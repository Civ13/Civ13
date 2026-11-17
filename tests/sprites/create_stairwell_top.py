#!/usr/bin/env python3
"""Draw the stairwell top marker in icons/obj/stairwell_top.dmi.

Two four-direction 32x32 states (DMI order SOUTH, NORTH, EAST, WEST):

  stairwell_top        wooden, in the colours of wood2_stairs in stairs.dmi
  stairwell_top_stone  the same shapes in grey stone

The marker lies on the open-air tile above a staircase, so a player on the
upper floor can tell the safe stair top from a plain drop. Its dir is the
direction the stairs climb: the side of the tile where the top step meets the
upper floor landing. For dir NORTH the landing is the tile to the north and a
player walks SOUTH from it onto this tile to go down.

Each direction shows:

  - a top-step nosing board, 6px deep, along the landing side, with a soft
    shadow under its inner edge where it overhangs the flight below
  - a handrail down each of the two sides, with two square posts apiece
  - two pale chevrons in the middle pointing away from the landing, down the
    stairs

Everything else stays transparent so the dimmed stairs below show through.
Every solid shape has a one pixel dark outline, so it reads on the dark blue
view of the level below as well as on daylight wood or grass. The shapes are
laid out once for NORTH and turned for the other directions; the light is
applied afterwards, so it comes from the top left in all four. Plain pixel work
with Pillow; nothing is random, so a rerun writes the same bytes.

  python3 tests/sprites/create_stairwell_top.py                  write the sheet
  python3 tests/sprites/create_stairwell_top.py --check          verify the committed sheet
  python3 tests/sprites/create_stairwell_top.py --preview <png>  also write a 4x review sheet
"""
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_water_animation import SIZE, write_dmi  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/stairwell_top.dmi'
STAIRS = ROOT / 'icons/obj/stairs.dmi'
FLOOR = ROOT / 'icons/turf/flooring/wood.dmi'
DIRS = ('SOUTH', 'NORTH', 'EAST', 'WEST')

# roles of a pixel in the layout
EMPTY, OUTLINE, BODY, CAP, CHEVRON, SHADE_NEAR, SHADE_FAR = range(7)
SOLID = (OUTLINE, BODY, CAP, CHEVRON)
SHADOW_ALPHA = {SHADE_NEAR: 96, SHADE_FAR: 48}

# outline, then body shaded / grain / base / lit, then post cap, then chevron lit / shaded
PALETTES = {
    'stairwell_top': {
        'outline': (44, 27, 19),
        'body': [(102, 67, 47), (123, 75, 47), (148, 97, 73), (186, 128, 94)],
        'cap': (204, 148, 108),
        'chevron': [(246, 226, 170), (214, 184, 122)],
    },
    'stairwell_top_stone': {
        'outline': (38, 38, 42),
        'body': [(96, 96, 100), (118, 118, 120), (142, 142, 144), (178, 178, 178)],
        'cap': (200, 200, 198),
        'chevron': [(240, 240, 228), (198, 198, 186)],
    },
}

NOSING = 6           # rows 0-5: outline, four of board, outline
RAIL = 4             # columns 0-3 and 28-31: outline, two of rail, outline
POST = 5             # posts are one pixel wider than the rail
POST_ROWS = (10, 24)
CHEVRON_ROWS = (11, 19)


