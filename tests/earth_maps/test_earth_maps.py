"""The draft lands of the rest of the Earth (tests/earth_maps/generate.py).

Offline: reads the committed maps and the repository's region files. It checks
that each draft is the map its design last wrote, that it is well formed and
within the measured size of the Americas regions, and, above all, that it is
still a draft: nothing a server builds or loads may name it.
"""
import hashlib
import json
import re
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))

DRAFTS = json.loads((HERE / 'drafts.json').read_text(encoding='utf-8'))
NAMES = ('africa', 'antarctica', 'asia', 'europe', 'greenland', 'oceania')
MEASURED_CELLS = 1050000   # the size the Americas regions were measured at (tests/americas_maps)
FRESH_ICE = '/turf/floor/beach/water/ice'


def parse(path):
    """Key table and grid rows of a one-level DMM."""
    text = Path(path).read_text(encoding='utf-8')
    head, _, body = text.partition('(1,1,1) = {"')
    keys = dict(re.findall(r'^"(\w+)" = \((.*)\)$', head, flags=re.M))
    rows = [row for row in body.split('"}')[0].split('\n') if row]
    return keys, rows


def known_paths():
    """Every turf, area and object path the two Americas maps use."""
    known = set()
    for name in ('north', 'south'):
        keys, _ = parse(ROOT / 'maps' / 'nomads' / ('nomads_americas_%s.dmm' % name))
        for value in keys.values():
            known.update(re.sub(r'\{.*?\}', '', value).split(','))
    return known


class EarthDrafts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.maps = {name: parse(ROOT / DRAFTS[name]['path']) for name in NAMES}

    def test_every_draft_is_listed(self):
        self.assertEqual(tuple(sorted(DRAFTS)), NAMES)
        on_disk = sorted(p.name for p in (ROOT / 'maps' / 'earth_drafts').glob('*.dmm'))
        self.assertEqual(on_disk, sorted(Path(DRAFTS[name]['path']).name for name in NAMES))

    def test_maps_are_what_the_designs_last_wrote(self):
        for name in NAMES:
            data = (ROOT / DRAFTS[name]['path']).read_bytes().replace(b'\r\n', b'\n')
            self.assertEqual(hashlib.sha256(data).hexdigest(), DRAFTS[name]['sha256'],
                             '%s: rerun tests/earth_maps/generate.py' % name)

    def test_grids_are_whole_and_within_the_measured_size(self):
        for name in NAMES:
            keys, rows = self.maps[name]
            width, height = DRAFTS[name]['size']
            self.assertLessEqual(width * height, MEASURED_CELLS, name)
            self.assertEqual(len(rows), height, name)
            self.assertEqual({len(row) for row in rows}, {2 * width}, name)
            used = {row[i:i + 2] for row in rows for i in range(0, len(row), 2)}
            self.assertEqual(used - set(keys), set(), name)

    def test_only_paths_the_americas_maps_use(self):
        known = known_paths() | {FRESH_ICE}
        for name in NAMES:
            keys, _ = self.maps[name]
            for value in keys.values():
                for path in re.sub(r'\{.*?\}', '', value).split(','):
                    self.assertIn(path, known, name)
        self.assertIn(FRESH_ICE + '\n', (ROOT / 'code/game/turfs/floor_types.dm').read_text(encoding='utf-8', errors='replace'))

    def test_each_has_land_sea_and_starts(self):
        for name in NAMES:
            keys, rows = self.maps[name]
            cells = len(rows) * len(rows[0]) // 2
            sea = {k for k, v in keys.items() if 'saltwater' in v or 'ice/salty' in v}
            wet = sum(row[i:i + 2] in sea for row in rows for i in range(0, len(row), 2))
            self.assertGreater(cells - wet, 0.15 * cells, name)
            self.assertGreater(wet, 0.2 * cells, name)
            starts = {k for k, v in keys.items() if 'JoinLateCiv' in v}
            placed = sum(row[i:i + 2] in starts for row in rows for i in range(0, len(row), 2))
            self.assertGreaterEqual(placed, 8, name)

    def test_drafts_stay_out_of_every_build_and_region_list(self):
        for name in NAMES:
            keys, _ = self.maps[name]
            self.assertFalse(any('map_metadata' in value for value in keys.values()), name)
        named = re.compile(r'earth_drafts|earth_(africa|antarctica|asia|europe|greenland|oceania)')
        watched = [ROOT / 'civ13.dme', ROOT / 'code/processes/mapswap.dm']
        watched += sorted((ROOT / 'scripts' / 'shard-group').glob('*.json'))
        watched += sorted((ROOT / 'scripts' / 'windows' / 'host').glob('*.json'))
        watched += sorted((ROOT / 'code/game/objects/map_metadata').rglob('*.dm'))
        for path in watched:
            self.assertIsNone(named.search(path.read_text(encoding='utf-8', errors='replace')), str(path))

    def test_designs_keep_inside_their_frames(self):
        import lands
        for name in NAMES:
            spec = lands.MAPS[name]
            self.assertIsNone(spec['metadata'], name)
            self.assertEqual(list(spec['size']), DRAFTS[name]['size'], name)
            self.assertEqual(spec['path'], DRAFTS[name]['path'], name)
            west, east = spec['lon']
            north, south = spec['lat']
            self.assertGreater(west, east, name)
            self.assertGreater(north, south, name)
            for lon, lat in spec['starts']:
                self.assertTrue(east <= lon <= west and south <= lat <= north, '%s start %s' % (name, (lon, lat)))


if __name__ == '__main__':
    unittest.main()
