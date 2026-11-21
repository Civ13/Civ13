"""Exercise the production graph traversal with fake tile/engine boundaries."""
import importlib.util
import json
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/1713/physical_data_lan.dm').read_text()
spec = importlib.util.spec_from_file_location(
    'lan_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)

NORTH, SOUTH, EAST, WEST = 1, 2, 4, 8
DIRS = {NORTH: (0, 1), SOUTH: (0, -1), EAST: (1, 0), WEST: (-1, 0)}
OPPOSITE = {NORTH: SOUTH, SOUTH: NORTH, EAST: WEST, WEST: EAST}


class DMList(list):
    @property
    def len(self):
        return len(self)

    def __getitem__(self, index):
        return super().__getitem__(index - 1)

    def __iadd__(self, item):
        self.append(item)
        return self


class Segment:
    def __init__(self, position, ports, live=True):
        self.position, self.port_mask, self.live = position, ports, live
        self.z = position[2]
        self.vertical_neighbor = None

    def valid_segment(self):
        return self.live

    def data_riser_neighbor(self):
        return self.vertical_neighbor


def graph(*segments):
    by_position = {s.position: s for s in segments}

    def step(segment, side):
        x, y, z = segment.position
        dx, dy = DIRS[side]
        n = by_position.get((x + dx, y + dy, z))
        return SimpleNamespace(z=z, segment=n) if n else None

    # Translate DM list representation and indexed post-increment explicitly;
    # adapter executes the remaining production control flow without mock edges.
    source = SOURCE.replace('var/list/seen = list()', 'var/list/seen = DMMap()')
    source = source.replace('pending[cursor++]', 'pending[cursor]\n\t\tcursor += 1')
    source = source.replace(
        'locate(/obj/structure/data_lan_cable) in T', 'T.segment')
    source = source.replace('for (var/side in sides)', 'for (side in sides)')
    source = source.replace('while (cursor <= pending.len)', 'while (cursor <= pending.len):')
    # Read the configured traversal bound from source, not from the fixture.
    limit = next(int(line.split()[-1]) for line in SOURCE.splitlines()
                 if line.startswith('#define CIV_DATA_LAN_MAX_SEGMENTS '))
    return adapter.project(source, '/proc/civ_data_lan_component', 'start', dict(
        list=lambda *items: DMList(items),
        DMMap=lambda: __import__('collections').defaultdict(bool),
        get_step=step, turn=lambda side, _: OPPOSITE[side],
        NORTH=NORTH, SOUTH=SOUTH, EAST=EAST, WEST=WEST,
        CIV_DATA_LAN_MAX_SEGMENTS=limit))


class PhysicalLANTests(unittest.TestCase):
    def test_reciprocal_ports_only_same_level_no_diagonals(self):
        a = Segment((1, 1, 1), 15)
        b = Segment((2, 1, 1), WEST)
        wrong_way = Segment((1, 2, 1), NORTH)
        vertical = Segment((1, 1, 2), 15)
        diagonal = Segment((0, 0, 1), 15)
        self.assertEqual({s for s, yes in graph(a, b, wrong_way, vertical, diagonal)(a).items() if yes}, {a, b})

    def test_cut_breaks_path_and_loop_can_reroute(self):
        a = Segment((1, 1, 1), 15)
        b = Segment((2, 1, 1), 15)
        c = Segment((3, 1, 1), 15)
        loop = [Segment((x, 2, 1), 15) for x in (1, 2, 3)]
        b.live = False
        self.assertFalse(graph(a, b, c)(a).get(c))
        self.assertTrue(graph(a, b, c, *loop)(a)[c])
        b.live = True
        self.assertTrue(graph(a, b, c)(a)[c])

    def test_over_budget_network_never_returns_partial_path(self):
        line = [Segment((x, 1, 1), EAST | WEST) for x in range(1, 258)]
        self.assertEqual(sum(graph(*line[:256])(line[0]).values()), 256)
        self.assertIsNone(graph(*line)(line[0]))
        self.assertIsNone(graph(*line)(None))

    def test_water_admission_requires_respective_jacket_and_nondense_turf(self):
        dry = SimpleNamespace(water=False, density=False)
        wet = SimpleNamespace(water=True, density=False)
        wall = SimpleNamespace(water=True, density=True)
        source = SOURCE.replace('/turf/floor/beach/water)', 'WATER)')
        admission = adapter.project(source, '/proc/civ_data_lan_site', 'T, sealed', {
            'civ_data_lan_land': lambda t: t is dry,
            'istype': lambda t, _: t is not None and t.water,
            'WATER': 'water',
        })
        self.assertTrue(admission(dry, False))
        self.assertTrue(admission(dry, True))
        self.assertFalse(admission(wet, False))
        self.assertTrue(admission(wet, True))
        self.assertFalse(admission(wall, True))
        self.assertFalse(admission(None, True))

    def test_same_plane_shore_route_stays_passive_and_costs_jacket(self):
        shore = Segment((1, 1, 1), EAST)
        sea = Segment((2, 1, 1), EAST | WEST)
        far = Segment((3, 1, 1), WEST)
        self.assertTrue(graph(shore, sea, far)(shore)[far])
        self.assertFalse(graph(shore, far)(shore).get(far))
        terminal = adapter.extract(SOURCE, '/obj/structure/telecom/terminal/data_lan/operational')
        self.assertIn('civ_data_lan_land(loc) && ..()', terminal)
        path = '/obj/item/stack/data_lan_cable/sealed'
        costs = json.loads((ROOT / 'config/craft_needs.json').read_text())
        self.assertEqual(costs[path]['inputs']['/obj/item/stack/material/plastic'], 1)
        self.assertIn('"' + path + '" = "electricity"', (ROOT / 'code/modules/research_tree/research_node.dm').read_text())

    def test_vertical_tile_pair_matches_only_open_ocean_and_actual_seabed(self):
        class Tile:
            def __init__(self, x, y, z, kind):
                self.x, self.y, self.z, self.kind = x, y, z, kind
                self.covered = False

            def iscovered(self):
                return self.covered

        surface = Tile(5, 2, 1, 'ocean')
        seabed = Tile(5, 2, 9, 'seabed')
        other = Tile(6, 2, 9, 'seabed')
        slots = {(t.x, t.y, t.z): t for t in (surface, seabed, other)}
        env = dict(map=SimpleNamespace(sea_layer_surface_z=1),
                   multiz_level_below=lambda z: 9 if z == 1 else 0,
                   multiz_level_above=lambda z: 1 if z == 9 else 0,
                   locate=lambda x, y, z: slots.get((x, y, z)),
                   sea_layer_open_surface=lambda t: t is not None and t.kind == 'ocean',
                   sea_layer_cell=lambda t: t is not None and t.kind == 'seabed')
        paired = adapter.project(SOURCE, '/proc/civ_data_lan_riser_tile', 'T', env)
        self.assertIs(paired(surface), seabed)
        self.assertIs(paired(seabed), surface)
        self.assertIsNone(paired(other))
        seabed.covered = True
        self.assertIsNone(paired(surface))
        self.assertIsNone(paired(seabed))
        seabed.covered = False
        seabed.kind = 'rock'
        self.assertIsNone(paired(surface))
        self.assertIsNone(paired(seabed))
        seabed.kind = 'seabed'
        env['multiz_level_above'] = lambda z: 0
        self.assertIsNone(paired(surface))
        self.assertIsNone(paired(seabed))

    def test_riser_requires_two_enabled_sealed_live_segments(self):
        transformed = SOURCE.replace('istype(src, /obj/structure/data_lan_cable/sealed)', 'src.sealed')
        transformed = transformed.replace('!vertical_feed || !valid_segment()', '!src.vertical_feed || !src.valid_segment()')
        transformed = transformed.replace('civ_data_lan_riser_tile(loc)', 'civ_data_lan_riser_tile(src.loc)')
        transformed = transformed.replace('locate(/obj/structure/data_lan_cable/sealed) in T', 'T.segment if T.segment.sealed else None')
        far = Segment((3, 1, 9), 15)
        far.sealed = True
        far.vertical_feed = True
        near = Segment((3, 1, 1), 15)
        near.sealed = True
        near.vertical_feed = True
        near.loc = SimpleNamespace(partner=SimpleNamespace(segment=far))
        neighbor = adapter.project(
            transformed, '/obj/structure/data_lan_cable/proc/data_riser_neighbor',
            'src', {'civ_data_lan_riser_tile': lambda t: t.partner})
        self.assertIs(neighbor(near), far)
        for part, key in ((near, 'vertical_feed'), (far, 'vertical_feed'),
                          (near, 'sealed'), (far, 'sealed'), (far, 'live')):
            setattr(part, key, False)
            self.assertIsNone(neighbor(near), (part, key))
            setattr(part, key, True)
        near.loc.partner = None
        self.assertIsNone(neighbor(near))

    def test_vertical_edges_count_toward_same_limit_and_disconnect(self):
        deck = [Segment((x, 1, 1), EAST | WEST) for x in range(1, 257)]
        sea = Segment((1, 1, 9), EAST | WEST)
        self.assertFalse(graph(*deck, sea)(deck[0]).get(sea))
        deck[0].vertical_neighbor = sea
        sea.vertical_neighbor = deck[0]
        self.assertTrue(graph(*deck[:-1], sea)(deck[0]).get(sea))
        self.assertIsNone(graph(*deck, sea)(deck[0]))

    def test_transport_isolates_legacy_receivers_and_rechecks_target(self):
        terminal = (ROOT / 'code/modules/1713/modern_terminal.dm').read_text()
        self.assertIn('istype(T, /obj/structure/telecom/terminal/data_lan)', terminal)
        send = adapter.extract(SOURCE.split('#undef CIV_DATA_LAN_MAX_SEGMENTS')[0], '/obj/structure/telecom/terminal/data_lan/proc/deliver_data_message')
        self.assertIn('!operational() || !target.operational()', send)
        self.assertIn('!component[destination]', send)
        self.assertLess(send.index('!component[destination]'), send.index('last_message = world.time'))
        self.assertLess(send.index('last_message = world.time'), send.index('to_chat('))


if __name__ == '__main__':
    unittest.main()
