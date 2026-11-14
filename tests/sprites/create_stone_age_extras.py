"""Hand-placed 32px Stone Age music and harvest: the bird-bone flute, the
hide frame drum and the flint-toothed sickle, as carried items. Every pixel
is placed by this script from a fixed palette (Pillow only); no external or
generated artwork.
The outline, wood, bone and cord tones are the ones
create_stone_age_rites.py and create_stone_age_traps.py use, and the flint
greys are those of create_stone_age_arms.py, lit from the upper left.
Everything is drawn without a tile background.

Run with Pillow to reproduce icons/obj/stone_age_extras.dmi. `--preview <png>`
also writes a labelled review sheet (4x and 1x, on grass and on dirt).
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
# bone
BN = [(240, 232, 208), (206, 194, 164), (160, 146, 118)]
# plant-fibre twine and sinew lacing
CD = [(205, 185, 143), (156, 131, 96), (112, 90, 62)]
# stretched rawhide of the drum head, light to dark
HD = [(236, 216, 172), (214, 186, 136), (182, 150, 104), (146, 114, 76)]
# flint, light to dark (create_stone_age_arms.py), and the fresh-flake glint
FL = [(184, 178, 168), (154, 149, 141), (111, 106, 100), (79, 74, 68)]
GLINT = (236, 234, 226)
# birch-tar hafting pitch
PT = [(70, 56, 46), (44, 36, 32)]
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


def bend(p0, p1, p2, n=60):
    """Points along a quadratic curve from p0 to p2, pulled toward p1."""
    out = []
    for i in range(n + 1):
        t = i / n
        a, b, c = (1 - t) ** 2, 2 * t * (1 - t), t * t
        out.append((a * p0[0] + b * p1[0] + c * p2[0], a * p0[1] + b * p1[1] + c * p2[1]))
    return out


def tube(f, points, radius, pal):
    """A bent pole through `points`; `radius(t)` thins it along the way."""
    n = len(points) - 1
    for y in range(32):
        for x in range(32):
            best, bi = 99.0, 0
            for i, (sx, sy) in enumerate(points):
                d = math.hypot(x + 0.5 - sx, y + 0.5 - sy)
                if d < best:
                    best, bi = d, i
            r = radius(bi / n) if callable(radius) else radius
            if best <= r:
                sx, sy = points[bi]
                s = ((x + 0.5 - sx) + (y + 0.5 - sy)) / (r * 1.4142)
                f.put(x, y, pal[0] if s < -0.3 else pal[1] if s < 0.35 else pal[2])


# --------------------------------------------------------------- bone flute

def bone_flute():
    """A flute cut from a bird's wing bone: a thin hollow tube, the joint
    left a little swollen at the lower end, five finger holes along the top."""
    f = Frame()
    bar(f, (6.0, 26.0), (26.0, 6.0), lambda t: 1.75 + 0.5 * max(0.0, 1 - t * 6) - 0.25 * t, three(BN, -0.4, 0.3))
    f.pts(BN[2], (9, 24), (10, 22))                                                # the old joint
    f.outline()
    for x, y in ((12, 19), (14, 17), (16, 15), (18, 13), (21, 10)):                # finger holes
        f.put(x, y, OUT)
        f.put(x + 1, y + 1, BN[2])
    f.pts((98, 80, 60), (26, 5), (27, 5), (27, 6))                                 # the open bore at the mouth end
    f.pts(BN[0], (25, 5), (26, 4))
    f.pts(BN[2], (23, 10), (24, 9), (6, 27))                                       # scored rings
    f.under(shadow([(x, 34 - x) for x in range(8, 27)], 45))
    return f


# --------------------------------------------------------------- frame drum

def frame_drum():
    """A hoop of bent wood with rawhide stretched over it, seen from above
    and to one side: the head as an oval, the rim below it, sinew lacing
    zigzagging down the rim."""
    f = Frame()
    cx, cy, rx, ry, deep = 15.5, 14.0, 11.2, 7.6, 5
    for y in range(32):
        for x in range(32):
            u = (x + 0.5 - cx) / rx
            v = (y + 0.5 - cy) / ry
            if u * u + v * v <= 1.0:                                               # the head
                d = math.hypot(u + 0.35, v + 0.4)
                i = 0 if d < 0.55 else 1 if d < 1.05 else 2
                if u * u + v * v > 0.8:
                    i = min(3, i + 1)                                              # hide pulled down over the hoop
                elif noise(x // 2, y, 53) > 0.9:
                    i = min(2, i + 1)                                              # the grain of the skin
                f.put(x, y, HD[i])
                continue
            for k in range(1, deep + 1):                                           # the hoop, below the head's edge
                vk = (y - k + 0.5 - cy) / ry
                if u * u + vk * vk <= 1.0:
                    c = WD[0] if u < -0.55 else WD[1] if u < 0.25 else WD[2] if u < 0.75 else WD[3]
                    if k == deep:
                        c = WD[3] if u > -0.5 else WD[2]
                    f.put(x, y, c)
                    break
    # worn patch where the hand strikes
    f.pts(HD[2], (14, 14), (15, 14), (16, 15), (17, 14), (15, 15), (13, 15)); f.pts(HD[1], (14, 15), (16, 14))
    f.outline()
    # lacing: each thong runs from the edge of the head down across the hoop
    for j, x in enumerate(range(6, 27, 2)):
        u = (x + 0.5 - cx) / rx
        y = int(cy + ry * math.sqrt(max(0.0, 1 - u * u)))
        if j % 2 == 0:
            f.put(x, y, OUT)                                                       # the hole in the hide
            f.put(x, y + 1, CD[0])
            f.put(x - 1, y + 2, CD[0]); f.put(x + 1, y + 2, CD[1])                 # the thong forks down to the hoop
        else:
            f.put(x, y + 3, CD[0] if u < 0.3 else CD[1])                           # and is caught under its lower edge
    f.under(shadow([(x, 27) for x in range(9, 24)] + [(x, 26) for x in range(5, 28) if (x, 26) not in f.px], 55))
    return f


# -------------------------------------------------------------- flint sickle

def flint_sickle():
    """A Neolithic reaping sickle: a curved wooden haft, the grip bound with
    twine, a row of small flint blades set in pitch along the inside of the
    curve."""
    f = Frame()
    spine = bend((7.5, 27.0), (7.5, 5.5), (26.5, 8.0))
    width = lambda t: 1.9 - 0.5 * max(0.0, t - 0.75) / 0.25 if t > 0.34 else 1.55
    tube(f, spine, width, WD)
    # six small flints set edge-out along the inside of the curve, each a
    # two-pixel back against the wood with one point standing proud of it
    for (b0, b1, tip) in (((12, 15), (12, 14), (13, 15)), ((13, 13), (14, 12), (14, 13)),
                          ((15, 11), (16, 11), (16, 12)), ((18, 10), (19, 10), (19, 11)),
                          ((21, 9), (22, 9), (22, 10)), ((24, 9), (25, 9), (25, 10))):
        f.pts(FL[0], b0); f.pts(FL[1], b1); f.pts(FL[2], tip)
    f.pts(PT[0], (11, 16), (17, 10), (20, 10), (23, 9), (26, 9))                   # pitch bedding between them
    f.outline()
    f.pts(GLINT, (12, 14), (18, 10), (24, 9))
    f.pts(WD[3], (9, 16), (14, 9))                                                 # grain
    # twine round the grip
    for y in (20, 22, 24):
        for x in range(32):
            c = f.px.get((x, y))
            if c and c[:3] != OUT:
                f.put(x, y, CD[1] if c[:3] == WD[2] else CD[0])
    return f


STATES = {
    'bone_flute': bone_flute(),
    'frame_drum': frame_drum(),
    'flint_sickle': flint_sickle(),
}
COLUMNS = 3


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
    write_dmi(ROOT / 'icons/obj/stone_age_extras.dmi', STATES)
    if '--preview' in sys.argv[1:-1]:
        write_preview(sys.argv[sys.argv.index('--preview') + 1])


if __name__ == '__main__':
    main()
