#!/usr/bin/env python3
"""Draw the four cobblestone floor states in icons/turf/floors.dmi.

    python3 scripts/draw_cobble_floors.py --repo-root . [--check] [--preview out.png]

Hand-laid pixel art, kept as code so it can be rebuilt and reviewed: every
stone is placed from the COURSES table below and shaded from a five-step grey
ramp. The tile repeats cleanly on all four sides. The running ("vertical")
states are the crosswise ("horizontal") ones turned a quarter, so both read as
the same paving. Only the four cobble frames are rewritten; every other frame
and the DMI description are carried over untouched.
"""
import argparse
import io
import re
from pathlib import Path

from PIL import Image, PngImagePlugin

TILE = 32
FLOORS = Path("icons/turf/floors.dmi")

# One course per row of stones: (course height, first-stone offset, stone widths).
# Heights add up to 32 and so do the widths, which is what makes the tile wrap.
COURSES = (
    (5, 0, (7, 6, 8, 5, 6)),
    (5, 3, (6, 8, 5, 7, 6)),
    (6, 6, (8, 6, 7, 5, 6)),
    (5, 1, (5, 7, 6, 8, 6)),
    (5, 4, (7, 5, 8, 6, 6)),
    (6, 2, (6, 7, 5, 6, 8)),
)
assert sum(c[0] for c in COURSES) == TILE and all(sum(c[2]) == TILE for c in COURSES)

# mortar, shade, three stone bodies, highlight
RAMPS = {
    "light": ((80, 79, 80), (102, 101, 102), ((120, 119, 119), (128, 127, 126), (123, 123, 125)), (146, 145, 144)),
    "dark": ((40, 40, 42), (55, 54, 56), ((70, 69, 70), (77, 76, 76), (73, 73, 76)), (92, 91, 91)),
}
# Which body grey each stone takes, course by course; fixed so rebuilds match.
BODY = (
    (0, 1, 2, 0, 1),
    (2, 0, 1, 2, 0),
    (1, 2, 0, 1, 2),
    (0, 2, 1, 0, 1),
    (1, 0, 2, 1, 0),
    (2, 1, 0, 2, 1),
)
# A few worn flecks per tile: (course, stone, dx, dy) inside the stone body.
FLECKS = ((0, 2, 3, 2), (1, 1, 4, 1), (2, 0, 2, 3), (2, 2, 3, 2), (3, 3, 4, 2),
          (4, 2, 2, 1), (5, 4, 3, 3), (5, 1, 2, 2), (3, 1, 3, 1), (0, 4, 2, 2))


def crosswise(tone):
    mortar, shade, bodies, light = RAMPS[tone]
    tile = Image.new("RGB", (TILE, TILE), mortar)
    px = tile.load()
    top = 0
    for course, (height, offset, widths) in enumerate(COURSES):
        left = offset
        for stone, width in enumerate(widths):
            body = bodies[BODY[course][stone]]
            w, h = width - 1, height - 1  # one pixel of mortar right and below
            for dy in range(h):
                for dx in range(w):
                    corner = dx in (0, w - 1) and dy in (0, h - 1)
                    if corner and (dx, dy) != (0, 0):
                        continue  # rounded: leave mortar showing
                    if corner or dy == 0:
                        colour = light if 0 < dx < w - 1 else body
                    elif dy == h - 1 or dx == w - 1:
                        colour = shade
                    else:
                        colour = body
                    px[(left + dx) % TILE, top + dy] = colour
            for c, s, dx, dy in FLECKS:
                if (c, s) == (course, stone) and 0 < dx < w - 1 and 0 < dy < h - 1:
                    px[(left + dx) % TILE, top + dy] = shade
            left += width
        top += height
    return tile.convert("RGBA")


def tiles():
    out = {}
    for tone, suffix in (("light", ""), ("dark", "_dark")):
        flat = crosswise(tone)
        out["cobble_horizontal" + suffix] = flat
        # Transpose keeps the light on the top-left of each stone.
        out["cobble_vertical" + suffix] = flat.transpose(Image.Transpose.TRANSPOSE)
    return out


def state_index(desc):
    index, found = 0, {}
    for block in re.split(r"(?m)(?=^state = )", desc):
        name = re.match(r'state = "([^"]*)"', block)
        if name is None:
            continue
        dirs = int(re.search(r"dirs = (\d+)", block)[1])
        frames = int(re.search(r"frames = (\d+)", block)[1])
        found.setdefault(name[1], (index, dirs * frames))
        index += dirs * frames
    return found


def rebuild(root):
    with Image.open(root / FLOORS) as source:
        desc = source.info["Description"]
        sheet = source.convert("RGBA")
    index = state_index(desc)
    columns = sheet.width // TILE
    for state, tile in tiles().items():
        slot, count = index[state]
        assert count == 1, state
        sheet.paste(tile, ((slot % columns) * TILE, (slot // columns) * TILE))
    info = PngImagePlugin.PngInfo()
    info.add_text("Description", desc, zip=True)
    buffer = io.BytesIO()
    sheet.save(buffer, "PNG", pnginfo=info, optimize=False, compress_level=9)
    return buffer.getvalue(), sheet


def preview(path):
    art = tiles()
    board = Image.new("RGBA", (4 * (TILE * 3 + 8) + 8, TILE * 3 + 16), (24, 24, 28, 255))
    for i, state in enumerate(art):
        for y in range(3):
            for x in range(3):
                board.paste(art[state], (8 + i * (TILE * 3 + 8) + x * TILE, 8 + y * TILE))
    board.resize((board.width * 3, board.height * 3), Image.Resampling.NEAREST).save(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, required=True)
    parser.add_argument("--preview", type=Path)
    parser.add_argument("--check", action="store_true", help="Refuse if the committed frames differ")
    args = parser.parse_args()
    binary, sheet = rebuild(args.repo_root)
    if args.check:
        with Image.open(args.repo_root / FLOORS) as committed:
            assert committed.convert("RGBA").tobytes() == sheet.tobytes(), "committed cobble frames are stale"
    else:
        (args.repo_root / FLOORS).write_bytes(binary)
    if args.preview:
        preview(args.preview)
    print("4 cobblestone floor states drawn")


if __name__ == "__main__":
    main()
