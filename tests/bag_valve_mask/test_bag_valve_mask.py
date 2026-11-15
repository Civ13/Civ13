"""Bag-valve mask only ventilates a patient still in reach (#5480)."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MEDICAL = ROOT / "code/game/objects/items/stacks/medical.dm"


def handler():
    text = MEDICAL.read_text()
    start = text.index("/obj/item/bag_valve_mask/attack(")
    end = text.index("\n/obj/", start + 1)
    return text[start:end]


class BagValveMaskTests(unittest.TestCase):
    def test_wait_tracks_the_patient(self):
        body = handler()
        self.assertIn("do_after(user, 80, M)", body)
        self.assertNotIn("do_after(user, 80, src)", body)

    def test_reach_and_mouth_are_rechecked_before_ventilating(self):
        body = handler()
        wait = body.index("do_after(user, 80, M)")
        heal = body.index("M.adjustOxyLoss(-7)")
        reach = body.index("(M != user && !user.Adjacent(M))", wait)
        held = body.index("loc != user", wait)
        mask = body.index("if (M.wear_mask)", wait)
        self.assertLess(max(reach, held, mask), heal)
        # Self-treatment is still allowed: the reach check is skipped for the user.
        self.assertIn("M != user &&", body[wait:heal])


if __name__ == "__main__":
    unittest.main()
