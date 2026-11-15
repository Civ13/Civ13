"""Hand-placed 32px rain gear: straw rain cape, oilskin coat, sou'wester, three
umbrellas (oiled paper, black cloth, folding nylon) and a branch-and-leaf
lean-to. Every pixel is placed by this script from a fixed palette (Pillow
only); no external or generated artwork.

Run with Pillow to reproduce
  icons/obj/clothing/rain_gear.dmi          item icons
  icons/mob/rain_gear.dmi                   worn, four directions
  icons/mob/items/lefthand_rain_gear.dmi    held, four directions, 32x48
  icons/mob/items/righthand_rain_gear.dmi
  icons/obj/rain_shelter.dmi                lean-to, four directions
The held sheets are 48px tall so an open umbrella's canopy sits above the head
without extra code. The cape and coat are drawn one pixel wider than the widest
coat sleeves so they cover whatever is worn underneath. `--preview <png>` also
writes a review sheet. Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_diving_gear import Frame, base_body  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]

# dried straw
S = [(236, 212, 134), (208, 178, 98), (170, 140, 68), (124, 98, 46), (66, 50, 22)]
# crude twine
TW = [(150, 112, 66), (108, 76, 42), (64, 44, 24)]
# oiled canvas
Y = [(244, 208, 84), (218, 172, 48), (176, 132, 32), (126, 92, 24), (58, 40, 12)]
# horn buttons, coat lining
BT = [(92, 62, 34), (50, 32, 18)]
# black umbrella cloth
K = [(98, 100, 112), (66, 68, 80), (44, 46, 56), (29, 30, 38), (12, 12, 16)]
# oiled paper and its lacquer band
P = [(244, 220, 158), (224, 186, 110), (192, 146, 74), (148, 104, 48), (80, 52, 24)]
RD = [(206, 76, 54), (162, 48, 36), (108, 30, 24)]
# bamboo
BM = [(220, 202, 126), (174, 154, 84), (122, 104, 52), (68, 56, 28)]
# nylon
N = [(108, 180, 228), (58, 134, 196), (36, 98, 156), (24, 66, 112), (10, 28, 54)]
# wood and bark
W = [(176, 126, 74), (134, 90, 48), (94, 60, 32), (58, 36, 18), (28, 18, 10)]
# steel
L = [(206, 212, 220), (150, 158, 168), (98, 106, 118), (48, 54, 64)]
# black plastic
PL = [(84, 86, 92), (48, 50, 56), (22, 23, 28)]
# leaves
G = [(150, 190, 76), (108, 154, 56), (72, 118, 42), (46, 84, 34), (22, 46, 20)]
SHADE = (24, 26, 18)
BED = [(150, 132, 70), (116, 100, 52), (82, 70, 36)]


class Tall(Frame):
    """A frame that may reach 16px above the tile (rows -16..31)."""

    def put(self, x, y, c):
        if 0 <= x < 32 and -16 <= y < 32:
            self.px[(x, y)] = c

    def flip(self):
        """Mirror about the body's centre column (x = 15)."""
        f = Tall()
        f.px = {(30 - x, y): c for (x, y), c in self.px.items() if 0 <= 30 - x < 32}
        return f

    def moved(self, dx, dy):
        f = Tall()
        for (x, y), c in self.px.items():
            f.put(x + dx, y + dy, c)
        return f

    def over(self, other):
        f = Tall()
        f.px = dict(self.px)
        f.px.update(other.px)
        return f

    def only(self, keep):
        f = Tall()
        f.px = {p: c for p, c in self.px.items() if p in keep}
        return f

    def image(self, height=32):
        im = Image.new('RGBA', (32, height))
        top = height - 32
        for (x, y), c in self.px.items():
            if y + top >= 0:
                im.putpixel((x, y + top), c + (255,))
        return im


def span_mask(rows):
    mask = set()
    for y, spans in rows.items():
        if isinstance(spans, tuple):
            spans = [spans]
        for x0, x1 in spans:
            for x in range(x0, x1 + 1):
                mask.add((x, y))
    return mask


def edge(mask, p):
    x, y = p
    return any(n not in mask for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))


# ---------------------------------------------------------------- straw rain cape

STRAND = (1, 1, 2, 0, 1, 2, 1, 0, 1, 3, 1, 0, 2)
TIERS = ((11, 15), (16, 20), (21, 25))


def thatch(f, rows, slit=None):
    """Three overlapping tiers of straw: each strand is one column, a tier's
    tips hang ragged over the shadowed top of the tier below."""
    mask = span_mask(rows)
    for (x, y) in sorted(mask):
        tier = next(i for i, (y0, y1) in enumerate(TIERS) if y0 <= y <= y1)
        y0, y1 = TIERS[tier]
        k = STRAND[(x * 5 + tier * 7) % len(STRAND)]
        if y == y0 and tier:
            k = 3 if (x + tier) % 3 else 2            # shadow under the tier above
        elif y == y1:
            k = min(k + 1, 3) if (x + tier) % 2 else k  # ragged tips
        elif y == y0 + 1 and tier and (x + tier) % 2:
            k = min(k + 1, 2)
        if edge(mask, (x, y)) and not (y == y1 and (x, y + 1) in mask):
            k = 4 if ((x - 1, y) not in mask or (x + 1, y) not in mask or (x, y - 1) not in mask) else 3
        f.put(x, y, S[k])
    # ragged hem: every other strand hangs a pixel lower
    for x in sorted({x for x, y in mask if y == 25}):
        if (x * 3) % 5 in (0, 2, 3):
            f.put(x, 26, S[3] if x % 2 else S[2])
    if slit:
        for y, (x0, x1) in slit.items():
            for x in range(x0, x1 + 1):
                f.px.pop((x, y), None)
            if (x0 - 1, y) in f.px:
                f.put(x0 - 1, y, S[4])
            if (x1 + 1, y) in f.px:
                f.put(x1 + 1, y, S[3])
    return f


