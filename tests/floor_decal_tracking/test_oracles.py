"""Synthetic log/parser tests only; these do not establish native outcomes."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('contained_runner', Path(__file__).with_name('run-contained.py'))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


def positive(eager=False):
    values = (128,128,128) if eager else (0,1,2)
    return ''.join(f'TRACKING initialized_turfs={n} distinct_native_lists={n}\n' for n in values) + 'PASS floor decal tracking 33 checks\n'


class OracleTests(unittest.TestCase):
    def test_exact_positive_and_eager_counts(self):
        runner.validate_native(positive(), None)
        runner.validate_native(positive(True), None, eager=True)
        with self.assertRaisesRegex(RuntimeError, 'tracking counts'):
            runner.validate_native(positive(True), None)

    def test_incomplete_checks_and_wrong_identity_counts_reject(self):
        for bad in (positive().replace('33 checks','32 checks'),
                    positive().replace('distinct_native_lists=2','distinct_native_lists=1')):
            with self.assertRaises(RuntimeError):
                runner.validate_native(bad, None)

    def test_exact_failure_required_and_pass_never_counts_as_caught(self):
        for _, _, target in runner.RUNS:
            if target is None:
                continue
            log = f'FAIL {target}\nFAIL exception: assertion: {target}\n'
            runner.validate_native(log, target)
            for bad in (positive(), log + 'FAIL unrelated\n', log + 'runtime error: bad ref\n',
                        log.replace(target, 'wrong target'), log + 'PASS floor decal tracking 33 checks\n'):
                with self.assertRaises(RuntimeError):
                    runner.validate_native(bad, target)

    def test_native_diagnostics_never_accepted(self):
        for message in ('Bad ref','BUG:','RUNTIME:','## ERROR:','fatal error','FAIL diagnostic: native error'):
            with self.assertRaisesRegex(RuntimeError, 'diagnostic'):
                runner.validate_native(positive() + message, None)

    def test_assertion_count_matches_authored_fixture(self):
        text = Path(__file__).with_name('probe.dm').read_text()
        self.assertEqual(sum(line.lstrip().startswith('check(') for line in text.splitlines()), 33)


if __name__ == '__main__':
    unittest.main()
