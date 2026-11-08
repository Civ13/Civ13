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

    def test_circular_explosion_walks_only_the_damage_radius(self):
        # flash_range is never applied per turf; walking trange(flash_range)
        # cost ~19 ms per (2, 2, 2, 100) artillery shell just to skip turfs.
        source = (HERE.parents[1] / 'code/processes/explosion.dm').read_text()
        body = source[source.index('/process/explosion/proc/explosion('):source.index('/process/explosion/proc/explosion_rec(')]
        self.assertIn('var/damage_range = max(devastation_range, heavy_impact_range, light_impact_range)\n', body)
        self.assertIn('for (var/turf/T in trange(damage_range, epicenter))', body)
        self.assertNotIn('trange(max_range', body)

    def test_known_maps_classify_their_upper_levels(self):
        audit = load('map_audit')
        for rel, levels in audit.EXPECTED.items():
            result = audit.classify(audit.ROOT / rel)
            for z, expected in levels.items():
                self.assertEqual(result[z][0], expected, f'{rel} z{z}')


if __name__ == '__main__':
    unittest.main()
