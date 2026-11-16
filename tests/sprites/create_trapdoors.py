"""Hand-placed 32px trapdoor sprites for icons/obj/doors/trapdoors.dmi: a
wooden trapdoor and an iron hatch that lie flat in an opening in a floor,
each shut, open and through its opening and closing animations, the lock, bar
and bolt overlays laid over them shut, and the two inventory items.

Everything is seen from above. A shut leaf covers the whole tile opaquely, so
it hides the level below. The leaf hangs on two hinges on the north edge and
swings up to stand upright along it: an open trapdoor is a band of planks
(the underside of the leaf, with its two ledges) across the top 8 rows, and
the rest of the tile is clear except the rim of the opening, so the stairs,
ladder or level drawn underneath shows through. The rim is 2px for the timber
frame and 3px for the heavier iron one. The opening animation is four frames
(delays 3,2,2,3, loop 1) of the upper face foreshortening as the free edge
rises, with the shadow of that edge under it; closing runs them backwards.

Unlike the material doors these are not tinted, so they are drawn in their
own colours, and the overlays carry their own dark outline so they read on
both leaves. The fittings each have their own place on the shut leaf:

  hinges     x = 5-9 and 22-26, y = 0-10   north edge (part of the base)
  brackets   x = 6-9 and 22-25, y = 13-18  either side of the middle
  bar        x = 1-30,          y = 14-17  east-west through the brackets
  bolt       x = 4-8,           y = 22-30  south edge, left; shoots south
  pull       x = 12-19,         y = 22-27  south edge, middle (part of base)
  lock       x = 21-27,         y = 21-28  south edge, right of the pull

Every pixel is placed by this script from a fixed palette (Pillow only); no
external or generated artwork. Run it to reproduce the sheet; `--check`
verifies the committed sheet instead of writing it, `--preview <png>` writes
a 4x review sheet. Released under Civ13 AGPL-3.0.
"""
import sys
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/doors/trapdoors.dmi'

OUT = (28, 22, 16)
# leaf planks: highlight, light, mid, shade, dark, deepest
PLANK = [(190, 140, 84), (164, 114, 64), (142, 96, 52), (118, 78, 42), (88, 56, 30), (54, 32, 16)]
# timber frame of the opening, darker than the leaf: light, mid, dark, deepest
RIM = [(124, 80, 44), (98, 62, 34), (72, 44, 24), (46, 28, 14)]
# forged iron fittings: highlight, light, mid, dark, deepest
IRON = [(206, 212, 220), (150, 158, 170), (104, 112, 126), (66, 72, 86), (30, 34, 44)]
# iron hatch plate: highlight, light, mid, shade, dark
PLATE = [(176, 182, 192), (140, 146, 158), (114, 120, 132), (90, 96, 108), (64, 68, 80)]
# iron curb of the hatch: light, mid, dark, deepest
CURB = [(96, 102, 114), (70, 76, 88), (48, 52, 62), (30, 32, 40)]
# blackened bolt plate: highlight, light, mid, dark
BODY = [(142, 148, 160), (92, 98, 112), (62, 66, 78), (42, 44, 54)]
# bar timber: highlight, light, mid, dark
WOOD = [(222, 184, 124), (184, 140, 86), (140, 100, 58), (96, 66, 36)]
# brass lock plate: highlight, light, mid, dark
BRASS = [(248, 222, 132), (220, 178, 78), (170, 126, 46), (112, 80, 30)]
VOID = (14, 12, 14)
SHADOW = (12, 10, 10, 120)      # cast by the rising leaf onto what is below

