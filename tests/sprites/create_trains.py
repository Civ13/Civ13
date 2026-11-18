"""Hand-placed art for the railway: the walkable platform cars (decks, sides,
windows, doors, railings, headstocks with couplers, roofs), the goods stock
(boxcar sides, sliding doors and roof, open wagon sides and drop doors), the car kit, the
railway gun car's lever and outriggers, the wreck overlay, three 3x4
locomotive bodies (steam, diesel, armoured) with their cab roofs, the 3x6
main-line engine with its three cab stations, the tender, and the
railway gun on its turntable. Every pixel is placed by this script from a
fixed palette (Pillow only); no external or generated artwork.

Everything is seen from straight above, like the submarine hulls, and lit
from the upper left in every direction (see trainkit.py). A car is three
tiles wide; `l`, `c` and `r` are the tile left of the heading, the rail tile
and the tile right of it, as train_platform_tiles() returns them.

    python3 tests/sprites/create_trains.py [--check] [--preview DIR]

Run with Pillow to reproduce icons/obj/vehicles/train_platforms.dmi and
railway_gun.dmi. `--check` writes nothing and fails when a committed sheet
differs from what this script draws. `--preview DIR` also writes review
renders: the state sheets and whole trains composed the way the game lays
the tiles out.
Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from trainkit import (Canvas, EDGE, HEADING, directions, mix, noise, ramp_at,  # noqa: E402
                      read_dmi, sheet_image, slice_car, write_dmi)

ROOT = Path(__file__).resolve().parents[2]
PLATFORMS = ROOT / 'icons/obj/vehicles/train_platforms.dmi'
GUN = ROOT / 'icons/obj/vehicles/railway_gun.dmi'
WATER = ROOT / 'icons/obj/vehicles/rail_water.dmi'
PLOUGH = ROOT / 'icons/obj/vehicles/train_plough.dmi'
LOADS = ROOT / 'icons/obj/vehicles/train_loads.dmi'
PIT = ROOT / 'icons/obj/vehicles/train_turntable.dmi'
PIT_LARGE = ROOT / 'icons/obj/vehicles/train_turntable_large.dmi'
RAILS = ROOT / 'icons/obj/vehicles/trains.dmi'

# ramps: lit, face, shade, outline
MAROON = ((170, 60, 56), (134, 38, 42), (98, 24, 30), (50, 12, 16))
TAN = ((208, 172, 120), (174, 138, 92), (134, 102, 64), (84, 60, 36))
WALNUT = ((154, 102, 56), (120, 76, 40), (88, 54, 28), (44, 26, 14))
OLIVE = ((140, 148, 110), (106, 114, 80), (78, 86, 58), (30, 34, 22))
OLIVE_D = (54, 60, 40)
RED = ((218, 64, 46), (172, 36, 32), (120, 22, 24), (58, 10, 12))
YELLOW = ((250, 216, 76), (216, 172, 38), (160, 120, 22), (70, 50, 10))
GLASS = ((218, 240, 248), (150, 200, 224), (98, 152, 184), (38, 60, 78))
# five-step metal ramps: glint, lit, face, shade, dark
STEEL = ((198, 204, 212), (152, 158, 168), (112, 118, 128), (80, 86, 96), (50, 54, 62))
STEEL_O = (24, 26, 32)
BLACK = ((124, 128, 138), (80, 84, 94), (52, 54, 62), (34, 36, 42), (18, 18, 22))
GREEN = ((126, 182, 124), (66, 132, 78), (40, 98, 56), (26, 70, 42), (12, 40, 24))
BLUE = ((136, 176, 230), (66, 108, 180), (42, 76, 144), (28, 52, 106), (14, 28, 64))
BRASS = ((252, 230, 146), (218, 180, 90), (166, 126, 54), (112, 80, 32), (66, 44, 16))
GUNM = ((172, 180, 188), (122, 130, 140), (84, 90, 100), (58, 62, 72), (30, 32, 38))
COPPER = ((244, 172, 100), (206, 118, 56), (150, 80, 36), (96, 48, 24))
PLANK = ((176, 128, 76), (150, 104, 58), (138, 94, 52), (160, 112, 64), (128, 86, 48))
PLANK_SEAM = (82, 54, 30)
OLD_PLANK = ((150, 126, 96), (126, 102, 76), (112, 90, 66), (134, 110, 82), (104, 84, 62))
OLD_SEAM = (64, 50, 36)
# freight oxide: the red-brown paint of goods stock
OXIDE = ((190, 96, 64), (150, 66, 48), (110, 46, 38), (54, 22, 20))
COAL = ((70, 70, 80), (40, 40, 48), (24, 24, 30), (12, 12, 16))
FIRE = ((255, 240, 170), (255, 176, 60), (226, 96, 28))
WHITE = (255, 255, 255)
DARK = (14, 14, 18)
CREAM = ((252, 250, 240), (228, 224, 208), (190, 186, 170), (112, 108, 98))
ICE = ((240, 250, 255), (196, 228, 246), (146, 192, 226), (86, 132, 180))
STRAW = ((244, 222, 140), (218, 188, 104), (178, 146, 76), (122, 96, 48))

DIR_INDEX = {'S': 0, 'N': 1, 'E': 2, 'W': 3}
LEFT_OF = {'N': 'W', 'W': 'S', 'S': 'E', 'E': 'N'}
OPPOSITE = {'N': 'S', 'S': 'N', 'E': 'W', 'W': 'E'}


# ---------------------------------------------------------------------------
# Surfaces

def planks(c, x0, y0, x1, y1, tones=PLANK, seam=PLANK_SEAM, seed=0, pitch=4):
    """Boards laid across the car (their long side runs east-west)."""
    k = 0
    y = y0
    while y <= y1:
        top = min(y + pitch - 1, y1)
        base = tones[1 + int(noise(k, seed, 7) * 4) % 4]
        cols = [mix(base, tones[0], 0.55)] + [base] * (top - y - 1) + [seam] if top - y >= 2 else [base, seam][:top - y + 1]
        c.bands(x0, y, x1, top, cols, along=False)
        for x in range(x0, x1 + 1):
            for yy in range(y + 1, top):
                n = noise(x // 3, yy + k * 5, seed + 3)
                if n < 0.12:
                    c.put(x, yy, mix(base, seam, 0.35))
                elif n > 0.93:
                    c.put(x, yy, mix(base, tones[0], 0.4))
        # a butt joint on some boards
        if x1 - x0 > 12 and noise(k, seed, 12) < 0.45:
            jx = x0 + 3 + int(noise(k, seed, 11) * max(1, x1 - x0 - 6))
            for yy in range(y, top):
                c.put(jx, yy, seam)
            if top - y >= 2:
                c.put(jx + 1, y + 1, mix(base, DARK, 0.45))
        k += 1
        y += pitch


def tread(c, x0, y0, x1, y1, face=STEEL[3], lit=STEEL[2], dark=STEEL[4], seams=True):
    """Chequer plate: small alternating diagonal dashes."""
    c.rect(x0, y0, x1, y1, face)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            gx, gy = x // 4, y // 4
            ix, iy = x % 4, y % 4
            if (gx + gy) % 2 == 0:
                on = (ix, iy) in ((1, 2), (2, 1))
            else:
                on = (ix, iy) in ((1, 1), (2, 2))
            if on:
                c.put(x, y, lit)
            elif noise(x, y, 21) < 0.05:
                c.put(x, y, mix(face, dark, 0.5))
    if seams:
        for y in range(y0, y1 + 1):
            if y % 16 == 15:
                c.rect(x0, y, x1, y, dark)
            elif y % 16 == 0:
                c.rect(x0, y, x1, y, mix(face, lit, 0.6))


def lino(c, x0, y0, x1, y1):
    """Cream floor tiles, eight pixels square, with a darker grout line."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            tone = noise(x // 8, y // 8, 30)
            col = mix((206, 196, 162), (220, 211, 180), tone)
            if x % 8 == 7 or y % 8 == 7:
                col = (170, 158, 124)
            elif x % 8 == 0 or y % 8 == 0:
                col = mix(col, WHITE, 0.25)
            else:
                n = noise(x, y, 31)
                if n < 0.05:
                    col = mix(col, (140, 128, 100), 0.3)
            c.put(x, y, col)


def carpet(c, x0, y0, x1, y1, border=True):
    base, deep, gold = (126, 30, 38), (100, 20, 30), (196, 152, 68)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            ix, iy = x % 8, y % 8
            col = base
            if abs(ix - 4) + abs(iy - 4) == 3:
                col = deep
            elif (ix, iy) == (4, 4):
                col = gold
            elif (ix, iy) == (0, 0):
                col = mix(base, gold, 0.35)
            elif noise(x, y, 41) < 0.10:
                col = mix(base, deep, 0.5)
            c.put(x, y, col)
    if border:
        for x in (x0, x1):
            c.rect(x, y0, x, y1, (78, 14, 22))
        for x in (x0 + 2, x1 - 2):
            c.rect(x, y0, x, y1, gold)
        for x in (x0 + 3, x1 - 3):
            c.rect(x, y0, x, y1, mix(base, deep, 0.6))


def hopper_floor(c):
    """The floor of a hopper: dark steel slope sheets falling to a pair of
    drop doors down the middle of the car."""
    c.rect(0, 0, 31, 31, BLACK[2])
    for x in range(32):
        d = abs(x - 15.5)
        tone = BLACK[1] if d > 12 else (BLACK[2] if d > 7 else BLACK[3])
        c.rect(x, 0, x, 31, tone)
    for y in range(32):
        for x in range(32):
            if noise(x, y, 31) < 0.06:
                c.put(x, y, mix(BLACK[2], OXIDE[2], 0.5))
    # the doors and their hinge straps
    c.rect(9, 0, 22, 31, BLACK[4])
    c.rect(10, 1, 15, 30, BLACK[3])
    c.rect(16, 1, 21, 30, mix(BLACK[3], BLACK[4], 0.5))
    c.rect(10, 1, 10, 30, BLACK[1])
    for y in (5, 15, 26):
        c.rect(7, y, 24, y, STEEL[4])
        c.put(8, y, STEEL[1])
        c.put(23, y, STEEL[2])


