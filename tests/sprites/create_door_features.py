"""Hand-placed 32px door feature sprites for icons/obj/doors/door_features.dmi:
the peep-hole, the sliding judas hatch (privacy shutter), the mail slot and
the pet door, all laid over a shut door, and the matching inventory items.

The shut doors in icons/obj/doors/material_doors.dmi are double-leaf and meet
on x = 15/16; each leaf has an upper panel (about y = 3-14), a middle rail
(y = 15-20) and a lower panel (y = 21-28). A door may carry all four features
at once, so each has its own place and no two share a pixel, outline included:

  peephole     x = 5-9,   y = 8-12   left leaf, eye height, under the closers
  judas_hatch  x = 20-31, y = 4-12   right leaf, upper panel
  mail_slot    x = 22-31, y = 15-18  right leaf, middle rail
  pet_door     x = 20-31, y = 21-31  right leaf, lower panel, on the threshold

The lock overlays of create_locks.py sit round the meeting line (x = 8-22,
y = 12-21), the closers and hinge of create_door_fittings.py along the top
and the left edge, and none of them is covered. The bars of
create_door_bars.py run the full width across y = 20-26, so they do cross the
top of the pet door; nothing 8px tall on the threshold can avoid them.

Doors are tinted with their material colour and these overlays are not, so
each one carries its own dark outline and reads on wood, metal and stone. The
open hatch keeps the frame of the shut one: its plate is slid to the right
and a barred opening shows on the left. The locked pet door is the same flap
with an iron bar dropped across it.

Every pixel is placed by this script from a fixed palette (Pillow only); no
external or generated artwork. Run it to reproduce the sheet; `--check`
verifies the committed sheet instead of writing it, `--bounds` prints each
state's pixel bounds, `--preview <png>` writes a 4x review sheet over real
door sprites. Released under Civ13 AGPL-3.0.
"""
import re
import sys
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/doors/door_features.dmi'
DOORS = ROOT / 'icons/obj/doors/material_doors.dmi'
LOCKS = ROOT / 'icons/obj/doors/locks_fitted.dmi'
BARS = ROOT / 'icons/obj/doors/door_bars.dmi'

OUT = (28, 22, 16)
# brass: highlight, light, mid, dark
BRASS = [(248, 222, 132), (220, 178, 78), (170, 126, 46), (112, 80, 30)]
# forged iron: highlight, light, mid, dark, deepest
IRON = [(206, 212, 220), (150, 158, 170), (104, 112, 126), (66, 72, 86), (30, 34, 44)]
# plate and flap timber: highlight, light, mid, dark
WOOD = [(222, 184, 124), (184, 140, 86), (140, 100, 58), (96, 66, 36)]
# hide flap of the pet door: highlight, light, mid, dark
HIDE = [(214, 196, 164), (180, 158, 124), (140, 118, 90), (98, 80, 60)]
# lens glass: glint, glass, deep glass
GLASS = [(150, 190, 214), (40, 58, 84), (16, 22, 36)]
# the dark behind an opening
VOID = (14, 12, 14)


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
    'A': BRASS[0], 'a': BRASS[1], 'r': BRASS[2], 's': BRASS[3],
    'H': IRON[0], 'I': IRON[1], 'i': IRON[2], 'd': IRON[3], 'k': IRON[4],
    'W': WOOD[0], 'w': WOOD[1], 'x': WOOD[2], 'y': WOOD[3],
    'F': HIDE[0], 'f': HIDE[1], 'g': HIDE[2], 'h': HIDE[3],
    'G': GLASS[0], 'l': GLASS[1], 'L': GLASS[2],
}

PEEPHOLE_AT = (6, 9)    # left, top of the 3x3 ring
HATCH_AT = (21, 5)      # left, top of the 10x7 hatch frame
SLOT_AT = (23, 16)      # left, top of the 8x2 flap
PET_AT = (21, 22)       # left, top of the 10x10 pet door frame


# ---------------------------------------------------------------- doors

def peephole():
    """A brass ring round one pixel of dark glass."""
    left, top = PEEPHOLE_AT
    return Frame().rows(top, left, [
        'aAa',
        'ALr',
        'rrs',
    ]).outline()


def judas_hatch():
    """An iron frame with a timber plate slid shut across it; the plate has
    an iron knob to push it by."""
    left, top = HATCH_AT
    return Frame().rows(top, left, [
        'HIIIIIIIIi',
        'IWWWWWWWWd',
        'IwwwwwwHwd',
        'Iwxxwwwkwd',
        'Ixxxxxxxxd',
        'Iyyyyyyyyd',
        'iddddddddk',
    ]).outline()


