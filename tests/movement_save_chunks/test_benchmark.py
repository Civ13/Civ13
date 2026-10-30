"""Offline benchmark safety contracts. Never compiles or starts BYOND."""
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch, Mock

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('movement_memory_benchmark', ROOT / 'tests/movement_save_chunks/benchmark.py')
bench = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = bench
with patch('subprocess.Popen', side_effect=AssertionError('Import must not launch native code')):
    SPEC.loader.exec_module(bench)

class BenchmarkSafetyTests(unittest.TestCase):
    def test_default_prepare_never_launches(self):
        with tempfile.TemporaryDirectory() as folder, patch.object(bench.subprocess, 'Popen', side_effect=AssertionError('Native forbidden')) as native, patch('builtins.print'):
            self.assertEqual(bench.main(['--output', folder]), 0)
            receipt = json.loads((Path(folder) / 'receipt.json').read_text())
            self.assertEqual(receipt['execution'], 'not_run')
            self.assertEqual(receipt['boundaries']['max_concurrency'], 1)
            self.assertFalse(list(Path(folder).rglob('*.dmb')))
            native.assert_not_called()

    def test_candidate_source_unchanged_and_baseline_only_restores_old_keys(self):
        import hashlib
        name = 'code/modules/persistence/saving.dm'
        original = (ROOT / name).read_bytes()
        with tempfile.TemporaryDirectory() as folder:
            receipt = bench.prepare(Path(folder))
            candidate = (Path(folder) / name).read_bytes()
            baseline = (Path(folder) / 'baseline-source' / name).read_bytes()
            self.assertEqual(candidate, original)
            self.assertEqual(baseline, bench.restore_old_identity_keys(name, original.decode()).encode())
            self.assertEqual(receipt['sources'][name], hashlib.sha256(candidate).hexdigest())
            self.assertEqual(receipt['baseline_sources'][name], hashlib.sha256(baseline).hexdigest())
            self.assertEqual(len(receipt['cases']), 18)
            self.assertTrue(receipt['comparative'])
            for path in bench.FILES:
                if path not in (name, 'code/modules/persistence/functions.dm'): self.assertEqual((Path(folder) / path).read_bytes(), (Path(folder) / 'baseline-source' / path).read_bytes())
            functions = 'code/modules/persistence/functions.dm'
            self.assertEqual((Path(folder) / functions).read_bytes(), (ROOT / functions).read_bytes())
            self.assertEqual((Path(folder) / 'baseline-source' / functions).read_text(), bench.restore_old_identity_keys(functions, (ROOT / functions).read_text()))
            self.assertFalse(receipt['profile_datums'])
            self.assertEqual(receipt['datum_profile_sites'], {})
        with tempfile.TemporaryDirectory() as folder, patch.object(bench.subprocess, 'Popen', side_effect=AssertionError('Native forbidden')), patch('builtins.print'):
            self.assertEqual(bench.main(['--output', folder, '--diagnostic-subset']), 0)
            receipt = json.loads((Path(folder) / 'receipt.json').read_text())
            self.assertEqual(len(receipt['cases']), 4)
            self.assertFalse(receipt['comparative'])

    def test_prepare_refuses_nonempty_destination(self):
        with tempfile.TemporaryDirectory() as folder:
            (Path(folder) / 'sentinel').write_text('keep')
            with self.assertRaisesRegex(ValueError, 'empty'): bench.prepare(Path(folder))
            self.assertEqual((Path(folder) / 'sentinel').read_text(), 'keep')

    def test_runtime_requires_explicit_archive_and_output(self):
        with patch.object(bench, 'prepare', side_effect=AssertionError('Prepare must not be reached')), patch('sys.stderr'):
            with self.assertRaises(SystemExit): bench.main(['--run-native', '--byond-bin', '/fake'])

    def test_limits_cannot_be_expanded_past_authorized_bounds(self):
        for kwargs in ({'case_seconds': 91}, {'job_seconds': 1201}, {'rss_mib': 1025}, {'sample_ms': 0}):
            with self.subTest(kwargs=kwargs), self.assertRaises(ValueError): bench.Limits(**kwargs).validate()
        self.assertEqual(bench.Limits().validate().rss_mib, 1024)

    def test_matrix_pairs_identical_approved_workloads(self):
        cases = bench.cases()
        self.assertEqual(len(cases), 18)
        for left, right in zip(cases[::2], cases[1::2]):
            self.assertEqual((left['count'], left['payload']), (right['count'], right['payload']))
            self.assertEqual((left['baseline'], right['baseline']), (1, 0))
            self.assertLessEqual(left['count'] * left['payload'], 128 * 1024 * 1024)
            self.assertIn(left['count'], (64, 512, 2048))

    def test_rss_job_and_case_boundaries_have_named_failures(self):
        limits = bench.Limits()
        self.assertEqual(bench.limit_reason(1200, 1190, 1200, 0, limits), 'job_timeout')
        self.assertEqual(bench.limit_reason(90, 0, 1200, 0, limits), 'case_timeout')
        self.assertEqual(bench.limit_reason(1, 0, 1200, 1024**3 + 1, limits), 'rss_limit')
        self.assertIsNone(bench.limit_reason(1, 0, 1200, 1024**3, limits))

    def test_private_and_highwater_are_not_conflated(self):
        with tempfile.TemporaryDirectory() as folder:
            pid = Path(folder) / '42'; pid.mkdir()
            (pid / 'status').write_text('VmRSS:\t100 kB\nVmHWM:\t200 kB\nVmSize:\t900 kB\n')
            (pid / 'smaps_rollup').write_text('Pss: 80 kB\nPrivate_Clean: 10 kB\nPrivate_Dirty: 20 kB\n')
            values = bench.proc_memory(42, Path(folder))
            self.assertEqual(values['rss_bytes'], 100 * 1024)
            self.assertEqual(values['hwm_bytes'], 200 * 1024)
            self.assertEqual(values['private_bytes'], 30 * 1024)
            self.assertEqual(values['pss_bytes'], 80 * 1024)

    def test_hard_address_space_bound_only_invokes_child_hook(self):
        with patch('resource.setrlimit') as limit:
            bench.bound_address_space(1024**3)
            self.assertEqual(limit.call_args.args[1], (1024**3, 1024**3))

    def test_resource_failure_kills_only_the_spawned_child_and_retains_samples(self):
        child = Mock(pid=42, returncode=-9)
        child.poll.side_effect = [None, -9]
        with tempfile.TemporaryDirectory() as folder, patch.object(bench.subprocess, 'Popen', return_value=child) as spawn, patch.object(bench, 'proc_memory', return_value={'rss_bytes': 1024**3 + 1}), patch.object(bench.time, 'monotonic', side_effect=[0, 1, 2]):
            result = bench.run_monitored(['fake-daemon'], Path(folder), 'daemon', bench.Limits(), 1200)
            self.assertEqual(result['status'], 'rss_limit')
            child.kill.assert_called_once(); child.wait.assert_called_once()
            self.assertEqual(result['pid'], 42)
            self.assertEqual(len((Path(folder) / 'daemon-memory.jsonl').read_text().splitlines()), 1)
            self.assertTrue((Path(folder) / 'daemon-summary.json').exists())
            self.assertTrue(callable(spawn.call_args.kwargs['preexec_fn']))

    def test_exhausted_job_never_spawns(self):
        with tempfile.TemporaryDirectory() as folder, patch.object(bench.subprocess, 'Popen', side_effect=AssertionError('No spawn')), patch.object(bench.time, 'monotonic', return_value=1200):
            result = bench.run_monitored(['never'], Path(folder), 'daemon', bench.Limits(), 1200)
            self.assertEqual(result['status'], 'not_started_job_timeout')
            self.assertTrue((Path(folder) / 'daemon-summary.json').exists())
            self.assertEqual((Path(folder) / 'daemon.log').read_text(), '')

    def test_missing_rss_terminates_without_claiming_memory_pass(self):
        child = Mock(pid=42, returncode=-9)
        child.poll.side_effect = [None, -9]
        with tempfile.TemporaryDirectory() as folder, patch.object(bench.subprocess, 'Popen', return_value=child), patch.object(bench, 'proc_memory', return_value={}), patch.object(bench.time, 'monotonic', side_effect=[0, 1, 2]):
            result = bench.run_monitored(['fake'], Path(folder), 'daemon', bench.Limits(), 1200)
            self.assertEqual(result['status'], 'memory_sampling_unavailable')
            child.kill.assert_called_once()

    def test_missing_final_sample_accepts_only_conclusive_clean_exit_with_prior_rss(self):
        for final_code, prior_rss, deadline, expected in (
            (0, True, 1200, 'exited'),
            (-9, True, 1200, 'memory_sampling_unavailable'),
            (0, False, 1200, 'memory_sampling_unavailable'),
            (0, True, 1, 'job_timeout'),
        ):
            with self.subTest(final_code=final_code, prior_rss=prior_rss, deadline=deadline):
                child = Mock(pid=42, returncode=final_code)
                child.poll.side_effect = [None, None, final_code]
                memories = [{'rss_bytes': 1024} if prior_rss else {}, {}]
                with tempfile.TemporaryDirectory() as folder, patch.object(bench.subprocess, 'Popen', return_value=child), patch.object(bench, 'proc_memory', side_effect=memories), patch.object(bench.time, 'monotonic', side_effect=[0, 0.1, 1, 1.01]), patch.object(bench.time, 'sleep'):
                    result = bench.run_monitored(['fake'], Path(folder), 'daemon', bench.Limits(), deadline)
                    self.assertEqual(result['status'], expected)
                    self.assertEqual(result.get('sampling_exit_race', False), expected == 'exited')
                    if expected == 'exited': self.assertEqual(result['sampling_observed_reason'], 'memory_sampling_unavailable')
                    child.kill.assert_called_once()
                    child.wait.assert_called_once()
                    self.assertEqual(result['samples'], 2)

    def test_native_diagnostic_markers_are_all_refused(self):
        for marker in ('BUG: invariant', 'Badref', 'bad ref', 'Bad loc', 'Unhandled exception', 'Runtime error:', '## ERROR:', 'FAIL:'):
            with self.subTest(marker=marker): self.assertIsNotNone(bench.DIAGNOSTIC.search(marker))

    def test_phase_contract_requires_all_repeats_and_real_baseline(self):
        rows = [dict(attempt=i, phase='after_refusal_cleanup' if i in (4, 5, 6) else 'after_success_cleanup', baseline=1, roster=0) for i in range(1, 8)]
        rows.append(dict(attempt=8, phase='complete', baseline=1, roster=0))
        self.assertTrue(bench.phase_contract(rows, 1))
        self.assertFalse(bench.phase_contract(rows[:-2], 1))
        self.assertFalse(bench.phase_contract([dict(row, roster=2) for row in rows], 1))
        self.assertFalse(bench.phase_contract(rows, 0))

    def test_every_compile_and_daemon_launch_reverifies_exact_runtime(self):
        events = []
        def verify(bin_dir, archive):
            events.append('verify')
            return {'version': '516.1688', 'identity_basis': 'mock-exact-archive'}
        def run(command, cwd, prefix, limits, deadline):
            events.append('launch')
            if prefix == 'compile':
                (cwd / 'compile.log').write_text('DM compiler version 516.1688\nbenchmark.dmb - 0 errors, 0 warnings\n')
                (cwd / 'benchmark.dmb').write_bytes(b'not executable - offline test')
            else:
                baseline = int(dict(pair.split('=') for pair in command[-1].split('&'))['baseline'])
                rows = [dict(attempt=i, phase='after_refusal_cleanup' if i in (4, 5, 6) else 'after_success_cleanup', baseline=baseline, roster=0) for i in range(1, 8)]
                rows.append(dict(attempt=8, phase='complete', baseline=baseline, roster=0))
                (cwd / 'daemon.log').write_text('\n'.join('BENCHMARK_PHASE ' + json.dumps(row) for row in rows))
                (cwd / 'result.txt').write_text('PASS')
            return {'status': 'exited', 'returncode': 0, 'peaks': {'rss_bytes': 1024}, 'samples': 1}
        with tempfile.TemporaryDirectory() as root:
            output = Path(root) / 'output'; bench.prepare(output)
            binaries = Path(root) / 'bin'; binaries.mkdir()
            (binaries / 'DreamMaker').touch(); (binaries / 'DreamDaemon').touch()
            with patch.object(bench, 'verify_runtime', side_effect=verify), patch.object(bench, 'run_monitored', side_effect=run), patch.object(bench.subprocess, 'Popen', side_effect=AssertionError('Native forbidden')):
                receipt = bench.run_native(output, binaries, Path(root) / 'pinned.zip', bench.Limits())
            self.assertEqual(events, ['verify', 'launch'] * 20)
            self.assertEqual(receipt['execution'], 'passed')
            self.assertEqual(receipt['memory_acceptance'], 'not_established')
            self.assertEqual(len(receipt['results']), 18)

    def test_compiler_banner_alone_is_not_a_success(self):
        with tempfile.TemporaryDirectory() as folder:
            dmb = Path(folder) / 'benchmark.dmb'; dmb.touch()
            log = 'DM compiler version 516.1688\nbenchmark.dmb - 0 errors, 0 warnings\n'
            self.assertFalse(bench.compile_ok({'status': 'exited', 'returncode': 1}, log, dmb))
            self.assertFalse(bench.compile_ok({'status': 'rss_limit', 'returncode': 0}, log, dmb))
            self.assertFalse(bench.compile_ok({'status': 'exited', 'returncode': 0}, log.replace('1688', '1681'), dmb))
            self.assertFalse(bench.compile_ok({'status': 'exited', 'returncode': 0}, log.replace('1688', '16880'), dmb))
            self.assertFalse(bench.compile_ok({'status': 'exited', 'returncode': 0}, log + 'DM compiler version 516.1688\n', dmb))
            self.assertTrue(bench.compile_ok({'status': 'exited', 'returncode': 0}, log, dmb))

    def test_fixture_baseline_disables_roster_and_verifies_prior_backup_bytes(self):
        source = (ROOT / 'tests/movement_save_chunks/benchmark.dm').read_text()
        self.assertIn('if(benchmark_baseline) return\n\t. = ..()', source)
        self.assertIn('benchmark_attempt <= 7', source)
        self.assertIn('benchmark_attempt >= 4 && benchmark_attempt <= 6', source)
        self.assertIn('md5(file(', source)
        self.assertIn('current.len != expected.len', source)
        self.assertIn('current[name] != expected[name]', source)
        self.assertIn('OpenPort("none")', source)

if __name__ == '__main__': unittest.main()
