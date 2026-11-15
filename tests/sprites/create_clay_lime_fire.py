"""Hand-placed sprites for the clay, lime and fire machines in
icons/obj/workshop_machines.dmi: the potter's wheel, the forge bellows, the
brick mould bench and the lime kiln, each with its idle frame and its working
loop, plus the quicklime lumps. Every pixel is placed by this script from a
fixed palette (Pillow only); no external or generated artwork.

Run with Pillow to reproduce the sheet. `--check` verifies the committed
sheet matches and `--preview <png>` writes an enlarged review sheet.
Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/workshop_machines.dmi'

OUT = (30, 22, 16)
# seasoned timber: highlight, light, mid, dark, deep
TIMBER = [(186, 140, 90), (156, 110, 66), (124, 84, 48), (92, 60, 34), (62, 40, 24)]
# field stone: highlight, light, mid, dark, deep
STONE = [(190, 188, 180), (156, 154, 146), (122, 120, 114), (90, 88, 86), (60, 58, 60)]
# wet clay: highlight, light, mid, dark
CLAY = [(214, 150, 110), (184, 116, 80), (150, 88, 60), (112, 62, 44)]
# tanned leather: highlight, light, mid, dark
HIDE = [(190, 132, 82), (156, 100, 58), (118, 72, 40), (82, 48, 28)]
# wrought iron: highlight, mid, dark
IRON = [(128, 132, 144), (84, 88, 100), (50, 52, 64)]
# burnt lime: glint, light, mid, shade
LIME = [(252, 252, 246), (232, 232, 222), (204, 204, 194), (166, 168, 162)]
# fire: core, bright, mid, deep
FIRE = [(255, 244, 170), (255, 196, 70), (240, 120, 36), (176, 56, 24)]
SMOKE = [(150, 148, 146), (116, 114, 114)]
SOOT = (44, 38, 38)


class Frame:
    def __init__(self, w=32, h=32):
        self.w, self.h, self.px = w, h, {}

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[(x, y)] = c

    def pts(self, c, *points):
        for x, y in points:
            self.put(x, y, c)

    def hline(self, x0, x1, y, c):
        for x in range(x0, x1 + 1):
            self.put(x, y, c)

    def vline(self, x, y0, y1, c):
        for y in range(y0, y1 + 1):
            self.put(x, y, c)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            self.hline(x0, x1, y, c)

    def ellipse(self, cx, cy, rx, ry, shade):
        """Filled ellipse; shade(x, y, nx, ny) picks each pixel's colour."""
        for y in range(int(cy - ry), int(cy + ry) + 1):
            for x in range(int(cx - rx), int(cx + rx) + 1):
                nx, ny = (x - cx) / rx, (y - cy) / ry
                if nx * nx + ny * ny <= 1.0:
                    self.put(x, y, shade(x, y, nx, ny))

    def outline(self, c=OUT):
        """Trace every still-clear pixel that touches a drawn one."""
        edge = set()
        for (x, y) in self.px:
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if (nx, ny) not in self.px:
                    edge.add((nx, ny))
        for x, y in edge:
            self.put(x, y, c)

    def image(self):
        im = Image.new('RGBA', (self.w, self.h))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c + (255,))
        return im


def grain(x, y, seed=0):
    """A fixed pseudo-random speckle, the same on every run."""
    v = (x * 73856093) ^ (y * 19349663) ^ (seed * 83492791)
    return (v >> 3) % 11


