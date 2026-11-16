"""Hand-placed 32px lock sprites for icons/obj/doors/locks_fitted.dmi: the
lock, padlock, knot and seal overlays laid over a shut door or the front of a
storage container, and the matching lock, key and key-blank inventory items.

The shut doors in icons/obj/doors/material_doors.dmi are double-leaf and meet
on x = 15/16, so every `door_*` overlay sits beside or across that line at
handle height (about y = 14-20). The `box_*` overlays are about 7px wide,
centred on x = 16 and low (y = 18-26) so they land on the front of chests,
crates, baskets and jars. Doors are tinted with their material colour and the
overlays are not, so each one carries its own dark outline and reads on wood,
metal and stone. `door_catch` is a hidden catch: only a faint two-pixel notch
on the meeting line.

Every pixel is placed by this script from a fixed palette (Pillow only); no
external or generated artwork. Run it to reproduce the sheet; `--check`
verifies the committed sheet instead of writing it, `--preview <png>` writes
a 4x review sheet over real door and container sprites. Released under Civ13
AGPL-3.0.
"""
import math
import re
import sys
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/doors/locks_fitted.dmi'
DOORS = ROOT / 'icons/obj/doors/material_doors.dmi'
DOORS_L = ROOT / 'icons/obj/doors/material_doors_leonister.dmi'
STONE_AGE = ROOT / 'icons/obj/stone_age_storage.dmi'
STORAGE = ROOT / 'icons/obj/storage.dmi'

OUT = (28, 22, 16)
# forged iron: highlight, light, mid, dark, outline
IRON = [(206, 212, 220), (150, 158, 170), (104, 112, 126), (66, 72, 86), (30, 34, 44)]
# blackened latch case: highlight, light, mid, dark
BODY = [(142, 148, 160), (92, 98, 112), (62, 66, 78), (42, 44, 54)]
# brass: highlight, light, mid, dark
BRASS = [(248, 222, 132), (220, 178, 78), (170, 126, 46), (112, 80, 30)]
# lock and key timber: highlight, light, mid, dark
WOOD = [(222, 184, 124), (184, 140, 86), (140, 100, 58), (96, 66, 36)]
# thin hemp cord: light, mid, dark
ROPE = [(232, 210, 158), (186, 158, 104), (122, 98, 60)]
# sealing clay / wax: highlight, light, mid, dark
CLAY = [(232, 132, 98), (196, 88, 62), (150, 58, 44), (100, 38, 32)]
# the hidden catch: a faint shadow, not an object
NOTCH = (0, 0, 0, 80)


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

    def disc(self, cx, cy, rx, ramp, ry=None):
        """A filled ellipse lit from the upper left with a 4-step ramp."""
        ry = ry or rx
        for y in range(32):
            for x in range(32):
                dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                if dx * dx + dy * dy <= 1.0:
                    t = (dx + dy) / 2
                    self.put(x, y, ramp[0] if t < -0.4 else ramp[1] if t < 0.05
                             else ramp[2] if t < 0.45 else ramp[3])
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
    'G': BRASS[0], 'g': BRASS[1], 'm': BRASS[2], 'n': BRASS[3],
    'W': WOOD[0], 'w': WOOD[1], 'x': WOOD[2], 'y': WOOD[3],
    'R': ROPE[0], 'r': ROPE[1], 'q': ROPE[2],
    'C': CLAY[0], 'D': CLAY[1], 'E': CLAY[2], 'F': CLAY[3],
}
# the same art recoloured from iron to brass
TO_BRASS = dict(KEY, H=BRASS[0], I=BRASS[1], i=BRASS[2], d=BRASS[3])


# ---------------------------------------------------------------- doors

def door_lock_pin():
    """A wooden lock box on the left leaf, its bolt shot across the meeting
    line, with the tumbler peg standing out of the top."""
    return Frame().rows(13, 9, [
        '..Ww.....',
        '..wx.....',
        'WWWWWw...',
        'WwwwwxWWw',
        'WwwwwxWwx',
        'wxxxxy...',
    ]).outline()


def door_lock_warded():
    """An iron lock plate with a keyhole, beside the meeting line."""
    return Frame().rows(14, 11, [
        'HIIi',
        'IkkI',
        'IkkI',
        'IikI',
        'Iiki',
        'iddd',
    ]).outline()


def door_lock_tumbler():
    """A brass plate carrying a round steel cylinder with a key slit."""
    return Frame().rows(14, 11, [
        'GGgg',
        'GHIg',
        'GIkm',
        'Gidm',
        'ggmm',
        'gmmn',
    ]).outline()


