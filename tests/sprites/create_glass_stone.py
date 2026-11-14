"""Hand-placed sprites for the glassblowing bench and the mason's saw in
icons/obj/glass_stone_machines.dmi, each with its idle frame and its working
loop. Every pixel is placed by this script from a fixed palette (Pillow
only); no external or generated artwork.

Run with Pillow to reproduce the sheet. `--check` verifies the committed
sheet matches and `--preview <png>` writes an enlarged review sheet.
Released under Civ13 AGPL-3.0.
"""
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_clay_lime_fire import Frame, TIMBER, STONE, IRON, FIRE, grain, plank, post  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/glass_stone_machines.dmi'

# clear glass: glint, light, mid, shade
GLASS = [(236, 250, 252), (176, 222, 230), (126, 186, 200), (84, 140, 158)]
# saw steel: glint, light, mid, dark
STEEL = [(240, 244, 248), (194, 202, 212), (144, 154, 168), (96, 104, 120)]
# pale cut stone: highlight, light, mid, dark
ASHLAR = [(226, 222, 208), (198, 194, 180), (166, 162, 150), (128, 124, 116)]
WATER = [(120, 170, 214), (72, 118, 176)]
DUST = [(232, 228, 216), (200, 196, 184)]


# ---------------------------------------------------- glassblowing bench --

def glass_bench(step=None):
    """A glassblower's bench: two long arm rails to roll the pipe on, an iron
    blowpipe across them, a stone marver and a water bucket. Working, a
    glowing gather swells on the end of the pipe."""
    f = Frame()
    # back legs and seat board
    post(f, 5, 15, 28)
    post(f, 25, 15, 28)
    plank(f, 4, 19, 27, 21, seed=3)
    plank(f, 6, 25, 25, 26, seed=5, base=3)
    # the two arm rails, running back to front on either side
    plank(f, 3, 12, 28, 13, seed=7, base=1)
    f.hline(3, 28, 14, TIMBER[3])
    # marver: a flat stone slab on the seat board
    f.rect(8, 17, 15, 18, STONE[1])
    f.hline(8, 15, 17, STONE[0])
    f.hline(8, 15, 19, STONE[3])
    # water bucket at the foot
    f.rect(18, 23, 23, 27, TIMBER[2])
    f.vline(18, 23, 27, TIMBER[1])
    f.vline(23, 23, 27, TIMBER[4])
    f.hline(18, 23, 25, IRON[1])
    f.hline(19, 22, 23, WATER[0])
    f.put(20, 23, (200, 226, 244))
    # blowpipe lying across the rails
    roll = 0 if step is None else step % 2
    f.hline(2, 24, 10 + roll, IRON[1])
    f.hline(2, 24, 9 + roll, IRON[0])
    f.pts(TIMBER[1], (1, 9 + roll), (1, 10 + roll), (0, 9 + roll), (0, 10 + roll))   # mouthpiece
    if step is None:
        # a finished bottle cooling on the board
        f.rect(18, 15, 20, 18, GLASS[1])
        f.vline(18, 15, 18, GLASS[0])
        f.vline(20, 15, 18, GLASS[3])
        f.pts(GLASS[2], (19, 13), (19, 14))
        f.put(19, 12, GLASS[0])
    else:
        # the gather: a hot bubble that swells and cools a shade each frame
        r = (2, 3, 4, 3)[step % 4]
        cx, cy = 26, 9 + roll
        for y in range(cy - r, cy + r + 1):
            for x in range(cx - r, cx + r + 1):
                d = (x - cx) ** 2 + (y - cy) ** 2
                if d <= r * r:
                    heat = 0 if d <= 1 else (1 if d <= r * r // 2 else 2)
                    if (x - cx) > r // 2 and heat < 3:
                        heat += 1
                    f.put(x, y, FIRE[min(3, heat)])
        f.put(cx - 1, cy - 1, FIRE[0])
    f.outline()
    return f


# ----------------------------------------------------------- mason's saw --

def masons_saw(step=None):
    """A stone block on two timber trestles under a two-handed frame saw.
    Working, the saw strokes back and forth and sheds pale dust."""
    f = Frame()
    slide = 0 if step is None else (0, 2, 4, 2)[step % 4]
    # trestles
    for x in (5, 23):
        post(f, x, 21, 28)
        post(f, x + 3, 21, 28, wide=1)
    plank(f, 3, 20, 28, 21, seed=3, base=3)
    # the block: lit top face, front face with a few bedding lines
    for y in range(11, 20):
        for x in range(6, 26):
            c = ASHLAR[1]
            if y <= 12:
                c = ASHLAR[0]
            elif y >= 18:
                c = ASHLAR[3]
            elif grain(x // 2, y, 9) == 0:
                c = ASHLAR[2]
            f.put(x, y, c)
    f.vline(25, 13, 19, ASHLAR[3])
    # the kerf already cut, and the slab it frees on the right
    f.vline(19, 11, 16, STONE[4])
    f.vline(20, 11, 12, ASHLAR[2])
    # frame saw: top bar, two uprights, the blade down in the kerf
    left = 10 + slide
    plank(f, left - 1, 3, left + 13, 4, seed=5, base=1)
    f.vline(left, 5, 13, TIMBER[2])
    f.vline(left + 12, 5, 13, TIMBER[3])
    f.hline(left - 2, left, 9, TIMBER[1])          # near handle
    f.hline(left + 12, left + 14, 9, TIMBER[1])    # far handle
    # tension cord and toggle
    f.hline(left + 1, left + 11, 6, (210, 196, 150))
    f.pts(TIMBER[3], (left + 6, 5), (left + 6, 7))
    # blade with teeth along its lower edge
    f.hline(left + 1, left + 11, 13, STEEL[1])
    for x in range(left + 1, left + 12):
        f.put(x, 14, STEEL[2] if (x + slide) % 2 else STEEL[3])
    f.put(left + 2, 13, STEEL[0])
    if step is not None:
        k = step % 4
        f.pts(DUST[0], (18 + k % 2, 17), (20, 18 + k % 2), (17, 19))
        f.pts(DUST[1], (19, 20), (21 - k % 2, 19), (18, 21), (20 + k % 2, 22))
    f.outline()
    return f


def states():
    """[(state, frames, delay)] in sheet order."""
    return [
        ('glass_bench', [glass_bench()], 0),
        ('glass_bench_on', [glass_bench(i) for i in range(4)], 3),
        ('masons_saw', [masons_saw()], 0),
        ('masons_saw_on', [masons_saw(i) for i in range(4)], 2),
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
        print('glass and stone sheet matches')
    else:
        write_dmi()
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
