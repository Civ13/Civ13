"""Hand-placed 32px firefighting tools: the fire beater (a leafy green branch)
and the fire flapper (a hide flap lashed to a pole), each dry and wet, the
iron fire hook, plus their in-hand sprites in four directions. Every pixel is placed by this script
from a fixed palette (Pillow only); no external or generated artwork.

Run with Pillow to reproduce icons/obj/firefighting.dmi. `--preview <png>`
also writes an enlarged review sheet. Released under Civ13 AGPL-3.0.
"""
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]

OUT = (28, 22, 16)
# bark: light, mid, dark
BARK = [(150, 108, 66), (116, 80, 46), (78, 52, 30)]
# trimmed pole: light, mid, dark
POLE = [(196, 160, 106), (160, 124, 76), (112, 82, 48)]
# green leaves: highlight, light, mid, dark, outline
LEAF = [(150, 196, 84), (104, 160, 60), (70, 124, 46), (44, 88, 36), (24, 52, 26)]
# soaked leaves
LEAF_WET = [(120, 176, 110), (72, 136, 72), (44, 100, 56), (26, 68, 44), (14, 40, 30)]
# rawhide flap: highlight, light, mid, dark, outline
HIDE = [(226, 196, 146), (198, 162, 110), (164, 126, 80), (122, 90, 56), (70, 48, 30)]
# soaked hide
HIDE_WET = [(176, 150, 112), (146, 116, 80), (114, 86, 58), (82, 60, 40), (44, 30, 20)]
CORD = [(222, 206, 160), (150, 132, 92)]
DROP = [(226, 244, 255), (128, 190, 232)]
# forged iron: highlight, light, mid, dark, outline
IRON = [(206, 212, 220), (150, 158, 170), (104, 112, 126), (66, 72, 86), (30, 34, 44)]


class Frame:
    def __init__(self):
        self.px = {}

    def put(self, x, y, c):
        if 0 <= x < 32 and 0 <= y < 32:
            self.px[(x, y)] = c

    def pts(self, c, *points):
        for x, y in points:
            self.put(x, y, c)

    def rows(self, top, left, art, key):
        """Stamp ASCII art: each character is looked up in key, '.' is clear."""
        for dy, row in enumerate(art):
            for dx, ch in enumerate(row):
                if ch != '.':
                    self.put(left + dx, top + dy, key[ch])

    def mirror(self):
        f = Frame()
        f.px = {(31 - x, y): c for (x, y), c in self.px.items()}
        return f

    def image(self):
        im = Image.new('RGBA', (32, 32))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c + (255,))
        return im


def diagonal(f, x0, y0, n, ramp, dx=1):
    """A two pixel thick stem rising to the right (dx=1) or left (dx=-1):
    lit edge above, shaded edge below."""
    for i in range(n):
        x, y = x0 + dx * i, y0 - i
        f.put(x, y, ramp[0] if i % 3 else ramp[1])
        f.put(x + dx, y, ramp[2])


# ---------------------------------------------------------------- fire beater
# One leaf, tip up and to the right. h highlight, l light, m mid, d dark, o outline
LEAF_STAMP = ['..oo.', '.olho', 'ollmo', 'ommdo', '.odo.']
# Leaves in drawing order (back to front), by top-left corner. They sit along
# the three twigs the stem splits into, so the head reads as one sprig.
BEATER_LEAVES = [
    (12, 4), (17, 3), (22, 5), (9, 8), (25, 9),
    (14, 7), (20, 7), (8, 13), (25, 14), (11, 11),
    (23, 11), (17, 9), (13, 15), (21, 15), (17, 13), (19, 18),
]
# Twig pixels that stay visible between the leaves.
BEATER_TWIGS = [(12, 20), (13, 19), (14, 18), (15, 17), (16, 16), (17, 15),
                (14, 17), (14, 16), (13, 15), (13, 14),
                (16, 17), (17, 17), (18, 17), (19, 16), (20, 16)]


def beater(wet=False):
    f = Frame()
    leaf = LEAF_WET if wet else LEAF
    bark = [BARK[1], BARK[2], (52, 34, 20)] if wet else BARK
    diagonal(f, 3, 29, 10, bark)                      # the handle
    f.pts(OUT, (2, 30), (3, 30), (2, 29))             # snapped butt end
    f.pts(bark[0], (6, 25))                           # a knot
    for x, y in BEATER_TWIGS:
        f.put(x, y, bark[1])
        f.put(x + 1, y, bark[2])
    key = {'h': leaf[0], 'l': leaf[1], 'm': leaf[2], 'd': leaf[3], 'o': leaf[4]}
    for x, y in BEATER_LEAVES:
        f.rows(y, x, LEAF_STAMP, key)
    if wet:
        f.pts(DROP[0], (15, 6), (24, 12), (12, 12), (20, 17), (27, 11))
        f.pts(DROP[1], (15, 7), (24, 13), (12, 13), (20, 18), (27, 12), (16, 23), (24, 21))
    return f


