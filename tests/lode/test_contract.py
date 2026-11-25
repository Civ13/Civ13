"""Lode ore and ore dressing: source contract and balance checks.

Gold-bearing quartz and silver-bearing ore drop from mined rock far more often
than free gold or silver, but one crushed load holds only half a lump of metal
and each washing method recovers a share of it. The approved plan's targets:
the buddle about matches mining free gold today, the pan stays below it.

    python3 tests/lode/test_contract.py
"""
import re
import struct
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/1713/lode.dm').read_text(encoding='utf-8')
CRUSH = (ROOT / 'code/modules/1713/stone_crushing.dm').read_text(encoding='utf-8')
MINING = (ROOT / 'code/game/turfs/floor_attackby.dm').read_text(encoding='utf-8')
SEAMS = (ROOT / 'code/modules/1713/mountain_seams.dm').read_text(encoding='utf-8')
# Defines other files use live in code/__defines (tests/dme_order).
SHARED_DEFINES = (ROOT / 'code/__defines/ore_processing.dm').read_text(encoding='utf-8')
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
NODES = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
RECIPES = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
DMI = ROOT / 'icons/obj/lode.dmi'


def define(name):
    match = re.search(rf'#define {name} ([0-9.]+)', SOURCE + SHARED_DEFINES)
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


# Free gold ore per mined rock from the Medieval age: 0.68% chance of 4 lumps.
FREE_GOLD_PER_ROCK = 0.0068 * 4


def gold_per_rock(recovery):
    return define('LODE_GOLD_CHANCE') / 100 * define('LODE_LUMPS') * define('LODE_METAL') * recovery


class Balance(unittest.TestCase):
    def test_buddle_about_matches_free_gold(self):
        ratio = gold_per_rock(define('LODE_BUDDLE_RECOVERY')) / FREE_GOLD_PER_ROCK
        self.assertAlmostEqual(ratio, 1.0, delta=0.15)

    def test_pan_below_buddle(self):
        self.assertLess(define('LODE_PAN_RECOVERY'), define('LODE_BUDDLE_RECOVERY'))
        self.assertLess(gold_per_rock(define('LODE_PAN_RECOVERY')), FREE_GOLD_PER_ROCK)

    def test_every_load_leaves_tailings(self):
        self.assertIn('.[/obj/item/stack/ore/tailings] = 1', SOURCE)

    def test_seams_sum_to_100(self):
        block = SEAMS[SEAMS.index('var/static/list/ores = list('):]
        block = block[:block.index('\n\t)')]
        weights = [int(w) for w in re.findall(r'= list\((\d+),', block)]
        self.assertEqual(sum(weights), 100)
        self.assertIn('/obj/item/stack/ore/gold_quartz = list(3, 1, 2, 4)', SEAMS)


class Wiring(unittest.TestCase):
    def test_included_and_gated(self):
        self.assertIn('#include "code\\modules\\1713\\lode.dm"', DME)
        self.assertLess(DME.index('placer.dm'), DME.index('lode.dm'))
        self.assertIn('"/obj/structure/placer_washer/buddle" = "ore_dressing"', NODES)
        self.assertIn('"/obj/structure/drill/stamp_mill/water" = "ore_dressing"', NODES)
        self.assertIn(',/obj/structure/placer_washer/buddle,', RECIPES)
        self.assertIn(',/obj/structure/drill/stamp_mill/water,', RECIPES)

    def test_mining_rolls_lode(self):
        self.assertIn('\tmining_lode(H) // Independent of the ore rolls; see lode.dm.', MINING)

    def test_crushers_take_lode(self):
        self.assertIn('return is_crushable_stone(I) || lode_crushed_type(I)', CRUSH)
        self.assertIn('if (!is_mill_feed(W) || !istype(H))', CRUSH)
        self.assertIn('lode_crushed_type(S) || roll_stone_crushing', CRUSH)

    def test_manual_stone_crusher_uses_the_existing_millstone_frame(self):
        crusher = CRUSH.split('/obj/structure/stone_crusher\n', 1)[1].split('\n/obj/', 1)[0]
        icon = re.search(r"(?m)^\ticon = '([^']+)'$", crusher)[1]
        state = re.search(r'(?m)^\ticon_state = "(\w+)"$', crusher)[1]
        self.assertEqual((icon, state), ('icons/obj/hopper_machines.dmi', 'millstones'))
        dmi = dmi_description(ROOT / icon)
        self.assertIn('width = 32', dmi)
        self.assertIn('height = 32', dmi)
        self.assertRegex(dmi, rf'state = "{state}"\s+dirs = 1\s+frames = 1')

    def test_no_world_time(self):
        self.assertNotIn('world.time', SOURCE)

    def test_sprites(self):
        text = dmi_description(DMI)
        for state in set(re.findall(r'(?:icon_state|idle_state|busy_state) = "([a-z_]+)"', SOURCE)) | {'water_stamp_mill_on'}:
            self.assertIn(f'state = "{state}"', text, state)


if __name__ == '__main__':
    unittest.main()
