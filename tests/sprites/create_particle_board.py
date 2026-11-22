#!/usr/bin/env python3
"""Draw the particle board sheet, icons/obj/particle_board.dmi.

Thirteen single-direction, single-frame 32x32 states in one pale tan palette:

  sawdust, sawdust_2..4        a growing heap of pale fine sawdust on the ground
  particle_board, _2.._4       one to four pressed sheets lying flat in a stack
  particle_board_swollen       a soaked stack: puffed, warped, stained, crumbling
  particle_wall                an opaque partition of two panels in a pine stud frame
  particle_wall_swollen        the same wall bulging and stained along its base
  particle_floor               a seamless floor of four square sheets, faint seams
  particle_floor_swollen       the same floor with raised, stained, crumbling seams

The stacks use the slab geometry of the `resin_laminate` states in
icons/obj/fabrics.dmi: a 20 px wide top face sheared seven rows to the right,
a four row cut edge under it and a shadowed side, each further sheet five rows
higher. The face is pale tan speckled with darker chips; the cut edges show
the coarser, darker core. Light comes from the top left. Every speckle comes
from a fixed integer hash, so a rerun writes the same bytes.

  python3 tests/sprites/create_particle_board.py                  write the sheet
  python3 tests/sprites/create_particle_board.py --check          verify the committed sheet
  python3 tests/sprites/create_particle_board.py --preview <png>  also write a 4x review sheet
"""
import math
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_water_animation import SIZE, write_dmi  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/particle_board.dmi'
STATES = (
    'sawdust', 'sawdust_2', 'sawdust_3', 'sawdust_4',
    'particle_board', 'particle_board_2', 'particle_board_3', 'particle_board_4',
    'particle_board_swollen',
    'particle_wall', 'particle_wall_swollen',
    'particle_floor', 'particle_floor_swollen',
)
ITEMS = STATES[:9]
TURFS = STATES[9:]

# pressed face, light to dark, then the two chip tones
FACE = [(232, 212, 170), (214, 190, 144), (198, 172, 124)]
CHIP = [(160, 128, 84), (126, 96, 58)]
# coarse core on a cut edge: lit arris, core, dark core, shadowed side
CORE = [(206, 180, 132), (176, 144, 96), (146, 114, 70), (118, 90, 54)]
OUTLINE = (88, 66, 38)
DEEP = (56, 41, 24)
# soaked board: face, chip, rim of the stain
WET = [(170, 148, 112), (146, 124, 90), (118, 98, 68), (92, 74, 50)]
# loose sawdust, light to shade
DUST = [(242, 228, 192), (226, 206, 162), (204, 180, 132), (172, 144, 98), (134, 106, 68)]
# pine stud frame: lit, body, grain, shade
PINE = [(230, 198, 134), (208, 172, 106), (184, 146, 86), (142, 108, 62)]
# floor sheets are the face worn a little darker so they sit beside other floors
FLOOR = [(190, 166, 122), (176, 152, 108), (162, 138, 96), (134, 108, 70), (108, 84, 52)]
SHADOW = (0, 0, 0, 46)

SLAB_W, SLAB_D, SLAB_H = 20, 7, 4


def noise(x, y, seed):
    n = (x * 73856093) ^ (y * 19349663) ^ (seed * 83492791)
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def face_tone(x, y, seed, chips=0.22):
    """Pale pressed face with scattered darker chips."""
    v = noise(x, y, seed)
    if v < chips * 0.3:
        return CHIP[1]
    if v < chips:
        return CHIP[0]
    if v < 0.40:
        return FACE[2]
    if v > 0.86:
        return FACE[0]
    return FACE[1]


