"""Relief backend: a land whose features grow with its size.

The port and oceanic backends draw one fixed layout (one lake, one confluence,
oval islands) whatever the map's size. This backend builds the land from its
relief instead, so a 200 x 200 land and a million-tile land come from the same
rules and each gets as many coasts, ranges, rivers and lakes as its area holds:

- the coastline is a noise field against the open-sea sides (or island domes),
  cut at the level that gives the requested share of sea;
- relief is a coastal ramp plus ridged noise; the highest ridges are mountains;
- every tile drains to the sea along a priority flood of that relief, hollows
  that fill become lakes, and the streams that gather the most land are rivers,
  with tributaries joining them and lakes spilling into them;
- climate bands follow a smooth moisture field.

Everything is integer arithmetic on flat arrays, standard library only, and
depends only on the configuration and its seed. Output is typed IR
(civ13-geography-ir/4); nothing here reads a map or launches the game.
"""
from collections import deque
from copy import deepcopy
import heapq
import json
from math import isqrt

from .configuration import seed_manifest, validate_config
from .surface_generator import Rejection, ground
from .validator import LAND_VERSION, canonical_hash, stable_u64, validate

ALGORITHM_VERSION = "relief-offline/1.0.0"
CONTENT_VERSION = "abstract-survival-catalog/1"
PROFILE_VERSION = "SURFACE-relief/1"
CHAIN = ["LUSH", "TEMPERATE", "STEPPE", "ARID", "DESERT"]
BAND_MOISTURE = {"LUSH": 75, "TEMPERATE": 55, "STEPPE": 40, "ARID": 25, "DESERT": 15}
MIN_ISLET = 20          # smaller scraps of land sink
MIN_LAKE = 10           # smaller hollows are levelled, not flooded
MIN_STREAM = 6          # shorter spring streams are dropped
MIN_RANGE = 12          # smaller mountain scraps become hills
MAX_RIVERS = 2000
SEA, LAKE, RIVER, SWAMP, PLAIN, HILL, MOUNTAIN, BEACH = range(8)
M64 = (1 << 64) - 1


def _mix(salt, i):
    """A well-mixed 64-bit value for cell i (splitmix64 finalizer)."""
    z = (salt + i * 0x9E3779B97F4A7C15) & M64
    z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & M64
    z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & M64
    return z ^ (z >> 31)


