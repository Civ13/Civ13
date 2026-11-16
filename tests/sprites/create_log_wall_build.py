#!/usr/bin/env python3
"""Draw the half-built log wall stages in icons/obj/log_wall_build.dmi.

Log walls are raised in steps (code/game/objects/covers_types/log_wall_building.dm).
The finished wall keeps its sprites `log_wall` and `log_wall_corner` in
icons/turf/walls.dmi; this sheet holds what the wall looks like before that:

  sill, sill_corner            one log on the ground
  courses, courses_corner      two logs, waist high
  upper, upper_corner          head high, the top plate still missing
  unchinked, unchinked_corner  full height, daylight between the logs

The straight states have four directions like `log_wall` (DMI order SOUTH,
NORTH, EAST, WEST): the logs run across the tile for EAST and WEST and up the
tile for SOUTH and NORTH, which is the same drawing flipped over its diagonal.
The corner states have one direction like `log_wall_corner`.

The five colours, the 10 pixel log pitch, the dark seams and the light rim on
the outer tile edge are those of `log_wall`, so a lower log sits on the same
rows as in the finished wall and the wall grows in place. The crossing logs of
a corner show as end grain lapped half a log above each course. Nothing is
notched before the wall is finished, so the ends are hewn rough; the unchinked
corner has the one large end of `log_wall_corner`, still rough. The gaps of the
unchinked wall are transparent, so whatever lies behind shows through.

Plain pixel work with Pillow; nothing is random, so a rerun writes the same
bytes. The finished sprites are only read for the review sheet.

  python3 tests/sprites/create_log_wall_build.py                  write the sheet
  python3 tests/sprites/create_log_wall_build.py --check          verify the committed sheet
  python3 tests/sprites/create_log_wall_build.py --preview <png>  also write an 8x review sheet
"""
import math
import re
import sys
from pathlib import Path
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_water_animation import SIZE, write_dmi  # noqa: E402
from create_bollards import DIRT, noise, option  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/log_wall_build.dmi'
FINISHED = ROOT / 'icons/turf/walls.dmi'
STAGES = ('sill', 'courses', 'upper', 'unchinked')
STATES = tuple(name + tail for name in STAGES for tail in ('', '_corner'))
DIRS = ('SOUTH', 'NORTH', 'EAST', 'WEST')  # DMI order for dirs = 4
EDGE = SIZE - 1

# the five colours of log_wall, dark to light
SEAM, SHADE, BARK, WOOD, LIGHT = range(5)
PALETTE = [(25, 17, 10), (46, 36, 26), (60, 47, 31), (91, 76, 50), (122, 111, 93)]

# (first row, last row) of each log of log_wall drawn with the logs across the
# tile, bottom log first; rows 11-12 and 19-20 are the seams between them
LOGS = ((21, 29), (13, 18), (2, 10))
SHORT_TOP = (5, 10)  # the third log before the top plate: a slimmer pole
SEAMS = ((19, 20), (11, 12))
END_X = 16  # the end grain of the crossing logs sits on this column


