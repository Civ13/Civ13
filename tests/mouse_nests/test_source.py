"""Source contracts for the mouse rework: rot creates no pests, mice are timid."""
from pathlib import Path
import re
import zlib
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

    def test_mice_eat_only_through_their_nest(self):
        base = block(self.source, "/mob/living/simple_animal/mouse\n")
        self.assertIn("granivore = 0", base)
        self.assertIn("scavenger = 0", base)

    def test_clay_jars_keep_mice_out(self):
        nests = read("code/modules/ecology/mouse_nests.dm")
        self.assertIn("/obj/structure/storage_container/storage_jar\n\trodent_access = RODENT_PROOF", nests)

    def test_butchering_gives_plain_meat(self):
        harvest = block(self.source, "/mob/living/simple_animal/mouse/harvest_products(")
        self.assertNotIn("meat/human", harvest)
        self.assertIn("/obj/item/weapon/reagent_containers/food/snacks/meat,", harvest)


class NestsAreTheSource(unittest.TestCase):
    def test_ecology_cycle_places_burrows(self):
        cycle = block(read("code/modules/ecology/ecology_spawning.dm"), "/datum/ecology_spawner/proc/cycle()")
        self.assertIn("mouse_burrow_cycle()", cycle)

    def test_process_settles_a_few_nests_per_fire(self):
        process = read("code/processes/mouse_nests.dm")
        self.assertIn("#define MOUSE_PROCESS_SETTLES 2", process)
        self.assertIn("schedule_interval = 10 SECONDS", process)

    def test_emitted_mice_are_not_saved(self):
        nests = read("code/modules/ecology/mouse_nests.dm")
        self.assertIn("should_save = FALSE // the nest's population already counts this mouse", nests)
        self.assertIn('return key == "out_mice" || ..()', nests)

    def test_nest_sprites_exist(self):
        data = (ROOT / "icons/obj/mouse_nests.dmi").read_bytes()
        start = data.index(b"zTXtDescription\x00\x00") + len(b"zTXtDescription\x00\x00")
        length = int.from_bytes(data[start - len(b"zTXtDescription\x00\x00") - 4:start - len(b"zTXtDescription\x00\x00")], "big")
        meta = zlib.decompress(data[start:start - len(b"Description\x00\x00") + length]).decode()
        for state in ("burrow", "nest_light", "nest_used", "nest_overrun"):
            self.assertIn(f'state = "{state}"', meta)


if __name__ == "__main__":
    unittest.main()
