"""Generated-cell graph tests; not native BYOND movement acceptance."""
import unittest
from collections import deque
from tools.rail_yard.yard import (
    layout, add_physical_routes, berth_origin, tile, RAIL, GROUND, CONCRETE,
    TRAIN_AREA, TRAIN, WALL,
)


def rails(cells):
    return {p for p, cell in cells.items() if cell.startswith(RAIL + ',')}


def connected(start, network):
    found = {start}
    todo = deque([start])
    while todo:
        x, y, z = todo.popleft()
        for q in ((x + 1, y, z), (x - 1, y, z), (x, y + 1, z), (x, y - 1, z)):
            if q in network and q not in found:
                found.add(q)
                todo.append(q)
    return found


class YardGeometry(unittest.TestCase):
    def test_every_berth_has_connected_clear_edge_lane(self):
        # Smallest, partial row, default, and largest documented layout.
        for berths, columns in ((1, 1), (5, 4), (96, 4), (162, 6)):
            with self.subTest(berths=berths, columns=columns):
                before, width, height = layout(berths, columns)
                after, w, h = layout(berths, columns, physical_routes=True)
                self.assertEqual((width, height), (w, h))
                track = rails(after)
                old_track = rails(before)
                for p, cell in before.items():
                    if p[2] == 1 or TRAIN_AREA in cell or '/rail_berth{' in cell or p in old_track:
                        self.assertEqual(cell, after[p])
                for berth in range(1, berths + 1):
                    ox, oy = berth_origin(berth, columns)
                    y = oy + 3 + len(TRAIN)
                    component = connected((ox + 1, y - 1, 2), track)
                    self.assertIn((1, y, 2), component)
                    self.assertIn((width, y, 2), component)
                    self.assertLessEqual(abs(y - (oy + 1)), 7)
                    for x in range(1, width + 1):
                        self.assertIn((x, y, 2), track)
                        for dy in (-1, 1):
                            self.assertIn(after[(x, y + dy, 2)],
                                          (tile(GROUND), tile(CONCRETE), tile(RAIL, GROUND)))
                    # Entire arrival consists fit from either edge, with no clipping.
                    for count in (1, 4, min(64, width)):
                        for xs in (range(1, count + 1), range(width - count + 1, width + 1)):
                            self.assertEqual(sum((x, y, 2) in track for x in xs), count)

    def test_default_output_unchanged(self):
        self.assertEqual(layout(5, 4), layout(5, 4, physical_routes=False))

    def test_obstruction_rejects_atomically(self):
        cells, w, h = layout(1, 1)
        ox, oy = berth_origin(1, 1)
        cells[(ox, oy + 3 + len(TRAIN), 2)] = tile(WALL, area=TRAIN_AREA)
        before = cells.copy()
        with self.assertRaisesRegex(ValueError, 'replace an existing object'):
            add_physical_routes(cells, w, h, 1, 1)
        self.assertEqual(cells, before)

    def test_dimensions_remain_bounded(self):
        with self.assertRaises(ValueError):
            layout(300, 8, physical_routes=True)


if __name__ == '__main__':
    unittest.main()
