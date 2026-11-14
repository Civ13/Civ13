"""Original 32px art for the fruit trees, the cave crops and two crab foods.

Every pixel comes from the fixed palettes, shapes and coordinates in this file.
There is no external, traced or generated artwork, and no randomness: the leaf
texture is a fixed integer hash of the pixel position. Run with Pillow from the
repository root:

    python3 tests/sprites/create_orchard.py [--preview sheet.png] [--check]

It replaces only these states and leaves every other state untouched:

- icons/farming/fruits.dmi: lemon, lime, orange, apple, sapodilla, sapote,
  olives, cherry, apricot, banana, coconut and cocoa, each with -grow1..-grow6,
  -harvest and -dead. Released under Civ13's AGPL-3.0 licence.
- icons/farming/pocket_stronghold_cave_wheat.dmi: cave_wheat-grow1..-grow6,
  -harvest and -dead.
- icons/farming/pocket_stronghold_plump_helmet.dmi and
  pocket_stronghold_turnip.dmi: -grow1, -grow2, -grow3 and -grow6.
- icons/obj/food/pocket_stronghold_food.dmi: crab_meat_roasted, food_ruined.

The Pocket Stronghold files keep their other states byte for byte and stay
under CC BY-SA 3.0 as adapted works; see icons/farming/ATTRIBUTION.md.

To change the look, edit this script and rerun it; do not hand-edit the states.
`--check` fails when a committed sheet differs from what this script draws.
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
S = 32
BX, BY = 16, 23  # trunk foot: the ground row shared with the other crops
STAGES = ['grow1', 'grow2', 'grow3', 'grow4', 'grow5', 'grow6', 'harvest', 'dead']


def col(h, a=255):
    return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16), a)


def hsh(x, y, seed):
    n = (x * 374761393 + y * 668265263 + seed * 2246822519) & 0xffffffff
    n = ((n ^ (n >> 13)) * 1274126177) & 0xffffffff
    return ((n ^ (n >> 16)) & 0xffff) / 65535.0


class Canvas:
    def __init__(self):
        self.im = Image.new('RGBA', (S, S))
        self.p = self.im.load()

    def px(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < S and 0 <= y < S and c:
            self.p[x, y] = col(c) if isinstance(c, str) else c

    def get(self, x, y):
        return self.p[x, y] if 0 <= x < S and 0 <= y < S else (0, 0, 0, 0)

    def pts(self, c, *pts):
        for x, y in pts:
            self.px(x, y, c)

    def line(self, c, x0, y0, x1, y1):
        x0, y0, x1, y1 = (int(round(v)) for v in (x0, y0, x1, y1))
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        out = []
        while True:
            self.px(x0, y0, c)
            out.append((x0, y0))
            if x0 == x1 and y0 == y1:
                return out
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def stamp(self, x, y, rows, pal, flip=False):
        for j, row in enumerate(rows):
            if flip:
                row = row[::-1]
            for i, ch in enumerate(row):
                if ch != '.':
                    self.px(x + i, y + j, pal[ch])

    def shadow(self, x0, x1, y=BY):
        """Soft contact shadow so the plant sits on the soil."""
        for x in range(x0, x1 + 1):
            if self.get(x, y)[3] == 0:
                self.p[x, y] = (0, 0, 0, 70 if x0 < x < x1 else 40)


def sc(x, y, s):
    return BX + (x - BX) * s, BY + (y - BY) * s


# ------------------------------------------------------------------ trunks
def trunk(c, pts, tones, s=1.0, flare=True):
    """pts: (x, y, width) from the foot upward. tones: dark, mid, light."""
    dark, mid, light = tones
    pts = [(*sc(x, y, s), max(1, round(w * (0.45 + 0.55 * s)) if s < 1 else w)) for x, y, w in pts]
    rows = {}
    for (x0, y0, w0), (x1, y1, w1) in zip(pts, pts[1:]):
        ya, yb = int(round(y0)), int(round(y1))
        for y in range(ya, yb - 1, -1):
            t = 0 if ya == yb else (ya - y) / (ya - yb)
            rows[y] = (x0 + (x1 - x0) * t, max(1, int(round(w0 + (w1 - w0) * t))))
    for y, (cx, w) in rows.items():
        xl = int(round(cx - w / 2.0))
        for i in range(w):
            c.px(xl + i, y, mid if w == 1 else light if i == 0 and w > 2 else dark if i == w - 1 else mid)
    if flare and s > 0.6:
        y = int(round(pts[0][1]))
        cx, w = rows[y]
        xl = int(round(cx - w / 2.0))
        c.px(xl - 1, y, mid)
        c.px(xl + w, y, dark)
    return rows


# ---------------------------------------------------------------- canopies
def canopy(c, blobs, tones, seed, s=1.0, rough=0.22, gaps=0.0, stroke=2):
    """Leafy mass from overlapping lit spheres. tones: outline, dark, mid, light, highlight."""
    blobs = [(*sc(x, y, s), max(1.3, rx * s), max(1.3, ry * s)) for x, y, rx, ry in blobs]
    mask = {}
    for y in range(S):
        for x in range(S):
            best = None
            for i, (cx, cy, rx, ry) in enumerate(blobs):
                nx, ny = (x - cx) / rx, (y - cy) / ry
                d = nx * nx + ny * ny
                if d <= 1 + (hsh(x, y, seed) - 0.5) * 2 * rough:
                    z = math.sqrt(max(0.0, 1 - min(d, 1)))
                    h = z * min(rx, ry) + i * 0.6
                    if best is None or h > best[0]:
                        best = (h, nx, ny, z, i)
            if best:
                mask[x, y] = best
    for (x, y), (_, nx, ny, z, i) in mask.items():
        if gaps and hsh(x * 3 + 1, y * 5 + 2, seed + 7) < gaps * (1.3 - z):
            continue
        light = -0.50 * nx - 0.62 * ny + 0.42 * z
        light += (hsh((x + (y % 2)) // stroke, y, seed + 3) - 0.5) * 0.46
        below, right = (x, y + 1) not in mask, (x + 1, y) not in mask
        above, left = (x, y - 1) not in mask, (x - 1, y) not in mask
        if below or (right and ny > -0.3):
            tone = tones[0]
        elif right or ((above or left) and light < 0.25):
            tone = tones[1]
        elif light < -0.16:
            tone = tones[1]
        elif light < 0.24:
            tone = tones[2]
        elif light < 0.62:
            tone = tones[3]
        else:
            tone = tones[4]
        # the underside of a clump that overlaps the clump below it stays dark
        nb = mask.get((x, y + 1))
        if nb and nb[4] != i and ny > 0.55 and tone in (tones[2], tones[3]):
            tone = tones[1]
        c.px(x, y, tone)
    return mask


def limbs(c, fork, blobs, tones, s=1.0, twigs=False, seed=0):
    """Branches from the fork to each leaf clump; with twigs for a bare tree."""
    fx, fy = sc(*fork, s)
    for i, (x, y, rx, ry) in enumerate(blobs):
        bx, by = sc(x, y, s)
        path = c.line(tones[0] if i % 2 else tones[1], fx, fy, bx, by)
        if twigs:
            for x_, y_ in path[:len(path) // 2]:
                c.px(x_ + 1, y_, tones[0])
                c.px(x_, y_, tones[1])
            for k in range(3):
                a = -math.pi / 2 + (k - 1) * 0.9 + (hsh(i, k, seed) - 0.5) * 0.7
                r = 0.75 * (rx if k != 1 else ry)
                c.line(tones[0], bx, by, bx + math.cos(a) * r, by + math.sin(a) * r * 0.9)


def fruit(c, spots, rows, pal, under=None):
    h = len(rows)
    w = len(rows[0])
    for x, y in spots:
        if under:
            for i in range(w):
                if c.get(x + i, y + h)[3]:
                    c.px(x + i, y + h, under)
        c.stamp(x, y, rows, pal)


def sprout(c, leaf, stem, pairs, reach):
    """grow1 and grow2: a seedling in the species' own leaf colours."""
    top = BY - 1 - 2 * pairs
    for y in range(BY, top, -1):
        c.px(BX, y, stem)
    for k in range(pairs):
        y = BY - 2 - 2 * k
        r = reach - (k == pairs - 1 and pairs > 1)
        for i in range(1, r + 1):
            c.px(BX - i, y - (i == r and r > 1), leaf[4] if i == r else leaf[3])
            c.px(BX + i, y - (i == r and r > 1), leaf[2] if i < r else leaf[3])
        c.px(BX - 1, y + 1, leaf[1])
    c.px(BX, top, leaf[3])
    c.px(BX, top - 1, leaf[4])
    c.shadow(BX - 2, BX + 2)


