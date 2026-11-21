"""Script-placed 96px art for the heteromorph's true form: a large golden
dragon, plus the burst of golden light shown while it changes form.

Every pixel is placed by this script from a fixed palette (Pillow only); no
external or generated artwork, and the design is our own: gleaming gold scales
shaded to bronze, cream belly plates, amber eyes, two swept-back horns, a short
row of back spines, folded bat-like wings with a warm membrane, and a long tail
that ends in a small leaf-shaped blade. Lit from the upper left with a dark
warm outline, like the large animals in icons/mob/animal_128.dmi.

Geometry: frames are 96x96. The mob is a 2x2-tile (64x64 px) body drawn with
pixel_x = -16, so the footprint is PNG columns 16-79 and rows 32-95. Feet stand
on the bottom rows; head, horns, wing wrists and tail may use the margins.
transform_flash is centred on the frame (48, 48).

States (dirs in BYOND order S, N, E, W; W is E mirrored and re-lit):
  gold             4 dirs, 2 frames, delay 8,8      standing, gentle breathing
  gold_walk        4 dirs, 4 frames, delay 3,3,3,3  walk cycle
  gold_attack      4 dirs, 3 frames, delay 2,2,3    rear back, snap and claw, recover
  transform_flash  1 dir,  6 frames, delay 1,1,1,2,2,2  light grows, then fades
  gold_fly         4 dirs, 4 frames, delay 3,2,3,2  wing beat: up, level, down, recover
  shadow_fly       4 dirs, 4 frames, delay 3,2,3,2  ground shadow, in step with gold_fly

Flight: gold_fly keeps the ground-anchored geometry of the other states (the
game lifts the whole icon with pixel_y while airborne), with the legs tucked,
the neck stretched and the wings fully spread; rows 0-19 stay clear. shadow_fly
is the dragon seen from straight above, flattened to half height, in pure black
at no more than 35% alpha with a feathered edge; it stays on the ground as an
underlay, centred on the footprint.

Run with Pillow to reproduce icons/mob/heteromorph_dragon.dmi.
`--preview <png>` also writes a review sheet: every ground state, dir and frame
at 2x on a grass-coloured and a dark background, with a 1x strip.
`--flight-preview <png>` writes the flight sheet: gold_fly lifted over
shadow_fly, then each state on its own, every dir and frame at 2x.
Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
S = 96

OUT = (38, 22, 12)
# gold scales: glint, light, base, bronze shade, dark bronze, deepest line
GOLD = [(255, 240, 160), (248, 208, 88), (224, 168, 44), (184, 122, 30), (136, 84, 24), (92, 52, 18)]
# belly plates: cream to pale gold
BELLY = [(255, 248, 214), (246, 228, 170), (222, 196, 128), (178, 146, 88)]
# wing membrane: warm, light to dark
MEMB = [(240, 164, 84), (212, 120, 56), (170, 82, 42), (122, 52, 32)]
# horns, spines, claws and teeth
HORN = [(252, 244, 220), (218, 200, 162), (160, 138, 104)]
EYE, PUPIL = (255, 176, 28), (48, 20, 8)
MOUTH, MOUTH2 = (150, 36, 28), (96, 20, 20)
# flash: core, middle, rim
FL = [(255, 252, 224), (255, 224, 112), (244, 172, 40)]
# preview backgrounds
GRASS, GRASS2 = (88, 134, 66), (74, 118, 56)
DARK, DARK2 = (30, 32, 36), (38, 40, 46)

DIRS = ('S', 'N', 'E', 'W')          # BYOND's order for dirs = 4


def scale_tex(x, y):
    """Staggered scale rows: a short dark lip under each scale, a glint on top."""
    r, u = y % 3, (x + (3 if (y // 3) % 2 else 0)) % 6
    if r == 2 and u in (1, 2):
        return 1
    if r == 0 and u == 4:
        return -1
    return 0


class Canvas:
    """Shapes are drawn in the east/south-facing layout; `flip` mirrors the
    finished frame and mirrors the light first, so it still falls from the
    upper left of the screen."""

    def __init__(self, flip=False):
        self.px = {}
        self.flip = flip
        self.lx = -0.45 if flip else 0.45

    def put(self, x, y, c, a=255):
        x, y = int(x), int(y)
        if 0 <= x < S and 0 <= y < S:
            self.px[(x, y)] = (c[0], c[1], c[2], a)

    def pts(self, c, *points):
        for x, y in points:
            self.put(x, y, c)

    def level(self, nx, ny, off=0.0):
        return 0.42 + 0.5 * (nx * self.lx + ny * 0.8) + off

    def fill(self, cells, ramp, tex=False, sep=True):
        """cells: {(x, y): (ramp, level)}. Rings the shape with its darkest
        colour where it overlaps what is already drawn, then fills it."""
        if sep:
            for (x, y) in cells:
                for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if n not in cells and n in self.px:
                        self.put(n[0], n[1], ramp[-1])
        for (x, y), (rmp, lv) in cells.items():
            top = len(rmp) - 1
            i = int(round(max(0.0, min(1.0, lv)) * top))
            if tex and rmp is GOLD:
                i = max(0, min(top - 1, i + scale_tex(x, y)))
            self.put(x, y, rmp[i])

    def ellipse(self, cx, cy, rx, ry, ramp=GOLD, off=0.0, tex=True, belly=None, sep=True):
        cells = {}
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                nx, ny = (x - cx) / rx, (y - cy) / ry
                if nx * nx + ny * ny <= 1.0:
                    lv = self.level(nx, ny, off)
                    if belly and belly(nx, ny, x, y):
                        seg = belly(nx, ny, x, y)
                        cells[(x, y)] = (BELLY, lv * 0.8 + (0.34 if seg == 2 else 0))
                    else:
                        cells[(x, y)] = (ramp, lv)
        self.fill(cells, ramp, tex, sep)

    def limb(self, pts, radii, ramp=GOLD, off=0.0, tex=True, belly=None, sep=True, flat=None):
        """A tapering tube through pts. belly=(dx, dy, threshold, spacing)
        turns the side facing (dx, dy) into segmented cream plates."""
        cells = {}
        lens = [math.hypot(pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1]) for i in range(len(pts) - 1)]
        rmax = max(radii) + 1
        x0 = int(min(p[0] for p in pts) - rmax); x1 = int(max(p[0] for p in pts) + rmax) + 1
        y0 = int(min(p[1] for p in pts) - rmax); y1 = int(max(p[1] for p in pts) + rmax) + 1
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                best = None
                run = 0.0
                for i in range(len(pts) - 1):
                    ax, ay = pts[i]; bx, by = pts[i + 1]
                    L = lens[i] or 1e-6
                    t = max(0.0, min(1.0, ((x - ax) * (bx - ax) + (y - ay) * (by - ay)) / (L * L)))
                    px, py = ax + (bx - ax) * t, ay + (by - ay) * t
                    r = radii[i] + (radii[i + 1] - radii[i]) * t
                    q = math.hypot(x - px, y - py) / r
                    if q <= 1.0 and (best is None or q < best[0]):
                        best = (q, (x - px) / r, (y - py) / r, run + L * t)
                    run += L
                if best is None:
                    continue
                _, nx, ny, s = best
                lv = self.level(nx, ny, off) if flat is None else flat
                if belly and nx * belly[0] + ny * belly[1] > belly[2]:
                    seg = int(s) % belly[3] == 0
                    cells[(x, y)] = (BELLY, lv * 0.8 + (0.34 if seg else 0))
                else:
                    cells[(x, y)] = (ramp, lv)
        self.fill(cells, ramp, tex, sep)

    def poly(self, pts, ramp, levelfn, sep=True):
        cells = {}
        n = len(pts)
        for y in range(int(min(p[1] for p in pts)), int(max(p[1] for p in pts)) + 1):
            for x in range(int(min(p[0] for p in pts)), int(max(p[0] for p in pts)) + 1):
                inside = False
                for i in range(n):
                    ax, ay = pts[i]; bx, by = pts[(i + 1) % n]
                    if (ay > y) != (by > y) and x < (bx - ax) * (y - ay) / (by - ay) + ax:
                        inside = not inside
                if inside:
                    cells[(x, y)] = (ramp, levelfn(x, y))
        self.fill(cells, ramp, False, sep)

    def outline(self):
        edge = set()
        for (x, y) in self.px:
            for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if n not in self.px:
                    edge.add(n)
        for x, y in edge:
            self.put(x, y, OUT)
        return self

    def image(self):
        im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            im.putpixel((S - 1 - x if self.flip else x, y), c)
        return im


def curve(pts, steps=4):
    """Smooth a control polyline (Catmull-Rom) so tails and necks bend evenly."""
    out = []
    p = [pts[0]] + list(pts) + [pts[-1]]
    for i in range(1, len(p) - 2):
        for k in range(steps):
            t = k / steps
            out.append(tuple(
                0.5 * ((2 * p[i][j]) + (-p[i - 1][j] + p[i + 1][j]) * t
                       + (2 * p[i - 1][j] - 5 * p[i][j] + 4 * p[i + 1][j] - p[i + 2][j]) * t * t
                       + (-p[i - 1][j] + 3 * p[i][j] - 3 * p[i + 1][j] + p[i + 2][j]) * t ** 3)
                for j in (0, 1)))
    out.append(tuple(pts[-1]))
    return out


def taper(n, r0, r1):
    return [r0 + (r1 - r0) * i / (n - 1) for i in range(n)]


def tail(c, ctrl, r0, r1, belly=None):
    pts = curve(ctrl)
    c.limb(pts, taper(len(pts), r0, r1), belly=belly)
    # leaf-shaped blade on the tip, pointing the way the tail ends
    (ax, ay), (bx, by) = pts[-3], pts[-1]
    d = math.hypot(bx - ax, by - ay) or 1.0
    ux, uy = (bx - ax) / d, (by - ay) / d
    blade = [(bx - ux * 2 - uy * 1, by - uy * 2 + ux * 1), (bx + ux * 2 - uy * 4, by + uy * 2 + ux * 4),
             (bx + ux * 8, by + uy * 8), (bx + ux * 2 + uy * 4, by + uy * 2 - ux * 4),
             (bx - ux * 2 + uy * 1, by - uy * 2 - ux * 1)]
    c.poly(blade, MEMB, lambda x, y: 0.25 + 0.5 * ((x + y) % 5 == 0))
    c.limb([(bx - ux, by - uy), (bx + ux * 6, by + uy * 6)], [1.0, 0.6], flat=0.6, tex=False, sep=False)


def wing(c, shoulder, wrist, tips, scallops, root, off=0.0, arm=(3.4, 2.6, 1.8), claw=True):
    """A folded bat wing: arm from shoulder up to the wrist, three fingers
    fanning back down, scalloped membrane between them."""
    elbow = ((shoulder[0] + wrist[0]) / 2 + (2 if wrist[0] < shoulder[0] else -2), (shoulder[1] + wrist[1]) / 2 + 1)
    outline = [shoulder, elbow, wrist]
    for t, s in zip(tips, scallops):
        outline += [t, s]
    outline.append(root)
    y0 = min(p[1] for p in outline); y1 = max(p[1] for p in outline)

    def lv(x, y):
        v = 0.12 + 0.62 * (y - y0) / (y1 - y0) + off
        return v + (0.18 if (x + 2 * y) % 9 == 0 else 0)      # faint veining
    c.poly(outline, MEMB, lv)
    for t in tips:
        c.limb([wrist, t], [1.1, 0.7], flat=0.62 + off, tex=False, sep=False)
    c.limb([shoulder, elbow, wrist], list(arm), off=off, sep=False)
    if not claw:
        return
    wx, wy = int(wrist[0]), int(wrist[1])
    c.pts(HORN[0], (wx, wy - 3), (wx, wy - 4))                # wrist claw
    c.pts(HORN[1], (wx, wy - 2))


def spines(c, pts, dist, every=2, start=1):
    """Short pale spines standing off the upper side of a curve."""
    for i in range(start, len(pts) - 1, every):
        (ax, ay), (bx, by) = pts[i], pts[i + 1]
        d = math.hypot(bx - ax, by - ay) or 1.0
        nx, ny = (by - ay) / d, -(bx - ax) / d
        if ny > 0:
            nx, ny = -nx, -ny
        r = dist(i)
        c.put(round(ax + nx * r), round(ay + ny * r), HORN[1])
        c.put(round(ax + nx * (r + 1)), round(ay + ny * (r + 1)), HORN[0])


def claws(c, x, y, step=2, n=3):
    for i in range(n):
        c.put(x + i * step, y, HORN[0])
        c.put(x + i * step, y - 1, HORN[1])


# --------------------------------------------------------------------------
# side view (east; west is the same drawing flipped)
# --------------------------------------------------------------------------

def side_leg(c, hip, foot, hind, far):
    off = 0.2 if far else 0.0
    hx, hy = hip; fx, fy = foot
    if hind:
        if not far:
            c.ellipse(hx, hy + 1, 8, 9, off=off)
        pts = [(hx, hy), (hx + 4, hy + 8), (fx - 4, fy - 8), (fx, fy - 1)]
        rad = [5, 4.2, 2.8, 2.6]
    else:
        pts = [(hx, hy), ((hx + fx) / 2 - 2, (hy + fy) / 2), (fx, fy - 1)]
        rad = [4.8, 3.8, 2.8]
    c.limb(pts, rad, off=off, sep=not (hind and not far))
    c.limb([(fx, fy), (fx + 5, fy)], [2.3, 1.9], off=off, sep=False)
    if not far:
        claws(c, fx + 2, int(fy) + 2)
    else:
        c.pts(HORN[2], (fx + 5, fy + 2), (fx + 7, fy + 1))


def side_head(c, hx, hy, jaw):
    # far horn, then near horn, both swept back over the neck
    c.limb(curve([(hx - 1, hy - 5), (hx - 8, hy - 11), (hx - 14, hy - 13)]), taper(9, 2.0, 0.6), HORN, off=0.3, tex=False)
    c.limb([(hx - 1, hy + 4), (hx + 11, hy + 6 + jaw)], [2.6, 1.6], BELLY, off=0.1, tex=False)
    if jaw:
        c.poly([(hx + 1, hy + 3), (hx + 13, hy + 3), (hx + 12, hy + 5 + jaw), (hx + 2, hy + 5)], [MOUTH, MOUTH2],
               lambda x, y: 0.0 if y < hy + 5 + jaw // 2 else 1.0)
    c.ellipse(hx, hy, 7, 6)
    c.limb([(hx + 2, hy + 1), (hx + 12, hy + 2)], [5, 3.2], sep=False)
    c.limb(curve([(hx - 3, hy - 4), (hx - 10, hy - 8), (hx - 17, hy - 9)]), taper(9, 2.3, 0.6), HORN, tex=False)
    if jaw:                                                  # teeth
        c.pts(HORN[0], (hx + 5, hy + 5), (hx + 8, hy + 5), (hx + 11, hy + 5), (hx + 13, hy + 5),
              (hx + 6, hy + 5 + jaw), (hx + 9, hy + 5 + jaw))
    c.pts(GOLD[5], (hx + 1, hy - 3), (hx + 2, hy - 3), (hx + 3, hy - 2), (hx + 4, hy - 2))   # brow ridge
    c.pts(EYE, (hx + 2, hy - 2), (hx + 2, hy - 1), (hx + 3, hy - 1))
    c.pts(PUPIL, (hx + 3, hy - 1))
    c.pts(GOLD[0], (hx + 6, hy - 2), (hx + 9, hy - 1))       # glint along the snout
    c.pts(GOLD[5], (hx + 13, hy + 1))                        # nostril
    c.pts(HORN[1], (hx - 6, hy + 4), (hx - 7, hy + 5))       # cheek spur
    c.pts(HORN[0], (hx - 8, hy + 5))


def side(flip, bob=0, breath=0, phase=None, head=(0, 0), jaw=0, claw=None, lift=0, sway=0):
    c = Canvas(flip)
    by = bob
    hx, hy = 77 + head[0], 36 + head[1] + by + breath
    # stride: near front and far hind move together
    step = {None: (0, 0), 0: (4, 0), 1: (0, 0), 2: (-4, 0), 3: (0, 3)}
    a = step[phase]
    b = step[None if phase is None else (phase + 2) % 4]
    # far wing peeking over the back
    wing(c, (58, 53 + by), (49, 21 + by - lift), [(30, 28 + by - lift), (23, 43 + by)], [(33, 37 + by), (30, 50 + by)],
         (50, 56 + by), off=0.28)
    # tail
    tail(c, [(31, 65 + by), (22, 70 + by), (15, 79), (9, 85), (5, 80 + sway), (6, 73 + sway)], 7.0, 1.3)
    # far legs
    side_leg(c, (40, 72 + by), (41 + b[0], 91 - b[1]), True, True)
    side_leg(c, (63, 70 + by), (66 + b[0], 91 - b[1]), False, True)
    # body, with cream plates along the underside
    c.ellipse(46, 66 + by, 19, 11 + breath,
              belly=lambda nx, ny, x, y: (2 if x % 4 == 0 else 1) if ny > 0.52 else 0)
    c.ellipse(59, 65 + by, 9, 10 + breath, sep=False,
              belly=lambda nx, ny, x, y: (2 if x % 4 == 0 else 1) if ny > 0.6 or nx > 0.62 else 0)
    # neck, plated down the throat
    neck = curve([(60, 61 + by), (67, 54 + by), (71, 46 + by + head[1] * 0.5), (hx - 4, hy + 3)])
    c.limb(neck, taper(len(neck), 8.0, 5.0), belly=(0.75, 0.66, 0.45, 3), sep=False)
    spines(c, neck, lambda i: 8.0 - 3.0 * i / len(neck), every=3, start=2)
    # near legs
    side_leg(c, (35, 71 + by), (33 + a[0], 91 - a[1]), True, False)
    if claw:
        fx, fy = claw
        c.limb([(60, 70 + by), (64, 76 + by), (fx, fy)], [4.8, 3.6, 2.6])
        c.limb([(fx, fy), (fx + 4, fy + 2)], [2.4, 2.0], sep=False)
        c.pts(HORN[0], (fx + 6, fy + 1), (fx + 6, fy + 3), (fx + 5, fy + 5), (fx + 7, fy + 2), (fx + 7, fy + 4))
    else:
        side_leg(c, (60, 70 + by), (60 + a[0], 91 - a[1]), False, False)
    # near wing folded over the back
    wing(c, (54, 56 + by), (43, 24 + by - lift), [(23, 31 + by - lift), (17, 47 + by), (21, 61 + by)],
         [(27, 41 + by), (24, 54 + by), (33, 63 + by)], (48, 62 + by))
    side_head(c, hx, hy, jaw)
    return c.outline()


# --------------------------------------------------------------------------
# front (south) and back (north) views
# --------------------------------------------------------------------------

def fb_wing(c, side_, by, lift=0, flare=0, inset=0, off=0.0):
    def P(dx, y):
        return (48 + side_ * dx, y)
    o = off + (0.14 if side_ * (1 if not c.flip else -1) > 0 else -0.06)
    wing(c, P(11 - inset, 58 + by), P(24 + flare - inset, 21 + by - lift),
         [P(33 + flare - inset, 43 + by - lift * 0.5), P(31 + flare - inset, 61 + by), P(23 + flare * 0.5 - inset, 72 + by)],
         [P(27 + flare - inset, 51 + by), P(25 + flare * 0.7 - inset, 66 + by), P(17 - inset, 71 + by)],
         P(12 - inset, 68 + by), off=o, arm=(3.2, 2.4, 1.7))


def fb_foot(c, x, y, off=0.0):
    c.ellipse(x, y, 5, 2.6, off=off, tex=False)
    claws(c, int(x) - 3, int(y) + 3, step=3)


def south_head(c, hy, jaw=0):
    for s_ in (-1, 1):                                        # horns: up, out and back
        c.limb(curve([(48 + s_ * 6, hy - 5), (48 + s_ * 11, hy - 13), (48 + s_ * 13, hy - 21)]), taper(9, 2.4, 0.6), HORN,
               off=0.25 if s_ > 0 else 0.0, tex=False)
    c.ellipse(48, hy, 9, 8)
    for y in range(hy - 9, hy - 5, 2):                        # crest spines
        c.pts(HORN[0], (48, y))
    if jaw:
        c.ellipse(48, hy + 8 + jaw, 5, 3 + jaw // 2, BELLY, off=0.25, tex=False)
        c.ellipse(48, hy + 7 + jaw // 2, 4, 1 + jaw // 2, [MOUTH, MOUTH2], tex=False)
    c.ellipse(48, hy + 5, 6, 5.5, off=-0.1, sep=False)
    if jaw:
        c.pts(HORN[0], (45, hy + 10), (47, hy + 10), (49, hy + 10), (51, hy + 10),
              (46, hy + 8 + jaw), (50, hy + 8 + jaw))
    else:
        for x in range(44, 53):
            c.put(x, hy + 10, BELLY[2] if x in (44, 52) else BELLY[1])   # lip of the lower jaw
        c.pts(GOLD[5], (45, hy + 9), (46, hy + 9), (47, hy + 9), (48, hy + 9), (49, hy + 9), (50, hy + 9), (51, hy + 9))
    c.pts(GOLD[5], (46, hy + 7), (50, hy + 7))                # nostrils
    c.pts(GOLD[0], (47, hy + 2), (47, hy + 3), (48, hy + 1))
    for s_ in (-1, 1):
        ex = 48 + s_ * 5
        c.pts(GOLD[5], (ex - s_, hy - 2), (ex, hy - 3), (ex + s_, hy - 3), (ex + 2 * s_, hy - 4))    # brow
        c.pts(EYE, (ex, hy - 2), (ex + s_, hy - 2), (ex, hy - 1), (ex + s_, hy - 1))
        c.pts(PUPIL, (ex, hy - 1))
        c.pts(HORN[1], (48 + s_ * 9, hy + 3), (48 + s_ * 10, hy + 4))                               # cheek spurs


def south(bob=0, breath=0, phase=None, head=0, jaw=0, claw=0, lift=0, sway=0):
    c = Canvas()
    by = bob
    step = {None: (0, 0), 0: (0, 2), 1: (0, 0), 2: (0, 0), 3: (0, 0)}
    lf = step[phase][1]                                       # viewer's-left front foot lift
    rf = step[None if phase is None else (phase + 2) % 4][1]
    # tail curling out to one side behind the body
    tail(c, [(57, 78 + by), (69, 85), (79 + sway, 87), (85 + sway, 80), (84 + sway, 72)], 5.5, 1.3)
    fb_wing(c, -1, by, lift)
    fb_wing(c, 1, by, lift)
    # haunches and hind feet either side of the chest
    for s_, l_ in ((-1, rf), (1, lf)):
        c.ellipse(48 + s_ * 15, 77 + by, 8, 10, off=0.16)
        fb_foot(c, 48 + s_ * 19, 91 - l_, off=0.16)
    # chest with a column of cream plates
    c.ellipse(48, 68 + by, 15, 17 + breath,
              belly=lambda nx, ny, x, y: (2 if y % 4 == 0 else 1) if abs(nx) < 0.5 - 0.12 * ny else 0)
    # front legs
    for s_, l_ in ((-1, lf), (1, rf)):
        if s_ == -1 and claw:
            continue
        x = 48 + s_ * 10
        c.limb([(x, 68 + by), (x + s_, 80 + by * 0.5), (x + s_, 89 - l_)], [5.2, 4.4, 3.6])
        fb_foot(c, x + s_, 91 - l_)
    # neck and head, facing the viewer
    hy = 40 + by + breath + head
    c.limb([(48, 60 + by), (48, hy + 6)], [8.5, 7])
    south_head(c, hy, jaw)
    if claw:                                                  # raised or striking forepaw
        px, py = {1: (27, 52), 2: (36, 74), 3: (37, 80)}[claw]
        c.limb([(38, 67 + by), ((38 + px) / 2 - 3, (67 + py) / 2), (px, py)], [5.2, 4.2, 3.4])
        c.ellipse(px, py, 4.5, 4, tex=False, sep=False)
        d = -1 if claw == 1 else 1
        for i in (-3, 0, 3):
            c.pts(HORN[0], (px + i, py + d * 5), (px + i, py + d * 6))
            c.pts(HORN[1], (px + i, py + d * 4))
    c.outline()
    if claw == 2:                                             # streaks left by the swipe
        for i, (x, y) in enumerate(((23, 50), (25, 55), (28, 60), (31, 64))):
            c.put(x, y, HORN[0], 210 - i * 25)
            c.put(x + 3, y - 2, HORN[0], 170 - i * 25)
            c.put(x + 6, y - 4, HORN[0], 130 - i * 25)
    return c


def north_head(c, hy, by):
    # head from behind, horns sweeping back toward the viewer
    c.ellipse(48, hy + 2, 6, 5, off=0.1)                      # snout tip beyond the skull
    c.limb([(48, 60 + by), (48, hy + 5)], [8.5, 6.5])
    c.ellipse(48, hy, 8, 7)
    for s_ in (-1, 1):
        c.limb(curve([(48 + s_ * 5, hy - 2), (48 + s_ * 10, hy - 10), (48 + s_ * 12, hy - 18)]), taper(9, 2.4, 0.6), HORN,
               off=0.25 if s_ > 0 else 0.0, tex=False)
        c.pts(HORN[1], (48 + s_ * 8, hy + 3), (48 + s_ * 9, hy + 4))


def north(bob=0, breath=0, phase=None, head=0, lift=0, flare=0, sway=0):
    c = Canvas()
    by = bob
    step = {None: 0, 0: 2, 1: 0, 2: 0, 3: 0}
    lh = step[phase]
    rh = step[None if phase is None else (phase + 2) % 4]
    hy = 37 + by + breath + head
    north_head(c, hy, by)
    # front feet just showing past the haunches
    for s_, l_ in ((-1, rh), (1, lh)):
        c.limb([(48 + s_ * 14, 70 + by), (48 + s_ * 18, 89 - l_)], [4.5, 3.4], off=0.2)
        c.ellipse(48 + s_ * 19, 91 - l_, 4, 2.4, off=0.2, tex=False)
    # back
    c.ellipse(48, 68 + by, 16, 17 + breath)
    # hind legs
    for s_, l_ in ((-1, lh), (1, rh)):
        c.ellipse(48 + s_ * 12, 78 + by, 8, 10)
        fb_foot(c, 48 + s_ * 13, 91 - l_)
    # wings folded over the flanks
    fb_wing(c, -1, by, lift, flare, inset=2)
    fb_wing(c, 1, by, lift, flare, inset=2)
    # spine ridge from the skull to the tail root
    for y in range(hy + 2, 79 + by):
        if (48, y) in c.px:
            c.put(48, y, GOLD[4])
            if y % 4 == 0:
                c.pts(HORN[0], (48, y))
                c.pts(HORN[1], (47, y), (49, y))
    # tail trailing toward the viewer and off to one side
    tail(c, [(48, 79 + by), (49, 86), (57, 90), (68, 88 + sway), (75, 82 + sway)], 6.0, 1.3)
    return c.outline()


# --------------------------------------------------------------------------
# flight: wings spread and beating, legs tucked, tail streaming
# --------------------------------------------------------------------------

FLY_DELAY = (3, 2, 3, 2)
FLY_BOB = (1, 0, -1, 0)          # the body sinks as the wings rise and lifts on the beat
FLY_SWAY = (1, 0, -1, 0)

# side view, near wing: wrist, three finger tips, scallops between them, root
SIDE_WING = (
    ((52, 25), [(34, 22), (17, 31), (15, 50)], [(27, 30), (21, 42), (28, 57)], (46, 61)),   # raised
    ((42, 44), [(18, 38), (10, 52), (20, 68)], [(22, 46), (19, 59), (32, 68)], (46, 62)),   # level
    ((50, 80), [(30, 92), (16, 82), (17, 66)], [(29, 84), (23, 74), (32, 66)], (45, 61)),   # down
    ((48, 33), [(26, 27), (15, 41), (19, 58)], [(26, 36), (22, 50), (32, 61)], (46, 62)),   # recovering
)
# front and back views, as (distance out from the centre line, y)
FB_WING = (
    ((25, 31), [(45, 23), (41, 45), (29, 59)], [(39, 37), (33, 52), (21, 61)]),
    ((27, 46), [(45, 51), (39, 64), (27, 72)], [(38, 56), (31, 66), (19, 68)]),
    ((25, 62), [(42, 80), (33, 85), (22, 81)], [(35, 77), (27, 79), (17, 74)]),
    ((23, 39), [(40, 37), (37, 55), (27, 67)], [(35, 47), (30, 60), (19, 66)]),
)


def tucked_leg(c, hip, knee, paw, rad, off=0.0, near=True):
    """A leg folded up against the belly, paw trailing back."""
    c.limb([hip, knee, paw], rad, off=off)
    px, py = int(paw[0]), int(paw[1])
    if near:
        c.pts(HORN[0], (px - 3, py + 1), (px - 3, py - 1))
        c.pts(HORN[1], (px - 2, py + 1), (px - 2, py - 1))
    else:
        c.pts(HORN[2], (px - 3, py))


def side_fly(flip, f):
    c = Canvas(flip)
    by, sw = FLY_BOB[f], FLY_SWAY[f]
    hx, hy = 79, 45 + by
    wrist, tips, scal, root = SIDE_WING[f]

    def sh(p, dx=0, dy=0):
        return (p[0] + dx, p[1] + by + dy)
    # far wing, a little ahead of and above the near one
    wing(c, (58, 53 + by), sh(wrist, 7, -2), [sh(p, 7, -2) for p in tips], [sh(p, 7, -2) for p in scal],
         (50, 57 + by), off=0.28, claw=f != 2)
    # tail streaming out behind
    tail(c, [(31, 65 + by), (23, 68 + by), (15, 68 + by + sw), (9, 65 + by + 2 * sw)], 7.0, 1.3)
    tucked_leg(c, (41, 72 + by), (40, 80 + by), (32, 81 + by), [4.6, 3.4, 2.4], off=0.2, near=False)
    tucked_leg(c, (64, 70 + by), (64, 78 + by), (57, 80 + by), [4.4, 3.4, 2.4], off=0.2, near=False)
    c.ellipse(46, 66 + by, 19, 11,
              belly=lambda nx, ny, x, y: (2 if x % 4 == 0 else 1) if ny > 0.52 else 0)
    c.ellipse(59, 65 + by, 9, 10, sep=False,
              belly=lambda nx, ny, x, y: (2 if x % 4 == 0 else 1) if ny > 0.6 or nx > 0.62 else 0)
    # neck stretched forward and low
    neck = curve([(60, 61 + by), (68, 57 + by), (73, 52 + by), (hx - 4, hy + 3)])
    c.limb(neck, taper(len(neck), 8.0, 5.0), belly=(0.75, 0.66, 0.45, 3), sep=False)
    spines(c, neck, lambda i: 8.0 - 3.0 * i / len(neck), every=3, start=2)
    c.ellipse(35, 71 + by, 8, 8)
    tucked_leg(c, (35, 72 + by), (35, 82 + by), (26, 83 + by), [5, 3.8, 2.6])
    tucked_leg(c, (60, 70 + by), (60, 80 + by), (52, 82 + by), [4.6, 3.6, 2.6])
    wing(c, (54, 56 + by), sh(wrist), [sh(p) for p in tips], [sh(p) for p in scal], sh(root), claw=f != 2)
    side_head(c, hx, hy, 0)
    return c.outline()


def fb_spread(c, side_, by, f, inset=0, off=0.0):
    wrist, tips, scal = FB_WING[f]

    def P(p):
        return (48 + side_ * (p[0] - inset), p[1] + by)
    o = off + (0.14 if side_ > 0 else -0.06)
    wing(c, P((11, 57)), P(wrist), [P(p) for p in tips], [P(p) for p in scal], P((12, 68)),
         off=o, arm=(3.2, 2.4, 1.7), claw=f != 2)


def south_fly(f):
    c = Canvas()
    by, sw = FLY_BOB[f] - 3, FLY_SWAY[f]
    tail(c, [(54, 76 + by), (62, 84 + by), (71, 87 + by), (79, 84 + by + sw), (85, 78 + by + 2 * sw)], 5.5, 1.3)
    fb_spread(c, -1, by, f)
    fb_spread(c, 1, by, f)
    for s_ in (-1, 1):                                        # haunches, hind paws tucked beneath
        c.ellipse(48 + s_ * 14, 77 + by, 7, 8, off=0.16)
        fb_foot(c, 48 + s_ * 15, 86 + by, off=0.16)
    c.ellipse(48, 68 + by, 15, 17,
              belly=lambda nx, ny, x, y: (2 if y % 4 == 0 else 1) if abs(nx) < 0.5 - 0.12 * ny else 0)
    for s_ in (-1, 1):                                        # forelegs folded against the chest
        x = 48 + s_ * 11
        c.limb([(x, 67 + by), (x - s_, 75 + by)], [5.0, 4.0])
        c.ellipse(x - s_, 78 + by, 4.5, 2.6, tex=False, sep=False)
        claws(c, int(x - s_) - 3, 81 + by, step=3)
    hy = 42 + by
    c.limb([(48, 60 + by), (48, hy + 6)], [8.5, 7])
    south_head(c, hy)
    return c.outline()


def north_fly(f):
    c = Canvas()
    by, sw = FLY_BOB[f] - 3, FLY_SWAY[f]
    hy = 38 + by
    north_head(c, hy, by)
    c.ellipse(48, 68 + by, 16, 17)
    for s_ in (-1, 1):                                        # hind legs tucked, soles toward the viewer
        c.ellipse(48 + s_ * 12, 77 + by, 8, 8)
        fb_foot(c, 48 + s_ * 13, 86 + by)
    fb_spread(c, -1, by, f, inset=2)
    fb_spread(c, 1, by, f, inset=2)
    for y in range(hy + 2, 79 + by):
        if (48, y) in c.px:
            c.put(48, y, GOLD[4])
            if y % 4 == 0:
                c.pts(HORN[0], (48, y))
                c.pts(HORN[1], (47, y), (49, y))
    tail(c, [(48, 78 + by), (50, 85 + by), (59, 89 + by), (70, 87 + by + sw), (78, 82 + by + 2 * sw)], 6.0, 1.3)
    return c.outline()


def fly_frame(d, f):
    return {'S': lambda: south_fly(f), 'N': lambda: north_fly(f),
            'E': lambda: side_fly(False, f), 'W': lambda: side_fly(True, f)}[d]()


# the shadow: the dragon from straight above. u runs nose-ward, v out to a wing.
SHADOW_ALPHA = 89                # 35% black at the core
SHADOW_SPAN = (0.80, 1.0, 0.80, 0.90)
SHADOW_CY = 75.0
SHADOW_SQUASH = 0.5


def _in_poly(pts, x, y):
    inside = False
    n = len(pts)
    for i in range(n):
        ax, ay = pts[i]; bx, by = pts[(i + 1) % n]
        if (ay > y) != (by > y) and x < (bx - ax) * (y - ay) / (by - ay) + ax:
            inside = not inside
    return inside


def _in_tube(pts, radii, x, y):
    for i in range(len(pts) - 1):
        ax, ay = pts[i]; bx, by = pts[i + 1]
        L2 = (bx - ax) ** 2 + (by - ay) ** 2 or 1e-6
        t = max(0.0, min(1.0, ((x - ax) * (bx - ax) + (y - ay) * (by - ay)) / L2))
        r = radii[i] + (radii[i + 1] - radii[i]) * t
        if (x - ax - (bx - ax) * t) ** 2 + (y - ay - (by - ay) * t) ** 2 <= r * r:
            return True
    return False


def shadow(d, f):
    sp, sw = SHADOW_SPAN[f], FLY_SWAY[f] * 2.0
    sweep = (1 - sp) * 20                                     # a shorter span is a wing swept back
    wingp = [(9, 5), (15 - sweep, 19 * sp), (5 - sweep, 41 * sp), (-4 - sweep * 0.6, 33 * sp), (-10 - sweep, 31 * sp),
             (-7, 23 * sp), (-15 - sweep * 0.5, 19 * sp), (-9, 12 * sp), (-14, 6)]
    tailp = curve([(-12, 0), (-21, sw * 0.4), (-29, sw), (-35, sw * 0.5)])
    tailr = taper(len(tailp), 5.0, 1.2)
    tu, tv = tailp[-1]
    blade = [(tu + 1, tv - 1), (tu - 2, tv - 3.5), (tu - 8, tv), (tu - 2, tv + 3.5), (tu + 1, tv + 1)]

    def inside(u, v):
        if (u / 17.0) ** 2 + (v / 9.0) ** 2 <= 1.0:
            return True
        if ((u - 29) / 7.5) ** 2 + (v / 4.5) ** 2 <= 1.0:
            return True
        if _in_tube([(12, 0), (27, 0)], [6.0, 4.0], u, v) or _in_tube(tailp, tailr, u, v):
            return True
        return _in_poly(wingp, u, abs(v)) or _in_poly(blade, u, v)

    n = 4                                                     # coverage from a 4x4 grid per pixel
    cov = [[0.0] * S for _ in range(S)]
    for y in range(S):
        for x in range(S):
            k = 0
            for j in range(n):
                for i in range(n):
                    dx = x + (i + 0.5) / n - 48.0
                    dy = (y + (j + 0.5) / n - SHADOW_CY) / SHADOW_SQUASH
                    u, v = {'S': (dy, dx), 'N': (-dy, dx), 'E': (dx, dy), 'W': (-dx, dy)}[d]
                    k += inside(u, v)
            cov[y][x] = k / float(n * n)
    c = Canvas()
    for y in range(S):
        for x in range(S):
            # feather: weighted mean with the eight neighbours
            a = w = 0.0
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    q = 4 if (dx, dy) == (0, 0) else 2 if 0 in (dx, dy) else 1
                    w += q
                    if 0 <= x + dx < S and 0 <= y + dy < S:
                        a += q * cov[y + dy][x + dx]
            a = int(round(SHADOW_ALPHA * a / w))
            if a >= 6:
                c.put(x, y, (0, 0, 0), a)
    return c


# --------------------------------------------------------------------------
# the change of form: a star of golden light that swells, hollows and fades
# --------------------------------------------------------------------------

def flash(i):
    R = (12, 25, 39, 46, 47, 47)[i]
    A = (240, 255, 255, 205, 120, 50)[i]
    hollow = (0.0, 0.0, 0.0, 0.35, 0.65, 0.86)[i]
    c = Canvas()
    for y in range(S):
        for x in range(S):
            dx, dy = x - 47.5, y - 47.5
            d = math.hypot(dx, dy)
            ang = math.atan2(dy, dx)
            edge = R * (0.68 + 0.32 * abs(math.cos(2 * ang + 0.4 * i)) ** 6 * (1.0 if math.cos(4 * ang + 0.8 * i) > 0 else 0.55))
            if d >= edge:
                continue
            t = d / edge
            a = A * min(1.0, 1.25 * (1 - t) ** 0.6)
            if t < hollow:
                a *= (t / hollow) ** 1.6
            a = int(a) // 15 * 15
            if a <= 0:
                continue
            c.put(x, y, FL[0] if t < 0.38 and not hollow else FL[1] if t < 0.7 else FL[2], a)
    for k in range(14):                                      # sparks thrown outward
        ang = k * 2.399963
        r = R * (0.62 + 0.36 * ((k * 7) % 5) / 4)
        x, y = int(47.5 + math.cos(ang) * r), int(47.5 + math.sin(ang) * r)
        if not (2 <= x < S - 2 and 2 <= y < S - 2):
            continue
        sa = min(255, A + 20)
        c.put(x, y, FL[0], sa)
        if (k + i) % 2 == 0:
            for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                c.put(n[0], n[1], FL[1], sa * 2 // 3)
    return c


# --------------------------------------------------------------------------
# states
# --------------------------------------------------------------------------

def dragon(d, **kw):
    """One frame for dir d from pose keywords; unused keywords are dropped."""
    if d in ('E', 'W'):
        keys = ('bob', 'breath', 'phase', 'head', 'jaw', 'claw', 'lift', 'sway')
        args = {k: v for k, v in kw.get('side', kw).items() if k in keys}
        return side(d == 'W', **args)
    if d == 'S':
        return south(**kw.get('south', {k: v for k, v in kw.items() if k in ('bob', 'breath', 'phase', 'sway')}))
    return north(**kw.get('north', {k: v for k, v in kw.items() if k in ('bob', 'breath', 'phase', 'sway')}))


def build():
    idle = [dict(), dict(breath=1)]
    walk = [dict(phase=p, bob=(0, 1, 0, 1)[p], sway=(0, 1, 0, -1)[p]) for p in range(4)]
    attack = [
        dict(side=dict(head=(-5, -3), jaw=3, claw=(69, 70), lift=2),
             south=dict(head=-3, jaw=2, claw=1, lift=2),
             north=dict(head=2, lift=1, flare=2)),
        dict(side=dict(head=(2, 4), jaw=5, claw=(72, 80), lift=4, sway=-2),
             south=dict(head=5, jaw=4, claw=2, lift=4, sway=-2),
             north=dict(head=-5, lift=4, flare=6, sway=-2)),
        dict(side=dict(head=(1, 2), jaw=0, claw=(68, 86), lift=1),
             south=dict(head=2, jaw=0, claw=3, lift=1),
             north=dict(head=-2, lift=2, flare=3)),
    ]
    states = []
    for name, poses, delay in (('gold', idle, (8, 8)), ('gold_walk', walk, (3, 3, 3, 3)),
                               ('gold_attack', attack, (2, 2, 3))):
        frames = [[dragon(d, **pose).image() for d in DIRS] for pose in poses]
        states.append((name, 4, delay, frames))
    states.append(('transform_flash', 1, (1, 1, 1, 2, 2, 2), [[flash(i).image()] for i in range(6)]))
    # flight states go after the flash so the earlier cells keep their place in the sheet
    states.append(('gold_fly', 4, FLY_DELAY, [[fly_frame(d, f).image() for d in DIRS] for f in range(4)]))
    states.append(('shadow_fly', 4, FLY_DELAY, [[shadow(d, f).image() for d in DIRS] for f in range(4)]))
    return states


def write_dmi(path, states, cols=8):
    cells = [im for _, _, _, frames in states for per_dir in frames for im in per_dir]
    rows = -(-len(cells) // cols)
    sheet = Image.new('RGBA', (S * cols, S * rows), (0, 0, 0, 0))
    for i, im in enumerate(cells):
        sheet.paste(im, (i % cols * S, i // cols * S))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = %d\n\theight = %d\n' % (S, S)
    for name, dirs, delay, frames in states:
        text += 'state = "%s"\n\tdirs = %d\n\tframes = %d\n\tdelay = %s\n' % (
            name, dirs, len(frames), ','.join(str(v) for v in delay))
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta)


def ground(kind, w, h):
    a, b = {'grass': (GRASS, GRASS2), 'dark': (DARK, DARK2)}[kind]
    im = Image.new('RGBA', (w, h), a + (255,))
    for y in range(h):
        for x in range(w):
            if (x * 7 + y * 13) % 23 == 0 or (x * 5 + y * 11) % 31 == 0:
                im.putpixel((x, y), b + (255,))
    return im


def write_preview(path, states, scale=2):
    """Per background: one row per dir with gold | gold_walk | gold_attack
    frames left to right, then the flash row and a 1x strip. A faint box marks the 64x64 footprint."""
    body = [s for s in states if s[0] in ('gold', 'gold_walk', 'gold_attack')]
    ncol = sum(len(s[3]) for s in body)
    label = 14
    pw, ph = S * ncol, label + (S + label) * 4 + S + label + S + label
    sheet = Image.new('RGBA', (pw * scale, ph * scale * 2), (0, 0, 0, 255))
    for bi, kind in enumerate(('grass', 'dark')):
        panel = ground(kind, pw, ph)
        notes = []
        for di, d in enumerate(DIRS):
            col = 0
            for name, _, delay, frames in body:
                for fi, per_dir in enumerate(frames):
                    x, y = col * S, label + di * (S + label)
                    for k in range(16, 80, 3):               # footprint corners and edges, dotted
                        for px_, py_ in ((x + k, y + 32), (x + k, y + 95), (x + 16, y + 32 + k - 16), (x + 79, y + 32 + k - 16)):
                            panel.putpixel((px_, py_), (255, 255, 255, 255) if kind == 'dark' else (40, 70, 30, 255))
                    panel.alpha_composite(per_dir[di], (x, y))
                    notes.append((x + 2, y - label + 2, '%s %s f%d d%s' % (name, d, fi + 1, delay[fi])))
                    col += 1
        fy = label + 4 * (S + label)
        name, _, delay, frames = [s for s in states if s[0] == 'transform_flash'][0]
        for fi, per_dir in enumerate(frames):
            panel.alpha_composite(per_dir[0], (fi * S, fy))
            notes.append((fi * S + 2, fy - label + 2, '%s f%d d%s' % (name, fi + 1, delay[fi])))
        # the flash over the idle dragon, centred on the body (flash lowered 16 px)
        panel.alpha_composite(body[0][3][0][0], (6 * S + S, fy))
        panel.alpha_composite(frames[2][0], (6 * S + S, fy + 16))
        notes.append((7 * S + 2, fy - label + 2, 'flash f3 over gold S'))
        big = panel.resize((pw * scale, ph * scale), Image.NEAREST)
        # true-size strip, pasted unscaled
        sy = (fy + S + label) * scale
        x = 4
        for name, _, _, frames in body:
            for per_dir in ((frames[0], frames[1]) if name == 'gold_attack' else (frames[0],)):
                for im in per_dir:
                    big.alpha_composite(im, (x, sy + 4))
                    x += S + 4
        draw = ImageDraw.Draw(big)
        for x, y, text in notes:
            draw.text((x * scale, y * scale), text, fill=(240, 240, 240))
        draw.text((4, sy - 12), '1x: gold f1, gold_walk f1, gold_attack f1 and f2, each S N E W', fill=(240, 240, 240))
        sheet.alpha_composite(big, (0, bi * ph * scale))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.convert('RGB').save(path)


FLY_LIFT = 20                    # HETEROMORPH_FLY_LIFT: pixel_y of the airborne dragon


def write_flight_preview(path, states, scale=2):
    """Per background, one row per dir: gold_fly lifted over shadow_fly (4
    frames), gold_fly as stored (4), shadow_fly alone (4), then standing gold
    for scale. Dotted box: the 64x64 footprint. Dashed line: row 20 of the frame."""
    by_name = dict((s[0], s) for s in states)
    fly, shd, idle = by_name['gold_fly'], by_name['shadow_fly'], by_name['gold']
    label, ch = 14, S + FLY_LIFT
    ncol = 13
    pw, ph = S * ncol, (label + ch) * 4 + label + S + 6
    sheet = Image.new('RGBA', (pw * scale, ph * scale * 2), (0, 0, 0, 255))
    for bi, kind in enumerate(('grass', 'dark')):
        panel = ground(kind, pw, ph)
        mark = (255, 255, 255, 255) if kind == 'dark' else (40, 70, 30, 255)
        notes = []
        for di, d in enumerate(DIRS):
            y = label + di * (label + ch) + FLY_LIFT         # top of the ground-anchored frame
            for col in range(ncol):
                x = col * S
                for k in range(16, 80, 3):
                    for px_, py_ in ((x + k, y + 32), (x + k, y + 95), (x + 16, y + 32 + k - 16), (x + 79, y + 32 + k - 16)):
                        panel.putpixel((px_, py_), mark)
                fi = col % 4
                if col < 4:
                    panel.alpha_composite(shd[3][fi][di], (x, y))
                    panel.alpha_composite(fly[3][fi][di], (x, y - FLY_LIFT))
                    text = 'fly+shadow %s f%d d%s' % (d, fi + 1, fly[2][fi])
                elif col < 8:
                    for k in range(0, S, 4):
                        panel.putpixel((x + k, y + 20), mark)
                    panel.alpha_composite(fly[3][fi][di], (x, y))
                    text = 'gold_fly %s f%d' % (d, fi + 1)
                elif col < 12:
                    panel.alpha_composite(shd[3][fi][di], (x, y))
                    text = 'shadow_fly %s f%d' % (d, fi + 1)
                else:
                    panel.alpha_composite(idle[3][0][di], (x, y))
                    text = 'gold %s f1' % d
                notes.append((x + 2, y - FLY_LIFT - label + 2, text))
        big = panel.resize((pw * scale, ph * scale), Image.NEAREST)
        sy = ((label + ch) * 4 + label) * scale              # true-size strip, pasted unscaled
        for di in range(4):
            for fi in range(4):
                x = 4 + (di * 4 + fi) * (S + 4)
                big.alpha_composite(shd[3][fi][di], (x, sy + FLY_LIFT))
                big.alpha_composite(fly[3][fi][di], (x, sy))
        draw = ImageDraw.Draw(big)
        for x, y, text in notes:
            draw.text((x * scale, y * scale), text, fill=(240, 240, 240))
        draw.text((4, sy - 12), '1x: gold_fly lifted %d px over shadow_fly, S N E W, 4 frames each' % FLY_LIFT, fill=(240, 240, 240))
        sheet.alpha_composite(big, (0, bi * ph * scale))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.convert('RGB').save(path)


def main():
    states = build()
    write_dmi(ROOT / 'icons/mob/heteromorph_dragon.dmi', states)
    if '--preview' in sys.argv[1:-1]:
        write_preview(sys.argv[sys.argv.index('--preview') + 1], states)
    if '--flight-preview' in sys.argv[1:-1]:
        write_flight_preview(sys.argv[sys.argv.index('--flight-preview') + 1], states)


if __name__ == '__main__':
    main()
