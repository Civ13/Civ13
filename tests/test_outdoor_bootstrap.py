"""DMM orientation and fail-closed inventory parser regressions."""
import importlib.util
import pathlib
import unittest

spec = importlib.util.spec_from_file_location(
    "bootstrap", pathlib.Path(__file__).resolve().parents[1] / "scripts/check-outdoor-bootstrap.py")
bootstrap = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bootstrap)


class MapInventoryParser(unittest.TestCase):
    def test_top_row_is_high_y_and_unused_definition_is_absent(self):
        text = '"aa" = (/turf/floor/grass,/area/test)\n"bb" = (/turf/floor/dirt,/area/test)\n"cc" = (/obj/structure/wild/smallbush,/turf/floor/dirt,/area/test)\n(4,7,2) = {"\naabb\nbbaa\n"}'
        tiles = bootstrap.read_map(text)
        self.assertEqual(set(tiles), {(4, 7, 2), (5, 7, 2), (4, 8, 2), (5, 8, 2)})
        self.assertIn("/turf/floor/grass", tiles[(4, 8, 2)])
        self.assertIn("/turf/floor/dirt", tiles[(4, 7, 2)])
        self.assertTrue(all("smallbush" not in tile for tile in tiles.values()))

    def test_invalid_maps_are_rejected(self):
        for text in (
            '"a" = (/turf/floor/dirt,/area/test)\n"bb" = (/turf/floor/dirt,/area/test)\n(1,1,1) = {"\na\n"}',
            '"aa" = (/turf/floor/dirt,/area/test)\n(1,1,1) = {"\naaaa\naa\n"}',
            '"aa" = (/turf/floor/dirt,/area/test)\n(1,1,1) = {"\nbb\n"}',
            '"aa" = (/turf/floor/dirt,/area/test)\n"aa" = (/turf/floor/dirt,/area/test)\n(1,1,1) = {"\naa\n"}',
            '"aa" = (/turf/floor/dirt,/area/test)\n(1,1,1) = {"\naa\n"}\n(1,1,1) = {"\naa\n"}',
        ):
            with self.subTest(text=text), self.assertRaises(ValueError):
                bootstrap.read_map(text)

    def test_unknown_inheritance_is_not_assumed_fresh(self):
        with self.assertRaises(ValueError):
            bootstrap.resolve({}, "/turf/floor/beach/water")

    def test_bush_ground_follows_the_round_start_seeder(self):
        self.assertTrue(bootstrap.seeds_bushes("/turf/floor/grass/jungle/savanna", "savanna"))
        self.assertTrue(bootstrap.seeds_bushes("/turf/floor/winter/grass", "taiga"))
        self.assertTrue(bootstrap.seeds_bushes("/turf/floor/dirt/dust", "desert"))
        self.assertFalse(bootstrap.seeds_bushes("/turf/floor/grass", "desert"))
        self.assertFalse(bootstrap.seeds_bushes("/turf/floor/winter/grass", "jungle"))
        self.assertFalse(bootstrap.seeds_bushes("/turf/floor/dirt/underground", "temperate"))
        self.assertFalse(bootstrap.seeds_bushes("/turf/floor/beach/sand/desert", "desert"))
        source = (bootstrap.ROOT / "code/game/turfs/flooring/flooring_premade.dm").read_text(encoding="utf-8")
        dirt = source[source.index("/turf/floor/dirt/plant()"):source.index("/turf/floor/winter/grass/plant()")]
        for climate in bootstrap.DIRT_BUSH_CLIMATES:
            branch = dirt[dirt.index(f'if ("{climate}")') + 4:]
            branch = branch.split('if ("')[0]
            self.assertIn("/obj/structure/wild/smallbush", branch, climate)

    def test_classification_separates_ploughable_and_clearable_ground(self):
        climates = {"/area/test": "savanna"}
        salt = {"/turf/floor/beach/water": "FALSE", "/turf/floor/beach/water/deep/saltwater": "TRUE"}
        dry = bootstrap.classify("/turf/floor/grass/jungle/savanna,/area/test", climates, salt)
        self.assertFalse(dry["soil"] or dry["clearable"])
        self.assertTrue(dry["bush_ground"])
        bank = bootstrap.classify("/turf/floor/grass,/area/test", climates, salt)
        self.assertTrue(bank["soil"])
        blocked = bootstrap.classify("/obj/structure/wild/rock,/turf/floor/grass,/area/test", climates, salt)
        self.assertFalse(blocked["soil"] or blocked["bush_ground"])
        snow = bootstrap.classify("/turf/floor/winter/grass,/area/test", climates, salt)
        self.assertTrue(snow["clearable"] and not snow["soil"])
        self.assertTrue(bootstrap.classify("/turf/floor/beach/water,/area/test", climates, salt)["fresh"])
        self.assertFalse(bootstrap.classify("/turf/floor/beach/water/deep/saltwater,/area/test", climates, salt)["fresh"])


if __name__ == "__main__":
    unittest.main()
