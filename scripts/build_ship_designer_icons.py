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

The cannons are drawn here too. In the game a cannon is a 64x64 sprite two
tiles long, and the hooped wooden one is the same sprite under a dark wood
tint: at one tile neither shows which way it points. draw_cannon() and
draw_hooped_cannon() are plan views of a gun on its truck carriage, in the
game sprite's own colours, drawn pointing south and turned for each facing.

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

# Turning a picture that faces south to each facing (degrees anticlockwise).
TURN = {2: 0, 1: 180, 4: 90, 8: 270}

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
IRON_LIGHT = (112, 116, 124, 255)
IRON_DARK = (38, 39, 44, 255)
GUN = (58, 60, 66, 255)  # the cast barrel of cannon.dmi
GUN_LIGHT = (98, 102, 110, 255)
GUN_DARK = (30, 31, 35, 255)
CARRIAGE = (140, 84, 34, 255)  # the truck carriage of cannon.dmi
CARRIAGE_LIGHT = (172, 108, 48, 255)
CARRIAGE_DARK = (98, 56, 22, 255)
LOG = (130, 75, 40, 255)  # WOOD, the hooped barrel's tint
LOG_LIGHT = (168, 108, 62, 255)
LOG_DARK = (88, 48, 24, 255)


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


def draw_crows_nest():
    """The mast from above with her crow's nest: a ring of planking round
    the masthead, over the yard and furled sail."""
    img = draw_mast()
    px = img.load()
    for dy in range(-7, 8):
        for dx in range(-7, 8):
            r2 = dx * dx + dy * dy
            if 30 <= r2 <= 49:
                px[15 + dx, 18 + dy] = SPAR_DARK if r2 >= 42 else SPAR_LIGHT
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


def _gun(body, light, dark, band, band_light, bands):
    """A gun on its truck carriage from above, the muzzle to the south.
    "bands" are the rows of the barrel that carry a ring or a hoop."""
    img = Image.new('RGBA', (TILE, TILE), (0, 0, 0, 0))
    px = img.load()
    for y in range(5, 21):  # the carriage bed: two cheeks and the planks between
        for x in range(9, 23):
            px[x, y] = CARRIAGE_LIGHT if x in (9, 22) else (CARRIAGE_DARK if x in (11, 20) or y in (5, 20) else CARRIAGE)
    for y0 in (7, 15):  # four trucks (wheels) on their axles
        for y in range(y0, y0 + 4):
            for x in (7, 8, 23, 24):
                px[x, y] = IRON_DARK if y in (y0, y0 + 3) else IRON
    for x, y in ((15, 2), (16, 2), (15, 3), (16, 3)):
        px[x, y] = dark  # the cascabel knob behind the breech
    px[15, 2] = body
    for y in range(4, 29):  # the barrel, thick at the breech, flared at the muzzle
        half = 4 if y < 7 else (3 if y < 19 else 2)
        if y >= 27:
            half = 3
        ring = y in bands
        for x in range(16 - half, 16 + half):
            if ring:
                px[x, y] = band_light if x < 16 - half + 2 else band
            else:
                px[x, y] = light if x == 16 - half + 1 else (dark if x in (16 - half, 16 + half - 1) else body)
    for x in range(14, 18):
        px[x, 28] = dark  # the muzzle's lip
    px[15, 28] = px[16, 28] = (12, 10, 8, 255)  # and the bore
    px[17, 6] = (12, 10, 8, 255)  # the touch hole
    for x, y in ((12, 12), (19, 12)):
        px[x, y] = IRON_LIGHT  # the trunnions in their caps
    return img


def draw_cannon():
    """A cast cannon from above: the dark barrel of cannon.dmi with its
    reinforcing rings, on a wooden truck carriage."""
    return _gun(GUN, GUN_LIGHT, GUN_DARK, IRON, IRON_LIGHT, (7, 18, 26))


def draw_hooped_cannon():
    """A hooped cannon from above: a barrel bored from a log, bound with an
    iron hoop every few fingers along it."""
    return _gun(LOG, LOG_LIGHT, LOG_DARK, IRON_DARK, IRON, (5, 9, 13, 17, 21, 25))


# name -> what the built thing looks like. "layers" are drawn bottom first:
# (dmi, state, tint or None). "turns" makes one picture per facing. "crop"
# takes one tile's box out of a bigger sprite. "draw" is a picture made in
# this file instead (facing south, if it turns). "outline" inks round a fitting that stands on a floor
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
    'piece_N': {'draw': draw_crows_nest, 'outline': True},
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
    # The gangway gate in her gunwale, from the built railing sheet.
    'piece_Y': {'layers': [('icons/obj/railings_built.dmi', 'wood_gate', None)], 'turns': True},
    # /obj/structure/multiz/ladder/up/placed (the foot of a stood-up ladder)
    'piece_X': {'layers': [('icons/obj/stairs.dmi', 'ladderup_wood', None)], 'outline': True},
    # /obj/structure/bed/wood (wood tint on the bed overlay)
    'piece_B': {'layers': [('icons/obj/bed_chair.dmi', 'bed', WOOD)], 'outline': True},
    # /obj/structure/cellar_pump/steam
    'piece_Q': {'layers': [('icons/obj/flood_defences.dmi', 'mine_pump', None)], 'outline': True},
    # /obj/structure/cellar_pump/sump
    'piece_U': {'layers': [('icons/obj/flood_defences.dmi', 'sump_pump', None)], 'outline': True},
    # /obj/structure/engine/external/steam
    'piece_E': {'layers': [('icons/obj/engines32.dmi', 'steam_static', None)], 'outline': True},
    # /obj/structure/cannon/hooped (a log barrel bound with iron hoops)
    'piece_H': {'draw': draw_hooped_cannon, 'turns': True, 'outline': True},
    # /obj/structure/cannon (64x64 in the game: drawn here at one tile)
    'piece_Z': {'draw': draw_cannon, 'turns': True, 'outline': True},
    # /obj/structure/torpedo_tube
    'piece_L': {'layers': [('icons/obj/naval_gear.dmi', 'torpedo_tube', None)], 'turns': True, 'outline': True},
    # /obj/structure/window_frame/metal
    'piece_V': {'layers': [('icons/obj/windows.dmi', 'windowmetal_frame', None)]},
    # /obj/structure/simple_door/key_door/anyone/fire_door/steel
    'piece_I': {'layers': [('icons/obj/doors/fire_doors.dmi', 'firedoor_steel', None)], 'turns': True},
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
        if spec.get('turns'):
            out = out.rotate(TURN[facing])
        return outline(out) if spec.get('outline') else out
    out = None
    for path, state, colour in spec['layers']:
        img, turns = frame(path, state, facing)
        if spec.get('turns') and not turns:
            # No facings in the sheet: turn the south picture, as the game
            # would with a transform.
            img = img.rotate(TURN[facing])
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
