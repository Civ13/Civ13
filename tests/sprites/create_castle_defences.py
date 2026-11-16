"""Hand-placed 32px wall openings for icons/obj/castle_defences.dmi: the
overlays laid over a built wall tile to show a loophole cut through it.

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

Every pixel is placed by this script from a fixed palette (Pillow only); no
external or generated artwork. Run it to reproduce the sheet; `--check`
verifies the committed sheet instead of writing it, `--preview <png>` writes
a 4x review sheet (with a 1x strip) of every state and dir over the real
wall sprites. Released under Civ13 AGPL-3.0.
"""
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


def states():
    out = {}
    for name, face, niche, top, left, edge in (
            ('arrow_slit', ARROW_FACE, ARROW_NICHE, TOP_EAST, 8, ARROW_EDGE),
            ('gun_loop', GUN_FACE, GUN_NICHE, GUN_TOP_EAST, 14, GUN_EDGE)):
        e = east(top, left, edge)
        out[name] = [south(face), north(niche), e, e.mirrored()]
    return out


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


if __name__ == '__main__':
    st = states()
    if '--check' in sys.argv:
        check(SHEET, st)
    else:
        write_dmi(SHEET, st)
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1], st)
