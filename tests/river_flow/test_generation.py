import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'scripts'))
from river_flow import build

L = '/turf/floor/grass'
F = '/turf/floor/beach/water'
S = '/turf/floor/beach/water/deep/saltwater'
W = '/turf/floor/beach/water/swamp'


class RiverFlowTest(unittest.TestCase):
    def test_channel_flows_to_sea_without_loops(self):
        rows = [[L] * 8 for _ in range(5)]
        rows[2] = [L, F, F, F, F, F, S, S]
        result = build(rows)
        self.assertEqual(result[2], '.eeeee..')
        self.assertTrue(all(c == '.' for row in result[:2] + result[3:] for c in row))

    def test_isolated_fresh_water_and_swamp_are_still(self):
        rows = [[L] * 7 for _ in range(5)]
        rows[1][1:4] = [F, F, F]
        rows[3] = [L, F, W, F, S, S, S]
        result = build(rows)
        self.assertEqual(result[1], '.......')
        self.assertEqual(result[3][1:3], '..')
        self.assertEqual(result[3][3], 'e')

    def test_wide_center_is_still(self):
        rows = [[L] * 9 for _ in range(9)]
        for y in range(1, 8):
            rows[y][1:8] = [F] * 7
        rows[4][8] = S
        result = build(rows)
        self.assertEqual(result[4][4], '.')
        self.assertEqual(build(rows), result)


if __name__ == '__main__':
    unittest.main()
