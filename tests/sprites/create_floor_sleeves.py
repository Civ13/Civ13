#!/usr/bin/env python3
"""Draw the floor sleeve in icons/obj/floor_sleeves.dmi.

One single-direction 32x32 state:

  sleeve  a short fired-clay lined shaft set flush into a floor, seen from
          above, so pipes can pass through to the level below or above

It is a round terracotta collar ring centred on the tile around a dark hollow.
The hollow is darkest under the upper (far) inner wall and ends in a lighter
lit lip of clay lining along its bottom edge. The collar is lit from the top
left and has a one pixel darker outline. The rest of the tile stays
transparent: the sleeve sits over whatever floor is there and pipes on the
same tile are drawn above it. The drawing is plain pixel work with Pillow;
nothing is random, so a rerun writes the same bytes.

  python3 tests/sprites/create_floor_sleeves.py                  write the sheet
  python3 tests/sprites/create_floor_sleeves.py --check          verify the committed sheet
  python3 tests/sprites/create_floor_sleeves.py --preview <png>  also write a 4x review sheet
"""
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_water_animation import SIZE, write_dmi  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/floor_sleeves.dmi'
STATES = ('sleeve',)
FLOORS = ((121, 88, 58), (126, 126, 122), (138, 104, 68))  # dirt, stone, planks

# outline, deep shade, shade, body, light, highlight
CLAY = [(84, 40, 26), (124, 62, 40), (150, 78, 50), (174, 96, 62), (196, 116, 78), (216, 140, 100)]
# the hollow, from the black under the far wall down to the lit lining
HOLE = [(12, 9, 9), (22, 15, 13), (36, 23, 18), (58, 34, 25)]
LIP = [(104, 54, 36), (136, 74, 48)]

CENTRE = 15.5
OUTER = 7.0  # collar radius: 14 px across
INNER = 4.1  # hollow radius: 8 px across


def noise(x, y, seed):
    n = (x * 73856093) ^ (y * 19349663) ^ (seed * 83492791)
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def disc(radius):
    return {(x, y) for y in range(SIZE) for x in range(SIZE)
            if (x - CENTRE) ** 2 + (y - CENTRE) ** 2 <= radius * radius}


def edge(cells, x, y):
    return any((x + dx, y + dy) not in cells for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))


def sleeve():
    im = Image.new('RGBA', (SIZE, SIZE))
    px = im.load()
    collar, hollow = disc(OUTER), disc(INNER)
    top = min(y for _, y in hollow)
    bottom = max(y for _, y in hollow)
    for x, y in collar:
        if (x, y) in hollow:
            if (x, y + 1) not in hollow:
                # lit lip of the lining, brightest on the side facing the light
                tone = LIP[1] if x >= CENTRE else LIP[0]
            else:
                depth = (y - top) / float(bottom - 1 - top)
                tone = HOLE[0] if depth < 0.34 else HOLE[1] if depth < 0.6 else HOLE[2] if depth < 0.85 else HOLE[3]
                if (x - 1, y) not in hollow and depth >= 0.34:
                    tone = HOLE[max(0, HOLE.index(tone) - 1)]  # left wall is in shade
            px[x, y] = tone + (255,)
            continue
        if edge(collar, x, y):
            px[x, y] = CLAY[0] + (255,)
            continue
        # top face of the collar: lit from the top left
        lit = -((x - CENTRE) + (y - CENTRE)) / (OUTER * 1.4142)
        tone = 5 if lit > 0.62 else 4 if lit > 0.22 else 3 if lit > -0.3 else 2
        if edge(collar - hollow, x, y) and (x, y - 1) in hollow:
            tone = min(5, tone + 1)  # near rim of the hollow catches the light
        elif any((x + dx, y + dy) in hollow for dx, dy in ((0, 1), (1, 0), (-1, 0))) and tone > 2:
            tone -= 1  # collar rolls over into the shaft
        px[x, y] = CLAY[tone] + (255,)
    return im


def build():
    return [(name, {'dirs': '1', 'frames': '1'}, [im]) for name, im in zip(STATES, (sleeve(),))]


def check_drawing(states):
    problems = []
    for name, _, (im,) in states:
        alpha = im.getchannel('A')
        if set(alpha.tobytes()) - {0, 255}:
            problems.append('%s: has half transparent pixels' % name)
        box = alpha.getbbox()
        width, height = box[2] - box[0], box[3] - box[1]
        if not (12 <= width <= 14 and 12 <= height <= 14):
            problems.append('%s: collar is %dx%d' % (name, width, height))
        if box[0] + box[2] != SIZE or box[1] + box[3] != SIZE:
            problems.append('%s: collar is not centred on the tile' % name)
        px = im.load()
        mid = SIZE // 2
        if sum(px[mid, box[1] + 3][:3]) >= sum(px[mid, box[3] - 4][:3]):
            problems.append('%s: hollow is not darker under the far wall' % name)
        if px[mid, mid][:3] not in HOLE:
            problems.append('%s: centre is not hollow' % name)
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
    """The sleeve over three floor tones at 4x, with a 1x row underneath."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    (_, _, (im,)) = states[0]
    strip = Image.new('RGBA', (SIZE * len(FLOORS), SIZE))
    px = strip.load()
    for n, floor in enumerate(FLOORS):
        for y in range(SIZE):
            for x in range(n * SIZE, (n + 1) * SIZE):
                v = noise(x, y, 40 + n)
                shift = -9 if v < 0.14 else 7 if v > 0.9 else 0
                px[x, y] = tuple(c + shift for c in floor) + (255,)
        strip.alpha_composite(im, (n * SIZE, 0))
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
        print('floor sleeves: %s' % ('FAILED' if problems else 'ok'))
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
