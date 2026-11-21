#!/usr/bin/env python3
"""Draw the ramp sections in icons/obj/ramps.dmi.

Four four-direction 32x32 states (DMI order SOUTH, NORTH, EAST, WEST):

  earth_ramp     packed earth between rows of set stones
  timber_ramp    planks laid across the slope, two cleats per section, edge beams
  stone_ramp     dressed flagstones in running bond between long kerb stones
  concrete_ramp  smooth concrete with ribbed grooves, a kerb and a yellow line

A ramp is several identical sections laid in a straight line. Each section
covers its whole tile and is drawn at floor level, like the stairs in
icons/obj/stairs.dmi. The dir of a section is the direction the ramp climbs:
dir NORTH rises toward the top of the screen.

Each section is laid out once for NORTH as three grids: a base colour, a
height and a position along the slope. The grids are turned for the other
directions and only then painted, so the light comes from the top left in all
four. The colour is brightened toward the high end of the section, which is
what makes the slope read; where two sections meet, the bright high end of one
sits against the darker low end of the next, like the joint between two built
sections. Every pattern across the slope repeats in 32 pixels and the kerbs run
unbroken, so sections laid end to end line up.

Plain pixel work with Pillow; nothing is random, so a rerun writes the same
bytes.

  python3 tests/sprites/create_ramps.py                  write the sheet
  python3 tests/sprites/create_ramps.py --check          verify the committed sheet
  python3 tests/sprites/create_ramps.py --preview <png>  also write a 4x review sheet
"""
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_water_animation import SIZE, write_dmi  # noqa: E402
from create_stairwell_top import read_dmi  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/ramps.dmi'
DIRS = ('SOUTH', 'NORTH', 'EAST', 'WEST')
STATES = ('earth_ramp', 'timber_ramp', 'stone_ramp', 'concrete_ramp')

HIGH, LOW = 1.13, 0.87   # brightness at the high and the low end of a section
RELIEF = 0.11            # brightness per unit of height facing the light


def noise(x, y, seed):
    n = (x * 73856093) ^ (y * 19349663) ^ (seed * 83492791)
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def shade(colour, by):
    return tuple(max(0, min(255, int(round(c * by)))) for c in colour)


def blank():
    """Colour and height grids for one section, indexed [y][x], NORTH layout."""
    return ([[(0, 0, 0)] * SIZE for _ in range(SIZE)],
            [[0.0] * SIZE for _ in range(SIZE)])


def mirror(x):
    """Distance in from the nearer long side, and which side it is."""
    return (x, 0) if x < SIZE // 2 else (SIZE - 1 - x, 1)


def earth():
    col, hgt = blank()
    soil = (126, 96, 64)
    # set stones down each side: (first row, last row, width) per stone, wrapping at 32
    stones = (((0, 5, 5), (7, 12, 4), (14, 20, 5), (22, 25, 4), (27, 30, 5)),
              ((1, 6, 4), (8, 14, 5), (16, 19, 4), (21, 27, 5), (29, 31, 4)))
    greys = ((150, 146, 138), (136, 133, 128), (160, 154, 142), (128, 127, 124))
    for y in range(SIZE):
        for x in range(SIZE):
            v = noise(x, y, 3)
            tone = 0.90 if v < 0.16 else 1.08 if v > 0.86 else 1.0
            # two faint wheel ruts worn into the earth
            if x in (10, 21):
                tone *= 0.93
            col[y][x] = shade(soil, tone)
            d, side = mirror(x)
            for n, (y0, y1, w) in enumerate(stones[side]):
                if not (y0 <= y <= y1 and d < w):
                    continue
                corner = d == w - 1 and y in (y0, y1)
                if corner:
                    break
                grey = greys[(n + side * 2) % len(greys)]
                col[y][x] = shade(grey, 0.94 + 0.12 * noise(x, y, 7))
                hgt[y][x] = 1.6 if 0 < d < w - 1 and y0 < y < y1 else 1.0
                break
            else:
                if d < 5:
                    col[y][x] = shade(soil, 0.72)   # dark earth between the stones
                    hgt[y][x] = -0.3
    # a few pebbles pressed into the surface
    for x, y in ((8, 4), (17, 9), (24, 14), (13, 19), (7, 25), (19, 28), (23, 2)):
        col[y][x] = shade((142, 136, 124), 1.0)
        hgt[y][x] = 0.8
    return col, hgt


