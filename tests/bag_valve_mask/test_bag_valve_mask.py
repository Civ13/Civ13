"""Bag-valve mask only ventilates a patient still in reach (#5480)."""
import sys
from types import SimpleNamespace as NS
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MEDICAL = ROOT / "code/game/objects/items/stacks/medical.dm"
sys.path.insert(0, str(ROOT / "tests/save_movement"))
from source_adapter import project


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
        mask = body.index("if (M.check_mouth_coverage())", wait)
        self.assertLess(max(reach, held, mask), heal)
        # Self-treatment is still allowed: the reach check is skipped for the user.
        self.assertIn("M != user &&", body[wait:heal])

    def test_actual_mouth_coverage_controls_start_and_finish(self):
        def trial(covered_at_start, covered_at_finish, mask_slot, moves_away=False):
            relief, waits, notices = [], [], []
            patient = NS(wear_mask=mask_slot, human=True, covered=covered_at_start,
                         reachable=True, adjustOxyLoss=relief.append)
            patient.check_mouth_coverage = lambda: patient.covered
            user = NS(Adjacent=lambda target: target.reachable,
                      visible_message=lambda *_: None)

            def wait(_user, _time, target):
                waits.append(target)
                target.covered = covered_at_finish
                target.reachable = not moves_away
                return True

            attack = project(MEDICAL.read_text(), '/obj/item/bag_valve_mask/attack', 'M, user',
                             dict(ishuman=lambda m: m.human, QDELETED=lambda _m: False,
                                  do_after=wait, loc=user, to_chat=lambda _u, _msg: notices.append('covered'),
                                  SPAN_NOTICE=str, SPAN_WARNING=str))
            attack(patient, user)
            return len(waits), relief, notices

        # A helmet can cover the face with no item in the mask slot.
        self.assertEqual(trial(True, True, None), (0, [], ['covered']))
        # A lowered sterile mask can occupy that slot without covering the mouth.
        self.assertEqual(trial(False, False, 'lowered sterile mask'), (1, [-7], []))
        self.assertEqual(trial(False, True, None), (1, [], ['covered']))
        self.assertEqual(trial(False, False, None, moves_away=True), (1, [], []))


if __name__ == "__main__":
    unittest.main()
