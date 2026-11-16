"""Hand-placed 32px beekeeping gear: the beekeeper's veil (a broad straw hat
with a dark gauze veil hanging all round to the shoulders) and the beekeeper
suit (a loose one-piece off-white cotton coverall, gathered with elastic at
the wrists and ankles; gloves are not part of it). Every pixel is placed by
this script from fixed palettes (Pillow only); no external or generated
artwork.

Run with Pillow to reproduce
  icons/obj/clothing/bee_gear.dmi          item icons
  icons/mob/bee_gear.dmi                   worn, four directions
  icons/mob/items/lefthand_bee_gear.dmi    held, four directions
  icons/mob/items/righthand_bee_gear.dmi
The worn veil is the only art here with partly transparent pixels: the gauze
is a checker of two alphas, so the wearer's face shows dimly through it and
the mesh still reads at 1x. The hat, the hem tape and the suit are opaque.
The suit is drawn one pixel wider than the body so it covers the uniform, and
stops at the elastic (wrist row 19, ankle row 28) so hands and footwear show.

`--check` verifies the four committed sheets byte for byte, `--preview <png>`
writes a review sheet. Released under Civ13 AGPL-3.0.
"""
import io
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_diving_gear import Frame, base_body, sym  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEETS = {
    'items': ROOT / 'icons/obj/clothing/bee_gear.dmi',
    'worn': ROOT / 'icons/mob/bee_gear.dmi',
    'left': ROOT / 'icons/mob/items/lefthand_bee_gear.dmi',
    'right': ROOT / 'icons/mob/items/righthand_bee_gear.dmi',
}

# dried straw (the rain cape's straw)
S = [(236, 212, 134), (208, 178, 98), (170, 140, 68), (124, 98, 46), (66, 50, 22)]
# hat band: dark felt ribbon
BAND = [(96, 70, 44), (62, 44, 28)]
# black gauze: thread catching the light, thread, shadowed thread, hem tape
M = [(120, 128, 120), (58, 64, 60), (26, 30, 28), (14, 16, 15)]
# what shows behind the gauze on the loose item and in the hand
BACKING = (74, 80, 74)
# bleached cotton drill
W = [(250, 248, 240), (232, 228, 214), (204, 199, 182), (166, 161, 144), (98, 95, 84)]
# horn buttons
BT = [(150, 128, 96), (104, 86, 62)]


class Art(Frame):
    """A 32px frame whose pixels may carry their own alpha."""

    def mirror(self):
        f = Art()
        f.px = {(31 - x, y): c for (x, y), c in self.px.items()}
        return f

    def flip(self):
        """Mirror about the body's centre column (x = 15), as the held sheets do."""
        f = Art()
        f.px = {(30 - x, y): c for (x, y), c in self.px.items() if 0 <= 30 - x < 32}
        return f

    def moved(self, dx, dy):
        f = Art()
        for (x, y), c in self.px.items():
            f.put(x + dx, y + dy, c)
        return f

    def solid(self, backing=BACKING):
        """The same art with the gauze laid over a backing, fully opaque."""
        f = Art()
        for p, c in self.px.items():
            if len(c) == 4:
                a = c[3] / 255.0
                c = tuple(int(round(c[i] * a + backing[i] * (1 - a))) for i in range(3))
            f.px[p] = c
        return f

    def image(self):
        im = Image.new('RGBA', (32, 32))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c if len(c) == 4 else c + (255,))
        return im


# ---------------------------------------------------------------- veil

def gauze(f, rows, hem_y, folds=()):
    """The hanging veil. `rows` is {y: (x0, x1)}. The two edge columns are the
    gauze seen edge on (nearly opaque); between them a checker of a dark,
    denser thread pixel and a thin one lets the face through. `folds` are
    columns where the cloth doubles over."""
    for y, (x0, x1) in rows.items():
        for x in range(x0, x1 + 1):
            if y == hem_y:
                f.put(x, y, M[3] + (250,))                     # tape hem, gathered
            elif x in (x0, x1):
                f.put(x, y, M[2] + (238,))
            elif x in folds:
                f.put(x, y, M[2] + (200 if (x + y) % 2 else 150,))
            elif (x + y) % 2:
                f.put(x, y, M[2] + (176,))
            else:
                f.put(x, y, M[1] + (72,))
    # the lit side: a few threads catch the light down the second column
    for y, (x0, x1) in rows.items():
        if y != hem_y and (x0 + 1 + y) % 2:
            f.put(x0 + 1, y, M[0] + (150,))
    return f


