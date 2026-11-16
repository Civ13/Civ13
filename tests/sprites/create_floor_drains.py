#!/usr/bin/env python3
"""Draw the floor drains in icons/obj/floor_drains.dmi.

Two single-direction 32x32 states:

  floor_drain          a dressed-stone drain slab set flush into a floor, seen
                       from above, with nine square holes cut through it
  floor_drain_clogged  the same slab with the holes choked by a grey-brown mat
                       of hair, silt and scum and muddy water pooled on top

The slab is a 12 px square of grey stone with clipped corners, centred on the
tile, lit from the top left, with a one pixel darker outline. Each hole is
black under its upper (far) edge and the stone below it catches the light.
The rest of the tile stays transparent: the drain sits over whatever floor is
there. The drawing is plain pixel work with Pillow; nothing is random, so a
rerun writes the same bytes.

  python3 tests/sprites/create_floor_drains.py                  write the sheet
  python3 tests/sprites/create_floor_drains.py --check          verify the committed sheet
  python3 tests/sprites/create_floor_drains.py --preview <png>  also write a 4x review sheet
"""
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_water_animation import SIZE, write_dmi  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/floor_drains.dmi'
STATES = ('floor_drain', 'floor_drain_clogged')
FLOORS = ((121, 88, 58), (126, 126, 122), (138, 104, 68))  # dirt, stone, planks

# outline, shade, body, light, highlight
STONE = [(58, 58, 60), (112, 112, 112), (140, 140, 138), (164, 164, 160), (190, 190, 184)]
HOLE = [(10, 10, 12), (26, 26, 30)]  # under the far edge, then the nearer half
# the mat: dark strands, body, light scum
MAT = [(62, 52, 42), (92, 80, 64), (120, 108, 88)]
# muddy water: shade, body, glint
WATER = [(84, 70, 48), (112, 94, 62), (176, 164, 128)]

LEFT, RIGHT = 10, 21  # slab spans 12 px
HOLES = [(x, y) for y in (12, 15, 18) for x in (12, 15, 18)]  # top left of each 2x2 hole

# the clog, drawn over rows 11..20 of the slab:
#   . stone  m mat  d dark strand  s scum  w water  v water shade  g glint  o open hole
CLOG = (
    '..........',
    '.dm..mmd..',
    '.mmmdmsmo.',
    '..mwwwwm..',
    '.dwgwwwwd.',
    '.mwwwgwvm.',
    '..vwwwvmm.',
    '.omvvvmdm.',
    '.ommdmmsm.',
    '....d.....',
)


def slab_cells():
    cells = {(x, y) for y in range(LEFT, RIGHT + 1) for x in range(LEFT, RIGHT + 1)}
    return cells - {(LEFT, LEFT), (RIGHT, LEFT), (LEFT, RIGHT), (RIGHT, RIGHT)}


def noise(x, y, seed):
    n = (x * 73856093) ^ (y * 19349663) ^ (seed * 83492791)
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def edge(cells, x, y):
    return any((x + dx, y + dy) not in cells for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))


def drain():
    im = Image.new('RGBA', (SIZE, SIZE))
    px = im.load()
    slab = slab_cells()
    holes = {(hx + dx, hy + dy) for hx, hy in HOLES for dx in (0, 1) for dy in (0, 1)}
    for x, y in slab:
        if edge(slab, x, y):
            tone = STONE[0]
        elif (x, y) in holes:
            tone = HOLE[0] if (x, y - 1) not in holes else HOLE[1]
        else:
            # top face: a bevel lit along the top and left, shaded bottom and right
            if y == LEFT + 1 or x == LEFT + 1:
                level = 4 if x + y <= LEFT * 2 + 9 else 3
            elif y == RIGHT - 1 or x == RIGHT - 1:
                level = 1
            else:
                level = 2
            if (x, y - 1) in holes and level < 4:
                level = 3  # near lip of a hole catches the light
            elif (x, y + 1) in holes and level == 2:
                level = 1  # stone rolls over into the hole
            tone = STONE[level]
        px[x, y] = tone + (255,)
    return im


