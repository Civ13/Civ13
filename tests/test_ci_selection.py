import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch
import subprocess

spec = importlib.util.spec_from_file_location('selection', Path(__file__).resolve().parents[1] / 'scripts/select-ci.py')
selection = importlib.util.module_from_spec(spec)
spec.loader.exec_module(selection)

class SelectionTests(unittest.TestCase):
    def test_documentation_only(self):
        self.assertFalse(selection.needs_game(['AGENTS.md', 'docs/api/search.js',
            'docs/api/search.css', 'scripts/build-api-docs.py',
            '.github/workflows/api-pages.yml']))
    def test_shared_and_runtime_paths(self):
        for path in ('civ13.dme', 'code/__defines/maps.dm', 'code/world.dm',
                     'maps/nomads/map.dmm', 'icons/obj/test.dmi', 'sound/a.ogg',
                     'config/config.txt', '_compile_options.dm',
                     '.github/workflows/test.yml', '.github/workflows/ci-selection.yml',
                     'scripts/select-ci.py', 'tests/chemistry/run.py',
                     'scripts/test-power.ps1', 'tools/new-tool/file'):
            with self.subTest(path=path):
                self.assertTrue(selection.needs_game(['docs/api/README.md', path]))
    def test_renamed_or_deleted_game_file(self):
        # git diff --name-only without rename detection returns both old/new paths.
        self.assertTrue(selection.needs_game(['code/old.dm', 'docs/moved.md']))
    def test_missing_base_or_manual_runs_all(self):
        self.assertTrue(selection.select('', 'abc')[0])
        self.assertTrue(selection.select('0' * 40, 'abc')[0])
    def test_failed_diff_runs_all(self):
        with patch.object(selection.subprocess, 'check_output',
                          side_effect=subprocess.CalledProcessError(1, 'git')):
            self.assertTrue(selection.select('abc', 'def')[0])
    def test_nul_delimited_paths(self):
        with patch.object(selection.subprocess, 'check_output',
                          return_value=b'docs/api/a file.md\0'):
            self.assertFalse(selection.select('abc', 'def')[0])

if __name__ == '__main__':
    unittest.main()
