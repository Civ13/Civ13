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


    def test_flu_passes_only_next_to_someone_or_by_sneeze(self):
        nearby = self.severe.split("/mob/living/human/proc/acquire_nearby_disease()", 1)[1].split("/mob/living/human/proc/", 1)[0]
        # A whole boat crew caught flu in minutes: it reached 2 tiles through
        # walls at 1% a second per sick person, with no trait or resistance.
        self.assertIn("get_dist(src, H) > 1 || !Adjacent(H)", nearby)
        self.assertIn("#define FLU_ADJACENT_CHANCE 0.25", self.severe)
        self.assertIn("dview(2, get_turf(src))", nearby)  # plague: no walls either
        self.assertIn("infection_chance_scale(H.disease_type)", nearby)
        self.assertIn('infection_chance_scale("flu")', nearby)
        sneeze = self.severe.split("/mob/living/human/proc/sneeze_flu()", 1)[1]
        self.assertIn("dview(2, get_turf(src))", sneeze)
        self.assertIn("FLU_SNEEZE_COOLDOWN", sneeze)
        self.assertIn('H.infection_chance_scale("flu")', sneeze)
        emote = read(HUMAN + "emotes/emote.dm")
        self.assertIn("sneeze_flu()", emote.split('if ("sneeze")', 1)[1].split('if ("burp")', 1)[0])

    def test_every_natural_route_scales_by_traits_and_resistance(self):
        immunity = read(HUMAN + "immunity.dm")
        scale = immunity.split("/mob/living/human/proc/infection_chance_scale(kind)", 1)[1].split("\n\n", 1)[0]
        for part in ('"Weak Immune System"', '"Strong Immune System"', "resists_disease(kind)",
                     "disease_immunity", "disease_node_scale()", "1 - disease_resistance_to(kind) / IMMUNITY_PROTECTS"):
            self.assertIn(part, scale)
        hygiene = read(HUMAN + "human_needs.dm").split("/mob/living/human/proc/handle_hygiene()", 1)[1].split("/mob/living/human/proc/", 1)[0]
        self.assertIn('infection_chance_scale("typhus")', hygiene)
        self.assertIn('catch_disease("typhus")', hygiene)
        self.assertNotIn('disease_type = "typhus"', hygiene)

if __name__ == "__main__":
    unittest.main()
