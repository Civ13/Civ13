#!/usr/bin/env python3
"""Draw the wall braces in icons/obj/buttresses.dmi.

Four 32x32 states, each with four directions (DMI order SOUTH, NORTH, EAST,
WEST). A brace's dir points FROM the brace TOWARD the wall it supports, so the
masonry always touches the tile edge on that side:

  buttress         stepped stone buttress, three stages with weathered set-offs
  flying_buttress  free-standing pier with a pinnacle and the springing of a
                   half-arch that leaves the tile toward the wall
  corbel_stone     small stepped stone bracket high on the wall
  corbel_wood      carved timber bracket with a diagonal brace

The greys follow support_st1 / concrete_pillar in icons/obj/structures.dmi.
Everything is lit from the top left, has a one pixel darker outline and a soft
ground shadow falling to the lower right. The drawing is plain pixel work with
Pillow; nothing is random, so a rerun writes the same bytes.

  python3 tests/sprites/create_buttresses.py                  write the sheet
  python3 tests/sprites/create_buttresses.py --check          verify the committed sheet
  python3 tests/sprites/create_buttresses.py --preview <png>  also write a 4x review sheet
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_water_animation import SIZE, write_dmi  # noqa: E402
from create_bollards import DIRT, WOOD, noise, option  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/buttresses.dmi'
STATES = ('buttress', 'flying_buttress', 'corbel_stone', 'corbel_wood')
DIRS = ('SOUTH', 'NORTH', 'EAST', 'WEST')  # DMI order for dirs = 4
EDGE = SIZE - 1

# outline first, then the support_st1 greys from shade to highlight
STONE = [(54, 54, 54), (74, 74, 74), (94, 94, 94), (114, 114, 114), (126, 126, 126), (138, 138, 138),
         (146, 146, 146)]


def mirror(tones):
    return {(EDGE - x, y): v for (x, y), v in tones.items()}


def fill(tones, x0, x1, y0, y1, ramp, tone):
    """Inclusive rectangle; tone is a number or f(x, y)."""
    for y in range(max(0, y0), min(EDGE, y1) + 1):
        for x in range(max(0, x0), min(EDGE, x1) + 1):
            tones[x, y] = (ramp, tone(x, y) if callable(tone) else tone)


def joint(x, y, bw=6, bh=4):
    """True on the mortar lines of a running bond."""
    return y % bh == 0 or (x + (y // bh % 2) * (bw // 2)) % bw == 0


def ashlar(seed, x0, x1, lit_left=True):
    """Tone for a dressed-stone face spanning columns x0..x1."""
    def tone(x, y):
        if joint(x, y):
            return 2
        t = 3
        if x <= x0 + 1:
            t = 4 if lit_left else 3
        elif x >= x1 - 1:
            t = 2
        elif y % 4 == 1:
            t = 4  # upper arris of each block catches the light
        if noise(x, y, seed) < 0.12:
            t -= 1
        return max(t, 1)
    return tone


def render(tones, wall, drop=(2, 2), strength=80):
    """Soft shadow to the lower right, body, then a one pixel darker rim.

    The rim is skipped along the wall-side tile edge so the masonry runs on
    into the wall instead of ending in a line.
    """
    im = Image.new('RGBA', (SIZE, SIZE))
    px = im.load()

    def inside(x, y):
        if (x, y) in tones:
            return True
        return {'NORTH': y < 0, 'SOUTH': y > EDGE, 'EAST': x > EDGE, 'WEST': x < 0}[wall]

    for step, alpha in ((1, strength // 2), (0, strength)):
        for x, y in tones:
            sx, sy = x + drop[0] + step, y + drop[1] + step
            if 0 <= sx < SIZE and 0 <= sy < SIZE and (sx, sy) not in tones:
                px[sx, sy] = (0, 0, 0, max(alpha, px[sx, sy][3]) if step == 0 else alpha)
    for (x, y), (ramp, tone) in tones.items():
        rim = any(not inside(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if rim:
            lit = not inside(x - 1, y) or not inside(x, y - 1)
            dark = ramp[0]
            if lit and inside(x + 1, y) and inside(x, y + 1):
                dark = tuple((a + b) // 2 for a, b in zip(ramp[0], ramp[1]))
            px[x, y] = dark + (255,)
        else:
            px[x, y] = ramp[max(1, min(len(ramp) - 1, tone))] + (255,)
    return im


# --- buttress -------------------------------------------------------------

def buttress_north():
    """Seen from the front: three faces, each lower stage standing further out."""
    t = {}
    for (y0, y1, x0, x1) in ((0, 7, 8, 23), (11, 17, 6, 25), (21, 28, 4, 27)):
        fill(t, x0, x1, y0, y1, STONE, ashlar(5, x0, x1))
    for (y0, x0, x1) in ((8, 6, 25), (18, 4, 27)):  # weathered set-offs
        fill(t, x0, x1, y0, y0, STONE, 6)
        fill(t, x0, x1, y0 + 1, y0 + 1, STONE, lambda x, y: 5 if noise(x, y, 6) > 0.2 else 4)
        fill(t, x0, x1, y0 + 2, y0 + 2, STONE, 4)
    fill(t, 3, 28, 29, 29, STONE, 2)  # plinth
    return t


def buttress_south():
    """Seen from behind and above: only the sloping tops, rising toward the wall."""
    t = {}
    for n, (y0, y1, x0, x1) in enumerate(((5, 13, 4, 27), (13, 22, 6, 25), (22, 31, 8, 23))):
        def tone(x, y, y0=y0, x0=x0, x1=x1, n=n):
            if y == y0:
                return 2 if n else 5  # crease where the next stage rises
            if y == y0 + 1:
                return 6
            v = 5 if x <= x0 + 2 else 3 if x >= x1 - 1 else 4
            if joint(x, y, 8, 4):
                v -= 1
            elif noise(x, y, 7) < 0.1:
                v -= 1
            return v
        fill(t, x0, x1, y0, y1, STONE, tone)
    return t


def buttress_east(lit=True):
    """Side on: the stepped profile, wall at the right edge."""
    t = {}
    for (x0, x1, top) in ((4, 12, 19), (13, 21, 11), (22, 31, 3)):
        for x in range(x0, x1 + 1):
            y0 = top - (x - x0) // 4  # weathering slope of the set-off
            face = ashlar(8, 4, 99, lit)
            for y in range(y0, 29):
                if y <= y0 + 1:
                    v = 6 if y == y0 else 5  # top of the stage, seen from above
                elif y == y0 + 2:
                    v = 4
                elif x == x0 and y < (28 if x0 == 4 else top + 8):
                    v = 4 if lit else 2  # riser facing away from the wall
                else:
                    v = face(x, y)
                t[x, y] = (STONE, v)
    fill(t, 3, 31, 29, 29, STONE, 2)
    return t


# --- flying buttress ------------------------------------------------------

def pier(t):
    def face(x, y):
        v = 4 if x <= 11 else 3 if x <= 17 else 2
        if joint(x, y - 2, 6, 4):
            v -= 1
        elif noise(x, y, 9) < 0.1:
            v -= 1
        return max(v, 1)
    fill(t, 10, 21, 14, 27, STONE, face)
    fill(t, 9, 22, 28, 29, STONE, lambda x, y: 3 if y == 28 and x < 18 else 2)
    fill(t, 9, 22, 12, 12, STONE, 6)  # cap moulding
    fill(t, 9, 22, 13, 13, STONE, 2)
    for y in range(4, 12):  # pinnacle
        half = int((y - 3) * 0.75)
        for x in range(16 - half, 16 + half):
            t[x, y] = (STONE, 6 if x < 15 else 5 if x == 15 else 3 if (x + y) % 5 else 2)
    return t


def flying_north():
    t = {}
    # top of the arch running away behind the pinnacle to the far edge
    fill(t, 13, 18, 0, 12, STONE, lambda x, y: 3 if x == 18 else 4 if y % 3 == 2 else 6 if x == 13 else 5)
    return pier(t)


def flying_south():
    t = pier({})
    # the arch comes forward over the pier: its soffit, in shade
    fill(t, 13, 18, 15, 31, STONE,
         lambda x, y: 5 if x == 13 else 1 if x == 18 else 1 if y == 15 else 2 if y % 3 == 0 else 3)
    return t


def flying_east():
    t = {}
    for x in range(22, SIZE):
        top = 13 - int(round(10 * math.sin((x - 21) / 10.0 * math.pi / 2)))
        for n in range(7):
            v = (6, 6, 5, 4, 3, 3, 2)[n]
            if n >= 3 and x % 3 == 0:
                v = 2 if n < 6 else 1  # voussoir joints
            t[x, top + n] = (STONE, v)
    return pier(t)


# --- corbels ----------------------------------------------------------------

def corbel_stone_north():
    t = {}
    fill(t, 10, 21, 0, 2, STONE, lambda x, y: 6 if x < 19 else 5)
    fill(t, 10, 21, 3, 5, STONE, lambda x, y: 2 if y == 3 and x % 4 == 1 else 4 if x < 13 else 3)
    fill(t, 11, 20, 6, 8, STONE, lambda x, y: 2 if y == 6 else 3)
    fill(t, 13, 18, 9, 10, STONE, lambda x, y: 1 if y == 9 else 2)
    return t


def corbel_stone_south():
    t = {}
    fill(t, 12, 19, 21, 22, STONE, 4)
    fill(t, 10, 21, 23, 31, STONE,
         lambda x, y: 3 if y == 26 else 4 if x >= 20 else 6 if x <= 11 or y == 23 else 5)
    return t


def corbel_stone_east(lit=True):
    t = {}
    nose = 4 if lit else 2
    fill(t, 22, 31, 8, 9, STONE, lambda x, y: 6 if y == 8 else 5)
    for (x0, y0, y1) in ((22, 10, 13), (25, 14, 16), (28, 17, 19)):
        fill(t, x0, 31, y0, y1, STONE,
             lambda x, y, x0=x0, y0=y0, y1=y1: nose if x == x0 else 2 if y == y1 else 4 if y == y0 else 3)
    fill(t, 23, 30, 11, 11, STONE, 2)  # carved groove along the top course
    return t


def corbel_wood_north():
    t = {}
    fill(t, 12, 19, 0, 2, WOOD, lambda x, y: 4 if x in (14, 17) else 5)
    fill(t, 12, 19, 3, 7, WOOD,
         lambda x, y: 2 if (x in (14, 17) and 4 <= y <= 6) or (y in (4, 6) and 14 <= x <= 17) else 4)
    fill(t, 13, 18, 8, 9, WOOD, lambda x, y: 1 if y == 8 else 2)  # the brace, end on
    fill(t, 14, 17, 10, 11, WOOD, 2)
    return t


def corbel_wood_south():
    t = {}
    fill(t, 13, 18, 21, 21, WOOD, 4)
    fill(t, 12, 19, 22, 31, WOOD, lambda x, y: 3 if x in (14, 17) and y % 5 else 4 if x == 19 else 5)
    fill(t, 10, 21, 29, 31, WOOD, lambda x, y: 4 if y == 29 else 3)  # wall plate
    return t


def corbel_wood_east(lit=True):
    t = {}
    near, far = (4, 2) if lit else (2, 4)
    fill(t, 21, 31, 9, 10, WOOD, lambda x, y: 5 if y == 9 or x % 4 else 4)
    fill(t, 21, 31, 11, 14, WOOD, lambda x, y: 4 if y == 12 else 2 if y == 14 else 3)
    del t[21, 14]  # chamfered nose
    fill(t, 28, 31, 15, 23, WOOD, lambda x, y: near if x == 28 else 3)
    for n in range(7):  # diagonal brace from under the nose back to the wall post
        for k, v in enumerate((near, 3, far)):
            if 22 + n + k <= 28:
                t[22 + n + k, 15 + n] = (WOOD, v)
    return t


def four(south, north, east, west, **kw):
    return [render(south, 'SOUTH', **kw), render(north, 'NORTH', **kw), render(east, 'EAST', **kw),
            render(west, 'WEST', **kw)]


def build():
    high = {'drop': (3, 5), 'strength': 48}  # brackets hang overhead: fainter, further shadow
    drawn = (
        four(buttress_south(), buttress_north(), buttress_east(), mirror(buttress_east(False))),
        four(flying_south(), flying_north(), flying_east(), mirror(flying_east())),
        four(corbel_stone_south(), corbel_stone_north(), corbel_stone_east(),
             mirror(corbel_stone_east(False)), **high),
        four(corbel_wood_south(), corbel_wood_north(), corbel_wood_east(),
             mirror(corbel_wood_east(False)), **high),
    )
    return [(name, {'dirs': '4', 'frames': '1'}, ims) for name, ims in zip(STATES, drawn)]


def solid_box(im):
    return im.getchannel('A').point(lambda v: 255 if v == 255 else 0).getbbox()


def check_drawing(states):
    problems = []
    for name, _, ims in states:
        if len(ims) != 4 or len({im.tobytes() for im in ims}) != 4:
            problems.append('%s: needs four different directions' % name)
        for d, im in zip(DIRS, ims):
            x0, y0, x1, y1 = solid_box(im)
            touch = {'SOUTH': y1 == SIZE, 'NORTH': y0 == 0, 'EAST': x1 == SIZE, 'WEST': x0 == 0}
            if not touch[d]:
                problems.append('%s %s: does not reach the wall-side edge' % (name, d))
            if sum(touch.values()) != 1:
                problems.append('%s %s: touches another tile edge' % (name, d))
            used = sum(1 for a in im.getchannel('A').tobytes() if a == 255)
            reach = (y1 - y0) if d in ('SOUTH', 'NORTH') else (x1 - x0)
            if name.startswith('corbel'):
                if not 9 <= reach <= 12 or used > SIZE * SIZE // 6:
                    problems.append('%s %s: reach %d, %d pixels' % (name, d, reach, used))
            elif name == 'buttress':
                across = (x1 - x0) if d in ('SOUTH', 'NORTH') else reach
                if across < 22 or used < SIZE * SIZE * 3 // 10:
                    problems.append('%s %s: too slight (%d across, %d pixels)' % (name, d, across, used))
            else:
                column = [y for y in range(SIZE) if all(im.getpixel((x, y))[3] == 255 for x in range(10, 22))]
                if len(column) < 14 or y0 > 6:
                    problems.append('%s %s: pier is not 12 wide and tall' % (name, d))
    return problems


def check_sheet(path, states):
    path = Path(path)
    if not path.exists():
        return ['%s is missing' % path]
    sheet = Image.open(path)
    text = sheet.info.get('Description', '')
    lines = [line.strip() for line in text.splitlines()]
    names = [line.split('"')[1] for line in lines if line.startswith('state = ')]
    problems = []
    if names != list(STATES):
        problems.append('%s lists %s' % (path.name, names))
    if [line for line in lines if line.startswith('dirs')] != ['dirs = 4'] * len(STATES):
        problems.append('%s: every state needs dirs = 4' % path.name)
    if 'width = %d' % SIZE not in lines or 'height = %d' % SIZE not in lines:
        problems.append('%s: not a %dx%d sheet' % (path.name, SIZE, SIZE))
    sheet = sheet.convert('RGBA')
    cols = sheet.width // SIZE
    n = 0
    for name, _, ims in states:
        for d, im in zip(DIRS, ims):
            box = ((n % cols) * SIZE, (n // cols) * SIZE, (n % cols + 1) * SIZE, (n // cols + 1) * SIZE)
            if sheet.crop(box).tobytes() != im.tobytes():
                problems.append('%s %s: committed pixels differ from the drawing' % (name, d))
            n += 1
    return problems


def wall_tile():
    im = Image.new('RGBA', (SIZE, SIZE))
    px = im.load()
    for y in range(SIZE):
        for x in range(SIZE):
            v = 1 if joint(x, y, 8, 8) else 3 if noise(x, y, 31) > 0.15 else 2
            px[x, y] = STONE[v] + (255,)
    return im


def write_preview(path, states, scale=4):
    """Rows are states, columns are dirs; each cell is 3x3 tiles with the wall drawn beside the brace."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    cell = SIZE * 3
    sheet = Image.new('RGBA', (cell * 4, cell * len(states)), DIRT + (255,))
    px = sheet.load()
    for y in range(sheet.height):
        for x in range(sheet.width):
            n = noise(x, y, 40)
            shift = -9 if n < 0.14 else 7 if n > 0.9 else 0
            px[x, y] = tuple(c + shift for c in DIRT) + (255,)
    wall = wall_tile()
    side = {'SOUTH': (0, 1), 'NORTH': (0, -1), 'EAST': (1, 0), 'WEST': (-1, 0)}
    for row, (_, _, ims) in enumerate(states):
        for col, (d, im) in enumerate(zip(DIRS, ims)):
            ox, oy = col * cell + SIZE, row * cell + SIZE
            dx, dy = side[d]
            for k in (-1, 0, 1):  # a three tile run of wall on the braced side
                sheet.alpha_composite(wall, (ox + dx * SIZE + k * SIZE * abs(dy), oy + dy * SIZE + k * SIZE * abs(dx)))
            sheet.alpha_composite(im, (ox, oy))
    big = sheet.convert('RGB').resize((sheet.width * scale, sheet.height * scale), Image.NEAREST)
    draw = ImageDraw.Draw(big)
    for row, (name, _, _) in enumerate(states):
        for col, d in enumerate(DIRS):
            x, y = col * cell * scale, row * cell * scale
            draw.rectangle((x, y, x + cell * scale - 1, y + cell * scale - 1), outline=(40, 28, 18))
            label = '%s  dir %s' % (name, d)
            draw.rectangle((x + 4, y + 4, x + 10 + 6 * len(label), y + 18), fill=(30, 22, 14))
            draw.text((x + 7, y + 5), label, fill=(240, 232, 214))
    big.save(path)


def main():
    states = build()
    problems = check_drawing(states)
    if '--check' in sys.argv:
        problems += check_sheet(option('--sheet') or SHEET, states)
        for line in problems:
            print(line)
        print('buttresses: %s' % ('FAILED' if problems else 'ok'))
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
