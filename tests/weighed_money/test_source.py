"""Weighed money and the trading balance: source contract checks.

    python3 tests/weighed_money/test_source.py
Native probe: python3 tests/ecology_spawning/run_linux.py . tests/weighed_money/probe.dm
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/weighed_money.dm'


class WeighedMoneySource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = SOURCE.read_text(encoding='utf-8')

    def test_included_after_barter(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertIn('#include "code\\modules\\1713\\barter.dm"\n#include "code\\modules\\1713\\weighed_money.dm"', dme)

    def test_coin_worth_matches_research_scale(self):
        # Research benches value coins copper 0.1 / silver 1 / gold 4.
        self.assertIn('"copper" = 0.1,', self.text)
        self.assertIn('"silver" = 1,', self.text)
        self.assertIn('"gold" = 4)', self.text)
        self.assertIn('C.amount * C.value', self.text)

    def test_mat_override_calls_parent(self):
        block = self.text.split('/obj/structure/barter_mat/attackby(obj/item/I, mob/user)')[1]
        self.assertIn('return ..()', block)

    def test_balance_reuses_existing_art(self):
        self.assertIn("icon = 'icons/obj/gem_science.dmi'", self.text)
        self.assertIn('icon_state = "gem_scale"', self.text)

    def test_recipe_and_research(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        self.assertIn('RECIPE: /material/wood/,trading balance,/obj/item/weighing_balance,', recipes)
        research = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        self.assertIn('"/obj/item/weighing_balance" = "basic_tools",', research)

    def test_never_creates_money(self):
        self.assertNotIn('new /obj/item/stack/money', self.text)
        self.assertNotIn('new/obj/item/stack/money', self.text)

    def test_no_forbidden_patterns(self):
        self.assertIsNone(re.search(r'(?<![A-Za-z_])(spawn|input)\(', self.text))
        self.assertNotIn(' in world', self.text)


if __name__ == '__main__':
    unittest.main()
