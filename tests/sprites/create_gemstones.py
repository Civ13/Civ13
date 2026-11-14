"""Original hand-placed 32px art for four cut and uncut gemstones.

Every pixel comes from the fixed palettes and the character stamps in this
file; there is no external, traced or generated artwork. The size class and
top-left lighting follow the Pocket Stronghold ruby/sapphire/diamond sprites
these sit next to. Released under Civ13's AGPL-3.0 licence. Run with Pillow
from the repository root:

    python3 tests/sprites/create_gemstones.py [--preview sheet.png] [--reference ores_gems.dmi]

It writes icons/obj/gemstones.dmi (all states 32x32, one direction, one frame):
emerald, emerald_uncut, amethyst, amethyst_uncut, topaz, topaz_uncut,
garnet, garnet_uncut.

To change the look, edit this script and rerun it; do not hand-edit the DMI.
"""
import re
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'icons/obj/gemstones.dmi'
S = 32

# Seven-step ramps, lightest first (stamp digits 0-6).
RAMPS = {
    'emerald': ('#d6ffdf', '#84eaa2', '#3fcb78', '#1ea257', '#127a40', '#0b552f', '#073521'),
    'amethyst': ('#f1dcff', '#d0a0f6', '#b071e6', '#8d4bcc', '#6a31a4', '#481f78', '#2c144e'),
    'topaz': ('#fff4c4', '#ffdb78', '#f7ba3c', '#df921c', '#b06a12', '#7c4610', '#4c2a0e'),
    'garnet': ('#f7b9bd', '#d95f70', '#ad2742', '#861532', '#640d29', '#430820', '#290517'),
}
# Grey host rock for the rough emerald (stamp letters a-d).
ROCK = {'a': '#a1a2a6', 'b': '#7c7d82', 'c': '#56565b', 'd': '#37373b'}

# name: (left, top, rows). '.' is transparent.
STAMPS = {
    # Step cut: rim, one step, a facet line, then the table with two glint stripes.
    'emerald': (10, 8, (
        '..11111112..',
        '.1222222234.',
        '120111111345',
        '121331330546',
        '121313300546',
        '121133003546',
        '121330033546',
        '121300333546',
        '121003333546',
        '121033333546',
        '121333334546',
        '121333344546',
        '121333444546',
        '125555555546',
        '.3444444456.',
        '..56666666..',
    )),
    # A six-sided prism shard standing in grey host rock, with loose bits.
    'emerald_uncut': (9, 10, (
        '....01........',
        '...0123.......',
        '...1123.......',
        '...1234..1....',
        '..a1234.023...',
        '.ab1234b124c.c',
        'abb2345b235cc.',
        'bbcc45ccc5cd..',
        '.cccddcddd....',
        '...........2.c',
        '..........35..',
    )),
    # Upright oval.
    'amethyst': (10, 9, (
        '...011112...',
        '..01222213..',
        '.0123333124.',
        '.1233003344.',
        '012330033245',
        '123300332345',
        '123003323345',
        '120033233345',
        '120332333455',
        '123323334455',
        '.2333334445.',
        '.4433444555.',
        '..45555556..',
        '...566666...',
    )),
    # A small cluster of pointed crystals.
    'amethyst_uncut': (10, 11, (
        '...0........',
        '..012..1....',
        '..123.023...',
        '.01234124...',
        '.12341235.2.',
        '012342345134',
        '.2345455.245',
        '..55.56.....',
        '..........4.',
        '.3.......35.',
    )),
    # Pear cut, point up.
    'topaz': (10, 8, (
        '.....01.....',
        '....0123....',
        '....1224....',
        '...012234...',
        '...122334...',
        '..01200334..',
        '..12003334..',
        '.0120033345.',
        '.1200332345.',
        '012033233445',
        '122332333445',
        '123323334455',
        '.2333334455.',
        '.4445555566.',
        '...566666...',
    )),
    # A stubby broken prism and chips.
    'topaz_uncut': (10, 12, (
        '..0011......',
        '.011223.....',
        '0112233.....',
        '12223344....',
        '122334445...',
        '.2334455..1.',
        '..34556..234',
        '....6.....5.',
        '.2..........',
    )),
    # Round cut.
    'garnet': (10, 10, (
        '....1112....',
        '..11222233..',
        '.1122333344.',
        '.1230013345.',
        '122300333455',
        '123003334455',
        '123033344455',
        '223333444556',
        '.3334445556.',
        '.3444455566.',
        '..45555666..',
        '....5666....',
    )),
    # A rounded many-sided pebble and two chips.
    'garnet_uncut': (11, 12, (
        '..0112....',
        '.011223...',
        '0122334...',
        '11233445..',
        '12334455..',
        '.3344556.2',
        '..45566.34',
        '........5.',
        '2.........',
    )),
}

