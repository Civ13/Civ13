"""Hand-placed sprites for mercury amalgamation in icons/obj/amalgam.dmi: the
soft balls of gold and of silver amalgam, the porous sponge metal left when
an amalgam is retorted, the dark slime tailings that still carry beads of
quicksilver, the amalgam press (an iron screw with a cross handle over a cast
iron pot in a catch tray on a squat wooden stand), the patio heap (a low
round cake of crushed ore mud on flagstones: fresh and salted, turned, and
fully worked) and the arrastra overlay (dark water and mercury beads for the
open frame of the `grindstone` state in icons/obj/structures.dmi, under and
beside its wheel). Every pixel is placed by this script from a fixed palette
(Pillow only); no external or generated artwork. The iron and quicksilver are
those of create_mercury.py, the timber and field stone are those of
create_clay_lime_fire.py and the slumped heap is the tailings heap of
create_lode.py.

Run with Pillow to write the sheet. `--check` verifies the committed sheet
and that the overlay covers no pixel of the grindstone, `--preview <png>`
writes a labelled 4x review sheet on grass and on dirt, with the overlay
shown on the grindstone.
Released under Civ13 AGPL-3.0.
"""
import math
import re
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_clay_lime_fire import TIMBER, STONE, grain  # noqa: E402
from create_tatara import Sprite, GRASS, DIRT, ground  # noqa: E402
from create_mercury import IRON, IRON_EDGE, QUICK  # noqa: E402
from create_lode import heap  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/amalgam.dmi'
STRUCTURES = ROOT / 'icons/obj/structures.dmi'

SIZE = 32

# gold amalgam: glint, lit, mid, shade, deep - silver-grey with a warm cast
AMAL_GOLD = [(255, 253, 236), (218, 215, 192), (182, 179, 156), (140, 137, 116), (100, 97, 84)]
AMAL_GOLD_EDGE = (60, 54, 42)
# silver amalgam: the same, cool and bluish
AMAL_SILVER = [(250, 252, 255), (216, 224, 236), (176, 188, 206), (132, 144, 166), (94, 104, 126)]
AMAL_SILVER_EDGE = (42, 48, 62)
# sponge gold: lit, mid, shade, deep, pit - dull and matte
SPONGE_GOLD = [(204, 170, 84), (176, 142, 60), (144, 112, 46), (110, 84, 36), (72, 52, 24)]
SPONGE_GOLD_EDGE = (52, 36, 16)
SPONGE_SILVER = [(228, 228, 222), (198, 200, 198), (164, 168, 170), (126, 130, 138), (84, 88, 98)]
SPONGE_SILVER_EDGE = (46, 48, 56)
# spent amalgamation slime: wet sheen, lit, mid, shade, deep
DARK_SLIME = [(168, 168, 164), (128, 128, 124), (104, 104, 102), (82, 82, 82), (60, 60, 64)]
DARK_SLIME_EDGE = (34, 34, 38)
# the patio cake: lit, mid, shade, deep
CAKE_FRESH = [(140, 120, 100), (116, 98, 82), (94, 78, 66), (70, 58, 50)]
CAKE_TURNED = [(112, 98, 86), (90, 78, 70), (70, 60, 56), (50, 43, 42)]
CAKE_WORKED = [(156, 154, 150), (130, 128, 126), (104, 102, 104), (76, 74, 78)]
CAKE_EDGE = (36, 30, 28)
SALT = (244, 242, 236)
FLAG_EDGE = (44, 42, 44)
# the water standing in the arrastra: glimmer, mid, deep
WATER = [(96, 112, 124), (58, 70, 84), (36, 44, 58)]
EDGE = (30, 20, 14)                      # the timber outline


# ---------------------------------------------------------------- balls --

def ball(f, cx, cy, rx, ry, tones):
    """One doughy ball, lit from the upper left: slumped flat on its foot,
    with a small hard glint and the pale wet rim light low on its far side."""
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            nx, ny = (x - cx) / rx, (y - cy) / ry
            if ny > 0:
                ny *= 1.18                            # it sags onto its foot
            d = nx * nx + ny * ny
            if d > 1.0:
                continue
            light = nx * 0.6 + ny * 0.75
            c = tones[1] if light < -0.42 else (tones[2] if light < 0.18 else tones[3])
            if light > 0.66:
                c = tones[4]
            if d > 0.62 and 0.2 < light < 0.66 and nx > 0.1:
                c = tones[2]                          # wet rim light
            f.put(x, y, c)
    gx, gy = int(round(cx - rx * 0.45)), int(round(cy - ry * 0.5))
    f.pts(tones[0], (gx, gy), (gx + 1, gy), (gx, gy + 1))


