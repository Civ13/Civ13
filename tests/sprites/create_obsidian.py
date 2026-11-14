"""Hand-placed 32px obsidian art: three ground outcrops, the raw nodule, a
struck flake, a polyhedral blade core, prismatic blades, arrowheads, a
spearhead, the hafted spear, knife and end-scraper, and the obsidian-tipped
arrow as an item and as a four-direction projectile. Every pixel is placed by
this script from a fixed palette (Pillow only); no external or generated
artwork.
The glass is black with blue-grey sheen, sharp specular glints, conchoidal
ripples and smoky thin edges. Wood, cord and the brown outline are the ones
used in icons/obj/stone_age_arms.dmi, the basalt greys are the ones in
icons/obj/flora/rocks.dmi, and the arrow layouts follow "arrow_flint" in
icons/obj/weapons.dmi and icons/obj/projectiles.dmi. Lit from the upper left.

Run with Pillow to reproduce icons/obj/obsidian.dmi. `--preview <png>` also
writes a review sheet (8x, with a 1x and 2x strip underneath, and the flint
equivalents alongside for comparison).
Released under Civ13 AGPL-3.0.
"""
import math
import re
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]

OUT = (62, 49, 34)
# obsidian: glint, sheen, lit face, body, shaded face, deepest black
OB = [(226, 234, 244), (134, 150, 172), (78, 90, 110), (46, 53, 68), (27, 30, 40), (14, 14, 20)]
# outline for the glass, darker than any face so the black body still reads
OBO = (6, 6, 10)
# smoky translucent thin edge, light to dark
SM = [(150, 150, 152), (108, 106, 108), (74, 72, 76)]
# weathered cortex on the raw nodule
CX = [(158, 152, 142), (130, 124, 116), (102, 97, 91), (76, 72, 68)]
# basalt (rocks.dmi), light to dark
BS = [(111, 111, 111), (95, 95, 95), (85, 85, 85), (69, 69, 69), (58, 58, 58)]
BSO = (38, 38, 40)
# wood, light to dark
WD = [(198, 151, 106), (168, 122, 76), (122, 84, 50), (92, 61, 34)]
# sinew and plant-fibre cord
CD = [(205, 185, 143), (156, 131, 96), (112, 90, 62)]
# the arrow item of weapons.dmi: shaft and feathers
AW = [(128, 99, 57), (105, 75, 51), (82, 49, 31)]
AF = [(171, 171, 149), (156, 138, 128), (99, 88, 82)]
# the flying arrow of projectiles.dmi: shaft and feathers
PS = [(120, 68, 68), (113, 55, 43)]
PF = (168, 168, 168)
# preview backgrounds
GROUND = (120, 124, 112)
LAVA = (66, 58, 54)
DARK = (30, 32, 36)


class Frame:
    def __init__(self):
        self.px = {}

    def put(self, x, y, c):
        if 0 <= x < 32 and 0 <= y < 32:
            self.px[(x, y)] = (c[0], c[1], c[2], 255)

    def pts(self, c, *points):
        for x, y in points:
            self.put(x, y, c)

    def tint(self, c, *points):
        """Like pts, but only over pixels that are already drawn."""
        for p in points:
            if p in self.px:
                self.put(p[0], p[1], c)

    def outline(self, c=OUT):
        """Ring every drawn shape with the dark outline colour."""
        edge = set()
        for (x, y) in self.px:
            for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if n not in self.px:
                    edge.add(n)
        for x, y in edge:
            self.put(x, y, c)

    def rim(self, light, dark=None):
        """Recolour the outermost pixels: smoky where the thin edge faces the
        light (upper left), optionally darker on the far side."""
        todo = {}
        for (x, y) in self.px:
            if (x - 1, y) not in self.px or (x, y - 1) not in self.px:
                todo[(x, y)] = light
            elif dark is not None and ((x + 1, y) not in self.px or (x, y + 1) not in self.px):
                todo[(x, y)] = dark
        for (x, y), c in todo.items():
            self.put(x, y, c)

    def over(self, other):
        self.px.update(other.px)

    def image(self):
        im = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c)
        return im


