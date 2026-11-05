import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from tools.procedural_maps import playable
from tools.procedural_maps.bundle import write_bundle
from tools.procedural_maps.configuration import barren_surface_preset, oceanic_preset, port_surface_preset, preset, validate_config
from tools.procedural_maps.dmm_export import project
from tools.procedural_maps.generator import generate
from tools.procedural_maps.source_audit import parse_classic


def cavern_config():
    c = preset("UNDERGROUND_CAVERN", "cave-0")
    c["dimensions"].update(width=64, height=80)
    c["starts"]["count"] = 4
    return c


def bundle(config, folder):
    r = generate(config)
    if r["document"] is None:
        raise AssertionError(r["reasons"])
    write_bundle(folder, r["document"], r["manifest"], preview=False, fresh=True)
    return r["document"]


class PlayableLayerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        root = Path(cls.tmp.name)
        cls.docs, cls.folders = {}, {}
        for name, config in (("surface", port_surface_preset("pilot-0", 64, 80)),
                             ("oceanic", oceanic_preset()),
                             ("cavern", cavern_config())):
            cls.folders[name] = root / name
            cls.folders[name].mkdir()
            cls.docs[name] = bundle(config, cls.folders[name])
        cls.built = {name: playable.build(folder) for name, folder in cls.folders.items()}

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def layout(self, name):
        _, parsed, _ = parse_classic(self.built[name][0])
        return parsed

    def test_build_is_deterministic_and_reported(self):
        for name, folder in self.folders.items():
            text, report = playable.build(folder)
            self.assertEqual(self.built[name][0], text)
            self.assertEqual(hashlib.sha256(text.encode()).hexdigest(), report["dmm_sha256"])
            self.assertEqual(hashlib.sha256((folder / "map.dmm").read_bytes()).hexdigest(), report["bundle_dmm_sha256"])
            self.assertEqual(playable.SUPPLY_VERSION, report["supply_version"])

    def test_offline_layout_is_kept_under_the_supplies(self):
        for name, doc in self.docs.items():
            base, parsed = project(doc), self.layout(name)
            self.assertEqual(set(base), set(parsed))
            for key, recipe in base.items():
                atoms = recipe.split(",")
                if playable.SOLID_ROCK_TURF in atoms and playable.CAVE_FLOOR_TURF in parsed[key].split(","):
                    atoms[atoms.index(playable.SOLID_ROCK_TURF)] = playable.CAVE_FLOOR_TURF
                if playable.METADATA in atoms:
                    atoms[atoms.index(playable.METADATA)] = playable.metadata_atom(playable.elevation_profile(doc))
                self.assertTrue(parsed[key].endswith(",".join(atoms)), (name, key))

    def test_generated_maps_carry_their_relief(self):
        for name, doc in self.docs.items():
            profile = playable.elevation_profile(doc)
            self.assertEqual(0, profile["dropped"], name)
            self.assertLessEqual(len(profile["regions"]), playable.MAX_ELEVATION_REGIONS)
            assert_profile_exact(self, doc, profile)
            text, report = self.built[name]
            self.assertEqual(len(profile["regions"]), report["elevation"]["regions"])
            self.assertIn(playable.metadata_atom(profile), text)
        surface = playable.elevation_profile(self.docs["surface"])
        self.assertTrue(any(r["metres"] >= 400 for r in surface["regions"]), "mountains reach the profile")
        cavern = playable.elevation_profile(self.docs["cavern"])
        self.assertEqual([{"x1": 1, "x2": 64, "y1": 1, "y2": 80, "z": 1, "metres": -40}], cavern["regions"])

    def test_start_cells_stay_clear(self):
        for name, doc in self.docs.items():
            base, parsed = project(doc), self.layout(name)
            for x, y, layer in doc["starts"]:
                key = (x + 1, y + 1, doc["layers"][layer]["native_z"])
                # Only a cave start's turf changes, to open floor.
                self.assertEqual(base[key].replace(playable.SOLID_ROCK_TURF + ",", playable.CAVE_FLOOR_TURF + ","), parsed[key])

    def test_surface_sites_become_native_supplies(self):
        doc, parsed = self.docs["surface"], self.layout("surface")
        cells = doc["layers"]["SURFACE"]["cells"]
        stone = [(x, y) for y, row in enumerate(cells) for x, c in enumerate(row)
                 if c["resource"] == "STONE" and c["tree"] == "NONE" and [x, y, "SURFACE"] not in doc["starts"]]
        self.assertTrue(stone)
        for x, y in stone:
            self.assertTrue(parsed[(x + 1, y + 1, 2)].startswith(playable.ROCK + ","))
        report = self.built["surface"][1]["supplies"]
        for kind in (playable.ROCK, playable.BUSH, playable.TALL_GRASS):
            self.assertGreater(report.get(kind, 0), 0, kind)

    def test_cavern_floors_open_and_exits_become_ladders(self):
        doc, parsed = self.docs["cavern"], self.layout("cavern")
        cells = doc["layers"]["UNDERGROUND"]["cells"]
        for y, row in enumerate(cells):
            for x, c in enumerate(row):
                atoms = parsed[(x + 1, y + 1, 1)].split(",")
                if c["terrain"] == "CAVE_FLOOR" and c["water"] == "NONE":
                    self.assertIn(playable.CAVE_FLOOR_TURF, atoms)
                    self.assertNotIn(playable.SOLID_ROCK_TURF, atoms)
                elif c["terrain"] == "ROCK":
                    self.assertIn(playable.SOLID_ROCK_TURF, atoms)
        for (x, y) in {(p["a"][0], p["a"][1]) for p in doc["portals"]}:
            area = 'area_id = "generated-%d-%d"' % (x, y)
            self.assertIn(playable.LADDER_UP + "{" + area + "}", parsed[(x + 1, y + 1, 1)])
            self.assertIn(playable.LADDER_DOWN + "{" + area + "}", parsed[(x + 1, y + 1, 2)])
        self.assertEqual(len(doc["portals"]), self.built["cavern"][1]["ladder_pairs"])
        self.assertGreater(len(doc["portals"]), 0)

    def test_food_sites_give_food_and_cave_trees_give_wood(self):
        doc, parsed = self.docs["surface"], self.layout("surface")
        food = [(x, y) for y, row in enumerate(doc["layers"]["SURFACE"]["cells"]) for x, c in enumerate(row)
                if c["resource"] == "FOOD" and c["water"] == "NONE" and not c["blocked"] and c["tree"] == "NONE"
                and c["terrain"] not in {"MOUNTAIN", "ROCK"} and [x, y, "SURFACE"] not in doc["starts"]]
        self.assertTrue(food)
        for x, y in food:
            self.assertTrue(parsed[(x + 1, y + 1, 2)].startswith(playable.BERRY_BUSH + ","))
        # Coastal FOOD sites too: the jungle bush gives herbs, not food.
        self.assertEqual([playable.BERRY_BUSH], playable.surface_supply(
            {"water": "NONE", "terrain": "BEACH", "blocked": False, "tree": "NONE",
             "resource": "FOOD", "biome": "COAST", "soil": "SAND"}, 0.5, 0.9))
        wood = playable.cavern_supply({"terrain": "CAVE_FLOOR", "water": "NONE", "tree": "NONE", "resource": "WOOD"}, 0.5)
        self.assertEqual([playable.DEAD_TREE_ATOM], wood)
        self.assertEqual("/obj/structure/wild/tree/dead_tree", playable.DEAD_TREE)
        self.assertIn("density = 0", wood[0])

    def test_misaligned_portal_pair_is_refused(self):
        doc = dict(self.docs["cavern"])
        pair = doc["portals"][0]
        moved = dict(pair, b=[pair["b"][0] + 1] + list(pair["b"][1:]))
        doc["portals"] = [moved] + doc["portals"][1:]
        with self.assertRaisesRegex(ValueError, "PLAYABLE_PORTAL_ALIGNMENT"):
            playable.playable_layout(doc)

    def test_water_and_blocked_cells_get_no_land_supplies(self):
        for name, doc in self.docs.items():
            parsed = self.layout(name)
            for layer, level in doc["layers"].items():
                z = level["native_z"]
                for y, row in enumerate(level["cells"]):
                    for x, c in enumerate(row):
                        atoms = parsed[(x + 1, y + 1, z)].split(",")
                        if c["water"] != "NONE":
                            self.assertFalse({playable.ROCK, playable.BUSH, playable.TALL_GRASS} & set(atoms))
                        if c["terrain"] in {"MOUNTAIN", "ROCK"}:
                            self.assertFalse({playable.ROCK, playable.BUSH, playable.TALL_GRASS, playable.FISH} & set(atoms))

    def test_types_exist_in_source_and_missing_type_is_refused(self):
        self.assertTrue(playable.verify_types())
        original = dict(playable.SOURCES)
        try:
            playable.SOURCES["/obj/structure/wild/not_a_real_bush"] = "code/game/objects/structures/wild.dm"
            with self.assertRaisesRegex(ValueError, "SUPPLY_TYPE_MISSING"):
                playable.verify_types()
        finally:
            playable.SOURCES.clear()
            playable.SOURCES.update(original)

    def test_write_refuses_existing_output_and_needs_dmm_suffix(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "region.dmm"
            result = playable.write(self.folders["oceanic"], out)
            self.assertEqual(self.built["oceanic"][0], out.read_text(encoding="utf-8"))
            self.assertTrue(Path(result["report"]).exists())
            with self.assertRaisesRegex(ValueError, "output exists"):
                playable.write(self.folders["oceanic"], out)
            with self.assertRaisesRegex(ValueError, "must end in .dmm"):
                playable.write(self.folders["oceanic"], Path(tmp) / "region.txt")

    def test_tampered_bundle_is_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp) / "b"
            folder.mkdir()
            bundle(port_surface_preset("pilot-0", 64, 80), folder)
            (folder / "map.dmm").write_text((folder / "map.dmm").read_text(encoding="utf-8") + "\n", encoding="utf-8")
            with self.assertRaises(ValueError):
                playable.build(folder)


