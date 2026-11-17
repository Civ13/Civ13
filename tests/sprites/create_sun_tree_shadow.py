#!/usr/bin/env python3
"""Draw the tree shadow blobs in icons/effects/sun_shadow.dmi (PROTOTYPE).

Three single-direction 64x64 states, each the ground shadow of a tree lying
straight up the sprite from its trunk base at the bottom centre (x 32, y 0):

  canopy  a short trunk and a lumpy round crown (broadleaf trees, palms)
  pine    a short trunk and a stepped cone
  bare    a trunk with a few limbs (dead, winter and destroyed trees, cacti)

The game (code/modules/1713/sun_shadows.dm) stretches the sprite by the sun's
height, turns it away from the sun and pins the bottom centre to the trunk, so
one sprite serves every phase of the day.

The shadow is a cool near-black. Its alpha comes from a 4x supersampled mask
that is blurred, more toward the tip (a real shadow's edge softens with
distance), and fades a little along its length. Plain Pillow drawing with
fixed numbers; nothing is random, so a rerun writes the same bytes.

  python3 tests/sprites/create_sun_tree_shadow.py                  write the sheet
  python3 tests/sprites/create_sun_tree_shadow.py --check          verify the committed sheet
  python3 tests/sprites/create_sun_tree_shadow.py --out <dmi>      write elsewhere
  python3 tests/sprites/create_sun_tree_shadow.py --preview <png>  also write a 4x review sheet
"""
import io
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/effects/sun_shadow.dmi'
SIZE = 64
SS = 4                      # supersampling
COLOUR = (9, 13, 24)        # cool near-black
PEAK = 168                  # alpha at the trunk base
TIP = 0.72                  # share of PEAK left at the far tip
BASE_X = 32.0

# Crown lumps: (x, height above the base, radius), in sprite pixels.
CANOPY = (
    (32.0, 39.0, 13.0), (23.5, 36.0, 8.5), (40.5, 35.5, 9.0), (26.0, 46.5, 8.5),
    (38.5, 47.0, 8.0), (32.0, 51.5, 7.5), (19.5, 42.0, 5.5), (45.0, 43.0, 5.5),
    (29.0, 29.5, 6.5), (36.5, 29.0, 6.0),
)
# Pine tiers: (height of the tier's foot, height of its tip, half width at the foot).
PINE = ((11.0, 34.0, 14.5), (22.0, 46.0, 11.5), (34.0, 58.0, 8.0))
# Bare limbs: (start height on the trunk, end x, end height, width).
LIMBS = (
    (20.0, 17.0, 35.0, 2.6), (24.0, 46.5, 40.0, 2.6), (31.0, 22.0, 50.0, 2.2),
    (35.0, 42.0, 54.0, 2.2), (27.0, 12.0, 44.0, 1.6), (30.0, 52.0, 47.0, 1.6),
    (40.0, 30.0, 58.5, 1.8),
)


def mask(shape):
    im = Image.new('L', (SIZE * SS, SIZE * SS), 0)
    d = ImageDraw.Draw(im)

    def pt(x, h):
        return (x * SS, (SIZE - h) * SS)

    def trunk(top, w0, w1):
        d.polygon([pt(BASE_X - w0, 0.5), pt(BASE_X + w0, 0.5), pt(BASE_X + w1, top), pt(BASE_X - w1, top)], fill=255)
        d.ellipse([pt(BASE_X - w0, 2.0), pt(BASE_X + w0, -1.0)], fill=255)

    if shape == 'canopy':
        trunk(30.0, 3.2, 2.2)
        for x, h, r in CANOPY:
            d.ellipse([pt(x - r, h + r), pt(x + r, h - r)], fill=255)
    elif shape == 'pine':
        trunk(14.0, 2.8, 2.2)
        for foot, tip, half in PINE:
            d.polygon([pt(BASE_X - half, foot), pt(BASE_X + half, foot), pt(BASE_X + 1.0, tip), pt(BASE_X - 1.0, tip)], fill=255)
            d.ellipse([pt(BASE_X - half, foot + 2.5), pt(BASE_X + half, foot - 2.5)], fill=255)
    else:
        trunk(44.0, 3.0, 1.4)
        for start, ex, eh, w in LIMBS:
            d.line([pt(BASE_X, start), pt(ex, eh)], fill=255, width=int(w * SS))
    return im


def draw(shape):
    m = mask(shape)
    near = m.filter(ImageFilter.GaussianBlur(1.1 * SS)).resize((SIZE, SIZE), Image.LANCZOS)
    far = m.filter(ImageFilter.GaussianBlur(2.6 * SS)).resize((SIZE, SIZE), Image.LANCZOS)
    out = Image.new('RGBA', (SIZE, SIZE))
    px = out.load()
    n = near.load()
    f = far.load()
    for y in range(SIZE):
        t = (SIZE - 1 - y) / float(SIZE - 1)      # 0 at the base, 1 at the tip
        for x in range(SIZE):
            cover = (n[x, y] * (1.0 - t) + f[x, y] * t) / 255.0
            a = int(round(PEAK * (1.0 - (1.0 - TIP) * t) * cover))
            if a >= 3:
                px[x, y] = COLOUR + (a,)
    return out


STATES = ('canopy', 'pine', 'bare')


def sheet_bytes():
    sheet = Image.new('RGBA', (SIZE * len(STATES), SIZE))
    for i, name in enumerate(STATES):
        sheet.paste(draw(name), (i * SIZE, 0))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = %d\n\theight = %d\n' % (SIZE, SIZE)
    for name in STATES:
        text += 'state = "%s"\n\tdirs = 1\n\tframes = 1\n' % name
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    buf = io.BytesIO()
    sheet.save(buf, format='PNG', pnginfo=meta, optimize=True)
    return buf.getvalue(), sheet


def main(argv):
    data, sheet = sheet_bytes()
    if '--check' in argv:
        if not SHEET.exists() or SHEET.read_bytes() != data:
            print('%s is out of date: rerun %s' % (SHEET.relative_to(ROOT), Path(__file__).name))
            return 1
        print('ok: %s matches' % SHEET.relative_to(ROOT))
        return 0
    target = Path(argv[argv.index('--out') + 1]) if '--out' in argv else SHEET
    target.write_bytes(data)
    print('wrote %s (%d bytes, %d states)' % (target, len(data), len(STATES)))
    if '--preview' in argv:
        grass = Image.new('RGBA', sheet.size, (104, 132, 62, 255))
        grass.alpha_composite(sheet)
        grass.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(argv[argv.index('--preview') + 1])
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
