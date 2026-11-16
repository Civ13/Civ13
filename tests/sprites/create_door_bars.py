"""Hand-placed 32px door bar sprites for icons/obj/doors/door_bars.dmi: the
bar brackets, the timber and iron bars dropped through them and the slide
bolt, all laid over a shut door, and the matching inventory items.

The shut doors in icons/obj/doors/material_doors.dmi are double-leaf and meet
on x = 15/16. The lock overlays of create_locks.py sit at handle height (about
y = 14-20), so everything here sits lower, across y = 21-25, and a barred door
still shows its lock. One carved timber bracket is pegged on each leaf
(x = 6-9 and x = 22-25) and a bar spans the whole door from x = 2 to x = 29. The slide bolt
has its plate on the right leaf and its keeper on the left. Doors are tinted
with their material colour and the overlays are not, so each one carries its
own dark outline and reads on wood, metal and stone.

Every pixel is placed by this script from a fixed palette (Pillow only); no
external or generated artwork. Run it to reproduce the sheet; `--check`
verifies the committed sheet instead of writing it, `--preview <png>` writes
a 4x review sheet over real door sprites. Released under Civ13 AGPL-3.0.
"""
import re
import sys
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/doors/door_bars.dmi'
DOORS = ROOT / 'icons/obj/doors/material_doors.dmi'
DOORS_L = ROOT / 'icons/obj/doors/material_doors_leonister.dmi'
LOCKS = ROOT / 'icons/obj/doors/locks_fitted.dmi'

OUT = (28, 22, 16)
# forged iron: highlight, light, mid, dark, outline
IRON = [(206, 212, 220), (150, 158, 170), (104, 112, 126), (66, 72, 86), (30, 34, 44)]
# blackened bolt plate: highlight, light, mid, dark
BODY = [(142, 148, 160), (92, 98, 112), (62, 66, 78), (42, 44, 54)]
# bar timber: highlight, light, mid, dark
WOOD = [(222, 184, 124), (184, 140, 86), (140, 100, 58), (96, 66, 36)]
# carved bracket timber, darker than the bar: highlight, light, mid, dark
OAK = [(178, 126, 74), (138, 92, 50), (102, 66, 36), (70, 44, 24)]
# the pale head of a wooden peg
PEG = (236, 206, 152)


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
    'O': OUT,
    'H': IRON[0], 'I': IRON[1], 'i': IRON[2], 'd': IRON[3], 'k': IRON[4],
    'B': BODY[0], 'b': BODY[1], 'c': BODY[2], 'e': BODY[3],
    'W': WOOD[0], 'w': WOOD[1], 'x': WOOD[2], 'y': WOOD[3],
    'T': OAK[0], 't': OAK[1], 'u': OAK[2], 'v': OAK[3], 'P': PEG,
}

BRACKET_X = (6, 22)     # left edge of the bracket on each leaf
BAR_X = (2, 29)         # a bar spans the whole door


# ---------------------------------------------------------------- doors

def brackets():
    """Two empty U-shaped timber cradles, one pegged on each leaf."""
    f = Frame()
    for left in BRACKET_X:
        f.rows(21, left, [
            'T..t',
            'T..u',
            't..u',
            'tPuu',
            'uvvv',
        ])
    return f.outline()


def bracket_lips(f):
    """The brackets as they show round a bar: the two prongs standing above
    it and the front lip, with its peg, rising over its lower edge."""
    for left in BRACKET_X:
        f.rows(21, left, ['T..t'])
        f.pts(OAK[0], (left, 22))
        f.pts(OAK[2], (left + 3, 22))
        f.rows(23, left, [
            'TTtu',
            'tPuu',
            'uvvv',
        ])
    return f


def bar_wood():
    """A thick timber beam dropped through both brackets."""
    f = Frame()
    x0, x1 = BAR_X
    f.rect(x0, 22, x1, 22, WOOD[0])
    f.rect(x0, 23, x1, 23, WOOD[1])
    f.rect(x0, 24, x1, 24, WOOD[2])
    # grain: short dark streaks and a lighter one, then the sawn ends
    f.pts(WOOD[2], (4, 23), (5, 23), (12, 23), (13, 23), (14, 23), (19, 23), (27, 23))
    f.pts(WOOD[1], (11, 22), (12, 22), (20, 22), (21, 22))
    f.pts(WOOD[3], (13, 24), (14, 24), (18, 24), (19, 24), (20, 24))
    f.pts(WOOD[1], (x0, 22), (x1, 22))
    f.pts(WOOD[2], (x0, 23), (x1, 23))
    f.pts(WOOD[3], (x0, 24), (x1, 24))
    return bracket_lips(f).outline()


