"""Offline checks for gemstones and belt pouches (docs/gemstones.md)."""
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/art_ports'))
from pocket_stronghold_food import state_names  # noqa: E402

FILES = [ROOT / 'code/modules/1713/gemstones.dm', ROOT / 'code/modules/1713/belt_pouches.dm']


def blocks(text):
    return re.split(r'\n(?=/)', text)


class GemstoneTest(unittest.TestCase):
    def test_every_icon_state_exists(self):
        checked = 0
        for path in FILES:
            for block in blocks(path.read_text(encoding='utf-8')):
                state = re.search(r'\ticon_state = "([^"]+)"', block)
                if not state:
                    continue
                icon = re.search(r"\ticon = '([^']+)'", block)
                if not icon:
                    parent = '/'.join(block.split('\n')[0].split('/')[:-1])
                    icon = re.search(rf"^{re.escape(parent)}\n(?:\t.*\n)*?\ticon = '([^']+)'", path.read_text(encoding='utf-8'), re.M)
                self.assertTrue(icon, block.split('\n')[0])
                self.assertIn(state[1], state_names(ROOT / icon[1]), block.split('\n')[0])
                checked += 1
        self.assertEqual(checked, 18)  # 6 rough, 7 cut, 2 pouches, 2 belts, tool loop

    def test_worn_pouch_states_have_four_directions(self):
        text = __import__('PIL.Image', fromlist=['Image']).open(ROOT / 'icons/mob/belt_pouches.dmi').info['Description']
        for state in ('leather_pouch', 'cloth_pouch', 'leather_pouch_left', 'cloth_pouch_left', 'pouch_belt', 'baldric'):
            self.assertRegex(text, rf'state = "{state}"\n\tdirs = 4')

    def test_gem_roll_is_independent_of_ore_table(self):
        mining = (ROOT / 'code/game/turfs/floor_attackby.dm').read_text(encoding='utf-8')
        self.assertIn('mining_gem_pocket(H)', mining)
        self.assertIn('#include "code\\modules\\1713\\gemstones.dm"', (ROOT / 'civ13.dme').read_text(encoding='utf-8'))

    def test_pouch_recipes_are_mapped_to_research(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        nodes = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        for path, node in (('/obj/item/clothing/accessory/storage/belt_pouch', 'basic_tools'),
                           ('/obj/item/clothing/accessory/storage/belt_pouch/cloth', 'weaving'),
                           ('/obj/item/clothing/pouch_belt', 'basic_tools'),
                           ('/obj/item/clothing/accessory/storage/baldric', 'basic_tools'),
                           ('/obj/item/clothing/accessory/storage/tool_loop', 'basic_tools')):
            self.assertRegex(recipes, rf'RECIPE: [^,]+,[^,]+,{re.escape(path)},')
            self.assertIn(f'"{path}" = "{node}"', nodes)

    def test_belt_draws_its_pouches(self):
        icons = (ROOT / 'code/game/mob/living/carbon/human/update_icons.dm').read_text(encoding='utf-8')
        belt = icons[icons.index('/mob/living/human/update_inv_belt('):]
        belt = belt[:belt.index('\n/mob/')]
        self.assertIn('for (var/obj/item/clothing/accessory/A in cbelt.accessories)', belt)
        pouches = (ROOT / 'code/modules/1713/belt_pouches.dm').read_text(encoding='utf-8')
        self.assertIn('overlay_state = others ? "[icon_state]_left" : null', pouches)

    def test_items_read_as_ordinary(self):
        # Player-facing text stays plain: names and descriptions only describe
        # ordinary pouches and stones.
        for path in FILES:
            text = path.read_text(encoding='utf-8').lower()
            for word in ('magic', 'arcane', 'spell', 'focus', 'foci', 'mystic', 'enchant', 'rune'):
                self.assertNotIn(word, text, f'{path.name}: {word}')


if __name__ == '__main__':
    unittest.main()
