#!/usr/bin/env python3
"""Birth-sign glyphs for the Civ13 Character Setup cards.

Draws twelve 32x32 emblems (one icon state each) with plain PIL primitives and
writes them as a BYOND DMI: a PNG sheet with a zTXt "Description" chunk.

    python3 tests/character_traits/birth_sign_sprites.py                       # writes icons/misc/birth_signs.dmi
    python3 tests/character_traits/birth_sign_sprites.py --out DIR_OR_FILE     # elsewhere
    python3 tests/character_traits/birth_sign_sprites.py --preview preview.png # 4x labelled contact sheet

Original pixel art drawn by Fable 5.2 for the birth charts (birth_charts.dm).

Every glyph is a flat silhouette in one gold; a shared pass then adds the
top-left highlight, bottom-right shade and 1px dark outline, so the set keeps
one palette and line weight. A few bright pixels around each emblem hint at a
constellation.
"""
import argparse
import math
from pathlib import Path

from PIL import Image, ImageDraw
from PIL.PngImagePlugin import PngInfo

SIZE = 32
COLUMNS = 4
BASE = (201, 164, 92, 255)      # muted gold
LIGHT = (238, 214, 150, 255)    # parchment highlight
SHADE = (146, 108, 54, 255)     # bronze shadow
DARK = (46, 32, 18, 255)        # outline and cut-in details
STAR = (255, 248, 220, 255)
GLOW = (214, 190, 130, 150)
CLEAR = (0, 0, 0, 0)
UI_BACKGROUND = (42, 35, 28, 255)
UI_ACCENT = (176, 138, 74, 255)


