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
        self.assertTrue(manifest)
        # Every frozen source must be covered exactly once, including later
        # reviewed integration checkpoints, without a stale fixed total.
        self.assertCountEqual([entry['file'] for entry in manifest.values()],
                              [path.name for path in fixtures.DIRECTORY.glob('*.txt')])
        with patch('subprocess.check_output', side_effect=AssertionError('Historical Git query')), \
             patch('subprocess.Popen', side_effect=AssertionError('Process launch')):
            for identity in manifest:
                commit, path = identity.split(':', 1)
                self.assertTrue(fixtures.text(commit, path))

    def test_manifest_coverage_rejects_missing_duplicate_and_unlisted_sources(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary) / 'fixtures'
            shutil.copytree(fixtures.DIRECTORY, directory)
            manifest_path = directory / 'manifest.json'
            manifest = json.loads(manifest_path.read_text())
            identity, entry = next(iter(manifest.items()))
            missing = {key: value for key, value in manifest.items() if key != identity}
            duplicate = dict(manifest, duplicate=entry)
            for changed in (missing, duplicate):
                with self.subTest(manifest=changed), patch.object(fixtures, 'DIRECTORY', directory):
                    manifest_path.write_text(json.dumps(changed))
                    with self.assertRaises(AssertionError):
                        self.test_all_frozen_inputs_load_without_git_or_processes()
            manifest_path.write_text(json.dumps(manifest))
            (directory / 'unlisted.txt').write_text('unlisted frozen source')
            with patch.object(fixtures, 'DIRECTORY', directory), self.assertRaises(AssertionError):
                self.test_all_frozen_inputs_load_without_git_or_processes()

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
