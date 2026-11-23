"""Source checks for issues 6973 (money printer payouts) and 6975 (sausage casing wait)."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FIAT = ROOT / 'code/modules/1713/fiatcurrency.dm'
PRODUCTION = ROOT / 'code/modules/1713/complex_production.dm'


def block(text, header):
    start = text.index(header)
    nxt = re.search(r'^/\S', text[start + len(header):], re.M)
    return text[start:start + len(header) + nxt.start()] if nxt else text[start:]


class MoneyPrinterPayoutTest(unittest.TestCase):
    def setUp(self):
        self.text = FIAT.read_text(encoding='utf-8')

    def test_dispense_returns_the_value_it_paid(self):
        body = block(self.text, '/obj/structure/money_printer/proc/dispense_real_money(')
        self.assertIn('return real_money_payout_value(payout)', body)
        self.assertNotIn('dispense_value <= 40', body)

    def test_coin_payout_mixes_denominations(self):
        body = block(self.text, '/obj/structure/money_printer/proc/real_money_denominations(')
        self.assertIn('list(/obj/item/stack/money/goldcoin, /obj/item/stack/money/silvercoin, /obj/item/stack/money/coppercoin)', body)

    def test_withdraw_and_redeem_deduct_only_the_paid_value(self):
        ui = block(self.text, '/obj/structure/money_printer/proc/display_ui(')
        self.assertIn('var/paid = dispense_real_money(real_money_inside)', ui)
        self.assertIn('real_money_inside - paid', ui)
        self.assertNotIn('real_money_inside = 0\n', ui)
        redeem = block(self.text, '/obj/structure/money_printer/attackby(')
        self.assertIn('var/paid = dispense_real_money(fiat_value)', redeem)
        self.assertIn('real_money_inside - paid', redeem)
        self.assertNotIn('real_money_inside -= fiat_value', redeem)
        self.assertLess(redeem.index('if (payable <= 0)'), redeem.index('qdel(F)'))


class SausageCasingWaitTest(unittest.TestCase):
    def test_stuffing_waits_on_the_casing_and_rechecks_before_paying(self):
        body = block(PRODUCTION.read_text(encoding='utf-8'), '/obj/item/stack/sausagecasing/attackby(')
        self.assertIn('do_after(user, 10, src)', body)
        guard = body.index('if (QDELETED(src) || QDELETED(W) || W.loc != user || (loc != user && !user.Adjacent(src)))')
        pay = body.index('if (!use(1))')
        output = body.index('new /obj/item/weapon/reagent_containers/food/snacks/sausage(user.loc)')
        self.assertLess(guard, pay)
        self.assertLess(pay, output)
        self.assertNotIn('src.amount -= 1', body)


if __name__ == '__main__':
    unittest.main()
