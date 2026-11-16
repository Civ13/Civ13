"""Hand-placed sprites for kept bee colonies in icons/farming/kept_hives.dmi:
the three fixed-comb hives (an upright hollowed log under a lid board, a
sun-dried clay cylinder lying on a mud bench and a coiled straw skep on a
board stand), each empty and with bees at the entrance, the hanging swarm
cluster on a branch stub and the smoke puff drawn over a hive that is being
smoked. Every pixel is placed by this script from fixed palettes (Pillow
only); no external or generated artwork. Shading is soft, lit from the upper
left, with no black outline, like icons/farming/wild_bees.dmi and the straw
`beehive` of icons/farming/beekeeping.dmi.

The hives stand on the ground in the usual 3/4 view and keep one pixel clear
on the left, right and bottom of the 32px frame. `hive_smoke` is an overlay
for any of them; everything else in its frames is transparent.

Run with Pillow to write the sheet. `--check` verifies the committed sheet,
`--preview <png>` writes a 4x review sheet of every state and frame on grass
and on dirt, the smoke over each hive, and 2x and 1x rows. Released under
Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/farming/kept_hives.dmi'

SIZE = 32

# bark: highlight, light, mid, dark, deep
BARK = [(150, 118, 84), (122, 92, 62), (92, 66, 44), (64, 46, 32), (42, 30, 22)]
# split board: highlight, light, mid, dark, deep
BOARD = [(214, 178, 124), (188, 148, 96), (158, 118, 72), (122, 88, 52), (88, 62, 38)]
HOLE = [(34, 24, 17), (18, 12, 9)]
STONE = [(186, 184, 176), (150, 148, 142), (112, 110, 106), (78, 76, 74)]
# sun-dried clay: highlight, light, mid, shade, dark, deep
CLAY = [(236, 204, 160), (216, 178, 130), (190, 148, 102), (160, 118, 78), (126, 90, 58),
        (94, 66, 44)]
# the mud bench: top light, top, top shade, face, face shade, foot
MUD = [(176, 150, 112), (154, 128, 92), (132, 106, 76), (108, 84, 60), (86, 66, 48),
       (64, 50, 38)]
CHAFF = (206, 184, 132)
# coiled straw: highlight, light, mid, shade, dark, deep
STRAW = [(246, 222, 150), (226, 194, 112), (198, 160, 82), (164, 124, 58), (124, 90, 40),
         (88, 62, 28)]
BEE_DARK = (38, 28, 18)
BEE_BROWN = (86, 60, 30)
BEE_AMBER = (150, 104, 40)
BEE_GOLD = (246, 198, 48)
BEE_WING = (236, 236, 228, 150)
LEAF = [(150, 184, 88), (104, 146, 62), (70, 108, 48)]
SHADOW = (20, 22, 16, 70)
# smoke, thickest first
SMOKE = [(226, 224, 218), (206, 204, 200), (186, 184, 184), (166, 166, 168)]


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


def with_bees(base, crawl, fliers, k):
    """The hive with its colony: `crawl` gives the places of the bees walking
    round the entrance in each frame, `fliers` are (cx, cy, rx, ry, phase,
    turns) loops flown in a whole number of turns, so frame 3 runs into 0."""
    f = base.copy()
    for x, y, flip in crawl[k]:
        bee(f, x, y, flip, wing=False)
    for i, (cx, cy, rx, ry, phase, turns) in enumerate(fliers):
        a = phase + 2 * math.pi * turns * k / 4
        x = int(round(cx + rx * math.cos(a)))
        y = int(round(cy + ry * math.sin(a)))
        x, y = max(2, min(28, x)), max(1, min(29, y))
        bee(f, x, y, flip=-math.sin(a) * turns < 0, wing=(i + k) % 3 != 0)
    return f


# -------------------------------------------------------------- log hive --

def log_hive():
    """A hollowed section of trunk stood on end, furrowed bark outside, a
    split board for a lid held down by a stone, and a flight hole low on the
    front."""
    f = Frame()
    cx, half = 15.5, 6.6
    for x in range(9, 23):
        nx = (x - cx) / half
        foot = 26.0 + 2.4 * math.sqrt(max(0.0, 1 - nx * nx))
        for y in range(9, int(foot) + 1):
            # furrows run up the trunk and wander a little
            col = x + (1 if grain(0, y // 5, 3) < 5 and grain(x, 0, 5) < 8 else 0)
            ridge = grain(col, 0, 7)
            v = 0.42 + nx * 0.36
            if ridge < 4:
                v += 0.22                       # a furrow
            elif ridge > 11:
                v -= 0.18                       # a ridge catching the light
            if grain(x, y, 9) == 0:
                v += 0.2                        # a crack across the plates
            if abs(nx) > 0.86:
                v = max(v, 0.62) + 0.14 if nx > 0 else max(v, 0.4)
            if y <= 13:
                v += 0.16 if y <= 12 else 0.08  # the lid's shadow
            if y >= foot - 1:
                v += 0.16
            f.put(x, y, tone(BARK, v))
    # the cut rim shows pale under the lid at the left
    f.pts(BOARD[2], (9, 9), (10, 9))
    # flight hole with a worn lower lip
    f.pts(HOLE[1], (15, 21), (16, 21), (15, 22), (16, 22))
    f.pts(HOLE[0], (14, 21), (17, 22))
    f.pts(BARK[4], (14, 20), (15, 20), (16, 20), (17, 20), (17, 21), (14, 22))
    f.pts(BARK[0], (15, 23), (16, 23))
    f.pts(BARK[1], (14, 23), (17, 23))
    # lid: a split board, wider than the log, its near edge showing
    for y in range(4, 10):
        for x in range(7, 25):
            if (x in (7, 24)) and y in (4, 9):
                continue
            v = 0.12 + (x - 7) / 17.0 * 0.3
            if y == 4:
                v -= 0.1
            if y == 6 and x not in (12, 13, 19):
                v += 0.18                       # the joint between two boards
            elif grain(x // 3, y, 13) < 3:
                v += 0.14                       # grain
            f.put(x, y, tone(BOARD, v))
    for x in range(7, 25):
        f.put(x, 10, BOARD[3] if x < 19 else BOARD[4])
        if 8 <= x <= 23:
            f.put(x, 11, BOARD[4])
    f.pts(BOARD[4], (10, 10), (17, 10))         # end checks in the board edge
    # a stone to keep the lid on
    for x, y, c in ((17, 4, 0), (18, 4, 0), (19, 4, 1), (16, 5, 0), (17, 5, 1), (18, 5, 1),
                    (19, 5, 1), (20, 5, 2), (16, 6, 1), (17, 6, 1), (18, 6, 2), (19, 6, 2),
                    (20, 6, 3), (17, 7, 2), (18, 7, 3), (19, 7, 3)):
        f.put(x, y, STONE[c])
    f.pts(BOARD[4], (20, 7), (21, 7), (21, 6))  # its shadow on the board
    ground_shadow(f, 18.0, 27.2, 8.4, 2.4)
    return f


LOG_CRAWL = [
    [(15, 21, 0), (13, 22, 0), (18, 24, 1)],
    [(16, 22, 1), (12, 21, 0), (18, 23, 1)],
    [(15, 22, 0), (13, 20, 0), (17, 24, 1)],
    [(16, 21, 1), (13, 23, 0), (19, 23, 1)],
]
LOG_FLY = [(15, 23, 9, 4, 0.4, 1), (16, 17, 11, 5, 2.6, -1), (14, 25, 6, 3, 4.4, 1),
           (17, 14, 8, 6, 5.5, 1)]


# ------------------------------------------------------------- clay hive --

def clay_hive():
    """A long sun-dried clay tube lying on a low mud bench, built up in hoops
    of clay and chaff. The near end is closed with a mud disc luted into the
    mouth, and the bees use the small hole low in that disc."""
    f = Frame()
    # the bench: a rounded slab of mud and chaff
    for y in range(18, 30):
        for x in range(2, 30):
            inset = 0
            if y in (18, 29):
                inset = 2
            elif y in (19, 28):
                inset = 1
            if x < 2 + inset or x > 29 - inset:
                continue
            if y <= 24:
                v = 0.08 + (x - 2) / 27.0 * 0.26 + (0.0 if y > 18 else -0.08)
                if grain(x, y, 21) < 2:
                    v += 0.16
                c = tone(MUD[:3], v * 2.0)
                if grain(x, y, 23) == 0:
                    c = CHAFF
            else:
                v = (x - 2) / 27.0
                c = MUD[3] if v < 0.55 else MUD[4]
                if y == 25:
                    c = MUD[2] if v < 0.55 else MUD[3]      # the rounded shoulder
                if y >= 28:
                    c = MUD[4] if v < 0.55 else MUD[5]
                if grain(x, y, 25) < 2:
                    c = MUD[5] if y < 28 else MUD[4]        # cracks in the face
            f.put(x, y, c)
    ground_shadow(f, 17.0, 28.6, 13.0, 1.6)
    cap_x, far_x, cy, rx, ry = 9.0, 23.5, 14.5, 4.4, 6.6
    # the tube's shadow on the bench
    for x in range(7, 29):
        for y in (22, 23):
            if (x, y) in f.px and (y == 22 or x >= 10):
                f.put(x, y, MUD[4])
    for y in range(7, 22):
        ny = (y - cy) / ry
        if abs(ny) > 1:
            continue
        arc = rx * math.sqrt(1 - ny * ny)
        for x in range(4, 30):
            d = x - arc                          # constant along a hoop of the tube
            if not (cap_x - 0.5 <= d + arc and d <= far_x):
                continue
            v = 0.34 + ny * 0.44
            if ny < -0.75:
                v += 0.1                         # the top turns away from us
            hoop = int(d - cap_x + 40) % 4
            if hoop == 3:
                v += 0.17                        # the join between two hoops
            elif hoop == 0:
                v -= 0.1
            if grain(x, y, 27) == 0:
                v += 0.12
            if d > far_x - 1.2:
                v += 0.14                        # the far end rounds off
            f.put(x, y, tone(CLAY, v))

    # the end cap: a mud disc luted into the mouth of the tube
    def cap(x, y, nx, ny):
        rr = math.hypot(nx, ny)
        light = nx * 0.5 + ny * 0.85
        if rr > 0.8:                             # the thick clay rim
            if light < -0.4:
                return CLAY[0]
            if light < 0.15:
                return CLAY[1]
            return CLAY[3] if light < 0.6 else CLAY[4]
        v = 0.46 + light * 0.24
        if grain(x, y, 29) < 2:
            v += 0.12
        c = tone(MUD, v)
        if grain(x, y, 31) == 0:
            c = CHAFF
        return c
    f.ellipse(cap_x, cy, rx, ry, cap)
    # the flight hole, low in the cap
    f.pts(HOLE[1], (8, 16), (9, 16), (8, 17), (9, 17))
    f.pts(MUD[5], (7, 16), (10, 16), (8, 15), (9, 15), (10, 17))
    f.pts(MUD[0], (8, 18), (9, 18))
    return f


CLAY_CRAWL = [
    [(8, 16, 0), (6, 18, 0), (11, 19, 1)],
    [(9, 17, 1), (6, 17, 0), (11, 18, 1)],
    [(8, 17, 0), (7, 14, 0), (10, 20, 1)],
    [(9, 16, 1), (7, 19, 0), (11, 20, 1)],
]
CLAY_FLY = [(9, 18, 6, 4, 1.0, 1), (11, 12, 8, 6, 3.2, -1), (8, 21, 5, 3, 5.0, 1),
            (16, 8, 9, 4, 0.2, 1)]


# ------------------------------------------------------------------ skep --

def skep():
    """A dome of coiled straw rope sewn round and round, standing on a board
    with two bearers; the flight hole is cut in the bottom coils in front."""
    f = Frame()
    # the stand: a board lying under the skep and its two bearers
    for y in range(20, 29):
        for x in range(4, 28):
            if y == 20 and (x < 6 or x > 25):
                continue
            if y <= 26:
                v = 0.1 + (x - 4) / 23.0 * 0.28
                if y == 23 and x % 9 != 4:
                    v += 0.16                    # the joint between two boards
                elif grain(x // 3, y, 41) < 3:
                    v += 0.12
                f.put(x, y, tone(BOARD, v))
            else:
                f.put(x, y, BOARD[3] if x < 17 and y == 27 else BOARD[4])
    for x in (6, 7, 8, 23, 24, 25):
        f.put(x, 29, BARK[3] if x < 20 else BARK[4])
        f.put(x, 30, BARK[4])
    ground_shadow(f, 17.0, 29.4, 12.0, 1.4)
    cx, top, base, half_w = 15.5, 4.0, 24.0, 8.0
    # its shadow on the board
    for x in range(9, 27):
        for y in (25, 26):
            if y == 25 or 11 <= x <= 25:
                f.put(x, y, BOARD[4] if x < 24 else BOARD[3])
    for y in range(4, 27):
        for x in range(7, 25):
            nx = (x - cx) / half_w
            if abs(nx) > 1:
                continue
            bow = 1.7 * (1 - nx * nx)            # the coils sag towards us
            t = (y - bow - top) / (base - top)
            if t > 1.0:
                continue
            if t < 0:
                continue
            half = half_w * (1 - (1 - t) ** 2.3) ** 0.5
            if abs(x - cx) > half + 0.25:
                continue
            e = (x - cx) / max(half, 0.5)
            v = 0.38 + e * 0.36 - 0.1 * (1 - t)
            row = (y - bow - top) % 3.0
            coil = int((y - bow - top) // 3)
            if row < 1.0:
                v -= 0.15                        # the top of the rope
            elif row >= 2.0:
                v += 0.2                         # the groove between coils
            elif (x + coil * 2) % 4 == 0:
                v += 0.12                        # the binding stitches
            if abs(e) > 0.86:
                v += 0.14 if e > 0 else 0.04
            f.put(x, y, tone(STRAW, v))
    # the loop it is carried by
    f.pts(STRAW[1], (15, 4), (15, 5))
    f.pts(STRAW[3], (16, 4), (16, 5))
    f.pts(STRAW[2], (15, 3), (16, 3))
    # the flight hole, arched, with a worn sill on the board
    f.pts(HOLE[1], (15, 22), (16, 22), (14, 23), (15, 23), (16, 23), (17, 23),
          (14, 24), (15, 24), (16, 24), (17, 24), (15, 25), (16, 25))
    f.pts(HOLE[0], (14, 25), (17, 25))
    f.pts(STRAW[5], (14, 22), (17, 22), (15, 21), (16, 21), (13, 23), (18, 23), (13, 24),
          (18, 24))
    f.pts(BOARD[1], (14, 26), (15, 26), (16, 26), (17, 26))
    return f


SKEP_CRAWL = [
    [(15, 24, 0), (12, 26, 0), (18, 26, 1)],
    [(16, 25, 1), (11, 26, 0), (19, 25, 1)],
    [(15, 25, 0), (13, 25, 0), (19, 26, 1)],
    [(16, 24, 1), (12, 25, 0), (17, 26, 1)],
]
SKEP_FLY = [(15, 23, 10, 4, 0.8, 1), (16, 15, 11, 5, 3.0, -1), (15, 26, 7, 2, 4.8, 1),
            (17, 9, 8, 5, 5.9, 1)]


# --------------------------------------------------------- swarm cluster --

def swarm_cluster(k):
    """A swarm hanging in a beard from a branch: thousands of bees holding on
    to one another, the surface crawling so the gold and the wing glints move
    from frame to frame."""
    f = Frame()
    # the stub of branch along the top, broken short at the right
    for x in range(1, 29):
        mid = 3.6 - (x - 1) * 0.045
        thick = 1.7 if x < 26 else 1.1
        for y in range(1, 7):
            d = y - mid
            if abs(d) > thick:
                continue
            v = 0.34 + d / thick * 0.34
            if grain(x // 2, y, 51) < 3:
                v += 0.18
            f.put(x, y, tone(BARK, v))
    f.pts(BOARD[1], (28, 2), (28, 3))            # the broken end
    f.pts(BOARD[2], (29, 2))
    # a twig and leaves
    f.pts(BARK[2], (6, 1), (7, 0))
    for x, y, c in ((4, 6, 1), (5, 6, 0), (5, 7, 1), (6, 7, 2), (3, 7, 2), (4, 7, 1),
                    (24, 0, 0), (25, 0, 1), (25, 1, 1), (26, 1, 2), (23, 6, 1), (24, 6, 2),
                    (24, 7, 1), (25, 7, 2)):
        f.put(x, y, LEAF[c])
    cx, top, low = 15.5, 2.0, 24.0
    for y in range(2, 25):
        t = (y - top) / (low - top)
        half = 6.6 * math.sqrt(max(0.0, 1 - t ** 2.6)) * (0.8 + 0.2 * min(1.0, t * 3.5))
        lean = 0.6 * math.sin(t * 2.2)           # it hangs a little off true
        for x in range(6, 26):
            dx = x - cx - lean
            edge = half + (grain(x, y, 53) - 7) / 16.0
            if abs(dx) > edge:
                continue
            e = dx / max(half, 0.6)
            light = e * 0.5 + (t - 0.4) * 0.45
            g = grain(x, y, 55)
            live = grain(x, y, 57) < 6           # these bees are moving
            if live:
                g = grain(x, y, 59 + k)
            v = light + (g - 7) / 13.0
            if v < -0.2:
                c = BEE_AMBER
            elif v < 0.28:
                c = BEE_BROWN
            else:
                c = BEE_DARK
            # the gold bands show only here and there, more on the lit side
            if g >= (11 if e < 0.1 else 14) and (x + y * 2) % 3 == 0:
                c = BEE_GOLD if e < 0.5 else BEE_AMBER
            if live and g == 15 and e < 0.4:
                c = (224, 222, 208)              # a wing catching the light
            f.put(x, y, c)
    # bees landing on it and leaving it
    for i, (ox, oy, rx, ry, phase, turns) in enumerate(
            ((8, 13, 2, 4, 0.5, 1), (24, 12, 2, 5, 2.4, -1), (10, 23, 3, 2, 4.0, 1),
             (22, 22, 3, 2, 1.2, -1))):
        a = phase + 2 * math.pi * turns * k / 4
        x, y = int(round(ox + rx * math.cos(a))), int(round(oy + ry * math.sin(a)))
        if (x, y) not in f.px and (x + 1, y) not in f.px and (x - 1, y) not in f.px:
            bee(f, x, y, flip=i % 2, wing=(i + k) % 2 == 0)
    return f


# ------------------------------------------------------------ hive smoke --

SMOKE_STAGE = [(0.0, 22.0, 2.6, 215), (-1.2, 15.5, 3.9, 160), (1.0, 8.5, 5.0, 90)]
SMOKE_PUFFS = [(11.0, 0, 1.0, 0.3), (18.5, 1, -1.0, 2.1), (15.0, 2, 0.6, 4.2)]


def hive_smoke(k):
    """Three puffs of smoke rolling up over the hive. Each one starts small
    and thick, swells and thins as it climbs, and is gone as the next takes
    its place, so frame 2 runs into frame 0."""
    f = Frame()
    acc = {}
    for x0, first, side, seed in SMOKE_PUFFS:
        dx, cy, r, alpha = SMOKE_STAGE[(first + k) % 3]
        cx = x0 + dx * side
        for y in range(SIZE):
            for x in range(SIZE):
                nx, ny = (x - cx) / (r * 1.15), (y - cy) / r
                a = math.atan2(ny, nx)
                edge = 1.0 + 0.1 * math.sin(a * 3 + seed + k) + 0.1 * math.sin(a * 5 + seed * 2)
                rr = math.hypot(nx, ny) / edge
                if rr > 1.0:
                    continue
                al = alpha * (1.0 if rr < 0.55 else (0.72 if rr < 0.8 else 0.42))
                shade = 0 if (ny < -0.2 and nx < 0.3 and rr < 0.7) else (1 if ny < 0.35 else 2)
                if rr > 0.8:
                    shade = min(3, shade + 1)
                old = acc.get((x, y))
                if old is None or al > old[1]:
                    acc[(x, y)] = (shade, al if old is None else min(235, al + old[1] * 0.3))
    for (x, y), (shade, al) in acc.items():
        f.put(x, y, SMOKE[shade] + (int(al),))
    return f


# ----------------------------------------------------------------- sheet --

def states():
    """[(state, [frame images], delay)] in sheet order."""
    log, clay, straw = log_hive(), clay_hive(), skep()
    drawn = [
        ('log_hive', [log], 0),
        ('log_hive_bees', [with_bees(log, LOG_CRAWL, LOG_FLY, k) for k in range(4)], 2),
        ('clay_hive', [clay], 0),
        ('clay_hive_bees', [with_bees(clay, CLAY_CRAWL, CLAY_FLY, k) for k in range(4)], 2),
        ('skep', [straw], 0),
        ('skep_bees', [with_bees(straw, SKEP_CRAWL, SKEP_FLY, k) for k in range(4)], 2),
        ('swarm_cluster', [swarm_cluster(k) for k in range(4)], 2),
        ('hive_smoke', [hive_smoke(k) for k in range(3)], 3),
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
    smoked = [on(g, by_name[n][0], by_name['hive_smoke'][k])
              for g in (GRASS, DIRT) for k, n in enumerate(('log_hive', 'clay_hive', 'skep'))]
    rows.append(('hive_smoke frames 0-2 over log_hive, clay_hive, skep', smoked))
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
        print('kept hive states match')
    else:
        write_dmi()
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
