"""Exercise supply-stall currency arithmetic and check mutation order offline."""
import importlib.util
from math import floor
from pathlib import Path
import re
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("source_adapter", ROOT / "tests/save_movement/source_adapter.py")
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
SOURCE = adapter.read("code/game/objects/structures/vending/supplier.dm")
TYPE = "/obj/structure/supplier"


def section(*args):
    return adapter.extract(SOURCE, *args)


class SupplyOrderPayoutTest(unittest.TestCase):
    def load_arithmetic(self):
        scale = re.search(r"^#define SUPPLY_COPPERS_PER_SILVER (\d+)$", SOURCE, re.M)
        self.assertIsNotNone(scale)
        self.scale = int(scale.group(1))
        env = {"SUPPLY_COPPERS_PER_SILVER": self.scale, "floor": floor}
        self.whole = adapter.project(SOURCE, TYPE + "/proc/whole_balance_coppers", "amount", env.copy())
        self.exact = adapter.project(SOURCE, TYPE + "/proc/exact_order_coppers", "amount", {
            **env, "whole_balance_coppers": self.whole,
            "isnum": lambda x: isinstance(x, (int, float)),
        })
        settlement = section(TYPE + "/proc/settle_standard_coppers")
        settlement = settlement.replace("pay_standard_coppers(coppers)", "record(coppers)")
        settlement = settlement.replace(
            "moneyin = max(0, moneyin -", "stall.moneyin = max(0, stall.moneyin -"
        )
        self.settle = adapter.project("/proc/projected()\n" + settlement + "\n", "/proc/projected",
                                      "stall, coppers, record", env.copy())

    def test_orders_require_positive_whole_copper_prices(self):
        self.load_arithmetic()
        self.assertEqual(self.scale, 10)
        for rejected in (None, -1, 0, 0.04, 0.09, 0.104, 1.25):
            with self.subTest(rejected=rejected):
                self.assertEqual(self.exact(rejected), 0)
        for amount, coins in ((0.1, 1), (0.3, 3), (0.1 + 0.2, 3), (12.7, 127)):
            with self.subTest(amount=amount):
                self.assertEqual(self.exact(amount), coins)

    def test_legacy_fraction_stays_after_purchase_or_withdrawal(self):
        self.load_arithmetic()
        for balance, debit, expected in (
            (0.04, 0, 0.04), (0.34, 2, 0.14), (12.34, 123, 0.04), (12.3, 123, 0),
        ):
            with self.subTest(balance=balance, debit=debit):
                stall = SimpleNamespace(moneyin=balance)
                payouts = []
                if debit:
                    self.assertGreaterEqual(self.whole(balance), debit)
                    self.settle(stall, debit, payouts.append)
                self.assertEqual(payouts, [debit] if debit else [])
                self.assertAlmostEqual(stall.moneyin, expected)
        self.assertEqual(self.whole(0.04), 0)
        self.assertEqual(self.whole(0.34), 3)

    def test_both_creation_paths_edits_and_currency_switch_share_the_guard(self):
        attack = section(TYPE + "/attackby")
        self.assertEqual(attack.count("payable_order_price(user, choice2)"), 2)
        self.assertEqual(attack.count("quoted_currency != accepted_currency"), 2)
        act = SOURCE.split(TYPE + "/ui_act(", 1)[1]
        edit = act.split('if (href_list["changeprice"])', 1)[1].split('if (href_list["changeamount"])', 1)[0]
        self.assertIn("payable_order_price(H, val)", edit)
        self.assertLess(edit.index("!isnull(checked_price)"), edit.index("orderprice = checked_price"))
        switching = act.split('if (href_list["changecurrency"])', 1)[1].split('if (href_list["removeorder"])', 1)[0]
        self.assertLess(switching.index('new_cur == "standard" && ordertype && !exact_order_coppers(orderprice)'),
                        switching.index("accepted_currency = new_cur"))

    def test_rejected_or_unfunded_order_leaves_sellers_items_alone(self):
        attack = section(TYPE + "/attackby")
        guard = 'var/standard_payment = accepted_currency == "standard"'
        self.assertIn(guard, attack)
        seller = attack.split(guard, 1)[1]
        validate = seller.index("if (!price_coppers)")
        self.assertLess(validate, seller.index("WS.split(buy_qty)"))
        self.assertLess(validate, seller.index("transfer_held_item_to(W, src)"))
        self.assertIn("floor(funds_coppers / price_coppers)", seller)
        self.assertIn("settle_standard_coppers(price_coppers * buy_qty)", seller)
        self.assertIn("settle_standard_coppers(price_coppers)", seller)
        self.assertIn("if (!NST)\n\t\t\t\t\t\treturn", seller)

    def test_standard_withdrawal_never_zeros_unpayable_money(self):
        withdraw = SOURCE.split('if (href_list["removemoney"])', 1)[1]
        before_fiat, _ = withdraw.split("\n\t\telse", 1)
        self.assertIn("coppers = whole_balance_coppers(moneyin)", before_fiat)
        self.assertLess(before_fiat.index("if (!coppers)"), before_fiat.index("settle_standard_coppers(coppers)"))
        self.assertNotIn("moneyin = 0", before_fiat)


if __name__ == "__main__":
    unittest.main()
