#!/usr/bin/env python3
"""Writes maps/1713/broadside.dmm, the Broadside TDM map.

Open sea and two sailing ships, one for each side. Each ship is a hull of
ship floors laid over deep water with a tiller at the stern, four rigged
masts down the middle and five guns along each side, railed and dressed
with existing objects so the king's ship and the pirate read apart. When the round starts
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
MAST = '/obj/structure/vehicleparts/movement/sail/premade'
BALL = '/obj/item/cannon_ball'
METADATA = '/obj/map_metadata/broadside'

RAIL = '/obj/structure/railing'
SHROUDS = '/obj/structure/voyage/ropeladder'
ANCHOR = '/obj/structure/voyage/anchor'
HATCH = '/obj/structure/voyage/grid'
LANTERN = '/obj/item/flashlight/lantern/on/anchored'
TABLE = '/obj/structure/table/wood'
ROPE = '/obj/item/stack/material/rope'
CRATE = '/obj/structure/closet/crate/empty'

# What tells the two ships apart at a glance.
LOOKS = {
    # The Foudroyant, a king's ship: scrubbed planking, a bluff bow, the white
    # ensign, a grating over the main hatch and the captain's table aft.
    'french': {
        'plank': '/obj/covers/repairedfloor/ship/afloat',
        'bow': (2, 2, 1, 1, 0, 0),
        'flag': '/obj/structure/flag/french',
        'jack': '/obj/structure/flag/french',
        'cask': '/obj/item/weapon/reagent_containers/glass/barrel/water',
        'chest': '/obj/structure/closet/crate/chest',
    },
    # The Black Gull, a pirate brigantine: grey weathered planking, a long
    # sharp bow, the black flag, rum, plunder and hammocks slung on deck.
    'pirates': {
        'plank': '/obj/covers/repairedfloor/ship/afloat/weathered',
        'bow': (2, 1, 1, 0, 0),
        'flag': '/obj/structure/flag/pirates',
        'jack': '/obj/structure/flag/black',
        'cask': '/obj/item/weapon/reagent_containers/glass/barrel/rum',
        'chest': '/obj/structure/closet/crate/treasurechest',
    },
}

GUN_ROWS = (2, 5, 8, 11, 13)    # tiles from the tiller, along the keel
MAST_ROWS = (3, 6, 9, 12)
SHROUD_ROWS = (3, 9)            # shrouds abreast of the fore and main masts
BOARDING_GAP = (6, 7)           # no rail here: the crews board across amidships
BROADSIDE = 14                  # tiles of full beam, from the tiller forward
HALF_BEAM = 3

# Dense things, for the checks below: guns must have a clear line of fire and
# the crew needs open deck to join on.
DENSE = ('/obj/structure/cannon', '/obj/structure/closet/', '/obj/structure/table/',
         '/obj/item/weapon/reagent_containers/glass/barrel/', '/obj/structure/hull_tiller/', RAIL)


def half_beams(side):
    """Half the beam at each tile along the keel, as {k: half}; the tiller is k = 0.

    A narrow counter one tile abaft the tiller, the full seven tiles of beam
    along the guns, then the bow, which ends in a bowsprit one plank wide.
    """
    halves = (2,) + (HALF_BEAM,) * BROADSIDE + LOOKS[side]['bow']
    return {k - 1: half for k, half in enumerate(halves)}


def ship(grid, tx, ty, bow, side):
    """Lays one ship with its tiller at (tx, ty). bow is +1 (east) or -1 (west).

    Returns her planks and the tiles of deck with nothing dense on them.
    """
    look = LOOKS[side]
    halves = half_beams(side)
    hull = set()

    def put(k, dy, *things):
        assert (k, dy) in hull, 'off the hull: %s %s %s' % (side, (k, dy), things)
        grid[(tx + bow * k, ty + dy)].extend(things)

    def put_wide(k, dy, thing):
        # A 64x64 sprite covers its tile and the ones east and north of it:
        # stand it on the western of the two keel tiles k and k + 1.
        put(k if bow > 0 else k + 1, dy, thing)

    for k, half in halves.items():
        for dy in range(-half, half + 1):
            hull.add((k, dy))
            grid[(tx + bow * k, ty + dy)] = [look['plank']]

    put(0, 0, '/obj/structure/hull_tiller/broadside/%s' % side)
    for k in MAST_ROWS:
        # Yards square across the keel, the sails bellying toward the bow. The
        # 64x64 sprite hangs north of its tile: half a tile down centres it.
        put(k, 0, '%s{dir = %d; pixel_y = -16}' % (MAST, 4 if bow > 0 else 8))
    for k in GUN_ROWS:
        # North-side guns stand one in from the rail, since a gun fills its
        # own tile and the one north of it; south-side guns on the rail.
        put(k, 2, '/obj/structure/cannon{dir = 1}')
        put(k, -3, '/obj/structure/cannon{dir = 2}')
        put(k, 1, BALL)
        put(k, -1, BALL)

    # The rail round the deck, open at each gun port, at the boarding gap
    # amidships and along the bowsprit.
    for (k, dy) in sorted(hull):
        if halves[k] == 0:
            continue
        for (sk, sdy, d) in ((0, 1, 1), (0, -1, 2),
                              (1, 0, 4 if bow > 0 else 8),
                              (-1, 0, 8 if bow > 0 else 4)):
            if (k + sk, dy + sdy) in hull:
                continue
            if sdy and (k in GUN_ROWS or k in BOARDING_GAP):
                continue
            put(k, dy, RAIL if d == 2 else '%s{dir = %d}' % (RAIL, d))

    # Shrouds from the rail to the mastheads.
    for k in SHROUD_ROWS:
        put_wide(k, 2, SHROUDS + '{dir = 1}')
        put_wide(k, -3, SHROUDS)

    # Aft: the colours at the taffrail, the stern lanterns, the shot and
    # small-arms stores, the captain's chest and the casks.
    put(-1, 0, look['flag'])
    put(-1, 2, LANTERN)
    put(0, 2, '/obj/structure/closet/crate/cannonball')
    put(0, -2, '/obj/structure/closet/crate/cannonball')
    put(-1, 1, '/obj/structure/closet/crate/musketball')
    put(-1, -1, '/obj/structure/closet/crate/blunderbuss_ammo')
    put(0, -3, look['chest'])
    put(1, -3, look['cask'])

    # Forward: the anchors at the catheads and the jack on the bowsprit.
    put(14, 2, ANCHOR)
    put(14, -2, ANCHOR)
    put(max(halves), 0, look['jack'])

    if side == 'french':
        put(-1, -2, LANTERN)
        # The captain's table against the rail, with his compass.
        put(0, 3, TABLE)
        put(1, 3, TABLE, '/obj/item/weapon/compass')
        # A grating over the main hatch, between the masts.
        west, east = sorted((tx + bow * 7, tx + bow * 8))
        for dy, row in ((1, (9, 5)), (0, (8, 4)), (-1, (10, 6))):
            grid[(west, ty + dy)].append('%s{dir = %d}' % (HATCH, row[0]))
            grid[(east, ty + dy)].append('%s{dir = %d}' % (HATCH, row[1]))
        # Water casks on the forecastle, lines coiled down by the masts.
        put(15, 1, look['cask'])
        put(15, -1, look['cask'])
        put(4, 0, ROPE)
        put(10, 0, ROPE)
    else:
        # Rum by the helm, plunder stacked amidships, hammocks slung forward.
        put(1, 3, look['cask'])
        put(0, 3, look['cask'])
        put(7, 0, CRATE)
        put(8, 0, CRATE, ROPE)
        put(10, 0, CRATE)
        put(4, 0, ROPE)
        put(14, 1, '/obj/structure/bed/hammock')
        put(14, -1, '/obj/structure/bed/hammock')
        put(15, 0, look['cask'])

    # Checks: a clear line of fire for every gun (a shot passes rails, and
    # none faces outboard at a gun), masts enough for the hull,
    # and open deck for the crew.
    def dense(k, dy, but=()):
        return [t for t in grid[(tx + bow * k, ty + dy)] if t.startswith(DENSE) and not (but and t.startswith(but))]

    for k in GUN_ROWS:
        for dy in (3, -3):
            assert not dense(k, dy, ('/obj/structure/cannon', RAIL)), 'gun at %d fouled on the %s ship' % (k, side)
    assert len(hull) <= len(MAST_ROWS) * 31, '%d planks are too many for the masts' % len(hull)
    free = sum(1 for (k, dy) in hull if not dense(k, dy))
    assert free >= 60, 'only %d tiles of open deck on the %s ship' % (free, side)
    return len(hull), free


grid = {}
SHIPS = {'french': ship(grid, 20, 55, 1, 'french'), 'pirates': ship(grid, 130, 25, -1, 'pirates')}


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
for name, (planks, free) in SHIPS.items():
    print('%s: %d planks, %d tiles of open deck' % (name, planks, free))
