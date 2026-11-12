"""Script-drawn 32px sea life for the Gaia sea layer: kelp turtle, reef eel,
drift jelly and a dead shoal. Every pixel is placed by this script from the
fixed palettes below (Pillow only); no external or generated artwork. The
animals are seen from above, lit from the upper left, and use light body
colours with a dark rim so they read against deep water.

Run with Pillow to reproduce icons/mob/sea_life.dmi. `--out <dmi>` writes the
sheet somewhere else, `--preview <png>` also writes a review sheet on sea-layer
water colours. Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]

# turtle shell, with the weed that grows on it
SHELL = [(184, 178, 100), (140, 142, 74), (102, 108, 56), (68, 76, 44), (28, 34, 24)]
WEED = [(132, 204, 96), (84, 156, 72)]
# turtle skin
SKIN = [(176, 206, 154), (128, 166, 116), (88, 124, 90), (56, 86, 66), (22, 38, 32)]
SKIN_SPOT = (60, 92, 70)
# turtle underside
PLASTRON = [(244, 230, 176), (216, 198, 138), (174, 154, 102), (126, 108, 72), (56, 46, 32)]
# eel back, speckles and pale belly
EEL = [(236, 200, 100), (200, 156, 64), (154, 112, 46), (106, 74, 34), (46, 30, 18)]
EEL_SPOT = (74, 46, 24)
EEL_FIN = (250, 226, 140)
BELLY = [(246, 236, 202), (222, 208, 166), (182, 168, 130), (132, 120, 94), (58, 50, 40)]
# reef rock and the crevice
ROCK = [(154, 148, 144), (118, 112, 110), (86, 82, 84), (58, 56, 64), (24, 24, 32)]
CREVICE = (8, 10, 16)
CORAL = [(236, 128, 122), (186, 78, 86)]
# jellyfish: glowing core, bell ramp, rim; alpha is set where it is painted
JELLY_CORE = (240, 252, 255)
JELLY = [(212, 240, 255), (158, 212, 250), (110, 172, 234), (76, 128, 200)]
JELLY_DEAD = [(176, 190, 204), (138, 154, 174), (104, 120, 144), (76, 90, 114), (34, 42, 58)]
# small silver fish
FISH = [(238, 242, 248), (188, 196, 210), (134, 144, 162), (90, 98, 116), (36, 40, 52)]
EYE = (12, 12, 16)
EYE_LIGHT = (250, 244, 200)
MOUTH = (150, 50, 54)

# forward vector on screen for each DMI direction slot (south, north, east, west)
FACING = [(0, 1), (0, -1), (1, 0), (-1, 0)]


class Frame:
    def __init__(self):
        self.px = {}
        self.rim = {}

    def put(self, x, y, c, rim=None):
        if 0 <= x < 32 and 0 <= y < 32:
            self.px[(x, y)] = c if len(c) == 4 else c + (255,)
            if rim:
                self.rim[(x, y)] = rim

    def outline(self):
        """Dark one-pixel rim around everything painted with a rim colour."""
        add = {}
        for (x, y), c in self.rim.items():
            for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if n not in self.px and 0 <= n[0] < 32 and 0 <= n[1] < 32:
                    add[n] = c
        for n, c in add.items():
            self.px[n] = c + (255,)

    def image(self):
        im = Image.new('RGBA', (32, 32))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c)
        return im


def band(light):
    return 0 if light > 0.5 else 1 if light > 0.0 else 2 if light > -0.55 else 3


def paint(parts, facing=(1, 0), centre=(16.0, 16.0)):
    """Rasterise parts given in body coordinates (u forward, v to the animal's
    right, in pixels from the tile centre). Each part is a function returning
    None, or (ramp, nu, nv, fixed): a colour ramp, the surface tilt across the
    part (-1..1 each way) used for upper-left lighting, and an optional fixed
    colour for markings. The first part that claims a pixel wins."""
    fx, fy = facing
    rx, ry = -fy, fx
    frame = Frame()
    for y in range(32):
        for x in range(32):
            cx, cy = x + 0.5 - centre[0], y + 0.5 - centre[1]
            u, v = cx * fx + cy * fy, cx * rx + cy * ry
            for part in parts:
                hit = part(u, v)
                if hit is None:
                    continue
                ramp, nu, nv, fixed = hit
                sx, sy = nu * fx + nv * rx, nu * fy + nv * ry
                colour = fixed or ramp[band(-(sx + sy) / 1.4142)]
                frame.put(x, y, colour, ramp[4])
                break
    frame.outline()
    return frame


def ellipse(cu, cv, ru, rv, ramp, mark=None):
    def part(u, v):
        du, dv = (u - cu) / ru, (v - cv) / rv
        if du * du + dv * dv > 1.0:
            return None
        return ramp, du, dv, mark(u, v, du, dv) if mark else None
    return part


def limb(a, b, wa, wb, ramp, mark=None):
    """A tapering paddle from a to b, mirrored on both sides of the body."""
    (au, av), (bu, bv) = a, b
    lu, lv = bu - au, bv - av
    length2 = lu * lu + lv * lv

    def part(u, v):
        v0 = abs(v)
        t = max(0.0, min(1.0, ((u - au) * lu + (v0 - av) * lv) / length2))
        du, dv = u - (au + lu * t), v0 - (av + lv * t)
        w = wa + (wb - wa) * t
        if du * du + dv * dv > w * w:
            return None
        return ramp, du / w, math.copysign(dv / w, v) if v else 0.0, mark(u, v0, t) if mark else None
    return part


def speck(u, v, salt=0):
    """Fixed pseudo-random pattern in body space, so markings turn with the animal."""
    n = int(math.floor(u * 2)) * 73856093 ^ int(math.floor(v * 2)) * 19349663 ^ salt * 83492791
    return (n & 0xffff) / 65535.0


# ---------------------------------------------------------------- kelp turtle

def turtle(facing):
    def scutes(u, v, du, dv):
        su, av, d = u + 1.0, abs(v), du * du + dv * dv
        if d > 0.74:
            return SHELL[2] if int(math.floor((math.atan2(dv, du) + math.pi) * 2.55)) % 2 else None
        if d > 0.56:
            return SHELL[3]
        seam = (2.0 < av < 3.0
                or (av < 2.0 and any(abs(su - s) < 0.5 for s in (-3.5, 0.5, 3.5)))
                or (av > 3.0 and any(abs(su - s) < 0.5 for s in (-1.5, 2.5))))
        if seam:
            return SHELL[3]
        if speck(u, v, 3) > 0.86:
            return WEED[0] if dv + du > 0.1 else WEED[1]
        return None

    def skin(u, v, t=0.0):
        return SKIN_SPOT if speck(u, v, 5) > 0.8 else None

    def head_marks(u, v, du, dv):
        if abs(u - 10.5) < 0.5 and abs(abs(v) - 1.5) < 0.5:
            return EYE
        return SKIN_SPOT if abs(v) < 1.0 and u < 10.0 else None

    return paint([
        ellipse(-1.0, 0.0, 8.0, 6.5, SHELL, scutes),
        ellipse(10.0, 0.0, 2.9, 2.4, SKIN, head_marks),
        ellipse(7.5, 0.0, 2.0, 1.6, SKIN),
        limb((5.0, 5.0), (0.5, 12.5), 2.3, 1.2, SKIN, skin),
        limb((-7.0, 3.5), (-11.0, 6.5), 1.7, 1.1, SKIN, skin),
        ellipse(-10.0, 0.0, 1.6, 0.9, SKIN),
    ], facing)


def turtle_dead():
    """Belly up, head to the right and tipped, flippers limp along the shell."""
    def plates(u, v, du, dv):
        su, av, d = u + 1.0, abs(v), du * du + dv * dv
        if d > 0.72:
            return SHELL[2] if d > 0.86 else SHELL[1]
        if av < 1.0 or any(abs(su - s) < 0.5 for s in (-3.5, -0.5, 2.5)):
            return PLASTRON[3]
        return None

    def head_marks(u, v, du, dv):
        return EYE if abs(u - 10.5) < 0.5 and abs(v + 2.5) < 0.5 else None

    def limp(a, b, wa, wb, side):
        base = limb((a[0], abs(a[1])), (b[0], abs(b[1])), wa, wb, SKIN)
        return lambda u, v: base(u, v) if v * side > 0 else None

    return paint([
        ellipse(-1.0, 0.0, 8.0, 6.5, PLASTRON, plates),
        ellipse(10.0, -1.5, 2.8, 2.3, SKIN, head_marks),
        ellipse(7.5, -0.5, 2.0, 1.6, SKIN),
        limp((4.5, 5.5), (-3.0, 9.5), 2.1, 1.2, 1),
        limp((5.0, 5.0), (3.0, 11.0), 2.1, 1.2, -1),
        limp((-7.0, 3.5), (-10.0, 7.5), 1.6, 1.0, 1),
        limp((-7.0, 3.5), (-11.5, 4.5), 1.6, 1.0, -1),
        ellipse(-10.0, 0.5, 1.6, 0.9, SKIN),
    ], (1, 0), (16.0, 17.0))


# ------------------------------------------------------------------- reef eel

def eel_body(spine, width, ramp, mark):
    """A ribbon along a sampled spine; `width(t)` is the half-width at t in 0..1
    from tail to snout."""
    def part(u, v):
        best = None
        for i, (su, sv) in enumerate(spine):
            d = (u - su) ** 2 + (v - sv) ** 2
            if best is None or d < best[0]:
                best = (d, i)
        d, i = best
        t = i / (len(spine) - 1.0)
        w = width(t)
        if d > w * w:
            return None
        su, sv = spine[i]
        j = min(len(spine) - 1, i + 1)
        k = max(0, i - 1)
        tu, tv = spine[j][0] - spine[k][0], spine[j][1] - spine[k][1]
        side = ((u - su) * -tv + (v - sv) * tu) / (math.hypot(tu, tv) or 1.0)
        return ramp, (u - su) / w, (v - sv) / w, mark(u, v, t, side, w)
    return part


def eel_width(t):
    if t < 0.35:
        return 1.0 + 1.6 * (t / 0.35)
    if t > 0.84:
        return 3.2 - 0.9 * ((t - 0.84) / 0.16) ** 2
    return 2.6 + 0.6 * max(0.0, (t - 0.7) / 0.14)


def eel_marks(u, v, t, side, w):
    if t > 0.88:
        if abs(abs(side) - 1.6) < 0.6 and 0.915 < t < 0.955:
            return EYE
        return None
    if abs(side) < 0.5 and 0.06 < t < 0.8:
        return EEL_FIN
    n = speck(u, v, 11)
    if n > 0.7:
        return EEL_SPOT
    return EEL[3] if n < 0.1 else None


def eel(facing):
    spine = []
    for i in range(121):
        t = i / 120.0
        u = -14.0 + 25.5 * t
        sway = 3.4 * math.sin(t * 2.0 * math.pi * 1.05 + 0.6) * (1.0 - 0.8 * max(0.0, (t - 0.65) / 0.35))
        spine.append((u, sway))
    return paint([eel_body(spine, eel_width, EEL, eel_marks)], facing)


def eel_dead():
    """Limp and rolled half over: pale belly up, a strip of speckled back along one edge."""
    spine = []
    for i in range(121):
        t = i / 120.0
        a = math.pi * (0.95 - 1.25 * t)
        spine.append((0.5 - 10.5 * math.cos(a) * (1.0 if t < 0.7 else 1.0 + 0.3 * (t - 0.7)), -4.0 + 9.0 * math.sin(a) + 3.0 * t))

    def marks(u, v, t, side, w):
        if t > 0.88:
            return EYE if abs(side + 1.6) < 0.6 and 0.915 < t < 0.955 else None
        if side > 1.2:
            return EEL_SPOT if speck(u, v, 11) > 0.6 else EEL[2]
        return None

    return paint([eel_body(spine, eel_width, BELLY, marks)], (1, 0), (16.0, 14.0))


def eel_hidden():
    """A reef rock with a dark crevice; the eel's head and gaping mouth poke out to the south."""
    def rock_marks(salt):
        def mark(u, v, du, dv):
            n = speck(u, v, salt)
            if n > 0.93:
                return ROCK[3]
            return ROCK[0] if n < 0.05 and du + dv < 0 else None
        return mark

    def crevice(u, v):
        du, dv = u / 6.6, (v - 2.5) / 4.4
        if du * du + dv * dv > 1.0 or v > 6.2:
            return None
        return ROCK, 0.0, 0.0, CREVICE

    def head_marks(u, v, du, dv):
        if abs(v - 4.5) < 0.5 and abs(abs(u) - 2.5) < 0.5:
            return EYE
        if 7.0 < v < 9.0 and abs(u) < 1.0 or abs(v - 6.5) < 0.5 and abs(u) < 2.0:
            return MOUTH
        return EEL_SPOT if speck(u, v, 11) > 0.72 and v < 4.0 else None

    def coral(cu, cv):
        def part(u, v):
            du, dv = abs(u - cu), abs(v - cv)
            if du + dv > 1.0:
                return None
            return (CORAL + [None, None, ROCK[4]]), 0.0, 0.0, CORAL[0] if du + dv < 1.0 and u <= cu and v <= cv else CORAL[1]
        return part

    return paint([
        ellipse(0.0, 5.5, 3.6, 4.2, EEL, head_marks),
        ellipse(0.0, 1.0, 3.0, 3.0, EEL, lambda u, v, du, dv: EEL_SPOT if speck(u, v, 11) > 0.7 else None),
        coral(-9.5, -5.5), coral(8.5, -7.5), coral(10.5, 1.5),
        crevice,
        ellipse(-7.0, 2.0, 6.0, 6.0, ROCK, rock_marks(1)),
        ellipse(7.5, 1.0, 6.0, 6.5, ROCK, rock_marks(2)),
        ellipse(0.5, -4.0, 9.5, 6.5, ROCK, rock_marks(3)),
        ellipse(-10.0, 6.5, 3.5, 2.5, ROCK, rock_marks(4)),
    ], (1, 0), (16.0, 15.0))


