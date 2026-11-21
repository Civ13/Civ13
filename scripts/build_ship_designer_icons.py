#!/usr/bin/env python3
"""Cuts the ship designer's tile pictures out of the game's own sprite sheets.

The ship designer window (code/modules/naval/ship_designer.dm) shows every
floor and fitting of a ship's draught as the sprite the built thing has in
the game. A browser window cannot read a DMI, so this script copies the
needed states into plain PNGs under icons/ship_designer/, which the window
is sent with browse_rsc. Nothing is drawn here: each picture is the first
frame of an existing state, tinted or layered the way the game does it.

Run it after changing ship_draught_pieces or ship_draught_floors
(code/modules/naval/ship_draught.dm) or the sprites they use:

    python3 scripts/build_ship_designer_icons.py          # write the PNGs
    python3 scripts/build_ship_designer_icons.py --check  # exit 1 if stale

A turning piece (rowing bench, door) gets one PNG per facing, named with the
BYOND dir number (1 north, 2 south, 4 east, 8 west).
"""
import io
import os
import struct
import sys
import zlib

from PIL import Image, ImageChops

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, 'icons', 'ship_designer')
TILE = 32
# The order a DMI stores the facings of a state in.
DMI_DIRS = [2, 1, 4, 8]
WOOD = (0x82, 0x4b, 0x28)  # material/wood icon_colour (materials.dm)

# name -> what the built thing looks like. "layers" are drawn bottom first:
# (dmi, state, tint or None). "turns" makes one picture per facing. "crop"
# takes one tile's box out of a bigger sprite.
# Names are the draught's keys, spelt out so no two differ only by case.
SPRITES = {
    # /obj/covers/repairedfloor
    'floor_w': {'layers': [('icons/turf/floors.dmi', 'wood_ship_repaired', None)]},
    # /obj/covers/steelplating
    'floor_s': {'layers': [('icons/turf/floors.dmi', 'floor', None)]},
    # /obj/structure/hull_tiller/steering_oar (no sprite of its own: the tiller's)
    'piece_O': {'layers': [('icons/obj/vehicles/vehicleparts_boats.dmi', 'ship_wheel', None)]},
    # /obj/structure/hull_tiller
    'piece_T': {'layers': [('icons/obj/vehicles/vehicleparts_boats.dmi', 'ship_wheel', None)]},
    # /obj/structure/vehicleparts/movement/sail
    # The bare mast is a 64x64 sprite: its yard overhangs the tiles beside it.
    # The window shows the tile around the mast itself, yard cut at the edges.
    'piece_M': {'layers': [('icons/obj/vehicles/vehicleparts64x64.dmi', 'sail0', None)], 'crop': (16, 18, 48, 50)},
    # /obj/structure/bed/chair/wood/rowing_bench
    'piece_R': {'layers': [('icons/obj/bed_chair.dmi', 'bleacher', None)], 'turns': True},
    # /obj/structure/hull_anchor/stone
    'piece_K': {'layers': [('icons/obj/hull_gear.dmi', 'killick', None)]},
    # /obj/structure/hull_anchor
    'piece_A': {'layers': [('icons/obj/vehicles/vehicleparts.dmi', 'anchor', None)]},
    # /obj/structure/cellar_pump/lever
    'piece_P': {'layers': [('icons/obj/flood_defences.dmi', 'lever_pump', None)]},
    # /obj/covers/wood_wall/adjustable
    'piece_W': {'layers': [('icons/turf/walls.dmi', 'woodwall0', None)]},
    # /obj/structure/simple_door/key_door/anyone/wood (wood tint on the door)
    'piece_D': {'layers': [('icons/obj/doors/material_doors_leonister.dmi', 'wood', WOOD)], 'turns': True},
    # /obj/structure/window_frame
    'piece_G': {'layers': [('icons/obj/windows.dmi', 'windownew_frame', None)]},
    # /obj/structure/closet/crate/empty
    'piece_C': {'layers': [('icons/obj/storage.dmi', 'wood_crate', None)]},
    # /obj/structure/bed/wood (wood tint on the bed overlay)
    'piece_B': {'layers': [('icons/obj/bed_chair.dmi', 'bed', WOOD)]},
}

