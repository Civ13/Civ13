"""Script-drawn dug wells for icons/obj/wells.dmi.

Every pixel is placed by this script from fixed palettes (Pillow only); no
external or generated artwork. It is the same family as create_sewers.py and
create_flood_defences.py and takes its earth, timber, stone and water colours
and its small drawing helpers from there. The wells are seen like the stone
wells in icons/obj/watercloset.dmi: from the south and a little above, low to
the ground, with the light from the upper left.

States, all 32x32 and 1 dir, 1 frame unless noted:

  waterhole_dry      A hole dug in the earth: a ring of heaped spoil, the cut
                     far side of the hole and a dry mud bottom with a few
                     stones.
  waterhole          The same with muddy water standing in the bottom.
  puddle-splash      2 frames, 5 ds each: rings spreading on the waterhole's
                     water. The waterhole is a puddle in the code, and a
                     puddle shows this state while someone is at it.
  timber_well_dry    A well lined with a crib of split logs: a square curb of
                     notched logs with their ends standing proud at the
                     corners, the south side of the curb two logs high, and
                     the timbered far wall going down into the dark.
  timber_well        The same with water glinting far down the shaft.

Every state keeps at least 1px clear on the left, right and bottom of the
tile, which `--check` enforces together with the frame counts.

Run with Pillow to rewrite icons/obj/wells.dmi (safe to rerun). `--out <dmi>`
writes the sheet somewhere else, `--preview <png>` writes a labelled review
sheet with every state on grass and dirt beside the stone wells they join,
`--check` only verifies that the committed sheet is what this script draws.
Released under Civ13 AGPL-3.0.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_water_animation import SIZE, read_dmi, write_dmi  # noqa: E402
from create_sewers import (  # noqa: E402
    BANK_LIT, BANK_SHADE, DARK, MUD, RIM, ROCK, SHADOW, WOOD, check_sheet, ground_tiles, image, loop, noise,
    option, pixels)

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/wells.dmi'
STONE_WELLS = ROOT / 'icons/obj/watercloset.dmi'

MARGIN = 1                               # clear pixels left, right and below
SPLASH_FRAMES, SPLASH_DELAY = 2, 5       # what the puddle code expects

# ---------------------------------------------------------------- waterhole

HOLE = (16.0, 17.0)                      # centre of the hole and its spoil
SPOIL_R = (12.6, 9.6)                    # the ring of heaped earth
MOUTH_R = (8.4, 5.9)                     # the mouth of the hole
FLOOR = (16.0, 19.2)                     # the bottom, seen past the near edge
FLOOR_R = (6.6, 3.4)
SPOIL_TOP = [(152, 116, 76), (134, 100, 64)]     # dry heaped earth, lit
CUT = [(104, 76, 48), (86, 62, 40), (68, 49, 33), (52, 38, 27)]   # the cut side, darker downward
MUDDY = [(96, 104, 86), (82, 92, 80), (110, 116, 94)]
MUDDY_SHADE = (62, 72, 66)
MUDDY_GLINT = (164, 170, 146)
RING = (148, 156, 134)


def inside(x, y, centre, radius, grow=0.0):
    dx = (x + 0.5 - centre[0]) / (radius[0] + grow)
    dy = (y + 0.5 - centre[1]) / (radius[1] + grow)
    return dx * dx + dy * dy


def waterhole(wet=False, ring=None):
    """The hole; `ring` is the size of a ripple on the water, 0..1."""
    px = {}
    for y in range(SIZE):
        for x in range(SIZE):
            # a ragged edge to the spoil, so it sits on the ground
            ragged = (noise(x // 2, y // 2, 811) - 0.5) * 1.6
            d = inside(x, y, HOLE, SPOIL_R, ragged)
            if d > 1:
                continue
            m = inside(x, y, HOLE, MOUTH_R)
            if m > 1:
                # heaped spoil: lit toward the upper left, shaded lower right
                side = (x - HOLE[0]) * 0.55 + (y - HOLE[1]) * 0.85
                if d > 0.8 and side > 1:
                    c = RIM[noise(x, y, 813) < 0.5]
                elif side < -3:
                    c = SPOIL_TOP[noise(x, y, 815) < 0.35]
                elif side < 3:
                    c = BANK_LIT[noise(x, y, 817) < 0.45]
                else:
                    c = BANK_SHADE[noise(x, y, 819) < 0.45]
                if noise(x, y, 821) > 0.965:
                    c = ROCK[2]                          # a stone in the spoil
                # the lip of the hole
                if m < 1.22:
                    c = RIM[1] if y < HOLE[1] else RIM[0]
                px[(x, y)] = c
                continue
            f = inside(x, y, FLOOR, FLOOR_R)
            if f > 1:
                # the cut far side, darker toward the bottom and to the left,
                # which the light does not reach
                down = (y - (HOLE[1] - MOUTH_R[1])) / (2 * MOUTH_R[1])
                tone = min(3, int(down * 4.2) + (1 if x < HOLE[0] - 3 else 0))
                if y > FLOOR[1]:
                    tone = 3                             # the near side is only its shadow
                c = CUT[tone]
                if tone < 3 and noise(x, y // 2, 823) > 0.86:
                    c = CUT[tone + 1]                    # a root or a seam
                px[(x, y)] = c
                continue
            if wet:
                c = MUDDY[1]
                if noise(x // 2, y, 825) < 0.3:
                    c = MUDDY[0]
                if f > 0.72:
                    c = MUDDY_SHADE                      # shadow of the sides on the water
                if (x, y) in ((13, 18), (14, 18), (15, 18), (18, 20)):
                    c = MUDDY_GLINT
                elif (x, y) in ((16, 18), (19, 20), (12, 19)):
                    c = MUDDY[2]
                if ring is not None:
                    r = inside(x, y, (FLOOR[0] - 1.0, FLOOR[1]), (FLOOR_R[0] * ring, FLOOR_R[1] * ring))
                    if 0.6 < r <= 1.0:
                        c = RING
                    elif ring < 0.5 and r <= 0.25:
                        c = MUDDY_GLINT                  # the drop goes in
            else:
                c = MUD[noise(x, y, 827) < 0.5]
                if f > 0.72:
                    c = CUT[3]
                if (x, y) in ((13, 19), (19, 18), (17, 21)):
                    c = ROCK[2]
                elif (x, y) in ((14, 19), (20, 18)):
                    c = ROCK[3]
            px[(x, y)] = c
    return image(px)


# -------------------------------------------------------------- timber well

CURB = (5, 7, 26, 22)                    # the top of the curb, x0 y0 x1 y1
LOG = 4                                  # thickness of a log seen from above
PROUD = 2                                # how far the long logs stand past the corners
FACE = (23, 27)                          # rows of the south side of the curb
SHAFT_WALL = 4                           # rows of the far wall seen in the shaft
DEEP = [(34, 26, 21), (26, 21, 18), (20, 17, 15)]
DEEP_WATER = [(38, 66, 82), (28, 48, 62)]
DEEP_GLINT = (126, 168, 176)


def log_tone(i):
    """Across a log seen from above: lit edge, body, body, shaded edge."""
    return (0, 1, 1, 2)[i]


def end_grain(px, x, y):
    """The sawn end of a log, 4x3, facing south."""
    for i in range(LOG):
        px[(x + i, y)] = WOOD[0]
        px[(x + i, y + 1)] = WOOD[1]
        px[(x + i, y + 2)] = WOOD[2]
    px[(x + 1, y + 1)] = WOOD[3]
    px[(x + 2, y + 1)] = WOOD[2]


def timber_well(wet=False):
    px = {}
    x0, y0, x1, y1 = CURB
    # the side logs run north-south and lie under the long ones
    for x in (x0, x1 - LOG + 1):
        for y in range(y0 - 1, y1 + 1):
            for i in range(LOG):
                c = WOOD[log_tone(i)]
                if noise(x + i, y // 3, 841) < 0.2:
                    c = WOOD[min(3, log_tone(i) + 1)]
                px[(x + i, y)] = c
        for i in range(LOG):
            px[(x + i, y0 - 1)] = WOOD[0] if i < LOG - 1 else WOOD[1]
    # the long logs run east-west over them and stand proud at each end
    for y in (y0, y1 - LOG + 1):
        for x in range(x0 - PROUD, x1 + PROUD + 1):
            for i in range(LOG):
                c = WOOD[log_tone(i)]
                if noise(x // 4, y + i, 843) < 0.22:
                    c = WOOD[min(3, log_tone(i) + 1)]
                px[(x, y + i)] = c
        # sawn ends, the left lit and the right in shade
        for i in range(LOG):
            px[(x0 - PROUD, y + i)] = WOOD[0]
            px[(x1 + PROUD, y + i)] = WOOD[3]
        px[(x0 - PROUD, y + 1)] = WOOD[1]
        # the notch where each sits on a side log
        for x in (x0 + LOG, x1 - LOG):
            for i in range(1, LOG):
                px[(x, y + i)] = WOOD[3] if y == y0 else WOOD[2]
    # the shaft
    sx0, sy0, sx1, sy1 = x0 + LOG, y0 + LOG, x1 - LOG, y1 - LOG
    for y in range(sy0, sy1 + 1):
        for x in range(sx0, sx1 + 1):
            row = y - sy0
            if row < SHAFT_WALL:
                # the timbered far wall: courses getting darker going down
                c = (WOOD[2], WOOD[3], DEEP[0], DEEP[1])[row]
                if row < 2 and (x + row * 3) % 7 == 0:
                    c = (WOOD[3], DEEP[0])[row]          # a joint between two timbers
                if x <= sx0 + 1:
                    c = DEEP[0] if row < 2 else DEEP[1]  # the west wall, out of the light
                elif x == sx1 and row < 2:
                    c = WOOD[2]                          # the east wall catches a little
            else:
                c = DEEP[1] if row == SHAFT_WALL else DEEP[2]
                if wet:
                    c = DEEP_WATER[1] if row == SHAFT_WALL or x <= sx0 + 2 else DEEP_WATER[0]
                    if (x, y) in ((sx0 + 5, sy0 + 5), (sx0 + 6, sy0 + 5), (sx0 + 9, sy0 + 6)):
                        c = DEEP_GLINT
            px[(x, y)] = c
    # the curb throws a shadow down the near side of the shaft
    for x in range(sx0, sx1 + 1):
        px[(x, sy1)] = DEEP[2] if not wet else DEEP_WATER[1]
    # the south side of the curb: the long log's side, then the course below
    f0, f1 = FACE
    for x in range(x0 - PROUD, x1 + PROUD + 1):
        px[(x, f0)] = WOOD[2]
        px[(x, f0 + 1)] = WOOD[3] if noise(x // 3, 0, 845) < 0.5 else WOOD[2]
        px[(x, f0 + 2)] = WOOD[3]
    # the lower long log, set back a pixel between the side logs' ends
    for x in range(x0, x1 + 1):
        px[(x, f0 + 2)] = WOOD[1] if noise(x // 4, 1, 847) < 0.7 else WOOD[2]
        px[(x, f0 + 3)] = WOOD[2]
        px[(x, f1)] = WOOD[3]
    for x in range(x0 - PROUD, x1 + PROUD + 1):
        if not x0 <= x <= x1:
            del px[(x, f0 + 2)]
    # the ends of the side logs show between the courses at each corner
    end_grain(px, x0, f0 + 2)
    end_grain(px, x1 - LOG + 1, f0 + 2)
    for x in range(x0 + 1, x1):
        px[(x, f1 + 1)] = SHADOW + (110,)
    px[(x0, f1 + 1)] = SHADOW + (70,)
    px[(x1, f1 + 1)] = SHADOW + (70,)
    return image(px)


# -------------------------------------------------------------------- sheet

STILLS = ('waterhole_dry', 'waterhole', 'timber_well_dry', 'timber_well')


def build():
    """The whole sheet as [(state, keys, images)]."""
    one = {'dirs': '1', 'frames': '1'}
    return [('waterhole_dry', dict(one), [waterhole()]),
            ('waterhole', dict(one), [waterhole(True)]),
            ('puddle-splash', loop(SPLASH_FRAMES, SPLASH_DELAY), [waterhole(True, 0.45), waterhole(True, 0.85)]),
            ('timber_well_dry', dict(one), [timber_well()]),
            ('timber_well', dict(one), [timber_well(True)])]


def check_drawing(states):
    """Rules the drawing itself must keep, whatever the palettes become."""
    by = {name: images for name, _, images in states}
    keys_of = {name: keys for name, keys, _ in states}
    problems = []
    want = list(STILLS) + ['puddle-splash']
    if sorted(by) != sorted(want) or len(states) != len(want):
        problems.append('state list is %s' % ', '.join(name for name, _, _ in states))
    for name, keys, images in states:
        if len(images) != int(keys['dirs']) * int(keys['frames']):
            problems.append('%s has %d images for its dirs and frames' % (name, len(images)))
        for im in images:
            if im.size != (SIZE, SIZE):
                problems.append('%s is not %dpx' % (name, SIZE))
                break
            if any(p[3] == 0 and p != (0, 0, 0, 0) for p in pixels(im)):
                problems.append('%s has coloured invisible pixels' % name)
                break
            box = im.getbbox()
            if box is None or box[0] < MARGIN or box[2] > SIZE - MARGIN or box[3] > SIZE - MARGIN:
                problems.append('%s does not keep its margin: %r' % (name, box))
                break
    for name in STILLS:
        if name in by and keys_of[name] != {'dirs': '1', 'frames': '1'}:
            problems.append('%s is not a single frame' % name)
    if keys_of.get('puddle-splash') != loop(SPLASH_FRAMES, SPLASH_DELAY):
        problems.append('puddle-splash is not %d frames of %d ds' % (SPLASH_FRAMES, SPLASH_DELAY))
    # wet and dry differ only inside the hole, and the splash only on the water
    for dry, wet in (('waterhole_dry', 'waterhole'), ('timber_well_dry', 'timber_well')):
        if dry in by and wet in by:
            a, b = pixels(by[dry][0]), pixels(by[wet][0])
            if a == b:
                problems.append('%s looks the same wet and dry' % wet)
            if [p[3] for p in a] != [p[3] for p in b]:
                problems.append('%s changes shape when it fills' % wet)
    if 'puddle-splash' in by and 'waterhole' in by:
        still = pixels(by['waterhole'][0])
        shots = [pixels(im) for im in by['puddle-splash']]
        if shots[0] == shots[1] or still in shots:
            problems.append('puddle-splash does not move')
        if any(sum(1 for p, q in zip(still, shot) if p != q) > 60 for shot in shots):
            problems.append('puddle-splash moves more than the water')
    return problems


# ------------------------------------------------------------------- review

def write_preview(path, states, scale=4):
    by = {name: images for name, _, images in states}
    grass, dirt = ground_tiles()
    stone = {}
    try:
        stone = {name: images[0] for name, _, images in read_dmi(STONE_WELLS)
                 if name in ('well1', 'well_dry', 'sandstone_well1', 'marble_well1', 'puddle')}
    except Exception:
        pass
    shots = []
    for name, _, images in states:
        for n, im in enumerate(images):
            shots.append((name if len(images) == 1 else 'splash %d' % n, im))
    label_h, pad = 12, 6
    cell = SIZE * scale
    family = [('puddle', stone.get('puddle')), ('waterhole', by['waterhole'][0]),
              ('timber_well', by['timber_well'][0]), ('well1', stone.get('well1')),
              ('sandstone', stone.get('sandstone_well1')), ('marble', stone.get('marble_well1'))]
    family = [(label, im) for label, im in family if im is not None]
    wide = pad + max(len(shots), len(family) + 1) * (cell + pad)
    high = pad + 2 * (cell + label_h + pad) + (SIZE + label_h + pad) + (cell + label_h + pad)
    sheet = Image.new('RGB', (wide, high), DARK)
    draw = ImageDraw.Draw(sheet)

    def tile(ground, im):
        out = ground.copy().convert('RGBA')
        out.alpha_composite(im)
        return out.convert('RGB')

    for col, (label, im) in enumerate(shots):
        for row, ground in enumerate((grass, dirt)):
            x, y = pad + col * (cell + pad), pad + row * (cell + label_h + pad)
            sheet.paste(tile(ground, im).resize((cell, cell), Image.NEAREST), (x, y + label_h))
            draw.text((x, y), label if row == 0 else 'dirt', fill=(220, 220, 220))
    ay = pad + 2 * (cell + label_h + pad)
    draw.text((pad, ay), 'at game size', fill=(220, 220, 220))
    for n, (_, im) in enumerate(shots):
        sheet.paste(tile(grass, im), (pad + n * (SIZE + 2), ay + label_h))
        sheet.paste(tile(dirt, im), (pad + (len(shots) + 1 + n) * (SIZE + 2), ay + label_h))
    by_y = ay + label_h + SIZE + pad
    draw.text((pad, by_y), 'beside the puddle and the stone wells already in the game', fill=(220, 220, 220))
    for n, (label, im) in enumerate(family):
        x = pad + n * (cell + pad)
        sheet.paste(tile(grass, im).resize((cell, cell), Image.NEAREST), (x, by_y + label_h))
    sheet.save(path)


def main():
    states = build()
    problems = check_drawing(states)
    if '--check' in sys.argv:
        problems += check_sheet(option('--sheet') or SHEET, states)
        for line in problems:
            print(line)
        print('wells: %s' % ('FAILED' if problems else 'ok'))
        return 1 if problems else 0
    if problems:
        print('\n'.join(problems))
        return 1
    write_dmi(option('--out') or SHEET, states)
    if option('--preview'):
        write_preview(option('--preview'), states)
    return 0


if __name__ == '__main__':
    sys.exit(main())
