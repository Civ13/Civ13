"""Injected contracts only. No Docker, Git subprocess, compiler or daemon runs."""
import copy
import hashlib
import importlib.util
import io
import json
import os
import re
import sys
from pathlib import Path
import tarfile
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from contextlib import ExitStack

ROOT = Path(__file__).resolve().parent


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


r = load_module('preflight_driver_test', ROOT / 'run.py')
p = load_module('preflight_prepare_test', ROOT / 'prepare.py')
HEAD = 'a' * 40
DIGEST = 'b' * 64
CID = 'c' * 64


def admitted():
    toolchain = json.loads((ROOT / 'toolchain.json').read_text())
    toolchain.update(status='INDEPENDENTLY_REVIEWED', archive_sha256=DIGEST,
                     image='example.invalid/admitted@sha256:' + DIGEST, image_id='sha256:' + DIGEST,
                     rootfs_provenance='INJECTED; not an acquired toolchain', independent_review='INJECTED')
    for key in ('compiler', 'daemon', 'python'):
        toolchain[key]['sha256'] = DIGEST
    toolchain['rootfs_files'] = {'opt/byond/bin/DreamMaker': DIGEST, 'opt/byond/bin/DreamDaemon': DIGEST}
    packet = {'head': HEAD, 'packet_sha256': DIGEST, 'executor': 'injected', 'toolchain': toolchain,
              'controls_receipt_sha256': DIGEST, 'source_manifest_sha256': DIGEST}
    grant = {'scope': r.SCOPE, 'head': HEAD, 'packet_sha256': DIGEST, 'executor': 'injected', 'granted': True,
             'starts': 10, 'ends': 900, 'compile_count': 1, 'smoke_modes': ['baseline', 'candidate'],
             'larger_controls_accepted': True, 'engine_contract_accepted': True, 'zero_cost_handoff_accepted': True,
             'controls_receipt_sha256': DIGEST}
    return packet, grant


def inspection(packet, source, build, output, compile_phase=True):
    return {'Image': packet['toolchain']['image_id'], 'Config': {'Image': packet['toolchain']['image'],
            'User': '65534:65534', 'Entrypoint': ['/usr/local/bin/python3.12'], 'WorkingDir': '/work'},
            'HostConfig': {'Memory': r.MEMORY, 'MemorySwap': r.MEMORY, 'PidsLimit': 32, 'NanoCpus': 1000000000,
                           'LogConfig': copy.deepcopy(r.LOG), 'NetworkMode': 'none', 'ReadonlyRootfs': True,
                           'Privileged': False, 'CgroupnsMode': 'private', 'IpcMode': 'private', 'PidMode': '',
                           'CapDrop': ['ALL'], 'SecurityOpt': ['no-new-privileges'], 'Tmpfs': {}, 'ShmSize': 1048576},
            'Mounts': [{'Source': str(path), 'Destination': dest, 'RW': rw, 'Type': 'bind'} for path, dest, rw in
                       ((source, '/source', False), (build, '/build', compile_phase), (output, '/work', True))],
            'State': {'OOMKilled': False}}


