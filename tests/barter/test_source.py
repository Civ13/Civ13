"""Barter: source contract checks.

    python3 tests/barter/test_source.py
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/barter.dm'


class BarterSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = SOURCE.read_text(encoding='utf-8')

    def test_included(self):
        self.assertIn('#include "code\\modules\\1713\\barter.dm"', (ROOT / 'civ13.dme').read_text(encoding='utf-8'))

    def test_trade_state_is_runtime_only(self):
        self.assertIn('return key == "traders" || key == "offers" || key == "agreed" || ..()', self.text)
        self.assertIn('/obj/structure/barter_mat/after_load()', self.text)

    def test_recipes_and_research(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        for line in ('RECIPE: /material/stone/,stone beads,/obj/item/stack/barter_beads/stone,',
                'RECIPE: /material/bone/,bone beads,/obj/item/stack/barter_beads/bone,',
                'RECIPE: /material/leather/,barter mat,/obj/structure/barter_mat,'):
            self.assertIn(line, recipes)
        research = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        self.assertIn('"/obj/structure/barter_mat" = "basic_tools",', research)

    def test_sprites_exist(self):
        from PIL import Image
        meta = Image.open(ROOT / 'icons/obj/barter.dmi').info.get('Description', '')
        for state in ('beads_stone', 'beads_bone', 'barter_mat', 'barter_mat_goods'):
            self.assertIn('state = "%s"' % state, meta)

    def test_trades_are_logged(self):
        self.assertIn('log_game("Barter at', self.text)

    def test_no_forbidden_patterns(self):
        self.assertIsNone(re.search(r'(?<![a-z_])(spawn|input)\(', self.text))
        self.assertNotIn(' in world', self.text)


if __name__ == '__main__':
    unittest.main()
