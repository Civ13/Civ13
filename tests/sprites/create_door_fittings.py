"""Hand-placed 32px door fittings for icons/obj/doors/door_fittings.dmi: the
overlays laid over a material door (counterweight, spring and hydraulic
closers, spring hinges, floor wedges) and the matching inventory items.

The doors in icons/obj/doors/material_doors.dmi fill the whole tile when shut
(two leaves meeting on x = 15/16) and leave a 6px leaf on each side when open
(x = 0-5 and x = 26-31). Every overlay is fitted to the LEFT leaf: its shut
state sits on the left leaf of the shut door, its `_open` state on the 6px
left strip, with closer arms reaching along the top edge of the doorway. The
door is tinted with its material colour and the overlay is not, so every
overlay carries its own dark outline and reads on wood, metal and stone.

Every pixel is placed by this script from a fixed palette (Pillow only); no
external or generated artwork. Run it to reproduce the sheet; `--check`
verifies the committed sheet instead of writing it, `--preview <png>` writes
a 4x review sheet over the wood, metal and stone doors. Released under Civ13
AGPL-3.0.
"""
import sys
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/doors/door_fittings.dmi'
DOORS = ROOT / 'icons/obj/doors/material_doors.dmi'

OUT = (28, 22, 16)
# forged iron: highlight, light, mid, dark, outline
IRON = [(206, 212, 220), (150, 158, 170), (104, 112, 126), (66, 72, 86), (30, 34, 44)]
# blackened closer body: highlight, light, mid, dark
BODY = [(142, 148, 160), (92, 98, 112), (62, 66, 78), (42, 44, 54)]
# hemp rope: light, mid, dark
ROPE = [(224, 200, 146), (178, 150, 98), (118, 94, 58)]
# field stone: highlight, light, mid, dark
STONE = [(204, 200, 188), (164, 160, 150), (122, 120, 112), (84, 82, 78)]
# wedge timber: highlight, light, mid, dark
WOOD = [(214, 176, 118), (178, 136, 84), (136, 98, 56), (94, 66, 36)]
# brass pin caps: light, dark
BRASS = [(226, 190, 96), (152, 110, 42)]


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

    def image(self):
        im = Image.new('RGBA', (32, 32))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c + (255,))
        return im


KEY = {
    'O': OUT,
    'H': IRON[0], 'I': IRON[1], 'i': IRON[2], 'd': IRON[3], 'k': IRON[4],
    'B': BODY[0], 'b': BODY[1], 'c': BODY[2], 'e': BODY[3],
    'R': ROPE[0], 'r': ROPE[1], 'q': ROPE[2],
    'S': STONE[0], 's': STONE[1], 't': STONE[2], 'u': STONE[3],
    'W': WOOD[0], 'w': WOOD[1], 'x': WOOD[2], 'y': WOOD[3],
    'G': BRASS[0], 'g': BRASS[1],
}


def rope_down(f, x, y0, y1):
    """A hanging rope: twisted strand with a dark edge on its right."""
    for y in range(y0, y1 + 1):
        f.put(x, y, ROPE[0] if y % 3 else ROPE[1])
        f.put(x + 1, y, OUT)


def rope_across(f, x0, x1, y):
    for x in range(x0, x1 + 1):
        f.put(x, y, ROPE[0] if x % 3 else ROPE[1])
        f.put(x, y + 1, OUT)


PULLEY = [
    '.OOO.',
    'OIHIO',
    'OHkiO',
    'OIiiO',
    '.OOO.',
]
WEIGHT = [
    '.OkO.',
    'OSSsO',
    'OSstO',
    'OsstO',
    'OsttO',
    'OttuO',
    '.OOO.',
]


def counterweight(opened):
    """Rope from a staple on the door top, over a pulley on the frame and
    down the hinge side to a stone weight: low when shut, drawn up when open."""
    f = Frame()
    end = 5 if opened else 12            # where the rope is stapled to the leaf
    rope_across(f, 4, end, 1)
    f.pts(IRON[4], (end + 1, 0), (end + 1, 2))
    f.pts(IRON[1], (end + 1, 1))
    f.pts(OUT, (4, 0), (3, 1), (end + 2, 1))
    for x in range(5, end + 1):
        f.put(x, 0, OUT)
    f.rows(2, 3, PULLEY, KEY)
    f.pts(ROPE[0], (3, 2))
    f.pts(OUT, (2, 2), (1, 3))
    top = 11 if opened else 22
    rope_down(f, 2, 3, top)
    for y in range(3, top + 1):
        if y > 6:
            f.put(1, y, OUT)
    f.pts(OUT, (1, 4), (1, 5), (1, 6))
    f.rows(top, 0, WEIGHT, KEY)
    f.pts(ROPE[1], (2, top))
    return f


