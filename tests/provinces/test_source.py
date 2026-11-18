"""Provinces: the committed province files, the generator and the DM reader.

Checks every continent's province file against its map (size, every land
tile in a province, 4-12 unique names), that the generator splits a small
made-up map along a river, and that the game's reader expects the format the
tool writes.

    python3 tests/provinces/test_source.py
"""
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
import provinces  # noqa: E402
from terrain_heights import read_dmm  # noqa: E402

SOURCE = ROOT / 'code/modules/provinces/provinces.dm'
DME = ROOT / 'civ13.dme'
# Map -> surface z, as scripts/provinces.py was run (docs/provinces.md).
CONTINENTS = {
    'nomads_gaia': 2, 'nomads_americas_north': 1, 'nomads_americas_south': 1,
    'nomads_europe': 1, 'nomads_asia': 1, 'nomads_desert': 2, 'nomads_jungle': 2,
}


class ProvinceFiles(unittest.TestCase):
    def test_every_continent_has_a_valid_file(self):
        for name, z in CONTINENTS.items():
            with self.subTest(map=name):
                width, height, fz, found, rows = provinces.read(ROOT / f'maps/provinces/{name}.txt')
                self.assertEqual(fz, z)
                self.assertTrue(provinces.MIN_PROVINCES <= len(found) <= provinces.MAX_PROVINCES)
                names = [n for _, n in found]
                self.assertEqual(len(names), len(set(names)), 'province names repeat')
                mw, mh, levels = read_dmm(ROOT / f'maps/nomads/{name}.dmm')
                self.assertEqual((width, height), (mw, mh))
                turfs = levels[z]
                for r, row in enumerate(turfs):
                    for c, turf in enumerate(row):
                        if provinces.tile_kind(turf) != provinces.WATER:
                            self.assertNotEqual(rows[r][c], '.', f'land at {c + 1},{height - r} is in no province')
                for char, _ in found:
                    self.assertTrue(any(char in row for row in rows), f'province {char} has no tiles')

    def test_files_exist_only_beside_a_height_file(self):
        for path in (ROOT / 'maps/provinces').glob('*.txt'):
            with self.subTest(file=path.name):
                self.assertTrue((ROOT / 'maps/heights' / path.name).exists())


class Generator(unittest.TestCase):
    def test_a_river_becomes_the_border(self):
        grass, river, sea = '/turf/floor/grass', '/turf/floor/beach/water/deep/jungle', '/turf/floor/beach/water/deep/saltwater'
        width, height = 60, 30
        turfs = []
        for r in range(height):
            row = []
            for c in range(width):
                if r in (0, height - 1) or c in (0, width - 1):
                    row.append(sea)
                elif c == 30:
                    row.append(river)
                else:
                    row.append(grass)
            turfs.append(row)
        flow = ['.' * width] * height
        flow = [row[:30] + ('s' if 0 < r < height - 1 else '.') + row[31:] for r, row in enumerate(flow)]
        heights = [[0] * width for _ in range(height)]
        old = provinces.SLIVER_SHARE
        try:
            provinces.SLIVER_SHARE = 0.1
            t, rows, found = provinces.build(turfs, heights, flow, count=2)
        finally:
            provinces.SLIVER_SHARE = old
        self.assertEqual(len(found), 2)
        west = {rows[r][c] for r in range(1, height - 1) for c in range(1, 30)}
        east = {rows[r][c] for r in range(1, height - 1) for c in range(31, width - 1)}
        self.assertEqual(len(west), 1)
        self.assertEqual(len(east), 1)
        self.assertNotEqual(west, east)

    def test_output_is_deterministic(self):
        turfs = [['/turf/floor/grass'] * 40 for _ in range(40)]
        heights = [[0] * 40 for _ in range(40)]
        first = provinces.build(turfs, heights, None, count=4)[1]
        second = provinces.build(turfs, heights, None, count=4)[1]
        self.assertEqual(first, second)


class Reader(unittest.TestCase):
    def test_reader_matches_the_format(self):
        text = SOURCE.read_text(encoding='utf-8')
        self.assertIn('"civ13-provinces 1"', text)
        self.assertEqual(provinces.HEADER, 'civ13-provinces 1')
        self.assertIn('replacetext(height_file, "maps/heights/", "maps/provinces/")', text)
        self.assertIn('should_save = FALSE', text)
        self.assertIn('#include "code\\modules\\provinces\\provinces.dm"', DME.read_text(encoding='utf-8'))

    def test_reader_never_sleeps(self):
        text = SOURCE.read_text(encoding='utf-8')
        self.assertNotIn('sleep(', text)
        self.assertNotIn('spawn(', text)


if __name__ == '__main__':
    unittest.main()
