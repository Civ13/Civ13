"""Execute the selected production flooding loops offline; no BYOND is launched."""
from copy import deepcopy
from pathlib import Path
from types import SimpleNamespace
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).parent
DIRECTIONS = ('NORTH', 'SOUTH', 'EAST', 'WEST')
OPPOSITE = dict(zip(DIRECTIONS, ('SOUTH', 'NORTH', 'WEST', 'EAST')))


def source():
    return (ROOT / 'code/modules/submarine/flooding_controller.dm').read_text()


def block(text):
    start = text.index('\t// Bulkhead integrity check:')
    return text[start:text.index('\t// A vessel lists and sinks', start)]


def project(text):
    """Translate every executable line of this bounded pair of loops."""
    declaration = re.search(r'var/static/list/flood_directions = list\(([^\n]+)\)', text)
    directions = tuple(x.strip() for x in declaration[1].split(',')) if declaration else ()
    lines = ['def run(sub_bulkheads, sub_blast_doors, src):']
    for raw in block(text).splitlines():
        code = raw.split('//', 1)[0].rstrip()
        if not code.strip():
            continue
        depth = len(code) - len(code.lstrip('\t'))
        code = code.strip()
        code = re.sub(r'for\(var/(?:[\w/]+/)?(\w+) in (.+)\)', r'for \1 in \2:', code)
        code = re.sub(r'var/(?:[\w/]+/)?(\w+) = ', r'\1 = ', code)
        code = code.replace('B.health > 0 ? 0.1 : 0.25', '(0.1 if B.health > 0 else 0.25)')
        code = code.replace('B.health > 0 ? 3 : 8', '(3 if B.health > 0 else 8)')
        code = code.replace(' || ', ' or ').replace(' && ', ' and ')
        code = re.sub(r'!(?!=)', 'not ', code)
        if code.startswith('if('):
            match = re.fullmatch(r'if\((.*)\)( continue)?', code)
            if not match:
                raise AssertionError(code)
            code = 'if ' + match[1] + ':' + (' continue' if match[2] else '')
        lines.append('    ' * depth + code)
    env = dict(zip(DIRECTIONS, DIRECTIONS))
    env.update(flood_directions=directions, min=min,
               QDELETED=lambda x: x.deleted, istype=lambda x: x is not None,
               get_step=lambda x, direction: x.neighbors.get(direction),
               turn=lambda direction, angle: OPPOSITE[direction],
               list=lambda *items: list(items))
    exec('\n'.join(lines), env)
    return env['run']


class Registry(list):
    def Copy(self):
        return Registry(self)

    def __isub__(self, value):
        self.remove(value)
        return self


class Tile:
    def __init__(self, amount, owner='ours', sealed=False):
        self.water_depth = amount
        self.flooding_owner = owner
        self.water_sealed = sealed
        self.transfers = []

    def add_water(self, amount):
        self.water_depth += amount
        self.transfers.append(amount)


def opening(kind, first=100, opposite=9.5, health=25, owner='ours', sealed=False):
    a, b = Tile(first, owner), Tile(opposite, sealed=sealed)
    obj = SimpleNamespace(deleted=False, watertight=False, health=health, state=True,
                          neighbors={'NORTH': a, 'SOUTH': b})
    return obj, (a, b)


def result(impl, bulkheads, doors):
    bulkheads, doors = deepcopy((bulkheads, doors))
    tiles = [t for obj in bulkheads + doors for t in obj.neighbors.values()]
    impl(Registry(bulkheads), Registry(doors), 'ours')
    return [(t.water_depth, t.transfers) for t in tiles]


class FloodingDirectionsTests(unittest.TestCase):
    def test_only_direction_storage_changes(self):
        # Freeze only the reviewed loops, not unrelated controller procedures.
        before = (HERE / 'before.dm.txt').read_text()
        self.assertEqual(block(source()), before.replace(
            'list(NORTH, SOUTH, EAST, WEST)', 'flood_directions'))
        self.assertEqual(source().count('var/static/list/flood_directions = '), 1)
        self.assertIn('var/static/list/flood_directions = list(NORTH, SOUTH, EAST, WEST)', source())

    def test_bulkhead_and_door_flows_match_in_each_orientation(self):
        old = project((HERE / 'before.dm.txt').read_text() + '\t// A vessel lists and sinks')
        new = project(source())
        for kind in ('bulkhead', 'door'):
            for direction in DIRECTIONS:
                for health in (25, 0, -10):
                    obj, _ = opening(kind, health=health)
                    obj.neighbors = {direction: obj.neighbors['NORTH'],
                                     OPPOSITE[direction]: obj.neighbors['SOUTH']}
                    args = ([obj], []) if kind == 'bulkhead' else ([], [obj])
                    with self.subTest(kind=kind, direction=direction, health=health):
                        self.assertEqual(result(old, *args), result(new, *args))

    def test_skipped_openings_and_empty_registries(self):
        impl = project(source())
        self.assertEqual(result(impl, [], []), [])
        for changes in (dict(deleted=True), dict(watertight=True)):
            obj, _ = opening('bulkhead')
            obj.__dict__.update(changes)
            self.assertEqual(result(impl, [obj], []), [(100, []), (9.5, [])])
        for changes in (dict(deleted=True), dict(state=False)):
            obj, _ = opening('door')
            obj.__dict__.update(changes)
            self.assertEqual(result(impl, [], [obj]), [(100, []), (9.5, [])])
        for kind in ('bulkhead', 'door'):
            for options in (dict(owner='another'), dict(sealed=True), dict(first=10, opposite=0)):
                obj, _ = opening(kind, **options)
                args = ([obj], []) if kind == 'bulkhead' else ([], [obj])
                self.assertEqual(result(impl, *args), result(project(
                    (HERE / 'before.dm.txt').read_text() + '\t// A vessel lists and sinks'), *args))

    def test_direction_order_negative_control_changes_actual_water(self):
        good = project(source())
        bad = project(source().replace('list(NORTH, SOUTH, EAST, WEST)',
                                       'list(SOUTH, NORTH, EAST, WEST)', 1))
        for kind in ('bulkhead', 'door'):
            obj, _ = opening(kind)
            args = ([obj], []) if kind == 'bulkhead' else ([], [obj])
            expected = result(good, *args)
            self.assertNotEqual(expected, result(bad, *args))
            self.assertEqual(expected, [(101.25, [1.25]), (12.5, [3])])
            self.assertTrue(all(row[0] >= 0 for row in expected))


if __name__ == '__main__':
    unittest.main()
