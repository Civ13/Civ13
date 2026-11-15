"""Hand-placed sprites for timekeeping and the lighthouse beacon:

  icons/obj/timekeeping.dmi (32x32): the sundial, the water clock (dripping
      and empty), the hourglass (resting and running), the four-direction
      turret clock movement and its wall dial, and the bell in its timber
      frame with its ring.
  icons/obj/lighthouse.dmi (32x32): the fire basket beacon (unlit, lit, lit
      with a bronze reflector) and the glazed lantern room wall piece.

Every pixel is placed by this script from the fixed palettes below (Pillow
only); no external or generated artwork. The stone greys are the masonry
brazier's, the timber, iron and rope are the catapult's, and the flame is the
lit brazier's, so the pieces stand beside the existing ones. Things are seen
three-quarters from above with the light from the upper left.

The clock face is drawn the way a fastened sign is used: the object stands on
the floor tile and is shifted 32 pixels onto the wall on the side opposite its
dir. SOUTH is the whole dial on the wall face; EAST and WEST are the dial seen
edge-on against the near edge of that wall tile; NORTH is its timber back along
the top edge of the wall tile to the south.

Run with Pillow to reproduce the sheets. `--check` verifies the committed
sheets match and `--preview <png>` writes a 4x review sheet with every state,
direction and frame labelled. Released under Civ13 AGPL-3.0.
"""
import math
import re
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
TIMEKEEPING = ROOT / 'icons/obj/timekeeping.dmi'
LIGHTHOUSE = ROOT / 'icons/obj/lighthouse.dmi'

SIZE = 32
DIRS = ('S', 'N', 'E', 'W')          # BYOND order inside a DMI
TURN = 2 * math.pi

OUT = (37, 21, 14)                   # the braziers' outline
# masonry brazier greys, light to dark
STONE = [(176, 176, 176), (157, 157, 157), (138, 138, 138), (117, 117, 117), (95, 95, 95), (76, 76, 76),
         (58, 58, 58), (46, 46, 46)]
# catapult timber, light to dark
WOOD = [(152, 78, 26), (135, 66, 20), (120, 58, 18), (105, 52, 16), (87, 43, 13), (70, 34, 11), (55, 28, 9)]
# wrought iron
IRON = [(150, 154, 166), (116, 120, 134), (86, 90, 104), (62, 64, 78), (42, 44, 54)]
# hemp rope
ROPE = [(222, 198, 146), (188, 162, 108), (146, 122, 78), (106, 86, 54)]
# bronze, glint to shadow (the wall clock's and bell stand's metal)
BRONZE = [(252, 214, 130), (236, 178, 84), (198, 142, 52), (158, 108, 34), (118, 78, 22), (80, 52, 14)]
# fired clay
CLAY = [(214, 150, 110), (184, 116, 80), (150, 88, 60), (112, 62, 44), (78, 42, 30)]
# water
WATER = [(168, 208, 236), (120, 170, 214), (72, 118, 176), (46, 82, 132)]
# glass: glint, pane, edge, shade
GLASS = [(236, 250, 252), (176, 222, 230), (126, 186, 200), (84, 140, 158)]
# sand
SAND = [(244, 220, 150), (222, 190, 112), (184, 150, 80)]
# painted dial
PAINT = [(240, 232, 208), (222, 210, 180), (196, 182, 150)]
# flame, hottest first, and the heat at which each colour starts
FLAME = [(255, 244, 196), (255, 214, 92), (255, 164, 40), (240, 104, 22), (204, 52, 14), (132, 26, 12)]
LEVELS = [0.80, 0.58, 0.38, 0.20, 0.08, 0.0]
# coals, dimmest first
COALS = [(58, 20, 12), (112, 30, 12), (176, 54, 14), (236, 112, 24), (255, 184, 64)]
CHAR = [(70, 66, 62), (53, 53, 53), (38, 36, 36), (26, 24, 24)]
GLOW = (255, 196, 92)
# split firewood
LOG = [(190, 132, 70), (160, 100, 44), (120, 68, 26), (84, 46, 16)]


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


def rect(im, x0, y0, x1, y1, c, a=255):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(im, x, y, c, a)


def line(im, x0, y0, x1, y1, c):
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        put(im, x0, y0, c)
        if (x0, y0) == (x1, y1):
            return
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def ellipse(im, cx, cy, rx, ry, fn):
    """fn(x, y, nx, ny) -> colour for every pixel inside; nx, ny are -1..1."""
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            nx, ny = (x - cx) / rx, (y - cy) / ry
            if nx * nx + ny * ny <= 1.0:
                put(im, x, y, fn(x, y, nx, ny))


def step(ramp, i):
    return ramp[max(0, min(len(ramp) - 1, int(i)))]


