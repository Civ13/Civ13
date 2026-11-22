#!/usr/bin/env python3
"""Cuts the train designer's pictures out of the game's own sprite sheets.

The train designer window (code/modules/1713/train_designer.dm) shows a
train sheet's cars the way the built cars look in the game. Like the airship
designer's pictures (scripts/build_air_designer_icons.py), they are PNGs
under icons/train_designer/, sent to the window with browse_rsc. Each is put
together from the first frames of existing states. Nothing is drawn here.

Every picture shows a car heading north: the front of the car is at the top
of the sheet, its left side on the left. The window turns a whole car on its
side for the strip of cars along the top. To keep the number of files the
window is sent small, the pieces of one thing share one picture, side by
side, and the window shows the piece it wants:

  deck_<centre>_<side>  96x32: the left side tile, the rail tile and the
                        right side tile of a deck (deck_side_*, deck_center_*)
  roof_<state>          96x96: the front, middle and back rows of a roof,
                        each left, centre, right (roof_<state>_<f|m|b><l|c|r>)
  edge_<style>          128x32: what stands along a tile's edge, on the
                        left, right, front and back edge (edge_<style>)
  body_<body>           96 wide, 32 a section: a whole locomotive or tender
                        body (loco_<body>_<n><l|c|r>)
  fit_<key>             32x32: a fitting, as its own object looks, with a
                        one-pixel pale outline

A fitting's file is named by its key. The keys are capital letters and the
other names are lower case words, and no two names differ only by case:
Windows serves the browser's cache without case.

Run it after changing the tables in code/modules/1713/train_draught.dm, the
stock cars' layouts or the sprites they use:

    python3 scripts/build_train_designer_icons.py          # write the PNGs
    python3 scripts/build_train_designer_icons.py --check  # exit 1 if stale
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_ship_designer_icons import REPO, TILE, frame, png_bytes, tint  # noqa: E402
from build_vehicle_designer_icons import outline  # noqa: E402

OUT = os.path.join(REPO, 'icons', 'train_designer')
CARS = 'icons/obj/vehicles/train_platforms.dmi'
BEDS = 'icons/obj/bed_chair.dmi'
NORTH, SOUTH, EAST, WEST = 1, 2, 4, 8
STEEL = (0x66, 0x66, 0x66)  # /material/steel icon_colour
BLUE = (0x6B, 0x6F, 0xE3)  # /material/cloth_blue icon_colour

# (centre, side) deck states: train_draught_floors() and the stock cars'
# layouts (train_car_layout()).
DECKS = [
    ('wood', 'wood'), ('boards', 'boards'), ('floor', 'floor'), ('carpet', 'floor'),
    ('carpet', 'carpet'), ('steel', 'steel'), ('straw', 'straw'),
    ('hopper', 'hopper'),  # the hopper wagon
    ('steel', 'boards'),  # the tank car
]
# train_draught_roofs() states; the stock cars use the same ones.
ROOFS = ['coach', 'boxcar', 'stock', 'reefer', 'steel', 'armor']
# train_draught_edges() styles.
EDGES = ['rail', 'wall', 'window', 'door', 'plank', 'freight_door', 'side', 'drop_door',
         'slat', 'slat_door', 'cold', 'cold_door', 'armor', 'armor_door', 'partition']
# Locomotive and tender bodies and how many sections long each is.
BODIES = {'steam': 4, 'mainline': 6, 'tender': 4, 'diesel': 4, 'dieselmain': 6,
          'electric': 4, 'tram': 4, 'armored': 4}
# train_draught_fittings(): key -> layers of (dmi, state, facing, tint).
FITTINGS = {
    # /obj/structure/bed/chair/comfy/blue: a steel chair padded in blue,
    # facing the way the car does
    'S': [(BEDS, 'chair', NORTH, STEEL), (BEDS, 'chair_padding', NORTH, BLUE)],
    # /obj/structure/bed (steel, as built with no material named)
    'B': [(BEDS, 'bed', SOUTH, STEEL)],
    # /obj/structure/bed/chair/comfy/diner_booth
    'D': [(BEDS, 'diner_booth_right', NORTH, None)],
    # /obj/structure/table/modern/table
    'T': [('icons/obj/structures.dmi', 'woodtable', SOUTH, None)],
    # /obj/structure/table/wood
    'W': [('icons/obj/structures.dmi', 'wood_table', SOUTH, None)],
    # /obj/structure/oven/stove
    'O': [('icons/obj/kitchen.dmi', 'stove', SOUTH, None)],
    # /obj/structure/sink
    'K': [('icons/obj/watercloset.dmi', 'sink', SOUTH, None)],
    # /obj/structure/closet/fridge
    'F': [('icons/obj/closet.dmi', 'fridge1', SOUTH, None)],
    # /obj/structure/closet/cabinet
    'C': [('icons/obj/closet.dmi', 'cabinet_closed', SOUTH, None)],
    # /obj/structure/closet/crate/large
    'X': [('icons/obj/storage.dmi', 'largemetal', SOUTH, None)],
    # /obj/structure/closet/crate
    'R': [('icons/obj/storage.dmi', 'crate', SOUTH, None)],
    # /obj/structure/train_brake_wheel
    'H': [(CARS, 'brake_wheel', SOUTH, None)],
    # /obj/structure/closet/ice_house/reefer
    'I': [(CARS, 'ice_bunker', SOUTH, None)],
    # /obj/structure/closet/ice_house/cold_locker
    'L': [(CARS, 'cold_locker', SOUTH, None)],
}


def cut(path, state, facing, colour=None):
    img, _turns = frame(path, state, facing)
    if img.size != (TILE, TILE):
        raise SystemExit('%s "%s" is not one %dx%d tile' % (path, state, TILE, TILE))
    img = img.convert('RGBA')
    return tint(img, colour) if colour else img


def sheet(rows):
    """One picture of the given rows of tiles."""
    out = Image.new('RGBA', (TILE * len(rows[0]), TILE * len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, img in enumerate(row):
            out.alpha_composite(img, (x * TILE, y * TILE))
    return out


def pictures():
    made = {}
    for centre, side in DECKS:
        made['deck_%s_%s' % (centre, side)] = sheet([[
            cut(CARS, 'deck_side_' + side, WEST),
            cut(CARS, 'deck_center_' + centre, NORTH),
            cut(CARS, 'deck_side_' + side, EAST)]])
    for state in ROOFS:
        made['roof_' + state] = sheet([[cut(CARS, 'roof_%s_%s%s' % (state, row, col), NORTH) for col in 'lcr'] for row in 'fmb'])
    for style in EDGES:
        made['edge_' + style] = sheet([[cut(CARS, 'edge_' + style, facing) for facing in (WEST, EAST, NORTH, SOUTH)]])
    for body, length in BODIES.items():
        made['body_' + body] = sheet([[cut(CARS, 'loco_%s_%d%s' % (body, n, col), NORTH) for col in 'lcr'] for n in range(1, length + 1)])
    for key, layers in FITTINGS.items():
        out = None
        for path, state, facing, colour in layers:
            img = cut(path, state, facing, colour)
            out = img if out is None else Image.alpha_composite(out, img)
        made['fit_' + key] = outline(out)
    return made


def main():
    check = '--check' in sys.argv[1:]
    wanted = {'%s.png' % name: png_bytes(img) for name, img in pictures().items()}
    lowered = [name.lower() for name in wanted]
    if len(set(lowered)) != len(lowered):
        raise SystemExit('two pictures differ only by case')
    stale = []
    os.makedirs(OUT, exist_ok=True)
    for fname, data in sorted(wanted.items()):
        path = os.path.join(OUT, fname)
        if not os.path.exists(path) or open(path, 'rb').read() != data:
            stale.append(fname)
            if not check:
                open(path, 'wb').write(data)
    extra = sorted(f for f in os.listdir(OUT) if f.endswith('.png') and f not in wanted)
    if check:
        if stale or extra:
            print('stale: %s; not made by this script: %s' % (stale, extra))
            return 1
        print('icons/train_designer: %d pictures up to date' % len(wanted))
        return 0
    print('icons/train_designer: wrote %d of %d pictures' % (len(stale), len(wanted)))
    if extra:
        print('not made by this script: %s' % extra)
    return 0


if __name__ == '__main__':
    sys.exit(main())
