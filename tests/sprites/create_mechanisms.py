"""Hand-placed 32px Stone Age mechanisms for icons/obj/mechanisms.dmi: a
lever, a pull cord, a pressure plate and a rock drop, each in its rest and
its worked state, and a single-state wooden pulley. Wood, rope and stone
only - no metal.

Palette and scale follow create_stone_age_traps.py (warm dark outline, grey
field stone, pale split timber, light from the upper left). The pressure plate
is deliberately low in contrast: it lies just above the floor, under people,
and should be found by looking rather than seen at a glance.

Every pixel is placed by this script from a fixed palette (Pillow only); no
external or generated artwork. Run it to reproduce the sheet; `--check`
verifies the committed sheet instead of writing it, `--preview <png>` writes
a 4x review sheet on grass. Released under Civ13 AGPL-3.0.
"""
import sys
from pathlib import Path
from PIL import Image, ImageChops, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/mechanisms.dmi'

OUT = (62, 49, 34, 255)
SHADOW = (20, 16, 12, 80)
# field stone: highlight, light, mid, dark
STONE = [(170, 168, 160, 255), (136, 134, 128, 255), (104, 102, 98, 255), (76, 74, 72, 255)]
# split timber: highlight, light, mid, dark
WOOD = [(214, 180, 132, 255), (184, 146, 98, 255), (140, 104, 64, 255), (92, 61, 34, 255)]
# plant-fibre rope: light, mid, dark
ROPE = [(222, 202, 150, 255), (176, 152, 102, 255), (116, 96, 60, 255)]
# the pressure plate: a flagstone only a little off the ground it sits in
PLATE = [(138, 135, 126, 255), (124, 121, 113, 255), (110, 107, 100, 255), (92, 89, 84, 255)]
SEAM = (40, 34, 28, 255)
SEAM_SOFT = (40, 34, 28, 150)


class Frame:
    def __init__(self):
        self.px = {}

    def put(self, x, y, c):
        if 0 <= x < 32 and 0 <= y < 32:
            self.px[(x, y)] = c

    def pts(self, c, *points):
        for x, y in points:
            self.put(x, y, c)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def line(self, x0, y0, x1, y1, c):
        """Bresenham line; returns the points it set."""
        out = []
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        x, y = x0, y0
        while True:
            self.put(x, y, c)
            out.append((x, y))
            if (x, y) == (x1, y1):
                return out
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x += sx
            if e2 <= dx:
                err += dx
                y += sy

    def pole(self, x0, y0, x1, y1, tones=WOOD):
        """A 2px timber: a lit edge on the left, a shaded edge on the right."""
        for x, y in self.line(x0 + 1, y0, x1 + 1, y1, tones[2]):
            pass
        self.line(x0, y0, x1, y1, tones[1])

    def rows(self, top, left, art, key):
        """Stamp ASCII art: each character is looked up in key, '.' is clear."""
        for dy, row in enumerate(art):
            for dx, ch in enumerate(row):
                if ch != '.':
                    self.put(left + dx, top + dy, key[ch])

    def outline(self, c=OUT):
        """A 1px dark edge on every clear pixel that touches a drawn one."""
        edge = set()
        for (x, y) in self.px:
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if (nx, ny) not in self.px:
                    edge.add((nx, ny))
        for x, y in edge:
            self.put(x, y, c)
        return self

    def shadow(self, x0, x1, y):
        """A soft ground shadow, only where nothing is drawn yet."""
        for x in range(x0, x1 + 1):
            if (x, y) not in self.px:
                self.put(x, y, SHADOW)
        return self

    def image(self):
        im = Image.new('RGBA', (32, 32))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c)
        return im


KEY = {
    'O': OUT,
    'S': STONE[0], 's': STONE[1], 't': STONE[2], 'u': STONE[3],
    'W': WOOD[0], 'w': WOOD[1], 'x': WOOD[2], 'y': WOOD[3],
    'R': ROPE[0], 'r': ROPE[1], 'q': ROPE[2],
}


# ---------------------------------------------------------------- lever

LEVER_BLOCK = [
    '...SSSSSSSSSSSss...',
    '.SSSssssssssssssst.',
    'SSsssssuuuusssssstt',
    'SsssssuOOOOusssssst',
    'ssssssstuutssssstttu',
    'sssstssssssssstttttu',
    'sttsttttstttttttuuu',
    '.ttttuttttttuttuuu.',
    '..uuuuuuuuuuuuuuu..',
]


