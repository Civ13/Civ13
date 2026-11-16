"""Tamahagane and the tatara: source contract checks.

Iron sand is panned or sifted from beach sand from the Classical age, Asia
yields more, and the bloomery (not the blast furnace) smelts it two to one.

    python3 tests/tatara/test_contract.py
"""
import json
import re
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/1713/tatara.dm').read_text(encoding='utf-8')
SIFTING = (ROOT / 'code/modules/1713/resource_sifting.dm').read_text(encoding='utf-8')
ASIA = (ROOT / 'code/game/objects/map_metadata/nomads/nomads_asia.dm').read_text(encoding='utf-8')
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
DMI = ROOT / 'icons/obj/tatara.dmi'
ATLAS = json.loads((ROOT / 'scripts/atlas/resource-sources.json').read_text(encoding='utf-8'))
SAND = '/obj/item/stack/ore/iron_sand'


def define(name):
    return int(re.search(r'#define %s (\d+)' % name, SOURCE).group(1))


def proc_body(text, header):
    start = text.index(header)
    end = text.find('\n/', start + 1)
    return text[start:end if end != -1 else len(text)]


def dmi_states():
    data = DMI.read_bytes()
    at = data.index(b'zTXtDescription\x00\x00') + len(b'zTXtDescription\x00\x00')
    text = zlib.decompressobj().decompress(data[at:]).decode()
    return set(re.findall(r'state = "([^"]+)"', text))


class IronSand(unittest.TestCase):
    def test_included_after_the_furnaces(self):
        self.assertEqual(DME.count('code\\modules\\1713\\tatara.dm'), 1)
        self.assertLess(DME.index('blacksmithing\\refining.dm'), DME.index('code\\modules\\1713\\tatara.dm'))

    def test_item_sprites(self):
        states = dmi_states()
        for suffix in ('', '_2', '_3', '_4'):
            self.assertIn('iron_sand' + suffix, states)

    def test_panning_and_beach_sifting_from_age_one(self):
        pan = proc_body(SIFTING, '/mob/living/human/proc/panning_choices(')
        self.assertIn('map.ordinal_age >= 1', pan)
        self.assertIn('choices["Iron sand"] = ' + SAND, pan)
        sift = proc_body(SIFTING, '/mob/living/human/proc/sifting_choices(')
        beach = sift[sift.index('map.ordinal_age >= 1'):sift.index('map.ordinal_age >= 2')]
        self.assertIn('istype(T, /turf/floor/beach/sand)', beach)
        self.assertIn('choices["Iron sand"] = ' + SAND, beach)
        self.assertEqual(SIFTING.count('panning ? panning_choices() : sifting_choices(T)'), 2)

    def test_yields_fit_one_deposit(self):
        pan, sift, bonus = define('IRON_SAND_PAN_UNITS'), define('IRON_SAND_SIFT_UNITS'), define('IRON_SAND_RICH_BONUS')
        self.assertEqual((pan, sift, bonus), (3, 2, 2))
        self.assertLessEqual(pan + bonus, 5)  # deposit_small_resource() refuses more than 5
        self.assertIn('iron_sand_yield(panning) : 1', SIFTING)
        self.assertIn('iron_sand_rich = TRUE', ASIA)

    def test_bloomery_only_two_to_one(self):
        self.assertEqual(define('IRON_SAND_PER_SPONGE'), 2)
        accept = proc_body(SOURCE, '/obj/structure/furnace/accept_manual_stack(')
        self.assertIn('type != /obj/structure/furnace', accept)
        self.assertIn('return ..()', accept)
        smelt = proc_body(SOURCE, '/obj/structure/furnace/process(')
        self.assertLess(smelt.index('iron_sand -= sponge * IRON_SAND_PER_SPONGE'), smelt.index('spawn_stack'))
        self.assertIn('return ..()', smelt)
        self.assertIn('spawn_stack(' + SAND, proc_body(SOURCE, '/obj/structure/furnace/empty('))

    def test_atlas_routes(self):
        routes = {r['name']: r for r in ATLAS['mechanisms']}
        for name in ('Pan iron sand', 'Sift iron sand from beach sand', 'Smelt iron sand in a bloomery'):
            self.assertIn(name, routes)
        self.assertIn(SAND, routes['Pan iron sand']['outputs'])
        self.assertEqual(routes['Smelt iron sand in a bloomery']['inputs'], [SAND])


if __name__ == '__main__':
    unittest.main()