def bar(f, p0, p1, half, shade):
    """A straight band from p0 to p1. `half(t)` is its half-width along the
    way (t from 0 to 1); `shade(s, t)` picks the colour, s running from -1 on
    the lit upper-left edge to +1 on the shaded edge."""
    (x0, y0), (x1, y1) = p0, p1
    dx, dy = x1 - x0, y1 - y0
    ln = math.hypot(dx, dy)
    nx, ny = dy / ln, -dx / ln
    if nx + ny < 0:              # make +n point away from the light
        nx, ny = -nx, -ny
    for y in range(32):
        for x in range(32):
            px, py = x + 0.5 - x0, y + 0.5 - y0
            t = (px * dx + py * dy) / (ln * ln)
            if not 0.0 <= t <= 1.0:
                continue
            hw = half(t) if callable(half) else half
            d = px * nx + py * ny
            if hw > 0 and abs(d) <= hw:
                c = shade(d / hw, t)
                if c is not None:
                    f.put(x, y, c)


def three(pal, a=-0.34, b=0.34):
    """Light edge, middle, shaded edge."""
    return lambda s, t: pal[0] if s < a else pal[1] if s < b else pal[2]


def poly(f, c, *points):
    """Fill a polygon (pixel centres inside it) with one colour."""
    n = len(points)
    for y in range(32):
        for x in range(32):
            cx, cy, inside = x + 0.5, y + 0.5, False
            for i in range(n):
                (x0, y0), (x1, y1) = points[i], points[(i + 1) % n]
                if (y0 > cy) != (y1 > cy) and cx < x0 + (cy - y0) * (x1 - x0) / (y1 - y0):
                    inside = not inside
            if inside:
                f.put(x, y, c)


def ripple(f, c, cx, cy, r, only):
    """A conchoidal ripple: the one-pixel ring of radius r about (cx, cy),
    drawn only where the frame already holds one of the `only` colours."""
    allowed = {(o[0], o[1], o[2], 255) for o in only}
    for (x, y), old in list(f.px.items()):
        if old in allowed and abs(math.hypot(x + 0.5 - cx, y + 0.5 - cy) - r) < 0.5:
            f.put(x, y, c)


def lump(f, cx, cy, rx, ry, pal=BS):
    """A rounded basalt stone shaded in bands away from the light."""
    for y in range(32):
        for x in range(32):
            u, v = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if u * u + v * v <= 1.0:
                d = math.hypot(u + 0.45, v + 0.55)
                f.put(x, y, pal[0] if d < 0.4 else pal[1] if d < 0.8 else pal[2] if d < 1.15
                      else pal[3] if d < 1.45 else pal[4])


def trace(f, c, *points):
    """A one-pixel line through the given points."""
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            f.put(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), c)


def glass(s, t, scars=6.0):
    """Shade for a knapped obsidian blade: smoky lit edge, sheen on the lit
    face, a bright ridge, then the black shaded face with scar notches."""
    scar = int(t * scars + (0.5 if s > 0 else 0.0)) % 2
    if s < -0.66:
        return SM[0] if scar else SM[1]
    if s < -0.12:
        return OB[2] if scar else OB[3]
    if s < 0.14:
        return OB[1] if 0.1 < t < 0.85 else OB[2]
    if s < 0.64:
        return OB[4]
    return OB[5] if scar else OB[4]


# ----------------------------------------------------------------- outcrops

def chunk(apex, left, right, foot, ridge_foot, glint=True):
    """One angular block of glass: a lit left face and a black right face
    meeting on a bright ridge that runs from the apex to `ridge_foot`."""
    f = Frame()
    poly(f, OB[3], left, apex, ridge_foot, foot[0])
    poly(f, OB[5], apex, right, foot[1], ridge_foot)
    # conchoidal ripples across the lit face, struck from the apex
    for r, c in ((4.0, OB[2]), (7.5, OB[2]), (11.0, OB[4])):
        ripple(f, c, apex[0], apex[1], r, (OB[3],))
    # sheen band low on the black face
    ripple(f, OB[4], right[0] + 1.0, right[1] - 1.0, 5.0, (OB[5],))
    ripple(f, OB[4], right[0] + 1.0, right[1] - 1.0, 9.0, (OB[5],))
    f.rim(SM[1])
    # the ridge
    ax, ay = int(apex[0]), int(apex[1])
    rx, ry = int(ridge_foot[0]), int(ridge_foot[1])
    n = max(ry - ay, 1)
    for i in range(1, n - 1):
        x, y = round(ax + (rx - ax) * i / n), ay + i
        if (x, y) in f.px:
            f.put(x, y, OB[1] if i < n * 0.6 else OB[2])
    if glint:
        f.tint(OB[0], (ax, ay + 1), (ax, ay + 2), (ax - 1, ay + 3))
    f.outline(OBO)
    return f


