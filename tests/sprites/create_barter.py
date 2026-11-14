"""Hand-placed 32px barter goods: a coil of ground stone beads, a coil of
bone beads, and the hide barter mat, empty and laid with trade goods on both
sides of its dividing stick. Every pixel is placed by this script from a
fixed palette (Pillow only); no external or generated artwork.
The outline, wood, bone, cord and stone tones are the ones
create_stone_age_rites.py and create_stone_age_traps.py use, lit from the
upper left. The mat is a scraped hide with an irregular edge and leg tabs,
in leather tones, so it does not read as the reed feast mat of
icons/obj/stone_age_rites.dmi. Everything is drawn without a tile background
so the floor shows around it.

Run with Pillow to reproduce icons/obj/barter.dmi. `--preview <png>` also
writes a labelled review sheet (4x and 1x, on grass and on dirt).
Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]

OUT = (62, 49, 34)
# wood, light to dark
WD = [(198, 151, 106), (168, 122, 76), (122, 84, 50), (92, 61, 34)]
# pale peeled wood and bone
PW = [(214, 180, 132), (184, 146, 98), (140, 104, 64)]
BN = [(240, 232, 208), (206, 194, 164), (160, 146, 118)]
# plant-fibre twine
CD = [(205, 185, 143), (156, 131, 96), (112, 90, 62)]
# ground stone beads: grey, green and ochre, each light then dark
ST = [(170, 168, 160), (136, 134, 128), (104, 102, 98), (76, 74, 72)]
GS = [(128, 178, 120), (74, 124, 84)]
OC = [(224, 164, 70), (170, 110, 44)]
# flint, light to dark (create_stone_age_arms.py)
FL = [(184, 178, 168), (154, 149, 141), (111, 106, 100), (79, 74, 68)]
# scraped hide of the mat, light to dark
HD = [(200, 150, 100), (172, 120, 76), (140, 94, 58), (108, 70, 44)]
# grey winter fur of the pelt bundle
FR = [(196, 190, 178), (158, 152, 142), (116, 110, 104)]
# salt cake
SA = [(246, 244, 236), (218, 216, 206), (176, 176, 170)]
# preview backgrounds
GRASS = (86, 128, 62)
DIRT = (134, 102, 70)
DARK = (30, 32, 36)


def noise(x, y, seed=0):
    """A fixed 0..1 value per pixel, so the sheet is reproducible."""
    n = (x * 374761393 + y * 668265263 + seed * 2147483647) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


class Frame:
    def __init__(self):
        self.px = {}

    def put(self, x, y, c, a=255):
        if 0 <= x < 32 and 0 <= y < 32:
            self.px[(x, y)] = (c[0], c[1], c[2], a)

    def pts(self, c, *points):
        for x, y in points:
            self.put(x, y, c)

    def outline(self, c=OUT, a=255):
        """Ring every drawn shape with the dark outline colour."""
        edge = set()
        for (x, y) in self.px:
            for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if n not in self.px:
                    edge.add(n)
        for x, y in edge:
            self.put(x, y, c, a)

    def over(self, other):
        """Lay `other` on top of this frame."""
        self.px.update(other.px)

    def under(self, other):
        """Slip `other` beneath this frame."""
        for k, v in other.px.items():
            self.px.setdefault(k, v)

    def image(self):
        im = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c)
        return im


def bar(f, p0, p1, half, shade):
    """A straight band from p0 to p1. `half(t)` is its half-width along the
    way (t from 0 to 1); `shade(s, t)` picks the colour, s running from -1 on
    the lit upper-left edge to +1 on the shaded edge."""
    (x0, y0), (x1, y1) = p0, p1
    dx, dy = x1 - x0, y1 - y0
    ln = math.hypot(dx, dy)
    nx, ny = dy / ln, -dx / ln
    if nx + ny < 0:              # make +n point away from the light
        nx, ny = -nx, -ny
    for y in range(32):
        for x in range(32):
            px, py = x + 0.5 - x0, y + 0.5 - y0
            t = (px * dx + py * dy) / (ln * ln)
            if not 0.0 <= t <= 1.0:
                continue
            hw = half(t) if callable(half) else half
            d = px * nx + py * ny
            if hw > 0 and abs(d) <= hw:
                c = shade(d / hw, t)
                if c is not None:
                    f.put(x, y, c)


def three(pal, a=-0.34, b=0.34):
    """Light edge, middle, shaded edge."""
    return lambda s, t: pal[0] if s < a else pal[1] if s < b else pal[2]


def blob(f, cx, cy, rx, ry, pal, lx=-0.45, ly=-0.5):
    """A rounded lump shaded in bands away from a light spot."""
    for y in range(32):
        for x in range(32):
            u, v = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if u * u + v * v <= 1.0:
                d = math.hypot(u - lx, v - ly)
                f.put(x, y, pal[0] if d < 0.42 else pal[1] if d < 0.95 else pal[2] if d < 1.4 else pal[-1])


def shadow(points, a=70):
    f = Frame()
    for x, y in points:
        f.put(x, y, (20, 16, 12), a)
    return f


def loop(cx, cy, rx, ry, start=0.0, sweep=2 * math.pi):
    """The pixels of an oval string, in order along it."""
    out = []
    steps = 200
    for i in range(steps + 1):
        a = start + sweep * i / steps
        p = (int(math.floor(cx + rx * math.cos(a))), int(math.floor(cy + ry * math.sin(a))))
        if not out or out[-1] != p:
            out.append(p)
    if len(out) > 1 and out[0] == out[-1]:
        out.pop()
    return out


def string(f, points, beads, phase=0):
    """Thread beads along `points`, one pixel each: `beads` is the repeating
    run of (light, dark) pairs. A bead shows its light where the string runs
    along the top or left of its turn and its dark along the bottom."""
    n = len(points)
    for i, (x, y) in enumerate(points):
        hi, lo = beads[(i + phase) % len(beads)]
        px, py = points[i - 1] if i else points[0]
        nx, ny = points[i + 1] if i + 1 < n else points[-1]
        f.put(x, y, hi if (nx - px) - (ny - py) * 0.4 >= 0 else lo)


STONE_RUN = ((ST[0], ST[2]), (GS[0], GS[1]), (OC[0], OC[1]), (ST[1], ST[3]), (GS[0], GS[1]), (ST[0], ST[2]),
             (OC[0], OC[1]))
BONE_RUN = ((BN[0], BN[1]), (BN[1], BN[2]), (BN[0], BN[1]), (BN[0], BN[2]), (PW[0], PW[2]))


def beads(run, cx=15.5, cy=23.0):
    """A few strings of beads coiled together, one end trailing loose."""
    f = Frame()
    # each turn runs clockwise from its left end, so the top of the turn is lit
    string(f, loop(cx, cy, 6.6, 4.3, math.pi), run)                                # the outer turn
    string(f, loop(cx + 0.6, cy + 0.4, 3.4, 1.6, math.pi), run, 3)                 # the innermost turn
    tail = [(int(cx + 6 + k), int(cy + 3 + (k + 1) // 2)) for k in range(4)]
    string(f, tail, run, 1)                                                        # the loose end
    f.outline()
    f.pts(CD[1], tail[-1])                                                         # the knotted cord end
    f.under(shadow([(x, int(cy + 6)) for x in range(int(cx - 5), int(cx + 7))], 55))
    return f


def small_coil(cx, cy, run, rx=3.0, ry=2.0):
    """A bead string as it lies among the goods on the mat."""
    f = Frame()
    string(f, loop(cx, cy, rx, ry, math.pi), run)
    f.outline()
    return f


# --------------------------------------------------------------- barter mat

def hide_at(x, y):
    """Whether the pixel is hide: a rough oval body with four leg tabs and a
    short neck, the way a pegged-out skin lies."""
    u, v = (x + 0.5 - 16.0) / 12.2, (y + 0.5 - 16.8) / 7.6
    r = (abs(u) ** 2.6 + abs(v) ** 2.6) ** (1 / 2.6)
    wob = 0.07 * math.sin(x * 0.9 + 1.3) * math.cos(y * 0.7) + (noise(x // 2, y // 2, 41) - 0.5) * 0.08
    if r + wob <= 1.0:
        return True
    for lx, ly, sx, sy in ((6.2, 11.4, -1, -1), (25.8, 11.2, 1, -1), (6.0, 22.6, -1, 1), (26.0, 22.4, 1, 1)):
        px, py = (x + 0.5 - lx) * sx, (y + 0.5 - ly) * sy                          # leg tabs, splayed outward
        along, across = px * 0.86 + py * 0.5, -px * 0.5 + py * 0.86
        if -1.0 <= along <= 4.6 and abs(across) <= 1.9 - 0.22 * along:
            return True
    return math.hypot((x + 0.5 - 3.4) / 2.3, (y + 0.5 - 16.8) / 2.0) <= 1.0        # the neck, to the left


def barter_mat():
    """A scraped hide laid flat, flesh side up, with a peeled stick laid
    down the middle to part the two traders' sides."""
    f = Frame()
    cells = [(x, y) for y in range(32) for x in range(32) if hide_at(x, y)]
    inside = set(cells)
    for x, y in cells:
        lit = (x - 16) / 13.0 * 0.55 + (y - 17) / 8.0 * 0.6 + (noise(x // 3, y // 2, 43) - 0.5) * 0.5
        i = 0 if lit < -0.38 else 1 if lit < 0.42 else 2
        n = noise(x, y, 47)
        if n > 0.93:
            i = min(3, i + 1)                                                      # scraper marks and stains
        elif n < 0.05:
            i = max(0, i - 1)
        edge = sum((x + dx, y + dy) not in inside for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1)))
        if edge:                                                                   # the curled, darker rim
            i = 3 if (x - 16) + (y - 17) * 1.6 > 0 else 2
        f.put(x, y, HD[i])
    # a backbone crease and two old cuts
    f.pts(HD[2], (7, 16), (8, 16), (9, 17), (22, 18), (23, 18), (24, 17), (10, 21), (11, 22))
    f.pts(HD[0], (7, 15), (8, 15), (22, 17), (23, 17))
    f.outline()
    # the dividing stick, casting a thin shade to its right
    s = Frame()
    for y in range(6, 28):
        s.put(15, y, PW[0] if y < 24 else PW[1])
        s.put(16, y, PW[1] if y < 12 else PW[2])
    s.pts(WD[3], (16, 11), (15, 19))                                               # knots
    s.pts(PW[0], (15, 6), (16, 6))                                                 # the cut top
    s.outline()
    f.over(s)
    for y in range(9, 26):
        if f.px.get((18, y), (0, 0, 0, 0))[:3] != OUT:
            f.put(18, y, HD[3])
    f.under(shadow([(x, 27) for x in range(6, 28)] + [(x, 26) for x in range(4, 30)], 55))
    return f