def lever(pulled):
    """A stout pole socketed in a ground stone, with a rope-whipped grip under
    its rounded head; it leans back to the left at rest and is thrown over to
    the right when pulled."""
    f = Frame()
    f.rows(20, 6, LEVER_BLOCK, KEY)
    tip = 24 if pulled else 6
    foot = 16 if pulled else 14
    shaft = f.line(foot, 23, tip, 7, WOOD[1])
    for x, y in shaft:
        f.put(x - 1, y, WOOD[0] if y % 4 else WOOD[1])
        f.put(x, y, WOOD[1])
        f.put(x + 1, y, WOOD[2])
    for x, y in shaft:
        if 10 <= y <= 12:                       # the grip
            f.put(x - 1, y, ROPE[0])
            f.put(x, y, ROPE[1] if y == 11 else ROPE[0])
            f.put(x + 1, y, ROPE[2])
        if y >= 22:                             # foot lost in the socket
            f.put(x - 1, y, WOOD[2])
            f.put(x, y, WOOD[3])
            f.put(x + 1, y, WOOD[3])
    # the rounded head
    f.rect(tip - 2, 4, tip + 2, 7, WOOD[1])
    f.rect(tip - 1, 3, tip + 1, 8, WOOD[1])
    f.pts(WOOD[0], (tip - 1, 4), (tip, 4), (tip - 1, 5), (tip - 2, 5), (tip - 1, 3))
    f.pts(WOOD[2], (tip + 2, 5), (tip + 2, 6), (tip + 2, 7), (tip + 1, 7), (tip + 1, 8), (tip, 8))
    f.outline()
    f.shadow(5, 26, 30)
    f.shadow(8, 23, 31)
    return f


# ------------------------------------------------------------ pull cord

def pull_cord(pulled):
    """A post with a braced arm; a cord over the arm ends in a wooden toggle.
    At rest the toggle hangs high, pulled it is drawn down with the cord taut."""
    f = Frame()
    # post
    for y in range(4, 29):
        f.put(8, y, WOOD[1])
        f.put(9, y, WOOD[1] if y % 5 else WOOD[2])
        f.put(10, y, WOOD[2])
    f.pts(WOOD[0], (8, 5), (8, 6), (8, 7), (8, 11), (8, 12), (8, 17), (8, 18), (8, 23))
    f.pts(WOOD[3], (10, 26), (10, 27), (10, 28), (9, 28))
    # arm
    for x in range(6, 24):
        f.put(x, 6, WOOD[0] if x % 6 else WOOD[1])
        f.put(x, 7, WOOD[2])
    f.put(23, 7, WOOD[3])
    # brace
    for i in range(6):
        f.put(11 + i, 13 - i, WOOD[1])
        f.put(11 + i, 14 - i, WOOD[2])
    # lashing of arm to post
    f.rect(8, 5, 10, 8, ROPE[1])
    f.pts(ROPE[0], (8, 5), (9, 6), (10, 7), (8, 7), (9, 8))
    f.pts(ROPE[2], (10, 5), (8, 8), (10, 8))
    # cord over the arm end
    end = 21 if pulled else 14
    f.rect(20, 5, 21, 8, ROPE[1])
    f.pts(ROPE[0], (20, 5), (20, 7))
    f.pts(ROPE[2], (21, 6), (21, 8))
    for y in range(9, end + 1):
        f.put(20, y, ROPE[0] if (y % 3 or pulled) else ROPE[1])
        if not pulled and y in (11, 12):
            f.put(21, y, ROPE[1])       # a little slack at rest
    # toggle
    for x in range(16, 25):
        f.put(x, end + 1, WOOD[0] if 17 <= x <= 22 else WOOD[1])
        f.put(x, end + 2, WOOD[2] if x < 24 else WOOD[3])
    f.pts(ROPE[1], (20, end + 1), (20, end + 2))
    f.pts(ROPE[2], (21, end + 1), (21, end + 2))
    f.outline()
    f.shadow(6, 14, 30)
    return f


# ------------------------------------------------------- pressure plate

PLATE_FLECKS = [(9, 11), (14, 13), (21, 12), (11, 18), (18, 17), (23, 20), (13, 22), (20, 22),
                (16, 10), (8, 15), (24, 15)]
PLATE_PITS = [(12, 12), (19, 14), (10, 21), (22, 18), (15, 19), (17, 23)]


