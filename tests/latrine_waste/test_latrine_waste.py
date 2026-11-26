"""Waste kept in pit latrines and outhouses can be dug and drawn back out (latrine_waste.dm); source checks."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8", errors="ignore")


SOURCE = read("code/modules/1713/latrine_waste.dm")
POO = read("code/game/mob/living/carbon/human/shit_piss.dm")


def proc(text, head):
    body = text.split(head, 1)[1]
    return body.split("\n/", 1)[0]


class LatrineWasteTest(unittest.TestCase):
    def test_included(self):
        dme = read("civ13.dme")
        self.assertIn('#include "code\\modules\\1713\\latrine_waste.dm"', dme)

    def test_only_unplumbed_fixtures_keep_waste(self):
        self.assertIn("return !is_plumbed()", proc(SOURCE, "/obj/structure/toilet/proc/keeps_waste()"))
        closet = read("code/game/objects/structures/watercloset.dm")
        self.assertIn("/obj/structure/toilet/pit_latrine/floorgrate/is_plumbed()\n\treturn TRUE", closet)
        self.assertIn("/obj/structure/toilet/outhouse/is_plumbed()\n\treturn FALSE", closet)

    def test_using_a_pit_fills_it(self):
        shit = proc(POO, "/mob/living/human/proc/handle_shit()")
        self.assertIn("T.flush_waste(V)", shit)
        self.assertIn("var/obj/structure/toilet/pit = in_outhouse ? loc : T", shit)
        self.assertIn("pit.take_night_soil(V)", shit)
        self.assertNotIn("V.forceMove(T)", shit)
        piss = proc(POO, "/mob/living/human/proc/handle_piss()")
        self.assertIn("T.take_urine(rand(5,10))", piss)
        self.assertIn("O.take_urine(rand(5,10))", piss)

    def test_full_pit_overflows(self):
        take = proc(SOURCE, "/obj/structure/toilet/proc/take_night_soil(")
        self.assertIn("night_soil++", take)
        self.assertIn("V.forceMove(get_turf(src))", take)
        self.assertIn("#define LATRINE_CAPACITY 30", SOURCE)
        urine = proc(SOURCE, "/obj/structure/toilet/proc/take_urine(")
        self.assertIn("LATRINE_URINE_CAPACITY - stored_urine", urine)
        self.assertIn("new /obj/effect/decal/cleanable/urine(T)", urine)

    def test_shovel_digs_one_load_and_dirties_hands(self):
        dig = proc(SOURCE, "/obj/structure/toilet/proc/dig_night_soil(")
        self.assertIn("night_soil--", dig)
        self.assertIn("new /obj/item/weapon/reagent_containers/food/snacks/poo/night_soil(get_turf(user))", dig)
        self.assertIn("H.soil(2, DIRTY_HANDS_WASTE)", dig)
        self.assertIn("is_tool(I, TOOL_SHOVEL)", SOURCE)

    def test_open_container_draws_urine(self):
        draw = proc(SOURCE, "/obj/structure/toilet/proc/draw_urine(")
        self.assertIn('RC.reagents.add_reagent("urine", amount)', draw)
        self.assertIn("stored_urine = max(0, stored_urine - amount)", draw)
        self.assertIn("H.soil(0, DIRTY_HANDS_WASTE)", draw)
        self.assertIn("I.is_open_container()", SOURCE)

    def test_drawing_rechecks_the_outhouse_door_after_wait(self):
        draw = proc(SOURCE, "/obj/structure/toilet/proc/draw_urine(")
        after_wait = draw.split("do_after(user, 15, src)", 1)[1]
        gate = after_wait.split("var/amount", 1)[0]
        self.assertRegex(gate, r"!latrine_reachable\(user\)\)\n\t\treturn")

    def test_drawing_rechecks_the_receiving_vessel_after_wait(self):
        draw = proc(SOURCE, "/obj/structure/toilet/proc/draw_urine(")
        after_wait = draw.split("do_after(user, 15, src)", 1)[1]
        gate = after_wait.split("var/amount", 1)[0]
        for check in ("QDELETED(RC)", "!RC.is_open_container()", "!RC.reagents"):
            self.assertIn(check, gate)
        self.assertRegex(gate, r"if \(.*!RC.is_open_container\(\).*\)\n\t\treturn")

    def test_outhouse_must_be_open(self):
        self.assertIn("istype(src, /obj/structure/toilet/outhouse) && !open", SOURCE)

    def test_night_soil_is_kept_fertilizer_but_still_waste(self):
        body = SOURCE.split("/obj/item/weapon/reagent_containers/food/snacks/poo/night_soil\n", 1)[1]
        self.assertIn("decay = 0", body)
        self.assertIn("fertilizer_value = 10", body)
        # Still human waste: not compost, so it fouls water and soils hands.
        self.assertNotIn("poo/fertilizer/night_soil", SOURCE)
        self.assertIn('istype(W, /obj/item/weapon/reagent_containers/food/snacks/poo)', read("code/modules/1713/production.dm"))

    def test_pit_holding_waste_fouls_wells(self):
        closet = read("code/game/objects/structures/watercloset.dm")
        self.assertIn("well_river_seepage() || latrine_fouls_near(src)", closet)
        fouls = proc(SOURCE, "/proc/latrine_fouls_near(")
        self.assertIn("T.night_soil > 0 && T.keeps_waste()", fouls)

    def test_saltpetre_inputs_exist(self):
        recipes = read("code/modules/reagents/Chemistry-Recipes.dm")
        self.assertIn('required_reagents = list("poo" = 2, "urine" = 1)', recipes)


if __name__ == "__main__":
    unittest.main()
