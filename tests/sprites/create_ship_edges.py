#!/usr/bin/env python3
"""Draw the ship edges art (docs/ship-edges.md): gunwales, bulwarks and their
gangway gates, figureheads, the grapnel, the bowsprit with its jib and the
mast with a crow's nest.

It writes five sheets:

  icons/obj/ship_edges.dmi (32x32)
      gunwale, gunwale_gate, gunwale_gate_open     4 dirs: a low planked side
          under a capping plank, with timberheads at the tile ends and a
          scupper; the gate is a boarded port between two timberheads
      bulwark, bulwark_gate, bulwark_gate_open     4 dirs: riveted grey plate
          under a steel rail, with a freeing port; the gate is a plate door
      figurehead                                   4 dirs: the uncarved baulk,
          marked out in chalk
      figurehead_bear, _wolf, _goose, _monkey, _serpent, _ram, _face
                                                   4 dirs: the carved figures
      grapnel                                      a four-fluked iron hook on
          a coil of line
  icons/mob/items/lefthand_ship_edges.dmi, righthand_ship_edges.dmi (32x32)
      grapnel                                      4 dirs, held: the coil in
          the fist and the hook hanging under it
  icons/obj/vehicles/ship_bowsprit.dmi (96x96)
      sail0, sail1, sail2                          4 dirs: the bare spar, the
          jib furled along it, the jib set. The state names are the mast's,
          because a bowsprit is a sail subtype. The dir is the way it points.
          Her own tile is the middle of the cell (the type has pixel_x and
          pixel_y of -32): the spar is stepped at the middle of her tile and
          stands 28 pixels out over the next tile in every direction.
  icons/obj/vehicles/ship_mast_nest.dmi (64x64)
      sail0, sail1, sail2                          4 dirs: the mast states of
          vehicleparts64x64.dmi with a crow's nest drawn at the masthead

The railing pieces follow icons/obj/railings_built.dmi (see
create_built_railings.py): the dir is the tile edge the piece runs along,
SOUTH and NORTH are elevations, EAST and WEST are strips seen from above with
their south end drawn at full height. The crow's nest sheet keeps the mast's
own 64x64 placement. Everything is lit from the top left. The drawing is plain pixel work
with Pillow from fixed palettes; nothing is random, so a rerun writes the
same bytes.

  python3 tests/sprites/create_ship_edges.py                  write the sheets
  python3 tests/sprites/create_ship_edges.py --check          verify the committed sheets
  python3 tests/sprites/create_ship_edges.py --preview <png>  also write a review sheet
"""
import math
import re
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_bollards import noise, option  # noqa: E402
from create_built_railings import Cv, shadow, WOOD, STEEL, IRON, BRASS  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
EDGES = ROOT / 'icons/obj/ship_edges.dmi'
LEFT = ROOT / 'icons/mob/items/lefthand_ship_edges.dmi'
RIGHT = ROOT / 'icons/mob/items/righthand_ship_edges.dmi'
BOWSPRIT = ROOT / 'icons/obj/vehicles/ship_bowsprit.dmi'
NEST = ROOT / 'icons/obj/vehicles/ship_mast_nest.dmi'
MASTS = ROOT / 'icons/obj/vehicles/vehicleparts64x64.dmi'

SIZE = 32
BIG = 64
WIDE = 96  # the bowsprit's cell: its own tile in the middle and a tile all round
EDGE = SIZE - 1
DIRS = ('SOUTH', 'NORTH', 'EAST', 'WEST')  # DMI order for dirs = 4
KINDS = ('', '_gate', '_gate_open')
FIGURES = ('bear', 'wolf', 'goose', 'monkey', 'serpent', 'ram', 'face')
SAILS = ('sail0', 'sail1', 'sail2')
OPEN_RUN = 14    # rows of an open leaf's top edge on a SOUTH / NORTH piece
OPEN_WIDTH = 19  # width of an open leaf lying along the north end of an EAST / WEST piece

# each ramp: outline first, then shade to highlight
HULL = [(40, 26, 18), (68, 44, 28), (92, 60, 38), (114, 76, 48), (138, 96, 62), (168, 124, 84)]
PLATE = [(30, 34, 40), (56, 62, 70), (76, 84, 93), (96, 105, 115), (120, 129, 139), (158, 166, 174)]
RUST = (124, 80, 54)
DARK = (18, 14, 12)


# --- sheets ---------------------------------------------------------------------

