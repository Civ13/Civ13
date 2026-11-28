"""Offline source contracts for syrups. Gameplay behaviour is covered by the
native probe: python3 tests/ecology_spawning/run_linux.py . tests/syrups/probe.dm 300
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/syrups.dm'
DRINKS = ROOT / 'code/modules/reagents/Chemistry-Reagents/Chemistry-Reagents-Food-Drinks.dm'
RECIPES = ROOT / 'code/modules/reagents/Chemistry-Recipes.dm'


def read(path):
    return path.read_text(encoding='utf-8')


class SyrupSourceTests(unittest.TestCase):
    def test_included(self):
        self.assertIn('#include "code\\modules\\1713\\syrups.dm"', read(ROOT / 'civ13.dme'))

    def test_reagents_unique(self):
        ids = re.findall(r'^\tid = "([^"]+)"', read(DRINKS), re.M)
        for rid in ('tree_sap', 'maple_syrup', 'sugar_syrup', 'fruit_syrup', 'molasses'):
            self.assertEqual(ids.count(rid), 1, rid)

    def test_hooks(self):
        wild = read(ROOT / 'code/game/objects/structures/wild.dm')
        # Lacquer trees in the silk lands are handled first.
        self.assertLess(wild.index('lacquer_tap_attackby(src, W, user)'), wild.index('sap_tap_attackby(src, W, user)'))
        oven = read(ROOT / 'code/game/objects/structures/kitchen/oven.dm')
        # Syrups boil before the salt step boils the water away.
        self.assertLess(oven.index('I.reagents.boil_syrups()'), oven.index('I.reagents.del_reagent("water")'))
        stamps = read(ROOT / 'code/modules/persistence/world_time_stamps.dm')
        self.assertIn('"sap_tapped_at" = list(/obj/structure/wild/tree/live_tree)', stamps)
        self.assertIn('var/tmp/sap_tapped_at', read(SOURCE))

    def test_uses_in_chemistry_files(self):
        recipes = read(RECIPES)
        for rid in ('rum_molasses', 'lemonade_syrup', 'fruit_syrup', 'fruit_syrup_orange'):
            self.assertIn(f'id = "{rid}"', recipes)
        preserves = read(ROOT / 'code/modules/1713/preserves.dm')
        self.assertIn('"maple_syrup" = 5', preserves)
        # Lemon juice with simple syrup makes lemonade, never fruit syrup.
        self.assertNotIn('"lemonjuice" = 5, "sugar_syrup"', recipes)


if __name__ == '__main__':
    unittest.main()
