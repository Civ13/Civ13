"""Build a directional river-current sidecar from a standard Civ13 map.

Rivers are narrow runs of fresh water. Each flows downstream along the
shortest water path to its outlet: salt water when the network reaches the
sea, else the map edge, else the broad water it feeds (an inland lake). Lakes, broad
water, swamps, floods and isolated ponds stay still. Map rivers are often one
tile wide with diagonal joints, so paths and currents may step diagonally.
This is an approximation for authored maps with flat water elevations, not a
fluid simulation. Sidecars are deterministic and are reviewed before use.

Codes: n e s w are cardinal; a b c d are north-east, south-east, south-west
and north-west.
"""
import argparse
import heapq
from collections import deque
from pathlib import Path
from terrain_heights import read_dmm, read_heights

# Cardinal steps first, so ties prefer them.
NEIGHBOURS = ((0, -1, 'n'), (1, 0, 'e'), (0, 1, 's'), (-1, 0, 'w'),
              (1, -1, 'a'), (1, 1, 'b'), (-1, 1, 'c'), (-1, -1, 'd'))
HEADER = 'civ13-river-flow 1'
# Water this many steps from every bank is a lake (bodies about 9+ wide by default;
# maps with broad rivers raise it with --lake-depth).
LAKE_DEPTH = 5
# Shorter runs of channel are lake margins or ponds, not rivers.
MIN_RIVER = 12


def classify(turf):
    """'salt', 'fresh' (may flow), 'still' (joins networks, never flows) or None."""
    if '/water' not in turf:
        return None
    if 'saltwater' in turf or '/ice/salty' in turf:
        return 'salt'
    if any(kind in turf for kind in ('/ice', '/swamp', '/flooded')):
        return 'still'
    return 'fresh'


def broad_water(kinds, width, height, lake_depth=LAKE_DEPTH):
    """Water belonging to lakes and other broad bodies.

    A core tile is at least lake_depth steps from any bank or the map edge;
    the body is every water tile within lake_depth steps of a core, so lake
    margins and rounded shores count as lake while narrow channels do not.
    """
    depth, queue = {}, deque()
    for p in kinds:
        x, y = p
        for dx, dy, _ in NEIGHBOURS:
            n = (x + dx, y + dy)
            if n not in kinds:
                depth[p] = 1
                queue.append(p)
                break
    while queue:
        p = queue.popleft()
        for dx, dy, _ in NEIGHBOURS:
            n = (p[0] + dx, p[1] + dy)
            if n in kinds and n not in depth:
                depth[n] = depth[p] + 1
                queue.append(n)
    body = {p: 0 for p, d in depth.items() if d >= lake_depth}
    queue = deque(sorted(body))
    while queue:
        p = queue.popleft()
        if body[p] >= lake_depth:
            continue
        for dx, dy, _ in NEIGHBOURS:
            n = (p[0] + dx, p[1] + dy)
            if n in kinds and n not in body:
                body[n] = body[p] + 1
                queue.append(n)
    return set(body)


def bank_heights(kinds, heights):
    """Each water tile's height: the mean of its land neighbours, or the nearest bank's."""
    level, queue = {}, deque()
    for p in sorted(kinds):
        land = [heights[p[1] + dy][p[0] + dx] for dx, dy, _ in NEIGHBOURS
                if (p[0] + dx, p[1] + dy) not in kinds and 0 <= p[1] + dy < len(heights) and 0 <= p[0] + dx < len(heights[0])]
        if land:
            level[p] = sum(land) / len(land)
            queue.append(p)
    while queue:
        p = queue.popleft()
        for dx, dy, _ in NEIGHBOURS:
            n = (p[0] + dx, p[1] + dy)
            if n in kinds and n not in level:
                level[n] = level[p]
                queue.append(n)
    return level