def blade(c, x, y, ang, length, tones, thick=True):
    """One large leaf: lit upper edge, shaded underside."""
    for i in range(length):
        px_, py_ = x + math.cos(ang) * i, y + math.sin(ang) * i
        if thick and 0 < i < length - 1:
            c.px(px_, py_ + 1, tones[1])
    for i in range(length):
        px_, py_ = x + math.cos(ang) * i, y + math.sin(ang) * i
        c.px(px_, py_, tones[4] if i in (1, 2) and length > 3 else tones[2] if i == length - 1 else tones[3])


def paddle(c, pts, tones, rib, width=2, torn=()):
    """A long arching leaf along a polyline: pale midrib, light above, dark below."""
    path = []
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        seg = Canvas().line('#000000', x0, y0, x1, y1)
        path += seg if not path else seg[1:]
    n = len(path)
    for i, (x, y) in enumerate(path):
        t = i / max(1, n - 1)
        w = 0 if i == 0 else min(width, 1 + int(width * math.sin(math.pi * min(1.0, t * 1.15)) + 0.2)) if i < n - 1 else 0
        px0, py0 = path[max(0, i - 1)]
        px1, py1 = path[min(n - 1, i + 1)]
        steep = abs(py1 - py0) > abs(px1 - px0)
        for k in range(1, w + 1):
            if i in torn and k == w:
                continue
            if steep:
                side = 1 if px1 >= px0 else -1  # outer side of the droop catches less light
                c.px(x - k, y, tones[3] if side > 0 or py1 < py0 else tones[1])
                c.px(x + k, y, tones[1] if side > 0 or py1 < py0 else tones[3])
            else:
                c.px(x, y - k, tones[4] if k == w and i % 3 == 0 else tones[3])
                c.px(x, y + k, tones[1] if k == w else tones[2])
    for i, (x, y) in enumerate(path):
        c.px(x, y, rib if 0 < i < n - 1 else tones[2])
    return path


def frond(c, pts, tones, comb=2):
    """A feather palm frond: a rib with leaflets hanging from it like a comb."""
    path = []
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        seg = Canvas().line('#000000', x0, y0, x1, y1)
        path += seg if not path else seg[1:]
    n = len(path)
    out = 1 if pts[-1][0] >= pts[0][0] else -1
    for i, (x, y) in enumerate(path):
        if i == 0:
            continue
        px0, py0 = path[i - 1]
        steep = abs(y - py0) >= abs(x - px0) and y != py0
        ln = 1 if i < 2 or i > n - 3 else comb
        for k in range(1, ln + 1):
            tone = (tones[3] if i % 2 == 0 else tones[2]) if k < ln or ln == 1 else tones[1] if i % 2 == 0 else None
            if steep:
                c.px(x + out * k, y + k - 1, tone)
            else:
                c.px(x, y + k, tone)
    for i, (x, y) in enumerate(path):
        c.px(x, y, tones[4] if i % 3 == 1 and i < n - 2 else tones[2])


DEAD_BARK = ('#463c34', '#6a5e52', '#8f8376')
DEAD_LEAF = ('#7a5a24', '#9c7a34', '#b8974a')