ORDER = ('emerald', 'emerald_uncut', 'amethyst', 'amethyst_uncut',
         'topaz', 'topaz_uncut', 'garnet', 'garnet_uncut')


def rgba(c):
    return (int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16), 255)


def draw(name):
    ramp = RAMPS[name.split('_')[0]]
    left, top, rows = STAMPS[name]
    img = Image.new('RGBA', (S, S))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == '.':
                continue
            img.putpixel((left + x, top + y), rgba(ROCK[ch] if ch in ROCK else ramp[int(ch)]))
    return img


def write_dmi(path, states):
    sheet = Image.new('RGBA', (S * len(states), S))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = %d\n\theight = %d\n' % (S, S)
    for i, (name, img) in enumerate(states.items()):
        sheet.paste(img, (i * S, 0))
        text += 'state = "%s"\n\tdirs = 1\n\tframes = 1\n' % name
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta, optimize=True)


def read_states(path, wanted):
    """Single-frame states of another DMI, for the side-by-side review sheet."""
    sheet = Image.open(path)
    text = sheet.info.get('Description', '')
    sheet = sheet.convert('RGBA')
    cols, index, found = sheet.width // S, 0, {}
    for name, dirs, frames in re.findall(r'state = "(.*?)"\n\tdirs = (\d+)\n\tframes = (\d+)', text):
        if name in wanted:
            found[name] = sheet.crop(((index % cols) * S, (index // cols) * S,
                                      (index % cols) * S + S, (index // cols) * S + S))
        index += int(dirs) * int(frames)
    return found


def preview(states, out, reference=None, scale=4):
    rows = [('this script', states)]
    if reference:
        names = ('ruby', 'ruby_uncut', 'sapphire', 'sapphire_uncut', 'diamond', 'diamond_uncut')
        found = read_states(reference, names)
        rows.append(('Pocket Stronghold reference', {n: found[n] for n in names if n in found}))
    cell, label = S * scale, 14
    width = cell * max(len(r[1]) for r in rows)
    # 4x cells, then the same row at 1x.
    img = Image.new('RGBA', (width, len(rows) * (cell + label * 2 + S + 6)), (34, 34, 40, 255))
    d = ImageDraw.Draw(img)
    y = 0
    for title, row in rows:
        d.text((4, y + 2), title, fill=(200, 200, 200, 255))
        y += label
        for i, (name, tile) in enumerate(row.items()):
            img.alpha_composite(tile.resize((cell, cell), Image.NEAREST), (i * cell, y))
            d.text((i * cell + 4, y + cell), name, fill=(235, 235, 235, 255))
            img.alpha_composite(tile, (i * cell + cell // 2 - S // 2, y + cell + label))
        y += cell + label + S + 6
    img.save(out)


def main(argv):
    states = {name: draw(name) for name in ORDER}
    write_dmi(OUT, states)
    print('wrote', OUT.relative_to(ROOT), 'with', len(states), 'states')
    if '--preview' in argv:
        ref = argv[argv.index('--reference') + 1] if '--reference' in argv else None
        preview(states, argv[argv.index('--preview') + 1], ref)


if __name__ == '__main__':
    main(sys.argv[1:])