def noise(x, y, seed):
    n = (x * 73856093) ^ (y * 19349663) ^ (seed * 83492791)
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def box(grid, x0, y0, x1, y1, fill):
    """An outlined rectangle, corners included."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            rim = x in (x0, x1) or y in (y0, y1)
            grid[y][x] = OUTLINE if rim else fill


def layout_north():
    """The role of every pixel with the landing along the top of the tile."""
    grid = [[EMPTY] * SIZE for _ in range(SIZE)]
    # shadow the nosing casts onto the flight below
    for x in range(RAIL, SIZE - RAIL):
        grid[NOSING][x] = SHADE_NEAR
        grid[NOSING + 1][x] = SHADE_FAR
    # handrails down both sides, closed at the foot
    box(grid, 0, NOSING - 1, RAIL - 1, SIZE - 1, BODY)
    box(grid, SIZE - RAIL, NOSING - 1, SIZE - 1, SIZE - 1, BODY)
    for y in POST_ROWS:
        box(grid, 0, y, POST - 1, y + POST - 1, CAP)
        box(grid, SIZE - POST, y, SIZE - 1, y + POST - 1, CAP)
    # top-step nosing board across the landing side
    box(grid, 0, 0, SIZE - 1, NOSING - 1, BODY)
    # chevrons, tips toward the bottom of the tile
    marks = set()
    for y0 in CHEVRON_ROWS:
        for i in range(5):
            for thick in (0, 1):
                marks.add((15 - i, y0 + 4 - i + thick))
                marks.add((16 + i, y0 + 4 - i + thick))
    for x, y in marks:
        grid[y][x] = CHEVRON
    for x, y in marks:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if grid[y + dy][x + dx] == EMPTY:
                grid[y + dy][x + dx] = OUTLINE
    return grid


def turn(grid, name):
    """The NORTH layout turned so the landing side faces the named direction."""
    if name == 'NORTH':
        return [row[:] for row in grid]
    if name == 'SOUTH':
        return [row[::-1] for row in grid[::-1]]
    if name == 'EAST':  # a quarter turn clockwise
        return [[grid[SIZE - 1 - x][y] for x in range(SIZE)] for y in range(SIZE)]
    return [[grid[x][SIZE - 1 - y] for x in range(SIZE)] for y in range(SIZE)]  # WEST


def role(grid, x, y):
    return grid[y][x] if 0 <= x < SIZE and 0 <= y < SIZE else OUTLINE


def paint(grid, palette, seed):
    """Colour a layout with the light from the top left."""
    im = Image.new('RGBA', (SIZE, SIZE))
    px = im.load()
    for y in range(SIZE):
        for x in range(SIZE):
            r = grid[y][x]
            if r == EMPTY:
                continue
            if r in SHADOW_ALPHA:
                px[x, y] = (0, 0, 0, SHADOW_ALPHA[r])
                continue
            lit = role(grid, x, y - 1) != r or role(grid, x - 1, y) != r
            dark = role(grid, x, y + 1) != r or role(grid, x + 1, y) != r
            if r == OUTLINE:
                tone = palette['outline']
            elif r == CHEVRON:
                tone = palette['chevron'][0 if lit else 1]
            elif r == CAP:
                tone = palette['cap'] if not dark or lit else palette['body'][2]
            elif lit:
                tone = palette['body'][3]
            elif dark:
                tone = palette['body'][0]
            else:
                tone = palette['body'][1 if noise(x, y, seed) < 0.3 else 2]
            px[x, y] = tone + (255,)
    return im


def build():
    north = layout_north()
    states = []
    for seed, (name, palette) in enumerate(PALETTES.items()):
        frames = [paint(turn(north, d), palette, 11 + seed) for d in DIRS]
        states.append((name, {'dirs': '4', 'frames': '1'}, frames))
    return states


def landing_side(im):
    """Which tile edge is solid from corner to corner."""
    a = im.getchannel('A').load()
    deep = NOSING - 1  # the board's inner outline, deeper than a rail or post is wide
    full = {
        'NORTH': all(a[x, 0] == 255 and a[x, deep] == 255 for x in range(SIZE)),
        'SOUTH': all(a[x, SIZE - 1] == 255 and a[x, SIZE - 1 - deep] == 255 for x in range(SIZE)),
        'WEST': all(a[0, y] == 255 and a[deep, y] == 255 for y in range(SIZE)),
        'EAST': all(a[SIZE - 1, y] == 255 and a[SIZE - 1 - deep, y] == 255 for y in range(SIZE)),
    }
    return [d for d in DIRS if full[d]]


def check_drawing(states):
    problems = []
    for name, _, frames in states:
        palette = PALETTES[name]
        allowed = {palette['outline'], palette['cap']} | set(palette['body']) | set(palette['chevron'])
        if len(frames) != len(DIRS):
            problems.append('%s: %d frames' % (name, len(frames)))
        for d, im in zip(DIRS, frames):
            px = im.load()
            cells = [px[x, y] for y in range(SIZE) for x in range(SIZE)]
            if landing_side(im) != [d]:
                problems.append('%s %s: nosing is on %s' % (name, d, landing_side(im)))
            if any(c[3] == 255 and c[:3] not in allowed for c in cells):
                problems.append('%s %s: colour outside the palette' % (name, d))
            if any(0 < c[3] < 255 and (c[:3] != (0, 0, 0) or c[3] not in SHADOW_ALPHA.values()) for c in cells):
                problems.append('%s %s: half transparent pixel is not the shadow' % (name, d))
            clear = sum(c[3] < 255 for c in cells)
            if clear * 2 < SIZE * SIZE:
                problems.append('%s %s: only %d see-through pixels' % (name, d, clear))
            middle = [px[x, y] for y in range(6, 26) for x in range(6, 26)]
            marks = sum(c[:3] in palette['chevron'] and c[3] == 255 for c in middle)
            if marks != 40:
                problems.append('%s %s: %d chevron pixels in the middle' % (name, d, marks))
            if any(c[3] == 255 and c[:3] in palette['body'] for c in middle):
                problems.append('%s %s: woodwork in the middle of the tile' % (name, d))
    return problems


def read_dmi(path):
    """Every state of a DMI as (name, dirs, frames, [images])."""
    sheet = Image.open(path)
    text = sheet.info.get('Description', '')
    sheet = sheet.convert('RGBA')
    width = height = SIZE
    found = []
    for line in text.splitlines():
        key, _, value = line.strip().partition(' = ')
        if key == 'width':
            width = int(value)
        elif key == 'height':
            height = int(value)
        elif key == 'state':
            found.append([value.strip('"'), 1, 1])
        elif key == 'dirs' and found:
            found[-1][1] = int(value)
        elif key == 'frames' and found:
            found[-1][2] = int(value)
    cols = sheet.width // width
    states, i = [], 0
    for name, dirs, frames in found:
        images = []
        for n in range(i, i + dirs * frames):
            x, y = (n % cols) * width, (n // cols) * height
            images.append(sheet.crop((x, y, x + width, y + height)))
        i += dirs * frames
        states.append((name, dirs, frames, images))
    return states


def check_sheet(path, states):
    path = Path(path)
    if not path.exists():
        return ['%s is missing' % path]
    problems = []
    found = read_dmi(path)
    if [(n, d, f) for n, d, f, _ in found] != [(n, 4, 1) for n, _, _ in states]:
        problems.append('%s lists %s' % (path.name, [(n, d, f) for n, d, f, _ in found]))
        return problems
    for (name, _, frames), (_, _, _, images) in zip(states, found):
        for d, want, got in zip(DIRS, frames, images):
            if want.tobytes() != got.tobytes():
                problems.append('%s %s: committed pixels differ from the drawing' % (name, d))
    return problems


def dimmed(im):
    """The level below as seen through open air: about 60% brightness, a little blue."""
    out = Image.new('RGBA', im.size)
    src, dst = im.load(), out.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = src[x, y]
            dst[x, y] = (int(r * 0.6 * 0.90), int(g * 0.6 * 0.96), min(255, int(b * 0.6 * 1.06) + 10), a)
    return out


def write_preview(path, states, scale=4):
    """Rows per state: over the dimmed stairs, over a wooden floor, and in a
    3x3 floor with the stairwell in the middle. Columns are SOUTH, NORTH,
    EAST, WEST, then a 1x strip. A last row shows the bare dimmed stairs."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    stairs = {n: ims for n, _, _, ims in read_dmi(STAIRS)}['wood2_stairs'][:4]
    below = [dimmed(s) for s in stairs]
    floor = {n: ims for n, _, _, ims in read_dmi(FLOOR)}['wood'][0]
    grass = Image.new('RGBA', (SIZE, SIZE))
    gp = grass.load()
    for y in range(SIZE):
        for x in range(SIZE):
            v = noise(x, y, 5)
            shift = -14 if v < 0.2 else 12 if v > 0.85 else 0
            gp[x, y] = (72 + shift, 122 + shift, 52 + shift // 2, 255)

    def over(base, top=None):
        out = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 255))
        out.alpha_composite(base)
        if top is not None:
            out.alpha_composite(top)
        return out

    def scene(n, top, ground):
        out = Image.new('RGBA', (SIZE * 3, SIZE * 3))
        for ty in range(3):
            for tx in range(3):
                out.paste(ground, (tx * SIZE, ty * SIZE))
        out.paste(over(below[n], top), (SIZE, SIZE))
        return out

    gap = 6
    cell = SIZE * scale
    big = SIZE * 3 * 2  # scenes at 2x
    rows = []
    for name, _, frames in states:
        rows.append((cell, [over(below[n], f) for n, f in enumerate(frames)], scale))
        rows.append((cell, [over(floor, f) for f in frames] + [over(grass, f) for f in frames[:2]], scale))
        rows.append((big, [scene(n, f, floor) for n, f in enumerate(frames)], 2))
    rows.append((big, [scene(n, f, grass) for n, f in enumerate(states[0][2])], 2))
    rows.append((big, [scene(n, None, floor) for n in range(4)], 2))  # before: no marker
    width = max(sum(im.width * s + gap for im in ims) for _, ims, s in rows) + gap + SIZE + gap
    height = sum(h + gap for h, _, _ in rows) + gap
    sheet = Image.new('RGB', (width, height), (32, 32, 32))
    y = gap
    for h, ims, s in rows:
        x = gap
        for im in ims:
            sheet.paste(im.resize((im.width * s, im.height * s), Image.NEAREST).convert('RGB'), (x, y))
            x += im.width * s + gap
        y += h + gap
    # 1x strip down the right edge: both states over the dimmed stairs
    y = gap
    for _, _, frames in states:
        for n, f in enumerate(frames):
            sheet.paste(over(below[n], f).convert('RGB'), (width - SIZE - gap, y))
            y += SIZE + gap
    sheet.save(path)


def option(name):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else None


def main():
    states = build()
    problems = check_drawing(states)
    if '--check' in sys.argv:
        problems += check_sheet(option('--sheet') or SHEET, states)
        for line in problems:
            print(line)
        print('stairwell top: %s' % ('FAILED' if problems else 'ok'))
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
