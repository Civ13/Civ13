"""The relief generator: a land's coasts, ranges, rivers and lakes are shares
of its own area, so the same rules give a sound land at every size."""
import copy
import json
import unittest

from tools.procedural_maps import land
from tools.procedural_maps.configuration import relief_preset, validate_config
from tools.procedural_maps.generator import generate
from tools.procedural_maps.validator import LAND_VERSION, PORT_VERSION, validate


def cells(doc):
    return doc["layers"]["SURFACE"]["cells"]


def census(doc):
    counts = {}
    for row in cells(doc):
        for c in row:
            key = c["water"] if c["water"] != "NONE" else c["terrain"]
            counts[key] = counts.get(key, 0) + 1
    return counts


def template(biome, land_type, width, height, coast=("S",), ridges=1):
    return {"biome": biome, "land_type": land_type, "size": "TINY", "width": width, "height": height,
            "coast": list(coast), "seed": "relief-test:1", "features": {"ridges": ridges},
            "resources": {"ore": "fair", "ores": [], "rare": [], "fertility": "fair", "game": []}}


class ReliefConfigTests(unittest.TestCase):
    def test_presets_are_valid_for_every_coast_and_for_islands(self):
        for sides in (("S",), ("E", "N"), ("N", "S", "W"), ("E", "N", "S", "W")):
            self.assertEqual([], validate_config(relief_preset("c", 96, 96, sea_sides=sides)), sides)
        self.assertEqual([], validate_config(relief_preset("c", 200, 200, islands=[3, 5])))
        self.assertEqual([], validate_config(relief_preset("c", 1280, 1280)))

    def test_bad_layouts_are_refused(self):
        def refused(change):
            c = relief_preset("c", 200, 200)
            change(c)
            self.assertTrue(validate_config(c), c["relief_layout"])
        refused(lambda c: c["relief_layout"].update(form="RING"))
        refused(lambda c: c["relief_layout"].update(sea_sides=[]))
        refused(lambda c: c["relief_layout"].update(sea_sides=["S", "N"]))          # not sorted
        refused(lambda c: c["relief_layout"].update(sea_sides=["UP"]))
        refused(lambda c: c["relief_layout"].update(islands=[2, 3]))                # a mainland is one land
        refused(lambda c: c["relief_layout"].update(mountain_pct=[0, 40]))
        refused(lambda c: c["relief_layout"].update(river_max_half_width=5))
        refused(lambda c: c["relief_layout"].pop("swamp_pct"))
        refused(lambda c: c["relief_layout"].update(disable_checks=True))
        refused(lambda c: c.update(water={}))
        refused(lambda c: c.update(biome_mix_pct={"LUSH": 50, "DESERT": 50}))        # skips the bands between
        refused(lambda c: c.update(biome_mix_pct={"COAST": 100}))
        refused(lambda c: c["dimensions"].update(width=2000))
        islands = relief_preset("c", 64, 64, islands=[3, 5])
        self.assertTrue(validate_config(islands), "five islands do not fit 64 x 64")


class ReliefGenerationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.small = generate(relief_preset("relief-0", 96, 96))
        cls.large = generate(relief_preset("relief-0", 300, 300))

    def test_a_land_is_valid_and_the_same_every_time(self):
        for result in (self.small, self.large):
            self.assertEqual("GENERATED_VALID_OFFLINE_IR", result["status"], result["reasons"])
            self.assertEqual(LAND_VERSION, result["document"]["schema"])
            self.assertEqual([], validate(result["document"]))
        again = generate(relief_preset("relief-0", 96, 96))
        self.assertEqual(self.small["manifest"]["generation_result"]["ir_sha256"],
                         again["manifest"]["generation_result"]["ir_sha256"])
        other = generate(relief_preset("relief-1", 96, 96))
        self.assertNotEqual(self.small["manifest"]["generation_result"]["ir_sha256"],
                            other["manifest"]["generation_result"]["ir_sha256"])

    def test_the_same_land_on_every_platform(self):
        # Integer arithmetic only: this hash must not depend on the machine.
        self.assertEqual(GOLDEN_96, self.small["manifest"]["generation_result"]["ir_sha256"])

    def test_features_grow_with_the_land(self):
        a, b = self.small["manifest"]["generated_topology"], self.large["manifest"]["generated_topology"]
        self.assertGreater(b["rivers"], a["rivers"])
        self.assertGreaterEqual(b["lakes"], a["lakes"])
        self.assertGreater(b["starts"], a["starts"])
        self.assertGreater(b["rivers"], 8, "a 300 x 300 land has a river system, not one channel")

    def test_shares_hold_at_both_sizes(self):
        for result in (self.small, self.large):
            doc, config = result["document"], result["manifest"]["configuration"]
            counts, area = census(doc), doc["width"] * doc["height"]
            layout = config["relief_layout"]
            self.assertTrue(layout["sea_pct"][0] - 2 <= counts["SEA"] * 100 / area <= layout["sea_pct"][1] + 2, counts)
            dry = area - counts["SEA"]
            self.assertTrue(8 <= counts["RIVER"] * 1000 / dry <= 60, counts)
            self.assertLessEqual(counts.get("LAKE", 0) * 100 / dry, layout["lake_max_pct"] + 1)
            self.assertLessEqual(counts.get("MOUNTAIN", 0) * 100 / dry, layout["mountain_pct"][1] + 1)

    def test_the_open_sea_is_on_the_asked_sides_only(self):
        for sides in (("S",), ("E", "N"), ("E", "N", "S", "W")):
            result = generate(relief_preset("sides", 128, 128, sea_sides=sides))
            self.assertIsNotNone(result["document"], result["reasons"])
            grid = cells(result["document"])
            edges = {"S": grid[0], "N": grid[-1], "W": [row[0] for row in grid], "E": [row[-1] for row in grid]}
            for side, edge in edges.items():
                sea = sum(c["water"] == "SEA" for c in edge)
                if side in sides:
                    self.assertEqual(len(edge), sea, "the %s edge is open sea" % side)
                else:
                    self.assertLess(sea, len(edge) // 2, "land runs to the %s edge" % side)

    def test_every_river_runs_down_to_water(self):
        doc = self.large["document"]
        grid, ids = cells(doc), {r["id"] for r in doc["rivers"]}
        lakes = {l["id"] for l in doc["lakes"]}
        for river in doc["rivers"]:
            self.assertIn(river["source"]["kind"], ("SPRING", "LAKE"))
            self.assertIn(river["sink"]["kind"], ("SEA", "LAKE", "RIVER"))
            if river["sink"]["kind"] == "RIVER":
                self.assertIn(river["sink"]["target"], ids - {river["id"]})
            if river["sink"]["kind"] == "LAKE":
                self.assertIn(river["sink"]["target"], lakes)
            heights = [grid[y][x]["elevation_m"] for x, y, _ in river["path"]]
            self.assertEqual(sorted(heights, reverse=True), heights, river["id"])
        self.assertTrue(any(r["sink"]["kind"] == "RIVER" for r in doc["rivers"]), "tributaries join larger rivers")
        self.assertTrue(any(r["sink"]["kind"] == "SEA" for r in doc["rivers"]))

    def test_islands_are_several_lands_each_with_a_start(self):
        result = generate(relief_preset("isles", 240, 240, islands=[4, 4]))
        self.assertIsNotNone(result["document"], result["reasons"])
        topology = result["manifest"]["generated_topology"]
        self.assertGreaterEqual(topology["lands"], 2)
        grid = cells(result["document"])
        self.assertTrue(all(c["water"] == "SEA" for c in grid[0] + grid[-1]))
        self.assertTrue(any(c["biome"] == "COAST" and c["water"] == "NONE" for row in grid for c in row))

    def test_a_spring_is_a_relief_source_only(self):
        doc = copy.deepcopy(self.small["document"])
        self.assertTrue(any(r["source"]["kind"] == "SPRING" for r in doc["rivers"]))
        sunk = copy.deepcopy(doc)
        next(r for r in sunk["rivers"] if r["source"]["kind"] == "SPRING")["sink"] = {"kind": "SPRING", "target": ""}
        self.assertTrue(validate(sunk), "a river cannot end in a spring")
        named = copy.deepcopy(doc)
        next(r for r in named["rivers"] if r["source"]["kind"] == "SPRING")["source"]["target"] = "lake-1"
        self.assertTrue(validate(named))
        doc["schema"] = PORT_VERSION
        doc["junctions"] = []
        self.assertTrue(validate(doc), "other schemas keep their edge-port grammar")

    def test_a_gaia_size_land_generates(self):
        result = generate(relief_preset("gaia-size", 500, 350, sea_sides=("S", "W")))
        self.assertIsNotNone(result["document"], result["reasons"])
        topology = result["manifest"]["generated_topology"]
        self.assertGreater(topology["rivers"], 20)
        self.assertGreater(topology["starts"], 20)


class ReliefLandTests(unittest.TestCase):
    def test_every_land_type_takes_its_shape(self):
        flat = land.land_config(template("GRASSLAND", "COASTAL_PLAIN", 200, 200, ridges=0))["relief_layout"]
        high = land.land_config(template("GRASSLAND", "HIGHLANDS", 200, 200))["relief_layout"]
        marsh = land.land_config(template("GRASSLAND", "MARSH", 200, 200))["relief_layout"]
        fjord = land.land_config(template("GRASSLAND", "FJORD_COAST", 200, 200))["relief_layout"]
        self.assertEqual([0, 0], flat["mountain_pct"])
        self.assertGreater(high["mountain_pct"][0], 5)
        self.assertGreater(marsh["swamp_pct"][0], 0)
        self.assertEqual(3, fjord["coast_roughness"])
        dry = land.land_config(template("DESERT", "COASTAL_PLAIN", 200, 200))["relief_layout"]
        wet = land.land_config(template("GRASSLAND", "COASTAL_PLAIN", 200, 200))["relief_layout"]
        self.assertLess(dry["river_permille"][1], wet["river_permille"][0])

    def test_every_coast_side_of_the_template_is_open_sea(self):
        c = land.land_config(template("GRASSLAND", "COASTAL_PLAIN", 200, 200, coast=("W", "N", "W")))
        self.assertEqual(["N", "W"], c["relief_layout"]["sea_sides"])
        self.assertEqual("MAINLAND", c["relief_layout"]["form"])
        isles = land.land_config(template("GRASSLAND", "ARCHIPELAGO", 200, 200, coast=("E",)))
        self.assertEqual("ISLANDS", isles["relief_layout"]["form"])

    def test_larger_island_lands_have_more_islands(self):
        small = land.island_count(template("GRASSLAND", "ARCHIPELAGO", 200, 200))
        large = land.island_count(template("GRASSLAND", "ARCHIPELAGO", 690, 690))
        tiny = land.island_count(template("GRASSLAND", "ARCHIPELAGO", 64, 64))
        self.assertGreater(large[0], small[1])
        self.assertLessEqual(tiny[1], 2)
        for t in (template("GRASSLAND", "ARCHIPELAGO", 64, 64), template("DESERT", "VOLCANIC_ISLE", 64, 90)):
            self.assertEqual([], validate_config(land.land_config(t)))

    def test_marsh_and_island_lands_generate(self):
        for t in (template("SWAMP", "MARSH", 128, 128), template("RAINFOREST", "ARCHIPELAGO", 160, 160, coast=("E", "S")),
                  template("ICE_SHEET", "FJORD_COAST", 128, 128, coast=("N", "W"), ridges=3)):
            result = generate(land.land_config(t))
            self.assertIsNotNone(result["document"], (t["land_type"], result["reasons"]))
        marsh = census(generate(land.land_config(template("SWAMP", "MARSH", 128, 128)))["document"])
        self.assertGreater(marsh.get("SWAMP", 0), 100)


GOLDEN_96 = "8d69b8791964c09a4571b8afdcbe6222c60a2161dd3aa700bd362de1a6c0df1e"

if __name__ == "__main__":
    unittest.main()
