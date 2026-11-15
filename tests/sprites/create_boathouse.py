"""Hand-placed 32px boathouse art: the shore office that stores boats and the
mooring piles that mark the corners of its boat slip (plain, and with a lit
lantern hung on top).
Every pixel is placed by this script from a fixed palette (Pillow only); no
external or generated artwork. Top-down 3/4 view, lit from the upper left,
dark outline, like the rest of the naval kit
(tests/sprites/create_naval_gear.py).

Run with Pillow to reproduce icons/obj/boathouse.dmi. `--preview <png>` also
writes a review sheet: every state at 8x (the office on sand and grass, the
piles on deep water and on a shoreline), and a 1x and 2x mock-up of the office
on a beach with its 7x7 slip diagonally beside it and piles on the slip's
three far corners. Released under Civ13 AGPL-3.0.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]

OUT = (22, 18, 16)
# weathered roof shingles, light to dark
SH = [(176, 160, 134), (146, 130, 106), (118, 102, 82), (88, 76, 60), (62, 52, 42)]
# wall planking, light to dark
W = [(186, 144, 92), (156, 116, 70), (124, 90, 52), (90, 62, 36)]
# door leaves and the dark inside of the shed
D = [(134, 98, 60), (104, 74, 44), (74, 52, 32)]
DARK, DARK2 = (30, 25, 24), (44, 37, 34)
# the dinghy seen through the open door
HULL = [(222, 214, 196), (176, 166, 148), (70, 104, 138)]
IRON, IRON2 = (92, 96, 104), (52, 54, 60)
ROPE = [(226, 200, 140), (180, 150, 96), (126, 100, 60)]
BUOY_W, BUOY_W2 = (240, 238, 228), (188, 186, 178)
BUOY_R, BUOY_R2 = (206, 58, 44), (148, 38, 32)
OAR = [(232, 204, 150), (198, 164, 108), (150, 116, 70)]
# tarred piles: end-grain cap, then light to dark
CAP, CAP2 = (206, 180, 140), (160, 134, 100)
T = [(132, 108, 84), (96, 76, 60), (66, 52, 42), (42, 33, 28)]
FOAM = (236, 248, 255)
# lantern
GLASS, CORE, GLOW = (255, 206, 104), (255, 246, 206), (255, 176, 72)
# preview backgrounds
WATER, WATER2 = (36, 78, 112), (44, 90, 124)
SHALLOW, SHALLOW2 = (58, 112, 142), (72, 128, 156)
SAND, SAND2 = (214, 196, 146), (198, 178, 128)
GRASS, GRASS2 = (88, 134, 66), (74, 118, 56)
SLIP = (48, 98, 132)


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

    def box(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            self.h(y, x0, x1, c)

    def outline(self, c=OUT, a=255):
        """Ring every drawn shape with the dark outline colour."""
        edge = set()
        for (x, y), col in self.px.items():
            if col[:3] == c:
                continue                 # inner outline pixels are not ringed again
            for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if n not in self.px:
                    edge.add(n)
        for x, y in edge:
            self.put(x, y, c, a)
        return self

    def soft(self, x, y, c, a):
        """A translucent pixel that never covers what is already drawn."""
        if (x, y) not in self.px:
            self.put(x, y, c, a)

    def image(self):
        im = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c)
        return im


def boathouse():
    f = Frame()
    # --- front wall: vertical planks under the eave ---
    for x in range(3, 29):
        for y in range(15, 30):
            c = W[1]
            if (x - 3) % 3 == 2:
                c = W[2]                     # seam between boards
            if y == 15:
                c = W[3]                     # shadow under the eave
            elif y == 16:
                c = W[2]
            f.put(x, y, c)
    f.v(3, 16, 29, W[0])                     # lit corner post
    f.v(4, 16, 29, W[2])
    f.v(28, 16, 29, W[3])                    # shaded corner post
    f.h(29, 4, 27, W[2])                     # sill
    # --- wide doorway: left leaf shut, right leaf swung away ---
    f.box(9, 17, 22, 29, W[3])               # frame
    f.h(17, 9, 22, D[2])
    f.box(10, 18, 21, 29, DARK)
    for x in range(10, 16):                  # the shut leaf
        f.v(x, 18, 29, D[0] if x % 2 == 0 else D[1])
    f.v(10, 18, 29, D[0])
    f.h(19, 10, 15, D[2]); f.h(27, 10, 15, D[2])       # ledges
    for i in range(6):                       # diagonal brace
        f.put(10 + i, 26 - i, D[2])
    f.pts(IRON, (15, 23), (15, 24))          # latch
    f.v(16, 18, 29, DARK2)                   # depth just inside the jamb
    # the dinghy's bow poking out of the dark
    f.h(22, 17, 21, OAR[1]); f.pts(OAR[0], (17, 22), (19, 22))   # gunwale
    f.h(23, 17, 21, HULL[0]); f.h(24, 17, 21, HULL[0])
    f.pts(HULL[1], (21, 23), (21, 24), (20, 24))
    f.h(25, 18, 20, HULL[2]); f.h(26, 18, 20, HULL[2])
    f.pts(HULL[2], (19, 27))
    f.v(19, 23, 26, HULL[1])                 # stem
    f.h(29, 17, 21, DARK2)                   # the trestle it rests on
    f.pts(D[2], (19, 28), (18, 29), (20, 29))
    # --- lifebuoy on the wall right of the door ---
    ring = [(24, 19), (25, 19), (26, 19), (23, 20), (27, 20), (23, 21), (27, 21),
            (23, 22), (27, 22), (24, 23), (25, 23), (26, 23)]
    for x, y in ring:
        f.put(x, y, BUOY_W if (x + y) < 47 else BUOY_W2)
    f.pts(BUOY_R, (25, 19), (23, 21))
    f.pts(BUOY_R2, (27, 21), (25, 23))
    f.pts(W[3], (24, 20), (25, 20), (26, 20), (24, 21), (25, 21), (26, 21),
          (24, 22), (25, 22), (26, 22))      # wall in shadow through the ring
    f.pts(IRON2, (25, 18))                   # the peg it hangs on
    # --- coil of rope under the buoy ---
    f.pts(ROPE[0], (24, 25), (25, 25), (24, 26))
    f.pts(ROPE[1], (26, 25), (26, 26), (26, 27), (24, 27), (25, 28))
    f.pts(ROPE[2], (25, 26), (25, 27), (24, 28), (26, 28))
    # --- an oar leaning on the wall left of the door ---
    f.box(5, 17, 8, 29, W[2])                # the wall behind it, in its shade
    for y in range(22, 30):
        x = 6 if y > 25 else 7
        f.put(x, y, OAR[0]); f.put(x + 1, y, W[3])
    f.box(6, 17, 7, 21, OAR[0])              # the blade, up
    f.v(7, 18, 21, OAR[1])
    f.v(8, 17, 21, W[3]); f.v(5, 17, 21, W[3])   # its edge and shadow on the wall
    f.pts(W[3], (6, 22))
    # --- roof: front slope of a pitched shingle roof, ridge along the top ---
    for y in range(2, 15):
        for x in range(1, 31):
            if y == 2:
                c = SH[0]                    # ridge cap, catching the light
            elif y == 3:
                c = SH[2]
            else:
                course = (y - 4) // 3
                row = (y - 4) % 3
                c = (SH[1], SH[2], SH[3])[row]
                if row < 2 and (x + course * 2) % 4 == 0:
                    c = SH[3]                # gap between shingles
                if x < 11 and row == 0:
                    c = SH[0]                # the lit end of each course
                if x > 24 and row < 2:
                    c = SH[min(4, SH.index(c) + 1)]
            f.put(x, y, c)
    f.h(14, 1, 30, SH[4])                    # eave edge
    f.v(1, 3, 14, W[1]); f.put(1, 2, W[0])   # barge boards on the gable ends
    f.v(30, 2, 14, W[3])
    # a tin stovepipe for the shipwright's stove
    f.box(23, 4, 24, 7, IRON); f.v(24, 4, 7, IRON2)
    f.h(3, 22, 25, IRON2)
    f.pts(SH[4], (23, 8), (24, 8), (25, 8), (25, 7))   # its shadow on the shingles
    f.outline()
    f.h(4, 22, 25, OUT)
    return f


def pile(f, x0, top, bottom, w):
    """One tarred round pile seen from above and in front: an end-grain cap
    over a shaft shaded light (left) to dark (right)."""
    x1 = x0 + w - 1
    for y in range(top + 2, bottom + 1):
        for i in range(w):
            t = i / (w - 1)
            c = T[0] if t < 0.2 else T[1] if t < 0.6 else T[2] if t < 0.85 else T[3]
            if (y + i * 2 + x0) % 7 == 0 and 0.2 <= t < 0.85:
                c = T[min(3, T.index(c) + 1)]     # checks in the timber
            f.put(x0 + i, y, c)
    f.h(top + 2, x0, x1, T[3])                    # shadow under the cap
    f.h(top - 1, x0, x1, OUT)
    f.h(top, x0, x1, CAP)
    f.h(top + 1, x0, x1, CAP)
    f.pts(CAP2, (x0 + w // 2, top + 1), (x1, top + 1), (x1, top), (x1 - 1, top + 1))
    f.v(x0 - 1, top, bottom, OUT); f.v(x1 + 1, top, bottom, OUT)
    f.h(bottom, x0, x1, T[3])                     # wet waterline


def slip_pile(lit=False):
    f = Frame()
    pile(f, 13, 7, 24, 6)                         # the tall king pile behind
    pile(f, 10, 12, 26, 5)                        # two raked piles in front
    pile(f, 17, 13, 26, 5)
    # rope lashing round all three
    for x in range(10, 22):
        f.put(x, 18, ROPE[0] if x % 2 == 0 else ROPE[1])
        f.put(x, 19, ROPE[1] if x % 2 == 0 else ROPE[2])
        f.put(x, 20, ROPE[2] if x < 20 else T[3])
    f.pts(ROPE[2], (21, 18), (21, 19))
    f.pts(ROPE[0], (12, 21)); f.pts(ROPE[1], (12, 22))        # the tail of the hitch
    if lit:
        # iron crook on the king pile with a lantern hanging from it
        f.pts(IRON, (15, 1), (16, 1))             # carrying ring
        f.h(2, 14, 17, IRON)
        f.box(14, 3, 17, 5, GLASS)
        f.pts(CORE, (15, 3), (16, 3), (15, 4), (16, 4))
        f.pts(GLOW, (14, 5), (17, 5))
        f.h(6, 14, 17, IRON2)
    f.outline()
    # ripples and foam ringing the base, so it stands in water
    for x, y, a in ((8, 26, 150), (9, 27, 210), (10, 28, 210), (11, 28, 170), (12, 29, 140),
                    (13, 28, 200), (14, 28, 220), (15, 29, 150), (16, 28, 210), (17, 28, 170),
                    (18, 29, 140), (19, 28, 200), (20, 28, 220), (21, 28, 170), (22, 27, 210),
                    (23, 26, 150), (7, 27, 80), (24, 27, 80), (9, 29, 90), (22, 29, 90),
                    (14, 30, 80), (15, 30, 60), (18, 30, 70), (19, 30, 50)):
        f.soft(x, y, FOAM, a)
    for x in (10, 11, 13, 14, 17, 18, 20, 21):     # foam lapping over the waterline
        f.put(x, 27, FOAM, 190 if x % 3 else 120)
    if lit:
        for x, y, a in ((12, 3, 110), (12, 4, 130), (12, 5, 90), (19, 3, 110), (19, 4, 130), (19, 5, 90),
                        (11, 4, 50), (20, 4, 50), (14, 0, 60), (17, 0, 60), (12, 2, 50), (19, 2, 50),
                        (12, 6, 45), (19, 6, 45)):
            f.soft(x, y, GLOW, a)
        # warm light spilling onto the cap of the king pile
        f.h(7, 14, 17, (246, 214, 150))
    return f


STATES = {
    'boathouse': [boathouse()],
    'slip_pile': [slip_pile(False)],
    'slip_pile_lit': [slip_pile(True)],
}


def write_dmi(path, states, cols=3):
    frames = [fr for group in states.values() for fr in group]
    rows = -(-len(frames) // cols)
    sheet = Image.new('RGBA', (32 * cols, 32 * rows), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(fr.image(), (i % cols * 32, i // cols * 32))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, group in states.items():
        text += 'state = "%s"\n\tdirs = %d\n\tframes = 1\n' % (name, len(group))
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta)


def ground(kind, ox=0, oy=0):
    """A flat review background tile; ox, oy keep the speckle from tiling."""
    a, b = {'sand': (SAND, SAND2), 'grass': (GRASS, GRASS2), 'water': (WATER, WATER2),
            'shallow': (SHALLOW, SHALLOW2), 'slip': (SLIP, WATER2)}[kind]
    tile = Image.new('RGBA', (32, 32), a + (255,))
    for y in range(32):
        for x in range(32):
            gx, gy = x + ox * 32, y + oy * 32
            if kind in ('water', 'shallow', 'slip'):
                if (gx + 3 * gy) % 16 < 5 and gy % 6 == 2:     # wave streaks
                    tile.putpixel((x, y), b + (255,))
            elif (gx * 7 + gy * 13) % 23 == 0 or (gx * 5 + gy * 11) % 31 == 0:
                tile.putpixel((x, y), b + (255,))
    return tile


def shore_tile():
    """Sand above, shallows below, with a foam line between."""
    tile = ground('sand')
    low = ground('shallow')
    for y in range(32):
        for x in range(32):
            edge = 15 + (1 if (x // 5) % 2 else 0) + (1 if x % 11 < 3 else 0)
            if y > edge:
                tile.putpixel((x, y), low.getpixel((x, y)))
            elif y == edge:
                tile.putpixel((x, y), FOAM + (255,))
    return tile


def write_preview(path, scale=8):
    img = {name: group[0].image() for name, group in STATES.items()}
    cells = [('boathouse', ground('sand'), 'boathouse on sand'),
             ('boathouse', ground('grass'), 'boathouse on grass'),
             ('slip_pile', ground('water'), 'slip_pile on deep water'),
             ('slip_pile', shore_tile(), 'slip_pile on shoreline'),
             ('slip_pile_lit', ground('water'), 'slip_pile_lit on deep water'),
             ('slip_pile_lit', shore_tile(), 'slip_pile_lit on shoreline')]
    cell = 32 * scale
    # mock-up: 11x10 tiles, sea above a beach; the office at (2, 7) with the
    # 7x7 slip diagonally up and right of it, piles on the three far corners
    cols, rows = 11, 10
    office, slip0, slip1 = (2, 7), (3, 0), (9, 6)
    mock = Image.new('RGBA', (32 * cols, 32 * rows))
    for ty in range(rows):
        for tx in range(cols):
            in_slip = slip0[0] <= tx <= slip1[0] and slip0[1] <= ty <= slip1[1]
            kind = 'slip' if in_slip else 'water' if ty < 6 else 'shallow' if ty == 6 else 'sand'
            mock.alpha_composite(ground(kind, tx, ty), (tx * 32, ty * 32))
    for x in range(32 * cols):                    # foam line where the beach starts
        mock.putpixel((x, 7 * 32 + (1 if (x // 5) % 2 else 0)), FOAM + (255,))
    mock.alpha_composite(img['boathouse'], (office[0] * 32, office[1] * 32))
    for i, (tx, ty) in enumerate(((slip0[0], slip0[1]), (slip1[0], slip0[1]), (slip1[0], slip1[1]))):
        mock.alpha_composite(img['slip_pile_lit' if i == 1 else 'slip_pile'], (tx * 32, ty * 32))
    pad, label = 16, 18
    width = cell * len(cells)
    height = cell + label + pad + 32 * rows * 2 + label + pad
    sheet = Image.new('RGBA', (width, height), (30, 32, 36, 255))
    draw = ImageDraw.Draw(sheet)
    for i, (name, tile, text) in enumerate(cells):
        tile = tile.copy()
        tile.alpha_composite(img[name])
        sheet.alpha_composite(tile.resize((cell, cell), Image.NEAREST), (i * cell, 0))
        draw.text((i * cell + 6, cell + 4), text + ' (8x)', fill=(220, 220, 220))
    top = cell + label + pad
    sheet.alpha_composite(mock, (pad, top))
    sheet.alpha_composite(mock.resize((mock.width * 2, mock.height * 2), Image.NEAREST), (pad * 2 + mock.width, top))
    draw.text((pad, top + mock.height + 4), 'mock-up 1x: office on the beach, 7x7 slip (lighter water), piles on its far corners', fill=(220, 220, 220))
    draw.text((pad * 2 + mock.width, top + mock.height * 2 + 4), 'mock-up 2x', fill=(220, 220, 220))
    # the three states bare at 1x and 2x on the sheet colour
    x = pad * 3 + mock.width * 3
    for i, name in enumerate(STATES):
        sheet.alpha_composite(img[name], (x, top + i * 80))
        sheet.alpha_composite(img[name].resize((64, 64), Image.NEAREST), (x + 44, top + i * 80))
        draw.text((x + 116, top + i * 80 + 10), name, fill=(220, 220, 220))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.convert('RGB').save(path)


def main():
    write_dmi(ROOT / 'icons/obj/boathouse.dmi', STATES)
    if '--preview' in sys.argv[1:-1]:
        write_preview(sys.argv[sys.argv.index('--preview') + 1])


if __name__ == '__main__':
    main()
