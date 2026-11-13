#!/usr/bin/env python3
"""Draws the Huey's airframe and rotor sprites from the existing UH-1 art.

The airframe is the top-down UH-1 already in the repository
(icons/obj/vehicles/heli_wip.dmi, state "UH1", 352x96, nose west). A
modular vehicle turns inside a square of at most seven tiles, so the
helicopter is fitted to a 3x7 footprint: the cabin is narrowed from 196 to
150 pixels and the tail boom from 156 to 74 (box-filtered across the length
only, alpha kept hard), then the whole is turned nose up and cut into 32x32
tiles. A tile's states are named "huey_<column>_<row>" (the hull seen from
outside) and, for the cabin rows, "huey_<column>_<row>_floor" (the deck seen
from inside), after its place in the DM layout table (huey_layout in
helicopter.dm: column 1 is the west side of a helicopter facing south, row 1
its nose). Each state holds the four directions the helicopter can face.

The main rotor is drawn here with plain Pillow shapes into its own 224x224
sheet (icons/obj/vehicles/huey_rotor.dmi): "rotor" is the stopped two-blade
rotor, "rotor_spin" a faint turning disc.

Usage: python3 scripts/draw_huey.py [--preview out.png]
"""
import math, os, struct, sys, zlib
from PIL import Image, ImageDraw
from PIL.PngImagePlugin import PngInfo

T = 32
COLS, ROWS = 3, 7
ROOFED_ROWS = 4          # rows 1-4 are the cabin; 5-7 the tail cone, boom and fin
CABIN_SRC, CABIN_DST = 196, 150
BOOM_DST = ROWS * T - CABIN_DST   # 74
ROTOR = 224

DECK1 = (78, 76, 60, 255)
DECK2 = (66, 64, 50, 255)
DECK3 = (54, 53, 42, 255)


def read_dmi_state(path, state):
    """The first frame of one state of a DMI, as an RGBA image."""
    data = open(path, 'rb').read()
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
        raise SystemExit(f'{path}: no DMI description')
    w = h = None
    index = 0
    for line in desc.splitlines():
        line = line.strip()
        if line.startswith('width'):
            w = int(line.split('=')[1])
        elif line.startswith('height'):
            h = int(line.split('=')[1])
        elif line.startswith('state'):
            name = line.split('=', 1)[1].strip().strip('"')
            current = name
            dirs = frames = 1
        elif line.startswith('dirs'):
            dirs = int(line.split('=')[1])
        elif line.startswith('frames'):
            frames = int(line.split('=')[1])
            if current == state:
                break
            index += dirs * frames
    sheet = Image.open(path).convert('RGBA')
    per_row = sheet.width // w
    x, y = (index % per_row) * w, (index // per_row) * h
    return sheet.crop((x, y, x + w, y + h))


def squeeze(im, width):
    """Narrow along x only; alpha stays hard so the outline keeps its edge."""
    out = im.resize((width, im.height), Image.BOX)
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255 if a >= 128 else 0)
    return out


