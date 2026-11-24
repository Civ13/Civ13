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
RICH = ROOT / 'code/modules/provinces/province_rich.dm'
TREATIES = ROOT / 'code/modules/provinces/province_treaties.dm'
DME = ROOT / 'civ13.dme'
# Map -> surface z, as scripts/provinces.py was run (docs/provinces.md).
CONTINENTS = {
    'nomads_gaia': 2, 'nomads_americas_north': 1, 'nomads_americas_south': 1,
    'nomads_europe': 1, 'nomads_asia': 1, 'nomads_desert': 2, 'nomads_jungle': 2,
    'nomads_earth_europe': 1, 'nomads_earth_africa': 1, 'nomads_earth_asia': 1, 'nomads_earth_oceania': 1, 'nomads_earth_greenland': 1,
    'nomads_earth_antarctica': 1, 'nomads_earth_mediterranean': 1,
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
            self.assertIn(f'continent_ore_factor("{ore}", src)', mining)
        self.assertIn('prob(copper_chance)', mining)
        self.assertNotIn('if (prob(12))', mining)
        self.assertIn('continent_ore_factor("gold", src)', (ROOT / 'code/modules/1713/lode.dm').read_text(encoding='utf-8'))
        self.assertIn('continent_ore_factor("gems", src)', (ROOT / 'code/modules/1713/gemstones.dm').read_text(encoding='utf-8'))
        self.assertIn('continent_seam_amount(ore_type', (ROOT / 'code/modules/1713/mountain_seams.dm').read_text(encoding='utf-8'))
        self.assertIn('#include "code\\modules\\provinces\\continent_resources.dm"', DME.read_text(encoding='utf-8'))



class LandOil(unittest.TestCase):
    """Val (2026-11-18): land oil wells work only on desert ground, which means Africa's deserts."""

    def test_springs_flow_only_on_oil_land_desert(self):
        text = RESOURCES.read_text(encoding='utf-8')
        self.assertIn('lands = list(MAP_NOMADS_DESERT, MAP_NOMADS_EARTH_AFRICA)', text)
        self.assertIn('istype(T, /turf/floor/beach/sand/desert) || istype(T, /turf/floor/dirt/dust)', text)
        # Off the continents springs flow as before; elsewhere they dry up with the phase-in.
        self.assertIn('if (!continent_home())\n\t\treturn TRUE', text)
        self.assertIn('return continent_phased(0) > 0', text)
        self.assertIn('text += " [continent_land_oil_text()]"', text)

    def test_springs_and_wells_ask(self):
        spring = (ROOT / 'code/modules/1713/oil_fires.dm').read_text(encoding='utf-8')
        self.assertIn('if (continent_land_oil_at(get_turf(src)))', spring)
        self.assertIn("if (refill_pending || !isturf(loc) || !flows())", spring)
        self.assertLess(spring.index('if (!flows())\n\t\tto_chat(user, SPAN_WARNING('), spring.index('if (counter <= 0)'))
        well = (ROOT / 'code/modules/1713/production.dm').read_text(encoding='utf-8')
        self.assertIn('return base && base.loc == loc && base.flows()', well)
        # Offshore rigs keep their own source.
        self.assertNotIn('flows()', (ROOT / 'code/modules/1713/offshore_rig.dm').read_text(encoding='utf-8'))


class GaiaCrops(unittest.TestCase):
    """Val (2026-11-18): crops grow faster on Gaia."""

    def test_extra_stage_only_on_gaia_before_harvest(self):
        text = RESOURCES.read_text(encoding='utf-8')
        self.assertIn('#define CONTINENT_GAIA_CROPS 25', text)
        self.assertIn('/obj/structure/farming/plant/advance_stage_if_allowed(allow_stage)\n\tvar/before = stage\n\t. = ..(allow_stage)', text)
        self.assertIn('if (stage > before && stage < readyStageMin && map && map.ID == MAP_NOMADS_GAIA && prob(CONTINENT_GAIA_CROPS))\n\t\tstageGrowth()', text)
        self.assertIn('Crops grow about a quarter faster here.', text)


class Fracking(unittest.TestCase):
    """Val (2026-11-18): Americas frack in later eras at the cost of their land; options 1-4."""

    def test_rules(self):
        text = (ROOT / 'code/modules/provinces/province_fracking.dm').read_text(encoding='utf-8')
        for line in ('lands = list(MAP_NOMADS_AMERICAS_NORTH, MAP_NOMADS_AMERICAS_SOUTH)', '#define FRACK_POLLUTION 25',
                     '#define FRACK_POLLUTION_RADIUS 3', '#define FRACK_FOUL_RANGE 6', '#define FRACK_FOUL_TIME 864000',
                     'if (!holder || holder != side)', 'pollution_emit(T, FRACK_POLLUTION, FRACK_POLLUTION_RADIUS)',
                     'if (!continent_home()) // continent_resources.dm\n\t\treturn null'):
            self.assertIn(line, text)
        import re
        for name in re.findall(r'^#define (\w+)', text, re.M):
            self.assertIn(f'#undef {name}', text)
        self.assertNotIn('sleep(', text)
        self.assertNotIn('spawn(', text)

    def test_wiring(self):
        rig = (ROOT / 'code/modules/1713/hydraulic_fracturing.dm').read_text(encoding='utf-8')
        self.assertLess(rig.index('var/refusal = fracking_refusal(H, get_turf(src))'), rig.index('if (!fracture_batch() || !check_power())\n\t\tstop_drilling()\n\t\tto_chat'))
        self.assertIn('output.reagents.add_reagent("petroleum", 50)\n\t\tfracking_batch_cost(src)', rig)
        sink = (ROOT / 'code/game/objects/structures/watercloset.dm').read_text(encoding='utf-8')
        self.assertIn('latrine_fouls_near(src) || fracking_fouls_near(src)', sink)
        self.assertIn('#include "code\\modules\\provinces\\province_fracking.dm"', DME.read_text(encoding='utf-8'))


class RubberTrees(unittest.TestCase):
    """Val (2026-11-18): rubber trees grow only in jungle (Africa, Asia's south, the Jungle)."""

    def test_rules_and_wiring(self):
        text = (ROOT / 'code/modules/1713/rubber_tapping.dm').read_text(encoding='utf-8')
        for line in ('lands = list(MAP_NOMADS_JUNGLE, MAP_NOMADS_EARTH_AFRICA, MAP_NOMADS_EARTH_ASIA)',
                     'return type == /obj/structure/wild/jungle && health > 0 && rubber_trees_here()',
                     '#define RUBBER_TAP_LATEX 10', '#define RUBBER_CURE_LATEX 10'):
            self.assertIn(line, text)
        import re
        for name in re.findall(r'^#define (\w+)', text, re.M):
            self.assertIn(f'#undef {name}', text)
        self.assertNotIn('sleep(', text)
        self.assertNotIn('spawn(', text)
        wild = (ROOT / 'code/game/objects/structures/wild.dm').read_text(encoding='utf-8')
        self.assertIn('/obj/structure/wild/jungle/attackby(obj/item/W as obj, mob/user as mob)\n\tif (rubber_tap_attackby(src, W, user))', wild)
        ores = (ROOT / 'code/modules/1713/ores.dm').read_text(encoding='utf-8')
        self.assertIn('if (rubber_cure_attackby(src, W, H)) // rubber_tapping.dm', ores)
        self.assertIn('istype(W, /obj/item/stack/material/plastic) || istype(W, /obj/item/stack/material/rubber)',
                      (ROOT / 'code/modules/naval/air_hull.dm').read_text(encoding='utf-8'))
        self.assertIn('RECIPE: /material/rubber/,rubber boots,', (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8'))
        self.assertIn('text += " [rubber_text()]"', RESOURCES.read_text(encoding='utf-8'))


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

    def test_hammer_dismantling_rechecks_siege_binding_before_salvage(self):
        text = self.text()
        dismantle = text.split('/obj/structure/war_banner/attackby(', 1)[1].split('\n/', 1)[0]
        self.assertIn('if (!is_tool(O, TOOL_HAMMER))\n\t\treturn ..()', dismantle)
        binding = '\n\tif (faction)'
        start, finish = (dismantle.index(binding), dismantle.rindex(binding))
        wait = dismantle.index('if (!do_ship_fixture_after(user, 25, src) || QDELETED(src))')
        salvage = dismantle.index('crafted_refund_stack(type, /obj/item/stack/material/wood)')
        self.assertTrue(start < wait < finish < salvage < dismantle.index('qdel(src)'))
        for guard, end in ((start, wait), (finish, salvage)):
            self.assertIn('\n\t\treturn TRUE', dismantle[guard:end])
        self.assertIn('if (refund)\n\t\tnew refund(get_turf(src))', dismantle)
        self.assertIn('faction = user.civilization', text.split('/obj/structure/war_banner/attack_hand(', 1)[1])
        end = text.split('/proc/province_siege_end(', 1)[1].split('\n/proc/', 1)[0]
        self.assertIn('W.faction = null', end)
        destroy = text.split('/obj/structure/war_banner/Destroy()', 1)[1].split('\n/', 1)[0]
        self.assertIn('province_siege_banner_lost(src)', destroy)

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


class Treaties(unittest.TestCase):
    """Nation treaties: allies and pact partners never contest, sieges need war."""

    def test_rules(self):
        text = TREATIES.read_text(encoding='utf-8')
        kinds = text[text.index('/proc/province_treaty_kinds'):text.index('/proc/province_groups_at_war')]
        # Only two nations have treaties; a plain faction keeps today's rules.
        self.assertIn('findtext(group_a, "nation:") != 1 || findtext(group_b, "nation:") != 1', kinds)
        self.assertIn('nation_treaties_of(copytext(group_a, 8))["in_force"]', kinds)
        friendly = text[text.index('/proc/province_groups_friendly'):text.index('/proc/province_treaty_siege_block')]
        self.assertIn('province_groups_allied(group_a, group_b) || ("pact" in province_treaty_kinds(group_a, group_b))', friendly)
        allied = text[text.index('/proc/province_groups_allied'):text.index('/proc/province_groups_friendly')]
        # An overlord and its vassal count as allies.
        self.assertIn('("alliance" in kinds) || ("overlord" in kinds) || ("vassal" in kinds)', allied)
        block = text[text.index('/proc/province_treaty_siege_block'):text.index('/proc/province_siege_side')]
        self.assertLess(block.index('return null'), block.index('province_groups_at_war'))
        side = text[text.index('/proc/province_siege_side'):]
        # An ally of both sides defends.
        self.assertLess(side.index('province_groups_allied(group, holder)'), side.index('province_groups_allied(group, attacker)'))
        self.assertNotIn('sleep(', text)
        self.assertNotIn('spawn(', text)

    def test_wiring(self):
        holding = HOLDING.read_text(encoding='utf-8')
        rival = holding[holding.index('/proc/province_rival'):holding.index('/proc/province_tell_leaders')]
        self.assertIn('group == holder || province_groups_friendly(group, holder)', rival)
        siege = SIEGE.read_text(encoding='utf-8')
        block = siege[siege.index('/proc/province_siege_block'):siege.index('/obj/structure/war_banner')]
        self.assertIn('province_treaty_siege_block(group, holder)', block)
        step = siege[siege.index('/proc/province_siege_step'):siege.index('/proc/province_siege_won')]
        off = step.index('province_treaty_siege_block(siege["group"], holder)')
        # Called off before the deposit or cooldown code runs.
        self.assertLess(off, step.index('province_upkeep_take'))
        self.assertLess(off, step.index('cooldown[siege["group"]]'))
        self.assertIn('province_siege_side(province_group_of(H.civilization), siege["group"], holder)', step)
        self.assertIn('#include "code\\modules\\provinces\\province_treaties.dm"', DME.read_text(encoding='utf-8'))
        self.assertIn('## Treaties', (ROOT / 'docs/provinces.md').read_text(encoding='utf-8'))


class VassalTribute(unittest.TestCase):
    """Vassal tribute and siege reports (province_treaties.dm)."""

    def test_tribute_rules(self):
        text = TREATIES.read_text(encoding='utf-8')
        for line in ('#define VASSAL_TRIBUTE_DAYS 7', '#define VASSAL_TRIBUTE_SHARE 0.1', '#define VASSAL_TRIBUTE_CAP 100'):
            self.assertIn(line, text)
        import re
        for name in re.findall(r'^#define (\w+)', text, re.M):
            self.assertIn(f'#undef {name}', text)
        tribute = text[text.index('/proc/province_vassal_tribute'):]
        # Real coin moves from a home faction's box, only when an overlord box is here.
        self.assertLess(tribute.index('if (!to_box)'), tribute.index('province_coin_move(from_box, to_box, due)'))
        self.assertIn('nation_home_faction(name) ? map.faction_strongbox(name) : null', tribute)
        self.assertIn('min(VASSAL_TRIBUTE_CAP, round(from_box.coin_worth() * VASSAL_TRIBUTE_SHARE))', tribute)
        move = text[text.index('/proc/province_coin_move'):text.index('/proc/province_vassal_tribute')]
        self.assertNotIn('new /obj', move)
        self.assertIn('out.forceMove(into)', move)
        self.assertIn('province_vassal_tribute()', (ROOT / 'code/game/mob/groups/nation.dm').read_text(encoding='utf-8'))
        self.assertNotIn('sleep(', text)

    def test_siege_wins_are_reported(self):
        siege = SIEGE.read_text(encoding='utf-8')
        won = siege[siege.index('/proc/province_siege_won'):siege.index('/proc/province_siege_text')]
        self.assertIn('province_siege_report(siege["faction"], holder)', won)
        text = TREATIES.read_text(encoding='utf-8')
        report = text[text.index('/proc/province_siege_report'):text.index('/proc/nation_overlord_of')]
        self.assertIn('"op" = "siege_won", "actor" = "world"', report)


class RichProvinces(unittest.TestCase):
    def text(self):
        return RICH.read_text(encoding='utf-8')

    def picks(self):
        """The rich provinces each continent gets, computed as province_rich_list does."""
        import hashlib
        import re
        defines = dict(re.findall(r'#define (MAP_NOMADS_\w+) "(\w+)"',
                                  (ROOT / 'code/__defines/maps.dm').read_text(encoding='utf-8')))
        homes = re.findall(r'(MAP_NOMADS_\w+) = list\(([^)]*)\)', RESOURCES.read_text(encoding='utf-8'))
        ores = set(re.findall(r'^\t\t"(\w+)" = list\(/obj/item/stack/ore/', self.text(), re.M))
        out = {}
        for define, listed in homes:
            map_id = defines[define]
            name = 'nomads_' + map_id.lower().replace('nomads_', '')
            candidates = [r.strip().strip('"') for r in listed.split(',') if r.strip().strip('"') in ores]
            names = {}
            for line in (ROOT / 'maps/provinces' / f'{name}.txt').read_text(encoding='utf-8').splitlines()[3:]:
                if not line.startswith('province '):
                    break
                names[line[9]] = line[11:]
            want = 3 if len(names) > 8 else 2
            order = {c: int(hashlib.md5(f'{map_id}|{c}|rich'.encode()).hexdigest()[:4], 16) for c in names}
            chosen = sorted(order, key=lambda c: (order[c], c))[:want]
            out[name] = [(names[c], candidates[i % len(candidates)]) for i, c in enumerate(chosen)]
        return out

    def test_every_continent_has_rich_provinces_of_its_own_resources(self):
        picks = self.picks()
        self.assertEqual(set(picks), set(CONTINENTS))
        for name, rich in picks.items():
            self.assertIn(len(rich), (2, 3), name)
            self.assertEqual(len({p for p, _ in rich}), len(rich), name)

    def test_docs_list_the_rich_provinces(self):
        docs = (ROOT / 'docs/provinces.md').read_text(encoding='utf-8')
        for name, rich in self.picks().items():
            line = next((l for l in docs.splitlines() if l.startswith(f'| {name} |')), None)
            self.assertIsNotNone(line, name)
            for province, resource in rich:
                self.assertIn(f'{province} ({resource})', line)

    def test_numbers_and_wiring(self):
        text = self.text()
        for line in ('#define RICH_LOADS_UNRANKED 4', 'if (1) loads = 6', 'if (2) loads = 10', 'if (3) loads = 16',
                     'if (4) loads = 24', 'before >= 2 ? max(1, round(loads / 2)) : loads'):
            self.assertIn(line, text)
        import re
        for name in re.findall(r'^#define (\w+)', text, re.M):
            self.assertIn(f'#undef {name}', text)
        self.assertNotIn('sleep(', text)
        self.assertNotIn('spawn(', text)
        self.assertNotIn(' in world', text)
        self.assertIn('#define CONTINENT_RICH 3', RESOURCES.read_text(encoding='utf-8'))
        floor = (ROOT / 'code/game/turfs/floor_attackby.dm').read_text(encoding='utf-8')
        self.assertIn('province_rich_attackby(src, C, user)', floor)
        self.assertIn('continent_ore_factor("copper", src)', floor)
        self.assertIn('province_rich_mark_all()', STAKE.read_text(encoding='utf-8'))
        self.assertIn('#include "code\\modules\\provinces\\province_rich.dm"', DME.read_text(encoding='utf-8'))


if __name__ == '__main__':
    unittest.main()