# ---------------------------------------------------------------- drift jelly

JELLY_FRAMES = 8


def jelly(step):
    """One frame of the pulse: the bell flattens and rounds, the threads sway,
    and a faint halo of light surrounds the bell."""
    frame = Frame()
    phase = 2.0 * math.pi * step / JELLY_FRAMES
    squeeze = math.sin(phase)
    rx, ry = 7.0 + 1.0 * squeeze, 5.6 - 0.9 * squeeze
    cx, cy = 16.0, 10.5 - 0.5 * squeeze
    skirt = cy + ry * 0.45
    bell = {}
    for y in range(32):
        for x in range(32):
            px, py = x + 0.5, y + 0.5
            du, dv = (px - cx) / rx, (py - cy) / ry
            d = du * du + dv * dv
            if d > 1.0 or py > skirt + (0.9 if int(x) % 3 == 1 else 0.0):
                continue
            bell[(x, y)] = (du, dv, d)
    # threads first, so the bell sits on top of them
    for i, x0 in enumerate((10, 12, 14, 17, 19, 21)):
        length = (11, 14, 9, 10, 14, 11)[i] - int(round(squeeze))
        arm = i in (2, 3)
        for n in range(length):
            y = int(skirt) + n
            sway = (1.6 if not arm else 0.9) * math.sin(n * 0.55 - phase + i * 1.3) * min(1.0, n / 4.0)
            x = x0 + int(round(sway + (x0 - 15.5) * 0.06 * n * (0.4 + 0.3 * squeeze)))
            fade = 1.0 - n / float(length)
            alpha = int(round((230 if arm else 190) * (0.35 + 0.65 * fade) / 5.0)) * 5
            frame.put(x, y, (JELLY[1] if arm else JELLY[2]) + (alpha,))
            if arm and n < length - 3:
                frame.put(x + (1 if i == 2 else -1), y, JELLY[2] + (alpha - 40,))
    for (x, y), (du, dv, d) in bell.items():
        light = -(du + dv) / 1.4142
        edge = any(n not in bell for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))
        if edge:
            colour = JELLY[1] + (245,) if light > 0.1 else JELLY[3] + (235,)
        elif d < 0.16 and dv > -0.25:
            colour = JELLY_CORE + (245,)
        elif light > 0.42:
            colour = JELLY[0] + (225,)
        elif light > -0.15:
            colour = JELLY[1] + (200,)
        else:
            colour = JELLY[2] + (200,)
        # four pale rings show through the bell
        if not edge and d > 0.2 and abs(abs(du) - 0.45) < 0.14 and abs(dv + 0.05) < 0.3:
            colour = JELLY[0] + (235,)
        frame.put(x, y, colour)
    glow = 1.0 + 0.25 * squeeze
    halo = {}
    for (x, y) in bell:
        for dx in range(-3, 4):
            for dy in range(-3, 4):
                n = (x + dx, y + dy)
                if n in frame.px or not (0 <= n[0] < 32 and 0 <= n[1] < 32):
                    continue
                dist = math.hypot(dx, dy)
                level = 70 if dist < 1.5 else 40 if dist < 2.5 else 20 if dist < 3.3 else 0
                halo[n] = max(halo.get(n, 0), level)
    for n, level in halo.items():
        if level:
            frame.put(n[0], n[1], JELLY[1] + (int(round(level * glow / 5.0)) * 5,))
    return frame


