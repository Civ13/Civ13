"""Source contracts for the mouse rework: rot creates no pests, mice are timid."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def block(source, header):
    """Text of one DM proc/type block: from its header to the next top-level line."""
    start = source.index(header)
    rest = source[start + len(header):]
    match = re.search(r"\n(?=/[a-z])", rest)
    return header + (rest[:match.start()] if match else rest)


PEST_SPAWN = re.compile(r"new\s*/mob/living/simple_animal/(mouse|cockroach|fly)\b")


class RotSpawnsNothing(unittest.TestCase):
    def test_food_rot_creates_no_pests(self):
        rot = block(read("code/modules/reagents/reagent_containers/food.dm"), "/obj/item/weapon/reagent_containers/food/proc/rot()")
        self.assertIsNone(PEST_SPAWN.search(rot))

    def test_chicken_carcass_creates_no_pests(self):
        source = read("code/modules/1713/complex_production.dm")
        self.assertIsNone(PEST_SPAWN.search(source))

    def test_cockroaches_are_short_lived(self):
        source = read("code/game/mob/living/simple_animal/friendly/cockroach.dm")
        life = block(source, "/mob/living/simple_animal/cockroach/New()")
        self.assertIn("PROC_REF(expire)), 10 MINUTES", life)
        self.assertIn("qdel(src)", block(source, "/mob/living/simple_animal/cockroach/proc/expire()"))


class TimidMouse(unittest.TestCase):
    def setUp(self):
        self.source = read("code/game/mob/living/simple_animal/friendly/mouse.dm")

    def test_mouse_never_attacks(self):
        base = block(self.source, "/mob/living/simple_animal/mouse\n")
        self.assertIn('behaviour = "scared"', base)
        self.assertIn("melee_damage_upper = 0", base)
        crossed = block(self.source, "/mob/living/simple_animal/mouse/Crossed(")
        self.assertNotIn("HOSTILE_STANCE", crossed)
        self.assertNotIn("npc_set_combat_target", crossed)

    def test_no_contact_or_birth_plague(self):
        crossed = block(self.source, "/mob/living/simple_animal/mouse/Crossed(")
        self.assertNotIn("disease", crossed)
        birth = block(self.source, "/mob/living/simple_animal/mouse/New()")
        self.assertNotIn("plaguemouse = TRUE", birth)

    def test_butchering_gives_plain_meat(self):
        harvest = block(self.source, "/mob/living/simple_animal/mouse/harvest_products(")
        self.assertNotIn("meat/human", harvest)
        self.assertIn("/obj/item/weapon/reagent_containers/food/snacks/meat,", harvest)


if __name__ == "__main__":
    unittest.main()
