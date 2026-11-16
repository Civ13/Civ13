"""Hand-placed sprites for hard-rock (lode) gold and silver in
icons/obj/lode.dmi: the two ores as they come from the vein (milky gold-bearing
quartz with rusty iron stain, and dark cubic lead-silver ore), the same two
crushed to grit, the pale slime tailings left after washing, the water stamp
mill (a timber frame with three iron-shod stamps over a mortar box and a cam
shaft with an iron gear hub: standing and a four-frame stamping loop) and the
buddle (a round wooden-rimmed washing pit with a central cone and a sweep arm:
dry and a three-frame working loop). Every pixel is placed by this script from
a fixed palette (Pillow only); no external or generated artwork. The timber
and field stone are those of create_clay_lime_fire.py, the muddy wash water is
the kanna channel's from create_tatara.py and the iron is the mercury
retort's from create_mercury.py.

Run with Pillow to write the sheet. `--check` verifies the committed sheet,
`--preview <png>` writes a labelled 4x review sheet on grass and on dirt,
`--gif <path>` writes the stamping loop.
Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_clay_lime_fire import TIMBER, STONE, grain  # noqa: E402
from create_tatara import Sprite, MUD, HOLE, GRASS, DIRT, ground  # noqa: E402
from create_mercury import IRON, IRON_EDGE  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/lode.dmi'

SIZE = 32
STAMP_DELAY = 2        # deciseconds per frame, as trip_hammer_on
STAMP_FRAMES = 4
BUDDLE_DELAY = 3
BUDDLE_FRAMES = 3

# milky vein quartz: glint, lit, mid, shade, deep
QUARTZ = [(250, 249, 244), (232, 230, 222), (206, 206, 200), (172, 174, 174), (134, 138, 142)]
QUARTZ_EDGE = (78, 74, 72)
# iron stain (gossan) on the quartz: light, mid, dark
RUST = [(190, 124, 70), (150, 90, 48), (112, 64, 38)]
# free gold: bright, shade
GOLD = [(244, 206, 72), (196, 146, 36)]
# argentiferous galena: steel glint, lit face, mid, shade, deep
GALENA = [(206, 214, 226), (134, 144, 164), (96, 106, 128), (68, 76, 98), (46, 52, 70)]
GALENA_EDGE = (20, 22, 32)
# crushed quartz grit: lit, mid, shade, deep
GRIT = [(222, 214, 196), (196, 188, 170), (166, 160, 146), (132, 128, 120)]
GRIT_EDGE = (74, 68, 62)
# crushed lead-silver ore: lit, mid, shade, deep
SLATE = [(122, 130, 146), (94, 102, 118), (70, 77, 94), (50, 56, 70)]
SILVER = (228, 234, 242)
# slime tailings: wet sheen, lit, mid, shade, deep
SLIME = [(232, 226, 210), (204, 194, 172), (180, 168, 146), (152, 140, 122), (120, 110, 98)]
SLIME_EDGE = (82, 74, 66)
EDGE = (30, 20, 14)                      # the timber outline
# dry buddle floor: lit, mid, shade, deep
FLOOR = [(228, 204, 162), (210, 184, 140), (186, 158, 116), (150, 122, 86)]
DUST = (226, 220, 204)


# ------------------------------------------------------------ vein ores --

def quartz_lump(cx, cy, rx, ry, seed):
    """One angular lump of milky quartz, lit from the upper left, with a
    rusty stain running through its shaded side."""
    g = Sprite()
    for y in range(int(cy - ry) - 2, int(cy + ry) + 3):
        for x in range(int(cx - rx) - 2, int(cx + rx) + 3):
            nx, ny = (x - cx) / rx, (y - cy) / ry
            a = math.atan2(ny, nx)
            edge = 1.0 + 0.13 * math.sin(3 * a + seed) + 0.09 * math.sin(5 * a + 2 * seed)
            if math.hypot(nx, ny) > edge:
                continue
            light = nx * 0.6 + ny * 0.75
            c = QUARTZ[1] if light < -0.3 else (QUARTZ[2] if light < 0.35 else QUARTZ[3])
            if light < -0.7:
                c = QUARTZ[0]
            if light > 0.8:
                c = QUARTZ[4]
            # the stain follows a slanting crack through the lump
            crack = (x + 2 * y + seed) % 9
            if crack == 0 and light > -0.5:
                c = RUST[1] if light < 0.4 else RUST[2]
            elif crack == 1 and light > -0.1 and grain(x, y, seed + 3) < 6:
                c = RUST[0]
            g.put(x, y, c)
    return g


def gold_quartz():
    f = Sprite()
    for i, lump in enumerate(((20.5, 20.5, 5.2, 4.2), (10.5, 21.5, 4.6, 3.6), (15.0, 14.5, 4.4, 3.6))):
        f.stamp(quartz_lump(*lump, seed=3 + i * 4))
    # clean white faces where the quartz broke, and the few specks of gold
    f.pts(QUARTZ[0], (8, 20), (9, 20), (13, 12), (14, 12), (18, 18), (19, 18))
    f.pts(GOLD[0], (17, 15), (22, 21), (11, 23))
    f.pts(GOLD[1], (18, 15), (21, 23))
    f.outline(QUARTZ_EDGE)
    f.pts(QUARTZ[3], (26, 25), (6, 25))               # chips broken off
    f.put(15, 26, QUARTZ[2])
    return f


def galena_block(f, x0, y0, w, h, step=0):
    """One cleaved cube of galena: bright top, mid front, dark right side,
    with a stepped cleavage notch out of the upper right corner."""
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            c = GALENA[2]
            if y == y0:
                c = GALENA[1]
            if x >= x0 + w - 2:
                c = GALENA[3]
            if y == y0 + h - 1:
                c = GALENA[4]
            if x == x0 and y < y0 + h - 1:
                c = GALENA[1]
            f.put(x, y, c)
    f.put(x0, y0, GALENA[0])                          # the lit corner
    f.put(x0 + 1, y0, GALENA[0])
    if step:                                          # cleavage step on the face
        sx, sy = x0 + step, y0 + h // 2
        f.hline(sx, x0 + w - 3, sy, GALENA[1])
        f.put(sx, sy, GALENA[0])
        f.vline(sx - 1, sy, y0 + h - 2, GALENA[3])


def silver_lode():
    f = Sprite()
    galena_block(f, 13, 11, 7, 6, 3)                  # the back lump
    galena_block(f, 17, 14, 5, 4)
    galena_block(f, 6, 18, 8, 7, 3)                   # near left
    galena_block(f, 4, 21, 4, 4)
    galena_block(f, 17, 19, 9, 7, 4)                  # near right
    galena_block(f, 23, 17, 4, 4)
    # steel-bright cleavage glints
    f.pts(GALENA[0], (9, 20), (15, 13), (20, 21), (21, 21), (24, 19), (11, 23))
    f.pts(SILVER, (8, 19), (19, 20), (14, 12))
    f.outline(GALENA_EDGE)
    f.pts(GALENA[3], (15, 27), (28, 26))              # fallen crumbs
    f.put(3, 27, GALENA[2])
    return f


# ---------------------------------------------------------------- heaps --

def heap(tones, edge, cx, base, rx, h, seed, speck=None, specks=(), smooth=False):
    """A small heap lit from the upper left. Grit heaps are coarse and
    speckled; a smooth heap is slumped, flat-topped and nearly unbroken."""
    f = Sprite()
    for x in range(int(math.ceil(cx - rx)), int(cx + rx) + 1):
        nx = (x - cx) / rx
        if smooth:
            top = int(round(base - h * (1.0 - nx * nx * nx * nx) ** 0.5))
        else:
            top = int(round(base - h * (1.0 - abs(nx)) ** 0.8)) + (grain(x, 0, seed) < 3)
        foot = base + int(round(1.7 * math.sqrt(max(0.0, 1.0 - nx * nx))))
        for y in range(top, foot + 1):
            light = nx * 0.9 + (y - top) / float(h) * 0.6
            c = tones[0] if light < -0.25 else (tones[1] if light < 0.4 else tones[2])
            if not smooth:
                g = grain(x, y, seed + 1)
                if g == 0:
                    c = tones[3]                      # a dark grain
                elif g == 1 and light > -0.2:
                    c = tones[2]
                elif g == 2 and light < 0.3:
                    c = tones[0]
            if y == foot:
                c = tones[3]
            f.put(x, y, c)
    for x, y in specks:
        f.put(x, y, speck)
    f.outline(edge)
    return f


def crushed_gold():
    f = heap(GRIT, GRIT_EDGE, 15.5, 24, 9.0, 8, 201, GOLD[0],
             ((13, 20), (18, 22), (10, 24), (20, 25), (15, 18)))
    f.pts(GRIT[2], (5, 27), (26, 27), (22, 28))
    f.put(9, 28, GRIT[1])
    return f


def crushed_silver():
    f = heap(SLATE, GALENA_EDGE, 15.5, 24, 9.0, 8, 211, SILVER,
             ((12, 21), (17, 19), (19, 23), (9, 24), (15, 25), (22, 24)))
    f.pts(SLATE[2], (5, 27), (26, 27), (21, 28))
    f.put(10, 28, SLATE[1])
    return f


def tailings():
    """A low wet slump of slime: smooth, with a sheen along the crown, a
    couple of sag lines and the water draining out round its foot."""
    f = heap(SLIME[1:], SLIME_EDGE, 15.5, 24, 11.0, 5, 221, smooth=True)
    f.hline(8, 14, 20, SLIME[0])                      # wet sheen on the crown
    f.hline(10, 12, 21, SLIME[0])
    f.pts(SLIME[0], (17, 20), (6, 22))
    f.hline(13, 19, 23, SLIME[3])                     # sag lines
    f.hline(20, 23, 22, SLIME[3])
    f.hline(7, 10, 24, SLIME[2])
    for x in range(3, 29):                            # the grey puddle it drains to
        if (x, 27) not in f.px and x % 4:
            f.put(x, 27, SLIME[3] + (150,))
    f.pts(SLIME[2] + (190,), (2, 26), (29, 26), (12, 28), (13, 28), (20, 28))
    return f


# ----------------------------------------------------------- stamp mill --

STEMS = (7, 12, 17)                # left column of each two-wide stamp stem
POSTS = (2, 21)                    # left column of each three-wide frame post
# how far each stamp is lifted in each frame: the cams take them in turn
LIFTS = ((3, 1, 0), (0, 3, 1), (0, 0, 3), (1, 0, 0))
DROPPED = (None, 0, 1, 2)          # the stamp that has just fallen
GEAR_CX, GEAR_CY = 27.5, 7.0


def stamp_mill(step=None):
    """Seen from the front: two posts on a sill, the mortar box between
    them, three stamps hanging through a guide rail, and the cam shaft
    across the top running out to its iron gear hub on the right."""
    f = Sprite()
    lifts = (0, 0, 0) if step is None else LIFTS[step]
    turn = 0 if step is None else step
    # the cam shaft, behind the stems
    for x in range(0, 25):
        f.put(x, 6, TIMBER[0] if (x + turn * 2) % 7 else TIMBER[1])
        f.put(x, 7, TIMBER[1] if (x + turn * 2) % 5 else TIMBER[2])
        f.put(x, 8, TIMBER[3])
    f.vline(0, 6, 8, IRON[2])                         # the iron band on its end
    # the stamps: stem, tappet, iron shoe
    for i, sx in enumerate(STEMS):
        up = lifts[i]
        if up:                                        # the cam under the tappet
            f.pts(TIMBER[4], (sx - 2, 9), (sx - 1, 9))
            f.put(sx - 2, 10 - min(up, 2), TIMBER[3])
        else:                                         # the cam turned away, on top
            f.pts(TIMBER[2], (sx - 2, 5), (sx - 1, 5))
        for y in range(4 - up, 20 - up):
            f.put(sx, y, TIMBER[0] if grain(sx, y // 4, 231) else TIMBER[1])
            f.put(sx + 1, y, TIMBER[3])
        f.put(sx - 1, 10 - up, TIMBER[1])             # the tappet peg
        f.put(sx - 1, 11 - up, TIMBER[4])
        for y in range(20 - up, 24 - up):             # the iron shoe
            f.put(sx - 1, y, IRON[1])
            f.put(sx, y, IRON[0] if y == 20 - up else IRON[2])
            f.put(sx + 1, y, IRON[2])
            f.put(sx + 2, y, IRON[3])
        f.hline(sx - 1, sx + 2, 23 - up, IRON[4])     # its worn face
    # the mortar box: the dark inside with ore in it, then the front board
    for x in range(5, 21):
        for y in (22, 23):
            if (x, y) not in f.px:
                f.put(x, y, STONE[3] if grain(x, y, 233) < 3 else HOLE)
    for x in range(4, 22):
        for y in range(24, 29):
            c = TIMBER[1] if y < 27 else TIMBER[2]
            if y == 24:
                c = TIMBER[0]
            elif grain(x // 5, y, 235) < 2:
                c = TIMBER[2] if y < 27 else TIMBER[3]
            if y == 26:
                c = IRON[2] if x % 6 else IRON[0]     # the iron strap round it
            f.put(x, y, c)
    f.hline(4, 21, 28, TIMBER[3])
    # the guide rail the stems slide through
    for x in range(4, 22):
        f.put(x, 14, TIMBER[0] if grain(x // 4, 1, 237) else TIMBER[1])
        f.put(x, 15, TIMBER[2])
        f.put(x, 16, TIMBER[4])
    for sx in STEMS:                                  # the slots, with the stem in them
        f.put(sx, 14, TIMBER[1])
        f.put(sx + 1, 14, TIMBER[4])
        f.put(sx - 1, 15, TIMBER[4])
        f.put(sx, 15, TIMBER[1])
        f.put(sx + 1, 15, TIMBER[4])
    # the frame: posts and sill
    for px in POSTS:
        for y in range(2, 30):
            f.put(px, y, TIMBER[1] if grain(px, y // 5, 239) else TIMBER[0])
            f.put(px + 1, y, TIMBER[2])
            f.put(px + 2, y, TIMBER[3])
        f.hline(px, px + 2, 2, TIMBER[0])
        for y in (6, 7, 8):                           # the shaft's bearing block
            f.put(px, y, TIMBER[3])
            f.put(px + 1, y, TIMBER[4])
            f.put(px + 2, y, TIMBER[4])
        f.put(px + 1, 15, IRON[3])                    # the rail's peg
    for x in range(0, 26):
        f.put(x, 29, TIMBER[1] if grain(x // 6, 2, 241) else TIMBER[2])
        f.put(x, 30, TIMBER[4])
    # the gear hub on the shaft end: iron rim, timber web, square axle
    for y in range(2, 13):
        for x in range(23, 32):
            d = math.hypot(x - GEAR_CX, y - GEAR_CY)
            if d > 4.3:
                continue
            if d > 2.9:
                c = IRON[1] if (x - GEAR_CX) + (y - GEAR_CY) < 0 else IRON[3]
            elif d > 1.2:
                c = TIMBER[3] if (int(x > GEAR_CX) + int(y > GEAR_CY) + turn) % 2 else TIMBER[2]
            else:
                c = IRON[0] if (x, y) == (27, 6) else IRON[2]
            f.put(x, y, c)
    for k in range(8):                                # the cogs, stepping round
        a = (k + 0.5 * (turn % 2)) * math.pi / 4.0
        f.put(int(round(GEAR_CX + 5.0 * math.cos(a))), int(round(GEAR_CY + 5.0 * math.sin(a))),
              IRON[1] if math.sin(a) + math.cos(a) < 0 else IRON[2])
    f.outline(EDGE)
    if step is not None and DROPPED[step] is not None:
        sx = STEMS[DROPPED[step]]                     # dust and wet thrown from the box
        f.pts(DUST + (235,), (sx - 2, 21), (sx + 3, 21))
        f.pts(DUST + (190,), (sx - 3, 19), (sx + 4, 20), (sx + 3, 18))
        f.pts(MUD[0] + (220,), (sx - 2, 19), (sx + 4, 22))
        f.put(sx - 3, 22, MUD[1] + (200,))
    return f


# --------------------------------------------------------------- buddle --

BCX, BCY = 15.5, 15.0
BRX, BRY = 14.0, 9.0               # outer edge of the rim
IRX, IRY = 12.0, 7.4               # the floor inside it
WALL = 5                           # height of the stave wall seen at the front


def buddle(step=None):
    """A round stave-walled pit seen from the front and above: the rim, the
    floor falling away from the central cone to the wall, and the sweep arm
    pivoted on the cone. With a step it holds muddy water, swirled by the arm."""
    f = Sprite()
    for x in range(1, 31):                            # the stave wall at the front
        nx = (x - BCX) / BRX
        if abs(nx) > 1.0:
            continue
        y0 = BCY + BRY * math.sqrt(1.0 - nx * nx)
        for y in range(int(BCY), int(round(y0)) + WALL + 1):
            c = TIMBER[1] if nx < 0.2 else TIMBER[2]
            if x % 4 == 1:
                c = TIMBER[3]                         # joints between the staves
            if abs(nx) > 0.85:
                c = TIMBER[3]
            f.put(x, y, c)
        hoop = int(round(y0)) + WALL - 2              # the iron hoop
        f.put(x, hoop, IRON[1] if nx < 0 else IRON[3])
        f.put(x, int(round(y0)) + WALL, TIMBER[4])
    for y in range(4, 26):
        for x in range(0, 32):
            nx, ny = (x - BCX) / BRX, (y - BCY) / BRY
            if nx * nx + ny * ny > 1.0:
                continue
            ix, iy = (x - BCX) / IRX, (y - BCY) / IRY
            r = math.hypot(ix, iy)
            if r > 1.0:                               # the rim, seen from above
                c = TIMBER[0] if ny > 0.2 or nx < -0.5 else TIMBER[1]
                if (x + (y > BCY)) % 4 == 1:
                    c = TIMBER[2]
                if r < 1.22 and iy < 0.1:
                    c = TIMBER[4] if r < 1.1 else TIMBER[3]   # the far wall's inner face
                f.put(x, y, c)
                continue
            a = math.atan2(iy, ix)
            if step is None:                          # the dry floor
                c = FLOOR[1]
                if r > 0.8:
                    c = FLOOR[2]
                if iy < -0.55 or (r > 0.7 and ix < -0.3 and iy < 0.2):
                    c = FLOOR[3]                      # shade under the far wall
                elif iy > 0.35 and r < 0.85:
                    c = FLOOR[0]
                if int(r * 4.6 + 0.5) != int(r * 4.6) and int(a * 5 + 20) % 3 == 0 and r > 0.35:
                    c = FLOOR[2] if c != FLOOR[3] else FLOOR[3]   # rings left by the sweep
                if grain(x, y, 251) == 0:
                    c = FLOOR[2]
            else:                                     # muddy water, swirling
                swirl = math.sin(3 * a + 7.0 * r - step * 2.0 * math.pi / 3.0)
                c = MUD[2]
                if swirl > 0.72:
                    c = MUD[0] if r > 0.45 and grain(x, y, 253 + step) < 6 else MUD[1]
                elif swirl > 0.25:
                    c = MUD[1]
                elif swirl < -0.75:
                    c = MUD[3]
                if iy < -0.7:
                    c = MUD[3]                        # shade under the far wall
            f.put(x, y, c)
    # the cone: a low mound in the middle, its apex left of centre top
    for y in range(11, 18):
        for x in range(11, 21):
            nx, ny = (x - BCX) / 4.6, (y - 14.4) / 3.1
            d = nx * nx + ny * ny
            if d > 1.0:
                continue
            ramp = FLOOR if step is None else MUD
            c = ramp[0] if nx + ny < -0.15 else (ramp[1] if nx + ny < 0.55 else ramp[2])
            if d > 0.62 and nx + ny > 0.1:
                c = ramp[3]                           # its shaded foot
            f.put(x, y, c)
    f.pts(QUARTZ[1], (13, 12), (14, 12), (13, 13))
    # the sweep arm across the pit, carried a little above the floor
    theta = math.radians(22 if step is None else 60 * step + 8)
    for i in range(-44, 45):
        t = i / 44.0
        x = int(round(BCX + t * (IRX - 0.6) * math.cos(theta)))
        y = int(round(BCY - 2 + t * (IRY - 0.8) * math.sin(theta)))
        f.put(x, y + 2, FLOOR[3] if step is None else MUD[3])     # its shadow
        if abs(i) > 8 and i % 6 == 0:
            f.put(x, y + 1, TIMBER[4])                # the rake teeth
    for i in range(-44, 45):
        t = i / 44.0
        x = int(round(BCX + t * (IRX - 0.6) * math.cos(theta)))
        y = int(round(BCY - 2 + t * (IRY - 0.8) * math.sin(theta)))
        f.put(x, y, TIMBER[1] if i < 0 else TIMBER[2])
        if f.px.get((x, y + 1)) not in (TIMBER[1], TIMBER[2]):
            f.put(x, y + 1, TIMBER[4])
    # the pivot post standing on the cone
    f.vline(15, 8, 14, TIMBER[2])
    f.vline(16, 8, 14, TIMBER[4])
    f.pts(IRON[0], (15, 7))
    f.pts(IRON[2], (16, 7))
    f.pts(IRON[1], (15, 12), (16, 12))                # the collar the arm turns on
    f.outline(EDGE)
    return f


def states():
    """[(state, frames, delay)] in sheet order."""
    return [
        ('gold_quartz', [gold_quartz()], 0),
        ('silver_lode', [silver_lode()], 0),
        ('crushed_gold', [crushed_gold()], 0),
        ('crushed_silver', [crushed_silver()], 0),
        ('tailings', [tailings()], 0),
        ('water_stamp_mill', [stamp_mill()], 0),
        ('water_stamp_mill_on', [stamp_mill(i) for i in range(STAMP_FRAMES)], STAMP_DELAY),
        ('buddle', [buddle()], 0),
        ('buddle_working', [buddle(i) for i in range(BUDDLE_FRAMES)], BUDDLE_DELAY),
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
    """The stamping mill on grass at game speed."""
    back = ground(GRASS, scale)
    shots = []
    for fr in dict((n, f) for n, f, _ in states())['water_stamp_mill_on']:
        tile = back.copy()
        tile.alpha_composite(fr.image().resize((SIZE * scale, SIZE * scale), Image.NEAREST))
        shots.append(tile.convert('RGB'))
    shots[0].save(path, save_all=True, append_images=shots[1:], duration=STAMP_DELAY * 100, loop=0)


if __name__ == '__main__':
    if '--check' in sys.argv:
        if not check():
            sys.exit('stale sheet: ' + str(SHEET))
        print('lode states match')
    else:
        write_dmi()
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
    if '--gif' in sys.argv:
        gif(sys.argv[sys.argv.index('--gif') + 1])
