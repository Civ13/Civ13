"""Offline checks for the generated Crossroads Mall raid and loot test range.

These parse the checked-in DMM, compare it with the generator, project the loot
tables from the DM source and flood-fill walking routes. They do not compile or
run BYOND, so they are not native movement, lighting or loot acceptance.

Run from the repository root:
    python3 -I -B -m unittest tests/crossroads_mall/test_crossroads_mall.py
"""
from collections import deque
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import build  # noqa: E402

MAP = ROOT / 'maps' / 'EFT' / 'crossroads_mall.dmm'
METADATA = ROOT / 'code' / 'game' / 'objects' / 'map_metadata' / 'crossroads_mall.dm'
LOOTDROP_SOURCE = ROOT / 'code' / 'game' / 'objects' / 'effects' / 'spawners' / 'loot.dm'
RANDOM_SOURCE = ROOT / 'code' / 'game' / 'objects' / 'random.dm'
DEFINITION = re.compile(r'^"([a-z]{2})" = \((.*)\)$')
SIGNS = ('/obj/structure/sign/crossroads',)


def split_atoms(body):
    """Split a tile definition on top-level commas, keeping {var} blocks intact."""
    atoms, depth, current = [], 0, []
    for char in body:
        if char == '{':
            depth += 1
        elif char == '}':
            depth -= 1
        if char == ',' and depth == 0:
            atoms.append(''.join(current))
            current = []
        else:
            current.append(char)
    atoms.append(''.join(current))
    return atoms


def parse(text):
    definitions, lines = {}, text.split('\n')
    index = 0
    while index < len(lines) and lines[index]:
        match = DEFINITION.match(lines[index])
        if not match:
            raise ValueError(f'Bad definition line {index + 1}: {lines[index][:60]}')
        definitions[match.group(1)] = split_atoms(match.group(2))
        index += 1
    index += 1
    if lines[index] != '(1,1,1) = {"':
        raise ValueError('Expected a single z level starting at (1,1,1)')
    rows = []
    index += 1
    while lines[index] != '"}':
        rows.append(lines[index])
        index += 1
    if any(line for line in lines[index + 1:]):
        raise ValueError('Trailing content after the grid')
    return definitions, rows


class Map:
    def __init__(self, text):
        self.definitions, rows = parse(text)
        self.height = len(rows)
        self.width = len(rows[0]) // 2
        self.cells = {}
        for row_index, row in enumerate(rows):
            y = self.height - row_index
            if len(row) != self.width * 2:
                raise ValueError(f'Row {row_index + 1} has {len(row)} characters, expected {self.width * 2}')
            for x in range(1, self.width + 1):
                key = row[(x - 1) * 2:(x - 1) * 2 + 2]
                self.cells[(x, y)] = self.definitions[key]

    def atoms(self, x, y):
        return self.cells[(x, y)]

    def turf(self, x, y):
        return self.atoms(x, y)[-2]

    def area(self, x, y):
        return self.atoms(x, y)[-1]

    def objects(self, x, y):
        return self.atoms(x, y)[:-2]

    def find(self, prefix):
        """Yield (x, y, atom) for objects whose path starts with the prefix."""
        for (x, y), atoms in self.cells.items():
            for atom in atoms[:-2]:
                if atom.split('{', 1)[0] == prefix or atom.startswith(prefix + '{'):
                    yield x, y, atom

    def footprint_blocked(self):
        blocked = set()
        for (x, y), atoms in self.cells.items():
            for atom in atoms[:-2]:
                base = atom.split('{', 1)[0]
                if base in build.FOOTPRINTS:
                    w, h = build.FOOTPRINTS[base]
                    for dx in range(w):
                        for dy in range(h):
                            blocked.add((x + dx, y + dy))
        return blocked

    def walkable(self, keyed_open=False, grace_open=True):
        blocked = self.footprint_blocked()
        cells = set()
        for (x, y), atoms in self.cells.items():
            if (x, y) in blocked:
                continue
            if atoms[-2] in build.DENSE_TURFS:
                continue
            if not grace_open and atoms[-1] == build.GRACE:
                continue
            if any(build.blocks(atom, keyed_open) for atom in atoms[:-2]):
                continue
            cells.add((x, y))
        return cells

    @staticmethod
    def reachable(cells, start):
        seen, queue = {start}, deque([start])
        if start not in cells:
            return seen
        while queue:
            x, y = queue.popleft()
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if (nx, ny) in cells and (nx, ny) not in seen:
                    seen.add((nx, ny))
                    queue.append((nx, ny))
        return seen


