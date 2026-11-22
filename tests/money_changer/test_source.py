"""Money changers and a nation's common money: source contract checks.

    python3 tests/money_changer/test_source.py
Native probe: python3 tests/ecology_spawning/run_linux.py . tests/money_changer/probe.dm
Coordinator votes: python3 -m unittest tests.transfer_storage.test_nations
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/money_changer.dm'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


class MoneyChangerSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = SOURCE.read_text(encoding='utf-8')

    def test_included_after_the_mint(self):
        self.assertIn('#include "code\\modules\\1713\\coin_mint.dm"\n#include "code\\modules\\1713\\money_changer.dm"', read('civ13.dme'))

    def test_craftable_with_trade_and_coinage(self):
        self.assertIn("money changer's table,/obj/structure/closet/crate/money_changer,6,", read('config/crafting/material_recipes_global.txt'))
        self.assertIn('"/obj/structure/closet/crate/money_changer" = "early_economy"', read('code/modules/research_tree/research_node.dm'))

    def test_no_money_from_nowhere(self):
        # Every coin paid comes out of the till: no new coin is made here.
        self.assertNotIn('new /obj/item/stack/money', self.text)
        self.assertNotIn('company_pay_coins', self.text)
        change = self.text.split('/proc/change_coins(', 1)[1]
        self.assertIn('coin_pay_from(stock(out_issuer), owed, user)', change)

    def test_change_rechecks_after_the_prompt(self):
        change = self.text.split('/proc/change_coins(', 1)[1]
        tail = change.split('// The coins, the rate and the till are checked again after the prompt.', 1)[1]
        for needle in ('M.amount != amount', 'rates[issuer] != percent', 'user.Adjacent(src)', 'coin_pay_from(stock(out_issuer), owed, null, TRUE)'):
            self.assertIn(needle, tail)
        self.assertLess(tail.index('coin_pay_from(stock(out_issuer), owed, null, TRUE)'), tail.index('M.forceMove(src)'))

    def test_strongbox_shares_the_counter(self):
        self.assertIn('return coin_pay_from(coin_stacks(), worth, to_user)', read('code/game/mob/groups/faction_treasury.dm'))

    def test_nation_common_money_vote(self):
        nation = read('code/game/mob/groups/nation.dm') + read('code/modules/1713/money_changer.dm')
        self.assertIn('"op" = "currency"', nation)
        self.assertIn('"Vote on a common money"', nation)
        nations = read('tools/transfer_storage/nations.py')
        self.assertIn("'currency'", nations.split('NATION_OPS = ', 1)[1].split('\n', 1)[0])
        self.assertIn('nation_currency', nations)


if __name__ == '__main__':
    unittest.main()
