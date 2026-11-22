"""Hand-placed sprites for rope in icons/obj/materials.dmi.

"rope" is one coil of laid hemp rope seen from above and a little to the
south: three turns lying side by side, the twist of the strands showing as
slanted marks, the coil seized with a few round turns on its right and the
working end trailing out at the lower left. "rope_2", "rope_3" and "rope_4"
are bigger piles of the same coil (two leaning together, three stacked, a
heap). The old "rope" was a short stack of brown planks.

Other fibres (sinew, catgut, flax tow, grass cuttings, crude twine) borrow
"rope" and tint it with `color`, so the coil is drawn in a pale hemp ramp
that still reads after a multiply.

Every pixel is placed by this script from the fixed palette below (Pillow
only); no external or generated artwork. It replaces "rope" where it stands,
appends the three pile states and leaves every other state in the sheet
untouched.

Run with Pillow to write the sheet. `--check` verifies the committed sheet,
`--preview <png>` writes a review sheet on grass and dirt (`--before <dmi>`
adds the older sheet's rope). Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_brazier_fire import read_dmi, write_dmi  # noqa: E402
from create_tatara import GRASS, DIRT, ground  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/materials.dmi'
SIZE = 32
SUFFIXES = ('', '_2', '_3', '_4')

# hemp: glint, lit, mid, shade, deep
HEMP = [(244, 226, 184), (222, 196, 146), (192, 162, 112), (152, 122, 80), (110, 84, 54)]
EDGE = (64, 46, 30)
# the tarred twine of the seizing: lit, shade
TWINE = [(134, 96, 62), (92, 64, 42)]
# the tints of the fibres that borrow the coil, for the review sheet
TINTS = (('sinew', 0xDFC4AC), ('catgut', 0xE8D7B0), ('flax tow', 0xC0AA74),
         ('grass cuttings', 0x709744), ('crude twine', 0xA59A61))


def coil(cx, cy, rx=11.0, ry=9.0, turns=3, height=2, seize=0.42, flip=False, eye=False):
    """One coil as {(x, y): colour}: the top of the turns, the side of the
    coil that faces the viewer and the far inner wall seen through the eye.
    Each turn is two pixels wide, a lit strand and the groove beside it.
    `seize` is the angle of the seizing turns (None for a loose coil); `eye`
    fills the eye with shadow, for a coil lying on another."""
    k = rx / ry
    width = turns * 2.0
    r_in = rx - width
    top = {}
    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = x - cx, (y - cy) * k
            d = math.hypot(dx, dy)
            if not r_in <= d < rx:
                continue
            a = math.atan2(dy, dx)
            n = int((d - r_in) / 2.0)
            f = ((d - r_in) / 2.0) % 1.0
            lay = a * (r_in + n * 2.0 + 1.0) * (-1 if flip else 1) + n * 1.5   # along this turn
            mark = int(math.floor(lay)) % 3 == 0              # the lay of the strands
            lit = (-dx * 0.55 - dy * 0.83) / (d or 1.0)       # +1 faces the upper left light
            if f >= 0.5 and n < turns - 1:
                tone = 4                                      # the groove between two turns
            else:
                tone = 2 if mark else 1
                if lit > 0.5 and not mark:
                    tone = 0
            if lit < -0.5 and tone < 4:
                tone += 1
            if seize is not None:
                off = (a - seize + math.pi) % (2 * math.pi) - math.pi
                across = abs(off) * d
                if across < 1.5:
                    tone = TWINE[int(d - r_in) % 2]           # tarred twine, turn by turn
                elif across < 2.3:
                    tone = 5                                  # the bite of the seizing
            top[(x, y)] = tone
    out = {}
    for (x, y) in top:
        for h in range(1, height + 1):
            below = (x, y + h)
            if below in top or below in out:
                continue
            front = math.hypot(below[0] - cx, (below[1] - cy) * k) >= rx
            if front:
                out[below] = HEMP[2 + ((x + h) % 3 == 0) + (h == height)]   # rows of rope, marked by the lay
            elif h == 1:
                out[below] = HEMP[4]                          # the far wall, in the eye
    if eye:
        for y in range(SIZE):
            for x in range(SIZE):
                if (x, y) not in top and math.hypot(x - cx, (y - cy) * k) < r_in:
                    out.setdefault((x, y), EDGE)
    for p, tone in top.items():
        out[p] = tone if isinstance(tone, tuple) else (HEMP + [EDGE])[tone]
    return out


def tail(points):
    """The working end: a two-tone line of single pixels, frayed pale at its tip."""
    out = {}
    for i, p in enumerate(points):
        out[p] = HEMP[1] if i % 2 == 0 else HEMP[3]
    out[points[-1]] = HEMP[0]
    return out


class Frame:
    def __init__(self):
        self.px = {}

    def put(self, x, y, c):
        if 0 <= x < SIZE and 0 <= y < SIZE:
            self.px[(x, y)] = c

    def stamp(self, lump):
        """Lay a piece over what is drawn, ringed by the dark edge."""
        for (x, y) in lump:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if (x + dx, y + dy) not in lump:
                    self.put(x + dx, y + dy, EDGE)
        for (x, y), c in lump.items():
            self.put(x, y, c)

    def image(self):
        im = Image.new('RGBA', (SIZE, SIZE))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c + (255,))
        return im


# (pieces back to front) per pile
def rope(suffix):
    f = Frame()
    small = dict(rx=8.5, ry=6.6, turns=2)
    if suffix == '':
        f.stamp(tail([(8, 24), (7, 25), (6, 26), (5, 27), (5, 28), (6, 29), (7, 29)]))
        f.stamp(coil(16.0, 15.5))
    elif suffix == '_2':
        f.stamp(coil(11.5, 12.5, seize=2.6, flip=True, **small))
        f.stamp(tail([(25, 25), (26, 26), (27, 27), (28, 27), (29, 26)]))
        f.stamp(coil(19.5, 19.5, **small))
    elif suffix == '_3':
        for i in range(3):                               # a stack, bottom first
            f.stamp(coil(16.0, 20.0 - i * 4, seize=0.5 if i == 2 else None, flip=i == 1, height=3, eye=True, **small))
    else:
        for i in range(3):
            f.stamp(coil(10.5, 16.5 - i * 4, seize=2.6 if i == 2 else None, flip=i == 1, height=3, eye=True, **small))
        for i in range(3):
            f.stamp(coil(21.0, 20.0 - i * 4, seize=0.5 if i == 2 else None, flip=i != 1, height=3, eye=True, **small))
    return f


def drawn():
    """{state: image} for the four states this script owns."""
    return {'rope' + suffix: rope(suffix).image() for suffix in SUFFIXES}


def rebuild(states):
    art = drawn()
    out = [(name, keys, [art.pop(name)] if name in art else images) for name, keys, images in states]
    for suffix in SUFFIXES:                              # new piles go on the end
        name = 'rope' + suffix
        if name in art:
            out.append((name, {'dirs': '1', 'frames': '1'}, [art[name]]))
    return out


def check(states):
    problems = []
    have = {name: images for name, _, images in states}
    for name, image in drawn().items():
        if name not in have:
            problems.append('%s is missing' % name)
        elif len(have[name]) != 1 or have[name][0].tobytes() != image.tobytes():
            problems.append('%s differs from the drawn rope' % name)
    return problems


# -------------------------------------------------------------- review --

def tinted(im, rgb):
    r0, g0, b0 = rgb >> 16, (rgb >> 8) & 255, rgb & 255
    out = im.copy()
    for y in range(SIZE):
        for x in range(SIZE):
            r, g, b, a = im.getpixel((x, y))
            out.putpixel((x, y), (r * r0 // 255, g * g0 // 255, b * b0 // 255, a))
    return out


def preview(path, before=None, scale=6):
    art = drawn()
    rows = []
    if before:
        old = {name: images[0] for name, _, images in read_dmi(before)}['rope']
        rows.append(('before: rope', [old] * 4))
        rows.append(('before: tinted', [tinted(old, rgb) for _, rgb in TINTS[:4]]))
    rows.append(('rope 1 / 2+ / 8+ / 20+', [art['rope' + s] for s in SUFFIXES]))
    rows.append(('sinew, catgut, tow, grass', [tinted(art['rope'], rgb) for _, rgb in TINTS[:4]]))
    pad, label = 8, 170
    cell = SIZE * scale
    small = 4 * SIZE + pad
    out = Image.new('RGBA', (pad + label + 2 * (4 * cell + pad) + 2 * small, pad + len(rows) * (cell + pad)), (24, 24, 24, 255))
    pen = ImageDraw.Draw(out)
    for j, tones in enumerate((GRASS, DIRT)):
        back, back1 = ground(tones, scale), ground(tones, 1)
        for r, (name, images) in enumerate(rows):
            y = pad + r * (cell + pad)
            if j == 0:
                pen.text((pad, y + cell // 2 - 5), name, fill=(230, 230, 230, 255))
            for i, im in enumerate(images):
                tile = back.copy()
                tile.alpha_composite(im.resize((cell, cell), Image.NEAREST))
                out.paste(tile, (pad + label + j * (4 * cell + pad) + i * cell, y))
                tile = back1.copy()                      # and at game size
                tile.alpha_composite(im)
                out.paste(tile, (pad + label + 2 * (4 * cell + pad) + j * small + i * SIZE, y + cell // 2 - SIZE // 2))
    out.save(path)


def option(name):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else None


if __name__ == '__main__':
    states = read_dmi(SHEET)
    if '--check' in sys.argv:
        problems = check(states)
        for problem in problems:
            print(problem)
        print('rope sprites: %s' % ('FAIL' if problems else 'ok'))
        sys.exit(1 if problems else 0)
    if '--preview' in sys.argv:
        preview(option('--preview'), option('--before'))
        sys.exit(0)
    write_dmi(SHEET, rebuild(states))
    print('wrote %s' % SHEET)
