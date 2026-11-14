"""Original hand-placed art for the small tree and the palm trees.

Every pixel comes from the fixed palettes and the hand-chosen coordinates in
this file (trunk spans, branch lines, leaf clumps, frond spines); there is no
external, traced or generated artwork, and no randomness - leaf texture comes
from the fixed GRAIN table. Released under Civ13's AGPL-3.0 licence. Run with
Pillow from the repository root:

    python3 tests/sprites/create_trees.py [--preview sheet.png]

It replaces these states in place and leaves every other state and the DMI
metadata untouched:

- icons/obj/flora/wild.dmi (32x32): "tree" (/obj/structure/wild/tree, the
  small tree) and "deadtree". The trunk is centred on BYOND pixel x=16
  (trunk_center_x) and stands on row 2.
- icons/obj/flora/palm.dmi (32x64): "palm1", "palm2", "dead_palm1",
  "dead_palm2". The highest opaque pixel stays on BYOND row 54, which
  tree climbing reads to place a climber (tests/tree_climbing/probe.dm).
  "palm1old" and "palm2old" are not touched.

Light comes from the top-left, as on icons/obj/flora/bigtrees.dmi, and each
trunk stands on the same soft ground shadow. To change the look, edit this
script and rerun it; do not hand-edit the states.
"""
import math
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]


def rgba(c, a=255):
    return (int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16), a)


# Leaf ramps run outline -> shade -> mid -> light -> highlight.
LEAF = [rgba(c) for c in ('#2c311a', '#40512a', '#5b703b', '#76983d', '#8cb850')]
LEAF_EDGE = rgba('#1c2414')
LEAF_ACCENT = rgba('#3b7128')  # the cool green flecks of bigtrees.dmi
DRY = [rgba(c) for c in ('#2e2623', '#4a3824', '#6b5231', '#8a6c3f', '#a58a55')]
DRY_ACCENT = rgba('#5a4a22')
FROND = [rgba(c) for c in ('#1f2a16', '#3a5226', '#55782f', '#76983d', '#a3c257')]
FROND_DRY = [rgba(c) for c in ('#2e2623', '#4f3a20', '#70562f', '#917543', '#b39a62')]
# Bark ramps run outline -> dark -> mid -> light -> highlight.
BARK = [rgba(c) for c in ('#1d1618', '#33221b', '#4a3824', '#624a30', '#7c6149')]
PALM_BARK = [rgba(c) for c in ('#2e2623', '#48301a', '#775e47', '#99795e', '#b8977a')]
PALM_BARK_DRY = [rgba(c) for c in ('#2e2623', '#3d2c1c', '#5f4b39', '#7b6450', '#92796a')]
NUT = [rgba(c) for c in ('#1d1618', '#3a2a1a', '#6a4d2c')]
SHADOW = '#1d1618'

# Fixed 8x8 leaf grain, -3..3: breaks the shading bands into short leaf strokes.
GRAIN = (
    (1, -2, 0, 3, -1, 2, -3, 0),
    (-1, 2, 1, -3, 0, -2, 1, 3),
    (3, 0, -2, 1, 2, -1, 0, -3),
    (-2, 1, 3, 0, -3, 1, 2, -1),
    (0, -3, -1, 2, 1, 3, -2, 1),
    (2, 1, 0, -2, 3, 0, -1, -3),
    (-3, 3, 2, -1, 0, -2, 1, 0),
    (1, -1, -3, 0, 2, 1, 3, -2),
)


