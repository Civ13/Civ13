#!/usr/bin/env python3
"""Give one edge of a hand-drawn map a sea coast (docs/map-coasts.md).

Ships cross between lands by arriving on deep salt water at a map edge
(code/modules/naval/ship_crossing.dm). A land-locked map has none, so no ship
can make landfall there. This replaces a band along one edge of one level with
open sea: deep water from the edge, a strip of shallows, then a beach, along a
wavy coastline with a few bays. Everything standing in the new water is
removed; fresh water that reaches the beach is kept, so rivers run out to sea.

    python3 scripts/map_coast.py --map maps/nomads/nomads_desert.dmm --z 2 \\
        --side N --land-area /area/caribbean/nomads/desert --seed desert

The edit is deterministic for a given map, side and seed. Afterwards rebuild
the map's height, current and flood files (docs/terrain-height.md,
docs/river-flow.md, docs/river-flood.md). Standard library only.
"""
import argparse
import hashlib
import itertools
import math
import re
import string
import sys
from pathlib import Path

DEEP = '/turf/floor/beach/water/deep/saltwater'
SHALLOW = '/turf/floor/beach/water/shallowsaltwater'
SEA_AREA = '/area/caribbean/sea/sea'
SHALLOW_WIDTH = 4
BEACH_WIDTH = 3
KEEP = ('/obj/map_metadata', '/obj/effect/landmark')


def split_tile(body):
    """Splits a dictionary entry's body into its paths, keeping {vars} whole."""
    parts, depth, quote, start = [], 0, False, 0
    for i, ch in enumerate(body):
        if ch == '"':
            quote = not quote
        elif not quote and ch in '{(':
            depth += 1
        elif not quote and ch in '})':
            depth -= 1
        elif not quote and ch == ',' and depth == 0:
            parts.append(body[start:i])
            start = i + 1
    parts.append(body[start:])
    return [p.strip() for p in parts]


def coastline(length, seed, mean, swing):
    """Distance of the waterline from the edge at each position along it."""
    digest = hashlib.sha256(seed.encode()).digest()
    waves = []
    for n, period in enumerate((length / 1.3, length / 2.9, length / 6.1, 23.0)):
        phase = digest[n] / 255 * 2 * math.pi
        waves.append((2 * math.pi / period, phase, (1.0, 0.6, 0.35, 0.15)[n]))
    total = sum(w[2] for w in waves)
    return [mean + swing * sum(a * math.sin(f * t + p) for f, p, a in waves) / total for t in range(length)]


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--map', required=True, type=Path)
    parser.add_argument('--z', required=True, type=int)
    parser.add_argument('--side', required=True, choices='NSEW')
    parser.add_argument('--land-area', required=True, help='area for new beach that was roofed or sea before')
    parser.add_argument('--beach', default='/turf/floor/beach/sand')
    parser.add_argument('--seed', required=True)
    parser.add_argument('--mean', type=int, default=30, help='mean distance of the waterline from the edge')
    parser.add_argument('--swing', type=int, default=7, help='how far bays and headlands move it')
    parser.add_argument('--dry-run', action='store_true', help='report what would change, write nothing')
    args = parser.parse_args(argv)

    text = args.map.read_text(encoding='utf-8')
    newline = '\r\n' if '\r\n' in text else '\n'
    lines = text.split(newline)
    tiles, order = {}, []
    grid_start = None
    for index, line in enumerate(lines):
        match = re.match(r'^"(\w+)" = \((.*)\)$', line)
        if match:
            tiles[match.group(1)] = match.group(2)
            order.append(match.group(1))
        elif line.startswith('('):
            grid_start = index
            break
    width = len(order[0])
    original_count = len(order)
    first_entry = next(i for i, line in enumerate(lines) if re.match(r'^"\w+" = \(', line))
    # One entry per line, in one run, then the level blocks.
    assert all(re.match(r'^"\w+" = \(', line) for line in lines[first_entry:first_entry + original_count])
    assert grid_start is not None and grid_start >= first_entry + original_count
    header = '(1,1,%d) = {"' % args.z
    start = lines.index(header) + 1
    end = start
    while lines[end] != '"}':
        end += 1
    rows = [[line[i:i + width] for i in range(0, len(line), width)] for line in lines[start:end]]
    maxy, maxx = len(rows), len(rows[0])

    along = maxx if args.side in 'NS' else maxy
    line_at = coastline(along, args.seed, args.mean, args.swing)
    by_body = {body: key for key, body in tiles.items()}
    alphabet = string.ascii_lowercase + string.ascii_uppercase
    spare = (''.join(k) for k in itertools.product(alphabet, repeat=width))

    def key_for(body):
        if body not in by_body:
            for candidate in spare:
                if candidate not in tiles:
                    break
            tiles[candidate] = body
            order.append(candidate)
            by_body[body] = candidate
        return by_body[body]

    counts = {'deep': 0, 'shallow': 0, 'beach': 0, 'kept water': 0}
    removed, moved = {}, []
    for row in range(maxy):
        for col in range(maxx):
            depth = {'N': row, 'S': maxy - 1 - row, 'W': col, 'E': maxx - 1 - col}[args.side]
            shore = line_at[col if args.side in 'NS' else row]
            if depth >= shore + BEACH_WIDTH:
                continue
            parts = split_tile(tiles[rows[row][col]])
            turf = next(p for p in parts if p.startswith('/turf'))
            area = next(p for p in parts if p.startswith('/area'))
            extras = [p for p in parts if not p.startswith(('/turf', '/area'))]
            kept = [p for p in extras if p.startswith(KEEP)]
            if depth < shore - SHALLOW_WIDTH:
                kind, new = 'deep', [DEEP, SEA_AREA]
            elif depth < shore:
                kind, new = 'shallow', [SHALLOW, SEA_AREA]
            elif '/water' in turf and 'saltwater' not in turf:
                counts['kept water'] += 1
                continue
            else:
                roofed = '/void/caves' in area or area.startswith('/area/caribbean/sea')
                kind, new = 'beach', [args.beach, args.land_area if roofed else area]
            for path in extras:
                if path not in kept:
                    name = path.split('{')[0]
                    removed[name] = removed.get(name, 0) + 1
            if kept and kind != 'beach':
                moved.append((row, col, kept))
                kept = []
            counts[kind] += 1
            rows[row][col] = key_for(','.join(kept + new))

    # Start points and the map's control object that fell in the new sea come
    # ashore: straight inland to the first dry tile.
    step = {'N': (1, 0), 'S': (-1, 0), 'W': (0, 1), 'E': (0, -1)}[args.side]
    for row, col, kept in moved:
        while True:
            row, col = row + step[0], col + step[1]
            parts = split_tile(tiles[rows[row][col]])
            turf = next(p for p in parts if p.startswith('/turf'))
            if '/water' not in turf and '/wall' not in turf:
                break
        rows[row][col] = key_for(','.join(kept + parts))
        print('moved ashore to %d,%d: %s' % (col + 1, maxy - row, ', '.join(k.split('{')[0] for k in kept)))
    print('%s z%d side %s: %s' % (args.map.name, args.z, args.side, counts))
    print('removed:', dict(sorted(removed.items(), key=lambda item: -item[1])))
    if args.dry_run:
        return 0
    entries = ['"%s" = (%s)' % (key, tiles[key]) for key in order]
    lines[start:end] = [''.join(row) for row in rows]
    out = lines[:first_entry] + entries + lines[first_entry + original_count:]
    args.map.write_text(newline.join(out), encoding='utf-8')
    return 0


if __name__ == '__main__':
    sys.exit(main())
