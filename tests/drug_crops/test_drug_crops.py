"""Offline source contracts for drug crops: real climates, wild sources and
cannabis as its own seed. Gameplay is covered by the native probe:
python3 tests/ecology_spawning/run_linux.py . tests/drug_crops/probe.dm 300
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def block(text, path):
    start = text.index('\n' + path + '\n') + 1
    end = text.find('\n/', start)
    return text[start:end if end != -1 else len(text)]


def biomes(text, path):
    body = block(text, path)
    match = re.search(r'biomes = list\(([^)]*)\)', body)
    return set(re.findall(r'"([^"]+)"', match.group(1)))


class DrugCropSourceTests(unittest.TestCase):
    def setUp(self):
        self.farming = (ROOT / 'code/game/objects/farming.dm').read_text(encoding='utf-8')
        self.foraging = (ROOT / 'code/modules/ecology/foraging.dm').read_text(encoding='utf-8')
        self.regrowth = (ROOT / 'code/modules/ecology/flora_regrowth.dm').read_text(encoding='utf-8')
        self.sheets = (ROOT / 'code/modules/materials/material_sheets.dm').read_text(encoding='utf-8')
        self.recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')

    def test_real_climates(self):
        expected = {
            'poppy': {'temperate', 'sea', 'semiarid', 'desert', 'savanna'},
            'tobacco': {'temperate', 'sea', 'semiarid', 'savanna', 'jungle'},
            'hemp': {'temperate', 'taiga', 'sea', 'semiarid', 'savanna'},
            'cannabis': {'temperate', 'sea', 'semiarid', 'savanna'},
            'coca': {'jungle', 'savanna'},
        }
        for crop, climates in expected.items():
            seed = biomes(self.farming, f'/obj/item/stack/farming/seeds/{crop}')
            plant = biomes(self.farming, f'/obj/structure/farming/plant/{crop}')
            self.assertEqual(seed, climates, crop)
            self.assertEqual(plant, climates, crop)

    def test_wild_sources(self):
        table = self.foraging.split('/proc/foraging_seed_table()', 1)[1].split('\n)', 1)[0]
        pool = self.regrowth.split('/proc/wild_plant_pool()', 1)[1].split('\n\t)', 1)[0]
        for crop in ('hemp', 'cannabis', 'tobacco', 'poppy', 'coca'):
            self.assertIn(f'/obj/item/stack/farming/seeds/{crop} = list(', table)
            self.assertIn(f'/obj/structure/farming/plant/{crop} = 1,', pool)
        # Foraged climates are a subset of where each crop actually grows.
        for crop in ('hemp', 'cannabis', 'tobacco', 'poppy', 'coca'):
            line = re.search(rf'seeds/{crop} = list\(([^)]*)\)', table).group(1)
            found = set(re.findall(r'"([^"]+)"', line))
            self.assertLessEqual(found, biomes(self.farming, f'/obj/structure/farming/plant/{crop}'), crop)

    def test_cannabis_split_from_hemp(self):
        plant = block(self.farming, '/obj/structure/farming/plant/cannabis')
        self.assertIn('stack = "material/cannabis_fresh"', plant)
        fresh = block(self.sheets, '/obj/item/stack/material/cannabis_fresh')
        self.assertIn('dried_type = /obj/item/stack/material/cannabis', fresh)
        self.assertNotIn('is_contraband', block(self.sheets, '/obj/item/stack/material/hemp'))
        self.assertIn('RECIPE: /material/cannabis/,joint,', self.recipes)
        self.assertNotIn('RECIPE: /material/hemp/,joint,', self.recipes)


if __name__ == '__main__':
    unittest.main()
