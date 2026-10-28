"""Offline projection of the production grid helper; no BYOND world is started."""
import math
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/objects/map_metadata/the_art_of_the_deal.dm'
DEFINES = dict(re.findall(r'^#define (MAP_\w+) "([^"]+)"',
                         (ROOT / 'code/__defines/maps.dm').read_text(), re.M))
CAMPAIGNS = ['MAP_CAMPAIGN', 'MAP_CAMPAIGN_NEW'] + [
    f'MAP_CAMPAIGN_{n}{side}' for n in range(1, 5) for side in 'AB']
AOTD = DEFINES['MAP_THE_ART_OF_THE_DEAL']


def project(source):
    """Translate only the helper's small arithmetic/switch subset, failing closed.

    This executes expressions and ID cases read from DM, rather than copying the
    corrected formulas. It is a source model, not native DM/runtime evidence.
    """
    proc = re.search(r'^/atom/proc/get_coded_loc\(\)\n(.*?)(?=^/|\Z)',
                     source, re.M | re.S)[1]
    output = ['def grid(map_id, x, y):']
    switch = None
    seen_case = False
    for raw in proc.splitlines():
        line = raw.strip()
        if not line or line.startswith('//'):
            continue
        depth = len(raw) - len(raw.lstrip('\t'))
        if line.startswith('switch('):
            switch = line[7:-1].replace('map.ID', 'map_id')
            if switch not in ('map_id', 'a') or depth != 1:
                raise ValueError('unsupported switch')
            seen_case = False
            continue
        case = re.fullmatch(r'if \((.*?)\)', line)
        if case:
            if depth != 2 or switch is None:
                raise ValueError('unsupported case')
            values = case[1].split(', ')
            if switch == 'map_id':
                if any(value not in DEFINES for value in values):
                    raise ValueError('unsupported map case')
                condition = f'map_id in {tuple(DEFINES[v] for v in values)!r}'
            else:
                bounds = re.fullmatch(r'(\d+) to (\d+)', case[1])
                if not bounds:
                    raise ValueError('unsupported column case')
                condition = f'{bounds[1]} <= a <= {bounds[2]}'
            output.append('    ' + ('elif ' if seen_case else 'if ') + condition + ':')
            seen_case = True
            continue
        assignment = re.fullmatch(r'(?:var/)?(cell_width|cell_height|a|b) = (.+)', line)
        if assignment:
            if depth not in (1, 3):
                raise ValueError('unsupported assignment')
            expression = assignment[2]
            if not re.fullmatch(r'[0-9A-Ja-z_"()+/ -]+', expression):
                raise ValueError('unsupported arithmetic')
            output.append('    ' * (2 if depth == 3 else 1) +
                          assignment[1] + ' = ' + expression)
            continue
        if line == 'return "[a][b]"' and depth == 1:
            output.append('    return f"{a}{b}"')
            continue
        raise ValueError('unhandled helper statement: ' + line)
    namespace = {'ceil': math.ceil, 'Floor': math.floor, '__builtins__': {}}
    exec('\n'.join(output), namespace)
    return namespace['grid']


class CodedLocationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = SOURCE.read_text(encoding='utf-8')
        cls.grid = staticmethod(project(cls.source))

    def test_reported_coordinates(self):
        self.assertEqual(self.grid(AOTD, 47, 142), 'C4')
        self.assertEqual(self.grid(AOTD, 74, 220), 'D1')

    def test_every_tile_and_cell_boundary_in_supported_grids(self):
        # Independent oracle enumerates each cell and its one-based tile ranges.
        grids = [(AOTD, 22, 22), ('OPERATION_FALCON', 40, 40)]
        grids += [(DEFINES[name], 15, 10) for name in CAMPAIGNS]
        for map_id, width, height in grids:
            with self.subTest(map_id=map_id):
                for column, letter in enumerate('ABCDEFGHIJ'):
                    for row in range(1, 11):
                        expected = f'{letter}{row}'
                        for x in range(column * width + 1, (column + 1) * width + 1):
                            for y in range((10 - row) * height + 1, (11 - row) * height + 1):
                                actual = self.grid(map_id, x, y)
                                if actual != expected:
                                    self.fail(f'{map_id} ({x},{y}): {actual} != {expected}')

    def test_four_edges_and_corners(self):
        for map_id, width, height in [(AOTD, 220, 220),
                                      (DEFINES['MAP_CAMPAIGN_NEW'], 150, 100),
                                      (DEFINES['MAP_OPERATION_FALCON'], 400, 400)]:
            for x, y, expected in [(1, 1, 'A10'), (width, 1, 'J10'),
                                   (1, height, 'A1'), (width, height, 'J1')]:
                with self.subTest(map_id=map_id, x=x, y=y):
                    self.assertEqual(self.grid(map_id, x, y), expected)
            for x in range(1, width + 1):
                self.assertTrue(self.grid(map_id, x, 1).endswith('10'))
                self.assertTrue(self.grid(map_id, x, height).endswith('1'))
            for y in range(1, height + 1):
                self.assertTrue(self.grid(map_id, 1, y).startswith('A'))
                self.assertTrue(self.grid(map_id, width, y).startswith('J'))

    def test_every_other_declared_map_keeps_default_sizing(self):
        special = {DEFINES[name] for name in CAMPAIGNS + ['MAP_OPERATION_FALCON']}
        for name, map_id in DEFINES.items():
            if map_id not in special:
                with self.subTest(name=name):
                    self.assertEqual(self.grid(map_id, 47, 142), 'C4')
                    self.assertEqual(self.grid(map_id, 74, 220), 'D1')

    def test_authored_falcon_edges_with_partial_top_and_right_cells(self):
        map_id = DEFINES['MAP_OPERATION_FALCON']
        for x, y, expected in [(1, 1, 'A10'), (390, 1, 'J10'),
                               (1, 390, 'A1'), (390, 390, 'J1'),
                               (360, 360, 'I2'), (361, 361, 'J1')]:
            self.assertEqual(self.grid(map_id, x, y), expected)

    def test_authored_dimensions_and_legacy_campaign_frame_limit(self):
        # Do not silently redefine cell sizes to fit irregular campaign maps.
        expected = {'campaign1a': (241, 109, 1), 'campaign1b': (241, 109, 1),
                    'campaign2a': (251, 197, 1), 'campaign2b': (251, 197, 1),
                    'campaign3a': (359, 159, 2), 'campaign3b': (359, 159, 2),
                    'campaign4a': (89, 153, 4), 'campaign4b': (89, 153, 4),
                    'operation_falcon': (390, 390, 2)}
        for name, dimensions in expected.items():
            folder = 'milsim' if name == 'operation_falcon' else 'campaign'
            source = (ROOT / f'maps/{folder}/{name}.dmm').read_text()
            key_width = len(re.search(r'^"([A-Za-z]+)" =', source, re.M)[1])
            extents = []
            for block in re.finditer(r'^\((\d+),(\d+),(\d+)\) = \{"\n(.*?)"\}',
                                     source, re.M | re.S):
                rows = block[4].strip('\n').splitlines()
                extents.append((int(block[1]) + len(rows[0]) // key_width - 1,
                                int(block[2]) + len(rows) - 1, int(block[3])))
            self.assertEqual(tuple(max(e[i] for e in extents) for i in range(3)), dimensions)

    def test_historical_row_math_negative_control(self):
        broken = project(self.source.replace('(y-1)/cell_height', 'y/cell_height'))
        self.assertEqual(broken(AOTD, 74, 220), 'D0')
        self.assertNotEqual(broken(AOTD, 1, 22), 'A10')

    def test_campaign_leak_negative_control(self):
        broken = project(self.source.replace('var/cell_width = 22', 'var/cell_width = 15')
                         .replace('var/cell_height = 22', 'var/cell_height = 10'))
        self.assertNotEqual(broken(AOTD, 47, 142), 'C4')
        self.assertNotEqual(broken(AOTD, 74, 220), 'D1')

    def test_numeric_hud_coordinates_are_preserved(self):
        self.assertIn('([parentmob.x],[parentmob.y])', self.source)

    def test_unhandled_source_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'unhandled helper statement'):
            project(self.source.replace('var/a = ceil(x/cell_width)', 'sleep(1)'))


if __name__ == '__main__':
    unittest.main()
