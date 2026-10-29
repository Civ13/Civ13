"""Frozen-input portability and corruption controls; no native or network calls."""
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

import historical_fixtures as fixtures


class HistoricalFixtures(unittest.TestCase):
    def test_all_frozen_inputs_load_without_git_or_processes(self):
        manifest = json.loads((fixtures.DIRECTORY / 'manifest.json').read_text())
        self.assertEqual(len(manifest), 9)
        with patch('subprocess.check_output', side_effect=AssertionError('Historical Git query')), \
             patch('subprocess.Popen', side_effect=AssertionError('Process launch')):
            for identity in manifest:
                commit, path = identity.split(':', 1)
                self.assertTrue(fixtures.text(commit, path))

    def test_changed_historical_bytes_are_rejected(self):
        manifest = json.loads((fixtures.DIRECTORY / 'manifest.json').read_text())
        identity, entry = next(iter(manifest.items()))
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            shutil.copyfile(fixtures.DIRECTORY / 'manifest.json', directory / 'manifest.json')
            (directory / entry['file']).write_bytes(b'changed historical test source')
            with patch.object(fixtures, 'DIRECTORY', directory), self.assertRaisesRegex(ValueError, 'fixture changed'):
                fixtures.text(*identity.split(':', 1))

    def test_original_seed_consumers_and_runtime_pin_need_no_historical_objects(self):
        import test_current_ci
        import test_preparation
        import test_source
        with patch('subprocess.check_output', side_effect=AssertionError('Historical Git query')):
            for consumer in (test_source.HistoricalSourceContractTests, test_source.CurrentMasterContractTests,
                             test_source.LightingCurrentMasterContractTests, test_preparation.ActualPreparationTests):
                consumer.setUpClass()
            test_current_ci.CurrentCITests().test_historical_pin_limits_and_result_guards_are_preserved()


if __name__ == '__main__':
    unittest.main()
