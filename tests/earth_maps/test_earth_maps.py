"""The lands of the rest of the Earth (tests/earth_maps/generate.py).

Offline: reads the committed maps and the repository's region files. It checks
that each land is the map its design last wrote, that it is well formed and
within the measured size of the Americas regions. A draft must stay a draft:
nothing a server builds or loads may name it. A playable land (all six
now; docs/earth-continents.md) carries its metadata, has the height,
current and flood files written with it, is registered in source and runs on
over its crossing edges.
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
PLAYABLE = NAMES   # every land is a region now; the draft checks stay for a new one
DRAFT_NAMES = tuple(name for name in NAMES if name not in PLAYABLE)
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
        self.assertEqual(on_disk, sorted(Path(DRAFTS[name]['path']).name for name in DRAFT_NAMES))
        for name in PLAYABLE:
            self.assertEqual(DRAFTS[name]['path'], 'maps/nomads/nomads_earth_%s.dmm' % name)

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
        known = known_paths() | {FRESH_ICE} | {'/obj/map_metadata/nomads/earth_%s' % name for name in PLAYABLE}
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
        for name in DRAFT_NAMES:
            keys, _ = self.maps[name]
            self.assertFalse(any('map_metadata' in value for value in keys.values()), name)
        named = re.compile(r'earth_drafts' + (r'|earth_(%s)' % '|'.join(DRAFT_NAMES) if DRAFT_NAMES else ''))
        watched = [ROOT / 'civ13.dme', ROOT / 'code/processes/mapswap.dm']
        watched += sorted((ROOT / 'scripts' / 'shard-group').glob('*.json'))
        watched += sorted((ROOT / 'scripts' / 'windows' / 'host').glob('*.json'))
        watched += sorted((ROOT / 'code/game/objects/map_metadata').rglob('*.dm'))
        for path in watched:
            self.assertIsNone(named.search(path.read_text(encoding='utf-8', errors='replace')), str(path))

    def test_designs_keep_inside_their_frames(self):
        import lands
        self.assertEqual(lands.PLAYABLE, PLAYABLE)
        for name in NAMES:
            spec = lands.MAPS[name]
            if name in PLAYABLE:
                self.assertEqual(spec['metadata'], '/obj/map_metadata/nomads/earth_%s' % name)
            else:
                self.assertIsNone(spec['metadata'], name)
            self.assertEqual(list(spec['size']), DRAFTS[name]['size'], name)
            self.assertEqual(spec['path'], DRAFTS[name]['path'], name)
            west, east = spec['lon']
            north, south = spec['lat']
            self.assertGreater(west, east, name)
            self.assertGreater(north, south, name)
            for lon, lat in spec['starts']:
                self.assertTrue(east <= lon <= west and south <= lat <= north, '%s start %s' % (name, (lon, lat)))


class EarthRegions(unittest.TestCase):
    """The lands made into regions: Europe, and Africa in place of the Desert and Jungle."""

    @classmethod
    def setUpClass(cls):
        cls.maps = {name: parse(ROOT / DRAFTS[name]['path']) for name in PLAYABLE}
        cls.metadata = (ROOT / 'code/game/objects/map_metadata/nomads/nomads_earth.dm').read_text(encoding='utf-8')

    def block(self, name):
        return self.metadata.split('/obj/map_metadata/nomads/earth_%s\n' % name)[1].split('\n\n')[0]

    def turf_of(self, keys, key):
        return next(p for p in re.sub(r'\{.*?\}', '', keys[key]).split(',') if p.startswith('/turf/'))

    def dry(self, turf):
        return (turf.startswith('/turf/floor') and 'water' not in turf and 'underground' not in turf
                and 'lava' not in turf)

    def test_metadata_sits_once_in_the_south_west_corner(self):
        for name in PLAYABLE:
            keys, rows = self.maps[name]
            path = '/obj/map_metadata/nomads/earth_%s' % name
            holders = [k for k, v in keys.items() if 'map_metadata' in v]
            self.assertEqual(len(holders), 1, name)
            self.assertTrue(keys[holders[0]].startswith(path + ','), name)
            self.assertEqual(rows[-1][0:2], holders[0], name)
            self.assertEqual(sum(row.count(holders[0]) for row in rows), 1, name)

    def test_height_flow_and_flood_files_are_the_set_written_with_the_map(self):
        sys.path.insert(0, str(ROOT / 'scripts'))
        import terrain_heights
        for name in PLAYABLE:
            entry = DRAFTS[name]
            for kind, suffix in (('heights', '.txt'), ('flow', '.flow.txt'), ('flood', '.flood.txt')):
                self.assertEqual(entry[kind]['path'], 'maps/heights/nomads_earth_%s%s' % (name, suffix))
                data = (ROOT / entry[kind]['path']).read_bytes().replace(b'\r\n', b'\n')
                self.assertEqual(hashlib.sha256(data).hexdigest(), entry[kind]['sha256'],
                                 '%s %s: rerun tests/earth_maps/generate.py' % (name, kind))
            width, height, by_z = terrain_heights.read_heights(ROOT / entry['heights']['path'])
            self.assertEqual((width, height, sorted(by_z)), (tuple(entry['size']) + ([1],)), name)
            keys, rows = self.maps[name]
            levels = by_z[1]
            for y in range(0, height, 7):
                for x in range(0, width, 7):
                    wet = 'water' in self.turf_of(keys, rows[y][2 * x:2 * x + 2])
                    self.assertEqual(levels[y][x] == 0, wet, (name, x, y))
            # Mountains reach high levels; the island continent is the flattest land.
            self.assertGreaterEqual(max(max(r) for r in levels), 10 if name == 'oceania' else 12, name)
            self.assertIn('terrain_height_file = "%s"' % entry['heights']['path'], self.block(name))

    def test_registered_in_source(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertIn('#include "code\\game\\objects\\map_metadata\\nomads\\nomads_earth.dm"', dme)
        defines = (ROOT / 'code/__defines/maps.dm').read_text(encoding='utf-8')
        durable = (ROOT / 'code/modules/persistence/durable_nomads.dm').read_text(encoding='utf-8')
        jobs = (ROOT / 'code/modules/1713/jobs/nomads.dm').read_text(encoding='utf-8')
        supervisor = (ROOT / 'scripts/nomads-lifecycle/supervisor.py').read_text(encoding='utf-8')
        group = json.loads((ROOT / 'scripts/shard-group/earth_continents.example.json').read_text(encoding='utf-8'))
        regions = {r['id']: r['map'] for r in group['regions']}
        self.assertEqual(regions, {name: DRAFTS[name]['path'] for name in PLAYABLE})
        for name in PLAYABLE:
            map_id = 'MAP_NOMADS_EARTH_%s' % name.upper()
            self.assertIn('#define %s "NOMADS_EARTH_%s"' % (map_id, name.upper()), defines)
            self.assertIn('ID = %s' % map_id, self.block(name))
            self.assertIn('/obj/map_metadata/nomads/earth_%s,' % name, durable)
            self.assertIn(map_id + ',', jobs)
            self.assertIn("'NOMADS_EARTH_%s': 'nomads_earth_%s.dmm'" % (name.upper(), name), supervisor)
            self.assertIn('new_player_start_z = 1', self.block(name))

    def test_crossing_edges_have_dry_ground_and_lead_to_asia(self):
        self.assertIn('edge_crossings = list("east" = "asia")', self.block('europe'))
        self.assertIn('edge_crossings = list("east" = list("asia" = list(0.68, 1)))', self.block('africa'))
        self.assertIn('edge_crossings = list("west" = list("africa" = list(0, 0.45), "europe" = list(0.45, 1)))',
                      self.block('asia'))
        for name, side, (lo, hi) in (('europe', 'east', (0, 1)), ('africa', 'east', (0.68, 1)),
                                     ('asia', 'west', (0, 0.45)), ('asia', 'west', (0.45, 1))):
            keys, rows = self.maps[name]
            height = len(rows)
            col = len(rows[0]) - 2 if side == 'east' else 0
            step = -1 if side == 'east' else 1
            # Counted south to north, as region_edge.dm does.
            stretch = range(int(lo * height), int(hi * height))
            dry = [y for y in stretch if self.dry(self.turf_of(keys, rows[height - 1 - y][col:col + 2]))]
            self.assertGreater(len(dry), 40, (name, side, lo))
            # Arrivals are put three tiles in: that ground is mostly dry too.
            inner = [y for y in dry if self.dry(self.turf_of(keys, rows[height - 1 - y][col + 6 * step:col + 6 * step + 2]))]
            self.assertGreater(len(inner), 0.8 * len(dry), (name, side, lo))

    def test_sea_lanes_know_africa_and_the_new_coasts(self):
        lanes = (ROOT / 'code/modules/naval/sea_lanes.dm').read_text(encoding='utf-8')
        self.assertIn('"africa" = list(12, 3, list("W", "S", "E"), TRUE),', lanes)
        self.assertIn('map.sea_coasts : here[3]', lanes)
        self.assertIn('sea_coasts = list("W", "N")', self.block('europe'))
        self.assertIn('sea_coasts = list("W", "S", "E")', self.block('africa'))
        self.assertIn('sea_coasts = list("E", "S", "N")', self.block('asia'))
        self.assertIn('sea_coasts = list("N", "S", "W", "E")', self.block('oceania'))
        self.assertIn('sea_coasts = list("E", "S", "N")', self.block('greenland'))
        self.assertIn('sea_coasts = list("N", "E", "S", "W")', self.block('antarctica'))
        for land in ('oceania', 'greenland', 'antarctica'):
            self.assertIn('"%s" = list(' % land, lanes)
            self.assertNotIn('edge_crossings', self.block(land))
        for name, sides in (('europe', 'WN'), ('africa', 'WSE'), ('asia', 'ESN'), ('oceania', 'NSWE'),
                            ('greenland', 'ESN'), ('antarctica', 'NESW')):
            keys, rows = self.maps[name]
            sea = {k for k, v in keys.items() if 'saltwater' in v or 'ice/salty' in v}
            edge = {'N': [rows[0][i:i + 2] for i in range(0, len(rows[0]), 2)],
                    'S': [rows[-1][i:i + 2] for i in range(0, len(rows[-1]), 2)],
                    'W': [row[0:2] for row in rows], 'E': [row[-2:] for row in rows]}
            for side in sides:
                self.assertGreater(sum(k in sea for k in edge[side]) / len(edge[side]), 0.7, (name, side))

    def test_every_land_climate_has_seed_bushes_and_farm_ground_by_fresh_water(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location('outdoor_bootstrap', ROOT / 'scripts/check-outdoor-bootstrap.py')
        inventory = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(inventory)
        climates, salt = inventory.load_inheritance()
        for name in PLAYABLE:
            report = inventory.audit('earth_' + name, climates, salt)
            bushes = report['bush_seeding_ground_by_climate']
            if name == 'antarctica':
                # The ice continent grows nothing near fresh water (it is all
                # frozen); only its fringe seeds forage. Food comes by sea
                # (docs/earth-continents.md).
                self.assertGreaterEqual(sum(bushes.values()), 500)
                continue
            # A land's main climates: those with real room to forage in. A small
            # patch of another climate on a coast or a peak is not one.
            main = [c for c, ground in bushes.items() if ground >= 5000]
            self.assertGreaterEqual(len(main), 2 if name == 'greenland' else 4, name)
            if name == 'greenland':
                # Most of the ice island's farmable ground is snow on the tundra
                # coasts, cleared with a spade; its fjord forests are steep.
                ground = report['farm_ground_by_climate']['tundra']
                self.assertGreaterEqual(ground['ploughable_near_water'] + ground['clearable_near_water'], 1000)
                continue
            for climate in main:
                ground = report['farm_ground_by_climate'].get(climate, {'ploughable_near_water': 0, 'clearable_near_water': 0})
                with self.subTest(map=name, climate=climate):
                    self.assertGreaterEqual(ground['ploughable_near_water'] + ground['clearable_near_water'], 100)

    def test_berry_bushes_never_spin_on_a_land_with_little_grass(self):
        # Greenland hung at boot: each berry kind was placed until it reached a
        # count from the map's size, picking grass tiles until enough were
        # empty, and the ice island has far fewer than that.
        source = (ROOT / 'code/game/objects/map_metadata/_map_metadata.dm').read_text(encoding='utf-8')
        self.assertNotIn('for (var/v=1, v<=amt_to_create)', source)
        self.assertIn('amt_to_create = min(amt_to_create, round(grass_turf_list.len / 16))', source)
        self.assertIn('for (var/tries = 1, placed < amt_to_create && tries <= amt_to_create * 20, tries++)', source)


if __name__ == '__main__':
    unittest.main()
