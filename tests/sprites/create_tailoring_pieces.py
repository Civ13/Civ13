"""Hand-placed 32px tailoring pattern pieces: the mix-and-match garment bodies,
sleeves, necklines, legwear, waist pieces, collars, closures, trims and
patterns that players combine into their own clothes.

Every pixel is placed by this script from the row tables, point lists and the
fixed grey ramp below (Pillow only); there is no external, traced or generated
artwork. Released under Civ13 AGPL-3.0. Run from the repository root:

    python3 tests/sprites/create_tailoring_pieces.py [--check] [--preview sheet.png] [--sheet states.png] [--hats hats.png] [--accessories accessories.png]

It owns two files and every state in them:

    icons/mob/tailoring.dmi           worn pieces, four directions (SOUTH, NORTH, EAST, WEST)
    icons/obj/clothing/tailoring.dmi  loose item pieces, one direction

`--check` writes nothing and fails if the committed sheets differ from what
this script draws. `--preview <png>` writes a review sheet of tinted
combinations on the base body; `--sheet <png>` lists every state on its own.

The game tints each piece with BYOND `color` (a multiply), so every state is
greyscale: cloth runs from 250 down to about 118, folds and outlines use the
darker greys and nothing is black. Pieces stack body first, then in the order
of STATES, and share one coordinate frame per direction, so any sleeve,
neckline or waist piece fits every body it is offered for. The body necklines
are cut to the deepest opening (the V); `tl_neck_round` and `tl_neck_high`
fill it in. Legwear starts at row 20, directly under the shirt hem at row 19.
The item states reuse the laid-flat front of each piece (the spread back for
the cloak and its pieces), so a loose garment is built from the same overlays.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_diving_gear import Frame, base_body  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
MOB = ROOT / 'icons/mob/tailoring.dmi'
OBJ = ROOT / 'icons/obj/clothing/tailoring.dmi'

# ---------------------------------------------------------------- grey ramp
HI, LIT, MID, DIM = 246, 230, 222, 202   # cloth, lit from the upper left
TOP, LEFT, RIGHT, BOTTOM = 210, 172, 134, 118   # edge tones
FOLD, CREASE, DEEP = 186, 158, 126       # folds, seams and deep creases
SHINE = 250                              # buttons, buckles, highlights


def g(v):
    return (v, v, v)


def rows(*parts):
    """Merge (y0, y1, span, span...) tuples into {y: [spans]}."""
    out = {}
    for y0, y1, *spans in parts:
        for y in range(y0, y1 + 1):
            out.setdefault(y, []).extend(spans)
    return out


def sym(*parts):
    """rows() for left-hand spans, mirrored about the body's centre column (x = 15)."""
    return rows(*[(y0, y1) + tuple(spans) + tuple((30 - b, 30 - a) for a, b in spans) for y0, y1, *spans in parts])


def cells(shape):
    if isinstance(shape, set):
        return shape
    return {(x, y) for y, spans in shape.items() for a, b in spans for x in range(a, b + 1)}


def cloth(shape, f=None):
    """Fill a shape with left-lit cloth: soft edge tones, banded shading across each row."""
    mask = shape if isinstance(shape, set) else cells(shape)
    f = f or Frame()
    for (x, y) in mask:
        if (x, y + 1) not in mask:
            v = BOTTOM
        elif (x + 1, y) not in mask:
            v = RIGHT
        elif (x - 1, y) not in mask:
            v = LEFT
        elif (x, y - 1) not in mask:
            v = TOP
        else:
            a = b = x
            while (a - 1, y) in mask:
                a -= 1
            while (b + 1, y) in mask:
                b += 1
            t = (x - a + 0.5) / (b - a + 1)
            v = LIT if t < 0.2 else HI if t < 0.5 else MID if t < 0.78 else DIM
        f.put(x, y, g(v))
    return f


def dots(f, v, *points):
    f.pts(g(v), *points)
    return f


def pair(f, v, *points):
    """Place points and their mirror about x = 15."""
    for x, y in points:
        f.put(x, y, g(v))
        f.put(30 - x, y, g(v))
    return f


def col(f, x, y0, y1, v):
    f.v(x, y0, y1, g(v))
    return f


def four(south, north, east, west=None):
    return [south, north, east, west or east.mirror()]


def plain(shape_s, shape_n, shape_e):
    return four(cloth(shape_s), cloth(shape_n), cloth(shape_e))


# ---------------------------------------------------------------- uniform bodies
# South and north share the silhouette; the south neck is cut to the V opening.
TORSO_S = sym((10, 10, (11, 12)), (11, 11, (10, 13)), (12, 12, (10, 14))) | rows((13, 15, (10, 20)), (16, 19, (11, 19)))
TORSO_N = sym((10, 10, (11, 13))) | rows((11, 15, (10, 20)), (16, 19, (11, 19)))
# East: the bare arm hangs over x 11-14, so a sleeveless body leaves it clear.
TORSO_E = rows((10, 10, (13, 14)), (11, 11, (13, 17)), (12, 12, (15, 18)), (13, 17, (15, 19)), (18, 19, (16, 19)))

TUNIC_SKIRT = rows((20, 21, (11, 19)), (22, 26, (10, 20)))
TUNIC_SKIRT_E = rows((20, 20, (16, 19)), (21, 21, (12, 18)), (22, 26, (12, 19)))
GOWN_SKIRT = rows((20, 20, (11, 19)), (21, 22, (10, 20)), (23, 24, (9, 21)), (25, 27, (8, 22)), (28, 31, (7, 23)))
GOWN_SKIRT_E = rows((20, 20, (16, 19)), (21, 21, (12, 18)), (22, 22, (12, 19)), (23, 24, (11, 19)),
                    (25, 27, (11, 20)), (28, 31, (10, 21)))

BODY_SHAPES = {
    'tl_shirt': (TORSO_S, TORSO_N, TORSO_E),
    'tl_tunic': (TORSO_S | TUNIC_SKIRT, TORSO_N | TUNIC_SKIRT, TORSO_E | TUNIC_SKIRT_E),
    'tl_gown': (TORSO_S | GOWN_SKIRT, TORSO_N | GOWN_SKIRT, TORSO_E | GOWN_SKIRT_E),
}


def torso_folds(f, d):
    if d == 0:
        dots(f, FOLD, (12, 15), (18, 15), (13, 17), (17, 18))       # creases under the arms and at the waist
        dots(f, CREASE, (15, 13))                                    # the foot of the neck slit
    elif d == 1:
        dots(f, FOLD, (15, 12), (15, 13), (15, 14), (12, 16), (18, 16))
    else:
        dots(f, FOLD, (16, 15), (17, 17))
        col(f, 15, 12, 17, CREASE)                                   # armhole seam beside the bare arm
    return f


def shirt(d):
    return torso_folds(cloth(BODY_SHAPES['tl_shirt'][d]), d)


def tunic(d):
    f = torso_folds(cloth(BODY_SHAPES['tl_tunic'][d]), d)
    if d < 2:
        dots(f, FOLD, (13, 23), (13, 24), (13, 25), (17, 22), (17, 23), (17, 24), (15, 25))
        dots(f, CREASE, (10, 22), (20, 22))
    else:
        dots(f, FOLD, (15, 23), (15, 24), (15, 25), (17, 22), (17, 23))
    return f


def gown(d):
    f = torso_folds(cloth(BODY_SHAPES['tl_gown'][d]), d)
    if d < 2:
        # folds fan out from the waist to the floor
        pair(f, FOLD, (13, 22), (13, 23), (12, 24), (12, 25), (11, 26), (11, 27), (10, 28), (10, 29), (10, 30))
        dots(f, FOLD, (15, 24), (15, 25), (15, 26), (16, 27), (16, 28), (16, 29), (16, 30))
        dots(f, HI, (14, 26), (14, 27), (14, 28), (13, 29), (13, 30))
        pair(f, CREASE, (10, 21), (9, 23), (8, 25), (7, 28))
    else:
        dots(f, FOLD, (14, 23), (14, 24), (13, 25), (13, 26), (13, 27), (12, 28), (12, 29), (12, 30),
             (17, 23), (17, 24), (17, 25), (18, 26), (18, 27), (18, 28), (18, 29), (18, 30))
        dots(f, HI, (15, 26), (15, 27), (15, 28), (15, 29))
    return f


# ---------------------------------------------------------------- sleeves
SHORT_S = sym((11, 11, (10, 10)), (12, 12, (9, 10)), (13, 13, (8, 10)), (14, 14, (7, 10)))
LONG_S = sym((11, 11, (10, 10)), (12, 12, (9, 10)), (13, 14, (8, 10)), (15, 15, (7, 10)), (16, 17, (7, 9)))
SHORT_E = rows((11, 11, (12, 14)), (12, 14, (11, 14)))
LONG_E = rows((11, 11, (12, 14)), (12, 17, (11, 14)))
COAT_SLEEVE_S = sym((11, 11, (9, 10)), (12, 12, (8, 10)), (13, 14, (7, 10)), (15, 15, (6, 10)), (16, 18, (6, 9)))
COAT_SLEEVE_E = rows((10, 10, (12, 14)), (11, 11, (11, 15)), (12, 17, (10, 15)), (18, 18, (11, 15)))
CUFF_S = sym((16, 18, (5, 9)))
CUFF_E = rows((16, 18, (10, 16)))


def sleeve_long():
    s = pair(cloth(LONG_S), FOLD, (8, 15))
    n = pair(cloth(LONG_S), FOLD, (9, 15), (8, 14))
    e = dots(cloth(LONG_E), FOLD, (12, 15), (13, 14))
    return four(s, n, e)


def coat_sleeve(cuffed):
    out = []
    for shape, cuff, elbow in ((COAT_SLEEVE_S, CUFF_S, [(7, 15)]), (COAT_SLEEVE_S, CUFF_S, [(8, 15), (7, 14)]),
                               (COAT_SLEEVE_E, CUFF_E, [(11, 14), (12, 15)])):
        f = cloth(shape)
        if shape is COAT_SLEEVE_S:
            pair(f, FOLD, *elbow)
        else:
            dots(f, FOLD, *elbow)
        if cuffed:
            for (x, y) in cells(cuff):           # the sleeve shadows the top of the cuff
                if f.px.get((x, 15)) in (g(LIT), g(HI), g(MID), g(DIM), g(FOLD)):
                    f.put(x, 15, g(CREASE))
            cloth(cuff, f)                       # the turned-back cuff keeps its own edge
            for (x, y) in cells(cuff):
                if f.px[(x, y)] == g(HI):
                    f.put(x, y, g(SHINE))
        out.append(f)
    return four(*out)


# ---------------------------------------------------------------- necklines
def neck_round():
    s = Frame()
    dots(s, MID, (12, 10), (13, 11), (14, 11), (15, 11)); dots(s, DIM, (16, 11), (17, 11), (18, 10))
    dots(s, HI, (15, 12)); dots(s, CREASE, (14, 12), (16, 12))
    n = Frame()
    dots(n, MID, (13, 10), (14, 11), (15, 11)); dots(n, DIM, (16, 11), (17, 10))
    e = Frame()
    dots(e, MID, (13, 10), (14, 10), (15, 11), (16, 11)); dots(e, DIM, (17, 11), (18, 11))
    dots(e, HI, (19, 12)); dots(e, CREASE, (18, 12))
    return four(s, n, e)


def neck_v():
    s = Frame()
    dots(s, HI, (12, 10), (13, 11), (14, 12)); dots(s, MID, (18, 10), (17, 11), (16, 12))
    dots(s, DIM, (15, 13)); dots(s, CREASE, (15, 14))            # the facing meets in a point
    dots(s, LIT, (11, 10), (12, 11), (13, 12), (14, 13)); dots(s, DIM, (19, 10), (18, 11), (17, 12), (16, 13))
    n = Frame()
    dots(n, HI, (13, 10), (14, 11), (15, 11)); dots(n, MID, (16, 11), (17, 10))
    e = Frame()
    dots(e, HI, (13, 10), (14, 10)); dots(e, MID, (15, 11), (16, 11), (17, 11), (17, 12), (18, 13))
    dots(e, DIM, (18, 12), (19, 13), (19, 14))
    return four(s, n, e)


