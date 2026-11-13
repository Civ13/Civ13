#!/usr/bin/env python3
"""Writes maps/313bc/ides_of_march.dmm, the Ides of March TDM map.

The map is built from existing tiles and props only: the Curia of Pompey
(marble walls, benches, Pompey's statue and Caesar's chair) with a portico in
front, Caesar's domus to the south where his party gathers, and streets and
houses around them. Run it again after changing the layout:

    python3 tools/ides_of_march/make_map.py
"""
from pathlib import Path

W, H = 64, 56
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'maps' / '313bc' / 'ides_of_march.dmm'

STREET = '/area/caribbean/ides'
CURIA = '/area/caribbean/ides/curia'
HOUSE = '/area/caribbean/ides/house'
DOORWAY = '/area/caribbean/no_mans_land/invisible_wall'
VOID = '/area/caribbean/void'

COBBLE = '/turf/floor/plating/cobblestone'
COBBLE_DARK = '/turf/floor/plating/cobblestone/dark'
GRASS = '/turf/floor/grass'
MARBLE = '/turf/floor/plating/marble/ornate'
MARBLE_TILE = '/turf/floor/plating/marble/tile'
WOOD = '/turf/floor/plating/tiled/woodh'
EDGE = '/turf/wall/indestructable/black'

MARBLE_WALL = '/obj/covers/marble_wall/classic'
STONE_WALL = '/obj/covers/stone_wall/classic/villa'
ARCH = '/obj/covers/marble_wall/grecian/archway'
COLUMN = '/obj/structure/religious/monument/pillar_monument'
DOOR = '/obj/structure/simple_door/key_door/anyone/roman'
STATUE = '/obj/structure/religious/statue{name = "statue of Pompey"; desc = "Gnaeus Pompeius Magnus, in marble."}'
THRONE = '/obj/structure/bed/chair/throne{dir = 2}'
BRAZIER = '/obj/structure/brazier/marble'
TABLE = '/obj/structure/table/wood'
BUSH = '/obj/structure/wild/bush'
LANTERN = '/obj/item/flashlight/lantern/on/anchored'
SENATE = '/obj/effect/landmark{name = "JoinLateIdesSenate"}'
PARTY = '/obj/effect/landmark{name = "JoinLateIdesCaesar"}'
METADATA = '/obj/map_metadata/ides_of_march'


def bench(direction):
    return '/obj/structure/bed/chair/wood{dir = %d}' % direction


# grid[x][y] = (objs list, turf, area), 1-based like the game.
grid = {}


def put(x, y, turf=None, area=None, objs=()):
    objs_now, turf_now, area_now = grid[(x, y)]
    grid[(x, y)] = (objs_now + list(objs), turf or turf_now, area or area_now)


def rect(x1, y1, x2, y2, **kw):
    for x in range(x1, x2 + 1):
        for y in range(y1, y2 + 1):
            put(x, y, **kw)


def walls(x1, y1, x2, y2, wall):
    for x in range(x1, x2 + 1):
        put(x, y1, objs=[wall])
        put(x, y2, objs=[wall])
    for y in range(y1 + 1, y2):
        put(x1, y, objs=[wall])
        put(x2, y, objs=[wall])


def clear(x, y, objs=()):
    """Removes walls from a tile (for doors) and adds objs."""
    o, t, a = grid[(x, y)]
    grid[(x, y)] = ([k for k in o if k not in (MARBLE_WALL, STONE_WALL)] + list(objs), t, a)


for x in range(1, W + 1):
    for y in range(1, H + 1):
        if x in (1, W) or y in (1, H):
            grid[(x, y)] = ([], EDGE, VOID)
        else:
            grid[(x, y)] = ([], COBBLE, STREET)
put(1, 1, objs=[METADATA])

# Gardens and a darker main road from Caesar's domus to the portico.
rect(2, 2, 63, 3, turf=GRASS)
rect(30, 12, 34, 16, turf=COBBLE_DARK)
for x, y in ((17, 12), (47, 12), (17, 50), (47, 50), (16, 30), (48, 30), (16, 40), (48, 40)):
    put(x, y, turf=GRASS, objs=[BUSH])

