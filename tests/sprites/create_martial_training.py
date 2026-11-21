"""Hand-placed 32px art for the martial training gear: the makiwara, a
tapered wooden striking post set in a timber footing on packed earth with a
pad of bound straw rope at fist height, and the gravel pail, a stout wooden
stave pail with two iron hoops and rope grips, packed to the brim with grey
gravel that has a dent where fingers have been driven in.
Every pixel is placed by this script from fixed palettes (Pillow only); no
external or generated artwork. Light falls from the upper left.

Run with Pillow to reproduce
  icons/obj/martial_training.dmi              `makiwara` and `gravel_pail`,
                                              one direction each

`--check` verifies the committed sheet byte for byte, `--preview <png>`
writes a 4x review sheet of both states on grass, dirt and a wooden floor,
each with a 1x copy beneath. Released under Civ13 AGPL-3.0.
"""
import io
import math
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/martial_training.dmi'

OUT = (38, 34, 36)
SHADOW = (20, 22, 20, 70)
# palettes of create_training_gear.py, light to dark
COBBLE = [(222, 216, 200), (196, 189, 172), (166, 158, 143), (134, 127, 115), (102, 96, 88)]
QUARRY = [(204, 204, 200), (174, 175, 172), (144, 145, 144), (112, 113, 115), (82, 83, 88)]
GRANITE = [(176, 172, 176), (146, 142, 148), (116, 112, 120), (88, 84, 94), (62, 58, 68)]
WOOD = [(224, 186, 146), (198, 156, 118), (170, 126, 90), (144, 102, 71), (116, 82, 55), (86, 58, 36)]
BARK = [(150, 112, 78), (124, 90, 60), (98, 68, 46), (74, 50, 34)]
ROPE = [(226, 204, 150), (184, 158, 104)]
IRON = [(214, 218, 224), (168, 174, 182), (124, 130, 140), (88, 92, 102), (56, 60, 68)]
# the rope pair with a sunlit straw above it and a shaded turn below
STRAW = [(246, 232, 186), ROPE[0], ROPE[1], (142, 116, 72)]


class Frame:
    def __init__(self):
        self.px = {}

    def put(self, x, y, c):
        if 0 <= x < 32 and 0 <= y < 32:
            self.px[(x, y)] = tuple(c) if len(c) == 4 else tuple(c) + (255,)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def pts(self, c, *points):
        for x, y in points:
            self.put(x, y, c)

    def outline(self, c=OUT):
        solid = {p for p, v in self.px.items() if v[3] == 255}
        edge = set()
        for (x, y) in solid:
            for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if n not in solid:
                    edge.add(n)
        for x, y in edge:
            self.put(x, y, c)
        return self

    def under(self, other):
        """Lay `other` beneath this frame."""
        for p, v in other.px.items():
            if p not in self.px:
                self.px[p] = v
        return self

    def image(self):
        im = Image.new('RGBA', (32, 32))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c)
        return im


def noise(x, y, seed=0):
    n = (x * 374761393 + y * 668265263 + seed * 2147483647) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def ground_shadow(cx, cy, rx, ry):
    f = Frame()
    for y in range(32):
        for x in range(32):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                f.put(x, y, SHADOW)
    return f


# --- makiwara ---------------------------------------------------------------

