"""Hand-placed sprites for the earthworks machines in
icons/obj/earthworks.dmi: the steam roller and the steam shovel, each standing
still and working. Every pixel is placed by this script from a fixed palette
(Pillow only); no external or generated artwork.

Run with Pillow to reproduce the sheet. `--check` verifies the committed
sheet matches and `--preview <png>` writes an enlarged review sheet.
Released under Civ13 AGPL-3.0.
"""
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_clay_lime_fire import Frame, IRON, FIRE  # noqa: E402
from create_machine_shop import STEEL, BRASS, STEAM  # noqa: E402
from create_mechanical_power import line  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/earthworks.dmi'

# engine green paint: light, mid, shade
GREEN = [(96, 150, 96), (62, 112, 66), (40, 78, 46)]
# dug earth
EARTH = [(150, 110, 70), (112, 78, 46)]


def roll(f, cx, cy, r, k, moving):
    """A broad iron roll seen from the side, with a mark that turns."""
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            d = (x - cx) ** 2 + (y - cy) ** 2
            if d <= r * r + 1:
                f.put(x, y, IRON[0] if y < cy - r // 2 else IRON[2] if y > cy + r // 2 else IRON[1])
    f.put(cx, cy, BRASS[0])
    mark = ((0, -1), (1, 0), (0, 1), (-1, 0))[k if moving else 0]
    f.put(cx + mark[0] * (r - 1), cy + mark[1] * (r - 1), STEEL[0])


def boiler(f, x0, x1, y0, y1, fired, k):
    """A horizontal boiler with brass bands, a firebox door and a chimney."""
    f.rect(x0, y0, x1, y1, GREEN[1])
    f.hline(x0, x1, y0, GREEN[0])
    f.hline(x0, x1, y1, GREEN[2])
    for x in (x0 + 3, x1 - 3):
        f.vline(x, y0, y1, BRASS[1])
    f.rect(x0, y0 + 1, x0 + 1, y1 - 1, FIRE[2] if fired else IRON[2])
    if fired:
        f.put(x0, y0 + 2, FIRE[k % 2])


# ----------------------------------------------------------- steam roller --

def steam_roller(step=None):
    """A boiler on a frame with a wide front roll and a larger rear roll, a
    tall chimney, a canopy on posts and a stone hopper behind the chimney.
    Rolling, the rolls turn, the fire glows and smoke and steam blow."""
    f = Frame()
    k = 0 if step is None else step % 4
    on = step is not None
    # canopy
    f.hline(4, 24, 5, IRON[1])
    f.hline(4, 24, 6, IRON[2])
    f.vline(6, 7, 14, IRON[1])
    f.vline(22, 7, 14, IRON[1])
    # boiler and chimney
    boiler(f, 7, 25, 14, 19, on, k)
    f.rect(23, 7, 25, 13, IRON[2])
    f.vline(23, 7, 13, IRON[1])
    f.hline(22, 26, 7, IRON[0])
    # stone hopper
    f.rect(11, 10, 17, 13, IRON[1])
    f.hline(11, 17, 10, STEEL[1])
    f.pts((190, 188, 180), (12, 9), (14, 9), (16, 9))
    f.pts((156, 154, 146), (13, 9), (15, 9))
    # frame and rolls
    f.hline(6, 27, 20, IRON[2])
    roll(f, 9, 24, 5, k, on)
    roll(f, 25, 25, 4, k, on)
    if on:
        puff = ((24, 5), (25, 4), (26, 3), (23, 4))[k]
        f.put(puff[0], puff[1], STEAM[1])
        f.put(puff[0] + 1, puff[1] - 1, STEAM[0])
    f.outline()
    return f


# ----------------------------------------------------------- steam shovel --

def steam_shovel(step=None):
    """A cab with a boiler and chimney on a bed frame, a boom raking up to the
    right, and a dipper on its stick. Digging, the dipper swings down into the
    ground, comes up full and the fire glows."""
    f = Frame()
    k = 0 if step is None else step % 4
    on = step is not None
    # bed frame on four small wheels
    f.rect(2, 24, 18, 26, IRON[1])
    f.hline(2, 18, 24, IRON[0])
    f.hline(2, 18, 26, IRON[2])
    for x in (4, 14):
        f.rect(x, 27, x + 2, 29, IRON[2])
        f.put(x + 1, 28, STEEL[1])
    # cab
    f.rect(3, 12, 13, 23, GREEN[1])
    f.vline(3, 12, 23, GREEN[0])
    f.vline(13, 12, 23, GREEN[2])
    f.hline(2, 14, 11, IRON[1])
    f.rect(8, 14, 11, 17, (150, 196, 226))
    f.rect(5, 19, 7, 21, FIRE[2] if on else IRON[2])
    if on:
        f.put(6, 20, FIRE[k % 2])
    # chimney
    f.rect(5, 5, 7, 10, IRON[2])
    f.vline(5, 5, 10, IRON[1])
    f.hline(4, 8, 5, IRON[0])
    # boom
    line(f, 14, 22, 27, 6, IRON[1])
    line(f, 15, 22, 28, 6, IRON[0])
    line(f, 13, 12, 27, 6, STEEL[2])    # hoist rope
    # stick and dipper: rest, reach down, bite, lift full
    tip = ((26, 18), (27, 24), (24, 26), (25, 16))[k] if on else (26, 18)
    line(f, 22, 12, tip[0], tip[1], IRON[2])
    x, y = tip
    f.rect(x - 2, y, x + 2, y + 3, IRON[1])
    f.hline(x - 2, x + 2, y, IRON[0])
    f.pts(STEEL[0], (x - 2, y + 4), (x, y + 4), (x + 2, y + 4))    # teeth
    if on and k == 3:
        f.hline(x - 1, x + 1, y - 1, EARTH[0])
        f.put(x, y - 2, EARTH[1])
    if on and k in (1, 2):
        f.pts(EARTH[0], (29, 28), (22, 29))
        f.pts(EARTH[1], (30, 29), (21, 28))
    if on:
        puff = ((6, 3), (7, 2), (8, 1), (5, 2))[k]
        f.put(puff[0], puff[1], STEAM[1])
        f.put(puff[0] + 1, puff[1] - 1, STEAM[0])
    f.outline()
    return f


def states():
    """[(state, frames, delay)] in sheet order."""
    return [
        ('steam_roller', [steam_roller()], 0),
        ('steam_roller_on', [steam_roller(i) for i in range(4)], 2),
        ('steam_shovel', [steam_shovel()], 0),
        ('steam_shovel_on', [steam_shovel(i) for i in range(4)], 4),
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
        print('earthworks sheet matches')
    else:
        write_dmi()
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
