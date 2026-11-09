#!/usr/bin/env python3
"""Make and edit terrain height files (docs/terrain-height.md).

A height file gives one level (0-15, written 0-9 then a-f) per tile of one or
more z-levels. The game reads it when a map sets terrain_height_file.

  generate  build heights for a .dmm level from its turfs (water low, land
            rising inland, ridges near rock walls, seeded noise)
  to-png    write a greyscale PNG of a height file, one pixel per tile
  from-png  turn a painted greyscale PNG back into a height file
  check     validate a height file against a .dmm's size
  bake-shading  write the slope shading sprites (icons/turf/terrain_shade.dmi)

Needs numpy and Pillow.
"""
import argparse
import re
import sys
from collections import deque
from pathlib import Path

HEADER = 'civ13-terrain-heights 1'
DIGITS = '0123456789abcdef'
MAX_LEVEL = 15
# Neighbouring tiles differ by at most this many levels after generation.
MAX_NEIGHBOUR_STEP = 2


def load_numpy():
    try:
        import numpy
    except ImportError:
        sys.exit('terrain_heights.py needs numpy (pip install numpy)')
    return numpy


def read_dmm(path):
    """Return (maxx, maxy, {z: rows of turf paths, north row first}) for a standard .dmm."""
    text = Path(path).read_text(encoding='utf-8')
    if text.startswith('//MAP CONVERTED BY dmm2tgm'):
        sys.exit('TGM maps are not supported; convert to the standard format first')
    keys = {}
    for match in re.finditer(r'^"(\w+)" = \((.*)\)$', text, re.M):
        turf = re.search(r'/turf/[\w/]+', match.group(2))
        keys[match.group(1)] = turf.group(0) if turf else ''
    if not keys:
        sys.exit(f'{path}: no dictionary entries found')
    width = len(next(iter(keys)))
    levels = {}
    for x, y, z, body in re.findall(r'^\((\d+),(\d+),(\d+)\) = \{"\n(.*?)\n"\}', text, re.M | re.S):
        if x != '1' or y != '1':
            sys.exit(f'{path}: only whole-level blocks starting at (1,1) are supported')
        rows = []
        for line in body.split('\n'):
            rows.append([keys[line[i:i + width]] for i in range(0, len(line), width)])
        levels[int(z)] = rows
    if not levels:
        sys.exit(f'{path}: no map blocks found')
    first = next(iter(levels.values()))
    return len(first[0]), len(first), levels


def classify(turf):
    """0 water, 1 shore, 2 land, 3 rock wall."""
    if 'rockwall' in turf or turf.startswith('/turf/wall/rock'):
        return 3
    if 'water' in turf or 'lava' in turf:
        return 0
    if 'beach' in turf or 'sand' in turf:
        return 1
    return 2


def distance_from(np, mask):
    """4-neighbour BFS distance (in tiles) from True cells; large where none."""
    h, w = mask.shape
    dist = np.full((h, w), 10 ** 6, dtype=np.int64)
    queue = deque()
    for y, x in zip(*np.nonzero(mask)):
        dist[y, x] = 0
        queue.append((y, x))
    while queue:
        y, x = queue.popleft()
        d = dist[y, x] + 1
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < h and 0 <= nx < w and dist[ny, nx] > d:
                dist[ny, nx] = d
                queue.append((ny, nx))
    return dist


def limit_steps(np, levels, fixed):
    """Lower tiles until no neighbour pair differs by more than MAX_NEIGHBOUR_STEP."""
    while True:
        p = np.pad(levels, 1, mode='edge')
        lowest = np.minimum.reduce([p[:-2, 1:-1], p[2:, 1:-1], p[1:-1, :-2], p[1:-1, 2:]])
        cap = np.where(fixed, levels, np.minimum(levels, lowest + MAX_NEIGHBOUR_STEP))
        if np.array_equal(cap, levels):
            return levels
        levels = cap


def octave(np, rng, shape, scale, amplitude):
    """Smooth noise: a coarse random grid scaled up with bicubic filtering."""
    from PIL import Image
    h, w = shape
    gh, gw = h // scale + 3, w // scale + 3
    grid = Image.fromarray(rng.standard_normal((gh, gw)).astype(np.float32))
    return np.array(grid.resize((gw * scale, gh * scale), Image.BICUBIC))[:h, :w] * amplitude


