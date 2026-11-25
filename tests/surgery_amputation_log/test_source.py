"""Surgical amputations must reach the admin attack log.

Gaia, 2026-11-20: players amputated an offline character's four limbs and the
only trace was their chat. The amputate step now logs the surgeon, the victim,
the limb and whether the victim was offline.
"""
from pathlib import Path
import re
import sys
from types import SimpleNamespace
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


class LimbGraftSourceTests(unittest.TestCase):
    def setUp(self):
        self.graft = (ROOT / "code/modules/surgery/limb_reattach.dm").read_text(encoding="utf-8")
        self.organs = (ROOT / "code/modules/organs/organ_external.dm").read_text(encoding="utf-8")
        self.wounds = (ROOT / "code/modules/organs/wound.dm").read_text(encoding="utf-8")

    def test_real_parent_and_each_child_slot_are_required(self):
        self.assertIn("parent.is_stump() || parent.owner != target || parent.loc != target", self.graft)
        self.assertIn("seen[limb_name] || target.get_organ(limb_name)", self.graft)
        self.assertIn("child.graft_slots_clear(target, seen, limb_name)", self.graft)
        self.assertIn("!isnull(inside_slot) && parent_organ != inside_slot", self.graft)

    def test_completion_revalidates_before_releasing_and_registering_donor(self):
        complete = self.graft.split("\tend_step(", 1)[1].split("\tfail_step(", 1)[0]
        self.assertLess(complete.index("can_use("), complete.index("drop_from_inventory("))
        self.assertLess(complete.index("drop_from_inventory("), complete.index("E.replaced("))
        self.assertIn("tool.loc != user", complete)

    def test_wound_cleanup_uses_saved_slot_not_list_order(self):
        self.assertIn("var/lost_limb_slot = null", self.wounds)
        self.assertIn("lost_limb_slot = lost_limb.limb_name", self.wounds)
        self.assertIn("parent.clear_grafted_limb_wound(limb_name)", self.organs)
        cleanup = self.organs.split("/proc/clear_grafted_limb_wound(", 1)[1]
        self.assertLess(cleanup.index("W.lost_limb_slot != slot"), cleanup.index("wounds -= W"))


class FacialCauteryTests(unittest.TestCase):
    def setUp(self):
        sys.path.insert(0, str(ROOT / 'tests/save_movement'))
        import source_adapter
        face = (ROOT / 'code/modules/surgery/face.dm').read_text(encoding='utf-8')
        step = face.split('/datum/surgery_step/face/cauterize\n', 1)[1]
        body = source_adapter.extract(step, 'end_step')
        body = re.sub(r'(?m)^\tuser\.visible_message\([\s\S]*?\n\t"[^\n]*"\)\n',
                      '\tnotify()\n', body, count=1)
        self.cauterize = source_adapter.project(
            '/cauterize()\n' + body + '\n', '/cauterize', 'target, target_zone',
            dict(notify=lambda: None, ORGAN_BLEEDING=4),
        )

    def test_face_stage_closes_without_changing_head_opening_or_bleeding(self):
        for stage in (1, 2, 3):
            with self.subTest(stage=stage):
                head = SimpleNamespace(open=2, status=12, disfigured=True)
                target = SimpleNamespace(op_stage=SimpleNamespace(face=stage),
                                         get_organ=lambda zone: head)
                self.cauterize(target, 'mouth')
                self.assertFalse(target.op_stage.face)
                self.assertEqual(head.open, 2)
                self.assertEqual(head.status, 12)
                self.assertEqual(head.disfigured, stage != 3)

    def test_uninjured_head_keeps_its_closed_state(self):
        head = SimpleNamespace(open=0, status=0, disfigured=True)
        target = SimpleNamespace(op_stage=SimpleNamespace(face=3),
                                 get_organ=lambda zone: head)
        self.cauterize(target, 'mouth')
        self.assertEqual((head.open, head.status, head.disfigured), (0, 0, False))


if __name__ == "__main__":
    unittest.main()
