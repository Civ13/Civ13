#!/usr/bin/env python3
"""Make and edit terrain height files (docs/terrain-height.md).

A height file gives one level (0-15, written 0-9 then a-f) per tile of one or
more z-levels. The game reads it when a map sets terrain_height_file.

  generate  build heights for a .dmm level from its turfs (water low, land
            rising inland, ridges near rock walls, seeded noise)
  to-png    write a greyscale PNG of a height file, one pixel per tile
  from-png  turn a painted greyscale PNG back into a height file
  check     validate a height file against a .dmm's size

Needs numpy; PNG commands also need Pillow.
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


def blur(np, a, radius):
    """Repeated 3x3 box blur, edges clamped."""
    for _ in range(radius):
        p = np.pad(a, 1, mode='edge')
        a = sum(p[dy:dy + a.shape[0], dx:dx + a.shape[1]] for dy in range(3) for dx in range(3)) / 9.0
    return a


def limit_steps(np, levels, fixed):
    """Lower tiles until no neighbour pair differs by more than MAX_NEIGHBOUR_STEP."""
    while True:
        p = np.pad(levels, 1, mode='edge')
        lowest = np.minimum.reduce([p[:-2, 1:-1], p[2:, 1:-1], p[1:-1, :-2], p[1:-1, 2:]])
        cap = np.where(fixed, levels, np.minimum(levels, lowest + MAX_NEIGHBOUR_STEP))
        if np.array_equal(cap, levels):
            return levels
        levels = cap


def generate(np, rows, seed):
    cls = np.array([[classify(t) for t in row] for row in rows])
    water = cls == 0
    rock = cls == 3
    rng = np.random.default_rng(seed)
    inland = np.minimum(distance_from(np, water), 16) if water.any() else np.full(cls.shape, 8)
    height = inland * 0.5
    height = height + blur(np, rng.standard_normal(cls.shape), 6) * 14
    height = height + blur(np, rock.astype(float), 3) * 8
    height = blur(np, height, 2)
    height[water] = 0
    height[cls == 1] = np.minimum(height[cls == 1], 1)
    levels = np.clip(np.round(height / 1.6), 0, MAX_LEVEL).astype(int)
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
    args = parser.parse_args(argv)
    args.func(args)


if __name__ == '__main__':
    main()