def straw_weave(f, brim_rows):
    """Plait marks on the brim: every third stitch a shade darker."""
    for y, (x0, x1) in brim_rows.items():
        for x in range(x0 + 1, x1):
            if (x * 2 + y * 3) % 5 == 0 and f.px.get((x, y)) in (S[0], S[1], S[2]):
                f.put(x, y, S[min(S.index(f.px[(x, y)]) + 1, 3)])


def veil_front(back=False):
    f = Art()
    veil = {6: (9, 21), 7: (9, 21), 8: (9, 21), 9: (9, 21), 10: (9, 21), 11: (9, 21), 12: (9, 21), 13: (10, 20)}
    gauze(f, veil, 13, folds=(12, 18) if not back else (11, 15, 19))
    # the hem draws in to the collar: corners cut, a tie knotted at the throat
    f.pts(M[2] + (238,), (9, 12), (21, 12))
    if not back:
        f.pts(M[0], (15, 13)); f.pts(M[1], (14, 13), (16, 13))
    # brim: a broad ellipse, its far edge behind the crown
    brim = {3: (9, 21), 4: (7, 23), 5: (7, 23)}
    f.part(brim, S)
    f.h(4, 8, 22, S[1]); f.h(4, 8, 12, S[0]); f.h(4, 19, 22, S[2])
    f.h(5, 8, 22, S[3]); f.pts(S[2], (8, 5), (9, 5), (10, 5)); f.pts(S[4], (7, 5), (23, 5), (7, 4), (23, 4))
    f.h(3, 9, 21, S[2]); f.pts(S[4], (9, 3), (21, 3), (8, 3), (22, 3))
    straw_weave(f, {4: (7, 23)})
    # crown
    crown = {0: (13, 17), 1: (12, 18), 2: (12, 18), 3: (12, 18)}
    f.ball(crown, S, 13.4, 1.0, (1.4, 3.0, 4.6))
    f.h(3, 12, 18, BAND[1]); f.h(3, 13, 16, BAND[0])
    if back:
        f.pts(BAND[0], (15, 3)); f.pts(BAND[1], (14, 3), (16, 3))
    # shadow the brim throws on the top of the veil
    for x in range(10, 21):
        f.put(x, 6, M[3] + (206 if x % 2 else 112,))
    return f


def veil_side():
    """Facing east: the face is on the right."""
    f = Art()
    veil = {6: (10, 22), 7: (10, 22), 8: (10, 22), 9: (10, 22), 10: (10, 22), 11: (10, 22), 12: (10, 22), 13: (11, 21)}
    gauze(f, veil, 13, folds=(13, 19))
    f.pts(M[2] + (238,), (10, 12), (22, 12))
    brim = {3: (10, 22), 4: (8, 24), 5: (8, 24)}
    f.part(brim, S)
    f.h(4, 9, 23, S[1]); f.h(4, 9, 13, S[0]); f.h(4, 20, 23, S[2])
    f.h(5, 9, 23, S[3]); f.pts(S[2], (9, 5), (10, 5), (11, 5)); f.pts(S[4], (8, 5), (24, 5), (8, 4), (24, 4))
    f.h(3, 10, 22, S[2]); f.pts(S[4], (10, 3), (22, 3), (9, 3), (23, 3))
    straw_weave(f, {4: (8, 24)})
    crown = {0: (14, 18), 1: (13, 19), 2: (13, 19), 3: (13, 19)}
    f.ball(crown, S, 14.4, 1.0, (1.4, 3.0, 4.6))
    f.h(3, 13, 19, BAND[1]); f.h(3, 14, 17, BAND[0])
    for x in range(11, 22):
        f.put(x, 6, M[3] + (206 if x % 2 else 112,))
    return f


