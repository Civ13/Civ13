"""Hand-placed 32px early carrying gear: grass carry net, hide sling bag, pack
basket on a tumpline, wooden pack frame and a travois. Every pixel is placed by
this script from a fixed palette (Pillow only); no external or generated
artwork. Drawing helpers are shared with create_diving_gear.py.

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
G = [(222, 206, 132), (186, 166, 94), (146, 126, 64), (104, 88, 42), (56, 46, 22)]
# raw hide
HD = [(204, 160, 112), (170, 126, 84), (134, 94, 60), (94, 64, 40), (50, 34, 20)]
# fur trim
FUR = [(150, 120, 92), (116, 90, 66), (84, 64, 46), (62, 46, 32), (40, 28, 18)]
# split willow wicker
W = [(226, 190, 118), (194, 152, 84), (154, 114, 58), (108, 78, 38), (58, 40, 18)]
# peeled poles
D = [(176, 132, 86), (142, 102, 62), (108, 76, 44), (74, 50, 28), (42, 28, 14)]
# leather lashings
L = [(120, 80, 46), (86, 56, 30)]


def net_mesh(f, x0, y0, x1, y1):
    """A knotted diamond mesh bag: cord outline, open diagonals inside."""
    rows = {}
    for y in range(y0, y1 + 1):
        inset = 1 if y in (y0, y1) else 0
        if y == y1 - 1:
            inset = 0
        rows[y] = (x0 + inset, x1 - inset)
    for y, (a, b) in rows.items():
        for x in range(a, b + 1):
            edge = x in (a, b) or y in (y0, y1)
            if edge:
                f.put(x, y, G[3])
            elif (x + y) % 3 == 0 or (x - y) % 3 == 0:
                f.put(x, y, G[1] if (x + y) % 2 else G[2])
    # something bulky inside the net
    for y in range(y0 + 2, y1):
        for x in range(x0 + 2, x1 - 1):
            if (x, y) not in f.px:
                f.put(x, y, (96, 120, 64) if y < y1 - 1 else (74, 96, 50))


# ---------------------------------------------------------------- worn: carry net (belt)

def net_worn(direction):
    f = Frame()
    if direction == 0:
        f.h(20, 11, 20, G[2]); f.pts(G[1], (13, 20), (16, 20), (19, 20))
        f.v(11, 20, 21, G[3])
        net_mesh(f, 8, 21, 12, 25)
        f.pts(G[3], (10, 26))
    elif direction == 1:
        f.h(20, 11, 20, G[2]); f.pts(G[1], (12, 20), (15, 20), (18, 20))
        f.v(20, 20, 21, G[3])
        net_mesh(f, 19, 21, 23, 25)
        f.pts(G[3], (21, 26))
    else:
        f.h(20, 12, 19, G[2]); f.pts(G[1], (14, 20), (17, 20))
        net_mesh(f, 13, 21, 17, 25)
        f.pts(G[3], (15, 26))
        if direction == 3:
            f = f.mirror()
    return f


# ---------------------------------------------------------------- worn: hide sling bag (back)

def sling_strap(f, pts, c):
    for x, y in pts:
        f.put(x, y, c)


def hide_bag(f, x0, y0, w, h):
    rows = {y: (x0, x0 + w - 1) for y in range(y0, y0 + h)}
    rows[y0 + h - 1] = (x0 + 1, x0 + w - 2)
    f.part(rows, HD)
    # fur-lined flap folded over the mouth
    f.h(y0, x0, x0 + w - 1, FUR[2])
    f.h(y0 + 1, x0 + 1, x0 + w - 2, FUR[0]); f.h(y0 + 2, x0 + 1, x0 + w - 2, FUR[1])
    for x in range(x0 + 1, x0 + w - 1, 2):
        f.put(x, y0 + 3, FUR[1])
    # toggle
    f.put(x0 + w // 2, y0 + 3, (226, 216, 196))


def sling_worn(direction):
    f = Frame()
    if direction == 0:
        # strap from the left shoulder down across the chest to the right hip
        sling_strap(f, [(19, 11), (19, 12), (18, 13), (17, 14), (16, 15), (15, 16), (14, 17), (13, 18), (12, 19)], HD[3])
        sling_strap(f, [(18, 12), (17, 13), (16, 14), (15, 15), (14, 16), (13, 17), (12, 18)], HD[2])
        f.part({20: (9, 12), 21: (9, 12), 22: (9, 12), 23: (10, 12)}, HD)
        f.pts(FUR[0], (10, 20), (11, 20))
    elif direction == 1:
        sling_strap(f, [(12, 11), (12, 12), (13, 13), (14, 14), (15, 15), (16, 16)], HD[3])
        sling_strap(f, [(13, 12), (14, 13), (15, 14), (16, 15)], HD[2])
        hide_bag(f, 15, 15, 8, 8)
    else:
        f.v(13, 11, 13, HD[3]); f.pts(HD[2], (12, 13), (11, 14))
        hide_bag(f, 7, 14, 6, 8)
        if direction == 3:
            f = f.mirror()
    return f


# ---------------------------------------------------------------- worn: pack basket on a tumpline (back)

def basket(f, x0, y0, w, h, rim=True):
    """Tapered wicker basket: wide mouth at y0, narrowing to the base."""
    rows = {}
    for i in range(h):
        taper = 0 if i < h // 2 else (1 if i < h - 2 else 2)
        rows[y0 + i] = (x0 + taper, x0 + w - 1 - taper)
    mask = f.part(rows, W)
    for (x, y) in mask:
        if f.px[(x, y)] == W[4]:
            continue
        # over-under weave: alternate dark stakes every third column, offset per row
        if (x + (y // 2)) % 3 == 0:
            f.put(x, y, W[3] if f.px[(x, y)] in (W[2], W[3]) else W[2])
    if rim:
        f.h(y0, x0, x0 + w - 1, W[4])
        f.h(y0 + 1, x0, x0 + w - 1, W[1])
        f.put(x0, y0 + 1, W[4]); f.put(x0 + w - 1, y0 + 1, W[4])
    return mask


def basket_worn(direction):
    f = Frame()
    if direction == 0:
        # tumpline band across the forehead, rim peeking over both shoulders
        f.h(5, 13, 18, HD[2]); f.pts(HD[1], (14, 5), (15, 5)); f.pts(HD[3], (12, 6), (19, 6))
        f.pts(HD[3], (12, 7), (19, 7))
        f.part({8: (9, 11), 9: (9, 11), 10: (9, 11), 11: (9, 10)}, W, 'flat')
        f.part({8: (20, 22), 9: (20, 22), 10: (20, 22), 11: (21, 22)}, W, 'flat')
        f.h(8, 9, 11, W[4]); f.h(8, 20, 22, W[4])
    elif direction == 1:
        basket(f, 10, 8, 12, 15)
        # tumpline running up from the rim to the forehead
        f.v(12, 5, 8, HD[3]); f.v(19, 5, 8, HD[3]); f.h(5, 13, 18, HD[2])
        f.h(4, 13, 18, HD[3])
    else:
        basket(f, 4, 8, 8, 15)
        f.pts(HD[3], (11, 8), (12, 7), (13, 6), (14, 5)); f.pts(HD[2], (12, 8), (13, 7), (14, 6), (15, 5))
        f.h(4, 15, 18, HD[3]); f.h(5, 16, 18, HD[2])
        if direction == 3:
            f = f.mirror()
    return f


# ---------------------------------------------------------------- worn: wooden pack frame (back)

def bedroll(f, x0, y0, w, h):
    rows = {y: (x0, x0 + w - 1) for y in range(y0, y0 + h)}
    rows[y0] = (x0 + 1, x0 + w - 2); rows[y0 + h - 1] = (x0 + 1, x0 + w - 2)
    f.part(rows, HD, 'lr')


def frame_worn(direction):
    f = Frame()
    if direction == 0:
        # pole ends above the shoulders, shoulder straps, waist cord
        for x in (10, 21):
            f.v(x, 4, 11, D[3]); f.put(x, 4, D[4])
        f.v(11, 4, 11, D[1]); f.v(20, 4, 11, D[1])
        f.h(6, 10, 11, L[1]); f.h(6, 20, 21, L[1])
        f.v(12, 12, 16, L[1]); f.v(19, 12, 16, L[1])
        f.pts(L[0], (12, 13), (19, 13))
    elif direction == 1:
        for x in (10, 21):
            f.v(x, 3, 23, D[4])
        f.v(11, 3, 23, D[1]); f.v(20, 3, 23, D[2])
        for y in (5, 13, 21):
            f.h(y, 10, 21, D[3]); f.h(y - 1, 12, 19, D[1])
        bedroll(f, 12, 6, 8, 6)
        bedroll(f, 11, 14, 10, 6)
        for y in (8, 17):
            f.h(y, 11, 20, L[1])
        f.pts(L[0], (14, 8), (17, 17))
    else:
        f.v(10, 3, 23, D[4]); f.v(9, 3, 23, D[1]); f.v(8, 3, 23, D[3])
        for y in (5, 13, 21):
            f.h(y, 5, 10, D[3])
        bedroll(f, 4, 6, 5, 6)
        bedroll(f, 3, 14, 6, 6)
        f.h(8, 3, 9, L[1]); f.h(17, 3, 9, L[1])
        f.pts(L[1], (11, 12), (12, 12))
        if direction == 3:
            f = f.mirror()
    return f


# ---------------------------------------------------------------- item icons

def net_item():
    f = Frame()
    f.pts(G[3], (15, 7), (16, 7), (14, 8), (17, 8), (15, 9), (16, 9))
    f.v(15, 10, 11, G[3]); f.v(16, 10, 11, G[2])
    net_mesh(f, 9, 12, 22, 25)
    return f


def sling_item():
    f = Frame()
    # carrying strap loop
    for x, y in ((11, 13), (11, 12), (12, 10), (12, 11), (13, 9), (14, 8), (15, 8), (16, 8), (17, 8), (18, 9), (19, 10), (19, 11), (20, 12), (20, 13)):
        f.put(x, y, HD[3])
    for x, y in ((13, 10), (14, 9), (17, 9), (18, 10)):
        f.put(x, y, HD[2])
    hide_bag(f, 9, 13, 14, 12)
    return f


def basket_item():
    f = Frame()
    basket(f, 9, 10, 14, 16)
    # tumpline lying looped over the top
    f.pts(HD[3], (10, 9), (11, 8), (12, 7), (13, 6), (18, 6), (19, 7), (20, 8), (21, 9))
    f.h(5, 13, 18, HD[2]); f.h(6, 14, 17, HD[1])
    return f


def frame_item():
    return frame_worn(1).shift(0, 2)


# ---------------------------------------------------------------- travois (dragged structure)

def travois(open_):
    f = Frame()
    # two long poles, crossed and lashed near the top, spreading to drag on the ground
    left = [(12 - (y - 4) // 3, y) for y in range(4, 31)]
    right = [(19 + (y - 4) // 3, y) for y in range(4, 31)]
    for x, y in left:
        f.put(x, y, D[4]); f.put(x + 1, y, D[1])
    for x, y in right:
        f.put(x, y, D[2]); f.put(x - 1, y, D[1]); f.put(x + 1, y, D[4])
    f.h(2, 14, 17, D[3]); f.pts(D[1], (13, 3), (18, 3)); f.pts(D[4], (12, 2), (19, 2))
    f.h(4, 13, 18, L[1]); f.h(5, 13, 18, L[0])
    # cross bars carrying the platform
    for y in (13, 24):
        a = 12 - (y - 4) // 3
        b = 19 + (y - 4) // 3
        f.h(y, a, b, D[3]); f.h(y - 1, a + 2, b - 2, D[1])
    # hide platform lashed between the bars
    a0, b0 = 12 - (14 - 4) // 3 + 2, 19 + (14 - 4) // 3 - 2
    rows = {}
    for y in range(14, 24):
        a = 12 - (y - 4) // 3 + 2
        b = 19 + (y - 4) // 3 - 2
        rows[y] = (a, b)
    if open_:
        f.part(rows, HD, 'flat')
        for y in range(15, 23, 2):
            f.h(y, rows[y][0] + 1, rows[y][1] - 1, HD[2])
        # the cover hide rolled back onto the top bar
        f.part({10: (a0, b0), 11: (a0, b0)}, FUR, 'flat')
        f.h(10, a0, b0, FUR[2])
    else:
        # covered load: bundles under a lashed hide
        load = {y: (rows[y][0], rows[y][1]) for y in range(14, 24)}
        load[11] = (a0 + 2, b0 - 2); load[12] = (a0 + 1, b0 - 1); load[13] = (a0, b0)
        f.part(load, HD, 'lr')
        for y in (14, 19):
            f.h(y, load[y][0], load[y][1], L[1])
        f.pts(FUR[0], (a0 + 3, 12), (a0 + 4, 12), (b0 - 3, 15))
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
