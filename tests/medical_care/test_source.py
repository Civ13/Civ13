"""Offline source contracts for field treatment and artery repair; not native DM execution."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
MEDICAL = (ROOT / "code/game/objects/items/stacks/medical.dm").read_text(encoding="utf-8")
ORGAN = (ROOT / "code/modules/organs/organ_external.dm").read_text(encoding="utf-8")
SURGERY = (ROOT / "code/modules/surgery/other.dm").read_text(encoding="utf-8")
HANDBOOK = (ROOT / "code/modules/1713/doctor_handbook.dm").read_text(encoding="utf-8")
HEART = (ROOT / "code/modules/organs/internal/heart.dm").read_text(encoding="utf-8")
DEFINES = (ROOT / "code/predefines.dm").read_text(encoding="utf-8")
LIFE = (ROOT / "code/game/mob/living/carbon/human/human_life.dm").read_text(encoding="utf-8")


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

    def test_tourniquet_stops_limb_bleeding_and_times_out(self):
        bleed = HEART[HEART.index("//Bleeding out"):]
        loop = bleed.index("for(var/obj/item/organ/external/temp in owner.organs)")
        skip = bleed.index("if(temp.is_tourniqueted())", loop)
        self.assertLess(skip, bleed.index("temp.status & ORGAN_BLEEDING", loop))
        self.assertLess(skip, bleed.index("temp.status & ORGAN_ARTERY_CUT", loop))
        self.assertIn("temp.has_bandaged_wound()", bleed)
        tq = block(ORGAN, "/obj/item/organ/external/proc/handle_tourniquet")
        for term in ("tourniquet_ticks++", "TOURNIQUET_CLOT_TICKS", "arterial_bleed_severity <= 1",
                     "has_bandaged_wound()", "status &= ~ORGAN_ARTERY_CUT", "TOURNIQUET_NUMB_TICKS * 2",
                     "status |= ORGAN_DEAD"):
            self.assertIn(term, tq)
        self.assertNotIn("world.time", tq)
        process = block(ORGAN, "/obj/item/organ/external/process")
        self.assertIn("handle_tourniquet()", process)
        need = block(ORGAN, "/obj/item/organ/external/proc/need_process")
        self.assertIn("if (tourniquet)", need)
        apply = block(ORGAN, "/obj/item/organ/external/proc/apply_tourniquet")
        self.assertIn("owner.bad_external_organs |= src", apply)

    def test_bandage_roll_applies_and_loosens_tourniquet(self):
        attack = block(MEDICAL, "/obj/item/stack/medical/bruise_pack/attack(")
        self.assertLess(attack.index("try_tourniquet("), attack.index("if (affecting.open)"))
        tq = block(MEDICAL, "/obj/item/stack/medical/bruise_pack/proc/try_tourniquet")
        for term in ("affecting.remove_tourniquet()", "affecting.apply_tourniquet()",
                     "affecting.can_take_tourniquet()", "affecting.is_tourniqueted()", "use(1)"):
            self.assertIn(term, tq)
        self.assertLess(tq.index("do_mob(user, H, 30)"), tq.index("affecting.apply_tourniquet()"))
        self.assertIn("affected.remove_tourniquet()", block(SURGERY, "/datum/surgery_step/fix_vein"))

    def test_splinted_fracture_heals_over_time(self):
        heal = block(ORGAN, "/obj/item/organ/external/proc/handle_fracture_healing")
        for term in ("ORGAN_BROKEN", "ORGAN_SPLINTED", "owner.lying ? 2 : 1", "FRACTURE_HEAL_TICKS",
                     "mend_fracture()", "status &= ~ORGAN_SPLINTED", "/obj/item/stack/medical/splint/small"):
            self.assertIn(term, heal)
        self.assertIn("fracture_heal_ticks = 0", block(ORGAN, "/obj/item/organ/external/proc/fracture"))
        self.assertIn("handle_fracture_healing()", block(ORGAN, "/obj/item/organ/external/process"))
        self.assertIn("!E.tourniquet && !(E.status & ORGAN_BROKEN)", LIFE)
        for name in ("TOURNIQUET_CLOT_TICKS", "TOURNIQUET_NUMB_TICKS", "FRACTURE_HEAL_TICKS"):
            self.assertRegex(DEFINES, rf"#define {name} \d+")

    def test_fed_bodies_regenerate_blood_faster(self):
        regen = HEART[HEART.index("//Blood regeneration"):HEART.index("if(pulse != PULSE_NONE)")]
        self.assertIn("owner.nutrition >= 150 && owner.water >= 150", regen)
        self.assertEqual(regen.count("B.volume += 0.1"), 2)


if __name__ == "__main__":
    unittest.main()
