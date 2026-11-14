"""Hand-placed 32px art for the aluminium chain: bauxite ore piles, alumina
powder heaps, aluminium ingots, fired alumina armour tiles, composite armour
panels, the alumina digester and the electrolytic reduction pot (each with a
four-frame working animation) and the red mud puddle. Every pixel is placed
by this script from a fixed palette (Pillow only); no external or generated
artwork.

Pile states grow with the suffixes "", "_2", "_3", "_4" like the ore piles of
icons/obj/mining.dmi and the ingots of icons/obj/materials.dmi. The bauxite
lumps are the size of "ore_tin" lumps and the ingot is the slanted slab of
"sheet-tin", cooler and brighter. Lit from the upper left; every object is
ringed with a darker shade of its own colour.

    python3 tests/sprites/create_aluminium.py [--preview sheet.png] [--check]

Run with Pillow to reproduce icons/obj/aluminium.dmi. `--preview <png>` also
writes a review sheet (each state at 4x with the 1x sprite beside it, the
animations as a row of frames, and the neighbouring ore and ingot sprites for
comparison). `--check` writes nothing and fails when the committed sheet
differs from what this script draws.
Released under Civ13 AGPL-3.0.
"""
import math
import re
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
DMI = ROOT / 'icons/obj/aluminium.dmi'
COLUMNS = 6

# bauxite: outline, dark, mid red-brown, light, ochre, cream pisolite
BX = {'o': (64, 32, 24), 'D': (104, 46, 32), 'm': (140, 64, 40), 'l': (168, 88, 50),
      'y': (196, 136, 72), 'p': (236, 204, 144)}
# alumina powder: glint, lit, body, shade, deep shade, outline
AL = [(255, 255, 255), (244, 247, 250), (224, 230, 238), (192, 202, 216), (160, 172, 190)]
ALO = (98, 108, 128)
# burlap sack: highlight, body, shade, rolled rim, outline
SK = {'T': (206, 178, 126), 't': (176, 146, 98), 's': (134, 106, 68), 'r': (196, 168, 118),
      'o': (72, 54, 34), 'w': AL[2], 'W': AL[0]}
# aluminium metal: glint, lit, face, shade, dark
AM = [(252, 254, 255), (226, 236, 246), (198, 212, 228), (160, 178, 200), (122, 140, 166)]
AMO = (62, 74, 98)
# fired alumina ceramic: lit, face, shade, dark
CR = [(250, 247, 238), (232, 227, 214), (198, 191, 176), (158, 150, 136)]
CRO = (78, 70, 60)
# armour steel: glint, lit, face, shade, dark
ST = [(176, 184, 194), (134, 142, 154), (98, 106, 118), (68, 74, 86), (46, 50, 60)]
STO = (24, 26, 32)
# aramid backing: lit, face, shade
KV = [(200, 178, 84), (160, 142, 62), (116, 104, 46)]
# brick: lit, face, shade, mortar
BR = [(184, 98, 68), (150, 72, 52), (112, 52, 40), (84, 42, 34)]
# copper: glint, face, shade, dark
CU = [(242, 170, 98), (204, 116, 54), (148, 78, 34), (96, 48, 24)]
# brass
BS = [(232, 200, 110), (188, 150, 70), (126, 96, 42)]
# carbon anode: lit, face, shade
CB = [(86, 86, 96), (52, 52, 60), (28, 28, 34)]
# fire and melt
FIRE = {'r': (204, 62, 22), 'o': (242, 132, 32), 'y': (255, 212, 84), 'w': (255, 246, 196)}
# red mud: glint, lit, body, shade, edge
RM = [(214, 150, 118), (170, 86, 56), (132, 56, 36), (100, 40, 28), (70, 28, 22)]
# preview
DARK = (30, 32, 36)
FLOORS = ((120, 124, 112), (112, 92, 70))


def noise(x, y, seed=0):
    """A fixed 0..1 hash, so speckle never changes between runs."""
    n = (x * 374761393 + y * 668265263 + seed * 1442695041) & 0xffffffff
    n = ((n ^ (n >> 13)) * 1274126177) & 0xffffffff
    return ((n ^ (n >> 16)) & 0xffff) / 65535.0


