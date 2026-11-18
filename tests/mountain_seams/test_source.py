"""Mountain seams: map facts and source contract checks.

The loop relies on one map fact: on both Americas maps the caves area holds
only mountain rock, so open dirt in that area is mined-out mountain. These
checks read the committed maps, mirror the seam hash to check the share and
district spread, and pin the wiring (opt-in, include order, nothing saved).

    python3 tests/mountain_seams/test_source.py
"""
import collections
import hashlib
import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/mountain_seams.dm'
METADATA = ROOT / 'code/game/objects/map_metadata/nomads/nomads_americas.dm'
ASIA_METADATA = ROOT / 'code/game/objects/map_metadata/nomads/nomads_asia.dm'
ASIA_MAP = ROOT / 'maps/nomads/nomads_asia.dmm'
EARTH_METADATA = ROOT / 'code/game/objects/map_metadata/nomads/nomads_earth.dm'
DME = ROOT / 'civ13.dme'
MAPS = {
    'NOMADS_AMERICAS_NORTH': ROOT / 'maps/nomads/nomads_americas_north.dmm',
    'NOMADS_AMERICAS_SOUTH': ROOT / 'maps/nomads/nomads_americas_south.dmm',
}
CAVES = '/area/caribbean/void/caves'
ROCK = ('/turf/floor/dirt/underground', '/turf/wall/rockwall')


def source():
    return SOURCE.read_text(encoding='utf-8')


def define(name):
    match = re.search(r'#define %s (\d+)' % name, source())
    return int(match.group(1))


def read_map(path):
    """Yields (x, y, turf, area) for every tile of the single z level."""
    text = path.read_text(encoding='utf-8')
    keys = dict(re.findall(r'^"(\w+)" = \((.*?)\)\n', text, re.M | re.S))
    width = len(next(iter(keys)))
    grid = re.search(r'\(1,1,1\) = \{"\n(.*?)\n"\}', text, re.S).group(1).split('\n')
    rows = len(grid)
    parsed = {}
    for key, body in keys.items():
        paths = [p.strip() for p in re.split(r',\s*(?=/)', body)]
        turf = next(p for p in paths if p.startswith('/turf'))
        area = next(p for p in paths if p.startswith('/area'))
        parsed[key] = (turf, area)
    for row, line in enumerate(grid):
        y = rows - row
        for column in range(0, len(line), width):
            turf, area = parsed[line[column:column + width]]
            yield column // width + 1, y, turf, area


def hash16(text):
    return int(hashlib.md5(text.encode()).hexdigest()[:4], 16)


def ore_weights():
    rows = re.findall(r'/obj/item/stack/ore/(\w+) = list\((\d+), (\d+), (\d+), (\d+)\)', source())
    return [(name, int(w), int(age), int(lo), int(hi)) for name, w, age, lo, hi in rows]