def _generate(config):
    problems = validate_config(config)
    if problems:
        raise Rejection("CONFIG_REJECTED", json.dumps(problems, sort_keys=True))
    layout = config["relief_layout"]
    w, h = config["dimensions"]["width"], config["dimensions"]["height"]
    n = w * h
    small = min(w, h)
    cfg_hash = canonical_hash(config)
    seed = config["seed"]

    def draw(stage, x=0, y=0, slot=0):
        return stable_u64(seed, ALGORITHM_VERSION, CONTENT_VERSION, PROFILE_VERSION + ":" + cfg_hash, stage, "SURFACE", x, y, slot)

    def choose(stage, bounds, slot=0):
        span = bounds[1] - bounds[0] + 1
        limit = 2 ** 64 - (2 ** 64 % span)
        for retry in range(32):
            value = draw(stage + "-choice", slot=slot * 32 + retry)
            if value < limit:
                return bounds[0] + value % span
        raise Rejection("RANDOM_REJECTION_BOUND", "integer sampling exhausted 32 draws")

    def octave(stage, scale):
        """Smooth lattice noise, one value 0..1023 per cell."""
        scale = max(2, scale)
        gw, gh = w // scale + 2, h // scale + 2
        lattice = [[draw(stage, gx, gy) % 1024 for gx in range(gw)] for gy in range(gh)]
        ease = [(3 * t * t * scale - 2 * t * t * t) * 1024 // (scale ** 3) for t in range(scale)]
        gx_of = [x // scale for x in range(w)]
        wx_of = [ease[x % scale] for x in range(w)]
        out = []
        for gy in range(gh - 1):
            a, b = lattice[gy], lattice[gy + 1]
            top = [a[g] * (1024 - t) + a[g + 1] * t for g, t in zip(gx_of, wx_of)]
            bottom = [b[g] * (1024 - t) + b[g + 1] * t for g, t in zip(gx_of, wx_of)]
            for ty in range(scale):
                if len(out) >= n:
                    break
                t = ease[ty]
                out.extend([(p * (1024 - t) + q * t) >> 20 for p, q in zip(top, bottom)])
        return out

    def fbm(stage, scale):
        """Three octaves, 0..7161."""
        a, b, c = octave(stage + "-a", scale), octave(stage + "-b", max(2, scale // 2)), octave(stage + "-c", max(2, scale // 4))
        return [4 * p + 2 * q + r for p, q, r in zip(a, b, c)]

    def near(i):
        x = i % w
        if x:
            yield i - 1
        if x < w - 1:
            yield i + 1
        if i >= w:
            yield i - w
        if i < n - w:
            yield i + w

    def spread(sources, passable, limit=None):
        """Steps from the nearest source through passable cells; -1 if unreached."""
        dist = [-1] * n
        queue = deque()
        for i in sources:
            if dist[i] < 0:
                dist[i] = 0
                queue.append(i)
        while queue:
            i = queue.popleft()
            d = dist[i] + 1
            if limit is not None and d > limit:
                continue
            for q in near(i):
                if dist[q] < 0 and passable[q]:
                    dist[q] = d
                    queue.append(q)
        return dist

    def components(mask):
        """Label 4-connected groups of set cells: (labels from 1, sizes)."""
        label = [0] * n
        sizes = [0]
        for start in range(n):
            if not mask[start] or label[start]:
                continue
            k = len(sizes)
            label[start] = k
            todo = [start]
            count = 0
            while todo:
                i = todo.pop()
                count += 1
                for q in near(i):
                    if mask[q] and not label[q]:
                        label[q] = k
                        todo.append(q)
            sizes.append(count)
        return label, sizes

    # --- 1. Land and sea -------------------------------------------------
    form = layout["form"]
    rough = layout["coast_roughness"]
    sea_share = choose("sea-coverage", layout["sea_pct"])
    if form == "MAINLAND":
        sides = set(layout["sea_sides"])
        fall = max(10, small * 30 // 100)
        noise = [a + b * 2 // 3 for a, b in zip(fbm("coast", max(8, fall // 2)), fbm("coast-detail", max(4, fall // 8)))]
        big = w + h
        column = [min(x if "W" in sides else big, w - 1 - x if "E" in sides else big) for x in range(w)]
        value = []
        for y in range(h):
            row = min(y if "S" in sides else big, h - 1 - y if "N" in sides else big)
            base = y * w
            value.extend([-1 if (d := min(c, row)) < 3 else min(d, fall) * 10000 // fall + noise[base + x] * rough // 2
                          for x, c in enumerate(column)])
        island_count = 1
    else:
        sides = {"N", "S", "E", "W"}
        island_count = choose("island-count", layout["islands"])
        margin = max(6, small // 14)
        cols = 1
        while cols * max(1, round(cols * h / w)) < island_count:
            cols += 1
        rows = max(1, round(cols * h / w))
        while cols * rows < island_count:
            rows += 1
        slots = sorted(((draw("island-slot", cx, cy), cx, cy) for cx in range(cols) for cy in range(rows)))[:island_count]
        dome = [-8192] * n
        cw, ch = (w - 2 * margin) / cols, (h - 2 * margin) / rows
        for k, (_, cx, cy) in enumerate(slots):
            ox = int(margin + cw * cx + cw * (30 + draw("island-x", k) % 41) / 100)
            oy = int(margin + ch * cy + ch * (30 + draw("island-y", k) % 41) / 100)
            rx = max(8, int(cw * (42 + draw("island-rx", k) % 22) / 100))
            ry = max(8, int(ch * (42 + draw("island-ry", k) % 22) / 100))
            xterm = [(x - ox) * (x - ox) * 1024 // (rx * rx) for x in range(max(0, ox - 2 * rx), min(w, ox + 2 * rx + 1))]
            x0 = max(0, ox - 2 * rx)
            for y in range(max(0, oy - 2 * ry), min(h, oy + 2 * ry + 1)):
                top = 1024 - (y - oy) * (y - oy) * 1024 // (ry * ry)
                base = y * w + x0
                dome[base:base + len(xterm)] = [max(old, top - t) for old, t in zip(dome[base:base + len(xterm)], xterm)]
        noise = [a + b * 2 // 3 for a, b in zip(fbm("coast", max(8, int(min(cw, ch)) // 4)), fbm("coast-detail", max(4, int(min(cw, ch)) // 12)))]
        value = []
        for y in range(h):
            edge_y = min(y, h - 1 - y)
            base = y * w
            # Open water at the very edge, and a shelf that sinks towards it so no shore is cut straight.
            value.extend([-10 ** 6 if (d := min(x, w - 1 - x, edge_y)) < 3 else
                          dome[base + x] * 8 + noise[base + x] * rough // 2 - (max(0, 2 * margin - d) * 9000 // margin)
                          for x in range(w)])
        del dome
    cut = sorted(value)[min(n - 1, n * sea_share // 100)]
    land = bytearray(1 if v > cut else 0 for v in value)
    del value, noise
    # Open sea is the water joined to an open-sea edge; other water is a hollow in the land.
    edge = []
    if "S" in sides:
        edge.extend(range(w))
    if "N" in sides:
        edge.extend(range(n - w, n))
    if "W" in sides:
        edge.extend(range(0, n, w))
    if "E" in sides:
        edge.extend(range(w - 1, n, w))
    water = bytearray(1 - v for v in land)
    open_sea = spread([i for i in edge if water[i]], water)
    pocket = bytearray(1 if water[i] and open_sea[i] < 0 else 0 for i in range(n))
    for i in range(n):
        if pocket[i]:
            land[i] = 1
    label, sizes = components(land)
    for i in range(n):
        if land[i] and sizes[label[i]] < MIN_ISLET:
            land[i] = 0
    land_label, land_sizes = components(land)
    land_cells = sum(land)
    if land_cells < 400:
        raise Rejection("LAND_AREA", "almost no land above the sea")
    sea_mask = bytearray(1 - v for v in land)
    coast_dist = spread([i for i in range(n) if sea_mask[i]], land)

    # --- 2. Relief --------------------------------------------------------
    ramp_reach = max(8, small // 5)
    mid = fbm("relief", ramp_reach)
    rough_ground = fbm("relief-detail", 9)
    ridge_scale = max(20, min(90, small // 4))
    ridge = octave("ridge", ridge_scale)
    ridge_fine = octave("ridge-fine", max(6, ridge_scale // 3))
    ranges = octave("range-mask", max(40, min(220, small // 2)))
    jitter = draw("relief-jitter")
    score = [0] * n
    height = [0] * n
    for i in range(n):
        if not land[i]:
            continue
        crest = 1023 - abs(2 * ridge[i] - 1023)
        s = crest * crest // 1023 * ranges[i] // 1023 + ridge_fine[i] // 8
        if coast_dist[i] < 4:
            s = s * coast_dist[i] // 4
        score[i] = s
        height[i] = 3 + min(coast_dist[i], ramp_reach) * 120 // ramp_reach + mid[i] * 140 // 7161 + s * 600 // 1150 + rough_ground[i] * 36 // 7161 + _mix(jitter, i) % 3
    del mid, ridge, ridge_fine, ranges, rough_ground
    ranked = sorted((i for i in range(n) if land[i] and not pocket[i]), key=lambda i: (-score[i], i))
    mountain_share = choose("mountain-coverage", layout["mountain_pct"])
    hill_share = choose("hill-coverage", layout["hill_pct"])
    mountain_count = len(ranked) * mountain_share // 100
    hill_count = len(ranked) * hill_share // 100
    kind = bytearray(PLAIN if v else SEA for v in land)
    for i in ranked[:mountain_count]:
        kind[i] = MOUNTAIN
        height[i] += 250
    for i in ranked[mountain_count:mountain_count + hill_count]:
        kind[i] = HILL
        height[i] += 60
    del ranked
    for i in range(n):
        if pocket[i]:
            height[i] = -60
    # Hollows for lakes: one site per stretch of land, more on larger land.
    lake_rate = choose("lake-density", layout["lakes_per_100k_land"])
    bowl_max = max(5, min(16, isqrt(land_cells) // 45))
    bowls = []
    wanted_by_land = {}
    for k in range(1, len(land_sizes)):
        size = land_sizes[k]
        wanted = size * lake_rate // 100000
        if lake_rate and size >= 1500:
            wanted = max(1, wanted)
        if wanted:
            wanted_by_land[k] = wanted
    if wanted_by_land:
        salt = draw("lake-sites")
        sites = sorted((i for i in range(n) if land[i] and kind[i] != MOUNTAIN and coast_dist[i] >= 9
                        and land_label[i] in wanted_by_land and _mix(salt, i) % 23 == 0), key=lambda i: (_mix(salt, i), i))
        for i in sites:
            k = land_label[i]
            if not wanted_by_land.get(k):
                continue
            radius = 3 + _mix(salt + 1, i) % (bowl_max - 2)
            if coast_dist[i] < radius + 4:
                continue
            x, y = i % w, i // w
            if any(abs(x - bx) + abs(y - by) < 2 * (radius + br) + 6 for bx, by, br in bowls):
                continue
            bowls.append((x, y, radius))
            wanted_by_land[k] -= 1
    for x, y, radius in bowls:
        for yy in range(max(0, y - radius), min(h, y + radius + 1)):
            for xx in range(max(0, x - radius), min(w, x + radius + 1)):
                d2 = (xx - x) * (xx - x) + (yy - y) * (yy - y)
                if d2 <= radius * radius and land[yy * w + xx]:
                    height[yy * w + xx] -= 70 * (radius * radius - d2) // (radius * radius) + 4

    # --- 3. Drainage: every tile reaches the sea ---------------------------
    filled = [0] * n
    parent = [-2] * n          # -1: drains into the sea; -2: not land
    heap = []
    seq = 0
    for i in range(n):
        if land[i] and coast_dist[i] == 1:
            parent[i] = -1
            filled[i] = height[i]
            heap.append((height[i], seq, i))
            seq += 1
    heapq.heapify(heap)
    order = []
    # The lowest reachable tile is always taken next (Prim's tree), so each tile's
    # way down is the one that climbs least, its level is the true spill level, and
    # streams wind along the low ground of a hollow instead of crossing it straight.
    while heap:
        _, _, i = heapq.heappop(heap)
        order.append(i)
        level = filled[i]
        for q in near(i):
            if parent[q] == -2 and land[q]:
                parent[q] = i
                filled[q] = level if level > height[q] else height[q]
                seq += 1
                heapq.heappush(heap, (height[q], seq, q))
    if len(order) != land_cells:
        raise Rejection("DRAINAGE", "land that no stream can leave")
    # Hollows that filled are lakes, largest first, within the lake budget.
    deep = bytearray(1 if land[i] and filled[i] - height[i] >= 2 else 0 for i in range(n))
    hollow, hollow_sizes = components(deep)
    budget = land_cells * layout["lake_max_pct"] // 100
    biggest = max(150, budget // 12)     # a basin larger than this stays a plain with a river through it
    lake_of = [0] * n
    accepted = {}
    used = 0
    for k in sorted(range(1, len(hollow_sizes)), key=lambda k: (-hollow_sizes[k], k)):
        size = hollow_sizes[k]
        if size < MIN_LAKE:
            break
        if used + size > budget or size > biggest:
            continue
        accepted[k] = True
        used += size
    lake_ids = {}
    outlet = {}
    for i in order:
        k = hollow[i]
        if k in accepted:
            if k not in lake_ids:
                lake_ids[k] = len(lake_ids) + 1
                outlet[lake_ids[k]] = i          # the first tile the flood reached: the lake spills here
            lake_of[i] = lake_ids[k]
            kind[i] = LAKE
    flow = [0] * n
    for i in order:
        flow[i] = 1
    for i in reversed(order):
        p = parent[i]
        if p >= 0:
            flow[p] += flow[i]
    dry = [i for i in order if not lake_of[i]]
    river_share = choose("river-coverage", layout["river_permille"])
    target = len(dry) * river_share // 1000
    threshold = max(30, sorted((flow[i] for i in dry), reverse=True)[target]) if target and target < len(dry) else n + 1
    is_river = bytearray(n)
    for i in dry:
        if flow[i] >= threshold:
            is_river[i] = 1
    # A lake spills by a river from the tile below its outlet, however small the stream.
    lake_start = {}
    claimed = set()
    for lake in sorted(outlet):
        first = parent[outlet[lake]]
        below = parent[first] if first >= 0 else -1
        # No room for a river of two tiles before the sea, another lake or another outlet: a closed basin.
        if first < 0 or lake_of[first] or below < 0 or lake_of[below] or below in lake_start or first in claimed or below in claimed:
            continue
        lake_start[first] = lake
        claimed.update((first, below))
        cur = first
        while cur >= 0 and not lake_of[cur] and not is_river[cur]:
            is_river[cur] = 1
            cur = parent[cur]
    best = {}
    has_child = bytearray(n)
    children = {}
    for i in dry:
        if not is_river[i]:
            continue
        p = parent[i]
        if p < 0 or not is_river[p]:
            continue
        has_child[p] = 1
        children[p] = children.get(p, 0) + 1
        if p in lake_start:
            continue
        rank = (1 if i in lake_start else 0, flow[i], -i)
        if p not in best or rank > best[p][0]:
            best[p] = (rank, i)
    segments = []
    for i in dry:
        if not is_river[i] or (has_child[i] and i not in lake_start):
            continue
        path = [i]
        while True:
            p = parent[path[-1]]
            if p < 0:
                sink = ("SEA", -1)
                break
            if lake_of[p]:
                sink = ("LAKE", lake_of[p])
                break
            if p in lake_start or best[p][1] != path[-1]:
                sink = ("RIVER", p)
                break
            path.append(p)
        source = lake_start.get(i, 0)
        if not source and len(path) < MIN_STREAM and all(children.get(q, 0) <= 1 for q in path):
            for q in path:
                is_river[q] = 0
            continue
        segments.append((path, source, sink))
    if len(segments) > MAX_RIVERS:
        raise Rejection("RIVER_COUNT", "more streams than the map format lists")
    river_of = [0] * n
    for k, (path, _, _) in enumerate(segments):
        for q in path:
            river_of[q] = k + 1
            kind[q] = RIVER
    # Rivers widen as they gather land.
    max_half = layout["river_max_half_width"]
    half_width = 0
    if max_half:
        front = deque()
        reach = {}
        for k, (path, _, _) in enumerate(segments):
            for q in path:
                r = 0 if flow[q] < threshold * 5 else 1 if flow[q] < threshold * 30 else 2
                r = min(r, max_half)
                if r:
                    reach[q] = r
                    front.append(q)
        while front:
            i = front.popleft()
            r = reach[i]
            for q in near(i):
                if kind[q] in (PLAIN, HILL, MOUNTAIN) and not river_of[q] and coast_dist[q] > 1:
                    river_of[q] = river_of[i]
                    kind[q] = RIVER
                    filled[q] = filled[i]
                    if r > 1:
                        reach[q] = r - 1
                        front.append(q)
        half_width = max(reach.values(), default=0)
    # Mountains: whole ranges stay, scraps become hills.
    peaks = bytearray(1 if k == MOUNTAIN else 0 for k in kind)
    label, sizes = components(peaks)
    range_count = 0
    for k in range(1, len(sizes)):
        if sizes[k] >= MIN_RANGE:
            range_count += 1
    for i in range(n):
        if peaks[i] and sizes[label[i]] < MIN_RANGE:
            kind[i] = HILL
    # Beaches along the open sea.
    beach = layout["coast_width_tiles"]
    for i in range(n):
        if kind[i] == PLAIN and 1 <= coast_dist[i] <= beach:
            kind[i] = BEACH

    # --- 4. Climate ---------------------------------------------------------
    mix = {k: v for k, v in config["biome_mix_pct"].items() if v}
    coast_share = mix.pop("COAST", 0)
    bands = [b for b in CHAIN if b in mix]
    damp = fbm("moisture", max(32, min(160, small // 4)))
    fresh = [i for i in range(n) if kind[i] in (LAKE, RIVER)]
    passable = bytearray(1 if k not in (SEA,) else 0 for k in kind)
    fresh_dist = spread(fresh, passable, 12)
    dry_land = [i for i in range(n) if kind[i] in (PLAIN, HILL, MOUNTAIN, BEACH)]
    wet_first = sorted(dry_land, key=lambda i: (-(damp[i] + (12 - fresh_dist[i]) * 60 if fresh_dist[i] >= 0 else damp[i]), i))
    band = bytearray([200]) * n      # water takes its band from the land around it
    total = sum(mix.values())
    cursor = 0
    for b, name in enumerate(bands):
        count = len(wet_first) * mix[name] // total if b < len(bands) - 1 else len(wet_first) - cursor
        for i in wet_first[cursor:cursor + count]:
            band[i] = b
        cursor += count
    del wet_first, damp
    # Neighbouring tiles differ by one band at most (two chamfer sweeps).
    for i in range(n):
        v = band[i]
        if i % w and band[i - 1] + 1 < v:
            v = band[i - 1] + 1
        if i >= w and band[i - w] + 1 < v:
            v = band[i - w] + 1
        band[i] = v
    for i in range(n - 1, -1, -1):
        v = band[i]
        if i % w < w - 1 and band[i + 1] + 1 < v:
            v = band[i + 1] + 1
        if i < n - w and band[i + w] + 1 < v:
            v = band[i + w] + 1
        band[i] = min(v, len(bands) - 1)
    moist_lo, moist_hi = config["climate"]["moisture_range"]
    temp_lo, temp_hi = config["climate"]["temperature_c_range"]
    band_moisture = [max(moist_lo, min(moist_hi, BAND_MOISTURE[name])) for name in bands]
    coastal = bytearray(n)
    if coast_share:
        by_shore = sorted(dry_land, key=lambda i: (coast_dist[i], i))
        for i in by_shore[:len(by_shore) * coast_share // 100]:
            coastal[i] = 1
    # Wetland beside fresh water, in patches.
    swamp_share = choose("swamp-coverage", layout["swamp_pct"])
    if swamp_share:
        patch = octave("swamp", 12)
        sites = sorted((i for i in dry_land if kind[i] == PLAIN and 1 <= fresh_dist[i] <= 5 and coast_dist[i] > 2
                        and bands[band[i]] != "DESERT"),
                       key=lambda i: (patch[i] + fresh_dist[i] * 120, i))
        for i in sites[:len(dry_land) * swamp_share // 100]:
            kind[i] = SWAMP
        del patch

    # --- 5. Starts, supplies and plants --------------------------------------
    walk = bytearray(1 if k in (PLAIN, HILL, BEACH) else 0 for k in kind)
    banks = [i for i in range(n) if walk[i] and any(kind[q] in (LAKE, RIVER) for q in near(i))]
    max_route = config["starts"]["max_route_tiles"]
    to_water = spread(banks, walk, max_route)
    step = 1 if n < 60000 else 2 if n < 250000 else 4
    rank_salt = draw("start-rank")
    candidates = [i for i in range(n) if walk[i] and to_water[i] >= 0 and (i % w) % step == 0 and (i // w) % step == 0
                  and 2 < i % w < w - 3 and 2 < i // w < h - 3 and all(walk[q] for q in near(i))]
    spacing = config["starts"]["min_spacing_tiles"]
    wanted = config["starts"]["count"]
    resource = bytearray(n)        # 0 none, 1 FOOD, 2 WOOD, 3 STONE
    reserved = bytearray(n)
    starts = []
    routes = []
    nearest = {}
    supply_salt = draw("supply-rank")
    # The largest lands each get a start first, then starts spread out.
    homes = sorted({land_label[i] for i in candidates}, key=lambda k: (-land_sizes[k], k))[:wanted]
    while candidates and len(starts) < wanted:
        pool = candidates
        if homes:
            home = homes.pop(0)
            pool = [i for i in candidates if land_label[i] == home] or candidates
        p = max(pool, key=lambda i: (nearest.get(i, 0), _mix(rank_salt, i), i))
        if resource[p]:
            candidates = [i for i in candidates if i != p]
            continue
        px, py = p % w, p // w
        found = {p: 0}
        queue = deque([p])
        while queue:
            i = queue.popleft()
            if found[i] >= min(4, max_route):
                continue
            for q in near(i):
                if walk[q] and q not in found:
                    found[q] = found[i] + 1
                    queue.append(q)
        taken = set(starts)
        choices = sorted((q for q, d in found.items() if d >= 1 and not resource[q] and q not in taken),
                         key=lambda q: (found[q], _mix(supply_salt, q), q))
        if len(choices) < 3:
            candidates = [i for i in candidates if i != p]
            continue
        starts.append(p)
        route = [p]
        while to_water[route[-1]] > 0:
            route.append(min((q for q in near(route[-1]) if to_water[q] == to_water[route[-1]] - 1), default=route[-1]))
            if len(route) > max_route + 2:
                raise Rejection("START_ROUTE", "a start lost its way to water")
        for q in route:
            reserved[q] = 1
        for code, q in zip((1, 2, 3), choices[:3]):
            resource[q] = code
            reserved[q] = 1
            cur = q
            while cur != p:                      # keep the way back to the start clear
                cur = min((t for t in near(cur) if found.get(t, 99) == found[cur] - 1))
                reserved[cur] = 1
        routes.append(dict(start=[px, py], water_route_tiles=len(route) - 1))
        candidates = [i for i in candidates if abs(i % w - px) + abs(i // w - py) >= spacing]
        first = len(starts) == 1
        for i in candidates:
            d = abs(i % w - px) + abs(i // w - py)
            if first or d < nearest[i]:
                nearest[i] = d
    if len(starts) < max(1, wanted // 2):
        raise Rejection("START_PACKING", "too few safe starts near fresh water")
    start_set = set(starts)
    density = choose("resource-density", config["resources"]["density_per_1000_land_tiles"])
    extra_salt = draw("extra-resources")
    spare = sorted((i for i in range(n) if walk[i] and not reserved[i] and i not in start_set), key=lambda i: (_mix(extra_salt, i), i))
    for i in spare[:len(dry_land) * density // 1000]:
        resource[i] = 1 + _mix(extra_salt + 1, i) % 3
        reserved[i] = 1
    del spare
    temperature = [temp_hi - (temp_hi - temp_lo) * y // max(1, h - 1) for y in range(h)]
    sandy = [name in ("ARID", "DESERT") for name in bands]
    tree = bytearray(n)            # 0 none, 1 BROADLEAF, 2 PINE, 3 CACTUS, 4 PALM
    eligible = []
    for i in range(n):
        if kind[i] not in (PLAIN, HILL) or reserved[i] or i in start_set:
            continue
        moisture, temp, sand = band_moisture[band[i]], temperature[i // w], sandy[band[i]]
        if coastal[i] and temp >= 18 and 20 <= moisture <= 85 and filled[i] <= 1000:
            species = 4
        elif not sand and 35 <= moisture <= 90 and -5 <= temp <= 35:
            species = 1
        elif 20 <= moisture <= 80 and -20 <= temp <= 25:
            species = 2
        elif sand and moisture <= 30 and temp >= 10:
            species = 3
        else:
            continue
        eligible.append((i, species))
    cover = choose("vegetation-density", config["vegetation"]["suitable_site_density_pct"])
    groves = octave("forest-clusters", max(4, min(40, small // 10)))
    tree_salt = draw("tree-fine")
    eligible.sort(key=lambda item: (groves[item[0]] * 1024 + _mix(tree_salt, item[0]) % 1024, item[0]))
    for i, species in eligible[:len(eligible) * cover // 100]:
        tree[i] = species
    del groves

    # --- 6. Typed IR ----------------------------------------------------------
    resource_name = ("NONE", "FOOD", "WOOD", "STONE")
    tree_name = ("NONE", "BROADLEAF", "PINE", "CACTUS", "PALM")
    sea_cell = ground(terrain="WATER", water="SEA", salinity="SALT", body="sea", depth_cm=200, soil="SILT", biome="COAST")
    grid = []
    for y in range(h):
        row = []
        temp = temperature[y]
        sea_row = dict(sea_cell, temperature_c=temp)     # one shared record for the row's sea
        for x in range(w):
            i = y * w + x
            k = kind[i]
            if k == SEA:
                row.append(sea_row)
                continue
            name = bands[band[i]]
            c = dict(terrain="WATER", biome="COAST" if coastal[i] else name, soil="SILT", elevation_m=filled[i],
                     moisture=band_moisture[band[i]], temperature_c=temp, water="NONE", salinity="NONE", depth_cm=0,
                     body="", blocked=False, tree="NONE", resource="NONE", hazard=False)
            if k == LAKE:
                c.update(water="LAKE", salinity="FRESH", depth_cm=200, body="lake-%d" % lake_of[i])
            elif k == RIVER:
                c.update(water="RIVER", salinity="FRESH", depth_cm=30, body="river-%d" % river_of[i])
            elif k == SWAMP:
                c.update(water="SWAMP", salinity="FRESH", depth_cm=30, body="wetlands", moisture=max(80, c["moisture"]))
            else:
                c.update(terrain=("PLAIN", "HILL", "MOUNTAIN", "BEACH")[k - PLAIN],
                         soil="ROCK" if k == MOUNTAIN else "SAND" if k == BEACH or sandy[band[i]] else "LOAM",
                         blocked=k == MOUNTAIN, tree=tree_name[tree[i]], resource=resource_name[resource[i]])
            row.append(c)
        grid.append(row)
    reserve = ground(terrain="ROCK", biome="CAVERN", soil="ROCK", blocked=True)
    underground = [[reserve] * w for _ in range(h)]
    rivers = []
    for k, (path, source, sink) in enumerate(segments):
        rid = "river-%d" % (k + 1)
        if sink[0] == "SEA":
            end = dict(kind="SEA", target="sea")
        elif sink[0] == "LAKE":
            end = dict(kind="LAKE", target="lake-%d" % sink[1])
        else:
            end = dict(kind="RIVER", target="river-%d" % river_of[sink[1]])
        rivers.append(dict(id=rid, path=[[q % w, q // w, "SURFACE"] for q in path],
                           source=dict(kind="LAKE", target="lake-%d" % source) if source else dict(kind="SPRING", target=""),
                           sink=end))
    outflow = {lake: "river-%d" % river_of[start] for start, lake in lake_start.items()}
    lakes = [dict(id="lake-%d" % lake, terminal_basin=lake not in outflow, outflow=outflow.get(lake, "")) for lake in sorted(outlet)]
    doc = dict(schema=LAND_VERSION, seed=seed, algorithm_version=ALGORITHM_VERSION, content_version=CONTENT_VERSION,
               profile_version=PROFILE_VERSION, profile="SURFACE", active_layer="SURFACE", width=w, height=h,
               layers={"SURFACE": {"native_z": 2, "cells": grid}, "UNDERGROUND": {"native_z": 1, "cells": underground}},
               ports=[], rivers=rivers, lakes=lakes, starts=[[i % w, i // w, "SURFACE"] for i in starts], portals=[],
               policy=dict(mountain_min_area=MIN_RANGE, mountain_max_components=max(1, range_count), max_moisture_step=25,
                           max_temperature_step=10, max_resource_distance=max_route, max_water_distance=max_route,
                           ship_radius=0, ocean_ports_min=1, land_components_min=1, start_count=len(starts),
                           river_half_width=half_width, max_path_uphill_m=0))
    reasons = validate(doc)
    if reasons:
        raise Rejection("INVARIANT_REJECTED", json.dumps(reasons[:20], sort_keys=True))
    counts = {}
    for k in kind:
        counts[k] = counts.get(k, 0) + 1
    names = ("SEA", "LAKE", "RIVER", "SWAMP", "PLAIN", "HILL", "MOUNTAIN", "BEACH")
    manifest = seed_manifest(config, ALGORITHM_VERSION, CONTENT_VERSION, PROFILE_VERSION)
    manifest.update(status="GENERATED_VALID_OFFLINE_IR",
                    generation_result={"ir_sha256": canonical_hash(doc), "validation_errors": [], "native_acceptance": "NOT_RUN"},
                    generated_topology=dict(lands=len([s for s in land_sizes[1:] if s >= MIN_ISLET]), islands_asked=island_count,
                                            rivers=len(rivers), lakes=len(lakes), ranges=range_count, starts=len(starts),
                                            lake_sites=len(bowls), river_flow_threshold=threshold, channel_half_width=half_width),
                    realized_cells={names[k]: counts[k] for k in sorted(counts)},
                    abstract_routes=routes, eligible_vegetation_sites=len(eligible), selected_vegetation_density_pct=cover,
                    cave_layer="UNGENERATED_BLOCKED_RESERVE", reference_matching="NOT_EVALUATED")
    return doc, manifest


def generate(config, *, traversal="forward"):
    """One bounded candidate, no retries or repair; the caller logs a rejection."""
    if traversal not in {"forward", "reverse"}:
        raise ValueError("traversal")
    try:
        doc, manifest = _generate(deepcopy(config))
        return {"status": "GENERATED_VALID_OFFLINE_IR", "document": doc, "manifest": manifest, "reasons": []}
    except Rejection as e:
        return {"status": "REJECTED_OFFLINE_CANDIDATE", "document": None, "manifest": None,
                "reasons": [{"code": e.code, "detail": e.detail}], "configuration_sha256": canonical_hash(config)}
