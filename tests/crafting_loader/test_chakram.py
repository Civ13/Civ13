"""The thrower uses the normal material weapon and crafting paths, not a new mode."""
from pathlib import Path
import re
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_basic_clothing import factionless_recipes, read, research  # noqa: E402
from test_loader import run_file  # noqa: E402
from test_radio_headset import dmi_states  # noqa: E402

GLOBAL = 'material_recipes_global.txt'
CHAKRAM = '/obj/item/weapon/material/thrown/chakram'


class ChakramTests(unittest.TestCase):
    def test_global_recipe_passes_the_production_loader(self):
        loaded = run_file(GLOBAL, read('config/crafting/' + GLOBAL))
        rows = [row for row in loaded.rows['global'] if row[3] == CHAKRAM]
        self.assertEqual(len(rows), 1)
        row = rows[0]
        self.assertEqual([row[1], row[2], row[4], row[7], row[8], row[10], row[13]],
                         ['/material/iron/', 'chakram', '3', '1', 'weapons', '39', 'iron'])

    def test_iron_smithing_unlocks_it_without_expiring_the_recipe(self):
        nodes, requirements = research()
        self.assertEqual(requirements[CHAKRAM], 'iron_smithing')
        first, tree = nodes['iron_smithing']
        self.assertEqual(tree, 'Main')
        self.assertNotIn(CHAKRAM, factionless_recipes(first - 1, nodes, requirements))
        self.assertIn(CHAKRAM, factionless_recipes(first, nodes, requirements))
        self.assertIn(CHAKRAM, factionless_recipes(8, nodes, requirements))

    def test_thrown_item_uses_an_existing_icon_and_normal_throwing(self):
        source = read('code/game/objects/items/weapons/material/thrown.dm')
        self.assertIn(CHAKRAM + '\n', source)
        definition = source.split(CHAKRAM + '\n', 1)[1].split('\n\n', 1)[0]
        icon = re.search(r"\bicon = '([^']+)'", definition)[1]
        state = re.search(r'\bicon_state = "([^"]+)"', definition)[1]
        self.assertIn(state, dmi_states(icon))
        for hand in ('l', 'r'):
            self.assertIn(f"slot_{hand}_hand_str = '{icon}'", definition)
        self.assertIn('sharp = TRUE', definition)
        self.assertIn('edge = TRUE', definition)
        self.assertIn('default_material = "iron"', definition)
        self.assertNotRegex(source, re.escape(CHAKRAM) + r'/\w')
        self.assertLess(float(re.search(r'(?m)^\tforce_divisor = ([\d.]+)', definition)[1]),
                        float(re.search(r'(?m)^\tthrown_force_divisor = ([\d.]+)', definition)[1]))