def coil(f, x, y, turns, h=3, pitch=2):
    """A side-on coil spring: lit turns with shaded gaps between them."""
    for i in range(turns):
        cx = x + i * pitch
        f.put(cx, y, IRON[0])
        for j in range(1, h - 1):
            f.put(cx, y + j, IRON[1])
        f.put(cx, y + h - 1, IRON[2])
        if i < turns - 1:
            if pitch == 2:
                for j in range(h):
                    f.put(cx + 1, y + j, IRON[3])
            else:
                for g in range(1, pitch):
                    f.put(cx + g, y + h // 2, IRON[2])
    return x + (turns - 1) * pitch


def closer_spring(opened):
    """A coiled iron spring arm across the top of the door: slack and close
    wound when shut, drawn out along the top of the doorway when open."""
    f = Frame()
    y = 3
    if opened:
        f.rect(0, y, 1, y + 2, IRON[2])           # frame plate
        f.put(0, y, IRON[1])
        f.put(2, y + 1, IRON[1])
        last = coil(f, 3, y, 4, pitch=3)
        f.put(last + 1, y + 1, IRON[1])
        f.put(last + 2, y + 1, IRON[1])
        f.rect(last + 3, y, last + 4, y + 2, IRON[2])
        f.put(last + 3, y, IRON[0])
    else:
        f.rect(1, y, 2, y + 2, IRON[2])           # frame plate
        f.put(1, y, IRON[1])
        last = coil(f, 3, y, 5)
        f.put(last + 1, y + 1, IRON[1])
        f.put(last + 2, y + 1, IRON[1])
        f.rect(last + 3, y, last + 4, y + 2, IRON[2])   # plate on the leaf
        f.put(last + 3, y, IRON[0])
    return f.outline()


def closer_hydraulic(opened):
    """A dark closer box at the top of the door and its two-part arm to the
    frame: folded flat above the box when shut, reaching out when open."""
    f = Frame()
    if opened:
        f.rows(4, 0, [
            'BBbbbc',
            'bbcGcc',
            'bcccce',
            'ccceee',
        ], KEY)
        # arm: box spindle, out and up to the bracket on the frame head
        f.pts(IRON[1], (4, 3), (5, 3), (6, 2), (7, 2), (8, 2))
        f.pts(IRON[0], (9, 1))
        f.pts(IRON[1], (10, 1), (11, 1), (12, 1), (13, 1))
        f.pts(IRON[2], (14, 1), (14, 0))
    else:
        f.rows(4, 5, [
            'BBBbbbbcc',
            'bbbbcGccc',
            'bbccccccc',
            'ccccceeee',
        ], KEY)
        # arm folded: from the spindle left to the elbow, back to the bracket
        f.pts(IRON[1], (10, 3), (9, 2), (8, 2), (7, 2), (6, 2), (5, 2))
        f.pts(IRON[0], (4, 1))
        f.pts(IRON[1], (5, 0), (6, 0), (7, 0), (8, 0))
        f.pts(IRON[2], (9, 0), (10, 0))
    return f.outline()


HINGE = [
    'GG..',
    'HIi.',
    'ddd.',
    'HIiI',
    'dddk',
    'HIiI',
    'ddd.',
    'HIi.',
    'GG..',
]
HINGE_OPEN = [
    'GG.',
    'HIi',
    'ddd',
    'HIi',
    'ddd',
    'HIi',
    'ddd',
    'HIi',
    'GG.',
]


def spring_hinge(opened):
    """Two spring hinges on the hinge edge: a coiled barrel between brass pin
    caps with a plate screwed to the leaf (seen narrower on the open leaf)."""
    f = Frame()
    for top in (4, 19):
        f.rows(top, 1, HINGE_OPEN if opened else HINGE, KEY)
    return f.outline()


def wedge_shape(f, x0, base, w, h, ramp):
    """A side-on wedge: thin end at x0, thick end at the right, on row base."""
    for i in range(w):
        col = max(1, round(h * (i + 1) / w))
        for j in range(col):
            y = base - j
            if j == col - 1:
                c = ramp[0]
            elif j == 0:
                c = ramp[3]
            elif i >= w - 2:
                c = ramp[2]
            else:
                c = ramp[1]
            f.put(x0 + i, y, c)
    for j in range(h):
        f.put(x0 + w - 1, base - j, ramp[3] if j else ramp[3])
    f.put(x0 + w - 1, base - h + 1, ramp[2])


def wedge_open(ramp):
    """A wedge on the floor with its thin end jammed under the open leaf."""
    f = Frame()
    wedge_shape(f, 3, 30, 8, 4, ramp)
    return f.outline()


# ---------------------------------------------------------------- items

def item_counterweight():
    f = Frame()
    # a coil of rope seen from above, tilted
    f.rows(8, 5, [
        '....RRRRRRR....',
        '..RRrrqqqrrRR..',
        '.RrrqRRRRRqrrR.',
        'RrrqRr...rRqrrR',
        'Rrq.R.....R.qrR',
        'RrrqRr...rRqrrR',
        '.RrrqRRRRRqrrq.',
        '..qrrrqqqrrrq..',
        '....qqrrrqq....',
    ], KEY)
    # the loose end running down to the weight
    f.pts(ROPE[0], (19, 16), (20, 17), (21, 18))
    f.pts(ROPE[1], (20, 16), (21, 17))
    f.rows(19, 19, [
        '.kHk.',
        'SSSst',
        'SSstt',
        'Ssstt',
        'ssttu',
        'sttuu',
    ], KEY)
    f.px.pop((19, 19), None)
    f.px.pop((23, 19), None)
    return f.outline()


def item_spring():
    f = Frame()
    y = 14
    f.rect(5, y - 1, 7, y + 4, IRON[2])               # frame plate
    f.rect(5, y - 1, 7, y - 1, IRON[1])
    f.pts(IRON[4], (6, y), (6, y + 3))
    last = coil(f, 8, y, 6, h=4)
    f.rect(last + 1, y + 1, last + 4, y + 2, IRON[1])   # arm
    f.rect(last + 1, y + 2, last + 4, y + 2, IRON[2])
    f.rect(last + 5, y, last + 7, y + 3, IRON[2])       # eye for the leaf
    f.rect(last + 5, y, last + 7, y, IRON[0])
    f.put(last + 6, y + 2, IRON[4])
    return f.outline()


def item_hydraulic():
    f = Frame()
    f.rows(15, 6, [
        'BBBBBBbbbbbbbbbccc',
        'BbbbbbbbbbccGGcccc',
        'bbbbbbbbccccGgccce',
        'bbbbbbccccccccccee',
        'bbccccccccccceeeee',
        'ccccccccceeeeeeeee',
    ], KEY)
    f.pts(IRON[4], (7, 19), (22, 19))
    # folded arm above the box
    for i in range(9):
        f.put(18 - i, 14 - (i + 1) // 3, IRON[1])
        f.put(18 - i, 13 - (i + 1) // 3, IRON[0])
    f.pts(IRON[0], (9, 10), (8, 10))
    for i in range(8):
        f.put(10 + i, 9 - i // 4, IRON[1])
        f.put(10 + i, 8 - i // 4, IRON[0])
    f.rect(18, 6, 20, 8, IRON[2])
    f.put(19, 7, IRON[4])
    return f.outline()


BIG_HINGE = [
    '....GG....',
    '....GH....',
    'IIIiHIiIII',
    'IkiiddiikI',
    'iiiiHIiiii',
    'iiiiddiiii',
    'iiiiHIiiii',
    'ikiiddiiki',
    'iidiHIidii',
    '....GH....',
    '....gg....',
]


def item_spring_hinge():
    f = Frame()
    f.rows(5, 5, BIG_HINGE, KEY)
    f.rows(16, 17, BIG_HINGE, KEY)
    return f.outline()


def item_wedge(ramp):
    f = Frame()
    wedge_shape(f, 7, 20, 18, 8, ramp)
    return f.outline()


def states():
    return {
        'closer_counterweight': [counterweight(False)],
        'closer_counterweight_open': [counterweight(True)],
        'closer_spring': [closer_spring(False)],
        'closer_spring_open': [closer_spring(True)],
        'closer_hydraulic': [closer_hydraulic(False)],
        'closer_hydraulic_open': [closer_hydraulic(True)],
        'spring_hinge': [spring_hinge(False)],
        'spring_hinge_open': [spring_hinge(True)],
        'wedge_wood_open': [wedge_open(WOOD)],
        'wedge_iron_open': [wedge_open(IRON)],
        'item_closer_counterweight': [item_counterweight()],
        'item_closer_spring': [item_spring()],
        'item_closer_hydraulic': [item_hydraulic()],
        'item_spring_hinge': [item_spring_hinge()],
        'item_wedge_wood': [item_wedge(WOOD)],
        'item_wedge_iron': [item_wedge(IRON)],
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


def door_frame(name):
    """The first frame of a state of material_doors.dmi."""
    im = Image.open(DOORS)
    index, found = 0, None
    cur = None
    for line in im.info['Description'].splitlines():
        line = line.strip()
        if line.startswith('state = '):
            cur = line.split('"')[1]
            if cur == name:
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


def tinted(im, colour):
    r, g, b, a = im.split()
    solid = Image.new('RGB', im.size, colour)
    out = ImageChops.multiply(Image.merge('RGB', (r, g, b)), solid)
    out.putalpha(a)
    return out


def preview(path, st, scale=4):
    # door state, material colour as the game tints it (icon_colour)
    doors = [('wood', 'wood', (0x82, 0x4B, 0x28)), ('iron', 'metal', (0x5C, 0x54, 0x54)),
             ('stone', 'stone', (0x80, 0x80, 0x80))]
    floor = (112, 104, 92)
    fittings = ['closer_counterweight', 'closer_spring', 'closer_hydraulic', 'spring_hinge',
                'wedge_wood', 'wedge_iron']
    items = [n for n in st if n.startswith('item_')]
    cell, pad, label = 32 * scale, 8, 14
    left = 170
    cols = len(doors) * 2
    width = left + cols * (cell + pad) + 48 * 3 + pad
    row_h = cell + pad
    height = label * 2 + len(fittings) * row_h + label + cell + label + pad * 3
    sheet = Image.new('RGBA', (width, height), (40, 40, 44, 255))
    draw = ImageDraw.Draw(sheet)
    for c, (mat, _, _) in enumerate(doors):
        for o, word in enumerate(('shut', 'open')):
            draw.text((left + (c * 2 + o) * (cell + pad), 2), '%s %s' % (mat, word), fill=(230, 230, 230))
    draw.text((left + cols * (cell + pad), 2), '1x', fill=(230, 230, 230))
    for r, fit in enumerate(fittings):
        y = label * 2 + r * row_h
        draw.text((4, y + cell // 2 - 12), fit, fill=(230, 230, 230))
        draw.text((4, y + cell // 2), fit + '_open', fill=(170, 170, 170))
        for c, (mat, base, colour) in enumerate(doors):
            for o, suffix in enumerate(('', '_open')):
                name = fit + suffix
                if name not in st:
                    continue
                tile = Image.new('RGBA', (32, 32), floor + (255,))
                tile.alpha_composite(tinted(door_frame(base + ('open' if o else '')), colour))
                tile.alpha_composite(st[name][0].image())
                x = left + (c * 2 + o) * (cell + pad)
                sheet.paste(tile.resize((cell, cell), Image.NEAREST), (x, y))
                if o:      # true size, open beside shut
                    sheet.paste(tile, (left + cols * (cell + pad) + c * 48 + 16, y + 40))
                else:
                    sheet.paste(tile, (left + cols * (cell + pad) + c * 48 + 16, y))
    y = label * 2 + len(fittings) * row_h + label
    grounds = [(94, 132, 62), (120, 96, 66), (172, 168, 160), (60, 60, 64)]
    for c, name in enumerate(items):
        x = 4 + c * (cell + pad)
        draw.text((x, y - label), name[5:], fill=(230, 230, 230))
        tile = Image.new('RGBA', (32, 32), grounds[c % 2] + (255,))
        tile.alpha_composite(st[name][0].image())
        sheet.paste(tile.resize((cell, cell), Image.NEAREST), (x, y))
    x0 = 4 + len(items) * (cell + pad)
    for g, ground in enumerate(grounds[2:]):
        for c, name in enumerate(items):
            tile = Image.new('RGBA', (32, 32), ground + (255,))
            tile.alpha_composite(st[name][0].image())
            sheet.paste(tile, (x0 + c * 34, y + g * 40))
    sheet.save(path)


if __name__ == '__main__':
    st = states()
    if '--check' in sys.argv:
        check(SHEET, st)
    else:
        write_dmi(SHEET, st)
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1], st)
