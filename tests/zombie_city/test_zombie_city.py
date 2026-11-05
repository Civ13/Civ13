"""Offline checks for the zombie city generator sources and base map.

They regenerate the blank base map and compare it with the checked-in DMM,
check that every turf and object type the generator and its interiors place
exists in the source tree, that the generator modules are included in civ13.dme, that the
loot table and density names match the horde and loot contracts, and that
the evidence checker's grid functions behave on small fixtures. They never
run BYOND; the headless probe (native_probe.py) is the generation evidence.

Run from the repository root:
    python3 -I -B -m unittest tests/zombie_city/test_zombie_city.py
"""
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_base  # noqa: E402
import check  # noqa: E402

MODULE = ROOT / "code/modules/zombie_city"
GENERATOR = MODULE / "generator.dm"
INTERIORS = MODULE / "interiors.dm"
LEVELS = MODULE / "levels.dm"
DME = ROOT / "civ13.dme"
TYPE_PATH = re.compile(r"(?<![\w/])(/(?:turf|obj|area)/[\w/]+)")
DEFINITION_PREFIXES = ("/turf/", "/obj/", "/area/")


def defined_types():
    """Every type path declared at the start of a line in a .dm file."""
    found = set()
    for path in ROOT.glob("code/**/*.dm"):
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            if line.startswith(DEFINITION_PREFIXES):
                found.add(line.split("//")[0].split("(")[0].split("/New")[0].split("/proc")[0].strip())
    return found


class BaseMapTest(unittest.TestCase):
    def test_checked_in_base_map_matches_builder(self):
        self.assertEqual(build_base.MAP_PATH.read_text(encoding="utf-8"), build_base.build())

    def test_base_map_shape(self):
        text = build_base.build()
        rows = text.split('(1,1,1) = {"\n')[1].split('"}')[0].split("\n")
        rows = [row for row in rows if row]
        self.assertEqual(len(rows), build_base.HEIGHT)
        self.assertTrue(all(len(row) == build_base.WIDTH for row in rows))
        self.assertTrue(all(row[0] == row[-1] == "b" for row in rows[:-1]))
        self.assertEqual(rows[-1][0], "c")
        self.assertEqual(set(rows[0]), {"b"})
        upper = text.split('(1,1,2) = {"\n')[1].split('"}')[0].split("\n")
        upper = [row for row in upper if row]
        self.assertEqual(len(upper), build_base.HEIGHT)
        self.assertEqual(set("".join(upper)), {"d"})
        self.assertNotIn('(1,1,3)', text)


class SourceTest(unittest.TestCase):
    def test_generator_files_are_included(self):
        dme = DME.read_text(encoding="utf-8-sig")
        for name in ("generator.dm", "interiors.dm", "levels.dm", "map.dm", "markers.dm", "rng.dm", "horde.dm", "loot.dm"):
            self.assertIn(f'#include "code\\modules\\zombie_city\\{name}"', dme)

    def test_placed_types_exist(self):
        existing = defined_types()
        source = GENERATOR.read_text(encoding="utf-8") + INTERIORS.read_text(encoding="utf-8") + LEVELS.read_text(encoding="utf-8")
        used = set(TYPE_PATH.findall(source))
        self.assertGreater(len(used), 50)
        missing = sorted(path for path in used if path not in existing)
        self.assertEqual(missing, [])

    def test_contract_names_match_consumers(self):
        source = GENERATOR.read_text(encoding="utf-8") + INTERIORS.read_text(encoding="utf-8") + LEVELS.read_text(encoding="utf-8")
        horde = (MODULE / "horde.dm").read_text(encoding="utf-8")
        loot = (MODULE / "loot.dm").read_text(encoding="utf-8")
        for density in re.findall(r'"(sparse|normal|dense|infested)"', source):
            self.assertIn(f'"{density}"', horde)
        for table in ("residential", "grocery", "pharmacy", "hardware", "police", "garage", "military", "medical"):
            self.assertIn(f'"{table}"', loot)
            self.assertIn(f'"{table}"', source)
        self.assertIn("zombie_horde_add_block(", source)
        self.assertIn("zombie_city_roll_loot(", source)
        self.assertIn("zombie_city_add_insertion(", source)
        self.assertIn("zombie_city_add_evacuation(", source)
        code = "\n".join(line.split("//")[0] for line in source.splitlines())
        self.assertEqual(re.findall(r"(?<![\w.])(?:rand|prob|pick|shuffle)\(", code), [])

    def test_metadata_opts_in(self):
        map_source = (MODULE / "map.dm").read_text(encoding="utf-8")
        self.assertIn("var/zombie_city = TRUE", map_source)
        self.assertIn("ID = MAP_ZOMBIE_CITY", map_source)
        self.assertIn('#define MAP_ZOMBIE_CITY "ZOMBIE_CITY"', (ROOT / "code/__defines/maps.dm").read_text(encoding="utf-8"))

    def test_room_kinds_have_furniture_and_fill(self):
        source = INTERIORS.read_text(encoding="utf-8")
        kinds_block = source.split("proc/room_kinds")[1].split("proc/room_furniture")[0]
        kinds = set(re.findall(r'"([a-z]+)"', kinds_block)) - {"house", "apartment", "office", "hospital", "police", "room"}
        furniture_block = source.split("proc/room_furniture")[1].split("proc/room_fill")[0]
        furnished = set(re.findall(r'if \(([^)]*)\)', furniture_block))
        furnished = set(re.findall(r'"([a-z]+)"', " ".join(furnished)))
        self.assertEqual(sorted(kinds - furnished), [])
        for marker in ("ZC_WALL_INNER", "ZC_DOOR_INNER", "ZC_WINDOW_BROKEN"):
            self.assertIn(marker, GENERATOR.read_text(encoding="utf-8"))


