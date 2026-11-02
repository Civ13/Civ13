"""Offline tests for paired worker, exact evidence and restricted transport."""
import copy
import contextlib
import hashlib
import importlib.util
import io
import json
import subprocess
import sys
from pathlib import Path
import tarfile
import tempfile
import time
import types
import unittest
from unittest.mock import patch

import build_guard
import receipt
import runner_limits
import source_binding
import stage_bundle
import test_receipt as model

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
HEAD = 'a' * 40
TREE = 'b' * 40


def load(name):
    spec = importlib.util.spec_from_file_location(name, HERE / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


evidence, worker = load('bump_evidence'), load('bump_worker')
controller, smoke = load('cloud_npc_controller'), load('cloud_npc_smoke')
job = load('cloud_npc_job')


def packet_fixture():
    inputs = source_binding.read_inputs(['git', '-C', str(ROOT)], source_binding.BASE)
    guard = build_guard.OLD.read_bytes()
    observer = (HERE / 'bump_fixture_observer.dm').read_bytes()
    scenario = (HERE / 'bump_fixture_probe.dm').read_bytes()
    sources = {'tests/human_subtile/bump_guard_preimage.dm': guard,
               stage_bundle.OBSERVER: observer, stage_bundle.SCENARIO: scenario}
    overlays = {v: stage_bundle.reconstruct(inputs, guard, observer, scenario, v == 'candidate')
                for v in ('baseline', 'candidate')}
    rows = {v: [model.row(c, v == 'candidate') for c in receipt.CASES] for v in ('baseline', 'candidate')}
    resource = {'bytes': 3, 'sha256': 'b' * 64, 'mode': 0o600}
    states = {v: {'before': resource, 'after': resource, 'changed': False, 'integrity_verified': True}
              for v in rows}
    phases = [dict(name=name, seconds=1, returncode=0, timed_out=False, oversized_log=False, deadline=limit)
              for name, limit in runner_limits.PHASES]
    for i, prefix in ((0, 'npc-parent'), (2, 'npc-smoke')):
        phases[i]['command'] = ['/opt/byond/bin/DreamMaker', '-max_errors', '0', '/work/' + prefix + '/stage/human_subtile.dme']
        phases[i + 1]['command'] = ['/opt/byond/bin/DreamDaemon', '/work/' + prefix + '/runtime/human_subtile.dmb',
                                   '59474', '-ip', '127.0.0.1', '-trusted', '-params', 'tested_commit=' + HEAD, '-log', 'runtime.log']
    without_name = lambda value: {k: v for k, v in value.items() if k != 'name'}
    files = {}
    receipts = {}
    for variant, prefix in (('baseline', 'npc-parent'), ('candidate', 'npc-smoke')):
        data = dict(head=HEAD, error=None, byond_version=516, byond_build=1688, port=0,
                    scope=receipt.SCOPE, bump_variant=variant, bump_rows=rows[variant],
                    bump_case=receipt.CASES[-1], bump_checks=50, bump_overflow=0,
                    bump_partial=rows[variant][-1]['events'],
                    bump_setup=dict(tick=0.5, startup_time=0, ready_time=.5, ready_usage=10))
        raw = json.dumps(data).encode()
        receipts[variant] = hashlib.sha256(raw).hexdigest()
        manifest = dict(head=HEAD, bump_variant=variant, bump_base=source_binding.BASE,
                        bump_base_tree=source_binding.TREE, bump_experiment_tree=TREE,
                        stage_files={p: evidence.metadata(r) for p, r in overlays[variant].items()})
        files[prefix + '/cloud-manifest.json'] = json.dumps(manifest).encode()
        files[prefix + '/stage/compile-stdout.log'] = b'0 errors, 0 warnings\n'
        files[prefix + '/stage/compile-stderr.log'] = b''
        for name, value in (('receipt.json', raw), ('result.txt', b'PASS\n'), ('port-closed.txt', b'closed\n'),
                            ('runtime.log', b''), ('daemon-stdout.log', b''), ('daemon-stderr.log', b'')):
            files[prefix + '/runtime/' + name] = value
    compiled = {'bytes': 4, 'sha256': 'c' * 64, 'mode': 0o444}
    artifacts = {v: {'human_subtile.rsc': resource, 'human_subtile.dmb': compiled} for v in rows}
    results = {v: {'receipt_sha256': receipts[v], 'daemon': without_name(phases[i + 1])}
               for v, i in (('baseline', 0), ('candidate', 2))}
    summary = dict(head=HEAD, tree=TREE, base=source_binding.BASE, suite='bump05', fixture_dme_only=True,
                   observation_complete=True, parity_established=False, scope=receipt.SCOPE, tick=.5,
                   cases=list(receipt.CASES), artifacts=artifacts, resource_states=states, results=results,
                   phases=phases, compiles={'baseline': without_name(phases[0]), 'candidate': without_name(phases[2])},
                   comparison_elapsed=5, setup_seconds=1,
                   limits=dict(compile_seconds=90, daemon_seconds=60, setup_seconds=60, work_seconds=490, whole_seconds=600))
    status = dict(head=HEAD, suite='bump05', phase='complete', outcome='passed', fixture_dme_only=True,
                  resource_copies_independent=True, runtime_resources=states)
    files['harness-status.json'] = json.dumps(status).encode()
    files['smoke-summary.json'] = json.dumps(summary).encode()
    files.update({f'abi/abi-{i}-{part}.log': b'' for i in range(6) for part in ('stdout', 'stderr')})
    return inputs, sources, files


def tar_bytes(files):
    output = io.BytesIO()
    with tarfile.open(fileobj=output, mode='w') as tar:
        for name, raw in files.items():
            info = tarfile.TarInfo(name)
            info.size = len(raw)
            tar.addfile(info, io.BytesIO(raw))
    return output.getvalue()


class EvidenceTests(unittest.TestCase):
    def test_current_workflow_only_selects_group_and_serializes(self):
        text = (ROOT / '.github/workflows/wildlife-cardinal-cadence.yml').read_text(encoding='utf-8')
        for token in ('on:\n  workflow_dispatch:', 'options: [native_group_bump]', 'suite: [group05]',
                      'test "$EXPERIMENT" = native_group_bump', 'test "$WILDLIFE_SUITE" = group05',
                      'max-parallel: 1', 'cancel-in-progress: false',
                      'test "$EXPECTED_HEAD" = "$GITHUB_SHA"', 'persist-credentials: false'):
            self.assertIn(token, text)
        for forbidden in ('\n  push:', '\n  pull_request:', 'suite: [transition05]',
                          'options: [transition]', 'options: [bump,', 'options: [ordinary_bump]', 'suite: [ordinary05]'):
            self.assertNotIn(forbidden, text)

    def test_host_recomputes_pair_and_rejects_missing_extra_or_modified_evidence(self):
        inputs, sources, files = packet_fixture()
        self.assertEqual(len(files), 32)
        fake_source = types.SimpleNamespace(BASE=source_binding.BASE, TREE=source_binding.TREE,
            budget_timeout=source_binding.budget_timeout,
            validate_head=lambda git, head, env, deadline: TREE, read_inputs=lambda git, base, env, deadline: inputs)
        loaded = {'source_binding': fake_source, 'stage_bundle': stage_bundle, 'receipt': receipt,
                  'runner_limits': runner_limits}
        def source(_git, _env, _head, path, _binding, _deadline):
            return sources[path]
        def compile_ok(log, name):
            if log != '0 errors, 0 warnings\n' or name != 'human_subtile.dmb':
                raise ValueError('compile log')
        with patch.object(evidence, 'source', side_effect=source):
            self.assertTrue(evidence.validate(tar_bytes(files), HEAD, 'bump05', ['git'], {}, loaded, compile_ok))
            with self.assertRaises(TimeoutError):
                evidence.validate(tar_bytes(files), HEAD, 'bump05', ['git'], {}, loaded, compile_ok, deadline=time.monotonic()-1)
            for mutation in ('missing', 'extra', 'receipt', 'manifest', 'timeout', 'command', 'artifact'):
                bad = copy.deepcopy(files)
                if mutation == 'missing': del bad['npc-parent/runtime/receipt.json']
                elif mutation == 'extra': bad['npc-parent/runtime/extra'] = b'x'
                elif mutation == 'receipt': bad['npc-smoke/runtime/receipt.json'] = b'{}'
                elif mutation == 'manifest': bad['npc-parent/cloud-manifest.json'] = b'{}'
                elif mutation == 'timeout':
                    summary = json.loads(bad['smoke-summary.json'])
                    summary['phases'][1]['timed_out'] = True
                    bad['smoke-summary.json'] = json.dumps(summary).encode()
                elif mutation == 'command':
                    summary = json.loads(bad['smoke-summary.json'])
                    summary['phases'][1]['command'][0] = '/unexpected/DreamDaemon'
                    bad['smoke-summary.json'] = json.dumps(summary).encode()
                else:
                    summary = json.loads(bad['smoke-summary.json'])
                    summary['artifacts']['baseline']['human_subtile.dmb']['mode'] = 0o600
                    bad['smoke-summary.json'] = json.dumps(summary).encode()
                with self.subTest(mutation=mutation), self.assertRaises((ValueError, KeyError)):
                    evidence.validate(tar_bytes(bad), HEAD, 'bump05', ['git'], {}, loaded, compile_ok)
        raw = tar_bytes(files)
        meta = {'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}
        self.assertEqual(controller.validate_package(raw, meta, 'bump05'), raw)
        extra = dict(files, **{'npc-parent/runtime/extra': b'x'})
        raw = tar_bytes(extra)
        with self.assertRaises(RuntimeError):
            controller.validate_package(raw, {'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}, 'bump05')

    def test_exact_container_arguments_and_deadline(self):
        args = controller.create_args('owned', 'b' * 32, HEAD, Path('/source'), Path('/byond'),
                                      Path('/byond.zip'), '1001:1001', 'bump05', 123.0)
        self.assertEqual(args[args.index('--network') + 1], 'none')
        self.assertEqual(args[args.index('--memory') + 1], '3g')
        self.assertEqual(args[args.index('--cpus') + 1], '2')
        self.assertEqual(args[args.index('--pids-limit') + 1], '64')
        self.assertIn('--read-only', args)
        self.assertIn('--work-deadline', args)
        with self.assertRaises(RuntimeError):
            controller.create_args('owned', 'b' * 32, HEAD, Path('/source'), Path('/byond'),
                                   Path('/byond.zip'), '1001:1001', 'bump05', None)

    def test_scratch_preflight_counts_second_stage_metadata_without_increasing_quota(self):
        tree = b'100644 blob abc 100\tcode/example.dm\0'
        estimate = job.selected_estimate(tree, 'bump05')
        self.assertEqual(estimate['archive_and_stage_estimate_bytes'], 200 + 32768)
        self.assertEqual(estimate['scratch_limit_bytes'], 1024**3)
        self.assertGreater(estimate['archive_and_stage_estimate_bytes'],
                           job.selected_estimate(tree, 'transition05')['archive_and_stage_estimate_bytes'])
        with self.assertRaises(RuntimeError):
            job.selected_estimate(b'', 'bump05')
        with self.assertRaises(RuntimeError):
            job.selected_estimate(b'100644 blob abc 1073741824\tcode/huge.dm\0', 'bump05')

    def test_isolated_python_loads_exact_sibling_modules_without_pythonpath(self):
        for target in ('bump_evidence', 'bump_worker'):
            code = '''import importlib.util, pathlib, sys, types
p=pathlib.Path(sys.argv[1]); name=sys.argv[2]
def load(n, f):
 s=importlib.util.spec_from_file_location(n, f); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); return m
m=load(name,p/(name+'.py'))
def require(ok,msg):
 if not ok: raise RuntimeError(msg)
mods=m.modules() if name=='bump_evidence' else m.modules(types.SimpleNamespace(HERE=p,load_module=load,require=require))
assert set(mods)=={'build_guard','source_binding','stage_observer','stage_bundle','materialize_pair','receipt','runner_limits'}
'''
            result = subprocess.run([sys.executable, '-I', '-B', '-c', code, str(HERE), target],
                                    capture_output=True, timeout=10)
            with self.subTest(target=target):
                self.assertEqual(result.returncode, 0, result.stderr.decode(errors='replace'))

    def test_complete_pair_round_trips_through_actual_bounded_transport(self):
        _, _, files = packet_fixture()
        self.assertTrue(set(files) <= set(smoke.EVIDENCE_PATHS))
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name, raw in files.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(raw)
            captured = io.StringIO()
            with patch.object(smoke, 'RUN_STATE', {'suite': 'bump05'}), contextlib.redirect_stdout(captured):
                smoke.emit_package(root, 'passed', {'samples': 1})
            output = captured.getvalue().encode()
            marker = json.loads(output.splitlines()[-1].split(b' ', 1)[1])
            self.assertTrue(marker['package']['complete'])
            raw = controller.package_from_logs(output, marker, 'bump05')
            with tarfile.open(fileobj=io.BytesIO(raw)) as tar:
                self.assertEqual(set(tar.getnames()), set(files))
            with self.assertRaises(RuntimeError):
                controller.package_from_logs(output.replace(b'HARNESS_EVIDENCE_PART 1/', b'HARNESS_EVIDENCE_PART 2/', 1), marker, 'bump05')

    def test_worker_runs_two_bounded_compiles_and_fresh_daemons(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            calls = []
            def require(ok, message):
                if not ok:
                    raise RuntimeError(message)
            def prepare(out):
                (out / 'stage').mkdir(parents=True)
                (out / 'stage/human_subtile.dme').write_text('fixture')
                return {'head': HEAD, 'dme': 'stage/human_subtile.dme', 'stage_files': {}}
            def pair(out, manifest, *_):
                parent = out.parent / 'npc-parent'
                (parent / 'stage').mkdir(parents=True)
                (parent / 'stage/human_subtile.dme').write_text('fixture')
                return parent, {'head': HEAD, 'dme': 'stage/human_subtile.dme', 'stage_files': {}}
            def compile_phase(_legacy, _group, _cmd, stage, _name, limit):
                calls.append(('compile', limit))
                (stage / 'compile-stdout.log').write_text('ok')
                (stage / 'compile-stderr.log').write_text('')
                return {'seconds': 0, 'returncode': 0, 'timed_out': False, 'oversized_log': False, 'deadline': limit}
            def linked(out, _stage, _dme, name):
                folder = out / name
                folder.mkdir()
                return folder, folder / 'human_subtile.dmb', {'human_subtile.rsc': {'mode': 384}}
            def daemon(_legacy, _group, _cmd, folder, _dme, _peer, _artifacts, _expected, label, states, timeout):
                calls.append(('daemon', label, timeout))
                states[label] = {'after': {'mode': 384}}
                (folder / 'port-closed.txt').write_bytes(b'closed\n')
                (folder / 'result.txt').write_bytes(b'PASS\n')
                (folder / 'receipt.json').write_text('{"bump_rows": []}')
                return {'seconds': 0, 'returncode': 0, 'timed_out': False, 'oversized_log': False, 'deadline': timeout}
            fake_source = types.SimpleNamespace(BASE=source_binding.BASE, TREE=source_binding.TREE,
                validate_head=lambda *_: TREE, read_inputs=lambda *_: {})
            fake_oracle = types.SimpleNamespace(SCOPE=receipt.SCOPE, CASES=receipt.CASES,
                validate_receipt=lambda *_: True, validate_pair=lambda *_: True)
            mods = dict(runner_limits=runner_limits, source_binding=fake_source,
                        materialize_pair=types.SimpleNamespace(prepare_pair=pair), receipt=fake_oracle)
            shared = types.SimpleNamespace(HERE=HERE, ROOT=root, require=require, checkpoint=lambda *a, **k: None,
                run_owned_phase=compile_phase, prepare_linked_runtime=linked, run_checked_runtime=daemon,
                file_hash=lambda _: 'b' * 64)
            npc = types.SimpleNamespace(prepare=prepare)
            runtime = types.SimpleNamespace(verify_linux=lambda *_: None)
            legacy = types.SimpleNamespace(validate_compile=lambda *_: None, inspect_logs=lambda *_: None)
            args = types.SimpleNamespace(suite='bump05', head=HEAD, work_deadline=time.monotonic() + 400)
            with patch.object(worker, 'modules', return_value=mods), patch.object(worker.os.path, 'samefile', return_value=False):
                worker.run(shared, args, root, root, root, None, {}, {}, {}, time.monotonic(), npc, runtime, legacy)
            self.assertEqual(calls, [('compile', 90), ('daemon', 'baseline', 60),
                                     ('compile', 90), ('daemon', 'candidate', 60)])
            self.assertFalse(json.loads((root / 'smoke-summary.json').read_text())['parity_established'])
            args.work_deadline = time.monotonic() + 1
            with patch.object(worker, 'modules', return_value=mods), self.assertRaises(ValueError):
                worker.run(shared, args, root, root, root, None, {}, {}, {}, time.monotonic(), npc, runtime, legacy)


if __name__ == '__main__':
    unittest.main()
