"""Hand-placed art for horses: the four horse coats in icons/mob/animal_64.dmi
(states "horse", "horse2" black, "horse3" dun and "horse4" white, each with
its "_dead" and "_riding" state), their foals ("foal", "foal2", "foal3",
"foal4" and the "_dead" states, appended to the same sheet) and
icons/obj/horseshoes.dmi ("horseshoe", "horseshoe_worn"). Every other state
of animal_64.dmi is left untouched and keeps its place. Every pixel is
placed by this script from fixed palettes and a fixed hash (Pillow only); no
external or generated artwork.

A horse is built from ellipses and tapered limbs. Each part carries a
surface direction, so one light from the upper left gives the four coat
tones in every view; an outline pass then darkens the silhouette and the
line where a nearer part crosses a farther one.

Placement in the 64 x 64 cell is the one the game already relies on: hooves
on the bottom row, body centred on x = 29, and the adult's back at y = 25 in
the side views, so a rider drawn with ride_pixel_x = -13, ride_pixel_y = -21
(the rider's 32 x 32 icon covers x 13..44, y 11..42 of the cell) sits on it.
"<horse>_riding" is the overlay drawn over the rider: the head, neck, chest
and forelegs when the horse faces south, the croup, tail and hind legs when
it faces north, and nothing in the side views. Foals stand on the same
ground line and centre.

    python3 tests/sprites/create_horses.py [--check] [--preview PNG [--before DMI]]

`--check` writes nothing and fails when a committed sheet differs from what
this script draws. `--preview <png>` writes a 4x before and after sheet;
"before" is animal_64.dmi as it was when the script started, or the sheet
given with `--before`.
Released under Civ13 AGPL-3.0.
"""
import math
import re
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/mob/animal_64.dmi'
SHOES = ROOT / 'icons/obj/horseshoes.dmi'
CELL = 64
GROUND = 63
CX = 29

# coat / points / muzzle: light, base, shade, deep, outline.  mane: light,
# base, deep, outline.  hoof: light, dark.
COATS = {
    'horse': dict(  # bay: brown with black mane, tail and lower legs
        coat=((184, 104, 60), (148, 74, 42), (112, 52, 32), (82, 38, 26), (42, 20, 14)),
        points=((92, 62, 50), (62, 42, 36), (42, 29, 27), (28, 20, 20), (14, 10, 10)),
        muzzle=((120, 76, 56), (88, 54, 42), (64, 40, 33), (46, 29, 26), (26, 15, 13)),
        mane=((74, 64, 64), (44, 38, 40), (25, 21, 23), (10, 8, 10)),
        hoof=((84, 74, 66), (46, 39, 35)), eye=(16, 10, 8)),
    'horse2': dict(  # black
        coat=((98, 94, 108), (66, 62, 75), (46, 43, 54), (31, 29, 38), (12, 11, 17)),
        points=((98, 94, 108), (66, 62, 75), (46, 43, 54), (31, 29, 38), (12, 11, 17)),
        muzzle=((84, 80, 92), (56, 52, 64), (40, 37, 47), (27, 25, 33), (12, 11, 17)),
        mane=((70, 66, 80), (38, 35, 46), (21, 19, 27), (7, 6, 10)),
        hoof=((70, 68, 76), (34, 32, 38)), eye=(4, 4, 6)),
    'horse3': dict(  # dun: sandy beige with dark brown mane, tail and legs
        coat=((230, 211, 172), (199, 177, 138), (163, 141, 106), (128, 108, 82), (68, 54, 40)),
        points=((142, 116, 90), (106, 84, 66), (78, 61, 49), (56, 43, 35), (30, 22, 18)),
        muzzle=((176, 150, 120), (140, 116, 92), (108, 88, 70), (82, 66, 52), (48, 37, 29)),
        mane=((108, 88, 70), (72, 57, 47), (44, 34, 29), (22, 16, 14)),
        hoof=((104, 92, 80), (58, 49, 42)), eye=(24, 16, 12)),
    'horse4': dict(  # white / grey
        coat=((253, 253, 250), (228, 230, 232), (192, 196, 205), (154, 158, 171), (88, 90, 104)),
        points=((240, 240, 240), (206, 209, 214), (168, 172, 183), (132, 136, 150), (78, 80, 94)),
        muzzle=((214, 198, 198), (184, 166, 168), (150, 136, 142), (120, 110, 120), (74, 68, 80)),
        mane=((206, 208, 214), (160, 163, 174), (116, 119, 133), (64, 66, 80)),
        hoof=((120, 116, 114), (70, 67, 68)), eye=(24, 22, 28)),
}
FOAL_OF = {'foal': 'horse', 'foal2': 'horse2', 'foal3': 'horse3', 'foal4': 'horse4'}

