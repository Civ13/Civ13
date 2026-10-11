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
        text = '"aa" = (/turf/floor/dirt,/area/test)\n"bb" = (/obj/structure/wild/smallbush,/turf/floor/dirt,/area/test)\n(4,7,2) = {"\naaaa\naaaa\n"}'
        tiles = bootstrap.read_map(text)
        self.assertEqual(set(tiles), {(4, 7, 2), (5, 7, 2), (4, 8, 2), (5, 8, 2)})
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


if __name__ == "__main__":
    unittest.main()
