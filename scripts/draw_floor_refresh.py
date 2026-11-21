#!/usr/bin/env python3
"""Redraw the weakest stone floors and bring the wood patterns into one palette.

    python3 scripts/draw_floor_refresh.py --repo-root . [--check] [--preview out.png]

Pixel work kept as code so it can be rebuilt and reviewed:

- mossy old stone: worn flags laid from the SLABS table, moss grown along chosen joints
- marble floor: a veined slab whose veins leave and re-enter at the same points
- raw pink marble 0-2: three slabs that share their edge crossings, so any of
  them can sit beside any other without a visible break
- dark tatami: the ordinary mat, actually darker
- wood patterns 1, 7 and 8: the existing drawings moved onto the warm brown
  hues the other wood floors use

Run it once against the stock art: the wood and tatami steps recolour what is
in the sheet. Only the named frames are rewritten.
"""
import argparse
import colorsys
import io
import re
from pathlib import Path

from PIL import Image, PngImagePlugin

TILE = 32
FLOORS = Path("icons/turf/floors.dmi")
WOOD = Path("icons/turf/flooring/wood.dmi")

# x, y, width, height; together they cover the tile exactly.
SLABS = (
    (0, 0, 12, 10), (12, 0, 20, 6), (12, 6, 10, 10), (22, 6, 10, 10), (0, 10, 12, 6),
    (0, 16, 8, 16), (8, 16, 14, 8), (22, 16, 10, 8), (8, 24, 10, 8), (18, 24, 14, 8),
)
OLD_STONE = ((27, 29, 25), (39, 41, 37), ((51, 53, 48), (57, 58, 53), (47, 49, 46)), (69, 70, 64))
MOSS = ((41, 63, 30), (54, 81, 35), (69, 99, 42))
# Joints the moss follows: (x, y, length, "h" or "v").
MOSSY_JOINTS = ((0, 9, 9, "h"), (11, 2, 7, "v"), (14, 15, 12, "h"), (21, 18, 6, "v"),
                (7, 22, 8, "v"), (20, 23, 10, "h"), (17, 26, 5, "v"), (26, 5, 6, "h"))


