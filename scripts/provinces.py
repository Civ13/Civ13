"""Cut a continent map into provinces that follow the land (docs/provinces.md).

Provinces are where factions hold land on a continent. They should end on the
borders a player sees: coasts, big rivers, lakes, mountain ranges and narrow
straits, not on straight lines. This tool grows provinces outward from evenly
spread starting points over a cost map: open ground is cheap, climbing costs
more, rock walls cost a lot and crossing water costs most, so neighbouring
provinces meet along those features. A few rounds of moving each starting
point to the middle of its province even out the sizes. Slivers merge into
the neighbour they share the longest border with, and small islets join the
nearest province.

Output (maps/provinces/<map>.txt), read by the game (code/modules/provinces):

    civ13-provinces 1
    size WIDTH HEIGHT
    z Z
    province <char> <name>
    ...
    rows

Rows run north first, one character per tile: '.' for open sea that belongs
to no province, otherwise the province's character (1-9 then a-z). The file
is deterministic for a given map, height file and river sidecar, and is
reviewed (render it with --render) before use. Map authors may hand-edit
names and border characters afterwards; rerunning the tool overwrites them.

Usage:
    python3 scripts/provinces.py --map maps/nomads/nomads_gaia.dmm --z 2 \
        --heights maps/heights/nomads_gaia.txt --flow maps/heights/nomads_gaia.flow.txt \
        --out maps/provinces/nomads_gaia.txt [--render gaia.png] [--count N]
"""
import argparse
import heapq
import sys
from collections import deque
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from terrain_heights import read_dmm, read_heights  # noqa: E402

HEADER = 'civ13-provinces 1'
CHARS = '123456789abcdefghijklmnopqrstuvwxyz'
# Land tiles per province, and the range of province counts per continent.
LAND_PER_PROVINCE = 12000
MIN_PROVINCES = 4
MAX_PROVINCES = 12
# Rounds of moving starting points to the middle of their provinces.
ROUNDS = 6
# A province smaller than this share of the average merges into a neighbour.
SLIVER_SHARE = 0.3
# Sea further than this from any land belongs to no province.
SEA_REACH = 8
# Step costs (entering a tile).
COST_LAND = 1.0
COST_CLIMB = 1.5  # per level of height change
COST_ROCK = 6.0
COST_RIVER = 30.0  # flowing fresh water
COST_FRESH = 30.0  # lakes, ponds, swamps
COST_SEA = 40.0

WATER, ROCK, LAND = 0, 1, 2


def tile_kind(turf):
    if 'rockwall' in turf or turf.startswith('/turf/wall/rock'):
        return ROCK
    if '/water' in turf or 'lava' in turf:
        return WATER
    return LAND


def read_flow(path, width, height):
    if not path:
        return None
    lines = Path(path).read_text(encoding='ascii').replace('\r', '').split('\n')
    if not lines[0].startswith('civ13-river-flow') or lines[1] != f'size {width} {height}':
        sys.exit(f'{path}: not a river-flow sidecar for a {width}x{height} map')
    return lines[3:3 + height]


def province_count(land, wanted=None):
    if wanted:
        return max(1, min(len(CHARS), wanted))
    return max(MIN_PROVINCES, min(MAX_PROVINCES, round(land / LAND_PER_PROVINCE)))


class Terrain:
    def __init__(self, turfs, heights, flow):
        self.h = len(turfs)
        self.w = len(turfs[0])
        n = self.w * self.h
        self.kind = bytearray(n)
        self.level = [0.0] * n
        self.salt = bytearray(n)
        self.river = bytearray(n)
        self.turf = [''] * n
        for r, row in enumerate(turfs):
            for c, turf in enumerate(row):
                i = r * self.w + c
                self.turf[i] = turf
                self.kind[i] = tile_kind(turf)
                if self.kind[i] == WATER and ('saltwater' in turf or '/ice/salty' in turf):
                    self.salt[i] = 1
                if heights is not None:
                    self.level[i] = float(heights[r][c])
                if flow is not None and flow[r][c] != '.':
                    self.river[i] = 1
        self.land = [i for i in range(n) if self.kind[i] != WATER]

    def neighbours(self, i):
        w = self.w
        r, c = divmod(i, w)
        if r > 0:
            yield i - w
        if r < self.h - 1:
            yield i + w
        if c > 0:
            yield i - 1
        if c < w - 1:
            yield i + 1

    def step_cost(self, a, b):
        k = self.kind[b]
        if k == WATER:
            if self.salt[b]:
                return COST_SEA
            return COST_RIVER if self.river[b] else COST_FRESH
        cost = COST_ROCK if k == ROCK else COST_LAND
        return cost + COST_CLIMB * abs(self.level[b] - self.level[a])

    def grow(self, seeds):
        """Multi-source shortest paths: (owner index per tile, distance per tile)."""
        n = self.w * self.h
        dist = [float('inf')] * n
        owner = [-1] * n
        heap = []
        for s, tile in enumerate(seeds):
            dist[tile] = 0.0
            owner[tile] = s
            heap.append((0.0, s, tile))
        heapq.heapify(heap)
        while heap:
            d, s, i = heapq.heappop(heap)
            if d > dist[i] or owner[i] != s:
                continue
            for j in self.neighbours(i):
                nd = d + self.step_cost(i, j)
                if nd < dist[j] or (nd == dist[j] and s < owner[j]):
                    dist[j] = nd
                    owner[j] = s
                    heapq.heappush(heap, (nd, s, j))
        return owner, dist


