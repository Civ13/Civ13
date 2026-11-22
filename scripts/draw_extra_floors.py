#!/usr/bin/env python3
"""Draw the flagstone, metal, glass, rush, obsidian and tread plate floors and the pelt rugs.

    python3 scripts/draw_extra_floors.py [--check] [--preview out.png]

Pixel art kept as code so it can be rebuilt and reviewed. Every floor tile
repeats on all four sides. Nothing here is random: stones are laid from the
FLAGS table, and the small surface marks come from fixed arithmetic patterns.

- icons/turf/flooring/extra_floors.dmi: flagstone, copper_plate, bronze_plate,
  lead_sheet, glass_block, rush_matting, obsidian_tile, steel_tread
- icons/obj/pelt_rugs.dmi: one spread hide per pelt, on a clear background
"""
import argparse
import os
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, os.environ.get("CIV13_DMI_TOOLS", str(ROOT / "tools")))
import dmi  # noqa: E402

SIZE = 32
FLOOR_SHEET = ROOT / "icons/turf/flooring/extra_floors.dmi"
RUG_SHEET = ROOT / "icons/obj/pelt_rugs.dmi"


def blank(colour):
    tile = Image.new("RGB", (SIZE, SIZE), colour)
    return tile, tile.load()


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


# ---------------------------------------------------------------- flagstone
# Centre of each flag and which body tone it takes. A pixel belongs to the
# nearest centre measured round the tile edges, which is what makes it wrap.
FLAGS = ((6, 5, 0), (22, 4, 1), (13, 15, 2), (29, 16, 0), (5, 25, 1), (20, 26, 2))
FLAG_MORTAR, FLAG_SHADE, FLAG_LIGHT = (58, 54, 48), (104, 98, 88), (160, 153, 139)
FLAG_BODY = ((133, 127, 115), (141, 134, 120), (126, 121, 112))


def flag_at(x, y):
    """Index of the nearest flag and how much nearer it is than the runner-up."""
    ranked = []
    for index, (cx, cy, _) in enumerate(FLAGS):
        dx = min(abs(x - cx), SIZE - abs(x - cx))
        dy = min(abs(y - cy), SIZE - abs(y - cy))
        # Squarish stones: mostly the longer side, a little of the shorter.
        ranked.append((max(dx, dy * 1.25) * 3 + min(dx, dy), index))
    ranked.sort()
    return ranked[0][1], ranked[1][0] - ranked[0][0]


def flagstone():
    tile, px = blank(FLAG_MORTAR)
    owner = [[flag_at(x, y) for x in range(SIZE)] for y in range(SIZE)]

    def stone(x, y):
        index, gap = owner[y % SIZE][x % SIZE]
        return index if gap > 2 else None

    for y in range(SIZE):
        for x in range(SIZE):
            index = stone(x, y)
            if index is None:
                continue
            body = FLAG_BODY[FLAGS[index][2]]
            if stone(x - 1, y) != index or stone(x, y - 1) != index:
                colour = FLAG_LIGHT
            elif stone(x + 1, y) != index or stone(x, y + 1) != index:
                colour = FLAG_SHADE
            elif (x * 5 + y * 11 + index * 3) % 29 == 0:
                colour = FLAG_SHADE  # a worn pit
            else:
                colour = body
            px[x, y] = colour
    return tile.convert("RGBA")


# ------------------------------------------------------------ copper, bronze
COPPER = {"seam": (74, 40, 26), "dark": (128, 70, 44), "body": ((176, 104, 62), (184, 111, 66)),
          "light": (214, 146, 96), "dent": (160, 92, 55)}
BRONZE = {"seam": (56, 42, 20), "dark": (104, 78, 36), "body": ((146, 112, 54), (152, 118, 58)),
          "light": (196, 164, 96), "dent": (128, 97, 46)}