class SourceContracts(unittest.TestCase):
    def source(self):
        names = {'config/names/n' + str(i) + '.txt' for i in range(146)}
        data = {'civ13.dme': b'#include "code/names.dm"\n',
                'code/names.dm': '\n'.join('file2list("' + x + '")' for x in sorted(names)).encode()}
        data.update({name: b'public\n' for name in names})
        return names, data

    def archive(self, data, extra=None):
        output = io.BytesIO()
        entries = {}
        with tarfile.open(fileobj=output, mode='w') as target:
            for path, value in data.items():
                row = tarfile.TarInfo(path); row.size = len(value)
                target.addfile(row, io.BytesIO(value))
                blob = hashlib.sha1(('blob ' + str(len(value)) + '\0').encode() + value).hexdigest()
                entries[path] = ('100644', 'blob', blob)
            if extra:
                target.addfile(extra)
        output.seek(0)
        return output, entries

    def test_archive_exact_public_bytes_and_post_mutation(self):
        names, data = self.source()
        archive, entries = self.archive(data)
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder) / 'source'
            manifest = p.extract(archive, entries, root, HEAD, names)
            self.assertEqual(manifest['compiled_artifacts'], 0)
            p.validate(root, manifest)
            (root / next(iter(names))).write_bytes(b'drift')
            with self.assertRaisesRegex(ValueError, 'changed'):
                p.validate(root, manifest)

    def test_archive_links_traversal_missing_blob_fail_closed(self):
        names, data = self.source()
        for kind in ('symlink', 'traversal', 'missing', 'blob', 'git-link', 'unexpected'):
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as folder:
                extra = None
                if kind in ('symlink', 'traversal', 'unexpected'):
                    extra = tarfile.TarInfo({'symlink': 'code/link', 'traversal': '../escape', 'unexpected': 'config/admins.txt'}[kind])
                    if kind == 'symlink':
                        extra.type = tarfile.SYMTYPE; extra.linkname = '/etc/passwd'
                archive, entries = self.archive(data, extra)
                if kind == 'missing':
                    entries['code/missing.dm'] = ('100644', 'blob', 'd' * 40)
                if kind == 'blob':
                    entries['code/names.dm'] = ('100644', 'blob', 'd' * 40)
                if kind == 'git-link':
                    entries['code/names.dm'] = ('120000', 'blob', entries['code/names.dm'][2])
                with self.assertRaises(ValueError):
                    p.extract(archive, entries, Path(folder) / 'source', HEAD, names)
                self.assertFalse((Path(folder) / 'escape').exists())

    def test_explicit_allowlist_excludes_private_compiled_and_other_tools(self):
        names, _ = self.source()
        for path in ('config/config.txt', 'config/admins.txt', 'data/save', 'BYOND/byond/bin/DreamMaker',
                     'code/compiled.dmb', 'tests/reserved_lighting/run-ci.py', '.git/config'):
            self.assertFalse(p.public(path, names), path)
        self.assertTrue(p.public('icons/public.dmi', names))
        for path in ('/etc/passwd', 'C:/live', 'code/../private', 'code//x', 'code\\x', './code/x'):
            with self.assertRaises(ValueError):
                p.relative(path)

    def test_aggregate_source_size_and_unexpected_after_seal(self):
        names, data = self.source()
        archive, entries = self.archive(data)
        with tempfile.TemporaryDirectory() as folder, patch.object(p, 'MAX_BYTES', 1):
            with self.assertRaisesRegex(ValueError, 'byte bound'):
                p.extract(archive, entries, Path(folder) / 'source', HEAD, names)