def clogged():
    im = drain()
    px = im.load()
    key = {'m': MAT[1], 'd': MAT[0], 's': MAT[2], 'w': WATER[1], 'v': WATER[0], 'g': WATER[2]}
    for row, line in enumerate(CLOG):
        for col, ch in enumerate(line):
            if ch in key:
                px[LEFT + 1 + col, LEFT + 1 + row] = key[ch] + (255,)
    return im


def build():
    return [(name, {'dirs': '1', 'frames': '1'}, [im]) for name, im in zip(STATES, (drain(), clogged()))]


def check_drawing(states):
    problems = []
    counts = {}
    for name, _, (im,) in states:
        alpha = im.getchannel('A')
        if set(alpha.tobytes()) - {0, 255}:
            problems.append('%s: has half transparent pixels' % name)
        box = alpha.getbbox()
        width, height = box[2] - box[0], box[3] - box[1]
        if not (12 <= width <= 14 and 12 <= height <= 14):
            problems.append('%s: slab is %dx%d' % (name, width, height))
        if box[0] + box[2] != SIZE or box[1] + box[3] != SIZE:
            problems.append('%s: slab is not centred on the tile' % name)
        px = im.load()
        slab = slab_cells()
        if any(px[x, y][:3] != STONE[0] for x, y in slab if edge(slab, x, y)):
            problems.append('%s: outline is broken' % name)
        tones = [px[x, y][:3] for x, y in slab]
        counts[name] = (sum(t in HOLE for t in tones), sum(t in MAT for t in tones),
                        sum(t in WATER for t in tones))
    if len(states) == len(STATES):
        open_holes, mat, water = counts[STATES[0]]
        if open_holes != len(HOLES) * 4 or mat or water:
            problems.append('%s: holes are not all open' % STATES[0])
        open_holes, mat, water = counts[STATES[1]]
        if open_holes > 8 or mat < 20 or water < 12:
            problems.append('%s: does not read as blocked' % STATES[1])
    return problems


def check_sheet(path, states):
    path = Path(path)
    if not path.exists():
        return ['%s is missing' % path]
    sheet = Image.open(path)
    text = sheet.info.get('Description', '')
    names = [line.split('"')[1] for line in text.splitlines() if line.startswith('state = ')]
    problems = []
    if names != list(STATES):
        problems.append('%s lists %s' % (path.name, names))
    sheet = sheet.convert('RGBA')
    for n, (name, _, (im,)) in enumerate(states):
        if sheet.crop((n * SIZE, 0, (n + 1) * SIZE, SIZE)).tobytes() != im.tobytes():
            problems.append('%s: committed pixels differ from the drawing' % name)
    return problems


def write_preview(path, states, scale=4):
    """Both states over three floor tones at 4x, with a 1x row underneath."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    cols = len(FLOORS) * len(states)
    strip = Image.new('RGBA', (SIZE * cols, SIZE))
    px = strip.load()
    for n in range(cols):
        floor = FLOORS[n % len(FLOORS)]
        for y in range(SIZE):
            for x in range(n * SIZE, (n + 1) * SIZE):
                v = noise(x % (SIZE * len(FLOORS)), y, 40 + n % len(FLOORS))
                shift = -9 if v < 0.14 else 7 if v > 0.9 else 0
                px[x, y] = tuple(c + shift for c in floor) + (255,)
        strip.alpha_composite(states[n // len(FLOORS)][2][0], (n * SIZE, 0))
    strip = strip.convert('RGB')
    sheet = Image.new('RGB', (strip.width * scale, strip.height * scale + SIZE), (32, 32, 32))
    sheet.paste(strip.resize((strip.width * scale, strip.height * scale), Image.NEAREST), (0, 0))
    sheet.paste(strip, (0, strip.height * scale))
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
        print('floor drains: %s' % ('FAILED' if problems else 'ok'))
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
