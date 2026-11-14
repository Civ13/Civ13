"""Original hand-placed 32px art for five plain necklaces and a tintable pendant.

Every pixel comes from the fixed palettes and the coordinate lists in this
file; there is no external, traced or generated artwork. Released under
Civ13's AGPL-3.0 licence. Run with Pillow from the repository root:

    python3 tests/sprites/create_necklaces.py [--preview sheet.png]

It writes two files with the same state names, in this order:
cord_necklace, bead_necklace, copper_necklace, silver_necklace,
gold_necklace, necklace_pendant.

- icons/obj/necklaces.dmi: inventory icons, one direction, one frame. All five
  loops share one outline whose lowest pixel is (16, 24) from the top-left;
  necklace_pendant is a 3x4 light greyscale setting just below it (x 15-17,
  y 25-28) so it lines up over any loop and takes a colour tint.
- icons/mob/necklaces.dmi: worn overlays, four directions (SOUTH, NORTH, EAST,
  WEST), one frame. The loop sits on the neck (y 9-10) and drops to the chest
  (y 13) in front; the back view shows only the strand across the nape and
  the side views a thin line from nape to chest. necklace_pendant is two
  greyscale pixels under the lowest point and is empty from the north.

To change the look, edit this script and rerun it; do not hand-edit the DMIs.
"""
import sys
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_belt_pouches import figure, write_dmi  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OBJ = ROOT / 'icons/obj/necklaces.dmi'
MOB = ROOT / 'icons/mob/necklaces.dmi'
S = 32

# strand colours: light, mid, dark
STRAND = {
    'cord_necklace': ('#b98450', '#8c5c30', '#5c3819'),
    'bead_necklace': ('#f3eedd', '#d3caae', '#a2977a'),
    'copper_necklace': ('#f2a878', '#c6703e', '#8a4622'),
    'silver_necklace': ('#f5f7f9', '#b9bfc7', '#7c838c'),
    'gold_necklace': ('#ffe680', '#e0b02e', '#a67716'),
}
BEAD_CORD = '#7a5a34'
ORDER = tuple(STRAND) + ('necklace_pendant',)

# Left half of the inventory loop from the top centre down to the bottom
# centre; the right half mirrors it about x 16.
LOOP_LEFT = (
    (16, 6), (15, 6), (14, 6), (13, 7), (12, 7), (11, 8), (10, 9), (9, 10), (9, 11),
    (8, 12), (8, 13), (8, 14), (8, 15), (8, 16), (9, 17), (9, 18), (10, 19),
    (11, 20), (12, 21), (13, 22), (14, 23), (15, 23), (16, 24),
)
# Inventory pendant: bail, then a small set stone. Light greys only, so a
# multiply tint gives the stone's colour.
PENDANT = (
    (16, 25, '#bdbdbd'),
    (15, 26, '#d9d9d9'), (16, 26, '#ffffff'), (17, 26, '#cfcfcf'),
    (15, 27, '#c4c4c4'), (16, 27, '#ebebeb'), (17, 27, '#ababab'),
    (16, 28, '#9e9e9e'),
)

# Worn strand per direction, in order along the strand.
WORN_SOUTH = ((12, 10), (13, 11), (14, 12), (15, 13), (16, 12), (17, 11), (18, 10))
WORN_NORTH = ((13, 10), (14, 10), (15, 10), (16, 10), (17, 10))
WORN_EAST = ((14, 9), (15, 10), (16, 10), (17, 11), (18, 11), (19, 12))
WORN_PENDANT_SOUTH = ((15, 14, '#ffffff'), (15, 15, '#c8c8c8'))
WORN_PENDANT_EAST = ((19, 13, '#ffffff'), (19, 14, '#c8c8c8'))


def rgba(c):
    return (int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16), 255)


def plot(pixels):
    img = Image.new('RGBA', (S, S))
    for x, y, c in pixels:
        img.putpixel((x, y), rgba(c))
    return img


def mirrored(img):
    return img.transpose(Image.FLIP_LEFT_RIGHT)


def strand_pixels(name, path, lit, on_skin=False):
    """Colour each strand pixel: lit(i, x, y) says whether it faces the light."""
    light, mid, dark = STRAND[name]
    if on_skin and name in ('cord_necklace', 'copper_necklace'):
        light, mid = mid, dark  # skin-toned strands need the darker pair to show on a neck
    out = []
    for i, (x, y) in enumerate(path):
        if name == 'cord_necklace':            # solid cord
            c = light if lit(i, x, y) else mid
        elif name == 'bead_necklace':          # bead, cord, bead, cord
            c = (light if lit(i, x, y) else mid) if i % 2 == 0 else BEAD_CORD
        else:                                  # chain links alternate
            c = (light if i % 2 == 0 else mid) if lit(i, x, y) else (mid if i % 2 == 0 else dark)
        out.append((x, y, c))
    return out


