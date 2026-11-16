"""Hand-placed 32px fire door sprites for icons/obj/doors/fire_doors.dmi: an
iron-clad timber fire door and a modern steel fire door, each shut, open and
through its opening and closing animations, the overlays laid over them and
the matching inventory items.

The doors follow the "metal" door of icons/obj/doors/material_doors.dmi: two
leaves that fill the tile and meet on x = 15/16, and slide apart 2px a frame
over six frames (delay 2, loop 1) until 6px of each leaf is left at the tile
edge (x = 0-5 and x = 26-31). Unlike the material doors these are not tinted,
so they are drawn in their own colours: grey riveted sheathing with strap
seams for the iron-clad door, muted red-grey paint with a wired-glass vision
panel and a kick plate for the steel one, both in a dark steel frame and with
a red-and-white sign plate on the right leaf (x = 21-26, y = 9-12).

The overlays are not tinted either and carry their own dark outline, so they
read on both doors. `seals_burnt` is the charred, peeled edge seal round the
frame; it keeps to the outer 6px columns and the top and bottom rows so it
suits a shut or an open door. `fusible_link` is for an open door: a keeper
plate on each parked leaf and a hold-open arm across the top of the opening
(y = 2-5) with the solder link on the meeting line. `panic_bar` is for a shut
door: a push bar on each leaf across y = 16-18, with an end case by each jamb.

Every pixel is placed by this script from a fixed palette (Pillow only); no
external or generated artwork. Run it to reproduce the sheet; `--check`
verifies the committed sheet instead of writing it, `--preview <png>` writes
a 4x review sheet of both doors through their frames, the overlays on them
and the items. Released under Civ13 AGPL-3.0.
"""
import sys
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/doors/fire_doors.dmi'

OUT = (28, 22, 16)
# dark steel door frame: light, mid, dark, deepest
FRAME = [(96, 102, 114), (66, 72, 84), (46, 50, 60), (30, 32, 40)]
# iron sheathing: highlight, light, mid, shade, dark
SHEATH = [(198, 202, 208), (164, 168, 176), (134, 138, 146), (108, 112, 122), (78, 82, 92)]
# painted steel, a muted red-grey: highlight, light, mid, shade, dark
PAINT = [(190, 132, 124), (166, 108, 102), (146, 90, 86), (124, 74, 72), (96, 56, 56)]
# bright steel fittings: highlight, light, mid, dark, deepest
STEEL = [(232, 236, 240), (188, 194, 202), (140, 146, 156), (92, 98, 110), (54, 58, 68)]
# wired glass: glare, wire, glass, deep glass
GLASS = [(214, 232, 236), (170, 196, 202), (98, 132, 146), (70, 98, 112)]
# sign plate: red, dark red, white, off-white
SIGN = [(206, 44, 40), (148, 28, 30), (246, 244, 236), (212, 208, 198)]
# brass and solder of the fusible link: highlight, light, mid, dark
BRASS = [(248, 222, 132), (220, 178, 78), (170, 126, 46), (112, 80, 30)]
SOLDER = [(236, 238, 232), (176, 180, 178)]
# burnt seal: pale unburnt strip, ash, char brown, char, soot
CHAR = [(216, 206, 184), (138, 132, 124), (86, 62, 44), (50, 40, 34), (24, 20, 18)]
# fresh intumescent strip: highlight, light, mid, dark, and its red core line
SEAL = [(122, 126, 132), (88, 92, 100), (62, 64, 72), (40, 42, 50)]
CORE = [(214, 70, 52), (158, 44, 38)]

SLIDE = (0, 2, 4, 6, 8, 10)     # px each leaf has slid at each opening frame
SIGN_AT = (21, 9)               # top-left of the sign plate, on the right leaf


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

    def slid(self, n):
        """The door with each leaf slid n px towards its own jamb, the way the
        material doors open; what passes the tile edge is cut off."""
        f = Frame()
        for (x, y), c in self.px.items():
            nx = x - n if x < 16 else x + n
            if (x < 16) == (nx < 16):
                f.put(nx, y, c)
        return f

    def image(self):
        im = Image.new('RGBA', (32, 32))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c if len(c) == 4 else c + (255,))
        return im


