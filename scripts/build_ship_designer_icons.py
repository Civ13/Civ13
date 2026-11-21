#!/usr/bin/env python3
"""Cuts the ship designer's tile pictures out of the game's own sprite sheets.

The ship designer window (code/modules/naval/ship_designer.dm) shows every
floor and fitting of a ship's draught as the sprite the built thing has in
the game. A browser window cannot read a DMI, so this script copies the
needed states into plain PNGs under icons/ship_designer/, which the window
is sent with browse_rsc. Most pictures are the first frame of an existing
state, tinted or layered the way the game does it. A fitting that stands on
a floor also gets a one-pixel ink outline, so it reads on planks and on steel
plate alike at any zoom.

Two fittings are drawn for the sheet instead, pixel by pixel in this file,
because their game sprites say nothing at one tile seen from above: the ship
mast (in the game a thin yard spilling over three tiles) and the steering
oar (which borrows the tiller's wheel). They are plan views in the game's
own wood colours: see draw_mast() and draw_steering_oar().

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

INK = (26, 16, 8, 255)  # the outline round a fitting

# Hand-placed colours for the pictures drawn here.
SPAR = (138, 90, 43, 255)
SPAR_LIGHT = (176, 122, 66, 255)
SPAR_DARK = (92, 56, 24, 255)
MAST = (168, 115, 58, 255)
MAST_RIM = (120, 78, 36, 255)
MAST_LIGHT = (206, 150, 88, 255)
MAST_HEART = (104, 66, 30, 255)
CANVAS = (232, 220, 192, 255)
CANVAS_SHADE = (196, 180, 140, 255)
CANVAS_TIE = (150, 134, 100, 255)
IRON = (70, 72, 78, 255)


def draw_mast():
    """A mast from above: the round spar, its yard across the ship and the
    sail furled along the yard under its gaskets."""
    img = Image.new('RGBA', (TILE, TILE), (0, 0, 0, 0))
    px = img.load()
    for x in range(2, 30):  # the yard, lit from above
        px[x, 17] = SPAR_LIGHT
        px[x, 18] = SPAR
        px[x, 19] = SPAR_DARK
    for x in range(3, 29):  # the furled sail lashed along it
        tie = x % 4 == 0
        px[x, 14] = CANVAS_TIE if tie else CANVAS
        px[x, 15] = CANVAS_TIE if tie else CANVAS
        px[x, 16] = CANVAS_TIE if tie else CANVAS_SHADE
        if x % 4 == 2:
            px[x, 13] = CANVAS  # the canvas bulges between gaskets
    px[2, 15] = CANVAS_SHADE
    px[29, 15] = CANVAS_SHADE
    # The mast itself: a disc nine pixels across, rim, body and a highlight.
    disc = [
        '...rrr...',
        '.rrbbbrr.',
        '.rbllbbr.',
        'rblllbbbr',
        'rbllhhbbr',
        'rbbbhhbbr',
        '.rbbbbbr.',
        '.rrbbbrr.',
        '...rrr...',
    ]
    shade = {'r': MAST_RIM, 'b': MAST, 'l': MAST_LIGHT, 'h': MAST_HEART}
    for dy, line in enumerate(disc):
        for dx, c in enumerate(line):
            if c != '.':
                px[11 + dx, 14 + dy] = shade[c]
    return img


def draw_steering_oar():
    """A steering oar from above: the loom inboard at the top with its grip,
    an iron crutch it turns in, and the blade trailing astern."""
    img = Image.new('RGBA', (TILE, TILE), (0, 0, 0, 0))
    px = img.load()
    for i in range(17):  # the loom, from (13,3) down to (18,19)
        x = 13 + round(i * 5 / 16)
        px[x, 3 + i] = SPAR_LIGHT
        px[x + 1, 3 + i] = SPAR
    for x, y in ((11, 2), (12, 2), (13, 2), (14, 2), (15, 2), (11, 3), (12, 3)):
        px[x, y] = SPAR_DARK  # the grip
    for x, y in ((13, 10), (14, 10), (17, 10), (18, 10), (13, 11), (18, 11), (13, 12), (14, 12), (17, 12), (18, 12)):
        px[x, y] = IRON  # the crutch
    blade = ((20, 17, 20), (21, 17, 21), (22, 17, 22), (23, 17, 22), (24, 17, 22), (25, 17, 22), (26, 18, 22), (27, 18, 22), (28, 19, 21), (29, 19, 20))
    for y, x0, x1 in blade:
        for x in range(x0, x1 + 1):
            px[x, y] = SPAR_LIGHT if x == x0 else (SPAR_DARK if x == x1 else SPAR)
    return img


# name -> what the built thing looks like. "layers" are drawn bottom first:
# (dmi, state, tint or None). "turns" makes one picture per facing. "crop"
# takes one tile's box out of a bigger sprite. "draw" is a picture made in
# this file instead. "outline" inks round a fitting that stands on a floor
# (not one that fills its tile: walls, doors and windows).
# Names are the draught's keys, spelt out so no two differ only by case.
SPRITES = {
    # /obj/covers/repairedfloor
    'floor_w': {'layers': [('icons/turf/floors.dmi', 'wood_ship_repaired', None)]},
    # /obj/covers/steelplating
    'floor_s': {'layers': [('icons/turf/floors.dmi', 'floor', None)]},
    # /obj/structure/hull_tiller/steering_oar (no sprite of its own in the game)
    'piece_O': {'draw': draw_steering_oar, 'outline': True},
    # /obj/structure/hull_tiller
    'piece_T': {'layers': [('icons/obj/vehicles/vehicleparts_boats.dmi', 'ship_wheel', None)], 'outline': True},
    # /obj/structure/vehicleparts/movement/sail
    # The bare mast is a 64x64 sprite of a thin yard: drawn here from above.
    'piece_M': {'draw': draw_mast, 'outline': True},
    # /obj/structure/bed/chair/wood/rowing_bench
    'piece_R': {'layers': [('icons/obj/bed_chair.dmi', 'bleacher', None)], 'turns': True, 'outline': True},
    # /obj/structure/hull_anchor/stone
    'piece_K': {'layers': [('icons/obj/hull_gear.dmi', 'killick', None)], 'outline': True},
    # /obj/structure/hull_anchor
    'piece_A': {'layers': [('icons/obj/vehicles/vehicleparts.dmi', 'anchor', None)], 'outline': True},
    # /obj/structure/cellar_pump/lever
    'piece_P': {'layers': [('icons/obj/flood_defences.dmi', 'lever_pump', None)], 'outline': True},
    # /obj/covers/wood_wall/adjustable
    'piece_W': {'layers': [('icons/turf/walls.dmi', 'woodwall0', None)]},
    # /obj/structure/simple_door/key_door/anyone/wood (wood tint on the door)
    'piece_D': {'layers': [('icons/obj/doors/material_doors_leonister.dmi', 'wood', WOOD)], 'turns': True},
    # /obj/structure/window_frame
    'piece_G': {'layers': [('icons/obj/windows.dmi', 'windownew_frame', None)]},
    # /obj/structure/closet/crate/empty
    'piece_C': {'layers': [('icons/obj/storage.dmi', 'wood_crate', None)], 'outline': True},
    # /obj/structure/bed/wood (wood tint on the bed overlay)
    'piece_B': {'layers': [('icons/obj/bed_chair.dmi', 'bed', WOOD)], 'outline': True},
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


def outline(img):
    """Inks every clear pixel that touches a solid one along an edge."""
    out = img.copy()
    src, dst = img.load(), out.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if src[x, y][3] >= 40:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] >= 128:
                    dst[x, y] = INK
                    break
    return out


def build(spec, facing=2):
    if 'draw' in spec:
        out = spec['draw']()
        return outline(out) if spec.get('outline') else out
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
    return outline(out) if spec.get('outline') else out


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
