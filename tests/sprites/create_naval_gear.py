"""Hand-placed 32px naval gear: the degaussing coil, the shore wiping station,
the magnetic sweep reel, the Oropesa sweep set, the deck torpedo tube and its
torpedoes (carried, and running just under the surface).
Every pixel is placed by this script from a fixed palette (Pillow only); no
external or generated artwork. The steel shades are the submarine hull palette
(scripts/draw_submarine_hull.py), lit from the upper left like the rest of the
kit (tests/sprites/create_naval_mines.py).

Run with Pillow to reproduce icons/obj/naval_gear.dmi. `--preview <png>`
also writes a review sheet (8x, every state and direction, with a 1x and 2x
strip underneath): deck fittings on deck planking, the running torpedo on a
deep-water tile, carried items on grey. Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]

OUT = (16, 20, 26)
# submarine hull steel: rivet highlight, H1-H4, plate seam
RIV = (136, 150, 160)
H = [(112, 128, 140), (84, 99, 112), (60, 72, 84), (40, 49, 59)]
SEAM = (48, 58, 68)
# bright wire and lead-grey fittings
L = [(214, 218, 222), (166, 172, 180), (116, 122, 132), (72, 78, 88)]
# red lead paint, light to dark
RED = [(206, 82, 58), (168, 54, 40), (118, 36, 30)]
YEL, YEL2 = (240, 208, 64), (176, 140, 36)
BRZ, BRZ2 = (176, 132, 60), (120, 86, 36)
# copper cable: glint, then light to dark
COP = [(238, 172, 116), (206, 124, 70), (164, 88, 46), (116, 58, 32), (78, 38, 24)]
# the same cable carrying current: a bluish sheen on the lit turns
SHEEN, SHEEN2 = (190, 226, 250), (128, 176, 226)
# rubber-sheathed cable
K = [(104, 110, 120), (70, 76, 86), (44, 48, 56), (26, 29, 35)]
# float paint
ORG = [(255, 176, 84), (240, 116, 40), (196, 76, 28), (138, 48, 24)]
# lamps and dials
LAMP_OFF, LAMP_OFF2 = (58, 70, 60), (36, 44, 40)
GRN, GRN2, GRN3 = (206, 255, 190), (96, 226, 104), (40, 140, 60)
LIT, LIT2 = (255, 214, 120), (255, 120, 60)
DIAL, DIAL_LIT = (150, 156, 150), (255, 240, 178)
# seen through the water
DEEP = (10, 18, 28)
FOAM = (236, 248, 255)
# preview backgrounds
WATER, WATER2 = (36, 78, 112), (44, 90, 124)
FLOOR = (120, 124, 112)
PLANK, PLANK2 = (150, 118, 80), (122, 94, 62)

STEEL = [RIV, H[0], H[1], H[2], H[3]]


class Frame:
    def __init__(self):
        self.px = {}

    def put(self, x, y, c, a=255):
        if 0 <= x < 32 and 0 <= y < 32:
            self.px[(x, y)] = (c[0], c[1], c[2], a)

    def pts(self, c, *points, a=255):
        for x, y in points:
            self.put(x, y, c, a)

    def h(self, y, x0, x1, c, a=255):
        for x in range(x0, x1 + 1):
            self.put(x, y, c, a)

    def v(self, x, y0, y1, c, a=255):
        for y in range(y0, y1 + 1):
            self.put(x, y, c, a)

    def box(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            self.h(y, x0, x1, c)

    def outline(self, c=OUT, a=255):
        """Ring every drawn shape with the dark outline colour."""
        edge = set()
        for (x, y) in self.px:
            for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if n not in self.px:
                    edge.add(n)
        for x, y in edge:
            self.put(x, y, c, a)
        return self

    def add(self, other):
        self.px.update(other.px)
        return self

    def image(self):
        im = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c)
        return im


def disc(cx, cy, r):
    """Pixels whose centres fall inside a circle."""
    return [(x, y) for y in range(32) for x in range(32)
            if math.hypot(x + 0.5 - cx, y + 0.5 - cy) <= r]


def band(ramp, i, n):
    """Shade of row i of n down a lying cylinder: a glint just under the
    top edge, then light to dark."""
    if i == 1 and n > 5:
        return ramp[0]
    t = (i + 0.5) / n
    return ramp[1] if t < 0.38 else ramp[2] if t < 0.66 else ramp[3] if t < 0.9 else ramp[min(4, len(ramp) - 1)]


def lying_drum(f, x0, x1, y0, y1, ramp, wrap, fill=1.0, flange=2, lip=2):
    """A cable drum lying across the tile: steel flanges at x0 and x1, the
    windings between rows y0..y1. `fill` < 1 leaves only the first part of
    the barrel wound and bares the steel core on the rest."""
    n = y1 - y0 + 1
    inner0, inner1 = x0 + flange, x1 - flange
    wound = inner0 + int(round((inner1 - inner0 + 1) * fill)) - 1
    for i in range(n):
        y = y0 + i
        for x in range(inner0, inner1 + 1):
            if x <= wound:
                c = band(ramp, i, n)
                if (x - inner0) % wrap == wrap - 1:      # the groove between turns
                    c = ramp[min(len(ramp) - 1, ramp.index(c) + 1)]
                f.put(x, y, c)
            elif 2 <= i < n - 2:                          # bare barrel
                f.put(x, y, band(STEEL, i - 2, n - 4))
    if wound < inner1:
        for i in range(2, n - 2):                         # shadow beside the last turn
            f.put(wound + 1, y0 + i, H[3])
    fn = n + 2 * lip
    for i in range(fn):
        y = y0 - lip + i
        for k in range(flange):
            for fx, lit in ((x0 + k, k == 0), (x1 - flange + 1 + k, k == 0)):
                c = band(STEEL, i, fn)
                if not lit:
                    c = STEEL[min(4, STEEL.index(c) + 1)]
                f.put(fx, y, c)
    # brass axle caps at the flange centres
    mid = (y0 + y1) // 2
    f.pts(BRZ, (x0, mid)); f.pts(BRZ2, (x0, mid + 1))
    f.pts(BRZ, (x1 - flange + 1, mid)); f.pts(BRZ2, (x1 - flange + 1, mid + 1))


def skid(f, x0, x1, y):
    """The bedplate a drum stands on: two rows of steel with holding-down bolts."""
    f.h(y, x0, x1, H[1]); f.h(y + 1, x0, x1, H[3])
    f.pts(H[0], (x0, y), (x0 + 1, y)); f.pts(H[2], (x1, y), (x1 - 1, y))
    for x in range(x0 + 3, x1 - 1, 5):
        f.put(x, y, RIV)


def lamp(f, x, y, lit, colours):
    hi, mid, lo = colours
    if lit:
        f.pts(hi, (x, y)); f.pts(mid, (x + 1, y), (x, y + 1)); f.pts(lo, (x + 1, y + 1))
    else:
        f.pts(LAMP_OFF, (x, y)); f.pts(LAMP_OFF2, (x + 1, y), (x, y + 1), (x + 1, y + 1))


def glow(f, x, y, c, a=70):
    """A soft halo round a lit 2x2 lamp, laid over whatever is there only
    where nothing has been drawn."""
    for gx, gy in ((x - 1, y), (x - 1, y + 1), (x + 2, y), (x + 2, y + 1),
                   (x, y - 1), (x + 1, y - 1), (x, y + 2), (x + 1, y + 2)):
        if (gx, gy) not in f.px:
            f.put(gx, gy, c, a)


# -------------------------------------------------------- degaussing coil

def coil(on):
    f = Frame()
    lying_drum(f, 2, 19, 9, 21, COP, wrap=2)
    skid(f, 1, 20, 25)
    # legs from the flanges down to the bedplate
    f.pts(H[1], (2, 24), (18, 24)); f.pts(H[3], (3, 24), (19, 24))
    if on:
        # current in the coil: a cold sheen running along the lit turns
        for x in range(4, 18):
            if x % 2 == 0:
                f.put(x, 10, SHEEN)
                if x % 4 == 0:
                    f.put(x, 11, SHEEN2)
                    f.put(x, 9, SHEEN2)
        f.pts(SHEEN2, (6, 12), (12, 12))
    # control box bolted alongside
    b = Frame()
    b.box(22, 11, 29, 12, H[0]); b.pts(RIV, (22, 11), (23, 11)); b.pts(H[1], (29, 11), (29, 12))
    b.box(22, 13, 29, 26, H[1]); b.v(22, 13, 26, H[0]); b.v(29, 13, 26, H[3]); b.v(28, 13, 26, H[2])
    b.h(26, 22, 29, H[3]); b.h(25, 23, 27, H[2])
    lamp(b, 23, 14, on, (GRN, GRN2, GRN3))
    # switch: a slot with the lever thrown up (on) or down (off)
    b.v(26, 15, 22, OUT)
    if on:
        b.pts(L[0], (26, 16), (26, 17)); b.pts(RED[0], (25, 14), (26, 14)); b.pts(RED[1], (25, 15), (26, 15))
        b.pts(RED[2], (27, 14), (27, 15))
    else:
        b.pts(L[1], (26, 20), (26, 21)); b.pts(RED[1], (25, 22), (26, 22)); b.pts(RED[2], (25, 23), (26, 23), (27, 22), (27, 23))
    b.pts(BRZ, (23, 19), (24, 19)); b.pts(BRZ2, (23, 20), (24, 20))       # maker's plate
    b.pts(RIV, (23, 24))
    f.outline(); b.outline()
    f.add(b)
    # the feeder from the coil into the box
    f.pts(COP[0] if on else COP[1], (20, 19), (21, 19)); f.pts(COP[3], (20, 20), (21, 20))
    if on:
        glow(f, 23, 14, GRN2)
    return f


# --------------------------------------------------------- wiping station

def wiping_station(on):
    f = Frame()
    # cabinet: top face, front, shaded right edge
    f.box(2, 6, 13, 7, H[0]); f.pts(RIV, (2, 6), (3, 6), (4, 6)); f.pts(H[1], (13, 6), (13, 7), (12, 7))
    f.box(2, 8, 13, 27, H[1]); f.v(2, 8, 27, H[0]); f.v(13, 8, 27, H[3]); f.v(12, 8, 27, H[2])
    f.h(27, 2, 13, H[3])
    # a round ammeter and a strip meter beside it
    face = DIAL_LIT if on else DIAL
    f.box(4, 10, 6, 12, face)
    f.h(9, 4, 6, SEAM); f.h(13, 4, 6, OUT); f.v(3, 10, 12, SEAM); f.v(7, 10, 12, OUT)
    f.box(9, 10, 11, 11, face); f.h(9, 9, 11, SEAM); f.h(12, 9, 11, OUT)
    if on:
        f.pts(OUT, (5, 12), (5, 11), (6, 10)); f.pts(RED[0], (11, 10), (11, 11)); f.pts(OUT, (10, 11))
    else:
        f.pts(SEAM, (5, 12), (4, 11)); f.pts(SEAM, (9, 11))
    # switch row and louvres
    f.pts(BRZ, (4, 16), (7, 16), (10, 16)); f.pts(BRZ2, (4, 17), (7, 17), (10, 17))
    for y in (20, 22, 24):
        f.h(y, 4, 10, SEAM); f.h(y + 1, 4, 10, H[0] if y == 20 else H[1])
    f.pts(RIV, (3, 26), (11, 26))
    # warning lamp on a stalk on the cabinet top
    f.pts(H[2], (7, 5), (8, 5))
    if on:
        f.pts(LIT, (7, 3)); f.pts(LIT2, (8, 3), (7, 4)); f.pts(RED[0], (8, 4))
    else:
        f.pts(RED[1], (7, 3)); f.pts(RED[2], (8, 3), (7, 4), (8, 4))
    f.outline()
    if on:
        for gx, gy, a in ((6, 2, 110), (9, 2, 110), (7, 1, 150), (8, 1, 150), (5, 3, 90), (10, 3, 90),
                          (7, 0, 70), (8, 0, 70), (5, 1, 60), (10, 1, 60)):
            f.put(gx, gy, LIT2, a)

    # cable drum seen end-on, on an A-frame
    d = Frame()
    cx, cy = 22.5, 12.5
    full = 4.6 if not on else 3.0
    for x, y in disc(cx, cy, 7.2):
        r = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
        lit = math.hypot(x + 0.5 - 20.0, y + 0.5 - 9.5)
        if r > 6.0:
            c = H[0] if lit < 6.5 else H[1] if lit < 10.5 else H[2]      # flange rim
        elif r > full:
            c = H[2] if lit < 7.5 else H[3]                              # dished flange
        elif r > 1.6:
            c = K[0] if lit < 3.6 else K[1] if lit < 6.4 else K[2]       # the wound cable
            if int(r + 0.2) % 2 == 0:
                c = K[min(3, K.index(c) + 1)]
        else:
            c = BRZ if lit < 4.6 else BRZ2                               # hub
        d.put(x, y, c)
    # spokes show where the flange is bare
    if on:
        for k in range(1, 3):
            d.pts(H[1], (int(cx - 0.5 - 2 - k), int(cy - 0.5)), (int(cx - 0.5), int(cy - 0.5 - 2 - k)))
            d.pts(SEAM, (int(cx + 0.5 + 1 + k), int(cy)), (int(cx), int(cy + 0.5 + 1 + k)))
    # A-frame legs and foot
    for i in range(6):
        d.pts(H[1], (18 - i // 2, 19 + i)); d.pts(H[3], (27 + i // 2, 19 + i))
    d.h(25, 15, 30, H[2]); d.pts(H[1], (15, 25), (16, 25)); d.h(26, 15, 30, H[3])
    d.outline()
    f.add(d)

    c = Frame()
    if not on:
        # heavy cable faked down in a coil on the quay, lugs uppermost
        for (ex, ey, rx, ry) in ((23.0, 26.5, 7.6, 3.4),):
            for y in range(32):
                for x in range(32):
                    q = math.hypot((x + 0.5 - ex) / rx, (y + 0.5 - ey) / ry)
                    if q <= 1.0:
                        ring = int(q * 3.6)
                        if ring == 0:
                            continue
                        lit = (x + 0.5 - ex) / rx + (y + 0.5 - ey) / ry
                        col = K[0] if lit < -0.75 else K[1] if lit < 0.15 else K[2]
                        if ring % 2 == 0:
                            col = K[3]
                        c.put(x, y, col)
        c.pts(COP[0], (29, 23)); c.pts(COP[2], (30, 23))
        c.pts(K[1], (28, 23))
        c.outline()
        c.pts(OUT, (22, 26), (23, 26), (24, 26), (22, 27), (23, 27))     # the eye of the coil
    else:
        # two cables run out across the quay towards the ship alongside
        runs = (((19, 19), (18, 21), (18, 23), (19, 25), (21, 27), (23, 28), (25, 29), (27, 30), (29, 31), (31, 31)),
                ((27, 16), (29, 18), (30, 20), (30, 22), (30, 24), (31, 26), (31, 27)))
        for run in runs:
            for (ax, ay), (bx, by) in zip(run, run[1:]):
                n = max(abs(bx - ax), abs(by - ay))
                for s in range(n + 1):
                    x = ax + (bx - ax) * s // n
                    y = ay + (by - ay) * s // n
                    c.put(x, y, K[0]); c.put(x + 1, y, K[1]); c.put(x, y + 1, K[2]); c.put(x + 1, y + 1, K[2])
        for (x, y) in list(c.px):
            if (x, y) in d.px and d.px[(x, y)][:3] != OUT and y < 19:
                del c.px[(x, y)]
        c.outline()
        for (x, y) in list(c.px):                    # do not ring over the drum itself
            if c.px[(x, y)][:3] == OUT and (x, y) in d.px and y < 19:
                del c.px[(x, y)]
    f.add(c)
    # feeder between cabinet and drum
    f.pts(K[0], (14, 22), (15, 22)); f.pts(K[2], (14, 23), (15, 23))
    return f


# ------------------------------------------------------------- sweep reel

def cable_run(f, points, ramp, width=2):
    for (ax, ay), (bx, by) in zip(points, points[1:]):
        n = max(abs(bx - ax), abs(by - ay), 1)
        for s in range(n + 1):
            x = ax + (bx - ax) * s // n
            y = ay + (by - ay) * s // n
            f.put(x, y, ramp[0])
            if width > 1:
                f.put(x + 1, y, ramp[2])


def small_float(f, x, y):
    f.pts(ORG[0], (x, y), (x + 1, y)); f.pts(ORG[1], (x + 2, y), (x, y + 1), (x + 1, y + 1)); f.pts(ORG[2], (x + 2, y + 1), (x + 3, y))
    f.pts(ORG[3], (x + 3, y + 1))


def sweep_reel(on):
    f = Frame()
    lying_drum(f, 2, 29, 6, 19, K + [K[3]], wrap=3, fill=0.24 if on else 1.0, flange=2, lip=2)
    # frame: cheeks down to the bedplate, a brake wheel on the right
    f.pts(H[1], (2, 22), (28, 22)); f.pts(H[3], (3, 22), (29, 22))
    skid(f, 1, 30, 23)
    f.outline()
    f.pts(RED[0], (30, 11)); f.pts(RED[1], (30, 12), (30, 13)); f.pts(RED[2], (30, 14))    # brake handle
    c = Frame()
    if not on:
        # the cable's tail float lashed in front of the drum
        rows = {26: (13, 26), 27: (11, 28), 28: (11, 28), 29: (11, 28), 30: (13, 26)}
        for y, (x0, x1) in rows.items():
            c.h(y, x0, x1, ORG[0] if y == 26 else ORG[1] if y < 29 else ORG[2])
        c.h(27, 13, 22, ORG[0]); c.pts(L[0], (14, 26), (15, 26))
        c.pts(ORG[2], (27, 27), (28, 27), (27, 28), (28, 28)); c.pts(ORG[3], (27, 29), (28, 29), (25, 30), (26, 30))
        c.v(18, 26, 30, YEL); c.v(19, 26, 30, YEL2)                       # marker band
        c.outline()
        # its tail of cable back up to the drum
        t = Frame()
        cable_run(t, ((9, 28), (7, 27), (6, 25), (6, 21)), K)
        t.outline()
        f.add(t)
        f.add(c)
        f.pts(K[0], (10, 28)); f.pts(K[2], (10, 29))
    else:
        # cable paying out over the stern, floats spaced along it
        cable_run(c, ((7, 17), (8, 20), (10, 24), (13, 27), (15, 29), (16, 31)), K)
        c.outline()
        for (x, y) in list(c.px):
            if y < 20 and c.px[(x, y)][:3] == OUT and (x, y) in f.px:
                del c.px[(x, y)]
        f.add(c)
        s = Frame()
        small_float(s, 9, 22); small_float(s, 14, 28)
        s.outline()
        f.add(s)
        # the float's empty chocks
        f.pts(H[2], (22, 28), (23, 28), (27, 28), (28, 28)); f.pts(OUT, (22, 29), (23, 29), (27, 29), (28, 29), (21, 28), (24, 28), (26, 28), (29, 28))
    return f


# ---------------------------------------------------------------- Oropesa

def oropesa(on):
    f = Frame()
    lying_drum(f, 2, 17, 6, 14, L + [L[3]], wrap=2, fill=0.4 if on else 1.0, flange=2, lip=2)
    f.pts(H[1], (2, 17), (16, 17)); f.pts(H[3], (3, 17), (17, 17))
    skid(f, 1, 18, 18)
    f.outline()
    if on:
        w = Frame()
        cable_run(w, ((6, 13), (7, 17), (9, 21), (12, 25), (14, 28), (15, 31)), [L[0], L[1], L[2]], width=1)
        for (x, y) in list(w.px):
            f.put(x, y, L[0])
            if (x + 1, y) not in w.px:
                f.put(x + 1, y, OUT)
        # the float's empty chocks; the otter has gone over with it
        f.pts(H[2], (20, 26), (21, 26), (27, 26), (28, 26)); f.pts(H[3], (20, 27), (21, 27), (27, 27), (28, 27))
        f.pts(OUT, (19, 26), (22, 26), (26, 26), (29, 26), (19, 27), (22, 27), (26, 27), (29, 27))
        f.h(28, 19, 22, OUT); f.h(28, 26, 29, OUT); f.h(25, 20, 21, OUT); f.h(25, 27, 28, OUT)
        return f
    # otter board (kite): a steel frame of angled vanes, wire cutter on its bridle
    k = Frame()
    k.box(21, 3, 29, 14, H[2])
    k.v(21, 3, 14, H[0]); k.h(3, 21, 29, H[0]); k.v(29, 4, 14, H[3]); k.h(14, 22, 29, H[3])
    k.pts(RIV, (21, 3), (22, 3))
    for y0 in (5, 8, 11):                       # vanes
        k.h(y0, 23, 27, L[1]); k.h(y0 + 1, 23, 27, H[1]); k.pts(L[0], (23, y0), (24, y0))
        k.h(y0 + 2, 23, 27, OUT) if y0 < 11 else None
        k.h(y0 - 1, 23, 27, SEAM) if y0 == 5 else None
    k.outline()
    f.add(k)
    # cutter: a V jaw of bright steel on a red bracket below the kite
    j = Frame()
    j.pts(RED[0], (23, 16), (24, 16)); j.pts(RED[1], (25, 16), (24, 17)); j.pts(RED[2], (25, 17))
    j.pts(L[0], (26, 16), (27, 15), (26, 18), (27, 19)); j.pts(L[1], (28, 15), (28, 19), (26, 17))
    j.outline()
    f.add(j)
    # the float: a torpedo-shaped buoy, nose left, tail fins right, flag staff
    b = Frame()
    rows = {22: (8, 22), 23: (5, 25), 24: (4, 27), 25: (3, 28), 26: (4, 27), 27: (5, 25), 28: (8, 22)}
    shade = {22: ORG[1], 23: ORG[0], 24: ORG[1], 25: ORG[1], 26: ORG[2], 27: ORG[2], 28: ORG[3]}
    for y, (x0, x1) in rows.items():
        b.h(y, x0, x1, shade[y])
    b.h(23, 8, 14, L[0]); b.h(23, 15, 18, ORG[0])
    b.pts(ORG[2], (3, 25), (4, 24), (4, 26)); b.pts(ORG[3], (5, 27))
    for y in rows:                              # white recognition band
        if rows[y][0] <= 18:
            b.put(18, y, L[0] if y < 26 else L[1]); b.put(19, y, L[1] if y < 26 else L[2])
    # tail fins
    b.pts(ORG[1], (26, 21), (27, 21), (27, 22), (26, 22)); b.pts(ORG[2], (28, 21), (28, 22), (27, 23), (26, 23))
    b.pts(ORG[2], (26, 28), (27, 28), (27, 29), (28, 29)); b.pts(ORG[3], (26, 29), (28, 28), (28, 27))
    # staff and flag
    b.v(12, 17, 21, L[1]); b.pts(RED[0], (13, 17), (14, 17), (15, 17), (13, 18), (14, 18)); b.pts(RED[1], (15, 18), (13, 19))
    b.outline()
    f.add(b)
    # wire from the drum to the float's towing eye
    f.pts(L[0], (5, 20), (4, 21), (4, 22)); f.pts(OUT, (6, 20), (5, 21))
    return f


# ----------------------------------------------------------- torpedo tube

def place(direction, a, b):
    """Axis coordinates to the tile: `a` runs along the facing (0 = astern),
    `b` across it with the lit side at low b. Vertical frames are the
    transpose of the horizontal ones, so the light stays upper left."""
    if direction == 'EAST':
        return a, b
    if direction == 'WEST':
        return 31 - a, b
    if direction == 'SOUTH':
        return b, a
    return b, 31 - a


def torpedo_tube(direction):
    f = Frame()

    def put(a, b, c):
        x, y = place(direction, a, b)
        f.put(x, y, c)

    # training base: a bolted ring seen from above (drawn in tile space so
    # its shading keeps to the upper left whichever way the tube points)
    for x, y in disc(16.0, 16.0, 7.6):
        r = math.hypot(x + 0.5 - 16.0, y + 0.5 - 16.0)
        lit = math.hypot(x + 0.5 - 12.0, y + 0.5 - 12.0)
        c = H[1] if lit < 5.5 else H[2] if lit < 10.5 else H[3]
        if 5.2 < r < 6.3:
            c = SEAM if lit < 10.5 else OUT
        f.put(x, y, c)
    for k in range(8):                                    # ring bolts
        ang = math.pi / 8 + k * math.pi / 4
        f.put(int(16.0 + 6.9 * math.cos(ang)), int(16.0 + 6.9 * math.sin(ang)), RIV if k in (3, 4, 5) else H[1])
    # the barrel
    tube = [H[0], RIV, H[0], H[1], H[2], H[3]]
    for a in range(3, 30):
        for i, c in enumerate(tube):
            put(a, 13 + i, c)
    for a in (14, 21):                                    # stiffening bands
        for i in range(6):
            put(a, 13 + i, SEAM if i < 4 else OUT)
        put(a + 1, 13, RIV); put(a + 1, 14, RIV)
    # muzzle ring and the dark of the bore just inside it
    ring = [H[0], RIV, RIV, H[0], H[1], H[1], H[2], H[3]]
    for i, c in enumerate(ring):
        put(28, 12 + i, c); put(29, 12 + i, STEEL[min(4, STEEL.index(c) + 1)])
    put(27, 13, SEAM); put(27, 14, SEAM); put(27, 15, SEAM); put(27, 16, OUT); put(27, 17, OUT); put(27, 18, OUT)
    # breech: a fatter cast section with its door at the back
    breech = [H[0], RIV, H[0], H[0], H[1], H[2], H[2], H[3]]
    for a in range(2, 9):
        for i, c in enumerate(breech):
            put(a, 12 + i, c)
    for i in range(8):
        put(2, 12 + i, H[2] if i < 5 else H[3])           # door edge
        put(8, 12 + i, SEAM if i < 5 else OUT)            # joint with the barrel
    for i in (1, 6):
        put(3, 12 + i, BRZ); put(4, 12 + i, BRZ2)         # door dogs
    put(5, 15, BRZ); put(6, 15, BRZ); put(5, 16, BRZ2); put(6, 16, BRZ2)   # impulse valve
    # firing lever standing off the breech on the lit side, red grip
    put(6, 11, L[1]); put(6, 10, L[0]); put(7, 9, L[1])
    put(7, 8, RED[0]); put(8, 8, RED[1]); put(8, 7, RED[0]); put(9, 7, RED[2])
    # trainer's handwheel on the other side
    for a, b, c in ((11, 20, BRZ2), (10, 21, BRZ), (11, 21, BRZ), (12, 21, BRZ2), (10, 22, BRZ), (12, 22, BRZ2),
                    (10, 23, BRZ2), (11, 23, BRZ2), (12, 23, BRZ2)):
        put(a, b, c)
    f.outline()
    hx, hy = place(direction, 11, 22)
    f.put(hx, hy, OUT)                                    # the eye of the handwheel
    return f


# ---------------------------------------------------------------- torpedo

def torpedo(magnetic):
    """Carried: tail lower left, warhead upper right."""
    f = Frame()
    x0, y0, x1, y1 = 5.5, 26.5, 27.0, 5.0
    length = math.hypot(x1 - x0, y1 - y0)
    ux, uy = (x1 - x0) / length, (y1 - y0) / length
    nx, ny = uy, -ux                                       # towards the light (upper left)
    steel = [H[0], H[1], H[2], H[3]]
    red = [RED[0], RED[0], RED[1], RED[2]]
    yel = [YEL, YEL, YEL2, BRZ2]
    brz = [(214, 172, 92), BRZ, BRZ2, (84, 58, 26)]
    cop = [COP[0], COP[1], COP[3], COP[4]]
    for y in range(32):
        for x in range(32):
            px, py = x + 0.5 - x0, y + 0.5 - y0
            t = px * ux + py * uy
            s = px * nx + py * ny
            if t < 1.5 or t > length:
                continue
            if t < 8.0:
                r = 0.8 + 1.7 * (t - 1.5) / 6.5            # tail cone
            elif t > length - 3.6:
                q = (t - (length - 3.6)) / 3.6
                r = 2.5 * math.sqrt(max(0.0, 1 - q * q))   # rounded nose
            else:
                r = 2.5
            if abs(s) > r:
                continue
            i = 0 if s > 0.9 else 1 if s > -0.5 else 2 if s > -1.6 else 3
            ramp = steel
            if magnetic:
                if t > length - 6.2:
                    ramp = brz                             # bronze pistol nose
                elif t > length - 8.6:
                    ramp = yel                             # yellow band
                elif length - 11.6 < t <= length - 10.2:
                    ramp = cop                             # search coil band
            else:
                if length - 8.6 < t <= length - 5.8:
                    ramp = red                             # warhead band
                elif t > length - 1.3:
                    ramp = brz                             # contact pistol
            c = ramp[i]
            if ramp is steel:
                if i == 0 and 12.0 < t < 19.0 and s < 1.9:
                    c = RIV                                # glint along the air flask
                if abs(t - (length - 12.8)) < 0.5 or abs(t - 9.0) < 0.5:
                    c = SEAM if i < 3 else OUT             # section joints
            f.put(x, y, c)
    # tail: four fins (two seen edge-on across the body), bronze propellers
    f.pts(H[1], (6, 22), (7, 21), (7, 22)); f.pts(H[0], (5, 21), (6, 21), (6, 20))
    f.pts(H[2], (10, 25), (10, 26), (11, 26)); f.pts(H[3], (10, 27), (11, 27), (11, 28))
    f.pts(BRZ, (3, 25), (4, 24), (4, 25)); f.pts((214, 172, 92), (3, 24))
    f.pts(BRZ2, (6, 28), (7, 28), (7, 29)); f.pts((84, 58, 26), (6, 29))
    f.pts(BRZ2, (5, 27), (4, 27)); f.pts(BRZ, (5, 26), (4, 26))
    f.outline()
    return f


def torpedo_running(direction):
    """From above, a hand's breadth under the surface: a dark slim shape and
    the white track of its exhaust behind it."""
    f = Frame()

    def put(a, b, c, alpha):
        x, y = place(direction, a, b)
        f.put(x, y, c, alpha)

    # the wake: brightest at the tail, spreading and breaking up astern
    for a in range(0, 15):
        near = a / 14.0
        core = int(70 + 170 * near)
        put(a, 15, FOAM, core); put(a, 16, FOAM, core)
        if a < 12 and (a % 3 != 1):
            put(a, 14, FOAM, int(40 + 110 * near)); put(a, 17, FOAM, int(40 + 110 * near))
        if a < 8 and a % 4 == 0:
            put(a, 13, FOAM, 70); put(a, 18, FOAM, 70)
        if a < 5 and a % 4 == 2:
            put(a, 12, FOAM, 46); put(a, 19, FOAM, 46)
    put(13, 14, FOAM, 150); put(13, 17, FOAM, 150)
    # the body
    for a in range(15, 30):
        put(a, 15, DEEP, 156); put(a, 16, DEEP, 156)
    for a in range(17, 28):
        put(a, 14, DEEP, 118); put(a, 17, DEEP, 118)
    put(30, 15, DEEP, 112); put(30, 16, DEEP, 112)
    put(15, 14, DEEP, 132); put(15, 17, DEEP, 132)        # tail fins
    put(15, 13, DEEP, 96); put(15, 18, DEEP, 96)
    # a thin bright ripple where the nose lifts the surface
    put(29, 13, FOAM, 90); put(28, 13, FOAM, 60); put(29, 18, FOAM, 90); put(28, 18, FOAM, 60)
    return f


DIRS = ('SOUTH', 'NORTH', 'EAST', 'WEST')      # DMI frame order for dirs = 4

STATES = {
    'coil': [coil(False)],
    'coil_on': [coil(True)],
    'wiping_station': [wiping_station(False)],
    'wiping_station_on': [wiping_station(True)],
    'sweep_reel': [sweep_reel(False)],
    'sweep_reel_on': [sweep_reel(True)],
    'oropesa': [oropesa(False)],
    'oropesa_on': [oropesa(True)],
    'torpedo_tube': [torpedo_tube(d) for d in DIRS],
    'torpedo': [torpedo(False)],
    'torpedo_magnetic': [torpedo(True)],
    'torpedo_running': [torpedo_running(d) for d in DIRS],
}


def write_dmi(path, states, cols=6):
    frames = [fr for group in states.values() for fr in group]
    rows = -(-len(frames) // cols)
    sheet = Image.new('RGBA', (32 * cols, 32 * rows), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(fr.image(), (i % cols * 32, i // cols * 32))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, group in states.items():
        text += 'state = "%s"\n\tdirs = %d\n\tframes = 1\n' % (name, len(group))
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta)


def preview_tile(name, fr):
    if name == 'torpedo_running':
        tile = Image.new('RGBA', (32, 32), WATER + (255,))
        for y in range(32):          # a few wave streaks, as on the water turf
            for x in range(32):
                if (x + 3 * y) % 16 < 5 and y % 6 == 2:
                    tile.putpixel((x, y), WATER2 + (255,))
    elif name in ('torpedo', 'torpedo_magnetic'):
        tile = Image.new('RGBA', (32, 32), FLOOR + (255,))
    else:
        tile = Image.new('RGBA', (32, 32), PLANK + (255,))
        for y in range(32):          # deck planking
            for x in range(32):
                if y % 8 == 7 or (x == (5 if (y // 8) % 2 else 21) and y % 8 < 7):
                    tile.putpixel((x, y), PLANK2 + (255,))
    tile.alpha_composite(fr.image())
    return tile


def write_preview(path, scale=8, cols=6):
    tiles = [preview_tile(name, fr) for name, group in STATES.items() for fr in group]
    rows = -(-len(tiles) // cols)
    cell = 32 * scale
    strip = 80
    sheet = Image.new('RGBA', (cell * cols, cell * rows + strip), (30, 32, 36, 255))
    for i, tile in enumerate(tiles):
        sheet.alpha_composite(tile.resize((cell, cell), Image.NEAREST), (i % cols * cell, i // cols * cell))
        sheet.alpha_composite(tile, (8 + i * 104, cell * rows + 24))
        sheet.alpha_composite(tile.resize((64, 64), Image.NEAREST), (44 + i * 104, cell * rows + 8))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.convert('RGB').save(path)


def main():
    write_dmi(ROOT / 'icons/obj/naval_gear.dmi', STATES)
    if '--preview' in sys.argv[1:-1]:
        write_preview(sys.argv[sys.argv.index('--preview') + 1])


if __name__ == '__main__':
    main()
