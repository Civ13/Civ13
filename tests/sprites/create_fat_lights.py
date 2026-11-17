"""Hand-placed sprites for carrying and burning animal fat:

  icons/obj/fat_lights.dmi (32x32): the grease horn, stoppered and with the
      stopper out, and the stone fat lamp, unlit and burning (4 frames of 2 ds).

Every pixel is placed by this script from the fixed palettes below (Pillow
only); no external or generated artwork. The horn is a cattle horn lying with
its tip to the lower left, a wooden stopper in the mouth and a carrying thong
tied round both ends. The lamp is a shallow hollowed sandstone with a handle
lug, a pool of fat and a moss wick at the near lip. Things are seen
three-quarters from above with the light from the upper left.

Run with Pillow to reproduce the sheet. `--check` verifies the committed sheet
matches and `--preview <png>` writes a 4x review sheet with every frame
labelled. Released under Civ13 AGPL-3.0.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
FAT_LIGHTS = ROOT / 'icons/obj/fat_lights.dmi'

SIZE = 32

# cattle horn from the pale mouth to the dark tip, each as (lit, mid, shade)
HORN = [((238, 224, 190), (214, 194, 152), (170, 148, 108)),
        ((222, 202, 160), (192, 168, 122), (146, 122, 84)),
        ((190, 160, 112), (156, 126, 84), (114, 88, 56)),
        ((140, 110, 76), (108, 82, 54), (76, 56, 38)),
        ((92, 72, 54), (68, 52, 40), (46, 34, 28))]
HORN_LINE = (40, 28, 22)
# the wooden stopper, light to dark
WOOD = [(186, 134, 84), (150, 100, 58), (112, 72, 40), (74, 46, 26)]
# the leather thong
THONG = [(126, 74, 44), (88, 48, 30), (56, 30, 20)]
# rendered fat: set and pale, then melted and lit by the flame
FAT = [(250, 244, 214), (236, 224, 180), (214, 198, 146), (186, 166, 112)]
MELT = [(255, 240, 170), (246, 212, 120), (224, 174, 82), (186, 132, 56)]
# red sandstone, light to dark
STONE = [(206, 170, 142), (184, 146, 120), (160, 122, 100), (134, 100, 84), (106, 78, 68), (78, 58, 54), (52, 40, 40)]
STONE_LINE = (40, 30, 32)
# the stone where the flame lights it
WARM = [(244, 200, 150), (222, 170, 124)]
WICK = [(84, 74, 50), (48, 40, 30), (22, 18, 16)]
FLAME = [(255, 252, 220), (255, 226, 120), (250, 170, 60), (220, 104, 36)]
SOOT = (36, 28, 26)


def noise(x, y, seed=0):
    """A fixed pseudo-random number 0..255, the same on every run."""
    v = (x * 73856093) ^ (y * 19349663) ^ (seed * 2654435761)
    v = (v ^ (v >> 13)) * 1274126177
    return ((v ^ (v >> 16)) >> 4) & 255


def new():
    return Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))


def put(im, x, y, c, a=255):
    if 0 <= x < SIZE and 0 <= y < SIZE and c is not None:
        im.putpixel((x, y), (c[0], c[1], c[2], a))


def outline(im, c):
    """A one pixel dark line around the drawn work."""
    src = im.copy()
    for y in range(SIZE):
        for x in range(SIZE):
            if src.getpixel((x, y))[3]:
                continue
            for ax, ay in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= ax < SIZE and 0 <= ay < SIZE and src.getpixel((ax, ay))[3]:
                    put(im, x, y, c)
                    break
    return im


# ------------------------------------------------------------- grease horn --

# The horn row by row: (y, first x, last x, band of HORN). It sweeps from the
# wide mouth at the upper right down and round to the tip at the lower left.
HORN_ROWS = [
    (8, 21, 24, 0), (9, 19, 25, 0), (10, 17, 26, 0), (11, 15, 26, 0), (12, 14, 25, 0),
    (13, 12, 24, 1), (14, 11, 22, 1), (15, 10, 20, 1), (16, 9, 18, 2), (17, 8, 16, 2),
    (18, 8, 15, 2), (19, 7, 13, 3), (20, 7, 12, 3), (21, 6, 11, 3), (22, 6, 10, 4),
    (23, 6, 9, 4), (24, 6, 8, 4), (25, 7, 7, 4),
]


def horn_band(x, y, band):
    """The colour band shifts toward the dark tip along the horn, not by row alone."""
    along = (26 - x) + (y - 8)                              # 0 at the mouth, about 36 at the tip
    return 0 if along < 9 else 1 if along < 16 else 2 if along < 23 else 3 if along < 29 else 4


def grease_horn(opened=False):
    im = new()
    for y, x0, x1, band in HORN_ROWS:
        for x in range(x0, x1 + 1):
            lit, mid, shade = HORN[horn_band(x, y, band)]
            span = max(1, x1 - x0)
            f = (x - x0) / span                             # 0 on the upper left edge of the row
            c = lit if f < 0.3 else mid if f < 0.72 else shade
            if noise(x, y, 3) < 26 and c is mid:
                c = lit                                     # the grain of the horn
            put(im, x, y, c)
    for x, y in ((16, 11), (15, 12), (13, 13), (12, 14), (11, 15), (10, 16), (9, 17)):
        put(im, x, y, (250, 242, 220))                      # the polish along the upper curve
    # a groove cut round the horn below the mouth, where the thong is tied
    for x, y in ((19, 10), (18, 11), (18, 12), (19, 13), (20, 14), (21, 15)):
        put(im, x, y, THONG[1])
    for x, y in ((19, 9), (18, 10)):
        put(im, x, y, THONG[0])
    put(im, 21, 15, THONG[2])
    # the thong round the tip
    for x, y in ((7, 20), (8, 21), (9, 22), (10, 23)):
        put(im, x, y, THONG[1])
    put(im, 7, 20, THONG[0])
    # the mouth of the horn, seen a little from above: a rim round the opening
    rim = [(22, 7), (23, 7), (24, 7), (25, 8), (26, 9), (27, 10), (27, 11), (26, 12)]
    for x, y in rim:
        put(im, x, y, HORN[0][0])
    if not opened:
        # the stopper stands out of the mouth: a turned wooden plug with a knob
        for x, y, i in ((25, 4, 0), (26, 4, 1), (27, 4, 2),
                        (24, 5, 0), (25, 5, 0), (26, 5, 1), (27, 5, 2), (28, 5, 3),
                        (24, 6, 1), (25, 6, 1), (26, 6, 1), (27, 6, 2), (28, 6, 3),
                        (23, 7, 1), (24, 7, 1), (25, 7, 2), (26, 7, 2), (27, 7, 3),
                        (25, 8, 2), (26, 8, 2), (27, 8, 3), (28, 8, 3),
                        (26, 9, 2), (27, 9, 3), (28, 9, 3), (27, 10, 3), (28, 10, 3)):
            put(im, x, y, WOOD[i])
        put(im, 25, 4, (224, 178, 124))                     # light on the knob
        for x, y in ((22, 7), (23, 8), (24, 9), (25, 10), (26, 11)):
            put(im, x, y, HORN[0][0])                       # the horn's lip in front of the plug
    else:
        # the open mouth with set fat inside
        for x, y, c in ((23, 8, FAT[1]), (24, 8, FAT[0]), (24, 9, FAT[0]), (25, 9, FAT[1]), (25, 10, FAT[1]),
                        (26, 10, FAT[2]), (25, 11, FAT[2]), (26, 11, FAT[3]), (23, 9, FAT[2]), (24, 10, FAT[2])):
            put(im, x, y, c)
        put(im, 22, 8, HORN[1][2])                          # the shaded inner lip
        put(im, 23, 10, HORN[1][2])
        # the stopper hanging on its cord below the mouth
        for x, y, i in ((24, 17, 0), (25, 17, 1), (23, 18, 0), (24, 18, 1), (25, 18, 1), (26, 18, 2),
                        (23, 19, 1), (24, 19, 1), (25, 19, 2), (26, 19, 3), (24, 20, 2), (25, 20, 3)):
            put(im, x, y, WOOD[i])
        for x, y in ((22, 15), (23, 16)):
            put(im, x, y, THONG[1])
    im = outline(im, HORN_LINE)
    # the carrying thong, a loose loop from the groove to the tip, drawn over the outline
    loop = [(17, 9), (16, 8), (14, 7), (12, 7), (10, 8), (8, 9), (6, 11), (5, 13), (4, 15), (4, 17), (5, 19), (6, 20)]
    for i, (x, y) in enumerate(loop):
        put(im, x, y, THONG[0] if i % 3 == 1 else THONG[1])
    for x, y in ((15, 8), (13, 7), (11, 8), (9, 9), (7, 10), (5, 12), (4, 14), (4, 16), (4, 18)):
        put(im, x, y, THONG[1])
    return im


# ---------------------------------------------------------- stone fat lamp --

# The lamp row by row: (y, first x, last x). An oval bowl with a handle lug on
# the right; the hollow sits inside it.
LAMP_ROWS = [(14, 9, 18), (15, 7, 20), (16, 6, 25), (17, 5, 27), (18, 5, 28), (19, 5, 28), (20, 5, 27),
             (21, 6, 25), (22, 7, 21), (23, 8, 20), (24, 10, 18)]
HOLLOW_ROWS = [(15, 10, 17), (16, 8, 19), (17, 7, 20), (18, 7, 20), (19, 8, 19), (20, 10, 17)]
WICK_AT = (9, 18)                                           # the wick lies on the near left lip


def lamp_body(im, lit):
    for y, x0, x1 in LAMP_ROWS:
        for x in range(x0, x1 + 1):
            i = 1 if y <= 16 else 2 if y <= 19 else 3 if y <= 21 else 4 if y <= 22 else 5
            if x >= 22:
                i += 1                                      # the handle lug falls away from the light
            if x <= 7 and y <= 19:
                i -= 1
            n = noise(x, y, 7)
            if n < 36:
                i += 1                                      # the grain of the sandstone
            elif n > 232:
                i -= 1
            put(im, x, y, STONE[max(0, min(len(STONE) - 1, i))])
    for x in range(9, 19):                                  # the far rim catches the light
        put(im, x, 14, STONE[0])
    for x, y in ((7, 15), (8, 15), (6, 16), (19, 15), (20, 15)):
        put(im, x, y, STONE[0])
    for x in range(22, 27):                                 # the flat top of the lug
        put(im, x, 17, STONE[1])
    for x, y in ((23, 18), (24, 18), (25, 18)):             # a thumb hollow worn in it
        put(im, x, y, STONE[4])
    pool = MELT if lit else FAT
    for y, x0, x1 in HOLLOW_ROWS:
        for x in range(x0, x1 + 1):
            edge = x in (x0, x1) or y in (15, 20)
            i = 2 if edge else 1
            if y == 15:
                i = 3                                       # shade under the far rim
            if not edge and noise(x, y, 9) < 60:
                i = 0
            put(im, x, y, pool[i])
    for x in range(10, 18):                                 # the dark line where the wall meets the fat
        put(im, x, 15, STONE[5] if not lit else STONE[4])
    if not lit:
        for x, y in ((12, 17), (13, 17), (15, 18), (16, 18), (12, 19)):   # the set fat's dull sheen
            put(im, x, y, FAT[0])
    else:
        for x, y in ((11, 17), (12, 17), (13, 18), (10, 18), (11, 19)):   # the flame mirrored in the melt
            put(im, x, y, MELT[0])
        for x, y in ((6, 17), (6, 18), (7, 16), (8, 20), (7, 20)):        # and warming the near lip
            put(im, x, y, WARM[1])
        put(im, 7, 19, WARM[0])
    # the moss wick lying over the lip
    wx, wy = WICK_AT
    for x, y, i in ((wx - 1, wy + 1, 1), (wx, wy, 0), (wx + 1, wy, 1), (wx, wy + 1, 1), (wx - 1, wy, 2)):
        put(im, x, y, WICK[i])


# The flame over the wick, frame by frame: rows from the base up, each a string
# of palette indexes into FLAME ('.' is empty), centred on the wick.
FLAME_FRAMES = [
    ['.32.', '2112', '2102', '.21.', '.2..'],
    ['.32.', '2112', '.102', '.12.', '..2.'],
    ['.32.', '2112', '2012', '.21.', '.12.', '..3.'],
    ['.23.', '2112', '210.', '.12.', '.2..'],
]


def fat_lamp(frame=None):
    im = new()
    lamp_body(im, frame is not None)
    im = outline(im, STONE_LINE)
    wx, wy = WICK_AT
    if frame is None:
        put(im, wx, wy - 1, SOOT)                           # the charred wick end
        return im
    rows = FLAME_FRAMES[frame]
    for r, row in enumerate(rows):
        for k, ch in enumerate(row):
            if ch != '.':
                put(im, wx - 1 + k, wy - 1 - r, FLAME[int(ch)])
    return im


# ------------------------------------------------------------------ sheets --

def fat_light_states():
    """[(state, [frames], delay)]; every state is one direction."""
    return [
        ('grease_horn', [grease_horn()], None),
        ('grease_horn_open', [grease_horn(opened=True)], None),
        ('fat_lamp', [fat_lamp()], None),
        ('fat_lamp-on', [fat_lamp(i) for i in range(len(FLAME_FRAMES))], 2),
    ]


def build(states):
    frames = [im for _, ims, _ in states for im in ims]
    cols = int(len(frames) ** 0.5 + 0.999)
    rows = (len(frames) + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * SIZE, rows * SIZE))
    for i, im in enumerate(frames):
        sheet.paste(im, ((i % cols) * SIZE, (i // cols) * SIZE))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = %d\n\theight = %d\n' % (SIZE, SIZE)
    for name, ims, delay in states:
        text += 'state = "%s"\n\tdirs = 1\n\tframes = %d\n' % (name, len(ims))
        if delay:
            text += '\tdelay = %s\n' % ','.join([str(delay)] * len(ims))
    text += '# END DMI\n'
    return sheet, text


def write_dmi(path, sheet, text):
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta, optimize=True)


def same(path, sheet, text):
    if not path.exists():
        return False
    old = Image.open(path)
    return old.info.get('Description') == text and old.size == sheet.size \
        and old.convert('RGBA').tobytes() == sheet.tobytes()


def existing(sheet, state):
    """The first icon of a state in an existing sheet, for scale; None if absent."""
    import re
    try:
        im = Image.open(ROOT / sheet)
        index = 0
        for name, dirs, frames in re.findall(r'state = "(.*?)"\n\tdirs = (\d+)\n\tframes = (\d+)',
                                             im.info.get('Description', '')):
            if name == state:
                cols = im.size[0] // SIZE
                x, y = (index % cols) * SIZE, (index // cols) * SIZE
                return im.convert('RGBA').crop((x, y, x + SIZE, y + SIZE))
            index += int(dirs) * int(frames)
    except OSError:
        pass
    return None


SCALE_ROW = [('icons/obj/lighting.dmi', 'torch'), ('icons/obj/lighting.dmi', 'torch-on'),
             ('icons/obj/lighting.dmi', 'lantern'), ('icons/obj/candle.dmi', 'candle1_lard'),
             ('icons/obj/candle.dmi', 'candle1_lit_lard'), ('icons/obj/claystuff.dmi', 'cookingpot')]


def preview(path, states, scale=4):
    """Every frame at 4x and at 1x, labelled, on grass, on a table top and on a
    night floor; a row of existing sprites gives scale."""
    grass, table, night = (98, 122, 78, 255), (124, 88, 56, 255), (30, 32, 44, 255)
    pad, label = 6, 12
    rows = []
    scale_row = [(state, im, grass) for sheet, state in SCALE_ROW for im in [existing(sheet, state)] if im]
    if scale_row:
        rows.append(('existing sprites, for scale', scale_row))
    for back, name in ((grass, 'on grass'), (table, 'on a table top'), (night, 'at night')):
        cells = []
        for state, ims, _ in states:
            for i, im in enumerate(ims):
                cells.append((state if len(ims) == 1 else '%s %d' % (state, i + 1), im, back))
        rows.append(('%s  %s' % (FAT_LIGHTS.name, name), cells))
    cell = SIZE * scale
    width = pad + max(len(cells) for _, cells in rows) * (cell + pad)
    height = pad + len(rows) * (label + label + cell + pad) + SIZE + pad
    out = Image.new('RGBA', (width, height), (24, 24, 24, 255))
    draw = ImageDraw.Draw(out)
    y = pad
    for title, cells in rows:
        draw.text((pad, y), title, fill=(240, 240, 240, 255))
        y += label
        for i, (caption, im, back) in enumerate(cells):
            x = pad + i * (cell + pad)
            draw.text((x, y), caption[:21], fill=(200, 220, 160, 255))
            tile = Image.new('RGBA', (cell, cell), back)
            tile.alpha_composite(im.resize((cell, cell), Image.NEAREST))
            out.paste(tile, (x, y + label))
        y += label + cell + pad
    x = pad                                                 # actual size, as in the game
    for back in (grass, table):
        for _, ims, _ in states:
            tile = Image.new('RGBA', (SIZE, SIZE), back)
            tile.alpha_composite(ims[0])
            out.paste(tile, (x, y))
            x += SIZE + 2
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    out.save(path, format='PNG')


def main(argv):
    states = fat_light_states()
    if '--check' in argv:
        if not same(FAT_LIGHTS, *build(states)):
            sys.exit('stale sheet: ' + str(FAT_LIGHTS))
        print('fat lights sheet matches')
        return
    if '--preview' in argv:
        preview(argv[argv.index('--preview') + 1], states)
        return
    write_dmi(FAT_LIGHTS, *build(states))
    print('wrote', FAT_LIGHTS)


if __name__ == '__main__':
    main(sys.argv[1:])
