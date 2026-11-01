"""Offline-only scale adapter controls; every native launch is injected."""
import json
import os
from pathlib import Path
import copy
import tempfile
import time
from types import SimpleNamespace
import unittest
from unittest import mock

import human_scale_run as runner
import human_scale_stage as stage

HEAD = 'a' * 40
SCOPE = 'b' * 64
GENERATION = 'round-v1:' + 'c' * 32


def row(phase, variant):
    value = {'head': HEAD, 'phase': phase, 'variant': variant, 'port': 0,
             'byond_version': 516, 'byond_build': 1688, 'error': None,
             'heartbeat_count': 1, 'heartbeat_max_gap_deciseconds': 2,
             'heartbeat_scope': 'post_initialization_setup_save_or_load_and_inspection',
             'setup_deciseconds': 1, 'inspection_deciseconds': 1,
             'world_turfs': 350000, 'world_turfs_basis': 'dimension_product_not_a_restored_turf_scan', 'generation': GENERATION}
    if phase == 'writer':
        value.update(save_deciseconds=2, saved_turfs=350000, setup_humans=32, setup_ground=5000,
                     serialization_and_flush_deciseconds=1, geometry_metrics=None,
                     saved_turf_slot_check='positive_integer_refs_not_unique_or_type_verified')
        if variant == 'enabled':
            value.update(human_candidate_checks_deciseconds=1)
    else:
        value.update(load_deciseconds=2, restored_humans=32, restored_ground=5000)
    return value