def pelt_bundle():
    """A rolled pelt tied with twine, its fur outward."""
    f = Frame()
    for y in range(11, 15):
        for x in range(5, 13):
            f.put(x, y, FR[0] if y == 11 else FR[1] if y < 14 else FR[2])
    f.pts(FR[0], (7, 12), (11, 12), (8, 13)); f.pts(FR[2], (7, 13), (12, 13))      # the lie of the fur
    for y in range(11, 15):
        f.put(5, y, HD[0] if y < 13 else HD[2])                                    # the flesh side at the roll's end
        f.put(10, y, CD[0] if y < 13 else CD[2])                                   # the tie
    f.outline()
    return f


def flint_blade():
    """A long struck blade, ridge down the middle."""
    f = Frame()
    bar(f, (19.5, 11.6), (27.0, 9.4), lambda t: 1.5 * math.sin(max(0.1, min(0.9, t)) * math.pi) ** 0.6,
        lambda s, t: FL[0] if s < -0.1 else FL[2])
    f.outline()
    f.pts((236, 234, 226), (22, 10), (23, 10))                                     # fresh-flake glint
    return f


def salt_cake():
    """A pressed cake of salt: lit top face, shaded front."""
    f = Frame()
    for y in range(20, 24):
        for x in range(22, 27):
            f.put(x, y, SA[0] if y < 22 and x < 26 else SA[1] if y < 23 else SA[2])
    f.pts(SA[2], (26, 21)); f.pts(SA[1], (24, 21))
    f.outline()
    return f