def huey_north(src):
    """The whole helicopter, nose up, 96x224."""
    side = Image.new('RGBA', (ROWS * T, src.height), (0, 0, 0, 0))
    cabin = squeeze(src.crop((0, 0, CABIN_SRC, src.height)), CABIN_DST)
    boom = squeeze(src.crop((CABIN_SRC, 0, src.width, src.height)), BOOM_DST)
    side.alpha_composite(cabin, (0, 0))
    side.alpha_composite(boom, (CABIN_DST, 0))
    top = Image.new('RGBA', (side.width, COLS * T), (0, 0, 0, 0))
    top.alpha_composite(side, (0, (COLS * T - side.height) // 2))
    # Nose west -> nose north: a quarter turn clockwise.
    return top.rotate(-90, expand=True)


def erode(alpha, n):
    w, h = alpha.size
    src = alpha.load()
    keep = Image.new('L', (w, h), 0)
    kp = keep.load()
    for y in range(h):
        for x in range(w):
            ok = src[x, y] > 0
            for dy in range(-n, n + 1):
                if not ok:
                    break
                for dx in range(-n, n + 1):
                    xx, yy = x + dx, y + dy
                    if not (0 <= xx < w and 0 <= yy < h) or src[xx, yy] == 0:
                        ok = False
                        break
            kp[x, y] = 255 if ok else 0
    return keep


def huey_deck(north):
    """The cabin with its roof off: plated deck inside the hull rim. The nose
    row keeps its glass."""
    deck = north.copy()
    inner = erode(north.getchannel('A'), 3).load()
    px = deck.load()
    for y in range(T, ROOFED_ROWS * T):
        for x in range(deck.width):
            if inner[x, y]:
                c = DECK1
                if x % 12 == 0 or y % 16 == 0:
                    c = DECK3
                elif x % 12 == 1 or y % 16 == 1:
                    c = DECK2
                px[x, y] = c
    return deck


def four_dirs(north):
    """BYOND direction order: south, north, east, west. The art faces north."""
    return [north.rotate(180), north, north.rotate(-90), north.rotate(90)]


def rotor_still():
    im = Image.new('RGBA', (ROTOR, ROTOR), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = ROTOR / 2
    a = math.radians(30)
    dx, dy = math.cos(a) * (c - 2), math.sin(a) * (c - 2)
    d.line([c - dx, c - dy, c + dx, c + dy], fill=(30, 30, 28, 255), width=5)
    d.line([c - dx, c - dy - 1, c + dx, c + dy - 1], fill=(70, 70, 64, 255), width=1)
    d.ellipse([c - 6, c - 6, c + 6, c + 6], fill=(30, 30, 28, 255))
    d.ellipse([c - 3, c - 3, c + 3, c + 3], fill=(96, 96, 88, 255))
    return im


def rotor_spin(frame, frames=4):
    im = Image.new('RGBA', (ROTOR, ROTOR), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = ROTOR / 2
    r = c - 2
    d.ellipse([c - r, c - r, c + r, c + r], fill=(24, 24, 22, 30))
    d.ellipse([c - r, c - r, c + r, c + r], outline=(24, 24, 22, 70), width=2)
    base = math.radians(frame * 180 / frames)
    for k in (0, 1):
        a = base + k * math.pi
        for spread, alpha in ((0.10, 60), (0.05, 90)):
            pts = [(c, c)]
            for t in (a - spread, a + spread):
                pts.append((c + math.cos(t) * r, c + math.sin(t) * r))
            d.polygon(pts, fill=(24, 24, 22, alpha))
    d.ellipse([c - 6, c - 6, c + 6, c + 6], fill=(30, 30, 28, 255))
    d.ellipse([c - 3, c - 3, c + 3, c + 3], fill=(96, 96, 88, 255))
    return im


def build_hull_states(root):
    src = read_dmi_state(os.path.join(root, 'icons', 'obj', 'vehicles', 'heli_wip.dmi'), 'UH1')
    north = huey_north(src)
    deck = huey_deck(north)
    states = []
    for r in range(1, ROWS + 1):
        for c in range(1, COLS + 1):
            box = ((COLS - c) * T, (r - 1) * T, (COLS - c + 1) * T, r * T)
            states.append((f'huey_{c}_{r}', four_dirs(north.crop(box)), None))
            if r <= ROOFED_ROWS:
                states.append((f'huey_{c}_{r}_floor', four_dirs(deck.crop(box)), None))
    return states, north, deck


def build_rotor_states():
    return [('rotor', [rotor_still()], None), ('rotor_spin', [rotor_spin(i) for i in range(4)], 'anim')]


def write_dmi(states, path, size, cols):
    n = sum(len(f) for _, f, _ in states)
    rows = (n + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * size, rows * size), (0, 0, 0, 0))
    desc = ['# BEGIN DMI', 'version = 4.0', f'\twidth = {size}', f'\theight = {size}']
    i = 0
    for name, frames, kind in states:
        if kind == 'anim':
            desc += [f'state = "{name}"', '\tdirs = 1', f'\tframes = {len(frames)}', '\tdelay = ' + ','.join('1' for _ in frames)]
        else:
            desc += [f'state = "{name}"', f'\tdirs = {len(frames)}', '\tframes = 1']
        for f in frames:
            sheet.paste(f, ((i % cols) * size, (i // cols) * size))
            i += 1
    desc.append('# END DMI')
    info = PngInfo()
    info.add_text('Description', '\n'.join(desc) + '\n', zip=True)
    sheet.save(path, format='PNG', pnginfo=info, optimize=True)


if __name__ == '__main__':
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    hull, north, deck = build_hull_states(root)
    rotor = build_rotor_states()
    if '--preview' in sys.argv:
        out = sys.argv[sys.argv.index('--preview') + 1]
        bg = Image.new('RGBA', (ROTOR * 2 + 48, ROTOR + 32), (96, 120, 72, 255))
        for i, art in enumerate((north, deck)):
            x = 16 + i * (ROTOR + 16) + (ROTOR - art.width) // 2
            bg.alpha_composite(art, (x, 16))
        spun = Image.new('RGBA', bg.size, (0, 0, 0, 0))
        spun.alpha_composite(rotor[1][1][0], (16, 16))
        bg.alpha_composite(spun)
        still = Image.new('RGBA', bg.size, (0, 0, 0, 0))
        still.alpha_composite(rotor[0][1][0], (32 + ROTOR, 16))
        bg.alpha_composite(still)
        bg.resize((bg.width * 3, bg.height * 3), Image.NEAREST).convert('RGB').save(out)
    else:
        vehicles = os.path.join(root, 'icons', 'obj', 'vehicles')
        write_dmi(hull, os.path.join(vehicles, 'huey_airframe.dmi'), T, 16)
        write_dmi(rotor, os.path.join(vehicles, 'huey_rotor.dmi'), ROTOR, 5)
        print(f'wrote {len(hull)} airframe states and {len(rotor)} rotor states')