def district_ore(x, y, map_id):
    block = define('MOUNTAIN_SEAM_DISTRICT')
    roll = hash16('%d,%d,%s,ore' % ((x - 1) // block, (y - 1) // block, map_id)) % 100
    for name, weight, _, _, _ in ore_weights():
        roll -= weight
        if roll < 0:
            return name
    return 'copper'


class MapFacts(unittest.TestCase):
    def test_caves_area_is_exactly_the_mountains(self):
        for map_id, path in MAPS.items():
            with self.subTest(map=map_id):
                rock = seams = 0
                ores = collections.Counter()
                for x, y, turf, area in read_map(path):
                    in_caves = area == CAVES or area.startswith(CAVES + '/')
                    is_rock = turf.startswith(ROCK)
                    self.assertEqual(in_caves, is_rock, '%s at %d,%d in %s' % (turf, x, y, area))
                    if is_rock and turf.startswith(ROCK[0]):
                        rock += 1
                        if hash16('%d,%d,%s' % (x, y, map_id)) % define('MOUNTAIN_SEAM_SHARE') == 0:
                            seams += 1
                            ores[district_ore(x, y, map_id)] += 1
                self.assertGreater(rock, 30000)
                share = seams / rock
                self.assertAlmostEqual(share, 1 / define('MOUNTAIN_SEAM_SHARE'), delta=0.01)
                # Every common ore shows up in quantity on each continent.
                for name in ('copper', 'tin', 'iron', 'coal'):
                    self.assertGreater(ores[name], 100, (map_id, dict(ores)))


    def test_asia_caves_area_is_mountain_or_open_cave_floor(self):
        # Asia is hand-drawn: its caves area is mountain rock plus a little
        # open cave floor, which is seam ground from the first day. Nothing
        # else (water, grass, built floors) lies in it.
        rock = seams = floor = 0
        ores = collections.Counter()
        for x, y, turf, area in read_map(ASIA_MAP):
            if not (area == CAVES or area.startswith(CAVES + '/')):
                self.assertFalse(turf.startswith(ROCK[0]), '%s at %d,%d in %s' % (turf, x, y, area))
                continue
            if turf.startswith(ROCK[0]):
                rock += 1
            else:
                self.assertEqual(turf, '/turf/floor/dirt', '%s at %d,%d' % (turf, x, y))
                floor += 1
            if hash16('%d,%d,NOMADS_ASIA' % (x, y)) % define('MOUNTAIN_SEAM_SHARE') == 0:
                seams += 1
                ores[district_ore(x, y, 'NOMADS_ASIA')] += 1
        self.assertGreater(rock, 14000)
        self.assertLess(floor, 200)
        self.assertAlmostEqual(seams / (rock + floor), 1 / define('MOUNTAIN_SEAM_SHARE'), delta=0.01)
        for name in ('copper', 'tin', 'iron', 'coal'):
            self.assertGreater(ores[name], 50, dict(ores))


class SourceContract(unittest.TestCase):
    def test_weights_and_gates(self):
        rows = ore_weights()
        self.assertEqual(sum(row[1] for row in rows), 100)
        gates = {row[0]: row[2] for row in rows}
        self.assertEqual(gates['iron'], 1)
        self.assertEqual(gates['zinc'], 1)
        for name in ('coal', 'saltpeter', 'sulphur', 'lead'):
            self.assertEqual(gates[name], 2)
        for name in ('copper', 'tin', 'silver', 'gold'):
            self.assertEqual(gates[name], 0)
        # Rare finds stay fresh rock only.
        for rare in ('diamond', 'uranium', 'bauxite', 'gem', 'obsidian'):
            self.assertNotIn(rare, gates)

    def test_slower_than_a_wall_and_regrows(self):
        self.assertEqual(define('MOUNTAIN_SEAM_WORK'), 480)
        self.assertIn('#define MOUNTAIN_SEAM_REGROW (20 MINUTES)', source())
        self.assertEqual(define('MOUNTAIN_SEAM_LOADS'), 6)
        self.assertIn('new /datum/resource_stock(MOUNTAIN_SEAM_LOADS, MOUNTAIN_SEAM_REGROW)', source())

    def test_opt_in_on_the_one_level_mountain_maps_only(self):
        meta = METADATA.read_text(encoding='utf-8')
        self.assertEqual(meta.count('mountain_seams = TRUE'), 2)
        self.assertEqual(ASIA_METADATA.read_text(encoding='utf-8').count('\tmountain_seams = TRUE\n'), 1)
        # The Earth-shaped Europe, Africa and Asia are one-level mountain maps too.
        self.assertEqual(EARTH_METADATA.read_text(encoding='utf-8').count('\tmountain_seams = TRUE\n'), 3)
        self.assertIn('/obj/map_metadata/var/mountain_seams = FALSE', source())
        others = [p for p in (ROOT / 'code').rglob('*.dm')
                  if p not in (SOURCE, METADATA, ASIA_METADATA, EARTH_METADATA) and 'mountain_seams = TRUE' in p.read_text(encoding='utf-8', errors='replace')]
        self.assertEqual(others, [])

    def test_ground_rule(self):
        ground = re.search(r'/proc/mountain_seam_ground\(turf/T\)\n(.*?)\n(?=\S)', source(), re.S).group(1)
        for needle in ('map.mountain_seams', 'T.z != 1', 'istype(T, /turf/floor/dirt/underground)',
                       'T.is_mineable', '/area/caribbean/void/caves', '/obj/covers', 'O.density && O.anchored'):
            self.assertIn(needle, ground)

    def test_nothing_saved(self):
        text = source()
        # Stocks and busy flags are globals, never atom vars.
        self.assertNotRegex(text, r'/turf[^\n]*/var/')
        self.assertNotRegex(text, r'/mob[^\n]*/var/')
        self.assertIn('var/global/list/mountain_seam_stock = list()', text)

    def test_hooks_fall_through(self):
        text = source()
        attack = re.search(r'/turf/floor/dirt/attackby\(obj/item/C, mob/user\)\n(.*?)\n(?=\S)', text, re.S).group(1)
        self.assertIn('return ..()', attack)
        self.assertIn('mountain_seam_ground(src)', attack)
        change = re.search(r'/turf/change_the_turf\(\)\n(.*?)\n(?=\S)', text, re.S).group(1)
        self.assertIn('..()', change)
        self.assertIn('if (map && map.mountain_seams)', change)

    def test_included_after_other_dirt_overrides(self):
        lines = DME.read_text(encoding='utf-8').splitlines()
        index = {line: n for n, line in enumerate(lines)}
        mine = index['#include "code\\modules\\1713\\mountain_seams.dm"']
        for other in ('trench.dm', 'road_tamping.dm', 'underground_excavation.dm'):
            self.assertLess(index['#include "code\\modules\\1713\\%s"' % other], mine)


if __name__ == '__main__':
    result = unittest.main(exit=False, verbosity=1).result
    sys.exit(0 if result.wasSuccessful() else 1)
