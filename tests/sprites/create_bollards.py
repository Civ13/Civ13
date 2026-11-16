#!/usr/bin/env python3
"""Draw the street bollards in icons/obj/bollards.dmi.

Four single-direction 32x32 states, each a short post standing in the lower
middle of the tile with most of the tile left empty:

  bollard_wood      squared timber post with grain and a chamfered, weathered top
  bollard_stone     rounded dressed-stone guard stone
  bollard_iron      cast-iron street bollard with a domed cap and a ring band
  bollard_concrete  plain concrete cylinder with a faint yellow reflective band

Every post is lit from the top left, has a one pixel darker outline and a soft
ground shadow falling to the lower right. The drawing is plain pixel work with
Pillow; nothing is random, so a rerun writes the same bytes.

  python3 tests/sprites/create_bollards.py                  write the sheet
  python3 tests/sprites/create_bollards.py --check          verify the committed sheet
  python3 tests/sprites/create_bollards.py --preview <png>  also write a 4x review sheet
"""
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_water_animation import SIZE, write_dmi  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/bollards.dmi'
STATES = ('bollard_wood', 'bollard_stone', 'bollard_iron', 'bollard_concrete')
DIRT = (121, 88, 58)

WOOD = [(58, 38, 24), (92, 60, 36), (112, 71, 43), (131, 86, 52), (152, 104, 66), (174, 126, 84)]
STONE = [(54, 54, 54), (86, 86, 84), (110, 110, 107), (130, 130, 127), (148, 148, 144), (170, 170, 165)]
IRON = [(10, 10, 12), (26, 27, 30), (40, 42, 46), (56, 58, 63), (78, 81, 87), (112, 116, 123)]
CONCRETE = [(74, 73, 72), (104, 102, 100), (119, 117, 115), (133, 131, 129), (146, 146, 142), (164, 164, 160)]
YELLOW = [(110, 92, 30), (150, 126, 40), (176, 150, 52), (198, 172, 66), (214, 190, 84), (230, 208, 110)]


def noise(x, y, seed):
    n = (x * 73856093) ^ (y * 19349663) ^ (seed * 83492791)
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def rows(spec):
    """Expand {(y0, y1): (x0, x1)} into {y: (x0, x1)} with inclusive spans."""
    out = {}
    for (y0, y1), span in spec.items():
        for y in range(y0, y1 + 1):
            out[y] = span
    return out


def round_tone(x, x0, x1):
    """Tone index 1-5 across a rounded post lit from the left."""
    t = (x - x0) / float(max(1, x1 - x0))
    if t < 0.12:
        return 3
    if t < 0.38:
        return 5 if 0.18 < t < 0.32 else 4
    if t < 0.6:
        return 3
    if t < 0.82:
        return 2
    return 1


def shadow(im, cx, cy, rx, ry, strength=92):
    px = im.load()
    for y in range(SIZE):
        for x in range(SIZE):
            d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            if d <= 1.0:
                px[x, y] = (0, 0, 0, int(strength * (1.0 - 0.6 * d)))


