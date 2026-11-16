"""Hand-placed sprites for Stone Age wild bees and honey hunting in
icons/farming/wild_bees.dmi: the wild nest in a tree hollow (full, robbed and
abandoned), the green smoke bundle and its smouldering loop, the angry bee
cloud drawn over a person, brood comb, crushed comb, a cake of rendered
beeswax and the beeswax candles. Every pixel is placed by this script from
fixed palettes (Pillow only); no external or generated artwork. Shading is
soft with no black outline, like the straw `beehive` of
icons/farming/beekeeping.dmi.

The candles take their geometry, wick, flame and timing from the red
`candle1`-`candle4` states of icons/obj/candle.dmi: each red wax pixel is
recoloured on a golden beeswax ramp and the shoulders of the top row are
softened for a dipped look; every other pixel is copied as it stands.

The nest states are overlays for the trunk of a 64px tree: the hollow is
centred on x = 15/16, y = 9-19 (rows counted from the top) of the 32px frame,
so the frame goes over the lower middle of the tree, 16 pixels in from its
left edge. Everything round the bark lip is transparent.

Run with Pillow to write the sheet. `--check` verifies the committed sheet,
`--preview <png>` writes a 4x review sheet of every state and frame on grass,
the nests on `tree_1` of icons/obj/flora/bigtrees.dmi and the swarm over a
person, with 1x and 2x strips. Released under Civ13 AGPL-3.0.
"""
import math
import re
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/farming/wild_bees.dmi'
CANDLES = ROOT / 'icons/obj/candle.dmi'
TREES = ROOT / 'icons/obj/flora/bigtrees.dmi'
HUMAN = ROOT / 'icons/mob/human.dmi'

SIZE = 32

# bark lip round the hollow: highlight, light, mid, dark, deep
BARK = [(150, 118, 84), (122, 92, 62), (92, 66, 44), (64, 46, 32), (42, 30, 22)]
HOLLOW = [(30, 21, 15), (18, 12, 9)]
# fresh comb: highlight, light, mid, dark, cell shadow
COMB = [(250, 226, 140), (236, 196, 92), (208, 152, 52), (160, 104, 32), (112, 70, 22)]
# old, abandoned comb
OLD_COMB = [(134, 100, 52), (102, 72, 36), (72, 50, 26)]
# a bee: body, stripe, wing glint
BEE_DARK = (38, 28, 18)
BEE_GOLD = (246, 198, 48)
BEE_WING = (236, 236, 228, 150)
# green grass and leaves: highlight, light, mid, dark, deep
GREEN = [(158, 190, 92), (122, 160, 70), (88, 128, 54), (60, 96, 44), (40, 68, 36)]
CORD = [(206, 176, 120), (164, 130, 80), (116, 88, 54)]
CHAR = [(58, 50, 44), (34, 30, 28)]
EMBER = [(255, 214, 96), (246, 150, 40), (204, 84, 24)]
# smoke, nearest the bundle first
SMOKE = [(222, 220, 214, 230), (204, 202, 198, 200), (188, 186, 184, 160),
         (172, 170, 170, 120), (158, 158, 160, 80)]
# capped brood: highlight, cap, cap shade, wall, wall shade
BROOD = [(246, 232, 190), (228, 206, 152), (204, 174, 116), (166, 124, 66), (120, 84, 42)]
LARVA = (250, 246, 232)
# squeezed wax: highlight, light, mid, dark, crease
WAX = [(248, 238, 196), (232, 214, 156), (206, 180, 116), (170, 138, 82), (128, 98, 56)]
HONEY = [(250, 196, 72), (226, 142, 26), (184, 98, 12)]
# rendered beeswax: highlight, light, mid, shade, dark, deep
BEESWAX = [(255, 232, 138), (246, 204, 82), (228, 172, 48), (196, 136, 34), (154, 100, 24),
           (112, 70, 18)]


def grain(x, y, seed):
    """A fixed pseudo-random 0-15 for a pixel."""
    n = (int(x) * 73856093) ^ (int(y) * 19349663) ^ (seed * 83492791)
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return (n ^ (n >> 16)) & 15


