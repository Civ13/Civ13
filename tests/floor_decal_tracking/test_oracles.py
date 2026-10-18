"""Synthetic log/parser tests only; these do not establish native outcomes."""
import importlib.util
from pathlib import Path
import unittest
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from native_policy import validate_baseline, validate_census, validate_sockets
from z_budget_evidence import validate_compile

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
            if target is None or target == runner.MISSING_UNION_FAILURE:
                continue
            log = f'FAIL {target}\nFAIL exception: assertion: {target}\n'
            runner.validate_native(log, target)
            for bad in (positive(), log + 'FAIL unrelated\n', log + 'runtime error: bad ref\n',
                        log.replace(target, 'wrong target'), log + 'PASS floor decal tracking 33 checks\n'):
                with self.assertRaises(RuntimeError):
                    runner.validate_native(bad, target)

    def test_only_exact_missing_lazy_union_exception_is_causal(self):
        log = 'TRACKING initialized_turfs=0 distinct_native_lists=0\nFAIL ' + runner.MISSING_UNION_FAILURE + '\n'
        runner.validate_native(log, runner.MISSING_UNION_FAILURE, profile='missing-lazy')
        for bad in (log.replace('type mismatch', 'other exception'), log.replace('corner_white', 'other_key'),
                    log + 'FAIL unrelated\n', log + 'PASS floor decal tracking 33 checks\n',
                    log + 'TRACKING initialized_turfs=1 distinct_native_lists=1\n',
                    log + 'runtime error: native failure\n', log.replace('initialized_turfs=0', 'initialized_turfs=1')):
            with self.assertRaises(RuntimeError):
                runner.validate_native(bad, runner.MISSING_UNION_FAILURE, profile='missing-lazy')
        with self.assertRaises(RuntimeError):
            runner.validate_native(log, runner.MISSING_UNION_FAILURE, profile='fixed')

    def test_native_diagnostics_never_accepted(self):
        for message in ('Bad ref', 'Bad loc', 'BUG:', 'RUNTIME:', '## ERROR:', 'fatal error',
                        'FAIL diagnostic: native error', 'assertion failed', 'infinite loop',
                        'segmentation', 'unexpected runtime', 'OOM', 'out of memory',
                        'access violation', 'CRASHED', 'invalid file'):
            with self.assertRaisesRegex(RuntimeError, 'diagnostic'):
                runner.validate_native(positive() + message, None)

    def test_strict_compile_banner_summary_artifact_and_order(self):
        good = 'DM compiler version 516.1681\nloading probe.dme\nprobe.dmb - 0 errors, 0 warnings\n'
        validate_compile(0, good)
        validate_compile(0, good.replace('warnings', 'warnings (10/18/26 1:23 pm)'))
        for bad in (good + good, good.replace('516.1681', '516.16810'),
                    good.replace('probe.dmb', 'other.dmb'), good + '1 warning\n',
                    good.replace('0 errors', '10 errors'), good.replace('warnings', 'warnings extra'),
                    '\n'.join(reversed(good.splitlines())), good + 'x' * 1024**2):
            with self.assertRaises(RuntimeError):
                validate_compile(0, bad)
        with self.assertRaises(RuntimeError):
            validate_compile(1, good)
        for message in ('runtime error:', 'Bad loc', 'OOM', 'access violation', 'invalid file', 'CRASH'):
            with self.assertRaises(RuntimeError):
                validate_compile(0, good + message)

    def test_socket_endpoints_and_closure(self):
        listen = dict(protocol='tcp', state='listen', address='127.0.0.1', port=59474)
        validate_sockets([listen], 'runtime', False)
        for state in map(str, range(5, 13)):
            connection = dict(protocol='tcp', state=state, address='127.0.0.1', port=1234,
                              remote_address='127.0.0.1', remote_port=59474)
            validate_sockets([connection], 'runtime', True)
            for change in ({'remote_address': '192.0.2.1'}, {'address': '0.0.0.0'},
                           {'remote_port': 0}, {'port': True}, {'state': '4'}, {'protocol': 'udp'}):
                with self.assertRaises(RuntimeError):
                    validate_sockets([connection | change], 'runtime', False)
        for phase, closed, sock in (('compile', False, listen), ('runtime', True, listen),
                                    ('runtime', False, listen | {'port': 1})):
            with self.assertRaises(RuntimeError):
                validate_sockets([sock], phase, closed)

    def test_census_pins_pid_creation_image_and_exclusivity(self):
        daemon = str(Path(__file__).resolve())
        row = dict(pid=161088, creation_filetime=134368205457714990, image=daemon)
        baseline = {key: row[key] for key in ('pid', 'creation_filetime')}
        validate_baseline([row], baseline, daemon)
        for rows in ([], [row, row], [row | {'pid': 1}],
                     [row | {'creation_filetime': 1}], [row | {'image': daemon + '.other'}],
                     [row | {'pid': True}], [row | {'image': ''}]):
            with self.assertRaises(RuntimeError):
                validate_baseline(rows, baseline, daemon)
        with self.assertRaises(RuntimeError):
            validate_census({})

    def test_assertion_count_matches_authored_fixture(self):
        text = Path(__file__).with_name('probe.dm').read_text()
        self.assertEqual(sum(line.lstrip().startswith('check(') for line in text.splitlines()), 33)


if __name__ == '__main__':
    unittest.main()