def round_side(ramp, lo, hi, seed=0, rate=0):
    """Shade for the side of something round: light on the left, dark right."""
    def fn(x, y, nx, ny=0):
        i = lo + (nx + 1) / 2 * (hi - lo + 0.999)
        if rate and noise(x, y, seed) < rate:
            i += 1
        return step(ramp, i)
    return fn


def drum(im, cx, cy, rx, ry, h, side, top):
    """An upright cylinder: its top ellipse at cy, the wall h pixels down."""
    for d in range(h, 0, -1):
        ellipse(im, cx, cy + d, rx, ry, lambda x, y, nx, ny: side(x, y, nx))
    ellipse(im, cx, cy, rx, ry, top)


def outline(im, c=OUT):
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


def flip(im):
    return im.transpose(Image.FLIP_LEFT_RIGHT)


def over(*layers):
    out = new()
    for layer in layers:
        out.alpha_composite(layer)
    return out


# ----------------------------------------------------------------- sundial --

def sundial():
    """A plain round stone pedestal carrying a bronze plate and its gnomon."""
    im = new()
    stone = round_side(STONE, 1, 5, 11, 40)
    drum(im, 15.5, 26.0, 8.0, 2.6, 3, stone, lambda x, y, nx, ny: step(STONE, 2 if nx < 0.3 else 3))
    drum(im, 15.5, 14.0, 4.0, 1.6, 12, stone, lambda x, y, nx, ny: STONE[2])
    drum(im, 15.5, 9.0, 9.0, 4.4, 3, stone, lambda x, y, nx, ny: step(STONE, 0 if nx + ny < -0.2 else 1))
    for y in (18, 22):                                   # worn joints in the shaft
        for x in range(12, 20):
            if noise(x, y, 12) < 150:
                put(im, x, y, STONE[5])

    def plate(x, y, nx, ny):
        r = math.hypot(nx, ny)
        if r > 0.86:
            return BRONZE[4] if nx + ny > 0.1 else BRONZE[2]
        return BRONZE[1] if nx + ny < -0.25 else BRONZE[2]
    ellipse(im, 15.5, 8.8, 7.6, 3.5, plate)
    for k in range(12):                                  # hour lines
        a = TURN * k / 12
        put(im, int(round(15.5 + 5.6 * math.cos(a) - 0.5)), int(round(8.8 + 2.4 * math.sin(a) - 0.5)), BRONZE[5])
    line(im, 14, 9, 9, 10, BRONZE[4])                    # the shadow it casts
    line(im, 14, 10, 10, 11, BRONZE[4])
    for i in range(8):                                   # gnomon: upright edge, sloping back
        for x in range(15, 16 + i):
            put(im, x, 1 + i, BRONZE[0] if x == 15 else (BRONZE[5] if x == 15 + i or i == 7 else BRONZE[4]))
    return outline(im)


# ------------------------------------------------------------- water clock --

def water_clock(frame=None):
    """A clay outflow vessel on a stone stand, scored with hour lines inside
    and out, dripping from a bronze spout into a bowl. frame None is dry."""
    im = new()
    wet = frame is not None
    # stone stand
    rect(im, 2, 18, 14, 20, STONE[1])
    for x in range(2, 15):
        put(im, x, 18, STONE[0])
    for y in range(21, 30):
        for x in range(2, 15):
            i = 3 + (1 if x > 10 else 0) + (1 if noise(x, y, 21) < 40 else 0)
            if y == 25 or (x == (6 if y < 25 else 10)):
                i = 6                                     # joints
            put(im, x, y, step(STONE, i))
    # upper vessel
    clay = round_side(CLAY, 0, 3, 22, 30)
    for y in range(7, 19):
        hw = 6.0 - (y - 7) * 0.17
        for x in range(int(round(8 - hw)), int(round(8 + hw)) + 1):
            put(im, x, y, clay(x, y, (x - 8) / hw))
    for i, y in enumerate((10, 12, 14, 16)):              # hour lines
        for x in range(7, 10 if i % 2 else 11):
            put(im, x, y, CLAY[4])
    ellipse(im, 8.0, 6.5, 6.4, 2.4, lambda x, y, nx, ny: CLAY[0] if ny < 0 else CLAY[1])

    def inside(level):
        def fn(x, y, nx, ny):
            if not wet:
                return CLAY[4] if ny < 0.1 else CLAY[3]
            if noise(x + (frame or 0), y, 23) < 50:
                return WATER[0]
            return WATER[level] if nx + ny < 0.2 else WATER[level + 1]
        return fn
    ellipse(im, 8.0, 6.6, 5.0, 1.5, inside(1))
    # spout
    for x, y, c in ((13, 17, BRONZE[1]), (14, 17, BRONZE[2]), (15, 17, BRONZE[2]), (16, 18, BRONZE[4]),
                    (15, 18, BRONZE[4])):
        put(im, x, y, c)
    # lower bowl
    bowl = round_side(CLAY, 1, 4, 24, 30)
    for y, hw in ((26, 6.0), (27, 5.6), (28, 4.8), (29, 3.6)):
        for x in range(int(round(19.5 - hw)), int(round(19.5 + hw)) + 1):
            put(im, x, y, bowl(x, y, (x - 19.5) / hw))
    ellipse(im, 19.5, 25.2, 6.2, 2.0, lambda x, y, nx, ny: CLAY[0] if ny < 0 else CLAY[1])
    ellipse(im, 19.5, 25.3, 4.8, 1.2, inside(1))
    outline(im)
    if wet:                                              # the drop, then its ring in the bowl
        if frame < 3:
            put(im, 16, 19 + frame * 2, WATER[0])
            put(im, 16, 20 + frame * 2, WATER[1])
        else:
            for x in (15, 17, 18):
                put(im, x, 25, WATER[0])
            put(im, 16, 24, WATER[0])
        if frame >= 2:
            put(im, 16, 19, WATER[1])                     # the next drop gathering
    return im


