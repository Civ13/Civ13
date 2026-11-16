"""Hand-placed sprites for the siege engines that stand beside the catapult
(icons/obj/catapult.dmi), in its timber, iron and rope colours:

  icons/obj/siege_engines.dmi (32x32): the battering ram and its swing, the
      ballista (unloaded and loaded), its loose bolt and the bolt in flight,
      the gate winch, the portcullis (closed, open, moving), the sections of
      a portcullis several tiles wide, the drawbridge (down and up) and the
      murder hole.
  icons/obj/trebuchet.dmi (64x64): trebuchet0, trebuchet1, trebuchet_fire.
  icons/obj/siege_tower.dmi (64x64): siege_tower, siege_tower_bridge.

The engines are small block models built facing north from fixed-colour
blocks, turned to each direction and drawn in the 3/4 top-down view (a block's
top face above its south face, one pixel of height per pixel), so every
direction shows the same machine with the light kept at the upper left. The
flat pieces (bolts, portcullis, drawbridge, murder hole) are placed pixel by
pixel. Everything comes from fixed palettes and a hash for texture (Pillow
only); no external or generated artwork.

The siege tower stands on the bottom-left 32x32 tile of its 64x64 cell and
rises into the upper half; its drop bridge is seven pixels long so the west
facing one still fits in the cell.

Run with Pillow to reproduce the sheets. `--check` verifies the committed
sheets match and `--preview <png>` writes a 4x review sheet with every state,
direction and frame labelled. `--runs <png>` writes a 4x sheet of assembled
portcullis runs (one, three and five tiles wide, three tiles tall), closed and
open, on the murder hole's stone floor. Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
ENGINES = ROOT / 'icons/obj/siege_engines.dmi'
TREBUCHET = ROOT / 'icons/obj/trebuchet.dmi'
TOWER = ROOT / 'icons/obj/siege_tower.dmi'

DIRS = ('S', 'N', 'E', 'W')          # BYOND order inside a DMI

# catapult.dmi timber, light to dark, and its outline
OUT = (47, 23, 7)
WOOD = [(152, 78, 26), (135, 66, 20), (120, 58, 18), (105, 52, 16), (97, 47, 14),
        (87, 43, 13), (70, 34, 11), (55, 28, 9)]
# peeled, paler timber for logs, shafts and decks
PALE = [(190, 132, 70), (168, 108, 50), (146, 88, 36), (124, 72, 28), (100, 56, 20), (76, 42, 14)]
# the catapult's stone greys
STONE = [(176, 176, 176), (157, 157, 157), (148, 148, 148), (117, 117, 117), (96, 96, 96), (78, 78, 78),
         (58, 58, 58)]
# wrought iron
IRON = [(150, 154, 166), (116, 120, 134), (86, 90, 104), (62, 64, 78), (42, 44, 54)]
# hemp rope
ROPE = [(222, 198, 146), (188, 162, 108), (146, 122, 78), (106, 86, 54)]
# wet hides
HIDE = [(178, 152, 120), (156, 130, 100), (134, 108, 82), (112, 88, 66), (90, 70, 52), (68, 52, 40)]
# leather
LEATHER = [(184, 124, 76), (150, 96, 56), (112, 68, 38), (80, 46, 26)]
# the dark of an opening
DARK = [(40, 30, 26), (30, 22, 20), (22, 16, 16), (16, 12, 12)]


def noise(x, y, z=0, seed=0):
    """A fixed pseudo-random number 0..255, the same on every run."""
    v = (x * 73856093) ^ (y * 19349663) ^ (z * 83492791) ^ (seed * 2654435761)
    v = (v ^ (v >> 13)) * 1274126177
    return ((v ^ (v >> 16)) >> 4) & 255


# ------------------------------------------------------------ block models --

class Mat:
    """A colour ramp with the ramp steps of a lit top face and a south face,
    and an optional texture: tex(x, y, z, face) -> extra steps darker."""

    def __init__(self, ramp, top=1, front=3, tex=None, edge=True):
        self.ramp, self.top, self.front, self.tex, self.edge = ramp, top, front, tex, edge


def speckle(seed, rate=40):
    return lambda x, y, z, face: 1 if noise(x, y, z, seed) < rate else 0


def hide_tex(x, y, z, face):
    """Stitched hide panels with damp blotches."""
    a, b = (x, y) if face == 't' else (x + y, z)
    d = 0
    if b % 7 == 3 or (a + (b // 7) * 3) % 8 == 0:
        d += 1                                     # seams
    if noise(a // 3, b // 3, 0, 7) < 70:
        d += 1                                     # wet patches
    if noise(a, b, 0, 9) < 22:
        d -= 1
    return d


def plank_tex(step, along='x'):
    def tex(x, y, z, face):
        v = {'x': x, 'y': y, 'z': z}[along]
        return 2 if v % step == 0 else (1 if noise(x, y, z, 3) < 28 else 0)
    return tex


def rope_tex(x, y, z, face):
    return (x + y + z) % 2


M_WOOD = Mat(WOOD, 1, 4, speckle(1))
M_WOOD_D = Mat(WOOD, 3, 5, speckle(2))
M_PALE = Mat(PALE, 1, 3, speckle(4))
M_DECK = Mat(PALE, 1, 3, plank_tex(4, 'y'))
M_IRON = Mat(IRON, 1, 3)
M_IRON_L = Mat(IRON, 0, 2)
M_ROPE = Mat(ROPE, 0, 2, rope_tex, edge=False)
M_COIL = Mat(ROPE, 0, 2, lambda x, y, z, face: x % 2)
M_HIDE = Mat(HIDE, 1, 3, hide_tex)
M_STONE = Mat(STONE, 1, 4, speckle(5, 60))
M_LEATHER = Mat(LEATHER, 1, 2)
M_DARK = Mat(DARK, 0, 2, edge=False)


class Model:
    """Blocks at whole (x, y, z): x east, y south, z up. Built facing north."""

    def __init__(self):
        self.v = {}
        self.parts = 0

    def part(self):
        self.parts += 1
        return self.parts

    def put(self, x, y, z, mat, part):
        self.v[(x, y, z)] = (mat, part, x, y, z)

    def box(self, x0, y0, z0, x1, y1, z1, mat, part=None):
        part = part or self.part()
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                for z in range(z0, z1 + 1):
                    self.put(x, y, z, mat, part)
        return part

    def beam(self, p0, p1, mat, w=2, d=2, h=2, part=None):
        """A straight timber from p0 to p1, w wide (x), d deep (y), h high."""
        part = part or self.part()
        n = int(max(abs(p1[i] - p0[i]) for i in range(3)) * 2) + 1
        for i in range(n + 1):
            t = i / n
            x, y, z = (p0[k] + (p1[k] - p0[k]) * t for k in range(3))
            xa, ya, za = (int(math.floor(c - (s - 1) / 2 + 0.5)) for c, s in ((x, w), (y, d), (z, h)))
            for xx in range(xa, xa + w):
                for yy in range(ya, ya + d):
                    for zz in range(max(za, 0), za + h):
                        self.put(xx, yy, zz, mat, part)
        return part

    def roll_x(self, x0, x1, cy, cz, r, mat, part=None):
        """A round log or wheel lying east-west."""
        part = part or self.part()
        for y in range(int(cy - r - 1), int(cy + r + 2)):
            for z in range(int(cz - r - 1), int(cz + r + 2)):
                if z >= 0 and (y - cy) ** 2 + (z - cz) ** 2 <= r * r:
                    for x in range(x0, x1 + 1):
                        self.put(x, y, z, mat, part)
        return part

    def roll_y(self, y0, y1, cx, cz, r, mat, part=None):
        """A round log lying north-south."""
        part = part or self.part()
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            for z in range(int(cz - r - 1), int(cz + r + 2)):
                if z >= 0 and (x - cx) ** 2 + (z - cz) ** 2 <= r * r:
                    for y in range(y0, y1 + 1):
                        self.put(x, y, z, mat, part)
        return part

    def turned(self, d, cx, cy):
        """The blocks turned from north to face d, about (cx, cy)."""
        out = {}
        for (x, y, z), val in self.v.items():
            if d == 'S':
                x, y = 2 * cx - x, 2 * cy - y
            elif d == 'E':
                x, y = cx - (y - cy), cy + (x - cx)
            elif d == 'W':
                x, y = cx + (y - cy), cy - (x - cx)
            out[(int(x), int(y), z)] = val
        return out


def surface(vox, x, y, z):
    """Height of the top surface in column (x, y) near z, or z at an edge or
    a wall."""
    if (x, y, z + 3) in vox:
        return z
    for zz in (z + 2, z + 1, z, z - 1, z - 2):
        if (x, y, zz) in vox and (x, y, zz + 1) not in vox:
            return zz
    return z


def project(vox):
    """{(sx, sy): [mat, step, part, depth]} before any shift."""
    px = {}
    for key in sorted(vox, key=lambda k: (k[1], k[2])):
        x, y, z = key
        mat, part, cx, cy, cz = vox[key]
        depth = (y, z)
        shade = 0
        if any((x, y, z + k) in vox for k in range(2, 13)):
            shade += 1                               # under cover
        if (x, y + 1, z) not in vox:
            step = mat.front + shade + (mat.tex(cx, cy, cz, 'f') if mat.tex else 0)
            px[(x, y - z)] = [mat, step, part, depth]
        if (x, y, z + 1) not in vox:
            if any((x - k, y - k, z + k) in vox for k in (1, 2, 3)):
                shade += 1                           # cast shadow, light from the upper left
            slope = (surface(vox, x + 1, y, z) - surface(vox, x - 1, y, z)
                     + surface(vox, x, y + 1, z) - surface(vox, x, y - 1, z))
            step = mat.top + shade + (mat.tex(cx, cy, cz, 't') if mat.tex else 0)
            step += -1 if slope > 0 else (1 if slope < 0 else 0)
            px[(x, y - z - 1)] = [mat, step, part, depth]
    return px


def fit(models, d, w, h, centre):
    """Shift that centres the union of the turned models in a w x h cell."""
    xs, ys = [], []
    for m in models:
        for (sx, sy) in project(m.turned(d, *centre)):
            xs.append(sx)
            ys.append(sy)
    return (w - (max(xs) - min(xs) + 1)) // 2 - min(xs), (h - (max(ys) - min(ys) + 1)) // 2 - min(ys)


def render(model, d, w, h, shift, centre, edge=1):
    """Draw the model facing d. edge 2 lines every part in the darkest ramp
    colour like the catapult; edge 1 only darkens the far side of a join."""
    px = project(model.turned(d, *centre))
    im = Image.new('RGBA', (w, h))
    cells = {}
    for (sx, sy), (mat, step, part, depth) in px.items():
        if mat.edge:
            for q in ((sx + 1, sy), (sx - 1, sy), (sx, sy + 1), (sx, sy - 1)):
                o = px.get(q)
                if o and o[2] != part and o[3] > depth and o[0].edge:
                    step = len(mat.ramp) - 1 if edge == 2 else step + 2
                    break
        cells[(sx + shift[0], sy + shift[1])] = mat.ramp[max(0, min(len(mat.ramp) - 1, step))]
    return paint(cells, w, h)


def paint(cells, w, h, outline=True):
    """An image from {(x, y): rgb}, traced with the catapult's outline."""
    im = Image.new('RGBA', (w, h))
    if outline:
        for (x, y) in list(cells):
            for q in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if q not in cells:
                    cells[q] = OUT
    for (x, y), c in cells.items():
        if 0 <= x < w and 0 <= y < h:
            im.putpixel((x, y), c + (255,))
    return im


