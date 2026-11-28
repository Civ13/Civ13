"""Offline source contracts for coffee. Gameplay behaviour is covered by the
native probe: python3 tests/ecology_spawning/run_linux.py . tests/coffee/probe.dm 300
"""
from pathlib import Path
import re
import struct
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/coffee.dm'


def dmi_states(path):
    data = path.read_bytes()
    pos = 8
    while pos < len(data):
        length, kind = struct.unpack('>I4s', data[pos:pos + 8])
        chunk = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b'zTXt' and chunk.startswith(b'Description\0'):
            text = zlib.decompress(chunk[len(b'Description\0') + 1:]).decode('utf-8')
            return set(re.findall(r'state = "([^"]*)"', text))
    return set()


class CoffeeSourceTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')

    def test_included(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertIn('#include "code\\modules\\1713\\coffee.dm"', dme)

    def test_sprites(self):
        states = dmi_states(ROOT / 'icons/obj/food/food.dmi')
        self.assertLessEqual({'green_coffee', 'roasted_coffee'}, states)

    def test_chain_hooks(self):
        oven = (ROOT / 'code/game/objects/structures/kitchen/oven.dm').read_text(encoding='utf-8')
        self.assertIn('snacks/grown/coffee))\n\t\t\tcontents += new /obj/item/weapon/reagent_containers/food/snacks/roasted_coffee(src)', oven)
        # Brewing runs before the salt step boils the water away.
        self.assertLess(oven.index('I.reagents.brew_coffee()'), oven.index('I.reagents.del_reagent("water")'))
        registry = (ROOT / 'code/modules/1713/processing_recipes.dm').read_text(encoding='utf-8')
        self.assertIn('snacks/roasted_coffee, "coffee_grounds", 3)', registry)
        mug = (ROOT / 'code/game/objects/structures/kitchen/stone_boiling.dm').read_text(encoding='utf-8')
        self.assertIn('holder.brew_coffee()', mug)

    def test_no_shortcuts(self):
        grown = (ROOT / 'code/modules/reagents/reagent_containers/food/grown.dm').read_text(encoding='utf-8')
        green = grown.split('/obj/item/weapon/reagent_containers/food/snacks/grown/coffee\n', 1)[1].split('\n/', 1)[0]
        self.assertNotIn('add_reagent', green)
        glass = (ROOT / 'code/modules/reagents/reagent_containers/glass.dm').read_text(encoding='utf-8')
        branch = glass.split('snacks/grown/coffee))', 1)[1].split('else if', 1)[0]
        self.assertNotIn('add_reagent', branch)
        drinks = (ROOT / 'code/modules/reagents/Chemistry-Reagents/Chemistry-Reagents-Food-Drinks.dm').read_text(encoding='utf-8')
        coffee = drinks.split('/datum/reagent/drink/coffee/affect_ingest(', 1)[1].split('\n/datum/', 1)[0]
        self.assertNotIn('CE_SPEEDBOOST', coffee)

    def test_reagent_unique(self):
        hits = 0
        for path in (ROOT / 'code').rglob('*.dm'):
            hits += len(re.findall(r'(?m)^\tid = "coffee_grounds"$', path.read_text(encoding='utf-8', errors='replace')))
        self.assertEqual(hits, 1)


if __name__ == '__main__':
    unittest.main()
