"""Script-drawn sewer pieces for icons/obj/sewers.dmi.

Every pixel is placed by this script from the fixed palettes below (Pillow
only); no external or generated artwork. The pieces are laid on ground tiles
and are transparent outside the drawn work, so the turf shows through. Light
comes from the upper left, as on the other script-drawn sheets.

States, all 32x32, 1 frame:

  ditch0 .. ditch15              1 dir. An open earth drain ditch: raw earth
                                 banks, a strip of wet mud and a thin line of
                                 murky water with scum in the bottom.
  stone_drain0 .. stone_drain15  1 dir. A covered stone drain: flat dressed
                                 cover slabs with mortar gaps and some wear.
  cesspit0 .. cesspit3           1 dir. A dug pit with a rough plank rim:
                                 empty, a little sludge, half full, and full
                                 to the brim with flies over it.
  outfall                        4 dirs (SOUTH, NORTH, EAST, WEST). The end
                                 of a drain at a river: a few stones and a
                                 dark wet spill fan.

Junction convention. The number after ditch / stone_drain is a bitmask of the
cardinal neighbours the piece connects to, in BYOND dir values:

  NORTH = 1   SOUTH = 2   EAST = 4   WEST = 8

So 3 runs north-south, 12 runs east-west, 5 is the corner joining north and
east, 7 is the tee with no west arm and 15 is the cross. A connected arm runs
to the tile edge with the same cross-section on every piece (the ditch is 12px
wide on columns/rows 10-21, the slabs 14px wide on 9-22, both centred on the
same line as the irrigation channel in icons/turf/trench.dmi), so any run of
tiles reads as one channel. 0 is the piece with no neighbours: ditch0 is a
short isolated trench, stone_drain0 is a single square slab with a slotted
stone grate, used as a street inlet.

Outfall direction convention. The outfall is laid over the last drain tile,
and its dir points from the drain toward the water. Only the water-side half
of the tile is drawn:

  dir     the water is ...     drawn half
  SOUTH   south of the tile    bottom rows
  NORTH   north of the tile    top rows
  EAST    east of the tile     right columns
  WEST    west of the tile     left columns

Run with Pillow to rewrite icons/obj/sewers.dmi (safe to rerun). `--out <dmi>`
writes the sheet somewhere else, `--preview <png>` writes a labelled review
sheet with every state on grass and dirt and a 4x4 layout with loops, tees
and a cross for both drains, `--check` only verifies that the committed sheet
is what this script draws. Released under Civ13 AGPL-3.0.
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


# -------------------------------------------------------------------- sheet

def build():
    """The whole sheet as [(state, keys, images)]."""
    one = {'dirs': '1', 'frames': '1'}
    states = [('ditch%d' % mask, dict(one), [ditch(mask)]) for mask in MASKS]
    states += [('stone_drain%d' % mask, dict(one), [stone_drain(mask)]) for mask in MASKS]
    states += [('cesspit%d' % fill, dict(one), [cesspit(fill)]) for fill in range(4)]
    states.append(('outfall', {'dirs': str(len(DIRS)), 'frames': '1'}, [outfall(name) for name in DIRS]))
    return states


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
    for kind, colours in (('ditch', DITCH_COLOURS), ('stone_drain', STONE_COLOURS)):
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
    for i, name in enumerate(DIRS):
        px = by['outfall'][i].load()
        dry = [(x, y) for y in range(SIZE) for x in range(SIZE)
               if px[x, y][3] and {'SOUTH': y < 16, 'NORTH': y > 15, 'EAST': x < 16, 'WEST': x > 15}[name]]
        if dry:
            problems.append('outfall %s draws on the drain half of the tile' % name)
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
    rows = 5
    high = pad + rows * (cell + label_h + pad) + 4 * cell + label_h + pad
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

    # the layouts, tiles butted together with no gap
    masks = layout_masks()
    top = pad + rows * (cell + label_h + pad)
    scenes = (('ditch on grass', 'ditch', grass), ('ditch on dirt', 'ditch', dirt),
              ('stone_drain on grass', 'stone_drain', grass), ('stone_drain on dirt', 'stone_drain', dirt))
    for n, (label, kind, ground) in enumerate(scenes):
        scene = Image.new('RGBA', (5 * SIZE, 4 * SIZE))
        for ty in range(4):
            for tx in range(5):
                at = (tx * SIZE, ty * SIZE)
                # a river down the right side, fed by an outfall on row 1
                scene.paste(water if tx == 4 else ground, at)
                mask = masks.get((tx, ty))
                if mask is None:
                    continue
                if (tx, ty) == (3, 1):
                    mask |= EAST
                scene.alpha_composite(by['%s%d' % (kind, mask)][0], at)
                if (tx, ty) == (3, 1):
                    scene.alpha_composite(by['outfall'][DIRS.index('EAST')], at)
        x = pad + n * (5 * cell + pad)
        big = scene.convert('RGB').resize((scene.width * scale, scene.height * scale), Image.NEAREST)
        sheet.paste(big, (x, top + label_h))
        draw.text((x, top), label, fill=(220, 220, 220))
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
