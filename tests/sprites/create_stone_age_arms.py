"""Hand-placed 32px Stone Age weapons and tools: spear-thrower and dart, bola,
fire-hardened javelin, stone club, weighted digging stick, hand axe, hide
scraper, bone needle and awl, stone adze and flint knife. Every pixel is
placed by this script from a fixed palette (Pillow only); no external or
generated artwork.
The outline, flint greys, wood browns and antler tones are the ones already
used in icons/obj/flint_mining.dmi, lit from the upper left.

Run with Pillow to reproduce icons/obj/stone_age_arms.dmi. `--preview <png>`
also writes a review sheet (8x, with a 1x and 2x strip underneath).
Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]

OUT = (62, 49, 34)
# flint, light to dark (flint_mining.dmi), plus the fresh-flake glint
FL = [(184, 178, 168), (154, 149, 141), (111, 106, 100), (79, 74, 68)]
# wood, light to dark
WD = [(198, 151, 106), (168, 122, 76), (122, 84, 50), (92, 61, 34)]
# pale peeled shaft wood for darts
PW = [(214, 180, 132), (184, 146, 98), (140, 104, 64)]
# bone and antler
BN = [(232, 218, 186), (210, 191, 152), (168, 141, 102), (125, 102, 73)]
# sinew and plant-fibre cord
CD = [(205, 185, 143), (156, 131, 96), (112, 90, 62)]
# fire-hardened, charred wood
CH = [(96, 78, 66), (66, 54, 48), (44, 36, 34)]
# feather fletching
FE = [(226, 220, 206), (182, 174, 158), (128, 120, 108)]
# river cobble (bola weights, club head, digging weight)
ST = [(170, 168, 160), (136, 134, 128), (104, 102, 98), (76, 74, 72)]
# preview backgrounds
GROUND = (120, 124, 112)
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

    def cut(self, *points):
        for p in points:
            self.px.pop(p, None)

    def outline(self, c=OUT):
        """Ring every drawn shape with the dark outline colour."""
        edge = set()
        for (x, y) in self.px:
            for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if n not in self.px:
                    edge.add(n)
        for x, y in edge:
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


def blob(f, cx, cy, rx, ry, pal, lx=-0.45, ly=-0.5):
    """A rounded stone shaded in bands away from a light spot."""
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


# ------------------------------------------------------------ spear-thrower

def atlatl_body():
    """Spur at the lower left, grip at the upper right, as it sits behind a
    dart that points up and to the right."""
    f = Frame()
    # the board: a flat stick, a little wider through the middle
    bar(f, (7.5, 27.5), (21.5, 13.5), lambda t: 1.2 + 0.45 * math.sin(t * math.pi), three(WD))
    # grip: two bands of hide wrap with the finger notch between them
    bar(f, (20.5, 14.5), (26.5, 8.5), 1.3, three(WD))
    bar(f, (19.5, 15.5), (21.5, 13.5), 1.75, lambda s, t: CD[0] if s < -0.2 else CD[1] if s < 0.5 else CD[2])
    bar(f, (23.5, 11.5), (25.5, 9.5), 1.75, lambda s, t: CD[0] if s < -0.2 else CD[1] if s < 0.5 else CD[2])
    f.pts(WD[1], (27, 7)); f.pts(WD[0], (26, 7)); f.pts(WD[2], (27, 8))          # pommel knob
    # bannerstone weight lashed under the board
    blob(f, 14.2, 22.4, 2.4, 2.4, ST)
    f.pts(CD[0], (12, 21), (13, 22)); f.pts(CD[1], (14, 23), (15, 24))
    # bone spur that seats the dart's nock: a hook rising off the tail end
    f.pts(BN[1], (6, 27), (6, 28), (5, 26), (5, 27)); f.pts(BN[2], (7, 28), (6, 29))
    f.pts(BN[0], (4, 25), (5, 25), (5, 24), (6, 24), (5, 23), (6, 22)); f.pts(BN[1], (6, 23), (7, 22)); f.pts(BN[2], (7, 23), (7, 24))
    f.outline()
    return f


def fletch(f, x0, y0, n):
    """Split feathers bound either side of the shaft from (x0, y0) upward."""
    for i in range(n):
        x, y = x0 + i, y0 - i
        f.pts(PW[2], (x, y))
        f.pts(FE[0], (x - 1, y), (x, y - 1)); f.pts(FE[1], (x + 1, y), (x, y + 1))
        if 0 < i < n - 1:
            f.pts(FE[0], (x - 1, y - 1)); f.pts(FE[2], (x + 1, y + 1))
        if 0 < i < n - 2:
            f.pts(FE[1], (x - 2, y - 1)); f.pts(FE[2], (x + 1, y + 2))


def dart(f, tail, head, feathers=6):
    """A light dart: peeled shaft, sinew-bound flint point, split feathers."""
    (x0, y0), (x1, y1) = tail, head
    bar(f, (x0 + 0.5, y0 + 0.5), (x1 - 2.5, y1 + 3.5), 0.72, lambda s, t: PW[0] if s < 0 else PW[2])
    fletch(f, x0 + 2, y0 - 2, feathers)
    f.pts(CD[1], (x0 + 1, y0 - 1), (x0 + 2 + feathers, y0 - 2 - feathers))        # feather bindings
    # flint point and its sinew binding
    hx, hy = x1, y1
    f.pts(CD[0], (hx - 5, hy + 5), (hx - 4, hy + 4)); f.pts(CD[1], (hx - 4, hy + 5), (hx - 3, hy + 4))
    f.pts(FL[1], (hx - 3, hy + 2), (hx - 2, hy + 1), (hx - 1, hy), (hx - 3, hy + 3), (hx - 4, hy + 3), (hx - 4, hy + 2))
    f.pts(FL[0], (hx - 2, hy + 2), (hx - 1, hy + 1), (hx, hy))
    f.pts(FL[2], (hx - 2, hy + 3), (hx - 1, hy + 2), (hx, hy + 1), (hx - 1, hy + 3), (hx - 2, hy + 4))
    f.pts(FL[3], (hx - 1, hy + 4), (hx, hy + 2), (hx - 2, hy + 5))


def atlatl():
    return atlatl_body()


def atlatl_loaded():
    f = atlatl_body()
    d = Frame()
    dart(d, (5, 23), (28, 2), feathers=4)       # nock seated on the spur
    d.outline()
    f.over(d)
    f.pts(BN[0], (5, 24)); f.pts(BN[1], (6, 24))                                  # spur tip over the nock
    return f


def atlatl_dart():
    f = Frame()
    dart(f, (3, 28), (28, 3))
    f.outline()
    return f


# --------------------------------------------------------------------- bola

def bola():
    f = Frame()
    c = Frame()
    # three cords from the knot, each sagging to its weight
    trace(c, CD[0], (15, 6), (12, 9), (9, 13), (7, 17), (7, 20))
    trace(c, CD[0], (16, 7), (17, 11), (16, 15), (15, 19), (15, 23))
    trace(c, CD[0], (17, 6), (20, 8), (23, 11), (25, 15), (25, 18))
    c.pts(CD[1], (9, 13), (7, 17), (16, 15), (15, 19), (23, 11), (25, 15))
    c.outline()
    f.over(c)
    # the weights: cobbles sewn into hide pouches, tied at the neck
    for cx, cy in ((7.0, 23.0), (15.5, 26.0), (25.0, 21.5)):
        s = Frame()
        blob(s, cx, cy, 3.1, 3.0, ST)
        s.outline()
        f.over(s)
        nx, ny = int(cx), int(cy - 3.0)
        f.pts(CD[1], (nx - 1, ny)); f.pts(CD[0], (nx, ny)); f.pts(CD[2], (nx + 1, ny))
    # the knot the thrower holds
    k = Frame()
    k.pts(CD[0], (15, 5), (16, 5), (15, 6), (16, 4)); k.pts(CD[1], (16, 6), (17, 5), (17, 6)); k.pts(CD[2], (16, 7), (17, 7))
    k.outline()
    f.over(k)
    return f


# ------------------------------------------------------------------ javelin

def javelin():
    f = Frame()

    def shade(s, t):
        if t > 0.9:
            pal = CH[1:] + [CH[2]]
        elif t > 0.78:
            pal = CH
        else:
            pal = WD
        return pal[0] if s < -0.3 else pal[1] if s < 0.35 else pal[2]

    # shaft thickest a third of the way up, tapering to the hardened point
    bar(f, (3.5, 28.5), (28.5, 3.5),
        lambda t: 1.3 if t < 0.72 else max(0.35, 1.3 * (1.0 - (t - 0.72) / 0.3)), shade)
    f.pts(CH[2], (28, 3)); f.pts(CH[1], (27, 4))
    # scorch creeping down from the point
    f.pts(CH[0], (21, 10), (20, 12)); f.pts(WD[3], (19, 12), (22, 10))
    # cord grip at the point of balance
    bar(f, (11.5, 20.5), (16.5, 15.5), 1.45, lambda s, t: CD[0] if s < -0.3 else CD[1] if s < 0.4 else CD[2])
    f.pts(CD[2], (12, 19), (14, 19), (14, 17), (16, 17), (13, 18), (15, 16))
    # butt end cut square
    f.pts(WD[3], (3, 28), (4, 29))
    f.outline()
    return f


# --------------------------------------------------------------- stone club

def stone_club():
    f = Frame()
    # handle swelling slightly to the grip end
    bar(f, (5.5, 27.5), (20.5, 12.5), lambda t: 1.75 - 0.4 * t, three(WD))
    f.pts(WD[3], (5, 27), (6, 28), (7, 27)); f.pts(WD[2], (4, 26), (5, 25))     # worn knob
    f.pts(WD[2], (9, 22), (12, 19))                                              # grain
    f.outline()
    # head: a heavy cobble set across the split end
    h = Frame()
    blob(h, 21.6, 10.6, 5.6, 4.9, ST)
    h.pts(ST[0], (18, 8), (19, 7)); h.pts(ST[3], (24, 14), (25, 12), (23, 15))
    h.pts(ST[2], (20, 12), (22, 9))                                              # pitting
    h.outline()
    f.over(h)
    # rawhide lashing crossed over the stone and wound round the haft
    for x, y in ((18, 8), (19, 9), (20, 10), (21, 11), (22, 12), (23, 13), (24, 14)):
        f.put(x, y, CD[0] if x < 22 else CD[1])
    for x, y in ((24, 8), (23, 9), (22, 10), (20, 12), (19, 13), (18, 14)):
        f.put(x, y, CD[0] if y < 11 else CD[1])
    f.pts(CD[2], (25, 14), (17, 14))
    f.pts(CD[0], (15, 15), (16, 16)); f.pts(CD[1], (17, 17), (14, 16), (15, 17)); f.pts(CD[2], (16, 18))
    return f


# ------------------------------------------------------------ digging stick

def digging_stick():
    f = Frame()

    def shade(s, t):
        pal = CH if t < 0.1 else WD
        return pal[0] if s < -0.3 else pal[1] if s < 0.35 else pal[2]

    # stout stick, chisel point down at the lower left, hardened in the fire
    bar(f, (4.5, 28.5), (26.5, 4.5), lambda t: 0.4 + 9.0 * t if t < 0.1 else 1.3, shade)
    f.pts(WD[0], (26, 4)); f.pts(WD[2], (27, 4), (27, 5))                         # rounded top
    f.pts(WD[2], (12, 20), (22, 9)); f.pts(WD[3], (9, 24))
    f.outline()
    # bored stone weight threaded on the shaft and wedged
    w = Frame()
    blob(w, 17.2, 14.6, 4.6, 4.2, ST)
    w.outline()
    # the bore: the shaft shows through, rim shadowed on the far side
    w.pts(WD[0], (16, 14), (17, 13)); w.pts(WD[1], (17, 14), (18, 13), (16, 15)); w.pts(WD[2], (17, 15), (18, 14))
    w.pts(OUT, (15, 14), (16, 13), (15, 15), (17, 12), (18, 12))
    w.pts(ST[3], (19, 13), (19, 14), (18, 15), (17, 16), (16, 16))
    f.over(w)
    # the shaft carries on in front of the weight below the bore
    f.pts(OUT, (13, 17), (14, 16)); f.pts(WD[1], (14, 17)); f.pts(WD[0], (13, 18))
    f.pts(BN[2], (19, 12)); f.pts(OUT, (20, 11))                                  # wedge
    return f


# ----------------------------------------------------------------- hand axe

AXE_ROWS = {  # y: (left, right) of the teardrop biface
    5: (16, 16), 6: (15, 17), 7: (15, 17), 8: (14, 18), 9: (14, 18), 10: (13, 19),
    11: (13, 19), 12: (12, 20), 13: (12, 20), 14: (11, 21), 15: (11, 21), 16: (10, 22),
    17: (10, 22), 18: (9, 22), 19: (9, 23), 20: (9, 23), 21: (9, 23), 22: (9, 23),
    23: (10, 22), 24: (10, 22), 25: (11, 21), 26: (13, 19),
}


def hand_axe():
    f = Frame()
    for y, (x0, x1) in AXE_ROWS.items():
        ridge = 15 + (1 if y > 15 else 0)        # the ridge wanders off centre
        for x in range(x0, x1 + 1):
            f.put(x, y, FL[1] if x < ridge else FL[2])
    # flake scars struck in from both edges towards the ridge
    f.pts(FL[0], (15, 8), (14, 10), (14, 11), (13, 13), (13, 14), (12, 16), (11, 18), (11, 19), (12, 19),
          (12, 22), (13, 23), (16, 6))
    f.pts(FL[2], (14, 13), (15, 13), (13, 16), (14, 17), (12, 20), (13, 20), (14, 21), (11, 22), (12, 24), (13, 25))
    f.pts(FL[1], (17, 10), (18, 13), (17, 14), (19, 16), (18, 17), (20, 19), (19, 20), (17, 22), (18, 23))
    f.pts(FL[3], (18, 9), (19, 12), (20, 14), (20, 15), (21, 17), (22, 19), (22, 20), (21, 21), (22, 22),
          (20, 23), (21, 24), (19, 25), (18, 26), (17, 26), (16, 12), (17, 17), (16, 20), (18, 20))
    # cortex left on the butt where the hand grips
    f.pts(BN[2], (14, 24), (15, 24), (16, 24), (15, 25), (16, 25), (17, 25), (14, 25))
    f.pts(BN[1], (14, 23), (15, 23)); f.pts(BN[3], (17, 24), (16, 26), (15, 26), (14, 26))
    f.outline()
    return f


# ------------------------------------------------------------- hide scraper

SCRAPER_ROWS = {  # an end-scraper on a thick blade, leaning, working end uppermost
    6: (17, 21), 7: (15, 23), 8: (14, 24), 9: (13, 24), 10: (13, 25), 11: (13, 25),
    12: (12, 24), 13: (12, 24), 14: (12, 24), 15: (12, 23), 16: (11, 23), 17: (11, 22),
    18: (11, 22), 19: (11, 21), 20: (10, 21), 21: (10, 20), 22: (10, 19), 23: (10, 18),
    24: (10, 17), 25: (11, 15),
}


def hide_scraper():
    f = Frame()
    for y, (x0, x1) in SCRAPER_ROWS.items():
        lean = (25 - y) / 5.0
        for x in range(x0, x1 + 1):
            # three long facets: lit flank, flat back, shaded flank
            f.put(x, y, FL[1] if x < 14 + lean else FL[0] if x < 16.5 + lean and y > 11 else FL[2])
    # steep retouch round the working end: short flakes fanning from the edge
    f.pts(FL[0], (17, 6), (19, 6), (15, 7), (14, 8), (13, 10), (16, 8), (18, 8), (20, 8), (22, 8))
    f.pts(FL[3], (18, 6), (20, 6), (21, 6), (16, 7), (23, 7), (24, 8), (24, 9), (25, 10), (25, 11),
          (15, 9), (17, 9), (19, 9), (21, 9), (23, 9))
    f.pts(FL[1], (18, 7), (20, 7), (22, 7), (16, 10), (18, 10), (20, 10), (22, 10))
    f.pts(FL[2], (17, 7), (19, 7), (21, 7), (14, 9), (17, 11), (19, 11), (21, 11))
    # shaded right edge and edge damage down the flanks
    f.pts(FL[3], (24, 12), (24, 13), (24, 14), (23, 15), (23, 16), (22, 17), (22, 18), (21, 19), (21, 20),
          (20, 21), (19, 22), (18, 23), (17, 24), (15, 25), (14, 25))
    f.pts(FL[0], (12, 14), (11, 17), (10, 21)); f.pts(FL[2], (12, 16), (11, 19), (11, 23))
    # bulb of percussion and its ripple at the butt
    f.pts(FL[0], (12, 22), (13, 23)); f.pts(FL[2], (13, 21), (14, 22), (15, 23)); f.pts(FL[3], (14, 24))
    f.outline()
    return f


# -------------------------------------------------------------- bone needle

def bone_needle():
    f = Frame()
    # the needle: thin polished bone, flattened head with a drilled eye
    n = Frame()
    bar(n, (7.5, 20.5), (23.5, 4.5), lambda t: 0.72 if t > 0.16 else 1.2,
        lambda s, t: BN[0] if s < 0 else BN[2])
    n.pts(BN[0], (24, 3)); n.pts(BN[1], (6, 21), (7, 22)); n.pts(BN[0], (6, 20))
    n.outline()
    n.pts(OUT, (8, 20))                                                           # the eye
    f.over(n)
    # sinew thread through the eye
    t = Frame()
    trace(t, CD[0], (8, 21), (9, 23), (8, 26), (6, 28), (4, 28))
    t.pts(CD[1], (9, 23), (8, 26), (4, 28))
    f.px.update({k: v for k, v in t.px.items() if k not in f.px})
    # the awl: a splinter of long bone, the joint end left as its handle
    a = Frame()
    bar(a, (15.5, 26.5), (27.5, 14.5), lambda t: 0.4 + 1.5 * (1.0 - t) ** 0.8,
        lambda s, t: BN[1] if s < -0.2 else BN[2] if s < 0.45 else BN[3])
    a.pts(BN[0], (14, 25), (15, 24), (16, 23)); a.pts(BN[1], (13, 26), (14, 27), (13, 25), (14, 26))
    a.pts(BN[2], (15, 28), (14, 28)); a.pts(BN[3], (16, 28), (17, 27)); a.pts(BN[0], (28, 14))
    a.outline()
    f.over(a)
    return f


# -------------------------------------------------------------- flint knife

def flint_knife():
    f = Frame()

    def blade(s, t):
        scar = int(t * 6.0 + (0.5 if s > 0 else 0.0)) % 2      # flakes struck in from each edge
        if s < -0.62:
            return FL[0] if scar else FL[1]                     # thin lit cutting edge
        if s < -0.1:
            return FL[1]
        if s < 0.12:
            return FL[0] if 0.12 < t < 0.8 else FL[1]           # the ridge between the two faces
        if s < 0.62:
            return FL[2]
        return FL[3] if scar else FL[2]

    # leaf blade: full behind the middle, drawn out to the point
    bar(f, (12.5, 19.5), (28.0, 4.0),
        lambda t: 0.45 + 3.1 * min(1.0, 0.55 + 2.2 * t) * (1.0 - t) ** 0.75, blade)
    f.pts(FL[0], (28, 3)); f.pts(FL[3], (20, 15), (23, 12)); f.pts(FL[2], (17, 13), (20, 10))
    # grip: the tang bedded in a hide wrap, bound with sinew
    bar(f, (5.5, 26.5), (13.5, 18.5), lambda t: 1.75 + 0.35 * t,
        lambda s, t: (CD[0] if s < -0.3 else CD[1] if s < 0.4 else CD[2]) if int(t * 7.0) % 2 == 0
        else (CD[1] if s < 0.1 else CD[2]))
    f.pts(CD[1], (4, 27), (5, 28)); f.pts(CD[0], (4, 26)); f.pts(CD[2], (6, 28), (5, 27))   # knotted tail
    f.outline()
    return f


# --------------------------------------------------------------- stone adze

def stone_adze():
    f = Frame()
    # elbow haft cut from a branch and the trunk it grew from
    bar(f, (5.5, 28.5), (16.5, 8.5), lambda t: 1.5 - 0.2 * t, three(WD))
    bar(f, (16.0, 7.5), (22.5, 15.5), 1.7, three(WD, -0.4, 0.3))
    f.pts(WD[0], (15, 7), (16, 6)); f.pts(WD[1], (17, 6)); f.pts(WD[2], (15, 11), (16, 11))
    f.pts(WD[3], (5, 28), (6, 29)); f.pts(WD[2], (8, 23), (11, 17))
    f.outline()
    # blade: ground stone seated on the foot, flaring to a bevelled edge
    b = Frame()
    bar(b, (20.0, 12.0), (26.5, 20.0), lambda t: 1.9 + 1.5 * t,
        lambda s, t: (FL[0] if s < 0.2 else FL[2]) if t > 0.86 else FL[1] if s < -0.1 else FL[2] if s < 0.6 else FL[3])
    b.outline()
    f.over(b)
    # lashing bound across foot and blade
    bar(f, (19.5, 11.5), (22.5, 15.2), 2.4,
        lambda s, t: None if int(t * 5.0) % 2 else CD[0] if s < -0.1 else CD[1] if s < 0.55 else CD[2])
    return f


STATES = {
    'atlatl': atlatl(),
    'atlatl_loaded': atlatl_loaded(),
    'atlatl_dart': atlatl_dart(),
    'bola': bola(),
    'javelin': javelin(),
    'stone_club': stone_club(),
    'digging_stick': digging_stick(),
    'hand_axe': hand_axe(),
    'hide_scraper': hide_scraper(),
    'bone_needle': bone_needle(),
    'stone_adze': stone_adze(),
    'flint_knife': flint_knife(),
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


def write_preview(path, scale=8, per_row=6):
    cell = 32 * scale
    rows = -(-len(STATES) // per_row)
    band = cell + 80
    sheet = Image.new('RGBA', (cell * per_row, band * rows), DARK + (255,))
    for i, fr in enumerate(STATES.values()):
        ox, oy = i % per_row * cell, i // per_row * band
        tile = Image.new('RGBA', (32, 32), GROUND + (255,))
        tile.alpha_composite(fr.image())
        sheet.alpha_composite(tile.resize((cell, cell), Image.NEAREST), (ox, oy))
        sheet.alpha_composite(fr.image(), (ox + 16, oy + cell + 24))
        sheet.alpha_composite(tile.resize((64, 64), Image.NEAREST), (ox + 64, oy + cell + 8))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.convert('RGB').save(path)


def main():
    write_dmi(ROOT / 'icons/obj/stone_age_arms.dmi', STATES)
    if '--preview' in sys.argv[1:-1]:
        write_preview(sys.argv[sys.argv.index('--preview') + 1])


if __name__ == '__main__':
    main()
