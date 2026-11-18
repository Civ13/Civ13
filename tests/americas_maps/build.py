"""Generate the two Americas region maps for Nomads.

    maps/nomads/nomads_americas_north.dmm
    maps/nomads/nomads_americas_south.dmm

Both maps are original designs drawn by this file: each continent is a set of
hand-placed outlines, mountain chains, rivers, lakes and climate centres
(continents.py), turned into terrain here with seeded noise so coasts, biome
borders and ridges look natural. Nothing is copied from another map.

Coordinates in continents.py are rough longitude west / latitude pairs, which
is only a convenient way to place features; a frame per continent maps them to
tiles. The DMM is one level (the surface, z 1). Row 1 of the grid is the north
edge; game y counts from the south.

Run from the repository root (needs numpy and Pillow):

    python3 -I -B tests/americas_maps/build.py            # both maps
    python3 -I -B tests/americas_maps/build.py --only north --preview out.png

Do not hand-edit the generated maps; change this file or continents.py and
regenerate, then regenerate the height and river files (docs/americas-regions.md).
"""
import argparse
import heapq
import math
import sys
from collections import deque
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))

import continents  # noqa: E402

try:
    import numpy as np
    from PIL import Image, ImageDraw, ImageFilter
except ImportError:  # pragma: no cover - developer tool
    sys.exit('build.py needs numpy and Pillow (pip install numpy Pillow)')

SS = 3  # supersampling for drawn shapes

# Biome -> area type.
AREAS = {
    'tundra': '/area/caribbean/nomads/snow',
    'taiga': '/area/caribbean/nomads/taiga',
    'forest': '/area/caribbean/nomads/forest',
    'semiarid': '/area/caribbean/nomads/semiarid',
    'desert': '/area/caribbean/nomads/desert',
    'jungle': '/area/caribbean/nomads/forest/Jungle',
    'savanna': '/area/caribbean/nomads/forest/savanna',
    'swamp': '/area/caribbean/colonies/swamp',
}
BIOMES = list(AREAS)
SEA_AREA = '/area/caribbean/sea/sea'
CAVE_AREA = '/area/caribbean/void/caves'
ADMIN_AREA = '/area/caribbean/admin'

T_SEA = '/turf/floor/beach/water/deep/saltwater'
T_SHALLOW = '/turf/floor/beach/water/shallowsaltwater'
T_ICE = '/turf/floor/beach/water/ice/salty'
T_RIVER = '/turf/floor/beach/water'
T_RIVER_JUNGLE = '/turf/floor/beach/water/jungle'
T_DEEP = '/turf/floor/beach/water/deep'
T_SWAMP = '/turf/floor/beach/water/swamp'
T_FLOODED = '/turf/floor/beach/water/flooded'
T_GRASS = '/turf/floor/grass'
T_JUNGLE = '/turf/floor/grass/jungle'
T_SAVANNA = '/turf/floor/grass/jungle/savanna'
T_WINTER = '/turf/floor/winter'
T_WINTER_GRASS = '/turf/floor/winter/grass'
T_DIRT = '/turf/floor/dirt'
T_DUST = '/turf/floor/dirt/dust'
T_JUNGLEDIRT = '/turf/floor/dirt/jungledirt'
T_SAND = '/turf/floor/beach/sand'
T_SAND_DARK = '/turf/floor/beach/sand/dark'
T_SAND_DESERT = '/turf/floor/beach/sand/desert'
T_ROCK = '/turf/floor/dirt/underground'
T_ROCK_ICY = '/turf/floor/dirt/underground/icy'
T_ROCK_SANDY = '/turf/floor/dirt/underground/sandy'
T_ROCKWALL = '/turf/wall/rockwall'
T_LAVA = '/turf/floor/lava/permanent'
T_DRY_LAVA = '/turf/floor/dirt/dry_lava'
T_BLACK = '/turf/wall/indestructable/black'

O_LANDMARK = '/obj/effect/landmark{icon_state = "x3"; name = "JoinLateCiv"}'
O_PUDDLE = '/obj/structure/sink/puddle'
O_OIL = '/obj/structure/oil_spring'
O_WOLFCAVE = '/obj/structure/animalspawner/wolfcave/full'
SPAWNERS = {
    'forest': ('/obj/effect/spawner/objspawner/tree',),
    'taiga': ('/obj/effect/spawner/objspawner/pine',),
    'tundra': ('/obj/effect/spawner/objspawner/pine/snow',),
    'jungle': ('/obj/effect/spawner/objspawner/jungle', '/obj/effect/spawner/objspawner/palm'),
    'savanna': ('/obj/effect/spawner/objspawner/medpine',),
    'semiarid': ('/obj/effect/spawner/objspawner/medpine', '/obj/effect/spawner/objspawner/tree'),
    'swamp': ('/obj/effect/spawner/objspawner/tree',),
}
# One grove spawner per this many land tiles of the biome.
SPAWNER_SPACING = {'forest': 420, 'taiga': 380, 'tundra': 2400, 'jungle': 300, 'savanna': 1100, 'semiarid': 1500, 'swamp': 500}


