"""Hand-placed 32px early carrying gear: grass carry net, hide sling bag, pack
basket on a tumpline, wooden pack frame and a travois. Every pixel is placed by
this script from a fixed palette (Pillow only); no external or generated
artwork. Most frames are typed out as character grids, one character per pixel;
the knotted net and the wicker weave are filled by small pattern helpers.
The Frame class, DMI writer and base body come from create_diving_gear.py.

Run with Pillow to reproduce icons/obj/primitive_carrying.dmi (item and travois
icons) and icons/mob/primitive_carrying.dmi (worn, four directions).
`--preview <png>` also writes a review sheet of the gear worn on the base body.
Released under Civ13 AGPL-3.0.
"""
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_diving_gear import Frame, base_body, write_dmi  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]

# twisted grass twine
G = [(234, 216, 142), (200, 178, 100), (160, 138, 70), (114, 98, 48), (66, 54, 28)]
# raw hide
HD = [(216, 172, 122), (182, 136, 92), (144, 102, 66), (102, 70, 44), (56, 38, 24)]
# fur
FUR = [(180, 154, 124), (144, 118, 92), (108, 86, 64), (78, 60, 44), (46, 34, 24)]
# split willow wicker
W = [(234, 198, 126), (202, 160, 90), (162, 122, 64), (116, 84, 42), (64, 44, 22)]
# peeled poles
D = [(188, 144, 96), (154, 112, 70), (118, 84, 50), (82, 56, 32), (46, 30, 18)]
# sinew lashing
L = [(232, 216, 180), (176, 152, 114)]
BONE = [(240, 232, 212), (190, 176, 150)]
DARK = (34, 26, 18)
GAP = (58, 48, 28)
ROOT_C = [(196, 146, 98), (150, 104, 66)]
LEAF = [(128, 154, 78), (86, 110, 54)]
BERRY = [(190, 62, 56), (132, 36, 40)]

KEY = {'X': DARK, 'T': BONE[0], 'Y': BONE[1], 'u': L[0], 'v': L[1],
       'R': ROOT_C[0], 'S': ROOT_C[1], 'M': LEAF[0], 'N': LEAF[1], 'B': BERRY[0], 'C': BERRY[1]}
for chars, ramp in (('12345', G), ('abcde', HD), ('fghij', FUR), ('klmno', W), ('pqrst', D)):
    for ch, colour in zip(chars, ramp):
        KEY[ch] = colour


def art(f, x0, y0, rows):
    """Place a character grid with its top-left pixel at (x0, y0); '.' is empty."""
    for dy, row in enumerate(rows):
        for dx, ch in enumerate(row):
            if ch != '.':
                f.put(x0 + dx, y0 + dy, KEY[ch])
    return f


def spans(rows):
    return {(x, y) for y, (x0, x1) in rows.items() for x in range(x0, x1 + 1)}


def is_edge(mask, x, y):
    return any(n not in mask for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))


def net_fill(f, rows, lumps=()):
    """Knotted diamond mesh over a shape: cord rim, 4px lattice, lit from the top
    left; whatever is carried shows through the gaps."""
    mask = spans(rows)
    xs = [x for x, _ in mask]
    ys = [y for _, y in mask]
    for (x, y) in mask:
        t = ((x - min(xs)) / max(1, max(xs) - min(xs)) + (y - min(ys)) / max(1, max(ys) - min(ys))) / 2
        if is_edge(mask, x, y):
            f.put(x, y, G[3] if t < 0.5 else G[4])
        elif (x + y) % 4 == 0 and (x - y) % 4 == 0:
            f.put(x, y, G[0] if t < 0.6 else G[1])
        elif (x + y) % 4 == 0 or (x - y) % 4 == 0:
            f.put(x, y, G[1] if t < 0.4 else G[2] if t < 0.7 else G[3])
        else:
            c = GAP
            for cx, cy, rx, ry, ramp in lumps:
                d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                if d <= 1:
                    c = ramp[0] if (x - cx) + (y - cy) < 0 else ramp[1]
            f.put(x, y, c)


