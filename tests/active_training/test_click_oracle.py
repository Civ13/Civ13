"""Offline fake-receipt oracle controls; never invoke the native launcher."""
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest import mock

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
spec = importlib.util.spec_from_file_location('verify_training_click', HERE / 'verify_click.py')
oracle = importlib.util.module_from_spec(spec)
spec.loader.exec_module(oracle)
HEAD = 'a' * 40


class ClickOracleTests(unittest.TestCase):
    def make(self, folder, original=False):
        """Write synthetic valid candidate or pinned-control receipts into folder."""
        def write(name, value):
            """Serialize a fixture value as UTF-8 JSON in the evidence directory."""
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
        (folder / 'compile.log').write_text('DM compiler version 516.1681\n.active_training_click.dmb - 0 errors, 0 warnings\n')
        (folder / 'compile-stdout.log').write_text((folder / 'compile.log').read_text())
        (folder / 'compile-stderr.log').write_text('')
        log = '\n'.join(('FAIL: ' if row['label'] in failed else 'PASS ') + row['label'] for row in checks) + '\n'
        (folder / 'runtime.log').write_text(log)
        (folder / 'runtime-stdout.log').write_text('')
        (folder / 'runtime-stderr.log').write_text('')

    def change(self, folder, name, mutate):
        """Apply mutate to a retained JSON value and write it back for rejection tests."""
        path = folder / name
        value = json.loads(path.read_text())
        mutate(value)
        path.write_text(json.dumps(value))

    def test_candidate_requires_complete_success(self):
        """Accept a complete candidate receipt with all 21 checks passing."""
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            self.make(folder)
            result = oracle.verify(folder, HEAD)
            self.assertEqual(result['checks'], 21)
            self.assertEqual(result['expected_feedback_failures'], 0)

    def test_original_exact_feedback_failures_and_reward_pass_are_accepted(self):
        """Accept the control only with its 11 expected feedback failures."""
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            self.make(folder, True)
            self.assertEqual(oracle.verify(folder, HEAD, True)['expected_feedback_failures'], 11)

    def test_original_cannot_pass_from_arbitrary_or_additional_failures(self):
        """Reject extra result rows even when they describe plausible control failures."""
        for label in ['original finite set reward remains intact', 'unrelated FAIL marker']:
            with self.subTest(label=label), tempfile.TemporaryDirectory() as temp:
                folder = Path(temp)
                self.make(folder, True)
                self.change(folder, 'result.json', lambda value: value['checks'].append({'label': label, 'passed': 0}))
                with self.assertRaises(ValueError):
                    oracle.verify(folder, HEAD, True)

    def test_ordinary_reward_failure_invalidates_original_control(self):
        """Reject a control that loses the original reward alongside missing feedback."""
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            self.make(folder, True)
            def corrupt(value):
                """Mark the finite reward check as failed in the synthetic result."""
                next(row for row in value['checks'] if row['label'] == 'original finite set reward remains intact')['passed'] = 0
            self.change(folder, 'result.json', corrupt)
            with self.assertRaisesRegex(ValueError, 'Unexpected causal failures'):
                oracle.verify(folder, HEAD, True)

    def test_nonzero_timeout_and_elapsed_deadlines_never_accept_receipts(self):
        """Reject process failures, timeouts, expired deadlines and invalid status types."""
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
        """Reject receipts with mismatched revisions or pinned-control source hashes."""
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
        """Reject an unpinned compiler or a build summary containing errors or warnings."""
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
        """Reject runtime errors in any runtime stream even for the silence control."""
        for name in ['runtime.log', 'runtime-stdout.log', 'runtime-stderr.log']:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temp:
                folder = Path(temp)
                self.make(folder, True)
                with (folder / name).open('a') as log:
                    log.write('\nruntime error: unrelated failure\n')
                with self.assertRaisesRegex(ValueError, 'Unrelated runtime'):
                    oracle.verify(folder, HEAD, True)

    def test_compile_requires_unique_exact_banner_and_binary_result(self):
        """Reject incomplete, duplicate, reordered or contaminated compiler results."""
        banner = 'DM compiler version 516.1681\n'
        summary = '.active_training_click.dmb - 0 errors, 0 warnings\n'
        invalid = [banner + '0 errors, 0 warnings\n',
                   banner + 'probe.dmb - 0 errors, 0 warnings\n',
                   banner + banner + summary, banner + summary + summary,
                   summary + banner, 'prefix ' + banner + summary,
                   banner + summary.rstrip() + ' trailing text\n',
                   banner + summary + 'other.dmb - 1 error, 0 warnings\n',
                   banner + summary + 'invalid file: absent.dme\n']
        for text in invalid:
            with self.subTest(text=text), tempfile.TemporaryDirectory() as temp:
                folder = Path(temp)
                self.make(folder)
                (folder / 'compile.log').write_text(text)
                with self.assertRaisesRegex(ValueError, 'warning-free'):
                    oracle.verify(folder, HEAD)

    def test_native_compiler_timestamp_and_console_copy_are_accepted(self):
        """Accept the native summary timestamp and its duplicate in console output."""
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            self.make(folder)
            text = 'DM compiler version 516.1681\n.active_training_click.dmb - 0 errors, 0 warnings (10/19/26 9:01 am)\n'
            (folder / 'compile.log').write_text(text)
            (folder / 'compile-stdout.log').write_text(text)
            oracle.verify(folder, HEAD)

    def test_comprehensive_diagnostics_reject_every_compile_and_runtime_stream(self):
        """Reject each known diagnostic marker in every retained log stream."""
        diagnostics = ['runtime error:', 'bad ref', 'bad loc', 'BUG:', '## ERROR:', 'RUNTIME:',
                       'assertion failed', 'infinite loop', 'segmentation fault', 'fatal error',
                       'Unexpected runtime', 'OOM', 'out of memory', 'access violation', 'CRASH',
                       'CRASHED', 'invalid file', 'Cannot read null', 'Cannot execute null',
                       'exception', 'fixture deadline']
        for name in [n for n in oracle.RETAINED_FILES if n.endswith('.log')]:
            for diagnostic in diagnostics:
                with self.subTest(name=name, diagnostic=diagnostic), tempfile.TemporaryDirectory() as temp:
                    folder = Path(temp)
                    self.make(folder, True)
                    with (folder / name).open('a') as log:
                        log.write('\n' + diagnostic + ' unrelated\n')
                    with self.assertRaises(ValueError):
                        oracle.verify(folder, HEAD, True)

    def test_unrelated_fail_rejects_all_streams_even_with_exact_control_result(self):
        """Reject unrelated FAIL markers despite otherwise valid control receipts."""
        for name in [n for n in oracle.RETAINED_FILES if n.endswith('.log')]:
            for marker in ['FAIL: unrelated failure', 'FAIL unrelated failure', 'FAIL']:
                with self.subTest(name=name, marker=marker), tempfile.TemporaryDirectory() as temp:
                    folder = Path(temp)
                    self.make(folder, True)
                    with (folder / name).open('a') as log:
                        log.write('\n' + marker + '\n')
                    with self.assertRaises(ValueError):
                        oracle.verify(folder, HEAD, True)

    def test_aggregate_bound_is_checked_before_any_metadata_or_log_read(self):
        """Reject oversized evidence using file sizes before opening retained files."""
        for names in [('metadata.json',), ('runtime-stdout.log', 'runtime-stderr.log')]:
            with self.subTest(names=names), tempfile.TemporaryDirectory() as temp:
                folder = Path(temp)
                self.make(folder)
                for name in names:
                    with (folder / name).open('wb') as stream:
                        stream.truncate(oracle.MAX_RETAINED_BYTES // len(names))
                with mock.patch.object(Path, 'open', side_effect=AssertionError('Must reject before reading')):
                    with self.assertRaisesRegex(ValueError, '16 MiB aggregate'):
                        oracle.verify(folder, HEAD)

    def test_bounded_reads_reject_file_growth_after_preflight(self):
        """Reject reads exceeding the aggregate limit when file size checks are stale."""
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            self.make(folder)
            # Simulate a stale stat that passed, then a larger retained receipt.
            size = sum((folder / name).stat().st_size for name in oracle.RETAINED_FILES)
            with mock.patch.object(oracle, 'MAX_RETAINED_BYTES', size - 1), \
                 mock.patch.object(Path, 'stat') as stat:
                stat.return_value.st_size = 0
                with self.assertRaisesRegex(ValueError, 'grew past 16 MiB'):
                    oracle.verify(folder, HEAD)

    def test_canonical_compile_log_keeps_accepted_one_mib_bound(self):
        """Reject a canonical compiler log exceeding its separate 1 MiB limit."""
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            self.make(folder)
            with (folder / 'compile.log').open('a') as log:
                log.write('x' * oracle.MAX_COMPILE_LOG)
            with self.assertRaisesRegex(ValueError, 'warning-free'):
                oracle.verify(folder, HEAD)

    def test_missing_duplicate_check_or_case_rejects(self):
        """Reject missing or duplicate result rows and invalid check boolean types."""
        for mutate in [lambda v: v['checks'].pop(), lambda v: v['checks'].append(v['checks'][0]),
                       lambda v: v['cases'].pop(), lambda v: v['checks'][0].update(passed='true')]:
            with tempfile.TemporaryDirectory() as temp:
                folder = Path(temp)
                self.make(folder)
                self.change(folder, 'result.json', mutate)
                with self.assertRaises(ValueError):
                    oracle.verify(folder, HEAD)

    def test_missing_or_additional_canonical_log_marker_rejects(self):
        """Reject an empty canonical runtime log or an unrelated failure marker."""
        for text in ['', 'FAIL: unrelated failure\n']:
            with self.subTest(text=text), tempfile.TemporaryDirectory() as temp:
                folder = Path(temp)
                self.make(folder)
                (folder / 'runtime.log').write_text(text)
                with self.assertRaises(ValueError):
                    oracle.verify(folder, HEAD)

    def test_console_repetition_is_not_double_counted_as_control_failure(self):
        """Allow a console copy of canonical control markers without double counting."""
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            self.make(folder, True)
            (folder / 'runtime-stdout.log').write_text((folder / 'runtime.log').read_text())
            oracle.verify(folder, HEAD, True)

    def test_actual_selector_and_existing_workflow_scope(self):
        """Check real Git suite selection, all four runner modes and artifact filtering."""
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