KEY = {
    'O': OUT,
    'F': FRAME[0], 'f': FRAME[1], 'g': FRAME[2], 'G': FRAME[3],
    'S': STEEL[0], 's': STEEL[1], 't': STEEL[2], 'u': STEEL[3], 'U': STEEL[4],
    'R': SIGN[0], 'r': SIGN[1], 'W': SIGN[2], 'w': SIGN[3],
    'B': BRASS[0], 'b': BRASS[1], 'c': BRASS[2], 'C': BRASS[3],
    'L': SOLDER[0], 'l': SOLDER[1],
    'P': CHAR[0], 'a': CHAR[1], 'n': CHAR[2], 'k': CHAR[3], 'K': CHAR[4],
    'I': SEAL[0], 'i': SEAL[1], 'j': SEAL[2], 'J': SEAL[3],
    'E': CORE[0], 'e': CORE[1],
}

LEAVES = ((0, 15), (16, 31))    # first and last column of each leaf


# ---------------------------------------------------------------- doors

def leaf_frame(f, x0, x1):
    """The dark steel edge of one leaf, lit from the upper left."""
    f.rect(x0, 0, x1, 0, FRAME[1])
    f.rect(x0, 31, x1, 31, FRAME[3])
    f.rect(x0, 0, x0, 31, FRAME[1])
    f.rect(x1, 0, x1, 31, FRAME[3])
    f.pts(FRAME[0], (x0, 0), (x0 + 1, 0), (x0, 1))
    f.pts(FRAME[2], (x1, 0), (x0, 31))


def sign_plate(f):
    """The red-and-white fire door sign: a white plate in a red border with a
    red bar across it."""
    x, y = SIGN_AT
    f.rows(y, x, [
        'RRRRRR',
        'RWWWWR',
        'RWRRwR',
        'rrrrrr',
    ])


def door_iron():
    """Iron-clad timber: three courses of riveted grey sheathing on each leaf,
    lapped at raised strap seams."""
    f = Frame()
    for x0, x1 in LEAVES:
        f.rect(x0, 0, x1, 31, SHEATH[2])
        # the sheets catch the light down their left side and fall off right
        f.rect(x0 + 1, 1, x0 + 1, 30, SHEATH[1])
        f.rect(x0 + 13, 1, x0 + 14, 30, SHEATH[3])
        f.rect(x0 + 1, 1, x1 - 1, 1, SHEATH[1])
        f.rect(x0 + 1, 30, x1 - 1, 30, SHEATH[3])
        # worn patches and a lap line down the middle sheet
        f.pts(SHEATH[1], (x0 + 4, 4), (x0 + 5, 4), (x0 + 9, 11), (x0 + 10, 11), (x0 + 3, 19),
              (x0 + 4, 20), (x0 + 10, 26), (x0 + 11, 26))
        f.pts(SHEATH[3], (x0 + 9, 3), (x0 + 10, 4), (x0 + 4, 12), (x0 + 5, 12), (x0 + 9, 19),
              (x0 + 10, 20), (x0 + 4, 27), (x0 + 5, 28))
        for y in range(18, 22):
            f.pts(SHEATH[3], (x0 + 7, y))
            f.pts(SHEATH[1], (x0 + 8, y))
        # strap seams: lit top edge, strap with rivet heads, shadow under it
        for y in (7, 15, 23):
            f.rect(x0 + 1, y - 1, x1 - 1, y - 1, SHEATH[0])
            f.rect(x0 + 1, y, x1 - 1, y, SHEATH[3])
            f.rect(x0 + 1, y + 1, x1 - 1, y + 1, SHEATH[4])
            for x in range(x0 + 2, x1, 3):
                f.pts(SHEATH[0], (x, y))
        # rivets down both edges of each sheet, each with its shadow
        for y in (3, 11, 19, 27):
            for x in (x0 + 2, x0 + 12):
                f.pts(SHEATH[0], (x, y))
                f.pts(SHEATH[4], (x, y + 1))
        leaf_frame(f, x0, x1)
    sign_plate(f)
    return f