def grain(x, y):
    return GRAIN[(y + x // 8 * 3) % 8][(x + y // 8 * 5) % 8] / 3.0


class Canvas:
    def __init__(self, w, h):
        self.w, self.h, self.px = w, h, {}

    def put(self, x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[(x, y)] = c

    def line(self, x0, y0, x1, y1, c):
        n = int(max(abs(x1 - x0), abs(y1 - y0)))
        for i in range(n + 1):
            t = i / n if n else 0
            self.put(round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t), c)

    def outline(self, c, diagonal=False):
        """Ring every drawn pixel with c where the neighbour is still empty."""
        steps = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        if diagonal:
            steps += [(1, 1), (-1, 1), (1, -1), (-1, -1)]
        for (x, y) in list(self.px):
            for dx, dy in steps:
                if (x + dx, y + dy) not in self.px:
                    self.put(x + dx, y + dy, c)

    def stamp(self, other, behind=False):
        for k, c in other.px.items():
            if not (behind and k in self.px):
                self.px[k] = c

    def shadow(self, cx, cy, rx, ry):
        """Soft ground shadow under whatever is already drawn."""
        for y in range(self.h):
            for x in range(self.w):
                d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                if d <= 1 and (x, y) not in self.px:
                    self.px[(x, y)] = rgba(SHADOW, 120 if d < 0.35 else 78 if d < 0.7 else 34)

    def image(self):
        im = Image.new('RGBA', (self.w, self.h), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c)
        return im


# ------------------------------------------------------------ small tree
# Trunk interior spans (y, left, right), top-left origin. The interior is
# centred on x=15, which is BYOND pixel x=16; the base stands on y=30.
TRUNK = [(30, 12, 18), (29, 13, 17), (28, 14, 17), (27, 14, 16), (26, 14, 16), (25, 14, 16),
         (24, 14, 16), (23, 14, 16), (22, 14, 16), (21, 14, 16), (20, 13, 17), (19, 13, 17)]
# Boughs as (x0, y0, x1, y1), drawn two pixels thick near the fork.
BOUGHS = [(13, 19, 9, 15), (9, 15, 6, 13), (9, 15, 8, 11), (17, 19, 21, 15), (21, 15, 25, 13),
          (21, 15, 22, 10), (15, 19, 15, 13), (15, 13, 13, 8), (15, 13, 18, 8)]
# Twigs only the dead tree shows.
TWIGS = [(6, 13, 3, 12), (6, 13, 5, 10), (8, 11, 6, 7), (8, 11, 10, 7), (13, 8, 11, 4),
         (13, 8, 14, 3), (18, 8, 17, 4), (18, 8, 21, 4), (22, 10, 21, 6), (22, 10, 25, 7),
         (25, 13, 28, 12), (25, 13, 27, 9)]
# Leaf clumps (cx, cy, rx, ry), back to front.
CLUMPS = [(15, 5.5, 6, 4.6), (9, 8.5, 5.5, 4.5), (22, 8.5, 5.5, 4.5), (15.5, 9.5, 5, 4),
          (5.5, 12.5, 3.6, 3.2), (25.5, 13, 3.6, 3.2), (10.5, 14, 5, 3.6), (20.5, 14.5, 5, 3.6)]
# The few withered clumps left on the dead tree.
DEAD_CLUMPS = [(12.5, 4.5, 2.4, 1.7), (7, 8, 2.2, 1.7), (21.5, 5.5, 2.4, 1.8), (26, 10, 2, 1.5),
               (4.5, 12.5, 1.8, 1.4), (17.5, 6, 1.8, 1.4)]


def leaf_clump(cv, clump, ramp, accent, centre=(15, 10), reach=(13, 10)):
    cx, cy, rx, ry = clump
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            dx, dy = (x - cx) / rx, (y - cy) / ry
            d = dx * dx + dy * dy
            g = grain(x, y)
            if d > 1 or (d > 0.72 and g > 0.5):
                continue  # ragged rim
            local = -(dx * 0.55 + dy * 0.83)
            far = -((x - centre[0]) / reach[0] * 0.55 + (y - centre[1]) / reach[1] * 0.83)
            v = 0.55 * local + 0.45 * far + g * 0.34
            if d > 0.7 and local < -0.25:
                shade = 0  # under-rim, separates the clump from the one below
            elif v < -0.5:
                shade = 0
            elif v < -0.12:
                shade = 1
            elif v < 0.3:
                shade = 2
            elif v < 0.72:
                shade = 3
            else:
                shade = 4
            c = ramp[shade]
            if shade in (1, 2) and g > 0.9:
                c = accent
            elif shade in (2, 3) and g < -0.9 and d < 0.6:
                c = ramp[0]  # gaps between leaves
            cv.put(x, y, c)


def small_tree(dead=False):
    wood = Canvas(32, 32)
    for i, (x0, y0, x1, y1) in enumerate(BOUGHS + (TWIGS if dead else [])):
        wood.line(x0, y0, x1, y1, BARK[2])
        if i in (0, 3, 6):
            wood.line(x0 + (1 if x1 >= x0 else -1), y0, x1, y1 + 1, BARK[1])
        if dead or i < 7:
            wood.line(x0, y0 - 1, x1, y1 - 1, BARK[3] if i < len(BOUGHS) else BARK[2])
    for y, left, right in TRUNK:
        for x in range(left, right + 1):
            edge = (x - left) / max(1, right - left)
            wood.put(x, y, BARK[3] if edge < 0.3 else BARK[2] if edge < 0.7 else BARK[1])
    for x, y in ((14, 27), (14, 23), (13, 30)):
        wood.put(x, y, BARK[4])  # bark glints
    for x, y in ((15, 25), (16, 22), (15, 29), (16, 28)):
        wood.put(x, y, BARK[1])  # bark furrows
    wood.outline(BARK[0])
    cv = Canvas(32, 32)
    cv.stamp(wood)
    if dead:
        for clump in DEAD_CLUMPS:
            leaf_clump(cv, clump, DRY, DRY_ACCENT)
    else:
        leaves = Canvas(32, 32)
        for clump in CLUMPS:
            leaf_clump(leaves, clump, LEAF, LEAF_ACCENT)
        # windows in the crown where the boughs show through
        for x, y in ((11, 11), (12, 11), (12, 12), (19, 11), (20, 12), (19, 12), (15, 16), (15, 17),
                     (16, 17), (14, 17)):
            leaves.px.pop((x, y), None)
        # stray leaves off the silhouette
        for x, y, s in ((1, 11, 2), (30, 11, 1), (8, 3, 3), (22, 2, 2), (3, 16, 1), (28, 17, 0),
                        (13, 0, 3), (18, 0, 2), (6, 17, 1), (24, 18, 0)):
            leaves.put(x, y, LEAF[s])
        leaves.outline(LEAF_EDGE)
        cv.stamp(leaves)
    cv.shadow(15.5, 30.2, 9.5, 2.3)
    return cv.image()


# ------------------------------------------------------------------ palms
def bezier(p0, p1, p2, t):
    u = 1 - t
    return (u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0],
            u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1])


