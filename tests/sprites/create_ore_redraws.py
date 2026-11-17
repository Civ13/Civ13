"""Hand-placed sprites for four ores in icons/obj/mining.dmi that used to be
hard to tell from their neighbours.

Charcoal ("ore_charcoal") was a black blob like mineral coal; it is now
charred wood: short split sticks, checked across the grain into blocks,
with an ashy lit edge and pale end grain. Cinnabar ("ore_mercury") was a
dark red close to iron ore; it is now the bright vermilion of the real
mineral, in rough granular lumps flecked with pale gangue. Lead ore
("ore_lead") was frosty blue-white crumbs; it is now galena, intergrown
lead-grey cubes with bright metallic tops. Water ice ("ore_ice", new) was
the sand pile with a tint; it is now angular pale blue shards with white
frost and specks of grit. Each has the usual "_2", "_3" and "_4" piles.

Every pixel is placed by this script from the fixed palettes below (Pillow
only); no external or generated artwork. It replaces the charcoal, cinnabar
and lead states where they stand, appends the ice states and leaves every
other state in the sheet untouched.

Run with Pillow to write the sheet. `--check` verifies the committed sheet,
`--preview <png>` writes a 6x review sheet on grass and dirt beside the
ores each one was confused with (`--before <dmi>` adds the older sheet's
rows). Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_brazier_fire import read_dmi, write_dmi  # noqa: E402
from create_clay_lime_fire import grain  # noqa: E402
from create_tatara import GRASS, DIRT, ground  # noqa: E402
from create_tin_calamine import Frame, spread, side  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/mining.dmi'
SIZE = 32
SUFFIXES = ('', '_2', '_3', '_4')

# charred wood: ash, lit, mid, dark, deep
CHAR = [(134, 128, 122), (88, 82, 78), (56, 51, 49), (36, 32, 31), (22, 19, 19)]
CHAR_EDGE = (10, 9, 9)
# cinnabar: glint, lit, mid, dark, deep
CINN = [(255, 176, 140), (236, 78, 50), (200, 44, 36), (146, 26, 30), (98, 18, 26)]
CINN_EDGE = (58, 10, 18)
GANGUE = [(232, 224, 212), (188, 178, 168)]
# galena: glint, top, front, side, deep
GAL = [(250, 252, 255), (204, 210, 224), (104, 112, 130), (66, 72, 90), (44, 48, 62)]
GAL_EDGE = (22, 24, 34)
# water ice: frost, lit, mid, shade, deep
ICE = [(250, 253, 255), (210, 234, 250), (164, 204, 236), (116, 164, 208), (82, 124, 174)]
ICE_EDGE = (50, 82, 126)
GRIT = (112, 104, 98)


# ------------------------------------------------------------- charcoal --

def stick(x0, y0, x1, y1, half, seed):
    """A charred length of split wood from (x0, y0) to (x1, y1): lit along
    its upper edge, checked across the grain, pale end grain at the far end."""
    out = {}
    length = math.hypot(x1 - x0, y1 - y0)
    ux, uy = (x1 - x0) / length, (y1 - y0) / length
    lo, hi = int(min(x0, x1) - half) - 2, int(max(x0, x1) + half) + 2
    for y in range(int(min(y0, y1) - half) - 2, int(max(y0, y1) + half) + 3):
        for x in range(lo, hi + 1):
            along = (x - x0) * ux + (y - y0) * uy
            across = -(x - x0) * uy + (y - y0) * ux
            if along < -0.5 or along > length + 0.5 or abs(across) > half:
                continue
            up = across * (1 if ux >= 0 else -1)          # negative is the upper edge
            tone = 1 if up < -half * 0.45 else 2 if up < half * 0.2 else 3 if up < half * 0.7 else 4
            step = int(along + spread(seed, 3, 0, 4))
            if step % 5 == 0 and up > -half * 0.3 and grain(step, seed, 5) > 0:
                tone = 4                                  # a check across the grain
            elif tone == 1 and grain(x, y, seed) < 2:
                tone = 0                                  # ash on the lit edge
            elif tone == 2 and grain(x, y, seed + 1) < 2:
                tone = 3                                  # grain
            if along > length - 1.2:
                tone = 1 if abs(across) > half * 0.4 else 3   # end grain and its heart
            out[(x, y)] = CHAR[tone]
    return out


# (x0, y0, x1, y1, half width), back to front
CHAR_PILES = {
    '': [(10, 24, 21, 20, 2.2)],
    '_2': [(8, 18, 19, 23, 2.2), (13, 26, 25, 21, 2.2), (6, 25, 13, 27, 1.6)],
    '_3': [(9, 14, 20, 19, 2.2), (14, 22, 26, 17, 2.2), (4, 21, 15, 25, 2.2),
           (15, 27, 27, 24, 2.2), (6, 28, 14, 27, 1.6)],
    '_4': [(10, 7, 20, 12, 2.2), (15, 15, 26, 10, 2.2), (4, 13, 15, 18, 2.2), (16, 20, 28, 17, 2.4),
           (3, 22, 15, 20, 2.4), (9, 23, 20, 27, 2.4), (18, 27, 28, 23, 2.2), (3, 27, 12, 28, 2.0)],
}


def charcoal(suffix):
    f = Frame()
    for i, s in enumerate(CHAR_PILES[suffix]):
        f.stamp(stick(*s, seed=401 + i * 7 + len(suffix)), CHAR_EDGE)
    return f


# ------------------------------------------------------------- cinnabar --

def granular(cx, cy, rx, ry, seed):
    """A rough lump of massive cinnabar: an uneven outline, grainy vermilion
    shading from the upper left and a fleck or two of pale gangue."""
    out = {}
    for y in range(int(cy - ry) - 2, int(cy + ry) + 3):
        for x in range(int(cx - rx) - 2, int(cx + rx) + 3):
            dx, dy = (x - cx) / rx, (y - cy) / ry
            a = math.atan2(dy, dx)
            edge = 1.0 + 0.16 * math.sin(a * 3 + seed) + 0.1 * math.sin(a * 5 + seed * 2.3)
            d = math.hypot(dx, dy) / edge
            if d > 1.0:
                continue
            lit = -dx * 0.55 - dy * 0.8 + (grain(x, y, seed) - 5) * 0.07
            tone = 1 if lit > 0.35 else 2 if lit > -0.1 else 3 if lit > -0.55 else 4
            g = grain(x, y, seed + 9)
            if g == 0 and lit > 0.0:
                tone = 0                                  # a crystal face catches the light
            out[(x, y)] = CINN[tone]
            if grain(x // 2, y // 2, seed + 4) == 0 and d < 0.8 and lit < 0.3:
                out[(x, y)] = GANGUE[0 if lit > -0.2 else 1]
    return out


LUMPS = {
    '': [(15.5, 22, 5, 3.6)],
    '_2': [(11, 21, 5, 3.6), (21, 24, 4.2, 3), (13.5, 26, 3, 2)],
    '_3': [(13, 17, 4.6, 3.4), (20, 19, 4.6, 3.4), (8.5, 23, 4.6, 3.4),
           (24.5, 24, 4.2, 3), (16, 23.5, 5.2, 3.8), (11.5, 27, 3, 2)],
    '_4': [(15, 11.5, 4.6, 3.4), (10.5, 15.5, 4.8, 3.4), (20.5, 15.5, 4.8, 3.4),
           (6.5, 21, 4.4, 3.4), (25, 21, 4.4, 3.4), (15.5, 19, 5.4, 3.8),
           (10.5, 24.5, 4.8, 3.4), (20.5, 25, 4.8, 3.4), (15.5, 27.5, 3.2, 2)],
}


def cinnabar(suffix):
    f = Frame()
    for i, (cx, cy, rx, ry) in enumerate(LUMPS[suffix]):
        f.stamp(granular(cx, cy, rx, ry, 503 + i * 3 + len(suffix)), CINN_EDGE)
    return f


# --------------------------------------------------------------- galena --

def cube(x, y, w, h, d):
    """A cleaved cube whose front face has its top left corner at (x, y):
    w wide and h tall, with a bright top and a dark right side d deep."""
    out = {}
    for j in range(h):
        for i in range(w):
            out[(x + i, y + j)] = GAL[2]
        out[(x, y + j)] = GAL[1] if j < h - 1 else GAL[2]        # the near arris
    for k in range(1, d + 1):
        for i in range(w):
            out[(x + i + k, y - k)] = GAL[1]                      # top
        for j in range(h):
            out[(x + w - 1 + k, y + j - k + 1)] = GAL[3 if j < h - 1 else 4]   # right side
    for i in range(w):
        out[(x + i, y + h - 1)] = GAL[3]                          # the foot in shade
    out[(x + 1 + d, y - d)] = GAL[0]                              # glint on the far top edge
    if w > 3:
        out[(x + 2 + d, y - d)] = GAL[0]
        out[(x + 2, y + 1)] = GAL[1]                              # a cleavage step on the face
        out[(x + 3, y + 1)] = GAL[1]
    return out


# (x, y, w, h, d), back to front
GAL_PILES = {
    '': [(11, 21, 5, 4, 2), (17, 23, 3, 3, 1)],
    '_2': [(7, 19, 5, 4, 2), (12, 22, 3, 3, 1), (18, 23, 5, 4, 2), (24, 25, 3, 2, 1)],
    '_3': [(11, 15, 5, 4, 2), (17, 17, 5, 4, 2), (5, 21, 5, 4, 2), (22, 22, 4, 4, 2),
           (11, 22, 6, 5, 2), (18, 25, 3, 3, 1), (8, 26, 3, 2, 1)],
    '_4': [(12, 9, 5, 4, 2), (7, 13, 5, 5, 2), (16, 13, 6, 5, 2), (3, 19, 5, 4, 2), (22, 19, 5, 5, 2),
           (10, 18, 6, 5, 2), (16, 21, 5, 5, 2), (6, 24, 5, 4, 2), (12, 25, 4, 3, 1), (21, 26, 4, 3, 1)],
}


def galena(suffix):
    f = Frame()
    for c in GAL_PILES[suffix]:
        f.stamp(cube(*c), GAL_EDGE)
    return f


# ------------------------------------------------------------------ ice --

def shard(cx, cy, rx, ry, seed):
    """An angular broken piece of ice: five flat faces round an off-centre
    peak, frosted white where they meet, with a speck of grit frozen in."""
    n = 5
    ring = []
    for i in range(n):
        a = 2 * math.pi * (i + spread(seed, i, -0.3, 0.3)) / n + 0.2 + seed
        r = spread(seed, i + 9, 0.8, 1.12)
        ring.append((cx + math.cos(a) * rx * r, cy + math.sin(a) * ry * r))
    peak = (cx + rx * 0.15, cy - ry * 0.2)
    out, owner = {}, {}
    for y in range(int(cy - ry * 1.3) - 1, int(cy + ry * 1.3) + 2):
        for x in range(int(cx - rx * 1.3) - 1, int(cx + rx * 1.3) + 2):
            p = (x + 0.0, y + 0.0)
            for i in range(n):
                a, b = ring[i], ring[(i + 1) % n]
                s1, s2, s3 = side(p, peak, a), side(p, a, b), side(p, b, peak)
                if (s1 >= 0 and s2 >= 0 and s3 >= 0) or (s1 <= 0 and s2 <= 0 and s3 <= 0):
                    mx, my = (a[0] + b[0]) / 2 - peak[0], (a[1] + b[1]) / 2 - peak[1]
                    lit = (-mx * 0.62 - my * 0.78) / (math.hypot(mx, my) or 1.0)
                    out[(x, y)] = ICE[1 if lit > 0.45 else 2 if lit > -0.1 else 3 if lit > -0.65 else 4]
                    owner[(x, y)] = i
                    break
    for (x, y), i in owner.items():                       # frost where two lit faces meet
        if owner.get((x + 1, y), i) != i and out[(x, y)] in ICE[1:3]:
            out[(x, y)] = ICE[0]
    for (x, y) in list(out):
        if grain(x, y, seed + 2) == 0 and grain(x // 2, y, seed) < 4 and out[(x, y)] != ICE[0]:
            out[(x, y)] = GRIT
    return out


def ice(suffix):
    f = Frame()
    for i, (cx, cy, rx, ry) in enumerate(LUMPS[suffix]):
        f.stamp(shard(cx, cy, rx, ry, 601 + i * 4 + len(suffix)), ICE_EDGE)
    return f


# --------------------------------------------------------- sheet in/out --

ORES = (('ore_charcoal', charcoal), ('ore_mercury', cinnabar), ('ore_lead', galena), ('ore_ice', ice))
ADDED = 'ore_ice'


def drawn():
    """{state: image} for the sixteen states this script owns."""
    return {name + suffix: draw(suffix).image() for name, draw in ORES for suffix in SUFFIXES}


def rebuild(states):
    art = drawn()
    out = [(name, keys, [art.pop(name)] if name in art else images) for name, keys, images in states]
    for suffix in SUFFIXES:                              # the ice goes on the end
        if ADDED + suffix in art:
            out.append((ADDED + suffix, {'dirs': '1', 'frames': '1'}, [art[ADDED + suffix]]))
    return out


def check(states):
    problems = []
    have = {name: images for name, _, images in states}
    for name, image in drawn().items():
        if name not in have:
            problems.append('%s is missing' % name)
        elif len(have[name]) != 1 or have[name][0].tobytes() != image.tobytes():
            problems.append('%s differs from the drawn ore' % name)
    return problems


# -------------------------------------------------------------- review --

def tinted(im, colour):
    im = im.copy()
    for y in range(SIZE):
        for x in range(SIZE):
            r, g, b, a = im.getpixel((x, y))
            im.putpixel((x, y), (r * colour[0] // 255, g * colour[1] // 255, b * colour[2] // 255, a))
    return im


def preview(path, states, before=None, scale=6):
    have = {name: images[0] for name, _, images in states}
    have.update(drawn())
    old = {name: images[0] for name, _, images in read_dmi(before)} if before else None
    rows = []
    for label, state, beside in (('charcoal', 'ore_charcoal', 'ore_coal'), ('cinnabar', 'ore_mercury', 'ore_iron'),
                                 ('lead ore', 'ore_lead', 'ore_silver'), ('water ice', 'ore_ice', 'ore_glass')):
        if old:
            was = [old[state + s] if state != ADDED else tinted(old['ore_glass' + s], (0xd8, 0xec, 0xff))
                   for s in SUFFIXES]
            rows.append(('before: ' + label, was))
        rows.append((label, [have[state + s] for s in SUFFIXES]))
        rows.append(('(%s)' % beside, [have[beside + s] for s in SUFFIXES]))
    pad, label_w = 8, 120
    cell = SIZE * scale
    out = Image.new('RGBA', (pad + 2 * (label_w + 4 * cell + pad), pad + len(rows) * (cell + pad)), (24, 24, 24, 255))
    pen = ImageDraw.Draw(out)
    for j, tones in enumerate((GRASS, DIRT)):
        back = ground(tones, scale)
        for r, (name, images) in enumerate(rows):
            y = pad + r * (cell + pad)
            if j == 0:
                pen.text((pad, y + cell // 2 - 5), name, fill=(230, 230, 230, 255))
            for i, im in enumerate(images):
                tile = back.copy()
                tile.alpha_composite(im.resize((cell, cell), Image.NEAREST))
                out.paste(tile, (pad + label_w + j * (4 * cell + pad) + i * cell, y))
    out.save(path)


def option(name):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else None


if __name__ == '__main__':
    sheet = read_dmi(SHEET)
    if '--check' in sys.argv:
        problems = check(sheet)
        if problems:
            sys.exit('stale sheet: ' + '; '.join(problems))
        print('charcoal, cinnabar, lead ore and ice states match')
    elif option('--preview'):
        preview(option('--preview'), sheet, option('--before'))
    else:
        write_dmi(SHEET, rebuild(sheet))
