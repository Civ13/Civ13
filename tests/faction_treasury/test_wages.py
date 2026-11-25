"""Checks for faction wage carry and caps; this is not a native gameplay probe."""
import os
from pathlib import Path
import re
import unittest


DAY = 864000
SOURCE = Path(os.environ.get("CIV13_TREASURY_SOURCE", Path(__file__).resolve().parents[2] /
              "code/game/mob/groups/faction_treasury.dm"))


def project(rate_tenths, balance_tenths, carry, elapsed):
    """Integer reference, not a substitute for compiling or running the DM proc."""
    room = rate_tenths * 7 - balance_tenths
    if elapsed <= 0 or room <= 0:
        return balance_tenths, carry
    earned, remainder = divmod(rate_tenths * elapsed + carry, DAY)
    return (balance_tenths + room, 0) if earned >= room else (balance_tenths + earned, remainder)


class FactionWagesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = SOURCE.read_text(encoding="utf-8")
        cls.accrue = cls.source.split("/proc/treasury_wage_accrue(", 1)[1].split("\n/", 1)[0]

    def test_repeated_checks_and_single_check_pay_exactly_the_same(self):
        repeated = 0, 0
        for _ in range(24):
            repeated = project(100, *repeated, 3600)
        self.assertEqual(repeated, project(100, 0, 0, 24 * 3600))
        self.assertEqual(repeated, (10, 0))
        self.assertIn("if (row.len == 4)", self.accrue)
        self.assertIn("+ row[5]", self.accrue)
        self.assertIn("row[5] = carry - extra_tenths * TREASURY_DAY", self.accrue)

    def test_rate_cut_preserves_old_earnings_but_does_not_add_at_cap(self):
        earned = project(100, 0, 0, 3 * DAY)
        self.assertEqual(earned, (300, 0))
        self.assertEqual(project(10, *earned, DAY), earned)
        self.assertEqual(project(10, 60, 0, DAY), (70, 0))
        self.assertEqual(project(10, 70, 240, DAY), (70, 240))
        self.assertIn("rate_tenths * TREASURY_WAGE_CAP_DAYS - owed_tenths", self.accrue)
        self.assertLess(self.accrue.index("room <= 0"), self.accrue.index("row[2] ="))

    def test_durable_legacy_conversion_payout_carry_and_read_only_ledger(self):
        self.assertRegex(self.source, r"if \(row.len == 4\)\n\s+row \+= 0 // legacy balance")
        self.assertIn('treasury_wage_accrue(row.Copy(), now)', self.source)
        payout = self.source.split("/proc/collect_wages(", 1)[1].split("\n/", 1)[0]
        self.assertIsNone(re.search(r"row\[5\]\s*=", payout))
        self.assertIn("row[5] <= 0", payout)


if __name__ == "__main__":
    unittest.main()