class Frame:
    """Maps (longitude west, latitude) to tile coordinates of one map."""

    def __init__(self, spec, width, height):
        self.w, self.h = width, height
        self.lon_w, self.lon_e = spec['lon']
        self.lat_n, self.lat_s = spec['lat']
        self.dx = width / (self.lon_w - self.lon_e)    # tiles per degree of longitude
        self.dy = height / (self.lat_n - self.lat_s)   # tiles per degree of latitude

    def xy(self, lon, lat):
        return ((self.lon_w - lon) * self.dx, (self.lat_n - lat) * self.dy)

    def pts(self, pairs):
        return [self.xy(lon, lat) for lon, lat in pairs]


def _box(a, r, axis):
    if r <= 0:
        return a
    pad = [(0, 0), (0, 0)]
    pad[axis] = (r + 1, r)
    c = np.cumsum(np.pad(a, pad, mode='edge'), axis=axis, dtype=np.float64)
    n = a.shape[axis]
    hi = np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=axis)
    lo = np.take(c, np.arange(0, n), axis=axis)
    return ((hi - lo) / (2 * r + 1)).astype(np.float32)


def blur(a, radius):
    """Three box blurs: close to a Gaussian of that radius, and exact to repeat."""
    a = np.asarray(a, dtype=np.float32)
    r = max(1, int(round(radius)))
    for _ in range(3):
        a = _box(_box(a, r, 0), r, 1)
    return a


def value_noise(rng, w, h, cell):
    """Smooth noise in -1..1 with features about `cell` tiles across."""
    gw, gh = max(2, int(w / cell) + 3), max(2, int(h / cell) + 3)
    lattice = rng.random((gh, gw), dtype=np.float32)
    img = Image.fromarray(lattice, mode='F').resize((gw * 8, gh * 8), Image.BICUBIC)
    cw, ch = int(w * 8 / cell), int(h * 8 / cell)
    img = img.crop((8, 8, 8 + max(cw, 1), 8 + max(ch, 1))).resize((w, h), Image.BICUBIC)
    return np.asarray(img, dtype=np.float32) * 2 - 1


def fbm(rng, w, h, cell, octaves=3):
    total = np.zeros((h, w), dtype=np.float32)
    amp, norm = 1.0, 0.0
    for _ in range(octaves):
        total += amp * value_noise(rng, w, h, max(cell, 2))
        norm += amp
        amp *= 0.5
        cell /= 2.2
    return total / norm