DELAYS = (3, 2, 2, 3)           # deciseconds a frame, opening and closing
# rows of the tile the foreshortened leaf covers at each opening frame
SWING = (25, 19, 13, 9)
OPEN_BAND = 8                   # rows the upright leaf covers when open


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

    def rows(self, top, left, art, key=None):
        """Stamp ASCII art: each character is looked up in key, '.' is clear."""
        key = key or KEY
        for dy, row in enumerate(art):
            for dx, ch in enumerate(row):
                if ch != '.':
                    self.put(left + dx, top + dy, key[ch])
        return self

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

    def image(self):
        im = Image.new('RGBA', (32, 32))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c if len(c) == 4 else c + (255,))
        return im


KEY = {
    'O': OUT, 'V': VOID,
    'H': IRON[0], 'I': IRON[1], 'i': IRON[2], 'd': IRON[3], 'k': IRON[4],
    'B': BODY[0], 'b': BODY[1], 'c': BODY[2], 'e': BODY[3],
    'W': WOOD[0], 'w': WOOD[1], 'x': WOOD[2], 'y': WOOD[3],
    'A': BRASS[0], 'a': BRASS[1], 'r': BRASS[2], 's': BRASS[3],
    'P': PLANK[0], 'p': PLANK[1], 'q': PLANK[2], 'Q': PLANK[3], 'u': PLANK[4], 'U': PLANK[5],
}


def darker(c, k):
    return tuple(int(v * k) for v in c[:3])


# ---------------------------------------------------------------- frames

def rim_wood(f):
    """The 2px timber frame of the opening, lit from the upper left."""
    f.rect(0, 0, 31, 1, RIM[1])
    f.rect(0, 30, 31, 31, RIM[2])
    f.rect(0, 0, 1, 31, RIM[1])
    f.rect(30, 0, 31, 31, RIM[2])
    f.rect(0, 0, 31, 0, RIM[0])
    f.rect(0, 0, 0, 31, RIM[0])
    f.rect(1, 31, 31, 31, RIM[3])
    f.rect(31, 1, 31, 31, RIM[3])
    # the inner row is the dark rebate the leaf drops into
    f.rect(1, 1, 30, 1, RIM[3])
    f.rect(1, 30, 30, 30, RIM[3])
    f.rect(1, 1, 1, 30, RIM[3])
    f.rect(30, 1, 30, 30, RIM[3])
    return f


def rim_iron(f):
    """The 3px iron curb of the hatch, with a bolt head at each corner and
    midway along each side."""
    f.rect(0, 0, 31, 2, CURB[1])
    f.rect(0, 29, 31, 31, CURB[2])
    f.rect(0, 0, 2, 31, CURB[1])
    f.rect(29, 0, 31, 31, CURB[2])
    f.rect(0, 0, 31, 0, CURB[0])
    f.rect(0, 0, 0, 31, CURB[0])
    f.rect(1, 31, 31, 31, CURB[3])
    f.rect(31, 1, 31, 31, CURB[3])
    # the inner edge, where the curb drops to the plate or the opening
    f.rect(2, 2, 29, 2, CURB[2])
    f.rect(2, 2, 2, 29, CURB[2])
    f.rect(2, 29, 29, 29, CURB[3])
    f.rect(29, 2, 29, 29, CURB[3])
    for x, y in ((1, 1), (30, 1), (1, 30), (30, 30), (15, 1), (16, 30), (1, 16), (30, 15)):
        f.pts(IRON[1], (x, y))
    return f


# ---------------------------------------------------------------- leaves
# A leaf is drawn on its own, as a dict of pixels in tile coordinates, so the
# same art serves the shut state, the swing frames and the kit item.

WOOD_BOX = (2, 2, 29, 29)       # the leaf inside the timber frame
IRON_BOX = (3, 3, 28, 28)       # the plate inside the iron curb
PLANK_X = (2, 9, 16, 23, 30)    # left edge of each of the four planks


def strap_hinge(f, x):
    """An iron strap hinge: the knuckle on the north rim and a strap, nailed
    three times, tapering down the leaf to a point."""
    f.rows(0, x, [
        'HIIId',
        'IiiiK',
        'dKKKK',
        '.Iid.',
        '.Hid.',
        '.Iid.',
        '.Iid.',
        '.Hid.',
        '.Iid.',
        '.Iik.',
        '..d..',
    ], dict(KEY, K=IRON[4]))