def door_steel():
    """Modern steel: smooth red-grey paint, a narrow wired-glass vision panel
    high on the left leaf, a pull by the meeting line and a steel kick plate."""
    f = Frame()
    for x0, x1 in LEAVES:
        f.rect(x0, 0, x1, 31, PAINT[2])
        f.rect(x0 + 1, 1, x0 + 2, 30, PAINT[1])
        f.rect(x0 + 12, 1, x0 + 14, 30, PAINT[3])
        f.rect(x0 + 1, 1, x1 - 1, 1, PAINT[0])
        f.rect(x0 + 1, 30, x1 - 1, 30, PAINT[4])
        f.rect(x0 + 14, 2, x0 + 14, 30, PAINT[4])
        # kick plate, screwed at its corners
        f.rect(x0 + 2, 25, x0 + 13, 25, STEEL[1])
        f.rect(x0 + 2, 26, x0 + 13, 28, STEEL[2])
        f.rect(x0 + 2, 29, x0 + 13, 29, STEEL[3])
        f.pts(STEEL[0], (x0 + 3, 26), (x0 + 12, 26))
        f.pts(STEEL[4], (x0 + 3, 28), (x0 + 12, 28))
        leaf_frame(f, x0, x1)
    # flush pulls either side of the meeting line
    for x in (13, 18):
        f.rect(x, 20, x, 22, STEEL[1])
        f.pts(STEEL[0], (x, 20))
        f.pts(STEEL[4], (x, 23))
    # vision panel: dark frame, glass, a diamond mesh of wire and a glare
    f.rect(8, 3, 13, 14, FRAME[3])
    f.rect(8, 3, 13, 3, FRAME[1])
    f.rect(8, 3, 8, 14, FRAME[1])
    for y in range(4, 14):
        for x in range(9, 13):
            f.put(x, y, GLASS[1] if (x + y) % 3 == 0 or (x - y) % 3 == 0 else
                  GLASS[2] if y < 9 else GLASS[3])
    f.pts(GLASS[0], (9, 4), (10, 4), (9, 5))
    sign_plate(f)
    return f


def door_states(name, shut):
    opening = [shut.slid(n) for n in SLIDE]
    return {
        name: [shut],
        name + 'open': [opening[-1]],
        name + 'opening': opening,
        name + 'closing': opening[::-1],
    }


# ---------------------------------------------------------------- overlays

def seals_burnt():
    """What is left of the edge seals: charred lengths clinging to the jambs
    and the head of the frame, ash, and pale curls peeling away from them."""
    f = Frame()
    f.rows(0, 0, [
        'kKk.nk..',
        'Kna..P..',
        'kk......',
        'Kn......',
        'kaP.....',
        'K.P.....',
        '........',
        'k.......',
        'Kn......',
        'kk......',
    ])
    f.rows(15, 0, [
        'kn..',
        'Kk..',
        'ka..',
        'K.P.',
        '..P.',
        '....',
        'k...',
        'Kn..',
        'kk..',
        'Ka..',
        'k...',
        '....',
        'Kn..',
        'kkP.',
        'KkaP',
        'kKk.',
        'Kkn.',
    ])
    f.rows(0, 24, [
        '.kn..kKk',
        '..P..akK',
        '......nk',
        '......kK',
        '.......k',
        '........',
        '......nK',
        '.....Pkk',
        '.....PaK',
        '......nk',
        '.......K',
    ])
    f.rows(14, 28, [
        '...k',
        '..nK',
        '..kk',
        '...K',
        '....',
        '...k',
        '..aK',
        '.P.k',
        '.P..',
        '....',
        '..nK',
        '..kk',
        '...K',
        '..ak',
        '.Pkk',
        'P.nK',
        '.kKk',
        '.nkK',
    ])
    return f.outline()


