"""Pulled punches stay nonlethal (#5323, #5324)."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ATTACKHAND = ROOT / "code/game/mob/living/carbon/human/human_attackhand.dm"
UNARMED = ROOT / "code/game/mob/living/carbon/human/unarmed_attack.dm"


def proc_body(text, header):
    start = text.index(header)
    rest = text[start + len(header):]
    match = re.search(r"^/", rest, re.M)
    return rest[: match.start()] if match else rest


class PulledPunchTests(unittest.TestCase):
    def test_teeth_only_after_landed_full_strike(self):
        body = proc_body(ATTACKHAND.read_text(), "/mob/living/human/attack_hand(")
        teeth = body.index("knock_out_teeth(")
        miss_return = body.index("if (miss_type)\n\t\t\t\treturn FALSE")
        attack_pick = body.index("H.get_unarmed_attack(src, hit_zone)")
        self.assertLess(attack_pick, teeth)
        self.assertLess(miss_return, teeth)
        guard = body.rfind("if (!attack.deal_halloss)", 0, teeth)
        self.assertGreater(guard, miss_return)
        self.assertEqual(body.count("knock_out_teeth("), 1)

    def test_wall_slam_is_halloss_for_sparring(self):
        body = proc_body(UNARMED.read_text(), "/datum/unarmed_attack/proc/apply_effects(")
        slam = body.index("slams into [T]!")
        branch = body[slam: slam + 600]
        self.assertIn("if (deal_halloss)\n\t\t\t\t\t\t\ttarget.adjustHalLoss(rand(10,15))", branch)
        self.assertIn("else\n\t\t\t\t\t\t\ttarget.adjustBruteLoss(rand(10,15))", branch)
        self.assertEqual(body.count("adjustBruteLoss(rand(10,15))"), 1)


if __name__ == "__main__":
    unittest.main()