def judas_hatch_open():
    """The same frame with the plate slid to the right: three iron bars
    stand in the dark opening and the knob end of the plate still shows."""
    left, top = HATCH_AT
    return Frame().rows(top, left, [
        'HIIIIIIIIi',
        'IViViViyWd',
        'IVdVdVdyHd',
        'IVdVdVdykd',
        'IVdVdVdyxd',
        'IVkVkVkyyd',
        'iddddddddk',
    ]).outline()


def mail_slot():
    """A narrow brass flap, bright along its top edge."""
    left, top = SLOT_AT
    return Frame().rows(top, left, [
        'aAAAAAaa',
        'srrrrrrs',
    ]).outline()


PET_DOOR = [
    'HIIIIIIIIi',
    'IhIhhhhIhd',
    'IFFFFFFffd',
    'IFffffffgd',
    'IFffffffgd',
    'Iffffffggd',
    'Iffffgfggd',
    'IfggggghVd',
    'IVVVVVVVVd',
    'iddddddddk',
]


def pet_door():
    """A hide flap hung by two iron knuckles in an iron frame that stands on
    the threshold; the dark line under the flap is the gap it swings over,
    and one lower corner curls away from the frame."""
    left, top = PET_AT
    return Frame().rows(top, left, PET_DOOR).outline()


def pet_door_locked():
    """The same pet door with an iron bar dropped across the flap, held by a
    brass latch in the middle."""
    f = pet_door()
    left, top = PET_AT
    f.rows(top + 4, left, [
        'HHIIAaIIIi',
        'idddrsdddk',
        'IhhhhhhhhI',
    ])
    f.put(left + 9, top + 6, IRON[3])
    return f


# ---------------------------------------------------------------- items

def item_peephole():
    """A brass door viewer lying on its side: the wide flange with its lens
    facing left and the threaded barrel that goes through the door."""
    return Frame().rows(9, 6, [
        '...aAAa.............',
        '..aAAAAa............',
        '.aAsssAArAaAaAaAa...',
        '.AslGlsarAaAaAaAaAa.',
        'aAsGllLsrAaAaAaAaaAa',
        'aAslllLsrararararars',
        'aasllLLsrararararars',
        '.asLLLLssrsrsrsrsrs.',
        '.rrssssrrsrsrsrsr...',
        '..rrrrrs............',
        '...rsss.............',
    ]).outline()


def item_judas_hatch():
    """A hatch frame with its timber plate half slid: bars on the left, the
    plate and its knob on the right, a screw at each corner."""
    return Frame().rows(8, 5, [
        'HHIIIIIIIIIIIIIIIIIIIi',
        'HkIIIIIIIIIIIIIIIIIIkd',
        'IIVVHiVVHiVVHiyWWWWWId',
        'IIVVIdVVIdVVIdyWWWwwId',
        'IIVVIdVVIdVVIdywwHIwId',
        'IIVVIdVVIdVVIdywwIkwId',
        'IIVVIdVVIdVVIdywxwwxId',
        'IIVVIdVVIdVVIdywwxxxId',
        'IIVVIdVVIdVVIdyxxxxxId',
        'IIVVIdVVIdVVIdyxxyyyId',
        'IIVVdkVVdkVVdkyyyyyyId',
        'IkiiiiiiiiiiiiiiiiiiKd',
        'iddddddddddddddddddddk',
    ], dict(KEY, K=IRON[4])).outline()


def item_mail_slot():
    """A brass letter plate: a screwed backplate with the hinged flap across
    its middle, shaded under its lower edge."""
    return Frame().rows(11, 4, [
        '.aAAAAAAAAAAAAAAAAAAAAa.',
        'aAaaaaaaaaaaaaaaaaaaaaar',
        'AasaaaaaaaaaaaaaaaaaasrR',
        'AaarrrrrrrrrrrrrrrrrrarR',
        'AarAAAAAAAAAAAAAAAAAasrR',
        'AaraaaaaaaaaaaaaaaaaasrR',
        'AarrrrrrrrrrrrrrrrrrrsrR',
        'AasssssssssssssssssssarR',
        'aasaaaaaaaaaaaaaaaaaasrR',
        'arrrrrrrrrrrrrrrrrrrrrrs',
        '.rsssssssssssssssssssss.',
    ], dict(KEY, R=BRASS[3])).outline()