def shadow(f, x0, x1, y):
    for x in range(x0, x1 + 1):
        if (x, y) not in f.px:
            f.put(x, y, BSO)


def basalt(*lumps):
    f = Frame()
    for cx, cy, rx, ry in lumps:
        s = Frame()
        lump(s, cx, cy, rx, ry)
        s.outline(BSO)
        f.over(s)
    return f


def obsidian_outcrop1():
    # one tall block and a lower one, footed in basalt rubble
    f = basalt((9.0, 24.5, 5.5, 3.6), (22.5, 24.0, 6.0, 4.0))
    f.over(chunk((15, 6), (9, 15), (21, 12), ((8, 26), (22, 26)), (14, 26)))
    f.over(chunk((23, 14), (19, 19), (27, 18), ((18, 27), (28, 27)), (22, 27)))
    f.over(basalt((14.0, 27.0, 4.2, 2.6), (5.5, 27.0, 2.6, 1.9), (25.5, 28.0, 3.2, 1.9)))
    f.pts(BS[4], (13, 28), (25, 29)); f.pts(BS[0], (12, 25), (24, 26))
    return f


def obsidian_outcrop2():
    # a low wide ledge of glass breaking out of a basalt hump
    f = basalt((16.0, 23.5, 12.0, 5.2))
    f.pts(BS[4], (8, 24), (9, 25), (25, 23), (24, 25)); f.pts(BS[3], (7, 22), (22, 21))
    f.over(chunk((10, 13), (6, 18), (16, 16), ((5, 24), (16, 25)), (10, 25)))
    f.over(chunk((20, 9), (15, 14), (25, 15), ((14, 25), (26, 25)), (19, 25)))
    f.over(basalt((12.5, 26.5, 4.5, 2.5), (23.5, 27.0, 4.0, 2.2), (4.5, 26.5, 2.2, 1.6)))
    f.pts(BS[0], (11, 25), (22, 26)); f.pts(BS[4], (14, 28), (25, 28))
    # loose spalls on the ground
    s = Frame()
    s.pts(OB[3], (28, 28), (29, 28), (29, 27)); s.pts(OB[1], (28, 27)); s.pts(OB[5], (30, 28))
    s.outline(OBO)
    f.over(s)
    return f


def obsidian_outcrop3():
    # three splintered blocks leaning together
    f = basalt((16.0, 25.0, 11.0, 3.6))
    f.over(chunk((24, 11), (20, 17), (28, 18), ((19, 26), (28, 26)), (23, 26), glint=False))
    f.over(chunk((9, 12), (5, 18), (14, 17), ((4, 26), (14, 26)), (8, 26)))
    f.over(chunk((17, 4), (12, 12), (21, 11), ((11, 27), (22, 27)), (16, 27)))
    f.over(basalt((9.0, 27.5, 4.0, 2.2), (21.0, 28.0, 4.8, 2.2), (28.0, 28.0, 2.4, 1.6)))
    f.pts(BS[0], (8, 26), (19, 27)); f.pts(BS[4], (10, 29), (22, 29))
    return f


# ------------------------------------------------------------------- nodule

