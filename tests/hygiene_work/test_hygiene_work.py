"""Dirt from work and dirty hands (hygiene_work.dm); source checks.

tests/hygiene_work/hygiene_probe.dm covers soil() and hand washing natively.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8", errors="ignore")


SOURCE = read("code/modules/1713/hygiene_work.dm")
DEFINES = read("code/__defines/mobs.dm")


class HygieneWorkTest(unittest.TestCase):
    def test_slower_idle_dirt(self):
        self.assertIn("#define HYGIENE_FACTOR 0.015", DEFINES)
        # From normal (200) to dirty (75) idle takes over two hours.
        self.assertGreater((200 - 75) / 0.015 / 3600, 2)

    def test_dirt_sources_are_wired(self):
        self.assertIn('if (statname == "farming")', SOURCE)
        self.assertIn("/turf/mining_gem_pocket(mob/living/human/H)", SOURCE)
        self.assertIn("soil(5, DIRTY_HANDS_WASTE)", SOURCE)
        self.assertIn("H.soil(3, DIRTY_HANDS_GRIME)", read("code/modules/1713/animal_harvest.dm"))
        self.assertIn("hygiene_sweat()", read("code/game/mob/living/carbon/human/human_needs.dm"))

    def test_any_hand_wash_clears_hands(self):
        self.assertRegex(SOURCE, r"/mob/living/human/clean_blood\(\)\n\t\. = \.\.\(\)\n\twash_hands\(\)")
        # Sinks, taps and baths already call clean_blood() on the washer.
        for rel in ("code/game/objects/structures/watercloset.dm", "code/modules/1713/factory_plumbing.dm",
                    "code/modules/1713/aqueducts.dm"):
            self.assertIn("clean_blood()", read(rel), rel)
        self.assertIn("/turf/floor/beach/water/attack_hand(mob/living/human/H)", SOURCE)

    def test_first_bite_rolls_once(self):
        body = SOURCE.split("/obj/item/weapon/reagent_containers/food/snacks/On_Consume(mob/M)", 1)[1]
        body = body.split("\n\n", 1)[0]
        self.assertIn("!hands_rolled", body)
        self.assertIn("hands_rolled = TRUE", body)
        self.assertIn("return ..()", body)
        self.assertIn('infection_chance_scale("food_poisoning")', SOURCE)
        self.assertIn("catch_dirty_water_illness(DIRTY_HANDS_CHOLERA_CHANCE)", SOURCE)

    def test_gloves_keep_hands_clean(self):
        self.assertIn("if (hands > dirty_hands && !gloves)", SOURCE)
        self.assertIsNone(re.search(r"var/tmp/dirty_hands", SOURCE))


if __name__ == "__main__":
    unittest.main()
