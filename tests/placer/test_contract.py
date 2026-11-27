"""Placer mining: source contract and balance checks.

Pay dirt is dug from river banks, its grade set by a hashed district (about a
quarter gold-bearing); the pan, the sluice box and the rocker wash it. The
gold-per-person-hour targets from the approved plan are checked here from
the source numbers: pan 30 (existing), sluice 60 on rich ground and about 20
on poor, rocker 80.

    python3 tests/placer/test_contract.py
"""
import hashlib
import re
import struct
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/1713/placer.dm').read_text(encoding='utf-8')
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
NODES = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
RECIPES = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
DMI = ROOT / 'icons/obj/placer.dmi'


def body(file, signature):
    path = ROOT / 'code/modules/1713' / (file + '.dm')
    return path.read_text(encoding="utf-8").split(signature, 1)[1].split('\n/', 1)[0]

def define(name):
    match = re.search(rf'#define {name} ([0-9.]+)', SOURCE)
    assert match, name
    return float(match.group(1))


def dmi_description(path):
    data = path.read_bytes()
    pos = 8
    while pos < len(data):
        length, kind = struct.unpack('>I4s', data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        if kind in (b'zTXt', b'tEXt') and body.startswith(b'Description\0'):
            text = body[len(b'Description\0'):]
            return zlib.decompress(text[1:]).decode() if kind == b'zTXt' else text.decode()
        pos += 12 + length
    return ''


def grade_chances(grade):
    block = SOURCE[SOURCE.index(f'if ("{grade}")', SOURCE.index('/proc/pay_dirt_wash(')):]
    return int(re.search(r'gold = (\d+)', block).group(1))


def gold_per_hour(grade, method, wash_define):
    scale = {'rocker': 1.2, 'pan': 0.55}.get(method, 1)
    seconds = (define('PAY_DIRT_DIG_TIME') + define(wash_define)) / 10
    return 3600 / seconds * grade_chances(grade) / 100 * scale


class Balance(unittest.TestCase):
    def test_scales_match_source(self):
        self.assertIn('var/scale = method == "rocker" ? 1.2 : (method == "pan" ? 0.55 : 1)', SOURCE)

    def test_sluice_rates(self):
        self.assertAlmostEqual(gold_per_hour('rich', 'sluice', 'SLUICE_WASH_TIME'), 60, delta=5)
        self.assertAlmostEqual(gold_per_hour('tin', 'sluice', 'SLUICE_WASH_TIME'), 20, delta=3)

    def test_rocker_rate(self):
        self.assertAlmostEqual(gold_per_hour('rich', 'rocker', 'ROCKER_WASH_TIME'), 80, delta=5)

    def test_panning_pay_dirt_stays_below_free_panning(self):
        self.assertLess(gold_per_hour('rich', 'pan', 'PAN_PAY_DIRT_TIME'), 30)

    def test_mercury_bonus(self):
        self.assertEqual(define('SLUICE_MERCURY_BONUS'), 1.25)
        self.assertEqual(define('SLUICE_MERCURY_LOSS'), 0.05)
        self.assertIn('river_mercury_spill(get_turf(src), SLUICE_MERCURY_LOSS)', SOURCE)


class Districts(unittest.TestCase):
    def hash16(self, text):
        return int(hashlib.md5(text.encode()).hexdigest()[:4], 16)

    def test_about_a_quarter_rich(self):
        rich = sum(1 for bx in range(40) for by in range(40) if self.hash16(f'{bx},{by},NOMADS_GAIA,placer') % 100 < 25)
        self.assertAlmostEqual(rich / 1600, 0.25, delta=0.04)

    def test_player_cannot_choose(self):
        self.assertIn('pay_dirt_type(pay_dirt_grade(T.x, T.y))', SOURCE)
        self.assertNotIn('input(', SOURCE)


class Wiring(unittest.TestCase):
    def test_included_and_gated(self):
        self.assertIn('#include "code\\modules\\1713\\placer.dm"', DME)
        self.assertIn('"/obj/structure/placer_washer/sluice" = "bronze_working"', NODES)
        self.assertIn('"/obj/structure/placer_washer/rocker" = "ore_dressing"', NODES)
        self.assertIn(',/obj/structure/placer_washer/sluice,', RECIPES)
        self.assertIn(',/obj/structure/placer_washer/rocker,', RECIPES)

    def test_runtime_only_state(self):
        self.assertNotIn('world.time', SOURCE)
        self.assertIn('return key == "washing" || ..()', SOURCE)
        self.assertIn('return key == "digging_pay_dirt" || ..()', SOURCE)

    def test_sprites(self):
        text = dmi_description(DMI)
        for state in set(re.findall(r'(?:icon_state|idle_state|busy_state) = "([a-z_]+)"', SOURCE)):
            self.assertIn(f'state = "{state}"', text, state)


class CommitTimeConditions(unittest.TestCase):
    def test_bank_is_rechecked_after_delay_before_debit_and_spawn(self):
        dig = SOURCE.split('/mob/living/human/verb/dig_pay_dirt()', 1)[1].split('/proc/pay_dirt_wash(', 1)[0]
        after_wait = dig.split('var/done = do_after(', 1)[1]
        self.assertLess(after_wait.index('if (!T.pay_dirt_bank())'), after_wait.index('stock.take(1)'))
        self.assertLess(after_wait.index('stock.take(1)'), after_wait.index('spawn_stack('))
        self.assertRegex(after_wait, r'if \(!T\.pay_dirt_bank\(\)\)\n[^\n]+\n\s+return')

    def test_manual_pan_rechecks_source_before_debit_and_uses_it_for_exposure(self):
        pan = SOURCE.split('/obj/item/kitchen/wood_bowl/proc/pan_pay_dirt', 1)[1].split('/obj/structure/placer_washer', 1)[0]
        before_wait, after_wait = pan.split('do_after(', 1)
        self.assertIn('var/turf/water = T?.panning_water()', before_wait)
        check = after_wait.index('if (get_turf(H) != T || !water || T.panning_water() != water)')
        self.assertLess(check, after_wait.index('P.use(1)'))
        self.assertIn('river_mercury_pan_message(H, water)', after_wait)

    def test_each_bowl_feed_checks_identity_custody_and_reach_after_wait(self):
        for file, method, debit in (('placer', 'pan_pay_dirt', 'P.use(1)'), ('lode', 'pan_crushed_ore', 'C.use(1)')):
            pan = body(file, '/obj/item/kitchen/wood_bowl/proc/' + method + '(')
            before, after = pan.split('do_after(', 1)
            self.assertIn('var/atom/bowl_location = loc', before)
            self.assertIn('panning_tool_available(H, bowl_location)', before)
            self.assertLess(after.index('!panning_tool_available(H, bowl_location)'), after.index(debit))
        sand = body('tatara', '/obj/item/kitchen/wood_bowl/proc/pan_sand(')
        self.assertIn('wash_sand(I, H, H, src, bowl_location, water)', sand)
        wash = body('tatara', '/proc/wash_sand(')
        self.assertIn('atom/bowl_location = null', wash)
        _, after_wait = wash.split('do_after(', 1)
        self.assertLess(after_wait.index('if (bowl_location)'), after_wait.index('S.use('))
        self.assertLess(after_wait.index('!bowl.panning_tool_available(H, bowl_location)'), after_wait.index('S.use('))
        self.assertIn('wash_sand(I, H, src)', body('tatara', '/obj/structure/kanna_channel/attackby('))
        dispatch = body('resource_sifting', '/obj/item/kitchen/wood_bowl/attackby(')
        for method in ('pan_pay_dirt', 'pan_crushed_ore', 'pan_sand'):
            self.assertIn(f'return {method}(I, H)', dispatch)
        guard = body('resource_sifting', '/obj/item/kitchen/wood_bowl/proc/panning_tool_available(')
        for condition in ('!QDELETED(src)', 'loc == original_location', 'H.item_is_in_hands(src)', 'isturf(loc) && Adjacent(H)'):
            self.assertIn(condition, guard)

    def test_panning_water_is_shallow_fresh_and_liquid(self):
        water = body('resource_sifting', '/turf/proc/valid_panning_water(')
        for condition in ('istype(W)', 'W.z == z', 'get_dist(src, W) <= 1', '!W.salty',
                          'W.water_level <= 30', 'W.watertile', 'is_liquid_water(W)'):
            self.assertIn(condition, water)
        finder = body('resource_sifting', '/turf/proc/panning_water()')
        self.assertIn('range(1, src)', finder)
        self.assertIn('if (valid_panning_water(W))', finder)
        helper = (ROOT / 'code/_helpers/water_turfs.dm').read_text(encoding='utf-8')
        liquid = helper.split('/proc/is_liquid_water(turf/T)', 1)[1].split('/proc/', 1)[0]
        self.assertIn('!istype(T, /turf/floor/beach/water/ice)', liquid)

    def test_concentrator_validates_its_pinned_water_without_reselecting(self):
        site = body('automated_sifting', '/obj/structure/drill/sifter/proc/valid_trace_site()')
        self.assertIn('if (!active)\n\t\treturn !!T.panning_water()', site)
        self.assertIn('T.valid_panning_water(trace_water) && trace_water.sifting_identity == trace_water_identity', site)
        self.assertNotIn('water == trace_water', site)


if __name__ == '__main__':
    unittest.main()