if __name__ == "__main__":
    unittest.main()


def flat_doc(width, height, surface, underground=None):
    """A minimal IR with only elevations; rows are IR order (row zero south)."""
    def level(z, grid):
        return {"native_z": z, "cells": [[{"elevation_m": v} for v in row] for row in grid]}
    underground = underground or [[0] * width for _ in range(height)]
    return {"layers": {"SURFACE": level(2, surface), "UNDERGROUND": level(1, underground)}}


def covered(profile, x, y, z):
    hits = [r for r in profile["regions"] if r["z"] == z and r["x1"] <= x <= r["x2"] and r["y1"] <= y <= r["y2"]]
    return hits


def assert_profile_exact(case, doc, profile):
    step = profile["step_m"]
    for level in doc["layers"].values():
        for y, row in enumerate(level["cells"]):
            for x, c in enumerate(row):
                hits = covered(profile, x + 1, y + 1, level["native_z"])
                case.assertLessEqual(len(hits), 1)
                want = int(round(c["elevation_m"] / step)) * step
                case.assertEqual(want, hits[0]["metres"] if hits else profile["default_metres"], (x, y))


class ElevationProfileTests(unittest.TestCase):
    def assert_exact(self, doc, profile):
        assert_profile_exact(self, doc, profile)

    def test_rings_merge_into_rectangles(self):
        grid = [[0] * 8 for _ in range(6)]
        for y in range(1, 5):
            for x in range(2, 6):
                grid[y][x] = 100
        grid[2][3] = grid[2][4] = grid[3][3] = grid[3][4] = 200
        doc = flat_doc(8, 6, grid)
        profile = playable.elevation_profile(doc)
        self.assert_exact(doc, profile)
        # Bottom row, top row, and the two middle rows merged as left edge, peak, right edge.
        self.assertEqual(5, len(profile["regions"]))
        self.assertEqual(0, profile["default_metres"])

    def test_default_is_the_most_common_band(self):
        doc = flat_doc(4, 4, [[300] * 4 for _ in range(4)], [[300] * 4 for _ in range(4)])
        profile = playable.elevation_profile(doc)
        self.assertEqual(300, profile["default_metres"])
        self.assertEqual([], profile["regions"])
        self.assertEqual("/obj/map_metadata/nomads{elevation_default_metres = 300; elevation_lapse_c_per_km = 6.5}",
                         playable.metadata_atom(profile))

    def test_default_band_needs_fewest_rectangles(self):
        # A uniform -40 m cave plane outnumbers the surface's sea level, but
        # choosing it would need a rectangle per surface row; sea level does not.
        surface = [[0, 150, 0, 150] if y % 2 else [150, 0, 150, 0] for y in range(8)]
        surface[0] = [0, 0, 0, 0]
        cave = [[-40] * 4 for _ in range(8)]
        for row in surface[1:]:
            row[:] = [0, 0, 150, 0]
        doc = flat_doc(4, 8, surface, cave)
        profile = playable.elevation_profile(doc)
        self.assertEqual(1, profile["step_m"])
        self.assertEqual(0, profile["default_metres"])
        self.assertEqual(2, len(profile["regions"]))
        self.assert_exact(doc, profile)

    def test_coarser_bands_then_largest_rectangles_fit_the_cap(self):
        # A 40x40 checkerboard of 0/20 m needs 800 single-tile regions at 1 m,
        # but rounds to flat at 50 m bands.
        board = [[20 * ((x + y) % 2) for x in range(40)] for y in range(40)]
        profile = playable.elevation_profile(flat_doc(40, 40, board))
        self.assertEqual(50, profile["step_m"])
        self.assertEqual([], profile["regions"])
        # 0/2000 m cannot be rounded away, so only the largest 256 are kept.
        board = [[2000 * ((x + y) % 2) for x in range(40)] for y in range(40)]
        profile = playable.elevation_profile(flat_doc(40, 40, board))
        self.assertEqual(1000, profile["step_m"])
        self.assertEqual(playable.MAX_ELEVATION_REGIONS, len(profile["regions"]))
        self.assertEqual(800 - 256, profile["dropped"])

    def test_text_form_stays_inside_one_tile_definition(self):
        doc = flat_doc(5, 3, [[0, 120, 120, 0, -40]] * 3)
        profile = playable.elevation_profile(doc)
        text = playable.elevation_text(profile)
        self.assertNotIn(",", text)
        self.assertNotIn(";", text)
        self.assertNotIn('"', text)
        rows = [dict(zip(("x1", "x2", "y1", "y2", "z", "metres"), map(int, row.split(" ")))) for row in text.split("|")]
        self.assertEqual(profile["regions"], rows)

    def test_lapse_is_bounded_and_zero_leaves_climate_alone(self):
        doc = flat_doc(3, 3, [[0, 500, 0]] * 3)
        for bad in (-1, 10.5, True, "6.5"):
            with self.assertRaises(ValueError):
                playable.elevation_profile(doc, bad)
        self.assertNotIn("lapse", playable.metadata_atom(playable.elevation_profile(doc, 0)))
        self.assertIn("elevation_lapse_c_per_km = 6.5", playable.metadata_atom(playable.elevation_profile(doc)))
        self.assertEqual("/obj/map_metadata/nomads", playable.metadata_atom(playable.elevation_profile(flat_doc(3, 3, [[0] * 3] * 3))))


class BarrenSkinTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        root = Path(cls.tmp.name)
        cls.folder = root / "barren"
        cls.folder.mkdir()
        cls.doc = bundle(barren_surface_preset("barren-t", 64, 80), cls.folder)
        cls.text, cls.report = playable.build(cls.folder, skin="barren")
        _, cls.parsed, _ = parse_classic(cls.text)
        cls.cave = root / "cavern"
        cls.cave.mkdir()
        bundle(cavern_config(), cls.cave)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_barren_preset_is_dry_cold_and_bare(self):
        c = barren_surface_preset("barren-t", 64, 80)
        self.assertEqual([], validate_config(c))
        self.assertEqual({"DESERT": 70, "ARID": 30}, c["biome_mix_pct"])
        self.assertEqual([0, 0], c["vegetation"]["suitable_site_density_pct"])
        self.assertLessEqual(c["climate"]["temperature_c_range"][1], -10)

    def test_build_is_deterministic_and_reports_the_skin(self):
        text, report = playable.build(self.folder, skin="barren")
        self.assertEqual(self.text, text)
        self.assertEqual("barren", report["skin"])
        self.assertEqual("native", playable.build(self.folder)[1]["skin"])
        self.assertNotEqual(self.text, playable.build(self.folder)[0])

    def test_surface_cells_become_barren_ground(self):
        cells = self.doc["layers"]["SURFACE"]["cells"]
        seen = set()
        for y, row in enumerate(cells):
            for x, c in enumerate(row):
                atoms = self.parsed[(x + 1, y + 1, 2)].split(",")
                self.assertEqual(playable.BARREN_AREA, atoms[-1])
                turf = [a for a in atoms if a.startswith("/turf/")]
                self.assertEqual(1, len(turf))
                if c["water"] in {"LAKE", "SEA"}:
                    expected = playable.BARREN_ICE
                elif c["water"] in {"RIVER", "SWAMP"}:
                    expected = playable.BARREN_CHANNEL
                elif c["terrain"] in {"MOUNTAIN", "ROCK"}:
                    expected = "/turf/floor/dirt/underground"
                    self.assertIn("/obj/structure/wild/rock/basalt", atoms)
                else:
                    expected = playable.BARREN_GROUND
                self.assertEqual(expected, turf[0], (x, y, c))
                seen.add(expected)
        self.assertEqual({playable.BARREN_ICE, playable.BARREN_CHANNEL, playable.BARREN_GROUND,
                          "/turf/floor/dirt/underground"}, seen)

    def test_nothing_lives_or_grows_and_stone_sites_keep_rocks(self):
        living = set(playable.SURFACE_TREES) | {playable.BUSH, playable.BERRY_BUSH, playable.TALL_GRASS,
                                                playable.FISH, playable.TURKEYS, playable.BOARS,
                                                playable.DEAD_TREE, playable.MUSHROOM, playable.MUSHROOM_SEEDS}
        for recipe in set(self.parsed.values()):
            for atom in recipe.split(","):
                self.assertNotIn(atom.split("{")[0], living, recipe)
        self.assertEqual({playable.ROCK}, set(self.report["supplies"]))
        cells = self.doc["layers"]["SURFACE"]["cells"]
        stone = [(x, y) for y, row in enumerate(cells) for x, c in enumerate(row)
                 if c["resource"] == "STONE" and [x, y, "SURFACE"] not in self.doc["starts"]]
        self.assertTrue(stone)
        for x, y in stone:
            self.assertTrue(self.parsed[(x + 1, y + 1, 2)].startswith(playable.ROCK + ","))
        self.assertEqual(len(stone), self.report["supplies"][playable.ROCK])

    def test_starts_and_reserve_plane_are_kept(self):
        for x, y, layer in self.doc["starts"]:
            self.assertIn('name = "JoinLateCiv"', self.parsed[(x + 1, y + 1, 2)])
        for (x, y, z), recipe in self.parsed.items():
            if z == 1:
                self.assertTrue(recipe.endswith("/area/caribbean/void/caves"), recipe)

    def test_barren_types_are_checked_and_bad_skins_refused(self):
        self.assertTrue(playable.verify_types(skin="barren"))
        with self.assertRaisesRegex(ValueError, "PLAYABLE_SKIN"):
            playable.verify_types(skin="lunar")
        with self.assertRaisesRegex(ValueError, "PLAYABLE_SKIN_PROFILE"):
            playable.build(self.cave, skin="barren")
        with self.assertRaisesRegex(ValueError, "PLAYABLE_SKIN"):
            playable.build(self.folder, skin="lunar")
        original = dict(playable.BARREN_SOURCES)
        try:
            playable.BARREN_SOURCES["/turf/floor/dirt/dust/regolith/not_real"] = "code/modules/space/barren_world.dm"
            with self.assertRaisesRegex(ValueError, "SUPPLY_TYPE_MISSING"):
                playable.verify_types(skin="barren")
        finally:
            playable.BARREN_SOURCES.clear()
            playable.BARREN_SOURCES.update(original)

    def test_cli_barren_preset_and_skin(self):
        from tools.procedural_maps.__main__ import main
        import contextlib
        import io
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "barren.json"
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(0, main(["preset", "--profile", "SURFACE", "--barren", "--seed", "barren-t",
                                          "--width", "64", "--height", "80", "--out", str(out)]))
                self.assertEqual(2, main(["preset", "--profile", "SURFACE", "--barren", "--legacy", "--out", str(Path(tmp) / "a.json")]))
                self.assertEqual(2, main(["preset", "--profile", "OCEANIC", "--barren", "--out", str(Path(tmp) / "b.json")]))
                self.assertEqual(0, main(["playable", str(self.folder), "--skin", "barren", "--out", str(Path(tmp) / "r.dmm")]))
            self.assertEqual(barren_surface_preset("barren-t", 64, 80), json.loads(out.read_text(encoding="utf-8")))
            self.assertEqual(self.text, (Path(tmp) / "r.dmm").read_text(encoding="utf-8"))
            self.assertFalse((Path(tmp) / "a.json").exists() or (Path(tmp) / "b.json").exists())
