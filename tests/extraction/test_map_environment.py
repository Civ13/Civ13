"""Offline only: importing the deployment launcher is deliberately avoided."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('map_environment', ROOT / 'scripts/map_environment.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class MapEnvironmentTests(unittest.TestCase):
    def test_actual_catalog_rewrites_one_unconditional_map(self):
        original = (ROOT / 'civ13.dme').read_text()
        for path in ('maps/extraction/industrial_district.dmm', 'maps/2013/alleyway.dmm', 'maps/1969/bank_robbery.dmm'):
            self.assertTrue((ROOT / path).is_file())
            changed = MODULE.select_map(original, path)
            block = changed.split(MODULE.BEGIN)[1].split(MODULE.END)[0]
            self.assertEqual(block, f'\n#include "{path}"\n')
            self.assertEqual(changed.split(MODULE.BEGIN)[0], original.split(MODULE.BEGIN)[0])
            self.assertEqual(changed.split(MODULE.END)[1], original.split(MODULE.END)[1])
            self.assertEqual(MODULE.select_map(changed, path), changed)

    def test_flat_historical_environment_and_comments(self):
        original = '// example.dmm\n#include "code.dm"\n#include "maps/old.dmm"\n'
        self.assertEqual(MODULE.select_map(original, 'maps/new.dmm'), '// example.dmm\n#include "code.dm"\n#include "maps/new.dmm"\n')

    def test_conditional_or_ambiguous_sources_fail_before_writing(self):
        for source in ('#ifdef MAP\n#include "old.dmm"\n#endif\n', MODULE.BEGIN + MODULE.BEGIN + MODULE.END, MODULE.END + MODULE.BEGIN, '#include "code.dm"\n'):
            with self.assertRaises(ValueError):
                MODULE.select_map(source, 'new.dmm')

    def test_include_injection_rejected(self):
        for path in ('', 'new.dm', 'bad".dmm', 'bad\n.dmm', 'bad\r.dmm'):
            with self.assertRaises(ValueError):
                MODULE.select_map('#include "old.dmm"\n', path)


if __name__ == '__main__':
    unittest.main()
