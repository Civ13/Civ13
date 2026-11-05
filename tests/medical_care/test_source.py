"""Offline source contracts for field treatment and artery repair; not native DM execution."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
MEDICAL = (ROOT / "code/game/objects/items/stacks/medical.dm").read_text(encoding="utf-8")
ORGAN = (ROOT / "code/modules/organs/organ_external.dm").read_text(encoding="utf-8")
SURGERY = (ROOT / "code/modules/surgery/other.dm").read_text(encoding="utf-8")
HANDBOOK = (ROOT / "code/modules/1713/doctor_handbook.dm").read_text(encoding="utf-8")


def block(source, path):
    match = re.search(rf"(?m)^{re.escape(path)}[^\n]*\n(?:(?:\t[^\n]*|)\n)*", source)
    if not match:
        raise AssertionError(f"missing {path}")
    return match.group()


class MedicalCare(unittest.TestCase):
    def test_severed_artery_is_repairable(self):
        step = block(SURGERY, "/datum/surgery_step/fix_vein")
        can_use = step[step.index("can_use("):step.index("begin_step(")]
        end = step[step.index("end_step("):step.index("fail_step(")]
        self.assertIn("ORGAN_ARTERY_CUT", can_use)
        self.assertIn("status &= ~ORGAN_ARTERY_CUT", end)
        self.assertIn("affected.update_damages()", end)

    def test_expert_shortcut_keeps_internal_wounds(self):
        helper = block(ORGAN, "/obj/item/organ/external/proc/clear_treated_external_wounds")
        self.assertIn("if (W.internal)", helper)
        self.assertIn("continue", helper)
        self.assertIn("update_damages()", helper)
        self.assertNotIn("wounds.Cut()", MEDICAL)
        self.assertNotIn("H_user.bad_external_organs", MEDICAL)
        self.assertEqual(MEDICAL.count("affecting.clear_treated_external_wounds()"), 2)

    def test_missing_limb_and_open_wound_guards(self):
        for path in ("/obj/item/stack/medical/advanced/sulfa/attack",
                     "/obj/item/stack/medical/advanced/ointment/attack",
                     "/obj/item/stack/medical/splint/attack"):
            body = block(MEDICAL, path)
            lookup = body.index("H.get_organ(user.targeted_organ)")
            guard = body.index("if (!affecting)", lookup)
            self.assertLess(guard, body.index("affecting.", lookup + 40), path)
        herbs = block(MEDICAL, "/obj/item/stack/medical/advanced/herbs/attack(")
        open_check = herbs.index("if (affecting.open)")
        self.assertIn("\n\t\t\treturn\n", herbs[open_check:herbs.index("is_salved()", open_check)])

    def test_splint_needs_break_or_dislocation(self):
        splint = block(MEDICAL, "/obj/item/stack/medical/splint/attack")
        self.assertIn("!(affecting.status & ORGAN_BROKEN) && !affecting.is_dislocated()", splint)
        self.assertNotIn("affecting.status == 0", splint)

    def test_handbook_lists_every_unsplinted_limb(self):
        self.assertIn('(e.limb_name in list("l_arm", "r_arm", "l_leg", "r_leg")) && !(e.status & ORGAN_SPLINTED)',
                      HANDBOOK)


if __name__ == "__main__":
    unittest.main()
