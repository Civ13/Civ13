"""The fire in a lit masonry brazier (stone, sandstone, obsidian, marble).

Each lit state ("s_brazier1" and its siblings in icons/obj/structures.dmi) is
the unlit bowl from the same sheet with a bed of glowing coals and a flame
drawn over it. Every pixel is placed by this script from the fixed palettes
below (Pillow only); no external or generated artwork.

The flame is one tall tongue with two short ones beside it. Bulges travel up
the tongues and the tips lean, all driven by whole numbers of turns per loop,
so frame FRAMES runs straight back into frame 0. A few sparks climb off the
tip. The inside of the rim is warmed towards orange and flickers with the fire.

Run with Pillow to rebuild the lit states in place; every other state in the
sheet is left untouched. `--check` verifies the committed sheet, `--gif <path>`
writes an enlarged review animation, `--preview <png>` a still sheet of every
frame. Released under Civ13 AGPL-3.0.
"""
import math
import struct
import sys
import zlib
from pathlib import Path
from PIL import Image, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons' / 'obj' / 'structures.dmi'

SIZE = 32
FRAMES = 16
DELAY = 1              # deciseconds per frame
TURN = 2 * math.pi

# lit state -> the unlit bowl it is drawn over
BRAZIERS = {
    's_brazier1': 's_brazier0',
    'sandstone_brazier1': 'sandstone_brazier0',
    'obsidian_brazier1': 'obsidian_brazier0',
    'marble_brazier1': 'marble_brazier0',
}

# flame, hottest first: core, yellow, amber, orange, red, dark red rim
FLAME = [(255, 244, 196), (255, 214, 92), (255, 164, 40), (240, 104, 22), (204, 52, 14), (132, 26, 12)]
# heat at which each flame colour starts
LEVELS = [0.88, 0.66, 0.42, 0.22, 0.08, 0.0]
# coals, dimmest first
COALS = [(58, 20, 12), (112, 30, 12), (176, 54, 14), (236, 112, 24), (255, 184, 64)]
GLOW = (255, 138, 44)  # the colour the rim is warmed towards

# The open mouth of the bowl: row -> (first, last) column of the coal bed.
BED = {14: (12, 19), 15: (10, 21), 16: (11, 20), 17: (12, 18)}
BASE = 17.0            # the row the flames stand on (their roots sit in the coals)

# Tongues: (centre column, height in pixels, half width at the root,
#           lean in pixels at the tip, turns per loop, phase)
TONGUES = [
    (16.0, 13.5, 4.6, 1.7, 1, 0.00),
    (12.6, 7.0, 2.6, 1.1, 2, 0.35),
    (19.4, 7.6, 2.7, 1.2, 2, 0.80),
    (15.2, 9.5, 3.0, 1.4, 3, 0.55),
]

# Sparks: (first frame, start column, start row, drift per frame)
SPARKS = [(1, 17.0, 5.0, 0.45), (6, 14.0, 6.0, -0.5), (11, 18.5, 7.0, 0.25)]
SPARK_LIFE = 5
SPARK_COLOURS = [FLAME[1], FLAME[2], FLAME[3], FLAME[4], FLAME[5]]


def tongue_heat(x, y, frame, tongue):
    """0..1 heat of one tongue at a pixel centre, or -1 outside it."""
    cx, height, width, lean, turns, phase = tongue
    p = TURN * (frame / FRAMES * turns + phase)
    # the whole tongue stretches and shrinks a little
    height *= 1.0 + 0.11 * math.sin(p) + 0.06 * math.sin(2 * p + 1.3)
    t = (BASE - (y + 0.5)) / height          # 0 at the root, 1 at the tip
    if t < -0.08 or t >= 1.0:
        return -1.0
    t = max(t, 0.0)
    # the tip leans, and a ripple runs up the tongue
    centre = cx + lean * t ** 1.4 * math.sin(p - t * 2.6) + 0.5 * t * math.sin(2 * p - t * 6.0)
    # a teardrop: wide low down, drawn to a point, with a bulge climbing it
    half = width * (1.0 - t) ** 0.72 * (0.62 + 0.38 * math.sin(math.pi * min(1.0, t * 2.4 + 0.42)))
    half *= 1.0 + 0.20 * math.sin(t * 8.0 - 2 * p)
    if half <= 0.35:
        return -1.0
    d = abs(x + 0.5 - centre) / half
    if d >= 1.0:
        return -1.0
    return (1.0 - d * d) * (1.0 - 0.80 * t ** 1.15)


