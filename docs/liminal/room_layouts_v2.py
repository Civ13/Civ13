"""Version-2 furnished room layouts: parse, derive the catalog and check them.

Standard library only. `room-layouts-v2.json` is the authored source. It derives
`room-archetypes-v2.json` in the existing catalog schema, so the topology tool's
own `validate_catalog` checks the result. The checks below add the furnishing
rules (desk pairs, chairs facing desks, wall fixtures on walls, floors).
"""
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
LAYOUTS = HERE / 'room-layouts-v2.json'
CATALOG = HERE / 'room-archetypes-v2.json'
DIRS = {1: (0, 1), 2: (0, -1), 4: (1, 0), 8: (-1, 0)}
DESKS = {'D': None, 'T': 'computer', 'P': 'paper'}
DENSE = {'O': 'column', 'D': 'desk', 'T': 'desk', 'P': 'desk', 'F': 'cabinet', 'B': 'shelf', 'L': 'locker',
         'R': 'rack', 'K': 'plant', 'V': 'vending_snack', 'Q': 'vending_coffee', 'S': 'sink'}
FREE_CHAIRS = {'^': 1, 'v': 2}
FLOORS = {'c': 'carpet', 't': 'steel_tile', 'w': 'white_tile', 'd': 'dark_plating'}
FACE_AWAY = {'V', 'Q', 'S'}


def load(path=LAYOUTS):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def socket_cells(width, height, socket):
    v = socket['offset']
    span = range(v - 1, v + 2)
    return {'N': [(x, height - 1) for x in span], 'S': [(x, 0) for x in span],
            'E': [(width - 1, y) for y in span], 'W': [(0, y) for y in span]}[socket['facing']]


def parse(name, room):
    """Return (catalog archetype, furnishing) for one room, raising ValueError on authoring errors."""
    rows = room['layout']
    height, width = len(rows), len(rows[0])
    if any(len(r) != width for r in rows):
        raise ValueError(name + ': ragged layout')
    cell = {(x, height - 1 - i): ch for i, r in enumerate(rows) for x, ch in enumerate(r)}
    if 'floor' in room:
        frows = room['floor']
        if len(frows) != height or any(len(r) != width for r in frows):
            raise ValueError(name + ': floor grid size')
        floor_of = {(x, height - 1 - i): ch for i, r in enumerate(frows) for x, ch in enumerate(r)}
    else:
        floor_of = {p: room['fill'] for p in cell}
    border = {p for p in cell if p[0] in (0, width - 1) or p[1] in (0, height - 1)}
    for p, ch in cell.items():
        if (p in border) != (ch in '#n'):
            raise ValueError(f'{name}: {p} {ch!r} must be a wall only on the border')
        if p not in border and ch != 'O' and floor_of[p] not in FLOORS:
            raise ValueError(f'{name}: {p} has no floor material')
    sockets = {}
    for sid, s in room['sockets'].items():
        cells = socket_cells(width, height, s)
        if any(cell.get(c) != '#' for c in cells):
            raise ValueError(f'{name}: socket {sid} must be plain wall cells')
        sockets[sid] = {'facing': s['facing'], 'offset': s['offset'], 'width': 3, 'kind': 'HUMAN_DOOR', 'clearance': 'HUMAN'}
    mask_rows = []
    for y in range(height):
        mask_rows.append(''.join('#' if cell[(x, y)] in '#n' else 'X' if cell[(x, y)] in DENSE else '.' for x in range(width)))
    desks = {p for p, ch in cell.items() if ch in DESKS}
    walls = {p for p in border}
    objects = []
    for (x, y), ch in sorted(cell.items(), key=lambda kv: (-kv[0][1], kv[0][0])):
        if ch in '#.':
            continue
        if ch == 'n':
            objects.append({'asset': 'noticeboard', 'position': [x, y], 'direction': 2, 'role': 'wall-mounted notice board'})
            continue
        if ch in DESKS:
            near = [bit for bit, (dx, dy) in DIRS.items() if (x + dx, y + dy) in desks]
            if len(near) > 1:
                raise ValueError(f'{name}: desk at {(x, y)} has more than one desk neighbour')
            objects.append({'asset': 'desk', 'position': [x, y], 'direction': near[0] if near else 2,
                            'state': 'woodtable_1tileendtable' if near else 'woodtable', 'role': 'work surface'})
            if DESKS[ch]:
                objects.append({'asset': DESKS[ch], 'position': [x, y], 'direction': 2, 'role': 'on the desk'})
            continue
        if ch == 'c':
            near = [bit for bit, (dx, dy) in DIRS.items() if (x + dx, y + dy) in desks]
            if len(near) != 1:
                raise ValueError(f'{name}: chair at {(x, y)} needs exactly one adjacent desk')
            objects.append({'asset': 'chair', 'position': [x, y], 'direction': near[0], 'role': 'seat facing its desk'})
            continue
        if ch in FREE_CHAIRS:
            objects.append({'asset': 'chair', 'position': [x, y], 'direction': FREE_CHAIRS[ch], 'role': 'waiting seat'})
            continue
        if ch not in DENSE:
            raise ValueError(f'{name}: unknown layout character {ch!r}')
        direction = 2
        if ch in FACE_AWAY:
            against = [bit for bit, (dx, dy) in DIRS.items() if (x + dx, y + dy) in walls]
            if not against:
                raise ValueError(f'{name}: {DENSE[ch]} at {(x, y)} must stand against a wall')
            direction = {1: 2, 2: 1, 4: 8, 8: 4}[against[0]]
        objects.append({'asset': DENSE[ch], 'position': [x, y], 'direction': direction, 'role': 'solid furnishing'})
    archetype = {'width': width, 'height': height, 'mask': mask_rows, 'role': room['role'], 'zone': room['zone'],
                 'sockets': sockets, 'anchors': room['anchors'], 'tags': room['tags'],
                 'native_admission': 'PENDING', 'authoring': 'ORIGINAL_ABSTRACT_MASK_NO_ASSET_COPY'}
    furnishing = {'program': room['program'], 'objects': objects,
                  'floor': {f'{x},{y}': FLOORS[floor_of[(x, y)]] for (x, y) in sorted(cell)
                            if (x, y) not in border and floor_of[(x, y)] in FLOORS}}
    return archetype, furnishing