def barter_mat_goods():
    """The mat with an offer on each side: stone beads and a rolled pelt on the
    left; a flint blade, a salt cake and bone beads on the right."""
    f = barter_mat()
    f.over(pelt_bundle())
    f.over(small_coil(8.5, 20.0, STONE_RUN))
    f.over(flint_blade())
    f.over(salt_cake())
    f.over(small_coil(22.0, 16.5, BONE_RUN, 2.6, 1.6))
    return f


STATES = {
    'beads_stone': beads(STONE_RUN),
    'beads_bone': beads(BONE_RUN),
    'barter_mat': barter_mat(),
    'barter_mat_goods': barter_mat_goods(),
}
COLUMNS = 4


def write_dmi(path, states):
    rows = -(-len(states) // COLUMNS)
    sheet = Image.new('RGBA', (32 * COLUMNS, 32 * rows), (0, 0, 0, 0))
    for i, fr in enumerate(states.values()):
        sheet.paste(fr.image(), (i % COLUMNS * 32, i // COLUMNS * 32))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name in states:
        text += 'state = "%s"\n\tdirs = 1\n\tframes = 1\n' % name
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta)


def ground(colour, seed):
    """A flat preview floor with a little fixed speckle."""
    tile = Image.new('RGBA', (32, 32), colour + (255,))
    for y in range(32):
        for x in range(32):
            n = noise(x, y, seed)
            if n > 0.86 or n < 0.1:
                d = 9 if n > 0.5 else -9
                tile.putpixel((x, y), tuple(max(0, min(255, v + d)) for v in colour) + (255,))
    return tile


def write_preview(path, scale=4, per_row=4):
    """Each state at 4x on grass and on dirt, labelled, with the 1x sprite on
    both floors underneath."""
    cell = 32 * scale
    pad, label = 10, 16
    box_w, box_h = cell * 2 + 6 + pad * 2, label + cell + 44 + pad * 2
    rows = -(-len(STATES) // per_row)
    sheet = Image.new('RGBA', (box_w * per_row, box_h * rows), DARK + (255,))
    draw = ImageDraw.Draw(sheet)
    floors = {'grass': ground(GRASS, 31), 'dirt': ground(DIRT, 32)}
    for i, (name, fr) in enumerate(STATES.items()):
        ox, oy = i % per_row * box_w + pad, i // per_row * box_h + pad
        draw.text((ox, oy), name, fill=(232, 228, 214))
        for j, kind in enumerate(('grass', 'dirt')):
            tile = floors[kind].copy()
            tile.alpha_composite(fr.image())
            x = ox + j * (cell + 6)
            sheet.alpha_composite(tile.resize((cell, cell), Image.NEAREST), (x, oy + label))
            sheet.alpha_composite(tile, (x, oy + label + cell + 6))
            draw.text((x + 38, oy + label + cell + 14), kind, fill=(150, 150, 140))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.convert('RGB').save(path)


def main():
    write_dmi(ROOT / 'icons/obj/barter.dmi', STATES)
    if '--preview' in sys.argv[1:-1]:
        write_preview(sys.argv[sys.argv.index('--preview') + 1])


if __name__ == '__main__':
    main()
