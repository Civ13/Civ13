"""Hand-placed 32px naval mines: the horned contact mine and the magnetic
ground mine, each as a carried item and as a laid mine seen through the water.
Every pixel is placed by this script from a fixed palette (Pillow only); no
external or generated artwork. The steel shades are the submarine hull palette
(scripts/draw_submarine_hull.py), lit from the upper left like the rest of the
kit.

Run with Pillow to reproduce icons/obj/naval_mines.dmi. `--preview <png>`
also writes a review sheet (8x, with a 1x and 2x strip underneath) that puts
the laid mines on a deep-water tile. Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]

OUT = (16, 20, 26)
# submarine hull steel: rivet highlight, H1-H4, plate seam
RIV = (136, 150, 160)
H = [(112, 128, 140), (84, 99, 112), (60, 72, 84), (40, 49, 59)]
SEAM = (48, 58, 68)
# lead Hertz horns
L = [(214, 218, 222), (166, 172, 180), (116, 122, 132), (72, 78, 88)]
# red lead primer, light to dark
RED = [(206, 82, 58), (168, 54, 40), (118, 36, 30)]
# stencil paint and brass pistol fittings
YEL = (240, 208, 64)
BRZ, BRZ2 = (176, 132, 60), (120, 86, 36)
# seen through the water
DEEP = (10, 18, 28)
MURK = (26, 40, 54)
FOAM = (214, 236, 246)
# preview backgrounds
WATER = (36, 78, 112)
WATER2 = (44, 90, 124)
FLOOR = (120, 124, 112)


class Frame:
    def __init__(self):
        self.px = {}

    def put(self, x, y, c, a=255):
        if 0 <= x < 32 and 0 <= y < 32:
            self.px[(x, y)] = (c[0], c[1], c[2], a)

    def pts(self, c, *points, a=255):
        for x, y in points:
            self.put(x, y, c, a)

    def h(self, y, x0, x1, c, a=255):
        for x in range(x0, x1 + 1):
            self.put(x, y, c, a)

    def v(self, x, y0, y1, c, a=255):
        for y in range(y0, y1 + 1):
            self.put(x, y, c, a)

    def outline(self, c=OUT, a=255):
        """Ring every drawn shape with the dark outline colour."""
        edge = set()
        for (x, y) in self.px:
            for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if n not in self.px:
                    edge.add(n)
        for x, y in edge:
            self.put(x, y, c, a)

    def image(self):
        im = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c)
        return im


def disc(cx, cy, r):
    """Pixels whose centres fall inside a circle."""
    return [(x, y) for y in range(32) for x in range(32)
            if math.hypot(x + 0.5 - cx, y + 0.5 - cy) <= r]


# ------------------------------------------------------------ contact mine

def contact_item():
    f = Frame()
    cx, cy, r = 16.0, 13.0, 6.6
    # the shell: banded shading by distance from the light spot
    for x, y in disc(cx, cy, r):
        d = math.hypot(x + 0.5 - 13.4, y + 0.5 - 9.8)
        f.put(x, y, RIV if d < 1.3 else H[0] if d < 3.9 else H[1] if d < 7.2 else H[2] if d < 10.6 else H[3])
    # welded seam between the two hemispheres, sagging towards the viewer
    for x in range(9, 23):
        y = int(13.6 + 3.2 * math.sqrt(max(0.0, 1 - ((x + 0.5 - cx) / r) ** 2)))
        if (x, y) in f.px:
            step = [RIV] + H + [H[3]]
            f.put(x, y, step[step.index(f.px[(x, y)][:3]) + 1])
    # lifting eye: shank and ring (the outline pass darkens the hole)
    f.pts(H[1], (15, 5), (16, 5))
    f.pts(H[0], (14, 3), (14, 4), (15, 2)); f.pts(H[1], (16, 2)); f.pts(H[2], (17, 3), (17, 4))
    # Hertz horns standing out of the silhouette
    f.pts(L[0], (5, 12), (6, 12), (7, 12)); f.pts(L[2], (8, 12), (8, 13))       # port
    f.pts(L[1], (5, 13)); f.pts(L[2], (6, 13), (7, 13))
    f.pts(L[1], (24, 12), (25, 12), (26, 12)); f.pts(L[3], (23, 12), (23, 13))  # starboard
    f.pts(L[2], (24, 13), (25, 13)); f.pts(L[3], (26, 13))
    f.pts(L[0], (8, 5), (9, 5), (9, 6), (10, 6)); f.pts(L[1], (10, 7)); f.pts(L[2], (8, 6), (9, 7))        # upper port
    f.pts(L[0], (22, 5), (23, 5), (21, 6)); f.pts(L[1], (22, 6), (21, 7)); f.pts(L[2], (23, 6), (22, 7))  # upper starboard
    f.outline()
    # horns on the near face point at the viewer: a lead cap on a dark collar
    for hx, hy in ((13, 13), (19, 10)):
        f.pts(L[0], (hx, hy)); f.pts(L[1], (hx + 1, hy), (hx, hy + 1)); f.pts(L[2], (hx + 1, hy + 1))
        f.pts(OUT, (hx + 2, hy + 1), (hx + 1, hy + 2), (hx + 2, hy + 2))
    # mooring cable down to the sinker
    f.pts(L[2], (15, 21), (16, 22)); f.pts(OUT, (16, 21), (15, 22))
    # sinker: a riveted iron block seen from above and in front
    s = Frame()
    s.h(24, 9, 22, H[0]); s.h(25, 9, 22, H[1]); s.pts(RIV, (10, 24), (11, 24)); s.pts(H[2], (21, 25), (22, 25))
    for y in range(26, 30):
        s.h(y, 9, 22, H[2])
        s.put(9, y, H[1]); s.pts(H[3], (21, y), (22, y))
    s.h(29, 9, 22, H[3])
    s.pts(RIV, (11, 27), (19, 27)); s.pts(H[1], (11, 28), (19, 28))
    s.h(27, 14, 17, OUT); s.h(28, 14, 17, SEAM)       # cable drum slot
    s.pts(H[3], (15, 24), (16, 24)); s.pts(OUT, (15, 25), (16, 25))  # fairlead
    s.outline()
    f.px.update(s.px)
    f.pts(L[2], (15, 23)); f.pts(OUT, (16, 23))
    return f


def contact_laid():
    """Moored a hand's breadth under the surface, seen from straight above:
    a dim shell, the crown horns standing clear of the water."""
    f = Frame()
    cx = cy = 16.0
    for x, y in disc(cx, cy, 8.1):
        d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
        lit = math.hypot(x + 0.5 - 13.2, y + 0.5 - 13.2)
        if d > 7.1:
            f.put(x, y, DEEP, 96)            # soft dark rim
        elif d > 6.0:
            f.put(x, y, DEEP, 150)
        elif lit < 3.2:
            f.put(x, y, H[2], 150)          # the crown, nearest the surface
        elif lit < 6.4:
            f.put(x, y, H[3], 160)
        else:
            f.put(x, y, MURK, 165)
    # drowned horns round the equator, barely seen
    for x, y in ((7, 15), (7, 16), (24, 15), (24, 16), (15, 7), (16, 7), (15, 24), (16, 24)):
        f.put(x, y, L[2], 120)
    for x, y in ((6, 15), (6, 16), (25, 15), (25, 16), (15, 6), (16, 6), (15, 25), (16, 25)):
        f.put(x, y, L[3], 80)
    # the crown horns break the surface
    for hx, hy in ((15, 15), (11, 11), (20, 11), (11, 20), (20, 20)):
        f.pts(L[0], (hx, hy)); f.pts(L[1], (hx + 1, hy), (hx, hy + 1)); f.pts(L[3], (hx + 1, hy + 1))
        f.pts(OUT, (hx + 2, hy + 1), (hx + 1, hy + 2), a=200)
    # ripples: a bright lip up-light of each horn, broken rings further out
    for hx, hy in ((11, 11), (20, 11), (11, 20), (20, 20)):
        f.pts(FOAM, (hx - 1, hy), (hx, hy - 1), a=190)
        f.pts(FOAM, (hx - 1, hy - 1), a=110)
    f.pts(FOAM, (14, 15), (15, 14), a=170)
    for x, y, a in ((12, 5, 150), (13, 4, 170), (14, 4, 150), (18, 4, 110), (19, 5, 110),
                    (5, 12, 150), (4, 13, 170), (4, 14, 150), (4, 18, 110), (5, 19, 110),
                    (26, 11, 110), (27, 12, 130), (27, 13, 110),
                    (11, 26, 110), (12, 27, 130), (13, 27, 110),
                    (25, 22, 90), (24, 23, 90), (22, 25, 90), (23, 24, 90)):
        f.put(x, y, FOAM, a)
    return f


# ----------------------------------------------------------- magnetic mine

# shade of each row of the lying cylinder, top (y = 13) to bottom (y = 22)
BANDS = [H[0], RIV, H[0], H[0], H[1], H[1], H[1], H[2], H[2], H[3]]
RBAND = [RED[0], RED[0], RED[0], RED[0], RED[1], RED[1], RED[1], RED[2], RED[2], RED[2]]
MAG_TOP, MAG_NOSE, MAG_TAIL = 13, 5, 26


def magnetic_rows():
    """Row spans of the mine lying on its side: domed nose to the left,
    flat tail to the right."""
    rows = {}
    for i in range(10):
        y = MAG_TOP + i
        dy = abs(y + 0.5 - 18.0)
        x0 = int(round(10.0 - math.sqrt(max(0.0, 5.2 ** 2 - dy ** 2)) * 1.0))
        tail = MAG_TAIL - (1 if i in (0, 9) else 0)
        rows[y] = (max(MAG_NOSE, x0), tail)
    return rows


def magnetic_item():
    f = Frame()
    rows = magnetic_rows()
    for i, (y, (x0, x1)) in enumerate(rows.items()):
        f.h(y, x0, x1, BANDS[i])
    # the nose dome turns away from the light towards its tip
    for y, (x0, x1) in rows.items():
        f.put(x0, y, H[2] if y < 19 else H[3])
        if 14 < y < 21:
            f.put(x0 + 1, y, H[1] if y < 18 else H[2])
    f.pts(RIV, (8, 14), (9, 14))
    # flat tail face, in shade, with the brass detonator cap
    for i, (y, (x0, x1)) in enumerate(rows.items()):
        f.put(x1, y, H[2] if i < 5 else H[3])
        f.put(x1 - 1, y, H[1] if i < 3 else H[2] if i < 7 else H[3])
        f.put(x1 - 2, y, SEAM)
    f.pts(BRZ, (25, 17)); f.pts(BRZ2, (25, 18)); f.pts(OUT, (26, 17), (26, 18))
    # red lead primer band round the body, a plate seam beside the nose
    for i, y in enumerate(rows):
        f.put(12, y, RBAND[i]); f.put(13, y, RBAND[i]); f.put(14, y, RBAND[min(9, i + 2)])
        f.put(11, y, SEAM)
    # pistol plate on the upper flank: bolted ring, brass pistol in its well
    f.h(15, 17, 20, SEAM); f.h(18, 17, 20, OUT); f.v(16, 16, 17, SEAM); f.v(21, 16, 17, OUT)
    f.pts(H[0], (17, 16), (18, 16), (17, 17)); f.pts(H[1], (20, 16), (20, 17))
    f.pts(BRZ, (18, 16), (19, 16)); f.pts(BRZ2, (18, 17), (19, 17))
    f.pts(RIV, (17, 16)); f.pts(L[0], (18, 16))
    # stencilled warning marks along the lower flank
    f.pts(YEL, (15, 20), (16, 20), (18, 20), (20, 20), (21, 20))
    f.pts(BRZ, (15, 21), (18, 21), (21, 21))
    # rivets along the keel plate
    f.pts(H[1], (16, 22), (19, 22), (22, 22))
    # lifting lugs welded to the top
    for lx in (14, 21):
        f.pts(H[1], (lx, 12), (lx + 2, 12)); f.pts(H[0], (lx, 11), (lx + 1, 11)); f.pts(H[2], (lx + 2, 11))
    f.outline()
    # bedding chocks so it reads as resting, not floating
    f.pts(H[3], (9, 24), (10, 24), (21, 24), (22, 24)); f.pts(OUT, (8, 24), (11, 24), (20, 24), (23, 24))
    f.h(25, 8, 11, OUT); f.h(25, 20, 23, OUT)
    return f


def magnetic_laid():
    """On the seabed: only a dark shape in the water, a shade deeper along
    its edge and across the primer band."""
    f = Frame()
    body = set()
    for y, (x0, x1) in magnetic_rows().items():
        for x in range(x0 - 1, x1 + 2):
            body.add((x, y - 2))
    for x in range(8, 27):
        body.add((x, MAG_TOP - 3)); body.add((x, MAG_TOP + 8))
    for (x, y) in body:
        inner = all(n in body for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))
        f.put(x, y, DEEP, 84 if inner else 108)
    for y in range(MAG_TOP - 2, MAG_TOP + 8):
        f.put(12, y, DEEP, 104); f.put(13, y, DEEP, 104)
    # the upper flank catches a little more light
    for x in range(15, 24):
        f.put(x, MAG_TOP - 1, MURK, 80)
    return f


STATES = {
    'contact': contact_item(),
    'contact_laid': contact_laid(),
    'magnetic': magnetic_item(),
    'magnetic_laid': magnetic_laid(),
}


def write_dmi(path, states):
    sheet = Image.new('RGBA', (32 * len(states), 32), (0, 0, 0, 0))
    for i, fr in enumerate(states.values()):
        sheet.paste(fr.image(), (i * 32, 0))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name in states:
        text += 'state = "%s"\n\tdirs = 1\n\tframes = 1\n' % name
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta)


def preview_tile(name, fr):
    if name.endswith('_laid'):
        tile = Image.new('RGBA', (32, 32), WATER + (255,))
        for y in range(32):          # a few wave streaks, as on the water turf
            for x in range(32):
                if (x + 3 * y) % 16 < 5 and y % 6 == 2:
                    tile.putpixel((x, y), WATER2 + (255,))
    else:
        tile = Image.new('RGBA', (32, 32), FLOOR + (255,))
    tile.alpha_composite(fr.image())
    return tile


def write_preview(path, scale=8):
    cell = 32 * scale
    sheet = Image.new('RGBA', (cell * len(STATES), cell + 80), (30, 32, 36, 255))
    for i, (name, fr) in enumerate(STATES.items()):
        tile = preview_tile(name, fr)
        sheet.alpha_composite(tile.resize((cell, cell), Image.NEAREST), (i * cell, 0))
        sheet.alpha_composite(tile, (i * cell + 16, cell + 24))
        sheet.alpha_composite(tile.resize((64, 64), Image.NEAREST), (i * cell + 64, cell + 8))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.convert('RGB').save(path)


def main():
    write_dmi(ROOT / 'icons/obj/naval_mines.dmi', STATES)
    if '--preview' in sys.argv[1:-1]:
        write_preview(sys.argv[sys.argv.index('--preview') + 1])


if __name__ == '__main__':
    main()
