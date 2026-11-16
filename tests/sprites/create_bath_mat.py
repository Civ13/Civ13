#!/usr/bin/env python3
"""Draw the bath mat in icons/obj/bath_mat.dmi.

One single-direction 32x32 state:

  bath_mat  a thick woven cotton mat lying flat on the floor, seen from above

The mat is a 20x13 px rectangle with clipped corners, set a little low on the
tile. A one pixel dark outline surrounds a pale selvedge, a darker blue border
band and a pale blue field woven in a regular basket stitch. Short ragged
fringes hang off the two short ends. Light comes from the top left: the
selvedge and band are lighter along the top and left and darker along the
bottom and right, and a very faint shadow lies under the bottom and right edges. The
rest of the tile stays transparent. The drawing is plain pixel work with
Pillow; nothing is random, so a rerun writes the same bytes.

  python3 tests/sprites/create_bath_mat.py                  write the sheet
  python3 tests/sprites/create_bath_mat.py --check          verify the committed sheet
  python3 tests/sprites/create_bath_mat.py --preview <png>  also write a 4x review sheet
"""
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_water_animation import SIZE, write_dmi  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/bath_mat.dmi'
STATES = ('bath_mat',)
FLOORS = ((121, 88, 58), (126, 126, 122), (138, 104, 68))  # dirt, stone, planks

OUTLINE = (78, 92, 114)
# pale selvedge just inside the outline: shaded, lit
RIM = [(186, 204, 220), (240, 245, 248)]
# border band: shaded, lit
BAND = [(98, 132, 170), (124, 158, 192)]
# woven field: stitch gap, body, raised loop
FIELD = [(184, 204, 220), (208, 224, 234), (238, 244, 248)]
# fringe: strand next to the mat, then the loose tip of every other strand
FRINGE = [(226, 234, 240), (188, 202, 214)]
SHADOW = (0, 0, 0, 46)

LEFT, TOP, WIDTH, HEIGHT = 6, 11, 20, 13
RIGHT, BOTTOM = LEFT + WIDTH - 1, TOP + HEIGHT - 1
FRINGE_ROWS = range(TOP + 1, BOTTOM)  # every row clear of the corners


def mat_cells():
    cells = {(x, y) for y in range(TOP, BOTTOM + 1) for x in range(LEFT, RIGHT + 1)}
    return cells - {(LEFT, TOP), (RIGHT, TOP), (LEFT, BOTTOM), (RIGHT, BOTTOM)}


def fringe_cells():
    """Map of fringe pixel to its tone: a ragged edge, strands one and two pixels long."""
    cells = {}
    for y in FRINGE_ROWS:
        for step, tone in enumerate(FRINGE[:1 + (y - TOP) % 2]):
            cells[(LEFT - 1 - step, y)] = tone
            cells[(RIGHT + 1 + step, y)] = tone
    return cells


def noise(x, y, seed):
    n = (x * 73856093) ^ (y * 19349663) ^ (seed * 83492791)
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def edge(cells, x, y):
    return any((x + dx, y + dy) not in cells for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))


def field_tone(x, y):
    """Basket stitch: two pixel loops, offset by two on alternate rows."""
    fx, fy = x - (LEFT + 3), y - (TOP + 3)
    raised = ((fx + 2 * (fy % 2)) // 2) % 2 == 0
    if y == BOTTOM - 3 or x == RIGHT - 3:
        return FIELD[1] if raised else FIELD[0]  # the pile falls away from the light
    return FIELD[2] if raised else FIELD[1]


def mat():
    im = Image.new('RGBA', (SIZE, SIZE))
    px = im.load()
    cells = mat_cells()
    fringe = fringe_cells()
    # faint shadow, one pixel down and right of everything solid
    for x, y in list(cells) + list(fringe):
        for dx, dy in ((0, 1), (1, 1)):
            px[x + dx, y + dy] = SHADOW
    for (x, y), tone in fringe.items():
        px[x, y] = tone + (255,)
    for x, y in cells:
        depth = min(x - LEFT, RIGHT - x, y - TOP, BOTTOM - y)
        lit = y - TOP == depth or x - LEFT == depth
        if edge(cells, x, y):
            tone = OUTLINE
        elif depth == 1:
            tone = RIM[1] if lit else RIM[0]  # the pale selvedge
        elif depth == 2:
            tone = BAND[1] if lit else BAND[0]  # the darker border band
        else:
            tone = field_tone(x, y)
        px[x, y] = tone + (255,)
    return im


def build():
    return [(name, {'dirs': '1', 'frames': '1'}, [im]) for name, im in zip(STATES, (mat(),))]


def check_drawing(states):
    problems = []
    cells = mat_cells()
    fringe = fringe_cells()
    for name, _, (im,) in states:
        px = im.load()
        solid = {(x, y) for y in range(SIZE) for x in range(SIZE) if px[x, y][3] == 255}
        faint = {(x, y) for y in range(SIZE) for x in range(SIZE) if 0 < px[x, y][3] < 255}
        if solid != cells | set(fringe):
            problems.append('%s: solid pixels are not the mat and its fringes' % name)
        if any(px[x, y] != SHADOW for x, y in faint):
            problems.append('%s: half transparent pixels are not the shadow' % name)
        if not faint or len(faint) > 60:
            problems.append('%s: shadow covers %d pixels' % (name, len(faint)))
        xs = [x for x, _ in cells]
        ys = [y for _, y in cells]
        if (max(xs) - min(xs) + 1, max(ys) - min(ys) + 1) != (20, 13):
            problems.append('%s: mat is not 20x13' % name)
        if min(xs) + max(xs) != SIZE - 1:
            problems.append('%s: mat is not centred across the tile' % name)
        if not 0 < (min(ys) + max(ys)) - (SIZE - 1) <= 6:
            problems.append('%s: mat is not set a little low' % name)
        if any(px[x, y][:3] != OUTLINE for x, y in cells if edge(cells, x, y)):
            problems.append('%s: outline is broken' % name)
        tones = [px[x, y][:3] for x, y in cells]
        if sum(t in BAND for t in tones) < 40 or sum(t in FIELD for t in tones) < 60:
            problems.append('%s: band or woven field is missing' % name)
        if len({t for t in tones if t in FIELD}) != len(FIELD):
            problems.append('%s: weave does not use every field tone' % name)
        left = sum(x < LEFT for x, _ in fringe)
        if left < 6 or left * 2 != len(fringe):
            problems.append('%s: fringes are uneven' % name)
        box = im.getchannel('A').getbbox()
        if box[0] < 2 or box[1] < 2 or box[2] > SIZE - 2 or box[3] > SIZE - 2:
            problems.append('%s: drawing touches the tile edge' % name)
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
    """The mat over three floor tones at 4x, with a 1x row underneath."""
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
        print('bath mat: %s' % ('FAILED' if problems else 'ok'))
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
