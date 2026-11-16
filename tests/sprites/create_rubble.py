#!/usr/bin/env python3
"""Draw the collapsed-building rubble in icons/obj/rubble.dmi.

Nine single-direction 32x32 states, three arrangements for each material, left
on the floor after a roof or wall falls:

  rubble_wood1-3   broken planks, splintered beams, a few nails and thatch bits
  rubble_stone1-3  broken grey dressed stone blocks and chips in mortar dust
  rubble_brick1-3  broken red-brown bricks and mortar lumps

Each is a low, flat scatter over roughly the middle two thirds of the tile, so
it reads as debris to walk over and not as a heap. Pieces are lit from the top
left, have a one pixel darker outline, throw a small shadow on the pieces under
them and a soft shadow on the ground. The rest of the tile is transparent. The
three arrangements of a material are laid out differently so a field of rubble
does not tile visibly. The drawing is plain pixel work with Pillow; nothing is
random, so a rerun writes the same bytes.

  python3 tests/sprites/create_rubble.py                  write the sheet
  python3 tests/sprites/create_rubble.py --check          verify the committed sheet
  python3 tests/sprites/create_rubble.py --preview <png>  also write a 4x review sheet
"""
import math
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_water_animation import SIZE, write_dmi  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/rubble.dmi'
MATERIALS = ('wood', 'stone', 'brick')
STATES = tuple('rubble_%s%d' % (m, n) for m in MATERIALS for n in (1, 2, 3))
FLOORS = ((121, 88, 58), (126, 126, 122), (138, 104, 68))  # dirt, stone, planks

# outline, deep shade, shade, body, light, highlight
PLANK = [(72, 48, 28), (122, 86, 50), (150, 110, 66), (176, 134, 84), (198, 158, 106), (220, 184, 134)]
BEAM = [(40, 27, 19), (70, 47, 31), (90, 61, 39), (108, 75, 48), (128, 92, 60), (152, 114, 78)]
STONE = [(58, 58, 58), (92, 92, 90), (114, 114, 111), (134, 134, 130), (154, 154, 149), (178, 178, 172)]
BRICK = [(70, 30, 22), (112, 48, 34), (136, 60, 42), (158, 74, 52), (178, 92, 66), (198, 116, 88)]
MORTAR = [(96, 90, 80), (132, 126, 114), (154, 148, 135), (174, 168, 154), (194, 189, 175), (212, 208, 196)]
THATCH = [(120, 96, 40), (196, 166, 84), (222, 196, 112)]
NAIL = [(38, 38, 42), (150, 152, 158)]
DUST = {'wood': (104, 78, 50), 'stone': (176, 172, 160), 'brick': (170, 150, 132)}


def noise(x, y, seed):
    n = (x * 73856093) ^ (y * 19349663) ^ (seed * 83492791)
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def slab(cx, cy, length, width, angle, seed, jag=(0, 0), cut=0.0):
    """Pixels of a turned rectangle as {(x, y): (u, v)}, u along its length.

    jag breaks the two ends unevenly, cut chips the far lower corner off.
    """
    a = math.radians(angle)
    ca, sa = round(math.cos(a), 4), round(math.sin(a), 4)
    out = {}
    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = x - cx, y - cy
            u, v = dx * ca + dy * sa, -dx * sa + dy * ca
            if abs(v) > width / 2.0:
                continue
            row = int(math.floor(v + 16))
            lo = -length / 2.0 + jag[0] * noise(row, 1, seed)
            hi = length / 2.0 - jag[1] * noise(row, 2, seed)
            if not lo <= u <= hi:
                continue
            if cut and u / (length / 2.0) + v / (width / 2.0) > 2.0 - cut:
                continue
            out[(x, y)] = (u, v)
    return out


def wood_tone(ramp):
    def tone(x, y, u, v, seed):
        row = int(math.floor(v + 16))
        t = 3 + (1 if noise(row, 7, seed) > 0.62 else 0)
        if noise(int(math.floor(u / 3.0)) + 40, row, seed) < 0.3:
            t -= 1  # grain streak along the board
        return ramp, t
    return tone