def veil_item():
    """The hat lying brim down with the veil gathered loosely under it."""
    f = veil_front().solid().moved(1, 9)
    # a loose item is not hanging from a head: let the veil sag and spread
    for x in range(9, 24):
        f.put(x, 23, M[2] if (x % 2) else M[1])
    f.h(24, 10, 22, M[3]); f.pts(M[3], (8, 23), (24, 23), (9, 24), (23, 24))
    f.pts(M[3], (9, 22), (23, 22)); f.pts(M[2], (10, 22), (22, 22))
    f.pts(M[0], (16, 24)); f.pts(M[1], (15, 24), (17, 24), (15, 25), (17, 25))   # tie ends
    return f


# ---------------------------------------------------------------- suit

def suit_front(back=False):
    f = Art()
    # crotch and baggy legs, blousing over the ankle elastic
    f.part({21: (10, 20), 22: (10, 20), 23: (10, 20)}, W)
    f.part(sym({23: (10, 14), 24: (10, 14), 25: (9, 14), 26: (9, 14), 27: (9, 14), 28: (11, 14)}), W)
    f.h(22, 11, 19, W[1]); f.h(23, 11, 19, W[1]); f.pts(W[0], (11, 22), (12, 22), (11, 23), (12, 23))
    f.pts(W[2], (18, 22), (19, 22), (18, 23), (19, 23)); f.pts(W[4], (15, 24), (15, 23)); f.pts(W[3], (15, 22))
    for x0, x1 in ((11, 14), (16, 19)):                        # elastic: a dark gathered row
        f.h(28, x0, x1, W[3]); f.pts(W[4], (x0, 28), (x1, 28)); f.put(x0 + 1, 28, W[2])
    f.pts(W[3], (12, 25), (13, 26), (17, 25), (18, 26))        # folds at the knees
    f.pts(W[2], (10, 27), (12, 27), (17, 27), (19, 27))        # cloth bunching over the elastic
    # torso
    f.part({11: (11, 19), 12: (10, 20), 13: (10, 20), 14: (10, 20), 15: (10, 20), 16: (10, 20), 17: (10, 20),
            18: (10, 20), 19: (10, 20), 20: (10, 20), 21: (10, 20)}, W)
    f.h(21, 11, 19, W[1]); f.pts(W[0], (11, 21), (12, 21)); f.pts(W[2], (18, 21), (19, 21))
    # sleeves, loose down to the wrist elastic; the hand is left bare
    f.part(sym({12: (8, 9), 13: (7, 9), 14: (6, 9), 15: (6, 9), 16: (6, 9), 17: (6, 9), 18: (6, 9), 19: (7, 9)}), W)
    for x0 in (7, 21):
        f.h(19, x0, x0 + 2, W[3]); f.pts(W[4], (x0, 19), (x0 + 2, 19)); f.put(x0 + 1, 19, W[2])
    f.pts(W[2], (7, 17), (8, 18), (23, 17), (22, 18)); f.pts(W[0], (7, 14), (7, 15), (22, 14))
    # drawn-in waist
    f.h(20, 11, 19, W[2])
    for x in (11, 13, 17, 19):
        f.put(x, 20, W[3])
    if back:
        # yoke seam and the centre back seam
        f.h(14, 11, 19, W[2]); f.pts(W[3], (11, 14), (19, 14))
        f.v(15, 15, 19, W[2]); f.v(15, 21, 22, W[3])
        f.h(11, 12, 18, W[2]); f.pts(W[4], (11, 11), (19, 11)); f.h(12, 12, 18, W[1])
        return f
    # buttoned front, right over left
    f.v(15, 13, 22, W[3]); f.v(14, 13, 22, W[0])
    f.pts(BT[0], (16, 14), (16, 17), (16, 20)); f.pts(BT[1], (16, 15), (16, 18))
    # stand collar, open at the throat
    for x in range(14, 17):
        f.px.pop((x, 11), None)
    f.pts(W[4], (13, 11), (17, 11), (14, 12), (16, 12), (15, 13))
    f.px.pop((15, 12), None)
    f.pts(W[0], (12, 11), (12, 12), (13, 12)); f.pts(W[2], (18, 11), (17, 12), (18, 12))
    # breast pocket and a hip pocket for the hive tool
    f.h(15, 17, 19, W[3]); f.pts(W[2], (17, 16), (19, 16))
    f.h(23, 11, 13, W[3]); f.h(23, 17, 19, W[3])
    return f


