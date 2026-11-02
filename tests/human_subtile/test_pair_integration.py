"""Offline pair worker, source binding and exact archive controls."""
import copy
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import time
import types
import unittest
from unittest.mock import patch

import cloud_npc_controller as controller
import cloud_npc_job as job
import pair_binding as binding
import pair_evidence as evidence
import pair_materialize as materialize
import pair_receipt as receipt
import pair_stage as stage
import pair_worker as worker
import runner_limits as limits
import test_pair_order as model

HERE = Path(__file__).resolve().parent
HEAD = 'a' * 40
TREE = 'b' * 40


def require(ok, msg):
    if not ok:
        raise RuntimeError(msg)


def inputs():
    root = HERE.parents[1]
    override = os.environ.get('PAIR_BASE_GITDIR')
    git = ['git', '-C', str(root)] if (root / 'civ13.dme').is_file() else ['git', '--git-dir', override]
    return binding.read_inputs(git)


def metadata(raw):
    return {'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}


def make_tar(files):
    output = io.BytesIO()
    with tarfile.open(fileobj=output, mode='w') as archive:
        for name, raw in files.items():
            info = tarfile.TarInfo(name)
            info.size = len(raw)
            archive.addfile(info, io.BytesIO(raw))
    return output.getvalue()


def package_fixture():
    base = inputs()
    fixture = (HERE / 'pair_measure.dm').read_bytes()
    overlay = stage.reconstruct(base, fixture)
    rows = {name: model.make_receipt(mode) for name, mode in
            (('baseline', 'legacy'), ('candidate', 'pair_first'))}
    resource = {'bytes': 3, 'sha256': 'b'*64, 'mode': 0o600}
    states = {v: {'before': resource, 'after': resource, 'changed': False, 'integrity_verified': True}
              for v in rows}
    phases = [dict(name=name, seconds=1, returncode=0, timed_out=False, oversized_log=False, deadline=limit)
              for name, limit in limits.PHASES]
    for index, prefix, mode in ((0, 'npc-parent', 'legacy'), (2, 'npc-smoke', 'pair_first')):
        phases[index]['command'] = ['/opt/byond/bin/DreamMaker', '-max_errors', '0',
                                     '/work/' + prefix + '/stage/human_subtile.dme']
        phases[index+1]['command'] = ['/opt/byond/bin/DreamDaemon',
            '/work/' + prefix + '/runtime/human_subtile.dmb', '59474', '-ip', '127.0.0.1', '-trusted',
            '-params', 'tested_commit=' + HEAD + ';pair_mode=' + mode, '-log', 'runtime.log']
    bare = lambda item: {k: v for k, v in item.items() if k != 'name'}
    files, receipts = {}, {}
    for label, prefix, mode in (('baseline', 'npc-parent', 'legacy'), ('candidate', 'npc-smoke', 'pair_first')):
        raw = json.dumps(rows[label]).encode()
        receipts[label] = hashlib.sha256(raw).hexdigest()
        manifest = dict(head=HEAD, pair_mode=mode, pair_base=stage.BASE, pair_base_tree=stage.BASE_TREE,
                        pair_experiment_tree=TREE, stage_files={p: metadata(v) for p, v in overlay.items()})
        files[prefix + '/cloud-manifest.json'] = json.dumps(manifest).encode()
        files[prefix + '/stage/compile-stdout.log'] = b'0 errors, 0 warnings\n'
        files[prefix + '/stage/compile-stderr.log'] = b''
        for name, value in (('receipt.json', raw), ('result.txt', b'PASS\n'), ('port-closed.txt', b'closed\n'),
                            ('runtime.log', b''), ('daemon-stdout.log', b''), ('daemon-stderr.log', b'')):
            files[prefix + '/runtime/' + name] = value
    compiled = {'bytes': 4, 'sha256': 'c'*64, 'mode': 0o444}
    artifacts = {v: {'human_subtile.rsc': resource, 'human_subtile.dmb': compiled} for v in rows}
    results = {v: {'receipt_sha256': receipts[v], 'daemon': bare(phases[i+1])}
               for v, i in (('baseline', 0), ('candidate', 2))}
    comparison = {'observations_complete': True, 'safety_or_gameplay_parity_established': False}
    summary = dict(head=HEAD, tree=TREE, base=stage.BASE, suite='pair05', fixture_dme_only=True,
                   observation_complete=True, parity_established=False, scope=receipt.SCOPE, tick=.5,
                   modes=['legacy', 'pair_first'], cases=list(receipt.CASES), comparison=comparison,
                   artifacts=artifacts, resource_states=states, results=results, phases=phases,
                   compiles={'baseline': bare(phases[0]), 'candidate': bare(phases[2])},
                   comparison_elapsed=5, setup_seconds=1,
                   limits=dict(compile_seconds=90, daemon_seconds=60, setup_seconds=60,
                               work_seconds=490, whole_seconds=600))
    status = dict(head=HEAD, suite='pair05', phase='complete', outcome='passed', fixture_dme_only=True,
                  resource_copies_independent=True, runtime_resources=states)
    files['harness-status.json'] = json.dumps(status).encode()
    files['smoke-summary.json'] = json.dumps(summary).encode()
    files.update({f'abi/abi-{i}-{part}.log': b'' for i in range(6) for part in ('stdout', 'stderr')})
    return base, fixture, files


class BindingControls(unittest.TestCase):
    def test_parent_and_exact_delta_fail_closed(self):
        paths = sorted(binding.ALLOWED_DELTA)
        def execute(cmd, **_):
            revision = cmd[-1]
            if cmd[-2:] == ['rev-parse', HEAD + '^']:
                return (binding.PARENT + '\n').encode()
            if cmd[-2:] == ['rev-parse', HEAD + '^^{tree}']:
                return (binding.PARENT_TREE + '\n').encode()
            if cmd[-2:] == ['rev-parse', HEAD + '^{tree}']:
                return (TREE + '\n').encode()
            if 'diff' in cmd:
                return ('\0'.join(paths) + '\0').encode()
            raise AssertionError(cmd)
        with patch.object(binding.subprocess, 'check_output', side_effect=execute):
            self.assertEqual(binding.validate_head(['git'], HEAD), TREE)
            paths.pop()
            with self.assertRaises(ValueError):
                binding.validate_head(['git'], HEAD)
            paths.append('unreviewed/file')
            with self.assertRaises(ValueError):
                binding.validate_head(['git'], HEAD)
        paths[:] = sorted(binding.ALLOWED_DELTA)
        for bad_revision in (HEAD + '^', HEAD + '^^{tree}'):
            def wrong(cmd, **kwargs):
                if cmd[-1] == bad_revision:
                    return ('f' * 40 + '\n').encode()
                return execute(cmd, **kwargs)
            with self.subTest(revision=bad_revision), patch.object(binding.subprocess, 'check_output', side_effect=wrong):
                with self.assertRaises(ValueError):
                    binding.validate_head(['git'], HEAD)
        with self.assertRaises(ValueError):
            binding.validate_head(['git'], 'not-a-sha')


class MaterializationControls(unittest.TestCase):
    def test_exact_preimage_and_separate_mutable_overlays(self):
        base = inputs()
        fixture = (HERE / 'pair_measure.dm').read_bytes()
        overlay = stage.reconstruct(base, fixture)
        with tempfile.TemporaryDirectory(prefix='pair-stage-', dir=HERE) as temp:
            root = Path(temp).resolve()
            self.assertEqual(root.parent, HERE.resolve())
            out = root / 'npc-smoke'
            folder = out / 'stage'
            for rel, raw in base.items():
                target = folder / rel
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(materialize.npc_probe(raw) if rel == materialize.PROBE else raw)
            suffix = b'#include "tests\\human_subtile\\pair_measure.dm"\n'
            (folder / 'human_subtile.dme').write_bytes(overlay['human_subtile.dme'][:-len(suffix)])
            manifest = {'head': HEAD, 'dme': 'stage/human_subtile.dme', 'stage_files': {}}
            parent, parent_manifest = materialize.prepare_pair(out, manifest, base, fixture)
            for rel, expected in overlay.items():
                self.assertEqual((out / 'stage' / rel).read_bytes(), expected)
                self.assertEqual((parent / 'stage' / rel).read_bytes(), expected)
                self.assertFalse(os.path.samefile(out / 'stage' / rel, parent / 'stage' / rel))
            self.assertEqual((parent_manifest['pair_mode'], manifest['pair_mode']), ('legacy', 'pair_first'))


class EvidenceControls(unittest.TestCase):
    def test_exact_archive_and_negative_controls(self):
        base, fixture, files = package_fixture()
        fake = types.SimpleNamespace(validate_head=lambda *_: TREE, read_inputs=lambda *a, **k: base,
                                     budget_timeout=lambda *_: 1)
        loaded = {'pair_binding': fake, 'pair_stage': stage, 'pair_receipt': receipt, 'runner_limits': limits}
        compile_ok = lambda log, name: require(log == '0 errors, 0 warnings\n' and name == 'human_subtile.dmb', 'compile')
        with patch.object(evidence, 'source', return_value=fixture):
            raw = make_tar(files)
            self.assertEqual(len(files), 32)
            self.assertTrue(evidence.validate(raw, HEAD, 'pair05', ['git'], {}, loaded, compile_ok))
            meta = {'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}
            self.assertEqual(controller.validate_package(raw, meta, 'pair05'), raw)
            for mutation in ('missing', 'extra', 'scope', 'mode', 'receipt', 'resource'):
                bad = copy.deepcopy(files)
                if mutation == 'missing':
                    del bad['npc-parent/runtime/receipt.json']
                elif mutation == 'extra':
                    bad['npc-parent/runtime/unexpected'] = b'x'
                elif mutation == 'scope':
                    value = json.loads(bad['smoke-summary.json']); value['parity_established'] = True
                    bad['smoke-summary.json'] = json.dumps(value).encode()
                elif mutation == 'mode':
                    value = json.loads(bad['smoke-summary.json']); value['phases'][1]['command'][-3] += ';extra=1'
                    bad['smoke-summary.json'] = json.dumps(value).encode()
                elif mutation == 'receipt':
                    bad['npc-parent/runtime/receipt.json'] = b'{}'
                else:
                    value = json.loads(bad['smoke-summary.json']); value['artifacts']['baseline']['human_subtile.dmb']['mode'] = 0o600
                    bad['smoke-summary.json'] = json.dumps(value).encode()
                with self.subTest(mutation=mutation), self.assertRaises((ValueError, KeyError, RuntimeError)):
                    evidence.validate(make_tar(bad), HEAD, 'pair05', ['git'], {}, loaded, compile_ok)
            extra = dict(files, **{'npc-parent/runtime/extra': b'x'})
            bad = make_tar(extra)
            with self.assertRaises(RuntimeError):
                controller.validate_package(bad, {'bytes': len(bad), 'sha256': hashlib.sha256(bad).hexdigest()}, 'pair05')

    def test_container_and_storage_limits_unchanged(self):
        args = controller.create_args('owned', 'b'*32, HEAD, Path('/source'), Path('/byond'),
                                      Path('/byond.zip'), '1001:1001', 'pair05', 123.0)
        for key, value in (('--network', 'none'), ('--memory', '3g'), ('--cpus', '2'), ('--pids-limit', '64')):
            self.assertEqual(args[args.index(key)+1], value)
        self.assertIn('--read-only', args)
        self.assertEqual(args[args.index('--cap-drop')+1], 'ALL')
        self.assertEqual(args[args.index('--security-opt')+1], 'no-new-privileges')
        self.assertEqual(args[args.index('--cgroupns')+1], 'private')
        self.assertIn('size=1073741824', args[args.index('--tmpfs')+1])
        self.assertNotIn('--privileged', args)
        self.assertIn('--work-deadline', args)
        with self.assertRaises(RuntimeError):
            controller.create_args('owned', 'b'*32, HEAD, Path('/source'), Path('/byond'),
                                   Path('/byond.zip'), '1001:1001', 'pair05', None)
        tree = b'100644 blob abc 100\tcode/example.dm\0'
        estimate = job.selected_estimate(tree, 'pair05')
        self.assertEqual(estimate['archive_and_stage_estimate_bytes'], 200 + 32768)
        self.assertEqual(estimate['scratch_limit_bytes'], 1024**3)



class WorkerControls(unittest.TestCase):
    def test_two_bounded_compiles_and_fresh_mode_specific_daemons(self):
        with tempfile.TemporaryDirectory(prefix='pair-worker-', dir=HERE) as temp:
            root = Path(temp).resolve()
            self.assertEqual(root.parent, HERE.resolve())
            calls = []

            def prepare(out):
                stage_dir = out / 'stage'
                stage_dir.mkdir(parents=True)
                (stage_dir / 'human_subtile.dme').write_bytes(b'fixture')
                return {'head': HEAD, 'dme': 'stage/human_subtile.dme', 'stage_files': {}}

            def pair(out, manifest, base, fixture):
                parent = root / 'npc-parent'
                (parent / 'stage').mkdir(parents=True)
                (parent / 'stage/human_subtile.dme').write_bytes(b'fixture')
                return parent, {'head': HEAD, 'dme': 'stage/human_subtile.dme', 'stage_files': {}}

            def compile_phase(_legacy, _group, command, folder, name, timeout):
                calls.append(('compile', timeout))
                (folder / 'compile-stdout.log').write_text('0 errors, 0 warnings\n')
                (folder / 'compile-stderr.log').write_text('')
                return dict(command=command, seconds=0, returncode=0, timed_out=False,
                            oversized_log=False, deadline=timeout)

            def linked(folder, stage_path, dme, name):
                work = folder / name
                work.mkdir()
                dmb = work / 'human_subtile.dmb'
                dmb.write_bytes(b'dmb')
                dmb.with_suffix('.rsc').write_bytes(b'rsc')
                return work, dmb, {'human_subtile.rsc': {'bytes': 3, 'sha256': 'b'*64, 'mode': 0o600},
                                   'human_subtile.dmb': {'bytes': 3, 'sha256': 'c'*64, 'mode': 0o444}}

            def daemon(_legacy, _group, command, work, dme, peer, artifacts, resource, label, states, timeout):
                mode = 'legacy' if label == 'baseline' else 'pair_first'
                self.assertEqual(command[command.index('-params')+1], 'tested_commit=' + HEAD + ';pair_mode=' + mode)
                calls.append(('daemon', mode, timeout))
                (work / 'port-closed.txt').write_bytes(b'closed\n')
                (work / 'result.txt').write_bytes(b'PASS\n')
                (work / 'receipt.json').write_text(json.dumps(model.make_receipt(mode)))
                states[label] = {'before': resource, 'after': resource, 'changed': False, 'integrity_verified': True}
                return dict(command=command, seconds=0, returncode=0, timed_out=False,
                            oversized_log=False, deadline=timeout)

            fake_binding = types.SimpleNamespace(validate_head=lambda *_: TREE, read_inputs=lambda *_: {})
            mods = {'runner_limits': limits, 'pair_binding': fake_binding,
                    'pair_materialize': types.SimpleNamespace(prepare_pair=pair),
                    'pair_receipt': receipt, 'pair_stage': stage}
            shared = types.SimpleNamespace(HERE=HERE, ROOT=root, require=require, checkpoint=lambda *a, **k: None,
                run_owned_phase=compile_phase, prepare_linked_runtime=linked, run_checked_runtime=daemon,
                file_hash=lambda path: hashlib.sha256(path.read_bytes()).hexdigest())
            runtime = types.SimpleNamespace(verify_linux=lambda *_: None)
            legacy = types.SimpleNamespace(validate_compile=lambda *_: None, inspect_logs=lambda *_: None)
            args = types.SimpleNamespace(suite='pair05', head=HEAD, work_deadline=time.monotonic()+400)
            with patch.object(worker, 'modules', return_value=mods), patch.object(worker.os.path, 'samefile', return_value=False):
                worker.run(shared, args, root, root, root, None, {}, {}, {}, time.monotonic(),
                           types.SimpleNamespace(prepare=prepare), runtime, legacy)
            self.assertEqual(calls, [('compile', 90), ('daemon', 'legacy', 60),
                                     ('compile', 90), ('daemon', 'pair_first', 60)])
            summary = json.loads((root / 'smoke-summary.json').read_text())
            self.assertFalse(summary['parity_established'])
            self.assertFalse(summary['comparison']['safety_or_gameplay_parity_established'])

    def test_insufficient_deadline_refuses_before_staging(self):
        fake = {'runner_limits': limits, 'pair_binding': None, 'pair_materialize': None,
                'pair_receipt': None, 'pair_stage': None}
        shared = types.SimpleNamespace(require=require)
        args = types.SimpleNamespace(suite='pair05', work_deadline=time.monotonic()+100)
        with patch.object(worker, 'modules', return_value=fake), self.assertRaises(ValueError):
            worker.run(shared, args, None, None, None, None, {}, {}, {}, time.monotonic(), None, None, None)

if __name__ == '__main__':
    unittest.main()
