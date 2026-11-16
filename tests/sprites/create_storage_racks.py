"""Hand-placed 32px storage racks, drawn empty: the Stone Age peg post, the
wooden tool rack, the weapon rack, the coat stand and the clothes rail. Every
pixel is placed by this script from a fixed palette (Pillow only); no external
or generated artwork. The outline, wood, bark, cord, stone and earth tones are
the ones create_stone_age_storage.py uses for icons/obj/stone_age_storage.dmi,
lit from the upper left.

The game lays the held items over the rack itself, scaled down and centred on
the points in ITEM_CENTRES (image pixels, origin at the top left), so each of
those spots is a bare peg, notch, hook or hanger with clear space under it.

Run with Pillow to reproduce icons/obj/storage_racks.dmi. `--preview <png>`
also writes a labelled review sheet (4x, on grass, dirt and a wood floor, and
once more with placeholder blobs at the item centres).
Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]

OUT = (62, 49, 34)
# raw hide
HD = [(216, 172, 122), (182, 136, 92), (144, 102, 66), (102, 70, 44), (56, 38, 24)]
# split and planed wood
WD = [(198, 151, 106), (168, 122, 76), (122, 84, 50), (92, 61, 34)]
# pale peeled sticks, pegs and turned hooks
PW = [(214, 180, 132), (184, 146, 98), (140, 104, 64)]
# bark
BK = [(150, 118, 86), (122, 92, 64), (96, 70, 48), (74, 53, 36), (54, 38, 27)]
# plant-fibre cord
CD = [(205, 185, 143), (156, 131, 96), (112, 90, 62)]
# river stones
ST = [(170, 168, 160), (136, 134, 128), (104, 102, 98), (76, 74, 72)]
# dug earth and the dark of a hollow
ER = [(156, 118, 78), (128, 94, 60), (100, 72, 46), (74, 52, 34)]
PD = [(60, 43, 30), (42, 30, 22), (26, 19, 15)]
# preview backgrounds and placeholder items
GRASS = (86, 128, 62)
DIRT = (134, 102, 70)
WOOD = (150, 112, 72)
DARK = (30, 32, 36)
MARK = [(92, 150, 214), (214, 96, 84), (232, 196, 80), (126, 196, 120), (190, 126, 208)]

# where the game centres each held item
ITEM_CENTRES = {
    'peg_post': ((9, 13), (22, 13), (9, 22), (22, 22)),
    'tool_rack': ((7, 15), (12, 15), (17, 15), (22, 15), (27, 15)),
    'weapon_rack': ((9, 15), (14, 15), (19, 15), (24, 15)),
    'coat_stand': ((10, 12), (22, 12), (9, 19), (23, 19)),
    'clothes_rail': ((7, 16), (12, 16), (17, 16), (22, 16), (27, 16)),
}


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


def shadow(points, a=70):
    f = Frame()
    for x, y in points:
        f.put(x, y, (20, 16, 12), a)
    return f


def upright(f, x0, x1, y0, y1, pal, seed=0):
    """A standing timber: lit on its left edge, shaded on its right, with a
    few fixed flecks of grain."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            i = 0 if x == x0 and x1 - x0 >= 2 else len(pal) - 2 if x == x1 else 1
            if x == x0 and x1 - x0 < 2:
                i = 0 if noise(x, y // 3, seed) > 0.45 else 1
            f.put(x, y, clamp(i, pal))


def beam(f, x0, x1, y0, y1, pal, seed=0):
    """A lying timber: lit along the top, shaded along the bottom, the grain
    running along it."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            i = 0 if y == y0 else 2 if y == y1 else 1
            n = noise(x // 4, y, seed)
            if y not in (y0, y1) and n > 0.78:
                i = 2 if noise(x // 4, y, seed + 1) > 0.5 else 0
            f.put(x, y, clamp(i, pal))


def stone(f, cx, cy, rx, ry):
    s = Frame()
    blob(s, cx, cy, rx, ry, ST)
    s.outline()
    f.over(s)


# ----------------------------------------------------------------- peg post

def peg_post():
    """A stout forked branch set upright in a ring of stones, with four peeled
    pegs lashed across it with cord. Peg tips at (9,8) (22,8) (9,17) (22,17)."""
    f = Frame()
    # the trunk, in its bark
    for y in range(7, 29):
        for x in range(14, 18):
            i = (1, 2, 2, 3)[x - 14]
            n = noise(x, y // 3, 51)
            if n > 0.8:
                i += 1                                                           # furrows down the bark
            elif n < 0.16 and x < 17:
                i -= 1
            f.put(x, y, clamp(i, BK))
    # the fork
    bar(f, (15.0, 8.5), (11.6, 2.4), 1.15, three(BK[0:3], -0.2, 0.45))
    bar(f, (17.0, 8.5), (20.6, 3.2), 1.15, three(BK[1:4], -0.3, 0.4))
    f.pts(PW[0], (11, 2), (12, 2)); f.pts(PW[1], (20, 3), (21, 3))               # the broken ends
    f.pts(BK[4], (15, 7), (16, 8), (16, 9))                                      # the crotch of the fork
    f.pts(BK[0], (14, 13), (14, 14), (14, 22))
    f.pts(BK[4], (16, 13), (16, 14), (15, 23), (15, 24))                         # a split in the bark
    f.outline()
    # the pegs: peeled sticks, tipped a little upward at the free end
    p = Frame()
    for py in (8, 17):
        for x in range(8, 14):
            y = py - (1 if x < 11 else 0)
            p.put(x, y, PW[0]); p.put(x, y + 1, PW[1] if x > 8 else PW[2])
            mx = 31 - x
            p.put(mx, y, PW[0] if mx < 23 else PW[1]); p.put(mx, y + 1, PW[2])
        p.pts(PW[2], (13, py + 1), (18, py), (18, py + 1))                       # shaded under the lashing
    p.outline()
    f.over(p)
    # the cord lashings, crossed over the trunk
    for py in (8, 17):
        for x in range(14, 18):
            for dy in (0, 1, 2):
                i = (0 if (x + dy) % 2 == 0 else 1) + (1 if x == 17 or dy == 2 else 0)
                f.put(x, py + dy, CD[i])
        f.pts(OUT, (14, py - 1), (15, py - 1), (16, py - 1), (17, py - 1))
        f.pts(CD[1], (17, py + 3)); f.pts(CD[0], (18, py + 4)); f.pts(CD[2], (18, py + 3))  # the loose end of the knot
    # the footing: packed earth and wedging stones
    b = Frame()
    for y in range(26, 30):
        for x in range(8, 24):
            if math.hypot((x + 0.5 - 16.0) / 8.2, (y + 0.5 - 29.5) / 4.2) <= 1.0:
                n = noise(x, y, 52)
                b.put(x, y, clamp((1 if x < 15 else 2) + (1 if n > 0.75 else -1 if n < 0.15 else 0), ER))
    b.outline()
    f.over(b)
    stone(f, 11.6, 27.6, 2.5, 2.0)
    stone(f, 20.6, 27.8, 2.5, 1.9)
    stone(f, 16.2, 28.6, 2.1, 1.5)
    f.under(shadow([(x, 30) for x in range(12, 26)] + [(x, 29) for x in range(23, 27)] + [(26, 28)]))
    return f


# ---------------------------------------------------------------- tool rack

def tool_rack():
    """A broad plank on two legs with five pegs driven into its face, and a
    low stretcher. Pegs at y 6-7, x 7 12 17 22 27."""
    f = Frame()
    upright(f, 3, 4, 10, 27, WD[1:], 61)
    upright(f, 29, 30, 10, 27, WD[1:], 62)
    beam(f, 5, 28, 23, 24, WD[1:], 63)                                           # the stretcher
    beam(f, 3, 6, 28, 29, WD[1:], 64)                                            # feet
    beam(f, 27, 30, 28, 29, WD[1:], 65)
    # the peg plank
    for y in range(4, 10):
        for x in range(3, 31):
            i = 0 if y == 4 else 3 if y == 9 else 2 if y == 8 else 1
            n = noise(x // 5, y, 66)
            if y in (5, 6, 7) and n > 0.7:
                i = 2 if noise(x // 5, y, 67) > 0.45 else 0                      # grain
            if x == 30:
                i = max(i, 2)
            f.put(x, y, WD[i])
    f.pts(PD[0], (4, 6), (29, 6)); f.pts(WD[0], (4, 7), (29, 7))                 # the trenails into the legs
    f.pts(WD[3], (3, 10), (4, 10), (29, 10), (30, 10))                           # the plank's shadow on the legs
    f.pts(WD[3], (5, 25), (28, 25))
    f.outline()
    for x in (7, 12, 17, 22, 27):
        f.pts(PW[0], (x - 1, 6), (x, 6), (x - 1, 7)); f.pts(PW[1], (x, 7))
        f.pts(OUT, (x - 1, 8), (x, 8), (x + 1, 7), (x + 1, 8), (x + 1, 6))       # the peg's shadow
        f.pts(PD[0], (x, 9), (x + 1, 9))
    f.under(shadow([(x, 30) for x in range(5, 31)] + [(31, 29), (31, 30)]))
    return f


# -------------------------------------------------------------- weapon rack

def weapon_rack():
    """Two posts carrying a notched crossbar over a trough where the butts
    rest. Notches at x 9 14 19 24, bar at y 5-9, trough at y 24-28."""
    f = Frame()
    upright(f, 4, 5, 3, 25, WD[1:], 71)
    upright(f, 28, 29, 3, 25, WD[1:], 72)
    f.pts(WD[0], (4, 3), (28, 3)); f.pts(WD[1], (5, 3), (29, 3))
    # the crossbar: its top face, then the front face the notches are cut into
    for y in range(5, 10):
        for x in range(3, 31):
            i = 0 if y <= 6 else 1 if y == 7 else 2 if y == 8 else 3
            if y == 6 and noise(x // 3, y, 73) > 0.6:
                i = 1
            f.put(x, y, WD[i])
    for x in (9, 14, 19, 24):
        for y in range(6, 10):
            f.pts(PD[1], (x - 1, y)); f.pts(PD[0], (x, y), (x + 1, y))
        f.pts(PD[2], (x - 1, 6), (x, 6), (x + 1, 6))
        f.pts(WD[1], (x - 1, 5), (x, 5), (x + 1, 5))                             # the back of the notch
    f.pts(PD[0], (4, 7), (29, 7))                                                # pegged to the posts
    f.pts(WD[3], (4, 10), (5, 10), (28, 10), (29, 10))
    # the trough: back board, dark hollow, front board
    for x in range(3, 31):
        f.put(x, 23, WD[1] if x < 29 else WD[2])
        f.put(x, 24, PD[0] if 4 <= x <= 29 else WD[1])
        f.put(x, 25, PD[1] if 4 <= x <= 29 else WD[1])
        f.put(x, 26, WD[0]); f.put(x, 27, WD[1] if noise(x // 4, 27, 74) < 0.75 else WD[2]); f.put(x, 28, WD[2])
    f.pts(PD[0], (4, 24), (5, 24), (4, 25)); f.pts(WD[2], (30, 26), (30, 27)); f.pts(WD[3], (30, 28))
    for x in (9, 14, 19, 24):
        f.pts(PD[2], (x, 25), (x - 1, 25), (x + 1, 25))                           # worn cups for the butts
    f.pts(PD[0], (5, 27), (28, 27))                                              # trenails
    for x0 in (4, 26):
        f.pts(WD[2], (x0, 29), (x0 + 1, 29), (x0 + 2, 29)); f.pts(WD[3], (x0 + 3, 29))
    f.outline()
    f.under(shadow([(x, 30) for x in range(8, 31)] + [(31, 29), (31, 30)]))
    return f


# --------------------------------------------------------------- coat stand

def coat_stand():
    """A turned pole with a knob on top, on three splayed feet, with two pairs
    of upturned hooks. Hook tips at (11,7) (21,7) (9,14) (23,14)."""
    f = Frame()
    # the feet
    bar(f, (15.5, 24.0), (8.6, 28.6), 1.0, three(WD[0:3], -0.2, 0.4))
    bar(f, (17.5, 24.0), (24.4, 28.6), 1.0, three(WD[1:4], -0.3, 0.3))
    f.pts(WD[1], (7, 29), (8, 29), (9, 29)); f.pts(WD[2], (24, 29), (25, 29)); f.pts(WD[3], (26, 29))
    upright(f, 15, 17, 25, 29, WD, 81)                                           # the foot toward the viewer
    f.pts(WD[1], (15, 30), (16, 30)); f.pts(WD[2], (17, 30))
    # the pole and its turnings
    upright(f, 15, 17, 6, 25, WD, 82)
    for y, wide in ((6, 1), (10, 1), (11, 1), (17, 1), (18, 1), (22, 1), (23, 1)):
        for x in range(15 - wide, 18 + wide):
            f.put(x, y, WD[0] if x <= 15 else WD[1] if x == 16 else WD[2] if x == 17 else WD[3])
    f.pts(WD[3], (15, 7), (16, 7), (17, 7), (15, 12), (16, 12), (17, 12), (15, 19), (16, 19), (17, 19),
          (15, 24), (16, 24), (17, 24))                                          # shade under each collar
    f.pts(WD[2], (15, 21), (15, 9), (15, 16))
    blob(f, 16.5, 3.5, 2.6, 2.6, WD)                                             # the knob
    # the hooks
    f.pts(PW[1], (13, 10), (12, 9), (19, 10)); f.pts(PW[0], (11, 8), (11, 7), (21, 7)); f.pts(PW[2], (20, 9), (21, 8))
    f.pts(PW[1], (13, 17), (12, 17), (11, 17), (10, 16), (19, 17), (20, 17))
    f.pts(PW[0], (9, 15), (9, 14), (23, 14)); f.pts(PW[2], (21, 17), (22, 16), (23, 15))
    f.outline()
    f.under(shadow([(x, 30) for x in range(9, 15)] + [(x, 30) for x in range(19, 28)] + [(x, 31) for x in range(15, 20)]))
    return f


# ------------------------------------------------------------- clothes rail

def clothes_rail():
    """Two posts on feet carrying a peeled pole, with five little wooden
    hangers tied along it. Pole at y 5-6, hangers at x 7 12 17 22 27."""
    f = Frame()
    upright(f, 4, 5, 3, 27, WD[1:], 91)
    upright(f, 28, 29, 3, 27, WD[1:], 92)
    f.pts(WD[0], (4, 2), (28, 2)); f.pts(WD[1], (5, 2), (29, 2))                 # rounded tops
    beam(f, 6, 27, 25, 26, WD[1:], 93)                                           # the stretcher
    beam(f, 3, 6, 28, 29, WD[1:], 94)                                            # feet
    beam(f, 27, 30, 28, 29, WD[1:], 95)
    # the pole, peeled pale, resting across the posts
    for x in range(3, 31):
        f.put(x, 5, PW[0]); f.put(x, 6, PW[1] if x % 7 else PW[2])
    f.pts(PW[2], (30, 5), (30, 6), (3, 6))
    f.pts(WD[3], (4, 7), (5, 7), (28, 7), (29, 7))
    f.pts(CD[0], (4, 5), (28, 5)); f.pts(CD[1], (5, 5), (4, 6), (29, 5), (28, 6)); f.pts(CD[2], (5, 6), (29, 6))  # lashed on
    f.outline()
    for x in (7, 12, 17, 22, 27):
        f.pts(CD[0], (x, 4)); f.pts(CD[1], (x, 5), (x, 6)); f.pts(CD[2], (x, 7))  # the tie over the pole
        f.pts(PW[0], (x, 8), (x - 1, 9)); f.pts(PW[2], (x + 1, 9))                # the hanger
        f.pts(OUT, (x, 9))
    f.under(shadow([(x, 30) for x in range(4, 32)]))
    return f


STATES = {
    'peg_post': peg_post(),
    'tool_rack': tool_rack(),
    'weapon_rack': weapon_rack(),
    'coat_stand': coat_stand(),
    'clothes_rail': clothes_rail(),
}
COLUMNS = 5


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


def placeholders(name):
    """Stand-in items for the review sheet only: a small coloured lump centred
    on each item centre, with the centre pixel itself marked white."""
    f = Frame()
    centres = ITEM_CENTRES[name]
    rx = 2.5 if len(centres) == 5 else 3.0 if name == 'weapon_rack' else 4.0
    ry = 7.5 if name == 'weapon_rack' else 5.5 if len(centres) == 5 else 4.0
    for k, (cx, cy) in enumerate(centres):
        for y in range(32):
            for x in range(32):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    f.put(x, y, MARK[k % len(MARK)], 215)
        f.put(cx, cy, (255, 255, 255))
    return f


def write_preview(path, scale=4, per_row=2):
    """Each state at 4x on grass, dirt and a wood floor, then on dirt with the
    placeholder items hung on it, labelled, with the 1x sprites underneath."""
    cell = 32 * scale
    pad, label = 10, 16
    kinds = ('grass', 'dirt', 'wood', 'items')
    box_w, box_h = (cell + 6) * len(kinds) - 6 + pad * 2, label + cell + 44 + pad * 2
    rows = -(-len(STATES) // per_row)
    sheet = Image.new('RGBA', (box_w * per_row, box_h * rows), DARK + (255,))
    draw = ImageDraw.Draw(sheet)
    floors = {'grass': ground(GRASS, 31), 'dirt': ground(DIRT, 32), 'wood': ground(WOOD, 33, planks=True)}
    floors['items'] = floors['dirt']
    for i, (name, fr) in enumerate(STATES.items()):
        ox, oy = i % per_row * box_w + pad, i // per_row * box_h + pad
        draw.text((ox, oy), name, fill=(232, 228, 214))
        for j, kind in enumerate(kinds):
            tile = floors[kind].copy()
            tile.alpha_composite(fr.image())
            if kind == 'items':
                tile.alpha_composite(placeholders(name).image())
            x = ox + j * (cell + 6)
            sheet.alpha_composite(tile.resize((cell, cell), Image.NEAREST), (x, oy + label))
            sheet.alpha_composite(tile, (x, oy + label + cell + 6))
            draw.text((x + 38, oy + label + cell + 14), kind, fill=(150, 150, 140))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.convert('RGB').save(path)


def main():
    write_dmi(ROOT / 'icons/obj/storage_racks.dmi', STATES)
    if '--preview' in sys.argv[1:-1]:
        write_preview(sys.argv[sys.argv.index('--preview') + 1])


if __name__ == '__main__':
    main()
