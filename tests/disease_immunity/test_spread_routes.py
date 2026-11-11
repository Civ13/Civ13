"""Source checks for how severe illnesses reach a person.

Players caught cholera without drinking anything: it spread from sick people
and bodies like plague, and any trace of germs in food or drink infected every
time, skipping the dose roll and the Strong Immune System trait. Cholera now
comes only from swallowed germs and typhus only from fleas; swallowing rolls
once per swallow on the dose actually swallowed.
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
HUMAN = "code/game/mob/living/carbon/human/"


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


class SpreadRoutes(unittest.TestCase):
    def setUp(self):
        self.severe = read(HUMAN + "severe_disease.dm")

    def test_only_flu_and_plague_spread_by_proximity(self):
        listed = re.search(r'var/global/list/contagious_diseases = list\(([^)]*)\)', self.severe).group(1)
        self.assertEqual(sorted(re.findall(r'"(\w+)"', listed)), ["flu", "plague"])
        nearby = self.severe.split("/mob/living/human/proc/acquire_nearby_disease()", 1)[1]
        self.assertIn("!(H.disease_type in contagious_diseases)", nearby)

    def test_swallowing_rolls_once_on_the_swallowed_dose(self):
        body = self.severe.split("/mob/living/human/proc/swallow_germs(", 1)[1].split("/mob/living/human/proc/", 1)[0]
        self.assertIn("prob(min(amount * 25 * dmod, 100))", body)
        self.assertIn('find_trait("Strong Immune System")', body)
        self.assertIn("resists_disease(kind)", body)
        for guard in ("disease", "orc", "crab"):
            self.assertRegex(body, rf"\b{guard}\b")
        taste = read("code/game/mob/living/carbon/taste.dm")
        self.assertIn("swallow_germs(temp)", taste)
        # The whole-container roll double-counted and used the full container.
        self.assertNotIn('has_reagent("cholera")', read("code/modules/reagents/reagent_containers.dm"))

    def test_germ_reagents_are_inert_in_the_stomach(self):
        toxins = read("code/modules/reagents/Chemistry-Reagents/Chemistry-Reagents-Toxins.dm")
        for kind in ("cholera", "typhus", "plague"):
            body = toxins.split(f"/datum/reagent/toxin/{kind}/affect_ingest(", 1)[1].split("\n\n", 1)[0]
            self.assertEqual(body.strip().splitlines()[-1].strip(), "return")


if __name__ == "__main__":
    unittest.main()
