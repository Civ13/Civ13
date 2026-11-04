"""Generate overlay/filming/village.dmm: the authored trailer village.

The village is laid out west to east along the production chain:
meadow (seed gathering) -> wheat farm -> open-air bakery -> carriage road ->
train station. Coordinates here use BYOND's convention (x right, y up, 1-based)
and are mirrored by the constants in overlay/filming/director.dm.

    python3 tools/village-trailer/make_map.py
"""
from pathlib import Path

W, H = 100, 20
OUT = Path(__file__).resolve().parent / 'overlay' / 'filming' / 'village.dmm'

OUT_AREA = '/area/caribbean/nomads'
GRASS = '/turf/floor/grass'
DIRT = '/turf/floor/dirt'
ROAD = '/turf/floor/dirt/dust'
PLOUGH = '/turf/floor/dirt/ploughed'
WOOD = '/turf/floor/wood'
STONE = '/turf/floor/plating/cobblestone'
WALL = '/turf/wall/wood'

# Each cell: [turf, [objects...]]
grid = {(x, y): [GRASS, []] for x in range(1, W + 1) for y in range(1, H + 1)}


def put(x, y, obj):
    grid[(x, y)][1].append(obj)


def turf(x, y, t):
    grid[(x, y)][0] = t


def rect(x1, y1, x2, y2, t):
    for x in range(x1, x2 + 1):
        for y in range(y1, y2 + 1):
            turf(x, y, t)


# Main road (carriage route) and the paths joining each station to it.
rect(1, 6, 72, 6, ROAD)
rect(13, 7, 14, 12, DIRT)          # meadow -> farm footpath
rect(27, 7, 29, 10, DIRT)          # farm -> bakery footpath

# Meadow: wild bushes with seeds ready for gathering.
for x, y in [(6, 10), (8, 11), (10, 10), (4, 12), (9, 13)]:
    put(x, y, '/obj/structure/wild/smallbush')
for x, y in [(3, 9), (5, 14), (11, 12), (7, 8), (12, 14)]:
    put(x, y, '/obj/structure/wild/tallgrass')

# Farm: ploughed plot, mature wheat rows to the north, empty rows south.
rect(15, 8, 26, 13, PLOUGH)
for x in range(16, 26):
    for y in (11, 12, 13):
        put(x, y, '/obj/structure/farming/plant/wheat')
for x in range(15, 27):
    put(x, 14, '/obj/structure/grille/fence/picket')

# Open-air bakery: wooden floor, back wall, mill, oven, water and counter.
rect(30, 8, 39, 13, WOOD)
rect(30, 14, 39, 14, WALL)
put(32, 12, '/obj/structure/mill/large')
put(35, 13, '/obj/structure/oven')
put(37, 13, '/obj/item/weapon/reagent_containers/glass/barrel/water')
for x in (33, 34, 35, 36):
    put(x, 9, '/obj/structure/table/wood')
put(38, 13, '/obj/structure/closet/crate/wood')
put(31, 14, '/obj/structure/sign/custom{name = "Village Bakery"; desc = "Fresh bread every day!"}')

# Station: cobblestone platform north of the rails, rails to the east edge.
rect(66, 4, 84, 5, STONE)
for x in range(56, W + 1):
    put(x, 3, '/obj/structure/rails/regular/horizontal')
put(70, 5, '/obj/structure/sign/custom{name = "Civ13 Station"; desc = "Trains depart east."}')
for x in (68, 74, 80):
    put(x, 5, '/obj/structure/bed/chair/wood')

# Scenery: tree lines along the north and south edges.
for x in range(2, W, 5):
    put(x, 18, '/obj/structure/wild/tree/live_tree')
for x in range(4, 60, 7):
    put(x, 2, '/obj/structure/wild/tree/live_tree')
for x in range(42, 64, 4):
    put(x, 10, '/obj/structure/wild/tree/live_tree')


def main():
    keys = {}
    rows = []
    for y in range(H, 0, -1):
        row = []
        for x in range(1, W + 1):
            t, objs = grid[(x, y)]
            cell = ','.join(objs + [t, OUT_AREA])
            if cell not in keys:
                n = len(keys)
                keys[cell] = chr(97 + n // 26) + chr(97 + n % 26)
            row.append(keys[cell])
        rows.append(''.join(row))
    lines = ['"%s" = (%s)' % (k, cell) for cell, k in keys.items()]
    lines.append('')
    lines.append('(1,1,1) = {"')
    lines.extend(rows)
    lines.append('"}')
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text('\n'.join(lines) + '\n', newline='\n')
    print(OUT, len(keys), 'keys')


if __name__ == '__main__':
    main()
