"""Failure-path tests use fake processes and never execute BYOND."""
import json
from pathlib import Path
import tempfile
import time
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import resources

class Child:
    pid = 123
    returncode = None
    def poll(self):
        return self.returncode
    def kill(self):
        self.returncode = 1
    def communicate(self, timeout=None):
        if self.returncode is None:
            self.returncode = 0
        return b'', b''

class ResourceFailureTests(unittest.TestCase):
    def test_live_diagnostic_survives_cleanup(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            diagnostic = root / 'runtime.log'
            diagnostic.write_text('BUG: retained diagnostic\n')
            receipt = root / 'resource.json'
            now = time.monotonic()
            child = Child()
            with patch.object(resources, 'os', SimpleNamespace(name='nt')), \
                 patch.object(resources.subprocess, 'CREATE_NO_WINDOW', 0, create=True), \
                 patch.object(resources.subprocess, 'Popen', return_value=child), \
                 patch.object(resources, 'listeners', return_value=[]), \
                 patch.object(resources, 'snapshot', return_value=dict(identity=42, cpu_seconds=0, peak_working_set=100, working_set=100)):
                with self.assertRaisesRegex(RuntimeError, 'Engine diagnostic'):
                    resources.Budget(now, now + 10).run(['fake'], root, receipt, diagnostic_file=diagnostic)
            diagnostic.unlink()
            self.assertEqual(Path(str(receipt) + '.engine.log').read_text(), 'BUG: retained diagnostic\n')
            self.assertTrue(json.loads(receipt.read_text())['reaped'])

    def test_expired_deadline_does_not_create_child(self):
        now = time.monotonic()
        budget = resources.Budget(now, now + 10)
        with patch.object(resources, 'os', SimpleNamespace(name='nt')), \
             patch.object(resources.time, 'monotonic', return_value=now + 11), \
             patch.object(resources.subprocess, 'Popen') as create:
            with self.assertRaisesRegex(RuntimeError, 'before process creation'):
                budget.run(['fake'], '.', 'unused')
            create.assert_not_called()

    def test_fast_exit_final_resource_query_failure_is_reaped(self):
        with tempfile.TemporaryDirectory() as directory:
            receipt = Path(directory) / 'resource.json'
            now = time.monotonic()
            child = Child()
            with patch.object(resources, 'os', SimpleNamespace(name='nt')), \
                 patch.object(resources.subprocess, 'CREATE_NO_WINDOW', 0, create=True), \
                 patch.object(resources.subprocess, 'Popen', return_value=child), \
                 patch.object(resources, 'listeners', return_value=[]), \
                 patch.object(resources, 'snapshot', side_effect=[dict(identity=42, cpu_seconds=0, peak_working_set=100, working_set=100), OSError('final query failed')]):
                with self.assertRaisesRegex(OSError, 'final query failed'):
                    resources.Budget(now, now + 10).run(['fake'], Path(directory), receipt)
            data = json.loads(receipt.read_text())
            self.assertTrue(data['reaped'])
            self.assertEqual(data['stop_reason'], 'final query failed')

if __name__ == '__main__':
    unittest.main()