def makiwara():
    """A board tapering from a thick foot to a thin springy top, clamped
    between two footing timbers on a pad of packed earth."""
    f = Frame()
    # packed earth round the foot, with a few set stones
    for y in range(25, 30):
        for x in range(32):
            if ((x + 0.5 - 16) / 9.2) ** 2 + ((y + 0.5 - 27.4) / 2.3) ** 2 <= 1.0:
                tone = 1 if y < 27 and x < 18 else 3 if y > 27 or x > 22 else 2
                if noise(x, y, 7) > 0.8:
                    tone = min(3, tone + 1)
                f.put(x, y, BARK[tone])
    f.pts(QUARRY[1], (8, 27), (22, 28))
    f.pts(QUARRY[3], (9, 27), (23, 28), (12, 29))
    # the board, thin at the top and thick at the foot
    for y in range(2, 25):
        x0 = 14 if y < 16 else 13
        x1 = 17 if y < 14 else 18
        for x in range(x0, x1 + 1):
            tone = 0 if x == x0 else 4 if x == x1 else 3 if x == x1 - 1 else 1 if x == x0 + 1 else 2
            if tone in (1, 2) and noise(x, y // 4, 4) > 0.7:
                tone += 1                                         # grain
            f.put(x, y, WOOD[tone])
    f.pts(WOOD[0], (14, 2), (15, 2), (16, 2))                     # cut top
    f.put(17, 2, WOOD[2])
    f.pts(WOOD[5], (15, 18), (15, 19), (16, 21))                  # a check in the grain
    # the straw rope pad, turn over turn, standing proud of the board
    for y in range(7, 15):
        for x in range(13, 19):
            turn = (y - 7) % 2
            tone = 1 if turn == 0 else 3
            if x == 13:
                tone = 0 if turn == 0 else 2
            elif x >= 18:
                tone = 3
            elif x == 17:
                tone = 2 if turn == 0 else 3
            elif (x + y // 2) % 3 == 0 and turn == 0:
                tone = 0                                          # twist of the strands
            f.put(x, y, STRAW[tone])
    for x in range(13, 19):
        f.put(x, 6, STRAW[0] if x < 17 else STRAW[2])             # top turn catches the light
    f.pts(STRAW[1], (19, 14), (20, 15))                           # the loose tail of the binding
    f.pts(STRAW[3], (20, 16), (19, 15))
    # footing timbers: one across the front, the end of one behind
    f.rect(19, 21, 22, 22, WOOD[4])
    f.pts(WOOD[5], (22, 22), (21, 22))
    for x in range(9, 23):
        f.put(x, 22, WOOD[1] if x < 20 else WOOD[2])
        f.put(x, 23, WOOD[2] if noise(x // 3, 23, 2) < 0.75 else WOOD[3])
        f.put(x, 24, WOOD[3])
        f.put(x, 25, WOOD[4] if x < 21 else WOOD[5])
    for y in range(22, 26):                                       # sawn end grain
        f.put(9, y, WOOD[0] if y < 25 else WOOD[2])
        f.put(22, y, WOOD[4] if y < 25 else WOOD[5])
    f.pts(IRON[3], (12, 23), (19, 23))                            # iron spikes pin it
    f.pts(IRON[1], (12, 24), (19, 24))
    return f.outline().under(ground_shadow(17.5, 28.6, 10.0, 2.4))


# --- gravel pail -------------------------------------------------------------

def gravel_pail():
    """A stave pail seen from a little above: the round mouth heaped with
    gravel, two iron hoops and a rope grip at each side."""
    f = Frame()
    cx, top, rx, ry = 15.5, 14.0, 7.0, 3.4
    foot = 26.0
    # the staves
    for y in range(12, 31):
        for x in range(32):
            dx = x + 0.5 - cx
            v = (y + 0.5 - top) / (foot - top)
            hw = rx - 1.3 * max(0.0, min(1.0, v))
            if abs(dx) > hw:
                continue
            t = dx / hw
            curve = math.sqrt(1 - t * t)
            if y + 0.5 < top or y + 0.5 > foot + 2.4 * curve:
                continue
            tone = 2 if t < -0.78 else 1 if t < -0.3 else 2 if t < 0.25 else 3 if t < 0.7 else 4
            if (x - 9) % 3 == 2:
                tone = min(5, tone + 1)                           # seam between staves
            if y + 0.5 > foot + 2.4 * curve - 1.0:
                tone = min(5, tone + 1)                           # the foot in shade
            f.put(x, y, WOOD[tone])
            for hoop in (4.0, 9.0):                               # iron hoops follow the curve
                if int(top + hoop + 1.9 * curve) == y:
                    f.put(x, y, IRON[2 if t < -0.8 else 0 if t < -0.45 else 1 if t < 0.1 else 2 if t < 0.55 else 3])
                elif int(top + hoop + 1.9 * curve) + 1 == y:
                    f.put(x, y, WOOD[5])
    # the rim: stave tops round the mouth
    for y in range(32):
        for x in range(32):
            nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - top) / ry
            if nx * nx + ny * ny <= 1.0:
                f.put(x, y, WOOD[3] if ny < -0.1 else WOOD[0] if nx < 0.45 else WOOD[1])
                if ny > 0 and (x + 0.5 - cx) ** 2 / rx ** 2 + (y + 1.5 - top) ** 2 / ry ** 2 > 1.0:
                    f.put(x, y + 1, WOOD[5] if nx > -0.5 else WOOD[4])  # shade under the lip
    # gravel, heaped a little above the rim
    gy, grx, gry = 13.2, 5.9, 3.1
    for y in range(32):
        for x in range(32):
            nx, ny = (x + 0.5 - cx) / grx, (y + 0.5 - gy) / gry
            if nx * nx + ny * ny > 1.0:
                continue
            lit = nx * 0.5 + ny * 0.65 + (noise(x, y, 11) - 0.5) * 1.9
            tone = 0 if lit < -0.5 else 1 if lit < -0.05 else 2 if lit < 0.4 else 3 if lit < 0.8 else 4
            pal = COBBLE if noise(x, y, 5) > 0.8 else QUARRY
            f.put(x, y, pal[tone])
    # the dent left by driven fingers: dark under its near lip, lit far side
    f.pts(GRANITE[4], (15, 12), (16, 12))
    f.pts(GRANITE[3], (14, 12), (15, 13), (16, 13))
    f.pts(QUARRY[4], (17, 12), (15, 11))
    f.pts(QUARRY[0], (17, 13), (16, 14), (14, 13))
    # a rope grip knotted through the top of a stave at each side
    f.pts(ROPE[0], (7, 15), (7, 16), (24, 15))
    f.pts(ROPE[1], (7, 17), (24, 16), (24, 17))
    # pebbles spilled by the foot
    f.pts(QUARRY[1], (6, 28), (25, 27))
    f.pts(QUARRY[3], (7, 28), (25, 28))
    return f.outline().under(ground_shadow(17.0, 28.2, 9.0, 2.2))


OBJ = {
    'makiwara': (1, 1, None, [makiwara()]),
    'gravel_pail': (1, 1, None, [gravel_pail()]),
}


def dmi_bytes(table):
    frames = [fr for (_, _, _, frs) in table.values() for fr in frs]
    cols = 8
    rows = (len(frames) + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * 32, rows * 32))
    for i, fr in enumerate(frames):
        sheet.paste(fr.image(), ((i % cols) * 32, (i // cols) * 32))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, (dirs, count, delay, _) in table.items():
        text += 'state = "%s"\n\tdirs = %d\n\tframes = %d\n' % (name, dirs, count)
        if delay:
            text += '\tdelay = %s\n' % ','.join([str(delay)] * count)
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    out = io.BytesIO()
    sheet.save(out, format='PNG', pnginfo=meta)
    return out.getvalue()


def check_drawing():
    problems = []
    for name, (dirs, count, _, frs) in OBJ.items():
        if len(frs) != dirs * count:
            problems.append('%s: frame count does not match its directions' % name)
        for fr in frs:
            solid = [p for p, c in fr.px.items() if c[3] == 255]
            if not solid:
                problems.append('%s: empty frame' % name)
                continue
            if max(y for _, y in solid) < 26:
                problems.append('%s: does not stand on the floor' % name)
    post = [p for p, c in OBJ['makiwara'][3][0].px.items() if c[3] == 255]
    pail = [p for p, c in OBJ['gravel_pail'][3][0].px.items() if c[3] == 255]
    if min(y for _, y in pail) <= min(y for _, y in post):
        problems.append('gravel_pail: should stand lower than the makiwara')
    return problems


def write_preview(path, scale=4):
    """Each state on grass, dirt and a wooden floor at `scale`, with the same
    tiles at 1x in a row beneath."""
    grounds = ((86, 128, 62, 255), (134, 102, 70, 255), (150, 112, 78, 255))
    cell, gap = 32 * scale, 6
    tiles = []
    for ground in grounds:
        for _, _, _, frs in OBJ.values():
            tile = Image.new('RGBA', (32, 32), ground)
            if ground == grounds[2]:
                for y in range(0, 32, 8):                         # floor boards
                    for x in range(32):
                        tile.putpixel((x, y), (116, 84, 58, 255))
            tile.alpha_composite(frs[0].image())
            tiles.append(tile)
    sheet = Image.new('RGBA', (gap + len(tiles) * (cell + gap), gap + cell + gap + 32 + gap), (30, 32, 36, 255))
    for i, tile in enumerate(tiles):
        sheet.alpha_composite(tile.resize((cell, cell), Image.NEAREST), (gap + i * (cell + gap), gap))
        sheet.alpha_composite(tile, (gap + i * (cell + gap) + (cell - 32) // 2, gap + cell + gap))
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert('RGB').save(path)


def main():
    args = sys.argv[1:]
    problems = check_drawing()
    if '--check' in args:
        if not SHEET.exists():
            problems.append('missing sheet: %s' % SHEET)
        elif SHEET.read_bytes() != dmi_bytes(OBJ):
            problems.append('stale sheet: %s' % SHEET)
        for line in problems:
            print(line)
        print('martial training: %s' % ('FAILED' if problems else 'ok'))
        return 1 if problems else 0
    if problems:
        print('\n'.join(problems))
        return 1
    SHEET.write_bytes(dmi_bytes(OBJ))
    if '--preview' in args[:-1]:
        write_preview(args[args.index('--preview') + 1])
    return 0


if __name__ == '__main__':
    sys.exit(main())
