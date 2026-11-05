"""Rail-yard region map for party trains (docs/party-train.md).

Writes a two-level .dmm: solid ground below, and on the surface an arrival
platform plus rows of numbered berths. Each berth is a platform with its
berth marker, a three-car walk-in train (locomotive cab, common car, sleeper)
behind it with party-only doors and indestructible carriage walls, and a
running line behind the train. Berths are laid out in columns joined by
roads, so one world holds many parties.

The map is generated, not committed: point a RAILYARD region's "map" at the
output (scripts/shard-group/README.md).
"""
import argparse
import math
import re
from pathlib import Path

VERSION = 'civ13-rail-yard/1'
MAX_SIDE = 255  # keep the world small enough to save quickly and stay in memory

BERTH_WIDTH = 34  # platform, train and margins of one berth, west to east
BERTH_HEIGHT = 9  # gap, platform, five rows of train, running line, gap
ROAD = 3  # road between columns and along the west edge
ARRIVAL_HEIGHT = 8  # arrival platform along the south edge
TOP_MARGIN = 3

AREA = '/area/caribbean/nomads/rail_yard'
TRAIN_AREA = '/area/caribbean/nomads/rail_yard/train'
UNDER_AREA = '/area/caribbean/void/caves'
METADATA = '/obj/map_metadata/nomads'

GROUND = '/turf/floor/dirt'
CONCRETE = '/turf/floor/plating/concrete'
FLOOR = '/turf/floor/wood'
WALL = '/turf/wall/indestructable/party_train'
BEDROCK = '/turf/wall/indestructable'
RAIL = '/obj/structure/rails/regular/horizontal'
START = '/obj/effect/landmark{icon_state = "x3"; name = "JoinLateCiv"}'

# Every type the map places, and the file that declares it.
SOURCES = {
    AREA: 'code/modules/persistence/party_train.dm',
    TRAIN_AREA: 'code/modules/persistence/party_train.dm',
    WALL: 'code/modules/persistence/party_train.dm',
    '/obj/structure/region_gate/rail_berth': 'code/modules/persistence/party_train.dm',
    '/obj/structure/simple_door/party_train': 'code/modules/persistence/party_train.dm',
    UNDER_AREA: 'code/game/area/caribbean.dm',
    METADATA: 'code/game/objects/map_metadata/nomads/nomads.dm',
    BEDROCK: 'code/game/turfs/wall_types.dm',
    RAIL: 'code/modules/1713/trains.dm',
    '/obj/structure/bed': 'code/game/objects/structures/stool_bed_chair_nest/bed.dm',
    '/obj/structure/bed/chair': 'code/game/objects/structures/stool_bed_chair_nest/chairs.dm',
    '/obj/structure/table': 'code/game/objects/structures/table.dm',
    '/obj/structure/table/rack': 'code/game/objects/structures/table_rack.dm',
    '/obj/structure/closet/crate': 'code/game/objects/structures/crates_lockers/crates.dm',
    '/obj/structure/props/engineprops': 'code/modules/1713/structures.dm',
}

# One berth's train, rows from north (the running line side) to south (the
# platform side), columns from x=2 within the berth. Keys:
#   # carriage wall, . floor, D door (party only), E engine, T table, c chair,
#   R rack, C crate, B bed
TRAIN = [
    '##############################',
    '#.T..E#c.c...c.c.#B.B.B.B.B..#',
    '#.c...D.T.....T..D.........CC#',
    '#.....#R.R.......#B.B.B.B.B..#',
    '##############D###############',
]
FURNITURE = {
    'E': '/obj/structure/props/engineprops{name = "locomotive boiler"; density = 1}',
    'T': '/obj/structure/table',
    'c': '/obj/structure/bed/chair',
    'R': '/obj/structure/table/rack',
    'C': '/obj/structure/closet/crate',
    'B': '/obj/structure/bed',
}


def tile(*atoms, area=AREA):
    return ','.join(list(atoms) + [area])


def size(berths, columns):
    rows = math.ceil(berths / columns)
    width = ROAD + columns * (BERTH_WIDTH + ROAD)
    height = ARRIVAL_HEIGHT + rows * BERTH_HEIGHT + TOP_MARGIN
    return width, height, rows


def berth_origin(n, columns):
    """South-west corner of berth n (1-based): rows fill west to east, then north."""
    column, row = (n - 1) % columns, (n - 1) // columns
    return ROAD + 1 + column * (BERTH_WIDTH + ROAD), ARRIVAL_HEIGHT + 1 + row * BERTH_HEIGHT