def neck_high():
    # the stand hugs the neck and rises beside the jaw, leaving the chin clear
    s = cloth(rows((9, 9, (13, 13), (17, 17)), (10, 10, (12, 18))))
    dots(s, HI, (13, 9), (13, 10), (14, 10)); dots(s, MID, (17, 9), (16, 10), (17, 10)); dots(s, DEEP, (15, 10))
    dots(s, MID, (13, 11), (14, 11), (15, 11)); dots(s, DIM, (16, 11), (17, 11)); dots(s, HI, (15, 12))
    n = cloth(rows((9, 9, (13, 17)), (10, 10, (12, 18))))
    dots(n, HI, (13, 9), (14, 9), (15, 9)); dots(n, MID, (16, 9), (17, 9)); dots(n, CREASE, (14, 11), (15, 11), (16, 11))
    e = cloth(rows((9, 9, (14, 15)), (10, 10, (13, 18))))
    dots(e, HI, (14, 9), (14, 10), (15, 10)); dots(e, MID, (16, 10), (17, 10)); dots(e, DIM, (18, 11)); dots(e, MID, (19, 12))
    return four(s, n, e)


# ---------------------------------------------------------------- legwear (shirt body only)
SEAT = [(20, 23, (11, 19))]
TROUSERS_S = rows(*SEAT, (24, 28, (11, 14), (16, 19)), (29, 29, (10, 14), (16, 20)))
TROUSERS_E = rows((20, 20, (16, 19)), (21, 22, (13, 18)), (23, 29, (13, 17)))
SHORTS_S = rows(*SEAT, (24, 24, (11, 14), (16, 19)), (25, 25, (10, 14), (16, 20)))
SHORTS_E = rows((20, 20, (16, 19)), (21, 25, (13, 18)))
BREECHES_S = rows((20, 21, (11, 19)), (22, 23, (10, 20)), (24, 25, (10, 14), (16, 20)), (26, 27, (11, 14), (16, 19)))
BREECHES_E = rows((20, 20, (16, 19)), (21, 25, (12, 18)), (26, 27, (13, 17)))
SKIRT_S = rows((20, 20, (11, 19)), (21, 23, (10, 20)), (24, 28, (9, 21)))
SKIRT_E = rows((20, 20, (16, 19)), (21, 21, (13, 18)), (22, 23, (12, 19)), (24, 28, (11, 19)))


def trousers(d):
    f = cloth((TROUSERS_S, TROUSERS_S, TROUSERS_E)[d])
    if d == 0:
        dots(f, CREASE, (15, 22)); dots(f, DEEP, (15, 23)); dots(f, FOLD, (12, 26), (13, 27), (18, 26), (17, 25))
        dots(f, FOLD, (12, 29), (13, 29), (17, 29), (18, 29))
    elif d == 1:
        dots(f, CREASE, (15, 22)); dots(f, DEEP, (15, 23)); dots(f, FOLD, (13, 26), (12, 27), (17, 26), (18, 27))
    else:
        dots(f, FOLD, (15, 25), (16, 26), (14, 23), (14, 29), (15, 29))
    return f


def shorts(d):
    f = cloth((SHORTS_S, SHORTS_S, SHORTS_E)[d])
    if d < 2:
        dots(f, CREASE, (15, 22)); dots(f, DEEP, (15, 23)); dots(f, FOLD, (12, 24), (18, 24))
    else:
        dots(f, FOLD, (15, 23), (15, 24))
    return f


def breeches(d):
    f = cloth((BREECHES_S, BREECHES_S, BREECHES_E)[d])
    if d < 2:
        dots(f, CREASE, (15, 22)); dots(f, DEEP, (15, 23))
        dots(f, HI, (11, 23), (12, 23), (11, 24), (17, 23), (17, 24))             # the full, gathered thigh
        dots(f, FOLD, (13, 25), (12, 25), (18, 25), (17, 25))
        for x in (11, 12, 13, 14, 16, 17, 18, 19):                                # knee band
            f.put(x, 26, g(CREASE)); f.put(x, 27, g(MID if x in (12, 13, 17, 18) else RIGHT))
    else:
        dots(f, HI, (14, 23), (15, 23), (14, 24)); dots(f, FOLD, (15, 25), (16, 25))
        for x in range(13, 18):
            f.put(x, 26, g(CREASE)); f.put(x, 27, g(MID if x in (14, 15) else RIGHT))
    return f


def skirt(d):
    f = cloth((SKIRT_S, SKIRT_S, SKIRT_E)[d])
    if d < 2:
        dots(f, FOLD, (13, 23), (13, 24), (12, 25), (12, 26), (12, 27), (15, 24), (15, 25), (15, 26), (15, 27),
             (18, 23), (18, 24), (18, 25), (19, 26), (19, 27))
        dots(f, HI, (14, 25), (14, 26), (14, 27))
        dots(f, CREASE, (10, 21), (20, 21), (9, 24), (21, 24))
    else:
        dots(f, FOLD, (14, 23), (14, 24), (14, 25), (13, 26), (13, 27), (17, 24), (17, 25), (17, 26), (17, 27))
    return f


# ---------------------------------------------------------------- waist pieces
def belt():
    out = []
    for d in range(3):
        f = Frame()
        a, b = (11, 19) if d < 2 else (16, 19)
        for x in range(a, b + 1):
            f.put(x, 20, g(LEFT if x == a else RIGHT if x == b else MID if x < (a + b) / 2 else DIM))
        if d == 0:                               # square buckle with its tongue
            dots(f, SHINE, (14, 19), (15, 19), (14, 20), (14, 21)); dots(f, MID, (16, 19), (16, 20), (15, 21), (16, 21))
            dots(f, DEEP, (15, 20)); dots(f, CREASE, (17, 20))
        elif d == 1:
            dots(f, CREASE, (13, 20), (17, 20))  # belt loops
        else:
            dots(f, SHINE, (19, 19), (19, 20)); dots(f, MID, (19, 21)); dots(f, DEEP, (18, 20))
        out.append(f)
    return four(*out)


def sash():
    def band(a, b):
        f = Frame()
        for x in range(a, b + 1):
            f.put(x, 19, g(TOP if a < x < b else LEFT if x == a else RIGHT))
            f.put(x, 20, g(HI if a < x < (a + b) / 2 else MID if x < b else RIGHT))
            f.put(x, 21, g(BOTTOM))
        for i, x in enumerate(range(a + 1, b)):  # the wraps cross on a slant
            if i % 3 == 1:
                f.put(x, 19, g(FOLD)); f.put(x + 1, 20, g(FOLD))
        return f

    s = band(11, 19)
    dots(s, SHINE, (17, 19), (18, 20)); dots(s, CREASE, (16, 20), (17, 21), (18, 19)); dots(s, MID, (17, 20), (18, 21))
    col(s, 17, 22, 26, LIT); col(s, 18, 22, 25, DIM); dots(s, BOTTOM, (17, 27), (18, 26)); dots(s, FOLD, (17, 24))
    n = band(11, 19)
    col(n, 11, 22, 24, DIM); dots(n, BOTTOM, (11, 25))               # the ends show past the hip
    e = band(16, 19)
    w = band(16, 19).mirror()                                       # the knot is on the wearer's left
    dots(w, SHINE, (14, 19), (15, 20)); dots(w, CREASE, (13, 20), (14, 21), (15, 19)); dots(w, MID, (14, 20), (15, 21))
    col(w, 14, 22, 26, LIT); col(w, 15, 22, 25, DIM); dots(w, BOTTOM, (14, 27), (15, 26)); dots(w, FOLD, (14, 24))
    return [s, n, e, w]


# ---------------------------------------------------------------- patterns
def armhole(p, d):
    x, y = p
    if d < 2:
        return x in (10, 20) and 11 <= y <= 15
    return (x == 15 and 12 <= y <= 17) or p in ((13, 11), (14, 11))