def obsidian_nodule():
    f = Frame()
    for y in range(32):
        for x in range(32):
            u, v = (x + 0.5 - 16.0) / 9.2, (y + 0.5 - 17.5) / 7.2
            # a lumpy cobble, flattened where the break took a spall off
            if u * u + v * v > 1.0 + 0.07 * math.sin(3.0 * math.atan2(v, u) + 0.6):
                continue
            # the break runs across the lower right in a shallow curve
            if x + 0.5 + 0.75 * (y + 0.5) > 30.2 + 1.3 * math.sin(y * 0.9):
                d = math.hypot(x + 0.5 - 15.0, y + 0.5 - 13.0)
                f.put(x, y, OB[3] if d < 7.0 else OB[4] if d < 10.5 else OB[5])
            else:
                d = math.hypot(u + 0.45, v + 0.5)
                f.put(x, y, CX[0] if d < 0.42 else CX[1] if d < 0.9 else CX[2] if d < 1.3 else CX[3])
    # ripples on the fresh break, struck from the cortex side
    for r, c in ((5.5, OB[2]), (8.5, OB[1]), (12.0, OB[2])):
        ripple(f, c, 15.0, 13.0, r, (OB[3], OB[4], OB[5]))
    f.tint(OB[0], (21, 16), (22, 17), (22, 16))
    f.tint(OB[1], (19, 22), (20, 22))
    # pitted, chalky rind
    f.tint(CX[3], (10, 14), (13, 12), (9, 18), (12, 20), (15, 15), (11, 17))
    f.tint(CX[0], (11, 13), (14, 11), (10, 16))
    f.tint(CX[2], (16, 12), (13, 17), (14, 19))
    # thin chipped lip where rind meets glass
    for y in range(11, 25):
        for x in range(8, 26):
            if f.px.get((x, y)) in ((CX[1] + (255,)), (CX[2] + (255,)), (CX[3] + (255,))) and \
                    f.px.get((x + 1, y)) in ((OB[3] + (255,)), (OB[4] + (255,)), (OB[2] + (255,))):
                f.put(x, y, CX[0])
    f.outline(OBO)
    return f


# -------------------------------------------------------------------- flake

FLAKE_ROWS = {  # y: (left, right); a thin struck flake, bulb at the bottom
    6: (13, 15), 7: (12, 17), 8: (11, 19), 9: (11, 21), 10: (10, 22), 11: (10, 23),
    12: (10, 24), 13: (10, 24), 14: (10, 24), 15: (10, 24), 16: (11, 23), 17: (11, 23),
    18: (11, 23), 19: (12, 22), 20: (12, 22), 21: (12, 21), 22: (13, 21), 23: (13, 20),
    24: (14, 19), 25: (14, 18), 26: (15, 17),
}


def obsidian_flake():
    f = Frame()
    for y, (x0, x1) in FLAKE_ROWS.items():
        ridge = 19.6 - (26 - y) * 0.12       # one arris, well off centre
        for x in range(x0, x1 + 1):
            f.put(x, y, OB[3] if x + 0.5 < ridge else OB[5])
    # ripples spreading up the wide face from the bulb of percussion
    for r in (5.0, 9.0, 13.0, 17.0):
        ripple(f, OB[2], 16.0, 28.0, r, (OB[3],))
    for r in (7.0, 12.0, 16.5):
        ripple(f, OB[4], 16.0, 28.0, r, (OB[5],))
    # feather-thin edges let the light through
    f.rim(SM[0], SM[2])
    f.tint(SM[1], (11, 16), (11, 17), (11, 18), (12, 19), (12, 20), (12, 21), (13, 22), (13, 23))
    # the arris and glints
    for y in range(9, 24):
        f.tint(OB[1] if y < 19 else OB[2], (int(19.6 - (26 - y) * 0.12), y))
    f.tint(OB[0], (12, 10), (13, 9), (12, 11), (13, 10), (14, 9))
    f.tint(OB[1], (15, 24), (16, 24)); f.tint(OB[2], (15, 25), (16, 25), (17, 24))      # the bulb
    f.outline(OBO)
    return f


# --------------------------------------------------------------------- core

def obsidian_core():
    f = Frame()
    faces = (OB[3], OB[4], OB[4], OB[5], OB[5])
    arris = (None, OB[1], OB[1], OB[2], OB[3])
    for y in range(9, 28):
        k = (y - 9) / 18.0
        hw = 6.4 * (1.0 - k ** 2.6) + 0.9     # a bullet: near-parallel sides, blunt tip
        cx = 16.0 + 1.2 * k                   # the core leans a touch
        for x in range(32):
            s = (x + 0.5 - cx) / hw
            if abs(s) > 1.0:
                continue
            # blade scars: five parallel flutes running the length of the core
            pos = (s + 1.0) * 2.5
            flute = min(4, int(pos))
            c = faces[flute]
            if arris[flute] is not None and (pos - flute) * hw / 2.5 < 1.0:
                c = arris[flute]              # the arrises between scars catch the light
            f.put(x, y, c)
    f.rim(SM[1])
    # short hinge scars where blades stopped early
    f.tint(OB[2], (11, 16), (12, 16), (11, 20), (12, 20)); f.tint(OB[4], (11, 17), (12, 21))
    f.tint(OB[3], (17, 18), (18, 18), (20, 14), (21, 14)); f.tint(OB[4], (15, 23), (16, 23))
    # the striking platform: a flat ground facet seen from above
    for y in range(5, 11):
        for x in range(32):
            u, v = (x + 0.5 - 16.0) / 7.0, (y + 0.5 - 7.6) / 2.7
            if u * u + v * v <= 1.0:
                f.put(x, y, SM[0] if u + v < -0.55 else SM[1] if u + 2.0 * v < 0.5 else SM[2])
    f.tint(OB[0], (12, 6), (13, 6), (14, 6))
    # scalloped platform edge: the negative bulbs of the removed blades
    f.tint(OB[5], (10, 9), (13, 10), (16, 10), (19, 10), (22, 9))
    f.tint(OB[0], (13, 12), (13, 13), (13, 14), (15, 12))
    f.outline(OBO)
    return f