def bar_iron():
    """A forged iron bar, thinner than the beam, with a rivet by each end
    and one each side of the meeting line."""
    f = Frame()
    x0, x1 = BAR_X
    f.rect(x0, 23, x1, 23, IRON[1])
    f.rect(x0, 24, x1, 24, IRON[3])
    f.pts(IRON[2], (x0, 23), (x1, 23))
    for x in (3, 13, 18, 28):
        f.pts(IRON[0], (x, 23))
        f.pts(IRON[4], (x, 24))
    return bracket_lips(f).outline()


def bolt_open():
    """A slide bolt on the right leaf, its rod drawn back onto the plate; the
    keeper on the left leaf stands empty."""
    return Frame().rows(21, 11, [
        '.......BBBbbbbc',
        'HIi....BbbbbHic',
        'IkI....bkHIIHId',
        'idd....bcddddce',
        '.......cceeeeee',
    ]).outline()


def bolt_shut():
    """The same bolt with its rod slid across the meeting line into the keeper."""
    return Frame().rows(21, 11, [
        '.......BBBbbbbc',
        'HIi....BHibbbbc',
        'IHIIIIIIHIikkkd',
        'iddddddddddccce',
        '.......cceeeeee',
    ]).outline()


# ---------------------------------------------------------------- items

BRACKET_ITEM = [
    'TTt.......',
    'TPt.......',
    'Ttu.......',
    'Ttu....TTt',
    'TPt....Ttu',
    'Ttu....Ttu',
    'Ttu....tuu',
    'TtttttttuV',
    'Ttuuuuuuuv',
    '.uvvvvvvv.',
]
PEG_ITEM = [
    'PW',
    'Ww',
    'wx',
    '.y',
]


def item_brackets():
    """A pair of carved timber brackets seen from the side - door plate with
    two peg heads, seat and upturned hook - and two loose wooden pegs."""
    f = Frame()
    key = dict(KEY, V=OAK[3])
    f.rows(7, 5, BRACKET_ITEM, key)
    f.rows(13, 17, BRACKET_ITEM, key)
    f.rows(20, 6, PEG_ITEM)
    f.rows(21, 11, PEG_ITEM)
    return f.outline()