def door_lock_latch():
    """A night-latch case with a small brass knob and its keep on the other leaf."""
    return Frame().rows(14, 9, [
        'BBBbbc.Bc',
        'BbGgcc.bc',
        'bbgncc.bc',
        'bcccce.ce',
        'cceeee...',
    ]).outline()


def door_lock_combination():
    """A round steel dial with an index mark and a brass centre knob."""
    f = Frame().disc(13, 17, 3, IRON)
    f.pts(IRON[4], (10, 17), (15, 16), (13, 19), (11, 15))
    f.pts((255, 255, 255), (12, 14))
    f.rows(16, 12, ['Gg', 'gn'])
    return f.outline()


def door_padlock(wheels=False):
    """A hasp strap across both leaves with a padlock through its staple."""
    f = Frame().rows(14, 11, [
        'HIIIIIIII',
        'ddkddkddd' if wheels else 'dddkddkdd',
    ])
    if wheels:
        f.rows(16, 13, [
            'I...I',
            'GGGgg',
            'HkHkH',
            'ggmmm',
            'gmmnn',
        ])
    else:
        f.rows(16, 14, [
            'I..I',
            'HIIi',
            'IkkI',
            'Iiki',
            'iddd',
        ])
    return f.outline()


def door_knot():
    """A cord through a staple on each leaf, knotted in the middle."""
    return Frame().rows(15, 12, [
        'H..RR..H',
        'IRRrRRRI',
        'i..Rr..i',
        '..R..r..',
        '..q..q..',
    ]).outline()


def door_seal():
    """A stamped clay blob pressed over a cord that crosses both leaves."""
    f = Frame()
    f.rows(17, 10, ['RRr......RRr'])
    f.disc(16, 17.5, 3, CLAY)
    f.pts(CLAY[3], (15, 16), (16, 17), (15, 18))
    return f.outline()


def door_seal_broken():
    """The seal cracked through: half still on its cord, which hangs cut."""
    f = Frame()
    f.rows(17, 10, ['RRr......RRr'])
    f.pts(ROPE[1], (19, 18), (19, 19))
    f.pts(ROPE[2], (19, 20))
    half = Frame().disc(15, 19.5, 3, CLAY)
    for (x, y), c in half.px.items():
        if x <= 14 or (x == 15 and y % 2):
            f.put(x, y, c)
    f.pts(CLAY[3], (14, 18), (13, 20))
    f.pts(CLAY[1], (17, 21), (18, 22))
    f.pts(CLAY[2], (17, 22))
    return f.outline()


def door_catch():
    """A hidden catch: nothing but a faint notch on the meeting line."""
    f = Frame()
    f.pts(NOTCH, (15, 17), (15, 18))
    return f


# ----------------------------------------------------------- containers

def box_lock():
    return Frame().rows(19, 14, [
        'HIIIi',
        'IikiI',
        'IkkkI',
        'IikiI',
        'Iikii',
        'idddd',
    ]).outline()


def box_padlock():
    return Frame().rows(18, 14, [
        '.HII.',
        '.I.i.',
        'kIkik',
        'HIIIi',
        'IikiI',
        'Iikii',
        'idddd',
    ]).outline()


def box_combination():
    f = Frame().disc(16.5, 22.5, 2.5, IRON)
    f.pts(IRON[4], (14, 22), (18, 23), (16, 24))
    f.pts((255, 255, 255), (16, 20))
    f.pts(BRASS[1], (16, 22))
    return f.outline()


def box_knot():
    return Frame().rows(19, 14, [
        'H.R.H',
        'IRrRI',
        'i.Rri',
        '.R..r',
        '.q..q',
    ]).outline()


def box_seal():
    f = Frame()
    f.pts(ROPE[0], (13, 22), (19, 22))
    f.disc(16.5, 22.5, 2.5, CLAY)
    f.pts(CLAY[3], (16, 22))
    return f.outline()


def box_seal_broken():
    f = Frame()
    f.pts(ROPE[0], (13, 22), (19, 22))
    f.pts(ROPE[1], (18, 23))
    f.pts(ROPE[2], (18, 24))
    half = Frame().disc(15.5, 23.5, 2.5, CLAY)
    for (x, y), c in half.px.items():
        if x <= 14 or (x == 15 and y % 2 == 0):
            f.put(x, y, c)
    f.pts(CLAY[1], (17, 26))
    return f.outline()


