"""Offline keyed-cache placement and walking topology; no native gameplay."""
from collections import deque
from pathlib import Path
import re
import unittest

from build_map import build as build_district
from build_mall import build as build_mall, coordinate, ROAD_ENTRIES
from test_mall import parse, reachable, blocked

ROOT = Path(__file__).resolve().parents[2]
MAPS = {
    'industrial_district.dmm': ('industrial_tool_cage', 'industrial_dispatch'),
    'modern_city_extraction.dmm': ('city_pharmacy', 'city_evidence'),
    'interchange_mall.dmm': ('mall_security', 'mall_hardware'),
}


def district_reachable(layers, start=(8, 8, 1)):
    size = len(layers[1])
    seen, pending = {start}, deque([start])
    while pending:
        x, y, z = pending.popleft()
        for xx, yy in ((x+1, y), (x-1, y), (x, y+1), (x, y-1)):
            point = xx, yy, z
            if point in seen or not (1 <= xx <= size and 1 <= yy <= size):
                continue
            value = layers[z][yy-1][xx-1]
            if blocked(value) or any(token in value for token in (
                    '/component_workbench', '/research_bench', '/structure/sink',
                    '/structure/wild/tree', '/structure/simple_door')):
                continue
            seen.add(point)
            pending.append(point)
    return seen


class KeyMapTests(unittest.TestCase):
    def test_checked_in_maps_match_generators(self):
        expected = {
            'industrial_district.dmm': build_district(),
            'modern_city_extraction.dmm': build_district(city=True),
            'interchange_mall.dmm': build_mall(),
        }
        for filename, source in expected.items():
            with self.subTest(map=filename):
                self.assertEqual((ROOT / 'maps/extraction' / filename).read_text(), source)

    def test_each_map_has_exact_targets_unique_ids_and_no_fixed_keys(self):
        for filename, suffixes in MAPS.items():
            with self.subTest(map=filename):
                source = (ROOT / 'maps/extraction' / filename).read_text()
                self.assertNotIn('/obj/item/weapon/key/extraction_container', source)
                layers = parse(source)
                mission = (1, 4, 5) if filename == 'interchange_mall.dmm' else (1,)
                seen = (reachable(layers, (coordinate(ROAD_ENTRIES[0][0]),
                                          coordinate(ROAD_ENTRIES[0][1]), 1))
                        if len(mission) > 1 else district_reachable(layers))
                ids, keyed = [], {}
                for z, rows in layers.items():
                    for y, row in enumerate(rows, 1):
                        for x, value in enumerate(row, 1):
                            if '/obj/effect/extraction_loot_marker' not in value:
                                continue
                            self.assertIn(z, mission)
                            container_id = int(re.search(r'container_id = (\d+)', value)[1])
                            ids.append(container_id)
                            match = re.search(r'/extraction_loot_marker/keyed/(\w+)', value)
                            if not match:
                                continue
                            suffix = match[1]
                            self.assertNotIn(suffix, keyed)
                            keyed[suffix] = container_id
                            self.assertIn((x, y, z), seen, value)
                            # A clear cardinal approach exists independently of
                            # the marker's own nonblocking tile.
                            self.assertTrue(any((xx, yy, z) in seen for xx, yy in (
                                (x+1, y), (x-1, y), (x, y+1), (x, y-1))))
                self.assertEqual(keyed, dict(zip(suffixes, (61, 62))))
                self.assertEqual(len(ids), len(set(ids)))
                self.assertTrue(all(1 <= value <= 64 for value in ids))

    def test_blocked_cache_control_is_detected(self):
        layers = parse(build_district())
        for y, row in enumerate(layers[1]):
            for x, value in enumerate(row):
                if '/keyed/industrial_tool_cage' in value:
                    target = x+1, y+1, 1
                    for xx, yy in ((x+1, y), (x-1, y), (x, y+1), (x, y-1)):
                        layers[1][yy][xx] = '(/obj/covers/generic_wall)'
        self.assertNotIn(target, district_reachable(layers))


if __name__ == '__main__':
    unittest.main()
