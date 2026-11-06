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

    def test_untreated_severe_illness_still_kills_first(self):
        # Severe illness kills untreated at progression 1200 (one per second).
        self.assertIn("disease_progression >= 1200", read(HUMAN + "severe_disease.dm"))
        self.assertLess(1200 * self.untreated, self.full)

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
        self.assertIn("if (kind == fighting)\n\t\t\tcontinue", self.src)

    def test_resistance_blocks_contagion_and_flu_recovery_grants_it(self):
        severe = read(HUMAN + "severe_disease.dm")
        self.assertIn("resists_disease(H.disease_type)", severe)
        self.assertIn('!resists_disease("flu")', severe)
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


if __name__ == "__main__":
    unittest.main()