# ---------------------------------------------------------------- items

def item_lock_pin():
    """A wooden pin lock: the case, two drop pegs and the sliding bolt."""
    return Frame().rows(10, 6, [
        '....Ww...Ww.........',
        '....wx...wx.........',
        '....wx...wx.........',
        'WWWWWWWWWWWWWWw.....',
        'WwwwwwwwwwwwwwxWWWWw',
        'WwwwwwwwwwwwwwxWwwwx',
        'WwwxwwwwwwxwwwxWwwwx',
        'Wwwwwwwwwwwwwwxxxxxy',
        'Wxxxxxxxxxxxxxy.....',
        'xyyyyyyyyyyyyyy.....',
    ]).outline()


def item_lock_warded():
    """A forged lock plate with riveted corners and a large keyhole."""
    return Frame().rows(8, 10, [
        '..HHIIIIi...',
        '.HIIIIIIIi..',
        'HIkIIIIIkIi.',
        'HIIIIkkIIIid',
        'IIIIkkkkIiid',
        'IIIIkkkkiiid',
        'IIIIIkkiiiid',
        'IIIIIkkiiiid',
        'IIIiIkkiiidd',
        'IIiikkkkiidd',
        'IikiiiiiikdD',
        '.iiiiiiiddd.',
        '..idddddd...',
    ], dict(KEY, D=IRON[3])).outline()


def item_lock_tumbler():
    """A brass case, its steel cylinder and key slit, and the bolt."""
    f = Frame().rows(10, 7, [
        'GGGGGGGGGGGGgg....',
        'GgkggggggggkgmHIIi',
        'Ggggggggggggmmiiid',
        'Ggggggggggggmm....',
        'Ggggggggggggmm....',
        'Ggggggggggggmm....',
        'Gggggggggggmmm....',
        'Ggggggggggmmmm....',
        'Ggggggggggmmmm....',
        'Ggkgggggmmmkmn....',
        'gmmmmmmmmmmnnn....',
    ])
    f.disc(14, 16, 3, IRON)
    f.pts(IRON[4], (13, 14), (13, 15), (13, 16), (14, 16), (13, 17))
    return f.outline()


def item_lock_latch():
    """A night latch: dark case, brass knob and the sprung bolt."""
    f = Frame().rows(11, 6, [
        'BBBBBBBBBBBbbbbc....',
        'BbkbbbbbbbbbbbkcHIIi',
        'Bbbbbbbbbbbbbcccdkkd',
        'BbbbbbbbbbbcccccHIIi',
        'Bbbbbbbbbbccccccdkkd',
        'BbbbbbbbccccccccHIIi',
        'Bbbbbbcccccccccciddd',
        'bbkccccccccccckc....',
        'ccccccceeeeeeeee....',
    ])
    f.disc(12, 15.5, 2.5, BRASS)
    return f.outline()


def item_lock_combination():
    """A combination dial: tick marks round the rim and a brass knob."""
    f = Frame().disc(16, 16, 7.5, IRON)
    for step in range(12):
        a = math.radians(step * 30)
        r = 5.6
        x = int(math.floor(16 + r * math.sin(a)))
        y = int(math.floor(16 - r * math.cos(a)))
        f.put(x, y, IRON[4])
    f.pts((255, 255, 255), (15, 9), (16, 9), (15, 10), (16, 10))
    f.disc(16, 16, 2.6, BRASS)
    f.pts(BRASS[3], (16, 16))
    return f.outline()


def item_padlock(wheels=False):
    f = Frame().rows(6, 9, [
        '....HHIIIi....',
        '...HIiiiiId...',
        '..HIi....iId..',
        '..Hi......Id..',
        '..Hi......Id..',
        '..Hi......Id..',
        '..Hi......Id..',
    ])
    if wheels:
        f.rows(13, 9, [
            'GGGGGGGGGGGGgg',
            'Gggggggggggggm',
            'GkkkkkkkkkkkkM',
            'GkHHkHHkHHkHkM',
            'GkIIkIIkIIkIkM',
            'GkHHkHHkHHkHkM',
            'GkkkkkkkkkkkkM',
            'Ggggggggggmmmm',
            'Gggggggmmmmmmn',
            'gmmmmmmmmnnnnn',
        ], dict(KEY, M=BRASS[2]))
    else:
        f.rows(13, 9, [
            'HHHIIIIIIIIIIi',
            'HIIIIIIIIIIIid',
            'IIIIIIkkIIIiid',
            'IIIIIkkkkIiiid',
            'IIIIIkkkkiiiid',
            'IIIIIIkkiiiiid',
            'IIIIIIkkiiiidd',
            'IIIiikkkkiiidd',
            'Iiiiiiiiiidddd',
            'iddddddddddddd',
        ])
    return f.outline()