def generate(np, rows, seed):
    """Rounded hills on gently rising land: water 0, beaches at most 1."""
    cls = np.array([[classify(t) for t in row] for row in rows])
    water = cls == 0
    rock = cls == 3
    rng = np.random.default_rng(seed)
    noise = (octave(np, rng, cls.shape, 28, 1.0) + octave(np, rng, cls.shape, 14, 0.5)
             + octave(np, rng, cls.shape, 7, 0.22))
    inland = np.minimum(distance_from(np, water), 12) / 12.0 if water.any() else np.ones(cls.shape)
    ridge = np.clip(1 - distance_from(np, rock) / 6.0, 0, 1) if rock.any() else np.zeros(cls.shape)
    hills = np.clip(noise - 0.25, 0, None)
    height = hills * 9 * np.minimum(inland * 2, 1) + inland * 1.5 + ridge * 3
    height[water] = 0
    height[cls == 1] = np.minimum(height[cls == 1], 1)
    levels = np.clip(np.round(height), 0, MAX_LEVEL).astype(int)
    levels[water] = 0
    return limit_steps(np, levels, water)


def write_heights(path, maxx, maxy, levels_by_z):
    lines = [HEADER, f'size {maxx} {maxy}']
    for z in sorted(levels_by_z):
        lines.append(f'z {z}')
        lines.extend(''.join(DIGITS[int(v)] for v in row) for row in levels_by_z[z])
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text('\n'.join(lines) + '\n', encoding='ascii', newline='\n')


def read_heights(path):
    """Return (maxx, maxy, {z: list of int rows}); raises ValueError like the game does."""
    lines = Path(path).read_text(encoding='ascii').replace('\r', '').split('\n')
    if lines[0] != HEADER:
        raise ValueError(f"missing '{HEADER}' header")
    size = lines[1].split(' ') if len(lines) > 1 else []
    if len(size) != 3 or size[0] != 'size':
        raise ValueError("missing 'size X Y' line")
    maxx, maxy = int(size[1]), int(size[2])
    levels, i = {}, 2
    while i < len(lines):
        line = lines[i]
        i += 1
        if not line:
            continue
        parts = line.split(' ')
        if len(parts) != 2 or parts[0] != 'z' or not parts[1].isdigit() or int(parts[1]) in levels:
            raise ValueError(f"bad or repeated z line '{line}'")
        z = int(parts[1])
        rows = lines[i:i + maxy]
        i += maxy
        if len(rows) != maxy:
            raise ValueError(f'z {z} has {len(rows)} of {maxy} rows')
        for r, row in enumerate(rows, 1):
            if len(row) != maxx or any(c not in DIGITS for c in row):
                raise ValueError(f'z {z} row {r} must be {maxx} characters of 0-9 or a-f')
        levels[z] = [[DIGITS.index(c) for c in row] for row in rows]
    if not levels:
        raise ValueError('no z levels')
    return maxx, maxy, levels


# Slope shading. The game computes a light level (-2..2) at every tile corner
# from the heights (terrain_height.dm, terrain_corner_light), and each tile
# shows the sprite for its four corner levels, blended across the tile, so
# neighbouring tiles join without seams. Keep the two in step.
LIGHT = (-1.0, -1.0, 1.2)        # from the north-west, above
RELIEF = 1.6                     # vertical exaggeration of one level
LIGHT_STEP = 0.22                # intensity per light level
SHADE_KEYS = 'abcde'             # light level -2..2
DARK_ALPHA = 0.30
LIGHT_ALPHA = 0.24
LIGHT_COLOUR = (255, 247, 224)


def corner_lights(np, levels):
    """Light level -2..2 at each corner of a north-first level grid, shape (h + 1, w + 1)."""
    p = np.pad(np.asarray(levels, dtype=float), 1, mode='edge')
    corners = (p[:-1, :-1] + p[1:, :-1] + p[:-1, 1:] + p[1:, 1:]) / 4
    q = np.pad(corners, 1, mode='edge')
    gx = (q[1:-1, 2:] - q[1:-1, :-2]) / 2
    gy = (q[2:, 1:-1] - q[:-2, 1:-1]) / 2
    length = (LIGHT[0] ** 2 + LIGHT[1] ** 2 + LIGHT[2] ** 2) ** 0.5
    lx, ly, lz = (c / length for c in LIGHT)
    nx, ny = -gx * RELIEF, -gy * RELIEF
    intensity = (nx * lx + ny * ly + lz) / np.sqrt(nx * nx + ny * ny + 1) - lz
    return np.clip(np.floor(intensity / LIGHT_STEP + 0.5), -2, 2).astype(int)


def shade_pixels(np, key, size=32):
    """RGBA pixels for one shading state: key = light levels at nw, ne, sw, se."""
    nw, ne, sw, se = (SHADE_KEYS.index(c) - 2 for c in key)
    t = (np.arange(size) + 0.5) / size
    tx, ty = t[None, :], t[:, None]
    v = (nw * (1 - tx) * (1 - ty) + ne * tx * (1 - ty) + sw * (1 - tx) * ty + se * tx * ty) / 2
    out = np.zeros((size, size, 4), dtype=np.uint8)
    dark = v < 0
    out[dark, 3] = np.round(-v[dark] * DARK_ALPHA * 255)
    light = v > 0
    out[light, :3] = LIGHT_COLOUR
    out[light, 3] = np.round(v[light] * LIGHT_ALPHA * 255)
    return out


