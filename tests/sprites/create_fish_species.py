"""Script-drawn fish for icons/obj/food/fish_species.dmi.

Every pixel is placed by this script from the pixel maps and fixed palettes
below (Pillow only); no external or generated artwork. The fish lie on their
side with the head to the left, like the cod in icons/obj/food/food.dmi.

States, all 32x32, 1 dir, 1 frame:

  trout, catfish, herring, tuna   The fresh fish.
  rotten_trout, rotten_catfish,   The same fish gone off: the same pixels with
  rotten_herring, rotten_tuna     every colour dulled toward a grey green.

Run with Pillow to rewrite the sheet (safe to rerun). `--out <dmi>` writes it
somewhere else, `--png <png>` writes an enlarged review picture, `--check`
only verifies that the committed sheet is what this script draws. Released
under Civ13 AGPL-3.0.
"""
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_water_animation import SIZE, read_dmi, write_dmi  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/food/fish_species.dmi'

EYE = (20, 22, 24)
ROT = (92, 102, 70)

# name: (pixel map, palette, top-left corner in the 32x32 tile)
FISH = {
    'trout': ((
        '..........ddd.........',
        '......oooodddooo.....t',
        '...ooOOkOOOOkOOOoo..tt',
        '.ooOkOOOOkOOOOkOOOottt',
        'oeOpppppppppppppppOttt',
        '.oOsssssssssssssso..tt',
        '..ssswwwwwwwwwss.....t',
        '....ff....ff..........',
    ), {'o': (74, 86, 52), 'O': (108, 120, 70), 'k': (48, 54, 36), 'p': (206, 120, 128), 's': (196, 200, 184),
        'w': (232, 232, 220), 'd': (86, 96, 58), 't': (92, 102, 62), 'f': (188, 150, 96), 'e': EYE}, (5, 12)),
    'catfish': ((
        '.............dd.........',
        '....bbbbbbbbbddbb.......',
        '..bbBBBBBBBBBBBBBbb....t',
        '.bBBBBBBBBBBBBBBBBBbb.tt',
        'beBBBBBBBBBBBBBBBBBBBttt',
        'bBBBggggggggggggggBb.ttt',
        'm.gggwwwwwwwwwggg.....tt',
        'm.m..ww.ff.....ff......t',
        '.m..m...................',
    ), {'b': (52, 48, 44), 'B': (84, 78, 68), 'g': (128, 122, 106), 'w': (204, 198, 178), 'd': (60, 56, 50),
        't': (64, 60, 54), 'f': (108, 100, 86), 'm': (40, 36, 34), 'e': (214, 196, 96)}, (4, 11)),
    'herring': ((
        '.......dd.......',
        '...gggggggg....t',
        '.ggGGGGGGGGgg.tt',
        'geGsssssssssGttt',
        '.sswwwwwwwwss.tt',
        '...ww..ff......t',
    ), {'g': (44, 82, 96), 'G': (78, 124, 136), 's': (188, 204, 210), 'w': (236, 242, 244), 'd': (58, 96, 108),
        't': (70, 110, 122), 'f': (150, 172, 180), 'e': EYE}, (8, 13)),
    'tuna': ((
        '...........dd...............',
        '..........ddd...............',
        '......nnnnnnnnnn..........t.',
        '...nnnNNNNNNNNNNnnn......tt.',
        '.nnNNNNNNNNNNNNNNNNnn...tt..',
        'neNNNNNNNNNNNNNNNNNNNnyytt..',
        'nNNNssssssssssssssssNnyyt...',
        '.nsssswwwwwwwwwwwsssss.ytt..',
        '..sswwwwwwwwwwwwwss.....tt..',
        '....www..ff....yy........tt.',
        '.........ff...............t.',
    ), {'n': (26, 44, 78), 'N': (48, 76, 120), 's': (168, 184, 198), 'w': (228, 234, 238), 'd': (30, 50, 86),
        't': (34, 54, 90), 'f': (60, 86, 126), 'y': (222, 184, 64), 'e': EYE}, (2, 10)),
}
ORDER = ('trout', 'catfish', 'herring', 'tuna')


def rotten(colour):
    """Dulled two thirds of the way toward a grey green, and a little darker."""
    return tuple(int((c + 2 * r) / 3 * 0.9) for c, r in zip(colour, ROT))


def draw(name, spoiled=False):
    rows, palette, (left, top) = FISH[name]
    im = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    for dy, row in enumerate(rows):
        for dx, c in enumerate(row):
            if c == '.':
                continue
            colour = palette[c]
            if spoiled and c != 'e':
                colour = rotten(colour)
            im.putpixel((left + dx, top + dy), colour + (255,))
    return im


def build():
    states = [(name, {'dirs': 1, 'frames': 1}, [draw(name)]) for name in ORDER]
    states += [('rotten_' + name, {'dirs': 1, 'frames': 1}, [draw(name, True)]) for name in ORDER]
    return states


def check_sheet(path, states):
    try:
        committed = read_dmi(path)
    except Exception as error:  # noqa: BLE001
        return ['cannot read %s: %s' % (path, error)]
    if [name for name, _, _ in committed] != [name for name, _, _ in states]:
        return ['states differ: sheet has %s' % [name for name, _, _ in committed]]
    return ['%s differs from the script' % name for (name, _, ims), (_, _, other) in zip(states, committed)
            if ims[0].tobytes() != other[0].convert('RGBA').tobytes()]


def write_png(path, states, scale=8):
    canvas = Image.new('RGBA', (SIZE * 4, SIZE * 2), (90, 90, 90, 255))
    for i, (_, _, ims) in enumerate(states):
        canvas.alpha_composite(ims[0], ((i % 4) * SIZE, (i // 4) * SIZE))
    canvas.resize((canvas.width * scale, canvas.height * scale), Image.NEAREST).save(path)


def option(name):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else None


def main():
    states = build()
    if '--check' in sys.argv:
        problems = check_sheet(option('--sheet') or SHEET, states)
        for problem in problems:
            print('FAIL: ' + problem)
        print('fish_species.dmi: %s' % ('%d problem(s)' % len(problems) if problems else 'matches the script'))
        return 1 if problems else 0
    out = option('--out') or SHEET
    write_dmi(out, states)
    print('wrote %s: %d states' % (out, len(states)))
    if option('--png'):
        write_png(option('--png'), states)
    return 0


if __name__ == '__main__':
    sys.exit(main())