def cape_front(back=False):
    rows = {11: (11, 19), 12: (9, 21), 13: (8, 22), 14: (7, 23), 15: (7, 23), 16: (6, 24), 17: (6, 24), 18: (6, 24),
            19: (6, 24), 20: (6, 24), 21: (5, 25), 22: (5, 25), 23: (5, 25), 24: (5, 25), 25: (5, 25)}
    f = Tall()
    if back:
        thatch(f, rows)
        # plaited collar band
        f.h(11, 12, 18, TW[1]); f.pts(TW[0], (12, 11), (14, 11), (16, 11)); f.pts(S[4], (11, 11), (19, 11))
        return f
    thatch(f, rows, {13: (15, 15), 14: (15, 15), 15: (15, 15), 16: (15, 15), 17: (15, 15), 18: (15, 15), 19: (14, 16),
                     20: (14, 16), 21: (14, 16), 22: (14, 16), 23: (13, 17), 24: (13, 17), 25: (13, 17), 26: (13, 17)})
    # neck open, twine tie knotted at the throat
    for x in range(13, 18):
        f.px.pop((x, 11), None)
    f.pts(S[4], (12, 11), (18, 11))
    f.pts(TW[0], (14, 12), (16, 12)); f.pts(TW[1], (15, 12), (15, 13)); f.pts(TW[2], (14, 13), (16, 14))
    return f


def cape_side():
    rows = {11: (12, 18), 12: (11, 19), 13: (11, 19), 14: (10, 20), 15: (10, 20), 16: (10, 20), 17: (10, 20), 18: (10, 20),
            19: (10, 20), 20: (10, 20), 21: (9, 21), 22: (9, 21), 23: (9, 21), 24: (9, 21), 25: (9, 21)}
    f = Tall()
    thatch(f, rows)
    f.h(11, 13, 17, TW[1]); f.pts(TW[0], (13, 11), (15, 11)); f.pts(TW[2], (18, 11), (19, 12))
    # front edge falls open a little
    f.v(20, 16, 20, S[4]); f.v(21, 21, 25, S[4])
    return f


# ---------------------------------------------------------------- oilskin coat

def coat_front(back=False):
    f = Tall()
    # skirt, flaring to the shin
    f.part({y: (9, 21) for y in range(20, 24)} | {24: (8, 22), 25: (8, 22), 26: (8, 22), 27: (8, 22), 28: (9, 21)}, Y)
    # body
    f.part({11: (11, 19), 12: (9, 21), 13: (9, 21), 14: (9, 21), 15: (9, 21), 16: (9, 21), 17: (9, 21), 18: (9, 21),
            19: (9, 21), 20: (9, 21), 21: (9, 21)}, Y)
    for y in range(20, 23):
        f.put(9, y, Y[4]); f.put(21, y, Y[4])
    f.h(20, 10, 20, Y[1]); f.h(21, 10, 12, Y[0]); f.h(21, 13, 17, Y[1]); f.h(21, 18, 20, Y[2])
    # sleeves, wide and stiff, down to the wrist
    for flip in (False, True):
        g = Tall()
        g.part({12: (7, 9), 13: (6, 9), 14: (5, 9), 15: (5, 9), 16: (5, 9), 17: (5, 9), 18: (5, 9), 19: (5, 9),
                20: (5, 9)}, Y, 'lr' if not flip else 'rl')
        g.h(19, 6, 8, Y[3])                                   # storm cuff
        g.pts(Y[0] if not flip else Y[1], (6, 15), (6, 16), (6, 17))
        f.px.update((g.flip() if flip else g).px)
    # wet sheen down the lit side, deep folds on the other
    f.v(10, 13, 19, Y[0]); f.v(11, 22, 26, Y[0]); f.v(19, 22, 27, Y[3]); f.v(20, 14, 19, Y[3])
    f.h(27, 9, 21, Y[3]); f.pts(Y[2], (10, 27), (11, 27), (12, 27))
    if back:
        # yoke seam, centre seam and a vent in the skirt
        f.h(14, 10, 20, Y[3]); f.h(13, 10, 20, Y[1]); f.pts(Y[0], (10, 13), (11, 13), (12, 13))
        f.v(15, 15, 22, Y[2]); f.v(15, 23, 28, Y[4]); f.v(16, 23, 27, Y[3])
        f.h(11, 12, 18, Y[2]); f.pts(Y[1], (12, 11), (13, 11)); f.h(12, 11, 19, Y[1]); f.pts(Y[4], (11, 11), (19, 11))
        return f
    # storm flap fastened right over left, horn buttons
    f.v(16, 14, 27, Y[3]); f.v(15, 14, 27, Y[1]); f.v(14, 14, 26, Y[0])
    f.pts(BT[0], (17, 15), (17, 18), (17, 21), (17, 24)); f.pts(BT[1], (17, 16), (17, 19), (17, 22), (17, 25))
    # turned-up collar, open at the throat
    for x in range(14, 17):
        f.px.pop((x, 11), None)
    f.pts(Y[4], (13, 11), (17, 11), (14, 12), (16, 12), (15, 13))
    f.px.pop((15, 12), None)
    f.pts(Y[0], (11, 12), (12, 12), (12, 11)); f.pts(Y[1], (13, 12), (18, 11), (17, 12)); f.pts(Y[2], (18, 12), (19, 12))
    f.pts(Y[3], (12, 13), (13, 13), (17, 13), (18, 13))
    # pocket flaps
    f.h(22, 10, 12, Y[3]); f.h(22, 18, 20, Y[4])
    return f