class Frame:
    def __init__(self):
        self.px = {}

    def put(self, x, y, c, a=255):
        if 0 <= x < 32 and 0 <= y < 32:
            self.px[(x, y)] = (c[0], c[1], c[2], a)

    def pts(self, c, *points, a=255):
        for x, y in points:
            self.put(x, y, c, a)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def tint(self, c, *points):
        """Like pts, but only over pixels that are already drawn."""
        for p in points:
            if p in self.px:
                self.put(p[0], p[1], c)

    def outline(self, c):
        """Ring every drawn shape with the dark outline colour."""
        edge = set()
        for (x, y) in self.px:
            for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if n not in self.px:
                    edge.add(n)
        for x, y in edge:
            self.put(x, y, c)
        return self

    def over(self, other):
        """Lay another frame on top of this one."""
        for (x, y), (r, g, b, a) in other.px.items():
            if a == 255 or (x, y) not in self.px:
                self.px[(x, y)] = (r, g, b, a)
            else:
                br, bg, bb, ba = self.px[(x, y)]
                k = a / 255.0
                self.px[(x, y)] = (round(r * k + br * (1 - k)), round(g * k + bg * (1 - k)),
                                   round(b * k + bb * (1 - k)), max(a, ba))
        return self

    def image(self):
        im = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c)
        return im


def stamp(f, rows, pal, left=0, top=0, flip=False):
    """Place a hand-drawn bitmap: one character per pixel, '.' is empty."""
    width = len(rows[0])
    for j, row in enumerate(rows):
        assert len(row) == width, (rows[0], row)
        for i, ch in enumerate(row[::-1] if flip else row):
            if ch != '.':
                f.put(left + i, top + j, pal[ch])


# ------------------------------------------------------------- bauxite ore

# o outline, D shade, m red-brown body, l lit face, y ochre, p pisolite
# nodule (a cream dot with ochre beside it and shade beneath)
LUMP_A = (
    '.....oooo.oo..',
    '...ooyllloymo.',
    '..oylpllmmpmmo',
    '.oyllDmmmmDmDo',
    'oyllmmpymmmmDo',
    'ollpmmDmmmpDDo',
    'olmDmmmmpmDDo.',
    '.oDmmmDDDDDo..',
    '..ooooooooo...',
)
LUMP_B = (
    '...ooooo...',
    '.ooyllllo..',
    'oylpllmpmo.',
    'oyllDmmDmDo',
    'ollmmpmmDDo',
    'ompmmDmpDo.',
    '.oDDmDDDo..',
    '..oooooo...',
)
# back to front: bitmap, left, top
ORE_PILES = {
    'ore_bauxite': ((LUMP_A, 9, 12),),
    'ore_bauxite_2': ((LUMP_A, 3, 9), (LUMP_B, 17, 17)),
    'ore_bauxite_3': ((LUMP_B, 12, 7), (LUMP_A, 3, 13), (LUMP_B, 17, 15), (LUMP_B, 12, 20)),
    'ore_bauxite_4': ((LUMP_B, 11, 2), (LUMP_A, 4, 7), (LUMP_B, 17, 8), (LUMP_B, 1, 14),
                      (LUMP_A, 10, 13), (LUMP_B, 21, 16), (LUMP_A, 3, 20), (LUMP_B, 17, 22)),
}


def ore(name):
    f = Frame()
    for rows, left, top in ORE_PILES[name]:
        stamp(f, rows, BX, left, top)
    return f


# ------------------------------------------------------------------ alumina

SACK = (
    '...oooooo...',
    '..orwwwwro..',
    '.orwwWWwwro.',
    '.orrwwwwrro.',
    '.otrrrrrrso.',
    'otttttttsso.',
    'otTttttttsso',
    'otTtttttssso',
    'otttttttssso',
    'otttttttssso',
    'ottttttsssso',
    '.otttttssso.',
    '.osssssssso.',
    '..oooooooo..',
)


