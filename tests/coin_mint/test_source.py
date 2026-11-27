"""Faction mints and marked coins: source contract checks.

    python3 tests/coin_mint/test_source.py
Native probe: python3 tests/ecology_spawning/run_linux.py . tests/coin_mint/probe.dm
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/coin_mint.dm'
RECIPES = ROOT / 'config/crafting/material_recipes_global.txt'


class CoinMintSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = SOURCE.read_text(encoding='utf-8')
        cls.recipes = RECIPES.read_text(encoding='utf-8')

    def test_included_after_weighed_money(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertIn('#include "code\\modules\\1713\\weighed_money.dm"\n#include "code\\modules\\1713\\coin_mint.dm"', dme)

    def test_no_loose_coin_crafting_in_the_global_list(self):
        for coin in ('goldcoin', 'silvercoin', 'coppercoin'):
            self.assertNotIn('/obj/item/stack/money/%s,' % coin, self.recipes)

    def test_die_recipe_and_research(self):
        self.assertIn('RECIPE: /material/bronze/,coin die,/obj/item/coin_die,', self.recipes)
        research = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        self.assertIn('"/obj/item/coin_die" = "early_economy",', research)

    def test_marking_and_predicate_use_the_coin_metal_classification(self):
        predicate = self.text.split('/proc/is_metal_coin()\n', 1)[1].split('\n/', 1)[0]
        classification = self.text.split('/proc/coin_metal()\n', 1)[1].split('\n/', 1)[0]
        marking = self.text.split('/proc/apply_coin_mark(new_issuer, new_fineness)\n', 1)[1].split('\n/', 1)[0]

        predicate_call = re.escape('!isnull(coin_metal())')
        self.assertRegex(predicate.strip(), rf'^return[ \t]+(?:{predicate_call}|\([ \t]*{predicate_call}[ \t]*\))$')
        self.assertEqual(
            re.findall(r'istype\(src, /obj/item/stack/money/(\w+)coin\)\)\n\t\treturn "(\w+)"', classification),
            [('copper', 'copper'), ('silver', 'silver'), ('gold', 'gold')],
        )
        self.assertTrue(classification.rstrip().endswith('\n\treturn null'))
        self.assertTrue(marking.startswith('\tvar/metal = coin_metal()\n\tif (isnull(metal))\n\t\treturn\n'))
        self.assertEqual(marking.count('coin_metal()'), 1)
        self.assertIn('fineness = metal == "copper" ? 1 : mint_fineness_clean(new_fineness)', marking)

    def test_merges_are_guarded_and_call_parent(self):
        for header in ('/obj/item/stack/merge(obj/item/stack/S)', '/obj/item/stack/transfer_to(obj/item/stack/S, var/_amount=null)'):
            block = self.text.split(header)[1].split('\n/')[0]
            self.assertIn('stack_compatible(S)', block)
            self.assertIn('return ..()', block)

    def test_smelter_melts_by_content(self):
        factory = (ROOT / 'code/game/objects/structures/factory/factory.dm').read_text(encoding='utf-8')
        self.assertIn('silver += SC.amount * SC.fineness / 10', factory)
        self.assertIn('gold += GC.amount * GC.fineness / 10', factory)
        self.assertIn('copper += I.amount/10', factory)
        self.assertNotIn('copper += I.amount/5', factory)

    def test_issuer_follows_renames(self):
        roster = (ROOT / 'code/game/mob/groups/faction_roster.dm').read_text(encoding='utf-8')
        self.assertIn('coin_issuer_rename(old_name, new_name)', roster)

    def test_striking_is_logged_and_rechecks_after_wait(self):
        self.assertIn('log_game("[key_name(user)] struck', self.text)
        self.assertIn('if (QDELETED(S) || S.amount < sheets', self.text)

    def test_no_forbidden_patterns(self):
        self.assertIsNone(re.search(r'(?<![A-Za-z_])(spawn|input)\(', self.text))
        self.assertNotIn(' in world', self.text)


if __name__ == '__main__':
    unittest.main()