TREES = {
    'lemon': dict(
        leaf=('#17381a', '#22541d', '#34761f', '#4f9a27', '#7cc23a'),
        bark=('#43301f', '#674a2b', '#8f6d43'),
        trunk=[(16, 23, 3), (16, 19, 2), (16, 13, 2)], fork=(16, 16),
        blobs=[(16, 14, 6.5, 4.5), (11.5, 11.5, 4.5, 4.5), (20.5, 11.5, 4.5, 4.5),
               (16, 8, 6, 5), (13.5, 4.5, 3.5, 3), (18.5, 5, 3.5, 3)],
        fruit=(['hy.', 'yyo', '.oo'], {'h': '#fff7a8', 'y': '#f7da25', 'o': '#cf9f10'}),
        spots=[(10, 10), (14, 13), (19, 14), (22, 9), (15, 6), (18, 9), (12, 5), (20, 4)],
        bloom=('#ffffff', '#f3e9c8'), sprout=(2, 2), seed=11),
    'lime': dict(
        leaf=('#0f2e1c', '#174726', '#236530', '#368a3d', '#5cb357'),
        bark=('#3b2f22', '#5c4a33', '#80694a'),
        trunk=[(16, 23, 2), (16, 20, 2), (16, 16, 2)], fork=(16, 19),
        blobs=[(16, 15, 7.5, 5), (11, 15.5, 4, 4), (21, 15.5, 4, 4), (13, 11, 4.5, 4),
               (19, 10.5, 4.5, 4), (16, 8, 3.5, 3)],
        fruit=(['hl', 'ld'], {'h': '#e6f58a', 'l': '#b5dc3c', 'd': '#7fae22'}),
        spots=[(9, 14), (13, 16), (18, 15), (22, 13), (12, 10), (16, 12), (20, 9), (15, 7), (20, 17)],
        bloom=('#ffffff', '#e8f3d0'), sprout=(2, 2), seed=23),
    'orange': dict(
        leaf=('#14351a', '#1e501c', '#2c6f20', '#429229', '#6bb63f'),
        bark=('#45301c', '#6b4a28', '#93703f'),
        trunk=[(16, 23, 3), (16, 20, 2), (16, 12, 2)], fork=(16, 15),
        blobs=[(16, 10, 8, 7), (10.5, 12, 3.5, 3.5), (21.5, 12, 3.5, 3.5), (16, 4.5, 4.5, 3)],
        fruit=(['.oo.', 'hooa', 'ooad', '.ad.'], {'h': '#ffd68a', 'o': '#f6921e', 'a': '#d96d10', 'd': '#a84c0a'}),
        spots=[(9, 9), (13, 5), (19, 4), (20, 10), (14, 10), (11, 13), (17, 14)],
        bloom=('#ffffff', '#f6efd2'), sprout=(3, 2), seed=37),
    'apple': dict(
        leaf=('#1e3d18', '#2c5a1e', '#427c26', '#609f33', '#8cc54c'),
        bark=('#352a24', '#574538', '#7c6652'),
        trunk=[(16, 23, 4), (16, 19, 3), (16, 14, 3)], fork=(16, 16),
        blobs=[(16, 13, 6, 3.5), (8.5, 11.5, 5.5, 4.5), (23.5, 11.5, 5.5, 4.5), (16, 8, 7, 5),
               (11.5, 5.5, 4.5, 3.5), (20.5, 5.5, 4.5, 3.5)],
        fruit=(['hrr', 'rrd', '.d.'], {'h': '#ff9a8a', 'r': '#e02a24', 'd': '#9c1418'}),
        spots=[(5, 11), (10, 13), (10, 5), (14, 9), (19, 12), (20, 4), (24, 9), (26, 13), (16, 4)],
        bloom=('#ffffff', '#f7b9cd'), sprout=(3, 3), seed=41),
    'sapodilla': dict(
        leaf=('#11301c', '#1a4a24', '#27682e', '#3b8839', '#5ba94c'),
        bark=('#3a2a20', '#5a4130', '#7d5d44'),
        trunk=[(16, 23, 3), (16, 20, 2), (16, 12, 2)], fork=(16, 17),
        blobs=[(16, 14, 6.5, 5), (16, 9, 6, 5.5), (16, 4.5, 4.5, 3.5)], rough=0.12,
        fruit=(['hb', 'bd'], {'h': '#d2a56a', 'b': '#a87642', 'd': '#77502a'}),
        spots=[(11, 15), (15, 16), (19, 14), (11, 10), (15, 11), (19, 9), (13, 6), (17, 5), (16, 2), (20, 16)],
        bloom=('#cfe3a0', '#9cc66a'), sprout=(3, 2), seed=53),
    'olives': dict(
        leaf=('#2c3b2e', '#40543c', '#587150', '#77906a', '#a3b890'),
        bark=('#463e35', '#6a6052', '#948a76'),
        trunk=[(15.5, 23, 5), (16, 20, 4), (14.5, 17, 3), (16, 14, 3)], fork=(15.5, 15),
        blobs=[(16, 11, 5, 3), (8, 10, 5, 3.4), (24, 10, 5, 3.4), (12.5, 6, 5, 3.4),
               (20, 5.5, 5, 3.4), (4.5, 13, 2.6, 2), (27.5, 13, 2.6, 2), (16, 3, 3, 2)],
        fruit=(['h', 'p'], {'h': '#6a4c7c', 'p': '#22152c'}),
        spots=[(6, 10), (9, 12), (11, 6), (14, 8), (15, 11), (18, 5), (21, 7), (22, 11), (25, 9),
               (27, 13), (4, 13), (17, 13), (13, 4), (20, 3)],
        bloom=('#f4f1d6', '#dcd9b4'), sprout=(2, 3), seed=67, rough=0.42, gaps=0.16,
        knot=(15, 19)),
    'cherry': dict(
        leaf=('#1c3b1c', '#285825', '#3a7b2f', '#55a03d', '#80c558'),
        bark=('#34191a', '#582a24', '#844636'),
        trunk=[(16, 23, 3), (16, 19, 2), (16, 13, 2)], fork=(16, 16),
        blobs=[(8.5, 11.5, 3.5, 3), (23.5, 11.5, 3.5, 3), (10.5, 8, 5, 5), (21.5, 8, 5, 5),
               (16, 8.5, 6, 5.5), (16, 3.5, 5.5, 2.6)],
        fruit=(['.g.', 'g.g', 'r.r', 'd.d'], {'g': '#9fbf5a', 'r': '#ee2f3c', 'd': '#a3101f'}),
        spots=[(6, 9), (10, 5), (11, 10), (15, 6), (15, 11), (19, 3), (20, 9), (23, 6), (23, 11)],
        bloom=('#ffffff', '#ffc4dc'), sprout=(3, 2), seed=71, lenticels='#6e3a30', heavy_bloom=True),
    'apricot': dict(
        leaf=('#2a4514', '#3d641a', '#588823', '#7aab31', '#a6cf4e'),
        bark=('#3d2618', '#5e3c25', '#875a39'),
        trunk=[(16, 23, 3), (15.5, 20, 2), (15.5, 15, 2)], fork=(15.5, 18),
        blobs=[(16, 13, 9.5, 4.5), (10.5, 10, 5, 4), (21.5, 10, 5, 4), (16, 7.5, 5.5, 3.5)],
        fruit=(['hy', 'ya'], {'h': '#ffe08a', 'y': '#ffb02e', 'a': '#e0661a'}),
        spots=[(7, 13), (11, 11), (14, 14), (19, 13), (23, 12), (12, 7), (16, 9), (20, 8), (16, 5), (25, 14)],
        bloom=('#ffffff', '#fbd5d8'), sprout=(2, 3), seed=83),
}


