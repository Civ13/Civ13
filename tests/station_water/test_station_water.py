"""Station water tanks and running water feeds (station_water.dm); source checks.

The native probe station_water_probe.dm covers the behaviour; these checks
keep the wiring in place without a compiler.
"""
from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[2]


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


if __name__ == "__main__":
    unittest.main()