def weave(f, rows, bands=()):
    """Wicker: staggered weavers over upright stakes, shaded round from the left."""
    mask = spans(rows)
    for y, (x0, x1) in rows.items():
        n = x1 - x0 - 1
        for x in range(x0, x1 + 1):
            if is_edge(mask, x, y):
                f.put(x, y, W[4])
                continue
            t = (x - x0 - 0.5) / max(1, n)
            k = 0 if t < 0.22 else 1 if t < 0.62 else 2 if t < 0.88 else 3
            if y in bands:
                k = min(3, k + 1) if (x + y) % 2 else min(3, k + 2)
            elif (x + (y % 2) * 2) % 4 == 3:
                k = min(3, k + 2)
            elif y % 2 and (x + 2) % 4 == 1:
                k = max(0, k - 1) if k else 0
            f.put(x, y, W[k])


def pole(f, x0, y0, x1, y1, width=3):
    """A peeled pole as a slanted run: light, mid and dark pixels across each row."""
    shades = (D[0], D[2], D[4]) if width == 3 else (D[1], D[4])
    for y in range(y0, y1 + 1):
        x = round(x0 + (x1 - x0) * (y - y0) / max(1, y1 - y0))
        for i, c in enumerate(shades):
            f.put(x + i, y, c)
    return f


def bar(f, y, x0, x1):
    """A cross bar three pixels tall with pale cut ends."""
    f.h(y, x0, x1, D[1]); f.h(y + 1, x0, x1, D[2]); f.h(y + 2, x0, x1, D[4])
    for x in (x0, x1):
        f.put(x, y, D[0]); f.put(x, y + 1, D[1])


def lash(f, x, y):
    """Sinew wrapped in a cross over a joint, 3x3 with its top-left at (x, y)."""
    f.pts(L[0], (x, y), (x + 1, y + 1), (x + 2, y + 2), (x + 2, y))
    f.pts(L[1], (x, y + 2))


# ---------------------------------------------------------------- item icons

def net_item():
    f = Frame()
    # waist cord: a short end one side, the long end trailing round the bag
    left = [(13, 10), (12, 10), (11, 9), (10, 9), (9, 10), (8, 11), (7, 11), (6, 12)]
    right = [(18, 10), (19, 10), (20, 9), (21, 9), (22, 10), (23, 11), (24, 12), (25, 13), (26, 14), (26, 15), (26, 16),
             (25, 17), (25, 18), (26, 19), (27, 20)]
    for i, (x, y) in enumerate(left):
        f.put(x, y, G[1] if i % 3 == 0 else G[2])
        f.put(x, y + 1, G[4])
    for i, (x, y) in enumerate(right):
        f.put(x, y, G[1] if i % 3 == 0 else G[2])
        f.put(x + 1, y + 1, G[4])
    f.pts(G[2], (5, 13), (7, 13), (27, 21), (28, 21))
    rows = {12: (13, 18), 13: (12, 19), 14: (11, 20), 15: (10, 21), 16: (9, 22), 17: (9, 22), 18: (8, 23), 19: (8, 23),
            20: (8, 23), 21: (8, 23), 22: (8, 23), 23: (8, 23), 24: (9, 22), 25: (10, 21), 26: (12, 19)}
    net_fill(f, rows, lumps=((13, 21, 3.2, 2.6, ROOT_C), (19, 22, 3.0, 2.4, LEAF), (17, 17, 2.2, 2.0, BERRY), (11, 17, 1.8, 1.8, LEAF)))
    # the mouth gathered and tied shut
    art(f, 12, 6, [
        '.3.23.4.',
        '.323324.',
        '..3224..',
        '..4124..',
        '.412234.',
        '.431124.',
    ])
    return f


def sling_item():
    f = Frame()
    art(f, 5, 3, [
        '.........eeee.........',
        '.......eebbbbee.......',
        '.....eebcddddcbee.....',
        '....ebcdee....eedce...',
        '...ebcde........edce..',
        '...ecde..........edce.',
        '..ebde............ede.',
        '..ecde............ede.',
        '..ede..............ede',
        '..ede..............ede',
        '.eeeeeeeeeeeeeeeeeeeee',
        'eaaabbbbbbbbbbbccccdde',
        'eabbbbbbbbbbbbccccccde',
        'eabbbbbbbbbbbbbccccdde',
        'ebbbbbbbbbbbbbccccccde',
        'eccbbbbbbbbbbccccccdde',
        'effgfgfgfgfgggghghgihe',
        'ejfgfhfgfgTYghghihihje',
        'eajbjbjbbeTYecjcjcjcde',
        'eabbbbbbbbeebcccccccde',
        'eabubbbbbbbbbccccccude',
        'eabbbbbbbbbbbbccccccde',
        'eabubbbbbbbbbccccccude',
        'ebbbbbbbbbbbbbcccccdde',
        '.ebbubbbbbbbcccccudde.',
        '..eecccccccccdddddee..',
        '....eeeeeeeeeeeeee....',
    ])
    return f


