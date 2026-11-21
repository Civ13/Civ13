#!/usr/bin/env python3
"""Draw the iron plate and iron grating floors (icons/turf/flooring/iron.dmi).

    python3 scripts/draw_iron_floors.py [--output path] [--check] [--preview out.png]

Pixel art kept as code. The plate is four riveted wrought-iron sheets with a
warm, slightly uneven surface so it does not read as the cool modern steel
tile. The grating is flat bars over a dark drain, with cross ties at the tile
edges so a run of gratings reads as one grid. Both repeat on all four sides.
"""
import argparse
import os
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, os.environ.get("CIV13_DMI_TOOLS", str(ROOT / "tools")))
import dmi  # noqa: E402

SIZE = 32
OUTPUT = ROOT / "icons/turf/flooring/iron.dmi"
STATES = ("iron_plate", "iron_grating")

SEAM, RIM_DARK, RIM_LIGHT = (38, 35, 34), (62, 57, 54), (104, 97, 91)
PLATE = ((84, 78, 74), (89, 83, 78), (80, 75, 72), (86, 80, 77))
RIVET_LIGHT, RIVET_DARK = (124, 116, 108), (48, 44, 42)
# Hammer marks: (x, y, length) of one-pixel-high dull strokes inside a sheet.
MARKS = ((4, 5, 3), (9, 10, 2), (5, 12, 2), (11, 4, 2))

PIT, PIT_DEEP = (20, 20, 22), (12, 12, 14)
BAR_TOP, BAR_SHADE, TIE = (112, 105, 98), (66, 61, 58), (80, 75, 70)


def plate():
    out = Image.new("RGB", (SIZE, SIZE), SEAM)
    px = out.load()
    for sheet in range(4):
        ox, oy = (sheet % 2) * 16, (sheet // 2) * 16
        body = PLATE[sheet]
        for y in range(15):
            for x in range(15):
                if x == 0 or y == 0:
                    colour = RIM_LIGHT
                elif x == 14 or y == 14:
                    colour = RIM_DARK
                else:
                    colour = body
                px[ox + x, oy + y] = colour
        for x, y, length in MARKS:
            for step in range(length):
                px[ox + (x + sheet * 2 + step) % 11 + 2, oy + (y + sheet * 3) % 9 + 3] = RIM_DARK
        for rx, ry in ((2, 2), (11, 2), (2, 11), (11, 11)):
            px[ox + rx, oy + ry] = RIVET_LIGHT
            px[ox + rx + 1, oy + ry] = RIVET_LIGHT
            px[ox + rx, oy + ry + 1] = RIVET_LIGHT
            px[ox + rx + 1, oy + ry + 1] = RIVET_DARK
    return out.convert("RGBA")


def grating():
    out = Image.new("RGB", (SIZE, SIZE), PIT)
    px = out.load()
    for y in range(SIZE):
        for x in range(SIZE):
            if (x + y) % 7 == 0:
                px[x, y] = PIT_DEEP  # a little depth in the drain below
    # Flat bars running across: two pixels of iron, two of open drain.
    for top in range(1, SIZE, 4):
        for x in range(SIZE):
            px[x, top] = BAR_TOP
            px[x, top + 1] = BAR_SHADE
    # Cross ties under the bars, at the tile edge and the middle.
    for left in (0, 16):
        for y in range(SIZE):
            if y % 4 in (1, 2):
                continue  # the bar sits on top here
            px[left, y] = TIE
            px[left + 1, y] = BAR_SHADE
    return out.convert("RGBA")


def build():
    art = dmi.Dmi(SIZE, SIZE)
    art.state(STATES[0]).frame(plate())
    art.state(STATES[1]).frame(grating())
    return art


def preview(path):
    tiles = (plate(), grating())
    board = Image.new("RGBA", (2 * (SIZE * 3 + 8) + 8, SIZE * 3 + 16), (24, 24, 28, 255))
    for i, tile in enumerate(tiles):
        for y in range(3):
            for x in range(3):
                board.paste(tile, (8 + i * (SIZE * 3 + 8) + x * SIZE, 8 + y * SIZE))
    board.resize((board.width * 4, board.height * 4), Image.Resampling.NEAREST).save(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--preview", type=Path)
    parser.add_argument("--check", action="store_true", help="Refuse if the committed frames differ")
    args = parser.parse_args()
    if args.check:
        committed = dmi.Dmi.from_file(args.output)
        for state, tile in zip(STATES, (plate(), grating())):
            frame = committed.get_state(state).get_frame().convert("RGBA")
            assert frame.tobytes() == tile.tobytes(), f"{state} is stale"
    else:
        build().to_file(args.output)
    if args.preview:
        preview(args.preview)
    print("2 iron floor states drawn")


if __name__ == "__main__":
    main()
