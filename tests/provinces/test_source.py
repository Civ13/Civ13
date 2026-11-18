"""Provinces: the committed province files, the generator and the DM reader.

Checks every continent's province file against its map (size, every land
tile in a province, 4-12 unique names), that the generator splits a small
made-up map along a river, and that the game's reader expects the format the
tool writes.

    python3 tests/provinces/test_source.py
"""
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
import provinces  # noqa: E402
from terrain_heights import read_dmm  # noqa: E402

SOURCE = ROOT / 'code/modules/provinces/provinces.dm'
STAKE = ROOT / 'code/modules/provinces/province_stake.dm'
HOLDING = ROOT / 'code/modules/provinces/province_holding.dm'
DME = ROOT / 'civ13.dme'
# Map -> surface z, as scripts/provinces.py was run (docs/provinces.md).
CONTINENTS = {
    'nomads_gaia': 2, 'nomads_americas_north': 1, 'nomads_americas_south': 1,
    'nomads_europe': 1, 'nomads_asia': 1, 'nomads_desert': 2, 'nomads_jungle': 2,
}


class ProvinceFiles(unittest.TestCase):
    def test_every_continent_has_a_valid_file(self):
        for name, z in CONTINENTS.items():
            with self.subTest(map=name):
                width, height, fz, found, rows = provinces.read(ROOT / f'maps/provinces/{name}.txt')
                self.assertEqual(fz, z)
                self.assertTrue(provinces.MIN_PROVINCES <= len(found) <= provinces.MAX_PROVINCES)
                names = [n for _, n in found]
                self.assertEqual(len(names), len(set(names)), 'province names repeat')
                mw, mh, levels = read_dmm(ROOT / f'maps/nomads/{name}.dmm')
                self.assertEqual((width, height), (mw, mh))
                turfs = levels[z]
                for r, row in enumerate(turfs):
                    for c, turf in enumerate(row):
                        if provinces.tile_kind(turf) != provinces.WATER:
                            self.assertNotEqual(rows[r][c], '.', f'land at {c + 1},{height - r} is in no province')
                for char, _ in found:
                    self.assertTrue(any(char in row for row in rows), f'province {char} has no tiles')

    def test_files_exist_only_beside_a_height_file(self):
        for path in (ROOT / 'maps/provinces').glob('*.txt'):
            with self.subTest(file=path.name):
                self.assertTrue((ROOT / 'maps/heights' / path.name).exists())


class Generator(unittest.TestCase):
    def test_a_river_becomes_the_border(self):
        grass, river, sea = '/turf/floor/grass', '/turf/floor/beach/water/deep/jungle', '/turf/floor/beach/water/deep/saltwater'
        width, height = 60, 30
        turfs = []
        for r in range(height):
            row = []
            for c in range(width):
                if r in (0, height - 1) or c in (0, width - 1):
                    row.append(sea)
                elif c == 30:
                    row.append(river)
                else:
                    row.append(grass)
            turfs.append(row)
        flow = ['.' * width] * height
        flow = [row[:30] + ('s' if 0 < r < height - 1 else '.') + row[31:] for r, row in enumerate(flow)]
        heights = [[0] * width for _ in range(height)]
        old = provinces.SLIVER_SHARE
        try:
            provinces.SLIVER_SHARE = 0.1
            t, rows, found = provinces.build(turfs, heights, flow, count=2)
        finally:
            provinces.SLIVER_SHARE = old
        self.assertEqual(len(found), 2)
        west = {rows[r][c] for r in range(1, height - 1) for c in range(1, 30)}
        east = {rows[r][c] for r in range(1, height - 1) for c in range(31, width - 1)}
        self.assertEqual(len(west), 1)
        self.assertEqual(len(east), 1)
        self.assertNotEqual(west, east)

    def test_output_is_deterministic(self):
        turfs = [['/turf/floor/grass'] * 40 for _ in range(40)]
        heights = [[0] * 40 for _ in range(40)]
        first = provinces.build(turfs, heights, None, count=4)[1]
        second = provinces.build(turfs, heights, None, count=4)[1]
        self.assertEqual(first, second)


class Reader(unittest.TestCase):
    def test_reader_matches_the_format(self):
        text = SOURCE.read_text(encoding='utf-8')
        self.assertIn('"civ13-provinces 1"', text)
        self.assertEqual(provinces.HEADER, 'civ13-provinces 1')
        self.assertIn('replacetext(height_file, "maps/heights/", "maps/provinces/")', text)
        self.assertIn('should_save = FALSE', text)
        self.assertIn('#include "code\\modules\\provinces\\provinces.dm"', DME.read_text(encoding='utf-8'))

    def test_reader_never_sleeps(self):
        text = SOURCE.read_text(encoding='utf-8')
        self.assertNotIn('sleep(', text)
        self.assertNotIn('spawn(', text)