class Glyph:
    def __init__(self):
        self.im = Image.new('RGBA', (SIZE, SIZE), CLEAR)
        self.d = ImageDraw.Draw(self.im)
        self.stars = []

    def poly(self, points, fill=BASE):
        self.d.polygon(points, fill=fill)

    def oval(self, x0, y0, x1, y1, fill=BASE):
        self.d.ellipse((x0, y0, x1, y1), fill=fill)

    def rect(self, x0, y0, x1, y1, fill=BASE):
        self.d.rectangle((x0, y0, x1, y1), fill=fill)

    def dot(self, x, y, fill=DARK):
        if 0 <= x < SIZE and 0 <= y < SIZE:
            self.im.putpixel((x, y), fill)

    def line(self, points, fill=BASE):
        self.d.line(points, fill=fill, width=1)

    def brush(self, points, width=2, fill=BASE):
        """A polyline stamped with a width x width square nib."""
        for (x0, y0), (x1, y1) in zip(points, points[1:]):
            steps = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) or 1
            for i in range(steps + 1):
                x = int(round(x0 + (x1 - x0) * i / steps))
                y = int(round(y0 + (y1 - y0) * i / steps))
                self.d.rectangle((x, y, x + width - 1, y + width - 1), fill=fill)

    def mirror(self):
        """Copy the left half onto the right half."""
        left = self.im.crop((0, 0, SIZE // 2, SIZE)).transpose(Image.FLIP_LEFT_RIGHT)
        self.im.paste(left, (SIZE // 2, 0))
        self.d = ImageDraw.Draw(self.im)

    def star(self, x, y, big=False):
        self.stars.append((x, y, big))

    def finish(self):
        src = self.im.load()
        out = self.im.copy()
        px = out.load()

        def solid(x, y):
            return 0 <= x < SIZE and 0 <= y < SIZE and src[x, y][3] != 0

        for y in range(SIZE):
            for x in range(SIZE):
                if src[x, y] == BASE:
                    if not solid(x, y - 1) or not solid(x - 1, y):
                        px[x, y] = LIGHT
                    elif not solid(x, y + 1) or not solid(x + 1, y):
                        px[x, y] = SHADE
                elif src[x, y][3] == 0:
                    if solid(x - 1, y) or solid(x + 1, y) or solid(x, y - 1) or solid(x, y + 1):
                        px[x, y] = DARK
        for x, y, big in self.stars:
            if big:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    if 0 <= x + dx < SIZE and 0 <= y + dy < SIZE and px[x + dx, y + dy][3] == 0:
                        px[x + dx, y + dy] = GLOW
            px[x, y] = STAR
        return out


def ox():
    g = Glyph()
    g.brush([(11, 10), (6, 10), (3, 7), (3, 3)], 3)             # horn
    g.dot(3, 2, BASE); g.dot(4, 2, BASE)
    g.poly([(10, 14), (5, 13), (4, 15), (7, 17), (10, 17)])       # ear
    g.poly([(10, 9), (15, 8), (15, 27), (13, 27), (11, 25), (10, 20), (9, 14)])  # skull
    g.oval(11, 20, 20, 28)                                        # muzzle
    g.mirror()
    g.oval(11, 20, 20, 28)
    for x in (12, 19):
        g.rect(x - 1, 15, x, 16, DARK)                            # eyes
    g.dot(13, 24); g.dot(18, 24)                                  # nostrils
    g.line([(14, 27), (17, 27)], SHADE)
    g.star(15, 3, True); g.star(9, 5); g.star(22, 5); g.star(2, 22); g.star(28, 20)
    return g


def hearth():
    g = Glyph()
    g.poly([(16, 3), (18, 7), (21, 11), (23, 16), (22, 20), (20, 23),
            (11, 23), (9, 20), (8, 16), (9, 12), (11, 14), (12, 10), (14, 7)])   # flame
    g.poly([(7, 13), (9, 17), (9, 21), (6, 19), (6, 16)])         # side tongue
    g.poly([(25, 12), (25, 17), (23, 21), (23, 16)])
    g.poly([(16, 12), (19, 17), (18, 21), (13, 21), (12, 18), (14, 16)], DARK)   # dark heart
    g.poly([(16, 16), (17, 19), (16, 21), (14, 21), (14, 19)], LIGHT)
    for x0 in (3, 9, 15, 21):                                     # hearth stones
        g.oval(x0, 24, x0 + 6, 29)
    g.oval(26, 25, 29, 29)
    g.star(4, 6, True); g.star(26, 4); g.star(10, 3); g.star(29, 9); g.star(2, 13)
    return g


def hare():
    g = Glyph()
    g.oval(7, 13, 22, 22)                                         # body
    g.oval(5, 12, 9, 15)                                          # scut
    g.poly([(17, 15), (21, 12), (24, 12), (24, 17), (21, 19)])    # neck
    g.oval(21, 10, 28, 16)                                        # head
    g.poly([(27, 12), (29, 13), (29, 15), (26, 16)])              # nose
    g.poly([(22, 11), (14, 5), (12, 5), (13, 7), (20, 13)])       # ears, laid back
    g.poly([(24, 10), (19, 3), (17, 3), (18, 6), (22, 11)])
    g.poly([(10, 18), (3, 23), (1, 26), (2, 27), (6, 26), (13, 22)])     # hind leg
    g.poly([(12, 20), (8, 26), (9, 27), (12, 26), (16, 21)])
    g.poly([(19, 19), (25, 24), (29, 25), (30, 24), (26, 22), (22, 17)])  # fore leg
    g.poly([(17, 20), (21, 25), (24, 26), (24, 25), (20, 19)])
    g.dot(25, 12)                                                 # eye
    g.star(6, 5, True); g.star(27, 4); g.star(2, 17); g.star(16, 28); g.star(29, 29)
    return g


def heron():
    g = Glyph()
    g.poly([(7, 15), (11, 12), (16, 12), (19, 15), (18, 19), (13, 21), (8, 20), (4, 23), (5, 19)])  # body and tail
    g.brush([(17, 14), (19, 12), (19, 9), (17, 7), (17, 5), (18, 3)], 2)   # S neck
    g.rect(18, 2, 21, 4)                                          # head
    g.poly([(21, 3), (28, 4), (21, 5)])                           # bill
    g.line([(18, 2), (14, 1)])                                    # crest plume
    g.line([(12, 21), (12, 29), (14, 29)])                        # standing leg
    g.line([(15, 20), (15, 24), (17, 26), (17, 29), (19, 29)])    # bent leg
    g.dot(20, 3)
    g.line([(9, 16), (14, 17)], SHADE)                            # wing fold
    g.star(26, 12, True); g.star(6, 6); g.star(28, 22); g.star(3, 28); g.star(10, 3)
    return g


def stag():
    g = Glyph()
    g.brush([(13, 15), (10, 13), (7, 10), (6, 6), (7, 2)], 2)     # main beam
    g.brush([(7, 10), (3, 9), (2, 6)], 2)                         # outer tine
    g.brush([(6, 6), (3, 3)], 1)
    g.brush([(10, 13), (11, 9), (11, 6)], 2)                      # inner tine
    g.poly([(12, 18), (7, 15), (5, 16), (7, 19), (12, 20)])       # ear
    g.poly([(12, 15), (15, 14), (15, 29), (14, 29), (13, 27), (12, 22), (11, 19)])  # face
    g.mirror()
    for x in (13, 18):
        g.dot(x, 19); g.dot(x, 20)                                # eyes
    g.rect(15, 27, 16, 28, DARK)                                  # nose
    g.star(15, 3, True); g.star(15, 9); g.star(3, 25); g.star(28, 25); g.star(24, 20)
    return g


def spear():
    g = Glyph()
    g.brush([(5, 27), (21, 11)], 2)                               # shaft
    g.poly([(29, 2), (27, 9), (24, 11), (20, 7), (22, 4)])        # leaf blade
    g.line([(27, 4), (23, 8)], LIGHT)                             # midrib
    g.rect(3, 27, 5, 29)                                          # butt
    g.im = Image.alpha_composite(g.im.transpose(Image.FLIP_LEFT_RIGHT), g.im)
    g.d = ImageDraw.Draw(g.im)
    g.line([(12, 16), (19, 16)], DARK)                            # lashing at the cross
    g.line([(12, 20), (19, 20)], DARK)
    g.rect(13, 17, 18, 19, SHADE)
    g.line([(20, 10), (24, 14)], DARK); g.line([(11, 10), (7, 14)], DARK)   # socket bindings
    g.star(15, 4, True); g.star(15, 27); g.star(2, 17); g.star(29, 17); g.star(15, 10)
    return g


def anvil():
    g = Glyph()
    g.poly([(9, 10), (28, 10), (28, 14), (24, 15), (9, 15)])      # face
    g.poly([(9, 10), (2, 11), (1, 12), (9, 16)])                  # horn
    g.poly([(11, 15), (22, 15), (20, 18), (20, 21), (13, 21), (13, 18)])   # waist
    g.poly([(13, 20), (20, 20), (26, 24), (26, 28), (7, 28), (7, 24)])     # foot
    g.poly([(13, 28), (15, 25), (18, 25), (20, 28)], CLEAR)       # arch under the foot
    g.line([(10, 12), (26, 12)], LIGHT)
    g.star(16, 4, True); g.star(22, 6); g.star(9, 5); g.star(27, 2); g.star(4, 20); g.star(29, 19)
    return g


def serpent():
    g = Glyph()
    points = []
    cx, cy = 14.0, 19.0
    turns = 2.15
    for i in range(400):
        t = i / 399.0
        a = math.pi * 0.2 - t * turns * 2 * math.pi
        r = 1.5 + t * 10.5
        points.append((cx + r * math.cos(a), cy + r * 0.82 * math.sin(a)))
    for i, (x, y) in enumerate(points):
        w = 1 if i < 60 else 2 if i < 150 else 3
        x0, y0 = int(round(x - w / 2.0)), int(round(y - w / 2.0))
        g.rect(x0, y0, x0 + w - 1, y0 + w - 1)
    ex, ey = points[-1]
    ex, ey = int(round(ex)), int(round(ey))
    g.brush([(ex - 1, ey - 1), (ex - 1, 10), (ex - 3, 7)], 3)      # neck lifts off the coil
    g.poly([(19, 3), (24, 3), (27, 6), (26, 8), (20, 8), (18, 6)])  # head
    g.dot(23, 5)
    g.line([(27, 7), (29, 8), (30, 7)], SHADE); g.dot(30, 10, SHADE); g.dot(29, 9, SHADE)   # forked tongue
    g.star(5, 5, True); g.star(12, 3); g.star(29, 15); g.star(2, 29); g.star(29, 29)
    return g


def wolf():
    g = Glyph()
    g.poly([(26, 1), (28, 2), (28, 4), (21, 11), (27, 9), (27, 10), (20, 16),
            (19, 22), (21, 29), (4, 29), (7, 24), (5, 22), (9, 18), (8, 15),
            (11, 11), (11, 8), (13, 2), (16, 7), (18, 8)])
    g.poly([(13, 5), (14, 8), (12, 9)], SHADE)                    # inner ear
    g.line([(15, 12), (17, 11)], DARK)                            # narrowed eye
    g.rect(26, 1, 27, 2, DARK)                                    # nose
    g.line([(9, 22), (11, 24)], SHADE); g.line([(12, 19), (14, 22)], SHADE)   # ruff
    g.line([(15, 25), (17, 27)], SHADE)
    g.star(20, 2, True); g.star(4, 5); g.star(27, 20); g.star(2, 14); g.star(28, 27)
    return g


def owl():
    g = Glyph()
    g.oval(5, 7, 26, 29)
    g.poly([(6, 14), (5, 2), (12, 8)])                            # ear tufts
    g.mirror()
    for cx in (11, 20):
        g.oval(cx - 4, 11, cx + 4, 19, DARK)                      # eye discs
        g.oval(cx - 2, 13, cx + 2, 17, LIGHT)
        g.rect(cx, 15, cx, 15, DARK)
    g.rect(15, 15, 16, 15, LIGHT)
    g.poly([(14, 19), (17, 19), (16, 22), (15, 22)], DARK)        # beak
    for x, y in ((10, 23), (15, 25), (20, 23)):                   # breast feathers
        g.line([(x, y), (x + 1, y + 1)], SHADE); g.dot(x + 2, y, SHADE)
    g.star(15, 3, True); g.star(2, 9); g.star(29, 9); g.star(1, 24); g.star(30, 24)
    return g


def bear():
    g = Glyph()
    g.oval(4, 4, 12, 12)                                          # ear
    g.oval(6, 6, 10, 10, DARK)
    g.oval(5, 7, 26, 28)                                          # head
    g.mirror()
    g.poly([(11, 28), (16, 30), (20, 28)])
    g.oval(10, 17, 21, 27, LIGHT)                                 # muzzle
    g.poly([(13, 18), (18, 18), (17, 21), (14, 21)], DARK)        # nose
    g.line([(15, 22), (15, 24)], DARK); g.line([(16, 22), (16, 24)], DARK)
    g.line([(13, 25), (18, 25)], DARK); g.dot(12, 24); g.dot(19, 24)
    for x in (10, 20):
        g.rect(x, 14, x + 1, 15, DARK)                            # eyes
    g.star(15, 2, True); g.star(1, 16); g.star(30, 16); g.star(3, 28); g.star(28, 28)
    return g


def hawk():
    g = Glyph()
    g.poly([(15, 12), (11, 8), (6, 5), (2, 5), (0, 8), (1, 13), (3, 11), (3, 17),
            (6, 14), (6, 20), (9, 16), (10, 22), (12, 18), (15, 20)])    # wing with primaries
    g.poly([(13, 8), (15, 7), (15, 24), (13, 22)])                # body
    g.poly([(13, 21), (15, 21), (15, 29), (12, 29), (10, 27)])    # tail fan
    g.mirror()
    g.oval(13, 5, 18, 10)                                         # head
    g.poly([(15, 9), (16, 9), (16, 11), (15, 11)], SHADE)         # hooked beak
    g.dot(14, 7); g.dot(17, 7)
    g.line([(15, 26), (15, 28)], SHADE); g.line([(16, 26), (16, 28)], SHADE)
    g.star(15, 1, True); g.star(5, 24); g.star(26, 24); g.star(24, 1); g.star(7, 1)
    return g


STATES = (('ox', ox), ('hearth', hearth), ('hare', hare), ('heron', heron),
          ('stag', stag), ('spear', spear), ('anvil', anvil), ('serpent', serpent),
          ('wolf', wolf), ('owl', owl), ('bear', bear), ('hawk', hawk))


def frames():
    return [(name, draw().finish()) for name, draw in STATES]


def description(names):
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = %d\n\theight = %d\n' % (SIZE, SIZE)
    for name in names:
        text += 'state = "%s"\n\tdirs = 1\n\tframes = 1\n' % name
    return text + '# END DMI\n'


def write_dmi(target, icons):
    rows = (len(icons) + COLUMNS - 1) // COLUMNS
    sheet = Image.new('RGBA', (COLUMNS * SIZE, rows * SIZE), CLEAR)
    for index, (_, icon) in enumerate(icons):
        sheet.paste(icon, ((index % COLUMNS) * SIZE, (index // COLUMNS) * SIZE))
    info = PngInfo()
    info.add_text('Description', description([name for name, _ in icons]), zip=True)
    sheet.save(target, format='PNG', pnginfo=info, optimize=True)


def write_preview(target, icons):
    scale, pad, label = 4, 12, 14
    cell = SIZE * scale
    small = SIZE * 2 + 6 + SIZE
    per_row = 6
    rows = (len(icons) + per_row - 1) // per_row
    row_height = cell + label + SIZE * 2 + pad * 2
    sheet = Image.new('RGBA', (pad + per_row * (cell + pad), pad + rows * row_height), UI_BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    for index, (name, icon) in enumerate(icons):
        x = pad + (index % per_row) * (cell + pad)
        y = pad + (index // per_row) * row_height
        draw.rectangle((x - 2, y - 2, x + cell + 1, y + cell + 1), outline=UI_ACCENT)
        sheet.alpha_composite(icon.resize((cell, cell), Image.NEAREST), (x, y))
        draw.text((x + 2, y + cell + 3), name, fill=UI_ACCENT)
        low = y + cell + label + 4
        left = x + (cell - small) // 2
        sheet.alpha_composite(icon.resize((SIZE * 2, SIZE * 2), Image.NEAREST), (left, low))
        sheet.alpha_composite(icon, (left + SIZE * 2 + 6, low + SIZE))
    sheet.convert('RGB').save(target, format='PNG')


def main():
    here = Path(__file__).resolve().parents[2] / 'icons/misc/birth_signs.dmi'
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--out', default=str(here), help='folder (or .dmi path) for birth_signs.dmi')
    parser.add_argument('--preview', help='also write a labelled 4x preview PNG here')
    args = parser.parse_args()
    out = Path(args.out)
    if out.suffix.lower() != '.dmi':
        out = out / 'birth_signs.dmi'
    out.parent.mkdir(parents=True, exist_ok=True)
    icons = frames()
    write_dmi(out, icons)
    print('wrote %s (%d states)' % (out, len(icons)))
    if args.preview:
        write_preview(args.preview, icons)
        print('wrote %s' % args.preview)


if __name__ == '__main__':
    main()
