"""Hand-placed 32px contraptions for icons/obj/contraptions.dmi: the
counterweight drum (`counterweight`, `counterweight_on`), the cam drum
sequencer (`cam_drum`, `cam_drum_on`) and the stationary steam engine
(`steam_engine`, `steam_engine_on`). Each has one direction; the `_on`
states are four-frame loops.

The counterweight drum is a timber gallows frame seen from the front: a rope
drum on an iron axle under the head beam, an iron ratchet wheel with its pawl
on the right end and a crank on the left, and a squared stone weight hanging
on the rope, wound right up. Running, the drum and ratchet turn, the crank
goes round and the stone sinks a pixel a frame as the rope pays out.

The cam drum is a wooden barrel on a low trestle, studded with pegs set in a
spiral. Four tappet levers hang from a rail behind it and rest their tips on
top of the barrel, each with a cord rising from its tip. Running, the pegs go
round and lift one tappet after another.

The steam engine stands on a masonry bed: an upright riveted iron boiler with
a firebox door and a short chimney, a horizontal cylinder on a stone block,
and the piston rod, crosshead and connecting rod turning a crank on a large
spoked iron flywheel. Cold it is dark; running, the wheel and crank turn, the
crosshead slides, the firebox glows orange and smoke puffs from the chimney.

Palette, outline and light (from the upper left) are those of
create_transmission.py and the prime movers in create_mechanical_power.py:
the same seasoned timber, wrought iron, field stone and hemp rope.

The art is drawn procedurally by this script: every pixel is placed from a
fixed palette (Pillow only); no external or generated artwork. Run it to
reproduce the sheet; `--check` verifies the committed sheet instead of
writing it, `--preview <png>` writes a 4x review sheet on grass. Released
under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageChops, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_transmission import Frame, TIMBER, STONE, IRON, GREASE, ROPE, PIT, grain  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/contraptions.dmi'

# polished brass on the engine's crosshead and crank pin
BRASS = [(232, 196, 104, 255), (176, 136, 60, 255)]
# the fire seen through the firebox door: bright, orange, deep
FIRE = [(255, 226, 120, 255), (250, 150, 50, 255), (196, 78, 30, 255)]
# iron and masonry lit by the fire
GLOW_IRON = (150, 92, 62, 255)
GLOW_STONE = (224, 160, 104, 255)
# chimney smoke, thinning as it rises
SMOKE = [(222, 222, 226, 240), (204, 204, 210, 190), (190, 190, 198, 120)]

FRAMES_ON = 4
DELAY_ON = 1


# ---------------------------------------------------------- counterweight

def counterweight(step=None):
    """`step` None is the drum wound up and standing; 0-3 are the frames of
    the weight coming down."""
    f = Frame()
    turn = 0 if step is None else step + 1        # rows the drum has turned
    drop = turn                                   # and the weight has sunk
    # sill, posts with their knee braces, head beam
    f.rect(2, 28, 29, 30, TIMBER[3])
    f.hline(2, 29, 28, TIMBER[1])
    f.hline(2, 29, 30, TIMBER[4])
    for x0 in (5, 25):
        f.rect(x0, 4, x0 + 2, 27, TIMBER[2])
        f.vline(x0, 4, 27, TIMBER[1])
        f.vline(x0 + 2, 4, 27, TIMBER[3])
        for y in range(6, 27):
            if grain(x0, y // 3, 2) == 0:
                f.put(x0 + 1, y, TIMBER[3])
    for i in range(3):
        f.pts(TIMBER[1], (8 + i, 24 + i), (24 - i, 24 + i))
        f.pts(TIMBER[3], (8 + i, 25 + i), (24 - i, 25 + i))
    f.rect(3, 1, 29, 3, TIMBER[2])
    f.hline(3, 29, 1, TIMBER[0])
    f.hline(3, 29, 3, TIMBER[4])
    f.pts(TIMBER[4], (6, 2), (26, 2), (4, 29), (27, 29))      # trenails
    # the iron axle, from the crank through both posts
    f.hline(2, 24, 9, IRON[0])
    f.hline(2, 24, 10, IRON[2])
    f.pts(IRON[1], (6, 9), (6, 10), (26, 9), (26, 10))        # its ends in the posts
    # the rope drum: a staved barrel whose seams go round with it
    shade = (0, 1, 1, 2, 2, 3, 3, 4)
    for i, y in enumerate(range(6, 14)):
        seam = (i - turn) % 4 == 2
        for x in range(9, 21):
            f.put(x, y, TIMBER[min(4, shade[i] + (1 if seam else 0))])
    f.vline(9, 6, 13, TIMBER[1])
    f.put(9, 13, TIMBER[3])
    # the rope coiled on it, and the fall down to the weight
    coil = range(12, 18)
    for i, y in enumerate(range(6, 14)):
        for x in coil:
            c = ROPE[0] if (x + turn) % 2 else ROPE[1]
            if i >= 5:
                c = ROPE[1] if (x + turn) % 2 else ROPE[2]
            f.put(x, y, c)
    top = 16 + drop
    for y in range(14, top - 1):
        f.put(15, y, ROPE[0] if (y - drop) % 3 else ROPE[1])
    # the stone weight, squared, with an iron strap and eye
    f.rect(11, top, 19, top + 6, STONE[1])
    f.hline(11, 19, top, STONE[0])
    f.vline(11, top, top + 6, STONE[0])
    f.rect(17, top + 1, 19, top + 6, STONE[2])
    f.vline(19, top + 1, top + 6, STONE[3])
    f.hline(11, 19, top + 6, STONE[3])
    f.pts(STONE[2], (13, top + 2), (12, top + 4), (14, top + 5))
    f.pts(STONE[3], (17, top + 3), (18, top + 5))
    f.vline(15, top, top + 6, IRON[1])
    f.put(15, top, IRON[0])
    f.put(15, top - 1, IRON[0])
    for p in ((11, top), (19, top), (11, top + 6), (19, top + 6)):
        f.px.pop(p, None)
    # the ratchet wheel, edge-on, its teeth going round with the drum
    for y in range(5, 15):
        tooth = (y - turn) % 4
        f.put(21, y, GREASE if tooth == 0 else IRON[0])
        f.put(22, y, IRON[2] if tooth == 3 else IRON[1])
        f.put(23, y, IRON[2])
        if tooth == 0:
            f.put(24, y, IRON[0])                 # a tooth standing proud
    # the pawl, pinned to the post, riding over the teeth
    up = step is not None and step % 2
    f.pts(IRON[0], (24, 16 - up), (25, 17))
    f.pts(IRON[1], (23, 15 - up))
    f.put(26, 17, GREASE)
    # the crank: down, toward us, up, away
    pose = 0 if step is None else step
    if pose == 0:
        f.vline(3, 10, 14, IRON[1])
        f.rect(1, 14, 2, 15, TIMBER[0])
        f.put(2, 15, TIMBER[2])
    elif pose == 2:
        f.vline(3, 5, 9, IRON[1])
        f.rect(1, 4, 2, 5, TIMBER[0])
        f.put(2, 5, TIMBER[2])
    elif pose == 1:
        f.rect(2, 8, 3, 11, IRON[0])
        f.rect(1, 8, 2, 11, TIMBER[0])
        f.vline(2, 9, 11, TIMBER[1])
    else:
        f.rect(2, 9, 3, 10, IRON[2])
        f.rect(1, 9, 2, 10, TIMBER[3])
    f.outline()
    f.shadow(3, 31, 30, 31)
    return f


# --------------------------------------------------------------- cam drum

TAPPETS = (8, 13, 18, 23)
CAM_CY, CAM_R = 19, 6


def cam_drum(step=None):
    """`step` None is the drum standing with every tappet down; 0-3 are the
    turning frames, each with a different tappet lifted."""
    f = Frame()
    cy, r = CAM_CY, CAM_R
    phase = 11.25 if step is None else step * 22.5
    # the trestle: sill, two end posts, and the tappet rail across the top
    f.rect(1, 28, 30, 30, TIMBER[3])
    f.hline(1, 30, 28, TIMBER[1])
    f.hline(1, 30, 30, TIMBER[4])
    for x0 in (2, 27):
        f.rect(x0, 5, x0 + 2, 27, TIMBER[2])
        f.vline(x0, 5, 27, TIMBER[1])
        f.vline(x0 + 2, 5, 27, TIMBER[3])
        f.rect(x0 - 1, 26, x0 + 3, 27, TIMBER[3])             # the foot
        f.hline(x0 - 1, x0 + 3, 26, TIMBER[1])
        f.pts(IRON[1], (x0 + 1, cy), (x0 + 1, cy + 1))        # the gudgeon
        f.put(x0 + 1, cy, IRON[0])
    f.rect(1, 2, 30, 4, TIMBER[2])
    f.hline(1, 30, 2, TIMBER[0])
    f.hline(1, 30, 4, TIMBER[4])
    f.pts(TIMBER[4], (3, 3), (28, 3))
    # the barrel, lit along the top, its stave seams going round
    seams = set()
    for j in range(4):
        a = (phase + 45 + j * 90) % 360
        if 20 < a < 160:
            seams.add(round(cy - r * math.cos(math.radians(a))))
    shade = {-6: 1, -5: 2, -4: 2, -3: 2, -2: 2, -1: 3, 0: 3, 1: 3, 2: 3, 3: 3, 4: 4, 5: 4, 6: 4}
    for dy in range(-r, r + 1):
        y = cy + dy
        ends = 1 if abs(dy) == r else 0
        for x in range(5 + ends, 27 - ends):
            f.put(x, y, TIMBER[min(4, shade[dy] + (1 if y in seams else 0))])
    for x in (6, 25):                                         # iron hoops
        for dy in range(-r, r + 1):
            f.put(x, cy + dy, IRON[0] if dy < -2 else IRON[1] if dy < 3 else IRON[2])
    # the pegs: four round each track, each track a step behind the last
    for k, x in enumerate(TAPPETS):
        for j in range(4):
            a = (phase + k * 22.5 + j * 90) % 360
            if a < 1 or a > 359:
                f.rect(x, cy - r - 2, x + 1, cy - r - 1, TIMBER[1])   # at the top, lifting
                f.hline(x, x + 1, cy - r - 2, TIMBER[0])
            elif a < 179:
                y = round(cy - r * math.cos(math.radians(a)))
                f.hline(x, x + 1, y, TIMBER[0])
                if y + 1 <= cy + r:
                    f.hline(x, x + 1, y + 1, TIMBER[1])
                if y + 2 <= cy + r:
                    f.hline(x, x + 1, y + 2, PIT)             # its shadow
            elif a < 181:
                f.hline(x, x + 1, cy + r + 1, TIMBER[3])      # under the barrel
    # the tappets hanging from the rail, tips on the barrel, and their cords
    for k, x in enumerate(TAPPETS):
        lifted = step is not None and (k + step) % 4 == 0
        tip = cy - r - (3 if lifted else 1)
        f.vline(x, 5, tip, TIMBER[0])
        f.vline(x + 1, 5, tip, TIMBER[2])
        f.hline(x, x + 1, tip, TIMBER[1])
        f.put(x, tip, TIMBER[0])
        for y in range(0, tip):
            f.put(x + 2, y, ROPE[0] if (y + (2 if lifted else 0)) % 3 else ROPE[1])
        f.put(x + 2, tip - 1, ROPE[2])                        # the knot
    f.outline()
    f.shadow(1, 31, 31, 31)
    return f


# ----------------------------------------------------------- steam engine

FLY_CX, FLY_CY, FLY_R = 24, 18, 7


def steam_engine(step=None):
    """`step` None is the engine cold; 0-3 are a turn of the crank."""
    f = Frame()
    on = step is not None
    ang = math.radians(210 if step is None else step * 90)
    cx, cy, r = FLY_CX, FLY_CY, FLY_R
    # the masonry bed
    for x in range(0, 32):
        f.put(x, 27, STONE[0])
        f.put(x, 28, STONE[3] if x % 6 == 2 else STONE[1])
        f.put(x, 29, STONE[3] if x % 6 == 5 else STONE[2])
        f.put(x, 30, STONE[4])
    f.pts(STONE[2], (4, 28), (15, 28), (22, 28))
    # the boiler: an upright riveted iron shell under a domed crown
    cols = {1: IRON[1], 2: IRON[0], 3: GREASE, 4: IRON[0], 5: IRON[1], 6: IRON[1],
            7: IRON[1], 8: IRON[2], 9: IRON[2], 10: IRON[2]}
    for x in range(1, 11):
        for y in range(12, 27):
            f.put(x, y, cols[x])
    for x in range(2, 10):
        f.put(x, 11, cols[x])
    f.pts(IRON[0], (2, 11), (3, 11), (4, 11))
    for y in (13, 18):                                        # riveted seams
        for x in range(1, 11):
            f.put(x, y, (GREASE if x < 8 else IRON[0]) if x % 2 == 0 else IRON[2])
    # the chimney
    for y in range(5, 11):
        f.put(5, y, IRON[0])
        f.put(6, y, IRON[1])
        f.put(7, y, IRON[2])
    f.hline(4, 8, 5, IRON[1])
    f.pts(IRON[0], (4, 5), (5, 5))
    f.put(8, 5, IRON[2])
    f.hline(4, 8, 10, IRON[2])                                # the flange on the crown
    f.put(4, 10, IRON[1])
    # the firebox door
    f.rect(3, 20, 9, 26, IRON[2])
    if on:
        for y in range(21, 26):
            for x in range(4, 9):
                g = grain(x, y, 11 + step)
                c = FIRE[1]
                if y >= 23 and g < 5:
                    c = FIRE[0]
                elif y == 21 or g > 8:
                    c = FIRE[2]
                f.put(x, y, c)
        f.vline(6, 21, 25, IRON[2])                           # the fire bars
        # the glow on the shell and the bed
        f.pts(GLOW_IRON, (2, 22), (2, 24), (10, 21), (10, 23), (10, 25), (5, 19), (7, 19))
        f.hline(3, 9, 27, GLOW_STONE)
        if step % 2:
            f.pts(GLOW_IRON, (2, 23), (10, 24), (4, 19), (8, 19))
            f.pts(GLOW_STONE, (2, 27), (10, 27))
    else:
        f.rect(4, 21, 8, 25, IRON[1])
        f.hline(4, 8, 21, IRON[0])
        f.vline(4, 21, 25, IRON[0])
        f.hline(5, 8, 25, IRON[2])
        f.hline(5, 7, 23, PIT)                                # the air slot
        f.put(8, 23, GREASE)                                  # the latch
    # the steam pipe over to the cylinder
    f.hline(11, 14, 14, IRON[0])
    f.hline(11, 14, 15, IRON[2])
    f.put(14, 14, GREASE)
    f.put(15, 15, IRON[1])
    # the cylinder on its stone block
    f.rect(12, 22, 17, 26, STONE[2])
    f.hline(12, 17, 22, STONE[0])
    f.vline(17, 23, 26, STONE[3])
    f.pts(STONE[3], (14, 24), (13, 26), (15, 25))
    for i, y in enumerate(range(16, 21)):
        f.hline(13, 16, y, (IRON[0], GREASE, IRON[0], IRON[1], IRON[2])[i])
    for x0 in (12, 17):
        f.vline(x0, 15, 21, IRON[1])
        f.put(x0, 15, IRON[0])
        f.put(x0, 21, IRON[2])
    # the flywheel's bearing stand, behind the wheel
    f.line(cx, cy, cx - 3, 26, IRON[2])
    f.line(cx, cy, cx + 3, 26, IRON[2])
    f.hline(cx - 4, cx + 4, 26, IRON[1])
    # the flywheel: a heavy iron rim on five spokes
    for a in range(0, 360, 2):
        ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        lit = (ca + sa) < -0.2
        f.put(round(cx + r * ca), round(cy + r * sa), IRON[0] if lit else IRON[2])
        f.put(round(cx + (r - 1) * ca), round(cy + (r - 1) * sa), IRON[1])
    for k in range(5):
        a = ang + math.radians(k * 72 + 36)
        f.line(cx, cy, round(cx + (r - 2) * math.cos(a)), round(cy + (r - 2) * math.sin(a)),
               IRON[0] if k % 2 else IRON[1])
    # the crank, the connecting rod, the crosshead and the piston rod
    px, py = round(cx + 2 * math.cos(ang)), round(cy + 2 * math.sin(ang))
    hx = px - round(math.sqrt(16 - (py - cy) ** 2))
    f.line(cx, cy, px, py, IRON[2])
    f.hline(18, hx, cy, GREASE)
    f.line(hx, cy, px, py, GREASE)
    f.vline(hx, cy - 1, cy + 1, BRASS[0])
    f.put(hx, cy + 1, BRASS[1])
    f.rect(cx - 1, cy - 1, cx + 1, cy + 1, IRON[1])
    f.put(cx, cy, IRON[2])
    f.put(cx - 1, cy - 1, IRON[0])
    f.put(px, py, BRASS[0])
    f.outline()
    f.shadow(1, 31, 31, 31)
    # smoke from the chimney: a puff that grows, drifts and thins
    puffs = {
        0: (((5, 3), (6, 3), (7, 3), (6, 2)), (), ()),
        1: (((6, 3), (6, 1), (7, 1), (7, 2), (8, 1), (6, 2)), ((8, 2), (7, 0), (8, 0)), ()),
        2: (((6, 3),), ((7, 1), (8, 1), (9, 1), (8, 2), (7, 2), (8, 0), (9, 0)),
            ((10, 0), (10, 1), (9, 2), (7, 0))),
        3: (((6, 3), (6, 2)), ((10, 0), (11, 0)),
            ((9, 0), (12, 0), (10, 1), (11, 1), (12, 1), (9, 1))),
    }.get(step, ((), (), ()))
    for c, points in zip(SMOKE, puffs):
        for x, y in points:
            f.put(x, y, c)
    return f


def states():
    """[(state, frames)] in sheet order; every state has one direction."""
    on = range(FRAMES_ON)
    return [
        ('counterweight', [counterweight()]),
        ('counterweight_on', [counterweight(i) for i in on]),
        ('cam_drum', [cam_drum()]),
        ('cam_drum_on', [cam_drum(i) for i in on]),
        ('steam_engine', [steam_engine()]),
        ('steam_engine_on', [steam_engine(i) for i in on]),
    ]


def build_sheet(st):
    frames = [fr for _, group in st for fr in group]
    sheet = Image.new('RGBA', (32 * len(frames), 32), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(fr.image(), (i * 32, 0))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, group in st:
        text += 'state = "%s"\n\tdirs = 1\n\tframes = %d\n' % (name, len(group))
        if len(group) > 1:
            text += '\tdelay = %s\n' % ','.join([str(DELAY_ON)] * len(group))
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
    """A row per state at 4x on grass, a frame per column, with the same
    frames at true size beside them."""
    grass = (94, 132, 62, 255)
    pad = 6
    cell = 32 * scale
    cols = max(len(group) for _, group in st)
    sheet = Image.new('RGBA', (pad + cols * (cell + pad) + cols * (32 + pad),
                               pad + len(st) * (cell + pad)), grass)
    for j, (_, group) in enumerate(st):
        y = pad + j * (cell + pad)
        for i, fr in enumerate(group):
            tile = Image.new('RGBA', (32, 32), grass)
            tile.alpha_composite(fr.image())
            sheet.paste(tile.resize((cell, cell), Image.NEAREST), (pad + i * (cell + pad), y))
            sheet.paste(tile, (pad + cols * (cell + pad) + i * (32 + pad), y + (cell - 32) // 2))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


if __name__ == '__main__':
    st = states()
    if '--check' in sys.argv:
        check(SHEET, st)
    else:
        write_dmi(SHEET, st)
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1], st)