_sheets = {}


def read_dmi(path):
    """(sheet image, tile width, tile height, {state: (first index, dirs, frames)})."""
    if path in _sheets:
        return _sheets[path]
    data = open(os.path.join(REPO, path), 'rb').read()
    desc = None
    i = 8
    while i < len(data):
        length = struct.unpack('>I', data[i:i + 4])[0]
        ctype = data[i + 4:i + 8]
        body = data[i + 8:i + 8 + length]
        if ctype == b'zTXt':
            key, rest = body.split(b'\0', 1)
            if key == b'Description':
                desc = zlib.decompress(rest[1:]).decode()
        i += 12 + length
    if desc is None:
        raise SystemExit('%s: no DMI description' % path)
    w = h = TILE
    states = {}
    index = 0
    name = None
    dirs = frames = 1

    def close():
        nonlocal index
        if name is not None:
            states.setdefault(name, (index, dirs, frames))
            index += dirs * frames

    for line in desc.splitlines():
        line = line.strip()
        if line.startswith('width'):
            w = int(line.split('=')[1])
        elif line.startswith('height'):
            h = int(line.split('=')[1])
        elif line.startswith('state'):
            close()
            name = line.split('=', 1)[1].strip().strip('"')
            dirs = frames = 1
        elif line.startswith('dirs'):
            dirs = int(line.split('=')[1])
        elif line.startswith('frames'):
            frames = int(line.split('=')[1])
    close()
    sheet = Image.open(os.path.join(REPO, path)).convert('RGBA')
    _sheets[path] = (sheet, w, h, states)
    return _sheets[path]


def frame(path, state, facing=2):
    """The first frame of a state for one facing, and whether the state turns."""
    sheet, w, h, states = read_dmi(path)
    if state not in states:
        raise SystemExit('%s: no state "%s"' % (path, state))
    index, dirs, _frames = states[state]
    # Frames are stored facing by facing within each animation frame.
    if dirs > 1:
        index += DMI_DIRS.index(facing)
    per_row = sheet.width // w
    x, y = (index % per_row) * w, (index // per_row) * h
    return sheet.crop((x, y, x + w, y + h)), dirs > 1


def tint(img, rgb):
    """BYOND's colour multiply."""
    r, g, b, a = img.split()
    solid = Image.new('RGB', img.size, rgb)
    out = ImageChops.multiply(Image.merge('RGB', (r, g, b)), solid)
    out.putalpha(a)
    return out


def build(spec, facing=2):
    out = None
    for path, state, colour in spec['layers']:
        img, turns = frame(path, state, facing)
        if spec.get('turns') and not turns:
            # No facings in the sheet: turn the south picture, as the game
            # would with a transform.
            img = img.rotate({2: 0, 1: 180, 4: 90, 8: 270}[facing])
        if colour:
            img = tint(img, colour)
        out = img if out is None else Image.alpha_composite(out, img)
    if 'crop' in spec:
        out = out.crop(spec['crop'])
    if out.size != (TILE, TILE):
        raise SystemExit('a picture must be one %dx%d tile: give a bigger sprite a "crop"' % (TILE, TILE))
    return out


def png_bytes(img):
    buf = io.BytesIO()
    img.save(buf, 'PNG', optimize=True)
    return buf.getvalue()


def main():
    check = '--check' in sys.argv[1:]
    wanted = {}
    for name, spec in SPRITES.items():
        if spec.get('turns'):
            for facing in (1, 2, 4, 8):
                wanted['%s_%d.png' % (name, facing)] = png_bytes(build(spec, facing))
        else:
            wanted['%s.png' % name] = png_bytes(build(spec))
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
        print('icons/ship_designer: %d pictures up to date' % len(wanted))
        return 0
    print('icons/ship_designer: wrote %d of %d pictures' % (len(stale), len(wanted)))
    if extra:
        print('not made by this script: %s' % extra)
    return 0


if __name__ == '__main__':
    sys.exit(main())