def timber():
    col, hgt = blank()
    plank = ((148, 97, 73), (136, 88, 62), (156, 104, 76), (140, 92, 68))
    beam = (102, 67, 47)
    cleat = (176, 122, 88)
    dark = (60, 38, 26)
    for y in range(SIZE):
        for x in range(SIZE):
            d, side = mirror(x)
            if d < 4:   # edge beam, grain along the slope
                grain = 0.92 if noise(x, y // 4, 23) < 0.3 else 1.0
                col[y][x] = shade(beam, grain)
                hgt[y][x] = 2.0
                if d in (0, 3):
                    col[y][x] = dark
                    hgt[y][x] = 1.4
                if d in (1, 2) and y % 16 in (7, 8):   # peg heads
                    col[y][x] = shade(cleat, 1.05)
                continue
            board = y // 8
            grain = noise(x // 3, y, 17)
            tone = 0.91 if grain < 0.22 else 1.07 if grain > 0.88 else 1.0
            col[y][x] = shade(plank[board], tone)
            if y % 8 == 7:   # gap between two planks
                col[y][x] = shade(plank[board], 0.62)
                hgt[y][x] = -0.5
            if y % 16 in (3, 4):   # cleat nailed across the planks
                col[y][x] = shade(cleat, 0.95 if grain < 0.3 else 1.0)
                hgt[y][x] = 1.2
                if y % 16 == 3 and d in (6, 14):
                    col[y][x] = dark   # nail heads
    return col, hgt


def stone():
    col, hgt = blank()
    flags = ((152, 148, 140), (142, 139, 133), (160, 155, 146), (147, 145, 140), (156, 150, 139))
    kerb = (172, 168, 160)
    joint = (88, 85, 80)
    for y in range(SIZE):
        for x in range(SIZE):
            d, side = mirror(x)
            if d < 4:   # long kerb stones, 16 to a stone, joints staggered left and right
                col[y][x] = shade(kerb, 0.95 + 0.08 * noise(x, y, 31))
                hgt[y][x] = 1.8
                if d == 3 or (y + side * 8) % 16 == 15:
                    col[y][x] = joint
                    hgt[y][x] = 0.4
                continue
            course = y // 8
            run = (x - 4 + (6 if course % 2 else 0)) % 24
            block = (run // 12 + course * 2) % len(flags)
            if course % 2 and x - 4 < 6:
                block = (block + 3) % len(flags)
            v = noise(x, y, 29)
            tone = 0.93 if v < 0.14 else 1.06 if v > 0.9 else 1.0
            col[y][x] = shade(flags[block], tone)
            if y % 8 == 7 or (run % 12 == 11 and d > 4):   # no joint doubled against the kerb
                col[y][x] = joint
                hgt[y][x] = -0.6
    return col, hgt


def concrete():
    col, hgt = blank()
    slab = (158, 158, 154)
    kerb = (190, 190, 184)
    paint = (214, 178, 54)
    edge = (84, 84, 84)
    for y in range(SIZE):
        for x in range(SIZE):
            d, side = mirror(x)
            if d < 3:   # raised kerb
                col[y][x] = shade(kerb, 0.97 + 0.05 * noise(x, y, 41))
                hgt[y][x] = 1.8
                if d == 2:
                    col[y][x] = edge
                    hgt[y][x] = 0.5
                continue
            v = noise(x, y, 43)
            tone = 0.96 if v < 0.12 else 1.03 if v > 0.92 else 1.0
            col[y][x] = shade(slab, tone)
            if d in (3, 4):   # painted line inside the kerb
                col[y][x] = shade(paint, 0.94 if v < 0.2 else 1.0)
            elif y % 4 == 3:   # ribbed anti-slip groove
                col[y][x] = shade(slab, 0.86)
                hgt[y][x] = -0.35
    return col, hgt


LAYOUTS = {'earth_ramp': earth, 'timber_ramp': timber, 'stone_ramp': stone, 'concrete_ramp': concrete}


def turn(grid, name):
    """A NORTH grid turned so the high end faces the named direction."""
    if name == 'NORTH':
        return [row[:] for row in grid]
    if name == 'SOUTH':
        return [row[::-1] for row in grid[::-1]]
    if name == 'EAST':  # a quarter turn clockwise
        return [[grid[SIZE - 1 - x][y] for x in range(SIZE)] for y in range(SIZE)]
    return [[grid[x][SIZE - 1 - y] for x in range(SIZE)] for y in range(SIZE)]  # WEST


def paint(col, hgt, along):
    """Colour one direction: slope brightness, then relief lit from the top left."""
    im = Image.new('RGBA', (SIZE, SIZE))
    px = im.load()
    for y in range(SIZE):
        for x in range(SIZE):
            h = hgt[y][x]
            # the neighbouring section is the same drawing, so heights wrap
            rise = (h - hgt[y][(x - 1) % SIZE]) + (h - hgt[(y - 1) % SIZE][x])
            fall = (h - hgt[y][(x + 1) % SIZE]) + (h - hgt[(y + 1) % SIZE][x])
            light = max(-2.5, min(2.5, (rise - fall) / 2.0)) * RELIEF
            slope = HIGH + (LOW - HIGH) * along[y][x] / (SIZE - 1)
            px[x, y] = shade(col[y][x], slope * (1.0 + light)) + (255,)
    return im


def build():
    along = [[float(y)] * SIZE for y in range(SIZE)]   # 0 at the high end
    states = []
    for name in STATES:
        col, hgt = LAYOUTS[name]()
        frames = [paint(turn(col, d), turn(hgt, d), turn(along, d)) for d in DIRS]
        states.append((name, {'dirs': '4', 'frames': '1'}, frames))
    return states


def brightness(im, box):
    cells = list(im.crop(box).convert('L').tobytes())
    return sum(cells) / float(len(cells))


# the quarter of the tile at the high end, and the one at the low end, per direction
ENDS = {
    'NORTH': ((0, 0, 32, 8), (0, 24, 32, 32)),
    'SOUTH': ((0, 24, 32, 32), (0, 0, 32, 8)),
    'EAST': ((24, 0, 32, 32), (0, 0, 8, 32)),
    'WEST': ((0, 0, 8, 32), (24, 0, 32, 32)),
}


def check_drawing(states):
    problems = []
    if [name for name, _, _ in states] != list(STATES):
        problems.append('states are %s' % [name for name, _, _ in states])
    for name, _, frames in states:
        if len(frames) != len(DIRS):
            problems.append('%s: %d frames' % (name, len(frames)))
        for d, im in zip(DIRS, frames):
            if im.size != (SIZE, SIZE):
                problems.append('%s %s: size %s' % (name, d, im.size))
            if im.getchannel('A').getextrema() != (255, 255):
                problems.append('%s %s: does not cover the whole tile' % (name, d))
            high, low = ENDS[d]
            if brightness(im, high) < brightness(im, low) + 12:
                problems.append('%s %s: the high end is not clearly lighter' % (name, d))
        if len({f.tobytes() for f in frames}) != len(frames):
            problems.append('%s: two directions are the same picture' % name)
    return problems


def check_sheet(path, states):
    path = Path(path)
    if not path.exists():
        return ['%s is missing' % path]
    found = read_dmi(path)
    if [(n, d, f) for n, d, f, _ in found] != [(n, 4, 1) for n, _, _ in states]:
        return ['%s lists %s' % (path.name, [(n, d, f) for n, d, f, _ in found])]
    problems = []
    for (name, _, frames), (_, _, _, images) in zip(states, found):
        for d, want, got in zip(DIRS, frames, images):
            if want.tobytes() != got.tobytes():
                problems.append('%s %s: committed pixels differ from the drawing' % (name, d))
    return problems


def write_preview(path, states, scale=4):
    """One row per state: SOUTH, NORTH, EAST, WEST at 4x, a run of four
    sections climbing EAST at 4x, then a run of four climbing NORTH at 1x."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    gap = 8
    cell = SIZE * scale
    width = gap + 4 * (cell + gap) + 4 * cell + gap + SIZE + gap
    height = gap + len(states) * (cell + gap)
    sheet = Image.new('RGB', (width, height), (96, 100, 96))
    y = gap
    for _, _, frames in states:
        x = gap
        for im in frames:
            sheet.paste(im.resize((cell, cell), Image.NEAREST).convert('RGB'), (x, y))
            x += cell + gap
        run = Image.new('RGBA', (SIZE * 4, SIZE))
        for n in range(4):
            run.paste(frames[2], (n * SIZE, 0))
        sheet.paste(run.resize((cell * 4, cell), Image.NEAREST).convert('RGB'), (x, y))
        x += cell * 4 + gap
        for n in range(4):
            sheet.paste(frames[1].convert('RGB'), (x, y + n * SIZE))
        y += cell + gap
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
        print('ramps: %s' % ('FAILED' if problems else 'ok'))
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
