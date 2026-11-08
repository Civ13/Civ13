"""Generate the per-round battle map variation inserts in maps/zones/variations/.

Each slot is a rectangle of a compiled battle map. A variant is a small
plain-format DMM laid over that rectangle at round start by
code/modules/map_variations/map_variations.dm. Cells the variant does not
change hold the keep marker, so the loader leaves them alone. Changes are only
made on open ground in the base map (floor turf, no structure, floor cover,
landmark or item), and every layout is mirrored across the slot's centre so
neither side gets the better half.

Idea after CM-SS13's "nightmare" map inserts (AGPL-3.0); reimplemented for Civ13.

Run from the repository root:
    python3 tests/map_variations/build_inserts.py          # write files
    python3 tests/map_variations/build_inserts.py --check  # exit 1 if stale
"""
from pathlib import Path
import json
import random
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'maps' / 'zones' / 'variations'
KEEP = '/obj/effect/map_variation_keep'
DEFINITION = re.compile(r'^"([A-Za-z]+)" = \((.*)\)$')
GRID = re.compile(r'\((\d+),(\d+),(\d+)\) = \{"\n(.*?)\n"\}', re.S)

DEBRIS = '/obj/structure/barricade/debris'
BRICK = '/obj/structure/barricade/debris/brick'
HEDGEHOG = '/obj/structure/barricade/antitank'
WIRE = '/obj/structure/barbwire'
TIRES = '/obj/structure/barricade/tires'
CRATER = '/turf/floor/dirt/burned'


def sandbag(direction):
    return '/obj/structure/window/barrier/sandbag{dir = %d}' % direction


def split_atoms(body):
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


def atom_path(atom):
    return atom.split('{', 1)[0]


