"""Offline checks for the authored two-level reef pilot."""
import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from ocean_maps import reef_fixture as reef  # noqa: E402


def neighbours(pos):
    x, y = pos
    return ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))


class ReefFixtureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = reef.FIXTURE.read_text(encoding="utf-8")
        cls.keys = dict(re.findall(r'^"(\w)" = \((.+)\)$', cls.text, re.M))
        cls.levels = {}
        for z, block in re.findall(r'^\(1,1,(\d+)\) = \{"\n([a-z\n]+)\n"\}$', cls.text, re.M):
            cls.levels[int(z)] = block.splitlines()[::-1]

    def points(self, z, key):
        return {(x, y) for y, row in enumerate(self.levels[z], 1)
                for x, code in enumerate(row, 1) if code == key}

    def test_exact_regeneration(self):
        self.assertEqual(reef.main(["--check"]), 0)

    def test_two_compact_authored_levels_and_metadata(self):
        self.assertEqual(set(self.levels), {1, 2})
        for rows in self.levels.values():
            self.assertEqual(len(rows), 30)
            self.assertTrue(all(len(row) == 40 for row in rows))
        self.assertEqual(self.points(1, "b"), {(1, 1)})
        self.assertIn("/ocean/indian{underground_compiled_z = 2; underground_depth = 1}", self.keys["b"])
        self.assertNotIn("sea_layer_surface_z", self.text)
        self.assertEqual(self.points(1, "d"), {(6, 15)})
        self.assertEqual(self.points(1, "f"), {(26, 8)})
        self.assertIn("buoy/yellow", self.keys["f"])

    def test_shelves_are_directly_under_open_water_not_a_dry_landing(self):
        shelf = self.points(2, "g")
        water = self.points(1, "a") | self.points(1, "f")
        self.assertEqual(self.keys["g"], f"{reef.SHELF},{reef.AREA}")
        self.assertEqual(self.keys["a"], f"{reef.SALTWATER},{reef.AREA}")
        self.assertTrue(shelf <= water)
        self.assertTrue(125 <= len(shelf) <= 250)
        self.assertTrue(all(1 < x < 40 and 1 < y < 30 for x, y in shelf))
        self.assertNotIn((6, 15), shelf)
        self.assertIn((26, 8), shelf)

    def test_connected_shallow_shelf_with_interior_reef_ridge(self):
        shelf = self.points(2, "g")
        self.assertIn((26, 17), self.points(2, "e"))
        self.assertIn((26, 15), shelf)
        visited = {(26, 8)}
        pending = list(visited)
        while pending:
            for pos in neighbours(pending.pop()):
                if pos in shelf and pos not in visited:
                    pending.append(pos)
                    visited.add(pos)
        self.assertEqual(visited, shelf)

        # If this fixture were put through the standard depth pass, all its
        # cells would still be within the six-tile shelf band (4-way distance).
        frontier = {p for p in shelf if any(n not in shelf for n in neighbours(p))}
        seen = set(frontier)
        for _ in range(5):
            frontier = {n for p in frontier for n in neighbours(p) if n in shelf - seen}
            seen.update(frontier)
        self.assertEqual(seen, shelf)