# --------------------------------------------------------------- fire flapper
# A hide flap lashed to the split head of a pole. The flap lies along the pole
# axis: u runs along it from the lashing, v across it.
def flapper(wet=False):
    f = Frame()
    hide = HIDE_WET if wet else HIDE
    pole = [POLE[1], POLE[2], (64, 44, 26)] if wet else POLE
    diagonal(f, 2, 30, 18, pole)                      # the pole, running under the flap
    f.pts(OUT, (1, 31), (2, 31), (1, 30))
    ox, oy = 15, 17                                   # where the flap starts on the pole
    ragged = [9, 9, 9.5, 9, 9, 9.5, 10, 9.5, 9, 9, 9.5, 9, 9]   # far edge, per v step
    inside = {}
    for y in range(32):
        for x in range(32):
            dx, dy = x - ox, oy - y
            u, v = (dx + dy) / 2.0, (dx - dy) / 2.0
            half = min(5.5, 2.5 + u * 0.6)
            far = ragged[int(v + 6) % len(ragged)]
            if 0 <= u <= far and abs(v) <= half:
                inside[(x, y)] = (u, v)
    for (x, y), (u, v) in inside.items():
        edge = any(n not in inside for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))
        if edge:
            c = hide[4]
        elif v < -2.5:
            c = hide[0]
        elif v < 1.5:
            c = hide[1]
        elif v < 3.5:
            c = hide[2]
        else:
            c = hide[3]
        f.put(x, y, c)
    # The pole shows as a ridge under the first half of the hide.
    for i in range(1, 6):
        f.put(ox + i, oy - i, hide[2])
        f.put(ox + i + 1, oy - i, hide[3])
    # Two cord lashings across the pole, and the stitch holes beside them.
    for cx, cy in ((16, 16), (19, 13)):
        f.pts(CORD[0], (cx - 1, cy - 1), (cx, cy), (cx + 1, cy + 1))
        f.pts(CORD[1], (cx, cy + 1), (cx + 1, cy + 2))
    for x, y in ((22, 7), (26, 10), (24, 13), (20, 10), (25, 7)):      # scars and scorch marks
        if (x, y) in inside:
            f.put(x, y, hide[3])
    if wet:
        f.pts(DROP[0], (21, 7), (26, 11), (23, 14))
        f.pts(DROP[1], (21, 8), (26, 12), (23, 15), (20, 21), (24, 20), (27, 17))
    return f


# ------------------------------------------------------------------ fire hook
# A long pole with a forged iron head: a spike in line with the pole and a
# hook curling back from it.
# The spike, from the socket to the point, and the hook that curls back from it.
HOOK_SPIKE = [(19, 12), (20, 11), (21, 10), (22, 9), (23, 8), (24, 7), (25, 6), (26, 5)]
HOOK_CURL = [(19, 10), (18, 9), (17, 8), (16, 7), (15, 7), (14, 7), (13, 8), (12, 9),
             (12, 10), (12, 11), (12, 12), (13, 13)]


def fire_hook():
    f = Frame()
    diagonal(f, 1, 30, 17, POLE)                      # the pole
    f.pts(OUT, (0, 31), (1, 31), (0, 30))
    iron = {}
    for i, (x, y) in enumerate(HOOK_SPIKE):           # lit above, shaded below
        iron[(x, y)] = IRON[0] if i > 4 else IRON[1]
        iron[(x + 1, y)] = IRON[2]
    del iron[(27, 5)]                                 # a sharp point
    for i, (x, y) in enumerate(HOOK_CURL):
        iron[(x, y)] = IRON[1] if i < 7 else IRON[2]
        iron[(x, y + 1)] = IRON[3]
    del iron[(13, 14)]                                # and a sharp hook tip
    for x, y in ((18, 13), (19, 13), (18, 14)):       # the socket band on the pole
        iron[(x, y)] = IRON[2]
    iron[(17, 14)] = IRON[3]
    for (x, y) in list(iron):                         # dark outline on open sides
        for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if n not in iron and n not in f.px:
                f.put(n[0], n[1], IRON[4])
    for (x, y), c in iron.items():
        f.put(x, y, c)
    return f