def item(name):
    if name == 'necklace_pendant':
        return plot(PENDANT)
    # One continuous path so links and beads alternate all the way round.
    path = list(LOOP_LEFT) + [(32 - x, y) for x, y in reversed(LOOP_LEFT[1:-1])]
    px = strand_pixels(name, path, lambda i, x, y: x < 16 or y < 9)
    light, mid, dark = STRAND[name]
    if name == 'cord_necklace':
        # darker underside of the cord and a small knot with two ends at the top
        px += [(x, y, dark) for x, y in ((23, 13), (23, 14), (23, 15), (22, 18), (21, 19))]
        px += [(16, 5, mid), (15, 4, light), (17, 4, mid), (16, 6, dark)]
    elif name == 'bead_necklace':
        px += [(16, 6, BEAD_CORD), (16, 5, BEAD_CORD)]
    else:
        # a plain hook clasp at the top
        px += [(15, 6, dark), (16, 6, light), (17, 6, dark), (16, 5, mid)]
    return plot(px)


def worn(name):
    if name == 'necklace_pendant':
        east = plot(WORN_PENDANT_EAST)
        return [plot(WORN_PENDANT_SOUTH), Image.new('RGBA', (S, S)), east, mirrored(east)]
    south = plot(strand_pixels(name, WORN_SOUTH, lambda i, x, y: x <= 15, True))
    north = plot(strand_pixels(name, WORN_NORTH, lambda i, x, y: x <= 15, True))
    east = plot(strand_pixels(name, WORN_EAST, lambda i, x, y: y <= 10, True))
    return [south, north, east, mirrored(east)]


def tinted(img, colour):
    """What the game's colour tint does: multiply."""
    return ImageChops.multiply(img, Image.new('RGBA', img.size, rgba(colour)))


def preview(items, mobs, out, scale=4):
    cell, label = S * scale, 14
    tints = (None, ('ruby', '#ea323c'), ('emerald', '#1ea257'), ('sapphire', '#008bf9'))
    names = ORDER[:-1]
    col = 200
    top = len(tints) * (cell + label)
    img = Image.new('RGBA', (max(col * len(names) + col, cell * 8 + 100), top + len(names) * (cell + label)),
                    (34, 34, 40, 255))
    d = ImageDraw.Draw(img)
    for r, tint in enumerate(tints):
        y = r * (cell + label)
        for i, name in enumerate(names):
            icon = items[name].copy()
            if tint:
                icon.alpha_composite(tinted(items['necklace_pendant'], tint[1]))
            d.text((i * col + 4, y + 1), name + (' + %s' % tint[0] if tint else ''), fill=(235, 235, 235, 255))
            img.alpha_composite(icon.resize((cell, cell), Image.NEAREST), (i * col, y + label))
            img.alpha_composite(icon, (i * col + cell + 8, y + label + 48))
        pend = tinted(items['necklace_pendant'], tint[1]) if tint else items['necklace_pendant']
        d.text((len(names) * col + 4, y + 1), 'necklace_pendant' + (' tinted' if tint else ' (greyscale)'),
               fill=(235, 235, 235, 255))
        img.alpha_composite(pend.resize((cell, cell), Image.NEAREST), (len(names) * col, y + label))
    for r, name in enumerate(names):
        y = top + r * (cell + label)
        tint = tints[1 + r % 3]
        d.text((4, y + 1), '%s worn over a plain tunic: S N E W, then with a %s-tinted pendant, then 1x' % (name, tint[0]),
               fill=(235, 235, 235, 255))
        for half in range(2):
            for direction in range(4):
                fig = figure(direction, 'white_tunic')
                fig.alpha_composite(mobs[name][direction])
                if half:
                    fig.alpha_composite(tinted(mobs['necklace_pendant'][direction], tint[1]))
                img.alpha_composite(fig.resize((cell, cell), Image.NEAREST), ((half * 4 + direction) * cell, y + label))
                img.alpha_composite(fig, (8 * cell + 4 + direction * 22, y + label + 20 + half * 44))
    img.save(out)


def main(argv):
    items = {name: item(name) for name in ORDER}
    mobs = {name: worn(name) for name in ORDER}
    write_dmi(OBJ, items, 1)
    write_dmi(MOB, mobs, 4)
    print('wrote', OBJ.relative_to(ROOT), 'and', MOB.relative_to(ROOT))
    if '--preview' in argv:
        preview(items, mobs, argv[argv.index('--preview') + 1])


if __name__ == '__main__':
    main(sys.argv[1:])
