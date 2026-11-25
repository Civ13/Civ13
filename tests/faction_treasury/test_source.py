"""Faction treasury strongbox: source contract checks.

    python3 tests/faction_treasury/test_source.py
Native probe: python3 tests/ecology_spawning/run_linux.py . tests/faction_treasury/probe.dm
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/mob/groups/faction_treasury.dm'


class FactionTreasurySource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = SOURCE.read_text(encoding='utf-8')
        cls.market = (ROOT / 'code/modules/1713/marketplace.dm').read_text(encoding='utf-8')
        cls.roster = (ROOT / 'code/game/mob/groups/faction_roster.dm').read_text(encoding='utf-8')

    def test_included_after_faction_hall(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertIn('#include "code\\game\\mob\\groups\\faction_hall.dm"\n#include "code\\game\\mob\\groups\\faction_treasury.dm"', dme)

    def test_recipe_and_research(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        self.assertIn('RECIPE: /material/wood/,strongbox,/obj/structure/closet/crate/faction_strongbox,', recipes)
        research = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        self.assertIn('"/obj/structure/closet/crate/faction_strongbox" = "early_economy"', research)

    def test_rename_and_normalize_hooks(self):
        self.assertIn('treasury_rename(old_name, new_name)', self.roster)
        self.assertIn('treasury_normalize()', self.roster)

    def test_wages_only_from_coin_in_the_box(self):
        collect = self.text.split('/proc/collect_wages(', 1)[1].split('\n/', 1)[0]
        self.assertIn('pay_out(owed, user)', collect)
        self.assertNotIn('new /obj/item/stack/money', collect)
        self.assertNotIn('company_pay_coins', collect)

    def test_wage_selector_and_rename_share_account_identity(self):
        rename = (ROOT / 'code/game/mob/living/carbon/human/name_change.dm').read_text(encoding='utf-8')
        self.assertIn('treasury_refresh_wage_name(account, old_name, new_name)', rename)
        self.assertIn('row[4] == old_name', self.text)
        select = self.text.split('/proc/set_wages(', 1)[1].split('\n/', 1)[0]
        self.assertIn('treasury_wage_choices(online_names, wages)', select)
        self.assertIn('var/account = selection[1]', select)
        self.assertIn('treasury_set_wage(faction, account, name, value)', select)
        self.assertNotIn('treasury_set_wage(faction, account, pick, value)', select)

    def test_powers_rechecked_after_the_prompt(self):
        menu = self.text.split('/proc/treasury_menu(', 1)[1].split('\n/', 1)[0]
        after = menu.split('var/choice = WWinput(', 1)[1]
        self.assertIn('!holds_key(user)', after)
        self.assertIn('!map.is_faction_leader(user, faction)', after)

    def test_box_takes_no_keys_and_cannot_be_unbolted(self):
        attack = self.text.split('/obj/structure/closet/crate/faction_strongbox/attackby(', 1)[1].split('\n/', 1)[0]
        self.assertIn('/obj/item/weapon/key', attack)
        self.assertIn('is_tool(W, TOOL_WRENCH)', attack)

    def test_stock_market_defers_to_the_strongbox(self):
        self.assertEqual(self.market.count('if (map.faction_strongbox(H.civilization))'), 2)
        self.assertIn('if (!box)', self.market)


if __name__ == '__main__':
    unittest.main()