def pressure_plate(pressed):
    """A flagstone flush with the ground on a pivot under its far edge, with a
    thin seam round it. Pressed, the near edge has dropped: the slab sits 1px
    lower, loses its lit edge and shows a deep gap along the top."""
    f = Frame()
    x0, x1 = 6, 25
    y0, y1 = (9, 24) if not pressed else (10, 25)
    body = PLATE[2] if pressed else PLATE[1]
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            corner = (x in (x0, x1)) and (y in (y0, y1))
            if not corner:
                f.put(x, y, body)
    d = 1 if pressed else 0
    for x, y in PLATE_FLECKS:
        f.put(x, y + d, PLATE[1] if pressed else PLATE[0])
    for x, y in PLATE_PITS:
        f.put(x, y + d, PLATE[3] if pressed else PLATE[2])
    # a hairline crack, so it reads as one worked slab
    f.pts(PLATE[3], (19, 9 + d + 1), (19, 9 + d + 2), (20, 9 + d + 3), (20, 9 + d + 4))
    if not pressed:
        for x in range(x0 + 1, x1):
            f.put(x, y0, PLATE[0])
        for y in range(y0 + 1, y1):
            f.put(x0, y, PLATE[0])
    for x in range(x0 + 1, x1):
        f.put(x, y1, PLATE[3])
    for y in range(y0 + 1, y1):
        f.put(x1, y, PLATE[3])
    # seam
    edge = set()
    for (x, y) in f.px:
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if (nx, ny) not in f.px:
                edge.add((nx, ny))
    for x, y in edge:
        f.put(x, y, SEAM if (pressed or y > y1 or x > x1) else SEAM_SOFT)
    if pressed:
        # the gap opened above the sunk slab, and the lip of ground over it
        for x in range(x0 + 1, x1):
            f.put(x, y0 - 2, SEAM)
        f.pts(SEAM_SOFT, (x0, y0 - 2), (x1, y0 - 2))
    return f


# ------------------------------------------------------------ rock drop

def a_frame(f):
    """A lashed tripod: a darker back leg, then the two front legs."""
    for y in range(6, 24):
        f.put(16, y, WOOD[3])
        f.put(17, y, WOOD[2] if y < 22 else WOOD[3])
    f.pole(15, 3, 4, 28)
    left = f.line(15, 3, 4, 28, WOOD[1])
    for x, y in left[::5]:
        f.put(x, y, WOOD[0])
    f.line(17, 3, 28, 28, WOOD[2])
    right = f.line(16, 3, 27, 28, WOOD[1])
    for x, y in right[2::5]:
        f.put(x, y, WOOD[0])
    # the crossed heads of the poles and the lashing under them
    f.pts(WOOD[1], (14, 2), (17, 2), (13, 1), (18, 1))
    f.pts(WOOD[2], (15, 2), (18, 2), (19, 1))
    f.rect(14, 4, 18, 5, ROPE[1])
    f.pts(ROPE[0], (14, 4), (16, 4), (15, 5), (17, 5))
    f.pts(ROPE[2], (18, 4), (18, 5), (14, 5))


# the loaded net: stones (S s t u) showing between the cords (R r q)
NET_FULL = [
    '.....rRq.....',
    '....rRrRq....',
    '...RSSrssRq..',
    '..RSSsrsstRq.',
    '.RsSssRSSstrq',
    '.rRssRtsSsRtq',
    'RsstRSSttRstq',
    'RSSsrSsstrSuq',
    'rSsRtsRtRsstq',
    '.RrsstSRstuq.',
    '.qstuRssrtuq.',
    '..qrttrttrq..',
    '...qqruqqq...',
    '.....qqq.....',
]

# the emptied net: a limp mesh, the outline pass darkens its holes
NET_SLACK = [
    '..rR..',
    '..Rq..',
    '.rRrq.',
    '.R.r.q',
    'r.R.rq',
    '.R.r.q',
    'R.r.Rq',
    '.R.r.q',
    'r.R.rq',
    '.r.R.q',
    '.rR.rq',
    '..rRq.',
    '..R.r.',
    '.r...q',
]

STONES_DOWN = [
    '......SSs..........',
    '.....SsssttSSs.....',
    '.SSs.ssstusSsst.Ss.',
    'SSsstsstuusssttuSsst',
    'ssttuuttuusttuuusttu',
    '.uuu..uuu..uuu..uuu.',
]


def rock_drop(empty):
    """Stones bagged in a rope net under a tripod, ready to be let go; once
    dropped the net hangs slack and the stones lie on the ground beneath."""
    f = Frame()
    a_frame(f)
    # the rope from the lashing to the net
    for y in range(6, 9):
        f.put(16, y, ROPE[0] if y % 2 else ROPE[1])
        f.put(17, y, ROPE[2])
    if empty:
        f.rows(8, 14, NET_SLACK, KEY)
        f.rows(23, 6, STONES_DOWN, KEY)
    else:
        f.rows(8, 10, NET_FULL, KEY)
    f.outline()
    f.shadow(3, 29, 30)
    if empty:
        f.shadow(7, 25, 31)
    return f


# --------------------------------------------------------------- pulley