def bark(x, y, y0, y1, seed):
    """Tone of a log lying across the tile on rows y0..y1, lit from above."""
    i, last = y - y0, y1 - y0
    if i in (0, last):  # where the log turns away: bark in shade, with furrows
        n = noise((x + i) // 2, y, seed)
        return SEAM if n < 0.2 else SHADE if n < 0.5 else BARK
    length = 4 + int(noise(y, 3, seed) * 4)  # streaks along the grain, 4 to 7 long
    n = noise((x + int(noise(y, 5, seed) * 9)) // length, y, seed + 1)
    if i in (1, last - 1):
        return WOOD if n > 0.72 else BARK
    if n > (0.74 if i <= last // 2 else 0.86):
        return LIGHT
    return WOOD if n > 0.42 else BARK


def lay(t, span, seed):
    for y in range(span[0], span[1] + 1):
        for x in range(SIZE):
            t[x, y] = bark(x, y, span[0], span[1], seed)


def seam(t, rows, open_gap):
    """The joint between two logs; open_gap leaves runs of it see-through."""
    upper, lower = rows
    for x in range(SIZE):
        t[x, upper] = SEAM
        t[x, lower] = SHADE
        if open_gap:
            t[x, lower] = SEAM
            run = (x + upper * 5) % 9  # six open, three where the logs bear on each other
            if run < 6:
                del t[x, upper]
                if 1 <= run <= 3 and noise(x // 3, upper, 61) > 0.45:
                    del t[x, lower]


def end_grain(t, cy, radius, seed):
    """Hewn end of a crossing log: rough rim, growth rings, an axe check."""
    cx = END_X - 0.5
    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = x - cx, y - (cy - 0.5)
            d = math.hypot(dx, dy)
            facet = int((math.atan2(dy, dx) + math.pi) / (2 * math.pi) * 7) % 7
            r = radius + (noise(facet, 0, seed) - 0.5) * 1.5  # seven axe facets
            if d > r + 1:
                continue
            if d > r:
                t[x, y] = SEAM
            elif d > r - 1 and radius > 5:
                t[x, y] = BARK if dy < 0 else SHADE
            elif radius > 5:
                ring = int(d * 1.15 + 0.4)
                t[x, y] = (LIGHT, WOOD, LIGHT, WOOD, BARK, LIGHT, WOOD)[ring % 7]
                if noise(x, y, seed + 2) < 0.12:
                    t[x, y] = WOOD
            else:  # a small end: pale fresh wood, one ring, shade under the lower rim
                t[x, y] = WOOD if 1.6 < d <= 2.6 or (d > r - 1 and dy > 0) else LIGHT
    for k in range(1, int(radius) - 1):  # the check runs up and to the right of the pith
        x, y = int(cx + 0.5 + k * 0.8), int(cy - 0.5 - k * 0.6)
        if t.get((x, y), SEAM) > SHADE:
            t[x, y] = BARK


def stage(name, corner):
    """Tones {(x, y): palette index} with the logs across the tile."""
    t = {}
    count = STAGES.index(name) + 1
    whole = name == 'unchinked'
    spans = list(LOGS[:min(count, 3)])
    if name == 'upper':
        spans[2] = SHORT_TOP
    for n, span in enumerate(spans):
        lay(t, span, 11 + n * 7)
    for rows in SEAMS[:len(spans) - 1]:
        seam(t, rows, whole)
    for x in range(SIZE):
        t[x, 30], t[x, 31] = SEAM, WOOD  # foot of the wall and the rim of log_wall
        top = spans[-1][0]
        if whole:
            t[x, 1], t[x, 0] = SEAM, WOOD
        else:
            t[x, top - 1] = SEAM  # outline over the highest log so far
    if corner:
        if whole:
            end_grain(t, 16, 6.5, 40)  # the one large end of log_wall_corner
        else:
            for n, span in enumerate(spans):
                end_grain(t, span[0] - 1, 4.0, 41 + n)  # lapped half a log higher
    return t


def render(t, upright=False):
    im = Image.new('RGBA', (SIZE, SIZE))
    px = im.load()
    for (x, y), tone in t.items():
        if 0 <= x < SIZE and 0 <= y < SIZE:
            px[(y, x) if upright else (x, y)] = PALETTE[tone] + (255,)
    return im


def build():
    states = []
    for name in STAGES:
        across, upright = render(stage(name, False)), render(stage(name, False), True)
        states.append((name, {'dirs': '4', 'frames': '1'}, [upright, upright, across, across]))
        states.append((name + '_corner', {'dirs': '1', 'frames': '1'}, [render(stage(name, True))]))
    return states


def solid(im):
    return sum(1 for a in im.getchannel('A').tobytes() if a == 255)


def check_drawing(states):
    problems = []
    by_name = {name: ims for name, _, ims in states}
    allowed = {c + (255,) for c in PALETTE} | {(0, 0, 0, 0)}
    for name, _, ims in states:
        for im in ims:
            raw = im.tobytes()
            if {tuple(raw[i:i + 4]) for i in range(0, len(raw), 4)} - allowed:
                problems.append('%s: a colour outside the log_wall palette' % name)
    for tail in ('', '_corner'):
        cover = [solid(by_name[name + tail][-1]) for name in STAGES]
        if cover != sorted(set(cover)):
            problems.append('stages%s do not grow: %s' % (tail, cover))
        for name, top in (('sill', 20), ('courses', 12), ('upper', 4), ('unchinked', 0)):
            im = by_name[name + tail][-1]
            box = im.getchannel('A').getbbox()
            limit = top if not tail or name == 'unchinked' else top - 7  # end grain laps higher
            if box[0] != 0 or box[2] != SIZE or box[3] != SIZE or not limit <= box[1] <= top:
                problems.append('%s%s: stands in rows %d-%d' % (name, tail, box[1], box[3] - 1))
        gaps = SIZE * SIZE - cover[-1]
        if not 24 <= gaps <= 90:
            problems.append('unchinked%s: %d see-through pixels' % (tail, gaps))
    for name in STAGES:
        south, north, east, west = by_name[name]
        if south.tobytes() != north.tobytes() or east.tobytes() != west.tobytes():
            problems.append('%s: SOUTH/NORTH and EAST/WEST must match like log_wall' % name)
        if south.tobytes() != east.transpose(Image.TRANSPOSE).tobytes():
            problems.append('%s: the upright logs are not the flipped drawing' % name)
        if by_name[name + '_corner'][0].tobytes() == east.tobytes():
            problems.append('%s_corner: no crossing log ends' % name)
    return problems


def check_sheet(path, states):
    path = Path(path)
    if not path.exists():
        return ['%s is missing' % path]
    sheet = Image.open(path)
    lines = [line.strip() for line in sheet.info.get('Description', '').splitlines()]
    names = [line.split('"')[1] for line in lines if line.startswith('state = ')]
    problems = []
    if names != list(STATES):
        problems.append('%s lists %s' % (path.name, names))
    if [line for line in lines if line.startswith('dirs')] != ['dirs = 4', 'dirs = 1'] * len(STAGES):
        problems.append('%s: straight states need dirs = 4, corners dirs = 1' % path.name)
    if 'width = %d' % SIZE not in lines or 'height = %d' % SIZE not in lines:
        problems.append('%s: not a %dx%d sheet' % (path.name, SIZE, SIZE))
    sheet = sheet.convert('RGBA')
    cols = sheet.width // SIZE
    n = 0
    for name, _, ims in states:
        for k, im in enumerate(ims):
            box = ((n % cols) * SIZE, (n // cols) * SIZE, (n % cols + 1) * SIZE, (n // cols + 1) * SIZE)
            if sheet.crop(box).tobytes() != im.tobytes():
                problems.append('%s %d: committed pixels differ from the drawing' % (name, k))
            n += 1
    return problems


def finished(state, index=0):
    """A frame of the finished wall from walls.dmi, for the review sheet only."""
    sheet = Image.open(FINISHED)
    at = 0
    for name, keys in re.findall(r'state = "([^"]*)"\n((?:\t.*\n)*)', sheet.info['Description']):
        if name == state:
            break
        at += int(re.search(r'dirs = (\d+)', keys)[1]) * int(re.search(r'frames = (\d+)', keys)[1])
    at += index
    cols = sheet.width // SIZE
    return sheet.convert('RGBA').crop(((at % cols) * SIZE, (at // cols) * SIZE,
                                       (at % cols + 1) * SIZE, (at // cols + 1) * SIZE))


def write_preview(path, states, scale=8):
    """Rows: logs across (EAST/WEST), logs upright (SOUTH/NORTH), corners. Last column: the finished wall."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    by_name = {name: ims for name, _, ims in states}
    rows = (
        ('EAST/WEST', [(name, by_name[name][2]) for name in STAGES] + [('log_wall (walls.dmi)', finished('log_wall', 2))]),
        ('SOUTH/NORTH', [(name, by_name[name][0]) for name in STAGES] + [('log_wall (walls.dmi)', finished('log_wall'))]),
        ('corner', [(name + '_corner', by_name[name + '_corner'][0]) for name in STAGES]
         + [('log_wall_corner (walls.dmi)', finished('log_wall_corner'))]),
    )
    pad, head = 6, 5  # ground around each tile and room for the label, in sprite pixels
    cw, ch = SIZE + pad * 2, SIZE + pad + head
    sheet = Image.new('RGBA', (cw * 5, ch * len(rows)), DIRT + (255,))
    px = sheet.load()
    for y in range(sheet.height):
        for x in range(sheet.width):
            n = noise(x, y, 40)
            shift = -9 if n < 0.14 else 7 if n > 0.9 else 0
            px[x, y] = tuple(c + shift for c in DIRT) + (255,)
    for r, (_, cells) in enumerate(rows):
        for c, (_, im) in enumerate(cells):
            sheet.alpha_composite(im, (c * cw + pad, r * ch + head))
    big = sheet.convert('RGB').resize((sheet.width * scale, sheet.height * scale), Image.NEAREST)
    draw = ImageDraw.Draw(big)
    for r, (side, cells) in enumerate(rows):
        for c, (name, _) in enumerate(cells):
            x, y = c * cw * scale, r * ch * scale
            label = name if side == 'corner' else '%s  %s' % (name, side)
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
        print('log wall build: %s' % ('FAILED' if problems else 'ok'))
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
