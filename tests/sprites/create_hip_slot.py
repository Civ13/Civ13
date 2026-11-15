"""Original hand-placed 32px art for the Hip inventory slot tile.

The slot that holds one hanging item (lantern, canteen, keys, a pouch) shows
a pouch hanging from a short length of belt. Every pixel comes from the glyph
layout and the per-style palettes in this file; there is no external, traced
or generated artwork. Released under Civ13's AGPL-3.0 licence. Run with
Pillow from the repository root:

    python3 tests/sprites/create_hip_slot.py [--check] [--preview sheet.png [--before DIR]]

It replaces the picture inside the "id" state of the four HUD style sheets in
icons/mob/screen/ and leaves the tile's frame, every other state, the state
order and the metadata text untouched. --check verifies the committed sheets
match this script. --before DIR takes the old sheets from DIR for the preview.

To change the look, edit this script and rerun it; do not hand-edit the DMIs.
"""
import re
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SCREEN = ROOT / 'icons/mob/screen'
S = 32
STATE = 'id'

# o = edge, m = body, l = lit leather, . = slot background.
GLYPH = (
    'ooooooooooooo',  # a length of belt
    'ommmmmmmmmmmo',
    'ooooooooooooo',
    '....oo.oo....',  # two hanging straps
    '....oo.oo....',
    '..ooooooooo..',  # the pouch flap
    '.olllllllllo.',
    '.olllllllllo.',
    '.ooolllllooo.',
    '.ommooooommo.',
    '.ommmmlmmmmo.',  # the button
    '.ommmmlmmmmo.',
    '.ommmmmmmmmo.',
    '.ommmmmmmmmo.',
    '..ommmmmmmo..',
    '...ooooooo...',
)
LEFT, TOP = 10, 8

# Each style: its glyph tones, and how to repaint the slot background where
# the old picture was. rows = two alternating stripe tones (even y, odd y);
# flat = one tone; halo = the dark base tone plus the speckle tone around the
# picture.
STYLES = {
    '1713Style': {'o': (123, 103, 85, 255), 'm': (132, 113, 96, 255), 'l': (151, 133, 116, 255),
                  'rows': ((91, 71, 54, 255), (85, 65, 49, 255)), 'area': (12, 10, 20, 19)},
    'ConsoleStyle': {'o': (201, 190, 168, 174), 'm': (217, 206, 182, 201), 'l': (250, 237, 210, 255),
                     'flat': None, 'area': (12, 10, 20, 19)},
    'litewebStyle': {'o': (17, 63, 12, 255), 'm': (27, 100, 19, 255), 'l': (53, 112, 34, 255),
                     'rows': ((27, 29, 26, 255), (39, 41, 37, 255)), 'area': (10, 7, 21, 22)},
    'FoFStyle': {'o': (105, 71, 39, 255), 'm': (139, 101, 52, 255), 'l': (149, 130, 56, 255),
                 'halo': ((34, 30, 28, 255), (50, 40, 38, 255)), 'area': (3, 5, 28, 25)},
}


def glyph_pixels():
    return {(LEFT + x, TOP + y): ch for y, row in enumerate(GLYPH) for x, ch in enumerate(row) if ch != '.'}


def speckle(x, y):
    """Fixed scatter for the FoF halo: the same pixels on every run."""
    return (x * 7 + y * 13 + (x * y) % 5) % 4 == 0


def paint(tile, style):
    """Returns the tile with the old picture removed and the hip glyph drawn."""
    tile = tile.copy()
    px = tile.load()
    x0, y0, x1, y1 = style['area']
    glyph = glyph_pixels()
    if 'rows' in style:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                px[x, y] = style['rows'][y % 2]
    elif 'flat' in style:
        flat = px[8, 8]  # the plain slot tone beside the picture
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                px[x, y] = flat
    else:
        base, dots = style['halo']
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                near = min(max(abs(x - gx), abs(y - gy)) for gx, gy in glyph)
                if near <= 1 or (near <= 2 and (x + y) % 2 == 0) or (near <= 5 and speckle(x, y)):
                    px[x, y] = dots
                else:
                    px[x, y] = base
    for (x, y), ch in glyph.items():
        px[x, y] = style[ch]
    return tile


def dmi_state_box(sheet, name):
    index, start = 0, None
    for state, dirs, frames in re.findall(r'state = "(.*?)"\n\tdirs = (\d+)\n\tframes = (\d+)',
                                          sheet.info.get('Description', '')):
        if state == name and start is None:
            start = index
        index += int(dirs) * int(frames)
    if start is None:
        raise SystemExit('state %r missing' % name)
    cols = sheet.width // S
    x, y = (start % cols) * S, (start // cols) * S
    return (x, y, x + S, y + S)


def redraw(path, style):
    sheet = Image.open(path)
    text = sheet.info.get('Description', '')
    rgba = sheet.convert('RGBA')
    box = dmi_state_box(sheet, STATE)
    old = rgba.crop(box)
    rgba.paste(paint(old, style), box)
    return rgba, text, old


def main(argv):
    check = '--check' in argv
    preview = argv[argv.index('--preview') + 1] if '--preview' in argv else None
    before_dir = Path(argv[argv.index('--before') + 1]) if '--before' in argv else None
    tiles = []
    for name, style in STYLES.items():
        path = SCREEN / (name + '.dmi')
        new, text, old = redraw(path, style)
        if before_dir:
            before = Image.open(before_dir / (name + '.dmi'))
            old = before.convert('RGBA').crop(dmi_state_box(before, STATE))
        current = Image.open(path).convert('RGBA')
        same = current.tobytes() == new.tobytes()
        if check:
            print('%s: %s' % (name, 'matches' if same else 'DIFFERS'))
            if not same:
                return 1
        elif not same:
            meta = PngImagePlugin.PngInfo()
            meta.add_text('Description', text, zip=True)
            new.save(path, format='PNG', pnginfo=meta, optimize=True)
            print('%s: redrawn' % name)
        else:
            print('%s: unchanged' % name)
        tiles.append((old, new.crop(dmi_state_box(Image.open(path), STATE))))
    if preview:
        scale = 8
        sheet = Image.new('RGBA', (len(tiles) * (S * scale + 8) + 8, 2 * (S * scale + 8) + 8), (58, 60, 70, 255))
        for i, pair in enumerate(tiles):
            for row, tile in enumerate(pair):
                big = tile.resize((S * scale, S * scale), Image.NEAREST)
                sheet.paste(big, (8 + i * (S * scale + 8), 8 + row * (S * scale + 8)), big)
        sheet.save(preview)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
