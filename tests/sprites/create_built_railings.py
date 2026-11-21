#!/usr/bin/env python3
"""Draw the player-built balcony and terrace railings in icons/obj/railings_built.dmi.

Twenty-one 32x32 states, each with four directions (DMI order SOUTH, NORTH,
EAST, WEST). They are ON_BORDER edge pieces placed like `railing0` in
icons/obj/railing.dmi: the dir is the tile edge the railing runs along.

  SOUTH  seen from the front along the bottom edge, 9-13 rows tall
  NORTH  the same elevation from behind along the top edge, in its own shade,
         with a soft shadow falling into the tile
  EAST / WEST  a narrow strip down the right / left edge seen from above, its
         south end closed by a post drawn at full height

Seven materials, each with a railing, a shut gate and an open gate:

  wood          planed timber top rail and square balusters
  stone         dressed grey balustrade: coping, plinth and turned balusters
  sandstone     the same form in sandstone tones
  brick         a low red-brick parapet under a stone coping (solid, lower)
  wrought_iron  dark iron bars with spear finials and small pointed scrolls
  steel_pipe    galvanised pipe handrail with a mid rail and flanged posts
  glass         pale half-transparent glass panel in thin steel posts and rail

  <material>            the railing
  <material>_gate       a shut gate between two posts: the leaf stands clear of
                        the posts and the ground, hangs on two dark hinges and
                        closes on a brass latch
  <material>_gate_open  the same posts with the leaf swung in over its own
                        tile along the hinge end

Every piece ends in a post (or runs to the tile edge), so a run of tiles joins
up and two pieces on one tile make a corner. The middle of the tile stays
clear for the floor and whoever stands on it. Everything is lit from the top
left. The drawing is plain pixel work with Pillow from fixed palettes; nothing
is random, so a rerun writes the same bytes.

  python3 tests/sprites/create_built_railings.py                  write the sheet
  python3 tests/sprites/create_built_railings.py --check          verify the committed sheet
  python3 tests/sprites/create_built_railings.py --preview <png>  also write a review sheet
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_water_animation import SIZE, write_dmi  # noqa: E402
from create_bollards import noise, option  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/railings_built.dmi'
FLOORS = ROOT / 'icons/turf/floors.dmi'
MATERIALS = ('wood', 'stone', 'sandstone', 'brick', 'wrought_iron', 'steel_pipe', 'glass')
KINDS = ('', '_gate', '_gate_open')
STATES = tuple(m + k for m in MATERIALS for k in KINDS)
DIRS = ('SOUTH', 'NORTH', 'EAST', 'WEST')  # DMI order for dirs = 4
EDGE = SIZE - 1

# each ramp: outline first, then shade to highlight
WOOD = [(52, 32, 20), (86, 54, 32), (116, 74, 44), (142, 94, 56), (168, 118, 74), (196, 150, 100)]
STONE = [(50, 50, 52), (82, 82, 84), (108, 108, 108), (134, 134, 132), (160, 160, 156), (190, 190, 184)]
SAND = [(92, 70, 40), (138, 110, 68), (168, 140, 90), (194, 166, 112), (214, 190, 138), (236, 218, 172)]
BRICK = [(64, 28, 22), (112, 44, 34), (144, 58, 42), (170, 76, 54), (190, 98, 70), (204, 118, 88)]
MORTAR = (176, 160, 138)
COPING = [(88, 82, 74), (128, 122, 110), (160, 154, 140), (186, 180, 164), (206, 200, 184), (226, 220, 204)]
IRON = [(12, 12, 14), (28, 29, 33), (44, 46, 51), (62, 65, 71), (88, 92, 99), (128, 133, 141)]
STEEL = [(58, 64, 70), (98, 106, 114), (130, 138, 146), (160, 168, 176), (190, 198, 204), (224, 230, 234)]
BRASS = [(108, 82, 26), (214, 180, 82)]
GLASS = (172, 218, 232, 84)
GLASS_EDGE = (120, 172, 192, 150)
GLASS_SHINE = (240, 250, 255, 150)

HEIGHT = {'wood': 12, 'stone': 13, 'sandstone': 13, 'brick': 9, 'wrought_iron': 13, 'steel_pipe': 12,
          'glass': 12}
POST = {'wood': 3, 'stone': 3, 'sandstone': 3, 'brick': 4, 'wrought_iron': 2, 'steel_pipe': 2, 'glass': 2}
STRIP = {'wood': 6, 'stone': 7, 'sandstone': 7, 'brick': 7, 'wrought_iron': 4, 'steel_pipe': 4, 'glass': 4}
LEAF = {'wood': 'timber', 'stone': 'iron', 'sandstone': 'iron', 'brick': 'plank', 'wrought_iron': 'iron',
        'steel_pipe': 'pipe', 'glass': 'glass'}
LEAF_STRIP = {'timber': 4, 'plank': 4, 'iron': 3, 'pipe': 3, 'glass': 3}
RAMP = {'wood': WOOD, 'stone': STONE, 'sandstone': SAND, 'brick': BRICK, 'wrought_iron': IRON,
        'steel_pipe': STEEL, 'glass': STEEL}
CAP_ROWS = 3        # how much of the far post shows at the north end of an EAST / WEST strip
OPEN_RUN = 14       # rows of an open leaf's top edge on a SOUTH / NORTH piece
OPEN_WIDTH = 19     # width of an open leaf lying along the north end of an EAST / WEST piece


class Cv:
    """A small RGBA canvas; writes outside it are dropped."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.im = Image.new('RGBA', (w, h))
        self.px = self.im.load()

    def put(self, x, y, colour, alpha=255):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = tuple(colour[:3]) + (colour[3] if len(colour) == 4 else alpha,)

    def row(self, x0, x1, y, colour):
        for x in range(x0, x1 + 1):
            self.put(x, y, colour)

    def col(self, x, y0, y1, colour):
        for y in range(y0, y1 + 1):
            self.put(x, y, colour)

    def clear(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = (0, 0, 0, 0)

    def stamp(self, other, x, y):
        """Opaque pixels replace, half-transparent ones only land on clear ground."""
        for oy in range(other.h):
            for ox in range(other.w):
                p = other.px[ox, oy]
                tx, ty = x + ox, y + oy
                if p[3] and 0 <= tx < self.w and 0 <= ty < self.h and (p[3] == 255 or not self.px[tx, ty][3]):
                    self.px[tx, ty] = p

    def mirrored(self):
        out = Cv(self.w, self.h)
        out.im = self.im.transpose(Image.FLIP_LEFT_RIGHT)
        out.px = out.im.load()
        return out

    def shaded(self, k):
        out = Cv(self.w, self.h)
        for y in range(self.h):
            for x in range(self.w):
                r, g, b, a = self.px[x, y]
                out.px[x, y] = (int(r * k), int(g * k), int(b * k), a)
        return out


# --- front elevations: 32 wide, HEIGHT tall, row 0 is the top -----------------

def glass_fill(c, x0, x1, y0, y1, seed=0):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            shine = (x + y + seed) % 11 < 2
            c.put(x, y, GLASS_EDGE if x in (x0, x1) else GLASS_SHINE if shine else GLASS)


def brick_face(c, x0, x1, y0, y1, shift=0):
    """Two-row bricks under one row of mortar, 8px running bond."""
    for y in range(y0, y1 + 1):
        course, r = divmod(y - y0, 3)
        for x in range(x0, x1 + 1):
            if r == 2:
                c.put(x, y, MORTAR if y < y1 else BRICK[0])
            elif (x + shift + 4 * (course % 2)) % 8 == 7:
                c.put(x, y, MORTAR)
            else:
                t = 4 if r == 0 else 3
                if noise((x + shift + 4 * (course % 2)) // 8, course, 3) < 0.3:
                    t -= 1
                c.put(x, y, BRICK[t])


def coping(c, x0, x1, y, open_left=False, open_right=False):
    """A three-row stone coping: lit top, face, and the shadow it throws."""
    for x in range(x0, x1 + 1):
        joint = x % 16 == 15
        c.put(x, y, COPING[3] if joint else COPING[5])
        c.put(x, y + 1, COPING[2] if joint else COPING[3])
        c.put(x, y + 2, COPING[0])
    if not open_left:
        c.put(x0, y + 1, COPING[0])
    if not open_right:
        c.put(x1, y + 1, COPING[0])


def posts(mat):
    """The two end posts of a piece, without anything between them."""
    r, h, c = RAMP[mat], HEIGHT[mat], Cv(SIZE, HEIGHT[mat])
    if mat == 'wood':
        for x, t in ((0, 4), (1, 3), (2, 0), (29, 0), (30, 5), (31, 4)):
            c.col(x, 0, h - 1, r[t])
        for x in (0, 1, 30, 31):
            c.put(x, 0, r[5])
            c.put(x, h - 1, r[1])
    elif mat in ('stone', 'sandstone'):
        for x, t in ((0, 3), (1, 3), (2, 1), (29, 1), (30, 4), (31, 3)):
            c.col(x, 3, h - 4, r[t])
        for x0 in (0, 29):
            c.row(x0, x0 + 2, 0, r[5])
            c.row(x0, x0 + 2, 1, r[4])
            c.row(x0, x0 + 2, 2, r[0])
            c.row(x0, x0 + 2, h - 3, r[4])
            c.row(x0, x0 + 2, h - 2, r[3])
            c.row(x0, x0 + 2, h - 1, r[0])
        c.put(3, 1, r[0])
        c.put(28, 1, r[0])
        c.put(3, h - 2, r[0])
        c.put(28, h - 2, r[0])
    elif mat == 'brick':
        for x0 in (0, 28):
            brick_face(c, x0, x0 + 3, 3, h - 1, shift=x0)
            coping(c, x0, x0 + 3, 0, open_left=x0 == 0, open_right=x0 == 28)
        c.col(3, 3, h - 1, BRICK[0])
        c.col(28, 3, h - 1, BRICK[0])
    elif mat == 'wrought_iron':
        for x, t in ((0, 3), (1, 1), (30, 1), (31, 4)):
            c.col(x, 1, h - 1, r[t])
        for x, t in ((0, 4), (1, 2), (30, 3), (31, 5)):
            c.put(x, 0, r[t])
    else:  # steel_pipe, glass: thin steel uprights
        for x, t in ((0, 3), (1, 0), (30, 0), (31, 5)):
            c.col(x, 0, h - 1, r[t])
        c.put(0, 0, r[5])
        c.put(31, 0, r[5])
        if mat == 'steel_pipe':
            c.row(0, 2, h - 1, r[0])
            c.row(29, 31, h - 1, r[0])
    return c


def front(mat):
    """The railing between its posts."""
    r, h, c = RAMP[mat], HEIGHT[mat], posts(mat)
    if mat == 'wood':
        for x in range(3, 29):
            c.put(x, 1, r[5])
            c.put(x, 2, r[3] if noise(x // 3, 0, 11) < 0.3 else r[4])
            c.put(x, 3, r[0])
            c.put(x, h - 3, r[4])
            c.put(x, h - 2, r[0])
        for x in range(5, 26, 4):  # square balusters
            c.col(x, 4, h - 4, r[4])
            c.col(x + 1, 4, h - 4, r[2])
    elif mat in ('stone', 'sandstone'):
        for x in range(SIZE):
            joint = x == 15
            c.put(x, 0, r[4] if joint else r[5])
            c.put(x, 1, r[3] if joint else r[4])
            c.put(x, 2, r[0])
            c.put(x, h - 3, r[3] if joint else r[4])
            c.put(x, h - 2, r[2] if joint else r[3])
            c.put(x, h - 1, r[0])
        # turned balusters: abacus, neck, low belly, foot
        shape = ((0, 3), (1, 2), (1, 2), (0, 3), (0, 3), (1, 2), (0, 3))
        for x0 in (5, 11, 17, 23):
            for n, (a, b) in enumerate(shape):
                for x in range(a, b + 1):
                    t = 5 if x == a else 2 if x == b else 4
                    if n in (0, 6):
                        t = (4, 4, 3, 1)[x]
                    c.put(x0 + x, 3 + n, r[t])
    elif mat == 'brick':
        brick_face(c, 0, EDGE, 3, h - 1)
        coping(c, 0, EDGE, 0, True, True)
    elif mat == 'wrought_iron':
        c.row(2, 29, 3, r[5])
        c.row(2, 29, 4, r[1])
        c.row(2, 29, h - 3, r[4])
        c.row(2, 29, h - 2, r[1])
        for x in range(3, 28, 4):
            c.col(x, 5, h - 4, r[4])
            c.col(x, 1, 2, r[4])  # spear finial
            c.put(x - 1, 1, r[2])
            c.put(x + 1, 1, r[2])
            c.put(x, 0, r[5])
            if x < 27:  # pointed scrolls between the bars, top and bottom
                for dx, dy in ((1, 6), (2, 5), (3, 6)):
                    c.put(x + dx, dy, r[4])
                    c.put(x + dx, h - 3 - (dy - 3), r[3])
    elif mat == 'steel_pipe':
        for x in range(SIZE):
            c.put(x, 0, r[5])
            c.put(x, 1, r[3])
            c.put(x, 2, r[0])
        c.row(2, 29, 6, r[4])
        c.row(2, 29, 7, r[0])
        c.col(15, 3, h - 1, r[4])
        c.col(16, 3, h - 1, r[0])
        c.put(15, 6, r[5])
        c.row(14, 17, h - 1, r[0])
    else:  # glass
        glass_fill(c, 1, 30, 2, h - 3)
        for x in range(SIZE):
            c.put(x, 0, r[5])
            c.put(x, 1, r[0])
            c.put(x, h - 2, r[3])
            c.put(x, h - 1, r[0])
    return c


# --- gate leaves ----------------------------------------------------------------

def leaf_front(kind, w, h):
    """A gate leaf seen face on, hinge side at the left."""
    c = Cv(w, h)
    if kind in ('timber', 'plank'):
        r = WOOD
        if kind == 'plank':  # close boarded
            for x in range(w):
                c.col(x, 0, h - 1, r[1] if x % 4 == 3 else r[4] if x % 4 == 0 else r[3])
        else:  # pickets and a brace rising from the hinge foot
            for x in range(5, w - 3, 5):
                c.col(x, 0, h - 1, r[3])
            for x in range(2, w - 2):
                y = h - 3 - (x - 2) * (h - 5) // (w - 5)
                c.put(x, y, r[3])
                c.put(x, y + 1, r[1])
        c.row(0, w - 1, 0, r[5])
        c.row(0, w - 1, 1, r[0] if kind == 'timber' else r[2])
        c.row(0, w - 1, h - 2, r[4])
        c.row(0, w - 1, h - 1, r[0])
        c.col(0, 0, h - 1, r[5])
        c.col(1, 1, h - 2, r[3])
        c.col(w - 2, 1, h - 2, r[4])
        c.col(w - 1, 0, h - 1, r[0])
    elif kind == 'iron':
        r = IRON
        for x in range(3, w - 2, 3):
            c.col(x, 0, h - 1, r[3])
        mid = h // 2
        c.row(0, w - 1, mid, r[4])  # lock rail
        for dx, dy in ((0, -2), (1, -3), (2, -2), (0, 2), (1, 3), (2, 2)):  # a ring over it
            c.put(w // 2 - 1 + dx, mid + dy, r[5])
        c.row(0, w - 1, 0, r[5])
        c.row(0, w - 1, 1, r[1])
        c.row(0, w - 1, h - 1, r[2])
        c.col(0, 0, h - 1, r[4])
        c.col(1, 1, h - 1, r[1])
        c.col(w - 2, 0, h - 1, r[4])
        c.col(w - 1, 0, h - 1, r[1])
    elif kind == 'pipe':
        r = STEEL
        for x in range(2, w - 2):  # brace
            y = h - 3 - (x - 2) * (h - 5) // (w - 5)
            c.put(x, y, r[3])
            c.put(x, y + 1, r[0])
        c.row(0, w - 1, h // 2, r[4])
        c.row(0, w - 1, 0, r[5])
        c.row(0, w - 1, 1, r[0])
        c.row(0, w - 1, h - 2, r[4])
        c.row(0, w - 1, h - 1, r[0])
        c.col(0, 0, h - 1, r[5])
        c.col(1, 1, h - 2, r[0])
        c.col(w - 2, 0, h - 1, r[4])
        c.col(w - 1, 0, h - 1, r[0])
    else:  # glass in a thin steel frame, with a pull handle near the latch
        r = STEEL
        glass_fill(c, 1, w - 2, 1, h - 2, seed=5)
        c.row(0, w - 1, 0, r[5])
        c.row(0, w - 1, h - 1, r[0])
        c.col(0, 0, h - 1, r[4])
        c.col(w - 1, 0, h - 1, r[1])
        c.col(w - 4, 3, h - 4, r[0])
        c.col(w - 5, 3, h - 4, r[5])
    return c


def leaf_side(kind, length, stile=0):
    """A leaf seen from above as a strip; `stile` rows of its near end stand below it."""
    w = LEAF_STRIP[kind]
    c = Cv(w, length + stile)
    for y in range(length):
        if kind in ('timber', 'plank'):
            c.put(0, y, WOOD[5])
            c.put(1, y, WOOD[4])
            c.put(2, y, WOOD[0])
            if kind == 'plank':
                c.put(3, y, WOOD[1] if y % 4 == 3 else WOOD[2])
            elif y % 4 < 2:
                c.put(3, y, WOOD[2])
        elif kind == 'iron':
            c.put(0, y, IRON[5])
            c.put(1, y, IRON[1])
            if y % 3 == 1:
                c.put(2, y, IRON[3])
        elif kind == 'pipe':
            c.put(0, y, STEEL[5])
            c.put(1, y, STEEL[3])
            c.put(2, y, STEEL[0])
        else:
            c.put(0, y, STEEL[5])
            c.put(1, y, GLASS_EDGE)
            c.put(2, y, GLASS_SHINE if y % 7 == 2 else GLASS)
    r = {'timber': WOOD, 'plank': WOOD, 'iron': IRON, 'pipe': STEEL, 'glass': STEEL}[kind]
    for y in range(length, length + stile):  # the end stile, seen at its full height
        c.put(0, y, r[4])
        c.put(1, y, r[3] if kind != 'glass' else r[1])
        if w == 4:
            c.put(2, y, r[0])
    if stile:
        c.row(0, 1 if w == 3 else 2, length + stile - 1, r[0])
    return c


def gate_front(mat, opened):
    h, pw, kind = HEIGHT[mat], POST[mat], LEAF[mat]
    c = posts(mat)
    if opened:  # the leaf swung in over its own tile, along the hinge post
        return c
    x0, x1 = pw + 1, EDGE - pw - 1
    c.stamp(leaf_front(kind, x1 - x0 + 1, h - 3), x0, 1)
    for y in (3, h - 5):  # hinge straps reaching from the post onto the leaf
        c.row(x0 - 2, x0 + 1, y, IRON[1])
        c.put(x0 - 1, y, IRON[4])
    y = h // 2 - 1  # latch
    c.row(x1 - 1, x1 + 2, y, BRASS[1])
    c.row(x1 - 1, x1 + 2, y + 1, BRASS[0])
    return c


# --- EAST / WEST strips: STRIP wide, 32 tall, seen from above --------------------

def end_post(mat):
    """The south end post of a strip, seen from the front at its full height."""
    r, w, h = RAMP[mat], STRIP[mat], HEIGHT[mat] - 2
    c = Cv(w, h)
    if mat == 'wood':
        for y in range(h):
            for x, t in enumerate((0, 5, 4, 3, 2, 0)):
                c.put(x, y, r[t if y > 2 else (0, 5, 5, 5, 4, 0)[x]])
        c.row(1, 4, 3, r[1])
        c.row(0, 5, h - 1, r[0])
    elif mat in ('stone', 'sandstone'):
        for y in range(h):
            wide = y < 3 or y >= h - 3
            for x in range(w):
                if wide:
                    t = 5 if y == 0 else 0 if y in (2, h - 1) else 4 if x < 4 else 3
                    c.put(x, y, r[0] if x in (0, w - 1) and y not in (0,) else r[t])
                elif 1 <= x <= w - 2:
                    c.put(x, y, r[(0, 5, 4, 3, 3, 1, 0)[x]] if x not in (1, w - 2) or True else r[0])
        c.row(2, w - 3, h // 2, r[2])
    elif mat == 'brick':
        coping(c, 0, w - 1, 0)
        brick_face(c, 0, w - 1, 3, h - 1, shift=2)
        c.col(0, 3, h - 1, BRICK[0])
        c.col(w - 1, 3, h - 1, BRICK[0])
    elif mat == 'wrought_iron':
        c.put(1, 0, r[5])
        c.put(2, 0, r[3])
        for y in range(1, h):
            c.put(1, y, r[4])
            c.put(2, y, r[1])
        c.put(0, 1, r[3])
        c.put(3, 1, r[1])
        c.row(0, 3, h - 1, r[1])
    else:
        for y in range(h):
            c.put(0, y, r[1])
            c.put(1, y, r[5] if y < 2 else r[4])
            c.put(2, y, r[3])
            c.put(3, y, r[0])
        if mat == 'steel_pipe':
            c.row(0, 3, h - 1, r[0])
    return c


def run(mat, length, shift=0):
    """The top of the railing between the posts of a strip."""
    r, w = RAMP[mat], STRIP[mat]
    c = Cv(w, length)
    for n in range(length):
        y = n + shift
        if mat == 'wood':
            for x, t in enumerate((0, 5, 4, 0)):
                c.put(x, n, r[t])
            if y % 4 < 2:
                c.put(4, n, r[3])
            c.put(5, n, r[1])
        elif mat in ('stone', 'sandstone'):
            joint = y % 16 == 15
            for x, t in enumerate((1, 5, 5, 4, 0)):
                c.put(x, n, r[3] if joint and 0 < x < 4 else r[t])
            if y % 6 < 4:
                c.put(5, n, r[4] if y % 6 == 0 else r[3] if y % 6 < 3 else r[1])
            c.put(6, n, r[2])
        elif mat == 'brick':
            joint = y % 16 == 15
            for x, t in enumerate((0, 5, 4, 0)):
                c.put(x, n, COPING[3] if joint and 0 < x < 3 else COPING[t])
            for x in (4, 5, 6):
                c.put(x, n, MORTAR if y % 4 == 3 else BRICK[(4, 3, 2)[x - 4]])
        elif mat == 'wrought_iron':
            c.put(1, n, r[5])
            c.put(2, n, r[1])
            if y % 4 == 1:
                c.put(3, n, r[3])
                c.put(0, n, r[4])  # spear points standing proud of the rail
        elif mat == 'steel_pipe':
            for x, t in enumerate((5, 3, 0)):
                c.put(x, n, r[t])
            c.put(3, n, r[2])
        else:
            c.put(0, n, r[5])
            c.put(1, n, r[0])
            c.put(2, n, GLASS_EDGE)
            c.put(3, n, GLASS_SHINE if y % 7 == 2 else GLASS)
    return c


def side(mat, kind):
    """One EAST / WEST strip, STRIP[mat] wide and a whole tile tall."""
    w, c = STRIP[mat], Cv(STRIP[mat], SIZE)
    post = end_post(mat)
    if mat == 'brick' and not kind:  # a plain wall has no posts to break it
        c.stamp(run(mat, SIZE), 0, 0)
        return c
    top = CAP_ROWS + (1 if mat in ('stone', 'sandstone', 'brick') else 0)
    c.stamp(post, 0, 0)
    for y in range(top, SIZE):
        for x in range(w):
            c.clear(x, y)
    for x in range(w):  # close the far post
        if c.px[x, top - 1][3]:
            c.put(x, top - 1, RAMP[mat][0])
    length = SIZE - post.h - top
    if not kind:
        c.stamp(run(mat, length, shift=top), 0, top)
    elif kind == '_gate':
        leaf = leaf_side(LEAF[mat], length - 2)
        x = min(1, w - leaf.w)
        c.stamp(leaf, x, top + 1)
        c.row(x, x + 1, top, IRON[1])  # hinge
        c.put(x, top + 1, IRON[1])
        c.row(x, x + 1, top + length - 1, BRASS[1])  # latch
        c.put(x + 1, top + length - 2, BRASS[0])
    c.stamp(post, 0, SIZE - post.h)
    return c


# --- the four directions --------------------------------------------------------

def shadow(c, y):
    """Two soft rows under whatever stands in row y - 1."""
    for x in range(SIZE):
        if c.px[x, y - 1][3] == 255:
            for dy, alpha in ((0, 70), (1, 34)):
                if not c.px[x, y + dy][3]:
                    c.put(x, y + dy, (0, 0, 0), alpha)


def tile(mat, kind, d):
    c = Cv(SIZE, SIZE)
    h, pw, lk = HEIGHT[mat], POST[mat], LEAF[mat]
    opened = kind == '_gate_open'
    if d in ('SOUTH', 'NORTH'):
        face = gate_front(mat, opened) if kind else front(mat)
        stile = h - 4
        leaf = leaf_side(lk, OPEN_RUN, stile)
        if d == 'SOUTH':
            c.stamp(face, 0, SIZE - h)
            if opened:
                c.stamp(leaf, pw + 1, EDGE - leaf.h)
                c.row(pw - 1, pw + 1, EDGE - 2, IRON[1])
        else:
            face = face.mirrored().shaded(0.86)
            c.stamp(face, 0, 0)
            if opened:
                c.stamp(leaf.shaded(0.92), EDGE - pw - leaf.w, 2)
                c.row(EDGE - pw - 1, EDGE - pw + 1, 4, IRON[1])
            shadow(c, h)
    else:
        strip = side(mat, kind)
        x = SIZE - strip.w if d == 'EAST' else 0
        if opened:  # the leaf lies along the north end, hinged on the far post
            leaf = leaf_front(lk, OPEN_WIDTH, h - 3)
            if d == 'EAST':
                c.stamp(leaf.mirrored(), x - OPEN_WIDTH, 1)
                c.row(x - 2, x, 3, IRON[1])
            else:
                c.stamp(leaf, strip.w, 1)
                c.row(strip.w - 1, strip.w + 1, 3, IRON[1])
            shadow_rows = h - 2
            for sx in range(SIZE):
                if c.px[sx, shadow_rows - 1][3] == 255:
                    c.put(sx, shadow_rows, (0, 0, 0), 60)
        c.stamp(strip, x, 0)
    return c.im


def build():
    return [(m + k, {'dirs': '4', 'frames': '1'}, [tile(m, k, d) for d in DIRS])
            for m in MATERIALS for k in KINDS]


# --- checks ---------------------------------------------------------------------

def check_drawing(states):
    problems = []
    seen = {}
    for name, _, ims in states:
        if len(ims) != 4 or len({im.tobytes() for im in ims}) != 4:
            problems.append('%s: needs four different directions' % name)
        for d, im in zip(DIRS, ims):
            alpha = im.getchannel('A')
            x0, y0, x1, y1 = alpha.getbbox()
            touch = {'SOUTH': y1 == SIZE, 'NORTH': y0 == 0, 'EAST': x1 == SIZE, 'WEST': x0 == 0}[d]
            if not touch:
                problems.append('%s %s: does not reach its edge' % (name, d))
            opened = name.endswith('_open')
            reach = {'SOUTH': SIZE - y0, 'NORTH': y1, 'EAST': SIZE - x0, 'WEST': x1}[d]
            limit = 28 if opened else 15 if d in ('SOUTH', 'NORTH') else 8
            if reach > limit:
                problems.append('%s %s: reaches %d px into the tile' % (name, d, reach))
            used = sum(1 for a in alpha.tobytes() if a)
            if used > SIZE * SIZE * 45 // 100:
                problems.append('%s %s: covers %d pixels' % (name, d, used))
            if any(alpha.getpixel((x, y)) for x in range(12, 20) for y in range(15, 18)):
                problems.append('%s %s: the middle of the tile is not clear' % (name, d))
            soft = sum(1 for a in alpha.tobytes() if 0 < a < 255)
            if name.startswith('glass') and not opened and soft < 20:
                problems.append('%s %s: the glass is not translucent' % (name, d))
            key = im.tobytes()
            if key in seen:
                problems.append('%s %s: same pixels as %s' % (name, d, seen[key]))
            seen[key] = '%s %s' % (name, d)
    return problems


def check_sheet(path, states):
    path = Path(path)
    if not path.exists():
        return ['%s is missing' % path]
    sheet = Image.open(path)
    text = sheet.info.get('Description', '')
    lines = [line.strip() for line in text.splitlines()]
    names = [line.split('"')[1] for line in lines if line.startswith('state = ')]
    problems = []
    if 'version = 4.0' not in lines:
        problems.append('%s: not a version 4.0 DMI' % path.name)
    if names != list(STATES):
        problems.append('%s lists %s' % (path.name, names))
    if [line for line in lines if line.startswith('dirs')] != ['dirs = 4'] * len(STATES):
        problems.append('%s: every state needs dirs = 4' % path.name)
    if 'width = %d' % SIZE not in lines or 'height = %d' % SIZE not in lines:
        problems.append('%s: not a %dx%d sheet' % (path.name, SIZE, SIZE))
    sheet = sheet.convert('RGBA')
    cols = sheet.width // SIZE
    n = 0
    for name, _, ims in states:
        for d, im in zip(DIRS, ims):
            box = ((n % cols) * SIZE, (n // cols) * SIZE, (n % cols + 1) * SIZE, (n // cols + 1) * SIZE)
            if sheet.crop(box).tobytes() != im.tobytes():
                problems.append('%s %s: committed pixels differ from the drawing' % (name, d))
            n += 1
    return problems


# --- preview --------------------------------------------------------------------

def floor_tile(name):
    """The first frame of a state of the floor sheet."""
    im = Image.open(FLOORS)
    index, found, dirs = 0, None, 1
    for line in im.info['Description'].splitlines():
        line = line.strip()
        if line.startswith('state = '):
            if line.split('"')[1] == name:
                found = index
                break
        elif line.startswith('dirs = '):
            dirs = int(line.split('=')[1])
        elif line.startswith('frames = '):
            index += dirs * int(line.split('=')[1])
    if found is None:
        raise KeyError(name)
    per_row = im.width // SIZE
    x, y = (found % per_row) * SIZE, (found // per_row) * SIZE
    return im.convert('RGBA').crop((x, y, x + SIZE, y + SIZE))


def write_preview(path, states, scale=3):
    """One row per material. On a wooden and then a stone floor: a 3x3 balcony
    ringed by the railing, the same with a shut gate in the middle of each
    side, and with those gates open. Last, the four lone pieces on each floor."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    by_name = {name: dict(zip(DIRS, ims)) for name, _, ims in states}
    floors = [floor_tile('wood'), floor_tile('stone_old')]
    gap, label = 12, 12
    block = 3 * SIZE + gap
    width = gap + 6 * block + 4 * SIZE + gap
    row_h = label + 3 * SIZE + gap
    sheet = Image.new('RGBA', (width, gap + row_h * len(MATERIALS)), (34, 30, 28, 255))

    def ring(ox, oy, floor, mat, kind):
        for ty in range(3):
            for tx in range(3):
                sheet.alpha_composite(floor, (ox + tx * SIZE, oy + ty * SIZE))
        for d in ('NORTH', 'WEST', 'EAST', 'SOUTH'):  # the order the edges layer in
            for k in range(3):
                tx, ty = {'NORTH': (k, 0), 'SOUTH': (k, 2), 'WEST': (0, k), 'EAST': (2, k)}[d]
                state = mat + (kind if k == 1 else '')
                sheet.alpha_composite(by_name[state][d], (ox + tx * SIZE, oy + ty * SIZE))

    marks = []
    for row, mat in enumerate(MATERIALS):
        oy = gap + row * row_h + label
        for f, floor in enumerate(floors):
            for k, kind in enumerate(KINDS):
                ox = gap + (f * 3 + k) * block
                ring(ox, oy, floor, mat, kind)
                marks.append((ox, oy - label, mat + kind))
        ox = gap + 6 * block
        for f, floor in enumerate(floors):  # the lone pieces, one clear tile apart
            for n, d in enumerate(DIRS):
                x, y = ox + n * SIZE, oy + f * (SIZE + SIZE // 2)
                sheet.alpha_composite(floor, (x, y))
                sheet.alpha_composite(by_name[mat][d], (x, y))
        marks.append((ox, oy - label, mat + ' S N E W'))
    big = sheet.convert('RGB').resize((sheet.width * scale, sheet.height * scale), Image.NEAREST)
    draw = ImageDraw.Draw(big)
    for x, y, text in marks:
        draw.text((x * scale + 2, y * scale + 12), text, fill=(240, 232, 214))
    big.save(path)


def main():
    states = build()
    problems = check_drawing(states)
    if '--check' in sys.argv:
        problems += check_sheet(option('--sheet') or SHEET, states)
        for line in problems:
            print(line)
        print('built railings: %s' % ('FAILED' if problems else 'ok'))
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
