"""Hill, current and flood files of a generated land: the game reads all three
and leaves a map flat, still or dry when one is malformed."""
import tempfile
import unittest
from pathlib import Path

from tools.procedural_maps import land, terrain_files
from tools.procedural_maps.generator import generate
from tools.procedural_maps.playable import playable_layout

STEPS = {"n": (0, 1), "e": (1, 0), "s": (0, -1), "w": (-1, 0), "a": (1, 1), "b": (1, -1), "c": (-1, -1), "d": (-1, 1)}


def template(land_type="HIGHLANDS", size=128, coast=("S", "W")):
    return {"biome": "TEMPERATE_FOREST", "land_type": land_type, "size": "TINY", "width": size, "height": size,
            "coast": list(coast), "seed": "terrain-test:1", "features": {"ridges": 1},
            "resources": {"ore": "fair", "ores": [], "rare": [], "fertility": "fair", "game": []}}


class TerrainFileTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.doc = generate(land.land_config(template(), 0))["document"]
        cls.layout, _ = playable_layout(cls.doc, "native")
        cls.tmp = tempfile.TemporaryDirectory()
        cls.folder = Path(cls.tmp.name)
        cls.summary = terrain_files.write_terrain_files(cls.folder, cls.doc, cls.layout)
        cls.heights_script, cls.flow_script, cls.flood_script = terrain_files._scripts()
        cls.cells = cls.doc["layers"]["SURFACE"]["cells"]

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_water_is_level_and_the_ground_climbs_out_of_it_by_small_steps(self):
        levels = terrain_files.land_levels(self.doc)
        size = self.doc["width"]
        highest = 0
        for y in range(size):
            for x in range(size):
                wet = self.cells[y][x]["terrain"] == "WATER"
                self.assertEqual(wet, levels[y][x] == 0, (x, y))
                highest = max(highest, levels[y][x])
                for nx, ny in ((x + 1, y), (x, y + 1)):
                    if nx < size and ny < size:
                        self.assertLessEqual(abs(levels[y][x] - levels[ny][nx]), terrain_files.MAX_NEIGHBOUR_STEP, (x, y))
                        if wet:
                            self.assertLessEqual(levels[ny][nx], terrain_files.BANK_STEP, (x, y))
        self.assertLessEqual(highest, terrain_files.SUMMIT)
        self.assertGreaterEqual(highest, 16, "highlands rise at least eight levels")

    def test_the_height_file_is_one_the_game_reads(self):
        width, height, by_z = self.heights_script.read_heights(self.folder / terrain_files.HEIGHTS_FILE)
        self.assertEqual((self.doc["width"], self.doc["height"], [2]), (width, height, sorted(by_z)))
        levels = terrain_files.land_levels(self.doc)
        # The file's first row is the north row.
        self.assertEqual([v / 2 for v in levels[-1]], list(by_z[2][0]))
        self.assertEqual(self.summary["highest_level"], max(max(row) for row in by_z[2]))

    def test_currents_run_down_the_generated_rivers(self):
        lines = (self.folder / terrain_files.FLOW_FILE).read_text(encoding="ascii").split("\n")
        size = self.doc["width"]
        self.assertEqual(["civ13-river-flow 1", "size %d %d" % (size, size), "z 2"], lines[:3])
        rows = lines[3:3 + size]
        self.assertTrue(all(len(row) == size and not set(row) - set(".neswabcd") for row in rows))
        along = against = 0
        for river in self.doc["rivers"]:
            for a, b in zip(river["path"], river["path"][1:]):
                code = rows[size - 1 - a[1]][a[0]]
                if code == ".":
                    continue
                dx, dy = STEPS[code]
                dot = dx * (b[0] - a[0]) + dy * (b[1] - a[1])
                along += dot > 0
                against += dot < 0
        self.assertGreater(along, 100)
        self.assertLessEqual(against * 50, along, "at most a stray tile in fifty runs upstream")
        self.assertEqual(self.summary["flowing_tiles"], sum(c != "." for row in rows for c in row))

    def test_flood_reaches_drain_downstream_and_cover_the_banks(self):
        width, height, z, reaches, labels, thresholds = self.flood_script.read_flood(self.folder / terrain_files.FLOOD_FILE)
        self.assertEqual((self.doc["width"], self.doc["height"], 2), (width, height, z))
        self.assertEqual(self.summary["flood_reaches"], len(reaches))
        self.assertGreater(len(reaches), 3)
        for reach in reaches:
            self.assertTrue(reach["down"] == 0 or reach["down"] > reach["id"], reach)
        size = self.doc["width"]
        for y in range(size):
            for x in range(size):
                if self.cells[size - 1 - y][x]["terrain"] == "WATER":
                    self.assertIsNone(thresholds[y][x], (x, y))
        hollows, ids = self.flood_script.read_hollows(self.folder / terrain_files.FLOOD_FILE)
        self.assertEqual(self.summary["hollows"], len(hollows))
        self.assertEqual((size, size), (len(ids), len(ids[0])))
        text = (self.folder / terrain_files.FLOOD_FILE).read_text(encoding="ascii")
        self.assertTrue(text.startswith(self.flood_script.HEADER + "\n"), "the version the game reads now")
        self.assertIn("\nhollows %d\n" % len(hollows), text)
        banks = sum(v is not None and v <= 2 for row in thresholds for v in row)
        self.assertGreater(banks, 200, "low ground by the rivers floods first")

    def test_a_land_folder_holds_the_three_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            report = land.build_land(template("COASTAL_PLAIN", 96, ("S",)), Path(tmp) / "one")
            again = land.build_land(template("COASTAL_PLAIN", 96, ("S",)), Path(tmp) / "two")
            for name in (terrain_files.HEIGHTS_FILE, terrain_files.FLOW_FILE, terrain_files.FLOOD_FILE):
                first = (Path(tmp) / "one" / name).read_bytes()
                self.assertEqual(first, (Path(tmp) / "two" / name).read_bytes(), name)
                self.assertNotIn(b"\r", first)
            self.assertEqual(report["terrain"], again["terrain"])
            self.assertEqual(2, report["terrain"]["z"])
            self.assertGreater(report["terrain"]["flood_tiles"], 0)


if __name__ == "__main__":
    unittest.main()
