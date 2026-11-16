"""Hand-placed sprites for the gilding dish in icons/obj/gilding_dish.dmi: a
shallow copper-lined clay dish with a rod laid across its rim. The states are
the dry dish, the dish filled with grape juice, each of those with a gold or
silver sheet folded over the rod, the dish with an item lowered in but
waiting for a charged cell, and the four-frame working loop with fine bubbles
rising round the item. Every pixel is placed by this script from a fixed
palette (Pillow only); no external or generated artwork. The clay colours are
those of the clay vase in icons/obj/claystuff.dmi, which is the jar cell the
dish stands beside.

Run with Pillow to write the sheet. `--check` verifies the committed sheet,
`--preview <png>` writes a 4x review sheet on grass and dirt with the dish
beside the jar cell, `--gif <path>` writes the working loops.
Released under Civ13 AGPL-3.0.
"""
import re
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_clay_lime_fire import Frame, TIMBER, grain  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/gilding_dish.dmi'
JAR_SHEET = ROOT / 'icons/obj/claystuff.dmi'

SIZE = 32
DELAY = 3              # deciseconds per frame of the working loop
FRAMES = 4

# fired clay, as the clay vase: highlight, light, mid, dark, deep, edge
CLAY = [(128, 84, 78), (109, 69, 66), (100, 55, 55), (88, 49, 55), (72, 40, 46), (54, 33, 37)]
# beaten copper lining: glint, light, mid, dark, deep
COPPER = [(232, 164, 108), (200, 124, 76), (166, 94, 58), (126, 68, 48), (92, 50, 42)]
VERDIGRIS = (98, 142, 118)
# grape juice: glint, light, mid, dark
JUICE = [(164, 84, 128), (118, 40, 84), (92, 26, 68), (68, 18, 54)]
METAL = {
    # glint, light, mid, dark
    'gold': [(255, 240, 150), (238, 198, 72), (198, 152, 42), (142, 102, 30)],
    'silver': [(248, 250, 252), (208, 214, 224), (160, 168, 182), (110, 116, 132)],
}
# the bare metal of the item being coated: light, dark
BARE = [(150, 122, 96), (104, 80, 66)]
THREAD = (196, 182, 150)
BUBBLE = (236, 214, 232)

CX, CY = 15.5, 19.5    # centre of the dish mouth
ROD_Y = 20             # the rod lies across the widest line of the rim
SHEET_X = (10, 13)     # columns the hung sheet covers
ITEM_X = 19            # column the lowered item hangs on


