import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'scripts'))
from river_flow import build

L = '/turf/floor/grass'
F = '/turf/floor/beach/water'
S = '/turf/floor/beach/water/deep/saltwater'
W = '/turf/floor/beach/water/swamp'


def land(width, height):
    return [[L] * width for _ in range(height)]


class RiverFlowTest(unittest.TestCase):
    def test_channel_flows_to_sea_without_loops(self):
        rows = land(20, 5)
        rows[2] = [L] + [F] * 16 + [S] * 3
        result = build(rows)
        self.assertEqual(result[2], '.' + 'e' * 16 + '...')
        self.assertTrue(all(c == '.' for row in result[:2] + result[3:] for c in row))

    def test_isolated_channel_short_runs_and_swamp_are_still(self):
        rows = land(24, 7)
        rows[1][2:16] = [F] * 14          # no outlet and no lake: still
        rows[3][2:6] = [F] * 4            # too short to be a river
        rows[3][6] = S
        rows[5] = [L] + [W] * 4 + [L] * 19
        result = build(rows)
        self.assertTrue(all(c == '.' for row in result for c in row))

    def test_lake_is_still_and_river_runs_through_it(self):
        rows = land(60, 20)
        for y in range(2, 18):
            rows[y][20:36] = [F] * 16      # a 16x16 lake
        rows[10][2:20] = [F] * 18          # inlet from the west
        rows[10][36:57] = [F] * 21         # outlet to the sea
        rows[10][57:60] = [S] * 3
        result = build(rows)
        # The tile at each mouth is lake margin and stays still.
        self.assertEqual(result[10][2:19], 'e' * 17)
        self.assertEqual(result[10][37:57], 'e' * 20)
        self.assertEqual(result[10][27], '.')
        self.assertEqual(build(rows), result)

    def test_diagonal_staircase_river(self):
        rows = land(20, 20)
        for i in range(16):
            rows[2 + i][2 + i] = F         # one tile wide, joined at corners
        rows[18][18] = S
        result = build(rows)
        self.assertEqual([result[2 + i][2 + i] for i in range(16)], ['b'] * 16)

    def test_inland_river_runs_off_the_map_edge(self):
        rows = land(16, 5)
        rows[2] = [L, L] + [F] * 14
        result = build(rows)
        self.assertEqual(result[2], '..' + 'e' * 14)

    def test_heights_send_a_river_to_the_lower_outlet(self):
        rows = land(30, 3)
        rows[1] = [S] + [F] * 28 + [S]
        flat = build(rows)
        self.assertEqual(flat[1][2], 'w')
        self.assertEqual(flat[1][27], 'e')
        heights = [[9 - x * 9 // 29 for x in range(30)] for _ in range(3)]  # falls to the east
        result = build(rows, heights=heights)
        # Only the mouth tiles beside the high western sea still spill west.
        self.assertEqual(result[1][3:29], 'e' * 26)


ROOT = Path(__file__).resolve().parents[2]
SIDECARS = {'nomads_gaia': 2, 'nomads_europe': 1, 'nomads_jungle': 2, 'nomads_asia': 1}


class CommittedSidecarTest(unittest.TestCase):
    def test_sidecars_match_their_maps(self):
        from terrain_heights import read_dmm, read_heights
        for name, z in SIDECARS.items():
            with self.subTest(name):
                lines = (ROOT / f'maps/heights/{name}.flow.txt').read_text(encoding='ascii').split('\n')
                hx, hy, _ = read_heights(ROOT / f'maps/heights/{name}.txt')
                self.assertEqual(lines[:3], ['civ13-river-flow 1', f'size {hx} {hy}', f'z {z}'])
                rows = lines[3:3 + hy]
                self.assertTrue(all(len(r) == hx and set(r) <= set('.neswabcd') for r in rows))
                _, _, levels = read_dmm(ROOT / f'maps/nomads/{name}.dmm')
                turfs = levels[z]
                flowing = [(x, y) for y, r in enumerate(rows) for x, c in enumerate(r) if c != '.']
                self.assertGreater(len(flowing), 500)
                for x, y in flowing:
                    turf = turfs[y][x]
                    self.assertTrue('/water' in turf and 'saltwater' not in turf and '/swamp' not in turf, (x, y, turf))


if __name__ == '__main__':
    unittest.main()