class Frame:
    def __init__(self):
        self.px = {}

    def put(self, x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < SIZE and 0 <= y < SIZE:
            self.px[(x, y)] = tuple(c)

    def pts(self, c, *points):
        for x, y in points:
            self.put(x, y, c)

    def ellipse(self, cx, cy, rx, ry, shade):
        """Fill an ellipse; shade(x, y, nx, ny) returns a colour or None."""
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                nx, ny = (x - cx) / rx, (y - cy) / ry
                if nx * nx + ny * ny <= 1.0:
                    c = shade(x, y, nx, ny)
                    if c is not None:
                        self.put(x, y, c)

    def image(self):
        im = Image.new('RGBA', (SIZE, SIZE))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c if len(c) == 4 else c + (255,))
        return im


def bee(f, x, y, flip=0, wing=True):
    """One bee: a dark speck with a gold stripe beside it and a pale wing."""
    f.put(x, y, BEE_DARK)
    f.put(x + (-1 if flip else 1), y, BEE_GOLD)
    if wing:
        f.put(x, y - 1, BEE_WING)


# ------------------------------------------------------------------ nest --

NX, NY = 15.5, 14.0        # centre of the hollow


def hollow(f):
    """The swollen bark lip and the dark cavity inside it."""
    def lip(x, y, nx, ny):
        if nx * nx + ny * ny < 0.42:
            return None
        light = nx * 0.7 + ny * 0.7            # lit from the upper left
        if light < -0.55:
            c = BARK[0] if grain(x, y, 3) < 6 else BARK[1]
        elif light < -0.1:
            c = BARK[1]
        elif light < 0.4:
            c = BARK[2]
        else:
            c = BARK[3]
        if grain(x, y, 5) == 0:
            c = BARK[3] if light < 0.4 else BARK[4]
        return c
    f.ellipse(NX, NY, 4.6, 5.9, lip)

    def hole(x, y, nx, ny):
        return HOLLOW[0] if ny > 0.35 and grain(x, y, 7) < 9 else HOLLOW[1]
    f.ellipse(NX, NY, 3.1, 4.5, hole)
    # the lower lip catches the light where the bees land
    f.pts(BARK[1], (14, 19), (15, 19), (16, 19))
    f.pts(BARK[0], (15, 18), (16, 18))
    f.pts(BARK[2], (14, 18), (17, 18))


def combs(f, lengths):
    """Combs hanging from the roof of the hollow, seen edge on from the
    front: (x, width, length) each, pale and rounded at the bottom."""
    for x, w, n in lengths:
        for i in range(n):
            y = 10 + i
            for j in range(w):
                c = COMB[1] if j == 0 else COMB[2]
                if i == 0:
                    c = COMB[2] if j == 0 else COMB[3]       # in the roof shadow
                elif i == n - 1:
                    c = COMB[2] if j == 0 else COMB[3]       # rounded tip
                elif i == 1 and j == 0:
                    c = COMB[0]                              # light on the shoulder
                f.put(x + j, y, c)


# bee places per frame: (x, y, flip); the first rows crawl on the comb and
# lip, the rest fly round the mouth
NEST_BEES = [
    [(15, 13, 0), (15, 18, 0), (10, 9, 0), (21, 12, 1), (19, 21, 1), (9, 17, 0)],
    [(15, 14, 0), (16, 18, 1), (11, 7, 0), (22, 14, 1), (20, 19, 1), (8, 15, 0)],
    [(15, 15, 0), (16, 19, 1), (13, 6, 0), (22, 16, 1), (18, 22, 0), (9, 13, 0)],
    [(15, 14, 0), (15, 19, 0), (11, 8, 1), (21, 10, 1), (20, 22, 1), (10, 19, 0)],
]
LOW_BEES = [
    [(15, 18, 0), (20, 11, 1), (10, 16, 0)],
    [(16, 18, 1), (21, 13, 1), (9, 14, 0)],
    [(16, 19, 1), (21, 15, 1), (10, 12, 0)],
    [(15, 19, 0), (20, 13, 1), (11, 14, 0)],
]