def tree(name, stage):
    t = TREES[name]
    c = Canvas()
    leaf, bark = t['leaf'], t['bark']
    if stage in ('grow1', 'grow2'):
        pairs, reach = t['sprout']
        sprout(c, leaf, bark[1], 1 if stage == 'grow1' else pairs, reach - (stage == 'grow1' and reach > 2))
        return c.im
    if stage == 'dead':
        limbs(c, t['fork'], t['blobs'], DEAD_BARK, twigs=True, seed=t['seed'])
        rows = trunk(c, t['trunk'], DEAD_BARK)
        for i, (x, y, rx, ry) in enumerate(t['blobs']):
            if i % 2 == 0:
                dx = (hsh(i, 1, t['seed'] + 5) - 0.5) * 2 * rx * 0.7
                c.px(x + dx, y + 1, DEAD_LEAF[i % 3])
                c.px(x + dx, y + 2, DEAD_LEAF[0])
        for k, (x, y) in enumerate(((9, 23), (10, 22), (21, 23), (23, 23), (24, 22), (12, 23))):
            c.px(x, y, DEAD_LEAF[k % 3])
        foot = rows[BY]
        c.shadow(int(foot[0]) - 3, int(foot[0]) + 3)
        return c.im
    s = {'grow3': 0.48, 'grow4': 0.66, 'grow5': 0.84}.get(stage, 1.0)
    limbs(c, t['fork'], t['blobs'], bark, s)
    rows = trunk(c, t['trunk'], bark, s)
    if s == 1.0:
        if 'lenticels' in t:
            for y in (21, 19, 17):
                c.px(16, y, t['lenticels'])
        if 'knot' in t:
            kx, ky = t['knot']
            c.pts(bark[0], (kx, ky), (kx + 1, ky), (kx, ky + 1))
            c.pts(bark[2], (kx - 1, ky + 2), (kx + 2, ky - 1))
    mask = canopy(c, t['blobs'], leaf, t['seed'], s, rough=t.get('rough', 0.22), gaps=t.get('gaps', 0.0))
    if stage == 'harvest':
        rows_, pal = t['fruit']
        fruit(c, t['spots'], rows_, pal, under=leaf[0])
    elif stage == 'grow6':
        a, b = t['bloom']
        for i, (x, y) in enumerate(t['spots']):
            if t.get('gaps') and i % 2:
                continue
            c.px(x, y, a)
            c.px(x + 1, y + (i % 2), b)
            if t.get('heavy_bloom'):
                c.pts(b, (x - 1, y + 1), (x + 2, y - 1))
                c.px(x + 1, y + 2, a)
    foot = min(mask, key=lambda p: -p[1])[1] if mask else BY
    w = 2 if s < 0.6 else 3 if s < 0.9 else 4
    c.shadow(BX - w, BX + w)
    return c.im



# ------------------------------------------------- large-leaved custom trees
GROW = {'grow3': 0.45, 'grow4': 0.62, 'grow5': 0.82, 'grow6': 1.0, 'harvest': 1.0}

SAPOTE = dict(leaf=('#1b3812', '#2a5516', '#3f781c', '#5c9c28', '#8cc63e'), bark=('#3e3026', '#5f4b3a', '#847058'))
SAPOTE_HEADS = [(8.5, 11), (23.5, 11), (12, 6), (20, 6), (16, 9.5), (16, 3.5)]
SAPOTE_FRUIT = (['hb', 'bb', 'bd'], {'h': '#c9955a', 'b': '#9a683a', 'd': '#6a4322'})


def sapote(stage):
    c = Canvas()
    leaf, bark = SAPOTE['leaf'], SAPOTE['bark']
    if stage in ('grow1', 'grow2'):
        sprout(c, leaf, bark[1], 1 if stage == 'grow1' else 2, 3)
        return c.im
    dead = stage == 'dead'
    s = GROW.get(stage, 1.0)
    tones = DEAD_BARK if dead else bark
    for i, (x, y) in enumerate(SAPOTE_HEADS):
        c.line(tones[0] if i % 2 else tones[1], *sc(16, 14, s), *sc(x, y + 1, s))
    trunk(c, [(16, 23, 3), (16, 18, 2), (16, 9, 2)], tones, s)
    n = max(2, round(len(SAPOTE_HEADS) * (0.4 + 0.6 * s))) if s < 1 else len(SAPOTE_HEADS)
    for i, (x, y) in enumerate(SAPOTE_HEADS[:n]):
        hx, hy = sc(x, y, s)
        if dead:
            for k in (0, 2, 4):
                a = math.pi * (0.15 + 0.175 * k)
                c.line(DEAD_LEAF[k % 3], hx, hy, hx + math.cos(a) * 3, hy + math.sin(a) * 3)
            continue
        ln = max(2, round(5 * (0.5 + 0.5 * s)))
        canopy(c, [(hx, hy + 0.5, ln - 1.2, ln - 1.8)], (leaf[0], leaf[0], leaf[1], leaf[1], leaf[2]), 90 + i, 1.0, rough=0.1)
        # a whorl of long leaves: the lower ones first so the upper ones overlap them
        for a in (0.72, 0.28, 0.95, 0.05, 1.2, -0.2, 1.42, -0.42, 1.5):
            ang = math.pi * a
            c2 = (leaf[0], leaf[1], leaf[1], leaf[2], leaf[3]) if 0.2 < a < 0.8 else leaf
            blade(c, hx, hy, ang if a >= 0 else ang, ln - (0.25 < a < 0.75), c2, thick=(a < 0.2 or a > 0.8))
        c.px(hx, hy, leaf[4])
    if dead:
        for k, (x, y) in enumerate(((9, 23), (11, 22), (21, 23), (23, 22), (24, 23))):
            c.px(x, y, DEAD_LEAF[k % 3])
    elif stage == 'harvest':
        fruit(c, [(10, 13), (21, 13), (13, 9), (18, 12), (14, 15), (18, 7)], *SAPOTE_FRUIT)
    elif stage == 'grow6':
        for x, y in ((10, 13), (21, 13), (13, 9), (18, 12), (14, 15), (18, 7)):
            c.pts('#b7d27a', (x, y))
            c.pts('#86a84c', (x, y + 1))
    c.shadow(BX - 3, BX + 3)
    return c.im


