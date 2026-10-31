"""Runner verdict and bounds checks only; no container or BYOND is started."""
import importlib.util
from pathlib import Path
import sys
import time
import types
import unittest
from unittest import mock

root = Path(__file__).resolve().parent
# resource does not exist on Windows; no resource operations execute in tests.
try:
    import resource
except ModuleNotFoundError:
    sys.modules['resource'] = types.ModuleType('resource')
spec = importlib.util.spec_from_file_location('reviewed_countdown_runner', root / 'run_ci.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)

class RunnerTests(unittest.TestCase):
    def test_verdict_requires_exact_control_and_closed_port(self):
        runner.validate_result('PASS:boot: armed=0 port=0', 'none', 'boot')
        runner.validate_result('FAIL:vote:vote_no_setup armed=1 port=0', 'postvote', 'vote')
        runner.validate_result('FAIL:latch:latch_cancelled,latch_no_setup port=0', 'latch', 'latch')
        for result, control, case in (
            ('PASS:vote: armed=1 port=0', 'postvote', 'vote'),
            ('FAIL:vote:vote_no_setup,other port=0', 'postvote', 'vote'),
            ('FAIL:vote:vote_no_setup port=4', 'postvote', 'vote'),
            ('FAIL:boot:vote_no_setup port=0', 'postvote', 'vote'),
            ('PASS:boot: port=1', 'none', 'boot'),
        ):
            with self.subTest(result=result), self.assertRaises(RuntimeError):
                runner.validate_result(result, control, case)

    def test_process_matrix_and_environment(self):
        self.assertEqual(len(runner.CASES), 5)
        self.assertEqual(sum(map(len, runner.CASES.values())), 12)
        self.assertEqual((runner.WORK_SECONDS, runner.COMPILE_SECONDS, runner.DAEMON_SECONDS), (330, 30, 12))
        self.assertEqual(set(runner.CHILD_ENV), {'PATH', 'LANG', 'LC_ALL', 'LD_LIBRARY_PATH', 'TMPDIR', 'PYTHONDONTWRITEBYTECODE'})
        self.assertFalse(any('TOKEN' in name or 'SECRET' in name for name in runner.CHILD_ENV))

    def test_aggregate_deadline_never_extends_child(self):
        with mock.patch.object(runner.time, 'monotonic', return_value=100):
            self.assertEqual(runner.remaining(200, 30), 30)
            self.assertEqual(runner.remaining(105, 30), 5)
            with self.assertRaises(TimeoutError): runner.remaining(100, 30)

if __name__ == '__main__': unittest.main()
