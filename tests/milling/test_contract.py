"""Industrial milling: source contract and balance checks.

Recoveries from the approved plan: plates 50%, shaking table 65%, drum 80%;
the drum loses 0.2u of quicksilver a load, 0.03u with a separator.

    python3 tests/milling/test_contract.py
"""
import re
import struct
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/1713/milling.dm').read_text(encoding='utf-8')
CRUSH = (ROOT / 'code/modules/1713/stone_crushing.dm').read_text(encoding='utf-8')
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
NODES = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
RECIPES = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
DMI = ROOT / 'icons/obj/milling.dmi'

PATHS = (
    '/obj/structure/drill/stamp_mill/water/mill/trommel',
    '/obj/structure/drill/stamp_mill/water/mill/drum',
    '/obj/structure/mercury_separator',
    '/obj/structure/drill/stamp_mill/water/mill/table',
    '/obj/item/amalgamation_plates',
)


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


class Balance(unittest.TestCase):
    def test_recoveries(self):
        self.assertEqual(define('PLATES_RECOVERY'), 0.5)
        self.assertEqual(define('TABLE_RECOVERY'), 0.65)
        self.assertEqual(define('DRUM_RECOVERY'), 0.8)

    def test_separator_cuts_loss(self):
        self.assertEqual(define('DRUM_LOSS'), 0.2)
        self.assertEqual(define('DRUM_SEPARATED_LOSS'), 0.03)

    def test_table_uses_no_mercury(self):
        block = SOURCE[SOURCE.index('/obj/structure/drill/stamp_mill/water/mill/table/stamp_one_stone'):]
        block = block[:block.index('\n///')]
        self.assertNotIn('mercury', block)


class Accounting(unittest.TestCase):
    def test_amalgam_loads_apply_mercury_and_recovery_after_feed_debit(self):
        drum = SOURCE.split('/drum/stamp_one_stone(', 1)[1].split('\n/', 1)[0]
        plates = SOURCE.split('/stamp_mill/stamp_one_stone(', 1)[1].split('\n/', 1)[0]
        self.assertIn(
            '\ttake_feed()\n\tfinish_amalgam_load(T, metal, spend, DRUM_RECOVERY, roll)\n\treturn TRUE',
            drum,
        )
        self.assertIn(
            '\tS.amount--\n'
            '\tif (S.amount <= 0)\n'
            '\t\tqdel(S)\n'
            '\tfinish_amalgam_load(T, metal, PLATES_LOSS, PLATES_RECOVERY, roll)\n'
            '\treturn TRUE',
            plates,
        )

        finish_load = SOURCE.split('/proc/finish_amalgam_load(', 1)[1].split('\n\n', 1)[0]
        self.assertIn(
            '\treagents.remove_reagent("mercury", spend)\n'
            '\triver_mercury_spill(T, spend)\n'
            '\tif (isnull(roll))\n'
            '\t\troll = rand(1, 1000) / 10\n'
            '\tif (roll <= LODE_METAL * recovery * 100)\n'
            '\t\treagents.remove_reagent("mercury", AMALGAM_WET_MERCURY)\n'
            '\t\tspawn_stack(amalgam_type_for(metal), T, 1)',
            finish_load,
        )

    def test_mills_admit_water_then_tailings_then_spend(self):
        for variant in ("drum", "table"):
            with self.subTest(variant=variant):
                body = SOURCE.split(f"/{variant}/stamp_one_stone(", 1)[1].split("\n/", 1)[0]
                steps = (
                    "if (!mill_water(TRUE))",
                    "if (!T.deposit_small_resource(",
                    "if (!mill_water())",
                    "take_feed()",
                )
                for step in steps:
                    self.assertIn(step, body)
                self.assertEqual(sorted(map(body.index, steps)), list(map(body.index, steps)))
        self.assertIn("check_only ? station_has_water() : station_take_water(null)", SOURCE)

    def test_trommel_checks_sluice_discharge_before_consuming_inputs(self):
        body = SOURCE.split("/trommel/stamp_one_stone(", 1)[1].split("\n/", 1)[0]
        steps = (
            "var/turf/T = get_turf(S)",
            "for (var/obj/item/stack/stack in T)",
            "if (++stack_count >= output_stack_limit)",
            'mill_stop_reason = "clear the sluice output tile and restart it"',
            "mill_water()",
            "take_feed()",
            "pay_dirt_wash(",
            "S.spend_mercury()",
            "pay_dirt_output(found, T)",
        )
        for step in steps:
            self.assertIn(step, body)
        self.assertEqual(sorted(map(body.index, steps)), list(map(body.index, steps)))


class Wiring(unittest.TestCase):
    def test_node_registered_after_its_prerequisites(self):
        self.assertIn('"industrial_milling", "Industrial Milling", "Industrial", 235, 3, RESEARCH_MODE_ANALYSIS, list("amalgamation","steam_power"), 4)', NODES)

    def test_included_and_gated(self):
        self.assertIn('#include "code\\modules\\1713\\milling.dm"', DME)
        self.assertLess(DME.index('amalgam.dm'), DME.index('milling.dm'))
        for path in PATHS:
            self.assertIn(f'"{path}" = "industrial_milling"', NODES)
            self.assertIn(f',{path},', RECIPES)

    def test_hopper_hook(self):
        self.assertIn('/obj/structure/drill/stamp_mill/proc/hopper_accepts(obj/item/I)', CRUSH)
        self.assertNotIn('is_mill_feed(S) && S.amount', CRUSH)
        self.assertIn('[mill_stop_reason || "clear its output tile and restart it"]', CRUSH)

    def test_no_world_time(self):
        self.assertNotIn('world.time', SOURCE)

    def test_sprites(self):
        text = dmi_description(DMI)
        states = set(re.findall(r'(?:icon_state|idle_state|active_state|plates_overlay) = "([a-z_]+)"', SOURCE))
        self.assertGreaterEqual(len(states), 9)
        for state in states:
            self.assertIn(f'state = "{state}"', text, state)


if __name__ == '__main__':
    unittest.main()
