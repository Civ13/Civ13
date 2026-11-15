#!/usr/bin/env python3
"""Build a river flood sidecar (docs/river-flood.md) from a map and its heights.

Fresh water is cut into reaches: one connected body of fresh water inside one
32x32 cell. Each reach drains to the next reach toward the sea (or to nothing,
for a closed lake). A priority flood from all water gives every land tile the
reach it floods from and its threshold: the lowest river stage, in levels above
the water, that reaches it over the ground. Land that floods from the sea first
belongs to no reach and never floods from a river.

Hollows are closed basins on land: ground below the level water must reach to
spill out of them. Rain pools there whatever the river does. Each hollow lists
its spill level, its tiles' heights and its catchment (the land whose water
runs into it, from the priority flood's drainage tree).

    python3 scripts/river_flood.py --map maps/nomads/nomads_gaia.dmm --z 2 \\
        --heights maps/heights/nomads_gaia.txt --out maps/heights/nomads_gaia.flood.txt
"""
import argparse
import heapq
import sys
from collections import deque
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from terrain_heights import DIGITS, read_dmm, read_heights  # noqa: E402
from river_flow import classify  # noqa: E402

HEADER = 'civ13-river-flood 2'
OLD_HEADERS = ('civ13-river-flood 1',)
CELL = 32
# Two characters per tile name a reach: 64 * 64 ids, 0 meaning none.
ID_DIGITS = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_'
MAX_REACHES = len(ID_DIGITS) ** 2 - 1
NONE = '.'
CARDINALS = ((0, -1), (1, 0), (0, 1), (-1, 0))
# Fresh water bodies smaller than this many tiles are not reaches.
MIN_WATER = 6
# Hollows smaller or shallower than this are left out; at most MAX_HOLLOWS,
# the largest by the water they hold.
MIN_HOLLOW_AREA = 3
MIN_HOLLOW_DEPTH = 0.5
MAX_HOLLOWS = MAX_REACHES