def jelly_dead():
    """Collapsed and dull on the seabed: a flat torn disc with its threads in a heap."""
    def marks(u, v, du, dv):
        d = du * du + dv * dv
        if d > 0.7:
            return JELLY_DEAD[2] if speck(u, v, 2) > 0.3 else JELLY_DEAD[3]
        if abs(abs(du) - 0.35) < 0.13 and abs(dv) < 0.4:
            return JELLY_DEAD[0]
        return None

    def thread(points):
        cells = set()
        for (x0, y0), (x1, y1) in zip(points, points[1:]):
            steps = max(abs(x1 - x0), abs(y1 - y0)) or 1
            for s in range(steps + 1):
                cells.add((x0 + round((x1 - x0) * s / steps), y0 + round((y1 - y0) * s / steps)))
        return cells

    frame = paint([ellipse(-1.0, -1.0, 8.5, 4.6, JELLY_DEAD, marks)], (1, 0), (16.0, 17.0))
    for points in ([(18, 20), (22, 22), (25, 21), (27, 23)], [(14, 21), (12, 24), (15, 26), (19, 25)],
                   [(9, 20), (6, 22), (5, 25)], [(20, 20), (21, 24), (24, 25)]):
        for x, y in thread(points):
            if (x, y) not in frame.px:
                frame.put(x, y, JELLY_DEAD[2] + (255,))
    return frame


