"""Hand-placed sprites for the earthworking tools between the shovel and the
steam shovel: the mattock, the wheelbarrow with its dirt and sand loads, the
horse-drawn slip scraper and the black-powder blasting charge. Every pixel is
placed by this script from a fixed palette (Pillow only); no external or
generated artwork. Lit from the upper left, in a dark outline.

    python3 tests/sprites/create_earthworking_tools.py [--check] [--preview sheet.png]

It writes three sheets:

  icons/obj/earthworking_tools.dmi
      mattock                  pick-mattock, iron grey head on a wooden haft
      wheelbarrow              4 dirs, empty tray; the wheel leads (dir is the
                               way it is pushed) and the handles trail
      wheelbarrow_dirt, wheelbarrow_sand, wheelbarrow_dirt_full,
      wheelbarrow_sand_full    4 dirs, only the load, laid over the barrow
      slip_scraper, slip_scraper_loaded
                               4 dirs; the hitch bail leads, the handles trail
      blasting_charge          powder keg with a cord fuse
      blasting_charge_lit      the same with the fuse burning (4 frames, 2 ds)
  icons/mob/items/lefthand_earthworking.dmi, righthand_earthworking.dmi
      mattock, blasting_charge held, 4 dirs, placed like the pickaxe and
      shovel in lefthand_weapons.dmi / righthand_weapons.dmi

`--check` writes nothing and fails when a committed sheet differs from what
this script draws. `--preview <png>` writes an enlarged review sheet of every
state and direction. Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_clay_lime_fire import Frame, OUT, TIMBER, IRON, FIRE, SMOKE, grain  # noqa: E402
from create_machine_shop import STEEL  # noqa: E402
from create_mechanical_power import line  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/earthworking_tools.dmi'
LEFT = ROOT / 'icons/mob/items/lefthand_earthworking.dmi'
RIGHT = ROOT / 'icons/mob/items/righthand_earthworking.dmi'

# neutral iron grey for the mattock head: glint, light, mid, shade
GREY = [(204, 208, 214), (160, 164, 172), (118, 122, 132), (80, 84, 94)]
# dug earth and loose sand: glint, light, mid, shade
DIRT = [(140, 108, 80), (108, 80, 58), (84, 60, 44), (60, 44, 34)]
SAND = [(240, 226, 178), (220, 200, 146), (192, 170, 116), (156, 134, 90)]
# hemp cord fuse
CORD = [(222, 206, 160), (170, 150, 108)]
SPARK = (255, 250, 214)

# BYOND's order for a four-direction state
DIRS = ('south', 'north', 'east', 'west')


def mirror(f):
    """The same frame flipped left to right."""
    g = Frame()
    for (x, y), c in f.px.items():
        g.put(31 - x, y, c)
    return g


def moved(f, dx, dy):
    g = Frame()
    for (x, y), c in f.px.items():
        g.put(x + dx, y + dy, c)
    return g


def shaft(f, x0, y0, x1, y1, lit=TIMBER[1], dark=TIMBER[3]):
    """A two-pixel wooden handle: lit on its left, dark on its right."""
    line(f, x0, y0, x1, y1, lit)
    line(f, x0 + 1, y0, x1 + 1, y1, dark)


# ------------------------------------------------------------------ mattock --

def mattock():
    """A long haft from lower left to upper right with the head set across its
    top: the broad adze blade to the upper left, the pick to the lower right,
    both curving back toward the hands."""
    f = Frame()
    cx, cy = 22.0, 10.0
    k = math.sqrt(0.5)
    for y in range(32):
        for x in range(32):
            # along the haft from its foot, and across it
            along = (x - 5.0) * k - (y - 27.0) * k
            across = (x - 5.0) * k + (y - 27.0) * k
            if 0 <= along <= 25.0 and abs(across) <= 0.9:
                f.put(x, y, TIMBER[1] if across < 0 else TIMBER[3])
    for y in range(32):
        for x in range(32):
            u = (x - cx) * k + (y - cy) * k         # along the head, pick positive
            v = (x - cx) * k - (y - cy) * k         # past the end of the haft
            off = v + 0.035 * u * u                 # the arms curve back
            if 0 <= u <= 10.5:
                half = 1.5 - u * 0.115
                if abs(off) <= half:
                    f.put(x, y, GREY[0] if u > 9.2 else GREY[1] if off > 0 else GREY[2])
            elif -8.0 <= u < 0:
                half = 1.3 + -u * 0.3
                if abs(off) <= half:
                    f.put(x, y, GREY[0] if u < -6.9 else GREY[1] if off > 0 else GREY[2])
            if abs(u) <= 1.6 and abs(v) <= 2.0:
                f.put(x, y, GREY[3] if abs(u) < 0.8 else GREY[2])    # the eye
    f.outline()
    return f


# -------------------------------------------------------------- wheelbarrow --
# The tray opening is the same box seen from the front and from behind, so one
# load drawing serves both. From the side the opening is a two-row band.

TRAY_X0, TRAY_X1, TRAY_Y0, TRAY_Y1 = 8, 23, 10, 16      # opening, front and rear views
SIDE_X0, SIDE_X1, SIDE_Y0, SIDE_Y1 = 8, 23, 8, 9        # opening, side views


def barrow_wheel_end(f, y0, y1):
    """The wheel seen edge on: an iron tyre on a wooden felloe."""
    f.rect(14, y0, 17, y1, IRON[1])
    f.vline(14, y0, y1, IRON[0])
    f.vline(17, y0, y1, IRON[2])
    f.vline(15, y0 + 1, y1 - 1, TIMBER[3])


def barrow_tray(f, face_dark):
    """The tray from above with the wall nearest the viewer below it."""
    # rim
    f.rect(7, 9, 24, 17, TIMBER[1])
    f.hline(7, 24, 9, TIMBER[0])
    f.vline(7, 9, 17, TIMBER[0])
    f.vline(24, 9, 17, TIMBER[2])
    f.hline(7, 24, 17, TIMBER[0])
    # floor planks, in the shadow of the back and left walls
    for y in range(TRAY_Y0, TRAY_Y1 + 1):
        for x in range(TRAY_X0, TRAY_X1 + 1):
            c = TIMBER[3]
            if y == TRAY_Y0 or x == TRAY_X0:
                c = TIMBER[4]
            elif x in (12, 16, 20):
                c = TIMBER[4]
            f.put(x, y, c)
    # the near wall leans in toward the foot of the tray
    for i, y in enumerate(range(18, 22)):
        inset = (0, 0, 1, 2)[i]
        f.hline(7 + inset, 24 - inset, y, TIMBER[2 if not face_dark else 3])
        f.put(7 + inset, y, TIMBER[1 if not face_dark else 2])
        f.put(24 - inset, y, TIMBER[3 if not face_dark else 4])
    f.hline(9, 22, 21, TIMBER[4])


def barrow_south():
    """Pushed toward the viewer: wheel below, handles away at the top."""
    f = Frame()
    shaft(f, 8, 3, 9, 8)
    shaft(f, 22, 3, 21, 8)
    f.pts(TIMBER[0], (8, 3), (22, 3))
    # rear legs show either side under the tray
    f.rect(8, 21, 8, 25, TIMBER[3])
    f.rect(23, 21, 23, 25, TIMBER[4])
    barrow_tray(f, False)
    # wheel forks and wheel
    f.pts(TIMBER[4], (12, 22), (13, 23), (19, 22), (18, 23))
    barrow_wheel_end(f, 22, 28)
    f.hline(13, 18, 24, IRON[2])
    f.hline(14, 17, 24, IRON[0])
    f.outline()
    return f


def barrow_north():
    """Pushed away from the viewer: wheel above, handles and legs below."""
    f = Frame()
    barrow_wheel_end(f, 3, 9)
    f.pts(TIMBER[4], (12, 8), (13, 7), (19, 8), (18, 7))
    barrow_tray(f, True)
    # legs under the rear of the tray
    f.rect(10, 22, 11, 26, TIMBER[3])
    f.vline(10, 22, 26, TIMBER[2])
    f.rect(20, 22, 21, 26, TIMBER[4])
    f.vline(20, 22, 26, TIMBER[3])
    # handles run back toward the viewer and spread
    shaft(f, 7, 19, 5, 29)
    shaft(f, 24, 19, 26, 29)
    f.pts(TIMBER[0], (5, 28), (5, 29), (26, 28), (26, 29))
    f.outline()
    return f


def side_top(x):
    """Top row of the near side wall of the tray at column x (side view)."""
    return 10


def barrow_east():
    """Side on, wheel to the right and handles to the left."""
    f = Frame()
    # far rim and the opening
    f.hline(SIDE_X0, SIDE_X1, 7, TIMBER[2])
    f.rect(SIDE_X0, SIDE_Y0, SIDE_X1, SIDE_Y1, TIMBER[4])
    f.hline(SIDE_X0 + 1, SIDE_X1, SIDE_Y1, TIMBER[3])
    # near side wall: deep at the back, raked forward to the nose
    for y in range(10, 20):
        t = y - 10
        x0 = 7 + t // 3
        x1 = 24 - (t * 5) // 9
        f.hline(x0, x1, y, TIMBER[2])
        f.put(x0, y, TIMBER[1])
        f.put(x1, y, TIMBER[3])
    f.hline(7, 24, 10, TIMBER[0])
    f.hline(8, 23, 11, TIMBER[1])
    f.hline(10, 19, 19, TIMBER[3])
    f.vline(14, 12, 18, TIMBER[3])          # a batten
    # handle, trailing back and up to the grip
    f.hline(1, 7, 13, TIMBER[3])
    f.hline(1, 7, 12, TIMBER[1])
    f.pts(TIMBER[0], (1, 11), (2, 11))
    f.pts(TIMBER[1], (1, 12))
    # the frame runs under the tray to the axle
    line(f, 10, 20, 22, 22, TIMBER[3])
    line(f, 11, 20, 22, 21, TIMBER[4])
    # leg and brace
    f.rect(9, 20, 10, 27, TIMBER[3])
    f.vline(9, 20, 27, TIMBER[2])
    f.pts(TIMBER[4], (11, 21), (12, 21), (11, 22))
    # wheel
    wx, wy = 23, 23
    for y in range(wy - 4, wy + 5):
        for x in range(wx - 4, wx + 5):
            d = math.hypot(x - wx, y - wy)
            if d <= 4.4:
                if d > 3.1:
                    c = IRON[0] if y < wy - 1 else IRON[2] if y > wy + 1 else IRON[1]
                elif x == wx or y == wy:
                    c = TIMBER[1]
                else:
                    c = TIMBER[4]
                f.put(x, y, c)
    f.put(wx, wy, IRON[0])
    f.outline()
    return f


def heap_shade(ramp, x, y, nx, ny, seed):
    """Loose earth: lit toward the upper left, with a fixed speckle."""
    lightness = -(nx * 0.6 + ny * 0.8)
    g = grain(x, y, seed)
    if lightness > 0.45:
        return ramp[0] if g > 2 else ramp[1]
    if lightness > -0.1:
        return ramp[1] if g > 2 else ramp[0] if g == 0 else ramp[2]
    if lightness > -0.6:
        return ramp[2] if g > 1 else ramp[3]
    return ramp[3] if g > 3 else ramp[2]


def load_plan(ramp, full):
    """A load seen from above (front and rear views of the barrow)."""
    f = Frame()
    if full:
        # heaped over the whole opening and up above the far rim
        cx, cy, rx, ry = 15.5, 12.0, 8.6, 6.4
        for y in range(5, TRAY_Y1 + 1):
            for x in range(TRAY_X0, TRAY_X1 + 1):
                nx, ny = (x - cx) / rx, (y - cy) / ry
                if (TRAY_Y0 <= y) or nx * nx + ny * ny <= 1.0:
                    f.put(x, y, heap_shade(ramp, x, y, nx, max(-1.0, min(1.0, ny)), 5))
    else:
        # a low layer on the floor, clear of the walls
        cx, cy, rx, ry = 15.5, 13.5, 7.4, 3.4
        for y in range(TRAY_Y0 + 1, TRAY_Y1 + 1):
            for x in range(TRAY_X0 + 1, TRAY_X1):
                nx, ny = (x - cx) / rx, (y - cy) / ry
                if nx * nx + ny * ny <= 1.25:
                    f.put(x, y, heap_shade(ramp, x, y, nx * 0.7, ny * 0.5 + 0.25, 9))
    return f


def load_side(ramp, full):
    """A load seen from the side: it shows in the opening and above it."""
    f = Frame()
    if full:
        cx, cy, rx, ry = 15.5, 9.6, 7.6, 6.2
        for y in range(3, SIDE_Y1 + 1):
            for x in range(SIDE_X0, SIDE_X1 + 1):
                nx, ny = (x - cx) / rx, (y - cy) / ry
                if y >= SIDE_Y0 or nx * nx + ny * ny <= 1.0:
                    f.put(x, y, heap_shade(ramp, x, y, nx, ny, 5))
    else:
        for y in range(SIDE_Y0, SIDE_Y1 + 1):
            for x in range(SIDE_X0 + 1, SIDE_X1):
                f.put(x, y, heap_shade(ramp, x, y, (x - 15.5) / 8.0 * 0.7, 0.2 if y == SIDE_Y0 else 0.7, 9))
    return f


def edge_outside(load, under):
    """Outline the part of a load that stands clear of the thing under it."""
    edge = set()
    for (x, y) in load.px:
        for p in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if p not in load.px and p not in under.px:
                edge.add(p)
    for x, y in edge:
        load.put(x, y, OUT)
    return load


def barrow_dirs():
    east = barrow_east()
    return [barrow_south(), barrow_north(), east, mirror(east)]


def barrow_load_dirs(ramp, full):
    under = barrow_dirs()
    plan, side = load_plan(ramp, full), load_side(ramp, full)
    out = [Frame(), Frame(), Frame(), mirror(side)]
    out[0].px.update(plan.px)
    out[1].px.update(plan.px)
    out[2].px.update(side.px)
    return [edge_outside(f, u) for f, u in zip(out, under)]


# ------------------------------------------------------------- slip scraper --

def scoop_floor(f, y0, y1):
    """The inside of the steel scoop seen from above."""
    for y in range(y0, y1 + 1):
        for x in range(9, 23):
            c = IRON[1]
            if x == 9 or (x + y) % 7 == 0:
                c = IRON[2]
            f.put(x, y, c)


def chain(f, pts):
    for i, (x, y) in enumerate(pts):
        f.put(x, y, STEEL[1] if i % 2 == 0 else IRON[1])


def scraper_south(loaded):
    """Drawn toward the viewer: bail and chain below, handles away at the top."""
    f = Frame()
    shaft(f, 10, 2, 11, 10)
    shaft(f, 21, 2, 20, 10)
    f.pts(TIMBER[0], (10, 2), (21, 2))
    scoop_floor(f, 13, 21)
    f.hline(9, 22, 13, IRON[2])             # shadow of the back
    f.hline(9, 22, 14, IRON[2])
    # back wall, rolled over at the top
    f.hline(8, 23, 10, STEEL[0])
    f.hline(7, 24, 11, STEEL[1])
    f.hline(7, 24, 12, STEEL[2])
    # side walls, lower toward the cutting edge
    f.rect(7, 12, 8, 21, STEEL[1])
    f.vline(7, 12, 21, STEEL[0])
    f.rect(23, 12, 24, 21, STEEL[2])
    f.vline(23, 12, 21, STEEL[1])
    # cutting edge
    f.hline(8, 23, 22, STEEL[0])
    f.hline(9, 22, 23, STEEL[2])
    if loaded:
        cx, cy, rx, ry = 15.5, 15.5, 7.2, 6.2
        for y in range(9, 22):
            for x in range(9, 23):
                nx, ny = (x - cx) / rx, (y - cy) / ry
                if nx * nx + ny * ny <= 1.0:
                    f.put(x, y, heap_shade(DIRT, x, y, nx, ny, 3))
        f.pts(DIRT[2], (11, 21), (14, 22), (19, 21))
    # bail and chain
    line(f, 7, 20, 14, 27, IRON[1])
    line(f, 24, 20, 17, 27, IRON[2])
    f.pts(STEEL[0], (7, 19), (24, 19))
    f.hline(14, 17, 28, IRON[1])
    chain(f, ((15, 29), (16, 29), (15, 30), (16, 30)))
    f.outline()
    return f


def scraper_north(loaded):
    """Drawn away from the viewer: bail above, the curved back and handles below."""
    f = Frame()
    # bail and chain
    line(f, 7, 13, 14, 5, IRON[1])
    line(f, 24, 13, 17, 5, IRON[2])
    f.hline(14, 17, 4, IRON[1])
    chain(f, ((15, 3), (16, 3), (15, 2), (16, 2)))
    # cutting edge
    f.hline(9, 22, 10, STEEL[2])
    f.hline(8, 23, 11, STEEL[0])
    scoop_floor(f, 12, 17)
    f.rect(7, 12, 8, 18, STEEL[1])
    f.vline(7, 12, 18, STEEL[0])
    f.rect(23, 12, 24, 18, STEEL[2])
    f.vline(23, 12, 18, STEEL[1])
    f.pts(STEEL[0], (7, 14), (24, 14))
    if loaded:
        cx, cy, rx, ry = 15.5, 13.5, 7.2, 5.6
        for y in range(8, 18):
            for x in range(9, 23):
                nx, ny = (x - cx) / rx, (y - cy) / ry
                if nx * nx + ny * ny <= 1.0 or (y >= 16 and 10 <= x <= 21):
                    f.put(x, y, heap_shade(DIRT, x, y, nx, max(-1.0, min(1.0, ny)), 3))
    # the back of the scoop, curving under
    f.hline(7, 24, 18, STEEL[0])
    f.hline(7, 24, 19, STEEL[1])
    f.hline(7, 24, 20, STEEL[1])
    f.hline(7, 24, 21, STEEL[2])
    f.hline(8, 23, 22, IRON[1])
    f.hline(9, 22, 23, IRON[2])
    f.pts(STEEL[0], (7, 19), (7, 20))
    f.pts(IRON[1], (24, 20), (24, 21))
    # handles bolted to the back, coming toward the viewer
    shaft(f, 10, 20, 9, 30)
    shaft(f, 20, 20, 21, 30)
    f.pts(TIMBER[0], (9, 29), (9, 30), (21, 29), (21, 30))
    f.pts(STEEL[0], (10, 20), (20, 20))
    f.outline()
    return f


def scoop_side_top(x):
    """Top row of the near side wall of the scoop at column x (side view)."""
    return 12 if x <= 13 else 12 + ((x - 13) * 10) // 11


def scraper_east(loaded):
    """Side on: curved back and handles to the left, cutting edge, bail and
    chain to the right."""
    f = Frame()
    # far wall and the inside, seen over the near wall
    for x in range(9, 25):
        top = scoop_side_top(x) - 2
        f.vline(x, top, 21, IRON[2])
        f.put(x, top, STEEL[2])
    if loaded:
        cx, cy, rx, ry = 14.5, 14.0, 7.4, 7.0
        for y in range(6, 22):
            for x in range(8, 24):
                nx, ny = (x - cx) / rx, (y - cy) / ry
                if nx * nx + ny * ny <= 1.0 and y < scoop_side_top(x) + 1:
                    f.put(x, y, heap_shade(DIRT, x, y, nx, ny, 3))
    # near wall
    for x in range(7, 25):
        top = scoop_side_top(x)
        y0, y1 = top, 22
        if x == 7:
            y0, y1 = 14, 19
        elif x == 8:
            y1 = 21
        for y in range(y0, y1 + 1):
            c = STEEL[1]
            if y == y0:
                c = STEEL[0]
            elif y >= 21:
                c = IRON[1]
            elif y >= 18 or x <= 8:
                c = STEEL[2]
            f.put(x, y, c)
    f.hline(22, 25, 23, STEEL[0])           # the lip bites forward
    f.hline(10, 21, 23, IRON[2])            # runner
    # handle
    line(f, 1, 7, 9, 13, TIMBER[1])
    line(f, 1, 8, 9, 14, TIMBER[3])
    f.pts(TIMBER[0], (1, 7), (2, 7))
    f.pts(STEEL[0], (9, 14))
    # bail from its pivot on the side wall to the chain
    line(f, 16, 19, 27, 21, IRON[1])
    line(f, 16, 20, 27, 22, IRON[2])
    f.pts(STEEL[0], (15, 19), (16, 19))
    chain(f, ((28, 21), (29, 22), (30, 22)))
    f.outline()
    return f


def scraper_dirs(loaded):
    east = scraper_east(loaded)
    return [scraper_south(loaded), scraper_north(loaded), east, mirror(east)]


# ---------------------------------------------------------- blasting charge --

FUSE = ((16, 11), (16, 10), (17, 9), (18, 8), (19, 8), (20, 7), (21, 6), (21, 5))


def blasting_charge(step=None):
    """A small powder keg, hooped in iron, with a cord fuse out of the bung.
    Lit, the end of the fuse burns and throws sparks."""
    f = Frame()
    # staves, bulging at the middle
    for y in range(13, 28):
        bulge = 1 if 16 <= y <= 24 else 0
        x0, x1 = 11 - bulge, 20 + bulge
        for x in range(x0, x1 + 1):
            t = (x - x0) / float(x1 - x0)
            c = TIMBER[1] if t < 0.3 else TIMBER[2] if t < 0.7 else TIMBER[3]
            if x in (13, 16, 19):
                c = TIMBER[3] if t < 0.7 else TIMBER[4]
            f.put(x, y, c)
    f.hline(11, 20, 27, TIMBER[4])
    # head
    f.hline(12, 19, 11, TIMBER[1])
    f.hline(11, 20, 12, TIMBER[0])
    f.hline(11, 20, 13, TIMBER[1])
    f.hline(12, 19, 14, TIMBER[3])
    f.pts(TIMBER[4], (15, 12), (16, 12))    # bung
    # hoops
    for y, x0, x1 in ((15, 11, 20), (25, 11, 20)):
        f.hline(x0, x1, y, IRON[1])
        f.pts(IRON[0], (x0, y), (x0 + 1, y))
        f.pts(IRON[2], (x1, y), (x1 - 1, y))
    for i, (x, y) in enumerate(FUSE):
        f.put(x, y, CORD[0] if i % 2 == 0 else CORD[1])
    f.outline()
    if step is not None:
        k = step % 4
        tx, ty = FUSE[-1]
        f.put(tx, ty, FIRE[1])
        f.put(tx, ty + 1, FIRE[2])
        f.put(tx, ty - 1, SPARK if k % 2 == 0 else FIRE[0])
        sparks = (
            ((1, -2), (-2, -1), (2, 0)),
            ((2, -3), (-1, -3), (3, -1), (-2, 1)),
            ((0, -3), (-3, -2), (2, -1)),
            ((1, -4), (-2, -3), (3, -2), (2, 1)),
        )[k]
        for i, (dx, dy) in enumerate(sparks):
            f.put(tx + dx, ty + dy, (FIRE[0], FIRE[1], SPARK, FIRE[2])[(i + k) % 4])
        puff = ((-1, -5), (0, -6), (1, -5), (0, -5))[k]
        f.put(tx + puff[0], ty + puff[1], SMOKE[0] if k < 2 else SMOKE[1])
    return f


# -------------------------------------------------------------------- held --
# Drawn for the left hand of a figure facing south, then placed for the other
# hand and directions as the pickaxe and shovel are in the weapons sheets.

HELD_KEY = {'A': GREY[0], 'a': GREY[1], 's': GREY[3], 'W': TIMBER[1], 'w': TIMBER[3],
            'T': TIMBER[2], 'I': IRON[1], 'i': IRON[2], 'f': CORD[0], 'F': CORD[1]}

HELD_MATTOCK = (20, 17, (
    '..AA......',
    '..AAa.aa..',
    '...aAAAAa.',
    '....sWa..s',
    '....Ww....',
    '...Ww.....',
    '...Ww.....',
    '..Ww......',
    '..Ww......',
    '.Ww.......',
))

HELD_CHARGE = (21, 17, (
    '....f.',
    '...F..',
    '.WWTw.',
    'IIIIii',
    'WTTTww',
    'WTTTww',
    'IIIIii',
    '.TTww.',
))


def held(art):
    x0, y0, rows = art
    f = Frame()
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch != '.':
                f.put(x0 + i, y0 + j, HELD_KEY[ch])
    return f


def held_dirs(art):
    """(left hand, right hand) frames in DIRS order."""
    base = held(art)
    flip = mirror(base)
    left = [base, flip, moved(base, -1, 1), moved(flip, 7, 0)]
    right = [flip, base, moved(base, -7, 0), moved(flip, 1, 1)]
    return left, right


# ------------------------------------------------------------------- sheets --

def item_states():
    """[(state, dirs, [frame][dir] frames, delay)] in sheet order."""
    out = [('mattock', 1, [[mattock()]], 0), ('wheelbarrow', 4, [barrow_dirs()], 0)]
    for name, ramp, full in (('wheelbarrow_dirt', DIRT, False), ('wheelbarrow_sand', SAND, False),
                             ('wheelbarrow_dirt_full', DIRT, True), ('wheelbarrow_sand_full', SAND, True)):
        out.append((name, 4, [barrow_load_dirs(ramp, full)], 0))
    out.append(('slip_scraper', 4, [scraper_dirs(False)], 0))
    out.append(('slip_scraper_loaded', 4, [scraper_dirs(True)], 0))
    out.append(('blasting_charge', 1, [[blasting_charge()]], 0))
    out.append(('blasting_charge_lit', 1, [[blasting_charge(i)] for i in range(4)], 2))
    return out


def held_states():
    m_left, m_right = held_dirs(HELD_MATTOCK)
    c_left, c_right = held_dirs(HELD_CHARGE)
    return ([('mattock', 4, [m_left], 0), ('blasting_charge', 4, [c_left], 0)],
            [('mattock', 4, [m_right], 0), ('blasting_charge', 4, [c_right], 0)])


def sheets():
    left, right = held_states()
    return ((SHEET, item_states()), (LEFT, left), (RIGHT, right))


def check_drawing():
    """The loads must sit in the tray, and nothing may be cut off by the tile."""
    barrow = barrow_dirs()
    plan = {(x, y) for x in range(TRAY_X0, TRAY_X1 + 1) for y in range(TRAY_Y0, TRAY_Y1 + 1)}
    side = {(x, y) for x in range(SIDE_X0, SIDE_X1 + 1) for y in range(SIDE_Y0, SIDE_Y1 + 1)}
    for name, _, frames, _ in item_states():
        for d, f in enumerate(frames[0]):
            assert f.px, name + ' is empty'
            if not name.startswith('wheelbarrow_'):
                continue
            opening = plan if d < 2 else side
            for (x, y), c in f.px.items():
                if c == OUT:
                    assert (x, y) not in barrow[d].px, '%s %s outlines over the barrow' % (name, DIRS[d])
                elif name.endswith('_full'):
                    assert (x, y) in opening or y < min(q[1] for q in opening), \
                        '%s %s spills at %d,%d' % (name, DIRS[d], x, y)
                else:
                    assert (x, y) in opening, '%s %s leaves the tray at %d,%d' % (name, DIRS[d], x, y)
            if name.endswith('_full'):
                assert opening <= set(f.px), '%s %s does not fill the tray' % (name, DIRS[d])
    for f in barrow:
        for p in plan if f in barrow[:2] else side:
            assert p in f.px, 'tray opening is not drawn'


def build(states):
    frames = [fr for _, _, frs, _ in states for per_dir in frs for fr in per_dir]
    cols = int(len(frames) ** 0.5 + 0.999)
    rows = (len(frames) + cols - 1) // cols
    im = Image.new('RGBA', (cols * 32, rows * 32))
    for i, fr in enumerate(frames):
        im.paste(fr.image(), ((i % cols) * 32, (i // cols) * 32))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, dirs, frs, delay in states:
        text += 'state = "%s"\n\tdirs = %d\n\tframes = %d\n' % (name, dirs, len(frs))
        if len(frs) > 1:
            text += '\tdelay = %s\n' % ','.join([str(delay)] * len(frs))
    text += '# END DMI\n'
    return im, text


def write_dmi(path, states):
    im, text = build(states)
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    im.save(path, 'PNG', pnginfo=meta, optimize=True)


def matches(path, states):
    if not path.exists():
        return False
    im, text = build(states)
    old = Image.open(path)
    return old.info.get('Description') == text and old.size == im.size and old.convert('RGBA').tobytes() == im.tobytes()


# ------------------------------------------------------------------ preview --

def figure_frames():
    """The base body in DIRS order, when its sheet is there to read."""
    path = ROOT / 'icons/mob/human.dmi'
    try:
        im = Image.open(path)
        text = im.info.get('Description', '')
        index = 0
        for block in text.split('state = ')[1:]:
            name = block.split('"')[1]
            dirs = int(block.split('dirs = ')[1].split()[0])
            count = dirs * int(block.split('frames = ')[1].split()[0])
            if name == 'human_m_s' and dirs == 4:
                cols = im.width // 32
                rgba = im.convert('RGBA')
                return [rgba.crop((((index + d) % cols) * 32, ((index + d) // cols) * 32,
                                   ((index + d) % cols) * 32 + 32, ((index + d) // cols) * 32 + 32)) for d in range(4)]
            index += count
    except (OSError, ValueError, IndexError):
        pass
    return [Image.new('RGBA', (32, 32)) for _ in range(4)]


def preview(path, scale=6):
    """Every state and direction on grass, the loads on their barrow, the held
    art on a figure, and the whole set again at 2x and 1x."""
    grass, dirt = (98, 122, 78, 255), (124, 100, 74, 255)
    items = {name: frs for name, _, frs, _ in item_states()}
    left, right = held_states()
    body = figure_frames()

    def over(*layers):
        tile = Image.new('RGBA', (32, 32))
        for layer in layers:
            tile.alpha_composite(layer if isinstance(layer, Image.Image) else layer.image())
        return tile

    rows = []
    rows.append(('mattock, blasting_charge, blasting_charge_lit 1-4',
                 [over(items['mattock'][0][0]), over(items['blasting_charge'][0][0])]
                 + [over(fr[0]) for fr in items['blasting_charge_lit']]))
    rows.append(('wheelbarrow S N E W | slip_scraper S N E W',
                 [over(f) for f in items['wheelbarrow'][0]] + [over(f) for f in items['slip_scraper'][0]]))
    rows.append(('wheelbarrow + _dirt | slip_scraper_loaded',
                 [over(b, l) for b, l in zip(items['wheelbarrow'][0], items['wheelbarrow_dirt'][0])]
                 + [over(f) for f in items['slip_scraper_loaded'][0]]))
    rows.append(('wheelbarrow + _dirt_full | + _sand_full',
                 [over(b, l) for b, l in zip(items['wheelbarrow'][0], items['wheelbarrow_dirt_full'][0])]
                 + [over(b, l) for b, l in zip(items['wheelbarrow'][0], items['wheelbarrow_sand_full'][0])]))
    rows.append(('wheelbarrow + _sand | overlays alone: _dirt_full E, _sand_full S, _dirt S, _sand E',
                 [over(b, l) for b, l in zip(items['wheelbarrow'][0], items['wheelbarrow_sand'][0])]
                 + [over(items['wheelbarrow_dirt_full'][0][2]), over(items['wheelbarrow_sand_full'][0][0]),
                    over(items['wheelbarrow_dirt'][0][0]), over(items['wheelbarrow_sand'][0][2])]))
    for label, a, b in (('held mattock: left hand S N E W | right hand S N E W', left[0], right[0]),
                        ('held blasting_charge: left hand S N E W | right hand S N E W', left[1], right[1])):
        rows.append((label, [over(body[d], a[2][0][d]) for d in range(4)] + [over(body[d], b[2][0][d]) for d in range(4)]))
    rows.append(('held art alone: mattock left, blasting_charge left',
                 [over(f) for f in left[0][2][0]] + [over(f) for f in left[1][2][0]]))

    pad, label_h, wide = 6, 14, 8
    cell = 32 * scale + pad
    small_h = 32 * 2 + pad
    height = pad + len(rows) * (cell + label_h) + len(rows) * small_h // 1 + pad
    out = Image.new('RGBA', (pad + wide * cell + pad + wide * (64 + pad) + wide * (32 + pad), height), (24, 24, 24, 255))
    draw = ImageDraw.Draw(out)
    y = pad
    for j, (label, tiles) in enumerate(rows):
        draw.text((pad, y), label, fill=(230, 230, 230, 255))
        y += label_h
        for i, tile in enumerate(tiles):
            bg = Image.new('RGBA', (32, 32), grass if (i // 4 + j) % 2 == 0 else dirt)
            bg.alpha_composite(tile)
            out.paste(bg.resize((32 * scale, 32 * scale), Image.NEAREST), (pad + i * cell, y))
            x2 = pad + wide * cell + pad
            out.paste(bg.resize((64, 64), Image.NEAREST), (x2 + i * (64 + pad), y))
            out.paste(bg, (x2 + wide * (64 + pad) + i * (32 + pad), y))
        y += cell
    out.crop((0, 0, out.width, y + pad)).save(path)


def main():
    check_drawing()
    if '--check' in sys.argv:
        stale = [str(path.relative_to(ROOT)) for path, states in sheets() if not matches(path, states)]
        if stale:
            sys.exit('stale sheet: ' + ', '.join(stale))
        print('earthworking tool sheets match (%d files)' % len(sheets()))
    else:
        for path, states in sheets():
            write_dmi(path, states)
    if '--preview' in sys.argv[1:-1]:
        target = Path(sys.argv[sys.argv.index('--preview') + 1])
        target.parent.mkdir(parents=True, exist_ok=True)
        preview(target)


if __name__ == '__main__':
    main()