# ------------------------------------------------------------------- blades

def blade(base, tip, width=1.45):
    f = Frame()

    def shade(s, t):
        if s < -0.5:
            return SM[0]                      # the feather edge, smoky
        if s < 0.0:
            return OB[3]
        if s < 0.42:
            return OB[1] if t > 0.12 else OB[2]   # the arris between two scars
        return OB[5]

    bar(f, base, tip, lambda t: width * (0.75 + 0.25 * math.sin(t * math.pi)) if t < 0.9
        else width * (1.0 - t) * 7.0 + 0.3, shade)
    f.outline(OBO)
    return f


def obsidian_blades():
    f = Frame()
    for base, tip in (((21.5, 27.5), (26.5, 6.5)), ((7.5, 26.5), (5.5, 7.5)),
                      ((17.5, 28.5), (19.5, 4.5)), ((12.5, 28.5), (12.0, 3.5))):
        f.over(blade(base, tip))
    f.tint(OB[0], (12, 6), (12, 7), (19, 8), (19, 9), (6, 11), (25, 12))
    return f


# --------------------------------------------------------------- arrowheads

# the pile of icons/obj/flint_mining.dmi "flint_arrowheads":
# o outline, l lit face, r shaded face, c ridge
ARROWHEADS = (
    '.........o......................',
    '........olo.....................',
    '........oco.....................',
    '.......olcro....................',
    '.......olcro......o.............',
    '.......olcro.....olo............',
    '......ollcrro....oco............',
    '......ollcrro...olcro...........',
    '.....olllcrrro..olcro...........',
    '.....oloooooro..olcro...........',
    '......o.....oo.ollcrro..........',
    '............oloollcrro..........',
    '............ocolllcrrro.........',
    '...........olcroooooooro........',
    '...........olcro.....o..........',
    '...........olcro................',
    '..........ollcrro...............',
    '..........ollcrro...............',
    '.........olllcrrro..............',
    '.........oloooooro..............',
    '..........o.....o...............',
)


def stamp(f, rows, key, top=0):
    for j, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != '.':
                f.put(x, top + j, key[ch])


def obsidian_arrowheads():
    f = Frame()
    stamp(f, ARROWHEADS, {'o': OBO, 'l': OB[3], 'r': OB[5], 'c': OB[1]}, top=7)
    f.pts(OB[0], (9, 9), (9, 10), (18, 13), (18, 14), (13, 19), (13, 20))       # glints
    f.pts(SM[1], (9, 8), (18, 12), (13, 18))                                    # smoky tips
    f.pts(SM[1], (6, 15), (16, 19), (10, 25))                                   # thin barbs
    f.pts(OB[4], (12, 15), (22, 19), (16, 25))
    return f


# ---------------------------------------------------------------- spearhead

def obsidian_spearhead():
    f = Frame()
    # long leaf point, widest a third of the way up from the tang
    bar(f, (11.5, 28.5), (21.5, 3.5),
        lambda t: 0.5 + 3.5 * min(1.0, 0.35 + 2.4 * t) * (1.0 - t) ** 0.7 if t > 0.14 else 1.7,
        lambda s, t: glass(s, t, 8.0))
    f.tint(OB[0], (17, 12), (17, 13), (16, 15), (21, 4))
    f.tint(OB[2], (12, 25), (12, 26)); f.tint(OB[5], (13, 27), (14, 26))        # ground tang
    f.outline(OBO)
    return f


