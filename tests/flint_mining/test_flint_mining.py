"""Offline source checks for flint mining; see run.py for the native probe."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('flint_mining_run', Path(__file__).with_name('run.py'))
run = importlib.util.module_from_spec(spec)
spec.loader.exec_module(run)


class FlintMiningSource(unittest.TestCase):
    def test_source_contracts(self):
        self.assertEqual(run.source_checks(), [])


if __name__ == '__main__':
    unittest.main()
