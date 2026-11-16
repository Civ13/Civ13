"""Offline source contracts: fertilizer (manure, compost) never rots away."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
POO = (ROOT / "code/game/mob/living/carbon/human/shit_piss.dm").read_text(encoding="utf-8")
FOOD = (ROOT / "code/modules/reagents/reagent_containers/food.dm").read_text(encoding="utf-8")
AI = (ROOT / "code/game/mob/living/simple_animal/simple_ai.dm").read_text(encoding="utf-8")
ANIMAL = (ROOT / "code/game/mob/living/simple_animal/simple_animal.dm").read_text(encoding="utf-8")


def type_block(source, path):
    return source.split(path + "\n", 1)[1].split("\n/", 1)[0]


class FertilizerNoDecayTests(unittest.TestCase):
    def test_fertilizer_types_have_no_decay(self):
        for path in ("/obj/item/weapon/reagent_containers/food/snacks/poo/animal",
                     "/obj/item/weapon/reagent_containers/food/snacks/poo/fertilizer"):
            block = type_block(POO, path)
            self.assertRegex(block, r"\n\tfertilizer_value = [1-9]")
            self.assertRegex(block, r"\n\tdecay = 0\b", path)
        # Human poo is not fertilizer and still rots away.
        self.assertIn("decay = 20*600", type_block(POO, "/obj/item/weapon/reagent_containers/food/snacks/poo"))

    def test_decay_loop_skips_any_fertilizer(self):
        new_proc = FOOD.split("/obj/item/weapon/reagent_containers/food/New()", 1)[1].split("\n/", 1)[0]
        self.assertIn("if (decay > 0 && fertilizer_value <= 0)", new_proc)
        loop = FOOD.split("/proc/food_decay()", 1)[1]
        first_check = loop.index("if (decay == 0 || fertilizer_value > 0)")
        self.assertLess(first_check, loop.index("decaytimer +="))
        self.assertLess(first_check, loop.index("qdel(src)"))

    def test_animals_do_not_pile_up_endless_manure(self):
        proc = AI.split("/mob/living/simple_animal/proc/drop_manure()", 1)[1].split("\n/", 1)[0]
        self.assertIn("in range(1, src)", proc)
        self.assertLess(proc.index("in range(1, src)"), proc.index("new/obj/item/weapon/reagent_containers/food/snacks/poo/animal(loc)"))
        for source in (AI, ANIMAL):
            self.assertEqual(len(re.findall(r"new\s*/obj/item/weapon/reagent_containers/food/snacks/poo/animal\(", source)),
                             1 if source is AI else 0)


if __name__ == "__main__":
    unittest.main()
