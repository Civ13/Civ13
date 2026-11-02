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


if __name__ == '__main__':
    unittest.main()
