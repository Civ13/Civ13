"""Hand-placed sprites for the Industrial gold mill in icons/obj/milling.dmi:
the trommel (a long inclined drum screen of perforated sheet iron on a timber
frame, with a feed chute at its high end and a drive pulley on that end:
standing and a three-frame turning loop), the amalgamating drum (a squat
Washoe-style cast iron pan on legs, its vertical shaft driven through a bevel
gear from a belt pulley: standing and a three-frame working loop), the mercury
separator (a wide shallow iron settler with a stirring arm, a pool of
quicksilver on its floor and an overflow spout), the shaking table (a tilted
rhomboid Wilfley deck with riffles, a water box along its top edge and a head
motion box with a pulley: standing and a two-frame shaking loop), the bundle
of two silvered copper amalgamation plates, and the two apron plate overlays:
one for the foot of the `water_stamp_mill` state in icons/obj/lode.dmi and one
for the foot of the 32x48 `mining_drill` states in
icons/obj/machines/mining_drill.dmi (an overlay sits on the lower 32 rows).
Every pixel is placed by this script from a fixed palette (Pillow only); no
external or generated artwork. The timber is that of create_clay_lime_fire.py,
the iron and quicksilver are those of create_mercury.py, the grit and gold
are those of create_lode.py and the dark slime is that of create_amalgam.py.

Run with Pillow to write the sheet. `--check` verifies the committed sheet
and that neither overlay leaves the strip it is allowed at the foot of its
machine, `--preview <png>` writes a labelled 4x review sheet on grass and on
dirt, with each overlay shown on its machine, `--gif <path>` writes the three
working loops side by side.
Released under Civ13 AGPL-3.0.
"""
import math
import re
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_clay_lime_fire import TIMBER, STONE, grain  # noqa: E402
from create_tatara import Sprite, GRASS, DIRT, ground  # noqa: E402
from create_mercury import IRON, IRON_EDGE, QUICK  # noqa: E402
from create_lode import GRIT, GOLD  # noqa: E402
from create_amalgam import DARK_SLIME  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/milling.dmi'
LODE = ROOT / 'icons/obj/lode.dmi'
DRILL = ROOT / 'icons/obj/machines/mining_drill.dmi'

SIZE = 32
RUN_DELAY = 2          # deciseconds per frame, as water_stamp_mill_on
TROMMEL_FRAMES = 3
DRUM_FRAMES = 3
TABLE_FRAMES = 2

EDGE = (30, 20, 14)                      # the timber outline
PERF = (26, 27, 34)                      # a punched hole in the screen
# copper: glint, lit, mid, shade, deep
COPPER = [(240, 172, 112), (206, 122, 70), (164, 88, 50), (118, 60, 36), (82, 42, 28)]
COPPER_EDGE = (48, 24, 16)
# a quicksilvered plate face: glint, bright, lit, mid, shade
SILVERED = [(250, 252, 255), (218, 226, 236), (184, 194, 208), (146, 156, 174), (108, 116, 136)]
# clean wash water: sheen, light, mid, deep
WATER = [(214, 232, 242), (138, 176, 204), (90, 128, 162), (60, 90, 124)]
# the table's deck covering (oiled linoleum): lit, mid, shade
DECK = [(160, 112, 78), (136, 92, 64), (108, 72, 52)]
# black sand, the heavy band on the table: lit, mid, deep
HEAVY = [(84, 84, 92), (58, 58, 66), (38, 38, 46)]
TWINE = [(196, 170, 120), (150, 124, 84), (104, 84, 56)]

# The strip each apron overlay must stay inside: (first row, first and last
# column). The water mill's is between its posts and below its stamp shoes;
# the powered mill's is the bottom lip of its base ring.
WATER_STRIP = (27, 6, 19)
ELECTRIC_STRIP = (26, 8, 23)


def trim(f):
    """Outline a machine: dark brown round its timber, near black round iron."""
    wood = set(TIMBER)
    before = set(f.px)
    f.outline(IRON_EDGE)
    for (x, y) in set(f.px) - before:
        near = [f.px.get(p) for p in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))
                if p in before]
        if near and all(c in wood for c in near):
            f.put(x, y, EDGE)