def coat_side():
    f = Tall()
    f.part({11: (12, 18), 12: (11, 19), 13: (11, 19), 14: (11, 19), 15: (11, 19), 16: (11, 19), 17: (11, 19),
            18: (11, 19), 19: (11, 19), 20: (11, 19), 21: (11, 19), 22: (11, 19), 23: (11, 19), 24: (10, 20),
            25: (10, 20), 26: (10, 20), 27: (10, 20), 28: (11, 19)}, Y)
    f.h(27, 11, 19, Y[3]); f.pts(Y[2], (11, 27), (12, 27))
    f.v(19, 13, 27, Y[3]); f.v(18, 14, 26, Y[1])              # front flap edge
    f.pts(BT[0], (18, 15), (18, 18), (18, 21), (18, 24))
    # collar standing round the neck
    f.h(11, 13, 17, Y[1]); f.pts(Y[0], (13, 11), (14, 11)); f.pts(Y[4], (12, 11), (18, 11)); f.h(12, 12, 18, Y[2])
    f.pts(Y[0], (12, 12))
    # sleeve
    f.part({13: (13, 17), 14: (12, 17), 15: (12, 17), 16: (12, 17), 17: (12, 17), 18: (12, 17), 19: (12, 17),
            20: (13, 17)}, Y)
    f.h(19, 13, 16, Y[3]); f.pts(Y[0], (13, 14), (13, 15), (13, 16))
    f.h(22, 13, 16, Y[3])                                     # pocket flap
    return f


# ---------------------------------------------------------------- sou'wester

def hat_front(back=False):
    f = Tall()
    crown = {1: (13, 17), 2: (12, 18), 3: (11, 19), 4: (11, 19), 5: (11, 19)}
    if back:
        # the long back brim sheds rain past the collar
        f.part({6: (10, 20), 7: (9, 21), 8: (9, 21), 9: (8, 22), 10: (8, 22), 11: (8, 22), 12: (10, 20)}, Y)
        f.h(6, 11, 19, Y[3])
        for x, k in ((12, 1), (15, 2), (18, 3)):              # panel seams fan out
            f.v(x, 7, 10, Y[k + 1] if k < 3 else Y[4])
        f.pts(Y[3], (11, 10), (19, 10)); f.pts(Y[0], (10, 8), (9, 9), (9, 10), (10, 9))
    f.ball(crown, Y, 13.0, 2.4, (1.6, 3.4, 5.2))
    f.v(15, 1, 4, Y[2])                                       # crown seam
    if back:
        f.h(5, 11, 19, Y[4])
        return f
    # short front brim, back brim showing either side of the neck
    f.part({5: (9, 21), 6: (9, 21)}, Y, 'flat')
    f.h(5, 10, 20, Y[1]); f.pts(Y[0], (10, 5), (11, 5), (12, 5), (13, 5)); f.pts(Y[2], (18, 5), (19, 5), (20, 5))
    f.h(6, 9, 21, Y[4]); f.h(6, 12, 18, Y[3])
    for x, k in ((10, 2), (20, 3)):
        f.v(x, 7, 10, Y[k]); f.put(x, 11, Y[4])
    f.pts(Y[4], (9, 7), (9, 8), (9, 9), (21, 7), (21, 8), (21, 9), (9, 10), (21, 10))
    return f


def hat_side():
    f = Tall()
    # brim: short peak ahead, long sloping tail behind
    f.part({5: (10, 22), 6: (9, 22), 7: (9, 12), 8: (8, 12), 9: (8, 12), 10: (7, 11), 11: (7, 11), 12: (7, 10)}, Y)
    f.h(6, 13, 22, Y[4]); f.h(5, 19, 21, Y[1]); f.put(22, 5, Y[4])
    f.pts(Y[0], (10, 7), (9, 8), (9, 9)); f.pts(Y[3], (11, 8), (11, 9), (10, 10), (10, 11))
    f.ball({1: (13, 18), 2: (12, 19), 3: (11, 19), 4: (11, 19), 5: (11, 19)}, Y, 13.5, 2.4, (1.6, 3.4, 5.2))
    f.h(5, 11, 18, Y[3]); f.v(15, 1, 4, Y[2])
    return f


# ---------------------------------------------------------------- umbrellas

