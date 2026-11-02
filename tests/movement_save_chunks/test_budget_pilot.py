"""Offline fixed-pilot controls. All compiler/daemon calls are injected."""
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
SPEC = importlib.util.spec_from_file_location('fixed_budget_pilot', Path(__file__).with_name('budget_pilot.py'))
pilot = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = pilot
with patch('subprocess.Popen', side_effect=AssertionError('Native forbidden')):
    SPEC.loader.exec_module(pilot)


class PilotTests(unittest.TestCase):
    def trace(self, baseline):
        rows = [dict(attempt=i, phase='after_refusal_cleanup' if i in (4, 5, 6) else 'after_success_cleanup', baseline=baseline)
                for i in range(1, 8)]
        rows += [dict(attempt=i, phase=p, baseline=baseline) for i in range(1, 8) for p in ('roster_start', 'roster_end')]
        rows.append(dict(attempt=8, phase='complete', baseline=baseline))
        return '\n'.join('BENCHMARK_PHASE ' + json.dumps(r) for r in rows)

    def exercise(self, *, budget_at=None, status=None, clock=None, identity_fail=None, replace_failure=None, until='2099-01-01T00:00:00Z'):
        launches = []
        identities = []
        def verify(*args):
            identities.append(True)
            if identity_fail == len(identities):
                raise ValueError('Pinned identity mismatch')
            return dict(version='516.1688')
        def run(command, cwd, prefix, limits, deadline):
            launches.append((prefix, command, vars(limits).copy(), deadline))
            code = 0
            state = 'exited'
            if prefix == 'compile':
                (cwd / 'compile.log').write_text('DM compiler version 516.1688\nbenchmark.dmb - 0 errors, 0 warnings\n')
                (cwd / 'benchmark.dmb').write_bytes(b'offline fake')
            else:
                index = len([r for r in launches if r[0] == 'daemon']) - 1
                baseline = int(command[-1].split('baseline=')[1])
                text, marker = self.trace(baseline), 'PASS'
                if index == budget_at:
                    text = Path(__file__).with_name('fixtures').joinpath('capture-budget-e042.txt').read_text()
                    marker = 'FAIL'
                    if replace_failure:
                        text = text.replace(*replace_failure)
                if status:
                    state, code = status, -9
                (cwd / 'runtime.log').write_text(text)
                (cwd / 'result.txt').write_text(marker)
            return dict(status=state, returncode=code, peaks={'rss_bytes': 1024}, samples=1)
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            output = root / 'output'
            pilot.prepare(output)
            binaries = root / 'bin'; binaries.mkdir()
            for name in ('DreamMaker', 'DreamDaemon'):
                (binaries / name).touch()
            with patch.object(pilot.sys, 'platform', 'linux'), patch.object(pilot.bench, 'verify_runtime', side_effect=verify), patch.object(pilot.bench, 'run_monitored', side_effect=run), patch.object(pilot.bench.subprocess, 'Popen', side_effect=AssertionError('Native forbidden')) as spawn:
                if clock:
                    with patch.object(pilot.time, 'monotonic', side_effect=clock):
                        receipt = pilot.execute(output, binaries, root / 'archive.zip', until)
                else:
                    receipt = pilot.execute(output, binaries, root / 'archive.zip', until)
                spawn.assert_not_called()
            return receipt, launches, identities

    def test_fixed_order_bounded_launches_and_distinct_verdict(self):
        receipt, launches, identities = self.exercise()
        daemons = [r for r in launches if r[0] == 'daemon']
        self.assertEqual(len(launches), 10)
        self.assertEqual(len(identities), 10)
        self.assertEqual([int(r[1][-1].split('baseline=')[1]) for r in daemons], [1,0,0,1,0,1,1,0])
        self.assertTrue(all(r[2] == pilot.LIMITS for r in launches))
        self.assertEqual(receipt['diagnostic_verdict'], 'completed_no_breach_observed')
        self.assertEqual(receipt['execution'], 'diagnostic_only')
        self.assertEqual(receipt['acceptance_status'], 'not_established')
        self.assertEqual(receipt['not_run'], [])
        self.assertEqual(len(pilot.bench.cases()), 18)

    def test_budget_failure_retained_and_no_replacement_runs(self):
        receipt, launches, _ = self.exercise(budget_at=1)
        self.assertEqual(len(launches), 10)
        self.assertEqual(receipt['diagnostic_verdict'], 'completed_with_breaches')
        self.assertFalse(receipt['results'][1]['passed'])
        self.assertEqual(receipt['results'][1]['capture_budget_observations'][0]['exception_metrics']['usage_delta'], 10.022)
        self.assertEqual([r['pilot_index'] for r in receipt['results']], list(range(8)))
        self.assertEqual(receipt['replacements'], 0)

    def test_resource_and_process_failures_stop_remaining_launches(self):
        for status in ('rss_limit', 'case_timeout', 'job_timeout', 'memory_sampling_unavailable', 'process_failed'):
            with self.subTest(status=status):
                receipt, launches, _ = self.exercise(status=status)
                self.assertEqual(len(launches), 3)
                self.assertEqual(receipt['diagnostic_verdict'], 'inconclusive_stopped')
                self.assertEqual(len(receipt['not_run']), 7)
                self.assertFalse(receipt['results'][0]['passed'])

    def test_deadline_after_identity_check_prevents_daemon_launch(self):
        receipt, launches, _ = self.exercise(clock=[0,0,0,0,0,899,900])
        self.assertEqual(len(launches), 2)
        self.assertEqual(receipt['diagnostic_verdict'], 'inconclusive_stopped')
        self.assertEqual(len(receipt['not_run']), 8)

    def test_expired_approval_never_launches(self):
        receipt, launches, _ = self.exercise(until='2020-01-01T00:00:00Z')
        self.assertEqual(launches, [])
        self.assertEqual(receipt['diagnostic_verdict'], 'inconclusive_stopped')

    def test_identity_refusal_stops_without_replacement(self):
        receipt, launches, _ = self.exercise(identity_fail=4)
        self.assertEqual(len(launches), 3)
        self.assertEqual(len(receipt['results']), 1)
        self.assertEqual(len(receipt['not_run']), 7)
        self.assertEqual(receipt['diagnostic_verdict'], 'inconclusive_stopped')

    def test_prepare_only_and_tampered_plan_refused(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(pilot.bench.subprocess, 'Popen', side_effect=AssertionError('Native forbidden')):
            output = Path(tmp) / 'output'
            receipt = pilot.prepare(output)
            self.assertEqual(receipt['diagnostic_verdict'], 'not_run')
            self.assertEqual(receipt['cases'], pilot.plan())
            receipt['limits']['job_seconds'] += 1
            (output / 'receipt.json').write_text(json.dumps(receipt))
            with patch.object(pilot.sys, 'platform', 'linux'), patch.object(pilot.bench, 'run_monitored', side_effect=AssertionError('No launch')):
                with self.assertRaises(ValueError):
                    pilot.execute(output, Path(tmp), Path(tmp)/'archive', '2099-01-01T00:00:00Z')

    def test_other_guard_failures_stop_instead_of_being_repeated(self):
        for replacement in (('tick_delta=0', 'tick_delta=1'),
                            ('usage_delta=10.022', 'usage_delta=NaN'),
                            ('work=58', 'work=8193'),
                            ('total_usage=69.314', 'total_usage=90'),
                            ('elapsed_ds=0', 'elapsed_ds=2')):
            with self.subTest(replacement=replacement):
                receipt, launches, _ = self.exercise(budget_at=1, replace_failure=replacement)
                self.assertEqual(len(launches), 4)
                self.assertEqual(receipt['diagnostic_verdict'], 'inconclusive_stopped')
                self.assertFalse(receipt['results'][1]['passed'])
                self.assertEqual(len(receipt['not_run']), 6)

    def test_native_cli_requires_explicit_new_deadline(self):
        with patch.object(pilot, 'prepare', side_effect=AssertionError('No preparation')):
            with self.assertRaises(SystemExit) as error:
                pilot.main(['--output','unused','--run-native'])
            self.assertEqual(error.exception.code, 2)



class PilotFinalizationTests(unittest.TestCase):
    trace = PilotTests.trace

    def run_fault(self, fault, primary=None):
        primary = primary or OSError('injected orchestration error')
        calls, failures = [], []
        stderr = __import__('io').StringIO()
        if fault == 'persistent_io_and_stderr':
            class BrokenStderr(__import__('io').StringIO):
                def write(self, text):
                    raise OSError('stderr unavailable')
            stderr = BrokenStderr()
        def run(command, cwd, prefix, limits, deadline):
            calls.append(prefix)
            if fault in ('compile_setup', 'compile_popen', 'compile_cleanup') and prefix == 'compile':
                raise primary
            if fault == 'daemon_cleanup' and prefix == 'daemon':
                raise primary
            if prefix == 'compile':
                (cwd / 'compile.log').write_text('DM compiler version 516.1688\nbenchmark.dmb - 0 errors, 0 warnings\n')
                (cwd / 'benchmark.dmb').write_bytes(b'offline fake')
            else:
                baseline = int(command[-1].split('baseline=')[1])
                (cwd / 'runtime.log').write_text(self.trace(baseline))
                (cwd / 'result.txt').write_text('PASS')
            return dict(status='exited', returncode=0, peaks={'rss_bytes': 1024}, samples=1)

        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / 'output'
            pilot.prepare(output)
            real_write = pilot.write
            def write(*args, **kwargs):
                name = args[2] if len(args) > 2 else kwargs.get('name', 'receipt.json')
                if (fault == 'progress_write' or (fault == 'mid_progress_write' and len(calls) == 3)) and name == 'progress.json':
                    raise primary
                if fault == 'final_write' and name == 'receipt.json':
                    raise primary
                return real_write(*args, **kwargs)
            with __import__('contextlib').ExitStack() as stack:
                stack.enter_context(patch.object(pilot.sys, 'platform', 'linux'))
                stack.enter_context(patch.object(pilot.bench, 'verify_runtime', return_value={'version':'516.1688'}))
                stack.enter_context(patch.object(pilot.bench, 'run_monitored', side_effect=run))
                stack.enter_context(patch.object(pilot.bench.subprocess, 'Popen', side_effect=AssertionError('No native execution')))
                stack.enter_context(patch.object(pilot.sys, 'stderr', stderr))
                if fault in ('progress_write', 'mid_progress_write', 'final_write'):
                    stack.enter_context(patch.object(pilot, 'write', side_effect=write))
                if fault == 'copy':
                    stack.enter_context(patch.object(pilot.shutil, 'copy2', side_effect=primary))
                if fault == 'classify':
                    stack.enter_context(patch.object(pilot, 'classify', side_effect=primary))
                if fault in ('persistent_io', 'persistent_io_and_stderr'):
                    errors = [primary, OSError('final receipt write failed'), OSError('recovery write failed')]
                    def broken(*args, **kwargs):
                        error = errors[min(len(failures), 2)]
                        failures.append(error)
                        raise error
                    stack.enter_context(patch.object(pilot, '_atomic_json', side_effect=broken))
                observed = None
                try:
                    pilot.execute(output, Path(tmp), Path(tmp)/'archive.zip', '2099-01-01T00:00:00Z')
                except BaseException as error:
                    observed = error
            saved = json.loads((output/'receipt.json').read_text())
            return primary, observed, saved, calls, stderr.getvalue(), failures

    def test_compile_setup_popen_and_cleanup_exceptions_finalize_and_reraise(self):
        for fault in ('compile_setup', 'compile_popen', 'compile_cleanup'):
            with self.subTest(fault=fault):
                primary, observed, saved, calls, _, _ = self.run_fault(fault)
                self.assertIs(observed, primary)
                self.assertEqual(calls, ['compile'])
                self.assertEqual(saved['diagnostic_verdict'], 'inconclusive_stopped')
                self.assertEqual(len(saved['not_run']), 8)
                self.assertEqual(saved['orchestration_error']['type'], 'OSError')

    def test_daemon_cleanup_exception_marks_outcome_unknown_and_stops(self):
        primary, observed, saved, calls, _, _ = self.run_fault('daemon_cleanup', TimeoutError('kill/wait unconfirmed'))
        self.assertIs(observed, primary)
        self.assertEqual(calls, ['compile','compile','daemon'])
        self.assertFalse(saved['results'][0]['passed'])
        self.assertEqual(saved['results'][0]['status'], 'orchestration_exception')
        self.assertEqual(saved['results'][0]['child_cleanup'], 'unconfirmed')
        self.assertEqual(len(saved['not_run']), 7)
        self.assertEqual(saved['diagnostic_verdict'], 'inconclusive_stopped')

    def test_copy_failure_marks_case_not_run_and_never_launches_daemon(self):
        primary, observed, saved, calls, _, _ = self.run_fault('copy')
        self.assertIs(observed, primary)
        self.assertEqual(calls, ['compile','compile'])
        self.assertEqual(saved['results'], [])
        self.assertEqual(len(saved['not_run']), 8)
        self.assertEqual(saved['active_step']['pilot_index'], 0)
        self.assertFalse(saved['active_step']['launch_attempted'])

    def test_progress_write_failure_has_no_launch_and_finalizes(self):
        primary, observed, saved, calls, _, _ = self.run_fault('progress_write')
        self.assertIs(observed, primary)
        self.assertEqual(calls, [])
        self.assertEqual(saved['diagnostic_verdict'], 'inconclusive_stopped')
        self.assertEqual(len(saved['not_run']), 8)

    def test_final_write_failure_keeps_completed_rows_but_never_reports_success(self):
        primary, observed, saved, calls, _, _ = self.run_fault('final_write')
        self.assertIs(observed, primary)
        self.assertEqual(len(calls), 10)
        self.assertEqual(len(saved['results']), 8)
        self.assertEqual(saved['diagnostic_verdict'], 'inconclusive_stopped')
        self.assertIn('finalization_error', saved)

    def test_persistent_io_keeps_not_run_canonical_and_reports_original_error(self):
        primary, observed, saved, calls, stderr, failures = self.run_fault('persistent_io')
        self.assertIs(observed, primary)
        self.assertEqual(calls, [])
        self.assertEqual(saved['diagnostic_verdict'], 'not_run')
        self.assertNotEqual(saved['diagnostic_verdict'], 'running')
        self.assertEqual(len(failures), 3)
        self.assertIn('inconclusive_stopped', stderr)
        self.assertIn('recovery write failed', stderr)
        self.assertTrue(any('final receipt write failed' in note for note in getattr(primary, '__notes__', [])))

    def test_storage_and_stderr_failure_preserve_secondary_errors_as_notes(self):
        primary, observed, saved, calls, _, _ = self.run_fault('persistent_io_and_stderr')
        self.assertIs(observed, primary)
        self.assertEqual(calls, [])
        self.assertEqual(saved['diagnostic_verdict'], 'not_run')
        notes = '\n'.join(getattr(primary, '__notes__', []))
        self.assertIn('stderr unavailable', notes)
        self.assertIn('recovery write failed', notes)

    def test_final_publication_and_recovery_failures_preserve_first_error(self):
        primary, secondary = OSError('final publication failed'), OSError('recovery failed')
        receipt = dict(execution_started=True, diagnostic_verdict='completed_no_breach_observed')
        stderr = __import__('io').StringIO()
        with patch.object(pilot, 'write', side_effect=primary), patch.object(pilot, '_atomic_json', side_effect=secondary), patch.object(pilot.sys, 'stderr', stderr):
            with self.assertRaises(OSError) as caught:
                pilot._persist_final(Path('unused'), receipt)
        self.assertIs(caught.exception, primary)
        self.assertEqual(receipt['diagnostic_verdict'], 'inconclusive_stopped')
        self.assertIn('recovery failed', '\n'.join(getattr(primary, '__notes__', [])))

    def test_keyboard_interrupt_is_not_hidden_or_followed_by_more_launches(self):
        primary, observed, saved, calls, _, _ = self.run_fault('daemon_cleanup', KeyboardInterrupt('interrupted'))
        self.assertIs(observed, primary)
        self.assertEqual(len(calls), 3)
        self.assertEqual(saved['diagnostic_verdict'], 'inconclusive_stopped')

    def test_prepare_copy_failure_produces_not_run_and_preserves_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp)/'output'
            primary = OSError('source copy failed')
            with patch.object(pilot.bench, 'prepare', side_effect=primary):
                with self.assertRaises(OSError) as caught:
                    pilot.prepare(output)
            self.assertIs(caught.exception, primary)
            saved = json.loads((output/'receipt.json').read_text())
            self.assertEqual(saved['diagnostic_verdict'], 'not_run')
            self.assertEqual(saved['orchestration_error']['message'], 'source copy failed')

    def test_mid_run_receipt_failure_preserves_result_and_stops(self):
        primary, observed, saved, calls, _, _ = self.run_fault('mid_progress_write')
        self.assertIs(observed, primary)
        self.assertEqual(calls, ['compile','compile','daemon'])
        self.assertEqual(len(saved['results']), 1)
        self.assertTrue(saved['results'][0]['passed'])
        self.assertEqual(len(saved['not_run']), 7)
        self.assertEqual(saved['diagnostic_verdict'], 'inconclusive_stopped')

    def test_classification_io_error_is_finalized_and_not_hidden(self):
        primary, observed, saved, calls, _, _ = self.run_fault('classify')
        self.assertIs(observed, primary)
        self.assertEqual(len(calls), 3)
        self.assertFalse(saved['results'][0]['passed'])
        self.assertEqual(saved['results'][0]['returned_summary']['status'], 'exited')
        self.assertEqual(saved['diagnostic_verdict'], 'inconclusive_stopped')

    def test_existing_directory_and_partial_run_cannot_be_resumed(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp)/'output'
            pilot.prepare(output)
            original = (output/'receipt.json').read_bytes()
            with self.assertRaises(FileExistsError):
                pilot.prepare(output)
            self.assertEqual((output/'receipt.json').read_bytes(), original)
            (output/'progress.json').write_text('{"diagnostic_verdict":"running"}')
            with patch.object(pilot.sys, 'platform', 'linux'), patch.object(pilot.bench, 'run_monitored', side_effect=AssertionError('No resume')) as run:
                with self.assertRaises(ValueError):
                    pilot.execute(output, Path(tmp), Path(tmp)/'archive', '2099-01-01T00:00:00Z')
                run.assert_not_called()

    def test_atomic_replace_failure_preserves_previous_receipt(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp)/'output'; pilot.prepare(output)
            original = (output/'receipt.json').read_bytes()
            with patch.object(Path, 'replace', side_effect=OSError('atomic replacement failed')):
                with self.assertRaises(OSError):
                    pilot.write(output, {'diagnostic_verdict':'running'})
            self.assertEqual((output/'receipt.json').read_bytes(), original)
            self.assertTrue(list(output.glob('.receipt.json.*.tmp')))


if __name__ == '__main__':
    unittest.main()