# --------------------------------------------------------------- hourglass --

# rows of the two bulbs: y -> (first, last) column of glass
BULB_TOP = {11: (13, 18), 12: (13, 18), 13: (13, 18), 14: (14, 17), 15: (15, 16)}
BULB_BOTTOM = {16: (15, 16), 17: (14, 17), 18: (13, 18), 19: (13, 18), 20: (13, 18)}
# running frames: rows of sand left above, and the pile below (row -> columns)
SAND_TOP = [(12, 13, 14, 15), (13, 14, 15), (14, 15), (15,)]
SAND_PILE = [{20: (14, 17)}, {20: (14, 17), 19: (15, 16)}, {20: (14, 17), 19: (14, 17), 18: (15, 16)},
             {20: (14, 17), 19: (14, 17), 18: (14, 17)}]
SAND_REST = {20: (14, 17), 19: (14, 17), 18: (14, 17), 17: (15, 16)}


def hourglass(frame=None):
    """Two glass bulbs in a turned wooden frame, about 10x14 in the middle of
    the cell. Resting, the sand is all below; running, a thread falls."""
    im = new()
    rect(im, 11, 9, 20, 9, WOOD[0])
    rect(im, 11, 10, 20, 10, WOOD[3])
    rect(im, 11, 21, 20, 21, WOOD[1])
    rect(im, 11, 22, 20, 22, WOOD[5])
    for x, c in ((11, WOOD[2]), (20, WOOD[5])):
        rect(im, x, 11, x, 20, c)
    for x in (11, 20):
        put(im, x, 9, WOOD[2])
        put(im, x, 22, OUT)
    for rows in (BULB_TOP, BULB_BOTTOM):
        for y, (a, b) in rows.items():
            for x in range(a, b + 1):
                if x in (a, b) and b - a > 1:
                    put(im, x, y, GLASS[2] if x == a else GLASS[3], 230)
                else:
                    put(im, x, y, GLASS[1], 150)
            if b - a > 3:
                put(im, a + 1, y, GLASS[0], 210)
    top = () if frame is None else SAND_TOP[frame]
    pile = SAND_REST if frame is None else SAND_PILE[frame]
    for y in top:
        a, b = BULB_TOP[y]
        for x in range(a + (1 if b - a > 1 else 0), b - (1 if b - a > 1 else 0) + 1):
            put(im, x, y, SAND[0] if y == top[0] else SAND[1])
    if frame is not None:                                 # the falling thread
        for y in range(16, min(pile)):
            put(im, 15, y, SAND[(y + frame) % 2])
    for y, (a, b) in pile.items():
        for x in range(a, b + 1):
            put(im, x, y, SAND[0] if y == min(pile) else (SAND[2] if x == b else SAND[1]))
    return im


# ------------------------------------------------------------- tower clock --

def gear(im, cx, cy, r, teeth, spokes=True, turn=0.0):
    """A bronze wheel seen face on: toothed rim, cross of spokes, hub."""
    for y in range(int(cy - r) - 2, int(cy + r) + 3):
        for x in range(int(cx - r) - 2, int(cx + r) + 3):
            dx, dy = x - cx, y - cy
            d = math.hypot(dx, dy)
            lit = dx + dy < 0
            if r - 0.3 < d <= r + 0.8:
                if int(math.floor((math.atan2(dy, dx) / TURN + turn + 1.0) * teeth * 2 + 0.5)) % 2 == 0:
                    put(im, x, y, BRONZE[2] if lit else BRONZE[4])
            elif r - 1.6 <= d <= r - 0.3:
                put(im, x, y, BRONZE[1] if lit else BRONZE[3])
            elif d <= 1.2:
                put(im, x, y, BRONZE[0] if d < 0.6 else BRONZE[2])
            elif spokes and d < r and min(abs(dx), abs(dy)) < 0.6:
                put(im, x, y, BRONZE[3])


