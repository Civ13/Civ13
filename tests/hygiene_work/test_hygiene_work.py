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


class BathingTest(unittest.TestCase):
    BATH = read("code/modules/1713/bathing.dm")

    def test_bathe_verb(self):
        self.assertIn("/mob/living/human/verb/bathe()", self.BATH)
        self.assertIn("W.salty || !is_liquid_water(W)", self.BATH)
        self.assertIn("catch_dirty_water_illness(germs * 15 * 0.5)", self.BATH)
        self.assertIn("river_current_direction(W) ? BATHE_RUNNING : BATHE_STILL", self.BATH)

    def test_tubs_wash_to_the_same_level(self):
        closet = read("code/game/objects/structures/watercloset.dm")
        self.assertIn("H.raise_hygiene(HYGIENE_LEVEL_NORMAL)", closet)
        self.assertNotIn("raise_hygiene(src.cleanliness)", closet)

    def test_sponge_bath_is_capped(self):
        self.assertIn("SPONGE_BATH_MAX", read("code/modules/reagents/reagent_containers.dm"))
        self.assertIn("#define SPONGE_BATH_MAX 175", DEFINES)

    def test_tank_only_on_persistence(self):
        self.assertIn("return water_capacity && map && map.persistence", self.BATH)
        self.assertIn("/obj/structure/shower/piped\n\twater_capacity = 0", self.BATH)


class BodyWashingTest(unittest.TestCase):
    WASH = read("code/modules/1713/body_washing.dm")

    def test_help_intent_washes_the_targeted_part(self):
        self.assertIn("/obj/item/weapon/reagent_containers/glass/attack(mob/living/M, mob/living/user, target_zone)", self.WASH)
        self.assertIn("user.a_intent != I_HELP", self.WASH)
        self.assertIn('return zone && zone != "mouth" && zone != "random"', self.WASH)
        feed = read("code/modules/reagents/reagent_containers.dm")
        self.assertIn('if (ishuman(user) && user.targeted_organ != "mouth")', feed)

    def test_mugs_and_cups_wash_too(self):
        drinks = read("code/modules/reagents/reagent_containers/food/drinks.dm")
        self.assertIn("if (washes_on_click(M, user))\n\t\t\treturn wash_with(M, user)", drinks)
        self.assertIn("/obj/item/weapon/reagent_containers/proc/washes_on_click(mob/living/M, mob/living/user)", self.WASH)
        feed = read("code/modules/reagents/reagent_containers.dm")
        self.assertIn("instead, switch to help intent.", feed)

    def test_self_examine_shows_dirty_parts(self):
        self.assertIn("var/dirt = H.part_dirt_status(org)", read("code/game/mob/living/carbon/human/human.dm"))
        self.assertIn("Examine yourself to see which parts need washing.", read("code/game/mob/living/carbon/human/human_needs.dm"))
        self.assertIn("LAZYSET(washed_parts, E.limb_name, hygiene)", self.WASH)

    def test_feeling_follows_washed_parts(self):
        needs = read("code/game/mob/living/carbon/human/human_needs.dm")
        feeling = needs.split("/mob/living/human/proc/hygiene_feeling()", 1)[1].split("\n\n", 1)[0]
        self.assertIn("part_dirt_status(E)", feeling)
        self.assertIn("fairly clean", feeling)
        self.assertIn("under your clothes", feeling)
        self.assertIn("if (H.next_dirty_zone())", needs)
        wash = read("code/modules/1713/body_washing.dm")
        self.assertIn("raise_hygiene(SPONGE_BATH_MAX)", wash.split("proc/check_whole_body_washed()", 1)[1])
        self.assertIn("if (hygiene < HYGIENE_LEVEL_DIRTY)", read("code/game/mob/living/carbon/human/human_helpers.dm"))

    def test_scripted_drinkers_target_the_mouth(self):
        self.assertIn('{"do": "click", "target": me, "zone": "mouth"}', read("tools/agent-control/autopilot.py"))
        self.assertIn("select the mouth on the body doll", read("code/modules/1713/practice_rooms.dm"))

    def test_wounds_and_soap(self):
        self.assertIn("W.germ_level *= 0.5", self.WASH)
        self.assertIn("E.disinfect()", self.WASH)
        self.assertIn("if (E.germ_level < INFECTION_LEVEL_ONE)", self.WASH)
        self.assertIn('reagents.remove_reagent("water", WASH_PART_WATER)', self.WASH)
        self.assertIn('reagents.has_reagent("food_poisoning")', self.WASH)

    def test_sources_wash_parts(self):
        for proc in ("/obj/structure/sink/attack_hand(mob/user)", "/obj/structure/water_tap/attack_hand(mob/living/user)",
                     "/turf/floor/beach/water/attack_hand(mob/living/human/H)"):
            self.assertIn(proc, self.WASH)

    def test_hand_and_whole_body_washes_mark_parts(self):
        self.assertRegex(SOURCE, r"proc/wash_hands\(\)\n\tdirty_hands = 0\n\tif \(!gloves\)[^\n]*\n\t\tmark_part_washed\(\"l_hand\"\)\n\t\tmark_part_washed\(\"r_hand\"\)")
        self.assertIn("raise_hygiene(river_current_direction(W) ? BATHE_RUNNING : BATHE_STILL)\n\tmark_bare_parts_washed()",
                      read("code/modules/1713/bathing.dm"))
        self.assertIn("HT.clean_blood()\n\t\t\t\tHT.mark_bare_parts_washed()", read("code/modules/reagents/reagent_containers.dm"))

    def test_washing_carries_on_to_the_next_part(self):
        wash = read("code/modules/1713/body_washing.dm")
        self.assertIn("zone = target.next_dirty_zone(done)", wash)
        self.assertIn("if (source && !source.wash_spend(src))", wash)
        self.assertIn("H.wash_on_after_hands(src)", SOURCE)
        self.assertIn("WH.wash_on_after_hands(src)", read("code/game/objects/structures/watercloset.dm"))
        self.assertIn("H.wash_on_after_hands(src)", read("code/modules/1713/wash_places.dm"))

    def test_loads_after_the_procs_it_extends(self):
        dme = read("civ13.dme").splitlines()
        def at(name):
            return next(i for i, line in enumerate(dme) if line.endswith(name + '"'))
        mine = at("body_washing.dm")
        for name in ("glass.dm", "watercloset.dm", "factory_plumbing.dm", "hygiene_work.dm"):
            self.assertLess(at(name), mine, name)


if __name__ == "__main__":
    unittest.main()