def build(rows, lake_depth=LAKE_DEPTH, heights=None):
    height, width = len(rows), len(rows[0])
    kinds = {}
    for y, row in enumerate(rows):
        for x, turf in enumerate(row):
            kind = classify(turf)
            if kind:
                kinds[(x, y)] = kind

    def neighbours(p):
        for dx, dy, d in NEIGHBOURS:
            n = (p[0] + dx, p[1] + dy)
            if n in kinds:
                yield n, d

    broad = broad_water(kinds, width, height, lake_depth)
    channel = {p for p, k in kinds.items() if k == 'fresh' and p not in broad}
    visited = set()
    for start in sorted(channel):
        if start in visited:
            continue
        piece, queue = {start}, deque([start])
        while queue:
            p = queue.popleft()
            for n, _ in neighbours(p):
                if n in channel and n not in piece:
                    piece.add(n)
                    queue.append(n)
        visited |= piece
        if len(piece) < MIN_RIVER:
            channel -= piece

    # Each inland network drains to the sea where it touches salt water,
    # otherwise into its broad water; a network of only channel stays still.
    seen, sinks, edge_outlets = set(), set(), set()
    for start in sorted(kinds):
        if kinds[start] == 'salt' or start in seen:
            continue
        network, queue = [start], deque([start])
        seen.add(start)
        while queue:
            p = queue.popleft()
            for n, _ in neighbours(p):
                if n not in seen and kinds[n] != 'salt':
                    seen.add(n)
                    network.append(n)
                    queue.append(n)
        # Outlets: the sea, else the map edge, else the network's broad water.
        coast = [p for p in network if any(kinds[n] == 'salt' for n, _ in neighbours(p))]
        edge = [p for p in network if p[0] in (0, width - 1) or p[1] in (0, height - 1)]
        if not coast:
            edge_outlets.update(edge)
        sinks.update(coast or edge or [p for p in network if p not in channel])

    # Priority flood from the outlets: water is reached in order of the
    # highest bank it must climb to, then by distance, so rivers run downhill
    # and a river between two outlets drains toward the lower spill. Without
    # heights this is plain distance to the nearest outlet.
    level = bank_heights(kinds, heights) if heights else {}
    spill, steps, queue, order = {}, {}, [], 0
    for p in sorted(sinks):
        spill[p], steps[p] = level.get(p, 0), 0
        heapq.heappush(queue, (spill[p], order, p))
        order += 1
    while queue:
        key, _, p = heapq.heappop(queue)
        for n, _ in neighbours(p):
            if kinds[n] != 'salt' and n not in spill:
                spill[n], steps[n] = max(key, level.get(n, 0)), steps[p] + 1
                heapq.heappush(queue, (spill[n], order, n))
                order += 1

    # Each channel tile steps to the neighbour no higher than itself that is
    # fewest steps from the outlet, cardinal first; outlets step into the sea.
    result = [['.' for _ in range(width)] for _ in range(height)]
    for p in sorted(channel):
        if p not in spill:
            continue
        x, y = p
        best = None
        for n, direction in neighbours(p):
            if steps[p] == 0:
                if kinds[n] == 'salt':
                    best = (0, direction)
                    break
                continue
            if n in steps and spill[n] <= spill[p] and steps[n] < steps[p] and (best is None or steps[n] < best[0]):
                best = (steps[n], direction)
        if best:
            result[y][x] = best[1]
        elif steps[p] == 0 and p in edge_outlets:
            # An outlet on the map edge runs off the map.
            result[y][x] = 'w' if x == 0 else 'e' if x == width - 1 else 'n' if y == 0 else 's'
    return [''.join(row) for row in result]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--map', required=True)
    parser.add_argument('--z', required=True, type=int)
    parser.add_argument('--out', required=True)
    parser.add_argument('--heights', help='terrain-heights file; rivers then run downhill')
    parser.add_argument('--lake-depth', type=int, default=LAKE_DEPTH,
                        help='steps from every bank that make water a lake (default %(default)s)')
    args = parser.parse_args()
    width, height, levels = read_dmm(args.map)
    if args.z not in levels:
        parser.error('z level is not present in the map')
    heights = None
    if args.heights:
        _, _, by_z = read_heights(args.heights)
        heights = by_z.get(args.z)
    rows = build(levels[args.z], args.lake_depth, heights)
    Path(args.out).write_text(f'{HEADER}\nsize {width} {height}\nz {args.z}\n' + '\n'.join(rows) + '\n', encoding='ascii', newline='\n')
    print(f'{args.out}: {sum(c != "." for row in rows for c in row)} flowing tiles')


if __name__ == '__main__':
    main()