def frond(spine, reach, ramp, sparse=False):
    """One frond on its own canvas: a curved midrib with leaflets hanging off both sides."""
    p0, p1, p2 = spine
    cv, rib, run, prev = Canvas(32, 64), [], 0.0, p0
    steps = 48
    for i in range(steps + 1):
        t = i / steps
        x, y = bezier(p0, p1, p2, t)
        nx, ny = bezier(p0, p1, p2, min(1, t + 0.02))
        px, py = bezier(p0, p1, p2, max(0, t - 0.02))
        tx, ty = nx - px, ny - py
        n = math.hypot(tx, ty) or 1
        tx, ty = tx / n, ty / n
        rib.append((round(x), round(y)))
        run += math.hypot(x - prev[0], y - prev[1])
        prev = (x, y)
        length = reach * math.sin(math.pi * min(1, t * 0.92 + 0.08) ** 0.75) + 0.6
        if int(run) % 3 == 2:
            length *= 0.45  # notches between leaflets
        if sparse and i % 6 in (2, 3):
            continue  # a dead frond has lost leaflets
        for side in (1, -1):
            lx, ly = -ty * side + tx * 0.35, tx * side + ty * 0.35 + 0.55  # swept back, drooping
            n = math.hypot(lx, ly) or 1
            lx, ly = lx / n, ly / n
            lit = (-ty * side) * -0.55 + (tx * side) * -0.83 > 0
            k = 1.0
            while k <= length:
                last = k + 1 > length
                if lit:
                    c = ramp[2] if last else ramp[3]
                else:
                    c = ramp[1] if last or k > length * 0.55 else ramp[2]
                cv.put(round(x + lx * k), round(y + ly * k), c)
                k += 0.5
    for j, (x, y) in enumerate(rib):
        cv.put(x, y, ramp[4] if j < len(rib) * 0.7 else ramp[3])
    cv.outline(ramp[0])
    return cv


