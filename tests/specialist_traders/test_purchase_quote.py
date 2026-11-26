"""Offline control flow through the specialist trader's payment boundary."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest


ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    "source_adapter", ROOT / "tests/save_movement/source_adapter.py"
)
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
SOURCE = adapter.read("code/game/objects/structures/vending/specialist_traders.dm")
TRADER = "/obj/structure/specialist_trader"


class PurchaseQuoteTests(unittest.TestCase):
    def setUp(self):
        body = adapter.extract(SOURCE, f"{TRADER}/proc/buy")
        # Stop after payment and stock debit. Native constructors and chat
        # rendering are outside the transaction boundary exercised here.
        body = body.split("\n\tvar/path = entry[1]", 1)[0] + "\n\treturn TRUE"
        self.payments = []
        self.trader = SimpleNamespace(
            catalogue={1: object(), "len": 1},
            stock_left={1: 3},
            dealer="dealer",
            accepts=["copper"],
            restock_if_due=lambda: None,
            entry_in_season=lambda entry: True,
            entry_researched=lambda entry, human: True,
            price_for=lambda index, human: self.current_price,
        )
        body = body.replace("T.catalogue.len", 'T.catalogue["len"]')
        body = body.replace("T.stock_left[index]--", "T.stock_left[index] -= 1")
        self.buy = adapter.project(
            "/proc/purchase()\n" + body, "/proc/purchase", "H, index, quoted_price",
            {
                "open_for_trade": lambda human: True,
                "trader": lambda: self.trader,
                "isnum": lambda value: isinstance(value, (int, float)),
                "isnull": lambda value: value is None,
                "to_chat": lambda *args: None,
                "get_turf": lambda human: None,
                "specialist_trader_take_payment": self.pay,
            },
        )
        self.buyer = object()

    def pay(self, human, price, accepted, turf):
        self.payments.append(price)
        return True

    def test_price_increase_makes_no_payment_or_stock_debit(self):
        self.current_price = 75
        purchased = self.buy(self.buyer, 1, 64)
        self.assertEqual(self.payments, [])
        self.assertEqual(self.trader.stock_left[1], 3)
        self.assertFalse(purchased)

    def test_price_drop_also_requires_a_fresh_quote(self):
        self.current_price = 64
        purchased = self.buy(self.buyer, 1, 75)
        self.assertEqual(self.payments, [])
        self.assertEqual(self.trader.stock_left[1], 3)
        self.assertFalse(purchased)

    def test_rendered_current_quote_pays_once(self):
        self.current_price = 64
        self.assertTrue(self.buy(self.buyer, 1, 64))
        self.assertEqual(self.payments, [64])
        self.assertEqual(self.trader.stock_left[1], 2)

    def test_buy_route_carries_the_price_displayed_in_the_stock_row(self):
        render = adapter.extract(SOURCE, f"{TRADER}/ui_interact")
        allowed = adapter.extract(SOURCE, f"{TRADER}/ui_actions")
        action = adapter.extract(SOURCE, f"{TRADER}/ui_act")
        self.assertIn('return list("buy")', allowed)
        self.assertIn('panel_button("Buy", "buy", "[i]:[price]")', render)
        self.assertIn("var/price = T.price_for(i, H)", render)
        self.assertIn("specialist_trader_price_text(price, T.accepts)", render)
        self.assertIn('splittext(params["value"], ":")', action)
        self.assertIn("buy(H, index, quoted_price)", action)


if __name__ == "__main__":
    unittest.main()
