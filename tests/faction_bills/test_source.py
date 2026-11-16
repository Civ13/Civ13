"""Bills of exchange and treasury notes: source contract checks.

    python3 tests/faction_bills/test_source.py
Native probe: python3 tests/ecology_spawning/run_linux.py . tests/faction_bills/probe.dm
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/mob/groups/faction_bills.dm'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


class FactionBillsSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = SOURCE.read_text(encoding='utf-8')

    def test_included_after_justice(self):
        self.assertIn('#include "code\\game\\mob\\groups\\faction_justice.dm"\n#include "code\\game\\mob\\groups\\faction_bills.dm"', read('civ13.dme'))

    def test_rename_and_normalize_hooks(self):
        roster = read('code/game/mob/groups/faction_roster.dm')
        self.assertIn('bill_rename(old_name, new_name)', roster)
        self.assertIn('bill_normalize()', roster)

    def test_bills_paid_only_from_coin_in_the_box(self):
        redeem = self.text.split('/proc/redeem_bill(', 1)[1].split('\n/', 1)[0]
        self.assertIn('pay_out(owed, user)', redeem)
        self.assertNotIn('new /obj/item/stack/money', self.text)
        self.assertNotIn('company_pay_coins', self.text)

    def test_drawing_needs_the_treasury_power_and_paper(self):
        draw = self.text.split('/proc/draw_bills(', 1)[1].split('\n/', 1)[0]
        tail = draw.split('// Everything is checked again after the prompts.', 1)[1]
        self.assertIn('holds_key(user)', tail)
        self.assertIn('bill_blank_supply(user)', tail)
        self.assertIn('/obj/structure/printingpress', draw)

    def test_bills_not_craftable(self):
        recipes = read('config/crafting/material_recipes_global.txt')
        self.assertNotIn('/obj/item/faction_bill', recipes)

    def test_strongbox_menu_offers_drawing(self):
        self.assertIn('draw_bills(user)', read('code/game/mob/groups/faction_treasury.dm'))


if __name__ == '__main__':
    unittest.main()
