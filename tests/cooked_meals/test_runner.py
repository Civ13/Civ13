"""Reject asynchronous native diagnostics even when the main probe wrote PASS."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('meal_runner', Path(__file__).with_name('run.py'))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class DiagnosticTests(unittest.TestCase):
    def test_normal_success_and_expected_control_are_accepted(self):
        runner.verify_result(0, 'PASS', 'PASS', 'Welcome BYOND!\nMEAL PASS: portion')
        runner.verify_result(0, 'FAIL: paid nutrients conserved', 'FAIL: paid nutrients conserved', 'MEAL exception: paid nutrients conserved')

    def test_async_runtime_cannot_hide_behind_pass(self):
        diagnostics = (
            '[20:00:00] Runtime in code/test.dm,85: Division by zero',
            '[20:00:00] Uncaught exception: asynchronous callback',
            'runtime error: Cannot read null.loc',
            'BUG: stale object', '## ERROR: native failure',
            'Bad ref in obj vars', 'Bad loc in movable',
        )
        for message in diagnostics:
            with self.subTest(message=message):
                with self.assertRaises(RuntimeError):
                    runner.verify_result(0, 'PASS', 'PASS', 'MEAL PASS: complete\n' + message)

    def test_exit_and_wrong_or_missing_completion_cannot_pass(self):
        for code, actual in ((1, 'PASS'), (0, ''), (0, 'FAIL: unrelated error')):
            with self.subTest(code=code, actual=actual):
                with self.assertRaises(RuntimeError):
                    runner.verify_result(code, actual, 'PASS', '')


if __name__ == '__main__':
    unittest.main()
