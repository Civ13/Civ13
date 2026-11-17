"""Hand-placed 32px lifts for multi-storey buildings, icons/obj/lifts.dmi.

  lift_wood            (1 dir): a square platform of heavy planks on two
                       cross battens, 2px inside the tile, with an iron eye
                       and a hemp rope at each corner. The ropes run off the
                       top of the tile toward the pulley over the shaft. It
                       is walked on, so it is drawn flat like a floor.
  lift_iron            (1 dir): an iron-framed lift car floor of tread plate
                       with a low railing on the north, east and west sides
                       (the open side faces SOUTH) and four steel cables
                       running off the top of the tile. Also walked on.
  steam_lift_engine    (1 dir): a small upright boiler with a stack beside a
                       winding drum wrapped in hemp cable, on a timber bed.
  steam_lift_engine_on (1 dir, 4 frames of 2 ticks, looping): the same with
                       the fire door glowing, steam puffing from the stack
                       and the drum turning.
  lift_motor           (1 dir): an electric winding machine - a finned
                       cast-iron motor housing coupled to a drum of steel
                       cable on an iron bed plate, with a small brass switch
                       box on the housing.
  lift_motor_on        (1 dir, 4 frames of 2 ticks, looping): the same with
                       the switch thrown, its lamp lit and the drum turning.
  lift_bell            (1 dir): a brass hand bell hung from a short braced
                       wooden bracket on a post, with a pull cord, to call
                       the lift in older buildings.
  lift_button          (1 dir): a brass call panel with one round button on
                       a slim iron post.
  lift_button_lit      (1 dir): the same with the button glowing amber.

Every pixel is placed by this script from the fixed palettes below (Pillow
only); no external or generated artwork. The timber, iron and rope ramps are
those of create_storey_fittings.py, the steel, brass and steam those of
create_machine_shop.py and the fire and lamp colours those of
create_clay_lime_fire.py, so the lifts sit beside the hoists, cranes and
machines. Things are seen three-quarters from above with the light from the
upper left.

Run with Pillow to reproduce the sheet. `--check` verifies the committed sheet
matches and `--preview <png>` writes a 4x labelled review sheet. Released
under Civ13 AGPL-3.0.
"""
import re
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/lifts.dmi'
FLOORS = ROOT / 'icons/turf/floors.dmi'

SIZE = 32

OUT = (24, 20, 18)                  # outline
WOOD = [(198, 162, 114), (162, 124, 80), (126, 92, 56), (88, 62, 38)]
IRON = [(150, 152, 158), (104, 106, 112), (66, 68, 74), (40, 41, 46)]
STEEL = [(206, 212, 222), (164, 170, 184), (116, 122, 138)]
BRASS = [(236, 200, 96), (196, 152, 58), (140, 104, 38)]
ROPE = [(226, 208, 160), (186, 164, 112), (134, 114, 74)]
STEAM = [(244, 246, 250), (208, 214, 224)]
FIRE = [(255, 244, 170), (255, 196, 70), (240, 120, 36), (176, 56, 24)]
LAMP_OFF = (90, 59, 28)

FRAMES = 4
DELAY = 2

PLAT = (2, 29)                      # first and last column and row of both platforms


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
        im.putpixel((x, y), (c[0], c[1], c[2], a))