def read_base(path):
    """Return {(x, y): [atom, ...]} for z=1 and the map size of a plain DMM."""
    text = (ROOT / path).read_text(encoding='utf-8')
    models = {}
    for line in text.split('\n'):
        match = DEFINITION.match(line.rstrip('\r'))
        if match:
            models[match.group(1)] = split_atoms(match.group(2))
    width = len(next(iter(models)))
    cells, size = {}, (0, 0)
    for gx, gy, gz, grid in GRID.findall(text.replace('\r\n', '\n')):
        if int(gz) != 1:
            continue
        rows = grid.split('\n')
        for index, row in enumerate(rows):
            y = int(gy) + len(rows) - 1 - index
            for column in range(len(row) // width):
                x = int(gx) + column
                cells[(x, y)] = models[row[column * width:(column + 1) * width]]
                size = (max(size[0], x), max(size[1], y))
    return cells, size


OPEN_EXTRA = ('/obj/effect/decal', '/obj/effect/floor_decal')
CLOSED_TURFS = ('/turf/wall', '/turf/floor/beach/water', '/turf/floor/trench', '/turf/floor/plating/beach/water')


def is_open(atoms):
    """Open ground: one floor turf, its area and at most decals."""
    for atom in atoms:
        path = atom_path(atom)
        if path.startswith('/area'):
            continue
        if path.startswith('/turf'):
            if not path.startswith('/turf/floor') or path.startswith(CLOSED_TURFS) or 'water' in path:
                return False
            continue
        if not path.startswith(OPEN_EXTRA):
            return False
    return True


class Layout:
    """Placements for one variant, mirrored across the slot's horizontal centre."""

    def __init__(self, slot, cells):
        self.slot = slot
        self.cells = cells
        self.x1, self.y1 = slot['x'], slot['y']
        self.x2, self.y2 = slot['x'] + slot['width'] - 1, slot['y'] + slot['height'] - 1
        self.changes = {}

    def open(self, x, y):
        return self.x1 <= x <= self.x2 and self.y1 <= y <= self.y2 and is_open(self.cells.get((x, y), ['/turf/wall']))

    def mirror_y(self, y):
        return self.y1 + self.y2 - y

    def mirror_x(self, x):
        return self.x1 + self.x2 - x

    def put(self, x, y, atoms, mirror=True, flip=None):
        """Place atoms at (x, y) and its mirror only if both cells are open."""
        targets = [(x, y, atoms)]
        if mirror:
            mirrored = [flip(a) for a in atoms] if flip else atoms
            targets.append((x, self.mirror_y(y), mirrored))
        if not all(self.open(tx, ty) for tx, ty, _ in targets):
            return False
        for tx, ty, tatoms in targets:
            self.changes[(tx, ty)] = list(tatoms)
        return True


def flip_sandbag(atom):
    return atom.replace('{dir = 1}', '{dir = @}').replace('{dir = 2}', '{dir = 1}').replace('{dir = @}', '{dir = 2}')


def rubble_piles(layout, rng, count, kinds):
    """Scattered rubble heaps, mirrored north-south and east-west."""
    placed, tries = 0, 0
    mid = (layout.y1 + layout.y2) // 2
    while placed < count and tries < count * 40:
        tries += 1
        x = rng.randint(layout.x1, (layout.x1 + layout.x2) // 2)
        y = rng.randint(layout.y1, mid)
        heap = [(0, 0), (1, 0), (0, 1)][:rng.randint(1, 3)]
        kind = rng.choice(kinds)
        cells = [(x + dx, y + dy) for dx, dy in heap]
        cells += [(layout.mirror_x(cx), cy) for cx, cy in cells]
        if all(layout.open(cx, cy) and layout.open(cx, layout.mirror_y(cy)) for cx, cy in cells):
            if any((cx, cy) in layout.changes for cx, cy in cells):
                continue
            for cx, cy in cells:
                layout.put(cx, cy, [kind])
            placed += 1


def hedgehog_line(layout, y, step, wire_rows):
    """Czech hedgehogs every few tiles on one row, wire on the given offsets."""
    for x in range(layout.x1 + 1, layout.x2, step):
        layout.put(x, y, [HEDGEHOG], mirror=False)
    for offset in wire_rows:
        for x in range(layout.x1, layout.x2 + 1):
            if (x - layout.x1) % 8 < 5:
                layout.put(x, y - offset, [WIRE])


def wire_belts(layout, rows_from_edge, gap_every=7, gap=2):
    for offset in rows_from_edge:
        y = layout.y1 + offset
        for x in range(layout.x1, layout.x2 + 1):
            if (x - layout.x1) % gap_every >= gap:
                layout.put(x, y, [WIRE])


def craters(layout, rng, count, radius=1):
    placed, tries = 0, 0
    mid = (layout.y1 + layout.y2) // 2
    while placed < count and tries < count * 40:
        tries += 1
        cx = rng.randint(layout.x1 + radius, layout.x2 - radius)
        cy = rng.randint(layout.y1 + radius, mid - radius)
        tiles = [(cx + dx, cy + dy) for dx in range(-radius, radius + 1) for dy in range(-radius, radius + 1)
                 if abs(dx) + abs(dy) <= radius + (1 if radius > 1 else 0)]
        if not all(layout.open(x, y) and layout.open(x, layout.mirror_y(y)) for x, y in tiles):
            continue
        if any((x, y) in layout.changes for x, y in tiles):
            continue
        for x, y in tiles:
            layout.put(x, y, [CRATER])
        layout.put(cx, cy, [CRATER, DEBRIS])
        placed += 1


def sandbag_nests(layout, rng, count):
    """U-shaped two-wide nests facing the far side, mirrored to face back."""
    placed, tries = 0, 0
    mid = (layout.y1 + layout.y2) // 2
    while placed < count and tries < count * 60:
        tries += 1
        x = rng.randint(layout.x1 + 1, layout.x2 - 2)
        y = rng.randint(layout.y1 + 1, mid - 1)
        front = [(x, y, sandbag(1)), (x + 1, y, sandbag(1))]
        sides = [(x - 1, y, sandbag(8)), (x + 2, y, sandbag(4))]
        cells = front + sides
        if not all(layout.open(cx, cy) and layout.open(cx, layout.mirror_y(cy)) for cx, cy, _ in cells):
            continue
        if any((cx, cy) in layout.changes or (cx, layout.mirror_y(cy)) in layout.changes for cx, cy, _ in cells):
            continue
        for cx, cy, atom in cells:
            layout.put(cx, cy, [atom], flip=flip_sandbag)
        placed += 1


def tire_barricades(layout, rng, count):
    rubble_piles(layout, rng, count, [TIRES])


SLOTS = {
    'smallingrad': {
        'map': 'SMALLINGRAD',
        'base_map': 'maps/1943/smallingrad.dmm',
        'slots': [
            {'id': 'central_avenue', 'x': 1, 'y': 58, 'z': 1, 'width': 45, 'height': 7,
             'variants': [
                 {'id': 'as_built', 'weight': 2},
                 {'id': 'rubble', 'weight': 1, 'seed': 11, 'build': lambda l, r: rubble_piles(l, r, 8, [DEBRIS, BRICK]),
                  'desc': 'Collapsed walls have spilled rubble across the central avenue.'},
                 {'id': 'tank_traps', 'weight': 1, 'build': lambda l, r: hedgehog_line(l, 61, 4, (2,)),
                  'desc': 'Czech hedgehogs and barbed wire block the central avenue.'},
             ]},
            {'id': 'south_square', 'x': 1, 'y': 32, 'z': 1, 'width': 45, 'height': 14,
             'variants': [
                 {'id': 'as_built', 'weight': 2},
                 {'id': 'shelled', 'weight': 1, 'seed': 23, 'build': lambda l, r: craters(l, r, 5),
                  'desc': 'Shelling has cratered the southern square.'},
                 {'id': 'barricades', 'weight': 1, 'seed': 29,
                  'build': lambda l, r: (tire_barricades(l, r, 5), sandbag_nests(l, r, 2)),
                  'desc': 'Tire barricades and sandbag nests fill the southern square.'},
             ]},
        ],
    },
    'hill_203': {
        'map': 'HILL_203',
        'base_map': 'maps/1903/hill_203.dmm',
        'slots': [
            {'id': 'west_slope', 'x': 1, 'y': 40, 'z': 1, 'width': 36, 'height': 81,
             'variants': [
                 {'id': 'as_built', 'weight': 2},
                 {'id': 'wire_belts', 'weight': 1, 'build': lambda l, r: wire_belts(l, (12, 68)),
                  'desc': 'Belts of barbed wire cross the western slope.'},
                 {'id': 'shelled', 'weight': 1, 'seed': 41, 'build': lambda l, r: craters(l, r, 7, 2),
                  'desc': 'Artillery has cratered the western slope.'},
                 {'id': 'sandbag_nests', 'weight': 1, 'seed': 43, 'build': lambda l, r: sandbag_nests(l, r, 4),
                  'desc': 'Abandoned sandbag nests dot the western slope.'},
             ]},
            {'id': 'east_slope', 'x': 65, 'y': 40, 'z': 1, 'width': 36, 'height': 81,
             'variants': [
                 {'id': 'as_built', 'weight': 2},
                 {'id': 'wire_belts', 'weight': 1, 'build': lambda l, r: wire_belts(l, (18, 62)),
                  'desc': 'Belts of barbed wire cross the eastern slope.'},
                 {'id': 'shelled', 'weight': 1, 'seed': 53, 'build': lambda l, r: craters(l, r, 7, 2),
                  'desc': 'Artillery has cratered the eastern slope.'},
                 {'id': 'sandbag_nests', 'weight': 1, 'seed': 59, 'build': lambda l, r: sandbag_nests(l, r, 4),
                  'desc': 'Abandoned sandbag nests dot the eastern slope.'},
             ]},
        ],
    },
}


def key_names():
    letters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
    for first in letters:
        for second in letters:
            yield first + second


def render_insert(slot, changes):
    models = {KEEP: 'aa'}
    names = key_names()
    next(names)
    for pos in sorted(changes):
        text = ','.join(changes[pos])
        if text not in models:
            models[text] = next(names)
    lines = ['"%s" = (%s)' % (key, text) for text, key in sorted(models.items(), key=lambda item: item[1])]
    rows = []
    for y in range(slot['y'] + slot['height'] - 1, slot['y'] - 1, -1):
        rows.append(''.join(models[','.join(changes[(x, y)])] if (x, y) in changes else 'aa'
                            for x in range(slot['x'], slot['x'] + slot['width'])))
    return '\n'.join(lines) + '\n\n(1,1,1) = {"\n' + '\n'.join(rows) + '\n"}\n'


def build():
    """Return {relative path: text} for every generated file."""
    files = {}
    for folder, spec in SLOTS.items():
        cells, _ = read_base(spec['base_map'])
        manifest = {'map': spec['map'], 'base_map': spec['base_map'],
                    'generated_by': 'tests/map_variations/build_inserts.py', 'slots': []}
        for slot in spec['slots']:
            entry = {key: slot[key] for key in ('id', 'x', 'y', 'z', 'width', 'height')}
            entry['variants'] = []
            for variant in slot['variants']:
                item = {'id': variant['id'], 'weight': variant['weight']}
                if 'build' in variant:
                    layout = Layout(slot, cells)
                    variant['build'](layout, random.Random(variant.get('seed', 0)))
                    if not layout.changes:
                        raise SystemExit('%s/%s/%s changed nothing' % (folder, slot['id'], variant['id']))
                    name = '%s_%s.dmm' % (slot['id'], variant['id'])
                    files['%s/%s' % (folder, name)] = render_insert(slot, layout.changes)
                    item['file'] = name
                    item['desc'] = variant['desc']
                entry['variants'].append(item)
            manifest['slots'].append(entry)
        files['%s/variations.json' % folder] = json.dumps(manifest, indent='\t') + '\n'
    return files


def main(argv):
    check = '--check' in argv
    files = build()
    stale = []
    for rel, text in files.items():
        path = OUT / rel
        if check:
            if not path.exists() or path.read_text(encoding='utf-8') != text:
                stale.append(rel)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding='utf-8', newline='\n')
    if check:
        extra = sorted(str(p.relative_to(OUT)).replace('\\', '/') for p in OUT.rglob('*') if p.is_file()
                       and str(p.relative_to(OUT)).replace('\\', '/') not in files)
        if stale or extra:
            print('Stale map variation files: %s; unexpected: %s' % (stale, extra))
            return 1
        print('Map variation inserts are up to date (%d files).' % len(files))
        return 0
    print('Wrote %d map variation files.' % len(files))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