def basket_item():
    f = Frame()
    rows = {}
    for y in range(9, 29):
        inset = 0 if y < 15 else 1 if y < 20 else 2 if y < 25 else 3 if y < 28 else 4
        rows[y] = (4 + inset, 19 - inset)
    weave(f, rows, bands=(14, 22, 27))
    # open mouth with a bound rim
    art(f, 4, 4, [
        '...oooooooooo...',
        '.ookkkkkkkkkloo.',
        'okkooXXXXXXoolmo',
        'okoXXXXXXXXXXomo',
        'okkoXXXXXXXXolmo',
        'olkkooooooookllo',
        '.ollkkkkkkllmmo.',
    ])
    f.pts(W[3], (6, 10), (9, 10), (12, 10), (15, 10), (18, 10))
    # tumpline: a hide strap tied under the rim and near the base, lying out in a
    # loop beside the basket with its broad brow band at the far end
    upper = ((20, 12), (21, 12), (22, 13), (23, 13), (24, 14), (25, 15), (26, 16))
    lower = ((26, 24), (25, 25), (24, 26), (23, 26), (22, 26), (21, 25), (20, 24), (19, 23))
    for x, y in upper + lower:
        f.put(x, y, HD[2]); f.put(x, y + 1, HD[4])
    f.pts(HD[1], (20, 12), (22, 13), (24, 14), (24, 26), (22, 26))
    art(f, 25, 16, [
        '.eee.',
        'eabce',
        'eabce',
        'eabde',
        'eabce',
        'eabde',
        'ebbde',
        'ebcde',
        '.eee.',
    ])
    return f


