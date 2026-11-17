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


SURFACES = {
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


EDGES = {
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


def roof_boxcar(c):
    """A boxcar's sheeted roof in freight oxide: seams across, a running
    board down the middle, grab irons at the front and the brake wheel aft."""
    prof = [(58, 24, 22), (122, 52, 40), (166, 78, 54), (184, 92, 62), (164, 76, 52),
            (140, 60, 44), (114, 46, 38), (86, 34, 30), (52, 20, 20)]
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
    c.frame(0, 0, 95, 95, OXIDE[3])
    for x in (1, 94):
        c.rect(x, 1, x, 94, OXIDE[2])
    c.rect(2, 1, 2, 94, mix(OXIDE[0], WHITE, 0.3), 120)
    for y in (1, 94):
        c.rect(1, y, 94, y, OXIDE[2])
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


ROOFS = {'coach': roof_coach, 'steel': roof_steel, 'armor': roof_armor, 'boxcar': roof_boxcar}


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
LOCO_ROWS = {'mainline': (6, 5), 'diesel': (4, 0)}


def loco_rows(name):
    return LOCO_ROWS.get(name, (4, 2))


def loco_states():
    out = {}
    for name, (body, roof) in list(LOCOS.items()) + [('tender', (loco_tender, None)),
                                                     ('mainline', (loco_mainline, roof_loco_steam))]:
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
    return out


def platform_states():
    states = {}
    for kind in ('wood', 'floor', 'carpet', 'steel', 'boards'):
        states['deck_center_' + kind] = deck_center(kind)
        states['deck_side_' + kind] = deck_side(kind)
    for name, draw in EDGES.items():
        states[name] = directions(draw, order=EDGE)
    states['car_kit'] = car_kit()
    states['brace_up'] = lever(False)
    states['brace_down'] = lever(True)
    states['wreck'] = wreck()
    states['loco_armor'] = directions(loco_armor, order=HEADING)
    states.update(end_states())
    states['outrigger'] = directions(outrigger, order=EDGE)
    states.update(roof_states())
    states.update(loco_states())
    states.update(coupler_states())
    states['coupling_item'] = coupling_item()
    states.update(knuckle_states())
    states['knuckle_item'] = knuckle_item()
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
    if '--check' in argv:
        bad = [str(p.relative_to(ROOT)) for p, s, size, cols in ((PLATFORMS, states, (32, 32), 16), (GUN, gun, (96, 96), 2),
                                                                 (WATER, water, (64, 64), 4))
               if not same(p, s, size, cols)]
        if bad:
            print('out of date: ' + ', '.join(bad))
            return 1
        print('train sheets match (%d + %d + %d states)' % (len(states), len(gun), len(water)))
        return 0
    write_dmi(PLATFORMS, states, cols=16)
    write_dmi(GUN, gun, size=(96, 96), cols=2)
    write_dmi(WATER, water, size=(64, 64), cols=4)
    print('wrote %d platform states and the railway gun' % len(states))
    if '--preview' in argv:
        write_previews(Path(argv[argv.index('--preview') + 1]), states, gun)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
