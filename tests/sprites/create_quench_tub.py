"""Script-drawn sprites for the blacksmith's quench tub in
icons/obj/quench_tub.dmi.

Every pixel is placed by this script from the fixed palettes below (Pillow
only); no external or generated artwork. The staves and iron hoops use the
colours of the wooden barrels in icons/obj/barrel.dmi, lit from the top left
inside a dark outline.

icons/obj/quench_tub.dmi, all 32x32, 1 dir:

  quench_tub         a squat coopered tub, lower and wider than a barrel,
                     with two iron hoops; empty, the dry floor in shadow
  quench_tub_full    the same with dark grey-blue quenching water to just
                     under the rim and a small glint
  quench_tub_steam   the full tub with white steam puffing off the water,
                     6 frames of 1.5 ticks, looping; the tub and water are
                     the same pixels in every frame, only the steam moves

Run with Pillow to rewrite the sheet (safe to rerun). `--check` only verifies
that the committed sheet is what this script draws, `--preview <png>` writes
a 4x review sheet with every state and frame on grass and on a wooden floor.
Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_clay_lime_fire import Frame, grain  # noqa: E402
from create_water_animation import SIZE, pixels, read_dmi, write_dmi  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/quench_tub.dmi'
FLOORS = ROOT / 'icons/turf/floors.dmi'

STEAM_FRAMES = 6
STEAM_DELAY = '1.5'

# barrel staves: highlight, light, mid, dark, deep
WOOD = [(168, 120, 52), (149, 101, 36), (132, 90, 33), (112, 64, 0), (97, 51, 29)]
SEAM = (60, 31, 17)            # the joints between staves
OUT = (38, 20, 12)             # the outline
# iron hoops: glint, light, mid, dark
IRON = [(149, 149, 149), (114, 114, 114), (95, 95, 95), (69, 69, 69)]
RIVET = (44, 44, 46)
# the dry inside: lit far wall, wall, floor, deep shadow
DRY = [(104, 62, 26), (84, 46, 20), (62, 33, 16), (44, 24, 13)]
# quenching water, dark with scale and soot: glint, light, mid, dark, shadow
WATER = [(150, 176, 190), (88, 112, 130), (66, 88, 108), (52, 70, 90), (38, 52, 70)]
# steam: bright core, body, thin edge (with alpha)
STEAM = [(255, 255, 255, 235), (236, 240, 244, 175), (222, 228, 234, 100)]

CX = 15.5                      # the tub's centre column
MOUTH = (16.5, 10.4, 3.8)      # the opening: centre row, half width, half height
FOOT = (26.2, 9.4, 3.0)        # the bottom edge: centre row, half width, half height
HOOPS = (2, 6)                 # rows below the front lip where each hoop starts


def arc(x, cy, rx, ry):
    """The front (lower) edge of an ellipse at column x, or None outside it."""
    nx = (x - CX) / rx
    if abs(nx) > 1.0:
        return None
    return cy + ry * math.sqrt(1.0 - nx * nx)


def tub(water=False):
    f = Frame()
    my, mrx, mry = MOUTH
    fy, frx, fry = FOOT
    # the outside wall: staves hanging from the front lip down to the foot
    for x in range(int(CX - mrx), int(CX + mrx) + 1):
        top = arc(x, my, mrx, mry)
        if top is None:
            continue
        bottom = arc(x, fy, frx, fry)
        if bottom is None:                                       # the flare past the foot
            bottom = fy - 1.0
        nx = (x - CX) / mrx
        stave = (x - 6) % 3 == 0                                 # a joint every third column
        for y in range(int(top + 0.5), int(bottom + 0.5) + 1):
            if nx < -0.72:
                c = WOOD[2]
            elif nx < -0.2:
                c = WOOD[1]
            elif nx < 0.42:
                c = WOOD[2]
            elif nx < 0.78:
                c = WOOD[3]
            else:
                c = WOOD[4]
            if stave:
                c = SEAM if nx > -0.2 else WOOD[4]
            elif grain(x, y, 5) == 0:
                c = WOOD[min(4, WOOD.index(c) + 1)]              # a fleck of grain
            if y >= int(bottom + 0.5):                           # the foot, in shade
                c = WOOD[4] if nx < 0.3 and not stave else SEAM
            f.put(x, y, c)
        for drop in HOOPS:                                       # the iron hoops, two rows each
            y = int(top + 0.5) + drop
            if y + 1 < int(bottom + 0.5):
                if nx < -0.78:
                    hi, lo = IRON[2], IRON[3]
                elif nx < -0.3:
                    hi, lo = IRON[0], IRON[1]
                elif nx < 0.4:
                    hi, lo = IRON[1], IRON[2]
                else:
                    hi, lo = IRON[2], IRON[3]
                f.put(x, y, hi)
                f.put(x, y + 1, lo)
    for drop in HOOPS:                                           # one rivet on each hoop
        f.put(18, int(arc(18, my, mrx, mry) + 0.5) + drop, RIVET)

    # the rim: the stave ends seen from above
    def rim(x, y, nx, ny):
        if (x - 6) % 3 == 0 and abs(ny) > 0.25:
            return WOOD[3] if ny < 0 else WOOD[4]
        if ny > 0.2:
            return WOOD[0] if nx < 0.1 else WOOD[1]
        return WOOD[1] if nx < 0.3 else WOOD[2]
    f.ellipse(CX, my, mrx, mry, rim)

    # the inside
    def hollow(x, y, nx, ny):
        if ny < -0.45:                                           # under the far lip... lit wall
            return DRY[0] if nx > -0.1 else DRY[1]
        if (x - 6) % 3 == 0 and ny < 0.1:
            return DRY[3]
        if ny < 0.05:
            return DRY[1] if nx > -0.4 else DRY[2]
        return DRY[2] if nx * 0.6 + ny < 0.55 else DRY[3]        # the floor, in shadow

    def pool(x, y, nx, ny):
        if nx * nx + ny * ny > 0.78 and ny < 0.2:
            return WATER[4]                                      # the wall's shadow on it
        light = -nx * 0.6 - ny * 0.5
        if light > 0.3:
            return WATER[3]
        if light > -0.35:
            return WATER[2]
        return WATER[1]
    f.ellipse(CX, my, mrx - 1.6, mry - 1.5, pool if water else hollow)
    if water:
        f.pts(WATER[0], (11, 15), (12, 15), (13, 16))            # the glint
        f.pts(WATER[1], (18, 18), (19, 18), (10, 16))
        f.pts(WATER[3], (16, 16), (17, 16), (20, 17))            # a slow ripple
    else:
        f.pts(DRY[3], (9, 17), (10, 18), (11, 18), (12, 18))     # the near wall's shadow
    f.outline(OUT)
    return f


# the puffs: start column, drift, how far through the loop each one is born
PUFFS = ((13.0, -1.6, 0), (17.5, 1.8, 2), (15.0, 0.6, 4))


def steam(index):
    """One frame of steam as an RGBA layer; each puff rises, swells and thins
    over one whole loop, so the last frame runs into the first."""
    layer = Image.new('RGBA', (SIZE, SIZE))
    best = {}
    for x0, drift, born in PUFFS:
        t = ((index - born) % STEAM_FRAMES) / STEAM_FRAMES
        cx = x0 + drift * t + 0.9 * math.sin(t * 5.0 + born)
        cy = 15.5 - 13.0 * t
        fade = 1.0 - max(0.0, t - 0.45) / 0.55                   # 1 while young, 0 when gone
        radius = (1.5 + 2.4 * math.sin(min(t * 1.5, 1.0) * math.pi / 2)) * (0.55 + 0.45 * fade)
        for y in range(SIZE):
            for x in range(SIZE):
                d = math.hypot(x - cx, (y - cy) * 1.1) / radius
                d += (grain(x, y, 7 + born) - 5) * 0.04          # a ragged edge
                if d > 1.0:
                    continue
                strength = (1.0 - d) * 0.9 + fade * 0.75
                tone = 0 if strength > 1.15 else 1 if strength > 0.7 else 2
                if (x, y) not in best or tone < best[(x, y)]:
                    best[(x, y)] = tone
    for (x, y), tone in best.items():
        layer.putpixel((x, y), STEAM[tone])
    return layer


def steam_frames():
    base = tub(True).image()
    frames = []
    for i in range(STEAM_FRAMES):
        im = base.copy()
        im.alpha_composite(steam(i))
        frames.append(im)
    return frames


# -------------------------------------------------------------------- sheet

KEYS = {'dirs': '1', 'frames': '1'}
STEAM_KEYS = {'dirs': '1', 'frames': str(STEAM_FRAMES),
              'delay': ','.join([STEAM_DELAY] * STEAM_FRAMES)}


def build():
    """[(state, keys, images)]."""
    return [('quench_tub', dict(KEYS), [tub().image()]),
            ('quench_tub_full', dict(KEYS), [tub(True).image()]),
            ('quench_tub_steam', dict(STEAM_KEYS), steam_frames())]


def solid(im):
    return set((i % SIZE, i // SIZE) for i, p in enumerate(pixels(im)) if p[3] == 255)


def check_drawing(states):
    """Rules the drawing itself must keep, whatever the palettes become."""
    problems = []
    by_name = dict((name, images) for name, _, images in states)
    dry, wet = by_name['quench_tub'][0], by_name['quench_tub_full'][0]
    water = set(c + (255,) for c in WATER)
    if solid(dry) != solid(wet):
        problems.append('quench_tub_full is not the same outline as quench_tub')
    if set(pixels(dry)) & water:
        problems.append('quench_tub shows water')
    if not set(pixels(wet)) & water:
        problems.append('quench_tub_full shows no water')
    for im in (dry, wet):
        if any(p[3] not in (0, 255) for p in pixels(im)):
            problems.append('a still tub has a half-clear pixel')
        xs = [x for x, _ in solid(im)]
        if min(xs) < 1 or max(xs) > SIZE - 2 or max(y for _, y in solid(im)) > SIZE - 2:
            problems.append('the tub does not keep 1px clear left, right and below')
    frames = by_name['quench_tub_steam']
    if len(frames) != STEAM_FRAMES or len(set(im.tobytes() for im in frames)) != STEAM_FRAMES:
        problems.append('quench_tub_steam does not have %d different frames' % STEAM_FRAMES)
    rim_row = int(MOUTH[0] - MOUTH[2])
    wet_px = pixels(wet)
    for n, im in enumerate(frames):
        px = pixels(im)
        # below the far lip only steam may differ from the full tub, and the
        # outside wall (below the front lip) may not differ at all
        for i, (a, b) in enumerate(zip(px, wet_px)):
            if a != b and i // SIZE > MOUTH[0] + 1:
                problems.append('steam frame %d changes the tub wall' % n)
                break
        if not any(p[3] and p[:3] == STEAM[0][:3] for p in px[:rim_row * SIZE]):
            problems.append('steam frame %d shows no steam above the rim' % n)
    return problems


def check_sheet(states):
    """The committed sheet is exactly what build() draws."""
    if not SHEET.exists():
        return ['%s is missing' % SHEET]
    have = read_dmi(SHEET)
    if [name for name, _, _ in have] != [name for name, _, _ in states]:
        return ['state list differs: %s' % ', '.join(name for name, _, _ in have)]
    problems = []
    for (name, keys, images), (_, want_keys, want_images) in zip(have, states):
        if keys != want_keys:
            problems.append('%s has keys %r, expected %r' % (name, keys, want_keys))
        elif any(pixels(a) != pixels(b) for a, b in zip(images, want_images)):
            problems.append('%s is not what this script draws' % name)
    return problems


# ------------------------------------------------------------------- review

def write_preview(path, states, scale=4):
    """Every state and frame on grass and on a wooden floor at 4x, then the
    same at 1x."""
    floors = dict((name, images[0]) for name, _, images in read_dmi(FLOORS))
    grounds = (('grass', floors['grass0']), ('wood floor', floors['wood']))
    shown = []
    for name, _, images in states:
        for i, im in enumerate(images):
            shown.append((name if len(images) == 1 else 'steam %d' % (i + 1), im))
    gap, top, left = 10, 16, 10
    cell = SIZE * scale
    sheet = Image.new('RGB', (left + len(shown) * (cell + gap),
                              gap + 2 * (cell + top + gap) + SIZE + top + gap), (32, 32, 36))
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
    draw.text((left, y), '1x', fill=(230, 230, 230))
    x = left
    for label, ground in grounds:
        for name, im in shown:
            sheet.paste(tile(ground, im, 1), (x, y + top))
            x += SIZE + 4
        x += gap
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


def option(name):
    args = sys.argv[1:]
    return args[args.index(name) + 1] if name in args[:-1] else None


def main():
    states = build()
    problems = check_drawing(states)
    if '--check' in sys.argv:
        problems += check_sheet(states)
        for line in problems:
            print(line)
        print('quench tub: %s' % ('FAILED' if problems else 'ok'))
        return 1 if problems else 0
    if problems:
        print('\n'.join(problems))
        return 1
    write_dmi(SHEET, states)
    if option('--preview'):
        write_preview(option('--preview'), states)
    return 0


if __name__ == '__main__':
    sys.exit(main())
