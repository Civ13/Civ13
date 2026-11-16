"""Source checks for tools built into wearable gear (code/modules/1713/worn_tools.dm).

The native probe (tests/worn_tools/probe.dm) covers behaviour; these checks keep
the wiring that the probe cannot see: include order, recipes, research and the
retired hidden shoe knife.
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def body(text, header):
    start = text.index(header)
    match = re.search(r'\n(?=\S)', text[start + len(header):])
    return text[start:start + len(header) + (match.start() if match else len(text))]


class WornToolsSource(unittest.TestCase):
    def setUp(self):
        self.worn = read('code/modules/1713/worn_tools.dm')

    def test_included_after_belt_gear(self):
        dme = read('civ13.dme')
        self.assertLess(dme.index('code\\modules\\1713\\belt_pouches.dm'), dme.index('code\\modules\\1713\\worn_tools.dm'))
        self.assertLess(dme.index('code\\modules\\1713\\lanyards.dm'), dme.index('code\\modules\\1713\\worn_tools.dm'))

    def test_reach_never_unpacks(self):
        holders = body(self.worn, '/mob/living/human/proc/worn_tool_holders()')
        for slot in ('belt', 'wear_id', 'w_uniform', 'wear_suit', 'shoes'):
            self.assertIn(slot, holders)
        for slot in ('back', 'l_store', 'r_store', 's_store'):
            self.assertNotRegex(holders, r'\b%s\b' % slot)

    def test_striker_reaches_a_worn_flint(self):
        striker = body(read('code/modules/1713/flint_mining.dm'), '/obj/item/weapon/flame/lighter/striker/attack_self(')
        self.assertIn('reach_worn_tool(/obj/item/weapon/flint)', striker)

    def test_fitting_slots(self):
        shoes = body(read('code/game/objects/items/clothing/clothing.dm'), '/obj/item/clothing/shoes\n')
        self.assertIn('valid_accessory_slots = list("fitting")', shoes)
        self.assertNotIn('can_hold_knife', shoes)
        self.assertNotIn('draw_knife', read('code/game/objects/items/clothing/clothing.dm'))
        suit = body(read('code/modules/1713/rain_gear.dm'), '/obj/item/clothing/suit\n')
        self.assertIn('"fitting"', suit)

    def test_attach_redraws_the_worn_slot(self):
        attach = body(read('code/game/objects/items/clothing/clothing_accessories.dm'), '/obj/item/clothing/attackby(')
        self.assertIn('update_clothing_icon()', attach)
        self.assertNotIn('update_inv_w_uniform()', attach)

    def test_recipes_and_research(self):
        recipes = read('config/crafting/material_recipes_global.txt')
        research = read('code/modules/research_tree/research_node.dm')
        for name, path, node in (('knife sheath', '/obj/item/clothing/accessory/storage/sheath/knife', 'basic_tools'),
                                 ('boot sheath', '/obj/item/clothing/accessory/storage/sheath/fitting', 'iron_tools'),
                                 ('sleeve sheath', '/obj/item/clothing/accessory/storage/sheath/fitting/sleeve', 'iron_tools')):
            self.assertIn(f'RECIPE: /material/leather/,{name},{path},', recipes)
            self.assertIn(f'"{path}" = "{node}"', research)


if __name__ == '__main__':
    unittest.main()