def leaf_wood():
    """Four boards running north-south, each lit down its left edge, with
    grain streaks, two strap hinges on the north edge and an iron ring pull,
    lying in its staple, by the south edge."""
    f = Frame()
    x0, y0, x1, y1 = WOOD_BOX
    tones = (PLANK[2], PLANK[1], PLANK[2], PLANK[3])
    for n in range(4):
        a, b = PLANK_X[n], PLANK_X[n + 1] - 1
        f.rect(a, y0, b, y1, tones[n])
        f.rect(a, y0, a, y1, PLANK[0] if n == 1 else PLANK[1])
        f.rect(b, y0, b, y1, PLANK[5])
        f.rect(b - 1, y0, b - 1, y1, PLANK[4] if n == 3 else PLANK[3])
    # sawn ends: a lit top edge and a dark bottom edge on the leaf
    f.rect(x0, y0, x1, y0, PLANK[1])
    f.rect(x0, y1, x1, y1, PLANK[4])
    for x in (8, 15, 22, 29):
        f.pts(PLANK[5], (x, y0), (x, y1))
    # grain: dark and light streaks along the boards, and one knot
    for x, ya, yb, c in ((4, 6, 12, PLANK[3]), (6, 15, 23, PLANK[3]), (5, 25, 28, PLANK[1]),
                         (11, 12, 20, PLANK[2]), (13, 4, 9, PLANK[2]), (12, 23, 27, PLANK[0]),
                         (18, 11, 17, PLANK[3]), (20, 19, 27, PLANK[3]), (19, 4, 8, PLANK[1]),
                         (25, 13, 19, PLANK[4]), (27, 21, 27, PLANK[4]), (26, 5, 9, PLANK[2])):
        f.rect(x, ya, x, yb, c)
    f.pts(PLANK[4], (19, 14), (20, 14), (19, 15))
    f.pts(PLANK[5], (20, 15))
    strap_hinge(f, 5)
    strap_hinge(f, 22)
    # ring pull: an iron ring hanging south from a staple, and its shadow
    f.rows(22, 13, [
        '.dHId.',
        '.HkkI.',
        'HkuukI',
        'IkuukI',
        '.Iiid.',
        '..kk..',
    ])
    return f


def leaf_iron():
    """Three courses of iron plate lapped at two riveted seams, rivets round
    the edge, two barrel hinges on the north curb and a drop handle lying in
    its two eyes by the south edge."""
    f = Frame()
    x0, y0, x1, y1 = IRON_BOX
    f.rect(x0, y0, x1, y1, PLATE[2])
    f.rect(x0, y0, x1, y0, PLATE[0])
    f.rect(x0, y0, x0, y1, PLATE[1])
    f.rect(x0, y1, x1, y1, PLATE[4])
    f.rect(x1, y0, x1, y1, PLATE[4])
    f.rect(x1 - 1, y0 + 1, x1 - 1, y1 - 1, PLATE[3])
    f.rect(x0 + 1, y1 - 1, x1 - 1, y1 - 1, PLATE[3])
    # lap seams: lit edge, then the shadow the upper course throws
    for y in (11, 20):
        f.rect(x0 + 1, y - 1, x1 - 1, y - 1, PLATE[1])
        f.rect(x0 + 1, y, x1 - 1, y, PLATE[4])
        for x in range(6, x1, 4):
            f.pts(PLATE[0], (x, y - 1))
    # worn patches and scratches
    f.pts(PLATE[1], (12, 6), (13, 6), (14, 7), (18, 14), (19, 14), (9, 16), (10, 17), (8, 24),
          (23, 25), (24, 25))
    f.pts(PLATE[3], (16, 5), (17, 6), (12, 15), (13, 16), (21, 17), (22, 17), (9, 23), (10, 26))
    # rivets round the edge, each with its shadow
    for x in range(5, x1, 4):
        for y in (y0 + 2, y1 - 2):
            f.pts(PLATE[0], (x, y))
            f.pts(PLATE[4], (x, y + 1))
    for y in (8, 14, 17, 23):
        for x in (x0 + 2, x1 - 2):
            f.pts(PLATE[0], (x, y))
            f.pts(PLATE[4], (x, y + 1))
    # barrel hinges: a knuckle across the curb and a leaf plate, bolted twice
    for x in (5, 22):
        f.rows(0, x, [
            'dHHHd',
            'IIiIi',
            'kdkdk',
            'HIIId',
            'IHiHd',
            'Iiiid',
            'dkkkk',
        ])
    # drop handle: a bar between two eyes, lying flat, and its shadow
    f.rows(22, 12, [
        'Hd....Hd',
        'IHHHHHId',
        'IdkkkkId',
        'Id....Id',
        'iIIIIIid',
        '.kkkkkk.',
    ])
    return f