def stone_tone(x, y, u, v, seed):
    n = noise(x, y, seed)
    return STONE, 3 + (1 if n > 0.82 else -1 if n < 0.2 else 0)


def brick_tone(mortar_end):
    def tone(x, y, u, v, seed):
        if mortar_end and u * mortar_end > abs(mortar_end) * (abs(mortar_end) - 1.3):
            return MORTAR, 3 + (1 if noise(x, y, seed) > 0.6 else 0)
        n = noise(x, y, seed)
        return BRICK, 3 + (1 if n > 0.85 else -1 if n < 0.16 else 0)
    return tone


def mortar_tone(x, y, u, v, seed):
    n = noise(x, y, seed)
    return MORTAR, 3 + (1 if n > 0.7 else -1 if n < 0.15 else 0)


def lay(px, solid, cells, tone_at, seed):
    """Paint one piece over what is there, with its outline and cast shadow."""
    for (x, y) in cells:  # shadow on the pieces underneath, to the lower right
        for sx, sy in ((x + 1, y + 1), (x + 1, y + 2)):
            if (sx, sy) in solid and (sx, sy) not in cells:
                r, g, b, _ = px[sx, sy]
                px[sx, sy] = (r * 7 // 10, g * 7 // 10, b * 7 // 10, 255)
                solid.discard((sx, sy))  # darken once
    def rim(x, y):
        return any((x + dx, y + dy) not in cells for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
    small = len(cells) <= 6
    for (x, y), (u, v) in cells.items():
        ramp, t = tone_at(x, y, u, v, seed)
        if small:
            # chips are too small for an outline: a lit and a shaded side
            lit = (x - 1, y) not in cells and (x, y - 1) not in cells
            px[x, y] = ramp[4 if lit else 1 if (x + 1, y) not in cells and (x, y + 1) not in cells else 2] + (255,)
        elif rim(x, y):
            lit = ((x - 1, y) not in cells or (x, y - 1) not in cells) and (x + 1, y) in cells and (x, y + 1) in cells
            px[x, y] = (tuple((a + b) // 2 for a, b in zip(ramp[0], ramp[1])) if lit else ramp[0]) + (255,)
        else:
            if rim(x - 1, y) or rim(x, y - 1):
                t += 1
            elif rim(x + 1, y) or rim(x, y + 1):
                t -= 1
            px[x, y] = ramp[max(1, min(5, t))] + (255,)
    solid.update(cells)


def line(x0, y0, x1, y1):
    n = max(abs(x1 - x0), abs(y1 - y0))
    return [(x0 + (x1 - x0) * i // max(1, n), y0 + (y1 - y0) * i // max(1, n)) for i in range(n + 1)]


# piece lists, bottom of the pile first
# wood:  ('plank'|'beam', cx, cy, length, width, angle, (jag, jag))
#        ('straw', x0, y0, x1, y1)   ('nail', x, y)
WOOD = {
    1: [('plank', 10.5, 13.0, 11, 4, 62, (2, 3)),
        ('beam', 15.5, 19.5, 22, 5, 14, (3, 2)),
        ('plank', 18.5, 12.5, 18, 4, -28, (0, 4)),
        ('plank', 21.5, 24.5, 9, 4, -14, (2, 2)),
        ('plank', 8.0, 11.5, 4, 1, 40, (0, 0)), ('plank', 25.0, 16.0, 3, 1, -60, (0, 0)),
        ('plank', 9.0, 25.5, 4, 1, 8, (0, 0)),
        ('straw', 5, 20, 7, 22), ('straw', 19, 8, 22, 9), ('straw', 25, 25, 27, 23),
        ('nail', 13, 18), ('nail', 20, 11), ('nail', 14, 26)],
    2: [('beam', 9.5, 16.0, 13, 5, 84, (2, 2)),
        ('plank', 16.0, 10.0, 20, 4, -9, (3, 0)),
        ('plank', 17.5, 14.5, 21, 4, 5, (0, 4)),
        ('plank', 15.0, 19.0, 19, 4, -4, (3, 3)),
        ('plank', 17.5, 23.5, 16, 4, 11, (2, 4)),
        ('plank', 6.0, 8.0, 3, 1, -30, (0, 0)), ('plank', 26.0, 19.0, 3, 1, 70, (0, 0)),
        ('straw', 22, 6, 25, 7), ('straw', 5, 25, 8, 26), ('straw', 24, 26, 26, 24),
        ('nail', 22, 14), ('nail', 12, 23), ('nail', 26, 11)],
    3: [('plank', 9.5, 21.5, 8, 4, -68, (2, 2)),
        ('plank', 22.5, 9.5, 8, 4, 80, (2, 3)),
        ('beam', 16.0, 16.0, 25, 6, -41, (4, 3)),
        ('plank', 9.5, 10.0, 9, 4, 14, (3, 0)),
        ('plank', 22.5, 22.5, 10, 4, 24, (0, 3)),
        ('plank', 15.0, 25.0, 4, 1, -20, (0, 0)), ('plank', 17.0, 6.5, 3, 1, 30, (0, 0)),
        ('straw', 4, 15, 7, 16), ('straw', 5, 17, 8, 17), ('straw', 25, 15, 27, 17),
        ('straw', 14, 21, 16, 22),
        ('nail', 18, 14), ('nail', 26, 25), ('nail', 12, 14)],
}
# stone: (cx, cy, length, width, angle, corner cut)
STONES = {
    1: [(12.0, 21.5, 8, 6, 35, 0.0), (21.0, 17.5, 9, 6, -20, 0.5), (11.5, 12.5, 10, 7, 10, 0.6),
        (22.0, 9.5, 5, 4, 30, 0.0), (20.5, 24.5, 5, 4, -5, 0.4),
        (6.0, 17.5, 2, 2, 0, 0), (17.0, 8.0, 2, 1, 0, 0), (26.0, 22.0, 2, 2, 0, 0),
        (16.0, 25.5, 1, 2, 0, 0), (17.5, 20.5, 2, 2, 45, 0), (26.0, 13.0, 1, 1, 0, 0)],
    2: [(9.5, 16.0, 7, 7, 20, 0.5), (14.5, 22.5, 9, 5, -25, 0.0), (22.5, 18.0, 9, 6, 15, 0.6),
        (16.5, 9.5, 11, 6, -5, 0.4), (16.0, 16.0, 4, 4, 45, 0.0),
        (7.0, 9.0, 2, 2, 0, 0), (25.0, 10.0, 2, 1, 0, 0), (23.0, 25.0, 2, 2, 0, 0),
        (7.0, 23.0, 2, 1, 0, 0), (27.0, 23.0, 1, 1, 0, 0), (10.0, 26.0, 1, 1, 0, 0)],
    3: [(10.0, 22.0, 6, 5, 10, 0.0), (22.5, 10.5, 7, 5, 50, 0.5), (9.0, 10.0, 8, 6, -15, 0.5),
        (22.0, 21.5, 9, 6, -10, 0.6), (15.5, 15.5, 11, 7, 30, 0.4),
        (16.0, 6.5, 2, 2, 0, 0), (5.0, 16.0, 2, 2, 0, 0), (15.0, 24.5, 2, 2, 30, 0),
        (26.5, 16.0, 2, 1, 0, 0), (27.0, 26.0, 1, 1, 0, 0), (6.0, 25.5, 1, 1, 0, 0)],
}
# brick: ('brick', cx, cy, length, angle, mortar end -1/0/1, broken end) or ('lump', cx, cy, w, h)
BRICKS = {
    1: [('brick', 10.0, 10.5, 8, 15, 1, 0), ('brick', 20.5, 9.0, 8, -25, 0, 2), ('lump', 15.5, 12.5, 4, 3),
        ('brick', 8.5, 18.0, 5, 80, 0, 2), ('brick', 15.0, 18.0, 8, -8, -1, 0), ('brick', 23.5, 16.5, 8, 60, 0, 0),
        ('brick', 11.5, 24.0, 8, -30, 0, 2), ('brick', 20.5, 23.5, 7, 12, 1, 2), ('lump', 26.0, 23.5, 3, 3),
        ('lump', 5.5, 13.0, 2, 2), ('lump', 16.5, 26.5, 2, 2), ('lump', 26.5, 10.0, 2, 1)],
    2: [('lump', 12.0, 21.0, 4, 3), ('brick', 21.5, 22.5, 8, 35, 0, 2), ('brick', 9.0, 24.5, 6, -15, 0, 2),
        ('brick', 9.5, 12.0, 8, -20, 1, 0), ('lump', 13.6, 10.2, 2, 4), ('brick', 17.2, 9.2, 8, -20, 1, 0),
        ('lump', 21.3, 7.5, 2, 4), ('brick', 24.0, 7.0, 5, -20, 0, 2),
        ('brick', 13.5, 16.0, 8, -20, 1, 0), ('lump', 17.6, 14.4, 2, 4), ('brick', 21.4, 13.3, 8, -20, 0, 2),
        ('brick', 24.5, 18.5, 5, 85, 0, 2), ('lump', 6.0, 18.5, 3, 2), ('lump', 16.5, 25.5, 2, 2),
        ('lump', 26.5, 25.0, 2, 2)],
    3: [('lump', 16.0, 15.5, 6, 5), ('brick', 9.0, 9.5, 8, 50, 0, 2), ('brick', 22.0, 11.5, 8, 5, -1, 0),
        ('brick', 16.5, 8.0, 5, -40, 0, 2), ('brick', 8.5, 19.5, 8, -5, 0, 0), ('brick', 23.5, 18.5, 6, -65, 1, 2),
        ('brick', 14.0, 24.5, 8, 28, 0, 2), ('brick', 22.5, 25.0, 5, -15, 0, 2), ('lump', 12.5, 14.0, 3, 2),
        ('lump', 19.5, 20.5, 3, 3), ('lump', 5.5, 14.5, 2, 2), ('lump', 26.5, 22.5, 2, 2), ('lump', 6.5, 25.5, 2, 1)],
}


def pieces(material, variant):
    """[(cells, tone function, seed)] plus loose single pixels drawn on top."""
    out, extra = [], []
    base = (MATERIALS.index(material) * 3 + variant) * 100
    if material == 'wood':
        for n, item in enumerate(WOOD[variant]):
            if item[0] == 'straw':
                pts = line(*item[1:])
                for i, p in enumerate(pts):
                    extra.append((p, THATCH[1 if i else 2]))
                extra.append(((pts[-1][0], pts[-1][1] + 1), THATCH[0]))
            elif item[0] == 'nail':
                extra.append(((item[1], item[2]), NAIL[1]))
                extra.append(((item[1] + 1, item[2] + 1), NAIL[0]))
            else:
                kind, cx, cy, length, width, angle, jag = item
                out.append((slab(cx, cy, length, width, angle, base + n, jag),
                            wood_tone(BEAM if kind == 'beam' else PLANK), base + n))
    elif material == 'stone':
        for n, (cx, cy, length, width, angle, cut) in enumerate(STONES[variant]):
            out.append((slab(cx, cy, length, width, angle, base + n, cut=cut), stone_tone, base + n))
    else:
        for n, item in enumerate(BRICKS[variant]):
            if item[0] == 'lump':
                _, cx, cy, w, h = item
                cells = slab(cx, cy, w, h, 0, base + n, cut=0.7 if w * h > 6 else 0)
                out.append((cells, mortar_tone, base + n))
            else:
                _, cx, cy, length, angle, mortar, broken = item
                jag = (0, broken * 0.6) if mortar <= 0 else (broken * 0.6, 0)
                out.append((slab(cx, cy, length, 4, angle, base + n, jag),
                            brick_tone(mortar * length / 2.0), base + n))
    return out, extra


def rubble(material, variant):
    im = Image.new('RGBA', (SIZE, SIZE))
    px = im.load()
    parts, extra = pieces(material, variant)
    body = set()
    for cells, _, _ in parts:
        body.update(cells)
    seed = MATERIALS.index(material) * 3 + variant
    # dust and grit trodden into the floor between the pieces
    dust = DUST[material]
    for y in range(4, 28):
        for x in range(4, 28):
            near = sum(1 for dy in range(-2, 3) for dx in range(-2, 3) if (x + dx, y + dy) in body)
            if near and noise(x, y, 500 + seed) < 0.06 + 0.035 * near:
                shade = -14 if noise(x, y, 600 + seed) < 0.35 else 0
                px[x, y] = tuple(c + shade for c in dust) + (150,)
    # soft ground shadow to the lower right: a dark core and a faint fringe
    core = {(x + 1, y + 1) for x, y in body}
    fringe = {(x + dx, y + dy) for x, y in core for dx, dy in ((1, 0), (0, 1), (1, 1), (-1, 0), (0, -1))}
    for cells, alpha in ((fringe, 40), (core, 84)):
        for x, y in cells:
            if 0 <= x < SIZE and 0 <= y < SIZE:
                px[x, y] = (0, 0, 0, alpha)
    solid = set()
    for cells, tone_at, piece_seed in parts:
        lay(px, solid, cells, tone_at, piece_seed)
    for (x, y), colour in extra:
        px[x, y] = colour + (255,)
    return im


def build():
    return [('rubble_%s%d' % (m, n), {'dirs': '1', 'frames': '1'}, [rubble(m, n)])
            for m in MATERIALS for n in (1, 2, 3)]


def opaque(im):
    return {(i % SIZE, i // SIZE) for i, a in enumerate(im.getchannel('A').tobytes()) if a == 255}


def check_drawing(states):
    problems = []
    masks = {}
    for name, _, (im,) in states:
        solid = masks[name] = opaque(im)
        xs, ys = [x for x, _ in solid], [y for _, y in solid]
        width, height = max(xs) - min(xs) + 1, max(ys) - min(ys) + 1
        if not (19 <= width <= 25 and 19 <= height <= 25):
            problems.append('%s: pile is %dx%d, wanted 60-75%% of the tile' % (name, width, height))
        box = im.getchannel('A').getbbox()
        if box[0] < 2 or box[1] < 2 or box[2] > SIZE - 2 or box[3] > SIZE - 2:
            problems.append('%s: reaches the tile edge' % name)
        if not SIZE * SIZE * 0.15 <= len(solid) <= SIZE * SIZE * 0.5:
            problems.append('%s: %d solid pixels' % (name, len(solid)))
    for material in MATERIALS:
        for a, b in ((1, 2), (1, 3), (2, 3)):
            one, two = masks['rubble_%s%d' % (material, a)], masks['rubble_%s%d' % (material, b)]
            if len(one ^ two) < 0.4 * len(one | two):
                problems.append('rubble_%s%d and %d are laid out too alike' % (material, a, b))
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
    """Every state over three floor tones at 4x, with the same rows at 1x underneath."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    block = Image.new('RGBA', (SIZE * len(states), SIZE * len(FLOORS)))
    px = block.load()
    for row, floor in enumerate(FLOORS):
        for y in range(row * SIZE, (row + 1) * SIZE):
            for x in range(block.width):
                v = noise(x, y, 40 + row)
                shift = -9 if v < 0.14 else 7 if v > 0.9 else 0
                px[x, y] = tuple(c + shift for c in floor) + (255,)
        for n, (_, _, (im,)) in enumerate(states):
            block.alpha_composite(im, (n * SIZE, row * SIZE))
    block = block.convert('RGB')
    sheet = Image.new('RGB', (block.width * scale, block.height * scale + block.height), (32, 32, 32))
    sheet.paste(block.resize((block.width * scale, block.height * scale), Image.NEAREST), (0, 0))
    sheet.paste(block, (0, block.height * scale))
    sheet.save(path)


def option(name):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else None


def main():
    states = build()
    problems = check_drawing(states)
    if '--check' in sys.argv:
        problems += check_sheet(option('--sheet') or SHEET, states)
        for line in problems:
            print(line)
        print('rubble: %s' % ('FAILED' if problems else 'ok'))
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
