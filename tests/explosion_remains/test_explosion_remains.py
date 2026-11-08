"""Offline checks for explosion remains: production wiring and the map audit."""
import contextlib
import importlib.util
import io
from pathlib import Path
import unittest

HERE = Path(__file__).resolve().parent


def load(name):
    spec = importlib.util.spec_from_file_location('explosion_remains_' + name, HERE / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ExplosionRemains(unittest.TestCase):
    def test_production_wiring(self):
        with contextlib.redirect_stdout(io.StringIO()) as out:
            failures = load('run').static_checks()
        self.assertEqual(failures, [], out.getvalue())

    def test_known_maps_classify_their_upper_levels(self):
        audit = load('map_audit')
        for rel, levels in audit.EXPECTED.items():
            result = audit.classify(audit.ROOT / rel)
            for z, expected in levels.items():
                self.assertEqual(result[z][0], expected, f'{rel} z{z}')


if __name__ == '__main__':
    unittest.main()