def core_tone(x, y, seed, shade=0):
    """Coarse core on a cut edge: bigger, darker flecks than the face."""
    v = noise(x // 2, y, seed)
    return CORE[min(3, 1 + shade + (1 if v < 0.38 else 0))]


def slab_cells(x0, ybot, h=SLAB_H):
    """Map of pixel to part name for one sheet whose front bottom left is x0, ybot."""
    cells = {}
    w, d = SLAB_W, SLAB_D
    for v in range(0, h + d + 2):
        y = ybot - v
        for u in range(0, w + d + 2):
            t = u - (w + 1)
            part = None
            if v == 0:
                part = 'deep' if u <= w + 1 else None
            elif v <= h:
                if u == 0:
                    part = 'edge'
                elif u <= w:
                    part = 'arris' if v == h else 'base' if v == 1 else 'core'
            elif v <= h + d:
                s = v - h - 1
                if u == s or u == s + w + 1:
                    part = 'rim'
                elif s < u <= s + w:
                    part = 'lit' if (v == h + d or u == s + 1) else 'face'
            elif d <= u < d + w:
                part = 'rim'
            if part is None and v >= 1 and 0 <= t < d:
                if 1 <= v - t <= h:
                    part = 'side'
                elif v - t == 0 and t >= 1:
                    part = 'deep'
            if part:
                cells[(x0 + u, y)] = part
    return cells


def paint_part(part, x, y, seed):
    if part == 'deep':
        return DEEP
    if part in ('edge', 'rim'):
        return OUTLINE
    if part == 'arris':
        return CORE[0]
    if part == 'core':
        return core_tone(x, y, seed)
    if part == 'base':
        return core_tone(x, y, seed, 1)
    if part == 'side':
        return CORE[3] if noise(x, y, seed + 5) < 0.75 else DEEP
    tone = face_tone(x, y, seed)
    if part == 'lit' and tone in FACE:
        return FACE[0]
    return tone


# each stack from the ground up: (x0, ybot); sheets sit a little askew
STACKS = {
    'particle_board': [(2, 23)],
    'particle_board_2': [(2, 25), (3, 20)],
    'particle_board_3': [(2, 28), (3, 23), (1, 18)],
    'particle_board_4': [(2, 30), (3, 25), (1, 20), (3, 15)],
}


def stack_parts(layout, h=SLAB_H):
    parts = {}
    for n, (x0, ybot) in enumerate(layout):
        for pos, part in slab_cells(x0, ybot, h).items():
            parts[pos] = (part, n)
    return parts


def stack(name):
    im = Image.new('RGBA', (SIZE, SIZE))
    px = im.load()
    for (x, y), (part, n) in stack_parts(STACKS[name]).items():
        px[x, y] = paint_part(part, x, y, 11 + n) + (255,)
    return im


def swollen_stack():
    """Two soaked sheets: thicker, wavy, a tide-marked stain, crumbs at the foot."""
    im = Image.new('RGBA', (SIZE, SIZE))
    px = im.load()
    parts = stack_parts([(2, 26), (3, 20)], h=5)
    warped = {}
    for (x, y), value in parts.items():
        lift = 1 if math.sin(x * 0.5 + 0.9) > 0.25 else 0
        warped[(x, y - lift)] = value
    # the warp leaves one pixel gaps between columns; close them
    for (x, y), value in list(warped.items()):
        if (x, y + 1) not in warped and (x, y + 2) in warped:
            warped[(x, y + 1)] = value
    for (x, y), (part, n) in warped.items():
        tone = paint_part(part, x, y, 11 + n)
        if part in ('face', 'lit'):
            # stain: an uneven pool over the lower left of the face
            r = math.hypot((x - 11) / 7.5, (y - 12) / 3.4) + (noise(x, y, 71) - 0.5) * 0.3
            if r < 0.82:
                tone = WET[2] if tone in CHIP else WET[1] if noise(x, y, 72) < 0.3 else WET[0]
            elif r < 1.0:
                tone = WET[3]  # the tide mark
        elif part in ('core', 'base', 'arris'):
            if x < 16 + n * 2 and (n == 0 or y > 14):
                tone = WET[2] if part != 'arris' and noise(x // 2, y, 73) < 0.5 else WET[1]
                if part == 'base':
                    tone = WET[3]
        px[x, y] = tone + (255,)
    # crumbling: bites out of the front foot, flakes lying beside it
    for x, y in ((6, 27), (7, 27), (13, 27), (14, 26), (14, 27), (20, 27), (2, 26), (2, 27)):
        if px[x, y][3]:
            px[x, y] = (0, 0, 0, 0)
    for x, y in ((5, 28), (8, 29), (12, 28), (15, 29), (19, 28), (24, 27), (26, 25),
                 (1, 28), (22, 29), (10, 30), (27, 23), (17, 30)):
        px[x, y] = (FACE[1] if (x + y) % 2 else WET[0]) + (255,)
    for x, y in ((6, 28), (13, 28), (20, 28), (25, 26)):
        px[x, y] = CHIP[1] + (255,)
    return im


HEAPS = {  # half width, height, base row
    'sawdust': (5, 3, 24),
    'sawdust_2': (8, 5, 25),
    'sawdust_3': (11, 8, 26),
    'sawdust_4': (13, 11, 27),
}


def heap(name):
    """A soft mound, lit from the upper left, with a scatter of stray dust round it."""
    rx, ry, base = HEAPS[name]
    seed = 30 + rx
    im = Image.new('RGBA', (SIZE, SIZE))
    px = im.load()
    cx = 15.5
    cells = set()
    for x in range(SIZE):
        dx = (x - cx) / (rx + 0.5)
        if abs(dx) >= 1:
            continue
        # a slumped cone: steeper near the peak, ragged along the top
        top = ry * (1 - abs(dx) ** 1.5) + (noise(x, 0, seed) - 0.5) * 1.2
        for y in range(base - max(0, int(round(top))), base + 1):
            cells.add((x, y))
        # the foot spreads a row lower in the middle
        if abs(dx) < 0.72:
            cells.add((x, base + 1))
    for x, y in cells:
        for dx, dy in ((0, 1), (1, 1)):
            if (x + dx, y + dy) not in cells:
                px[x + dx, y + dy] = SHADOW
    for x, y in cells:
        dx = (x - cx) / (rx + 0.5)
        height = (base + 1 - y) / (ry + 1.0)
        light = 0.5 - dx * 0.55 + height * 0.25 + (noise(x, y, seed + 1) - 0.5) * 0.45
        below = (x, y + 1) not in cells
        right = (x + 1, y) not in cells
        above = (x, y - 1) not in cells
        if below or (right and dx > 0.3):
            tone = DUST[4] if below and dx > -0.2 else DUST[3]
        elif above and dx < 0.35:
            tone = DUST[0]
        elif light > 0.78:
            tone = DUST[0]
        elif light > 0.42:
            tone = DUST[1]
        elif light > 0.12:
            tone = DUST[2]
        else:
            tone = DUST[3]
        px[x, y] = tone + (255,)
    # stray dust lying round the foot
    for n in range(4 + rx):
        x = int(cx + (noise(n, 1, seed + 2) * 2 - 1) * (rx + 3))
        y = base + 1 + int(noise(n, 2, seed + 2) * 2.99) - (1 if abs(x - cx) > rx else 0)
        if 1 <= x < SIZE - 1 and y < SIZE - 1 and (x, y) not in cells:
            px[x, y] = (DUST[1] if n % 3 else DUST[2]) + (255,)
    return im


def wall_parts():
    """Part name for every pixel of the wall: frame members and the two inset panels."""
    parts = {}
    for y in range(SIZE):
        for x in range(SIZE):
            if x in (0, SIZE - 1) or y in (0, SIZE - 1):
                part = 'border'
            elif y <= 3:
                part = 'plate%d' % (y - 1)
            elif y >= 28:
                part = 'plate%d' % (y - 28)
            elif x <= 2 or x >= 29 or x in (15, 16):
                part = 'stud0' if x in (1, 15, 29) else 'stud2'
            else:
                part = 'panel'
            parts[(x, y)] = part
    return parts


def wall(swollen=False):
    im = Image.new('RGBA', (SIZE, SIZE))
    px = im.load()
    for (x, y), part in wall_parts().items():
        if part == 'border':
            tone = OUTLINE
        elif part.startswith('plate'):
            k = int(part[5])
            tone = (PINE[0], PINE[1], PINE[3])[k]
            if k == 1 and noise(x // 5, y, 51) < 0.3:
                tone = PINE[2]  # long grain
            if x in (8, 23) and k == 1:
                tone = PINE[3]  # nail heads over the panel centres
        elif part.startswith('stud'):
            k = int(part[4])
            tone = (PINE[0], PINE[1], PINE[3])[k]
            if k == 0 and noise(x, y // 4, 52) < 0.3:
                tone = PINE[1]
        else:
            tone = face_tone(x, y, 53, 0.14)
            left = x in (3, 17)
            if y == 4 or left:
                # the frame stands proud and shades the panel under and beside it
                tone = CHIP[0] if tone in FACE else CHIP[1]
            elif y == 5 or x in (4, 18):
                tone = FACE[2] if tone in FACE else tone
            elif y == 27 or x in (14, 28):
                tone = FACE[0] if tone in FACE else tone
        if swollen:
            tone = soak_wall(x, y, part, tone)
        px[x, y] = tone + (255,)
    return im


def soak_wall(x, y, part, tone):
    """Stain, bulge and crumble the bottom third of the wall."""
    tide = 18 + int(round(1.6 + 1.6 * math.sin(x * 0.55 + 1.0) + noise(x // 2, 0, 61)))
    if part == 'border' or y < tide:
        return tone
    if part == 'panel':
        if y == tide:
            return WET[3]  # the tide mark
        dark = tone in CHIP
        inner = 5 <= x <= 12 or 19 <= x <= 26  # the belly sags between the studs
        if inner and y == 23 + (x % 13 in (5, 6, 12, 0)):
            return FACE[2]  # the swollen belly catches the light...
        if inner and y == 26:
            return WET[3]  # ...and shades the foot
        if y == 27:
            # ragged bottom edge with pieces missing
            return DEEP if noise(x // 2, 1, 64) < 0.45 else WET[2]
        return WET[2] if dark else WET[1] if noise(x, y, 62) < 0.3 else WET[0]
    if part.startswith('stud'):
        return {PINE[0]: PINE[2], PINE[1]: PINE[3], PINE[3]: OUTLINE}.get(tone, tone)
    # bottom plate: wet timber under a litter of crumbs
    v = noise(x, y, 65)
    if v < 0.22 and y >= 29:
        return FACE[0] if v < 0.1 else FACE[1]
    if v > 0.86:
        return CHIP[1]
    return {PINE[0]: PINE[2], PINE[1]: PINE[3], PINE[3]: OUTLINE}.get(tone, WET[3])


HALF = SIZE // 2


def seam_distance(x, y):
    """Signed distance in pixels to the nearer sheet seam; seams lie on x, y = 0 and 16."""
    dx = (x % HALF + HALF // 2) % HALF - HALF // 2
    dy = (y % HALF + HALF // 2) % HALF - HALF // 2
    return dx if abs(dx) < abs(dy) else dy


def floor(swollen=False):
    im = Image.new('RGBA', (SIZE, SIZE))
    px = im.load()
    for y in range(SIZE):
        for x in range(SIZE):
            v = noise(x, y, 81)
            if v < 0.04:
                tone = FLOOR[4]
            elif v < 0.14:
                tone = FLOOR[3]
            elif v < 0.36:
                tone = FLOOR[2]
            elif v > 0.84:
                tone = FLOOR[0]
            else:
                tone = FLOOR[1]
            ax, ay = x % HALF, y % HALF
            if not swollen:
                if ax == 0 or ay == 0:
                    tone = FLOOR[3] if v < 0.8 else FLOOR[2]  # faint seam
                elif (ax == 1 or ay == 1) and tone in FLOOR[1:3]:
                    tone = FLOOR[0]  # lit edge of the next sheet
            else:
                d = seam_distance(x, y)
                near = min(abs((ax + 8) % 16 - 8), abs((ay + 8) % 16 - 8))
                reach = 1 + int(noise(x // 2, y // 2, 82) * 2.4)
                corner = abs((ax + 8) % 16 - 8) + abs((ay + 8) % 16 - 8) <= 5
                if ax == 0 or ay == 0:
                    tone = DEEP if noise(x, y, 83) < 0.3 else WET[3]  # the seam gapes
                elif d == -1 and near == 1:
                    # raised lip facing the light
                    tone = FACE[0] if noise(x, y, 84) < 0.7 else FACE[1]
                elif d == 1 and near == 1:
                    tone = WET[3] if noise(x, y, 84) < 0.5 else WET[2]  # lip in shade
                elif near <= reach or corner:
                    w = noise(x, y, 85)
                    if w < 0.08:
                        tone = FACE[0]  # crumb
                    elif w > 0.93:
                        tone = DEEP  # pit where a flake came away
                    else:
                        tone = WET[2] if tone in FLOOR[3:] else WET[1] if w < 0.4 else WET[0]
                elif near == reach + 1:
                    tone = WET[3] if noise(x, y, 86) < 0.3 else FLOOR[3]  # tide mark
            px[x, y] = tone + (255,)
    return im


def build():
    images = [heap(name) for name in STATES[:4]]
    images += [stack(name) for name in STATES[4:8]]
    images += [swollen_stack(), wall(), wall(True), floor(), floor(True)]
    return [(name, {'dirs': '1', 'frames': '1'}, [im]) for name, im in zip(STATES, images)]


PALETTE = set(FACE + CHIP + CORE + WET + DUST + PINE + FLOOR + [OUTLINE, DEEP])


def pixels(im):
    raw = im.tobytes()
    return [tuple(raw[i:i + 4]) for i in range(0, len(raw), 4)]


def check_drawing(states):
    problems = []
    if tuple(name for name, _, _ in states) != STATES:
        problems.append('state list is wrong')
    solid = {}
    for name, _, (im,) in states:
        px = im.load()
        cells = [(x, y) for y in range(SIZE) for x in range(SIZE)]
        solid[name] = sum(px[c][3] == 255 for c in cells)
        if any(px[c][3] == 255 and px[c][:3] not in PALETTE for c in cells):
            problems.append('%s: colour outside the shared palette' % name)
        if any(0 < px[c][3] < 255 and px[c] != SHADOW for c in cells):
            problems.append('%s: half transparent pixel that is not the shadow' % name)
        if name in TURFS:
            if solid[name] != SIZE * SIZE:
                problems.append('%s: does not fill the tile' % name)
        else:
            box = im.getchannel('A').getbbox()
            if not box or solid[name] < 20:
                problems.append('%s: nothing drawn' % name)
            elif abs((box[0] + box[2]) - SIZE) > 4:
                problems.append('%s: not centred across the tile' % name)
    for group in (STATES[:4], STATES[4:8]):
        sizes = [solid[name] for name in group]
        if any(b < a + 40 for a, b in zip(sizes, sizes[1:])):
            problems.append('%s: sizes do not grow: %s' % (group[0], sizes))
    board = states[4][2][0]
    if board.getchannel('A').getbbox() != (2, 11, 30, 24):
        problems.append('particle_board: not on the resin_laminate footprint')
    for name in ('particle_floor', 'particle_floor_swollen'):
        px = dict(zip(STATES, (s[2][0] for s in states)))[name].load()
        # four identical-layout sheets: seams on x, y = 0 and 16 only, so it wraps
        seam = [px[x, 0][:3] for x in range(SIZE)] + [px[0, y][:3] for y in range(SIZE)]
        field = [px[x, y][:3] for y in (5, 9, 21, 27) for x in range(3, 14)]
        if sum(map(sum, seam)) / len(seam) >= sum(map(sum, field)) / len(field):
            problems.append('%s: seams are not darker than the sheets' % name)
    images = dict(zip(STATES, (s[2][0] for s in states)))
    for dry, wet in (('particle_board_2', 'particle_board_swollen'),
                     ('particle_wall', 'particle_wall_swollen'),
                     ('particle_floor', 'particle_floor_swollen')):
        stained = sum(p[3] == 255 and p[:3] in WET for p in pixels(images[wet]))
        if stained < 60 or any(p[:3] in WET for p in pixels(images[dry]) if p[3]):
            problems.append('%s: water stain is missing or on the dry state' % wet)
    wall_px = images['particle_wall_swollen'].load()
    dry_px = images['particle_wall'].load()
    if any(wall_px[x, y] != dry_px[x, y] for y in range(0, 18) for x in range(SIZE)):
        problems.append('particle_wall_swollen: damage reaches the top of the wall')
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


def dmi_state(path, wanted):
    """First frame of one state of another sheet, or None."""
    path = Path(path)
    if not path.exists():
        return None
    sheet = Image.open(path)
    index = 0
    name = None
    counts = {}
    order = []
    for line in sheet.info.get('Description', '').splitlines():
        line = line.strip()
        if line.startswith('state = '):
            name = line.split('"')[1]
            order.append(name)
            counts[name] = [1, 1]
        elif name and line.startswith('dirs = '):
            counts[name][0] = int(line.split('=')[1])
        elif name and line.startswith('frames = '):
            counts[name][1] = int(line.split('=')[1])
    sheet = sheet.convert('RGBA')
    cols = sheet.width // SIZE
    for name in order:
        if name == wanted:
            x, y = (index % cols) * SIZE, (index // cols) * SIZE
            return sheet.crop((x, y, x + SIZE, y + SIZE))
        index += counts[name][0] * counts[name][1]
    return None


def ground(tone, seed):
    im = Image.new('RGBA', (SIZE, SIZE))
    px = im.load()
    for y in range(SIZE):
        for x in range(SIZE):
            v = noise(x, y, seed)
            shift = -10 if v < 0.16 else 8 if v > 0.9 else 0
            px[x, y] = tuple(c + shift for c in tone) + (255,)
    return im


def write_preview(path, states, scale=4):
    """Every state on grass, dirt and planks at 4x, the floors tiled 3x3 and the
    walls beside b_wood_wall, with a 1x row of the states underneath."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    images = dict(zip(STATES, (s[2][0] for s in states)))
    planks = dmi_state(ROOT / 'icons/turf/flooring/wood.dmi', 'wood') or ground((81, 43, 15), 3)
    grounds = (ground((84, 124, 62), 1), ground((121, 88, 58), 2), planks)
    cols = len(STATES)
    rows = len(grounds) + 3
    small = Image.new('RGBA', (SIZE * cols, SIZE * rows), (32, 32, 32, 255))
    for r, tile in enumerate(grounds):
        for c, name in enumerate(STATES):
            small.alpha_composite(tile, (c * SIZE, r * SIZE))
            small.alpha_composite(images[name], (c * SIZE, r * SIZE))
    top = len(grounds) * SIZE
    for n, name in enumerate(('particle_floor', 'particle_floor_swollen')):
        for ty in range(3):
            for tx in range(3):
                small.alpha_composite(images[name], ((n * 3 + tx) * SIZE + n * 8, top + ty * SIZE))
    # a room corner: walls standing on the plank floor beside the game's wooden walls
    row = ['b_wood_wall', 'particle_wall', 'particle_wall_swollen', 'new_wood0', 'particle_wall']
    for n, name in enumerate(row):
        tile = images.get(name) or dmi_state(ROOT / 'icons/turf/walls.dmi', name) or planks
        x = (7 + n) * SIZE
        small.alpha_composite(tile, (x, top))
        small.alpha_composite(planks, (x, top + SIZE))
        small.alpha_composite(images['particle_floor'], (x, top + 2 * SIZE))
    small = small.convert('RGB')
    sheet = Image.new('RGB', (small.width * scale, small.height * scale + SIZE), (32, 32, 32))
    sheet.paste(small.resize((small.width * scale, small.height * scale), Image.NEAREST), (0, 0))
    sheet.paste(small.crop((0, 0, small.width, SIZE)), (0, small.height * scale))
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
        print('particle board: %s' % ('FAILED' if problems else 'ok'))
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