def shade_states():
    keys = [a + b + c + d for a in SHADE_KEYS for b in SHADE_KEYS for c in SHADE_KEYS for d in SHADE_KEYS]
    return [k for k in keys if k != 'cccc']


def cmd_bake_shading(args):
    np = load_numpy()
    from PIL import Image
    from PIL.PngImagePlugin import PngInfo
    states = shade_states()
    cols = 25
    rows = -(-len(states) // cols)
    sheet = np.zeros((rows * 32, cols * 32, 4), dtype=np.uint8)
    for i, key in enumerate(states):
        y, x = divmod(i, cols)
        sheet[y * 32:(y + 1) * 32, x * 32:(x + 1) * 32] = shade_pixels(np, key)
    lines = ['# BEGIN DMI', 'version = 4.0', '\twidth = 32', '\theight = 32']
    for key in states:
        lines += [f'state = "{key}"', '\tdirs = 1', '\tframes = 1']
    lines.append('# END DMI')
    info = PngInfo()
    info.add_text('Description', '\n'.join(lines) + '\n', zip=True)
    Image.fromarray(sheet, 'RGBA').save(args.out, format='PNG', pnginfo=info, optimize=True)
    print(f'wrote {args.out}: {len(states)} states')


def cmd_generate(args):
    np = load_numpy()
    maxx, maxy, levels = read_dmm(args.map)
    out = {}
    for z in args.z:
        if z not in levels:
            sys.exit(f'{args.map} has no z {z}')
        out[z] = generate(np, levels[z], args.seed + z).tolist()
    write_heights(args.out, maxx, maxy, out)
    print(f'wrote {args.out}: {maxx}x{maxy}, z {", ".join(map(str, sorted(out)))}')


def cmd_to_png(args):
    from PIL import Image
    maxx, maxy, levels = read_heights(args.heights)
    rows = levels[args.z]
    image = Image.new('L', (maxx, maxy))
    image.putdata([v * 17 for row in rows for v in row])
    image.save(args.out)
    print(f'wrote {args.out}')


def cmd_from_png(args):
    from PIL import Image
    image = Image.open(args.png).convert('L')
    maxx, maxy = image.size
    data = list(image.getdata())
    rows = [[min(MAX_LEVEL, round(data[y * maxx + x] / 17)) for x in range(maxx)] for y in range(maxy)]
    existing = {}
    if Path(args.out).exists():
        old_x, old_y, existing = read_heights(args.out)
        if (old_x, old_y) != (maxx, maxy):
            sys.exit(f'{args.png} is {maxx}x{maxy} but {args.out} is {old_x}x{old_y}')
    existing[args.z] = rows
    write_heights(args.out, maxx, maxy, existing)
    print(f'wrote z {args.z} of {args.out}')


def cmd_check(args):
    try:
        maxx, maxy, levels = read_heights(args.heights)
    except ValueError as error:
        sys.exit(f'{args.heights}: {error}')
    if args.map:
        map_x, map_y, map_levels = read_dmm(args.map)
        if (map_x, map_y) != (maxx, maxy):
            sys.exit(f'{args.heights} is {maxx}x{maxy} but {args.map} is {map_x}x{map_y}')
        missing = sorted(set(levels) - set(map_levels))
        if missing:
            sys.exit(f'{args.heights} names z {missing} that {args.map} does not have')
    counts = {z: sum(v > 0 for row in rows for v in row) for z, rows in levels.items()}
    print(f'{args.heights}: {maxx}x{maxy}, raised tiles per z {counts}')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='command', required=True)
    g = sub.add_parser('generate')
    g.add_argument('--map', required=True)
    g.add_argument('--z', type=int, action='append', required=True)
    g.add_argument('--out', required=True)
    g.add_argument('--seed', type=int, default=13)
    g.set_defaults(func=cmd_generate)
    t = sub.add_parser('to-png')
    t.add_argument('--heights', required=True)
    t.add_argument('--z', type=int, required=True)
    t.add_argument('--out', required=True)
    t.set_defaults(func=cmd_to_png)
    f = sub.add_parser('from-png')
    f.add_argument('--png', required=True)
    f.add_argument('--z', type=int, required=True)
    f.add_argument('--out', required=True)
    f.set_defaults(func=cmd_from_png)
    c = sub.add_parser('check')
    c.add_argument('--heights', required=True)
    c.add_argument('--map')
    c.set_defaults(func=cmd_check)
    b = sub.add_parser('bake-shading')
    b.add_argument('--out', default='icons/turf/terrain_shade.dmi')
    b.set_defaults(func=cmd_bake_shading)
    args = parser.parse_args(argv)
    args.func(args)


if __name__ == '__main__':
    main()
