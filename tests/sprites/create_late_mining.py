"""Hand-placed sprites for late gold mining in icons/obj/late_mining.dmi:
the hydraulic monitor (a 19th-century "giant": a long tapering cast iron
nozzle on a gooseneck swivel, a counterweight box of stones on its tail, a
heavy timber sled under it and a riveted iron feed pipe coming in at the base
from behind; four directions in BYOND order S, N, E, W, standing and a
three-frame jetting loop with a thick white-blue jet running to the cell edge),
the stripped bank (an opaque turf of bare washed cobbles and gravel with pale
sand in the rill channels, tiling seamlessly with itself), and the cyanide vat
(a round stave vat with iron hoops on timber bearers, a tap running into a
small zinc box of shavings beside it: empty and dry, and a two-frame leaching
loop full of pale slurry with a drip at the spout and dark gold slime
collecting on the zinc).
Every pixel is placed by this script from a fixed palette (Pillow only); no
external or generated artwork. The timber and field stone are those of
create_clay_lime_fire.py, the iron is that of create_mercury.py, the grit is
that of create_lode.py and the wash water is that of create_milling.py.

Run with Pillow to write the sheet. `--check` rebuilds the sheet and compares
its Description and pixels with the committed file, and verifies that the
stripped bank is opaque, `--preview <png>` writes a labelled 4x review sheet
on grass and on dirt (the monitor in all four directions, every jetting frame
and a 3x3 block of the stripped bank), `--gif <path>` writes the jetting
monitor in its four directions beside the leaching vat.
Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_clay_lime_fire import TIMBER, STONE, grain  # noqa: E402
from create_tatara import Sprite, GRASS, DIRT, ground  # noqa: E402
from create_mercury import IRON, IRON_EDGE  # noqa: E402
from create_lode import GRIT  # noqa: E402
from create_milling import WATER, EDGE, trim, beam  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/late_mining.dmi'

SIZE = 32
JET_FRAMES = 3
JET_DELAY = 1          # deciseconds per frame
LEACH_FRAMES = 2
LEACH_DELAY = 4

BORE = (26, 27, 34)                      # the dark mouth of the nozzle
FOAM = (250, 252, 255)                   # the white core of the jet
MIST = (214, 232, 242, 150)              # a fleck of spray, half clear
# washed gravel: lit, mid, shade, deep
GRAVEL = [(146, 136, 122), (128, 118, 104), (110, 100, 88), (84, 76, 68)]
# cobbles, each lit, mid, shade: grey, brown, blue-grey
COBBLES = (
    [(182, 176, 164), (150, 144, 134), (114, 108, 102)],
    [(172, 154, 132), (142, 124, 104), (106, 92, 78)],
    [(164, 168, 172), (130, 136, 142), (96, 102, 110)],
)
COBBLE_FOOT = (66, 60, 56)               # the shadow under a cobble
RILL_CUT = (96, 86, 76)                  # the cut bank of a rill
# zinc shavings: glint, lit, mid, shade
ZINC = [(176, 188, 200), (142, 156, 172), (112, 126, 144), (84, 96, 114)]
# gold slime on the zinc: lit, mid, deep
SLIME = [(74, 74, 80), (48, 48, 54), (28, 28, 34)]
# the slurry of tailings and solution: sheen, lit, mid, shade
SLURRY = [(230, 224, 184), (210, 202, 158), (188, 180, 138), (160, 152, 118)]
# the dry floor and filter of the empty vat: lit, mid, shade
DRY = [(170, 146, 108), (144, 120, 86), (116, 94, 66)]

# how far the nozzle tip is thrown off line in each jetting frame
KICK = (0, 1, 0)


def flipped(f):
    """Mirror left to right: the west view is the east view turned round."""
    g = Sprite()
    g.px = {(SIZE - 1 - x, y): c for (x, y), c in f.px.items()}
    return g


# ----------------------------------------------------- hydraulic monitor --

def iron_tone(n):
    """Tone across a round iron part, n from -1 (lit side) to 1 (shade)."""
    if n < -0.55:
        return IRON[1]
    if n < -0.1:
        return IRON[0]
    if n < 0.35:
        return IRON[1]
    if n < 0.75:
        return IRON[2]
    return IRON[3]


def ball(f, cx, cy, r):
    """The swivel joint: a cast iron ball lit from the upper left, with the
    seam of its socket round the middle."""
    def shade(x, y, nx, ny):
        light = nx * 0.7 + ny * 0.7
        if light < -0.75:
            return IRON[0]
        if light < -0.1:
            return IRON[1]
        if light < 0.5:
            return IRON[2]
        return IRON[3]
    f.ellipse(cx, cy, r, r, shade)
    f.put(int(cx - r * 0.4), int(cy - r * 0.5), FOAM)             # the glint


def pipe_h(f, x0, x1, y):
    """The riveted feed pipe lying left to right, four rows deep."""
    rows = (IRON[1], IRON[0], IRON[2], IRON[3])
    band = (IRON[0], FOAM, IRON[1], IRON[2])
    for x in range(x0, x1 + 1):
        for k in range(4):
            c = rows[k]
            if x % 4 == 1:
                c = band[k]                           # a riveted lap joint
            elif x % 4 == 2:
                c = IRON[4] if k else IRON[2]
            f.put(x, y + k, c)


def pipe_v(f, x, y0, y1):
    """The feed pipe running up the cell, four columns wide."""
    cols = (IRON[1], IRON[0], IRON[2], IRON[3])
    band = (IRON[0], FOAM, IRON[1], IRON[2])
    for y in range(y0, y1 + 1):
        for k in range(4):
            c = cols[k]
            if y % 4 == 1:
                c = band[k]
            elif y % 4 == 2:
                c = IRON[4] if k else IRON[2]
            f.put(x + k, y, c)


def stones(f, x0, x1, y, seed):
    """Field stones heaped in the counterweight box: a row and a crown."""
    for x in range(x0, x1 + 1):
        g = grain(x, y, seed)
        f.put(x, y, STONE[1] if g < 4 else (STONE[2] if g < 8 else STONE[3]))
        if x0 < x < x1:
            f.put(x, y - 1, STONE[0] if g < 5 else STONE[1])
    f.put(x0 + 1, y, STONE[4])                        # the gaps between them
    f.put(x1 - 2, y, STONE[4])


def box(f, x0, y0, x1, y1, seed):
    """The timber counterweight box, its planks lying along it."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            c = TIMBER[1] if grain(x // 3, y, seed) else TIMBER[2]
            if y == y0:
                c = TIMBER[0]
            elif y == y1:
                c = TIMBER[3]
            elif (y - y0) % 3 == 0:
                c = TIMBER[3]                         # the joint between planks
            if x == x1:
                c = TIMBER[3]
            f.put(x, y, c)
    f.pts(IRON[1], (x0, y0 + 1), (x1, y0 + 1))        # the strap nails
    f.pts(IRON[3], (x0, y1 - 1), (x1, y1 - 1))


