"""Hand-placed sprites for the small ancient items:

  icons/obj/small_ancient.dmi (32x32): the wet and the fired clay tablet, each
      blank and with pressed wedge marks, the cut reed stylus, the senet board
      and the chessboard with a few pieces on them, and the straw-packed ice
      house, shut and open.

Every pixel is placed by this script from the fixed palettes below (Pillow
only); no external or generated artwork. The wet tablet uses the unfired greys
and the fired tablet the fired reds of the pottery in claystuff.dmi, the ice
house the timber of the wooden crate in crate.dmi, so the pieces sit beside
the existing ones. Items are drawn small and centred like the paper; the ice
house fills the tile as a crate does. Things are seen
three-quarters from above with the light from the upper left.

Run with Pillow to reproduce the sheet. `--check` verifies the committed sheet
matches and `--preview <png>` writes a 4x review sheet with every state
labelled. Released under Civ13 AGPL-3.0.
"""
import re
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SMALL_ANCIENT = ROOT / 'icons/obj/small_ancient.dmi'

SIZE = 32

# unfired clay (claystuff.dmi's unfired pots), damp glint first, light to dark
WET = [(186, 178, 176), (158, 148, 145), (141, 131, 130), (133, 123, 123), (125, 116, 117), (117, 112, 113),
       (107, 102, 103), (86, 80, 82)]
# fired clay (claystuff.dmi's pots and bricks) under a warmer terracotta light, light to dark
FIRED = [(196, 112, 74), (178, 96, 66), (160, 84, 62), (142, 74, 60), (122, 64, 56), (100, 55, 55),
         (77, 47, 50), (54, 33, 37)]
# cut reed
REED = [(232, 214, 150), (206, 182, 112), (170, 144, 80), (128, 102, 52), (84, 64, 30)]
# the wooden crate's timber, light to dark
WOOD = [(197, 140, 98), (186, 119, 68), (164, 104, 60), (148, 94, 54), (128, 81, 47), (108, 69, 40),
        (94, 60, 32), (69, 44, 24), (49, 33, 17)]
# dark board wood (ebony and walnut)
DARK = [(104, 70, 50), (82, 52, 38), (62, 38, 28), (44, 27, 20), (30, 18, 14)]
# ivory and boxwood
IVORY = [(250, 242, 220), (232, 218, 186), (204, 186, 148), (166, 146, 110)]
# the pale inlaid squares of a board
BOARD = [(226, 196, 140), (204, 170, 112), (176, 140, 88)]
# blue faience
FAIENCE = [(132, 208, 214), (62, 150, 172), (32, 98, 128), (20, 62, 90)]
# brass, glint to shadow
BRASS = [(255, 232, 150), (240, 192, 92), (204, 150, 56), (160, 110, 36), (116, 76, 24), (76, 48, 16)]
# straw
STRAW = [(240, 216, 136), (214, 182, 98), (178, 142, 66), (136, 104, 44), (96, 72, 30)]
# packed ice
ICE = [(250, 253, 255), (222, 238, 248), (186, 214, 236), (144, 180, 212), (104, 140, 180)]
IRON = [(116, 120, 134), (86, 90, 104), (62, 64, 78), (42, 44, 54)]
INK = (37, 21, 14)                   # the darkest outline


def noise(x, y, seed=0):
    """A fixed pseudo-random number 0..255, the same on every run."""
    v = (x * 73856093) ^ (y * 19349663) ^ (seed * 2654435761)
    v = (v ^ (v >> 13)) * 1274126177
    return ((v ^ (v >> 16)) >> 4) & 255


# ----------------------------------------------------------------- drawing --

def new():
    return Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))


def put(im, x, y, c, a=255):
    if 0 <= x < SIZE and 0 <= y < SIZE and c is not None:
        im.putpixel((x, y), (c[0], c[1], c[2], c[3] if len(c) > 3 else a))