def encode_id(i):
    return ID_DIGITS[i // 64] + ID_DIGITS[i % 64]


def build(rows, heights):
    """rows: north-first turf paths; heights: north-first levels, same size.

    Returns (reaches, labels, thresholds): reaches is a list of dicts in id
    order (id 1 first, every reach before the one it drains to); labels holds
    reach ids per tile (0 none); thresholds holds a level or None."""
    h, w = len(rows), len(rows[0])
    kinds = [[classify(t) for t in row] for row in rows]
    fresh = [[k in ('fresh', 'still') for k in row] for row in kinds]
    salt = [[k == 'salt' for k in row] for row in kinds]

    # Reaches: connected fresh water, cut by the cell grid.
    comp = [[0] * w for _ in range(h)]
    count = 0
    for sy in range(h):
        for sx in range(w):
            if fresh[sy][sx] and not comp[sy][sx]:
                count += 1
                comp[sy][sx] = count
                queue = deque([(sx, sy)])
                while queue:
                    x, y = queue.popleft()
                    for dx, dy in CARDINALS:
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and fresh[ny][nx] and not comp[ny][nx]:
                            comp[ny][nx] = count
                            queue.append((nx, ny))
    # Puddles too small to be a body of water are left to the land around them.
    sizes = [0] * (count + 1)
    for row in comp:
        for c in row:
            sizes[c] += 1
    for y in range(h):
        for x in range(w):
            if fresh[y][x] and sizes[comp[y][x]] < MIN_WATER:
                fresh[y][x] = False
                comp[y][x] = 0
    key_of = {}
    reach_tiles = {}
    for y in range(h):
        for x in range(w):
            if fresh[y][x]:
                key = (comp[y][x], y // CELL, x // CELL)
                key_of[(x, y)] = key
                reach_tiles.setdefault(key, []).append((x, y))

    # Distance over water to an outlet (salt water or the map edge); closed
    # components measure from their largest reach instead.
    dist = {}
    queue = deque()
    for (x, y) in key_of:
        edge = x in (0, w - 1) or y in (0, h - 1)
        near_salt = any(0 <= x + dx < w and 0 <= y + dy < h and salt[y + dy][x + dx] for dx, dy in CARDINALS)
        if edge or near_salt:
            dist[(x, y)] = 0
            queue.append((x, y))

    def spread(queue):
        while queue:
            x, y = queue.popleft()
            for dx, dy in CARDINALS:
                n = (x + dx, y + dy)
                if n in key_of and n not in dist:
                    dist[n] = dist[(x, y)] + 1
                    queue.append(n)
    spread(queue)
    by_comp = {}
    for key, tiles in reach_tiles.items():
        by_comp.setdefault(key[0], []).append(key)
    for c, keys in sorted(by_comp.items()):
        if any(t in dist for k in keys for t in reach_tiles[k]):
            continue
        root = max(keys, key=lambda k: (len(reach_tiles[k]), k))
        for t in reach_tiles[root]:
            dist[t] = 0
        spread(deque(reach_tiles[root]))

    # Each reach drains to the neighbouring reach nearest the outlet.
    low = {key: min(dist[t] for t in tiles) for key, tiles in reach_tiles.items()}
    down = {}
    for key, tiles in reach_tiles.items():
        best = None
        for (x, y) in tiles:
            for dx, dy in CARDINALS:
                other = key_of.get((x + dx, y + dy))
                if other and other != key and low[other] < low[key]:
                    candidate = (low[other], other)
                    if best is None or candidate < best:
                        best = candidate
        down[key] = best[1] if best else None
    # Upstream first: a reach always comes before the one it drains to.
    order = sorted(reach_tiles, key=lambda k: (-low[k], k))
    if len(order) > MAX_REACHES:
        raise ValueError(f'{len(order)} reaches is more than {MAX_REACHES}')
    ident = {key: i + 1 for i, key in enumerate(order)}

    # Priority flood from all water: each land tile's reach and threshold.
    labels = [[0] * w for _ in range(h)]
    level = [[None] * w for _ in range(h)]
    heap = []
    for y in range(h):
        for x in range(w):
            if fresh[y][x] or salt[y][x]:
                labels[y][x] = ident[key_of[(x, y)]] if fresh[y][x] else 0
                level[y][x] = 0
                heapq.heappush(heap, (0, 0 if fresh[y][x] else 1, y, x))
    parent = {}
    popped = []
    while heap:
        t, _, y, x = heapq.heappop(heap)
        popped.append((x, y))
        for dx, dy in CARDINALS:
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and level[ny][nx] is None:
                level[ny][nx] = max(t, heights[ny][nx])
                labels[ny][nx] = labels[y][x]
                parent[(nx, ny)] = (x, y)
                heapq.heappush(heap, (level[ny][nx], 0 if labels[y][x] else 1, ny, nx))
    thresholds = [[None] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if labels[y][x] and not fresh[y][x] and level[y][x] is not None:
                thresholds[y][x] = level[y][x]

    reaches = []
    sums = {i: [0, 0, 0] for i in range(1, len(order) + 1)}
    for y in range(h):
        for x in range(w):
            r = labels[y][x]
            if r:
                s = sums[r]
                s[0] += 1
                s[1] += x + 1
                s[2] += h - y
    for key in order:
        i = ident[key]
        n, sx, sy = sums[i]
        reaches.append({'id': i, 'down': ident[down[key]] if down[key] else 0,
                        'x': round(sx / n), 'y': round(sy / n), 'area': n, 'upstream': n,
                        'water': len(reach_tiles[key])})
    for r in reaches:
        if r['down']:
            reaches[r['down'] - 1]['upstream'] += r['upstream']
    water = [[fresh[y][x] or salt[y][x] for x in range(w)] for y in range(h)]
    hollows, hollow_ids = find_hollows(heights, level, water, parent, popped)
    return reaches, labels, thresholds, hollows, hollow_ids


def find_hollows(heights, level, water, parent, popped):
    """Closed basins: connected land tiles below the same spill level.

    Returns (hollows, ids): hollows is a list of dicts in id order, ids holds a
    hollow id per tile (0 none)."""
    h, w = len(heights), len(heights[0])
    # Tiles drain to their parent in the priority flood; a tile's subtree is
    # the land whose water runs through it.
    size = {}
    for t in reversed(popped):
        size[t] = size.get(t, 0) + 1
        p = parent.get(t)
        if p is not None:
            size[p] = size.get(p, 0) + size[t]
    comp = [[0] * w for _ in range(h)]
    found = []
    for sy in range(h):
        for sx in range(w):
            spill = level[sy][sx]
            if water[sy][sx] or comp[sy][sx] or spill is None or spill <= heights[sy][sx]:
                continue
            index = len(found) + 1
            comp[sy][sx] = index
            tiles = [(sx, sy)]
            queue = deque(tiles)
            while queue:
                x, y = queue.popleft()
                for dx, dy in CARDINALS:
                    nx, ny = x + dx, y + dy
                    if (0 <= nx < w and 0 <= ny < h and not comp[ny][nx] and not water[ny][nx]
                            and level[ny][nx] == spill and spill > heights[ny][nx]):
                        comp[ny][nx] = index
                        tiles.append((nx, ny))
                        queue.append((nx, ny))
            found.append((spill, tiles))
    kept = []
    for index, (spill, tiles) in enumerate(found, 1):
        ground = [heights[y][x] for x, y in tiles]
        bottom = min(ground)
        if len(tiles) < MIN_HOLLOW_AREA or spill - bottom < MIN_HOLLOW_DEPTH:
            continue
        inside = set(tiles)
        catchment = sum(size.get(t, 1) for t in tiles if parent.get(t) not in inside)
        steps = int(round((spill - bottom) * 2))
        hist = [0] * steps
        for g in ground:
            hist[int(round((g - bottom) * 2))] += 1
        kept.append({'index': index, 'spill': spill, 'bottom': bottom, 'area': len(tiles),
                     'catchment': max(catchment, len(tiles)), 'hist': hist,
                     'capacity': sum(spill - g for g in ground), 'tiles': tiles})
    kept.sort(key=lambda o: (-o['capacity'], o['index']))
    kept = kept[:MAX_HOLLOWS]
    kept.sort(key=lambda o: o['index'])
    ids = [[0] * w for _ in range(h)]
    hollows = []
    for i, o in enumerate(kept, 1):
        sx = sum(x for x, _ in o['tiles'])
        sy = sum(y for _, y in o['tiles'])
        n = o['area']
        for x, y in o['tiles']:
            ids[y][x] = i
        hollows.append({'id': i, 'spill': o['spill'], 'x': round(sx / n) + 1, 'y': h - round(sy / n),
                        'area': n, 'catchment': o['catchment'], 'bottom': o['bottom'], 'hist': o['hist']})
    return hollows, ids


def write_flood(path, width, height, z, reaches, labels, thresholds, hollows=(), hollow_ids=None):
    lines = [HEADER, f'size {width} {height}', f'z {z}', f'reaches {len(reaches)}']
    for r in reaches:
        lines.append(f"r {r['id']} {r['down']} {r['x']} {r['y']} {r['area']} {r['upstream']} {r['water']}")
    lines.extend(''.join(encode_id(v) for v in row) for row in labels)
    lines.extend(''.join(NONE if v is None else DIGITS[int(round(v * 2))] for v in row) for row in thresholds)
    # Hollows: one line each, then only the rows (north first, 1-based) that hold one.
    lines.append(f'hollows {len(hollows)}')
    for o in hollows:
        lines.append(f"h {o['id']} {DIGITS[int(round(o['spill'] * 2))]} {DIGITS[int(round(o['bottom'] * 2))]} "
                     f"{o['x']} {o['y']} {o['area']} {o['catchment']} {','.join(map(str, o['hist']))}")
    rows = [(i, row) for i, row in enumerate(hollow_ids or [], 1) if any(row)]
    lines.append(f'hollow_rows {len(rows)}')
    lines.extend(f"{i} {''.join(encode_id(v) for v in row)}" for i, row in rows)
    Path(path).write_text('\n'.join(lines) + '\n', encoding='ascii', newline='\n')


def read_flood(path):
    """Return (width, height, z, reaches, labels, thresholds) as build() made them."""
    lines = Path(path).read_text(encoding='ascii').split('\n')
    if lines[0] != HEADER and lines[0] not in OLD_HEADERS:
        raise ValueError(f"missing '{HEADER}' header")
    width, height = map(int, lines[1].split()[1:])
    z = int(lines[2].split()[1])
    n = int(lines[3].split()[1])
    reaches = []
    for line in lines[4:4 + n]:
        _, i, d, x, y, area, up, water = line.split()
        reaches.append({'id': int(i), 'down': int(d), 'x': int(x), 'y': int(y), 'area': int(area),
                        'upstream': int(up), 'water': int(water)})
    start = 4 + n
    labels = [[ID_DIGITS.index(row[i]) * 64 + ID_DIGITS.index(row[i + 1]) for i in range(0, 2 * width, 2)]
              for row in lines[start:start + height]]
    level = {c: i / 2 for i, c in enumerate(DIGITS)}
    thresholds = [[None if c == NONE else level[c] for c in row] for row in lines[start + height:start + 2 * height]]
    return width, height, z, reaches, labels, thresholds


def read_hollows(path):
    """Return (hollows, ids) from a sidecar; none for a version 1 file."""
    width, height, _, reaches, _, _ = read_flood(path)
    lines = Path(path).read_text(encoding='ascii').split('\n')
    at = 4 + len(reaches) + 2 * height
    ids = [[0] * width for _ in range(height)]
    if at >= len(lines) or not lines[at].startswith('hollows '):
        return [], ids
    level = {c: i / 2 for i, c in enumerate(DIGITS)}
    n = int(lines[at].split()[1])
    hollows = []
    for line in lines[at + 1:at + 1 + n]:
        _, i, spill, bottom, x, y, area, catchment, hist = line.split()
        hollows.append({'id': int(i), 'spill': level[spill], 'bottom': level[bottom], 'x': int(x), 'y': int(y),
                        'area': int(area), 'catchment': int(catchment), 'hist': [int(v) for v in hist.split(',')]})
    at += 1 + n
    rows = int(lines[at].split()[1])
    for line in lines[at + 1:at + 1 + rows]:
        r, text = line.split(' ', 1)
        ids[int(r) - 1] = [ID_DIGITS.index(text[i]) * 64 + ID_DIGITS.index(text[i + 1]) for i in range(0, 2 * width, 2)]
    return hollows, ids


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--map', required=True)
    parser.add_argument('--z', type=int, required=True)
    parser.add_argument('--heights', required=True)
    parser.add_argument('--out', required=True)
    args = parser.parse_args(argv)
    width, height, levels = read_dmm(args.map)
    hx, hy, by_z = read_heights(args.heights)
    if (hx, hy) != (width, height) or args.z not in by_z or args.z not in levels:
        sys.exit(f'{args.heights} does not match z {args.z} of {args.map}')
    reaches, labels, thresholds, hollows, hollow_ids = build(levels[args.z], by_z[args.z])
    write_flood(args.out, width, height, args.z, reaches, labels, thresholds, hollows, hollow_ids)
    land = sum(1 for row in thresholds for v in row if v is not None)
    pooled = sum(o['area'] for o in hollows)
    print(f'{args.out}: {len(reaches)} reaches, {land} land tiles flood from a river, '
          f'{len(hollows)} hollows over {pooled} tiles')


if __name__ == '__main__':
    main()