class ScaleContracts(unittest.TestCase):
    def test_fixed_map_adaptation_and_anchor_failure(self):
        original = (stage.ROOT / 'tests/human_subtile/probe.dm').read_text(encoding='utf-8')
        adapted = stage.adapt_probe(original)
        self.assertIn('\tmaxx = 700\n', adapted)
        self.assertIn('\tmaxy = 500\n', adapted)
        self.assertIn('\tmaxz = 1\n', adapted)
        self.assertNotIn('/world/New()', adapted)
        with self.assertRaisesRegex(ValueError, 'width'):
            stage.adapt_probe(original.replace('\tmaxx = 18\n', '\tmaxx = 19\n'))

    def test_instrumentation_preserves_guards_and_exact_anchors(self):
        source = (stage.ROOT / 'code/modules/persistence/saving.dm').read_text(encoding='utf-8')
        adapted = stage.instrument_saver(source)
        self.assertEqual(adapted.count('human_scale_serialization_start = world.realtime'), 1)
        self.assertEqual(adapted.count('human_scale_serialization_end = world.realtime'), 1)
        self.assertEqual(adapted.count('human_scale_human_checks_start = world.realtime'), 1)
        self.assertEqual(adapted.count('human_scale_human_checks_end = world.realtime'), 1)
        self.assertIn('var/deadline = world.time + 1200', adapted)
        self.assertIn('if(world.time >= deadline', adapted)
        with self.assertRaisesRegex(ValueError, 'level flush'):
            stage.instrument_saver(source.replace('\t\tsavefile.Flush()\n', '\t\tsavefile.Flush() // drift\n', 1))

    def test_staging_rejects_fixture_or_scope_drift_without_native_process(self):
        scope = stage.review_scope()
        def fake_prepare(root, output, suite):
            tree = output / 'stage'
            probe = tree / 'tests/human_subtile/probe.dm'
            saver = tree / 'code/modules/persistence/saving.dm'
            probe.parent.mkdir(parents=True)
            saver.parent.mkdir(parents=True)
            probe.write_bytes((root / 'tests/human_subtile/probe.dm').read_bytes())
            saver.write_bytes((root / 'code/modules/persistence/saving.dm').read_bytes())
            (tree / 'human_subtile.dme').write_text('// synthetic DME\n')
            return {'head': HEAD, 'dme': 'stage/human_subtile.dme'}
        fake_spec = SimpleNamespace(loader=SimpleNamespace(exec_module=lambda module: None))
        fake_module = SimpleNamespace(prepare=fake_prepare)
        corrupt = copy.deepcopy(scope)
        corrupt['files']['tests/movement_save_chunks/human_scale_probe.dm']['sha256'] = '0' * 64
        with tempfile.TemporaryDirectory() as directory, \
             mock.patch.object(stage.importlib.util, 'spec_from_file_location', return_value=fake_spec), \
             mock.patch.object(stage.importlib.util, 'module_from_spec', return_value=fake_module):
            with mock.patch.object(stage, 'review_scope', return_value=corrupt):
                with self.assertRaisesRegex(ValueError, 'fixture changed'):
                    stage.prepare(Path(directory) / 'fixture-drift', HEAD, scope['sha256'])
            with mock.patch.object(stage, 'review_scope', side_effect=[scope, {'sha256':'f' * 64}]):
                with self.assertRaisesRegex(ValueError, 'scope changed while staging'):
                    stage.prepare(Path(directory) / 'scope-drift', HEAD, scope['sha256'])

    def test_scope_covers_wrapper_driver_probe_and_dependencies(self):
        for path in ('.github/workflows/moving-save-chunks.yml', 'scripts/travis_pre_byond.sh',
                     'tests/movement_save_chunks/human_scale_run.py',
                     'tests/movement_save_chunks/human_scale_probe.dm',
                     'tests/human_subtile/run.py', 'tools/byond/version.json'):
            self.assertIn(path, stage.SCOPE_INPUTS)
        self.assertEqual(len(stage.SCOPE_INPUTS), len(set(stage.SCOPE_INPUTS)))

    def test_probe_has_exact_counts_no_client_and_real_roundtrip(self):
        text = (stage.HERE / 'human_scale_probe.dm').read_text(encoding='utf-8')
        for value in ('350000', '5000', '32', 'map_storage.Save_World()', 'map_storage.Load_World()',
                      'human_scale_count_saved_turfs()', 'scale_ground_exact_position',
                      'scale_world_human_count', 'human_subtile_same', 'OpenPort("none")',
                      'human-scale-entry.json', 'scale_variant_binding', 'ref != round(ref)',
                      'positive_integer_refs_not_unique_or_type_verified',
                      'dimension_product_not_a_restored_turf_scan',
                      'post_initialization_setup_save_or_load_and_inspection'):
            self.assertIn(value, text)
        self.assertNotIn('world.Export', text)
        self.assertNotIn('persistence_world_operation', text)

    def test_hosted_temporary_output_and_disk_fail_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            target = root / 'fresh'
            env = {'GITHUB_ACTIONS': 'true', 'RUNNER_TEMP': str(root)}
            self.assertEqual(runner.checked_output(target, env), target)
            with self.assertRaisesRegex(RuntimeError, 'hosted'):
                runner.checked_output(target, {'RUNNER_TEMP': str(root)})
            with self.assertRaisesRegex(RuntimeError, 'direct runner-temp'):
                runner.checked_output(root / 'nested' / 'new', env)
            target.mkdir()
            with self.assertRaisesRegex(RuntimeError, 'already exists'):
                runner.checked_output(target, env)
            with mock.patch.object(runner.shutil, 'disk_usage', return_value=mock.Mock(free=runner.MIN_FREE_START - 1)):
                with self.assertRaisesRegex(RuntimeError, 'insufficient'):
                    runner.free_space(root, runner.MIN_FREE_START)

    def test_review_identity_and_dirty_untracked_rejected_before_stage(self):
        with mock.patch.object(runner.subprocess, 'check_output', side_effect=[(HEAD + '\n').encode(), b'']), \
             mock.patch.object(runner.subprocess, 'run', return_value=mock.Mock(returncode=0)), \
             mock.patch.object(stage, 'review_scope', return_value={'sha256': SCOPE}):
            self.assertEqual(runner.verify_review(HEAD, SCOPE)['sha256'], SCOPE)
        with mock.patch.object(runner.subprocess, 'check_output', return_value=('d' * 40).encode()), \
             mock.patch.object(stage, 'prepare') as prepare:
            with self.assertRaisesRegex(RuntimeError, 'head mismatch'):
                runner.verify_review(HEAD, SCOPE)
            prepare.assert_not_called()
        with mock.patch.object(runner.subprocess, 'check_output', return_value=HEAD.encode()), \
             mock.patch.object(runner.subprocess, 'run', return_value=mock.Mock(returncode=1)):
            with self.assertRaisesRegex(RuntimeError, 'dirty'):
                runner.verify_review(HEAD, SCOPE)
        with mock.patch.object(runner.subprocess, 'check_output', side_effect=[HEAD.encode(), b'unknown\0']), \
             mock.patch.object(runner.subprocess, 'run', return_value=mock.Mock(returncode=0)):
            with self.assertRaisesRegex(RuntimeError, 'untracked'):
                runner.verify_review(HEAD, SCOPE)
        with mock.patch.object(runner.subprocess, 'check_output', side_effect=[HEAD.encode(), b'BYOND/pinned.zip\0BYOND/byond/bin/DreamDaemon\0']), \
             mock.patch.object(runner.subprocess, 'run', return_value=mock.Mock(returncode=0)), \
             mock.patch.object(stage, 'review_scope', return_value={'sha256': SCOPE}):
            self.assertEqual(runner.verify_review(HEAD, SCOPE)['sha256'], SCOPE)

    def test_runtime_is_bound_to_fixed_bootstrap_paths(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            binary_dir = root / 'BYOND/byond/bin'
            binary_dir.mkdir(parents=True)
            archive = root / 'BYOND/pinned.zip'
            archive.write_bytes(b'not executed; identity is separately mocked')
            with mock.patch.object(runner, 'ROOT', root):
                self.assertEqual(runner.pinned_runtime_paths(binary_dir, archive), (binary_dir, archive))
                with self.assertRaisesRegex(RuntimeError, 'noncanonical'):
                    runner.pinned_runtime_paths(root, archive)

    def test_rss_reconciliation_never_accepts_unmeasured_live_child(self):
        ticks = iter([0.0] + [0.001 * i for i in range(1, 100)])
        samples = {'count': 1, 'peak_rss': 64}
        with mock.patch.object(runner.common, 'child_exited_unreaped', return_value=False), \
             mock.patch.object(runner.common, 'observed_proc_state', return_value='R'), \
             mock.patch.object(runner.benchmark, 'proc_memory', return_value={}):
            with self.assertRaisesRegex(RuntimeError, 'sampling unavailable'):
                runner.reconcile_rss(42, samples, 0.1, clock=lambda: next(ticks), sleeper=lambda _: None)
        self.assertLessEqual(len(samples['missing_rss_probes']), 10)
        with mock.patch.object(runner.common, 'child_exited_unreaped', return_value=True), \
             mock.patch.object(runner.common, 'observed_proc_state', return_value='Z'):
            witnessed = {'count': 1, 'peak_rss': 64}
            runner.reconcile_rss(42, witnessed, 10, clock=lambda: 0, sleeper=lambda _: None)
            self.assertTrue(witnessed['rss_exit_race'])
        with self.assertRaisesRegex(RuntimeError, 'previously sampled'):
            runner.reconcile_rss(42, {'count': 0, 'peak_rss': 0}, 1, clock=lambda: 0)
        with mock.patch.object(runner.common, 'child_exited_unreaped', return_value=False), \
             mock.patch.object(runner.common, 'observed_proc_state', return_value='R'), \
             mock.patch.object(runner.benchmark, 'proc_memory', return_value={'rss_bytes': 0}):
            ticks = iter([0.0] + [0.001 * i for i in range(1, 150)])
            with self.assertRaisesRegex(RuntimeError, 'sampling unavailable'):
                runner.reconcile_rss(42, {'count': 1, 'peak_rss': 64}, 0.1,
                                     clock=lambda: next(ticks), sleeper=lambda _: None)

    def test_monitor_rejects_overlimit_and_only_records_valid_startup_entry(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            entry = root / 'human-scale-entry.json'
            monitor, samples = runner.monitor_for(root, time.monotonic(), time.monotonic() + 5,
                                                   (HEAD, 'writer', 'disabled'))
            with mock.patch.object(runner, 'free_space', return_value=20 * runner.GIB), \
                 mock.patch.object(runner.common, 'inventory', return_value={}):
                with mock.patch.object(runner.benchmark, 'proc_memory', return_value={'rss_bytes': runner.MEMORY + 1}):
                    with self.assertRaisesRegex(RuntimeError, 'RSS exceeded'):
                        monitor(42, root)
                    self.assertEqual(samples['observations'][-1]['memory']['rss_bytes'], runner.MEMORY + 1)
                with mock.patch.object(runner.benchmark, 'proc_memory', return_value={'rss_bytes': 64, 'hwm_bytes': 96, 'pss_bytes': 48}):
                    entry.write_text('{')
                    monitor(42, root)
                    self.assertIsNone(samples['entry_observed_seconds'])
                    entry.write_text(json.dumps(row('writer', 'disabled')))
                    monitor(42, root)
                    self.assertIsNotNone(samples['entry_observed_seconds'])
                    self.assertEqual(samples['observations'][-1]['memory']['hwm_bytes'], 96)
                    self.assertEqual(samples['observations'][-1]['memory']['pss_bytes'], 48)
                    self.assertEqual(samples['observations'][-1]['free_bytes'], 20 * runner.GIB)
                    self.assertEqual(samples['observations'][-1]['directory_bytes'], 0)
                    self.assertEqual(samples['observations'][-1]['directory_files'], 0)
                with mock.patch.object(runner, 'MAX_MEMORY_OBSERVATIONS', 1):
                    with self.assertRaisesRegex(RuntimeError, 'observation budget'):
                        runner.record_memory(samples, {'rss_bytes': 64}, 1)

    def test_file_copy_and_hash_are_bounded_and_preserve_exact_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'source'
            source.mkdir()
            (source / 'member').write_bytes(b'synthetic bytes')
            deadline = time.monotonic() + 5
            expected = runner.bounded_hashes(source, deadline, 100, 4)
            with mock.patch.object(runner, 'free_space', return_value=20 * runner.GIB):
                copied = runner.copy_tree_bounded(source, root / 'dest', deadline, root, 100, 4)
            self.assertEqual(copied, expected)
            self.assertEqual(runner.bounded_hashes(root / 'dest', deadline, 100, 4), expected)
            with self.assertRaisesRegex(RuntimeError, 'not empty'):
                runner.copy_tree_bounded(source, root / 'dest', deadline, root, 100, 4)
            with self.assertRaisesRegex(RuntimeError, 'deadline'):
                runner.bounded_digest(source / 'member', time.monotonic() - 1)
            with mock.patch.object(runner, 'FILE_BYTES', 2):
                with self.assertRaisesRegex(RuntimeError, 'per-file'):
                    runner.bounded_digest(source / 'member', deadline)

    def test_child_limits_are_installed_and_monitor_trace_is_retained(self):
        fake = SimpleNamespace(RLIMIT_AS=1, RLIMIT_FSIZE=2, setrlimit=mock.Mock())
        with mock.patch.dict('sys.modules', {'resource': fake}):
            runner.bounded_child()
        self.assertEqual(fake.setrlimit.call_args_list, [
            mock.call(1, (runner.MEMORY, runner.MEMORY)),
            mock.call(2, (runner.FILE_BYTES, runner.FILE_BYTES)),
        ])
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            samples = {'count': 1, 'peak_rss': 1, 'entry_observed_seconds': 0.1}
            def injected(command, cwd, name, timeout, **kwargs):
                self.assertEqual(kwargs['preexec_fn'], runner.bounded_child)
                self.assertTrue(kwargs['retain_leader'])
                self.assertNotIn('TEST_SECRET', kwargs['env'])
                kwargs['on_event']('spawn', 123)
                kwargs['on_event']('group_signal_sent', 123)
                kwargs['on_event']('wait', 0)
                return {'returncode': 0}
            with mock.patch.dict(os.environ, {'TEST_SECRET': 'must-not-be-forwarded'}), \
                 mock.patch.object(runner, 'monitor_for', return_value=(lambda *a: None, samples)), \
                 mock.patch.object(runner.common.legacy, 'run_process', side_effect=injected), \
                 mock.patch.object(runner.common, 'inventory', return_value={}):
                runner.launch(['injected-only'], root, 'disabled-writer', 10,
                              time.monotonic() + 20, root, (HEAD, 'writer', 'disabled'))
            trace = json.loads((root / 'disabled-writer-supervision.json').read_text())
            self.assertEqual(trace['status'], 'exited')
            self.assertEqual([e['event'] for e in trace['events']], ['spawn', 'group_signal_sent', 'wait'])

    def test_launch_failure_retains_owned_cleanup_events(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            samples = {'count': 1, 'peak_rss': 1, 'entry_observed_seconds': 0.1}
            def injected(command, cwd, name, timeout, **kwargs):
                kwargs['on_event']('spawn', 123)
                kwargs['on_event']('group_signal_sent', 123)
                kwargs['on_event']('wait', 9)
                raise RuntimeError('injected timeout')
            with mock.patch.object(runner, 'monitor_for', return_value=(lambda *a: None, samples)), \
                 mock.patch.object(runner.common.legacy, 'run_process', side_effect=injected):
                with self.assertRaisesRegex(RuntimeError, 'injected timeout'):
                    runner.launch(['injected-only'], root, 'disabled-writer', 10,
                                  time.monotonic() + 20, root, (HEAD, 'writer', 'disabled'))
            trace = json.loads((root / 'disabled-writer-supervision.json').read_text())
            self.assertEqual(trace['status'], 'failed')
            self.assertEqual(trace['error'], 'injected timeout')
            self.assertEqual([e['event'] for e in trace['events']], ['spawn', 'group_signal_sent', 'wait'])

    def test_receipts_reject_wrong_source_variant_counts_or_times(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'row.json'
            good = row('writer', 'disabled')
            path.write_text(json.dumps(good))
            self.assertEqual(runner.load_receipt(path, HEAD, 'writer', 'disabled')['saved_turfs'], 350000)
            for key, bad in (('head', 'd' * 40), ('variant', 'enabled'), ('saved_turfs', 349999),
                             ('save_deciseconds', -1), ('port', 1), ('heartbeat_count', 0),
                             ('world_turfs_basis', 'verified_restore'), ('saved_turf_slot_check', 'unique'),
                             ('heartbeat_scope', 'save_only')):
                value = dict(good, **{key: bad})
                path.write_text(json.dumps(value))
                with self.subTest(key=key), self.assertRaises(RuntimeError):
                    runner.load_receipt(path, HEAD, 'writer', 'disabled')
            reader = row('reader', 'enabled')
            reader['restored_ground'] = 4999
            path.write_text(json.dumps(reader))
            with self.assertRaisesRegex(RuntimeError, 'object count'):
                runner.load_receipt(path, HEAD, 'reader', 'enabled')
            enabled = row('writer', 'enabled')
            enabled['geometry_metrics'] = {'turfs': 350000}
            path.write_text(json.dumps(enabled))
            with self.assertRaisesRegex(RuntimeError, 'obsolete fractional geometry metrics'):
                runner.load_receipt(path, HEAD, 'writer', 'enabled')

    def exercise_injected_run(self, fail_at=None):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = root / 'evidence'
            native = root / 'tools'
            native.mkdir()
            for name in ('DreamMaker', 'DreamDaemon'):
                (native / name).write_bytes(b'fake tool, never executed')
            calls = []
            def prepare(dest, head, scope):
                source = dest / 'stage'
                (source / 'config').mkdir(parents=True)
                (source / 'config/config.txt').write_bytes(b'')
                for variant in ('disabled', 'enabled'):
                    (source / ('human_scale_' + variant + '.dme')).write_text(variant)
                return {'head': head, 'scope_sha256': scope,
                        'stage_files': runner.common.hashes(source, total_limit=runner.STAGE_BYTES, max_entries=12000)}
            def launch(command, cwd, label, seconds, deadline, byond_bin, entry, source_bytes):
                calls.append((command, label, seconds, entry))
                if label == fail_at:
                    raise RuntimeError('injected failure')
                if entry is None:
                    artifact = Path(command[-1]).with_suffix('.dmb').name
                    (cwd / artifact).write_bytes(b'fake compiled binary')
                    (cwd / 'compile-stdout.log').write_text('DM compiler version 516.1688\n' + artifact + ' - 0 errors, 0 warnings\n')
                    (cwd / 'compile-stderr.log').write_text('')
                else:
                    _, phase, variant = entry
                    if phase == 'writer':
                        (cwd / 'map_saves/save_complete.txt').write_text(GENERATION)
                        (cwd / 'map_saves/1.sav').write_bytes(b'synthetic seed')
                    (cwd / ('human-scale-' + phase + '.json')).write_text(json.dumps(row(phase, variant)))
                return {'returncode': 0, 'timed_out': False}
            with mock.patch.object(runner.sys, 'platform', 'linux'), \
                 mock.patch.object(runner, 'checked_output', return_value=output), \
                 mock.patch.object(runner, 'free_space', return_value=20 * runner.GIB), \
                 mock.patch.object(runner, 'verify_review'), \
                 mock.patch.object(runner, 'pinned_runtime_paths', return_value=(native, root / 'pinned.zip')), \
                 mock.patch.object(runner.stage_adapter, 'prepare', side_effect=prepare), \
                 mock.patch.object(runner.benchmark, 'verify_runtime', return_value={'version': '516.1688'}), \
                 mock.patch.object(runner, 'launch', side_effect=launch):
                if fail_at:
                    with self.assertRaisesRegex(RuntimeError, 'injected failure'):
                        runner.run(output, native, root / 'pinned.zip', HEAD, SCOPE)
                    result = json.loads((output / 'human-scale-run.json').read_text())
                    self.assertEqual(result['execution'], 'failed')
                    self.assertIn('enabled-reader', result['not_started'])
                else:
                    result = runner.run(output, native, root / 'pinned.zip', HEAD, SCOPE)
                    self.assertEqual(result['execution'], 'completed_measurement')
                    self.assertEqual(result['product_acceptance'], 'not_evaluated')
                    self.assertEqual(result['not_started'], [])
                    self.assertEqual([c[1] for c in calls], list(runner.PLAN))
                    self.assertEqual([c[2] for c in calls], [120, 120, 900, 900, 900, 900])
                    for command, _, _, entry in calls[2:]:
                        self.assertIn('127.0.0.1', command)
                        self.assertIn('-nowebclient', command)
                        self.assertEqual(entry[0], HEAD)
            return calls

    def test_fixed_paired_plan_with_injected_processes_only(self):
        calls = self.exercise_injected_run()
        self.assertEqual(len(calls), 6)

    def test_failure_retains_receipt_and_never_starts_remaining_phases(self):
        calls = self.exercise_injected_run(fail_at='disabled-writer')
        self.assertEqual([c[1] for c in calls], list(runner.PLAN[:3]))


if __name__ == '__main__':
    unittest.main()
