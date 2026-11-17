"""Hand-placed sprites for tin ore and calamine in icons/obj/mining.dmi.

Tin ore ("ore_tin" and its "_2", "_3", "_4" piles) is cassiterite: blocky,
faceted brown-black crystals with a glassy glint, some still carrying a
knob of the pale quartz they grew on. Calamine ("ore_calamine" and its
piles) is the zinc ore: rounded, grape-like crusts, chalk white on top and
pale blue-green in the hollows. The two used to share one grey lump.

Every pixel is placed by this script from the two fixed palettes below
(Pillow only); no external or generated artwork. It replaces the four tin
states where they stand, appends the four calamine states and leaves every
other state in the sheet untouched.

Run with Pillow to write the sheet. `--check` verifies the committed sheet,
`--preview <png>` writes a 6x review sheet on grass and dirt beside the
neighbouring ores (`--before <dmi>` adds the older sheet's tin row).
Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_brazier_fire import read_dmi, write_dmi  # noqa: E402
from create_clay_lime_fire import grain  # noqa: E402
from create_tatara import GRASS, DIRT, ground  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/mining.dmi'
SIZE = 32
SUFFIXES = ('', '_2', '_3', '_4')

# cassiterite: glint, lit, mid, dark, deep
TIN = [(240, 214, 170), (150, 100, 62), (104, 66, 42), (68, 42, 30), (42, 26, 22)]
TIN_EDGE = (22, 13, 12)
# the quartz it grew on: lit, mid, shade
QUARTZ = [(238, 232, 216), (204, 194, 174), (160, 148, 132)]
# calamine: chalk, pale, mid, shade, deep
CAL = [(240, 248, 240), (192, 222, 206), (146, 194, 180), (102, 154, 148), (70, 112, 116)]
CAL_EDGE = (46, 78, 88)
# the rusty earth calamine weathers out of
RUST = (176, 142, 96)


class Frame:
    def __init__(self):
        self.px = {}

    def put(self, x, y, c):
        if 0 <= x < SIZE and 0 <= y < SIZE:
            self.px[(x, y)] = c

    def stamp(self, lump, edge):
        """Lay a lump over what is drawn, ringed by its dark edge."""
        for (x, y) in lump:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if (x + dx, y + dy) not in lump:
                    self.put(x + dx, y + dy, edge)
        for (x, y), c in lump.items():
            self.put(x, y, c)

    def image(self):
        im = Image.new('RGBA', (SIZE, SIZE))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c + (255,))
        return im


def spread(seed, n, lo, hi):
    """A fixed value in lo..hi, the same on every run."""
    return lo + (hi - lo) * grain(seed, n, seed * 7 + n) / 10.0


# ------------------------------------------------------------------ tin --

def side(p, a, b):
    return (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])


def crystal(cx, cy, rx, ry, seed, quartz=False):
    """A blocky crystal: six flat faces round a peak set toward the light
    (upper left), each face one tone, the two lit ridges picked out."""
    n = 6
    ring = []
    for i in range(n):
        a = 2 * math.pi * (i + spread(seed, i, -0.25, 0.25)) / n + 0.5
        r = spread(seed, i + 9, 0.86, 1.08)
        ring.append((cx + math.cos(a) * rx * r, cy + math.sin(a) * ry * r))
    peak = (cx - rx * 0.22, cy - ry * 0.28)
    faces = []
    for i in range(n):
        a, b = ring[i], ring[(i + 1) % n]
        mx, my = (a[0] + b[0]) / 2 - peak[0], (a[1] + b[1]) / 2 - peak[1]
        d = math.hypot(mx, my) or 1.0
        lit = (-mx * 0.62 - my * 0.78) / d            # +1 faces the light
        tone = 1 if lit > 0.55 else 2 if lit > 0.0 else 3 if lit > -0.6 else 4
        faces.append((a, b, tone, lit, mx / d))
    stone = max(range(n), key=lambda i: faces[i][4]) if quartz else None      # the right-hand face
    out = {}
    for y in range(int(cy - ry * 1.3) - 1, int(cy + ry * 1.3) + 2):
        for x in range(int(cx - rx * 1.3) - 1, int(cx + rx * 1.3) + 2):
            p = (x + 0.0, y + 0.0)
            for i, (a, b, tone, lit, _) in enumerate(faces):
                s1, s2, s3 = side(p, peak, a), side(p, a, b), side(p, b, peak)
                if (s1 >= 0 and s2 >= 0 and s3 >= 0) or (s1 <= 0 and s2 <= 0 and s3 <= 0):
                    if i == stone:
                        out[(x, y)] = QUARTZ[1 if grain(x, y, seed) > 3 else 2]
                    else:
                        out[(x, y)] = TIN[tone]
                    break
    px, py = int(round(peak[0])), int(round(peak[1]))
    if (px, py) in out:
        out[(px, py)] = TIN[0]                          # the glassy glint
        for step in (1, 2):
            if (px - step, py + step) in out and step <= rx / 2:
                out[(px - step, py + step)] = TIN[1]    # the lit ridge
        if rx >= 4 and (px + 1, py - 1) in out:
            out[(px + 1, py - 1)] = TIN[0]
    if stone is not None:
        tops = sorted(k for k, c in out.items() if c in QUARTZ)
        if tops:
            out[min(tops, key=lambda k: k[0] + k[1])] = QUARTZ[0]
    return out


# (cx, cy, rx, ry, quartz), back to front
TIN_PILES = {
    '': [(15.5, 22, 5, 3.6, True)],
    '_2': [(11, 21, 5, 3.6, False), (21, 24, 4.2, 3, True), (13.5, 25.5, 3.2, 2.2, False)],
    '_3': [(13, 17, 4.6, 3.4, False), (20, 19, 4.6, 3.4, True), (8.5, 23, 4.6, 3.4, True),
           (24.5, 24, 4.2, 3, False), (16, 23.5, 5.2, 3.8, False), (11.5, 26.5, 3, 2, False)],
    '_4': [(15, 11.5, 4.6, 3.4, True), (10.5, 15.5, 4.8, 3.4, False), (20.5, 15.5, 4.8, 3.4, False),
           (6.5, 21, 4.4, 3.4, False), (25, 21, 4.4, 3.4, True), (15.5, 19, 5.4, 3.8, False),
           (10.5, 24.5, 4.8, 3.4, True), (20.5, 25, 4.8, 3.4, False), (15.5, 27, 3.2, 2, False)],
}


def tin(suffix):
    f = Frame()
    for i, (cx, cy, rx, ry, quartz) in enumerate(TIN_PILES[suffix]):
        f.stamp(crystal(cx, cy, rx, ry, 211 + i * 5 + len(suffix), quartz), TIN_EDGE)
    return f


# ------------------------------------------------------------- calamine --

def crust(cx, cy, rx, ry, seed, rust=False):
    """A rounded, grape-like lump: a few overlapping knobs, each chalk
    white where the light lands and blue-green toward its foot."""
    knobs = [(cx, cy + ry * 0.15, min(rx, ry) * 0.95)]
    count = 3 if rx < 4 else 4
    for i in range(count):
        a = math.pi * (1.05 + 0.9 * i / max(1, count - 1)) + spread(seed, i, -0.2, 0.2)
        r = min(rx, ry) * spread(seed, i + 5, 0.6, 0.8)
        knobs.append((cx + math.cos(a) * (rx - r * 0.75), cy + math.sin(a) * (ry - r * 0.8), r))
    knobs.append((cx + rx * 0.45, cy + ry * 0.3, min(rx, ry) * 0.7))
    knobs.append((cx - rx * 0.5, cy + ry * 0.35, min(rx, ry) * 0.65))
    out = {}
    for kx, ky, r in knobs:
        for y in range(int(ky - r) - 1, int(ky + r) + 2):
            for x in range(int(kx - r) - 1, int(kx + r) + 2):
                dx, dy = (x - kx) / r, (y - ky) / r
                dd = dx * dx + dy * dy
                if dd > 1.0:
                    continue
                lit = -dx * 0.55 - dy * 0.8 + (1.0 - dd) * 0.35
                tone = 0 if lit > 0.9 else 1 if lit > 0.5 else 2 if lit > 0.05 else 3 if lit > -0.45 else 4
                out[(x, y)] = CAL[tone]
    if rust:
        foot = max(y for _, y in out)
        for (x, y) in list(out):
            if y >= foot - 2 and x >= cx - 1 and grain(x, y, seed) > 1:
                out[(x, y)] = RUST
    return out


CAL_PILES = {
    '': [(15.5, 22, 5, 3.6, True)],
    '_2': [(11, 21, 5, 3.8, False), (21, 24, 4.4, 3.2, True), (14, 26, 3, 2.2, False)],
    '_3': [(13, 17, 4.6, 3.6, False), (20.5, 19, 4.6, 3.6, False), (8.5, 23, 4.6, 3.6, True),
           (24.5, 24, 4.2, 3.2, True), (16, 23.5, 5.2, 4, False), (11.5, 26.5, 3, 2.2, False)],
    '_4': [(15, 11.5, 4.6, 3.6, False), (10.5, 15.5, 4.8, 3.6, False), (20.5, 15.5, 4.8, 3.6, False),
           (6.5, 21, 4.4, 3.6, True), (25, 21, 4.4, 3.6, False), (15.5, 19, 5.4, 4, False),
           (10.5, 24.5, 4.8, 3.6, False), (20.5, 25, 4.8, 3.6, True), (15.5, 27, 3.2, 2.2, False)],
}


def calamine(suffix):
    f = Frame()
    for i, (cx, cy, rx, ry, rust) in enumerate(CAL_PILES[suffix]):
        f.stamp(crust(cx, cy, rx, ry, 307 + i * 3 + len(suffix), rust), CAL_EDGE)
    return f


# --------------------------------------------------------- sheet in/out --

def drawn():
    """{state: image} for the eight states this script owns."""
    out = {}
    for suffix in SUFFIXES:
        out['ore_tin' + suffix] = tin(suffix).image()
        out['ore_calamine' + suffix] = calamine(suffix).image()
    return out


def rebuild(states):
    art = drawn()
    out = [(name, keys, [art.pop(name)] if name in art else images) for name, keys, images in states]
    for suffix in SUFFIXES:                              # calamine goes on the end
        name = 'ore_calamine' + suffix
        if name in art:
            out.append((name, {'dirs': '1', 'frames': '1'}, [art[name]]))
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

def preview(path, states, before=None, scale=6):
    have = {name: images[0] for name, _, images in states}
    have.update(drawn())
    rows = []
    if before:
        old = {name: images[0] for name, _, images in read_dmi(before)}
        tinted = {}
        for suffix in SUFFIXES:                          # calamine was tin art tinted #c9c2a8
            im = old['ore_tin' + suffix].copy()
            for y in range(SIZE):
                for x in range(SIZE):
                    r, g, b, a = im.getpixel((x, y))
                    im.putpixel((x, y), (r * 0xc9 // 255, g * 0xc2 // 255, b * 0xa8 // 255, a))
            tinted[suffix] = im
        rows.append(('before: tin ore', [old['ore_tin' + s] for s in SUFFIXES]))
        rows.append(('before: calamine', [tinted[s] for s in SUFFIXES]))
    rows.append(('tin ore', [have['ore_tin' + s] for s in SUFFIXES]))
    rows.append(('calamine', [have['ore_calamine' + s] for s in SUFFIXES]))
    for other in ('ore_copper', 'ore_iron', 'ore_coal', 'ore_lead', 'ore_silver'):
        rows.append((other, [have[other + s] for s in SUFFIXES]))
    pad, label = 8, 110
    cell = SIZE * scale
    block = label + 4 * cell + pad
    out = Image.new('RGBA', (pad + 2 * block, pad + len(rows) * (cell + pad)), (24, 24, 24, 255))
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
                out.paste(tile, (pad + label + j * (4 * cell + pad) + i * cell, y))
    out.save(path)


def option(name):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else None


if __name__ == '__main__':
    sheet = read_dmi(SHEET)
    if '--check' in sys.argv:
        problems = check(sheet)
        if problems:
            sys.exit('stale sheet: ' + '; '.join(problems))
        print('tin ore and calamine states match')
    elif option('--preview'):
        preview(option('--preview'), sheet, option('--before'))
    else:
        write_dmi(SHEET, rebuild(sheet))