def nest(k):
    f = Frame()
    hollow(f)
    combs(f, ((13, 1, 4), (15, 2, 7), (18, 1, 5)))
    for x, y, flip in NEST_BEES[k]:
        bee(f, x, y, flip, wing=not (12 <= x <= 18 and 9 <= y <= 19))
    return f


def nest_low(k):
    f = Frame()
    hollow(f)
    # torn stubs under the roof and one ragged piece left hanging
    combs(f, ((13, 1, 2), (14, 2, 2), (17, 2, 3)))
    f.pts(COMB[3], (15, 12), (18, 13))
    f.pts(COMB[4], (14, 12), (17, 13))
    f.pts(HONEY[2], (15, 17), (16, 17))        # a smear of spilt honey
    for x, y, flip in LOW_BEES[k]:
        bee(f, x, y, flip)
    return f


def nest_empty():
    f = Frame()
    hollow(f)
    f.pts(OLD_COMB[1], (13, 10), (14, 10), (15, 10), (14, 11), (17, 10))
    f.pts(OLD_COMB[0], (14, 12), (15, 11))
    f.pts(OLD_COMB[2], (15, 12), (17, 11))
    f.pts((70, 62, 54), (17, 14), (18, 13), (16, 15))        # an old web
    return f


# ---------------------------------------------------------- smoke bundle --