def edge_wheel(im, x, y0, y1, wide=2):
    """A wheel seen edge-on: a toothed bar."""
    for y in range(y0, y1 + 1):
        for i in range(wide):
            c = BRONZE[1 + i * 2] if y % 2 else BRONZE[2 + i * 2]
            put(im, x + i, y, BRONZE[4] if y in (y0, y1) else c)


def weight(im, x, y):
    """A stone clock weight, 5x8, hung by an iron eye at (x + 2, y - 1)."""
    for j in range(8):
        for i in range(5):
            put(im, x + i, y + j, step(STONE, (1 if j == 0 else 2) + i * 0.8 + (1 if j == 7 else 0)))
    for i in (0, 4):
        put(im, x + i, y, STONE[4])
        put(im, x + i, y + 7, STONE[6])
    put(im, x + 2, y - 1, IRON[1])


def iron_frame(im, x0, x1):
    for x, c in ((x0, IRON[1]), (x0 + 1, IRON[3]), (x1 - 1, IRON[2]), (x1, IRON[4])):
        rect(im, x, 5, x, 27, c)
    rect(im, x0, 5, x1, 5, IRON[0])
    rect(im, x0, 6, x1, 6, IRON[3])
    rect(im, x0, 25, x1, 25, IRON[1])
    rect(im, x0, 26, x1, 26, IRON[4])
    for x in (x0, x1 - 1):                                # feet
        rect(im, x - 1, 28, x + 2, 28, IRON[2])
        rect(im, x - 1, 29, x + 2, 29, IRON[4])
    for x, y in ((x0, 5), (x1, 5), (x0, 25), (x1, 25)):   # wedged joints
        put(im, x, y, IRON[0])


def movement_front():
    """The movement seen along its arbors: the great wheel on the rope barrel
    below, two smaller wheels and the escapement above, and the weight hung
    off an arm on the right."""
    im = new()
    iron_frame(im, 3, 23)
    rect(im, 5, 15, 21, 15, IRON[3])                      # middle rail
    rect(im, 3, 3, 29, 3, IRON[1])                        # weight arm
    rect(im, 3, 4, 29, 4, IRON[4])
    rect(im, 27, 2, 29, 2, BRONZE[2])                     # its pulley
    put(im, 28, 3, BRONZE[1])
    for y in range(5, 16):
        put(im, 28, y, ROPE[y % 2])
    weight(im, 26, 16)
    for y in range(7, 20):                                # the fall from the barrel
        put(im, 9, y, ROPE[1 + y % 2])
    ellipse(im, 13.0, 19.0, 3.4, 3.4,                     # rope barrel behind the great wheel
            lambda x, y, nx, ny: ROPE[1 + (x + y) % 2] if math.hypot(nx, ny) > 0.55 else WOOD[2])
    gear(im, 13.0, 19.0, 5.0, 12)
    gear(im, 9.0, 10.0, 3.0, 8, turn=0.02)
    gear(im, 17.0, 10.0, 3.0, 8, spokes=False, turn=0.05)
    for x, y in ((15, 7), (16, 6), (17, 6), (18, 6), (19, 7), (17, 5)):   # anchor
        put(im, x, y, IRON[0])
    return outline(im)


def movement_side(weight_in_front):
    """The movement seen from its end: the wheels are toothed bars on their
    arbors, the barrel a rope-wound cylinder. The weight hangs on the far
    side (drawn first, higher) or the near side (drawn last, lower)."""
    im = new()
    if not weight_in_front:
        for y in range(4, 9):
            put(im, 15, y, ROPE[y % 2])
        weight(im, 13, 10)
    iron_frame(im, 9, 22)
    rect(im, 11, 10, 20, 10, IRON[1])                     # arbors
    rect(im, 11, 20, 20, 20, IRON[1])
    for y in range(17, 24):                               # rope barrel
        for x in range(12, 17):
            put(im, x, y, ROPE[min(3, (0 if y < 19 else 1 if y < 22 else 2) + x % 2)])
    edge_wheel(im, 17, 15, 25)
    edge_wheel(im, 12, 7, 13)
    edge_wheel(im, 18, 8, 12, 1)
    put(im, 18, 6, IRON[0])
    put(im, 18, 7, IRON[0])
    rect(im, 15, 3, 16, 4, BRONZE[2])                     # the arm's pulley, end on
    put(im, 15, 3, BRONZE[0])
    if weight_in_front:
        for y in range(5, 18):
            put(im, 15, y, ROPE[y % 2])
        weight(im, 13, 18)
    return outline(im)


