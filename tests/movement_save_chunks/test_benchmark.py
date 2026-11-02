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
            self.assertEqual(baseline, bench.restore_preflight_reference_keys(original.decode()).encode())
            self.assertEqual(receipt['sources'][name], hashlib.sha256(candidate).hexdigest())
            self.assertEqual(receipt['baseline_sources'][name], hashlib.sha256(baseline).hexdigest())
            self.assertEqual(len(receipt['cases']), 18)
            self.assertTrue(receipt['comparative'])
            for path in bench.FILES:
                if path != name: self.assertEqual((Path(folder) / path).read_bytes(), (Path(folder) / 'baseline-source' / path).read_bytes())
            functions = 'code/modules/persistence/functions.dm'
            self.assertEqual((Path(folder) / functions).read_bytes(), (ROOT / functions).read_bytes())
            self.assertEqual((Path(folder) / 'baseline-source' / functions).read_text(), (ROOT / functions).read_text())
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

    def test_phase_contract_requires_all_repeats_and_staged_baseline(self):
        rows = [dict(attempt=i, phase='after_refusal_cleanup' if i in (4, 5, 6) else 'after_success_cleanup', baseline=1, roster=0) for i in range(1, 8)]
        rows += [dict(attempt=i, phase=p, baseline=1, roster=2) for i in range(1, 8) for p in ('roster_start', 'roster_end')]
        rows.append(dict(attempt=8, phase='complete', baseline=1, roster=2))
        self.assertTrue(bench.phase_contract(rows, 1))
        self.assertFalse(bench.phase_contract(rows[:-2], 1))
        self.assertTrue(bench.phase_contract([dict(row, roster=2) for row in rows], 1))
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
                rows += [dict(attempt=i, phase=p, baseline=baseline, roster=2) for i in range(1, 8) for p in ('roster_start', 'roster_end')]
                rows.append(dict(attempt=8, phase='complete', baseline=baseline, roster=2))
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

    def test_fixture_baseline_keeps_roster_and_verifies_prior_backup_bytes(self):
        source = (ROOT / 'tests/movement_save_chunks/benchmark.dm').read_text()
        self.assertNotIn('if(benchmark_baseline) return', source)
        self.assertIn('benchmark_phase("roster_start")\n\t. = ..()', source)
        self.assertIn('benchmark_phase("roster_end")', source)
        self.assertIn('benchmark_attempt <= 7', source)
        self.assertIn('benchmark_attempt >= 4 && benchmark_attempt <= 6', source)
        self.assertIn('md5(file(', source)
        self.assertIn('current.len != expected.len', source)
        self.assertIn('current[name] != expected[name]', source)
        self.assertIn('OpenPort("none")', source)


