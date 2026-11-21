"""Hand-placed 32px art for the training gear: lifting stones, bronze hand
weights, the iron barbell, the skipping rope, the stationary running gear (a
wooden tread wheel on a timber frame and a motor treadmill, each with a still
state and a four-frame `_turning` / `_running` state in four directions) and
the older obstacle course (start post with a pennant, finish post with a
wreath, log hurdle, balance log and steel hurdle), kept for existing objects.
Every pixel is placed by this script from fixed palettes (Pillow only); no
external or generated artwork. Light falls from the upper left.

The tread wheel and treadmill are drawn to sit under a person standing on the
tile centre: east and west show the wheel side on (rim, spokes, hub) and the
belt running across the tile, north and south show the slatted drum end on
between its posts and the belt running up the tile. The handrail and console
are at the end the gear faces. The moving states turn the wheel, or run the
belt stripes, backward under the walker.

Run with Pillow to reproduce
  icons/obj/training.dmi                      item icons and structures
  icons/mob/items/lefthand_training.dmi       held, four directions, with a
  icons/mob/items/righthand_training.dmi      raised `_lift` state for each

`--check` verifies the three committed sheets byte for byte, `--preview <png>`
writes a review sheet, `--in-use <png>` writes a sheet of a plain body standing
on the gear and holding the rope. Released under Civ13 AGPL-3.0.
"""
import io
import math
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_diving_gear import base_body  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEETS = {
    'obj': ROOT / 'icons/obj/training.dmi',
    'left': ROOT / 'icons/mob/items/lefthand_training.dmi',
    'right': ROOT / 'icons/mob/items/righthand_training.dmi',
}

OUT = (38, 34, 36)
SHADOW = (20, 22, 20, 70)
# river cobble, quarry stone and dark granite, light to dark
COBBLE = [(222, 216, 200), (196, 189, 172), (166, 158, 143), (134, 127, 115), (102, 96, 88)]
QUARRY = [(204, 204, 200), (174, 175, 172), (144, 145, 144), (112, 113, 115), (82, 83, 88)]
GRANITE = [(176, 172, 176), (146, 142, 148), (116, 112, 120), (88, 84, 94), (62, 58, 68)]
LICHEN = [(148, 164, 96), (112, 132, 74)]
WOOD = [(224, 186, 146), (198, 156, 118), (170, 126, 90), (144, 102, 71), (116, 82, 55), (86, 58, 36)]
BARK = [(150, 112, 78), (124, 90, 60), (98, 68, 46), (74, 50, 34)]
ROPE = [(226, 204, 150), (184, 158, 104)]
BRONZE = [(246, 214, 140), (220, 170, 86), (182, 126, 56), (138, 90, 40), (98, 62, 30)]
IRON = [(214, 218, 224), (168, 174, 182), (124, 130, 140), (88, 92, 102), (56, 60, 68)]
RED = [(232, 96, 76), (198, 56, 50), (150, 38, 42)]
CLOTH = [(246, 242, 230), (214, 208, 194), (172, 164, 152)]
LEAF = [(132, 178, 84), (92, 142, 62), (60, 104, 48)]
RUBBER = [(92, 94, 100), (60, 62, 68), (42, 44, 50)]
LAMP = [(120, 232, 110), (232, 96, 76), (96, 44, 44)]


class Frame:
    def __init__(self):
        self.px = {}

    def put(self, x, y, c):
        if 0 <= x < 32 and 0 <= y < 32:
            self.px[(x, y)] = tuple(c) if len(c) == 4 else tuple(c) + (255,)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def pts(self, c, *points):
        for x, y in points:
            self.put(x, y, c)

    def outline(self, c=OUT):
        solid = {p for p, v in self.px.items() if v[3] == 255}
        edge = set()
        for (x, y) in solid:
            for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if n not in solid:
                    edge.add(n)
        for x, y in edge:
            self.put(x, y, c)
        return self

    def under(self, other):
        """Lay `other` beneath this frame."""
        for p, v in other.px.items():
            if p not in self.px:
                self.px[p] = v
        return self

    def shift(self, dx, dy):
        f = Frame()
        f.px = {(x + dx, y + dy): c for (x, y), c in self.px.items() if 0 <= x + dx < 32 and 0 <= y + dy < 32}
        return f

    def flip(self):
        """Mirror about the body's centre column (x = 15.5)."""
        f = Frame()
        f.px = {(31 - x, y): c for (x, y), c in self.px.items()}
        return f

    def image(self):
        im = Image.new('RGBA', (32, 32))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c)
        return im


def noise(x, y, seed=0):
    n = (x * 374761393 + y * 668265263 + seed * 2147483647) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def ground_shadow(cx, cy, rx, ry):
    f = Frame()
    for y in range(32):
        for x in range(32):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                f.put(x, y, SHADOW)
    return f


def boulder(cx, cy, rx, ry, pal, seed, lumps=0.07):
    """A rounded stone: a lumpy ellipse shaded from the upper left."""
    f = Frame()
    for y in range(32):
        for x in range(32):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            a = math.atan2(dy, dx)
            r = 1.0 + lumps * math.sin(3 * a + seed) + lumps * 0.6 * math.sin(5 * a + seed * 2.3)
            nx, ny = dx / (rx * r), dy / (ry * r)
            d = nx * nx + ny * ny
            if d > 1.0:
                continue
            lit = nx * 0.55 + ny * 0.8 + (noise(x, y, seed) - 0.5) * 0.28
            tone = 0 if lit < -0.62 else 1 if lit < -0.18 else 2 if lit < 0.3 else 3 if lit < 0.72 else 4
            f.put(x, y, pal[tone])
    return f


# --- lifting stones -------------------------------------------------------

