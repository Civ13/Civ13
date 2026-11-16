"""Hand-placed sprites for gold-rush placer mining in icons/obj/placer.dmi:
the heap of wet pay dirt, the sluice box (a sloped plank trough on trestles
with cross riffle bars and a sheepskin fleece lining: dry, and a three-frame
running loop with muddy outflow at the low end) and the rocker or cradle (a
plank box on curved rockers with a perforated iron hopper and an upright
handle: idle and a two-frame rocking loop). Every pixel is placed by this
script from a fixed palette (Pillow only); no external or generated artwork.
The timber and muddy wash water are those of the kanna channel in
create_tatara.py, the iron is the mercury retort's from create_mercury.py and
the pebbles are the field stone of create_clay_lime_fire.py.

Run with Pillow to write the sheet. `--check` verifies the committed sheet,
`--preview <png>` writes a labelled 4x review sheet on grass and on dirt,
`--gif <path>` writes the running sluice loop.
Released under Civ13 AGPL-3.0.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_clay_lime_fire import TIMBER, STONE, grain  # noqa: E402
from create_tatara import Sprite, MUD, HOLE, GRASS, DIRT, ground  # noqa: E402
from create_mercury import IRON, IRON_EDGE  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/placer.dmi'

SIZE = 32
WATER_DELAY = 2        # deciseconds per frame, as kanna_channel_working
WATER_FRAMES = 3
ROCK_DELAY = 3
ROCK_FRAMES = 2

# wet river dirt: damp sheen, lit, mid, shade, deep
EARTH = [(150, 132, 112), (118, 94, 70), (94, 74, 56), (70, 56, 44), (50, 40, 34)]
EARTH_EDGE = (28, 22, 20)
# sheepskin fleece: lit curl, mid, shade, deep between the curls
FLEECE = [(240, 234, 212), (218, 208, 180), (186, 174, 144), (150, 138, 112)]
# running water: foam, light, mid, deep
WATER = [(226, 238, 240), (150, 188, 202), (110, 154, 176), (82, 122, 148)]
EDGE = (30, 20, 14)                      # the timber outline


# ------------------------------------------------------------- pay dirt --

PEBBLES = ((12, 19, 1), (19, 17, 0), (16, 22, 1), (22, 22, 2), (9, 23, 2), (15, 15, 1))


def pay_dirt():
    """A small slumped heap of wet gravelly river dirt, lit from the upper
    left: dark damp earth, grit and a few grey pebbles."""
    f = Sprite()
    cx, base, rx, h = 15.5, 24, 9.0, 10
    for x in range(7, 25):
        nx = (x - cx) / rx
        lump = (0, 1, 0, 0, 1, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 1, 0)[x - 7]
        top = int(round(base - h * (1.0 - nx * nx) ** 0.9)) + lump
        foot = base + int(round(1.8 * max(0.0, 1.0 - nx * nx) ** 0.5))
        for y in range(top, foot + 1):
            light = nx * 0.9 + (y - top) / float(h) * 0.6
            c = EARTH[1] if light < -0.25 else (EARTH[2] if light < 0.4 else EARTH[3])
            g = grain(x, y, 161)
            if g == 0:
                c = EARTH[4]                          # dark wet grit
            elif g == 1:
                c = STONE[3] if light > 0 else STONE[2]   # gravel
            elif g == 2 and light < 0.2:
                c = EARTH[0]                          # damp sheen
            if y == foot:
                c = EARTH[4]                          # the soaked foot
            f.put(x, y, c)
    for x, y, t in PEBBLES:                           # pebbles: lit top, dark under
        f.put(x, y, STONE[t])
        f.put(x + 1, y, STONE[t + 1])
        f.put(x, y + 1, STONE[t + 2])
        f.put(x + 1, y + 1, STONE[t + 2])
    f.outline(EARTH_EDGE)
    # clods and grit fallen round the foot, and the wet it stands in
    f.pts(EARTH[3], (5, 26), (26, 25), (20, 28), (11, 28))
    f.pts(STONE[2], (25, 27), (7, 27))
    for x in range(9, 23):
        if (x, 27) not in f.px and x % 3:
            f.put(x, 27, EARTH[4] + (110,))
    return f


# --------------------------------------------------------------- sluice --

X0, X1 = 1, 27                     # the trough, high end at the left
BARS = (5, 10, 15, 20, 25)         # left column of each riffle bar
LEGS = (3, 23)                     # left column of each near trestle leg


def drop(x):
    """How far the trough has fallen by column x."""
    return int((x - X0) * 0.24 + 0.5)


def sluice_box(step=None):
    """The trough seen from the front and above: far side board, the lined
    floor with its riffle bars, and the near side board standing on two
    trestles. With a step, water runs down it and spills off the low end."""
    f = Sprite()
    for lx in LEGS:                                   # trestle legs and feet
        top = 7 + drop(lx) + 13
        for y in range(top - 12, 30):
            f.put(lx, y, TIMBER[2] if grain(lx, y // 3, 171) else TIMBER[3])
            f.put(lx + 1, y, TIMBER[4])
        f.hline(lx - 1, lx + 2, 29, TIMBER[3])
        f.put(lx - 1, 29, TIMBER[2])
    for x in range(X0, X1 + 1):
        t = 7 + drop(x)
        f.put(x, t, TIMBER[0] if grain(x // 4, 0, 173) else TIMBER[1])     # far board, top edge
        f.put(x, t + 1, TIMBER[3])                    # its inner face, in shade
        f.put(x, t + 2, TIMBER[4])
        bar = [b for b in BARS if b <= x <= b + 1]
        for r in range(5):                            # the floor
            y = t + 3 + r
            if step is None:
                curl = grain(x, y, 175)
                c = FLEECE[0] if curl < 3 else (FLEECE[1] if curl < 8 else FLEECE[2])
                if grain(x // 2, y // 2, 177) == 0:
                    c = FLEECE[3]                     # parting between the curls
                if r == 0:
                    c = FLEECE[2] if curl < 8 else FLEECE[3]     # shaded by the far board
            else:
                run = (x - 2 * step + r * 2) % 6      # streaks run downhill
                c = WATER[2]
                if run < 2 and r % 2 == 0:
                    c = WATER[1]
                elif run == 3 and r in (1, 4):
                    c = WATER[3]
                elif run == 5 and r == 3:
                    c = FLEECE[2]                     # the fleece showing through
                if x > 13 and run == 4 and r % 2:
                    c = MUD[1]                        # mud carried in the flow
                if x > 20 and run == 2 and r != 2:
                    c = MUD[2]
                if r == 0:
                    c = WATER[3]
            if bar:
                c = TIMBER[0] if x == bar[0] else TIMBER[2]
                if step is not None and x != bar[0] and (r + step) % 3 == 0:
                    c = WATER[0]                      # water breaking over the bar
                if r == 0:
                    c = TIMBER[2] if x == bar[0] else TIMBER[3]
            elif step is not None and x - 2 in BARS and (r + step) % 3 != 1:
                c = WATER[0] if (r + step) % 2 else WATER[1]     # foam below the bar
            if x == X0:
                c = TIMBER[1]                         # the head board
            f.put(x, y, c)
        f.put(x, t + 8, TIMBER[0])                    # near board, top edge
        for r in range(9, 13):                        # and its front face
            y = t + r
            c = TIMBER[1] if r < 11 else TIMBER[2]
            if grain(x // 5, r, 179) < 2:
                c = TIMBER[2] if r < 11 else TIMBER[3]
            if r == 12:
                c = TIMBER[3]
            if x == X1:
                c = TIMBER[3]                         # end grain at the low end
            f.put(x, y, c)
        if x in (LEGS[0], LEGS[0] + 1, LEGS[1], LEGS[1] + 1):
            f.put(x, t + 10, TIMBER[4])               # the peg through each leg
    if step is not None:                              # the fall off the low end
        t = 7 + drop(X1)
        for x, y0 in ((X1 + 1, t + 4), (X1 + 2, t + 6)):
            for y in range(y0, 29):
                run = (y - 2 * step + x) % 6
                f.put(x, y, MUD[0] if run == 0 else (MUD[1] if run < 3 else MUD[2]))
    f.outline(EDGE)
    if step is not None:                              # the muddy puddle it feeds
        for x in range(25, 32):
            f.put(x, 30, MUD[2] if (x + step) % 3 else MUD[1])
        for x in range(27, 32):
            f.put(x, 29, MUD[1] if (x + step) % 3 else MUD[0])
        f.put(26 - step % 2, 29, MUD[3] + (200,))
        f.put(24 + step, 31, MUD[3] + (170,))
        f.put(29 + step % 2, 31, MUD[2] + (200,))
    return f


# --------------------------------------------------------------- rocker --

ROCKER_CX = 15.5
HOLES = ((11, 9), (14, 9), (17, 9), (20, 9), (12, 11), (15, 11), (18, 11), (21, 11))


def rocker_parts():
    """The cradle seen from its low end: the curved rocker under the plank
    box, the tail opening over the riffled apron, the hopper with its
    perforated iron plate and the upright handle. Returned unoutlined."""
    f = Sprite()
    for x in range(4, 28):                            # the curved rocker
        nx = (x - ROCKER_CX) / 12.0
        low = 28 - int(round(3.2 * nx * nx))
        f.put(x, low - 1, TIMBER[1] if x < 14 else TIMBER[2])
        f.put(x, low, TIMBER[4])
        if 7 <= x <= 24:
            for y in range(25, low - 1):
                f.put(x, y, TIMBER[4])                # the cleat it is nailed to
    f.pts(TIMBER[0], (4, 24), (5, 25))
    for y in range(16, 25):                           # the box end
        for x in range(7, 25):
            c = TIMBER[1] if x < 21 else TIMBER[2]
            if y == 19:
                c = TIMBER[3]                         # joints between the boards
            elif grain(x // 4, y, 181) < 2:
                c = TIMBER[2]
            if x in (7, 24):
                c = TIMBER[0] if x == 7 else TIMBER[3]    # the side boards, end on
            if y == 24:
                c = TIMBER[3]
            f.put(x, y, c)
    f.rect(10, 20, 21, 23, HOLE)                      # the tail opening
    f.hline(10, 21, 22, FLEECE[2])                    # the blanket on the floor
    f.pts(FLEECE[1], (11, 22), (14, 22), (15, 22), (19, 22))
    f.pts(FLEECE[3], (13, 22), (17, 22), (21, 22))
    f.hline(10, 21, 23, TIMBER[1])                    # the last riffle bar
    f.pts(TIMBER[0], (10, 23), (11, 23), (12, 23))
    f.hline(10, 21, 20, TIMBER[4])                    # shade under the end board
    # the hopper: rim, iron plate seen from above, front board
    f.rect(8, 7, 23, 12, TIMBER[1])
    f.hline(8, 23, 7, TIMBER[0])
    f.vline(23, 7, 12, TIMBER[2])
    f.rect(10, 8, 21, 11, IRON[2])
    f.hline(10, 21, 8, IRON[3])                       # shade under the far rim
    f.vline(10, 8, 11, IRON[3])
    for x, y in HOLES:
        f.put(x, y, IRON_EDGE)
        if y > 8:
            f.put(x, y - 1, IRON[1])                  # the punched lip catches light
    f.pts(IRON[0], (13, 10), (19, 10))
    for y in range(13, 16):                           # hopper front board
        for x in range(8, 24):
            c = TIMBER[1] if y < 15 else TIMBER[2]
            if grain(x // 5, y, 183) < 2:
                c = TIMBER[2]
            if x == 23:
                c = TIMBER[3]
            f.put(x, y, c)
    f.hline(8, 23, 15, TIMBER[3])                     # shade where it sits on the box
    # the upright handle, pegged to the hopper's side
    f.vline(25, 1, 14, TIMBER[1])
    f.vline(26, 1, 14, TIMBER[3])
    f.pts(TIMBER[0], (25, 1), (25, 2), (25, 3))
    f.pts(TIMBER[2], (24, 10), (24, 13))
    f.pts(IRON[3], (25, 10), (25, 13))
    return f


def tilt(f, lean):
    """Rock the cradle on its curve by two whole-pixel shears (so no pixel
    is lost or doubled): lean is -1 for left, 1 for right."""
    g = Sprite()
    for (x, y), c in f.px.items():
        x2 = x + lean * ((30 - y) // 7)               # the top swings over
        y2 = y + lean * int(round((x2 - ROCKER_CX) / 7.0))
        g.put(x2, y2, c)
    return g


def rocker(step=None):
    f = rocker_parts()
    if step is None:
        f.outline(EDGE)
        return f
    lean = -1 if step % ROCK_FRAMES == 0 else 1
    f = tilt(f, lean)
    f.outline(EDGE)
    # water shaken from the low side and dripping from the tail
    side = 8 if lean < 0 else 23
    for i, (dx, dy, a) in enumerate(((0, 0, 255), (-1, 2, 220), (1, 4, 170))):
        f.put(side + lean * 2 + dx * lean, 26 + dy + (1 if lean > 0 else 0), WATER[1 if i else 0] + (a,))
    f.put(14 + lean * 3, 29, WATER[1] + (230,))
    f.put(17 + lean * 3, 30, WATER[2] + (200,))
    f.put(11 + lean * 4, 30, MUD[1] + (200,))
    return f


def states():
    """[(state, frames, delay)] in sheet order."""
    return [
        ('pay_dirt', [pay_dirt()], 0),
        ('sluice', [sluice_box()], 0),
        ('sluice_running', [sluice_box(i) for i in range(WATER_FRAMES)], WATER_DELAY),
        ('rocker', [rocker()], 0),
        ('rocker_rocking', [rocker(i) for i in range(ROCK_FRAMES)], ROCK_DELAY),
    ]


# --------------------------------------------------------- sheet in/out --

def build():
    blocks, frames = [], []
    for name, frs, delay in states():
        block = 'state = "%s"\n\tdirs = 1\n\tframes = %d\n' % (name, len(frs))
        if len(frs) > 1:
            block += '\tdelay = %s\n' % ','.join([str(delay)] * len(frs))
        blocks.append(block)
        frames += [fr.image() for fr in frs]
    cols = int(len(frames) ** 0.5 + 0.999)
    rows = (len(frames) + cols - 1) // cols
    im = Image.new('RGBA', (cols * SIZE, rows * SIZE))
    for i, fr in enumerate(frames):
        im.paste(fr, ((i % cols) * SIZE, (i // cols) * SIZE))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    text += ''.join(blocks) + '# END DMI\n'
    return im, text


def write_dmi():
    im, text = build()
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    im.save(SHEET, 'PNG', pnginfo=meta, optimize=True)


def check():
    if not SHEET.exists():
        return False
    im, text = build()
    old = Image.open(SHEET)
    return old.info.get('Description') == text and old.convert('RGBA').tobytes() == im.tobytes()


# -------------------------------------------------------------- review --

def preview(path, scale=4):
    """Every frame, labelled, on grass (upper block) and dirt (lower)."""
    cells = []
    for name, frs, _ in states():
        for i, fr in enumerate(frs):
            cells.append((name if len(frs) == 1 else '%s [%d]' % (name, i + 1), fr.image()))
    cols, pad, label = 4, 8, 14
    rows = (len(cells) + cols - 1) // cols
    cw, ch = SIZE * scale + pad, SIZE * scale + label + pad
    out = Image.new('RGBA', (pad + cols * cw, pad + 2 * rows * ch), (24, 24, 24, 255))
    pen = ImageDraw.Draw(out)
    for j, tones in enumerate((GRASS, DIRT)):
        back = ground(tones, scale)
        for i, (name, im) in enumerate(cells):
            x, y = pad + (i % cols) * cw, pad + (j * rows + i // cols) * ch
            tile = back.copy()
            tile.alpha_composite(im.resize((SIZE * scale, SIZE * scale), Image.NEAREST))
            out.paste(tile, (x, y))
            pen.text((x + 1, y + SIZE * scale + 1), name, fill=(230, 230, 230, 255))
    out.save(path)


def gif(path, scale=6):
    """The running sluice on grass at game speed."""
    back = ground(GRASS, scale)
    shots = []
    for fr in dict((n, f) for n, f, _ in states())['sluice_running']:
        tile = back.copy()
        tile.alpha_composite(fr.image().resize((SIZE * scale, SIZE * scale), Image.NEAREST))
        shots.append(tile.convert('RGB'))
    shots[0].save(path, save_all=True, append_images=shots[1:], duration=WATER_DELAY * 100, loop=0)


if __name__ == '__main__':
    if '--check' in sys.argv:
        if not check():
            sys.exit('stale sheet: ' + str(SHEET))
        print('placer states match')
    else:
        write_dmi()
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
    if '--gif' in sys.argv:
        gif(sys.argv[sys.argv.index('--gif') + 1])