# ----------------------------------------------------------------- dead shoal

# One small fish lying on its side, head to the left. 1-4 index FISH from light
# to dark, e is the eye, b a pale belly pixel; the dark rim is added afterwards.
FISH_SIDE = (
    "...3333....4",
    ".3222223..43",
    "1e111112332.",
    ".1bbbbb2..43",
    "...1bb.....4",
)
FISH_SMALL = (
    ".2332..3",
    "1e11223.",
    ".1bb...3",
)


def stamp(frame, art, x0, y0, flip_x=False, flip_y=False, turn=False):
    rows = [row[::-1] for row in art] if flip_x else list(art)
    if flip_y:
        rows = rows[::-1]
    key = {'e': EYE, 'b': FISH[0], '1': FISH[0], '2': FISH[1], '3': FISH[2], '4': FISH[3]}
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch != '.':
                frame.put(x0 + (j if turn else i), y0 + (i if turn else j), key[ch], FISH[4])


def shoal_dead():
    frame = Frame()
    stamp(frame, FISH_SIDE, 2, 4)
    stamp(frame, FISH_SIDE, 17, 9, flip_x=True, flip_y=True)
    stamp(frame, FISH_SMALL, 5, 13, flip_y=True)
    stamp(frame, FISH_SIDE, 9, 20, flip_x=True)
    stamp(frame, FISH_SMALL, 25, 17, turn=True)
    stamp(frame, FISH_SMALL, 2, 26, flip_x=True, flip_y=True)
    frame.outline()
    return frame