def stone_small():
    f = boulder(16, 20.5, 6.2, 5.0, COBBLE, 3)
    f.pts(COBBLE[0], (13, 18), (14, 17), (15, 17))                 # water-worn shine
    f.pts(COBBLE[3], (17, 21), (18, 21), (19, 20))                 # a vein
    return f.outline().under(ground_shadow(16.5, 25.3, 7.0, 1.8))


def stone_heavy():
    f = boulder(16, 18.5, 9.2, 7.6, QUARRY, 8)
    # a pecked groove round the middle to take the fingers
    for x in range(7, 26):
        y = 19 + (1 if 11 < x < 21 else 0)
        if (x, y) in f.px:
            f.put(x, y, QUARRY[4] if x > 12 else QUARRY[3])
            if (x, y - 1) in f.px and x % 3:
                f.put(x, y - 1, QUARRY[1] if x < 16 else QUARRY[2])
    f.pts(QUARRY[0], (11, 13), (12, 12), (13, 12), (14, 12), (10, 14))
    f.pts(QUARRY[4], (20, 23), (21, 22), (18, 24))
    return f.outline().under(ground_shadow(17, 26.6, 10.2, 2.2))


def stone_great():
    f = boulder(16, 17, 12.4, 10.6, GRANITE, 14, lumps=0.05)
    # two hand holds pecked into the flanks
    for (hx, hy) in ((8, 18), (23, 19)):
        f.rect(hx, hy, hx + 2, hy + 1, GRANITE[4])
        f.pts(OUT, (hx + 1, hy + 1), (hx + 2, hy + 1))
        f.pts(GRANITE[1], (hx, hy - 1), (hx + 1, hy - 1), (hx + 2, hy - 1))
    # lichen on the weather side, a crack down the lee side
    for (x, y) in ((11, 9), (12, 9), (12, 10), (13, 8), (17, 8), (18, 9), (9, 12), (15, 11), (20, 11)):
        f.put(x, y, LICHEN[noise(x, y, 5) > 0.5])
    f.pts(GRANITE[4], (19, 13), (19, 14), (20, 15), (20, 16), (21, 17), (20, 23), (19, 24))
    f.pts(GRANITE[0], (8, 11), (9, 10), (10, 9), (7, 13))
    return f.outline().under(ground_shadow(17, 27.6, 13.0, 2.4))


def haltere(f, x0, y0):
    """One bronze hand weight: a round grip between two flared ends."""
    f.rect(x0 + 3, y0 + 2, x0 + 7, y0 + 3, BRONZE[2])
    f.rect(x0 + 3, y0 + 2, x0 + 7, y0 + 2, BRONZE[1])
    for ex in (x0, x0 + 8):
        f.rect(ex, y0, ex + 2, y0 + 5, BRONZE[2])
        f.rect(ex, y0, ex + 2, y0, BRONZE[0])
        f.rect(ex, y0 + 1, ex, y0 + 3, BRONZE[1])
        f.rect(ex + 2, y0 + 2, ex + 2, y0 + 5, BRONZE[3])
        f.rect(ex, y0 + 5, ex + 2, y0 + 5, BRONZE[4])
    f.pts(BRONZE[0], (x0 + 4, y0 + 2), (x0 + 5, y0 + 2))


def hand_weights():
    f = Frame()
    haltere(f, 5, 9)
    haltere(f, 15, 18)
    return f.outline().under(ground_shadow(11, 16.0, 6.5, 1.5)).under(ground_shadow(21, 25.0, 6.5, 1.5))


def plate(f, cx, y0, y1, wide=2):
    """An iron plate seen nearly edge on."""
    for y in range(y0, y1 + 1):
        t = (y - y0) / max(1, y1 - y0)
        inset = 1 if y in (y0, y1) else 0
        for x in range(cx - wide + inset, cx + wide - inset + 1):
            tone = 1 if t < 0.2 else 2 if t < 0.55 else 3 if t < 0.85 else 4
            if x == cx - wide + inset and t < 0.7:
                tone = max(0, tone - 1)
            f.put(x, y, IRON[tone])


def barbell():
    f = Frame()
    f.rect(1, 18, 30, 18, IRON[1])
    f.rect(1, 19, 30, 19, IRON[3])
    for x in (13, 14, 17, 18):                                    # knurled grip
        f.put(x, 18, IRON[0])
    plate(f, 5, 11, 26, 2)
    plate(f, 9, 13, 24, 1)
    plate(f, 26, 11, 26, 2)
    plate(f, 22, 13, 24, 1)
    f.rect(11, 17, 11, 20, IRON[2])                               # collars
    f.rect(20, 17, 20, 20, IRON[2])
    return f.outline().under(ground_shadow(16, 27.2, 14.0, 1.8))


# --- the course -----------------------------------------------------------

