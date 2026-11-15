"""Hand-placed sprites for the powered cranes in icons/obj/power_cranes.dmi:
the steam crane and the tower crane, each standing still and hauling. Every
pixel is placed by this script from a fixed palette (Pillow only); no external
or generated artwork.

Run with Pillow to reproduce the sheet. `--check` verifies the committed
sheet matches and `--preview <png>` writes an enlarged review sheet.
Released under Civ13 AGPL-3.0.
"""
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_clay_lime_fire import Frame, IRON, FIRE  # noqa: E402
from create_lifting import ROPE, CRATE  # noqa: E402
from create_machine_shop import STEEL, BRASS, STEAM  # noqa: E402
from create_mechanical_power import line  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/power_cranes.dmi'

# painted lattice steel: light, mid, shade
PAINT = [(244, 196, 62), (208, 152, 36), (150, 104, 26)]
# counterweight concrete
BLOCK = [(176, 174, 168), (132, 130, 126)]


def crate(f, x, top):
    """A slung crate five wide, hung from x."""
    for y in range(top, top + 5):
        for cx in range(x - 2, x + 3):
            c = CRATE[1]
            if y == top or cx == x - 2:
                c = CRATE[0]
            if y == top + 4 or cx == x + 2:
                c = CRATE[2]
            f.put(cx, y, c)


def fall(f, x, y0, hook_y):
    for y in range(y0, hook_y):
        f.put(x, y, ROPE[0] if y % 2 else ROPE[1])
    f.pts(IRON[1], (x, hook_y), (x, hook_y + 1), (x + 1, hook_y + 2), (x, hook_y + 3), (x - 1, hook_y + 2))


# ------------------------------------------------------------ steam crane --

def steam_crane(step=None):
    """A crane on an iron carriage: an upright boiler with a chimney at the
    left, the winding engine at its foot and a braced iron jib raking up to
    the right. Hauling, the fire glows, steam blows and a crate climbs."""
    f = Frame()
    k = 0 if step is None else step % 4
    # carriage
    f.rect(2, 26, 22, 28, IRON[1])
    f.hline(2, 22, 26, IRON[0])
    f.hline(2, 22, 28, IRON[2])
    for x in (5, 18):
        f.rect(x, 28, x + 2, 30, IRON[2])
        f.put(x + 1, 29, STEEL[1])
    # upright boiler
    f.rect(3, 11, 9, 25, IRON[1])
    f.vline(3, 11, 25, IRON[0])
    f.vline(9, 11, 25, IRON[2])
    f.hline(3, 9, 11, STEEL[1])
    f.hline(3, 9, 16, BRASS[1])
    f.hline(3, 9, 21, BRASS[1])
    f.rect(5, 22, 7, 24, FIRE[2] if step is not None else IRON[2])
    if step is not None:
        f.put(6, 23, FIRE[k % 2])
    # chimney
    f.rect(5, 4, 7, 10, IRON[2])
    f.vline(5, 4, 10, IRON[1])
    f.hline(4, 8, 4, IRON[0])
    # winding drum and engine
    f.rect(11, 20, 16, 25, IRON[1])
    f.hline(11, 16, 20, STEEL[1])
    spoke = ((13, 21), (15, 22), (14, 24), (12, 23))[k]
    f.put(spoke[0], spoke[1], STEEL[0])
    f.put(13, 22, BRASS[0])
    # jib and its tie
    line(f, 14, 20, 28, 3, IRON[1])
    line(f, 15, 20, 29, 3, IRON[0])
    line(f, 9, 12, 28, 3, IRON[2])
    f.pts(STEEL[1], (28, 2), (29, 2), (29, 3))
    lift = 0 if step is None else (0, 2, 4, 6)[k]
    hook_y = (10 if step is None else 16) - lift
    fall(f, 29, 4, hook_y)
    if step is not None:
        crate(f, 29, hook_y + 4)
        puff = ((6, 2), (7, 1), (8, 0), (5, 1))[k]
        f.put(puff[0], puff[1], STEAM[0])
        f.put(puff[0] + 1, puff[1] + 1, STEAM[1])
    f.outline()
    return f


# ------------------------------------------------------------ tower crane --

def tower_crane(step=None):
    """A lattice mast on a ballasted foot with a cab at its head, a long jib
    to the right, a short counter-jib with a concrete weight to the left and
    a trolley on the jib. Hauling, a crate climbs under the trolley."""
    f = Frame()
    k = 0 if step is None else step % 4
    # foot and ballast
    f.rect(6, 27, 18, 29, BLOCK[1])
    f.hline(6, 18, 27, BLOCK[0])
    # lattice mast
    f.vline(10, 8, 26, PAINT[1])
    f.vline(14, 8, 26, PAINT[2])
    for y in range(9, 26, 4):
        line(f, 10, y, 14, y + 3, PAINT[0])
        f.hline(10, 14, y + 3, PAINT[2])
    # cab
    f.rect(9, 5, 15, 8, PAINT[1])
    f.hline(9, 15, 5, PAINT[0])
    f.rect(12, 6, 14, 7, (150, 196, 226))
    # apex and ties
    f.vline(12, 1, 4, PAINT[1])
    line(f, 12, 1, 27, 4, IRON[1])
    line(f, 12, 1, 3, 4, IRON[1])
    # jib and counter-jib
    f.hline(1, 30, 4, PAINT[0])
    f.hline(1, 30, 5, PAINT[2])
    for x in range(17, 30, 3):
        f.put(x, 5, PAINT[0])
    # counterweight
    f.rect(1, 6, 4, 9, BLOCK[1])
    f.hline(1, 4, 6, BLOCK[0])
    # trolley and fall
    tx = 25
    f.pts(IRON[0], (tx - 1, 6), (tx, 6), (tx + 1, 6))
    lift = 0 if step is None else (0, 3, 6, 9)[k]
    hook_y = (12 if step is None else 20) - lift
    fall(f, tx, 7, hook_y)
    if step is not None:
        crate(f, tx, hook_y + 4)
        f.put(13, 6, FIRE[1] if k % 2 else (150, 196, 226))    # cab lamp
    f.outline()
    return f


def states():
    """[(state, frames, delay)] in sheet order."""
    return [
        ('steam_crane', [steam_crane()], 0),
        ('steam_crane_haul', [steam_crane(i) for i in range(4)], 3),
        ('tower_crane', [tower_crane()], 0),
        ('tower_crane_haul', [tower_crane(i) for i in range(4)], 3),
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
        print('power cranes sheet matches')
    else:
        write_dmi()
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
