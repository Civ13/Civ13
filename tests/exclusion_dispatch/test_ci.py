"""Offline result/cleanup tests; never invoke BYOND."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

spec = importlib.util.spec_from_file_location('exclusion_ci', Path(__file__).with_name('run-ci.py'))
ci = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ci)


BIND_LOG = 'World opened on network port 12345 for address 127.0.0.1.\n'


class LinuxCITests(unittest.TestCase):
    def result(self, failures=0):
        return dict(cases=1000, failures=failures, samples=[], network=dict(
            preclose_address='127.0.0.1', closed_port=0, reopen_result=0, after_reopen_port=0))

    def test_parity_and_mutation_dispatch(self):
        ci.validate_result('parity', self.result(), BIND_LOG)
        for mode in ('omit', 'parent', 'eager'):
            ci.validate_result(mode, self.result(1), BIND_LOG)
            with self.assertRaises(RuntimeError):
                ci.validate_result(mode, self.result(), BIND_LOG)
        with self.assertRaises(RuntimeError):
            ci.validate_result('parity', self.result(1), BIND_LOG)

    def test_diagnostics_network_and_incomplete_results_fail(self):
        for log in ('BUG: invalid', 'runtime error: bad loc', 'Bad ref'):
            with self.assertRaises(RuntimeError):
                ci.validate_result('parity', self.result(), log)
        for key in ('closed_port', 'reopen_result', 'after_reopen_port'):
            result = self.result()
            result['network'][key] = 1
            with self.assertRaises(RuntimeError):
                ci.validate_result('parity', result, BIND_LOG)
        for key, value in (('cases', 0), ('samples', [1])):
            result = self.result()
            result[key] = value
            with self.assertRaises(RuntimeError):
                ci.validate_result('parity', result, BIND_LOG)

    def test_bind_diagnostic_is_separate_from_host_address(self):
        result = self.result()
        result['network']['preclose_address'] = '10.1.1.178'
        ci.validate_result('parity', result, BIND_LOG)
        for log in ('', BIND_LOG.replace('127.0.0.1', '0.0.0.0'),
                    BIND_LOG.replace('127.0.0.1', '10.1.1.178'),
                    BIND_LOG + BIND_LOG.replace('127.0.0.1', '::')):
            with self.assertRaises(RuntimeError):
                ci.validate_result('parity', result, log)

    def test_deadline_prevents_process_creation(self):
        with tempfile.TemporaryDirectory() as temp:
            with self.assertRaisesRegex(RuntimeError, 'before launch'):
                ci.run(['does-not-exist'], Path(temp), 'expired', time.monotonic() - 1)
            self.assertEqual(list(Path(temp).iterdir()), [])

    @unittest.skipUnless(sys.platform == 'linux', 'Linux process-group/resource semantics')
    def test_timeout_reaps_owned_child_and_retains_receipt(self):
        with tempfile.TemporaryDirectory() as temp:
            work = Path(temp)
            with self.assertRaises(subprocess.TimeoutExpired):
                ci.run([sys.executable, '-c', 'import time; time.sleep(5)'], work, 'timeout', time.monotonic() + .1)
            receipt = json.loads((work / 'timeout-process.json').read_text())
            self.assertTrue(receipt['reaped'])
            self.assertNotEqual(receipt['returncode'], 0)
            self.assertIn('error', receipt)

    @unittest.skipUnless(sys.platform == 'linux', 'Linux process-group/resource semantics')
    def test_actual_source_preparation_with_bounded_git_mapping(self):
        with tempfile.TemporaryDirectory() as temp:
            work = Path(temp)
            packet = work / 'source.json'
            ci.run([sys.executable, str(ci.HERE / 'run.py'), '--source-only',
                    '--output', str(packet)], work, 'prepare', time.monotonic() + 40)
            self.assertFalse(json.loads(packet.read_text())['native_execution'])
            self.assertTrue((work / 'source.sources/production.dm').is_file())

    @unittest.skipUnless(sys.platform == 'linux', 'Linux process-group/resource semantics')
    def test_clean_process_retains_logs_and_receipt(self):
        with tempfile.TemporaryDirectory() as temp:
            work = Path(temp)
            self.assertIn('offline child', ci.run([sys.executable, '-c', 'print("offline child")'], work, 'clean', time.monotonic() + 10))
            self.assertTrue(json.loads((work / 'clean-process.json').read_text())['reaped'])


if __name__ == '__main__':
    unittest.main()
