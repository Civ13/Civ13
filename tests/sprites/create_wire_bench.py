"""Hand-placed sprites for the wire drawing bench in icons/obj/wire_bench.dmi,
standing still and drawing. Every pixel is placed by this script from a fixed
palette (Pillow only); no external or generated artwork.

Run with Pillow to reproduce the sheet. `--check` verifies the committed
sheet matches and `--preview <png>` writes an enlarged review sheet.
Released under Civ13 AGPL-3.0.
"""
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_clay_lime_fire import Frame, TIMBER, IRON  # noqa: E402
from create_machine_shop import STEEL  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/wire_bench.dmi'

# drawn copper: light, mid, shade
COPPER = [(240, 160, 104), (204, 116, 66), (150, 78, 42)]


def wire_bench(step=None):
    """A long plank bench on four legs: a rod and tongs at the left, an
    upright iron draw plate in the middle and a capstan with a crank at the
    right, winding the drawn wire. Drawing, the capstan turns, the coil on
    it grows and the wire shimmers."""
    f = Frame()
    k = 0 if step is None else step % 4
    on = step is not None
    # bench top and legs
    f.rect(1, 19, 30, 21, TIMBER[2])
    f.hline(1, 30, 19, TIMBER[0])
    f.hline(1, 30, 21, TIMBER[4])
    for x in (3, 13, 20, 27):
        f.rect(x, 22, x + 1, 29, TIMBER[3])
        f.vline(x, 22, 29, TIMBER[2])
    f.hline(4, 27, 26, TIMBER[3])
    # draw plate on its block
    f.rect(12, 16, 16, 18, TIMBER[3])
    f.rect(13, 9, 15, 17, IRON[1])
    f.vline(13, 9, 17, IRON[0])
    f.vline(15, 9, 17, IRON[2])
    f.pts(IRON[2], (14, 11), (14, 15))
    f.put(14, 13, COPPER[0] if on else IRON[2])
    # thick rod waiting at the left, tongs beside it
    f.hline(3, 12, 13, COPPER[1])
    f.hline(3, 12, 14, COPPER[2])
    f.hline(3, 9, 17, IRON[1])
    f.put(10, 16, IRON[0])
    f.put(10, 18, IRON[0])
    # capstan: a drum on a spindle, with the coil and the crank
    f.rect(22, 10, 27, 18, TIMBER[2])
    f.vline(22, 10, 18, TIMBER[1])
    f.vline(27, 10, 18, TIMBER[4])
    f.hline(21, 28, 9, IRON[1])
    f.hline(21, 28, 18, IRON[2])
    turns = 2 + (k if on else 0)
    for i in range(min(turns, 5)):
        f.hline(22, 27, 16 - i, COPPER[i % 2])
    f.vline(24, 5, 8, IRON[1])
    arm = ((4, 0), (3, 2), (-4, 0), (-3, 2))[k] if on else (4, 0)
    for i in range(1, abs(arm[0]) + 1):
        f.put(24 + (i if arm[0] > 0 else -i), 5 + arm[1] * i // abs(arm[0]), IRON[0])
    f.put(24 + arm[0], 4 + arm[1], TIMBER[0])
    # thin drawn wire from the plate to the drum
    for x in range(16, 22):
        f.put(x, 13, COPPER[0] if (not on or (x + k) % 3) else STEEL[0])
    f.outline()
    return f


def states():
    """[(state, frames, delay)] in sheet order."""
    return [
        ('wire_bench', [wire_bench()], 0),
        ('wire_bench_on', [wire_bench(i) for i in range(4)], 3),
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
        print('wire bench sheet matches')
    else:
        write_dmi()
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