def tower_clock():
    south = movement_front()
    west = movement_side(True)
    return [south, flip(south), flip(movement_side(False)), west]


# -------------------------------------------------------------- clock face --

def dial_front():
    im = new()

    def face(x, y, nx, ny):
        r = math.hypot(nx, ny)
        if r > 0.89:
            return step(BRONZE, 2.5 + (nx + ny) * 1.6)
        if r > 0.82:
            return BRONZE[5]
        return PAINT[0] if nx + ny < -0.35 else (PAINT[1] if nx + ny < 0.75 else PAINT[2])
    ellipse(im, 15.5, 15.5, 13.6, 13.6, face)
    for k in range(12):                                   # hour marks, long at the quarters
        a = TURN * k / 12
        for r in ((8.2, 9.4) if k % 3 == 0 else (9.4,)):
            put(im, int(math.floor(16 + r * math.sin(a))), int(math.floor(16 - r * math.cos(a))), IRON[4])
    for x, y in ((14, 14), (13, 13), (12, 12), (11, 11), (10, 10), (9, 9), (10, 9), (9, 10), (13, 14), (14, 13),
                 (17, 17), (18, 18)):
        put(im, x, y, IRON[4])                            # the single hour hand and its tail
    rect(im, 15, 15, 16, 16, BRONZE[1])
    put(im, 16, 16, BRONZE[4])
    return outline(im)


def dial_side():
    """Facing east: seen edge-on against the right edge of the cell."""
    im = new()

    def strip(x, y, nx, ny):
        if x <= 26:
            return WOOD[4] if x == 25 else WOOD[2]
        if x in (27, 30) or abs(ny) > 0.93:
            return BRONZE[2] if x == 27 else BRONZE[4]
        if y % 5 == 3:
            return IRON[4] if x == 29 else PAINT[1]
        return PAINT[0] if x == 28 else PAINT[1]
    ellipse(im, 27.5, 15.5, 3.0, 13.6, strip)
    for y in range(10, 16):
        put(im, 28, y, IRON[4])
    put(im, 28, 15, BRONZE[1])
    return outline(im)


def dial_back():
    """Facing north: the boarded back and rim, along the top edge of the cell."""
    im = new()

    def strip(x, y, nx, ny):
        if y == 1 or abs(nx) > 0.95:
            return BRONZE[2] if nx < 0 else BRONZE[4]
        if x % 6 == 3:
            return WOOD[6]
        if y == 4:
            return IRON[2]
        return WOOD[1] if y < 4 else WOOD[4]
    ellipse(im, 15.5, 3.5, 13.6, 3.0, strip)
    return outline(im)


def clock_face():
    east = dial_side()
    return [dial_front(), dial_back(), east, flip(east)]


# -------------------------------------------------------------------- bell --

# half width of the bell at each row below the pivot
BELL = {3: 2.5, 4: 3.5, 5: 4.2, 6: 4.7, 7: 5.0, 8: 5.2, 9: 5.4, 10: 5.6, 11: 5.8, 12: 6.0, 13: 6.3, 14: 6.7,
        15: 7.2, 16: 7.8, 17: 7.8}
PIVOT = (16.0, 8.0)


def bell_pixel(u, v, clap):
    row = int(math.floor(v))
    if row in (1, 2):
        return BRONZE[4] if abs(u) <= 1.5 else None       # the crown it hangs by
    if row in BELL:
        hw = BELL[row]
        if abs(u) > hw:
            return None
        t = (u / hw + 1) / 2
        i = 3 if t < 0.12 else 0 if t < 0.24 else 1 if t < 0.40 else 2 if t < 0.62 else 3 if t < 0.84 else 4
        if row in (6, 14):
            i += 1                                        # moulding wires
        if row >= 16:
            i = max(0, i - 1) if t < 0.5 else i           # the thick lip
        return step(BRONZE, i)
    if row == 18 and abs(u) <= 6.6:
        return BRONZE[5]                                  # the mouth
    if row in (18, 19, 20) and abs(u - clap) <= 1.0:
        return IRON[3] if row < 20 else IRON[4]           # clapper
    return None


