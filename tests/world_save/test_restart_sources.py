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
            # Same declaration as code/_helpers/global_lists.dm.
            self.assertEqual(probe.count('var/list/clients = list()'), 1)
            self.assertNotIn('#define clients', (Path(output) / 'probe.dme').read_text())

    def test_all_existing_controls_keep_the_client_declaration(self):
        for control in ('generation', 'consume', 'import', 'deferred-reboot'):
            with self.subTest(control=control), tempfile.TemporaryDirectory() as output:
                receipt = RUNNER.prepare(ROOT, Path(output), control)
                self.assertEqual(receipt['negative_control'], control)
                self.assertIn('var/list/clients = list()', (Path(output) / 'probe.dm').read_text())

    def test_lifecycle_combination_has_one_shared_client_collection(self):
        with tempfile.TemporaryDirectory() as output:
            RUNNER.prepare(ROOT, Path(output))
            base = (Path(output) / 'probe.dm').read_text().split('/world/New()')[0]
            lifecycle = (ROOT / 'tests/world_save/lifecycle_probe.dm').read_text()
            import re
            self.assertEqual(len(re.findall(r'^var/(?:global/)?list/clients\s*=', base + lifecycle, re.M)), 1)


if __name__ == '__main__':
    unittest.main()
