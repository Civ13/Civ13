"""Original hand-placed 32px art for the coffee chain items.

Every pixel comes from the fixed palette and the stamps and coordinates in this
file; there is no external, traced or generated artwork. Released under Civ13's
AGPL-3.0 licence. Run with Pillow from the repository root:

    python3 tests/sprites/create_coffee.py [--check] [--preview sheet.png]

It appends (or replaces) these states in icons/obj/food/food.dmi and leaves
every other state untouched, including the old `coffee`, `coffee_arabica` and
`coffee_roasted` states:

- green_coffee: a picked sprig of ripe red coffee cherries with a few unripe
  green ones and a leaf. Drawn in its own colours; the item needs no `color`.
- roasted_coffee: a small heap of dark roasted beans with their creases.

It reuses the DMI reader and writer of create_herb_garden.py. `--check`
verifies the committed sheet without writing; `--preview <png>` writes a 4x
review sheet with the old tinted `coffee` look for comparison. To change the
look, edit this script and rerun it; do not hand-edit the DMI.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_herb_garden import read_dmi, write_dmi  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
DMI = ROOT / 'icons/obj/food/food.dmi'
S = 32
OLD_TINT = (0xa5, 0x20, 0x1d)  # the `color` the item used over the old `coffee` state

PAL = {
    # roasted beans
    'k': '#1c0e06', 'o': '#2e180b', 'd': '#472712', 'm': '#633818', 'l': '#834f25', 'h': '#b07a45',
    # ripe cherries
    'q': '#5e0c12', 'r': '#a11a1c', 'R': '#d2302a', 'p': '#f39078',
    # unripe cherries
    'e': '#2f5a1a', 'g': '#4f8a26', 'G': '#7db83c', 'y': '#c6e68c',
    # leaf and twig
    'x': '#1f4a1c', 'f': '#2f6f27', 'F': '#479a36', 'v': '#7cc55a',
    'b': '#4a3216', 'B': '#775428',
}


def rgba(c):
    c = PAL[c]
    return (int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16), 255)


def stamp(im, x, y, rows, remap=None):
    px = im.load()
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch != '.' and 0 <= x + i < S and 0 <= y + j < S:
                px[x + i, y + j] = rgba(remap.get(ch, ch) if remap else ch)


# ------------------------------------------------------------ roasted beans
# Each bean is an outlined oval lit from the upper left with a dark crease.
BEAN_FLAT = [   # crease runs along the bean
    '.ooooo.',
    'omlhlmo',
    'olkkkmo',
    'ommmddo',
    '.ooooo.',
]
BEAN_TILT = [   # crease runs from upper left to lower right
    '.oooo.',
    'ohlmmo',
    'olkkmo',
    'ommkdo',
    'ommddo',
    '.oooo.',
]
BEAN_TILT_R = [row[::-1] for row in BEAN_TILT]
BEAN_BACK = [   # crease side down: a plain rounded back
    '.oooo.',
    'olhlmo',
    'ommmdo',
    'omdddo',
    '.oooo.',
]
BEAN_UP = [     # standing on end
    '.ooo.',
    'olhmo',
    'omkmo',
    'omkmo',
    'omkdo',
    'omddo',
    '.ooo.',
]
HEAP = [  # painted back to front
    (13, 9, BEAN_BACK),
    (9, 12, BEAN_TILT), (17, 12, BEAN_FLAT), (14, 12, BEAN_UP),
    (5, 16, BEAN_FLAT), (21, 16, BEAN_TILT_R),
    (11, 17, BEAN_TILT_R), (16, 18, BEAN_FLAT),
    (25, 21, BEAN_BACK),  # one that rolled off
]


def roasted_coffee():
    im = Image.new('RGBA', (S, S))
    for x, y, rows in HEAP:
        stamp(im, x, y, rows)
    return im


# ---------------------------------------------------------- coffee cherries
CHERRY = [
    '.qrrq.',
    'qRpRrq',
    'rRRRrq',
    'rRRrrq',
    'qrrrqq',
    '.qqqq.',
]
CHERRY_SMALL = [
    '.qrq.',
    'qpRrq',
    'rRRrq',
    'qrrqq',
    '.qqq.',
]
UNRIPE = {'q': 'e', 'r': 'g', 'R': 'G', 'p': 'y'}
LEAF = [  # points up and right from the twig
    '......xxx.',
    '....xxFvfx',
    '..xxFvFffx',
    '.xFvFFfffx',
    'xFvFFfffx.',
    'xvFFfffx..',
    'xFfffxx...',
    '.xxxx.....',
]
TWIG = [(6, 8), (7, 9), (8, 10), (9, 11), (10, 12), (11, 13), (12, 14), (13, 15), (14, 16),
        (15, 17), (16, 18), (17, 19), (18, 20)]
CLUSTER = [  # x, y, stamp, unripe; painted back to front along the twig
    (10, 8, CHERRY_SMALL, True),
    (5, 12, CHERRY, False), (13, 10, CHERRY, False),
    (9, 15, CHERRY, False), (15, 14, CHERRY_SMALL, True),
    (13, 19, CHERRY, False), (18, 17, CHERRY, False),
    (8, 20, CHERRY_SMALL, True), (19, 22, CHERRY_SMALL, False),
]


def green_coffee():
    im = Image.new('RGBA', (S, S))
    stamp(im, 15, 4, LEAF)
    px = im.load()
    for x, y in TWIG:
        px[x, y] = rgba('B')
        px[x, y + 1] = rgba('b')
    px[5, 7] = rgba('b')  # the cut end
    px[6, 7] = rgba('B')
    for x, y, rows, unripe in CLUSTER:
        stamp(im, x, y, rows, UNRIPE if unripe else None)
    return im


def build():
    return [('green_coffee', green_coffee()), ('roasted_coffee', roasted_coffee())]


def check(new_states):
    states = {name: frames for name, _, frames in read_dmi(DMI)[1]}
    bad = [name for name, frame in new_states
           if name not in states or len(states[name]) != 1 or states[name][0].tobytes() != frame.tobytes()]
    if bad:
        sys.exit('icons/obj/food/food.dmi is stale for: %s; rerun create_coffee.py' % ', '.join(bad))
    print('icons/obj/food/food.dmi matches create_coffee.py (%s)' % ', '.join(n for n, _ in new_states))


def preview(new_states, out):
    """Review sheet of the actual sprite pixels at 4x; not a gameplay screenshot."""
    old = next(frames[0] for name, _, frames in read_dmi(DMI)[1] if name == 'coffee')
    r, g, b, a = old.split()
    tinted = Image.merge('RGBA', [ch.point(lambda v, t=t: v * t // 255) for ch, t in zip((r, g, b), OLD_TINT)] + [a])
    cells = [('old coffee + tint', tinted)] + list(new_states)
    z, pad, label = 4, 12, 16
    cw, chh = S * z + pad, S * z + pad + label
    backs = [(214, 208, 190, 255), (96, 128, 72, 255), (34, 34, 38, 255)]
    img = Image.new('RGBA', (cw * len(cells) + pad, chh * len(backs) + pad), (60, 60, 64, 255))
    d = ImageDraw.Draw(img)
    for row, back in enumerate(backs):
        for col, (name, frame) in enumerate(cells):
            x, y = pad + col * cw, pad + row * chh
            d.text((x, y), name, fill=(235, 235, 220))
            d.rectangle((x, y + label, x + S * z - 1, y + label + S * z - 1), fill=back)
            img.alpha_composite(frame.resize((S * z, S * z), Image.NEAREST), (x, y + label))
            # actual size, bottom right of the cell
            img.alpha_composite(frame, (x + S * z - S, y + label + S * z - S))
    Path(out).parent.mkdir(parents=True, exist_ok=True)
    img.save(out)


if __name__ == '__main__':
    new = build()
    if '--check' in sys.argv:
        check(new)
    else:
        write_dmi(DMI, new)
    if '--preview' in sys.argv:
        preview(new, sys.argv[sys.argv.index('--preview') + 1])
