"""Version-2 furnished room layouts: derived catalog, topology checks and furnishing rules."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('room_layouts_v2', ROOT / 'docs/liminal/room_layouts_v2.py')
layouts = importlib.util.module_from_spec(spec)
spec.loader.exec_module(layouts)


class LayoutV2Tests(unittest.TestCase):
    def setUp(self):
        self.source = layouts.load()

    def test_catalog_is_derived_and_passes_topology_checks(self):
        catalog, furnishing, problems = layouts.check(self.source)
        self.assertEqual([], problems)
        self.assertEqual(layouts.CATALOG.read_text(encoding='utf-8'), layouts.dumps(catalog))
        self.assertEqual('liminal-authored-rooms/0.2.0', catalog['version'])
        self.assertEqual(10, len(furnishing))

    def test_rooms_are_furnished_and_dense_cells_match_the_mask(self):
        catalog, furnishing = layouts.derive(self.source)
        for name, a in catalog['archetypes'].items():
            solid = {(x, y) for y, row in enumerate(a['mask']) for x, ch in enumerate(row) if ch == 'X'}
            dense = {tuple(o['position']) for o in furnishing[name]['objects'] if o['asset'] in set(layouts.DENSE.values())}
            self.assertEqual(solid, dense, name)
            self.assertGreaterEqual(len(furnishing[name]['objects']), 4, name)

    def test_chairs_face_desks_and_desks_pair_at_most(self):
        _, furnishing = layouts.derive(self.source)
        for name, f in furnishing.items():
            desks = {tuple(o['position']) for o in f['objects'] if o['asset'] == 'desk'}
            for o in f['objects']:
                if o['asset'] == 'chair' and o['role'] == 'seat facing its desk':
                    dx, dy = layouts.DIRS[o['direction']]
                    self.assertIn((o['position'][0] + dx, o['position'][1] + dy), desks, name)
                if o['asset'] in ('computer', 'paper'):
                    self.assertIn(tuple(o['position']), desks, name)

    def test_blocked_doorway_and_unseated_chair_are_rejected(self):
        bad = copy.deepcopy(self.source)
        rows = bad['rooms']['extraction_airlock']['layout']
        rows[4] = '#L......#'  # a locker in the doorway approach
        self.assertIn('CATALOG_ANCHOR_CLEARANCE', layouts.check(bad)[2])
        bad = copy.deepcopy(self.source)
        rows = bad['rooms']['extraction_airlock']['layout']
        rows[4] = '#...c...#'
        with self.assertRaises(ValueError):
            layouts.check(bad)

    def test_assembly_contract_is_unchanged_from_v1(self):
        bad = copy.deepcopy(self.source)
        bad['rooms']['utility_gallery']['anchors']['objective'] = [[5, 4]]
        self.assertIn('ASSEMBLY_CONTRACT_CHANGED:utility_gallery', layouts.check(bad)[2])


if __name__ == '__main__':
    unittest.main()