def fusible_link():
    """A hold-open arm across the head of the opening: a keeper plate on each
    parked leaf, two iron arms and the soldered brass link between them."""
    f = Frame()
    f.rows(2, 2, [
        'SsU........cBBc........Ssu',
        'stutssssssBbLlbctttttttstu',
        'suUuuuuuuucbllcCuuuuuuusuU',
        'tuU........cccC........tuU',
    ])
    return f.outline()


def panic_bar():
    """A push bar on each leaf, hinged in an end case by the jamb and stopping
    short of the meeting line."""
    f = Frame()
    f.rows(15, 2, [
        'Sst......................Sst',
        'stuSSSSSSSSSS..SSSSSSSSSSstu',
        'sUussssssssst..ssssssssstsUu',
        'stuuuuuuuuuuU..uuuuuuuuuUstu',
        'tuU......................tuU',
    ])
    return f.outline()


# ---------------------------------------------------------------- items

def item_fusible_link():
    """The hold-open arm off the door: a screw plate, the arm, and the link -
    two brass strips lapped and held by a bead of solder - ending in an eye."""
    return Frame().rows(11, 3, [
        'SssU......................',
        'sUtu.........cBBBBc.......',
        'sttuSSSSSSSSBbbLLbbBc.tSt.',
        'sttusttttttBbbLllLbbbctu.t',
        'sttuuuuuuuucbbbllbbccCtu.u',
        'sUtu.......cccbbbbcCC.tuu.',
        'stuU.........cCCCCC.......',
        'tuuU......................',
    ]).outline()


def item_panic_bar():
    """A push bar lying flat with an end case, screwed twice, at each end."""
    return Frame().rows(11, 3, [
        'SSst..................SSst',
        'sUtu..................sUtu',
        'sttuSSSSSSSSSSSSSSSSSSsttu',
        'sttussssssssssssssssstsstu',
        'sttuttttttttttttttttttsttu',
        'sttuuuuuuuuuuuuuuuuuuUsttu',
        'sUtu..................sUtu',
        'tuuU..................tuuU',
    ]).outline()


def item_fire_seals():
    """A coil of intumescent seal strip - grey with a red core line - seen
    from the side of the roll, its loose end trailing off to the right."""
    return Frame().rows(6, 6, [
        '.....IIIIIII.........',
        '...IIiiiiiiiiI.......',
        '..IiiEEEEEEEijj......',
        '.IiEEjjjjjjjEejj.....',
        '.IiEjjIIIIIjjEejJ....',
        'IiEjjIiEEEiijjEjJ....',
        'IiEjIiEjjjEijjEjJ....',
        'IiEjIiEjJjEijjEjJ....',
        'IiEjIiEjjjeijjEjJ....',
        'IiEjjIieeeijjEejJ....',
        '.IiEjjiiiijjEejjJ....',
        '.IieEjjjjjjEeejJJ....',
        '..IieEEEEEEeejjJ.....',
        '...jjeeeeeeejjJIIIIIi',
        '....jjjjjjjjjJEEEEEEe',
        '......JJJJJJJjjjjjjjJ',
    ]).outline()


def states():
    st = {}
    st.update(door_states('firedoor_iron', door_iron()))
    st.update(door_states('firedoor_steel', door_steel()))
    st.update({
        'seals_burnt': [seals_burnt()],
        'fusible_link': [fusible_link()],
        'panic_bar': [panic_bar()],
        'item_fusible_link': [item_fusible_link()],
        'item_panic_bar': [item_panic_bar()],
        'item_fire_seals': [item_fire_seals()],
    })
    return st


