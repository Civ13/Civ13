"""Offline source contracts for butter. Gameplay behaviour is covered by the
native probe: python3 tests/ecology_spawning/run_linux.py . tests/butter/probe.dm 300
"""
from pathlib import Path
import re
import struct
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/butter.dm'


def read(path):
    return path.read_text(encoding='utf-8')


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


class ButterSourceTests(unittest.TestCase):
    def setUp(self):
        self.source = read(SOURCE)

    def test_included(self):
        self.assertIn('#include "code\\modules\\1713\\butter.dm"', read(ROOT / 'civ13.dme'))

    def test_sprites(self):
        states = dmi_states(ROOT / 'icons/obj/food/butter.dmi')
        used = set(re.findall(r'"(butter_churn|butter_churn_closed|butter|butter_salted|butter_rancid|buttered_bread)"', self.source))
        self.assertEqual(len(used), 6)
        self.assertLessEqual(used, states)

    def test_recipe_and_research(self):
        path = '/obj/item/weapon/reagent_containers/glass/butter_churn'
        self.assertIn(f',{path},', read(ROOT / 'config/crafting/material_recipes_global.txt'))
        self.assertIn(f'"{path}" = "pottery_storage"', read(ROOT / 'code/modules/research_tree/research_node.dm'))

    def test_reagents_unique(self):
        for rid in ('butter', 'buttermilk'):
            hits = 0
            for path in (ROOT / 'code').rglob('*.dm'):
                hits += len(re.findall(rf'(?m)^\tid = "{rid}"$', path.read_text(encoding='utf-8', errors='replace')))
            self.assertEqual(hits, 1, rid)

    def test_hooks(self):
        food = read(ROOT / 'code/modules/reagents/reagent_containers/food.dm')
        self.assertIn('crock_food_decay_step(src, loc)', food)
        preserves = read(ROOT / 'code/modules/1713/preserves.dm')
        self.assertIn('crock_pot_work()', preserves)
        self.assertIn('press_butter(W, user)', preserves)
        self.assertIn('"butter" = list("fat" = 1)', read(ROOT / 'code/modules/diet/diet.dm'))


if __name__ == '__main__':
    unittest.main()