# -------------------------------------------------------------------- spear

def obsidian_spear():
    f = Frame()
    bar(f, (3.5, 28.5), (21.5, 10.5), 1.05, lambda s, t: WD[1] if s < 0 else WD[2])
    f.pts(WD[3], (3, 28), (4, 28)); f.pts(WD[0], (9, 22), (13, 18), (17, 14))
    f.outline()
    h = Frame()
    bar(h, (19.5, 12.5), (29.5, 2.5),
        lambda t: 0.4 + 2.9 * min(1.0, 0.5 + 2.6 * t) * (1.0 - t) ** 0.75,
        lambda s, t: glass(s, t, 5.0))
    h.tint(OB[0], (24, 7), (25, 6), (29, 2))
    h.outline(OBO)
    f.over(h)
    # sinew binding over the split shaft and the tang
    b = Frame()
    bar(b, (17.5, 14.5), (21.0, 11.0), 1.6,
        lambda s, t: (CD[0] if s < -0.2 else CD[1] if s < 0.45 else CD[2]))
    b.outline()
    f.over(b)
    f.pts(CD[2], (18, 13), (20, 13), (19, 12))
    return f


# -------------------------------------------------------------------- knife

def obsidian_knife():
    f = Frame()
    # grip: the tang bedded in a hide wrap, bound with sinew
    bar(f, (5.5, 26.5), (13.5, 18.5), lambda t: 1.75 + 0.35 * t,
        lambda s, t: (CD[0] if s < -0.3 else CD[1] if s < 0.4 else CD[2]) if int(t * 7.0) % 2 == 0
        else (CD[1] if s < 0.1 else CD[2]))
    f.pts(CD[1], (4, 27), (5, 28)); f.pts(CD[0], (4, 26)); f.pts(CD[2], (6, 28), (5, 27))   # knotted tail
    f.outline()
    # leaf blade: full behind the middle, drawn out to the point
    b = Frame()
    bar(b, (12.5, 19.5), (28.0, 4.0),
        lambda t: 0.45 + 3.1 * min(1.0, 0.55 + 2.2 * t) * (1.0 - t) ** 0.75, glass)
    b.pts(SM[0], (28, 3))
    b.tint(OB[0], (19, 12), (20, 11), (22, 9)); b.tint(OB[5], (20, 15), (23, 12))
    b.outline(OBO)
    f.over(b)
    f.pts(CD[0], (12, 18), (13, 17)); f.pts(CD[1], (13, 19), (14, 18)); f.pts(CD[2], (14, 19), (15, 18))
    return f


# ------------------------------------------------------------------ scraper

SCRAPER_ROWS = {  # a small end-scraper on a blade segment, working end uppermost
    8: (17, 20), 9: (15, 22), 10: (14, 23), 11: (14, 23), 12: (13, 23), 13: (13, 23),
    14: (13, 23), 15: (13, 22), 16: (12, 22), 17: (12, 21), 18: (12, 21), 19: (12, 20),
    20: (12, 20), 21: (12, 19), 22: (12, 18), 23: (13, 17),
}


def obsidian_scraper():
    f = Frame()
    for y, (x0, x1) in SCRAPER_ROWS.items():
        lean = (23 - y) / 5.0
        for x in range(x0, x1 + 1):
            # three long facets: lit flank, flat back, shaded flank
            f.put(x, y, OB[3] if x < 14.5 + lean else OB[2] if x < 17.0 + lean and y > 12 else OB[4])
    # steep retouch round the working end: short flakes fanning from the edge
    f.tint(SM[0], (17, 8), (19, 8), (15, 9), (14, 10), (16, 10), (18, 10), (20, 10))
    f.tint(OB[5], (18, 8), (20, 8), (22, 9), (23, 10), (23, 11), (15, 11), (17, 11), (19, 11), (21, 11))
    f.tint(OB[1], (18, 9), (20, 9), (16, 12), (18, 12), (20, 12))
    f.tint(OB[3], (17, 9), (19, 9), (21, 9), (22, 12))
    # arrises of the back facet, glint, shaded right edge
    for y in range(13, 22):
        f.tint(OB[1] if y < 18 else OB[2], (int(14.5 + (23 - y) / 5.0), y))
    f.tint(OB[0], (16, 13), (16, 14), (15, 15))
    f.tint(OB[5], (23, 12), (23, 13), (23, 14), (22, 15), (22, 16), (21, 17), (21, 18), (20, 19), (20, 20),
           (19, 21), (18, 22), (17, 23), (16, 23))
    f.tint(SM[1], (13, 13), (13, 14), (12, 16), (12, 18), (12, 20))
    f.tint(OB[2], (13, 21), (14, 22))                                           # the bulb at the butt
    f.outline(OBO)
    return f