def layout(berths, columns):
    if not 1 <= columns <= 8:
        raise ValueError('columns must be 1 to 8')
    if berths < 1:
        raise ValueError('berths must be at least 1')
    width, height, _ = size(berths, columns)
    if width > MAX_SIDE or height > MAX_SIDE:
        raise ValueError('%d berths in %d columns need %dx%d tiles; the most is %dx%d' % (berths, columns, width, height, MAX_SIDE, MAX_SIDE))
    cells = {}
    for x in range(1, width + 1):
        for y in range(1, height + 1):
            cells[(x, y, 1)] = tile(BEDROCK, area=UNDER_AREA)
            # Roads, the arrival platform and berth platforms are concrete; the rest is ground.
            cells[(x, y, 2)] = tile(CONCRETE if y <= ARRIVAL_HEIGHT or (x - 1) % (BERTH_WIDTH + ROAD) < ROAD else GROUND)
    cells[(1, 1, 1)] = tile(METADATA, BEDROCK, area=UNDER_AREA)
    # Arrival points for travellers without a train, in the middle of the arrival platform.
    middle = width // 2
    for dx in range(-3, 3):
        cells[(middle + dx, ARRIVAL_HEIGHT // 2, 2)] = tile(START, CONCRETE)
    for n in range(1, berths + 1):
        ox, oy = berth_origin(n, columns)
        # Platform (south) row, the full berth width so it meets both roads.
        for dx in range(BERTH_WIDTH):
            cells[(ox + dx, oy + 1, 2)] = tile(CONCRETE)
        cells[(ox + 2, oy + 1, 2)] = tile('/obj/structure/region_gate/rail_berth{berth = %d; name = "berth %d"}' % (n, n), CONCRETE)
        # Train: TRAIN's last row sits just north of the platform.
        for row, line in enumerate(reversed(TRAIN)):
            for col, key in enumerate(line):
                at = (ox + 2 + col, oy + 2 + row, 2)
                if key == '#':
                    cells[at] = tile(WALL, area=TRAIN_AREA)
                elif key == 'D':
                    cells[at] = tile('/obj/structure/simple_door/party_train{berth = %d}' % n, FLOOR, area=TRAIN_AREA)
                elif key in FURNITURE:
                    cells[at] = tile(FURNITURE[key], FLOOR, area=TRAIN_AREA)
                else:
                    cells[at] = tile(FLOOR, area=TRAIN_AREA)
        # Running line behind the train.
        for dx in range(1, BERTH_WIDTH - 1):
            cells[(ox + dx, oy + 2 + len(TRAIN), 2)] = tile(RAIL, GROUND)
    return cells, width, height


def write_text(cells, width, height):
    recipes = sorted(set(cells.values()))
    alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
    digits = 1
    while len(alphabet) ** digits < len(recipes):
        digits += 1

    def key(n):
        return ''.join(alphabet[(n // len(alphabet) ** p) % len(alphabet)] for p in reversed(range(digits)))

    keys = {recipe: key(i) for i, recipe in enumerate(recipes)}
    lines = ['// Generated rail yard (%s). Rebuild it with python3 -m tools.rail_yard; do not edit by hand.' % VERSION]
    lines.extend('"%s" = (%s)' % (keys[r], r) for r in recipes)
    for z in (1, 2):
        lines.extend(['', '(1,1,%d) = {"' % z])
        for y in range(height, 0, -1):
            lines.append(''.join(keys[cells[(x, y, z)]] for x in range(1, width + 1)))
        lines.append('"}')
    return '\n'.join(lines) + '\n'


def verify_types(root):
    for typename, path in SOURCES.items():
        text = (Path(root) / path).read_text(encoding='utf-8-sig')
        if not re.search(r'^' + re.escape(typename) + r'([ \t]*(//.*)?$|/\w+\()', text, re.M):
            raise ValueError('%s is not declared in %s' % (typename, path))


def main(argv=None):
    parser = argparse.ArgumentParser(prog='python3 -m tools.rail_yard', description='Write a rail-yard region map for party trains.')
    parser.add_argument('--berths', type=int, default=96, help='party berths (default 96)')
    parser.add_argument('--columns', type=int, default=4, help='berth columns (default 4)')
    parser.add_argument('--out', required=True, help='output .dmm')
    args = parser.parse_args(argv)
    out = Path(args.out)
    if out.suffix.lower() != '.dmm':
        parser.error('--out must end in .dmm')
    verify_types(Path(__file__).resolve().parents[2])
    try:
        cells, width, height = layout(args.berths, args.columns)
    except ValueError as error:
        parser.error(str(error))
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(write_text(cells, width, height), encoding='utf-8', newline='\n')
    print('%s: %d berths, %dx%d tiles' % (out, args.berths, width, height))
    return 0