def item_knot_seal():
    """A coil of thin cord with one loose end."""
    return Frame().rows(10, 7, [
        '....RRRRRRRR.....',
        '..RRrqqqqqqrRR...',
        '.RrqRRRRRRRRqrR..',
        'RrqRrq....qrRqrR.',
        'Rq.Rq......qR.qR.',
        'RrqRrq....qrRqrR.',
        '.RrqRRRRRRRRqrq..',
        '..qrrqqqqqqrrq.R.',
        '....qqrrrrqq..Rr.',
        '............RRr..',
    ]).outline()


def item_clay_seal():
    """A lump of sealing clay pressed flat, with a stamp mark in it."""
    f = Frame().disc(16, 17, 7.5, CLAY, ry=5.6)
    f.rows(14, 12, [
        '..FFFF..',
        '.F..E.F.',
        'F.FEEE.F',
        'F.EEFE.F',
        '.F.E..F.',
        '..FFFF..',
    ])
    f.pts(CLAY[0], (10, 15), (11, 14), (12, 13))
    return f.outline()


def item_hidden_catch():
    """A small wooden latch bar on an iron pivot pin, and its keeper block."""
    return Frame().rows(12, 6, [
        '...............WWWWw',
        'WWWWWWWWWWWWWw.Wwwwx',
        'WwHkwwwwwwwwwwwwx.wx',
        'WwkkwwwwwwwwwxxxxWwx',
        'Wxxxxxxxxxxxxy.Wwwwx',
        'xyyyyyyyyyyyyy.wxxxy',
        '...............xyyyy',
    ]).outline()


WOOD_KEY = [
    '.................W.W.W',
    '.................w.w.w',
    'WWWWWW...........w.w.x',
    'WwwwwwWWWWWWWWWWWWWWWW',
    'Ww..wwwwwwwwwwwwwwwwwx',
    'Ww..wwwwwwwwwwwwwwwwwx',
    'Wwwwwxxxxxxxxxxxxxxxxy',
    'xyyyyy................',
]
WARDED_KEY = [
    '..HHI...............',
    '.HIiiI..............',
    'HI...iI.............',
    'Hi...iIHHHHHHHHHHHHI',
    'Hi...iiiiiiiiiiiiiid',
    'Ii...id.......I.Ii.d',
    '.Iiiid........IiI.id',
    '..idd.........I.iiid',
]
TUMBLER_KEY = [
    '..GGGG..............',
    '.GGgggg.....G..G....',
    'GGg..gg..G.GgG.GgG..',
    'Gg....gGGgGgggGgggG.',
    'Gg....ggggggggggggmm',
    'Ggg..gmmmmmmmmmmmmm.',
    '.gggmmn.............',
    '..mmnn..............',
]
SKELETON_KEY = [
    '..HHII..................',
    '.HIiiiI.................',
    'HI....iI.Hi.............',
    'Hi....iIHHIHHHHHHHHHHHHI',
    'Ii....idiiiiiiiiiiiiiiid',
    'Ii....id.id.........Ii.d',
    '.Iiiiid.............IiId',
    '..iddd..............i..d',
]


def blank(art, rows, fill):
    """The uncut blank of a key: the listed rows are replaced."""
    art = list(art)
    for i, row in zip(rows, fill):
        art[i] = row
    return art


def key(art, top, left):
    return Frame().rows(top, left, art).outline()