def rect(im, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(im, x, y, c)


def step(ramp, i):
    return ramp[max(0, min(len(ramp) - 1, int(i)))]


def outline(im, c):
    """A one pixel dark line around the drawn work."""
    src = im.copy()
    for y in range(SIZE):
        for x in range(SIZE):
            if src.getpixel((x, y))[3]:
                continue
            for ax, ay in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= ax < SIZE and 0 <= ay < SIZE and src.getpixel((ax, ay))[3]:
                    put(im, x, y, c)
                    break
    return im


# ------------------------------------------------------------ clay tablets --

TAB_X0, TAB_X1 = 10, 22              # the face and the edge below it
TAB_Y0, TAB_Y1, TAB_EDGE = 9, 20, 22
# rows of marks, a pixel apart: v an upright wedge, h a lying wedge, a an angled pair
WEDGES = ['vhav', 'ahvv', 'hvvh', 'vah']
WEDGE_ROWS = (10, 13, 16, 19)


def tablet(fired=False, words=False):
    im = new()
    ramp = FIRED if fired else WET
    for y in range(TAB_Y0, TAB_EDGE + 1):
        for x in range(TAB_X0, TAB_X1 + 1):
            corner = x in (TAB_X0, TAB_X1) and y in (TAB_Y0, TAB_EDGE)
            if corner:
                continue
            if y > TAB_Y1:                                  # the thick lower edge
                i = 5 + (y - TAB_Y1 - 1) + (1 if x > 18 else 0)
            else:
                i = 2 + (x - TAB_X0 + y - TAB_Y0) / 9.0     # pillowed face, lit upper left
                if x == TAB_X0 or y == TAB_Y0:
                    i -= 1                                  # raised rim catching the light
                if x == TAB_X1 or y == TAB_Y1:
                    i += 1
                if fired:
                    n = noise(x, y, 3)                      # dry, grainy and matte
                    i += 1 if n < 50 else (-1 if n > 225 else 0)
            put(im, x, y, step(ramp, max(1, i)))
    if not fired:                                           # the damp sheen
        for x, y in ((12, 13), (13, 12), (14, 11), (15, 10), (13, 14), (14, 13), (15, 12), (16, 11)):
            put(im, x, y, WET[1])
        for x, y in ((13, 13), (14, 12), (15, 11)):
            put(im, x, y, WET[0])
        for x, y in ((18, 18), (19, 17), (20, 16)):
            put(im, x, y, WET[2])
    else:                                                   # a pit and a chipped corner
        put(im, 19, 12, FIRED[5])
        put(im, 21, 20, FIRED[6])
    if words:
        head, tail = ramp[7], ramp[6]
        for row, y in zip(WEDGES, WEDGE_ROWS):
            x = TAB_X0 + 2
            for mark in row:
                if mark == 'v':
                    put(im, x, y, head)
                    put(im, x, y + 1, tail)
                elif mark == 'h':
                    put(im, x, y, head)
                    put(im, x + 1, y, tail)
                    x += 1
                elif mark == 'a':
                    put(im, x, y + 1, head)
                    put(im, x + 1, y, tail)
                    x += 1
                x += 2
    return outline(im, ramp[7])


# ------------------------------------------------------------------ stylus --

def stylus():
    """A reed lying from lower left (the cut wedge tip) to upper right."""
    im = new()
    for k in range(13):                                     # the stem, lit along its upper side
        x, y = 11 + k, 20 - k
        node = k in (4, 9)
        put(im, x, y, REED[2] if node else REED[0] if k % 3 == 1 else REED[1])
        put(im, x + 1, y, REED[4] if node else REED[2])
        put(im, x + 1, y + 1, REED[4] if node else REED[3])
    put(im, 24, 7, REED[3])                                 # the hollow cut top
    put(im, 24, 8, REED[4])
    for x, y, c in ((10, 21, REED[1]), (11, 21, REED[2]), (11, 22, REED[3]), (9, 22, REED[1]), (10, 22, REED[2]),
                    (8, 23, REED[2]), (9, 23, REED[3]), (10, 23, REED[3]), (7, 24, WET[4]), (8, 24, WET[5]),
                    (9, 24, WET[6]), (10, 24, REED[4])):    # the broad wedge, clay on its edge
        put(im, x, y, c)
    return outline(im, REED[4])


# ------------------------------------------------------------------- senet --

SENET_X0, SENET_Y0 = 1, 11                                  # first square, top left


def senet_square(col, row):
    return SENET_X0 + col * 3, SENET_Y0 + row * 3


def cone(im, col, row, ramp):
    x, y = senet_square(col, row)
    put(im, x, y + 1, ramp[1])
    put(im, x + 1, y + 1, ramp[2])
    put(im, x, y, ramp[0])
    put(im, x + 1, y, ramp[2])
    put(im, x, y - 1, ramp[0])
    put(im, x + 1, y - 1, ramp[1])
    put(im, x, y - 2, ramp[0])


def spool(im, col, row, ramp):
    x, y = senet_square(col, row)
    put(im, x, y + 1, ramp[1])
    put(im, x + 1, y + 1, ramp[3])
    put(im, x, y, ramp[2])
    put(im, x + 1, y, ramp[3])
    put(im, x, y - 1, ramp[0])
    put(im, x + 1, y - 1, ramp[1])


def senet():
    im = new()
    rect(im, 0, 10, 30, 19, DARK[2])                        # the frame and the lines between squares
    rect(im, 0, 10, 30, 10, DARK[1])
    for row in range(3):
        for col in range(10):
            x, y = senet_square(col, row)
            rect(im, x, y, x + 1, y + 1, BOARD[1])
            put(im, x, y, BOARD[0])
            put(im, x + 1, y + 1, BOARD[2])
    for col, row, c in ((4, 1, FAIENCE[1]), (5, 2, (176, 60, 44)), (6, 2, FAIENCE[1]), (7, 2, (176, 60, 44)),
                        (8, 2, FAIENCE[1])):                # the marked houses
        x, y = senet_square(col, row)
        put(im, x, y + 1, c)
        put(im, x + 1, y, c)
    rect(im, 0, 20, 30, 23, DARK[3])                        # the box side
    rect(im, 0, 20, 30, 20, DARK[2])
    rect(im, 0, 23, 30, 23, DARK[4])
    rect(im, 20, 20, 29, 22, DARK[1])                       # the drawer front
    rect(im, 20, 20, 29, 20, DARK[0])
    rect(im, 19, 20, 19, 23, DARK[4])
    rect(im, 24, 21, 25, 21, BRASS[1])                      # its knob
    put(im, 25, 22, BRASS[4])
    cone(im, 0, 0, IVORY)
    spool(im, 1, 0, FAIENCE)
    cone(im, 2, 0, IVORY)
    spool(im, 6, 0, FAIENCE)
    cone(im, 3, 1, IVORY)
    spool(im, 8, 1, FAIENCE)
    cone(im, 1, 2, IVORY)
    outline(im, INK)
    rect(im, 31, 0, 31, 31, (0, 0, 0, 0))                   # the frame is its own edge at the sides
    return im


# ------------------------------------------------------------------- chess --

CHESS_X0, CHESS_Y0 = 8, 7                                   # first square, top left
LIGHT_MEN = [(236, 112, 70), (190, 62, 40), (128, 36, 28)]      # red-stained wood
DARK_MEN = [(92, 84, 92), (44, 38, 44), (22, 18, 22)]           # ebony


def chess_square(col, row):
    return CHESS_X0 + col * 2, CHESS_Y0 + row * 2


def chessman(im, col, row, ramp, tall=0, crown=None):
    """A turned piece standing on its square, rising over the squares behind."""
    x, y = chess_square(col, row)
    put(im, x, y + 1, ramp[1])                              # the foot
    put(im, x + 1, y + 1, ramp[2])
    for k in range(tall + 1):                               # the stem
        put(im, x, y - k, ramp[0])
        put(im, x + 1, y - k, ramp[1])
    top = y - tall - 1
    if crown == 'king':                                     # a cross
        put(im, x, top, ramp[0])
        put(im, x, top - 1, ramp[0])
    elif crown == 'rook':                                   # a flat battlement
        put(im, x, top, ramp[0])
        put(im, x + 1, top, ramp[0])
    elif crown == 'bishop':                                 # a pointed mitre
        put(im, x + 1, top, ramp[0])
    else:                                                   # a pawn's round head
        put(im, x, top, ramp[0])


def chess():
    im = new()
    rect(im, 7, 6, 24, 23, WOOD[6])                         # the frame
    rect(im, 7, 6, 24, 6, WOOD[4])
    rect(im, 7, 6, 7, 23, WOOD[4])
    for row in range(8):
        for col in range(8):
            x, y = chess_square(col, row)
            pale = (row + col) % 2 == 0
            rect(im, x, y, x + 1, y + 1, BOARD[0] if pale else WOOD[4])
            put(im, x, y, IVORY[1] if pale else WOOD[3])
    rect(im, 7, 24, 24, 25, WOOD[7])                        # the board's front edge
    rect(im, 7, 24, 24, 24, WOOD[6])
    chessman(im, 4, 0, DARK_MEN, 1, 'king')
    chessman(im, 0, 0, DARK_MEN, 1, 'rook')
    chessman(im, 2, 2, DARK_MEN)
    chessman(im, 6, 3, DARK_MEN, 1, 'bishop')
    chessman(im, 3, 5, LIGHT_MEN)
    chessman(im, 1, 6, LIGHT_MEN, 1, 'bishop')
    chessman(im, 5, 7, LIGHT_MEN, 1, 'king')
    chessman(im, 7, 6, LIGHT_MEN, 1, 'rook')
    return outline(im, INK)


# --------------------------------------------------------------- ice house --

def timber(im, x0, y0, x1, y1, base, upright, seed):
    """A beam: grain along its length, lit on its upper or left edge."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            i = base
            along, across, first, last = (y, x, x0, x1) if upright else (x, y, y0, y1)
            if across == first:
                i -= 1
            if across == last and last > first:
                i += 1
            if noise(along // 3, across, seed) < 60:
                i += 1
            put(im, x, y, step(WOOD, i))


def straw(im, x0, y0, x1, y1, seed, shade=0):
    """Packed straw: short stalks lying every way."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            n = noise(x + (y % 2), y // 2, seed)
            i = 1 + shade + (0 if n < 70 else 1 if n < 170 else 2 if n < 235 else 3)
            if noise(x, y, seed + 1) < 26:
                i = shade
            put(im, x, y, step(STRAW, i))


def ice_body(im):
    """The box below the lid: straw between timber posts and rails."""
    straw(im, 6, 16, 25, 24, 11)
    rect(im, 3, 15, 28, 15, WOOD[8])                        # the shadow under the lid
    for x in range(6, 26):
        if noise(x, 16, 5) < 150:
            put(im, x, 16, STRAW[3])
    timber(im, 6, 20, 25, 20, 4, False, 21)                 # a lath holding the straw in
    timber(im, 3, 16, 5, 27, 3, True, 22)                   # corner posts
    timber(im, 26, 16, 28, 27, 4, True, 23)
    timber(im, 15, 16, 16, 24, 3, True, 24)                 # middle post
    timber(im, 3, 25, 28, 27, 4, False, 25)                 # sill
    for x in (4, 15, 27):                                   # pegs
        put(im, x, 26, WOOD[8])
        put(im, x, 17, WOOD[8])
    for x, y in ((8, 25), (13, 25), (19, 25), (23, 25)):    # straw worked out over the sill
        put(im, x, y, STRAW[1])


def ice_house(opened=False):
    im = new()
    ice_body(im)
    if not opened:
        timber(im, 2, 7, 29, 8, 1, False, 31)               # the heavy lid's top, three boards
        timber(im, 2, 9, 29, 10, 1, False, 32)
        timber(im, 2, 11, 29, 11, 2, False, 33)
        timber(im, 6, 7, 8, 11, 3, True, 34)                # battens across them
        timber(im, 23, 7, 25, 11, 3, True, 35)
        timber(im, 2, 12, 29, 14, 5, False, 36)             # its thick front edge
        rect(im, 2, 14, 29, 14, WOOD[7])
        for x in (7, 24):
            put(im, x, 8, IRON[2])
            put(im, x, 10, IRON[2])
        rect(im, 14, 9, 17, 9, IRON[1])                     # the iron lifting ring
        put(im, 13, 10, IRON[1])
        put(im, 18, 10, IRON[1])
        rect(im, 14, 11, 17, 11, IRON[2])
        put(im, 14, 9, IRON[0])
        for x in (4, 5, 11, 12, 19, 20, 26):                # straw squeezed out under the lid
            put(im, x, 15, STRAW[1 + (x % 2)])
        for x in (5, 12, 20):
            put(im, x, 16, STRAW[0])
    else:
        timber(im, 2, 1, 29, 6, 6, False, 41)               # the lid stood up behind, underside out
        timber(im, 2, 1, 29, 1, 3, False, 42)
        timber(im, 6, 2, 8, 6, 5, True, 43)
        timber(im, 23, 2, 25, 6, 5, True, 44)
        straw(im, 10, 3, 21, 5, 45, 1)                      # straw matting pinned under it
        timber(im, 3, 7, 28, 7, 2, False, 46)               # the far rim
        rect(im, 4, 8, 27, 13, WOOD[8])                     # the well
        straw(im, 4, 8, 27, 13, 47)
        rect(im, 4, 8, 27, 8, STRAW[4])                     # shade under the far rim
        for by in (9, 11):                                  # two courses of sawn ice blocks
            off = 3 if by == 11 else 0
            for bx in range(6 - off, 26, 6):
                x0, x1 = max(bx, 6), min(bx + 4, 25)
                rect(im, x0, by, x1, by + 1, ICE[1])
                rect(im, x0, by, x1 - 1, by, ICE[0])
                rect(im, x0 + 1, by + 1, x1, by + 1, ICE[2])
                if x1 < 25:
                    rect(im, x1 + 1, by, x1 + 1, by + 1, ICE[4])
        rect(im, 6, 13, 25, 13, ICE[3])                     # their sawn near faces
        for x in (8, 14, 20):
            put(im, x, 13, ICE[4])
        for x, y in ((7, 9), (16, 11), (19, 9)):            # glints
            put(im, x, y, (255, 255, 255))
        for x, y in ((11, 10), (17, 12), (22, 10), (9, 12)):  # loose straw on the ice
            put(im, x, y, STRAW[1])
        timber(im, 3, 14, 28, 15, 2, False, 48)             # the near rim
        timber(im, 3, 8, 3, 13, 3, True, 49)                # side rims
        timber(im, 28, 8, 28, 13, 5, True, 50)
        for x in (5, 12, 20):
            put(im, x, 16, STRAW[0])
    return outline(im, WOOD[8])


# ------------------------------------------------------------------ sheets --

def small_ancient_states():
    """[(state, image)]; every state is one direction and one frame."""
    return [
        ('clay_tablet', tablet()),
        ('clay_tablet_words', tablet(words=True)),
        ('clay_tablet_fired', tablet(fired=True)),
        ('clay_tablet_fired_words', tablet(fired=True, words=True)),
        ('stylus', stylus()),
        ('senet', senet()),
        ('chess', chess()),
        ('ice_house', ice_house()),
        ('ice_house_open', ice_house(opened=True)),
    ]


def build(states):
    cols = int(len(states) ** 0.5 + 0.999)
    rows = (len(states) + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * SIZE, rows * SIZE))
    for i, (_, im) in enumerate(states):
        sheet.paste(im, ((i % cols) * SIZE, (i // cols) * SIZE))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = %d\n\theight = %d\n' % (SIZE, SIZE)
    for name, _ in states:
        text += 'state = "%s"\n\tdirs = 1\n\tframes = 1\n' % name
    text += '# END DMI\n'
    return sheet, text


def write_dmi(path, sheet, text):
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta, optimize=True)


def same(path, sheet, text):
    if not path.exists():
        return False
    old = Image.open(path)
    return old.info.get('Description') == text and old.size == sheet.size \
        and old.convert('RGBA').tobytes() == sheet.tobytes()


def existing(sheet, state):
    """The first icon of a state in an existing sheet, for scale; None if absent."""
    try:
        im = Image.open(ROOT / sheet)
        index = 0
        for name, dirs, frames in re.findall(r'state = "(.*?)"\n\tdirs = (\d+)\n\tframes = (\d+)',
                                             im.info.get('Description', '')):
            if name == state:
                cols = im.size[0] // SIZE
                x, y = (index % cols) * SIZE, (index // cols) * SIZE
                return im.convert('RGBA').crop((x, y, x + SIZE, y + SIZE))
            index += int(dirs) * int(frames)
    except OSError:
        pass
    return None


SCALE_ROW = [('icons/obj/bureaucracy.dmi', 'paper_words'), ('icons/obj/claystuff.dmi', 'unfired_claybricks'),
             ('icons/obj/claystuff.dmi', 'claybricks'),
             ('icons/obj/crate.dmi', 'woodencrate'), ('icons/obj/crate.dmi', 'woodencrateopen')]


def preview(path, states, scale=4):
    """Every state at 4x, each cell labelled, on grass and on a table top; a
    row of existing sprites gives scale."""
    grass, table = (98, 122, 78, 255), (124, 88, 56, 255)
    pad, label, per_row = 6, 12, 5
    rows = []                                   # (title, [(caption, image, background)])
    scale_row = [(state, im, grass) for sheet, state in SCALE_ROW for im in [existing(sheet, state)] if im]
    if scale_row:
        rows.append(('existing sprites, for scale', scale_row))
    for back, name in ((grass, 'on grass'), (table, 'on a table top')):
        cells = [(state, im, back) for state, im in states]
        for i in range(0, len(cells), per_row):
            rows.append(('%s  %s' % (SMALL_ANCIENT.name, name), cells[i:i + per_row]))
    cell = SIZE * scale
    width = pad + max(len(cells) for _, cells in rows) * (cell + pad)
    height = pad + len(rows) * (label + label + cell + pad)
    out = Image.new('RGBA', (width, height), (24, 24, 24, 255))
    draw = ImageDraw.Draw(out)
    y = pad
    for title, cells in rows:
        draw.text((pad, y), title, fill=(240, 240, 240, 255))
        y += label
        for i, (caption, im, back) in enumerate(cells):
            x = pad + i * (cell + pad)
            draw.text((x, y), caption[:21], fill=(200, 220, 160, 255))
            tile = Image.new('RGBA', (cell, cell), back)
            tile.alpha_composite(im.resize((cell, cell), Image.NEAREST))
            out.paste(tile, (x, y + label))
        y += label + cell + pad
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    out.save(path, format='PNG')


def main(argv):
    states = small_ancient_states()
    if '--check' in argv:
        if not same(SMALL_ANCIENT, *build(states)):
            sys.exit('stale sheet: ' + str(SMALL_ANCIENT))
        print('small ancient sheet matches')
    else:
        write_dmi(SMALL_ANCIENT, *build(states))
        print('wrote %s (%d states)' % (SMALL_ANCIENT.relative_to(ROOT), len(states)))
    if '--preview' in argv:
        preview(argv[argv.index('--preview') + 1], states)


if __name__ == '__main__':
    main(sys.argv[1:])