def suit_side():
    """Facing east."""
    f = Art()
    f.part({21: (12, 18), 22: (12, 18), 23: (12, 18), 24: (12, 18), 25: (11, 18), 26: (11, 19), 27: (11, 19),
            28: (13, 17)}, W)
    f.h(28, 13, 17, W[3]); f.pts(W[4], (13, 28), (17, 28)); f.pts(W[2], (14, 28))
    f.pts(W[3], (15, 25), (16, 26)); f.pts(W[2], (12, 27), (17, 27), (18, 27))
    f.part({11: (12, 18), 12: (11, 19), 13: (10, 20), 14: (10, 20), 15: (10, 20), 16: (10, 20), 17: (10, 20),
            18: (10, 20), 19: (11, 20), 20: (11, 19), 21: (12, 18)}, W)
    f.h(21, 13, 17, W[1]); f.pts(W[0], (13, 21)); f.pts(W[2], (17, 21))
    f.h(20, 12, 18, W[2]); f.pts(W[3], (12, 20), (18, 20))    # waist
    # buttoned front edge
    f.v(19, 13, 19, W[3]); f.pts(BT[0], (19, 14), (19, 17)); f.pts(BT[1], (19, 15), (19, 18))
    # collar
    f.h(11, 13, 17, W[1]); f.pts(W[0], (13, 11), (14, 11)); f.pts(W[4], (12, 11), (18, 11))
    # sleeve hanging at the side, gathered at the wrist
    f.part({12: (13, 17), 13: (13, 17), 14: (12, 17), 15: (12, 17), 16: (12, 17), 17: (12, 17), 18: (12, 17),
            19: (13, 16)}, W)
    f.h(19, 13, 16, W[3]); f.pts(W[4], (13, 19), (16, 19)); f.pts(W[2], (14, 19))
    f.h(12, 14, 16, W[1]); f.pts(W[0], (14, 12), (13, 14), (13, 15)); f.pts(W[2], (15, 17), (16, 18))
    f.h(23, 13, 16, W[3])                                     # hip pocket
    return f


def suit_item():
    """Laid flat, front up, a little smaller than life so it sits in the tile."""
    return suit_front().moved(1, -4)


# ---------------------------------------------------------------- held

def suit_in_hand(x):
    """The coverall folded over the hand."""
    f = Art()
    f.part({17: (x - 1, x + 1), 18: (x - 2, x + 2), 19: (x - 2, x + 2), 20: (x - 2, x + 2), 21: (x - 2, x + 2),
            22: (x - 2, x + 2), 23: (x - 1, x + 2), 24: (x - 1, x + 1)}, W)
    f.h(20, x - 1, x + 1, W[3]); f.pts(W[0], (x - 1, 18), (x, 18)); f.pts(W[2], (x, 22), (x + 1, 22))
    f.pts(W[3], (x, 23)); f.pts(BT[0], (x + 1, 19))
    return f


def veil_in_hand(x):
    """The hat carried by its crown, the veil trailing below."""
    f = Art()
    for y, (x0, x1) in {20: (x - 2, x + 2), 21: (x - 2, x + 2), 22: (x - 2, x + 2), 23: (x - 2, x + 2),
                        24: (x - 1, x + 1)}.items():
        for xx in range(x0, x1 + 1):
            f.put(xx, y, M[3] if xx in (x0, x1) or y == 24 else M[2] if (xx + y) % 2 == 0 else M[1])
    f.pts(M[0], (x - 1, 21), (x - 1, 23))
    f.part({16: (x - 1, x + 1), 17: (x - 2, x + 2), 18: (x - 3, x + 3), 19: (x - 3, x + 3)}, S)
    f.h(17, x - 1, x + 1, BAND[1]); f.put(x - 1, 17, BAND[0])
    f.h(18, x - 2, x + 2, S[1]); f.pts(S[0], (x - 2, 18), (x - 1, 18)); f.pts(S[2], (x + 2, 18))
    f.h(19, x - 2, x + 2, S[3])
    f.put(x, 16, S[0])
    return f


def four(make, s=21, n=9, e=16, w=13):
    """Left-hand frames S, N, E, W for a maker taking the hand's column."""
    return [make(s), make(n), make(e), make(w)]