# the sheave: a turned wooden wheel on a peg axle, the rope riding its top
SHEAVE = [
    '....RRRRq....',
    '..RRyyyyyrq..',
    '.RryWWWwwyrq.',
    '.RyWWwwwwxyq.',
    '.RyWwyyywxyq.',
    '.RyWwyOywxyq.',
    '.ryWwyyywxyq.',
    '.R.ywwwxxy.q.',
    '.R..yyyyy..q.',
]

ROPE_COIL = [
    '..RRrq.',
    '.RrqRrq',
    'RrRrqrq',
    '.rqqqq.',
]


def pulley():
    """A timber post braced at the foot, forked at its head round a wooden
    sheave. The rope rides over the sheave: the hauling end falls to a coil on
    the ground, the working end hangs with a toggle, and the standing line
    lashed to the post head runs up out of the tile to the floor above."""
    f = Frame()
    # post
    for y in range(2, 29):
        f.put(15, y, WOOD[1])
        f.put(16, y, WOOD[1] if y % 5 else WOOD[2])
        f.put(17, y, WOOD[2])
    f.pts(WOOD[0], (15, 15), (15, 16), (15, 20), (15, 21), (15, 25))
    f.pts(WOOD[3], (17, 26), (17, 27), (17, 28), (16, 28))
    # foot braces
    for i in range(5):
        f.put(14 - i, 24 + i, WOOD[1])
        f.put(14 - i, 25 + i, WOOD[2])
        f.put(18 + i, 24 + i, WOOD[2])
        f.put(18 + i, 25 + i, WOOD[3])
    # the forked head, its lashing, and the line going up
    f.rect(15, 2, 17, 3, ROPE[1])
    f.pts(ROPE[0], (15, 2), (16, 3))
    f.pts(ROPE[2], (17, 2), (17, 3))
    f.pts(ROPE[0], (16, 0))
    f.pts(ROPE[1], (16, 1))
    f.rows(4, 10, SHEAVE, KEY)
    # hauling end down to its coil
    for y in range(13, 25):
        f.put(11, y, ROPE[0] if y % 3 else ROPE[1])
    f.rows(25, 5, ROPE_COIL, KEY)
    # working end and its toggle
    for y in range(13, 19):
        f.put(21, y, ROPE[1] if y % 3 else ROPE[2])
    for x in range(19, 25):
        f.put(x, 19, WOOD[0] if 20 <= x <= 22 else WOOD[1])
        f.put(x, 20, WOOD[2] if x < 24 else WOOD[3])
    f.pts(ROPE[1], (21, 19), (21, 20))
    f.outline()
    f.shadow(6, 25, 30)
    return f


def states():
    return {
        'lever': [lever(False)],
        'lever_pulled': [lever(True)],
        'pull_cord': [pull_cord(False)],
        'pull_cord_pulled': [pull_cord(True)],
        'pressure_plate': [pressure_plate(False)],
        'pressure_plate_pressed': [pressure_plate(True)],
        'rock_drop': [rock_drop(False)],
        'rock_drop_empty': [rock_drop(True)],
        'pulley': [pulley()],
    }


def build_sheet(st):
    frames = [fr for group in st.values() for fr in group]
    sheet = Image.new('RGBA', (32 * len(frames), 32), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(fr.image(), (i * 32, 0))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, group in st.items():
        text += 'state = "%s"\n\tdirs = %d\n\tframes = 1\n' % (name, len(group))
    text += '# END DMI\n'
    return sheet, text


def write_dmi(path, st):
    sheet, text = build_sheet(st)
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta)


def check(path, st):
    sheet, text = build_sheet(st)
    old = Image.open(path)
    if old.info.get('Description') != text:
        sys.exit('%s: state list differs from the generator' % path)
    if old.size != sheet.size or ImageChops.difference(old.convert('RGBA'), sheet).getbbox():
        sys.exit('%s: pixels differ from the generator' % path)
    print('%s matches the generator' % path)


def preview(path, st, scale=4):
    """All states at 4x on grass, with a true-size row beneath."""
    grass = (94, 132, 62, 255)
    pad = 6
    cell = 32 * scale
    sheet = Image.new('RGBA', (pad + len(st) * (cell + pad), pad * 3 + cell + 32), grass)
    for i, group in enumerate(st.values()):
        tile = Image.new('RGBA', (32, 32), grass)
        tile.alpha_composite(group[0].image())
        x = pad + i * (cell + pad)
        sheet.paste(tile.resize((cell, cell), Image.NEAREST), (x, pad))
        sheet.paste(tile, (x + (cell - 32) // 2, pad * 2 + cell))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


if __name__ == '__main__':
    st = states()
    if '--check' in sys.argv:
        check(SHEET, st)
    else:
        write_dmi(SHEET, st)
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1], st)