def flame_colour(x, y, frame):
    heat = max(tongue_heat(x, y, frame, tongue) for tongue in TONGUES)
    if heat < 0:
        return None
    for colour, level in zip(FLAME, LEVELS):
        if heat >= level:
            return colour
    return FLAME[-1]


def coal_colour(x, y, frame):
    """Coals glow in patches that brighten and dim, hottest under the flame."""
    seed = (x * 7 + y * 13) % 11
    pulse = math.sin(TURN * (frame / FRAMES * (1 + seed % 2) + seed / 11.0))
    middle = 1.0 - abs(x + 0.5 - 16.0) / 7.0
    heat = 0.30 + 0.45 * middle + 0.25 * pulse + (0.12 if (x + y) % 2 else -0.08)
    return COALS[max(0, min(len(COALS) - 1, int(heat * len(COALS))))]


def warm(pixel, amount):
    return tuple(int(round(c + (g - c) * amount)) for c, g in zip(pixel[:3], GLOW)) + (pixel[3],)


def rim_glow(x, y, frame):
    """How strongly a bowl pixel is lit by the fire (0 = not at all)."""
    if not 9 <= y <= 19:
        return 0.0
    reach = math.hypot((x + 0.5 - 16.0) / 9.0, (y + 0.5 - 15.5) / 5.0)
    if reach >= 1.0:
        return 0.0
    flicker = 0.85 + 0.15 * math.sin(TURN * (frame / FRAMES * 2 + 0.2))
    return 0.50 * (1.0 - reach) ** 0.8 * flicker


def lit_frame(base, frame):
    out = base.copy()
    px, src = out.load(), base.load()
    for y in range(SIZE):
        for x in range(SIZE):
            if src[x, y][3]:
                amount = rim_glow(x, y, frame)
                if amount > 0.04:
                    px[x, y] = warm(src[x, y], amount)
    for y, (first, last) in BED.items():
        for x in range(first, last + 1):
            px[x, y] = coal_colour(x, y, frame) + (255,)
    for y in range(SIZE):
        for x in range(SIZE):
            # the flames stand inside the bowl: below its lip they stay on the coals
            if y in BED and not BED[y][0] <= x <= BED[y][1]:
                continue
            if y > max(BED):
                continue
            colour = flame_colour(x, y, frame)
            if colour:
                px[x, y] = colour + (255,)
    for start, sx, sy, drift in SPARKS:
        age = (frame - start) % FRAMES
        if age >= SPARK_LIFE:
            continue
        x = int(round(sx + drift * age + 0.6 * math.sin(age * 1.7 + start)))
        y = int(round(sy - 1.4 * age))
        if 0 <= x < SIZE and 0 <= y < SIZE and flame_colour(x, y, frame) is None:
            px[x, y] = SPARK_COLOURS[age] + (255,)
    return out


# -------------------------------------------------------------------- sheet