def diagonal(columns, ramp, top):
    """A bar lying from lower left to upper right, climbing 1px every 2px."""
    f = Frame()
    for n in range(columns):
        for dy, c in enumerate(ramp):
            f.put(3 + n, top - n // 2 + dy, c)
    return f


def item_bar_wood():
    """A timber beam lying on the diagonal, with grain and sawn ends."""
    f = diagonal(26, [WOOD[0], WOOD[1], WOOD[1], WOOD[2], WOOD[3]], 20)
    for n in (4, 5, 6, 12, 13, 19, 20, 21):          # grain streaks
        f.put(3 + n, 20 - n // 2 + 2, WOOD[2])
    for n in (8, 9, 16, 17, 23):
        f.put(3 + n, 20 - n // 2 + 1, WOOD[0])
    for n in (0, 25):                                # sawn ends
        top = 20 - n // 2
        f.pts(WOOD[1], (3 + n, top))
        f.pts(WOOD[2], (3 + n, top + 1), (3 + n, top + 2))
        f.pts(WOOD[3], (3 + n, top + 3), (3 + n, top + 4))
    return f.outline()


def item_bar_iron():
    """A forged iron bar lying on the diagonal, riveted near each end and in
    the middle."""
    f = diagonal(26, [IRON[0], IRON[1], IRON[3]], 21)
    for n in range(26):
        if n % 6 >= 4:                               # hammer marks dull the edge
            f.put(3 + n, 21 - n // 2, IRON[1])
    for n in (2, 12, 22):
        top = 21 - n // 2
        f.pts(IRON[0], (3 + n, top + 1))
        f.pts(IRON[4], (4 + n, top + 1))
    for n in (0, 25):
        top = 21 - n // 2
        f.pts(IRON[1], (3 + n, top))
        f.pts(IRON[2], (3 + n, top + 1))
    return f.outline()


def item_bolt():
    """A slide bolt: nailed plate, rod with its knob, and the loose keeper."""
    return Frame().rows(11, 4, [
        '.......BBBBBBBBBBBBbbbbc',
        'HIIIi..BkbbbbbbbbbbbbkBc',
        'IiiiI..BbbbbbbHIibbbbbcc',
        'Ikkki.HHHHHHHHHIiHHIkkce',
        'Ikkki.IIIIIIIIHIiIIikkce',
        'Ikkki.iddddddddIddddkkce',
        'IiiiI..bbbbbbbIidcccccce',
        'idddd..bkccccccccccckcee',
        '.......ceeeeeeeeeeeeeeee',
    ]).outline()


def states():
    return {
        'brackets': [brackets()],
        'bar_wood': [bar_wood()],
        'bar_iron': [bar_iron()],
        'bolt_open': [bolt_open()],
        'bolt_shut': [bolt_shut()],
        'item_brackets': [item_brackets()],
        'item_bar_wood': [item_bar_wood()],
        'item_bar_iron': [item_bar_iron()],
        'item_bolt': [item_bolt()],
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


def dmi_frame(path, name):
    """The first frame of a state of a 32px .dmi."""
    im = Image.open(path)
    index = 0
    for m in re.finditer(r'state = "(.*?)"\n\tdirs = (\d+)\n\tframes = (\d+)', im.info['Description']):
        if m.group(1) == name:
            break
        index += int(m.group(2)) * int(m.group(3))
    else:
        raise KeyError(name)
    per_row = im.width // 32
    x, y = (index % per_row) * 32, (index // per_row) * 32
    return im.convert('RGBA').crop((x, y, x + 32, y + 32))


def tinted(im, colour):
    if colour is None:
        return im
    r, g, b, a = im.split()
    solid = Image.new('RGB', im.size, colour)
    out = ImageChops.multiply(Image.merge('RGB', (r, g, b)), solid)
    out.putalpha(a)
    return out


def preview(path, st, scale=4):
    text, dim = (230, 230, 230), (170, 170, 170)
    # label, sheet, state, material colour as the game tints it (icon_colour)
    doors = [('wood', DOORS, 'wood', (0x82, 0x4B, 0x28)), ('iron', DOORS, 'metal', (0x5C, 0x54, 0x54)),
             ('stone', DOORS, 'stone', (0x80, 0x80, 0x80)), ('leonister wood2', DOORS_L, 'wood2', None)]
    floor = (112, 104, 92)
    grounds = [(94, 132, 62), (120, 96, 66), (172, 168, 160), (60, 60, 64)]
    overlays = [n for n in st if not n.startswith('item_')]
    items = [n for n in st if n.startswith('item_')]
    # each overlay alone, then the bars under a fitted lock to show both read
    columns = [(n, [st[n][0].image()]) for n in overlays]
    if LOCKS.exists():
        columns += [('%s + %s' % (bar, lock[5:]), [st[bar][0].image(), dmi_frame(LOCKS, lock)])
                    for bar, lock in (('bar_wood', 'door_lock_warded'), ('bar_iron', 'door_padlock'),
                                      ('bolt_shut', 'door_lock_latch'))]
    cell, pad, label, left = 32 * scale, 8, 14, 110
    step = cell + pad
    per_row = len(columns)
    one_x = left + per_row * step + 12            # the 1x column
    width = one_x + per_row * 34 + pad
    height = (label + len(doors) * step) + (label + step) + pad * 3
    sheet = Image.new('RGBA', (width, height), (40, 40, 44, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((one_x, 2), '1x', fill=text)

    y = 2
    for c, (name, _) in enumerate(columns):
        draw.text((left + c * step, y), name[:22], fill=text)
    y += label
    for r, row in enumerate(doors):
        draw.text((4, y + r * step + cell // 2), row[0], fill=dim)
        base = Image.new('RGBA', (32, 32), floor + (255,))
        base.alpha_composite(tinted(dmi_frame(row[1], row[2]), row[3]))
        for c, (name, layers) in enumerate(columns):
            tile = base.copy()
            for layer in layers:
                tile.alpha_composite(layer)
            sheet.paste(tile.resize((cell, cell), Image.NEAREST), (left + c * step, y + r * step))
            sheet.paste(tile, (one_x + c * 34, y + r * step))
    y += len(doors) * step + pad
    for c, name in enumerate(items):
        x = left + c * step
        draw.text((x, y), name, fill=text)
        tile = Image.new('RGBA', (32, 32), grounds[c % 2] + (255,))
        tile.alpha_composite(st[name][0].image())
        sheet.paste(tile.resize((cell, cell), Image.NEAREST), (x, y + label))
        for g, ground in enumerate(grounds):
            tile = Image.new('RGBA', (32, 32), ground + (255,))
            tile.alpha_composite(st[name][0].image())
            sheet.paste(tile, (one_x + c * 34, y + label + g * 34))
    sheet.save(path)


if __name__ == '__main__':
    st = states()
    if '--check' in sys.argv:
        check(SHEET, st)
    else:
        write_dmi(SHEET, st)
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1], st)
