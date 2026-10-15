"""Independent generated-tile circulation checks; no native gameplay claims."""
from collections import deque
import re
import unittest

from build_mall import build, coordinate
from test_mall import parse, blocked


SIZES = (160, 256, 320, 512)


def flood(rows, start, forbidden=(), bounds=None):
    """Walk one physical floor only, so stairs cannot hide a broken route."""
    size = len(rows)
    left, bottom, right, top = bounds or (2, 2, size - 1, size - 1)
    forbidden = set(forbidden)
    seen = set()
    pending = deque([start])
    while pending:
        x, y = pending.popleft()
        if ((x, y) in seen or (x, y) in forbidden or
                not left <= x <= right or not bottom <= y <= top or
                blocked(rows[y - 1][x - 1])):
            continue
        seen.add((x, y))
        pending.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return seen


def rectangle(size, box):
    left, bottom, right, top = (coordinate(v, size) for v in box)
    return {(x, y) for y in range(bottom, top + 1)
            for x in range(left, right + 1)}


def markers(layers, token):
    for z, rows in layers.items():
        for y, row in enumerate(rows, 1):
            for x, value in enumerate(row, 1):
                if token in value:
                    yield x, y, z, value


class MallRouteTests(unittest.TestCase):
    maxDiff = 1200
    @classmethod
    def setUpClass(cls):
        cls.maps = {size: parse(build(size)) for size in SIZES}

    def test_every_scale_preserves_all_container_identities(self):
        expected = {1: {57, 58, 59, 60, 63, 64},
                    4: set(range(1, 17)) | {61, 62},
                    5: set(range(17, 57))}
        for size, layers in self.maps.items():
            with self.subTest(size=size):
                actual = {z: [] for z in expected}
                keyed = {}
                for x, y, z, value in markers(layers, '/extraction_loot_marker'):
                    identity = int(re.search(r'container_id = (\d+)', value)[1])
                    actual[z].append(identity)
                    if '/extraction_loot_marker/keyed/' in value:
                        keyed[identity] = value
                for z, identities in expected.items():
                    self.assertCountEqual(actual[z], identities)
                self.assertEqual(set(keyed), {61, 62})
                self.assertIn('/keyed/mall_security', keyed[61])
                self.assertIn('/keyed/mall_hardware', keyed[62])

    def test_upper_public_routes_survive_closed_shops(self):
        for size, layers in self.maps.items():
            with self.subTest(size=size):
                c = lambda v: coordinate(v, size)
                closed = set()
                for y in (26, 50, 88, 112):
                    for i in range(5):
                        closed.update(rectangle(size, (26 + 22*i, y,
                                                        44 + 22*i, y + 18)))
                seen = flood(layers[5], (c(20), c(18)), closed)
                # Public routes must connect every real stair, without using
                # shop interiors or any lower floor as an escape hatch.
                stairs = [(x, y) for x, y, z, _ in
                          markers(layers, '/extraction_mall_stairs') if z == 5]
                self.assertEqual(len(stairs), 6)
                self.assertTrue(set(stairs) <= seen)
                for point in ((20, 140), (138, 18), (138, 140),
                              (20, 80), (138, 80), (80, 80)):
                    self.assertTrue((c(point[0]), c(point[1])) in seen,
                                    f'Size {size}: public route missing at {point}')
                # Severing every north/south route must invalidate the proof.
                cut = closed | rectangle(size, (2, 80, 159, 80))
                self.assertFalse((c(20), c(140)) in
                                 flood(layers[5], (c(20), c(18)), cut),
                                 f'Size {size}: severed public route remained connected')

    def test_parking_reward_rooms_have_independent_doors(self):
        rooms = (
            ((35, 106, 35, 106), (48, 119, 48, 119), {57, 58}),
            ((123, 112, 123, 112), (110, 120, 110, 120), {59, 60}),
            ((32, 22, 32, 22), (42, 30, 42, 30), {63}),
            ((127, 22, 127, 22), (116, 34, 116, 34), {64}),
        )
        for size, layers in self.maps.items():
            c = lambda v: coordinate(v, size)
            loot = {int(re.search(r'container_id = (\d+)', value)[1]): (x, y)
                    for x, y, z, value in markers(layers, '/extraction_loot_marker')
                    if z == 1}
            for south, side, identities in rooms:
                # Door gaps are three normalized cells wide.
                sx, sy = south[:2]
                dx, dy = side[:2]
                doors = (rectangle(size, (sx - 1, sy, sx + 1, sy)),
                         rectangle(size, (dx, dy - 1, dx, dy + 1)))
                for index, sealed in enumerate(doors):
                    with self.subTest(size=size, room=identities, sealed=index):
                        seen = flood(layers[1], (c(56), c(12)), sealed)
                        for identity in identities:
                            self.assertTrue(loot[identity] in seen,
                                            f'Unreachable parking container {identity}')
                seen = flood(layers[1], (c(56), c(12)), doors[0] | doors[1])
                for identity in identities:
                    self.assertFalse(loot[identity] in seen,
                                     f'Size {size}: closing both doors must isolate container {identity}')

    def test_receiving_routes_do_not_depend_on_central_door(self):
        for size, layers in self.maps.items():
            c = lambda v: coordinate(v, size)
            for x in (48, 112):
                with self.subTest(size=size, receiving=x):
                    # Bound the proof to this receiving lane: the public
                    # perimeter and other shop doors cannot rescue it.
                    bounds = (c(x-4), c(124), c(x+4), c(140))
                    start, target = (c(x), c(140)), (c(x), c(124))
                    self.assertTrue(target in flood(layers[4], start, bounds=bounds),
                                    f'Size {size}: receiving lane {x} is disconnected')
                    sealed = rectangle(size, (x-4, 134, x+4, 134))
                    self.assertFalse(target in flood(layers[4], start, sealed, bounds),
                                     f'Size {size}: blocked receiving lane {x} remained connected')

    def test_road_arrivals_are_separated_from_highway_exits(self):
        for size, layers in self.maps.items():
            roads = [(x, y) for x, y, z, _ in
                     markers(layers, '/extraction_raid_marker/road') if z == 1]
            exits = [(x, y) for x, y, z, _ in
                     markers(layers, '/extraction_exit/highway') if z == 1]
            self.assertEqual(len(roads), 2)
            self.assertEqual(len(exits), 2)
            # Rounding at scaled coordinates permits one physical tile slack.
            minimum = 40 * (size - 1) / 159 - 1
            for road in roads:
                for exit_point in exits:
                    self.assertGreaterEqual(abs(road[0] - exit_point[0]) +
                                            abs(road[1] - exit_point[1]), minimum)


if __name__ == '__main__':
    unittest.main()