_L = (-0.50, -0.66, 0.56)
_N = math.sqrt(sum(v * v for v in _L))
LIGHT = tuple(v / _N for v in _L)


def noise(x, y, seed=0):
    """A fixed 0..1 hash, so texture never changes between runs."""
    n = (int(x) * 374761393 + int(y) * 668265263 + seed * 1442695041) & 0xffffffff
    n = ((n ^ (n >> 13)) * 1274126177) & 0xffffffff
    return ((n ^ (n >> 16)) & 0xffff) / 65535.0


class Layer:
    """Parts drawn into a 64 x 64 cell, then toned and outlined in one pass.
    `k` shrinks everything toward (ox, oy) for the lying foal."""

    def __init__(self, k=1.0, ox=CX, oy=GROUND, rmin=0.0):
        self.px = {}      # (x, y) -> [material, light, depth]
        self.dots = {}    # (x, y) -> colour key or rgb, laid over the result
        self.k, self.ox, self.oy, self.rmin = k, ox, oy, rmin

    def _p(self, x, y):
        return self.ox + (x - self.ox) * self.k, self.oy + (y - self.oy) * self.k

    def _r(self, r):
        return max(self.rmin, r * self.k) if self.k != 1.0 else r

    def _set(self, x, y, mat, lum, z):
        if not (0 <= x < CELL and 0 <= y < CELL):
            return
        old = self.px.get((x, y))
        if old and old[2] == z and old[0] == mat:
            old[1] = max(old[1], lum)
        elif not old or z >= old[2]:
            self.px[(x, y)] = [mat, lum, z]

    def ell(self, cx, cy, rx, ry, mat='coat', z=3, dark=0.0):
        cx, cy = self._p(cx, cy)
        rx, ry = self._r(rx), self._r(ry)
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                nx, ny = (x - cx) / rx, (y - cy) / ry
                d2 = nx * nx + ny * ny
                if d2 <= 1.0:
                    nz = math.sqrt(1.0 - d2)
                    self._set(x, y, mat, nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2] - dark, z)

    def cap(self, x0, y0, r0, x1, y1, r1, mat='coat', z=3, dark=0.0):
        """A limb: a round-ended segment that tapers from r0 to r1."""
        x0, y0 = self._p(x0, y0)
        x1, y1 = self._p(x1, y1)
        r0, r1 = self._r(r0), self._r(r1)
        dx, dy = x1 - x0, y1 - y0
        ln = dx * dx + dy * dy or 1.0
        rm = max(r0, r1)
        for y in range(int(min(y0, y1) - rm) - 1, int(max(y0, y1) + rm) + 2):
            for x in range(int(min(x0, x1) - rm) - 1, int(max(x0, x1) + rm) + 2):
                t = max(0.0, min(1.0, ((x - x0) * dx + (y - y0) * dy) / ln))
                r = r0 + (r1 - r0) * t
                ox, oy = x - (x0 + dx * t), y - (y0 + dy * t)
                d2 = (ox * ox + oy * oy) / (r * r)
                if d2 <= 1.0:
                    nz = math.sqrt(1.0 - d2)
                    self._set(x, y, mat, ox / r * LIGHT[0] + oy / r * LIGHT[1] + nz * LIGHT[2] - dark, z)

    def path(self, pts, mat='coat', z=3, dark=0.0):
        """Joined limbs through (x, y, r) points."""
        for a, b in zip(pts, pts[1:]):
            self.cap(a[0], a[1], a[2], b[0], b[1], b[2], mat, z, dark)

    def hoof(self, x0, w, h, z=3, dark=0.0, toe=1):
        """A hoof standing on the ground line; toe = 1 points right, -1 left,
        0 is seen from the front or back."""
        if self.k != 1.0:
            return
        for i in range(h):
            y = GROUND - h + 1 + i
            a, b = x0, x0 + w - 1
            if i == 0 and h > 2:
                if toe >= 0:
                    b -= 1
                if toe <= 0:
                    a += 1
            for x in range(int(a), int(b) + 1):
                self._set(x, y, 'hoof', (0.6 if i == 0 else 0.1) - dark, z)

    def dot(self, x, y, colour):
        x, y = self._p(x, y)
        self.dots[(int(round(x)), int(round(y)))] = colour

    def image(self, pal, seed=0):
        im = Image.new('RGBA', (CELL, CELL), (0, 0, 0, 0))
        for (x, y), (mat, lum, z) in self.px.items():
            ramp = pal[mat]
            edge = under = False
            for qx, qy in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if not (0 <= qx < CELL and 0 <= qy < CELL):
                    continue
                other = self.px.get((qx, qy))
                if other is None:
                    edge = True
                elif other[2] > z:
                    under = True
            if mat == 'hoof':
                c = ramp[1] if (edge or lum < 0.4) else ramp[0]
            elif mat == 'mane':
                i = 0 if lum > 0.62 else 1 if lum > 0.12 else 2
                if i < 2 and noise(x, y // 2, seed + 5) < 0.22:
                    i += 1
                c = ramp[3] if edge else ramp[2] if under else ramp[i]
            else:
                i = 0 if lum > 0.83 else 1 if lum > 0.40 else 2 if lum > 0.02 else 3
                c = ramp[4] if edge else ramp[3] if under else ramp[i]
            im.putpixel((x, y), c + (255,))
        for (x, y), colour in self.dots.items():
            if (x, y) in self.px:
                im.putpixel((x, y), (pal[colour] if isinstance(colour, str) else colour) + (255,))
        return im


def over(*images):
    out = Image.new('RGBA', (CELL, CELL), (0, 0, 0, 0))
    for im in images:
        out.alpha_composite(im)
    return out


# ---------------------------------------------------------------------------
# The two builds. Lengths are pixels in the 64 x 64 cell.

ADULT = dict(
    foal=False,
    # side view, facing east
    barrel=(27, 33, 15, 8.5), haunch=(15.5, 32.5, 8.5, 9), shoulder=(37.5, 33.5, 7.5, 9.5), withers=(35, 27, 6, 3.5),
    neck=((39.5, 30, 7.6), (45, 22, 5.6), (49, 15, 4.3)), head=((49.5, 14.5, 4.4), (55, 19.5, 3.3), (58.5, 23, 2.7)),
    ear=((48.6, 11.5, 1.7), (49.2, 7.2, 0.5)), eye=(52, 15), nostril=(60, 23),
    mane=((47, 11.5, 2.2), (42, 17.5, 3.0), (37.5, 25, 2.6)), forelock=((49.5, 10.5, 1.3), (51.5, 13.5, 1.0)),
    tail=((7.5, 28.5, 2.0), (4.5, 34, 2.8), (3.5, 43, 3.0), (4.5, 51, 1.6)),
    fore=dict(x=38, top=39, knee=50, fet=58.5, ru=3.1, rk=2.3, rc=1.8, rf=2.1, far=4),
    hind=dict(x=15, top=37, hock=49.5, fet=58.5, back=4.5, rt=4.6, rk=2.5, rc=1.9, rf=2.1, far=4.5),
    hoof=(5, 3),
    # front (south) and back (north) views
    f_rump=(29, 24, 11, 14.5), f_chest=(29, 41, 10, 8.5), f_leg=dict(dx=5.5, top=44, knee=54, ru=3.2, rk=2.4, rc=2.0),
    f_hind=dict(dx=8.0, top=38, r=2.2, lift=3), f_neck=((29, 41, 6.5), (29, 31, 5.4)),
    f_head=((29, 28, 5.8), (29, 38.5, 4.0), (29, 42.5, 3.6)), f_ear=((4.4, 24.5, 1.8), (5.6, 20.0, 0.5)),
    f_eye=(4.0, 32), f_nostril=(1.6, 43.5), f_forelock=((29, 23.2, 1.7), (29.3, 26.6, 1.2)),
    f_mane=((34.5, 29, 2.4), (36.5, 39, 2.2)),
    b_head=(29, 8, 4.6, 5.0), b_ear=((3.3, 5, 1.7), (4.0, 0.8, 0.5)), b_neck=((29, 11, 4.8), (29, 23, 7.6)),
    b_barrel=(29, 31, 11, 12), b_rump=(29, 44.5, 11.5, 10), b_mane=((29, 5, 1.8), (29.3, 23, 2.2)),
    b_leg=dict(dx=6.5, top=50, hock=56, rt=3.6, rk=2.5, rc=2.0),
    b_tail=((29, 38, 2.0), (29, 46, 3.1), (29.3, 56.5, 1.8)),
)

FOAL = dict(
    foal=True,
    barrel=(27.5, 44.5, 9, 5.2), haunch=(20.5, 44, 5.3, 5.6), shoulder=(33.5, 44.8, 4.7, 5.8), withers=(32, 40.8, 3.5, 2.2),
    neck=((34.5, 42.5, 4.4), (37, 38, 3.4), (39, 33.5, 2.9)), head=((39.5, 32.5, 3.3), (43, 35.5, 2.7), (45.5, 38, 2.2)),
    ear=((38.8, 30.5, 1.5), (39.0, 27.2, 0.5)), eye=(41, 33), nostril=(46, 38),
    mane=((38, 30.5, 1.2), (35.5, 35, 1.4), (33, 40, 1.2)), forelock=((39.5, 29.8, 1.0), (40.5, 31, 0.8)),
    tail=((15.5, 42, 1.5), (13.5, 46, 1.9), (13.5, 50.5, 1.3)),
    fore=dict(x=34, top=48, knee=55, fet=60, ru=2.0, rk=1.8, rc=1.25, rf=1.5, far=2.5),
    hind=dict(x=20.5, top=46, hock=54.5, fet=60, back=2.5, rt=2.7, rk=1.8, rc=1.3, rf=1.5, far=3),
    hoof=(3, 2),
    f_rump=(29, 41, 6.6, 7.5), f_chest=(29, 49.5, 6, 4.8), f_leg=dict(dx=3.6, top=51, knee=57, ru=2.0, rk=1.8, rc=1.4),
    f_hind=dict(dx=5.6, top=46, r=1.6, lift=2), f_neck=((29, 49, 4.0), (29, 44, 3.4)),
    f_head=((29, 41.5, 4.1), (29, 47.5, 3.0), (29, 50, 2.6)), f_ear=((3.2, 39, 1.5), (4.0, 35.6, 0.5)),
    f_eye=(2.7, 43), f_nostril=(1.2, 50.6), f_forelock=((29, 38.2, 1.1), (29, 39.6, 0.9)),
    f_mane=None,
    b_head=(29, 31.5, 3.3, 3.6), b_ear=((2.4, 29.5, 1.4), (2.9, 26.4, 0.5)), b_neck=((29, 33.5, 3.0), (29, 40, 4.2)),
    b_barrel=(29, 44, 6.4, 7), b_rump=(29, 51, 6.8, 5.6), b_mane=((29, 30, 1.1), (29, 40, 1.2)),
    b_leg=dict(dx=4.0, top=54, hock=58.5, rt=2.2, rk=1.7, rc=1.4),
    b_tail=((29, 47.5, 1.5), (29, 51, 2.0), (29, 54.5, 1.3)),
)


def side_view(P, pal, seed=0):
    """Facing east."""
    c = Layer()
    hw, hh = P['hoof']
    F, H = P['fore'], P['hind']
    pastern = GROUND - hh + 0.4

    def fore(x, z, dark):
        c.path([(x, F['top'], F['ru']), (x, F['knee'], F['rk'] - 0.2)], 'coat', z, dark)
        c.ell(x + 0.2, F['knee'], F['rk'], F['rk'], 'coat', z, dark)
        c.path([(x, F['knee'], F['rc']), (x + 0.2, F['fet'], F['rc'])], 'points', z, dark)
        c.ell(x + 0.4, F['fet'], F['rf'], F['rf'], 'points', z, dark)
        c.cap(x + 0.4, F['fet'], F['rc'], x + 1.2, pastern, F['rc'], 'points', z, dark)
        c.hoof(round(x - hw / 2 + 1), hw, hh, z, dark)

    def hind(x, z, dark):
        hx = x - H['back']
        c.path([(x + 1.5, H['top'], H['rt']), (hx, H['hock'], H['rk'] - 0.2)], 'coat', z, dark)
        c.ell(hx - 0.3, H['hock'], H['rk'], H['rk'], 'coat', z, dark)
        c.path([(hx, H['hock'], H['rc']), (hx + 1.2, H['fet'], H['rc'])], 'points', z, dark)
        c.ell(hx + 1.4, H['fet'], H['rf'], H['rf'], 'points', z, dark)
        c.cap(hx + 1.4, H['fet'], H['rc'], hx + 2.2, pastern, H['rc'], 'points', z, dark)
        c.hoof(round(hx + 2 - hw / 2 + 1), hw, hh, z, dark)

    fore(F['x'] + F['far'], 1, 0.45)
    hind(H['x'] + H['far'], 1, 0.45)
    c.path(P['tail'], 'mane', 2)
    e = P['ear']
    c.cap(e[0][0] + 1.6, e[0][1] + 0.3, e[0][2], e[1][0] + 2.0, e[1][1] + 0.6, e[1][2], 'coat', 2, 0.5)
    c.ell(*P['barrel'])
    c.ell(*P['haunch'])
    c.ell(*P['shoulder'])
    c.ell(*P['withers'])
    c.path(P['neck'])
    c.path(P['head'][:2])
    c.path(P['head'][1:], 'muzzle')
    fore(F['x'], 3, 0.0)
    hind(H['x'], 3, 0.0)
    c.path(e)
    c.path(P['mane'], 'mane', 5)
    c.path(P['forelock'], 'mane', 5)
    c.dot(*P['eye'], 'eye')
    c.dot(*P['nostril'], pal['muzzle'][4])
    return c.image(pal, seed)


def front_view(P, pal, seed=0):
    """Facing south. Returns (body behind the rider, parts over the rider)."""
    hw, hh = P['hoof']
    back = Layer()
    G = P['f_hind']
    for s in (-1, 1):
        x = CX + s * G['dx']
        foot = GROUND - G['lift']
        back.path([(x, G['top'], G['r'] + 0.8), (x, foot - hh - 1, G['r'])], 'coat', 1, 0.4)
        for i in range(hh):
            for xx in range(int(round(x - hw / 2 + 0.5)), int(round(x - hw / 2 + 0.5)) + hw):
                back._set(xx, foot - hh + 1 + i, 'hoof', -0.4, 1)
    back.ell(*P['f_rump'], z=3)
    front = Layer()
    F = P['f_leg']
    for s in (-1, 1):
        x = CX + s * F['dx']
        front.path([(x, F['top'], F['ru']), (x, F['knee'], F['rk'] - 0.2)], 'coat', 2)
        front.ell(x, F['knee'], F['rk'], F['rk'], 'coat', 2)
        front.path([(x, F['knee'], F['rc']), (x, GROUND - hh, F['rc'])], 'points', 2)
        front.hoof(round(x - hw / 2 + 0.5), hw, hh, 2, toe=0)
    front.ell(*P['f_chest'], z=2)
    if P['f_mane']:
        front.path(P['f_mane'], 'mane', 3)
    front.path(P['f_neck'], 'coat', 3)
    e = P['f_ear']
    for s in (-1, 1):
        front.cap(CX + s * e[0][0], e[0][1], e[0][2], CX + s * e[1][0], e[1][1], e[1][2], 'coat', 4)
    front.path(P['f_head'][:2], 'coat', 4)
    front.path(P['f_head'][1:], 'muzzle', 4)
    front.path(P['f_forelock'], 'mane', 5)
    for s in (-1, 1):
        front.dot(CX + s * P['f_eye'][0], P['f_eye'][1], 'eye')
        front.dot(CX + s * P['f_nostril'][0], P['f_nostril'][1], pal['muzzle'][4])
    return back.image(pal, seed), front.image(pal, seed)


def back_view(P, pal, seed=0):
    """Facing north. Returns (body ahead of the rider, parts over the rider)."""
    hw, hh = P['hoof']
    far = Layer()
    e = P['b_ear']
    for s in (-1, 1):
        far.cap(CX + s * e[0][0], e[0][1], e[0][2], CX + s * e[1][0], e[1][1], e[1][2], 'coat', 2)
    far.ell(*P['b_head'], z=2)
    far.path(P['b_neck'], 'coat', 3)
    far.ell(*P['b_barrel'], z=3)
    far.path(P['b_mane'], 'mane', 5)
    near = Layer()
    B = P['b_leg']
    for s in (-1, 1):
        x = CX + s * B['dx']
        near.path([(x, B['top'], B['rt']), (x, B['hock'], B['rk'])], 'coat', 3)
        near.path([(x, B['hock'], B['rc']), (x, GROUND - hh, B['rc'])], 'points', 3)
        near.hoof(round(x - hw / 2 + 0.5), hw, hh, 3, toe=0)
    near.ell(*P['b_rump'], z=3)
    near.path(P['b_tail'], 'mane', 5)
    return far.image(pal, seed), near.image(pal, seed)


def dead_view(P, pal, seed=0):
    """Lying on its side, legs toward the viewer, head on the ground."""
    foal = P['foal']
    c = Layer(0.64, CX, 54, 1.25) if foal else Layer()
    pal = dict(pal)
    # far legs first, then the tail
    c.path([(34, 42, 3.0), (40, 50, 2.2)], 'coat', 1, 0.45)
    c.path([(40, 50, 1.9), (46.5, 58, 1.8)], 'points', 1, 0.45)
    c.path([(46.5, 58, 2.1), (48.5, 60, 2.0)], 'hoofp', 1)
    c.path([(12, 43, 4.0), (17, 51, 2.3)], 'coat', 1, 0.45)
    c.path([(17, 51, 1.9), (23.5, 59, 1.8)], 'points', 1, 0.45)
    c.path([(23.5, 59, 2.1), (25.5, 61, 2.0)], 'hoofp', 1)
    if foal:
        c.path([(7, 34, 1.9), (3.5, 37, 2.2), (2.5, 41, 1.5)], 'mane', 2)
    else:
        c.path([(7.5, 33, 2.0), (4, 36, 2.8), (2.5, 43, 2.8), (4, 49, 1.6)], 'mane', 2)
    c.ell(27, 36, 16, 8)
    c.ell(15, 35.5, 8.5, 8.5)
    c.ell(38, 36.5, 7.5, 8.5)
    c.path([(40, 35, 7.0), (47, 33, 5.2), (52, 32.5, 4.4)])
    c.path([(52.5, 32.5, 4.4), (57.5, 35, 3.4)])
    c.path([(57.5, 35, 3.4), (60.3, 37.5, 2.7)], 'muzzle')
    c.cap(50, 29.5, 1.7, 47.5, 26.5, 0.6)
    # near legs, stretched out stiff toward the viewer
    c.path([(39, 41, 3.1), (45, 48, 2.3)])
    c.path([(45, 48, 1.9), (52, 55.5, 1.8)], 'points')
    c.path([(52, 55.5, 2.2), (54, 57.5, 2.0)], 'hoofp')
    c.path([(17, 41, 4.4), (23, 49, 2.4)])
    c.path([(23, 49, 1.9), (30, 56.5, 1.8)], 'points')
    c.path([(30, 56.5, 2.2), (32, 58.5, 2.0)], 'hoofp')
    if foal:
        c.path([(49, 28.5, 1.5), (44, 29, 1.7), (39, 30, 1.4)], 'mane', 5)
    else:
        c.path([(50, 28, 2.0), (44, 28.5, 2.8), (38, 29.5, 2.4)], 'mane', 5)
        c.path([(44, 29, 2.2), (42, 33.5, 1.7)], 'mane', 5)
    c.dot(54, 32, pal['coat'][4])
    c.dot(55, 32, pal['coat'][4])
    h = pal['hoof']
    pal['hoofp'] = (h[0], h[0], h[1], h[1], tuple(v // 2 for v in h[1]))
    return c.image(pal, seed)


def horse_states():
    """name -> frames (south, north, east, west), in sheet order."""
    out = {}
    for n, (name, pal) in enumerate(COATS.items()):
        east = side_view(ADULT, pal, n)
        body_s, over_s = front_view(ADULT, pal, n)
        far_n, over_n = back_view(ADULT, pal, n)
        blank = Image.new('RGBA', (CELL, CELL), (0, 0, 0, 0))
        out[name] = [over(body_s, over_s), over(far_n, over_n), east, east.transpose(Image.FLIP_LEFT_RIGHT)]
        out[name + '_dead'] = [dead_view(ADULT, pal, n)]
        out[name + '_riding'] = [over_s, over_n, blank, blank.copy()]
    return out


def foal_states():
    out = {}
    for n, (name, parent) in enumerate(FOAL_OF.items()):
        pal = COATS[parent]
        east = side_view(FOAL, pal, n + 10)
        out[name] = [over(*front_view(FOAL, pal, n + 10)), over(*back_view(FOAL, pal, n + 10)),
                     east, east.transpose(Image.FLIP_LEFT_RIGHT)]
    for n, (name, parent) in enumerate(FOAL_OF.items()):
        out[name + '_dead'] = [dead_view(FOAL, COATS[parent], n + 10)]
    return out


# ---------------------------------------------------------------------------
# Horseshoes (32 x 32)

IRON = ((196, 202, 210), (146, 152, 162), (102, 108, 120), (66, 70, 82), (28, 30, 38))
RUST = ((176, 124, 84), (138, 88, 58), (104, 62, 44), (74, 44, 34), (36, 22, 18))
RUST_SPOTS = ((188, 104, 48), (120, 62, 30), (92, 84, 82))


def shoe(px, cx, cy, turn, ramp, z, worn=False, seed=0):
    """One horseshoe lying flat, with its six nail holes. `turn` is where the
    open heel points, in degrees (0 = east, 90 = down the icon)."""
    t = math.radians(turn)
    ct, st = math.cos(t), math.sin(t)
    for y in range(int(cy) - 9, int(cy) + 10):
        for x in range(int(cx) - 9, int(cx) + 10):
            dx, dy = x - cx, y - cy
            lx, ly = dx * ct + dy * st, -dx * st + dy * ct     # lx runs toe -> heel
            outer = (lx / 7.8) ** 2 + (ly / 6.6) ** 2
            inner = (lx / 3.7) ** 2 + (ly / 2.5) ** 2
            if outer > 1.0 or inner <= 1.0 or (lx > 0 and abs(ly) < 1.8) or lx > 6.6:
                continue
            if worn and lx < -5.6 and noise(x, y, seed) < 0.75:
                continue  # the toe is worn thin
            d = math.hypot(dx, dy) or 1.0
            lum = (dx * LIGHT[0] + dy * LIGHT[1]) / d * (1.0 if outer > 0.62 else -0.7)
            i = 0 if lum > 0.42 else 1 if lum > -0.1 else 2 if lum > -0.5 else 3
            c = ramp[i]
            if worn:
                n = noise(x, y, seed + 9)
                c = RUST_SPOTS[0] if n < 0.14 else RUST_SPOTS[1] if n < 0.28 else RUST_SPOTS[2] if n > 0.93 else c
            px[(x, y)] = [c, z]
    for k, deg in enumerate((78, 108, 138)):
        for s in (-1, 1):
            if worn and noise(k, s + 2, seed + 3) < 0.3:
                continue  # a hole packed with dirt
            a = math.radians(s * deg)
            lx, ly = math.cos(a) * 5.9, math.sin(a) * 4.7
            q = (int(round(cx + lx * ct - ly * st)), int(round(cy + lx * st + ly * ct)))
            if q in px and px[q][1] == z:
                px[q] = [ramp[4], z]


def shoe_pile(worn):
    ramp = RUST if worn else IRON
    px = {}
    places = ((8, 22, 100, 1), (23, 22, 75, 2), (16, 9, 10, 3)) if not worn else ((10, 21, 70, 1), (21, 11, 125, 2))
    for cx, cy, turn, z in places:
        shoe(px, cx, cy, turn, ramp, z, worn, seed=z * 7 + (40 if worn else 0))
    im = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
    for (x, y), (c, z) in px.items():
        edge = False
        for q in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            o = px.get(q)
            if o is None or o[1] != z:
                edge = True
        im.putpixel((x, y), (ramp[4] if edge else c) + (255,))
    return im


def shoe_states():
    return {'horseshoe': [shoe_pile(False)], 'horseshoe_worn': [shoe_pile(True)]}


def shoe_sheet(states):
    sheet = Image.new('RGBA', (32 * len(states), 32), (0, 0, 0, 0))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for i, (name, frames) in enumerate(states.items()):
        sheet.paste(frames[0], (i * 32, 0))
        text += 'state = "%s"\n\tdirs = 1\n\tframes = 1\n' % name
    return sheet, text + '# END DMI\n'


# ---------------------------------------------------------------------------
# Sheet patching

def read_sheet(path):
    """(image, description text, [(name, first cell, cell count)]). Handles
    animated states, which the simple readers in this folder do not."""
    im = Image.open(path)
    text = im.info.get('Description', '')
    im = im.convert('RGBA')
    index, cell = [], 0
    for block in re.split(r'(?m)^(?=state = )', text)[1:]:
        name = re.match(r'state = "([^"]*)"', block).group(1)
        n = int(re.search(r'dirs = (\d+)', block).group(1)) * int(re.search(r'frames = (\d+)', block).group(1))
        index.append((name, cell, n))
        cell += n
    return im, text, index


def cell_box(i, cols):
    return (i % cols * CELL, i // cols * CELL)


def patched_sheet(horses, foals, path=SHEET):
    """The animal sheet with the horse cells replaced and the foals appended."""
    old, text, index = read_sheet(path)
    cols = old.width // CELL
    where = {name: (first, n) for name, first, n in index}
    total = sum(n for _, _, n in index)
    for name, frames in horses.items():
        if where.get(name, (0, 0))[1] != len(frames):
            raise SystemExit('animal_64.dmi: state %s is missing or has changed shape' % name)
    for name, frames in foals.items():
        if name in where:
            if where[name][1] != len(frames):
                raise SystemExit('animal_64.dmi: state %s has changed shape' % name)
            continue
        where[name] = (total, len(frames))
        total += len(frames)
        text = text.replace('# END DMI', 'state = "%s"\n\tdirs = %d\n\tframes = 1\n# END DMI' % (name, len(frames)))
    rows = max(old.height // CELL, -(-total // cols))
    sheet = Image.new('RGBA', (old.width, rows * CELL), (0, 0, 0, 0))
    sheet.paste(old, (0, 0))
    for name, frames in list(horses.items()) + list(foals.items()):
        for k, fr in enumerate(frames):
            sheet.paste(fr, cell_box(where[name][0] + k, cols))
    return sheet, text


def save_dmi(path, sheet, text):
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta)


def same(path, sheet, text):
    if not path.exists():
        return False
    im = Image.open(path)
    return im.info.get('Description', '') == text and im.size == sheet.size and im.convert('RGBA').tobytes() == sheet.tobytes()


# ---------------------------------------------------------------------------
# Review sheet

def rider():
    """A plain stand-in for a rider, only for the review sheet."""
    im = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle((11, 10, 20, 20), fill=(70, 96, 150, 255), outline=(30, 44, 80, 255))
    d.rectangle((12, 21, 14, 30), fill=(66, 56, 50, 255))
    d.rectangle((17, 21, 19, 30), fill=(66, 56, 50, 255))
    d.ellipse((11, 1, 20, 10), fill=(232, 196, 162, 255), outline=(96, 64, 44, 255))
    return im


def frames_of(path):
    im, _, index = read_sheet(path)
    cols = im.width // CELL
    out = {}
    for name, first, n in index:
        out[name] = [im.crop(cell_box(first + k, cols) + tuple(v + CELL for v in cell_box(first + k, cols))) for k in range(n)]
    return out


def write_preview(path, before, horses, foals, shoes):
    zoom, pad, label = 4, 6, 14
    step = CELL + pad
    heads = ('south', 'north', 'east', 'west', 'dead', 'ridden S', 'ridden N', 'ridden E')
    half = len(heads) * step + 16
    rows = len(COATS) * 2 + 1
    w, h = half * 2, rows * (step + label) + 30
    im = Image.new('RGBA', (w, h), (0, 0, 0, 255))
    px = im.load()
    for y in range(h):
        for x in range(w):
            base = (100, 126, 78) if noise(x // 5, y // 5, 300) < 0.5 else (94, 120, 74)
            px[x, y] = ((82, 106, 64) if noise(x, y, 301) < 0.1 else base) + (255,)
    notes = []

    def cells(states, name, with_rider):
        base = states.get(name)
        if not base:
            return []
        out = list(base) + list(states.get(name + '_dead', []))
        if with_rider:
            cover = states[name + '_riding']
            for k in (0, 1, 2):
                c = base[k].copy()
                c.alpha_composite(rider(), (13, CELL - 21 - 32))
                c.alpha_composite(cover[k])
                out.append(c)
        return out

    for side, (title, adults, young) in enumerate((('before', before, before), ('after', horses, foals))):
        x0 = side * half + 8
        notes.append((x0, 2, title.upper()))
        for k, head in enumerate(heads):
            notes.append((x0 + k * step, 12, head))
        for r, name in enumerate(COATS):
            y = 26 + r * (step + label)
            notes.append((x0, y, name))
            for k, fr in enumerate(cells(adults, name, True)):
                im.alpha_composite(fr, (x0 + k * step, y + label - 4))
        for r, name in enumerate(FOAL_OF):
            y = 26 + (len(COATS) + r) * (step + label)
            got = cells(young, name, False)
            notes.append((x0, y, name if got else name + ' (new)'))
            for k, fr in enumerate(got):
                im.alpha_composite(fr, (x0 + k * step, y + label - 4))
    y = 26 + len(COATS) * 2 * (step + label)
    notes.append((half + 8, y, 'horseshoe, horseshoe_worn (new sheet, 32 x 32)'))
    for k, frames in enumerate(shoes.values()):
        im.alpha_composite(frames[0], (half + 8 + k * 40, y + label))
    im = im.resize((w * zoom, h * zoom), Image.NEAREST)
    d = ImageDraw.Draw(im)
    for x, y, s in notes:
        d.text((x * zoom + 1, y * zoom + 1), s, fill=(0, 0, 0, 255))
        d.text((x * zoom, y * zoom), s, fill=(255, 255, 255, 255))
    d.line((half * zoom, 0, half * zoom, im.height), fill=(40, 52, 32, 255), width=3)
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)


def main(argv):
    horses, foals, shoes = horse_states(), foal_states(), shoe_states()
    sheet, text = patched_sheet(horses, foals)
    shoes_im, shoes_text = shoe_sheet(shoes)
    if '--check' in argv:
        ok = same(SHEET, sheet, text) and same(SHOES, shoes_im, shoes_text)
        print('horse sheets match' if ok else 'horse sheets are out of date')
        return 0 if ok else 1
    before = None
    if '--preview' in argv:
        before = frames_of(Path(argv[argv.index('--before') + 1]) if '--before' in argv else SHEET)
    save_dmi(SHEET, sheet, text)
    save_dmi(SHOES, shoes_im, shoes_text)
    print('wrote %d horse states, %d foal states and %d horseshoe states' % (len(horses), len(foals), len(shoes)))
    if before is not None:
        write_preview(Path(argv[argv.index('--preview') + 1]), before, horses, foals, shoes)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
