"""Script-drawn sewer pieces for icons/obj/sewers.dmi.

Every pixel is placed by this script from the fixed palettes below (Pillow
only); no external or generated artwork. The pieces are laid on ground tiles
and are transparent outside the drawn work, so the turf shows through. Light
comes from the upper left, as on the other script-drawn sheets.

States, all 32x32, 1 frame unless noted:

  ditch0 .. ditch15              1 dir. An open earth drain ditch: raw earth
                                 banks, a strip of wet mud and a thin line of
                                 murky water with scum in the bottom.
  stone_drain0 .. stone_drain15  1 dir. A covered stone drain: flat dressed
                                 cover slabs with mortar gaps and some wear.
  brick_drain0 .. brick_drain15  1 dir. An Imperial-era brick sewer: the back
                                 of a red-brown brick vault in stretcher bond
                                 with dark mortar and a lighter crown course.
  cesspit0 .. cesspit3           1 dir. A dug pit with a rough plank rim:
                                 empty, a little sludge, half full, and full
                                 to the brim with flies over it.
  outfall                        4 dirs (SOUTH, NORTH, EAST, WEST). The end
                                 of a drain at a river: a few stones and a
                                 dark wet spill fan.
  flap_gate                      4 dirs (SOUTH, NORTH, EAST, WEST). A hinged
                                 wooden flap with two iron straps hanging
                                 over the end of a drain, laid over an
                                 outfall tile.
  clog                           1 dir. An overlay for any drain piece: a
                                 lump of dark silt, sticks and a scrap of rag
                                 plugging the centre of the channel.
  pump_steam, pump_steam_on      1 dir. A small Victorian steam pumping
                                 engine seen from the side, standing on the
                                 end of a drain: a riveted iron boiler with a
                                 short chimney on a brick plinth, a flywheel
                                 and a suction pipe going down into the
                                 drain. _on is 4 frames, 2 ds each: the
                                 wheel and its rod turn, the fire flickers
                                 and steam drifts from the chimney.
  pump_electric,                 1 dir. A compact electric pump: a green
  pump_electric_on               painted motor and an iron pump casing on a
                                 concrete plinth, a riser with a red valve
                                 wheel, a cable box with a lamp and a spout.
                                 _on is 3 frames, 3 ds each: the lamp blinks,
                                 the cooling fins shimmer and water runs from
                                 the spout.
  septic0 .. septic3             1 dir. A sealed concrete septic tank seen
                                 from above, flush with the ground: a square
                                 lid with two round iron inspection covers on
                                 a diagonal, a vent and a brass level gauge. The gauge
                                 fills with the tank; at 2 the joints round
                                 the covers are damp and at 3 they weep. No
                                 open sewage shows at any level.
  settling0 .. settling3         1 dir. An open brick settling tank seen from
                                 above: a rectangular basin with an inlet on
                                 the west, a stone weir and an outlet chamber
                                 on the east. Clear water, then a growing
                                 layer of brown sludge on the bottom, then
                                 full and murky.

Junction convention. The number after ditch / stone_drain / brick_drain is a
bitmask of the
cardinal neighbours the piece connects to, in BYOND dir values:

  NORTH = 1   SOUTH = 2   EAST = 4   WEST = 8

So 3 runs north-south, 12 runs east-west, 5 is the corner joining north and
east, 7 is the tee with no west arm and 15 is the cross. A connected arm runs
to the tile edge with the same cross-section on every piece (the ditch is 12px
wide on columns/rows 10-21, the slabs and the brick vault 14px wide on 9-22,
all centred on the same line as the irrigation channel in
icons/turf/trench.dmi), so any run of tiles reads as one channel and a brick
arm meets a stone arm edge to edge. 0 is the piece with no neighbours: ditch0
is a short isolated trench, stone_drain0 is a single square slab with a
slotted stone grate, used as a street inlet, and brick_drain0 is a round
cast-iron manhole cover set in a square of brick.

The brick courses run along the drain, five to the width, with the bond
repeating every 8px so it carries on unbroken from tile to tile. Where arms
meet at a corner, tee or cross the courses are mitred on the diagonals, as
the groins of the vault are.

Outfall direction convention. The outfall and the flap gate are laid over
the last drain tile, and their dir points from the drain toward the water.
Only the water-side half of the tile is drawn:

  dir     the water is ...     drawn half
  SOUTH   south of the tile    bottom rows
  NORTH   north of the tile    top rows
  EAST    east of the tile     right columns
  WEST    west of the tile     left columns

Run with Pillow to rewrite icons/obj/sewers.dmi (safe to rerun). `--out <dmi>`
writes the sheet somewhere else, `--preview <png>` writes a labelled review
sheet with every state on grass and dirt and a 4x4 layout with loops, tees
and a cross for each drain, a layout where brick joins stone and a flap gate
closes the outfall, and clogs on a ditch and a drain, then the pumps (every
frame), the septic and settling tanks and two layouts with them in place,
`--check` only verifies that the committed sheet is what this script draws. Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_water_animation import SIZE, read_dmi, write_dmi  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/sewers.dmi'
GROUND = ROOT / 'icons/turf/floors.dmi'

NORTH, SOUTH, EAST, WEST = 1, 2, 4, 8
DIRS = ('SOUTH', 'NORTH', 'EAST', 'WEST')   # BYOND order for dirs = 4
MASKS = range(16)

# ---- open ditch -----------------------------------------------------------
D_LO, D_HI = 10, 21                      # the 12px channel
RIM = [(92, 66, 42), (74, 52, 34)]       # broken edge of the cut
BANK_LIT = [(134, 100, 64), (116, 86, 54)]
BANK_SHADE = [(98, 70, 44), (82, 58, 37)]
FOOT_LIT = (94, 72, 48)                  # lower bank, damp
FOOT_SHADE = (66, 49, 33)
MUD = [(60, 50, 38), (52, 43, 33)]       # wet mud beside the water
WATER = [(80, 76, 62), (70, 67, 55), (92, 87, 70)]
GLINT = (118, 113, 94)
SCUM = [(150, 150, 108), (116, 120, 84)]
DITCH_COLOURS = set(RIM + BANK_LIT + BANK_SHADE + [FOOT_LIT, FOOT_SHADE] + MUD + WATER + [GLINT] + SCUM)

# ---- stone drain ----------------------------------------------------------
S_LO, S_HI = 9, 22                       # the 14px line of slabs
SLAB = [(198, 194, 180), (172, 168, 155), (160, 156, 144), (146, 142, 131)]
SLAB_SHADE = (116, 112, 103)
CHIP = (128, 124, 114)
MORTAR = (94, 88, 78)
SLOT = (36, 32, 30)
SLOT_LIP = (206, 202, 188)
STONE_COLOURS = set(SLAB + [SLAB_SHADE, CHIP, MORTAR, SLOT, SLOT_LIP])

# ---- brick drain ----------------------------------------------------------
B_LO, B_HI = S_LO, S_HI                  # the 14px vault, on the slab line
BOND = 8                                 # a 7px stretcher and its joint
BRICK = [(184, 104, 76), (164, 86, 62), (144, 72, 52), (122, 58, 44), (100, 48, 38)]
BRICK_MORTAR = (72, 46, 38)
IRON = [(112, 114, 118), (82, 84, 88), (58, 60, 64), (38, 39, 43)]
BRICK_COLOURS = set(BRICK + [BRICK_MORTAR] + IRON)

# ---- cesspit --------------------------------------------------------------
P_LO, P_HI = 4, 27                       # the 24px pit with its rim
PLANK = 3
WOOD = [(176, 130, 84), (150, 108, 68), (118, 82, 50), (84, 57, 33)]
NAIL = (52, 44, 40)
WALL_LIT = [(124, 92, 60), (100, 73, 47)]
WALL_SHADE = [(74, 53, 35), (58, 42, 29)]
FLOOR = [(50, 37, 27), (40, 29, 22), (64, 46, 31)]
SLUDGE = [(104, 94, 56), (84, 76, 46), (64, 58, 36), (46, 42, 28)]
SHEEN = (140, 132, 86)
FLY = (24, 22, 22)
FLY_WING = (176, 180, 176)

# ---- outfall --------------------------------------------------------------
ROCK = [(176, 172, 162), (140, 137, 129), (106, 103, 98), (76, 73, 70)]
WET = (40, 36, 30)
FROTH = (186, 180, 150)

# ---- flap gate and clog ---------------------------------------------------
SHADOW = (20, 18, 16)
SILT = [(86, 76, 58), (66, 57, 43), (48, 42, 33), (34, 30, 26)]
STICK = [(132, 100, 62), (92, 66, 40)]
RAG = [(170, 162, 140), (124, 116, 100)]
CLOG_AT = (11, 12)                       # top left of the 10x8 lump
CLOG = ('...12k....',
        '.k1211k22.',
        '1Kk0122rr2',
        '12Kk12rrR3',
        '2122k23R33',
        '2212Kk2233',
        '.3222Kk23.',
        '..3333K3..')
CLOG_KEY = {'0': SILT[0], '1': SILT[1], '2': SILT[2], '3': SILT[3], 'k': STICK[0], 'K': STICK[1],
            'r': RAG[0], 'R': RAG[1]}

# ---- pump stations --------------------------------------------------------
STEAM_FRAMES, STEAM_DELAY = 4, 2         # frames, ds per frame
ELECTRIC_FRAMES, ELECTRIC_DELAY = 3, 3
BRASS = [(226, 188, 96), (184, 142, 62), (128, 94, 40)]
EMBER = [(255, 204, 96), (236, 120, 44), (132, 48, 28)]
STEAM = [(238, 238, 232), (204, 206, 204)]
PAINT = [(112, 148, 100), (80, 116, 74), (56, 86, 56), (36, 58, 40)]
CONCRETE = [(188, 188, 180), (168, 168, 161), (150, 150, 144), (114, 114, 109)]
VALVE = [(226, 92, 70), (188, 52, 42), (120, 30, 28)]
LAMP_LIT = [(255, 232, 150), (255, 176, 56)]
LAMP_DARK = [(132, 84, 34), (92, 56, 26)]
CABLE = (28, 27, 30)
FLOW = [(206, 226, 226), (142, 180, 190), (96, 140, 156)]
WHEEL_AT, WHEEL_R = (23, 16), 6          # the flywheel hub and its radius

# ---- septic tank ----------------------------------------------------------
LID_LO, LID_HI = 4, 27                   # the 24px lid, the size of the cesspit
COVERS = ((11, 11), (20, 20))            # the two inspection covers, on a diagonal
COVER_R = 4.4
DAMP = [(132, 128, 112), (104, 99, 80), (84, 78, 60)]
GAUGE_ROW, GAUGE_LO, GAUGE_STEP = 7, 19, 2
GAUGE_FULL = (204, 70, 44)

# ---- settling tank --------------------------------------------------------
T_X = (2, 29)                            # outer brick walls, 3px thick
T_Y = (6, 25)
T_WALL = 3
WEIR = (21, 22)                          # the two columns of the stone weir
NOTCH = (14, 17)                         # rows where the water goes over it
PORT = (15, 16)                          # rows of the inlet and the outlet
CLEAR = [(94, 140, 152), (80, 126, 140), (110, 156, 166)]
CLEAR_SHADE = (58, 98, 114)
CLEAR_GLINT = (182, 212, 214)
SETTLED = [(116, 110, 84), (100, 88, 60), (78, 66, 44)]     # sludge under water

# preview backgrounds, used when the game sheets cannot be read
GRASS = (86, 128, 62)
DIRT = (134, 102, 70)
RIVER = (62, 112, 152)
DARK = (30, 32, 36)


def noise(x, y, seed=0):
    """A fixed 0..1 value per pixel, so the sheet is reproducible."""
    n = (x * 374761393 + y * 668265263 + seed * 2147483647) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def image(px):
    im = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    for (x, y), c in px.items():
        if 0 <= x < SIZE and 0 <= y < SIZE:
            im.putpixel((x, y), c if len(c) == 4 else c + (255,))
    return im


# ------------------------------------------------------------------- shapes

def channel(mask, lo, hi, radius):
    """inside(x, y) for a junction piece. Connected arms carry on past the
    tile edge, so depth into the channel does not change at a join."""
    def rounded(x, y, x0, y0, x1, y1, corners):
        for cx, cy, sx, sy, cut in ((x0, y0, 1, 1, corners[0]), (x1, y0, -1, 1, corners[1]),
                                    (x0, y1, 1, -1, corners[2]), (x1, y1, -1, -1, corners[3])):
            if not cut:
                continue
            ox, oy = cx + sx * (radius - 0.5), cy + sy * (radius - 0.5)
            if (x - ox) * sx < 0 and (y - oy) * sy < 0 and (x - ox) ** 2 + (y - oy) ** 2 > radius * radius:
                return False
        return True

    n, s, e, w = mask & NORTH, mask & SOUTH, mask & EAST, mask & WEST

    def inside(x, y):
        if mask == 0:
            # a short trench, longer than it is wide
            return 7 <= x <= 24 and lo <= y <= hi and rounded(x, y, 7, lo, 24, hi, (1, 1, 1, 1))
        if lo <= x <= hi and lo <= y <= hi:
            return rounded(x, y, lo, lo, hi, hi,
                           (not n and not w, not n and not e, not s and not w, not s and not e))
        if lo <= x <= hi:
            return bool(n) if y < lo else bool(s)
        if lo <= y <= hi:
            return bool(w) if x < lo else bool(e)
        return False
    return inside


def depth(inside, x, y, reach=8):
    """(distance to the nearest ground pixel, direction to it)."""
    best, towards = reach + 1.0, (0, 0)
    for dy in range(-reach, reach + 1):
        for dx in range(-reach, reach + 1):
            if not inside(x + dx, y + dy):
                d = math.hypot(dx, dy)
                if d < best:
                    best, towards = d, (dx, dy)
    return best, towards


# -------------------------------------------------------------------- ditch

def ditch(mask):
    inside = channel(mask, D_LO, D_HI, 4)
    px = {}
    for y in range(SIZE):
        for x in range(SIZE):
            if not inside(x, y):
                continue
            d, (tx, ty) = depth(inside, x, y)
            level = int(d + 0.35)
            # the north and west banks face away from the light
            shaded = tx + ty < 0 or (tx + ty == 0 and ty < 0)
            grain = noise(x, y, 11)
            if level <= 1:
                c = RIM[1] if (grain < 0.45) != shaded else RIM[0]
            elif level == 2:
                c = (BANK_SHADE if shaded else BANK_LIT)[grain < 0.4]
            elif level == 3:
                c = FOOT_SHADE if shaded else FOOT_LIT
                if grain < 0.18:
                    c = (BANK_SHADE if shaded else BANK_LIT)[1]
            elif level == 4:
                c = MUD[grain < 0.4]
            else:
                c = WATER[0 if grain < 0.55 else 1 if grain < 0.85 else 2]
                film = noise(x // 2, y // 2, 23)
                if noise(x, y, 37) < 0.07:
                    c = GLINT
                if film < 0.11 and noise(x, y, 41) < 0.55:
                    c = SCUM[noise(x, y, 43) < 0.45]
            px[(x, y)] = c
    return image(px)


# -------------------------------------------------------------- stone drain

def slab_of(mask, x, y):
    """The slab a pixel lies on as (key, x0, y0, x1, y1, open sides), or
    'gap' for a mortar line, or None off the drain. A slab that runs to the
    tile edge is open there: it carries on into the next tile."""
    lo, hi = S_LO, S_HI
    if lo <= x <= hi and lo <= y <= hi:
        return ('c%d' % mask, lo, lo, hi, hi, '')
    if lo <= x <= hi and y < lo and mask & NORTH:
        return 'gap' if y == lo - 1 else ('n', lo, 0, hi, lo - 2, 'n')
    if lo <= x <= hi and y > hi and mask & SOUTH:
        return 'gap' if y == hi + 1 else ('s', lo, hi + 2, hi, SIZE - 1, 's')
    if lo <= y <= hi and x < lo and mask & WEST:
        return 'gap' if x == lo - 1 else ('w', 0, lo, lo - 2, hi, 'w')
    if lo <= y <= hi and x > hi and mask & EAST:
        return 'gap' if x == hi + 1 else ('e', hi + 2, lo, SIZE - 1, hi, 'e')
    return None


def stone_drain(mask):
    px = {}
    for y in range(SIZE):
        for x in range(SIZE):
            slab = slab_of(mask, x, y)
            if slab is None:
                continue
            if slab == 'gap':
                px[(x, y)] = MORTAR
                continue
            key, x0, y0, x1, y1, open_sides = slab
            seed = sum(ord(ch) for ch in key) * 7 + 101
            if (y == y1 and 's' not in open_sides) or (x == x1 and 'e' not in open_sides):
                c = SLAB_SHADE
            elif (y == y0 and 'n' not in open_sides) or (x == x0 and 'w' not in open_sides):
                c = SLAB[0]
            else:
                # broad worn patches, then a few chips
                patch = noise(x // 3, y // 3, seed)
                c = SLAB[1] if patch < 0.5 else SLAB[2] if patch < 0.85 else SLAB[3]
                if noise(x, y, seed + 1) < 0.12:
                    c = SLAB[2] if c == SLAB[1] else SLAB[1]
                if noise(x, y, seed + 2) < 0.035:
                    c = CHIP
            px[(x, y)] = c
    if mask == 0:
        # the inlet grate: three slots cut through the slab
        for sx in (12, 15, 18):
            for y in range(12, 20):
                px[(sx, y)] = px[(sx + 1, y)] = SLOT
            px[(sx, 20)] = px[(sx + 1, 20)] = SLOT_LIP
            px[(sx, 11)] = px[(sx + 1, 11)] = SLAB_SHADE
    else:
        # a hairline crack across the centre slab, different on each piece
        cx = S_LO + 3 + int(noise(mask, 1, 71) * 8)
        cy = S_LO + 2 + int(noise(mask, 2, 71) * 4)
        for i in range(3 + int(noise(mask, 3, 71) * 4)):
            px[(cx, cy)] = CHIP
            cx += (-1, 0, 1)[int(noise(mask, i, 73) * 3)]
            cy += 1
            if not (S_LO < cx < S_HI and S_LO < cy < S_HI):
                break
    return image(px)


# -------------------------------------------------------------- brick drain

def brick_way(mask, x, y):
    """True where the courses run north-south, False where they run
    east-west, None off the vault. In the centre the arms are mitred on the
    diagonals; a quarter with no arm of its own carries the run beside it."""
    lo, hi = B_LO, B_HI
    if lo <= x <= hi and lo <= y <= hi:
        if not mask & (EAST | WEST):
            return bool(mask)           # the manhole square is laid east-west
        if not mask & (NORTH | SOUTH):
            return False
        dx, dy = x - 15.5, y - 15.5
        if abs(dy) >= abs(dx):
            return bool(mask & (NORTH if dy < 0 else SOUTH))
        return not mask & (WEST if dx < 0 else EAST)
    if lo <= x <= hi:
        return True if mask & (NORTH if y < lo else SOUTH) else None
    if lo <= y <= hi:
        return False if mask & (WEST if x < lo else EAST) else None
    return None


def brick_at(upright, x, y):
    """The colour of the vault at a pixel for courses running north-south
    (upright) or east-west. Five 2px courses with a mortar line between; the
    middle one is the crown and the two on the far side from the light are
    darker."""
    across, along = (x - B_LO, y) if upright else (y - B_LO, x)
    course, row = divmod(across, 3)
    shift = BOND // 2 if course % 2 else 0
    if row == 2 or (along - shift) % BOND == BOND - 1:
        return BRICK_MORTAR
    brick = ((along - shift) // BOND) % (SIZE // BOND)
    tone = (2, 1, 0, 2, 3)[course]
    fired = noise(brick, course, 131 + upright)
    if fired < 0.3:
        tone += 1
    elif fired > 0.85 and course != 2:
        tone -= 1
    if noise(x, y, 137) < 0.04:
        tone += 1
    return BRICK[max(0, min(tone, len(BRICK) - 1))]


def brick_drain(mask):
    px = {}
    lo, hi = B_LO, B_HI
    for y in range(SIZE):
        for x in range(SIZE):
            upright = brick_way(mask, x, y)
            if upright is not None:
                px[(x, y)] = brick_at(upright, x, y)
    if mask in (NORTH, SOUTH, EAST, WEST):
        # a dead end is closed with a course of bricks laid across it
        for i in range(lo, hi + 1):
            for depth_in in range(3):
                edge = hi - depth_in if mask in (NORTH, WEST) else lo + depth_in
                at = (i, edge) if mask in (NORTH, SOUTH) else (edge, i)
                if depth_in == 2 or i - lo in (4, 9):
                    c = BRICK_MORTAR
                else:
                    c = BRICK[3 if mask in (NORTH, WEST) else 1]
                    if noise((i - lo) // 5, mask, 139) < 0.4:
                        c = BRICK[2]
                px[at] = c
    if mask == 0:
        # the manhole: a round cast-iron cover with a raised rim, a ring
        # groove and a chequered boss, in a mortar bed
        for y in range(lo, hi + 1):
            for x in range(lo, hi + 1):
                dx, dy = x - 15.5, y - 15.5
                r = math.hypot(dx, dy)
                if r > 6.6:
                    continue
                if r > 5.7:
                    c = BRICK_MORTAR
                elif r > 4.6:
                    c = IRON[0] if dx + dy < -2 else IRON[3] if dx + dy > 2 else IRON[1]
                elif 2.5 < r <= 3.4:
                    c = IRON[3] if dx + dy < 0 else IRON[2]
                elif r <= 2.5:
                    c = IRON[1] if (x + y) % 2 else IRON[3]
                else:
                    c = IRON[2] if noise(x, y, 141) < 0.3 else IRON[1]
                px[(x, y)] = c
    return image(px)


# ------------------------------------------------------------------ cesspit

FLIES = ((9, 10), (20, 8), (15, 17), (23, 20), (11, 22), (28, 13), (17, 2))


def cesspit(fill):
    px = {}
    lo, hi = P_LO, P_HI
    in_lo, in_hi = lo + PLANK, hi - PLANK

    def pit(x, y):
        return in_lo <= x <= in_hi and in_lo <= y <= in_hi

    # the pit itself
    for y in range(in_lo, in_hi + 1):
        for x in range(in_lo, in_hi + 1):
            d, (tx, ty) = depth(pit, x, y)
            level = int(d + 0.35)
            shaded = tx + ty < 0 or (tx + ty == 0 and ty < 0)
            grain = noise(x, y, 53)
            if level <= 3:
                tones = WALL_SHADE if shaded else WALL_LIT
                c = tones[0] if level == 1 else tones[1]
                if level == 2 and grain < 0.3:
                    c = tones[0]
                if level == 3 and not shaded:
                    c = WALL_SHADE[0]
            else:
                c = FLOOR[0] if grain < 0.5 else FLOOR[1]
                if noise(x, y, 59) < 0.06:
                    c = FLOOR[2]
            wobble = noise(x, y, 61)
            if fill == 1:
                # a pool in the middle of the bottom
                r = math.hypot(x - 15.8, (y - 16.4) * 1.25)
                if r < 3.6 + 1.6 * noise(x // 2, y // 2, 67):
                    c = SLUDGE[3] if wobble < 0.5 else SLUDGE[2]
                    if (x, y) in ((14, 15), (15, 15)):
                        c = SLUDGE[1]
            elif fill == 2 and level >= 3:
                c = SLUDGE[2] if wobble < 0.6 else SLUDGE[3]
                if level == 3:
                    c = SLUDGE[3]
                elif noise(x // 3, y, 69) < 0.14:
                    c = SLUDGE[1]
            elif fill == 3:
                c = SLUDGE[1] if wobble < 0.6 else SLUDGE[0]
                if level == 1:
                    c = SLUDGE[3] if shaded else SLUDGE[2]
                elif noise(x // 3, y, 69) < 0.16:
                    c = SHEEN if noise(x, y, 79) < 0.5 else SLUDGE[0]
                elif noise(x, y, 83) < 0.05:
                    c = SLUDGE[2]
            px[(x, y)] = c
    if fill == 2:
        px[(13, 14)] = px[(14, 14)] = px[(19, 18)] = SHEEN
    if fill == 3:
        for x, y in ((12, 13), (13, 13), (19, 19), (20, 19), (16, 21)):
            px[(x, y)] = SHEEN
        for x, y in ((18, 12), (12, 19)):       # bubbles
            px[(x, y)] = SLUDGE[3]
            px[(x, y - 1)] = SHEEN

    # the plank rim: top and bottom boards overlap the side boards, and the
    # rough ends stand a pixel proud here and there
    def board(x0, y0, x1, y1, across_y, seed):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                row = (y - y0) if across_y else (x - x0)
                along = (x - x0) if across_y else (y - y0)
                grain = noise(along // 3, row, seed)
                if row == 0:
                    c = WOOD[0] if grain < 0.7 else WOOD[1]
                elif row == 1:
                    c = WOOD[1] if grain < 0.75 else WOOD[2]
                else:
                    c = WOOD[2] if grain < 0.7 else WOOD[3]
                px[(x, y)] = c

    board(lo, in_lo, lo + PLANK - 1, in_hi, False, 201)            # west
    board(hi - PLANK + 1, in_lo, hi, in_hi, False, 202)            # east
    board(lo - 1, lo, hi, lo + PLANK - 1, True, 203)               # north
    board(lo, hi - PLANK + 1, hi + 1, hi, True, 204)               # south
    # the inner lip is in shadow on the lit side of the rim
    for i in range(in_lo, in_hi + 1):
        px[(i, lo + PLANK - 1)] = WOOD[3]
        px[(lo + PLANK - 1, i)] = WOOD[3]
    # board joints and nails
    for x, y in ((14, lo), (14, lo + 1), (20, hi), (20, hi - 1), (20, hi - 2)):
        px[(x, y)] = WOOD[3]
    for y, x in ((13, lo), (13, lo + 1), (18, hi), (18, hi - 1)):
        px[(x, y)] = WOOD[3]
    for x, y in ((lo + 1, lo + 1), (hi - 1, lo + 1), (lo + 1, hi - 1), (hi - 1, hi - 1),
                 (lo + 1, in_lo + 1), (hi - 1, in_hi - 1)):
        px[(x, y)] = NAIL
    # a split end
    px[(lo - 1, lo + 1)] = WOOD[3]
    px[(hi + 1, hi - 1)] = WOOD[3]

    if fill == 3:
        # slopped over the rim, and the flies
        for x, y in ((10, lo + 2), (11, lo + 2), (22, hi - 2), (hi - 2, 15), (hi - 2, 16)):
            px[(x, y)] = SLUDGE[2]
        for x, y in FLIES:
            px[(x, y)] = FLY
            px[(x + 1, y - 1)] = FLY_WING + (170,)
    return image(px)


# ------------------------------------------------------------------ outfall

def toward(name, a, t):
    """Tile pixel for `a` across the drain and `t` pixels from the middle of
    the tile toward the water."""
    if name == 'SOUTH':
        return a, 16 + t
    if name == 'NORTH':
        return 31 - a, 15 - t
    if name == 'EAST':
        return 16 + t, a
    return 15 - t, 31 - a


STONES = ((8.4, 3.4, 3.3, 2.6), (23.4, 3.0, 3.0, 2.5), (10.8, 8.8, 1.8, 1.5),
          (21.8, 9.4, 2.1, 1.7), (6.2, 12.2, 1.4, 1.2))
FROTHS = ((14, 4), (18, 5), (15, 7), (19, 9), (13, 10), (17, 12), (21, 13), (11, 13))


def outfall(name):
    px = {}
    # the spill fan: dark wet ground and water, widening and thinning out
    for t in range(1, 16):
        half = 3.2 + 0.62 * t
        for a in range(SIZE):
            off = abs(a + 0.5 - 16)
            edge = half + 1.6 * (noise(a, t, 91) - 0.5)
            if off > edge:
                continue
            alpha = 185.0 * (1.0 - t / 20.0) * (1.0 if off < edge * 0.55 else 0.62)
            if noise(a, t, 93) < 0.12:
                alpha *= 0.6
            px[toward(name, a, t)] = WET + (int(round(alpha)),)
    for a, t in FROTHS:
        px[toward(name, a, t)] = FROTH + (int(150 - 6 * t),)
    # the stones, shaded in screen space so the light stays upper left
    for a, t, ra, rt in STONES:
        cx, cy = toward(name, a - 0.5, t - 0.5)
        cx, cy = cx + 0.5, cy + 0.5
        rx, ry = (ra, rt) if name in ('SOUTH', 'NORTH') else (rt, ra)
        for y in range(SIZE):
            for x in range(SIZE):
                u, v = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                if u * u + v * v <= 1.0:
                    d = math.hypot(u + 0.45, v + 0.5)
                    px[(x, y)] = ROCK[0] if d < 0.5 else ROCK[1] if d < 1.0 else ROCK[2] if d < 1.42 else ROCK[3]
    return image(px)


# ---------------------------------------------------------------- flap gate

FLAP_A = (8, 23)                         # across the drain, a little wider
FLAP_T = (6, 14)                         # hanging out over the water
STRAPS = (11, 19)                        # each strap is 2px wide


def flap_gate(name):
    px = {}
    for a in range(FLAP_A[0] + 1, FLAP_A[1] + 1):
        px[toward(name, a, FLAP_T[1] + 1)] = SHADOW + (110,)
    # the boards run down the flap, four of them
    wood = {}
    for t in range(FLAP_T[0], FLAP_T[1] + 1):
        for a in range(FLAP_A[0], FLAP_A[1] + 1):
            plank, row = divmod(a - FLAP_A[0], 4)
            if row == 3 and a != FLAP_A[1]:
                c = WOOD[3]
            else:
                c = WOOD[1] if noise(plank, t // 3, 151) < 0.7 else WOOD[2]
            wood[toward(name, a, t)] = c
    # edges shaded in screen space so the light stays upper left
    for (x, y), c in wood.items():
        if (x + 1, y) not in wood or (x, y + 1) not in wood:
            c = WOOD[3]
        elif (x - 1, y) not in wood or (x, y - 1) not in wood:
            c = WOOD[0]
        px[(x, y)] = c
    # the hinge bar across the top of the drain mouth
    for a in range(FLAP_A[0] - 1, FLAP_A[1] + 2):
        ends = a in (FLAP_A[0] - 1, FLAP_A[1] + 1)
        px[toward(name, a, FLAP_T[0] - 2)] = IRON[3] if ends else IRON[1]
        px[toward(name, a, FLAP_T[0] - 1)] = IRON[3] if ends else IRON[2]
    # two iron straps from the bar down the flap, bolted through
    for a0 in STRAPS:
        for t in range(FLAP_T[0] - 2, FLAP_T[1] - 1):
            px[toward(name, a0, t)] = IRON[2]
            px[toward(name, a0 + 1, t)] = IRON[3]
        for t in (FLAP_T[0] - 2, FLAP_T[0] + 2, FLAP_T[1] - 3):
            px[toward(name, a0, t)] = IRON[0]
    return image(px)


# --------------------------------------------------------------------- clog

def clog():
    px = {}
    for row, line in enumerate(CLOG):
        for col, key in enumerate(line):
            if key != '.':
                px[(CLOG_AT[0] + col, CLOG_AT[1] + row)] = CLOG_KEY[key]
    return image(px)


# ------------------------------------------------------------ pump stations

def fill_box(px, x0, y0, x1, y1, colour):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px[(x, y)] = colour


def rod(px, x0, y0, x1, y1, colour):
    """A 1px straight line between two pixels."""
    steps = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(steps + 1):
        px[(int(round(x0 + (x1 - x0) * i / steps)), int(round(y0 + (y1 - y0) * i / steps)))] = colour


def ground_shadow(px, x0, x1, y):
    for x in range(x0, x1 + 1):
        px[(x, y)] = SHADOW + (70 if x in (x0, x1) else 110,)


def suction_pipe(px, top):
    """The pipe both pumps drop into the drain under the middle of the tile:
    a flange on the machine, the pipe down the face of the plinth and a
    flanged dark mouth at the ground."""
    for y in range(top + 1, 29):
        for x, c in zip(range(13, 17), (IRON[0], IRON[1], IRON[2], IRON[3])):
            px[(x, y)] = c
    for y, tones in ((top, (IRON[1], IRON[0], IRON[0], IRON[1], IRON[2], IRON[3])),
                     (29, (IRON[2], IRON[0], IRON[1], IRON[1], IRON[2], IRON[3]))):
        for x, c in zip(range(12, 18), tones):
            px[(x, y)] = c
    for x in range(13, 17):
        px[(x, 30)] = SLOT
    px[(12, 30)] = px[(17, 30)] = SHADOW + (110,)


def pump_steam(frame=None):
    """The steam pumping engine; `frame` is None stopped, else 0..3 running."""
    px = {}
    running = frame is not None
    turn = frame if running else 0

    # steam from the chimney, two puffs half a loop apart, thinning as they
    # rise and drift east. Drawn first so the engine stands in front of it
    if running:
        for k in range(2):
            age = (frame + 2 * k) % STEAM_FRAMES
            cx, cy = 5.5 + 2.3 * age, 4.2 - 1.1 * age
            radius = 1.5 + 0.55 * age
            for y in range(SIZE):
                for x in range(SIZE):
                    r = math.hypot(x - cx, (y - cy) * 1.15) + 0.9 * (noise(x, y, 301 + age) - 0.5)
                    if r > radius:
                        continue
                    alpha = (235, 200, 150, 100)[age]
                    if r > radius - 0.9:
                        alpha = alpha * 2 // 3
                    px[(x, y)] = STEAM[x - cx + y - cy > 0.8] + (alpha,)

    # the brick plinth: two courses with a lit top edge
    x0, x1, top = 2, 29, 24
    for x in range(x0, x1 + 1):
        for row in range(5):
            course = 0 if row < 2 else 1
            along = x - x0 + (3 if course else 0)
            if row == 2 or along % 6 == 5:
                c = BRICK_MORTAR
            else:
                tone = (0, 1, 0, 2, 3)[row]
                if noise(along // 6, course, 311) < 0.35:
                    tone += 1
                c = BRICK[tone]
            if x == x1 and c != BRICK_MORTAR:
                c = BRICK[4]
            px[(x, top + row)] = c
    ground_shadow(px, x0 + 1, x1 + 1, top + 5)

    # the chimney, with a flared cap and a strengthening band
    for y in range(5, 13):
        for x, c in zip((4, 5, 6), (IRON[1], IRON[2], IRON[3])):
            px[(x, y)] = c
    for x, c in zip(range(3, 8), (IRON[1], IRON[0], IRON[1], IRON[2], IRON[3])):
        px[(x, 5)] = c
    for x, c in zip((4, 5, 6), (IRON[0], IRON[0], IRON[2])):
        px[(x, 9)] = c

    # the boiler: a riveted iron barrel on its side, lit along the top
    tones = (1, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3)
    for row, tone in enumerate(tones):
        y = 13 + row
        for x in range(3, 18):
            if x in (3, 17) and row in (0, len(tones) - 1):
                continue
            c = IRON[tone]
            if x in (7, 13):                         # a lap seam and its rivets
                c = IRON[min(tone + 1, 3)]
                if row % 2 == 1:
                    c = IRON[0] if tone < 2 else IRON[1]
            elif x == 17:
                c = IRON[min(tone + 1, 3)]
            elif tone == 1 and noise(x, y, 313) < 0.12:
                c = IRON[2]
            px[(x, y)] = c
    # the fire door, glowing when the engine is in steam
    fill_box(px, 9, 17, 11, 21, IRON[3])
    if running:
        fire = ((EMBER[1], EMBER[0], EMBER[1]), (EMBER[0], EMBER[1], EMBER[2]),
                (EMBER[1], EMBER[1], EMBER[0]), (EMBER[2], EMBER[0], EMBER[1]))[frame]
        for y, c in zip((18, 19, 20), fire):
            px[(10, y)] = c
    else:
        px[(10, 18)] = px[(10, 19)] = px[(10, 20)] = SLOT
    # the pressure gauge
    px[(15, 15)] = BRASS[0]
    px[(15, 16)] = BRASS[1]

    # the cylinder on top of the barrel, brass bound
    for y, row in zip((10, 11, 12), ((IRON[0], IRON[0], IRON[1]), (IRON[1], IRON[1], IRON[2]),
                                      (IRON[2], IRON[2], IRON[3]))):
        for x, c in zip((9, 10, 11), row):
            px[(x, y)] = c
        px[(8, y)] = BRASS[0] if y == 10 else BRASS[1] if y == 11 else BRASS[2]
        px[(12, y)] = BRASS[1] if y < 12 else BRASS[2]

    # the bearing frame the flywheel turns in
    hx, hy = WHEEL_AT
    rod(px, hx - 3, 23, hx, hy, IRON[3])
    rod(px, hx + 3, 23, hx, hy, IRON[3])
    fill_box(px, hx - 3, 23, hx + 3, 23, IRON[2])

    # the flywheel: an iron rim on four spokes, an eighth of a quarter turn
    # a frame so the four frames close the loop
    spin = math.radians(22.5 * turn + 10)
    for y in range(hy - WHEEL_R, hy + WHEEL_R + 1):
        for x in range(hx - WHEEL_R, hx + WHEEL_R + 1):
            dx, dy = x - hx, y - hy
            r = math.hypot(dx, dy)
            if r > WHEEL_R + 0.45:
                continue
            if r > WHEEL_R - 1.25:
                c = IRON[0] if dx + dy < -4 else IRON[3] if dx + dy > 4 else IRON[1]
                if dx + dy < -4 and r > WHEEL_R - 0.3:
                    c = IRON[1]
            elif r <= 1.5:
                c = IRON[1] if dx + dy <= 0 else IRON[3]
            else:
                off = min(abs(dx * math.sin(spin + quarter) - dy * math.cos(spin + quarter))
                          for quarter in (0.0, math.pi / 2))
                if off > 0.55:
                    continue
                c = IRON[2]
            px[(x, y)] = c
    px[(hx, hy)] = BRASS[1]
    # the connecting rod from the cylinder to the crank pin, a quarter turn a frame
    crank = math.radians(90 * turn - 60)
    pin = (int(round(hx + 3 * math.cos(crank))), int(round(hy + 3 * math.sin(crank))))
    rod(px, 13, 11, pin[0], pin[1], SLAB[0])
    px[(13, 11)] = SLAB[1]
    px[pin] = BRASS[0]

    suction_pipe(px, 23)
    return image(px)


def pump_electric(frame=None):
    """The electric pump; `frame` is None stopped, else 0..2 running."""
    px = {}
    running = frame is not None

    # the concrete plinth
    x0, x1, top = 3, 26, 24
    for x in range(x0, x1 + 1):
        for row in range(5):
            c = (CONCRETE[0], CONCRETE[1], CONCRETE[1], CONCRETE[2], CONCRETE[3])[row]
            if row in (1, 2) and noise(x // 2, row, 331) < 0.3:
                c = CONCRETE[2]
            if x == x1 and row:
                c = CONCRETE[3]
            px[(x, top + row)] = c
    ground_shadow(px, x0 + 1, x1 + 1, top + 5)

    # the supply cable, down the back of the motor to the ground
    rod(px, 5, 10, 3, 12, CABLE)
    rod(px, 3, 12, 3, 23, CABLE)

    # the motor: a painted barrel with cooling fins between plain end bells
    tones = (1, 0, 0, 0, 1, 1, 1, 2, 2, 3)
    for row, tone in enumerate(tones):
        y = 13 + row
        for x in range(4, 17):
            if x in (4, 16) and row in (0, len(tones) - 1):
                continue
            c = PAINT[tone]
            if 7 <= x <= 13:
                # the fins; running, the light on them shivers
                dark = (x + (frame if running and row < 4 else 0)) % 2 == 0
                if dark and 0 < row < len(tones) - 1:
                    c = PAINT[min(tone + 1, 3)]
            elif x in (6, 14):
                c = PAINT[min(tone + 1, 3)]
            elif x == 16:
                c = PAINT[min(tone + 1, 3)]
            px[(x, y)] = c
    px[(5, 17)] = px[(15, 17)] = IRON[0]             # end bell bolts
    px[(5, 20)] = px[(15, 20)] = IRON[2]
    for x in (5, 6, 7, 13, 14, 15):                  # the feet
        px[(x, 23)] = IRON[3]
    fill_box(px, 9, 17, 11, 18, BRASS[1])            # the maker's plate
    px[(9, 17)] = px[(10, 17)] = BRASS[0]
    px[(11, 18)] = BRASS[2]

    # the cable box on top, with the running lamp
    fill_box(px, 6, 8, 11, 12, IRON[1])
    fill_box(px, 6, 8, 11, 8, IRON[0])
    fill_box(px, 11, 9, 11, 12, IRON[3])
    fill_box(px, 6, 12, 10, 12, IRON[2])
    px[(10, 10)] = px[(10, 11)] = CABLE              # the switch
    lamp = (7, 10)
    lit = running and frame != 2
    px[lamp] = LAMP_LIT[0] if lit else LAMP_DARK[0]
    px[(lamp[0] + 1, lamp[1])] = LAMP_LIT[1] if lit else LAMP_DARK[1]
    if running and frame == 0:
        for dx, dy in ((0, -1), (1, -1), (-1, 0), (2, 0), (0, 1), (1, 1)):
            px[(lamp[0] + dx, lamp[1] + dy)] = LAMP_LIT[1]
        px[lamp] = px[(lamp[0] + 1, lamp[1])] = LAMP_LIT[0]

    # the shaft, and the round iron pump casing it drives
    px[(17, 17)], px[(17, 18)] = SLAB[0], SLAB_SHADE
    cx, cy, cr = 22, 18, 4.5
    for y in range(13, 24):
        for x in range(17, 28):
            dx, dy = x - cx, y - cy
            r = math.hypot(dx, dy)
            if r > cr:
                continue
            if r > cr - 1.1:
                c = IRON[0] if dx + dy < -3 else IRON[3] if dx + dy > 3 else IRON[1]
            elif r <= 1.2:
                c = IRON[0] if dx + dy < 0 else IRON[1]
            elif r < 2.6:
                c = IRON[3] if dx + dy < 0 else IRON[2]
            else:
                c = IRON[1] if dx + dy < 1 else IRON[2]
            px[(x, y)] = c
    px[(cx, cy)] = BRASS[1]
    if running:                                      # the shaft end turning
        px[((cx - 1, cy), (cx, cy - 1), (cx + 1, cy))[frame]] = SLAB[0]

    # the riser, the valve and its red hand wheel
    for y in range(9, 14):
        for x, c in zip((21, 22, 23), (IRON[0], IRON[1], IRON[3])):
            px[(x, y)] = c
    for x, c in zip(range(20, 25), (IRON[1], IRON[0], IRON[1], IRON[2], IRON[3])):
        px[(x, 10)] = c
        px[(x, 13)] = c
    px[(22, 8)] = px[(22, 7)] = IRON[2]
    for x in range(19, 26):
        px[(x, 6)] = VALVE[2] if x in (19, 25) else VALVE[1]
    for x in range(20, 25):
        px[(x, 5)] = VALVE[0]
    px[(22, 6)] = VALVE[0]

    # the delivery pipe: out of the riser, over and down to a spout
    for x in range(24, 30):
        px[(x, 11)] = IRON[0]
        px[(x, 12)] = IRON[2]
    for y in range(11, 22):
        for x, c in zip((27, 28, 29), (IRON[0], IRON[1], IRON[3])):
            px[(x, y)] = c
    px[(27, 11)] = IRON[1]
    px[(29, 11)] = IRON[2]
    for x, c in zip(range(26, 31), (IRON[1], IRON[0], IRON[1], IRON[2], IRON[3])):
        px[(x, 21)] = c
    for x in (27, 28, 29):
        px[(x, 22)] = SLOT
    if running:
        # water falling from the spout, and where it lands
        for y in range(22, 29):
            for x in (27, 28, 29):
                n = noise(x, y - 2 * frame, 341)
                c = FLOW[0] if n < 0.3 else FLOW[1] if n < 0.75 else FLOW[2]
                px[(x, y)] = c + (235 if y < 28 else 200,)
        splash = (((26, 29), (30, 28), (28, 29)), ((27, 29), (29, 29), (30, 29)), ((26, 28), (28, 29), (29, 29)))[frame]
        for at in splash:
            px[at] = FLOW[0] + (190,)
    else:
        px[(28, 23)] = FLOW[1] + (150,)              # a drip left hanging

    suction_pipe(px, 23)
    return image(px)


# -------------------------------------------------------------- septic tank

def septic(fill):
    px = {}
    lo, hi = LID_LO, LID_HI
    # the cast concrete lid, flush with the ground
    for y in range(lo, hi + 1):
        for x in range(lo, hi + 1):
            patch = noise(x // 3, y // 3, 401)
            c = CONCRETE[1] if patch < 0.6 else CONCRETE[2]
            if noise(x, y, 403) < 0.1:
                c = CONCRETE[2] if c == CONCRETE[1] else CONCRETE[1]
            if noise(x, y, 405) < 0.03:
                c = CONCRETE[3]
            if y == hi or x == hi:
                c = CONCRETE[3]
            elif y == lo or x == lo:
                c = CONCRETE[0]
            px[(x, y)] = c
    # the two iron inspection covers, bedded in a joint
    for cx, cy in COVERS:
        for y in range(cy - 7, cy + 8):
            for x in range(cx - 7, cx + 8):
                if not (lo < x < hi and lo < y < hi):
                    continue
                dx, dy = x - cx, y - cy
                r = math.hypot(dx, dy)
                wet = noise(x, y, 407 + cx)
                if r > COVER_R + 1.0:
                    # damp, then weeping, in the concrete round the joint
                    if fill == 2 and r < COVER_R + 1.9 and wet < 0.4:
                        px[(x, y)] = DAMP[0]
                    elif fill == 3 and r < COVER_R + 2.1 and wet < 0.8:
                        px[(x, y)] = DAMP[1] if r < COVER_R + 1.6 or wet < 0.3 else DAMP[0]
                    continue
                if r > COVER_R:
                    c = CONCRETE[3] if fill < 2 else DAMP[1] if fill == 2 else DAMP[2]
                elif r > COVER_R - 1.0:
                    c = IRON[0] if dx + dy < -2 else IRON[3] if dx + dy > 2 else IRON[1]
                elif abs(dx) <= 1 and dy == 0:
                    c = IRON[3]                      # the lifting slot
                else:
                    c = IRON[1] if (x + y) % 2 else IRON[2]
                px[(x, y)] = c
    if fill == 3:
        # runs of seepage from the joints and the seam toward the low side
        for x, y0, length in ((8, 18, 3), (11, 18, 4), (14, 18, 2), (17, 26, 1), (22, 26, 1)):
            for y in range(y0, y0 + length):
                px[(x, y)] = DAMP[1] if y < y0 + length - 1 else DAMP[0]
        for at in ((17, 28), (18, 28), (21, 28), (22, 28), (23, 28), (28, 21), (28, 22), (28, 24)):
            px[at] = WET + (120,)
    # the vent stub
    for (x, y), c in zip(((6, 22), (7, 22), (8, 22), (6, 23), (7, 23), (8, 23), (6, 24), (7, 24), (8, 24)),
                         (IRON[1], IRON[0], IRON[1], IRON[0], SLOT, IRON[2], IRON[1], IRON[2], IRON[3])):
        px[(x, y)] = c
    # the level gauge: a brass-framed slot that fills from the west
    g0, g1 = GAUGE_LO, GAUGE_LO + 3 * GAUGE_STEP - 1
    fill_box(px, g0 - 1, GAUGE_ROW - 1, g1 + 1, GAUGE_ROW + 1, BRASS[1])
    fill_box(px, g0 - 1, GAUGE_ROW - 1, g1 + 1, GAUGE_ROW - 1, BRASS[0])
    fill_box(px, g0 - 1, GAUGE_ROW + 1, g1 + 1, GAUGE_ROW + 1, BRASS[2])
    for i in range(3 * GAUGE_STEP):
        c = SLOT
        if i < fill * GAUGE_STEP:
            c = GAUGE_FULL if fill == 3 else EMBER[0] if fill == 2 else STEAM[0]
        px[(g0 + i, GAUGE_ROW)] = c
    return image(px)


# ------------------------------------------------------------ settling tank

def settling(fill):
    px = {}
    (x0, x1), (y0, y1) = T_X, T_Y
    in_x0, in_x1, in_y0, in_y1 = x0 + T_WALL, x1 - T_WALL, y0 + T_WALL, y1 - T_WALL
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if in_x0 <= x <= in_x1 and in_y0 <= y <= in_y1:
                continue
            # the brick walls from above: which wall, and how far in from
            # its outer face. The corners are mitred
            reach = {'n': y - y0, 's': y1 - y, 'w': x - x0, 'e': x1 - x}
            side = min('nwse', key=lambda k: reach[k])
            ring = reach[side]
            along = x if side in 'ns' else y
            brick, joint = divmod(along + (2 if ring == 2 else 0), 5)
            if joint == 4 and ring < 2:
                c = BRICK_MORTAR
            else:
                # lit outer edge on the north and west, shaded on the south
                # and east; the inner face drops into shadow under the light
                tone = {'n': (0, 1, 4), 'w': (0, 1, 4), 's': (2, 3, 1), 'e': (2, 3, 1)}[side][ring]
                if ring < 2 and noise(brick, 'nwse'.index(side), 501) < 0.3:
                    tone += 1
                c = BRICK[min(tone, 4)]
            px[(x, y)] = c

    main_x1 = WEIR[0] - 1
    murky = fill == 3
    for y in range(in_y0, in_y1 + 1):
        for x in range(in_x0, in_x1 + 1):
            grain = noise(x, y, 503)
            shaded = y == in_y0 or x == in_x0 or x == WEIR[1] + 1
            if x in WEIR:
                # the stone weir, with the water going over its notch
                if NOTCH[0] <= y <= NOTCH[1]:
                    c = (CLEAR[2] if not murky else WATER[2]) if x == WEIR[0] else FROTH
                else:
                    c = SLAB[0] if x == WEIR[0] else SLAB[2]
                    if y in (in_y0, NOTCH[1] + 1):
                        c = SLAB_SHADE if x == WEIR[1] else SLAB[1]
                px[(x, y)] = c
                continue
            if x > WEIR[1]:
                # the outlet chamber: settled water, on its way out
                c = CLEAR[grain < 0.4] if not murky else WATER[grain < 0.4]
                if shaded:
                    c = CLEAR_SHADE if not murky else MUD[1]
                if NOTCH[0] <= y <= NOTCH[1] and x == WEIR[1] + 1:
                    c = FROTH if (y + fill) % 2 else CLEAR_GLINT
                px[(x, y)] = c
                continue
            # the main basin
            c = CLEAR[0] if grain < 0.55 else CLEAR[1] if grain < 0.85 else CLEAR[2]
            if shaded:
                c = CLEAR_SHADE
            elif noise(x, y, 505) < 0.04:
                c = CLEAR_GLINT
            # how far out from the middle of the basin floor, 0 to about 1.4
            out = math.hypot((x - (in_x0 + main_x1) / 2.0) / 8.0, (y - (in_y0 + in_y1) / 2.0) / 7.0)
            out += 0.35 * (noise(x // 2, y // 2, 507) - 0.5)
            if fill == 1 and out < 0.62:
                c = SETTLED[0] if out > 0.4 or grain < 0.6 else SETTLED[1]
                if out > 0.5 and grain < 0.35:
                    c = CLEAR[1]
            elif fill == 2 and out < 1.02:
                c = SETTLED[1] if out < 0.7 else SETTLED[0]
                if out < 0.45 and grain < 0.4:
                    c = SETTLED[2]
                if out > 0.9 and grain < 0.35:
                    c = CLEAR[1]
                if shaded:
                    c = SETTLED[2]
            elif murky:
                c = SLUDGE[1] if grain < 0.55 else SLUDGE[2]
                if shaded:
                    c = SLUDGE[3]
                elif noise(x // 3, y, 509) < 0.16:
                    c = SHEEN if noise(x, y, 511) < 0.5 else SLUDGE[0]
            px[(x, y)] = c
    if murky:
        for at in ((9, 12), (10, 12), (16, 19), (13, 16)):
            px[at] = SHEEN
        for x, y in ((18, 13), (8, 18)):                 # bubbles
            px[(x, y)] = SLUDGE[3]
            px[(x, y - 1)] = SHEEN
        for y in range(NOTCH[0] - 1, NOTCH[1] + 2):      # scum held back at the weir
            px[(main_x1, y)] = SCUM[y % 2]
    # the inlet and the outlet, cut through the end walls
    for y in PORT:
        for x in range(x0, in_x0):
            px[(x, y)] = (WATER[0] if fill else CLEAR[1]) if y == PORT[1] else MUD[1]
        for x in range(in_x1 + 1, x1 + 1):
            px[(x, y)] = (CLEAR[1] if not murky else WATER[0]) if y == PORT[1] else MUD[1]
    return image(px)


# -------------------------------------------------------------------- sheet

def build():
    """The whole sheet as [(state, keys, images)]."""
    one = {'dirs': '1', 'frames': '1'}
    states = [('ditch%d' % mask, dict(one), [ditch(mask)]) for mask in MASKS]
    states += [('stone_drain%d' % mask, dict(one), [stone_drain(mask)]) for mask in MASKS]
    states += [('cesspit%d' % fill, dict(one), [cesspit(fill)]) for fill in range(4)]
    states.append(('outfall', {'dirs': str(len(DIRS)), 'frames': '1'}, [outfall(name) for name in DIRS]))
    states += [('brick_drain%d' % mask, dict(one), [brick_drain(mask)]) for mask in MASKS]
    states.append(('flap_gate', {'dirs': str(len(DIRS)), 'frames': '1'}, [flap_gate(name) for name in DIRS]))
    states.append(('clog', dict(one), [clog()]))
    # phase S3, appended so the earlier states keep their place in the sheet
    states.append(('pump_steam', dict(one), [pump_steam()]))
    states.append(('pump_steam_on', loop(STEAM_FRAMES, STEAM_DELAY),
                   [pump_steam(frame) for frame in range(STEAM_FRAMES)]))
    states.append(('pump_electric', dict(one), [pump_electric()]))
    states.append(('pump_electric_on', loop(ELECTRIC_FRAMES, ELECTRIC_DELAY),
                   [pump_electric(frame) for frame in range(ELECTRIC_FRAMES)]))
    states += [('septic%d' % fill, dict(one), [septic(fill)]) for fill in range(4)]
    states += [('settling%d' % fill, dict(one), [settling(fill)]) for fill in range(4)]
    return states


def loop(frames, delay):
    return {'dirs': '1', 'frames': str(frames), 'delay': ','.join([str(delay)] * frames)}


def pixels(im):
    raw = im.convert('RGBA').tobytes()
    return [tuple(raw[i:i + 4]) for i in range(0, len(raw), 4)]


def borders(im):
    """The four border lines of a tile, each read along the join."""
    px = im.load()
    last = SIZE - 1
    return {NORTH: [px[i, 0] for i in range(SIZE)], SOUTH: [px[i, last] for i in range(SIZE)],
            WEST: [px[0, i] for i in range(SIZE)], EAST: [px[last, i] for i in range(SIZE)]}


def check_drawing(states):
    """Rules the drawing itself must keep, whatever the palettes become."""
    by = {name: images for name, _, images in states}
    problems = []
    for kind, colours in (('ditch', DITCH_COLOURS), ('stone_drain', STONE_COLOURS),
                          ('brick_drain', BRICK_COLOURS)):
        allowed = {c + (255,) for c in colours} | {(0, 0, 0, 0)}
        sides = {mask: borders(by['%s%d' % (kind, mask)][0]) for mask in MASKS}
        outline = None
        for mask in MASKS:
            if not set(pixels(by['%s%d' % (kind, mask)][0])) <= allowed:
                problems.append('%s%d uses a colour outside its palette' % (kind, mask))
            for side in (NORTH, SOUTH, EAST, WEST):
                line = sides[mask][side]
                solid = [bool(p[3]) for p in line]
                if not mask & side:
                    if any(solid):
                        problems.append('%s%d reaches its unconnected side %d' % (kind, mask, side))
                    continue
                # the same line on every piece that has this arm ...
                if line != sides[side][side]:
                    problems.append('%s%d does not match %s%d on side %d' % (kind, mask, kind, side, side))
                # ... and the same opening on all four sides
                outline = outline or solid
                if solid != outline:
                    problems.append('%s%d opens at a different place on side %d' % (kind, mask, side))
    for name, _, images in states:
        if any(p[3] == 0 and p != (0, 0, 0, 0) for im in images for p in pixels(im)):
            problems.append('%s has coloured invisible pixels' % name)
        if any(im.size != (SIZE, SIZE) for im in images):
            problems.append('%s is not %dpx' % (name, SIZE))
    for fill in range(4):
        box = by['cesspit%d' % fill][0].getbbox()
        if box is None or box[0] < 1 or box[1] < 1 or box[2] > SIZE - 1 or box[3] > SIZE - 1:
            problems.append('cesspit%d touches the tile edge' % fill)
    for state in ('outfall', 'flap_gate'):
        for i, name in enumerate(DIRS):
            px = by[state][i].load()
            dry = [(x, y) for y in range(SIZE) for x in range(SIZE)
                   if px[x, y][3] and {'SOUTH': y < 16, 'NORTH': y > 15, 'EAST': x < 16, 'WEST': x > 15}[name]]
            if dry:
                problems.append('%s %s draws on the drain half of the tile' % (state, name))
    # a brick arm and a stone arm open at the same place, so they butt cleanly
    for side in (NORTH, SOUTH, EAST, WEST):
        if ([bool(p[3]) for p in borders(by['brick_drain%d' % side][0])[side]]
                != [bool(p[3]) for p in borders(by['stone_drain%d' % side][0])[side]]):
            problems.append('brick_drain and stone_drain open differently on side %d' % side)
    want = (CLOG_AT[0], CLOG_AT[1], CLOG_AT[0] + len(CLOG[0]), CLOG_AT[1] + len(CLOG))
    if by['clog'][0].getbbox() != want or want != (11, 12, 21, 20):
        problems.append('clog is not the centred 10x8 lump')

    # phase S3: pumps, septic tank, settling tank
    keys_of = {name: keys for name, keys, _ in states}
    stands = (['pump_steam', 'pump_steam_on', 'pump_electric', 'pump_electric_on']
              + ['septic%d' % fill for fill in range(4)] + ['settling%d' % fill for fill in range(4)])
    for name in stands:
        for im in by[name]:
            box = im.getbbox()
            if box is None or box[0] < 1 or box[1] < 0 or box[2] > SIZE - 1 or box[3] > SIZE - 1:
                problems.append('%s does not sit inside the tile' % name)
                break
    for still, frames, delay in (('pump_steam', STEAM_FRAMES, STEAM_DELAY),
                                 ('pump_electric', ELECTRIC_FRAMES, ELECTRIC_DELAY)):
        name = still + '_on'
        if keys_of[name] != loop(frames, delay) or len(by[name]) != frames:
            problems.append('%s is not %d frames of %d ds' % (name, frames, delay))
        shots = [pixels(im) for im in by[name]]
        if any(shots[i] == shots[i - 1] for i in range(len(shots))):
            problems.append('%s repeats a frame' % name)
        if pixels(by[still][0]) in shots:
            problems.append('%s looks the same stopped and running' % still)
        # the machine stands still: only the moving parts may differ
        moved = sum(1 for spot in zip(pixels(by[still][0]), *shots) if len(set(spot)) > 1)
        if moved > SIZE * SIZE // 4:
            problems.append('%s moves more than its working parts' % name)
    sewage = {c + (255,) for c in SLUDGE + [SHEEN, FLY]}
    for fill in range(4):
        im = by['septic%d' % fill][0]
        px = im.load()
        if sewage & set(pixels(im)):
            problems.append('septic%d shows open sewage' % fill)
        if any(px[x, y][3] != 255 for y in range(LID_LO, LID_HI + 1) for x in range(LID_LO, LID_HI + 1)):
            problems.append('septic%d has a hole in its lid' % fill)
        lit = sum(1 for i in range(3 * GAUGE_STEP) if px[GAUGE_LO + i, GAUGE_ROW][:3] != SLOT)
        if lit != fill * GAUGE_STEP:
            problems.append('septic%d gauge reads %d' % (fill, lit))
    murk = {c + (255,) for c in SETTLED + SLUDGE + [SHEEN]}
    sludge = [sum(1 for p in pixels(by['settling%d' % fill][0]) if p in murk) for fill in range(4)]
    if sludge[0] or sorted(set(sludge)) != sludge:
        problems.append('settling tank sludge does not grow with the level: %r' % sludge)
    walls = [[p[3] for p in pixels(by['settling%d' % fill][0])] for fill in range(4)]
    if any(wall != walls[0] for wall in walls):
        problems.append('settling tank changes shape with the level')
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
        elif any(pixels(a) != pixels(b) for a, b in zip(images, want_images)):
            problems.append('%s is not what this script draws' % name)
    return problems


# ------------------------------------------------------------------- review

def ground_tiles():
    """Grass and dirt from the game sheet, or flat stand-ins."""
    flat = {'grass0': GRASS, 'dirt': DIRT}
    found = {}
    try:
        found = {name: images[0] for name, _, images in read_dmi(GROUND) if name in flat and images}
    except Exception:
        pass
    return [found.get(name) or Image.new('RGBA', (SIZE, SIZE), colour + (255,)) for name, colour in flat.items()]


# a 4x4 run with two loops, tees, a cross and two dead ends
LAYOUT = ('##.#',
          '####',
          '.##.',
          '.#..')


def layout_masks():
    def laid(tx, ty):
        return 0 <= ty < len(LAYOUT) and 0 <= tx < len(LAYOUT[0]) and LAYOUT[ty][tx] == '#'
    out = {}
    for ty in range(len(LAYOUT)):
        for tx in range(len(LAYOUT[0])):
            if laid(tx, ty):
                out[(tx, ty)] = (NORTH * laid(tx, ty - 1) + SOUTH * laid(tx, ty + 1)
                                 + EAST * laid(tx + 1, ty) + WEST * laid(tx - 1, ty))
    return out


def write_preview(path, states, scale=3):
    by = {name: images for name, _, images in states}
    grass, dirt = ground_tiles()
    water = Image.new('RGBA', (SIZE, SIZE), RIVER + (255,))
    label_h, pad = 12, 6
    cell = SIZE * scale
    wide = pad + 4 * (5 * cell + pad)
    rows = 10
    high = pad + rows * (cell + label_h + pad) + 3 * (4 * cell + label_h + pad)
    sheet = Image.new('RGB', (wide, high), DARK)
    draw = ImageDraw.Draw(sheet)

    def tile(layers):
        im = Image.new('RGBA', (SIZE, SIZE))
        for layer in layers:
            im.alpha_composite(layer)
        return im

    def show(im, col, row, label):
        x, y = pad + col * (cell + pad), pad + row * (cell + label_h + pad)
        big = im.convert('RGB').resize((im.width * scale, im.height * scale), Image.NEAREST)
        sheet.paste(big, (x, y + label_h))
        draw.text((x, y), label, fill=(220, 220, 220))

    for mask in MASKS:
        show(tile([grass, by['ditch%d' % mask][0]]), mask, 0, 'ditch%d' % mask)
        show(tile([dirt, by['ditch%d' % mask][0]]), mask, 1, 'ditch%d dirt' % mask)
        show(tile([grass, by['stone_drain%d' % mask][0]]), mask, 2, 'stone_drain%d' % mask)
        show(tile([dirt, by['stone_drain%d' % mask][0]]), mask, 3, 'stone_d%d dirt' % mask)
    for fill in range(4):
        show(tile([grass, by['cesspit%d' % fill][0]]), fill, 4, 'cesspit%d' % fill)
        show(tile([dirt, by['cesspit%d' % fill][0]]), fill + 4, 4, 'cesspit%d dirt' % fill)
    arm = {'SOUTH': SOUTH, 'NORTH': NORTH, 'EAST': EAST, 'WEST': WEST}
    for i, name in enumerate(DIRS):
        # the last drain tile with the outfall on it; the river lies beyond
        back = {'SOUTH': NORTH, 'NORTH': SOUTH, 'EAST': WEST, 'WEST': EAST}[name]
        kind = 'ditch' if i % 2 == 0 else 'stone_drain'
        show(tile([grass, by['%s%d' % (kind, arm[name] | back)][0], by['outfall'][i]]), 8 + i, 4,
             'outfall %s' % name)
        show(tile([dirt, by['outfall'][i]]), 12 + i, 4, 'alone %s' % name)

    clog_im = by['clog'][0]
    for mask in MASKS:
        show(tile([grass, by['brick_drain%d' % mask][0]]), mask, 5, 'brick_drain%d' % mask)
        show(tile([dirt, by['brick_drain%d' % mask][0]]), mask, 6, 'brick_d%d dirt' % mask)
    for i, name in enumerate(DIRS):
        back = {'SOUTH': NORTH, 'NORTH': SOUTH, 'EAST': WEST, 'WEST': EAST}[name]
        kind = 'brick_drain' if i % 2 == 0 else 'stone_drain'
        show(tile([grass, by['%s%d' % (kind, arm[name] | back)][0], by['outfall'][i], by['flap_gate'][i]]),
             i, 7, 'flap_gate %s' % name)
        show(tile([dirt, by['flap_gate'][i]]), 4 + i, 7, 'alone %s' % name)
    for n, (label, under) in enumerate((('clog ditch3', 'ditch3'), ('clog ditch12', 'ditch12'),
                                        ('clog stone3', 'stone_drain3'), ('clog stone15', 'stone_drain15'),
                                        ('clog brick12', 'brick_drain12'), ('clog brick7', 'brick_drain7'))):
        show(tile([grass, by[under][0], clog_im]), 8 + n, 7, label)
    show(tile([grass, clog_im]), 14, 7, 'clog alone')
    show(tile([dirt, clog_im]), 15, 7, 'clog dirt')

    # phase S3: each pump stopped on grass and dirt, then every running frame
    # over the end of a drain; the two tanks at each level on grass and dirt
    col = 0
    for still, under in (('pump_steam', 'brick_drain1'), ('pump_electric', 'stone_drain1')):
        show(tile([grass, by[still][0]]), col, 8, still)
        show(tile([dirt, by[still][0]]), col + 1, 8, 'dirt')
        show(tile([grass, by[under][0], by[still][0]]), col + 2, 8, 'on a drain')
        col += 3
        for n, frame in enumerate(by[still + '_on']):
            show(tile([grass, by[under][0], frame]), col, 8, '_on %d' % n)
            col += 1
    for fill in range(4):
        show(tile([grass, by['septic%d' % fill][0]]), fill, 9, 'septic%d' % fill)
        show(tile([dirt, by['septic%d' % fill][0]]), fill + 4, 9, 'septic%d dirt' % fill)
        show(tile([grass, by['settling%d' % fill][0]]), fill + 8, 9, 'settling%d' % fill)
        show(tile([dirt, by['settling%d' % fill][0]]), fill + 12, 9, 'settling%d dirt' % fill)
    # the same pieces at game size, on grass
    actual = [by['pump_steam'][0], by['pump_steam_on'][1], by['pump_electric'][0], by['pump_electric_on'][0]]
    actual += [by['septic%d' % fill][0] for fill in range(4)] + [by['settling%d' % fill][0] for fill in range(4)]
    ax, ay = pad + 13 * (cell + pad), pad + 8 * (cell + label_h + pad)
    draw.text((ax, ay), 'at game size', fill=(220, 220, 220))
    for n, im in enumerate(actual):
        sheet.paste(tile([grass, im]).convert('RGB'), (ax + (n % 6) * (SIZE + 2), ay + label_h + (n // 6) * (SIZE + 2)))

    # the layouts, tiles butted together with no gap
    masks = layout_masks()
    top = pad + rows * (cell + label_h + pad)

    def one(tx, ty, kind):
        return kind

    def joined(tx, ty, kind):
        # brick on the two west columns, stone slabs from there to the river
        return 'brick_drain' if tx < 2 else 'stone_drain'

    # (label, piece, ground, which piece on which tile, flap gate, clogged
    # tiles, other pieces laid on tiles)
    scenes = (('ditch on grass', 'ditch', grass, one, False, (), {}),
              ('ditch on dirt', 'ditch', dirt, one, False, (), {}),
              ('stone_drain on grass', 'stone_drain', grass, one, False, (), {}),
              ('stone_drain on dirt', 'stone_drain', dirt, one, False, (), {}),
              ('brick_drain on grass', 'brick_drain', grass, one, False, (), {}),
              ('brick_drain on dirt', 'brick_drain', dirt, one, False, (), {}),
              ('brick into stone, flap gate, clog', '', grass, joined, True, ((2, 2),), {}),
              ('ditch, flap gate, clogs', 'ditch', grass, one, True, ((1, 2), (0, 0)), {}),
              ('steam pump, settling tank, septic', 'brick_drain', grass, one, False, (),
               {(3, 1): by['pump_steam_on'][1], (3, 2): by['settling1'][0], (0, 3): by['septic1'][0],
                (3, 3): by['settling3'][0]}),
              ('electric pump, septic, settling tank', 'stone_drain', dirt, one, False, (),
               {(3, 1): by['pump_electric_on'][0], (3, 2): by['settling2'][0], (0, 3): by['septic3'][0],
                (0, 2): by['septic0'][0]}))
    for n, (label, kind, ground, pick, gated, clogged, extras) in enumerate(scenes):
        scene = Image.new('RGBA', (5 * SIZE, 4 * SIZE))
        for ty in range(4):
            for tx in range(5):
                at = (tx * SIZE, ty * SIZE)
                # a river down the right side, fed by an outfall on row 1
                scene.paste(water if tx == 4 else ground, at)
                mask = masks.get((tx, ty))
                if mask is None:
                    if (tx, ty) in extras:
                        scene.alpha_composite(extras[(tx, ty)], at)
                    continue
                if (tx, ty) == (3, 1):
                    mask |= EAST
                scene.alpha_composite(by['%s%d' % (pick(tx, ty, kind), mask)][0], at)
                if (tx, ty) == (3, 1):
                    scene.alpha_composite(by['outfall'][DIRS.index('EAST')], at)
                    if gated:
                        scene.alpha_composite(by['flap_gate'][DIRS.index('EAST')], at)
                if (tx, ty) in clogged:
                    scene.alpha_composite(clog_im, at)
                if (tx, ty) in extras:
                    scene.alpha_composite(extras[(tx, ty)], at)
        x = pad + (n % 4) * (5 * cell + pad)
        y = top + (n // 4) * (4 * cell + label_h + pad)
        big = scene.convert('RGB').resize((scene.width * scale, scene.height * scale), Image.NEAREST)
        sheet.paste(big, (x, y + label_h))
        draw.text((x, y), label, fill=(220, 220, 220))
    sheet.save(path)


def option(name):
    args = sys.argv[1:]
    return args[args.index(name) + 1] if name in args[:-1] else None


def main():
    states = build()
    problems = check_drawing(states)
    if '--check' in sys.argv:
        problems += check_sheet(option('--sheet') or SHEET, states)
        for line in problems:
            print(line)
        print('sewers: %s' % ('FAILED' if problems else 'ok'))
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