def plank(f, x0, y0, x1, y1, seed=0, base=2):
    """A timber face with a lit top edge, a shaded foot and long grain."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            c = TIMBER[base]
            if y == y0:
                c = TIMBER[base - 1]
            elif y == y1 and y1 > y0:
                c = TIMBER[base + 1]
            elif grain(x // 3, y, seed) == 0:
                c = TIMBER[base + 1]
            f.put(x, y, c)


def post(f, x, y0, y1, wide=2):
    for i in range(wide):
        f.vline(x + i, y0, y1, TIMBER[2] if i == 0 else TIMBER[3])
    f.put(x, y0, TIMBER[1])


# ------------------------------------------------------- potter's wheel --

def potters_wheel(step=None):
    """A kick wheel: a heavy stone flywheel near the ground, a wooden shaft
    through a timber frame and a small wheel head carrying the clay."""
    f = Frame()
    turn = 0 if step is None else step
    # flywheel, seen from above and a little in front
    def fly(x, y, nx, ny):
        c = STONE[2]
        if ny < -0.45:
            c = STONE[1]
        if ny > 0.5:
            c = STONE[3]
        # four kick marks that travel round the rim as it turns
        a = math.atan2(ny, nx) + turn * math.pi / 8
        if 0.55 < nx * nx + ny * ny < 0.9 and int((a % (math.pi / 2)) * 6) == 0:
            c = STONE[4] if step is not None or True else c
        return c
    f.ellipse(15.5, 24, 11, 4.5, fly)
    f.hline(6, 25, 28, STONE[4])
    f.hline(8, 23, 29, STONE[4])
    # frame: two posts and a cross bench behind the wheel head
    post(f, 5, 9, 25)
    post(f, 25, 9, 25)
    plank(f, 4, 13, 27, 15, seed=3)
    # shaft
    f.vline(15, 12, 22, TIMBER[3])
    f.vline(16, 12, 22, TIMBER[4])
    # wheel head
    def head(x, y, nx, ny):
        c = TIMBER[1]
        if ny > 0.3:
            c = TIMBER[2]
        a = math.atan2(ny, nx) + turn * math.pi / 4
        if nx * nx + ny * ny > 0.5 and int((a % math.pi) * 4) == 0:
            c = TIMBER[3]
        return c
    f.ellipse(15.5, 10.5, 6, 2.4, head)
    f.hline(10, 21, 13, TIMBER[4])
    # the clay: a lump at rest, a rising pot while the wheel turns
    if step is None:
        f.rect(14, 8, 17, 9, CLAY[1])
        f.hline(14, 17, 7, CLAY[0])
        f.pts(CLAY[2], (14, 10), (15, 10), (16, 10), (17, 10))
    else:
        wob = (0, 1, 0, -1)[step % 4]
        f.rect(13, 5, 18, 9, CLAY[1])
        f.vline(13, 5, 9, CLAY[0])
        f.vline(18, 5, 9, CLAY[2])
        f.hline(13, 18, 10, CLAY[3])
        f.hline(14, 17, 4, CLAY[0])
        f.hline(14, 17, 5, CLAY[3])           # the open mouth
        f.put(15 + wob, 7, CLAY[0])           # a wet glint that travels
        f.put(16 + wob, 8, CLAY[0])
    f.outline()
    return f


# -------------------------------------------------------------- bellows --

def bellows(step=None):
    """A forge bellows on a timber stand: two pear-shaped boards, leather
    pleats between them, an iron nozzle and a pump lever."""
    f = Frame()
    squeeze = 0 if step is None else (0, 2, 4, 2)[step % 4]
    top = 11 + squeeze            # the upper board drops as it is pumped
    # stand
    post(f, 7, 20, 28)
    post(f, 21, 20, 28)
    plank(f, 5, 27, 25, 28, seed=5, base=3)
    # lower board
    plank(f, 5, 21, 24, 22, seed=7)
    # leather pleats
    for y in range(top + 2, 21):
        fold = (y - top) % 3
        for x in range(6, 24):
            taper = max(0, (x - 17) // 2)       # narrows toward the nozzle
            if y < top + 2 + taper:
                continue
            c = HIDE[1]
            if fold == 0:
                c = HIDE[0]
            elif fold == 2:
                c = HIDE[3]
            elif grain(x, y, 9) == 0:
                c = HIDE[2]
            f.put(x, y, c)
    # upper board, tilted down toward the nozzle
    for x in range(4, 25):
        drop = max(0, (x - 15) // 3)
        f.put(x, top + drop, TIMBER[0] if x % 5 else TIMBER[1])
        f.put(x, top + 1 + drop, TIMBER[2])
    # brass studs along the board edge
    for x in (7, 11, 15):
        f.put(x, top + 1, (214, 176, 84))
    # nozzle
    f.rect(25, 20, 29, 21, IRON[1])
    f.hline(25, 29, 20, IRON[0])
    f.put(30, 20, IRON[2])
    f.put(30, 21, IRON[2])
    # pump lever: a pole from the upper board up to a hand grip
    f.vline(5, top - 6, top, TIMBER[2])
    f.vline(4, top - 6, top - 5, TIMBER[1])
    f.hline(2, 7, top - 7, TIMBER[1])
    f.hline(2, 7, top - 6, TIMBER[3])
    # a puff of air from the nozzle on the down stroke
    if step is not None and step % 4 in (1, 2):
        f.pts((226, 232, 236), (31, 19), (31, 22))
    f.outline()
    if step is not None and step % 4 == 2:
        f.put(31, 20, (244, 246, 248))
    return f


# ---------------------------------------------------- brick mould bench --

def brick_bench(filled=False):
    """A stout table with an open wooden mould frame of eight cells; the
    filled state shows wet clay struck level in every cell."""
    f = Frame()
    # legs
    post(f, 4, 19, 28)
    post(f, 26, 19, 28)
    post(f, 9, 21, 28, wide=1)
    post(f, 22, 21, 28, wide=1)
    # table top, seen from a little above
    for y in range(9, 19):
        for x in range(3, 29):
            c = TIMBER[1] if grain(x // 4, y, 11) else TIMBER[2]
            f.put(x, y, c)
    f.hline(3, 28, 9, TIMBER[0])
    plank(f, 3, 19, 28, 20, seed=13, base=3)
    # mould frame: 4 cells by 2
    f.rect(6, 10, 25, 17, TIMBER[3])
    for row in range(2):
        for col in range(4):
            x0, y0 = 7 + col * 5, 11 + row * 3
            for y in range(y0, y0 + 2):
                for x in range(x0, x0 + 4):
                    if filled:
                        c = CLAY[1] if y == y0 else CLAY[2]
                        if x == x0 and y == y0:
                            c = CLAY[0]
                    else:
                        c = TIMBER[4] if y == y0 else TIMBER[2]
                    f.put(x, y, c)
    f.hline(6, 25, 10, TIMBER[2])
    # a strike board and a lump of spare clay on the bench
    if filled:
        f.hline(4, 9, 18, TIMBER[0])
        f.pts(CLAY[1], (26, 17), (27, 17), (27, 18))
        f.put(26, 16, CLAY[0])
    f.outline()
    return f


# ------------------------------------------------------------ lime kiln --

def lime_kiln(step=None):
    """A squat dry-stone shaft kiln with an arched draw hole, limed white
    round the mouth; lit, the draw hole glows and the top smokes."""
    f = Frame()
    # body: a tapering stone drum, wider at the foot
    for y in range(7, 29):
        half = 7 + (y - 7) * 5 // 21
        for x in range(16 - half, 16 + half):
            course = (y - 7) // 3
            joint = (y - 7) % 3 == 2 or (x + course * 3) % 6 == 0
            edge = x - (16 - half)
            c = STONE[2]
            if edge < 2:
                c = STONE[1]
            elif edge > 2 * half - 4:
                c = STONE[3]
            if joint:
                c = STONE[4] if edge > 2 * half - 4 else STONE[3]
            elif grain(x, y, 17) == 0:
                c = STONE[1]
            f.put(x, y, c)
    # open top, seen slightly from above
    def top(x, y, nx, ny):
        return SOOT if nx * nx + ny * ny < 0.55 else STONE[1]
    f.ellipse(15.5, 7, 6.5, 2.2, top)
    # draw hole
    for y in range(21, 29):
        for x in range(12, 20):
            arch = y == 21 and x in (12, 19)
            if not arch:
                f.put(x, y, SOOT)
    f.hline(11, 20, 20, STONE[0])
    f.vline(11, 21, 28, STONE[1])
    f.vline(20, 21, 28, STONE[3])
    # spilled lime round the mouth
    f.pts(LIME[1], (10, 28), (11, 29), (21, 28), (20, 29), (9, 29), (22, 29))
    f.pts(LIME[2], (13, 28), (14, 28), (18, 28))
    f.pts(LIME[0], (15, 28), (16, 28), (17, 28))
    if step is not None:
        k = step % 4
        # glowing charge behind the draw hole
        for y in range(23, 29):
            for x in range(13, 19):
                heat = (grain(x, y, 21 + k) % 4)
                f.put(x, y, FIRE[min(3, heat + (0 if y > 25 else 1))])
        f.pts(FIRE[0], (15, 27), (16, 26 + k % 2), (14 + k, 28))
        # fire in the throat
        for x in range(12, 20):
            f.put(x, 7, FIRE[2 if (x + k) % 3 else 1])
        f.hline(13, 18, 8, FIRE[3])
        f.pts(FIRE[1], (14 + k % 3, 6), (17 - k % 2, 6))
        f.put(15 + k % 2, 5, FIRE[0])
    f.outline()
    if step is not None:
        k = step % 4
        # smoke drifting up and to the right, drawn over the outline
        for i, (dx, dy) in enumerate(((0, 0), (1, -1), (2, -2), (2, -3))):
            x, y = 15 + dx + (k + i) % 2, 3 - i + (0 if i else 0) + dy // 3
            if y >= 0:
                f.put(x, y, SMOKE[i % 2])
                f.put(x + 1, y, SMOKE[(i + 1) % 2])
    return f


# ------------------------------------------------------------ quicklime --

def quicklime():
    """A small heap of burnt lime lumps."""
    f = Frame()
    lumps = ((10, 20, 5, 3), (17, 21, 6, 3), (13, 16, 5, 3), (20, 17, 4, 2), (15, 23, 5, 2))
    for i, (cx, cy, rx, ry) in enumerate(lumps):
        def lump(x, y, nx, ny, i=i):
            if ny < -0.3 and nx < 0.3:
                return LIME[0]
            if ny > 0.45 or nx > 0.6:
                return LIME[3]
            return LIME[1] if grain(x, y, 30 + i) else LIME[2]
        f.ellipse(cx, cy, rx, ry, lump)
    f.pts(LIME[2], (7, 24), (25, 23), (23, 25))
    f.outline((96, 98, 96))
    return f


def states():
    """[(state, frames, delay)] in sheet order."""
    return [
        ('potters_wheel', [potters_wheel()], 0),
        ('potters_wheel_on', [potters_wheel(i) for i in range(8)], 1),
        ('bellows', [bellows()], 0),
        ('bellows_pump', [bellows(i) for i in range(4)], 2),
        ('brick_bench', [brick_bench()], 0),
        ('brick_bench_full', [brick_bench(True)], 0),
        ('lime_kiln', [lime_kiln()], 0),
        ('lime_kiln_on', [lime_kiln(i) for i in range(4)], 2),
        ('quicklime', [quicklime()], 0),
    ]


def build():
    frames = [fr for _, frs, _ in states() for fr in frs]
    cols = int(len(frames) ** 0.5 + 0.999)
    rows = (len(frames) + cols - 1) // cols
    im = Image.new('RGBA', (cols * 32, rows * 32))
    for i, fr in enumerate(frames):
        im.paste(fr.image(), ((i % cols) * 32, (i // cols) * 32))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, frs, delay in states():
        text += 'state = "%s"\n\tdirs = 1\n\tframes = %d\n' % (name, len(frs))
        if len(frs) > 1:
            text += '\tdelay = %s\n' % ','.join([str(delay)] * len(frs))
    text += '# END DMI\n'
    return im, text


def write_dmi():
    im, text = build()
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    im.save(SHEET, 'PNG', pnginfo=meta, optimize=True)


def check():
    im, text = build()
    old = Image.open(SHEET)
    return old.info.get('Description') == text and old.convert('RGBA').tobytes() == im.tobytes()


def preview(path, scale=6):
    """Every state's frames on grass, stone, snow and night grounds."""
    grounds = ((98, 122, 78, 255), (120, 118, 112, 255), (226, 232, 238, 255), (30, 38, 52, 255))
    rows = [frs[:4] for _, frs, _ in states()]
    pad = 6
    cell = 32 * scale + pad
    out = Image.new('RGBA', (pad + 4 * 4 * cell, pad + len(rows) * cell), (24, 24, 24, 255))
    for j, frs in enumerate(rows):
        for g, bg in enumerate(grounds):
            for i, fr in enumerate(frs):
                tile = Image.new('RGBA', (32 * scale, 32 * scale), bg)
                tile.alpha_composite(fr.image().resize((32 * scale, 32 * scale), Image.NEAREST))
                if g == 3:
                    dark = Image.new('RGBA', tile.size, (10, 14, 40, 90))
                    tile.alpha_composite(dark)
                out.paste(tile, (pad + (g * 4 + i) * cell, pad + j * cell))
    out.save(path)


if __name__ == '__main__':
    if '--check' in sys.argv:
        if not check():
            sys.exit('stale sheet: ' + str(SHEET))
        print('clay, lime and fire sheet matches')
    else:
        write_dmi()
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
