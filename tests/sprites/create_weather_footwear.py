"""Hand-placed 32px weather and terrain footwear: snowshoes, mukluks, hobnail
boots, pattens, rubber boots and climbing boots. Every pixel is placed by this
script from a fixed palette (Pillow only); no external or generated artwork.
Frames are typed out as character grids, one character per pixel; only the
rawhide webbing of the snowshoe item is filled by a small pattern helper.
The Frame class, DMI writer and base body come from create_diving_gear.py.

Run with Pillow to reproduce icons/obj/weather_footwear.dmi (item icons) and
icons/mob/weather_footwear.dmi (worn, four directions). `--preview <png>` also
writes a review sheet of the footwear worn on the base body.
Released under Civ13 AGPL-3.0.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_diving_gear import Frame, base_body, write_dmi  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]

DARK = (26, 20, 16)
# bent pale wood
W = [(238, 208, 146), (208, 172, 106), (170, 132, 74), (122, 90, 48), (66, 46, 24)]
# rawhide webbing and lashing
L = [(240, 226, 190), (188, 164, 122)]
# brown fur wrap
FUR = [(176, 148, 116), (142, 114, 86), (108, 84, 60), (78, 58, 42), (44, 32, 22)]
# pale cuff fur
PF = [(246, 240, 226), (214, 202, 180), (160, 146, 124)]
# soft tanned hide
HD = [(222, 180, 128), (190, 144, 96), (150, 108, 68), (106, 74, 46), (58, 40, 24)]
# dark boot leather
T = [(134, 92, 58), (100, 66, 40), (70, 46, 28), (46, 30, 20), (24, 16, 12)]
# iron and steel
S = [(206, 212, 220), (146, 154, 164), (88, 96, 108)]
# green rubber
GR = [(156, 206, 132), (74, 128, 74), (46, 94, 56), (28, 62, 40), (12, 30, 22)]
# orange shell
O = [(250, 158, 62), (226, 102, 38), (172, 62, 28), (96, 34, 20)]
BEAD = [(204, 52, 48), (56, 110, 190)]

KEY = {'X': DARK, 'u': L[0], 'v': L[1], '1': PF[0], '2': PF[1], '3': PF[2],
       'H': S[0], 'I': S[1], 'J': S[2], '8': BEAD[0], '9': BEAD[1],
       'O': O[0], 'P': O[1], 'Q': O[2], 'Z': O[3]}
for chars, ramp in (('klmno', W), ('fghij', FUR), ('abcde', HD), ('pqrst', T), ('ABCDE', GR)):
    for ch, colour in zip(chars, ramp):
        KEY[ch] = colour


def art(f, x0, y0, rows):
    """Place a character grid with its top-left pixel at (x0, y0); '.' is empty."""
    for dy, row in enumerate(rows):
        for dx, ch in enumerate(row):
            if ch != '.':
                f.put(x0 + dx, y0 + dy, KEY[ch])
    return f


# ---------------------------------------------------------------- worn grids
# The base body's feet end on row 31. Facing south or north the left foot spans
# x 9-14 and the right foot mirrors it about the gap at x 15; facing east the
# single visible leg spans x 13-17 with the toe reaching x 19.
# Each entry: (x0, y0, front grid, back grid or None, side x0, side y0, side grid).

SNOWSHOES = (6, 26, [
    '.....jfgj',
    '.....jghj',
    '.....juuj',
    '..okjfggj',
    'okvujfghk',
    '.okkllkko',
], [
    '.....jghj',
    '.....jghj',
    '.....juuj',
    '.okljghhj',
    'okvujghhk',
    '.oklkkko.',
], 8, 26, [
    '.....jfggj......',
    '.....jfghj......',
    '.....juuhj......',
    '.....jfgghj....o',
    '.....jfuuhij..ok',
    'okkvkllvllkvkko.',
])

MUKLUKS = (9, 24, [
    '.21123',
    '.32123',
    '..eabe',
    '..e89e',
    '..eabe',
    '.eabce',
    'eaubce',
    'edddde',
], [
    '.21123',
    '.32223',
    '..ebce',
    '..e98e',
    '..ebce',
    '.ebcce',
    'ebbcce',
    'edddde',
], 12, 24, [
    '.211123..',
    '3212223..',
    '.eabce...',
    '.e898e...',
    '.eabce...',
    '.eabbce..',
    '.eabucce.',
    '.eddddde.',
])

HOBNAIL = (9, 27, [
    '..tqrt',
    '.tqvqt',
    'tqpvqt',
    'XXXXXX',
    'IXIXIX',
], [
    '..tqrt',
    '.tqrrt',
    'tqqrrt',
    'XXXXXX',
    'IXIXIX',
], 13, 27, [
    'tqqrt..',
    'tpqvt..',
    'tpqqvrt',
    'XXXXXXX',
    'XIXXIXI',
])

PATTENS = (9, 27, [
    '..tqrt',
    '..abbc',
    '.tqpqt',
    'okllmo',
    'onmmno',
], [
    '..tqrt',
    '..tqrt',
    '.tqrrt',
    'okllmo',
    'onmmno',
], 12, 27, [
    '.tqqrt...',
    '.tpqat...',
    '.tpqqabt.',
    'okklllmmo',
    '.omoXomo.',
])

RUBBER = (9, 25, [
    '.CBBBC',
    '.EABCE',
    '.EABCE',
    '.EABCE',
    '.EABCE',
    'EBABCE',
    'XXXXXX',
], [
    '.CBBBC',
    '.EBCCE',
    '.EBCCE',
    '.EBCCE',
    '.EBCCE',
    'EBBCCE',
    'XXXXXX',
], 12, 25, [
    '.CBBBBC..',
    '.EABCCE..',
    '.EABCCE..',
    '.EABCCE..',
    '.EBBCCCE.',
    '.EBABBCCE',
    '.XXXXXXXX',
])

CLIMBING = (9, 26, [
    '..JIIJ',
    '.ZOPQZ',
    '.ZOHPZ',
    'JIOHIJ',
    'XXXXXX',
    'HJHHJH',
], [
    '..JIIJ',
    '.ZPPQZ',
    '.ZPQQZ',
    'JIPQIJ',
    'XXXXXX',
    'HJHHJH',
], 12, 26, [
    '.JIIIJ....',
    '.ZOPPQZ...',
    '.ZOPHQZ...',
    '.JOPPHPIJ.',
    '.XXXXXXXXH',
    '.HJHJJHJH.',
])


def worn(spec):
    x0, y0, front, back, sx, sy, side = spec
    frames = []
    for grid in (front, back or front):
        f = art(Frame(), x0, y0, grid)
        for (x, y), c in list(f.px.items()):
            f.put(30 - x, y, c)
        frames.append(f)
    east = art(Frame(), sx, sy, side)
    return frames + [east, east.mirror()]


# ---------------------------------------------------------------- item icons

def pair(grid, x0, y0, dx=8, dy=3):
    """Two boots in profile, toes to the left: the far one behind and above."""
    f = Frame()
    art(f, x0 + dx, y0, grid)
    art(f, x0, y0 + dy, grid)
    return f


def snowshoe(f, x0, y0):
    """One snowshoe seen from above: bent wood teardrop frame with a round toe
    and a lashed tail, two cross bars, rawhide lattice and a fur toe binding."""
    half = [2, 3, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 4, 4, 4, 3, 3, 2, 2, 1, 1]
    cx = x0 + 5
    for i, h in enumerate(half):
        y = y0 + i
        for x in range(cx - h, cx + h + 1):
            edge = abs(x - cx) == h or i == 0 or (i > 0 and abs(x - cx) > half[i - 1]) or (i + 1 < len(half) and abs(x - cx) > half[i + 1])
            if edge:
                f.put(x, y, W[0] if x < cx - 1 and i < 12 else W[1] if x <= cx else W[2] if i < 14 else W[3])
            elif (x + y) % 3 == 0 or (x - y) % 3 == 0:
                f.put(x, y, L[0] if x <= cx else L[1])
    # outline shadow down the right-hand rim and the tail
    for i, h in enumerate(half):
        f.put(cx + h + 1, y0 + i, W[4])
    for i in range(3):
        f.put(cx, y0 + len(half) + i, W[2]); f.put(cx + 1, y0 + len(half) + i, W[4])
    f.put(cx, y0 + len(half), L[0]); f.put(cx, y0 + len(half) - 1, L[0])
    # cross bars and the foot binding between them
    for by in (6, 13):
        f.h(y0 + by, cx - half[by] + 1, cx + half[by] - 1, W[2])
        f.put(cx - half[by] + 1, y0 + by, W[0])
    art(f, cx - 2, y0 + 7, [
        'jfggj',
        'jfghj',
        'uuuuv',
        'jghij',
    ])
    return f


def snowshoes_item():
    f = Frame()
    snowshoe(f, 3, 3)
    snowshoe(f, 17, 5)
    return f


ITEM_GRIDS = {
    'mukluks': ([
        '.....2112112',
        '....321121223',
        '....322212233',
        '.....eabbcde',
        '.....e8989de',
        '.....eabbcde',
        '.....eabbcde',
        '.....eabbcde',
        '.....eabucde',
        '....eaabbcde',
        '..eeaabbbcde',
        '.eaabbubbcde',
        'eaabbbbbccde',
        'eabbbbccccde',
        '.eddddddddde',
        '..eeeeeeeee.',
    ], 5, 6),
    'hobnail_boots': ([
        '......tttttt',
        '.....tqppqrt',
        '.....tpvqrst',
        '.....tqvqrst',
        '....tqpvqrst',
        '..ttqppvqrst',
        '.tqppqqqrrst',
        'tqpqqqrrrsst',
        'tsssssssssst',
        'XXXXXXXXXXXX',
        'HXHXHXH..HXH',
    ], 6, 9),
    'pattens': ([
        '.......ttttt',
        '......tqpqrt',
        '....ttqpqqrt',
        '..ttqpaabqrt',
        '.tqppqqabrst',
        'tqpqqqrrabst',
        'tttttttttttt',
        'okkkllllmmno',
        'olllmmmmnnno',
        '.onno..onno.',
        '.oooo..oooo.',
    ], 6, 9),
    'rubber_boots': ([
        '.....CBBBBBC',
        '.....EABBCDE',
        '.....EABBCDE',
        '.....EABBCDE',
        '.....EABBCDE',
        '.....EBABCDE',
        '.....EBBBCDE',
        '....EBBBBCDE',
        '..EEBBBBCCDE',
        '.EBAABBBCCDE',
        'EBABBBBCCCDE',
        'EBBBBCCCCDDE',
        'XXXXXXXXXXXX',
        '.XXXXXX..XXX',
    ], 6, 7),
    'climbing_boots': ([
        '......JIIIIIJ',
        '......ZOOPPQZ',
        '......ZOHPPQZ',
        '.....ZOPHPQQZ',
        '...ZZOOPHPQQZ',
        '..ZOOPPPPQQIJ',
        '.JIIOPPQQIIIJ',
        '.JIIIIIIIIIJJ',
        'HXXXXXXXXXXXX',
        '.XXXXXXX.XXXX',
        '.H.H.H.H..H.H',
    ], 5, 9),
}

SPECS = {
    'snowshoes': SNOWSHOES,
    'mukluks': MUKLUKS,
    'hobnail_boots': HOBNAIL,
    'pattens': PATTENS,
    'rubber_boots': RUBBER,
    'climbing_boots': CLIMBING,
}
WORN = {name: worn(spec) for name, spec in SPECS.items()}
ITEMS = {'snowshoes': snowshoes_item()}
for _name, (_grid, _x, _y) in ITEM_GRIDS.items():
    ITEMS[_name] = pair(_grid, _x, _y)
ITEMS = {name: ITEMS[name] for name in SPECS}


def write_preview(path, scale=6):
    """Review sheet: each state worn on the base body in four directions, then its item icon."""
    cell = 32 * scale
    sheet = Image.new('RGBA', (cell * 5, cell * len(WORN)), (58, 82, 52, 255))
    draw = ImageDraw.Draw(sheet)
    for row, state in enumerate(WORN):
        for direction in range(4):
            figure = base_body(direction)
            figure.alpha_composite(WORN[state][direction].image())
            sheet.alpha_composite(figure.resize((cell, cell), Image.NEAREST), (direction * cell, row * cell))
            draw.text((direction * cell + 4, row * cell + 4), 'SNEW'[direction], fill=(255, 255, 255, 255))
        sheet.alpha_composite(ITEMS[state].image().resize((cell, cell), Image.NEAREST), (4 * cell, row * cell))
        draw.text((4 * cell + 4, row * cell + 4), state, fill=(255, 255, 255, 255))
    sheet.convert('RGB').save(path)


def main():
    write_dmi(ROOT / 'icons/obj/weather_footwear.dmi', ITEMS, 1)
    write_dmi(ROOT / 'icons/mob/weather_footwear.dmi', WORN, 4)
    if '--preview' in sys.argv[1:-1]:
        write_preview(sys.argv[sys.argv.index('--preview') + 1])


if __name__ == '__main__':
    main()