def item_pet_door():
    """A framed hide flap, twice the size of the fitted one, hung by two iron
    knuckles under the hinge pin and a screw at each corner of the frame."""
    return Frame().rows(6, 7, [
        'HHIIIIIIIIIIIIIIIi',
        'HkIIIIIIIIIIIIIIkd',
        'IIiHHHHHHHHHHHHiId',
        'IIhHIhhhhhhhhHIhId',
        'IIhIdhhhhhhhhIdhId',
        'IIFFFFFFFFFFFffgId',
        'IIFFFFFFffffffggId',
        'IIFFfffffffffgggId',
        'IIFfffffffffffggId',
        'IIFfffffffgfffggId',
        'IIFffffffgfffgggId',
        'IIffffffffffggggId',
        'IIfffffggfffggghId',
        'IIffffggggggggghId',
        'IIfggggggggggghVId',
        'IIgghhhhhhhhhhVVId',
        'IIVVVVVVVVVVVVVVId',
        'IkiiiiiiiiiiiiiikD',
        'idddddddddddddddDk',
    ], dict(KEY, D=IRON[3])).outline()


OVERLAYS = ('peephole', 'judas_hatch', 'judas_hatch_open', 'mail_slot', 'pet_door', 'pet_door_locked')


def states():
    return {
        'peephole': [peephole()],
        'judas_hatch': [judas_hatch()],
        'judas_hatch_open': [judas_hatch_open()],
        'mail_slot': [mail_slot()],
        'pet_door': [pet_door()],
        'pet_door_locked': [pet_door_locked()],
        'item_peephole': [item_peephole()],
        'item_judas_hatch': [item_judas_hatch()],
        'item_mail_slot': [item_mail_slot()],
        'item_pet_door': [item_pet_door()],
    }


def bounds(st):
    """Inclusive pixel bounds of each state, outline included."""
    out = {}
    for name, group in st.items():
        xs = [x for x, _ in group[0].px]
        ys = [y for _, y in group[0].px]
        out[name] = (min(xs), min(ys), max(xs), max(ys))
    return out


def assert_apart(st):
    """The four features, in either of their states, never share a pixel."""
    kinds = [('peephole',), ('judas_hatch', 'judas_hatch_open'), ('mail_slot',),
             ('pet_door', 'pet_door_locked')]
    used = [set().union(*(st[n][0].px.keys() for n in kind)) for kind in kinds]
    for i in range(len(used)):
        for j in range(i + 1, len(used)):
            if used[i] & used[j]:
                sys.exit('%s overlaps %s' % (kinds[i][0], kinds[j][0]))


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
    # label, state, material colour as the game tints it (icon_colour)
    doors = [('wood', 'wood', (0x82, 0x4B, 0x28)), ('metal (iron)', 'metal', (0x5C, 0x54, 0x54)),
             ('stone', 'stone', (0x80, 0x80, 0x80))]
    floor = (112, 104, 92)
    grounds = [(94, 132, 62), (120, 96, 66), (172, 168, 160), (60, 60, 64)]
    items = [n for n in st if n.startswith('item_')]
    img = lambda *names: [st[n][0].image() for n in names]
    # each overlay alone, all four together, then under a lock and a bar
    columns = [(n, img(n)) for n in OVERLAYS]
    columns.append(('all four', img('peephole', 'judas_hatch', 'mail_slot', 'pet_door')))
    columns.append(('all, open + locked', img('peephole', 'judas_hatch_open', 'mail_slot', 'pet_door_locked')))
    if LOCKS.exists() and BARS.exists():
        columns.append(('all + padlock + bar', img('peephole', 'judas_hatch', 'mail_slot', 'pet_door')
                        + [dmi_frame(BARS, 'bar_wood'), dmi_frame(LOCKS, 'door_padlock')]))
    cell, pad, label, left = 32 * scale, 8, 14, 96
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
        base.alpha_composite(tinted(dmi_frame(DOORS, row[1]), row[2]))
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
    assert_apart(st)
    if '--check' in sys.argv:
        check(SHEET, st)
    else:
        write_dmi(SHEET, st)
    if '--bounds' in sys.argv:
        for name, box in bounds(st).items():
            print('%-18s x = %d-%d, y = %d-%d' % (name, box[0], box[2], box[1], box[3]))
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1], st)