def straw_floor(c):
    """A stock car's floor: worn boards under a litter of straw."""
    planks(c, 0, 0, 31, 31, tones=OLD_PLANK, seam=OLD_SEAM, seed=5)
    for y in range(32):
        for x in range(32):
            n = noise(x // 5, y // 2, 61)
            m = noise(x // 3, y, 62)
            if n < 0.12:
                continue  # a bare patch of board
            c.put(x, y, STRAW[1] if m > 0.28 else STRAW[2])
            if m > 0.93:
                c.put(x, y, STRAW[0])
            elif m < 0.035:
                c.put(x, y, STRAW[3])


SURFACES = {
    'hopper': hopper_floor,
    'straw': straw_floor,
    'wood': lambda c: planks(c, 0, 0, 31, 31, seed=1),
    'floor': lambda c: lino(c, 0, 0, 31, 31),
    'carpet': lambda c: carpet(c, 0, 0, 31, 31),
    'steel': lambda c: tread(c, 0, 0, 31, 31),
    # the worn grey floor boards of goods stock
    'boards': lambda c: planks(c, 0, 0, 31, 31, tones=OLD_PLANK, seam=OLD_SEAM, seed=5),
}


def deck_center(kind):
    return directions(SURFACES[kind], order=HEADING)


def deck_side(kind):
    """A side tile, drawn with the car's outer edge to the west."""
    def draw(c):
        if kind == 'carpet':
            carpet(c, 0, 0, 31, 31, border=False)
        elif kind == 'wood':
            planks(c, 0, 0, 31, 31, seed=2)
        else:
            SURFACES[kind](c)
        # the side sill and its stake pockets and axle box
        c.rect(0, 0, 0, 31, STEEL_O)
        c.rect(1, 0, 1, 31, STEEL[3])
        c.shade(2, 0, 2, 31, 70)
        for y in (2, 9, 23, 30):
            c.put(1, y, STEEL[1])
        c.rect(0, 13, 1, 19, STEEL[4])
        c.put(1, 15, STEEL[0])
        c.put(1, 17, STEEL[2])
    return directions(draw, order=EDGE)


# ---------------------------------------------------------------------------
# Car sides: drawn against the west edge of the tile

def wall_run(c, y0, y1, ramp, thick=4, shadow=True):
    c.rect(0, y0, thick - 1, y1, ramp[3])
    inner = thick - 2
    cols = [ramp[0], ramp[2]] if inner == 2 else ([ramp[0], ramp[1], ramp[2]] if inner == 3 else [ramp[0]])
    c.bands(1, y0, thick - 2, y1, cols, along=True)
    if shadow:
        c.shade(thick, y0, thick, y1, 80)
        c.shade(thick + 1, y0, thick + 1, y1, 34)


def glass_run(c, y0, y1, x0=0, x1=3):
    c.rect(x0, y0, x1, y1, GLASS[3])
    c.bands(x0 + 1, y0 + 1, x1 - 1, y1 - 1, [GLASS[0], GLASS[1]] if x1 - x0 == 3 else [GLASS[1]], along=True)
    c.put(x0 + 1, y0 + 2, WHITE)
    if x1 - x0 == 3:
        c.put(x0 + 2, y0 + 3, WHITE, 190)
        c.put(x0 + 2, y1 - 2, GLASS[2])
    # daylight on the floor inside
    c.rect(x1 + 1, y0 + 1, x1 + 3, y1 - 1, (255, 248, 214), 30)


def edge_wall(c):
    wall_run(c, 0, 31, MAROON)
    for y in (7, 15, 23, 31):
        c.rect(1, y, 2, y, MAROON[2])


def edge_window(c):
    wall_run(c, 0, 31, MAROON)
    glass_run(c, 4, 14)
    glass_run(c, 17, 27)
    c.rect(1, 15, 2, 16, BRASS[1])


def door_leaf(c, y0, y1, ramp, thick=4, lite=True):
    c.rect(0, y0, thick - 1, y1, ramp[3])
    c.bands(1, y0 + 1, thick - 2, y1 - 1, [ramp[0], ramp[1]] if thick == 4 else [ramp[0]], along=True)
    if lite:
        mid = (y0 + y1) // 2
        c.rect(1, mid - 3, thick - 2, mid + 3, GLASS[1])
        c.put(1, mid - 2, WHITE)
        c.rect(1, mid - 4, thick - 2, mid - 4, ramp[3])
        c.rect(1, mid + 4, thick - 2, mid + 4, ramp[3])
    c.put(thick - 1, y1 - 3, BRASS[0])
    c.put(thick, y1 - 3, BRASS[2])


def sill_plate(c, y0, y1, thick=4):
    """The threshold seen through an open doorway."""
    c.rect(0, y0, thick - 1, y1, STEEL[4])
    for y in range(y0 + 1, y1, 2):
        c.rect(1, y, thick - 2, y, STEEL[2])
    c.rect(0, y0, thick - 1, y0, STEEL_O)
    c.rect(0, y1, thick - 1, y1, STEEL_O)


def edge_door(c):
    wall_run(c, 0, 31, MAROON)
    door_leaf(c, 6, 25, WALNUT)
    c.rect(4, 7, 4, 24, STEEL[1])
    c.shade(5, 7, 5, 24, 50)


def edge_door_open(c):
    wall_run(c, 0, 5, MAROON)
    wall_run(c, 26, 31, MAROON)
    sill_plate(c, 6, 25)
    # the leaf, swung inward on its hinge
    c.shade(5, 8, 24, 9, 70)
    c.rect(4, 5, 23, 7, WALNUT[3])
    c.bands(5, 6, 22, 6, [WALNUT[0]], along=False)
    c.rect(11, 6, 17, 6, GLASS[1])
    c.put(12, 6, WHITE)
    c.put(21, 8, BRASS[0])


def edge_partition(c):
    wall_run(c, 0, 31, TAN, thick=3)
    for y in (0, 29):
        c.bevel(0, y, 2, y + 2, TAN[0], TAN[1], TAN[2], outline=TAN[3])
    for y in (10, 20):
        c.put(1, y, TAN[2])


def edge_inner_door(c):
    wall_run(c, 0, 31, TAN, thick=3)
    door_leaf(c, 6, 25, WALNUT, thick=3)


def edge_inner_door_open(c):
    wall_run(c, 0, 5, TAN, thick=3)
    wall_run(c, 26, 31, TAN, thick=3)
    c.rect(0, 6, 2, 25, (104, 78, 50))
    c.rect(1, 6, 1, 25, (128, 98, 64))
    # the leaf slid back along the wall
    c.shade(6, 15, 6, 31, 60)
    c.rect(3, 14, 5, 31, WALNUT[3])
    c.rect(4, 15, 4, 30, WALNUT[0])
    c.rect(4, 19, 4, 25, GLASS[1])
    c.put(5, 17, BRASS[0])


def edge_rail(c):
    c.shade(3, 0, 3, 31, 46)
    c.rect(2, 0, 2, 31, STEEL[4], 200)
    c.rect(1, 0, 1, 31, STEEL[0])
    for y in (0, 10, 20, 29):
        c.rect(0, y, 2, y + 2, STEEL_O)
        c.put(1, y + 1, STEEL[0])
        c.put(0, y, STEEL[2])
        c.shade(3, y + 1, 4, y + 2, 60)


def armor_run(c, y0, y1):
    c.rect(0, y0, 4, y1, OLIVE[3])
    c.bands(1, y0, 3, y1, [OLIVE[0], OLIVE[1], OLIVE[2]], along=True)
    c.shade(5, y0, 5, y1, 90)
    c.shade(6, y0, 6, y1, 40)


def edge_armor(c):
    armor_run(c, 0, 31)
    for y in (2, 8, 23, 29):
        c.rivet(2, y, OLIVE[0], OLIVE[3])
    for y in (11, 20):
        c.rect(1, y, 3, y, OLIVE_D)
    # the firing slit
    c.rect(0, 14, 4, 17, (12, 14, 10))
    c.rect(1, 18, 3, 18, OLIVE[0])


def edge_armor_door(c):
    armor_run(c, 0, 31)
    c.rect(0, 6, 4, 6, OLIVE[3])
    c.rect(0, 25, 4, 25, OLIVE[3])
    c.bands(1, 7, 3, 24, [mix(OLIVE[0], WHITE, 0.15), OLIVE[0], OLIVE[1]], along=True)
    for y in (8, 22):
        c.rect(3, y, 5, y + 1, STEEL[4])
        c.put(4, y, STEEL[1])
    c.disc(6, 15.5, 2.4, [STEEL[0], STEEL[2], STEEL[4]], outline=STEEL_O)
    c.rect(0, 14, 1, 17, (12, 14, 10))


def edge_armor_door_open(c):
    armor_run(c, 0, 5)
    armor_run(c, 26, 31)
    sill_plate(c, 6, 25, thick=5)
    c.shade(6, 9, 25, 10, 80)
    c.rect(5, 4, 24, 8, OLIVE[3])
    c.bands(6, 5, 23, 7, [OLIVE[0], OLIVE[1], OLIVE[2]], along=False)
    for x in (8, 15, 22):
        c.rivet(x, 6, mix(OLIVE[0], WHITE, 0.2), OLIVE[3])
    c.disc(19, 10, 2.2, [STEEL[0], STEEL[2], STEEL[4]], outline=STEEL_O)


def edge_plank(c):
    """A boxcar's boarded side: oxide planks between iron posts."""
    wall_run(c, 0, 31, OXIDE)
    for y in range(3, 32, 4):
        c.rect(1, y, 2, y, OXIDE[2])
    for y in (7, 23):
        c.rect(0, y, 3, y + 1, STEEL[4])
        c.put(1, y, STEEL[1])
        c.put(2, y + 1, STEEL[3])


def freight_leaf(c, y0, y1):
    lit = mix(OXIDE[0], WHITE, 0.2)
    c.rect(0, y0, 3, y1, OXIDE[3])
    c.bands(1, y0 + 1, 2, y1 - 1, [lit, OXIDE[1]], along=True)
    for y in range(y0 + 4, y1, 4):
        c.rect(1, y, 2, y, OXIDE[2])


def edge_freight_door(c):
    """The sliding door of a boxcar, shut: a wide leaf hung from a runner."""
    wall_run(c, 0, 31, OXIDE)
    freight_leaf(c, 2, 29)
    # the runner along the outside and its two hangers
    c.rect(0, 0, 0, 31, STEEL[4])
    for y in (3, 28):
        c.rect(0, y, 1, y, STEEL[1])
    # hasp and handle on the inside face
    c.rect(3, 14, 3, 17, STEEL[0])
    c.put(4, 15, STEEL[2])
    c.put(4, 16, STEEL[4])


def edge_freight_door_open(c):
    """The doorway clear, the leaf run back along the side past this tile."""
    wall_run(c, 0, 2, OXIDE)
    wall_run(c, 29, 31, OXIDE)
    sill_plate(c, 3, 28)
    c.rect(0, 0, 0, 31, STEEL[4])
    # the end of the leaf, standing proud of the wall
    c.rect(0, 0, 3, 2, OXIDE[3])
    c.rect(1, 0, 2, 1, mix(OXIDE[0], WHITE, 0.2))
    c.put(0, 1, STEEL[1])


def edge_slat(c):
    """A stock car's side: boards with gaps between them, on iron posts."""
    wall_run(c, 0, 31, OXIDE)
    for y in range(2, 32, 4):
        # the gap between two slats: the floor shows through
        c.clear(1, y, 2, y + 1)
        c.shade(1, y, 2, y, 110)
    for y in (7, 23):
        c.rect(0, y, 3, y + 1, STEEL[4])
        c.put(1, y, STEEL[1])


def slat_leaf(c, y0, y1):
    c.rect(0, y0, 3, y1, OXIDE[3])
    c.bands(1, y0 + 1, 2, y1 - 1, [mix(OXIDE[0], WHITE, 0.2), OXIDE[1]], along=True)
    for y in range(y0 + 3, y1 - 1, 4):
        c.clear(1, y, 2, y)
        c.shade(1, y, 2, y, 150)


def edge_slat_door(c):
    """The sliding door of a stock car, shut: a slatted leaf hung from a runner."""
    wall_run(c, 0, 31, OXIDE)
    slat_leaf(c, 2, 29)
    c.rect(0, 0, 0, 31, STEEL[4])
    for y in (3, 28):
        c.rect(0, y, 1, y, STEEL[1])
    c.rect(3, 14, 3, 17, STEEL[0])
    c.put(4, 15, STEEL[2])
    c.put(4, 16, STEEL[4])


def edge_slat_door_open(c):
    wall_run(c, 0, 2, OXIDE)
    wall_run(c, 29, 31, OXIDE)
    sill_plate(c, 3, 28)
    c.rect(0, 0, 0, 31, STEEL[4])
    c.rect(0, 0, 3, 2, OXIDE[3])
    c.rect(1, 0, 2, 1, mix(OXIDE[0], WHITE, 0.2))
    c.put(0, 1, STEEL[1])


def edge_cold(c):
    """An ice car's side: thick insulated boarding painted white, iron straps."""
    wall_run(c, 0, 31, CREAM, thick=5)
    for y in range(5, 32, 6):
        c.rect(1, y, 3, y, CREAM[2])
    for y in (10, 22):
        c.rect(0, y, 4, y, STEEL[4])
        c.put(1, y, STEEL[1])
        c.put(3, y, STEEL[2])


def edge_cold_door(c):
    """The thick hinged door of an ice car, shut: strap hinges and a lever latch."""
    wall_run(c, 0, 31, CREAM, thick=5)
    c.rect(0, 3, 4, 28, CREAM[3])
    c.bands(1, 4, 3, 27, [CREAM[0], CREAM[1], CREAM[2]], along=True)
    for y in (6, 25):
        c.rect(0, y, 4, y, STEEL_O)
        c.rect(1, y, 3, y, STEEL[2])
        c.put(1, y, STEEL[0])
    # the latch bar on the inside face
    c.rect(4, 13, 4, 18, STEEL[1])
    c.put(5, 15, STEEL[0])
    c.put(5, 16, STEEL[3])


def edge_cold_door_open(c):
    wall_run(c, 0, 2, CREAM, thick=5)
    wall_run(c, 29, 31, CREAM, thick=5)
    sill_plate(c, 3, 28, thick=5)
    # the leaf swung in on its hinges, its thick edge showing
    c.shade(6, 5, 27, 7, 70)
    c.rect(5, 1, 26, 5, CREAM[3])
    c.bands(6, 2, 25, 4, [CREAM[0], CREAM[1], CREAM[2]], along=False)
    for x in (9, 22):
        c.rect(x, 1, x, 5, STEEL[3])
    c.put(24, 6, STEEL[0])


SIDE_WOOD = (PLANK[0], PLANK[1], PLANK[4], PLANK_SEAM)


def low_run(c, y0, y1):
    """An open wagon's plank side: lower than a wall, so it throws less shadow."""
    c.rect(0, y0, 3, y1, SIDE_WOOD[3])
    c.rect(1, y0, 1, y1, mix(SIDE_WOOD[0], WHITE, 0.22))
    c.rect(2, y0, 2, y1, SIDE_WOOD[1])
    c.shade(4, y0, 4, y1, 70)
    c.shade(5, y0, 5, y1, 26)


def stanchion(c, y):
    c.rect(0, y, 3, y + 1, STEEL_O)
    c.rect(1, y, 2, y, STEEL[0])
    c.rect(1, y + 1, 2, y + 1, STEEL[2])
    c.shade(4, y, 4, y + 1, 40)


def edge_side(c):
    low_run(c, 0, 31)
    for y in range(5, 32, 6):
        c.put(1, y, SIDE_WOOD[1])
    for y in (0, 15, 30):
        stanchion(c, y)


def edge_drop_door(c):
    """A drop door in an open wagon's side, up and pinned."""
    low_run(c, 0, 31)
    for y in (0, 30):
        stanchion(c, y)
    # the door between its posts, its strap hinges and the pins that hold it
    c.rect(1, 3, 2, 28, mix(SIDE_WOOD[0], WHITE, 0.34))
    c.rect(2, 3, 2, 28, SIDE_WOOD[0])
    for y in (7, 15, 23):
        c.rect(0, y, 4, y, STEEL[4])
        c.rect(1, y, 2, y, STEEL[1])
    for y in (3, 28):
        c.rect(0, y, 3, y, STEEL_O)
        c.put(4, y, BRASS[1])


def edge_drop_door_open(c):
    """The door let down outside the wagon: only its hinge line is left."""
    low_run(c, 0, 2)
    low_run(c, 29, 31)
    for y in (0, 30):
        stanchion(c, y)
    c.rect(0, 3, 0, 28, STEEL[4])
    for y in (7, 15, 23):
        c.rect(0, y, 1, y, STEEL[1])
    for y in (3, 28):
        c.put(1, y, BRASS[1])


def edge_hopper(c):
    """A hopper's steel side: a plate with a rolled top edge and pressed ribs."""
    c.rect(0, 0, 4, 31, STEEL_O)
    c.bands(1, 0, 3, 31, [BLACK[0], BLACK[1], BLACK[2]], along=True)
    c.shade(5, 0, 5, 31, 90)
    c.shade(6, 0, 6, 31, 40)
    for y in (3, 11, 19, 27):
        c.rect(0, y, 4, y + 1, STEEL_O)
        c.rect(1, y, 3, y, STEEL[1])
        c.rect(1, y + 1, 3, y + 1, STEEL[3])
    for y in (7, 15, 23):
        c.rivet(2, y, STEEL[0], BLACK[4])


EDGES = {
    'edge_hopper': edge_hopper,
    'edge_slat': edge_slat, 'edge_slat_door': edge_slat_door, 'edge_slat_door_open': edge_slat_door_open,
    'edge_cold': edge_cold, 'edge_cold_door': edge_cold_door, 'edge_cold_door_open': edge_cold_door_open,
    'edge_plank': edge_plank, 'edge_freight_door': edge_freight_door, 'edge_freight_door_open': edge_freight_door_open,
    'edge_side': edge_side, 'edge_drop_door': edge_drop_door, 'edge_drop_door_open': edge_drop_door_open,
    'edge_wall': edge_wall, 'edge_window': edge_window, 'edge_armor': edge_armor,
    'edge_door': edge_door, 'edge_door_open': edge_door_open,
    'edge_inner_door': edge_inner_door, 'edge_inner_door_open': edge_inner_door_open,
    'edge_partition': edge_partition, 'edge_rail': edge_rail,
    'edge_armor_door': edge_armor_door, 'edge_armor_door_open': edge_armor_door_open,
}


# ---------------------------------------------------------------------------
# Headstocks, outriggers and the small single sprites

def buffer(c, x, y):
    c.disc(x, y, 3.3, [STEEL[0], STEEL[2], STEEL[4]], outline=STEEL_O)
    c.put(x - 1, y - 1, WHITE, 150)


def headstock(c, ramp=RED):
    """The end beam of a car across its three tiles, facing north."""
    c.shade(2, 4, 93, 4, 70)
    c.bevel(1, 0, 94, 3, ramp[0], ramp[1], ramp[2], outline=ramp[3])
    for x in (8, 38, 57, 87):
        c.rivet(x, 2, mix(ramp[0], WHITE, 0.3), ramp[3])
    buffer(c, 21.5, 1.0)
    buffer(c, 73.5, 1.0)
    # the coupling: draw hook and its link
    c.rect(44, 0, 51, 3, STEEL_O)
    c.rect(45, 0, 50, 2, STEEL[3])
    c.rect(46, 0, 49, 0, STEEL[0])
    c.rect(47, 1, 48, 2, DARK)


def end_states():
    """Headstock pieces as overlays that follow their tile's own direction:
    end_fc / end_bc ride on the rail tile (dir = the car's heading), the
    l and r pieces on the side deck tiles (dir = that tile's outward side)."""
    imgs = directions(headstock, w=96, h=32, order=HEADING)
    piece = {col: slice_car(imgs, 1, 0, col) for col in (-1, 0, 1)}
    out = {name: [None] * 4 for name in ('end_fl', 'end_fc', 'end_fr', 'end_bl', 'end_bc', 'end_br')}
    for h in 'SNEW':
        left, right, back = LEFT_OF[h], OPPOSITE[LEFT_OF[h]], OPPOSITE[h]
        out['end_fc'][DIR_INDEX[h]] = piece[0][DIR_INDEX[h]]
        out['end_fl'][DIR_INDEX[left]] = piece[-1][DIR_INDEX[h]]
        out['end_fr'][DIR_INDEX[right]] = piece[1][DIR_INDEX[h]]
        out['end_bc'][DIR_INDEX[h]] = piece[0][DIR_INDEX[back]]
        out['end_bl'][DIR_INDEX[left]] = piece[1][DIR_INDEX[back]]
        out['end_br'][DIR_INDEX[right]] = piece[-1][DIR_INDEX[back]]
    return out


def coupler_body(c, ramp=STEEL):
    c.bevel(13, 0, 18, 4, ramp[0], ramp[2], ramp[4], outline=STEEL_O)


def coupler_free(c):
    """A whole coupling at a free end (car heading north, its end at the top):
    the draw hook with its link swung aside."""
    coupler_body(c)
    c.rect(15, 1, 16, 2, DARK)
    c.rect(19, 2, 19, 3, STEEL[3])
    c.ring(22.0, 3.5, 2.6, STEEL_O, width=2.4)
    c.ring(22.0, 3.5, 2.4, STEEL[0], width=1.0)


def coupler_linked(c):
    """Half of a made coupling: the links run over the car's end onto the
    next car's hook, drawn up tight by the brass screw between them."""
    coupler_body(c)
    c.rect(12, 0, 12, 3, STEEL_O)
    c.rect(19, 0, 19, 3, STEEL_O)
    c.rect(13, 0, 13, 2, STEEL[0])
    c.rect(18, 0, 18, 2, STEEL[0])
    c.rect(14, 0, 17, 1, BRASS[1])
    c.put(14, 0, BRASS[0])
    c.rect(15, 1, 16, 1, BRASS[3])


def coupler_broken(c):
    """A snapped coupling: a cracked, rusting stub and a link hanging loose."""
    c.bevel(13, 1, 18, 4, BLACK[1], BLACK[2], BLACK[4], outline=STEEL_O)
    for x in (13, 15, 18):
        c.put(x, 0, STEEL_O)
    c.line(14, 4, 17, 1, DARK)
    c.put(16, 3, OXIDE[0])
    c.put(14, 2, OXIDE[1])
    c.line(19, 2, 22, 5, STEEL[3])
    c.put(22, 5, STEEL[0])


def coupler_none(c):
    """The empty drawbar pocket of an end whose coupling was taken off."""
    c.rect(13, 0, 18, 3, STEEL_O)
    c.rect(14, 0, 17, 2, DARK)
    c.put(14, 2, STEEL[4])
    c.put(12, 1, STEEL_O)
    c.put(19, 1, STEEL_O)


def coupler_states():
    """coupler_f_* sit at the end a car faces, coupler_b_* at its other end;
    both turn with the car (train_couplings.dm)."""
    out = {}
    for kind, draw in (('free', coupler_free), ('linked', coupler_linked),
                       ('broken', coupler_broken), ('none', coupler_none)):
        front = directions(draw, order=HEADING)
        out['coupler_f_' + kind] = front
        out['coupler_b_' + kind] = [front[DIR_INDEX[OPPOSITE[h]]] for h in 'SNEW']
    return out


def knuckle_head(c, ramp=STEEL):
    """The cast head of an automatic coupler on its shank."""
    c.bevel(14, 2, 17, 4, ramp[1], ramp[2], ramp[4], outline=STEEL_O)
    c.rect(11, 0, 20, 2, STEEL_O)
    c.rect(12, 0, 19, 1, ramp[2])
    c.rect(12, 0, 15, 0, ramp[0])


def knuckle_free(c):
    """An automatic coupler at a free end: the knuckle stands open, with the
    uncoupling lever's rod running off to the side of the car."""
    knuckle_head(c)
    c.rect(17, 0, 19, 0, DARK)
    c.put(20, 0, STEEL[0])
    c.rect(21, 3, 25, 3, STEEL_O)
    c.rect(21, 3, 24, 3, STEEL[3])
    c.put(25, 2, BRASS[1])


def knuckle_linked(c):
    """Half of a pair of locked knuckles: the head closed on its mate across
    the car's end, the lock pin showing as a brass dot."""
    knuckle_head(c)
    c.rect(12, 0, 19, 0, STEEL[3])
    c.rect(15, 0, 16, 1, DARK)
    c.put(18, 1, BRASS[0])
    c.rect(21, 3, 25, 3, STEEL_O)
    c.rect(21, 3, 24, 3, STEEL[3])
    c.put(25, 2, BRASS[1])


def knuckle_broken(c):
    """A cracked head with the knuckle torn out of it."""
    knuckle_head(c, BLACK)
    c.clear(17, 0, 20, 1)
    c.put(17, 1, STEEL_O)
    c.line(13, 0, 15, 2, DARK)
    c.put(16, 3, OXIDE[0])
    c.put(13, 1, OXIDE[1])
    c.line(21, 3, 23, 5, STEEL[3])


def knuckle_states():
    """knuckle_f_* / knuckle_b_*: an automatic coupler in place of the hook
    and screw link (train_shunting.dm)."""
    out = {}
    for kind, draw in (('free', knuckle_free), ('linked', knuckle_linked), ('broken', knuckle_broken)):
        front = directions(draw, order=HEADING)
        out['knuckle_f_' + kind] = front
        out['knuckle_b_' + kind] = [front[DIR_INDEX[OPPOSITE[h]]] for h in 'SNEW']
    return out


def plough_blade(c):
    """A wedge snowplough bolted to the headstock, 96 x 96 and centred on the
    car's end tile (car heading north): it stands out ahead of the car, two
    blades meeting at a point, the left one lit, over a drift of thrown snow."""
    for y in range(18, 35):
        half = 2 + int((y - 18) * 1.4)
        x0, x1 = 47 - half, 48 + half
        c.shade(x0 + 2, y + 2, x1 + 3, y + 2, 50)
    for y in range(18, 35):
        half = 2 + int((y - 18) * 1.4)
        x0, x1 = 47 - half, 48 + half
        c.rect(x0 - 1, y, x1 + 1, y, STEEL_O)
        c.rect(x0, y, 47, y, RED[0] if y < 30 else RED[1])
        c.rect(48, y, x1, y, RED[2] if y < 30 else RED[3])
        c.put(x0, y, STEEL[0])
        c.put(x0 + 1, y, STEEL[1])
        c.put(x1, y, STEEL[3])
        c.put(47, y, STEEL[1])
        c.put(48, y, STEEL_O)
    c.rect(46, 17, 49, 17, STEEL_O)
    c.rect(24, 35, 71, 35, STEEL_O)
    # the angle iron along the foot and its bolts
    c.rect(26, 33, 46, 33, STEEL[2])
    c.rect(49, 33, 69, 33, STEEL[4])
    for x in (30, 38, 57, 65):
        c.put(x, 31, STEEL[0])


def plough_states():
    front = directions(plough_blade, w=96, h=96, order=HEADING)
    return {'plough_f': front, 'plough_b': [front[DIR_INDEX[OPPOSITE[h]]] for h in 'SNEW']}


def plough_item():
    """A snowplough standing on the ground, point up."""
    c = Canvas(32, 32)
    c.shade(5, 24, 28, 27, 60)
    for y in range(6, 24):
        half = 1 + int((y - 6) * 0.72)
        x0, x1 = 15 - half, 16 + half
        c.rect(x0 - 1, y, x1 + 1, y, STEEL_O)
        c.rect(x0, y, 15, y, RED[0] if y < 20 else RED[1])
        c.rect(16, y, x1, y, RED[2])
        c.put(x0, y, STEEL[0])
        c.put(15, y, STEEL[1])
        c.put(16, y, STEEL_O)
    c.rect(2, 24, 29, 24, STEEL_O)
    c.put(15, 5, STEEL_O)
    c.put(16, 5, STEEL_O)
    for x in (8, 13, 18, 23):
        c.put(x, 21, STEEL[0])
    return [c.image()]


def knuckle_item():
    """A spare automatic coupler on the ground: shank, head and open knuckle."""
    c = Canvas(32, 32)
    c.shade(4, 21, 28, 23, 60)
    c.bevel(4, 14, 17, 18, STEEL[1], STEEL[2], STEEL[4], outline=STEEL_O)
    c.rect(6, 15, 8, 17, DARK)
    c.bevel(17, 10, 24, 21, STEEL[0], STEEL[2], STEEL[4], outline=STEEL_O)
    c.rect(22, 13, 24, 18, DARK)
    c.bevel(24, 9, 27, 13, STEEL[0], STEEL[1], STEEL[3], outline=STEEL_O)
    c.put(20, 12, BRASS[0])
    c.put(20, 13, BRASS[2])
    return [c.image()]


BRICK = ((176, 96, 72), (142, 70, 54), (104, 48, 40), (58, 26, 24))
ASH = ((196, 194, 188), (150, 148, 144), (104, 102, 100), (62, 60, 60))


def ash_pit(fill):
    """An ash pit between the rails of a track running north (train_servicing.dm):
    a brick-lined trough under the sleepers, drawn over them. fill 0 is swept
    out, 1 has ash on its floor with a few live embers, 2 is heaped to the rim."""
    def draw(c):
        # brick lining, lit from the upper left
        c.rect(11, 0, 23, 31, BRICK[3])
        for y in range(0, 32, 4):
            c.rect(11, y, 12, y + 2, BRICK[0] if (y // 4) % 2 else BRICK[1])
            c.rect(22, y, 23, y + 2, BRICK[2])
        # the pit itself
        c.rect(13, 0, 21, 31, DARK)
        c.rect(13, 0, 13, 31, (30, 26, 28))
        if fill == 0:
            c.speckle(14, 0, 21, 31, ASH[3], 0.10, seed=41)
        elif fill == 1:
            c.rect(14, 0, 21, 31, ASH[3])
            c.speckle(14, 0, 21, 31, ASH[2], 0.45, seed=42)
            c.speckle(14, 0, 21, 31, ASH[1], 0.12, seed=43)
            for x, y in ((16, 6), (19, 15), (15, 24)):
                c.put(x, y, FIRE[1])
                c.put(x + 1, y, FIRE[2])
        else:
            c.rect(13, 0, 21, 31, ASH[2])
            c.speckle(13, 0, 21, 31, ASH[1], 0.45, seed=44)
            c.speckle(13, 0, 21, 31, ASH[0], 0.14, seed=45)
            c.speckle(13, 0, 21, 31, ASH[3], 0.16, seed=46)
            for x, y in ((15, 4), (18, 11), (16, 19), (19, 27)):
                c.put(x, y, COAL[1])
        # the rails' cross ties are cut away over a pit: two iron bearers stay
        for y in (7, 23):
            c.rect(11, y, 23, y + 1, STEEL_O)
            c.rect(11, y, 23, y, STEEL[2])
    return directions(draw, order=HEADING)


def fire_rake():
    """A fireman's rake: a long iron shaft with a ring handle and a toothed
    head, lying across the tile."""
    c = Canvas(32, 32)
    c.shade(5, 24, 27, 26, 60)
    c.line(6, 23, 24, 9, STEEL_O)
    c.line(6, 22, 24, 8, STEEL[2])
    c.line(7, 22, 25, 8, STEEL_O)
    c.ring(5.0, 24.0, 2.6, STEEL_O, width=2.2)
    c.ring(5.0, 24.0, 2.4, STEEL[1], width=0.9)
    # the head, square to the shaft, with four teeth
    c.line(21, 4, 29, 12, STEEL_O)
    c.line(22, 4, 29, 11, BLACK[1])
    for x, y in ((22, 6), (24, 8), (26, 10), (28, 12)):
        c.line(x, y, x - 2, y + 2, STEEL_O)
    return [c.image()]


SAND = ((240, 222, 168), (214, 190, 132), (178, 152, 100), (122, 100, 62))


def brake_shoes():
    """A set of cast iron brake shoes: two curved blocks, face to face."""
    c = Canvas(32, 32)
    c.shade(8, 22, 26, 25, 60)
    for cx, lean in ((12.5, -1), (21.5, 1)):
        for y in range(8, 23):
            bow = round(2.2 * math.cos((y - 15) / 7.5 * math.pi / 2))
            x0 = int(cx - 2 + lean * (bow - 2))
            c.rect(x0 - 1, y, x0 + 4, y, STEEL_O)
            c.rect(x0, y, x0 + 3, y, BLACK[2])
            c.put(x0 if lean < 0 else x0 + 3, y, BLACK[0])
            c.put(x0 + 3 if lean < 0 else x0, y, mix(COPPER[2], BLACK[3], 0.5))
        # the lug the hanger pin goes through
        lx = int(cx + lean * 3)
        c.rect(lx - 1, 13, lx + 1, 17, STEEL_O)
        c.put(lx, 15, STEEL[1])
    return [c.image()]


def carriage_key():
    """A square-socket carriage key: a T handle on a short shank."""
    c = Canvas(32, 32)
    c.shade(10, 23, 24, 25, 60)
    c.rect(9, 8, 22, 12, STEEL_O)
    c.rect(10, 9, 21, 11, STEEL[2])
    c.rect(10, 9, 21, 9, STEEL[0])
    for x in (10, 21):
        c.put(x, 10, STEEL[4])
    c.rect(14, 12, 17, 23, STEEL_O)
    c.rect(15, 12, 16, 22, STEEL[2])
    c.rect(15, 12, 15, 22, STEEL[0])
    c.rect(13, 20, 18, 24, STEEL_O)
    c.rect(14, 21, 17, 23, STEEL[3])
    c.rect(15, 22, 16, 23, DARK)
    return [c.image()]


def ticket_punch():
    """A conductor's punch: two plier handles and the jaw with its die."""
    c = Canvas(32, 32)
    c.shade(8, 24, 25, 26, 60)
    c.line(9, 25, 14, 13, STEEL_O)
    c.line(10, 25, 15, 13, STEEL[1])
    c.line(22, 25, 17, 13, STEEL_O)
    c.line(21, 25, 16, 13, STEEL[3])
    for x in (9, 10, 21, 22):
        c.put(x, 25, WALNUT[1])
        c.put(x, 24, WALNUT[0])
    c.disc(15.5, 13.0, 2.2, [STEEL[0], STEEL[2], STEEL[4]], outline=STEEL_O)
    c.put(15, 13, BRASS[0])
    c.rect(12, 6, 19, 10, STEEL_O)
    c.rect(13, 7, 18, 9, STEEL[2])
    c.rect(13, 7, 18, 7, STEEL[0])
    c.rect(15, 8, 16, 9, DARK)
    return [c.image()]


def ticket_book():
    """A book of tickets: card covers, the stubs showing at the foot."""
    c = Canvas(32, 32)
    c.shade(8, 24, 26, 26, 60)
    c.bevel(7, 9, 24, 23, MAROON[0], MAROON[1], MAROON[2], outline=MAROON[3])
    c.rect(7, 9, 9, 23, MAROON[3])
    c.rect(8, 10, 8, 22, MAROON[2])
    c.rect(11, 12, 22, 15, CREAM[1])
    c.rect(12, 13, 21, 13, MAROON[2])
    c.rect(12, 14, 18, 14, MAROON[2], 150)
    c.rect(10, 21, 24, 22, CREAM[0])
    for x in range(11, 24, 3):
        c.put(x, 22, CREAM[3])
    return [c.image()]


def ticket(punched):
    """A card ticket; cancelled, it has a notch punched out of one edge."""
    c = Canvas(32, 32)
    c.shade(8, 21, 25, 22, 50)
    c.rect(7, 11, 24, 20, CREAM[3])
    c.rect(8, 12, 23, 19, CREAM[0])
    c.rect(8, 12, 12, 19, (190, 214, 170))
    c.rect(14, 13, 22, 13, MAROON[2])
    c.rect(14, 15, 20, 15, CREAM[3])
    c.rect(14, 17, 21, 17, CREAM[3])
    c.put(10, 15, MAROON[1])
    c.put(10, 16, MAROON[1])
    if punched:
        c.clear(18, 18, 20, 20)
        c.put(17, 19, CREAM[3])
        c.put(21, 19, CREAM[3])
        c.rect(18, 17, 20, 17, CREAM[3])
    return [c.image()]


def signal_flags():
    """A red and a green flag, their staffs crossed."""
    c = Canvas(32, 32)
    c.shade(9, 25, 24, 26, 60)
    c.line(11, 26, 20, 5, WALNUT[3])
    c.line(12, 26, 21, 5, WALNUT[1])
    c.line(21, 26, 12, 5, WALNUT[3])
    c.line(20, 26, 11, 5, WALNUT[1])
    for y in range(6, 15):
        x0 = 21 - (y - 5) // 2
        c.rect(x0, y, x0 + 8, y, GREEN[2] if y in (6, 14) else GREEN[1])
        c.put(x0 + 8, y, GREEN[3])
        c.put(x0 + 1 + (y % 3), y, GREEN[0])
    for y in range(6, 15):
        x1 = 11 + (y - 5) // 2
        c.rect(x1 - 8, y, x1, y, RED[2] if y in (6, 14) else RED[1])
        c.put(x1 - 8, y, RED[3])
        c.put(x1 - 2 - (y % 3), y, RED[0])
    return [c.image()]


def semaphore(clear):
    """A semaphore signal from the side: a white post, a red arm and its lamp."""
    c = Canvas(32, 32)
    c.shade(11, 29, 24, 30, 60)
    c.bevel(13, 27, 20, 29, STEEL[1], STEEL[2], STEEL[4], outline=STEEL_O)
    c.rect(15, 5, 18, 27, STEEL_O)
    c.rect(16, 6, 17, 20, CREAM[0])
    c.rect(17, 6, 17, 20, CREAM[2])
    c.rect(16, 21, 17, 26, BLACK[2])
    c.rect(17, 21, 17, 26, BLACK[4])
    c.rect(16, 3, 17, 4, RED[1])
    c.put(16, 2, RED[0])
    lamp = GREEN if clear else RED
    c.disc(21.0, 9.5, 2.6, [WHITE, lamp[0], lamp[1], lamp[2]], outline=DARK)
    c.rect(18, 9, 19, 10, STEEL[3])
    if clear:
        # the arm dropped: line clear
        for i in range(12):
            x, y = 15 - i, 8 + i
            c.rect(x - 1, y - 2, x + 1, y + 2, RED[3])
        for i in range(12):
            x, y = 15 - i, 8 + i
            tone = CREAM[0] if i in (7, 8) else RED[1]
            c.rect(x, y - 1, x, y + 1, tone)
            c.put(x, y - 1, CREAM[1] if i in (7, 8) else RED[0])
    else:
        # the arm level: danger
        c.rect(2, 6, 15, 11, RED[3])
        c.rect(3, 7, 15, 10, RED[1])
        c.rect(3, 7, 15, 7, RED[0])
        c.rect(3, 10, 15, 10, RED[2])
        c.rect(6, 7, 7, 10, CREAM[0])
    c.rect(15, 7, 18, 10, STEEL_O)
    c.put(16, 8, STEEL[0])
    c.put(17, 9, STEEL[2])
    return [c.image()]


def lever_frame():
    """A signal box lever frame: five long levers in an iron frame."""
    c = Canvas(32, 32)
    c.shade(3, 28, 29, 30, 60)
    c.bevel(1, 21, 30, 28, STEEL[1], STEEL[3], STEEL[4], outline=STEEL_O)
    c.rect(2, 23, 29, 23, STEEL[4])
    grips = (RED, RED, BLUE, BLACK, YELLOW)
    for i, ramp in enumerate(grips):
        x = 4 + i * 6
        pulled = i in (1, 3)
        lean = 1 if pulled else 0
        top = 11 if pulled else 6
        for off, col in ((0, STEEL[1]), (1, STEEL[4])):
            c.line(x + off, 21, x + off + lean, top, col)
        c.rect(x + lean - 1, top - 3, x + lean + 2, top + 1, mix(ramp[2], DARK, 0.5))
        c.rect(x + lean, top - 2, x + lean + 1, top, ramp[1])
        c.put(x + lean, top - 2, ramp[0])
        c.rect(x - 1, 20, x + 2, 22, STEEL_O)
        c.put(x, 21, STEEL[0])
        c.rect(x, 25, x + 1, 26, BRASS[1])
    return [c.image()]


def token_instrument():
    """A token instrument: a cast iron cabinet with a needle, a bell and a slot."""
    c = Canvas(32, 32)
    c.shade(8, 28, 25, 30, 60)
    c.bevel(8, 7, 23, 28, MAROON[0], MAROON[1], MAROON[2], outline=MAROON[3])
    c.rect(9, 18, 22, 18, MAROON[3])
    c.disc(15.5, 4.5, 2.8, [WHITE, BRASS[0], BRASS[1], BRASS[3]], outline=BRASS[4])
    c.rect(15, 7, 16, 7, BRASS[3])
    c.disc(15.5, 12.5, 4.2, [CREAM[0], CREAM[0], CREAM[1], CREAM[2]], outline=DARK)
    c.line(15, 13, 13, 10, RED[2])
    c.put(15, 13, DARK)
    c.rect(11, 21, 20, 23, BRASS[4])
    c.rect(12, 22, 19, 22, DARK)
    c.rect(11, 20, 20, 20, BRASS[1])
    c.disc(15.5, 25.5, 1.4, [BRASS[0], BRASS[2]], outline=BRASS[4])
    return [c.image()]


def train_token():
    """A single-line tablet: a brass disc with a hole and a notch."""
    c = Canvas(32, 32)
    c.shade(10, 22, 23, 24, 60)
    c.disc(15.5, 15.5, 6.6, [BRASS[0], BRASS[1], BRASS[2], BRASS[3]], outline=BRASS[4])
    c.ring(15.5, 15.5, 4.6, BRASS[3], width=0.8)
    c.disc(15.5, 15.5, 1.6, [DARK], outline=BRASS[4])
    c.rect(15, 9, 16, 10, BRASS[4])
    c.put(12, 12, WHITE)
    c.put(13, 11, WHITE)
    return [c.image()]


def section_board():
    """A lineside board on a post: a black tablet ring on white."""
    c = Canvas(32, 32)
    c.shade(11, 29, 22, 30, 60)
    c.rect(14, 16, 17, 29, WALNUT[3])
    c.rect(15, 16, 16, 28, WALNUT[1])
    c.rect(15, 16, 15, 28, WALNUT[0])
    c.bevel(6, 4, 25, 16, CREAM[0], CREAM[1], CREAM[2], outline=DARK)
    c.ring(15.5, 10.0, 3.6, DARK, width=1.2)
    c.rect(8, 6, 9, 14, BLACK[3])
    c.rect(22, 6, 23, 14, BLACK[3])
    return [c.image()]


def signal_wire():
    """A coil of iron signal wire with a loose end."""
    c = Canvas(32, 32)
    c.shade(8, 23, 25, 25, 60)
    for r, col in ((8.2, STEEL_O), (7.4, STEEL[1]), (6.4, STEEL[3]), (5.4, STEEL[2]), (4.4, STEEL[4])):
        c.ring(15.5, 15.5, r, col, width=1.0)
    c.line(22, 19, 27, 24, STEEL[2])
    c.line(22, 20, 26, 24, STEEL[4])
    c.put(10, 10, STEEL[0])
    c.put(11, 9, STEEL[0])
    c.rect(14, 22, 17, 24, WALNUT[3])
    c.rect(15, 22, 16, 23, WALNUT[1])
    return [c.image()]


def buffer_stop(c):
    """A buffer stop at the end of a line that runs north: two raking rails
    bolted to the track, a red beam across them and a buffer over each rail."""
    c.shade(5, 9, 30, 13, 70)
    for x in (6, 26):
        c.rect(x - 1, 11, x + 3, 30, STEEL_O)
        c.bands(x, 12, x + 2, 29, [STEEL[1], STEEL[2], STEEL[4]], along=True)
        for y in (16, 22, 28):
            c.rivet(x + 1, y, STEEL[0], STEEL_O)
    # the cross brace between the raking rails
    c.rect(9, 19, 25, 22, WALNUT[3])
    c.rect(9, 20, 25, 21, WALNUT[1])
    c.rect(9, 20, 25, 20, WALNUT[0])
    # the beam, red with a white band
    c.bevel(2, 3, 31, 9, RED[0], RED[1], RED[2], outline=RED[3])
    c.rect(13, 4, 20, 8, CREAM[0])
    c.rect(13, 8, 20, 8, CREAM[2])
    # the buffers face the train
    for x in (7.5, 27.5):
        c.rect(int(x), 10, int(x) + 1, 12, STEEL[4])
        c.disc(x, 13.5, 2.6, [STEEL[0], STEEL[1], STEEL[3]], outline=STEEL_O)


def crossing_boards(c):
    """Boards between and beside the rails of a line that runs north."""
    for x0, x1, seed in ((0, 4, 71), (10, 24, 72), (30, 31, 73)):
        c.rect(x0, 0, x1, 31, OLD_SEAM)
        for x in range(x0, x1 + 1):
            tone = OLD_PLANK[(x * 7 + seed) % len(OLD_PLANK)]
            for y in range(32):
                c.put(x, y, OLD_SEAM if (x - x0) % 5 == 4 and x != x1 else (mix(tone, DARK, 0.18) if noise(x, y // 3, seed) > 0.82 else tone))
    for y in (3, 15, 28):
        for x in (2, 12, 17, 22):
            c.put(x, y, STEEL[4])


def crossing_gate(c, shut):
    """A crossing gate beside rails that lie to the north: shut, it lies
    across the road along the top of its tile; open, it is swung back along
    the left edge of the road."""
    c.shade(2, 4, 6, 8, 70)
    if shut:
        c.shade(4, 7, 31, 8, 60)
        c.bevel(3, 2, 31, 6, CREAM[0], CREAM[1], CREAM[2], outline=DARK)
        for x in (10, 18, 26):
            c.rect(x, 3, x, 5, CREAM[3])
        c.disc(17.0, 4.0, 3.4, [(255, 190, 170), RED[0], RED[1], RED[2]], outline=DARK)
        c.bevel(28, 1, 31, 7, WALNUT[0], WALNUT[1], WALNUT[3], outline=DARK)
    else:
        c.shade(5, 4, 6, 31, 60)
        c.bevel(1, 3, 5, 31, CREAM[0], CREAM[1], CREAM[2], outline=DARK)
        for y in (10, 18, 26):
            c.rect(2, y, 4, y, CREAM[3])
        c.disc(3.0, 17.0, 3.4, [(255, 190, 170), RED[0], RED[1], RED[2]], outline=DARK)
    # the hinge post
    c.bevel(0, 0, 5, 6, WALNUT[0], WALNUT[1], WALNUT[3], outline=DARK)
    c.put(2, 3, BRASS[0])


def turntable_deck(c):
    """The plank deck of a turntable bridge under rails that run north."""
    c.rect(0, 0, 31, 31, OLD_SEAM)
    for y in range(32):
        tone = OLD_PLANK[(y // 4 * 3 + 1) % len(OLD_PLANK)]
        for x in range(0, 32):
            c.put(x, y, OLD_SEAM if y % 4 == 3 else (mix(tone, DARK, 0.2) if noise(x // 3, y, 91) > 0.84 else tone))


def turntable_girders(c):
    """The riveted plate girders along each side of the bridge, drawn over
    the rails that run north."""
    for x0 in (0, 30):
        c.rect(x0, 0, x0 + 1, 31, STEEL[3])
        c.rect(x0 + (1 if x0 else 0), 0, x0 + (1 if x0 else 0), 31, STEEL_O)
        c.rect(x0 + (0 if x0 else 1), 0, x0 + (0 if x0 else 1), 31, STEEL[1])
        for y in (3, 11, 19, 27):
            c.put(x0 + (0 if x0 else 1), y, STEEL[0])


def turntable_pivot():
    """The pivot of a turntable, seen between the rails: a cast bearing ring
    bolted down, with a brass cap."""
    c = Canvas(32, 32)
    c.disc(16.5, 16.5, 6.4, [STEEL[2], STEEL[3], STEEL[4]], outline=STEEL_O)
    c.ring(16.5, 16.5, 4.2, STEEL[1], width=1.0)
    for x, y in ((13, 13), (20, 13), (13, 20), (20, 20)):
        c.put(x, y, STEEL[0])
    c.disc(16.5, 16.5, 2.2, [BRASS[0], BRASS[1], BRASS[3]], outline=DARK)
    return [c.image()]


def track_wear(bad):
    """What worn track shows between the rails, the same whichever way the
    line runs: weeds in the ballast and dark, sunk patches; in a bad way,
    more of both and the splintered ends of split sleepers."""
    c = Canvas(32, 32)
    tufts = ((13, 13), (20, 17), (15, 21)) + (((21, 12), (12, 18), (18, 22), (17, 14)) if bad else ())
    for x, y in ((14, 16), (19, 20)) + (((12, 12), (21, 15), (16, 19)) if bad else ()):
        c.rect(x, y, x + 2, y + 1, DARK, a=110)
        c.put(x + 1, y, DARK, a=160)
    if bad:
        for x0, y0 in ((11, 15), (19, 13), (14, 22)):
            for i, col in enumerate((WALNUT[3], WALNUT[1], WALNUT[0], WALNUT[1])):
                c.put(x0 + i, y0 + (i % 2), col)
            c.put(x0 + 4, y0 + 1, OXIDE[1])
    for x, y in tufts:
        c.put(x, y, GREEN[3])
        c.put(x, y - 1, GREEN[1])
        c.put(x - 1, y, GREEN[2])
        c.put(x + 1, y - 1, GREEN[0])
    return [c.image()]


def turntable_pit(size):
    """The pit of a turntable from above: a brick wall round a gravel floor
    that falls into shadow under the upper-left wall, with the ring rail the
    ends of the bridge run on."""
    im = Image.new('RGBA', (size, size))
    px = im.load()
    mid = (size - 1) / 2.0
    R = size / 2.0 - 1.0
    for y in range(size):
        for x in range(size):
            dx, dy = x - mid, y - mid
            d = math.hypot(dx, dy)
            if d > R:
                continue
            ang = math.atan2(dy, dx)
            if d > R - 1.0:
                col = DARK
            elif d > R - 5.0:
                # the coping: bricks laid round the rim
                course = int((ang + math.pi) * R / 6.0)
                tone = BRICK[(course * 5 + int(d)) % 2]
                edge = ((ang + math.pi) * R / 6.0) % 1.0 < 0.16
                col = BRICK[3] if edge else (BRICK[0] if d > R - 2.2 else tone)
            elif d > R - 6.0:
                col = DARK
            else:
                # the floor, darker where the wall shades it
                lit = (dx + dy) / (R * 1.42)
                depth = max(0.0, (d - (R - 20.0)) / 14.0) * max(0.0, -lit)
                tone = ROCK[2] if noise(x // 2, y // 2, 113) > 0.5 else ROCK[1]
                if noise(x, y, 127) > 0.9:
                    tone = ROCK[0]
                col = mix(mix(tone, ROCK[3], 0.35), DARK, min(0.6, 0.15 + depth * 0.5))
                ring = R - 11.0
                if abs(d - ring) < 1.3:
                    col = STEEL[1] if abs(d - ring) < 0.6 else STEEL[4]
                elif abs(d - ring) < 2.4 and int((ang + math.pi) * ring / 5.0) % 2 == 0:
                    col = WALNUT[3]
            px[x, y] = col + (255,)
    return [im]


def station_board():
    """A station name board: a long white board on two posts."""
    c = Canvas(32, 32)
    c.shade(3, 29, 29, 30, 60)
    for x in (5, 25):
        c.rect(x - 1, 14, x + 2, 29, WALNUT[3])
        c.rect(x, 14, x + 1, 28, WALNUT[1])
        c.rect(x, 14, x, 28, WALNUT[0])
    c.bevel(1, 5, 30, 15, CREAM[0], CREAM[1], CREAM[2], outline=DARK)
    c.frame(3, 7, 28, 13, BLACK[3])
    # a row of painted letters, too small to read
    for i, w in enumerate((2, 1, 2, 2, 1, 2, 1)):
        x = 6 + i * 3
        c.rect(x, 9, x + w - 1, 11, BLACK[4])
        if i % 2:
            c.put(x, 10, CREAM[0])
    return [c.image()]


def hand_lamp(shade):
    """A railway hand lamp: a tin body, a bull's-eye lens and a wire handle."""
    c = Canvas(32, 32)
    c.shade(9, 26, 23, 28, 60)
    c.ring(15.5, 8.0, 4.4, STEEL[3], width=1.0)
    c.clear(10, 9, 21, 14)
    c.bevel(12, 9, 19, 11, BLACK[0], BLACK[1], BLACK[3], outline=BLACK[4])
    c.bevel(10, 12, 21, 25, BLACK[0], BLACK[2], BLACK[3], outline=BLACK[4])
    c.rect(11, 25, 20, 26, BLACK[4])
    c.rect(14, 7, 17, 8, BLACK[2])
    lens = {'white': (WHITE, (255, 244, 190), (236, 200, 110), (150, 110, 40)),
            'red': ((255, 190, 170), RED[0], RED[1], RED[2]),
            'green': ((200, 255, 200), (112, 214, 96), (52, 160, 60), (26, 96, 36))}.get(shade, (GLASS[1], GLASS[2], GLASS[3], GLASS[3]))
    c.disc(15.5, 18.0, 4.2, list(lens), outline=DARK)
    if shade:
        c.ring(15.5, 18.0, 6.2, lens[1], width=0.8)
        c.put(14, 16, WHITE)
    return [c.image()]


def guard_journal():
    """The guard's journal: a black cloth-bound book with a pencil in its loop."""
    c = Canvas(32, 32)
    c.shade(8, 25, 25, 27, 60)
    c.bevel(8, 7, 23, 24, BLACK[1], BLACK[2], BLACK[3], outline=BLACK[4])
    c.rect(8, 7, 10, 24, BLACK[4])
    c.rect(21, 8, 22, 23, CREAM[1])
    c.rect(12, 10, 19, 13, BRASS[2])
    c.rect(13, 11, 18, 12, CREAM[0])
    c.rect(24, 9, 25, 21, YELLOW[1])
    c.put(24, 8, DARK)
    c.put(25, 8, DARK)
    c.rect(24, 21, 25, 22, RED[1])
    return [c.image()]


def coal_heap(c, cx, cy, r, seed):
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            d = math.hypot(x - cx, (y - cy) * 1.15) + noise(x, y, seed) * 2.2
            if d > r:
                continue
            n = noise(x // 2, y // 2, seed + 1)
            lit = (cx - x) + (cy - y)
            tone = COAL[0] if (n > 0.8 and lit > -2) else (COAL[1] if n > 0.45 else (COAL[2] if n > 0.15 else COAL[3]))
            c.put(x, y, tone)
            if d > r - 1.2:
                c.put(x, y, COAL[3])


def coal_stage(fill):
    """A coaling stage, 64 x 64 and centred on its tile: a timber deck on
    trestle legs with kerb boards, a heap of coal on it and a barrow run.
    fill 0 is swept bare, 1 has a small heap, 2 is piled high."""
    c = Canvas(64, 64)
    c.shade(12, 14, 57, 59, 70)
    # trestle legs at the corners, then the deck
    for x, y in ((7, 7), (52, 7), (7, 52), (52, 52)):
        c.bevel(x, y, x + 4, y + 4, WALNUT[1], WALNUT[2], WALNUT[3], outline=DARK)
    c.rect(8, 8, 55, 55, OLD_SEAM)
    planks(c, 9, 9, 54, 54, tones=OLD_PLANK, seam=OLD_SEAM, seed=61)
    # kerb boards round three sides; the south side is the barrow run
    for x0, y0, x1, y1 in ((8, 8, 55, 10), (8, 8, 10, 55), (53, 8, 55, 55)):
        c.bevel(x0, y0, x1, y1, WALNUT[0], WALNUT[1], WALNUT[2], outline=WALNUT[3])
    c.rect(11, 53, 52, 55, WALNUT[2])
    c.rect(11, 53, 52, 53, WALNUT[0])
    # coal dust ground into the boards
    c.speckle(11, 11, 52, 52, COAL[2], 0.10 if fill == 0 else 0.22, seed=62)
    if fill == 1:
        coal_heap(c, 30, 28, 10, 63)
    elif fill == 2:
        coal_heap(c, 31, 30, 19, 64)
        coal_heap(c, 28, 26, 9, 65)
    # a shovel left standing in the corner
    c.line(46, 49, 50, 40, WALNUT[3])
    c.line(45, 49, 49, 40, TAN[1])
    c.bevel(43, 48, 47, 52, STEEL[1], STEEL[2], STEEL[4], outline=STEEL_O)
    return [c.image()]


def bulk_pile(c, cx, cy, r, seed, ramp):
    """A heap of bulk in the four tones of ramp, lit from the upper left."""
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            d = math.hypot(x - cx, (y - cy) * 1.15) + noise(x, y, seed) * 2.2
            if d > r:
                continue
            n = noise(x // 2, y // 2, seed + 1)
            lit = (cx - x) + (cy - y)
            tone = ramp[0] if (n > 0.8 and lit > -2) else (ramp[1] if n > 0.45 else (ramp[2] if n > 0.15 else ramp[3]))
            c.put(x, y, ramp[3] if d > r - 1.2 else tone)


def loading_stage(tone):
    """A loading stage, 64 x 64 and centred on its tile: a timber deck on
    trestle legs with kerb boards, an iron chute over its north edge and a
    heap of coal, ore or sand. tone None is swept bare."""
    c = Canvas(64, 64)
    c.shade(12, 14, 57, 59, 70)
    for x, y in ((7, 9), (52, 9), (7, 52), (52, 52)):
        c.bevel(x, y, x + 4, y + 4, WALNUT[1], WALNUT[2], WALNUT[3], outline=DARK)
    c.rect(8, 10, 55, 55, OLD_SEAM)
    planks(c, 9, 11, 54, 54, tones=OLD_PLANK, seam=OLD_SEAM, seed=66)
    # kerb boards down both sides and along the back
    for x0, y0, x1, y1 in ((8, 10, 10, 55), (53, 10, 55, 55), (8, 53, 55, 55)):
        c.bevel(x0, y0, x1, y1, WALNUT[0], WALNUT[1], WALNUT[2], outline=WALNUT[3])
    # the front kerb, broken by the mouth of the chute
    for x0, x1 in ((8, 23), (40, 55)):
        c.bevel(x0, 10, x1, 12, WALNUT[0], WALNUT[1], WALNUT[2], outline=WALNUT[3])
    ramp = (HEAPS.get(tone) or SAND) if tone else None
    if ramp:
        c.speckle(11, 13, 52, 52, ramp[2], 0.2, seed=67)
        bulk_pile(c, 31, 33, 17, 68, ramp)
        bulk_pile(c, 29, 28, 8, 69, ramp)
    # the chute: a plate trough with raised sides, running out over the rails
    c.rect(23, 0, 40, 14, STEEL_O)
    c.bands(24, 0, 39, 13, [STEEL[1]] + [STEEL[3]] * 14 + [STEEL[4]], along=True)
    c.rect(24, 0, 25, 13, STEEL[1])
    c.rect(38, 0, 39, 13, STEEL[4])
    for y in (2, 7, 12):
        c.put(24, y, STEEL[0])
        c.put(39, y, STEEL[2])
    if ramp:
        for y in range(1, 14):
            for x in range(27, 37):
                if noise(x, y, 70) > 0.55:
                    c.put(x, y, ramp[1] if noise(x, y, 71) > 0.5 else ramp[3])
    return [c.image()]


def goods_crane(hauling):
    """A hand crane for a goods yard from above: an iron post on a bolted
    base, a winding drum with a crank handle either side, and a timber jib
    with an iron strap reaching north to its sheave and hook."""
    c = Canvas(32, 32)
    c.shade(9, 17, 25, 30, 60)
    c.disc(15.5, 21.5, 7.2, [STEEL[2], STEEL[3], STEEL[4]], outline=STEEL_O, flat=True)
    for x, y in ((11, 17), (20, 17), (11, 26), (20, 26)):
        c.put(x, y, STEEL[0])
    # the jib
    c.shade(15, 3, 19, 20, 50)
    c.bevel(13, 2, 18, 21, TAN[0], TAN[1], TAN[2], outline=DARK)
    for y in (6, 12, 18):
        c.rect(13, y, 18, y, STEEL[3])
    c.disc(15.5, 3.5, 2.4, [STEEL[0], STEEL[2], STEEL[4]], outline=STEEL_O)
    c.rect(15, 5, 16, 19, DARK)
    if hauling:
        c.rect(14, 0, 17, 2, RED[1])
        c.put(15, 1, RED[0])
    else:
        c.put(15, 1, STEEL[1])
        c.put(16, 1, STEEL[3])
        c.put(16, 0, STEEL[3])
    # the drum and its cranks
    c.bevel(10, 19, 21, 24, BLACK[0], BLACK[2], BLACK[4], outline=DARK)
    for y in (20, 22):
        c.rect(11, y, 20, y, BLACK[1])
    for x0, x1 in ((6, 9), (22, 25)):
        c.rect(x0, 21, x1, 22, STEEL_O)
        c.rect(x0, 21, x1, 21, STEEL[1])
    c.rect(5, 19 if hauling else 23, 6, 21 if hauling else 25, WALNUT[1])
    c.rect(25, 23 if hauling else 19, 26, 25 if hauling else 21, WALNUT[1])
    return [c.image()]


def livestock_ramp(c):
    """A livestock ramp whose head is to the north: cleated planks rising to
    the car door, with a post-and-rail fence down each side."""
    c.shade(5, 29, 28, 31, 70)
    c.rect(5, 0, 26, 31, OLD_SEAM)
    for y in range(32):
        rise = 1.0 - y / 31.0
        for x in range(6, 26):
            tone = OLD_PLANK[(x // 5 * 3 + 2) % len(OLD_PLANK)]
            col = OLD_SEAM if x % 5 == 0 else mix(tone, CREAM[1], 0.22 * rise)
            c.put(x, y, mix(col, DARK, 0.16) if noise(x, y // 2, 97) > 0.86 else col)
    for y in (3, 9, 15, 21, 27):
        c.rect(6, y, 25, y, WALNUT[0])
        c.rect(6, y + 1, 25, y + 1, WALNUT[3])
    for x0 in (2, 27):
        c.rect(x0, 0, x0 + 2, 31, DARK)
        c.rect(x0 + 1, 0, x0 + 1, 31, WALNUT[1])
        for y in (0, 10, 20, 29):
            c.bevel(x0, y, x0 + 2, y + 2, WALNUT[0], WALNUT[1], WALNUT[3], outline=DARK)


def sand_bin(full):
    """A sand bin, 64 x 64 and centred on its tile: a boarded bin with a tin
    lid hinged back over half of it, dry sand (or bare boards) in the open half."""
    c = Canvas(64, 64)
    c.shade(18, 20, 49, 51, 70)
    c.rect(15, 15, 48, 48, DARK)
    c.bevel(16, 16, 47, 47, WALNUT[0], WALNUT[1], WALNUT[2], outline=WALNUT[3])
    # the open half
    c.rect(19, 31, 44, 44, WALNUT[3])
    if full:
        c.rect(20, 32, 44, 44, SAND[1])
        c.speckle(20, 32, 44, 44, SAND[0], 0.30, seed=71)
        c.speckle(20, 32, 44, 44, SAND[2], 0.22, seed=72)
        c.rect(20, 32, 44, 32, SAND[3])
        c.rect(20, 32, 20, 44, SAND[3])
        # the scoop
        c.bevel(36, 36, 41, 40, STEEL[0], STEEL[1], STEEL[3], outline=STEEL_O)
        c.line(41, 41, 44, 44, WALNUT[3])
    else:
        planks(c, 20, 32, 44, 44, tones=OLD_PLANK, seam=OLD_SEAM, seed=73)
        c.shade(20, 32, 44, 44, 110)
        c.speckle(20, 40, 44, 44, SAND[2], 0.18, seed=74)
    # the lid over the other half: ribbed tin with two strap hinges
    c.bevel(17, 17, 46, 30, ROOF_TIN[0], ROOF_TIN[1], ROOF_TIN[3], outline=ROOF_TIN[4])
    for x in range(21, 45, 5):
        c.rect(x, 18, x, 29, ROOF_TIN[2])
    for x in (24, 38):
        c.rect(x, 28, x + 2, 32, STEEL_O)
        c.put(x + 1, 30, STEEL[1])
    return [c.image()]


ROCK = ((166, 140, 120), (128, 104, 90), (94, 76, 68), (58, 46, 42))
HEAPS = {'coal': COAL, 'ore': ROCK}


def heap(tone, fill):
    """A bulk load across one section of a car, 96 x 96 and centred on the
    section's tile (car heading north): a ridge down the middle of the car
    that runs on into the next section. fill 1 is a low ridge, 2 a full load."""
    ramp = HEAPS.get(tone) or SAND

    def draw(c):
        half = 39 if fill == 2 else 24
        for y in range(32, 64):
            for x in range(96):
                # ragged edge, the same on every section so the heaps join
                edge = half + (noise(x // 3, y % 32, 51) - 0.5) * 5 + 2 * math.sin((y % 32) / 32 * 2 * math.pi)
                d = abs(x - 47.5)
                if d > edge:
                    continue
                n = noise(x // 2, (y % 32) // 2, 52 + fill)
                # lit on the slope that faces the upper left, dark on the far one
                slope = (47.5 - x) / half
                lit = slope * 0.6 + (n - 0.5) * 1.1
                col = ramp[0] if lit > 0.55 else (ramp[1] if lit > 0.05 else (ramp[2] if lit > -0.45 else ramp[3]))
                if d > edge - 1.5:
                    col = ramp[3]
                elif d < 1.5 and n > 0.4:
                    col = ramp[0]
                c.put(x, y, col)
    return directions(draw, w=96, h=96, order=HEADING)


def tank_shell(part):
    """A tank car's tank across one section, 96 x 96 and centred on the
    section's tile (car heading north): a black riveted barrel 46 pixels wide
    standing over the rail tile and the inner edge of both running boards.
    part f and b are the dished ends, m a plain ring, d the ring under the
    filling dome."""
    def draw(c):
        x0, x1 = 25, 70
        y0, y1 = (36 if part == 'f' else 32), (59 if part == 'b' else 63)
        # the shadow the barrel throws on the running board
        c.shade(x1 + 1, y0 + 2, x1 + 3, y1, 70)
        for y in range(y0, y1 + 1):
            inset = 0
            depth = (y - y0) if part == 'f' else ((y1 - y) if part == 'b' else 99)
            if depth < 7:
                inset = int(round(9 * (1 - math.sqrt(1 - ((7 - depth) / 7.0) ** 2))))
            c.cyl(x0 + inset, y, x1 - inset, y, BLACK)
            if depth == 0:
                c.rect(x0 + inset, y, x1 - inset, y, BLACK[4])
            elif depth == 6:
                # the seam where the dished end is riveted to the barrel
                for x in range(x0 + 2, x1 - 1, 3):
                    c.put(x, y, BLACK[0] if x < 44 else BLACK[1])
        # the straps that hold the barrel to its cradles
        for y in ((52,) if part == 'f' else ((43,) if part == 'b' else (36, 59))):
            c.rect(x0, y, x1, y, STEEL_O)
            c.rect(x0 + 1, y, x1 - 1, y, STEEL[3])
            for x in (34, 38, 42):
                c.put(x, y, STEEL[1])
            c.put(x0 + 1, y + 1, STEEL_O)
            c.put(x1 - 1, y + 1, STEEL_O)
        # a ring of rivets round each plate joint
        if part in ('m', 'd'):
            for x in range(x0 + 2, x1 - 1, 3):
                c.put(x, 47 if part == 'm' else 33, BLACK[0] if x < 44 else (BLACK[1] if x < 58 else BLACK[3]))
        if part == 'd':
            # the filling dome, its hinged lid and the safety valve beside it
            c.shade(40, 41, 58, 58, 60)
            c.disc(47.5, 47.5, 9, [BLACK[0], BLACK[1], BLACK[2], BLACK[3], BLACK[4]], outline=DARK)
            c.disc(47.5, 47.5, 5.5, [STEEL[0], STEEL[1], STEEL[2], STEEL[3], STEEL[4]], outline=STEEL_O)
            c.rect(46, 41, 49, 42, STEEL_O)
            c.put(47, 47, STEEL[0])
            c.rect(47, 52, 48, 53, BRASS[1])
            c.disc(61.5, 47.5, 2.2, [BRASS[0], BRASS[1], BRASS[2], BRASS[3]], outline=BRASS[4])
        if part == 'm':
            # the ladder rungs up to the walkway along the top
            for y in range(38, 58, 4):
                c.rect(45, y, 50, y, STEEL[2])
                c.put(45, y, STEEL[0])
            c.rect(44, 37, 44, 57, STEEL_O)
            c.rect(51, 37, 51, 57, STEEL_O)
    return directions(draw, w=96, h=96, order=HEADING)


def tank_valve():
    """The valve on a tank car's end platform: a red hand wheel on the outlet
    pipe and a coil of hose beside it."""
    c = Canvas(32, 32)
    c.shade(5, 24, 27, 29, 60)
    # the outlet pipe and its flange
    c.cyl(13, 3, 18, 14, STEEL)
    c.bevel(11, 12, 20, 15, STEEL[1], STEEL[2], STEEL[4], outline=STEEL_O)
    # the hand wheel
    c.ring(15.5, 13.5, 7, RED[3], width=2.6)
    c.ring(15.5, 13.5, 7, RED[1], width=1.4)
    for dx, dy in ((1, 0), (0, 1), (-1, 0), (0, -1)):
        for k in range(1, 7):
            c.put(15.5 + dx * k, 13.5 + dy * k, RED[2])
    c.disc(15.5, 13.5, 2.0, [STEEL[0], STEEL[2], STEEL[4]], outline=STEEL_O)
    c.put(11, 9, RED[0])
    c.put(12, 8, RED[0])
    # the hose, coiled on the deck
    c.ring(16, 24, 5.5, DARK, width=2.6)
    c.ring(16, 24, 5.5, BLACK[1], width=1.2)
    c.ring(16, 24, 2.5, BLACK[2], width=1.2)
    c.rect(21, 22, 24, 23, BRASS[2])
    c.put(24, 22, BRASS[0])
    return [c.image()]


def cold_chest(kind, opened):
    """The fittings of an ice car, seen like the game's other furniture: the
    zinc-lined ice bunker and a white cold locker, each shut and with its lid
    stood up behind."""
    c = Canvas(32, 32)
    body = STEEL if kind == 'bunker' else CREAM
    edge = STEEL_O if kind == 'bunker' else CREAM[3]
    c.shade(3, 27, 29, 29, 60)
    if opened:
        # the lid stood up at the back, its lining out
        c.bevel(3, 2, 28, 9, body[1], body[2], body[3], outline=edge)
        c.rect(5, 4, 26, 7, STEEL[1] if kind == 'bunker' else CREAM[1])
        c.rect(5, 7, 26, 7, STEEL[3] if kind == 'bunker' else CREAM[2])
        # the well
        c.bevel(3, 10, 28, 27, body[0], body[1], body[3], outline=edge)
        c.rect(5, 11, 26, 19, DARK)
        if kind == 'bunker':
            # sawn blocks of ice, two courses
            for by, off in ((12, 0), (16, 3)):
                for bx in range(6 - off, 26, 7):
                    x0, x1 = max(bx, 6), min(bx + 5, 25)
                    c.rect(x0, by, x1, by + 2, ICE[1])
                    c.rect(x0, by, x1 - 1, by, ICE[0])
                    c.rect(x0 + 1, by + 2, x1, by + 2, ICE[2])
            c.rect(5, 11, 26, 11, ICE[3])
        else:
            # two wire shelves in the cold dark
            for y in (13, 17):
                c.rect(6, y, 25, y, STEEL[3])
                for x in range(7, 25, 3):
                    c.put(x, y, STEEL[1])
            c.rect(5, 11, 26, 11, CREAM[3])
    else:
        # the lid, with its rim and the front of the box under it
        c.bevel(3, 6, 28, 16, body[0], body[1], body[2], outline=edge)
        c.bevel(3, 16, 28, 27, body[1], body[2], body[3], outline=edge)
        c.rect(4, 15, 27, 15, body[3])
        if kind == 'bunker':
            # the lifting ring and the rivets round the lid
            c.ring(15.5, 11, 3.2, STEEL_O, width=1.3)
            c.put(14, 9, STEEL[0])
            for x in range(6, 27, 4):
                c.put(x, 7, STEEL[0])
                c.put(x, 25, STEEL[3])
            # a block of ice painted on the front
            c.rect(12, 19, 19, 23, ICE[3])
            c.rect(13, 20, 18, 22, ICE[1])
            c.put(13, 20, ICE[0])
        else:
            # strap hinges, the lever latch and a blue band
            for x in (8, 23):
                c.rect(x, 6, x, 10, STEEL[3])
                c.put(x, 7, STEEL[0])
            c.rect(4, 21, 27, 22, ICE[2])
            c.rect(4, 21, 27, 21, ICE[1])
            c.rect(14, 15, 17, 18, STEEL_O)
            c.rect(15, 16, 16, 17, STEEL[0])
    return [c.image()]


def rail_crane(hauling):
    """The rail crane, 96 x 96 and centred on its tile (car heading north):
    a green engine house on a turntable with its counterweight ahead and a
    lattice jib reaching back over the next section of the car. Hauling, the
    chimney steams and a sling hangs taut from the hook."""
    def draw(c):
        # the turntable and its roller path
        c.shade(34, 36, 64, 64, 60)
        c.disc(47.5, 47.5, 15, [STEEL[2], STEEL[3], STEEL[4]], outline=STEEL_O, flat=True)
        c.ring(47.5, 47.5, 12, STEEL[1], 150)
        # the counterweight ahead of the house
        c.bevel(37, 27, 58, 34, BLACK[0], BLACK[2], BLACK[4], outline=DARK)
        for x in (41, 47, 53):
            c.put(x, 30, BLACK[0])
        # the jib: two lattice booms, cross braces and the hoist rope
        c.shade(45, 60, 54, 94, 50)
        for y in range(56, 93):
            c.put(43, y, STEEL_O)
            c.put(44, y, YELLOW[0] if y % 8 < 4 else YELLOW[1])
            c.put(50, y, YELLOW[1] if y % 8 < 4 else YELLOW[2])
            c.put(51, y, STEEL_O)
            k = (y - 56) % 12
            x = 45 + (k if k < 6 else 11 - k)
            c.put(min(x, 49), y, YELLOW[2])
        c.rect(47, 52, 47, 91, DARK)
        # the jib head, its sheave and the hook block
        c.bevel(42, 89, 52, 94, YELLOW[0], YELLOW[1], YELLOW[3], outline=STEEL_O)
        c.disc(47.5, 91.5, 2.2, [STEEL[0], STEEL[2], STEEL[4]], outline=STEEL_O)
        if hauling:
            c.rect(46, 84, 48, 88, RED[1])
            c.put(47, 86, RED[0])
            c.line(44, 80, 47, 84, DARK)
            c.line(50, 80, 47, 84, DARK)
        # the engine house: boiler end with the chimney, cab window, roof seam
        c.bevel(36, 35, 59, 57, GREEN[0], GREEN[1], GREEN[3], outline=GREEN[4])
        c.rect(38, 46, 57, 46, GREEN[2])
        c.rect(38, 47, 57, 47, GREEN[0])
        for x in (39, 56):
            c.rivet(x, 37, GREEN[0], GREEN[4])
            c.rivet(x, 55, GREEN[0], GREEN[4])
        c.rect(40, 51, 47, 54, GLASS[3])
        c.rect(41, 52, 46, 53, GLASS[1])
        c.put(41, 52, WHITE)
        c.disc(52.5, 40.5, 3.4, [BLACK[0], BLACK[2], BLACK[4]], outline=DARK)
        c.disc(52.5, 40.5, 1.4, [DARK, DARK], flat=True)
        c.disc(42.5, 40.5, 2.2, [BRASS[0], BRASS[1], BRASS[3]], outline=BRASS[4])
        if hauling:
            for cx, cy, r, a in ((55, 37, 3.2, 170), (59, 33, 4.0, 130), (64, 28, 4.6, 90)):
                for yy in range(int(cy - r), int(cy + r) + 1):
                    for xx in range(int(cx - r), int(cx + r) + 1):
                        if math.hypot(xx - cx, yy - cy) <= r:
                            c.put(xx, yy, WHITE, a)
    return directions(draw, w=96, h=96, order=HEADING)


def load_states():
    out = {}
    out['rail_crane'] = rail_crane(False)
    out['rail_crane_haul'] = rail_crane(True)
    for part in 'fmdb':
        out['tank_' + part] = tank_shell(part)
    for tone in ('coal', 'ore', 'sand'):
        for fill in (1, 2):
            out['heap_%s_%d' % (tone, fill)] = heap(tone, fill)
    return out


def drop_pit(tone):
    """A drop pit between the rails of a track running north (train_freight.dm):
    a timber-lined bin under a grating of iron bars. tone None is empty."""
    def draw(c):
        c.rect(9, 0, 22, 31, WALNUT[3])
        c.rect(9, 0, 10, 31, WALNUT[1])
        c.rect(21, 0, 22, 31, WALNUT[2])
        c.rect(11, 0, 20, 31, DARK)
        if tone:
            ramp = HEAPS.get(tone) or SAND
            for y in range(32):
                for x in range(11, 21):
                    n = noise(x // 2, y // 2, 81)
                    c.put(x, y, ramp[1] if n > 0.55 else (ramp[2] if n > 0.2 else ramp[3]))
                    if n > 0.88:
                        c.put(x, y, ramp[0])
        else:
            c.speckle(11, 0, 20, 31, WALNUT[3], 0.2, seed=82)
        # the grating
        for y in range(1, 32, 4):
            c.rect(9, y, 22, y, STEEL_O)
            c.rect(10, y, 21, y, STEEL[3] if tone else STEEL[2])
        for y in (0, 31):
            c.rect(9, y, 22, y, STEEL_O)
    return directions(draw, order=HEADING)


def coupling_item():
    """A spare coupling on the ground: draw hook, screw and links."""
    c = Canvas(32, 32)
    c.shade(4, 21, 29, 23, 60)
    c.bevel(3, 14, 12, 18, STEEL[1], STEEL[2], STEEL[4], outline=STEEL_O)
    c.ring(15.0, 16.0, 4.2, STEEL_O, width=3.4)
    c.ring(15.0, 16.0, 4.0, STEEL[1], width=1.6)
    c.clear(11, 10, 14, 12)
    for x in (22.0, 27.0):
        c.ring(x, 16.0, 3.4, STEEL_O, width=2.6)
        c.ring(x, 16.0, 3.2, STEEL[0], width=1.0)
    c.rect(23, 15, 26, 17, BRASS[3])
    c.rect(23, 15, 26, 16, BRASS[1])
    c.put(23, 15, BRASS[0])
    return [c.image()]


def fusible_plug():
    """The boiler's safety plug: a bronze hexagon head on a threaded shank,
    with the grey lead core showing in its middle."""
    c = Canvas(32, 32)
    c.shade(10, 22, 22, 24, 60)
    # threaded shank
    c.bevel(13, 14, 18, 22, BRASS[1], BRASS[2], BRASS[4], outline=DARK)
    for y in (16, 18, 20):
        c.rect(14, y, 17, y, BRASS[4])
    # hexagon head
    c.rect(11, 9, 20, 14, DARK)
    c.rect(12, 8, 19, 15, DARK)
    c.rect(12, 9, 19, 14, BRASS[2])
    c.rect(12, 9, 19, 10, BRASS[0])
    c.rect(12, 14, 19, 14, BRASS[3])
    c.rect(11, 10, 11, 13, BRASS[3])
    c.rect(20, 10, 20, 13, BRASS[4])
    # lead core
    c.rect(14, 11, 17, 13, STEEL[3])
    c.rect(14, 11, 16, 11, STEEL[0])
    c.put(17, 13, STEEL[4])
    return [c.image()]


def outrigger(c):
    """A lowered outrigger on the ground beside a braced gun car (car to the east)."""
    c.shade(7, 13, 17, 24, 60)
    c.shade(15, 18, 31, 19, 60)
    c.bevel(13, 13, 31, 17, STEEL[1], STEEL[2], STEEL[4], outline=STEEL_O)
    for x in (18, 23, 28):
        c.rect(x, 14, x + 1, 16, YELLOW[1])
    c.bevel(4, 9, 15, 21, STEEL[1], STEEL[3], STEEL[4], outline=STEEL_O)
    for x, y in ((6, 11), (13, 11), (6, 19), (13, 19)):
        c.rivet(x, y, STEEL[0], STEEL_O)
    c.disc(9.5, 15.0, 2.6, [STEEL[0], STEEL[1], STEEL[3]], outline=STEEL_O)
    c.put(9, 15, DARK)


def lever(down):
    c = Canvas(32, 32)
    c.shade(8, 28, 25, 30, 60)
    c.bevel(8, 23, 23, 28, STEEL[1], STEEL[2], STEEL[4], outline=STEEL_O)
    for x in (10, 21):
        c.rivet(x, 25, STEEL[0], STEEL_O)
    # the notched quadrant
    for i in range(13):
        a = math.radians(205 + i * 10.8)
        x, y = 15.5 + math.cos(a) * 9, 23 + math.sin(a) * 9
        c.put(round(x), round(y), STEEL[4] if i % 3 else STEEL[1])
    tip = (8, 10) if down else (23, 10)
    knob = ((112, 214, 96), (52, 160, 60), (26, 96, 36)) if down else ((240, 110, 90), (204, 44, 36), (124, 20, 20))
    for off, col in ((0, STEEL[1]), (1, STEEL[4])):
        c.line(15 + off, 23, tip[0] + off, tip[1], col)
    c.rect(14, 21, 17, 23, STEEL_O)
    c.put(15, 22, STEEL[0])
    c.disc(tip[0] + 0.5, tip[1] - 0.5, 3.0, list(knob), outline=mix(knob[2], DARK, 0.5))
    c.put(tip[0], tip[1] - 2, WHITE, 200)
    return [c.image()]


def brake_wheel(on):
    """A handbrake seen from above: a spoked hand wheel on a column over a
    bolted floor plate (train_brakes.dm). Wound on, the pawl is dropped into
    the ratchet and its tell-tale shows red; off, it stands clear in green."""
    c = Canvas(32, 32)
    c.shade(7, 25, 26, 28, 60)
    # floor plate
    c.bevel(8, 19, 24, 26, STEEL[1], STEEL[3], STEEL[4], outline=STEEL_O)
    for x, y in ((10, 21), (22, 21), (10, 24), (22, 24)):
        c.rivet(x, y, STEEL[0], STEEL_O)
    # the wheel's shadow on the plate, then the column under its hub
    c.shade(9, 17, 23, 20, 70)
    c.bevel(14, 14, 18, 21, STEEL[1], STEEL[2], STEEL[4], outline=STEEL_O)
    # rim: dark iron with a worn bright edge
    c.ring(16.0, 13.0, 9.2, STEEL_O, width=3.6)
    c.ring(16.0, 13.0, 9.0, STEEL[3], width=2.0)
    c.ring(16.0, 12.6, 9.4, STEEL[0], a=150, width=0.8)
    # four spokes, turned an eighth when the brake is on
    turn = math.pi / 4 if on else 0.0
    for i in range(4):
        a = turn + i * math.pi / 2
        x, y = 16.0 + math.cos(a) * 8.0, 13.0 + math.sin(a) * 8.0
        c.line(16, 13, round(x), round(y), STEEL_O)
        c.line(16, 12, round(x), round(y) - 1, STEEL[1])
    # brass hub and its nut
    c.disc(16.0, 13.0, 2.8, [BRASS[0], BRASS[1], BRASS[3]], outline=DARK)
    c.put(16, 13, BRASS[4])
    # ratchet pawl and tell-tale on the plate
    tell = RED if on else ((112, 214, 96), (52, 160, 60), (26, 96, 36), (12, 44, 16))
    c.rect(19, 22, 23, 25, STEEL_O)
    c.rect(20, 23, 22, 24, tell[1])
    c.put(20, 23, tell[0])
    c.put(22, 24, tell[2])
    if on:
        c.line(18, 20, 21, 22, STEEL[0])
    else:
        c.line(22, 19, 23, 21, STEEL[1])
    return [c.image()]


def car_kit():
    c = Canvas(32, 32)
    c.shade(2, 28, 29, 30, 70)
    # pallet
    for x in (3, 14, 25):
        c.bevel(x, 26, x + 3, 28, OLD_PLANK[0], OLD_PLANK[2], OLD_SEAM, outline=DARK)
    c.bevel(2, 24, 29, 26, OLD_PLANK[0], OLD_PLANK[1], OLD_PLANK[4], outline=DARK)
    # the deck boards, strapped
    for i, y in enumerate((20, 16, 12)):
        base = PLANK[1 + i % 3]
        c.bevel(3 + i, y, 28 - i, y + 4, PLANK[0], base, PLANK[4], outline=PLANK_SEAM)
        for x in range(5 + i, 27 - i):
            if noise(x // 3, y, 5) < 0.2:
                c.put(x, y + 2, mix(base, PLANK_SEAM, 0.4))
    for x in (8, 22):
        c.rect(x, 12, x + 1, 24, STEEL[4])
        c.rect(x, 12, x, 24, STEEL[1])
    # a wheelset on top
    c.rect(8, 6, 23, 8, STEEL_O)
    c.rect(8, 7, 23, 7, STEEL[1])
    for x in (4, 20):
        c.rect(x + 1, 1, x + 6, 12, STEEL_O)
        c.rect(x, 3, x + 7, 10, STEEL_O)
        c.rect(x + 1, 3, x + 6, 10, STEEL[3])
        c.rect(x + 2, 2, x + 5, 11, STEEL[3])
        c.rect(x + 2, 3, x + 2, 9, STEEL[0])
        c.rect(x + 3, 5, x + 4, 8, STEEL[4])
        c.put(x + 3, 6, STEEL[1])
    return [c.image()]


def wreck():
    c = Canvas(32, 32)
    for y in range(32):
        for x in range(32):
            v = (noise(x // 5, y // 5, 61) * 0.6 + noise(x // 2, y // 2, 62) * 0.4)
            d = math.hypot(x - 15.5, y - 15.5) / 22.0
            a = int(max(0, (v - 0.25 - d * 0.35)) * 420)
            if a > 20:
                c.put(x, y, (16, 14, 12), min(a, 200))
    for pts in (((3, 6), (9, 11), (8, 17), (15, 21), (14, 28)), ((28, 3), (22, 9), (24, 15), (18, 18)),
                ((9, 11), (16, 9), (21, 12)), ((15, 21), (23, 24), (29, 22))):
        for a, b in zip(pts, pts[1:]):
            c.line(a[0], a[1], b[0], b[1], (8, 8, 8))
            c.line(a[0] + 1, a[1] + 1, b[0] + 1, b[1] + 1, (150, 146, 136), 90)
    # torn, curled plate
    for (x0, y0, x1, y1) in ((5, 20, 11, 24), (19, 5, 25, 8), (20, 25, 26, 28)):
        c.bevel(x0, y0, x1, y1, STEEL[1], STEEL[3], STEEL[4], outline=DARK)
        c.put(x0 + 1, y0 + 1, STEEL[0])
        c.put(x1, y0, DARK, 0)
    c.clear(11, 20, 11, 20)
    c.clear(19, 8, 19, 8)
    for i in range(26):
        x, y = int(noise(i, 1, 63) * 30) + 1, int(noise(i, 2, 63) * 30) + 1
        c.put(x, y, (40, 36, 30) if i % 3 else (120, 112, 100))
    return [c.image()]


def derailed():
    """Laid over the deck of a car that is off the rails: it leans, and its
    boards have sprung."""
    c = Canvas(32, 32)
    # the deck leans away from the light: darker towards the low side
    for y in range(32):
        for x in range(32):
            a = int(max(0, x + (y - 16) * 0.35 - 6) * 5.2)
            if a > 0:
                c.put(x, y, (10, 8, 6), min(a, 130))
    c.rect(0, 0, 1, 31, (255, 244, 214), 70)
    # sprung boards: lifted ends catch the light and throw a shadow
    for x0, y0, n in ((5, 6, 9), (15, 13, 11), (8, 22, 8), (20, 27, 7)):
        c.line(x0, y0, x0 + n, y0 - 2, PLANK[0])
        c.line(x0, y0 + 1, x0 + n, y0 - 1, PLANK_SEAM)
        c.line(x0 + 1, y0 + 2, x0 + n, y0, (10, 8, 6), 120)
        c.put(x0 + n, y0 - 2, WHITE, 180)
    # ballast thrown up onto the deck
    for i in range(14):
        x, y = int(noise(i, 1, 77) * 28) + 2, int(noise(i, 2, 77) * 28) + 2
        c.put(x, y, (ASH[0], ASH[1], ASH[2])[i % 3])
        c.put(x + 1, y + 1, ASH[3], 200)
    return [c.image()]


def rerail_jack():
    """A screw jack: a foot plate, a tapered body, the screw and a ratchet bar."""
    c = Canvas(32, 32)
    c.shade(7, 27, 26, 29, 60)
    c.bevel(8, 24, 23, 27, STEEL[1], STEEL[2], STEEL[4], outline=STEEL_O)
    for y in range(12, 24):
        half = 3 + (y - 12) // 3
        c.rect(15 - half, y, 16 + half, y, STEEL_O)
        c.rect(16 - half, y, 15 + half, y, RED[1])
        c.put(16 - half, y, RED[0])
        c.put(15 + half, y, RED[2])
    c.rect(14, 5, 17, 12, STEEL_O)
    c.rect(15, 5, 16, 11, STEEL[1])
    for y in (6, 8, 10):
        c.rect(15, y, 16, y, STEEL[4])
    c.bevel(11, 2, 20, 5, STEEL[0], STEEL[2], STEEL[4], outline=STEEL_O)
    c.line(17, 14, 27, 9, STEEL_O)
    c.line(17, 13, 27, 8, STEEL[1])
    c.disc(27.5, 8.0, 1.6, [WALNUT[0], WALNUT[1]], outline=WALNUT[3])
    c.rect(14, 13, 17, 15, BRASS[2])
    c.put(14, 13, BRASS[0])
    return [c.image()]


def loco_armor(c):
    """Plate bolted over the old one-tile steam engine."""
    for x0 in (0, 27):
        c.rect(x0, 0, x0 + 4, 31, OLIVE[3])
        c.bands(x0 + 1, 1, x0 + 3, 30, [OLIVE[0], OLIVE[1], OLIVE[2]], along=True)
        for y in (3, 9, 15, 21, 27):
            c.rivet(x0 + 2, y, mix(OLIVE[0], WHITE, 0.25), OLIVE[3])
    c.rect(4, 12, 27, 19, OLIVE[3])
    c.bands(5, 13, 26, 18, [OLIVE[0], OLIVE[1], OLIVE[1], OLIVE[1], OLIVE[2], OLIVE[2]], along=False)
    for x in (8, 15, 23):
        c.rivet(x, 14, mix(OLIVE[0], WHITE, 0.25), OLIVE[3])
    c.rect(12, 16, 19, 17, (12, 14, 10))


# ---------------------------------------------------------------------------
# Roofs: three tiles wide; the front, middle and back rows of a car

def across(profile, n=96):
    return [ramp_at(profile, i / (n - 1)) for i in range(n)]


def walkway(c, x0, x1, y0, y1, tones=OLD_PLANK, seam=OLD_SEAM):
    c.shade(x1 + 2, y0, x1 + 2, y1, 60)
    c.rect(x0 - 1, y0, x1 + 1, y1, DARK)
    planks(c, x0, y0, x1, y1, tones=tones, seam=seam, seed=9)
    for y in range(y0 + 7, y1, 16):
        c.rect(x0 - 1, y, x0 - 1, y + 1, STEEL[2])
        c.rect(x1 + 1, y, x1 + 1, y + 1, STEEL[2])


def roof_coach(c):
    prof = [(74, 78, 84), (132, 136, 138), (188, 190, 184), (214, 214, 204), (190, 190, 182),
            (160, 162, 158), (128, 130, 130), (94, 98, 102), (62, 66, 72)]
    c.bands(0, 0, 95, 95, across(prof), along=True)
    for y in range(96):
        for x in range(96):
            if noise(x, y, 71) < 0.07:
                c.put(x, y, (40, 40, 44), 28)
    # the rounded ends
    for i, a in enumerate((150, 100, 60, 30, 12)):
        c.shade(0, i, 95, i, a)
        c.shade(0, 95 - i, 95, 95 - i, a)
    # canvas seams, gutters, cornice in the body colour
    for y in (31, 63):
        c.shade(0, y, 95, y, 50)
        c.rect(0, y + 1, 95, y + 1, WHITE, 26)
    for x in (0, 95):
        c.rect(x, 0, x, 95, MAROON[3])
    for x in (1, 94):
        c.rect(x, 0, x, 95, MAROON[2])
    c.rect(2, 0, 2, 95, (236, 236, 226), 110)
    c.rect(93, 0, 93, 95, (30, 32, 36), 110)
    c.rect(0, 0, 95, 0, MAROON[3])
    c.rect(0, 95, 95, 95, MAROON[3])
    # ventilators
    for y in (16, 48, 80):
        for x in (20, 71):
            c.shade(x + 1, y - 2, x + 6, y + 5, 60)
            c.bevel(x, y - 4, x + 4, y + 3, (236, 236, 228), (176, 178, 176), (104, 108, 112), outline=(44, 46, 52))
            c.rect(x + 2, y - 2, x + 2, y + 1, (60, 62, 68))
    walkway(c, 42, 53, 4, 91)
    for (x, y) in ((0, 0), (1, 0), (0, 1), (2, 0), (0, 2), (95, 0), (94, 0), (95, 1), (93, 0), (95, 2),
                   (0, 95), (1, 95), (0, 94), (2, 95), (0, 93), (95, 95), (94, 95), (95, 94), (93, 95), (95, 93)):
        c.clear(x, y, x, y)
    for (x, y) in ((1, 1), (94, 1), (1, 94), (94, 94)):
        c.put(x, y, MAROON[3])


def roof_steel(c):
    prof = [(52, 56, 64), (104, 110, 120), (150, 156, 166), (168, 174, 182), (146, 152, 162),
            (122, 128, 138), (100, 106, 116), (78, 84, 94), (50, 54, 62)]
    c.bands(0, 0, 95, 95, across(prof), along=True)
    for y in range(96):
        # pressed ribs
        if y % 8 == 3:
            c.rect(2, y, 93, y, WHITE, 56)
        elif y % 8 == 4:
            c.shade(2, y, 93, y, 70)
        for x in range(96):
            n = noise(x, y, 81)
            if n < 0.05:
                c.put(x, y, (120, 74, 44), 46)
            elif n > 0.96:
                c.put(x, y, (20, 22, 26), 40)
    for y in (31, 63):
        c.shade(0, y, 95, y, 90)
    c.frame(0, 0, 95, 95, STEEL_O)
    for y in (1, 94):
        c.rect(1, y, 94, y, STEEL[4])
    for x in (1, 94):
        c.rect(x, 0, x, 95, STEEL[4])
    for y in range(4, 96, 8):
        c.rivet(3, y, STEEL[0], STEEL_O)
        c.rivet(92, y, STEEL[0], STEEL_O)
    walkway(c, 42, 53, 2, 93)
    # the ladder head at the back corner
    for y in (84, 87, 90):
        c.rect(5, y, 12, y, STEEL[0])
        c.shade(5, y + 1, 12, y + 1, 70)
    c.rect(4, 82, 4, 92, STEEL_O)
    c.rect(13, 82, 13, 92, STEEL_O)


def camo(c, x0, y0, x1, y1, seed=91):
    """Darker blotches over olive plate only."""
    olives = set(OLIVE[:3])

    def field(x, y):
        gx, gy = x / 9.0, y / 8.0
        ix, iy = int(gx), int(gy)
        fx, fy = gx - ix, gy - iy
        a = noise(ix, iy, seed) * (1 - fx) + noise(ix + 1, iy, seed) * fx
        b = noise(ix, iy + 1, seed) * (1 - fx) + noise(ix + 1, iy + 1, seed) * fx
        return a * (1 - fy) + b * fy

    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            X, Y = c.wpt(x, y)
            p = c.px.get((X, Y))
            if p and p[:3] in olives and field(x, y) > 0.56:
                c.wput(X, Y, mix(p[:3], (52, 66, 46), 0.5))


def plate_roof(c, x0, y0, x1, y1, chamfer=4):
    n = x1 - x0 + 1
    cols = [OLIVE[3]] + [OLIVE[0]] * chamfer + [OLIVE[1]] * (n - 2 - chamfer * 2) + [OLIVE[2]] * chamfer + [OLIVE[3]]
    c.bands(x0, y0, x1, y1, cols, along=True)


def hatch(c, x0, y0, x1, y1, ramp=OLIVE, handle=True):
    c.shade(x0 + 1, y1 + 1, x1 + 1, y1 + 1, 70)
    c.shade(x1 + 1, y0 + 1, x1 + 1, y1 + 1, 70)
    c.bevel(x0, y0, x1, y1, mix(ramp[0], WHITE, 0.2), ramp[1], ramp[2], outline=ramp[3])
    for (x, y) in ((x0 + 2, y0 + 2), (x1 - 2, y0 + 2), (x0 + 2, y1 - 2), (x1 - 2, y1 - 2)):
        c.rivet(x, y, mix(ramp[0], WHITE, 0.3), ramp[3])
    c.rect(x0 + 3, y0 - 1, x0 + 4, y0, STEEL[4])
    c.rect(x1 - 4, y0 - 1, x1 - 3, y0, STEEL[4])
    if handle:
        mx, my = (x0 + x1) // 2, (y0 + y1) // 2
        c.rect(mx - 1, my, mx + 2, my, STEEL[0])
        c.rect(mx - 1, my + 1, mx + 2, my + 1, ramp[3])


def roof_armor(c):
    plate_roof(c, 0, 0, 95, 95, chamfer=5)
    for y in (0, 95):
        c.rect(0, y, 95, y, OLIVE[3])
    for y in (1,):
        c.rect(1, y, 94, y, mix(OLIVE[0], WHITE, 0.15))
    c.rect(1, 94, 94, 94, OLIVE_D)
    for y in (15, 31, 47, 63, 79):
        c.rect(1, y, 94, y, OLIVE_D)
        c.rect(1, y + 1, 94, y + 1, mix(OLIVE[1], OLIVE[0], 0.5), 150)
        for x in range(8, 96, 10):
            c.rivet(x, y - 2, mix(OLIVE[0], WHITE, 0.25), OLIVE[3])
    # non-slip walkway
    c.rect(41, 2, 54, 93, OLIVE_D)
    tread(c, 42, 2, 53, 93, face=OLIVE[2], lit=OLIVE[0], dark=OLIVE_D, seams=False)
    for y in (16, 48, 80):
        hatch(c, 12, y - 6, 25, y + 6)
        hatch(c, 70, y - 6, 83, y + 6)
    camo(c, 0, 0, 95, 95)


BOXCAR_ROOF = [(58, 24, 22), (122, 52, 40), (166, 78, 54), (184, 92, 62), (164, 76, 52),
               (140, 60, 44), (114, 46, 38), (86, 34, 30), (52, 20, 20)]
STOCK_ROOF = [(40, 28, 22), (92, 66, 48), (128, 96, 68), (146, 112, 80), (126, 94, 66),
              (106, 78, 56), (86, 62, 46), (64, 46, 36), (38, 26, 20)]
REEFER_ROOF = [(96, 94, 88), (188, 186, 174), (226, 224, 210), (244, 242, 230), (224, 222, 208),
               (200, 198, 184), (172, 170, 158), (140, 138, 128), (88, 86, 80)]


def roof_boxcar(c, prof=BOXCAR_ROOF, trim=OXIDE):
    """A boxcar's sheeted roof in freight oxide: seams across, a running
    board down the middle, grab irons at the front and the brake wheel aft."""
    c.bands(0, 0, 95, 95, across(prof), along=True)
    for y in range(96):
        # sheet seams, the same in every row so a long roof repeats cleanly
        if y % 16 == 7:
            c.rect(2, y, 93, y, WHITE, 44)
        elif y % 16 == 8:
            c.shade(2, y, 93, y, 84)
        for x in range(96):
            n = noise(x, y, 83)
            if n < 0.06:
                c.put(x, y, (26, 20, 20), 40)
            elif n > 0.965:
                c.put(x, y, (226, 150, 110), 34)
    for y in (31, 63):
        c.shade(0, y, 95, y, 60)
    c.frame(0, 0, 95, 95, trim[3])
    for x in (1, 94):
        c.rect(x, 1, x, 94, trim[2])
    c.rect(2, 1, 2, 94, mix(trim[0], WHITE, 0.3), 120)
    for y in (1, 94):
        c.rect(1, y, 94, y, trim[2])
    walkway(c, 42, 53, 2, 93)
    # grab irons at the front corner, by the ladder
    for y in (5, 9):
        c.rect(82, y, 90, y, STEEL[0])
        c.shade(82, y + 1, 90, y + 1, 70)
    c.rect(81, 4, 81, 11, STEEL_O)
    c.rect(91, 4, 91, 11, STEEL_O)
    # the brake wheel on its staff at the back
    c.shade(13, 83, 23, 93, 50)
    c.ring(17, 86, 5.2, STEEL_O)
    c.ring(17, 86, 4.2, STEEL[1])
    c.line(13, 86, 21, 86, STEEL[3])
    c.line(17, 82, 17, 90, STEEL[3])
    c.disc(17, 86, 1.6, [STEEL[0], STEEL[2], STEEL[4]], outline=STEEL_O)


def roof_stock(c):
    """A stock car's roof: weathered boards and a louvred ventilator either
    side of the running board in every section."""
    roof_boxcar(c, STOCK_ROOF, WALNUT)
    for y0 in (10, 42, 74):
        for x0 in (16, 66):
            c.shade(x0 + 1, y0 + 1, x0 + 14, y0 + 13, 60)
            c.bevel(x0, y0, x0 + 13, y0 + 12, WALNUT[0], WALNUT[1], WALNUT[2], outline=WALNUT[3])
            for y in range(y0 + 2, y0 + 11, 3):
                c.rect(x0 + 2, y, x0 + 11, y, DARK)
                c.rect(x0 + 2, y + 1, x0 + 11, y + 1, WALNUT[0])


def roof_reefer(c):
    """An ice car's white roof, with the two icing hatches over the bunker at
    its front end."""
    roof_boxcar(c, REEFER_ROOF, CREAM)
    for x0 in (8, 62):
        c.shade(x0 + 1, 5, x0 + 26, 27, 60)
        c.bevel(x0, 4, x0 + 24, 25, CREAM[0], CREAM[1], CREAM[2], outline=CREAM[3])
        c.rect(x0 + 3, 7, x0 + 21, 7, CREAM[2])
        # strap hinges at the back, the lifting handle at the front
        for x in (x0 + 5, x0 + 19):
            c.rect(x, 20, x, 26, STEEL[3])
            c.put(x, 21, STEEL[0])
        c.rect(x0 + 9, 9, x0 + 15, 9, STEEL_O)
        c.rect(x0 + 10, 10, x0 + 14, 10, STEEL[1])


ROOFS = {'coach': roof_coach, 'steel': roof_steel, 'armor': roof_armor, 'boxcar': roof_boxcar,
         'stock': roof_stock, 'reefer': roof_reefer}


def roof_states():
    out = {}
    for kind, draw in ROOFS.items():
        imgs = directions(draw, w=96, h=96, order=HEADING)
        for seg, row in enumerate('fmb'):
            for col, name in ((-1, 'l'), (0, 'c'), (1, 'r')):
                out['roof_%s_%s%s' % (kind, row, name)] = slice_car(imgs, 3, seg, col)
    return out


# ---------------------------------------------------------------------------
# Locomotives: 96 x 128, heading north

def wheel(c, x, y0, y1, outer_left):
    c.rect(x, y0, x + 2, y1, DARK)
    c.rect(x + (0 if outer_left else 2), y0 + 1, x + (0 if outer_left else 2), y1 - 1, STEEL[3])
    c.put(x + 1, (y0 + y1) // 2, STEEL[1])


def beam(c, y0, y1, ramp=RED, hazard=False):
    c.bevel(8, y0, 87, y1, ramp[0], ramp[1], ramp[2], outline=ramp[3])
    if hazard:
        for y in range(y0 + 1, y1):
            for x in range(9, 87):
                if ((x + y) // 3) % 2 == 0:
                    c.put(x, y, (26, 26, 30))
    cy = y0 + 0.5 if y0 == 0 else y1 - 0.5
    buffer(c, 23.5, cy)
    buffer(c, 71.5, cy)
    c.rect(44, y0, 51, y1, STEEL_O)
    c.rect(45, y0 if y0 == 0 else y0 + 1, 50, y1 - 1 if y0 == 0 else y1, STEEL[3])
    c.rect(47, y0 + 1, 48, y1 - 1, DARK)


def coal(c, x0, y0, x1, y1, seed=101):
    c.rect(x0, y0, x1, y1, COAL[2])
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            n = noise(x // 2, y // 2, seed)
            m = noise(x, y, seed + 1)
            col = COAL[1] if n > 0.45 else COAL[2]
            if n > 0.78 and m > 0.4:
                col = COAL[0]
            if m > 0.965:
                col = (150, 154, 170)
            if m < 0.10:
                col = COAL[3]
            c.put(x, y, col)
    # heaped in the middle
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            d = max(abs(x - (x0 + x1) / 2) / ((x1 - x0) / 2 + 0.1), abs(y - (y0 + y1) / 2) / ((y1 - y0) / 2 + 0.1))
            if d > 0.8:
                c.shade(x, y, x, y, int((d - 0.8) * 500))


def backhead(c, x0, x1, y):
    """The firebox end inside a cab: fire door, gauges and regulator."""
    c.bevel(x0, y, x1, y + 5, BLACK[1], BLACK[2], BLACK[4], outline=DARK)
    mid = (x0 + x1) // 2
    c.rect(mid - 4, y + 2, mid + 5, y + 5, DARK)
    c.rect(mid - 3, y + 3, mid + 4, y + 5, FIRE[2])
    c.rect(mid - 2, y + 4, mid + 3, y + 5, FIRE[1])
    c.rect(mid - 1, y + 5, mid + 2, y + 5, FIRE[0])
    for x in (x0 + 4, x0 + 9, x1 - 9, x1 - 4):
        c.put(x, y + 2, BRASS[0])
        c.put(x + 1, y + 2, WHITE)
        c.put(x, y + 3, BRASS[2])
    c.line(mid, y + 1, mid + 7, y + 1, RED[0])
    c.put(mid + 8, y + 1, BRASS[0])
    # glow on the floor
    for i, a in enumerate((70, 44, 22)):
        c.rect(mid - 5, y + 6 + i, mid + 6, y + 6 + i, FIRE[1], a)


def cab_walls(c, y0, y1, ramp, thick=3, windows=((6, 14),), glass=True):
    """Side walls of a cab from y0 to y1 with window openings given from y0."""
    for x0 in (8, 88 - thick):
        c.rect(x0, y0, x0 + thick - 1, y1, ramp[4])
        c.bands(x0 + 1, y0, x0 + thick - 2, y1, [ramp[1]] if thick == 3 else [ramp[1], ramp[3]], along=True)
        for a, b in windows:
            if glass:
                glass_run(c, y0 + a, y0 + b, x0=x0, x1=x0 + thick - 1)
                c.clear(x0 + thick, y0 + a, x0 + thick + 2, y0 + b) if x0 > 40 else None
            else:
                c.rect(x0, y0 + a, x0 + thick - 1, y0 + b, (12, 14, 10))
    c.shade(8 + thick, y0, 8 + thick, y1, 70)
    c.shade(87 - thick, y0, 87 - thick, y1, 70)


def loco_steam(c, with_roof=False):
    # running gear under the footplate
    for y in (30, 44, 58):
        wheel(c, 5, y - 6, y + 5, True)
        wheel(c, 88, y - 6, y + 5, False)
    for x in (7, 87):
        wheel(c, x, 9, 16, x < 40)
    for x in (4, 91):
        c.rect(x, 24, x, 62, STEEL[1])
        for y in (30, 44, 58):
            c.put(x, y, BRASS[0])
            c.put(x, y + 1, STEEL[4])
    # tender wheels
    for y in (100, 110, 120):
        wheel(c, 6, y - 3, y + 3, True)
        wheel(c, 87, y - 3, y + 3, False)
    # footplate
    c.rect(9, 3, 86, 70, DARK)
    tread(c, 10, 4, 85, 69, face=BLACK[3], lit=BLACK[2], dark=BLACK[4], seams=False)
    for x in (10, 85):
        c.rect(x, 4, x, 69, RED[1])
    # cylinders
    for x0 in (3, 84):
        c.cyl(x0, 9, x0 + 8, 23, BLACK, along=True)
        c.rect(x0, 9, x0 + 8, 9, DARK)
        c.rect(x0, 23, x0 + 8, 23, DARK)
        c.rect(x0 + 1, 11, x0 + 7, 11, BRASS[2])
        c.rect(x0 + 4, 24, x0 + 4, 27, STEEL[0])
    beam(c, 0, 3)
    for x in (30, 64):
        c.rect(x, 4, x + 2, 6, DARK)
        c.put(x + 1, 5, FIRE[0])
    # splashers
    for y in (30, 44, 58):
        for x0 in (12, 77):
            c.bevel(x0, y - 6, x0 + 6, y + 5, GREEN[1], GREEN[2], GREEN[3], outline=GREEN[4])
            c.rect(x0 + 1, y - 5, x0 + 5, y - 5, BRASS[1])
    for x0 in (14, 79):
        c.rect(x0, 42, x0 + 2, 46, BRASS[1])
        c.rect(x0 + 1, 43, x0 + 1, 45, RED[1])
    # smokebox, boiler and firebox
    c.shade(64, 8, 69, 70, 90)
    c.cyl(32, 6, 63, 22, BLACK, along=True)
    c.rect(32, 6, 63, 6, DARK)
    c.cyl(33, 7, 62, 7, [BLACK[0], BLACK[0], BLACK[1], BLACK[2], BLACK[4]], along=True)
    c.cyl(30, 23, 65, 64, GREEN, along=True)
    for y in (23, 33, 44, 55):
        c.cyl(30, y, 65, y, BRASS, along=True)
        c.cyl(30, y + 1, 65, y + 1, [GREEN[2], GREEN[3], GREEN[3], GREEN[4], GREEN[4]], along=True)
    c.bevel(27, 60, 68, 72, GREEN[1], GREEN[2], GREEN[3], outline=GREEN[4])
    c.rect(29, 62, 66, 62, GREEN[0])
    for x in (31, 39, 56, 64):
        c.rivet(x, 66, BRASS[0], GREEN[4])
    # handrails
    for x in (28, 67):
        c.rect(x, 8, x, 58, STEEL[0])
        for y in range(10, 58, 12):
            c.put(x, y, BRASS[1])
    # chimney with its copper cap
    c.shade(46, 10, 57, 22, 60)
    c.disc(47.5, 13.5, 6.4, [COPPER[0], COPPER[1], COPPER[2], COPPER[3]], outline=DARK)
    c.disc(47.5, 13.5, 4.4, [BLACK[1], BLACK[2], BLACK[3]], outline=DARK)
    c.disc(47.5, 13.5, 2.6, [(4, 4, 6), (10, 10, 12)], flat=True)
    # dome, safety valves and whistle
    c.shade(46, 36, 57, 49, 70)
    c.disc(47.5, 39.0, 6.6, [WHITE, BRASS[0], BRASS[1], BRASS[2], BRASS[3]], outline=BRASS[4])
    for x in (45.0, 50.0):
        c.disc(x, 51.0, 1.9, [BRASS[0], BRASS[1], BRASS[3]], outline=BRASS[4])
    c.put(47, 57, BRASS[0])
    c.put(48, 57, BRASS[0])
    c.put(48, 58, BRASS[3])
    # cab
    planks(c, 11, 73, 84, 96, seed=4)
    c.rect(8, 69, 87, 72, GREEN[4])
    c.bands(9, 70, 86, 71, [GREEN[1], GREEN[3]], along=False)
    for x0 in (13, 73):
        c.rect(x0, 69, x0 + 9, 72, GLASS[3])
        c.bands(x0 + 1, 70, x0 + 8, 71, [GLASS[0], GLASS[1]], along=False)
        c.put(x0 + 2, 70, WHITE)
    c.shade(11, 73, 84, 73, 80)
    cab_walls(c, 73, 93, GREEN, thick=3, windows=((3, 12),))
    backhead(c, 30, 65, 72)
    c.disc(17.5, 86.5, 3.0, [WALNUT[0], WALNUT[1], WALNUT[2]], outline=WALNUT[3])
    c.disc(78.5, 86.5, 3.0, [WALNUT[0], WALNUT[1], WALNUT[2]], outline=WALNUT[3])
    c.line(72, 76, 74, 82, STEEL[0])
    c.put(74, 83, RED[0])
    for x in (9, 86):
        c.put(x, 94, BRASS[0])
        c.put(x, 95, BRASS[2])
    # fall plate and tender
    tread(c, 30, 94, 65, 98, face=STEEL[3], lit=STEEL[1], dark=STEEL[4], seams=False)
    c.rect(30, 94, 65, 94, STEEL_O)
    c.shade(9, 125, 88, 125, 60)
    c.bevel(8, 98, 87, 124, GREEN[1], GREEN[2], GREEN[3], outline=GREEN[4])
    c.frame(10, 100, 85, 122, BRASS[2])
    c.rect(12, 101, 83, 121, GREEN[3])
    c.rect(17, 100, 78, 116, GREEN[4])
    c.rect(18, 99, 77, 99, GREEN[4])
    coal(c, 18, 99, 77, 115)
    c.rect(17, 116, 78, 116, GREEN[0])
    for x in (20, 26):
        c.put(x, 96, COAL[1])
        c.put(x + 40, 97, COAL[2])
    c.disc(47.5, 119.5, 2.4, [STEEL[0], STEEL[2], STEEL[4]], outline=STEEL_O)
    c.bevel(14, 118, 26, 121, PLANK[0], PLANK[2], PLANK[4], outline=PLANK_SEAM)
    c.put(20, 119, BRASS[0])
    c.bevel(68, 118, 80, 121, STEEL[1], STEEL[3], STEEL[4], outline=STEEL_O)
    beam(c, 125, 127)
    if with_roof:
        c.stamp(row_canvas(roof_loco_steam, c.tf), *row_offset(c, 2))


def cab_stations(c, y0):
    """The three stations of a steam cab whose floor starts at row y0: the
    fireman's injector wheels and gauge glass on the left, the driver's
    regulator, reverser wheel and brake handle on the right, a seat for each."""
    # fireman's side: two injector wheels on their steam pipe, the gauge glass
    c.rect(13, y0 + 3, 26, y0 + 4, COPPER[2])
    c.rect(13, y0 + 3, 26, y0 + 3, COPPER[0])
    for x in (15.5, 22.5):
        c.disc(x, y0 + 7.5, 2.4, [BRASS[0], BRASS[1], BRASS[3]], outline=BRASS[4])
        c.put(int(x), y0 + 7, RED[0])
    c.rect(27, y0 + 2, 28, y0 + 9, GLASS[3])
    c.rect(27, y0 + 5, 28, y0 + 8, GLASS[1])
    c.put(27, y0 + 3, WHITE)
    c.disc(17.5, y0 + 19.5, 3.0, [WALNUT[0], WALNUT[1], WALNUT[2]], outline=WALNUT[3])
    # driver's stand: the regulator handle reaching back from the backhead,
    # the reverser wheel on its pedestal and the brake handle
    c.line(66, y0 + 3, 74, y0 + 9, STEEL_O)
    c.line(66, y0 + 2, 74, y0 + 8, RED[0])
    c.put(75, y0 + 9, BRASS[0])
    c.bevel(77, y0 + 2, 83, y0 + 12, BLACK[1], BLACK[2], BLACK[4], outline=DARK)
    c.disc(80.0, y0 + 7.0, 2.6, [STEEL[0], STEEL[1], STEEL[3]], outline=STEEL_O)
    c.put(80, y0 + 7, BRASS[0])
    c.rect(69, y0 + 13, 70, y0 + 17, BRASS[2])
    c.rect(68, y0 + 12, 71, y0 + 12, BRASS[0])
    c.disc(78.5, y0 + 19.5, 3.0, [WALNUT[0], WALNUT[1], WALNUT[2]], outline=WALNUT[3])


def loco_mainline(c, with_roof=False):
    """A six-coupled express engine, 96 x 192: smokebox and bogie, three
    sections of boiler over the driving wheels, the wide firebox over the
    trailing truck and the cab, open at the back to the tender."""
    # bogie, driving wheels with their rods, trailing truck
    for y in (9, 21):
        for x in (7, 87):
            wheel(c, x, y - 4, y + 4, x < 40)
    for y in (58, 82, 106):
        wheel(c, 5, y - 10, y + 10, True)
        wheel(c, 88, y - 10, y + 10, False)
    for x in (4, 91):
        c.rect(x, 44, x, 116, STEEL[1])
        c.rect(x, 40, x, 43, STEEL[3])
        for y in (58, 82, 106):
            c.put(x, y, BRASS[0])
            c.put(x, y + 1, STEEL[4])
    for x in (7, 87):
        wheel(c, x, 136, 147, x < 40)
    # footplate
    c.rect(9, 3, 86, 158, DARK)
    tread(c, 10, 4, 85, 157, face=BLACK[3], lit=BLACK[2], dark=BLACK[4], seams=False)
    for x in (10, 85):
        c.rect(x, 4, x, 157, RED[1])
    # cylinders outside the frames, behind the bogie
    for x0 in (3, 84):
        c.cyl(x0, 26, x0 + 8, 42, BLACK, along=True)
        c.rect(x0, 26, x0 + 8, 26, DARK)
        c.rect(x0, 42, x0 + 8, 42, DARK)
        c.rect(x0 + 1, 28, x0 + 7, 28, BRASS[2])
        c.rect(x0 + 4, 43, x0 + 4, 47, STEEL[0])
    beam(c, 0, 3)
    for x in (30, 64):
        c.rect(x, 4, x + 2, 6, DARK)
        c.put(x + 1, 5, FIRE[0])
    # splashers over the driving wheels, a nameplate on the middle pair
    for y in (58, 82, 106):
        for x0 in (12, 77):
            c.bevel(x0, y - 9, x0 + 6, y + 9, GREEN[1], GREEN[2], GREEN[3], outline=GREEN[4])
            c.rect(x0 + 1, y - 8, x0 + 5, y - 8, BRASS[1])
    for x0 in (14, 79):
        c.rect(x0, 77, x0 + 2, 87, BRASS[1])
        c.rect(x0 + 1, 78, x0 + 1, 86, RED[1])
    # smoke deflector plates either side of the smokebox
    for x0 in (21, 72):
        c.bevel(x0, 6, x0 + 2, 36, BLACK[1], BLACK[2], BLACK[4], outline=DARK)
    # smokebox, boiler and firebox
    c.shade(64, 8, 70, 158, 90)
    c.cyl(31, 5, 64, 30, BLACK, along=True)
    c.rect(31, 5, 64, 5, DARK)
    c.cyl(32, 6, 63, 6, [BLACK[0], BLACK[0], BLACK[1], BLACK[2], BLACK[4]], along=True)
    c.cyl(29, 31, 66, 128, GREEN, along=True)
    for y in (31, 47, 63, 79, 95, 111):
        c.cyl(29, y, 66, y, BRASS, along=True)
        c.cyl(29, y + 1, 66, y + 1, [GREEN[2], GREEN[3], GREEN[3], GREEN[4], GREEN[4]], along=True)
    c.bevel(25, 124, 70, 160, GREEN[1], GREEN[2], GREEN[3], outline=GREEN[4])
    c.rect(27, 126, 68, 126, GREEN[0])
    c.rect(27, 127, 27, 157, GREEN[0])
    for y in (132, 142, 152):
        for x in (29, 37, 58, 66):
            c.rivet(x, y, BRASS[0], GREEN[4])
    c.cyl(40, 128, 55, 156, [GREEN[0], GREEN[1], GREEN[2], GREEN[2], GREEN[3]], along=True)
    # handrails along the boiler
    for x in (27, 68):
        c.rect(x, 8, x, 120, STEEL[0])
        for y in range(10, 120, 12):
            c.put(x, y, BRASS[1])
    # double chimney with its copper cap
    c.shade(46, 9, 58, 26, 60)
    for cy in (13.5, 20.5):
        c.disc(47.5, cy, 6.0, [COPPER[0], COPPER[1], COPPER[2], COPPER[3]], outline=DARK)
    for cy in (13.5, 20.5):
        c.disc(47.5, cy, 4.0, [BLACK[1], BLACK[2], BLACK[3]], outline=DARK)
        c.disc(47.5, cy, 2.4, [(4, 4, 6), (10, 10, 12)], flat=True)
    # feed dome, steam dome, safety valves and whistle
    c.shade(46, 50, 56, 60, 70)
    c.disc(47.5, 53.0, 4.6, [GREEN[0], GREEN[1], GREEN[2], GREEN[3]], outline=GREEN[4])
    c.shade(46, 76, 58, 90, 70)
    c.disc(47.5, 79.5, 7.0, [WHITE, BRASS[0], BRASS[1], BRASS[2], BRASS[3]], outline=BRASS[4])
    for x in (44.5, 50.5):
        c.disc(x, 119.0, 2.0, [BRASS[0], BRASS[1], BRASS[3]], outline=BRASS[4])
    c.put(47, 137, BRASS[0])
    c.put(48, 137, BRASS[0])
    c.put(48, 138, BRASS[3])
    # cab: spectacle plate, floor, side sheets and the three stations
    planks(c, 11, 161, 84, 188, seed=6)
    c.rect(8, 157, 87, 160, GREEN[4])
    c.bands(9, 158, 86, 159, [GREEN[1], GREEN[3]], along=False)
    for x0 in (12, 74):
        c.rect(x0, 157, x0 + 9, 160, GLASS[3])
        c.bands(x0 + 1, 158, x0 + 8, 159, [GLASS[0], GLASS[1]], along=False)
        c.put(x0 + 2, 158, WHITE)
    c.shade(11, 161, 84, 161, 80)
    cab_walls(c, 161, 187, GREEN, thick=3, windows=((3, 13),))
    backhead(c, 30, 65, 160)
    cab_stations(c, 162)
    for x in (9, 86):
        c.put(x, 188, BRASS[0])
        c.put(x, 189, BRASS[2])
    # fall plate onto the tender
    tread(c, 30, 185, 65, 188, face=STEEL[3], lit=STEEL[1], dark=STEEL[4], seams=False)
    c.rect(30, 185, 65, 185, STEEL_O)
    beam(c, 189, 191)


def loco_tender(c, with_roof=False):
    """A separate tender: a shovelling plate at the front, the coal space
    between the tank's side sheets, and the tank top with its filler."""
    for y in (22, 64, 106):
        wheel(c, 5, y - 6, y + 5, True)
        wheel(c, 88, y - 6, y + 5, False)
    for x in (4, 91):
        c.rect(x, 14, x, 114, STEEL[1])
        for y in (22, 64, 106):
            c.put(x, y, BRASS[0])
            c.put(x, y + 1, STEEL[4])
    # frame and shovelling plate
    c.rect(9, 3, 86, 124, DARK)
    tread(c, 10, 4, 85, 31, face=STEEL[3], lit=STEEL[1], dark=STEEL[4], seams=False)
    beam(c, 0, 3)
    for x in (10, 85):
        c.rect(x, 4, x, 30, STEEL[0])
        for y in (6, 16, 26):
            c.put(x, y, BRASS[1])
    # hand brake and tool rack on the plate
    c.disc(17.5, 10.5, 3.0, [WALNUT[0], WALNUT[1], WALNUT[2]], outline=WALNUT[3])
    c.put(17, 10, BRASS[0])
    c.bevel(70, 7, 82, 10, PLANK[0], PLANK[2], PLANK[4], outline=PLANK_SEAM)
    c.put(76, 8, BRASS[0])
    # tank
    c.shade(9, 123, 88, 124, 60)
    c.bevel(8, 30, 87, 123, GREEN[1], GREEN[2], GREEN[3], outline=GREEN[4])
    c.frame(10, 32, 85, 121, BRASS[2])
    c.rect(12, 33, 83, 120, GREEN[3])
    for y in range(36, 120, 9):
        for x in (13, 82):
            c.rivet(x, y, GREEN[0], GREEN[4])
    # coal space, open to the plate through the coal door
    c.rect(19, 30, 76, 94, GREEN[4])
    coal(c, 20, 30, 75, 93, seed=131)
    c.rect(19, 94, 76, 94, GREEN[0])
    c.rect(36, 28, 59, 31, DARK)
    coal(c, 37, 27, 58, 31, seed=137)
    for x, y in ((33, 25), (41, 24), (55, 25), (62, 26)):
        c.put(x, y, COAL[1])
        c.put(x + 1, y, COAL[2])
    # tank top: filler, vents and the tool boxes
    for y in (99, 117):
        for x in range(16, 82, 11):
            c.rivet(x, y, GREEN[0], GREEN[4])
    c.shade(41, 102, 57, 116, 60)
    c.disc(47.5, 107.5, 6.6, [WHITE, BRASS[0], BRASS[1], BRASS[2], BRASS[3]], outline=BRASS[4])
    c.disc(47.5, 107.5, 3.2, [STEEL[1], STEEL[3], STEEL[4]], outline=STEEL_O)
    c.put(46, 106, WHITE)
    for x in (24.0, 71.0):
        c.disc(x, 107.5, 1.9, [BRASS[0], BRASS[1], BRASS[3]], outline=BRASS[4])
    c.bevel(14, 111, 30, 118, PLANK[0], PLANK[2], PLANK[4], outline=PLANK_SEAM)
    c.put(22, 114, BRASS[0])
    c.bevel(65, 111, 81, 118, STEEL[1], STEEL[3], STEEL[4], outline=STEEL_O)
    c.put(73, 114, STEEL[0])
    beam(c, 125, 127)


def hood(c, x0, y0, x1, y1, ramp, chamfer=3):
    n = x1 - x0 + 1
    cols = [ramp[4]] + [ramp[1]] * chamfer + [ramp[2]] * (n - 2 - chamfer * 2) + [ramp[3]] * chamfer + [ramp[4]]
    c.bands(x0, y0, x1, y1, cols, along=True)
    c.rect(x0, y0, x1, y0, ramp[4])
    c.rect(x0, y1, x1, y1, ramp[4])


def fan(c, cx, cy, r):
    c.disc(cx, cy, r, [STEEL[1], STEEL[2], STEEL[4]], outline=STEEL_O, flat=True)
    c.disc(cx, cy, r - 1.6, [(30, 32, 38), (16, 16, 20)], flat=True)
    for k in range(8):
        a = math.radians(k * 45 + 12)
        for t in (0.35, 0.6, 0.85):
            c.put(round(cx + math.cos(a) * (r - 2) * t), round(cy + math.sin(a) * (r - 2) * t), STEEL[3])
    for d in range(-int(r) + 2, int(r) - 1, 2):
        w = int(math.sqrt(max(0, (r - 1.6) ** 2 - d * d)))
        c.rect(cx - w, cy + d, cx + w, cy + d, STEEL[2], 90)
    c.disc(cx, cy, 1.6, [STEEL[0], STEEL[2]], flat=True)


def loco_diesel(c, with_roof=False):
    for y in (14, 26, 96, 108):
        wheel(c, 6, y - 4, y + 4, True)
        wheel(c, 87, y - 4, y + 4, False)
    for y0 in (9, 91):
        for x in (5, 90):
            c.rect(x, y0, x, y0 + 22, STEEL[3])
            c.put(x, y0 + 11, YELLOW[0])
    # frame and walkways
    c.rect(8, 3, 87, 124, DARK)
    tread(c, 9, 4, 86, 123, face=STEEL[3], lit=STEEL[2], dark=STEEL[4], seams=False)
    for x in (9, 86):
        c.rect(x, 33, x, 122, YELLOW[1])
        for y in range(34, 122, 8):
            c.put(x, y, YELLOW[0])
            c.put(x, y + 1, YELLOW[3])
    beam(c, 0, 3, ramp=YELLOW, hazard=True)
    beam(c, 124, 127, ramp=YELLOW, hazard=True)
    # nose
    c.shade(11, 10, 86, 10, 60)
    c.bevel(10, 4, 85, 9, YELLOW[0], YELLOW[1], YELLOW[2], outline=YELLOW[3])
    for x in (28.5, 66.5):
        c.disc(x, 6.5, 2.4, [WHITE, FIRE[0], (220, 200, 120)], outline=STEEL_O)
    c.rect(44, 5, 51, 8, YELLOW[3])
    c.rect(45, 6, 50, 7, BLUE[2])
    # cab: floor, desk and seats
    c.rect(10, 10, 85, 31, BLUE[4])
    for y in range(13, 30):
        for x in range(13, 83):
            c.put(x, y, (110, 118, 112) if noise(x, y, 111) > 0.08 else (92, 100, 96))
    c.bevel(15, 13, 62, 18, STEEL[2], STEEL[4], (30, 32, 38), outline=DARK)
    for x, col in ((19, BRASS[0]), (24, BRASS[0]), (29, WHITE), (36, RED[0]), (40, (96, 220, 110)), (46, BRASS[0]),
                   (52, WHITE), (57, RED[0])):
        c.put(x, 15, col)
        c.put(x, 16, mix(col, DARK, 0.5))
    c.line(64, 14, 68, 17, STEEL[0])
    c.put(69, 18, RED[0])
    for x0 in (24, 58):
        c.shade(x0 + 1, 22, x0 + 11, 30, 60)
        c.bevel(x0, 21, x0 + 9, 28, (150, 96, 60), (112, 68, 42), (78, 46, 28), outline=(40, 22, 14))
        c.rect(x0, 28, x0 + 9, 29, (40, 22, 14))
        c.rect(x0 + 1, 28, x0 + 8, 28, (150, 96, 60))
    # windscreen and walls
    c.rect(10, 10, 85, 12, BLUE[4])
    c.bands(11, 11, 84, 11, [BLUE[1]], along=False)
    for x0, x1 in ((15, 44), (51, 80)):
        c.rect(x0, 10, x1, 12, GLASS[3])
        c.bands(x0 + 1, 11, x1 - 1, 11, [GLASS[0]], along=False)
        c.put(x0 + 3, 11, WHITE)
        c.put(x0 + 9, 11, GLASS[1])
    for x0 in (10, 83):
        c.rect(x0, 10, x0 + 2, 31, BLUE[4])
        c.rect(x0 + 1, 11, x0 + 1, 30, BLUE[1])
        glass_run(c, 15, 25, x0=x0, x1=x0 + 2)
    c.clear(86, 15, 88, 25)
    tread(c, 86, 15, 86, 25, face=STEEL[3], lit=STEEL[2], dark=STEEL[4], seams=False)
    c.rect(10, 30, 85, 31, BLUE[4])
    c.rect(11, 30, 84, 30, BLUE[1])
    for x0 in (14, 75):
        sill = Canvas(1, 1)
        del sill
        c.rect(x0, 30, x0 + 6, 31, STEEL[4])
        c.rect(x0 + 1, 30, x0 + 5, 30, STEEL[2])
    # the long hood
    c.shade(74, 34, 77, 118, 80)
    hood(c, 22, 32, 73, 116, BLUE)
    for x in (26, 69):
        c.rect(x, 33, x, 115, (236, 228, 196))
    for y in (46, 58):
        c.frame(29, y, 66, y + 10, BLUE[4], 150)
        c.rect(30, y + 1, 65, y + 1, BLUE[0], 70)
        c.rect(46, y + 5, 49, y + 5, STEEL[0])
    for x in (41.5, 53.5):
        c.shade(int(x) - 2, 37, int(x) + 5, 44, 50)
        c.disc(x, 39.5, 3.0, [STEEL[0], STEEL[2], STEEL[4]], outline=STEEL_O)
        c.disc(x, 39.5, 1.5, [(6, 6, 8), (6, 6, 8)], flat=True)
    fan(c, 47.5, 80.5, 8.0)
    fan(c, 47.5, 101.5, 8.0)
    for y in range(111, 116):
        c.rect(26, y, 69, y, BLUE[4] if y % 2 else STEEL[2])
    for x, y in ((24, 34), (71, 34), (24, 114), (71, 114)):
        c.put(x, y, YELLOW[0])
    # rear platform rail
    c.rect(9, 121, 40, 121, YELLOW[1])
    c.rect(55, 121, 86, 121, YELLOW[1])
    for x in (9, 24, 40, 55, 71, 86):
        c.put(x, 121, YELLOW[0])
        c.put(x, 122, YELLOW[3])
    c.disc(47.5, 119.0, 1.8, [WHITE, FIRE[0], (220, 200, 120)], outline=STEEL_O)
    if with_roof:
        c.stamp(row_canvas(roof_loco_diesel, c.tf), *row_offset(c, 0))


DMAROON = ((204, 92, 82), (156, 50, 50), (120, 32, 38), (86, 20, 28), (46, 10, 16))


def span(m, a, b):
    """Rows a..b counted through the row map m, low row first."""
    return (min(m(a), m(b)), max(m(a), m(b)))


def diesel_cab_end(c, m):
    """One cab of the main-line diesel. m maps a row counted from this end of
    the engine to a row of the drawing, so the same cab is drawn at both ends."""
    # nose: marker lights either side of the headcode panel
    y0, y1 = span(m, 4, 9)
    c.bevel(10, y0, 85, y1, YELLOW[0], YELLOW[1], YELLOW[2], outline=YELLOW[3])
    for x in (28.5, 66.5):
        c.disc(x, (y0 + y1) / 2.0, 2.4, [WHITE, FIRE[0], (220, 200, 120)], outline=STEEL_O)
    y0, y1 = span(m, 5, 8)
    c.rect(44, y0, 51, y1, YELLOW[3])
    c.rect(45, y0 + 1, 50, y1 - 1, DMAROON[2])
    for x in (16, 79):
        c.put(x, m(6), RED[0])
        c.put(x, m(7), RED[2])
    # floor, desk and two seats
    y0, y1 = span(m, 10, 31)
    c.rect(10, y0, 85, y1, DMAROON[4])
    y0, y1 = span(m, 13, 29)
    for y in range(y0, y1 + 1):
        for x in range(13, 83):
            c.put(x, y, (116, 112, 104) if noise(x, y, 113) > 0.08 else (98, 94, 88))
    y0, y1 = span(m, 13, 18)
    c.bevel(15, y0, 62, y1, STEEL[2], STEEL[4], (30, 32, 38), outline=DARK)
    for x, col in ((19, BRASS[0]), (24, BRASS[0]), (29, WHITE), (36, RED[0]), (40, (96, 220, 110)), (46, BRASS[0]),
                   (52, WHITE), (57, RED[0])):
        c.put(x, m(15), col)
        c.put(x, m(16), mix(col, DARK, 0.5))
    # the driver's brake valve and the dead-man's handle beside the desk
    c.line(64, m(14), 68, m(17), STEEL[0])
    c.put(69, m(18), RED[0])
    c.disc(73.5, (m(15) + m(16)) / 2.0, 1.8, [BRASS[0], BRASS[1], BRASS[3]], outline=BRASS[4])
    for x0 in (24, 58):
        y0, y1 = span(m, 21, 28)
        c.shade(x0 + 1, y0 + 1, x0 + 11, y1 + 2, 60)
        c.bevel(x0, y0, x0 + 9, y1, (150, 96, 60), (112, 68, 42), (78, 46, 28), outline=(40, 22, 14))
    # windscreen
    y0, y1 = span(m, 10, 12)
    c.rect(10, y0, 85, y1, DMAROON[4])
    c.bands(11, m(11), 84, m(11), [DMAROON[1]], along=False)
    for x0, x1 in ((15, 44), (51, 80)):
        c.rect(x0, y0, x1, y1, GLASS[3])
        c.bands(x0 + 1, m(11), x1 - 1, m(11), [GLASS[0]], along=False)
        c.put(x0 + 3, m(11), WHITE)
        c.put(x0 + 9, m(11), GLASS[1])
    # side walls with their drop windows
    for x0 in (10, 83):
        y0, y1 = span(m, 10, 31)
        c.rect(x0, y0, x0 + 2, y1, DMAROON[4])
        c.rect(x0 + 1, y0 + 1, x0 + 1, y1 - 1, DMAROON[1])
        glass_run(c, *span(m, 15, 25), x0=x0, x1=x0 + 2)
    # back wall, with a door onto each walkway
    y0, y1 = span(m, 30, 31)
    c.rect(10, y0, 85, y1, DMAROON[4])
    c.rect(11, m(30), 84, m(30), DMAROON[1])
    for x0 in (14, 75):
        c.rect(x0, y0, x0 + 6, y1, STEEL[4])
        c.rect(x0 + 1, m(30), x0 + 5, m(30), STEEL[2])


def loco_dieselmain(c, with_roof=False):
    """A main-line diesel, 96 x 192: a cab at each end, the same from either
    way, and the long hood between them over two six-wheel bogies."""
    for y in (38, 50, 62, 129, 141, 153):
        wheel(c, 6, y - 4, y + 4, True)
        wheel(c, 87, y - 4, y + 4, False)
    for y0 in (33, 124):
        for x in (5, 90):
            c.rect(x, y0, x, y0 + 34, STEEL[3])
            for k in (5, 17, 29):
                c.put(x, y0 + k, YELLOW[0])
    # frame and walkways
    c.rect(8, 3, 87, 188, DARK)
    tread(c, 9, 4, 86, 187, face=STEEL[3], lit=STEEL[2], dark=STEEL[4], seams=False)
    for x in (9, 86):
        c.rect(x, 33, x, 158, YELLOW[1])
        for y in range(34, 158, 8):
            c.put(x, y, YELLOW[0])
            c.put(x, y + 1, YELLOW[3])
    beam(c, 0, 3, ramp=YELLOW, hazard=True)
    beam(c, 188, 191, ramp=YELLOW, hazard=True)
    diesel_cab_end(c, lambda y: y)
    diesel_cab_end(c, lambda y: 191 - y)
    # the long hood, a cream band along each shoulder
    c.shade(74, 34, 77, 158, 80)
    hood(c, 22, 32, 73, 159, DMAROON)
    for x in (26, 69):
        c.rect(x, 33, x, 158, CREAM[1])
    # radiator grilles and fans at each end
    for y0 in (35, 151):
        for y in range(y0, y0 + 6):
            c.rect(29, y, 66, y, DMAROON[4] if (y - y0) % 2 else STEEL[2])
    fan(c, 47.5, 52.5, 8.0)
    fan(c, 47.5, 138.5, 8.0)
    # engine room doors, two each side of the exhausts
    for y in (64, 76, 106, 118):
        c.frame(29, y, 66, y + 9, DMAROON[4], 150)
        c.rect(30, y + 1, 65, y + 1, DMAROON[0], 70)
        c.rect(46, y + 5, 49, y + 5, STEEL[0])
    # twin exhausts and the boiler-room hatch between them
    for x in (38.5, 56.5):
        c.shade(int(x) - 2, 93, int(x) + 5, 100, 50)
        c.disc(x, 95.5, 3.2, [STEEL[0], STEEL[2], STEEL[4]], outline=STEEL_O)
        c.disc(x, 95.5, 1.6, [(6, 6, 8), (6, 6, 8)], flat=True)
    hatch(c, 44, 91, 51, 100, ramp=(DMAROON[1], DMAROON[2], DMAROON[3], DMAROON[4]))
    for x, y in ((24, 34), (71, 34), (24, 157), (71, 157), (24, 95), (71, 95)):
        c.put(x, y, YELLOW[0])


def roof_loco_dieselmain(c, m=lambda y: y):
    prof = [DMAROON[4], DMAROON[3], DMAROON[1], DMAROON[0], DMAROON[1], DMAROON[2], DMAROON[2], DMAROON[3],
            DMAROON[4]]
    y0, y1 = span(m, 9, 31)
    c.bands(9, y0, 86, y1, across(prof, 78), along=True)
    c.frame(9, y0, 86, y1, DMAROON[4])
    c.rect(10, m(10), 85, m(10), CREAM[1])
    c.rect(10, m(30), 85, m(30), DMAROON[3])
    # twin horns, a ventilator and the aerial
    for x in (36, 44):
        y0, y1 = span(m, 13, 20)
        c.shade(x + 1, y0 + 2, x + 3, y1 + 2, 60)
        c.cyl(x, y0, x + 2, y1, BRASS, along=True)
        c.rect(x, m(13), x + 2, m(13), BRASS[4])
    y0, y1 = span(m, 14, 24)
    hatch(c, 54, y0, 66, y1, ramp=(DMAROON[1], DMAROON[2], DMAROON[3], DMAROON[4]), handle=False)
    for y in (17, 20):
        c.rect(57, m(y), 63, m(y), DMAROON[4])
    c.put(22, m(20), STEEL[0])
    c.put(72, m(26), RED[0])


def roof_loco_dieselmain_rear(c):
    roof_loco_dieselmain(c, lambda y: 31 - y)


def loco_armored(c, with_roof=False):
    # skirts hide the running gear
    for x0 in (4, 87):
        c.rect(x0, 5, x0 + 4, 123, OLIVE[3])
        c.bands(x0 + 1, 6, x0 + 3, 122, [OLIVE[0], OLIVE[1], OLIVE[2]], along=True)
        for y in range(10, 122, 9):
            c.rivet(x0 + 2, y, mix(OLIVE[0], WHITE, 0.25), OLIVE[3])
        for y in (36, 68, 97):
            c.rect(x0 + 1, y, x0 + 3, y, OLIVE_D)
    c.rect(8, 3, 87, 124, OLIVE[3])
    c.rect(9, 4, 86, 123, OLIVE[1])
    for y in (20, 36, 52, 68):
        c.rect(9, y, 86, y, OLIVE_D)
        for x in (13, 20, 75, 82):
            c.rivet(x, y - 2, mix(OLIVE[0], WHITE, 0.25), OLIVE[3])
    beam(c, 0, 3, ramp=(STEEL[1], STEEL[2], STEEL[4], STEEL_O))
    # boiler casing
    c.shade(68, 8, 72, 70, 90)
    plate_roof(c, 28, 6, 67, 68, chamfer=6)
    c.rect(28, 6, 67, 6, OLIVE[3])
    c.rect(29, 7, 66, 8, mix(OLIVE[0], WHITE, 0.15))
    c.rect(28, 68, 67, 68, OLIVE[3])
    for y in (22, 38, 54):
        c.rect(29, y, 66, y, OLIVE_D)
        for x in range(32, 66, 6):
            c.rivet(x, y - 2, mix(OLIVE[0], WHITE, 0.25), OLIVE[3])
    c.shade(46, 11, 56, 21, 70)
    c.disc(47.5, 13.5, 5.6, [OLIVE[0], OLIVE[1], OLIVE[2]], outline=OLIVE[3])
    c.disc(47.5, 13.5, 2.8, [(4, 4, 6), (10, 10, 12)], flat=True)
    hatch(c, 40, 28, 55, 35, handle=False)
    hatch(c, 40, 42, 55, 51)
    # cab
    c.rect(12, 73, 83, 97, DARK)
    tread(c, 12, 73, 83, 97, face=STEEL[3], lit=STEEL[2], dark=STEEL[4], seams=False)
    c.rect(8, 69, 87, 72, OLIVE[3])
    c.bands(9, 70, 86, 71, [OLIVE[0], OLIVE[2]], along=False)
    for x0 in (14, 74):
        c.rect(x0, 70, x0 + 7, 71, (12, 14, 10))
    c.shade(12, 73, 83, 73, 80)
    for x0 in (8, 84):
        c.rect(x0, 73, x0 + 3, 97, OLIVE[3])
        c.bands(x0 + 1, 73, x0 + 2, 97, [OLIVE[0], OLIVE[2]], along=True)
        c.rect(x0, 80, x0 + 3, 85, (12, 14, 10))
        for y in (76, 90, 95):
            c.rivet(x0 + 1, y, mix(OLIVE[0], WHITE, 0.25), OLIVE[3])
    c.shade(12, 73, 12, 97, 70)
    c.shade(83, 73, 83, 97, 70)
    backhead(c, 30, 65, 72)
    c.disc(18.5, 87.5, 3.0, [WALNUT[0], WALNUT[1], WALNUT[2]], outline=WALNUT[3])
    c.disc(77.5, 87.5, 3.0, [WALNUT[0], WALNUT[1], WALNUT[2]], outline=WALNUT[3])
    # armoured tender
    c.shade(9, 125, 88, 125, 60)
    plate_roof(c, 8, 98, 87, 124, chamfer=4)
    c.rect(8, 98, 87, 98, OLIVE[3])
    c.rect(8, 124, 87, 124, OLIVE[3])
    c.rect(30, 98, 65, 99, STEEL[3])
    hatch(c, 16, 102, 46, 116)
    hatch(c, 49, 102, 79, 116)
    c.disc(47.5, 120.5, 2.2, [STEEL[0], STEEL[2], STEEL[4]], outline=STEEL_O)
    for x in range(14, 86, 9):
        c.rivet(x, 122, mix(OLIVE[0], WHITE, 0.25), OLIVE[3])
    beam(c, 125, 127, ramp=(STEEL[1], STEEL[2], STEEL[4], STEEL_O))
    camo(c, 0, 0, 95, 127, seed=93)
    if with_roof:
        c.stamp(row_canvas(roof_loco_armored, c.tf), *row_offset(c, 2))


# Cab roofs: one row of three tiles.

def roof_loco_steam(c):
    prof = [GREEN[4], GREEN[3], GREEN[1], GREEN[0], GREEN[1], GREEN[2], GREEN[2], GREEN[3], GREEN[4]]
    c.shade(8, 31, 87, 31, 0)
    c.bands(7, 4, 88, 30, across(prof, 82), along=True)
    c.frame(7, 4, 88, 30, GREEN[4])
    c.rect(8, 5, 87, 5, GREEN[0], 120)
    for x in (8, 87):
        c.rect(x, 5, x, 29, BRASS[2])
    for y in (12, 22):
        c.shade(9, y, 86, y, 50)
    hatch(c, 40, 11, 55, 22, ramp=(GREEN[1], GREEN[2], GREEN[3], GREEN[4]))


def roof_loco_diesel(c):
    prof = [BLUE[4], BLUE[3], BLUE[1], BLUE[0], BLUE[1], BLUE[2], BLUE[2], BLUE[3], BLUE[4]]
    c.bands(9, 9, 86, 31, across(prof, 78), along=True)
    c.frame(9, 9, 86, 31, BLUE[4])
    c.rect(10, 10, 85, 10, (236, 228, 196))
    c.rect(10, 30, 85, 30, BLUE[3])
    # horns, vent and aerial
    for x in (36, 44):
        c.shade(x + 1, 15, x + 3, 22, 60)
        c.cyl(x, 13, x + 2, 20, BRASS, along=True)
        c.rect(x, 13, x + 2, 13, BRASS[4])
    hatch(c, 54, 14, 66, 24, ramp=(BLUE[1], BLUE[2], BLUE[3], BLUE[4]), handle=False)
    for y in (17, 20):
        c.rect(57, y, 63, y, BLUE[4])
    c.put(22, 20, STEEL[0])
    c.put(23, 21, DARK, 140)
    c.put(72, 26, RED[0])


def roof_loco_armored(c):
    plate_roof(c, 7, 4, 88, 31, chamfer=5)
    c.rect(7, 4, 88, 4, OLIVE[3])
    c.rect(7, 31, 88, 31, OLIVE[3])
    c.rect(8, 5, 87, 5, mix(OLIVE[0], WHITE, 0.15))
    for x in range(12, 88, 8):
        c.rivet(x, 28, mix(OLIVE[0], WHITE, 0.25), OLIVE[3])
        c.rivet(x, 8, mix(OLIVE[0], WHITE, 0.25), OLIVE[3])
    hatch(c, 39, 11, 56, 24)
    c.disc(22.5, 17.5, 2.6, [STEEL[0], STEEL[2], STEEL[4]], outline=STEEL_O)
    camo(c, 0, 0, 95, 31, seed=95)


def row_canvas(draw, tf):
    c = Canvas(96, 32, tf)
    draw(c)
    return c


def row_offset(c, seg, rows=4):
    """World offset of one row of a `rows`-long car drawn with c's transform."""
    return {'id': (0, seg * 32), 'vf': (0, (rows - 1 - seg) * 32),
            'cw': ((rows - 1 - seg) * 32, 0), 'tp': (seg * 32, 0)}[c.tf]


LOCOS = {'steam': (loco_steam, roof_loco_steam), 'diesel': (loco_diesel, roof_loco_diesel),
         'armored': (loco_armored, roof_loco_armored)}
# name -> (sections, the section under the cab roof); the others are 4 long
LOCO_ROWS = {'mainline': (6, 5), 'diesel': (4, 0), 'dieselmain': (6, 0)}


def loco_rows(name):
    return LOCO_ROWS.get(name, (4, 2))


def loco_states():
    out = {}
    for name, (body, roof) in list(LOCOS.items()) + [('tender', (loco_tender, None)),
                                                     ('mainline', (loco_mainline, roof_loco_steam)),
                                                     ('dieselmain', (loco_dieselmain, roof_loco_dieselmain))]:
        rows = loco_rows(name)[0]
        imgs = directions(body, w=96, h=rows * 32, order=HEADING)
        for seg in range(rows):
            for col, cn in ((-1, 'l'), (0, 'c'), (1, 'r')):
                out['loco_%s_%d%s' % (name, seg + 1, cn)] = slice_car(imgs, rows, seg, col)
        if not roof:
            continue
        rimgs = directions(roof, w=96, h=32, order=HEADING)
        for col, cn in ((-1, 'l'), (0, 'c'), (1, 'r')):
            out['roof_loco_%s_%s' % (name, cn)] = slice_car(rimgs, 1, 0, col)
    # the main-line diesel's rear cab: the same roof, facing the other way
    rimgs = directions(roof_loco_dieselmain_rear, w=96, h=32, order=HEADING)
    for col, cn in ((-1, 'l'), (0, 'c'), (1, 'r')):
        out['roof_loco_dieselmain_b%s' % cn] = slice_car(rimgs, 1, 0, col)
    return out


# ---------------------------------------------------------------------------
# Railway gun: 96 x 96, the barrel pointing north

def railway_gun(c):
    cx = cy = 47.5
    c.disc(cx + 1.5, cy + 2, 23.5, [(0, 0, 0), (0, 0, 0)], flat=True)
    for key in list(c.px):
        c.px[key] = (0, 0, 0, 80)
    # turntable: base ring with its traverse rack, then the turning platform
    c.disc(cx, cy, 23.5, [STEEL[1], STEEL[2], STEEL[3], STEEL[4]], outline=STEEL_O, flat=True)
    for k in range(72):
        a = math.radians(k * 5)
        c.put(round(cx + math.cos(a) * 21.2), round(cy + math.sin(a) * 21.2), STEEL[0] if k % 2 else STEEL_O)
    c.disc(cx, cy, 19.0, [OLIVE[0], OLIVE[1], OLIVE[1], OLIVE[2]], outline=OLIVE[3], flat=True)
    for y in range(28, 68):
        for x in range(28, 68):
            if math.hypot(x - cx, y - cy) < 17 and (x // 4 + y // 4) % 2 == 0 and (x % 4, y % 4) in ((1, 2), (2, 1)):
                c.put(x, y, OLIVE[0])
    for k in range(12):
        a = math.radians(k * 30 + 15)
        c.rivet(round(cx + math.cos(a) * 17.2), round(cy + math.sin(a) * 17.2), mix(OLIVE[0], WHITE, 0.3), OLIVE[3])
    # curved gun shield ahead of the trunnions
    for k in range(-56, 57):
        a = math.radians(-90 + k)
        for r in (15.0, 16.0, 17.0):
            X, Y = c.wpt(cx + math.cos(a) * r, cy + math.sin(a) * r)
            wx, wy = c.wpt(cx, cy)
            t = 0.5 + ((X - wx) + (Y - wy)) / (r * 2.6)
            col = ramp_at([mix(OLIVE[0], WHITE, 0.25), OLIVE[0], OLIVE[1], OLIVE[2]], t)
            if r == 17.0 or abs(k) > 54:
                col = OLIVE[3]
            c.wput(round(X), round(Y), col)
    # cheeks and trunnions
    c.shade(38, 60, 60, 62, 70)
    for x0 in (35, 55):
        c.bevel(x0, 36, x0 + 5, 59, OLIVE[0], OLIVE[1], OLIVE[2], outline=OLIVE[3])
        for y in (39, 56):
            c.rivet(x0 + 2, y, mix(OLIVE[0], WHITE, 0.3), OLIVE[3])
        c.disc(x0 + 2.5, 47.5, 2.6, [BRASS[0], BRASS[1], BRASS[3]], outline=BRASS[4])
    # cradle and recoil cylinders
    c.shade(43, 22, 56, 64, 80)
    c.bevel(41, 28, 54, 60, GUNM[1], GUNM[3], GUNM[4], outline=DARK)
    for x0 in (41, 52):
        c.cyl(x0, 20, x0 + 2, 46, GUNM, along=True)
        c.rect(x0, 20, x0 + 2, 20, BRASS[1])
        c.rect(x0, 46, x0 + 2, 46, DARK)
    # barrel: breech ring, reinforce, chase, muzzle brake
    c.shade(50, 1, 53, 44, 80)
    c.cyl(43, 46, 52, 62, GUNM, along=True)
    c.cyl(44, 18, 51, 46, GUNM, along=True)
    c.cyl(45, 3, 50, 18, GUNM, along=True)
    c.cyl(44, 0, 51, 4, GUNM, along=True)
    for y in (1, 3):
        c.rect(44, y, 44, y, DARK)
        c.rect(51, y, 51, y, DARK)
        c.rect(46, y, 49, y, GUNM[4], 120)
    for y in (18, 30, 46):
        c.cyl(44, y, 51, y, [GUNM[1], GUNM[2], GUNM[3], GUNM[4], DARK], along=True)
    c.rect(43, 62, 52, 62, DARK)
    # breech block, lever, elevating wheel and layer's seat
    c.bevel(42, 62, 53, 67, GUNM[0], GUNM[2], GUNM[4], outline=DARK)
    c.rect(46, 64, 49, 65, BRASS[1])
    c.put(46, 64, BRASS[0])
    c.line(53, 64, 57, 62, GUNM[0])
    c.put(58, 61, RED[0])
    c.ring(31.5, 52.5, 3.2, BRASS[1])
    c.put(31, 52, BRASS[0])
    c.put(32, 53, BRASS[3])
    c.line(34, 52, 36, 50, GUNM[1])
    c.bevel(28, 57, 34, 63, (150, 96, 60), (112, 68, 42), (78, 46, 28), outline=(40, 22, 14))
    # loading tray with a shell
    c.bevel(44, 68, 51, 72, GUNM[3], GUNM[4], GUNM[1], outline=DARK)
    c.cyl(61, 55, 64, 62, BRASS, along=True)
    c.rect(61, 53, 64, 54, GUNM[3])
    c.put(62, 52, GUNM[2])
    c.put(63, 52, GUNM[4])
    c.shade(65, 54, 65, 63, 70)


def gun_states():
    return {'railway_gun': directions(railway_gun, w=96, h=96, order=HEADING)}


# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Water tower and water crane: 64 x 64, centred on their tile

ROOF_TIN = ((150, 96, 78), (122, 70, 58), (94, 50, 44), (66, 34, 32), (40, 20, 20))


def tower_body():
    """A round stave tank under a conical tin roof, seen from straight above."""
    c = Canvas(64, 64)
    cx = cy = 31.5
    for y in range(64):
        for x in range(64):
            if math.hypot(x - cx - 4, y - cy - 5) <= 25.5:
                c.shade(x, y, x, y, 80)
    # the trestle legs show at the corners
    for x, y in ((9, 9), (51, 9), (9, 51), (51, 51)):
        c.bevel(x, y, x + 3, y + 3, WALNUT[0], WALNUT[1], WALNUT[2], outline=WALNUT[3])
    # tank rim: staves and the top iron band
    for y in range(64):
        for x in range(64):
            d = math.hypot(x - cx, y - cy)
            if d > 25.2:
                continue
            ang = math.atan2(y - cy, x - cx)
            lit = (-math.cos(ang) - math.sin(ang)) / 1.42  # 1 towards the upper left
            if d > 24.0:
                c.put(x, y, DARK)
            elif d > 22.6:
                c.put(x, y, STEEL[1] if lit > 0.3 else (STEEL[3] if lit > -0.4 else STEEL[4]))
            elif d > 20.4:
                stave = int((ang + math.pi) * 14) % 2
                base = TAN[1] if lit > 0.2 else (TAN[2] if lit > -0.5 else TAN[3])
                c.put(x, y, mix(base, TAN[3], 0.35) if stave else base)
            else:
                # the roof: a cone, brighter on the side that faces the light
                tone = ROOF_TIN[0] if lit > 0.6 else (ROOF_TIN[1] if lit > 0.1 else (ROOF_TIN[2] if lit > -0.5 else ROOF_TIN[3]))
                if int(d) % 5 == 4:
                    tone = mix(tone, ROOF_TIN[4], 0.45)
                seam = abs(((ang + math.pi) * 6 / math.pi) % 1.0 - 0.5) > 0.46 and d > 3
                c.put(x, y, mix(tone, ROOF_TIN[4], 0.5) if seam else tone)
    c.ring(cx, cy, 20.6, ROOF_TIN[4], width=1.0)
    c.disc(cx, cy, 2.6, [BRASS[0], BRASS[1], BRASS[3]], outline=BRASS[4])
    c.put(31, 30, WHITE)
    return c


def tower_spout(c):
    """The spout, swung out towards the north of its 64 x 64 tile."""
    c.shade(31, 1, 36, 8, 70)
    c.bevel(29, 0, 34, 9, STEEL[1], STEEL[2], STEEL[4], outline=STEEL_O)
    c.rect(30, 0, 33, 1, DARK)
    c.rect(31, 2, 31, 8, STEEL[0])
    c.line(27, 9, 30, 4, STEEL[3])
    c.line(36, 9, 33, 4, STEEL[3])


def water_crane(c):
    """A standpipe beside the track, its arm swung out to the north."""
    c.shade(28, 30, 40, 40, 70)
    c.bevel(26, 26, 37, 37, STEEL[1], STEEL[3], STEEL[4], outline=STEEL_O)
    for x, y in ((27, 27), (36, 27), (27, 36), (36, 36)):
        c.put(x, y, STEEL[0])
    # the arm, its stay and the leather bag at the end
    c.shade(33, 6, 36, 26, 60)
    c.bevel(30, 5, 33, 28, GREEN[1], GREEN[2], GREEN[3], outline=GREEN[4])
    c.rect(31, 6, 31, 27, GREEN[0])
    c.line(27, 28, 30, 16, STEEL[1])
    c.line(36, 28, 33, 16, STEEL[1])
    c.bevel(29, 0, 34, 6, WALNUT[0], WALNUT[1], WALNUT[2], outline=WALNUT[3])
    c.rect(30, 0, 33, 0, DARK)
    c.rect(29, 3, 34, 3, BRASS[1])
    # the column with its brass cap and valve wheel
    c.disc(31.5, 31.5, 5.2, [GREEN[0], GREEN[1], GREEN[2], GREEN[3]], outline=GREEN[4])
    c.disc(31.5, 31.5, 2.4, [WHITE, BRASS[0], BRASS[1], BRASS[3]], outline=BRASS[4])
    c.disc(38.5, 34.5, 2.6, [RED[0], RED[1], RED[2]], outline=RED[3])
    c.put(38, 34, DARK)


def water_states():
    out = {'water_tower': [], 'water_crane': directions(water_crane, w=64, h=64, order=HEADING)}
    for tf in HEADING:
        tower = tower_body()
        spout = Canvas(64, 64, tf)
        tower_spout(spout)
        im = spout.image()
        im.alpha_composite(tower.image())
        out['water_tower'].append(im)
    out['coal_stage_empty'] = coal_stage(0)
    out['coal_stage'] = coal_stage(1)
    out['coal_stage_full'] = coal_stage(2)
    out['loading_stage_empty'] = loading_stage(None)
    for tone in ('coal', 'ore', 'sand'):
        out['loading_stage_' + tone] = loading_stage(tone)
    out['sand_bin_empty'] = sand_bin(False)
    out['sand_bin'] = sand_bin(True)
    return out


def platform_states():
    states = {}
    for kind in ('wood', 'floor', 'carpet', 'steel', 'boards', 'hopper', 'straw'):
        states['deck_center_' + kind] = deck_center(kind)
        states['deck_side_' + kind] = deck_side(kind)
    for name, draw in EDGES.items():
        states[name] = directions(draw, order=EDGE)
    states['car_kit'] = car_kit()
    states['brace_up'] = lever(False)
    states['brace_down'] = lever(True)
    states['wreck'] = wreck()
    states['derailed'] = derailed()
    states['rerail_jack'] = rerail_jack()
    states['loco_armor'] = directions(loco_armor, order=HEADING)
    states.update(end_states())
    states['outrigger'] = directions(outrigger, order=EDGE)
    states.update(roof_states())
    states.update(loco_states())
    states.update(coupler_states())
    states['coupling_item'] = coupling_item()
    states.update(knuckle_states())
    states['knuckle_item'] = knuckle_item()
    states['ash_pit'] = ash_pit(0)
    states['ash_pit_ash'] = ash_pit(1)
    states['ash_pit_full'] = ash_pit(2)
    states['fire_rake'] = fire_rake()
    states['brake_shoes'] = brake_shoes()
    states['carriage_key'] = carriage_key()
    states['ticket_punch'] = ticket_punch()
    states['ticket_book'] = ticket_book()
    states['ticket'] = ticket(False)
    states['ticket_punched'] = ticket(True)
    states['signal_flags'] = signal_flags()
    states['guard_journal'] = guard_journal()
    states['signal_danger'] = semaphore(False)
    states['signal_clear'] = semaphore(True)
    states['lever_frame'] = lever_frame()
    states['token_instrument'] = token_instrument()
    states['train_token'] = train_token()
    states['section_board'] = section_board()
    states['signal_wire'] = signal_wire()
    states['station_board'] = station_board()
    states['buffer_stop'] = directions(buffer_stop, order=HEADING)
    states['crossing_boards'] = directions(crossing_boards, order=HEADING)
    states['crossing_gate_shut'] = directions(lambda c: crossing_gate(c, True), order=HEADING)
    states['crossing_gate_open'] = directions(lambda c: crossing_gate(c, False), order=HEADING)
    states['turntable_deck'] = directions(turntable_deck, order=HEADING)
    states['turntable_girders'] = directions(turntable_girders, order=HEADING)
    states['turntable_pivot'] = turntable_pivot()
    states['goods_crane'] = goods_crane(False)
    states['goods_crane_haul'] = goods_crane(True)
    states['livestock_ramp'] = directions(livestock_ramp, order=HEADING)
    states['track_worn'] = track_wear(False)
    states['track_bad'] = track_wear(True)
    states['hand_lamp'] = hand_lamp(None)
    states['hand_lamp_white'] = hand_lamp('white')
    states['hand_lamp_red'] = hand_lamp('red')
    states['hand_lamp_green'] = hand_lamp('green')
    states['plough_item'] = plough_item()
    states['tank_valve'] = tank_valve()
    states['ice_bunker'] = cold_chest('bunker', False)
    states['ice_bunker_open'] = cold_chest('bunker', True)
    states['cold_locker'] = cold_chest('locker', False)
    states['cold_locker_open'] = cold_chest('locker', True)
    states['drop_pit'] = drop_pit(None)
    for tone in ('coal', 'ore', 'sand'):
        states['drop_pit_' + tone] = drop_pit(tone)
    states['fusible_plug'] = fusible_plug()
    states['brake_wheel'] = brake_wheel(False)
    states['brake_wheel_on'] = brake_wheel(True)
    return states


# ---------------------------------------------------------------------------
# Review renders

L, R = -1, 1
_vest = [(L, 'out', 'door'), (R, 'out', 'door'), (L, 'front', 'wall'), (0, 'front', 'door'), (R, 'front', 'wall')]
_back = [(L, 'back', 'wall'), (0, 'back', 'door'), (R, 'back', 'wall')]
_win = [(L, 'out', 'window'), (R, 'out', 'window')]
_walls = [(L, 'out', 'wall'), (R, 'out', 'wall')]
_comp = [(L, 'in', 'inner_door'), (R, 'in', 'inner_door'), (L, 'front', 'partition'), (R, 'front', 'partition')]
_rails = [(L, 'out', 'rail'), (R, 'out', 'rail')]
_arm = [(L, 'out', 'armor'), (R, 'out', 'armor')]
_armd = [(L, 'out', 'armor_door'), (R, 'out', 'armor_door'), (L, 'front', 'armor'), (0, 'front', 'armor_door'),
         (R, 'front', 'armor')]
_armb = [(L, 'back', 'armor'), (0, 'back', 'armor_door'), (R, 'back', 'armor')]
_van = [(L, 'out', 'plank'), (R, 'out', 'plank')]
_van_d = [(L, 'out', 'freight_door'), (R, 'out', 'freight_door')]
_van_f = [(L, 'front', 'plank'), (0, 'front', 'plank'), (R, 'front', 'plank')]
_van_b = [(L, 'back', 'plank'), (0, 'back', 'plank'), (R, 'back', 'plank')]
_low = [(L, 'out', 'side'), (R, 'out', 'side')]
_low_d = [(L, 'out', 'drop_door'), (R, 'out', 'drop_door')]
_low_f = [(L, 'front', 'side'), (0, 'front', 'side'), (R, 'front', 'side')]
_low_b = [(L, 'back', 'side'), (0, 'back', 'side'), (R, 'back', 'side')]
_bin = [(L, 'out', 'hopper'), (R, 'out', 'hopper')]
_bin_f = [(L, 'front', 'hopper'), (0, 'front', 'hopper'), (R, 'front', 'hopper')]
_bin_b = [(L, 'back', 'hopper'), (0, 'back', 'hopper'), (R, 'back', 'hopper')]
_slat = [(L, 'out', 'slat'), (R, 'out', 'slat')]
_slat_d = [(L, 'out', 'slat_door'), (R, 'out', 'slat_door')]
_slat_f = [(L, 'front', 'slat'), (0, 'front', 'slat'), (R, 'front', 'slat')]
_slat_b = [(L, 'back', 'slat'), (0, 'back', 'slat'), (R, 'back', 'slat')]
_cold = [(L, 'out', 'cold'), (R, 'out', 'cold')]
_cold_d = [(L, 'out', 'cold_door'), (R, 'out', 'cold_door')]
_cold_f = [(L, 'front', 'cold'), (0, 'front', 'cold'), (R, 'front', 'cold')]
_cold_b = [(L, 'back', 'cold'), (0, 'back', 'cold'), (R, 'back', 'cold')]
_side_d = [(L, 'out', 'door'), (R, 'out', 'door')]
# mirrors train_car_layout() in code/modules/1713/train_platforms.dm
CARS = {
    'flatbed': ('wood', 'wood', [_rails, [], [], _rails], None),
    'coach': ('carpet', 'floor', [_vest, _win, _win, _win + _back], 'coach'),
    'sleeper': ('carpet', 'floor', [_vest, _win + _comp, _win + _comp, _win + _comp + _back], 'coach'),
    'dining': ('floor', 'floor', [_vest, _win, _win, _win + _back], 'coach'),
    'storage': ('steel', 'steel', [_vest, _walls + _comp, _walls + _comp, _walls + _comp + _back], 'steel'),
    'railgun': ('steel', 'steel', [_rails, _rails, _rails, _rails], None),
    'armored': ('steel', 'steel', [_armd, _arm, _arm, _arm + _armb], 'armor'),
    'flak': ('steel', 'steel', [_rails, _rails, _rails, _rails], None),
    'bogie_coach': ('carpet', 'floor', [_vest] + [_win] * 6 + [[(L, 'out', 'door'), (R, 'out', 'door')] + _back], 'coach'),
    'boxcar': ('boards', 'boards', [_van + _van_f, _van, _van, _van_d, _van_d, _van, _van, _van + _van_b], 'boxcar'),
    'open_wagon': ('boards', 'boards', [_low + _low_f, _low, _low, _low_d, _low_d, _low, _low, _low + _low_b], None),
    'long_flatbed': ('wood', 'wood', [_rails, [], [], [], [], [], [], _rails], None),
    'hopper': ('hopper', 'hopper', [_bin + _bin_f, _bin, _bin, _bin, _bin, _bin + _bin_b], None),
    'stock_car': ('straw', 'straw', [_slat + _slat_f, _slat, _slat, _slat_d, _slat_d, _slat, _slat, _slat + _slat_b], 'stock'),
    'ice_car': ('boards', 'boards', [_cold + _cold_f, _cold, _cold, _cold_d, _cold_d, _cold, _cold, _cold + _cold_b], 'reefer'),
    'mail_van': ('boards', 'boards', [_vest, _win, _win, _side_d, _side_d, _walls, _walls, _walls + _back], 'coach'),
    'bogie_sleeper': ('carpet', 'floor', [_vest] + [_win + _comp] * 6
                      + [_side_d + _back + [(L, 'front', 'partition'), (R, 'front', 'partition')]], 'coach'),
    'bogie_dining': ('floor', 'floor', [_vest] + [_win] * 6 + [_side_d + _back], 'coach'),
    'crane_car': ('steel', 'steel', [_rails, [], [], _rails], None),
    'tank_car': ('steel', 'boards', [[], _rails, _rails, _rails, _rails, []], None),
    'brake_van': ('boards', 'boards', [_rails, _win + [(L, 'front', 'plank'), (0, 'front', 'door'), (R, 'front', 'plank')],
                                       _van, _win + [(L, 'back', 'plank'), (0, 'back', 'door'), (R, 'back', 'plank')]],
                  'boxcar'),
}


def tile_pos(heading, seg, col, rows=4):
    return {'N': (col + 1, seg), 'S': (1 - col, rows - 1 - seg),
            'E': (rows - 1 - seg, col + 1), 'W': (seg, 1 - col)}[heading]


def render_car(states, kind, heading, roof=False, open_doors=False, braced=False):
    """One car the way apply_layout() lays its parts out."""
    center, side, segs, roof_kind = CARS[kind]
    rows = len(segs)
    size = (96, rows * 32) if heading in 'NS' else (rows * 32, 96)
    im = Image.new('RGBA', size, (0, 0, 0, 0))
    left, right = LEFT_OF[heading], OPPOSITE[LEFT_OF[heading]]
    for seg in range(rows):
        for col in (L, 0, R):
            x, y = tile_pos(heading, seg, col, rows)
            if col == 0:
                tile = states['deck_center_' + center][DIR_INDEX[heading]]
            else:
                tile = states['deck_side_' + side][DIR_INDEX[left if col == L else right]]
            im.alpha_composite(tile, (x * 32, y * 32))
    for seg, row in ((0, 'f'), (rows - 1, 'b')):
        for col, cn in ((L, 'l'), (0, 'c'), (R, 'r')):
            x, y = tile_pos(heading, seg, col, rows)
            d = heading if col == 0 else (left if col == L else right)
            im.alpha_composite(states['end_' + row + cn][DIR_INDEX[d]], (x * 32, y * 32))
    for seg in range(rows):
        for col, edge, style in segs[seg]:
            if edge == 'front':
                d = heading
            elif edge == 'back':
                d = OPPOSITE[heading]
            elif edge == 'in':
                d = right if col == L else left
            else:
                d = left if col == L else right
            name = 'edge_' + style
            if open_doors and name + '_open' in states and (seg + col) % 2 == 0:
                name += '_open'
            x, y = tile_pos(heading, seg, col, rows)
            im.alpha_composite(states[name][DIR_INDEX[d]], (x * 32, y * 32))
    if roof and roof_kind:
        for seg in range(rows):
            for col, cn in ((L, 'l'), (0, 'c'), (R, 'r')):
                x, y = tile_pos(heading, seg, col, rows)
                row = 'f' if seg == 0 else ('b' if seg == rows - 1 else 'm')
                im.alpha_composite(states['roof_%s_%s%s' % (roof_kind, row, cn)][DIR_INDEX[heading]],
                                   (x * 32, y * 32))
    return im


def render_loco(states, name, heading, roof=True):
    rows, cab = loco_rows(name)
    size = (96, rows * 32) if heading in 'NS' else (rows * 32, 96)
    im = Image.new('RGBA', size, (0, 0, 0, 0))
    for seg in range(rows):
        for col, cn in ((L, 'l'), (0, 'c'), (R, 'r')):
            x, y = tile_pos(heading, seg, col, rows)
            im.alpha_composite(states['loco_%s_%d%s' % (name, seg + 1, cn)][DIR_INDEX[heading]], (x * 32, y * 32))
            if roof and seg == cab:
                im.alpha_composite(states['roof_loco_%s_%s' % (name, cn)][DIR_INDEX[heading]], (x * 32, y * 32))
            if roof and name == 'dieselmain' and seg == rows - 1:
                im.alpha_composite(states['roof_loco_dieselmain_b%s' % cn][DIR_INDEX[heading]], (x * 32, y * 32))
    return im


def ground(w, h, seed=0):
    im = Image.new('RGBA', (w, h))
    for y in range(h):
        for x in range(w):
            n = noise(x, y, 200 + seed)
            m = noise(x // 6, y // 6, 201 + seed)
            base = mix((104, 128, 76), (92, 116, 68), m)
            if n < 0.12:
                base = mix(base, (70, 92, 52), 0.6)
            elif n > 0.9:
                base = mix(base, (140, 156, 96), 0.5)
            im.putpixel((x, y), base + (255,))
    return im


def lay_track(im, y_tile=None, x_tile=None):
    rails = read_dmi(RAILS)['rails']
    if y_tile is not None:
        for x in range(0, im.width, 32):
            im.alpha_composite(rails[DIR_INDEX['E']], (x, y_tile * 32))
    else:
        for y in range(0, im.height, 32):
            im.alpha_composite(rails[DIR_INDEX['N']], (x_tile * 32, y))


def train_east(states, gun, units, pad=1):
    """Units are images heading east; the first is the front (east end)."""
    width = sum(u.width for u in units) + pad * 64
    im = ground(width, 96 + 128)
    lay_track(im, y_tile=3)
    x = width - pad * 32
    for u in units:
        x -= u.width
        im.alpha_composite(u, (x, 64))
    return im


def write_previews(out, states, gun):
    out.mkdir(parents=True, exist_ok=True)

    def big(im, s):
        return im.resize((im.width * s, im.height * s), Image.NEAREST)

    sheet = sheet_image(states, cols=16)
    bg = Image.new('RGBA', sheet.size, (96, 120, 84, 255))
    bg.alpha_composite(sheet)
    big(bg, 3).save(out / 'states.png')

    passenger = train_east(states, gun, [
        render_loco(states, 'steam', 'E'), render_car(states, 'flatbed', 'E'),
        render_car(states, 'coach', 'E', open_doors=True), render_car(states, 'coach', 'E', roof=True)])
    big(passenger, 3).save(out / 'steam-train.png')

    freight = train_east(states, gun, [
        render_loco(states, 'diesel', 'E'), render_car(states, 'sleeper', 'E'),
        render_car(states, 'dining', 'E'), render_car(states, 'storage', 'E', roof=True)])
    big(freight, 3).save(out / 'diesel-train.png')

    gun_car = render_car(states, 'railgun', 'E')
    war = train_east(states, gun, [
        render_loco(states, 'armored', 'E'), render_car(states, 'armored', 'E', roof=True),
        gun_car, render_car(states, 'armored', 'E', open_doors=True)])
    # the gun on segment 2, aimed north, with the outriggers down on segments 1 and 4
    gx = war.width - 32 - 128 * 2 - 128 + 64
    for seg_x in (gx + 32, gx - 64):
        war.alpha_composite(states['outrigger'][DIR_INDEX['N']], (seg_x, 32))
        war.alpha_composite(states['outrigger'][DIR_INDEX['S']], (seg_x, 160))
    war.alpha_composite(states['brace_down'][0], (gx + 32, 64))
    war.alpha_composite(gun['railway_gun'][DIR_INDEX['N']], (gx - 32, 64))
    big(war, 3).save(out / 'war-train.png')

    # every locomotive in all four directions, roofs off and on
    im = ground(3 * (128 + 96 + 96 + 128 + 40) // 1, 2 * 150, seed=3)
    im = ground(6 * 136 + 8, 4 * 136 + 8, seed=3)
    for i, name in enumerate(LOCOS):
        for j, heading in enumerate('NSEW'):
            for k, roof in enumerate((False, True)):
                unit = render_loco(states, name, heading, roof=roof)
                im.alpha_composite(unit, (8 + (i * 2 + k) * 136 + (128 - unit.width) // 2,
                                          8 + j * 136 + (128 - unit.height) // 2))
    big(im, 3).save(out / 'locomotives.png')

    im = ground(4 * 104 + 8, 104 + 8, seed=5)
    for j, heading in enumerate('SNEW'):
        tread_bg = Image.new('RGBA', (96, 96))
        c = Canvas(96, 96)
        tread(c, 0, 0, 95, 95)
        im.alpha_composite(c.image(), (8 + j * 104, 8))
        im.alpha_composite(gun['railway_gun'][DIR_INDEX[heading]], (8 + j * 104, 8))
        del tread_bg
    big(im, 4).save(out / 'railway-gun.png')

    # the bogie stock: two trains heading east, then every car heading north
    # with its roof off and on, and the goods stock facing south and west
    goods = train_east(states, gun, [
        render_loco(states, 'steam', 'E'), render_car(states, 'boxcar', 'E', roof=True),
        render_car(states, 'open_wagon', 'E'), render_car(states, 'long_flatbed', 'E')])
    express = train_east(states, gun, [
        render_loco(states, 'diesel', 'E'), render_car(states, 'bogie_coach', 'E', open_doors=True),
        render_car(states, 'bogie_coach', 'E', roof=True), render_car(states, 'boxcar', 'E', open_doors=True)])
    both = Image.new('RGBA', (max(goods.width, express.width), goods.height + express.height), (96, 120, 84, 255))
    both.alpha_composite(goods, (0, 0))
    both.alpha_composite(express, (0, goods.height))
    big(both, 2).save(out / 'long-stock-trains.png')

    # a water stop: engine and tender under the tower's spout, a crane further on
    water = water_states()
    stop = train_east(states, gun, [render_loco(states, 'steam', 'E'), render_loco(states, 'tender', 'E', roof=False),
                                    render_car(states, 'open_wagon', 'E')], pad=3)
    stop.alpha_composite(water['water_tower'][DIR_INDEX['S']], (stop.width - 96 - 128 - 112, 0))
    stop.alpha_composite(water['water_crane'][DIR_INDEX['N']], (stop.width - 80, 160))
    big(stop, 3).save(out / 'water-stop.png')

    # the main-line engine: with its tender and a coach heading east, then
    # heading north and south with the cab roof off and on
    express = train_east(states, gun, [render_loco(states, 'mainline', 'E', roof=False),
                                       render_loco(states, 'tender', 'E', roof=False),
                                       render_car(states, 'bogie_coach', 'E', roof=True)])
    im = Image.new('RGBA', (express.width, express.height + 208), (96, 120, 84, 255))
    im.alpha_composite(express, (0, 0))
    im.alpha_composite(ground(express.width, 208, seed=11), (0, express.height))
    for i, (heading, roof) in enumerate((('N', False), ('N', True), ('S', False))):
        im.alpha_composite(render_loco(states, 'mainline', heading, roof=roof), (16 + i * 112, express.height + 8))
    cab = render_loco(states, 'mainline', 'N', roof=False).crop((0, 160, 96, 192))
    im.alpha_composite(cab.resize((288, 96), Image.NEAREST), (16 + 3 * 112 + 16, express.height + 56))
    big(im, 3).save(out / 'mainline.png')

    # the main-line diesel: two units in multiple with a coach heading east,
    # then heading north and south with the cab roofs off and on
    pair = train_east(states, gun, [render_loco(states, 'dieselmain', 'E', roof=False),
                                    render_loco(states, 'dieselmain', 'E', roof=True),
                                    render_car(states, 'bogie_coach', 'E', roof=True)])
    im = Image.new('RGBA', (pair.width, pair.height + 208), (96, 120, 84, 255))
    im.alpha_composite(pair, (0, 0))
    im.alpha_composite(ground(pair.width, 208, seed=13), (0, pair.height))
    for i, (heading, roof) in enumerate((('N', False), ('N', True), ('S', False), ('S', True))):
        im.alpha_composite(render_loco(states, 'dieselmain', heading, roof=roof), (16 + i * 112, pair.height + 8))
    cab = render_loco(states, 'dieselmain', 'N', roof=False).crop((0, 0, 96, 32))
    im.alpha_composite(cab.resize((288, 96), Image.NEAREST), (16 + 4 * 112 + 16, pair.height + 56))
    big(im, 3).save(out / 'mainline-diesel.png')

    # the conductor's things
    names = ('guard_journal', 'carriage_key', 'ticket_book', 'ticket', 'ticket_punched', 'ticket_punch', 'signal_flags')
    im = Image.new('RGBA', (8 + len(names) * 40, 48), (96, 120, 84, 255))
    for i, name in enumerate(names):
        im.alpha_composite(states[name][0], (8 + i * 40, 8))
    big(im, 6).save(out / 'conductor.png')

    # signals and single-line working
    names = ('signal_danger', 'signal_clear', 'lever_frame', 'token_instrument', 'train_token', 'section_board', 'signal_wire')
    im = ground(8 + len(names) * 40, 48, seed=17)
    for i, name in enumerate(names):
        im.alpha_composite(states[name][0], (8 + i * 40, 8))
    big(im, 6).save(out / 'signals.png')

    # stations and lamps
    names = ('station_board', 'hand_lamp', 'hand_lamp_white', 'hand_lamp_red', 'hand_lamp_green')
    im = ground(8 + len(names) * 40, 48, seed=23)
    for i, name in enumerate(names):
        im.alpha_composite(states[name][0], (8 + i * 40, 8))
    big(im, 6).save(out / 'stations.png')

    # track works: a line ending at a buffer stop, and a level crossing with
    # its gates open to the road, then shut across it
    rail = read_dmi(RAILS)['rails']
    im = ground(3 * 112 + 16, 5 * 32 + 16, seed=29)
    for y in range(1, 5):
        im.alpha_composite(rail[DIR_INDEX['N']], (40, 8 + y * 32))
    im.alpha_composite(states['buffer_stop'][DIR_INDEX['N']], (40, 8 + 32))
    for k, name in enumerate(('crossing_gate_open', 'crossing_gate_shut')):
        x0 = 112 + k * 112 + 8
        for x in range(3):
            im.alpha_composite(rail[DIR_INDEX['E']], (x0 + x * 32, 8 + 2 * 32))
        im.alpha_composite(states['crossing_boards'][DIR_INDEX['E']], (x0 + 32, 8 + 2 * 32))
        # two tiles from the rails, clear of the sides of wide cars
        im.alpha_composite(states[name][DIR_INDEX['S']], (x0 + 32, 8))
        im.alpha_composite(states[name][DIR_INDEX['N']], (x0 + 32, 8 + 4 * 32))
    big(im, 5).save(out / 'trackworks.png')

    # a small turntable: the bridge lying north and south with a road
    # leading off, then turned a quarter away from it
    pit = turntable_pit(160)[0]
    im = ground(2 * 7 * 32 + 24, 7 * 32 + 16, seed=37)
    for k, heading in enumerate(('N', 'E')):
        x0 = 8 + k * (7 * 32 + 8)
        im.alpha_composite(pit, (x0 + 32, 8))
        for y in range(2):
            im.alpha_composite(rail[DIR_INDEX['N']], (x0 + 3 * 32, 8 + (5 + y) * 32))
        for i in range(5):
            at = (x0 + 3 * 32, 8 + i * 32) if heading == 'N' else (x0 + (1 + i) * 32, 8 + 2 * 32)
            im.alpha_composite(states['turntable_deck'][DIR_INDEX[heading]], at)
            im.alpha_composite(rail[DIR_INDEX[heading]], at)
            im.alpha_composite(states['turntable_girders'][DIR_INDEX[heading]], at)
        im.alpha_composite(states['turntable_pivot'][0], (x0 + 3 * 32, 8 + 2 * 32))
    big(im, 4).save(out / 'turntable.png')

    # track wear: a line in good order, worn, and in a bad way
    im = ground(3 * 48 + 16, 3 * 32 + 16, seed=41)
    for k, name in enumerate((None, 'track_worn', 'track_bad')):
        for y in range(3):
            at = (16 + k * 48, 8 + y * 32)
            im.alpha_composite(rail[DIR_INDEX['N']], at)
            if name:
                im.alpha_composite(states[name][0], at)
    big(im, 6).save(out / 'trackwear.png')

    # off the rails: a derailed boxcar, the same car rerailed, and the jack
    im = ground(2 * 104 + 8 + 56, 8 * 32 + 16, seed=19)
    for i, off in enumerate((True, False)):
        car = render_car(states, 'boxcar', 'N', roof=False)
        if off:
            for seg in range(4):
                car.alpha_composite(states['derailed'][0], (32, seg * 32))
        im.alpha_composite(car, (8 + i * 104, 8))
    im.alpha_composite(states['rerail_jack'][0], (2 * 104 + 16, 24))
    big(im, 3).save(out / 'derailed.png')

    # couplings: made, free, broken and taken off, on a train heading east
    def with_couplers(kind, front, rear, part='coupler'):
        car = render_car(states, kind, 'E')
        car.alpha_composite(states[part + '_f_' + front][DIR_INDEX['E']], (car.width - 32, 32))
        car.alpha_composite(states[part + '_b_' + rear][DIR_INDEX['E']], (0, 32))
        return car
    made = train_east(states, gun, [with_couplers('flatbed', 'free', 'linked'), with_couplers('coach', 'linked', 'linked'),
                                    with_couplers('flatbed', 'linked', 'broken')])
    apart = train_east(states, gun, [with_couplers('flatbed', 'none', 'free')])
    im = Image.new('RGBA', (made.width + apart.width, made.height), (96, 120, 84, 255))
    im.alpha_composite(made, (apart.width, 0))
    im.alpha_composite(apart, (0, 0))
    im.alpha_composite(states['coupling_item'][0], (apart.width - 20, 150))
    big(im, 3).save(out / 'couplings.png')

    # automatic couplers: locked, free and broken, and a spare
    made = train_east(states, gun, [with_couplers('flatbed', 'free', 'linked', 'knuckle'),
                                    with_couplers('coach', 'linked', 'linked', 'knuckle'),
                                    with_couplers('flatbed', 'linked', 'broken', 'knuckle')])
    apart = train_east(states, gun, [with_couplers('flatbed', 'free', 'free', 'knuckle')])
    im = Image.new('RGBA', (made.width + apart.width, made.height), (96, 120, 84, 255))
    im.alpha_composite(made, (apart.width, 0))
    im.alpha_composite(apart, (0, 0))
    im.alpha_composite(states['knuckle_item'][0], (apart.width - 20, 150))
    big(im, 3).save(out / 'automatic-couplers.png')

    # servicing: an engine over an ash pit, the pit empty, in use and full, the rake
    engine = render_loco(states, 'steam', 'E')
    im = ground(engine.width + 7 * 32, 96 + 128, seed=13)
    lay_track(im, y_tile=3)
    for i, name in enumerate(('ash_pit', 'ash_pit_ash', 'ash_pit_full')):
        im.alpha_composite(states[name][DIR_INDEX['E']], (16 + i * 48, 96))
    im.alpha_composite(states['ash_pit_ash'][DIR_INDEX['E']], (16 + 4 * 48 + engine.width - 64, 96))
    im.alpha_composite(engine, (16 + 4 * 48, 64))
    im.alpha_composite(states['fire_rake'][0], (16 + 48, 150))
    big(im, 3).save(out / 'servicing.png')

    # the depot: coaling stage bare, in use and piled high, the sand bin empty
    # and filled, a tender coaling up, and a set of brake shoes
    engine = render_loco(states, 'steam', 'E')
    im = ground(max(5 * 72 + 16, engine.width + 96), 96 + 96 + 80, seed=17)
    lay_track(im, y_tile=5)
    for i, name in enumerate(('coal_stage_empty', 'coal_stage', 'coal_stage_full', 'sand_bin_empty', 'sand_bin')):
        im.alpha_composite(water[name][0], (8 + i * 72, 8))
    im.alpha_composite(states['brake_shoes'][0], (8 + 3 * 72 + 16, 72))
    im.alpha_composite(engine, (16, 128))
    im.alpha_composite(water['coal_stage_full'][0], (16 + 64, 80))
    im.alpha_composite(water['sand_bin'][0], (16 + 160, 80))
    big(im, 3).save(out / 'depot.png')

    # the goods yard: a loading stage empty and filled over an open wagon, the
    # goods crane at rest and hauling, and a livestock ramp against a stock car
    wagon = render_car(states, 'hopper', 'E')
    stock = render_car(states, 'stock_car', 'E')
    im = ground(wagon.width + stock.width + 96, 96 + 96 + 128, seed=23)
    lay_track(im, y_tile=6)
    for i, name in enumerate(('loading_stage_empty', 'loading_stage_coal', 'loading_stage_ore', 'loading_stage_sand')):
        im.alpha_composite(water[name][0], (8 + i * 72, 8))
    im.alpha_composite(states['goods_crane'][0], (8 + 4 * 72 + 16, 24))
    im.alpha_composite(states['goods_crane_haul'][0], (8 + 4 * 72 + 64, 24))
    im.alpha_composite(wagon, (16, 160))
    im.alpha_composite(water['loading_stage_coal'][0], (16 + 64, 96))
    im.alpha_composite(stock, (16 + wagon.width + 32, 160))
    im.alpha_composite(states['livestock_ramp'][DIR_INDEX['N']], (16 + wagon.width + 32 + 128, 256))
    big(im, 3).save(out / 'goods.png')

    # the snowplough: on the front of an engine heading east and north, and
    # the plough standing on the ground
    plough = plough_states()
    engine = render_loco(states, 'steam', 'E')
    engine_n = render_loco(states, 'steam', 'N')
    im = ground(engine.width + engine_n.width + 160, max(engine.height, engine_n.height) + 64, seed=19)
    lay_track(im, y_tile=2)
    im.alpha_composite(engine, (16, 32))
    im.alpha_composite(plough['plough_f'][DIR_INDEX['E']], (16 + engine.width - 64, 32))
    im.alpha_composite(engine_n, (engine.width + 96, 40))
    im.alpha_composite(plough['plough_f'][DIR_INDEX['N']], (engine.width + 96, 8))
    im.alpha_composite(states['plough_item'][0].resize((64, 64), Image.NEAREST), (16, engine.height + 40))
    big(im, 3).save(out / 'snowplough.png')

    # bulk freight: an open wagon of coal, a hopper empty, part loaded with
    # sand and full of ore, and the drop pit empty and with each kind in it
    loads = load_states()

    def loaded(kind, heading, tone=None, fill=2):
        car = render_car(states, kind, heading)
        if not tone:
            return car
        rows = len(CARS[kind][2])
        under = Image.new('RGBA', car.size, (0, 0, 0, 0))
        for seg in range(rows):
            x, y = tile_pos(heading, seg, 0, rows)
            under.alpha_composite(loads['heap_%s_%d' % (tone, fill)][DIR_INDEX[heading]], (x * 32 - 32, y * 32 - 32))
        # the heap lies on the deck, under the car's sides
        base = Image.new('RGBA', car.size, (0, 0, 0, 0))
        center, side, segs, _ = CARS[kind]
        plain = dict(CARS)
        CARS['_bare'] = (center, side, [[] for _ in segs], None)
        base.alpha_composite(render_car(states, '_bare', heading))
        del CARS['_bare']
        base.alpha_composite(under)
        CARS['_sides'] = (center, side, segs, None)
        sides = render_car(states, kind, heading)
        bare = render_car(states, '_sides', heading)
        del CARS['_sides']
        # keep only what the sides add over the bare deck
        deck = Image.new('RGBA', car.size, (0, 0, 0, 0))
        CARS['_bare'] = (center, side, [[] for _ in segs], None)
        deck.alpha_composite(render_car(states, '_bare', heading))
        del CARS['_bare']
        px, dk, bs = sides.load(), deck.load(), base.load()
        for yy in range(car.height):
            for xx in range(car.width):
                if px[xx, yy] != dk[xx, yy]:
                    bs[xx, yy] = px[xx, yy]
        return base
    row = [loaded('open_wagon', 'E', 'coal'), loaded('hopper', 'E'), loaded('hopper', 'E', 'sand', 1), loaded('hopper', 'E', 'ore')]
    im = ground(max(row[0].width + row[1].width, row[2].width + row[3].width) + 48, 2 * 104 + 72, seed=23)
    im.alpha_composite(row[0], (8, 4))
    im.alpha_composite(row[1], (16 + row[0].width, 4))
    im.alpha_composite(row[2], (8, 108))
    im.alpha_composite(row[3], (16 + row[2].width, 108))
    for i, name in enumerate(('drop_pit', 'drop_pit_coal', 'drop_pit_ore', 'drop_pit_sand')):
        x = 16 + i * 64
        im.alpha_composite(read_dmi(RAILS)['rails'][DIR_INDEX['E']], (x, 2 * 104 + 20))
        im.alpha_composite(states[name][DIR_INDEX['E']], (x, 2 * 104 + 20))
    big(im, 3).save(out / 'bulk-freight.png')

    # the tank car heading east and north, with its tank over the middle
    # sections and the valve on the front platform
    def tank_car(heading):
        car = render_car(states, 'tank_car', heading)
        im = Image.new('RGBA', (car.width + 64, car.height + 64), (0, 0, 0, 0))
        im.alpha_composite(car, (32, 32))
        for seg, part in ((1, 'f'), (2, 'd'), (3, 'm'), (4, 'b')):
            x, y = tile_pos(heading, seg, 0, 6)
            im.alpha_composite(loads['tank_' + part][DIR_INDEX[heading]], (x * 32, y * 32))
        x, y = tile_pos(heading, 0, L, 6)
        im.alpha_composite(states['tank_valve'][0], (32 + x * 32, 32 + y * 32))
        # the handrails stand above the barrel
        rails = Image.new('RGBA', car.size, (0, 0, 0, 0))
        CARS['_bare'] = (CARS['tank_car'][0], CARS['tank_car'][1], [[] for _ in range(6)], None)
        bare = render_car(states, '_bare', heading)
        del CARS['_bare']
        px, bp, rp = car.load(), bare.load(), rails.load()
        for yy in range(car.height):
            for xx in range(car.width):
                if px[xx, yy] != bp[xx, yy]:
                    rp[xx, yy] = px[xx, yy]
        im.alpha_composite(rails, (32, 32))
        return im.crop((32, 32, 32 + car.width, 32 + car.height))
    east, north = tank_car('E'), tank_car('N')
    im = ground(east.width + north.width + 40, max(east.height + 24, north.height + 16), seed=31)
    im.alpha_composite(east, (8, 8))
    im.alpha_composite(north, (east.width + 24, 8))
    im.alpha_composite(states['tank_valve'][0].resize((64, 64), Image.NEAREST), (16, east.height + 24))
    big(im, 3).save(out / 'tank-car.png')

    # special stock: the stock car, ice car and mail van heading north, open
    # and roofed, and the ice car's bunker and cold locker shut and open
    kinds = ('stock_car', 'ice_car', 'mail_van')
    im = ground(len(kinds) * 2 * 104 + 8 + 4 * 72, 264 + 16, seed=37)
    for i, kind in enumerate(kinds):
        car = render_car(states, kind, 'N', open_doors=(kind != 'mail_van'))
        if kind == 'ice_car':
            for seg in (0, 1, 2, 5, 6, 7):
                for col in (L, R):
                    x, y = tile_pos('N', seg, col, 8)
                    name = 'ice_bunker' if (seg == 0 and col == L) else 'cold_locker'
                    car.alpha_composite(states[name][0], (x * 32, y * 32))
        im.alpha_composite(car, (8 + i * 208, 12))
        im.alpha_composite(render_car(states, kind, 'N', roof=True), (8 + i * 208 + 104, 12))
    for i, name in enumerate(('ice_bunker', 'ice_bunker_open', 'cold_locker', 'cold_locker_open')):
        im.alpha_composite(states[name][0].resize((64, 64), Image.NEAREST), (len(kinds) * 208 + 8 + i * 72, 24))
    big(im, 3).save(out / 'special-stock.png')

    # the crane car heading east and north, at rest and hauling with its
    # outriggers down
    def crane_car(heading, hauling):
        car = render_car(states, 'crane_car', heading, braced=hauling)
        im = Image.new('RGBA', (car.width + 64, car.height + 64), (0, 0, 0, 0))
        im.alpha_composite(car, (32, 32))
        x, y = tile_pos(heading, 1, 0, 4)
        im.alpha_composite(loads['rail_crane_haul' if hauling else 'rail_crane'][DIR_INDEX[heading]], (x * 32, y * 32))
        x, y = tile_pos(heading, 0, L, 4)
        im.alpha_composite(states['brace_down' if hauling else 'brace_up'][0], (32 + x * 32, 32 + y * 32))
        return im
    parts = [crane_car('E', False), crane_car('E', True), crane_car('N', True)]
    im = ground(parts[0].width + parts[2].width + 16, parts[0].height * 2 + 8, seed=43)
    im.alpha_composite(parts[0], (0, 0))
    im.alpha_composite(parts[1], (0, parts[0].height))
    im.alpha_composite(parts[2], (parts[0].width + 8, 8))
    big(im, 3).save(out / 'crane-car.png')

    im = ground(4 * 104 + 8, 264 + 16, seed=41)
    for i, (kind, roof) in enumerate((('bogie_sleeper', False), ('bogie_sleeper', True), ('bogie_dining', False), ('bogie_dining', True))):
        im.alpha_composite(render_car(states, kind, 'N', roof=roof), (8 + i * 104, 12))
    big(im, 3).save(out / 'long-sleeper-dining.png')

    im = ground(6 * 104 + 8 + 2 * 264, 264 + 16, seed=9)
    for i, (kind, roof) in enumerate((('bogie_coach', False), ('bogie_coach', True), ('boxcar', False),
                                      ('boxcar', True), ('open_wagon', False), ('long_flatbed', False))):
        im.alpha_composite(render_car(states, kind, 'N', roof=roof, open_doors=(i == 2)), (8 + i * 104, 12))
    im.alpha_composite(render_car(states, 'open_wagon', 'W', open_doors=True), (6 * 104 + 8, 24))
    im.alpha_composite(render_car(states, 'boxcar', 'W', roof=True), (6 * 104 + 8, 152))
    im.alpha_composite(render_car(states, 'boxcar', 'S'), (6 * 104 + 8 + 264 + 40, 12))
    im.alpha_composite(render_car(states, 'open_wagon', 'S'), (6 * 104 + 8 + 264 + 144, 12))
    big(im, 3).save(out / 'long-stock-cars.png')

    # the brake van: at the back of a goods train, then with its roof off and
    # the brake wheel in the cabin, wound off and on
    def van(heading, on, roof=False):
        car = render_car(states, 'brake_van', heading, roof=roof)
        if not roof:
            x, y = tile_pos(heading, 2, L)
            car.alpha_composite(states['brake_wheel_on' if on else 'brake_wheel'][0], (x * 32, y * 32))
        return car
    goods = train_east(states, gun, [
        render_loco(states, 'steam', 'E'), render_car(states, 'open_wagon', 'E'), van('E', False, roof=True)])
    im = Image.new('RGBA', (goods.width, goods.height + 2 * 104 + 8), (96, 120, 84, 255))
    im.alpha_composite(goods, (0, 0))
    im.alpha_composite(van('E', False), (16, goods.height + 4))
    im.alpha_composite(van('E', True), (16 + 152, goods.height + 4))
    im.alpha_composite(van('N', True), (16 + 304, goods.height + 4))
    im.alpha_composite(van('E', True, roof=True), (16, goods.height + 108))
    for i, name in enumerate(('brake_wheel', 'brake_wheel_on')):
        im.alpha_composite(states[name][0].resize((96, 96), Image.NEAREST), (16 + 152 + i * 104, goods.height + 108))
    big(im, 3).save(out / 'brake-van.png')

    im = ground(2 * 104 + 8 + 136, 2 * 136 + 8, seed=7)
    for i, (kind, roof) in enumerate((('coach', False), ('coach', True))):
        im.alpha_composite(render_car(states, kind, 'N', roof=roof), (8 + i * 104, 8))
        im.alpha_composite(render_car(states, 'storage' if i else 'flatbed', 'S', roof=roof), (8 + i * 104, 144))
    im.alpha_composite(render_car(states, 'armored', 'W', roof=True), (216, 24))
    im.alpha_composite(render_car(states, 'sleeper', 'W'), (216, 160))
    big(im, 3).save(out / 'cars-other-directions.png')


def same(path, states, size, cols):
    if not path.exists():
        return False
    old = Image.open(path)
    new = sheet_image(states, size=size, cols=cols)
    names = ['state = "%s"' % n for n in states]
    text = old.info.get('Description', '')
    return old.convert('RGBA').tobytes() == new.tobytes() and old.size == new.size and \
        [ln for ln in text.splitlines() if ln.startswith('state = ')] == names


def main(argv):
    states = platform_states()
    gun = gun_states()
    water = water_states()
    plough = plough_states()
    loads = load_states()
    pit = {'pit': turntable_pit(160)}
    pit_large = {'pit': turntable_pit(352)}
    if '--check' in argv:
        bad = [str(p.relative_to(ROOT)) for p, s, size, cols in ((PLATFORMS, states, (32, 32), 16), (GUN, gun, (96, 96), 2),
                                                                 (WATER, water, (64, 64), 4), (PLOUGH, plough, (96, 96), 4), (LOADS, loads, (96, 96), 4),
                                                                 (PIT, pit, (160, 160), 1), (PIT_LARGE, pit_large, (352, 352), 1))
               if not same(p, s, size, cols)]
        if bad:
            print('out of date: ' + ', '.join(bad))
            return 1
        print('train sheets match (%d + %d + %d + %d + %d + 2 states)' % (len(states), len(gun), len(water), len(plough), len(loads)))
        return 0
    write_dmi(PLATFORMS, states, cols=16)
    write_dmi(GUN, gun, size=(96, 96), cols=2)
    write_dmi(WATER, water, size=(64, 64), cols=4)
    write_dmi(PLOUGH, plough, size=(96, 96), cols=4)
    write_dmi(LOADS, loads, size=(96, 96), cols=4)
    write_dmi(PIT, pit, size=(160, 160), cols=1)
    write_dmi(PIT_LARGE, pit_large, size=(352, 352), cols=1)
    print('wrote %d platform states and the railway gun' % len(states))
    if '--preview' in argv:
        write_previews(Path(argv[argv.index('--preview') + 1]), states, gun)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