def landmasses(t):
    """Connected pieces of land (4-neighbour), largest first, as tile lists."""
    seen = bytearray(t.w * t.h)
    masses = []
    for start in t.land:
        if seen[start]:
            continue
        seen[start] = 1
        piece = [start]
        queue = deque([start])
        while queue:
            i = queue.popleft()
            for j in t.neighbours(i):
                if not seen[j] and t.kind[j] != WATER:
                    seen[j] = 1
                    piece.append(j)
                    queue.append(j)
        masses.append(piece)
    masses.sort(key=lambda m: (-len(m), m[0]))
    return masses


def share_out(masses, count):
    """Starting points per landmass, by size. Pieces too small for a province of
    their own get none and join their nearest neighbour as they grow."""
    total = sum(len(m) for m in masses)
    mean = total / count
    big = [m for m in masses if len(m) >= SLIVER_SHARE * mean] or masses[:1]
    land = sum(len(m) for m in big)
    exact = [count * len(m) / land for m in big]
    shares = [max(1, int(e)) for e in exact]
    while sum(shares) > count and max(shares) > 1:
        k = max(range(len(big)), key=lambda k: (shares[k] - exact[k], -k))
        shares[k] -= 1
    while sum(shares) < count:
        k = max(range(len(big)), key=lambda k: (exact[k] - shares[k], -k))
        shares[k] += 1
    return list(zip(big, shares))


