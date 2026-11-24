"""Source checks for gradual disease immunity and poison tolerance.

A patient kept on interrupted medicine could hold cholera forever because
nothing but a finished course ever cleared a severe illness. The arithmetic
below replays the per-second rules from the production sources.
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
HUMAN = "code/game/mob/living/carbon/human/"


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def define(text, name):
    return float(re.search(rf"#define {name} ([\d.]+)", text).group(1))


class DiseaseImmunity(unittest.TestCase):
    def setUp(self):
        self.src = read(HUMAN + "immunity.dm")
        self.full = define(self.src, "IMMUNITY_FULL")
        self.protects = define(self.src, "IMMUNITY_PROTECTS")
        self.untreated = define(self.src, "IMMUNITY_GAIN_UNTREATED")
        self.treated = define(self.src, "IMMUNITY_GAIN_TREATED")
        self.decay = define(self.src, "IMMUNITY_DECAY")

    def test_immunity_runs_every_life_tick_before_illness(self):
        disease = read(HUMAN + "human_disease.dm")
        body = disease[disease.index("/mob/living/human/proc/handle_disease()"):]
        self.assertLess(body.index("if (handle_immunity())"), body.index("handle_severe_disease()"))
        self.assertLess(body.index("if (stat == DEAD)"), body.index("if (handle_immunity())"))
        self.assertIn('#include "code\\game\\mob\\living\\carbon\\human\\immunity.dm"', read("civ13.dme"))

    def test_untreated_severe_illness_can_recover(self):
        severe = read(HUMAN + "severe_disease.dm")
        self.assertNotIn("death()", severe)
        self.assertNotIn("adjustToxLoss", severe)
        self.assertNotIn("adjustBrainLoss", severe)
        self.assertAlmostEqual(self.full / self.untreated, 2000)
        self.assertIn("if (updated >= IMMUNITY_FULL)", self.src)
        self.assertIn("clear_disease()", self.src)

    def test_ordinary_flu_does_not_damage_brain(self):
        disease = read(HUMAN + "human_disease.dm")
        flu = disease.split('else if (disease_type == "flu")', 1)[1].split('else if (disease_type == "zombie")', 1)[0]
        self.assertNotIn("adjustBrainLoss", flu)
        self.assertIn("disease_progression >= 240", flu)
        self.assertIn("adjustBrainLoss(200)", disease)  # exceptional zombie course unchanged

    def test_interrupted_treatment_cannot_hold_an_illness_forever(self):
        # Alternate 60 s on medicine and 30 s off: courses never finish (180
        # treated seconds in a row) but resistance still clears the illness.
        resistance, seconds, progression = 0.0, 0, 0
        while resistance < self.full:
            treated = seconds % 90 < 60
            resistance += self.treated if treated else self.untreated
            if not treated:
                progression += 1
            seconds += 1
        self.assertLess(seconds, 20 * 60)
        self.assertLess(progression, 1200)

    def test_recovery_protects_for_a_while_then_fades(self):
        seconds_protected = (self.full - self.protects) / self.decay
        self.assertGreater(seconds_protected, 30 * 60)
        self.assertLess(self.full / self.decay, 3 * 3600)
        self.assertIn("if (resists_disease(fighting))", self.src)
        self.assertIn("disease_resistance -= faded", self.src)
        # Only the illness being fought is exempt from fading.
        self.assertIn("if (kind == fighting)\n\t\t\t\tcontinue", self.src)

    def test_flu_never_sleeps_or_paralyses_and_floors_once(self):
        # Chat feedback 2026-11-17: sick players spent minutes unable to act.
        disease = read(HUMAN + "human_disease.dm")
        flu = disease.split('else if (disease_type == "flu")', 1)[1].split('else if (disease_type == "zombie")', 1)[0]
        for banned in ("DROWSY", "Weaken(", "Paralyse(", "Stun(", "sleeping"):
            self.assertNotIn(banned, flu)
        self.assertEqual(flu.count("flu_knockdown()"), 1)
        self.assertIn("#define FLU_MAX_DOWNS 1\n#define FLU_DOWN_TIME 2\n", disease)
        helper = disease.split("/mob/living/human/proc/flu_knockdown()", 1)[1].split("/mob/living/human/proc/handle_disease()", 1)[0]
        self.assertIn("if (flu_downs >= FLU_MAX_DOWNS)\n\t\treturn FALSE", helper)
        self.assertIn("Weaken(FLU_DOWN_TIME)", helper)
        self.assertEqual(flu.count("flu_downs = 0"), 2)
        self.assertIn("<big><font color='#3d9e3d'><b>You feel much better now! The illness is gone.</b></font></big>", flu)

    def test_disease_classifications_preserve_membership_and_active_guard(self):
        # This projects the two source helpers; it does not execute BYOND DM.
        severe = read(HUMAN + "severe_disease.dm")
        severe = severe.split("/mob/living/human/proc/is_severe_disease()", 1)[1].split("\n\n", 1)[0]
        immunity = self.src.split("/mob/living/human/proc/builds_disease_immunity(kind)", 1)[1].split("\n\n", 1)[0]

        def check(body, variable, expected, expression):
            declaration = re.search(rf"var/static/list/{variable} = list\(([^)]*)\)", body)
            self.assertIsNotNone(declaration)
            self.assertEqual(re.findall(r'"([^"]+)"', declaration.group(1)), expected)
            self.assertIn(expression, body)
            self.assertEqual(body.count(variable), 2)  # Declared and read only.

        severe_args = ("severe_diseases", ["plague", "typhus", "malaria", "cholera"],
                       "return disease && (disease_type in severe_diseases)")
        immunity_args = ("immune_diseases", ["flu", "plague", "typhus", "malaria", "cholera"],
                         "return kind in immune_diseases")
        check(severe, *severe_args)
        check(immunity, *immunity_args)
        # Negative controls prove this projection rejects a lost guard or a
        # broadened classification instead of merely finding the helper.
        with self.assertRaises(AssertionError):
            check(severe.replace("disease && ", ""), *severe_args)
        with self.assertRaises(AssertionError):
            check(immunity.replace('"flu"', '"worms"'), *immunity_args)

    def test_resistance_blocks_contagion_and_flu_recovery_grants_it(self):
        severe = read(HUMAN + "severe_disease.dm")
        # Proximity and filth rolls go through infection_chance_scale(), which
        # blocks anyone whose resistance protects them.
        self.assertIn("infection_chance_scale(H.disease_type)", severe)
        self.assertIn('infection_chance_scale("flu")', severe)
        scale = self.src.split("/mob/living/human/proc/infection_chance_scale(kind)", 1)[1]
        self.assertIn("resists_disease(kind)", scale.split("\n\n", 1)[0])
        self.assertIn('disease_resistance["flu"] = 100', read(HUMAN + "human_disease.dm"))
        for kind in ("flu", "plague", "typhus", "malaria", "cholera"):
            self.assertIn(f'"{kind}"', self.src[self.src.index("builds_disease_immunity(kind)"):])
        self.assertNotIn('"zombie"', self.src)


class PoisonTolerance(unittest.TestCase):
    def setUp(self):
        self.src = read(HUMAN + "immunity.dm")
        self.max = define(self.src, "POISON_TOLERANCE_MAX_REDUCTION")
        self.half = define(self.src, "POISON_TOLERANCE_HALF")
        self.cap = define(self.src, "POISON_TOLERANCE_CAP")

    def factor(self, exposure):
        return 1 - self.max * exposure / (exposure + self.half)

    def test_base_toxin_damage_uses_tolerance(self):
        toxins = read("code/modules/reagents/Chemistry-Reagents/Chemistry-Reagents-Toxins.dm")
        base = toxins[toxins.index("/datum/reagent/toxin/affect_blood("):toxins.index("/datum/reagent/toxin/plasticide")]
        self.assertIn("M.adjustToxLoss(strength * removed * M.poison_tolerance(id, removed, name))", base)
        self.assertNotIn("M.adjustToxLoss(strength * removed)\n", base)
        self.assertIn("/mob/living/proc/poison_tolerance(id, removed, poison_name)\n\treturn 1", self.src)

    def test_tolerance_is_gradual_and_never_immunity(self):
        self.assertEqual(self.factor(0), 1)
        self.assertAlmostEqual(self.factor(self.half), 1 - self.max / 2)
        self.assertGreaterEqual(self.factor(self.cap), 0.5)
        previous = 1
        for units in range(1, int(self.cap) + 1):
            current = self.factor(units)
            self.assertLess(current, previous)
            previous = current




class ImmunizationClinic(unittest.TestCase):
    def setUp(self):
        self.clinic = read("code/modules/1713/immunization_clinic.dm")
        self.severe = read(HUMAN + "severe_disease.dm")

    def proc(self, text, marker):
        return text.split(marker, 1)[1].split("\n/", 1)[0]

    def test_both_drinking_routes_check_cholera_without_masking_worms(self):
        for entry, guard, worm in (
            ("proc/swallow_germs(", "immunization_protects(kind)", 'catch_disease("worms")'),
            ("proc/catch_dirty_water_illness(", 'immunization_protects("cholera")', 'catch_disease("worms")'),
        ):
            body = self.proc(self.severe, entry)
            self.assertLess(body.index(guard), body.index("catch_disease("))
            self.assertIn(worm, body)
        generic = self.proc(read(HUMAN + "immunity.dm"), "proc/infection_chance_scale(")
        self.assertIn("immunization_protects(kind)", generic)
        illness = self.proc(read(HUMAN + "immunity.dm"), "proc/handle_immunity()")
        self.assertNotIn("immunization", illness)

    def test_window_and_existing_case_are_separate(self):
        protects = self.proc(self.clinic, "proc/immunization_protects(")
        self.assertIn('kind != "cholera"', protects)
        self.assertIn("now >= entry[1] && now < entry[2]", protects)
        record = self.proc(self.clinic, "proc/receive_clinic_immunization(")
        self.assertIn("(disease && disease_type == kind)", record)
        self.assertIn("now < entry[2]", record)
        self.assertIn("starts + CLINIC_CHOLERA_PROTECTION_MINUTES", record)
        for name in ("disease_treatment", "disease_course", "clear_disease(", "disease_resistance"):
            self.assertNotIn(name, record)

    def test_consent_rechecks_precede_the_only_dose_commit(self):
        offer = self.proc(self.clinic, "/immunization_clinic/attack_hand(")
        consent = offer.index('answer != "Accept"')
        commit = offer.index("apply_clinic_dose(")
        for guard in ("clinic_active()", "H.client != operator", "patient.client != recipient",
                      'crafting_node_allowed(H, "immunization")', "clinic_doses <= 0"):
            self.assertIn(guard, offer[consent:commit])
        dose = self.proc(self.clinic, "proc/apply_clinic_dose(")
        self.assertLess(dose.index("receive_clinic_immunization("), dose.index("clinic_doses--"))
        self.assertNotIn("sleep(", dose)
        self.assertNotIn("WWinput", dose)

    def test_paid_and_bounded_supplies_cannot_use_a_moved_stack(self):
        stock = self.proc(self.clinic, "/immunization_clinic/attackby(")
        for guard in ("clinic_active()", "clinic_present(H)", '"immunization"',
                      "CLINIC_DOSE_CAPACITY - CLINIC_BATCH_DOSES", "S.loc != H", "H.get_active_hand() != S"):
            self.assertLess(stock.index(guard), stock.index("S.use(1)"))
        self.assertLess(stock.index("S.use(1)"), stock.index("clinic_doses += CLINIC_BATCH_DOSES"))

    def test_single_world_rollout_and_save_shape(self):
        active = self.proc(self.clinic, "proc/clinic_active()")
        self.assertIn("map.ordinal_age >=", active)
        self.assertIn("!shard_group.enabled", active)
        self.assertIn("/mob/living/human/var/list/immunization_record = null", self.clinic)
        self.assertNotIn("var/tmp/immunization_record", self.clinic)
        self.assertIn("world.realtime", self.proc(self.clinic, "proc/immunization_now()"))
        nodes = read("code/modules/research_tree/research_node.dm")
        self.assertRegex(nodes, r'"immunization", "Immunization", "Health".*list\("germ_theory", "pharmacology"\), 5')
        self.assertIn('"/obj/structure/workshop_machine/immunization_clinic" = "immunization"', nodes)


if __name__ == "__main__":
    unittest.main()
