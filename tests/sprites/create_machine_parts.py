"""Hand-placed 32px art for the standard machine parts: the gear set, shaft,
bearing, spring, drive belt, drive chain and wheel, the visibly different wooden
gear set, shaft and bearing block, and the parts mould (raw, fired and
poured). Every pixel is placed by this script from a fixed palette (Pillow
only); no external or generated artwork.

The parts are drawn in a pale grey ramp because the game tints each one with
its material's colour, the way a knife or an ingot is tinted; the outline is
dark enough to stay an outline under any tint. The mould uses the clay and
molten-metal colours of the moulds in icons/obj/metallurgy.dmi and is not
tinted. Lit from the upper left.

    python3 tests/sprites/create_machine_parts.py [--preview sheet.png] [--check]

Run with Pillow to reproduce icons/obj/machine_parts.dmi. `--preview <png>`
also writes a review sheet (each part at 4x, untinted and in the colours of
the materials it is made of, with the 1x sprite on two floors beside it).
`--check` writes nothing and fails when the committed sheet differs from what
this script draws.
Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
DMI = ROOT / 'icons/obj/machine_parts.dmi'
COLUMNS = 6

# tintable ramp: glint, lit, face, shade, deep shade
G = [(255, 255, 255), (236, 236, 236), (206, 206, 206), (166, 166, 166), (124, 124, 124)]
OUT = (52, 52, 56)
HOLE = (34, 34, 38)
# unfired clay, as "pickaxe_mold_raw": face, rim, recess, recess lip, edge
RAW = {'f': (178, 178, 178), 'r': (150, 150, 150), 'c': (119, 119, 119), 'l': (128, 128, 128),
       'e': (77, 77, 77), 'd': (95, 95, 95)}
# fired clay, as "pickaxe_mold_empty"
FIRED = {'f': (110, 63, 43), 'r': (102, 58, 40), 'c': (87, 48, 32), 'l': (93, 52, 35),
         'e': (73, 40, 26), 'd': (78, 43, 28)}
# molten metal, as "pickaxe_mold_full"
MELT = ((254, 97, 0), (252, 253, 107))
# preview
DARK = (30, 32, 36)
FLOORS = ((120, 124, 112), (112, 92, 70))
TINTS = {'wood': (0x82, 0x4B, 0x28), 'bone': (0xCC, 0xD1, 0xC4), 'copper': (0xB8, 0x73, 0x33),
         'bronze': (0x7C, 0x46, 0x11), 'brass': (0xC9, 0xA4, 0x3F), 'iron': (0x5C, 0x54, 0x54),
         'steel': (0x66, 0x66, 0x66), 'leather': (0x5C, 0x48, 0x31), 'rope': (0xFF, 0xFF, 0xFF)}
SHOWN_IN = {
    'gear': ('bronze', 'brass', 'iron', 'steel', 'bone'), 'gear_wood': ('wood',),
    'shaft': ('bronze', 'iron', 'steel'), 'shaft_wood': ('wood',),
    'bearing': ('bronze', 'brass', 'iron', 'copper'), 'bearing_wood': ('wood',),
    'spring': ('bronze', 'iron', 'steel'), 'belt': ('leather', 'rope'),
    'chain': ('iron', 'steel', 'bronze'),
    'wheel': ('iron', 'steel', 'bronze'), 'wheel_wood': ('wood',), 'wheel_shod': (),
}


class Frame:
    def __init__(self):
        self.px = {}

    def put(self, x, y, c, a=255):
        if 0 <= x < 32 and 0 <= y < 32:
            self.px[(x, y)] = (c[0], c[1], c[2], a)

    def pts(self, c, *points):
        for x, y in points:
            self.put(x, y, c)

    def tint(self, c, *points):
        """Like pts, but only over pixels that are already drawn."""
        for p in points:
            if p in self.px:
                self.put(p[0], p[1], c)

    def outline(self, c=OUT):
        """Ring every drawn shape with the dark outline colour."""
        edge = set()
        for (x, y) in self.px:
            for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if n not in self.px:
                    edge.add(n)
        for x, y in edge:
            self.put(x, y, c)
        return self

    def image(self):
        im = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c)
        return im


def stamp(f, rows, pal, left=0, top=0):
    """Place a hand-drawn bitmap: one character per pixel, '.' is empty."""
    width = len(rows[0])
    for j, row in enumerate(rows):
        assert len(row) == width, (rows[0], row)
        for i, ch in enumerate(row):
            if ch != '.':
                f.put(left + i, top + j, pal[ch])


def lit(dx, dy, r):
    """Ramp index for a point on a flat disc lit from the upper left."""
    k = (-dx - dy) / (1.4142 * max(r, 1))
    return 1 if k > 0.45 else 2 if k > -0.2 else 3 if k > -0.7 else 4


# ---------------------------------------------------------------- gear set

def cog(f, cx, cy, root, tip, teeth, hub, phase=0.0, spokes=0):
    """A spur gear seen face on: root circle, square-cut teeth, hub and bore."""
    for y in range(32):
        for x in range(32):
            dx, dy = x - cx, y - cy
            r = math.hypot(dx, dy)
            if r > tip + 0.3:
                continue
            a = (math.atan2(dy, dx) + phase) % (2 * math.pi)
            in_tooth = (a * teeth / (2 * math.pi)) % 1.0 < 0.5
            if r > root + 0.3 and not in_tooth:
                continue
            f.put(x, y, G[lit(dx, dy, tip)])
    for y in range(32):
        for x in range(32):
            dx, dy = x - cx, y - cy
            r = math.hypot(dx, dy)
            if (x, y) not in f.px or r > root:
                continue
            if spokes and hub + 0.6 < r < root - 1.6:
                a = math.atan2(dy, dx) % (2 * math.pi)
                if abs(((a * spokes / (2 * math.pi)) % 1.0) - 0.5) < 0.28:
                    f.put(x, y, HOLE)          # lightening window between spokes
                    continue
            if r <= hub + 0.3:
                f.put(x, y, G[1] if dx + dy < 0 else G[3])   # raised hub
            if r <= 1.1:
                f.put(x, y, HOLE)              # bore
    # a rim line just inside the teeth
    for y in range(32):
        for x in range(32):
            dx, dy = x - cx, y - cy
            if (x, y) in f.px and abs(math.hypot(dx, dy) - (root - 0.6)) < 0.5 and f.px[(x, y)][:3] != HOLE:
                f.put(x, y, G[3] if dx + dy < 0 else G[1])


def gear():
    f = Frame()
    cog(f, 12.5, 18.5, 7.2, 9.6, 10, 2.4, spokes=5)
    small = Frame()
    cog(small, 24.5, 8.5, 3.4, 5.4, 6, 1.6, phase=0.5)
    f.outline()
    small.outline()
    f.px.update(small.px)
    return f


def peg_wheel(f, cx, cy, radius, pegs, phase=0.0):
    """A wooden face wheel: a plank disc with round pegs for teeth."""
    for y in range(32):
        for x in range(32):
            dx, dy = x - cx, y - cy
            r = math.hypot(dx, dy)
            if r <= radius + 0.3:
                shade = 2 if dx + dy < 2 else 3
                if int(y) % 3 == 0 and r < radius - 0.5:
                    shade += 1                 # grain between the planks
                f.put(x, y, G[shade])
    for k in range(pegs):
        a = phase + k * 2 * math.pi / pegs
        px, py = cx + math.cos(a) * (radius + 1.4), cy + math.sin(a) * (radius + 1.4)
        x0, y0 = int(round(px - 0.5)), int(round(py - 0.5))
        f.pts(G[1], (x0, y0), (x0 + 1, y0))
        f.pts(G[3], (x0, y0 + 1), (x0 + 1, y0 + 1))
    # square eye for a square shaft, and the two clamps that hold the planks
    x0, y0 = int(cx - 1), int(cy - 1)
    for y in range(y0, y0 + 3):
        for x in range(x0, x0 + 3):
            f.put(x, y, HOLE)
    if radius > 5:
        for d in (-4, 4):
            for y in range(int(cy - radius + 2), int(cy + radius - 1)):
                if (x0 + 1 + d, y) in f.px:
                    f.put(x0 + 1 + d, y, G[1] if d < 0 else G[4])


def gear_wood():
    f = Frame()
    peg_wheel(f, 12.5, 18.5, 7.6, 10)
    small = Frame()
    peg_wheel(small, 24.5, 8.5, 3.6, 6, phase=0.4)
    f.outline()
    small.outline()
    f.px.update(small.px)
    return f


# ------------------------------------------------------------------- wheel

def spoked(f, cx, cy, outer, rim, hub, spokes, width, ramp=None, phase=0.0):
    """A wheel seen face on: rim, hub with a bore, and straight spokes."""
    ramp = ramp or G
    for y in range(32):
        for x in range(32):
            dx, dy = x - cx, y - cy
            r = math.hypot(dx, dy)
            if r > outer + 0.3:
                continue
            if r >= outer - rim:
                f.put(x, y, ramp[lit(dx, dy, outer)])
            elif r <= hub + 0.3:
                f.put(x, y, ramp[1] if dx + dy < 0 else ramp[3])
            else:
                a = (math.atan2(dy, dx) + phase) % (2 * math.pi)
                k = (a * spokes / (2 * math.pi)) % 1.0
                # distance from the spoke's centre line, in pixels
                off = abs(math.sin((min(k, 1 - k)) * 2 * math.pi / spokes)) * r
                if off <= width:
                    f.put(x, y, ramp[2] if dx + dy < 0 else ramp[3])
    for y in range(32):
        for x in range(32):
            if math.hypot(x - cx, y - cy) <= 1.1:
                f.put(x, y, HOLE)


def wheel():
    f = Frame()
    spoked(f, 15.5, 15.5, 13.2, 2.0, 2.6, 8, 0.55)
    return f.outline()


def wheel_wood():
    f = Frame()
    spoked(f, 15.5, 15.5, 13.2, 3.4, 3.4, 6, 1.0, phase=0.3)
    # joints between the six felloes of the rim
    for k in range(6):
        a = k * math.pi / 3
        for r in (10.6, 11.6, 12.6):
            x, y = int(round(15.5 + math.cos(a) * r - 0.5)), int(round(15.5 + math.sin(a) * r - 0.5))
            f.tint(G[4], (x, y))
    return f.outline()


# an iron-shod wooden wheel is drawn in its own colours and is not tinted
WOOD_RAMP = [(196, 140, 92), (170, 112, 66), (146, 90, 50), (116, 68, 36), (88, 50, 26)]
IRON_RAMP = [(214, 214, 220), (176, 176, 184), (140, 140, 150), (104, 104, 114), (76, 76, 86)]


def wheel_shod():
    f = Frame()
    spoked(f, 15.5, 15.5, 12.0, 3.0, 3.4, 6, 1.0, ramp=WOOD_RAMP, phase=0.3)
    for y in range(32):
        for x in range(32):
            dx, dy = x - 15.5, y - 15.5
            r = math.hypot(dx, dy)
            if 12.0 < r <= 13.5:
                f.put(x, y, IRON_RAMP[lit(dx, dy, 13.5)])     # the iron tyre
            elif r <= 2.0 and r > 1.1:
                f.put(x, y, IRON_RAMP[2])                     # hub band
    return f.outline()


# ------------------------------------------------------------------- shaft

# 1 lit, 2 face, 3 shade, 4 deep shade, 0 glint, k keyway
SHAFT = (
    '........................2221',
    '.......................22113',
    '......................111133',
    '.....................1112334',
    '....................01k2334.',
    '...................01k2334..',
    '..................0122334...',
    '.................0122334....',
    '................0122334.....',
    '...............0122334......',
    '..............0122334.......',
    '.............0122334........',
    '............0122334.........',
    '...........0122334..........',
    '..........0122334...........',
    '.........0122334............',
    '........0122334.............',
    '.......0122334..............',
    '......0122334...............',
    '.....01k2334................',
    '....01k2334.................',
    '...1112334..................',
    '..111133....................',
    '.22113......................',
    '2221........................',
)
SHAFT_WOOD = (
    '.......................22221.',
    '......................2211123',
    '.....................22122233',
    '....................121222334',
    '...................1212g2334.',
    '..................1122g2334..',
    '.................1122g2334...',
    '................112222334....',
    '...............1122g2334.....',
    '..............1122g2334......',
    '.............1122g2334.......',
    '............112222334........',
    '...........1122g2334.........',
    '..........1122g2334..........',
    '.........1122g2334...........',
    '........112222334............',
    '.......1122g2334.............',
    '......1122g2334..............',
    '.....1122g2334...............',
    '....112222334................',
    '...1222g2334.................',
    '..22122g334..................',
    '.2211223344..................',
    '22111233.....................',
    '.22223.......................',
)
SHAFT_PAL = {'0': G[0], '1': G[1], '2': G[2], '3': G[3], '4': G[4], 'k': HOLE, 'g': G[4]}


def shaft():
    f = Frame()
    stamp(f, SHAFT, SHAFT_PAL, 2, 4)
    return f.outline()


def shaft_wood():
    f = Frame()
    stamp(f, SHAFT_WOOD, SHAFT_PAL, 1, 4)
    return f.outline()


# ----------------------------------------------------------------- bearing

# A flanged bushing seen from the front and a little above.
BUSHING = (
    '......11111111......',
    '....111222222221....',
    '...11222222222223...',
    '..1122223333222233..',
    '.112223hhhhhh322233.',
    '.12223hhhhhhhh32233.',
    '.1223hhhhhhhhhh2334.',
    '.1223hhhhhhhhhh2334.',
    '.12223hhhhhhhh22334.',
    '.122223hhhhhh223334.',
    '..1222221111222334..',
    '...22222222223334...',
    '..3.333333333344.4..',
    '..32.3444444443.24..',
    '..3222........2224..',
    '...32222222222224...',
    '....333222222344....',
    '......34444444......',
)
# A split pillow block: two halves of a log clamped round a greased bore.
BLOCK = (
    '....1111111111111111....',
    '...122222222222222223...',
    '..12222222222222222223..',
    '..122g2222333322222g23..',
    '..12222223hhhh32222223..',
    '..1222223hhhhhh3222223..',
    '..122g223hhhhhh322g223..',
    '..4444443hhhhhh3444444..',
    '..1222223hhhhhh3222223..',
    '..122g2223hhhh3222g223..',
    '..12222222333322222223..',
    '..12222222222222222223..',
    '.1122g22222222222g22233.',
    '122222222222222222222223',
    '122222222222222222222234',
    '.3333333333333333333344.',
)
BEAR_PAL = {'1': G[1], '2': G[2], '3': G[3], '4': G[4], 'h': HOLE, 'g': G[4]}


def bearing():
    f = Frame()
    stamp(f, BUSHING, BEAR_PAL, 6, 7)
    return f.outline()


def bearing_wood():
    f = Frame()
    stamp(f, BLOCK, BEAR_PAL, 4, 8)
    f.outline()
    # grease weeping from the bore; kept dark so it reads under the wood tint
    f.pts(HOLE, (15, 20), (16, 21))
    return f


# ------------------------------------------------------------------ spring

def spring():
    """A coil spring lying on its side, drawn as the zigzag a helix shows from
    the side: the near half of each turn thick and lit, the far half thin and
    in shade."""
    f = Frame()
    turns, x0, pitch, top, bottom = 4, 3, 6, 10, 21
    height = bottom - top
    far = Frame()
    for t in range(turns):
        for i in range(height + 1):
            # far half: from the foot of this turn back up to the crown of the next
            far.put(x0 + t * pitch + 4 + ((height - i) * 2 + height // 2) // height, top + i, G[4])
    for t in range(turns + 1):
        for i in range(height + 1):
            # near half: from the crown down and forward to the foot
            x = x0 + t * pitch + (i * 3 + height // 2) // height
            f.put(x, top + i, G[0] if i in (1, 2) else G[1] if i < 6 else G[2] if i < 9 else G[3])
            f.put(x + 1, top + i, G[2] if i < 6 else G[3])
    far.px = {p: c for p, c in far.px.items() if p[0] <= x0 + turns * pitch + 4}
    far.px.update(f.px)
    return far.outline()


# ------------------------------------------------------------ belt, chain

def loop_points(cx, cy, a, b, steps=400):
    seen = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        p = (int(round(cx + a * math.cos(t))), int(round(cy + b * math.sin(t))))
        if not seen or seen[-1] != p:
            seen.append(p)
    if seen[0] == seen[-1]:
        seen.pop()
    return seen


def belt():
    """A flat belt coiled as a loop, the laced join at the front."""
    f = Frame()
    cx, cy = 15.5, 16.5
    for y in range(32):
        for x in range(32):
            dx, dy = (x - cx) / 12.5, (y - cy) / 7.5
            outer = dx * dx + dy * dy
            ix, iy = (x - cx) / 9.5, (y - cy + 1) / 4.2
            inner = ix * ix + iy * iy
            if outer <= 1.0 and inner > 1.0:
                # the top of the loop shows the inside face, in shade
                if y < cy - 1 and inner < 1.9:
                    f.put(x, y, G[4])
                else:
                    f.put(x, y, G[1] if y < cy + 2 and x < cx else G[2] if y < cy + 4 else G[3])
    f.outline()
    # lacing across the join
    for x, y in ((13, 22), (15, 22), (17, 22)):
        f.pts(HOLE, (x, y))
        f.pts(G[0], (x, y - 1))
    # a row of stitch marks round the outer face
    for i, (x, y) in enumerate(loop_points(cx, cy + 0.6, 11.2, 6.2)):
        if i % 4 == 0 and y > cy and (x, y) in f.px and f.px[(x, y)][:3] != OUT and not 11 < x < 19:
            f.put(x, y, G[4])
    return f


def chain():
    """A loop of chain: flat links seen face on alternating with links on edge."""
    f = Frame()
    cx, cy = 15.5, 16.5
    path = loop_points(cx, cy, 11.5, 7.0)
    for i, (x, y) in enumerate(path):
        phase = i % 5
        if phase in (0, 1, 2):
            # a face-on link: a little ring, lit on top
            f.put(x, y, G[2])
            f.put(x, y - 1, G[1])
            f.put(x, y + 1, G[3])
        else:
            # an edge-on link joining two rings
            f.put(x, y, G[4])
    f.outline()
    for i, (x, y) in enumerate(path):
        if i % 5 == 1:
            f.put(x, y, HOLE)                  # the eye of each face-on link
    return f


# ------------------------------------------------------------ parts mould

def mould(pal, poured=False):
    """A clay slab with three recesses: a toothed wheel, a bushing and a bar."""
    f = Frame()
    x0, y0, x1, y1 = 1, 7, 30, 24
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            edge = x in (x0, x1) or y in (y0, y1)
            rim = x in (x0 + 1, x1 - 1) or y in (y0 + 1, y1 - 1)
            f.put(x, y, pal['e'] if edge else pal['r'] if rim else pal['f'])
    recess = set()
    for y in range(y0 + 2, y1 - 1):
        for x in range(x0 + 2, x1 - 1):
            # toothed wheel, its eye left standing as a core
            dx, dy = x - 9.5, y - 14.5
            r = math.hypot(dx, dy)
            a = math.atan2(dy, dx) % (2 * math.pi)
            if 1.3 < r <= 4.3 or (r <= 6.1 and (a * 8 / (2 * math.pi)) % 1.0 < 0.5 and r > 1.3):
                recess.add((x, y))
            # bushing: a ring round a core
            r = math.hypot(x - 22.5, y - 12.5)
            if 1.6 < r <= 4.3:
                recess.add((x, y))
            # bar
            if 17 <= x <= 27 and 19 <= y <= 20:
                recess.add((x, y))
    for (x, y) in recess:
        # the wall under the upper-left lip is in shadow, the far wall catches light
        lip = (x - 1, y) not in recess or (x, y - 1) not in recess
        f.put(x, y, pal['e'] if lip else pal['c'])
    for (x, y) in recess:
        for n in ((x + 1, y), (x, y + 1)):
            if n not in recess and f.px.get(n, (0,))[:3] == pal['f']:
                f.put(n[0], n[1], pal['l'])
    if poured:
        for (x, y) in recess:
            deep = all(n in recess for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
            f.put(x, y, MELT[1] if deep else MELT[0])
    return f


def build():
    """name -> (frames, delays); delays is None for a still state."""
    states = {}
    for name, draw in (('gear', gear), ('gear_wood', gear_wood), ('shaft', shaft),
                       ('shaft_wood', shaft_wood), ('bearing', bearing),
                       ('bearing_wood', bearing_wood), ('spring', spring), ('belt', belt),
                       ('chain', chain), ('wheel', wheel), ('wheel_wood', wheel_wood),
                       ('wheel_shod', wheel_shod)):
        states[name] = ([draw()], None)
    states['parts_mold_raw'] = ([mould(RAW)], None)
    states['parts_mold_empty'] = ([mould(FIRED)], None)
    states['parts_mold_full'] = ([mould(FIRED, poured=True)], None)
    return states


def render(states):
    frames = [fr for group, _ in states.values() for fr in group]
    rows = -(-len(frames) // COLUMNS)
    sheet = Image.new('RGBA', (32 * COLUMNS, 32 * rows), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(fr.image(), (i % COLUMNS * 32, i // COLUMNS * 32))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, (group, delays) in states.items():
        text += 'state = "%s"\n\tdirs = 1\n\tframes = %d\n' % (name, len(group))
        if delays:
            text += '\tdelay = %s\n' % ','.join(str(d) for d in delays)
    text += '# END DMI\n'
    return sheet, text


def write_dmi(path, states):
    sheet, text = render(states)
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta)


def check(path, states):
    sheet, text = render(states)
    if not Path(path).is_file():
        return ['%s is missing' % path]
    with Image.open(path) as im:
        have_text = im.info.get('Description', '')
        have = im.convert('RGBA')
    problems = []
    if have_text != text:
        problems.append('state metadata differs')
    if have.size != sheet.size or have.tobytes() != sheet.tobytes():
        problems.append('pixels differ')
    return problems


# ------------------------------------------------------------------ preview

def tinted(im, colour):
    """BYOND's colour var multiplies each channel."""
    out = im.copy()
    px = out.load()
    for y in range(32):
        for x in range(32):
            r, g, b, a = px[x, y]
            px[x, y] = (r * colour[0] // 255, g * colour[1] // 255, b * colour[2] // 255, a)
    return out


def write_preview(path, states, scale=4):
    cell, pad, label = 32 * scale, 8, 14
    rows = []
    for name, (group, _) in states.items():
        im = group[0].image()
        row = [(name, im)]
        for material in SHOWN_IN.get(name, ()):
            row.append((material, tinted(im, TINTS[material])))
        rows.append(row)
    wide = max(len(r) for r in rows)
    box_w, box_h = cell + 44 + pad, cell + label + pad
    sheet = Image.new('RGBA', (box_w * wide + pad, box_h * len(rows) + pad), DARK + (255,))
    draw = ImageDraw.Draw(sheet)
    for j, row in enumerate(rows):
        for i, (name, im) in enumerate(row):
            ox, oy = pad + i * box_w, pad + j * box_h
            draw.text((ox, oy), name, fill=(232, 228, 214))
            tile = Image.new('RGBA', (32, 32), FLOORS[0] + (255,))
            tile.alpha_composite(im)
            sheet.alpha_composite(tile.resize((cell, cell), Image.NEAREST), (ox, oy + label))
            for k, floor in enumerate(FLOORS):
                tile = Image.new('RGBA', (32, 32), floor + (255,))
                tile.alpha_composite(im)
                sheet.alpha_composite(tile, (ox + cell + 6, oy + label + k * 38))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.convert('RGB').save(path)


def main():
    states = build()
    if '--check' in sys.argv:
        problems = check(DMI, states)
        for p in problems:
            print('machine_parts.dmi: ' + p)
        if problems:
            sys.exit(1)
        print('machine_parts.dmi matches (%d states, %d frames)'
              % (len(states), sum(len(g) for g, _ in states.values())))
    else:
        write_dmi(DMI, states)
    if '--preview' in sys.argv[1:-1]:
        write_preview(sys.argv[sys.argv.index('--preview') + 1], states)


if __name__ == '__main__':
    main()