def bell(angle=0.0, clap=0.0):
    """A bronze bell hung by its headstock between two posts of a timber
    frame; angle (degrees) swings it to the right about the beam."""
    im = new()
    a = math.radians(angle)
    ca, sa = math.cos(a), math.sin(a)
    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = x + 0.5 - PIVOT[0], y + 0.5 - PIVOT[1]
            put(im, x, y, bell_pixel(dx * ca - dy * sa, dx * sa + dy * ca, clap))
    # frame: beam, headstock, posts, braces, feet
    for y, c in ((3, WOOD[0]), (4, WOOD[1]), (5, WOOD[3]), (6, WOOD[5])):
        rect(im, 1, y, 30, y, c)
    rect(im, 11, 7, 20, 8, WOOD[2])
    rect(im, 11, 9, 20, 9, WOOD[5])
    for x in (12, 19):
        rect(im, x, 6, x, 9, IRON[2])
    for x0 in (2, 27):
        for i, c in enumerate((WOOD[1], WOOD[3], WOOD[5])):
            rect(im, x0 + i, 7, x0 + i, 28, c)
        rect(im, x0 - 2, 29, x0 + 4, 29, WOOD[2])
        rect(im, x0 - 2, 30, x0 + 4, 30, WOOD[5])
    line(im, 5, 12, 9, 7, WOOD[3])
    line(im, 5, 13, 9, 8, WOOD[5])
    line(im, 26, 12, 22, 7, WOOD[3])
    line(im, 26, 13, 22, 8, WOOD[5])
    for x in range(1, 31, 5):
        put(im, x, 4, WOOD[4])                            # grain
    return outline(im)


BELL_RING = [(10, -1.5), (18, 5.0), (10, 2.0), (0, 0.0)]   # (degrees, clapper offset) per frame


# ------------------------------------------------------------------ beacon --

BASKET_TOP, BASKET_BOTTOM = 10, 20
# tongues: (centre column, height, half width at the root, lean at the tip, turns per loop, phase)
TONGUES = [(15.5, 11.5, 6.4, 1.6, 1, 0.00), (10.8, 7.0, 3.2, 1.2, 1, 0.40), (20.2, 7.4, 3.2, 1.2, 1, 0.75),
           (14.4, 9.4, 3.8, 1.4, 2, 0.20), (17.2, 8.6, 3.4, 1.2, 1, 0.55)]
FLAME_BASE = 11.0
# sparks: (phase frame, start column, start row, drift per frame)
SPARKS = [(0, 17.0, 2.0, 0.6), (1, 12.0, 4.0, -0.7), (2, 21.0, 5.0, 0.8), (3, 14.0, 1.0, -0.3), (2, 8.0, 6.0, -0.6)]
FRAMES = 4


def basket_half(y):
    return 4.0 + (BASKET_BOTTOM - y) * 0.4


