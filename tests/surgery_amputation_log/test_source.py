"""Surgical amputations must reach the admin attack log.

Gaia, 2026-11-20: players amputated an offline character's four limbs and the
only trace was their chat. The amputate step now logs the surgeon, the victim,
the limb and whether the victim was offline.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
GENERIC = (ROOT / "code/modules/surgery/generic.dm").read_text(encoding="utf-8")


def amputate_end_step():
    block = re.search(r"(?m)^/datum/surgery_step/generic/amputate\n(?:(?:\t[^\n]*|)\n)*", GENERIC)
    assert block, "missing amputate step"
    step = re.search(r"(?m)^\tend_step\(.*\n(?:(?:\t\t[^\n]*|)\n)*", block.group())
    assert step, "missing amputate end_step"
    return step.group()


class AmputationLogTests(unittest.TestCase):
    def test_amputation_is_attack_logged_before_the_limb_drops(self):
        body = amputate_end_step()
        log = body.find("admin_attack_log(user, target,")
        drop = body.find("affected.droplimb(")
        self.assertNotEqual(log, -1, "amputation is not written to the attack log")
        self.assertNotEqual(drop, -1)
        self.assertLess(log, drop, "log before droplimb, while the limb is still named")

    def test_offline_victims_are_marked(self):
        body = amputate_end_step()
        self.assertIn("target.client", body)
        self.assertIn("victim offline", body)


if __name__ == "__main__":
    unittest.main()
