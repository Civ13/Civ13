"""Hand-placed 32px strait boom parts for icons/obj/strait_booms.dmi: the
shore winch (`winch`, `winch_broken`) and one tile of the chain boom raised
(`boom`), sunk (`boom_lowered`) and snapped (`boom_broken`).

The winch is a heavy iron-bound drum wound with chain, hung between two
timber cheeks on a stone footing, with a crank on one end of the axle and a
ratchet on the other. It has four directions, in BYOND order south, north,
east, west: the chain leads off the drum to that tile edge, toward the
water. South and north show the drum side on, east and west show it end on
behind an A frame. `winch_broken` has one direction: a cheek snapped, the
drum tipped off its bearings, the chain spilled slack over a cracked footing.

The boom states have four directions: south and north run the chain down the
tile, east and west run it across, and the chain always reaches both tile
edges so neighbouring segments join. Raised, a thick iron chain rides on two
timber log floats at water level, with a little foam along them. Lowered,
only the dark shadow of chain and logs shows under the surface, and the top
of a float or two just breaks it. Broken, the chain comes in from both tile
edges and trails off under water, and the two logs lie askew; north is the
mirror of south and west the mirror of east.

Everything is clear except the winch's stone footing; the boom is drawn to
be read over the deep blue of `seadeep` in icons/turf/beach.dmi.

Palette, outline and light (from the upper left) are those of
create_transmission.py: the same seasoned timber, wrought iron and field
stone, so the winch sits beside the other machines and the berths.

The art is drawn procedurally by this script: every pixel is placed from a
fixed palette (Pillow only); no external or generated artwork. Run it to
reproduce the sheet; `--check` verifies the committed sheet instead of
writing it, `--preview <png>` writes a 4x review sheet (a column per state,
a row per direction, the winch on a shore and the boom on deep water, then
the tile joins). Released under Civ13 AGPL-3.0.
"""
import math
import re
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_transmission import (  # noqa: E402
    Frame, TIMBER, STONE, IRON, GREASE, DIRS4, grain, axis, write_dmi, check)

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/strait_booms.dmi'
BEACH = ROOT / 'icons/turf/beach.dmi'

# the sawn end of a log
CUT = (214, 178, 122, 255)
# rust on chain that lives in salt water
RUST = (124, 82, 58, 255)
# foam where timber breaks the surface: thick, thin
FOAM = [(236, 248, 255, 190), (236, 248, 255, 110)]
# iron and timber seen through deep water: near the surface, deeper, faint
SUNK = [(18, 50, 92, 150), (18, 50, 92, 105), (18, 50, 92, 60)]

# where the boom chain lies: the first of its four rows across the tile
CHAIN_T = 14


def flip(f):
    """The frame mirrored left to right."""
    g = Frame()
    for (x, y), c in f.px.items():
        g.put(31 - x, y, c)
    return g


def transpose_mirror(put):
    """The same `put`, running the other way along the tile."""
    return lambda a, t, c: put(31 - a, t, c)


def chain(put, a0, a1, t, rusty=False):
    """A 3px chain along `a`: flat links with a dark eye, and the links
    between them seen edge on."""
    for a in range(a0, a1 + 1):
        k = a % 4
        if k == 3:
            put(a, t + 1, IRON[1])
            continue
        put(a, t, IRON[0])
        put(a, t + 1, IRON[2] if k == 1 else IRON[1])
        put(a, t + 2, RUST if rusty and grain(a, t, 3) < 3 else IRON[2])


def heavy_chain(put, a0, a1, t=CHAIN_T):
    """The 4px boom chain: big flat links, a rusty underside."""
    for a in range(a0, a1 + 1):
        k = a % 5
        if k >= 3:
            put(a, t + 1, GREASE if k == 3 else IRON[0])
            put(a, t + 2, IRON[1])
            continue
        put(a, t, GREASE if k == 0 else IRON[0])
        put(a, t + 1, IRON[2] if k == 1 else IRON[0])
        put(a, t + 2, IRON[2] if k == 1 else IRON[1])
        put(a, t + 3, RUST if grain(a, 5, 2) < 4 else IRON[2])