def beacon_body(frame=None):
    """Stone base and iron basket; frame None is the cold fuel."""
    im = new()
    lit = frame is not None

    def course(x, y, nx):
        i = 2 + (nx + 1) * 1.6 + (1 if noise(x, y, 31) < 36 else 0)
        row = y - 22
        if row % 3 == 0 or (x + (row // 3) * 3) % 6 == 0:
            i += 2                                        # mortar
        return step(STONE, i)
    drum(im, 15.5, 21.5, 7.6, 2.6, 6, course, lambda x, y, nx, ny: step(STONE, 1 if nx + ny < 0 else 2))

    def fuel(x, y):
        if lit:
            return step(COALS, 1 + (noise(x, y, 40 + frame) % 4) - (1 if y > 17 else 0))
        n = noise(x, y, 41)
        return WOOD[5] if n < 60 else step(CHAR, n % 4)
    for y in range(BASKET_TOP, BASKET_BOTTOM + 1):
        hw = basket_half(y)
        x0, x1 = int(round(15.5 - hw)), int(round(15.5 + hw))
        bars = set(int(round(15.5 + f * hw)) for f in (-1.0, -0.6, -0.2, 0.2, 0.6, 1.0))
        bars |= {x0, x1}
        for x in range(x0, x1 + 1):
            shade = round_side(IRON, 0, 4)(x, y, (x - 15.5) / hw)
            if y in (BASKET_BOTTOM, 15) or x in bars:
                put(im, x, y, shade)
            else:
                put(im, x, y, fuel(x, y))
    # the open top: iron rim around the fuel
    ellipse(im, 15.5, 9.6, 8.4, 2.7, lambda x, y, nx, ny: round_side(IRON, 0, 4)(x, y, nx))
    ellipse(im, 15.5, 9.5, 7.0, 1.7, lambda x, y, nx, ny: fuel(x, y) if lit else step(CHAR, 1 + noise(x, y, 42) % 3))
    if not lit:                                           # split logs laid across the top
        for (x0, y0, x1, y1), c in (((8, 8, 19, 5), LOG[1]), ((8, 9, 19, 6), LOG[3]), ((12, 4, 23, 8), LOG[0]),
                                    ((12, 5, 23, 9), LOG[2]), ((14, 9, 16, 2), LOG[1]), ((15, 9, 17, 2), LOG[3])):
            line(im, x0, y0, x1, y1, c)
        for x, y in ((19, 5), (12, 4), (16, 2), (8, 8)):
            put(im, x, y, LOG[0])                         # pale cut ends
    return outline(im)


def front_rim():
    """The near half of the basket rim, redrawn in front of the flame."""
    im = new()
    for x in range(SIZE):
        for y in (10, 11, 12):
            nx, ny = (x - 15.5) / 8.4, (y - 9.6) / 2.7
            inner = ((x - 15.5) / 7.0) ** 2 + ((y - 9.5) / 1.7) ** 2
            if nx * nx + ny * ny <= 1.0 and inner > 1.0:
                put(im, x, y, round_side(IRON, 0, 4)(x, y, nx))
    return im


def flame_heat(x, y, frame):
    best = -1.0
    for cx, height, width, lean, turns, phase in TONGUES:
        p = TURN * (frame / FRAMES * turns + phase)
        height = height * (1.0 + 0.10 * math.sin(p))
        t = (FLAME_BASE - (y + 0.5)) / height
        if t < -0.1 or t >= 1.0:
            continue
        t = max(t, 0.0)
        centre = cx + lean * t ** 1.4 * math.sin(p - t * 2.6)
        half = width * (1.0 - t) ** 0.75 * (1.0 + 0.22 * math.sin(p - t * 5.0))
        d = abs(x + 0.5 - centre)
        if half <= 0.3 or d > half:
            continue
        best = max(best, (1.0 - d / half) ** 0.8 * (1.0 - 0.55 * t))
    return best


def flame(frame):
    im = new()
    for y in range(SIZE):
        for x in range(SIZE):
            h = flame_heat(x, y, frame)
            if h < 0:
                continue
            for colour, level in zip(FLAME, LEVELS):
                if h >= level:
                    put(im, x, y, colour)
                    break
    for start, sx, sy, drift in SPARKS:
        age = (frame - start) % FRAMES
        put(im, int(round(sx + drift * age)), int(round(sy - 1.5 * age)), FLAME[1 + age])
    return im


def glow(frame, reach):
    """The light thrown around the fire: a soft disc that breathes."""
    im = new()
    r = reach + (0.0, 0.8, 0.3, -0.5)[frame]
    for y in range(SIZE):
        for x in range(SIZE):
            d = math.hypot(x - 15.5, y - 7.0)
            if d < r:
                put(im, x, y, GLOW, int(120 * (1.0 - d / r) ** 1.1) + 12)
    return im


def reflector(frame):
    """A dished, polished bronze mirror standing behind the basket."""
    im = new()
    hot = (0.0, 0.05, 0.02, -0.04)[frame]

    def dish(x, y, nx, ny):
        r = math.hypot(nx, ny)
        if r > 0.90:
            return step(BRONZE, 2.6 + (nx + ny) * 1.5)
        if r > 0.82:
            return BRONZE[4]
        f = math.hypot(nx, (ny - 0.1) * 1.1)             # the fire thrown back from the bowl
        if f < 0.34 + hot:
            return FLAME[0]
        if f < 0.52 + hot:
            return BRONZE[0]
        if f < 0.68 + hot or noise(x, y, 50) < 26:
            return BRONZE[1]
        return BRONZE[2]
    ellipse(im, 15.5, 9.5, 14.0, 9.6, dish)
    for x0, x1 in ((5, 8), (26, 23)):                     # iron stays down to the base
        line(im, x0, 17, x1, 23, IRON[2])
        line(im, x0 + (1 if x0 < 16 else -1), 17, x1 + (1 if x0 < 16 else -1), 23, IRON[4])
    return outline(im)


def beacon_lit(frame, mirror=False):
    back = [glow(frame, 15.0 if mirror else 13.0)]
    if mirror:
        back.append(reflector(frame))
    return over(*back, beacon_body(frame), flame(frame), front_rim())


# ------------------------------------------------------- lighthouse lantern --

def lighthouse_lantern():
    """One wall piece of a glazed lantern room: an iron sill and head, upright
    astragals and a transom, with clear panes the beacon shows through."""
    im = new()
    for y in range(SIZE):
        for x in range(SIZE):
            streak = (x + y) % 11 in (0, 1) and noise(x // 2, y // 2, 60) < 200
            put(im, x, y, GLASS[0] if streak else (GLASS[1] if (x + y) < 34 else GLASS[2]), 150 if streak else 92)
    for y, c in ((0, IRON[1]), (1, IRON[0]), (2, IRON[2]), (3, IRON[3]), (4, IRON[4])):       # head
        rect(im, 0, y, 31, y, c)
    for y, c in ((25, IRON[4]), (26, IRON[0]), (27, IRON[1]), (28, IRON[2]), (29, IRON[3]), (30, IRON[3]),
                 (31, IRON[4])):                                                              # sill
        rect(im, 0, y, 31, y, c)
    for x0 in (0, 10, 20, 30):                                                                # astragals
        rect(im, x0, 5, x0, 24, IRON[1])
        rect(im, x0 + 1, 5, x0 + 1, 24, IRON[4])
    rect(im, 0, 14, 31, 14, IRON[1])                                                          # transom
    rect(im, 0, 15, 31, 15, IRON[4])
    for x in range(2, 31, 4):                                                                 # rivets
        put(im, x, 2, IRON[0])
        put(im, x, 28, IRON[0])
    return im


# ------------------------------------------------------------------ sheets --

def timekeeping_states():
    """[(state, frames, delay, loop)]; frames is a list of per-frame dir lists,
    loop 0 repeats for ever."""
    return [
        ('sundial', [[sundial()]], 0, 0),
        ('water_clock', [[water_clock(f)] for f in range(4)], 2, 0),
        ('water_clock_empty', [[water_clock()]], 0, 0),
        ('hourglass', [[hourglass()]], 0, 0),
        ('hourglass_running', [[hourglass(f)] for f in range(4)], 3, 0),
        ('tower_clock', [tower_clock()], 0, 0),
        ('clock_face', [clock_face()], 0, 0),
        ('bell', [[bell()]], 0, 0),
        ('bell_ring', [[bell(a, c)] for a, c in BELL_RING], 1, 1),
    ]


def lighthouse_states():
    return [
        ('beacon', [[beacon_body()]], 0, 0),
        ('beacon_lit', [[beacon_lit(f)] for f in range(FRAMES)], 1.5, 0),
        ('beacon_reflector', [[beacon_lit(f, True)] for f in range(FRAMES)], 1.5, 0),
        ('lighthouse_lantern', [[lighthouse_lantern()]], 0, 0),
    ]


def sheets():
    return [(TIMEKEEPING, timekeeping_states()), (LIGHTHOUSE, lighthouse_states())]


def build(states):
    icons = [im for _, frames, _, _ in states for row in frames for im in row]
    cols = int(len(icons) ** 0.5 + 0.999)
    rows = (len(icons) + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * SIZE, rows * SIZE))
    for i, im in enumerate(icons):
        sheet.paste(im, ((i % cols) * SIZE, (i // cols) * SIZE))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = %d\n\theight = %d\n' % (SIZE, SIZE)
    for name, frames, delay, loop in states:
        text += 'state = "%s"\n\tdirs = %d\n\tframes = %d\n' % (name, len(frames[0]), len(frames))
        if len(frames) > 1:
            text += '\tdelay = %s\n' % ','.join(['%g' % delay] * len(frames))
            if loop:
                text += '\tloop = %d\n' % loop
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


def preview(path, built, scale=4):
    """Every state, direction and frame at 4x, each cell labelled, on grass
    and (the wall pieces) on a stone wall; two existing sprites give scale."""
    grass, wall = (98, 122, 78, 255), (104, 100, 96, 255)
    on_wall = ('clock_face', 'lighthouse_lantern')
    pad, label = 6, 12
    rows = []                                   # (title, [(caption, image, background)])
    scale_row = [(state, im, grass) for state in ('s_brazier0', 'bell_stand', 'wall_clock')
                 for im in [existing('icons/obj/structures.dmi', state)] if im]
    if scale_row:
        rows.append(('structures.dmi (existing, for scale)', scale_row))
    for sheet_path, states in built:
        singles = []
        for name, frames, delay, loop in states:
            back = wall if name in on_wall else grass
            dirs = len(frames[0])
            if len(frames) == 1 and dirs == 1:
                singles.append((name, frames[0][0], back))
            elif len(frames) == 1:
                rows.append(('%s  %s (%d dirs)' % (sheet_path.name, name, dirs),
                             [(DIRS[i], im, back) for i, im in enumerate(frames[0])]))
            else:
                rows.append(('%s  %s (%d frames, delay %g, %s)' % (
                    sheet_path.name, name, len(frames), delay, 'loop %d' % loop if loop else 'looping'),
                    [('%d' % (k + 1), fr[0], back) for k, fr in enumerate(frames)]))
        if singles:
            rows.append(('%s  single states' % sheet_path.name, singles))
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
    built = sheets()
    if '--check' in argv:
        for path, states in built:
            if not same(path, *build(states)):
                sys.exit('stale sheet: ' + str(path))
        print('timekeeping sheets match')
    else:
        for path, states in built:
            write_dmi(path, *build(states))
            print('wrote %s (%d states)' % (path.relative_to(ROOT), len(states)))
    if '--preview' in argv:
        preview(argv[argv.index('--preview') + 1], built)


if __name__ == '__main__':
    main(sys.argv[1:])