# ------------------------------------------------------------------- in hand
# Left hand, facing south, north, east and west: where the shaft runs (as on
# the spear) and where the head sits. The right hand is the mirror image.
SHAFTS = {
    'S': ([(22, 19), (23, 18), (24, 17), (25, 16), (26, 15)], (28, 13)),
    'N': ([(12, 24), (11, 23), (10, 22), (9, 21), (6, 18), (5, 17), (4, 16)], (3, 14)),
    'E': ([(21, 19), (22, 18), (23, 17), (24, 16), (25, 15)], (27, 13)),
    'W': ([(20, 25), (19, 24), (18, 23), (17, 22), (14, 19), (13, 18), (12, 17)], (11, 15)),
}
HAND_LEAVES = ['.oo..', 'olho.', 'ollmo', 'ommdo', '.odo.']
HAND_FLAP = ['.ooo.', 'ohllo', 'ollmo', 'olmdo', '.ooo.']
HAND_HOOK = ['...ho', '.o.lo', 'ol.mo', 'ommo.', '.oo..']


def in_hand(kind, facing):
    f = Frame()
    shaft, (hx, hy) = SHAFTS[facing]
    ramp = BARK if kind == 'beater' else POLE
    step = 1 if shaft[1][0] > shaft[0][0] else -1
    for x, y in shaft:
        f.put(x, y, ramp[0])
        f.put(x + step, y, ramp[2])
    if kind == 'beater':
        key = {'h': LEAF[0], 'l': LEAF[1], 'm': LEAF[2], 'd': LEAF[3], 'o': LEAF[4]}
        f.rows(hy - 2, hx - 2, HAND_LEAVES, key)
    elif kind == 'hook':
        key = {'h': IRON[0], 'l': IRON[1], 'm': IRON[2], 'd': IRON[3], 'o': IRON[4]}
        art = HAND_HOOK if step > 0 else [row[::-1] for row in HAND_HOOK]
        f.rows(hy - 2, hx - 2, art, key)
    else:
        key = {'h': HIDE[0], 'l': HIDE[1], 'm': HIDE[2], 'd': HIDE[3], 'o': HIDE[4]}
        f.rows(hy - 2, hx - 2, HAND_FLAP, key)
    return f


def hand_states(kind):
    left = {d: in_hand(kind, d) for d in 'SNEW'}
    right = {'S': left['S'].mirror(), 'N': left['N'].mirror(), 'E': left['W'].mirror(), 'W': left['E'].mirror()}
    return [left[d] for d in 'SNEW'], [right[d] for d in 'SNEW']


def states():
    out = {
        'fire_beater': [beater()],
        'fire_beater_wet': [beater(True)],
        'fire_flapper': [flapper()],
        'fire_flapper_wet': [flapper(True)],
        'fire_hook': [fire_hook()],
    }
    for kind, name in (('beater', 'fire_beater'), ('flapper', 'fire_flapper'), ('hook', 'fire_hook')):
        out[name + '_l'], out[name + '_r'] = hand_states(kind)
    return out


def write_dmi(path, st):
    frames = [fr for group in st.values() for fr in group]
    sheet = Image.new('RGBA', (32 * len(frames), 32), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(fr.image(), (i * 32, 0))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, group in st.items():
        text += 'state = "%s"\n\tdirs = %d\n\tframes = 1\n' % (name, len(group))
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta)


def preview(path, st, scale=8):
    grounds = [(94, 132, 62), (120, 96, 66), (60, 60, 64)]   # grass, dirt, night
    names = ['fire_beater', 'fire_beater_wet', 'fire_flapper', 'fire_flapper_wet', 'fire_hook']
    hands = ['fire_beater_l', 'fire_beater_r', 'fire_flapper_l', 'fire_flapper_r', 'fire_hook_l', 'fire_hook_r']
    cell = 32 * scale
    sheet = Image.new('RGBA', (cell * 5, cell * (len(grounds) + len(hands)) // 1), (40, 40, 44, 255))
    for r, ground in enumerate(grounds):
        for c, name in enumerate(names):
            tile = Image.new('RGBA', (32, 32), ground + (255,))
            tile.alpha_composite(st[name][0].image())
            sheet.paste(tile.resize((cell, cell), Image.NEAREST), (c * cell, r * cell))
    for r, name in enumerate(hands):
        for c, fr in enumerate(st[name]):
            tile = Image.new('RGBA', (32, 32), grounds[0] + (255,))
            tile.alpha_composite(fr.image())
            sheet.paste(tile.resize((cell, cell), Image.NEAREST), (c * cell, (len(grounds) + r) * cell))
    sheet.save(path)


if __name__ == '__main__':
    st = states()
    write_dmi(ROOT / 'icons/obj/firefighting.dmi', st)
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1], st)
