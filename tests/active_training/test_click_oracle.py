"""Offline fake-receipt oracle controls; never invoke the native launcher."""
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
spec = importlib.util.spec_from_file_location('verify_training_click', HERE / 'verify_click.py')
oracle = importlib.util.module_from_spec(spec)
spec.loader.exec_module(oracle)
HEAD = 'a' * 40


class ClickOracleTests(unittest.TestCase):
    def make(self, folder, original=False):
        def write(name, value):
            (folder / name).write_text(json.dumps(value), encoding='utf-8')
        write('metadata.json', {'checkout_head': HEAD, 'control': 'original-silence' if original else 'candidate',
              'original_control_commit': oracle.ORIGINAL if original else None,
              'original_control_sha256': oracle.ORIGINAL_SHA256 if original else None})
        failed = oracle.SILENT_FAILURES if original else set()
        checks = [{'label': label, 'passed': int(label not in failed)} for label in oracle.CHECKS]
        write('result.json', {'commit': HEAD, 'byond_build': 1681, 'checks': checks,
              'cases': [{'case': name, 'messages': [], 'time': i} for i, name in enumerate(oracle.CASES)]})
        for phase, limit in [('compile', 180), ('runtime', 100)]:
            write(phase + '-status.json', {'returncode': 0, 'timed_out': False,
                  'wall_seconds': 8 if phase == 'compile' else 50, 'deadline_seconds': limit})
        (folder / 'compile.log').write_text('DM compiler version 516.1681\nprobe.dmb - 0 errors, 0 warnings\n')
        log = '\n'.join(('FAIL: ' if row['label'] in failed else 'PASS ') + row['label'] for row in checks) + '\n'
        (folder / 'runtime.log').write_text(log)
        (folder / 'runtime-stdout.log').write_text('')
        (folder / 'runtime-stderr.log').write_text('')

    def change(self, folder, name, mutate):
        path = folder / name
        value = json.loads(path.read_text())
        mutate(value)
        path.write_text(json.dumps(value))

    def test_candidate_requires_complete_success(self):
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            self.make(folder)
            result = oracle.verify(folder, HEAD)
            self.assertEqual(result['checks'], 21)
            self.assertEqual(result['expected_feedback_failures'], 0)

    def test_original_exact_feedback_failures_and_reward_pass_are_accepted(self):
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            self.make(folder, True)
            self.assertEqual(oracle.verify(folder, HEAD, True)['expected_feedback_failures'], 11)

    def test_original_cannot_pass_from_arbitrary_or_additional_failures(self):
        for label in ['original finite set reward remains intact', 'unrelated FAIL marker']:
            with self.subTest(label=label), tempfile.TemporaryDirectory() as temp:
                folder = Path(temp)
                self.make(folder, True)
                self.change(folder, 'result.json', lambda value: value['checks'].append({'label': label, 'passed': 0}))
                with self.assertRaises(ValueError):
                    oracle.verify(folder, HEAD, True)

    def test_ordinary_reward_failure_invalidates_original_control(self):
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            self.make(folder, True)
            def corrupt(value):
                next(row for row in value['checks'] if row['label'] == 'original finite set reward remains intact')['passed'] = 0
            self.change(folder, 'result.json', corrupt)
            with self.assertRaisesRegex(ValueError, 'Unexpected causal failures'):
                oracle.verify(folder, HEAD, True)

    def test_nonzero_timeout_and_elapsed_deadlines_never_accept_receipts(self):
        for phase, limit in [('compile', 180), ('runtime', 100)]:
            for field, value in [('returncode', 7), ('timed_out', True), ('wall_seconds', limit),
                                 ('returncode', False), ('wall_seconds', '50')]:
                with self.subTest(phase=phase, field=field, value=value), tempfile.TemporaryDirectory() as temp:
                    folder = Path(temp)
                    self.make(folder)
                    self.change(folder, phase + '-status.json', lambda row: row.update({field: value}))
                    with self.assertRaises(ValueError):
                        oracle.verify(folder, HEAD)

    def test_wrong_commit_or_original_source_identity_reject(self):
        for name, field, bad in [('result.json', 'commit', 'b' * 40),
                                 ('metadata.json', 'checkout_head', 'b' * 40),
                                 ('metadata.json', 'original_control_commit', 'b' * 40),
                                 ('metadata.json', 'original_control_sha256', 'b' * 64)]:
            with self.subTest(field=field), tempfile.TemporaryDirectory() as temp:
                folder = Path(temp)
                self.make(folder, True)
                self.change(folder, name, lambda row: row.update({field: bad}))
                with self.assertRaises(ValueError):
                    oracle.verify(folder, HEAD, True)

    def test_pinned_compiler_summary_is_required(self):
        for text in ['DM compiler version 516.1680\n0 errors, 0 warnings',
                     'DM compiler version 516.1681\n10 errors, 0 warnings',
                     'DM compiler version 516.1681\n0 errors, 1 warning']:
            with self.subTest(text=text), tempfile.TemporaryDirectory() as temp:
                folder = Path(temp)
                self.make(folder)
                (folder / 'compile.log').write_text(text)
                with self.assertRaisesRegex(ValueError, 'warning-free'):
                    oracle.verify(folder, HEAD)

    def test_unrelated_runtime_diagnostic_alongside_expected_failures_rejects(self):
        for name in ['runtime.log', 'runtime-stdout.log', 'runtime-stderr.log']:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temp:
                folder = Path(temp)
                self.make(folder, True)
                with (folder / name).open('a') as log:
                    log.write('\nruntime error: unrelated failure\n')
                with self.assertRaisesRegex(ValueError, 'Unrelated runtime'):
                    oracle.verify(folder, HEAD, True)

    def test_missing_duplicate_check_or_case_rejects(self):
        for mutate in [lambda v: v['checks'].pop(), lambda v: v['checks'].append(v['checks'][0]),
                       lambda v: v['cases'].pop(), lambda v: v['checks'][0].update(passed='true')]:
            with tempfile.TemporaryDirectory() as temp:
                folder = Path(temp)
                self.make(folder)
                self.change(folder, 'result.json', mutate)
                with self.assertRaises(ValueError):
                    oracle.verify(folder, HEAD)

    def test_missing_or_additional_canonical_log_marker_rejects(self):
        for text in ['', 'FAIL: unrelated failure\n']:
            with self.subTest(text=text), tempfile.TemporaryDirectory() as temp:
                folder = Path(temp)
                self.make(folder)
                (folder / 'runtime.log').write_text(text)
                with self.assertRaises(ValueError):
                    oracle.verify(folder, HEAD)

    def test_console_repetition_is_not_double_counted_as_control_failure(self):
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            self.make(folder, True)
            (folder / 'runtime-stdout.log').write_text((folder / 'runtime.log').read_text())
            oracle.verify(folder, HEAD, True)

    def test_actual_selector_and_existing_workflow_scope(self):
        spec = importlib.util.spec_from_file_location('training_ci_selection', ROOT / 'scripts/select-ci.py')
        selection = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(selection)
        previous = os.getcwd()
        try:
            os.chdir(ROOT)
            # Real immutable Git comparisons, not a mocked list of added paths.
            self.assertIn('tests/active_training', selection.introduced_tests(oracle.ORIGINAL, 'HEAD', 'pull_request'))
            self.assertEqual(selection.introduced_tests(oracle.ORIGINAL, oracle.ORIGINAL, 'pull_request'), [])
            self.assertEqual(selection.introduced_tests(oracle.ORIGINAL, 'HEAD', 'push'), [])
            self.assertTrue(selection.needs_extensive('workflow_dispatch', True))
            self.assertFalse(selection.needs_extensive('push', True))
        finally:
            os.chdir(previous)
        workflow = (ROOT / '.github/workflows/test.yml').read_text(encoding='utf-8')
        block = workflow.split('      - name: Verify finite active training and post-wait negative control\n', 1)[1].split('\n      - name:', 1)[0]
        self.assertIn("if: needs.changes.outputs.extensive == 'true' || contains(fromJSON(needs.changes.outputs.new_tests), 'tests/active_training')", block)
        calls = [line for line in block.splitlines() if '-File tests/active_training/run.ps1 ' in line]
        self.assertEqual(len(calls), 4)
        self.assertEqual(sum('-ClickFeedback' in line for line in calls), 2)
        self.assertEqual(sum('-OriginalSilence' in line for line in calls), 1)
        self.assertEqual(sum('-NegativeControl' in line for line in calls), 1)
        self.assertIn("-p 'test_click*.py'", block)
        retain = workflow.split('      - name: Retain active training click feedback evidence\n', 1)[1].split('\n      - name:', 1)[0]
        self.assertIn("always() && steps.active_training.outputs.started == 'true'", retain)
        self.assertIn('actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02', retain)
        self.assertNotIn('/config', retain)
        self.assertNotIn('.dmb', retain)


if __name__ == '__main__':
    unittest.main()