def read_dmi(path):
    """[(name, {key: text}, [image, ...] in sheet order)] for a 32px sheet."""
    text = None
    with open(path, 'rb') as fh:
        fh.read(8)
        while True:
            head = fh.read(8)
            if len(head) < 8:
                break
            length, kind = struct.unpack('>I4s', head)
            data = fh.read(length)
            fh.read(4)
            if kind == b'zTXt' and data.startswith(b'Description\0'):
                text = zlib.decompress(data[data.index(0) + 2:]).decode()
    sheet = Image.open(path).convert('RGBA')
    cols = sheet.width // SIZE
    states, at = [], 0
    for line in text.splitlines():
        line = line.strip()
        if line.startswith('state'):
            states.append((line.split('=', 1)[1].strip().strip('"'), {}, []))
        elif states and '=' in line:
            key, value = (part.strip() for part in line.split('=', 1))
            states[-1][1][key] = value
    for _, keys, images in states:
        for _ in range(int(keys['dirs']) * int(keys['frames'])):
            x, y = (at % cols) * SIZE, (at // cols) * SIZE
            images.append(sheet.crop((x, y, x + SIZE, y + SIZE)))
            at += 1
    return states


def write_dmi(path, states):
    images = [im for _, _, ims in states for im in ims]
    cols = math.ceil(math.sqrt(len(images)))
    sheet = Image.new('RGBA', (cols * SIZE, ((len(images) + cols - 1) // cols) * SIZE))
    for i, im in enumerate(images):
        sheet.paste(im, ((i % cols) * SIZE, (i // cols) * SIZE))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = %d\n\theight = %d\n' % (SIZE, SIZE)
    for name, keys, _ in states:
        text += 'state = "%s"\n' % name
        for key, value in keys.items():
            text += '\t%s = %s\n' % (key, value)
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta, optimize=True)


def loop_keys():
    return {'dirs': '1', 'frames': str(FRAMES), 'delay': ','.join([str(DELAY)] * FRAMES)}


def rebuild(states):
    bowls = {name: images[0] for name, _, images in states if name in BRAZIERS.values()}
    out = []
    for name, keys, images in states:
        if name in BRAZIERS:
            base = bowls[BRAZIERS[name]]
            out.append((name, loop_keys(), [lit_frame(base, f) for f in range(FRAMES)]))
        else:
            out.append((name, keys, images))
    return out


def check(states):
    """The committed lit states are exactly what this script draws."""
    problems = []
    by = {name: (keys, images) for name, keys, images in states}
    for name, keys, images in rebuild(states):
        if name not in BRAZIERS:
            continue
        if name not in by:
            problems.append('%s is missing' % name)
        elif by[name][0] != keys:
            problems.append('%s does not use the %d-frame loop' % (name, FRAMES))
        elif [im.tobytes() for im in by[name][1]] != [im.tobytes() for im in images]:
            problems.append('%s differs from the drawn fire' % name)
    return problems


GROUNDS = [(86, 122, 66), (226, 230, 236), (28, 30, 40)]   # grass, snow, night


def write_gif(path, states, scale=8):
    by = {name: images for name, _, images in states}
    names = list(BRAZIERS)
    out = []
    for f in range(FRAMES):
        im = Image.new('RGBA', (SIZE * len(names), SIZE * len(GROUNDS)))
        for g, ground in enumerate(GROUNDS):
            im.paste(ground + (255,), (0, g * SIZE, im.width, (g + 1) * SIZE))
            for n, name in enumerate(names):
                im.alpha_composite(by[name][f], (n * SIZE, g * SIZE))
        out.append(im.convert('RGB').resize((im.width * scale, im.height * scale), Image.NEAREST))
    out[0].save(path, save_all=True, append_images=out[1:], duration=DELAY * 100, loop=0)


def write_preview(path, states, scale=6):
    """Every frame of every lit brazier, one row each, on grass."""
    by = {name: images for name, _, images in states}
    im = Image.new('RGBA', (SIZE * FRAMES, SIZE * len(BRAZIERS)), GROUNDS[0] + (255,))
    for n, name in enumerate(BRAZIERS):
        for f in range(FRAMES):
            im.alpha_composite(by[name][f], (f * SIZE, n * SIZE))
    im.convert('RGB').resize((im.width * scale, im.height * scale), Image.NEAREST).save(path)


def option(name):
    args = sys.argv[1:]
    return args[args.index(name) + 1] if name in args[:-1] else None


def main():
    if '--check' in sys.argv:
        problems = check(read_dmi(option('--sheet') or SHEET))
        for line in problems:
            print(line)
        print('brazier fire: %s' % ('FAILED' if problems else 'ok'))
        return 1 if problems else 0
    states = rebuild(read_dmi(SHEET))
    write_dmi(option('--out') or SHEET, states)
    if option('--gif'):
        write_gif(option('--gif'), states)
    if option('--preview'):
        write_preview(option('--preview'), states)
    return 0


if __name__ == '__main__':
    sys.exit(main())
