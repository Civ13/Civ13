"""Offline street vendor checkout source contracts, not a native UI/game test."""
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
VENDOR = "code/game/objects/structures/vending/npc_vendors.dm"
MONEY = "code/game/objects/items/stacks/money.dm"
DEAL = "code/game/objects/map_metadata/the_art_of_the_deal.dm"
VENDOR_TYPE = "/mob/living/simple_animal/npc_vendor"


class StreetCheckoutTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = (ROOT / VENDOR).read_text(encoding="utf-8")
        money = (ROOT / MONEY).read_text(encoding="utf-8")
        deal = (ROOT / DEAL).read_text(encoding="utf-8")
        dollar = money.split("/obj/item/stack/money/dollar/New()", 1)[1].split(
            "/obj/item/stack/money/dollar100", 1
        )[0]
        age = int(re.search(r"\bordinal_age = (\d+)", deal).group(1))
        assert age >= 4, "The Art of the Deal no longer uses the late-age dollar bill."
        bill_value = re.search(
            r'name = "5 Dollar Bills"\n\s+desc = [^\n]+\n\s+singular_name = [^\n]+'
            r'\n\s+icon_state = [^\n]+\n\s+value = (\d+)',
            dollar,
        )
        cls.bill_units = int(bill_value.group(1))

    def proc(self, path):
        key = f"\n{VENDOR_TYPE}{path}("
        self.assertIn(key, self.source)
        return self.source.split(key, 1)[1].split("\n/", 1)[0]

    def units_per_dollar(self):
        match = re.search(r"^#define STREET_VENDOR_UNITS_PER_DOLLAR (\d+)$", self.source, re.M)
        self.assertIsNotNone(match, "The balance and checkout need one dollar conversion.")
        return int(match.group(1))

    def test_display_uses_the_same_units_as_the_bill_label(self):
        panel = self.proc("/ui_interact")
        self.assertIn("total_money += M.value * M.amount", panel)
        self.assertIn('panel_row("Money", "$[total_money / STREET_VENDOR_UNITS_PER_DOLLAR]")', panel)
        self.assertEqual(30 * self.bill_units / self.units_per_dollar(), 150)

    def test_biker_checkout_matches_each_quote_and_preserves_reputation_rules(self):
        panel = self.proc("/biker/shop_sections")
        checkout = self.proc("/biker/shop_act")
        quote = self.proc("/biker/proc/sale_price_dollars")
        payout = self.proc("/biker/proc/pay_sale")
        self.assertIn(
            "D.amount = sale_price_dollars(sale_kind, reputation[H.civilization])"
            " * STREET_VENDOR_UNITS_PER_DOLLAR / D.value",
            payout,
        )
        for sale, pricing, dollars, bills in (
            ("meth", "buying_price1 + max(faction_reputation, 0)", 50, 10),
            ("coke", "buying_price2 + min(faction_reputation, 15)", 65, 13),
            ("brick", "(buying_price2 + max(faction_reputation, 0)) * 20", 1300, 260),
        ):
            with self.subTest(sale=sale):
                self.assertIn(f'sale_price_dollars("{sale}", reputation[H.civilization])', panel)
                self.assertIn(f'if ("{sale}")\n\t\t\treturn {pricing}', quote)
                self.assertIn(f'pay_sale(H, "{sale}")', checkout)
                self.assertEqual(dollars * self.units_per_dollar() / self.bill_units, bills)

    def test_yates_prices_and_removes_only_currently_available_evidence(self):
        panel = self.proc("/fed/shop_sections")
        checkout = self.proc("/fed/shop_act").split('if (href_list["reduce"])', 1)[1].split(
            'if (href_list["intel"])', 1
        )[0]
        self.assertIn('panel_button("Remove Up to 5", "reduce", 5)', panel)
        self.assertIn('panel_button("Remove Up to 10", "reduce", 10)', panel)
        guards = (
            'if (!(reputation[H.civilization] > 0))',
            'if (!(AD.heat[H.civilization] > 0))',
            "if (!(requested in list(1, 5, 10)))",
        )
        for guard in guards:
            self.assertLess(checkout.index(guard), checkout.index("var/removed ="))
        ordered = (
            "var/removed = min(requested, AD.heat[H.civilization])",
            "var/total_price = removed * heat_price",
            "total_price * STREET_VENDOR_UNITS_PER_DOLLAR / M.value",
            "if (isnull(amount_due) || M.amount < amount_due)",
            "M.amount -= amount_due",
            "AD.heat[H.civilization] -= removed",
            "if (removed >= 10)",
            "else if (removed >= 5)",
        )
        indices = [checkout.index(line) for line in ordered]
        self.assertEqual(indices, sorted(indices))
        for requested, available, starting_cash, expected_cash in (
            (5, 1, 1000, 800),
            (5, 1, 200, 0),
            (5, 1, 195, 195),
            (5, 5, 1000, 0),
        ):
            with self.subTest(requested=requested, available=available, starting_cash=starting_cash):
                amount_due = min(requested, available) * 200 * self.units_per_dollar() / self.bill_units
                bills = starting_cash // 5
                remaining = bills - amount_due if bills >= amount_due else bills
                self.assertEqual(remaining * 5, expected_cash)


if __name__ == "__main__":
    unittest.main()