def write_dmi(path, states, size):
    images = [im for _, _, ims in states for im in ims]
    cols = 16 if size == SIZE else 4
    sheet = Image.new('RGBA', (cols * size, ((len(images) + cols - 1) // cols) * size))
    for i, im in enumerate(images):
        sheet.paste(im, ((i % cols) * size, (i // cols) * size))
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', dmi_text(states, size), zip=True)
    sheet.save(path, format='PNG', pnginfo=meta, optimize=True)


def dmi_text(states, size):
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = %d\n\theight = %d\n' % (size, size)
    for name, keys, _ in states:
        text += 'state = "%s"\n' % name
        for key, value in keys.items():
            text += '\t%s = %s\n' % (key, value)
    return text + '# END DMI\n'


def read_states(path, size, names):
    """The frames of some four-direction states of a committed sheet."""
    sheet = Image.open(path)
    text = sheet.info['Description']
    sheet = sheet.convert('RGBA')
    cols = sheet.width // size
    out, index = {}, 0
    for name, dirs, frames in re.findall(r'state = "(.*?)"\n\tdirs = (\d+)\n\tframes = (\d+)', text):
        if name in names and name not in out:
            out[name] = [sheet.crop(((i % cols) * size, (i // cols) * size,
                                     (i % cols + 1) * size, (i // cols + 1) * size))
                         for i in range(index, index + 4)]
        index += int(dirs) * int(frames)
    return out


def four(name, ims):
    return (name, {'dirs': '4', 'frames': '1'}, ims)


# --- gunwale and bulwark --------------------------------------------------------

class Gunwale:
    """A wooden gunwale: two strakes under a capping plank."""
    name, h, pw, strip_w, leaf_w = 'gunwale', 9, 4, 5, 3

    def cap_rows(self, c, x0, x1):
        for x in range(x0, x1 + 1):
            c.put(x, 0, WOOD[5])
            c.put(x, 1, WOOD[3] if noise(x // 3, 1, 7) < 0.3 else WOOD[4])
            c.put(x, 2, WOOD[0])

    def front(self):
        c = Cv(SIZE, self.h)
        self.cap_rows(c, 0, EDGE)
        for x in range(SIZE):
            grain = noise(x // 4, 2, 5) < 0.25
            c.put(x, 3, HULL[4 if not grain else 3])
            c.put(x, 4, HULL[3])
            c.put(x, 5, HULL[1])  # the seam between her two strakes
            c.put(x, 6, HULL[3 if not noise(x // 5, 3, 5) < 0.25 else 2])
            c.put(x, 7, HULL[2])
            c.put(x, 8, HULL[0])
        for x, y in ((11, 3), (22, 6)):  # butt joints
            c.col(x, y, y + 1, HULL[1])
        for x, y in ((9, 3), (13, 3), (20, 6), (24, 6), (6, 6), (26, 3)):  # treenails
            c.put(x, y, HULL[5])
        for x0, tones in ((0, (4, 3, 0)), (29, (0, 5, 4))):  # timberheads at the tile ends
            for n, t in enumerate(tones):
                c.col(x0 + n, 3, 7, WOOD[t] if t else HULL[0])
        c.row(14, 17, 6, HULL[1])  # scupper
        c.row(14, 17, 7, DARK)
        return c

    def posts(self):
        """The two timberheads of the gangway port."""
        c = Cv(SIZE, self.h)
        for x0, tones in ((0, (4, 3, 2, 0)), (28, (0, 5, 4, 3))):
            self.cap_rows(c, x0, x0 + 3)
            for n, t in enumerate(tones):
                c.col(x0 + n, 3, 7, WOOD[t] if t else HULL[0])
            c.row(x0, x0 + 3, 8, HULL[0])
        c.put(3, 1, WOOD[0])
        c.put(28, 1, WOOD[0])
        return c

    def leaf_face(self, w, h):
        """The gate seen face on: upright boards under a top ledge."""
        c = Cv(w, h)
        for x in range(w):
            for y in range(2, h - 1):
                c.put(x, y, HULL[(4, 3, 3, 1)[x % 4]])
            c.put(x, h - 3, HULL[(5, 4, 4, 1)[x % 4]])  # the bottom ledge
        c.row(0, w - 1, 0, WOOD[5])
        c.row(0, w - 1, 1, WOOD[3])
        c.row(0, w - 1, h - 1, HULL[0])
        c.col(0, 0, h - 1, HULL[0])
        c.col(w - 1, 0, h - 1, HULL[0])
        c.put(0, 0, WOOD[4])
        return c

    def leaf_top(self, length, stile=0):
        c = Cv(self.leaf_w, length + stile)
        for y in range(length):
            c.put(0, y, WOOD[5])
            c.put(1, y, HULL[1] if y % 4 == 3 else HULL[4])
            c.put(2, y, HULL[0])
        for y in range(length, length + stile):
            c.put(0, y, HULL[4])
            c.put(1, y, HULL[3])
            c.put(2, y, HULL[0])
        if stile:
            c.row(0, 2, length + stile - 1, HULL[0])
        return c

    def run(self, length, shift=0):
        """The capping plank from above."""
        c = Cv(self.strip_w, length)
        for n in range(length):
            y = n + shift
            joint = y % 16 == 15
            for x, t in enumerate((0, 5, 4, 3, 0)):
                c.put(x, n, WOOD[2] if joint and 0 < x < 4 else WOOD[t])
            if y % 8 == 3:
                c.put(2, n, WOOD[2])  # treenail
        return c

    def end(self):
        """The south end of a strip at its full height."""
        c = Cv(self.strip_w, self.h - 2)
        h = c.h
        for x, t in enumerate((0, 5, 4, 3, 0)):
            c.put(x, 0, WOOD[t] if t else WOOD[0])
            c.put(x, 1, WOOD[max(t - 1, 0)])
        c.row(0, 4, 2, WOOD[0])
        for y in range(3, h - 1):
            for x, t in enumerate((0, 4, 3, 2, 0)):
                c.put(x, y, HULL[t])
        c.row(1, 3, 4, HULL[1])
        c.row(0, 4, h - 1, HULL[0])
        return c

    def far(self):
        """The north timberhead of a gate strip, from above."""
        c = Cv(self.strip_w, 4)
        for y in range(3):
            for x, t in enumerate((0, 5, 4, 3, 0)):
                c.put(x, y, WOOD[t])
        c.row(0, 4, 3, WOOD[0])
        return c


class Bulwark(Gunwale):
    """A steel bulwark: riveted plate under a rail."""
    name, h, pw, strip_w, leaf_w = 'bulwark', 11, 3, 4, 3

    def rail(self, c, x0, x1):
        for x in range(x0, x1 + 1):
            c.put(x, 0, STEEL[5])
            c.put(x, 1, STEEL[3])
            c.put(x, 2, PLATE[0])

    def rivet(self, c, x, y):
        c.put(x, y, PLATE[5])
        c.put(x + 1, y, PLATE[1])

    def front(self):
        c = Cv(SIZE, self.h)
        self.rail(c, 0, EDGE)
        for x in range(SIZE):
            c.put(x, 3, PLATE[4])
            for y in range(4, 9):
                c.put(x, y, PLATE[3] if noise(x // 3, y, 9) > 0.06 else PLATE[2])
            c.put(x, 9, PLATE[2])
            c.put(x, 10, PLATE[0])
        for x in range(2, 30, 4):
            self.rivet(c, x, 4)
            if not 5 <= x <= 12:
                self.rivet(c, x, 8)
        c.col(15, 3, 9, PLATE[1])  # the lap between two plates
        c.col(16, 3, 9, PLATE[4])
        for y in (6,):
            self.rivet(c, 12, y)
            self.rivet(c, 18, y)
        c.col(0, 3, 9, PLATE[4])  # frames at the tile ends
        c.col(31, 3, 9, PLATE[1])
        c.row(6, 11, 7, PLATE[1])  # freeing port
        for y in (8, 9):
            c.row(6, 11, y, DARK)
        c.put(5, 8, PLATE[1])
        c.put(12, 8, PLATE[4])
        for x, y in ((22, 9), (22, 8), (26, 9), (3, 9)):  # rust weeping from the rivets
            c.put(x, y, RUST if y == 9 else tuple((a + b) // 2 for a, b in zip(RUST, PLATE[3])))
        return c

    def posts(self):
        c = Cv(SIZE, self.h)
        for x0, tones in ((0, (4, 3, 0)), (29, (0, 5, 3))):
            self.rail(c, x0, x0 + 2)
            for n, t in enumerate(tones):
                c.col(x0 + n, 3, 9, PLATE[t])
            c.row(x0, x0 + 2, 10, PLATE[0])
        return c

    def leaf_face(self, w, h):
        c = Cv(w, h)
        for x in range(w):
            for y in range(h):
                c.put(x, y, PLATE[3] if noise(x // 3, y, 13) > 0.06 else PLATE[2])
        c.row(0, w - 1, 0, STEEL[5])
        c.row(0, w - 1, 1, PLATE[4])
        c.row(1, w - 2, h // 2, PLATE[4])  # stiffener
        c.row(1, w - 2, h // 2 + 1, PLATE[1])
        c.row(0, w - 1, h - 1, PLATE[0])
        c.col(0, 1, h - 1, PLATE[0])
        c.col(w - 1, 0, h - 1, PLATE[0])
        for x in range(2, w - 2, 4):
            self.rivet(c, x, 2)
            self.rivet(c, x, h - 3)
        return c

    def leaf_top(self, length, stile=0):
        c = Cv(self.leaf_w, length + stile)
        for y in range(length):
            c.put(0, y, STEEL[5])
            c.put(1, y, PLATE[5] if y % 4 == 1 else PLATE[3])
            c.put(2, y, PLATE[0])
        for y in range(length, length + stile):
            c.put(0, y, PLATE[4])
            c.put(1, y, PLATE[3])
            c.put(2, y, PLATE[0])
        if stile:
            c.row(0, 2, length + stile - 1, PLATE[0])
        return c

    def run(self, length, shift=0):
        c = Cv(self.strip_w, length)
        for n in range(length):
            y = n + shift
            joint = y % 16 == 15
            c.put(0, n, PLATE[0])
            c.put(1, n, PLATE[2] if joint else STEEL[5])
            c.put(2, n, PLATE[2] if joint else PLATE[5] if y % 4 == 1 else STEEL[3])
            c.put(3, n, PLATE[0])
        return c

    def end(self):
        c = Cv(self.strip_w, self.h - 2)
        h = c.h
        for x, t in enumerate((0, 5, 3, 0)):
            c.put(x, 0, STEEL[t] if t else PLATE[0])
            c.put(x, 1, STEEL[t - 1] if t else PLATE[0])
        c.row(0, 3, 2, PLATE[0])
        for y in range(3, h - 1):
            for x, t in enumerate((0, 4, 2, 0)):
                c.put(x, y, PLATE[t])
        c.put(1, 4, PLATE[5])
        c.put(1, h - 3, PLATE[5])
        c.row(0, 3, h - 1, PLATE[0])
        return c

    def far(self):
        c = Cv(self.strip_w, 4)
        for y in range(3):
            for x, t in enumerate((0, 5, 3, 0)):
                c.put(x, y, STEEL[t] if t else PLATE[0])
        c.row(0, 3, 3, PLATE[0])
        return c


def gate_front(style, opened):
    c = style.posts()
    if opened:
        return c
    x0, x1 = style.pw + 1, EDGE - style.pw - 1
    c.stamp(style.leaf_face(x1 - x0 + 1, style.h - 2), x0, 1)
    for y in (3, style.h - 4):  # hinge straps reaching from the post onto the leaf
        c.row(x0 - 2, x0 + 2, y, IRON[1])
        c.put(x0 - 1, y, IRON[4])
    y = style.h // 2  # latch
    c.row(x1 - 1, x1 + 2, y, BRASS[1])
    c.row(x1 - 1, x1 + 2, y + 1, BRASS[0])
    return c


def strip(style, kind):
    """One EAST / WEST strip, a whole tile tall."""
    c = Cv(style.strip_w, SIZE)
    end = style.end()
    length = SIZE - end.h
    if not kind:
        c.stamp(style.run(length), 0, 0)
    else:
        far = style.far()
        c.stamp(far, 0, 0)
        if kind == '_gate':
            leaf = style.leaf_top(length - far.h - 2)
            c.stamp(leaf, 1, far.h + 1)
            c.row(1, 2, far.h, IRON[1])  # hinge
            c.row(1, 2, length - 1, BRASS[1])  # latch
    c.stamp(end, 0, length)
    return c


def edge_tile(style, kind, d):
    c = Cv(SIZE, SIZE)
    h, pw = style.h, style.pw
    opened = kind == '_gate_open'
    if d in ('SOUTH', 'NORTH'):
        face = gate_front(style, opened) if kind else style.front()
        leaf = style.leaf_top(OPEN_RUN, h - 4)
        if d == 'SOUTH':
            c.stamp(face, 0, SIZE - h)
            if opened:
                c.stamp(leaf, pw + 1, EDGE - leaf.h)
                c.row(pw - 1, pw + 1, EDGE - 2, IRON[1])
        else:
            c.stamp(face.mirrored().shaded(0.86), 0, 0)
            if opened:
                c.stamp(leaf.shaded(0.92), EDGE - pw - leaf.w, 2)
                c.row(EDGE - pw - 1, EDGE - pw + 1, 4, IRON[1])
            shadow(c, h)
    else:
        piece = strip(style, kind)
        x = SIZE - piece.w if d == 'EAST' else 0
        if opened:  # the leaf lies along the north end, hinged on the far post
            leaf = style.leaf_face(OPEN_WIDTH, h - 2)
            if d == 'EAST':
                c.stamp(leaf.mirrored(), x - OPEN_WIDTH + 1, 1)
                c.row(x - 1, x + 1, 3, IRON[1])
            else:
                c.stamp(leaf, piece.w - 1, 1)
                c.row(piece.w - 2, piece.w, 3, IRON[1])
            for sx in range(SIZE):
                if c.px[sx, h - 2][3] == 255 and not c.px[sx, h - 1][3]:
                    c.put(sx, h - 1, (0, 0, 0), 60)
        c.stamp(piece, x, 0)
        if d == 'WEST':  # lit from the left: only a west side shades her own deck
            for y in range(SIZE):
                if c.px[piece.w - 1, y][3] == 255 and not c.px[piece.w, y][3]:
                    c.put(piece.w, y, (0, 0, 0), 56)
    return c.im


# --- figureheads ----------------------------------------------------------------

# o outline, 1-5 carved oak from shade to highlight, g / G gilding, k black
# paint, w white paint, r red paint, c chalk
OAK = {'o': (40, 22, 12), '1': (72, 42, 24), '2': (100, 60, 32), '3': (130, 84, 46), '4': (162, 114, 66),
       '5': (200, 158, 104), 'g': (220, 182, 76), 'G': (156, 116, 40), 'k': (22, 18, 16), 'w': (234, 228, 212),
       'r': (156, 46, 38), 'c': (226, 222, 206)}

TRUNK_F = [
    '...o43oooo32o...',
    '..o4544333322o..',
    '..o4543333221o..',
    '..o4433332221o..',
    '...o43332221o...',
    '...o43332211o...',
    '....oggggggo....',
    '....o433221o....',
    '.....o3221o.....',
    '.....o3211o.....',
    '......oooo......',
]
TRUNK_S = [
    '...o44332o......',
    '..o444333o......',
    '..o4443332o.....',
    '..o4433322o.....',
    '..o4433322o.....',
    '...o433221o.....',
    '...o433221o.....',
    '....ogggggo.....',
    '....o43321o.....',
    '....o4321o......',
    '.....o321o......',
    '.....oooo.......',
]

HEAD_F = {
    'bear': [
        '..oo........oo..',
        '.o54o.oooo.o43o.',
        '.o435o5544o332o.',
        '..o4555544433o..',
        '..o5k455443k2o..',
        '..o4554334432o..',
        '..o454o22o332o..',
        '...o4o3kk2o2o...',
        '...o3o2222o2o...',
        '....oo2rr2oo....',
    ],
    'wolf': [
        '...o........o...',
        '..o5o......o3o..',
        '..o54o.oo.o32o..',
        '..o454o55o332o..',
        '..o4554444332o..',
        '..o4k544443k2o..',
        '...o45443332o...',
        '...oo443332oo...',
        '....oo3kk2oo....',
        '.....ow22wo.....',
    ],
    'monkey': [
        '......oooo......',
        '....oo4433oo....',
        '...o44333322o...',
        '.oo4o555544o2oo.',
        'o53o5k5555k4o32o',
        'o43o55544554o22o',
        '.oo4o554455o2oo.',
        '...o45k44k42o...',
        '...oo5rrrr4oo...',
        '.....oooooo.....',
    ],
    'ram': [
        '..ooo..oo..ooo..',
        '.ogggoo44oogggo.',
        'ogGoGgo443oGgoGo',
        'ogGogGo443oGgoGo',
        'ogGGGo54443oGGGo',
        '.oooo4k44k32oooo',
        '...o45444332o...',
        '....o454432o....',
        '....oo4kk2oo....',
        '.....o3223o.....',
    ],
    'face': [
        '....ogoggogo....',
        '....oggggggo....',
        '...o45555443o...',
        '...o4kk44kk3o...',
        '...o4w5443w2o...',
        '...o455o4432o...',
        '...o44333322o...',
        '...o43rrrr22o...',
        '...o43434321o...',
        '....o343432o....',
    ],
}

HEAD_S = {
    'bear': [
        '................',
        '....oo..........',
        '...o54oooo......',
        '..o44554443o....',
        '..o455444k43oo..',
        '..o4554444333ko.',
        '..o45444333r22o.',
        '..o444333oooo...',
        '...o44332o......',
        '...o44332o......',
    ],
    'wolf': [
        '...o............',
        '..o5o...........',
        '..o54ooo........',
        '..o4554443oo....',
        '..o4554k4433oo..',
        '..o45544443333ko',
        '..o4544333wrw2o.',
        '..o44433ooooooo.',
        '...o4433o.......',
        '...o44332o......',
    ],
    'monkey': [
        '....ooooo.......',
        '...o4443335o....',
        '..o444333555o...',
        '..o4o53355k5o...',
        '..o4o4335555oo..',
        '..o44433554k5o..',
        '...o443355rr5o..',
        '...o44333oooo...',
        '...o44332o......',
        '...o44332o......',
    ],
    'ram': [
        '....oooo........',
        '...oggggo.......',
        '..ogGooGgoo.....',
        '..ogGgGoG443o...',
        '..ogGGGog4k43o..',
        '...oggGo544433o.',
        '...ooooo4443k2o.',
        '...o4433o3322o..',
        '...o44332oooo...',
        '...o44332o......',
    ],
    'face': [
        '...ogogogo......',
        '...oggggGo......',
        '..o4455554o.....',
        '..o445k5w5o.....',
        '..o44555554o....',
        '..o4455555o.....',
        '..o4443rr5o.....',
        '..o4434343o.....',
        '...o434343o.....',
        '...o44332o......',
    ],
}

WHOLE_F = {
    'goose': [
        '...oooooo.......',
        '..o555443o......',
        '..o5k44k3o......',
        '..ow4gg3wo......',
        '...oogGooo......',
        '....ogGo43o.....',
        '.....oo443o.....',
        '......o4432o....',
        '.......o432o....',
        '.......o432o....',
        '......o4432o....',
        '....oo44332oo...',
        '...o455443322o..',
        '..o4o5443322o1o.',
        '..o4o4443322o1o.',
        '...oo443322oo...',
        '....oggggggo....',
        '....o433221o....',
        '.....o3221o.....',
        '.....o3211o.....',
        '......oooo......',
    ],
    'serpent': [
        '.....oooooo.....',
        '....o554433o....',
        '...o5k5443k2o...',
        '...o45544332o...',
        '....o4w33w2o....',
        '.....o4r32o.....',
        '....oo4r3o......',
        '...o4543o.......',
        '..o45432o.......',
        '..o4543o........',
        '..o45432oooo....',
        '...o454333332o..',
        '....oo44433322o.',
        '......oooo3322o.',
        '....oooo.o3321o.',
        '...o4543oo332o..',
        '..o454333332o...',
        '...oggggggoo....',
        '....o433221o....',
        '.....o3221o.....',
        '......oooo......',
    ],
    'block': [
        '....oooooooo....',
        '...o55554444o...',
        '...o54444433o...',
        '...oooooooooo...',
        '...o44433322o...',
        '...o4c433c22o...',
        '...o4c4333c2o...',
        '...o44c33c22o...',
        '...o443cc322o...',
        '...o44333322o...',
        '...o44313322o...',
        '...o44333122o...',
        '...o41333322o...',
        '...o44333322o...',
        '...o44333322o...',
        '...oooooooooo...',
        '....o433221o....',
        '....o433221o....',
        '.....o3221o.....',
        '.....o3211o.....',
        '......oooo......',
    ],
}

# a back drawn by hand, where smoothing the front would leave its beak showing
WHOLE_B = {
    'goose': [
        '.......oooooo...',
        '......o444333o..',
        '......o443332o..',
        '......ow4332wo..',
        '......o44332o...',
        '.....o44332o....',
        '.....o4432o.....',
        '....o4432o......',
        '....o432o.......',
        '....o432o.......',
        '....o4432o......',
        '...oo44332oo....',
        '..o445443322o...',
        '.o4o4443322o1o..',
        '.o4o443o322o1o..',
        '...oo43o322oo...',
        '....oggggggo....',
        '....o433221o....',
        '.....o3221o.....',
        '.....o3211o.....',
        '......oooo......',
    ],
}

WHOLE_S = {
    'goose': [
        '.....oooo.......',
        '....o5544oo.....',
        '....o54k4ggo....',
        '....o5443oGo....',
        '....o543o.o.....',
        '....o543o.......',
        '....o543o.......',
        '....o543o.......',
        '...o4543o.......',
        '..o445433o......',
        '.o44554332o.....',
        '.o454443322o....',
        'o4544o433221o...',
        'o454o3o33221o...',
        '.o44oo332221o...',
        '..o443322211o...',
        '...oogggggo.....',
        '....o43321o.....',
        '....o4321o......',
        '.....o321o......',
        '.....oooo.......',
    ],
    'serpent': [
        '......ooooo.....',
        '.....o554443oo..',
        '....o45k444333o.',
        '....o4544ooowwo.',
        '....o454orrro...',
        '....o4543owwo...',
        '.....o454333o...',
        '....o4543ooo....',
        '...o4543o.......',
        '..o4543o........',
        '..o4543o........',
        '..o45433oo......',
        '...o4544332o....',
        '....oo443322o...',
        '......o43322o...',
        '.....o443321o...',
        '...oo443321o....',
        '...oggggggo.....',
        '....o43321o.....',
        '.....o321o......',
        '.....oooo.......',
    ],
    'block': [
        '....ooooooo.....',
        '...o5555444o....',
        '...o5444443o....',
        '...ooooooooo....',
        '...o4443322o....',
        '...o4443322o....',
        '...o4c43322o....',
        '...o44c3322o....',
        '...o443c322o....',
        '...o4433c22o....',
        '...o4433322o....',
        '...o4413322o....',
        '...o4433122o....',
        '...o4433322o....',
        '...o4433322o....',
        '...ooooooooo....',
        '....o43321o.....',
        '....o43321o.....',
        '....o4321o......',
        '.....o321o......',
        '.....oooo.......',
    ],
}


def figure_maps(name):
    if name in WHOLE_F:
        return WHOLE_F[name], WHOLE_S[name]
    return HEAD_F[name] + TRUNK_F, HEAD_S[name] + TRUNK_S


def back_of(rows):
    """The back of a figure: the same outline with its face smoothed away."""
    h, w = len(rows), len(rows[0])

    def at(x, y):
        return rows[y][x] if 0 <= x < w and 0 <= y < h else '.'

    out = []
    for y in range(h):
        solid = [x for x in range(w) if rows[y][x] != '.']
        line = ''
        for x in range(w):
            ch = rows[y][x]
            if ch == '.' or ch in 'gG':
                line += ch
                continue
            rim = any(at(x + dx, y + dy) == '.' for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if ch == 'o' and (rim or len(set(rows[y].strip('.'))) == 1):
                line += 'o'
                continue
            t = (x - solid[0]) / float(max(1, solid[-1] - solid[0]))
            tone = '4' if t < 0.3 else '3' if t < 0.62 else '2'
            if (x + y) % 5 == 0 and tone != '4':  # tool marks down its back
                tone = str(int(tone) - 1)
            line += tone
        out.append(line)
    return [row[::-1] for row in out]


def paint_map(rows, shade=1.0):
    for row in rows:
        if len(row) != 16:
            raise SystemExit('figure row is %d wide: %r' % (len(row), row))
    im = Image.new('RGBA', (SIZE, SIZE))
    px = im.load()
    top = 31 - len(rows)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != '.':
                px[8 + x, top + y] = tuple(int(v * shade) for v in OAK[ch]) + (255,)
    return im


def figure(name):
    front, side = figure_maps(name)
    east = paint_map(side)
    back = WHOLE_B.get(name) or back_of(front)
    return [paint_map(front), paint_map(back, 0.9), east, east.transpose(Image.FLIP_LEFT_RIGHT)]


# --- shaded line work: the grapnel ---------------------------------------------

HEMP = [(84, 64, 36), (132, 106, 64), (170, 144, 94), (204, 180, 128), (228, 208, 160)]
FORGED = [(14, 14, 16), (44, 46, 52), (72, 76, 84), (104, 109, 118), (150, 156, 166)]


class Ink:
    """Layers of flat shapes that are outlined and bevelled when painted."""

    def __init__(self, size=SIZE):
        self.size = size
        self.im = Image.new('RGBA', (size, size))

    def layer(self, cells, ramp, pattern=None):
        """cells: a set of (x, y). ramp: outline, shade, mid, light, glint."""
        px = self.im.load()
        cells = {(x, y) for x, y in cells if 0 <= x < self.size and 0 <= y < self.size}
        for x, y in cells:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                p = (x + dx, y + dy)
                if p not in cells and 0 <= p[0] < self.size and 0 <= p[1] < self.size:
                    px[p] = ramp[0] + (255,)
        for x, y in cells:
            lit = (x - 1, y) not in cells or (x, y - 1) not in cells
            dim = (x + 1, y) not in cells or (x, y + 1) not in cells
            t = 3 if lit and not dim else 1 if dim and not lit else 2
            if pattern and pattern(x, y):
                t = max(1, t - 1)
            px[x, y] = ramp[t] + (255,)

    def dot(self, x, y, colour):
        self.im.load()[x, y] = colour + (255,)


def path(points, thick=1):
    """The cells of a polyline; thick 2 draws a 2x2 pen."""
    cells = set()
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            x = int(round(x0 + (x1 - x0) * i / float(n)))
            y = int(round(y0 + (y1 - y0) * i / float(n)))
            for dx in range(thick):
                for dy in range(thick):
                    cells.add((x + dx, y + dy))
    return cells


def ring(cx, cy, rx, ry, width=1.0):
    cells = set()
    for y in range(SIZE):
        for x in range(SIZE):
            d = math.hypot((x - cx) / rx, (y - cy) / ry)
            if 1.0 - width / min(rx, ry) <= d <= 1.0:
                cells.add((x, y))
    return cells


def grapnel():
    ink = Ink()

    def twist(x, y):
        return (x + 2 * y) % 4 == 0

    # the coil of line lying on the deck, three turns
    ink.layer(ring(12.5, 22.5, 9.4, 5.6, 2.0), HEMP, twist)
    ink.layer(ring(12.5, 22.0, 6.4, 3.4, 1.6), HEMP, twist)
    ink.layer(path([(19, 19), (18, 17), (16, 16)]), HEMP, twist)  # the bight up to the eye
    # the shank, from the eye up to the crown
    ink.layer(path([(15, 15), (22, 8)], 2), FORGED)
    ink.layer(ring(14.5, 16.5, 2.4, 2.4, 1.2), FORGED)  # the eye
    # four flukes curling back from the crown
    ink.layer(path([(23, 8), (21, 5), (18, 4), (15, 5), (14, 7)], 2), FORGED)
    ink.layer(path([(24, 9), (27, 11), (28, 14), (27, 17), (25, 18)], 2), FORGED)
    ink.layer(path([(24, 7), (26, 5), (28, 5), (29, 7)], 1), FORGED)
    ink.layer(path([(22, 10), (22, 13), (20, 14)], 1), FORGED)
    for x, y in ((14, 8), (25, 19), (29, 8), (19, 14)):  # the barbed points
        ink.dot(x, y, FORGED[3])
    for x, y in ((17, 13), (19, 11), (21, 9), (19, 4), (27, 12)):  # glints along the iron
        ink.dot(x, y, FORGED[4])
    return ink.im


def held(hand_x, hand_y):
    """The coil in the fist and the hook hanging under it."""
    ink = Ink()
    ink.layer(ring(hand_x + 0.5, hand_y + 0.5, 2.6, 3.2, 1.2), HEMP, lambda x, y: (x + y) % 3 == 0)
    hook = path([(hand_x, hand_y + 4), (hand_x, hand_y + 7)])
    hook |= {(hand_x - 1, hand_y + 7), (hand_x - 2, hand_y + 6), (hand_x - 2, hand_y + 5),
             (hand_x + 1, hand_y + 7), (hand_x + 2, hand_y + 6), (hand_x + 2, hand_y + 5)}
    ink.layer(hook, FORGED)
    ink.dot(hand_x, hand_y + 5, FORGED[4])
    return ink.im


def held_states():
    blank = Image.new('RGBA', (SIZE, SIZE))
    # hand positions follow the mattock in lefthand_earthworking.dmi
    left = [held(23, 20), held(8, 20), held(21, 21), blank]
    right = [held(8, 20), held(23, 20), blank, held(10, 21)]
    return [four('grapnel', left)], [four('grapnel', right)]


# --- 64x64: the bowsprit --------------------------------------------------------

SPAR = [(66, 42, 14), (84, 54, 18), (110, 77, 40), (132, 96, 56)]
CHOCK = [(40, 24, 8), (60, 38, 12), (84, 54, 18), (104, 70, 30)]
CANVAS = [(132, 126, 118), (158, 153, 146), (181, 177, 172), (198, 195, 190)]
SAILCLOTH = [(150, 147, 142), (172, 172, 170), (187, 187, 187), (200, 200, 200)]
GASKET = [(90, 70, 52), (113, 92, 74), (147, 123, 98), (160, 138, 112)]
LINE = [(110, 88, 52), (140, 116, 74), (176, 152, 104), (204, 182, 132)]
BAND = [(20, 21, 24), (44, 46, 51), (72, 76, 84), (118, 123, 132)]
RAMPS = {'spar': SPAR, 'chock': CHOCK, 'canvas': CANVAS, 'sail': SAILCLOTH, 'gasket': GASKET, 'line': LINE,
         'band': BAND}
# materials drawn as one body: a part is lit and shaded against the others
GROUP = {'spar': 'spar', 'band': 'spar', 'line': 'spar', 'chock': 'chock', 'canvas': 'canvas',
         'gasket': 'canvas', 'sail': 'sail', 'sheet': 'sheet'}
RAMPS['sheet'] = LINE
# the way a bowsprit points, then the way to its starboard side
AXES = {'NORTH': ((0, -1), (1, 0)), 'SOUTH': ((0, 1), (-1, 0)), 'EAST': ((1, 0), (0, 1)),
        'WEST': ((-1, 0), (0, -1))}


JIB_TACK = 42  # pixels ahead of the step where the jib is tacked down


def jib_reach(fi):
    """How far to starboard the set jib bellies, fi pixels ahead of the step."""
    return int(round(15.0 * ((JIB_TACK - fi) / 40.0) ** 0.75))


def bowsprit_cells(state):
    """{(fi, ri): material}: fi counts pixels ahead of the step at the middle
    of her tile, ri to starboard. The tile ends 16 ahead, so the spar stands
    28 pixels out over the next one whichever way it points."""
    cells = {}
    for fi in range(-14, 44):
        half = 2 if fi < 20 else 1
        for ri in range(-half, half):
            cells[fi, ri] = 'spar'
    for fi in range(-14, -11):  # the heel chock
        for ri in range(-3, 3):
            cells[fi, ri] = 'chock'
    for fi in (11, 13, 15):  # the gammoning lashing her to the stem
        for ri in range(-2, 2):
            cells[fi, ri] = 'line'
    for ri in range(-2, 2):
        cells[19, ri] = 'band'
    for fi in (42, 43):
        for ri in range(-1, 1):
            cells[fi, ri] = 'band'
    if state == 'sail1':  # the jib furled along the spar under its gaskets
        for fi in range(18, 41):
            wide = 2 if 19 <= fi <= 38 else 1
            for ri in range(-wide, wide):
                cells[fi, ri] = 'gasket' if fi % 5 == 1 else 'canvas'
        for fi in (23, 28, 33):  # the canvas bulges between gaskets
            cells[fi, 2] = 'canvas'
    elif state == 'sail2':  # the jib set, bellying to starboard from tack to clew
        for fi in range(2, JIB_TACK):
            luff = 2 if fi < 20 else 1
            for ri in range(luff, max(luff, jib_reach(fi)) + 1):
                cells[fi, ri] = 'sail'
        for ri in range(3, 15):  # the sheet, from her clew in to the deck
            cells[0 if ri < 9 else 1, ri] = 'sheet'
    return cells


def bowsprit(state, d):
    (fx, fy), (rx, ry) = AXES[d]
    grid = {}
    for (fi, ri), mat in bowsprit_cells(state).items():
        x = int(47.5 + (ri + 0.5) * rx + (fi + 0.5) * fx)
        y = int(47.5 + (ri + 0.5) * ry + (fi + 0.5) * fy)
        grid[x, y] = (mat, fi, ri)
    im = Image.new('RGBA', (WIDE, WIDE))
    px = im.load()

    def group(p):
        return GROUP[grid[p][0]] if p in grid else None

    for (x, y), (mat, fi, ri) in grid.items():
        g = group((x, y))
        lit = group((x - 1, y)) != g or group((x, y - 1)) != g
        dim = group((x + 1, y)) != g or group((x, y + 1)) != g
        t = 3 if lit and not dim else 1 if dim and not lit else 2
        if mat == 'spar' and t == 2 and noise(fi // 3, ri, 17) < 0.35:
            t = 1
        if mat == 'line' and (fi + ri) % 2:
            t = max(1, t - 1)
        if mat == 'sail':
            if (jib_reach(fi) - ri) % 5 == 4 and ri > 2:
                t = 1  # the seams of her cloths, parallel to the leech
            elif t == 1:
                t = 0  # bolt rope along leech and foot
            elif noise(fi, ri, 23) < 0.2:
                t = 3
        if mat == 'sheet':
            t = 2 if (fi + ri) % 2 else 1
        px[x, y] = RAMPS[mat][t] + (255,)
    return im


# --- 64x64: the mast with a crow's nest -----------------------------------------

TUB = {'o': (46, 28, 10), 's': (154, 112, 66), 'm': (122, 89, 53), 'd': (84, 54, 18), 'i': (52, 32, 12),
       'f': (104, 72, 38), 'F': (86, 58, 28), 'h': (60, 62, 68), 'M': (196, 118, 78), 'c': (75, 47, 15)}


def nest():
    """A round lookout tub from above: hooped staves, the floor and the masthead."""
    c = Cv(13, 13)
    for y in range(13):
        for x in range(13):
            dx, dy = x - 6, y - 6
            d = math.hypot(dx, dy)
            if d > 6.4:
                continue
            if d > 5.5:
                ch = 'o'
            elif d > 4.4:  # the staves, lit from the top left
                side = (dx + dy) / max(d, 1.0)
                ch = 's' if side < -0.5 else 'd' if side > 0.6 else 'm'
                if (int(round(math.degrees(math.atan2(dy, dx)))) // 30) % 2 and ch != 'd':
                    ch = 'm' if ch == 's' else 'd'
            elif d > 3.5:
                ch = 'i'  # the shadow inside her wall
            elif d > 1.6:
                ch = 'F' if y % 2 else 'f'  # floor boards
            else:
                ch = 'M' if d > 0.5 else 'c'  # the masthead
            c.put(x, y, TUB[ch])
    for x, y in ((4, 8), (8, 9)):  # the lubber's hole and a knot
        c.put(x, y, TUB['i'])
    return c


def masthead(im, d):
    """Where the mast stands in one frame of the bare mast: the knob beside the yard."""
    x0, y0, x1, y1 = im.getbbox()
    alpha = im.getchannel('A').load()
    if d in ('SOUTH', 'NORTH'):
        y = y0 if d == 'SOUTH' else y1 - 1
        xs = [x for x in range(x0, x1) if alpha[x, y]]
        return (xs[0] + xs[-1]) // 2, y + (2 if d == 'SOUTH' else -2)
    x = x0 if d == 'EAST' else x1 - 1
    ys = [y for y in range(y0, y1) if alpha[x, y]]
    return x + (2 if d == 'EAST' else -2), (ys[0] + ys[-1]) // 2


def nest_states():
    masts = read_states(MASTS, BIG, SAILS)
    tub = nest()
    out = []
    for name in SAILS:
        ims = []
        for d, bare, im in zip(DIRS, masts['sail0'], masts[name]):
            cx, cy = masthead(bare, d)
            c = Cv(BIG, BIG)
            c.im = im.copy()
            c.px = c.im.load()
            for dy in range(13):  # a soft shadow under the tub, falling to the lower right
                for dx in range(13):
                    if tub.px[dx, dy][3]:
                        x, y = cx - 6 + dx + 2, cy - 6 + dy + 2
                        if 0 <= x < BIG and 0 <= y < BIG and not c.px[x, y][3]:
                            c.put(x, y, (0, 0, 0), 50)
            c.stamp(tub, cx - 6, cy - 6)
            ims.append(c.im)
        out.append(four(name, ims))
    return out


# --- every sheet ----------------------------------------------------------------

def edge_states():
    states = []
    for style in (Gunwale(), Bulwark()):
        for kind in KINDS:
            states.append(four(style.name + kind, [edge_tile(style, kind, d) for d in DIRS]))
    states.append(four('figurehead', figure('block')))
    for name in FIGURES:
        states.append(four('figurehead_' + name, figure(name)))
    states.append(('grapnel', {'dirs': '1', 'frames': '1'}, [grapnel()]))
    return states


def build():
    left, right = held_states()
    return [
        (EDGES, SIZE, edge_states()),
        (LEFT, SIZE, left),
        (RIGHT, SIZE, right),
        (BOWSPRIT, WIDE, [four(name, [bowsprit(name, d) for d in DIRS]) for name in SAILS]),
        (NEST, BIG, nest_states()),
    ]


# --- checks ---------------------------------------------------------------------

def check_drawing(sheets):
    problems = []
    by_path = {path: states for path, _, states in sheets}
    for name, keys, ims in by_path[EDGES]:
        if keys['dirs'] == '4' and len({im.tobytes() for im in ims}) != 4:
            problems.append('%s: needs four different directions' % name)
        for d, im in zip(DIRS, ims):
            box = im.getchannel('A').getbbox()
            if not box:
                problems.append('%s %s: empty' % (name, d))
                continue
            x0, y0, x1, y1 = box
            if name.startswith(('gunwale', 'bulwark')):
                if not {'SOUTH': y1 == SIZE, 'NORTH': y0 == 0, 'EAST': x1 == SIZE, 'WEST': x0 == 0}[d]:
                    problems.append('%s %s: does not reach its edge' % (name, d))
                reach = {'SOUTH': SIZE - y0, 'NORTH': y1, 'EAST': SIZE - x0, 'WEST': x1}[d]
                limit = 28 if name.endswith('_open') else 14 if d in ('SOUTH', 'NORTH') else 7
                if reach > limit:
                    problems.append('%s %s: reaches %d px into the tile' % (name, d, reach))
                if d in ('SOUTH', 'NORTH') and (x0, x1) != (0, SIZE):
                    problems.append('%s %s: does not span the tile' % (name, d))
                if d in ('EAST', 'WEST') and (y0, y1) != (0, SIZE):
                    problems.append('%s %s: does not span the tile' % (name, d))
            elif y1 > SIZE - 1 or y0 < 2:
                problems.append('%s %s: leaves its tile' % (name, d))
    for path in (BOWSPRIT, NEST):
        states = by_path[path]
        if [name for name, _, _ in states] != list(SAILS):
            problems.append('%s: needs the states %s' % (path.name, ', '.join(SAILS)))
        frames = [im.tobytes() for _, _, ims in states for im in ims]
        if len(set(frames)) != len(frames):
            problems.append('%s: two frames are the same' % path.name)
    for name, _, ims in by_path[BOWSPRIT]:
        for d, im in zip(DIRS, ims):
            x0, y0, x1, y1 = im.getbbox()
            tip = {'SOUTH': WIDE - y1, 'NORTH': y0, 'EAST': WIDE - x1, 'WEST': x0}[d]
            heel = {'SOUTH': y0, 'NORTH': WIDE - y1, 'EAST': x0, 'WEST': WIDE - x1}[d]
            # her own tile is the middle 32 pixels: the spar is stepped inside
            # it and stands most of a tile out over the next one
            if tip > 6 or not SIZE <= heel < SIZE + 6:
                problems.append('bowsprit %s %s: tip %d and heel %d px from the cell edges' % (name, d, tip, heel))
    bare = read_states(MASTS, BIG, SAILS)
    for name, _, ims in by_path[NEST]:
        for d, im, mast in zip(DIRS, ims, bare[name]):
            changed = sum(1 for a, b in zip(im.tobytes()[3::4], mast.tobytes()[3::4]) if a != b)
            if not changed:
                problems.append('crow\'s nest %s %s: no nest on the mast' % (name, d))
    return problems


def check_sheets(sheets):
    problems = []
    for path, size, states in sheets:
        if not path.exists():
            problems.append('%s is missing' % path)
            continue
        sheet = Image.open(path)
        if sheet.info.get('Description', '') != dmi_text(states, size):
            problems.append('%s: states differ from the drawing' % path.name)
            continue
        sheet = sheet.convert('RGBA')
        cols = sheet.width // size
        i = 0
        for name, _, ims in states:
            for d, im in enumerate(ims):
                box = ((i % cols) * size, (i // cols) * size, (i % cols + 1) * size, (i // cols + 1) * size)
                if sheet.crop(box).tobytes() != im.tobytes():
                    problems.append('%s %s %d: committed pixels differ from the drawing' % (path.name, name, d))
                i += 1
    return problems


def backdrop(w, h, colour, seed):
    im = Image.new('RGBA', (w, h), colour + (255,))
    px = im.load()
    for y in range(h):
        for x in range(w):
            n = noise(x, y, seed)
            shift = -8 if n < 0.14 else 6 if n > 0.9 else 0
            if y % 8 == 7:
                shift -= 14  # deck seams
            px[x, y] = tuple(max(0, c + shift) for c in colour) + (255,)
    return im


def write_preview(path, sheets, scale=4):
    """Every state and direction in rows, on deck planking and on water."""
    rows = []
    for sheet_path, size, states in sheets:
        for name, _, ims in states:
            rows.append((size, name, ims))
    width = max(sum(size + 4 for _ in ims) for size, _, ims in rows) + 4
    height = sum(size + 4 for size, _, _ in rows) + 4
    out = Image.new('RGBA', (width, height), (30, 30, 34, 255))
    y = 4
    for size, name, ims in rows:
        x = 4
        for im in ims:
            ground = (58, 92, 122) if size != SIZE else (128, 96, 62)
            out.alpha_composite(backdrop(size, size, ground, 40), (x, y))
            if size == WIDE:  # her own tile, in the middle of the cell
                out.alpha_composite(backdrop(SIZE, SIZE, (128, 96, 62), 40), (x + SIZE, y + SIZE))
            out.alpha_composite(im, (x, y))
            x += size + 4
        y += size + 4
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    out.convert('RGB').resize((out.width * scale, out.height * scale), Image.NEAREST).save(path)


def main():
    sheets = build()
    problems = check_drawing(sheets)
    if '--check' in sys.argv:
        problems += check_sheets(sheets)
        for line in problems:
            print(line)
        print('ship edges: %s' % ('FAILED' if problems else 'ok'))
        return 1 if problems else 0
    if problems:
        print('\n'.join(problems))
        return 1
    for path, size, states in sheets:
        write_dmi(path, states, size)
    if option('--preview'):
        write_preview(option('--preview'), sheets)
    return 0


if __name__ == '__main__':
    sys.exit(main())
