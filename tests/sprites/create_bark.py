"""The bark items of icons/obj/bark.dmi: `bark`, a slab of peeled tree bark,
and `bark_crushed`, a small loose heap of shredded tan bark chips.

`bark` is older hand-made art with no generator. This script does not redraw
it: it reads that frame from the committed sheet and writes it back
unchanged as the first state, and BARK_SHA256 pins its pixels so a change to
it is caught by `--check`. `bark_crushed` is drawn here in the five browns of
the `bark` frame, with no dark outline, like it: a low ragged mound of short
chips about 14x8 pixels in the lower middle of the tile, lit from the upper
left, with a few chips fallen clear of it.

The new art is drawn procedurally by this script: every pixel is placed from
a fixed palette (Pillow only); no external or generated artwork. Run it to
rewrite the sheet; `--check` verifies the committed sheet instead of writing
it, `--preview <png>` writes a 4x review sheet on grass and dirt. Released
under Civ13 AGPL-3.0.
"""
import hashlib
import sys
from pathlib import Path
from PIL import Image, ImageChops, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_transmission import grain  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/bark.dmi'

# the RGBA bytes of the hand-made `bark` frame this script carries over
BARK_SHA256 = 'ef301f0b516cdc27e874127c10e748873b5cb4fd60039beaf142a084fefe9dbe'

# the browns of the `bark` frame: highlight, light, mid, dark, deep
BARK = [(205, 204, 198, 255), (188, 184, 169, 255), (177, 156, 140, 255),
        (167, 133, 118, 255), (152, 103, 93, 255)]

# the heap, row by row from y = 18: (first column, last column)
HEAP_TOP = 18
HEAP_ROWS = ((14, 17), (12, 19), (11, 20), (10, 21), (9, 22), (9, 22), (9, 22), (10, 21))
# chips lying clear of the heap: (x, y, palette index)
LOOSE = ((7, 24, 3), (8, 24, 2), (24, 25, 2), (25, 25, 4), (22, 19, 3), (6, 26, 4), (19, 26, 3))


def old_bark():
    """The committed `bark` frame, pixel for pixel."""
    return Image.open(SHEET).convert('RGBA').crop((0, 0, 32, 32))


def bark_crushed():
    im = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
    for j, (x0, x1) in enumerate(HEAP_ROWS):
        y = HEAP_TOP + j
        for x in range(x0, x1 + 1):
            # short chips, two pixels long, lying every way: lighter up the
            # left of the mound, darker down its right and along the foot
            v = grain((x + (y % 2)) // 2, y, 3)
            idx = (1, 1, 2, 2, 2, 3, 3, 2, 3, 4, 4)[v]
            if x - x0 > (x1 - x0) * 2 // 3 or j >= 6:
                idx = min(4, idx + 1)
            if x == x0 or (j < 3 and x <= x0 + 1):
                idx = max(0, idx - 1)
            im.putpixel((x, y), BARK[idx])
    # the ragged foot: gaps between the lowest chips
    for x in (11, 15, 16, 20):
        im.putpixel((x, HEAP_TOP + 7), (0, 0, 0, 0))
    # bright chip edges catching the light, and dark gaps between chips
    for x, y in ((15, 18), (13, 19), (12, 21), (16, 20), (10, 22), (14, 23)):
        im.putpixel((x, y), BARK[0])
    for x, y in ((17, 19), (14, 21), (19, 22), (12, 23), (17, 24), (21, 23)):
        im.putpixel((x, y), BARK[4])
    for x, y, idx in LOOSE:
        im.putpixel((x, y), BARK[idx])
    return im


def states():
    """[(state, frame)] in sheet order; each is one frame, one direction."""
    return [('bark', old_bark()), ('bark_crushed', bark_crushed())]


def build_sheet(st):
    sheet = Image.new('RGBA', (32 * len(st), 32), (0, 0, 0, 0))
    for i, (_, im) in enumerate(st):
        sheet.paste(im, (i * 32, 0))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, _ in st:
        text += 'state = "%s"\n\tdirs = 1\n\tframes = 1\n' % name
    text += '# END DMI\n'
    return sheet, text


def write_dmi(path, st):
    sheet, text = build_sheet(st)
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta)


def check(path, st):
    sheet, text = build_sheet(st)
    old = Image.open(path)
    if old.info.get('Description') != text:
        sys.exit('%s: state list differs from the generator' % path)
    if old.size != sheet.size or ImageChops.difference(old.convert('RGBA'), sheet).getbbox():
        sys.exit('%s: pixels differ from the generator' % path)
    print('%s matches the generator' % path)


def preview(path, st, scale=4):
    """Each state at 4x on grass and on dirt, with true-size copies below."""
    grounds = ((94, 132, 62, 255), (122, 94, 62, 255))
    pad = 6
    cell = 32 * scale
    sheet = Image.new('RGBA', (pad + len(st) * (cell + pad),
                               pad + len(grounds) * (cell + pad) + 32 + pad), (40, 40, 40, 255))
    for j, ground in enumerate(grounds):
        for i, (_, im) in enumerate(st):
            tile = Image.new('RGBA', (32, 32), ground)
            tile.alpha_composite(im)
            x = pad + i * (cell + pad)
            sheet.paste(tile.resize((cell, cell), Image.NEAREST), (x, pad + j * (cell + pad)))
            sheet.paste(tile, (x + j * (32 + pad), pad + len(grounds) * (cell + pad)))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


if __name__ == '__main__':
    st = states()
    if hashlib.sha256(st[0][1].tobytes()).hexdigest() != BARK_SHA256:
        sys.exit('%s: the hand-made `bark` frame has changed' % SHEET)
    if '--check' in sys.argv:
        check(SHEET, st)
    else:
        write_dmi(SHEET, st)
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1], st)