class AdmissionContracts(unittest.TestCase):
    def test_smoke_uses_real_semantic_comparator_and_rejects_old_summary(self):
        semantic=load_module('preflight_real_semantic_compare',ROOT.parent/'compare.py')
        states=[{'label':label,'rows':[[x,y,'synthetic'] for x,y in sorted(semantic.coordinates(label))],
                 'lumcounts':[[x,y,0.2,0.0] for x,y in sorted(semantic.ALL_CELLS)]} for label in semantic.LABELS]
        with tempfile.TemporaryDirectory() as folder, patch.dict(sys.modules,{'compare':semantic}):
            left,right=Path(folder)/'baseline',Path(folder)/'candidate'
            data='\n'.join(json.dumps(row) for row in states)
            left.write_text(data);right.write_text(data)
            result=r.compare_smokes(left,right)
            self.assertEqual((result['snapshots'],result['rows'],result['lumcount_rows'],result['still_omitted_lumcount_rows']),
                             (6,1350,1536,36))
            changed=copy.deepcopy(states)
            next(row for row in changed[-1]['lumcounts'] if row[:2]==[9,6])[3]=0.5
            right.write_text('\n'.join(json.dumps(row) for row in changed))
            with self.assertRaisesRegex(ValueError,'Native lumcount mismatch'):r.compare_smokes(left,right)
            for field in ('lumcount_rows','still_omitted_lumcount_rows'):
                for fault in ('missing','wrong'):
                    with self.subTest(field=field,fault=fault):
                        incomplete=copy.deepcopy(result)
                        if fault=='missing':incomplete.pop(field)
                        else:incomplete[field]-=1
                        with patch.object(semantic,'compare',return_value=incomplete):
                            with self.assertRaisesRegex(ValueError,'semantic smoke'):r.compare_smokes(left,right)

    def test_capacity_exclusive_collision_preserves_unowned_bytes(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            existing = root / 'capacity-collision'
            existing.write_bytes(b'operator-owned evidence')
            with patch.object(r, 'quota', return_value={'device': 1}), patch.object(r.uuid, 'uuid4', return_value=SimpleNamespace(hex='collision')):
                with self.assertRaises(FileExistsError):
                    r.capacity_control(root, 1024)
            self.assertTrue(existing.exists(), 'Unowned preexisting capacity probe was deleted')
            self.assertEqual(existing.read_bytes(), b'operator-owned evidence')

    def test_shared_budget_clamps_work_and_cleanup_to_outer_and_grant(self):
        clock = [0, 20]
        budget = r.Budget(10000, lambda: clock[0], lambda: clock[1])
        clock[0] = 570
        with self.assertRaisesRegex(ValueError, 'reserve'):
            budget.require(225)
        self.assertEqual(budget.timeout(180), 12)
        self.assertEqual(budget.timeout(180, cleanup=True), 27)
        clock[1] = 9990
        self.assertEqual(budget.timeout(180, cleanup=True), 7)
        with self.assertRaisesRegex(ValueError, 'deadline'):
            budget.timeout(180)

    def test_large_resource_artifact_and_log_policy_are_separate(self):
        limits = {}
        resource = SimpleNamespace(RLIMIT_CPU=1, RLIMIT_FSIZE=2, setrlimit=lambda key, value: limits.update({key: value}))
        with patch.dict(sys.modules, {'resource': resource}):
            r.compiler_limits()
        self.assertEqual(limits[2], (r.BUILD, r.BUILD))
        self.assertGreater(61 * 1024**2, r.OUTPUT)
        self.assertLess(61 * 1024**2, limits[2][0])
        with tempfile.TemporaryDirectory() as folder:
            paths = [Path(folder) / 'out', Path(folder) / 'err']
            # A 61MiB RSC lives in the build filesystem. Only the two log paths
            # reach the output detector; no large artifact is allocated here.
            child = SimpleNamespace(returncode=0, poll=lambda: 0)
            with patch.object(Path, 'stat', return_value=SimpleNamespace(st_size=1024)):
                self.assertEqual(r.compile_once(Path(folder), paths, popen=lambda *a, **kw: child), 0)
            for path in paths:
                path.unlink()
            calls = []
            child = SimpleNamespace(returncode=None, poll=lambda: child.returncode,
                                    kill=lambda: setattr(child, 'returncode', -9), wait=lambda **kw: calls.append('reaped'))
            with patch.object(Path, 'stat', return_value=SimpleNamespace(st_size=r.OUTPUT)):
                with self.assertRaisesRegex(ValueError, 'log output bound'):
                    r.compile_once(Path(folder), paths, popen=lambda *a, **kw: child)
            self.assertEqual(calls, ['reaped'])

    def test_real_compiler_exit_and_fatal_diagnostics_not_pipeline_success(self):
        log = 'DM compiler version 516.1681\nprobe.dmb - 0 errors, 0 warnings (1.0s)\n'
        r.compiler_result(0, log, re.compile('## ERROR'))
        for code, text in ((1, log), (0, log.replace('0 warnings', '1 warnings')),
                           (0, log + '## ERROR'), (0, log + 'Cannot open config/missing.txt')):
            with self.assertRaisesRegex(ValueError, 'Compiler failed'):
                r.compiler_result(code, text, re.compile('## ERROR'))

    def test_missing_exit_cpu_or_positive_private_provenance_rejected(self):
        identity = {'pid': 42, 'start_ticks': 100}
        good = [{'identity': identity, 'cpu': .01, 'private': 100, 'private_sampled': True, 'exited': False, 'exit_code': None},
                {'identity': identity, 'cpu': .02, 'private': 100, 'private_sampled': False, 'exited': True, 'exit_code': 0}]
        def validate(sample, expected, previous, limits):
            if sample['identity'] != expected:
                raise ValueError('PID drift')
            if previous and sample['cpu'] < previous['cpu']:
                raise ValueError('CPU reversal')
        r.adapter_evidence(good, identity, validate)
        for mutate in (lambda x: x.clear(), lambda x: x[-1].update(cpu=0), lambda x: x[0].update(private_sampled=False),
                       lambda x: x[-1].update(exit_code=1), lambda x: x[0].update(identity={'pid': 42, 'start_ticks': 101})):
            sample = copy.deepcopy(good); mutate(sample)
            with self.assertRaises(ValueError):
                r.adapter_evidence(sample, identity, validate)

    def test_capacity_control_requires_actual_linux_enospc_and_removes_only_probe(self):
        for error in (28, 13):
            writes = []
            class Writer:
                def __enter__(self): return self
                def __exit__(self, *args): return False
                def write(self, block):
                    if writes:
                        raise OSError(error, 'injected filesystem limit')
                    writes.append(len(block)); return len(block)
            with tempfile.TemporaryDirectory() as folder:
                root = Path(folder)
                with patch.object(r, 'quota', return_value={'device': 1}), patch.object(Path, 'open', return_value=Writer()), patch.object(Path, 'unlink') as unlink:
                    if error == 28:
                        value = r.capacity_control(root, 2 * 1024**2)
                        self.assertEqual(value['errno'], 28)
                    else:
                        with self.assertRaisesRegex(ValueError, 'ENOSPC'):
                            r.capacity_control(root, 2 * 1024**2)
                    unlink.assert_called_once_with(missing_ok=True)

    def test_unresolved_recipe_and_inert_default(self):
        with self.assertRaisesRegex(ValueError, 'Unresolved'):
            r.toolchain(json.loads((ROOT / 'toolchain.json').read_text()))
        self.assertEqual(r.plan()['compile_count'], 1)
        self.assertEqual(r.plan()['smoke_modes'], ['baseline', 'candidate'])
        self.assertFalse(r.plan()['image_acquisition'])

    def test_lease_packet_executor_controls_and_toolchain_before_external_effect(self):
        packet, grant = admitted()
        r.admission(packet, grant, 20)
        mutations = [lambda p, g: g.update(ends=21), lambda p, g: g.update(ends=float('inf')),
                     lambda p, g: g.update(executor='other'), lambda p, g: g.update(packet_sha256='f' * 64),
                     lambda p, g: g.update(compile_count=2), lambda p, g: g.update(larger_controls_accepted=False),
                     lambda p, g: g.update(smoke_modes=['baseline', 'candidate', 'baseline']),
                     lambda p, g: p['toolchain']['daemon'].update(sha256=None),
                     lambda p, g: p['toolchain'].update(rootfs_files={}), lambda p, g: p.update(controls_receipt_sha256=None)]
        for mutate in mutations:
            p1, g1 = copy.deepcopy(packet), copy.deepcopy(grant)
            mutate(p1, g1)
            with self.assertRaises(ValueError):
                r.admission(p1, g1, 20)

    def test_hard_quota_is_one_aggregate_host_mount_not_two_run_limits(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            stat = lambda path: SimpleNamespace(f_frsize=4096, f_blocks=r.SCRATCH // 4096, f_bavail=100)
            self.assertEqual(r.quota(root, r.SCRATCH, stat, lambda x: True)['capacity'], r.SCRATCH)
            with self.assertRaisesRegex(ValueError, 'capacity'):
                r.quota(root, r.SCRATCH * 2, stat, lambda x: True)
            with self.assertRaisesRegex(ValueError, 'mount'):
                r.quota(root, r.SCRATCH, stat, lambda x: False)
            for phase in ('baseline', 'candidate', 'controller-compile'):
                r.contained(root / phase, root)
            with self.assertRaisesRegex(ValueError, 'escape'):
                r.contained(root.parent / 'outside', root)

    def test_prestart_readback_rejects_mount_log_swap_network_and_missing_counter(self):
        packet, _ = admitted()
        source, build, output = Path('/source-root'), Path('/build-root'), Path('/output-root')
        good = inspection(packet, source, build, output)
        r.settings(good, packet, source, build, output, True)
        changes = [lambda x: x['HostConfig']['LogConfig']['Config'].pop('compress'),
                   lambda x: x['HostConfig']['LogConfig']['Config'].update(compress='true'),
                   lambda x: x['HostConfig'].update(MemorySwap=r.MEMORY * 2),
                   lambda x: x['HostConfig'].pop('PidsLimit'),
                   lambda x: x['HostConfig'].update(NetworkMode='bridge'),
                   lambda x: x['Mounts'][0].update(RW=True),
                   lambda x: x['Mounts'].append({'Source': '/home/runner', 'Destination': '/private', 'RW': False, 'Type': 'bind'})]
        for change in changes:
            value = copy.deepcopy(good); change(value)
            with self.assertRaises((KeyError, ValueError)):
                r.settings(value, packet, source, build, output, True)


class OrchestrationContracts(unittest.TestCase):
    def actual_execute(self, fault):
        """Actual execute/lease/verify/phase/seal; only external effects injected."""
        with tempfile.TemporaryDirectory() as folder, ExitStack() as stack:
            base = Path(folder).resolve()
            source, build, output = (base / name for name in ('source', 'build', 'output'))
            for path in (source, build, output): path.mkdir()
            native = source / 'tests/reserved_lighting/native_preflight'; native.mkdir(parents=True)
            for name in ('run.py', 'prepare.py'): (native / name).write_bytes((ROOT / name).read_bytes())
            (source / 'source.json').write_text(json.dumps({'head': HEAD, 'files': {}}))
            packet, grant = admitted()
            packet.pop('packet_sha256')
            packet['source_manifest_sha256'] = r.sha(source / 'source.json')
            packet_path, grant_path = base / 'packet.json', base / 'grant.json'
            packet_path.write_text(json.dumps(packet))
            grant.update(packet_sha256=r.sha(packet_path), ends=10000)
            grant_path.write_text(json.dumps(grant))
            clock, calls, compiled_done = [0], [], [False]
            def validate(*args):
                if fault == 'slow-hash': clock[0] = 570
                if compiled_done[0]:
                    if fault == 'rewrite-build':
                        target = build / 'fixture/probe.dmb'; target.write_bytes(b'coherently changed binary')
                        ledger = json.loads((build / 'build.json').read_text())
                        ledger['files']['fixture/probe.dmb'] = r.sha(target)
                        (build / 'build.json').write_text(json.dumps(ledger))
                    if fault == 'rewrite-request':
                        (output / 'request.json').write_text('{}')
            prep = SimpleNamespace(validate=validate, relative=p.relative)
            class Docker:
                def __init__(self, directory): self.phase = directory.name.split('controller-', 1)[1]
                def call(self, args, **kw):
                    calls.append((self.phase, args, kw))
                    if args[0] == 'create':
                        if fault == 'slow-create': clock[0] = 570
                        return 0, CID, ''
                    if args[0] == 'wait':
                        if self.phase != 'compile': return 0, '0', ''
                        fixture = build / 'fixture'; fixture.mkdir()
                        for name in ('probe.dmb', 'probe.rsc'): (fixture / name).write_bytes(b'original product')
                        ledger = {'head': HEAD, 'compiler': packet['toolchain']['compiler'], 'exit_code': 0,
                                  'files': {path.relative_to(build).as_posix(): r.sha(path) for path in fixture.iterdir()}}
                        (build / 'build.json').write_text(json.dumps(ledger))
                        for name in ('compile-stdout.log', 'compile-stderr.log'): (output / name).write_bytes(b'original compile log')
                        return 0, '0', ''
                    return 0, '', ''
            def retire(docker, *args):
                docker.call(['rm', CID], cleanup=True)
                backend = getattr(docker, 'docker', docker)
                if backend.phase == 'compile': compiled_done[0] = True
                return {'all_exited': True, 'owned_container_absent': True}
            def inspect(docker, *args):
                return inspection(packet, source, build, output, getattr(docker, 'docker', docker).phase == 'compile')
            pilot = SimpleNamespace(Docker=Docker, inspect=inspect, owned=lambda *a: None, retire=retire)
            original_stat = Path.stat
            def stat(path, *args, **kw):
                value = original_stat(path, *args, **kw)
                if path in (build, output):
                    values = list(value); values[2] = 41 if path == build else 42
                    return os.stat_result(values)
                return value
            env = {'GITHUB_ACTIONS': 'true', 'RUNNER_ENVIRONMENT': 'github-hosted', 'RUNNER_OS': 'Linux', 'RUNNER_ARCH': 'X64',
                   'GITHUB_REPOSITORY': 'Civ13/Civ13', 'GITHUB_REPOSITORY_ID': '141349998', 'GITHUB_EVENT_NAME': 'workflow_dispatch',
                   'CIV13_REPOSITORY_VISIBILITY': 'public', 'CIV13_NATIVE_PREFLIGHT_CONFIRMED': 'true', 'GITHUB_SHA': HEAD}
            stack.enter_context(patch.object(r.sys, 'platform', 'linux'))
            stack.enter_context(patch.object(r.time, 'monotonic', lambda: clock[0]))
            stack.enter_context(patch.object(r.time, 'time', lambda: 20))
            stack.enter_context(patch.object(r, 'quota', return_value={}))
            stack.enter_context(patch.object(r, 'capacity_control', return_value={}))
            stack.enter_context(patch.object(Path, 'stat', stat))
            stack.enter_context(patch.object(r, 'module', side_effect=lambda name, path: prep if name == 'native_staging' else pilot))
            stack.enter_context(patch.object(r, 'build_inventory', side_effect=lambda *a: r.load(build / 'build.json')))
            with self.assertRaises(ValueError):
                r.execute(packet_path, grant_path, source, build, output, env)
            receipt = r.load(output / 'preflight.json')
            return calls, receipt

    def test_actual_orchestration_refuses_slow_hash_and_create_before_start(self):
        for fault in ('slow-hash', 'slow-create'):
            with self.subTest(fault=fault):
                calls, receipt = self.actual_execute(fault)
                self.assertFalse(receipt['complete'])
                self.assertFalse(any(args[0] == 'start' for _, args, _ in calls))
                self.assertIn('reserve', receipt['runs'][0]['error'])
                if fault == 'slow-create':
                    cleanup = [kw['timeout'] for _, args, kw in calls if args[0] == 'rm']
                    self.assertTrue(cleanup)
                    self.assertLessEqual(cleanup[0], 27)

    def test_actual_orchestration_rejects_coherent_build_or_request_rewrite(self):
        for fault, error in (('rewrite-build', 'Original compile ledger drift'), ('rewrite-request', 'Original shared request drift')):
            with self.subTest(fault=fault):
                calls, receipt = self.actual_execute(fault)
                self.assertFalse(receipt['complete'])
                self.assertEqual([phase for phase, args, _ in calls if args[0] == 'start'], ['compile'])
                self.assertIn(error, receipt['error'])

    def test_exact_compile_two_smokes_stop_on_failure(self):
        for failing in (None, 'compile', 'baseline', 'candidate'):
            calls, saved = [], []
            def phase(name):
                calls.append(name)
                return {'complete': name != failing}
            def verify(final=False):
                return {'snapshots': 6, 'rows': 1350, 'lumcount_rows': 1536, 'still_omitted_lumcount_rows': 36, 'equal': True} if final else None
            result = r.sequence(phase, verify, lambda x: saved.append(copy.deepcopy(x)))
            expected = ['compile', 'baseline', 'candidate']
            if failing:
                expected = expected[:expected.index(failing) + 1]
            self.assertEqual(calls, expected)
            self.assertEqual(result['complete'], failing is None)
            self.assertFalse(result['performance_verdict'])
            self.assertEqual(saved[-1], result)

    def test_final_parity_hash_or_lease_failure_persists_incomplete(self):
        for fail in ('parity', 'after-parity'):
            final = [False]
            saved = []
            def verify(final=False):
                if final:
                    if fail == 'parity':
                        raise ValueError('parity drift')
                    done[0] = True
                elif done[0]:
                    raise ValueError('lease/input drift after hashing')
            done = final
            result = r.sequence(lambda n: {'complete': True}, verify, lambda x: saved.append(copy.deepcopy(x)))
            self.assertFalse(result['complete'])
            self.assertFalse(saved[-1]['complete'])
            self.assertEqual(len(result['runs']), 3)

    def owned_fixture(self, create_error=False, reconcile=False, settings_error=False):
        packet, _ = admitted()
        source, build, output = Path('/s'), Path('/b'), Path('/o')
        good = inspection(packet, source, build, output)
        if settings_error:
            good['HostConfig']['LogConfig']['Config']['compress'] = 'true'
        calls, cleanup = [], []
        class Docker:
            def call(self, args, **kw):
                calls.append(args)
                if args[0] == 'create':
                    if create_error:
                        raise ValueError('original create rc1')
                    return 0, CID, ''
                if args[0] == 'inspect':
                    if reconcile:
                        return 0, json.dumps([dict(good, Id=CID)]), ''
                    return 1, '', 'not found'
                if args[0] == 'wait':
                    return 0, '0', ''
                return 0, '', ''
        pilot = SimpleNamespace(inspect=lambda *a: good, owned=lambda *a: None,
                                retire=lambda *a: cleanup.append(a[1]) or {'all_exited': True, 'owned_container_absent': True})
        row = r.owned_phase(pilot, Docker(), packet, source, build, output, 'compile', lambda **kw: None)
        return row, calls, cleanup

    def test_unknown_create_no_signals_no_retry_original_error(self):
        row, calls, cleanup = self.owned_fixture(create_error=True)
        self.assertFalse(row['complete'])
        self.assertEqual(row['create_error'], 'original create rc1')
        self.assertEqual(len([x for x in calls if x[0] == 'create']), 1)
        self.assertEqual(cleanup, [])
        self.assertFalse(row['cleanup']['all_exited'])
        self.assertFalse(any(x[0] in ('start', 'kill', 'rm') for x in calls))

    def test_known_uncertain_create_cleanup_preserves_failure(self):
        row, calls, cleanup = self.owned_fixture(create_error=True, reconcile=True)
        self.assertFalse(row['complete'])
        self.assertEqual(row['error'], 'original create rc1')
        self.assertEqual(cleanup, [CID])
        self.assertFalse(any(x[0] == 'start' for x in calls))

    def test_bad_settings_cleanup_before_start(self):
        row, calls, cleanup = self.owned_fixture(settings_error=True)
        self.assertFalse(row['complete'])
        self.assertEqual(cleanup, [CID])
        self.assertFalse(any(x[0] == 'start' for x in calls))

    def test_valid_injected_phase_is_not_native_execution(self):
        row, calls, cleanup = self.owned_fixture()
        self.assertTrue(row['complete'])
        self.assertEqual(cleanup, [CID])
        self.assertEqual(len([x for x in calls if x[0] == 'start']), 1)
        argv = next(x for x in calls if x[0] == 'create')
        self.assertIn('never', argv)
        self.assertNotIn('pull', [x[0] for x in calls])


if __name__ == '__main__':
    unittest.main()