def post(f, x0, y0, y1, wide=3):
    """An upright wooden post with a chocked foot."""
    for y in range(y0, y1 + 1):
        for i in range(wide):
            tone = (1, 3, 5)[i] if wide == 3 else (1, 4)[i]
            if noise(x0 + i, y // 3, 4) > 0.82 and i == 1:
                tone = 4
            f.put(x0 + i, y, WOOD[tone])
    for i in range(wide):
        f.put(x0 + i, y0, WOOD[0])                                # cut top
    # stones wedged round the foot
    f.pts(QUARRY[1], (x0 - 2, y1), (x0 - 1, y1 - 1), (x0 + wide, y1 - 1))
    f.pts(QUARRY[3], (x0 - 1, y1), (x0 + wide, y1), (x0 + wide + 1, y1))


def start_post(wave):
    """A post flying a red pennant; three frames of flutter."""
    f = Frame()
    post(f, 12, 5, 27)
    f.pts(ROPE[0], (12, 7), (13, 7), (14, 7), (12, 13), (13, 13), (14, 13))
    f.pts(ROPE[1], (14, 8), (14, 14))
    for i in range(12):                                           # pennant, hoist to fly
        x = 15 + i
        half = 3.4 * (1 - i / 12.0)
        mid = 10.2 + (0, 0.9, -0.7)[wave] * math.sin(i / 2.6 + wave * 1.3) * (i / 11.0) * 1.6
        for y in range(32):
            if abs(y + 0.5 - mid) <= half + 0.2:
                fold = math.sin(i / 1.7 + wave * 2.1)
                tone = 0 if (y + 0.5 - mid) < -half * 0.3 and fold > -0.3 else 2 if fold < -0.55 or (y + 0.5 - mid) > half * 0.55 else 1
                f.put(x, y, RED[tone])
    return f.outline().under(ground_shadow(14.5, 28.3, 5.0, 1.6))


def finish_post():
    """A shorter post hung with a leaf wreath and two white ribbons."""
    f = Frame()
    post(f, 14, 7, 27)
    cx, cy = 15.5, 13.5
    for y in range(32):
        for x in range(32):
            d = math.hypot(x + 0.5 - cx, (y + 0.5 - cy) * 0.95)
            if 3.3 <= d <= 6.1:
                a = math.atan2(y + 0.5 - cy, x + 0.5 - cx)
                leafy = math.sin(a * 7 + d)
                tone = 0 if leafy > 0.35 and (x + y) < 30 else 2 if leafy < -0.45 or (x + y) > 33 else 1
                f.put(x, y, LEAF[tone])
    for (x, y) in ((12, 20), (12, 21), (11, 22), (11, 23), (10, 24), (18, 20), (19, 21), (19, 22), (20, 23), (20, 24)):
        f.put(x, y, CLOTH[0] if x < 15 else CLOTH[1])
    f.pts(RED[1], (10, 25), (20, 25))
    return f.outline().under(ground_shadow(16.5, 28.3, 5.0, 1.6))


def log_h(f, x0, x1, y0, y1, bark=True, seed=0):
    """A log lying across the tile, round in section."""
    rows = y1 - y0 + 1
    for y in range(y0, y1 + 1):
        t = (y - y0) / max(1, rows - 1)
        for x in range(x0, x1 + 1):
            if bark:
                tone = 0 if t < 0.2 else 1 if t < 0.5 else 2 if t < 0.8 else 3
                if noise(x // 3, y, seed) > 0.8 and 0 < tone < 3:
                    tone += 1
                f.put(x, y, BARK[tone])
            else:
                tone = 0 if t < 0.2 else 2 if t < 0.55 else 3 if t < 0.85 else 5
                f.put(x, y, WOOD[tone])
    for y in range(y0, y1 + 1):                                   # pale sawn ends
        f.put(x0, y, WOOD[1] if y < y1 else WOOD[3])
        f.put(x1, y, WOOD[2] if y < y1 else WOOD[4])


def log_v(f, x0, x1, y0, y1, bark=True, seed=0):
    cols = x1 - x0 + 1
    for x in range(x0, x1 + 1):
        t = (x - x0) / max(1, cols - 1)
        for y in range(y0, y1 + 1):
            if bark:
                tone = 0 if t < 0.2 else 1 if t < 0.5 else 2 if t < 0.8 else 3
                if noise(x, y // 3, seed) > 0.8 and 0 < tone < 3:
                    tone += 1
                f.put(x, y, BARK[tone])
            else:
                tone = 0 if t < 0.2 else 2 if t < 0.55 else 3 if t < 0.85 else 5
                f.put(x, y, WOOD[tone])
    for x in range(x0, x1 + 1):
        f.put(x, y0, WOOD[1])
        f.put(x, y1, WOOD[3] if x < x1 else WOOD[4])


def fork(f, x, y0, y1):
    """A forked stake holding the rail."""
    f.rect(x, y0 + 2, x + 1, y1, WOOD[3])
    for y in range(y0 + 2, y1 + 1):
        f.put(x, y, WOOD[2])
        f.put(x + 1, y, WOOD[5])
    f.pts(WOOD[2], (x - 1, y0), (x - 1, y0 + 1), (x + 2, y0), (x + 2, y0 + 1))
    f.pts(QUARRY[2], (x - 1, y1), (x + 2, y1))


def log_hurdle_h():
    f = Frame()
    fork(f, 5, 11, 27)
    fork(f, 25, 11, 27)
    log_h(f, 2, 29, 12, 15, bark=False)
    for x in (5, 6, 25, 26):                                      # lashings
        f.put(x, 12, ROPE[0]); f.put(x, 13, ROPE[0]); f.put(x, 14, ROPE[1]); f.put(x, 15, ROPE[1])
    return f.outline().under(ground_shadow(16, 28.2, 13.0, 1.6))


def log_hurdle_v():
    """The same hurdle seen end on: the rail runs away up the tile."""
    f = Frame()
    for y in (7, 23):                                             # a trestle foot under each end
        f.rect(10, y + 2, 21, y + 3, WOOD[3])
        f.rect(10, y + 2, 21, y + 2, WOOD[1])
        f.pts(WOOD[5], (10, y + 3), (21, y + 3))
        f.pts(QUARRY[2], (9, y + 3), (22, y + 3))
    log_v(f, 14, 17, 3, 27, bark=False)
    for y in (8, 9, 24, 25):
        f.put(14, y, ROPE[0]); f.put(15, y, ROPE[0]); f.put(16, y, ROPE[1]); f.put(17, y, ROPE[1])
    return f.outline().under(ground_shadow(16.5, 29.4, 7.5, 1.4))


def balance_log_h():
    f = Frame()
    for x in (5, 24):                                             # low chocks
        f.rect(x, 23, x + 3, 26, WOOD[4])
        f.rect(x, 23, x + 3, 23, WOOD[2])
        f.rect(x + 3, 24, x + 3, 26, WOOD[5])
    log_h(f, 1, 30, 16, 23, seed=6)
    f.rect(2, 16, 29, 17, WOOD[1])                                # top hewn flat to walk on
    for x in range(2, 30):
        if noise(x, 0, 9) > 0.72:
            f.put(x, 17, WOOD[2])
        if x % 7 == 3:
            f.put(x, 16, WOOD[0])
    return f.outline().under(ground_shadow(16, 27.2, 14.5, 1.6))


def balance_log_v():
    f = Frame()
    for y in (5, 23):
        f.rect(10, y, 21, y + 2, WOOD[4])
        f.rect(10, y, 21, y, WOOD[2])
        f.pts(WOOD[5], (10, y + 2), (21, y + 2))
    log_v(f, 12, 19, 1, 29, seed=6)
    f.rect(14, 2, 16, 28, WOOD[1])
    for y in range(2, 29):
        if noise(0, y, 9) > 0.72:
            f.put(16, y, WOOD[2])
        if y % 7 == 3:
            f.put(14, y, WOOD[0])
    return f.outline().under(ground_shadow(16.5, 30.2, 5.5, 1.2))


def steel_hurdle_h():
    f = Frame()
    for x in (6, 25):                                             # legs and feet
        f.rect(x, 12, x, 26, IRON[2])
        f.rect(x, 26, x + 1, 26, IRON[3])
        for i in range(4):
            f.put(x - 1 - i + (x == 6) * 0 + (0 if x == 6 else 2 + 2 * i), 27 + i // 2, IRON[3])
    f.rect(6, 22, 25, 22, IRON[3])                                # brace
    f.rect(3, 8, 28, 12, CLOTH[0])                                # the board
    f.rect(3, 12, 28, 12, CLOTH[2])
    for x in range(3, 29):
        if (x - 3) // 5 % 2 == 1:
            f.rect(x, 8, x, 11, RED[1])
            f.put(x, 8, RED[0])
            f.put(x, 12, RED[2])
    return f.outline().under(ground_shadow(16, 28.6, 13.0, 1.5))


def steel_hurdle_v():
    f = Frame()
    f.rect(15, 4, 16, 24, CLOTH[0])
    f.rect(16, 4, 16, 24, CLOTH[1])
    for y in range(4, 25):
        if (y - 4) // 5 % 2 == 1:
            f.put(15, y, RED[0]); f.put(16, y, RED[1])
    for y in (6, 22):
        f.rect(11, y + 3, 20, y + 3, IRON[3])
        f.rect(11, y + 2, 20, y + 2, IRON[1])
        f.pts(IRON[2], (15, y + 1), (16, y + 1))
    return f.outline().under(ground_shadow(16, 27.4, 6.5, 1.3))


# --- the tread wheel ------------------------------------------------------
# Frames are S, N, E, W. `step` is the animation frame, 0 to 3; `way` is +1
# when the walker faces east or south and -1 for west or north.

def treadwheel_side(step, way):
    """The wheel side on: rim, tread boards, six spokes and the hub on its
    axle, carried by an A frame on a sill."""
    f = Frame()
    cx, cy, big = 16.0, 17.0, 13.5
    for i in range(13):                                           # the A frame behind the wheel
        y = 17 + i
        for x in (15 - i * 11 // 12, 16 + i * 11 // 12):
            f.put(x, y, WOOD[4])
            f.put(x + (-1 if x < 16 else 1), y, WOOD[5] if x > 16 else WOOD[3])
    f.rect(2, 29, 29, 30, WOOD[3])                                # the sill
    f.rect(2, 29, 29, 29, WOOD[1])
    f.pts(WOOD[5], (2, 30), (29, 30))
    turn = way * step * 15.0
    for y in range(32):
        for x in range(32):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            r = math.hypot(dx, dy)
            if r > big:
                continue
            a = math.degrees(math.atan2(dy, dx)) - turn
            lit = (dx * 0.55 + dy * 0.8) / big
            near = (a + 30.0) % 60.0 - 30.0                       # degrees from the nearest spoke
            across = abs(r * math.sin(math.radians(near)))
            if r >= 11.4:                                         # the rim, jointed between the spokes
                tone = 0 if lit < -0.6 else 1 if lit < -0.15 else 2 if lit < 0.35 else 3 if lit < 0.7 else 4
                if abs(r * math.sin(math.radians(a % 60.0 - 30.0))) < 0.55:
                    tone = 5
                f.put(x, y, WOOD[tone])
            elif r >= 10.0:                                       # tread boards on the inside of the rim
                f.put(x, y, WOOD[(1, 3, 5, 3)[int((a % 60.0) // 15.0)]])
            elif r <= 2.7:
                f.put(x, y, IRON[1] if r < 1.0 else WOOD[1] if lit < -0.05 else WOOD[3])
            elif across <= 0.85:
                f.put(x, y, WOOD[2] if lit < 0.1 else WOOD[3])
    f.pts(IRON[3], (16, 17))
    return f.outline().under(ground_shadow(16, 30.6, 14.5, 1.3))


def treadwheel_end(step, way):
    """The wheel end on: the boarded drum between two posts, its boards
    drawing together toward the top and the bottom as they go round."""
    f = Frame()
    cy, big = 17.0, 13.5
    for x0 in (3, 26):                                            # posts, feet and axle
        for y in range(11, 30):
            f.put(x0, y, WOOD[1]); f.put(x0 + 1, y, WOOD[3]); f.put(x0 + 2, y, WOOD[5])
        f.rect(x0, 11, x0 + 2, 11, WOOD[0])
        f.rect(x0 - 2, 29, x0 + 4, 30, WOOD[3])
        f.rect(x0 - 2, 29, x0 + 4, 29, WOOD[1])
        f.rect(x0, 15, x0 + 2, 18, WOOD[2])
        f.pts(IRON[1], (x0 + 1, 16)); f.pts(IRON[3], (x0 + 1, 17))
    f.rect(6, 16, 25, 16, IRON[1])
    f.rect(6, 17, 25, 17, IRON[3])
    for y in range(4, 30):
        up = (y + 0.5 - cy) / big
        deg = math.degrees(math.asin(max(-1.0, min(1.0, up))))
        part = (deg / 20.0 - way * step / 4.0) % 1.0
        inset = 1 if y in (4, 29) else 0
        for x in range(9 + inset, 23 - inset):
            if x in (9, 10, 21, 22):                              # the two rims
                tone = (0 if up < -0.5 else 1 if up < 0.3 else 2) + (0, 1, 2, 3)[(9, 10, 21, 22).index(x)]
                f.put(x, y, WOOD[min(5, tone)])
            elif part < 0.5:
                tone = 0 if up < -0.55 else 1 if up < -0.1 else 2 if up < 0.5 else 3
                if x > 17:
                    tone += 1
                f.put(x, y, WOOD[tone])
            else:
                f.put(x, y, WOOD[5] if part < 0.75 or up > 0.4 else WOOD[4])
    return f.outline().under(ground_shadow(16, 30.8, 14.5, 1.2))


def treadwheel(step):
    return [treadwheel_end(step, 1), treadwheel_end(step, -1), treadwheel_side(step, 1), treadwheel_side(step, -1)]


# --- the motor treadmill --------------------------------------------------

def treadmill_side(step, lit):
    """Facing east: the belt runs across the tile to a motor hood, with the
    handrail and console standing over the hood."""
    f = Frame()
    f.rect(2, 23, 24, 23, IRON[1])                                # far rail
    f.rect(2, 30, 24, 30, IRON[3])                                # near rail
    f.rect(2, 24, 2, 29, IRON[2])                                 # tail roller
    for y in range(24, 30):
        for x in range(3, 24):
            stripe = (x + step) % 4 == 0
            f.put(x, y, RUBBER[0] if stripe and y < 29 else RUBBER[2] if y == 29 else RUBBER[1])
    f.rect(24, 21, 29, 30, IRON[2])                               # motor hood
    f.rect(24, 21, 29, 21, IRON[0])
    f.rect(24, 22, 24, 29, IRON[1])
    f.rect(29, 23, 29, 30, IRON[3])
    f.rect(25, 30, 29, 30, IRON[4])
    f.pts(IRON[4], (26, 25), (27, 25), (26, 27), (27, 27))        # vents
    for y in range(10, 21):                                       # upright
        f.put(26, y, IRON[1]); f.put(27, y, IRON[3])
    f.rect(20, 12, 25, 12, IRON[1])                               # handrail back toward the runner
    f.rect(19, 12, 21, 12, RUBBER[1])
    f.rect(23, 6, 29, 9, IRON[4])                                 # console
    f.rect(23, 6, 29, 6, IRON[1])
    f.pts(IRON[2], (23, 7), (23, 8), (23, 9))
    f.pts(LAMP[0] if lit else LAMP[2], (25, 8))
    f.pts(LAMP[1] if lit and step % 2 == 0 else LAMP[2], (27, 8))
    return f.outline().under(ground_shadow(16, 30.9, 14.5, 1.1))


def treadmill_end(step, lit, north):
    """The belt running up the tile. Facing north the hood, rail and console
    stand at the top; facing south they stand at the bottom."""
    f = Frame()
    if north:
        y0, y1 = 12, 29
    else:
        y0, y1 = 3, 26
    for y in range(y0, y1 + 1):
        f.put(8, y, IRON[0]); f.put(9, y, IRON[2])                # side rails
        f.put(22, y, IRON[2]); f.put(23, y, IRON[4])
        for x in range(10, 22):
            stripe = (y - step if north else y + step) % 4 == 0
            f.put(x, y, RUBBER[0] if stripe and x < 20 else RUBBER[2] if x == 21 else RUBBER[1])
    if north:
        f.rect(8, 30, 23, 30, IRON[3])                            # tail roller
        f.rect(8, 9, 23, 11, IRON[2])                             # hood
        f.rect(8, 9, 23, 9, IRON[0])
        f.rect(8, 11, 23, 11, IRON[3])
        f.pts(IRON[4], (13, 10), (14, 10), (17, 10), (18, 10))
        for x0 in (7, 23):                                        # uprights and the bar between them
            for y in range(3, 10):
                f.put(x0, y, IRON[1]); f.put(x0 + 1, y, IRON[3])
        f.rect(7, 3, 24, 3, IRON[1])
        f.rect(7, 4, 24, 4, IRON[3])
        f.rect(11, 1, 20, 4, IRON[4])                             # console
        f.rect(11, 1, 20, 1, IRON[1])
        f.pts(LAMP[0] if lit else LAMP[2], (12, 2))
        f.pts(LAMP[1] if lit and step % 2 == 0 else LAMP[2], (19, 2))
    else:
        f.rect(8, 2, 23, 2, IRON[2])                              # tail roller
        f.rect(8, 27, 23, 30, IRON[2])                            # hood
        f.rect(8, 27, 23, 27, IRON[0])
        f.rect(8, 30, 23, 30, IRON[4])
        f.pts(IRON[4], (13, 29), (14, 29), (17, 29), (18, 29))
        for x0 in (6, 24):
            for y in range(15, 30):
                f.put(x0, y, IRON[1]); f.put(x0 + 1, y, IRON[3])
        f.rect(6, 15, 25, 15, IRON[1])
        f.rect(6, 16, 25, 16, IRON[3])
        f.rect(4, 14, 5, 14, RUBBER[1]); f.rect(26, 14, 27, 14, RUBBER[1])   # grips
        f.rect(4, 15, 5, 15, RUBBER[2]); f.rect(26, 15, 27, 15, RUBBER[2])
        f.rect(20, 11, 27, 14, IRON[4])                           # console on the rail's end
        f.rect(20, 11, 27, 11, IRON[1])
        f.pts(LAMP[0] if lit else LAMP[2], (25, 13))
        f.pts(LAMP[1] if lit and step % 2 == 0 else LAMP[2], (26, 13))
    return f.outline().under(ground_shadow(16, 30.9, 10.5, 1.1))


def treadmill(step, lit):
    east = treadmill_side(step, lit)
    return [treadmill_end(step, lit, False), treadmill_end(step, lit, True), east, east.flip()]


# --- the skipping rope ----------------------------------------------------

def handle(f, x0, y0):
    """A turned wooden handle lying along the tile, the rope leaving its right end."""
    for i, x in enumerate(range(x0, x0 + 8)):
        waist = i in (2, 6)
        f.put(x, y0, WOOD[1] if waist else WOOD[0])
        f.put(x, y0 + 1, WOOD[3] if waist else WOOD[2])
        f.put(x, y0 + 2, WOOD[5] if waist else WOOD[4])
    f.pts(WOOD[1], (x0 - 1, y0 + 1))                              # the knob


def skipping_rope():
    f = Frame()
    for (cx, cy, rx, ry) in ((15.0, 20.5, 8.2, 5.2), (17.5, 19.5, 7.4, 4.6)):   # two turns of the coil
        for i in range(360):
            a = math.radians(i)
            x, y = int(cx + rx * math.cos(a)), int(cy + ry * math.sin(a))
            f.put(x, y, ROPE[1] if (x + y) % 3 == 0 or math.sin(a) > 0.5 else ROPE[0])
    handle(f, 4, 8)
    handle(f, 15, 11)
    f.pts(ROPE[0], (12, 9), (13, 10), (13, 11), (13, 12), (12, 13), (11, 14))
    f.pts(ROPE[1], (13, 13))
    f.pts(ROPE[0], (23, 12), (24, 13), (25, 14))
    f.pts(ROPE[1], (25, 15), (25, 16))
    return f.outline().under(ground_shadow(16.5, 25.6, 9.5, 1.6))


# --- held in the hands ----------------------------------------------------
# Frames are S, N, E, W. The left hand's column for each facing:
HAND = (21, 9, 16, 13)


def held_one(make):
    left = [make(HAND[d], d) for d in range(4)]
    return left, [left[0].flip(), left[1].flip(), left[3].flip(), left[2].flip()]


def held_both(make):
    both = [make(d) for d in range(4)]
    return both, both


def small_in_hand(x, d):
    return boulder(x + 0.5, 18.5, 2.6, 2.4, COBBLE, 3, lumps=0).outline()


def small_lifted(x, d):
    return boulder(x + (0.5 if d < 2 else 0.5), 8.5, 2.6, 2.4, COBBLE, 3, lumps=0).outline()


def carried(pal, rx, ry, seed):
    """A stone hugged to the body with both hands."""
    def make(d):
        cx = (15.5, 15.5, 20.0, 11.0)[d]
        f = boulder(cx + 0.5, 18.5, rx, ry, pal, seed, lumps=0.03).outline()
        if d == 1:                                                # facing away: only its flanks show
            f.px = {p: c for p, c in f.px.items() if p[0] < 12 or p[0] > 19}
        return f
    return make


def overhead(pal, rx, ry, seed):
    def make(d):
        cx = (15.5, 15.5, 17.0, 14.0)[d]
        return boulder(cx + 0.5, 3.6 + ry * 0.35, rx, ry * 0.9, pal, seed, lumps=0.03).outline()
    return make


def weight_in_hand(x, d):
    f = Frame()
    if d < 2:
        f.rect(x - 2, 18, x + 3, 19, BRONZE[2])
        f.rect(x - 2, 17, x - 1, 20, BRONZE[1]); f.rect(x + 2, 17, x + 3, 20, BRONZE[3])
        f.pts(BRONZE[0], (x - 2, 17), (x + 2, 17))
    else:
        f.rect(x - 1, 17, x + 1, 20, BRONZE[2])
        f.pts(BRONZE[0], (x - 1, 17), (x, 17)); f.pts(BRONZE[4], (x + 1, 20))
    return f.outline()


def weight_lifted(x, d):
    return weight_in_hand(x, d).shift(0, -9)


def bar_frame(d, y):
    f = Frame()
    if d < 2:
        f.rect(3, y, 28, y, IRON[1])
        f.rect(3, y + 1, 28, y + 1, IRON[3])
        plate(f, 5, y - 4, y + 5, 1)
        plate(f, 26, y - 4, y + 5, 1)
        f.outline()
        if d == 1 and y > 12:                                     # behind the body when carried facing away
            f.px = {p: c for p, c in f.px.items() if p[0] < 12 or p[0] > 19}
        return f
    cx = 19.5 if d == 2 else 12.5
    if y < 12:
        cx = 16.5 if d == 2 else 15.5
    for yy in range(32):
        for xx in range(32):
            r = math.hypot(xx + 0.5 - cx, yy + 0.5 - (y + 0.5))
            if r <= 4.6:
                f.put(xx, yy, IRON[0] if r < 1.2 else IRON[3] if r < 2.2 else IRON[1] if (xx + yy) < cx + y - 1 else IRON[2])
    return f.outline()


def rope_in_hand(x, d):
    """Both handles in one fist, the rope hanging in a loop beside the leg."""
    f = Frame()
    f.pts(WOOD[0], (x, 16)); f.pts(WOOD[2], (x, 17), (x, 18)); f.pts(WOOD[4], (x, 19))
    f.pts(WOOD[1], (x + 1, 16)); f.pts(WOOD[3], (x + 1, 17), (x + 1, 18)); f.pts(WOOD[5], (x + 1, 19))
    for y in range(20, 27):
        f.put(x, y, ROPE[0] if y % 3 else ROPE[1])
        f.put(x + 1, y, ROPE[1])
    f.pts(ROPE[1], (x, 27), (x + 1, 27))
    return f.outline()


def rope_swung(d):
    """Mid skip: a handle in each hand and the rope passing over the head."""
    f = Frame()
    if d < 2:
        for i in range(0, 901):                                   # one half placed, the other mirrored
            a = math.radians(180 + i / 10.0)
            x, y = int(16.0 + 10.0 * math.cos(a)), int(17.0 + 16.0 * math.sin(a))
            if x < 16 and y < 17:
                f.put(x, y, ROPE[1] if (x + y) % 4 == 0 else ROPE[0])
                f.put(31 - x, y, ROPE[1] if (x + y) % 4 == 1 else ROPE[0])
        for x in (6, 25):
            f.pts(WOOD[0], (x, 16)); f.pts(WOOD[2], (x, 17)); f.pts(WOOD[4], (x, 18))
        return f.outline()
    for y in range(1, 16):                                        # seen from the side it leans back over the head
        t = (15 - y) / 14.0
        x = int(round(16 - 8.0 * t ** 0.8))
        f.put(x, y, ROPE[1] if y % 4 == 0 else ROPE[0])
    f.pts(WOOD[0], (16, 16)); f.pts(WOOD[2], (16, 17)); f.pts(WOOD[4], (16, 18))
    f.outline()
    return f if d == 2 else f.flip()


HELD = {
    'lifting_stone_small': held_one(small_in_hand),
    'lifting_stone_small_lift': held_one(small_lifted),
    'lifting_stone_heavy': held_both(carried(QUARRY, 4.3, 3.6, 8)),
    'lifting_stone_heavy_lift': held_both(overhead(QUARRY, 4.3, 3.6, 8)),
    'lifting_stone_great': held_both(carried(GRANITE, 5.6, 4.6, 14)),
    'lifting_stone_great_lift': held_both(overhead(GRANITE, 5.6, 4.6, 14)),
    'hand_weights': held_one(weight_in_hand),
    'hand_weights_lift': held_one(weight_lifted),
    'barbell': held_both(lambda d: bar_frame(d, 19)),
    'barbell_lift': held_both(lambda d: bar_frame(d, 4)),
    'skipping_rope': held_one(rope_in_hand),
    'skipping_rope_lift': held_both(rope_swung),
}

# name -> (dirs, frames, delay, [frames in DMI order: every direction of frame 1, then frame 2 ...])
OBJ = {
    'lifting_stone_small': (1, 1, None, [stone_small()]),
    'lifting_stone_heavy': (1, 1, None, [stone_heavy()]),
    'lifting_stone_great': (1, 1, None, [stone_great()]),
    'hand_weights': (1, 1, None, [hand_weights()]),
    'barbell': (1, 1, None, [barbell()]),
    'course_start': (1, 3, 3, [start_post(0), start_post(1), start_post(2)]),
    'course_finish': (1, 1, None, [finish_post()]),
    'log_hurdle': (4, 1, None, [log_hurdle_h(), log_hurdle_h(), log_hurdle_v(), log_hurdle_v()]),
    'balance_log': (4, 1, None, [balance_log_h(), balance_log_h(), balance_log_v(), balance_log_v()]),
    'steel_hurdle': (4, 1, None, [steel_hurdle_h(), steel_hurdle_h(), steel_hurdle_v(), steel_hurdle_v()]),
    'treadwheel': (4, 1, None, treadwheel(0)),
    'treadwheel_turning': (4, 4, 1, [fr for step in range(4) for fr in treadwheel(step)]),
    'treadmill': (4, 1, None, treadmill(0, False)),
    'treadmill_running': (4, 4, 1, [fr for step in range(4) for fr in treadmill(step, True)]),
    'skipping_rope': (1, 1, None, [skipping_rope()]),
}


def states(key):
    if key == 'obj':
        return OBJ
    side = 0 if key == 'left' else 1
    return {name: (4, 1, None, pair[side]) for name, pair in HELD.items()}


def dmi_bytes(table):
    frames = [fr for (_, _, _, frs) in table.values() for fr in frs]
    cols = 8
    rows = (len(frames) + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * 32, rows * 32))
    for i, fr in enumerate(frames):
        sheet.paste(fr.image(), ((i % cols) * 32, (i // cols) * 32))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, (dirs, count, delay, _) in table.items():
        text += 'state = "%s"\n\tdirs = %d\n\tframes = %d\n' % (name, dirs, count)
        if delay:
            text += '\tdelay = %s\n' % ','.join([str(delay)] * count)
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    out = io.BytesIO()
    sheet.save(out, format='PNG', pnginfo=meta)
    return out.getvalue()


def check_drawing():
    problems = []
    for name, (dirs, count, _, frs) in OBJ.items():
        if len(frs) != dirs * count:
            problems.append('%s: frame count does not match its directions' % name)
        for fr in frs:
            solid = [p for p, c in fr.px.items() if c[3] == 255]
            if not solid:
                problems.append('%s: empty frame' % name)
    for name, (left, right) in HELD.items():
        for fr in left + right:
            if not fr.px:
                problems.append('%s: an in-hand frame is empty' % name)
        if name + '_lift' not in HELD and not name.endswith('_lift'):
            problems.append('%s: no raised state' % name)
    return problems


def old_state(path, name):
    sheet = Image.open(ROOT / path)
    index, found = 0, None
    dirs = frames = 1
    current = None
    for line in sheet.info.get('Description', '').split('\n'):
        line = line.strip()
        if line.startswith('state = '):
            if current is not None:
                if current == name and found is None:
                    found = index
                index += dirs * frames
            current, dirs, frames = line[9:-1], 1, 1
        elif line.startswith('dirs = '):
            dirs = int(line[7:])
        elif line.startswith('frames = '):
            frames = int(line[9:])
    if found is None and current == name:
        found = index
    sheet = sheet.convert('RGBA')
    cols = sheet.width // 32
    return sheet.crop(((found % cols) * 32, (found // cols) * 32, (found % cols) * 32 + 32, (found // cols) * 32 + 32))


def write_preview(path, scale=6):
    """First the two borrowed icons the weights replaced, then every icon on
    grass and again on dirt (a four-direction state shows south and east, a
    moving state adds its second frame), then each held thing carried and
    raised, facing south, north, east and west."""
    grass, dirt, back = (86, 128, 62, 255), (134, 102, 70, 255), (30, 32, 36, 255)
    cell = 32 * scale
    tiles = []
    for name, (dirs, count, _, frs) in OBJ.items():
        tiles.append(frs[0])
        if dirs == 4:
            tiles.append(frs[2])
        if count > 1:
            tiles.append(frs[dirs])
            if dirs == 4:
                tiles.append(frs[dirs + 2])
    per_row = 14
    icon_rows = (len(tiles) + per_row - 1) // per_row
    names = [n for n in HELD if not n.endswith('_lift')]
    width = max(per_row * cell, len(names) * 4 * 96)
    y0 = (1 + 2 * icon_rows) * (cell + 4) + 8
    sheet = Image.new('RGBA', (width, y0 + 2 * 100 + 4), back)
    for i, (p, s) in enumerate((('icons/obj/materials.dmi', 'sheet-stone'), ('icons/obj/flags.dmi', 'flagpole_blank'))):
        tile = Image.new('RGBA', (32, 32), grass)
        tile.alpha_composite(old_state(p, s))
        sheet.alpha_composite(tile.resize((cell, cell), Image.NEAREST), (i * cell, 0))
    for r, ground in enumerate((grass, dirt)):
        for i, fr in enumerate(tiles):
            tile = Image.new('RGBA', (32, 32), ground)
            tile.alpha_composite(fr.image())
            sheet.alpha_composite(tile.resize((cell, cell), Image.NEAREST),
                                  ((i % per_row) * cell, (1 + r * icon_rows + i // per_row) * (cell + 4)))
    for r, suffix in enumerate(('', '_lift')):
        for i, name in enumerate(names):
            for d in range(4):
                tile = Image.new('RGBA', (32, 32), grass)
                tile.alpha_composite(base_body(d))
                tile.alpha_composite(HELD[name + suffix][0][d].image())
                sheet.alpha_composite(tile.resize((96, 96), Image.NEAREST), ((i * 4 + d) * 96, y0 + r * 100))
    sheet.convert('RGB').save(path)


def write_in_use(path, scale=5):
    """A plain body on the tread wheel and the treadmill and with the rope,
    facing south, north, east and west. Each row shows the still state and the
    third frame of the moving state (the rope: carried and swung, each hand),
    large and then at game size."""
    grass, back = (86, 128, 62, 255), (30, 32, 36, 255)
    rows = []
    for still, moving in (('treadwheel', 'treadwheel_turning'), ('treadmill', 'treadmill_running')):
        row = []
        for name, first in ((still, 0), (moving, 8)):
            for d in range(4):
                tile = Image.new('RGBA', (32, 32), grass)
                tile.alpha_composite(OBJ[name][3][first + d].image())
                tile.alpha_composite(base_body(d))
                row.append(tile)
        rows.append(row)
    for side in (0, 1):
        row = []
        for name in ('skipping_rope', 'skipping_rope_lift'):
            for d in range(4):
                tile = Image.new('RGBA', (32, 32), grass)
                tile.alpha_composite(base_body(d))
                tile.alpha_composite(HELD[name][side][d].image())
                row.append(tile)
        rows.append(row)
    cell = 32 * scale
    sheet = Image.new('RGBA', (8 * (cell + 4) + 8 * 34 + 12, len(rows) * (cell + 4)), back)
    for r, row in enumerate(rows):
        for i, tile in enumerate(row):
            sheet.alpha_composite(tile.resize((cell, cell), Image.NEAREST), (i * (cell + 4), r * (cell + 4)))
            sheet.alpha_composite(tile, (8 * (cell + 4) + 12 + i * 34, r * (cell + 4) + cell // 2 - 16))
    sheet.convert('RGB').save(path)


def main():
    args = sys.argv[1:]
    problems = check_drawing()
    if '--check' in args:
        for key, path in SHEETS.items():
            if not path.exists():
                problems.append('missing sheet: %s' % path)
            elif path.read_bytes() != dmi_bytes(states(key)):
                problems.append('stale sheet: %s' % path)
        for line in problems:
            print(line)
        print('training gear: %s' % ('FAILED' if problems else 'ok'))
        return 1 if problems else 0
    if problems:
        print('\n'.join(problems))
        return 1
    for key, path in SHEETS.items():
        path.write_bytes(dmi_bytes(states(key)))
    if '--preview' in args[:-1]:
        write_preview(args[args.index('--preview') + 1])
    if '--in-use' in args[:-1]:
        write_in_use(args[args.index('--in-use') + 1])
    return 0


if __name__ == '__main__':
    sys.exit(main())