def underside_wood():
    """The upright leaf seen from the south: the underside of the boards as a
    band, the top row its sawn edge, with the two ledges that hold the boards
    together and a dark edge where it meets the frame."""
    f = Frame()
    h = OPEN_BAND
    f.rect(0, 0, 31, h - 1, RIM[2])
    for n in range(4):
        a, b = PLANK_X[n], PLANK_X[n + 1] - 1
        f.rect(a, 0, b, 0, PLANK[1])                # the free edge, catching the light
        f.rect(a, 1, b, h - 3, PLANK[3 if n % 2 else 4])
        f.rect(b, 0, b, h - 3, PLANK[5])
    f.pts(PLANK[0], (3, 0), (4, 0), (10, 0), (17, 0), (18, 0), (24, 0))
    # ledges across the boards, nailed at each one
    for y in (2, 4):
        f.rect(2, y, 29, y, PLANK[2])
        for x in (5, 12, 19, 26):
            f.pts(IRON[3], (x, y))
    f.rect(2, 5, 29, 5, PLANK[5])
    # the foot of the leaf on the north rim, and the hinge knuckles under it
    f.rect(0, h - 2, 31, h - 2, RIM[3])
    f.rect(2, h - 1, 29, h - 1, VOID)
    f.rect(1, 0, 1, h - 1, RIM[3])
    f.rect(30, 0, 30, h - 1, RIM[3])
    f.rect(0, 0, 0, h - 1, RIM[0])
    f.rect(31, 0, 31, h - 1, RIM[3])
    for x in (6, 23):
        f.rect(x, h - 3, x + 2, h - 2, IRON[3])
        f.pts(IRON[1], (x, h - 3))
    return f


def underside_iron():
    """The upright plate seen from the south: its darker, unpainted underside
    with a stiffening rib, rivet ends and the two hinge knuckles at its foot."""
    f = Frame()
    h = OPEN_BAND
    f.rect(0, 0, 31, h - 1, CURB[2])
    f.rect(3, 0, 28, 0, PLATE[0])                   # the free edge
    f.rect(3, 1, 28, h - 3, PLATE[4])
    f.rect(3, 1, 3, h - 3, PLATE[3])
    f.rect(28, 1, 28, h - 3, CURB[3])
    f.rect(4, 3, 27, 3, PLATE[2])                   # stiffening rib
    f.rect(4, 4, 27, 4, CURB[3])
    for x in range(6, 28, 4):
        f.pts(PLATE[1], (x, 1))
        f.pts(PLATE[3], (x, 5))
    f.rect(0, h - 2, 31, h - 2, CURB[3])
    f.rect(3, h - 1, 28, h - 1, VOID)
    f.rect(0, 0, 2, h - 1, CURB[1])
    f.rect(29, 0, 31, h - 1, CURB[2])
    f.rect(0, 0, 0, h - 1, CURB[0])
    f.rect(31, 0, 31, h - 1, CURB[3])
    f.rect(2, 0, 2, h - 1, CURB[2])
    f.rect(29, 0, 29, h - 1, CURB[3])
    for x in (6, 23):
        f.rect(x, h - 3, x + 2, h - 2, IRON[3])
        f.pts(IRON[1], (x, h - 3))
    return f