def patterns(name, body):
    """Second-colour patterns cut from the body's own shaded cloth, so they sit on it exactly."""
    out = {}
    tests = {
        'stripes': lambda p, d, low: p[0] % 2 == 1,
        'checks': lambda p, d, low: ((p[0] + 1) // 2 + p[1] // 2) % 2 == 0,
        'hem': lambda p, d, low: p[1] >= low - 1 or armhole(p, d),
    }
    for kind, test in tests.items():
        frames = []
        for d in range(3):
            low = max(y for _, y in body[d].px)
            f = Frame()
            f.px = {p: c for p, c in body[d].px.items() if test(p, d, low)}
            if kind == 'hem':
                for (x, y) in list(f.px):        # a lighter band above a firm edge
                    if y == low - 1 and f.px[(x, y)] in (g(HI), g(MID), g(LIT), g(DIM), g(FOLD)):
                        f.put(x, y, g(HI))
            frames.append(f)
        out['%s_%s' % (name, kind)] = four(*frames)
    return out


# ---------------------------------------------------------------- suit bodies
JACKET_S = TORSO_S | rows((20, 20, (11, 19)), (21, 23, (10, 20)))
JACKET_N = TORSO_N | rows((20, 20, (11, 19)), (21, 23, (10, 20)))
JACKET_E = rows((10, 10, (13, 14)), (11, 11, (13, 17)), (12, 12, (15, 19)), (13, 17, (15, 20)), (18, 20, (16, 20)),
                (21, 23, (12, 20)))
COAT_TAIL = rows((24, 26, (9, 21)))
COAT_TAIL_E = rows((24, 26, (11, 20)))
SUIT_SHAPES = {
    'tl_jacket': (JACKET_S, JACKET_N, JACKET_E),
    'tl_coat': (JACKET_S | COAT_TAIL, JACKET_N | COAT_TAIL, JACKET_E | COAT_TAIL_E),
}


def suit_body(name, d):
    f = cloth(SUIT_SHAPES[name][d])
    low = 26 if name == 'tl_coat' else 23
    if d == 0:
        col(f, 15, 13, low - 1, CREASE)                              # where the fronts meet
        dots(f, DEEP, (15, 13)); dots(f, FOLD, (12, 15), (18, 15), (12, 20), (18, 20))
        dots(f, CREASE, (12, 21), (13, 21), (17, 21), (18, 21))      # pocket welts
        if name == 'tl_coat':
            dots(f, FOLD, (12, 24), (12, 25), (18, 24), (18, 25))
    elif d == 1:
        col(f, 15, 12, 19, FOLD)                                     # centre back seam
        dots(f, FOLD, (12, 16), (18, 16))
        if name == 'tl_coat':
            col(f, 15, 20, 25, DEEP); col(f, 14, 21, 25, LIT)        # back vent
            dots(f, CREASE, (13, 20), (17, 20))
        else:
            dots(f, CREASE, (15, 22))
    else:
        col(f, 15, 12, 17, CREASE)
        dots(f, FOLD, (17, 16), (18, 19)); dots(f, CREASE, (16, 21), (17, 21))
        if name == 'tl_coat':
            dots(f, FOLD, (14, 24), (14, 25), (17, 24), (17, 25))
    return f


CLOAK_SIDE = sym((10, 10, (11, 12)), (11, 11, (9, 13)), (12, 12, (8, 12)), (13, 13, (7, 11)), (14, 27, (6, 10)),
                 (28, 28, (7, 10)))
CLOAK_N = sym((10, 10, (11, 13))) | rows((11, 11, (9, 21)), (12, 12, (8, 22)), (13, 13, (7, 23)), (14, 27, (6, 24)),
                                         (28, 28, (7, 23)))
CLOAK_E = rows((10, 10, (13, 15)), (11, 11, (11, 17)), (12, 27, (10, 18)), (28, 28, (11, 18)))


def cloak(d):
    f = cloth((CLOAK_SIDE, CLOAK_N, CLOAK_E)[d])
    if d == 0:
        pair(f, FOLD, (8, 16), (8, 17), (8, 18), (8, 22), (8, 23), (8, 24), (8, 25))
        pair(f, HI, (7, 20), (7, 21))
    elif d == 1:
        for x, y0, y1 in ((9, 15, 27), (12, 17, 27), (15, 14, 27), (18, 16, 27), (21, 15, 27)):
            col(f, x, y0, y1, FOLD)
        for x, y0, y1 in ((10, 18, 26), (16, 19, 26), (22, 18, 25)):
            col(f, x, y0, y1, HI)
        dots(f, CREASE, (9, 27), (12, 27), (15, 27), (18, 27), (21, 27))
    else:
        for x, y0, y1 in ((12, 14, 27), (15, 13, 27)):
            col(f, x, y0, y1, FOLD)
        col(f, 13, 17, 26, HI)
    return f


# ---------------------------------------------------------------- collars
def collar_stand():
    s = cloth(sym((9, 9, (12, 13)), (10, 10, (12, 14))))
    dots(s, HI, (12, 9)); dots(s, MID, (17, 9))
    n = cloth(rows((9, 9, (13, 17)), (10, 10, (12, 18))))
    dots(n, HI, (13, 9), (14, 9), (15, 9)); dots(n, MID, (16, 9), (17, 9))
    e = cloth(rows((9, 9, (14, 15)), (10, 10, (13, 18))))
    dots(e, HI, (14, 9), (14, 10), (15, 10)); dots(e, MID, (16, 10), (17, 10))
    return four(s, n, e)


def collar_lapels():
    s = cloth(sym((10, 10, (11, 12)), (11, 11, (11, 13)), (12, 13, (12, 14)), (14, 14, (13, 14)), (15, 15, (14, 14))))
    dots(s, HI, (11, 10), (12, 11), (13, 12), (13, 13)); dots(s, MID, (19, 10), (18, 11), (17, 12), (17, 13))
    dots(s, DEEP, (11, 12), (19, 12))                                # the notch
    n = cloth(rows((10, 10, (12, 13), (17, 18)), (11, 11, (12, 18))))
    dots(n, HI, (13, 11), (14, 11)); dots(n, MID, (15, 11), (16, 11))
    e = cloth(rows((10, 10, (13, 15)), (11, 11, (14, 18)), (12, 12, (17, 19)), (13, 13, (18, 20)), (14, 14, (19, 20))))
    dots(e, HI, (14, 10), (15, 11), (16, 11)); dots(e, MID, (18, 12), (19, 13))
    return four(s, n, e)


FUR = (250, 226, 196, 236, 166, 244, 210, 150)


def fur(shape):
    """Soft fur: no hard edge, light tufts and dark flecks from a fixed table."""
    mask = cells(shape)
    f = Frame()
    for (x, y) in mask:
        v = FUR[(x * 5 + y * 3 + (x * y) % 3) % 8]
        if (x, y + 1) not in mask:
            v = min(v, 176) - 26
        elif (x, y - 1) not in mask:
            v = max(v, 226)
        f.put(x, y, g(v))
    return f


def collar_fur():
    s = fur(sym((9, 9, (11, 13)), (10, 10, (10, 13)), (11, 11, (9, 14)), (12, 12, (10, 14)), (13, 13, (12, 14))))
    n = fur(rows((9, 9, (12, 18)), (10, 10, (10, 20)), (11, 11, (9, 21)), (12, 12, (10, 20))))
    e = fur(rows((9, 9, (11, 14)), (10, 10, (11, 19)), (11, 11, (11, 20)), (12, 12, (13, 20)), (13, 13, (17, 20))))
    return four(s, n, e)


# ---------------------------------------------------------------- closures and trim
def closure(front, side):
    s, e = Frame(), Frame()
    for v, points in front:
        dots(s, v, *points)
    for v, points in side:
        dots(e, v, *points)
    return four(s, Frame(), e)                   # nothing shows from behind


def buttons_single():
    ys = (14, 16, 18, 20, 22)
    return closure([(SHINE, [(15, y) for y in ys]), (CREASE, [(15, y + 1) for y in ys])],
                   [(SHINE, [(19, y) for y in ys])])


def buttons_double():
    ys = (14, 16, 18, 20)
    return closure([(SHINE, [(13, y) for y in ys] + [(17, y) for y in ys]),
                    (CREASE, [(13, y + 1) for y in ys] + [(17, y + 1) for y in ys])],
                   [(SHINE, [(18, y) for y in ys]), (CREASE, [(18, y + 1) for y in ys])])


def toggles():
    ys = (14, 17, 20)
    return closure([(SHINE, [(x, y) for y in ys for x in (14, 15)]), (MID, [(16, y) for y in ys]),
                    (CREASE, [(x, y) for y in ys for x in (12, 13, 17, 18)]),       # cord loops
                    (DEEP, [(x, y + 1) for y in ys for x in (14, 15, 16)])],
                   [(SHINE, [(19, y) for y in ys]), (MID, [(20, y) for y in ys]), (CREASE, [(18, y) for y in ys])])


def trim(name):
    low = 26 if name == 'tl_coat' else 23
    out = []
    for d in range(3):
        mask = cells(SUIT_SHAPES[name][d])
        f = Frame()
        for (x, y) in mask:
            if y == low:
                f.put(x, y, g(MID if x < 15 else DIM))
            elif d == 0 and x in (14, 16) and y >= 13:
                f.put(x, y, g(HI if x == 14 else MID))
            elif d == 2 and x == 20:
                f.put(x, y, g(MID))
        out.append(f)
    return four(*out)


# ---------------------------------------------------------------- cloak pieces
def cloak_hood():
    s = cloth(sym((9, 9, (11, 13)), (10, 10, (10, 13)), (11, 11, (10, 12))))
    dots(s, HI, (11, 9), (12, 9), (11, 10)); dots(s, MID, (18, 9), (19, 9), (18, 10)); dots(s, CREASE, (12, 10), (17, 10))
    n = cloth(rows((9, 9, (12, 18)), (10, 10, (11, 19)), (11, 13, (10, 20)), (14, 14, (11, 19)), (15, 15, (12, 18)),
                   (16, 16, (14, 16))))
    dots(n, CREASE, (12, 10), (13, 11), (14, 11), (15, 11), (16, 11), (17, 11), (18, 10))   # the folded opening
    dots(n, HI, (12, 12), (13, 12), (14, 12), (13, 13)); dots(n, FOLD, (15, 13), (15, 14), (17, 13), (16, 15))
    e = cloth(rows((9, 9, (11, 14)), (10, 10, (10, 14)), (11, 13, (9, 13)), (14, 14, (10, 12)), (15, 15, (11, 11))))
    dots(e, CREASE, (13, 10), (12, 11)); dots(e, HI, (10, 11), (11, 12)); dots(e, FOLD, (11, 13))
    return four(s, n, e)


def cloak_clasp():
    s = Frame()
    dots(s, SHINE, (13, 11), (17, 11)); dots(s, MID, (14, 11), (16, 11)); dots(s, CREASE, (15, 11))
    dots(s, DIM, (13, 12), (17, 12)); dots(s, HI, (13, 10), (17, 10))
    e = Frame()
    dots(e, SHINE, (18, 11)); dots(e, MID, (17, 11), (18, 12)); dots(e, HI, (18, 10))
    return four(s, Frame(), e)


def cloak_border():
    out = []
    for d, shape in enumerate((CLOAK_SIDE, CLOAK_N, CLOAK_E)):
        mask = cells(shape)
        f = Frame()
        for (x, y) in mask:
            hem = (x, y + 1) not in mask
            if d == 0:
                inner = y >= 11 and (((x + 1, y) not in mask and x < 15) or ((x - 1, y) not in mask and x > 15))
            elif d == 1:
                inner = y >= 14 and ((x - 1, y) not in mask or (x + 1, y) not in mask)
            else:
                inner = y >= 11 and (x + 1, y) not in mask
            if hem or inner:
                f.put(x, y, g(DIM if hem and not inner else HI if x < 15 else MID))
        out.append(f)
    return four(*out)


# ---------------------------------------------------------------- hats
# Every crown shares its two lowest rows (4 and 5, just above the eyes on row
# 6), so one band, brim, pair of flaps or decoration fits every crown.
HAT_FOOT_S, HAT_FOOT_E = (4, 5, (11, 19)), (4, 5, (12, 19))
CROWNS = {
    'tl_hat_round': (rows((2, 2, (13, 17)), (3, 3, (12, 18)), HAT_FOOT_S), None,
                     rows((2, 2, (14, 17)), (3, 3, (12, 18)), HAT_FOOT_E)),
    'tl_hat_tall': (rows((0, 3, (12, 18)), HAT_FOOT_S), None, rows((0, 3, (13, 18)), HAT_FOOT_E)),
    'tl_hat_pointed': (rows((0, 0, (15, 15)), (1, 1, (14, 16)), (2, 2, (13, 17)), (3, 3, (12, 18)), HAT_FOOT_S), None,
                       rows((0, 0, (11, 12)), (1, 1, (11, 15)), (2, 2, (13, 17)), (3, 3, (12, 18)), HAT_FOOT_E)),
    # The soft crown flops over the wearer's right ear and down the back.
    'tl_hat_soft': (rows((2, 2, (11, 18)), (3, 3, (9, 19)), (4, 4, (9, 19)), (5, 5, (11, 19))),
                    rows((2, 2, (12, 19)), (3, 3, (11, 21)), (4, 4, (11, 21)), (5, 5, (11, 19))),
                    rows((2, 2, (12, 17)), (3, 3, (10, 18)), (4, 4, (10, 19)), (5, 5, (12, 19)))),
}


def crown(name):
    south, north, east = CROWNS[name]
    s, n, e = cloth(south), cloth(north or south), cloth(east)
    if name == 'tl_hat_round':
        dots(s, HI, (14, 3), (15, 3)); dots(s, FOLD, (17, 4)); dots(n, FOLD, (15, 3), (15, 4)); dots(e, HI, (14, 3), (15, 3))
    elif name == 'tl_hat_tall':
        for f, a in ((s, 13), (n, 13), (e, 14)):
            col(f, a, 1, 3, HI); col(f, 17, 1, 3, DIM)
        dots(s, TOP, (13, 0), (14, 0), (15, 0), (16, 0), (17, 0)); dots(e, TOP, (14, 0), (15, 0), (16, 0), (17, 0))
    elif name == 'tl_hat_pointed':
        dots(s, HI, (14, 2), (13, 3), (14, 3)); dots(s, FOLD, (16, 2), (17, 3)); dots(n, FOLD, (15, 2), (15, 3), (15, 4))
        dots(e, FOLD, (14, 2), (13, 1)); dots(e, HI, (14, 3), (15, 3))
    else:
        dots(s, FOLD, (11, 4), (12, 4), (13, 3)); dots(s, HI, (14, 3), (15, 3), (16, 3)); dots(s, CREASE, (10, 4))
        dots(n, FOLD, (19, 4), (18, 4), (17, 3)); dots(n, HI, (13, 3), (14, 3)); dots(n, CREASE, (20, 4))
        dots(e, FOLD, (12, 4), (13, 4), (12, 3)); dots(e, HI, (15, 3), (16, 3)); dots(e, CREASE, (11, 4))
    return four(s, n, e)


def hat_patterns(name, body):
    """Second-colour stripes and sewn panels cut from the crown's own shaded cloth."""
    out = {}
    for kind, test in (('stripes', lambda x, y, mid: x % 2 == 1), ('panels', lambda x, y, mid: (x - mid) % 4 in (0, 1))):
        frames = []
        for d in range(3):
            xs = [x for x, _ in body[d].px]
            mid = (min(xs) + max(xs)) // 2
            f = Frame()
            f.px = {p: c for p, c in body[d].px.items() if test(p[0], p[1], mid)}
            frames.append(f)
        out['%s_%s' % (name, kind)] = four(*frames)
    return out


def strip(y, a, b, f=None, top=HI, low=None):
    """One row of cloth, lit from the left."""
    f = f or Frame()
    for x in range(a, b + 1):
        f.put(x, y, g(low if low and x > (a + b) / 2 else LEFT if x == a else RIGHT if x == b else top))
    return f


def hat_band():
    s, n, e = strip(4, 11, 19, low=MID), strip(4, 11, 19, low=MID), strip(4, 12, 19, low=MID)
    dots(s, CREASE, (18, 4)); dots(n, CREASE, (15, 4))     # the knot, then the seam at the back
    return four(s, n, e)


def hat_band_fur():
    return four(fur(rows((4, 5, (10, 20)))), fur(rows((4, 5, (10, 20)))), fur(rows((4, 5, (11, 20)))))


def brim_narrow():
    s, n, e = strip(5, 9, 21, top=LIT, low=DIM), strip(5, 9, 21, top=LIT, low=DIM), strip(5, 10, 21, top=LIT, low=DIM)
    return four(s, n, e)


def brim_wide():
    out = []
    for a, b in ((7, 23), (7, 23), (8, 23)):
        f = strip(5, a, b, top=LIT, low=DIM)
        strip(4, a + 3, b - 3, f, top=HI, low=MID)                  # the brim rises to meet the crown
        dots(f, BOTTOM, (a, 6), (a + 1, 6), (b - 1, 6), (b, 6))    # and droops at its ends
        out.append(f)
    return four(*out)


def brim_peak():
    s = strip(5, 10, 20, top=SHINE, low=LIT)
    dots(s, BOTTOM, (10, 5), (20, 5))
    e = strip(5, 18, 23, top=LIT, low=DIM)
    dots(e, BOTTOM, (23, 6), (22, 6))
    return four(s, Frame(), e)


def brim_cocked():
    """A brim pinned up at both sides: low over the brow, rising to a corner past each ear."""
    wings = sym((2, 2, (7, 8)), (3, 3, (7, 10)), (4, 4, (8, 11)), (5, 5, (10, 14))) | rows((5, 5, (15, 15)))
    s, n = cloth(wings), cloth(wings)
    pair(s, HI, (8, 3), (9, 4)); dots(s, SHINE, (15, 5))
    e = strip(5, 10, 23, top=LIT, low=DIM)
    for y, a, b in ((4, 11, 17), (3, 12, 16)):                      # the turned-up side
        strip(y, a, b, e, top=HI, low=MID)
    dots(e, TOP, (13, 2), (14, 2), (15, 2)); dots(e, BOTTOM, (24, 6), (23, 6)); dots(e, LEFT, (10, 4))
    return four(s, n, e)


def ear_flaps():
    s = Frame()
    for x, v in ((10, LEFT), (11, HI), (19, MID), (20, RIGHT)):
        col(s, x, 6, 8, v)
    dots(s, BOTTOM, (10, 9), (20, 9)); dots(s, FOLD, (11, 8), (19, 8))
    e = cloth(rows((6, 8, (13, 15)), (9, 9, (14, 14))))
    dots(e, CREASE, (14, 10))                                       # the tie
    return four(s, s, e)


def neck_cloth():
    s = Frame()
    for x, v in ((10, LEFT), (20, RIGHT)):
        col(s, x, 6, 9, v)
    dots(s, BOTTOM, (10, 10), (20, 10))
    n = cloth(rows((6, 7, (11, 19)), (8, 10, (10, 20)), (11, 11, (11, 19))))
    dots(n, FOLD, (13, 8), (13, 9), (17, 8), (17, 9), (15, 10))
    e = cloth(rows((6, 7, (11, 13)), (8, 10, (10, 13)), (11, 11, (10, 12))))
    dots(e, FOLD, (12, 8), (12, 9))
    return four(s, n, e)


def feather():
    def quill(points):
        f = Frame()
        for i, (x, y) in enumerate(points):
            f.put(x, y, g(SHINE if i == len(points) - 1 else HI if i % 2 else LIT))
        return f
    s = quill(((19, 4), (20, 3), (20, 2), (21, 1), (21, 0)))
    dots(s, FOLD, (21, 2), (22, 1)); dots(s, DIM, (22, 0))
    e = quill(((15, 4), (14, 3), (13, 2), (12, 1), (11, 0)))
    dots(e, FOLD, (13, 3), (12, 2), (11, 1)); dots(e, DIM, (10, 0))
    return four(s, s.mirror(), e)


def plume():
    s = fur(rows((0, 0, (20, 22)), (1, 2, (19, 23)), (3, 3, (19, 22)), (4, 4, (19, 20))))
    e = fur(rows((0, 0, (10, 13)), (1, 1, (9, 14)), (2, 2, (10, 15)), (3, 3, (12, 16)), (4, 4, (14, 16))))
    return four(s, s.mirror(), e)


def badge():
    s = Frame()
    dots(s, SHINE, (15, 3), (15, 4)); dots(s, MID, (14, 4), (16, 4)); dots(s, DIM, (15, 5))
    e = Frame()
    dots(e, SHINE, (19, 4)); dots(e, MID, (19, 3), (18, 4))
    return four(s, Frame(), e)


def ribbons():
    s = Frame()
    dots(s, HI, (20, 5), (21, 6)); dots(s, MID, (21, 7), (20, 6)); dots(s, BOTTOM, (21, 8))
    n = Frame()
    dots(n, SHINE, (14, 4), (15, 4), (16, 4)); dots(n, CREASE, (15, 5))        # the bow, then its two tails
    col(n, 14, 5, 8, HI); col(n, 16, 5, 8, MID); dots(n, BOTTOM, (14, 9), (16, 8))
    e = Frame()
    dots(e, SHINE, (12, 4)); col(e, 11, 5, 8, HI); col(e, 12, 5, 7, MID); dots(e, BOTTOM, (11, 9), (12, 8))
    return four(s, n, e)


def lowered(frame, by=11):
    """A worn hat frame moved down the tile, so the loose item sits in its middle."""
    f = Frame()
    f.px = {(x, y + by): c for (x, y), c in frame.px.items()}
    return f


# ---------------------------------------------------------------- gloves, boots and belts
# Worn pieces sit on the hands, feet and waist of the base body, on the same
# pixels as the game's plain leather gloves, boots and belt. Each state also has
# its own loose drawing: a pair of gloves laid flat, a pair of boots standing
# side on, a belt laid out. Pieces share the hand, the foot and the strap, so
# one cuff, sole or buckle fits every body it is offered for.
def bar(shape, top=HI, low=MID):
    """A narrow band: light along its upper edge, a shade darker at its right end."""
    mask = shape if isinstance(shape, set) else cells(shape)
    f = Frame()
    for (x, y) in mask:
        v = top if (x, y - 1) not in mask else low
        f.put(x, y, g(min(v, DIM) if (x + 1, y) not in mask and (x - 1, y) in mask else v))
    return f


def cut(frames, test):
    """A piece cut from another piece's own shaded cloth, one frame per direction."""
    out = []
    for fr in frames:
        f = Frame()
        f.px = {p: c for p, c in fr.px.items() if test(*p)}
        out.append(f)
    return out


def spots(v, *points):
    return dots(Frame(), v, *points)


HAND_S = cells(sym((18, 20, (7, 10)), (21, 21, (8, 9))))
HAND_E = cells(rows((18, 20, (12, 15), (20, 20)), (21, 21, (13, 14))))
ARM_S = cells(sym((15, 15, (7, 10)), (16, 17, (7, 9))))        # a long glove reaches the elbow
ARM_E = cells(rows((15, 17, (11, 14))))
SHOE_S = cells(sym((29, 29, (10, 14)), (30, 31, (9, 14))))
SHOE_E = cells(rows((29, 29, (13, 18)), (30, 31, (13, 19))))
ANKLE_S, ANKLE_E = cells(sym((27, 28, (11, 14)))), cells(rows((27, 28, (13, 17))))
SHAFT_S, SHAFT_E = cells(sym((23, 26, (11, 14)))), cells(rows((23, 26, (13, 17))))
WAIST_S, WAIST_E = cells(rows((18, 19, (11, 19)))), cells(rows((18, 19, (12, 12), (16, 19))))
WIDE_S, WIDE_E = cells(rows((17, 19, (11, 19)))), cells(rows((17, 19, (12, 12), (16, 19))))


def waist_sash():
    """A cloth sash wound twice round the waist, knotted on the wearer's left with the ends hanging."""
    def band(shape):
        f = cloth(shape)
        for x, y in sorted(shape):
            if y == 18 and x % 3 == 1 and (x + 1, 19) in shape:    # the wraps cross on a slant
                f.put(x, 18, g(FOLD))
        return f

    def ends(f, x):
        dots(f, SHINE, (x, 18)); dots(f, CREASE, (x - 1, 19))
        col(f, x - 1, 20, 23, LIT); col(f, x, 20, 22, DIM); dots(f, BOTTOM, (x - 1, 24), (x, 23)); dots(f, FOLD, (x - 1, 22))
        return f

    s, n, e, w = band(WAIST_S), band(WAIST_S), band(WAIST_E), band(WAIST_E).mirror()
    ends(s, 18)
    col(n, 12, 20, 22, DIM); dots(n, BOTTOM, (12, 23))
    ends(w, 14)
    return [s, n, e, w]


def worn_accessories():
    worn = {}
    worn['tl_gloves'] = plain(HAND_S, HAND_S, HAND_E)
    worn['tl_gloves_long'] = plain(HAND_S | ARM_S, HAND_S | ARM_S, HAND_E | ARM_E)
    cuff_s, cuff_e = sym((17, 17, (7, 10))), rows((17, 17, (11, 15)))
    worn['tl_glove_cuff'] = four(bar(cuff_s), bar(cuff_s), bar(cuff_e))
    flare_s, flare_e = sym((15, 15, (7, 10)), (16, 17, (6, 10))), rows((15, 15, (11, 14)), (16, 17, (11, 15)))
    worn['tl_glove_gauntlet'] = plain(flare_s, flare_s, flare_e)
    worn['tl_glove_cuff_fur'] = four(fur(sym((16, 17, (6, 10)))), fur(sym((16, 17, (6, 10)))), fur(rows((16, 17, (11, 15)))))
    band_s, band_e = sym((15, 15, (7, 10))), rows((15, 15, (11, 14)))
    worn['tl_glove_long_band'] = four(bar(band_s), bar(band_s), bar(band_e))
    worn['tl_glove_long_fur'] = four(fur(sym((14, 15, (6, 10)))), fur(sym((14, 15, (6, 10)))), fur(rows((14, 15, (10, 15)))))
    knuckles = pair(pair(Frame(), SHINE, (8, 19)), MID, (9, 19))
    worn['tl_glove_knuckles'] = four(knuckles, knuckles, dots(spots(SHINE, (13, 19), (20, 19)), MID, (14, 19)))
    stripe = pair(Frame(), HI, (9, 18), (9, 19), (9, 20))
    worn['tl_glove_stripe'] = four(stripe, stripe, spots(HI, (14, 18), (14, 19), (14, 20)))
    worn['tl_glove_tips'] = cut(worn['tl_gloves'], lambda x, y: y >= 20)

    worn['tl_shoes'] = plain(SHOE_S, SHOE_S, SHOE_E)
    worn['tl_boots'] = plain(SHOE_S | ANKLE_S, SHOE_S | ANKLE_S, SHOE_E | ANKLE_E)
    worn['tl_boots_tall'] = plain(SHOE_S | ANKLE_S | SHAFT_S, SHOE_S | ANKLE_S | SHAFT_S, SHOE_E | ANKLE_E | SHAFT_E)
    sole_s, sole_e = sym((31, 31, (9, 14))), rows((31, 31, (13, 19)))
    worn['tl_boot_sole'] = four(bar(sole_s, MID), bar(sole_s, MID), bar(sole_e, MID))
    worn['tl_boot_toecap'] = four(bar(sym((30, 30, (9, 14)))), Frame(), bar(rows((29, 29, (18, 18)), (30, 30, (17, 19)))))
    strap_s, strap_e = sym((29, 29, (10, 14))), rows((29, 29, (13, 18)))
    worn['tl_boot_strap'] = four(bar(strap_s), bar(strap_s), bar(strap_e))
    buckle = pair(pair(Frame(), SHINE, (10, 29)), MID, (11, 29))
    worn['tl_boot_buckle'] = four(buckle, buckle, dots(spots(SHINE, (15, 29)), MID, (16, 29)))
    laces = {'tl_shoes': ((12, 29),), 'tl_boots': ((12, 27), (13, 28), (12, 29)),
             'tl_boots_tall': ((12, 23), (13, 24), (12, 25), (13, 26), (12, 27), (13, 28), (12, 29))}
    for body, points in laces.items():
        side = [(17 if x == 12 else 16, y) for x, y in points]
        worn[body + '_laces'] = four(pair(Frame(), SHINE, *points), Frame(), spots(SHINE, *side))
    for body, top in (('tl_boots', 27), ('tl_boots_tall', 23)):
        low = top + (1 if body == 'tl_boots_tall' else 0)
        cs, ce = sym((top, low, (11, 14))), rows((top, low, (13, 17)))
        worn[body + '_cuff'] = four(bar(cs), bar(cs), bar(ce))
        fs, fe = sym((top - 1, top, (10, 14))), rows((top - 1, top, (12, 18)))
        worn[body + '_fur'] = four(fur(fs), fur(fs), fur(fe))

    worn['tl_waist_belt'] = plain(WAIST_S, WAIST_S, WAIST_E)
    worn['tl_waist_wide'] = plain(WIDE_S, WIDE_S, WIDE_E)
    worn['tl_waist_sash'] = waist_sash()
    square = dots(dots(dots(spots(SHINE, (14, 18), (14, 19)), HI, (15, 18)), MID, (16, 18), (16, 19)), DEEP, (15, 19))
    worn['tl_waist_buckle_square'] = four(square, Frame(), dots(spots(SHINE, (20, 18)), MID, (20, 19)))
    ring = dots(dots(dots(spots(SHINE, (15, 17), (14, 18)), HI, (14, 19), (16, 18)), MID, (16, 19), (15, 20)), DEEP, (15, 18), (15, 19))
    worn['tl_waist_buckle_round'] = four(ring, Frame(), dots(spots(SHINE, (20, 17), (20, 18)), MID, (20, 19), (20, 20)))
    plate = cloth(rows((17, 17, (14, 16)), (18, 19, (13, 17)), (20, 20, (14, 16))))
    dots(plate, SHINE, (14, 18), (15, 18)); dots(plate, DEEP, (15, 19))
    worn['tl_waist_buckle_plate'] = four(plate, Frame(), cloth(rows((17, 20, (20, 20)), (18, 19, (19, 20)))))
    worn['tl_waist_studs'] = four(pair(Frame(), SHINE, (12, 18)), pair(Frame(), SHINE, (12, 18), (14, 18)), spots(SHINE, (17, 18)))
    worn['tl_waist_stripe'] = cut(worn['tl_waist_belt'], lambda x, y: y == 18)
    end = dots(col(Frame(), 17, 20, 22, MID), BOTTOM, (17, 23))
    worn['tl_waist_end'] = four(end, Frame(), dots(col(Frame(), 19, 20, 22, MID), BOTTOM, (19, 23)))
    sash = worn['tl_waist_sash']
    worn['tl_waist_sash_stripes'] = cut(sash, lambda x, y: y <= 19 and x % 2 == 1 or y > 19 and y % 2 == 1)
    worn['tl_waist_sash_fringe'] = [spots(HI, (17, 24), (18, 23), (17, 25)), spots(HI, (12, 23), (12, 24)), Frame(),
                                    spots(HI, (13, 24), (14, 23), (13, 25))]
    return worn


# Loose gloves: two gloves side by side, fingers up, thumbs inward. Local
# columns 0-9 and rows from the fingertips down; GLOVE_TOP is the tile row of
# the fingertips for both lengths, so the hand pieces fit either.
GLOVE_TOP = 8
GLOVE_HAND = rows((0, 0, (3, 6)), (1, 3, (2, 7)), (4, 4, (1, 7)), (5, 6, (0, 7)), (7, 7, (1, 7)), (8, 11, (2, 7)))
GLOVE_ARM = rows((12, 16, (2, 7)))


def glove_pair(shape):
    local = shape if isinstance(shape, set) else cells(shape)
    return {(12 - x, GLOVE_TOP + y) for x, y in local} | {(18 + x, GLOVE_TOP + y) for x, y in local}


# Loose boots: a pair standing side on, toes to the right. Local columns 0-9,
# rows counted up from the sole on tile row BOOT_SOLE.
BOOT_SOLE = 24
BOOT_FOOT = ((4, (1, 5)), (3, (0, 6)), (2, (0, 8)), (1, (0, 9)), (0, (0, 9)))


def boot_pair(spans):
    """spans: (rows above the sole, (first column, last column)) for one boot."""
    return {(ox + x, BOOT_SOLE - up) for ox in (4, 17) for up, (a, b) in spans for x in range(a, b + 1)}


def boot_shaft(height):
    return tuple((up, (1, 5)) for up in range(5, 5 + height))


def item_accessories():
    items = {}
    items['tl_gloves'] = cloth(glove_pair(GLOVE_HAND))
    items['tl_gloves_long'] = cloth(glove_pair(cells(GLOVE_HAND) | cells(GLOVE_ARM)))
    for name in ('tl_gloves', 'tl_gloves_long'):                # the seams between the fingers
        for x, y in glove_pair({(4, 1), (4, 2), (4, 3), (6, 1), (6, 2)}):
            items[name].put(x, y, g(FOLD))
    items['tl_glove_cuff'] = bar(glove_pair(rows((10, 11, (2, 7)))))
    items['tl_glove_gauntlet'] = cloth(glove_pair(rows((11, 13, (1, 8)), (14, 15, (0, 9)))))
    items['tl_glove_cuff_fur'] = fur(glove_pair(rows((10, 12, (1, 8)))))
    items['tl_glove_long_band'] = bar(glove_pair(rows((15, 16, (2, 7)))))
    items['tl_glove_long_fur'] = fur(glove_pair(rows((15, 17, (1, 8)))))
    f = Frame()
    for x, y in glove_pair({(3, 4), (5, 4)}):
        f.put(x, y, g(SHINE))
    for x, y in glove_pair({(4, 4), (6, 4)}):
        f.put(x, y, g(MID))
    items['tl_glove_knuckles'] = f
    items['tl_glove_stripe'] = bar(glove_pair(rows((4, 9, (4, 5)))))
    items['tl_glove_tips'] = cut([items['tl_gloves']], lambda x, y: y <= GLOVE_TOP + 2)[0]

    items['tl_shoes'] = cloth(boot_pair(BOOT_FOOT))
    items['tl_boots'] = cloth(boot_pair(BOOT_FOOT + boot_shaft(5)))
    items['tl_boots_tall'] = cloth(boot_pair(BOOT_FOOT + boot_shaft(11)))
    items['tl_boot_sole'] = bar(boot_pair(((0, (0, 9)),)), MID)
    items['tl_boot_toecap'] = bar(boot_pair(((2, (7, 8)), (1, (7, 9)))))
    items['tl_boot_strap'] = bar(boot_pair(((3, (0, 6)),)))
    f = Frame()
    for ox in (4, 17):
        dots(f, SHINE, (ox + 2, BOOT_SOLE - 3), (ox + 2, BOOT_SOLE - 2)); dots(f, MID, (ox + 3, BOOT_SOLE - 3), (ox + 3, BOOT_SOLE - 2))
    items['tl_boot_buckle'] = f
    for body, height in (('tl_shoes', 0), ('tl_boots', 5), ('tl_boots_tall', 11)):
        f = Frame()
        for ox in (4, 17):
            dots(f, SHINE, (ox + 6, BOOT_SOLE - 3), (ox + 7, BOOT_SOLE - 2))
            for up in range(4, 5 + height):
                f.put(ox + (5 if up % 2 else 4), BOOT_SOLE - up, g(SHINE))
        items[body + '_laces'] = f
        if height:
            top = 4 + height
            items[body + '_cuff'] = bar(boot_pair(((top, (1, 5)), (top - 1, (1, 5)))))
            items[body + '_fur'] = fur(boot_pair(((top + 1, (0, 6)), (top, (0, 6)), (top - 1, (0, 6)))))

    strap = rows((14, 16, (6, 26)), (15, 15, (27, 28)))
    items['tl_waist_belt'] = cloth(strap)
    items['tl_waist_wide'] = cloth(rows((13, 17, (6, 26)), (14, 16, (27, 28))))
    f = cloth(rows((12, 18, (3, 7))))
    for x, y in cells(rows((14, 16, (4, 5)))):
        del f.px[(x, y)]
    dots(f, SHINE, (3, 12), (4, 12), (3, 13)); dots(f, HI, (5, 15), (6, 15))        # the frame, then the tongue
    items['tl_waist_buckle_square'] = f
    f = cloth(rows((12, 12, (4, 6)), (13, 17, (3, 7)), (18, 18, (4, 6))))
    for x, y in cells(rows((14, 16, (5, 5)))):
        del f.px[(x, y)]
    dots(f, SHINE, (4, 12), (4, 13), (3, 14)); dots(f, HI, (5, 15), (6, 15))
    items['tl_waist_buckle_round'] = f
    f = cloth(rows((11, 11, (3, 7)), (12, 18, (2, 8)), (19, 19, (3, 7))))
    dots(f, SHINE, (3, 12), (4, 12), (3, 13), (5, 14)); dots(f, DEEP, (5, 16), (6, 15), (4, 15)); dots(f, CREASE, (5, 15))
    items['tl_waist_buckle_plate'] = f
    items['tl_waist_studs'] = spots(SHINE, *[(x, 15) for x in range(10, 26, 3)])
    items['tl_waist_stripe'] = bar(rows((15, 15, (8, 26))))
    items['tl_waist_end'] = bar(rows((14, 16, (23, 26)), (15, 15, (27, 28))))
    sash = cloth(rows((12, 18, (4, 25))))
    for x in (9, 15, 21):
        col(sash, x, 13, 17, FOLD)
    for y in (12, 14, 16, 18):
        dots(sash, DIM, (26, y), (27, y))
    items['tl_waist_sash'] = sash
    items['tl_waist_sash_stripes'] = cut([sash], lambda x, y: x <= 25 and x % 3 == 0)[0]
    items['tl_waist_sash_fringe'] = spots(HI, *[(x, y) for y in (12, 14, 16, 18) for x in (26, 27, 28)])
    return items


# ---------------------------------------------------------------- state table
def build():
    worn = {}
    bodies = {'tl_shirt': shirt, 'tl_tunic': tunic, 'tl_gown': gown}
    for name, draw in bodies.items():
        worn[name] = four(draw(0), draw(1), draw(2))
    worn['tl_sleeve_short'] = plain(SHORT_S, SHORT_S, SHORT_E)
    worn['tl_sleeve_long'] = sleeve_long()
    worn['tl_neck_round'] = neck_round()
    worn['tl_neck_v'] = neck_v()
    worn['tl_neck_high'] = neck_high()
    for name, draw in (('tl_legs_trousers', trousers), ('tl_legs_shorts', shorts), ('tl_legs_breeches', breeches),
                       ('tl_legs_skirt', skirt)):
        worn[name] = four(draw(0), draw(1), draw(2))
    worn['tl_belt'] = belt()
    worn['tl_sash'] = sash()
    for name in bodies:
        worn.update(patterns(name, worn[name]))
    for name in ('tl_jacket', 'tl_coat'):
        worn[name] = four(*[suit_body(name, d) for d in range(3)])
    worn['tl_cloak'] = four(cloak(0), cloak(1), cloak(2))
    worn['tl_coat_sleeve_long'] = coat_sleeve(False)
    worn['tl_coat_sleeve_cuffed'] = coat_sleeve(True)
    worn['tl_collar_stand'] = collar_stand()
    worn['tl_collar_lapels'] = collar_lapels()
    worn['tl_collar_fur'] = collar_fur()
    worn['tl_buttons_single'] = buttons_single()
    worn['tl_buttons_double'] = buttons_double()
    worn['tl_toggles'] = toggles()
    worn['tl_jacket_trim'] = trim('tl_jacket')
    worn['tl_coat_trim'] = trim('tl_coat')
    worn['tl_cloak_hood'] = cloak_hood()
    worn['tl_cloak_clasp'] = cloak_clasp()
    worn['tl_cloak_border'] = cloak_border()
    for name in CROWNS:
        worn[name] = crown(name)
    for name in CROWNS:
        worn.update(hat_patterns(name, worn[name]))
    for name, draw in (('tl_hat_band', hat_band), ('tl_hat_band_fur', hat_band_fur), ('tl_hat_brim_narrow', brim_narrow),
                       ('tl_hat_brim_wide', brim_wide), ('tl_hat_peak', brim_peak), ('tl_hat_brim_cocked', brim_cocked),
                       ('tl_hat_flaps', ear_flaps), ('tl_hat_neck_cloth', neck_cloth), ('tl_hat_feather', feather),
                       ('tl_hat_plume', plume), ('tl_hat_badge', badge), ('tl_hat_ribbons', ribbons)):
        worn[name] = draw()
    # Loose items lie flat, front up; the cloak is spread out on its back with
    # the hood and border on it and the clasp at the neck.
    spread = ('tl_cloak', 'tl_cloak_hood', 'tl_cloak_border')
    # A loose hat is its front view, moved down to the middle of the tile.
    items = {name: lowered(frames[0]) if name.startswith('tl_hat_') else frames[1 if name in spread else 0]
             for name, frames in worn.items()}
    worn.update(worn_accessories())
    items.update(item_accessories())
    return {name: worn[name] for name in STATES}, {name: items[name] for name in STATES}


STATES = (
    'tl_shirt', 'tl_tunic', 'tl_gown', 'tl_sleeve_short', 'tl_sleeve_long', 'tl_neck_round', 'tl_neck_v',
    'tl_neck_high', 'tl_legs_trousers', 'tl_legs_shorts', 'tl_legs_breeches', 'tl_legs_skirt', 'tl_belt', 'tl_sash',
    'tl_shirt_stripes', 'tl_shirt_checks', 'tl_shirt_hem', 'tl_tunic_stripes', 'tl_tunic_checks', 'tl_tunic_hem',
    'tl_gown_stripes', 'tl_gown_checks', 'tl_gown_hem', 'tl_jacket', 'tl_coat', 'tl_cloak', 'tl_coat_sleeve_long',
    'tl_coat_sleeve_cuffed', 'tl_collar_stand', 'tl_collar_lapels', 'tl_collar_fur', 'tl_buttons_single',
    'tl_buttons_double', 'tl_toggles', 'tl_jacket_trim', 'tl_coat_trim', 'tl_cloak_hood', 'tl_cloak_clasp',
    'tl_cloak_border',
    'tl_hat_round', 'tl_hat_tall', 'tl_hat_pointed', 'tl_hat_soft', 'tl_hat_round_stripes', 'tl_hat_round_panels',
    'tl_hat_tall_stripes', 'tl_hat_tall_panels', 'tl_hat_pointed_stripes', 'tl_hat_pointed_panels',
    'tl_hat_soft_stripes', 'tl_hat_soft_panels', 'tl_hat_band', 'tl_hat_band_fur', 'tl_hat_brim_narrow',
    'tl_hat_brim_wide', 'tl_hat_peak', 'tl_hat_brim_cocked', 'tl_hat_flaps', 'tl_hat_neck_cloth', 'tl_hat_feather',
    'tl_hat_plume', 'tl_hat_badge', 'tl_hat_ribbons',
    'tl_gloves', 'tl_gloves_long', 'tl_glove_cuff', 'tl_glove_gauntlet', 'tl_glove_cuff_fur', 'tl_glove_long_band',
    'tl_glove_long_fur', 'tl_glove_knuckles', 'tl_glove_stripe', 'tl_glove_tips',
    'tl_shoes', 'tl_boots', 'tl_boots_tall', 'tl_boot_sole', 'tl_boot_toecap', 'tl_boot_strap', 'tl_boot_buckle',
    'tl_shoes_laces', 'tl_boots_laces', 'tl_boots_tall_laces', 'tl_boots_cuff', 'tl_boots_fur', 'tl_boots_tall_cuff',
    'tl_boots_tall_fur',
    'tl_waist_belt', 'tl_waist_wide', 'tl_waist_sash', 'tl_waist_buckle_square', 'tl_waist_buckle_round',
    'tl_waist_buckle_plate', 'tl_waist_studs', 'tl_waist_stripe', 'tl_waist_end', 'tl_waist_sash_stripes',
    'tl_waist_sash_fringe',
)
# Empty from the north.
BACKLESS = ('tl_buttons_single', 'tl_buttons_double', 'tl_toggles', 'tl_cloak_clasp', 'tl_hat_peak', 'tl_hat_badge',
            'tl_boot_toecap', 'tl_shoes_laces', 'tl_boots_laces', 'tl_boots_tall_laces', 'tl_waist_buckle_square',
            'tl_waist_buckle_round', 'tl_waist_buckle_plate', 'tl_waist_end')
# The sash is knotted on the wearer's left, so its fringe is hidden from the east.
SIDELESS = ('tl_waist_sash_fringe',)


def verify(worn, items):
    """The contract with the game: greyscale, tintable, and every piece on its body."""
    assert tuple(worn) == STATES and tuple(items) == STATES, 'state list drifted'
    for name in STATES:
        for d, f in enumerate(worn[name] + [items[name]]):
            assert f.px or (d == 1 and name in BACKLESS) or (d == 2 and name in SIDELESS), '%s dir %d is empty' % (name, d)
            for p, (r, gr, b) in f.px.items():
                assert r == gr == b and 96 <= r <= 250, '%s dir %d %s is not a tintable grey' % (name, d, p)
    for body in ('tl_shirt', 'tl_tunic', 'tl_gown'):
        for kind in ('stripes', 'checks', 'hem'):
            for d in range(4):
                assert set(worn['%s_%s' % (body, kind)][d].px) <= set(worn[body][d].px), 'pattern off its cloth'
    for d in range(4):
        shirt_low = max(y for _, y in worn['tl_shirt'][d].px)
        for legs in ('tl_legs_trousers', 'tl_legs_shorts', 'tl_legs_breeches', 'tl_legs_skirt'):
            assert min(y for _, y in worn[legs][d].px) == shirt_low + 1, 'legwear must start under the shirt hem'
        for trim_name, body in (('tl_jacket_trim', 'tl_jacket'), ('tl_coat_trim', 'tl_coat'),
                                ('tl_cloak_border', 'tl_cloak')):
            assert set(worn[trim_name][d].px) <= set(worn[body][d].px), 'trim off its cloth'
        for uniform, coat in (('tl_sleeve_long', 'tl_coat_sleeve_long'), ('tl_sleeve_short', 'tl_coat_sleeve_cuffed')):
            assert set(worn[uniform][d].px) <= set(worn[coat][d].px), 'coat sleeve must cover the uniform sleeve'
        for name in CROWNS:
            assert set(worn['tl_hat_band'][d].px) <= set(worn[name][d].px), 'hat band off its crown'
            assert max(y for _, y in worn[name][d].px) == 5, 'a crown must end just above the eyes'
            for kind in ('stripes', 'panels'):
                assert set(worn['%s_%s' % (name, kind)][d].px) < set(worn[name][d].px), 'hat pattern off its crown'
        for piece in ('tl_hat_brim_narrow', 'tl_hat_brim_wide', 'tl_hat_peak', 'tl_hat_brim_cocked', 'tl_hat_band_fur'):
            face = {(x, y) for (x, y) in worn[piece][d].px if y >= 6 and 11 <= x <= 19}
            assert not face or d != 0, 'a brim must not cover the face'


# ---------------------------------------------------------------- DMI in and out
def write_dmi(path, states, dirs):
    frames = [fr for name in states for fr in (states[name] if dirs > 1 else [states[name]])]
    cols = 4 if dirs > 1 else 8
    sheet = Image.new('RGBA', (cols * 32, ((len(frames) + cols - 1) // cols) * 32))
    for i, fr in enumerate(frames):
        sheet.paste(fr.image(), ((i % cols) * 32, (i // cols) * 32))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name in states:
        text += 'state = "%s"\n\tdirs = %d\n\tframes = 1\n' % (name, dirs)
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta)


def same(path, states, dirs):
    if not path.exists():
        return False
    sheet = Image.open(path)
    names, counts = [], []
    for line in sheet.info.get('Description', '').split('\n'):
        line = line.strip()
        if line.startswith('state = '):
            names.append(line[9:-1])
        elif line.startswith('dirs = '):
            counts.append(int(line[7:]))
    if names != list(states) or counts != [dirs] * len(names):
        return False
    sheet = sheet.convert('RGBA')
    cols, i = sheet.width // 32, 0
    for name in states:
        for fr in (states[name] if dirs > 1 else [states[name]]):
            box = ((i % cols) * 32, (i // cols) * 32, (i % cols) * 32 + 32, (i // cols) * 32 + 32)
            if sheet.crop(box).tobytes() != fr.image().tobytes():
                return False
            i += 1
    return True


# ---------------------------------------------------------------- review sheets
CREAM, NAVY, RED, GOLD, BROWN, GREEN = (236, 226, 204), (44, 62, 110), (176, 52, 44), (224, 180, 70), (112, 74, 44), (58, 124, 88)
TAN, PLUM, TEAL, BLACK, SKY, OLIVE = (190, 160, 110), (128, 52, 104), (48, 118, 122), (62, 62, 70), (96, 140, 200), (112, 116, 62)
LINEN = [('tl_shirt', CREAM), ('tl_sleeve_long', CREAM), ('tl_neck_round', CREAM), ('tl_legs_trousers', BLACK),
         ('tl_belt', BROWN)]
OUTFITS_GOWN = [('tl_gown', CREAM), ('tl_sleeve_long', CREAM), ('tl_neck_round', CREAM)]
OUTFITS = {
    'tl_shirt': [
        ('long sleeves, round neck,\ntrousers, belt', LINEN),
        ('short sleeves, V neck,\nshorts, stripes', [('tl_shirt', RED), ('tl_sleeve_short', RED), ('tl_neck_v', CREAM),
                                                     ('tl_legs_shorts', TAN), ('tl_shirt_stripes', CREAM)]),
        ('long sleeves, high collar,\nbreeches, sash, checks', [('tl_shirt', GREEN), ('tl_sleeve_long', GREEN),
                                                                ('tl_neck_high', CREAM), ('tl_legs_breeches', CREAM),
                                                                ('tl_sash', RED), ('tl_shirt_checks', (36, 84, 60))]),
        ('sleeveless, skirt,\nhem band', [('tl_shirt', SKY), ('tl_legs_skirt', NAVY), ('tl_shirt_hem', GOLD)]),
    ],
    'tl_tunic': [
        ('short sleeves, round neck,\nbelt', [('tl_tunic', BROWN), ('tl_sleeve_short', BROWN), ('tl_neck_round', TAN),
                                               ('tl_belt', BLACK)]),
        ('long sleeves, V neck,\nsash, hem band', [('tl_tunic', NAVY), ('tl_sleeve_long', NAVY), ('tl_neck_v', GOLD),
                                                   ('tl_sash', GOLD), ('tl_tunic_hem', GOLD)]),
        ('long sleeves, high collar,\nstripes', [('tl_tunic', CREAM), ('tl_sleeve_long', CREAM),
                                                 ('tl_neck_high', RED), ('tl_tunic_stripes', RED)]),
        ('sleeveless, checks, belt', [('tl_tunic', OLIVE), ('tl_belt', BROWN), ('tl_tunic_checks', (70, 74, 36))]),
    ],
    'tl_gown': [
        ('long sleeves, V neck,\nsash, hem band', [('tl_gown', PLUM), ('tl_sleeve_long', PLUM), ('tl_neck_v', GOLD),
                                                   ('tl_sash', GOLD), ('tl_gown_hem', GOLD)]),
        ('short sleeves, round neck,\nchecks', [('tl_gown', TEAL), ('tl_sleeve_short', TEAL), ('tl_neck_round', CREAM),
                                                ('tl_gown_checks', (30, 84, 90))]),
        ('long sleeves, high collar,\nstripes, belt', [('tl_gown', CREAM), ('tl_sleeve_long', CREAM),
                                                       ('tl_neck_high', CREAM), ('tl_belt', BROWN),
                                                       ('tl_gown_stripes', SKY)]),
        ('sleeveless, plain', [('tl_gown', RED)]),
    ],
    'tl_jacket': [
        ('waistcoat: no sleeves,\nsingle buttons', LINEN + [('tl_jacket', BROWN), ('tl_buttons_single', GOLD)]),
        ('long sleeves, lapels,\ndouble buttons, trim', LINEN + [('tl_jacket', NAVY), ('tl_coat_sleeve_long', NAVY),
                                                                 ('tl_collar_lapels', NAVY), ('tl_buttons_double', GOLD),
                                                                 ('tl_jacket_trim', GOLD)]),
        ('cuffed sleeves, stand\ncollar, toggles', LINEN + [('tl_jacket', OLIVE), ('tl_coat_sleeve_cuffed', OLIVE),
                                                            ('tl_collar_stand', OLIVE), ('tl_toggles', CREAM)]),
        ('long sleeves, fur collar', LINEN + [('tl_jacket', BLACK), ('tl_coat_sleeve_long', BLACK),
                                              ('tl_collar_fur', TAN)]),
    ],
    'tl_coat': [
        ('cuffed sleeves, lapels,\ndouble buttons, trim', LINEN + [('tl_coat', NAVY), ('tl_coat_sleeve_cuffed', NAVY),
                                                                   ('tl_collar_lapels', CREAM),
                                                                   ('tl_buttons_double', GOLD), ('tl_coat_trim', GOLD)]),
        ('long sleeves, fur collar,\ntoggles', LINEN + [('tl_coat', BROWN), ('tl_coat_sleeve_long', BROWN),
                                                        ('tl_collar_fur', CREAM), ('tl_toggles', CREAM)]),
        ('long sleeves, stand collar,\nsingle buttons', LINEN + [('tl_coat', BLACK), ('tl_coat_sleeve_long', BLACK),
                                                                 ('tl_collar_stand', RED), ('tl_buttons_single', GOLD)]),
        ('sleeveless, plain', LINEN + [('tl_coat', GREEN)]),
    ],
    'tl_cloak': [
        ('clasp', LINEN + [('tl_cloak', RED), ('tl_cloak_clasp', GOLD)]),
        ('hood, clasp, border', LINEN + [('tl_cloak', GREEN), ('tl_cloak_hood', GREEN), ('tl_cloak_clasp', GOLD),
                                         ('tl_cloak_border', GOLD)]),
        ('hood, border, over a gown', OUTFITS_GOWN + [('tl_cloak', NAVY), ('tl_cloak_hood', NAVY), ('tl_cloak_border', SKY)]),
        ('plain', LINEN + [('tl_cloak', BLACK)]),
    ],
}
SUITS = ('tl_jacket', 'tl_coat', 'tl_cloak')
BG, PANEL, INK = (44, 48, 58, 255), (70, 92, 74, 255), (236, 236, 236, 255)


def tinted(frame, colour):
    im = Image.new('RGBA', (32, 32))
    for (x, y), (v, _, _) in frame.px.items():
        im.putpixel((x, y), tuple(v * c // 255 for c in colour) + (255,))
    return im


def stack(pieces, pick, body=None):
    tile = body.copy() if body else Image.new('RGBA', (32, 32))
    for name, colour in pieces:
        tile.alpha_composite(tinted(pick(name), colour))
    return tile


def big(tile, scale):
    return tile.resize((32 * scale, 32 * scale), Image.NEAREST)


def uniform_reference(direction):
    """The existing customtunic worn sprite, for scale."""
    sheet = Image.open(ROOT / 'icons/mob/uniform.dmi')
    index, sizes = 0, []
    for line in sheet.info['Description'].split('\n'):
        line = line.strip()
        if line.startswith('state = '):
            sizes.append([line[9:-1], 1, 1])
        elif line.startswith('dirs = '):
            sizes[-1][1] = int(line[7:])
        elif line.startswith('frames = '):
            sizes[-1][2] = int(line[9:])
    for name, dirs, frames in sizes:
        if name == 'customtunic':
            break
        index += dirs * frames
    cols, i = sheet.width // 32, index + direction
    return sheet.convert('RGBA').crop(((i % cols) * 32, (i // cols) * 32, (i % cols) * 32 + 32, (i // cols) * 32 + 32))


def write_preview(path, worn, items, scale=4):
    cell, gap, label = 32 * scale, 8, 30
    bodies = [base_body(d) for d in range(4)]
    block = 4 * cell + gap * 3
    width = 110 + 4 * (block + gap)
    row_h = label + cell + gap
    height = 30 + 6 * row_h + 40 + 2 * row_h + 40 + 3 * row_h + 20
    sheet = Image.new('RGBA', (width, height), BG)
    draw = ImageDraw.Draw(sheet)
    draw.text((8, 8), 'Tailoring pattern pieces - tinted combinations on the base body (S, N, E, W), 4x', fill=INK)
    y = 30
    for body, outfits in OUTFITS.items():
        draw.text((8, y + label + 8), body, fill=INK)
        draw.text((8, y + label + 22), 'suit layer' if body in SUITS else 'uniform layer', fill=(170, 176, 190, 255))
        for c, (text, pieces) in enumerate(outfits):
            x = 110 + c * (block + gap)
            draw.multiline_text((x + 2, y + 2), text, fill=INK, spacing=1)
            draw.rectangle((x, y + label, x + 4 * cell - 1, y + label + cell - 1), fill=PANEL)
            for d in range(4):
                sheet.alpha_composite(big(stack(pieces, lambda n: worn[n][d], bodies[d]), scale), (x + d * cell, y + label))
        y += row_h
    draw.text((8, y + 6), 'Loose items - the same combinations built from icons/obj/clothing/tailoring.dmi, 4x', fill=INK)
    y += 24
    loose = [(b, o) for b in OUTFITS for o in OUTFITS[b]]
    per = (width - 16) // (cell + gap)
    for i, (body, (text, pieces)) in enumerate(loose[:2 * per]):
        x, yy = 8 + (i % per) * (cell + gap), y + (i // per) * row_h
        draw.text((x + 2, yy + 8), body, fill=INK)
        draw.rectangle((x, yy + label, x + cell - 1, yy + label + cell - 1), fill=PANEL)
        own = [p for p in pieces if body not in SUITS or p not in LINEN and p not in OUTFITS_GOWN]
        sheet.alpha_composite(big(stack(own, lambda n: items[n]), scale), (x, yy + label))
    y += 2 * row_h + 12
    draw.text((8, y + 6), 'Plain greyscale states as stored (untinted): each body alone, then with its plain pieces; '
              'far right: existing customtunic for scale', fill=INK)
    y += 24
    white = (255, 255, 255)
    plain_rows = [
        [('tl_shirt', ['tl_shirt']), ('tl_tunic', ['tl_tunic']), ('tl_gown', ['tl_gown']),
         ('tl_gown + long sleeves + V neck + sash', ['tl_gown', 'tl_sleeve_long', 'tl_neck_v', 'tl_sash'])],
        [('tl_shirt + short sleeves + round neck\n+ breeches + belt',
          ['tl_shirt', 'tl_sleeve_short', 'tl_neck_round', 'tl_legs_breeches', 'tl_belt']),
         ('tl_jacket', ['tl_jacket']), ('tl_coat', ['tl_coat']), ('tl_cloak', ['tl_cloak'])],
        [('tl_coat + cuffed sleeves + lapels\n+ double buttons',
          ['tl_coat', 'tl_coat_sleeve_cuffed', 'tl_collar_lapels', 'tl_buttons_double']),
         ('tl_jacket + long sleeves + fur collar\n+ toggles',
          ['tl_jacket', 'tl_coat_sleeve_long', 'tl_collar_fur', 'tl_toggles']),
         ('tl_cloak + hood + clasp', ['tl_cloak', 'tl_cloak_hood', 'tl_cloak_clasp']), None],
    ]
    for r, row in enumerate(plain_rows):
        for c, entry in enumerate(row):
            x = 110 + c * (block + gap)
            if entry is None:
                draw.text((x + 2, y + 8), 'existing uniform.dmi customtunic', fill=INK)
                draw.rectangle((x, y + label, x + 4 * cell - 1, y + label + cell - 1), fill=PANEL)
                for d in range(4):
                    tile = bodies[d].copy()
                    tile.alpha_composite(uniform_reference(d))
                    sheet.alpha_composite(big(tile, scale), (x + d * cell, y + label))
                continue
            text, names = entry
            draw.multiline_text((x + 2, y + 2), text, fill=INK, spacing=1)
            draw.rectangle((x, y + label, x + 4 * cell - 1, y + label + cell - 1), fill=PANEL)
            for d in range(4):
                tile = stack([(n, white) for n in names], lambda n: worn[n][d], bodies[d])
                sheet.alpha_composite(big(tile, scale), (x + d * cell, y + label))
        y += row_h
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.convert('RGB').save(path)


HATS = {
    'tl_hat_round': [
        ('plain', [('tl_hat_round', BROWN)]),
        ('narrow brim, band', [('tl_hat_round', TAN), ('tl_hat_band', BLACK), ('tl_hat_brim_narrow', TAN)]),
        ('wide brim, band, feather', [('tl_hat_round', GREEN), ('tl_hat_band', GOLD), ('tl_hat_brim_wide', GREEN),
                                      ('tl_hat_feather', RED)]),
        ('peak, panels, badge', [('tl_hat_round', NAVY), ('tl_hat_round_panels', CREAM), ('tl_hat_peak', BLACK),
                                 ('tl_hat_badge', GOLD)]),
        ('fur trim, ear flaps', [('tl_hat_round', BROWN), ('tl_hat_band_fur', CREAM), ('tl_hat_flaps', BROWN)]),
    ],
    'tl_hat_tall': [
        ('plain', [('tl_hat_tall', BLACK)]),
        ('narrow brim, band', [('tl_hat_tall', BLACK), ('tl_hat_band', RED), ('tl_hat_brim_narrow', BLACK)]),
        ('wide brim, band, badge', [('tl_hat_tall', BLACK), ('tl_hat_band', BROWN), ('tl_hat_brim_wide', BLACK),
                                    ('tl_hat_badge', GOLD)]),
        ('stripes, peak, plume', [('tl_hat_tall', RED), ('tl_hat_tall_stripes', CREAM), ('tl_hat_band', BLACK),
                                  ('tl_hat_peak', BLACK), ('tl_hat_plume', CREAM)]),
        ('fur trim, ribbons', [('tl_hat_tall', PLUM), ('tl_hat_band_fur', TAN), ('tl_hat_ribbons', GOLD)]),
    ],
    'tl_hat_pointed': [
        ('plain', [('tl_hat_pointed', RED)]),
        ('wide brim, band', [('tl_hat_pointed', OLIVE), ('tl_hat_band', BROWN), ('tl_hat_brim_wide', OLIVE)]),
        ('stripes, narrow brim', [('tl_hat_pointed', CREAM), ('tl_hat_pointed_stripes', SKY),
                                  ('tl_hat_brim_narrow', SKY)]),
        ('fur trim, ear flaps', [('tl_hat_pointed', TEAL), ('tl_hat_band_fur', CREAM), ('tl_hat_flaps', TEAL)]),
        ('panels, neck cloth, ribbons', [('tl_hat_pointed', GOLD), ('tl_hat_pointed_panels', RED),
                                         ('tl_hat_neck_cloth', RED), ('tl_hat_ribbons', CREAM)]),
    ],
    'tl_hat_soft': [
        ('plain', [('tl_hat_soft', NAVY)]),
        ('band, feather', [('tl_hat_soft', PLUM), ('tl_hat_band', GOLD), ('tl_hat_feather', CREAM)]),
        ('cocked brim, plume', [('tl_hat_soft', BLACK), ('tl_hat_brim_cocked', BLACK), ('tl_hat_plume', RED)]),
        ('stripes, peak', [('tl_hat_soft', TAN), ('tl_hat_soft_stripes', BROWN), ('tl_hat_peak', BROWN)]),
        ('panels, neck cloth, badge', [('tl_hat_soft', CREAM), ('tl_hat_soft_panels', GREEN),
                                       ('tl_hat_neck_cloth', CREAM), ('tl_hat_badge', GOLD)]),
    ],
}
HAT_CROWNS = (('tl_hat_round', NAVY), ('tl_hat_tall', BLACK), ('tl_hat_pointed', RED), ('tl_hat_soft', GREEN))


def write_hat_preview(path, worn, items, scale=6):
    """Tinted hats on the dressed base body (head and shoulders), every piece on every crown, and the loose items."""
    crop = 18                                    # rows of each tile shown
    cw, ch, gap, label = 32 * scale, crop * scale, 8, 30
    bodies = []
    for d in range(4):
        body = base_body(d)
        for name, colour in LINEN:
            body.alpha_composite(tinted(worn[name][d], colour))
        bodies.append(body)

    def head(pieces, d):
        return big(stack(pieces, lambda n: worn[n][d], bodies[d]), scale).crop((0, 0, cw, ch))

    block = 4 * cw + gap
    pieces = [n for n in STATES if n.startswith('tl_hat_') and n not in CROWNS and not n.endswith(('_stripes', '_panels'))]
    width = 110 + 5 * (block + gap)
    row_h = label + ch + gap
    piece_w = 2 * cw + gap
    per = (width - 110) // (piece_w + gap)
    piece_rows = -(-len(pieces) // per)
    height = 30 + 4 * row_h + 30 + 4 * piece_rows * row_h + 30 + (32 * scale + label + gap) + 16
    sheet = Image.new('RGBA', (width, height), BG)
    draw = ImageDraw.Draw(sheet)
    draw.text((8, 8), 'Tailored hat pieces - tinted combinations on the base body (S, N, E, W), %dx' % scale, fill=INK)
    y = 30
    for body, hats in HATS.items():
        draw.text((8, y + label + 8), body, fill=INK)
        for c, (text, parts) in enumerate(hats):
            x = 110 + c * (block + gap)
            draw.text((x + 2, y + 10), text, fill=INK)
            draw.rectangle((x, y + label, x + 4 * cw - 1, y + label + ch - 1), fill=PANEL)
            for d in range(4):
                sheet.alpha_composite(head(parts, d), (x + d * cw, y + label))
        y += row_h
    draw.text((8, y + 8), 'Every piece on every crown, front and side: the piece in gold, the crown in its own colour', fill=INK)
    y += 30
    for crown_name, colour in HAT_CROWNS:
        for i, piece in enumerate(pieces):
            x, yy = 110 + (i % per) * (piece_w + gap), y + (i // per) * row_h
            if i % per == 0:
                draw.text((8, yy + label + 8), crown_name, fill=INK)
            draw.text((x + 2, yy + 10), piece, fill=INK)
            draw.rectangle((x, yy + label, x + 2 * cw - 1, yy + label + ch - 1), fill=PANEL)
            for k, d in enumerate((0, 2)):
                sheet.alpha_composite(head([(crown_name, colour), (piece, GOLD)], d), (x + k * cw, yy + label))
        y += piece_rows * row_h
    draw.text((8, y + 8), 'Loose items - the same combinations built from icons/obj/clothing/tailoring.dmi', fill=INK)
    y += 30
    loose = [(b, o) for b in HATS for o in HATS[b]]
    for i, (body, (text, parts)) in enumerate(loose):
        x = 8 + i * (32 * scale // 2 + gap)
        draw.rectangle((x, y + label, x + 32 * scale // 2 - 1, y + label + 32 * scale // 2 - 1), fill=PANEL)
        sheet.alpha_composite(big(stack(parts, lambda n: items[n]), scale // 2), (x, y + label))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.convert('RGB').save(path)


LEATHER, DARK, RUSSET, STEEL = (176, 132, 84), (84, 60, 44), (150, 84, 52), (196, 200, 206)
ACCESSORIES = {
    'tl_gloves': [
        ('plain', [('tl_gloves', LEATHER)]),
        ('turned cuff, back stripe', [('tl_gloves', DARK), ('tl_glove_cuff', CREAM), ('tl_glove_stripe', CREAM)]),
        ('gauntlet cuff, knuckle pads', [('tl_gloves', RUSSET), ('tl_glove_gauntlet', RUSSET), ('tl_glove_knuckles', GOLD)]),
        ('fur cuff, fingertips', [('tl_gloves', NAVY), ('tl_glove_cuff_fur', CREAM), ('tl_glove_tips', BLACK)]),
    ],
    'tl_gloves_long': [
        ('plain', [('tl_gloves_long', CREAM)]),
        ('top band, back stripe', [('tl_gloves_long', PLUM), ('tl_glove_long_band', GOLD), ('tl_glove_stripe', GOLD)]),
        ('fur top, knuckle pads', [('tl_gloves_long', DARK), ('tl_glove_long_fur', TAN), ('tl_glove_knuckles', STEEL)]),
        ('fingertips', [('tl_gloves_long', RED), ('tl_glove_tips', BLACK)]),
    ],
    'tl_shoes': [
        ('plain', [('tl_shoes', LEATHER)]),
        ('sole, laces', [('tl_shoes', DARK), ('tl_boot_sole', TAN), ('tl_shoes_laces', CREAM)]),
        ('toe cap, buckle', [('tl_shoes', BLACK), ('tl_boot_toecap', RUSSET), ('tl_boot_buckle', GOLD)]),
        ('strap, sole', [('tl_shoes', RED), ('tl_boot_strap', GOLD), ('tl_boot_sole', DARK)]),
    ],
    'tl_boots': [
        ('plain', [('tl_boots', LEATHER)]),
        ('turned cuff, laces, sole', [('tl_boots', DARK), ('tl_boot_sole', BLACK), ('tl_boots_laces', CREAM),
                                      ('tl_boots_cuff', TAN)]),
        ('fur cuff, strap', [('tl_boots', RUSSET), ('tl_boot_strap', DARK), ('tl_boots_fur', CREAM)]),
        ('toe cap, buckle', [('tl_boots', BLACK), ('tl_boot_toecap', STEEL), ('tl_boot_buckle', GOLD)]),
    ],
    'tl_boots_tall': [
        ('plain', [('tl_boots_tall', BLACK)]),
        ('turned cuff, buckle', [('tl_boots_tall', DARK), ('tl_boot_buckle', GOLD), ('tl_boots_tall_cuff', TAN)]),
        ('laces, sole, toe cap', [('tl_boots_tall', RUSSET), ('tl_boot_sole', BLACK), ('tl_boot_toecap', DARK),
                                  ('tl_boots_tall_laces', CREAM)]),
        ('fur cuff', [('tl_boots_tall', LEATHER), ('tl_boots_tall_fur', CREAM)]),
    ],
    'tl_waist_belt': [
        ('square buckle', [('tl_waist_belt', LEATHER), ('tl_waist_buckle_square', GOLD)]),
        ('round buckle, studs', [('tl_waist_belt', BLACK), ('tl_waist_buckle_round', STEEL), ('tl_waist_studs', STEEL)]),
        ('plate buckle, stripe', [('tl_waist_belt', RED), ('tl_waist_stripe', GOLD), ('tl_waist_buckle_plate', GOLD)]),
        ('square buckle, hanging end', [('tl_waist_belt', DARK), ('tl_waist_buckle_square', STEEL), ('tl_waist_end', DARK)]),
    ],
    'tl_waist_wide': [
        ('square buckle', [('tl_waist_wide', DARK), ('tl_waist_buckle_square', GOLD)]),
        ('plate buckle, studs', [('tl_waist_wide', BLACK), ('tl_waist_studs', GOLD), ('tl_waist_buckle_plate', GOLD)]),
        ('round buckle, stripe', [('tl_waist_wide', NAVY), ('tl_waist_stripe', CREAM), ('tl_waist_buckle_round', STEEL)]),
        ('round buckle, hanging end', [('tl_waist_wide', RUSSET), ('tl_waist_buckle_round', GOLD), ('tl_waist_end', RUSSET)]),
    ],
    'tl_waist_sash': [
        ('plain', [('tl_waist_sash', RED)]),
        ('stripes', [('tl_waist_sash', CREAM), ('tl_waist_sash_stripes', SKY)]),
        ('fringe', [('tl_waist_sash', PLUM), ('tl_waist_sash_fringe', GOLD)]),
        ('stripes, fringe', [('tl_waist_sash', GREEN), ('tl_waist_sash_stripes', GOLD), ('tl_waist_sash_fringe', CREAM)]),
    ],
}


def write_accessory_preview(path, worn, items, scale=5):
    """Tinted gloves, boots and belts on the dressed base body (S, N, E, W), then the loose item."""
    cell, gap, label = 32 * scale, 8, 30
    dressed = []
    for d in range(4):
        body = base_body(d)
        for name, colour in LINEN[:-1]:
            body.alpha_composite(tinted(worn[name][d], colour))
        dressed.append(body)
    block = 5 * cell + gap
    sheet = Image.new('RGBA', (120 + 4 * (block + gap), 30 + len(ACCESSORIES) * (label + cell + gap) + 8), BG)
    draw = ImageDraw.Draw(sheet)
    draw.text((8, 8), 'Tailored gloves, boots and belts - tinted combinations worn (S, N, E, W) and as the loose item, %dx' % scale,
              fill=INK)
    y = 30
    for body, combos in ACCESSORIES.items():
        draw.text((8, y + label + cell // 2), body, fill=INK)
        for c, (text, parts) in enumerate(combos):
            x = 120 + c * (block + gap)
            draw.text((x + 2, y + 10), text, fill=INK)
            draw.rectangle((x, y + label, x + 5 * cell - 1, y + label + cell - 1), fill=PANEL)
            for d in range(4):
                sheet.alpha_composite(big(stack(parts, lambda n: worn[n][d], dressed[d]), scale), (x + d * cell, y + label))
            sheet.alpha_composite(big(stack(parts, lambda n: items[n]), scale), (x + 4 * cell, y + label))
        y += label + cell + gap
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.convert('RGB').save(path)


def write_state_sheet(path, worn, items, scale=3):
    """Every state on its own: S, N, E, W worn frames, then the loose item."""
    cell, name_w, per_col = 32 * scale, 150, 13
    group = name_w + 5 * cell + 24
    sheet = Image.new('RGBA', (8 + -(-len(STATES) // per_col) * group, 44 + per_col * (cell + 4)), BG)
    draw = ImageDraw.Draw(sheet)
    draw.text((8, 6), 'Every tailoring state, greyscale as stored, 3x: worn S, N, E, W (icons/mob/tailoring.dmi) '
              'and the loose item (icons/obj/clothing/tailoring.dmi)', fill=INK)
    for i, name in enumerate(STATES):
        x0, y0 = 8 + (i // per_col) * group, 44 + (i % per_col) * (cell + 4)
        if i % per_col == 0:
            for k, head in enumerate(('S', 'N', 'E', 'W', 'item')):
                draw.text((x0 + name_w + k * cell + (8 if k == 4 else 0) + cell // 2 - 6, 28), head, fill=INK)
        draw.text((x0, y0 + cell // 2 - 6), name, fill=INK)
        for k, fr in enumerate(worn[name] + [items[name]]):
            x = x0 + name_w + k * cell + (8 if k == 4 else 0)
            for cy in range(0, cell, 12):        # checker so transparency reads
                for cx in range(0, cell, 12):
                    dark = (cx // 12 + cy // 12) % 2
                    draw.rectangle((x + cx, y0 + cy, x + cx + 11, y0 + cy + 11),
                                   fill=(58, 78, 104, 255) if dark else (66, 88, 116, 255))
            sheet.alpha_composite(big(fr.image(), scale), (x, y0))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.convert('RGB').save(path)


def main(argv):
    worn, items = build()
    verify(worn, items)
    if '--check' in argv:
        ok = same(MOB, worn, 4) and same(OBJ, items, 1)
        print('tailoring sprites', 'match' if ok else 'DIFFER from create_tailoring_pieces.py')
        return 0 if ok else 1
    write_dmi(MOB, worn, 4)
    write_dmi(OBJ, items, 1)
    print('wrote', MOB.relative_to(ROOT), 'and', OBJ.relative_to(ROOT))
    for flag, draw in (('--preview', write_preview), ('--sheet', write_state_sheet), ('--hats', write_hat_preview),
                       ('--accessories', write_accessory_preview)):
        if flag in argv:
            draw(argv[argv.index(flag) + 1], worn, items)
            print('wrote', argv[argv.index(flag) + 1])
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