def smoke_bundle(lit=False, k=0):
    """A sheaf of green grass and leaves lying with its tied stalks at the
    lower left and its leafy head at the upper right."""
    f = Frame()
    ax, ay, bx, by = 6.0, 25.0, 23.0, 14.0
    length = math.hypot(bx - ax, by - ay)
    ux, uy = (bx - ax) / length, (by - ay) / length
    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = x - ax, y - ay
            t = (dx * ux + dy * uy) / length
            across = -dx * uy + dy * ux             # + is below the axis
            if not -0.02 <= t <= 1.0:
                continue
            half = 2.0 + 2.6 * max(0.0, t) ** 1.5
            if t > 0.9:
                half *= 1.0 - (t - 0.9) * 4.0
            ragged = half + (grain(x, y, 11) - 8) / 14.0 * (0.4 + t)
            if abs(across) > ragged:
                continue
            n = across / half
            streak = grain(int(across * 1.5 + 40), 0, 13)     # blades run lengthwise
            if n < -0.45:
                c = GREEN[0] if streak < 6 else GREEN[1]
            elif n < 0.2:
                c = GREEN[1] if streak < 5 else GREEN[2]
            elif n < 0.65:
                c = GREEN[2] if streak < 8 else GREEN[3]
            else:
                c = GREEN[3] if streak < 9 else GREEN[4]
            if t > 0.55 and grain(x, y, 17) < 3:
                c = GREEN[0] if n < 0 else GREEN[4]           # broken leaf edges
            if t < 0.08:
                c = CORD[0] if n < 0 else CORD[1]             # dry cut stalk ends
            f.put(x, y, c)
    # leaves sticking out of the head
    for x, y, c in ((19, 11, 1), (20, 10, 0), (21, 10, 1), (24, 18, 3), (25, 17, 3), (25, 13, 2),
                    (26, 13, 3), (17, 12, 1), (22, 20, 4)):
        f.put(x, y, GREEN[c])
    # two turns of bark cord
    for t0 in (0.30, 0.42):
        for i in range(-4, 5):
            px = ax + ux * length * t0 - uy * i * 0.9
            py = ay + uy * length * t0 + ux * i * 0.9
            if (int(round(px)), int(round(py))) in f.px:
                f.put(round(px), round(py), CORD[0] if i < -1 else (CORD[1] if i < 2 else CORD[2]))
    if lit:
        # the head is charred and glows; damp leaves give thick smoke
        for x, y in ((22, 13), (23, 13), (24, 14), (23, 15), (24, 16), (22, 12), (25, 15), (21, 13),
                     (24, 13), (23, 16)):
            if (x, y) in f.px:
                f.put(x, y, CHAR[grain(x, y, 19) % 2])
        glow = ((23, 14), (24, 15), (22, 14))
        for i, (x, y) in enumerate(glow):
            f.put(x, y, EMBER[(i + k) % 3])
        # two wisps; each puff climbs so frame 3 runs back into frame 0
        for wx, phase, top in ((23, 0, 10), (25, 1, 8)):
            for i in range(top):
                y = 12 - i
                step = i + phase - k
                sway = (0, 1, 1, 0, -1, -1)[step % 6]
                x = wx + sway + i // 5
                tone = min(len(SMOKE) - 1, i * len(SMOKE) // top)
                f.put(x, y, SMOKE[tone])
                if step % 3 == 0 and i > 1:
                    f.put(x + 1, y, SMOKE[min(len(SMOKE) - 1, tone + 1)])
                if step % 3 == 1 and i > 4:
                    f.put(x - 1, y, SMOKE[min(len(SMOKE) - 1, tone + 2)])
    return f


# ------------------------------------------------------------- bee swarm --

SWARM_FRAMES = 7
# (rx, ry, phase, turns per loop, centre x, centre y)
SWARM = [(9, 5, 0.0, 1, 16, 9), (11, 7, 2.1, -1, 16, 11), (6, 4, 4.0, 2, 15, 8),
         (10, 8, 5.2, 1, 16, 12), (7, 6, 1.0, -2, 17, 10), (12, 4, 3.3, 1, 16, 7),
         (5, 8, 0.6, -1, 16, 12), (8, 3, 2.8, 2, 16, 5), (11, 9, 4.6, -1, 16, 13),
         (4, 3, 5.8, 3, 16, 8), (9, 7, 1.7, 2, 15, 14), (12, 6, 0.3, -1, 16, 10),
         (7, 9, 3.9, 1, 17, 13), (10, 3, 5.0, -2, 16, 4)]


def bee_swarm(k):
    """Bees circling the head and shoulders of whoever stands on the tile.
    Each one keeps to its own ellipse and comes round in a whole number of
    turns, so the last frame runs into the first."""
    f = Frame()
    for i, (rx, ry, phase, turns, cx, cy) in enumerate(SWARM):
        a = phase + 2 * math.pi * turns * k / SWARM_FRAMES
        x = int(round(cx + rx * math.cos(a)))
        y = int(round(cy + ry * math.sin(a) + math.sin(a * 2 + i)))
        x, y = max(2, min(29, x)), max(2, min(29, y))
        heading = -math.sin(a) * turns
        bee(f, x, y, flip=heading < 0, wing=(i + k) % 3 != 0)
        if i % 4 == 0:                      # a faint trail behind the fast ones
            b = a - 0.5 * (1 if turns > 0 else -1)
            tx = int(round(cx + rx * math.cos(b)))
            ty = int(round(cy + ry * math.sin(b) + math.sin(b * 2 + i)))
            if (tx, ty) not in f.px:
                f.put(tx, ty, BEE_DARK + (110,))
    return f


# ----------------------------------------------------------------- items --

def blob(f, cx, cy, rx, ry, seed, shade, wobble=0.16):
    """An irregular rounded lump."""
    for y in range(SIZE):
        for x in range(SIZE):
            nx, ny = (x - cx) / rx, (y - cy) / ry
            a = math.atan2(ny, nx)
            edge = 1.0 + wobble * math.sin(a * 3 + seed) + wobble * 0.6 * math.sin(a * 5 + seed * 2)
            r = math.hypot(nx, ny) / edge
            if r <= 1.0:
                c = shade(x, y, nx, ny, r)
                if c is not None:
                    f.put(x, y, c)


def brood_comb():
    """A torn slab of comb, face up: rows of pale domed caps over the brood
    with a few open cells showing white grubs."""
    f = Frame()

    def shade(x, y, nx, ny, r):
        light = nx * 0.6 + ny * 0.8
        row = y - 11
        col = x + (1 if (row // 2) % 2 else 0)
        wall = BROOD[3] if light < 0.5 else BROOD[4]
        if r > 0.86:
            return wall if grain(x, y, 23) < 12 else BROOD[4]     # the torn edge
        if nx > 0.38:                      # uncapped honey cells along one side
            if row % 2 == 0 and col % 2 == 0:
                return COMB[4] if grain(x, y, 33) < 11 else HONEY[1]
            return COMB[1] if light < 0.6 else COMB[2]
        if row % 2 == 1 and col % 2 == 1:
            return wall if grain(x, y, 31) < 11 else BROOD[2]
        if row % 2 == 1 or col % 2 == 1:
            return BROOD[2] if light < 0.45 else BROOD[3]
        if light < -0.5:
            return BROOD[0]
        return BROOD[1] if light < 0.5 else BROOD[2]
    blob(f, 15.5, 16.5, 8.2, 5.6, 1.3, shade, wobble=0.1)
    # the slab's thickness along the near edge
    for (x, y) in sorted(f.px):
        if (x, y + 1) not in f.px and y > 16:
            f.put(x, y + 1, COMB[3] if grain(x, y, 29) < 10 else COMB[4])
            if grain(x, 0, 37) < 9:
                f.put(x, y + 2, COMB[4])
    # open cells: a dark cell with a curled grub
    for x, y in ((11, 14), (17, 18), (20, 14), (13, 19)):
        if (x, y) in f.px:
            f.put(x, y, LARVA)
            f.put(x + 1, y, BROOD[4])
            f.put(x, y + 1, BROOD[4])
    return f


def crushed_comb():
    """A wad of comb squeezed in the fist: pale crumpled wax, creased, with
    honey still running out of it."""
    f = Frame()

    def shade(x, y, nx, ny, r):
        light = nx * 0.55 + ny * 0.85
        fold = math.sin(x * 1.1 + y * 0.6) + math.sin(x * 0.5 - y * 1.3 + 2.0)
        if light < -0.55:
            c = WAX[0]
        elif light < -0.05:
            c = WAX[1]
        elif light < 0.5:
            c = WAX[2]
        else:
            c = WAX[3]
        if fold > 1.25:
            c = WAX[3] if light < 0.3 else WAX[4]            # a crease
        elif fold < -1.35 and light < 0.4:
            c = WAX[0]                                       # a raised fold
        if r > 0.9 and light > 0.2:
            c = WAX[4]
        return c
    blob(f, 15.5, 16.5, 8.8, 4.4, 2.4, shade, wobble=0.13)
    # honey squeezed out along the creases, glossy, and a thin pool under it
    for x0, y0, n in ((9, 15, 5), (14, 13, 6), (19, 14, 4)):
        for i in range(n):
            for w in (0, 1):
                x, y = x0 + i + w, y0 + i
                if (x, y) in f.px:
                    f.put(x, y, HONEY[0] if (w == 0 and i == 1) else HONEY[1 + (w and i > 1)])
    low = max(y for _, y in f.px)
    for x in range(9, 23):
        if (x, low) in f.px or (x, low - 1) in f.px:
            f.put(x, low + 1 if (x, low) in f.px else low, HONEY[2] if x % 5 else HONEY[1])
    return f


def beeswax():
    """A round cake of rendered wax as it comes out of the bowl it set in:
    deep golden yellow, flat on top with the ring of the bowl pressed in."""
    f = Frame()
    cx, cy, rx, ry, thick = 15.5, 14.5, 8.4, 4.6, 5
    for dy in range(thick, 0, -1):                 # the side, lit from the left
        def side(x, y, nx, ny, dy=dy):
            if nx < -0.6:
                c = BEESWAX[2]
            elif nx < 0.25:
                c = BEESWAX[3]
            elif nx < 0.75:
                c = BEESWAX[4]
            else:
                c = BEESWAX[5]
            if dy == thick:
                c = BEESWAX[4] if nx < 0.25 else BEESWAX[5]   # the foot
            return c
        f.ellipse(cx, cy + dy, rx, ry, side)

    def top(x, y, nx, ny):
        r = math.hypot(nx, ny)
        light = nx * 0.6 + ny * 0.8
        if r > 0.9:
            return BEESWAX[0] if light < -0.2 else BEESWAX[2]     # the rim
        if 0.5 < r < 0.68:
            return BEESWAX[2] if light < 0.3 else BEESWAX[3]      # the bowl ring
        if light < -0.35:
            return BEESWAX[0] if r < 0.5 else BEESWAX[1]
        return BEESWAX[1]
    f.ellipse(cx, cy, rx, ry, top)
    f.pts(BEESWAX[0], (11, 12), (12, 12), (12, 11))               # the sheen
    f.pts(BEESWAX[3], (20, 16), (21, 16))                         # a dent
    return f


# --------------------------------------------------------------- candles --

def read_states(path, size=SIZE):
    """{state: [frame images]} of a sheet (first of each name)."""
    im = Image.open(path)
    text = im.info['Description']
    im = im.convert('RGBA')
    cols = im.width // size
    out, at = {}, 0
    for block in re.split(r'(?m)^(?=state = )', text.split('# END DMI')[0])[1:]:
        name = re.match(r'state = "([^"]*)"', block).group(1)
        count = (int(re.search(r'\tdirs = (\d+)', block).group(1))
                 * int(re.search(r'\tframes = (\d+)', block).group(1)))
        frames = []
        for i in range(at, at + count):
            x, y = (i % cols) * size, (i // cols) * size
            frames.append(im.crop((x, y, x + size, y + size)))
        at += count
        out.setdefault(name, frames)
    return out


def wax_colour(red):
    """The beeswax tone for a red candle pixel of this brightness (89-224)."""
    t = max(0.0, min(1.0, (red - 89) / 135.0)) * (len(BEESWAX) - 1)
    ramp = BEESWAX[::-1]
    i = min(len(ramp) - 2, int(t))
    a, b = ramp[i], ramp[i + 1]
    return tuple(int(round(a[j] + (b[j] - a[j]) * (t - i))) for j in range(3))


def beeswax_candle(src):
    """A frame of the red candle with its wax recoloured; wick and flame are
    left exactly as they are."""
    im = src.copy()
    wax = [(x, y) for y in range(SIZE) for x in range(SIZE)
           if (lambda p: p[3] and p[0] > p[1] + 60 and p[2] < 60)(src.getpixel((x, y)))]
    for x, y in wax:
        im.putpixel((x, y), wax_colour(src.getpixel((x, y))[0]) + (255,))
    if wax:
        top = min(y for _, y in wax)
        row = sorted(x for x, y in wax if y == top)
        if len(row) == 3:                  # dipped: a rounded shoulder
            for x in (row[0], row[2]):
                im.putpixel((x, top), im.getpixel((x, top))[:3] + (120,))
    return im


def candle_states():
    src = read_states(CANDLES)
    out = []
    for n in (1, 2, 3):
        out.append(('candle%d_beeswax' % n, [beeswax_candle(src['candle%d' % n][0])], 0))
        lit = src['candle%d_lit' % n]
        assert len(lit) == 2
        out.append(('candle%d_lit_beeswax' % n, [beeswax_candle(fr) for fr in lit], 1))
    out.append(('candle4_beeswax', [beeswax_candle(src['candle4'][0])], 0))
    return out


# ----------------------------------------------------------------- sheet --

def states():
    """[(state, [frame images], delay)] in sheet order."""
    drawn = [
        ('nest', [nest(k) for k in range(4)], 2),
        ('nest_low', [nest_low(k) for k in range(4)], 2),
        ('nest_empty', [nest_empty()], 0),
        ('smoke_bundle', [smoke_bundle()], 0),
        ('smoke_bundle_lit', [smoke_bundle(True, k) for k in range(3)], 2),
        ('bee_swarm', [bee_swarm(k) for k in range(SWARM_FRAMES)], 1),
        ('brood_comb', [brood_comb()], 0),
        ('crushed_comb', [crushed_comb()], 0),
        ('beeswax', [beeswax()], 0),
    ]
    return [(n, [fr.image() for fr in frs], d) for n, frs, d in drawn] + candle_states()


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
BACK = (24, 24, 24, 255)
NEST_AT = (16, 32)         # where the 32px nest frame goes on the 64px tree


def on_tree(tree, fr):
    tile = Image.new('RGBA', (64, 64), GRASS)
    tile.alpha_composite(tree)
    tile.alpha_composite(fr, NEST_AT)
    return tile


def on_person(person, fr):
    tile = Image.new('RGBA', (SIZE, SIZE), GRASS)
    tile.alpha_composite(person)
    tile.alpha_composite(fr)
    return tile


def person_sprite():
    """A standing person from the game sheet, or a plain silhouette."""
    try:
        return read_states(HUMAN)['human_m_s'][0]
    except (OSError, KeyError, IndexError):
        f = Frame()
        f.ellipse(15.5, 6.5, 3.5, 4, lambda *a: (150, 120, 96))
        for y in range(11, 30):
            for x in range(11, 21):
                f.put(x, y, (120, 96, 78))
        return f.image()


def preview(path, scale=4):
    sheet = states()
    tree = read_states(TREES, 64)['tree_1'][0]
    person = person_sprite()
    pad, label = 6, 12
    cell = SIZE * scale + pad
    widest = max(len(frs) for _, frs, _ in sheet)
    rows = []          # (label, [tiles at 1x])
    for name, frs, delay in sheet:
        tiles = []
        for fr in frs:
            tile = Image.new('RGBA', (SIZE, SIZE), GRASS)
            tile.alpha_composite(fr)
            tiles.append(tile)
        rows.append(('%s  %d frame%s%s' % (name, len(frs), 's' if len(frs) > 1 else '',
                                           ', delay %d' % delay if delay else ''), tiles))
    by_name = dict((n, frs) for n, frs, _ in sheet)
    trees = [on_tree(tree, by_name[n][k]) for n, k in
             (('nest', 0), ('nest', 2), ('nest_low', 0), ('nest_empty', 0))]
    swarm = [on_person(person, fr) for fr in by_name['bee_swarm']]
    left = pad + widest * cell
    tree_w = 64 * scale + pad
    width = left + 2 * tree_w + pad
    height = max(pad + len(rows) * (cell + label),
                 2 * (tree_w + label) + (cell + label) * 2 + 64 * 2 + 3 * label + 80)
    out = Image.new('RGBA', (width, height), BACK)
    draw = ImageDraw.Draw(out)
    y = pad
    for text, tiles in rows:
        draw.text((pad, y), text, fill=(230, 230, 230, 255))
        for i, tile in enumerate(tiles):
            out.paste(tile.resize((SIZE * scale,) * 2, Image.NEAREST), (pad + i * cell, y + label))
        y += cell + label
    # right column: the nests on the tree, the swarm on a person, small strips
    y = pad
    for i, (tile, text) in enumerate(zip(trees, ('nest on tree_1', 'nest, frame 3', 'nest_low',
                                                 'nest_empty'))):
        x = left + (i % 2) * tree_w
        yy = y + (i // 2) * (tree_w + label)
        draw.text((x, yy), text, fill=(230, 230, 230, 255))
        out.paste(tile.resize((64 * scale,) * 2, Image.NEAREST), (x, yy + label))
    y += 2 * (tree_w + label)
    draw.text((left, y), 'bee_swarm over a person', fill=(230, 230, 230, 255))
    for i, tile in enumerate(swarm):
        out.paste(tile.resize((SIZE * scale,) * 2, Image.NEAREST),
                  (left + (i % 4) * cell, y + label + (i // 4) * cell))
    y += label + 2 * cell
    draw.text((left, y), '2x and 1x', fill=(230, 230, 230, 255))
    y += label
    x = left
    for tile in trees[::2]:
        out.paste(tile.resize((128, 128), Image.NEAREST), (x, y))
        out.paste(tile, (x, y + 128 + pad))
        x += 128 + pad
    for tile in swarm[:2]:
        out.paste(tile.resize((64, 64), Image.NEAREST), (x, y))
        out.paste(tile, (x, y + 128 + pad))
        x += 64 + pad
    y += 128 + pad + 64 + pad
    x = left
    singles = [tiles[0] for _, tiles in rows]
    per = (width - left) // 66
    for i, tile in enumerate(singles):
        out.paste(tile.resize((64, 64), Image.NEAREST),
                  (left + (i % per) * 66, y + (i // per) * 66))
    y += ((len(singles) + per - 1) // per) * 66 + pad
    for i, tile in enumerate(singles):
        out.paste(tile, (left + (i % 15) * 34, y + (i // 15) * 34))
    out.save(path)


if __name__ == '__main__':
    if '--check' in sys.argv:
        if not check():
            sys.exit('stale sheet: ' + str(SHEET))
        print('wild bee states match')
    else:
        write_dmi()
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
