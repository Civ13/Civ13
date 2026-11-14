"""Hand-placed 32px Stone Age rites: the earthen burial mound with its kerb
of field stones, the stone cairn, and the woven feast mat, empty and spread
with a feast. Every pixel is placed by this script from a fixed palette
(Pillow only); no external or generated artwork.
The outline, wood, stone, leaf and earth tones are the ones
create_stone_age_traps.py and create_dugout_canoe.py use, lit from the upper
left. Everything is drawn without a tile background so the floor shows
around it.

Run with Pillow to reproduce icons/obj/stone_age_rites.dmi. `--preview <png>`
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
# pale peeled wood and bone
PW = [(214, 180, 132), (184, 146, 98), (140, 104, 64)]
BN = [(240, 232, 208), (206, 194, 164), (160, 146, 118)]
# bark, light to dark
BK = [(134, 100, 68), (108, 78, 51), (84, 59, 38), (66, 47, 31)]
# plant-fibre twine
CD = [(205, 185, 143), (156, 131, 96), (112, 90, 62)]
# field stone: neutral, a cooler and a warmer grey
ST = [(170, 168, 160), (136, 134, 128), (104, 102, 98), (76, 74, 72)]
SC = [(160, 166, 168), (126, 132, 136), (96, 100, 106), (70, 72, 78)]
SW = [(178, 170, 154), (144, 136, 122), (110, 102, 92), (80, 74, 68)]
# lichen
LI = [(196, 198, 132), (150, 160, 92)]
# leaves and grass
LF = [(122, 156, 70), (90, 126, 52), (62, 94, 40), (44, 70, 32)]
# heaped earth, light to dark
ER = [(156, 118, 78), (128, 94, 60), (100, 72, 46), (74, 52, 34)]
# dry reed of the mat, light to dark
RD = [(224, 198, 142), (198, 168, 110), (162, 130, 80), (124, 96, 58)]
# roast meat, crackling to shadow
MT = [(206, 128, 72), (170, 88, 48), (126, 58, 34), (88, 40, 28)]
# fired clay
CL = [(198, 124, 84), (164, 94, 62), (124, 68, 46), (90, 48, 34)]
# berries, red and dark
BR = [(214, 66, 72), (160, 34, 56), (108, 40, 104), (66, 28, 72)]
# flatbread
FB = [(236, 210, 154), (210, 176, 112), (172, 132, 76)]
# roots
RT = [(222, 146, 74), (184, 104, 50), (132, 70, 38)]
# gourd
GD = [(228, 194, 100), (198, 154, 64), (154, 112, 46), (110, 80, 36)]
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


def stone(cx, cy, rx, ry, pal=ST, joint=OUT):
    """One field stone, ringed with `joint`."""
    s = Frame()
    blob(s, cx, cy, rx, ry, pal)
    s.outline(joint)
    return s


def tuft(f, x, y, kind=0):
    """A small tuft of grass rooted at (x, y)."""
    blades = (((0, 0), (0, -1), (-1, -2), (1, -1), (2, -2)), ((0, 0), (0, -1), (0, -2), (-1, -1), (1, -2)),
              ((0, 0), (-1, -1), (1, -1), (1, -2)))[kind % 3]
    for i, (dx, dy) in enumerate(blades):
        f.put(x + dx, y + dy, LF[2] if dy == 0 else LF[0] if i % 2 else LF[1])


# ------------------------------------------------------------ burial mound

def mound_at(x, y):
    """Whether the pixel is part of the barrow: a dome over an oval foot."""
    u, v = (x + 0.5 - 16.0) / 13.4, (y + 0.5 - 23.6) / 4.6
    if u * u + v * v <= 1.0:
        return True
    v = (y + 0.5 - 23.6) / 9.6
    return y + 0.5 < 23.6 and u * u + v * v <= 1.0


def burial_mound():
    """A low barrow of packed earth, grass starting on its crown, with a
    loose kerb of field stones round the foot."""
    f = Frame()
    for y in range(32):
        for x in range(32):
            if not mound_at(x, y):
                continue
            u, v = (x + 0.5 - 16.0) / 13.4, (y + 0.5 - 20.5) / 7.5
            lit = u * 0.62 + v * 0.85 + (noise(x // 2, y, 4) - 0.5) * 0.16
            i = 0 if lit < -0.52 else 1 if lit < 0.1 else 2 if lit < 0.62 else 3
            n = noise(x, y, 6)
            if n > 0.88:
                i = min(3, i + 1)                                                  # clods
            elif n < 0.08:
                i = max(0, i - 1)
            f.put(x, y, ER[i])
    # a spade-cut seam where the last earth was heaped
    f.pts(ER[3], (9, 21), (10, 22), (11, 22), (20, 19), (21, 19), (22, 20))
    f.pts(ER[0], (9, 20), (10, 21), (20, 18), (21, 18))
    f.outline()
    # thin turf creeping over the crown
    for y in range(13, 19):
        for x in range(7, 25):
            if (x, y) in f.px and f.px[(x, y)][:3] != OUT:
                d = math.hypot((x - 14.5) / 8.5, (y - 14.0) / 3.6)
                if d < 1.0 and noise(x, y, 12) > 0.42 + 0.45 * d:
                    f.put(x, y, LF[1] if x + y < 31 else LF[2])
    for i, (x, y) in enumerate(((9, 17), (13, 14), (17, 16), (21, 15), (15, 19), (24, 19), (6, 21))):
        tuft(f, x, y, i)
    # kerb stones round the sides and front of the foot
    kerb = ((-14, 2.1, 1.5, ST), (10, 1.6, 1.3, SW), (34, 2.2, 1.5, SC), (58, 1.7, 1.4, ST), (76, 2.3, 1.5, SW),
            (99, 1.7, 1.3, ST), (118, 2.2, 1.6, SC), (143, 1.8, 1.4, SW), (164, 2.2, 1.5, ST), (190, 1.6, 1.3, SC))
    for deg, rx, ry, pal in kerb:
        a = math.radians(deg)
        cx, cy = 16.0 + 13.2 * math.cos(a), 24.3 + 4.4 * math.sin(a)
        f.over(stone(round(cx * 2) / 2, round(cy * 2) / 2, rx, ry, pal))
    f.pts(LI[1], (9, 28), (22, 28))
    f.under(shadow([(x, 30) for x in range(7, 26)] + [(x, 29) for x in range(3, 30)], 60))
    return f


# -------------------------------------------------------------------- cairn

JOINT = (58, 54, 50)          # the dark between two stones of the heap
CAIRN = (
    # the base course, then each course above it; the capstone goes on last
    (9.6, 26.2, 2.9, 2.2, SW), (22.6, 26.4, 2.6, 2.0, ST), (18.6, 26.8, 2.4, 1.9, SC), (14.2, 26.4, 3.2, 2.4, ST),
    (20.6, 22.6, 2.8, 2.4, SC), (11.4, 22.2, 2.6, 2.6, ST), (16.0, 22.0, 3.0, 2.9, SW),
    (18.8, 18.2, 2.9, 2.3, ST), (13.6, 18.0, 3.1, 2.6, SC),
    (17.6, 14.6, 2.2, 2.1, SW), (14.6, 14.2, 2.5, 2.3, ST),
)


def cairn():
    """Field stones heaped into a rough cone under one flat capstone."""
    f = Frame()
    for cx, cy, rx, ry, pal in CAIRN:
        f.over(stone(cx, cy, rx, ry, pal, JOINT))
    for k in [k for k, v in f.px.items() if v[:3] == JOINT]:                       # only the joints keep that tone
        if any(n not in f.px for n in ((k[0] - 1, k[1]), (k[0] + 1, k[1]), (k[0], k[1] - 1), (k[0], k[1] + 1))):
            del f.px[k]
    f.outline()
    cap = Frame()
    for y in range(8, 13):                                                         # a flat slab: lit top, dark edge
        for x in range(11, 22):
            u, v = (x + 0.5 - 16.0) / 4.1, (y + 0.5 - 10.6) / 2.1
            if u * u + v * v <= 1.0:
                cap.put(x, y, ST[3] if y >= 11 and u > 0 else ST[2] if y >= 11 else ST[0] if u < 0.1 and y < 10
                        else ST[1])
    cap.outline()
    f.over(cap)
    # chips, cracks and lichen
    f.pts(SW[2], (16, 22), (17, 23), (13, 18), (14, 27))
    f.pts(LI[0], (14, 10), (11, 21), (19, 17), (9, 26))
    f.pts(LI[1], (15, 10), (12, 21), (15, 26), (21, 23), (14, 14), (20, 17))
    f.under(shadow([(x, 29) for x in range(8, 26)] + [(x, 28) for x in range(6, 27)] + [(25, 27), (26, 27)], 70))
    return f


# ---------------------------------------------------------------- feast mat

MAT = (3, 9, 28, 26)            # left, top, right, bottom of the woven body


def feast_mat():
    """A reed mat laid flat: twined rows of reed, fringed at both ends."""
    f = Frame()
    x0, y0, x1, y1 = MAT
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if (x in (x0, x1)) and (y in (y0, y1)):
                continue                                                           # worn corners
            warp = (x - x0) % 5 == 2                                               # the twine that binds the reeds
            row = (y - y0) % 2
            lit = (x - x0) / (x1 - x0) * 0.5 + (y - y0) / (y1 - y0) * 0.5
            if warp:
                c = RD[3] if row else RD[1]                                        # over one reed, under the next
            elif row:
                c = RD[1] if lit < 0.6 else RD[2]
            else:
                c = RD[0] if lit < 0.45 else RD[1]
            if not warp and noise(x, y, 17) > 0.95:
                c = RD[2]                                                          # a split reed here and there
            f.put(x, y, c)
    for x in range(x0 + 1, x1):                                                    # bound selvedge top and bottom
        f.put(x, y0, RD[0] if x % 2 else RD[1])
        f.put(x, y1, RD[2] if x % 2 else RD[3])
    f.outline()
    # the loose reed ends, left unoutlined so they stay light
    for y in range(y0 + 1, y1):
        if y % 2:
            f.put(x0 - 1, y, RD[2]); f.put(x0 - 2, y, RD[1])
            f.put(x1 + 1, y, RD[3]); f.put(x1 + 2, y, RD[2])
        else:
            f.put(x0 - 1, y, OUT); f.put(x1 + 1, y, OUT)
    f.pts(RD[1], (0, 12), (0, 19), (31, 16), (31, 23))                             # a few longer strands
    f.under(shadow([(x, y1 + 2) for x in range(x0 + 1, x1 + 2)], 55))
    return f


def haunch():
    """A roast haunch, the bone toward the upper right, on a broad leaf."""
    f = Frame()
    lf = Frame()
    for y in range(32):
        for x in range(32):
            u, v = (x + 0.5 - 10.8) / 7.6, (y + 0.5 - 16.4) / 4.3
            if u * u + v * v <= 1.0:
                lf.put(x, y, LF[0] if v < -0.35 else LF[1] if v < 0.45 else LF[2])
    for x in range(4, 18):
        lf.put(x, 16, LF[3])                                                       # midrib
    lf.pts(LF[3], (7, 14), (8, 15), (12, 14), (13, 15), (8, 18), (9, 17), (14, 18), (15, 17))
    lf.outline()
    f.over(lf)
    m = Frame()
    bar(m, (13.5, 13.5), (18.5, 10.6), 0.85, three(BN))                            # the bone
    blob(m, 19.0, 10.4, 1.5, 1.4, BN)                                              # its knuckle
    blob(m, 9.6, 15.6, 4.6, 3.5, MT, -0.4, -0.55)
    blob(m, 12.6, 14.2, 2.4, 2.2, MT, -0.4, -0.5)
    m.pts(MT[0], (7, 14), (8, 13), (9, 13)); m.pts((238, 176, 110), (8, 14), (9, 14))   # glaze
    m.pts(MT[3], (10, 17), (11, 16), (7, 17))                                      # char
    m.outline()
    f.over(m)
    return f


def bowl():
    """A clay bowl heaped with berries."""
    f = Frame()
    for y in range(32):
        for x in range(32):
            u, v = (x + 0.5 - 23.0), (y + 0.5 - 21.6)
            if (u / 4.6) ** 2 + (v / 3.7) ** 2 <= 1.0:
                f.put(x, y, CL[0] if u + v < -3.2 else CL[1] if u + v < 1.0 else CL[2] if u + v < 3.6 else CL[3])
    for y in range(32):
        for x in range(32):
            u, v = (x + 0.5 - 23.0) / 3.5, (y + 0.5 - 20.8) / 2.5
            if u * u + v * v <= 1.0:
                n = noise(x, y, 23)
                f.put(x, y, BR[0] if n < 0.3 else BR[1] if n < 0.55 else BR[2] if n < 0.82 else BR[3])
    f.pts(BR[0], (22, 18), (23, 18), (24, 19), (21, 19)); f.pts(BR[2], (22, 19), (25, 18))   # heaped over the rim
    f.pts((246, 170, 170), (21, 20), (24, 20), (22, 22))                           # shine
    f.outline()
    return f


def breads():
    """Three flatbreads, overlapping."""
    f = Frame()
    for cx, cy in ((7.6, 23.6), (12.0, 23.2), (9.6, 21.3)):
        b = Frame()
        for y in range(32):
            for x in range(32):
                u, v = (x + 0.5 - cx) / 3.4, (y + 0.5 - cy) / 2.1
                if u * u + v * v <= 1.0:
                    b.put(x, y, FB[0] if u + v < -0.2 else FB[1] if u + v < 0.9 else FB[2])
        b.outline()
        f.over(b)
    f.pts(WD[1], (9, 21), (12, 23), (7, 24)); f.pts(WD[2], (10, 21), (6, 23), (13, 24))    # toasted spots
    return f


def gourd():
    """A bottle gourd standing with its neck up."""
    f = Frame()
    blob(f, 24.2, 13.4, 3.3, 3.2, GD)
    blob(f, 23.9, 9.6, 1.7, 1.9, GD)
    f.pts(GD[0], (23, 11), (23, 12)); f.pts(GD[2], (22, 14), (24, 15), (26, 12))   # ribs
    f.outline()
    f.pts(WD[2], (24, 6)); f.pts(WD[3], (25, 6))                                   # stopper stub
    return f


def roots():
    """A couple of roots with their green tops left on."""
    f = Frame()
    bar(f, (14.5, 21.5), (18.0, 24.0), lambda t: 1.3 - 0.8 * t, three(RT))
    bar(f, (15.5, 24.5), (18.5, 26.2), lambda t: 1.1 - 0.6 * t, three(RT))
    f.pts(LF[0], (13, 20), (14, 20)); f.pts(LF[1], (13, 21), (14, 24), (13, 24)); f.pts(LF[2], (14, 25))
    f.outline()
    return f


def feast_mat_food():
    """The mat spread: roast haunch on a leaf, bread, roots, a bowl of
    berries and a gourd of drink."""
    f = feast_mat()
    f.over(gourd())
    f.over(haunch())
    f.over(breads())
    f.over(roots())
    f.over(bowl())
    f.pts(BR[1], (19, 17), (5, 20)); f.pts(BR[0], (18, 18), (4, 21))               # berries spilt on the mat
    f.pts(LF[1], (27, 17), (26, 18)); f.pts(LF[0], (27, 18))                       # a sprig of herbs
    return f


STATES = {
    'burial_mound': burial_mound(),
    'cairn': cairn(),
    'feast_mat': feast_mat(),
    'feast_mat_food': feast_mat_food(),
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
    write_dmi(ROOT / 'icons/obj/stone_age_rites.dmi', STATES)
    if '--preview' in sys.argv[1:-1]:
        write_preview(sys.argv[sys.argv.index('--preview') + 1])


if __name__ == '__main__':
    main()