def beam(f, x0, x1, y, seed, thick=2):
    """A horizontal timber: lit top, grain, dark underside."""
    for x in range(x0, x1 + 1):
        f.put(x, y, TIMBER[0] if grain(x // 4, y, seed) else TIMBER[1])
        for k in range(1, thick - 1):
            f.put(x, y + k, TIMBER[1] if grain(x // 5, y + k, seed + 1) else TIMBER[2])
        f.put(x, y + thick - 1, TIMBER[3])


def post(f, x, y0, y1, seed):
    """An upright timber three wide."""
    for y in range(y0, y1 + 1):
        f.put(x, y, TIMBER[0] if grain(x, y // 4, seed) else TIMBER[1])
        f.put(x + 1, y, TIMBER[2])
        f.put(x + 2, y, TIMBER[3])


def pulley_side(f, cx, cy, ry, turn):
    """A cast iron belt pulley seen nearly edge on: a tall narrow disc with a
    crowned rim, its spokes showing as marks that step round with `turn`."""
    for y in range(int(cy - ry), int(cy + ry) + 1):
        ny = (y - cy) / ry
        half = 1.6 * math.sqrt(max(0.0, 1.0 - ny * ny))
        for x in range(int(math.ceil(cx - half)), int(cx + half) + 1):
            c = IRON[2]
            if x < cx - 0.6:
                c = IRON[0] if abs(ny) < 0.75 else IRON[1]    # the lit belt face
            elif x > cx + 0.6:
                c = IRON[3]
            if abs(ny) > 0.86:
                c = IRON[3] if ny > 0 else IRON[1]
            f.put(x, y, c)
    for k in range(3):                                # the spokes, stepping round
        yy = int(round(cy + (ry - 1.4) * math.sin((k * 2 + turn * 0.67) * math.pi / 3.0)))
        f.put(int(cx + 0.5), yy, IRON[4])
    f.put(int(cx + 0.5), int(round(cy)), IRON[0])     # the shaft end


# -------------------------------------------------------------- trommel --

TX0, TX1 = 7, 25                   # the drum, high end to low end
TR = 4                             # its radius
DRUM_TONE = (1, 0, 1, 2, 2, 3, 3, 4, 4)   # iron tone down the drum, top to foot
HOOPS = (7, 8, 16, 24, 25)         # columns of the iron tyres round it
# what falls through the screen in each frame: (x, y, kind)
DRIBBLE = (
    ((11, 20, 0), (14, 22, 1), (17, 21, 0), (20, 24, 1), (12, 23, 1), (18, 24, 0), (15, 20, 0)),
    ((11, 22, 0), (14, 20, 1), (17, 23, 0), (20, 22, 0), (13, 21, 1), (19, 23, 1), (16, 22, 0)),
    ((12, 20, 1), (14, 24, 0), (17, 20, 1), (21, 23, 0), (11, 24, 0), (19, 21, 0), (15, 23, 1)),
)
# the oversize stones leaving the low end in each frame
TUMBLE = (((29, 16), (30, 21)), ((29, 18), (30, 24)), ((28, 15), (30, 20), (29, 23)))


def axis(x):
    """Row of the drum's centre line at column x: it falls to the right."""
    return int(round(9.5 + (x - TX0) * 0.25))


def trommel(step=None):
    """Seen three quarters from the front: the drum slopes down to the
    right on a timber frame; the chute feeds its high end, where the drive
    pulley sits on the shaft, and the stones roll out of the open low end."""
    f = Sprite()
    turn = 0 if step is None else step
    # the far side rail and far posts, seen under the drum
    for x in range(TX0 - 1, TX1 + 3):
        f.put(x, axis(x) + TR + 1, TIMBER[0] if grain(x // 4, 3, 411) else TIMBER[1])
        f.put(x, axis(x) + TR + 2, TIMBER[3])
    post(f, 8, axis(8) + TR + 3, 27, 413)
    post(f, 23, axis(23) + TR + 3, 27, 415)
    # the box under the screen that catches the fines
    for x in range(11, 22):
        f.put(x, 25, TIMBER[0] if x in (11, 21) else GRIT[1 + grain(x, 25, 417) % 3])
        f.put(x, 26, TIMBER[1] if grain(x // 4, 2, 419) else TIMBER[2])
        f.put(x, 27, TIMBER[2])
    f.pts(GRIT[0], (14, 25), (18, 25))
    # the sill
    beam(f, 5, 27, 28, 421, thick=2)
    # the drum
    for x in range(TX0, TX1 + 1):
        cy = axis(x)
        for r in range(-TR, TR + 1):
            t = DRUM_TONE[r + TR]
            if x in HOOPS:                            # the tyres: solid, and proud
                c = IRON[max(0, t - 1)] if r < 3 else IRON[3]
            else:
                c = IRON[t]
                phase = (x + turn + (1 if r % 2 else 0) * 2) % 3 if r % 2 == 0 else None
                if r % 2 == 0 and phase == 0 and abs(r) < TR:
                    c = PERF if r > -3 else IRON[4]   # the punched rows, creeping along
                elif r % 2 and (x + turn + 1) % 3 == 0 and abs(r) < TR:
                    c = PERF if r > -3 else IRON[4]
            f.put(x, cy + r, c)
    for hx in (7, 24):                                # a rivet line on the end tyres
        f.put(hx, axis(hx) - 1, IRON[4])
        f.put(hx, axis(hx) + 2, IRON[4])
    # the open low end: the rim, and the dark inside with a stone or two in it
    cy = axis(TX1 + 1)
    for r in range(-TR, TR + 1):
        f.put(TX1 + 1, cy + r, IRON[1] if r < 1 else IRON[2])
    for r in range(-3, 4):
        f.put(TX1 + 2, cy + r, PERF if abs(r) < 3 else IRON[3])
    for r in range(-2, 3):
        f.put(TX1 + 3, cy + r, IRON[3] if abs(r) < 2 else IRON[4])
    f.put(TX1 + 2, cy + 2, STONE[2])
    # the shaft out of the high end and the drive pulley on it
    f.hline(4, TX0 - 1, axis(TX0), IRON[1])
    f.hline(4, TX0 - 1, axis(TX0) + 1, IRON[3])
    pulley_side(f, 2.5, axis(TX0) + 0.5, 5.5, turn)
    # the near posts carrying the pulley end bearing and the low end
    post(f, 4, axis(TX0) + 2, 27, 423)
    f.hline(4, 6, axis(TX0) + 2, IRON[2])             # the bearing cap
    # the feed chute: a sloping timber trough with gravel in it
    for i in range(6):
        y, x0 = 1 + i, 9 + i
        f.put(x0, y, TIMBER[1])
        for x in range(x0 + 1, x0 + 5):
            g = grain(x, y, 425)
            c = GRIT[2] if g < 4 else (STONE[2] if g < 7 else GRIT[1])
            if step is not None and (x + y + turn) % 4 == 0:
                c = GRIT[0]                           # the gravel on the move
            f.put(x, y, c)
        f.put(x0 + 5, y, TIMBER[3])
    f.hline(9, 14, 0, TIMBER[0])
    f.pts(STONE[1], (11, 1), (13, 3))
    # the reject heap at the low end
    f.pts(STONE[1], (29, 28), (30, 27))
    f.pts(STONE[2], (30, 28), (31, 28), (29, 27))
    f.pts(STONE[3], (30, 29), (29, 29), (31, 29), (28, 29))
    trim(f)
    if step is not None:
        for x, y, kind in DRIBBLE[step]:
            if (x, y) in f.px and f.px[(x, y)] not in (EDGE, IRON_EDGE):
                continue
            f.put(x, y, (WATER[1] + (210,)) if kind == 0 else (GRIT[1] + (235,)))
            if kind == 0:
                f.put(x, y + 1, WATER[2] + (150,))
        f.pts(WATER[0] + (220,), (13 + step, 25), (18 - step, 25))
        for i, (x, y) in enumerate(TUMBLE[step]):     # the stones rolling out
            f.put(x, y, STONE[1] if i % 2 == 0 else STONE[2])
            f.put(x, y + 1, STONE[3])
    return f


# ----------------------------------------------------- amalgamating drum --

DCX, DTOP = 15.5, 15.0             # centre column and row of the open top
DRX, DRY = 10.4, 3.8               # the rim
DDEEP = 8                          # how far the wall comes down


def tub_tone(nx):
    """Cast iron tone round a tub lit from the upper left."""
    if nx < -0.82:
        return 3
    if nx < -0.55:
        return 1
    if nx < -0.25:
        return 0
    if nx < 0.15:
        return 1
    if nx < 0.6:
        return 2
    if nx < 0.86:
        return 3
    return 4


def tub(f, cx, top, rx, ry, deep, bands, seed):
    """An iron tub seen from a little above: the wall, with raised hoops at
    the rows in `bands` and a rivet line under each, then the rim."""
    for y in range(int(top - ry), int(top + ry + deep) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            nx = (x - cx) / rx
            if abs(nx) > 1.0:
                continue
            span = ry * math.sqrt(1.0 - nx * nx)
            if not (top - span <= y <= top + deep + span):
                continue
            if y < top:
                continue                              # the mouth is drawn after
            t = tub_tone(nx)
            row = int(round(y - span - top))          # rows follow the curve of the wall
            if row in bands:
                t = max(0, t - 1)
            elif row - 1 in bands:
                t = min(4, t + 1)
                if x % 3 == 0:
                    t = 4                             # rivets
            elif grain(x, y, seed) == 0:
                t = min(4, t + 1)                     # the rough casting skin
            if y > top + deep + span - 1.2:
                t = 4                                 # the turn of the bottom
            f.put(x, y, IRON[t])


def mouth(f, cx, top, rx, ry, lip, fill):
    """The open top: a lit rim `lip` wide round whatever fill(x, y, nx, ny)
    gives for the inside."""
    for y in range(int(top - ry) - 1, int(top + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            nx, ny = (x - cx) / rx, (y - top) / ry
            if nx * nx + ny * ny > 1.0:
                continue
            ix, iy = (x - cx) / (rx - lip), (y - top) / max(0.6, ry - lip * 0.75)
            if ix * ix + iy * iy <= 1.0:
                f.put(x, y, fill(x, y, ix, iy))
            else:
                f.put(x, y, IRON[0] if nx + ny < -0.5 else (IRON[1] if nx + ny < 0.6 else IRON[2]))


def amalgamator_drum(step=None):
    """Seen from the front and a little above: the pan on three legs, the
    bridge across its mouth, the muller shaft down through it, the crown
    gear on the shaft and the pinion, cross shaft and belt pulley out over
    the right side; the discharge pipe low on the left."""
    f = Sprite()
    turn = 0 if step is None else step
    # the legs
    for lx in (6, 15, 23):
        for y in range(24 if lx != 15 else 27, 31):
            f.put(lx, y, IRON[1] if lx < 15 else IRON[2])
            f.put(lx + 1, y, IRON[3])
            f.put(lx + 2, y, IRON[4])
        f.hline(lx - 1, lx + 3, 30, IRON[3])          # the foot
    tub(f, DCX, DTOP, DRX, DRY, DDEEP, (2, 6), 431)

    def slurry(x, y, ix, iy):
        if iy < -0.6:
            return IRON[4]                            # the far wall inside
        if step is None:
            return DARK_SLIME[3] if (x + 2 * y) % 5 else DARK_SLIME[4]
        swirl = (x + 2 * y + turn * 2) % 6            # the pulp going round
        if swirl == 0:
            return DARK_SLIME[1]
        return DARK_SLIME[4] if swirl in (2, 3) else DARK_SLIME[3]

    mouth(f, DCX, DTOP, DRX, DRY, 1.4, slurry)
    if step is not None:                              # slop against the rim
        f.pts(DARK_SLIME[0], ((8, 15), (22, 16), (12, 17))[step])
        f.pts(QUICK[1], ((19, 16), (12, 15), (17, 17))[step])
    # the discharge pipe, with its flange against the wall
    f.vline(5, 20, 23, IRON[1])
    f.hline(2, 4, 21, IRON[1])
    f.hline(2, 4, 22, IRON[3])
    f.put(2, 21, IRON[0])
    # the bridge: two standards off the rim and the bar across their heads
    for bx in (8, 22):
        for y in range(11, 14):
            f.put(bx, y, IRON[1])
            f.put(bx + 1, y, IRON[3])
    f.hline(8, 26, 9, IRON[1])
    f.hline(8, 26, 10, IRON[3])
    f.pts(IRON[0], (8, 9), (9, 9), (10, 9), (11, 9))
    f.pts(IRON[4], (11, 10), (20, 10))                # bolt heads
    # the muller shaft, down through the bridge into the pulp
    for y in range(3, 17):
        if y in (9, 10):
            continue
        f.put(15, y, IRON[0] if y < 9 else IRON[1])
        f.put(16, y, IRON[3])
    # the crown gear on the shaft: a toothed wheel lying flat
    f.hline(12, 19, 5, IRON[1])
    for x in range(11, 21):
        f.put(x, 6, IRON[0] if (x + turn) % 2 else IRON[4])   # the teeth, stepping round
    f.hline(12, 19, 7, IRON[3])
    f.pts(IRON[0], (15, 4), (16, 4))                  # the nut on the shaft head
    # the pinion standing against it, on the cross shaft
    for y in range(3, 8):
        f.put(21, y, IRON[1] if (y + turn) % 2 else IRON[4])
        f.put(22, y, IRON[2] if (y + turn) % 2 else IRON[4])
    f.hline(23, 26, 5, IRON[1])                       # the cross shaft
    f.hline(23, 26, 6, IRON[3])
    for y in (7, 8):                                  # its bearing pedestal on the bridge
        f.put(24, y, IRON[2])
        f.put(25, y, IRON[3])
    f.pts(IRON[0], (24, 4), (25, 4))
    pulley_side(f, 28.5, 5.5, 4.5, turn)
    trim(f)
    if step is not None:                              # pulp running from the pipe
        for y in range(22, 29):
            if (y + turn) % 3:
                f.put(1, y, DARK_SLIME[2 + (y + turn) % 2] + (230,))
        f.pts(DARK_SLIME[3] + (220,), (0, 29), (1, 29), (2, 29), (1, 30))
        f.put((0, 2, 3)[step], 30, DARK_SLIME[2] + (200,))
        f.put(1, 21, DARK_SLIME[1])
    return f


# ---------------------------------------------------- mercury separator --

SCX, STOP = 15.0, 18.0
SRX, SRY = 13.4, 6.0
SDEEP = 5


def mercury_separator():
    """A settler: lower and wider than the pan, open, with the quicksilver
    lying bright in the middle of its floor and a stirring arm hung from a
    spindle with a flat belt pulley on its head."""
    f = Sprite()
    for lx in (4, 14, 24):                            # stub feet
        for y in range(27, 31):
            f.put(lx, y, IRON[2])
            f.put(lx + 1, y, IRON[3])
            f.put(lx + 2, y, IRON[4])
    tub(f, SCX, STOP, SRX, SRY, SDEEP, (1,), 441)

    def floor(x, y, ix, iy):
        if iy < -0.5:
            return IRON[4] if iy < -0.72 else IRON[3]         # the far wall inside
        mx, my = (x - SCX) / 5.2, (y - (STOP + 1.6)) / 2.1
        if mx * mx + my * my <= 1.0:                          # the quicksilver
            if mx + my * 1.5 < -0.55:
                return QUICK[0]
            return QUICK[1] if mx + my < 0.55 else QUICK[2]
        g = grain(x, y, 443)                                  # thin grey pulp over the floor
        return DARK_SLIME[1] if g == 0 else (DARK_SLIME[3] if g < 4 else DARK_SLIME[2])

    mouth(f, SCX, STOP, SRX, SRY, 1.5, floor)
    f.pts(QUICK[1], (7, 19), (22, 21), (10, 21))              # stray beads
    f.put(23, 18, QUICK[0])
    # the overflow spout, a lip running out of the rim on the right
    f.hline(27, 31, 18, IRON[1])
    f.hline(28, 31, 19, DARK_SLIME[2])
    f.hline(28, 31, 20, IRON[3])
    f.put(31, 19, DARK_SLIME[1])
    # the spindle standing in the middle, the arm across it, the stirrers
    for y in range(6, 19):
        f.put(15, y, IRON[0] if y < 12 else IRON[1])
        f.put(16, y, IRON[3])
    f.hline(6, 25, 12, IRON[1])
    f.hline(6, 25, 13, IRON[3])
    f.pts(IRON[0], (6, 12), (7, 12), (8, 12), (9, 12))
    for sx in (7, 11, 20, 24):                        # the stirrers hanging in the pulp
        for y in range(14, 19 if sx in (7, 24) else 20):
            f.put(sx, y, IRON[2] if sx < 15 else IRON[3])
    f.pts(IRON[4], (7, 18), (24, 18), (11, 19), (20, 19))
    f.pts(IRON[0], (14, 12), (17, 12))                # the boss on the arm
    # the flat belt pulley on the head of the spindle
    f.hline(12, 19, 3, IRON[1])
    f.hline(11, 20, 4, IRON[0])
    f.hline(11, 20, 5, IRON[2])
    f.hline(12, 19, 6, IRON[4])
    f.pts(IRON[3], (20, 4), (20, 5), (19, 5))
    f.pts(IRON[0], (15, 2), (16, 2))
    trim(f)
    return f


# -------------------------------------------------------- shaking table --

DECK_TOP, DECK_FOOT = 11, 21       # rows of the deck
DECK_W = 20


def deck_left(y):
    """First column of the deck in row y: a rhomboid, raked to the right."""
    return 9 + (y - DECK_TOP) // 4


def shaking_table(step=None):
    """Seen from the front and above: the head motion box and its pulley on
    the left, the deck running away to the right with the water box along
    its top edge. The sand fans across the riffles: pale tailings to the
    front, the black heavy band above it and the thread of gold at the top."""
    f = Sprite()
    shift = 0 if step is None else step               # the deck's stroke
    # the under frame: a sill, two trestles and the rocker beam on them
    beam(f, 2, 29, 29, 451, thick=2)
    for lx in (12, 25):
        post(f, lx, 25, 28, 453 + lx)
    beam(f, 9, 29, 24, 455, thick=2)
    f.pts(IRON[2], (13, 25), (26, 25))                # the rocker shoes
    # the block the head motion stands on, then its cast iron box
    for y in range(22, 29):
        for x in range(1, 7):
            c = TIMBER[1] if x < 5 else TIMBER[3]
            if y == 22:
                c = TIMBER[0]
            elif grain(x // 3, y, 457) < 2:
                c = TIMBER[2]
            f.put(x, y, c)
    for y in range(12, 22):
        for x in range(1, 7):
            c = IRON[2] if x < 5 else IRON[3]
            if y == 12:
                c = IRON[1] if x < 5 else IRON[2]
            if y == 21:
                c = IRON[4]
            f.put(x, y, c)
    f.pts(IRON[4], (1, 13), (6, 13), (1, 20), (6, 20))        # bolts
    # the pulley on its face
    for y in range(13, 21):
        for x in range(0, 7):
            d = math.hypot(x - 3.0, y - 16.5)
            if d > 3.3:
                continue
            if d > 2.2:
                c = IRON[0] if (x - 3.0) + (y - 16.5) < 0 else IRON[1]
            elif d > 0.8:
                c = IRON[4] if (int(x > 3) + int(y > 16.5) + shift) % 2 else IRON[3]
            else:
                c = IRON[0]
            f.put(x, y, c)
    # the water box along the top edge of the deck: a trough with holes
    wx = deck_left(DECK_TOP) + 1
    for x in range(wx, wx + DECK_W):
        f.put(x, 8, TIMBER[0] if grain(x // 4, 8, 459) else TIMBER[1])
        f.put(x, 9, WATER[1] if (x + shift) % 4 else WATER[0])
        f.put(x, 10, TIMBER[2] if x % 3 else TIMBER[4])       # the plug holes
    f.put(wx, 9, TIMBER[1])
    f.put(wx + DECK_W - 1, 9, TIMBER[3])
    # the feed box on the corner by the head motion
    f.hline(9, 12, 6, TIMBER[0])
    f.hline(9, 12, 7, GRIT[2])
    f.pts(TIMBER[3], (9, 7), (12, 7))
    # the pitman from the box to the deck
    f.hline(7, 9 + shift, 16, IRON[1])
    f.hline(7, 9 + shift, 17, IRON[4])
    # the deck
    for y in range(DECK_TOP, DECK_FOOT + 1):
        x0 = deck_left(y) + shift
        for i in range(DECK_W):
            x = x0 + i
            v = (y - DECK_TOP) - i * 0.36             # how far down the fan of sand
            riffle = (i + 2 * (y - DECK_TOP)) % 4 == 0 and i < DECK_W - 3 - (y - DECK_TOP) // 3
            if v < -3.2:
                c = DECK[0] if riffle else DECK[1]            # washed clean
            elif v < -2.2:
                c = GOLD[0] if i % 5 else GOLD[1]             # the gold streak
            elif v < -0.4:
                c = HEAVY[0] if riffle else (HEAVY[2] if grain(i, y, 461) == 0 else HEAVY[1])
            elif v < 4.2:
                c = STONE[1] if riffle else (STONE[3] if grain(i, y, 463) == 0 else STONE[2])
            else:
                c = GRIT[0] if riffle else (GRIT[3] if grain(i, y, 465) == 0 else GRIT[2])
            if i == 0:
                c = TIMBER[1]                                 # the deck's edge strips
            if i == DECK_W - 1:
                c = TIMBER[3]
            f.put(x, y, c)
        # the sheet of wash water running down the deck
        if y % 2 == 0:
            i = 3 + ((y * 5 + (0 if step is None else 2 + step * 3)) % (DECK_W - 5))
            f.put(x0 + i, y, WATER[0])
            f.put(x0 + i + 1, y, WATER[1])
    # the front edge of the tilted deck
    x0 = deck_left(DECK_FOOT) + shift
    for i in range(DECK_W):
        f.put(x0 + i, DECK_FOOT + 1, TIMBER[0] if grain(i // 4, 1, 467) else TIMBER[1])
        f.put(x0 + i, DECK_FOOT + 2, TIMBER[3])
    f.pts(IRON[2], (x0 + 3, DECK_FOOT + 2), (x0 + 15, DECK_FOOT + 2))
    # tailings slopping off the front edge
    for i in (2, 6, 11):
        f.put(x0 + i + (0 if step is None else step), DECK_FOOT + 1, GRIT[0])
    trim(f)
    return f


# ---------------------------------------------------------------- plates --

def plate(f, x0, y0, w=16, h=6):
    """One flat plate lying down, raked like a card on a table: the
    silvered face, then the bare copper showing on its front and right edge."""
    for r in range(h):
        y = y0 + r
        xs = x0 + (h - 1 - r) // 2
        for i in range(w):
            k = (i + r * 2) % 9                       # the sheen runs across in bars
            c = SILVERED[2]
            if k in (0, 1):
                c = SILVERED[0]
            elif k in (2, 8):
                c = SILVERED[1]
            elif k in (5, 6):
                c = SILVERED[3]
            if r == h - 1 and i > w // 2:
                c = SILVERED[4]
            f.put(xs + i, y, c)
        f.put(xs + w, y, COPPER[2] if r else COPPER[1])       # the right edge
    for i in range(w + 1):                            # the front edge
        f.put(x0 + i, y0 + h, COPPER[1] if i < 4 else (COPPER[2] if i < w - 2 else COPPER[3]))
    f.put(x0, y0 + h, COPPER[0])


def amalgamation_plates():
    f = Sprite()
    plate(f, 6, 16)                                   # the one underneath
    plate(f, 7, 12)                                   # and the one tied on it
    for tx in (12, 21):                               # the twine round the pair
        for y in range(12, 24):
            lean = (17 - y) // 2 if y < 18 else 0
            if (tx + lean, y) in f.px:
                f.put(tx + lean, y, TWINE[1] if y % 2 else TWINE[0])
    f.pts(TWINE[2], (12, 23), (21, 23))
    f.outline(COPPER_EDGE)
    f.pts(QUICK[1], (5, 25), (25, 24))                # beads shaken off the faces
    f.put(15, 25, QUICK[0])
    return f


# ------------------------------------------------------- apron overlays --

def apron(rows, splash):
    """A silvered copper apron plate sloping out toward the viewer. `rows`
    is [(y, x0, x1)] from its head under the mortar to its lip."""
    f = Sprite()
    last = len(rows) - 1
    for n, (y, x0, x1) in enumerate(rows):
        for x in range(x0, x1 + 1):
            k = (x * 2 + n * 3) % 11                  # the long sheen of the face
            c = SILVERED[2]
            if n == 0:
                c = SILVERED[4]                       # in the shadow of the box
            elif k < 2:
                c = SILVERED[0]
            elif k < 4:
                c = SILVERED[1]
            elif k in (7, 8):
                c = SILVERED[3]
            if x in (x0, x1):
                c = COPPER[1] if x == x0 else COPPER[3]       # the bare side edges
            if n == last:
                c = COPPER[2] if x0 < x < x1 else COPPER[4]   # the lip
            f.put(x, y, c)
    for x, n in splash:                               # pulp washing down the plate
        y, x0, x1 = rows[n]
        if x0 < x < x1:
            f.put(x, y, DARK_SLIME[2])
    return f


def plates_overlay_water():
    """For `water_stamp_mill`: between the posts, from the foot of the
    mortar box's front board out over the sill."""
    return apron([(27, 8, 17), (28, 8, 17), (29, 7, 18), (30, 7, 18), (31, 6, 19)],
                 ((11, 1), (11, 2), (14, 2), (14, 3), (10, 3)))


def plates_overlay_electric():
    """For `mining_drill` (32x48, so this lies on its lower 32 rows): on the
    bottom lip of the base ring, out past its foot."""
    return apron([(26, 10, 21), (27, 10, 21), (28, 9, 22), (29, 9, 22), (30, 8, 23), (31, 8, 23)],
                 ((13, 1), (13, 2), (18, 2), (18, 3), (12, 4), (17, 4)))


def states():
    """[(state, frames, delay)] in sheet order."""
    return [
        ('trommel', [trommel()], 0),
        ('trommel_on', [trommel(i) for i in range(TROMMEL_FRAMES)], RUN_DELAY),
        ('amalgamator_drum', [amalgamator_drum()], 0),
        ('amalgamator_drum_on', [amalgamator_drum(i) for i in range(DRUM_FRAMES)], RUN_DELAY),
        ('mercury_separator', [mercury_separator()], 0),
        ('shaking_table', [shaking_table()], 0),
        ('shaking_table_on', [shaking_table(i) for i in range(TABLE_FRAMES)], RUN_DELAY),
        ('amalgamation_plates', [amalgamation_plates()], 0),
        ('plates_overlay_water', [plates_overlay_water()], 0),
        ('plates_overlay_electric', [plates_overlay_electric()], 0),
    ]


# --------------------------------------------------------- sheet in/out --

def build():
    blocks, frames = [], []
    for name, frs, delay in states():
        block = 'state = "%s"\n\tdirs = 1\n\tframes = %d\n' % (name, len(frs))
        if len(frs) > 1:
            block += '\tdelay = %s\n' % ','.join([str(delay)] * len(frs))
        blocks.append(block)
        frames += [fr.image() for fr in frs]
    cols = int(len(frames) ** 0.5 + 0.999)
    rows = (len(frames) + cols - 1) // cols
    im = Image.new('RGBA', (cols * SIZE, rows * SIZE))
    for i, fr in enumerate(frames):
        im.paste(fr, ((i % cols) * SIZE, (i // cols) * SIZE))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    text += ''.join(blocks) + '# END DMI\n'
    return im, text


def write_dmi():
    im, text = build()
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    im.save(SHEET, 'PNG', pnginfo=meta, optimize=True)


def base_state(path, state):
    """The first frame of `state` in another sheet, whatever its cell size."""
    sheet = Image.open(path)
    text = sheet.info.get('Description', '')
    size = re.search(r'width = (\d+)\n\theight = (\d+)', text)
    if not size:
        return None
    w, h = int(size.group(1)), int(size.group(2))
    index = 0
    for name, dirs, frames in re.findall(r'state = "(.*?)"\n\tdirs = (\d+)\n\tframes = (\d+)', text):
        if name == state:
            cols = sheet.size[0] // w
            x, y = (index % cols) * w, (index // cols) * h
            return sheet.convert('RGBA').crop((x, y, x + w, y + h))
        index += int(dirs) * int(frames)
    return None


def laid_on(base, overlay):
    """The overlay on its machine, as the game lays it: bottom left corners
    together."""
    out = base.copy()
    out.alpha_composite(overlay.image(), (0, out.size[1] - SIZE))
    return out


def in_strip(overlay, strip):
    """True when every pixel of the overlay is inside its allowed strip."""
    top, left, right = strip
    return bool(overlay.px) and all(y >= top and left <= x <= right for x, y in overlay.px)


def check():
    if not SHEET.exists():
        return False
    im, text = build()
    old = Image.open(SHEET)
    return old.info.get('Description') == text and old.convert('RGBA').tobytes() == im.tobytes()


# -------------------------------------------------------------- review --

def backdrop(tones, w, h, scale):
    """Ground under a cell of any size, tiled from the 32x32 patch."""
    patch = ground(tones, scale)
    out = Image.new('RGBA', (w * scale, h * scale))
    for y in range(0, h * scale, SIZE * scale):
        for x in range(0, w * scale, SIZE * scale):
            out.paste(patch, (x, y))
    return out


def preview(path, scale=4):
    """Every frame, labelled, on grass (upper block) and dirt (lower), and
    last a row with each apron overlay laid on its machine."""
    cells = []
    for name, frs, _ in states():
        for i, fr in enumerate(frs):
            cells.append((name if len(frs) == 1 else '%s [%d]' % (name, i + 1), fr.image()))
    cols = 5
    lines = [cells[i:i + cols] for i in range(0, len(cells), cols)]
    extra = []
    mill = base_state(LODE, 'water_stamp_mill')
    if mill is not None:
        extra.append(('water_stamp_mill', mill))
        extra.append(('  + plates_overlay_water', laid_on(mill, plates_overlay_water())))
    for state in ('mining_drill', 'mining_drill_active'):
        drill = base_state(DRILL, state)
        if drill is not None:
            if state == 'mining_drill':
                extra.append((state, drill))
            extra.append(('%s + electric' % state.replace('mining_', ''),
                          laid_on(drill, plates_overlay_electric())))
    if extra:
        lines.append(extra)
    pad, label = 8, 14
    cw = SIZE * scale + pad + 24                      # room for the long names
    heights = [max(im.size[1] for _, im in line) * scale + label + pad for line in lines]
    block = sum(heights)
    out = Image.new('RGBA', (pad + cols * cw, pad + 2 * block), (24, 24, 24, 255))
    pen = ImageDraw.Draw(out)
    for j, tones in enumerate((GRASS, DIRT)):
        y = pad + j * block
        for line, high in zip(lines, heights):
            tall = max(im.size[1] for _, im in line)
            for i, (name, im) in enumerate(line):
                x = pad + i * cw
                tile = backdrop(tones, im.size[0], im.size[1], scale)
                tile.alpha_composite(im.resize((im.size[0] * scale, im.size[1] * scale), Image.NEAREST))
                top = y + (tall - im.size[1]) * scale
                out.paste(tile, (x, top))
                pen.text((x + 1, y + tall * scale + 1), name, fill=(230, 230, 230, 255))
            y += high
    out.save(path)


def gif(path, scale=4):
    """The amalgamating drum, the trommel and the shaking table working,
    side by side on grass at game speed."""
    loops = dict((n, f) for n, f, _ in states())
    shown = [loops[n] for n in ('amalgamator_drum_on', 'trommel_on', 'shaking_table_on')]
    back = ground(GRASS, scale)
    gap = 8
    side = SIZE * scale
    shots = []
    for t in range(6):                                # 3 and 2 frame loops both close in 6
        sheet = Image.new('RGBA', (gap + len(shown) * (side + gap), side + 2 * gap), (24, 24, 24, 255))
        for i, frs in enumerate(shown):
            tile = back.copy()
            tile.alpha_composite(frs[t % len(frs)].image().resize((side, side), Image.NEAREST))
            sheet.paste(tile, (gap + i * (side + gap), gap))
        shots.append(sheet.convert('RGB'))
    shots[0].save(path, save_all=True, append_images=shots[1:], duration=RUN_DELAY * 100, loop=0)


if __name__ == '__main__':
    if '--check' in sys.argv:
        if not check():
            sys.exit('stale sheet: ' + str(SHEET))
        if not in_strip(plates_overlay_water(), WATER_STRIP):
            sys.exit('plates_overlay_water leaves the foot of the water stamp mill')
        if not in_strip(plates_overlay_electric(), ELECTRIC_STRIP):
            sys.exit('plates_overlay_electric leaves the foot of the powered stamp mill')
        print('milling states match')
    else:
        write_dmi()
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
    if '--gif' in sys.argv:
        gif(sys.argv[sys.argv.index('--gif') + 1])
