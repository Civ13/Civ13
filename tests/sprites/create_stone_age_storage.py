"""Hand-placed 32px Stone Age storage: the coiled grass basket, the fired clay
storage jar and its unfired blank, the hollowed log chest, the grass-lined
storage pit, the rolled bundle of pit lining and the pot-in-pot zeer cooler
(dry and wet, empty and full, and unfired). Every pixel is placed by this
script from a fixed palette (Pillow only); no external or generated artwork.
The outline, wood, cord, stone and earth tones are the ones
create_stone_age_traps.py uses for icons/obj/stone_age_traps.dmi and the straw
and hide ramps are the ones in create_primitive_carrying.py, lit from the
upper left. The storage pit is drawn without a tile background so the floor
shows around it.

Run with Pillow to reproduce icons/obj/stone_age_storage.dmi. `--preview <png>`
also writes a labelled review sheet (4x, on grass, dirt and a wood floor).
Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]

OUT = (62, 49, 34)
# dry grass and straw coils, light to dark
G = [(234, 216, 142), (200, 178, 100), (160, 138, 70), (114, 98, 48), (66, 54, 28)]
# raw hide
HD = [(216, 172, 122), (182, 136, 92), (144, 102, 66), (102, 70, 44), (56, 38, 24)]
# split and hollowed wood
WD = [(198, 151, 106), (168, 122, 76), (122, 84, 50), (92, 61, 34)]
# pale peeled sticks
PW = [(214, 180, 132), (184, 146, 98), (140, 104, 64)]
# bark
BK = [(150, 118, 86), (122, 92, 64), (96, 70, 48), (74, 53, 36), (54, 38, 27)]
# plant-fibre cord
CD = [(205, 185, 143), (156, 131, 96), (112, 90, 62)]
# river stones
ST = [(170, 168, 160), (136, 134, 128), (104, 102, 98), (76, 74, 72)]
# fired terracotta
TC = [(228, 146, 98), (200, 112, 70), (164, 84, 52), (124, 60, 38), (88, 42, 28)]
# wet unfired clay
UC = [(184, 170, 150), (152, 137, 118), (120, 106, 90), (90, 79, 66), (64, 55, 46)]
# dug earth and the dark of a hollow
ER = [(156, 118, 78), (128, 94, 60), (100, 72, 46), (74, 52, 34)]
PD = [(60, 43, 30), (42, 30, 22), (26, 19, 15)]
# stored goods
GRAIN = [(240, 204, 104), (204, 158, 62), (150, 108, 40)]
GOURD = [(176, 190, 104), (134, 154, 76), (96, 116, 56), (66, 84, 42)]
LF = [(122, 156, 70), (90, 126, 52), (62, 94, 40)]
# preview backgrounds
GRASS = (86, 128, 62)
DIRT = (134, 102, 70)
WOOD = (150, 112, 72)
DARK = (30, 32, 36)


def noise(x, y, seed=0):
    """A fixed 0..1 value per pixel, so the sheet is reproducible."""
    n = (x * 374761393 + y * 668265263 + seed * 2147483647) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def clamp(i, pal):
    return pal[max(0, min(len(pal) - 1, i))]


class Frame:
    def __init__(self):
        self.px = {}

    def put(self, x, y, c, a=255):
        if 0 <= x < 32 and 0 <= y < 32:
            self.px[(x, y)] = (c[0], c[1], c[2], a)

    def pts(self, c, *points):
        for x, y in points:
            self.put(x, y, c)

    def outline(self, c=OUT, a=255):
        """Ring every drawn shape with the dark outline colour."""
        edge = set()
        for (x, y) in self.px:
            for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if n not in self.px:
                    edge.add(n)
        for x, y in edge:
            self.put(x, y, c, a)

    def over(self, other):
        """Lay `other` on top of this frame."""
        self.px.update(other.px)

    def under(self, other):
        """Slip `other` beneath this frame."""
        for k, v in other.px.items():
            self.px.setdefault(k, v)

    def image(self):
        im = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c)
        return im


def bar(f, p0, p1, half, shade):
    """A straight band from p0 to p1. `shade(s, t)` picks the colour, s running
    from -1 on the lit upper-left edge to +1 on the shaded edge, t from 0 to 1
    along the way."""
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
            d = px * nx + py * ny
            if 0.0 <= t <= 1.0 and abs(d) <= half:
                c = shade(d / half, t)
                if c is not None:
                    f.put(x, y, c)


def three(pal, a=-0.34, b=0.34):
    """Light edge, middle, shaded edge."""
    return lambda s, t: pal[0] if s < a else pal[1] if s < b else pal[2]


def blob(f, cx, cy, rx, ry, pal, lx=-0.45, ly=-0.5):
    """A rounded lump shaded in bands away from a light spot."""
    for y in range(32):
        for x in range(32):
            u, v = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if u * u + v * v <= 1.0:
                d = math.hypot(u - lx, v - ly)
                f.put(x, y, pal[0] if d < 0.42 else pal[1] if d < 0.95 else pal[2] if d < 1.4 else pal[3])


def trace(f, c, *points):
    """A one-pixel cord through the given points."""
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            f.put(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), c)


def shadow(points, a=70):
    f = Frame()
    for x, y in points:
        f.put(x, y, (20, 16, 12), a)
    return f


# ------------------------------------------------------------------- basket

BASKET_HW = {14: 12.0, 15: 12.6, 16: 13.0, 17: 13.0, 18: 13.0, 19: 13.0, 20: 12.8, 21: 12.5, 22: 12.0, 23: 11.5,
             24: 10.8, 25: 10.0, 26: 8.8, 27: 7.0}
RIM = (16.0, 13.5, 12.6, 4.0)


def rim_r(x, y):
    cx, cy, rx, ry = RIM
    return math.hypot((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry)


def basket(full=False):
    """A wide, low basket of grass coils sewn in a spiral; `full` heaps it with
    grain, a gourd and a tied bundle."""
    f = Frame()
    # the coiled wall: two-pixel coils sagging toward the viewer, stitched across
    for y, hw in BASKET_HW.items():
        for x in range(32):
            dx = x + 0.5 - 16.0
            if abs(dx) > hw:
                continue
            row = y - 14 - 1.7 * (1.0 - (dx / 13.2) ** 2)
            k, lit = int(math.floor(row / 2.0)), (row % 2.0) < 1.0
            s = dx / hw
            i = (1 if lit else 2) + (-1 if s < -0.35 else 1 if s > 0.5 else 0) + (1 if s > 0.84 else 0)
            if lit and (x + k * 2) % 4 == 0:
                i += 1                                                           # the stitch over the coil
            c = clamp(i, G[:4])
            if k == 2 and lit and (x + k * 2) % 4 != 0:
                c = HD[2] if s < 0.5 else HD[3]                                   # one coil wrapped in dyed bark
            f.put(x, y, c)
    # the mouth: a bound rim coil round the dark inside
    ring = {}
    for y in range(9, 18):
        for x in range(32):
            r = rim_r(x, y)
            if r > 1.0:
                continue
            if r > 0.7:
                s = (x + 0.5 - 16.0) / 12.6
                i = (0 if y >= 14 else 1) + (1 if s > 0.45 else 0) + (1 if (x + (y >= 14)) % 3 == 0 else 0)
                ring[(x, y)] = clamp(i, G[:4])
            elif y <= 11:
                f.put(x, y, G[3] if (x % 4) else G[4])                            # the far wall inside
            else:
                f.put(x, y, G[4] if y == 12 and x % 3 else PD[0] if noise(x, y, 2) > 0.2 else PD[1])
    for (x, y), c in ring.items():
        f.put(x, y, c)
    f.outline()
    if full:
        c = Frame()
        # threshed grain heaped to the rim
        for y in range(9, 16):
            for x in range(32):
                if rim_r(x, y) <= 0.74:
                    n = noise(x, y, 7)
                    c.put(x, y, GRAIN[0] if n > 0.7 else GRAIN[2] if n < 0.25 else GRAIN[1])
        # ears of grain standing at the left
        for (ex, ey, lean) in ((6, 3, -1), (9, 2, 0), (12, 4, 1)):
            for j in range(5):
                c.put(ex, ey + j, GRAIN[0] if j % 2 == 0 else GRAIN[1])
                c.put(ex + 1, ey + j, GRAIN[1] if j % 2 == 0 else GRAIN[2])
            c.pts(GRAIN[0], (ex + (lean < 0), ey - 1))
            for j in range(5, 12 - (ey > 3)):
                c.put(ex + (1 if lean > 0 and j > 7 else 0) + (1 if lean < 0 and j > 8 else 0), ey + j, G[1] if j % 3 else G[2])
        # a gourd
        blob(c, 18.5, 9.5, 4.6, 4.4, GOURD)
        c.pts(GOURD[0], (16, 7), (17, 7))
        c.pts(BK[2], (19, 4), (20, 3), (20, 4)); c.pts(BK[1], (19, 5), (18, 5))
        # a hide bundle tied with cord
        blob(c, 25.0, 11.5, 3.4, 3.2, HD)
        c.pts(CD[0], (23, 10), (24, 11), (25, 12)); c.pts(CD[1], (26, 13), (27, 13), (25, 9), (26, 9))
        c.pts(HD[1], (25, 7), (26, 7)); c.pts(HD[2], (26, 8), (27, 7))
        c.outline()
        f.over(c)
        for (x, y), col in ring.items():                                         # the near rim laps the goods
            if y >= 14:
                f.put(x, y, col)
        for (x, y) in ring:
            if y >= 14 and (x, y - 1) not in ring and (x, y - 1) in c.px and rim_r(x, y - 1) > 0.74:
                f.put(x, y - 1, OUT)
    f.under(shadow([(x, 29) for x in range(9, 25)] + [(x, 28) for x in range(24, 28)] + [(27, 27), (28, 27), (28, 26)]))
    return f


# ---------------------------------------------------------------------- jar

JAR = ((3, 4.6), (4, 4.9), (5, 4.9), (6, 4.2), (7, 4.0), (8, 5.0), (9, 7.2), (10, 8.8), (11, 9.8), (13, 10.6),
       (17, 10.6), (20, 9.7), (23, 8.0), (26, 5.9), (28, 4.6), (29, 4.1))


def jar_hw(y):
    for (y0, w0), (y1, w1) in zip(JAR, JAR[1:]):
        if y0 <= y <= y1:
            return w0 + (w1 - w0) * (y - y0) / (y1 - y0)
    return 0.0


def jar(pal, stopper=False, wet=False):
    """The tall storage jar: flared lip, short neck, wide shoulders drawn in to
    a narrow foot, with an incised zigzag band round the shoulder."""
    f = Frame()
    idx = {}
    for y in range(3, 30):
        hw = jar_hw(y)
        for x in range(32):
            dx = x + 0.5 - 16.0
            if abs(dx) > hw:
                continue
            s = dx / hw + (noise(x, y, 5) - 0.5) * 0.12
            i = 2 if s < -0.8 else 1 if s < -0.52 else 0 if s < -0.2 else 1 if s < 0.26 else 2 if s < 0.6 else 3 if s < 0.87 else 4
            if y in (6, 7) or y >= 28:
                i += 1                                                           # under the lip, and the foot
            idx[(x, y)] = min(i, 4)
    # the incised band: two lines and a zigzag between, following the curve
    for (x, y) in list(idx):
        sag = int(round(1.4 * (1.0 - ((x + 0.5 - 16.0) / 10.6) ** 2)))
        line = y - sag
        if line in (11, 15) or (line in (12, 13, 14) and line - 12 == (0, 1, 2, 1)[x % 4]):
            idx[(x, y)] = min(idx[(x, y)] + 2, 4)
    for (x, y), i in idx.items():
        f.put(x, y, pal[i])
    if wet:                                                                       # a wet shine on the raw clay
        f.pts((218, 208, 190), (10, 15), (10, 16), (11, 17), (12, 9), (11, 20), (13, 5))
        f.pts(pal[3], (20, 22), (21, 18), (19, 25), (22, 16))                     # finger drags
    # the open mouth
    for x in range(13, 19):
        f.put(x, 2, pal[1] if x < 17 else pal[2])
        f.put(x, 3, pal[4]); f.put(x, 4, PD[1])
    f.pts(pal[0], (11, 3), (12, 3), (11, 4), (12, 4)); f.pts(pal[2], (19, 3), (20, 3), (20, 4)); f.pts(pal[1], (19, 4))
    f.pts(PD[0], (13, 4), (18, 4))
    if stopper:
        # a hide cover over a wooden plug, bound under the lip with cord
        for y, (x0, x1) in {1: (13, 18), 2: (11, 20), 3: (10, 21), 4: (10, 21), 5: (10, 21), 7: (10, 21)}.items():
            for x in range(x0, x1 + 1):
                if y == 7 and (noise(x, y, 9) < 0.3 or x in (10, 21)) and x not in (13, 14, 18):
                    continue
                i = (1 if x < 12 else 0 if x < 15 else 1 if x < 18 else 2 if x < 20 else 3) + (1 if y in (5, 7) else 0)
                f.put(x, y, clamp(i, HD[:4]))
        f.pts(HD[0], (14, 1), (15, 1), (13, 2)); f.pts(HD[2], (16, 3), (17, 4), (12, 4))    # folds over the plug
        f.pts(HD[3], (12, 8), (16, 8), (19, 8))
        for x in range(11, 21):
            f.put(x, 6, CD[0] if x < 15 else CD[1] if x < 19 else CD[2])
        f.pts(CD[0], (16, 6), (17, 7)); f.pts(CD[1], (17, 6), (18, 7), (18, 8), (16, 8), (15, 9), (19, 9), (19, 10))
    f.outline()
    f.under(shadow([(x, 30) for x in range(20, 25)] + [(x, 29) for x in range(21, 26)] + [(22, 28), (23, 28)]))
    return f


# ----------------------------------------------------------------- zeer pot

# dry and damp sand packed between the two pots
SAND = [(240, 222, 172), (216, 194, 140), (184, 160, 108), (148, 124, 80)]
WSAND = [(172, 142, 98), (142, 114, 76), (112, 88, 58), (84, 64, 42)]
# terracotta dark with the water soaking through it, and the beads standing on it
WTC = [(168, 100, 80), (138, 76, 62), (108, 58, 50), (82, 44, 40), (58, 32, 30)]
BEAD = [(236, 244, 246), (176, 204, 216)]
# a damp woven cloth
CL = [(226, 222, 204), (192, 190, 172), (154, 154, 140), (116, 118, 108), (82, 84, 78)]

ZEER = ((13, 13.0), (15, 13.8), (18, 14.0), (21, 13.4), (24, 11.8), (27, 9.4), (29, 7.4))
ZO = (16.0, 13.0, 13.4, 5.5)        # the outer pot's mouth
ZI = (16.0, 11.5, 8.2, 3.1)         # the inner pot's mouth


def zeer_hw(y):
    for (y0, w0), (y1, w1) in zip(ZEER, ZEER[1:]):
        if y0 <= y <= y1:
            return w0 + (w1 - w0) * (y - y0) / (y1 - y0)
    return 0.0


def ell(x, y, e, dy=0.0):
    cx, cy, rx, ry = e
    return math.hypot((x + 0.5 - cx) / rx, (y + 0.5 - cy - dy) / ry)


def zeer(pal, sand=None, cover=False, full=False, wet=False, raw=False):
    """The pot-in-pot cooler: a wide, low pot with a smaller one nested in its
    mouth. `sand` packs the gap between the rims, `cover` lays a damp cloth
    over half the inner mouth, `full` shows the food under it, `wet` soaks the
    outer pot and `raw` is the unfired blank with an empty gap."""
    f = Frame()
    # the outer pot's wall
    for y in range(13, 30):
        hw = zeer_hw(y)
        for x in range(32):
            dx = x + 0.5 - 16.0
            if abs(dx) > hw:
                continue
            s = dx / hw + (noise(x, y, 51) - 0.5) * 0.12
            i = 2 if s < -0.84 else 1 if s < -0.56 else 0 if s < -0.24 else 1 if s < 0.24 else 2 if s < 0.6 else 3 if s < 0.87 else 4
            if y >= 28 or ell(x, y, ZO, 1.2) <= 1.0:
                i += 1                                                           # the foot, and under the rim
            sag = int(round(1.6 * (1.0 - (dx / 13.9) ** 2)))
            if y - sag in (21, 23):
                i += 2                                                           # two incised lines round the belly
            i = min(i, 4)
            c = pal[i]
            if wet:
                # the water comes through from the sand: dark below a ragged line, drier at the rim
                tide = 15.0 + 2.6 * noise(x // 3, 0, 52) + (1.5 if abs(dx) > 9 else 0)
                if y > tide and not (noise(x // 3, y // 2, 53) > 0.9 and y < 21):
                    c = WTC[i]
                elif y > tide - 1.0:
                    c = pal[min(i + 1, 4)]
            f.put(x, y, c)
    if wet:
        f.pts(BEAD[0], (8, 22), (13, 25), (19, 21), (24, 24))                    # beads of water on the outside
        f.pts(BEAD[1], (8, 23), (13, 26), (19, 22), (24, 25), (17, 27), (5, 23), (11, 21))
    if raw:
        f.pts((218, 208, 190), (7, 20), (7, 21), (8, 24), (9, 26))               # a wet shine on the raw clay
        f.pts(pal[3], (20, 25), (22, 20), (19, 27), (23, 24))                    # finger drags
    # the outer mouth: its rim, and the sand (or the empty gap) inside
    fill = sand
    for y in range(7, 19):
        for x in range(32):
            r = ell(x, y, ZO)
            if r > 1.0:
                continue
            dx = x + 0.5 - 16.0
            if r > 0.82:
                i = (0 if y >= 14 else 1) + (1 if dx > 5.5 else 0) + (1 if dx > 10.5 else 0) + (1 if dx < -11.0 else 0)
                f.put(x, y, clamp(i, pal))
            elif fill is None:
                f.put(x, y, pal[4] if y <= 9 else PD[0] if noise(x, y, 54) > 0.25 else PD[1])
            elif ell(x, y, ZO, -1.0) > 0.82 and y < 13:
                f.put(x, y, pal[4])          # the shade of the far rim on the sand
            else:
                n = noise(x, y, 55)
                i = (0 if n > 0.72 else 2 if n < 0.2 else 1) + (1 if dx > 8.0 else 0)
                f.put(x, y, clamp(i, fill))
    # the inner pot: a short stretch of its wall standing out of the sand, then its rim and its dark inside
    for y in range(7, 19):
        for x in range(32):
            dx = x + 0.5 - 16.0
            if ell(x, y, ZI) > 1.0 and ell(x, y, ZI, 1.0) <= 1.0:
                f.put(x, y, pal[2] if dx < 3.0 else pal[3])
            elif ell(x, y, ZI) > 1.0 and ell(x, y, ZI, 2.0) <= 1.0 and fill is not None:
                f.put(x, y, fill[3] if wet else fill[2])                         # its shadow on the sand
    inside = set()
    for y in range(7, 16):
        for x in range(32):
            r = ell(x, y, ZI)
            if r > 1.0:
                continue
            dx = x + 0.5 - 16.0
            if r > 0.76:
                i = (0 if y >= 12 else 1) + (1 if dx > 3.5 else 0) + (1 if dx > 7.0 else 0)
                f.put(x, y, clamp(i, pal))
            else:
                inside.add((x, y))
                f.put(x, y, pal[3] if y <= 9 else pal[4] if y == 10 and x % 3 else PD[0] if noise(x, y, 56) > 0.2 else PD[1])
    f.outline()
    if full:
        # a gourd, greens and a root sitting in the open half
        g = Frame()
        blob(g, 12.0, 9.6, 3.0, 2.9, GOURD)
        g.pts(BK[2], (12, 5), (12, 6)); g.pts(BK[1], (13, 5))
        g.pts(LF[0], (8, 9), (9, 8), (16, 8)); g.pts(LF[1], (8, 10), (9, 9), (9, 10), (10, 11), (16, 9), (17, 9))
        g.pts(LF[2], (9, 11), (10, 12), (17, 10), (16, 10))
        g.pts(GRAIN[0], (14, 12), (15, 12)); g.pts(GRAIN[1], (13, 12), (15, 11), (16, 11), (16, 12)); g.pts(GRAIN[2], (14, 13), (15, 13))
        keep = {k: v for k, v in g.px.items() if k in inside or (k[1] <= 9 and ell(k[0], k[1], ZI) <= 1.25)}
        g.px = keep
        g.outline()
        g.px = {k: v for k, v in g.px.items() if k in keep or k[1] <= 9 or k in inside}
        f.over(g)
    if cover:
        # the cloth: laid over the right half of the mouth, its hem hanging onto the sand
        c = Frame()
        for y in range(5, 19):
            for x in range(32):
                dx = x + 0.5 - 16.0
                edge = 0.2 + (y - 11) * 0.3                                      # the folded-back edge, slanting
                r = ell(x, y, (17.2, 10.9, 8.0, 3.5))
                hem = dx > 6.0 and r > 1.0 and ell(x, y, (17.2, 10.9, 8.0, 3.5), 1.0 + (x % 3 == 0)) <= 1.0
                if dx < edge or (r > 1.0 and not hem):
                    continue
                d = math.hypot((dx - 2.0) / 8.0, (y + 0.5 - 9.0) / 4.0)
                i = (0 if d < 0.45 else 1 if d < 0.95 else 2) + (1 if hem else 0)
                col = clamp(i, CL[:4])
                if int(dx - edge) in (3, 6):
                    col = clamp(i + 1, HD[1:])                                    # dyed stripes in the weave
                if dx < edge + 1.0:
                    col = CL[0]                                                   # the rolled edge catches the light
                c.put(x, y, col)
        c.pts(CL[2], (22, 10), (23, 11))                       # creases
        c.outline()
        f.over(c)
        for (x, y) in list(c.px):                                                 # its shadow on the open mouth
            if c.px[(x, y)][:3] == OUT and (x - 1, y) in inside and (x - 1, y) not in c.px and not full:
                f.put(x - 1, y, PD[2])
    f.under(shadow([(x, 30) for x in range(11, 25)] + [(x, 29) for x in range(23, 28)] + [(27, 28), (28, 28), (28, 27), (29, 27)]))
    return f


# ---------------------------------------------------------------- log chest

def log_top(x, y, grow=0.0):
    """The split face of the log: a long flat with rounded ends."""
    u, v = (x + 0.5 - 16.0) / (13.8 + grow), (y + 0.5 - 13.0) / (4.6 + grow)
    return abs(u) ** 4 + abs(v) ** 2.2


def log_chest(full=False):
    """A half log lying bark-down in its bark, the split face hollowed into a
    trough; `full` ties a hide over the hollow."""
    f = Frame()
    for x in range(32):
        tops = [y for y in range(32) if log_top(x, y) <= 1.0]
        if not tops:
            continue
        # the bark side below the split face
        for d in range(1, 10):
            y = tops[-1] + d
            i = 1 if d <= 2 else 2 if d <= 5 else 3 if d <= 7 else 4
            n = noise(x // 3, y, 21)
            if n > 0.72:
                i += 1                                                           # furrows along the grain
            elif n < 0.14:
                i -= 1
            if abs(x + 0.5 - 16.0) > 12.2:
                i += 1
            f.put(x, y, clamp(i, BK))
        for y in tops:
            r = log_top(x, y)
            # the hollow, with the far wall catching the light
            hu, hv = (x + 0.5 - 16.0) / 11.4, (y + 0.5 - 13.2) / 2.9
            if abs(hu) ** 4 + abs(hv) ** 2.2 <= 1.0:
                if hv < -0.45:
                    c = WD[2] if noise(x, y, 4) > 0.25 else WD[1]
                elif hv < 0.05:
                    c = WD[3]
                else:
                    c = PD[0] if noise(x // 2, y, 6) > 0.3 else PD[1]
                if hu < -0.86 and hv >= -0.45:
                    c = PD[1]
            elif r > 0.8:
                c = BK[1] if y < 13 else BK[2]                                    # the bark edge round the face
            else:
                c = WD[0] if noise(x // 4, y, 8) > 0.3 else WD[1]                 # pale split wood
                if y >= 16:
                    c = WD[1]
            f.put(x, y, c)
    f.pts(BK[0], (6, 20), (7, 20), (13, 19), (14, 19), (21, 20), (22, 20))        # lit bark ridges
    f.pts(BK[4], (10, 23), (11, 23), (12, 24), (19, 22), (20, 22))                # a crack
    f.pts(LF[1], (5, 22), (6, 23), (25, 21)); f.pts(LF[2], (5, 23), (26, 22))     # moss
    if full:
        # the hide lid, sagging a little over the front edge
        lid = set()
        for y in range(32):
            for x in range(32):
                r = log_top(x, y, 0.3)
                droop = (r > 1.0 and log_top(x, y - 1 - (noise(x // 3, 0, 14) > 0.6), 0.3) <= 1.0 and y > 13
                         and abs(x + 0.5 - 16.0) < 12.5)
                if r <= 1.0 or droop:
                    u, v = (x + 0.5 - 16.0) / 14.3, (y + 0.5 - 13.0) / 5.1
                    d = math.hypot(u + 0.45, v + 0.6)
                    i = 0 if d < 0.75 else 1 if d < 1.35 else 2
                    if droop:
                        i = 3
                    if noise(x, y, 17) > 0.92:
                        i += 1
                    f.put(x, y, clamp(i, HD[:4]))
                    lid.add((x, y))
        f.pts(HD[2], (11, 11), (12, 12), (13, 12), (19, 14), (20, 15), (21, 15))  # creases
        for x in range(32):                                                       # the hem and its shadow on the bark
            low = max((y for y in range(32) if log_top(x, y, 0.3) <= 1.0 or (x, y) in lid), default=None)
            if low is not None and low > 13:
                f.put(x, low, HD[3])
                if (x, low + 1) in f.px:
                    f.put(x, low + 1, BK[4])
        # two cords right round the log, knotted on top
        for cx in (8, 23):
            for y in range(32):
                if (cx, y) in f.px:
                    f.put(cx, y, CD[0] if y < 17 else CD[1])
                    f.put(cx + 1, y, CD[1] if y < 17 else CD[2])
            f.pts(CD[0], (cx - 1, 12), (cx, 11)); f.pts(CD[1], (cx + 2, 12), (cx + 2, 13), (cx - 1, 13), (cx - 2, 14))
        trace(f, CD[1], (10, 13), (22, 13)); f.pts(CD[0], (12, 13), (15, 13), (16, 13), (19, 13))
    f.outline()
    f.under(shadow([(x, 28) for x in range(7, 29)] + [(x, 27) for x in range(27, 30)] + [(29, 26), (30, 26), (30, 25)]))
    return f


# -------------------------------------------------------------- storage pit

PIT = (16.0, 19.0)


def pit_r(x, y, rx, ry, dy=0.0):
    return math.hypot((x + 0.5 - PIT[0]) / rx, (y + 0.5 - PIT[1] - dy) / ry)


def pit_rim(f):
    """The ring of dug earth, ragged at the outside, lit on the upper left."""
    for y in range(32):
        for x in range(32):
            r = pit_r(x, y, 14.6, 9.6) + (noise(x // 2, y // 2, 11) - 0.5) * 0.1
            if r > 1.0:
                continue
            n = noise(x, y, 12)
            if r > 0.92:
                if n > 0.4:
                    f.put(x, y, ER[3] if n > 0.6 else ER[2])
                continue
            lit = (x - 16) + (y - 19) * 1.5 < -4
            i = (1 if lit else 2) + (1 if r > 0.84 else 0) + (1 if n > 0.82 else -1 if n < 0.12 else 0)
            f.put(x, y, clamp(i, ER))


def straw_ring(f, r0, r1, seed, rx=11.2, ry=7.0):
    """Dry grass lapping over the lip of the pit."""
    for y in range(32):
        for x in range(32):
            r = pit_r(x, y, rx, ry)
            a = math.atan2(y + 0.5 - PIT[1], x + 0.5 - PIT[0])
            strand = int((a + math.pi) * 9.0)
            reach = r1 + (noise(strand, 0, seed) - 0.5) * 0.2                     # uneven straw ends
            if r0 <= r <= reach:
                n = noise(strand, int(r * 9), seed + 1)
                i = (0 if n > 0.6 else 1 if n > 0.22 else 2) + (1 if (x - 16) + (y - 19) > 6 else 0)
                f.put(x, y, clamp(i, G[:4]))


def storage_pit():
    """The open pit from above and in front: the far wall and the floor show,
    both lined with dry grass."""
    f = Frame()
    pit_rim(f)
    for y in range(32):
        for x in range(32):
            if pit_r(x, y, 11.2, 7.0) > 0.9:
                continue
            strand = x + (noise(x, 0, 23) > 0.5)
            if pit_r(x, y, 8.4, 4.2, 2.2) <= 1.0:
                # the floor, in the shade of the near wall
                n = noise(x, y, 24)
                c = G[4] if n > 0.5 else PD[0] if n > 0.18 else G[3]
                if pit_r(x, y, 8.4, 4.2, 2.2) > 0.8 and y < 21:
                    c = PD[1]                                                     # where the wall meets the floor
                if (x - 16) < -3 and n > 0.3:
                    c = PD[0]
            else:
                # the lined wall: upright straw, darker going down and on the left
                depth = pit_r(x, y, 11.2, 7.0)
                n = noise(strand, y // 3, 25)
                i = (2 if depth > 0.72 else 3) + (1 if n > 0.7 else 0) + (1 if x < 9 and y > 15 else 0)
                c = clamp(i, G) if y < 22 else PD[0]
            f.put(x, y, c)
    straw_ring(f, 0.88, 1.12, 26)
    return f


def stone(f, cx, cy, rx, ry):
    s = Frame()
    blob(s, cx, cy, rx, ry, ST)
    s.outline()
    f.over(s)


def storage_pit_full():
    """Closed: a hide pegged flat over the mouth, branches across it and
    stones round the edge to hold it down."""
    f = Frame()
    pit_rim(f)
    straw_ring(f, 0.9, 1.12, 26)                                                  # the lining shows at the edge
    h = Frame()
    for y in range(32):
        for x in range(32):
            a = math.atan2(y + 0.5 - PIT[1], x + 0.5 - PIT[0])
            r = pit_r(x, y, 11.6, 7.3) + 0.07 * math.sin(a * 5.0 + 0.6)           # the uneven edge of the skin
            if r <= 1.0:
                d = math.hypot((x + 0.5 - 16.0) / 11.6 + 0.4, (y + 0.5 - 19.0) / 7.3 + 0.5)
                i = (0 if d < 0.8 else 1 if d < 1.3 else 2) + (1 if r > 0.88 else 0)
                if noise(x, y, 31) > 0.93:
                    i += 1
                h.put(x, y, clamp(i, HD[:4]))
    h.pts(HD[2], (10, 16), (11, 17), (12, 17), (19, 21), (20, 22), (21, 22))      # creases
    h.outline()
    f.over(h)
    b = Frame()
    bar(b, (6.5, 22.5), (26.5, 14.5), 0.62, three(BK[1:4], -0.1, 0.5))
    bar(b, (8.5, 14.0), (24.5, 23.5), 0.62, three(PW, -0.1, 0.5))
    b.pts(LF[1], (27, 13), (26, 13), (6, 23)); b.pts(LF[0], (27, 12))
    b.outline()
    f.over(b)
    stone(f, 4.5, 18.5, 2.3, 1.9)
    stone(f, 27.5, 19.5, 2.4, 2.0)
    stone(f, 10.0, 25.5, 2.3, 1.8)
    stone(f, 17.5, 11.8, 2.2, 1.6)
    stone(f, 22.5, 25.6, 2.0, 1.6)
    return f


# --------------------------------------------------------------- pit lining

def pit_lining():
    """A rolled bundle of dry grass tied twice with cord, the coiled end of
    the roll showing at the upper right and loose straw ends at the lower left."""
    f = Frame()
    (x0, y0), (x1, y1) = (7.5, 23.0), (22.5, 10.5)
    dx, dy = x1 - x0, y1 - y0
    ln = math.hypot(dx, dy)
    nx, ny = dy / ln, -dx / ln
    if nx + ny < 0:
        nx, ny = -nx, -ny
    half = 5.6
    ties = {}
    for y in range(32):
        for x in range(32):
            px, py = x + 0.5 - x0, y + 0.5 - y0
            t = (px * dx + py * dy) / ln                                           # pixels along the roll
            d = px * nx + py * ny
            s = d / half
            if abs(s) > 1.0:
                continue
            strand = int((s + 1.0) * 5.0)
            tail = -1.0 - 3.2 * noise(strand, 3, 41)                               # ragged straw ends
            if tail <= t <= ln:
                n = noise(strand, int(t / 3.0), 42)
                i = (0 if s < -0.6 else 1 if s < 0.0 else 2 if s < 0.6 else 3) + (1 if n > 0.6 else -1 if n < 0.12 else 0)
                f.put(x, y, clamp(i, G[:4]))
                for tie in (4.5, 13.0):
                    bow = t - tie + 0.9 * s * s
                    if abs(bow) < 0.8:
                        ties[(x, y)] = CD[0] if s < -0.2 else CD[1]
                    elif 0.8 <= bow < 1.7:
                        ties[(x, y)] = G[4]                                       # the cord bites into the roll
            # the end of the roll, coiled like a snail
            e = math.hypot((t - ln) / 3.3, s)
            if t > ln and e <= 1.0:
                turn = int(e * 3.4 + 0.3 * math.atan2(s, (t - ln) / 3.3 + 0.01))
                f.put(x, y, G[4] if e < 0.22 else (G[0], G[3])[turn % 2] if e < 0.84 else G[1])
    for (x, y), c in ties.items():
        f.put(x, y, c)
    f.outline()
    f.pts(CD[0], (9, 13), (8, 12)); f.pts(CD[1], (10, 14), (8, 14), (7, 15), (10, 12))  # knot and its ends
    f.pts(G[1], (3, 26), (4, 27)); f.pts(G[2], (9, 28), (2, 24))                 # dropped straws
    f.under(shadow([(x, 28) for x in range(10, 19)] + [(x, 27) for x in range(17, 23)] + [(x, 26) for x in range(21, 26)]))
    return f


STATES = {
    'basket': basket(),
    'basket_full': basket(True),
    'storage_jar': jar(TC),
    'storage_jar_full': jar(TC, stopper=True),
    'storage_jar_unfired': jar(UC, wet=True),
    'log_chest': log_chest(),
    'log_chest_full': log_chest(True),
    'storage_pit': storage_pit(),
    'storage_pit_full': storage_pit_full(),
    'pit_lining': pit_lining(),
    'zeer_pot_unfired': zeer(UC, raw=True),
    'zeer_pot': zeer(TC, sand=SAND, cover=True),
    'zeer_pot_full': zeer(TC, sand=SAND, cover=True, full=True),
    'zeer_pot_wet': zeer(TC, sand=WSAND, cover=True, wet=True),
    'zeer_pot_wet_full': zeer(TC, sand=WSAND, cover=True, full=True, wet=True),
}
COLUMNS = 4


def write_dmi(path, states):
    rows = -(-len(states) // COLUMNS)
    sheet = Image.new('RGBA', (32 * COLUMNS, 32 * rows), (0, 0, 0, 0))
    for i, fr in enumerate(states.values()):
        sheet.paste(fr.image(), (i % COLUMNS * 32, i // COLUMNS * 32))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name in states:
        text += 'state = "%s"\n\tdirs = 1\n\tframes = 1\n' % name
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta)


def ground(colour, seed, planks=False):
    """A flat preview floor with a little fixed speckle."""
    tile = Image.new('RGBA', (32, 32), colour + (255,))
    for y in range(32):
        for x in range(32):
            n = noise(x, y, seed)
            d = 0
            if n > 0.86 or n < 0.1:
                d = 9 if n > 0.5 else -9
            if planks and (y % 8 == 7 or (x == (5, 21, 12, 27)[y // 8] and y % 8 != 7)):
                d = -34
            if d:
                tile.putpixel((x, y), tuple(max(0, min(255, v + d)) for v in colour) + (255,))
    return tile


def write_preview(path, scale=4, per_row=4):
    """Each state at 4x on grass, dirt and a wood floor, labelled, with the 1x
    sprite on the same floors underneath."""
    cell = 32 * scale
    pad, label = 10, 16
    kinds = ('grass', 'dirt', 'wood')
    box_w, box_h = (cell + 6) * len(kinds) - 6 + pad * 2, label + cell + 44 + pad * 2
    rows = -(-len(STATES) // per_row)
    sheet = Image.new('RGBA', (box_w * per_row, box_h * rows), DARK + (255,))
    draw = ImageDraw.Draw(sheet)
    floors = {'grass': ground(GRASS, 31), 'dirt': ground(DIRT, 32), 'wood': ground(WOOD, 33, planks=True)}
    for i, (name, fr) in enumerate(STATES.items()):
        ox, oy = i % per_row * box_w + pad, i // per_row * box_h + pad
        draw.text((ox, oy), name, fill=(232, 228, 214))
        for j, kind in enumerate(kinds):
            tile = floors[kind].copy()
            tile.alpha_composite(fr.image())
            x = ox + j * (cell + 6)
            sheet.alpha_composite(tile.resize((cell, cell), Image.NEAREST), (x, oy + label))
            sheet.alpha_composite(tile, (x, oy + label + cell + 6))
            draw.text((x + 38, oy + label + cell + 14), kind, fill=(150, 150, 140))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.convert('RGB').save(path)


def main():
    write_dmi(ROOT / 'icons/obj/stone_age_storage.dmi', STATES)
    if '--preview' in sys.argv[1:-1]:
        write_preview(sys.argv[sys.argv.index('--preview') + 1])


if __name__ == '__main__':
    main()