class BudgetReportingTests(unittest.TestCase):
    CASE = {'count': 64, 'payload': 1024, 'baseline': 0}
    FIXTURE = ROOT / 'tests/movement_save_chunks/fixtures/capture-budget-e042.txt'

    def retained(self):
        return self.FIXTURE.read_text(encoding='utf-8')

    def observations(self, logs):
        return bench.capture_budget_observations(logs, self.CASE, 'case-01-64-1024-0')

    def test_retained_exception_and_cumulative_counter_have_distinct_scopes(self):
        rows = self.observations({'runtime.log': self.retained()})
        self.assertEqual(len(rows), 1)
        row = rows[0]
        self.assertEqual(row['case_id'], 'case-01-64-1024-0')
        self.assertEqual(row['configuration'], self.CASE)
        self.assertEqual(row['attempt'], 7)
        self.assertEqual(row['metric_status'], 'complete')
        self.assertEqual(row['exception_metrics']['usage_delta'], 10.022)
        self.assertEqual(row['reported_values']['usage_delta'], '10.022')
        self.assertEqual(row['exception_metrics']['work'], 58)
        self.assertEqual(row['cumulative_counter_snapshot']['capture_tick_usage'], 5.986)
        self.assertEqual(row['cumulative_counter_snapshot']['attempt'], 7)
        self.assertIn('not the failing chunk peak', row['counter_scope'])
        self.assertIn('usage_delta=10.022', row['raw_exception'])

    def test_context_never_leaks_between_log_streams(self):
        failure = self.retained().splitlines()[-1]
        rows = self.observations({'runtime.log': self.retained(), 'errors.txt': failure})
        self.assertEqual([r['attempt'] for r in rows], [7, None])
        self.assertIsNone(rows[1]['cumulative_counter_snapshot'])
        self.assertEqual(rows[1]['configuration'], self.CASE)

    def test_mismatched_malformed_or_invalid_phase_clears_context(self):
        failure = self.retained().splitlines()[-1]
        for phase in (
            'BENCHMARK_PHASE not-json',
            'BENCHMARK_PHASE ' + json.dumps(dict(attempt=7, baseline=1, phase='before_save')),
            'BENCHMARK_PHASE ' + json.dumps(dict(attempt='7', baseline=0, phase='before_save')),
            'BENCHMARK_PHASE ' + json.dumps(dict(attempt=8, baseline=0, phase='complete')),
            'BENCHMARK_PHASE []',
            'BENCHMARK_PHASE ' + json.dumps(dict(attempt=7, baseline=0, phase=[])),
            'BENCHMARK_PHASE ' + json.dumps(dict(attempt=7, baseline=0, phase='unknown')),
        ):
            with self.subTest(phase=phase):
                rows = self.observations({'runtime.log': self.retained() + '\n' + phase + '\n' + failure})
                self.assertIsNone(rows[-1]['attempt'])

    def test_incomplete_nonfinite_and_duplicate_metrics_stay_visible(self):
        for broken in (
            self.retained().replace('usage_delta=10.022', 'usage_delta=NaN'),
            self.retained().replace('start_usage=59.292', ''),
            self.retained().replace('usage_delta=10.022', 'usage_delta=10.022 usage_delta=0'),
            self.retained().replace('usage_delta=10.022', 'usage_delta=1e999'),
        ):
            with self.subTest(broken=broken):
                row = self.observations({'runtime.log': broken})[0]
                self.assertEqual(row['metric_status'], 'incomplete_or_invalid')
                self.assertIn('Moving save chunk exceeded', row['raw_exception'])

    def test_duplicate_streams_are_separate_labelled_observations(self):
        rows = self.observations({'daemon.log': self.retained(), 'runtime.log': self.retained()})
        self.assertEqual(len(rows), 2)
        self.assertEqual([r['log_name'] for r in rows], ['daemon.log', 'runtime.log'])
        self.assertEqual([r['attempt'] for r in rows], [7, 7])

    def complete_phases(self):
        rows = [dict(attempt=i, phase='after_refusal_cleanup' if i in (4, 5, 6) else 'after_success_cleanup', baseline=0, capture_tick_usage=5.986)
                for i in range(1, 8)]
        rows += [dict(attempt=i, phase=p, baseline=0) for i in range(1, 8) for p in ('roster_start', 'roster_end')]
        rows.append(dict(attempt=8, phase='complete', baseline=0))
        return '\n'.join('BENCHMARK_PHASE ' + json.dumps(row) for row in rows) + '\n'

    def offline_result(self, log, marker, returncode=0):
        # One injected case drives the real post-run classifier; no tool executes.
        def run(command, cwd, prefix, limits, deadline):
            if prefix == 'compile':
                (cwd / 'compile.log').write_text('DM compiler version 516.1688\nbenchmark.dmb - 0 errors, 0 warnings\n')
                (cwd / 'benchmark.dmb').write_bytes(b'offline fake, never executable')
                code = 0
            else:
                (cwd / 'runtime.log').write_text(log, encoding='utf-8')
                (cwd / 'result.txt').write_text(marker)
                code = returncode
            return dict(status='exited', returncode=code, peaks={'rss_bytes': 1024}, samples=1)
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            output = root / 'output'
            bench.prepare(output)
            receipt = json.loads((output / 'receipt.json').read_text())
            receipt['cases'] = [dict(self.CASE)]
            (output / 'receipt.json').write_text(json.dumps(receipt))
            binaries = root / 'bin'
            binaries.mkdir()
            for name in ('DreamMaker', 'DreamDaemon'):
                (binaries / name).touch()
            with patch.object(bench.sys, 'platform', 'linux'), patch.object(bench, 'verify_runtime', return_value={'version': '516.1688'}), patch.object(bench, 'run_monitored', side_effect=run), patch.object(bench.subprocess, 'Popen', side_effect=AssertionError('No native execution')) as spawn:
                receipt = bench.run_native(output, binaries, root / 'pinned.zip', bench.Limits())
                spawn.assert_not_called()
            return receipt['results'][0], receipt['execution']

    def test_real_classifier_retains_both_metrics_and_original_failure(self):
        row, execution = self.offline_result(self.retained(), 'FAIL')
        self.assertFalse(row['passed'])
        self.assertEqual(execution, 'failed_or_incomplete')
        self.assertEqual(row['capture_budget_observations'][0]['attempt'], 7)
        self.assertEqual(row['capture_budget_observations'][0]['exception_metrics']['usage_delta'], 10.022)
        self.assertEqual(row['capture_budget_observations'][0]['cumulative_counter_snapshot']['capture_tick_usage'], 5.986)

    def test_reporting_does_not_relax_any_classification_failure(self):
        full = self.complete_phases()
        for log, marker, code in (
            (full, 'FAIL', 0),
            (full + self.retained(), 'PASS', 0),
            (full + self.retained().replace('usage_delta=10.022', 'usage_delta=NaN'), 'PASS', 0),
            (full + self.retained().replace('5.986', '0.001'), 'PASS', 0),
            (full, 'PASS', 1),
        ):
            with self.subTest(marker=marker, code=code, has_exception='FAIL:' in log):
                row, execution = self.offline_result(log, marker, code)
                self.assertTrue(row['phase_contract'])  # Isolate verdict gates from incomplete phases.
                self.assertFalse(row['passed'])
                self.assertEqual(execution, 'failed_or_incomplete')

    def test_complete_positive_has_no_breach_observation(self):
        row, execution = self.offline_result(self.complete_phases(), 'PASS')
        self.assertTrue(row['passed'])
        self.assertEqual(execution, 'passed')
        self.assertEqual(row['capture_budget_observations'], [])


if __name__ == '__main__': unittest.main()