class Canopy:
    def __init__(self, half, height, panels, ramp, scallop=True, curve=2.0):
        self.half, self.height, self.panels, self.ramp, self.scallop, self.curve = half, height, panels, ramp, scallop, curve

    def width(self, row):
        """Half-width of row `row` (0 = top)."""
        t = (row + 1) / self.height
        return self.half * (1 - (1 - t) ** self.curve) ** (1 / self.curve)

    def draw(self, f, cx, top, trim=None):
        ramp, n = self.ramp, self.panels
        cells = {}
        for row in range(self.height):
            hw = self.width(row)
            for x in range(int(math.floor(cx - hw)), int(math.ceil(cx + hw)) + 1):
                u = (x - cx) / (hw + 0.5)
                if abs(u) > 1:
                    continue
                a = math.asin(u) / math.pi + 0.5              # 0..1 round the visible half
                panel = min(int(a * n), n - 1)
                frac = a * n - panel
                if self.scallop and row == self.height - 1 and 0.3 < frac < 0.7 and n < 8:
                    continue                                  # rim curves up between the ribs
                cells[(x, top + row)] = (panel, frac)
        for (x, y), (panel, frac) in cells.items():
            left = cells.get((x - 1, y))
            k = (0, 1, 1, 2, 2, 3, 3)[min(int(panel * 6 / max(n - 1, 1) + 0.5), 6)]
            if left and left[0] != panel:
                k = min(k + 1, 3)                             # rib
            if edge(cells, (x, y)):
                k = 4
            f.put(x, y, ramp[k])
        if trim:
            trim(f, cx, top, cells)
        return cells


def shaft(f, x, y0, y1, ramp, lean=0):
    """A 1px shaft with its shaded side; `lean` shifts the upper half."""
    mid = (y0 + y1) // 2
    for y in range(y0, y1 + 1):
        xx = x + (lean if y < mid else 0)
        f.put(xx, y, ramp[1]); f.put(xx + 1, y, ramp[3])


def paper_trim(f, cx, top, cells):
    # lacquer band above the rim, dark cap on the hub
    for (x, y) in cells:
        if y == top + 4 and f.px[(x, y)] != P[4]:
            f.put(x, y, RD[0] if x < cx - 3 else RD[1] if x < cx + 5 else RD[2])
    f.pts(BT[1], (cx, top - 1), (cx, top)); f.pts(BT[0], (cx - 1, top), (cx + 1, top))


def cloth_trim(f, cx, top, cells):
    f.pts(L[0], (cx, top - 2)); f.pts(L[1], (cx, top - 1)); f.pts(L[3], (cx + 1, top - 1))
    f.pts(K[0], (cx - 4, top + 2), (cx - 5, top + 3), (cx - 3, top + 1))


def nylon_trim(f, cx, top, cells):
    f.pts(PL[1], (cx, top - 1)); f.pts(PL[2], (cx + 1, top - 1))
    f.pts(N[0], (cx - 4, top + 2), (cx - 3, top + 1), (cx - 5, top + 3))
    f.pts((236, 244, 250), (cx - 4, top + 1))


KINDS = {
    'umbrella_paper': dict(canopy=Canopy(12, 6, 11, P, scallop=False, curve=1.25), trim=paper_trim, top=-7, shaft=BM),
    'umbrella_cloth': dict(canopy=Canopy(11, 8, 5, K, curve=2.0), trim=cloth_trim, top=-8, shaft=W),
    'umbrella_nylon': dict(canopy=Canopy(10, 6, 4, N, curve=1.8), trim=nylon_trim, top=-6, shaft=L),
}


def grip(f, kind, x, y):
    """The handle below the hand at (x, y)."""
    if kind == 'umbrella_paper':
        f.pts(BM[0], (x, y)); f.pts(BM[2], (x, y + 1)); f.pts(BM[3], (x + 1, y), (x + 1, y + 1)); f.pts(TW[1], (x, y - 1))
    elif kind == 'umbrella_cloth':
        f.pts(W[1], (x, y), (x, y + 1)); f.pts(W[3], (x + 1, y), (x + 1, y + 1))
        f.pts(W[2], (x, y + 2), (x - 1, y + 2)); f.pts(W[3], (x - 2, y + 2), (x - 2, y + 1)); f.pts(L[1], (x, y - 1))
    else:
        f.pts(PL[0], (x, y)); f.pts(PL[1], (x, y + 1), (x, y + 2)); f.pts(PL[2], (x + 1, y), (x + 1, y + 1), (x + 1, y + 2))
        f.pts(PL[1], (x - 1, y + 3)); f.pts(PL[2], (x - 1, y + 2))


def held_open(kind, hand_x, centre):
    """Open umbrella held at hand_x, canopy centred over `centre`."""
    spec = KINDS[kind]
    f = Tall()
    rim = spec['top'] + spec['canopy'].height
    shaft(f, hand_x, rim - 1, 19, spec['shaft'] if kind != 'umbrella_nylon' else [L[0], L[1], L[2], L[3]])
    grip(f, kind, hand_x, 20)
    spec['canopy'].draw(f, centre, spec['top'], spec['trim'])
    return f