def fur_roll(f, x0, y0, w):
    """A rolled pelt lying across the frame, six pixels tall, tied twice."""
    body = ['f', 'f', 'g', 'h', 'i', 'j']
    for i, ch in enumerate(body):
        a, b = (x0 + 1, x0 + w - 2) if i in (0, 5) else (x0, x0 + w - 1)
        f.h(y0 + i, a, b, KEY[ch])
    for x in range(x0 + 2, x0 + w - 2, 3):
        f.put(x, y0 + 1, FUR[1]); f.put(x + 1, y0 + 3, FUR[1]); f.put(x, y0 + 4, FUR[4])
    for x in (x0, x0 + w - 1):
        f.v(x, y0 + 1, y0 + 4, FUR[4])
    # rolled ends
    f.pts(FUR[1], (x0 + 1, y0 + 2), (x0 + w - 2, y0 + 2)); f.pts(FUR[3], (x0 + 1, y0 + 3), (x0 + w - 2, y0 + 3))
    for x in (x0 + w // 4, x0 + w - 1 - w // 4):
        f.v(x, y0, y0 + 5, L[1]); f.put(x, y0, L[0]); f.put(x, y0 + 1, L[0])


def frame_item():
    f = Frame()
    for x in (8, 21):
        pole(f, x, 2, x, 29)
        f.pts(D[0], (x, 2), (x + 1, 2)); f.put(x + 2, 2, D[3])
        f.pts(D[4], (x, 30), (x + 1, 30))
    bar(f, 5, 6, 25)
    bar(f, 14, 6, 25)
    bar(f, 24, 6, 25)
    fur_roll(f, 6, 8, 20)
    # a hide bundle corded to the lower bars
    art(f, 9, 16, [
        '..eeeeeeeeee..',
        '.eaabbbbbbcde.',
        'eaabbbvbbcccde',
        'eabvbbbvbcvcde',
        'ebbbvbbbvcccde',
        'ebbbbvbvccccde',
        'ebbbbbvccccdde',
        'ecbbbvcvcccdde',
        '.ecccccccddde.',
        '..eeeeeeeeee..',
    ])
    for x in (8, 21):
        for y in (5, 24):
            lash(f, x, y)
    f.pts(L[0], (8, 14), (10, 14), (21, 14), (23, 14))
    return f


def travois(open_):
    f = Frame()
    # two long poles crossed and lashed at the towing end, splayed to drag behind
    pole(f, 13, 0, 3, 30)
    pole(f, 16, 0, 26, 30)
    f.pts(D[0], (13, 0), (14, 0), (16, 0), (17, 0))
    art(f, 12, 2, [
        '.uuvuuv.',
        'uvuuvuuv',
        '.vuuvuv.',
    ])
    # worn drag ends
    f.pts(D[3], (3, 31), (4, 31), (27, 31), (28, 31))

    def edge(y):
        return round(13 + (3 - 13) * y / 30) + 3, round(16 + (26 - 16) * y / 30) - 1

    bar(f, 10, edge(10)[0] - 5, edge(10)[1] + 5)
    bar(f, 25, edge(25)[0] - 5, edge(25)[1] + 5)
    for y in (10, 25):
        lash(f, edge(y)[0] - 3, y); lash(f, edge(y)[1] + 1, y)
    bed = {y: edge(y) for y in range(13, 25)}
    if open_:
        # bare hide bed laced to the poles, the cover pelt rolled up against the top bar
        f.part(bed, HD, 'flat')
        for y in range(14, 24):
            a, b = bed[y]
            for x in range(a + 1, b):
                t = (x - a) / (b - a)
                f.put(x, y, HD[1] if t < 0.3 else HD[2] if t < 0.75 else HD[3])
            if y % 2:
                f.put(a + 1, y, L[0]); f.put(b - 1, y, L[1])
        for x, y in ((13, 17), (17, 19), (14, 21), (19, 16), (11, 20), (18, 22)):
            f.put(x, y, HD[3])
        f.pts(HD[0], (12, 16), (13, 16), (15, 20), (16, 20))
        a, b = edge(12)
        fur_roll(f, a - 2, 8, b - a + 5)
    else:
        # the load heaped under a pelt and corded down
        load = dict(bed)
        a, b = edge(12)
        load.update({7: (a + 2, b - 2), 8: (a, b), 9: (a - 1, b + 1), 10: (a - 2, b + 2), 11: (a - 2, b + 2), 12: (a - 2, b + 2)})
        for y in range(13, 24):
            load[y] = (bed[y][0] - 1, bed[y][1] + 1)
        load[24] = (bed[24][0] + 1, bed[24][1] - 1)
        f.ball(load, HD, 12, 12, r=(3.0, 6.4, 10.5))
        # fur edge of the pelt showing along the top
        for x in range(a + 3, b - 2):
            f.put(x, 8, FUR[0] if x % 2 else FUR[1])
        for x in range(a + 1, b, 2):
            f.put(x, 9, FUR[1])
        # cords pulled over the load, sagging with its curve
        for y0 in (12, 19):
            a2, b2 = load[y0]
            n = b2 - a2
            for i in range(n + 1):
                sag = 0 if i in (0, n) else 1 if i in (1, 2, n - 1, n - 2) else 2
                f.put(a2 + i, y0 + sag, L[0] if i < n * 0.55 else L[1])
                f.put(a2 + i, y0 + sag + 1, HD[3])
    return f


# ---------------------------------------------------------------- worn: carry net (belt)

POUCH = [
    '.343.',
    '32X24',
    '3M2X4',
    '32XS4',
    '4X2X5',
    '.455.',
]


def net_worn(direction):
    f = Frame()
    if direction == 0:
        art(f, 11, 20, ['232323234'])
        art(f, 10, 21, POUCH)
        f.pts(G[1], (12, 20)); f.pts(G[4], (11, 21), (13, 21))
    elif direction == 1:
        art(f, 11, 20, ['232323234'])
        art(f, 16, 21, POUCH)
        f.pts(G[1], (18, 20))
    else:
        art(f, 12, 20, ['23232334'])
        art(f, 13, 21, POUCH)
        f.pts(G[1], (15, 20))
        if direction == 3:
            f = f.mirror()
    return f


# ---------------------------------------------------------------- worn: hide sling bag (back)

def sling_worn(direction):
    f = Frame()
    if direction == 0:
        # strap from the far shoulder down across the chest to the bag on the hip
        for i in range(9):
            x, y = 19 - i, 10 + i
            f.put(x, y, HD[2]); f.put(x + 1, y, HD[3]); f.put(x - 1, y, HD[4] if i > 6 else HD[3])
        art(f, 6, 18, [
            '.eeee.',
            'egfgfe',
            'ejgjhe',
            'eabbce',
            'eabbde',
            'ebbcde',
            '.eeee.',
        ])
    elif direction == 1:
        for i in range(6):
            x, y = 11 + i, 10 + i
            f.put(x, y, HD[2]); f.put(x + 1, y, HD[3]); f.put(x - 1, y, HD[4])
        art(f, 14, 15, [
            '.eeeeeeee.',
            'eaabbbccde',
            'efgfgfghge',
            'ejfhTYhije',
            'eabjTYjcde',
            'eabbeebcde',
            'eabbbbccde',
            'ebbbbcccde',
            '.eeccccde.',
            '..eeeeee..',
        ])
    else:
        # the strap climbs the near side of the chest; the bag rides behind the hip
        for i, (x, y) in enumerate(((13, 15), (14, 14), (15, 13), (16, 12), (17, 11), (17, 10))):
            f.put(x, y, HD[2]); f.put(x - 1, y, HD[4]); f.put(x + 1, y, HD[3])
        art(f, 7, 15, [
            '.eeeeee.',
            'eaabbcde',
            'efgfghge',
            'ejfTYhje',
            'eabeecde',
            'eabbbcde',
            'ebbbccde',
            'ebbcccde',
            '.eeeeee.',
        ])
        if direction == 3:
            f = f.mirror()
    return f


# ---------------------------------------------------------------- worn: pack basket on a tumpline (back)

def basket_worn(direction):
    f = Frame()
    if direction == 0:
        # brow band, and the basket rim showing either side of the neck
        art(f, 11, 4, [
            '.eddddddd.',
            'dabbbbbbcd',
            'e........e',
        ])
        f.pts(HD[4], (11, 4), (20, 4))
        left = ['oooo', 'okkl', 'ollm', 'omn.', 'oo..']
        art(f, 8, 7, left)
        art(f, 20, 7, [row[::-1] for row in left])
        f.pts(W[2], (20, 8), (21, 8)); f.pts(W[3], (20, 9), (21, 9), (22, 10))
    elif direction == 1:
        rows = {}
        for y in range(11, 24):
            inset = 0 if y < 15 else 1 if y < 19 else 2 if y < 22 else 3
            rows[y] = (9 + inset, 22 - inset)
        weave(f, rows, bands=(14, 20))
        art(f, 9, 7, [
            '..oooooooooo..',
            '.okkkkkkkkklo.',
            'okkoXXXXXXolmo',
            'okkkooooookllo',
            '.ollkkkkllmmo.',
        ])
        # tumpline up both sides of the head and over the crown
        art(f, 10, 2, [
            '..eddddddde.',
            '.dbbbbbbbbcd',
            '.dc......cd.',
            'ed........de',
            'ed........de',
        ])
        f.pts(HD[2], (10, 7), (21, 7)); f.pts(HD[4], (9, 7), (22, 7))
    else:
        rows = {}
        for y in range(11, 24):
            inset = 0 if y < 15 else 1 if y < 20 else 2
            rows[y] = (3 + inset, 11 - (1 if y > 20 else 0))
        weave(f, rows, bands=(14, 20))
        art(f, 3, 7, [
            '..ooooo..',
            '.okkkkko.',
            'okoXXXolo',
            'okkoookmo',
            '.olkklmo.',
        ])
        # the tumpline runs from the rim up over the temple to the brow
        for x, y in ((11, 8), (12, 7), (13, 6), (14, 6), (15, 5), (16, 5), (17, 4), (18, 4)):
            f.put(x, y, HD[2]); f.put(x, y - 1, HD[4])
        f.pts(HD[1], (17, 4), (18, 4), (19, 5)); f.put(19, 4, HD[4])
        if direction == 3:
            f = f.mirror()
    return f


# ---------------------------------------------------------------- worn: wooden pack frame (back)

def frame_worn(direction):
    f = Frame()
    if direction == 0:
        # pole tops over the shoulders, the rolled pelt behind the neck, pole feet by the thighs
        for x in (9, 20):
            f.v(x, 3, 10, D[1]); f.v(x + 1, 3, 10, D[4]); f.put(x, 3, D[0])
            f.v(x, 22, 25, D[1]); f.v(x + 1, 22, 25, D[4])
        f.pts(L[0], (9, 5), (20, 5)); f.pts(L[1], (10, 5), (21, 5))
        # shoulder straps
        for x in (12, 18):
            f.v(x, 10, 16, HD[2]); f.put(x, 10, HD[1]); f.put(x, 16, HD[4])
        f.v(13, 11, 15, HD[4]); f.v(17, 11, 15, HD[4])
    elif direction == 1:
        for x in (9, 20):
            pole(f, x, 3, x, 25)
            f.pts(D[0], (x, 3), (x + 1, 3))
        bar(f, 5, 8, 23)
        bar(f, 13, 8, 23)
        bar(f, 21, 8, 23)
        fur_roll(f, 7, 7, 18)
        art(f, 10, 14, [
            '.eeeeeeeeee.',
            'eaabbbvbccde',
            'eabvbbbvcvde',
            'ebbbvbbcvcde',
            'ebbbbvbvccde',
            'ebbbbbvcccde',
            'ecbbbvcvcdde',
            '.eeeeeeeeee.',
        ])
        for x in (9, 20):
            lash(f, x, 5); lash(f, x, 21)
    else:
        # upright pole against the back, the load behind it, one strap round the shoulder
        art(f, 2, 7, [
            '..jjjjj.',
            '.jffgghj',
            'jfgvghij',
            'jghvhiij',
            '.jjjjjj.',
            '.eeeeee.',
            'eaabbcde',
            'eabvbcde',
            'ebbbvcde',
            'ebbvbcde',
            'ebvbccde',
            'ecbbccde',
            '.eeeeee.',
        ])
        pole(f, 9, 3, 9, 25, width=2)
        f.put(9, 3, D[0])
        for y in (5, 13, 21):
            f.h(y, 6, 11, D[1]); f.h(y + 1, 6, 11, D[4]); f.put(6, y, D[0])
            f.pts(L[0], (9, y)); f.pts(L[1], (10, y + 1))
        for x, y in ((11, 11), (12, 10), (13, 10), (14, 10), (15, 11), (16, 12), (16, 13), (16, 14), (15, 15), (14, 16), (13, 16), (12, 16), (11, 16)):
            f.put(x, y, HD[2])
        f.pts(HD[4], (15, 12), (15, 13), (15, 14), (14, 15))
        if direction == 3:
            f = f.mirror()
    return f


WORN = {
    'carry_net': [net_worn(d) for d in range(4)],
    'sling_bag': [sling_worn(d) for d in range(4)],
    'pack_basket': [basket_worn(d) for d in range(4)],
    'pack_frame': [frame_worn(d) for d in range(4)],
}
ITEMS = {
    'carry_net': net_item(),
    'sling_bag': sling_item(),
    'pack_basket': basket_item(),
    'pack_frame': frame_item(),
    'travois': travois(False),
    'travois_open': travois(True),
}


def write_preview(path, scale=6):
    """Review sheet: each piece worn on the base body in four directions, then the item icons."""
    cell = 32 * scale
    rows = list(WORN)
    sheet = Image.new('RGBA', (cell * 6, cell * (len(rows) + 1)), (58, 82, 52, 255))
    for row, state in enumerate(rows):
        for direction in range(4):
            figure = base_body(direction)
            figure.alpha_composite(WORN[state][direction].image())
            sheet.alpha_composite(figure.resize((cell, cell), Image.NEAREST), (direction * cell, row * cell))
    for i, name in enumerate(ITEMS):
        sheet.alpha_composite(ITEMS[name].image().resize((cell, cell), Image.NEAREST), (i * cell, len(rows) * cell))
    sheet.convert('RGB').save(path)


def main():
    write_dmi(ROOT / 'icons/obj/primitive_carrying.dmi', ITEMS, 1)
    write_dmi(ROOT / 'icons/mob/primitive_carrying.dmi', WORN, 4)
    if '--preview' in sys.argv[1:-1]:
        write_preview(sys.argv[sys.argv.index('--preview') + 1])


if __name__ == '__main__':
    main()
