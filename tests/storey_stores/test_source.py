"""Storey stores (loft drying, upstairs mice, flood rot): source contracts. Behaviour is in probe.dm:

    python3 tests/storey_stores/test_source.py
    python3 tests/ecology_spawning/run_linux.py . tests/storey_stores/probe.dm
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


class StoreyStoresSource(unittest.TestCase):
    def test_included(self):
        self.assertIn('#include "code\\modules\\1713\\storey_stores.dm"', read('civ13.dme'))

    def test_dehydrator_step(self):
        production = read('code/modules/1713/production.dm')
        self.assertIn('dry_timer += dry_step()', production)
        self.assertNotIn('dry_timer += 150', production)
        self.assertIn('/obj/structure/dehydrator/dry_step()', read('code/modules/1713/storey_stores.dm'))

    def test_mice_stay_downstairs(self):
        self.assertIn('if (turf_is_above_ground(T)) // mice keep to the ground floor', read('code/modules/ecology/mouse_nests.dm'))

    def test_flood_rots_grain(self):
        flood = read('code/modules/1713/flood_effects.dm')
        self.assertIn('else if (flood_rots(I))', flood)
        self.assertEqual(flood.count('flood_items_at('), 2)


if __name__ == '__main__':
    unittest.main()
