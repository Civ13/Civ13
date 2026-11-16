"""Hand-placed 32px sprites for the mouse rework in icons/obj/mouse_nests.dmi:
the field mouse burrow, the three stages of a house mouse nest, the gnawed
overlay for fouled food, the snap mousetrap (set, sprung, with a catch), the
poison bait and the baited deadfall. Every pixel is placed by this script
from a fixed palette (Pillow only); no external or generated artwork.

It reuses the frame helpers and the outline, wood, stone and earth colours of
create_stone_age_traps.py, so the deadfall here is that script's own set
deadfall with a morsel tied on, and the mouse greys are the ones of
mouse_gray in icons/mob/animal.dmi. Everything sits low in the tile, bottom
centre, on a transparent background, lit from the upper left.

Run with Pillow to reproduce the sheet. `--check` verifies the committed
sheet, `--preview <png>` writes a labelled 4x review sheet with every state
on the game's grass, dirt and wooden floor tiles (and at 1x underneath).
Released under Civ13 AGPL-3.0.
"""
import math
import re
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_stone_age_traps import (Frame, OUT, WD, PW, ER, PD, CD, ST, noise, bar,  # noqa: E402
                                    deadfall_set)

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/mouse_nests.dmi'

# shredded straw: highlight, light, mid, shade
STRAW = [(236, 214, 150), (212, 182, 110), (172, 140, 76), (124, 98, 54)]
# shredded cloth: faded blue and a dull madder red, light and dark of each
RAG = [(150, 160, 172), (104, 114, 132), (168, 104, 92), (122, 70, 64)]
# droppings: body, dark end and the glint that lifts them off a dark floor
DROP = [(46, 33, 25), (24, 17, 14), (112, 90, 70)]
# seed husk: pale shell, shade, the empty dark inside
HUSK = [(232, 212, 164), (178, 148, 100), (70, 50, 34)]
# the grey mouse of icons/mob/animal.dmi, plus its ear, nose and tail pink
MOUSE = [(134, 134, 134), (116, 116, 116), (88, 88, 88), (61, 61, 61)]
PINK = [(216, 171, 166), (153, 101, 87)]
# iron wire and spring
IRON = [(214, 216, 220), (160, 164, 172), (104, 108, 118), (66, 68, 78)]
CHEESE = [(244, 214, 110), (214, 170, 62), (160, 118, 40)]
# fired clay shard
POT = [(204, 132, 94), (172, 100, 70), (130, 72, 52), (92, 50, 40)]
# grain and the sickly green of the poison on it
GRAIN = [(236, 208, 132), (204, 168, 92), (150, 116, 60)]
BANE = [(176, 206, 104), (128, 164, 78), (88, 122, 62)]
# raw meat for the deadfall morsel
MEAT = [(236, 150, 128), (200, 88, 74), (146, 54, 52)]
SHADE = (20, 16, 12)


def ground_shadow(f, a=90):
    """A soft dark line under every drawn pixel that has nothing below it."""
    for (x, y) in list(f.px):
        if (x, y + 1) not in f.px:
            f.put(x, y + 1, SHADE, a)


def hole(f, cx, cy, rx, ry):
    """The dark mouth of a hole: blackest under the far lip."""
    for y in range(32):
        for x in range(32):
            u, v = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if u * u + v * v <= 1.0:
                f.put(x, y, PD[2] if v < 0.1 else PD[1] if v < 0.62 else PD[0])


def dropping(f, x, y, lie=0):
    """One pellet, two pixels long; `lie` 0 flat, 1 falling right, 2 rising."""
    dy = (0, 1, -1)[lie % 3]
    f.put(x, y, DROP[0])
    f.put(x + 1, y + dy, DROP[1])
    if (x, y - 1) not in f.px:
        f.put(x, y - 1, DROP[2], 150)                  # a glint on its back