def amalgam(tones, edge):
    f = Sprite()
    ball(f, 16.0, 14.0, 4.6, 4.0, tones)              # the one behind
    ball(f, 10.5, 21.0, 5.2, 4.4, tones)
    ball(f, 21.0, 21.5, 5.6, 4.6, tones)
    # the creases where they press together, and a bright streak on the big one
    f.pts(tones[4], (15, 18), (16, 19), (15, 22), (16, 23), (15, 24))
    f.pts(tones[0], (23, 18))
    f.outline(edge)
    f.pts(tones[2], (5, 27), (27, 27))                # squeezed-off crumbs
    f.put(15, 27, tones[1])
    return f


# --------------------------------------------------------------- sponge --

PITS = ((11, 15), (15, 13), (19, 15), (22, 18), (9, 19), (13, 19), (17, 18),
        (20, 21), (11, 23), (15, 22), (18, 24), (23, 22), (14, 16), (7, 22))


def sponge(tones, edge):
    """A knobbly lump of retorted metal: matte, and eaten through with the
    holes the quicksilver left."""
    f = Sprite()
    cx, cy, rx, ry = 15.5, 19.0, 10.0, 7.2
    for y in range(8, 30):
        for x in range(2, 30):
            nx, ny = (x - cx) / rx, (y - cy) / ry
            a = math.atan2(ny, nx)
            rim = 1.0 + 0.10 * math.sin(4 * a + 1.3) + 0.08 * math.sin(7 * a + 0.4)
            if math.hypot(nx, ny) > rim:
                continue
            light = nx * 0.6 + ny * 0.8
            c = tones[0] if light < -0.35 else (tones[1] if light < 0.3 else tones[2])
            if light > 0.75:
                c = tones[3]
            g = grain(x, y, 311)
            if g == 0:
                c = tones[3]                          # pinholes
            elif g == 1 and light < 0.3:
                c = tones[0]
            elif g == 2:
                c = tones[2]
            f.put(x, y, c)
    for i, (x, y) in enumerate(PITS):                 # the bigger holes
        if (x, y) not in f.px:
            continue
        f.put(x, y, tones[4])
        if i % 3 != 2:
            f.put(x + 1, y, tones[4])
        if i % 3 == 0:
            f.put(x, y + 1, tones[4])
            f.put(x + 1, y + 1, tones[3])
        f.put(x + (2 if i % 3 != 2 else 1), y + 1, tones[0])   # lit lip below
        f.put(x, y - 1, tones[3])                     # shaded lip above
    f.outline(edge)
    f.pts(tones[2], (4, 27), (27, 26))                # crumbs
    f.put(21, 28, tones[1])
    return f


# ------------------------------------------------------------- tailings --

def amalgam_tailings():
    """The lode tailings heap again, but dark spent slime, with the lost
    quicksilver showing as a few bright beads."""
    f = heap(DARK_SLIME[1:], DARK_SLIME_EDGE, 15.5, 24, 11.0, 5, 221, smooth=True)
    f.hline(8, 14, 20, DARK_SLIME[0])                 # wet sheen on the crown
    f.hline(10, 12, 21, DARK_SLIME[0])
    f.pts(DARK_SLIME[0], (17, 20), (6, 22))
    f.hline(13, 19, 23, DARK_SLIME[4])                # sag lines
    f.hline(20, 23, 22, DARK_SLIME[4])
    f.hline(7, 10, 24, DARK_SLIME[3])
    for x in range(3, 29):                            # the dark puddle it drains to
        if (x, 27) not in f.px and x % 4:
            f.put(x, 27, DARK_SLIME[4] + (160,))
    f.pts(DARK_SLIME[3] + (190,), (2, 26), (29, 26), (12, 28), (13, 28), (20, 28))
    f.pts(QUICK[0], (15, 22), (21, 24), (9, 23), (24, 27))    # mercury beads
    f.pts(QUICK[1], (18, 21), (12, 25), (6, 27))
    return f


# ---------------------------------------------------------------- press --

