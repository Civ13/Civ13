"""Script-drawn sprites for washing: the wash basin and washstand in
icons/obj/washstand.dmi and the dirty hands badge in
icons/effects/dirty_hands.dmi.

Every pixel is placed by this script from the fixed palettes below (Pillow
only); no external or generated artwork. The clay is the fired clay of the
bowls and pitchers in icons/obj/claystuff.dmi, the timber is the dark wood of
the nightstand in icons/obj/structures.dmi.

icons/obj/washstand.dmi, all 32x32, 1 dir, 1 frame, 1px clear on the left,
right and bottom:

  basin            a wide fired clay wash basin standing on the floor, empty
  basin_full       the same with clear water to just under the rim
  washstand        a four-legged wooden stand with a lower shelf, holding a
                   smaller clay basin and a clay pitcher, basin empty
  washstand_full   the same with clear water in the basin

icons/effects/dirty_hands.dmi, 32x32, 1 dir, 1 frame:

  dirty_hands      a badge laid over the HUD hunger/thirst icon (the
                   nutrition1..nutrition4 states of the icons/mob/screen/
                   style sheets): a grimy open hand with brown smears and two
                   stink lines, inside a 1px dark outline, in the bottom-left
                   12x12 pixels only. The rest of the tile is clear, so the
                   leaf of the nutrition icon stays readable.

Run with Pillow to rewrite both sheets (safe to rerun). `--check` only
verifies that the committed sheets are what this script draws, `--preview
<png>` writes a 4x review sheet with every state on grass and on a wooden
floor, the same at 1x and 2x, and the badge over nutrition1..nutrition4 of
each HUD style. Released under Civ13 AGPL-3.0.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_clay_lime_fire import Frame, grain  # noqa: E402
from create_water_animation import SIZE, pixels, read_dmi, write_dmi  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/washstand.dmi'
BADGE_SHEET = ROOT / 'icons/effects/dirty_hands.dmi'
FLOORS = ROOT / 'icons/turf/floors.dmi'
HUD_STYLES = ('1713Style', 'FoFStyle', 'litewebStyle', 'ConsoleStyle')
HUD_DIR = ROOT / 'icons/mob/screen'

MARGIN = 1                     # clear pixels left, right and below
BADGE_BOX = (0, 20, 11, 31)    # the badge stays inside this, x0 y0 x1 y1

# fired clay, as claystuff.dmi: highlight, light, mid, dark, deep, edge
CLAY = [(128, 84, 78), (109, 69, 66), (100, 55, 55), (88, 49, 55), (72, 40, 46), (54, 33, 37)]
# the hollow of the basin, in its own shade: lit far wall, mid, floor, deep
HOLLOW = [(92, 54, 55), (78, 44, 48), (64, 36, 42), (50, 29, 36)]
# clear water over clay: glint, light, mid, shade under the rim
WATER = [(214, 236, 240), (138, 190, 208), (104, 160, 186), (74, 124, 156)]
# dark furniture wood: highlight, light, mid, dark, deep, edge
WOOD = [(168, 118, 66), (144, 92, 46), (124, 70, 34), (98, 54, 28), (72, 40, 24), (42, 24, 16)]

# the badge: dirty skin light, mid, shade; grime light, dark; stink; outline
SKIN = [(232, 196, 150), (206, 164, 118), (160, 120, 82)]
GRIME = [(124, 84, 44), (78, 50, 26)]
STINK = (150, 172, 62)
BADGE_OUT = (26, 18, 12)


# -------------------------------------------------------------------- clay

def bowl(f, cx, cy, rx, ry, depth, foot, water=False):
    """A round clay basin seen from above and in front: the mouth is an
    ellipse at (cx, cy), the wall falls `depth` rows to a foot `foot` wide."""
    for y in range(int(cy + 0.5), int(cy + depth) + 1):          # the outside wall
        t = (y - cy) / depth
        half = rx - (rx - foot) * t ** 2.2
        for x in range(int(cx - half + 0.999), int(cx + half) + 1):
            nx = (x - cx) / half
            c = CLAY[2]
            if nx < -0.6:
                c = CLAY[1]
            elif nx > 0.72:
                c = CLAY[4]
            elif nx > 0.3:
                c = CLAY[3]
            if y == int(cy + depth):                             # the foot, in shade
                c = CLAY[4] if nx < 0.3 else CLAY[5]
            elif t > 0.45 and -0.6 < nx < -0.25 and grain(x, y, 4) < 4:
                c = CLAY[1]                                      # a soft band of light
            f.put(x, y, c)

    def rim(x, y, nx, ny):
        if ny < -0.35:
            return CLAY[1] if nx < 0.35 else CLAY[2]
        if nx < -0.45:
            return CLAY[0] if ny < 0.3 else CLAY[1]
        return CLAY[2] if nx < 0.5 else CLAY[3]
    f.ellipse(cx, cy, rx, ry, rim)

    def hollow(x, y, nx, ny):
        # lit from the upper left: the near left wall is in the rim's shadow,
        # the far right wall catches the light
        if ny < -0.55:
            return HOLLOW[3]
        light = nx * 0.7 + ny * 0.6
        if light > 0.45:
            return HOLLOW[0]
        if light > -0.2:
            return HOLLOW[1]
        return HOLLOW[2]
    f.ellipse(cx, cy + 0.2, rx - 1.7, ry - 1.3, hollow)

    if water:
        def pool(x, y, nx, ny):
            if ny < -0.4:
                return WATER[3]                                  # the rim's shadow on it
            if nx * 0.7 + ny * 0.5 > 0.35:
                return WATER[1]
            return WATER[2]
        f.ellipse(cx, cy + 0.5, rx - 2.4, ry - 1.7, pool)


def floor_basin(water=False):
    f = Frame()
    cx, cy = 15.5, 15.5
    bowl(f, cx, cy, 12.0, 6.0, 12, 7.0, water)
    f.pts(CLAY[0], (5, 13), (6, 12), (7, 12), (8, 11))           # light on the lip
    f.pts(CLAY[0], (5, 19), (6, 21), (6, 22))                    # and on the belly
    for x in range(6, 26):                                       # a scored line under the rim
        if 22 <= 15.5 + 6.0 * (1 - ((x - cx) / 12.0) ** 2) ** 0.5 + 1 and x % 5 != 2:
            y = int(cy + 6.0 * (1 - ((x - cx) / 12.0) ** 2) ** 0.5 + 1.6)
            if (x, y) in f.px and (x, y + 1) in f.px:
                f.put(x, y, CLAY[3] if x < 19 else CLAY[4])
    if water:
        f.pts(WATER[0], (11, 15), (12, 15), (13, 14), (20, 18), (21, 18))
        f.pts(WATER[1], (9, 16), (10, 17), (16, 13), (17, 13))
    else:
        f.pts(HOLLOW[0], (20, 18), (21, 17))                     # a dry glint on the floor
    f.outline(CLAY[5])
    return f


# ------------------------------------------------------------------- stand

def board(f, x0, y0, x1, y1, seed, tone=1):
    """A board seen from above: long grain, a lit far edge."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            c = WOOD[tone]
            if y == y0:
                c = WOOD[tone - 1]
            elif grain(x // 4, y, seed) < 2:
                c = WOOD[tone + 1]
            f.put(x, y, c)


def leg(f, x, y0, y1, far=False):
    f.vline(x, y0, y1, WOOD[3] if far else WOOD[2])
    f.vline(x + 1, y0, y1, WOOD[4] if far else WOOD[3])
    if not far:
        f.put(x, y1, WOOD[3])
        f.put(x + 1, y1, WOOD[4])


def pitcher(f, cx, base):
    """A clay pitcher standing on the stand, spout to the left, handle right."""
    def belly(x, y, nx, ny):
        light = -nx * 0.8 - ny * 0.4
        if light > 0.45:
            return CLAY[1]
        if light > -0.25:
            return CLAY[2]
        return CLAY[3] if light > -0.75 else CLAY[4]
    f.ellipse(cx, base - 3.5, 3.6, 3.6, belly)
    f.hline(cx - 1, cx + 1, base, CLAY[4])                       # the foot
    f.rect(cx - 1, base - 9, cx + 1, base - 7, CLAY[2])          # the neck
    f.vline(cx - 1, base - 9, base - 7, CLAY[1])
    f.vline(cx + 1, base - 9, base - 7, CLAY[3])
    f.hline(cx - 2, cx + 2, base - 10, CLAY[1])                  # the lip
    f.put(cx - 3, base - 10, CLAY[0])                            # the spout
    f.put(cx - 2, base - 10, CLAY[0])
    f.put(cx, base - 10, HOLLOW[2])                              # its dark mouth
    f.put(cx + 1, base - 10, HOLLOW[2])
    f.pts(CLAY[3], (cx + 3, base - 9), (cx + 4, base - 8), (cx + 5, base - 7),
          (cx + 5, base - 6), (cx + 4, base - 5))                # the handle
    f.put(cx - 2, base - 5, CLAY[0])                             # light on the belly


def washstand(water=False):
    f = Frame()
    leg(f, 7, 21, 26, far=True)                                  # far legs, seen under the top
    leg(f, 23, 21, 26, far=True)
    board(f, 6, 23, 25, 25, 9, tone=2)                           # the shelf
    f.hline(6, 25, 26, WOOD[4])                                  # its front edge
    f.pts(WOOD[1], (9, 23), (10, 23), (17, 23), (18, 23), (19, 23))
    f.rect(11, 23, 14, 24, CLAY[2])                              # a folded cloth and a
    f.hline(11, 14, 23, CLAY[1])                                 # clay soap dish on it
    f.rect(19, 23, 22, 24, (206, 198, 176))
    f.hline(19, 22, 24, (168, 160, 140))
    leg(f, 3, 21, 29)                                            # near legs
    leg(f, 27, 21, 29)
    board(f, 3, 13, 28, 18, 3)                                   # the top
    f.hline(3, 28, 19, WOOD[2])                                  # its front edge
    f.hline(3, 28, 20, WOOD[4])
    f.pts(WOOD[1], (3, 19), (4, 19), (5, 19))
    f.pts(WOOD[3], (25, 19), (26, 19), (27, 19), (28, 19))
    f.hline(5, 17, 17, WOOD[3])                                  # the basin's shadow
    f.hline(20, 27, 17, WOOD[3])                                 # and the pitcher's
    bowl(f, 10.5, 10.5, 7.0, 3.4, 6, 4.0, water)
    f.pts(CLAY[0], (5, 9), (6, 8), (7, 8))
    if water:
        f.pts(WATER[0], (8, 10), (9, 10), (13, 12))
        f.pts(WATER[1], (7, 11), (12, 9))
    pitcher(f, 23, 16)
    f.outline(WOOD[5])
    return f


# ------------------------------------------------------------------- badge

def dirty_hands():
    """An open left hand, fingers up, with grime on the palm and fingertips.
    The finger gaps are left clear so the outline draws them."""
    f = Frame()
    fingers = ((3, 24), (5, 22), (7, 21), (9, 23))               # column, top row
    for x, top in fingers:
        f.vline(x, top, 26, SKIN[0])
        f.put(x, top, GRIME[0])                                  # dirty fingertips
    f.rect(3, 27, 9, 30, SKIN[1])                                # the palm
    f.hline(3, 9, 26, SKIN[0])
    f.hline(4, 9, 30, SKIN[2])
    f.vline(9, 27, 30, SKIN[2])
    f.pts(SKIN[0], (1, 26), (2, 27))                             # the thumb
    f.pts(SKIN[1], (1, 27), (2, 28))
    f.pts(GRIME[0], (5, 27), (7, 27), (4, 28), (8, 29), (5, 30), (9, 25), (5, 23), (7, 22), (1, 26))
    f.pts(GRIME[1], (6, 27), (5, 28), (6, 28), (7, 28), (6, 29), (7, 29), (3, 25), (7, 24))
    f.outline(BADGE_OUT)
    f.pts(STINK, (1, 23), (0, 22), (1, 21))                      # stink lines rising
    f.pts(STINK, (11, 22), (10, 21), (11, 20))
    return f


# -------------------------------------------------------------------- sheets

KEYS = {'dirs': '1', 'frames': '1'}


def build():
    """{sheet path: [(state, keys, images)]}."""
    return {
        SHEET: [('basin', dict(KEYS), [floor_basin().image()]),
                ('basin_full', dict(KEYS), [floor_basin(True).image()]),
                ('washstand', dict(KEYS), [washstand().image()]),
                ('washstand_full', dict(KEYS), [washstand(True).image()])],
        BADGE_SHEET: [('dirty_hands', dict(KEYS), [dirty_hands().image()])],
    }


def drawn(im):
    """[(x, y)] of every pixel that is not clear."""
    return [(i % SIZE, i // SIZE) for i, p in enumerate(pixels(im)) if p[3]]


def check_drawing(sheets):
    """Rules the drawing itself must keep, whatever the palettes become."""
    problems = []
    for name, _, images in sheets[SHEET]:
        spots = drawn(images[0])
        if any(x < MARGIN or x >= SIZE - MARGIN or y >= SIZE - MARGIN for x, y in spots):
            problems.append('%s does not keep %dpx clear left, right and below' % (name, MARGIN))
        if any(p[3] not in (0, 255) for p in pixels(images[0])):
            problems.append('%s has a half-clear pixel' % name)
    by_name = dict((name, images[0]) for name, _, images in sheets[SHEET])
    for dry in ('basin', 'washstand'):
        wet = by_name[dry + '_full']
        if set(drawn(by_name[dry])) != set(drawn(wet)):
            problems.append('%s_full is not the same outline as %s' % (dry, dry))
        if not set(pixels(wet)) & set(c + (255,) for c in WATER):
            problems.append('%s_full shows no water' % dry)
        if set(pixels(by_name[dry])) & set(c + (255,) for c in WATER):
            problems.append('%s shows water' % dry)
    badge = sheets[BADGE_SHEET][0][2][0]
    x0, y0, x1, y1 = BADGE_BOX
    if any(not (x0 <= x <= x1 and y0 <= y <= y1) for x, y in drawn(badge)):
        problems.append('dirty_hands leaves the bottom-left 12x12')
    return problems


def check_sheet(path, states):
    """The committed sheet is exactly what build() draws."""
    if not Path(path).exists():
        return ['%s is missing' % path]
    have = read_dmi(path)
    if [name for name, _, _ in have] != [name for name, _, _ in states]:
        return ['%s state list differs: %s' % (Path(path).name, ', '.join(name for name, _, _ in have))]
    problems = []
    for (name, keys, images), (_, want_keys, want_images) in zip(have, states):
        if keys != want_keys:
            problems.append('%s has dirs/frames %r, expected %r' % (name, keys, want_keys))
        elif any(pixels(a) != pixels(b) for a, b in zip(images, want_images)):
            problems.append('%s is not what this script draws' % name)
    return problems


# ------------------------------------------------------------------- review

def write_preview(path, sheets, scale=4):
    """Rows 1-2: every state on grass and on a wooden floor at 4x. Row 3: the
    same at 2x and 1x. Rows 4 on: the badge over nutrition1..4 of each HUD
    style at 4x, with the 1x pair beside it."""
    floors = dict((name, images[0]) for name, _, images in read_dmi(FLOORS))
    grounds = (('grass', floors['grass0']), ('wood floor', floors['wood']))
    states = [(name, images[0]) for name, _, images in sheets[SHEET]]
    badge = sheets[BADGE_SHEET][0][2][0]
    shown = states + [('dirty_hands', badge)]
    huds = []
    for style in HUD_STYLES:
        by_name = dict((name, images[0]) for name, _, images in read_dmi(HUD_DIR / (style + '.dmi')))
        huds.append((style, [by_name['nutrition%d' % i] for i in range(1, 5)]))

    gap, top, left = 10, 16, 10
    cell = SIZE * scale
    width = left + max(len(shown) * (cell + gap), 2 * len(shown) * (3 * SIZE + 8) + 3 * gap)
    height = gap + 2 * (cell + top + gap) + (2 * SIZE + top + gap) + len(huds) * (cell + top + gap)
    sheet = Image.new('RGB', (width, height), (32, 32, 36))
    draw = ImageDraw.Draw(sheet)

    def tile(ground, im, zoom):
        t = ground.copy()
        t.alpha_composite(im)
        return t.convert('RGB').resize((SIZE * zoom, SIZE * zoom), Image.NEAREST)

    y = gap
    for label, ground in grounds:
        for i, (name, im) in enumerate(shown):
            at = left + i * (cell + gap)
            draw.text((at, y), '%s, %s' % (name, label), fill=(230, 230, 230))
            sheet.paste(tile(ground, im, scale), (at, y + top))
        y += cell + top + gap
    draw.text((left, y), '2x and 1x', fill=(230, 230, 230))
    x = left
    for zoom in (2, 1):
        for label, ground in grounds:
            for name, im in shown:
                sheet.paste(tile(ground, im, zoom), (x, y + top))
                x += SIZE * zoom + 4
        x += gap
    y += 2 * SIZE + top + gap
    back = Image.new('RGBA', (SIZE, SIZE), (58, 58, 64, 255))
    for style, icons in huds:
        draw.text((left, y), 'dirty_hands over nutrition1-4, %s (4x, then 2x and 1x)' % style, fill=(230, 230, 230))
        x = left
        for zoom in (scale, 2, 1):
            for icon in icons:
                t = back.copy()
                t.alpha_composite(icon)
                t.alpha_composite(badge)
                sheet.paste(t.convert('RGB').resize((SIZE * zoom, SIZE * zoom), Image.NEAREST), (x, y + top))
                x += SIZE * zoom + (gap if zoom == scale else 4)
            x += gap
        y += cell + top + gap
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


def option(name):
    args = sys.argv[1:]
    return args[args.index(name) + 1] if name in args[:-1] else None


def main():
    sheets = build()
    problems = check_drawing(sheets)
    if '--check' in sys.argv:
        for path, states in sheets.items():
            problems += check_sheet(path, states)
        for line in problems:
            print(line)
        print('wash places: %s' % ('FAILED' if problems else 'ok'))
        return 1 if problems else 0
    if problems:
        print('\n'.join(problems))
        return 1
    for path, states in sheets.items():
        write_dmi(path, states)
    if option('--preview'):
        write_preview(option('--preview'), sheets)
    return 0


if __name__ == '__main__':
    sys.exit(main())