def paint(im, shape, tone_at):
    """Fill the body, then darken its rim into a one pixel outline."""
    px = im.load()
    inside = {(x, y) for y, (x0, x1) in shape.items() for x in range(x0, x1 + 1)}
    for x, y in inside:
        ramp, tone = tone_at(x, y, *shape[y])
        rim = any((x + dx, y + dy) not in inside for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if rim:
            # the lit top-left rim stays a shade lighter than the shaded one
            lit = (x - 1, y) not in inside or (x, y - 1) not in inside
            dark = ramp[0]
            if lit and (x + 1, y) in inside and (x, y + 1) in inside:
                dark = tuple((a + b) // 2 for a, b in zip(ramp[0], ramp[1]))
            px[x, y] = dark + (255,)
        else:
            px[x, y] = ramp[max(1, min(5, tone))] + (255,)


def wood():
    im = Image.new('RGBA', (SIZE, SIZE))
    shadow(im, 18.5, 28.6, 8.0, 2.6)
    shape = rows({(13, 13): (13, 19), (14, 29): (12, 20)})
    streaks = {14: (17, 24), 16: (19, 28), 18: (17, 22), 19: (24, 28)}
    knot = (15, 23)

    def tone(x, y, x0, x1):
        if y <= 15:  # end grain of the sawn top
            t = 5 if x < 16 else 4
            if (x, y) in ((16, 14), (15, 15), (17, 15)):
                t = 3  # heart ring
            if (x, y) in ((18, 14), (18, 15)):
                t = 2  # drying crack
            return WOOD, t
        if y == 16:
            return WOOD, 2  # chamfer under the top
        t = 4 if x <= 14 else 3 if x <= 17 else 2
        if x in streaks and streaks[x][0] <= y <= streaks[x][1]:
            t -= 1
        if abs(x - knot[0]) + abs(y - knot[1]) <= 1:
            t = 1 if (x, y) == knot else 2
        if noise(x, y, 3) < 0.10:
            t -= 1
        if y >= 28:
            t -= 1  # damp, dirty foot
        return WOOD, t

    paint(im, shape, tone)
    return im


def stone():
    im = Image.new('RGBA', (SIZE, SIZE))
    shadow(im, 18.5, 28.8, 8.5, 2.6)
    shape = rows({(13, 13): (14, 18), (14, 14): (12, 19), (15, 15): (12, 20), (16, 27): (11, 20),
                  (28, 29): (11, 21)})
    shape[28] = (11, 20)
    shape[29] = (11, 21)
    chips = {(18, 19), (19, 20), (13, 24), (16, 27), (17, 16)}

    def tone(x, y, x0, x1):
        t = round_tone(x, x0, x1)
        if y <= 14:
            t += 1  # crown catches the light
        elif y == 15 and x <= 16:
            t += 1
        if (x, y) in chips:
            t -= 1
        elif noise(x, y, 11) < 0.16:
            t -= 1
        elif noise(x, y, 12) < 0.07:
            t += 1
        if y >= 28:
            t -= 1
        return STONE, t

    paint(im, shape, tone)
    return im


def iron():
    im = Image.new('RGBA', (SIZE, SIZE))
    shadow(im, 18.5, 28.8, 8.0, 2.5)
    shape = rows({(12, 12): (15, 17), (13, 13): (14, 18), (14, 14): (13, 19), (15, 15): (14, 18),
                  (16, 17): (12, 20), (18, 26): (13, 19), (27, 27): (12, 20), (28, 29): (11, 21)})

    def tone(x, y, x0, x1):
        t = round_tone(x, x0, x1) - 1
        if y in (12, 13) and x <= 16:
            t += 1  # glint on the dome
        if y == 16:
            t += 1  # top of the ring band
        if y == 17 or y == 15:
            t -= 1
        if y in (20, 24) and 14 <= x <= 18:
            t -= 1 if x != 15 else 0  # cast flutes
        if y == 27:
            t += 1 if x <= 16 else 0
        return IRON, t

    paint(im, shape, tone)
    px = im.load()
    px[15, 13] = IRON[5] + (255,)
    for y in (19, 21, 22, 23, 25):
        px[15, y] = IRON[4] + (255,)
    return im


def concrete():
    im = Image.new('RGBA', (SIZE, SIZE))
    shadow(im, 18.5, 28.8, 8.0, 2.5)
    shape = rows({(13, 13): (14, 18), (14, 28): (12, 20), (29, 29): (13, 19)})

    def tone(x, y, x0, x1):
        if y <= 15 and not (y == 15 and (x <= 13 or x >= 19)):
            return CONCRETE, 5 if x <= 17 else 4  # flat top face
        t = round_tone(x, x0, x1)
        if y in (19, 20):
            return YELLOW, t  # reflective band
        if noise(x, y, 21) < 0.10:
            t -= 1
        if y >= 28:
            t -= 1
        return CONCRETE, t

    paint(im, shape, tone)
    px = im.load()
    for x in range(14, 19):  # lip under the top face
        px[x, 16] = CONCRETE[2] + (255,)
    # keep the band faint: blend it halfway back into the concrete
    for y in (19, 20):
        for x in range(13, 20):
            c = px[x, y]
            g = CONCRETE[round_tone(x, 12, 20)]
            px[x, y] = tuple((a * 3 + b * 2) // 5 for a, b in zip(c[:3], g)) + (255,)
    return im


def build():
    drawn = (wood(), stone(), iron(), concrete())
    return [(name, {'dirs': '1', 'frames': '1'}, [im]) for name, im in zip(STATES, drawn)]


def check_drawing(states):
    problems = []
    for name, _, (im,) in states:
        solid = im.point(lambda v: 255 if v == 255 else 0).getchannel('A').getbbox()
        width, height = solid[2] - solid[0], solid[3] - solid[1]
        if not (7 <= width <= 11 and 15 <= height <= 18):
            problems.append('%s: body is %dx%d' % (name, width, height))
        if solid[1] < 11 or solid[3] > 30:
            problems.append('%s: body leaves the lower middle of the tile' % name)
        used = sum(1 for a in im.getchannel('A').tobytes() if a)
        if used > SIZE * SIZE // 4:
            problems.append('%s: covers %d pixels' % (name, used))
    return problems


def check_sheet(path, states):
    path = Path(path)
    if not path.exists():
        return ['%s is missing' % path]
    sheet = Image.open(path)
    text = sheet.info.get('Description', '')
    names = [line.split('"')[1] for line in text.splitlines() if line.startswith('state = ')]
    problems = []
    if names != list(STATES):
        problems.append('%s lists %s' % (path.name, names))
    sheet = sheet.convert('RGBA')
    for n, (name, _, (im,)) in enumerate(states):
        if sheet.crop((n * SIZE, 0, (n + 1) * SIZE, SIZE)).tobytes() != im.tobytes():
            problems.append('%s: committed pixels differ from the drawing' % name)
    return problems


def write_preview(path, states, scale=4):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    strip = Image.new('RGBA', (SIZE * len(states), SIZE), DIRT + (255,))
    px = strip.load()
    for y in range(SIZE):
        for x in range(strip.width):
            n = noise(x, y, 40)
            shift = -9 if n < 0.14 else 7 if n > 0.9 else 0
            px[x, y] = tuple(c + shift for c in DIRT) + (255,)
    for n, (_, _, (im,)) in enumerate(states):
        strip.alpha_composite(im, (n * SIZE, 0))
    strip.convert('RGB').resize((strip.width * scale, strip.height * scale), Image.NEAREST).save(path)


def option(name):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else None


def main():
    states = build()
    problems = check_drawing(states)
    if '--check' in sys.argv:
        problems += check_sheet(option('--sheet') or SHEET, states)
        for line in problems:
            print(line)
        print('bollards: %s' % ('FAILED' if problems else 'ok'))
        return 1 if problems else 0
    if problems:
        print('\n'.join(problems))
        return 1
    write_dmi(option('--out') or SHEET, states)
    if option('--preview'):
        write_preview(option('--preview'), states)
    return 0


if __name__ == '__main__':
    sys.exit(main())