def palm_trunk(cv, centre, bark):
    """centre: [(y, x)] knots of the trunk centre line, top to bottom."""
    top, base = centre[0][0], centre[-1][0]
    for y in range(top, base + 1):
        for (ya, xa), (yb, xb) in zip(centre, centre[1:]):
            if ya <= y <= yb:
                cx = xa + (xb - xa) * (y - ya) / (yb - ya)
        width = 3 if y < top + 14 else 4
        left = round(cx) - 1  # the trunk thickens on its shaded side
        if y >= base - 1:
            left, width = left - 1, width + 2  # root flare
        right = left + width - 1
        ring = (y - top) % 3 == 2  # leaf scars
        for x in range(left, right + 1):
            e = (x - left) / max(1, right - left)
            shade = 4 if e < 0.2 else 3 if e < 0.5 else 2 if e < 0.8 else 1
            if ring:
                shade = max(1, shade - 1)
            cv.put(x, y, bark[shade])
    cv.outline(bark[0])


# Crown hub (x, y) and trunk centre lines. The base stands on BYOND x=16/17.
PALMS = {
    'palm1': dict(
        hub=(17, 22),
        trunk=[(22, 17.0), (30, 17.6), (40, 17.2), (50, 15.8), (58, 14.8), (62, 14.6)],
        # fronds back to front: (control, tip, leaflet reach)
        fronds=[((16, 11), (11, 13), 2.6), ((21, 11), (25, 14), 2.6),
                ((9, 11), (2, 17), 3.2), ((26, 12), (30, 19), 3.0),
                ((7, 17), (2, 28), 3.2), ((27, 18), (30, 30), 3.0),
                ((11, 19), (8, 33), 3.0), ((23, 20), (25, 34), 2.8),
                ((17, 13), (18, 14), 2.0)],
        nuts=[(15, 24), (18, 25), (17, 23)],
    ),
    'palm2': dict(
        hub=(14, 23),
        trunk=[(23, 14.0), (31, 13.2), (41, 13.6), (51, 14.6), (58, 15.2), (62, 15.4)],
        fronds=[((12, 11), (17, 12), 2.6), ((10, 12), (5, 14), 2.6),
                ((20, 11), (28, 15), 3.2), ((6, 14), (1, 22), 3.0),
                ((25, 16), (30, 26), 3.2), ((5, 20), (2, 32), 3.0),
                ((20, 19), (24, 33), 3.0), ((9, 21), (8, 35), 2.8),
                ((14, 14), (13, 15), 2.0)],
        nuts=[(13, 25), (16, 25), (14, 26)],
    ),
}
# Dead fronds hang: each (control, tip) is pulled down toward the trunk.
DEAD_FRONDS = {
    'palm1': [((15, 8), (10, 15), 2.2), ((23, 9), (27, 18), 2.2),
              ((8, 15), (4, 27), 2.6), ((27, 16), (29, 29), 2.6),
              ((11, 19), (9, 35), 2.6), ((23, 19), (24, 36), 2.4),
              ((14, 21), (14, 33), 2.0), ((20, 21), (20, 31), 2.0)],
    'palm2': [((13, 9), (18, 15), 2.2), ((9, 9), (4, 17), 2.2),
              ((21, 15), (26, 26), 2.6), ((5, 17), (3, 30), 2.6),
              ((19, 19), (21, 36), 2.6), ((8, 20), (8, 37), 2.4),
              ((16, 22), (17, 33), 2.0), ((11, 22), (11, 32), 2.0)],
}
PALM_TOP = 10  # image row of the highest opaque pixel = BYOND row 54


