"""Hand-placed sprites for the ethanol distillery in icons/obj/distillery.dmi.
The old `distillery` and `distillery1` states of icons/obj/structures.dmi were
a flat barrel beside a dark lump on a grey strip; here it is a copper pot
still, drawn side on with the light at the upper left:

  distillery    a riveted copper pot on a field-stone firebox, a lyne arm
                running down into a hooped wooden worm tub full of cooling
                water, and a clay catch bowl under the tub's copper spout
  distillery1   the same with the fire lit: four frames of flame in the
                firebox, a drop falling from the spout into the bowl and a
                wisp of steam off the warm tub water

Every pixel is placed by this script from a fixed palette (Pillow only); no
external or generated artwork. The timber, stone, clay, iron and fire colours
are those of icons/obj/workshop_machines.dmi.

Run with Pillow to reproduce the sheet. `--check` verifies the committed sheet
matches, `--preview <png>` writes a before and after review sheet and
`--gif <gif>` writes the working loop enlarged.
Released under Civ13 AGPL-3.0.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_clay_lime_fire import Frame, TIMBER, STONE, CLAY, IRON, FIRE, SMOKE, SOOT  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/distillery.dmi'
OLD_SHEET = ROOT / 'icons/obj/structures.dmi'

# beaten copper: glint, light, mid, shade, deep
COPPER = [(250, 196, 140), (226, 146, 90), (190, 108, 64), (144, 74, 46), (98, 48, 36)]
SHINE = (255, 232, 196)
# cooling water in the tub: glint, mid, shade
WATER = [(168, 212, 228), (96, 154, 188), (60, 108, 148)]
SPIRIT = (222, 238, 240)
EMBER_STONE = (178, 128, 96)
STEAM = (238, 242, 242, 140)
DELAY = 1.5

# flame height in each firebox column (x 5..10) for the four working frames
FLAMES = ((1, 3, 4, 2, 3, 1), (2, 2, 3, 4, 2, 1), (1, 3, 2, 3, 4, 2), (2, 4, 3, 2, 2, 1))
# the wisp off the tub water, rising frame by frame
WISPS = (
    ((26, 10), (27, 10), (27, 9), (27, 8)),
    ((27, 9), (27, 8), (28, 8), (27, 7), (26, 6)),
    ((27, 8), (27, 7), (26, 7), (26, 6), (26, 5), (27, 5)),
    ((26, 10), (27, 6), (26, 5), (26, 4), (27, 4)),
)


def copper(nx, ny):
    """Ramp step for a rounded copper surface lit from the upper left."""
    v = nx * 0.6 + ny * 0.8
    if v < -0.62:
        return COPPER[0]
    if v < -0.2:
        return COPPER[1]
    if v < 0.3:
        return COPPER[2]
    if v < 0.72:
        return COPPER[3]
    return COPPER[4]


def firebox(f, step):
    """Coursed field stone with an arched stoke hole; `step` lights the fire."""
    for y in range(22, 30):
        row = (y - 22) // 2
        for x in range(2, 14):
            c = STONE[1] if (y - 22) % 2 == 0 else STONE[2]
            if (x + row * 2) % 4 == 0:
                c = STONE[3]
            if x == 13 or y == 29:
                c = STONE[3]
            if x == 2 and c != STONE[3]:
                c = STONE[0]
            f.put(x, y, c)
    f.hline(2, 12, 22, STONE[0])
    f.rect(5, 26, 10, 29, SOOT)
    f.hline(6, 9, 25, SOOT)
    if step is None:
        f.pts(TIMBER[4], (6, 29), (7, 29), (8, 29), (7, 28))
        f.pts(SMOKE[1], (9, 29), (5, 29))
        return
    for y in range(26, 30):                                  # stones in the firelight
        f.put(4, y, EMBER_STONE)
        f.put(11, y, EMBER_STONE)
    f.hline(6, 9, 24, EMBER_STONE)
    f.pts(EMBER_STONE, (5, 25), (10, 25))
    for i, h in enumerate(FLAMES[step]):
        x = 5 + i
        for k in range(h):
            y = 29 - k
            c = FIRE[1]
            if k == h - 1:
                c = FIRE[3]
            elif k == h - 2:
                c = FIRE[2]
            elif k == 0 and h >= 4:
                c = FIRE[0]
            f.put(x, y, c)


def pot(f):
    """The still: a round copper pot, a short neck, a helmet and the lyne arm."""
    f.ellipse(7.5, 16.5, 6, 5.6, lambda x, y, nx, ny: copper(nx, ny))
    for x in range(3, 13):                                   # riveted seam round the belly
        if (x, 17) in f.px:
            f.put(x, 17, COPPER[3] if x % 2 else COPPER[4])
    f.pts(SHINE, (4, 13), (5, 12), (4, 14))
    for y in range(9, 12):                                   # neck
        f.pts(COPPER[1], (6, y))
        f.pts(COPPER[2], (7, y), (8, y))
        f.pts(COPPER[4], (9, y))
    f.hline(5, 10, 11, COPPER[3])                            # collar
    f.put(5, 11, COPPER[1])
    f.ellipse(7.5, 6.5, 3, 2.6, lambda x, y, nx, ny: copper(nx, ny))
    f.put(6, 5, SHINE)
    # lyne arm: falls gently to the right, then drops into the worm tub
    for x in range(10, 24):
        y = 5 + (x - 10) * 4 // 13
        f.put(x, y, COPPER[1])
        f.put(x, y + 1, COPPER[3])
    f.put(10, 5, COPPER[0])
    for y in range(10, 13):
        f.put(23, y, COPPER[2])
        f.put(24, y, COPPER[4])
    f.put(24, 9, COPPER[3])


def worm_tub(f):
    """An open stave tub of cooling water with two iron hoops and stub feet."""
    for y in range(14, 29):
        for x in range(20, 30):
            c = TIMBER[1] if ((x - 20) // 2) % 2 == 0 else TIMBER[2]
            if (x - 20) % 2 == 1 and y % 5 == 2:
                c = TIMBER[3]                                # knots and joints
            if x == 20:
                c = TIMBER[0]
            if x >= 28:
                c = TIMBER[3]
            if y == 28:
                c = TIMBER[4]
            f.put(x, y, c)
    for y in (16, 25):                                       # hoops
        f.hline(20, 29, y, IRON[1])
        f.pts(IRON[0], (20, y), (21, y))
        f.pts(IRON[2], (28, y), (29, y))
    f.hline(21, 28, 11, TIMBER[1])                           # far rim
    f.hline(20, 29, 12, WATER[1])
    f.pts(WATER[0], (21, 12), (22, 12), (27, 12))
    f.pts(WATER[2], (25, 12), (28, 12))
    f.pts(TIMBER[1], (20, 12), (29, 12))
    f.hline(20, 29, 13, TIMBER[0])                           # near rim
    f.pts(TIMBER[2], (28, 13), (29, 13))
    f.pts(TIMBER[4], (21, 29), (22, 29), (27, 29), (28, 29))  # feet


def spout_and_bowl(f, step):
    f.pts(COPPER[1], (17, 22), (18, 22), (19, 22))
    f.put(17, 23, COPPER[3])
    # clay catch bowl
    f.hline(15, 18, 27, CLAY[0])
    f.hline(15, 18, 28, CLAY[1])
    f.put(18, 28, CLAY[3])
    f.pts(CLAY[2], (16, 29))
    f.put(17, 29, CLAY[3])
    if step is None:
        return
    if step == 0:
        f.put(17, 24, SPIRIT)                                # a drop gathers
    elif step == 1:
        f.put(17, 25, SPIRIT)
    elif step == 2:
        f.put(17, 26, SPIRIT)
    else:
        f.pts(SPIRIT, (16, 27), (17, 27))                    # and lands


def still(step=None):
    """One frame: idle when `step` is None, else working frame 0..3."""
    f = Frame()
    pot(f)
    firebox(f, step)
    worm_tub(f)
    # the arm's drop is drawn over the tub rim
    for y in range(10, 13):
        f.put(23, y, COPPER[2])
        f.put(24, y, COPPER[4])
    spout_and_bowl(f, step)
    f.outline()
    im = f.image()
    if step is not None:
        for x, y in WISPS[step]:
            if (x, y) not in f.px:
                im.putpixel((x, y), STEAM)
    return im


def states():
    """[(state, [frame images])] in sheet order."""
    return [
        ('distillery', [still()]),
        ('distillery1', [still(i) for i in range(4)]),
    ]


def build():
    frames = [im for _, ims in states() for im in ims]
    cols = int(len(frames) ** 0.5 + 0.999)
    rows = (len(frames) + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * 32, rows * 32))
    for i, im in enumerate(frames):
        sheet.paste(im, ((i % cols) * 32, (i // cols) * 32))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, ims in states():
        text += 'state = "%s"\n\tdirs = 1\n\tframes = %d\n' % (name, len(ims))
        if len(ims) > 1:
            text += '\tdelay = %s\n' % ','.join([str(DELAY)] * len(ims))
    text += '# END DMI\n'
    return sheet, text


def write_dmi():
    sheet, text = build()
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(SHEET, 'PNG', pnginfo=meta, optimize=True)


def check():
    sheet, text = build()
    old = Image.open(SHEET)
    return old.info.get('Description') == text and old.convert('RGBA').tobytes() == sheet.tobytes()


def old_frames(state):
    """The frames of a state in the shared structures sheet, for the preview."""
    sheet = Image.open(OLD_SHEET)
    index = count = 0
    name = None
    for line in sheet.info['Description'].split('\n'):
        if line.startswith('state = '):
            name = line[9:-1]
            dirs = 1
        elif line.startswith('\tdirs'):
            dirs = int(line.split('=')[1])
        elif line.startswith('\tframes'):
            count = dirs * int(line.split('=')[1])
            if name == state:
                break
            index += count
    cols = sheet.size[0] // 32
    rgba = sheet.convert('RGBA')
    out = []
    for i in range(index, index + count):
        x, y = (i % cols) * 32, (i // cols) * 32
        out.append(rgba.crop((x, y, x + 32, y + 32)))
    return out


GROUNDS = ((98, 122, 78, 255), (132, 100, 66, 255), (120, 118, 112, 255))


def preview(path, scale=6):
    """Idle and the four working frames, before and after, on grass, then the
    idle and first working frame on a wooden floor and stone, and at 1x."""
    pad, label = 8, 16
    big = 32 * scale
    cell = big + pad
    rows = (('BEFORE', old_frames('distillery') + old_frames('distillery1')),
            ('AFTER', [im for _, ims in states() for im in ims]))
    width = pad + 5 * cell + 2 * cell + 40 + pad
    out = Image.new('RGBA', (width, pad + 2 * (label + cell)), (24, 24, 24, 255))
    draw = ImageDraw.Draw(out)
    for r, (title, frames) in enumerate(rows):
        y = pad + r * (label + cell)
        draw.text((pad, y), title + ': idle, then the four working frames; idle on wood and working on stone; 1x',
                  fill=(230, 230, 230, 255))
        y += label
        shown = [(fr, GROUNDS[0]) for fr in frames] + [(frames[0], GROUNDS[1]), (frames[1], GROUNDS[2])]
        for i, (fr, bg) in enumerate(shown):
            tile = Image.new('RGBA', (big, big), bg)
            tile.alpha_composite(fr.resize((big, big), Image.NEAREST))
            out.paste(tile, (pad + i * cell, y))
        for i, fr in enumerate((frames[0], frames[1])):
            small = Image.new('RGBA', (32, 32), GROUNDS[0])
            small.alpha_composite(fr)
            out.paste(small, (pad + 7 * cell, y + i * 40))
    out.save(path)


def gif(path, scale=6):
    big = 32 * scale
    frames = []
    for im in states()[1][1]:
        tile = Image.new('RGBA', (big, big), GROUNDS[0])
        tile.alpha_composite(im.resize((big, big), Image.NEAREST))
        frames.append(tile.convert('P', palette=Image.ADAPTIVE))
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=int(DELAY * 100), loop=0)


if __name__ == '__main__':
    if '--check' in sys.argv:
        if not check():
            sys.exit('stale sheet: ' + str(SHEET))
        print('distillery sheet matches')
    else:
        write_dmi()
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
    if '--gif' in sys.argv:
        gif(sys.argv[sys.argv.index('--gif') + 1])
