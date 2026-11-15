"""Hand-placed sprites for the rolling mill in icons/obj/rolling_mill.dmi:
two iron rolls in a pair of housings, standing still and rolling a glowing
bar. Every pixel is placed by this script from a fixed palette (Pillow only);
no external or generated artwork.

Run with Pillow to reproduce the sheet. `--check` verifies the committed
sheet matches and `--preview <png>` writes an enlarged review sheet.
Released under Civ13 AGPL-3.0.
"""
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_clay_lime_fire import Frame, TIMBER, IRON, FIRE  # noqa: E402
from create_machine_shop import STEEL, BRASS  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/rolling_mill.dmi'

# hot metal: white heat, orange, dull red
HOT = [(255, 236, 170), (250, 150, 48), (188, 70, 30)]


def rolling_mill(step=None):
    """Two housings on a timber sole with a screw-down on top of each, two
    rolls between them, a feed table at the front and a coupling spindle out
    to the right for the prime mover. Rolling, the roll highlights travel,
    a glowing bar passes through the bite and scale sparks off it."""
    f = Frame()
    k = 0 if step is None else step % 4
    # timber sole
    f.rect(2, 27, 29, 29, TIMBER[1])
    f.hline(2, 29, 27, TIMBER[0])
    f.hline(2, 29, 29, TIMBER[2])
    # the two housings
    for x in (4, 22):
        f.rect(x, 7, x + 4, 26, IRON[1])
        f.vline(x, 7, 26, IRON[0])
        f.vline(x + 4, 7, 26, IRON[2])
        f.hline(x, x + 4, 7, IRON[0])
        f.rect(x - 1, 24, x + 5, 26, IRON[1])
        f.hline(x - 1, x + 5, 24, IRON[0])
        f.hline(x - 1, x + 5, 26, IRON[2])
        # screw-down with its hand wheel
        f.vline(x + 2, 3, 6, STEEL[1])
        f.hline(x, x + 4, 3, BRASS[1])
        f.put(x + (k if step is not None else 0), 3, BRASS[0])
        # roll neck bearings
        f.rect(x + 1, 11, x + 3, 12, BRASS[2])
        f.rect(x + 1, 18, x + 3, 19, BRASS[2])
    # top and bottom rolls
    for top in (9, 16):
        f.rect(9, top, 21, top + 5, STEEL[1])
        f.hline(9, 21, top, STEEL[0])
        f.hline(9, 21, top + 5, STEEL[2])
        f.hline(9, 21, top + 4, STEEL[2])
        # a travelling highlight shows the roll turning
        row = top + 1 + (k if step is not None else 1) % 4
        f.hline(10, 20, row, STEEL[0])
    # coupling spindle to the prime mover
    f.rect(27, 17, 30, 19, IRON[1])
    f.hline(27, 30, 17, IRON[0])
    f.put(28 + (k % 2 if step is not None else 0), 18, STEEL[0])
    # feed table
    f.rect(10, 22, 20, 23, IRON[2])
    f.hline(10, 20, 22, IRON[1])
    if step is not None:
        # the bar in the bite, drawn out longer each pass
        length = (3, 5, 7, 9)[k]
        x0 = 15 - length // 2
        f.hline(x0, x0 + length, 15, HOT[1])
        f.hline(x0 + 1, x0 + length - 1, 15, HOT[0])
        f.put(x0, 15, HOT[2])
        f.put(x0 + length, 15, HOT[2])
        f.hline(9, 21, 14, FIRE[2])      # glow on the roll faces
        f.hline(9, 21, 16, FIRE[2])
        sparks = (((8, 14), (22, 16)), ((7, 13), (23, 15)), ((8, 16), (22, 13)), ((7, 15), (23, 17)))[k]
        f.pts(HOT[0], *sparks)
    f.outline()
    return f


def states():
    """[(state, frames, delay)] in sheet order."""
    return [
        ('rolling_mill', [rolling_mill()], 0),
        ('rolling_mill_on', [rolling_mill(i) for i in range(4)], 2),
    ]


def build():
    frames = [fr for _, frs, _ in states() for fr in frs]
    cols = int(len(frames) ** 0.5 + 0.999)
    rows = (len(frames) + cols - 1) // cols
    im = Image.new('RGBA', (cols * 32, rows * 32))
    for i, fr in enumerate(frames):
        im.paste(fr.image(), ((i % cols) * 32, (i // cols) * 32))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, frs, delay in states():
        text += 'state = "%s"\n\tdirs = 1\n\tframes = %d\n' % (name, len(frs))
        if len(frs) > 1:
            text += '\tdelay = %s\n' % ','.join([str(delay)] * len(frs))
    text += '# END DMI\n'
    return im, text


def write_dmi():
    im, text = build()
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    im.save(SHEET, 'PNG', pnginfo=meta, optimize=True)


def check():
    im, text = build()
    old = Image.open(SHEET)
    return old.info.get('Description') == text and old.convert('RGBA').tobytes() == im.tobytes()


def preview(path, scale=6):
    """Every state's frames on grass, stone, snow and night grounds."""
    grounds = ((98, 122, 78, 255), (120, 118, 112, 255), (226, 232, 238, 255), (30, 38, 52, 255))
    rows = [frs[:4] for _, frs, _ in states()]
    pad = 6
    cell = 32 * scale + pad
    out = Image.new('RGBA', (pad + 4 * 4 * cell, pad + len(rows) * cell), (24, 24, 24, 255))
    for j, frs in enumerate(rows):
        for g, bg in enumerate(grounds):
            for i, fr in enumerate(frs):
                tile = Image.new('RGBA', (32 * scale, 32 * scale), bg)
                tile.alpha_composite(fr.image().resize((32 * scale, 32 * scale), Image.NEAREST))
                if g == 3:
                    tile.alpha_composite(Image.new('RGBA', tile.size, (10, 14, 40, 90)))
                out.paste(tile, (pad + (g * 4 + i) * cell, pad + j * cell))
    out.save(path)


if __name__ == '__main__':
    if '--check' in sys.argv:
        if not check():
            sys.exit('stale sheet: ' + str(SHEET))
        print('rolling mill sheet matches')
    else:
        write_dmi()
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