def under(c):
    """A colour seen through the juice."""
    return tuple((a + 2 * b) // 3 for a, b in zip(c, JUICE[2]))


def body(f):
    """The clay outside: a thick rim and a shallow wall down to a flat foot."""
    def rim(x, y, nx, ny):
        if ny < -0.4:
            return CLAY[1] if nx < 0.3 else CLAY[2]
        if nx < -0.5:
            return CLAY[1]
        return CLAY[2] if nx < 0.45 else CLAY[3]
    for y in range(20, 27):                       # the wall below the mouth
        t = (y - 19.5) / 7.0
        half = 8.6 - 4.0 * t ** 2.0
        for x in range(int(CX - half + 0.999), int(CX + half) + 1):
            nx = (x - CX) / half
            c = CLAY[2]
            if nx < -0.55:
                c = CLAY[1]
            elif nx > 0.7:
                c = CLAY[4]
            elif nx > 0.3:
                c = CLAY[3]
            if y == 26:
                c = CLAY[4] if nx < 0.3 else CLAY[5]     # the foot, in shade
            f.put(x, y, c)
    f.ellipse(CX, CY, 8.6, 4.5, rim)
    f.pts(CLAY[0], (8, 17), (9, 16), (10, 16))           # light on the lip
    f.pts(CLAY[0], (8, 23), (9, 24))                     # and on the belly


def lining(f):
    """The copper sheet beaten into the bowl, seen through the mouth."""
    def wall(x, y, nx, ny):
        # lit from the upper left, so the far right of the hollow is bright
        # and the near left lies under the shadow of the rim
        light = nx * 0.7 + ny * 0.6
        if ny < -0.5:
            return COPPER[4] if nx < 0.1 else COPPER[3]  # under the far rim
        if light < -0.4:
            return COPPER[3]
        if light < 0.3:
            return COPPER[2]
        return COPPER[1]
    f.ellipse(CX, CY, 7.0, 3.3, wall)
    f.hline(12, 18, 21, COPPER[1])                       # the flat floor
    f.hline(14, 17, 22, COPPER[2])
    f.pts(COPPER[0], (19, 21), (20, 19), (16, 22))       # hammer marks
    f.put(21, 18, VERDIGRIS)                             # a little verdigris


def juice(f):
    """Grape juice to just under the rim; the far lining still shows."""
    def pool(x, y, nx, ny):
        if ny < -0.45:
            return JUICE[3]                              # the rim's reflection
        if nx * 0.7 + ny * 0.6 > 0.4:
            return JUICE[1]
        return JUICE[2]
    f.ellipse(CX, CY + 0.4, 6.4, 2.6, pool)
    f.pts(JUICE[0], (15, 18), (16, 18), (20, 22))        # light on the surface


def rod(f):
    """A peeled stick laid across the rim to hang things from."""
    f.hline(6, 25, ROD_Y, TIMBER[1])
    f.pts(TIMBER[0], (6, ROD_Y), (7, ROD_Y), (15, ROD_Y), (16, ROD_Y))
    f.pts(TIMBER[2], (22, ROD_Y), (23, ROD_Y), (24, ROD_Y))
    f.put(25, ROD_Y, TIMBER[3])


def hung_sheet(f, metal, wet):
    """A sheet folded over the rod: a tab stands above it and the rest hangs
    into the dish, dimmed where it is under the juice."""
    m = METAL[metal]
    x0, x1 = SHEET_X
    for y in range(ROD_Y - 4, ROD_Y + 1):                # the tab and the fold
        for x in range(x0, x1 + 1):
            c = m[1] if x < x1 else m[2]
            if y == ROD_Y - 4:
                c = m[0] if x < x1 else m[1]
            elif x == x0:
                c = m[0]
            elif y == ROD_Y:
                c = m[2] if x < x1 else m[3]
            f.put(x, y, c)
    f.put(x0 + 2, ROD_Y - 2, m[0])                       # a glint
    for x in range(x0, x1 + 1):                          # the part in the dish
        c = m[2] if x < x1 else m[3]
        f.put(x, ROD_Y + 1, under(c) if wet else c)
    for x in range(x0 + 1, x1):                          # it follows the bowl
        f.put(x, ROD_Y + 2, under(m[2]) if wet else m[3])


def lowered_item(f, metal, coat):
    """A small ring hung on a thread in the juice. coat is how far the frame
    is into the loop: the new metal glints on a different side each frame."""
    m = METAL[metal]
    x = ITEM_X
    f.put(x, ROD_Y - 1, THREAD)                          # the knot on the rod
    f.put(x, ROD_Y, THREAD)
    ring = [(x - 1, ROD_Y + 1), (x, ROD_Y + 1), (x + 1, ROD_Y + 1), (x, ROD_Y + 2)]
    for i, (px, py) in enumerate(ring):
        f.put(px, py, under(BARE[0] if i < 3 else BARE[1]))
    if coat is not None:
        gx, gy = ring[coat % len(ring)]
        f.put(gx, gy, m[1])
        gx, gy = ring[(coat + 1) % len(ring)]
        f.put(gx, gy, under(m[1]))


def bubbles(f, step):
    """Fine bubbles climbing from the item to the surface and breaking."""
    k = step % FRAMES
    for bx, phase in ((ITEM_X - 2, 0), (ITEM_X + 2, 2)):
        rise = (k + phase) % FRAMES
        if rise == 3:
            continue                                     # it has burst
        f.put(bx, ROD_Y + 1 - rise - (rise > 0), BUBBLE if rise else JUICE[0])
    f.put(((16, 22), (21, 21), (17, 18), (21, 19))[k][0],
          ((16, 22), (21, 21), (17, 18), (21, 19))[k][1], BUBBLE)
    f.put(SHEET_X[1] + 1, ROD_Y + 1 - k % 2 * 2, JUICE[0])   # the sheet dissolving


def dish(wet=False, metal=None, item=False, step=None):
    f = Frame()
    body(f)
    lining(f)
    if wet:
        juice(f)
    rod(f)
    if metal:
        hung_sheet(f, metal, wet)
    if item:
        lowered_item(f, metal, step)
        if step is not None:
            bubbles(f, step)
    f.outline(CLAY[5])
    return f


def states():
    """[(state, frames, delay)] in sheet order."""
    out = [
        ('dish', [dish()], 0),
        ('dish_gold', [dish(metal='gold')], 0),
        ('dish_silver', [dish(metal='silver')], 0),
        ('dish_juice', [dish(wet=True)], 0),
        ('dish_juice_gold', [dish(wet=True, metal='gold')], 0),
        ('dish_juice_silver', [dish(wet=True, metal='silver')], 0),
    ]
    for metal in ('gold', 'silver'):
        out.append(('dish_%s_wait' % metal, [dish(wet=True, metal=metal, item=True)], 0))
        out.append(('dish_%s_on' % metal,
                    [dish(wet=True, metal=metal, item=True, step=i) for i in range(FRAMES)], DELAY))
    return out


# --------------------------------------------------------- sheet in/out --

def build():
    sheet = states()
    frames = [fr.image() for _, frs, _ in sheet for fr in frs]
    cols = int(len(frames) ** 0.5 + 0.999)
    rows = (len(frames) + cols - 1) // cols
    im = Image.new('RGBA', (cols * SIZE, rows * SIZE))
    for i, fr in enumerate(frames):
        im.paste(fr, ((i % cols) * SIZE, (i // cols) * SIZE))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, frs, delay in sheet:
        text += 'state = "%s"\n\tdirs = 1\n\tframes = %d\n' % (name, len(frs))
        if len(frs) > 1:
            text += '\tdelay = %s\n' % ','.join([str(delay)] * len(frs))
    return im, text + '# END DMI\n'


def write_dmi():
    im, text = build()
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    im.save(SHEET, 'PNG', pnginfo=meta, optimize=True)


def check():
    im, text = build()
    old = Image.open(SHEET)
    return old.info.get('Description') == text and old.convert('RGBA').tobytes() == im.tobytes()


# -------------------------------------------------------------- review --

GRASS = (98, 122, 78, 255)
DIRT = (122, 96, 70, 255)


def jar_cell():
    """The jar cell's sprite (the clay vase), read from its own sheet."""
    im = Image.open(JAR_SHEET)
    text = im.info['Description']
    im = im.convert('RGBA')
    at = 0
    for name, dirs, frames in re.findall(r'state = "([^"]*)"\n\tdirs = (\d+)\n\tframes = (\d+)', text):
        if name == 'clayvase':
            x, y = (at % (im.width // SIZE)) * SIZE, (at // (im.width // SIZE)) * SIZE
            return im.crop((x, y, x + SIZE, y + SIZE))
        at += int(dirs) * int(frames)
    raise SystemExit('no clayvase state in ' + str(JAR_SHEET))


def scene(frame, bg, scale):
    """The jar cell on one tile and the dish on the tile to its right."""
    tile = Image.new('RGBA', (2 * SIZE, SIZE), bg)
    tile.alpha_composite(jar_cell(), (0, 0))
    tile.alpha_composite(frame, (SIZE, 0))
    return tile.resize((2 * SIZE * scale, SIZE * scale), Image.NEAREST)


def preview(path, scale=4):
    """Row 1 and 2: every state (first frame) on grass and on dirt. Rows 3
    and 4: the jar cell beside the dish, dry, filled, hung and working."""
    sheet = states()
    firsts = [frs[0].image() for _, frs, _ in sheet]
    pad = 6
    cell = SIZE * scale + pad
    out = Image.new('RGBA', (pad + len(firsts) * cell, pad + 4 * cell), (24, 24, 24, 255))
    for j, bg in enumerate((GRASS, DIRT)):
        for i, fr in enumerate(firsts):
            tile = Image.new('RGBA', (SIZE * scale, SIZE * scale), bg)
            tile.alpha_composite(fr.resize((SIZE * scale, SIZE * scale), Image.NEAREST))
            out.paste(tile, (pad + i * cell, pad + j * cell))
    by_name = dict((n, frs) for n, frs, _ in sheet)
    shown = [by_name['dish'][0], by_name['dish_juice'][0], by_name['dish_juice_gold'][0],
             by_name['dish_gold_on'][1], by_name['dish_silver_on'][2]]
    for j, bg in enumerate((GRASS, DIRT)):
        for i, fr in enumerate(shown):
            out.paste(scene(fr.image(), bg, scale), (pad + i * 2 * cell, pad + (2 + j) * cell))
    out.save(path)


def gif(path, scale=6):
    """Both working loops beside the jar cell, on grass, at game speed."""
    by_name = dict((n, frs) for n, frs, _ in states())
    shots = []
    for k in range(FRAMES):
        shot = Image.new('RGBA', (4 * SIZE * scale, SIZE * scale))
        for j, metal in enumerate(('gold', 'silver')):
            shot.paste(scene(by_name['dish_%s_on' % metal][k].image(), GRASS, scale), (j * 2 * SIZE * scale, 0))
        shots.append(shot.convert('RGB'))
    shots[0].save(path, save_all=True, append_images=shots[1:], duration=DELAY * 100, loop=0)


if __name__ == '__main__':
    if '--check' in sys.argv:
        if not check():
            sys.exit('stale sheet: ' + str(SHEET))
        print('gilding dish states match')
    else:
        write_dmi()
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
    if '--gif' in sys.argv:
        gif(sys.argv[sys.argv.index('--gif') + 1])
