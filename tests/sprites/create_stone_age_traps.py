"""Hand-placed 32px Stone Age traps: the twine snare, the figure-4 deadfall,
the covered and staked pit, and the wicker fish weir. Every pixel is placed
by this script from a fixed palette (Pillow only); no external or generated
artwork.
The outline, wood, cord and cobble tones are the ones create_stone_age_arms.py
uses for icons/obj/stone_age_arms.dmi, lit from the upper left. The set traps
are drawn without a tile background so the floor or the river shows through;
the covered pit is mostly translucent on purpose.

Run with Pillow to reproduce icons/obj/stone_age_traps.dmi. `--preview <png>`
also writes a labelled review sheet (4x, on grass and on dirt or water).
Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]

OUT = (62, 49, 34)
# wood, light to dark
WD = [(198, 151, 106), (168, 122, 76), (122, 84, 50), (92, 61, 34)]
# pale peeled wood: stakes, trigger sticks, withies
PW = [(214, 180, 132), (184, 146, 98), (140, 104, 64)]
# green sapling bark
SP = [(150, 142, 84), (116, 108, 62), (82, 76, 46)]
# plant-fibre twine
CD = [(205, 185, 143), (156, 131, 96), (112, 90, 62)]
# flat river stone
ST = [(170, 168, 160), (136, 134, 128), (104, 102, 98), (76, 74, 72)]
# leaves
LF = [(122, 156, 70), (90, 126, 52), (62, 94, 40), (44, 70, 32)]
# dry leaves in the pit cover
DL = [(170, 150, 78), (136, 112, 56), (104, 84, 44)]
# dug earth, light to dark, and the dark of the pit
ER = [(156, 118, 78), (128, 94, 60), (100, 72, 46), (74, 52, 34)]
PD = [(60, 43, 30), (42, 30, 22), (26, 19, 15)]
# fish seen through the water
FI = [(206, 214, 206), (150, 162, 158), (86, 98, 100)]
RIPPLE = (214, 232, 236)
# preview backgrounds
GRASS = (86, 128, 62)
DIRT = (134, 102, 70)
WATER = (62, 112, 152)
DARK = (30, 32, 36)


def noise(x, y, seed=0):
    """A fixed 0..1 value per pixel, so the sheet is reproducible."""
    n = (x * 374761393 + y * 668265263 + seed * 2147483647) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


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


def trace(f, c, *points, a=255):
    """A one-pixel cord through the given points."""
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            f.put(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), c, a)


def bend(p0, p1, p2, n=40):
    """Points along a quadratic curve from p0 to p2, pulled toward p1."""
    out = []
    for i in range(n + 1):
        t = i / n
        a, b, c = (1 - t) ** 2, 2 * t * (1 - t), t * t
        out.append((a * p0[0] + b * p1[0] + c * p2[0], a * p0[1] + b * p1[1] + c * p2[1]))
    return out


def tube(f, points, radius, pal):
    """A bent pole through `points`; `radius(t)` thins it along the way."""
    n = len(points) - 1
    for y in range(32):
        for x in range(32):
            best, bi = 99.0, 0
            for i, (sx, sy) in enumerate(points):
                d = math.hypot(x + 0.5 - sx, y + 0.5 - sy)
                if d < best:
                    best, bi = d, i
            r = radius(bi / n) if callable(radius) else radius
            if best <= r:
                sx, sy = points[bi]
                s = ((x + 0.5 - sx) + (y + 0.5 - sy)) / (r * 1.4142)
                f.put(x, y, pal[0] if s < -0.3 else pal[1] if s < 0.35 else pal[2])


def ring(f, cx, cy, rx, ry, shade, gap=None):
    """A one-pixel cord loop; `shade(angle)` picks the colour."""
    steps = 96
    for i in range(steps):
        a = 2 * math.pi * i / steps
        if gap and gap[0] <= a <= gap[1]:
            continue
        c = shade(a)
        f.put(int(math.floor(cx + rx * math.cos(a))), int(math.floor(cy + ry * math.sin(a))), c[:3],
              c[3] if len(c) > 3 else 255)


def cord_shade(a):
    """Lit on the upper left of the loop, shaded on the lower right."""
    s = math.cos(a) + math.sin(a)
    return CD[0] if s < -0.4 else CD[1] if s < 0.7 else CD[2]


def stick(f, p0, p1, half=0.9, pal=PW):
    bar(f, p0, p1, half, three(pal))


def leaf(f, x, y, kind, pal=LF, a=255):
    """A small leaf; `kind` picks one of four lies."""
    shapes = (((0, 0), (1, 0), (1, 1), (2, 1)), ((0, 1), (1, 1), (1, 0), (2, 0)),
              ((0, 0), (0, 1), (1, 1), (1, 2)), ((0, 0), (1, 0), (0, 1)))
    for i, (dx, dy) in enumerate(shapes[kind % 4]):
        f.put(x + dx, y + dy, pal[0] if i == 0 else pal[1] if i < 3 else pal[2], a)


def shadow(points, a=70):
    f = Frame()
    for x, y in points:
        f.put(x, y, (20, 16, 12), a)
    return f


# -------------------------------------------------------------------- snare

def snare():
    """The carried snare: a springy stick with the twine noose coiled on it."""
    f = Frame()
    tube(f, bend((5.5, 27.5), (11.0, 14.0), (24.5, 5.5)), lambda t: 1.35 - 0.45 * t, SP)
    f.pts(SP[2], (11, 17), (16, 10)); f.pts(SP[0], (8, 20))                     # bark knots
    f.pts(PW[0], (5, 28), (4, 27)); f.pts(PW[1], (5, 29))                        # cut butt
    f.outline()
    c = Frame()
    ring(c, 19.0, 21.0, 6.2, 5.0, cord_shade)                                    # the open noose
    ring(c, 18.0, 21.5, 4.0, 3.0, cord_shade, gap=(0.2, 1.6))                    # a second turn of the coil
    trace(c, CD[1], (24, 7), (26, 11), (25, 15), (24, 17))                       # running end up to the tip
    c.pts(CD[0], (24, 6), (25, 9), (24, 17))
    c.outline()
    c.pts(CD[0], (23, 16), (24, 16)); c.pts(CD[2], (25, 17), (24, 18))           # slip knot
    f.over(c)
    # a couple of turns of twine binding the cord to the tip
    f.pts(CD[0], (22, 7), (23, 6)); f.pts(CD[1], (23, 7), (24, 8))
    return f


def snare_set():
    """Set: the sapling bent over, the noose held open just above the ground
    by the trigger peg."""
    f = Frame()
    tube(f, bend((27.0, 28.5), (27.0, 6.0), (12.0, 9.5)), lambda t: 1.25 - 0.55 * t, SP)
    f.pts(SP[2], (26, 20), (24, 11)); f.pts(LF[1], (11, 8), (10, 9)); f.pts(LF[0], (10, 8))
    f.outline()
    f.pts(ER[2], (25, 30), (26, 30), (28, 30), (29, 29)); f.pts(ER[1], (27, 30))  # earth at the foot
    # trigger peg driven into the ground, with the toggle hooked under its notch
    p = Frame()
    p.pts(PW[0], (15, 16), (15, 17), (15, 18), (15, 19)); p.pts(PW[1], (16, 17), (16, 18), (16, 19), (15, 20), (16, 20))
    p.pts(PW[2], (16, 21), (15, 21), (16, 16))
    p.pts(PW[0], (10, 18), (11, 18), (12, 18)); p.pts(PW[1], (13, 18), (14, 18))  # toggle
    p.outline()
    p.pts(WD[3], (14, 18))                                                        # the notch
    f.over(p)
    # the taut cord from sapling tip to the toggle
    trace(f, CD[1], (12, 10), (12, 16)); f.pts(CD[0], (12, 11), (12, 14))
    # noose lying open, no outline so it stays low and quiet
    loop = ((11, 20), (10, 21), (8, 22), (7, 23), (6, 24), (6, 25), (6, 26), (7, 27), (8, 28), (9, 28), (10, 29),
            (11, 29), (12, 29), (13, 29), (14, 28), (15, 28), (16, 27), (17, 26), (17, 25), (17, 24), (16, 23),
            (15, 22), (13, 21), (12, 20), (9, 21), (14, 21), (11, 19))
    for (x, y) in loop:
        f.put(x, y, CD[0] if x + y < 33 else CD[1])
    for (x, y) in loop:
        if y >= 26 and (x, y + 1) not in f.px:
            f.put(x, y + 1, (20, 16, 12), 70)
    return f


def snare_sprung():
    """Sprung: the sapling upright again, the noose drawn tight on its cord."""
    f = Frame()
    tube(f, bend((27.0, 28.5), (26.0, 14.0), (22.5, 3.5)), lambda t: 1.25 - 0.55 * t, SP)
    f.pts(SP[2], (26, 20), (25, 11)); f.pts(LF[1], (22, 2), (21, 3)); f.pts(LF[0], (21, 2))
    f.outline()
    f.pts(ER[2], (25, 30), (26, 30), (28, 30), (29, 29)); f.pts(ER[1], (27, 30))
    c = Frame()
    trace(c, CD[1], (22, 5), (19, 10), (16, 16)); c.pts(CD[0], (21, 6), (19, 10), (17, 14))
    ring(c, 15.5, 19.5, 1.6, 2.6, cord_shade)                                    # the closed loop
    c.pts(PW[0], (15, 15), (16, 15)); c.pts(PW[1], (17, 15), (18, 16))           # the toggle swinging on the cord
    c.outline()
    f.over(c)
    # the peg left in the ground
    p = Frame()
    p.pts(PW[0], (9, 24), (9, 25)); p.pts(PW[1], (10, 24), (10, 25), (9, 26), (10, 26)); p.pts(PW[2], (10, 27), (9, 27))
    p.outline()
    f.over(p)
    return f


# ----------------------------------------------------------------- deadfall

def slab(f, cx, cy, rx, ry):
    """The flat stone lying down: a broad top face over a shaded edge."""
    for y in range(32):
        for x in range(32):
            u, v = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if u * u + v * v > 1.0:
                continue
            v2 = (y + 0.5 - (cy - 1.8)) / (ry - 1.0)
            if u * u / 0.96 + v2 * v2 > 1.0:
                f.put(x, y, ST[3] if u > 0.2 else ST[2])                          # the thickness of the slab
            else:
                d = math.hypot(u + 0.5, v2 + 0.55)
                c = ST[0] if d < 0.5 else ST[1] if d < 1.25 else ST[2]
                if noise(x, y, 3) > 0.9:
                    c = ST[2] if c != ST[2] else ST[1]
                f.put(x, y, c)


def notch(f, *points):
    f.pts(WD[3], *points)


def deadfall():
    """The carried kit: the flat stone and its three notched trigger sticks."""
    f = Frame()
    slab(f, 13.5, 20.5, 10.0, 6.5)
    f.pts(ST[2], (9, 18), (10, 19), (11, 19), (16, 21), (17, 22))                 # a crack and a chip
    f.outline()
    s = Frame()
    stick(s, (15.5, 6.5), (26.5, 15.5), 0.95)
    stick(s, (20.5, 4.5), (28.5, 9.5), 0.95)
    stick(s, (18.5, 12.5), (27.5, 21.5), 0.95)
    s.outline()
    notch(s, (21, 11), (24, 7), (23, 17), (19, 13))
    f.over(s)
    return f


def deadfall_set():
    """Set: the stone leaning on the figure-4 - upright, slanted lever and the
    bait stick reaching under the stone."""
    f = Frame()
    # the stone, its low edge on the ground at the left
    bar(f, (4.5, 25.5), (24.0, 9.5), lambda t: 3.3 + 0.9 * math.sin(t * math.pi),
        lambda s, t: (ST[0] if 0.1 < t < 0.75 else ST[1]) if s < -0.45 else ST[1] if s < 0.25
        else ST[2] if s < 0.7 else ST[3])
    f.pts(ST[2], (10, 18), (11, 18), (12, 17), (17, 13), (18, 13))
    f.outline()
    t = Frame()
    stick(t, (11.5, 22.5), (28.5, 22.5), 0.9)                                    # bait stick
    stick(t, (23.5, 15.5), (23.5, 28.0), 1.0)                                    # upright
    stick(t, (21.5, 9.5), (28.5, 22.0), 0.95)                                    # slanted lever
    t.outline()
    notch(t, (24, 15), (28, 21), (23, 22))
    t.pts(CD[1], (12, 22), (12, 23)); t.pts(CD[0], (11, 22))                     # bait tied on the end
    # the trigger stands behind the stone's lip but in front of its shadow
    for k, v in t.px.items():
        if k not in f.px or k[1] > 19 or k[0] > 21:
            f.px[k] = v
    sh = [(x, y) for y in range(22, 30) for x in range(5, 23) if 2 * (y - 22) <= (x - 2) and x + (y - 22) < 26]
    f.under(shadow(sh, 80))
    return f


def deadfall_sprung():
    """Sprung: the stone flat on the ground, the trigger sticks thrown clear."""
    f = Frame()
    s = Frame()
    stick(s, (20.5, 21.5), (29.5, 26.5), 0.95)                                   # pinned under the edge
    stick(s, (22.5, 6.5), (28.5, 14.5), 0.95)
    stick(s, (3.5, 8.5), (12.5, 6.5), 0.95)
    s.outline()
    notch(s, (26, 11), (8, 7), (27, 25))
    f.over(s)
    st = Frame()
    slab(st, 14.0, 19.0, 11.0, 7.5)
    st.pts(ST[2], (9, 16), (10, 17), (11, 17), (17, 19), (18, 20))
    st.outline()
    f.over(st)
    f.under(shadow([(x, 27) for x in range(8, 22)] + [(x, 28) for x in range(11, 19)], 70))
    return f


# ---------------------------------------------------------------------- pit

def pit_shape(x, y):
    """0 at the middle of the pit, 1 at the outer edge of the dirt rim."""
    u, v = (x + 0.5 - 16.0) / 15.0, (y + 0.5 - 16.0) / 14.6
    r = (abs(u) ** 3.2 + abs(v) ** 3.2) ** (1 / 3.2)
    return r + (noise(x // 2, y // 2, 11) - 0.5) * 0.07


def pit_open():
    f = Frame()
    inner = set()
    for y in range(32):
        for x in range(32):
            r = pit_shape(x, y)
            if r < 0.76:
                inner.add((x, y))
            elif r <= 1.0:
                lit = (x - 16) + (y - 16)                                         # spoil heaped round the lip
                n = noise(x, y, 5)
                c = ER[0] if lit < -12 else ER[1] if lit < 6 else ER[2]
                if n > 0.82:
                    c = ER[min(3, ER.index(c) + 1)]
                elif n < 0.12:
                    c = ER[max(0, ER.index(c) - 1)]
                if r > 0.93:                                                      # ragged outer edge
                    if n > 0.55:
                        continue
                    c = ER[2] if lit > -4 else ER[1]
                f.put(x, y, c)
            elif r <= 1.06 and noise(x, y, 7) > 0.86:
                f.put(x, y, ER[2], 170)                                           # loose crumbs on the grass
    top = {}
    for (x, y) in inner:
        top[x] = min(top.get(x, 99), y)
    left = {}
    for (x, y) in inner:
        left[y] = min(left.get(y, 99), x)
    for (x, y) in inner:
        d = y - top[x]                                                            # how far down the far wall
        n = noise(x, y, 9)
        if d < 2:
            c = ER[3]
        elif d < 5:
            c = PD[0] if n < 0.8 else ER[3]
        elif d < 9:
            c = PD[1] if n < 0.85 else PD[0]
        else:
            c = PD[2] if n < 0.9 else PD[1]
        if x - left[y] < 2 and d >= 2:
            c = PD[0] if d < 9 else PD[1]
        f.put(x, y, c)
    for (x, y) in inner:                                                          # undercut lip along the near edges
        if (x, y - 1) not in inner or (x - 1, y) not in inner:
            f.put(x, y, OUT)
    return f


STAKES = ((8, 14), (13, 11), (19, 12), (24, 15), (10, 21), (16, 19), (22, 22), (15, 26))


def pit_staked():
    """Fire-hardened stakes set in the floor of the pit, points up."""
    f = pit_open()
    for i, (x, y) in enumerate(sorted(STAKES, key=lambda p: p[1])):
        h = 6 + (i % 2)
        for k in range(h):
            yy = y - k
            if k == h - 1:
                f.put(x, yy, PW[0])                                               # the point
            elif k < 2:
                f.put(x, yy, PW[2]); f.put(x + 1, yy, WD[3])                      # foot lost in the dark
            else:
                f.put(x, yy, PW[0] if k > h - 4 else PW[1]); f.put(x + 1, yy, PW[2])
        f.put(x - 1, y - 1, OUT); f.put(x + 2, y, PD[2]); f.put(x + 2, y - 1, PD[2])
        f.put(x + 1, y - h + 1, (60, 46, 40))                                     # charred tip
    return f


def pit_covered():
    """The pit under its lattice of thin branches and leaves. Mostly
    translucent, so whatever floor it is dug in shows through."""
    f = Frame()
    for y in range(32):                                                           # the faintest hint of the hole
        for x in range(32):
            r = pit_shape(x, y)
            if r < 0.7:
                f.put(x, y, PD[2], 34 if r < 0.5 else 22)
            elif 0.84 < r <= 1.0 and noise(x, y, 5) > 0.72:
                f.put(x, y, ER[1], 70)                                            # a little disturbed earth
    twigs = (((3, 9), (28, 5)), ((2, 17), (29, 13)), ((3, 24), (28, 21)), ((6, 28), (27, 27)),
             ((6, 3), (9, 28)), ((14, 2), (16, 29)), ((22, 3), (25, 28)), ((4, 5), (27, 26)), ((27, 8), (7, 25)))
    for i, (p0, p1) in enumerate(twigs):
        t = Frame()
        trace(t, WD[2] if i % 2 else WD[1], p0, p1)
        for (x, y) in t.px:
            n = noise(x, y, 21 + i)
            f.put(x, y, WD[3] if n > 0.8 else WD[2] if i % 2 else WD[1], 150 + int(60 * n))
    spots = ((5, 6), (11, 4), (19, 6), (25, 9), (8, 12), (15, 10), (22, 14), (4, 19), (12, 17), (18, 19),
             (26, 18), (7, 24), (14, 23), (21, 25), (25, 23), (10, 28), (17, 14), (20, 9), (9, 20), (23, 4))
    for i, (x, y) in enumerate(spots):
        pal = DL if i % 5 == 4 else (LF[1:] if i % 2 else LF)
        leaf(f, x, y, i, pal, 215 if i % 3 else 190)
    return f


def pit_cover():
    """The carried cover: branches and leafy brush tied in a bundle."""
    f = Frame()
    for i, (p0, p1) in enumerate((((4.5, 24.5), (25.5, 6.5)), ((5.5, 27.5), (27.5, 9.5)), ((8.5, 28.5), (28.5, 12.5)),
                                  ((3.5, 21.5), (22.5, 4.5)))):
        stick(f, p0, p1, 0.95, WD if i % 2 else SP)
    f.pts(WD[3], (11, 21), (17, 17), (21, 14)); f.pts(SP[2], (9, 20), (20, 10))
    for i, (x, y) in enumerate(((22, 3), (25, 5), (27, 7), (28, 10), (24, 8), (20, 6), (26, 12), (3, 22), (5, 26),
                                (8, 28), (23, 11), (19, 9), (6, 23))):
        leaf(f, x, y, i, DL if i % 6 == 5 else (LF[1:] if i % 2 else LF))
    f.outline()
    # twine wound twice round the middle
    for x0 in (11, 14):
        bar(f, (x0 + 0.5, 14.5), (x0 + 7.5, 22.5), 0.75, lambda s, t: CD[0] if t < 0.35 else CD[1] if t < 0.75 else CD[2])
    f.pts(CD[0], (20, 23), (21, 24)); f.pts(CD[1], (19, 24), (21, 25)); f.pts(OUT, (22, 24), (20, 25), (21, 26), (22, 25))
    return f


# --------------------------------------------------------------------- weir

def weir_stakes():
    """The carried weir: sharpened stakes rolled in a strip of woven withies."""
    f = Frame()
    ux, uy = 0.646, -0.763                                                        # along the stakes
    vx, vy = 0.763, 0.646                                                         # across the bundle
    stakes = []
    for i in range(4):
        o = (i - 1.5) * 3.4
        s = Frame()
        bar(s, (6.5 + o * vx, 25.0 + o * vy), (22.0 + o * vx, 6.7 + o * vy),
            lambda t: min(1.0, 0.2 + 4.5 * t), three(PW))                         # pointed at the lower end
        stakes.append(s)
        f.over(s)
    f.outline()
    # three withies woven over and under across the stakes
    for row, d in enumerate((9.0, 13.5, 18.0)):
        cx, cy = 6.5 + ux * d, 25.0 + uy * d
        w = Frame()
        bar(w, (cx - 7.2 * vx, cy - 7.2 * vy), (cx + 7.2 * vx, cy + 7.2 * vy), 0.9,
            lambda s, t: SP[0] if s < 0.0 else SP[2])
        for i, s in enumerate(stakes):
            if (i + row) % 2:
                for k in s.px:
                    w.px.pop(k, None)                                             # the withy passes behind this stake
        f.over(w)
    return f


def fish(f, x, y, way):
    """A small river fish seen from above, nose toward `way`."""
    body = ((0, 0, 1), (-1, 1, 0), (0, 1, 1), (1, 1, 2), (-1, 2, 0), (0, 2, 1), (1, 2, 2), (-1, 3, 0), (0, 3, 1),
            (1, 3, 2), (0, 4, 1), (0, 5, 2), (-1, 6, 1), (1, 6, 2))                # nose first, tail fork last
    for dx, dy, c in body:
        if way == 'down':
            px, py = x + dx, y - dy
        elif way == 'left':
            px, py = x + dy, y + dx
        else:
            px, py = x - dy, y + dx
        f.put(px, py, FI[c])
    for (px, py) in [k for k, v in f.px.items() if v[3] == 255]:                  # a dark edge so it reads in the water
        for n in ((px - 1, py), (px + 1, py), (px, py - 1), (px, py + 1)):
            if n not in f.px:
                f.put(n[0], n[1], (18, 38, 58), 120)


def weir_base(x):
    """Water line of the fence in column x: two arms meeting at the bottom."""
    return x + 12 if x <= 15 else 43 - x


WEIR_POSTS = (1, 4, 7, 10, 13, 15, 16, 18, 21, 24, 27, 30)


def fish_weir(full=False):
    """A V of stakes and wattle standing in the shallows; the current carries
    fish into the open mouth at the top and they crowd at the point."""
    f = Frame()
    swim = Frame()
    if full:
        fish(swim, 15, 18, 'down')
        fish(swim, 13, 6, 'right')
        fish(swim, 18, 10, 'left')
    fence = Frame()
    # wattle: withies woven between the stakes, four courses above the water
    for x in range(1, 31):
        y = weir_base(x)
        fence.put(x, y, WD[3])                                                    # wet foot
        for k in range(1, 5):
            over = (k + sum(1 for p in WEIR_POSTS if p < x)) % 2
            fence.put(x, y - k, WD[0] if over else WD[2])
    # the stakes stand proud of the wattle
    for x in WEIR_POSTS:
        y = weir_base(x)
        h = 8 if x in (15, 16) else 7
        for k in range(h):
            fence.put(x, y - k, WD[3] if k == 0 else PW[0] if k >= h - 3 else PW[1])
    fence.outline()
    f.over(fence)
    # water line: shade under the fence and a ripple beside each stake
    wet = Frame()
    for (x, y) in fence.px:
        if (x, y + 1) not in fence.px:
            wet.put(x, y + 1, (16, 34, 52), 95)
    for x in WEIR_POSTS:
        y = weir_base(x)
        wet.put(x - 1, y + 2, RIPPLE, 150)
        wet.put(x + 1, y + 2, RIPPLE, 110)
    f.under(wet)
    f.under(swim)
    return f


STATES = {
    'snare': snare(),
    'snare_set': snare_set(),
    'snare_sprung': snare_sprung(),
    'deadfall': deadfall(),
    'deadfall_set': deadfall_set(),
    'deadfall_sprung': deadfall_sprung(),
    'pit_cover': pit_cover(),
    'pit_open': pit_open(),
    'pit_staked': pit_staked(),
    'pit_covered': pit_covered(),
    'weir_stakes': weir_stakes(),
    'fish_weir': fish_weir(),
    'fish_weir_full': fish_weir(True),
}
COLUMNS = 4
IN_WATER = ('fish_weir', 'fish_weir_full')


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


def ground(colour, seed):
    """A flat preview floor with a little fixed speckle."""
    tile = Image.new('RGBA', (32, 32), colour + (255,))
    for y in range(32):
        for x in range(32):
            n = noise(x, y, seed)
            if n > 0.86 or n < 0.1:
                d = 9 if n > 0.5 else -9
                tile.putpixel((x, y), tuple(max(0, min(255, v + d)) for v in colour) + (255,))
    return tile


def write_preview(path, scale=4, per_row=5):
    """Each state at 4x on grass and on dirt (water for the weir), labelled,
    with the 1x sprite on both floors underneath."""
    cell = 32 * scale
    pad, label = 10, 16
    box_w, box_h = cell * 2 + 6 + pad * 2, label + cell + 44 + pad * 2
    rows = -(-len(STATES) // per_row)
    sheet = Image.new('RGBA', (box_w * per_row, box_h * rows), DARK + (255,))
    draw = ImageDraw.Draw(sheet)
    floors = {'grass': ground(GRASS, 31), 'dirt': ground(DIRT, 32), 'water': ground(WATER, 33)}
    for i, (name, fr) in enumerate(STATES.items()):
        ox, oy = i % per_row * box_w + pad, i // per_row * box_h + pad
        draw.text((ox, oy), name, fill=(232, 228, 214))
        kinds = ('grass', 'water') if name in IN_WATER else ('grass', 'dirt')
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
    write_dmi(ROOT / 'icons/obj/stone_age_traps.dmi', STATES)
    if '--preview' in sys.argv[1:-1]:
        write_preview(sys.argv[sys.argv.index('--preview') + 1])


if __name__ == '__main__':
    main()