def sunk_chain(put, a0, a1, t=CHAIN_T, depth=0):
    """The boom chain as a shadow under the surface."""
    for a in range(a0, a1 + 1):
        k = a % 5
        d = min(2, depth + (1 if k >= 3 else 0))
        if k < 3:
            put(a, t, SUNK[min(2, d + 1)])
            put(a, t + 3, SUNK[min(2, d + 1)])
        put(a, t + 1, SUNK[d])
        put(a, t + 2, SUNK[d])


def bar(put, ca, ct, half_len, half_w, deg, shade):
    """A straight bar turned `deg` about its middle; `shade(u, v)` gives the
    colour from the place along (u) and across (v) it."""
    co, si = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    for a in range(32):
        for t in range(32):
            da, dt = a - ca, t - ct
            u = da * co + dt * si
            v = -da * si + dt * co
            if abs(u) <= half_len and abs(v) <= half_w:
                c = shade(u, v)
                if c:
                    put(a, t, c)


def log_shade(half_len, half_w, seed):
    """A round wet log seen from above: lit along the upper side, sawn ends,
    an iron staple band near each end."""
    def shade(u, v):
        if abs(u) > half_len - 1:
            return CUT if v < 0 else TIMBER[1]
        if half_len - 3.2 < abs(u) <= half_len - 2.2:
            return IRON[0] if v < -half_w + 1.6 else IRON[1] if v < half_w - 1.2 else IRON[2]
        g = grain(int(u + 20) // 3, int(v + 20), seed)
        if v < -half_w + 1.2:
            return TIMBER[0] if g > 2 else TIMBER[1]
        if v < 0:
            return TIMBER[1] if g else TIMBER[2]
        if v < half_w - 1.2:
            return TIMBER[2] if g else TIMBER[3]
        return TIMBER[3] if g > 1 else TIMBER[4]
    return shade


def foam(f, put_xy, points):
    """Foam on the water, never over the boom itself."""
    for (a, t, thick) in points:
        x, y = put_xy(a, t)
        if (x, y) not in f.px and 0 <= x < 32 and 0 <= y < 32:
            f.px[(x, y)] = FOAM[0 if thick else 1]


def xy(vert):
    return (lambda a, t: (t, a)) if vert else (lambda a, t: (a, t))


# ------------------------------------------------------------------- boom

def boom(vert):
    f = Frame()
    put = axis(f, vert)
    for k, ca in enumerate((8.5, 23.5)):
        bar(put, ca, 15.5, 5.5, 4.4, 0, log_shade(5.5, 4.4, 3 + k))
    heavy_chain(put, 0, 31)
    f.outline()
    wash = [(a, 21, grain(a, 2, 4) < 5) for a in range(3, 30) if grain(a, 1, 6) < 6 and not 14 <= a <= 17]
    wash += [(a, 10, False) for a in range(3, 30) if grain(a, 4, 9) < 3 and not 14 <= a <= 17]
    wash += [(1, 21, False), (15, 19, False), (16, 12, False), (30, 22, False), (9, 22, False), (24, 22, False)]
    foam(f, xy(vert), wash)
    return f


def boom_lowered(vert):
    f = Frame()
    put = axis(f, vert)
    for ca in (8.5, 23.5):
        bar(put, ca, 15.5, 5.5, 4.4, 0,
            lambda u, v: None if abs(u) > 4.6 and abs(v) > 3.4 else SUNK[2])
    sunk_chain(put, 0, 31)
    # the back of one float just breaking the surface, and a knot of another
    for a in range(5, 11):
        put(a, 13, TIMBER[2] if grain(a, 3, 1) else TIMBER[1])
    for a in range(6, 10):
        put(a, 12, TIMBER[1])
    put(7, 12, TIMBER[0])
    for a in range(22, 25):
        put(a, 13, TIMBER[3])
    put(23, 12, TIMBER[2])
    foam(f, xy(vert), [(4, 13, False), (11, 13, True), (5, 12, False), (10, 12, False),
                       (7, 11, False), (21, 13, False), (25, 13, True), (23, 11, False)])
    return f


def boom_broken(vert, mirror):
    f = Frame()
    put = axis(f, vert)
    if mirror:
        put = transpose_mirror(put)
    # the near log, swung off the line, still shackled to its chain
    bar(put, 11, 16.5, 5.5, 4.2, 20, log_shade(5.5, 4.2, 5))
    heavy_chain(put, 0, 9)
    # the far log adrift
    bar(put, 22.5, 8, 5.5, 4.0, -38, log_shade(5.5, 4.0, 8))
    # the stub still made fast at the far tile edge
    heavy_chain(put, 28, 31)
    # the parted end trailing off the near log
    for i, (a, t) in enumerate(((16, 19), (17, 20), (18, 21), (18, 22), (19, 23))):
        put(a, t, IRON[0] if i % 2 == 0 else IRON[1])
        put(a + 1, t, IRON[2] if i % 2 == 0 else RUST)
    # a broken link hanging on the far log's staple
    put(19, 11, IRON[1])
    put(19, 12, IRON[0])
    put(18, 13, IRON[1])
    f.outline()
    # what has sunk: both chain ends going down into the dark
    under = f.px.copy()
    f.px = {}
    for i, (a, t) in enumerate(((20, 24), (21, 25), (21, 26), (22, 27), (23, 28), (24, 28), (25, 29))):
        put(a, t, SUNK[min(2, i // 2)])
        put(a + 1, t, SUNK[min(2, 1 + i // 3)])
    for i, (a, t) in enumerate(((27, 17), (26, 18), (26, 19), (25, 20), (25, 21), (24, 22))):
        put(a, t, SUNK[min(2, i // 2)])
        put(a + 1, t, SUNK[min(2, 1 + i // 3)])
    sunk, f.px = f.px, under
    for p, c in sunk.items():
        f.px.setdefault(p, c)
    to_xy = xy(vert)
    if mirror:
        base = to_xy
        to_xy = lambda a, t: base(31 - a, t)        # noqa: E731
    foam(f, to_xy, [(3, 21, False), (5, 22, True), (8, 23, False), (13, 24, False), (15, 11, False),
                    (17, 14, False), (26, 3, False), (28, 5, True), (27, 12, False), (29, 19, False),
                    (16, 2, False), (2, 12, False)])
    return f


# ------------------------------------------------------------------ winch

def footing(f, cracked=False):
    """A dressed stone slab: its top face, and the front face below it."""
    f.rect(2, 20, 29, 26, STONE[1])
    f.hline(2, 29, 20, STONE[0])
    f.vline(2, 20, 26, STONE[0])
    f.rect(2, 27, 29, 30, STONE[2])
    f.hline(2, 29, 27, STONE[3])
    f.hline(2, 29, 30, STONE[4])
    f.vline(29, 21, 30, STONE[3])
    for x in (10, 20):                              # joints in the top face
        f.vline(x, 21, 26, STONE[2])
    f.hline(3, 28, 23, STONE[2])
    for x in (6, 15, 24):                           # and in the front
        f.vline(x, 28, 29, STONE[4])
    for x in range(3, 29):
        g = grain(x, 7, 12)
        if g < 2:
            f.put(x, 25 if x % 2 else 22, STONE[0])
        elif g == 2:
            f.put(x, 28, STONE[3])
    if cracked:
        for p in ((17, 20), (17, 21), (18, 22), (18, 23), (17, 24), (16, 25), (16, 26),
                  (16, 27), (15, 28), (15, 29), (14, 30)):
            f.put(p[0], p[1], STONE[4])
        f.pts(STONE[3], (19, 22), (15, 24), (17, 27))
        f.pts(STONE[4], (26, 21), (27, 21), (27, 22))          # a spalled corner


def cheek(f, x0, top=6, bottom=23):
    """One timber cheek of the frame, its sill and the iron bearing strap."""
    f.vline(x0, top, bottom, TIMBER[0])
    f.vline(x0 + 1, top, bottom, TIMBER[1])
    f.vline(x0 + 2, top, bottom, TIMBER[2])
    f.vline(x0 + 3, top, bottom, TIMBER[4])
    for y in range(top + 1, bottom):
        if grain(x0, y // 3, 4) == 0:
            f.put(x0 + 1, y, TIMBER[2])
    f.rect(x0 - 1, bottom + 1, x0 + 4, bottom + 2, TIMBER[3])
    f.hline(x0 - 1, x0 + 4, bottom + 1, TIMBER[1])
    f.put(x0 + 4, bottom + 2, TIMBER[4])


def wound_drum(f, x0, x1, y0, y1):
    """The drum side on, chain wound round it turn beside turn, between two
    iron flanges."""
    rows = y1 - y0
    for x in range(x0 + 2, x1 - 1):
        for y in range(y0, y1 + 1):
            r = (y - y0) / rows
            band = 0 if r < 0.25 else 1 if r < 0.7 else 2
            link = (y + (x - x0) // 3) % 2
            if (x - x0) % 3 == 1:
                c = IRON[2] if band else IRON[1]             # between two turns
            elif band == 0:
                c = GREASE if link else IRON[0]
            elif band == 1:
                c = IRON[0] if link else IRON[1]
            else:
                c = IRON[1] if link else IRON[2]
            f.put(x, y, c)
        if grain(x, 3, 8) < 2:
            f.put(x, y1 - 1, RUST)
    for x, lit in ((x0, True), (x1 - 1, False)):
        f.vline(x, y0 - 1, y1 + 1, IRON[0] if lit else IRON[1])
        f.vline(x + 1, y0 - 1, y1 + 1, IRON[1] if lit else IRON[2])
        f.put(x, y0 - 1, GREASE)


def winch_side_on(lead):
    """The winch seen along the lead of the chain; `lead` is 'south' (the
    chain comes off the front of the drum to the bottom tile edge) or 'north'
    (it goes off the back to the top edge)."""
    f = Frame()
    put = axis(f, True)
    footing(f)
    if lead == 'north':
        chain(put, 0, 8, 14, rusty=True)
    # tie beam across the back of the cheeks
    f.hline(4, 26, 6, TIMBER[1])
    f.hline(4, 26, 7, TIMBER[3])
    wound_drum(f, 8, 22, 9, 19)
    cheek(f, 4)
    cheek(f, 23)
    for x0 in (4, 23):                                  # bearing straps
        f.rect(x0, 13, x0 + 3, 15, IRON[1])
        f.hline(x0, x0 + 3, 13, IRON[0])
        f.put(x0 + 3, 15, IRON[2])
        f.put(x0 + 1, 14, GREASE)
    # the ratchet wheel and its pawl on the left end of the axle
    f.rect(1, 12, 2, 16, IRON[1])
    f.pts(IRON[0], (1, 12), (1, 14), (1, 16))
    f.pts(IRON[2], (2, 13), (2, 15))
    f.pts(IRON[1], (2, 10), (3, 11))
    # the crank on the right: axle stub, arm, a turned wooden grip
    f.hline(27, 28, 14, IRON[1])
    f.vline(28, 7, 14, IRON[0])
    f.put(28, 14, GREASE)
    f.hline(28, 30, 6, TIMBER[0])
    f.hline(28, 30, 7, TIMBER[3])
    if lead == 'south':
        chain(put, 20, 31, 14, rusty=True)
    f.outline()
    return f


def winch_end_on():
    """The winch seen from the side, the chain leading off to the right
    (east) tile edge."""
    f = Frame()
    footing(f)
    cx, cy, r = 13, 13, 7
    # the wound chain showing past the flange, and the chain leading off the
    # top of the drum down to the water's edge
    pts = f.line(cx + 3, cy - 7, 31, 15, IRON[0])
    for i, (x, y) in enumerate(pts):
        f.put(x, y, GREASE if i % 4 == 0 else IRON[0] if i % 4 < 3 else IRON[1])
        f.put(x, y + 1, IRON[2] if i % 4 == 1 else IRON[1] if i % 4 < 3 else RUST)
    # the far cheek's leg, in shade
    f.line(cx, cy, cx + 9, 23, TIMBER[4])
    # the flange: an iron-rimmed disc, the timber drum end inside it
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            d = math.hypot(x - cx, y - cy)
            if d > r + 0.3:
                continue
            if d > r - 1.3:
                c = IRON[0] if (x - cx) + (y - cy) < -3 else IRON[2] if (x - cx) + (y - cy) > 5 else IRON[1]
            elif d > r - 2.6:
                c = IRON[2] if (x + y) % 2 else IRON[1]          # chain turns
            else:
                c = TIMBER[1] if (x - cx) + (y - cy) < 0 else TIMBER[2]
            f.put(x, y, c)
    for k in range(4):                                   # the drum's cross arms
        a = math.radians(45 + 90 * k)
        f.line(cx, cy, round(cx + 3.6 * math.cos(a)), round(cy + 3.6 * math.sin(a)), TIMBER[3])
    # the near cheek: an A frame on its sill, the axle in an iron bearing
    for dx in (-1, 1):
        for x, y in f.line(cx - 1, cy + 1, cx - 1 + dx * 8, 23, TIMBER[0 if dx < 0 else 1]):
            f.put(x + 1, y, TIMBER[2])
            f.put(x + 2, y, TIMBER[4])
    f.rect(3, 23, 24, 25, TIMBER[2])
    f.hline(3, 24, 23, TIMBER[0])
    f.hline(3, 24, 25, TIMBER[4])
    for x in range(4, 24):
        if grain(x // 3, 6, 2) == 0:
            f.put(x, 24, TIMBER[3])
    f.pts(IRON[1], (5, 24), (22, 24))                    # holding-down bolts
    f.rect(cx - 1, cy - 1, cx + 1, cy + 1, IRON[1])
    f.hline(cx - 1, cx + 1, cy - 1, IRON[0])
    f.put(cx, cy, GREASE)
    # the crank arm and its grip, end on
    f.line(cx, cy, cx - 5, cy - 6, IRON[0])
    f.line(cx + 1, cy, cx - 4, cy - 6, IRON[1])
    f.rect(cx - 6, cy - 8, cx - 4, cy - 6, TIMBER[1])
    f.pts(TIMBER[0], (cx - 6, cy - 8), (cx - 5, cy - 8))
    f.put(cx - 4, cy - 6, TIMBER[3])
    # the pawl resting on the rim
    f.pts(IRON[1], (cx + 6, cy + 5), (cx + 7, cy + 6), (cx + 8, cy + 7))
    f.outline()
    return f


def winch_broken():
    f = Frame()
    footing(f, cracked=True)
    # the left cheek still stands, splintered short
    cheek(f, 4, top=11)
    f.pts(TIMBER[0], (4, 9), (4, 10), (6, 10))
    f.pts(TIMBER[2], (5, 10))
    # the right cheek snapped off at the sill, lying across the footing
    f.rect(23, 21, 26, 23, TIMBER[2])
    f.hline(23, 26, 21, CUT)
    f.pts(TIMBER[4], (24, 21), (26, 22))
    put = axis(f, False)
    bar(put, 22, 26.5, 7, 1.6, 9,
        lambda u, v: CUT if u < -6 else TIMBER[1] if v < -0.5 else TIMBER[3] if v > 0.8 else TIMBER[2])
    # the drum tipped out of its bearings, the turns of chain gone slack
    def drum(u, v):
        if abs(u) > 6.2:
            return IRON[0] if v < -1 else IRON[1] if v < 3 else IRON[2]
        k = int(u + 20) % 3
        if v < -2.6:
            return TIMBER[0] if k else TIMBER[1]
        if abs(u) < 3.5 and v < 2:
            return TIMBER[1] if k else TIMBER[2]             # bare where it ran off
        if k == 1:
            return IRON[2]
        return IRON[0] if v < 0 else IRON[1] if v < 2.6 else IRON[2]
    bar(put, 14.5, 15.5, 7.4, 4.6, -22, drum)
    f.pts(RUST, (10, 20), (13, 19), (19, 15))
    # the bent crank
    f.pts(IRON[0], (22, 9), (23, 8), (24, 8), (25, 9))
    f.pts(IRON[1], (25, 10), (26, 11))
    f.pts(TIMBER[1], (26, 12), (27, 12))
    # the chain spilled in a slack heap down the front
    heap = ((8, 22), (9, 23), (10, 24), (11, 25), (12, 25), (13, 24), (14, 23), (15, 24),
            (10, 26), (11, 27), (12, 27), (13, 26), (9, 25), (8, 24), (7, 25), (7, 26),
            (8, 27), (9, 28), (10, 29), (11, 29), (12, 28), (13, 29), (14, 30), (15, 31), (16, 31))
    for i, (x, y) in enumerate(heap):
        f.put(x, y, (IRON[0], IRON[1], IRON[2], IRON[1])[i % 4])
        if i % 5 == 2:
            f.put(x + 1, y, RUST)
    f.pts(GREASE, (10, 24), (13, 24), (8, 27))
    f.outline()
    return f


def states():
    """state -> frames in BYOND direction order (south, north, east, west)."""
    east = winch_end_on()
    return {
        'winch': [winch_side_on('south'), winch_side_on('north'), east, flip(east)],
        'winch_broken': [winch_broken()],
        'boom': [boom(v) for v in DIRS4],
        'boom_lowered': [boom_lowered(v) for v in DIRS4],
        'boom_broken': [boom_broken(v, m) for v, m in zip(DIRS4, (False, True, False, True))],
    }


def water_tile():
    """The first frame of `seadeep`, or flat deep blue if it is not there."""
    flat = Image.new('RGBA', (32, 32), (66, 132, 181, 255))
    try:
        im = Image.open(BEACH)
        text = im.info.get('Description', '')
        i = 0
        for name, dirs, frames in re.findall(r'state = "(.*?)"\n\tdirs = (\d+)\n\tframes = (\d+)', text):
            if name == 'seadeep':
                per_row = im.size[0] // 32
                x, y = (i % per_row) * 32, (i // per_row) * 32
                return im.convert('RGBA').crop((x, y, x + 32, y + 32))
            i += int(dirs) * int(frames)
    except OSError:
        pass
    return flat


def preview(path, st, scale=4):
    """A column per state, a row per direction (south, north, east, west),
    the winch on sand and the boom on deep water; beneath, at 4x, the winch
    beside boom tiles each way to show the joins, and every frame at true
    size."""
    sand = Image.new('RGBA', (32, 32), (214, 196, 150, 255))
    water = water_tile()
    pad = 6
    cell = 32 * scale

    def on(ground, fr):
        tile = ground.copy()
        tile.alpha_composite(fr.image())
        return tile

    def ground(name):
        return sand if name.startswith('winch') else water

    rows = 4
    join_y = pad + rows * (cell + pad)
    sheet = Image.new('RGBA', (pad + len(st) * (cell + pad), join_y + cell * 3 + pad + 32 + pad),
                      (40, 44, 52, 255))
    for i, (name, group) in enumerate(st.items()):
        for j, fr in enumerate(group):
            sheet.paste(on(ground(name), fr).resize((cell, cell), Image.NEAREST),
                        (pad + i * (cell + pad), pad + j * (cell + pad)))
    # joins: winch east, boom, lowered, broken in a row; winch south over a boom
    strip = Image.new('RGBA', (32 * 4, 32))
    for k, (name, d) in enumerate((('winch', 2), ('boom', 2), ('boom', 3), ('boom_broken', 2))):
        strip.paste(on(ground(name), st[name][d]), (32 * k, 0))
    sheet.paste(strip.resize((strip.width * scale, cell), Image.NEAREST), (pad, join_y))
    col = Image.new('RGBA', (32, 32 * 3))
    for k, (name, d) in enumerate((('winch', 0), ('boom', 0), ('boom_lowered', 1))):
        col.paste(on(ground(name), st[name][d]), (0, 32 * k))
    sheet.paste(col.resize((cell, cell * 3), Image.NEAREST), (pad + 4 * cell + pad, join_y))
    x = pad
    for name, group in st.items():
        for fr in group:
            sheet.paste(on(ground(name), fr), (x, join_y + cell * 3 + pad))
            x += 32 + 2
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


if __name__ == '__main__':
    st = states()
    if '--check' in sys.argv:
        check(SHEET, st)
    else:
        write_dmi(SHEET, st)
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1], st)