COCOA = dict(leaf=('#12301a', '#1c4a20', '#2a6a26', '#3f8c30', '#63b044'), bark=('#2e211c', '#4a3830', '#6b5448'),
             flush=('#5a2a1e', '#8a4428', '#b5653a', '#d48a52', '#e8ad76'))
COCOA_PODS = [((14, 14), 'y'), ((17, 16), 'o'), ((14, 18), 'r'), ((17, 20), 'y'), ((11, 12), 'o'), ((20, 12), 'r')]
POD = {'y': {'h': '#ffe27a', 'p': '#eebb2c', 'd': '#b9801a'},
       'o': {'h': '#ffc27a', 'p': '#e58226', 'd': '#a9521a'},
       'r': {'h': '#d9785a', 'p': '#a43a2a', 'd': '#6e211c'},
       'g': {'h': '#b9d86a', 'p': '#7fa83a', 'd': '#55782a'}}


def cocoa(stage):
    c = Canvas()
    leaf, bark = COCOA['leaf'], COCOA['bark']
    if stage in ('grow1', 'grow2'):
        sprout(c, leaf if stage == 'grow2' else COCOA['flush'], bark[1], 1 if stage == 'grow1' else 2, 3)
        return c.im
    dead = stage == 'dead'
    s = GROW.get(stage, 1.0)
    tones = DEAD_BARK if dead else bark
    arms = [(9, 9), (23, 9), (13, 6), (19, 6)]
    for i, (x, y) in enumerate(arms):
        c.line(tones[1] if i < 2 else tones[0], *sc(16, 12, s), *sc(x, y, s))
    trunk(c, [(16, 23, 3), (16, 19, 2), (16, 10, 2)], tones, s)
    if dead:
        for i, (x, y) in enumerate(arms):
            c.line(tones[0], x, y, x + (-3 if x < 16 else 3), y - 1)
            c.line(DEAD_LEAF[i % 3], x, y + 1, x + (-1 if x < 16 else 1), y + 5)
            c.line(DEAD_LEAF[(i + 1) % 3], x + (-3 if x < 16 else 3), y, x + (-4 if x < 16 else 4), y + 4)
        c.stamp(14, 15, ['p', 'd', 'd'], {'p': '#4a3a30', 'd': '#2e2420'})
        for k, (x, y) in enumerate(((10, 23), (12, 22), (21, 23), (23, 23))):
            c.px(x, y, DEAD_LEAF[k % 3])
        c.shadow(BX - 3, BX + 3)
        return c.im
    blobs = [(16, 7.5, 8.5, 4.2), (9.5, 9, 4.5, 3.2), (22.5, 9, 4.5, 3.2), (16, 4.5, 5.5, 3)]
    canopy(c, blobs, leaf, 101, s, rough=0.15)
    # big leaves droop below the rim of the crown
    ln = max(2, round(4 * (0.45 + 0.55 * s)))
    for k, x in enumerate((6, 9, 12, 20, 23, 26)):
        hx, hy = sc(x, 10.5 - (k in (2, 3)) * 0.5, s)
        blade(c, hx, hy, math.pi * (0.5 - 0.22 * (x - 16) / 10.0), ln - (k % 2), leaf, thick=False)
    for k, x in enumerate((13, 16, 19)):  # the new flush is bronze-red
        hx, hy = sc(x, 2.5 - (k == 1), s)
        c.px(hx, hy, COCOA['flush'][3])
        c.px(hx + (k - 1), hy + 1, COCOA['flush'][2])
    if stage in ('grow6', 'harvest'):
        for (x, y), kind in COCOA_PODS:
            pal = POD['g' if stage == 'grow6' else kind]
            if stage == 'grow6':
                c.stamp(x, y, ['h', 'p'], pal)
            else:
                c.stamp(x, y, ['hp', 'pd', '.d'] if x >= 16 else ['ph', 'pd', 'd.'], pal)
    c.shadow(BX - 3, BX + 3)
    return c.im


BANANA = dict(leaf=('#1d4a16', '#2c6a1c', '#3f8c24', '#5cae30', '#8fd04a'), rib='#7cc23e',
              stem=('#566328', '#869638', '#b2c05c'), sheath='#7a5c30')
BANANA_LEAVES = [
    ([(0, 0), (-3, -1), (-7, 1), (-10, 5)], (5,)),
    ([(0, 0), (3, -1), (7, 1), (10, 5)], (6,)),
    ([(0, 0), (-3, -4), (-7, -6), (-11, -5), (-13, -2)], (7, 11)),
    ([(0, 0), (3, -4), (7, -6), (11, -5), (13, -2)], (6, 10)),
    ([(0, 0), (-1, -5), (-3, -9)], ()),
    ([(0, 0), (2, -5), (4, -9)], ()),
]
HAND = ['.yhy.', 'yhyhy', 'hyoyo', 'oyo.o']