def palm(name, dead=False):
    spec = PALMS[name]
    hub = spec['hub']
    cv = Canvas(32, 64)
    palm_trunk(cv, spec['trunk'], PALM_BARK_DRY if dead else PALM_BARK)
    fronds = DEAD_FRONDS[name] if dead else spec['fronds']
    ramp = FROND_DRY if dead else FROND
    for i, (control, tip, reach) in enumerate(fronds):
        layer = frond((hub, control, tip), reach, ramp, sparse=dead)
        if i < 2:  # the two rear fronds sit in shade
            for k, c in layer.px.items():
                if c in ramp[2:]:
                    layer.px[k] = ramp[ramp.index(c) - 1]
        cv.stamp(layer)
    if not dead:
        for x, y in spec['nuts']:
            for dx, dy, c in ((0, 0, NUT[2]), (1, 0, NUT[1]), (0, 1, NUT[1]), (1, 1, NUT[0])):
                cv.put(x + dx, y + dy, c)
    top = min(y for (_, y) in cv.px)
    assert top == PALM_TOP, (name, dead, top)  # the climbing probe pins this row
    base = spec['trunk'][-1]
    cv.shadow(base[1] + 0.5, 62.2, 7.5, 1.9)
    return cv.image()


# ------------------------------------------------------------- DMI plumbing
def replace_states(path, size, frames):
    """Paste frames over their named single-frame states; keep all else as it is."""
    w, h = size
    im = Image.open(path)
    text = im.info['Description']
    im = im.convert('RGBA')
    cols, index, found = im.width // w, 0, set()
    name, count = None, 1
    blocks = []
    for line in text.splitlines():
        if line.startswith('state = '):
            blocks.append([line.split('"')[1], 1])
        elif blocks and line.strip().split(' = ')[0] in ('dirs', 'frames'):
            blocks[-1][1] *= int(line.strip().split(' = ')[1])
    for name, count in blocks:
        if name in frames and name not in found:
            assert count == 1 and frames[name].size == size, name
            im.paste(frames[name], ((index % cols) * w, (index // cols) * h))
            found.add(name)
        index += count
    assert found == set(frames), sorted(set(frames) - found)
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    im.save(path, format='PNG', pnginfo=meta, optimize=True)


def build():
    return {
        ('icons/obj/flora/wild.dmi', (32, 32)): {'tree': small_tree(), 'deadtree': small_tree(dead=True)},
        ('icons/obj/flora/palm.dmi', (32, 64)): {
            'palm1': palm('palm1'), 'palm2': palm('palm2'),
            'dead_palm1': palm('palm1', dead=True), 'dead_palm2': palm('palm2', dead=True)},
    }


def preview(sheets, out):
    """Review sheet of the actual sprite pixels at 4x on flat grass; not a gameplay screenshot."""
    frames = [f for states in sheets.values() for f in states.values()]
    sheet = Image.new('RGBA', (sum(f.width + 4 for f in frames) + 4, 72), (74, 104, 58, 255))
    x = 4
    for f in frames:
        sheet.alpha_composite(f, (x, 68 - f.height))
        x += f.width + 4
    sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).convert('RGB').save(out)


def main():
    sheets = build()
    for (path, size), frames in sheets.items():
        replace_states(ROOT / path, size, frames)
    if '--preview' in sys.argv[1:-1]:
        preview(sheets, sys.argv[sys.argv.index('--preview') + 1])


if __name__ == '__main__':
    main()
