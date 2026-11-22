"""Offline checks for the generated Americas region maps (standard library only).

They read the committed .dmm files; the generator (build.py, needs numpy and
Pillow) is not run here. Run from the repository root:

    python3 -I -B -m unittest tests/americas_maps/test_americas_maps.py
"""
import re
import unittest
import hashlib
import json
import os
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
# Digests of each map and its height, current and flood files, written by
# build.py when it writes them (line endings normalised, so any checkout matches).
SIDECARS = json.loads((Path(__file__).resolve().parent / 'sidecars.json').read_text(encoding='utf-8'))


def file_digest(path):
    return hashlib.sha256(path.read_bytes().replace(b'\r\n', b'\n')).hexdigest()

MAPS = {
    'north': {
        'path': 'maps/nomads/nomads_americas_north.dmm',
        'metadata': '/obj/map_metadata/nomads/americas_north',
        'edge': 'south',
        'neighbour': 'southamerica',
        'heights': 'maps/heights/nomads_americas_north.txt',
        'flow': 'maps/heights/nomads_americas_north.flow.txt',
        'flood': 'maps/heights/nomads_americas_north.flood.txt',
    },
    'south': {
        'path': 'maps/nomads/nomads_americas_south.dmm',
        'metadata': '/obj/map_metadata/nomads/americas_south',
        'edge': 'north',
        'neighbour': 'northamerica',
        'heights': 'maps/heights/nomads_americas_south.txt',
        'flow': 'maps/heights/nomads_americas_south.flow.txt',
        'flood': 'maps/heights/nomads_americas_south.flood.txt',
    },
}
# The size the memory benchmark covers (docs/americas-regions.md): a map may
# not grow past it without a new measurement.
MEASURED_CELLS = 1050000
START = '/obj/effect/landmark{icon_state = "x3"; name = "JoinLateCiv"}'
WATER_WALKABLE = ('/turf/floor/beach/water', '/turf/floor/beach/water/jungle', '/turf/floor/beach/water/swamp',
                  '/turf/floor/beach/water/flooded', '/turf/floor/beach/water/shallowsaltwater',
                  '/turf/floor/beach/water/ice/salty')
BLOCKED = ('/turf/floor/dirt/underground', '/turf/wall', '/turf/floor/lava', '/turf/floor/beach/water/deep')


def read_map(path):
    text = (ROOT / path).read_text(encoding='utf-8')
    keys = {}
    for match in re.finditer(r'^"(\w+)" = \((.*)\)$', text, re.M):
        keys[match.group(1)] = match.group(2)
    blocks = re.findall(r'^\((\d+),(\d+),(\d+)\) = \{"\n(.*?)\n"\}', text, re.M | re.S)
    return keys, blocks


def split_tile(tile):
    """Atoms of one tile definition, in order, honouring {var = "a,b"} blocks."""
    parts, depth, quoted, current = [], 0, False, ''
    for ch in tile:
        if ch == '"':
            quoted = not quoted
        if not quoted:
            if ch == '{':
                depth += 1
            elif ch == '}':
                depth -= 1
            elif ch == ',' and depth == 0:
                parts.append(current)
                current = ''
                continue
        current += ch
    parts.append(current)
    return parts


class Level:
    def __init__(self, name):
        self.spec = MAPS[name]
        keys, blocks = read_map(self.spec['path'])
        self.keys = keys
        self.blocks = blocks
        self.width_of_key = len(next(iter(keys)))
        self.rows = blocks[0][3].split('\n')
        self.height = len(self.rows)
        self.width = len(self.rows[0]) // self.width_of_key
        self.tiles = {key: split_tile(value) for key, value in keys.items()}
        self.turf = {key: next(p for p in parts if p.startswith('/turf/')) for key, parts in self.tiles.items()}

    def key(self, row, col):
        k = self.width_of_key
        return self.rows[row][col * k:(col + 1) * k]

    def walkable(self, key):
        turf = self.turf[key]
        if turf in WATER_WALKABLE:
            return True
        return not turf.startswith(BLOCKED) and 'saltwater' not in turf

    def cells_with(self, atom):
        found = []
        for row in range(self.height):
            for col in range(self.width):
                if atom in self.tiles[self.key(row, col)]:
                    found.append((row, col))
        return found

    def component(self, start):
        seen = {start}
        queue = deque([start])
        while queue:
            row, col = queue.popleft()
            for r, c in ((row - 1, col), (row + 1, col), (row, col - 1), (row, col + 1)):
                if 0 <= r < self.height and 0 <= c < self.width and (r, c) not in seen and self.walkable(self.key(r, c)):
                    seen.add((r, c))
                    queue.append((r, c))
        return seen


class AmericasMapsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.levels = {name: Level(name) for name in MAPS}

    def test_every_land_climate_has_seed_bushes_and_farm_ground_by_fresh_water(self):
        # A nomad starts on a random tile (new_player_start_z), so every climate
        # needs ground that seeds forage bushes and ground a digging stick can
        # work within a crop's reach of fresh water (#3048). Dry grass and
        # desert sand cannot be ploughed; their river banks carry plain soil.
        import importlib.util
        spec = importlib.util.spec_from_file_location('outdoor_bootstrap', ROOT / 'scripts/check-outdoor-bootstrap.py')
        inventory = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(inventory)
        climates, salt = inventory.load_inheritance()
        for name in MAPS:
            report = inventory.audit('americas_' + name, climates, salt)
            self.assertEqual(set(report['farm_ground_by_climate']), set(inventory.LAND_CLIMATES), name)
            for climate, ground in report['farm_ground_by_climate'].items():
                with self.subTest(map=name, climate=climate):
                    self.assertGreaterEqual(report['bush_seeding_ground_by_climate'].get(climate, 0), 500)
                    self.assertGreaterEqual(ground['ploughable_near_water'] + ground['clearable_near_water'], 100)
                    if climate in ('savanna', 'desert', 'semiarid', 'temperate', 'jungle'):
                        self.assertGreaterEqual(ground['ploughable_near_water'], 100)

    def test_each_map_is_one_whole_level_with_even_rows(self):
        for name, level in self.levels.items():
            with self.subTest(name):
                self.assertEqual(len(level.blocks), 1)
                self.assertEqual(level.blocks[0][:3], ('1', '1', '1'))
                self.assertEqual({len(k) for k in level.keys}, {level.width_of_key})
                self.assertEqual({len(row) for row in level.rows}, {level.width * level.width_of_key})
                used = {level.key(r, c) for r in range(level.height) for c in range(level.width)}
                self.assertLessEqual(used, set(level.keys))
                self.assertLessEqual(level.width * level.height, MEASURED_CELLS)

    def test_every_tile_has_one_turf_and_one_area_and_no_macros(self):
        for name, level in self.levels.items():
            with self.subTest(name):
                for key, parts in level.tiles.items():
                    self.assertEqual(sum(p.startswith('/turf/') for p in parts), 1, key)
                    self.assertEqual(sum(p.startswith('/area/') for p in parts), 1, key)
                    self.assertTrue(parts[-1].startswith('/area/') and parts[-2].startswith('/turf/'), key)
                    self.assertNotRegex(level.keys[key], r'\b(TRUE|FALSE)\b')

    def test_metadata_sits_once_in_the_south_west_corner(self):
        for name, level in self.levels.items():
            with self.subTest(name):
                cells = level.cells_with(level.spec['metadata'])
                self.assertEqual(cells, [(level.height - 1, 0)])
                others = [k for k, parts in level.tiles.items() if any('/obj/map_metadata' in p for p in parts)]
                self.assertEqual(len(others), 1)

    def test_land_is_most_of_what_a_region_needs(self):
        for name, level in self.levels.items():
            with self.subTest(name):
                total = level.width * level.height
                ground = sum(1 for r in range(level.height) for c in range(level.width)
                             if level.walkable(level.key(r, c)) and level.turf[level.key(r, c)] not in WATER_WALKABLE)
                # Gaia has about 95,000 tiles of open ground.
                self.assertGreater(ground, 280000)
                self.assertGreater(ground / total, 0.27)

    def test_starts_stand_on_open_ground(self):
        for name, level in self.levels.items():
            with self.subTest(name):
                starts = level.cells_with(START)
                self.assertGreaterEqual(len(starts), 14)
                for row, col in starts:
                    key = level.key(row, col)
                    self.assertTrue(level.walkable(key) and level.turf[key] not in WATER_WALKABLE, (row, col))

    def edge_ground(self, level):
        """Columns of dry ground on the border row the land carries on beyond."""
        row = level.height - 1 if level.spec['edge'] == 'south' else 0
        return row, [col for col in range(level.width)
                     if level.walkable(level.key(row, col)) and level.turf[level.key(row, col)] not in WATER_WALKABLE]

    def test_isthmus_runs_off_its_edge_on_the_mainland(self):
        widths = {}
        for name, level in self.levels.items():
            with self.subTest(name):
                # Nothing stands on the map for the crossing (region_edge.dm).
                gates = [p for parts in level.tiles.values() for p in parts if 'region_gate' in p]
                self.assertEqual(gates, [])
                row, cols = self.edge_ground(level)
                self.assertGreaterEqual(len(cols), 8)
                # One unbroken neck of land, so a place along it means the same on both maps.
                self.assertEqual(cols, list(range(cols[0], cols[-1] + 1)))
                widths[name] = len(cols)
                # Arrivals are put down a few tiles in: that ground is dry too.
                inward = -1 if level.spec['edge'] == 'south' else 1
                for depth in (3, 4, 5):
                    dry = [col for col in cols if level.walkable(level.key(row + inward * depth, col))
                           and level.turf[level.key(row + inward * depth, col)] not in WATER_WALKABLE]
                    self.assertGreaterEqual(len(dry), len(cols) - 4, depth)
                mainland = level.component((row, cols[len(cols) // 2]))
                starts = level.cells_with(START)
                on_mainland = [s for s in starts if s in mainland]
                self.assertGreaterEqual(len(on_mainland), 12)
                ground = sum(1 for r in range(level.height) for c in range(level.width) if level.walkable(level.key(r, c)))
                self.assertGreater(len(mainland) / ground, 0.7)
        # The neck is as wide on both sides, so walkers keep their place across it.
        self.assertEqual(widths['north'], widths['south'])

    def test_land_reaches_other_edges_for_player_built_trails(self):
        # Trail markers are built within ten tiles of a border.
        wanted = {'north': {'west', 'east', 'south'}, 'south': {'north', 'east', 'south'}}
        for name, level in self.levels.items():
            with self.subTest(name):
                found = set()
                for row in range(level.height):
                    for col in range(level.width):
                        key = level.key(row, col)
                        if not level.walkable(key) or level.turf[key] in WATER_WALKABLE:
                            continue
                        if row < 10:
                            found.add('north')
                        if row >= level.height - 10:
                            found.add('south')
                        if col < 10:
                            found.add('west')
                        if col >= level.width - 10:
                            found.add('east')
                self.assertLessEqual(wanted[name], found)

    def test_height_flow_and_flood_files_match_the_maps(self):
        import sys
        import tempfile
        sys.path.insert(0, str(ROOT / 'scripts'))
        import river_flood
        import river_flow
        import terrain_heights
        for name, level in self.levels.items():
            with self.subTest(name):
                heights_path = ROOT / level.spec['heights']
                width, height, by_z = terrain_heights.read_heights(heights_path)
                self.assertEqual(heights_path.read_text(encoding='ascii').split('\n', 1)[0], terrain_heights.HEADER)
                self.assertEqual((width, height, sorted(by_z)), (level.width, level.height, [1]))
                levels = by_z[1]
                rows = [[level.turf[level.key(row, col)] for col in range(level.width)] for row in range(level.height)]
                # Water is level 0, dry ground never is, and the mountains reach the top.
                for row in range(level.height):
                    for col in range(level.width):
                        self.assertEqual(levels[row][col] == 0, 'water' in rows[row][col], (row, col))
                self.assertGreaterEqual(max(max(r) for r in levels), 12)
                # The map and its three files are the set the generator wrote together.
                for kind in ('path', 'heights', 'flow', 'flood'):
                    self.assertEqual(file_digest(ROOT / level.spec[kind]), SIDECARS[name][kind], level.spec[kind])
                # Rebuilding the currents and flood reaches from the map takes over a
                # minute, so it runs on request: AMERICAS_MAPS_REBUILD=1.
                if not os.environ.get('AMERICAS_MAPS_REBUILD'):
                    continue
                flow = river_flow.build(rows, heights=levels)
                text = '%s\nsize %d %d\nz 1\n%s\n' % (river_flow.HEADER, level.width, level.height, '\n'.join(flow))
                self.assertEqual((ROOT / level.spec['flow']).read_text(encoding='ascii'), text)
                self.assertGreater(sum(len(r) - r.count('.') for r in flow), 2000)
                built = river_flood.build(rows, levels)
                with tempfile.TemporaryDirectory() as folder:
                    out = Path(folder) / 'flood.txt'
                    river_flood.write_flood(out, level.width, level.height, 1, *built)
                    self.assertEqual(out.read_bytes(), (ROOT / level.spec['flood']).read_bytes())
                self.assertGreater(len(built[0]), 100)
                self.assertGreater(len(built[3]), 20)

    def test_regions_are_registered_in_source(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertIn('#include "code\\game\\objects\\map_metadata\\nomads\\nomads_americas.dm"', dme)
        defines = (ROOT / 'code/__defines/maps.dm').read_text(encoding='utf-8')
        metadata = (ROOT / 'code/game/objects/map_metadata/nomads/nomads_americas.dm').read_text(encoding='utf-8')
        durable = (ROOT / 'code/modules/persistence/durable_nomads.dm').read_text(encoding='utf-8')
        jobs = (ROOT / 'code/modules/1713/jobs/nomads.dm').read_text(encoding='utf-8')
        for name, spec in MAPS.items():
            with self.subTest(name):
                map_id = f'MAP_NOMADS_AMERICAS_{name.upper()}'
                self.assertIn(f'#define {map_id} "NOMADS_AMERICAS_{name.upper()}"', defines)
                self.assertIn(f"{spec['metadata']}\n\tID = {map_id}", metadata)
                self.assertIn(f'terrain_height_file = "{spec["heights"]}"', metadata)
                self.assertIn(spec['metadata'] + ',', durable)
                self.assertIn(map_id + ',', jobs)

    def test_edges_lead_to_each_other(self):
        # The links live in the world links table (tools/world_links/world_links.json).
        links = (ROOT / 'code/modules/persistence/world_links.dm').read_text(encoding='utf-8')
        for name, spec in MAPS.items():
            with self.subTest(name):
                region = name + 'america'
                self.assertIn(f'"{region}" = list("{spec["edge"]}" = list("{spec["neighbour"]}" = list(0, 1)))', links)
        group = (ROOT / 'scripts/shard-group/americas.example.json').read_text(encoding='utf-8')
        self.assertIn('"id": "northamerica"', group)
        self.assertIn('"id": "southamerica"', group)
        self.assertIn(MAPS['north']['path'], group)
        self.assertIn(MAPS['south']['path'], group)

    def test_edge_crossing_is_wired_into_travel(self):
        edge = (ROOT / 'code/modules/persistence/region_edge.dm').read_text(encoding='utf-8')
        travel = (ROOT / 'code/modules/persistence/region_travel.dm').read_text(encoding='utf-8')
        trails = (ROOT / 'code/modules/persistence/region_trails.dm').read_text(encoding='utf-8')
        human = (ROOT / 'code/game/mob/living/carbon/human/human.dm').read_text(encoding='utf-8')
        # The crossing travels in the payload, is validated on arrival and places the walker.
        self.assertIn('if(!region_edge_payload_ok(P)) return null', travel)
        self.assertIn('region_edge_arrival_turf(P, incoming) ||', travel)
        self.assertIn('\t\t\tregion_edge_check()\n', human)
        # The hidden gate is never saved, never an arrival point, and asks through travel().
        gate = edge.split('/obj/structure/region_gate/land_edge\n')[1].split('\n\n')[0]
        self.assertIn('should_save = FALSE', gate)
        self.assertIn('invisibility = 101', gate)
        self.assertIn('/obj/structure/region_gate/land_edge/accepts_arrivals()\n\treturn FALSE', edge)
        self.assertIn('\tgate.travel(src)\n', edge)
        # The ask lock never rides a save (civ13 saves tmp vars too).
        self.assertIn('return key == "region_edge_asking" || key == "region_edge_asked_at" || ..()', edge)
        # Drivers and draggers are told why, in plain words.
        self.assertIn('if (H.buckled || H.driver || H.driver_vehicle) return "You cannot drive across yet. Get down and walk on."', edge)
        # A rider takes the mount: recorded before the ask, removed only once the rider left,
        # validated on arrival, and never carried without an edge crossing.
        self.assertIn('"voyage", "ship", "edge", "mount", "led", "cart", "bike", "wagon"', travel)
        self.assertIn('if ((H.riding || H.riding_mob) && !region_edge_mount_record(H)) return', edge)
        self.assertIn('if (took_mount && QDELETED(src) && !QDELETED(steed))', edge)
        self.assertIn('return ispath(path, /mob/living/simple_animal) && initial(A.can_ride)', edge)
        ok = edge.split('/proc/region_edge_payload_ok(list/P)\n')[1].split('\n\n')[0]
        self.assertIn('return isnull(P["mount"]) && isnull(P["led"]) && isnull(P["cart"]) && isnull(P["bike"]) && isnull(P["wagon"])', ok)
        self.assertIn('region_edge_bike_valid(P["bike"])', ok)
        # A carriage is packed whole as its driver leaves (team in harness, shut
        # crates), comes back if they could not leave, and only a driver at the
        # border is asked; passengers and anything that cannot be rebuilt keep it here.
        self.assertIn('region_edge_wagon_valid(P["wagon"])', ok)
        wagon = (ROOT / 'code/modules/persistence/region_edge_carriage.dm').read_text(encoding='utf-8').replace('\r\n', '\n')
        self.assertIn('#include "code\\modules\\persistence\\region_edge_carriage.dm"', (ROOT / 'civ13.dme').read_text(encoding='utf-8'))
        self.assertIn('var/list/driven = pack_wagon(H)', edge)
        self.assertIn('\trelease_wagon()\n', edge)
        self.assertIn('region_edge_wagon_arrived(H, P, side)', edge)
        self.assertIn('return "Passengers have to get down and walk across themselves."', wagon)
        self.assertIn('if (!istype(crate) || crate.opened)', wagon)
        self.assertIn('A.wild || A.rider || !region_edge_wagon_draft_ok(A.type)', wagon)
        self.assertIn('if (!islist(E) || E.len != 2 || !region_travel_worn_valid(E[1], E[2]))', wagon)
        self.assertLess(wagon.index('C.let_off(src, T)'), wagon.index('gate.travel(src)'))
        carriage = (ROOT / 'code/game/objects/structures/carriage.dm').read_text(encoding='utf-8').replace('\r\n', '\n')
        self.assertIn('\t\tif (!region_edge_reached(m_dir))\n\t\t\trefuse("\\The [src] cannot go further that way.")', carriage)
        # A bicycle's rider gets off at the edge and it is wheeled over; riding one
        # onto the edge asks like a walk does. The pedal airship never crosses.
        self.assertIn('!ispath(path, /obj/structure/vehicle/bicycle/airship)', edge)
        self.assertLess(edge.index('ridden.unbuckle_mob()'), edge.index('gate.travel(src)'))
        bicycle = (ROOT / 'code/game/objects/structures/bicycle.dm').read_text(encoding='utf-8').replace('\r\n', '\n')
        self.assertLess(bicycle.index('H.forceMove(target)\n'), bicycle.index('H.region_edge_ride()'))
        self.assertIn('region_edge_cart_valid(P["cart"])', ok)
        self.assertIn('region_edge_mount_valid(P["led"], TRUE)', ok)
        # An animal led by hand goes the same way; anything else dragged stays.
        self.assertIn('if (H.pulling && !region_edge_led_record(H))', edge)
        # A pulled hand cart or travois is recorded as its puller leaves and held in
        # the gate from then on, so its load cannot change; it comes back if they stay.
        extra = edge[edge.index('/obj/structure/region_gate/land_edge/travel_extra'):edge.index('/obj/structure/region_gate/land_edge/attack_hand')]
        self.assertLess(extra.index('region_edge_cart_record(H)'), extra.index('cart.forceMove(src)'))
        self.assertIn('/obj/structure/region_gate/land_edge/Destroy()\n\trelease_cart()', edge)
        self.assertIn('return ispath(path, /obj/structure/closet/crate/cart) || ispath(path, /obj/structure/closet/crate/travois)', edge)
        self.assertIn('!region_travel_worn_valid(E[1], E[2])', edge)
        self.assertIn('if (took_led && QDELETED(src) && !QDELETED(beast))', edge)
        self.assertIn('region_edge_mount_valid(P["mount"])', ok)
        self.assertIn('\t\t\tregion_edge_replayed(H, P)\n', travel)
        # No trail posts drawn on maps any more.
        self.assertNotIn('trail_marker/authored', trails)


if __name__ == '__main__':
    unittest.main()