def derive(layouts=None):
    layouts = layouts or load()
    catalog = {'schema': 'civ13-liminal-room-catalog/1', 'version': layouts['version'], 'native_approved': False, 'archetypes': {}}
    furnishing = {}
    for name, room in layouts['rooms'].items():
        catalog['archetypes'][name], furnishing[name] = parse(name, room)
    return catalog, furnishing


def check(layouts=None):
    """Return (catalog, furnishing, problems)."""
    sys.path.insert(0, str(ROOT))
    from tools.liminal_maps.catalog import validate_catalog
    catalog, furnishing = derive(layouts)
    problems = list(validate_catalog(catalog))
    v1 = json.loads((HERE / 'room-archetypes-v1.json').read_text(encoding='utf-8'))['archetypes']
    if set(v1) != set(catalog['archetypes']):
        problems.append('ROOM_SET_CHANGED')
    for name, a in catalog['archetypes'].items():
        old = v1.get(name)
        if old and (old['role'], old['zone'], old['width'], old['height'], old['sockets'], old['anchors']) != \
                (a['role'], a['zone'], a['width'], a['height'], a['sockets'], a['anchors']):
            problems.append('ASSEMBLY_CONTRACT_CHANGED:' + name)
    return catalog, furnishing, problems


def dumps(value):
    return json.dumps(value, indent=2) + '\n'


if __name__ == '__main__':
    catalog, furnishing, problems = check()
    if problems:
        raise SystemExit('FAILED ' + ', '.join(problems))
    if sys.argv[1:] == ['--write']:
        CATALOG.write_text(dumps(catalog), encoding='utf-8')
    elif CATALOG.read_text(encoding='utf-8') != dumps(catalog):
        raise SystemExit('room-archetypes-v2.json is stale; run with --write')
    print('PASS', len(catalog['archetypes']), 'rooms')
