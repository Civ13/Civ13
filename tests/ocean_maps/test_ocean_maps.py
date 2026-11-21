"""The ocean regions (docs/ocean-regions.md): maps, metadata and sea links.

Run: python3 -m unittest discover -s tests/ocean_maps
"""
import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))

from world_links import crossings, load  # noqa: E402
from ocean_maps import generate  # noqa: E402

LAND_MAPS = {
    'northamerica': ('maps/nomads/nomads_americas_north.dmm', 1),
    'southamerica': ('maps/nomads/nomads_americas_south.dmm', 1),
    'europe': ('maps/nomads/nomads_earth_europe.dmm', 1),
    'mediterranean': ('maps/nomads/nomads_earth_mediterranean.dmm', 1),
    'africa': ('maps/nomads/nomads_earth_africa.dmm', 1),
    'asia': ('maps/nomads/nomads_earth_asia.dmm', 1),
    'oceania': ('maps/nomads/nomads_earth_oceania.dmm', 1),
    'greenland': ('maps/nomads/nomads_earth_greenland.dmm', 1),
    'antarctica': ('maps/nomads/nomads_earth_antarctica.dmm', 1),
    'gaia': ('maps/nomads/nomads_gaia.dmm', 2),
}


def load_level(path, z):
    text = (ROOT / path).read_text(encoding='utf-8')
    keys = {}
    for m in re.finditer(r'^"(\w+)" = \((.*)\)$', text, re.M):
        keys[m.group(1)] = m.group(2)
    width = len(next(iter(keys)))
    m = re.search(r'^\(1,1,%d\) = \{"\n(.*?)\n"\}' % z, text, re.M | re.S)
    rows = [[keys[r[i:i + width]] for i in range(0, len(r), width)] for r in m.group(1).split('\n')]
    return rows[::-1]  # rows[y - 1][x - 1]


def edge_row(rows, side):
    if side == 'south':
        return rows[0]
    if side == 'north':
        return rows[-1]
    return [r[0] if side == 'west' else r[-1] for r in rows]


def stretch(row, lo, hi):
    n = len(row)
    first = min(max(round(lo * n) + 1, 1), n)
    last = min(max(round(hi * n), first), n)
    return row[first - 1:last]


def water(cell):
    turf = next((p for p in re.findall(r'(/[\w/]+)', cell) if p.startswith('/turf')), '')
    return turf.startswith('/turf/floor/beach/water') and '/ice' not in turf


class OceanMapTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.table = load()
        cls.sea = crossings(cls.table, 'sail')
        cls.levels = {}

    def level(self, region):
        if region not in self.levels:
            if region in self.table['oceans']:
                self.levels[region] = load_level('maps/nomads/nomads_ocean_%s.dmm' % region, 1)
            else:
                self.levels[region] = load_level(*LAND_MAPS[region])
        return self.levels[region]

    def test_maps_are_written_from_the_table(self):
        self.assertEqual(generate.main(['--check']), 0)

    def test_five_oceans(self):
        self.assertEqual(set(self.table['oceans']), {'atlantic', 'pacific', 'indian', 'arctic', 'southern'})

    def test_each_map_has_its_size_metadata_and_one_landing(self):
        for oid, ocean in self.table['oceans'].items():
            with self.subTest(oid):
                text = (ROOT / ('maps/nomads/nomads_ocean_%s.dmm' % oid)).read_text(encoding='utf-8')
                self.assertEqual(text.count('/obj/map_metadata/nomads/ocean/%s,' % oid), 1)
                self.assertEqual(text.count('JoinLateCiv'), 1)
                rows = self.level(oid)
                self.assertEqual((len(rows[0]), len(rows)), tuple(ocean['size']))
                self.assertNotIn('(1,1,2)', text)

    def test_insets_are_breakers(self):
        for oid, ocean in self.table['oceans'].items():
            rows = self.level(oid)
            for inset in ocean.get('insets', []):
                x0, y0, x1, y1 = inset['box']
                with self.subTest(oid=oid, land=inset['land']):
                    self.assertTrue(all('breakers' in rows[y - 1][x - 1] for y in (y0, y1) for x in (x0, x1)))
                    self.assertTrue(water(rows[y0 - 2][x0 - 2]) and water(rows[y1][x1]))

    def test_every_ocean_edge_leads_on_or_is_ice(self):
        for oid, ocean in self.table['oceans'].items():
            sides = set(self.sea.get(oid, {})) | set(ocean.get('wrap', []))
            if 'west' in ocean.get('wrap', []):
                sides.add('east')
            if ocean.get('ice'):
                sides.add(ocean['ice'][0])
            with self.subTest(oid):
                self.assertEqual(sides, {'north', 'south', 'east', 'west'})

    def test_sea_links_have_open_water_both_ends(self):
        for link in self.table['links']:
            if link['kind'] != 'sail':
                continue
            for region, side, lo, hi in (link['a'], link['b']):
                with self.subTest(region=region, side=side, lo=lo):
                    cells = stretch(edge_row(self.level(region), side), lo, hi)
                    share = sum(water(c) for c in cells) / len(cells)
                    self.assertGreater(share, 0.5)

    def test_island_lands_are_insets(self):
        lands = {i['land'] for o in self.table['oceans'].values() for i in o.get('insets', [])}
        self.assertEqual(lands, {'gaia', 'greenland'})

    def test_metadata_is_cheap_and_registered(self):
        dm = (ROOT / 'code/game/objects/map_metadata/nomads/nomads_ocean.dm').read_text(encoding='utf-8')
        base = dm.split('/obj/map_metadata/nomads/ocean\n')[1].split('\n\n')[0]
        for line in ('dig_down_underground = FALSE', 'building_levels = 0', 'ecology_wildlife_cap = 0',
                     'wild_plant_cap = 0', 'new_player_start_z = 1'):
            self.assertIn(line, base)
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertIn('#include "code\\modules\\naval\\ocean_regions.dm"', dme)
        self.assertIn('#include "code\\game\\objects\\map_metadata\\nomads\\nomads_ocean.dm"', dme)
        defines = (ROOT / 'code/__defines/maps.dm').read_text(encoding='utf-8')
        durable = (ROOT / 'code/modules/persistence/durable_nomads.dm').read_text(encoding='utf-8')
        jobs = (ROOT / 'code/modules/1713/jobs/nomads.dm').read_text(encoding='utf-8')
        supervisor = (ROOT / 'scripts/nomads-lifecycle/supervisor.py').read_text(encoding='utf-8')
        for oid in self.table['oceans']:
            with self.subTest(oid):
                map_id = 'MAP_NOMADS_OCEAN_%s' % oid.upper()
                self.assertIn('#define %s "NOMADS_OCEAN_%s"' % (map_id, oid.upper()), defines)
                block = dm.split('/obj/map_metadata/nomads/ocean/%s\n' % oid)[1].split('\n\n')[0]
                self.assertIn('ID = %s' % map_id, block)
                self.assertIn('ocean = "%s"' % oid, block)
                self.assertIn('/obj/map_metadata/nomads/ocean/%s,' % oid, durable)
                self.assertIn(map_id + ',', jobs)
                self.assertIn("'NOMADS_OCEAN_%s': 'nomads_ocean_%s.dmm'" % (oid.upper(), oid), supervisor)

    def test_dm_tables_name_the_oceans(self):
        dm = (ROOT / 'code/modules/persistence/world_links.dm').read_text(encoding='utf-8')
        for oid in self.table['oceans']:
            self.assertIn('\t"%s" = list(' % oid, dm.split('var/global/list/world_oceans')[1].split('\n)\n')[0])
        self.assertIn('"gaia" = list(250, 560, 299, 594)', dm)
        # Oceans are no voyage destination: the continent layout lists lands only.
        layout = dm.split('var/global/list/continent_layout')[1]
        for oid in self.table['oceans']:
            self.assertNotIn('"%s"' % oid, layout)


if __name__ == '__main__':
    unittest.main()