def rect(im, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(im, x, y, c)


def step(ramp, i):
    return ramp[max(0, min(len(ramp) - 1, int(i)))]


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


def over(*layers):
    im = new()
    for layer in layers:
        im.alpha_composite(layer)
    return im


def path(xa, ya, xb, yb):
    """The pixels of a straight run, one per row, from (xa, ya) up to (xb, yb)."""
    n = abs(yb - ya)
    return [(xa + round((xb - xa) * i / n), ya + (i if yb > ya else -i)) for i in range(n + 1)] if n else [(xa, ya)]


# --------------------------------------------------------------- platforms --

# where each line is made fast (x, y) and the column where it leaves the top
# of the tile; the two front lines lean in toward the pulley overhead
CORNERS = (((5, 5), 6), ((26, 5), 25), ((5, 25), 8), ((26, 25), 23))


def lines(im, ramp, shade):
    """The four ropes or cables from the corner eyes off the top of the tile."""
    for (x, y), top in CORNERS:
        for i, (px, py) in enumerate(path(x, y - 1, top, 0)):
            if py > 6:
                put(im, px + 1, py, shade)                      # its shadow on the deck
            put(im, px, py, ramp[0] if i % 3 != 2 else ramp[2])
    for (x, y), _ in CORNERS:                                   # the iron eye it is tied to
        put(im, x - 1, y, IRON[2])
        put(im, x + 1, y, IRON[3])
        put(im, x, y + 1, IRON[3])
        put(im, x, y, ramp[1])


def lift_wood():
    im = new()
    a, b = PLAT
    for y in range(a, b + 1):
        for x in range(a, b + 1):
            if y >= b - 1:                                      # the plank ends, facing south
                c = WOOD[3] if y == b or (x - a) % 7 == 6 else WOOD[2]
            else:
                col = (x - a) % 7                               # four heavy planks, 7px each
                plank = (x - a) // 7
                tone = 1
                if col == 0:
                    tone = 0                                    # lit left arris
                elif col == 6:
                    tone = 3                                    # the gap
                elif noise(plank, y // 2 + plank * 3, 21) < 46 or noise(x, y // 5, 22) < 22:
                    tone = 2                                    # grain
                if y == a and tone < 3:
                    tone = 0
                c = WOOD[tone]
            put(im, x, y, c)
    for y0 in (7, 20):                                          # the two battens the planks are spiked to
        for x in range(a, b + 1):
            put(im, x, y0, WOOD[0])
            put(im, x, y0 + 1, WOOD[1] if noise(x // 3, y0, 23) > 50 else WOOD[2])
            put(im, x, y0 + 2, WOOD[2])
            put(im, x, y0 + 3, WOOD[3])
        for x in range(a + 3, b, 7):
            put(im, x, y0 + 1, IRON[3])                         # spike heads
    for y in range(a, b + 1):                                   # a dark rim so the deck reads apart from a floor
        put(im, a, y, WOOD[2] if y < b - 1 else WOOD[3])
        put(im, b, y, WOOD[3])
    lines(im, ROPE, WOOD[3])
    return im


RAIL_Y = 4                          # the top rail of the car's north side


def lift_iron():
    im = new()
    a, b = PLAT
    for y in range(RAIL_Y, b + 1):                              # the floor
        for x in range(a, b + 1):
            edge = min(x - a, b - x, b - y)
            if y >= b - 1:                                      # the south channel iron
                c = IRON[3] if y == b else IRON[2]
            elif edge <= 1:                                     # the frame under the side rails
                c = IRON[2]
            else:                                               # tread plate
                c = IRON[1]
                if (x % 4, y % 4) in ((0, 0), (2, 2)):
                    c = IRON[0]                                 # the raised studs
                elif (x % 4, (y - 1) % 4) in ((0, 0), (2, 2)):
                    c = IRON[2]
            put(im, x, y, c)
    for x in range(a + 2, b - 1):                               # the sill plate at the open side
        put(im, x, b - 2, STEEL[1] if x % 6 else IRON[2])
    # the north railing, seen from the front: top rail, mid rail, posts
    for x in range(a, b + 1):
        put(im, x, RAIL_Y, STEEL[0])
        put(im, x, RAIL_Y + 1, IRON[1])
        put(im, x, RAIL_Y + 4, IRON[0])
        put(im, x, RAIL_Y + 8, IRON[3])                         # its shadow on the plate
    for x in (a + 6, a + 13, a + 14, a + 21):
        for y in range(RAIL_Y + 2, RAIL_Y + 8):
            put(im, x, y, IRON[0] if x != a + 14 else IRON[2])
    # the side railings run away down the tile: a lit top rail with posts
    for x, lit in ((a, True), (b - 1, False)):
        for y in range(RAIL_Y, 24):
            put(im, x, y, STEEL[0] if lit else STEEL[1])
            put(im, x + 1, y, IRON[1] if lit else IRON[2])
        for y in range(RAIL_Y, 30):                             # corner posts front and back
            if y < RAIL_Y + 8 or y >= 22:
                put(im, x, y, STEEL[1] if lit else IRON[0])
                put(im, x + 1, y, IRON[2])
        put(im, x, 22, STEEL[0])                                # the newel caps at the open side
        put(im, x + 1, 22, STEEL[1])
        inner = x + 2 if lit else x - 1
        for y in range(RAIL_Y + 9, 28):
            put(im, inner, y, IRON[3])                          # the rail's shadow
        for y0 in (13, 18):                                     # the posts between
            put(im, inner, y0, IRON[0])
            put(im, inner, y0 + 1, IRON[0])
    lines(im, STEEL, IRON[3])
    return outline(im)


# ------------------------------------------------------------------ drives --

def drum(im, x0, x1, y0, y1, k, cable):
    """A winding drum lying across the tile between two iron cheeks, wrapped
    in cable. k steps the turns and a bolt on each cheek round."""
    h = y1 - y0
    for y in range(y0, y1 + 1):
        row = y - y0
        shade = 0 if row <= 1 else (1 if row < h - 2 else 2)   # round: lit on top, dark beneath
        for x in range(x0 + 1, x1):
            turn = (x + row // 5 + k) % 4                       # the turns, travelling as it winds
            tone = shade + (0, 0, 1, 2)[turn] - (1 if turn == 0 and row > 1 else 0)
            put(im, x, y, step(cable, tone))
    for x in (x0, x1):                                          # the cheeks, a pixel proud all round
        for y in range(y0 - 1, y1 + 2):
            put(im, x, y, IRON[1] if x == x0 else IRON[2])
        put(im, x, y0 - 1, IRON[0])
        put(im, x, y0 + 1 + (k * (h - 1)) // 4 + (k % 2), STEEL[0])     # a bolt head going round
    for x in (x0, x1):                                          # the bearing pedestals
        put(im, x - 1, y1, IRON[2])
        put(im, x + 1, y1, IRON[3])
        put(im, x - 1, y1 + 1, IRON[1])
        put(im, x + 1, y1 + 1, IRON[3])


def fall(im, x, y0, ramp, k=0):
    """The line leaving the drum straight up off the tile, to the headgear."""
    for y in range(0, y0 + 1):
        put(im, x, y, ramp[0] if (y + k) % 3 != 2 else ramp[2])


STACK_X = 8                         # the middle column of the boiler's stack
STACK_TOP = 6


def steam_puff(im, k):
    """One puff leaving the stack and thinning as it climbs: the four frames
    carry it from the cap to the top of the tile while the next one forms."""
    for age in (k, k + 4):                                      # this puff and the one before it
        cy = STACK_TOP - 2 - (age * 3) // 4
        cx = STACK_X + (age + 1) // 3
        r2 = (1.2, 2.3, 2.3, 4.2, 4.2, 5.5, 5.5, 5.5)[age]      # it swells as it climbs
        alpha = 240 - age * 26
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                if dx * dx + dy * dy > r2:
                    continue
                put(im, cx + dx, cy + dy, STEAM[0 if dx + dy < 1 else 1], alpha - 25 * (dx * dx + dy * dy > 2))


def steam_lift_engine(k=None):
    on = k is not None
    k = k or 0
    im = new()
    # the timber bed, two baulks with iron holding-down bolts
    for x in range(2, 30):
        put(im, x, 26, WOOD[0])
        put(im, x, 27, WOOD[1] if noise(x // 3, 1, 41) > 60 else WOOD[2])
        put(im, x, 28, WOOD[2])
        put(im, x, 29, WOOD[3])
    for x in (3, 14, 28):
        put(im, x, 27, IRON[3])
    # the upright boiler: a riveted iron barrel, lit down its left side
    for y in range(11, 26):
        for x in range(4, 13):
            tone = (0, 0, 1, 1, 1, 1, 2, 2, 3)[x - 4]
            if y == 11 and x in (4, 12):
                continue                                        # the rounded crown
            if y == 11:
                tone = max(0, tone - 1)
            put(im, x, y, IRON[tone])
    for y in (14, 20):                                          # brass bands
        for x in range(4, 13):
            put(im, x, y, step(BRASS, (x - 4) // 3))
    rect(im, 6, 22, 9, 24, IRON[3])                             # the fire door
    put(im, 6, 22, IRON[2])
    if on:
        rect(im, 7, 23, 8, 24, FIRE[2])
        put(im, 7 + k % 2, 23, FIRE[k % 2])
        put(im, 8 - k % 2, 24, FIRE[3])
    put(im, 10, 17, BRASS[0])                                   # the pressure gauge
    put(im, 11, 17, BRASS[2])
    put(im, 5, 17, BRASS[1])                                    # the water glass
    put(im, 5, 18, STEAM[1])
    for y in range(STACK_TOP, 11):                              # the stack and its flared cap
        put(im, STACK_X - 1, y, IRON[1])
        put(im, STACK_X, y, IRON[2])
        put(im, STACK_X + 1, y, IRON[3])
    for x in range(STACK_X - 2, STACK_X + 3):
        put(im, x, STACK_TOP, IRON[0] if x <= STACK_X else IRON[2])
    # the steam cylinder and the rod to the drum's crank
    rect(im, 13, 19, 15, 21, BRASS[1])
    put(im, 13, 19, BRASS[0])
    put(im, 14, 19, BRASS[0])
    put(im, 15, 21, BRASS[2])
    put(im, 14, 21, BRASS[2])
    put(im, 13, 16, IRON[1])                                    # the steam pipe from the boiler
    put(im, 14, 16, IRON[1])
    put(im, 14, 17, IRON[2])
    put(im, 14, 18, IRON[2])
    drum(im, 16, 27, 14, 23, k, ROPE)
    crank = ((16, 17), (16, 19), (16, 21), (16, 19))[k]
    put(im, crank[0], crank[1], STEEL[0])
    rect(im, 16, 25, 17, 25, IRON[2])                           # pedestal feet on the bed
    rect(im, 26, 25, 28, 25, IRON[2])
    fall(im, 23, 13, ROPE, k)
    outline(im)
    if on:
        steam_puff(im, k)
    return im


def lift_motor(k=None):
    on = k is not None
    k = k or 0
    im = new()
    # the cast bed plate
    for x in range(2, 30):
        put(im, x, 26, IRON[0])
        put(im, x, 27, IRON[1])
        put(im, x, 28, IRON[2])
        put(im, x, 29, IRON[3])
    for x in (3, 15, 28):
        put(im, x, 27, STEEL[0])
    # the motor housing: a barrel lying along the bed, ribbed with cooling fins
    for y in range(14, 25):
        for x in range(3, 15):
            row = y - 14
            if (x in (3, 14) and row in (0, 10)) or (x == 3 and row in (1, 9)):
                continue                                        # the rounded end bell
            tone = 0 if row == 1 else (1 if row < 5 else (2 if row < 9 else 3))
            if row == 0:
                tone = 1
            if 5 <= x <= 12 and x % 2 == 0 and row > 1:
                tone += 1                                       # between the fins
            if x <= 4:
                tone = max(tone, 1) if row < 8 else 3           # the end bell, plain
            put(im, x, y, step(IRON, tone))
    rect(im, 7, 19, 10, 20, BRASS[1])                           # the maker's plate
    put(im, 7, 19, BRASS[0])
    put(im, 10, 20, BRASS[2])
    for x in (4, 13):                                           # the feet
        put(im, x, 25, IRON[2])
        put(im, x + 1, 25, IRON[3])
    rect(im, 15, 18, 16, 20, STEEL[1])                          # the shaft coupling
    put(im, 15, 18, STEEL[0])
    put(im, 16, 20, STEEL[2])
    put(im, 15 + (k % 2), 19, IRON[3])
    drum(im, 17, 28, 14, 23, k, STEEL + [IRON[2]])
    rect(im, 17, 25, 18, 25, IRON[2])
    rect(im, 27, 25, 29, 25, IRON[2])
    fall(im, 24, 13, STEEL, k)
    # the brass switch box on the housing, with its knife switch and lamp
    rect(im, 7, 13, 8, 13, IRON[3])                             # the conduit it stands on
    rect(im, 4, 8, 11, 12, BRASS[1])
    for x in range(4, 12):
        put(im, x, 8, BRASS[0])
        put(im, x, 12, BRASS[2])
    for y in range(9, 13):
        put(im, 11, y, BRASS[2])
    rect(im, 6, 10, 9, 10, IRON[3])                             # the switch slot
    put(im, 9 if on else 6, 10, STEEL[0])                       # the handle, thrown across when running
    put(im, 9 if on else 6, 9, STEEL[1])
    lamp = (9, 6)                                               # the pilot lamp on top of the box
    rect(im, lamp[0], lamp[1], lamp[0] + 1, lamp[1] + 1, FIRE[1] if on else LAMP_OFF)
    if on:
        put(im, lamp[0], lamp[1], FIRE[0])
        put(im, lamp[0] + 1, lamp[1] + 1, FIRE[2] if k % 2 else FIRE[1])
    else:
        put(im, lamp[0], lamp[1], (132, 90, 46))
    return outline(im)


# ------------------------------------------------------------ call devices --

def lift_bell():
    frame = new()
    for x in range(5, 15):                                      # the foot block
        put(frame, x, 27, WOOD[0])
        put(frame, x, 28, WOOD[1])
        put(frame, x, 29, WOOD[3])
    for y in range(5, 27):                                      # the post
        for i, tone in enumerate((0, 1, 1, 3)):
            if 0 < i < 3 and noise(8 + i, y // 3, 51) < 50:
                tone = 2
            put(frame, 8 + i, y, WOOD[tone])
    for x in range(7, 25):                                      # the bracket arm
        put(frame, x, 5, WOOD[0])
        put(frame, x, 6, WOOD[2] if noise(x // 3, 6, 52) < 60 else WOOD[1])
        put(frame, x, 7, WOOD[3])
    put(frame, 24, 6, WOOD[2])                                  # end grain
    for i in range(7):                                          # the knee brace under it
        put(frame, 12 + i, 14 - i, WOOD[1])
        put(frame, 12 + i, 15 - i, WOOD[3])
    for i in range(3):                                          # iron strap where arm meets post
        put(frame, 12, 5 + i, IRON[i])
    bell = new()
    cx = 21                                                     # the bell hangs under the arm's end
    put(bell, cx, 8, IRON[1])                                   # the staple
    put(bell, cx + 1, 8, IRON[2])
    for y, half in ((9, 1), (10, 2), (11, 2), (12, 3), (13, 3), (14, 3), (15, 4), (16, 5)):
        for x in range(cx - half + 1, cx + half + 1):
            pos = (x - (cx - half + 1)) / max(1, 2 * half - 1)
            tone = 0 if pos < 0.3 else (1 if pos < 0.75 else 2)
            if y == 16:
                tone = min(2, tone + 1) if pos > 0.2 else 0     # the flared lip
            if y == 9:
                tone = 1
            put(bell, x, y, BRASS[tone])
    put(bell, cx - 1, 11, FIRE[0])                              # glint on the shoulder
    put(bell, cx - 1, 12, FIRE[0])
    put(bell, cx, 17, IRON[2])                                  # the clapper
    put(bell, cx + 1, 17, IRON[3])
    cord = new()
    for y in range(18, 26):                                     # the pull cord and its wooden toggle
        put(cord, cx, y, ROPE[0] if y % 3 else ROPE[2])
    for x in range(cx - 1, cx + 2):
        put(cord, x, 26, WOOD[0])
        put(cord, x, 27, WOOD[2])
    return over(outline(frame), outline(cord), outline(bell))


BUTTON = (13, 6)                    # left and top of the 6px button ring


def lift_button(lit=False):
    im = new()
    for y in range(16, 28):                                     # the slim post
        put(im, 15, y, IRON[0])
        put(im, 16, y, IRON[2])
    for x in range(12, 20):                                     # its foot
        put(im, x, 28, IRON[1] if x < 18 else IRON[2])
        put(im, x, 29, IRON[3])
    put(im, 14, 27, IRON[1])
    put(im, 17, 27, IRON[3])
    x0, y0, x1, y1 = 11, 3, 20, 15                              # the panel
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            c = BRASS[1]
            if y == y0 or x == x0:
                c = BRASS[0]
            if y == y1 or x == x1:
                c = BRASS[2]
            put(im, x, y, c)
    for x, y in ((x0 + 1, y0 + 1), (x1 - 1, y0 + 1), (x0 + 1, y1 - 1), (x1 - 1, y1 - 1)):
        put(im, x, y, BRASS[2])                                 # screws
    bx, by = BUTTON
    for dy in range(6):                                         # the ring and the button in it
        for dx in range(6):
            if dx in (0, 5) and dy in (0, 5):
                continue
            ring = dx in (0, 5) or dy in (0, 5)
            core = 1 < dx < 4 and 1 < dy < 4
            if ring:
                c = IRON[3] if dx + dy < 5 else IRON[2]
                if lit:
                    c = FIRE[3] if dx + dy < 5 else FIRE[2]
            elif lit:
                c = FIRE[0] if core and dx + dy <= 5 else FIRE[1]
                if dx == 4 and dy == 4:
                    c = FIRE[2]
            else:
                c = STEEL[0] if dx + dy <= 3 else (STEEL[1] if dx + dy < 7 else STEEL[2])
            put(im, bx + dx, by + dy, c)
    if lit:                                                     # the glow on the brass round it
        for x, y in ((bx - 1, by + 2), (bx - 1, by + 3), (bx + 6, by + 2), (bx + 6, by + 3),
                     (bx + 2, by - 1), (bx + 3, by - 1), (bx + 2, by + 6), (bx + 3, by + 6)):
            put(im, x, y, FIRE[1])
        for x, y in ((bx, by), (bx + 5, by), (bx, by + 5), (bx + 5, by + 5)):
            put(im, x, y, FIRE[1])
    for x in range(14, 18):                                     # the engraved label under it
        put(im, x, 13, BRASS[2] if x % 2 == 0 else IRON[2])
    return outline(im)


# ------------------------------------------------------------------ sheets --

def all_states():
    """[(state, dirs, frames, delay or None, [images, frame by frame])]"""
    loop = range(FRAMES)
    return [
        ('lift_wood', 1, 1, None, [lift_wood()]),
        ('lift_iron', 1, 1, None, [lift_iron()]),
        ('steam_lift_engine', 1, 1, None, [steam_lift_engine()]),
        ('steam_lift_engine_on', 1, FRAMES, DELAY, [steam_lift_engine(k) for k in loop]),
        ('lift_motor', 1, 1, None, [lift_motor()]),
        ('lift_motor_on', 1, FRAMES, DELAY, [lift_motor(k) for k in loop]),
        ('lift_bell', 1, 1, None, [lift_bell()]),
        ('lift_button', 1, 1, None, [lift_button()]),
        ('lift_button_lit', 1, 1, None, [lift_button(lit=True)]),
    ]


def build(states):
    images = [im for st in states for im in st[4]]
    cols = int(len(images) ** 0.5 + 0.999)
    rows = (len(images) + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * SIZE, rows * SIZE))
    for i, im in enumerate(images):
        sheet.paste(im, ((i % cols) * SIZE, (i // cols) * SIZE))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = %d\n\theight = %d\n' % (SIZE, SIZE)
    for name, dirs, frames, delay, _ in states:
        text += 'state = "%s"\n\tdirs = %d\n\tframes = %d\n' % (name, dirs, frames)
        if delay:
            text += '\tdelay = %s\n' % ','.join([str(delay)] * frames)
    text += '# END DMI\n'
    return sheet, text


def write_dmi(path_, sheet, text):
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path_, format='PNG', pnginfo=meta, optimize=True)


def same(path_, sheet, text):
    if not path_.exists():
        return False
    old = Image.open(path_)
    return old.info.get('Description') == text and old.size == sheet.size \
        and old.convert('RGBA').tobytes() == sheet.tobytes()


def check_drawing(states):
    """The promises the game code relies on."""
    by = {st[0]: st for st in states}
    a, b = PLAT
    for name in ('lift_wood', 'lift_iron'):
        im = by[name][4][0]
        assert all(im.getpixel((x, y))[3] == 255 for y in range(a + 4, b + 1) for x in range(a, b + 1)), \
            '%s must be a solid floor' % name
        assert sum(1 for x in range(SIZE) if im.getpixel((x, 0))[3]) >= 4, '%s lines must run off the top' % name
        box = im.getbbox()
        assert box[0] >= a - 1 and box[2] <= b + 2 and box[3] <= b + 2, '%s strays from its inset' % name
    iron = by['lift_iron'][4][0]
    assert iron.getpixel((16, b - 3))[:3] not in (STEEL[0],), 'the south side of the car must stay open'
    for name in ('steam_lift_engine', 'lift_motor'):
        still = by[name][4][0]
        frames = by[name + '_on'][4]
        assert len({f.tobytes() for f in frames}) == FRAMES, '%s_on frames must all differ' % name
        assert all(f.tobytes() != still.tobytes() for f in frames)
        box = still.getbbox()
        assert box[2] - box[0] <= 30 and box[1] >= 0 and box[3] <= 31
    assert by['lift_button'][4][0].tobytes() != by['lift_button_lit'][4][0].tobytes()
    assert by['lift_button'][4][0].getbbox() == by['lift_button_lit'][4][0].getbbox()
    for st in states:
        assert all(im.getbbox() for im in st[4]), '%s has an empty frame' % st[0]


def floor_tile(state):
    """A floor from floors.dmi to stand the pieces on; None if absent."""
    try:
        im = Image.open(FLOORS)
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


def preview(path_, states, scale=4):
    """Every icon and frame at 4x on a wooden floor, on plating and in a dark
    open shaft, each labelled, with a 1x strip on each."""
    backs = [('wooden floor', floor_tile('wood') or Image.new('RGBA', (SIZE, SIZE), (124, 88, 56, 255))),
             ('plating', floor_tile('plating') or Image.new('RGBA', (SIZE, SIZE), (110, 110, 112, 255))),
             ('dark shaft', Image.new('RGBA', (SIZE, SIZE), (30, 28, 30, 255)))]
    cells = []                                  # (caption, image)
    for name, _, frames, _, images in states:
        for i, im in enumerate(images):
            cells.append(('%s f%d' % (name, i + 1) if frames > 1 else name, im))
    cell, pad, label = SIZE * scale, 6, 12
    per_row = 8
    grid_rows = [cells[i:i + per_row] for i in range(0, len(cells), per_row)]
    width = pad + per_row * (cell + pad)
    height = pad + len(backs) * (label + len(grid_rows) * (label + cell + pad) + label + SIZE + pad) + pad
    out = Image.new('RGBA', (width, height), (24, 24, 24, 255))
    draw = ImageDraw.Draw(out)
    y = pad
    for title, back in backs:
        draw.text((pad, y), '%s  on %s' % (SHEET.name, title), fill=(240, 240, 240, 255))
        y += label
        for row in grid_rows:
            for i, (caption, im) in enumerate(row):
                x = pad + i * (cell + pad)
                draw.text((x, y), caption[:21], fill=(200, 220, 160, 255))
                tile = back.copy()
                tile.alpha_composite(im)
                out.paste(tile.resize((cell, cell), Image.NEAREST), (x, y + label))
            y += label + cell + pad
        draw.text((pad, y), '1x (game scale), same order', fill=(240, 240, 240, 255))
        y += label
        for i, (_, im) in enumerate(cells):
            tile = back.copy()
            tile.alpha_composite(im)
            out.paste(tile, (pad + i * (SIZE + 2), y))
        y += SIZE + pad
    Path(path_).parent.mkdir(parents=True, exist_ok=True)
    out.save(path_, format='PNG')


def main(argv):
    states = all_states()
    check_drawing(states)
    if '--check' in argv:
        if not same(SHEET, *build(states)):
            sys.exit('stale sheet: ' + str(SHEET))
        print('lifts sheet matches')
    else:
        write_dmi(SHEET, *build(states))
        print('wrote %s (%d states)' % (SHEET.relative_to(ROOT), len(states)))
    if '--preview' in argv:
        preview(argv[argv.index('--preview') + 1], states)


if __name__ == '__main__':
    main(sys.argv[1:])