def monitor_side(step=None):
    """Facing east: the sled along the foot, the feed pipe coming in low on
    the left, the gooseneck rising to the swivel ball, the barrel tapering
    away up and to the right and the counterweight box on the tail."""
    kick = 0 if step is None else KICK[step]
    f = Sprite()
    # the sled: a deck over a heavy runner, its nose cut back, two bearers
    beam(f, 1, 22, 24, 301, thick=4)
    f.pts(TIMBER[2], (23, 24), (23, 25))
    f.pts(TIMBER[3], (1, 27), (2, 27), (22, 27))
    for x0 in (4, 17):                                # the ends of the bearers
        f.rect(x0, 22, x0 + 2, 23, TIMBER[2])
        f.hline(x0, x0 + 2, 22, TIMBER[0])
        f.put(x0 + 1, 23, TIMBER[4])
    # the feed pipe and the flanged foot of the gooseneck
    pipe_h(f, 0, 7, 19)
    for y in range(18, 24):
        for x in range(8, 14):
            f.put(x, y, iron_tone((x - 10.5) / 3.0))
    f.hline(8, 13, 18, IRON[0])
    f.hline(8, 13, 23, IRON[4])
    f.pts(FOAM, (9, 20), (9, 22))                     # the flange bolts
    f.pts(IRON[4], (12, 20), (12, 22))
    # the riser
    for y in range(13, 18):
        for x in range(9, 13):
            f.put(x, y, iron_tone((x - 10.5) / 2.0))
    f.hline(9, 12, 15, IRON[3])                       # the packing gland
    # the tail lever and its box of stones
    f.hline(5, 8, 11, IRON[2])
    f.hline(5, 8, 10, IRON[0])
    box(f, 0, 10, 5, 15, 303)
    stones(f, 0, 5, 9, 305)
    # the barrel, tapering to the tip
    for x in range(12, 25):
        t = (x - 12) / 12.0
        cy = 10.5 - 2.5 * t + kick * t
        half = 3.0 - 1.9 * t
        for y in range(int(round(cy - half)), int(round(cy + half)) + 1):
            c = iron_tone((y - cy) / (half + 0.5))
            if x in (15, 20):                         # the reinforcing rings
                c = IRON[0] if y < cy else IRON[2]
            elif x in (16, 21):
                c = IRON[4] if y >= cy else IRON[2]
            f.put(x, y, c)
    tip = int(round(8.0 + kick))
    f.vline(24, tip - 1, tip + 1, IRON[0])            # the nozzle ring
    f.put(24, tip, FOAM if step is not None else BORE)
    ball(f, 10.5, 10.5, 3.3)
    trim(f)
    if step is not None:
        for x in range(25, SIZE):
            d = x - 25
            cy = tip - 0.2 * d
            half = 1.0 + 0.32 * d
            for y in range(int(round(cy - half)), int(round(cy + half)) + 1):
                n = abs(y - cy) / (half + 0.5)
                c = FOAM if n < 0.4 else (WATER[0] if n < 0.75 else WATER[1])
                if n >= 0.4 and (x + y * 2 + step) % 3 == 0:
                    c = WATER[1] if c == WATER[0] else WATER[2]     # the streaks
                f.put(x, y, c)
        spray = (((26, tip - 3), (29, tip + 3), (30, tip - 5), (23, tip - 3)),
                 ((27, tip - 4), (28, tip + 3), (31, tip - 5), (23, tip + 3)),
                 ((25, tip - 3), (30, tip + 3), (29, tip - 5), (26, tip + 3)))[step]
        for i, (x, y) in enumerate(spray):
            if (x, y) not in f.px or f.px[(x, y)] in (IRON_EDGE, EDGE):
                f.put(x, y, FOAM if i == 0 else (WATER[0] if i < 3 else MIST))
    return f