# The Curia of Pompey: x 20-44, y 24-46.
rect(21, 25, 43, 45, turf=MARBLE, area=CURIA)
walls(20, 24, 44, 46, MARBLE_WALL)
for x in (31, 32, 33):           # main doors onto the portico
    clear(x, 24, objs=[ARCH])
    put(x, 24, turf=MARBLE, area=CURIA)
    put(x, 23, area=DOORWAY)
for y in (35,):                  # side doors east and west
    clear(20, y, objs=[DOOR])
    put(20, y, turf=MARBLE, area=CURIA)
    put(19, y, area=DOORWAY)
    clear(44, y, objs=[DOOR])
    put(44, y, turf=MARBLE, area=CURIA)
    put(45, y, area=DOORWAY)
put(32, 44, objs=[STATUE])
put(32, 42, objs=[THRONE])
rect(29, 41, 35, 43, turf=MARBLE_TILE)
put(25, 44, objs=[BRAZIER])
put(39, 44, objs=[BRAZIER])
for y in range(27, 41):          # tiered benches facing the floor
    if y == 35:
        continue
    for x in (21, 22, 23):
        put(x, y, objs=[bench(4)])
    for x in (41, 42, 43):
        put(x, y, objs=[bench(8)])
for y in (28, 32, 38):
    put(27, y, objs=[COLUMN])
    put(37, y, objs=[COLUMN])
for x in (24, 25, 26, 38, 39, 40):
    for y in range(27, 41):
        if y != 35:
            put(x, y, objs=[SENATE])

# Portico in front of the Curia: y 17-22, columns along the front.
rect(18, 17, 46, 22, turf=MARBLE_TILE)
for x in range(19, 46, 3):
    if x not in (31, 34):
        put(x, 18, objs=[COLUMN])
put(18, 22, objs=[LANTERN])
put(46, 22, objs=[LANTERN])

# Caesar's domus: x 24-40, y 4-11, door north onto the road.
rect(25, 5, 39, 10, turf=WOOD, area=HOUSE)
walls(24, 4, 40, 11, STONE_WALL)
for x in (31, 32, 33):
    clear(x, 11, objs=[DOOR] if x == 32 else [])
    put(x, 11, turf=WOOD, area=HOUSE)
for x in (31, 33):
    put(x, 11, objs=[STONE_WALL])
put(27, 9, objs=[TABLE])
put(37, 9, objs=[TABLE])
put(32, 6, objs=[BRAZIER])
for x in range(26, 39):
    for y in (6, 7, 8):
        if (x, y) != (32, 6):
            put(x, y, objs=[PARTY])


def house(x1, y1, x2, y2, door):
    rect(x1 + 1, y1 + 1, x2 - 1, y2 - 1, turf=WOOD, area=HOUSE)
    walls(x1, y1, x2, y2, STONE_WALL)
    dx, dy = door
    clear(dx, dy, objs=[DOOR])
    put(dx, dy, turf=WOOD, area=HOUSE)
    put((x1 + x2) // 2, (y1 + y2) // 2, objs=[TABLE])


# Insulae and shops along the streets, for cover in the chase.
house(3, 5, 13, 13, (13, 9))
house(3, 18, 12, 26, (12, 22))
house(3, 31, 12, 41, (12, 36))
house(3, 45, 13, 53, (8, 45))
house(51, 5, 61, 13, (51, 9))
house(52, 18, 61, 26, (52, 22))
house(52, 31, 61, 41, (52, 36))
house(51, 45, 61, 53, (56, 45))
house(19, 49, 29, 54, (24, 49))
house(35, 49, 45, 54, (40, 49))


def tile_text(objs, turf, area):
    return '(' + ','.join(list(objs) + [turf, area]) + ')'


keys = {}
LETTERS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'


def key_for(text):
    if text not in keys:
        n = len(keys)
        keys[text] = LETTERS[n // len(LETTERS)] + LETTERS[n % len(LETTERS)]
    return keys[text]


columns = []
for x in range(1, W + 1):
    col = [key_for(tile_text(*grid[(x, y)])) for y in range(H, 0, -1)]
    columns.append(col)

lines = []
for text, k in keys.items():
    lines.append('"%s" = %s' % (k, text))
lines.append('')
lines.append('(1,1,1) = {"')
for row in range(H):
    lines.append(''.join(columns[x][row] for x in range(W)))
lines.append('"}')
OUT.write_text('\n'.join(lines) + '\n', encoding='utf-8')
print('wrote', OUT.relative_to(ROOT), 'with', len(keys), 'tile kinds')
