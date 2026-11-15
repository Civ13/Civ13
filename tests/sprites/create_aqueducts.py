"""Script-drawn aqueduct pieces for icons/obj/aqueducts.dmi.

Every pixel is placed by this script from fixed palettes (Pillow only); no
external or generated artwork. The stone, timber, iron and water colours are
the ones create_sewers.py and create_flood_defences.py use, so an aqueduct
sits beside a drain or a cistern as the same masonry. The pieces are seen
three-quarters from above with the light from the upper left and are
transparent outside the drawn work.

States, all 32x32, 1 dir and 1 frame unless noted:

  channel0 .. channel15      An open stone-lined channel laid on the ground:
                             two low cut-stone kerbs and a mortar bed. Empty.
  flume0 .. flume15          A raised wooden trough on timber trestle legs,
                             its south board and the legs under it showing.
                             Empty.
  arch0 .. arch15            The channel carried high on a stone arcade: the
                             parapets and bed on top, the piers and arches
                             below its south side, open between the piers so
                             whoever walks under shows through. Empty.
  water0 .. water15          4 frames, 2 ds each. The water in a trough, an
                             overlay for channel / flume / arch of the same
                             number. Clean blue-green with ripples running
                             south and east; mid-light so a colour multiply
                             turns it foul.
  pipe_clay0 .. pipe_clay15  A thin terracotta pipe on the ground with joint
                             collars.
  pipe_lead0 .. pipe_lead15  A thinner dull grey lead pipe with soldered
                             joints.
  intake                     4 dirs. A stone intake head with a timber and
                             iron grate. dir points at the water it draws
                             from; the other half of the tile is a channel
                             arm running inland.
  qanat, qanat_wet           The mouth of an access shaft: a stone ring with
                             a small timber windlass; _wet has dark water
                             glinting at the bottom.
  noria                      4 dirs. A big timber water wheel with clay pots
                             on its rim. dir points at the river; a short
                             trough leaves the tile on the inland side.
  noria_on                   4 dirs, 4 frames, 2 ds each. The wheel turning,
                             water in its trough.
  fountain                   A street fountain: a stone basin with a carved
                             spout stone at the back (north). Dry.
  fountain_full              4 frames, 2 ds each. The basin full, the spout
                             running.
  tap                        A bronze standpipe over a small stone trough.
  tap_running                4 frames, 2 ds each.
  bath                       One tile of a public bath: a stone rim round a
                             sunken plastered pool with steps down from the
                             south. Empty.
  bath_full                  4 frames, 2 ds each. Full, the surface
                             shimmering.
  conduit_house              A small stone conduit house: a slab-roofed hut
                             over a water tank, with a door and a spout.

Junction convention. The number after channel / flume / arch / water /
pipe_clay / pipe_lead is a bitmask of the cardinal neighbours the piece
connects to, in BYOND dir values, exactly as in sewers.dmi:

  NORTH = 1   SOUTH = 2   EAST = 4   WEST = 8

3 runs north-south, 12 east-west, 5 is the corner joining north and east and
15 the cross. 0 has no neighbours: a square stone tank, a short box of
trough, a lone pier, a still pool and a pipe socket. A connected arm runs to
the tile edge with the same cross-section on every tile.

The three troughs share one inner channel, 8px wide on columns/rows 12-19
(centred on the same line as the drains in sewers.dmi), so waterN lies
exactly on the bed of channelN, flumeN and archN. The intake's inland half
is the same channel arm, so the water for that single arm fits it too.

Directions. Sheets with 4 dirs are in BYOND order SOUTH, NORTH, EAST, WEST.

Run with Pillow to rewrite icons/obj/aqueducts.dmi (safe to rerun). `--out
<dmi>` writes the sheet somewhere else, `--preview <png>` writes a 4x review
sheet (a sample network laid out on a river bank, then every state), and
`--check` only verifies that the committed sheet is what this script draws.
Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_water_animation import SIZE, pixels, read_dmi, write_dmi  # noqa: E402
from create_sewers import (BRASS, CHIP, CLEAR, CLEAR_GLINT, CLEAR_SHADE, FLOW, IRON, MORTAR,  # noqa: E402
                           NAIL, ROCK, SHADOW, SLAB, SLAB_SHADE, SLOT, WOOD, image, noise, toward)
from create_flood_defences import FOAM, PLASTER, ROPE, STONE_FOOT  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/aqueducts.dmi'
GROUND = ROOT / 'icons/turf/floors.dmi'

NORTH, SOUTH, EAST, WEST = 1, 2, 4, 8
DIRS = ('SOUTH', 'NORTH', 'EAST', 'WEST')   # BYOND order for dirs = 4
BIT = {'SOUTH': SOUTH, 'NORTH': NORTH, 'EAST': EAST, 'WEST': WEST}
BACK = {'SOUTH': 'NORTH', 'NORTH': 'SOUTH', 'EAST': 'WEST', 'WEST': 'EAST'}
MASKS = range(16)
FRAMES, DELAY = 4, 2                        # every animated state
EXT = range(-1, SIZE + 1)                   # one pixel past the tile, for shading at the edges

IN_LO, IN_HI = 12, 19                       # the inner channel every trough shares
CH_LO, CH_HI = 10, 21                       # channel kerbs and flume boards, 2px
AR_LO, AR_HI = 9, 22                        # arcade parapets, 3px
ARCH_DROP = 9                               # rows of arcade showing under the south side

STONE = SLAB + [SLAB_SHADE]                 # light to dark
BED = [(158, 150, 134), (144, 136, 121), (126, 119, 106)]      # the mortar bed
BED_SHADE = (98, 92, 82)
TERRA = [(222, 150, 104), (196, 118, 78), (160, 88, 58), (118, 62, 44)]
LEAD = [(170, 174, 182), (136, 140, 150), (104, 108, 118), (72, 75, 84)]
SOLDER = [(208, 210, 212), (172, 175, 180), (126, 129, 136)]
BRONZE = [(214, 168, 98), (172, 124, 64), (124, 86, 44), (82, 56, 32)]
DEEP = [(36, 64, 78), (48, 84, 100)]        # water far down a shaft
WATER_ALPHA = 235

# preview backgrounds, used when the game sheets cannot be read
GRASS = (86, 128, 62)
DIRT = (134, 102, 70)
RIVER = [(62, 112, 152), (74, 126, 164), (54, 100, 140)]
DARK = (30, 32, 36)


class Canvas:
    """Pixels with a material: (palette, tone, block). A pixel on the upper
    or left edge of its block is drawn a tone lighter and one on the lower
    or right edge a tone darker, in screen space, so every block is lit from
    the upper left whichever way the piece faces."""

    def __init__(self):
        self.m = {}

    def put(self, x, y, pal, tone=1, block=None):
        self.m[(x, y)] = (pal, tone, block)

    def flat(self, x, y, colour):
        self.m[(x, y)] = (None, colour, None)

    def under(self, x, y, colour):
        if (x, y) not in self.m:
            self.flat(x, y, colour)

    def box(self, x0, y0, x1, y1, pal, tone=1, block=None):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, pal, tone, block)

    def has(self, x, y):
        return (x, y) in self.m

    def image(self):
        px = {}
        for (x, y), (pal, tone, block) in self.m.items():
            if not (0 <= x < SIZE and 0 <= y < SIZE):
                continue
            if pal is None:
                px[(x, y)] = tone
                continue
            if block is not None:
                def edge(dx, dy):
                    other = self.m.get((x + dx, y + dy))
                    return other is None or other[2] != block
                lit = edge(0, -1) or edge(-1, 0)
                dark = edge(0, 1) or edge(1, 0)
                if lit and not dark:
                    tone -= 1
                elif dark and not lit:
                    tone += 1
            px[(x, y)] = pal[max(0, min(tone, len(pal) - 1))]
        return image(px)


def line(x0, y0, x1, y1):
    steps = int(max(abs(x1 - x0), abs(y1 - y0), 1))
    return [(int(round(x0 + (x1 - x0) * i / steps)), int(round(y0 + (y1 - y0) * i / steps)))
            for i in range(steps + 1)]


# ------------------------------------------------------------------- shapes

def arms(mask, lo, hi):
    """inside(x, y) for a junction piece `lo`..`hi` wide. A connected arm
    carries on past the tile edge."""
    def inside(x, y):
        cx, cy = lo <= x <= hi, lo <= y <= hi
        if cx and cy:
            return True
        if cx:
            return bool(mask & (NORTH if y < lo else SOUTH))
        if cy:
            return bool(mask & (WEST if x < lo else EAST))
        return False
    return inside


def kerb_block(mask, x, y, lo, hi, length=8):
    """The stone or board of a trough wall a pixel belongs to."""
    if lo <= x <= hi and lo <= y <= hi:
        across = (y < IN_LO and not mask & NORTH) or (y > IN_HI and not mask & SOUTH)
    else:
        across = lo <= y <= hi
    if across:
        north = y < 16
        return ('h', north, (x if north else x + length // 2) // length)
    west = x < 16
    return ('v', west, (y if west else y + length // 2) // length)


def stone_trough(c, mask, lo, hi, seed, light):
    """Stone walls and the mortar bed between them."""
    outer, inner = arms(mask, lo, hi), arms(mask, IN_LO, IN_HI)
    for y in EXT:
        for x in EXT:
            if inner(x, y):
                grain = noise(x, y, seed)
                tone = 0 if grain < 0.5 else 1
                if noise(x, y, seed + 1) < 0.06:
                    tone = 2
                if not inner(x, y - 1) or not inner(x - 1, y):
                    c.flat(x, y, BED_SHADE)        # the wall's shadow on the bed
                else:
                    c.put(x, y, BED, tone)
            elif outer(x, y):
                block = kerb_block(mask, x, y, lo, hi)
                tone = 1 if noise(block[2], 7 * block[1] + (block[0] == 'h'), seed + 2) < 0.6 else 2
                if not light:
                    tone += 1
                c.put(x, y, STONE, tone, block)
                if noise(x, y, seed + 3) < 0.03:
                    c.flat(x, y, CHIP)


def cast_shadow(c, inside, dx, dy, alpha):
    """The shadow a raised piece throws on the ground to the lower right."""
    for y in range(SIZE):
        for x in range(SIZE):
            if not c.has(x, y) and inside(x - dx, y - dy):
                c.flat(x, y, SHADOW + (alpha,))


# ------------------------------------------------------------------ channel

def channel(mask):
    c = Canvas()
    stone_trough(c, mask, CH_LO, CH_HI, 501, False)
    return c.image()


# -------------------------------------------------------------------- flume

def flume(mask):
    c = Canvas()
    outer, inner = arms(mask, CH_LO, CH_HI), arms(mask, IN_LO, IN_HI)

    def leg(x0, y0, rows=4):
        for y in range(y0, y0 + rows):
            c.flat(x0, y, WOOD[1] if y == y0 else WOOD[2])
            c.flat(x0 + 1, y, WOOD[3])

    # trestles under a north-south run: a cross beam with a leg at each end
    for bit, y0 in ((NORTH, 6), (SOUTH, 22)):
        if not mask & bit:
            continue
        for x in range(7, 25):
            if (x < 16 and mask & WEST or x >= 16 and mask & EAST) and bit == SOUTH:
                continue
            c.flat(x, y0, WOOD[1] if x not in (7, 24) else WOOD[2])
            c.flat(x, y0 + 1, WOOD[3])
        for x0, side in ((7, WEST), (23, EAST)):
            if not (bit == SOUTH and mask & side):
                leg(x0, y0 + 2)
    # legs under the south board of an east-west run and of a closed south end
    under = []
    if mask & WEST:
        under.append(6)
    if mask & EAST:
        under.append(22 if not mask & SOUTH else 24)
    if not mask & SOUTH:
        if not mask & WEST:
            under.append(10)
        if not mask & EAST:
            under.append(20)
        if mask & WEST and mask & EAST:
            under.append(14)
    for x0 in under:
        leg(x0, CH_HI + 3)

    for y in EXT:
        for x in EXT:
            if inner(x, y):
                # floor boards along the run, dark inside the trough
                tone = 2 if noise(x // 2, y // 2, 521) < 0.7 else 3
                if not inner(x, y - 1) or not inner(x - 1, y):
                    tone = 3
                c.flat(x, y, WOOD[tone])
                if (x % 16 == 15 and IN_LO <= y <= IN_HI) or (y % 16 == 15 and IN_LO <= x <= IN_HI):
                    c.flat(x, y, WOOD[3])
            elif outer(x, y):
                way, first, _ = kerb_block(mask, x, y, CH_LO, CH_HI)
                along, across = (x, y) if way == 'h' else (y, x)
                top = across in (CH_LO, IN_HI + 1)
                tone = 0 if top else 1
                if noise(along // 4, across, 523) < 0.25:
                    tone += 1
                c.flat(x, y, WOOD[tone])
                if along % 16 == 7:
                    c.flat(x, y, WOOD[3] if not top else NAIL)
    # the south board seen side on, wherever the trough has a south edge
    for x in EXT:
        for y in range(SIZE):
            if outer(x, y) and not outer(x, y + 1):
                c.flat(x, y + 1, WOOD[2] if x % 16 != 7 else WOOD[3])
                c.flat(x, y + 2, WOOD[3])
    cast_shadow(c, outer, 3, 6, 70)
    return c.image()


# --------------------------------------------------------------------- arch

def arch(mask):
    c = Canvas()
    outer = arms(mask, AR_LO, AR_HI)
    stone_trough(c, mask, AR_LO, AR_HI, 541, True)

    def solid(x):
        if not mask & EAST and x >= 14:
            return True
        if not mask & WEST and x <= 17:
            return True
        return x % 16 in (14, 15, 0, 1)

    def masonry(x, r):
        if solid(x) or r <= 2:
            return True
        reach = next((d for d in range(1, 8) if solid(x - d) or solid(x + d)), 8)
        return (r == 3 and reach < 4) or (r == 4 and reach < 2)

    for x in EXT:
        if not (outer(x, AR_HI) and not outer(x, AR_HI + 1)):
            continue
        for r in range(1, ARCH_DROP + 1):
            y = AR_HI + r
            if not masonry(x, r):
                c.flat(x, y, SHADOW + (125 if r <= 5 else 85,))
                continue
            course = (r - 1) // 3
            if r == 1:
                colour = SLAB_SHADE                     # under the parapet
            elif r == ARCH_DROP:
                colour = STONE_FOOT
            elif not masonry(x, r + 1) or (r <= 4 and not solid(x)):
                colour = SLAB[1]                        # the arch ring
            elif (r - 1) % 3 == 2 or (x + 3 * (course % 2)) % 6 == 0:
                colour = MORTAR
            else:
                colour = SLAB[2] if noise((x + 3 * (course % 2)) // 6, course, 543) < 0.55 else SLAB[3]
            if r > 4 and colour not in (MORTAR, STONE_FOOT):
                if not masonry(x + 1, r):
                    colour = SLAB_SHADE
                elif not masonry(x - 1, r):
                    colour = SLAB[1]
            c.flat(x, y, colour)
    cast_shadow(c, outer, 4, 4, 80)
    return c.image()


# -------------------------------------------------------------------- water

LANE_PHASE = (0, 5, 2, 7, 4, 1, 6, 3)


def water(mask, frame):
    inner = arms(mask, IN_LO, IN_HI)
    ns, ew = mask & (NORTH | SOUTH), mask & (EAST | WEST)
    px = {}
    for y in range(SIZE):
        for x in range(SIZE):
            if not inner(x, y):
                continue
            if not (IN_LO <= x <= IN_HI and IN_LO <= y <= IN_HI):
                upright = IN_LO <= x <= IN_HI
            elif bool(ns) != bool(ew):
                upright = bool(ns)
            else:
                upright = None                          # a meeting of arms, or a still tank
            if upright is None:
                along, lane = x + y, (x - y) % 8
            elif upright:
                along, lane = y, x - IN_LO
            else:
                along, lane = x, y - IN_LO
            phase = (along - 2 * frame + LANE_PHASE[lane]) % 8
            colour = CLEAR[0] if noise(x // 2, y // 2, 561) < 0.6 else CLEAR[1]
            if lane in (1, 4, 6) and phase < 3:
                colour = CLEAR[2]
                if lane == 4 and phase == 0:
                    colour = CLEAR_GLINT
            if not inner(x, y - 1) or not inner(x - 1, y):
                colour = CLEAR_SHADE
            px[(x, y)] = colour + (WATER_ALPHA,)
    return image(px)


# -------------------------------------------------------------------- pipes

def pipe(mask, lead):
    c = Canvas()
    lo, hi = (15, 17) if lead else (14, 17)
    body = arms(mask, lo, hi)
    pal = LEAD if lead else TERRA
    tones = (0, 1, 3) if lead else (0, 1, 2, 3)
    straight = mask in (NORTH | SOUTH, EAST | WEST)
    joint_lo, joint_hi = (14, 18) if lead else (13, 18)
    joint_pal = SOLDER if lead else TERRA
    for y in EXT:
        for x in EXT:
            if not body(x, y):
                continue
            if lo <= x <= hi and lo <= y <= hi:
                upright = bool(mask & (NORTH | SOUTH))
            else:
                upright = lo <= x <= hi
            along, across = (y, x) if upright else (x, y)
            c.flat(x, y, pal[tones[across - lo]])
            if not lead and noise(along // 3, upright, 581) < 0.2 and across in (lo + 1, lo + 2):
                c.flat(x, y, pal[tones[across - lo] + 1])
            if along % 16 in (7, 8) and not (joint_lo <= along <= joint_hi):
                # a collar, or a wiped solder joint, round the pipe
                for a in range(joint_lo, joint_hi + 1):
                    at = (a, y) if upright else (x, a)
                    c.put(at[0], at[1], joint_pal, 1, ('joint', upright, along // 16))
    if not straight:
        # a junction box, an elbow or a stopped end; alone, a socket
        for y in range(joint_lo, joint_hi + 1):
            for x in range(joint_lo, joint_hi + 1):
                corner = x in (joint_lo, joint_hi) and y in (joint_lo, joint_hi)
                if corner and (lead or mask == 0):
                    continue
                c.put(x, y, joint_pal, 1, 'hub')
        if mask == 0:
            for y in (15, 16):
                for x in (15, 16):
                    c.flat(x, y, SLOT)
            c.flat(15, 17, pal[0])
            c.flat(16, 17, pal[0])
    for y in range(SIZE):
        for x in range(SIZE):
            if not c.has(x, y) and (c.has(x, y - 1) and c.m[(x, y - 1)][1] != SHADOW + (70,)) \
                    and not c.has(x, y + 1):
                c.flat(x, y, SHADOW + (70,))
    return c.image()


# ------------------------------------------------------------------- intake

def intake(name):
    c = Canvas()
    stone_trough(c, BIT[BACK[name]], CH_LO, CH_HI, 501, False)

    def put(a, t, pal, tone, block):
        x, y = toward(name, a, t)
        c.put(x, y, pal, tone, block)

    def flat(a, t, colour):
        x, y = toward(name, a, t)
        c.flat(x, y, colour)

    # the head wall across the channel, a lintel over the opening
    for t in range(4, 9):
        for a in range(5, 27):
            block = 'lintel' if 12 <= a <= 19 else 'west' if a < 12 else 'east'
            put(a, t, STONE, 0 if block == 'lintel' else 1, ('wall', block))
            if noise(a, t, 601) < 0.04:
                flat(a, t, CHIP)
    # wing walls of rough stone running out into the water
    for t in range(9, 14):
        for a in list(range(5, 9)) + list(range(23, 27)):
            if t >= 12 and a in (8, 23):
                continue
            put(a, t, ROCK, 1, ('wing', a < 16, t < 12))
    # the grate: a timber frame with iron bars, the water dark behind them
    for t in range(9, 14):
        for a in range(9, 23):
            if a in (9, 10, 21, 22):
                put(a, t, WOOD, 1, ('post', a < 16))
            elif t == 13:
                put(a, t, WOOD, 1, 'sill')
            elif a % 2 == 0:
                flat(a, t, IRON[0] if t == 9 else IRON[1] if t < 12 else IRON[2])
            else:
                flat(a, t, CLEAR_SHADE if noise(a, t, 603) < 0.6 else DEEP[1])
    for a, t in ((10, 9), (21, 9), (10, 12), (21, 12)):
        flat(a, t, NAIL)
    # the river lapping at the grate
    for t in (14, 15):
        for a in range(7, 25):
            n = noise(a, t, 605)
            if n < 0.3:
                flat(a, t, FOAM + (150,))
            elif n < 0.7:
                flat(a, t, CLEAR_GLINT + (110,))
    return c.image()


# -------------------------------------------------------------------- qanat

def qanat(wet):
    c = Canvas()
    cx, cy, r_out, r_in = 15.5, 18.5, 9.6, 6.0
    ring = lambda x, y: r_in <= math.hypot(x - cx, y - cy) <= r_out    # noqa: E731
    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = x - cx, y - cy
            r = math.hypot(dx, dy)
            if ring(x, y):
                seg = int((math.atan2(dy, dx) + math.pi) / (2 * math.pi) * 10) % 10
                c.put(x, y, STONE, 1 if seg % 3 else 2, ('ring', seg))
                if noise(x, y, 621) < 0.03:
                    c.flat(x, y, CHIP)
            elif r < r_in:
                # the far wall of the shaft, lit a little, then the dark
                if dy < -1 and r > 4.6:
                    c.flat(x, y, ROCK[2] if (x + 2 * (y % 2)) % 4 else ROCK[3])
                elif dy < 0 and r > 3.2:
                    c.flat(x, y, ROCK[3])
                else:
                    c.flat(x, y, SLOT)
                if wet and math.hypot(dx, (dy - 1.2) * 1.15) < 3.7:
                    c.flat(x, y, DEEP[0] if noise(x, y, 623) < 0.7 else DEEP[1])
            elif dy > 0 and (ring(x, y - 1) or ring(x, y - 2)):
                c.flat(x, y, SLAB_SHADE if ring(x, y - 1) else STONE_FOOT)   # the ring stands proud
    if wet:
        for x, y in ((14, 19), (15, 19), (17, 21)):
            c.flat(x, y, CLEAR_GLINT)
        for x, y in ((16, 19), (13, 20), (16, 21), (15, 22)):
            c.flat(x, y, CLEAR[1])
    # the windlass: two posts, a barrel with the rope on it, an iron crank
    for x0, name in ((4, 'left'), (26, 'right')):
        c.box(x0, 5, x0 + 1, 21, WOOD, 1, ('post', name))
        c.flat(x0, 22, SHADOW + (90,))
        c.flat(x0 + 1, 22, SHADOW + (90,))
    for x in range(6, 26):
        c.flat(x, 7, WOOD[0] if noise(x // 3, 0, 625) < 0.7 else WOOD[1])
        c.flat(x, 8, WOOD[2])
        c.flat(x, 9, WOOD[3])
    for x in range(11, 21):
        for y in range(6, 11):
            c.flat(x, y, ROPE[0] if (x + (y > 8)) % 2 == 0 and y < 10 else ROPE[1])
    for y in range(11, 19):
        c.flat(16, y, ROPE[0] if y < 14 else ROPE[1])
    for x, y, colour in ((28, 7, IRON[0]), (28, 8, IRON[2]), (29, 8, IRON[1]), (29, 9, IRON[1]),
                         (29, 10, IRON[2]), (29, 11, IRON[2]), (30, 11, WOOD[1]), (30, 12, WOOD[3])):
        c.flat(x, y, colour)
    return c.image()


# -------------------------------------------------------------------- noria

WHEEL_R = 12.0
POTS = 8


def launder(c, name, running, frame):
    """The short trough that carries the lifted water off the tile, inland,
    on the line of a flume."""
    back = BACK[name]
    reach = {'SOUTH': 6, 'NORTH': 5, 'EAST': 13, 'WEST': 13}[name]
    for t in range(16 - reach, 16):
        for a in range(CH_LO, CH_HI + 1):
            x, y = toward(back, a, t)
            if IN_LO <= a <= IN_HI:
                if running:
                    lane = a - IN_LO
                    along = (y if back == 'SOUTH' else -y if back == 'NORTH' else x if back == 'EAST' else -x)
                    wave = (along - 2 * frame + LANE_PHASE[lane]) % 8
                    c.flat(x, y, CLEAR[2] if lane in (1, 4, 6) and wave < 3 else CLEAR[0])
                else:
                    c.flat(x, y, WOOD[2] if noise(x // 2, y // 2, 641) < 0.7 else WOOD[3])
                if t == 16 - reach:
                    c.flat(x, y, WOOD[3])
            else:
                c.put(x, y, WOOD, 1, ('board', a < 16))
    if name in ('EAST', 'WEST'):
        # its south board seen side on
        for t in range(16 - reach, 16):
            x, y = toward(back, CH_LO if name == 'WEST' else CH_HI, t)
            c.flat(x, y + 1, WOOD[2])
            c.flat(x, y + 2, WOOD[3])


def wheel_face(c, cx, cy, turn):
    """The wheel seen flat on: rim, spokes, hub and the pots tied to the rim."""
    step = 2 * math.pi / POTS
    for y in range(-2, SIZE + 2):
        for x in range(-2, SIZE + 2):
            dx, dy = x - cx, y - cy
            r = math.hypot(dx, dy)
            if r > WHEEL_R + 2.4:
                continue
            ang = math.atan2(dy, dx) - turn
            pot = int(math.floor(ang / step))
            pa = turn + (pot + 0.5) * step
            if math.hypot(dx - (WHEEL_R + 0.4) * math.cos(pa), dy - (WHEEL_R + 0.4) * math.sin(pa)) <= 1.75:
                c.put(x, y, TERRA, 1, ('pot', pot % POTS))
                continue
            if r > WHEEL_R:
                continue
            spoke = min(abs(r * math.sin(ang - k * step)) for k in range(POTS))
            if r > WHEEL_R - 2.0:
                tone = 0 if dx + dy < -6 else 2 if dx + dy > 6 else 1
                if r > WHEEL_R - 0.7 and tone:
                    tone += 1
                c.flat(x, y, WOOD[tone])
            elif r <= 2.4:
                c.flat(x, y, IRON[1] if dx + dy <= 0 else IRON[3])
            elif 5.6 <= r <= 6.6:
                c.flat(x, y, WOOD[2])
            elif spoke <= 0.62:
                c.flat(x, y, WOOD[1] if r < 5.6 else WOOD[2])
    c.flat(int(cx), int(cy), BRASS[1])
    c.flat(int(cx) + 1, int(cy), BRASS[0])


def wheel_edge(c, x0, frame):
    """The wheel seen edge on: two rims, the paddles and pots between them
    passing downward as it turns."""
    for y in range(1, 31):
        inset = 2 if y in (1, 30) else 1 if y in (2, 3, 28, 29) else 0
        for x in range(x0 + inset, x0 + 8 - inset):
            col = x - x0
            if col in (0, 1, 6, 7):
                tone = (0, 1, 1, 0, 0, 0, 1, 2)[col]
                if y % 8 == 3:
                    tone = 3
                c.flat(x, y, WOOD[min(tone + (y > 22), 3)])
                continue
            row = (y - frame) % 4
            if row == 0:
                c.flat(x, y, WOOD[0])                   # a paddle board
            elif row == 3:
                c.flat(x, y, WOOD[3])
            else:
                pot = ((y - frame) // 4) % 2
                colour = TERRA[1 if row == 1 else 2]
                if (col in (2, 3)) != bool(pot):
                    colour = WOOD[3] if row == 2 else WOOD[2]
                c.flat(x, y, colour)
    for x in range(x0 + 1, x0 + 7):
        c.flat(x, 31, SHADOW + (90,))


def noria(name, frame=None):
    c = Canvas()
    running = frame is not None
    turn = (frame or 0) * (2 * math.pi / POTS / FRAMES)
    if name in ('SOUTH', 'NORTH'):
        cx, cy = 15.5, (17.5 if name == 'SOUTH' else 14.0)
        feet = ((5, 30), (26, 30)) if name == 'SOUTH' else ((4, 28), (27, 28))

        def frame_legs(tones):
            for fx, fy in feet:
                for x, y in line(15.5 + (0.5 if fx > 15 else -0.5), cy, fx, fy):
                    c.flat(x, y, tones[0])
                    c.flat(x + 1, y, tones[1])
        if name == 'SOUTH':
            launder(c, name, running, frame or 0)
            frame_legs((WOOD[2], WOOD[3]))              # the trestle stands behind, on the bank
            wheel_face(c, cx, cy, turn)
            if running:
                for i in range(8, 24):
                    if noise(i, frame, 661) < 0.45:
                        c.flat(i, 31 - int(noise(i, frame, 663) * 2), FOAM + (190,))
        else:
            wheel_face(c, cx, cy, turn)
            frame_legs((WOOD[0], WOOD[2]))              # and in front, seen from the bank side
            for x, y, colour in ((15, 13, IRON[0]), (16, 13, IRON[1]), (15, 14, IRON[1]), (16, 14, IRON[3])):
                c.flat(x, y, colour)
            launder(c, name, running, frame or 0)
            if running:
                for i in range(9, 23):
                    if noise(i, frame, 665) < 0.4:
                        c.flat(i, int(noise(i, frame, 667) * 2), FOAM + (170,))
    else:
        flip = (lambda x: x) if name == 'EAST' else (lambda x: SIZE - 1 - x)
        d = Canvas()
        launder(d, 'EAST', running, frame or 0)
        # the catch box at the head of the trough and the post the axle turns in
        for y in range(8, 24):
            for x in range(13, 21):
                edge = x in (13, 20) or y in (8, 23)
                if edge:
                    d.put(x, y, WOOD, 1, 'box')
                elif running:
                    d.flat(x, y, CLEAR[(x + y + frame) % 3])
                else:
                    d.flat(x, y, WOOD[3] if y < 11 or x < 15 else WOOD[2])
        for x in range(13, 21):
            d.flat(x, 24, WOOD[2])
            d.flat(x, 25, WOOD[3])
        d.box(17, 3, 18, 27, WOOD, 1, 'post')
        for x, y in line(13, 27, 17, 20):
            d.flat(x, y, WOOD[2])
        for x in (19, 20):
            d.flat(x, 14, IRON[0])
            d.flat(x, 15, IRON[1])
            d.flat(x, 16, IRON[3])
        wheel_edge(d, 21, frame or 0)
        if running:
            for y in range(4, 9):
                if (y + frame) % 2:
                    d.flat(20, y, FLOW[0] + (220,))
                    d.flat(19, y + 1, FLOW[1] + (200,))
            for i in range(20, 31):
                if noise(i, frame, 669) < 0.4:
                    d.flat(i, 31, FOAM + (190,))
        if name == 'WEST':
            # the mirror image; the launder is redrawn so its boards stay lit from the left
            for (x, y), value in d.m.items():
                c.m[(flip(x), y)] = (value[0], value[1], None if value[2] is None else ('flip', value[2]))
        else:
            c = d
    return c.image()


# ----------------------------------------------------------------- fountain

def ripples(x, y, cx, cy, frame, squash=1.6):
    """Rings spreading from where a stream lands."""
    r = math.hypot(x - cx, (y - cy) * squash)
    return int(r - frame) % 4 == 0


def fountain(frame=None):
    c = Canvas()
    full = frame is not None
    x0, y0, x1, y1 = 4, 13, 27, 27
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if (x in (x0, x1)) and (y in (y0, y1)):
                continue
            if 7 <= x <= 24 and 16 <= y <= 24:
                if full and y >= 17:
                    colour = CLEAR[0] if noise(x // 2, y // 2, 701) < 0.6 else CLEAR[1]
                    if ripples(x, y, 15.5, 19.0, frame):
                        colour = CLEAR[2]
                    if y == 17 or x == 7:
                        colour = CLEAR_SHADE
                    c.flat(x, y, colour)
                elif y <= 18:
                    c.flat(x, y, SLAB[3] if y < 18 else SLAB_SHADE)     # the far side of the bowl
                elif x == 7 or y == 19:
                    c.flat(x, y, BED_SHADE)
                else:
                    c.put(x, y, BED, 1 if noise(x, y, 703) < 0.6 else 2)
                continue
            if y < 16:
                block = ('n', x // 8)
            elif y > 24:
                block = ('s', (x + 4) // 8)
            else:
                block = ('w' if x < 16 else 'e', y // 5)
            c.put(x, y, STONE, 1, ('rim',) + block)
    # the front of the basin
    for x in range(x0, x1 + 1):
        for row, colour in enumerate((SLAB[3], SLAB_SHADE, STONE_FOOT)):
            if row == 2 and x in (x0, x1):
                continue
            c.flat(x, y1 + 1 + row, MORTAR if x % 8 == 3 and row < 2 else colour)
    # the spout stone: an upright slab with a gable and a carved mask
    for y in range(2, 16):
        inset = 3 if y == 2 else 1 if y == 3 else 0
        for x in range(11 + inset, 21 - inset):
            c.put(x, y, STONE, 1, 'stele')
    for y in range(5, 12):
        for x in range(12, 20):
            r = math.hypot(x - 15.5, y - 8.0)
            if 2.4 <= r <= 3.4:
                c.flat(x, y, SLAB[3] if x - 15.5 + y - 8.0 < 0 else SLAB[0])
            elif r < 2.4:
                c.flat(x, y, SLAB[1])
    for x, y in ((14, 7), (17, 7)):
        c.flat(x, y, SLAB_SHADE)                        # the eyes
    for x, y, colour in ((15, 9, BRONZE[0]), (16, 9, BRONZE[1]), (15, 10, BRONZE[1]), (16, 10, BRONZE[2]),
                         (15, 11, BRONZE[2]), (16, 11, BRONZE[3])):
        c.flat(x, y, colour)
    if full:
        for y in range(12, 19):
            for x in (15, 16):
                n = noise(x, y - 2 * frame, 705)
                c.flat(x, y, (FLOW[0] if n < 0.4 else FLOW[1] if n < 0.8 else FLOW[2]) + (240,))
        splash = (((14, 19), (17, 18)), ((13, 19), (17, 19)), ((14, 18), (18, 19)), ((13, 18), (16, 19)))[frame]
        for at in splash:
            c.flat(at[0], at[1], CLEAR_GLINT)
    else:
        c.flat(15, 12, SLOT)
        c.flat(16, 12, SLOT)
    return c.image()


# ---------------------------------------------------------------------- tap

def tap(frame=None):
    c = Canvas()
    running = frame is not None
    x0, y0, x1, y1 = 8, 17, 25, 26
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 10 <= x <= 23 and 19 <= y <= 24:
                if running and y >= 20:
                    colour = CLEAR[0] if noise(x // 2, y // 2, 721) < 0.6 else CLEAR[1]
                    if ripples(x, y, 17.5, 21.5, frame):
                        colour = CLEAR[2]
                    if y == 20 or x == 10:
                        colour = CLEAR_SHADE
                    c.flat(x, y, colour)
                elif y == 19:
                    c.flat(x, y, SLAB[3])
                elif x == 10 or y == 20:
                    c.flat(x, y, BED_SHADE)
                else:
                    c.put(x, y, BED, 1 if noise(x, y, 723) < 0.6 else 2)
                continue
            block = ('n', x // 9) if y < 19 else ('s', (x + 4) // 9) if y > 24 else ('w' if x < 16 else 'e',)
            c.put(x, y, STONE, 1, ('rim',) + block)
    for x in range(x0, x1 + 1):
        for row, colour in enumerate((SLAB[3], SLAB_SHADE, STONE_FOOT)):
            if row == 2 and x in (x0, x1):
                continue
            c.flat(x, y1 + 1 + row, MORTAR if x % 9 == 4 and row < 2 else colour)
    # the standpipe behind the west end of the trough
    c.box(8, 14, 13, 16, STONE, 2, 'foot')
    for y in range(6, 14):
        c.flat(10, y, BRONZE[0])
        c.flat(11, y, BRONZE[2])
    c.box(9, 4, 12, 6, BRONZE, 1, 'head')
    c.box(9, 10, 12, 10, BRONZE, 1, 'band')
    for x in range(7, 15):                              # the tee handle
        c.flat(x, 2, BRONZE[0] if x not in (7, 14) else BRONZE[1])
        c.flat(x, 3, BRONZE[2] if x not in (7, 14) else BRONZE[3])
    c.flat(10, 3, BRONZE[1])
    c.flat(11, 3, BRONZE[3])
    for x in range(13, 19):                             # the spout
        c.flat(x, 5, BRONZE[0])
        c.flat(x, 6, BRONZE[2])
    for y in range(6, 11):
        c.flat(17, y, BRONZE[1])
        c.flat(18, y, BRONZE[3])
    c.flat(17, 5, BRONZE[0])
    c.flat(18, 5, BRONZE[1])
    c.flat(17, 11, SLOT)
    c.flat(18, 11, SLOT)
    if running:
        for y in range(12, 21):
            for x in (17, 18):
                n = noise(x, y - 2 * frame, 725)
                c.flat(x, y, (FLOW[0] if n < 0.4 else FLOW[1] if n < 0.8 else FLOW[2]) + (240,))
        splash = (((16, 21), (19, 20)), ((15, 21), (19, 21)), ((16, 20), (20, 21)), ((15, 20), (18, 21)))[frame]
        for at in splash:
            c.flat(at[0], at[1], CLEAR_GLINT)
    else:
        c.flat(17, 12, FLOW[1] + (160,))                # a drip left hanging
    return c.image()


# --------------------------------------------------------------------- bath

BATH_RIM = 3
BATH_WALL = (3, 7)                           # rows of the far wall of the pool
BATH_STEPS = ((26, 28, 0), (23, 25, 1), (20, 22, 2))     # rows and plaster tone, top step first
BATH_STEP_X = (11, 20)


def bath(frame=None):
    c = Canvas()
    lo, hi = BATH_RIM, SIZE - 1 - BATH_RIM
    for y in range(SIZE):
        for x in range(SIZE):
            if lo <= x <= hi and lo <= y <= hi:
                continue
            if y < lo:
                block = ('n', x // 8)
            elif y > hi:
                block = ('s', (x + 4) // 8)
            else:
                block = ('w' if x < lo else 'e', (y + (4 if x > hi else 0)) // 8)
            c.put(x, y, STONE, 1 if noise(block[1], len(block[0]) + ord(block[0][0]), 741) < 0.6 else 2, block)
    for y in range(lo, hi + 1):
        for x in range(lo, hi + 1):
            if y <= BATH_WALL[1]:
                tone = (1, 1, 1, 2, 3)[y - BATH_WALL[0]]
                if noise(x // 3, y, 743) < 0.15 and tone < 3:
                    tone += 1
            else:
                # the plastered floor, a dark line of tesserae round it
                tone = 3 if noise(x // 2, y // 2, 745) < 0.75 else 2
                border = (x in (7, 24) and 11 <= y <= 25) or (y in (11, 25) and 7 <= x <= 24)
                if border and (x + y) % 2 == 0:
                    tone = 4
                if x <= lo + 1 or y == BATH_WALL[1] + 1:
                    tone = 4                            # the rim's shadow
            c.flat(x, y, PLASTER[tone])
    for y0, y1, tone in BATH_STEPS:
        for y in range(y0, y1 + 1):
            for x in range(BATH_STEP_X[0], BATH_STEP_X[1] + 1):
                colour = PLASTER[tone]
                if x == BATH_STEP_X[1]:
                    colour = PLASTER[tone + 2]
                elif y == y1 and tone:
                    colour = PLASTER[tone + 2]          # the shadow of the step above
                c.flat(x, y, colour)
    for x in range(BATH_STEP_X[0], BATH_STEP_X[1] + 1):
        c.flat(x, 19, PLASTER[4])
    out = c.image()
    if frame is None:
        return out
    px = {}
    turn = frame * math.pi / 2
    for y in range(lo + 2, hi + 1):
        for x in range(lo, hi + 1):
            shimmer = math.sin(x * 0.7 + turn) + math.sin(y * 0.9 - turn + x * 0.25)
            colour = CLEAR[2] if shimmer > 1.25 else CLEAR[1] if shimmer < -1.0 else CLEAR[0]
            alpha = 205
            if BATH_STEP_X[0] <= x <= BATH_STEP_X[1] and y >= 20:
                alpha = (165, 185, 200)[[s[0] <= y <= s[1] for s in BATH_STEPS].index(True)]
            if y == lo + 2 or x == lo:
                colour, alpha = CLEAR_SHADE, 225
            px[(x, y)] = colour + (alpha,)
    for i in range(5):
        gx = lo + 2 + int(noise(i, 1, 747) * 20)
        gy = lo + 5 + int(noise(i, 2, 747) * 18)
        if (i + frame) % 4 < 2:
            px[(gx, gy)] = CLEAR_GLINT + (235,)
            if (i + frame) % 4 == 0:
                px[(gx + 1, gy)] = CLEAR_GLINT + (235,)
    out.alpha_composite(image(px))
    return out


# ------------------------------------------------------------ conduit house

def conduit_house():
    c = Canvas()
    # the wall, coursed stone
    for y in range(15, 29):
        for x in range(5, 27):
            course = (y - 15) // 3
            stone = (x + 3 * (course % 2)) // 6
            c.put(x, y, STONE, 2 if noise(stone, course, 761) < 0.6 else 3, ('wall', course, stone))
    for x in range(5, 27):
        c.flat(x, 15, STONE_FOOT)                       # under the eaves
        c.flat(x, 28, STONE_FOOT)
    # the stone slab roof, its front slope toward us, and the ridge
    for y in range(3, 15):
        for x in range(3, 29):
            if y < 5:
                c.put(x, y, STONE, 0, ('ridge', x // 9))
                continue
            course = (y - 5) // 3
            slab = (x + 3 * (course % 2)) // 6
            c.put(x, y, STONE, 1 if noise(slab, course, 763) < 0.6 else 2, ('roof', course, slab))
    c.box(15, 1, 16, 2, STONE, 1, 'finial')
    # the door, planked and strapped, under a round head
    for y in range(19, 28):
        for x in range(13, 19):
            if y == 19 and x in (13, 18):
                continue
            c.flat(x, y, WOOD[3] if x == 15 or y == 19 else WOOD[2] if noise(x, y // 3, 765) < 0.7 else WOOD[1])
    for x in range(13, 19):
        c.flat(x, 21, IRON[2])
        c.flat(x, 25, IRON[2])
    c.flat(17, 23, IRON[0])
    for x, y in ((12, 19), (19, 19), (12, 18), (13, 18), (18, 18), (19, 18)):
        c.flat(x, y, SLAB[1])                           # the door head
    for x in range(14, 18):
        c.flat(x, 18, SLAB[1])
    # a lead spout and the little trough it runs into
    for x, y, colour in ((8, 21, LEAD[0]), (9, 21, LEAD[1]), (8, 22, LEAD[2]), (9, 22, LEAD[3])):
        c.flat(x, y, colour)
    for y in (23, 24, 25):
        c.flat(8, y, SLAB_SHADE)                        # the damp under it
    c.box(6, 26, 11, 29, STONE, 1, 'trough')
    for x in range(7, 11):
        c.flat(x, 27, CLEAR[0] if x != 8 else CLEAR_GLINT)
    for x in range(6, 28):
        c.under(x, 29, SHADOW + (100,))
    for y in range(16, 29):
        c.under(27, y, SHADOW + (80,))
    return c.image()


# -------------------------------------------------------------------- build

def loop():
    return {'dirs': '1', 'frames': str(FRAMES), 'delay': ','.join([str(DELAY)] * FRAMES)}


ONE = {'dirs': '1', 'frames': '1'}
FOUR = {'dirs': '4', 'frames': '1'}
TROUGHS = ('channel', 'flume', 'arch')
JUNCTIONS = TROUGHS + ('water', 'pipe_clay', 'pipe_lead')


def build():
    states = []
    for name, draw in (('channel', channel), ('flume', flume), ('arch', arch)):
        states += [('%s%d' % (name, mask), dict(ONE), [draw(mask)]) for mask in MASKS]
    states += [('water%d' % mask, loop(), [water(mask, f) for f in range(FRAMES)]) for mask in MASKS]
    states += [('pipe_clay%d' % mask, dict(ONE), [pipe(mask, False)]) for mask in MASKS]
    states += [('pipe_lead%d' % mask, dict(ONE), [pipe(mask, True)]) for mask in MASKS]
    states.append(('intake', dict(FOUR), [intake(name) for name in DIRS]))
    states.append(('qanat', dict(ONE), [qanat(False)]))
    states.append(('qanat_wet', dict(ONE), [qanat(True)]))
    states.append(('noria', dict(FOUR), [noria(name) for name in DIRS]))
    turning = loop()
    turning['dirs'] = '4'
    states.append(('noria_on', turning, [noria(name, f) for f in range(FRAMES) for name in DIRS]))
    states.append(('fountain', dict(ONE), [fountain()]))
    states.append(('fountain_full', loop(), [fountain(f) for f in range(FRAMES)]))
    states.append(('tap', dict(ONE), [tap()]))
    states.append(('tap_running', loop(), [tap(f) for f in range(FRAMES)]))
    states.append(('bath', dict(ONE), [bath()]))
    states.append(('bath_full', loop(), [bath(f) for f in range(FRAMES)]))
    states.append(('conduit_house', dict(ONE), [conduit_house()]))
    return states


# ------------------------------------------------------------------- checks

def border(im, side):
    px = im.load()
    if side == NORTH:
        return [px[x, 0] for x in range(SIZE)]
    if side == SOUTH:
        return [px[x, SIZE - 1] for x in range(SIZE)]
    if side == EAST:
        return [px[SIZE - 1, y] for y in range(SIZE)]
    return [px[0, y] for y in range(SIZE)]


def check_drawing(states):
    by = {name: images for name, _, images in states}
    problems = []
    for name, _, images in states:
        if any(im.getbbox() is None for im in images):
            problems.append('%s has an empty frame' % name)
    straight = {NORTH: NORTH | SOUTH, SOUTH: NORTH | SOUTH, EAST: EAST | WEST, WEST: EAST | WEST}
    for kind in JUNCTIONS:
        for mask in MASKS:
            frames = by['%s%d' % (kind, mask)]
            for side in (NORTH, SOUTH, EAST, WEST):
                for n, im in enumerate(frames):
                    edge = border(im, side)
                    if mask & side:
                        # the work itself; a shadow beside it may be hidden by another arm
                        if edge[AR_LO:AR_HI + 1] != border(by['%s%d' % (kind, straight[side])][n], side)[AR_LO:AR_HI + 1]:
                            problems.append('%s%d does not meet a straight run on side %d' % (kind, mask, side))
                            break
                    elif kind in ('water', 'pipe_clay', 'pipe_lead', 'channel') and any(p[3] for p in edge):
                        problems.append('%s%d reaches the tile edge on unconnected side %d' % (kind, mask, side))
                        break
    # the water lies on the bed of every trough, and nowhere else
    for mask in MASKS:
        inner = arms(mask, IN_LO, IN_HI)
        want = {(x, y) for y in range(SIZE) for x in range(SIZE) if inner(x, y)}
        for im in by['water%d' % mask]:
            px = im.load()
            if {(x, y) for y in range(SIZE) for x in range(SIZE) if px[x, y][3]} != want:
                problems.append('water%d is not the shared inner channel' % mask)
                break
        for kind in TROUGHS:
            px = by['%s%d' % (kind, mask)][0].load()
            if any(px[x, y][3] != 255 for x, y in want):
                problems.append('%s%d has no bed under some of water%d' % (kind, mask, mask))
            walls = sum(1 for x, y in want for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                        if 0 <= x + dx < SIZE and 0 <= y + dy < SIZE and (x + dx, y + dy) not in want
                        and px[x + dx, y + dy][3] != 255)
            if walls:
                problems.append('%s%d has a gap in the wall round its bed' % (kind, mask))
    # the intake's inland half is a channel arm, so the single-arm water fits it
    for i, name in enumerate(DIRS):
        inner = arms(BIT[BACK[name]], IN_LO, IN_HI)
        px, ch = by['intake'][i].load(), by['channel%d' % BIT[BACK[name]]][0].load()
        half = {'SOUTH': lambda x, y: y < 16, 'NORTH': lambda x, y: y > 15,
                'EAST': lambda x, y: x < 16, 'WEST': lambda x, y: x > 15}[name]
        for y in range(SIZE):
            for x in range(SIZE):
                if half(x, y) and px[x, y] != ch[x, y]:
                    problems.append('intake %s inland half is not channel%d' % (name, BIT[BACK[name]]))
                    break
            else:
                continue
            break
        if any(px[x, y][3] != 255 for y in range(SIZE) for x in range(SIZE) if inner(x, y)):
            problems.append('intake %s has no bed under the water' % name)
    # animations: four different frames; the still parts stay put
    keys_of = {name: keys for name, keys, _ in states}
    for still, moving, dirs in (('noria', 'noria_on', 4), ('fountain', 'fountain_full', 1),
                                ('tap', 'tap_running', 1), ('bath', 'bath_full', 1)):
        want = loop()
        want['dirs'] = str(dirs)
        if keys_of[moving] != want or len(by[moving]) != FRAMES * dirs:
            problems.append('%s is not %d frames of %d ds' % (moving, FRAMES, DELAY))
            continue
        for d in range(dirs):
            shots = [pixels(by[moving][f * dirs + d]) for f in range(FRAMES)]
            if len({tuple(shot) for shot in shots}) != FRAMES:
                problems.append('%s repeats a frame' % moving)
            if pixels(by[still][d]) in shots:
                problems.append('%s looks the same as %s' % (still, moving))
    for mask in MASKS:
        if len({tuple(pixels(im)) for im in by['water%d' % mask]}) != FRAMES:
            problems.append('water%d repeats a frame' % mask)
    for name in ('qanat', 'qanat_wet', 'fountain', 'fountain_full', 'tap', 'tap_running', 'conduit_house'):
        for im in by[name]:
            box = im.getbbox()
            if box[0] < 1 or box[2] > SIZE - 1 or box[3] > SIZE - 1:
                problems.append('%s does not sit inside the tile' % name)
                break
    return problems


def check_sheet(path, states):
    """The committed sheet is exactly what build() draws."""
    if not Path(path).exists():
        return ['%s is missing' % path]
    have = read_dmi(path)
    problems = []
    if [name for name, _, _ in have] != [name for name, _, _ in states]:
        return ['state list differs: %s' % ', '.join(name for name, _, _ in have)]
    for (name, keys, images), (_, want_keys, want_images) in zip(have, states):
        if keys != want_keys:
            problems.append('%s has dirs/frames %r, expected %r' % (name, keys, want_keys))
        elif len(images) != len(want_images) or any(pixels(a) != pixels(b) for a, b in zip(images, want_images)):
            problems.append('%s is not what this script draws' % name)
    return problems


# ------------------------------------------------------------------- review

def ground_tiles():
    """Grass and dirt from the game sheet, or flat stand-ins; and a river."""
    flat = {'grass0': GRASS, 'dirt': DIRT}
    found = {}
    try:
        found = {name: images[0] for name, _, images in read_dmi(GROUND) if name in flat and images}
    except Exception:
        pass
    tiles = [found.get(name) or Image.new('RGBA', (SIZE, SIZE), colour + (255,)) for name, colour in flat.items()]
    river = Image.new('RGBA', (SIZE, SIZE), RIVER[0] + (255,))
    for y in range(SIZE):
        for x in range(SIZE):
            n = noise(x // 4, y, 801)
            if n < 0.12:
                river.putpixel((x, y), RIVER[1] + (255,))
            elif n > 0.9:
                river.putpixel((x, y), RIVER[2] + (255,))
    return tiles + [river]


# the sample network. ~ river, : the dirt of a hollow the arcade crosses,
# I intake, N noria, C channel, F flume, A arch, Q qanat shaft, O fountain,
# c clay pipe, l lead pipe, T tap, B bath, H conduit house
SCENE = ('~~............',
         '~~NFFF:::.Q...',
         '~~...F:::.C...',
         '~~ICCCAAAACCCO',
         '~~....:::.c...',
         '~~....:::.cccT',
         '~~...Hllllc...',
         '~~....:::.lBB.',
         '~~....:::..BB.')
TROUGH_OF = {'C': 'channel', 'F': 'flume', 'A': 'arch'}
PIPE_OF = {'c': 'pipe_clay', 'l': 'pipe_lead'}
# the dir of each single piece, and which neighbours it takes water from or gives it to
SCENE_DIR = {'I': 'WEST', 'N': 'WEST'}
JOINS = {'I': EAST, 'N': EAST, 'Q': SOUTH, 'O': WEST, 'T': WEST, 'H': EAST, 'B': WEST}


def write_preview(path, states, scale=4):
    by = {name: images for name, _, images in states}
    keys = {name: k for name, k, _ in states}
    grass, dirt, river = ground_tiles()
    label_h, pad = 12, 6
    cell = SIZE * scale
    cols = 16
    wide = pad + cols * (cell + pad)
    scene_h = len(SCENE) * cell

    def at(tx, ty):
        return SCENE[ty][tx] if 0 <= ty < len(SCENE) and 0 <= tx < len(SCENE[0]) else '.'

    def mask_of(tx, ty, group):
        here, mask = at(tx, ty), 0
        for bit, (dx, dy), back in ((NORTH, (0, -1), SOUTH), (SOUTH, (0, 1), NORTH),
                                    (EAST, (1, 0), WEST), (WEST, (-1, 0), EAST)):
            there = at(tx + dx, ty + dy)
            if there in group or (there in JOINS and JOINS[there] & back and there != 'B'):
                mask |= bit
            elif there == 'B' and back == WEST and at(tx + dx - 1, ty + dy) != 'B':
                mask |= bit
            elif here in TROUGH_OF and there in PIPE_OF and bit == SOUTH:
                mask |= bit                             # a channel spur feeding a pipe
            elif here in PIPE_OF and there in TROUGH_OF and bit == NORTH:
                mask |= bit
        return mask

    def scene(wet, frame):
        im = Image.new('RGBA', (len(SCENE[0]) * SIZE, len(SCENE) * SIZE))
        over = Image.new('RGBA', im.size)
        for ty in range(len(SCENE)):
            for tx in range(len(SCENE[0])):
                spot, here = (tx * SIZE, ty * SIZE), at(tx, ty)
                im.paste(river if here == '~' else dirt if here == ':' or (here == 'A' and 6 <= tx <= 8)
                         or (here == 'l' and 6 <= tx <= 8) else grass, spot)
                if here in TROUGH_OF:
                    mask = mask_of(tx, ty, TROUGH_OF)
                    layer = over if here == 'A' else im     # the arcade is drawn above people
                    layer.alpha_composite(by['%s%d' % (TROUGH_OF[here], mask)][0], spot)
                    if wet:
                        layer.alpha_composite(by['water%d' % mask][frame], spot)
                elif here in PIPE_OF:
                    im.alpha_composite(by['%s%d' % (PIPE_OF[here], mask_of(tx, ty, PIPE_OF))][0], spot)
                elif here == 'I':
                    d = DIRS.index(SCENE_DIR[here])
                    im.alpha_composite(by['intake'][d], spot)
                    if wet:
                        im.alpha_composite(by['water%d' % BIT[BACK[SCENE_DIR[here]]]][frame], spot)
                elif here == 'N':
                    d = DIRS.index(SCENE_DIR[here])
                    im.alpha_composite(by['noria_on'][frame * 4 + d] if wet else by['noria'][d], spot)
                elif here == 'Q':
                    im.alpha_composite(by['qanat_wet' if wet else 'qanat'][0], spot)
                elif here == 'O':
                    im.alpha_composite(by['fountain_full'][frame] if wet else by['fountain'][0], spot)
                elif here == 'T':
                    im.alpha_composite(by['tap_running'][frame] if wet else by['tap'][0], spot)
                elif here == 'B':
                    im.alpha_composite(by['bath_full'][frame] if wet else by['bath'][0], spot)
                elif here == 'H':
                    im.alpha_composite(by['conduit_house'][0], spot)
        im.alpha_composite(over)
        return im

    rows = 6 + 4                             # the junction rows, then the single pieces
    high = pad + 2 * (scene_h + label_h + pad) + rows * (cell + label_h + pad)
    sheet = Image.new('RGB', (wide, high), DARK)
    draw = ImageDraw.Draw(sheet)
    for n, (label, wet, frame) in enumerate((('the network running (frame 1)', True, 1), ('the network dry', False, 0))):
        y = pad + n * (scene_h + label_h + pad)
        im = scene(wet, frame)
        draw.text((pad, y), label, fill=(220, 220, 220))
        sheet.paste(im.convert('RGB').resize((im.width * scale, im.height * scale), Image.NEAREST), (pad, y + label_h))
        # the same at game size, to the right
        sheet.paste(im.convert('RGB'), (pad + im.width * scale + pad, y + label_h))
    top = pad + 2 * (scene_h + label_h + pad)

    def tile(layers, ground=None):
        im = (ground or grass).copy()
        for layer in layers:
            im.alpha_composite(layer)
        return im

    def show(im, col, row, label):
        x, y = pad + col * (cell + pad), top + row * (cell + label_h + pad)
        sheet.paste(im.convert('RGB').resize((cell, cell), Image.NEAREST), (x, y + label_h))
        draw.text((x, y), label, fill=(220, 220, 220))

    for mask in MASKS:
        show(tile([by['channel%d' % mask][0]]), mask, 0, 'channel%d' % mask)
        show(tile([by['flume%d' % mask][0]]), mask, 1, 'flume%d' % mask)
        show(tile([by['arch%d' % mask][0]], dirt if mask % 2 else grass), mask, 2, 'arch%d' % mask)
        under = TROUGHS[mask % 3]
        show(tile([by['%s%d' % (under, mask)][0], by['water%d' % mask][0]]), mask, 3, 'water%d %s' % (mask, under))
        show(tile([by['pipe_clay%d' % mask][0]]), mask, 4, 'pipe_clay%d' % mask)
        show(tile([by['pipe_lead%d' % mask][0]], dirt if mask % 2 else grass), mask, 5, 'pipe_lead%d' % mask)
    col, row = 0, 6

    def place(im, label, ground=None):
        nonlocal col, row
        if col >= cols:
            col, row = 0, row + 1
        show(tile([im], ground), col, row, label)
        col += 1

    for name in ('intake', 'noria'):
        for i, d in enumerate(DIRS):
            place(by[name][i], '%s %s' % (name, d))
    for i, d in enumerate(DIRS):
        for f in range(FRAMES):
            place(by['noria_on'][f * 4 + i], 'noria_on %s %d' % (d[0], f))
    for i, d in enumerate(DIRS):
        mask = BIT[BACK[d]]
        place(tile([by['intake'][i], by['water%d' % mask][0]]), 'intake+water%d' % mask)
    place(by['qanat'][0], 'qanat')
    place(by['qanat_wet'][0], 'qanat_wet')
    place(by['qanat'][0], 'qanat dirt', dirt)
    place(by['conduit_house'][0], 'conduit_house')
    place(by['conduit_house'][0], 'conduit dirt', dirt)
    for still, moving in (('fountain', 'fountain_full'), ('tap', 'tap_running'), ('bath', 'bath_full')):
        if col + 1 + FRAMES > cols:
            col, row = 0, row + 1
        place(by[still][0], still)
        for f in range(FRAMES):
            place(by[moving][f], '%s %d' % (moving, f))
    place(by['water3'][0], 'water3 alone', dirt)
    place(by['water15'][2], 'water15 alone', dirt)
    sheet.save(path)
    del keys


def option(name):
    args = sys.argv[1:]
    return args[args.index(name) + 1] if name in args[:-1] else None


def main():
    states = build()
    problems = check_drawing(states)
    if '--check' in sys.argv:
        problems += check_sheet(option('--sheet') or SHEET, states)
        for text in problems:
            print(text)
        print('aqueducts: %s' % ('FAILED' if problems else 'ok'))
        return 1 if problems else 0
    if problems:
        print('\n'.join(problems))
        return 1
    write_dmi(option('--out') or SHEET, states)
    if option('--preview'):
        write_preview(option('--preview'), states)
    return 0


if __name__ == '__main__':
    sys.exit(main())