def old_stone():
    mortar, shade, bodies, light = OLD_STONE
    tile = Image.new("RGB", (TILE, TILE), mortar)
    px = tile.load()
    for index, (x, y, width, height) in enumerate(SLABS):
        body = bodies[index % 3]
        w, h = width - 1, height - 1
        for dy in range(h):
            for dx in range(w):
                if dy == 0 and 0 < dx < w - 1:
                    colour = light
                elif dy == h - 1 or dx == w - 1:
                    colour = shade
                else:
                    colour = body
                px[x + dx, y + dy] = colour
        # One hairline crack on every third slab.
        if index % 3 == 1:
            for step in range(min(w, h) - 3):
                px[x + 2 + step, y + 2 + (step * 2) // 3] = shade
    for x, y, length, way in MOSSY_JOINTS:
        for step in range(length):
            jx, jy = ((x + step) % TILE, y) if way == "h" else (x, (y + step) % TILE)
            px[jx, jy] = MOSS[1]
            # Creep onto the slab on alternating sides, thicker mid-run.
            side = 1 if step % 3 else -1
            if 0 < step < length - 1:
                cx, cy = (jx, (jy + side) % TILE) if way == "h" else ((jx + side) % TILE, jy)
                px[cx, cy] = MOSS[0] if step % 2 else MOSS[2]
    return tile.convert("RGBA")


def line(px, points, colour, wrap=True):
    """Plain integer line through the points; wraps so veins cross tile edges."""
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        steps = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(steps + 1):
            x = x0 + (x1 - x0) * i // steps
            y = y0 + (y1 - y0) * i // steps
            if wrap:
                px[x % TILE, y % TILE] = colour
            elif 0 <= x < TILE and 0 <= y < TILE:
                px[x, y] = colour


def white_marble():
    base, soft, vein = (240, 235, 232), (229, 224, 222), (212, 207, 207)
    tile = Image.new("RGB", (TILE, TILE), base)
    px = tile.load()
    long_vein = ((0, 6), (9, 11), (17, 8), (25, 13), (32, 6))
    cross_vein = ((20, 0), (23, 9), (19, 17), (24, 25), (20, 32))
    # One strong vein and one faint one, so a room does not read as a grid.
    line(px, cross_vein, soft)
    line(px, [(x, y + 1) for x, y in long_vein], soft)
    line(px, long_vein, vein)
    for branch in (((9, 11), (12, 16), (11, 21)), ((19, 17), (13, 19), (8, 18)),
                   ((25, 13), (28, 18)), ((3, 26), (7, 29), (6, 31))):
        line(px, branch, soft, wrap=False)
    return tile.convert("RGBA")


# Every pink slab crosses left/right at y=10 and top/bottom at x=22.
PINK_PATHS = (
    (((0, 10), (8, 14), (15, 9), (24, 15), (32, 10)), ((22, 0), (18, 8), (25, 16), (20, 24), (22, 32)),
     (((8, 14), (5, 21), (9, 27)), ((25, 16), (29, 21)))),
    (((0, 10), (6, 6), (14, 12), (23, 7), (32, 10)), ((22, 0), (26, 7), (21, 15), (26, 23), (22, 32)),
     (((14, 12), (11, 19), (4, 22)), ((21, 15), (15, 17), (12, 25)))),
    (((0, 10), (10, 12), (17, 17), (26, 12), (32, 10)), ((22, 0), (20, 10), (24, 18), (19, 26), (22, 32)),
     (((10, 12), (7, 4)), ((17, 17), (13, 24), (15, 30)), ((26, 12), (29, 5)))),
)


def pink_marble(variant):
    base, wisp, faint, halo, vein = (229, 213, 218), (240, 230, 233), (222, 198, 206), (217, 180, 192), (200, 142, 162)
    tile = Image.new("RGB", (TILE, TILE), base)
    px = tile.load()
    across, down, branches = PINK_PATHS[variant]
    # Pale wisps first, kept clear of the edges so they never need a partner.
    for start in ((4, 20 + variant * 2), (12, 3 + variant), (24, 26 - variant * 3)):
        line(px, (start, (start[0] + 5, start[1] + 2), (start[0] + 9, start[1] + 1)), wisp, wrap=False)
    # One strong vein and one faint one, so a room does not read as a grid.
    line(px, down, faint)
    for branch in branches:
        line(px, branch, faint, wrap=False)
    line(px, [(x, y + 1) for x, y in across], halo)
    line(px, across, vein)
    return tile.convert("RGBA")


def recolour(tile, change):
    out = tile.copy()
    px = out.load()
    for y in range(TILE):
        for x in range(TILE):
            r, g, b, a = px[x, y]
            h, s, v = change(*colorsys.rgb_to_hsv(r / 255, g / 255, b / 255))
            px[x, y] = tuple(round(c * 255) for c in colorsys.hsv_to_rgb(h, min(s, 1), min(v, 1))) + (a,)
    return out


WOOD_HUE = 28 / 360
RECOLOURS = {
    # Grey-brown planks: same drawing, proper wood saturation.
    "woodalt": lambda h, s, v: (WOOD_HUE, min(s * 1.6, 0.78), v),
    # The grey squares become pale ash; the brown ones are left alone.
    "woodalt7": lambda h, s, v: (WOOD_HUE + 0.02, 0.42, min(v * 1.08, 1)) if s < 0.5 else (h, s, v),
    # Olive yellow to golden oak.
    "woodalt8": lambda h, s, v: (WOOD_HUE + 0.015, min(s * 1.05, 0.85), v * 0.94),
}
DARK_TATAMI = lambda h, s, v: (h - 0.012, min(s * 1.05, 1), v * 0.74)


def state_index(desc):
    index, found = 0, {}
    for block in re.split(r"(?m)(?=^state = )", desc):
        name = re.match(r'state = "([^"]*)"', block)
        if name is None:
            continue
        count = int(re.search(r"dirs = (\d+)", block)[1]) * int(re.search(r"frames = (\d+)", block)[1])
        found.setdefault(name[1], (index, count))
        index += count
    return found


class Sheet:
    def __init__(self, path):
        self.path = path
        with Image.open(path) as source:
            self.desc = source.info["Description"]
            self.image = source.convert("RGBA")
        self.index = state_index(self.desc)
        self.columns = self.image.width // TILE

    def box(self, state):
        slot, count = self.index[state]
        assert count == 1, state
        x, y = (slot % self.columns) * TILE, (slot // self.columns) * TILE
        return (x, y, x + TILE, y + TILE)

    def get(self, state):
        return self.image.crop(self.box(state))

    def put(self, state, tile):
        self.image.paste(tile, self.box(state)[:2])

    def encode(self):
        info = PngImagePlugin.PngInfo()
        info.add_text("Description", self.desc, zip=True)
        buffer = io.BytesIO()
        self.image.save(buffer, "PNG", pnginfo=info, optimize=False, compress_level=9)
        return buffer.getvalue()


def drawn():
    art = {"stone_old": old_stone(), "marble": white_marble()}
    art.update({f"pink_marble{i}": pink_marble(i) for i in range(3)})
    return art


def apply(root):
    floors, wood = Sheet(root / FLOORS), Sheet(root / WOOD)
    for state, tile in drawn().items():
        floors.put(state, tile)
    for way in ("0", "1"):
        floors.put("tatami_dark" + way, recolour(floors.get("tatami" + way), DARK_TATAMI))
    for state, change in RECOLOURS.items():
        # The same patterns sit in both sheets; recolour both from the wood sheet.
        tile = recolour(wood.get(state), change)
        wood.put(state, tile)
        if state in floors.index:
            floors.put(state, tile)
    return floors, wood


def preview(path):
    art = drawn()
    board = Image.new("RGBA", (len(art) * (TILE * 3 + 8) + 8, TILE * 3 + 16), (24, 24, 28, 255))
    pink = [art[f"pink_marble{i}"] for i in range(3)]
    for i, (state, tile) in enumerate(art.items()):
        for y in range(3):
            for x in range(3):
                # Mix the pink variants the way the game picks them.
                shown = pink[(x + 2 * y + i) % 3] if state.startswith("pink") else tile
                board.paste(shown, (8 + i * (TILE * 3 + 8) + x * TILE, 8 + y * TILE))
    board.resize((board.width * 3, board.height * 3), Image.Resampling.NEAREST).save(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, required=True)
    parser.add_argument("--preview", type=Path)
    parser.add_argument("--check", action="store_true",
                        help="Check the drawn frames match the sheet (recolours are one-way and not checked)")
    args = parser.parse_args()
    if args.check:
        floors = Sheet(args.repo_root / FLOORS)
        for state, tile in drawn().items():
            assert floors.get(state).tobytes() == tile.tobytes(), f"{state} is stale"
    else:
        floors, wood = apply(args.repo_root)
        (args.repo_root / FLOORS).write_bytes(floors.encode())
        (args.repo_root / WOOD).write_bytes(wood.encode())
    if args.preview:
        preview(args.preview)
    print("floor refresh frames drawn")


if __name__ == "__main__":
    main()