def sled_plan(f, y0, y1):
    """The sled seen along its length: two runners with their end faces at
    the foot and two bearers across them."""
    for x0 in (6, 22):
        for y in range(y0, y1 - 2):
            f.put(x0, y, TIMBER[0] if grain(x0, y // 4, 311) else TIMBER[1])
            f.put(x0 + 1, y, TIMBER[1])
            f.put(x0 + 2, y, TIMBER[1] if grain(x0, y // 5, 313) else TIMBER[2])
            f.put(x0 + 3, y, TIMBER[3])
        f.rect(x0, y1 - 2, x0 + 3, y1, TIMBER[2])     # the sawn end
        f.hline(x0, x0 + 3, y1, TIMBER[4])
        f.pts(TIMBER[3], (x0 + 1, y1 - 1), (x0 + 2, y1 - 1))
    beam(f, 5, 26, y0 + 2, 315, thick=3)
    beam(f, 5, 26, y1 - 7, 317, thick=3)


def monitor_front(step=None):
    """Facing south: the nozzle comes down the cell at the viewer, its bore
    open at the tip; the counterweight box stands up behind the swivel and
    the feed pipe comes down the left side and turns in at the base."""
    kick = 0 if step is None else KICK[step]
    f = Sprite()
    sled_plan(f, 9, 22)
    pipe_v(f, 1, 0, 13)                               # the feed pipe from behind
    pipe_h(f, 1, 11, 13)
    f.pts(IRON[0], (1, 13), (2, 13))                  # the elbow
    f.pts(IRON[3], (4, 16), (3, 16))
    # the box on the tail, the lever foreshortened under it
    box(f, 11, 2, 20, 7, 321)
    stones(f, 11, 20, 1, 323)
    f.rect(14, 8, 17, 9, IRON[2])
    f.vline(14, 8, 9, IRON[0])
    f.vline(17, 8, 9, IRON[3])
    # the flanged foot under the ball
    for x in range(10, 22):
        f.put(x, 16, iron_tone((x - 15.5) / 6.0))
        f.put(x, 17, IRON[4] if x % 3 == 1 else IRON[3])
    ball(f, 15.5, 12.5, 4.2)
    # the barrel coming forward
    for y in range(14, 22):
        t = (y - 14) / 7.0
        cx = 15.5 + kick * t
        half = 3.6 - 1.4 * t
        for x in range(int(math.ceil(cx - half)), int(math.floor(cx + half)) + 1):
            c = iron_tone((x - cx) / (half + 0.5))
            if y in (16, 19):
                c = IRON[0] if x < cx else IRON[1]
            elif y in (17, 20):
                c = IRON[4] if x > cx else IRON[3]
            f.put(x, y, c)
    x0 = 14 + kick
    f.hline(x0, x0 + 3, 21, IRON[0])                  # the nozzle ring and bore
    f.hline(x0, x0 + 3, 23, IRON[1])
    f.pts(IRON[0], (x0 - 1, 22), (x0 + 4, 22))
    f.hline(x0, x0 + 3, 22, BORE if step is None else FOAM)
    trim(f)
    if step is not None:
        jet_plan(f, x0 + 1.5, range(23, SIZE), step, 1)
    return f


def monitor_back(step=None):
    """Facing north: the counterweight box nearest the viewer over the feed
    pipe coming in from the foot of the cell, the barrel running away up the
    cell beyond the swivel."""
    kick = 0 if step is None else KICK[step]
    f = Sprite()
    sled_plan(f, 11, 26)
    # the barrel going away, drawn first: the ball and box stand before it
    for y in range(7, 15):
        t = (14 - y) / 7.0
        cx = 15.5 + kick * t
        half = 3.6 - 1.4 * t
        for x in range(int(math.ceil(cx - half)), int(math.floor(cx + half)) + 1):
            c = iron_tone((x - cx) / (half + 0.5))
            if y in (9, 12):
                c = IRON[0] if x < cx else IRON[1]
            elif y in (10, 13):
                c = IRON[4] if x > cx else IRON[3]
            f.put(x, y, c)
    x0 = 14 + kick
    f.hline(x0, x0 + 3, 6, IRON[0])                   # the nozzle ring
    for x in range(10, 22):                           # the flanged foot
        f.put(x, 19, iron_tone((x - 15.5) / 6.0))
        f.put(x, 20, IRON[4] if x % 3 == 1 else IRON[3])
    ball(f, 15.5, 15.5, 4.2)
    pipe_v(f, 14, 24, SIZE - 1)                       # the feed pipe from behind
    f.rect(14, 20, 17, 21, IRON[2])                   # the lever
    f.vline(14, 20, 21, IRON[0])
    box(f, 11, 20, 20, 26, 331)
    stones(f, 11, 20, 19, 333)
    trim(f)
    if step is not None:
        jet_plan(f, x0 + 1.5, range(5, -1, -1), step, -1)
    return f


def jet_plan(f, cx, rows, step, way):
    """The jet running straight up or down the cell from the tip to the
    edge, widening as it goes, with its flecks of spray."""
    first = rows[0]
    for y in rows:
        d = abs(y - first)
        half = 1.6 + 0.3 * d
        for x in range(int(math.ceil(cx - half)), int(math.floor(cx + half)) + 1):
            n = abs(x - cx) / (half + 0.5)
            c = FOAM if n < 0.45 else (WATER[0] if n < 0.75 else WATER[1])
            if n >= 0.45 and (x * 2 + y + step) % 3 == 0:
                c = WATER[1] if c == WATER[0] else WATER[2]
            f.put(x, y, c)
    last = rows[-1]
    cx = int(cx)
    spray = (((cx - 4, first + way), (cx + 5, first + 3 * way), (cx - 5, last), (cx + 4, first)),
             ((cx + 4, first + way), (cx - 4, first + 3 * way), (cx + 6, last), (cx - 4, first)),
             ((cx - 3, first + 2 * way), (cx + 4, first + 2 * way), (cx - 6, last - way),
              (cx + 5, last)))[step]
    for i, (x, y) in enumerate(spray):
        if (x, y) not in f.px or f.px[(x, y)] in (IRON_EDGE, EDGE):
            f.put(x, y, FOAM if i == 0 else (WATER[0] if i < 3 else MIST))


def monitor(step=None):
    """[S, N, E, W] for one frame."""
    east = monitor_side(step)
    return [monitor_front(step), monitor_back(step), east, flipped(east)]


# --------------------------------------------------------- stripped bank --

# the cobbles: (centre x, centre y, half width, half height, kind)
COBBLE_AT = (
    (3.5, 4.0, 2.6, 2.0, 0), (15.0, 2.5, 2.2, 1.6, 1), (29.5, 6.5, 2.4, 2.0, 2),
    (17.5, 9.5, 3.2, 2.4, 0), (2.0, 13.5, 2.0, 1.6, 1), (13.5, 16.5, 2.0, 1.6, 2),
    (29.0, 17.0, 2.8, 2.2, 1), (19.0, 21.0, 2.4, 1.8, 0), (4.0, 22.5, 3.0, 2.2, 2),
    (15.5, 27.5, 2.8, 2.0, 1), (30.5, 27.0, 2.2, 1.8, 0), (20.5, 15.0, 1.6, 1.2, 1),
    (0.5, 30.0, 2.0, 1.4, 0), (18.0, 31.5, 1.8, 1.3, 2), (14.0, 22.0, 1.4, 1.1, 0),
)
# the small pebbles between them
PEBBLE_AT = ((7, 1), (21, 4), (1, 8), (13, 7), (27, 11), (5, 17), (17, 13), (22, 26),
             (2, 26), (14, 12), (28, 22), (20, 29), (5, 29), (31, 13), (16, 19), (30, 1))


def rill(y):
    """The two rill channels on row y: (centre column, half width). Both
    close on themselves over the 32 rows, so the tile joins top to bottom."""
    a = 2.0 * math.pi * y / SIZE
    return ((9.5 + 2.6 * math.sin(a) + 1.0 * math.sin(2 * a + 1.0), 1.4 + 0.5 * math.sin(a + 2.0)),
            (25.0 + 2.2 * math.sin(a + 2.4) + 0.8 * math.sin(3 * a), 1.0 + 0.4 * math.sin(2 * a)))


def stripped_bank():
    """Bare washed gravel: every pixel is drawn modulo the cell, so cobbles
    and rills run on across each edge into the next tile."""
    f = Sprite()
    for y in range(SIZE):
        for x in range(SIZE):
            g = grain(x, y, 341)
            f.put(x, y, GRAVEL[0] if g < 2 else (GRAVEL[2] if g < 5 else
                                                 (GRAVEL[3] if g == 10 else GRAVEL[1])))
    for y in range(SIZE):                             # the rills, pale washed sand
        for cx, half in rill(y):
            lo, hi = int(round(cx - half)), int(round(cx + half))
            f.put((lo - 1) % SIZE, y, RILL_CUT)       # the cut bank, in shade
            for x in range(lo, hi + 1):
                g = grain(x % SIZE, y, 343)
                f.put(x % SIZE, y, GRIT[0] if g < 4 else (GRIT[2] if g == 10 else GRIT[1]))
            f.put((hi + 1) % SIZE, y, GRAVEL[0])      # the lit lip
    for i, (x, y) in enumerate(PEBBLE_AT):
        tones = COBBLES[i % 3]
        f.put(x, y, tones[0])
        f.put((x + 1) % SIZE, y, tones[1])
        f.put((x + 1) % SIZE, (y + 1) % SIZE, COBBLE_FOOT)
    for cx, cy, rx, ry, kind in COBBLE_AT:
        tones = COBBLES[kind]
        inside = []
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                nx, ny = (x - cx) / rx, (y - cy) / ry
                if nx * nx + ny * ny <= 1.0:
                    inside.append((x, y, nx * 0.6 + ny * 0.8))
        for x, y, _ in inside:                        # the shadow, down and right
            f.put((x + 1) % SIZE, (y + 1) % SIZE, COBBLE_FOOT)
        for x, y, light in inside:
            c = tones[0] if light < -0.3 else (tones[1] if light < 0.4 else tones[2])
            f.put(x % SIZE, y % SIZE, c)
    return f


# ----------------------------------------------------------- cyanide vat --

VCX, VCY = 11.5, 8.0               # centre of the vat's mouth
VRX, VRY = 10.5, 4.0               # its half width and half height
VDEEP = 12                         # how far the staves come down
HOOP_ROWS = (2, 3, 8, 9)           # rows of the two iron hoops, below the rim


def stave_tone(x, nx):
    k = 2 if nx < -0.7 else (0 if nx < -0.25 else (1 if nx < 0.3 else (2 if nx < 0.72 else 3)))
    if int(x) % 3 == 0:
        k = min(4, k + 1)                             # the seam between staves
    return k


def cyanide_vat(step=None):
    full = step is not None
    f = Sprite()
    # the bearers it stands on, back and front, in the vat's shadow
    f.rect(1, 19, 22, 27, TIMBER[4])
    beam(f, 1, 22, 19, 351, thick=4)
    beam(f, 1, 22, 24, 353, thick=4)
    for x0 in (1, 19):                                # their sawn ends
        f.rect(x0, 25, x0 + 3, 26, TIMBER[2])
    # the staves and hoops
    for x in range(1, 23):
        nx = (x - VCX) / VRX
        dy = VRY * math.sqrt(max(0.0, 1.0 - nx * nx))
        top = int(round(VCY + dy))
        back = int(round(VCY - dy))
        for y in range(back, top):
            f.put(x, y, TIMBER[0])                    # filled in by the mouth below
        for k in range(VDEEP + 1):
            tone = stave_tone(x, nx)
            c = TIMBER[tone]
            if k in HOOP_ROWS:
                c = iron_tone(nx) if k in (2, 8) else IRON[min(4, IRON.index(iron_tone(nx)) + 1)]
            elif k == VDEEP:
                c = TIMBER[4]
            elif k == 0:
                c = TIMBER[0] if tone < 2 else TIMBER[1]
            f.put(x, top + k, c)
    f.pts(FOAM, (5, 15), (5, 21))                     # the hoop lugs
    # the mouth: the rim of stave ends, the far wall inside, then the floor
    for y in range(int(VCY - VRY), int(VCY + VRY) + 1):
        for x in range(1, 23):
            nx, ny = (x - VCX) / VRX, (y - VCY) / VRY
            if nx * nx + ny * ny > 1.0:
                continue
            ix, iy = (x - VCX) / (VRX - 1.2), (y - VCY) / (VRY - 1.0)
            if ix * ix + iy * iy > 1.0:
                f.put(x, y, TIMBER[0] if (x % 3 or ny > 0) and nx < 0.5 else TIMBER[1])
                continue
            c = TIMBER[4] if x % 3 == 0 else TIMBER[3]              # the far wall
            if full:
                sx, sy = (x - VCX) / (VRX - 1.8), (y - VCY - 0.6) / (VRY - 1.4)
                if sx * sx + sy * sy <= 1.0:
                    g = grain(x + 2 * step, y, 355)
                    c = SLURRY[1] if g < 5 else SLURRY[2]
                    if sy < -0.55:
                        c = SLURRY[3]                 # under the far wall's shade
                    elif (x + 3 * y + 5 * step) % 9 == 0:
                        c = SLURRY[0]                 # the moving sheen
                    elif g == 10:
                        c = SLURRY[3]                 # tailings showing through
            else:
                fx, fy = (x - VCX) / (VRX - 2.4), (y - VCY - 1.4) / (VRY - 2.0)
                if fx * fx + fy * fy <= 1.0:
                    g = grain(x, y, 357)
                    c = DRY[1] if g < 7 else DRY[0]   # the dry filter floor
                    if x % 4 == 2:
                        c = DRY[2]                    # its boards
            f.put(x, y, c)
    # the tap in the vat's side and the spout over the zinc box
    f.hline(22, 27, 15, IRON[0])
    f.hline(22, 27, 16, IRON[3])
    f.pts(IRON[1], (24, 14), (24, 13), (23, 13), (25, 13))          # the tap handle
    f.put(27, 17, IRON[2])
    # the zinc box: a narrow trough of shavings, a divider across it
    f.rect(25, 19, 31, 23, TIMBER[1])
    f.hline(25, 31, 19, TIMBER[0])
    f.hline(25, 31, 23, TIMBER[0])
    f.vline(25, 19, 23, TIMBER[0])
    f.vline(31, 19, 23, TIMBER[2])
    for y in range(24, 27):
        for x in range(25, 32):
            f.put(x, y, TIMBER[3] if y == 26 else (TIMBER[2] if x % 3 == 0 else TIMBER[1]))
    f.pts(TIMBER[3], (25, 27), (26, 27), (30, 27), (31, 27))        # its feet
    for y in range(20, 23):
        for x in range(26, 31):
            g = grain(x, y, 359)
            c = ZINC[0] if g < 2 else (ZINC[1] if g < 6 else (ZINC[2] if g < 9 else ZINC[3]))
            if full and (x < 29 or g < 3):            # slime, thickest under the spout
                h = grain(x + step, y, 361)
                c = SLIME[1] if h < 6 else (SLIME[2] if h < 9 else SLIME[0])
            f.put(x, y, c)
    trim(f)
    if full:                                          # the drip from the spout
        if step == 0:
            f.put(27, 18, SLURRY[0])
        else:
            f.put(27, 19, SLURRY[1])
            f.put(27, 20, SLURRY[0])
            f.pts(SLURRY[0], (26, 21))
    return f


def states():
    """[(state, dirs, frames, delay)] in sheet order; frames is a list of
    frames, each a list of one sprite per direction."""
    return [
        ('hydraulic_monitor', 4, [monitor()], 0),
        ('hydraulic_monitor_jetting', 4, [monitor(i) for i in range(JET_FRAMES)], JET_DELAY),
        ('stripped_bank', 1, [[stripped_bank()]], 0),
        ('cyanide_vat', 1, [[cyanide_vat()]], 0),
        ('cyanide_vat_leaching', 1, [[cyanide_vat(i)] for i in range(LEACH_FRAMES)], LEACH_DELAY),
    ]


# --------------------------------------------------------- sheet in/out --

def build():
    """(image, Description). A DMI stores each frame's directions together:
    frame 1 S, N, E, W, then frame 2 and so on."""
    blocks, cells = [], []
    for name, dirs, frs, delay in states():
        block = 'state = "%s"\n\tdirs = %d\n\tframes = %d\n' % (name, dirs, len(frs))
        if len(frs) > 1:
            block += '\tdelay = %s\n' % ','.join([str(delay)] * len(frs))
        blocks.append(block)
        for fr in frs:
            cells += [d.image() for d in fr]
    cols = int(len(cells) ** 0.5 + 0.999)
    rows = (len(cells) + cols - 1) // cols
    im = Image.new('RGBA', (cols * SIZE, rows * SIZE))
    for i, cell in enumerate(cells):
        im.paste(cell, ((i % cols) * SIZE, (i // cols) * SIZE))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    text += ''.join(blocks) + '# END DMI\n'
    return im, text


def write_dmi():
    im, text = build()
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    im.save(SHEET, 'PNG', pnginfo=meta, optimize=True)


def check():
    """A list of what is wrong; empty when everything matches."""
    wrong = []
    im, text = build()
    if not SHEET.exists():
        wrong.append('missing sheet: %s' % SHEET)
    else:
        old = Image.open(SHEET)
        if old.info.get('Description') != text or old.convert('RGBA').tobytes() != im.tobytes():
            wrong.append('stale sheet: %s' % SHEET)
    bank = stripped_bank()
    if len(bank.px) != SIZE * SIZE or any(len(c) == 4 for c in bank.px.values()):
        wrong.append('stripped_bank does not fill its cell with opaque pixels')
    return wrong


# -------------------------------------------------------------- review --

def backdrop(tones, w, h, scale):
    """Ground under a picture of any size, tiled from the 32x32 patch."""
    patch = ground(tones, scale)
    out = Image.new('RGBA', (w * scale, h * scale))
    for y in range(0, h * scale, SIZE * scale):
        for x in range(0, w * scale, SIZE * scale):
            out.paste(patch, (x, y))
    return out


def tiled(n=3):
    """An n by n block of the stripped bank, to show it joins itself."""
    one = stripped_bank().image()
    out = Image.new('RGBA', (SIZE * n, SIZE * n))
    for j in range(n):
        for i in range(n):
            out.paste(one, (i * SIZE, j * SIZE))
    return out


def preview(path, scale=4):
    """Every frame, labelled, on grass (upper block) and dirt (lower): the
    monitor in its four directions, each jetting frame in four directions,
    the vat, and last the stripped bank tiled 3x3, bare and with the monitors
    at work on it."""
    table = dict((name, frs) for name, _, frs, _ in states())
    ways = 'SNEW'
    lines = [[('hydraulic_monitor %s' % ways[d], table['hydraulic_monitor'][0][d].image())
              for d in range(4)]
             + [('stripped_bank', stripped_bank().image()),
                ('cyanide_vat', table['cyanide_vat'][0][0].image())]]
    for i, fr in enumerate(table['hydraulic_monitor_jetting']):
        line = [('..._jetting %s [%d]' % (ways[d], i + 1), fr[d].image()) for d in range(4)]
        if i < LEACH_FRAMES:
            line.append(('..._vat_leaching [%d]' % (i + 1),
                         table['cyanide_vat_leaching'][i][0].image()))
        lines.append(line)
    block = tiled(3)
    worked = block.copy()
    jets = table['hydraulic_monitor_jetting'][0]
    for d, (cx, cy) in enumerate(((1, 0), (1, 2), (0, 1), (2, 1))):
        worked.alpha_composite(jets[d].image(), (cx * SIZE, cy * SIZE))
    worked.alpha_composite(table['cyanide_vat_leaching'][0][0].image(), (SIZE, SIZE))
    lines.append([('stripped_bank 3x3', block), None, None,
                  ('3x3 with monitors and vat', worked)])
    cols = 6
    pad, label = 8, 14
    cw = SIZE * scale + pad + 24                      # room for the long names
    heights = [max(c[1].size[1] for c in line if c) * scale + label + pad for line in lines]
    high = sum(heights)
    out = Image.new('RGBA', (pad + cols * cw, pad + 2 * high), (24, 24, 24, 255))
    pen = ImageDraw.Draw(out)
    for j, tones in enumerate((GRASS, DIRT)):
        y = pad + j * high
        for line, h in zip(lines, heights):
            for i, cell in enumerate(line):
                if cell is None:
                    continue
                name, im = cell
                x = pad + i * cw
                tile = backdrop(tones, im.size[0], im.size[1], scale)
                tile.alpha_composite(im.resize((im.size[0] * scale, im.size[1] * scale),
                                               Image.NEAREST))
                out.paste(tile, (x, y))
                pen.text((x + 1, y + im.size[1] * scale + 1), name, fill=(230, 230, 230, 255))
            y += h
    out.save(path)


def gif(path, scale=4):
    """The jetting monitor in its four directions and the leaching vat, side
    by side on grass at game speed."""
    table = dict((name, frs) for name, _, frs, _ in states())
    jets, vat = table['hydraulic_monitor_jetting'], table['cyanide_vat_leaching']
    back = ground(GRASS, scale)
    gap = 8
    side = SIZE * scale
    shots = []
    for t in range(JET_FRAMES * LEACH_FRAMES * LEACH_DELAY):      # both loops close
        cells = jets[(t // JET_DELAY) % JET_FRAMES] + vat[(t // LEACH_DELAY) % LEACH_FRAMES]
        sheet = Image.new('RGBA', (gap + len(cells) * (side + gap), side + 2 * gap),
                          (24, 24, 24, 255))
        for i, cell in enumerate(cells):
            tile = back.copy()
            tile.alpha_composite(cell.image().resize((side, side), Image.NEAREST))
            sheet.paste(tile, (gap + i * (side + gap), gap))
        shots.append(sheet.convert('RGB'))
    shots[0].save(path, save_all=True, append_images=shots[1:], duration=JET_DELAY * 100, loop=0)


if __name__ == '__main__':
    if '--check' in sys.argv:
        problems = check()
        if problems:
            sys.exit('\n'.join(problems))
        print('late mining states match')
    else:
        write_dmi()
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
    if '--gif' in sys.argv:
        gif(sys.argv[sys.argv.index('--gif') + 1])
