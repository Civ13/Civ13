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
RESOURCES = ROOT / 'code/modules/provinces/continent_resources.dm'
RANKS = ROOT / 'code/modules/provinces/province_ranks.dm'
UPKEEP = ROOT / 'code/modules/provinces/province_upkeep.dm'
SIEGE = ROOT / 'code/modules/provinces/province_siege.dm'
DME = ROOT / 'civ13.dme'
# Map -> surface z, as scripts/provinces.py was run (docs/provinces.md).
CONTINENTS = {
    'nomads_gaia': 2, 'nomads_americas_north': 1, 'nomads_americas_south': 1,
    'nomads_europe': 1, 'nomads_asia': 1, 'nomads_desert': 2, 'nomads_jungle': 2,
    'nomads_earth_europe': 1, 'nomads_earth_africa': 1,
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
        expected = {'PROVINCE_GAIN_HOURS': 72, 'PROVINCE_CAP_PER_LAND': 3,
                    'PROVINCE_STATION_RESIDENTS': 3, 'PROVINCE_PREVIEW_DAYS': 21}
        for name, value in expected.items():
            match = re.search(r'#define %s (\d+)' % name, self.text())
            self.assertIsNotNone(match, name)
            self.assertEqual(int(match.group(1)), value, name)
            self.assertIn(f'#undef {name}', self.text())

    def test_rival_needs_the_margin_over_the_holder(self):
        self.assertIn('G[1] < 0.35 * S["total"] || G[1] < margin * holder_stake', self.text())
        self.assertIn('/proc/province_rival(list/S, holder, margin = 1.25)', self.text())
        self.assertIn('province_rival(S, holder, province_rank_margin(rank))', self.text())

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



class ContinentResources(unittest.TestCase):
    """Val (2026-11-18): each continent rich in its own resource; Gaia not for the endgame."""

    def text(self):
        return RESOURCES.read_text(encoding='utf-8')

    def test_every_continent_has_a_home_resource(self):
        import re
        homes = dict(re.findall(r'(MAP_NOMADS_\w+) = list\(([^)]*)\)', self.text()))
        expected = {'MAP_NOMADS_GAIA': 'copper', 'MAP_NOMADS_JUNGLE': 'tin', 'MAP_NOMADS_AMERICAS_NORTH': 'iron',
                    'MAP_NOMADS_EUROPE': 'coal', 'MAP_NOMADS_ASIA': 'saltpeter', 'MAP_NOMADS_DESERT': 'sulphur',
                    'MAP_NOMADS_AMERICAS_SOUTH': 'bauxite', 'MAP_NOMADS_EARTH_EUROPE': 'coal',
                    'MAP_NOMADS_EARTH_AFRICA': 'sulphur'}
        for name, resource in expected.items():
            self.assertIn(f'"{resource}"', homes.get(name, ''), name)
        self.assertEqual(len(homes), len(CONTINENTS))

    def test_rates(self):
        text = self.text()
        for line in ('#define CONTINENT_HOME 2', '#define CONTINENT_BULK 0.5', '#define CONTINENT_STRATEGIC 0.33',
                     '#define CONTINENT_PHASE_DAYS 7', '"iron" = 1', '"bauxite" = 0, "uranium" = 0', '"tin" = 1'):
            self.assertIn(line, text)
        import re
        for name in re.findall(r'^#define (\w+)', text, re.M):
            self.assertIn(f'#undef {name}', text)
        self.assertIn('return max(rate, 0.75)', text)
        self.assertNotIn('sleep(', text)
        self.assertNotIn('spawn(', text)

    def test_mining_uses_the_factors(self):
        mining = (ROOT / 'code/game/turfs/floor_attackby.dm').read_text(encoding='utf-8')
        for ore in ('copper', 'tin', 'iron', 'zinc', 'coal', 'saltpeter', 'sulphur', 'lead', 'uranium', 'silver', 'gold', 'diamond', 'bauxite'):
            self.assertIn(f'continent_ore_factor("{ore}")', mining)
        self.assertIn('prob(copper_chance)', mining)
        self.assertNotIn('if (prob(12))', mining)
        self.assertIn('continent_ore_factor("gold")', (ROOT / 'code/modules/1713/lode.dm').read_text(encoding='utf-8'))
        self.assertIn('continent_ore_factor("gems")', (ROOT / 'code/modules/1713/gemstones.dm').read_text(encoding='utf-8'))
        self.assertIn('continent_seam_amount(ore_type', (ROOT / 'code/modules/1713/mountain_seams.dm').read_text(encoding='utf-8'))
        self.assertIn('#include "code\\modules\\provinces\\continent_resources.dm"', DME.read_text(encoding='utf-8'))



class Ranks(unittest.TestCase):
    """Val (2026-11-18): a clear objective for city building and defence."""

    def text(self):
        return RANKS.read_text(encoding='utf-8')

    def test_numbers(self):
        text = self.text()
        for line in ('#define RANK_SETTLEMENT 40', '#define RANK_DROP_HOURS 48', '#define RANK_MEMBERS_PER_RANK 3',
                     '#define RANK_WATCHTOWER_RANGE 10', 'list("Camp", "Village", "Town", "City")',
                     'if (2) return 1.35', 'if (3) return 1.5', 'if (4) return 1.6', 'return 1.25',
                     'if (3) return 60', 'if (4) return 72', 'return 48'):
            self.assertIn(line, text)
        import re
        for name in re.findall(r'^#define (\w+)', text, re.M):
            self.assertIn(f'#undef {name}', text)
        for needs in ('residents >= 4', 'residents >= 7', 'residents >= 11', 'residents >= 16', 'houses >= 3',
                      'plots >= 4', 'plots >= 10', 'plots >= 20', 'guests >= 2', 'guests >= 4', 'guests >= 6',
                      'ring["slits"] >= 12', 'province_strong_gates(gates) >= 2', 'ring["paved"] >= 60'):
            self.assertIn(needs, text)
        self.assertNotIn('sleep(', text)
        self.assertNotIn('spawn(', text)
        self.assertNotIn(' in world', text)

    def test_ring_never_leaves_the_settlement(self):
        ring = self.text().split('/proc/province_ring(', 1)[1].split('\n/proc/', 1)[0]
        self.assertIn('> RANK_SETTLEMENT)\n\t\t\t\treturn result', ring)
        self.assertIn('if (province_indoors(N) || province_indoors(T))', ring)

    def test_wiring(self):
        holding = HOLDING.read_text(encoding='utf-8')
        self.assertIn('province_rank_update(c, holder, S, name)', holding)
        self.assertIn('province_rank_lose_hours(rank) * 36000', holding)
        hall = (ROOT / 'code/game/mob/groups/faction_hall.dm').read_text(encoding='utf-8')
        self.assertIn('province_ledger_show(user, src)', hall)
        self.assertIn('+ province_rank_member_bonus(faction)', hall)
        self.assertIn('province_rank_bed_extra(account, get_turf(H))',
                      (ROOT / 'code/modules/research_tree/death_legacy.dm').read_text(encoding='utf-8'))
        self.assertIn('#include "code\\modules\\provinces\\province_ranks.dm"', DME.read_text(encoding='utf-8'))



class UpkeepAndRuins(unittest.TestCase):
    def text(self):
        return UPKEEP.read_text(encoding='utf-8')

    def test_numbers(self):
        text = self.text()
        for line in ('if (2) return 50', 'if (3) return 150', 'if (4) return 400', 'round(base * 1.5)', 'base * 2',
                     '#define RUIN_RESIDENTS 3', '#define RUIN_DAYS 14', '#define UPKEEP_WEEK 6048000'):
            self.assertIn(line, text)
        import re
        for name in re.findall(r'^#define (\w+)', text, re.M):
            self.assertIn(f'#undef {name}', text)
        self.assertNotIn('sleep(', text)
        self.assertNotIn('spawn(', text)
        self.assertNotIn(' in world', text)

    def test_upkeep_never_takes_from_a_short_box(self):
        take = self.text().split('/proc/province_upkeep_take(', 1)[1].split('\n/proc/', 1)[0]
        self.assertLess(take.index('if (B.coin_worth() < worth)'), take.index('M.use(count)'))

    def test_ruins_wait_for_the_rules_and_wiring(self):
        ruins = self.text().split('/proc/province_ruins_update(', 1)[1].split('\n/proc/', 1)[0]
        self.assertIn('if (!province_rules_active())', ruins)
        self.assertIn('province_ruins_update(stakes) // province_upkeep.dm', HOLDING.read_text(encoding='utf-8'))
        self.assertIn('province_upkeep_paid(c, group, seat)', RANKS.read_text(encoding='utf-8'))
        self.assertIn('#include "code\\modules\\provinces\\province_upkeep.dm"', DME.read_text(encoding='utf-8'))


class Sieges(unittest.TestCase):
    def text(self):
        return SIEGE.read_text(encoding='utf-8')

    def test_numbers(self):
        text = self.text()
        for line in ('#define SIEGE_WINDOW_HOURS 3', '#define SIEGE_BUSY_HOURS 8', '#define SIEGE_WINDOW_DELAY_HOURS 72',
                     '#define SIEGE_NOTICE_HOURS 24', '#define SIEGE_DEPOSIT 100', '#define SIEGE_SUSPEND_DAYS 7',
                     '#define SIEGE_IMMUNE_DAYS 3', '#define SIEGE_REPEAT_DAYS 14', '#define SIEGE_COOLDOWN_DAYS 3',
                     'if (2) return 15', 'if (3) return 20', 'if (4) return 30', 'return 10'):
            self.assertIn(line, text)
        import re
        for name in re.findall(r'^#define (\w+)', text, re.M):
            self.assertIn(f'#undef {name}', text)
        self.assertNotIn('sleep(', text)
        self.assertNotIn('spawn(', text)
        self.assertNotIn(' in world', text)

    def test_defenders_pause_the_capture(self):
        step = self.text().split('/proc/province_siege_step(', 1)[1].split('\n/proc/', 1)[0]
        self.assertLess(step.index('if (defenders)'), step.index('siege["progress"] += SIEGE_TICK'))
        self.assertIn('H.client', step)

    def test_deposit_spent_only_when_nobody_came(self):
        step = self.text().split('/proc/province_siege_step(', 1)[1].split('\n/proc/', 1)[0]
        self.assertEqual(step.count('province_upkeep_take('), 1)
        self.assertLess(step.index('if (siege["shown"])'), step.index('province_upkeep_take('))

    def test_holdings_change_only_in_the_window(self):
        holding = HOLDING.read_text(encoding='utf-8')
        self.assertIn('var/window = province_in_window(c)', holding)
        self.assertIn('province_rank_lose_hours(rank) * 36000 && window', holding)
        self.assertIn('PROVINCE_GAIN_HOURS * 36000 || !window', holding)
        self.assertIn('province_rank_effective(c)', holding)

    def test_wiring(self):
        ranks = RANKS.read_text(encoding='utf-8')
        self.assertIn('province_rank_effective(c)', ranks)
        self.assertIn('province_siege_text(c)', ranks)
        stake = STAKE.read_text(encoding='utf-8')
        self.assertIn('province_hours_record(active)', stake)
        self.assertIn('province_siege_resume()', stake)
        self.assertIn('#include "code\\modules\\provinces\\province_siege.dm"', DME.read_text(encoding='utf-8'))
        factions = (ROOT / 'code/game/mob/groups/factions.dm').read_text(encoding='utf-8')
        self.assertEqual(factions.count('verbs += /mob/living/human/proc/province_defence_window'), 2)
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        self.assertIn('/obj/structure/war_banner', recipes)
        self.assertIn('province_rename_faction(old_name, new_name)',
                      (ROOT / 'code/game/mob/groups/faction_recruitment.dm').read_text(encoding='utf-8'))


if __name__ == '__main__':
    unittest.main()
