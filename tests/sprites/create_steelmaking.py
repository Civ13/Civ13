"""Hand-placed sprites for realistic steelmaking in icons/obj/steelmaking.dmi:
the eight furnaces (coke bank, finery, cementation furnace, puddling furnace,
Bessemer converter, open hearth, electric arc furnace and the carburizing
pot), each with a still state and a four-frame burning loop, and the items:
coke, nickel, cobalt and chromite ore piles (four sizes each), the steely
bloom, the clay steel crucible (raw, fired, sealed), inconel bars (four pile
sizes) and the blister, fine, nickel and maraging steel stacks. Every pixel
is placed by this script from a fixed palette (Pillow only); no external or
generated artwork. The fired clay is the bloomery's palette from
icons/obj/metallurgy.dmi (by way of create_tatara.py) and the stone, iron,
fire and smoke colours are those of create_clay_lime_fire.py.

Run with Pillow to write the sheet. `--check` verifies the committed sheet,
`--preview <png>` writes a labelled 4x review sheet on grass and on dirt.
Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_clay_lime_fire import STONE, IRON, FIRE, SMOKE, SOOT, grain  # noqa: E402
from create_tatara import Sprite, inside, CLAY, CHAR, EMBER, KERA, RUST, SLAG, HOLE  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/steelmaking.dmi'

SIZE = 32
FIRE_DELAY = 1         # deciseconds per frame, as bloomery_on
FIRE_FRAMES = 4

# red furnace brick: highlight, light, mid, dark, deep
BRICK = [(204, 112, 82), (176, 88, 64), (146, 68, 50), (112, 50, 40), (80, 36, 32)]
# plate steel of the converter and the arc furnace shell
PLATE = [(158, 164, 176), (120, 126, 140), (88, 94, 108), (60, 64, 78), (40, 42, 54)]
CARBON = [(72, 72, 78), (48, 48, 54), (30, 30, 36)]           # electrodes
WHITE_HOT = (255, 252, 226)
ARC = (214, 238, 255)
LUTE = [(226, 208, 172), (196, 176, 140), (160, 140, 110)]    # clay luting
RAW = [(184, 166, 142), (156, 138, 116), (128, 110, 92), (100, 84, 70), (74, 62, 54)]
EDGE = (22, 20, 22)

# ores: lit, mid, shade, deep, then the accents
COKE = [(166, 166, 170), (132, 132, 138), (98, 98, 104), (66, 66, 72)]
COKE_PORE, COKE_GLINT = (30, 30, 34), (200, 202, 208)
NICKEL = [(230, 198, 122), (194, 158, 86), (150, 118, 64), (106, 82, 48)]
NICKEL_GLINT, HOST = (252, 238, 184), [(98, 94, 90), (70, 68, 66)]
COBALT = [(232, 234, 238), (192, 196, 206), (146, 150, 164), (102, 106, 122)]
BLOOM_PINK = [(236, 164, 192), (204, 118, 160)]
CHROME = [(92, 90, 98), (60, 58, 66), (40, 38, 44), (24, 22, 28)]
CHROME_GLINT, CHROME_STREAK = (158, 154, 146), (78, 62, 50)
STEEL = [(232, 238, 246), (196, 204, 218), (156, 166, 182), (114, 124, 142), (78, 86, 102)]
INCONEL = [(176, 184, 156), (140, 150, 124), (106, 116, 96), (76, 84, 72), (52, 58, 52)]
# sheet stacks: lit, top, left side, right side, seam
BLISTER = [(150, 144, 146), (112, 108, 112), (86, 82, 88), (62, 58, 64), (40, 38, 42)]
FINE = [(246, 250, 255), (208, 216, 230), (160, 170, 188), (116, 126, 146), (76, 84, 102)]
NICKEL_STEEL = [(248, 244, 232), (212, 206, 192), (168, 160, 146), (124, 116, 104), (84, 78, 70)]
MARAGING = [(110, 128, 176), (58, 68, 104), (42, 48, 78), (28, 32, 54), (16, 18, 32)]
SOFT = [(150, 152, 154), (132, 134, 136), (104, 106, 110), (80, 82, 86), (56, 58, 62)]


# -------------------------------------------------------------- helpers --

def brick(x, y, tone, pal=BRICK, seed=0):
    """Running-bond brickwork; tone 0 lit, 1 mid, 2 shaded."""
    course = y // 3
    i = tone + 1
    if y % 3 == 2 or (x + (course % 2) * 3) % 6 == 0:
        i += 1
    elif grain(x, y, seed) == 0:
        i -= 1
    return pal[min(4, i)]


def wall(f, y0, y1, span, pal=BRICK, seed=0):
    """Brick between span(y) = (left, right), lit from the left."""
    for y in range(y0, y1 + 1):
        xa, xb = span(y)
        for x in range(xa, xb + 1):
            r = (x - xa) / float(max(1, xb - xa))
            f.put(x, y, brick(x, y, 0 if r < 0.2 else (2 if r > 0.74 else 1), pal, seed))


def drum(f, y0, y1, span, pal=PLATE):
    """A round metal body between span(y), with a highlight left of centre."""
    for y in range(y0, y1 + 1):
        xa, xb = span(y)
        for x in range(xa, xb + 1):
            r = (x - xa) / float(max(1, xb - xa))
            i = 2 if r < 0.1 else (1 if r < 0.26 else (0 if r < 0.4 else (1 if r < 0.62 else (2 if r < 0.86 else 3))))
            f.put(x, y, pal[i])


def arch(f, x0, y0, x1, y1, c):
    """A round-headed opening."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if y == y0 and x in (x0, x1):
                continue
            f.put(x, y, c)


