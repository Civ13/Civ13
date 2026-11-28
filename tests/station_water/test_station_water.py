"""Station water tanks and running water feeds (station_water.dm); source checks.

The native probe station_water_probe.dm covers the behaviour; these checks
keep the wiring in place without a compiler.
"""
from pathlib import Path
import json
import sys
import unittest
from unittest.mock import Mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests/save_movement"))
from source_adapter import extract, project


def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8", errors="ignore")


SOURCE = read("code/modules/1713/station_water.dm")


class StationWaterTest(unittest.TestCase):
    def test_included_after_its_feeds(self):
        dme = read("civ13.dme")
        self.assertLess(dme.index("aqueducts.dm"), dme.index("station_water.dm"))

    def test_feeds(self):
        for feed in ("/obj/structure/aqueduct/feeds_station_water()",
                     "/obj/structure/sink/feeds_station_water()",
                     "/obj/structure/sink/aqueduct_fountain/feeds_station_water()",
                     "/obj/structure/aqueduct_bath/feeds_station_water()",
                     "/obj/structure/water_tap/feeds_station_water()"):
            self.assertIn(feed, SOURCE)
        # A river feeds only with a current and above low water; ice never.
        self.assertIn("is_liquid_water(T) && aqueduct_fresh_water(T)", SOURCE)
        self.assertIn("river_current_direction(T) && river_stage_at(T) > STATION_WATER_LOW_STAGE", SOURCE)

    def test_fed_tanks_keep_no_timer(self):
        self.assertNotIn("spawn(", SOURCE)
        self.assertNotIn("addtimer", SOURCE)
        self.assertNotIn("world.time - water", SOURCE)

    def test_pipes_fill_only_water(self):
        self.assertIn('id == "water"', SOURCE)
        self.assertIn("FLUID_TIER_SINK", SOURCE)

    def test_hand_recipes_with_water_name_real_products(self):
        needs = json.loads(read("config/craft_needs.json"))
        watered = {k for k, v in needs.items() if v.get("water")}
        self.assertTrue(watered)
        rows = "\n".join(read(str(p.relative_to(ROOT))) for p in (ROOT / "config/crafting").glob("material_recipes_*.txt"))
        for product in watered:
            self.assertIn("," + product + ",", rows, product)


    def test_stations_take_water(self):
        clay = read("code/modules/1713/clay_lime_fire.dm")
        self.assertEqual(clay.count("station_water_pour(I, H)"), 2)
        self.assertEqual(clay.count("!station_take_water(H)"), 2)
        self.assertEqual(clay.count("station_water_examine(user)"), 2)
        self.assertIn("/obj/structure/converter/retting_trough/attackby(obj/item/M, mob/user)", SOURCE)

    def test_availability_checks_the_feed_once_and_warns_only_on_request(self):
        user = object()
        for store, fed, viewer, available in (
            (2, False, user, False),
            (2, False, None, False),
            (5, False, user, True),
            (0, True, user, True),
        ):
            with self.subTest(store=store, fed=fed, viewer=viewer is not None):
                feed = Mock(return_value=fed)
                warn = Mock()
                env = {"water_store": store, "station_water_feed": feed,
                       "station_warn_needs_water": warn}
                check = project(SOURCE, "/obj/structure/proc/station_has_water", "amount, user", env)
                self.assertEqual(check(5, viewer), available)
                self.assertEqual(env["water_store"], store)
                feed.assert_called_once_with()
                if viewer and not available:
                    warn.assert_called_once_with(viewer, 5)
                else:
                    warn.assert_not_called()

    def test_station_actions_check_water_before_work_and_debit_afterward(self):
        stations = (
            ("clay_lime_fire", "/obj/structure/workshop_machine/potters_wheel/proc/throw_wares"),
            ("clay_lime_fire", "/obj/structure/workshop_machine/brick_bench/proc/mould_bricks"),
            ("placer", "/obj/structure/placer_washer/proc/wash"),
            ("amalgam", "/obj/structure/stone_crusher/proc/work_arrastra"),
            ("wash_places", "/obj/structure/washbasin/attack_hand"),
        )
        for file, proc in stations:
            with self.subTest(proc=proc):
                body = extract(read(f"code/modules/1713/{file}.dm"), proc)
                self.assertEqual(body.count("station_take_water(H)"), 1)
                self.assertLess(body.index("!station_has_water(user = H)"), body.index("do_after("))
                self.assertLess(body.index("do_after("), body.index("station_take_water(H)"))

    def test_wash_places(self):
        wash = read("code/modules/1713/wash_places.dm")
        self.assertIn("water_per_use = 5", wash)
        self.assertRegex(wash, r'H\.wash_part_of\(H, zone, "\\the \[src\]", src\)')
        comfort = read("code/game/mob/living/carbon/human/home_comfort.dm")
        self.assertIn('"wash" = "a place to wash"', comfort)
        self.assertIn("if (mess <= HOME_MESS_ALLOWED && !foul)", comfort)
        self.assertIn("/obj/item/weapon/clay/washbasin = list(3, 50)", read("code/modules/1713/clay_lime_fire.dm"))

    def test_quench_tub(self):
        quench = read("code/modules/1713/quench_tub.dm")
        self.assertIn("water_per_use = 10", quench)
        self.assertIn('return material_name == "iron" || material_name == "steel"', quench)
        self.assertIn("/obj/structure/anvil/finish_forged_piece(", quench)
        self.assertIn("quench_tub,", read("config/crafting/material_recipes_global.txt"))
        self.assertIn('"/obj/structure/quench_tub" = "iron_smithing"', read("code/modules/research_tree/research_node.dm"))
        dme = read("civ13.dme")
        self.assertLess(dme.index("blacksmithing\\blacksmithing.dm"), dme.index("1713\\quench_tub.dm"))


if __name__ == "__main__":
    unittest.main()