def iron_bar(f, x0, y0, x1, y1, upright=False):
    """A cast iron member: lit along its top (or left) edge, dark below."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            k = (x - x0) if upright else (y - y0)
            n = (x1 - x0) if upright else (y1 - y0)
            c = IRON[1] if k == 0 else (IRON[3] if k == n and n else IRON[2])
            f.put(x, y, c)


def amalgam_press():
    """Seen from the front: the stand, the catch tray on it, the pot between
    two pillars, the yoke across their heads and the screw through the yoke
    down onto the follower in the pot."""
    f = Sprite()
    # the squat wooden stand: a thick top on two stout legs with a stretcher
    for x in range(4, 28):
        f.put(x, 23, TIMBER[0] if grain(x // 4, 1, 321) else TIMBER[1])
        f.put(x, 24, TIMBER[1] if grain(x // 5, 2, 323) else TIMBER[2])
        f.put(x, 25, TIMBER[3])
    for lx in (5, 23):
        for y in range(26, 31):
            f.put(lx, y, TIMBER[1])
            f.put(lx + 1, y, TIMBER[2])
            f.put(lx + 2, y, TIMBER[2] if grain(lx, y, 325) else TIMBER[3])
            f.put(lx + 3, y, TIMBER[3])
        f.hline(lx, lx + 3, 30, TIMBER[4])
    f.hline(9, 22, 27, TIMBER[2])                     # the stretcher
    f.hline(9, 22, 28, TIMBER[4])
    # the catch tray: its floor seen from a little above, then the front wall
    f.hline(6, 25, 19, IRON[4])
    f.hline(5, 26, 20, IRON[1])                       # the lit front lip
    f.hline(5, 26, 21, IRON[2])
    f.hline(6, 25, 22, IRON[3])
    f.pts(IRON[0], (6, 20), (7, 20), (8, 20))
    f.pts(IRON[3], (5, 19), (26, 19))                 # the end walls
    f.put(26, 21, IRON[3])
    # the two pillars and the yoke across them
    iron_bar(f, 8, 9, 9, 19, upright=True)
    iron_bar(f, 22, 9, 23, 19, upright=True)
    iron_bar(f, 7, 7, 24, 8)
    f.pts(IRON[0], (7, 7), (8, 7), (9, 7), (10, 7))
    f.pts(IRON[4], (8, 9), (9, 9), (22, 9), (23, 9))  # shade under the yoke
    f.hline(14, 17, 6, IRON[1])                       # the boss the screw runs in
    f.put(14, 6, IRON[0])
    f.put(17, 6, IRON[3])
    # the pot: a cast iron cylinder with a rim, a belly band and a foot
    for y in range(13, 20):
        for x in range(11, 21):
            c = IRON[(3, 1, 0, 1, 2, 2, 2, 3, 3, 4)[x - 11]]
            if y in (13, 16):
                c = IRON[max(0, IRON.index(c) - 1)]   # the raised bands catch light
            if y in (14, 17):
                c = IRON[min(4, IRON.index(c) + 1)]   # and shade what is under them
            if y == 19:
                c = IRON[4] if x > 12 else IRON[3]
            if grain(x, y, 327) == 0 and y not in (13, 16):
                c = IRON[min(4, IRON.index(c) + 1)]   # the rough casting skin
            f.put(x, y, c)
    f.hline(10, 21, 13, IRON[1])                      # the rim stands proud
    f.pts(IRON[0], (10, 13), (11, 13), (12, 13), (13, 13))
    f.pts(IRON[3], (20, 13), (21, 13))
    # the follower going down into the pot, and the screw on it
    f.hline(13, 18, 12, IRON[3])
    f.hline(13, 15, 12, IRON[2])
    for y in range(1, 12):
        if y in (6, 7, 8):
            continue                                  # hidden in the boss and yoke
        f.put(15, y, IRON[0] if y % 2 else IRON[2])   # the thread
        f.put(16, y, IRON[2] if y % 2 else IRON[4])
    # the cross handle through the head of the screw, with a ball on each end
    f.hline(9, 22, 2, IRON[1])
    f.pts(IRON[0], (9, 2), (10, 2), (15, 1), (15, 2))
    f.pts(IRON[3], (19, 2), (20, 2), (21, 2), (22, 2))
    for bx in (7, 23):
        f.pts(IRON[1], (bx, 1), (bx, 2), (bx + 1, 1))
        f.pts(IRON[3], (bx + 1, 2), (bx, 3), (bx + 1, 3))
    f.put(7, 1, IRON[0])
    # the squeezed-out quicksilver: a drip at the foot of the pot, a bead in the tray
    f.put(21, 18, QUICK[1])
    f.outline(IRON_EDGE)
    for (x, y), c in list(f.px.items()):              # the timber keeps its own outline
        if c == IRON_EDGE and y >= 23:
            f.put(x, y, EDGE)
    f.pts(QUICK[0], (24, 19))
    f.pts(QUICK[1], (25, 19))
    f.pts(QUICK[2], (25, 20))
    f.put(7, 19, QUICK[1])
    return f


# ----------------------------------------------------------- patio heap --

PCX, PCY = 15.5, 17.0
FRX, FRY = 15.4, 12.4              # the flagged floor showing round the cake
CRX, CRY = 12.6, 8.8               # the cake itself
THICK = 2                          # how far its edge stands up at the front


def flags(f):
    """A round patch of the flagged yard floor, seen from above."""
    for y in range(3, 31):
        for x in range(0, 32):
            nx, ny = (x - PCX) / FRX, (y - PCY) / FRY
            a = math.atan2(ny, nx)
            if math.hypot(nx, ny) > 1.0 + 0.04 * math.sin(6 * a + 1.0):
                continue
            row = (y - 3) // 5
            col = (x + (row % 2) * 4) // 7
            c = STONE[1] if (row + col) % 3 else STONE[2]
            if (y - 3) % 5 == 4 or (x + (row % 2) * 4) % 7 == 6:
                c = STONE[4]                          # the joints
            elif grain(x, y, 331) == 0:
                c = STONE[2] if c == STONE[1] else STONE[3]
            elif (y - 3) % 5 == 0:
                c = STONE[0] if c == STONE[1] else STONE[1]
            f.put(x, y, c)


def patio_heap(stage):
    """A low flat cake of ore mud, lit from the upper left. Stage 1 is fresh
    and lumpy with salt strewn on it, stage 2 has been turned into furrows and
    shows the first quicksilver, stage 3 is trodden smooth, grey and bright
    with amalgam."""
    tones = (None, CAKE_FRESH, CAKE_TURNED, CAKE_WORKED)[stage]
    f = Sprite()
    flags(f)
    f.outline(FLAG_EDGE)
    cake = Sprite()
    for y in range(5, 31):
        for x in range(1, 31):
            nx = (x - PCX) / CRX
            a = math.atan2((y - PCY) / CRY, nx)
            wob = 1.0 + 0.05 * math.sin(5 * a + stage) + 0.03 * math.sin(9 * a + 2 * stage)
            top = math.hypot(nx, (y - PCY) / CRY) <= wob
            side = math.hypot(nx, (y - THICK - PCY) / CRY) <= wob
            if not (top or side):
                continue
            if not top:                               # the standing edge at the front
                cake.put(x, y, tones[3] if nx > -0.4 else tones[2])
                continue
            r = math.hypot(nx, (y - PCY) / CRY) / wob
            light = nx * 0.55 + (y - PCY) / CRY * 0.7
            c = tones[1]
            if r > 0.72 and light < -0.35:
                c = tones[0]                          # the lit shoulder
            elif r > 0.8 and light > 0.45:
                c = tones[2]
            g = grain(x, y, 341 + stage)
            if stage == 1:                            # lumpy and coarse
                if g == 0:
                    c = tones[3]
                elif g == 1:
                    c = tones[0]
                elif g == 2:
                    c = tones[2]
            elif stage == 2:                          # furrows from the turning
                band = (x // 2 + y) % 5
                if band == 0 and r < 0.92:
                    c = tones[3]
                elif band == 4 and r < 0.92:
                    c = tones[0]
                elif g == 0:
                    c = tones[2]
            else:                                     # trodden smooth
                if g == 0:
                    c = tones[2]
                elif (x + 3 * y) % 11 == 0 and r < 0.85:
                    c = tones[0]
            cake.put(x, y, c)
    cake.outline(CAKE_EDGE)
    f.stamp(cake)
    if stage == 1:
        f.pts(SALT, (9, 13), (14, 11), (20, 13), (24, 17), (17, 17), (11, 19),
              (7, 16), (21, 21), (14, 22), (18, 10))
        f.pts(STONE[0], (10, 13), (15, 22), (25, 17))
    elif stage == 2:
        f.pts(QUICK[1], (12, 14), (20, 16), (15, 21), (23, 19))
        f.pts(QUICK[0], (8, 17), (18, 12))
        f.pts(SALT, (14, 17), (22, 13))               # the last of the salt
    else:
        f.pts(QUICK[0], (9, 14), (15, 11), (21, 13), (25, 17), (18, 16), (12, 19),
              (7, 17), (20, 21), (14, 23), (16, 14), (23, 20), (10, 22))
        f.pts(QUICK[1], (10, 14), (22, 13), (19, 16), (13, 19), (21, 21), (15, 23), (17, 19))
        f.pts(QUICK[2], (16, 12), (26, 17), (8, 18))
    return f


# ------------------------------------------------------ arrastra overlay --

# The open frame of the grindstone state, row by row: the clear pixels under
# its top beam, beside and below the wheel, down to the lower rail.
TROUGH = {
    20: list(range(8, 11)) + list(range(22, 25)),
    21: list(range(8, 12)) + list(range(21, 25)),
    22: list(range(8, 13)) + list(range(20, 25)),
    23: list(range(7, 14)) + list(range(19, 25)),
    24: list(range(7, 25)),
}


def arrastra_overlay():
    """Dark water standing in the crusher's frame with the wheel dipping
    into it, and the quicksilver lying in it as bright beads."""
    f = Sprite()
    for y in (22, 23, 24):
        for x in TROUGH[y]:
            c = WATER[1] if y < 24 else WATER[2]
            if y == 22:
                c = WATER[0] if grain(x, y, 351) < 5 else WATER[1]   # the surface
            elif grain(x, y, 353) == 0:
                c = WATER[2] if y == 23 else WATER[1]
            f.put(x, y, c)
    # the wet climbing the frame and the wheel above the water line
    f.pts(WATER[1] + (150,), (8, 21), (24, 21), (11, 21), (21, 21))
    f.pts(WATER[0] + (110,), (9, 21), (23, 21))
    # ripples where the wheel meets the water
    f.pts(WATER[0], (13, 23), (19, 23), (15, 24), (17, 24))
    # the quicksilver
    f.pts(QUICK[0], (10, 23), (22, 23), (16, 24))
    f.pts(QUICK[1], (11, 23), (23, 24), (9, 24), (13, 24), (20, 24))
    f.pts(QUICK[2], (11, 24), (22, 24))
    return f


def states():
    """[(state, frames, delay)] in sheet order."""
    return [
        ('amalgam_gold', [amalgam(AMAL_GOLD, AMAL_GOLD_EDGE)], 0),
        ('amalgam_silver', [amalgam(AMAL_SILVER, AMAL_SILVER_EDGE)], 0),
        ('sponge_gold', [sponge(SPONGE_GOLD, SPONGE_GOLD_EDGE)], 0),
        ('sponge_silver', [sponge(SPONGE_SILVER, SPONGE_SILVER_EDGE)], 0),
        ('amalgam_tailings', [amalgam_tailings()], 0),
        ('amalgam_press', [amalgam_press()], 0),
        ('patio_heap_1', [patio_heap(1)], 0),
        ('patio_heap_2', [patio_heap(2)], 0),
        ('patio_heap_3', [patio_heap(3)], 0),
        ('arrastra_overlay', [arrastra_overlay()], 0),
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


def grindstone():
    """The first tile of the `grindstone` state the overlay is drawn for."""
    sheet = Image.open(STRUCTURES)
    index = 0
    for name, dirs, frames in re.findall(r'state = "(.*?)"\n\tdirs = (\d+)\n\tframes = (\d+)',
                                         sheet.info.get('Description', '')):
        if name == 'grindstone':
            cols = sheet.size[0] // SIZE
            x, y = (index % cols) * SIZE, (index // cols) * SIZE
            return sheet.convert('RGBA').crop((x, y, x + SIZE, y + SIZE))
        index += int(dirs) * int(frames)
    return None


def overlay_clear():
    """True when the overlay covers no drawn pixel of the grindstone."""
    base = grindstone()
    return base is not None and not any(base.getpixel(p)[3] for p in arrastra_overlay().px)


def check():
    if not SHEET.exists():
        return False
    im, text = build()
    old = Image.open(SHEET)
    return old.info.get('Description') == text and old.convert('RGBA').tobytes() == im.tobytes()


# -------------------------------------------------------------- review --

def preview(path, scale=4):
    """Every state, labelled, on grass (upper block) and dirt (lower), and
    last the grindstone with the arrastra overlay laid on it."""
    cells = []
    for name, frs, _ in states():
        for i, fr in enumerate(frs):
            cells.append((name if len(frs) == 1 else '%s [%d]' % (name, i + 1), fr.image()))
    base = grindstone()
    if base is not None:
        base.alpha_composite(arrastra_overlay().image())
        cells.append(('grindstone + overlay', base))
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


if __name__ == '__main__':
    if '--check' in sys.argv:
        if not check():
            sys.exit('stale sheet: ' + str(SHEET))
        if not overlay_clear():
            sys.exit('arrastra_overlay covers the grindstone in ' + str(STRUCTURES))
        print('amalgam states match')
    else:
        write_dmi()
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