def right_of(left):
    return [left[0].flip(), left[1].flip(), left[3].flip(), left[2].flip()]


# ---------------------------------------------------------------- sheets

WORN = {
    'bee_veil': [veil_front(), veil_front(True), veil_side(), veil_side().mirror()],
    'beekeeper_suit': [suit_front(), suit_front(True), suit_side(), suit_side().mirror()],
}
ITEMS = {
    'bee_veil': veil_item(),
    'beekeeper_suit': suit_item(),
}
HELD_L = {
    'bee_veil': four(veil_in_hand),
    'beekeeper_suit': four(suit_in_hand),
}
HELD_R = {name: right_of(frames) for name, frames in HELD_L.items()}
BUILD = {'items': (ITEMS, 1), 'worn': (WORN, 4), 'left': (HELD_L, 4), 'right': (HELD_R, 4)}


def dmi_bytes(states, dirs):
    frames = [fr for name in states for fr in (states[name] if dirs > 1 else [states[name]])]
    cols = 4 if dirs > 1 else len(frames)
    rows = (len(frames) + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * 32, rows * 32))
    for i, fr in enumerate(frames):
        sheet.paste(fr.image(), ((i % cols) * 32, (i // cols) * 32))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name in states:
        text += 'state = "%s"\n\tdirs = %d\n\tframes = 1\n' % (name, dirs)
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    out = io.BytesIO()
    sheet.save(out, format='PNG', pnginfo=meta)
    return out.getvalue()


def check_drawing():
    """Rules the drawing must keep, whatever the palettes become."""
    problems = []
    for direction, name in enumerate(('south', 'north', 'east', 'west')):
        body = base_body(direction)
        veil, suit = WORN['bee_veil'][direction], WORN['beekeeper_suit'][direction]
        for y in range(3, 10):
            for x in range(32):
                if body.getpixel((x, y))[3] and (x, y) not in veil.px:
                    problems.append('bee_veil %s leaves the head bare at %d,%d' % (name, x, y))
        if not any(len(c) == 4 and c[3] < 160 for (x, y), c in veil.px.items() if 6 <= y <= 9):
            problems.append('bee_veil %s has no see-through mesh over the face' % name)
        # the suit covers the body from the collar to the elastic, bar the throat and the hands
        for y in range(12, 28):
            for x in range(32):
                if body.getpixel((x, y))[3] and (x, y) not in suit.px and not (19 <= y <= 21) and (x, y) != (15, 12):
                    problems.append('beekeeper_suit %s leaves the body bare at %d,%d' % (name, x, y))
        if any(len(c) == 4 for c in suit.px.values()):
            problems.append('beekeeper_suit %s is not opaque' % name)
        if any(y > 28 for _, y in suit.px):
            problems.append('beekeeper_suit %s covers the feet' % name)
    for states in (ITEMS, HELD_L, HELD_R):
        for name, frames in states.items():
            for fr in (frames if isinstance(frames, list) else [frames]):
                if not fr.px or any(len(c) == 4 for c in fr.px.values()):
                    problems.append('%s item or held art is empty or see-through' % name)
    return problems


def clothing(direction, path, name):
    """One state of an existing worn sheet, to show the suit over a uniform."""
    sheet = Image.open(ROOT / path)
    order = []
    for line in sheet.info.get('Description', '').split('\n'):
        line = line.strip()
        if line.startswith('state = '):
            order.append([line[9:-1], 1, 1])
        elif line.startswith('dirs = '):
            order[-1][1] = int(line[7:])
        elif line.startswith('frames = '):
            order[-1][2] = int(line[9:])
    index = 0
    for state, dirs, frames in order:
        if state == name:
            break
        index += dirs * frames
    sheet = sheet.convert('RGBA')
    cols = sheet.width // 32
    i = index + (direction if dirs > 1 else 0)
    return sheet.crop(((i % cols) * 32, (i // cols) * 32, (i % cols) * 32 + 32, (i // cols) * 32 + 32))


def write_preview(path, scale=6):
    """Review sheet. Rows: veil and suit together, the same over a uniform,
    the veil alone, the suit alone (each S, N, E, W on the base body); then
    both items held in either hand, the item icons, and 2x and 1x rows."""
    cell = 32 * scale
    bg, bg2, dirt = (74, 96, 74, 255), (66, 88, 68, 255), (126, 98, 68, 255)
    uniform = ('icons/mob/uniform.dmi', 'farmer_outfit')

    def figure(direction, worn=(), under=None, held=()):
        im = base_body(direction)
        if under:
            im.alpha_composite(clothing(direction, *under))
        for state in worn:
            im.alpha_composite(WORN[state][direction].image())
        for hand, state in held:
            im.alpha_composite(hand[state][direction].image())
        return im

    rows = [
        [figure(d, ('beekeeper_suit', 'bee_veil')) for d in range(4)],
        [figure(d, ('beekeeper_suit', 'bee_veil'), uniform) for d in range(4)],
        [figure(d, ('bee_veil',)) for d in range(4)],
        [figure(d, ('beekeeper_suit',)) for d in range(4)],
        [figure(d, ('bee_veil',), uniform) for d in range(4)],
        [figure(d, (), None, ((HELD_L, 'bee_veil'), (HELD_R, 'beekeeper_suit'))) for d in range(4)],
        [figure(d, (), None, ((HELD_L, 'beekeeper_suit'), (HELD_R, 'bee_veil'))) for d in range(4)],
    ]
    side = [ITEMS['bee_veil'].image(), ITEMS['beekeeper_suit'].image()]
    sheet = Image.new('RGBA', (cell * 6, cell * len(rows) + 32 * 3 + 12), bg)
    for r, row in enumerate(rows):
        for c, im in enumerate(row):
            ground = dirt if r == 1 else bg
            tile = Image.new('RGBA', (32, 32), ground)
            tile.alpha_composite(im)
            sheet.alpha_composite(tile.resize((cell, cell), Image.NEAREST), (c * cell, r * cell))
    for i, im in enumerate(side):
        for j, ground in enumerate((bg2, dirt)):
            tile = Image.new('RGBA', (32, 32), ground)
            tile.alpha_composite(im)
            sheet.alpha_composite(tile.resize((cell, cell), Image.NEAREST), ((4 + j) * cell, i * cell))
    # the worn veil with nobody under it, to show the mesh itself
    for j, ground in enumerate((bg2, (230, 230, 230, 255))):
        tile = Image.new('RGBA', (32, 32), ground)
        tile.alpha_composite(WORN['bee_veil'][0 if j == 0 else 2].image())
        sheet.alpha_composite(tile.resize((cell, cell), Image.NEAREST), ((4 + j) * cell, 2 * cell))
    # 2x and 1x: both worn, veil alone, suit alone, then the items
    y0 = cell * len(rows) + 4
    small = rows[0] + rows[2] + rows[3]
    for i, im in enumerate(small):
        tile = Image.new('RGBA', (32, 32), bg)
        tile.alpha_composite(im)
        sheet.alpha_composite(tile.resize((64, 64), Image.NEAREST), (i * 66, y0))
        sheet.alpha_composite(tile, (i * 34, y0 + 68))
    for i, im in enumerate(side):
        tile = Image.new('RGBA', (32, 32), bg2)
        tile.alpha_composite(im)
        sheet.alpha_composite(tile.resize((64, 64), Image.NEAREST), ((len(small) + i) * 66, y0))
        sheet.alpha_composite(tile, ((len(small) + i) * 34, y0 + 68))
    sheet.convert('RGB').save(path)


def main():
    args = sys.argv[1:]
    problems = check_drawing()
    if '--check' in args:
        for key, (states, dirs) in BUILD.items():
            path = SHEETS[key]
            if not path.exists():
                problems.append('missing sheet: %s' % path)
            elif path.read_bytes() != dmi_bytes(states, dirs):
                problems.append('stale sheet: %s' % path)
        for line in problems:
            print(line)
        print('bee gear: %s' % ('FAILED' if problems else 'ok'))
        return 1 if problems else 0
    if problems:
        print('\n'.join(problems))
        return 1
    for key, (states, dirs) in BUILD.items():
        SHEETS[key].write_bytes(dmi_bytes(states, dirs))
    if '--preview' in args[:-1]:
        write_preview(args[args.index('--preview') + 1])
    return 0


if __name__ == '__main__':
    sys.exit(main())