def blend(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def glow(f, cx, cy, r, colour, strength=1.0):
    """Light spilling from a hot spot: tints drawn pixels and leaves a
    fading translucent halo on the clear ones."""
    for y in range(int(cy - r), int(cy + r) + 1):
        for x in range(int(cx - r), int(cx + r) + 1):
            d = math.hypot(x - cx, y - cy)
            if d > r or not (0 <= x < SIZE and 0 <= y < SIZE):
                continue
            t = strength * (1.0 - d / r)
            old = f.px.get((x, y))
            if old is None:
                f.put(x, y, colour + (int(200 * t),))
            elif len(old) == 3:
                f.put(x, y, blend(old, colour, t))


def flames(f, x0, x1, base, hmax, k, seed=0):
    """A bed of flame rising from the row `base`."""
    mid, half = (x0 + x1) / 2.0, (x1 - x0) / 2.0 + 0.5
    for x in range(x0, x1 + 1):
        nx = (x - mid) / half
        h = (1.0 - nx * nx) ** 0.6 * hmax * (0.62 + 0.26 * math.sin(x * 0.9 + k * math.pi / 2.0 + seed)
                                             + 0.16 * math.sin(x * 1.7 - k * math.pi + 1.0))
        h = max(1.0, h)
        for y in range(base, base - int(round(h)) - 1, -1):
            t = (base - y) / h
            f.put(x, y, FIRE[0] if t < 0.3 else (FIRE[1] if t < 0.58 else (FIRE[2] if t < 0.84 else FIRE[3])))


def smoke(f, x0, y0, k, puffs=2, drift=1, tones=SMOKE):
    """Puffs climbing two pixels a frame, eight apart, so four frames loop."""
    span = 8 * puffs
    for j in range(puffs):
        p = (2 * k + 8 * j) % span
        x = x0 + drift * (p // 3) + (1 if (p // 2 + j) % 2 else 0)
        y = y0 - p
        a = int(225 - 170 * p / float(span))
        c = tones[j % 2]
        d = tones[(j + 1) % 2]
        f.put(x, y, c + (a,))
        f.put(x + 1, y, d + (a,))
        if p >= 2:
            f.put(x, y - 1, d + (a,))
            f.put(x + 1, y + 1, c + (int(a * 0.7),))
        if p >= 6:
            f.put(x - 1, y, c + (int(a * 0.7),))
            f.put(x + 2, y - 1, d + (int(a * 0.6),))
            f.put(x + 1, y - 1, c + (a,))


def sparks(f, spots, k):
    """Each spark climbs two pixels a frame and fades, repeating every four."""
    for i, (sx, sy) in enumerate(spots):
        phase = (k + i) % FIRE_FRAMES
        x = sx + (1 if (phase + i) % 2 else 0) * (1 if i % 2 else -1)
        tone = (FIRE[0], FIRE[1], FIRE[1], FIRE[2])[phase]
        f.put(x, sy - 2 * phase, tone + ((255, 235, 190, 130)[phase],))


def coals(f, x0, y0, x1, y1, seed, heat=None):
    """Charcoal lumps; with heat (the burning step) they glow."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            f.put(x, y, coal(x, y, seed, heat))


def coal(x, y, seed, heat=None):
    lump = grain(x // 2, (y + x // 4) // 2, seed)
    c = CHAR[1] if lump < 4 else (CHAR[2] if lump < 9 else CHAR[3])
    if grain(x, y, seed + 1) == 0:
        c = CHAR[0]
    if heat is not None:
        g = grain(x // 2, (y + x // 4) // 2, seed + 2 + (heat % 2))
        if g < 3:
            c = FIRE[2]
        elif g < 6:
            c = EMBER[1] if grain(x, y, seed + 3) > 2 else FIRE[1]
        elif g < 8:
            c = EMBER[2]
    return c


# ------------------------------------------------------------ coke bank --

def coke_bank(step=None):
    """A low brick oven banked up like a clamp, the door bricked to an
    arch, a short vent collar on the crown."""
    f = Sprite()
    for x in range(3, 29):
        nx = (x - 15.5) / 13.0
        top = 28 - int(round(14 * (1.0 - abs(nx) ** 2.6) ** 0.6))
        for y in range(top, 29):
            tone = 0 if (y - top < 2 and nx < 0.5) else (2 if nx > 0.5 else (0 if nx < -0.62 else 1))
            f.put(x, y, brick(x, y, tone, CLAY, 201))
    wall(f, 10, 14, lambda y: (12, 19), CLAY, 203)        # vent collar
    f.hline(12, 19, 10, CLAY[0])
    f.hline(13, 18, 11, SOOT)
    f.hline(11, 20, 18, CLAY[0])                          # arch ring
    f.vline(10, 20, 28, CLAY[1])
    f.vline(21, 20, 28, CLAY[3])
    f.pts(CLAY[0], (10, 19), (21, 19))
    arch(f, 11, 19, 20, 28, SOOT)
    coals(f, 12, 24, 19, 28, 205)
    f.pts(CHAR[1], (13, 23), (14, 23), (17, 23), (18, 22), (18, 23))
    if step is not None:
        k = step % FIRE_FRAMES
        for y in range(20, 29):
            for x in range(11, 21):
                if (x, y) in ((11, 19), (20, 19)):
                    continue
                f.put(x, y, FIRE[3] if y < 22 else coal(x, y, 205, k))
        flames(f, 12, 19, 25, 4, k, 2)
        coals(f, 12, 27, 19, 28, 205, k)
        f.hline(13, 18, 11, FIRE[2])
        f.pts(FIRE[1], (14 + k % 3, 11), (17 - k % 2, 11))
        f.hline(11, 20, 18, (236, 156, 96))
    f.outline(HOLE)
    if step is not None:
        glow(f, 15.5, 29, 4, FIRE[2], 0.5)
        smoke(f, 14, 9, k, 2, 1, (SMOKE[1], (84, 82, 84)))
        smoke(f, 16, 7, (k + 2) % 4, 1, 1)
    return f


# --------------------------------------------------------------- finery --

def finery(step=None):
    """A small open hearth under a brick hood: the charcoal fire on the
    hearth, a pig of iron across it and the tuyere blowing in from the left."""
    f = Sprite()
    wall(f, 0, 3, lambda y: (13, 18), BRICK, 211)          # flue
    f.hline(12, 19, 0, BRICK[0])
    wall(f, 4, 11, lambda y: (16 - (5 + y - 4), 15 + (5 + y - 4)), BRICK, 213)   # hood
    f.hline(4, 27, 11, BRICK[3])
    f.rect(6, 12, 25, 17, SOOT)                            # the hearth mouth
    for y in range(12, 15):
        for x in range(7, 25):
            if grain(x, y, 215) < 3:
                f.put(x, y, BRICK[4])
    wall(f, 12, 17, lambda y: (3, 6), BRICK, 217)          # cheeks
    wall(f, 12, 17, lambda y: (25, 28), BRICK, 217)
    f.hline(2, 29, 18, STONE[0])                           # hearth slab
    f.hline(2, 29, 19, STONE[2])
    wall(f, 20, 28, lambda y: (3, 28), BRICK, 219)
    arch(f, 13, 23, 18, 28, SOOT)                          # ash hole
    f.hline(12, 19, 22, BRICK[0])
    f.pts(STONE[1], (14, 28), (16, 28), (17, 27))
    for x in range(9, 23):                                 # the fire
        nx = (x - 15.5) / 7.0
        top = 17 - int(round(2.4 * (1.0 - nx * nx)))
        for y in range(top, 18):
            f.put(x, y, coal(x, y, 221, step))
    f.hline(12, 19, 14, IRON[0])                           # the pig
    f.hline(12, 19, 15, IRON[2])
    f.pts(IRON[1], (12, 14), (19, 14))
    f.hline(0, 8, 14, IRON[0])                             # tuyere
    f.hline(0, 8, 15, IRON[2])
    f.pts(IRON[1], (3, 14), (6, 14), (9, 15))
    f.pts(STONE[0], (9, 14))
    if step is not None:
        k = step % FIRE_FRAMES
        flames(f, 9, 22, 15, 5, k, 4)
        f.hline(12, 19, 14, WHITE_HOT if k % 2 else FIRE[0])
        f.hline(12, 19, 15, FIRE[1])
        f.pts(FIRE[0], (13, 15), (17 - k % 2, 15))
        f.pts(FIRE[2], (11, 15), (20, 15), (12 + k, 16))
        f.hline(9, 10, 14, FIRE[0])                        # the blast
        f.hline(4, 27, 11, (224, 132, 80))
        f.hline(7, 24, 18, (244, 206, 150))
    f.outline(EDGE)
    if step is not None:
        sparks(f, ((10, 13), (14, 12), (18, 13), (21, 12)), k)
        glow(f, 15.5, 15, 6, FIRE[1], 0.35)
        smoke(f, 15, 0, k, 1, 1)
    return f


# ---------------------------------------------------------- cementation --

def cement_span(y):
    half = 4 + int(round(7.4 * ((y - 9) / 19.0) ** 0.62))
    return 16 - half, 15 + half


def cementation(step=None):
    """A bottle-shaped brick cone drawing up into a chimney, iron hoops
    round the cone and the arched firing door at the foot."""
    f = Sprite()
    wall(f, 2, 8, lambda y: (13, 18), BRICK, 231)
    f.hline(12, 19, 1, BRICK[0])
    f.hline(12, 19, 2, BRICK[2])
    f.hline(13, 18, 0, SOOT)
    wall(f, 9, 28, cement_span, BRICK, 233)
    for hy in (13, 20):                                    # hoops
        xa, xb = cement_span(hy)
        f.hline(xa, xb, hy, IRON[1])
        f.hline(xa, xa + 2, hy, IRON[0])
        f.hline(xb - 1, xb, hy, IRON[2])
    f.hline(12, 19, 21, BRICK[0])
    f.vline(12, 22, 28, BRICK[1])
    f.vline(19, 22, 28, BRICK[4])
    arch(f, 13, 22, 18, 28, SOOT)
    f.pts(SOOT, (15, 16), (16, 16))                        # sight hole
    f.hline(15, 16, 15, BRICK[0])
    f.pts(CHAR[1], (14, 28), (15, 27), (17, 28))
    if step is not None:
        k = step % FIRE_FRAMES
        for y in range(23, 29):
            for x in range(13, 19):
                f.put(x, y, FIRE[min(3, grain(x, y, 235 + k) % 4 + (0 if y > 25 else 1))])
        f.pts(FIRE[0], (15, 27), (16, 26 + k % 2), (14 + k % 3, 28))
        f.hline(13, 18, 22, FIRE[3])
        f.pts(FIRE[1 + k % 2], (15, 16), (16, 16))
        f.hline(13, 18, 0, FIRE[2])
        f.pts(FIRE[1], (14 + k % 3, 0), (17 - k % 2, 0))
        f.hline(12, 19, 1, (236, 150, 100))
    f.outline(EDGE)
    if step is not None:
        glow(f, 15.5, 29, 4, FIRE[2], 0.5)
        smoke(f, 14, 0 + 4, k, 1, 1)
        smoke(f, 16, 2, (k + 2) % 4, 1, 1)
    return f


# ------------------------------------------------------------- puddling --

def puddling(step=None):
    """A long low reverberatory furnace: the firebox and its ash pit on the
    left, the iron-framed working door in the middle, the tall stack right."""
    f = Sprite()
    wall(f, 3, 28, lambda y: (23, 28), BRICK, 241)         # stack
    f.hline(22, 29, 2, BRICK[0])
    f.hline(22, 29, 3, BRICK[2])
    f.hline(23, 28, 1, SOOT)
    for by in (10, 18):
        f.hline(23, 28, by, IRON[1])
        f.put(23, by, IRON[0])

    def roof(y):
        return (2 + max(0, 15 - y) * 2, 22)
    wall(f, 13, 28, roof, BRICK, 243)
    f.hline(6, 22, 13, BRICK[0])
    f.hline(4, 22, 14, BRICK[0])
    f.hline(2, 22, 15, BRICK[1])
    for bx in (3, 19):                                     # buckstays
        f.vline(bx, 15, 28, IRON[1])
    f.hline(3, 19, 16, IRON[2])                            # tie bar
    f.pts(IRON[0], (3, 16), (19, 16))
    f.rect(9, 18, 16, 25, IRON[1])                         # door frame
    f.hline(9, 16, 18, IRON[0])
    f.vline(16, 19, 25, IRON[2])
    f.rect(10, 19, 15, 24, IRON[2])                        # the door plate
    f.rect(12, 21, 13, 22, SOOT)                           # stirring hole
    f.pts(IRON[0], (10, 19), (15, 19), (10, 24), (15, 24))
    f.rect(5, 20, 6, 22, IRON[2])                          # fire door
    f.hline(5, 6, 20, IRON[0])
    arch(f, 4, 25, 7, 28, SOOT)                            # ash pit
    f.pts(STONE[1], (5, 28), (6, 28))
    if step is not None:
        k = step % FIRE_FRAMES
        f.rect(12, 21, 13, 22, WHITE_HOT if k % 2 else FIRE[0])
        for x, y in ((10, 20), (10, 22), (10, 23), (15, 20), (15, 21), (15, 23), (11, 24), (13, 24), (14, 24),
                     (11, 19), (12, 19), (14, 19)):
            f.put(x, y, FIRE[2] if (x + y + k) % 3 else FIRE[1])
        f.pts(FIRE[1], (11, 21), (14, 22), (12, 20 + (k % 2) * 3), (13, 23 - (k % 2) * 3))
        f.pts(FIRE[2], (5, 21), (6, 22 - k % 2))
        for x in range(4, 8):
            for y in range(26, 29):
                f.put(x, y, FIRE[2 if (x + y + k) % 3 else 1] if y > 26 else FIRE[3])
        f.hline(23, 28, 1, FIRE[2])
        f.pts(FIRE[1], (24 + k % 3, 1), (27 - k % 2, 1))
        f.hline(22, 29, 2, (236, 150, 100))
        for i in range(7):                                 # the rabble
            f.put(11 - i, 23 + (i + 1) // 2, IRON[0] if i % 3 else IRON[1])
        f.put(12, 22, FIRE[1])
    f.outline(EDGE)
    if step is not None:
        glow(f, 12.5, 21.5, 4, FIRE[1], 0.4)
        glow(f, 5.5, 29, 3, FIRE[2], 0.5)
        f.pts(FIRE[1 + k % 2], (25 + k % 2, 0))
        smoke(f, 24, 4, k, 1, 1, (SMOKE[1], (84, 82, 84)))
        smoke(f, 26, 2, (k + 2) % 4, 1, 1)
    return f


# ------------------------------------------------------------- bessemer --

def bessemer(step=None):
    """The pear-shaped converter hung on trunnions between two iron
    standards, its mouth turned up and to the right."""
    f = Sprite()
    for x0 in (2, 26):                                     # standards
        for y in range(17, 29):
            spread = (y - 17) // 5
            f.hline(x0 + 1 - spread, x0 + 2 + spread, y, IRON[1])
            f.put(x0 + 1 - spread, y, IRON[0])
            f.put(x0 + 2 + spread, y, IRON[2])
        f.hline(x0 - 1, x0 + 4, 28, IRON[2])
        f.hline(x0, x0 + 3, 16, IRON[0])
    f.hline(5, 25, 18, IRON[0])                            # trunnions
    f.hline(5, 25, 19, IRON[2])
    discs = [(14.5, 20.0, 8.0, 7.6)]
    for i in range(9):                                     # the neck
        t = i / 8.0
        discs.append((15.0 + 4.5 * t, 14.0 - 6.0 * t, 6.4 - 2.6 * t, 6.4 - 2.6 * t))
    for y in range(3, 29):
        for x in range(4, 27):
            if not any(((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0 for cx, cy, rx, ry in discs):
                continue
            light = (x - 15.5) / 9.0 * 0.75 + (y - 16.0) / 12.0 * 0.6
            i = 0 if light < -0.42 else (1 if light < -0.12 else (2 if light < 0.28 else (3 if light < 0.6 else 4)))
            if grain(x, y, 251) == 0 and i < 4:
                i += 1
            f.put(x, y, PLATE[i])
    for by in (15, 24):                                    # riveted bands
        for x in range(4, 27):
            if (x, by) in f.px:
                f.put(x, by, PLATE[4] if x % 3 else PLATE[0])
    for x in range(6, 24):                                 # trunnion ring
        if (x, 18) in f.px:
            f.put(x, 18, PLATE[0] if x < 14 else PLATE[1])
            f.put(x, 19, PLATE[2] if x < 18 else PLATE[3])
            f.put(x, 20, PLATE[4])
    mouth = ((19, 6), (20, 6), (21, 6), (20, 7), (21, 7), (22, 7), (21, 8), (22, 8), (20, 5))
    f.pts(SOOT, *mouth)
    f.pts(PLATE[0], (18, 5), (19, 4), (18, 6))
    if step is not None:
        k = step % FIRE_FRAMES
        f.pts(FIRE[0], *mouth)
    f.outline(EDGE)
    if step is not None:
        for d in range(13):                                # the blow
            cx, cy = 21.0 + d * 0.8, 6.0 - d * 0.72
            r = 2.9 - 0.13 * d + 0.7 * math.sin(d * 1.3 + k * math.pi / 2.0)
            for y in range(int(cy - r) - 1, int(cy + r) + 2):
                for x in range(int(cx - r) - 1, int(cx + r) + 2):
                    q = math.hypot(x - cx, y - cy) / max(0.6, r)
                    if q > 1.0 or (x, y) in mouth:
                        continue
                    c = WHITE_HOT if q < 0.42 and d < 9 else (FIRE[0] if q < 0.7 else (FIRE[1] if d < 8 else FIRE[2]))
                    old = f.px.get((x, y))
                    if old in (WHITE_HOT, FIRE[0]) and c not in (WHITE_HOT,):
                        continue
                    f.put(x, y, c)
        f.pts(WHITE_HOT, *mouth)
        glow(f, 21, 6, 7, FIRE[1], 0.45)
        sparks(f, ((24, 12), (28, 9), (17, 3), (29, 14), (13, 5), (26, 16)), k)
        for i, (sx, sy) in enumerate(((27, 6), (30, 9), (24, 10), (29, 3))):     # sparks raining down
            p = (k + i) % FIRE_FRAMES
            f.put(sx + p % 2, sy + 2 * p, FIRE[1] + ((255, 220, 170, 110)[p],))
    return f


# ---------------------------------------------------------- open hearth --

DOORS = (4, 13, 22)      # left pixel of each charging door, six wide


def open_hearth(step=None):
    """A long brick furnace bound with iron buckstays, three arched
    charging doors along the front and the stack behind."""
    f = Sprite()
    wall(f, 2, 9, lambda y: (23, 28), BRICK, 261)          # stack
    f.hline(22, 29, 1, BRICK[0])
    f.hline(23, 28, 0, SOOT)
    wall(f, 12, 28, lambda y: (1, 30), BRICK, 263)
    for x in range(1, 31):                                 # sprung roof
        nx = (x - 15.5) / 15.0
        top = 9 + int(round(2.2 * nx * nx))
        for y in range(top, 12):
            f.put(x, y, BRICK[0] if y == top else (BRICK[1] if x < 22 else BRICK[2]))
        if x % 4 == 0:
            f.put(x, top + 1, BRICK[3])
    f.hline(1, 30, 12, IRON[2])                            # skewback channel
    f.hline(1, 30, 13, BRICK[3])
    for bx in (2, 11, 20, 29):                             # buckstays
        f.vline(bx, 11, 28, IRON[1])
        f.put(bx, 11, IRON[0])
        f.put(bx, 12, IRON[0])
    for dx in DOORS:
        f.hline(dx, dx + 5, 15, BRICK[0])                  # arch ring
        f.pts(BRICK[0], (dx - 1, 16), (dx + 6, 16))
        arch(f, dx, 16, dx + 5, 24, IRON[2])
        f.hline(dx + 1, dx + 4, 16, IRON[1])
        f.vline(dx, 17, 24, IRON[1])
        f.hline(dx + 2, dx + 3, 20, SOOT)                  # wicket hole
        f.pts(IRON[0], (dx + 1, 18), (dx + 4, 18), (dx + 1, 23), (dx + 4, 23))
    f.hline(1, 30, 25, STONE[0])                           # charging sill
    f.hline(1, 30, 26, STONE[2])
    if step is not None:
        k = step % FIRE_FRAMES
        for n, dx in enumerate(DOORS):
            hot = (k + n) % 2
            f.hline(dx + 2, dx + 3, 20, WHITE_HOT if hot else FIRE[0])
            for y in range(17, 25):                        # light round the door
                f.put(dx - 1, y, FIRE[2] if (y + k + n) % 3 else FIRE[3])
                f.put(dx + 6, y, FIRE[3] if (y + k + n) % 3 else FIRE[2])
            f.hline(dx, dx + 5, 15, (240, 160, 96))
        dx = DOORS[1]                                      # middle door lifted
        for y in range(21, 25):
            for x in range(dx, dx + 6):
                f.put(x, y, WHITE_HOT if (y > 22 and grain(x, y, 265 + k) < 6) else FIRE[0 if y > 21 else 1])
        f.hline(dx, dx + 5, 20, IRON[0])
        f.hline(dx + 1, dx + 4, 25, (255, 226, 170))
        f.hline(23, 28, 0, FIRE[2])
        f.pts(FIRE[1], (24 + k % 3, 0), (27 - k % 2, 0))
    f.outline(EDGE)
    if step is not None:
        glow(f, DOORS[1] + 2.5, 24, 5, FIRE[1], 0.45)
        smoke(f, 24, 3, k, 1, 1)
        smoke(f, 26, 1, (k + 2) % 4, 1, 1)
    return f


# ---------------------------------------------------------- arc furnace --

RODS = ((9, 11), (15, 12), (21, 11))      # left pixel and the row each electrode enters the lid


def arc_furnace(step=None):
    """A round steel shell on a rocker, a domed lid pierced by three
    carbon electrodes hung from a mast arm, the pouring spout to the left."""
    f = Sprite()
    f.rect(28, 3, 29, 28, IRON[1])                         # mast
    f.vline(28, 3, 28, IRON[0])
    f.hline(27, 30, 28, IRON[2])
    f.hline(8, 28, 3, IRON[0])                             # arm
    f.hline(8, 28, 4, IRON[2])

    def shell(y):
        cut = max(0, y - 23)
        cut = cut * cut // 2
        return (5 + cut, 26 - cut)
    drum(f, 14, 26, shell)
    for x in range(5, 27):                                 # seam and rivets
        f.put(x, 15, PLATE[4] if x % 3 else PLATE[0])
    f.hline(7, 24, 27, IRON[2])                            # rocker
    f.hline(9, 22, 28, IRON[1])
    f.pts(IRON[0], (9, 28), (22, 28))
    for y in range(9, 15):                                 # lid
        for x in range(4, 28):
            nx, ny = (x - 15.5) / 11.6, (y - 13.6) / 4.6
            if nx * nx + ny * ny > 1.0 or y > 14:
                continue
            light = nx * 0.8 + ny * 0.5
            f.put(x, y, PLATE[0] if light < -0.75 else (PLATE[1] if light < -0.2 else (PLATE[2] if light < 0.45 else PLATE[3])))
    f.hline(4, 27, 14, PLATE[3])
    f.pts(PLATE[0], (5, 14), (8, 14), (11, 14), (14, 14))
    for x, entry in RODS:
        f.rect(x, 2, x + 1, entry, CARBON[1])
        f.vline(x, 2, entry, CARBON[0])
        f.hline(x - 1, x + 2, 5, IRON[0])                  # clamp
        f.hline(x - 1, x + 2, 6, IRON[2])
        f.hline(x - 1, x + 2, entry, PLATE[4])             # lid port
        f.pts(CARBON[2], (x, entry), (x + 1, entry))
    f.rect(13, 18, 18, 23, PLATE[3])                       # slag door
    f.hline(13, 18, 18, PLATE[0])
    f.vline(13, 19, 23, PLATE[1])
    f.rect(15, 20, 16, 21, SOOT)
    f.hline(1, 5, 18, PLATE[1])                            # spout
    f.hline(1, 5, 19, SOOT)
    f.hline(2, 5, 20, PLATE[3])
    f.put(1, 18, PLATE[0])
    if step is not None:
        k = step % FIRE_FRAMES
        f.rect(15, 20, 16, 21, FIRE[0] if k % 2 else WHITE_HOT)
        f.hline(2, 5, 19, FIRE[2])
        f.put(2 + k, 19, FIRE[1])
        for n, (x, entry) in enumerate(RODS):
            f.pts(FIRE[1], (x, entry - 1), (x + 1, entry - 1))
            f.pts(FIRE[2], (x, entry - 2), (x + 1, entry - 2))
    f.outline(EDGE)
    if step is not None:
        for n, (x, entry) in enumerate(RODS):
            live = (k + n) % 4
            r = (5.5, 3.5, 6.5, 4.5)[live]
            glow(f, x + 0.5, entry, r, ARC, (0.9, 0.55, 1.0, 0.7)[live])
            f.pts((255, 255, 255), (x - 1, entry), (x + 2, entry), (x, entry), (x + 1, entry))
            if live in (0, 2):                             # the arc spitting
                f.pts(ARC, (x - 2, entry - 1), (x + 3, entry - 1), (x - 1, entry + 1), (x + 2, entry + 1))
                f.pts((255, 255, 255), (x - 3 + live, entry - 3), (x + 3 - live // 2, entry - 2))
        sparks(f, ((7, 9), (13, 8), (19, 9), (24, 8)), k)
        f.put(1, 20 + k % 2, FIRE[1] + (220,))
    return f


# ------------------------------------------------------ carburizing pot --

def carburizing_pot(step=None):
    """A lidded clay box, the lid luted down with clay, set in a bed of
    charcoal; lit, the charcoal burns and the box glows red."""
    f = Sprite()
    k = None if step is None else step % FIRE_FRAMES
    bed = {}
    for y in range(17, 31):                                # the charcoal bed
        for x in range(2, 30):
            nx, ny = (x - 15.5) / 13.0, (y - 24.0) / 5.6
            lumpy = 1.0 + 0.09 * math.sin(x * 1.9) + 0.06 * math.sin(x * 0.7 + 2)
            if nx * nx + ny * ny <= lumpy:
                bed[(x, y)] = coal(x, y, 281, k)
    for (x, y), c in bed.items():
        if (x, y - 1) not in bed and k is None:
            c = CHAR[0]
        f.put(x, y, c)
    for y in range(13, 25):                                # box front
        for x in range(9, 23):
            i = 2 if x < 20 else 3
            if x < 11:
                i = 1
            g = grain(x, y, 283)
            if g == 0:
                i -= 1
            elif g == 1:
                i += 1
            c = CLAY[min(4, i)]
            if k is not None:
                c = blend(c, (246, 92, 40), min(0.85, max(0.0, (y - 12) / 12.0)) * (0.8 + 0.1 * (k % 2)))
            f.put(x, y, c)
    for y in range(8, 13):                                 # lid, seen from above
        inset = (12 - y) // 2
        for x in range(8 + inset, 24 - inset):
            c = CLAY[0] if y < 11 else CLAY[1]
            if x > 20 - inset:
                c = CLAY[2]
            if grain(x, y, 285) == 0:
                c = CLAY[2]
            f.put(x, y, c)
    f.hline(8, 23, 13, CLAY[1])                            # lid edge
    f.hline(8, 23, 14, CLAY[3])
    f.rect(14, 8, 17, 9, CLAY[2])                          # lifting lug
    f.hline(14, 17, 7, CLAY[0])
    f.pts(CLAY[4], (14, 10), (15, 10), (16, 10), (17, 10))
    for x in range(8, 24):                                 # the luting
        g = grain(x, 0, 287)
        f.put(x, 14, LUTE[0] if g < 6 else LUTE[1])
        if g < 7:
            f.put(x, 15, LUTE[1] if g < 4 else LUTE[2])
        if g == 0:
            f.put(x, 16, LUTE[2])
        if g > 8:
            f.put(x, 13, LUTE[0])
    for x in range(8, 24):                                 # charcoal banked up the front
        h = 2 + grain(x // 2, 1, 289) % 3
        for y in range(25 - h, 25):
            f.put(x, y, coal(x, y, 281, k))
    if k is not None:
        f.hline(9, 22, 24, FIRE[1])
    f.outline(EDGE)
    if k is not None:
        flames(f, 4, 8, 22, 4, k, 1)
        flames(f, 23, 27, 22, 4, k, 3)
        flames(f, 11, 15, 27, 2, k, 5)
        flames(f, 18, 21, 28, 2, (k + 1) % 4, 6)
        glow(f, 15.5, 24, 8, FIRE[2], 0.15)
        sparks(f, ((6, 16), (25, 15), (12, 6), (20, 5)), k)
        smoke(f, 15, 5, k, 1, 1)
    return f


# ----------------------------------------------------------------- ores --

def lump(cx, cy, rx, ry, seed, shade, edge=EDGE, rough=1.0):
    """One irregular lump; shade(x, y, light, seed) picks each pixel."""
    g = Sprite()
    for y in range(int(cy - ry) - 2, int(cy + ry) + 3):
        for x in range(int(cx - rx) - 2, int(cx + rx) + 3):
            nx, ny = (x - cx) / rx, (y - cy) / ry
            a = math.atan2(ny, nx)
            rim = 1.0 + rough * (0.16 * math.sin(3 * a + seed) + 0.10 * math.sin(5 * a + 2 * seed))
            if math.hypot(nx, ny) > rim:
                continue
            g.put(x, y, shade(x, y, nx * 0.6 + ny * 0.75, seed))
    g.outline(edge)
    return g


def tone(pal, light):
    return pal[0] if light < -0.45 else (pal[1] if light < 0.1 else (pal[2] if light < 0.55 else pal[3]))


def coke_shade(x, y, light, seed):
    c = tone(COKE, light)
    p = grain(x, y, seed + 1)
    if p < 2 or (p == 2 and light > 0.1):
        return COKE_PORE                                   # the open pores
    if p == 3 and light < 0.2:
        return COKE_GLINT                                  # silvery cell walls
    return c


def nickel_shade(x, y, light, seed):
    if grain(x // 3, (y + 1) // 3, seed + 1) < 3:          # host rock
        return HOST[0] if light < 0.2 else HOST[1]
    c = tone(NICKEL, light)
    p = grain(x, y, seed + 2)
    if p == 0 and light < 0.3:
        return NICKEL_GLINT
    if p == 1:
        return NICKEL[3]
    if (x + 2 * y + seed) % 7 == 0 and light > -0.3:       # cleavage lines
        return NICKEL[2] if c != NICKEL[2] else NICKEL[3]
    return c


def cobalt_shade(x, y, light, seed):
    c = tone(COBALT, light)
    if grain(x // 2, (y + x // 3) // 2, seed + 1) < 2:     # the pink bloom
        return BLOOM_PINK[0] if light < 0.25 else BLOOM_PINK[1]
    p = grain(x, y, seed + 2)
    if p == 0 and light < 0.2:
        return (255, 255, 255)
    if p == 1:
        return COBALT[3]
    if (x - y + seed) % 5 == 0 and light > 0.0:            # crystal faces
        return COBALT[2]
    return c


def chromite_shade(x, y, light, seed):
    c = tone(CHROME, light)
    p = grain(x, y, seed + 1)
    if light < -0.35 and p < 5:
        return CHROME_GLINT                                # dull lustre on the lit faces
    if p == 0:
        return CHROME_GLINT
    if p == 1:
        return CHROME[3]
    if grain(x // 3, y // 2, seed + 2) == 0:
        return CHROME_STREAK
    return c


PILES = {
    1: [(15.5, 20, 5.5, 4)],
    2: [(10.5, 21, 5, 4), (20.5, 20, 5.5, 4.5)],
    3: [(9.5, 22, 5, 4), (21.5, 22, 5.5, 4), (15.5, 16, 6, 4.5)],
    4: [(8.5, 22.5, 5.5, 4.5), (22.5, 22.5, 6, 4.5), (15.5, 24, 5, 4),
        (11.5, 16, 5.5, 4.5), (20, 15.5, 5.5, 4.5), (15.5, 10, 5.5, 4.5)],
}
# chromite comes as heavy small grains: more and smaller pieces
GRAINS = {
    1: [(12.5, 21, 3.5, 3), (19, 20, 4, 3)],
    2: [(8.5, 21, 3.5, 3), (15, 22, 4, 3), (22, 21, 3.5, 3), (12.5, 17, 3.5, 3), (19, 17, 3.5, 2.8)],
    3: [(6.5, 22, 3.5, 3), (13, 23, 4, 3), (20, 23, 3.5, 3), (26, 22, 3.5, 3), (10, 18, 3.5, 3),
        (16.5, 18, 4, 3), (23, 18, 3.5, 3), (13.5, 13.5, 3.5, 3), (19.5, 14, 3.5, 2.8)],
    4: [(5.5, 23, 3.5, 3), (12, 24, 4, 3), (19, 24, 4, 3), (26, 23, 3.5, 3), (8.5, 19, 3.5, 3),
        (15.5, 20, 4, 3), (22.5, 19, 3.5, 3), (11.5, 15, 3.5, 3), (18.5, 15.5, 4, 3), (24.5, 15, 3, 2.6),
        (14.5, 11, 3.5, 3), (20, 11, 3.5, 2.8), (17, 7, 3.5, 2.8)],
}


def ore(shade, size, seed, layout=PILES, edge=EDGE, rough=1.0):
    f = Sprite()
    for i, spot in enumerate(layout[size]):
        f.stamp(lump(*spot, seed=seed + i * 7, shade=shade, edge=edge, rough=rough))
    return f


def steely_bloom():
    """A spongy bloom with bright steely patches, rust and glassy slag."""
    def shade(x, y, light, seed):
        c = KERA[0] if light < -0.45 else (KERA[1] if light < 0.25 else KERA[2])
        if grain(x // 3, (y + x // 5) // 3, seed + 1) < 4:                   # steel
            facet = grain((x + y // 2) // 2, y // 2, seed + 2)
            c = STEEL[1] if facet < 4 else (STEEL[2] if facet < 8 else STEEL[3])
            if grain(x, y, seed + 3) == 0:
                c = STEEL[0]
            return c
        if grain(x // 3, y // 2, seed + 4) < 2:                              # rust
            c = RUST[0] if light < -0.3 else (RUST[1] if light < 0.4 else RUST[2])
        elif grain((x + 1) // 3, (y + 1) // 3, seed + 5) < 2:                # slag
            c = SLAG[0] if grain(x, y, seed + 6) < 2 else (SLAG[1] if light < 0.3 else SLAG[2])
        if grain(x, y, seed + 7) < 2:
            c = KERA[3]
        return c
    f = Sprite()
    f.stamp(lump(15.5, 19, 9, 6.5, 301, shade, (16, 15, 16)))
    f.pts(SLAG[1], (5, 26), (25, 26))                      # slag shed at the foot
    f.pts(KERA[2], (7, 27), (24, 27), (22, 27))
    return f


# ------------------------------------------------------------- crucible --

def crucible(kind):
    """A small tapered clay crucible: 'raw' unfired grey clay, 'fired'
    and 'sealed' with a luted lid."""
    f = Sprite()
    pal = RAW if kind == 'raw' else CLAY
    for y in range(12, 27):
        t = (y - 12) / 14.0
        half = 5.4 + 0.9 * math.sin(t * math.pi * 0.9) - 2.6 * t * t
        xa, xb = int(round(15.5 - half)), int(round(15.5 + half))
        for x in range(xa, xb + 1):
            r = (x - xa) / float(xb - xa)
            i = 1 if r < 0.16 else (0 if r < 0.34 else (1 if r < 0.56 else (2 if r < 0.8 else 3)))
            g = grain(x, y, 311)
            if kind == 'raw':
                if (y + x // 4) % 4 == 0 and g > 2:
                    i += 1                                 # coil and finger marks
            elif g == 0:
                i += 1
            if kind != 'raw' and y > 22 and grain(x, y, 313) < 4:
                i = 4                                      # fire scale at the foot
            f.put(x, y, pal[min(4, i)])
    f.hline(12, 19, 26, pal[4])
    if kind == 'sealed':
        for y in range(8, 13):                             # domed lid
            for x in range(9, 23):
                nx, ny = (x - 15.5) / 6.4, (y - 12.5) / 4.2
                if nx * nx + ny * ny <= 1.0:
                    light = nx * 0.8 + ny * 0.3
                    f.put(x, y, CLAY[0] if light < -0.5 else (CLAY[1] if light < 0.1 else (CLAY[2] if light < 0.6 else CLAY[3])))
        f.rect(15, 6, 16, 7, CLAY[1])                      # knob
        f.put(15, 6, CLAY[0])
        f.put(16, 7, CLAY[3])
        for x in range(9, 23):                             # the luted joint
            g = grain(x, 1, 315)
            f.put(x, 13, LUTE[0] if x < 15 else LUTE[1])
            if 9 < x < 22:
                f.put(x, 14, LUTE[1] if g < 6 else LUTE[2])
            if g < 2 and 10 < x < 21:
                f.put(x, 15, LUTE[2])
                f.put(x, 16, LUTE[1] if g == 0 else LUTE[2])
            if g > 8:
                f.put(x, 12, LUTE[0])
    else:
        for y in range(10, 15):                            # the open mouth
            for x in range(9, 23):
                nx, ny = (x - 15.5) / 6.2, (y - 12.0) / 2.4
                d = nx * nx + ny * ny
                if d <= 1.0:
                    if d < 0.5:
                        c = SOOT if kind == 'fired' else pal[4]
                        if ny < -0.2 and d > 0.25:
                            c = pal[3]                     # far inner wall
                    else:
                        c = pal[0] if ny < 0.2 else pal[1]
                    f.put(x, y, c)
        f.pts(pal[1], (15, 9), (16, 9))                    # pouring lip
        f.put(15, 10, pal[0])
    f.outline(EDGE)
    return f


# ------------------------------------------------------ bars and sheets --

BAR = [(0.5, 4.5), (9.5, 0.5), (12.5, 2.5), (3.5, 6.5)]
BAR_PILES = {
    1: [(10, 14)],
    2: [(8, 13), (12, 16)],
    3: [(8, 14), (12, 17), (10, 11)],
    4: [(5, 13), (9, 16), (13, 19), (7, 10), (11, 13), (9, 7)],
}


def bar(ox, oy, pal, seed):
    """A cast bar lying up and to the right, three pixels deep."""
    g = Sprite()
    for y in range(0, 11):
        for x in range(0, 14):
            if inside(BAR, x + 0.01, y + 0.01):
                c = pal[1]
                if not inside(BAR, x + 0.01, y - 0.99):
                    c = pal[0]                             # lit far edge
                elif grain(x, y, seed) < 2:
                    c = pal[2]                             # dull cast skin
                elif (x + 2 * y) % 6 == 0:
                    c = pal[0]
            else:
                depth = [d for d in (1, 2, 3) if inside(BAR, x + 0.01, y - d + 0.01)]
                if not depth:
                    continue
                c = pal[2] if x < 4 else pal[3]            # end face, long face
                if depth[0] == 3:
                    c = pal[4]
            g.put(ox + x, oy + y, c)
    g.outline(EDGE)
    return g


def bars(size, pal=INCONEL):
    f = Sprite()
    for i, (ox, oy) in enumerate(BAR_PILES[size]):
        f.stamp(bar(ox, oy, pal, 321 + i * 3))
    return f


PLATE_TOP = [(1.5, 13.5), (14.5, 7.5), (29.5, 14.5), (16.5, 20.5)]
PLATE_DEEP = 2


def plain(x, y, pal):
    return pal[1]


def bright(x, y, pal):
    """A ground, polished face: long sheen streaks."""
    s = (x + 2 * y) % 11
    if s < 2:
        return pal[0]
    if s == 6:
        return pal[2]
    return pal[1]


def blistered(x, y, pal):
    """Blister steel: a scaly skin raised in round blisters."""
    bx, by = x // 3, (y + (x // 3) % 2) // 3
    g = grain(bx, by, 331)
    if g < 4:                                              # a blister
        lx, ly = x % 3, (y + (x // 3) % 2) % 3
        if (lx, ly) == (0, 0):
            return pal[0]
        if (lx, ly) in ((2, 2), (1, 2), (2, 1)):
            return pal[4]
        return pal[2]
    if g > 8:
        return RUST[2] if grain(x, y, 333) < 6 else RUST[1]
    return pal[1] if grain(x, y, 335) > 2 else pal[2]


def blued(x, y, pal):
    """Dark heat-blued steel with a cold sheen."""
    s = (x + 2 * y) % 13
    if s == 0:
        return pal[0]
    if s == 1:
        return blend(pal[0], pal[1], 0.5)
    return pal[1] if grain(x, y, 337) > 0 else pal[2]


def matte(x, y, pal):
    """Soft, unaged: an even dull face."""
    return pal[1] if (x + y) % 2 or grain(x, y, 339) > 3 else pal[2]


def sheets(pal, finish, count=3):
    """A squared stack of plates seen like the other metal sheets."""
    f = Sprite()
    for n in range(count):
        lift = (count - 1 - n) * PLATE_DEEP + 3
        top = [(px, py + lift) for px, py in PLATE_TOP]
        for y in range(SIZE):
            for x in range(SIZE):
                if inside(top, x + 0.01, y + 0.01):
                    c = finish(x, y - lift + n * 5, pal)
                    if not inside(top, x + 0.01, y - 0.99) and finish is not matte:
                        c = pal[0] if x < 15 else c
                    f.put(x, y, c)
                    continue
                depth = [d for d in range(1, PLATE_DEEP + 1) if inside(top, x + 0.01, y - d + 0.01)]
                if depth:
                    c = pal[2] if x < 17 else pal[3]
                    if depth[0] == PLATE_DEEP:
                        c = pal[3] if x < 17 else pal[4]
                    f.put(x, y, c)
    f.outline(EDGE)
    return f


# --------------------------------------------------------------- states --

STRUCTURES = (
    ('coke_bank', coke_bank), ('finery', finery), ('cementation', cementation), ('puddling', puddling),
    ('bessemer', bessemer), ('open_hearth', open_hearth), ('arc_furnace', arc_furnace),
    ('carburizing_pot', carburizing_pot),
)
ORES = (
    ('ore_coke', coke_shade, 341, PILES, 1.0),
    ('ore_nickel', nickel_shade, 351, PILES, 1.0),
    ('ore_cobalt', cobalt_shade, 361, PILES, 1.2),
    ('ore_chromite', chromite_shade, 371, GRAINS, 0.8),
)


def pile_name(name, size):
    return name if size == 1 else '%s_%d' % (name, size)


def states():
    """[(state, frames, delay)] in sheet order."""
    out = []
    for name, draw in STRUCTURES:
        out.append((name, [draw()], 0))
        out.append((name + '_on', [draw(i) for i in range(FIRE_FRAMES)], FIRE_DELAY))
    for name, shade, seed, layout, rough in ORES:
        for size in (1, 2, 3, 4):
            out.append((pile_name(name, size), [ore(shade, size, seed, layout, rough=rough)], 0))
    out += [
        ('steely_bloom', [steely_bloom()], 0),
        ('steel_crucible_unfired', [crucible('raw')], 0),
        ('steel_crucible', [crucible('fired')], 0),
        ('steel_crucible_sealed', [crucible('sealed')], 0),
    ]
    for size in (1, 2, 3, 4):
        out.append((pile_name('sheet-inconel', size), [bars(size)], 0))
    out += [
        ('sheet-blister', [sheets(BLISTER, blistered)], 0),
        ('sheet-fine', [sheets(FINE, bright)], 0),
        ('sheet-nickel', [sheets(NICKEL_STEEL, bright)], 0),
        ('sheet-maraging', [sheets(MARAGING, blued)], 0),
        ('sheet-maraging_soft', [sheets(SOFT, matte)], 0),
    ]
    return out


# --------------------------------------------------------- sheet in/out --

def build():
    blocks, frames = [], []
    for name, frs, delay in states():
        block = 'state = "%s"\n\tdirs = 1\n\tframes = %d\n' % (name, len(frs))
        if len(frs) > 1:
            block += '\tdelay = %s\n' % ','.join([str(delay)] * len(frs))
        blocks.append(block)
        frames += [fr.image() for fr in frs]
    cols = int(len(frames) ** 0.5 + 0.999)
    rows = (len(frames) + cols - 1) // cols
    im = Image.new('RGBA', (cols * SIZE, rows * SIZE))
    for i, fr in enumerate(frames):
        im.paste(fr, ((i % cols) * SIZE, (i // cols) * SIZE))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    text += ''.join(blocks) + '# END DMI\n'
    return im, text


def write_dmi():
    im, text = build()
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    im.save(SHEET, 'PNG', pnginfo=meta, optimize=True)


def check():
    if not SHEET.exists():
        return False
    im, text = build()
    old = Image.open(SHEET)
    return old.info.get('Description') == text and old.convert('RGBA').tobytes() == im.tobytes()


# -------------------------------------------------------------- review --

GRASS = [(98, 122, 78), (90, 114, 72), (108, 132, 84)]
DIRT = [(124, 98, 70), (114, 90, 64), (134, 108, 78)]


def ground(tones, scale):
    tile = Image.new('RGBA', (SIZE, SIZE), tones[0] + (255,))
    for y in range(SIZE):
        for x in range(SIZE):
            g = grain(x, y, 131)
            if g < 2:
                tile.putpixel((x, y), tones[1 + g] + (255,))
    return tile.resize((SIZE * scale, SIZE * scale), Image.NEAREST)


def preview(path, scale=4):
    """Every frame, labelled, on grass (upper block) and dirt (lower)."""
    cells = []
    for name, frs, _ in states():
        for i, fr in enumerate(frs):
            cells.append((name if len(frs) == 1 else '%s [%d]' % (name, i + 1), fr.image()))
    cols, pad, label = 10, 8, 14
    rows = (len(cells) + cols - 1) // cols
    cw, ch = SIZE * scale + pad, SIZE * scale + label + pad
    out = Image.new('RGBA', (pad + cols * cw, pad + 2 * rows * ch), (24, 24, 24, 255))
    pen = ImageDraw.Draw(out)
    for j, tones in enumerate((GRASS, DIRT)):
        back = ground(tones, scale)
        for i, (name, im) in enumerate(cells):
            x, y = pad + (i % cols) * cw, pad + (j * rows + i // cols) * ch
            tile = back.copy()
            tile.alpha_composite(im.resize((SIZE * scale, SIZE * scale), Image.NEAREST))
            out.paste(tile, (x, y))
            pen.text((x + 1, y + SIZE * scale + 1), name, fill=(230, 230, 230, 255))
    out.save(path)


if __name__ == '__main__':
    if '--check' in sys.argv:
        if not check():
            sys.exit('stale sheet: ' + str(SHEET))
        print('steelmaking states match')
    else:
        write_dmi()
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