class CheckerTest(unittest.TestCase):
    GRID = [
        "###########",
        "#E==.WwWwW#",
        "#===.DfWfL#",
        "#===.WWWDW#",
        "#=V=.......",
        "###########",
    ]

    def test_reachability_passes_on_open_fixture(self):
        result = check.reachability(self.GRID)
        self.assertEqual(result["entries"], 1)
        self.assertEqual(result["required"], 5)
        self.assertEqual(result["unreachable"], {})

    def test_broken_window_is_passable_and_glass_is_not(self):
        rows = list(self.GRID)
        rows[3] = "#===.WWWWW#"
        rows[2] = "#===.DfofL#"
        self.assertEqual(check.reachability(rows)["unreachable"], {})
        rows[2] = "#===.DfwfL#"
        self.assertEqual(sum(check.reachability(rows)["unreachable"].values()), 1)

    def test_reachability_reports_sealed_loot(self):
        rows = list(self.GRID)
        rows[2] = "#===.WfWfL#"
        rows[3] = "#===.WWWWW#"
        result = check.reachability(rows)
        self.assertEqual(sum(result["unreachable"].values()), 1)

    def test_spacing_and_counts(self):
        manifest = {"entries": [{"x": 3, "y": 198}, {"x": 50, "y": 198}], "exits": [{"x": 3, "y": 3, "checkpoint": True}],
                    "blocks": [], "buildings": [], "pois": {}}
        self.assertTrue(any("closer" in p for p in check.spacing(manifest)))
        problems = check.counts(manifest)
        self.assertTrue(any("entries" in p for p in problems))
        self.assertTrue(any("hospital" in p for p in problems))

    def test_rooms_fit_and_hold_loot(self):
        building = {"id": 1, "x1": 10, "y1": 10, "x2": 20, "y2": 20, "loot": [{"x": 12, "y": 12}],
                    "rooms": [{"kind": "bedroom", "x1": 11, "y1": 11, "x2": 14, "y2": 14}]}
        self.assertEqual(check.rooms({"buildings": [building]}), [])
        building["rooms"].append({"kind": "hall", "x1": 15, "y1": 11, "x2": 16, "y2": 19})
        self.assertEqual(check.rooms({"buildings": [building]}), [])
        building["rooms"][0]["x2"] = 12
        building["loot"].append({"x": 18, "y": 18})
        problems = check.rooms({"buildings": [building]})
        self.assertTrue(any("smaller" in p for p in problems))
        self.assertTrue(any("not in a room" in p for p in problems))
        building["rooms"][0]["x1"] = 10
        self.assertTrue(any("outside" in p for p in check.rooms({"buildings": [building]})))

    def test_upper_level_reachable_from_stairs(self):
        ground = [
            "###########",
            "#E==.WwWwW#",
            "#===.DfSfW#",
            "#===.WWWWW#",
            "#=V=.......",
            "###########",
        ]
        upper = [
            "~~~~~~~~~~~",
            "~~~~~WwWwW~",
            "~~~~~WffDL~",
            "~~~~~WWWWW~",
            "~~~~~~~~~~~",
            "~~~~~~~~~~~",
        ]
        self.assertEqual(check.reachability(ground)["unreachable"], {})
        result = check.upper_reachability(ground, upper)
        self.assertEqual(result["entries"], 1)
        self.assertEqual(result["required"], 2)
        self.assertEqual(result["unreachable"], {})
        upper[2] = "~~~~~WffWL~"
        self.assertEqual(check.upper_reachability(ground, upper)["unreachable"], {"all stairs": ["column 10 row 4"]})
        with self.assertRaises(ValueError):
            check.upper_reachability(ground, upper[:-1])

    def test_ragged_grid_rejected(self):
        with self.assertRaises(ValueError):
            check.parse_grid("###\n##\n")


if __name__ == "__main__":
    unittest.main()