def states():
    wood_blank = blank(WOOD_KEY, (0, 1, 2), ['.' * 22, '.' * 22, 'WWWWWW' + '.' * 16])
    warded_blank = blank(WARDED_KEY, (5, 6, 7), [
        'Ii...id.......IIIiid',
        '.Iiiid........IIiiid',
        '..idd.........Iiiidd',
    ])
    tumbler_blank = blank(TUMBLER_KEY, (1, 2, 3), [
        '.GGgggg.............',
        'GGg..gg.GGGGGGGGGG..',
        'Gg....gGggggggggggG.',
    ])
    return {
        'door_lock_pin': [door_lock_pin()],
        'door_lock_warded': [door_lock_warded()],
        'door_lock_tumbler': [door_lock_tumbler()],
        'door_lock_latch': [door_lock_latch()],
        'door_lock_combination': [door_lock_combination()],
        'door_padlock': [door_padlock()],
        'door_padlock_combination': [door_padlock(True)],
        'door_knot': [door_knot()],
        'door_seal': [door_seal()],
        'door_seal_broken': [door_seal_broken()],
        'door_catch': [door_catch()],
        'box_lock': [box_lock()],
        'box_padlock': [box_padlock()],
        'box_combination': [box_combination()],
        'box_knot': [box_knot()],
        'box_seal': [box_seal()],
        'box_seal_broken': [box_seal_broken()],
        'item_lock_pin': [item_lock_pin()],
        'item_lock_warded': [item_lock_warded()],
        'item_lock_tumbler': [item_lock_tumbler()],
        'item_lock_latch': [item_lock_latch()],
        'item_lock_combination': [item_lock_combination()],
        'item_padlock': [item_padlock()],
        'item_padlock_combination': [item_padlock(True)],
        'item_knot_seal': [item_knot_seal()],
        'item_clay_seal': [item_clay_seal()],
        'item_hidden_catch': [item_hidden_catch()],
        'key_wood': [key(WOOD_KEY, 12, 5)],
        'key_warded': [key(WARDED_KEY, 12, 6)],
        'key_tumbler': [key(TUMBLER_KEY, 12, 6)],
        'key_skeleton': [key(SKELETON_KEY, 12, 4)],
        'blank_wood': [key(wood_blank, 12, 5)],
        'blank_warded': [key(warded_blank, 12, 6)],
        'blank_tumbler': [key(tumbler_blank, 12, 6)],
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
    boxes = [('log_chest', STONE_AGE, 'log_chest'), ('basket', STONE_AGE, 'basket'),
             ('storage_jar', STONE_AGE, 'storage_jar'), ('wood_chest', STORAGE, 'wood_chest'),
             ('crate', STORAGE, 'crate')]
    floor = (112, 104, 92)
    grounds = [(94, 132, 62), (120, 96, 66), (172, 168, 160), (60, 60, 64)]
    door_states = [n for n in st if n.startswith('door_')]
    box_states = [n for n in st if n.startswith('box_')]
    items = [n for n in st if not n.startswith(('door_', 'box_'))]
    cell, pad, label, left = 32 * scale, 8, 14, 110
    step = cell + pad
    per_row = len(door_states)
    one_x = left + per_row * step + 12            # the 1x column
    width = one_x + per_row * 34 + pad
    item_rows = -(-len(items) // per_row)
    height = (label + len(doors) * step) + (label + len(boxes) * step) + item_rows * (label + step) + pad * 3
    sheet = Image.new('RGBA', (width, height), (40, 40, 44, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((one_x, 2), '1x', fill=text)

    def block(y, names, rows, prefix):
        for c, name in enumerate(names):
            draw.text((left + c * step, y), name[len(prefix):], fill=text)
        y += label
        for r, row in enumerate(rows):
            draw.text((4, y + r * step + cell // 2), row[0], fill=dim)
            base = Image.new('RGBA', (32, 32), floor + (255,))
            base.alpha_composite(tinted(dmi_frame(row[1], row[2]), row[3] if len(row) > 3 else None))
            for c, name in enumerate(names):
                tile = base.copy()
                tile.alpha_composite(st[name][0].image())
                sheet.paste(tile.resize((cell, cell), Image.NEAREST), (left + c * step, y + r * step))
                sheet.paste(tile, (one_x + c * 34, y + r * step))
        return y + len(rows) * step + pad

    y = block(2, door_states, doors, 'door_')
    y = block(y, box_states, boxes, 'box_')
    for i, name in enumerate(items):
        r, c = divmod(i, per_row)
        x, ty = left + c * step, y + r * (label + step)
        draw.text((x, ty), name, fill=text)
        tile = Image.new('RGBA', (32, 32), grounds[(r + c) % 2] + (255,))
        tile.alpha_composite(st[name][0].image())
        sheet.paste(tile.resize((cell, cell), Image.NEAREST), (x, ty + label))
        for g, ground in enumerate(grounds):
            tile = Image.new('RGBA', (32, 32), ground + (255,))
            tile.alpha_composite(st[name][0].image())
            sheet.paste(tile, (one_x + c * 34, ty + label + g * 34))
    sheet.save(path)


if __name__ == '__main__':
    st = states()
    if '--check' in sys.argv:
        check(SHEET, st)
    else:
        write_dmi(SHEET, st)
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1], st)