def heap(cx, base, half, height, seed):
    """A cone of fine powder: lit left flank, shaded right flank and foot."""
    f = Frame()
    for dx in range(-half, half + 1):
        h = height * (1.0 - (abs(dx) / (half + 0.6)) ** 1.5)
        top = base - int(round(h))
        for y in range(top, base + 1):
            n = dx / float(half) + (y - top) * 0.04
            k = 1 if n < -0.3 else 2 if n < 0.3 else 3
            if y == base and k < 3:
                k += 1
            if y == top and dx <= 0:
                k = 0
            r = noise(cx + dx, y, seed)
            if r > 0.9 and k < 4:
                k += 1
            elif r < 0.07 and k > 0:
                k -= 1
            f.put(cx + dx, y, AL[k])
    f.outline(ALO)
    # a few loose grains at the foot
    for i in range(half // 2):
        x = cx - half - 2 + int(noise(i, seed, 5) * (2 * half + 5))
        if (x, base + 1) not in f.px and (x, base) not in f.px:
            f.put(x, base + 1, AL[3])
    return f


def alumina(n):
    f = Frame()
    if n == 1:
        f.over(heap(16, 21, 6, 5, 1))
    elif n == 2:
        f.over(heap(16, 23, 9, 8, 2))
    elif n == 3:
        stamp(f, SACK, SK, 4, 10)
        f.over(heap(20, 26, 8, 7, 3))
    else:
        stamp(f, SACK, SK, 2, 6)
        stamp(f, SACK, SK, 13, 4, flip=True)
        f.over(heap(17, 28, 11, 10, 4))
    return f


# -------------------------------------------------------------- slab maths

def slab(origin, u, v, thick, top, left, right, edge):
    """A flat block seen from above and in front. `origin` is the far corner
    of the top face, `u` runs to the right and down, `v` to the left and
    down. top(s, t) colours the upper face from its two 0..1 coordinates,
    left(d, k) and right(d, k) colour the two visible sides from the depth
    below the upper edge and the 0..1 position along it."""
    f = Frame()
    ox, oy = origin
    det = u[0] * v[1] - u[1] * v[0]
    low = {}
    for y in range(32):
        for x in range(32):
            px, py = x + 0.5 - ox, y + 0.5 - oy
            s = (px * v[1] - py * v[0]) / det
            t = (u[0] * py - u[1] * px) / det
            if 0 <= s <= 1 and 0 <= t <= 1:
                f.put(x, y, top(s, t))
                low[x] = (y, s, t)
    front = ox + u[0] + v[0]
    for x, (y, s, t) in low.items():
        for d in range(thick):
            f.put(x, y + 1 + d, left(d, s) if x + 0.5 < front else right(d, t))
    return f.outline(edge)


# ---------------------------------------------------------------- ingots

def ingot(origin):
    def top(s, t):
        if t < 0.2 or s < 0.1:
            return AM[1] if (s > 0.12 and t > 0.06) or s < 0.1 else AM[0]
        if t > 0.8 or s > 0.9:
            return AM[2]
        # the sunken pour face, with a glint running along it
        if 0.34 < t < 0.5 and 0.2 < s < 0.62:
            return AM[0]
        return AM[2] if (t > 0.62 or s > 0.78) else AM[1]

    f = slab(origin, (14, 8), (-6, 6), 3, top,
             lambda d, k: AM[3] if d < 2 else AM[4],
             lambda d, k: AM[4], AMO)
    return f


INGOTS = {
    1: ((13, 8),),
    2: ((16, 5), (10, 11)),
    3: ((16, 8), (10, 14), (13, 4)),
    4: ((16, 11), (10, 17), (16, 5), (10, 11), ),
}


def ingots(n):
    f = Frame()
    for origin in INGOTS[n]:
        f.over(ingot(origin))
    return f


# ---------------------------------------------------------- ceramic tiles

def tile(origin, chip=False):
    def top(s, t):
        if s < 0.12 or t < 0.12:
            return CR[0]
        if s > 0.88 or t > 0.88:
            return CR[2]
        return CR[1]

    f = slab(origin, (10, 5), (-8, 4), 2, top,
             lambda d, k: CR[2] if d == 0 else CR[3],
             lambda d, k: CR[3], CRO)
    return f


TILES = {
    1: ((16, 12),),
    2: ((17, 14), (15, 11)),
    3: ((16, 16), (17, 13), (15, 10)),
    4: ((19, 17), (20, 14), (18, 11), (11, 19)),
}


def tiles(n):
    f = Frame()
    for origin in TILES[n]:
        f.over(tile(origin))
    return f


# -------------------------------------------------------- composite panels

def panel(origin):
    def top(s, t):
        # a rolled steel face: bright upper edges, a bolt in each corner
        if s < 0.07 or t < 0.1:
            return ST[1]
        if s > 0.93 or t > 0.9:
            return ST[3]
        near = min(s, 1 - s) < 0.2 and min(t, 1 - t) < 0.26
        far = min(s, 1 - s) > 0.11 and min(t, 1 - t) > 0.14
        if near and far:
            return ST[0]
        return ST[2]

    def left(d, k):
        if d < 2:
            return (ST[3], CR[1])[d]
        return KV[0] if d == 2 else KV[1]

    def right(d, k):
        if d < 2:
            return (ST[4], CR[2])[d]
        return KV[1] if d == 2 else KV[2]

    return slab(origin, (12, 6), (-10, 5), 4, top, left, right, STO)


PANELS = {
    1: ((15, 9),),
    2: ((15, 11), (16, 6)),
    3: ((15, 13), (16, 8), (15, 3)),
    4: ((15, 16), (16, 11), (15, 6), (16, 1)),
}


def panels(n):
    f = Frame()
    for origin in PANELS[n]:
        f.over(panel(origin))
    return f


# ---------------------------------------------------------------- digester

# flame in the firebox mouth, one bitmap per frame
FLAMES = (
    ('..o...', 'rooy.r', 'oyyyoo', 'ywwyyo'),
    ('.....o', 'royo.o', 'oyyyor', 'yywwyo'),
    ('...o..', 'orryo.', 'oyyyyr', 'oywwyy'),
    ('.o....', 'ooyr.r', 'ryyyoo', 'yywyyo'),
)
# steam from the relief valve: x, y, alpha
STEAM = (
    ((15, 2, 210), (16, 2, 150)),
    ((15, 1, 200), (16, 1, 210), (16, 2, 150), (17, 0, 110)),
    ((16, 0, 150), (17, 1, 170), (15, 2, 210), (17, 0, 90), (18, 0, 70)),
    ((15, 1, 180), (16, 2, 200), (17, 0, 120), (18, 1, 70)),
)
WHITE = (240, 244, 248)


def bricks(f, x0, y0, x1, y1):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            row = y - y0
            if row % 2 == 1:
                c = BR[3]
            elif (x - x0 + (row // 2 % 2) * 2) % 4 == 3:
                c = BR[3]
            else:
                c = BR[0] if row == 0 else BR[1]
            f.put(x, y, c)


def digester(frame=None):
    f = Frame()
    on = frame is not None
    # legs and feet
    for x in (6, 22):
        f.rect(x, 19, x + 1, 30, ST[3])
        for y in range(19, 31):
            f.put(x, y, ST[1])
        f.rect(x - 1, 30, x + 2, 30, ST[4])
    # firebox: brick box under the vessel with an arched mouth
    bricks(f, 9, 24, 20, 30)
    f.rect(8, 23, 21, 23, ST[3])
    f.rect(9, 23, 20, 23, ST[2])
    f.rect(12, 27, 17, 30, (26, 20, 20))
    f.rect(13, 26, 16, 26, (26, 20, 20))
    f.pts(BR[3], (11, 27), (11, 28), (11, 29), (11, 30), (18, 27), (18, 28), (18, 29), (18, 30),
          (12, 26), (17, 26), (13, 25), (14, 25), (15, 25), (16, 25))
    if on:
        stamp(f, FLAMES[frame], FIRE, 12, 27)
        f.pts(FIRE['o'] if frame % 2 else FIRE['r'], (13, 26), (16, 26))
        f.pts(FIRE['y'] if frame % 2 else FIRE['o'], (14, 26), (15, 26))
        # the glow licks the brick arch and the underside of the vessel
        warm = (226, 124, 62) if frame % 2 else (206, 104, 56)
        f.pts(warm, (11, 27), (11, 28), (18, 27), (18, 28), (12, 26), (17, 26),
              (13, 25), (14, 25), (15, 25), (16, 25))
        f.pts((150, 84, 50), (12, 23), (13, 23), (14, 23), (15, 23), (16, 23), (17, 23))
    else:
        f.pts((74, 72, 74), (12, 29), (14, 29), (16, 29))
        f.pts((112, 108, 104), (13, 30), (15, 30), (16, 30))
    # the vessel: a domed riveted cylinder, shaded round its girth
    shade = (4, 3, 2, 1, 0, 0, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4)
    spans = {5: (11, 18), 6: (9, 20), 7: (8, 21), 21: (8, 21), 22: (10, 19)}
    for y in range(5, 23):
        x0, x1 = spans.get(y, (7, 22))
        for x in range(x0, x1 + 1):
            k = shade[x - 7]
            if y == 5 and k > 0:
                k -= 1
            if y >= 21 and k < 4:
                k += 1
            f.put(x, y, ST[k])
    for y in (8, 20):
        for x in range(7, 23):
            f.put(x, y, ST[4] if x % 2 else ST[0] if x < 14 else ST[1])
    for y in (11, 14, 17):
        f.pts(ST[4], (19, y))
        f.pts(ST[1], (18, y))
    # relief valve on the crown
    f.rect(15, 3, 16, 4, BS[1])
    f.pts(BS[0], (15, 3))
    # pressure gauge on a brass boss
    f.rect(11, 11, 13, 15, BS[1])
    f.rect(10, 12, 14, 14, BS[1])
    f.pts(BS[0], (11, 11), (12, 11), (10, 12), (10, 13))
    f.pts(BS[2], (14, 12), (14, 13), (14, 14), (11, 15), (12, 15), (13, 15))
    f.rect(11, 12, 13, 14, (240, 238, 226))
    needle = ((11, 14), (12, 13)) if not on else (((12, 13), (13, 12)), ((12, 13), (12, 12)))[frame % 2]
    f.pts((190, 40, 30), *needle)
    f.outline(STO)
    # liquor pipe: out of the shell, down the side, away along the floor
    p = Frame()
    p.rect(23, 10, 27, 11, CU[1])
    p.rect(26, 10, 27, 27, CU[1])
    p.rect(26, 26, 31, 27, CU[1])
    for y in range(10, 27):
        p.put(27, y, CU[2])
    for x in range(26, 32):
        p.put(x, 27, CU[2])
    for x in range(23, 27):
        p.put(x, 10, CU[0])
    for y in range(12, 26):
        p.put(26, y, CU[0])
    p.pts(CU[0], (28, 26), (29, 26), (30, 26), (31, 26))
    # flanges and a red hand valve
    p.rect(23, 9, 23, 12, ST[1])
    p.rect(25, 22, 28, 23, ST[1])
    p.pts(ST[3], (28, 22), (28, 23))
    p.rect(24, 16, 29, 17, (196, 48, 38))
    p.pts((236, 96, 80), (24, 16), (25, 16), (26, 16), (27, 16))
    p.pts((120, 26, 24), (29, 17), (28, 17))
    p.outline(STO)
    f.over(p)
    if on:
        for x, y, a in STEAM[frame]:
            f.put(x, y, WHITE, a)
    return f


# ----------------------------------------------------------- reduction pot

# molten bath seen between and under the anodes, one row pair per frame
MELT = (
    ('oyyoorooyywyoorooyo', 'royywyoooryyoooywyr'),
    ('ooywyorooyyoorooyyo', 'roooyyoorywyooryyor'),
    ('oyoooroywyooyrooywo', 'rywyooooroyyoroyyor'),
    ('oooyyrooyyoowyrooyo', 'royyooywooryooowyor'),
)
# fumes: x, y, alpha
FUMES = (
    ((10, 12, 120), (16, 11, 110), (22, 12, 90), (10, 8, 60), (4, 11, 70)),
    ((10, 11, 120), (16, 12, 120), (16, 9, 70), (22, 11, 100), (4, 12, 90), (11, 7, 50)),
    ((10, 12, 110), (10, 9, 80), (16, 10, 110), (22, 12, 110), (22, 9, 60), (4, 10, 70), (17, 7, 50)),
    ((10, 10, 110), (16, 12, 120), (16, 8, 70), (22, 10, 90), (4, 12, 90), (23, 7, 50)),
)
FUME = (206, 206, 196)


def reduction_pot(frame=None):
    f = Frame()
    on = frame is not None
    # gantry posts and the bus bar the anodes hang from
    for x in (1, 24):
        f.rect(x, 3, x + 1, 13, ST[3])
        for y in range(3, 14):
            f.put(x, y, ST[1])
    f.rect(0, 3, 27, 5, AM[3])
    for x in range(0, 28):
        f.put(x, 3, AM[1])
        f.put(x, 5, AM[4])
    # brick-lined cavity: back lip, side walls, the bath
    f.rect(1, 13, 25, 13, BR[0])
    for x in range(1, 26):
        if x % 4 == 2:
            f.put(x, 13, BR[2])
    f.rect(1, 14, 3, 17, BR[2])
    f.rect(23, 14, 25, 17, BR[2])
    f.pts(BR[1], (1, 14), (1, 15), (1, 16), (1, 17), (25, 14), (25, 15), (25, 16), (25, 17))
    if on:
        for y in (14, 15):
            for x in range(4, 23):
                f.put(x, y, FIRE['o'] if (x + frame) % 3 else FIRE['r'])
        stamp(f, MELT[frame], FIRE, 4, 16)
        glow = (214, 112, 60) if frame % 2 else (196, 96, 54)
        f.pts(glow, (3, 14), (3, 15), (3, 16), (3, 17), (23, 14), (23, 15), (23, 16), (23, 17))
    else:
        # frozen crust with a dusting of alumina
        f.rect(4, 14, 22, 17, (58, 54, 56))
        for x in range(4, 23):
            for y in (16, 17):
                r = noise(x, y, 9)
                if r > 0.72:
                    f.put(x, y, (206, 206, 200) if r > 0.88 else (96, 90, 90))
    # carbon anodes on their rods
    for x in (5, 11, 17):
        f.rect(x + 2, 6, x + 3, 8, ST[2])
        f.pts(ST[0], (x + 2, 6), (x + 2, 7), (x + 2, 8))
        f.rect(x + 1, 3, x + 4, 5, ST[3])
        f.pts(ST[1], (x + 1, 3), (x + 2, 3), (x + 3, 3))
        f.rect(x, 9, x + 4, 15, CB[1])
        for y in range(9, 16):
            f.put(x, y, CB[0])
            f.put(x + 4, y, CB[2])
        for i in range(5):
            f.put(x + i, 9, CB[0])
        if on:
            hot = (236, 120, 40) if (frame + x) % 2 else (204, 84, 30)
            for i in range(5):
                f.put(x + i, 15, hot)
            for i in range(1, 5):
                f.put(x + i, 14, (112, 58, 40))
    # front lip of brick, then the riveted steel shell on its cradle
    for x in range(0, 27):
        f.put(x, 18, BR[3] if x % 4 == 1 else BR[0])
        f.put(x, 19, BR[3] if x % 4 == 3 else BR[1])
    f.rect(0, 20, 26, 28, ST[2])
    for x in range(0, 27):
        f.put(x, 20, ST[1])
        f.put(x, 27, ST[3])
        f.put(x, 28, ST[4])
    for x in (0, 8, 17, 25):
        f.rect(x, 20, x + 1, 28, ST[3])
        for y in range(20, 28):
            f.put(x, y, ST[0] if y < 22 else ST[1])
    for x in (4, 12, 13, 21):
        f.pts(ST[0], (x, 22), (x, 25))
        f.pts(ST[4], (x, 23), (x, 26))
    f.rect(1, 29, 5, 30, ST[4])
    f.rect(21, 29, 25, 30, ST[4])
    f.pts(ST[3], (1, 29), (2, 29), (3, 29), (21, 29), (22, 29), (23, 29))
    # cathode collector bar poking out of the shell
    f.rect(26, 23, 28, 25, ST[1])
    f.pts(ST[3], (26, 25), (27, 25), (28, 25))
    f.outline(STO)
    # thick copper cables: bus bar to the floor, collector bar to the floor
    c = Frame()
    for y in range(4, 22):
        c.put(29, y, CU[0] if y % 4 else CU[1])
        c.put(30, y, CU[1] if y % 4 else CU[2])
    c.pts(CU[1], (28, 3), (28, 4), (29, 3))
    c.pts(CU[0], (28, 3))
    c.pts(CU[1], (30, 22), (31, 22), (31, 23), (30, 23))
    c.pts(CU[0], (30, 22))
    c.pts(CU[2], (31, 23))
    c.outline(CU[3])
    f.over(c)
    c = Frame()
    for x, y in ((29, 24), (30, 25), (30, 26), (30, 27), (30, 28), (31, 29)):
        c.put(x, y, CU[0])
        c.put(x, y + 1, CU[1])
    c.pts(CU[1], (31, 28))
    c.pts(CU[2], (31, 30))
    c.outline(CU[3])
    f.over(c)
    if on:
        for x, y, a in FUMES[frame]:
            f.put(x, y, FUME, a)
            f.put(x, y - 1, FUME, a // 2)
    return f


# ------------------------------------------------------------------ red mud

def red_mud():
    f = Frame()
    cx, cy = 15.5, 21.5
    body = set()
    for y in range(32):
        for x in range(32):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            ang = math.atan2(dy, dx)
            wob = 1.0 + 0.13 * math.sin(3 * ang + 0.6) + 0.08 * math.sin(5 * ang + 2.0)
            if (dx / (11.0 * wob)) ** 2 + (dy / (5.2 * wob)) ** 2 <= 1.0:
                body.add((x, y))
    body |= {(27, 26), (28, 26), (27, 27), (3, 17), (4, 17), (25, 15)}
    for (x, y) in body:
        rim = any(n not in body for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))
        low = (x, y + 1) not in body or (x + 1, y) not in body
        if rim:
            f.put(x, y, RM[4] if low else RM[3], 235)
        else:
            r = noise(x, y, 21)
            f.put(x, y, RM[3] if r > 0.83 else RM[1] if r < 0.12 else RM[2])
    # wet sheen along the upper left, a few ripples
    f.tint(RM[1], (8, 19), (9, 18), (10, 18), (11, 18), (12, 17), (13, 17), (14, 17),
           (17, 21), (18, 21), (19, 21), (20, 22), (11, 23), (12, 23), (13, 24))
    f.tint(RM[0], (10, 19), (11, 19), (12, 18), (18, 22), (22, 20))
    f.tint(RM[3], (14, 22), (15, 22), (16, 23), (20, 19), (21, 19), (9, 21), (10, 22))
    return f


# -------------------------------------------------------------------- sheet

def build():
    """name -> (frames, delays); delays is None for a still state."""
    states = {}
    for name in ORE_PILES:
        states[name] = ([ore(name)], None)
    for base, draw in (('alumina', alumina), ('sheet-aluminium', ingots),
                       ('ceramic_tile', tiles), ('composite_panel', panels)):
        for n in (1, 2, 3, 4):
            states[base + ('' if n == 1 else '_%d' % n)] = ([draw(n)], None)
    states['digester'] = ([digester()], None)
    states['digester_on'] = ([digester(i) for i in range(4)], (2, 2, 2, 2))
    states['reduction_pot'] = ([reduction_pot()], None)
    states['reduction_pot_on'] = ([reduction_pot(i) for i in range(4)], (3, 2, 3, 2))
    states['red_mud'] = ([red_mud()], None)
    return states


def render(states):
    frames = [fr for group, _ in states.values() for fr in group]
    rows = -(-len(frames) // COLUMNS)
    sheet = Image.new('RGBA', (32 * COLUMNS, 32 * rows), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(fr.image(), (i % COLUMNS * 32, i // COLUMNS * 32))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, (group, delays) in states.items():
        text += 'state = "%s"\n\tdirs = 1\n\tframes = %d\n' % (name, len(group))
        if delays:
            text += '\tdelay = %s\n' % ','.join(str(d) for d in delays)
    text += '# END DMI\n'
    return sheet, text


def write_dmi(path, states):
    sheet, text = render(states)
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta)


def check(path, states):
    sheet, text = render(states)
    if not Path(path).is_file():
        return ['%s is missing' % path]
    with Image.open(path) as im:
        have_text = im.info.get('Description', '')
        have = im.convert('RGBA')
    problems = []
    if have_text != text:
        problems.append('state metadata differs')
    if have.size != sheet.size or have.tobytes() != sheet.tobytes():
        problems.append('pixels differ')
    return problems


# ------------------------------------------------------------------ preview

def ground(colour, seed):
    tile_ = Image.new('RGBA', (32, 32), colour + (255,))
    for y in range(32):
        for x in range(32):
            n = noise(x, y, seed)
            if n > 0.86 or n < 0.1:
                d = 9 if n > 0.5 else -9
                tile_.putpixel((x, y), tuple(max(0, min(255, v + d)) for v in colour) + (255,))
    return tile_


def neighbour(path, name):
    """One state of an existing sheet, for the comparison strip only."""
    with Image.open(ROOT / path) as im:
        text = im.info['Description']
        im = im.convert('RGBA')
    index = 0
    for m in re.finditer(r'state = "(.*?)"\n\tdirs = (\d+)\n\tframes = (\d+)', text):
        if m.group(1) == name:
            break
        index += int(m.group(2)) * int(m.group(3))
    else:
        return None
    cols = im.width // 32
    x, y = index % cols * 32, index // cols * 32
    return im.crop((x, y, x + 32, y + 32))


def write_preview(path, states, scale=4):
    """Each state at 4x on a grass-grey floor with the 1x sprite on two
    floors beside it; animations as a row of frames; neighbours last."""
    cell = 32 * scale
    pad, label = 10, 16
    box_w, box_h = cell + 40 + pad * 2, label + cell + pad * 2
    rows = [
        [(n, [states[n][0][0].image()]) for n in ORE_PILES],
        [(n, [states[n][0][0].image()]) for n in states if n.startswith('alumina')],
        [(n, [states[n][0][0].image()]) for n in states if n.startswith('sheet-')],
        [(n, [states[n][0][0].image()]) for n in states if n.startswith('ceramic_')],
        [(n, [states[n][0][0].image()]) for n in states if n.startswith('composite_')],
        [('digester', [states['digester'][0][0].image()]),
         ('digester_on (4 frames, delay 2,2,2,2)', [fr.image() for fr in states['digester_on'][0]])],
        [('reduction_pot', [states['reduction_pot'][0][0].image()]),
         ('reduction_pot_on (4 frames, delay 3,2,3,2)', [fr.image() for fr in states['reduction_pot_on'][0]])],
        [('red_mud', [states['red_mud'][0][0].image()])],
    ]
    refs = []
    for sheet_path, name in (('icons/obj/mining.dmi', 'ore_iron_2'), ('icons/obj/mining.dmi', 'ore_copper_2'),
                             ('icons/obj/mining.dmi', 'ore_tin_2'), ('icons/obj/materials.dmi', 'sheet-tin'),
                             ('icons/obj/materials.dmi', 'sheet-iron'), ('icons/obj/materials.dmi', 'sheet-silver_4')):
        im = neighbour(sheet_path, name)
        if im is not None:
            refs.append(('existing: ' + name, [im]))
    rows[-1].extend(refs[:4])
    rows.append(refs[4:] + [('all new items at 1x', None)])
    wide = max(sum(max(1, len(frames or [0, 0, 0])) for _, frames in row) for row in rows)
    sheet = Image.new('RGBA', (box_w * max(5, wide), box_h * len(rows)), DARK + (255,))
    draw = ImageDraw.Draw(sheet)
    floors = [ground(c, 31 + i) for i, c in enumerate(FLOORS)]
    for j, row in enumerate(rows):
        ox = pad
        for name, frames in row:
            oy = j * box_h + pad
            draw.text((ox, oy), name, fill=(232, 228, 214))
            if frames is None:
                # everything side by side at true size, as it would lie on the floor
                x = ox
                for n, (group, _) in states.items():
                    if n.endswith('_on'):
                        continue
                    t = floors[0].copy()
                    t.alpha_composite(group[0].image())
                    sheet.alpha_composite(t, (x, oy + label + (0 if x < ox + 32 * 12 else 0)))
                    x += 32
                    if x >= ox + 32 * 12:
                        x, oy = ox, oy + 34
                ox += box_w * 3
                continue
            for k, im in enumerate(frames):
                t = floors[0].copy()
                t.alpha_composite(im)
                sheet.alpha_composite(t.resize((cell, cell), Image.NEAREST), (ox, oy + label))
                if k == len(frames) - 1:
                    for i, floor in enumerate(floors):
                        t = floor.copy()
                        t.alpha_composite(im)
                        sheet.alpha_composite(t, (ox + cell + 6, oy + label + i * 38))
                    ox += box_w
                else:
                    ox += cell + 4
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.convert('RGB').save(path)


def main():
    states = build()
    if '--check' in sys.argv:
        problems = check(DMI, states)
        for p in problems:
            print('aluminium.dmi: ' + p)
        if problems:
            sys.exit(1)
        print('aluminium.dmi matches (%d states, %d frames)'
              % (len(states), sum(len(g) for g, _ in states.values())))
    else:
        write_dmi(DMI, states)
    if '--preview' in sys.argv[1:-1]:
        write_preview(sys.argv[sys.argv.index('--preview') + 1], states)


if __name__ == '__main__':
    main()
