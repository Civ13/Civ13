"""Production restart packet preparation; no native process is launched."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('restart_sources', Path(__file__).with_name('run-restart-transaction.py'))
RUNNER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUNNER)


class RestartFixtureSources(unittest.TestCase):
    def test_connected_client_collection_is_declared_without_disabling_notice(self):
        with tempfile.TemporaryDirectory() as output:
            RUNNER.prepare(ROOT, Path(output))
            transaction = (Path(output) / 'transaction.dm').read_text()
            probe = (Path(output) / 'probe.dm').read_text()
            self.assertIn('if(clients.len)', transaction)
            self.assertIn('sleep(600)', transaction)
            self.assertEqual(probe.count('var/global/list/clients = list()'), 1)
            self.assertNotIn('#define clients', (Path(output) / 'probe.dme').read_text())

    def test_all_existing_controls_keep_the_client_declaration(self):
        for control in ('generation', 'consume', 'import', 'deferred-reboot'):
            with self.subTest(control=control), tempfile.TemporaryDirectory() as output:
                receipt = RUNNER.prepare(ROOT, Path(output), control)
                self.assertEqual(receipt['negative_control'], control)
                self.assertIn('var/global/list/clients = list()', (Path(output) / 'probe.dm').read_text())


if __name__ == '__main__':
    unittest.main()
