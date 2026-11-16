"""Hand-placed 32px castle defences for icons/obj/castle_defences.dmi.

Wall openings, laid over a built wall tile to show a loophole cut through it:

  arrow_slit (4 dirs): a tall narrow arrow loop with a fishtail foot.
  gun_loop   (4 dirs): a keyhole gun loop - a round hole for the muzzle with
                       a short vertical sighting slit above it.

The dir of each state is the OUTSIDE face of the wall, the side attackers
stand on; defenders stand on the opposite tile and shoot out. Walls are drawn
in the 3/4 top-down view (the top of the wall along the upper rows of the
tile, its south face below), so each facing is drawn the way that side of the
wall is seen:

  SOUTH  the outside is the visible south face: only the narrow dressed-stone
         slit shows, low on the face, and behind it on the wall top the splay
         opens out toward the north (inside) edge.
  NORTH  the visible south face is the inside: a wide splayed embrasure niche
         with a sill, closing to a thin slit of daylight, and on the wall top
         the opening pinches to a point at the north (outside) edge.
  EAST / WEST  the opening runs across the wall top in plan: a splayed wedge
         that is wide on the inside and pinches to the slit on the outside
         edge, where the slit itself is seen edge-on in a dressed-stone jamb.

In every facing the wedge is wide on the defenders' side and its point is
the outside. The walls underneath are stone, sandstone, clay and timber, so
each opening carries its own dark outline and a dressed-stone surround and
is transparent everywhere else.

Pouring and dropping:

  murder_hole_rim (1 dir): a dressed stone kerb round a square shaft in a
        floor. Columns and rows 6-25 (20x20, counted from the top left) are
        fully transparent so the darkened level below shows through; the
        kerb is 4px of stone and a 2px dark lip.
  machicolation (4 dirs): a stone parapet on corbels along the edge of a
        wall-walk tile, with a dark drop opening between each pair of
        corbels. The dir is the OUTSIDE, as for the openings above. The
        piece fills the 16 rows (S: 16-31, N: 0-15) or columns (E: 16-31,
        W: 0-15) on that side and leaves the rest of the tile clear. Corbels
        and crenels repeat every 8 and 16px, so a run of tiles joins up.
  hoarding (4 dirs): the same in timber - a sill beam, a plank floor with two
        drop gaps and a board roof sloping down and out, with a raw hide
        nailed on it. Rows 11-31 (S), 0-21 (N), columns 10-31 (E), 0-21 (W).
  hoarding_burning (4 dirs, 4 frames of 1.2 ds, loops): the whole hoarding
        charred, with embers and flames. It replaces `hoarding`, it is not an
        overlay.
  tar_kiln (1 dir): a low daubed pine-tar kiln on a ring of stones, with a
        stoke hole, a stone channel at the front right and a small clay pot
        under it.
  tar_kiln_on (4 frames of 2 ds, loops): the kiln burning - fire in the stoke
        hole, tar running down the channel, thin dark smoke from the vent.
  pour_splash (6 frames of 1 ds, loop = 1): a liquid landing, seen from
        above: a burst, a spreading ring, droplets fading out.
  oil_slick (1 dir): an irregular puddle about 26x15px.
  falling_stone (4 frames of 1,1,1,3 ds, loop = 1): a stone dropping onto its
        shadow, the hit, and the stone lying cracked in its dust.

pour_splash and oil_slick are light greys only (every pixel r = g = b, 150 or
more) with soft half-transparent edges and no outline, because the game
tints them per liquid with `color`; `--check` enforces that, the clear centre
of the rim and the two play-once states. A state with both dirs and frames
stores all four dirs of frame 1, then frame 2, and so on. The eight
wall-opening frames keep the first row of the sheet.

Every pixel is placed by this script from a fixed palette (Pillow only); no
external or generated artwork, and nothing is random. Run it to reproduce the
sheet; `--check` verifies the committed sheet instead of writing it,
`--preview <png>` writes a 4x review sheet (with a 1x strip) of the wall
openings over the real wall sprites, and `--preview-drop <png>` writes a 4x
and 1x review sheet of the pouring and dropping states: the rim over a
darkened floor, the machicolation and hoarding on a stone wall-walk, every
animation frame, and the splash and slick in six liquid colours. Released
under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/castle_defences.dmi'
WALLS = ROOT / 'icons/turf/walls.dmi'
CLAY = ROOT / 'icons/obj/claystuff.dmi'

DIRS = ('SOUTH', 'NORTH', 'EAST', 'WEST')      # BYOND order inside a DMI

OUT = (24, 20, 18)                  # outline
GAP = (8, 7, 10)                    # the open slit, seen from outside
DEEP = (38, 34, 36)                 # deep shade inside the embrasure
SHADE = (72, 68, 66)                # embrasure floor / shaded splay
# dressed stone surround: highlight, light, mid, dark
STONE = [(226, 220, 204), (192, 186, 170), (148, 143, 131), (104, 99, 92)]
SKY = [(214, 228, 236), (150, 176, 194)]       # daylight through the slit

KEY = {
    'O': OUT, 'k': GAP, 'd': DEEP, 's': SHADE,
    'H': STONE[0], 'L': STONE[1], 'M': STONE[2], 'D': STONE[3],
    'Y': SKY[0], 'y': SKY[1],
}


class Frame:
    def __init__(self):
        self.px = {}

    def put(self, x, y, c):
        if 0 <= x < 32 and 0 <= y < 32:
            self.px[(x, y)] = c

    def rows(self, top, left, art, key=KEY):
        """Stamp ASCII art: each character is looked up in key, '.' is clear."""
        for dy, row in enumerate(art):
            for dx, ch in enumerate(row):
                if ch != '.':
                    self.put(left + dx, top + dy, key[ch])

    def mirrored(self):
        """Flip left-right, swapping the lit and shaded stone so the light
        stays at the upper left."""
        swap = {STONE[1]: STONE[2], STONE[2]: STONE[1], STONE[0]: STONE[3], STONE[3]: STONE[0]}
        f = Frame()
        for (x, y), c in self.px.items():
            f.px[(31 - x, y)] = swap.get(c, c)
        return f

    def image(self):
        im = Image.new('RGBA', (32, 32))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c + (255,))
        return im


# ------------------------------------------------------------ south (outside)

# The slit as attackers see it on the south face. Columns start at x = 11.
ARROW_FACE = [
    '..OOOOOO..',
    '..OHLLMO..',
    '..OLkkMO..',
    '..OLkkMO..',
    '..OLkkMO..',
    '..OLkkMO..',
    '..OLkkMO..',
    '..OLkkMO..',
    '..OLkkMO..',
    '..OLkkMO..',
    '..OLkkMO..',
    '..OLkkMO..',
    '..OLkkMO..',
    '.OOLkkMOO.',
    '.OLkkkkMO.',
    'OHLkkkkMDO',
    'OLLLMMMMDO',
    'OOOOOOOOOO',
]
GUN_FACE = [
    '..OOOOOO..',
    '..OHLLMO..',
    '..OLkkMO..',
    '..OLkkMO..',
    '..OLkkMO..',
    '..OLkkMO..',
    '..OLkkMO..',
    '.OOLkkMOO.',
    'OOLLkkMMOO',
    'OHLkkkkMDO',
    'OLkkkkkkDO',
    'OLkkkkkkDO',
    'OLkkkkkkDO',
    'OLMkkkkDDO',
    'OOMMDDDDOO',
    '.OOOOOOOO.',
]
# The splay behind the slit on the wall top: wide at the north (inside) edge,
# closing down to the slit. Columns start at x = 10.
TOP_SOUTH = [
    'OMssssssssDO',
    'OMssssssssDO',
    '.OMssssssDO.',
    '.OMsddddsDO.',
    '..OMddddDO..',
    '..OMddddDO..',
    '...OMddDO...',
]


def south(face):
    f = Frame()
    f.rows(0, 10, TOP_SOUTH)
    f.rows(7, 11, face)
    return f


# ------------------------------------------------------------- north (inside)

# The inner embrasure on the visible face: a wide niche whose cheeks close in
# on a slit of daylight, with a sill to stand a bow or gun on. Starts x = 9.
ARROW_NICHE = [
    'OOOOOOOOOOOOOO',
    'ODDDDDDDDDDDHO',
    'ODsddkYYkdsLHO',
    'ODsddkYYkdsLHO',
    'ODsddkYykdsLHO',
    'ODsddkYYkdsLHO',
    'ODsddkYYkdsLHO',
    'ODsddkYykdsLHO',
    'ODsddkYYkdsLHO',
    'ODsddkYYkdsLHO',
    'ODsddkYykdsLHO',
    'ODsddkYYkdsLHO',
    'ODsddkyykdsLHO',
    'ODssddkkddsLHO',
    'OMLLLLLLLLLLHO',
    'OMMMMMMMMMMMMO',
    'OOOOOOOOOOOOOO',
]
GUN_NICHE = [
    'OOOOOOOOOOOOOO',
    'ODDDDDDDDDDDHO',
    'ODsddkYYkdsLHO',
    'ODsddkYYkdsLHO',
    'ODsddkYykdsLHO',
    'ODsddkYYkdsLHO',
    'ODsddkYYkdsLHO',
    'ODsdkkYYkkdLHO',
    'ODsdkYYYYkdLHO',
    'ODsdkYYYykdLHO',
    'ODsdkYYyykdLHO',
    'ODsdkkyykkdLHO',
    'ODssddkkddsLHO',
    'OMLLLLLLLLLLHO',
    'OMMMMMMMMMMMMO',
    'OOOOOOOOOOOOOO',
]
# On the wall top the opening pinches to the slit at the north (outside) edge.
# Columns start at x = 9.
TOP_NORTH = [
    '.....OkkO.....',
    '....OMkkDO....',
    '....OMddDO....',
    '...OMddddDO...',
    '...OMddddDO...',
    '..OMsddddsDO..',
    '..OMssssssDO..',
    '.OMssssssssDO.',
]


def north(niche):
    f = Frame()
    f.rows(0, 9, TOP_NORTH)
    f.rows(8, 9, niche)
    return f


# ----------------------------------------------------------------- east/west

# Plan view across the wall top, drawn for EAST: wide on the west (inside)
# edge of the opening and pinched to the slit at the east (outside) edge.
# Columns start at x = 8; centred on the edge-on slit.
TOP_EAST = [
    'OOOOOO..............',
    'OLLLLLOOOOOO........',
    'OssssssLLLLLOOOOOO..',
    'OssssssssssdLLLLLLOO',
    'Ossssssssddddddddddd',
    'Ossssssssddddddddddd',
    'OssssssssssdMMMMMMOO',
    'OssssssMMMMMOOOOOO..',
    'OMMMMMOOOOOO........',
    'OOOOOO..............',
]
# The gun loop's splay is shorter and blunter. Columns start at x = 14.
GUN_TOP_EAST = [
    'OOOOOOOO......',
    'OLLLLLLLOOOOOO',
    'OssssssdLLLLLO',
    'Osssdddddddddd',
    'Osssdddddddddd',
    'OssssssdMMMMMO',
    'OMMMMMMMOOOOOO',
    'OOOOOOOO......',
]
# The slit seen edge-on in its jamb on the outside edge. Starts x = 27.
ARROW_EDGE = [
    'OOOOO',
    'OLkMO',
    'OLkMO',
    'OLkMO',
    'OLkMO',
    'OLkMO',
    'OLkMO',
    'OLkMO',
    'OLkMO',
    'OLkMO',
    'OLkkO',
    'OLkkO',
    'OLMMO',
    'OOOOO',
]
GUN_EDGE = [
    'OOOOO',
    'OLkMO',
    'OLkMO',
    'OLkMO',
    'OLkMO',
    'OLkMO',
    'OkkkO',
    'OkkkO',
    'OkkkO',
    'OkkkO',
    'OLMMO',
    'OOOOO',
]


def east(top, left, edge):
    f = Frame()
    f.rows(16 - len(top) // 2, left, top)
    f.rows(16 - len(edge) // 2, 27, edge)
    return f


# ===================================================== pouring and dropping
#
# Everything below is the second half of the sheet: the openings defenders
# pour and drop through, the kiln that makes the pitch, and the effects.

FLOORS = ROOT / 'icons/turf/floors.dmi'

# rough sawn timber: highlight, light, mid, dark
WOOD = [(198, 162, 114), (162, 124, 80), (126, 92, 56), (88, 62, 38)]
WOOD_SHADOW = (54, 40, 30)          # the far wall inside a gallery
HIDE = [(190, 150, 112), (156, 116, 84), (118, 84, 62)]         # raw hide
CHAR = [(84, 62, 48), (58, 44, 38), (36, 29, 27)]               # charred timber
FLAME = [(255, 244, 176), (255, 204, 64), (246, 142, 32), (204, 72, 22)]
CLAY_C = [(216, 154, 108), (186, 122, 82), (150, 92, 62), (106, 64, 46)]
TAR = (22, 18, 20)
TAR_SHINE = (92, 84, 96)
SMOKE = (50, 46, 48)
SMOKE_RIM = (98, 94, 94)
# light greyscale for the effects the game tints with `color`
GREY = [(252, 252, 252), (230, 230, 230), (202, 202, 202), (172, 172, 172)]
ROCK = [(204, 202, 196), (160, 158, 152), (118, 116, 112), (80, 78, 76)]
ROCK_OUT = (44, 42, 42)
DUST = [(202, 194, 180), (176, 165, 149), (146, 133, 117)]

# the clear opening of murder_hole_rim: columns and rows HOLE[0] .. HOLE[1]
HOLE = (6, 25)

BURN_FRAMES, BURN_DELAY = 4, '1.2'
KILN_FRAMES, KILN_DELAY = 4, '2'
SPLASH_FRAMES, SPLASH_DELAY = 6, '1'
STONE_DELAYS = ('1', '1', '1', '3')


def noise(x, y, seed):
    """A fixed 0..1 value for a pixel, so nothing here is random."""
    n = (x * 73856093) ^ (y * 19349663) ^ (seed * 83492791)
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


class Canvas(Frame):
    """A Frame whose pixels may be half transparent."""

    def over(self, x, y, c, a=255):
        """Lay colour c at alpha a over what is already there."""
        if not (0 <= x < 32 and 0 <= y < 32) or a <= 0:
            return
        a = min(255, int(a))
        old = self.px.get((x, y))
        if old is None or a == 255:
            self.px[(x, y)] = tuple(c[:3]) + (a,)
            return
        oa = old[3] if len(old) == 4 else 255
        na = a + oa * (255 - a) // 255
        rgb = tuple((c[i] * a + old[i] * oa * (255 - a) // 255) // na for i in range(3))
        self.px[(x, y)] = rgb + (na,)

    def copy(self):
        c = Canvas()
        c.px = dict(self.px)
        return c

    def flipped(self):
        """Flip left-right as drawn (no relighting)."""
        c = Canvas()
        for (x, y), v in self.px.items():
            c.px[(31 - x, y)] = v
        return c

    def image(self):
        im = Image.new('RGBA', (32, 32))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), tuple(c) if len(c) == 4 else tuple(c) + (255,))
        return im


# ------------------------------------------------------------- murder hole

def murder_hole_rim():
    """A dressed stone kerb round a square shaft. The viewer stands south of
    it and looks down, so the far (north) side of the shaft shows two rows of
    its inner face, the sides a dark lip and the near side a lit arris."""
    f = Canvas()
    lo, hi = HOLE
    tones = {'top': (3, 0, 1, 2), 'left': (3, 0, 1, 2), 'bottom': (3, 2, 1, 1), 'right': (3, 2, 2, 1)}
    joints = {'top': (10, 21), 'left': (12, 22), 'bottom': (8, 16, 24), 'right': (9, 19)}
    for y in range(32):
        for x in range(32):
            if lo <= x <= hi and lo <= y <= hi:
                continue                                    # the open shaft
            ring = min(x, y, 31 - x, 31 - y)                # 0 at the tile edge
            if y == ring and x >= ring and x <= 31 - ring:
                side = 'top'
            elif y == 31 - ring:
                side = 'bottom'
            else:
                side = 'left' if x == ring else 'right'
            if ring >= 4:                                   # the inner lip
                c = {'top': (SHADE, DEEP), 'bottom': (STONE[1], OUT),
                     'left': (OUT, DEEP), 'right': (OUT, DEEP)}[side][ring - 4]
            else:                                           # four dressed courses
                along = x if side in ('top', 'bottom') else y
                c = STONE[tones[side][ring]]
                if ring and (along in joints[side] or along in (ring, 31 - ring)):
                    c = STONE[3]                            # joints and mitres
                elif ring > 1 and c == STONE[1] and noise(x, y, 3) > 0.9:
                    c = STONE[2]                            # pitting
            f.put(x, y, c)
    return f


# ----------------------------------------------------------- machicolation

def _corbel(i):
    """Where along the edge pixel i falls: corbel pixel 0..3, or -1..-4 for
    the four pixels of the drop opening between two corbels."""
    m = i % 8
    return m - 2 if 2 <= m <= 5 else -1 - ((m - 6) % 8)


def _crenel(i):
    return i % 16 in (6, 7, 8, 9)


def machicolation_south():
    """Outside to the south: from the wall-walk outward a kerb, the corbel
    tops with the drop openings between them, the parapet top with its
    crenels, then its outer face and the corbel ends in shadow under it."""
    f = Canvas()
    for x in range(32):
        c = _corbel(x)
        f.put(x, 16, STONE[3] if c >= 0 else OUT)
        for y in range(17, 22):
            if c >= 0:
                tone = STONE[0] if y == 17 and c < 3 else STONE[2] if c == 3 else STONE[1]
            else:
                tone = SHADE if y == 17 else DEEP if y == 18 else GAP
            f.put(x, y, tone)
        f.put(x, 22, OUT)
        tones = (STONE[0], STONE[1], STONE[1], STONE[2])
        if _crenel(x):                      # through the notch, then its sill
            tones = (DEEP, STONE[3], STONE[2], STONE[2])
        elif x % 16 in (5, 10):             # the merlon's cheek
            tones = (OUT, OUT, STONE[1], STONE[2])
        elif x % 16 == 0:
            tones = (STONE[0], STONE[2], STONE[2], STONE[2])
        for y, tone in zip(range(23, 27), tones):
            f.put(x, y, tone)
        for y in (27, 28):
            f.put(x, y, STONE[3] if (x + (4 if y == 28 else 0)) % 8 == 0 else STONE[2])
        f.put(x, 29, STONE[3])
        f.put(x, 30, GAP if c < 0 else STONE[3] if c == 3 else STONE[2])
        f.put(x, 31, STONE[3] if c in (1, 2) else GAP)
    return f


def machicolation_north():
    """Outside to the north: the parapet top along the far edge, its inner
    face toward the viewer, and the corbels and openings at its foot."""
    f = Canvas()
    for x in range(32):
        c = _corbel(x)
        f.put(x, 0, OUT)
        tones = (STONE[0], STONE[1], STONE[1], STONE[3])
        if _crenel(x):
            tones = (DEEP, DEEP, STONE[3], STONE[2])
        elif x % 16 in (5, 10):
            tones = (OUT, OUT, OUT, STONE[3])
        elif x % 16 == 0:
            tones = (STONE[0], STONE[2], STONE[2], STONE[3])
        for y, tone in zip(range(1, 5), tones):
            f.put(x, y, tone)
        for y in range(5, 9):
            brick = (x + (4 if y >= 7 else 0)) % 8 == 0
            f.put(x, y, STONE[3] if brick  else STONE[2])
        f.put(x, 9, OUT)
        for y in range(10, 15):
            if c >= 0:
                tone = STONE[0] if y == 10 and c < 3 else STONE[2] if c == 3 else STONE[1]
            else:
                tone = SHADE if y == 10 else DEEP if y == 11 else GAP
            f.put(x, y, tone)
        f.put(x, 15, STONE[3] if c >= 0 else OUT)
    return f


def machicolation_east():
    """Outside to the east, in plan: kerb, corbels and openings, then the
    parapet top down the east edge. Each merlon shows two rows of its south
    side above the sunk sill of the crenel below it."""
    f = Canvas()
    for y in range(32):
        c = _corbel(y)
        f.put(16, y, STONE[3] if c >= 0 else OUT)
        for x in range(17, 22):
            if c >= 0:
                tone = STONE[0] if c == 0 and x < 21 else STONE[2] if c == 3 else STONE[1]
            else:
                tone = SHADE if c == -1 else DEEP if c == -2 else GAP
            f.put(x, y, tone)
        f.put(22, y, OUT)
        m = y % 16
        for x, tone in zip(range(23, 31), (STONE[0], STONE[1], STONE[1], STONE[1], STONE[1],
                                           STONE[2], STONE[2], STONE[3])):
            if m in (6, 7):
                tone = STONE[3] if m == 6 or x >= 28 else STONE[2]      # merlon side
            elif m in (8, 9):
                tone = STONE[2] if x < 29 else STONE[3]
            elif m == 10 and x < 30:
                tone = STONE[0]
            elif m == 0 and 24 <= x <= 28:
                tone = STONE[2]
            f.put(x, y, tone)
        f.put(31, y, OUT)
        if m in (6, 7, 8, 9):
            f.put(30, y, DEEP)
    return f


# ----------------------------------------------------------------- hoarding

def _wood(tone, along, across, seed):
    """Saw marks: the tone wanders in short streaks along the board."""
    n = noise(along // 3, across, seed)
    if n < 0.16:
        tone += 1
    elif n > 0.9:
        tone -= 1
    return WOOD[max(0, min(3, tone))]


# the board roof: three overlapping courses from the high inner edge down to
# the eave, each a lit top edge, a body and the shadow under its lower edge
ROOF = ((0, 0), (0, 1), (0, 1), (0, 1), (0, 3),
        (1, 1), (1, 2), (1, 2), (1, 3),
        (2, 2), (2, 2), (2, 3))             # (course, tone) per pixel of slope
ROOF_JOINT = (0, 3, 1)                      # where each course butts its boards


def _roof(i, along):
    """Colour of roof pixel i down the slope, `along` the gallery."""
    course, tone = ROOF[min(i, len(ROOF) - 1)]
    lead = i == 0 or ROOF[i - 1][0] != course
    if tone < 3 and not lead and along % 6 == ROOF_JOINT[course]:
        return WOOD[3]
    return _wood(tone, along, i, 4)


def _hide(f, x0, y0, w, h):
    """A raw hide nailed over the roof boards against fire arrows."""
    for y in range(h):
        for x in range(w):
            edge = x in (0, w - 1) or y in (0, h - 1)
            if edge and (x in (0, w - 1)) and (y in (0, h - 1)):
                continue
            if edge and noise(x0 + x, y0 + y, 21) < 0.3:
                continue
            tone = 2 if edge else 0 if (x + y < (w + h) // 2 - 2 and noise(x, y, 5) > 0.35) else 1
            f.put(x0 + x, y0 + y, HIDE[tone])
    for x, y in ((1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)):
        f.put(x0 + x, y0 + y, OUT)


def _gap(i):
    return i % 16 in (8, 9, 10, 11)


def hoarding_south():
    """Outside to the south: a sill beam on the wall-walk, the plank floor of
    the gallery with two drop gaps, then the board roof sloping down and out."""
    f = Canvas()
    for x in range(32):
        f.put(x, 11, OUT)
        f.put(x, 12, _wood(1, x, 12, 1))
        f.put(x, 13, WOOD[3] if x % 8 == 7 else _wood(2, x, 13, 1))
        for y in range(14, 19):
            if _gap(x):
                tone = WOOD[3] if y == 14 else DEEP if y == 15 else GAP
            elif x % 4 == 3:
                tone = WOOD[3]
            else:
                tone = _wood(1 if (x // 4) % 2 else 2, y, x, 2)
            f.put(x, y, tone)
        f.put(x, 19, OUT)
        for y in range(20, 31):
            f.put(x, y, _roof(y - 20 + 1 if y > 20 else 0, x))
        f.put(x, 31, OUT)
    _hide(f, 17, 21, 10, 8)
    return f


def hoarding_north():
    """Outside to the north: the roof falls away from the viewer, and under
    its eave beam the open inner side shows the posts, the dark gallery and
    its plank floor with the drop gaps."""
    f = Canvas()
    for x in range(32):
        f.put(x, 0, OUT)
        for y, i in zip(range(1, 7), (10, 9, 5, 4, 2, 0)):
            f.put(x, y, _roof(i, x))
        f.put(x, 7, OUT)
        f.put(x, 8, _wood(1, x, 8, 1))
        f.put(x, 9, WOOD[3])
        post = x % 16 in (3, 4)
        for y in range(10, 14):
            if post:
                f.put(x, y, WOOD[1] if x % 16 == 3 else WOOD[2])
            else:
                f.put(x, y, DEEP if x % 4 == 1 or y == 10 else WOOD_SHADOW)
        for y in range(14, 19):
            if _gap(x):
                tone = DEEP if y == 14 else GAP
            elif x % 4 == 3:
                tone = WOOD[3]
            else:
                tone = _wood(1 if (x // 4) % 2 else 2, y, x, 2)
            f.put(x, y, tone)
        f.put(x, 19, _wood(1, x, 19, 1))
        f.put(x, 20, WOOD[3] if x % 8 == 7 else _wood(2, x, 20, 1))
        f.put(x, 21, OUT)
    _hide(f, 18, 1, 9, 5)
    return f


def hoarding_east():
    """Outside to the east, in plan: sill beam, plank floor with two drop
    gaps, and the board roof sloping down toward the east edge."""
    f = Canvas()
    for y in range(32):
        f.put(10, y, OUT)
        f.put(11, y, _wood(1, y, 11, 1))
        f.put(12, y, WOOD[3] if y % 8 == 7 else _wood(2, y, 12, 1))
        for x in range(13, 18):
            if _gap(y):
                tone = WOOD[3] if y % 16 == 8 else DEEP if y % 16 == 9 else GAP
            elif y % 4 == 3:
                tone = WOOD[3]
            else:
                tone = _wood(1 if (y // 4) % 2 else 2, x, y, 2)
            f.put(x, y, tone)
        f.put(18, y, OUT)
        for x in range(19, 31):
            f.put(x, y, _roof(x - 19, y))
        f.put(31, y, OUT)
    _hide(f, 20, 17, 8, 10)
    return f


def _flame(f, bx, by, height, lean, width):
    """One tongue of flame rising from (bx, by)."""
    for dy in range(height + 1):
        t = dy / float(height)
        half = width * (1.0 - t) ** 0.8 * min(1.0, 0.45 + t * 3.0)
        cx = bx + lean * t * t
        for x in range(int(cx - half - 1), int(cx + half + 2)):
            d = abs(x - cx)
            if d > half + 0.25:
                continue
            core = 1.0 - d / (half + 0.5)
            heat = core * (1.0 - t * 0.85)
            tone = 0 if heat > 0.62 else 1 if heat > 0.4 else 2 if heat > 0.18 else 3
            f.put(x, by - dy, FLAME[tone])


def burning(base, frame, vertical):
    """A hoarding well alight: the timber chars, embers creep along the
    boards and flames stand up from it. vertical = the gallery runs north to
    south (EAST / WEST facings)."""
    f = Canvas()
    box = [min(x for x, _ in base.px), min(y for _, y in base.px),
           max(x for x, _ in base.px), max(y for _, y in base.px)]
    for (x, y), c in base.px.items():
        if c in (OUT, GAP, DEEP):
            f.px[(x, y)] = c
            continue
        n = noise(x // 2, y // 2, 31)
        lum = sum(c) // 3
        if n < 0.62:
            c = CHAR[0 if lum > 130 else 1 if lum > 90 else 2]
        else:
            c = tuple(v * 2 // 3 for v in c)
        e = noise(x, y, 40 + (frame + x + y) % BURN_FRAMES)
        if n < 0.62 and e > 0.9:
            c = FLAME[2] if e > 0.95 else FLAME[3]
        f.px[(x, y)] = c
    # tongues: (place along the gallery, across it, height, width, phase)
    tongues = ((3, 0.55, 9, 2.4, 0), (9, 0.2, 6, 1.8, 2), (15, 0.7, 11, 2.8, 1),
               (21, 0.35, 7, 2.0, 3), (27, 0.6, 10, 2.5, 2), (30, 0.15, 5, 1.5, 0))
    order = []
    for along, across, height, width, phase in tongues:
        k = (frame + phase) % BURN_FRAMES
        height += (0, 2, 1, -1)[k]
        lean = (-1.5, 0.5, 1.5, -0.5)[k]
        if vertical:
            bx = box[0] + across * (box[2] - box[0])
            by = min(31, along + 3)
        else:
            bx = along
            by = box[1] + (0.35 + across * 0.65) * (box[3] - box[1])
        order.append((by, bx, height, lean, width))
    for by, bx, height, lean, width in sorted(order):
        _flame(f, int(round(bx)), int(round(by)), height, lean, width)
    return f


# ----------------------------------------------------------------- tar kiln

KILN_KEY = {
    'O': OUT, 'h': CLAY_C[0], 'l': CLAY_C[1], 'm': CLAY_C[2], 'd': CLAY_C[3],
    'S': STONE[1], 's': STONE[2], 'D': STONE[3], 'k': GAP, 'e': DEEP,
    't': TAR, 'T': TAR_SHINE, 'H': STONE[0],
}
# A low daubed dome on a ring of stones: a smoke vent in the crown, the stoke
# hole at the front left and, at the front right, a stone channel that leads
# the tar down into a small clay pot. Columns start at x = 3, rows at y = 13.
KILN = [
    '.........OOOO.............',
    '.......OOhkklOO...........',
    '.....OOhhhlllllOO.........',
    '....OhhhhlllllmmmO........',
    '...OhhhlllllllmmmmO.......',
    '..OhhhllllllllmmmmmO......',
    '..OhhlllllllllmmmmdO......',
    '.OhhllOOOOlllmmmmmddO.....',
    '.OhllOkkkkOllmmmmmddO.....',
    '.OlllOkeekOlmmmmmdddO.....',
    '.OllmOkeekOmmmmmddOOOO....',
    'OSSsDOkeekOSSsDSSOStSsO...',
    'OSssDOeeeeOSssDSsDOStSsO..',
    '.OOOOOOOOOOOOOOOOOOOStSO..',
    '....................OtOOO.',
    '...................OmTtmO.',
    '...................OlmmdO.',
    '....................OmdO..',
    '.....................OO...',
]
KILN_AT = (3, 12)
STOKE = [(x, y) for y in range(8, 13) for x in range(6, 10)]   # in KILN cells
VENT = (KILN_AT[0] + 10, KILN_AT[1] + 1)


def _ground_shadow(f, cx, cy, rx, ry, alpha):
    for y in range(32):
        for x in range(32):
            if (x, y) not in f.px and ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                f.over(x, y, (0, 0, 0), alpha)


def tar_kiln(frame=None):
    f = Canvas()
    f.rows(KILN_AT[1], KILN_AT[0], KILN, KILN_KEY)
    # daub cracks
    for x, y in ((9, 16), (10, 17), (10, 18), (16, 15), (17, 16), (14, 20), (6, 18)):
        if f.px.get((x, y)) in CLAY_C:
            f.put(x, y, CLAY_C[3])
    _ground_shadow(f, 16, 25, 14, 3.2, 70)
    _ground_shadow(f, 25, 30, 4.5, 1.6, 70)
    if frame is None:
        return f
    # fire in the stoke hole
    for cx, cy in STOKE:
        x, y = KILN_AT[0] + cx, KILN_AT[1] + cy
        n = noise(cx, cy, 60 + frame)
        depth = cy - 8
        if depth == 0:
            tone = 3 if n > 0.4 else None
        elif depth == 4:
            tone = 1 if n > 0.35 else 2
        else:
            tone = (3, 2, 1, 0)[min(3, depth + (1 if n > 0.55 else 0))]
        if tone is not None:
            f.put(x, y, FLAME[tone])
    # the glow on the daub round the hole and on the ground in front
    for x, y in ((8, 18), (13, 18), (8, 20), (13, 20), (8, 22), (13, 22)):
        if (x + y + frame) % 2 == 0 and f.px.get((x, y)) == OUT:
            f.put(x, y, FLAME[3])
    for x in range(8, 14):
        f.over(x, 26, FLAME[2], 90 if (x + frame) % 2 else 50)
    # the vent glows and the tar runs
    f.put(VENT[0], VENT[1], FLAME[3] if frame % 2 else FLAME[2])
    f.put(VENT[0] + 1, VENT[1], FLAME[2] if frame % 2 else FLAME[3])
    drip = ((24, 23), (24, 24), (24, 25), (24, 26))[frame]
    f.put(drip[0], drip[1], TAR_SHINE)
    # thin dark smoke: three puffs a third of a loop apart, so frame 4 runs
    # back into frame 1
    for k in range(3):
        p = (frame / float(KILN_FRAMES) + k / 3.0) % 1.0
        sx = VENT[0] + 0.5 + 2.2 * p * math.sin(2 * math.pi * (p * 0.75 + k / 3.0))
        sy = VENT[1] - 1 - p * 11.0
        r = 1.3 + p * 2.0
        for y in range(int(sy - r - 1), int(sy + r + 2)):
            for x in range(int(sx - r - 1), int(sx + r + 2)):
                d = ((x - sx) ** 2 + (y - sy) ** 2) ** 0.5
                if d <= r and y < VENT[1]:
                    rim = d > r - 0.8
                    f.over(x, y, SMOKE_RIM if rim else SMOKE, (245 - 150 * p) * (0.7 if rim else 1.0))
    return f


# ------------------------------------------------------- splash and slick

def _grey(dx, dy, r):
    """Tone of a blob pixel lit from the upper left."""
    lit = -(dx + dy) / (r * 1.4142 + 0.01)
    return GREY[0 if lit > 0.3 else 1 if lit > -0.25 else 2 if lit > -0.7 else 3]


def _blob(f, cx, cy, r, alpha):
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            dx, dy = x - cx, (y - cy) / 0.8
            d = (dx * dx + dy * dy) ** 0.5
            if d <= r:
                f.over(x, y, _grey(dx, dy, r), alpha * (0.55 if d > r - 0.7 and r > 1.2 else 1.0))


SPLASH_C = (15.5, 17.0)
# per frame: pool radius, ring radius, ring thickness, ring alpha, how much
# of the ring has broken up, droplet distance, droplet radius, droplet alpha
SPLASH = (
    (3.6, 0.0, 0.0, 0, 0.0, 5.5, 1.3, 235),
    (2.4, 6.0, 2.6, 235, 0.0, 9.0, 1.5, 230),
    (1.2, 8.8, 2.0, 215, 0.12, 11.5, 1.4, 215),
    (0.0, 11.0, 1.5, 170, 0.4, 13.0, 1.2, 180),
    (0.0, 12.2, 1.2, 110, 0.68, 14.0, 1.0, 130),
    (0.0, 13.0, 1.0, 60, 0.86, 14.6, 0.8, 70),
)


def pour_splash(frame):
    """From above: the liquid lands, throws up a crown that spreads as a
    ring, and the flung droplets carry on outward and fade."""
    pool, ring, thick, ring_a, holes, reach, drop_r, drop_a = SPLASH[frame]
    f = Canvas()
    cx, cy = SPLASH_C
    if ring:
        for y in range(32):
            for x in range(32):
                dx, dy = x - cx, (y - cy) / 0.8
                d = (dx * dx + dy * dy) ** 0.5
                off = abs(d - ring)
                if off > thick / 2.0 or noise(x // 2, y // 2, 70) < holes:
                    continue
                f.over(x, y, _grey(dx, dy, ring), ring_a * (0.55 if off > thick / 2.0 - 0.6 else 1.0))
    if pool:
        _blob(f, cx, cy, pool, 240)
    for i in range(12):
        ang = math.radians(i * 30 + 28 * noise(i, 1, 71) - 6)
        far = reach * (0.82 + 0.3 * noise(i, 2, 72))
        r = drop_r * (0.65 + 0.6 * noise(i, 3, 73))
        if frame >= 3 and noise(i, frame, 74) < 0.18 * (frame - 2):
            continue
        _blob(f, cx + math.cos(ang) * far, cy + math.sin(ang) * far * 0.8, r, drop_a)
        if frame in (0, 1):                 # the streak behind a flung drop
            _blob(f, cx + math.cos(ang) * far * 0.72, cy + math.sin(ang) * far * 0.8 * 0.72,
                  r * 0.7, drop_a * 0.8)
    return f


# the slick is a union of flattened discs: (centre x, centre y, rx, ry)
SLICK = ((15.5, 18.5, 9.5, 6.0), (21.5, 16.0, 6.0, 4.6), (9.0, 21.5, 5.2, 3.6),
         (20.5, 22.5, 6.2, 3.6), (11.5, 14.5, 5.0, 3.4), (25.5, 20.0, 2.6, 2.2))
SLICK_DROPS = ((5, 15), (27, 25), (4, 24), (28, 13))


def oil_slick():
    f = Canvas()
    for y in range(32):
        for x in range(32):
            depth = max(1.0 - (((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2) ** 0.5
                        for cx, cy, rx, ry in SLICK)
            if depth <= 0.0:
                continue
            # a pale rim where the film is thin, a darker lower lip, and
            # sheen streaks toward the upper left
            below = max(1.0 - (((x - cx) / rx) ** 2 + ((y + 1 - cy) / ry) ** 2) ** 0.5
                        for cx, cy, rx, ry in SLICK) <= 0.0
            streak = (x + 2 * y) % 11 in (0, 1) and noise(x // 4, y // 2, 80) > 0.35 and depth > 0.3
            if depth < 0.14:
                tone, alpha = (3 if below else 1), 125
            elif depth < 0.3:
                tone, alpha = (3 if below else 1), 180
            else:
                pale = noise(x // 3, y // 2, 81) > 0.55 and not below
                tone, alpha = (0 if streak else 1 if pale else 2), 210
            f.over(x, y, GREY[tone], alpha)
    for x, y in SLICK_DROPS:
        f.over(x, y, GREY[1], 170)
        f.over(x + 1, y, GREY[2], 130)
    return f


# ------------------------------------------------------------ falling stone

ROCK_KEY = {'O': ROCK_OUT, 'h': ROCK[0], 'l': ROCK[1], 'm': ROCK[2], 'd': ROCK[3]}
BOULDER = [
    '...OOOO...',
    '.OOhhllOO.',
    'OhhhllllmO',
    'OhhllllmmO',
    'OhllllmmmO',
    'OlllmmmmdO',
    'OllmmmmddO',
    '.OmmmdddO.',
    '..OOOOOO..',
]
BOULDER_LANDED = [
    '...OOOO...',
    '.OOhhllOO.',
    'OhhhlOllmO',
    'OhhllOlmmO',
    'OhlllmOmmO',
    'OlllmmOmdO',
    'OOmmmmdOOO',
]
STONE_GROUND = 27       # the row the stone comes to rest on


def falling_stone(frame):
    """A stone dropped from the level above: two frames in the air over its
    growing shadow, the hit, and the stone lying cracked in its dust."""
    f = Canvas()
    top = (0, 9, 18, 20)[frame]
    for y in range(32):                                     # the shadow
        for x in range(32):
            rx = (2.5, 4.0, 5.5, 5.5)[frame]
            if ((x - 15.5) / rx) ** 2 + ((y - 27.0) / (rx * 0.4)) ** 2 <= 1.0:
                f.over(x, y, (0, 0, 0), (50, 75, 100, 100)[frame])
    if frame < 2:                                           # speed streaks
        for x, n in ((12, 4), (15, 6), (18, 5), (20, 3)):
            for i in range(n):
                f.over(x, top - 1 - i, ROCK[1], 150 - i * 26)
    if frame >= 2:
        # dust thrown out along the ground on both sides
        spread, alpha = ((4.0, 215), (8.0, 150))[frame - 2]
        for side in (-1, 1):
            for k, (far, up, r) in enumerate(((1.0, 0.0, 2.6), (0.6, 2.5, 2.0), (1.45, 1.0, 1.8))):
                px_, py_ = 15.5 + side * (4.5 + far * spread), 26.5 - up * (frame - 1) * 0.9
                r = r + (frame - 2) * 0.9
                for y in range(int(py_ - r - 1), int(py_ + r + 2)):
                    for x in range(int(px_ - r - 1), int(px_ + r + 2)):
                        d = ((x - px_) ** 2 + (y - py_) ** 2) ** 0.5
                        if d > r or (frame == 3 and noise(x, y, 90) < 0.22):
                            continue
                        lit = -((x - px_) + (y - py_)) / (r * 1.4142)
                        tone = 0 if lit > 0.3 else 1 if lit > -0.4 else 2
                        f.over(x, y, DUST[tone], alpha * (0.6 if d > r - 0.8 else 1.0))
    art = BOULDER if frame < 3 else BOULDER_LANDED
    sprite = Canvas()
    sprite.rows(top, 11, art, ROCK_KEY)
    for (x, y), c in sprite.px.items():
        f.px[(x, y)] = c
    if frame == 2:                                          # chips flying
        for x, y in ((8, 19), (23, 20), (10, 16), (22, 16), (15, 15)):
            f.put(x, y, ROCK[1])
            f.put(x, y + 1, ROCK[3])
    if frame == 3:
        for x, y in ((8, 26), (9, 27), (23, 27), (24, 26)):
            f.put(x, y, ROCK[2])
    return f


# ------------------------------------------------------------------- sheet

def states():
    """The wall openings: name -> the four facings in DMI order."""
    out = {}
    for name, face, niche, top, left, edge in (
            ('arrow_slit', ARROW_FACE, ARROW_NICHE, TOP_EAST, 8, ARROW_EDGE),
            ('gun_loop', GUN_FACE, GUN_NICHE, GUN_TOP_EAST, 14, GUN_EDGE)):
        e = east(top, left, edge)
        out[name] = [south(face), north(niche), e, e.mirrored()]
    return out


def facings(south_f, north_f, east_f):
    return [south_f, north_f, east_f, east_f.flipped()]


def all_states():
    """Every state of the sheet as (name, DMI keys, frames). A state with
    both dirs and frames lists all its dirs for frame 1, then frame 2 ..."""
    out = [(name, {'dirs': 4, 'frames': 1}, group) for name, group in states().items()]
    mach = facings(machicolation_south(), machicolation_north(), machicolation_east())
    hoard = facings(hoarding_south(), hoarding_north(), hoarding_east())
    out.append(('murder_hole_rim', {'dirs': 1, 'frames': 1}, [murder_hole_rim()]))
    out.append(('machicolation', {'dirs': 4, 'frames': 1}, mach))
    out.append(('hoarding', {'dirs': 4, 'frames': 1}, hoard))
    out.append(('hoarding_burning',
                {'dirs': 4, 'frames': BURN_FRAMES, 'delay': ','.join([BURN_DELAY] * BURN_FRAMES)},
                [burning(hoard[d], fr, d >= 2) for fr in range(BURN_FRAMES) for d in range(4)]))
    out.append(('tar_kiln', {'dirs': 1, 'frames': 1}, [tar_kiln()]))
    out.append(('tar_kiln_on',
                {'dirs': 1, 'frames': KILN_FRAMES, 'delay': ','.join([KILN_DELAY] * KILN_FRAMES)},
                [tar_kiln(fr) for fr in range(KILN_FRAMES)]))
    out.append(('pour_splash',
                {'dirs': 1, 'frames': SPLASH_FRAMES,
                 'delay': ','.join([SPLASH_DELAY] * SPLASH_FRAMES), 'loop': 1},
                [pour_splash(fr) for fr in range(SPLASH_FRAMES)]))
    out.append(('oil_slick', {'dirs': 1, 'frames': 1}, [oil_slick()]))
    out.append(('falling_stone',
                {'dirs': 1, 'frames': len(STONE_DELAYS), 'delay': ','.join(STONE_DELAYS), 'loop': 1},
                [falling_stone(fr) for fr in range(len(STONE_DELAYS))]))
    return out


SHEET_COLS = 8      # the eight wall-opening frames keep the first row


def build_sheet(st):
    frames = [fr for _, _, group in st for fr in group]
    rows = (len(frames) + SHEET_COLS - 1) // SHEET_COLS
    sheet = Image.new('RGBA', (32 * SHEET_COLS, 32 * rows), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(fr.image(), ((i % SHEET_COLS) * 32, (i // SHEET_COLS) * 32))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, keys, group in st:
        assert len(group) == keys['dirs'] * keys['frames'], name
        text += 'state = "%s"\n' % name
        for key, value in keys.items():
            text += '\t%s = %s\n' % (key, value)
    text += '# END DMI\n'
    return sheet, text


def write_dmi(path, st):
    sheet, text = build_sheet(st)
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta)


def check_drawing(st):
    """The promises the game code relies on."""
    problems = []
    by_name = {name: (keys, group) for name, keys, group in st}
    rim = by_name['murder_hole_rim'][1][0].image().getchannel('A')
    lo, hi = HOLE
    for y in range(32):
        for x in range(32):
            inside = lo <= x <= hi and lo <= y <= hi
            if inside != (rim.getpixel((x, y)) == 0):
                problems.append('murder_hole_rim: (%d,%d) is %s' % (x, y, 'filled' if inside else 'clear'))
    for name in ('pour_splash', 'oil_slick'):
        for n, fr in enumerate(by_name[name][1]):
            for (x, y), c in fr.px.items():
                if not (c[0] == c[1] == c[2] and c[0] >= 150):
                    problems.append('%s frame %d: (%d,%d) %s is not a light grey' % (name, n + 1, x, y, c))
    for name in ('pour_splash', 'falling_stone'):
        if by_name[name][0].get('loop') != 1:
            problems.append('%s must play once' % name)
    return problems[:20]


def check(path, st):
    problems = check_drawing(st)
    if problems:
        sys.exit('\n'.join(problems))
    sheet, text = build_sheet(st)
    old = Image.open(path)
    if old.info.get('Description') != text:
        sys.exit('%s: state list differs from the generator' % path)
    if old.size != sheet.size or ImageChops.difference(old.convert('RGBA'), sheet).getbbox():
        sys.exit('%s: pixels differ from the generator' % path)
    if old.convert('RGBA').tobytes() != sheet.tobytes():
        sys.exit('%s: pixels differ from the generator' % path)
    print('%s matches the generator' % path)


def wall_frame(path, name):
    """The first frame (SOUTH dir) of a state of a wall sheet."""
    im = Image.open(path)
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
    per_row = im.width // 32
    x, y = (found % per_row) * 32, (found // per_row) * 32
    return im.convert('RGBA').crop((x, y, x + 32, y + 32))


# (label, covers type, sheet, icon_state). Joining walls are shown as the
# lone piece (0), an east-west run (12) and a north-south run (3).
PREVIEW_WALLS = [
    ('rough stone', '/obj/covers/stone_wall', WALLS, 'b_stone_wall'),
    ('stone block, lone', '/obj/covers/stone_wall/classic', WALLS, 'stone_block_wall0'),
    ('stone block, E-W run', '/obj/covers/stone_wall/classic', WALLS, 'stone_block_wall12'),
    ('stone block, N-S run', '/obj/covers/stone_wall/classic', WALLS, 'stone_block_wall3'),
    ('stone brick, lone', '/obj/covers/stone_wall/brick', WALLS, 'new_stonebrick0'),
    ('stone brick, E-W run', '/obj/covers/stone_wall/brick', WALLS, 'new_stonebrick12'),
    ('stone brick, N-S run', '/obj/covers/stone_wall/brick', WALLS, 'new_stonebrick3'),
    ('fortress, lone', '/obj/covers/stone_wall/fortress', WALLS, 'fortress_brickwall0'),
    ('fortress, E-W run', '/obj/covers/stone_wall/fortress', WALLS, 'fortress_brickwall12'),
    ('fortress, N-S run', '/obj/covers/stone_wall/fortress', WALLS, 'fortress_brickwall3'),
    ('sandstone block, lone', '/obj/covers/sandstone_wall/classic', WALLS, 'sandstone_block_wall0'),
    ('sandstone block, E-W run', '/obj/covers/sandstone_wall/classic', WALLS, 'sandstone_block_wall12'),
    ('sandstone block, N-S run', '/obj/covers/sandstone_wall/classic', WALLS, 'sandstone_block_wall3'),
    ('log wall', '/obj/covers/wood_wall/log', WALLS, 'log_wall'),
    ('clay block wall', '/obj/covers/clay_wall', CLAY, 'claybrickwall'),
]


def preview(path, st, scale=4):
    ground = (86, 120, 60)
    cell, pad, head = 32 * scale, 6, 30
    left = 236
    cols = [(name, d) for name in st for d in range(4)]
    strip = len(cols) * 40 + pad
    width = left + len(cols) * (cell + pad) + strip
    row_h = cell + pad
    height = head + len(PREVIEW_WALLS) * row_h + 34
    sheet = Image.new('RGBA', (width, height), (40, 40, 44, 255))
    draw = ImageDraw.Draw(sheet)
    for c, (name, d) in enumerate(cols):
        x = left + c * (cell + pad)
        draw.text((x, 2), name, fill=(230, 230, 230))
        draw.text((x, 14), '%s = outside' % DIRS[d], fill=(170, 200, 230))
    draw.text((left + len(cols) * (cell + pad), 2), '1x (game scale), same order', fill=(230, 230, 230))
    for r, (label, typepath, src, state) in enumerate(PREVIEW_WALLS):
        y = head + r * row_h
        draw.text((4, y + cell // 2 - 18), label, fill=(230, 230, 230))
        draw.text((4, y + cell // 2 - 6), typepath, fill=(170, 170, 170))
        draw.text((4, y + cell // 2 + 6), '%s : %s' % (src.name, state), fill=(130, 130, 130))
        wall = wall_frame(src, state)
        for c, (name, d) in enumerate(cols):
            tile = Image.new('RGBA', (32, 32), ground + (255,))
            tile.alpha_composite(wall)
            tile.alpha_composite(st[name][d].image())
            sheet.paste(tile.resize((cell, cell), Image.NEAREST), (left + c * (cell + pad), y))
            sheet.paste(tile, (left + len(cols) * (cell + pad) + c * 40, y + cell // 2 - 16))
    draw.text((4, height - 30), 'The dir is the outside face (attackers). The wedge is wide on the '
              'defenders\' side and its point is the outside.', fill=(200, 200, 200))
    draw.text((4, height - 16), 'S: narrow slit on the visible face.  N: wide inner embrasure with '
              'daylight.  E/W: plan wedge across the wall top to an edge-on slit.', fill=(200, 200, 200))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


# ---------------------------------------------- pouring and dropping preview

# the six liquids the game tints pour_splash and oil_slick with
LIQUIDS = (('water', (96, 152, 222)), ('oil', (206, 146, 44)), ('pitch', (44, 40, 40)),
           ('sand', (216, 188, 132)), ('lime', (246, 246, 238)), ('lead', (178, 184, 192)))


def tinted(im, colour):
    """What BYOND's `color` does to an icon: multiply each channel."""
    r, g, b, a = im.split()
    return Image.merge('RGBA', [band.point(lambda v, c=c: v * c // 255)
                                for band, c in zip((r, g, b), colour)] + [a])


def darkened(im, keep=0.42):
    r, g, b, a = im.split()
    return Image.merge('RGBA', [band.point(lambda v: int(v * keep)) for band in (r, g, b)] + [a])


def scene(w, h, tile):
    im = Image.new('RGBA', (32 * w, 32 * h))
    for ty in range(h):
        for tx in range(w):
            im.paste(tile, (tx * 32, ty * 32))
    return im


def preview_drop(path, st, scale=4):
    by = {name: [fr.image() for fr in group] for name, keys, group in st}
    floor = wall_frame(FLOORS, 'stone_bricks')
    cobble = wall_frame(FLOORS, 'cobble_horizontal')
    dirt = wall_frame(FLOORS, 'dirt')
    grass = wall_frame(FLOORS, 'grass0')

    def on(tile, *layers):
        im = tile.copy()
        for layer in layers:
            im.alpha_composite(layer)
        return im

    rows = []

    # the rim over the darkened level below
    hole = scene(3, 3, floor)
    hole.paste(on(darkened(cobble), by['murder_hole_rim'][0]), (32, 32))
    hole2 = scene(3, 3, cobble)
    hole2.paste(on(darkened(grass), by['murder_hole_rim'][0]), (32, 32))
    magenta = Image.new('RGBA', (32, 32), (255, 0, 255, 255))
    rows.append(('murder_hole_rim: the clear centre is x %d-%d, y %d-%d from the top left' % (HOLE * 2), [
        ('in a stone floor, cobbles below', hole), ('in cobbles, grass below', hole2),
        ('clear = magenta', on(magenta, by['murder_hole_rim'][0])),
        ('dark floor', on(darkened(floor), by['murder_hole_rim'][0]))]))

    # machicolation and hoarding: each facing alone, then round a tower top
    for name in ('machicolation', 'hoarding'):
        cells = [('%s = outside' % DIRS[d], on(floor, by[name][d])) for d in range(4)]
        top = scene(5, 5, grass)
        for tx in range(1, 4):
            for ty in range(1, 4):
                top.paste(floor, (tx * 32, ty * 32))
            top.alpha_composite(by[name][1], (tx * 32, 32))
            top.alpha_composite(by[name][0], (tx * 32, 96))
        top.alpha_composite(by[name][3], (32, 64))       # there is no corner piece
        top.alpha_composite(by[name][2], (96, 64))
        run = scene(3, 1, floor)
        for tx in range(3):
            run.alpha_composite(by[name][0], (tx * 32, 0))
        cells += [('SOUTH run of 3', run), ('all four round a 3x3 wall-walk', top)]
        rows.append((name + ' on a stone wall-walk', cells))

    for d0 in (0, 2):
        rows.append(('hoarding_burning, 4 frames of %s ds' % BURN_DELAY, [
            ('%s frame %d' % (DIRS[d], fr + 1), on(floor, by['hoarding_burning'][fr * 4 + d]))
            for d in (d0, d0 + 1) for fr in range(BURN_FRAMES)]))

    rows.append(('tar_kiln, tar_kiln_on (4 frames of %s ds) and falling_stone (delays %s, plays once)'
                 % (KILN_DELAY, ','.join(STONE_DELAYS)),
                 [('tar_kiln', on(dirt, by['tar_kiln'][0])), ('on grass', on(grass, by['tar_kiln'][0]))]
                 + [('on, frame %d' % (i + 1), on(dirt if i % 2 == 0 else grass, im))
                    for i, im in enumerate(by['tar_kiln_on'])]
                 + [('stone, frame %d' % (i + 1), on(cobble if i % 2 == 0 else grass, im))
                    for i, im in enumerate(by['falling_stone'])]))

    rows.append(('pour_splash (6 frames of %s ds, plays once) and oil_slick, untinted' % SPLASH_DELAY,
                 [('splash %d' % (i + 1), on(cobble, im)) for i, im in enumerate(by['pour_splash'])]
                 + [('oil_slick', on(cobble, by['oil_slick'][0])),
                    ('slick on grass', on(grass, by['oil_slick'][0])),
                    ('slick on dirt', on(dirt, by['oil_slick'][0]))]))
    for i in range(0, len(LIQUIDS), 2):
        cells = []
        for label, colour in LIQUIDS[i:i + 2]:
            ground = cobble if label not in ('lime', 'lead') else dirt
            cells += [('%s %d' % (label, n + 1), on(ground, tinted(im, colour)))
                      for n, im in enumerate(by['pour_splash'])]
            cells.append(('%s slick' % label, on(ground, tinted(by['oil_slick'][0], colour))))
        rows.append(('tinted with color: ' + ', '.join('%s rgb%s' % lc for lc in LIQUIDS[i:i + 2]), cells))

    pad, head, label_h = 8, 18, 14
    width = max(sum(im.width * scale + pad for _, im in cells) for _, cells in rows) + pad
    height = sum(head + label_h + max(im.height for _, im in cells) * (scale + 1) + 3 * pad
                 for _, cells in rows) + pad
    sheet = Image.new('RGBA', (width, height), (40, 40, 44, 255))
    draw = ImageDraw.Draw(sheet)
    y = pad
    for title, cells in rows:
        draw.text((pad, y), title, fill=(236, 236, 236))
        y += head
        tall = max(im.height for _, im in cells)
        x = pad
        for label, im in cells:
            draw.text((x, y), label, fill=(170, 200, 230))
            sheet.paste(im.resize((im.width * scale, im.height * scale), Image.NEAREST), (x, y + label_h))
            sheet.paste(im, (x, y + label_h + tall * scale + pad))       # 1x, game scale
            x += im.width * scale + pad
        y += label_h + tall * (scale + 1) + 3 * pad
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


def option(name):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else None


if __name__ == '__main__':
    st = all_states()
    if '--check' in sys.argv:
        check(SHEET, st)
    else:
        problems = check_drawing(st)
        if problems:
            sys.exit('\n'.join(problems))
        write_dmi(SHEET, st)
    if option('--preview'):
        preview(option('--preview'), states())
    if option('--preview-drop'):
        preview_drop(option('--preview-drop'), st)
