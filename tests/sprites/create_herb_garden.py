"""Original hand-placed 32px art for the herb garden crops and their products.

Every pixel comes from the fixed palette and the stamps and coordinates in this
file; there is no external, traced or generated artwork. Released under Civ13's
AGPL-3.0 licence. Run with Pillow from the repository root:

    python3 tests/sprites/create_herb_garden.py [--preview sheet.png]

It appends (or replaces) these states and leaves every other state untouched:

- icons/farming/plants.dmi: chamomile, dandelion, mint, sunflower and rose,
  each with -grow1..-grow6, -harvest and -dead.
- icons/farming/seeds.dmi: chamomileseeds, dandelionseeds, mintseeds,
  sunflowerseeds, roseseeds.
- icons/obj/food/food.dmi: chamomile, dandelion, dandelion_root, mint_sprig,
  sunflower, sunflower_seeds, rosehips, rose_petals, yarrow_sprig,
  comfrey_sprig, elderflower_sprig, milk_thistle_sprig.
- icons/obj/food/dryed.dmi: dried_chamomile, dried_mint,
  roasted_dandelion_root, dried_rose_petals.
- icons/obj/food/dryer.dmi: hanging states and their "R" rotations for
  chamomile, mint_sprig, dandelion_root (dry_size 5, one slot wide and two
  tall), rose_petals (dry_size 2, two slots wide) and the four dried products.
- icons/obj/herbalism.dmi (new): mortar_pestle, mortar_pestle_full.

To change the look, edit this script and rerun it; do not hand-edit the DMIs.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
S = 32

PAL = {
    # crop greens, matched to icons/farming/plants.dmi
    'd': '#006500', 'g': '#008000', 'G': '#20a120', 'L': '#40c640', 'o': '#659e3a',
    # mint
    'm': '#0c6b4a', 'M': '#1f9a68', 'N': '#55cf96', 'v': '#c3a8e6', 'V': '#8f6cc0',
    # petals and pollen
    'w': '#f6f6ee', 's': '#c9cfc0', 'y': '#f7d417', 'Y': '#e0a00c', 'O': '#b87508',
    # browns and withered greys
    'k': '#2f1e02', 'b': '#553505', 'B': '#7b5a2a', 'n': '#a8834a', 't': '#d1b57c',
    'e': '#6c6253', 'E': '#8b8376',
    # rose
    'q': '#7a0f1e', 'r': '#b0182c', 'R': '#d8324a', 'p': '#f2707f',
    'h': '#c93a14', 'H': '#f07a30', 'x': '#4a4a1c',
    # muted herb palette, taken from icons/farming/humanity_wild_herbs.dmi
    '1': '#25321e', '2': '#344723', '3': '#435c2c', '4': '#567035', '5': '#6f8244',
    '6': '#f0e5bc', '7': '#d7c99d', '8': '#c6b178', '9': '#ad965f',
    'a': '#a7639a', 'A': '#854279', 'z': '#60355c', 'u': '#3d3425', 'U': '#625138',
    # stone
    'K': '#37373b', 'c': '#56565b', 'C': '#7c7d82', 'D': '#a1a2a6', 'F': '#c8c9cc',
}


def rgba(c):
    c = PAL[c]
    return (int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16), 255)


class Canvas:
    def __init__(self):
        self.im = Image.new('RGBA', (S, S))
        self.p = self.im.load()

    def px(self, x, y, c):
        if 0 <= x < S and 0 <= y < S and c != '.':
            self.p[x, y] = rgba(c)

    def pts(self, c, *pts):
        for x, y in pts:
            self.px(x, y, c)

    def line(self, c, x0, y0, x1, y1):
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

    def stamp(self, x, y, rows, flip=False, remap=None):
        for j, row in enumerate(rows):
            if flip:
                row = row[::-1]
            for i, ch in enumerate(row):
                if ch != '.':
                    self.px(x + i, y + j, remap.get(ch, ch) if remap else ch)

    def cstamp(self, cx, cy, rows, **kw):
        self.stamp(cx - len(rows[0]) // 2, cy - len(rows) // 2, rows, **kw)


BASE = 23  # ground row used by the crops in plants.dmi
STAGES = ['grow1', 'grow2', 'grow3', 'grow4', 'grow5', 'grow6', 'harvest', 'dead']

# ---------------------------------------------------------------- chamomile
DAISY = ['.w.', 'wyw', '.s.']
DAISY_BIG = ['sws', 'wyw', 'sYs']


def chamomile(stage):
    c = Canvas()
    plans = {
        'grow1': [(16, 16, 21)],
        'grow2': [(15, 14, 20), (17, 18, 19)],
        'grow3': [(14, 12, 18), (16, 16, 16), (18, 20, 18)],
        'grow4': [(13, 10, 16), (15, 14, 13), (17, 18, 14), (19, 22, 16)],
        'grow5': [(13, 9, 15), (15, 13, 11), (16, 16, 13), (17, 19, 12), (19, 23, 15)],
        'grow6': [(13, 8, 14), (15, 12, 10), (16, 16, 8), (17, 20, 10), (19, 24, 14)],
    }
    plans['harvest'] = plans['grow6']
    plans['dead'] = [(14, 10, 17), (16, 15, 14), (18, 22, 16)]
    dead = stage == 'dead'
    tops = []
    for n, (xb, xt, yt) in enumerate(plans[stage]):
        path = c.line('B' if dead else 'g', xb, BASE, xt, yt)
        tops.append((xt, yt))
        if dead:
            continue
        # feathery leaflets alternate up the stem
        for k, (x, y) in enumerate(path[1:-2]):
            if k % 2 == 0:
                c.px(x + (1 if (k // 2 + n) % 2 else -1), y, 'G')
            elif k % 4 == 1:
                c.px(x + (-2 if (k // 2 + n) % 2 else 2), y - 1, 'L')
    if stage == 'grow1':
        c.pts('G', (15, 21), (17, 22))
    if stage in ('grow4', 'grow5'):
        for x, y in tops:
            c.px(x, y, 'o')
            if stage == 'grow5':
                c.px(x, y - 1, 'y')
    if stage == 'grow6':
        for i, (x, y) in enumerate(tops):
            if i in (1, 3):
                c.cstamp(x, y, DAISY)
            else:
                c.px(x, y, 'o')
                c.px(x, y - 1, 'y')
    if stage == 'harvest':
        for i, (x, y) in enumerate(tops):
            c.cstamp(x, y, DAISY_BIG if i in (1, 2, 3) else DAISY)
        for x, y in ((11, 17), (21, 17), (14, 15), (18, 16)):
            c.cstamp(x, y, DAISY)
    if dead:
        c.line('B', 10, 17, 8, 19)
        c.line('B', 22, 16, 24, 18)
        c.pts('e', (8, 20), (24, 19), (15, 13), (13, 20), (19, 20))
        c.pts('n', (12, 21), (18, 19), (16, 18))
    return c.im


# ---------------------------------------------------------------- dandelion
D_HEAD = ['.yy.', 'yYYy', '.OO.']
D_PUFF = ['.sws.', 'swwws', 'wwsww', 'swwws', '.sws.']
D_LEAVES = [(-6, -4), (6, -4), (-3, -7), (3, -7), (-7, -1), (7, -1)]


def dandelion(stage):
    c = Canvas()
    count = {'grow1': 2, 'grow2': 4, 'grow3': 6}.get(stage, 6)
    scale = {'grow1': 0.4, 'grow2': 0.6, 'grow3': 0.8}.get(stage, 1.0)
    dead = stage == 'dead'
    for i, (dx, dy) in enumerate(D_LEAVES[:count]):
        tx, ty = 16 + round(dx * scale), BASE + round(dy * scale)
        path = c.line('B' if dead else 'g', 16, BASE, tx, ty)
        for k, (x, y) in enumerate(path[1:]):
            # jagged teeth along the upper edge, pale midrib on long leaves
            if k % 2 == 0:
                c.px(x, y - 1, 'n' if dead else 'G')
            elif not dead and scale == 1.0 and abs(dx) > 3:
                c.px(x, y, 'L')
        c.px(tx, ty, 'e' if dead else 'd')
    stalks = {
        'grow4': [(16, 17, 'bud')],
        'grow5': [(16, 14, 'ybud'), (19, 19, 'bud')],
        'grow6': [(15, 11, 'head'), (19, 16, 'ybud')],
        'harvest': [(15, 10, 'head'), (20, 14, 'head'), (11, 14, 'puff')],
        'dead': [(15, 13, 'bare'), (19, 17, 'bare')],
    }.get(stage, [])
    for x, y, kind in stalks:
        c.line('B' if dead else 'o', 16, BASE - 1, x, y)
        if kind == 'bud':
            c.px(x, y, 'G')
            c.px(x, y - 1, 'd')
        elif kind == 'ybud':
            c.px(x, y, 'G')
            c.pts('y', (x, y - 1))
            c.pts('d', (x - 1, y), (x + 1, y))
        elif kind == 'head':
            c.stamp(x - 1, y - 2, D_HEAD)
        elif kind == 'puff':
            c.cstamp(x, y - 1, D_PUFF)
        elif kind == 'bare':
            c.px(x, y, 'e')
            c.px(x - 1, y - 1, 'E')
    return c.im


# --------------------------------------------------------------------- mint
def mint(stage):
    c = Canvas()
    plans = {
        'grow1': [(16, 2, 0)],
        'grow2': [(15, 4, 0), (18, 2, 0)],
        'grow3': [(13, 5, -1), (16, 7, 0), (19, 4, 1)],
        'grow4': [(12, 7, -1), (16, 10, 0), (20, 7, 1)],
        'grow5': [(11, 8, -2), (14, 11, -1), (17, 13, 0), (21, 9, 2)],
        'grow6': [(10, 9, -2), (13, 13, -1), (16, 15, 0), (19, 13, 1), (22, 9, 2)],
    }
    plans['harvest'] = plans['grow6']
    plans['dead'] = [(12, 8, -2), (16, 11, 1), (20, 7, 2)]
    dead = stage == 'dead'
    for xb, height, lean in plans[stage]:
        path = c.line('B' if dead else 'm', xb, BASE, xb + lean, BASE - height)
        for k, (x, y) in enumerate(path):
            if k == 0 or k % 3 != 1:
                continue
            if dead:
                c.pts('n', (x - 1, y + 1), (x + 1, y + 1))
                c.pts('e', (x - 2, y + 2), (x + 2, y + 2))
            else:
                c.pts('M', (x - 1, y), (x + 1, y), (x - 2, y - 1), (x + 2, y - 1))
                c.pts('N', (x - 2, y), (x + 2, y))
        tx, ty = path[-1]
        if dead:
            c.px(tx, ty, 'e')
        elif stage == 'harvest':
            c.pts('V', (tx, ty), (tx, ty - 2))
            c.pts('v', (tx, ty - 1), (tx, ty - 3), (tx - 1, ty - 1), (tx + 1, ty - 2))
        else:
            c.px(tx, ty, 'N')
            if height > 2:
                c.pts('M', (tx - 1, ty), (tx + 1, ty))
    return c.im


# ---------------------------------------------------------------- sunflower
SF_LEAF = ['.GGg', 'GLgd', '.gd.']
SF_BUD = ['.G.', 'GLG', 'dGd']
SF_BUD_OPEN = ['.y.y.', 'yGLGy', '.dGd.']
SF_SMALL = ['.yYy.', 'ybkby', 'Ykbky', 'ybkby', '.yYy.']
SF_HEAD = [
    '..y.y.y..',
    '.yYyyyYy.',
    'yybbkbbyy',
    '.ybkbkby.',
    'yykbnbkyy',
    '.ybkbkby.',
    'yybbkbbyy',
    '.yYyyyYy.',
    '..y.y.y..',
]
SF_DEAD_HEAD = ['.bkb.', 'bknkb', 'kbkbk', '.kbk.']


def sunflower(stage):
    c = Canvas()
    top = {'grow1': 21, 'grow2': 18, 'grow3': 14, 'grow4': 11, 'grow5': 8,
           'grow6': 7, 'harvest': 9, 'dead': 10}[stage]
    dead = stage == 'dead'
    c.line('B' if dead else 'g', 16, BASE, 16, top)
    if not dead and stage not in ('grow1', 'grow2'):
        c.line('d', 17, BASE, 17, top + 3)  # thick stalk
    if stage == 'grow1':
        c.pts('G', (15, 21), (17, 21), (14, 20), (18, 20))
        return c.im
    leaf_rows = [y for y in (20, 16, 12) if y > top + 2]
    for n, y in enumerate(leaf_rows):
        if dead:
            c.pts('n', (15, y), (14, y + 1), (13, y + 2), (17, y + 1), (18, y + 2))
            c.pts('e', (13, y + 3), (18, y + 3))
        else:
            c.stamp(12, y - 1 - (n % 2), SF_LEAF)
            c.stamp(18, y - 2 + (n % 2), SF_LEAF, flip=True)
    if stage in ('grow2', 'grow3'):
        c.pts('L', (15, top), (17, top))
        c.px(16, top - 1, 'G')
    elif stage == 'grow4':
        c.cstamp(16, top, SF_BUD)
    elif stage == 'grow5':
        c.cstamp(16, top, SF_BUD_OPEN)
    elif stage == 'grow6':
        c.cstamp(16, top - 2, SF_SMALL)
    elif stage == 'harvest':
        c.cstamp(16, top - 4, SF_HEAD)
    elif dead:
        # the stalk bends over and the spent head hangs
        c.pts('B', (15, top - 1), (14, top - 2), (13, top - 2), (12, top - 1))
        c.stamp(9, top, SF_DEAD_HEAD)
    return c.im


# --------------------------------------------------------------------- rose
ROSE_TIPS = [(0, -9), (-4, -6), (4, -7), (-7, -10), (7, -11), (-3, -14), (3, -15), (0, -5)]
ROSE_LEAF = ['.G.', 'gGg', 'dg.']
ROSE_BLOOM = ['.Rp', 'RrR', 'qR.']


def rose(stage):
    c = Canvas()
    count = {'grow1': 1, 'grow2': 2, 'grow3': 3, 'grow4': 5, 'grow5': 7}.get(stage, 8)
    scale = {'grow1': 0.3, 'grow2': 0.5, 'grow3': 0.7, 'grow4': 0.9, 'grow5': 1.0}.get(stage, 1.0)
    dead = stage == 'dead'
    fork = (16, BASE - round(4 * scale))
    c.line('B' if dead else 'x', 16, BASE, *fork)
    tips = []
    for i, (dx, dy) in enumerate(ROSE_TIPS[:count]):
        tx, ty = 16 + round(dx * scale), BASE + round(dy * scale)
        path = c.line('B' if dead else 'x', fork[0], fork[1], tx, ty)
        tips.append((tx, ty))
        if dead:
            for k, (x, y) in enumerate(path[2:]):
                if k % 3 == 0:
                    c.px(x + (1 if i % 2 else -1), y, 'b')  # thorns
    if dead:
        c.pts('e', (11, 19), (20, 18), (14, 12))
        c.pts('n', (9, 14), (23, 13))
        return c.im
    for i, (tx, ty) in enumerate(tips):
        c.cstamp(tx, ty, ROSE_LEAF, flip=bool(i % 2))
        if scale >= 0.8:  # fill the bush between the branches
            mx, my = (tx + fork[0]) // 2, (ty + fork[1]) // 2
            c.pts('g', (mx - 1, my), (mx + 1, my - 1))
            c.px(mx, my - 1, 'd')
    if stage == 'grow5':
        for tx, ty in tips[3:7]:
            c.px(tx, ty - 1, 'r')
    elif stage == 'grow6':
        for tx, ty in tips[3:5]:
            c.cstamp(tx, ty - 1, ROSE_BLOOM)
        for tx, ty in tips[5:7]:
            c.px(tx, ty - 1, 'r')
            c.px(tx, ty - 2, 'R')
    elif stage == 'harvest':
        for i, (tx, ty) in enumerate(tips[3:7]):
            c.cstamp(tx, ty - 1, ROSE_BLOOM, flip=bool(i % 2))
        c.cstamp(16, 15, ROSE_BLOOM)
    return c.im


CROPS = {'chamomile': chamomile, 'dandelion': dandelion, 'mint': mint,
         'sunflower': sunflower, 'rose': rose}

# -------------------------------------------------------------------- seeds
SEED_SPOTS = [(8, 5), (18, 3), (25, 8), (4, 13), (13, 11), (21, 14), (27, 18),
              (8, 20), (16, 19), (23, 24), (12, 26)]
SEED_STAMPS = {
    'chamomileseeds': (['tn'], ['t', 'n'], 11),
    'dandelionseeds': (['w.w', '.w.', '.s.', '.B.', '.b.'], ['w.w', '.w.', '.s.', '.B.', '.b.'], 8),
    'mintseeds': (['kb', 'b.'], ['bk', '.b'], 11),
    'sunflowerseeds': (['.k.', 'kEk', 'kwk', 'kEk', '.k.'], ['.kkk.', 'kEwEk', '.kkk.'], 9),
    'roseseeds': (['nt.', 'Hnb'], ['.tn', 'bnH'], 11),
}


def seeds(name):
    c = Canvas()
    a, b, count = SEED_STAMPS[name]
    for i, (x, y) in enumerate(SEED_SPOTS[:count]):
        c.cstamp(x, y, b if i % 3 == 1 else a)
    return c.im


# ------------------------------------------------------------------ produce
def art(rows, x, y):
    c = Canvas()
    c.stamp(x, y, rows)
    return c


PRODUCE = {}

PRODUCE['chamomile'] = art([
    '..sws.....sws.',
    '.swwws...swwws',
    '.wwyYw...wyYww',
    '.swYOs.w.sYOws',
    '..sws.sws.sws.',
    '...g.swwws.g..',
    '...gGwwyYwGg..',
    '....gswYOsg...',
    '..L.g.sws.g.L.',
    '...Lgg.g.ggL..',
    '.....g.g.g....',
    '......ggg.....',
    '......tnt.....',
    '......ggg.....',
    '.....g.g.g....',
    '.....g.d..g...',
    '....d..d...d..',
], 9, 7).im

PRODUCE['dandelion'] = art([
    '.......yyy......',
    '......yYyYy.....',
    '.....yYyyYYy....',
    '......YOYOY.....',
    '.......dod......',
    '..d.....o....d..',
    '.dGd....o...dGd.',
    '..dGd...o..dGd..',
    '.dGLd...o.dGLd..',
    '..dGGd.o..dGd...',
    '...dGLdo.dGLd...',
    '..dGGgdoddGd....',
    '...ddGgdGgd.....',
    '.....dgggd......',
    '......dtd.......',
], 8, 8).im

PRODUCE['dandelion_root'] = art([
    '...........d.G..',
    '...........dGd..',
    '..........bGdb..',
    '.........bntnb..',
    '........bnttb...',
    '.......bnttnb...',
    '......bnttnb.b..',
    '..b..bnttnbbb...',
    '...bbnttnb......',
    '...bnttnb.......',
    '..bnttnbb.......',
    '..bntnb..b......',
    '.bntnb..........',
    '.bnnb...........',
    'bnnb............',
    'bbb.............',
    'b...............',
], 8, 8).im


def mint_sprig():
    c = Canvas()
    path = c.line('m', 9, 27, 21, 7)
    leaf = ['.mMm.', 'mMNNm', 'mMNMm', '.mmm.']
    for k, (x, y) in enumerate(path):
        if k in (4, 10, 16):
            c.stamp(x - 6, y - 3, leaf)
            c.stamp(x + 1, y, leaf, flip=True)
    c.line('m', 9, 27, 21, 7)
    c.stamp(19, 4, ['.MN.', 'MNNM', '.MM.'])
    c.px(8, 28, 'B')
    return c.im


PRODUCE['mint_sprig'] = mint_sprig()

PRODUCE['sunflower'] = art([
    '.....y.y.y.....',
    '...yYyYyYyYy...',
    '..yyYyyyyyYyy..',
    '.yYyybbbbbyyYy.',
    '..yybbkbkbbyy..',
    'yYybkbnbnbkbyYy',
    '.yybbnkbknbbyy.',
    'yYybkbkbkbkbyYy',
    '.yybbnkbknbbyy.',
    'yYybkbnbnbkbyYy',
    '..yybbkbkbbyy..',
    '.yYyybbbbbyyYy.',
    '..yyYyyyyyYyy..',
    '...yYyYyYyYy...',
    '.....y.ygy.....',
    '.......gd......',
    '.......gd......',
    '......gd.......',
], 8, 6).im


def sunflower_seeds():
    c = Canvas()
    up, flat = SEED_STAMPS['sunflowerseeds'][0], SEED_STAMPS['sunflowerseeds'][1]
    for x, y, s in ((10, 22, flat), (16, 23, flat), (22, 22, flat), (13, 20, up),
                    (19, 20, up), (16, 18, flat), (11, 18, up), (21, 17, up),
                    (16, 15, up), (13, 15, flat), (19, 14, flat), (16, 12, flat)):
        c.cstamp(x, y, s)
    return c.im


PRODUCE['sunflower_seeds'] = sunflower_seeds()

PRODUCE['rosehips'] = art([
    '.......x.....dG.',
    '......x.....dGd.',
    '..k...x....xd...',
    '.hHh.x....x.....',
    'hHHhhx...x......',
    'hhhhq.x.x..k....',
    '.hhq..xx..hHh...',
    '.......x.hHHhh..',
    '..dG...x.hhhhq..',
    '.dGdx..x..hhq...',
    '..d..x.x........',
    '...k..xx........',
    '..hHh..x........',
    '.hHHhh.x........',
    '.hhhhq.x........',
    '..hhq..x........',
    '.......x........',
], 8, 7).im


def rose_petals():
    c = Canvas()
    a = ['.Rp.', 'RRRp', 'rRR.', '.rq.']
    b = ['.RR.', 'pRRr', '.Rrq']
    for i, (x, y) in enumerate(((9, 12), (17, 10), (23, 14), (12, 18), (19, 19), (15, 14), (8, 22), (22, 23), (15, 24))):
        c.stamp(x, y, a if i % 2 == 0 else b, flip=(i % 3 == 0))
    return c.im


PRODUCE['rose_petals'] = rose_petals()

PRODUCE['yarrow_sprig'] = art([
    '...6767.67...',
    '..676787676..',
    '.78767678767.',
    '..987989789..',
    '...3.3.3.3...',
    '....33333....',
    '......2......',
    '..3...2......',
    '.343..2..3...',
    '..3432..343..',
    '....3323432..',
    '......233....',
    '......2......',
    '...3..2......',
    '..343.2.3....',
    '...34323433..',
    '.....3233....',
    '......2......',
    '......2......',
    '......1......',
    '......1......',
], 10, 6).im

PRODUCE['comfrey_sprig'] = art([
    '.......33......',
    '......3..3zAz..',
    '.......3.aAaAz.',
    '.......3.aA.aA.',
    '.......3..a..a.',
    '.......3.......',
    '.......3.......',
    '..33...3...33..',
    '.3453..3..3543.',
    '.34543.3.34543.',
    '..345433345543.',
    '...3454345543..',
    '....34434543...',
    '.....3323433...',
    '......3233.....',
    '.......2.......',
    '.......2.......',
    '.......2.......',
    '.......1.......',
    '.......1.......',
], 9, 7).im

PRODUCE['elderflower_sprig'] = art([
    '....67676767...',
    '..676767676767.',
    '.7676787678767.',
    '..78789878987..',
    '...9.8.9.8.9...',
    '....3.3.3.3....',
    '.....3.3.3.....',
    '......333......',
    '.......U.......',
    '..33...U...33..',
    '.3453..U..3543.',
    '..34533U33543..',
    '...3333U3333...',
    '.......U.......',
    '.......U.......',
    '.......u.......',
    '.......u.......',
    '.......u.......',
], 9, 8).im

PRODUCE['milk_thistle_sprig'] = art([
    '.....a.a.a.....',
    '....aAaAaAa....',
    '....AaAaAaA....',
    '.....zAzAz.....',
    '....5343435....',
    '.....34543.....',
    '......333......',
    '.......3.......',
    '.1.....3.....1.',
    '..31...3...13..',
    '.1343..3..3431.',
    '..13431313431..',
    '.1.134333431.1.',
    '.....13331.....',
    '.......2.......',
    '.......2.......',
    '.......2.......',
    '.......1.......',
    '.......1.......',
], 9, 7).im

# -------------------------------------------------------------- dried items
DRIED = {}
DRIED['dried_chamomile'] = art([
    '......tYt.......',
    '....tYnOtYt.....',
    '...YtOtYtnOtY...',
    '..tnYtnOYtYntO..',
    '.tYOtYtYnOtYOtn.',
    'nOtnOtnYtnOtnYtn',
    '.nnOnBOnnOnBOnn.',
    '..BnBnnBnnBnnB..',
], 8, 14).im
DRIED['dried_mint'] = art([
    '......353.......',
    '....3425343.....',
    '...243532435....',
    '..35243425342...',
    '.3425342532435..',
    '243253424352432.',
    '.2132421324231..',
    '..121.2121.121..',
], 8, 14).im
DRIED['roasted_dandelion_root'] = art([
    '........kbbk....',
    '..kbbk.kBnBbk...',
    '.kBnBbkkbBbbk...',
    '.kbBbbk.kkkk....',
    '..kkkkkbbk......',
    '.....kBnBbk.kbk.',
    '.....kbBBbkkBnbk',
    '......kkkk.kbBbk',
    '............kkk.',
], 8, 13).im
DRIED['dried_rose_petals'] = art([
    '......rRr.......',
    '....rqrRqrR.....',
    '...RrqRrrqrRr...',
    '..rqrRrqRrqrqR..',
    '.rRrqrRrqrRrqrr.',
    'qrqRrqrqRrqrRqrq',
    '.qqrqqrqqrqqrqq.',
    '..kqkqqkqqkqqk..',
], 8, 14).im

# ------------------------------------------------------- dehydrator overlays
# Overlays sit at the top-left of the frame; one slot is 5 px wide, 6 px tall.
HANG = {
    'chamomile': ['..n..', '.ggg.', '.ggg.', 'g.g.g', 'g.g.g', 'wgwgw', 'ywYwy', 'wswsw', '.s.s.'],
    'mint_sprig': ['..n..', '..m..', '.MmM.', 'NMmMN', '.MmM.', 'NMmMN', '.MmM.', '.NMN.', '..N..'],
    'dandelion_root': ['..n..', '.bnb.', '.ntn.', '.ntn.', '.ntn.', '.bnb.', '..n..', '..n..', '..b..'],
    'rose_petals': ['.Rp.rR.Rp', 'RRRRrRpRR', 'rRqrRRrRr', '.r..rq.r.'],
}
DRY_REMAP = {
    'dried_chamomile': ('chamomile', {'g': '4', 'w': 't', 's': 'n', 'y': 'Y', 'Y': 'O'}),
    'dried_mint': ('mint_sprig', {'m': '1', 'M': '3', 'N': '4'}),
    'roasted_dandelion_root': ('dandelion_root', {'n': 'b', 't': 'B', 'b': 'k'}),
    'dried_rose_petals': ('rose_petals', {'R': 'r', 'p': 'r', 'r': 'q', 'q': 'k'}),
}


def hang(rows, remap=None, rotated=False):
    c = Canvas()
    if rotated:  # quarter turn; the hanging end moves to the left
        rows = [''.join(rows[j][i] for j in range(len(rows))) for i in range(len(rows[0]))]
    c.stamp(0, 0, rows, remap=remap)
    return c.im


def dryer_states():
    out = []
    for name, rows in HANG.items():
        out += [(name, hang(rows)), (name + 'R', hang(rows, rotated=True))]
    for name, (src, remap) in DRY_REMAP.items():
        rows = HANG[src]
        if name in ('dried_chamomile', 'dried_mint'):
            rows = rows[:1] + rows[2:]  # dried bunches shrink a little
        out += [(name, hang(rows, remap)), (name + 'R', hang(rows, remap, rotated=True))]
    return out


# ------------------------------------------------------------------- mortar
MORTAR = [
    '..............FD..',
    '.............FDC..',
    '............FDCK..',
    '...........FDCK...',
    '..........FDCK....',
    '.KKKKKKKKKDCKKKKK.',
    'KFFFDDDDDDDDDDDCCK',
    'KDKccccccccccccKCK',
    '.KDKKKKKKKKKKKKCK.',
    '.KFDDDCCCCCCCCCcK.',
    '.KFDDCCCCCCCCCccK.',
    '..KDDCCCCCCCCCcK..',
    '..KDDDCCCCCCCccK..',
    '...KDDCCCCCCccK...',
    '....KKDCCCccKK....',
    '....KDDDCCCCcK....',
    '...KFDDDCCCCccK...',
    '...KKKKKKKKKKKK...',
]
MORTAR_FULL = list(MORTAR)
MORTAR_FULL[4] = '....oG..LoFDCK.G..'
MORTAR_FULL[5] = '.KKoGLoGoGDCKoGKK.'
MORTAR_FULL[7] = 'KDKgoGgGogGdgoGKCK'


def mortar(rows):
    return art(rows, 7, 8).im


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


def write_dmi(path, new_states, cols=8):
    """Append new_states to path, replacing same-named states from earlier runs."""
    header = ['# BEGIN DMI', 'version = 4.0', '\twidth = 32', '\theight = 32']
    states = []
    if path.exists():
        header, states, cols = read_dmi(path)
    names = {name for name, _ in new_states}
    states = [s for s in states if s[0] not in names]
    for name, frame in new_states:
        states.append((name, ['state = "%s"' % name, '\tdirs = 1', '\tframes = 1'], [frame]))
    frames = [f for _, _, fs in states for f in fs]
    sheet = Image.new('RGBA', (cols * S, -(-len(frames) // cols) * S))
    for i, f in enumerate(frames):
        sheet.paste(f, ((i % cols) * S, (i // cols) * S))
    text = '\n'.join(header + [line for _, block, _ in states for line in block] + ['# END DMI', ''])
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta, optimize=True)


def build():
    return {
        'icons/farming/plants.dmi': [('%s-%s' % (crop, st), fn(st)) for crop, fn in CROPS.items() for st in STAGES],
        'icons/farming/seeds.dmi': [(name, seeds(name)) for name in SEED_STAMPS],
        'icons/obj/food/food.dmi': list(PRODUCE.items()),
        'icons/obj/food/dryed.dmi': list(DRIED.items()),
        'icons/obj/food/dryer.dmi': dryer_states(),
        'icons/obj/herbalism.dmi': [('mortar_pestle', mortar(MORTAR)), ('mortar_pestle_full', mortar(MORTAR_FULL))],
    }


def preview(sheets, out):
    """Review sheet of the actual sprite pixels at 4x; not a gameplay screenshot."""
    z, cell_w, cell_h, per_row = 4, S * 4 + 12, S * 4 + 18, 8
    groups = [
        ('Crops in icons/farming/plants.dmi: grow1 to grow6, harvest, dead', sheets['icons/farming/plants.dmi']),
        ('Seeds in icons/farming/seeds.dmi', sheets['icons/farming/seeds.dmi']),
        ('Produce and picked sprigs in icons/obj/food/food.dmi', sheets['icons/obj/food/food.dmi']),
        ('Dried products in icons/obj/food/dryed.dmi', sheets['icons/obj/food/dryed.dmi']),
        ('Mortar and pestle in icons/obj/herbalism.dmi', sheets['icons/obj/herbalism.dmi']),
        ('Dehydrator overlays in icons/obj/food/dryer.dmi (straight, then R)', sheets['icons/obj/food/dryer.dmi']),
    ]
    height = sum(24 + -(-len(g) // per_row) * cell_h for _, g in groups) + cell_h + 40
    img = Image.new('RGBA', (cell_w * per_row + 12, height), (74, 104, 58, 255))
    d = ImageDraw.Draw(img)
    y = 6
    for title, group in groups:
        d.text((8, y), title, fill='white')
        y += 20
        for i, (name, frame) in enumerate(group):
            x = 8 + (i % per_row) * cell_w
            yy = y + (i // per_row) * cell_h
            d.rectangle((x, yy + 12, x + S * z - 1, yy + 12 + S * z - 1), fill=(96, 128, 72, 255))
            img.alpha_composite(frame.resize((S * z, S * z), Image.NEAREST), (x, yy + 12))
            d.text((x, yy), name[:22], fill=(235, 235, 220))
        y += -(-len(group) // per_row) * cell_h + 4
    # the rack with every overlay hung where the game places it
    d.text((8, y), 'Dehydrator with the fresh items hung (left) and the dried ones (right)', fill='white')
    y += 18
    rack_path = ROOT / 'icons/obj/food/dryer.dmi'
    rack = next(fs[0] for name, _, fs in read_dmi(rack_path)[1] if name == 'empty')
    over = dict(sheets['icons/obj/food/dryer.dmi'])
    for n, hung in enumerate((['chamomile', 'mint_sprig', 'dandelion_root', 'rose_petals'],
                              ['dried_chamomile', 'dried_mint', 'roasted_dandelion_root', 'dried_rose_petals'])):
        tile = rack.copy()
        for name, (col, row) in zip(hung, ((1, 1), (2, 1), (3, 1), (1, 3))):
            tile.alpha_composite(over[name], (4 + 5 * col, 6 * row - 1))
        img.alpha_composite(tile.resize((S * z, S * z), Image.NEAREST), (8 + n * cell_w, y))
    img.save(out)


if __name__ == '__main__':
    sheets = build()
    for rel, new_states in sheets.items():
        write_dmi(ROOT / rel, new_states)
    if '--preview' in sys.argv:
        preview(sheets, sys.argv[sys.argv.index('--preview') + 1])
