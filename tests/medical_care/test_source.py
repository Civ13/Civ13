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
BASE_ORGAN = (ROOT / "code/modules/organs/organ.dm").read_text(encoding="utf-8")
AGENT = (ROOT / "code/modules/agent_control/agent_characters.dm").read_text(encoding="utf-8")
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
        self.assertNotIn("bad_external_organs", MEDICAL)
        close = block(MEDICAL, "/obj/item/stack/medical/proc/try_expert_close")
        self.assertIn("affecting.clear_treated_external_wounds()", close)
        self.assertIn("limb_needs(affecting)", close)

    def test_shared_treatment_guards(self):
        treat = block(MEDICAL, "/obj/item/stack/medical/proc/treat(")
        lookup = treat.index("H.get_organ(user.targeted_organ)")
        guard = treat.index("if (!affecting)", lookup)
        self.assertLess(guard, treat.index("affecting.", guard + 20))
        open_check = treat.index("if (affecting.open)")
        self.assertIn("\n\t\treturn\n", treat[open_check:treat.index("limb_needs(affecting)", open_check)])
        self.assertLess(treat.index("pre_treat("), open_check)
        # internal wounds are never touched by field treatment
        needs = block(MEDICAL, "/obj/item/stack/medical/proc/wound_needs")
        self.assertLess(needs.index("if (W.internal)"), needs.index("MED_BANDAGE"))
        # the expert close and the stack use come after the loop, and use is last
        self.assertLess(treat.index("try_expert_close(affecting, user)", open_check + 200), treat.index("use(min(used, amount))"))
        splint = block(MEDICAL, "/obj/item/stack/medical/splint/attack")
        lookup = splint.index("H.get_organ(user.targeted_organ)")
        self.assertLess(splint.index("if (!affecting)", lookup), splint.index("affecting.", lookup + 40))

    def test_every_treatment_item_uses_the_shared_proc(self):
        expected = {
            "/obj/item/stack/medical/bruise_pack\n": "MED_BANDAGE",
            "/obj/item/stack/medical/advanced/bruise_pack\n": "MED_BANDAGE|MED_DISINFECT",
            "/obj/item/stack/medical/advanced/herbs\n": "MED_DISINFECT|MED_SALVE",
            "/obj/item/stack/medical/advanced/sulfa\n": "MED_DISINFECT",
            "/obj/item/stack/medical/advanced/ointment\n": "MED_SALVE",
        }
        for path, flags in expected.items():
            self.assertIn(f"treat_flags = {flags}", block(MEDICAL, path), path)
        for path in ("bruise_pack", "advanced/bruise_pack", "advanced/herbs", "advanced/sulfa", "advanced/ointment"):
            self.assertNotIn(f"/obj/item/stack/medical/{path}/attack(", MEDICAL)

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
        self.assertIn("return try_tourniquet(H, affecting, user)",
                      block(MEDICAL, "/obj/item/stack/medical/bruise_pack/pre_treat"))
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

    def test_every_era_has_an_antibiotic(self):
        self.assertNotIn('get_reagent_amount("penicillin")', ORGAN + BASE_ORGAN)
        self.assertEqual((ORGAN + BASE_ORGAN).count("owner.get_antibiotic_dose()"), 4)
        table = re.search(r"var/list/antibiotic_strengths = list\(([^)]*)\)", BASE_ORGAN).group(1)
        for reagent in ('"penicillin" = 1', '"prontosil"', '"herbal_remedy"'):
            self.assertIn(reagent, table)
        dose = block(BASE_ORGAN, "/mob/living/human/proc/get_antibiotic_dose")
        self.assertIn("ingested.get_reagent_amount(id)", dose)
        treat = block(MEDICAL, "/obj/item/stack/medical/proc/treat(")
        self.assertIn("affecting.germ_level < INFECTION_LEVEL_TWO", treat)

    def test_herb_dose_reaches_the_antibiotic_threshold(self):
        # One chewed herb adds 10 units; the organ code needs a dose of 5.
        herbs = block(MEDICAL, "/obj/item/stack/medical/advanced/herbs/attack_self")
        self.assertIn('H.ingested.add_reagent("herbal_remedy", 10)', herbs)
        weight = float(re.search(r'"herbal_remedy" = ([0-9.]+)', BASE_ORGAN).group(1))
        self.assertGreaterEqual(10 * weight, 5)

    def test_agent_sees_injuries_and_can_aim(self):
        injuries = block(AGENT, "/proc/agent_injuries")
        for key in ('"bleeding"', '"artery_cut"', '"broken"', '"splinted"', '"tourniquet"', '"infected"',
                    '"untreated_wounds"', '"limb"'):
            self.assertIn(key, injuries)
        self.assertIn("if (W.internal)", injuries)
        state = block(AGENT, "/datum/agent_control/proc/character_state")
        self.assertIn('out["injuries"] = agent_injuries(H)', state)
        self.assertIn('out["aim"] = H.targeted_organ', state)
        self.assertIn('"aim")', block(AGENT, "/proc/agent_character_actions"))
        step = block(AGENT, "/datum/agent_control/proc/perform_step")
        self.assertIn("M.targeted_organ = limb", step)
        self.assertIn('"limb"', block(AGENT, "/datum/agent_control/proc/check_step"))

    def test_autopilot_points_a_bleeding_agent_at_the_limb(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("agent_catalog", ROOT / "tools/agent-control/catalog.py")
        catalog = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(catalog)
        self.assertIn("aim", catalog.CHARACTER_ACTIONS)
        self.assertIn("l_arm", catalog.LIMB["enum"])
        source = (ROOT / "tools/agent-control/autopilot.py").read_text(encoding="utf-8")
        self.assertIn('row.get("bleeding") or row.get("artery_cut")', source)
        self.assertIn("tourniquet", source)

    def test_every_era_can_splint_a_break(self):
        recipes = (ROOT / "config/crafting/material_recipes_global.txt").read_text(encoding="utf-8")
        line = next(l for l in recipes.splitlines() if "/obj/item/stack/medical/splint/wooden," in l)
        fields = line.replace("RECIPE: ", "").split(",")
        self.assertEqual(len(fields), 13)
        self.assertEqual(fields[0], "/material/wood/")
        self.assertEqual(fields[10], "0")  # no research needed, unlike iron splints
        self.assertIn("/obj/item/stack/medical/splint/wooden\n", MEDICAL)


if __name__ == "__main__":
    unittest.main()