# ------------------------------------------------------------- arrow (item)

# icons/obj/weapons.dmi "arrow_flint" with the head re-cut in obsidian:
# 1 2 3 shaft light to dark, a b d feathers, G glint, S sheen, B body, K black
ARROW_ITEM = (
    '.....................GS.........',
    '....................SBK.........',
    '..................sBBK..........',
    '..................1BK...........',
    '.................12Kk...........',
    '................123.............',
    '...............123..............',
    '..............123...............',
    '.............123................',
    '............123.................',
    '...........123..................',
    '..........123...................',
    '.........123....................',
    '......ba123.....................',
    '....abd123......................',
    '...aba123a......................',
    '.....123db......................',
    '.....33ab.......................',
    '.......ba.......................',
    '.......a........................',
)


def arrow_obsidian():
    f = Frame()
    stamp(f, ARROW_ITEM, {'1': AW[0], '2': AW[1], '3': AW[2], 'a': AF[0], 'b': AF[1], 'd': AF[2],
                          'G': OB[0], 'S': OB[1], 's': OB[2], 'B': OB[3], 'K': OB[5], 'k': OB[4]}, top=7)
    return f


# ----------------------------------------------------------- arrow (flight)

# icons/obj/projectiles.dmi "arrow_flint", one frame per direction, with the
# grey flint tip replaced by glass: f feather, 1 2 shaft, G S B K as above
FLIGHT = {
    'south': (12, (
        '..............f..f..............',
        '..............f11f..............',
        '..............2211..............',
        '...............21...............',
        '...............21...............',
        '...............21...............',
        '...............BK...............',
        '..............SBKK..............',
        '..............GSBK..............',
        '...............SK...............',
    )),
    'north': (10, (
        '...............GK...............',
        '..............GSBK..............',
        '..............SBKK..............',
        '...............BK...............',
        '...............21...............',
        '...............21...............',
        '...............21...............',
        '..............2211..............',
        '..............f11f..............',
        '..............f..f..............',
    )),
    'east': (14, (
        '............ff1....SS...........',
        '.............11111BBGS..........',
        '.............12222BKKK..........',
        '............ff2....KK...........',
    )),
    'west': (14, (
        '...........SS....1ff............',
        '..........SGBB11111.............',
        '..........KKKB22221.............',
        '...........KK....2ff............',
    )),
}


def flight(direction):
    f = Frame()
    top, rows = FLIGHT[direction]
    stamp(f, rows, {'f': PF, '1': PS[0], '2': PS[1], 'G': OB[0], 'S': OB[1], 'B': OB[3], 'K': OB[5]}, top=top)
    return f


# each state is a list of frames: one, or four in BYOND order S, N, E, W
STATES = {
    'obsidian_outcrop1': [obsidian_outcrop1()],
    'obsidian_outcrop2': [obsidian_outcrop2()],
    'obsidian_outcrop3': [obsidian_outcrop3()],
    'obsidian_nodule': [obsidian_nodule()],
    'obsidian_flake': [obsidian_flake()],
    'obsidian_core': [obsidian_core()],
    'obsidian_blades': [obsidian_blades()],
    'obsidian_arrowheads': [obsidian_arrowheads()],
    'obsidian_spearhead': [obsidian_spearhead()],
    'obsidian_spear': [obsidian_spear()],
    'obsidian_knife': [obsidian_knife()],
    'obsidian_scraper': [obsidian_scraper()],
    'arrow_obsidian': [arrow_obsidian()],
    'arrow_obsidian_flight': [flight('south'), flight('north'), flight('east'), flight('west')],
}
COLUMNS = 4