def copper_plate():
    """One hammered sheet to a tile, lapped and nailed along its top and left edge."""
    c = COPPER
    tile, px = blank(c["seam"])
    for y in range(1, SIZE):
        for x in range(1, SIZE):
            if y == 1 or x == 1:
                colour = c["light"]
            elif y == SIZE - 1 or x == SIZE - 1:
                colour = c["dark"]
            else:
                # Planishing: rows of round hammer dents, each lit on its lower lip.
                cx, cy = (x + (y // 6 % 2) * 3) % 6, y % 6
                colour = c["body"][(x // 11 + y // 13) % 2]
                if (cx, cy) in ((2, 2), (3, 2), (2, 3)):
                    colour = c["dent"]
                elif (cx, cy) == (3, 3):
                    colour = c["light"]
            px[x, y] = colour
    for step in range(5, SIZE, 9):
        for nx, ny in ((step, 3), (3, step)):
            px[nx, ny] = c["light"]
            px[nx + 1, ny] = c["seam"]
            px[nx, ny + 1] = c["seam"]
    return tile.convert("RGBA")


def bronze_plate():
    """Cast square tiles with a raised rim and a small boss in the middle."""
    c = BRONZE
    tile, px = blank(c["seam"])
    for index in range(4):
        ox, oy = (index % 2) * 16, (index // 2) * 16
        body = c["body"][(index % 2 + index // 2) % 2]
        for y in range(15):
            for x in range(15):
                edge = min(x, y, 14 - x, 14 - y)
                if edge == 0:
                    colour = c["light"] if (x == 0 or y == 0) else c["dark"]
                elif edge == 1:
                    colour = body
                elif edge == 2:
                    colour = c["dark"] if (x == 2 or y == 2) else c["light"]  # sunk panel
                else:
                    colour = body if (x + y) % 5 else c["dent"]
                px[ox + x, oy + y] = colour
        # Boss: a lit diamond.
        for dx, dy, colour in ((0, -1, c["light"]), (-1, 0, c["light"]), (0, 0, c["light"]),
                               (1, 0, c["dark"]), (0, 1, c["dark"])):
            px[ox + 7 + dx, oy + 7 + dy] = colour
    return tile.convert("RGBA")


# --------------------------------------------------------------------- lead
LEAD_BODY, LEAD_DULL, LEAD_ROLL, LEAD_SHADE, LEAD_DARK = (
    (104, 108, 116), (97, 101, 109), (140, 144, 152), (72, 75, 83), (52, 54, 61))


def lead_sheet():
    """Soft sheets dressed over wooden rolls: a raised rounded seam every half tile."""
    tile, px = blank(LEAD_BODY)
    for y in range(SIZE):
        for x in range(SIZE):
            # Slow dull blotches where the sheet has been walked flat.
            if ((x // 3) * 7 + (y // 2) * 5) % 11 < 3:
                px[x, y] = LEAD_DULL
    for left in (7, 23):
        for y in range(SIZE):
            px[left - 1, y] = LEAD_SHADE
            px[left, y] = LEAD_ROLL
            px[left + 1, y] = LEAD_BODY
            px[left + 2, y] = LEAD_SHADE
            px[left + 3, y] = LEAD_DARK
    # The sheets lap across the rolls once per tile.
    for lap, start in ((12, 9), (27, 25), (27, 0)):
        end = {9: 23, 25: 32, 0: 6}[start]
        for x in range(start, end):
            px[x, lap] = LEAD_SHADE
            px[x, (lap + 1) % SIZE] = LEAD_ROLL
    return tile.convert("RGBA")


# -------------------------------------------------------------------- glass
GLASS_FRAME, GLASS_EDGE, GLASS_BODY, GLASS_CORE, GLASS_GLINT = (
    (38, 52, 54), (84, 128, 126), (118, 168, 162), (146, 194, 186), (214, 240, 234))


def glass_block():
    """Thick cast blocks set in a dark frame, lit from the top left."""
    tile, px = blank(GLASS_FRAME)
    for index in range(4):
        ox, oy = (index % 2) * 16, (index // 2) * 16
        for y in range(15):
            for x in range(15):
                edge = min(x, y, 14 - x, 14 - y)
                if edge == 0:
                    colour = GLASS_EDGE
                elif edge <= 2:
                    colour = GLASS_BODY
                else:
                    colour = GLASS_CORE if (x + y) < 16 else GLASS_BODY
                px[ox + x, oy + y] = colour
        # A broken glint across the top-left shoulder and a faint one below.
        for step in range(5):
            px[ox + 2 + step, oy + 6 - step] = GLASS_GLINT
        for step in range(3):
            px[ox + 9 + step, oy + 12 - step] = GLASS_CORE
        px[ox + 3, oy + 3] = GLASS_GLINT
    return tile.convert("RGBA")


# --------------------------------------------------------------------- rush
RUSH_GAP, RUSH_DARK, RUSH_MID, RUSH_LIGHT, RUSH_GREEN = (
    (66, 58, 30), (122, 110, 56), (156, 144, 78), (188, 176, 104), (134, 138, 70))


def rush_matting():
    """Plaited rushes: bands four stems wide passing over and under each other."""
    tile, px = blank(RUSH_GAP)
    for y in range(SIZE):
        for x in range(SIZE):
            bx, by = x // 8, y // 8
            across = (bx + by) % 2 == 0  # this square shows the band running across
            along, over = (x, y) if across else (y, x)
            stem = over % 8
            if stem == 7:
                continue  # the gap between bands
            colour = (RUSH_LIGHT, RUSH_MID, RUSH_MID, RUSH_DARK)[stem % 2 * 2 + (stem // 2) % 2] \
                if stem % 2 == 0 else RUSH_MID
            if stem in (1, 5):
                colour = RUSH_LIGHT
            if stem in (2, 6):
                colour = RUSH_DARK
            # A few greener stems so it reads as cut rushes, not straw board.
            if (over // 8 * 3 + stem) % 7 == 3:
                colour = RUSH_GREEN
            # The band dips under its neighbour at both ends of the square.
            if along % 8 in (0, 7):
                colour = mix(colour, RUSH_GAP, 0.55)
            px[x, y] = colour
    return tile.convert("RGBA")


# ----------------------------------------------------------------- obsidian
OBS_GROUT, OBS_BODY, OBS_DEEP, OBS_SHEEN, OBS_GLINT, OBS_EDGE = (
    (8, 8, 10), (30, 27, 38), (21, 19, 27), (74, 68, 96), (156, 148, 190), (56, 51, 70))


def obsidian_tile():
    """Knapped and polished volcanic glass: black tiles with curved flake scars."""
    tile, px = blank(OBS_GROUT)
    # Flake scars as short arcs: (x, y, radius, first step, steps) per tile corner.
    scars = (((3, 12, 9, 0, 6), (9, 4, 5, 2, 4)), ((12, 3, 8, 3, 6), (4, 9, 4, 0, 3)),
             ((11, 13, 9, 2, 6), (5, 5, 4, 1, 3)), ((2, 3, 7, 4, 5), (10, 10, 4, 0, 3)))
    arc = ((0, 0), (1, -1), (2, -1), (3, -2), (4, -2), (5, -2), (6, -1), (7, -1), (8, 0), (9, 1))
    for index in range(4):
        ox, oy = (index % 2) * 16, (index // 2) * 16
        for y in range(15):
            for x in range(15):
                if x == 0 or y == 0:
                    colour = OBS_EDGE
                elif x == 14 or y == 14:
                    colour = OBS_DEEP
                else:
                    colour = OBS_BODY if (x * 3 + y * 5 + index) % 9 else OBS_DEEP
                px[ox + x, oy + y] = colour
        for sx, sy, _, first, steps in scars[index]:
            for step in range(first, first + steps):
                dx, dy = arc[step]
                x, y = sx + dx - first, sy + dy
                if 0 < x < 14 and 0 < y < 14:
                    px[ox + x, oy + y] = OBS_GLINT if step == first + steps // 2 else OBS_SHEEN
    return tile.convert("RGBA")


# -------------------------------------------------------------------- tread
TREAD_BODY, TREAD_DULL, TREAD_LIGHT, TREAD_SHADE, TREAD_SEAM = (
    (112, 117, 124), (104, 109, 116), (172, 178, 186), (70, 74, 81), (48, 51, 57))


def steel_tread():
    """Rolled steel with raised lozenges set crosswise to each other."""
    tile, px = blank(TREAD_BODY)
    for y in range(SIZE):
        for x in range(SIZE):
            if (x * 3 + y * 7) % 13 == 0:
                px[x, y] = TREAD_DULL
    for gy in range(4):
        for gx in range(4):
            ox, oy = gx * 8, gy * 8
            rising = (gx + gy) % 2 == 0
            for step in range(5):
                x = ox + 2 + step
                y = oy + (5 - step if rising else 1 + step)
                px[x % SIZE, y % SIZE] = TREAD_LIGHT
                px[x % SIZE, (y + 1) % SIZE] = TREAD_SHADE
    return tile.convert("RGBA")


FLOORS = (("flagstone", flagstone), ("copper_plate", copper_plate), ("bronze_plate", bronze_plate),
          ("lead_sheet", lead_sheet), ("glass_block", glass_block), ("rush_matting", rush_matting),
          ("obsidian_tile", obsidian_tile), ("steel_tread", steel_tread))

# --------------------------------------------------------------------- rugs
# outline, shadow fur, body fur, light fur, underside showing at the edge
PELTS = {
    "bear_brown": ((48, 30, 18), (86, 56, 34), (112, 76, 46), (140, 100, 62), (176, 150, 112)),
    "bear_black": ((12, 12, 14), (30, 29, 32), (44, 42, 46), (64, 61, 66), (120, 110, 98)),
    "bear_white": ((126, 122, 110), (196, 192, 178), (224, 221, 208), (244, 242, 234), (190, 176, 150)),
    "wolf": ((44, 42, 40), (88, 84, 78), (118, 113, 104), (150, 145, 134), (176, 160, 134)),
    "wolf_white": ((120, 118, 112), (190, 188, 180), (216, 214, 206), (240, 239, 234), (188, 176, 154)),
}
# Half outlines (right side, mirrored): the hide lies head up, legs spread.
BEAR_HALF = ((0, 2), (2, 2), (3, 0), (5, 1), (4, 4), (5, 7), (9, 5), (13, 4), (15, 7), (12, 10), (8, 11),
             (9, 15), (9, 19), (12, 21), (15, 24), (14, 28), (10, 27), (7, 24), (4, 27), (2, 29), (0, 30))
WOLF_HALF = ((0, 1), (2, 2), (3, 0), (4, 2), (3, 5), (4, 8), (8, 7), (12, 5), (13, 8), (9, 11), (6, 12),
             (7, 16), (7, 20), (10, 23), (12, 27), (10, 28), (7, 25), (4, 24), (2, 27), (1, 31), (0, 31))


def pelt_rug(name):
    outline, shadow, body, light, hide = PELTS[name]
    half = WOLF_HALF if name.startswith("wolf") else BEAR_HALF
    points = [(16 + x, y) for x, y in half] + [(15 - x, y) for x, y in reversed(half)]
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).polygon(points, fill=255)
    inside = mask.load()
    tile = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    px = tile.load()

    def filled(x, y):
        return 0 <= x < SIZE and 0 <= y < SIZE and inside[x, y] > 0

    for y in range(SIZE):
        for x in range(SIZE):
            if not filled(x, y):
                continue
            depth = min(sum(1 for d in range(1, 4) if filled(x + sx * d, y + sy * d))
                        for sx, sy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if depth == 0:
                colour = outline
            elif depth == 1:
                # The trimmed edge shows pale hide here and there.
                colour = hide if (x * 7 + y * 3) % 5 == 0 else shadow
            else:
                # Fur lies away from the spine: short strokes that lean outward.
                lean = (x + (y if x < 16 else -y)) % 4
                colour = (body, light, body, shadow)[lean]
                if abs(x - 15.5) < 1 and 6 < y < 24:
                    colour = shadow  # the spine
            px[x, y] = colour + (255,)
    # Ears and nose so the head reads at a glance.
    for ex in (13, 18):
        if filled(ex, 1):
            px[ex, 1] = shadow + (255,)
    px[15, 3] = px[16, 3] = outline + (255,)
    return tile


RUGS = tuple(PELTS)


def floor_tiles():
    return {name: draw() for name, draw in FLOORS}


def rug_tiles():
    return {name: pelt_rug(name) for name in RUGS}


def build(tiles):
    art = dmi.Dmi(SIZE, SIZE)
    for name, tile in tiles.items():
        art.state(name).frame(tile)
    return art


def check(path, tiles):
    committed = dmi.Dmi.from_file(path)
    for name, tile in tiles.items():
        frame = committed.get_state(name).get_frame().convert("RGBA")
        assert frame.tobytes() == tile.tobytes(), f"{name} is stale"


def preview(path):
    floors, rugs = floor_tiles(), rug_tiles()
    cell = SIZE * 3 + 8
    board = Image.new("RGBA", (len(floors) * cell + 8, cell * 2 + 8), (24, 24, 28, 255))
    for i, tile in enumerate(floors.values()):
        for y in range(3):
            for x in range(3):
                board.paste(tile, (8 + i * cell + x * SIZE, 8 + y * SIZE))
    under = floors["flagstone"]
    for i, tile in enumerate(rugs.values()):
        for y in range(3):
            for x in range(3):
                board.paste(under, (8 + i * cell + x * SIZE, 8 + cell + y * SIZE))
        board.alpha_composite(tile, (8 + i * cell + SIZE, 8 + cell + SIZE))
    board.resize((board.width * 3, board.height * 3), Image.Resampling.NEAREST).save(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview", type=Path)
    parser.add_argument("--check", action="store_true", help="Refuse if the committed frames differ")
    args = parser.parse_args()
    if args.check:
        check(FLOOR_SHEET, floor_tiles())
        check(RUG_SHEET, rug_tiles())
    else:
        build(floor_tiles()).to_file(FLOOR_SHEET)
        build(rug_tiles()).to_file(RUG_SHEET)
    if args.preview:
        preview(args.preview)
    print(f"{len(FLOORS)} floor states and {len(RUGS)} pelt rugs drawn")


if __name__ == "__main__":
    main()
