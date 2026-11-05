"""Source checks for the illness pain ceiling and resting body heat.

Live reports showed a cholera patient at health 94.76 with halloss 1990 and
traumatic shock near 999, and every player outdoors at exactly the air
temperature (279.15 K at 6 C). The arithmetic below replays the per-second
rules from the production sources so the old behaviour fails these tests.
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def define(text, name):
    return int(re.search(rf"#define {name} (\d+)", text).group(1))


class IllnessPain(unittest.TestCase):
    def setUp(self):
        self.src = read("code/game/mob/living/carbon/human/severe_disease.dm")

    def test_illness_pain_is_capped(self):
        self.assertNotIn("\t\tapply_effect(3, AGONY, FALSE)\n", self.src)
        self.assertIn("if (halloss < pain_cap)", self.src)
        self.assertIn("apply_effect(min(3, pain_cap - halloss), AGONY, FALSE)", self.src)

    def test_cure_drops_piled_up_illness_pain(self):
        body = self.src[self.src.index("/mob/living/human/proc/clear_disease()"):self.src.index("/mob/living/human/proc/handle_severe_disease()")]
        self.assertIn("halloss = min(halloss, SEVERE_DISEASE_PAIN_CRITICAL)", body)
        self.assertLess(body.index("halloss = min("), body.index("disease = FALSE"))

    def test_an_hour_of_illness_stays_below_shock(self):
        normal = define(self.src, "SEVERE_DISEASE_PAIN")
        critical = define(self.src, "SEVERE_DISEASE_PAIN_CRITICAL")
        for cap in (normal, critical):
            halloss = 0
            for _ in range(3600):
                if halloss < cap:
                    halloss += min(3, cap - halloss)
                halloss = max(0, halloss - 1)  # standing recovery in human Life
            # updateshock counts halloss at 0.5; 80 starts shock on its own.
            self.assertLess(0.5 * halloss, 80)


class RestingBodyHeat(unittest.TestCase):
    def test_body_holds_heat_above_freezing_air(self):
        life = read("code/game/mob/living/carbon/human/human_life.dm")
        block = life[life.index("// No exposure loss this step"):life.index("if (map && (map.civilizations || map.ID == MAP_ANTARCTICA))")]
        self.assertIn("if (loc_temp < species.cold_level_1 || bodytemperature > species.body_temperature)", block)
        self.assertIn("temp_adj = -0.1", block)
        self.assertIn("temp_adj = 0.1", block)


class Rejuvenate(unittest.TestCase):
    def test_rejuvenate_clears_pain_shock_heat_and_illness(self):
        living = read("code/game/mob/living/living.dm")
        body = living[living.index("/mob/living/proc/rejuvenate()"):living.index("/mob/living/proc/UpdateDamageIcon()")]
        # setHalLoss() only adjusts brute damage, so it never cleared pain.
        self.assertNotIn("setHalLoss(0)", body)
        self.assertIn("\thalloss = 0\n", body)
        self.assertIn("H.clear_disease()", body)
        self.assertIn("H.bodytemperature = H.species.body_temperature", body)
        carbon = read("code/game/mob/living/carbon/carbon.dm")
        human = carbon[carbon.index("/mob/living/human/rejuvenate()"):carbon.index("/mob/living/human/relaymove(")]
        for line in ("ingested.clear_reagents()", "shock_stage = 0", "traumatic_shock = 0", "E.pain = 0"):
            self.assertIn(line, human)


if __name__ == "__main__":
    unittest.main()
