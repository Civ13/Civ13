#!/usr/bin/env python3
"""Writes maps/313bc/ides_of_march.dmm, the Ides of March TDM map.

The map is built from existing tiles and props only. North is up:

  - the Curia of Pompey at the north end, with an apse for Pompey's statue,
    a dais for Caesar's chair, tiered benches behind two rows of columns,
    three archways onto the porch, a door on each side and two at the back;
  - the Portico of Pompey in front of it: a walled garden court with
    colonnades, plane trees, two fountains and statues;
  - the Via along the south side of the portico and Caesar's domus beyond it,
    where his party gathers;
  - streets, alleys and city blocks on both sides: baths, tabernae, an insula,
    a market, a temple of Venus Victrix, workshops, a tavern, a bakery and a
    warehouse. Most buildings have two ways out, so a chase has somewhere to go.

Run it again after changing the layout:

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

# Floors.
COBBLE = '/turf/floor/plating/cobblestone'
COBBLE_DARK = '/turf/floor/plating/cobblestone/dark'
COBBLE_V = '/turf/floor/plating/cobblestone/vertical'
GRASS = '/turf/floor/grass'
DIRT = '/turf/floor/dirt'
DUST = '/turf/floor/dirt/dust'
WATER = '/turf/floor/beach/water'
MARBLE = '/turf/floor/plating/marble'
MARBLE_ORNATE = '/turf/floor/plating/marble/ornate'
MARBLE_TILE = '/turf/floor/plating/marble/tile'
MARBLE_PINK = '/turf/floor/plating/marble/pink'
MARBLE_GRID = '/turf/floor/plating/marble/grid'
MOSAIC = '/turf/floor/plating/marble/decorative_tile'
WOOD = '/turf/floor/plating/tiled/woodh'
WOOD_V = '/turf/floor/plating/tiled/woodv'
BRICK_FLOOR = '/turf/floor/plating/tiled'
RED_CARPET = '/turf/floor/carpet/redcarpet'
PURPLE_CARPET = '/turf/floor/carpet/purplecarpet'
EDGE = '/turf/wall/indestructable/black'

# Walls and openings.
MARBLE_WALL = '/obj/covers/marble_wall/classic'
MARBLE_PANEL = '/obj/covers/marble_wall/grecian'
MARBLE_ARCH = '/obj/covers/stone_wall/classic/archway/marble'
ARCH = '/obj/covers/marble_wall/grecian/archway'
VILLA = '/obj/covers/stone_wall/classic/villa'
VILLA_PILLAR = '/obj/covers/stone_wall/classic/villa/pillared'
VILLA_AQUILA = '/obj/covers/stone_wall/classic/villa/relief/aquila'
VILLA_GREEK = '/obj/covers/stone_wall/classic/villa/relief/greek'
VILLA_GLADIATOR = '/obj/covers/stone_wall/classic/villa/relief/gladiator'
VILLA_DOORWAY = '/obj/covers/stone_wall/classic/villa_doorway'
STONE = '/obj/covers/stone_wall/classic'
STONE_ARCH = '/obj/covers/stone_wall/classic/archway'
BRICK = '/obj/covers/brick_wall'
SANDSTONE = '/obj/covers/sandstone_wall/classic'
SANDSTONE_ARCH = '/obj/covers/sandstone_wall/classic/archway'
CLAY = '/obj/covers/clay_wall/redearth'
DOOR = '/obj/structure/simple_door/key_door/anyone/roman'
STAIRS = '/obj/covers/cobblestone/stairs'

# Props.
COLUMN = '/obj/structure/mine_support/stone/ionic'
PILLAR = '/obj/structure/religious/monument/pillar_monument'
THRONE = '/obj/structure/bed/chair/throne{dir = 2; name = "Caesar\'s chair"; desc = "The gilded chair the senate voted to the Dictator."}'
BRAZIER = '/obj/structure/brazier/marble/lit'
LANTERN = '/obj/item/flashlight/lantern/on/anchored'
FOUNTAIN = '/obj/structure/fountain'
WELL = '/obj/structure/sink/well/marble'
VENUS = '/obj/structure/religious/monument/venus'
TABLE = '/obj/structure/table/wood'
MARBLE_TABLE = '/obj/structure/table/marble'
ROUND_TABLE = '/obj/structure/table/fancy'
SHELF = '/obj/structure/table/rack/shelf/wooden'
STALL = '/obj/structure/props/marketstall'
URN = '/obj/structure/closet/crate/urn'
URN_STAND = '/obj/structure/closet/crate/urn/stand'
BARREL = '/obj/structure/closet/crate/barrel'
CRATE = '/obj/structure/closet/crate/empty'
CHEST = '/obj/structure/closet/crate/chest/treasury'
HAY = '/obj/structure/hay_bale'
POT = '/obj/structure/pot'
PLANT = '/obj/structure/potted_plant'
CAMPFIRE = '/obj/structure/oven/fireplace'
MILL = '/obj/structure/mill'
LOOM = '/obj/structure/loom'
ANVIL = '/obj/structure/anvil'
BOOKCASE = '/obj/structure/bookcase'
BED = '/obj/structure/bed/wood'
CURTAIN = '/obj/structure/curtain/open/red'
AMPHORA = '/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/amphora/wine'
AMPHORA_WATER = '/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/amphora/water'
TREE = '/obj/structure/wild/tree/live_tree'
BLOSSOM = '/obj/structure/wild/jungle/cherry{name = "almond tree"; desc = "An almond tree, in blossom for the Ides of March."}'
BUSH = '/obj/structure/wild/bush'
HEDGE = '/obj/structure/wild/bush/big'
SHRUB = '/obj/structure/wild/smallbush'
FLOWERS = '/obj/structure/wild/flowers'
TALLGRASS = '/obj/structure/wild/tallgrass'
SENATE = '/obj/effect/landmark{name = "JoinLateIdesSenate"}'
PARTY = '/obj/effect/landmark{name = "JoinLateIdesCaesar"}'
METADATA = '/obj/map_metadata/ides_of_march'


def statue(name, desc):
    return '/obj/structure/religious/statue{name = "%s"; desc = "%s"}' % (name, desc)


def bench(direction, end=''):
    return '/obj/structure/bed/chair/wood/bleacher%s{dir = %d}' % (end, direction)


def stool(direction):
    return '/obj/structure/bed/chair/wood{dir = %d}' % direction


def railing(direction):
    return '/obj/structure/window/barrier/railing/stone{dir = %d}' % direction


# grid[(x, y)] = [wall or None, objs list, turf, area], 1-based like the game.
grid = {}


def put(x, y, turf=None, area=None, objs=()):
    cell = grid[(x, y)]
    cell[1] += list(objs)
    cell[2] = turf or cell[2]
    cell[3] = area or cell[3]


def rect(x1, y1, x2, y2, **kw):
    for x in range(x1, x2 + 1):
        for y in range(y1, y2 + 1):
            put(x, y, **kw)


def wall(x, y, kind):
    grid[(x, y)][0] = kind


def wall_line(x1, y1, x2, y2, kind):
    for x in range(x1, x2 + 1):
        for y in range(y1, y2 + 1):
            wall(x, y, kind)


def opening(x, y, *objs, **kw):
    """Removes the wall from a tile (for a door or archway) and adds objs."""
    grid[(x, y)][0] = None
    put(x, y, objs=objs, **kw)


def building(x1, y1, x2, y2, kind, floor, area=HOUSE):
    """A walled box: floor and area inside, kind of wall all around."""
    rect(x1, y1, x2, y2, turf=floor)
    rect(x1 + 1, y1 + 1, x2 - 1, y2 - 1, area=area)
    wall_line(x1, y1, x2, y1, kind)
    wall_line(x1, y2, x2, y2, kind)
    wall_line(x1, y1, x1, y2, kind)
    wall_line(x2, y1, x2, y2, kind)


def door(x, y, kind=DOOR, area=HOUSE):
    opening(x, y, kind, area=area)


def scatter(kind, spots):
    for x, y in spots:
        put(x, y, objs=[kind])


for x in range(1, W + 1):
    for y in range(1, H + 1):
        if x in (1, W) or y in (1, H):
            grid[(x, y)] = [None, [], EDGE, VOID]
        else:
            grid[(x, y)] = [None, [], COBBLE, STREET]
put(1, 1, objs=[METADATA])

# ---------------------------------------------------------------- streets
# The Via runs east-west between the portico and Caesar's domus; a street runs
# up each side of the portico and the Curia, and a back street behind it.
rect(2, 13, 63, 15, turf=COBBLE_DARK)
rect(12, 16, 14, 55, turf=COBBLE_V)
rect(50, 16, 52, 55, turf=COBBLE_V)
rect(2, 52, 63, 55, turf=COBBLE)
rect(30, 13, 34, 15, turf=COBBLE)          # worn crossing in front of the domus
# Gardens along the south edge of the city, and dirt lanes down to them.
rect(2, 2, 63, 3, turf=GRASS)
rect(2, 4, 63, 4, turf=DIRT)
rect(20, 4, 21, 12, turf=DIRT)
rect(43, 4, 44, 12, turf=DIRT)
rect(11, 4, 12, 12, turf=DIRT)
rect(54, 4, 55, 12, turf=DIRT)
scatter(TREE, ((5, 2), (17, 2), (26, 2), (47, 2), (60, 2)))
scatter(BLOSSOM, ((12, 2), (36, 2), (55, 2)))
scatter(HEDGE, ((8, 3), (22, 3), (30, 3), (42, 3), (51, 3)))
scatter(BUSH, ((3, 3), (15, 3), (34, 3), (58, 3), (62, 3)))
scatter(FLOWERS, ((9, 2), (19, 3), (24, 2), (28, 3), (33, 2), (40, 2), (45, 3), (53, 2), (57, 3)))
scatter(TALLGRASS, ((2, 2), (14, 2), (20, 2), (44, 2), (49, 2), (63, 2), (63, 3)))

# --------------------------------------------------- the Curia of Pompey
# Hall x 21-43, y 33-51, with the apse behind the north wall.
CX1, CY1, CX2, CY2 = 21, 33, 43, 51
building(CX1, CY1, CX2, CY2, MARBLE_WALL, MARBLE_ORNATE, area=CURIA)
for x in range(CX1, CX2 + 1, 2):             # carved panels along the long walls
    for y in (CY1, CY2):
        wall(x, y, MARBLE_PANEL)
for y in range(CY1, CY2 + 1, 3):
    wall(CX1, y, MARBLE_PANEL)
    wall(CX2, y, MARBLE_PANEL)

# Apse: a curved recess for Pompey's statue.
rect(28, 52, 36, 52, turf=MARBLE_PINK, area=CURIA)
rect(30, 53, 34, 53, turf=MARBLE_PINK, area=CURIA)
for x, y in ((27, 52), (37, 52), (28, 53), (29, 53), (35, 53), (36, 53),
             (29, 54), (30, 54), (31, 54), (32, 54), (33, 54), (34, 54), (35, 54)):
    wall(x, y, MARBLE_PANEL)
for x in range(29, 36):
    opening(x, 51, turf=MARBLE_PINK, area=CURIA)
put(29, 51, objs=[COLUMN])
put(35, 51, objs=[COLUMN])
put(32, 53, objs=[statue('statue of Pompey', 'Gnaeus Pompeius Magnus, in marble. He looks down on the chair of the man who beat him.')])
put(30, 53, objs=[URN_STAND])
put(34, 53, objs=[URN_STAND])
put(28, 52, objs=[BRAZIER])
put(36, 52, objs=[BRAZIER])

# Dais for Caesar's chair, at the foot of the statue.
rect(28, 47, 36, 50, turf=MOSAIC)
rect(30, 47, 34, 50, turf=PURPLE_CARPET)
rect(28, 46, 36, 46, turf=MARBLE_GRID)
put(32, 49, objs=[THRONE])
put(29, 50, objs=[PLANT])
put(35, 50, objs=[PLANT])
put(28, 48, objs=[MARBLE_TABLE])
put(36, 48, objs=[MARBLE_TABLE])

# Three tiers of benches down each side, facing the floor of the house, with
# a cross aisle between the side doors.
for xs, floor in (((22, 23), MARBLE_TILE), ((24, 25), MARBLE_PINK), ((26, 27), MARBLE_TILE),
                  ((37, 38), MARBLE_TILE), ((39, 40), MARBLE_PINK), ((41, 42), MARBLE_TILE)):
    rect(xs[0], 35, xs[1], 47, turf=floor)
rect(22, 42, 42, 42, turf=MARBLE)
rect(28, 34, 28, 45, turf=MARBLE_GRID)
rect(36, 34, 36, 45, turf=MARBLE_GRID)
rect(32, 34, 32, 45, turf=MOSAIC)
BENCH_ROWS = [y for y in range(36, 47) if y not in (41, 42, 43)]
for y in BENCH_ROWS:
    end = '/l' if y in (40, 46) else '/r' if y in (36, 44) else ''
    for x in (23, 25, 27):
        put(x, y, objs=[bench(4, end), SENATE])
    for x in (37, 39, 41):
        put(x, y, objs=[bench(8, end), SENATE])
for y in (35, 38, 41, 43, 46):
    put(28, y, objs=[COLUMN])
    put(36, y, objs=[COLUMN])
for x, y in ((22, 34), (42, 34), (22, 50), (42, 50)):
    put(x, y, objs=[BRAZIER])
for x, y in ((22, 48), (42, 48), (26, 34), (38, 34)):
    put(x, y, objs=[LANTERN])
put(24, 49, objs=[MARBLE_TABLE])
put(25, 49, objs=[MARBLE_TABLE])
put(39, 49, objs=[BOOKCASE])
put(40, 49, objs=[BOOKCASE])


def curia_door(x, y, dx, dy, kind):
    """A way out of the Curia, with a grace wall on the tile outside it."""
    opening(x, y, kind, turf=MARBLE_ORNATE, area=CURIA)
    put(x + dx, y + dy, area=DOORWAY)


for x in (31, 32, 33):                       # main archways onto the porch
    curia_door(x, CY1, 0, -1, ARCH)
curia_door(CX1, 42, -1, 0, DOOR)             # side doors
curia_door(CX2, 42, 1, 0, DOOR)
curia_door(24, CY2, 0, 1, DOOR)              # back doors beside the apse
curia_door(40, CY2, 0, 1, DOOR)

# Porch: ten columns on a stepped podium.
rect(21, 30, 43, 32, turf=MARBLE_TILE)
rect(22, 29, 42, 29, turf=MARBLE_TILE, objs=[STAIRS])
for x in (22, 24, 26, 28, 30, 34, 36, 38, 40, 42):
    put(x, 30, objs=[COLUMN])
put(29, 32, objs=[BRAZIER])
put(35, 32, objs=[BRAZIER])
for x in (23, 26, 29, 35, 38, 41):            # inlaid panels in the porch floor
    put(x, 31, turf=MOSAIC)
put(21, 31, objs=[URN])
put(43, 31, objs=[URN])

# ---------------------------------------------------- Portico of Pompey
# Garden court x 20-44, y 17-28, colonnades west, east and south, a wall with
# a gate on the west and east sides.
rect(16, 16, 48, 28, turf=GRASS)
rect(16, 16, 19, 32, turf=MARBLE_TILE)       # west walk
rect(45, 16, 48, 32, turf=MARBLE_TILE)       # east walk
rect(16, 16, 48, 16, turf=MARBLE_TILE)       # south walk
rect(20, 29, 21, 29, turf=MARBLE_TILE)
rect(43, 29, 44, 29, turf=MARBLE_TILE)
rect(20, 30, 20, 32, turf=MARBLE_TILE)
rect(44, 30, 44, 32, turf=MARBLE_TILE)
wall_line(15, 16, 15, 32, VILLA)
wall_line(49, 16, 49, 32, VILLA)
for y in (16, 20, 25, 29, 32):
    wall(15, y, VILLA_PILLAR)
    wall(49, y, VILLA_PILLAR)
wall(15, 18, VILLA_GREEK)
wall(49, 18, VILLA_GREEK)
wall(15, 27, VILLA_GLADIATOR)
wall(49, 27, VILLA_GLADIATOR)
for y in (22, 23):                           # side gates
    opening(15, y, MARBLE_ARCH, turf=MARBLE_TILE)
    opening(49, y, MARBLE_ARCH, turf=MARBLE_TILE)
for y in (17, 19, 21, 24, 26, 28):
    put(19, y, objs=[COLUMN])
    put(45, y, objs=[COLUMN])
for x in list(range(16, 31, 2)) + list(range(34, 49, 2)):
    put(x, 16, objs=[COLUMN])
for y in (18, 21, 24, 27, 30):               # inlaid panels down the walks
    put(17, y, turf=MOSAIC)
    put(47, y, turf=MOSAIC)
for x in (21, 25, 29, 35, 39, 43):
    put(x, 16, turf=MOSAIC)
for x, y in ((16, 20), (16, 25), (48, 20), (48, 25), (16, 31), (48, 31)):
    put(x, y, objs=[LANTERN])
for x, y in ((16, 18), (16, 27), (48, 18), (48, 27)):
    put(x, y, objs=[bench(4 if x == 16 else 8)])
# Paths: the axis from the Via to the Curia steps, and a cross path between
# the side gates, opening into a paved square round each fountain.
rect(31, 17, 33, 28, turf=MARBLE_TILE)
rect(20, 22, 44, 23, turf=MARBLE_TILE)
rect(31, 22, 33, 23, turf=MOSAIC)
for fx in (23, 38):
    rect(fx - 1, 20, fx + 4, 25, turf=MARBLE)
    rect(fx, 21, fx + 3, 24, turf=MARBLE_GRID)
    put(fx + 1, 22, objs=[FOUNTAIN])         # 2x2, anchored at its south-west tile
    for x, y in ((fx - 1, 20), (fx + 4, 20), (fx - 1, 25), (fx + 4, 25)):
        put(x, y, objs=[PLANT])
# Plane trees, hedges along the axis, statues of the Muses, flower beds.
scatter(TREE, ((21, 18), (28, 18), (36, 18), (43, 18), (21, 26), (43, 26)))
scatter(BLOSSOM, ((29, 26), (35, 26)))
for y in (17, 18, 19, 20, 25, 26, 27, 28):
    put(30, y, objs=[HEDGE])
    put(34, y, objs=[HEDGE])
for x, y, muse in ((30, 21, 'Clio'), (34, 21, 'Thalia'), (30, 24, 'Calliope'), (34, 24, 'Urania')):
    put(x, y, objs=[statue('statue of %s' % muse, 'One of the Muses that Pompey set up in his portico.')])
scatter(FLOWERS, ((20, 17), (24, 18), (26, 17), (29, 20), (20, 20), (35, 20), (38, 18), (41, 17), (44, 20),
                  (20, 25), (24, 27), (26, 28), (27, 26), (37, 28), (38, 26), (41, 27), (44, 25), (44, 28)))
scatter(SHRUB, ((23, 17), (27, 19), (37, 19), (40, 18), (22, 27), (25, 26), (39, 27), (42, 28), (20, 28)))
scatter(BUSH, ((29, 17), (35, 17), (29, 28), (35, 28), (28, 21), (36, 24)))
for x in (24, 25, 26, 27, 37, 38, 39, 40):   # low walls: cover on the lawns
    put(x, 19, objs=[railing(1)])
    put(x, 26, objs=[railing(2)])

# ------------------------------------------------- beside the Curia: west
# The market: stalls and goods between the street and the Curia wall.
rect(15, 33, 20, 51, turf=DUST)
rect(20, 33, 20, 51, turf=COBBLE)
for x, y in ((17, 35), (17, 39), (17, 45), (17, 49)):
    put(x, y, objs=[STALL])
    put(x + 1, y, objs=[TABLE, AMPHORA if y % 2 else AMPHORA_WATER])
scatter(BARREL, ((16, 36), (18, 40), (16, 46)))
scatter(CRATE, ((18, 36), (16, 40), (18, 46), (16, 50), (18, 50)))
scatter(URN, ((19, 37), (15, 44), (19, 47)))
scatter(HAY, ((15, 34), (15, 51)))
put(16, 42, objs=[WELL])
put(18, 43, objs=[LANTERN])
put(18, 33, objs=[LANTERN])

# ------------------------------------------------- beside the Curia: east
# A sacred grove with an open-air altar.
rect(44, 33, 49, 51, turf=GRASS)
rect(44, 33, 44, 51, turf=COBBLE)
rect(45, 42, 49, 42, turf=MARBLE_TILE)
rect(46, 41, 48, 43, turf=MARBLE_TILE)
put(47, 42, objs=[MARBLE_TABLE, AMPHORA])    # the altar
put(46, 43, objs=[BRAZIER])
put(48, 43, objs=[BRAZIER])
scatter(TREE, ((46, 36), (48, 47), (46, 49)))
scatter(BLOSSOM, ((48, 38),))
scatter(HEDGE, ((49, 34), (49, 35), (49, 36), (49, 48), (49, 49), (49, 50)))
scatter(FLOWERS, ((45, 34), (47, 39), (45, 45), (47, 45), (48, 50), (45, 38)))
scatter(SHRUB, ((47, 34), (45, 40), (48, 45), (45, 51)))
put(46, 39, objs=[statue('statue of Victory', 'Winged Victory, holding out a wreath.')])
put(46, 46, objs=[bench(1)])

# -------------------------------------------------------- Caesar's domus
# x 22-42, y 4-12: atrium with an impluvium, dining room and kitchen to the
# west, study and bedroom to the east, a back door into the garden.
building(22, 4, 42, 12, VILLA, MARBLE)
for x, y in ((22, 4), (42, 4), (22, 12), (42, 12), (29, 12), (35, 12), (22, 8), (42, 8)):
    wall(x, y, VILLA_PILLAR)
wall(26, 12, VILLA_AQUILA)
wall(38, 12, VILLA_AQUILA)
wall_line(28, 5, 28, 11, VILLA)
wall_line(36, 5, 36, 11, VILLA)
wall_line(37, 8, 41, 8, VILLA)
wall_line(23, 8, 25, 8, VILLA)
door(32, 12)
door(39, 4)
opening(28, 9, VILLA_DOORWAY)
opening(28, 6, VILLA_DOORWAY)
opening(36, 10, VILLA_DOORWAY)
opening(36, 6, VILLA_DOORWAY)
opening(39, 8, CURTAIN)
rect(29, 5, 35, 11, turf=MARBLE_TILE)        # atrium
rect(31, 7, 33, 9, turf=MOSAIC)
put(32, 8, turf=WATER)                       # impluvium
for x in range(29, 36):
    for y in range(6, 11):
        if (x, y) != (32, 8):
            put(x, y, objs=[PARTY])
put(29, 11, objs=[BRAZIER])
put(35, 11, objs=[BRAZIER])
put(29, 5, objs=[statue('statue of Venus Genetrix', 'The mother of the Julian house.')])
put(35, 5, objs=[URN_STAND])
put(32, 5, objs=[CHEST])
rect(23, 9, 27, 11, turf=RED_CARPET)         # triclinium
put(25, 10, objs=[TABLE, AMPHORA])
put(26, 10, objs=[TABLE])
put(23, 11, objs=[BED])
put(25, 11, objs=[BED])
put(23, 9, objs=[PLANT])
put(27, 11, objs=[LANTERN])
rect(23, 5, 27, 7, turf=BRICK_FLOOR)         # kitchen
put(23, 7, objs=[POT])
put(23, 5, objs=[BARREL])
put(24, 5, objs=[SHELF])
put(25, 5, objs=[SHELF])
put(27, 5, objs=[URN])
put(25, 7, objs=[TABLE])
rect(37, 9, 41, 11, turf=PURPLE_CARPET)      # tablinum
put(39, 11, objs=[BOOKCASE])
put(40, 11, objs=[BOOKCASE])
put(41, 11, objs=[LANTERN])
put(40, 10, objs=[ROUND_TABLE])
put(41, 10, objs=[stool(8)])
put(37, 11, objs=[CHEST])
rect(37, 5, 41, 7, turf=WOOD)                # cubiculum
put(41, 7, objs=[BED])
put(41, 5, objs=[BED])
put(37, 7, objs=[URN])
put(37, 5, objs=[PLANT])
for x in (30, 34):                           # the front of the house
    put(x, 13, objs=[PLANT])
put(31, 13, objs=[LANTERN])
put(33, 13, objs=[LANTERN])

# ------------------------------------------------------ south-west block
# Horreum (warehouse) with a wide archway onto the Via.
building(2, 5, 10, 12, STONE, DIRT)
for x in (5, 6):
    opening(x, 12, STONE_ARCH, area=HOUSE)
door(10, 8)
scatter(CRATE, ((3, 6), (4, 6), (3, 7), (8, 6), (9, 6), (9, 10)))
scatter(BARREL, ((3, 10), (3, 11), (4, 11), (8, 11)))
scatter(HAY, ((6, 6), (7, 6), (9, 11)))
scatter(URN, ((5, 9), (7, 9)))
put(9, 8, objs=[LANTERN])
# Caupona (tavern) on the corner.
building(13, 5, 19, 12, BRICK, WOOD)
door(16, 12)
door(19, 8)
for x, y in ((14, 9), (15, 9), (16, 9), (17, 9)):
    put(x, y, objs=[TABLE])
put(15, 9, objs=[AMPHORA])
put(17, 9, objs=[AMPHORA_WATER])
scatter(BARREL, ((14, 6), (15, 6), (18, 6)))
put(16, 6, objs=[POT])
put(17, 6, objs=[SHELF])
put(14, 11, objs=[stool(4)])
put(18, 11, objs=[ROUND_TABLE])
put(18, 10, objs=[stool(2)])
put(14, 7, objs=[LANTERN])
put(15, 13, objs=[BARREL])

# ------------------------------------------------------ south-east block
# A small insula of two flats.
building(45, 5, 53, 12, SANDSTONE, WOOD)
wall_line(49, 5, 49, 12, SANDSTONE)
door(47, 12)
door(51, 12)
door(45, 8)
door(53, 7)
opening(49, 10, CURTAIN)
for x, y in ((46, 6), (52, 10)):
    put(x, y, objs=[BED])
put(46, 10, objs=[TABLE])
put(46, 11, objs=[stool(1)])
put(48, 6, objs=[URN])
put(50, 6, objs=[SHELF])
put(52, 6, objs=[CRATE])
put(50, 11, objs=[LANTERN])
# Pistrinum (bakery).
building(56, 5, 63, 12, BRICK, BRICK_FLOOR)
door(59, 12)
door(56, 8)
put(61, 10, objs=[MILL])
put(62, 6, objs=[CAMPFIRE])
put(60, 6, objs=[TABLE])
put(59, 6, objs=[TABLE])
put(57, 6, objs=[BARREL])
put(62, 11, objs=[HAY])
put(57, 11, objs=[SHELF])
put(62, 8, objs=[LANTERN])

# ----------------------------------------------------- west of the portico
# Balneum (baths): a pool hall facing the portico's west gate.
building(2, 16, 11, 28, STONE, MARBLE_TILE)
wall_line(3, 25, 10, 25, STONE)
door(11, 22)
door(6, 28)
opening(6, 25, VILLA_DOORWAY)
rect(5, 18, 8, 22, turf=WATER)
rect(4, 17, 9, 23, turf=MARBLE)
rect(5, 18, 8, 22, turf=WATER)
for x, y in ((3, 17), (10, 17), (3, 24), (10, 24)):
    put(x, y, objs=[COLUMN])
put(3, 20, objs=[bench(4)])
put(10, 19, objs=[URN_STAND])
put(3, 23, objs=[BRAZIER])
put(10, 24, objs=[LANTERN])
rect(3, 26, 10, 27, turf=WOOD)               # changing room
put(3, 27, objs=[SHELF])
put(4, 27, objs=[SHELF])
put(9, 27, objs=[bench(2)])
put(10, 27, objs=[bench(2)])
put(10, 26, objs=[URN])
# Alley, then a row of three tabernae with a lane behind them.
rect(2, 29, 11, 30, turf=DIRT)
rect(2, 31, 3, 40, turf=DIRT)
rect(2, 41, 11, 42, turf=DIRT)
building(4, 31, 11, 40, CLAY, WOOD_V)
wall_line(4, 34, 11, 34, CLAY)
wall_line(4, 37, 11, 37, CLAY)
for y, goods in ((32, (AMPHORA, URN, BARREL)), (35, (AMPHORA_WATER, CRATE, SHELF)), (38, (AMPHORA, SHELF, LOOM))):
    opening(11, y, area=HOUSE)               # open shop front
    opening(11, y + 1, TABLE, goods[0], area=HOUSE)   # with a counter across half of it
    put(5, y + 1, objs=[goods[1]])
    put(6, y + 1, objs=[goods[2]])
    put(5, y, objs=[SHELF])
    put(9, y + 1, objs=[stool(4)])
door(4, 35)                                  # back door of the middle shop
put(8, 38, objs=[LANTERN])
put(8, 32, objs=[LANTERN])
scatter(CRATE, ((2, 30), (3, 41)))
scatter(BARREL, ((2, 42), (10, 29)))
put(7, 41, objs=[HAY])
# Insula: two flats and a stair lobby, doors on the street and the alley.
building(2, 43, 11, 51, BRICK, WOOD)
wall_line(3, 47, 10, 47, BRICK)
wall_line(7, 44, 7, 46, BRICK)
door(11, 45)
door(11, 49)
door(5, 43)
door(8, 51)
opening(7, 45, CURTAIN)
opening(5, 47, CURTAIN)
put(3, 44, objs=[BED])
put(3, 46, objs=[URN])
put(10, 46, objs=[TABLE])
put(9, 46, objs=[stool(4)])
put(8, 44, objs=[SHELF])
put(3, 50, objs=[BED])
put(3, 48, objs=[BED])
put(6, 50, objs=[TABLE, AMPHORA_WATER])
put(10, 50, objs=[POT])
put(10, 48, objs=[LANTERN])
put(9, 44, objs=[LANTERN])

# ----------------------------------------------------- east of the portico
# Temple of Venus Victrix in its precinct, facing the portico's east gate.
rect(53, 16, 63, 26, turf=MARBLE_TILE)
rect(53, 16, 63, 16, turf=GRASS)
rect(53, 26, 63, 26, turf=GRASS)
building(57, 18, 63, 24, MARBLE_WALL, MARBLE_ORNATE)
for x, y in ((57, 18), (57, 24), (63, 18), (63, 24), (60, 18), (60, 24), (63, 21)):
    wall(x, y, MARBLE_PANEL)
opening(57, 21, ARCH, area=HOUSE)
rect(58, 21, 61, 21, turf=RED_CARPET)
put(61, 21, objs=[VENUS])
put(62, 19, objs=[BRAZIER])
put(62, 23, objs=[BRAZIER])
put(58, 19, objs=[URN_STAND])
put(58, 23, objs=[URN_STAND])
rect(55, 18, 55, 24, objs=[STAIRS + '{dir = 4}'])
for y in (18, 20, 22, 24):
    put(56, y, objs=[COLUMN])
put(53, 21, objs=[MARBLE_TABLE])             # altar in front of the steps
put(53, 19, objs=[BRAZIER])
put(53, 23, objs=[BRAZIER])
scatter(HEDGE, ((53, 16), (55, 16), (57, 16), (59, 16), (61, 16), (63, 16),
                (53, 26), (55, 26), (57, 26), (59, 26), (61, 26), (63, 26)))
scatter(FLOWERS, ((54, 16), (58, 16), (62, 16), (56, 26), (60, 26)))
# Alley, then workshops round a yard: a smith and a weaver.
rect(53, 27, 63, 28, turf=DIRT)
rect(53, 39, 63, 40, turf=DIRT)
building(53, 29, 63, 38, STONE, DIRT)
wall_line(58, 29, 58, 38, STONE)
door(53, 32)
door(53, 36, kind=STONE_ARCH)
door(60, 38)
door(56, 29)
opening(58, 34, STONE_ARCH)
put(55, 34, objs=[ANVIL])
put(54, 37, objs=[CAMPFIRE])
put(57, 37, objs=[CRATE])
put(57, 30, objs=[BARREL])
put(54, 30, objs=[TABLE])
put(57, 33, objs=[LANTERN])
rect(59, 30, 62, 37, turf=WOOD)
put(62, 36, objs=[LOOM])
put(62, 33, objs=[LOOM])
put(60, 30, objs=[SHELF])
put(61, 30, objs=[SHELF])
put(62, 30, objs=[CHEST])
put(59, 37, objs=[TABLE])
put(62, 31, objs=[LANTERN])
scatter(CRATE, ((63, 27), (62, 40)))
scatter(BARREL, ((55, 40), (54, 28)))
# Insula round a courtyard, with a passage through from the street to the
# back street.
building(53, 41, 63, 51, SANDSTONE, WOOD)
rect(57, 45, 59, 47, turf=GRASS, area=STREET)
wall_line(56, 44, 60, 44, SANDSTONE)
wall_line(56, 48, 60, 48, SANDSTONE)
wall_line(56, 44, 56, 48, SANDSTONE)
wall_line(60, 44, 60, 48, SANDSTONE)
wall_line(56, 42, 56, 43, SANDSTONE)
wall_line(60, 49, 60, 50, SANDSTONE)
door(53, 46)
door(58, 51)
door(58, 41)
opening(56, 46, SANDSTONE_ARCH)
opening(58, 48, SANDSTONE_ARCH)
opening(58, 44, SANDSTONE_ARCH)
opening(60, 46, CURTAIN)
opening(56, 43, CURTAIN)
opening(60, 49, CURTAIN)
put(58, 46, objs=[WELL])
put(57, 47, objs=[FLOWERS])
put(59, 45, objs=[SHRUB])
put(54, 42, objs=[BED])
put(54, 43, objs=[URN])
put(62, 45, objs=[BED])
put(62, 47, objs=[TABLE])
put(62, 42, objs=[SHELF])
put(61, 42, objs=[BARREL])
put(62, 50, objs=[BED])
put(61, 50, objs=[POT])
put(54, 50, objs=[TABLE, AMPHORA])
put(54, 49, objs=[stool(2)])
put(54, 48, objs=[LANTERN])
put(62, 43, objs=[LANTERN])

# ----------------------------------------------------------- back street
scatter(TREE, ((8, 54), (56, 54)))
scatter(BARREL, ((19, 55), (45, 55)))
scatter(CRATE, ((20, 55), (46, 55), (2, 55)))
scatter(HAY, ((63, 55),))
put(17, 54, objs=[STALL])
put(18, 54, objs=[TABLE, AMPHORA])
put(47, 54, objs=[WELL])
for x, y in ((12, 52), (26, 55), (38, 55), (52, 52), (3, 53), (62, 53)):
    put(x, y, objs=[LANTERN])

# ----------------------------------------------------- street furniture
for x in (4, 10, 18, 24, 40, 46, 54, 60):    # lamps along the Via
    put(x, 15 if x % 4 else 13, objs=[LANTERN])
scatter(PILLAR, ((14, 14), (50, 14)))        # milestones at the crossroads
put(27, 14, objs=[STALL])
put(26, 14, objs=[CRATE])
put(37, 14, objs=[HAY])
put(38, 14, objs=[BARREL])
put(13, 24, objs=[BARREL])
put(13, 38, objs=[CRATE])
put(51, 30, objs=[CRATE])
put(51, 44, objs=[BARREL])
for y in (19, 27, 35, 44, 48):
    put(12, y, objs=[LANTERN])
    put(52, y, objs=[LANTERN])


def tile_text(wall_kind, objs, turf, area):
    return '(' + ','.join(([wall_kind] if wall_kind else []) + list(objs) + [turf, area]) + ')'


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
