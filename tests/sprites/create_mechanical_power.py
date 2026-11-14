"""Hand-placed sprites for the prime movers in
icons/obj/mechanical_power.dmi: the treadwheel, horse gin, mill wheel and
windmill, each standing still and turning. Every pixel is placed by this
script from a fixed palette (Pillow only); no external or generated artwork.

Run with Pillow to reproduce the sheet. `--check` verifies the committed
sheet matches and `--preview <png>` writes an enlarged review sheet.
Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_clay_lime_fire import Frame, TIMBER, IRON, grain  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/mechanical_power.dmi'

# sailcloth: light, mid, shade
SAIL = [(238, 230, 208), (212, 202, 176), (176, 164, 138)]
# water and foam
WATER = [(120, 170, 214), (72, 118, 176), (226, 240, 250)]
# hemp rope
ROPE = [(226, 208, 160), (186, 164, 112)]


def line(f, x0, y0, x1, y1, c):
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(n + 1):
        f.put(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), c)


def wheel(f, cx, cy, r, phase, spokes=8, squash=1.0, tread=True):
    """A spoked timber wheel seen face-on: felloe, spokes at `phase`, hub."""
    for a in range(0, 360, 3):
        x = cx + r * math.cos(math.radians(a))
        y = cy + r * squash * math.sin(math.radians(a))
        f.put(round(x), round(y), TIMBER[1] if a > 180 else TIMBER[3])
        if tread:
            x2 = cx + (r - 1) * math.cos(math.radians(a))
            y2 = cy + (r - 1) * squash * math.sin(math.radians(a))
            f.put(round(x2), round(y2), TIMBER[2])
    for k in range(spokes):
        a = math.radians(phase + k * 360 / spokes)
        line(f, cx, cy, round(cx + (r - 2) * math.cos(a)), round(cy + (r - 2) * squash * math.sin(a)),
             TIMBER[2] if k % 2 else TIMBER[3])
    f.rect(cx - 1, cy - 1, cx + 1, cy + 1, IRON[1])
    f.put(cx, cy, IRON[0])


def trestle(f, x, y0, y1):
    f.vline(x, y0, y1, TIMBER[2])
    f.vline(x + 1, y0, y1, TIMBER[3])
    f.put(x, y0, TIMBER[1])


# ------------------------------------------------------------ treadwheel --

def treadwheel(step=None):
    """A wide walking wheel between two trestles, with treads on its rim."""
    f = Frame()
    phase = 0 if step is None else step * 11
    f.rect(3, 28, 28, 29, TIMBER[3])
    f.hline(3, 28, 28, TIMBER[1])
    wheel(f, 15, 15, 12, phase, spokes=8)
    # treads: short cleats inside the lower rim, creeping with the wheel
    for k in range(6):
        a = math.radians(25 + k * 26 + (phase % 26))
        x = 15 + 10 * math.cos(a)
        y = 15 + 10 * math.sin(a)
        f.put(round(x), round(y), TIMBER[0])
    trestle(f, 3, 14, 28)
    trestle(f, 27, 14, 28)
    f.hline(3, 28, 15, IRON[2])
    f.rect(14, 14, 16, 16, IRON[1])
    f.outline()
    return f


# -------------------------------------------------------------- horse gin --

def horse_gin(step=None):
    """A capstan post with a crown wheel on top and a long sweep with a
    whippletree at its end. Turning, the sweep swings round the post."""
    f = Frame()
    k = 0 if step is None else step % 4
    # trodden ring on the ground
    for a in range(0, 360, 12):
        f.put(round(16 + 13 * math.cos(math.radians(a))), round(24 + 5 * math.sin(math.radians(a))), (118, 96, 66))
    # the sweep behind the post for the far half of its turn
    ends = ((29, 24), (22, 28), (3, 24), (10, 20))
    ex, ey = ends[k]
    if k == 3:
        line(f, 16, 17, ex, ey, TIMBER[3])
    # post and footing
    f.rect(14, 12, 17, 26, TIMBER[2])
    f.vline(14, 12, 26, TIMBER[1])
    f.vline(17, 12, 26, TIMBER[4])
    f.rect(11, 26, 20, 28, TIMBER[3])
    f.hline(11, 20, 26, TIMBER[1])
    # crown wheel with pegs
    wheel(f, 16, 9, 8, k * 15, spokes=6, squash=0.45, tread=False)
    for a in range(0, 360, 30):
        x = 16 + 8 * math.cos(math.radians(a + k * 15))
        y = 9 + 3.6 * math.sin(math.radians(a + k * 15))
        f.put(round(x), round(y) - 1, TIMBER[0])
    # the sweep in front of the post, with its whippletree and traces
    if k != 3:
        line(f, 16, 17, ex, ey, TIMBER[1])
        line(f, 16, 18, ex, ey + 1, TIMBER[3])
    f.vline(ex, ey - 2, ey + 2, TIMBER[0])
    f.pts(ROPE[1], (ex + (1 if ex > 16 else -1), ey - 2), (ex + (1 if ex > 16 else -1), ey + 2))
    f.outline()
    return f


# ------------------------------------------------------------- mill wheel --

def mill_wheel(step=None):
    """An undershot paddle wheel on a timber frame over a wooden race.
    Turning, the paddles go round and the race foams."""
    f = Frame()
    phase = 0 if step is None else step * 9
    # the race: a trough of water under the wheel
    f.rect(1, 26, 30, 29, WATER[1])
    f.hline(1, 30, 26, WATER[0])
    f.hline(0, 31, 30, TIMBER[4])
    f.vline(0, 25, 30, TIMBER[3])
    f.vline(31, 25, 30, TIMBER[3])
    wheel(f, 16, 15, 12, phase, spokes=8)
    # paddles standing proud of the rim
    for kx in range(12):
        a = math.radians(phase + kx * 30)
        x0, y0 = 16 + 12 * math.cos(a), 15 + 12 * math.sin(a)
        x1, y1 = 16 + 14 * math.cos(a), 15 + 14 * math.sin(a)
        line(f, round(x0), round(y0), round(x1), round(y1), TIMBER[0] if y1 < 15 else TIMBER[3])
    trestle(f, 6, 14, 26)
    trestle(f, 24, 14, 26)
    f.hline(6, 25, 15, IRON[2])
    f.rect(15, 14, 17, 16, IRON[1])
    if step is not None:
        s = step % 4
        f.pts(WATER[2], (8 + s, 27), (14 + s, 28), (20 - s, 27), (25 - s, 28), (4 + s * 2, 28))
        f.pts(WATER[2], (11 + s, 25), (21 - s, 25))
    else:
        f.pts(WATER[0], (7, 28), (18, 28), (26, 27))
    f.outline()
    return f


# --------------------------------------------------------------- windmill --

def windmill(step=None):
    """A small post mill: a boarded buck on a trestle with four lattice sails
    on the windshaft. Turning, the sails sweep round."""
    f = Frame()
    phase = 20 if step is None else 20 + step * 22.5
    # trestle and post
    line(f, 9, 30, 15, 21, TIMBER[3])
    line(f, 23, 30, 17, 21, TIMBER[3])
    f.rect(15, 19, 17, 30, TIMBER[2])
    f.vline(15, 19, 30, TIMBER[1])
    f.hline(8, 24, 30, TIMBER[4])
    # the buck
    for y in range(9, 21):
        for x in range(10, 23):
            c = TIMBER[2]
            if x == 10:
                c = TIMBER[1]
            elif x == 22:
                c = TIMBER[4]
            elif (y - 9) % 3 == 2:
                c = TIMBER[3]
            f.put(x, y, c)
    for i in range(7):                              # pitched roof
        f.hline(10 + i, 22 - i, 8 - i, TIMBER[3] if i % 2 else TIMBER[4])
    f.rect(15, 15, 17, 20, TIMBER[4])               # door
    # sails
    cx, cy = 16, 11
    for kx in range(4):
        a = math.radians(phase + kx * 90)
        ca, sa = math.cos(a), math.sin(a)
        tipx, tipy = cx + 14 * ca, cy + 14 * sa
        line(f, cx, cy, round(tipx), round(tipy), TIMBER[0])
        # the cloth: a strip offset to the trailing side of the stock
        for d in range(4, 14):
            for w in (1, 2):
                x = cx + d * ca - w * sa
                y = cy + d * sa + w * ca
                f.put(round(x), round(y), SAIL[0] if w == 1 else (SAIL[1] if d % 3 else SAIL[2]))
    f.rect(cx - 1, cy - 1, cx + 1, cy + 1, IRON[1])
    f.put(cx, cy, IRON[0])
    f.outline()
    return f


def states():
    """[(state, frames, delay)] in sheet order."""
    return [
        ('treadwheel', [treadwheel()], 0),
        ('treadwheel_on', [treadwheel(i) for i in range(4)], 2),
        ('horse_gin', [horse_gin()], 0),
        ('horse_gin_on', [horse_gin(i) for i in range(4)], 5),
        ('mill_wheel', [mill_wheel()], 0),
        ('mill_wheel_on', [mill_wheel(i) for i in range(4)], 2),
        ('windmill', [windmill()], 0),
        ('windmill_on', [windmill(i) for i in range(4)], 2),
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
        print('mechanical power sheet matches')
    else:
        write_dmi()
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