def source_tables():
    """Every concrete loot table a map can place, projected from the DM source."""
    lootdrop = re.findall(r'^(/obj/effect/spawner/lootdrop/[\w/]+)\n\tname', LOOTDROP_SOURCE.read_text(encoding='utf-8'), re.M)
    random_text = re.sub(r'/\*.*?\*/', '', RANDOM_SOURCE.read_text(encoding='utf-8'), flags=re.S)
    randoms = set(re.findall(r'^(/obj/random/[\w/]+)/spawn_choices\(\)', random_text, re.M))
    randoms |= set(re.findall(r'^(/obj/random/[\w/]+)/New\(\)', random_text, re.M))
    randoms -= {'/obj/random/single', '/obj/random/proc'}
    # Snowy trees share one spawn_choices override under a different parent path.
    randoms |= set(re.findall(r'^(/obj/random/plants/tree_snow[\w]*)\n\tname', random_text, re.M))
    randoms -= {path for path in randoms if path.endswith('/snow')}
    return set(lootdrop) | randoms


class CrossroadsMallTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = MAP.read_text(encoding='utf-8')
        cls.map = Map(cls.text)

    def test_generator_reproduces_checked_in_map(self):
        self.assertEqual(build.generate(), self.text, 'Regenerate with tests/crossroads_mall/build.py; do not hand-edit the map')

    def test_single_level_dimensions_and_uniform_keys(self):
        self.assertEqual((self.map.width, self.map.height), (build.WIDTH, build.HEIGHT))
        self.assertTrue(all(len(key) == 2 for key in self.map.definitions))
        self.assertLessEqual(len(self.map.definitions), 676)
        for x in range(1, self.map.width + 1):
            self.assertEqual(self.map.turf(x, 1), build.BORDER)
            self.assertEqual(self.map.turf(x, self.map.height), build.BORDER)
        for y in range(1, self.map.height + 1):
            self.assertEqual(self.map.turf(1, y), build.BORDER)
            self.assertEqual(self.map.turf(self.map.width, y), build.BORDER)

    def test_definitions_use_literal_values_only(self):
        for atoms in self.map.definitions.values():
            for atom in atoms:
                if '{' not in atom:
                    continue
                for assignment in atom[atom.index('{') + 1:-1].split('; '):
                    key, value = assignment.split(' = ', 1)
                    self.assertTrue(value.startswith('"') or re.fullmatch(r'-?\d+', value), assignment)
                    self.assertNotIn('TRUE', value)
                    self.assertNotIn('FALSE', value)

    def test_every_type_path_is_defined_in_dm_source(self):
        paths = set()
        for atoms in self.map.definitions.values():
            for atom in atoms:
                paths.add(atom.split('{', 1)[0])
        source = '\n'.join(path.read_text(encoding='utf-8', errors='replace') for path in (ROOT / 'code').rglob('*.dm'))
        defined = set(re.findall(r'^(/(?:obj|turf|area|mob)/[\w/]+)', source, re.M))
        # A proc or var defined on a path also declares that type.
        defined |= set(re.findall(r'^(/(?:obj|turf|area|mob)/[\w/]+)/(?:proc/|verb/)?\w+\s*\(', source, re.M))
        missing = sorted(path for path in paths if path not in defined)
        self.assertEqual(missing, [], f'Undefined DMM types: {missing}')

    def test_spawns_and_extraction_points(self):
        pmc = [(x, y) for x, y, atom in self.map.find(build.LANDMARK) if 'JoinLatePMC' in atom]
        scav = [(x, y) for x, y, atom in self.map.find(build.LANDMARK) if 'JoinLateScav' in atom]
        self.assertEqual(len(pmc), 4)
        self.assertEqual(len(scav), 5)
        for name, area in build.EXTRACTS.items():
            tiles = [pos for pos, atoms in self.map.cells.items() if atoms[-1] == area]
            self.assertGreaterEqual(len(tiles), 4, name)
            self.assertTrue(any(area.rsplit('/', 1)[1] == name for _ in [0]))
        signs = [atom for _, _, atom in self.map.find(build.SIGN_EXTRACT)]
        self.assertEqual(len(signs), len(build.EXTRACTS))
        for (x, y) in pmc:
            self.assertEqual(self.map.area(x, y), build.OUTSIDE)
            ring = {self.map.area(x + dx, y + dy) for dx in range(-3, 4) for dy in range(-3, 4)}
            self.assertIn(build.GRACE, ring, 'PMC spawn must sit inside a grace wall ring')

    def test_pmc_spawns_reach_every_raid_extraction(self):
        cells = self.map.walkable(keyed_open=False, grace_open=True)
        pmc = [(x, y) for x, y, atom in self.map.find(build.LANDMARK) if 'JoinLatePMC' in atom]
        for start in pmc:
            seen = self.map.reachable(cells, start)
            for name, area in build.EXTRACTS.items():
                if name == 'range':
                    continue
                tiles = {pos for pos, atoms in self.map.cells.items() if atoms[-1] == area}
                self.assertTrue(seen & tiles, f'{start} cannot walk to {name}')

    def test_grace_walls_hold_pmc_spawns_until_release(self):
        cells = self.map.walkable(keyed_open=False, grace_open=False)
        pmc = [(x, y) for x, y, atom in self.map.find(build.LANDMARK) if 'JoinLatePMC' in atom]
        for start in pmc:
            seen = self.map.reachable(cells, start)
            self.assertLess(len(seen), 120, f'{start} escapes its grace pocket')
            self.assertNotIn((82, 83), seen)

    def test_scavs_and_stores_connect_through_the_concourse(self):
        cells = self.map.walkable(keyed_open=False)
        seen = self.map.reachable(cells, (82, 83))
        scav = [(x, y) for x, y, atom in self.map.find(build.LANDMARK) if 'JoinLateScav' in atom]
        for start in scav:
            self.assertIn(start, seen, start)
        store_doors = [(x, y) for x, y, _ in self.map.find(build.STORE_DOOR)]
        self.assertGreaterEqual(len(store_doors), 20)
        for door in store_doors:
            self.assertIn(door, seen, door)
        # Every unkeyed loot spawner on the raid floor has a walkable neighbour.
        for x, y, atom in list(self.map.find('/obj/random')) + list(self.map.find('/obj/effect/spawner/lootdrop')):
            if self.map.area(x, y) == build.RANGE:
                continue
            neighbours = {(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)}
            self.assertTrue(neighbours & cells, f'Loot at {x},{y} has no approach')

    def test_keyed_rooms_need_their_keys(self):
        locked = self.map.walkable(keyed_open=False)
        unlocked = self.map.walkable(keyed_open=True)
        seen_locked = self.map.reachable(locked, (82, 83))
        seen_unlocked = self.map.reachable(unlocked, (82, 83))
        rooms = {'security': (44, 108), 'management': (30, 108), 'cage': (120, 105)}
        for name, probe in rooms.items():
            self.assertNotIn(probe, seen_locked, name)
            self.assertIn(probe, seen_unlocked, name)
        doors = {name: [(x, y) for x, y, _ in self.map.find(path)] for name, path in build.KEYED_DOORS.items()}
        for name, placed in doors.items():
            self.assertGreaterEqual(len(placed), 1, name)
            self.assertLessEqual(len(placed), 2, name)
        keys = {name: [(x, y) for x, y, _ in self.map.find(path)] for name, path in build.KEYS.items()}
        for name in ('security', 'management'):
            self.assertEqual(len(keys[name]), 1, name)
            x, y = keys[name][0]
            self.assertTrue({(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1), (x, y)} & seen_locked, f'{name} key is unreachable')
        # The cage key is chained behind the management suite door.
        self.assertEqual(len(keys['cage']), 1)
        x, y = keys['cage'][0]
        self.assertTrue(25 <= x <= 37 and 98 <= y <= 117, 'cage key belongs in the management suite')
        self.assertTrue({(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1), (x, y)} & seen_unlocked, 'cage key is unreachable')
        # The range gate key is never placed; admins spawn it.
        self.assertEqual(keys['range'], [])
        self.assertEqual(len(keys['test']), 1)
        self.assertEqual(self.map.area(*keys['test'][0]), build.RANGE)

    def test_range_is_sealed_from_the_raid_without_the_gate_key(self):
        locked = self.map.walkable(keyed_open=False)
        seen = self.map.reachable(locked, (82, 83))
        range_tiles = {pos for pos, atoms in self.map.cells.items() if atoms[-1] == build.RANGE and atoms[-2] not in build.DENSE_TURFS}
        self.assertFalse(seen & range_tiles)
        unlocked = self.map.walkable(keyed_open=True)
        seen = self.map.reachable(unlocked, (82, 83))
        for x, y, _ in self.map.find(build.PAD):
            neighbours = {(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1), (x, y)}
            self.assertTrue(neighbours & seen, f'Pad at {x},{y} has no approach')
        for x in range(25, 140):
            for y in range(133, 149):
                if self.map.turf(x, y) in build.DENSE_TURFS:
                    self.assertIn(self.map.turf(x, y), (build.BORDER, build.BLOCKS), (x, y))

    def test_every_loot_table_has_exactly_one_labelled_pad(self):
        pads = {}
        for x, y, atom in self.map.find(build.PAD):
            variables = dict(part.split(' = ', 1) for part in atom[atom.index('{') + 1:-1].split('; '))
            table = variables['table'].strip('"')
            name = variables['name'].strip('"')
            self.assertTrue(name.startswith('loot pad: '), name)
            self.assertNotIn(table, pads, f'Duplicate pad for {table}')
            pads[table] = (x, y, name)
            self.assertEqual(self.map.area(x, y), build.RANGE)
        expected = source_tables() | {build.MEDBAG}
        self.assertEqual(set(pads), expected, 'Each loot table in the DM source needs one pad; update build.PAD_TABLES')
        self.assertEqual(set(pads), {path for _, path in build.PAD_TABLES})
        self.assertEqual(len({name for _, _, name in pads.values()}), len(pads))

    def test_mechanics_corner_has_its_tools(self):
        corner = {atom.split('{', 1)[0] for (x, y), atoms in self.map.cells.items() if 56 <= x <= 90 and 133 <= y <= 137 for atom in atoms[:-2]}
        for path in (build.KEYED_DOORS['test'], build.KEYS['test'], '/obj/item/weapon/lockpick',
                     '/obj/item/weapon/gun/projectile/shotgun/pump', '/obj/item/ammo_magazine/shellbox',
                     build.OPTABLE, build.MEDBAG, build.SIGN_EXTRACT):
            self.assertIn(path, corner, path)
        self.assertTrue(any(atoms[-1] == build.GRACE for (x, y), atoms in self.map.cells.items() if 133 <= y <= 148))

    def test_metadata_and_registration(self):
        metadata = METADATA.read_text(encoding='utf-8')
        self.assertIn('/obj/map_metadata/eft_factory/crossroads_mall', metadata)
        self.assertIn('ID = MAP_CROSSROADS_MALL', metadata)
        self.assertIn('#define MAP_CROSSROADS_MALL "CROSSROADS_MALL"', (ROOT / 'code' / '__defines' / 'maps.dm').read_text(encoding='utf-8'))
        self.assertIn('crossroads_mall.dm', (ROOT / 'civ13.dme').read_text(encoding='utf-8'))
        self.assertNotIn('crossroads_mall.dmm', (ROOT / 'civ13.dme').read_text(encoding='utf-8'))
        mapswap = (ROOT / 'code' / 'processes' / 'mapswap.dm').read_text(encoding='utf-8')
        self.assertNotIn('CROSSROADS', mapswap, 'The mall must stay out of every vote rotation')
        verbs = (ROOT / 'code' / 'modules' / 'admin' / 'admin_verbs.dm').read_text(encoding='utf-8')
        self.assertIn('/client/proc/crossroads_reroll_loot_pads', verbs)
        self.assertIn('/client/proc/crossroads_loot_report', verbs)
        for area in list(build.EXTRACTS.values()) + [build.INTERIOR, build.RANGE]:
            self.assertIn(area + '\n', metadata, area)
        for name in ('security', 'management', 'cage', 'range', 'test'):
            self.assertIn(f'/datum/keyslot/crossroads/{name}\n', metadata)
            self.assertIn(f'/obj/item/weapon/key/modern/crossroads/{name}\n', metadata)
            self.assertIn(f'/obj/structure/simple_door/key_door/crossroads/{name}\n', metadata)
        # Pads store their table as text so standalone DMM readers never see a path value.
        self.assertIn('text2path(table)', metadata)


if __name__ == '__main__':
    unittest.main()
