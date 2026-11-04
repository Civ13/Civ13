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

# ---------------------------------------------------------------- village dressing
DOOR = '/obj/structure/simple_door/key_door/anyone/wood'
WINDOW = '/obj/structure/window/classic'
LAMP = '/obj/structure/torch_stand/full'
LANTERN = '/obj/item/flashlight/lantern/on/anchored'
FLOWERS = '/obj/structure/wild/flowers'
POT = '/obj/structure/potted_plant'
CRATE = '/obj/structure/closet/crate/empty'
BARREL = '/obj/item/weapon/reagent_containers/glass/barrel/water'
TABLE = '/obj/structure/table/wood'
CHAIR = '/obj/structure/bed/chair/wood/wings'
TREE = '/obj/structure/wild/tree/live_tree'


def building(x1, y1, x2, y2, doors=(), windows=(), floor=WOOD):
    """Walls on the perimeter, a wooden floor inside, doors/windows in the walls."""
    rect(x1, y1, x2, y2, floor)
    for x in range(x1, x2 + 1):
        for y in range(y1, y2 + 1):
            if x in (x1, x2) or y in (y1, y2):
                turf(x, y, WALL)
    for x, y in doors:
        turf(x, y, floor)
        put(x, y, DOOR)
    for x, y in windows:
        turf(x, y, floor)
        put(x, y, WINDOW)


def cottage(x1, y1, door_side='north'):
    """A 7x4 family cottage: bed, table and chairs, cabinet, plant."""
    x2, y2 = x1 + 6, y1 + 3
    front = y2 if door_side == 'north' else y1
    back = y1 + 1 if door_side == 'north' else y2 - 1
    building(x1, y1, x2, y2, doors=[(x1 + 3, front)], windows=[(x1 + 1, front), (x1 + 5, front)])
    inner = y1 + 1 if door_side == 'north' else y2 - 1
    put(x1 + 1, back, '/obj/structure/bed')
    put(x1 + 5, back, '/obj/structure/closet/cabinet')
    put(x1 + 4, inner if back != inner else back, TABLE)
    put(x1 + 2, y1 + 1 if y2 - y1 > 2 else back, '/obj/structure/bookcase')
    outside = front + 1 if door_side == 'north' else front - 1
    put(x1 + 2, outside, POT)
    put(x1 + 4, outside, FLOWERS)


# Homes along the south side of the road (the carriage passes them).
cottage(3, 1)
cottage(17, 1)
cottage(44, 1)
# Blacksmith's yard opposite the bakery.
rect(28, 1, 38, 4, DIRT)
put(31, 3, '/obj/structure/anvil')
put(33, 3, BARREL)
put(35, 2, CRATE)
put(36, 2, CRATE)
put(29, 4, LAMP)
put(37, 4, '/obj/structure/sign/custom{name = "Smithy"; desc = "Tools mended while you wait."}')
for x in range(28, 39):
    put(x, 1, '/obj/structure/grille/fence/picket')

# North of the road: a small market square and two more cottages.
rect(41, 8, 47, 13, STONE)
for x in (42, 44, 46):
    put(x, 11, TABLE)
for x, item in [(42, 'pumpkin'), (44, 'apple'), (46, 'carrot')]:
    put(x, 11, f'/obj/item/weapon/reagent_containers/food/snacks/grown/{item}')
put(43, 13, BARREL)
put(45, 13, CRATE)
put(47, 13, CRATE)
put(41, 9, LAMP)
put(47, 9, LAMP)
put(44, 12, '/obj/structure/sign/custom{name = "Market"; desc = "Fresh produce from the village farms."}')
cottage(50, 10, door_side='south')
cottage(58, 10, door_side='south')
put(57, 8, LAMP)

# Lamps and flowers along the road verge (y5 keeps the carriage lane clear).
for x in (12, 26, 40, 52):
    put(x, 5, LAMP)
for x, y in [(2, 8), (5, 8), (11, 8), (3, 13), (12, 10), (7, 15), (10, 15), (16, 5),
             (24, 5), (35, 5), (48, 7), (63, 8), (64, 12)]:
    put(x, y, FLOWERS)
for x, y in [(1, 11), (12, 16), (3, 16)]:
    put(x, y, '/obj/structure/wild/rock')

# Farm stores beside the field path.
put(28, 12, CRATE)
put(28, 13, BARREL)

# Station hall north of the platform, lanterns along the platform.
building(74, 6, 83, 10, doors=[(78, 6)], windows=[(76, 6), (81, 6)])
put(75, 9, TABLE)
put(76, 9, CHAIR)
put(82, 9, '/obj/structure/closet/cabinet')
put(80, 9, POT)
put(79, 8, '/obj/structure/sign/custom{name = "Ticket office"; desc = "All trains depart east."}')
for x in (71, 77, 83):
    put(x, 5, LANTERN)

# Scenery: tree lines along the north edge and the empty corners.
for x in range(2, W, 5):
    put(x, 18, TREE)
for x in (13, 26, 41, 52, 66, 88, 94):
    put(x, 2 if x < 56 else 14, TREE)
for x in (86, 91, 97):
    put(x, 8, TREE)


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
