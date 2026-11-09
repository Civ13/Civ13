"""Build a directional river-current sidecar from a standard Civ13 map.

Only narrow, fresh channels connected to salt water flow. Distances are measured
along water to the coast; disconnected lakes and broad water remain still. This
is an approximation for authored maps with flat water elevations, not a fluid
simulation. Sidecars are deterministic and may be reviewed before use.
"""
import argparse
from collections import deque
from pathlib import Path
from terrain_heights import read_dmm

NEIGHBOURS = ((0, -1, 'n'), (1, 0, 'e'), (0, 1, 's'), (-1, 0, 'w'))
HEADER = 'civ13-river-flow 1'


def build(rows):
    height, width = len(rows), len(rows[0])
    fresh = set()
    salt = set()
    water = set()
    for y, row in enumerate(rows):
        for x, turf in enumerate(row):
            if '/water' not in turf:
                continue
            p = (x, y)
            water.add(p)
            if 'saltwater' in turf or '/ice/salty' in turf:
                salt.add(p)
            elif not any(kind in turf for kind in ('/ice', '/swamp', '/flooded')):
                fresh.add(p)

    def neighbours(p):
        x, y = p
        return ((x + dx, y + dy, d) for dx, dy, d in NEIGHBOURS)

    # A shortest path through fresh water to an adjacent salt-water outlet.
    outlets = sorted(p for p in fresh if any((x, y) in salt for x, y, _ in neighbours(p)))
    distance = {p: 0 for p in outlets}
    queue = deque(outlets)
    while queue:
        p = queue.popleft()
        for x, y, _ in neighbours(p):
            n = (x, y)
            if n in fresh and n not in distance:
                distance[n] = distance[p] + 1
                queue.append(n)

    # Restrict current to channels within two cardinal steps of a bank.
    bank = {p for p in fresh if any((x, y) not in water and 0 <= x < width and 0 <= y < height for x, y, _ in neighbours(p))}
    narrow = set(bank)
    for p in bank:
        narrow.update((x, y) for x, y, _ in neighbours(p) if (x, y) in fresh)
    result = [['.' for _ in range(width)] for _ in range(height)]
    for p, value in distance.items():
        if p not in narrow:
            continue
        for x, y, direction in neighbours(p):
            n = (x, y)
            if (value == 0 and n in salt) or distance.get(n) == value - 1:
                result[p[1]][p[0]] = direction
                break
    return [''.join(row) for row in result]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--map', required=True)
    parser.add_argument('--z', required=True, type=int)
    parser.add_argument('--out', required=True)
    args = parser.parse_args()
    width, height, levels = read_dmm(args.map)
    if args.z not in levels:
        parser.error('z level is not present in the map')
    rows = build(levels[args.z])
    Path(args.out).write_text(f'{HEADER}\nsize {width} {height}\nz {args.z}\n' + '\n'.join(rows) + '\n', encoding='ascii', newline='\n')
    print(f'{args.out}: {sum(c != "." for row in rows for c in row)} flowing tiles')


if __name__ == '__main__':
    main()