class Painter:
    """Draws antialiased shapes in tile coordinates into a float field."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new('L', (w * SS, h * SS), 0)
        self.draw = ImageDraw.Draw(self.img)

    def polygon(self, pts, value=255):
        self.draw.polygon([(x * SS, y * SS) for x, y in pts], fill=value)

    def ellipse(self, cx, cy, rx, ry, value=255):
        self.draw.ellipse([(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS], fill=value)

    def stroke(self, pts, width, width_end=None, value=255):
        """A polyline as overlapping discs; the width may taper along it."""
        width_end = width if width_end is None else width_end
        dense = resample(pts, 0.5)
        n = max(len(dense) - 1, 1)
        for i, (x, y) in enumerate(dense):
            r = (width + (width_end - width) * i / n) / 2
            self.draw.ellipse([(x - r) * SS, (y - r) * SS, (x + r) * SS, (y + r) * SS], fill=value)

    def field(self):
        small = self.img.resize((self.w, self.h), Image.BOX)
        return np.asarray(small, dtype=np.float32) / 255


def resample(pts, step):
    out = [pts[0]]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        n = max(1, int(math.hypot(x1 - x0, y1 - y0) / step))
        for i in range(1, n + 1):
            out.append((x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n))
    return out


def meander(rng, pts, amplitude, wavelength=26.0):
    """Bends a polyline sideways with a few sine waves; the ends stay put."""
    dense = resample(pts, 3.0)
    if len(dense) < 4:
        return dense
    length = 3.0 * (len(dense) - 1)
    waves = [(rng.uniform(0.6, 1.4) * wavelength, rng.uniform(0, 6.283), rng.uniform(0.5, 1.0)) for _ in range(3)]
    out = []
    for i, (x, y) in enumerate(dense):
        x0, y0 = dense[max(i - 1, 0)]
        x1, y1 = dense[min(i + 1, len(dense) - 1)]
        dx, dy = x1 - x0, y1 - y0
        norm = math.hypot(dx, dy) or 1.0
        s = 3.0 * i
        taper = min(1.0, s / 18.0, (length - s) / 18.0)
        off = sum(a * math.sin(6.283 * s / wl + ph) for wl, ph, a in waves) / 2.0 * amplitude * max(taper, 0.0)
        out.append((x - dy / norm * off, y + dx / norm * off))
    return out


def grow(mask, steps=1):
    out = mask.copy()
    for _ in range(steps):
        g = out.copy()
        g[1:, :] |= out[:-1, :]
        g[:-1, :] |= out[1:, :]
        g[:, 1:] |= out[:, :-1]
        g[:, :-1] |= out[:, 1:]
        out = g
    return out


def distance(mask, cap):
    """4-neighbour distance from True cells, capped."""
    dist = np.full(mask.shape, cap, dtype=np.int16)
    reached = mask.copy()
    dist[reached] = 0
    for d in range(1, cap):
        g = grow(reached)
        dist[g & ~reached] = d
        reached = g
    return dist


def components(mask):
    """4-connected labels (from 1) and sizes."""
    h, w = mask.shape
    labels = np.zeros((h, w), dtype=np.int32)
    sizes = [0]
    flat = mask
    for sy, sx in zip(*np.nonzero(mask)):
        if labels[sy, sx]:
            continue
        label = len(sizes)
        labels[sy, sx] = label
        queue = deque([(sy, sx)])
        size = 0
        while queue:
            y, x = queue.popleft()
            size += 1
            if y > 0 and flat[y - 1, x] and not labels[y - 1, x]:
                labels[y - 1, x] = label
                queue.append((y - 1, x))
            if y < h - 1 and flat[y + 1, x] and not labels[y + 1, x]:
                labels[y + 1, x] = label
                queue.append((y + 1, x))
            if x > 0 and flat[y, x - 1] and not labels[y, x - 1]:
                labels[y, x - 1] = label
                queue.append((y, x - 1))
            if x < w - 1 and flat[y, x + 1] and not labels[y, x + 1]:
                labels[y, x + 1] = label
                queue.append((y, x + 1))
        sizes.append(size)
    return labels, sizes


def build(name, width=None, height=None):
    spec = continents.MAPS[name]
    w = width or spec['size'][0]
    h = height or spec['size'][1]
    rng = np.random.default_rng(spec['seed'])
    fr = Frame(spec, w, h)
    scale = w / spec['design_width']  # widths given in tiles scale with the map

    # ---- land ----------------------------------------------------------
    p = Painter(w, h)
    for poly in spec['land']:
        p.polygon(fr.pts(poly))
    for poly, factor in spec.get('islands', []):
        pts = fr.pts(poly)
        cx = sum(x for x, _ in pts) / len(pts)
        cy = sum(y for _, y in pts) / len(pts)
        pts = [(cx + (x - cx) * factor, cy + (y - cy) * factor) for x, y in pts]
        if len(pts) > 5:
            p.polygon(pts)
            continue
        # A small island: a few overlapping lobes inside its outline, so the
        # shore is rounded and irregular rather than a drawn polygon.
        rx = (max(x for x, _ in pts) - min(x for x, _ in pts)) / 2
        ry = (max(y for _, y in pts) - min(y for _, y in pts)) / 2
        for _ in range(4):
            ox, oy = rng.uniform(-0.45, 0.45) * rx, rng.uniform(-0.45, 0.45) * ry
            p.ellipse(cx + ox, cy + oy, rx * rng.uniform(0.5, 0.8), ry * rng.uniform(0.5, 0.8))
    drawn = p.field()
    coast = blur(drawn, 2.2 * scale) + 0.20 * fbm(rng, w, h, 30 * scale) + 0.09 * value_noise(rng, w, h, 6)
    land = coast > 0.5
    p = Painter(w, h)
    for pts, width_tiles in spec.get('land_strokes', []):
        p.stroke(fr.pts(pts), width_tiles)
    land |= (p.field() + 0.12 * value_noise(rng, w, h, 5)) > 0.5
    p = Painter(w, h)
    for pts, width_tiles in spec.get('sea_strokes', []):
        p.stroke(fr.pts(pts), width_tiles)
    land &= ~(p.field() > 0.5)
    # Drop specks of land and fill specks of water.
    labels, sizes = components(land)
    small = np.array([s < 10 for s in sizes])
    land &= ~small[labels]
    labels, sizes = components(~land)
    border = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))) - {0}
    sea = np.isin(labels, list(border))
    pockets = ~land & ~sea
    land |= pockets  # enclosed noise ponds become land; lakes are drawn below

    # ---- fresh water ---------------------------------------------------
    p = Painter(w, h)
    for lon, lat, rx, ry in spec['lakes']:
        cx, cy = fr.xy(lon, lat)
        p.ellipse(cx, cy, rx * fr.dx, ry * fr.dy)
    # A wide soft edge lets the noise bend the shore into bays and points.
    lake = ((blur(p.field(), 5.0 * scale) + 0.38 * fbm(rng, w, h, 16 * scale, 3) + 0.08 * value_noise(rng, w, h, 5)) > 0.5) & land
    river = np.zeros((h, w), dtype=bool)
    channel = np.zeros((h, w), dtype=bool)
    p = Painter(w, h)
    pc = Painter(w, h)
    for pts, w0, w1 in spec['rivers']:
        line = meander(rng, fr.pts(pts), amplitude=5.0)
        p.stroke(line, max(w0 * 1.0, 1.6), max(w1 * 1.0, 1.6))
        if w1 >= 5:
            # A deep channel down the middle of the wide reach, with fords.
            dense = resample(line, 0.5)
            n = len(dense)
            for i, (x, y) in enumerate(dense):
                wd = w0 + (w1 - w0) * i / max(n - 1, 1)
                along = i * 0.5
                if wd >= 5 and (along % 90.0) > 9.0:
                    r = (wd - 3.4) / 2
                    pc.draw.ellipse([(x - r) * SS, (y - r) * SS, (x + r) * SS, (y + r) * SS], fill=255)
    river = (p.field() > 0.42) & land
    channel = (pc.field() > 0.5) & river
    drawn_river = river.copy()

    # ---- biomes --------------------------------------------------------
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    best = np.full((h, w), -1e9, dtype=np.float32)
    biome = np.zeros((h, w), dtype=np.int8)
    for kind, lon, lat, rx, ry in spec['biomes']:
        cx, cy = fr.xy(lon, lat)
        d = np.sqrt(((xx - cx) / (rx * fr.dx)) ** 2 + ((yy - cy) / (ry * fr.dy)) ** 2)
        score = 1.0 - d
        take = score > best
        best[take] = score[take]
        biome[take] = BIOMES.index(kind)
    # Wobble the borders: re-pick with noise added per biome.
    scores = []
    for index, kind in enumerate(BIOMES):
        s = np.full((h, w), -1e9, dtype=np.float32)
        for k, lon, lat, rx, ry in spec['biomes']:
            if k != kind:
                continue
            cx, cy = fr.xy(lon, lat)
            d = np.sqrt(((xx - cx) / (rx * fr.dx)) ** 2 + ((yy - cy) / (ry * fr.dy)) ** 2)
            s = np.maximum(s, 1.0 - d)
        scores.append(s + 0.22 * fbm(rng, w, h, 34 * scale, 2) + 0.06 * value_noise(rng, w, h, 7))
    biome = np.argmax(np.stack(scores), axis=0).astype(np.int8)
    cold = (biome == BIOMES.index('tundra')) | (biome == BIOMES.index('taiga'))

    # ---- mountains -----------------------------------------------------
    p = Painter(w, h)
    for pts, width_tiles in spec['mountains']:
        # The range swells and narrows along its length.
        line = resample(meander(rng, fr.pts(pts), amplitude=4.0, wavelength=34.0), 14.0)
        widths = [width_tiles * scale * 1.7 * rng.uniform(0.62, 1.3) for _ in line]
        for i in range(len(line) - 1):
            p.stroke(line[i:i + 2], widths[i], widths[i + 1])
    for poly in spec.get('massifs', []):
        p.polygon(fr.pts(poly))
    ridge = blur(p.field(), 2.6 * scale) + 0.30 * fbm(rng, w, h, 13 * scale, 3) + 0.07 * value_noise(rng, w, h, 4)
    p = Painter(w, h)
    for pts, width_tiles in spec['passes']:
        p.stroke(meander(rng, fr.pts(pts), amplitude=2.2, wavelength=14.0), width_tiles)
    gap = (p.field() + 0.10 * value_noise(rng, w, h, 4)) > 0.35

    # ---- relief and drainage -------------------------------------------
    # Height above the sea in metres: a ramp up from the coast, rolling
    # hills, the mountain chains, and valleys along the drawn rivers.
    inland = np.clip((blur(land.astype(np.float32), 30 * scale) - 0.5) * 2.0, 0.0, 1.0)
    elev = 15.0 + 200.0 * inland ** 0.9
    elev += 170.0 * np.clip(fbm(rng, w, h, 26 * scale, 3), 0.0, None) + 50.0 * fbm(rng, w, h, 9 * scale, 2)
    # Foothills spread wide of each range; the range itself climbs to its crest.
    elev += 260.0 * np.clip(blur(np.clip(ridge, 0.0, 1.0), 10 * scale) - 0.15, 0.0, 1.0)
    high = 950.0 * np.clip(ridge - 0.45, 0.0, 1.2) ** 1.2
    high[gap] *= 0.25
    elev += high
    elev -= 90.0 * blur(drawn_river.astype(np.float32), 7 * scale) + 60.0 * blur(lake.astype(np.float32), 6 * scale)
    elev = np.maximum(elev, 4.0)
    # Rain: the share of its water each tile sends downhill.
    rain = np.zeros((h, w), dtype=np.float32)
    for index, kind in enumerate(BIOMES):
        rain[biome == index] = RAIN[kind]
    # Streams wander: the drainage reads the relief through a fine grain, so a
    # course bends round small rises instead of running straight down a slope.
    grain = 26.0 * value_noise(rng, w, h, 5) + 18.0 * value_noise(rng, w, h, 11) + 12.0 * rng.random((h, w), dtype=np.float32)
    parent, order, filled = drainage(elev + grain, land, lake | drawn_river, sea)
    filled -= grain
    acc = accumulate(parent, order, rain)
    # The tiles that gather the most land become rivers that join the drawn
    # ones: tributaries, and streams on the islands and the far coasts.
    open_land = land & ~lake & ~drawn_river
    share = spec.get('tributary_share', 0.011)
    level = np.quantile(acc[open_land], 1.0 - share) if open_land.any() else 0.0
    tributary = open_land & (acc >= level)
    # Drop stray scraps that touch no other water, then widen the big ones.
    labels, sizes = components(tributary | lake | drawn_river)
    keep = np.array([s >= 12 for s in sizes])
    tributary &= keep[labels]
    wide = tributary & (acc >= level * 9.0)
    tributary |= grow(wide, 1) & open_land
    river |= tributary
    # Hollows the drainage had to fill deep become ponds and small lakes.
    depth = filled - elev
    pond = open_land & ~river & (depth > spec.get('pond_depth', 26.0)) & (ridge < 0.5)
    for kind in spec.get('dry_biomes', ()):  # lands whose deserts hold no standing water
        pond &= biome != BIOMES.index(kind)
    labels, sizes = components(pond)
    keep = np.array([10 <= s <= 2500 * scale * scale for s in sizes])
    pond &= keep[labels]
    lake |= pond
    river &= ~lake

    fresh = lake | river
    lake_deep = lake & (distance(~lake, 4) >= 3)
    dry = land & ~fresh
    d_sea = distance(sea, 24)
    d_water = distance(~dry, 24)
    rock = (ridge > 0.56) & dry & ~gap & (d_water >= 2) & ~grow(river, 2)
    # High valleys: open ground inside the widest massifs, reached by a pass.
    inner = distance(~rock, 8)
    valley = rock & (inner >= 4) & (fbm(rng, w, h, 11 * scale, 2) > 0.34)
    rock &= ~valley
    core = (ridge > 1.0) & rock & (distance(~rock, 8) >= 5) & (value_noise(rng, w, h, 9) > -0.1)
    volcano_lava = np.zeros((h, w), dtype=bool)
    volcano_ash = np.zeros((h, w), dtype=bool)
    for lon, lat, r in spec.get('volcanoes', []):
        cx, cy = fr.xy(lon, lat)
        d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) + 1.5 * value_noise(rng, w, h, 5)
        volcano_lava |= (d < r * 0.35) & land
        volcano_ash |= (d < r * 0.75) & land & ~volcano_lava
        rock |= (d < r) & (d >= r * 0.75) & dry & (d_water >= 2)
        # One way into the crater, from the south.
        rock &= ~((np.abs(xx - cx) < 1.6) & (yy > cy) & (yy < cy + r + 2))
        elev += np.clip(r * 1.6 - d, 0.0, None) * 28.0
    rock &= ~(volcano_lava | volcano_ash)
    core &= rock

    # Open every walled-in pocket of walkable ground to the rest of its land.
    walk = dry & ~rock & ~volcano_lava
    rock = open_pockets(walk, rock, dry)
    core &= rock
    walk = dry & ~rock & ~volcano_lava

    # ---- turfs ---------------------------------------------------------
    turf = np.empty((h, w), dtype=object)
    area = np.empty((h, w), dtype=object)
    for index, kind in enumerate(BIOMES):
        area[biome == index] = AREAS[kind]
    n_a = fbm(rng, w, h, 14 * scale, 3)
    n_b = fbm(rng, w, h, 5, 2)
    n_c = value_noise(rng, w, h, 3)

    def put(mask, path):
        turf[mask] = path

    b = {kind: (biome == i) for i, kind in enumerate(BIOMES)}
    put(b['tundra'], T_WINTER)
    put(b['tundra'] & (n_a > 0.45), T_WINTER_GRASS)
    put(b['taiga'], T_WINTER_GRASS)
    put(b['taiga'] & (n_a < -0.15), T_WINTER)
    put(b['taiga'] & (n_a > 0.5), T_GRASS)
    put(b['forest'], T_GRASS)
    put(b['forest'] & (n_b > 0.62), T_DIRT)
    put(b['semiarid'], T_GRASS)
    put(b['semiarid'] & (n_a > 0.05), T_DUST)
    put(b['semiarid'] & (n_b > 0.5), T_DIRT)
    put(b['desert'], T_SAND_DESERT)
    put(b['desert'] & (n_a > 0.25), T_DUST)
    put(b['jungle'], T_JUNGLE)
    put(b['jungle'] & (n_b > 0.66), T_JUNGLEDIRT)
    put(b['jungle'] & (n_b < -0.55) & (d_water <= 5) & (d_water >= 1), T_FLOODED)
    put(b['savanna'], T_SAVANNA)
    put(b['savanna'] & (n_a > 0.35), T_DUST)
    # Fertile banks: dry grass and desert sand cannot be ploughed, so the dry
    # lands are farmed beside their rivers and lakes, within reach of the water.
    d_bank = distance(river | lake | channel | lake_deep, 5)
    put(b['savanna'] & (d_bank <= 3), T_GRASS)
    put(b['savanna'] & (d_bank <= 3) & (n_b > 0.3), T_DIRT)
    put(b['desert'] & (d_bank <= 2), T_DIRT)
    put(b['swamp'], T_GRASS)
    put(b['swamp'] & (n_b > 0.25), T_DIRT)
    put(b['swamp'] & (n_b < -0.22), T_SWAMP)

    # Beaches: sand along the sea, except on the cold coasts.
    beach_w = 1 + (n_a > 0.1).astype(np.int16) + (n_c > 0.55).astype(np.int16)
    beach = dry & (d_sea <= beach_w) & ~cold
    put(beach, T_SAND)
    put(beach & b['desert'], T_SAND_DESERT)
    put(beach & b['jungle'] & (n_b > 0.0), T_SAND_DARK)

    # Mountains: rock to mine; the highest cores are bare cave wall.
    put(rock, T_ROCK)
    put(rock & cold, T_ROCK_ICY)
    put(rock & b['desert'], T_ROCK_SANDY)
    put(core, T_ROCKWALL)
    area[rock] = CAVE_AREA
    put(volcano_ash, T_DRY_LAVA)
    put(volcano_lava, T_LAVA)

    # Fresh water.
    put(river, T_RIVER)
    put(river & b['jungle'], T_RIVER_JUNGLE)
    put(channel, T_DEEP)
    put(lake, T_RIVER)
    put(lake & b['jungle'], T_RIVER_JUNGLE)
    put(lake_deep, T_DEEP)

    # The sea: deep, with shallows along the shore and ice in the far cold.
    put(sea, T_SEA)
    area[sea] = SEA_AREA
    d_land = distance(land, 12)
    shallow_w = 2 + (n_a > 0.0).astype(np.int16) + (n_b > 0.4).astype(np.int16)
    shallows = sea & (d_land <= shallow_w)
    put(shallows, T_SHALLOW)
    lat = fr.lat_n - yy / fr.dy
    ice_n, ice_s = spec['ice']  # sea ice only north / south of these latitudes
    polar = sea & b['tundra'] & ((lat > ice_n) | (lat < ice_s))
    ice = polar & ((d_land <= 7) | (n_a > 0.3)) & (n_b > -0.72)
    ice |= sea & b['taiga'] & (d_land <= 2) & (n_a > 0.2) & ((lat > ice_n) | (lat < ice_s))
    put(ice, T_ICE)
    area[ice & b['tundra']] = AREAS['tundra']
    area[ice & b['taiga']] = AREAS['taiga']

    # ---- objects -------------------------------------------------------
    objects = {}
    open_ground = walk & ~beach & ~volcano_ash & (turf != T_SWAMP) & (turf != T_FLOODED)
    d_block = distance(~open_ground, 12)

    def scatter(kind_mask, spacing, paths, margin=3):
        cells = np.argwhere(kind_mask & (d_block >= margin))
        count = int(kind_mask.sum() / spacing)
        if not len(cells) or count <= 0:
            return
        picks = cells[rng.choice(len(cells), size=min(count, len(cells)), replace=False)]
        for i, (y, x) in enumerate(picks):
            if (y, x) not in objects:
                objects[(y, x)] = paths[i % len(paths)]

    for kind, paths in SPAWNERS.items():
        scatter(b[kind] & open_ground, SPAWNER_SPACING[kind], paths)
    d_fresh = distance(fresh, 24)
    thirsty = (b['desert'] | b['semiarid'] | b['savanna']) & open_ground & (d_fresh >= 18)
    scatter(thirsty, 900, (O_PUDDLE,), margin=2)
    scatter(open_ground & (d_fresh >= 23) & ~thirsty, 2600, (O_PUDDLE,), margin=2)
    oily = (b['desert'] | b['semiarid'] | b['taiga'] | b['tundra'] | b['swamp']) & open_ground
    scatter(oily, 2600, (O_OIL,), margin=2)
    scatter((b['jungle'] | b['savanna'] | b['forest']) & open_ground, 9000, (O_OIL,), margin=2)
    scatter((b['taiga'] | b['forest']) & open_ground & (distance(rock, 10) <= 6), 5200, (O_WOLFCAVE,), margin=2)

    marks = []
    for lon, lat in spec['starts']:
        cx, cy = fr.xy(lon, lat)
        spot = nearest(open_ground & (d_block >= 5), cx, cy)
        if spot:
            objects[spot] = O_LANDMARK
            marks.append(spot)

    trails = []
    for trail in spec['trails']:
        placed = place_trail(trail, walk, turf, objects, w, h)
        trails.append((trail, placed))

    # Metadata sits on a black wall in the south-west corner, as on Gaia.
    turf[h - 1, 0] = T_BLACK
    area[h - 1, 0] = ADMIN_AREA
    objects[(h - 1, 0)] = spec['metadata']

    stats = {
        'size': (w, h),
        'land': int(land.sum()),
        'walkable': int(walk.sum()),
        'rock': int(rock.sum()),
        'fresh': int(fresh.sum()),
        'sea': int(sea.sum()),
        'biomes': {kind: int((b[kind] & dry & ~rock).sum()) for kind in BIOMES},
        'starts': len(marks),
        'trails': [(t['id'], len(pl)) for t, pl in trails],
        'objects': len(objects),
    }
    stats['tributaries'] = int(tributary.sum())
    stats['ponds'] = int(pond.sum())
    return turf, area, objects, stats, np.rint(elev).astype(np.int32)


RAIN = {'tundra': 0.5, 'taiga': 0.8, 'forest': 1.0, 'semiarid': 0.35, 'desert': 0.08, 'jungle': 1.5,
        'savanna': 0.6, 'swamp': 1.2}


def drainage(elev, land, water, sea):
    """Priority flood from the sea inwards (as the relief generator of
    tools/procedural_maps does): the lowest reachable tile is always taken
    next, so every tile has a way down that climbs as little as possible.
    Drawn rivers and lakes are taken as soon as they are reached, so the land
    around them drains into them. Returns each tile's downhill neighbour
    (-1 at the sea), the order tiles were taken in, and the filled height."""
    h, w = elev.shape
    n = h * w
    e = elev.ravel().tolist()
    is_land = land.ravel().tolist()
    is_water = water.ravel().tolist()
    parent = [-2] * n
    filled = list(e)
    order = []
    heap = []
    seq = 0
    coast = land & grow(sea, 1)
    for i in np.flatnonzero(coast.ravel()).tolist():
        parent[i] = -1
        heap.append((0.0 if is_water[i] else e[i], seq, i))
        seq += 1
    heapq.heapify(heap)
    push, pop = heapq.heappush, heapq.heappop
    while heap:
        key, _, i = pop(heap)
        order.append(i)
        filled[i] = key if key > e[i] else e[i]
        x = i % w
        for q in (i - w, i + w, i - 1 if x else -1, i + 1 if x < w - 1 else -1):
            if 0 <= q < n and is_land[q] and parent[q] == -2:
                parent[q] = i
                k = key if is_water[q] else (e[q] if e[q] > key else key + 0.01)
                seq += 1
                push(heap, (k, seq, q))
    return parent, order, np.array(filled, dtype=np.float32).reshape(h, w)


def accumulate(parent, order, rain):
    """Water gathered by each tile from everything that drains through it."""
    acc = rain.ravel().astype(np.float64).tolist()
    for i in reversed(order):
        q = parent[i]
        if q >= 0:
            acc[q] += acc[i]
    return np.array(acc, dtype=np.float32).reshape(rain.shape)


def write_sidecars(name, turf, elev, base=None):
    """Hill levels, river currents and flood reaches for one map, by the rules
    generated lands use (tools/procedural_maps/terrain_files.py): water is
    level 0, the ground climbs out of it and follows the relief."""
    sys.path.insert(0, str(ROOT))
    from tools.procedural_maps import terrain_files
    terrain_heights, river_flow, river_flood = terrain_files._scripts()
    h, w = turf.shape
    rows = [[str(t) for t in row] for row in turf.tolist()]
    wet = [['water' in t for t in row] for row in rows]
    metres = elev.tolist()
    cells = [[{'elevation_m': metres[y][x], 'terrain': 'WATER' if wet[y][x] else 'LAND'} for x in range(w)]
             for y in range(h - 1, -1, -1)]
    doc = {'width': w, 'height': h, 'active_layer': 0, 'layers': [{'cells': cells}]}
    levels = [[v / 2 for v in row] for row in reversed(terrain_files.land_levels(doc))]
    base = ROOT / (base or 'maps/heights/nomads_americas_%s' % name)
    terrain_heights.write_heights(str(base) + '.txt', w, h, {1: levels})
    flow = river_flow.build(rows, heights=levels)
    Path(str(base) + '.flow.txt').write_text('%s\nsize %d %d\nz 1\n%s\n' % (river_flow.HEADER, w, h, '\n'.join(flow)),
                                             encoding='ascii', newline='\n')
    built = river_flood.build(rows, levels)
    river_flood.write_flood(str(base) + '.flood.txt', w, h, 1, *built)
    return {'highest_level': max(max(row) for row in levels), 'flowing': sum(c != '.' for row in flow for c in row),
            'reaches': len(built[0]), 'hollows': len(built[3]) if len(built) > 3 else 0}


def write_manifest():
    """Digests of every map and its height, current and flood files, for the
    test suite: it checks them instead of rebuilding the files on every run."""
    import hashlib
    import json
    manifest = {}
    for name in sorted(continents.MAPS):
        base = ROOT / 'maps' / 'heights' / ('nomads_americas_%s' % name)
        files = {'path': ROOT / 'maps' / 'nomads' / ('nomads_americas_%s.dmm' % name), 'heights': Path(str(base) + '.txt'),
                 'flow': Path(str(base) + '.flow.txt'), 'flood': Path(str(base) + '.flood.txt')}
        manifest[name] = {kind: hashlib.sha256(path.read_bytes().replace(b'\r\n', b'\n')).hexdigest()
                          for kind, path in files.items()}
    (Path(__file__).resolve().parent / 'sidecars.json').write_text(json.dumps(manifest, indent=1, sort_keys=True) + '\n',
                                                                 encoding='utf-8', newline='\n')


def open_pockets(walk, rock, dry):
    """Carve a two-tile pass from each enclosed walkable pocket to open ground."""
    labels, sizes = components(walk)
    land_labels, _ = components(dry)
    main = {}
    for label in range(1, len(sizes)):
        ys, xs = np.nonzero(labels == label)
        land_id = land_labels[ys[0], xs[0]]
        if land_id not in main or sizes[label] > sizes[main[land_id]]:
            main[land_id] = label
    h, w = walk.shape
    rock = rock.copy()
    order = sorted(range(1, len(sizes)), key=lambda i: -sizes[i])
    joined = {label: True for label in main.values()}
    for label in order:
        if label in joined or sizes[label] < 12:
            continue
        ys, xs = np.nonzero(labels == label)
        land_id = land_labels[ys[0], xs[0]]
        target = main[land_id]
        if target == label:
            continue
        # Breadth-first through rock from the pocket to any joined ground.
        prev = {}
        queue = deque()
        for y, x in zip(ys.tolist(), xs.tolist()):
            prev[(y, x)] = None
            queue.append((y, x))
        end = None
        while queue:
            y, x = queue.popleft()
            lab = labels[y, x]
            if lab and lab != label and joined.get(lab):
                end = (y, x)
                break
            for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= ny < h and 0 <= nx < w and (ny, nx) not in prev and dry[ny, nx] and (rock[ny, nx] or labels[ny, nx]):
                    prev[(ny, nx)] = (y, x)
                    queue.append((ny, nx))
        if end is None:
            continue
        cell = end
        while cell is not None:
            y, x = cell
            for cy, cx in ((y, x), (y, min(x + 1, w - 1)), (min(y + 1, h - 1), x)):
                if rock[cy, cx]:
                    rock[cy, cx] = False
            cell = prev[cell]
        joined[label] = True
    return rock


def nearest(mask, cx, cy, reach=40):
    h, w = mask.shape
    x0, x1 = max(0, int(cx - reach)), min(w, int(cx + reach) + 1)
    y0, y1 = max(0, int(cy - reach)), min(h, int(cy + reach) + 1)
    cells = np.argwhere(mask[y0:y1, x0:x1])
    if not len(cells):
        return None
    d = (cells[:, 0] + y0 - cy) ** 2 + (cells[:, 1] + x0 - cx) ** 2
    y, x = cells[int(np.argmin(d))]
    return (int(y + y0), int(x + x0))


def place_trail(trail, walk, turf, objects, w, h):
    """Trail posts in a row along one map edge, on the walkable tiles there.

    `edge` is n, s, e or w; `at` is the centre along that edge as a 0..1
    fraction; the posts stand `inset` tiles in from the border."""
    edge, at, count, inset = trail['edge'], trail['at'], trail['posts'], trail.get('inset', 3)
    placed = []
    if edge in 'ns':
        y = inset if edge == 'n' else h - 1 - inset
        centre = int(at * w)
        candidates = [x for x in range(max(0, centre - 40), min(w, centre + 41)) if walk[y, x]]
        candidates.sort(key=lambda x: abs(x - centre))
        chosen = sorted(candidates[:count * 3])[::3][:count] if len(candidates) >= count * 3 else candidates[:count]
        for x in chosen:
            objects[(y, x)] = trail['object']
            placed.append((y, x))
    else:
        x = inset if edge == 'w' else w - 1 - inset
        centre = int(at * h)
        candidates = [y for y in range(max(0, centre - 40), min(h, centre + 41)) if walk[y, x]]
        candidates.sort(key=lambda y: abs(y - centre))
        chosen = sorted(candidates[:count * 3])[::3][:count] if len(candidates) >= count * 3 else candidates[:count]
        for y in chosen:
            objects[(y, x)] = trail['object']
            placed.append((y, x))
    return placed


KEY_CHARS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'


def write_dmm(path, turf, area, objects):
    h, w = turf.shape
    tiles = {}
    grid = []
    for y in range(h):
        row = []
        for x in range(w):
            obj = objects.get((y, x))
            tile = (obj, turf[y, x], area[y, x])
            index = tiles.get(tile)
            if index is None:
                index = tiles[tile] = len(tiles)
            row.append(index)
        grid.append(row)
    if len(tiles) > len(KEY_CHARS) ** 2:
        sys.exit(f'{path}: {len(tiles)} tile kinds need three-letter keys')
    # Stable, readable order: plain terrain first, then tiles with objects.
    order = sorted(tiles, key=lambda t: (t[0] is not None, t[1], t[2], t[0] or ''))
    key_of = {}
    lines = []
    for n, tile in enumerate(order):
        key = KEY_CHARS[n // len(KEY_CHARS)] + KEY_CHARS[n % len(KEY_CHARS)]
        key_of[tiles[tile]] = key
        obj, t, a = tile
        parts = ([obj] if obj else []) + [t, a]
        lines.append(f'"{key}" = ({",".join(parts)})')
    lines.append('')
    lines.append('(1,1,1) = {"')
    for row in grid:
        lines.append(''.join(key_of[i] for i in row))
    lines.append('"}')
    Path(path).write_text('\n'.join(lines) + '\n', encoding='utf-8', newline='\n')


PREVIEW = {
    T_SEA: (28, 62, 110), T_SHALLOW: (60, 110, 160), T_ICE: (205, 225, 235), T_RIVER: (70, 130, 200),
    T_RIVER_JUNGLE: (60, 135, 150), T_DEEP: (40, 90, 170), T_SWAMP: (70, 100, 80), T_FLOODED: (80, 120, 95),
    T_GRASS: (88, 150, 70), T_JUNGLE: (40, 110, 50), T_SAVANNA: (150, 160, 80), T_WINTER: (235, 238, 242),
    T_WINTER_GRASS: (170, 195, 165), T_DIRT: (125, 100, 70), T_DUST: (175, 150, 105), T_JUNGLEDIRT: (95, 85, 55),
    T_SAND: (225, 210, 160), T_SAND_DARK: (160, 150, 120), T_SAND_DESERT: (230, 200, 130), T_ROCK: (110, 105, 100),
    T_ROCK_ICY: (150, 160, 170), T_ROCK_SANDY: (160, 135, 100), T_ROCKWALL: (70, 68, 66), T_LAVA: (240, 90, 20),
    T_DRY_LAVA: (60, 45, 45), T_BLACK: (0, 0, 0),
}


def preview(path, turf, objects, zoom=1):
    h, w = turf.shape
    rgb = np.zeros((h, w, 3), dtype=np.uint8)
    for t, colour in PREVIEW.items():
        rgb[turf == t] = colour
    for (y, x), obj in objects.items():
        if obj == O_LANDMARK:
            rgb[max(0, y - 1):y + 2, max(0, x - 1):x + 2] = (255, 0, 255)
        elif 'region_gate' in obj:
            rgb[max(0, y - 1):y + 2, max(0, x - 1):x + 2] = (255, 255, 0)
    img = Image.fromarray(rgb, 'RGB')
    if zoom != 1:
        img = img.resize((w * zoom, h * zoom), Image.NEAREST)
    img.save(path)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('--only', choices=sorted(continents.MAPS))
    parser.add_argument('--size', help='WIDTHxHEIGHT override (benchmarks)')
    parser.add_argument('--out', help='output .dmm (with --only)')
    parser.add_argument('--preview', help='also write a flat colour overview PNG (with --only)')
    args = parser.parse_args(argv)
    for name in ([args.only] if args.only else sorted(continents.MAPS)):
        size = [int(v) for v in args.size.split('x')] if args.size else (None, None)
        turf, area, objects, stats, elev = build(name, *size)
        out = Path(args.out) if args.out and args.only else ROOT / continents.MAPS[name]['path']
        write_dmm(out, turf, area, objects)
        if args.preview and args.only:
            preview(args.preview, turf, objects)
        if not (args.out or args.size):
            stats['sidecars'] = write_sidecars(name, turf, elev)
        print(name, out, stats)
    if not (args.out or args.size):
        write_manifest()


if __name__ == '__main__':
    main()
