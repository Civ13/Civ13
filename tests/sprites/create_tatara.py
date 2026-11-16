"""Hand-placed sprites for tatara steelmaking in icons/obj/tatara.dmi: the
satetsu iron sand piles, the kera bloom lumps, the broken tamahagane chunks
(four pile sizes each), the clay box furnace (unlit, loaded, a four-frame
burning loop and the spent, cracked furnace) and the kanna-nagashi washing
channel (empty and a three-frame running loop). Every pixel is placed by this
script from a fixed palette (Pillow only); no external or generated artwork.
The fired clay is the bloomery's palette from icons/obj/metallurgy.dmi and
the timber and fire colours are those of create_clay_lime_fire.py.

Run with Pillow to write the sheet. `--check` verifies the committed sheet,
`--preview <png>` writes a labelled 4x review sheet on grass and on dirt,
`--gif <path>` writes the burning loop.
Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_clay_lime_fire import Frame, TIMBER, FIRE, grain  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/tatara.dmi'

SIZE = 32
FIRE_DELAY = 1         # deciseconds per frame, as bloomery_on
FIRE_FRAMES = 4
WATER_DELAY = 2
WATER_FRAMES = 3

# satetsu: lit, mid, shade, deep, blue-grey glitter, glint
SAND = [(58, 63, 78), (40, 44, 56), (28, 30, 40), (18, 19, 26), (112, 128, 156), (182, 198, 222)]
SAND_EDGE = (12, 13, 18)
# kera bloom: lit, mid, shade, pore
KERA = [(92, 92, 96), (66, 66, 70), (46, 46, 50), (26, 25, 28)]
RUST = [(150, 90, 48), (114, 62, 36), (84, 44, 28)]
SLAG = [(96, 124, 128), (52, 72, 80), (30, 42, 50)]          # glassy slag
SPARKLE = (214, 220, 228)
KERA_EDGE = (16, 15, 16)
# tamahagane: glint, bright, mid, shade fracture faces, then skin lit/mid/dark
STEEL = [(248, 250, 255), (214, 222, 234), (170, 180, 196), (124, 134, 152)]
SKIN = [(78, 80, 90), (54, 56, 64), (36, 37, 44)]
STEEL_EDGE = (22, 23, 30)
# fired clay (the bloomery's colours): highlight, light, mid, dark, deep
CLAY = [(192, 117, 73), (168, 99, 58), (143, 83, 48), (110, 61, 31), (83, 45, 21)]
# the same clay after the firing: scorched and grey
BURNT = [(126, 92, 74), (102, 74, 60), (80, 58, 48), (58, 42, 36), (42, 30, 28)]
HOLE = (40, 20, 9)
CHAR = [(74, 70, 68), (48, 44, 44), (30, 28, 30), (17, 16, 19)]
EMBER = [(206, 92, 34), (150, 52, 26), (104, 36, 24)]
# muddy wash water: foam, light, mid, deep
MUD = [(206, 188, 154), (170, 140, 98), (140, 110, 74), (108, 82, 56)]


class Sprite(Frame):
    """A Frame whose pixels may carry their own alpha (the sparks)."""

    def stamp(self, other):
        self.px.update(other.px)

    def image(self):
        im = Image.new('RGBA', (self.w, self.h))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c if len(c) == 4 else c + (255,))
        return im


# ------------------------------------------------------------ iron sand --

def sand_grain(x, y, seed):
    """Glitter and dark grains shared by every heap of iron sand."""
    g = grain(x, y, seed)
    if g == 0:
        return SAND[5] if grain(x // 2, y // 2, seed + 1) < 3 else SAND[4]
    if g == 1:
        return SAND[3]
    return None


def sand_mound(f, cx, base, rx, h, seed):
    """A smooth cone of fine sand, lit from the upper left."""
    for x in range(int(math.ceil(cx - rx)), int(cx + rx) + 1):
        nx = (x - cx) / rx
        top = int(round(base - h * (1.0 - abs(nx)) ** 0.85))
        foot = base + int(round(1.6 * math.sqrt(max(0.0, 1.0 - nx * nx))))
        for y in range(top, foot + 1):
            light = nx * 0.9 + (y - top) / float(h) * 0.5
            c = SAND[0] if light < -0.2 else (SAND[1] if light < 0.4 else SAND[2])
            if y == top and nx < 0.3:
                c = SAND[0]
            c = sand_grain(x, y, seed) or c
            f.put(x, y, c)


def iron_sand(size):
    f = Sprite()
    mounds = {
        1: [(15.5, 23, 6, 5)],
        2: [(15.5, 24, 9, 8)],
        3: [(8.5, 25, 6, 5), (18, 25, 10, 11)],
        4: [(6.5, 27, 5, 5), (25, 27, 5, 4), (15.5, 26, 13, 15)],
    }[size]
    for i, m in enumerate(mounds):
        sand_mound(f, *m, seed=61 + i)
    f.outline(SAND_EDGE)
    # loose grains spilt round the foot
    cx, base, rx, _ = mounds[-1]
    for i in range(3 + size * 2):
        x = int(cx - rx - 2 + grain(i, size, 63) * (2 * rx + 4) / 10.0)
        y = base + 2 + grain(i, size, 65) % 3
        if (x, y) not in f.px:
            f.put(x, y, SAND[4] if i % 4 == 0 else SAND[2])
    return f


# ----------------------------------------------------------------- kera --

def kera_lump(cx, cy, rx, ry, seed):
    """One rough, spongy lump of bloom."""
    g = Sprite()
    for y in range(int(cy - ry) - 2, int(cy + ry) + 3):
        for x in range(int(cx - rx) - 2, int(cx + rx) + 3):
            nx, ny = (x - cx) / rx, (y - cy) / ry
            a = math.atan2(ny, nx)
            edge = 1.0 + 0.16 * math.sin(3 * a + seed) + 0.10 * math.sin(5 * a + 2 * seed)
            if math.hypot(nx, ny) > edge:
                continue
            light = nx * 0.6 + ny * 0.75
            c = KERA[0] if light < -0.45 else (KERA[1] if light < 0.25 else KERA[2])
            if grain(x // 3, y // 2, seed + 1) < 3:           # rusty patch
                c = RUST[0] if light < -0.3 else (RUST[1] if light < 0.4 else RUST[2])
            elif grain(x // 3, (y + 1) // 3, seed + 2) < 2:   # glassy slag
                c = SLAG[1] if light < 0.3 else SLAG[2]
                if grain(x, y, seed + 3) < 2:
                    c = SLAG[0]
            p = grain(x, y, seed + 4)
            if p < 2:
                c = KERA[3]                                   # pores
            elif p == 2 and grain(x // 2, y // 2, seed + 5) < 4:
                c = SPARKLE                                   # bare metal
            g.put(x, y, c)
    g.outline(KERA_EDGE)
    return g


def kera(size):
    f = Sprite()
    lumps = {
        1: [(15.5, 20, 5.5, 4)],
        2: [(10.5, 21, 5, 4), (20.5, 20, 5.5, 4.5)],
        3: [(9.5, 22, 5, 4), (21.5, 22, 5.5, 4), (15.5, 16, 6, 4.5)],
        4: [(8.5, 22.5, 5.5, 4.5), (22.5, 22.5, 6, 4.5), (15.5, 24, 5, 4),
            (11.5, 16, 5.5, 4.5), (20, 15.5, 5.5, 4.5), (15.5, 10, 5.5, 4.5)],
    }[size]
    for i, lump in enumerate(lumps):
        f.stamp(kera_lump(*lump, seed=71 + i * 7))
    return f


# ----------------------------------------------------------- tamahagane --

SHARDS = [
    [(0, 3), (3, 0), (8, 1), (10, 4), (7, 8), (2, 7)],
    [(0, 2), (4, 0), (8, 2), (7, 7), (1, 6)],
    [(1, 0), (6, 0), (10, 3), (6, 7), (0, 5)],
    [(0, 1), (5, 0), (7, 4), (4, 8), (0, 6)],
]


def inside(poly, x, y):
    hit = False
    for i in range(len(poly)):
        (x0, y0), (x1, y1) = poly[i], poly[(i + 1) % len(poly)]
        if (y0 > y) != (y1 > y) and x < x0 + (y - y0) * (x1 - x0) / float(y1 - y0):
            hit = not hit
    return hit


def shard(kind, ox, oy, seed):
    """An angular chunk: the bright crystalline fracture on top and the
    dark outer skin showing as the thickness below and to the right."""
    g = Sprite()
    poly = [(px + 0.5, py + 0.5) for px, py in SHARDS[kind]]
    for y in range(-1, 11):
        for x in range(-1, 12):
            if not inside(poly, x + 0.01, y + 0.01):
                continue
            if inside(poly, x + 1.51, y + 2.51):
                facet = grain((x + y // 2) // 2, (y + seed) // 2, seed)
                c = STEEL[1] if facet < 4 else (STEEL[2] if facet < 9 else STEEL[3])
                if grain(x, y, seed + 1) == 0:
                    c = STEEL[0]
                elif grain(x, y, seed + 1) == 1:
                    c = STEEL[3]
            else:
                c = SKIN[1] if grain(x, y, seed + 2) > 2 else SKIN[0]
                if not inside(poly, x + 0.01, y + 1.01):
                    c = SKIN[2]
            g.put(ox + x, oy + y, c)
    g.outline(STEEL_EDGE)
    return g


def tamahagane(size):
    f = Sprite()
    lay = {
        1: [(0, 11, 16)],
        2: [(0, 5, 16), (1, 17, 18)],
        3: [(0, 4, 18), (2, 17, 19), (1, 11, 12)],
        4: [(0, 2, 19), (2, 19, 20), (3, 12, 20), (1, 6, 13), (0, 15, 12), (1, 11, 6)],
    }[size]
    for i, (kind, ox, oy) in enumerate(lay):
        f.stamp(shard(kind, ox, oy, seed=81 + i * 5))
    return f


# --------------------------------------------------------------- tatara --

TUYERES = (5, 9, 13, 17, 21, 25)      # left pixel of each blast hole
SLUMP = [1, 1, 1, 1, 2, 2, 2, 3, 3, 3, 3, 3, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0]


def furnace(f, clay=CLAY, sag=None, lit=None):
    """The clay box: a long open trough seen from the front and above, its
    long front wall pierced by a row of blast holes with the slag tap at
    the foot. sag lowers the rim per column; lit is the burning step."""
    for x in range(2, 30):
        s = sag[x] if sag else 0
        top = 6 + s
        if x in (2, 29):                      # the walls flare at the foot
            for y in range(19, 28):
                f.put(x, y, clay[3] if x == 29 else clay[2])
            continue
        for y in range(top, 28):
            r = y - top
            if r < 2:                         # far rim
                c = clay[0] if r == 0 else clay[1]
            elif r < 7:
                if 5 <= x <= 26:              # the open top
                    c = clay[4] if r < 4 else HOLE
                    if r < 3:
                        c = clay[3]           # far inner wall, in shade
                    if r == 3 and grain(x, y, 91) < 2:
                        c = clay[3]
                    if x == 5:
                        c = clay[3]
                else:                         # end walls
                    c = clay[1] if x < 16 else clay[2]
            elif r < 9:                       # near rim
                c = clay[0] if r == 7 else clay[1]
            else:                             # the front wall
                c = clay[2] if y < 25 else clay[3]
                if r == 9:
                    c = clay[3]               # shade under the lip
                g = grain(x, y, 93)
                if g == 0:
                    c = clay[max(0, clay.index(c) - 1)]
                elif g == 1:
                    c = clay[min(4, clay.index(c) + 1)]
                if y in (18, 23) and grain(x // 3, y, 95) < 5:
                    c = clay[3]               # seams between the clay courses
                if x >= 28:
                    c = clay[min(4, clay.index(c) + 1)]
            f.put(x, y, c)
    for tx in TUYERES:                        # blast holes with a lit lip
        f.hline(tx, tx + 1, 19, clay[0])
        f.rect(tx, 20, tx + 1, 21, HOLE)
        f.hline(tx, tx + 1, 22, clay[3])
    f.pts(clay[3], (14, 24), (17, 24))        # the slag tap
    f.hline(15, 16, 24, clay[4])
    f.rect(14, 25, 17, 27, HOLE)
    if lit is not None:
        pulse = (0, 1, 2, 1)[lit % FIRE_FRAMES]
        for i, tx in enumerate(TUYERES):
            hot = (pulse + i) % 3
            f.pts(FIRE[(1, 0, 1)[hot]], (tx, 20), (tx + 1, 21))
            f.pts(FIRE[(2, 1, 2)[hot]], (tx + 1, 20), (tx, 21))
            f.hline(tx, tx + 1, 22, FIRE[3])
        f.rect(14, 25, 17, 27, FIRE[2])
        f.pts(FIRE[(1, 0, 1)[pulse]], (15, 26), (16, 26), (15, 27), (16, 27))
        f.pts(FIRE[3], (14, 25), (17, 25))
        for x in range(5, 27):                # the charge glowing in the top
            for y in range(8, 13):
                f.put(x, y, FIRE[2] if grain(x, y + lit, 97) < 5 else FIRE[1])
        f.hline(5, 26, 13, (232, 150, 86))    # near rim lit from within
    f.outline(HOLE)
    if lit is not None:                       # slag running from the tap
        puddle = ((13, 28), (14, 28), (15, 28), (16, 28), (17, 28), (18, 28),
                  (14, 29), (15, 29), (16, 29), (17, 29), (18 + pulse % 2, 29))
        for i, (x, y) in enumerate(puddle):
            f.put(x, y, FIRE[2] if (i + lit) % 3 else FIRE[1])
        f.pts(FIRE[3], (12, 28), (19, 28), (13, 29))


def tatara():
    f = Sprite()
    furnace(f)
    return f


def tatara_loaded():
    """Charcoal heaped over the top with black iron sand strewn on it."""
    f = Sprite()
    furnace(f)
    for x in range(5, 27):
        nx = (x - 15.5) / 11.5
        top = 9 - int(round(5 * (1.0 - nx * nx) ** 0.8)) + (1 if grain(x // 2, 0, 99) < 3 else 0)
        for y in range(top, 13):
            lump = grain(x // 2, (y + x // 4) // 2, 101)
            c = CHAR[1] if lump < 4 else (CHAR[2] if lump < 9 else CHAR[3])
            if grain(x, y, 103) == 0 or y == top:
                c = CHAR[0]
            if grain(x // 4, y // 2, 105) < 4 and y < 11:     # iron sand
                c = sand_grain(x, y, 107) or (SAND[1] if x < 16 else SAND[2])
            f.put(x, y, c)
        f.put(x, top - 1, HOLE)
    f.pts(HOLE, (4, 9), (27, 9), (4, 10), (27, 10))
    return f


def tatara_on(step):
    """Flames and sparks from the open top, glowing blast holes and slag."""
    f = Sprite()
    k = step % FIRE_FRAMES
    furnace(f, lit=k)
    for x in range(5, 27):
        nx = (x - 15.5) / 11.5
        h = (1.0 - nx * nx) ** 0.6 * (6.5 + 3.0 * math.sin(x * 0.9 + k * math.pi / 2.0)
                                      + 2.0 * math.sin(x * 1.7 - k * math.pi + 1.0))
        h = max(2.0, h)
        for y in range(12, 12 - int(round(h)) - 1, -1):
            t = (12 - y) / h
            c = FIRE[0] if t < 0.3 else (FIRE[1] if t < 0.58 else (FIRE[2] if t < 0.84 else FIRE[3]))
            f.put(x, y, c)
    # sparks: each climbs two pixels a frame and fades, repeating every four
    for i, (sx, sy) in enumerate(((7, 6), (12, 4), (19, 5), (24, 7), (16, 3), (10, 8), (22, 4))):
        phase = (k + i) % FIRE_FRAMES
        x = sx + (1 if (phase + i) % 2 else 0) * (1 if i % 2 else -1)
        y = sy - 2 * phase
        tone = (FIRE[0], FIRE[1], FIRE[1], FIRE[2])[phase]
        f.put(x, y, tone + ((255, 235, 190, 130)[phase],))
    return f


def tatara_spent():
    """After the firing: scorched, cracked and slumping, embers in the cracks."""
    f = Sprite()
    furnace(f, clay=BURNT, sag=SLUMP)
    for x in range(6, 26):                    # ash and dying embers inside
        y = 10 + SLUMP[x]
        if grain(x, 3, 109) < 3:
            f.put(x, y, EMBER[2])
        elif grain(x, 3, 109) < 5:
            f.put(x, y + 1, CHAR[0])
    cracks = (
        [(7, 15), (7, 16), (8, 17), (8, 18), (7, 19), (8, 20), (8, 21), (9, 22), (9, 23), (10, 24), (10, 25), (10, 26)],
        [(19, 13), (19, 14), (19, 15), (20, 16), (19, 17), (19, 18), (18, 19), (19, 20), (20, 21), (20, 22),
         (20, 23), (21, 24), (22, 25), (22, 26), (22, 27)],
        [(13, 17), (12, 18), (12, 19), (11, 20)],
        [(25, 16), (26, 17), (26, 18), (25, 19), (25, 20), (26, 21), (26, 22)],
        [(15, 20), (16, 21), (16, 22), (15, 23)],
    )
    for n, crack in enumerate(cracks):
        for i, (x, y) in enumerate(crack):
            glow = grain(i, n, 111)
            f.put(x, y, EMBER[2] if glow < 3 else (EMBER[1] if glow == 3 else HOLE))
    f.rect(14, 25, 17, 27, HOLE)
    f.pts(EMBER[2], (15, 27), (16, 26))
    # clay shed from the walls
    f.pts(BURNT[2], (5, 29), (6, 29), (24, 29), (12, 29))
    f.pts(BURNT[4], (6, 30), (25, 29), (13, 29))
    return f


# -------------------------------------------------------- kanna channel --

RIFFLES = (10, 21)       # top row of each cross bar


def kanna_channel(step=None):
    """A plank sluice running down the tile; with a step, muddy water runs
    and iron sand lies behind the riffles."""
    f = Sprite()
    for ty in (4, 26):                        # sleepers under the trough
        f.hline(7, 24, ty, TIMBER[2])
        f.hline(7, 24, ty + 1, TIMBER[4])
        f.pts(TIMBER[1], (7, ty), (8, ty))
    for y in range(SIZE):
        for x in range(11, 21):               # floor boards
            c = TIMBER[3]
            if x in (14, 17):
                c = TIMBER[4]
            elif grain(x, y // 4, 121) < 2:
                c = TIMBER[2]
            if x == 11:
                c = TIMBER[4]                 # shade under the left board
            if step is not None:
                run = (y - 2 * step + grain(x, 0, 129)) % 6      # streaks run down
                c = MUD[2]
                if run < 2 and x % 2 == 0:
                    c = MUD[1]
                elif run == 3 and x % 3 == 0:
                    c = MUD[3]
                if x == 11:
                    c = MUD[3]
            f.put(x, y, c)
        for x, tone in ((9, 0), (10, 1), (21, 1), (22, 2)):      # side boards
            c = TIMBER[tone]
            if grain(x, y // 5, 123) < 2:
                c = TIMBER[tone + 1]
            f.put(x, y, c)
    for ry in RIFFLES:
        f.hline(11, 20, ry, TIMBER[0])
        f.hline(11, 20, ry + 1, TIMBER[2])
        f.hline(11, 20, ry + 2, TIMBER[4] if step is None else MUD[3])
        if step is None:
            continue
        for x in range(11, 21):               # sand settled above the bar
            for d, cut in ((1, 11), (2, 8), (3, 4), (4, 1)):
                if grain(x, d, 125 + ry) < cut:
                    f.put(x, ry - d, sand_grain(x, ry - d, 127) or (SAND[1] if d > 1 else SAND[2]))
            if (x + step) % 3 == 0:           # water breaking over the bar
                f.put(x, ry, MUD[0])
            if (x + step) % 3 != 1:
                f.put(x, ry + 1, MUD[0] if (x + step) % 2 else MUD[1])
            if (x * 2 + step) % 3 == 0:
                f.put(x, ry + 2, MUD[1])
    for ty in (4, 26):                        # pegs through the side boards
        f.pts(TIMBER[4], (9, ty), (22, ty))
    f.outline()
    return f


def states():
    """[(state, frames, delay)] in sheet order."""
    out = []
    for name, draw in (('iron_sand', iron_sand), ('kera', kera), ('tamahagane', tamahagane)):
        for size in (1, 2, 3, 4):
            out.append((name if size == 1 else '%s_%d' % (name, size), [draw(size)], 0))
    out += [
        ('tatara', [tatara()], 0),
        ('tatara_loaded', [tatara_loaded()], 0),
        ('tatara_on', [tatara_on(i) for i in range(FIRE_FRAMES)], FIRE_DELAY),
        ('tatara_spent', [tatara_spent()], 0),
        ('kanna_channel', [kanna_channel()], 0),
        ('kanna_channel_working', [kanna_channel(i) for i in range(WATER_FRAMES)], WATER_DELAY),
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
    cols, pad, label = 6, 8, 14
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


def gif(path, scale=6):
    """The burning loop on grass at game speed."""
    back = ground(GRASS, scale)
    shots = []
    for fr in dict((n, f) for n, f, _ in states())['tatara_on']:
        tile = back.copy()
        tile.alpha_composite(fr.image().resize((SIZE * scale, SIZE * scale), Image.NEAREST))
        shots.append(tile.convert('RGB'))
    shots[0].save(path, save_all=True, append_images=shots[1:], duration=FIRE_DELAY * 100, loop=0)


if __name__ == '__main__':
    if '--check' in sys.argv:
        if not check():
            sys.exit('stale sheet: ' + str(SHEET))
        print('tatara states match')
    else:
        write_dmi()
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
    if '--gif' in sys.argv:
        gif(sys.argv[sys.argv.index('--gif') + 1])
