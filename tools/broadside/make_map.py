#!/usr/bin/env python3
"""Writes maps/1713/broadside.dmm, the Broadside TDM map.

Open sea and two sailing ships, one for each side. Each ship is a hull of
ship floors laid over deep water with a tiller at the stern, four rigged
masts down the middle and five guns along each side. When the round starts
the tiller commissions her as a built hull (code/modules/craft/), so she
sails, turns and carries everything aboard; map_metadata/broadside.dm does
the rest.

The French ship lies in the north lane with her bow to the east, the pirate
ship in the south lane with her bow to the west, so the two close on each
other starboard to starboard.

Run it again after changing the layout:

    python3 tools/broadside/make_map.py

--check only compares the generated map with the file and exits 1 when they
differ.
"""
import sys
from pathlib import Path

W, H = 150, 80
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'maps' / '1713' / 'broadside.dmm'

SEA = '/area/caribbean/sea/sea'
VOID = '/area/caribbean/void'
WATER = '/turf/floor/beach/water/deep/saltwater'
EDGE = '/turf/wall/indestructable/black'
PLANK = '/obj/covers/repairedfloor/ship/afloat'
MAST = '/obj/structure/vehicleparts/movement/sail/premade'
BALL = '/obj/item/cannon_ball'
METADATA = '/obj/map_metadata/broadside'

# The hull with the bow to the east, as (dx, dy) from the tiller's tile.
# Square stern, seven tiles of beam, narrowing to a point at the bow.
HULL_LENGTH = 20


def hull_offsets():
    cells = []
    for i in range(HULL_LENGTH):
        if i < 15:
            half = 3
        elif i < 17:
            half = 2
        elif i < 19:
            half = 1
        else:
            half = 0
        for dy in range(-half, half + 1):
            cells.append((i - 1, dy))   # the tiller stands one tile in from the stern
    return cells


GUN_ROWS = (2, 5, 8, 11)        # tiles from the tiller, along the keel
MAST_ROWS = (3, 6, 9, 12)
EXTRA_GUN = 13                  # a fifth gun each side, forward


def ship(grid, tx, ty, bow, side):
    """Lays one ship with its tiller at (tx, ty). bow is +1 (east) or -1 (west)."""
    tiller = '/obj/structure/hull_tiller/broadside/%s' % side
    for dx, dy in hull_offsets():
        grid[(tx + bow * dx, ty + dy)] = [PLANK]
    grid[(tx, ty)].append(tiller)
    for k in MAST_ROWS:
        grid[(tx + bow * k, ty)].append(MAST)
    for k in GUN_ROWS + (EXTRA_GUN,):
        x = tx + bow * k
        # North-side guns stand one in from the rail, since a gun fills its
        # own tile and the one north of it; south-side guns on the rail.
        grid[(x, ty + 2)].append('/obj/structure/cannon{dir = 1}')
        grid[(x, ty - 3)].append('/obj/structure/cannon{dir = 2}')
        grid[(x, ty + 1)].append(BALL)
        grid[(x, ty - 1)].append(BALL)
    # Stores at the stern, either side of the tiller.
    grid[(tx, ty + 2)].append('/obj/structure/closet/crate/cannonball')
    grid[(tx, ty - 2)].append('/obj/structure/closet/crate/cannonball')
    grid[(tx - bow, ty + 2)].append('/obj/structure/closet/crate/musketball')
    grid[(tx - bow, ty - 2)].append('/obj/structure/closet/crate/blunderbuss_ammo')


grid = {}
ship(grid, 20, 55, 1, 'french')
ship(grid, 130, 25, -1, 'pirates')


def tile_text(x, y):
    if x == 1 and y == 1:
        return '(%s,%s,%s)' % (METADATA, EDGE, VOID)
    objs = grid.get((x, y), [])
    return '(' + ','.join(list(objs) + [WATER, SEA]) + ')'


keys = {}
LETTERS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'


def key_for(text):
    if text not in keys:
        n = len(keys)
        keys[text] = LETTERS[n // len(LETTERS)] + LETTERS[n % len(LETTERS)]
    return keys[text]


columns = []
for x in range(1, W + 1):
    columns.append([key_for(tile_text(x, y)) for y in range(H, 0, -1)])

lines = ['"%s" = %s' % (k, text) for text, k in keys.items()]
lines.append('')
lines.append('(1,1,1) = {"')
for row in range(H):
    lines.append(''.join(columns[x][row] for x in range(W)))
lines.append('"}')
text = '\n'.join(lines) + '\n'
if '--check' in sys.argv[1:]:
    if not OUT.exists() or OUT.read_text(encoding='utf-8') != text:
        print(OUT.relative_to(ROOT), 'does not match tools/broadside/make_map.py')
        sys.exit(1)
    print(OUT.relative_to(ROOT), 'matches the generator')
    sys.exit(0)
OUT.write_text(text, encoding='utf-8')
print('wrote', OUT.relative_to(ROOT), 'with', len(keys), 'tile kinds')