def build_sheet(st):
    frames = [fr for group in st.values() for fr in group]
    sheet = Image.new('RGBA', (32 * len(frames), 32), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(fr.image(), (i * 32, 0))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, group in st.items():
        text += 'state = "%s"\n\tdirs = 1\n\tframes = %d\n' % (name, len(group))
        if len(group) > 1:      # the timing of the material door animations
            text += '\tdelay = %s\n\tloop = 1\n' % ','.join(['2'] * len(group))
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
    text, dim = (230, 230, 230), (170, 170, 170)
    floor = (112, 104, 92)
    grounds = [(94, 132, 62), (120, 96, 66), (172, 168, 160), (60, 60, 64)]
    doors = ('firedoor_iron', 'firedoor_steel')
    items = [n for n in st if n.startswith('item_')]
    # label, door state suffix, frame, overlays
    columns = [('shut', '', 0, ())]
    columns += [('opening %d' % (n + 1), 'opening', n, ()) for n in range(len(SLIDE))]
    columns += [('open', 'open', 0, ())]
    fitted = [('panic_bar', '', 0, ('panic_bar',)),
              ('seals_burnt', '', 0, ('seals_burnt',)),
              ('seals + bar', '', 0, ('seals_burnt', 'panic_bar')),
              ('fusible_link', 'open', 0, ('fusible_link',)),
              ('seals, open', 'open', 0, ('seals_burnt',)),
              ('seals + link', 'open', 0, ('seals_burnt', 'fusible_link'))]
    cell, pad, label, left = 32 * scale, 8, 14, 60
    step = cell + pad
    width = left + len(columns) * step + pad
    block = label + len(doors) * step
    height = 2 * block + (label + step) + (label + len(doors) * 2 * 34) + pad * 5
    sheet = Image.new('RGBA', (width, height), (40, 40, 44, 255))
    draw = ImageDraw.Draw(sheet)

    def tile(door, suffix, frame, overlays):
        t = Image.new('RGBA', (32, 32), floor + (255,))
        t.alpha_composite(st[door + suffix][frame].image())
        for name in overlays:
            t.alpha_composite(st[name][0].image())
        return t

    y = 2
    ones = []
    for group in (columns, fitted):
        for c, col in enumerate(group):
            draw.text((left + c * step, y), col[0], fill=text)
        y += label
        for r, door in enumerate(doors):
            draw.text((4, y + r * step + cell // 2), door[9:], fill=dim)
            for c, col in enumerate(group):
                t = tile(door, *col[1:])
                sheet.paste(t.resize((cell, cell), Image.NEAREST), (left + c * step, y + r * step))
            ones.append([tile(door, *col[1:]) for col in group])
        y += len(doors) * step + pad
    for c, name in enumerate(items):
        x = left + c * step
        draw.text((x, y), name, fill=text)
        t = Image.new('RGBA', (32, 32), grounds[c % 2] + (255,))
        t.alpha_composite(st[name][0].image())
        sheet.paste(t.resize((cell, cell), Image.NEAREST), (x, y + label))
        for g, ground in enumerate(grounds):
            t = Image.new('RGBA', (32, 32), ground + (255,))
            t.alpha_composite(st[name][0].image())
            sheet.paste(t, (left + len(items) * step + c * 34, y + label + g * 34))
    y += label + step + pad
    draw.text((4, y), '1x: shut, opening, open, overlays, then closing', fill=text)
    y += label
    for r, row in enumerate(ones):
        for c, t in enumerate(row):
            sheet.paste(t, (left + c * 34, y + r * 34))
    # the closing frames run the opening ones backwards; show them at 1x only
    for r, door in enumerate(doors):
        for c, fr in enumerate(st[door + 'closing']):
            t = Image.new('RGBA', (32, 32), floor + (255,))
            t.alpha_composite(fr.image())
            sheet.paste(t, (left + (len(columns) + 1 + c) * 34, y + r * 34))
    sheet.save(path)


if __name__ == '__main__':
    st = states()
    if '--check' in sys.argv:
        check(SHEET, st)
    else:
        write_dmi(SHEET, st)
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1], st)
