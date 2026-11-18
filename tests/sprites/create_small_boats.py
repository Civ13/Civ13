"""Hand-placed small boats: the outrigger canoe and the log raft.

Every pixel is placed by this script from a fixed palette (Pillow only); no
external or generated artwork. The wood, bark and outline tones are the ones
create_dugout_canoe.py uses, lit from the upper left, so the outrigger reads as
the same dugout hull with gear lashed to it.

icons/obj/vehicles/outrigger.dmi (96x96, four directions, bow towards dir; the
hull sits on the middle 32x32, so the game draws it with pixel_w and pixel_z of
-32 and the boat still stands on one tile):
  outrigger          the canoe: a long dugout hull, two booms lashed across it
                     and one float lashed to the boom ends on the starboard side
  outrigger_fitted   the same with the booms laid across and the float beside
                     them, nothing lashed yet
  outrigger_motor    the canoe with an outboard engine and its fuel tank aft
  mast_furled        overlay: a short mast with the sail rolled on its spars
  mast_set           overlay: the crab claw sail of plaited mats set
  mast_torn          overlay: the same sail holed and ragged

icons/obj/vehicles/raft.dmi (32x32):
  raft               four directions: round logs under two cross poles, bound
                     with rope
  raft_logs          the logs laid out, not yet lashed
  log_rollers        three short rollers for hauling a boat over land
  sail               the small sail rolled up on its spars

Run with Pillow to reproduce both sheets. `--check` verifies the committed
sheets, `--preview <png>` writes a review sheet with the old sprites beside
the new.
Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_dugout_canoe import OUT, WD, PW, BK, CH, WATER, GRASS, DARK, noise, blunt, adzed  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
BIG = ROOT / 'icons/obj/vehicles/outrigger.dmi'
SMALL = ROOT / 'icons/obj/vehicles/raft.dmi'

SOUTH, NORTH, EAST, WEST = 'south', 'north', 'east', 'west'
DIRS = (SOUTH, NORTH, EAST, WEST)

# plaited fibre cord, light to dark
CORD = [(226, 204, 150), (192, 164, 108), (140, 112, 66)]
# woven pandanus mat, light to dark
MAT = [(232, 214, 160), (212, 190, 132), (184, 158, 102), (150, 124, 76)]
# pale peeled poles (booms, spars, mast)
POLE = [(206, 172, 120), (170, 132, 84), (124, 90, 54)]
# engine iron and a red fuel tank
IRON = [(150, 154, 158), (108, 112, 118), (72, 76, 82), (44, 46, 52)]
TANK = [(190, 72, 56), (150, 50, 40), (104, 34, 30)]
SHADE = (50, 38, 28)


class Frame:
    def __init__(self, size):
        self.size = size
        self.px = {}

    def put(self, x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < self.size and 0 <= y < self.size:
            self.px[(x, y)] = (c[0], c[1], c[2], 255)

    def outline(self, c=OUT):
        edge = set()
        for (x, y) in self.px:
            for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if n not in self.px:
                    edge.add(n)
        for x, y in edge:
            self.put(x, y, c)

    def image(self):
        im = Image.new('RGBA', (self.size, self.size), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c)
        return im


# ------------------------------------------------------------ the outrigger
#
# Boat coordinates: u runs from the stern (negative) to the bow, v from port
# (negative) to starboard, both from the middle of the hull, which is the
# middle of the sheet.

BIG_SIZE = 96
MID = 47.5
HULL_V = 0.0
HULL_LEN = 24.0
HULL_WID = 6.6
FLOAT_V = 23.0
FLOAT_LEN = 17.0
FLOAT_WID = 2.4
BOOMS = (10.0, -12.0)     # u of the fore and aft boom
BOOM_PORT = HULL_V - 9.0  # the booms overhang the port gunwale a little


def to_local(facing, x, y):
    dx, dy = x - MID, y - MID
    if facing == NORTH:
        return -dy, dx
    if facing == SOUTH:
        return dy, -dx
    if facing == EAST:
        return dx, dy
    return -dx, -dy


def to_screen(facing, u, v, lift=0.0):
    if facing == NORTH:
        x, y = MID + v, MID - u
    elif facing == SOUTH:
        x, y = MID - v, MID + u
    elif facing == EAST:
        x, y = MID + u, MID + v
    else:
        x, y = MID - u, MID - v
    return x, y - lift


def hull_top(u, v):
    t = u / HULL_LEN
    if abs(t) >= 1:
        return False
    return abs(v - HULL_V) <= HULL_WID * blunt(t, 2.2 if t > 0 else 3.8)


def hull_hold(u, v):
    t = (u + 0.5) / (HULL_LEN - 4.5)
    if abs(t) >= 1:
        return False
    return abs(v - HULL_V) <= (HULL_WID - 1.7) * blunt(t, 2.2 if t > 0 else 3.6)


def float_top(u, v, shift=0.0):
    t = (u + 1.0) / FLOAT_LEN
    if abs(t) >= 1:
        return False
    return abs(v - FLOAT_V - shift) <= FLOAT_WID * blunt(t, 1.5)


def boom_at(u, v, reach):
    """Index of the boom covering this point, or None."""
    for i, bu in enumerate(BOOMS):
        if abs(u - bu) <= 1.0 and BOOM_PORT <= v <= reach:
            return i
    return None


def hull_and_float(facing, lashed=True, motor=False):
    """The canoe seen from above and a little from the south."""
    f = Frame(BIG_SIZE)
    flat = facing in (EAST, WEST)
    shift = 0.0 if lashed else 3.0           # an unlashed float lies off the boom ends
    reach = FLOAT_V + 1.0 if lashed else FLOAT_V - 2.5
    grid = [(x, y) for y in range(BIG_SIZE) for x in range(BIG_SIZE)]

    def H(x, y):
        return hull_top(*to_local(facing, x, y))

    def HO(x, y):
        return hull_hold(*to_local(facing, x, y))

    def FL(x, y):
        return float_top(*to_local(facing, x, y), shift=shift)

    # the outsides, seen below each top surface
    for x, y in grid:
        for drop in (3, 2, 1):
            if H(x, y - drop) and not H(x, y):
                i = drop if noise(x // 3 if flat else x, y, 61) < 0.8 else min(3, drop + 1)
                f.put(x, y, BK[min(3, i)])
        if FL(x, y - 1) and not FL(x, y):
            f.put(x, y, BK[3])
    # the float: a peeled, pointed log
    for x, y in grid:
        if FL(x, y):
            u, v = to_local(facing, x, y)
            lit = not FL(x, y - 1) or not FL(x - 1, y)
            c = WD[0] if lit else WD[2] if not FL(x, y + 1) else WD[1]
            if noise(x // 3 if flat else x, y // 1 if flat else y // 3, 71) > 0.86:
                c = WD[2]
            f.put(x, y, c)
    # the hull
    for x, y in grid:
        if not H(x, y):
            continue
        u, v = to_local(facing, x, y)
        if not HO(x, y):
            lit = (y < to_screen(facing, 0, HULL_V)[1]) if flat else (x < to_screen(facing, 0, HULL_V)[0])
            c = WD[2] if lit else BK[1]
            if not H(x, y - 1) or not H(x - 1, y):
                c = WD[1]
            elif not H(x, y + 1):
                c = BK[1]
            elif abs(u) > HULL_LEN - 4.5 and noise(x, y, 62) > 0.7:
                c = BK[0]
            f.put(x, y, c)
            continue
        c = adzed(x, y, 63)
        scar = noise(int(u + 40) // 3, int(v + 40) // 2, 64) + 0.2 * (1 - abs(v - HULL_V) / (HULL_WID - 1.7))
        if scar > 0.94 and noise(x, y, 66) > 0.3:
            c = CH[2] if noise(x, y, 65) > 0.5 else WD[3]
        elif scar > 0.82 and noise(x, y, 66) > 0.5:
            c = WD[2]
        if not HO(x, y - 1):
            c = WD[3]
        elif not HO(x, y - 2):
            c = WD[2]
        elif not HO(x - 1, y):
            c = PW[2]
        elif not HO(x, y + 1):
            c = PW[0]
        f.put(x, y, c)
    # two thwarts to sit on
    for x, y in grid:
        u, v = to_local(facing, x, y)
        if HO(x, y) and (abs(u - 3.0) <= 1.0 or abs(u + 16.0) <= 1.0):
            f.put(x, y, WD[1] if (u > 0) == (abs(u) % 2 < 1) else WD[2])
    # shadow the booms throw on whatever is under them, then the booms
    for x, y in grid:
        u, v = to_local(facing, x, y)
        if (x, y) in f.px and boom_at(*to_local(facing, x, y - 2), reach) is not None:
            f.put(x, y, SHADE)
    for x, y in grid:
        u, v = to_local(facing, x, y)
        if boom_at(*to_local(facing, x, y - 1), reach) is not None and boom_at(u, v, reach) is None:
            if not H(x, y) and not FL(x, y):
                f.put(x, y, POLE[2])
    for x, y in grid:
        u, v = to_local(facing, x, y)
        i = boom_at(u, v, reach)
        if i is None:
            continue
        along = v if not flat else v
        c = POLE[0] if boom_at(*to_local(facing, x, y - 1), reach) is None or \
            boom_at(*to_local(facing, x - 1, y), reach) is None else POLE[1]
        if noise(int(along) // 4, i, 73) > 0.8:
            c = POLE[1]
        f.put(x, y, c)
    f.outline()
    # lashings: turns of cord round each boom at both gunwales and at the float
    if lashed:
        for bu in BOOMS:
            for bv in (HULL_V - HULL_WID + 0.6, HULL_V + HULL_WID - 0.6, FLOAT_V):
                cx, cy = to_screen(facing, bu, bv)
                cx, cy = int(round(cx - 0.5)), int(round(cy - 0.5))
                for ox, oy, c in ((-1, -1, CORD[1]), (0, -1, CORD[0]), (1, -1, CORD[1]),
                                  (-1, 0, CORD[0]), (0, 0, CORD[2]), (1, 0, CORD[0]),
                                  (-1, 1, CORD[1]), (0, 1, CORD[0]), (1, 1, CORD[2]),
                                  (2, 0, CORD[2]), (0, 2, CORD[2]), (-2, 0, CORD[1]), (0, -2, CORD[1])):
                    f.put(cx + ox, cy + oy, c)
    else:
        # a coil of cord waiting on the forward thwart
        cx, cy = to_screen(facing, 3.0, HULL_V)
        for ox, oy, c in ((0, 0, CORD[2]), (-1, 0, CORD[0]), (1, 0, CORD[1]), (0, -1, CORD[0]), (0, 1, CORD[1])):
            f.put(cx + ox, cy + oy, c)
    if motor:
        outboard(f, facing)
    return f


def outboard(f, facing):
    """A small engine clamped over the stern, its tiller arm reaching forward
    and a fuel tank on the bottom boards just ahead of it."""
    def block(u0, u1, v0, v1, shade):
        cells = set()
        for x in range(BIG_SIZE):
            for y in range(BIG_SIZE):
                u, v = to_local(facing, x, y)
                if u0 <= u <= u1 and v0 <= v - HULL_V <= v1:
                    cells.add((x, y))
        for x, y in sorted(cells):
            top = (x, y - 1) not in cells or (x - 1, y) not in cells
            low = (x, y + 1) not in cells or (x + 1, y) not in cells
            f.put(x, y, shade[0] if top else shade[2] if low else shade[1])
        for x, y in sorted(cells):
            for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if n not in cells:
                    f.put(n[0], n[1], IRON[3] if shade is IRON else OUT)
    block(-19.5, -14.5, -2.5, 2.5, TANK)            # tank
    block(-27.5, -22.0, -3.5, 3.5, IRON)            # powerhead over the stern
    for k in range(7):                               # tiller arm
        x, y = to_screen(facing, -22.0 + k, HULL_V + 3.0)
        f.put(x, y, IRON[3] if k < 6 else WD[0])
    x, y = to_screen(facing, -25.0, HULL_V)          # filler cap
    f.put(x, y, IRON[0])
    x, y = to_screen(facing, -17.0, HULL_V)
    f.put(x, y, IRON[1])


# ------------------------------------------------------------------ the sail
#
# Overlays drawn above the crew. Points are (u, v, height); height lifts a
# point straight up the screen.

MAST_FOOT = (6.0, HULL_V)
MAST_H = 15.0
TACK = (21.0, HULL_V, 2.0)
PEAK = (-15.0, HULL_V - 1.0, 19.0)
CLEW = (-17.0, HULL_V + 15.0, 5.0)


def line(f, a, b, colours, width=1):
    (x0, y0), (x1, y1) = a, b
    n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
    for k in range(n + 1):
        t = k / n
        x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        f.put(round(x), round(y), colours[0])
        if width > 1:
            f.put(round(x) + 1, round(y), colours[1])


def mast(f, facing, height=MAST_H):
    foot = to_screen(facing, *MAST_FOOT)
    head = to_screen(facing, MAST_FOOT[0], MAST_FOOT[1], height)
    line(f, foot, head, (POLE[0], POLE[2]), 2)
    # the lashing at the mast step
    f.put(round(foot[0]) - 1, round(foot[1]), CORD[1])
    f.put(round(foot[0]) + 2, round(foot[1]), CORD[2])
    return head


def sail(facing, state):
    f = Frame(BIG_SIZE)
    if state == 'furled':
        # both spars and the rolled mat lowered along the hull, lashed to the mast
        a = to_screen(facing, 20.0, HULL_V + 1.0, 4.0)
        b = to_screen(facing, -18.0, HULL_V + 2.0, 6.0)
        cells = set()
        n = 120
        for k in range(n + 1):
            t = k / n
            x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
            for o in (-1, 0, 1):
                cells.add((round(x) + (o if facing in (NORTH, SOUTH) else 0),
                           round(y) + (o if facing in (EAST, WEST) else 0)))
        for x, y in sorted(cells):
            first = (x - 1, y) not in cells or (x, y - 1) not in cells
            last = (x + 1, y) not in cells or (x, y + 1) not in cells
            f.put(x, y, POLE[0] if first and not last else MAT[3] if last and not first else MAT[1])
        ties = 0
        for x, y in sorted(cells):
            along = y if facing in (NORTH, SOUTH) else x
            if along % 7 == 3:
                f.put(x, y, CORD[2] if ties % 2 else CORD[0])
                ties += 1
        f.outline()
        mast(f, facing, 9.0)
        return f
    # The clew swings out to starboard, except heading west, where starboard
    # is up the screen and the sail would close on its own peak.
    clew_at = (CLEW[0], HULL_V - 15.0, CLEW[2]) if facing == WEST else \
        (CLEW[0], HULL_V + 19.0, CLEW[2]) if facing == NORTH else CLEW
    tack, peak, clew = (to_screen(facing, *p) for p in (TACK, PEAK, clew_at))
    cut = 0.4 if facing in (NORTH, WEST) else 0.62

    def side(p, a, b):
        return (p[0] - a[0]) * (b[1] - a[1]) - (p[1] - a[1]) * (b[0] - a[0])

    cells = set()
    for y in range(BIG_SIZE):
        for x in range(BIG_SIZE):
            p = (x + 0.0, y + 0.0)
            d = (side(p, tack, peak), side(p, peak, clew), side(p, clew, tack))
            if all(v >= -0.5 for v in d) or all(v <= 0.5 for v in d):
                # the leech between the spar ends is cut in a deep curve
                mx, my = (peak[0] + clew[0]) / 2, (peak[1] + clew[1]) / 2
                span = math.hypot(peak[0] - clew[0], peak[1] - clew[1]) / 2
                if math.hypot(x - mx, y - my) < span * cut:
                    continue
                cells.add((x, y))
    for x, y in sorted(cells):
        # mats sewn in strips running from the tack out to the leech
        ang = math.atan2(y - tack[1], x - tack[0])
        strip = int(ang * 9.0 + 40)
        dist = math.hypot(x - tack[0], y - tack[1])
        c = MAT[1] if strip % 2 else MAT[0]
        if int(dist) % 5 == 0:
            c = MAT[2]
        if (x, y + 1) not in cells or (x + 1, y) not in cells:
            c = MAT[3]
        if state == 'torn':
            hole = noise(x // 4, y // 5, 91)
            if hole > 0.74:
                continue
            if hole > 0.66:
                c = MAT[3]
        f.put(x, y, c)
    f.outline()
    head = mast(f, facing)
    line(f, tack, peak, (POLE[0], POLE[2]), 2)
    line(f, tack, clew, (POLE[1], POLE[2]), 2)
    # halyard from the masthead to the upper spar, and the tack lashing
    mid = (tack[0] + (peak[0] - tack[0]) * 0.55, tack[1] + (peak[1] - tack[1]) * 0.55)
    line(f, head, mid, (CORD[2],))
    for o in ((0, 0), (1, 0), (0, 1)):
        f.put(round(tack[0]) + o[0], round(tack[1]) + o[1], CORD[0])
    return f


# ------------------------------------------------------------------ the raft

def raft(facing, lashed=True):
    """Seven round logs of uneven length. Lashed, two cross poles lie over
    them with rope turns at every log; unlashed they are just laid side by
    side with gaps."""
    f = Frame(32)
    along_x = facing in (EAST, WEST)           # logs run along the direction of travel
    count = 7
    for i in range(count):
        centre = 4.5 + i * 3.8 if lashed else 3.5 + i * 4.0 + (0.6 if i % 2 else -0.4)
        lo = 2 + (int(noise(i, 1, 81) * 3) if lashed else int(noise(i, 2, 82) * 5))
        hi = 29 - (int(noise(i, 3, 83) * 3) if lashed else int(noise(i, 4, 84) * 5))
        for a in range(lo, hi + 1):
            for o in (-1, 0, 1):
                b = int(round(centre)) + o
                x, y = (a, b) if along_x else (b, a)
                if along_x:
                    c = BK[0] if o < 0 else BK[1] if o == 0 else BK[2]
                else:
                    c = BK[0] if o < 0 else BK[1] if o == 0 else BK[2]
                if noise(a // 4, i, 85) > 0.78 and o == 0:
                    c = BK[2]
                if a in (lo, hi):
                    c = WD[0] if o == 0 else WD[1]   # the cut end grain
                f.put(x, y, c)
        if along_x:
            for a in range(lo, hi + 1):            # the round of the log showing on its south side
                if (a, int(round(centre)) + 2) not in f.px and i == count - 1:
                    f.put(a, int(round(centre)) + 2, BK[3])
    f.outline()
    if lashed:
        for p in (8, 23):
            for b in range(1, 31):
                x, y = (p, b) if along_x else (b, p)
                x2, y2 = (p + 1, b) if along_x else (b, p + 1)
                f.put(x, y, POLE[0])
                f.put(x2, y2, POLE[1])
            for i in range(count):
                centre = int(round(4.5 + i * 3.8))
                for d, c in ((-1, CORD[0]), (0, CORD[2]), (2, CORD[1])):
                    x, y = (p + d, centre) if along_x else (centre, p + d)
                    f.put(x, y, c)
                x, y = (p, centre - 1) if along_x else (centre - 1, p)
                f.put(x, y, CORD[1])
            for b in (0, 31):
                x, y = (p, b) if along_x else (b, p)
                x2, y2 = (p + 1, b) if along_x else (b, p + 1)
                f.put(x, y, OUT)
                f.put(x2, y2, OUT)
            for b in range(1, 31):                  # outline along the poles where they stand clear
                for d in (-1, 2):
                    x, y = (p + d, b) if along_x else (b, p + d)
                    if (x, y) not in f.px:
                        f.put(x, y, OUT)
    return f


def rollers():
    f = Frame(32)
    for i, cy in enumerate((8, 16, 24)):
        lo, hi = 4 + i % 2, 27 - (i + 1) % 2
        for x in range(lo, hi + 1):
            for o, c in ((-1, WD[0]), (0, WD[1]), (1, WD[2]), (2, WD[3])):
                if x in (lo, hi) and o in (-1, 2):
                    continue
                f.put(x, cy + o, PW[0] if x == hi and o in (0, 1) else c)
            if noise(x // 3, i, 88) > 0.8:
                f.put(x, cy, WD[2])
    f.outline()
    return f


def sail_item():
    """The mat sail rolled on its two spars and tied, lying on a slant."""
    f = Frame(32)
    for k in range(0, 49):
        t = k / 48
        x, y = 4 + 23 * t, 26 - 20 * t
        for o, c in ((-2, POLE[0]), (-1, MAT[0]), (0, MAT[1]), (1, MAT[2]), (2, MAT[3])):
            f.put(round(x + o * 0.66), round(y + o * 0.75), c)
    f.outline()
    for t in (0.2, 0.5, 0.8):
        x, y = 4 + 23 * t, 26 - 20 * t
        for o in (-2, -1, 0, 1, 2):
            f.put(round(x + o * 0.66), round(y + o * 0.75), CORD[2] if o in (-2, 2) else CORD[0])
    return f


# ---------------------------------------------------------------- the sheets

def big_states():
    return {
        'outrigger': [hull_and_float(d) for d in DIRS],
        'outrigger_fitted': [hull_and_float(d, lashed=False) for d in DIRS],
        'outrigger_motor': [hull_and_float(d, motor=True) for d in DIRS],
        'mast_furled': [sail(d, 'furled') for d in DIRS],
        'mast_set': [sail(d, 'set') for d in DIRS],
        'mast_torn': [sail(d, 'torn') for d in DIRS],
    }


def small_states():
    return {
        'raft': [raft(d) for d in DIRS],
        'raft_logs': [raft(NORTH, lashed=False)],
        'log_rollers': [rollers()],
        'sail': [sail_item()],
    }


def sheet_bytes(states, size, columns=4):
    frames = [fr for group in states.values() for fr in group]
    rows = -(-len(frames) // columns)
    sheet = Image.new('RGBA', (size * columns, size * rows), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(fr.image(), (i % columns * size, i // columns * size))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = %d\n\theight = %d\n' % (size, size)
    for name, group in states.items():
        text += 'state = "%s"\n\tdirs = %d\n\tframes = 1\n' % (name, len(group))
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    return sheet, meta


def write(path, states, size):
    sheet, meta = sheet_bytes(states, size)
    sheet.save(path, format='PNG', pnginfo=meta)


def check(path, states, size):
    sheet, _ = sheet_bytes(states, size)
    have = Image.open(path).convert('RGBA')
    if have.size != sheet.size or have.tobytes() != sheet.tobytes():
        raise SystemExit('%s does not match this script: rerun it' % path)


def ground(colour, seed, size):
    tile = Image.new('RGBA', (size, size), colour + (255,))
    for y in range(size):
        for x in range(size):
            n = noise(x, y, seed)
            if n > 0.86 or n < 0.1:
                d = 9 if n > 0.5 else -9
                tile.putpixel((x, y), tuple(max(0, min(255, v + d)) for v in colour) + (255,))
    return tile


def old_frames(path, state, size):
    """Frames of a state in an existing sheet, for the before column."""
    im = Image.open(path)
    text = im.text.get('Description', '')
    im = im.convert('RGBA')
    index, found = 0, None
    name, dirs, frames = None, 1, 1
    entries = []
    for ln in text.splitlines():
        ln = ln.strip()
        if ln.startswith('state'):
            if name is not None:
                entries.append((name, dirs, frames))
            name, dirs, frames = ln.split('=', 1)[1].strip().strip('"'), 1, 1
        elif ln.startswith('dirs'):
            dirs = int(ln.split('=')[1])
        elif ln.startswith('frames'):
            frames = int(ln.split('=')[1])
    entries.append((name, dirs, frames))
    cols = im.width // size
    for name, dirs, frames in entries:
        if name == state:
            found = [im.crop(((index + i) % cols * size, (index + i) // cols * size,
                              (index + i) % cols * size + size, (index + i) // cols * size + size))
                     for i in range(dirs)]
            break
        index += dirs * frames
    return found


def write_preview(path, scale=3):
    big, small = big_states(), small_states()
    old_big = ROOT / 'icons/obj/vehicles/vehicleparts64x64.dmi'
    old_small = ROOT / 'icons/obj/vehicles/vehicleparts.dmi'
    water, grass = ground(WATER, 33, BIG_SIZE), ground(GRASS, 31, BIG_SIZE)

    def over(base, *layers):
        tile = base.copy()
        for layer in layers:
            tile.alpha_composite(layer, ((BIG_SIZE - layer.width) // 2,) * 2)
        return tile.resize((tile.width * scale, tile.height * scale), Image.NEAREST)

    rows = []
    old_sail = old_frames(old_big, 'outrigger_frame1', 64)
    old_s1, old_s2 = old_frames(old_big, 'sail1', 64), old_frames(old_big, 'sail2', 64)
    old_motor = old_frames(old_big, 'outrigger_frame3', 64)
    rows.append(('before: sailing outrigger, sail set', [over(water, old_sail[i], old_s1[i], old_s2[i]) for i in range(4)]))
    rows.append(('before: motor outrigger', [over(water, old_motor[i]) for i in range(4)]))
    img = {k: [fr.image() for fr in v] for k, v in big.items()}
    rows.append(('outrigger canoe (paddled)', [over(water, img['outrigger'][i]) for i in range(4)]))
    rows.append(('outrigger canoe, beached', [over(grass, img['outrigger'][i]) for i in range(4)]))
    rows.append(('being built: booms and float fitted, not lashed', [over(grass, img['outrigger_fitted'][i]) for i in range(4)]))
    rows.append(('sail furled', [over(water, img['outrigger'][i], img['mast_furled'][i]) for i in range(4)]))
    rows.append(('sail set', [over(water, img['outrigger'][i], img['mast_set'][i]) for i in range(4)]))
    rows.append(('sail torn', [over(water, img['outrigger'][i], img['mast_torn'][i]) for i in range(4)]))
    rows.append(('outboard engine', [over(water, img['outrigger_motor'][i]) for i in range(4)]))
    w32, g32 = ground(WATER, 33, 32), ground(GRASS, 31, 32)
    s2 = scale * 3
    old_raft = old_frames(old_small, 'raft', 32)
    simg = {k: [fr.image() for fr in v] for k, v in small.items()}

    def over32(base, layer):
        tile = base.copy()
        tile.alpha_composite(layer)
        return tile.resize((32 * s2, 32 * s2), Image.NEAREST)

    rows.append(('before: raft', [over32(w32, old_raft[i]) for i in range(4)]))
    rows.append(('raft', [over32(w32, simg['raft'][i]) for i in range(4)]))
    rows.append(('raft logs laid out, log rollers, rolled sail; old sail item',
                 [over32(g32, simg['raft_logs'][0]), over32(g32, simg['log_rollers'][0]),
                  over32(g32, simg['sail'][0]), over32(g32, old_frames(old_small, 'sailing0', 32)[0])]))
    cell, pad, label = BIG_SIZE * scale, 8, 16
    sheet = Image.new('RGBA', (pad + 4 * (cell + pad), pad + len(rows) * (cell + label + pad)), DARK + (255,))
    draw = ImageDraw.Draw(sheet)
    for r, (name, tiles) in enumerate(rows):
        oy = pad + r * (cell + label + pad)
        draw.text((pad, oy), name + '   (south, north, east, west)' if r < 11 else name, fill=(232, 228, 214))
        for i, tile in enumerate(tiles):
            sheet.alpha_composite(tile, (pad + i * (cell + pad), oy + label))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.convert('RGB').save(path)


def main():
    args = sys.argv[1:]
    if '--check' in args:
        check(BIG, big_states(), BIG_SIZE)
        check(SMALL, small_states(), 32)
        print('small boat sheets match')
        return
    write(BIG, big_states(), BIG_SIZE)
    write(SMALL, small_states(), 32)
    if '--preview' in args:
        write_preview(args[args.index('--preview') + 1])


if __name__ == '__main__':
    main()