def wisp(f, x, y, dx, dy, n, tone=1):
    """One strand of straw, n pixels long, stepping (dx, dy)."""
    for i in range(n):
        px, py = int(round(x + dx * i)), int(round(y + dy * i))
        f.put(px, py, STRAW[tone if i else max(0, tone - 1)])


def husk(f, x, y, flip=False):
    """A split seed husk: a pale shell with its dark emptied middle."""
    s = -1 if flip else 1
    f.put(x, y, HUSK[0]); f.put(x + s, y, HUSK[2]); f.put(x + 2 * s, y, HUSK[0])
    f.put(x, y + 1, HUSK[1]); f.put(x + s, y + 1, HUSK[1]); f.put(x + 2 * s, y - 1, HUSK[1])


def gnaw(f, x, y, steep=False):
    """Paired tooth marks: two short pale scores with the dark cut beside."""
    for k in range(2):
        for i in range(3):
            px, py = (x + k * 2 + (i if not steep else 0), y - i) if not steep else (x + k * 2 + i // 2, y - i)
            f.put(px, py, PW[0] if i < 2 else PW[1])
            f.put(px + 1, py, OUT, 200)


def straw_heap(f, cx, cy, rx, ry, seed, rags=False):
    """A wad of shredded straw: short strands lying every way, darker low
    down and at the skirts, with a ragged edge."""
    for y in range(32):
        for x in range(32):
            u, v = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            r = u * u + v * v + (noise(x, y, seed) - 0.5) * 0.5
            if r > 1.0:
                continue
            # strands: bands a pixel wide whose slant changes patch by patch
            patch = int(noise(x // 4, y // 3, seed + 1) * 3)
            band = (x + y, x - y, y * 2 + x // 3)[patch]
            n = noise(band, patch, seed + 2)
            tone = 0 if n > 0.82 else 1 if n > 0.42 else 2
            if v > 0.35 or u > 0.55:
                tone = min(3, tone + 1)
            if u + v < -0.75:
                tone = max(0, tone - 1)
            c = STRAW[tone]
            if rags:
                n2 = noise(x // 3, y // 2, seed + 3)
                if n2 > 0.86:
                    c = RAG[0] if tone < 2 else RAG[1]
                elif n2 < 0.1:
                    c = RAG[2] if tone < 2 else RAG[3]
            f.put(x, y, c)


def edge(f, a=255):
    """The dark outline, as the trap sprites wear it."""
    f.outline(OUT, a)


# ------------------------------------------------------------------ burrow

def burrow():
    """A field mouse hole: a dark mouth in a low ring of kicked-out earth,
    the spoil fanned out to the lower right."""
    f = Frame()
    cx, cy = 15.5, 25.5
    for y in range(32):
        for x in range(32):
            u, v = (x + 0.5 - cx) / 6.6, (y + 0.5 - cy) / 4.0
            # the fan of spoil pulls the ring out to the lower right
            fan = max(0.0, (u * 0.7 + v * 0.7)) * 0.32
            r = u * u + v * v - fan + (noise(x, y, 61) - 0.5) * 0.34
            if r > 1.0:
                if r < 1.35 and noise(x, y, 62) > 0.84:
                    f.put(x, y, ER[2], 190)                    # loose crumbs
                continue
            lit = u + v
            c = ER[0] if lit < -0.75 else ER[1] if lit < 0.25 else ER[2]
            n = noise(x, y, 63)
            if n > 0.84:
                c = ER[min(3, ER.index(c) + 1)]
            elif n < 0.14:
                c = ER[max(0, ER.index(c) - 1)]
            if r > 0.72 and lit > 0.2:
                c = ER[3]
            f.put(x, y, c)
    solid = Frame()
    solid.px = {k: v for k, v in f.px.items() if v[3] == 255}
    ground_shadow(solid, 120)
    for k, v in solid.px.items():
        f.px.setdefault(k, v) if v[:3] == SHADE else None
    hole(f, cx, cy - 0.3, 3.6, 2.1)
    f.pts(OUT, (12, 24), (13, 23), (14, 23), (15, 23), (16, 23), (17, 23), (18, 24))   # the far lip overhangs
    f.pts(ER[0], (13, 22), (14, 22), (16, 22))
    f.pts(ER[0], (14, 27), (15, 27)); f.pts(ER[1], (16, 27), (17, 27))                  # the worn near lip
    return f


# -------------------------------------------------------------------- nests

def nest_hole(f):
    """The gnawed way in: a small dark hole with pale chewed splinters."""
    h = Frame()
    hole(h, 15.5, 26.0, 3.2, 2.2)
    h.outline(OUT)
    f.over(h)
    f.pts(PW[0], (12, 24), (19, 25), (14, 23)); f.pts(PW[1], (18, 24), (12, 27), (19, 27))


def nest_light():
    """A new house mouse nest: the hole, a few wisps of straw, three
    droppings."""
    f = Frame()
    wisp(f, 8, 26, 1, -0.5, 4, 1); wisp(f, 9, 28, 1, 0, 4, 2)
    wisp(f, 20, 23, 1, 0.5, 4, 1); wisp(f, 20, 28, 1, -0.34, 4, 1)
    wisp(f, 17, 22, 0.5, -1, 3, 2); wisp(f, 11, 23, 1, 0.5, 3, 1)
    ground_shadow(f, 80)
    nest_hole(f)
    dropping(f, 23, 26, 1); dropping(f, 6, 24, 0); dropping(f, 10, 30, 2)
    return f


def nest_used():
    """A used nest: a crescent of straw packed round the hole, more
    droppings, two emptied seed husks."""
    f = Frame()
    w = Frame()
    straw_heap(w, 15.5, 25.0, 8.2, 4.6, 71)
    for k in [k for k in w.px if k[1] >= 28 and 12 <= k[0] <= 19]:
        del w.px[k]                                    # open at the front
    edge(w)
    f.over(w)
    wisp(f, 4, 25, 1, -0.5, 3, 1); wisp(f, 25, 23, 1, 0.34, 3, 1); wisp(f, 23, 29, 1, 0, 3, 2)
    wisp(f, 6, 28, 1, 0.5, 3, 2)
    nest_hole(f)
    for x, y, lie in ((26, 26, 1), (3, 22, 0), (10, 30, 2), (20, 30, 0), (27, 20, 2), (7, 19, 1)):
        dropping(f, x, y, lie)
    husk(f, 14, 30); husk(f, 28, 29, True)
    return f


def nest_overrun():
    """An overrun nest: a big messy heap of straw and shredded cloth, the
    hole trodden wide, droppings everywhere, gnaw marks round it."""
    f = Frame()
    w = Frame()
    straw_heap(w, 15.5, 22.5, 12.6, 7.4, 81, rags=True)
    straw_heap(w, 9.5, 17.5, 5.5, 3.6, 82, rags=True)                 # it has spread up one side
    straw_heap(w, 23.5, 26.5, 5.0, 3.0, 83)
    for k in [k for k in w.px if k[1] >= 27 and 12 <= k[0] <= 19]:
        del w.px[k]
    edge(w)
    f.over(w)
    # loose strands and a torn rag thrown clear
    wisp(f, 1, 22, 1, -0.5, 3, 1); wisp(f, 27, 15, 1, 0.5, 3, 1); wisp(f, 20, 12, 1, -0.5, 3, 2)
    wisp(f, 2, 28, 1, 0.34, 4, 2); wisp(f, 26, 30, 1, 0, 3, 1); wisp(f, 4, 13, 0.5, -1, 3, 1)
    f.pts(RAG[0], (25, 11), (26, 11), (26, 12)); f.pts(RAG[1], (27, 12), (25, 12))
    f.pts(RAG[2], (3, 17), (4, 17)); f.pts(RAG[3], (4, 18), (5, 18))
    h = Frame()
    hole(h, 15.5, 25.0, 4.2, 2.7)
    h.outline(OUT)
    f.over(h)
    f.pts(PW[0], (11, 23), (20, 24), (13, 22), (18, 22)); f.pts(PW[1], (11, 27), (20, 27))
    for x, y, lie in ((27, 22, 1), (1, 25, 0), (9, 29, 2), (21, 29, 0), (29, 18, 2), (5, 30, 1), (24, 13, 0),
                      (13, 11, 1), (29, 27, 0), (1, 16, 2), (17, 30, 1), (8, 12, 0), (13, 18, 0), (21, 20, 1),
                      (18, 16, 2)):
        dropping(f, x, y, lie)
    husk(f, 12, 30); husk(f, 25, 30, True); husk(f, 29, 23, True); husk(f, 17, 10)
    gnaw(f, 1, 10); gnaw(f, 27, 8, True); gnaw(f, 28, 31)
    return f


# ------------------------------------------------------------------- gnawed

def gnawed():
    """Overlay for a fouled food item: three small scalloped bites with pale tooth
    scores and crumbs, and two droppings, kept to the lower right corner."""
    f = Frame()
    bites = ((22.5, 21.5, 1.6), (20.5, 24.0, 1.5), (25.0, 19.5, 1.2))
    for cx, cy, r in bites:
        for y in range(32):
            for x in range(32):
                d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                if d <= r:
                    f.put(x, y, PD[0] if x + y < cx + cy else PD[1])
    f.outline(OUT, 210)
    # the pale scores the teeth leave on the upper-left rim of each bite
    f.pts(HUSK[0], (20, 20), (21, 19), (18, 23), (23, 18)); f.pts(HUSK[1], (19, 22), (24, 17))
    f.pts(HUSK[0], (25, 23)); f.pts(HUSK[1], (23, 26))                                  # crumbs
    dropping(f, 26, 25, 1); dropping(f, 20, 27, 0)
    return f


# ---------------------------------------------------------------- mousetrap

def trap_base(f):
    """The wooden base, 12 by 6, seen from above with its front edge."""
    for y in range(22, 28):
        for x in range(10, 22):
            c = WD[0] if y == 22 else WD[1]
            if noise(x // 3, y, 91) > 0.8 and y > 22:
                c = WD[2]                               # grain
            f.put(x, y, c)
    for x in range(10, 22):
        f.put(x, 28, WD[3])                             # its thickness
    f.pts(WD[0], (10, 23), (10, 24))


def spring(f):
    """The coil across the middle of the base."""
    for y in range(22, 28):
        f.put(15, y, IRON[1] if y % 2 else IRON[3])
        f.put(16, y, IRON[0] if y % 2 else IRON[2])


def snap_bar(f, x0, x1):
    """The square wire bar lying on the base between columns x0 and x1."""
    for x in range(min(x0, x1), max(x0, x1) + 1):
        f.put(x, 22, IRON[0]); f.put(x, 27, IRON[2])
    far = x0
    for y in range(22, 28):
        f.put(far, y, IRON[0] if y < 25 else IRON[1])
    f.put(far, 27, IRON[2])


def mousetrap():
    """Set: the bar held back over the left half by the catch rod, a crumb of
    cheese on the pedal at the right."""
    f = Frame()
    trap_base(f)
    edge(f)
    snap_bar(f, 11, 15)
    spring(f)
    f.pts(IRON[3], (12, 25), (13, 25), (14, 24), (17, 24))          # catch rod over the bar to the pedal
    f.pts(IRON[1], (12, 24), (13, 24))
    f.pts(WD[3], (18, 23), (20, 23), (18, 26), (19, 26), (20, 26), (17, 25), (17, 26))   # the pedal's shadow
    f.pts(WD[2], (18, 25), (20, 25), (20, 24))
    f.pts(CHEESE[0], (18, 24), (19, 23)); f.pts(CHEESE[1], (19, 24)); f.pts(CHEESE[2], (19, 25))
    return f


def sprung_parts(f):
    snap_bar(f, 20, 16)
    spring(f)
    # the catch rod thrown up and back, clear of the base
    f.pts(IRON[1], (11, 21), (10, 20), (9, 19), (8, 18)); f.pts(IRON[0], (8, 17))
    f.pts(IRON[3], (12, 22))
    f.pts(OUT, (9, 20), (8, 19), (7, 18), (7, 17), (8, 16), (9, 17), (9, 18), (10, 19), (11, 20), (10, 21))


def mousetrap_sprung():
    """Sprung on nothing: the bar slapped down over the right half, the
    pedal bare, the catch rod thrown back."""
    f = Frame()
    trap_base(f)
    edge(f)
    f.pts(WD[3], (18, 24), (19, 24), (18, 25)); f.pts(WD[2], (17, 24), (19, 25))        # the empty pedal
    f.pts(CHEESE[1], (23, 26))                                                           # a crumb knocked off
    f.pts(OUT, (23, 27))
    sprung_parts(f)
    return f


def mousetrap_caught():
    """Sprung on a grey mouse: its head pinned on the pedal under the bar,
    the body and tail lying off the right end of the base."""
    f = Frame()
    trap_base(f)
    edge(f)
    m = Frame()
    # head on the base, nose toward the spring
    m.pts(MOUSE[1], (18, 24), (19, 24), (18, 25), (19, 25)); m.pts(MOUSE[2], (18, 26), (19, 26))
    m.pts(PINK[0], (17, 25))                                                             # nose
    # body hanging off the end of the base
    for y in range(22, 28):
        for x in range(20, 28):
            u, v = (x + 0.5 - 23.6) / 4.2, (y + 0.5 - 24.9) / 2.9
            if u * u + v * v <= 1.0:
                m.put(x, y, MOUSE[0] if v < -0.45 and u < 0.4 else MOUSE[1] if v < 0.35 else MOUSE[2])
    m.pts(PINK[0], (21, 22)); m.pts(PINK[1], (22, 22))                                   # the ear, folded back
    m.pts(MOUSE[3], (22, 27), (25, 27)); m.pts(PINK[0], (23, 28), (26, 28))              # feet turned up
    edge_px = set(m.px)
    for (x, y) in edge_px:
        for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if n not in m.px and not (10 <= n[0] <= 21 and 22 <= n[1] <= 27):
                m.put(n[0], n[1], MOUSE[3])                                             # the mouse's own dark edge
    f.over(m)
    f.pts(MOUSE[3], (28, 26), (29, 27), (30, 27), (30, 26), (31, 25))                    # tail
    f.pts(OUT, (18, 23))                                                                 # the shut eye
    sprung_parts(f)
    f.put(20, 22, IRON[0]); f.put(20, 27, IRON[2])
    return f


# -------------------------------------------------------------- poison bait

def poison_bait():
    """A little heap of grain on a potsherd, some of it tinged sickly green."""
    f = Frame()
    # the shard: a curved, broken-edged piece of a fired clay pot
    rows = {23: (12, 19), 24: (10, 21), 25: (9, 22), 26: (9, 22), 27: (10, 21), 28: (12, 20)}
    for y, (x0, x1) in rows.items():
        for x in range(x0, x1 + 1):
            c = POT[0] if y <= 24 and x < 17 else POT[1] if y <= 26 else POT[2]
            if y == 28:
                c = POT[3]
            f.put(x, y, c)
    f.pts(POT[2], (21, 25), (22, 26), (19, 23)); f.pts(POT[0], (9, 25))
    for k in ((22, 25), (10, 27)):
        f.px.pop(k, None)                                                               # chipped corners
    edge(f)
    # the grain heap
    g = Frame()
    for y in range(19, 27):
        for x in range(11, 21):
            u, v = (x + 0.5 - 15.6) / 4.4, (y + 0.5 - 23.4) / 3.0
            if u * u + v * v + (noise(x, y, 95) - 0.5) * 0.3 <= 1.0:
                n = noise(x, y, 96)
                c = GRAIN[0] if (u + v < -0.3 and n > 0.3) or n > 0.9 else GRAIN[1] if n > 0.28 else GRAIN[2]
                if v > 0.45:
                    c = GRAIN[2] if n < 0.6 else GRAIN[1]
                t = noise(x, y, 97)
                if t > 0.7:
                    c = BANE[0] if c == GRAIN[0] else BANE[1] if c == GRAIN[1] else BANE[2]
                g.put(x, y, c)
    g.outline(GRAIN[2])
    for k, v in list(g.px.items()):
        if v[:3] == GRAIN[2] and k not in f.px:
            g.px[k] = OUT + (255,)                                                      # dark where it overhangs
    f.over(g)
    f.pts(GRAIN[0], (21, 26), (11, 27)); f.pts(BANE[1], (20, 27), (24, 28)); f.pts(GRAIN[1], (7, 28))
    f.pts(BANE[0], (14, 20), (17, 21), (13, 23))
    return f


# ---------------------------------------------------------- baited deadfall

def deadfall_baited():
    """The set deadfall of stone_age_traps.dmi with a morsel of meat tied on
    the end of the bait stick, under the propped stone."""
    f = deadfall_set()
    m = Frame()
    m.pts(MEAT[1], (9, 22), (10, 22), (11, 22), (9, 23), (10, 23), (11, 23), (10, 24), (11, 24), (12, 23))
    m.pts(MEAT[0], (9, 22), (10, 22), (10, 23)); m.pts(MEAT[2], (11, 24), (12, 23), (11, 23))
    m.outline(OUT)
    f.over(m)
    f.pts(CD[0], (12, 22)); f.pts(CD[1], (13, 22), (13, 23))                             # the twine that ties it
    return f


def states():
    """{state: Frame} in sheet order."""
    return {
        'burrow': burrow(),
        'nest_light': nest_light(),
        'nest_used': nest_used(),
        'nest_overrun': nest_overrun(),
        'gnawed': gnawed(),
        'mousetrap': mousetrap(),
        'mousetrap_sprung': mousetrap_sprung(),
        'mousetrap_caught': mousetrap_caught(),
        'poison_bait': poison_bait(),
        'deadfall_baited': deadfall_baited(),
    }


COLUMNS = 4


def build():
    st = states()
    rows = -(-len(st) // COLUMNS)
    sheet = Image.new('RGBA', (32 * COLUMNS, 32 * rows), (0, 0, 0, 0))
    for i, fr in enumerate(st.values()):
        sheet.paste(fr.image(), (i % COLUMNS * 32, i // COLUMNS * 32))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name in st:
        text += 'state = "%s"\n\tdirs = 1\n\tframes = 1\n' % name
    text += '# END DMI\n'
    return sheet, text


def write_dmi():
    sheet, text = build()
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(SHEET, format='PNG', pnginfo=meta, optimize=True)


def check():
    sheet, text = build()
    old = Image.open(SHEET)
    return old.info.get('Description') == text and old.convert('RGBA').tobytes() == sheet.tobytes()


# ------------------------------------------------------------------ review

def game_tile(sheet, state):
    """The first frame of `state` in one of the game's 32px icon sheets."""
    im = Image.open(ROOT / sheet)
    text = im.info['Description']
    im = im.convert('RGBA')
    cols, at = im.width // 32, 0
    for block in re.split(r'(?m)^(?=state = )', text.split('# END DMI')[0])[1:]:
        if re.match(r'state = "([^"]*)"', block).group(1) == state:
            x, y = at % cols * 32, at // cols * 32
            return im.crop((x, y, x + 32, y + 32))
        at += int(re.search(r'\tdirs = (\d+)', block).group(1)) * int(re.search(r'\tframes = (\d+)', block).group(1))
    raise KeyError(state)


def write_preview(path, scale=4, per_row=5):
    """Every state at 4x on grass, dirt and a wooden floor, labelled, with
    the same three at 1x underneath; then the gnawed overlay on real food
    and the baited deadfall beside the plain one."""
    floors = [('grass', game_tile('icons/turf/floors.dmi', 'grass1')),
              ('dirt', game_tile('icons/turf/floors.dmi', 'dirt')),
              ('wood floor', game_tile('icons/turf/floors.dmi', 'wood'))]
    st = states()
    cell, gap, pad, label = 32 * scale, 4, 12, 16
    box_w = pad * 2 + len(floors) * cell + (len(floors) - 1) * gap
    box_h = pad + label + cell + 14 + 6 + 32 + pad
    rows = -(-len(st) // per_row)
    extra_h = label + cell + pad * 2 + 14
    dark = (30, 32, 36, 255)
    sheet = Image.new('RGBA', (box_w * per_row, box_h * rows + extra_h), dark)
    draw = ImageDraw.Draw(sheet)

    def shot(tile, sprites, x, y, big=True):
        t = tile.copy()
        for s in sprites:
            t.alpha_composite(s)
        sheet.alpha_composite(t.resize((cell, cell), Image.NEAREST) if big else t, (x, y))

    for i, (name, fr) in enumerate(st.items()):
        ox, oy = i % per_row * box_w + pad, i // per_row * box_h + pad
        draw.text((ox, oy), name, fill=(236, 230, 214))
        for j, (kind, tile) in enumerate(floors):
            x = ox + j * (cell + gap)
            shot(tile, [fr.image()], x, oy + label)
            draw.text((x, oy + label + cell + 2), kind, fill=(150, 150, 140))
            shot(tile, [fr.image()], ox + j * (32 + gap), oy + label + cell + 20, big=False)
        draw.text((ox + 3 * (32 + gap) + 4, oy + label + cell + 30), '1x', fill=(150, 150, 140))
    # comparisons along the bottom
    oy = box_h * rows + pad
    grass, wood = floors[0][1], floors[2][1]
    x = pad
    draw.text((x, oy), 'gnawed overlay on food (clean | fouled)', fill=(236, 230, 214))
    for food in ('bread', 'cheesewedge', 'wheat'):
        item = game_tile('icons/obj/food/food.dmi', food)
        shot(wood, [item], x, oy + label)
        shot(wood, [item, st['gnawed'].image()], x + cell + gap, oy + label)
        draw.text((x, oy + label + cell + 2), food, fill=(150, 150, 140))
        x += 2 * (cell + gap) + pad
    draw.text((x, oy), 'deadfall_set (existing) | deadfall_baited | mouse beside burrow, trap', fill=(236, 230, 214))
    shot(grass, [game_tile('icons/obj/stone_age_traps.dmi', 'deadfall_set')], x, oy + label)
    shot(grass, [st['deadfall_baited'].image()], x + cell + gap, oy + label)
    mouse = game_tile('icons/mob/animal.dmi', 'mouse_gray')
    up = Image.new('RGBA', (32, 32))
    up.alpha_composite(mouse, (0, -12))
    shot(grass, [st['burrow'].image(), up], x + 2 * (cell + gap), oy + label)
    shot(wood, [st['mousetrap'].image(), up], x + 3 * (cell + gap), oy + label)
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.convert('RGB').save(path)


if __name__ == '__main__':
    if '--check' in sys.argv:
        if not check():
            sys.exit('stale sheet: ' + str(SHEET))
        print('mouse nest states match')
    else:
        write_dmi()
    if '--preview' in sys.argv:
        write_preview(sys.argv[sys.argv.index('--preview') + 1])
