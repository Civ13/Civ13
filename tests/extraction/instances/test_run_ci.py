"""Offline checks for CI-only native admission and named assertion controls."""
import importlib.util
from pathlib import Path
import tempfile
import types
import unittest
from unittest import mock

SPEC = importlib.util.spec_from_file_location('instance_ci', Path(__file__).with_name('run_ci.py'))
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


class RunnerContracts(unittest.TestCase):
    def setUp(self):
        self.probe = Path(__file__).with_name('probe.dm').read_text(encoding='utf-8')
        self.labels = runner.labels(self.probe)
        self.positive = ''.join('PASS: ' + label + '\n' for label in sorted(self.labels)) + 'INSTANCE PROBE COMPLETE\n'

    def test_positive_and_each_named_target_oracle(self):
        self.assertEqual(runner.verdict(self.positive, self.labels, 'baseline')['assertions'], 35)
        for control, (_, _, label) in runner.CONTROLS.items():
            log = self.positive.replace('PASS: ' + label, 'FAIL: ' + label).replace(
                'INSTANCE PROBE COMPLETE', 'INSTANCE PROBE FAILED: 1')
            self.assertEqual(runner.verdict(log, self.labels, control)['failures'], [label])
            with self.assertRaisesRegex(ValueError, 'exact assertion'):
                runner.verdict(log.replace('FAIL: ' + label, 'PASS: ' + label), self.labels, control)

    def test_missing_duplicate_failures_and_engine_errors_are_not_evidence(self):
        for log in (self.positive.replace('INSTANCE PROBE COMPLETE', ''),
                    self.positive + self.positive.splitlines()[0] + '\n',
                    self.positive.replace('PASS:', 'FAIL:', 1),
                    self.positive + 'runtime error: Bad ref\n',
                    self.positive + 'warning: engine\n',
                    self.positive + 'BUG: engine\n',
                    self.positive + 'Access violation\n',
                    self.positive + 'Out of memory\n',
                    self.positive.replace(self.positive.splitlines()[0] + '\n', '')):
            with self.subTest(log=log[-50:]), self.assertRaises(ValueError):
                runner.verdict(log, self.labels, 'baseline')
        with self.assertRaises(ValueError):
            runner.verdict(self.positive, self.labels, 'overlap')

    def test_control_requires_named_target_and_reports_collateral_separately(self):
        target = runner.CONTROLS['overlap'][2]
        collateral = next(label for label in sorted(self.labels) if label != target)
        log = self.positive.replace('PASS: ' + target, 'FAIL: ' + target).replace(
            'PASS: ' + collateral, 'FAIL: ' + collateral).replace(
            'INSTANCE PROBE COMPLETE', 'INSTANCE PROBE FAILED: 2')
        result = runner.verdict(log, self.labels, 'overlap')
        self.assertEqual(result['expected_target'], target)
        self.assertEqual(result['collateral_failure_labels'], [collateral])
        self.assertEqual(result['oracle'], 'named target required; collateral reported')
        with self.assertRaisesRegex(ValueError, 'exact assertion'):
            runner.verdict(log.replace('FAIL: ' + target, 'PASS: ' + target), self.labels, 'overlap')

    def test_compiler_summary_cannot_hide_diagnostics(self):
        clean = 'DM compiler version 516.1681\nprobe.dmb - 0 errors, 0 warnings\n'
        runner.compiler_verdict(clean)
        for diagnostic in ('runtime error:', 'Bad ref', 'unhandled', 'Traceback', 'segmentation',
                           'fatal', 'error:', 'warning:', 'BUG:', 'access violation', 'out of memory'):
            with self.subTest(diagnostic=diagnostic), self.assertRaisesRegex(ValueError, 'diagnostic'):
                runner.compiler_verdict(clean + diagnostic)
        for log in ('', clean.replace('516.1681', '516.1682'), clean.replace('0 errors', '1 errors')):
            with self.assertRaisesRegex(ValueError, 'banner/result'):
                runner.compiler_verdict(log)

    def test_control_anchors_are_unique_and_source_is_detached(self):
        source = (runner.ROOT / runner.SOURCE).read_text(encoding='utf-8')
        self.assertEqual(runner.mutation(source, 'baseline'), source)
        for control, (anchor, replacement, _) in runner.CONTROLS.items():
            changed = runner.mutation(source, control)
            self.assertNotEqual(changed, source)
            self.assertIn(replacement, changed)
            self.assertIn(anchor, source)
            with self.assertRaisesRegex(ValueError, 'anchor changed'):
                runner.mutation(source + '\n' + anchor, control)

    def test_native_requires_linux_ci_before_preparing_or_spawning(self):
        with mock.patch.object(runner.sys, 'platform', 'win32'), mock.patch.object(runner.subprocess, 'Popen') as spawn:
            with self.assertRaisesRegex(ValueError, 'ephemeral Linux CI'):
                runner.native_gate(Path('unused'), Path('unused'))
            spawn.assert_not_called()

    def test_cli_rejects_local_native_before_preparation(self):
        with mock.patch.object(runner.sys, 'platform', 'win32'), \
                mock.patch.object(runner.sys, 'argv', ['run_ci.py', '--head', 'a' * 40,
                                                     '--output', 'unused', '--byond-bin', 'unused']), \
                mock.patch.object(runner, 'prepare') as prepare, \
                mock.patch.object(runner.subprocess, 'Popen') as spawn:
            with self.assertRaisesRegex(ValueError, 'ephemeral Linux CI'):
                runner.main()
            prepare.assert_not_called()
            spawn.assert_not_called()

    def test_prepare_uses_exact_git_objects_and_never_native_processes(self):
        source = (runner.ROOT / runner.SOURCE).read_bytes()
        with tempfile.TemporaryDirectory() as folder, mock.patch.object(runner, 'committed',
                side_effect=[source, self.probe.encode()]) as committed, mock.patch.object(runner, 'run_bounded') as native:
            output = Path(folder) / 'new'
            manifest, expected = runner.prepare('a' * 40, output)
            self.assertFalse(manifest['native_executed'])
            self.assertEqual(expected, self.labels)
            self.assertEqual(committed.call_args_list[0].args, ('a' * 40, runner.SOURCE))
            self.assertEqual((output / 'baseline/instances.dm').read_bytes(), source)
            self.assertIn('#include "instances.dm"', (output / 'baseline/probe.dme').read_text())
            native.assert_not_called()

    def test_child_group_is_cleaned_before_leader_is_reaped(self):
        fake_resource = types.SimpleNamespace(RLIMIT_AS=1, RLIMIT_CPU=2, RLIMIT_FSIZE=3,
                                             RLIMIT_CORE=4, setrlimit=mock.Mock())
        events = []
        process = mock.Mock(pid=12345, returncode=0)
        process.wait.side_effect = lambda **kwargs: events.append('reap')
        constants = {'P_PID': 1, 'WEXITED': 2, 'WNOHANG': 4, 'WNOWAIT': 8}
        with tempfile.TemporaryDirectory() as folder, mock.patch.dict('sys.modules', resource=fake_resource), \
                mock.patch.object(runner.subprocess, 'Popen', return_value=process) as spawn, \
                mock.patch.multiple(runner.os, create=True, **constants), \
                mock.patch.object(runner.signal, 'SIGKILL', 9, create=True), \
                mock.patch.object(runner.os, 'waitid', create=True,
                                  side_effect=lambda *args: events.append('observe') or object()), \
                mock.patch.object(runner.os, 'killpg', create=True,
                                  side_effect=lambda *args: events.append('kill-group')):
            runner.run_bounded(['mock-only'], Path(folder), 'positive.log', 10, 2, 1024, float('inf'))
            self.assertEqual(events, ['observe', 'kill-group', 'reap'])
            spawn.call_args.kwargs['preexec_fn']()
            self.assertEqual(fake_resource.setrlimit.call_count, 4)
            process.poll.assert_not_called()
            process.returncode = 1
            with self.assertRaisesRegex(ValueError, 'Native process failed'):
                runner.run_bounded(['mock-only'], Path(folder), 'failed.log', 10, 2, 1024, float('inf'))
            events.clear()
            with mock.patch.object(runner.os, 'waitid', return_value=None), \
                    self.assertRaisesRegex(ValueError, 'wall deadline'):
                runner.run_bounded(['mock-only'], Path(folder), 'timeout.log', 10, 2, 1024, 0)
            self.assertEqual(events, ['kill-group', 'reap'])

    def test_workflow_has_independent_bounded_job_and_manual_default_off(self):
        workflow = (runner.ROOT / '.github/workflows/test.yml').read_text()
        guard = ("if: needs.changes.outputs.extensive == 'true' || "
                 "contains(fromJSON(needs.changes.outputs.new_tests), 'tests/extraction') || "
                 "(github.event_name == 'workflow_dispatch' && inputs.extraction_instance_regressions)")
        block = workflow.split('  extraction-instances:\n', 1)[1].split('  # Existing game compilation gate.', 1)[0]
        self.assertEqual(block.count(guard), 2)
        self.assertIn('needs: changes', block)
        self.assertIn('timeout-minutes: 12', block)
        self.assertIn('timeout-minutes: 5', block)
        self.assertIn('timeout-minutes: 6', block)
        self.assertIn('default: false', workflow.split('      extraction_instance_regressions:', 1)[1].split('permissions:', 1)[0])
        for required in ('persist-credentials: false', 'github.event.pull_request.head.sha || github.sha',
                         '--retry 0', '--max-time 60', 'retention-days: 7',
                         'tests/extraction/instances/run_ci.py', '--output "$RUNNER_TEMP/extraction-instances"'):
            self.assertIn(required, block)
        for forbidden in ('travis_pre_byond', 'civ13.dme', 'apt upgrade', 'continue-on-error', '1714', 'D:/'):
            self.assertNotIn(forbidden, block)


if __name__ == '__main__':
    unittest.main()