def write_dmi(path, states):
    frames = [fr for group in states.values() for fr in group]
    rows = -(-len(frames) // COLUMNS)
    sheet = Image.new('RGBA', (32 * COLUMNS, 32 * rows), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(fr.image(), (i % COLUMNS * 32, i // COLUMNS * 32))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, group in states.items():
        text += 'state = "%s"\n\tdirs = %d\n\tframes = 1\n' % (name, len(group))
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta)


def read_dmi(path):
    """The frames of an existing 32px DMI by state name (preview only)."""
    im = Image.open(path)
    text = im.info['Description']
    im = im.convert('RGBA')
    cols, out, i = im.width // 32, {}, 0
    for name, body in re.findall(r'state = "(.*?)"\n((?:\t.*\n)*)', text):
        n = int(re.search(r'dirs = (\d+)', body).group(1)) * int(re.search(r'frames = (\d+)', body).group(1))
        group = [im.crop((k % cols * 32, k // cols * 32, k % cols * 32 + 32, k // cols * 32 + 32))
                 for k in range(i, i + n)]
        out.setdefault(name, group)
        i += n
    return out


# flint (and rock) art each obsidian state should sit beside: (file, state)
COMPARE = {
    'obsidian_outcrop1': ('icons/obj/flora/rocks.dmi', 'basalt1'),
    'obsidian_outcrop2': ('icons/obj/flora/rocks.dmi', 'rock2'),
    'obsidian_outcrop3': ('icons/obj/flora/rocks.dmi', 'rock4'),
    'obsidian_arrowheads': ('icons/obj/flint_mining.dmi', 'flint_arrowheads'),
    'obsidian_spearhead': ('icons/obj/flint_mining.dmi', 'flint_spearhead'),
    'obsidian_spear': ('icons/obj/weapons.dmi', 'spear'),
    'obsidian_knife': ('icons/obj/stone_age_arms.dmi', 'flint_knife'),
    'obsidian_scraper': ('icons/obj/stone_age_arms.dmi', 'hide_scraper'),
    'arrow_obsidian': ('icons/obj/weapons.dmi', 'arrow_flint'),
    'arrow_obsidian_flight': ('icons/obj/projectiles.dmi', 'arrow_flint'),
}


def write_preview(path, scale=8, per_row=6):
    """Every frame at 8x on grass-grey ground with a 1x and 2x strip on that
    ground and on dark dry lava; then each state at 4x beside its flint
    equivalent."""
    cell = 32 * scale
    tiles = [(name, fr.image()) for name, group in STATES.items() for fr in group]
    rows = -(-len(tiles) // per_row)
    band = cell + 80
    pairs = [(name, STATES[name], read_dmi(ROOT / src)[state]) for name, (src, state) in COMPARE.items()]
    slots = sum(len(new) + len(old) for _, new, old in pairs)
    crow = -(-slots // 12)
    sheet = Image.new('RGBA', (cell * per_row, band * rows + 16 + crow * 136), DARK + (255,))

    def on(ground, im, k):
        tile = Image.new('RGBA', (32, 32), ground + (255,))
        tile.alpha_composite(im)
        return tile.resize((32 * k, 32 * k), Image.NEAREST)

    for i, (name, im) in enumerate(tiles):
        ox, oy = i % per_row * cell, i // per_row * band
        sheet.alpha_composite(on(GROUND, im, scale), (ox, oy))
        sheet.alpha_composite(on(GROUND, im, 1), (ox + 8, oy + cell + 24))
        sheet.alpha_composite(on(GROUND, im, 2), (ox + 48, oy + cell + 8))
        sheet.alpha_composite(on(LAVA, im, 1), (ox + 128, oy + cell + 24))
        sheet.alpha_composite(on(LAVA, im, 2), (ox + 168, oy + cell + 8))
    # comparisons: obsidian frames then the flint ones, separated by a gap
    x, y = 0, band * rows + 16
    for name, new, old in pairs:
        need = (len(new) + len(old)) * 128
        if x + need > sheet.width:
            x, y = 0, y + 136
        for fr in new:
            sheet.alpha_composite(on(GROUND, fr.image(), 4), (x, y))
            x += 128
        for im in old:
            sheet.alpha_composite(on(LAVA, im, 4), (x, y))
            x += 128
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.convert('RGB').save(path)


def main():
    write_dmi(ROOT / 'icons/obj/obsidian.dmi', STATES)
    if '--preview' in sys.argv[1:-1]:
        write_preview(sys.argv[sys.argv.index('--preview') + 1])


if __name__ == '__main__':
    main()