def spread_seeds(t, count):
    """Farthest-point starting points over the cost map, shared out by landmass."""
    seeds = []
    for mass, share in share_out(landmasses(t), count):
        sx = sum(i % t.w for i in mass) / len(mass)
        sy = sum(i // t.w for i in mass) / len(mass)
        first = min(mass, key=lambda i: ((i % t.w - sx) ** 2 + (i // t.w - sy) ** 2, i))
        local = [first]
        _, dist = t.grow(local)
        while len(local) < share:
            far = max(mass, key=lambda i: (dist[i], -i))
            local.append(far)
            _, nd = t.grow([far])
            dist = [min(a, b) for a, b in zip(dist, nd)]
        seeds += local
    return seeds


def recentre(t, owner, count):
    """Each province's land tile nearest its land's mean position."""
    sums = [[0, 0, 0] for _ in range(count)]
    for i in t.land:
        o = owner[i]
        if o >= 0:
            sums[o][0] += i % t.w
            sums[o][1] += i // t.w
            sums[o][2] += 1
    best = [None] * count
    for i in t.land:
        o = owner[i]
        if o < 0 or not sums[o][2]:
            continue
        mx, my = sums[o][0] / sums[o][2], sums[o][1] / sums[o][2]
        d = ((i % t.w - mx) ** 2 + (i // t.w - my) ** 2, i)
        if best[o] is None or d < best[o][0]:
            best[o] = (d, i)
    return [b[1] for b in best if b]


def merge_slivers(t, owner, count):
    mean = len(t.land) / count  # the planned size, so merges do not cascade
    while True:
        sizes = {}
        for i in t.land:
            sizes[owner[i]] = sizes.get(owner[i], 0) + 1
        if len(sizes) <= 1:
            return owner
        small = min(sizes, key=lambda o: (sizes[o], o))
        if sizes[small] >= SLIVER_SHARE * mean:
            return owner
        border = {}
        for i in t.land:
            if owner[i] != small:
                continue
            for j in t.neighbours(i):
                o = owner[j]
                if o != small and o >= 0:
                    border[o] = border.get(o, 0) + 1
        if not border:  # an island of its own: join the nearest other province by cost
            others = [o for o in sizes if o != small]
            border = {others[0]: 1}
        into = max(border, key=lambda o: (border[o], -o))
        owner = [into if o == small else o for o in owner]


def sea_reach(t):
    """Tiles within SEA_REACH steps of land (land itself included)."""
    n = t.w * t.h
    dist = [-1] * n
    queue = deque()
    for i in t.land:
        dist[i] = 0
        queue.append(i)
    while queue:
        i = queue.popleft()
        if dist[i] >= SEA_REACH:
            continue
        for j in t.neighbours(i):
            if dist[j] < 0:
                dist[j] = dist[i] + 1
                queue.append(j)
    return dist


COMPASS = {(0, 0): 'North-west', (1, 0): 'North', (2, 0): 'North-east',
           (0, 1): 'West', (1, 1): 'Central', (2, 1): 'East',
           (0, 2): 'South-west', (1, 2): 'South', (2, 2): 'South-east'}


def describe(t, tiles):
    """Terrain words for a province, best fit first."""
    n = len(tiles)
    rock = sum(1 for i in tiles if t.kind[i] == ROCK) / n
    mean_level = sum(t.level[i] for i in tiles) / n
    coast = sum(1 for i in tiles if any(t.kind[j] == WATER and t.salt[j] for j in t.neighbours(i))) / n
    river = sum(1 for i in tiles if any(t.river[j] for j in t.neighbours(i))) / n
    lakes = sum(1 for i in tiles if any(t.kind[j] == WATER and not t.salt[j] and not t.river[j] for j in t.neighbours(i))) / n
    biome = {'snow': 'Snowfields', 'sand': 'Sands', 'desert': 'Sands', 'jungle': 'Jungle', 'swamp': 'Marshes'}
    counts = {}
    for i in tiles:
        for key in biome:
            if key in t.turf[i]:
                counts[key] = counts.get(key, 0) + 1
                break
    scores = [
        ('Highlands', max(rock * 4, (mean_level - 4) / 4)),
        ('Hills', (mean_level - 2) / 4),
        ('Riverlands', river * 15),
        ('Lakelands', lakes * 15),
        ('Coast', coast * 15),
        ('Lowlands', 0.5),
        ('Plains', 0.4),
        ('Reach', 0.1),
    ]
    for key, count in counts.items():
        scores.append((biome[key], count / n * 2))
    words = []
    for word, score in sorted(scores, key=lambda ws: (-ws[1], ws[0])):
        if word not in words:
            words.append(word)
    return words


def name_provinces(t, owner, ids):
    land_x = [i % t.w for i in t.land]
    land_y = [i // t.w for i in t.land]
    x0, x1 = min(land_x), max(land_x)
    y0, y1 = min(land_y), max(land_y)
    tiles = {o: [] for o in ids}
    for i in t.land:
        if owner[i] in tiles:
            tiles[owner[i]].append(i)
    names = {}
    taken = set()
    for o in sorted(ids, key=lambda o: -len(tiles[o])):  # big provinces pick first
        own = tiles[o]
        mx = sum(i % t.w for i in own) / len(own)
        my = sum(i // t.w for i in own) / len(own)
        cx = min(2, int(3 * (mx - x0) / max(1, x1 - x0 + 1)))
        cy = min(2, int(3 * (my - y0) / max(1, y1 - y0 + 1)))
        compass = COMPASS[(cx, cy)]
        name = None
        for word in describe(t, own):
            if f'{compass} {word}' not in taken:
                name = f'{compass} {word}'
                break
        k = 2
        while name is None or name in taken:
            name = f'{compass} {describe(t, own)[0]} {k}'
            k += 1
        taken.add(name)
        names[o] = name
    return names


def build(turfs, heights, flow, count=None):
    t = Terrain(turfs, heights, flow)
    if not t.land:
        sys.exit('the map has no land')
    count = province_count(len(t.land), count)
    seeds = spread_seeds(t, count)
    owner, _ = t.grow(seeds)
    for _ in range(ROUNDS):
        seeds = recentre(t, owner, len(seeds))
        owner, _ = t.grow(seeds)
    owner = merge_slivers(t, owner, count)
    reach = sea_reach(t)
    # Order provinces north-west first, so characters read naturally.
    first_seen = []
    for i in range(t.w * t.h):
        o = owner[i]
        if t.kind[i] != WATER and o not in first_seen:
            first_seen.append(o)
    char_of = {o: CHARS[k] for k, o in enumerate(first_seen)}
    names = name_provinces(t, owner, first_seen)
    rows = []
    for r in range(t.h):
        row = []
        for c in range(t.w):
            i = r * t.w + c
            o = owner[i]
            row.append(char_of[o] if (o in char_of and 0 <= reach[i]) else '.')
        rows.append(''.join(row))
    provinces = [(char_of[o], names[o]) for o in first_seen]
    return t, rows, provinces


def write(path, width, height, z, rows, provinces):
    lines = [HEADER, f'size {width} {height}', f'z {z}']
    lines += [f'province {c} {name}' for c, name in provinces]
    lines += rows
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text('\n'.join(lines) + '\n', encoding='ascii', newline='\n')


def read(path):
    """(width, height, z, [(char, name)], rows); raises ValueError like the game."""
    lines = Path(path).read_text(encoding='ascii').replace('\r', '').split('\n')
    if lines[0] != HEADER:
        raise ValueError(f"missing '{HEADER}' header")
    _, w, h = lines[1].split(' ')
    _, z = lines[2].split(' ')
    width, height = int(w), int(h)
    provinces = []
    i = 3
    while lines[i].startswith('province '):
        _, char, name = lines[i].split(' ', 2)
        provinces.append((char, name))
        i += 1
    rows = lines[i:i + height]
    if len(rows) != height or any(len(row) != width for row in rows):
        raise ValueError('bad rows')
    known = {c for c, _ in provinces} | {'.'}
    if any(ch not in known for row in rows for ch in row):
        raise ValueError('a row uses an undeclared province')
    return width, height, int(z), provinces, rows


PALETTE = [(230, 159, 0), (86, 180, 233), (0, 158, 115), (240, 228, 66), (0, 114, 178),
           (213, 94, 0), (204, 121, 167), (160, 120, 80), (120, 200, 120), (190, 150, 230),
           (250, 130, 130), (140, 140, 60)]


def render(t, rows, provinces, out, scale=2):
    from PIL import Image, ImageDraw
    colour = {c: PALETTE[k % len(PALETTE)] for k, (c, _) in enumerate(provinces)}
    img = Image.new('RGB', (t.w, t.h))
    px = img.load()
    for r in range(t.h):
        for c in range(t.w):
            i = r * t.w + c
            ch = rows[r][c]
            if t.kind[i] == WATER:
                base = (40, 70, 130) if t.salt[i] else (70, 120, 200)
                if ch != '.':
                    pc = colour[ch]
                    base = tuple((3 * b + p) // 4 for b, p in zip(base, pc))
            else:
                pc = colour[ch]
                shade = min(1.0, 0.75 + t.level[i] * 0.03)
                if t.kind[i] == ROCK:
                    shade *= 0.6
                base = tuple(int(v * shade) for v in pc)
            edge = False
            if ch != '.':
                for dr, dc in ((0, 1), (1, 0)):
                    rr, cc = r + dr, c + dc
                    if rr < t.h and cc < t.w and rows[rr][cc] not in (ch, '.'):
                        edge = True
            px[c, r] = (20, 20, 20) if edge else base
    img = img.resize((t.w * scale, t.h * scale), Image.NEAREST)
    draw = ImageDraw.Draw(img)
    for ch, name in provinces:
        tiles = [(c, r) for r in range(t.h) for c in range(t.w) if rows[r][c] == ch and t.kind[r * t.w + c] != WATER]
        mx = sum(c for c, _ in tiles) / len(tiles) * scale
        my = sum(r for _, r in tiles) / len(tiles) * scale
        label = f'{ch} {name}'
        box = draw.textbbox((0, 0), label)
        x, y = mx - (box[2] - box[0]) / 2, my - (box[3] - box[1]) / 2
        draw.rectangle((x - 2, y - 1, x + box[2] - box[0] + 2, y + box[3] - box[1] + 2), fill=(255, 255, 255))
        draw.text((x, y), label, fill=(0, 0, 0))
    img.save(out)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--map', required=True)
    parser.add_argument('--z', required=True, type=int)
    parser.add_argument('--heights')
    parser.add_argument('--flow')
    parser.add_argument('--out', required=True)
    parser.add_argument('--count', type=int, help='number of provinces (default: by land area)')
    parser.add_argument('--render', help='write a review image (needs Pillow)')
    args = parser.parse_args(argv)
    width, height, levels = read_dmm(args.map)
    if args.z not in levels:
        parser.error('z level is not present in the map')
    heights = None
    if args.heights:
        _, _, by_z = read_heights(args.heights)
        heights = by_z.get(args.z)
    flow = read_flow(args.flow, width, height)
    t, rows, provinces = build(levels[args.z], heights, flow, args.count)
    write(args.out, width, height, args.z, rows, provinces)
    print(f'{args.out}: {len(provinces)} provinces over {len(t.land)} land tiles')
    for c, name in provinces:
        print(f'  {c} {name}: {sum(row.count(c) for row in rows)} tiles')
    if args.render:
        render(t, rows, provinces, args.render)


if __name__ == '__main__':
    main()
