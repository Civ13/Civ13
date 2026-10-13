"""Offline topology checks; not graphical or native driving acceptance."""
from collections import deque
from pathlib import Path
import re
import unittest
from build_mall import build, coordinate, SIZE, ROAD_ENTRIES, HIGHWAY_EXITS
from build_map import build as original

ROOT = Path(__file__).resolve().parents[2]


def parse(source):
    entries = re.findall(r'^"([a-z]{2})" = (.*)$', source, re.M)
    definitions = dict(entries)
    if len(entries) != len(definitions):
        raise ValueError('Duplicate tile key')
    layers = {}
    for z, body in re.findall(r'\(1,1,(\d+)\) = \{"\n(.*?)\n"\}', source, re.S):
        rows = body.splitlines()
        size = len(rows)
        if not all(len(row) == size*2 for row in rows):
            raise ValueError('Non-square or inconsistent grid')
        layers[int(z)] = [[definitions[row[x*2:x*2+2]] for x in range(size)] for row in reversed(rows)]
    return layers


def blocked(value):
    # Closets (including fridges) and ovens are dense native furnishings.
    # Chairs are conservatively reserved; beds, sinks and toilets are walkable.
    return any(atom in value for atom in ('/obj/covers/generic_wall', '/obj/structure/table', '/obj/structure/bed/chair', '/obj/structure/closet', '/obj/structure/oven', '/obj/structure/props/car_wreck'))


def reachable(layers, start, vehicle=False):
    size = len(layers[1])
    pending, seen = deque([start]), {start}
    stairs = {}
    wreck_cells = set()
    for z in (1, 4, 5):
        for y, row in enumerate(layers[z], 1):
            for x, value in enumerate(row, 1):
                if '/obj/structure/props/car_wreck' in value:
                    # Native wreck bounding box is 96x64 pixels, or 3x2 tiles.
                    wreck_cells.update((x+dx, y+dy, z) for dx in range(3) for dy in range(2))
    if not vehicle:
        for z in (1, 4, 5):
            for y, row in enumerate(layers[z], 1):
                for x, value in enumerate(row, 1):
                    if '/extraction_mall_stairs' in value:
                        stairs[x, y, z] = int(re.search(r'destination_z = (\d+)', value)[1])
    while pending:
        x, y, z = pending.popleft()
        adjacent = [(x+1, y, z), (x-1, y, z), (x, y+1, z), (x, y-1, z)]
        if (x, y, z) in stairs:
            adjacent.append((x, y, stairs[x, y, z]))
        for xx, yy, zz in adjacent:
            point = (xx, yy, zz)
            if point in seen or not 2 <= xx < size or not 2 <= yy < size:
                continue
            radius = 1 if vehicle else 0
            if any((xx+dx, yy+dy, zz) in wreck_cells for dx in range(-radius, radius+1) for dy in range(-radius, radius+1)):
                continue
            if any(blocked(layers[zz][cy-1][cx-1]) for cy in range(yy-radius, yy+radius+1) for cx in range(xx-radius, xx+radius+1)):
                continue
            seen.add(point)
            pending.append(point)
    return seen