class Stake(unittest.TestCase):
    """The reviewed numbers (docs/provinces.md, "Stake") and the wiring."""

    def text(self):
        return STAKE.read_text(encoding='utf-8')

    def define(self, name):
        import re
        match = re.search(r'#define %s ([\d.]+)' % name, self.text())
        self.assertIsNotNone(match, name)
        return float(match.group(1))

    def test_numbers_match_the_plan(self):
        expected = {'STAKE_BED_HOURS': 72, 'STAKE_ROSTER_HOURS': 72, 'STAKE_TOTAL_MINUTES': 600,
                    'STAKE_ACTIVE_MINUTES': 240, 'STAKE_ACTIVE_DAYS': 3, 'STAKE_DAYS': 7,
                    'STAKE_HALL_RANGE': 40, 'STAKE_HALL_PER_TIER': 2, 'STAKE_LEAD_POINTS': 6,
                    'STAKE_LEAD_ACCOUNTS': 4, 'STAKE_LEAD_SHARE': 0.35, 'STAKE_LEAD_MARGIN': 1.25}
        for name, value in expected.items():
            self.assertEqual(self.define(name), value, name)

    def test_every_define_is_undefined(self):
        import re
        for name in re.findall(r'^#define (\w+)', self.text(), re.M):
            self.assertIn(f'#undef {name}', self.text())

    def test_resident_curve(self):
        # Mirror of province_resident_points: 1 each to 10, half to 30, a quarter after.
        def points(n):
            return min(n, 10) + 0.5 * max(0, min(n - 10, 20)) + 0.25 * max(n - 30, 0)
        self.assertEqual(points(4), 4)
        self.assertEqual(points(20), 15)
        self.assertEqual(points(50), 25)
        self.assertIn('min(count, 10) + 0.5 * Clamp(count - 10, 0, 20) + 0.25 * max(count - 30, 0)', self.text())

    def test_hall_points_capped_by_residents(self):
        self.assertIn('min(L[faction] * STAKE_HALL_PER_TIER, R[faction])', self.text())

    def test_wiring(self):
        self.assertIn('province_activity_start() // province_stake.dm',
                      (ROOT / 'code/game/mob/groups/faction_start.dm').read_text(encoding='utf-8'))
        factions = (ROOT / 'code/game/mob/groups/factions.dm').read_text(encoding='utf-8')
        self.assertEqual(factions.count('verbs += /mob/living/human/proc/province_holdings'), 2)
        self.assertIn('#include "code\\modules\\provinces\\province_stake.dm"', DME.read_text(encoding='utf-8'))
        self.assertNotIn('sleep(', self.text())
        self.assertNotIn('spawn(', self.text())
        self.assertNotIn('/Login()', self.text())
        self.assertNotIn(' in world', self.text())
        bed = (ROOT / 'code/game/objects/structures/stool_bed_chair_nest/bed.dm').read_text(encoding='utf-8')
        self.assertIn('all_beds += src', bed)
        self.assertIn('all_beds -= src', bed)


class Holding(unittest.TestCase):
    def text(self):
        return HOLDING.read_text(encoding='utf-8')

    def test_numbers_match_the_plan(self):
        import re
        expected = {'PROVINCE_GAIN_HOURS': 72, 'PROVINCE_LOSE_HOURS': 48, 'PROVINCE_CAP_PER_LAND': 3,
                    'PROVINCE_STATION_RESIDENTS': 3, 'PROVINCE_PREVIEW_DAYS': 21}
        for name, value in expected.items():
            match = re.search(r'#define %s (\d+)' % name, self.text())
            self.assertIsNotNone(match, name)
            self.assertEqual(int(match.group(1)), value, name)
            self.assertIn(f'#undef {name}', self.text())

    def test_rival_needs_the_margin_over_the_holder(self):
        self.assertIn('G[1] < 0.35 * S["total"] || G[1] < 1.25 * holder_stake', self.text())

    def test_stations_follow_holdings(self):
        station = (ROOT / 'code/game/mob/groups/recruitment_station.dm').read_text(encoding='utf-8')
        self.assertIn('isturf(loc) && !province_station_problem(src)', station)
        self.assertIn('province_station_problem(station, own)', station)
        start = (ROOT / 'code/game/mob/groups/faction_start.dm').read_text(encoding='utf-8')
        self.assertIn('!province_station_problem(S)', start)
        self.assertIn('province_holding_update() // province_holding.dm', STAKE.read_text(encoding='utf-8'))

    def test_lands_without_provinces_keep_stations(self):
        self.assertIn('return map && map.province_map() && world.realtime >= map.province_rules_from()', self.text())
        self.assertNotIn('sleep(', self.text())
        self.assertNotIn('spawn(', self.text())


if __name__ == '__main__':
    unittest.main()