# ---------------------------------------------------------------------- sheet

def states():
    """name -> (dirs, delays or None, frames in DMI order)."""
    return [
        ('kelp_turtle', 4, None, [turtle(f) for f in FACING]),
        ('kelp_turtle_dead', 1, None, [turtle_dead()]),
        ('reef_eel', 4, None, [eel(f) for f in FACING]),
        ('reef_eel_hidden', 1, None, [eel_hidden()]),
        ('reef_eel_dead', 1, None, [eel_dead()]),
        ('drift_jelly', 1, [2] * JELLY_FRAMES, [jelly(i) for i in range(JELLY_FRAMES)]),
        ('drift_jelly_dead', 1, None, [jelly_dead()]),
        ('shoal_dead', 1, None, [shoal_dead()]),
    ]


def write_dmi(path, table):
    frames = [fr for _, _, _, frs in table for fr in frs]
    cols = 8
    rows = (len(frames) + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * 32, rows * 32))
    for i, fr in enumerate(frames):
        sheet.paste(fr.image(), ((i % cols) * 32, (i // cols) * 32))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, dirs, delays, frs in table:
        text += 'state = "%s"\n\tdirs = %d\n\tframes = %d\n' % (name, dirs, len(frs) // dirs)
        if delays:
            text += '\tdelay = %s\n' % ','.join(str(d) for d in delays)
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta)


def write_preview(path, table, scale=6):
    """Review sheet: every frame on shallow and deep sea-layer water, enlarged,
    with a true-size strip underneath each band."""
    frames = [fr.image() for _, _, _, frs in table for fr in frs]
    cols = 8
    rows = (len(frames) + cols - 1) // cols
    cell = 32 * scale
    band_h = rows * cell + 48
    sheet = Image.new('RGBA', (cols * cell, band_h * 2))
    for b, water in enumerate(((0, 106, 138, 255), (10, 38, 62, 255))):
        sheet.paste(water, (0, b * band_h, cols * cell, (b + 1) * band_h))
        for i, im in enumerate(frames):
            sheet.alpha_composite(im.resize((cell, cell), Image.NEAREST), ((i % cols) * cell, b * band_h + (i // cols) * cell))
            sheet.alpha_composite(im, (8 + i * 34, b * band_h + rows * cell + 8))
    sheet.convert('RGB').save(path)


def write_gif(path, table, scale=6):
    for name, _, delays, frs in table:
        if name != 'drift_jelly':
            continue
        out = []
        for fr in frs:
            bg = Image.new('RGBA', (32, 32), (10, 38, 62, 255))
            bg.alpha_composite(fr.image())
            out.append(bg.resize((32 * scale, 32 * scale), Image.NEAREST).convert('P', palette=Image.ADAPTIVE))
        out[0].save(path, save_all=True, append_images=out[1:], duration=[d * 100 for d in delays], loop=0)


def option(name):
    args = sys.argv[1:]
    return args[args.index(name) + 1] if name in args[:-1] else None


def main():
    table = states()
    write_dmi(option('--out') or ROOT / 'icons/mob/sea_life.dmi', table)
    if option('--preview'):
        write_preview(option('--preview'), table)
    if option('--gif'):
        write_gif(option('--gif'), table)


if __name__ == '__main__':
    main()