def held_closed(kind, x):
    """Furled umbrella carried point down beside the leg."""
    f = Tall()
    if kind == 'umbrella_nylon':
        # folded short in its sleeve, hanging from a wrist strap
        f.part({19: (x, x + 2), 20: (x - 1, x + 2), 21: (x - 1, x + 2), 22: (x - 1, x + 2), 23: (x - 1, x + 2),
                24: (x - 1, x + 2), 25: (x, x + 2)}, N, 'flat')
        f.v(x, 20, 24, N[0]); f.v(x + 1, 20, 24, N[1]); f.pts(N[3], (x, 22), (x + 1, 22))
        f.pts(PL[0], (x, 18)); f.pts(PL[2], (x + 1, 18), (x + 1, 17)); f.pts(PL[1], (x, 17))
        return f
    ramp = P if kind == 'umbrella_paper' else K
    f.part({y: (x - 1, x + 1) for y in range(19, 28)} | {28: (x, x + 1), 29: (x, x)}, ramp, 'flat')
    f.v(x, 20, 27, ramp[0] if kind == 'umbrella_paper' else ramp[1]); f.v(x + 1, 20, 27, ramp[3])
    if kind == 'umbrella_paper':
        f.h(22, x - 1, x + 1, RD[1]); f.put(x, 22, RD[0]); f.h(25, x, x + 1, TW[1])
        f.pts(BM[1], (x, 18), (x, 17), (x, 16)); f.pts(BM[3], (x + 1, 18), (x + 1, 17), (x + 1, 16))
        f.pts(BM[2], (x, 29), (x, 30))
    else:
        f.h(23, x, x + 1, K[0])                               # closing strap
        f.pts(W[1], (x, 18), (x, 17)); f.pts(W[3], (x + 1, 18), (x + 1, 17))
        f.pts(W[1], (x, 16), (x - 1, 15), (x - 2, 16)); f.pts(W[3], (x + 1, 16), (x, 15), (x - 2, 17))
        f.pts(L[1], (x, 29), (x, 30)); f.pts(L[3], (x + 1, 29))
    return f


def outline(f, colour, skip=()):
    add = {}
    for (x, y) in f.px:
        for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if n not in f.px and n not in skip:
                add[n] = colour
    for p, c in add.items():
        f.put(p[0], p[1], c)
    return f


def item_closed(kind):
    f = Tall()
    if kind == 'umbrella_nylon':
        # stubby folded umbrella in its sleeve, strap looped at the handle
        for i in range(11):
            x, y = 10 + i, 22 - i
            f.pts(N[0], (x - 1, y - 2), (x, y - 2)); f.pts(N[1], (x, y - 1), (x + 1, y - 1), (x - 1, y - 1))
            f.pts(N[2], (x, y), (x + 1, y)); f.pts(N[3], (x + 1, y + 1), (x + 2, y), (x + 2, y + 1))
        f.pts(N[3], (13, 18), (14, 18), (15, 17), (16, 17)); f.pts(N[0], (12, 17), (13, 16))   # closing band
        for i in range(4):
            x, y = 21 + i, 11 - i
            f.pts(PL[0], (x, y - 1)); f.pts(PL[1], (x, y), (x + 1, y - 1)); f.pts(PL[2], (x + 1, y))
        outline(f, N[4])
        f.pts(PL[2], (26, 7), (27, 8), (27, 9), (27, 10), (26, 11), (25, 11))                   # wrist strap
        return f
    ramp = P if kind == 'umbrella_paper' else K
    # furled canopy, slim at the tip and full near the handle
    for i in range(17):
        x, y = 6 + i, 26 - i
        w = 0 if i < 2 else 1 if i < 13 else 0
        f.put(x, y, ramp[1])
        if w:
            f.pts(ramp[0], (x - 1, y - 1)); f.pts(ramp[2], (x + 1, y)); f.pts(ramp[3], (x + 1, y + 1)); f.pts(ramp[1], (x, y - 1))
        if i % 3 == 1 and 2 <= i < 13:
            f.put(x, y, ramp[3])                              # folds
    if kind == 'umbrella_paper':
        for (x, y) in ((11, 20), (12, 21), (12, 20), (11, 19)):
            f.put(x, y, RD[1])
        f.pts(RD[0], (11, 20)); f.pts(TW[1], (16, 15), (17, 16), (16, 16)); f.pts(TW[0], (15, 15))
        hand, tip = BM, BM
    else:
        f.pts(K[0], (14, 17), (15, 18), (14, 18))
        hand, tip = W, L
    outline(f, ramp[4])
    f.pts(tip[1], (4, 28), (5, 27)); f.pts(tip[3], (5, 28))
    for i in range(5):
        x, y = 23 + i, 9 - i
        f.put(x, y, hand[1]); f.put(x + 1, y, hand[3]); f.put(x, y - 1, hand[0])
    if kind == 'umbrella_cloth':
        f.pts(W[1], (28, 4), (29, 5), (29, 6), (28, 7)); f.pts(W[3], (29, 4), (30, 5), (30, 6), (29, 7), (27, 8))
        f.pts(W[0], (28, 3))
    return f


def item_open(kind):
    spec = KINDS[kind]
    f = Tall()
    top = 6 if kind == 'umbrella_cloth' else 7
    rim = top + spec['canopy'].height
    shaft(f, 15, rim - 1, 24, spec['shaft'] if kind != 'umbrella_nylon' else [L[0], L[1], L[2], L[3]])
    grip(f, kind, 15, 25)
    spec['canopy'].draw(f, 15, top, spec['trim'])
    return f


# ---------------------------------------------------------------- held bundles

def bundle(ramp, x, tie=None):
    """A folded garment in the hand."""
    f = Tall()
    f.part({17: (x - 1, x + 1), 18: (x - 2, x + 2), 19: (x - 2, x + 2), 20: (x - 2, x + 2), 21: (x - 2, x + 2),
            22: (x - 1, x + 2), 23: (x - 1, x + 1)}, ramp)
    f.h(20, x - 1, x + 1, ramp[3]); f.pts(ramp[0], (x - 1, 18), (x, 18)); f.pts(ramp[2], (x, 22))
    if tie:
        f.v(x, 18, 22, tie[1]); f.put(x, 18, tie[0])
    return f