def four(models, w, h, centre, edge=1, fit_to=None, shift=None):
    """One frame set [S, N, E, W] per model, all sharing one fit per dir."""
    frames = []
    for m in models:
        row = []
        for d in DIRS:
            s = shift or fit(fit_to or models, d, w, h, centre)
            row.append(render(m, d, w, h, s, centre, edge))
        frames.append(row)
    return frames


# ------------------------------------------------------------ battering ram --

def ram_model(swing=0):
    """A pitched hide roof on four solid wheels, the iron-capped log slung
    under the ridge with its head to the north."""
    m = Model()
    for x0 in (7, 23):
        for cy in (11, 22):
            p = m.roll_x(x0, x0 + 1, cy, 2, 2.3, M_WOOD_D)
            m.put(x0 if x0 == 7 else x0 + 1, cy, 2, M_IRON, p)
    m.box(9, 8, 2, 10, 25, 3, M_WOOD)
    m.box(21, 8, 2, 22, 25, 3, M_WOOD)
    m.box(9, 8, 2, 22, 9, 3, M_WOOD)
    m.box(9, 24, 2, 22, 25, 3, M_WOOD)
    for x in (9, 21):
        for y in (9, 23):
            m.box(x, y, 4, x + 1, y + 1, 5, M_WOOD_D)
    # the log, hung on two rope slings
    p = m.roll_y(7 + swing, 28 + swing, 15.5, 3.5, 1.6, M_PALE)
    m.roll_y(3 + swing, 7 + swing, 15.5, 3.5, 2.3, M_IRON)
    m.roll_y(2 + swing, 2 + swing, 15.5, 3.5, 1.3, M_IRON_L)
    m.box(14, 27 + swing, 2, 17, 27 + swing, 5, M_IRON)
    for y in (12, 21):
        m.box(15, y + swing // 2, 6, 16, y + swing // 2, 7, M_ROPE)
    # the roof
    roof = m.part()
    for x in range(8, 24):
        z = 5 + min(x - 8, 23 - x) // 2
        for y in range(9, 25):
            m.put(x, y, z, M_HIDE, roof)
    m.box(15, 8, 9, 16, 25, 9, M_WOOD)
    return m


def ram_states():
    rest = ram_model()
    swings = [ram_model(s) for s in (3, 0, -3, -1)]
    fit_to = [rest] + swings
    return [
        ('ram', four([rest], 32, 32, (15.5, 15.5), fit_to=fit_to), 0),
        ('ram_swing', four(swings, 32, 32, (15.5, 15.5), fit_to=fit_to), 1),
    ]


# ----------------------------------------------------------------- ballista --

def ballista_model(loaded=False):
    """A torsion bolt thrower: a stock on a timber stand, a spring frame with
    two rope bundles at the front and a bow arm from each."""
    m = Model()
    m.box(9, 9, 0, 22, 10, 1, M_WOOD_D)
    m.box(9, 23, 0, 22, 24, 1, M_WOOD_D)
    m.box(14, 9, 0, 17, 24, 1, M_WOOD_D)
    m.box(14, 14, 2, 17, 17, 3, M_WOOD)
    # stock with its slider groove
    stock = Mat(WOOD, 1, 4, lambda x, y, z, face: 3 if face == 't' and x in (15, 16) else 0)
    m.box(14, 5, 4, 17, 28, 5, stock)
    # spring frame, bundles and washers
    m.box(6, 6, 3, 25, 8, 7, M_WOOD)
    for x in (8, 21):
        p = m.box(x, 6, 2, x + 2, 8, 8, M_ROPE)
        m.box(x, 6, 9, x + 2, 8, 9, M_IRON, p)
    m.box(12, 6, 3, 13, 8, 7, M_IRON)
    m.box(18, 6, 3, 19, 8, 7, M_IRON)
    # arms and string
    back = 15 if loaded else 11
    tip_l, tip_r = (3 if loaded else 1, back, 5.5), (28 if loaded else 30, back, 5.5)
    m.beam((9, 7, 5.5), tip_l, M_PALE, 2, 2, 2)
    m.beam((22, 7, 5.5), tip_r, M_PALE, 2, 2, 2)
    nock = 25 if loaded else 12
    for tip, x in ((tip_l, 14), (tip_r, 17)):
        m.beam((tip[0], tip[1], 6), (x, nock, 6), M_ROPE, 1, 1, 1)
    m.box(14, nock, 6, 17, nock, 6, M_ROPE if not loaded else M_IRON)
    # windlass at the tail
    p = m.roll_x(12, 19, 28, 6, 1.5, M_WOOD_D)
    m.box(10, 28, 6, 11, 28, 6, M_IRON, p)
    m.box(20, 28, 6, 21, 28, 6, M_IRON, p)
    m.box(10, 28, 7, 10, 28, 8, M_IRON, p)
    m.box(21, 28, 4, 21, 28, 5, M_IRON, p)
    if loaded:
        p = m.box(15, 5, 6, 16, 22, 8, Mat(PALE, 0, 2))
        m.box(15, 1, 6, 16, 4, 8, M_IRON_L, p)
        m.box(14, 3, 7, 17, 4, 8, M_IRON, p)
        m.box(14, 21, 7, 17, 24, 8, M_LEATHER, p)
        m.box(15, 21, 8, 16, 24, 8, Mat(PALE, 0, 2), p)
    return m


def ballista_states():
    a, b = ballista_model(), ballista_model(True)
    return [
        ('ballista', four([a], 32, 32, (15.5, 15.5), fit_to=[a, b]), 0),
        ('ballista_loaded', four([b], 32, 32, (15.5, 15.5), fit_to=[a, b]), 0),
    ]


# -------------------------------------------------------------------- winch --

def winch_model():
    """A windlass: a rope drum between two timber cheeks with a crank handle
    at each end."""
    m = Model()
    for x in (6, 23):
        m.box(x, 9, 0, x + 2, 24, 1, M_WOOD_D)
        m.beam((x + 1, 11, 2), (x + 1, 16.5, 9), M_WOOD, 3, 2, 2)
        m.beam((x + 1, 22, 2), (x + 1, 16.5, 9), M_WOOD, 3, 2, 2)
    m.box(6, 22, 0, 25, 24, 1, M_WOOD_D)
    m.roll_x(9, 22, 16.5, 8, 2.6, M_WOOD_D)
    m.roll_x(11, 20, 16.5, 8, 3.6, M_COIL)
    # the fall running off the drum to the gate
    m.beam((16, 13, 9), (16, 5, 1), M_ROPE, 1, 1, 1)
    # cranks, opposed
    p = m.box(3, 16, 8, 5, 17, 8, M_IRON)
    m.box(3, 16, 9, 3, 17, 13, M_IRON, p)
    m.box(1, 16, 13, 3, 17, 13, M_PALE, p)
    p = m.box(26, 16, 8, 28, 17, 8, M_IRON)
    m.box(28, 16, 3, 28, 17, 7, M_IRON, p)
    m.box(28, 16, 3, 30, 17, 3, M_PALE, p)
    return m


def winch_state():
    m = winch_model()
    return ('winch', [[render(m, 'N', 32, 32, fit([m], 'N', 32, 32, (15.5, 15.5)), (15.5, 15.5))]], 0)


# -------------------------------------------------------------- flat pieces --

def turn2d(cells, d, size=32):
    out = {}
    for (x, y), c in cells.items():
        if d == 'S':
            x, y = size - 1 - x, size - 1 - y
        elif d == 'E':
            x, y = size - 1 - y, x
        elif d == 'W':
            x, y = y, size - 1 - x
        out[(x, y)] = c
    return out


def bolt_item():
    """The loose ballista bolt, lying from lower left to its head upper right."""
    c = {}
    for i in range(18):
        x, y = 6 + i, 25 - i
        c[(x, y)] = PALE[0]
        c[(x + 1, y)] = PALE[2]
    for (x, y), col in {(24, 7): IRON[1], (25, 7): IRON[2], (24, 6): IRON[0], (25, 6): IRON[1], (26, 6): IRON[2],
                        (25, 5): IRON[0], (26, 5): IRON[1], (27, 5): IRON[2], (26, 4): IRON[0], (27, 4): IRON[1],
                        (28, 3): IRON[0], (27, 3): IRON[0], (23, 7): IRON[2], (26, 7): IRON[3],
                        (27, 6): IRON[3]}.items():
        c[(x, y)] = col
    for i in range(4):                       # three leather vanes
        x, y = 5 + i, 26 - i
        c[(x - 1, y - 1)] = LEATHER[0]
        c[(x - 2, y - 2)] = LEATHER[1]
        c[(x + 2, y + 1)] = LEATHER[2]
        c[(x + 2, y + 2)] = LEATHER[3]
        c[(x - 1, y - 2)] = LEATHER[1]
    c[(4, 27)] = PALE[3]
    c[(5, 26)] = PALE[1]
    return ('ballista_bolt', [[paint(c, 32, 32)]], 0)


def bolt_flight():
    """The bolt in the air, head to the north."""
    c = {}
    for y in range(10, 23):
        c[(15, y)] = PALE[0]
        c[(16, y)] = PALE[2]
    c.update({(15, 6): IRON[0], (16, 6): IRON[1], (15, 7): IRON[0], (16, 7): IRON[2],
              (14, 8): IRON[0], (15, 8): IRON[1], (16, 8): IRON[1], (17, 8): IRON[3],
              (14, 9): IRON[1], (15, 9): IRON[2], (16, 9): IRON[2], (17, 9): IRON[3]})
    for y in range(20, 25):
        c[(14, y)] = LEATHER[0 if y < 23 else 1]
        c[(17, y)] = LEATHER[2]
    c[(13, 23)] = c[(13, 24)] = LEATHER[1]
    c[(18, 23)] = c[(18, 24)] = LEATHER[3]
    return ('bolt_flight', [[paint(turn2d(c, d), 32, 32) for d in DIRS]], 0)


def portcullis(lift=0):
    """An oak grid of four-pixel bars, iron plates on every crossing and an
    iron-shod spike under each upright, standing in the gateway. `lift` is how
    far it has been drawn up out of the tile."""
    c = {}
    bars = (0, 7, 14, 21, 28)
    rails = (2, 10, 18)
    for bx in bars:
        for y in range(0, 25):
            c[(bx, y)] = OUT
            c[(bx + 1, y)] = WOOD[1] if noise(bx, y // 3, 0, 11) > 60 else WOOD[2]
            c[(bx + 2, y)] = WOOD[4] if noise(bx, y // 2, 1, 11) > 50 else WOOD[5]
            c[(bx + 3, y)] = OUT
        # the shoe and spike
        for y, row in ((25, (3, 1, 2, 4)), (26, (3, 0, 2, 4)), (27, (3, 1, 2, 4)),
                       (28, (None, 1, 3, None)), (29, (None, 1, 3, None)), (30, (None, 2, 4, None))):
            for i, k in enumerate(row):
                if k is not None:
                    c[(bx + i, y)] = IRON[k]
        c[(bx, 28)] = c[(bx + 3, 28)] = OUT
    for ry in rails:
        for x in range(32):
            if not any(b <= x < b + 4 for b in bars):
                c[(x, ry)] = OUT
                c[(x, ry + 1)] = WOOD[1] if noise(x // 3, ry, 2, 11) > 60 else WOOD[2]
                c[(x, ry + 2)] = WOOD[5]
                c[(x, ry + 3)] = OUT
        for bx in bars:                       # crossing plates
            for i in range(4):
                for j in range(4):
                    rim = i in (0, 3) or j in (0, 3)
                    c[(bx + i, ry + j)] = IRON[4] if rim else IRON[2]
            c[(bx + 1, ry + 1)] = IRON[0]
    out = {(x, y - lift): col for (x, y), col in c.items() if y - lift >= 0}
    # the foot of the spikes throws a line of shade on the sill while it hangs
    return paint(out, 32, 32, outline=False)


def portcullis_states():
    return [
        ('portcullis_closed', [[portcullis(0)]], 0),
        ('portcullis_open', [[portcullis(25)]], 0),
        ('portcullis_moving', [[portcullis(k)] for k in (5, 10, 15, 20)], 1),
    ]


# A portcullis several tiles wide is built from one-tile sections. Across a
# run the uprights stand every eight pixels (four of bar, four of gap), so a
# middle section tiles with itself and with both ends; an end section closes
# the run with a six-pixel stile in place of its outermost upright.
RUN_BARS = (2, 10, 18, 26)
RUN_RAILS = (2, 10, 18)
RUN_LIFTS = (5, 10, 15, 20)                  # the frames of portcullis_moving
SHOE = ((25, (3, 1, 2, 4)), (26, (3, 0, 2, 4)), (27, (3, 1, 2, 4)),
        (28, (None, 1, 3, None)), (29, (None, 1, 3, None)), (30, (None, 2, 4, None)))
STILE_SHOE = ((25, (3, 1, 1, 2, 2, 4)), (26, (3, 0, 1, 2, 2, 4)), (27, (3, 1, 1, 2, 2, 4)),
              (28, (None, 1, 1, 3, 3, None)), (29, (None, None, 1, 3, None, None)),
              (30, (None, None, 2, 4, None, None)))


def portcullis_section(end, lift=0):
    """One tile of a run along x. `end` is 'w' or 'e' for the section that
    closes the run on that side, 'c' for one with a neighbour on both sides."""
    c = {}
    bars = [b for b in RUN_BARS if not (end == 'w' and b == 2) and not (end == 'e' and b == 26)]
    stile = {'w': 0, 'e': 26}.get(end)
    for bx in bars:
        for y in range(0, 25):
            c[(bx, y)] = OUT
            c[(bx + 1, y)] = WOOD[1] if noise(bx, y // 3, 0, 11) > 60 else WOOD[2]
            c[(bx + 2, y)] = WOOD[4] if noise(bx, y // 2, 1, 11) > 50 else WOOD[5]
            c[(bx + 3, y)] = OUT
        for y, row in SHOE:
            for i, k in enumerate(row):
                if k is not None:
                    c[(bx + i, y)] = IRON[k]
        c[(bx, 28)] = c[(bx + 3, 28)] = OUT
    if stile is not None:
        for y in range(0, 25):
            c[(stile, y)] = OUT
            c[(stile + 1, y)] = WOOD[0] if noise(stile, y // 4, 3, 11) > 150 else WOOD[1]
            c[(stile + 2, y)] = WOOD[1] if noise(stile, y // 3, 0, 11) > 60 else WOOD[2]
            c[(stile + 3, y)] = WOOD[3] if noise(stile, y // 3, 4, 11) > 90 else WOOD[4]
            c[(stile + 4, y)] = WOOD[4] if noise(stile, y // 2, 1, 11) > 50 else WOOD[5]
            c[(stile + 5, y)] = OUT
        for y, row in STILE_SHOE:
            for i, k in enumerate(row):
                if k is not None:
                    c[(stile + i, y)] = IRON[k]
        c[(stile, 28)] = c[(stile + 5, 28)] = OUT
        c[(stile + 1, 29)] = c[(stile + 4, 29)] = OUT
    posts = [(b, 4) for b in bars] + ([(stile, 6)] if stile is not None else [])
    for ry in RUN_RAILS:
        for x in range(32):
            if not any(b <= x < b + w for b, w in posts):
                c[(x, ry)] = OUT
                # texture by the place along the run, so every join matches
                c[(x, ry + 1)] = WOOD[1] if noise((x + 2) % 8 // 3, ry, 2, 11) > 60 else WOOD[2]
                c[(x, ry + 2)] = WOOD[5]
                c[(x, ry + 3)] = OUT
        for bx, w in posts:                   # crossing plates
            for i in range(w):
                for j in range(4):
                    rim = i in (0, w - 1) or j in (0, 3)
                    c[(bx + i, ry + j)] = IRON[4] if rim else IRON[2]
            c[(bx + 1, ry + 1)] = IRON[0]
            if w == 6:
                c[(bx + 2, ry + 1)] = IRON[1]
    out = {(x, y - lift): col for (x, y), col in c.items() if y - lift >= 0}
    return paint(out, 32, 32, outline=False)


# A run along y is seen edge on from above: a six-pixel band down the middle
# of the tile, an iron plate where each upright stands (every eight pixels)
# and the head rail between them. As the grid is drawn up each upright shows
# less of its timber and more of its iron shoe and spike, until only the row
# of spikes hangs in the gateway.
EDGE_X = 13
EDGE_WOOD = (None, 1, 2, 4, 5, None)         # the band across x; None is the outline
EDGE_SHOE = ((3, 1, 1, 2, 2, 4), (3, 0, 1, 2, 2, 4), (3, 1, 1, 2, 2, 4),
             (None, 3, 1, 3, 4, None), (None, None, 1, 3, None, None), (None, None, 2, 4, None, None))


def edge_column(lift):
    """The eight rows of band that one upright shows at this lift, top row
    first; each row is six ramp entries or None for open air."""
    plate = [(IRON[4],) * 6, (IRON[4], IRON[0], IRON[1], IRON[2], IRON[2], IRON[4]),
             (IRON[4], IRON[2], IRON[2], IRON[2], IRON[3], IRON[4]), (IRON[4],) * 6]
    rail = [tuple(OUT if k is None else WOOD[k] for k in EDGE_WOOD)] * 4
    shoe = [tuple(None if k is None else IRON[k] for k in row) for row in EDGE_SHOE]
    rows = plate + rail + shoe + [(None,) * 6] * 8
    drop = (lift * 8 + 12) // 25                # 0 closed .. 8 open
    return rows[drop:drop + 8]


def portcullis_edge(end, lift=0):
    """One tile of a run along y. `end` is 'n' or 's' for the section that
    closes the run on that side, 'm' for one with a neighbour on both sides."""
    c = {}
    column = edge_column(lift)
    hanging = lift >= 25                       # drawn right up: only the spikes show
    for y in range(32):
        row = column[y % 8]
        for i, col in enumerate(row):
            if col is None:
                continue
            if col in WOOD and noise(i, y // 3, 5, 11) < 50:
                col = WOOD[WOOD.index(col) + 1]
            c[(EDGE_X + i, y)] = col
        for i in range(1, 5):                  # the outline down the sides of a spike
            if row[i] is not None:
                for q in (i - 1, i + 1):
                    if row[q] is None:
                        c[(EDGE_X + q, y)] = OUT
    # the end stile: an iron-bound head while any timber shows, a broader
    # shoe once only the spikes hang
    y0 = {'n': 0, 's': 24 if hanging else 21}.get(end)
    if y0 is not None and hanging:
        for j in (0, 1, 2):
            c[(EDGE_X - 1, y0 + j)] = IRON[3]
            c[(EDGE_X + 6, y0 + j)] = IRON[4]
    elif y0 is not None:
        for y in range(y0, 6 if end == 'n' else 32):
            for x in range(EDGE_X, EDGE_X + 6):
                c.pop((x, y), None)
        stile_cap(c, y0)
        if end == 's':                         # the south face of the stile, its shoe and spike
            for y, row in ((27, (6, 3, 4, 4, 5, 5, 6, 6)), (28, (6, 3, 4, 4, 5, 5, 6, 6))):
                for i, k in enumerate(row):
                    c[(EDGE_X - 1 + i, y)] = OUT if i in (0, 7) else WOOD[k]
            for y, row in ((29, (4, 3, 1, 1, 2, 2, 4, 4)), (30, (None, 4, 1, 1, 3, 3, 4, None)),
                           (31, (None, None, 4, 2, 4, 4, None, None))):
                for i, k in enumerate(row):
                    if k is not None:
                        c[(EDGE_X - 1 + i, y)] = IRON[k]
    return paint(c, 32, 32, outline=False)


def stile_cap(c, y0):
    """The iron-bound head of an end stile, eight wide and six deep."""
    for j in range(6):
        for i in range(8):
            x, y = EDGE_X - 1 + i, y0 + j
            if i in (0, 7) or j in (0, 5):
                col = OUT
            elif j in (1, 4):
                col = IRON[1] if i < 4 else IRON[3]
            else:
                col = (WOOD[0], WOOD[1], WOOD[1], WOOD[3], WOOD[4], WOOD[5])[i - 1]
            c[(x, y)] = col
    c[(EDGE_X, y0 + 1)] = IRON[0]


def portcullis_run_states():
    out = []
    for ends, draw in (('wce', portcullis_section), ('nms', portcullis_edge)):
        for name, lifts in (('closed', (0,)), ('open', (25,)), ('moving', RUN_LIFTS)):
            for end in ends:
                out.append(('portcullis_%s_%s' % (name, end), [[draw(end, k)] for k in lifts],
                            1 if len(lifts) > 1 else 0))
    return out


def drawbridge_down():
    """The lowered deck spanning north: cross planks between two stringers,
    two iron bands along it and a chain down each side."""
    c = {}
    for y in range(32):
        for x in range(3, 29):
            if x in (3, 28):
                col = OUT
            elif x in (4, 27):
                col = WOOD[4]
            elif x in (5, 26):
                col = WOOD[6]
            elif y % 4 == 3:
                col = PALE[4]
            else:
                col = PALE[1] if noise(x // 5, y // 4, 0, 21) > 90 else PALE[2]
                if noise(x, y, 0, 22) < 20:
                    col = PALE[3]
            c[(x, y)] = col
        for bx in (9, 21):
            c[(bx, y)] = IRON[1]
            c[(bx + 1, y)] = IRON[3]
            if y % 4 == 1:
                c[(bx, y)] = IRON[0]
        for cx in (1, 30):
            c[(cx, y)] = IRON[1] if y % 3 else IRON[4]
            if y % 3 == 1:
                c[(cx + (1 if cx == 1 else -1), y)] = IRON[3]
    for x in range(1, 31):                    # ring bolts at the far end
        if x in (1, 2, 29, 30):
            c[(x, 2)] = IRON[0]
    return ('drawbridge_down', [[paint(turn2d(c, d), 32, 32, outline=False) for d in DIRS]], 0)


def drawbridge_up():
    """The bridge hauled up against its gate. Spanning north or south it
    stands across the tile as a timber wall face (the deck from the south, the
    joists from the north); spanning east or west it stands along the tile's
    hinge edge and is seen from above, edge on."""
    frames = []
    for d in DIRS:
        c = {}
        if d in ('N', 'S'):
            for y in range(1, 31):
                for x in range(1, 31):
                    if y < 3:
                        col = PALE[0] if x % 5 else PALE[2]          # the top edge
                    elif x % 5 == 0:
                        col = WOOD[6]
                    else:
                        col = WOOD[2] if noise(x // 5, y // 6, 0, 31) > 100 else WOOD[3]
                        if noise(x, y, 0, 32) < 24:
                            col = WOOD[4]
                        if y == 30:
                            col = WOOD[6]
                    c[(x, y)] = col
            if d == 'N':                           # deck side: iron bands
                for by in (7, 22):
                    for x in range(1, 31):
                        c[(x, by)] = IRON[1]
                        c[(x, by + 1)] = IRON[3]
                        if x % 5 == 2:
                            c[(x, by)] = IRON[0]
            else:                                  # underside: joists
                for by in (8, 21):
                    for x in range(1, 31):
                        c[(x, by)] = WOOD[0]
                        c[(x, by + 1)] = WOOD[2]
                        c[(x, by + 2)] = WOOD[7]
            for cx in (3, 28):                     # chains from the top corners
                for y in range(0, 14):
                    c[(cx, y)] = IRON[0] if y % 3 else IRON[4]
                    if y % 3 == 1:
                        c[(cx + (1 if cx == 3 else -1), y)] = IRON[2]
                for dx in (-1, 0, 1):
                    for dy in (0, 1, 2):
                        c[(cx + dx, 13 + dy)] = IRON[3] if (dx, dy) != (0, 1) else IRON[0]
        else:
            x0 = 3 if d == 'E' else 23              # hinge edge: west for east, east for west
            for y in range(1, 31):
                for x in range(x0, x0 + 6):
                    if y < 22:                       # top edge seen from above
                        col = PALE[1] if y % 4 else PALE[4]
                        if x in (x0, x0 + 5):
                            col = WOOD[4]
                    else:                            # south end face
                        col = WOOD[4] if x % 2 else WOOD[5]
                        if y == 30:
                            col = WOOD[7]
                    c[(x, y)] = col
                if y in (3, 4, 18, 19):
                    for x in range(x0, x0 + 6):
                        c[(x, y)] = IRON[1] if y in (3, 18) else IRON[3]
            cx = x0 - 2 if d == 'E' else x0 + 7      # chains to the gate behind it
            for by in (3, 18):
                for i in range(3):
                    x = cx - i if d == 'E' else cx + i
                    if 0 <= x < 32:
                        c[(x, by)] = IRON[0] if i % 2 == 0 else IRON[3]
                c[(cx + (1 if d == 'E' else -1), by)] = IRON[0]
        frames.append(paint(c, 32, 32))
    return ('drawbridge_up', [frames], 0)


def murder_hole():
    """A stone floor slab with a dark square opening; the north side of the
    shaft shows below the lip."""
    c = {}
    for y in range(32):
        for x in range(32):
            n = noise(x, y, 0, 41)
            col = STONE[2] if n > 90 else (STONE[3] if n > 22 else STONE[1])
            if x in (0, 31) or y in (0, 31):
                col = STONE[5]
            elif x == 1 or y == 1:
                col = STONE[0]
            elif x == 30 or y == 30:
                col = STONE[4]
            elif (y == 16 and (x < 9 or x > 22)) or (x == 16 and (y < 9 or y > 22)):
                col = STONE[5]                       # slab joints
            c[(x, y)] = col
    for y in range(9, 23):
        for x in range(9, 23):
            if x in (9, 22) or y in (9, 22):
                col = STONE[0] if (y == 22 or x == 22) else STONE[5]   # the lip
            elif y < 14:
                col = STONE[5] if (x + y // 2) % 4 else STONE[6]      # shaft wall
                if y == 13:
                    col = STONE[6]
            else:
                col = DARK[min(3, (y - 14) // 2)]
            c[(x, y)] = col
    return ('murder_hole', [[paint(c, 32, 32, outline=False)]], 0)


# ---------------------------------------------------------------- trebuchet --

TREB_AXLE = (31, 12)          # y, z of the pivot


def arm_point(r, deg):
    """A point r along the throwing arm (r > 0 the long end) at angle deg:
    0 lies level to the rear, 90 stands up, 180 lies forward. Heights are
    halved, as the view looks down on the engine."""
    a = math.radians(deg)
    return TREB_AXLE[0] + r * math.cos(a), TREB_AXLE[1] + 0.5 * r * math.sin(a)


def trebuchet_model(deg=-40, sling=None, stone=None):
    """A-frames on a sill frame, the arm on its axle, the counterweight box
    hung from the short end and the sling from the long end. `sling` is the
    (y, z) of the pouch, `stone` the (y, z) of the stone or None."""
    m = Model()
    # sills and the sling trough
    for x in (9, 50):
        m.box(x, 6, 0, x + 4, 58, 2, M_WOOD)
    m.box(9, 6, 0, 54, 10, 2, M_WOOD)
    m.box(9, 54, 0, 54, 58, 2, M_WOOD)
    m.box(27, 11, 0, 36, 53, 0, Mat(WOOD, 4, 5, plank_tex(5, 'y')))
    # windlass at the rear
    m.roll_x(18, 45, 50, 4, 1.6, M_WOOD_D)
    for x in (16, 46):
        m.box(x, 49, 0, x + 1, 51, 5, M_WOOD)
    # A-frames and axle
    ya, za = TREB_AXLE
    for x in (11, 52):
        m.beam((x, 13, 3), (x, ya, za), M_WOOD, 3, 3, 2)
        m.beam((x, 49, 3), (x, ya, za), M_WOOD, 3, 3, 2)
        m.beam((x, 22, 6), (x, 40, 6), M_WOOD_D, 3, 2, 1)
    p = m.box(8, ya - 1, za, 55, ya + 1, za + 1, M_WOOD_D)
    for x in (7, 56):
        m.box(x, ya - 1, za, x, ya + 1, za + 1, M_IRON, p)
    # counterweight box under the short end
    sy, sz = arm_point(-9, deg)
    top = max(8, int(round(sz)) - 2)
    cy = int(round(sy))
    box = Mat(WOOD, 2, 4, lambda x, y, z, face: 0)
    p = m.box(23, cy - 5, top - 7, 40, cy + 5, top, box)
    for x in (26, 27, 36, 37):
        m.box(x, cy - 5, top - 7, x, cy + 5, top, M_IRON, p)
    m.box(24, cy - 4, top + 1, 39, cy + 4, top + 1, M_STONE, p)
    for x in range(24, 40):
        for y in range(cy - 4, cy + 5):
            if noise(x // 2, y // 2, 0, 51) < 90:
                m.put(x, y, top + 2, M_STONE, p)
    # the arm
    ly, lz = arm_point(27, deg)
    arm = m.beam((31.5, sy, sz + 1), (31.5, ly, lz + 1), M_PALE, 4, 3, 2)
    m.box(29, ya - 1, za + 2, 34, ya + 1, za + 3, M_IRON)
    m.beam((31.5, ly, lz + 1), (31.5, ly, lz + 1), M_IRON, 4, 2, 2, arm)
    # sling
    if sling:
        py, pz = sling
        for x in (31, 32):
            m.beam((x, ly, lz + 1), (x, py, pz), M_ROPE, 1, 1, 1)
        m.box(30, int(round(py)) - 2, int(round(pz)), 33, int(round(py)) + 1, int(round(pz)), M_LEATHER)
    if stone:
        qy, qz = int(round(stone[0])), int(round(stone[1]))
        p = m.box(30, qy - 2, qz + 1, 33, qy + 1, qz + 2, M_STONE)
        m.box(31, qy - 1, qz + 3, 32, qy, qz + 3, Mat(STONE, 0, 3), p)
        m.box(31, qy - 3, qz + 1, 32, qy + 2, qz + 2, M_STONE, p)
        m.box(29, qy - 1, qz + 1, 34, qy, qz + 2, M_STONE, p)
    return m


# arm angle per frame of the throw, and how far the sling trails behind it
TREB_SWING = (-40, -32, -14, 12, 42, 72, 98, 114, 106, 98, 88, 66, 40, 14, -12, -32)
TREB_TRAIL = (None, 150, 120, 85, 50, 22, 4)


def trebuchet_pose(i):
    deg = TREB_SWING[i]
    ly, lz = arm_point(27, deg)
    rest = (ly - 14, 1)
    if i == 0:
        return deg, rest, rest
    if i < len(TREB_TRAIL):
        a = math.radians(deg - TREB_TRAIL[i])
        pouch = (ly + 12 * math.cos(a), max(1, lz + 6 * math.sin(a)))
        return deg, pouch, pouch
    # thrown: the pouch hangs and swings under the arm, the stone flies north
    k = i - len(TREB_TRAIL)
    sway = (5, 2, -2, -4, -3, -2, 0, 0, 0)[k]
    pouch = (ly + sway, max(1, lz - 6)) if deg > 0 else (ly - 12, 1)
    release = arm_point(27, TREB_SWING[len(TREB_TRAIL) - 1])
    stone = (release[0] - 16 - 15 * (k + 1), release[1] + 8 + 2 * k) if k < 2 else None
    return deg, pouch, stone


def trebuchet_states():
    centre = (31.5, 31.5)
    empty = trebuchet_model(-40, trebuchet_pose(0)[1])
    loaded = trebuchet_model(*trebuchet_pose(0))
    upright = trebuchet_model(90, (arm_point(27, 90)[0], arm_point(27, 90)[1] + 4))
    fit_to = [empty, upright]
    fire = []
    for i in range(16):
        deg, pouch, stone = trebuchet_pose(i)
        fire.append(trebuchet_model(deg, pouch, stone))
    return [
        ('trebuchet0', four([empty], 64, 64, centre, 2, fit_to), 0),
        ('trebuchet1', four([loaded], 64, 64, centre, 2, fit_to), 0),
        ('trebuchet_fire', four(fire, 64, 64, centre, 2, fit_to), 0.4),
    ]


# -------------------------------------------------------------- siege tower --

def wall_tex(x, y, z, face):
    """Hide cladding between the storey beams, with arrow slits."""
    return hide_tex(x, y, z, face)


def siege_tower_model(bridge_down=False):
    """An 18 x 18 timber tower on four solid wheels, three storeys clad in
    hides, an open fighting deck on top and a drop bridge hinged at the deck
    on the north face."""
    m = Model()
    for x0 in (-2, 18):
        for cy in (3, 14):
            p = m.roll_x(x0, x0 + 1, cy, 3, 3.2, M_WOOD_D)
            m.put(x0 if x0 < 0 else x0 + 1, cy, 3, M_IRON, p)
    m.box(0, 0, 3, 17, 17, 5, M_WOOD)
    hide = m.part()
    frame = m.part()
    dark = m.part()
    top = 34
    for z in range(6, top + 1):
        for x in range(18):
            for y in range(18):
                edge_x, edge_y = x in (0, 17), y in (0, 17)
                if not (edge_x or edge_y):
                    continue
                if z > 27 and y == 0 and 1 < x < 16:
                    continue                          # the bridge closes this side
                a = y if edge_x else x                # position along the wall
                if (edge_x and edge_y) or (edge_x and y in (1, 16)) or (edge_y and x in (1, 16)):
                    m.put(x, y, z, M_WOOD, frame)     # corner posts
                elif z in (6, 13, 20, 27, top):
                    m.put(x, y, z, M_WOOD, frame)     # storey beams
                elif y == 17 and 6 <= x <= 11 and z < 13:
                    m.put(x, y, z, M_DARK if z % 2 else M_WOOD_D, dark)   # rear door and ladder
                elif a in (8, 9) and z in (16, 17, 18, 23, 24, 25):
                    m.put(x, y, z, M_DARK, dark)      # arrow slits
                else:
                    m.put(x, y, z, M_HIDE, hide)
    # fighting deck
    m.box(1, 1, 27, 16, 16, 27, M_DECK)
    # gallows posts and lintel for the bridge ropes
    m.box(0, 0, 28, 1, 1, 40, M_WOOD)
    m.box(16, 0, 28, 17, 1, 40, M_WOOD)
    m.box(0, 0, 41, 17, 1, 41, M_WOOD_D)
    plank = Mat(PALE, 1, 2, lambda x, y, z, face: 2 if x % 4 == 1 else (1 if noise(x, y, z, 61) < 30 else 0))
    if bridge_down:
        p = m.box(2, -7, 27, 15, -1, 27, plank)
        m.box(2, -7, 27, 15, -7, 28, M_IRON, p)
        m.box(2, -4, 27, 15, -4, 27, M_IRON, p)
        for x in (2, 15):
            m.beam((x, -6, 28), (x, 0, 40), M_ROPE, 1, 1, 1)
    else:
        p = m.box(2, 0, 28, 15, 0, 36, plank)
        m.box(2, 0, 36, 15, 0, 36, M_IRON, p)
        m.box(2, 0, 32, 15, 0, 32, M_IRON, p)
        for x in (2, 15):
            m.beam((x, 0, 37), (x, 0, 40), M_ROPE, 1, 1, 1)
    return m


TOWER_SHIFT = (7, 43)       # model (0, 0, 0) on the cell: base on the bottom-left tile


def tower_states():
    centre = (8.5, 8.5)
    return [
        ('siege_tower', four([siege_tower_model()], 64, 64, centre, 1, shift=TOWER_SHIFT), 0),
        ('siege_tower_bridge', four([siege_tower_model(True)], 64, 64, centre, 1, shift=TOWER_SHIFT), 0),
    ]


# ------------------------------------------------------------------- sheets --

def engine_states():
    """[(state, frames, delay)]; frames is a list of per-frame dir lists."""
    out = ram_states() + ballista_states()
    out += [bolt_item(), bolt_flight(), winch_state()]
    out += portcullis_states()
    out += portcullis_run_states()
    out += [drawbridge_down(), drawbridge_up(), murder_hole()]
    return out


def sheets():
    return [(ENGINES, 32, engine_states()), (TREBUCHET, 64, trebuchet_states()), (TOWER, 64, tower_states())]


def build(size, states):
    icons = [im for _, frames, _ in states for row in frames for im in row]
    cols = int(len(icons) ** 0.5 + 0.999)
    rows = (len(icons) + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * size, rows * size))
    for i, im in enumerate(icons):
        sheet.paste(im, ((i % cols) * size, (i // cols) * size))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = %d\n\theight = %d\n' % (size, size)
    for name, frames, delay in states:
        text += 'state = "%s"\n\tdirs = %d\n\tframes = %d\n' % (name, len(frames[0]), len(frames))
        if len(frames) > 1:
            text += '\tdelay = %s\n\tloop = 1\n' % ','.join(['%g' % delay] * len(frames))
    text += '# END DMI\n'
    return sheet, text


def write_dmi(path, sheet, text):
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, 'PNG', pnginfo=meta, optimize=True)


def same(path, sheet, text):
    if not path.exists():
        return False
    old = Image.open(path)
    return old.info.get('Description') == text and old.size == sheet.size \
        and old.convert('RGBA').tobytes() == sheet.tobytes()


def preview(path, built, scale=4):
    """Every state, direction and frame at 4x on grass, each cell labelled;
    the catapult stands at the top for scale."""
    grass = (98, 122, 78, 255)
    pad, label = 6, 12
    rows = []                                   # (title, size, [(caption, image)])
    cat = Image.open(ROOT / 'icons/obj/catapult.dmi').convert('RGBA')
    rows.append(('catapult.dmi catapult0 (existing, for scale)', 64,
                 [(d, cat.crop((i * 64, 0, i * 64 + 64, 64))) for i, d in enumerate(DIRS)]))
    for sheet_path, size, states in built:
        singles = []
        for name, frames, delay in states:
            dirs = len(frames[0])
            if len(frames) == 1 and dirs == 1:
                singles.append((name, frames[0][0]))
                continue
            if len(frames) == 1:
                rows.append(('%s  %s' % (sheet_path.name, name), size,
                             [(DIRS[i], im) for i, im in enumerate(frames[0])]))
                continue
            for i in range(dirs):
                who = DIRS[i] if dirs == 4 else ''
                rows.append(('%s  %s %s (%d frames, delay %g, loop 1)' % (sheet_path.name, name, who,
                                                                           len(frames), delay), size,
                             [('%s%d' % (who, k + 1), fr[i]) for k, fr in enumerate(frames)]))
        if singles:
            rows.append(('%s  single states' % sheet_path.name, size, singles))
    width = pad + max(len(cells) * (size * scale + pad) for _, size, cells in rows)
    height = pad + sum(label + label + size * scale + pad for _, size, _ in rows)
    out = Image.new('RGBA', (width, height), (24, 24, 24, 255))
    draw = ImageDraw.Draw(out)
    y = pad
    for title, size, cells in rows:
        draw.text((pad, y), title, fill=(240, 240, 240, 255))
        y += label
        for i, (caption, im) in enumerate(cells):
            x = pad + i * (size * scale + pad)
            draw.text((x, y), caption, fill=(200, 220, 160, 255))
            tile = Image.new('RGBA', (size * scale, size * scale), grass)
            if size == 64:                       # mark the four 32px tiles of the cell
                d2 = ImageDraw.Draw(tile)
                d2.line((32 * scale, 0, 32 * scale, 64 * scale), fill=(88, 110, 70, 255))
                d2.line((0, 32 * scale, 64 * scale, 32 * scale), fill=(88, 110, 70, 255))
            tile.alpha_composite(im.resize((size * scale, size * scale), Image.NEAREST))
            out.paste(tile, (x, y + label))
        y += label + size * scale + pad
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    out.save(path)


def runs_preview(path, states, scale=4):
    """Assembled portcullis runs at 4x on a stone floor: one, three and five
    tiles wide and three tiles tall, each closed and open."""
    icon = {name: frames[0][0] for name, frames, _ in states}
    slab = icon['murder_hole'].copy()
    patch = slab.crop((2, 2, 9, 30))             # plain slab to cover the opening
    for x in range(9, 23, 7):
        slab.paste(patch, (x, 2))
    pad, label = 8, 12

    def across(n):
        return ['portcullis_%s'] if n == 1 else ['portcullis_%s_' + e for e in 'w' + 'c' * (n - 2) + 'e']

    groups = [('%d wide' % n, [(i, 0, s) for i, s in enumerate(across(n))], n, 1) for n in (1, 3, 5)]
    groups.append(('3 tall', [(0, i, 'portcullis_%s_' + e) for i, e in enumerate('nms')], 1, 3))
    width = pad + sum(w * 32 * scale + pad for _, _, w, _ in groups)
    height = pad + 2 * (label + 3 * 32 * scale + pad)
    out = Image.new('RGBA', (width, height), (24, 24, 24, 255))
    draw = ImageDraw.Draw(out)
    y = pad
    for state in ('closed', 'open'):
        x = pad
        for title, cells, w, h in groups:
            draw.text((x, y), '%s, %s' % (title, state), fill=(240, 240, 240, 255))
            tile = Image.new('RGBA', (w * 32, 3 * 32))
            for tx in range(w):
                for ty in range(3):
                    tile.paste(slab, (tx * 32, ty * 32))
            for tx, ty, name in cells:
                tile.alpha_composite(icon[name % state], (tx * 32, (ty if h == 3 else 1) * 32))
            out.paste(tile.resize((tile.width * scale, tile.height * scale), Image.NEAREST), (x, y + label))
            x += w * 32 * scale + pad
        y += label + 3 * 32 * scale + pad
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    out.save(path)


def main(argv):
    built = sheets()
    if '--check' in argv:
        for path, size, states in built:
            if not same(path, *build(size, states)):
                sys.exit('stale sheet: ' + str(path))
        print('siege engine sheets match')
    else:
        for path, size, states in built:
            write_dmi(path, *build(size, states))
            print('wrote %s (%d states)' % (path.relative_to(ROOT), len(states)))
    if '--preview' in argv:
        preview(argv[argv.index('--preview') + 1], built)
    if '--runs' in argv:
        runs_preview(argv[argv.index('--runs') + 1], built[0][2])


if __name__ == '__main__':
    main(sys.argv[1:])