class MallTests(unittest.TestCase):
    def test_dmm_assignments_use_numeric_booleans(self):
        for filename in ('industrial_district.dmm', 'modern_city_extraction.dmm', 'interchange_mall.dmm'):
            with self.subTest(map=filename):
                self.assertIsNone(re.search(r'=\s*(?:TRUE|FALSE)\b',
                                          (ROOT / 'maps/extraction' / filename).read_text()))
        for source in (original(), original(city=True), build()):
            self.assertIsNone(re.search(r'=\s*(?:TRUE|FALSE)\b', source))

    def test_post_war_dressing_stays_on_raid_floors(self):
        layers = parse(build())
        for z in (1, 4, 5):
            tiles = [value for row in layers[z] for value in row]
            self.assertGreaterEqual(sum('/extraction_mall_rubble' in value for value in tiles), 6)
            self.assertGreaterEqual(sum('/decal/rubbish' in value for value in tiles), 6)
        self.assertGreaterEqual(sum('/props/car_wreck' in value for row in layers[1] for value in row), 16)
        for z in (4, 5):
            self.assertTrue(any('/floor/wood_broken' in value for row in layers[z] for value in row))
        for z in (2, 3):
            self.assertFalse(any('/extraction_mall_rubble' in value or '/props/car_wreck' in value for row in layers[z] for value in row))

    def test_generated_default_and_protected_levels(self):
        generated = build()
        self.assertEqual((ROOT / 'maps/extraction/interchange_mall.dmm').read_text(), generated)
        layers, homes = parse(generated), parse(original())
        self.assertEqual(set(layers), {1, 2, 3, 4, 5})
        for z, rows in layers.items():
            self.assertEqual(len(rows), SIZE)
            self.assertTrue(all(len(row) == SIZE for row in rows))
        for z in (2, 3):
            for y in range(96):
                self.assertEqual(layers[z][y][:96], homes[z][y])
            self.assertTrue(all('/obj/covers/generic_wall' in layers[z][100][x] for x in range(SIZE)))
        loot = [value for z in (1, 4, 5) for row in layers[z] for value in row if '/extraction_loot_marker' in value]
        ids = [int(re.search(r'container_id = (\d+)', value)[1]) for value in loot]
        self.assertEqual(len(ids), 64)
        self.assertEqual(sum('/extraction_loot_marker/keyed/' not in value for value in loot), 62)
        self.assertEqual(sum('/extraction_loot_marker/keyed/' in value for value in loot), 2)
        self.assertEqual(len(set(ids)), len(ids))
        self.assertTrue(all(1 <= value <= 64 for value in ids))
        parking_pools = [re.search(r'pool_kind = "([a-z]+)"', value)[1]
                         for row in layers[1] for value in row
                         if '/extraction_loot_marker' in value]
        self.assertCountEqual(parking_pools, ['workshop'] * 3 + ['supplies'] * 2 + ['ammunition'])
        # Preserve existing durable shop/cache identities when adding parking
        # loot; redistributing or renumbering sources would reuse old journals.
        for z, expected in ((1, {57, 58, 59, 60, 63, 64}),
                            (4, set(range(1, 17)) | {61, 62}),
                            (5, set(range(17, 57)))):
            floor_ids = {int(re.search(r'container_id = (\d+)', value)[1])
                         for row in layers[z] for value in row
                         if '/extraction_loot_marker' in value}
            self.assertEqual(floor_ids, expected)

    def test_raid_furnishings_use_fixed_catalog(self):
        # Native furniture can yield saleable materials through damage and tool
        # paths. Keep every raid placement on the reviewed, map-only variants.
        allowed = {
            '/obj/covers/generic_wall/extraction_mall',
            '/obj/structure/table/extraction_mall',
            '/obj/structure/table/extraction_mall/shelf',
            '/obj/structure/table/extraction_mall/coatrack',
            '/obj/structure/table/extraction_mall/nightstand',
            '/obj/structure/bed/wood/extraction_mall',
            '/obj/structure/bed/fieldbed/extraction_mall',
            '/obj/structure/bed/sofa/extraction_mall',
            '/obj/structure/bed/chair/extraction_mall',
            '/obj/structure/closet/extraction_mall',
            '/obj/structure/closet/fridge/extraction_mall',
            '/obj/structure/oven/extraction_mall',
            '/obj/structure/sink/extraction_mall',
            '/obj/structure/toilet/extraction_mall',
            '/obj/structure/extraction_mall_stairs',
            '/obj/structure/extraction_mall_fixture/register',
            '/obj/structure/props/car_wreck',
        }
        layers = parse(build())
        for z in (1, 4, 5):
            for row in layers[z]:
                for value in row:
                    for path in re.findall(r'/obj/(?:structure|covers)/[A-Za-z0-9_/]+', value):
                        self.assertIn(path, allowed)

    def test_walk_routes_and_native_sized_vehicle_clearance(self):
        for size in (160, 256, 320):
            with self.subTest(size=size):
                layers = parse(build(size))
                c = lambda value: coordinate(value, size)
                start = (c(ROAD_ENTRIES[0][0]), c(ROAD_ENTRIES[0][1]), 1)
                seen = reachable(layers, start)
                for z in (1, 4, 5):
                    for y, row in enumerate(layers[z], 1):
                        for x, value in enumerate(row, 1):
                            if any(token in value for token in ('/extraction_raid_marker', '/extraction_exit', '/extraction_loot_marker', '/extraction_npc_marker', '/extraction_mall_stairs', '/extraction_drop_box', '/extraction_mall_sign')):
                                self.assertIn((x, y, z), seen, value)
                            if any(token in value for token in ('/obj/structure/closet', '/obj/structure/oven', '/obj/structure/sink', '/obj/structure/toilet', '/obj/structure/bed/wood', '/obj/structure/bed/fieldbed', '/extraction_surface_source')):
                                self.assertTrue(any(point in seen for point in ((x+1, y, z), (x-1, y, z), (x, y+1, z), (x, y-1, z))), (x, y, z, value))
                self.assertFalse(any(z in (2, 3) for _, _, z in seen))
                for entry in ROAD_ENTRIES:
                    cars = reachable(layers, (c(entry[0]), c(entry[1]), 1), vehicle=True)
                    for exit_point in HIGHWAY_EXITS:
                        self.assertIn((c(exit_point[0]), c(exit_point[1]), 1), cars)
                    self.assertFalse(any(z != 1 for _, _, z in cars))

    def test_surface_sources_keep_unique_ids_and_real_supports(self):
        supports = {
            'floor': 'null',
            'shelf': '/obj/structure/table/extraction_mall/shelf',
            'table': '/obj/structure/table/extraction_mall',
            'register': '/obj/structure/extraction_mall_fixture/register',
        }
        for size in (160, 256, 320):
            with self.subTest(size=size):
                layers = parse(build(size))
                ids = []
                by_floor = {}
                kinds = []
                for z, rows in layers.items():
                    for row in rows:
                        for value in row:
                            markers = re.findall(r'/obj/effect/extraction_surface_source\{([^}]+)\}', value)
                            if not markers:
                                continue
                            self.assertEqual(len(markers), 1)
                            fields = dict(field.strip().split(' = ', 1) for field in markers[0].split(';'))
                            ids.append(int(fields['source_id']))
                            by_floor[z] = by_floor.get(z, 0) + 1
                            kind = fields['support_kind'].strip('"')
                            kinds.append(kind)
                            self.assertEqual(fields['support_type'], supports[kind])
                            self.assertIn(fields['pool_id'].strip('"'), ('parking_fuel', 'parking_wheel', 'repair_parts', 'canned_food', 'register_cash'))
                            placed = [atom.split('{', 1)[0] for atom in value[1:-1].split(',')]
                            if kind == 'floor':
                                self.assertFalse(blocked(value))
                            else:
                                self.assertEqual(placed.count(supports[kind]), 1)
                            if kind == 'register':
                                self.assertIn(supports['table'], placed)
                self.assertCountEqual(ids, range(1, 41))
                self.assertEqual(by_floor, {1: 12, 4: 20, 5: 8})
                self.assertCountEqual(kinds, ['floor']*8 + ['shelf']*22 + ['table']*4 + ['register']*6)

    def test_disconnected_stair_control_is_detected(self):
        layers = parse(build(160))
        for y, row in enumerate(layers[1]):
            for x, value in enumerate(row):
                if '/extraction_mall_stairs' in value:
                    row[x] = '(/obj/covers/generic_wall,/turf/floor/plating/concrete,/area/extraction_mall/parking)'
        seen = reachable(layers, (10, 12, 1))
        self.assertFalse(any(z != 1 for _, _, z in seen))

    def test_expanded_size_and_bad_size(self):
        layers = parse(build(512))
        self.assertTrue(all(len(rows) == 512 for rows in layers.values()))
        for size in (96, 513):
            with self.assertRaises(ValueError):
                build(size)


if __name__ == '__main__':
    unittest.main()