def straw_bundle(x):
    f = bundle(S, x, TW)
    for y in (19, 21, 22):
        for xx in (x - 1, x + 1):
            if (xx, y) in f.px and f.px[(xx, y)] != S[4]:
                f.put(xx, y, S[STRAND[(xx * 5 + y) % len(STRAND)]])
    f.pts(S[3], (x - 1, 24), (x + 1, 24))
    return f


def hat_in_hand(x):
    f = Tall()
    f.part({18: (x - 1, x + 1), 19: (x - 2, x + 2), 20: (x - 2, x + 2), 21: (x - 3, x + 3), 22: (x - 3, x + 2)}, Y)
    f.h(21, x - 2, x + 2, Y[3]); f.pts(Y[0], (x - 1, 19)); f.pts(Y[2], (x - 2, 22), (x - 1, 22))
    return f


def four(make, s=21, n=9, e=16, w=13):
    """Left-hand frames S, N, E, W for a maker taking the hand's column."""
    return [make(s), make(n), make(e), make(w)]


def right_of(left):
    return [left[0].flip(), left[1].flip(), left[3].flip(), left[2].flip()]


def held_frames():
    left = {
        'straw_rain_cape': four(straw_bundle),
        'oilskin_coat': four(lambda x: bundle(Y, x)),
        'souwester': four(hat_in_hand),
    }
    for kind in KINDS:
        left[kind] = four(lambda x, k=kind: held_closed(k, x), 22, 8, 17, 12)
        # canopy leans in over the head
        left[kind + '_open'] = [held_open(kind, 21, 17), held_open(kind, 9, 13), held_open(kind, 13, 15),
                                held_open(kind, 17, 15)]
    return left, {name: right_of(frames) for name, frames in left.items()}


# ---------------------------------------------------------------- lean-to

def leaf(f, x, y, k=0, flip=False):
    """One broad leaf, tip down, 3x4."""
    a, b, c = G[k], G[min(k + 1, 3)], G[min(k + 2, 3)]
    pts = [(0, 0, b), (1, 0, a), (2, 0, b), (0, 1, a), (1, 1, G[max(k - 1, 0)]), (2, 1, c), (0, 2, b), (1, 2, a), (2, 2, c),
           (1, 3, c)]
    for dx, dy, col in pts:
        f.put(x + (2 - dx if flip else dx), y + dy, col)
    f.put(x + 1, y + 4, G[4])


def roof_plane(f, quad, seed=0):
    """Leaf thatch over the roof: rows of overlapping leaves on a dark ground,
    lighter up the slope. `quad` gives, per row y, the (x0, x1) span."""
    mask = span_mask(quad)
    ys = sorted({y for _, y in mask})
    for (x, y) in mask:
        f.put(x, y, G[3] if (x + y) % 2 else G[4])
    for row, y in enumerate(range(ys[0] - 1, ys[-1] + 1, 3)):
        for col, x in enumerate(range(-2 + (row % 2) * 2, 34, 4)):
            k = (1, 0, 2, 1, 1, 2, 0, 1, 2)[(col * 3 + row * 5 + seed) % 9]
            g = Tall()
            leaf(g, x, y, k, (col + row) % 2 == 1)
            for p, c in g.px.items():
                if p in mask:
                    f.put(p[0], p[1], c)
    for p in mask:
        if edge(mask, p):
            f.put(p[0], p[1], G[4])
    return mask