# ---------------------------------------------------------------- states

def shut(rim, leaf):
    f = rim(Frame())
    f.px.update(leaf.px)
    return f


def opened(rim, underside):
    """The rim of the opening, clear inside, with the upright leaf across the
    north edge."""
    f = rim(Frame())
    edge = 3 if rim is rim_iron else 2
    for (x, y) in list(f.px):
        if edge <= x <= 31 - edge and edge <= y <= 31 - edge:
            del f.px[(x, y)]
    f.px.update(underside.px)
    return f


def swing(rim, leaf, box, rows, step):
    """One opening frame: the upper face of the leaf squeezed into `rows`
    rows below the north rim as its free edge rises, growing darker as it
    tips away from the light, with the edge of the leaf and the shadow it
    throws into the opening beneath it."""
    x0, y0, x1, y1 = box
    f = rim(Frame())
    for (x, y) in list(f.px):
        if x0 <= x <= x1 and y0 <= y <= y1:
            del f.px[(x, y)]
    tall = y1 - y0 + 1
    shade = 1.0 - 0.07 * (step + 1)
    for (x, y), c in leaf.px.items():
        if y < y0:              # the hinge knuckles stay on the rim
            f.put(x, y, c)
    for r in range(rows):
        src = y0 + (r * tall) // rows
        for x in range(x0, x1 + 1):
            f.put(x, y0 + r, darker(leaf.px[(x, src)], shade))
    # the free edge: a lit lip, then the thickness of the leaf in shadow
    lip = PLANK[0] if box is WOOD_BOX else PLATE[0]
    deep = PLANK[5] if box is WOOD_BOX else CURB[3]
    f.rect(x0, y0 + rows - 1, x1, y0 + rows - 1, lip)
    f.rect(x0, y0 + rows, x1, y0 + rows, deep)
    for d in (1, 2):
        f.rect(x0, y0 + rows + d, x1, y0 + rows + d, SHADOW[:3] + (SHADOW[3] // d,))
    return f


def door_states(name, rim, leaf, underside, box):
    opening = [swing(rim, leaf, box, rows, n) for n, rows in enumerate(SWING)]
    return {
        name: [shut(rim, leaf)],
        name + 'open': [opened(rim, underside)],
        name + 'opening': opening,
        name + 'closing': opening[::-1],
    }


# ---------------------------------------------------------------- overlays

BRACKET_X = (6, 22)     # left edge of each bracket
BAR_X = (1, 30)         # a bar reaches over the frame on both sides
BOLT_AT = (4, 22)       # left, top of the bolt plate


def lock():
    """A brass lock plate, screwed at two corners, with a dark keyhole."""
    return Frame().rows(22, 22, [
        'AAAar',
        'aVVVr',
        'aVVVr',
        'aaVrr',
        'aaVrs',
        'rrsss',
    ]).outline()


def brackets():
    """Two iron staples standing on the leaf, open to the west and east so a
    bar can be slid through them: a foot plate above and below a dark gap."""
    f = Frame()
    for left in BRACKET_X:
        f.rows(13, left, [
            'HIId',
            'IHid',
            'k..k',
            'k..k',
            'Iiid',
            'dkkk',
        ])
    return f.outline()


def bracket_straps(f):
    """The brackets as they show over a bar: a foot above and below it and
    the strap of the staple crossing it."""
    for left in BRACKET_X:
        f.rows(13, left, [
            'HIId',
            'HIid',
            'IIid',
            'Iiid',
            'Iidd',
            'dkkk',
        ])
    return f


def bar_wood():
    """A timber beam laid east-west through both brackets, its ends resting
    on the frame."""
    f = Frame()
    x0, x1 = BAR_X
    f.rect(x0, 14, x1, 14, WOOD[0])
    f.rect(x0, 15, x1, 15, WOOD[1])
    f.rect(x0, 16, x1, 16, WOOD[2])
    f.rect(x0, 17, x1, 17, WOOD[3])
    f.pts(WOOD[2], (3, 15), (4, 15), (12, 15), (13, 15), (14, 15), (19, 15), (27, 15), (28, 15))
    f.pts(WOOD[1], (11, 14), (12, 14), (18, 14), (19, 14), (15, 16), (16, 16))
    f.pts(WOOD[3], (13, 16), (14, 16), (19, 16), (20, 16))
    f.pts(WOOD[1], (x0, 14), (x1, 14))
    f.pts(WOOD[2], (x0, 15), (x1, 15))
    f.pts(WOOD[3], (x0, 16), (x1, 16))
    return bracket_straps(f).outline()


def bar_iron():
    """A forged iron bar, thinner than the beam, riveted by each end."""
    f = Frame()
    x0, x1 = BAR_X
    f.rect(x0, 15, x1, 15, IRON[1])
    f.rect(x0, 16, x1, 16, IRON[3])
    f.pts(IRON[2], (x0, 15), (x1, 15))
    for x in (2, 12, 19, 29):
        f.pts(IRON[0], (x, 15))
        f.pts(IRON[4], (x, 16))
    return bracket_straps(f).outline()


def bolt_open():
    """A slide bolt by the south edge, its rod drawn back up onto the plate
    and the knob at the top of its slot; the keeper on the frame is empty."""
    left, top = BOLT_AT
    return Frame().rows(top, left, [
        'BBbbc',
        'BbHbc',
        'bHIie',
        'bbIce',
        'bbIce',
        'ceeee',
        '.....',
        'HkkI.',
        'idd..',
    ]).outline()


def bolt_shut():
    """The same bolt with its rod shot south through the keeper into the
    frame and the knob at the bottom of its slot."""
    left, top = BOLT_AT
    return Frame().rows(top, left, [
        'BBbbc',
        'Bbkbc',
        'bbkce',
        'bbIce',
        'bHIie',
        'ccIee',
        '..I..',
        'HIIId',
        'idId.',
    ]).outline()


# ---------------------------------------------------------------- items

def kit_wood():
    """A wooden trapdoor leaf: five boards, two strap hinges and the ring."""
    f = Frame()
    for n in range(5):
        a = 6 + n * 4
        f.rect(a, 7, a + 3, 26, (PLANK[2], PLANK[1], PLANK[2], PLANK[3], PLANK[2])[n])
        f.rect(a, 7, a, 26, PLANK[0] if n == 1 else PLANK[1])
        f.rect(a + 3, 7, a + 3, 26, PLANK[5])
    f.rect(6, 7, 25, 7, PLANK[0])
    f.rect(6, 26, 25, 26, PLANK[4])
    f.rect(25, 7, 25, 26, PLANK[5])
    for x, ya, yb, c in ((8, 12, 17, PLANK[3]), (12, 18, 23, PLANK[2]), (16, 10, 14, PLANK[3]),
                         (20, 15, 22, PLANK[4]), (23, 10, 13, PLANK[3])):
        f.rect(x, ya, x, yb, c)
    for x in (8, 20):
        f.rows(6, x, [
            'HIId',
            'dkkk',
            '.Hd.',
            '.Id.',
            '.Id.',
            '.Hd.',
            '.Id.',
            '.d..',
        ])
    f.rows(19, 13, [
        '.HId.',
        'HkukI',
        'IkukI',
        '.Iid.',
    ])
    return f.outline()


def kit_iron():
    """An iron hatch leaf: a riveted plate with one lap seam, two hinge
    knuckles on its north edge and the drop handle."""
    f = Frame()
    f.rect(6, 8, 25, 26, PLATE[2])
    f.rect(6, 8, 25, 8, PLATE[0])
    f.rect(6, 8, 6, 26, PLATE[1])
    f.rect(6, 26, 25, 26, PLATE[4])
    f.rect(25, 8, 25, 26, PLATE[4])
    f.rect(24, 9, 24, 25, PLATE[3])
    f.rect(7, 15, 24, 15, PLATE[1])
    f.rect(7, 16, 24, 16, PLATE[4])
    f.pts(PLATE[1], (11, 11), (12, 11), (17, 12), (10, 20), (20, 19))
    f.pts(PLATE[3], (14, 12), (15, 13), (19, 21), (9, 23))
    for x in range(8, 25, 4):
        for y in (10, 24):
            f.pts(PLATE[0], (x, y))
            f.pts(PLATE[4], (x, y + 1))
    for y in (13, 19):
        for x in (8, 23):
            f.pts(PLATE[0], (x, y))
            f.pts(PLATE[4], (x, y + 1))
    for x in (8, 20):
        f.rows(6, x, [
            'dHHd',
            'IiIi',
            'kdkd',
            'HIId',
            'dkkk',
        ])
    f.rows(18, 12, [
        'Hd....Hd',
        'IHHHHHId',
        'IdkkkkId',
        'iIIIIIid',
        '.kkkkkk.',
    ])
    return f.outline()


OVERLAYS = ('lock', 'brackets', 'bar_wood', 'bar_iron', 'bolt_open', 'bolt_shut')
BASES = ('trapdoor_wood', 'hatch_iron')


def states():
    st = {}
    st.update(door_states('trapdoor_wood', rim_wood, leaf_wood(), underside_wood(), WOOD_BOX))
    st.update(door_states('hatch_iron', rim_iron, leaf_iron(), underside_iron(), IRON_BOX))
    st.update({
        'lock': [lock()],
        'brackets': [brackets()],
        'bar_wood': [bar_wood()],
        'bar_iron': [bar_iron()],
        'bolt_open': [bolt_open()],
        'bolt_shut': [bolt_shut()],
        'kit_wood': [kit_wood()],
        'kit_iron': [kit_iron()],
    })
    return st


def assert_shape(st):
    """A shut leaf hides the whole tile; an open one leaves the opening clear
    below the upright leaf and inside the rim."""
    for base, edge in (('trapdoor_wood', 2), ('hatch_iron', 3)):
        shut_px = st[base][0].px
        if len(shut_px) != 1024 or any(len(c) == 4 and c[3] != 255 for c in shut_px.values()):
            sys.exit('%s does not cover the tile opaquely' % base)
        open_px = st[base + 'open'][0].px
        for y in range(32):
            for x in range(32):
                inside = edge <= x <= 31 - edge and OPEN_BAND <= y <= 31 - edge
                if inside == ((x, y) in open_px):
                    sys.exit('%sopen: wrong coverage at %d,%d' % (base, x, y))
    for a in ('lock', 'brackets', 'bolt_open', 'bolt_shut'):
        for b in ('lock', 'brackets', 'bar_wood', 'bar_iron', 'bolt_open', 'bolt_shut'):
            if a != b and {a, b} != {'bolt_open', 'bolt_shut'} and not (a == 'brackets' and b.startswith('bar_')):
                if st[a][0].px.keys() & st[b][0].px.keys():
                    sys.exit('%s overlaps %s' % (a, b))


def build_sheet(st):
    frames = [fr for group in st.values() for fr in group]
    sheet = Image.new('RGBA', (32 * len(frames), 32), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(fr.image(), (i * 32, 0))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, group in st.items():
        text += 'state = "%s"\n\tdirs = 1\n\tframes = %d\n' % (name, len(group))
        if len(group) > 1:
            text += '\tdelay = %s\n\tloop = 1\n' % ','.join(str(d) for d in DELAYS)
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


def checker(size=32, cell=4):
    """A mid-grey checker, so clear pixels show in the review sheet."""
    im = Image.new('RGBA', (size, size))
    for y in range(size):
        for x in range(size):
            im.putpixel((x, y), (132, 132, 132, 255) if (x // cell + y // cell) % 2 else (104, 104, 104, 255))
    return im


def preview(path, st, scale=4):
    text, dim = (230, 230, 230), (170, 170, 170)
    grounds = [(94, 132, 62), (120, 96, 66), (172, 168, 160), (60, 60, 64)]
    cell, pad, label, left = 32 * scale, 8, 14, 60
    step = cell + pad
    # label, state suffix, frame, overlays
    swing_cols = [('shut', '', 0, ())]
    swing_cols += [('opening %d' % (n + 1), 'opening', n, ()) for n in range(len(SWING))]
    swing_cols += [('open', 'open', 0, ())]
    swing_cols += [('closing %d' % (n + 1), 'closing', n, ()) for n in range(len(SWING))]
    fitted = [(name, '', 0, (name,)) for name in OVERLAYS]
    fitted += [('lock+bar+bolt', '', 0, ('bar_wood', 'lock', 'bolt_shut')),
               ('lock+iron bar', '', 0, ('bar_iron', 'lock', 'bolt_open'))]
    width = left + max(len(swing_cols), len(fitted)) * step + pad
    block = label + len(BASES) * step + pad
    height = 2 * block + (label + step + pad) + (label + 4 * 34) + pad * 2
    sheet = Image.new('RGBA', (width, height), (40, 40, 44, 255))
    draw = ImageDraw.Draw(sheet)

    def tile(base, suffix, frame, overlays):
        t = checker()
        t.alpha_composite(st[base + suffix][frame].image())
        for name in overlays:
            t.alpha_composite(st[name][0].image())
        return t

    y = 2
    ones = []
    for group in (swing_cols, fitted):
        for c, col in enumerate(group):
            draw.text((left + c * step, y), col[0], fill=text)
        y += label
        for r, base in enumerate(BASES):
            draw.text((4, y + r * step + cell // 2), base.split('_')[1], fill=dim)
            row = [tile(base, *col[1:]) for col in group]
            for c, t in enumerate(row):
                sheet.paste(t.resize((cell, cell), Image.NEAREST), (left + c * step, y + r * step))
            ones.append(row)
        y += len(BASES) * step + pad
    # the overlays on their own, then the items
    singles = list(OVERLAYS) + ['kit_wood', 'kit_iron']
    for c, name in enumerate(singles):
        draw.text((left + c * step, y), name, fill=text)
        t = checker() if name in OVERLAYS else Image.new('RGBA', (32, 32), grounds[c % 2] + (255,))
        t.alpha_composite(st[name][0].image())
        sheet.paste(t.resize((cell, cell), Image.NEAREST), (left + c * step, y + label))
    y += label + step + pad
    draw.text((4, y), '1x', fill=text)
    y += label
    for r, row in enumerate(ones):
        for c, t in enumerate(row):
            sheet.paste(t, (left + c * 34, y + r * 34))
    for c, name in enumerate(('kit_wood', 'kit_iron')):
        for g, ground in enumerate(grounds):
            t = Image.new('RGBA', (32, 32), ground + (255,))
            t.alpha_composite(st[name][0].image())
            sheet.paste(t, (left + (12 + c) * 34, y + g * 34))
    sheet.save(path)


if __name__ == '__main__':
    st = states()
    assert_shape(st)
    if '--check' in sys.argv:
        check(SHEET, st)
    else:
        write_dmi(SHEET, st)
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1], st)
