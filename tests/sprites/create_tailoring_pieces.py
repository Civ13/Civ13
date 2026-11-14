"""Hand-placed 32px tailoring pattern pieces: the mix-and-match garment bodies,
sleeves, necklines, legwear, waist pieces, collars, closures, trims and
patterns that players combine into their own clothes.

Every pixel is placed by this script from the row tables, point lists and the
fixed grey ramp below (Pillow only); there is no external, traced or generated
artwork. Released under Civ13 AGPL-3.0. Run from the repository root:

    python3 tests/sprites/create_tailoring_pieces.py [--check] [--preview sheet.png] [--sheet states.png]

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
    # Loose items lie flat, front up; the cloak is spread out on its back with
    # the hood and border on it and the clasp at the neck.
    spread = ('tl_cloak', 'tl_cloak_hood', 'tl_cloak_border')
    items = {name: frames[1 if name in spread else 0] for name, frames in worn.items()}
    return worn, items


STATES = (
    'tl_shirt', 'tl_tunic', 'tl_gown', 'tl_sleeve_short', 'tl_sleeve_long', 'tl_neck_round', 'tl_neck_v',
    'tl_neck_high', 'tl_legs_trousers', 'tl_legs_shorts', 'tl_legs_breeches', 'tl_legs_skirt', 'tl_belt', 'tl_sash',
    'tl_shirt_stripes', 'tl_shirt_checks', 'tl_shirt_hem', 'tl_tunic_stripes', 'tl_tunic_checks', 'tl_tunic_hem',
    'tl_gown_stripes', 'tl_gown_checks', 'tl_gown_hem', 'tl_jacket', 'tl_coat', 'tl_cloak', 'tl_coat_sleeve_long',
    'tl_coat_sleeve_cuffed', 'tl_collar_stand', 'tl_collar_lapels', 'tl_collar_fur', 'tl_buttons_single',
    'tl_buttons_double', 'tl_toggles', 'tl_jacket_trim', 'tl_coat_trim', 'tl_cloak_hood', 'tl_cloak_clasp',
    'tl_cloak_border',
)
BACKLESS = ('tl_buttons_single', 'tl_buttons_double', 'tl_toggles', 'tl_cloak_clasp')   # empty from the north


def verify(worn, items):
    """The contract with the game: greyscale, tintable, and every piece on its body."""
    assert tuple(worn) == STATES and tuple(items) == STATES, 'state list drifted'
    for name in STATES:
        for d, f in enumerate(worn[name] + [items[name]]):
            assert f.px or (d == 1 and name in BACKLESS), '%s dir %d is empty' % (name, d)
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


def write_state_sheet(path, worn, items, scale=3):
    """Every state on its own: S, N, E, W worn frames, then the loose item."""
    cell, name_w, per_col = 32 * scale, 150, 13
    group = name_w + 5 * cell + 24
    sheet = Image.new('RGBA', (8 + 3 * group, 44 + per_col * (cell + 4)), BG)
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
    for flag, draw in (('--preview', write_preview), ('--sheet', write_state_sheet)):
        if flag in argv:
            draw(argv[argv.index(flag) + 1], worn, items)
            print('wrote', argv[argv.index(flag) + 1])
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