def pole(f, x, y0, y1, fork=True):
    f.v(x, y0, y1, W[1]); f.v(x + 1, y0, y1, W[3]); f.pts(W[0], (x, y0 + 1), (x, y0 + 4)); f.put(x, y1, W[3])
    f.pts(W[2], (x, (y0 + y1) // 2))
    if fork:
        f.pts(W[1], (x - 1, y0 - 1), (x + 2, y0 - 1)); f.pts(W[3], (x - 1, y0 - 2), (x + 2, y0 - 2))


def bedding(f, rows):
    for (x, y) in span_mask(rows):
        f.put(x, y, BED[(x * 3 + y * 5) % 3] if (x + y * 2) % 4 else BED[2])


def lean_to_south():
    """Open side towards the viewer: we look in under the high edge."""
    frame, roof = Tall(), Tall()
    for y in range(13, 27):                                   # shade under the roof
        inset = 0 if y < 22 else y - 21
        for x in range(4 + inset, 28 - inset):
            if y < 17 or (x + y) % 2 == 0 or y < 20:
                frame.put(x, y, SHADE)
    bedding(frame, {23: (8, 23), 24: (7, 24), 25: (7, 24), 26: (9, 22)})
    for x in (9, 15, 21):                                     # rafters seen from below
        frame.v(x, 13, 16, W[3])
    pole(frame, 3, 12, 29); pole(frame, 27, 12, 29)
    mask = roof_plane(roof, {2: (4, 27), 3: (2, 29), 4: (1, 30), 5: (1, 30), 6: (0, 31), 7: (0, 31), 8: (0, 31),
                             9: (0, 31), 10: (0, 31), 11: (1, 30)})
    # ridge pole along the high edge, lashed to the forks
    roof.h(11, 1, 30, W[1]); roof.h(12, 1, 30, W[3]); roof.pts(W[0], (2, 11), (3, 11), (8, 11), (9, 11), (16, 11))
    for x in (3, 4, 27, 28):
        roof.pts(TW[0], (x, 11)); roof.pts(TW[2], (x, 12))
    for x in (5, 11, 18, 24):                                 # leaf tips hang over the edge
        roof.pts(G[2], (x, 13)); roof.pts(G[4], (x, 14))
    return frame, roof


def lean_to_north():
    """Open side away from the viewer: the whole leafy slope faces us."""
    frame, roof = Tall(), Tall()
    pole(frame, 3, 3, 16); pole(frame, 27, 3, 16)
    frame.h(4, 1, 30, W[1]); frame.h(5, 1, 30, W[3]); frame.pts(W[0], (6, 4), (7, 4), (14, 4), (22, 4))
    for x in (3, 4, 27, 28):
        frame.pts(TW[0], (x, 4)); frame.pts(TW[2], (x, 5))
    rows = {5: (2, 29), 6: (1, 30)}
    rows.update({y: (0, 31) for y in range(7, 28)})
    rows.update({28: (1, 30), 29: (2, 29)})
    roof_plane(roof, rows, 2)
    for x in (6, 15, 24):                                     # rafters show through near the top
        roof.v(x, 5, 7, W[2]); roof.put(x, 4, W[1])
    for x in range(1, 31, 3):                                 # weighted down along the ground
        roof.pts(G[4], (x, 30)); roof.pts(G[3], (x + 1, 30))
    roof.h(27, 3, 28, W[3]); roof.h(26, 3, 28, W[1]); roof.pts(W[0], (5, 26), (12, 26), (20, 26))
    for x in (4, 10, 17, 23):
        g = Tall(); leaf(g, x, 25, 0, x % 2 == 0); roof.px.update(g.px)
    return frame, roof


def lean_to_east():
    """Open side to the right: the slope climbs from the ground on the left."""
    frame, roof = Tall(), Tall()
    quad = {}
    for x in range(1, 29):
        t = (x - 1) / 27
        far, near = 20 - t * 18, 30 - t * 17
        for y in range(int(round(far)), int(round(near)) + 1):
            lo, hi = quad.get(y, (x, x))
            quad[y] = (min(lo, x), max(hi, x))
    # shade inside, seen through the open triangle
    for x in range(8, 28):
        t = (x - 1) / 27
        for y in range(int(round(30 - t * 17)) + 1, 30):
            if (x + y) % 2 == 0 or x > 16:
                frame.put(x, y, SHADE)
    bedding(frame, {27: (17, 25), 28: (14, 26), 29: (13, 26)})
    pole(frame, 26, 13, 30)
    roof_plane(roof, quad, 4)
    # ridge pole along the high edge, a rafter on the near edge
    for y in range(1, 15):
        roof.put(28, y, W[1]); roof.put(29, y, W[3])
    roof.pts(W[0], (28, 3), (28, 8)); roof.pts(TW[0], (28, 12), (28, 13)); roof.pts(TW[2], (29, 12), (29, 13))
    for x in range(1, 28):
        y = int(round(30 - (x - 1) / 27 * 17))
        roof.put(x, y, W[2] if x % 5 else W[1]); roof.put(x, y + 1, W[4]) if y < 30 else None
    for x in (6, 13, 20):
        y = int(round(30 - (x - 1) / 27 * 17))
        roof.pts(G[1], (x, y + 1)); roof.pts(G[3], (x, y + 2))
    return frame, roof


def flip_pair(pair):
    out = []
    for f in pair:
        g = Tall()
        g.px = {(31 - x, y): c for (x, y), c in f.px.items()}
        out.append(g)
    return tuple(out)


def shelter_states():
    s, n, e = lean_to_south(), lean_to_north(), lean_to_east()
    w = flip_pair(e)
    pairs = [s, n, e, w]
    return {
        'lean_to': [fr.over(rf) for fr, rf in pairs],
        'lean_to_frame': [fr for fr, _ in pairs],
        'lean_to_roof': [rf for _, rf in pairs],
    }


# ---------------------------------------------------------------- sheets

WORN = {
    'straw_rain_cape': [cape_front(), cape_front(True), cape_side(), cape_side().flip()],
    'oilskin_coat': [coat_front(), coat_front(True), coat_side(), coat_side().flip()],
    'souwester': [hat_front(), hat_front(True), hat_side(), hat_side().flip()],
}
ITEMS = {
    'straw_rain_cape': WORN['straw_rain_cape'][1].moved(1, -3),
    'oilskin_coat': WORN['oilskin_coat'][0].moved(1, -4),
    'souwester': WORN['souwester'][2].moved(1, 10),
}
for _kind in KINDS:
    ITEMS[_kind] = item_closed(_kind)
    ITEMS[_kind + '_open'] = item_open(_kind)
HELD_L, HELD_R = held_frames()
SHELTER = shelter_states()


def write_dmi(path, states, dirs, height=32):
    frames = [fr for name in states for fr in (states[name] if dirs > 1 else [states[name]])]
    cols = 4 if dirs > 1 else len(frames)
    rows = (len(frames) + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * 32, rows * height))
    for i, fr in enumerate(frames):
        sheet.paste(fr.image(height), ((i % cols) * 32, (i // cols) * height))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = %d\n' % height
    for name in states:
        text += 'state = "%s"\n\tdirs = %d\n\tframes = 1\n' % (name, dirs)
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta)


def clothing(direction, *names):
    """Existing worn art (suit.dmi / uniform.dmi) to show the cape over."""
    out = Image.new('RGBA', (32, 32))
    for path, name in names:
        sheet = Image.open(ROOT / path)
        index, found, dirs, frames = 0, None, 1, 1
        order = []
        for line in sheet.info.get('Description', '').split('\n'):
            line = line.strip()
            if line.startswith('state = '):
                order.append([line[9:-1], 1, 1])
            elif line.startswith('dirs = '):
                order[-1][1] = int(line[7:])
            elif line.startswith('frames = '):
                order[-1][2] = int(line[9:])
        for state, dirs, frames in order:
            if state == name:
                found = index
                break
            index += dirs * frames
        sheet = sheet.convert('RGBA')
        cols = sheet.width // 32
        i = found + (direction if dirs > 1 else 0)
        out.alpha_composite(sheet.crop(((i % cols) * 32, (i // cols) * 32, (i % cols) * 32 + 32, (i // cols) * 32 + 32)))
    return out


def write_preview(path, scale=5):
    """Review sheet: gear worn and held on the base body, items, and the lean-to."""
    cell, tall = 32 * scale, 48 * scale
    bg, bg2 = (74, 96, 74, 255), (66, 88, 68, 255)
    under = (('icons/mob/suit.dmi', 'jap_raincoat'),)
    figures = [
        ((), ('straw_rain_cape',), None),
        (under, ('straw_rain_cape',), None),
        ((), ('oilskin_coat', 'souwester'), None),
        ((), ('oilskin_coat',), ('umbrella_paper_open', 'L')),
        ((), ('oilskin_coat',), ('umbrella_cloth_open', 'R')),
        ((), ('straw_rain_cape',), ('umbrella_nylon_open', 'L')),
        ((), (), ('umbrella_cloth', 'L')),
    ]
    width = cell * 8
    sheet = Image.new('RGBA', (width, tall * len(figures) + cell * 4), bg)
    for row, (below, worn, held) in enumerate(figures):
        for direction in range(4):
            figure = Image.new('RGBA', (32, 48))
            figure.alpha_composite(base_body(direction), (0, 16))
            if below:
                figure.alpha_composite(clothing(direction, *below), (0, 16))
            for state in worn:
                figure.alpha_composite(WORN[state][direction].image(48))
            if held:
                figure.alpha_composite((HELD_L if held[1] == 'L' else HELD_R)[held[0]][direction].image(48))
            sheet.alpha_composite(figure.resize((cell, tall), Image.NEAREST), (direction * cell, row * tall))
    # held closed umbrellas and bundles, facing the viewer, on the right
    extras = [('umbrella_paper', 'L'), ('umbrella_nylon', 'R'), ('straw_rain_cape', 'L'), ('oilskin_coat', 'R'),
              ('souwester', 'L')]
    for i, (state, hand) in enumerate(extras):
        for j, direction in enumerate((0, 2)):
            figure = Image.new('RGBA', (32, 48))
            figure.alpha_composite(base_body(direction), (0, 16))
            figure.alpha_composite((HELD_L if hand == 'L' else HELD_R)[state][direction].image(48))
            sheet.alpha_composite(figure.resize((cell, tall), Image.NEAREST), ((4 + j) * cell + cell // 4, i * tall))
    # item icons
    names = list(ITEMS)
    y0 = tall * len(figures)
    for i, name in enumerate(names):
        tile = Image.new('RGBA', (32, 32), bg2)
        tile.alpha_composite(ITEMS[name].image())
        sheet.alpha_composite(tile.resize((cell, cell), Image.NEAREST), ((i % 8) * cell, y0 + (i // 8) * cell))
    # lean-to: four directions, then someone sheltering (frame under, roof over)
    grass = (96, 132, 70, 255)
    for direction in range(4):
        tile = Image.new('RGBA', (32, 32), grass)
        tile.alpha_composite(SHELTER['lean_to'][direction].image())
        sheet.alpha_composite(tile.resize((cell, cell), Image.NEAREST), (direction * cell, y0 + 2 * cell))
        tile = Image.new('RGBA', (32, 32), grass)
        tile.alpha_composite(SHELTER['lean_to_frame'][direction].image())
        tile.alpha_composite(base_body(0), (0, -2))
        tile.alpha_composite(WORN['straw_rain_cape'][0].image(), (0, -2))
        tile.alpha_composite(SHELTER['lean_to_roof'][direction].image())
        sheet.alpha_composite(tile.resize((cell, cell), Image.NEAREST), (direction * cell, y0 + 3 * cell))
    sheet.convert('RGB').save(path)


def main():
    write_dmi(ROOT / 'icons/obj/clothing/rain_gear.dmi', ITEMS, 1)
    write_dmi(ROOT / 'icons/mob/rain_gear.dmi', WORN, 4)
    write_dmi(ROOT / 'icons/mob/items/lefthand_rain_gear.dmi', HELD_L, 4, 48)
    write_dmi(ROOT / 'icons/mob/items/righthand_rain_gear.dmi', HELD_R, 4, 48)
    write_dmi(ROOT / 'icons/obj/rain_shelter.dmi', SHELTER, 4)
    if '--preview' in sys.argv[1:-1]:
        write_preview(sys.argv[sys.argv.index('--preview') + 1])


if __name__ == '__main__':
    main()