def banana(stage):
    c = Canvas()
    b = BANANA
    if stage in ('grow1', 'grow2'):
        top = BY - (3 if stage == 'grow1' else 6)
        for y in range(BY, top, -1):
            c.px(BX, y, b['stem'][1])
        paddle(c, [(BX, top), (BX - 2, top - 2), (BX - 4, top - 2)], b['leaf'], b['rib'], 1)
        paddle(c, [(BX, top), (BX + 1, top - 3), (BX + 3, top - 4)], b['leaf'], b['rib'], 1)
        if stage == 'grow2':
            paddle(c, [(BX, top + 2), (BX + 3, top + 1), (BX + 5, top + 2)], b['leaf'], b['rib'], 1)
        c.shadow(BX - 2, BX + 2)
        return c.im
    dead = stage == 'dead'
    g = GROW.get(stage, 1.0)
    top = BY - round(12 * g)
    stem = ('#4a4032', '#6b5d48', '#8c7c62') if dead else b['stem']
    rows = trunk(c, [(16, 23, 4 if g > 0.7 else 2), (16, top, 3 if g > 0.7 else 2)], stem, 1.0, flare=g > 0.7)
    for y in range(BY - 1, top + 1, -3):
        c.px(15 if (y // 3) % 2 else 16, y, '#3e352a' if dead else b['sheath'])
    if dead:
        for k, (pts, _) in enumerate(BANANA_LEAVES[:4]):
            sgn = -1 if pts[-1][0] < 0 else 1
            drop = [(16, top), (16 + sgn * (3 + k % 2), top - 1 + k // 2), (16 + sgn * (5 + k // 2), top + 4), (16 + sgn * (4 + k // 2), top + 9 - k)]
            paddle(c, drop, ('#3e3020', '#5a4428', '#7a5c30', '#9c7a3c', '#b8974a'), '#6b5234', 1)
        c.line(stem[0], 16, top, 15, top - 4)
        c.shadow(BX - 3, BX + 3)
        return c.im
    show = {'grow3': [4, 2, 3], 'grow4': [4, 5, 2, 3], 'grow5': [4, 5, 2, 3, 0, 1]}.get(stage, [4, 5, 2, 3, 0])
    for idx in show:
        pts, torn = BANANA_LEAVES[idx]
        pts = [(16 + round(x * g), top + round(y * g)) for x, y in pts]
        paddle(c, pts, b['leaf'], b['rib'], 2 if g > 0.5 else 1, torn if g == 1.0 else ())
    if stage in ('grow6', 'harvest'):
        pal = {'y': '#f4d21f', 'h': '#fff07a', 'o': '#c79a12'} if stage == 'harvest' else {'y': '#8fb53a', 'h': '#b9d86a', 'o': '#5f8a2a'}
        c.line('#6f7f30', 17, top + 1, 20, top + 3)
        c.stamp(18, top + 4, HAND, pal)
        c.pts('#6a2a5a', (20, top + 8), (20, top + 9))
        c.px(21, top + 9, '#93388f')
    c.shadow(BX - 3, BX + 3)
    return c.im


PALM = dict(leaf=('#164a1c', '#236824', '#33882c', '#4fa83a', '#86cc58'), bark=('#574c40', '#80725f', '#a89a82'))
FRONDS = [
    [(0, 0), (-5, 1), (-9, 5), (-10, 9)],
    [(0, 0), (5, 1), (9, 5), (10, 9)],
    [(0, 0), (-4, -3), (-9, -3), (-13, 0), (-15, 4)],
    [(0, 0), (4, -3), (8, -3), (11, 0), (12, 4)],
    [(0, 0), (-3, -4), (-7, -6), (-10, -5)],
    [(0, 0), (3, -4), (6, -6), (9, -5)],
    [(0, 0), (0, -3), (1, -6)],
]


def coconut(stage):
    c = Canvas()
    leaf, bark = PALM['leaf'], PALM['bark']
    if stage in ('grow1', 'grow2'):
        # a sprouting nut
        c.stamp(14, 21, ['.bb.', 'bBbd', '.dd.'], {'b': '#7d5428', 'B': '#a3743a', 'd': '#5a3a1c'})
        frond(c, [(16, 21), (15, 18), (13, 16)], leaf, 1)
        if stage == 'grow2':
            frond(c, [(16, 21), (17, 16), (20, 13)], leaf, 1)
            frond(c, [(16, 21), (15, 15), (12, 13)], leaf, 1)
        c.shadow(BX - 2, BX + 2)
        return c.im
    dead = stage == 'dead'
    g = GROW.get(stage, 1.0)
    tones = DEAD_BARK if dead else bark
    h = 15 * max(0.0, (g - 0.3) / 0.7)
    foot, crown = (13, 23), (13 + round(5 * h / 15), 23 - round(h) - 1)
    mid = ((foot[0] + crown[0]) / 2 - 0.8, (foot[1] + crown[1]) / 2)
    rows = trunk(c, [(foot[0] + 0.5, 23, 3), (mid[0] + 0.5, mid[1], 2), (crown[0] + 0.5, crown[1], 2)], tones, 1.0, flare=h > 5)
    for y, (cx, w) in rows.items():
        if (BY - y) % 2 == 1 and y < BY:
            c.px(int(round(cx - w / 2.0)) + w - 1, y, tones[0])
            c.px(int(round(cx - w / 2.0)), y, tones[1])
    cx, cy = crown
    f = 0.55 + 0.45 * g
    if dead:
        for k, pts in enumerate(FRONDS[:4]):
            sgn = -1 if pts[-1][0] < 0 else 1
            drop = [(cx, cy), (cx + sgn * (2 + k // 2), cy + 1 - k // 2), (cx + sgn * (4 + k // 2), cy + 5), (cx + sgn * (4 + k // 2), cy + 9 - k)]
            frond(c, drop, ('#3e3020', '#5a4428', '#7a5c30', '#9c7a3c', '#b8974a'), 1)
        c.line(tones[0], cx, cy, cx + 1, cy - 3)
        c.shadow(foot[0] - 2, foot[0] + 4)
        return c.im
    for k, pts in enumerate(FRONDS):
        if g < 0.5 and k < 2:
            continue
        frond(c, [(cx + round(x * f), cy + round(y * f)) for x, y in pts], leaf, 2 if g > 0.7 else 1)
    if stage in ('grow6', 'harvest'):
        pal = {'h': '#b0824a', 'b': '#7d5428', 'd': '#4e3218'} if stage == 'harvest' else {'h': '#b9d86a', 'b': '#7fa83a', 'd': '#55782a'}
        for x, y in ((cx - 3, cy + 1), (cx + 1, cy + 1), (cx - 1, cy + 3)):
            c.stamp(x, y, ['hbb', 'bbd', '.d.'], pal)
    c.px(cx, cy, leaf[1])
    c.shadow(foot[0] - 2, foot[0] + 4)
    return c.im


CUSTOM = {'sapote': sapote, 'banana': banana, 'coconut': coconut, 'cocoa': cocoa}

# ------------------------------------------------------------- cave wheat
# Pale, lightless grass: cool greys with a bone-white ear, after the grey sheaf
# of the harvested item.
CW = ('#3d424b', '#646b76', '#8f97a3', '#bcc3cc', '#eef1f4')
CW_EAR = ('#8e8a7c', '#c9c5b4', '#f2efe2')
CW_PLANTS = [(4, 24, -1, 0.82), (8, 25, 0, 1.0), (12, 24, 1, 0.88), (16, 25, -1, 0.94), (20, 24, 0, 0.80),
             (24, 25, 1, 1.0), (28, 24, 0, 0.86)]
CW_HEIGHT = {'grow1': 3, 'grow2': 5, 'grow3': 8, 'grow4': 11, 'grow5': 14, 'grow6': 16, 'harvest': 16}


def cave_wheat(stage):
    c = Canvas()
    if stage == 'dead':
        dead = ('#2e2f33', '#4a4c52', '#6b6d73')
        for i, (x, base, lean, k) in enumerate(CW_PLANTS):
            h = round(7 * k)
            d = 1 if i % 2 else -1
            c.line(dead[1 if i % 2 else 0], x, base, x, base - h)
            c.line(dead[2 if i % 3 == 0 else 1], x, base - h, x + d * 3, base - h + 3)
            c.px(x + d * 3, base - h + 4, dead[0])
            c.px(x - d, base - 1, dead[1])
        return c.im
    height = CW_HEIGHT[stage]
    for back in (True, False):
        for i, (x, base, lean, k) in enumerate(CW_PLANTS):
            if (base == 24) != back:
                continue
            h = max(2, round(height * k))
            dark, stem, lit = (CW[0], CW[1], CW[2]) if back else (CW[1], CW[2], CW[3])
            # a tuft of two blades at the foot
            t = min(h, 5)
            c.line(lit, x, base, x - 2, base - t)
            c.line(stem, x, base, x + 2, base - t + 1)
            c.px(x - 2, base - t, CW[4] if not back else CW[3])
            if h > 6:
                top = (x + (lean if h > 11 else 0), base - h)
                path = c.line(stem, x, base, *top)
                for j, (px_, py_) in enumerate(path):
                    if j % 4 == 2:
                        c.px(px_, py_, lit)
                if h > 9:  # one flag leaf below the ear
                    side = 1 if i % 2 else -1
                    jx, jy = path[round(h * 0.55)]
                    c.pts(lit, (jx + side, jy - 1), (jx + side * 2, jy - 2))
                    c.px(jx + side * 3, jy - 2, dark)
                tx, ty = top
                if stage == 'grow5':  # the ear is still in the boot
                    c.pts(CW_EAR[1], (tx, ty), (tx, ty + 1), (tx, ty + 2))
                    c.px(tx, ty - 1, CW_EAR[2])
                elif stage in ('grow6', 'harvest'):
                    ripe = stage == 'harvest'
                    d = lean if lean else (1 if i % 2 else -1)
                    for q in range(6 if ripe else 5):
                        nod = (1 if q >= 3 else 0) if ripe else 0
                        ex, ey = tx + d * nod, ty + 3 - q + nod
                        c.px(ex, ey, CW_EAR[2])
                        c.px(ex + d, ey, CW_EAR[1] if q % 2 else CW_EAR[0])
                        if ripe:
                            c.px(ex - d, ey, CW_EAR[1] if q % 2 == 0 else CW_EAR[2])
                    if ripe:  # awns
                        c.pts(CW_EAR[1], (ex, ey - 1), (ex + d * 2, ey - 1))
                    else:
                        c.px(ex, ey - 1, CW_EAR[1])
            c.px(x, base, dark)
    return c.im


# ------------------------------------- plump helmet and turnip in-between stages
# Drawn in the palette of the Pocket Stronghold harvest sprites so the kept
# upstream stages and these read as one plant.
PH = {'a': '#622461', 'b': '#93388f', 'c': '#bf6f4a', 'd': '#e69c69', 'e': '#ca52c9', 'f': '#3b1443',
      'g': '#f6ca9f', 'h': '#8a4836'}
PLUMP = {
    'grow1': (13, 15, ['.bb....', 'abeb...', '.dg..bb', '.cg..ae', '......d']),
    'grow2': (11, 13, ['....bbb..', '...abbeb.', '...faabb.', '.bb..dg..', 'abe..cgg.', '.d....g..']),
    'grow3': (10, 11, ['.....bbbb..', '....abbbeb.', '...aabbbebb', '...faaabbb.', '.....hcdg..', '.bbb.hcdgg.',
                       'abeb..cdg..', 'faab.......', '.cg........']),
    'grow6': (9, 7, ['....bbbbb....', '..abbbbbbbb..', '.aabbbbbbebbb', 'faabbbbbbeebb', 'faaabbbbbbbba',
                     '.ffaaabbbbba.', '...ffaaaaa...', '....hhccdg...', '...hhccddgg..', '...hccddggg..',
                     '....cddgg....', '.....dgg.....']),
}
TU = {'a': '#5ac54f', 'b': '#99e65f', 'c': '#33984b', 'd': '#134c4c', 'e': '#0c2e44', 'f': '#1e6f50',
      'g': '#f9e6cf', 'h': '#f6ca9f', 'i': '#e69c69', 'j': '#bf6f4a'}
TURNIP = {
    'grow1': (12, 13, ['bb...bb', 'abc.cba', '.fcdcf.', '...d...', '...e...', '...g...']),
    'grow2': (12, 11, ['...b....', '.b.a..b.', 'bab..abb', 'fcba.cba', '.fcadcf.', '..fcdc..', '...df...', '...ag...']),
    'grow3': (12, 10, ['.....b..', '.b...ab.', 'bab.dcba', 'fcbadcbd', 'ffcadbad', '.fbcdbc.', '..efdc..', '...df...',
                       '...ag...']),
    'grow6': (10, 5, ['.......da..', '......dcab.', '.ba...dcbab', 'fcbad.dcbad', 'ffcbadccbad', '.ffbcdcbad.',
                      '.eefbcdbc..', '...efacae..', '....efaf...', '....efa....', '.....ag....', '....hhgg...',
                      '...jiihh...', '....jih....']),
}


def stamped(table, pal, stage):
    c = Canvas()
    x, y, rows = table[stage]
    c.stamp(x, y, rows, pal)
    return c.im


# ------------------------------------------------------------- crab foods
CRAB = {'O': '#5a1e14', 'R': '#c8402a', 'r': '#e8683a', 'h': '#f79a5a', 'd': '#8f2a1c', 'W': '#f6ead8',
        'w': '#e2c9a8', 'p': '#f0a898', 'P': '#d9604a', 's': '#8a5a30', 'c': '#d9b48a'}
CRAB_ROASTED = [
    '.......OOOOOOO........',
    '.....OOWWPWWWWOO......',
    '...OOWWWWWWPpWWWOO....',
    '.OORWWPpWWWWWWWPWRO...',
    'OhrRWWWWWsWWWPWWWRRdO.',
    '.OrrhWWPWWWWWWWwwRdO..',
    '..OrrrhhwwwwwwrRRdOOO.',
    '...OdrrrrhhrrRRddOhrO.',
    '....OOddddddddOOOrrRdO',
    '......OOOOOOOO.OrRO.O.',
    '................OO....',
]
RUIN = {'K': '#1c1410', 'D': '#3a2a22', 'M': '#5a4336', 'L': '#806450', 'G': '#5f7a34', 'g': '#9cb054',
        'S': '#7a3226', 's': '#a04a36', 'A': '#b0a898'}
FOOD_RUINED = [
    '.......KKKK.......',
    '.....KKDMLMKK.....',
    '...KKDMLMDDGgK....',
    '..KDMMLDDMGGGDKK..',
    '.KDSsMDDMMDGDMLDK.',
    '.KSSDDMLDDMDDMMDK.',
    'KDMDDGgDMSsDMLDDDK',
    'KDDMGGDDDSSDDMDAK.',
    '.KKDDDDKKDDDDKKK..',
    '...KKKK..KKKK.....',
]


def food(rows, pal):
    c = Canvas()
    c.stamp(16 - len(rows[0]) // 2, 17 - len(rows) // 2, rows, pal)
    return c.im


def build():
    fruits = [('%s-%s' % (n, st), tree(n, st)) for n in TREES for st in STAGES]
    fruits += [('%s-%s' % (n, st), fn(st)) for n, fn in CUSTOM.items() for st in STAGES]
    return {
        'icons/farming/fruits.dmi': fruits,
        'icons/farming/pocket_stronghold_cave_wheat.dmi': [('cave_wheat-' + st, cave_wheat(st)) for st in STAGES],
        'icons/farming/pocket_stronghold_plump_helmet.dmi': [('plump_helmet-' + st, stamped(PLUMP, PH, st)) for st in PLUMP],
        'icons/farming/pocket_stronghold_turnip.dmi': [('turnip-' + st, stamped(TURNIP, TU, st)) for st in TURNIP],
        'icons/obj/food/pocket_stronghold_food.dmi': [('crab_meat_roasted', food(CRAB_ROASTED, CRAB)),
                                                     ('food_ruined', food(FOOD_RUINED, RUIN))],
    }


# ------------------------------------------------------------- DMI plumbing
def read_dmi(path):
    im = Image.open(path)
    lines = im.info['Description'].splitlines()
    header, blocks = [], []
    for line in lines:
        if line.startswith('state = '):
            blocks.append([line])
        elif line.startswith('# END DMI'):
            break
        elif blocks:
            blocks[-1].append(line)
        else:
            header.append(line)
    im = im.convert('RGBA')
    cols = im.width // S
    states, idx = [], 0
    for block in blocks:
        n = 1
        for line in block[1:]:
            key, _, val = line.strip().partition(' = ')
            if key in ('dirs', 'frames'):
                n *= int(val)
        frames = [im.crop(((i % cols) * S, (i // cols) * S, (i % cols) * S + S, (i // cols) * S + S))
                  for i in range(idx, idx + n)]
        idx += n
        states.append((block[0].split('"')[1], block, frames))
    return header, states, cols


def merged(path, new_states):
    """The sheet with new_states drawn over the same-named states, order kept."""
    header, states, cols = read_dmi(path)
    new = dict(new_states)
    missing = set(new) - {name for name, _, _ in states}
    assert not missing, 'States missing from %s: %s' % (path, sorted(missing))
    states = [(name, block, [new[name]] if name in new else frames) for name, block, frames in states]
    frames = [f for _, _, fs in states for f in fs]
    sheet = Image.new('RGBA', (cols * S, -(-len(frames) // cols) * S))
    for i, f in enumerate(frames):
        sheet.paste(f, ((i % cols) * S, (i // cols) * S))
    text = '\n'.join(header + [line for _, block, _ in states for line in block] + ['# END DMI', ''])
    return sheet, text


def write_dmi(path, new_states):
    sheet, text = merged(path, new_states)
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta, optimize=True)


def check(path, new_states):
    sheet, _ = merged(path, new_states)
    return sheet.tobytes() == Image.open(path).convert('RGBA').tobytes()


def preview(sheets, out, z=4):
    """Review sheet of the actual sprite pixels; not a gameplay screenshot."""
    per_row, cw, ch = 8, S * z + 10, S * z + 18
    total = sum(-(-len(g) // per_row) for g in sheets.values())
    img = Image.new('RGBA', (cw * per_row + 10, total * ch + 24 * len(sheets) + 10), (36, 40, 48, 255))
    d = ImageDraw.Draw(img)
    y = 6
    for rel, group in sheets.items():
        d.text((8, y), rel, fill='white')
        y += 20
        for i, (name, frame) in enumerate(group):
            x, yy = 8 + (i % per_row) * cw, y + (i // per_row) * ch
            d.rectangle((x, yy + 12, x + S * z - 1, yy + 12 + S * z - 1), fill=(92, 72, 48, 255))
            img.alpha_composite(frame.resize((S * z, S * z), Image.NEAREST), (x, yy + 12))
            d.text((x, yy), name[:22], fill=(235, 235, 220))
        y += -(-len(group) // per_row) * ch + 4
    img.save(out)


if __name__ == '__main__':
    sheets = build()
    if '--check' in sys.argv:
        bad = [rel for rel, new_states in sheets.items() if not check(ROOT / rel, new_states)]
        if bad:
            sys.exit('Out of date, rerun tests/sprites/create_orchard.py: ' + ', '.join(bad))
        print('Orchard sheets match the script')
    elif '--no-write' not in sys.argv:
        for rel, new_states in sheets.items():
            write_dmi(ROOT / rel, new_states)
    if '--preview' in sys.argv:
        preview(sheets, sys.argv[sys.argv.index('--preview') + 1])
