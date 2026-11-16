"""Hand-placed sprites for the Industrial-era moveable-frame hive and its kit
in icons/farming/frame_hives.dmi: the white-painted stacked box hive on two
bricks, closed and with the lid off and the frame top bars showing, the five
bee overlays for its entrance slit, the steel hive tool, the tin bellows
smoker cold and smoking, the wooden honey frame with foundation, with drawn
comb and with capped honey, the hand-cranked centrifugal extractor still and
spinning, and the small nucleus box empty and with bees at its hole. Every
pixel is placed by this script from fixed palettes (Pillow only); no external
or generated artwork. Shading is soft, lit from the upper left, with no black
outline, like icons/farming/kept_hives.dmi and the straw `beehive` of
icons/farming/beekeeping.dmi.

The hive, the extractor and the nucleus box stand on the ground in the usual
3/4 view and keep one pixel clear on the left, right and bottom of the 32px
frame. `bees1` to `bees5` are overlays for `frame_hive` and
`frame_hive_open`: the entrance slit is on x = 10-21, y = 25 (rows counted
from the top) with the landing board on the two rows under it, and everything
else in their frames is transparent.

Run with Pillow to write the sheet. `--check` verifies the committed sheet,
`--preview <png>` writes a 4x review sheet of every state and frame on grass
and on dirt, the bee overlays over the hive, and 2x and 1x rows. Released
under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/farming/frame_hives.dmi'

SIZE = 32

# weathered white paint: highlight, light, mid, shade, dark, deep
PAINT = [(252, 250, 240), (238, 236, 224), (216, 218, 212), (186, 192, 196), (150, 160, 172),
         (114, 124, 140)]
# sawn pine: highlight, light, mid, dark, deep
BOARD = [(226, 190, 134), (200, 160, 104), (168, 126, 78), (130, 94, 56), (94, 66, 40)]
# bare weathered wood where the paint has gone
BARE = (158, 142, 120)
HOLE = [(40, 30, 24), (20, 14, 11)]
BRICK = [(190, 110, 84), (160, 84, 62), (126, 62, 48), (92, 46, 38)]
MORTAR = (188, 180, 164)
# tin plate: highlight, light, mid, shade, dark, deep
TIN = [(236, 240, 240), (204, 210, 212), (168, 176, 180), (130, 138, 146), (96, 104, 114),
       (66, 72, 82)]
# tool steel: highlight, light, mid, dark, deep
STEEL = [(232, 236, 240), (192, 198, 206), (148, 156, 166), (104, 112, 124), (70, 76, 88)]
IRON = [(120, 122, 130), (86, 88, 98), (58, 60, 70), (40, 42, 50)]
RED = [(214, 84, 62), (178, 52, 42), (132, 36, 34)]
LEATHER = [(150, 96, 58), (118, 70, 42), (86, 50, 32), (58, 34, 24)]
BRASS = [(250, 220, 120), (214, 170, 66), (160, 116, 40), (108, 76, 28)]
# beeswax foundation and new comb: highlight, light, mid, shade, dark
WAX = [(254, 244, 200), (244, 228, 166), (226, 202, 130), (198, 168, 96), (160, 128, 68)]
# capped honey: highlight, light, mid, shade, dark, deep
HONEY = [(255, 232, 150), (250, 204, 86), (232, 168, 44), (200, 130, 28), (158, 94, 20),
         (112, 62, 16)]
BEE_DARK = (38, 28, 18)
BEE_GOLD = (246, 198, 48)
BEE_WING = (236, 236, 228, 150)
SHADOW = (20, 22, 16, 70)
SMOKE = [(232, 232, 228), (210, 210, 208), (188, 188, 190)]


def grain(x, y, seed):
    """A fixed pseudo-random 0-15 for a pixel."""
    n = (int(x) * 73856093) ^ (int(y) * 19349663) ^ (seed * 83492791)
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return (n ^ (n >> 16)) & 15


def tone(ramp, v):
    """The ramp colour for v in 0 (lightest) to 1 (darkest)."""
    return ramp[max(0, min(len(ramp) - 1, int(v * len(ramp))))]


class Frame:
    def __init__(self):
        self.px = {}

    def put(self, x, y, c):
        x, y = int(x), int(y)
        if 1 <= x < SIZE - 1 and 0 <= y < SIZE - 1:
            self.px[(x, y)] = tuple(c)

    def under(self, x, y, c):
        if (int(x), int(y)) not in self.px:
            self.put(x, y, c)

    def pts(self, c, *points):
        for x, y in points:
            self.put(x, y, c)

    def row(self, c, y, x0, x1):
        for x in range(x0, x1 + 1):
            self.put(x, y, c)

    def ellipse(self, cx, cy, rx, ry, shade, under=False):
        """Fill an ellipse; shade(x, y, nx, ny) returns a colour or None."""
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                nx, ny = (x - cx) / rx, (y - cy) / ry
                if nx * nx + ny * ny <= 1.0:
                    c = shade(x, y, nx, ny)
                    if c is not None:
                        (self.under if under else self.put)(x, y, c)

    def copy(self):
        f = Frame()
        f.px = dict(self.px)
        return f

    def image(self):
        im = Image.new('RGBA', (SIZE, SIZE))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c if len(c) == 4 else c + (255,))
        return im


def ground_shadow(f, cx, cy, rx, ry):
    """A soft cast shadow under and to the right of whatever is drawn."""
    f.ellipse(cx, cy, rx, ry, lambda *a: SHADOW, under=True)


def bee(f, x, y, flip=0, wing=True):
    """One bee: a dark speck with a gold stripe beside it and a pale wing."""
    f.put(x, y, BEE_DARK)
    f.put(x + (-1 if flip else 1), y, BEE_GOLD)
    if wing:
        f.put(x, y - 1, BEE_WING)


def fly(f, fliers, k, frames=6, box=(2, 28, 1, 29)):
    """Bees flying (cx, cy, rx, ry, phase, turns) loops in a whole number of
    turns, so the last frame runs into the first."""
    for i, (cx, cy, rx, ry, phase, turns) in enumerate(fliers):
        a = phase + 2 * math.pi * turns * k / frames
        x = int(round(cx + rx * math.cos(a)))
        y = int(round(cy + ry * math.sin(a)))
        x, y = max(box[0], min(box[1], x)), max(box[2], min(box[3], y))
        bee(f, x, y, flip=-math.sin(a) * turns < 0, wing=(i + k) % 3 != 0)


def painted(f, x0, x1, y0, y1, seed, lift=0.0):
    """A white-painted board face: paler at the left, grey-blue at the right,
    with weather streaks and the odd chip down to bare wood."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            v = 0.06 + (x - x0) / float(x1 - x0) * 0.62 + lift
            if x == x1:
                v += 0.2                        # the corner turns away
            elif x == x1 - 1:
                v += 0.1
            g = grain(x, y // 2, seed)
            if g == 0:
                v += 0.17                       # a weather streak
            elif g == 15:
                v -= 0.1
            c = tone(PAINT, v)
            if grain(x, y, seed + 1) == 0 and grain(x // 3, y // 2, seed + 2) < 5:
                c = BARE                        # a chip in the paint
            f.put(x, y, c)


def planks(f, x0, x1, y0, y1, seed, lift=0.0, joint=None):
    """A bare pine face with grain and, at row `joint`, a seam."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            v = 0.1 + (x - x0) / float(max(1, x1 - x0)) * 0.34 + lift
            if x == x1:
                v += 0.18
            if y == joint and x % 7 != 3:
                v += 0.2
            elif grain(x // 3, y, seed) < 3:
                v += 0.13
            f.put(x, y, tone(BOARD, v))


# ------------------------------------------------------------ frame hive --

def hand_hold(f, y):
    """The scooped hand-hold cut in the front of a box."""
    f.row(PAINT[5], y, 14, 17)
    f.row(PAINT[4], y + 1, 14, 17)
    f.pts(PAINT[3], (13, y), (18, y + 1))
    f.row(PAINT[0], y + 2, 14, 17)


def frame_hive(open_top=False):
    """Two white boxes stacked on a bottom board: a shallow super over a deep
    brood box, each with a hand-hold, the entrance slit across the bottom
    with a landing board under it, a telescoping lid on top, the whole stood
    on two bricks. Open, the lid leans on the hive's right side and the top
    bars of the frames show in the top box."""
    f = Frame()
    # the bricks
    for x0 in (7, 19):
        for y in range(28, 31):
            for x in range(x0, x0 + 6):
                v = 0.1 + (x - x0) / 5.0 * 0.4 + (y - 28) * 0.18 + (0.2 if x0 == 19 else 0)
                if grain(x, y, 61) < 2:
                    v += 0.2
                f.put(x, y, tone(BRICK, v))
        f.pts(MORTAR, (x0 + 3, 29))
    # the dark under the hive between them
    for x in range(13, 19):
        f.put(x, 28, (30, 30, 26, 150))
        f.put(x, 29, (30, 30, 26, 110))
    ground_shadow(f, 18.0, 29.6, 10.5, 1.4)
    # the deep brood box and the super over it
    painted(f, 7, 24, 16, 24, 63)
    painted(f, 7, 24, 10, 15, 67)
    for x in range(7, 25):
        f.put(x, 16, PAINT[4] if x < 21 else PAINT[5])      # the joint
        if (x, 15) in f.px and x not in (7, 24):
            f.put(x, 15, PAINT[1] if x < 14 else PAINT[2])  # the lower edge lit
    hand_hold(f, 12 if not open_top else 11)
    hand_hold(f, 19)
    # bottom board, entrance slit and the landing board in front
    for x in range(7, 25):
        f.put(x, 25, PAINT[3] if x < 20 else PAINT[4])
        f.put(x, 26, tone(BOARD, 0.25 + (x - 7) / 17.0 * 0.4))
    f.row(HOLE[1], 25, 10, 21)
    f.pts(HOLE[0], (10, 25), (21, 25))
    for x in range(8, 24):
        f.put(x, 27, BOARD[3] if x < 18 else BOARD[4])
    f.row(BOARD[0], 26, 9, 15)
    if not open_top:
        # the telescoping lid: its tin-clad top, then its rim hanging over the super
        for y in range(4, 7):
            for x in range(6, 26):
                if y == 4 and x in (6, 25):
                    continue
                v = 0.0 + (x - 6) / 19.0 * 0.42 + (y - 4) * 0.06
                if grain(x, y, 71) == 0:
                    v += 0.16
                f.put(x, y, tone(TIN, v))               # tin sheet over the top
        painted(f, 6, 25, 7, 9, 73, lift=0.1)
        for x in range(6, 26):
            f.put(x, 7, PAINT[1] if x < 18 else PAINT[2])   # the lid's near edge
            f.put(x, 9, PAINT[4] if x < 20 else PAINT[5])
        for x in range(7, 25):
            f.put(x, 10, PAINT[4] if x < 21 else PAINT[5])  # its shadow on the box
    else:
        # the open top of the super seen from above
        for x in range(7, 25):
            f.put(x, 5, PAINT[2] if x < 20 else PAINT[3])   # the far wall
            f.put(x, 9, PAINT[0] if x < 18 else PAINT[1])   # the near wall's top
            for y in (6, 7, 8):
                if x in (7, 24):
                    f.put(x, y, PAINT[1] if x == 7 else PAINT[3])
                elif x % 2 == 0:
                    # a top bar, pale wood with propolis at the ends
                    f.put(x, y, BOARD[0] if y == 7 else (BOARD[2] if y == 6 else BOARD[1]))
                else:
                    f.put(x, y, HOLE[0] if y > 6 else HOLE[1])
        for x in range(8, 24):
            f.put(x, 10, PAINT[1] if x < 16 else PAINT[2])
        # the lid stood on its edge, leaning on the right side
        for y in range(13, 31):
            x0 = 25 + (y - 13) * 3 // 17
            f.put(x0, y, PAINT[1] if y > 13 else PAINT[0])
            f.put(x0 + 1, y, PAINT[2] if grain(x0, y, 75) else PAINT[3])
            f.put(x0 + 2, y, PAINT[4] if y < 29 else PAINT[5])
        f.pts(PAINT[0], (25, 12), (26, 12))
        f.pts(PAINT[3], (27, 12))
        ground_shadow(f, 27.0, 30.0, 3.0, 1.0)
    return f


# bees round the entrance slit: where each crawler stands in each frame
HIVE_CRAWL = [
    [(15, 25, 0), (16, 26, 1), (14, 26, 0), (15, 27, 0), (16, 25, 1), (14, 25, 0)],
    [(19, 26, 1), (18, 26, 1), (18, 25, 1), (19, 25, 1), (20, 26, 1), (20, 27, 1)],
    [(11, 26, 0), (11, 25, 0), (12, 25, 0), (12, 26, 0), (10, 26, 0), (10, 27, 0)],
    [(17, 23, 1), (16, 23, 1), (16, 24, 1), (17, 24, 1), (18, 24, 1), (18, 23, 1)],
    [(12, 23, 0), (13, 23, 0), (13, 24, 0), (12, 24, 0), (11, 24, 0), (11, 23, 0)],
    [(22, 26, 1), (22, 25, 1), (21, 26, 1), (22, 27, 1), (23, 26, 1), (22, 24, 1)],
]
HIVE_FLY = [
    (15, 23, 8, 3, 0.4, 1), (16, 20, 11, 5, 2.6, -1), (14, 25, 6, 3, 4.4, 1),
    (18, 17, 9, 6, 5.5, 1), (12, 21, 9, 4, 1.5, -1), (16, 24, 12, 3, 3.5, 2),
    (15, 15, 10, 5, 0.9, -1), (20, 22, 7, 5, 2.0, 1), (10, 18, 6, 6, 5.0, 1),
    (16, 12, 11, 4, 3.9, -1),
]
# crawlers, fliers for bees1..bees5
HIVE_BEES = [(1, 1), (2, 2), (3, 4), (4, 7), (6, 10)]


def hive_bees(level, k):
    f = Frame()
    crawlers, fliers = HIVE_BEES[level - 1]
    for path in HIVE_CRAWL[:crawlers]:
        x, y, flip = path[k]
        bee(f, x, y, flip, wing=False)
    fly(f, HIVE_FLY[:fliers], k, box=(3, 27, 8, 29))
    return f


# ------------------------------------------------------------- hive tool --

def hive_tool():
    """A flat steel bar lying corner to corner: a broad chisel end at the
    lower left, the grip painted red and worn through, and the other end
    turned over in a scraping hook."""
    f = Frame()
    for i in range(17):
        x, y = 7 + i, 24 - i
        if 4 <= i <= 11:
            worn = i in (4, 7, 11)              # paint rubbed off by the hand
            top, mid, low = (STEEL[1] if worn else RED[0]), RED[1], RED[2]
        else:
            top, mid, low = STEEL[0], STEEL[1], STEEL[3]
        f.put(x, y, top)
        f.put(x + 1, y, mid)
        f.put(x + 1, y + 1, mid)
        f.put(x + 2, y + 1, low)
    # the chisel end, spread and ground to an edge
    f.pts(STEEL[0], (5, 23), (6, 23), (5, 24), (6, 24), (4, 25), (5, 25))
    f.pts(STEEL[1], (6, 25), (5, 26), (6, 26), (7, 26), (6, 27))
    f.pts(STEEL[3], (7, 27), (8, 27), (9, 26))
    # the hook, turned over and down
    f.pts(STEEL[0], (24, 7), (25, 6), (26, 6))
    f.pts(STEEL[1], (25, 7), (26, 7), (27, 7), (27, 8))
    f.pts(STEEL[2], (28, 8), (28, 9), (27, 9), (28, 10), (27, 10))
    f.pts(STEEL[3], (27, 11), (26, 11), (26, 12))
    f.pts(STEEL[4], (25, 12))
    # the nail-pulling hole
    f.pts(STEEL[4], (21, 11))
    return f


# ---------------------------------------------------------------- smoker --

def bee_smoker():
    """An upright tin fire pot with a cone lid whose spout leans away from
    the bellows; the bellows, two wooden boards with pleated leather between,
    stand against the pot's left side and blow in through a pipe near the
    bottom."""
    f = Frame()
    # the bellows: the inner board against the pot, the outer one sprung open
    for y in range(13, 28):
        left = 9 - (27 - y) * 4 // 14
        for x in range(left, 13):
            if x <= left + 1:
                c = BOARD[0] if x == left else BOARD[2]
                if x == left and y % 4 == 1:
                    c = BRASS[1]                 # the tacks holding the leather
            elif x >= 11:
                c = BOARD[2] if x == 11 else BOARD[4]
            else:
                v = 0.3 + (x - left) / 8.0 * 0.5
                if (y + (x - left) // 2) % 3 == 0:
                    v -= 0.3                     # a pleat catching the light
                c = tone(LEATHER, v)
            f.put(x, y, c)
    for x in range(6, 13):                      # the leather over the top
        if (x, 13) in f.px:
            f.put(x, 12, LEATHER[1] if x < 10 else LEATHER[2])
    f.pts(LEATHER[3], (9, 27), (10, 27))
    # brackets and the blast pipe
    f.pts(TIN[4], (13, 16), (13, 22))
    f.pts(TIN[3], (13, 25))
    f.pts(TIN[5], (13, 26))
    # the fire pot
    for y in range(14, 29):
        for x in range(14, 24):
            if y == 28 and x in (14, 23):
                continue
            nx = (x - 14) / 9.0
            v = 0.34 - 0.5 * nx if nx < 0.3 else 0.12 + (nx - 0.3) * 1.05
            if y in (15, 26):
                v += 0.2                         # a rolled seam
            elif y in (14, 25):
                v -= 0.08
            if y == 28:
                v += 0.25
            if grain(x, y, 85) == 0:
                v += 0.12                        # soot and dents
            f.put(x, y, tone(TIN, v))
    # the draught holes low on the pot
    f.pts(HOLE[0], (16, 23), (18, 23), (20, 23))
    # the cone lid and its spout
    for y, x0, x1 in ((13, 14, 23), (12, 14, 23), (11, 15, 23), (10, 16, 24), (9, 18, 24),
                      (8, 19, 25), (7, 21, 26), (6, 23, 26)):
        for x in range(x0, x1 + 1):
            nx = (x - x0) / float(max(1, x1 - x0))
            v = 0.05 + nx * 0.6 + (0.1 if y == 13 else 0)
            f.put(x, y, tone(TIN, v))
    f.row(TIN[5], 14, 14, 23)                   # the lid's lip
    f.pts(TIN[0], (15, 11), (16, 10), (18, 9), (19, 8))
    f.pts(HOLE[0], (25, 6), (26, 6))            # the spout's mouth
    f.pts(TIN[4], (24, 13), (24, 14))           # the hinge
    return f


SMOKER_WISP = [
    [(26, 5, 210), (27, 4, 180), (27, 3, 150), (26, 2, 115), (27, 1, 75)],
    [(26, 5, 190), (26, 4, 180), (27, 3, 155), (28, 2, 120), (28, 1, 85), (27, 0, 50)],
    [(27, 5, 200), (27, 4, 170), (26, 3, 150), (26, 2, 125), (27, 1, 95), (28, 0, 55)],
]


def bee_smoker_lit(k):
    f = bee_smoker()
    for i, (x, y, a) in enumerate(SMOKER_WISP[k]):
        f.put(x, y, SMOKE[min(2, i // 2)] + (a,))
        side = 1 if (i + k) % 2 else -1
        if y < 5 and (x + side, y) not in f.px:
            f.put(x + side, y, SMOKE[2] + (a // 2,))
    f.pts((250, 150, 50), (18, 23))             # the fire showing at a draught hole
    return f


# ----------------------------------------------------------- honey frame --

def honey_frame(fill):
    """A wooden frame seen flat on: the top bar runs out past the side bars
    in two lugs. `fill` is 0 for a sheet of wax foundation, 1 for drawn empty
    comb, 2 for comb full of capped honey."""
    f = Frame()
    for y in range(11, 23):
        for x in range(8, 24):
            cell = (x + 2 * (y % 2)) % 4 == 0   # staggered like the cells
            light = (x - 8) / 15.0 * 0.5 + (y - 11) / 11.0 * 0.5
            if fill == 0:
                c = WAX[1] if light < 0.55 else WAX[2]
                if cell:
                    c = WAX[2] if light < 0.55 else WAX[3]
                if (x + y) in (22, 23, 30):
                    c = WAX[0]                   # the sheet's sheen
            elif fill == 1:
                c = WAX[0] if light < 0.3 else (WAX[1] if light < 0.75 else WAX[2])
                if cell:
                    c = WAX[4] if light > 0.3 else WAX[3]
                elif (x + 2 * (y % 2)) % 4 == 2 and y % 2 == 0:
                    c = WAX[2] if light < 0.75 else WAX[3]
            else:
                v = 0.12 + light * 0.5 + (grain(x // 2, y // 2, 91) - 7) / 40.0
                c = tone(HONEY, v)
                if cell:
                    c = tone(HONEY, v + 0.2)     # the dimples between cappings
                elif grain(x, y, 93) < 2:
                    c = HONEY[0]                 # a dry white capping
                if (x, y) in ((22, 21), (23, 22), (21, 22), (23, 20), (8, 22)):
                    c = HONEY[5]                 # a few cells left open
            f.put(x, y, c)
    if fill:
        # comb is built out thicker than the wood and shades the bars' inner side
        for x in range(8, 24):
            f.put(x, 11, tone(WAX if fill == 1 else HONEY, 0.75))
    # side bars, bottom bar, then the top bar with its lugs
    for y in range(11, 23):
        f.put(6, y, BOARD[0])
        f.put(7, y, BOARD[2])
        f.put(24, y, BOARD[1])
        f.put(25, y, BOARD[3])
    for x in range(6, 26):
        f.put(x, 23, BOARD[1] if x < 17 else BOARD[2])
        f.put(x, 24, BOARD[3] if x < 22 else BOARD[4])
    for x in range(3, 29):
        f.put(x, 8, BOARD[0] if x < 20 else BOARD[1])
        f.put(x, 9, BOARD[1] if x < 14 else BOARD[2])
        if 6 <= x <= 25:
            f.put(x, 10, BOARD[3] if x < 22 else BOARD[4])
    f.pts(BOARD[3], (3, 9), (4, 9), (5, 9), (26, 9), (27, 9), (28, 9))
    f.pts(BOARD[4], (9, 8), (22, 8))            # the nails
    return f


# ------------------------------------------------------------- extractor --

EX_CX, EX_RX, EX_TOP, EX_BASE = 15.5, 8.0, 10.0, 25.0
CRANK = [(1, 0), (0, 1), (-1, 0), (0, -1)]


def extractor(spin=None):
    """An upright tin drum on three short legs, open at the top with the
    frame basket inside, an iron bar across the mouth carrying the gear and
    a hand crank, and a brass honey gate low on the front. `spin` 0-3 turns
    the crank a quarter at a time and blurs the basket."""
    f = Frame()
    # legs: one at each side and one in front
    for x0, y0 in ((9, 26), (21, 26), (15, 28)):
        for y in range(y0, 31):
            f.put(x0, y, IRON[0] if x0 < 20 else IRON[1])
            f.put(x0 + 1, y, IRON[2])
    ground_shadow(f, 18.0, 29.6, 10.0, 1.4)
    for x in range(8, 24):
        nx = (x - EX_CX) / EX_RX
        bow = 3.0 * math.sqrt(max(0.0, 1 - nx * nx))
        for y in range(int(EX_TOP), 29):
            rel = y - bow - EX_TOP
            if rel < -bow or y > EX_BASE + bow:
                continue
            u = (x - 8) / 15.0
            v = 0.36 - 0.9 * u if u < 0.28 else 0.1 + (u - 0.28) * 0.95
            if 4 <= rel < 5 or 12 <= rel < 13:
                v += 0.2                         # the hoops' shadow
            elif 3 <= rel < 4 or 11 <= rel < 12:
                v -= 0.12                        # the hoops
            if y > EX_BASE + bow - 1:
                v += 0.2
            if grain(x, y, 97) == 0:
                v += 0.1
            f.put(x, y, tone(TIN, v))

    # the open mouth: a bright rim, the dark inside, the basket's wire
    def mouth(x, y, nx, ny):
        rr = math.hypot(nx, ny)
        if rr > 0.8:
            return TIN[0] if ny > 0 and nx < 0.4 else (TIN[1] if ny > 0 else TIN[3])
        return IRON[3] if ny < 0.0 else TIN[5]
    f.ellipse(EX_CX, EX_TOP, EX_RX, 3.2, mouth)
    if spin is None:
        # the basket's wire and the edges of two combs standing in it
        f.pts(TIN[3], (11, 11), (20, 11), (12, 12), (19, 12))
        f.pts(HONEY[3], (13, 11), (13, 12), (18, 11), (18, 12))
        f.pts(TIN[4], (11, 9), (20, 9), (13, 8), (18, 8))
    else:
        # the basket a blur of wire and comb
        for x in range(10, 22):
            if (x + spin * 3) % 4 < 2:
                f.put(x, 11, TIN[3] if (x + spin) % 3 else HONEY[3])
                f.put(x + 1, 12, TIN[4])
            if (x + spin * 3 + 2) % 4 == 0:
                f.put(x, 9, TIN[4])
        # the drum shivers: its bright streak shifts from frame to frame
        for y in range(16, 22):
            f.put(11 + (spin % 2), y, TIN[0])
    # the bar across the mouth, the gear case and the crank
    for x in range(8, 24):
        f.put(x, 10, IRON[0] if x < 18 else IRON[1])
    for y in range(5, 10):
        for x in range(14, 19):
            f.put(x, y, IRON[1] if (x < 16 and y < 7) else (IRON[2] if x < 18 else IRON[3]))
    f.pts(IRON[0], (14, 5), (15, 5), (14, 6))
    f.pts(BRASS[1], (16, 7))                    # the crank's hub
    dx, dy = CRANK[0 if spin is None else spin]
    hx, hy = 16, 7
    for i in range(1, 5):
        f.put(hx + dx * i, hy + dy * i, STEEL[1] if i < 4 else STEEL[2])
    tx, ty = hx + dx * 5, hy + dy * 5
    f.pts(BOARD[0], (tx, ty))
    f.pts(BOARD[2], (tx + (0 if dx else 1), ty + (1 if dx else 0)))
    f.pts(BOARD[1], (tx - (0 if dx else 1), ty - (1 if dx else 0)))
    # the honey gate
    f.pts(BRASS[0], (10, 23), (11, 23))
    f.pts(BRASS[1], (12, 23), (10, 24), (11, 24))
    f.pts(BRASS[2], (12, 24), (10, 25))
    f.pts(BRASS[3], (11, 25), (13, 24))
    f.pts(BRASS[1], (11, 22), (11, 21))         # its lever
    f.pts(BRASS[0], (10, 21))
    if spin is not None and spin % 2 == 0:
        f.pts(HONEY[2], (10, 26))               # honey running from the gate
    elif spin is not None:
        f.pts(HONEY[2], (10, 27))
    return f


# ----------------------------------------------------------- nucleus box --

def nucleus_box():
    """A small bare pine box for a few frames and a starter colony: a flat
    lid with a strap to carry it by, a round flight hole low in the front
    with a peg of a landing board under it."""
    f = Frame()
    ground_shadow(f, 18.0, 29.4, 9.5, 1.5)
    planks(f, 8, 23, 18, 29, 101, joint=23)
    for x in range(8, 24):
        f.put(x, 18, BOARD[3] if x < 20 else BOARD[4])      # the lid's shadow
        f.put(x, 29, BOARD[3] if x < 18 else BOARD[4])
    # the lid: top, then its near edge
    for y in range(13, 16):
        for x in range(7, 25):
            if y == 13 and x in (7, 24):
                continue
            v = 0.0 + (x - 7) / 17.0 * 0.3
            if grain(x // 3, y, 103) < 3:
                v += 0.14
            f.put(x, y, tone(BOARD, v))
    planks(f, 7, 24, 16, 17, 105, lift=0.2)
    f.row(BOARD[4], 17, 8, 24)
    # the carrying strap
    f.pts(LEATHER[1], (12, 14), (12, 13), (12, 12), (13, 11), (14, 10), (15, 10), (16, 10),
          (17, 10))
    f.pts(LEATHER[2], (18, 11), (19, 12), (19, 13), (19, 14))
    f.pts(LEATHER[0], (13, 10), (14, 9), (15, 9), (16, 9))
    f.pts(BRASS[1], (12, 15), (19, 15))
    # the flight hole and its landing peg
    f.pts(HOLE[1], (15, 24), (16, 24), (15, 25), (16, 25))
    f.pts(BOARD[4], (14, 24), (15, 23), (16, 23), (17, 24), (17, 25), (14, 25))
    f.row(BOARD[0], 26, 13, 18)
    f.row(BOARD[4], 27, 13, 18)
    # a vent of wire gauze at the right
    f.pts(TIN[3], (20, 21), (21, 21), (20, 20))
    f.pts(TIN[4], (21, 20))
    return f


NUC_CRAWL = [
    [(15, 25, 0), (16, 26, 1), (17, 26, 1), (16, 25, 1), (14, 26, 0), (14, 25, 0)],
    [(19, 24, 1), (19, 25, 1), (18, 25, 1), (18, 24, 1), (19, 23, 1), (20, 24, 1)],
]
NUC_FLY = [(15, 23, 8, 3, 0.6, 1), (16, 20, 9, 5, 3.4, -1)]


def nucleus_box_full(k):
    f = nucleus_box()
    for path in NUC_CRAWL:
        x, y, flip = path[k]
        bee(f, x, y, flip, wing=False)
    fly(f, NUC_FLY, k, box=(3, 27, 6, 29))
    return f


# ----------------------------------------------------------------- sheet --

def states():
    """[(state, [frame images], delay)] in sheet order."""
    drawn = [
        ('frame_hive', [frame_hive()], 0),
        ('frame_hive_open', [frame_hive(open_top=True)], 0),
    ]
    for level in range(1, 6):
        drawn.append(('bees%d' % level, [hive_bees(level, k) for k in range(6)], 2))
    drawn += [
        ('hive_tool', [hive_tool()], 0),
        ('bee_smoker', [bee_smoker()], 0),
        ('bee_smoker_lit', [bee_smoker_lit(k) for k in range(3)], 2),
        ('honey_frame', [honey_frame(0)], 0),
        ('honey_frame_drawn', [honey_frame(1)], 0),
        ('honey_frame_filled', [honey_frame(2)], 0),
        ('extractor', [extractor()], 0),
        ('extractor_spin', [extractor(k) for k in range(4)], 1),
        ('nucleus_box', [nucleus_box()], 0),
        ('nucleus_box_full', [nucleus_box_full(k) for k in range(6)], 2),
    ]
    return [(n, [fr.image() for fr in frs], d) for n, frs, d in drawn]


def build():
    sheet = states()
    frames = [fr for _, frs, _ in sheet for fr in frs]
    cols = int(len(frames) ** 0.5 + 0.999)
    rows = (len(frames) + cols - 1) // cols
    im = Image.new('RGBA', (cols * SIZE, rows * SIZE))
    for i, fr in enumerate(frames):
        im.paste(fr, ((i % cols) * SIZE, (i // cols) * SIZE))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, frs, delay in sheet:
        text += 'state = "%s"\n\tdirs = 1\n\tframes = %d\n' % (name, len(frs))
        if len(frs) > 1:
            text += '\tdelay = %s\n' % ','.join([str(delay)] * len(frs))
    return im, text + '# END DMI\n'


def write_dmi():
    im, text = build()
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    im.save(SHEET, 'PNG', pnginfo=meta, optimize=True)


def check():
    if not SHEET.exists():
        return False
    im, text = build()
    old = Image.open(SHEET)
    return old.info.get('Description') == text and old.convert('RGBA').tobytes() == im.tobytes()


# ---------------------------------------------------------------- review --

GRASS = (98, 122, 78, 255)
DIRT = (126, 98, 68, 255)
BACK = (24, 24, 24, 255)
WHITE = (230, 230, 230, 255)


def on(ground, *layers):
    tile = Image.new('RGBA', (SIZE, SIZE), ground)
    for layer in layers:
        tile.alpha_composite(layer)
    return tile


def preview(path, scale=4):
    sheet = states()
    by_name = dict((n, frs) for n, frs, _ in sheet)
    pad, label = 6, 12
    cell = SIZE * scale + pad
    rows = []                       # (label, [tiles at 1x])
    for name, frs, delay in sheet:
        text = '%s  %d frame%s%s  (grass, then dirt)' % (
            name, len(frs), 's' if len(frs) > 1 else '', ', delay %d' % delay if delay else '')
        rows.append((text, [on(g, fr) for g in (GRASS, DIRT) for fr in frs]))
    over = [on(g, by_name[h][0], by_name['bees%d' % n][0])
            for g, h in ((GRASS, 'frame_hive'), (DIRT, 'frame_hive_open')) for n in range(1, 6)]
    rows.append(('bees1-bees5 frame 0 over frame_hive, then over frame_hive_open', over))
    widest = max(len(tiles) for _, tiles in rows)
    small = [t for _, tiles in rows for t in tiles]
    per = (widest * cell) // 66
    lines2 = (len(small) + per - 1) // per
    per1 = (widest * cell) // 34
    lines1 = (len(small) + per1 - 1) // per1
    width = pad + widest * cell
    height = pad + len(rows) * (cell + label) + label + lines2 * 66 + label + lines1 * 34 + pad
    out = Image.new('RGBA', (width, height), BACK)
    draw = ImageDraw.Draw(out)
    y = pad
    for text, tiles in rows:
        draw.text((pad, y), text, fill=WHITE)
        for i, tile in enumerate(tiles):
            out.paste(tile.resize((SIZE * scale,) * 2, Image.NEAREST), (pad + i * cell, y + label))
        y += cell + label
    draw.text((pad, y), '2x', fill=WHITE)
    y += label
    for i, tile in enumerate(small):
        out.paste(tile.resize((64, 64), Image.NEAREST), (pad + (i % per) * 66, y + (i // per) * 66))
    y += lines2 * 66
    draw.text((pad, y), '1x', fill=WHITE)
    y += label
    for i, tile in enumerate(small):
        out.paste(tile, (pad + (i % per1) * 34, y + (i // per1) * 34))
    out.save(path)


if __name__ == '__main__':
    if '--check' in sys.argv:
        if not check():
            sys.exit('stale sheet: ' + str(SHEET))
        print('frame hive states match')
    else:
        write_dmi()
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
