"""Draw Civ13's kiln-fired terracotta floor family with Pillow and tools/dmi.

Run from the repository root. Optional --preview renders a contact board.
These are opaque 32px turf sprites, not overlay decals, with no animation.
"""
import argparse
import os
from pathlib import Path
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, os.environ.get("CIV13_DMI_TOOLS", str(ROOT / "tools")))
import dmi  # noqa: E402

SIZE = 32
OUTPUT = ROOT / "icons/turf/flooring/terracotta.dmi"
STATES = ("terracotta", "terracotta_edge", "terracotta_outer",
          "terracotta_inner", "terracotta_inset", "brick_paving")
BRICK = ((148, 72, 55), (160, 81, 59), (139, 66, 53), (154, 86, 65))
BRICK_JOINT, BRICK_LIGHT, BRICK_SHADE = (84, 66, 58), (178, 100, 74), (116, 54, 45)
# Keep native DMI order, not compass notation or numeric direction order.
ANGLES = {"SOUTH": 0, "NORTH": 180, "EAST": 90, "WEST": 270}
CLAY = ((146, 93, 70), (158, 102, 75), (151, 96, 73), (141, 88, 67))
GROUT = (76, 53, 46)
TRIM = ((77, 50, 42), (135, 79, 54), (185, 130, 85), (112, 67, 53),
        (123, 75, 57), (137, 87, 64), (174, 114, 76), (101, 61, 48))


def shade(color, n):
    return tuple(max(0, min(255, channel + n)) for channel in color)


def field():
    """Four hand-shaded fired pavers, separated by narrow recessed joints."""
    out = Image.new("RGB", (SIZE, SIZE), GROUT)
    px = out.load()
    for y in range(SIZE):
        for x in range(SIZE):
            u, v = x % 16, y % 16
            if u == 15 or v == 15:
                continue
            color = CLAY[(y // 16) * 2 + x // 16]
            # Deterministic 1px firing flecks over elongated kiln mottling.
            grain = ((x * 19 + y * 17 + (x * y) % 13) % 7) - 3
            fire = (((u + 2 * v) // 5 + (x // 16) * 3) % 4 - 1) * 2
            if u == 0 or v == 0:
                fire += 14
            elif u == 14 or v == 14:
                fire -= 16
            elif u == 1 or v == 1:
                fire += 5
            px[x, y] = shade(color, grain + fire)
    # Tiny, deliberately placed scratches and iron spots avoid white noise.
    draw = ImageDraw.Draw(out)
    for x, y, delta in ((4, 3, 13), (20, 5, -13), (25, 10, 12), (11, 11, -15),
                        (8, 24, -12), (22, 21, 12), (27, 25, -17), (4, 27, 10)):
        c = shade(px[x, y], delta)
        draw.line((x, y, x + 1, y), fill=c)
    return out.convert("RGBA")


def trim(kind):
    """South straight strip or SE corner. Clip or miter the same band."""
    out = Image.new("RGBA", (SIZE, SIZE))
    px = out.load()
    for y in range(SIZE):
        for x in range(SIZE):
            a, b = SIZE - 1 - x, SIZE - 1 - y
            depth = b if kind == "edge" else min(a, b) if kind == "outer" else max(a, b)
            if depth < len(TRIM):
                px[x, y] = TRIM[depth] + (255,)
    return out


def inset():
    """A glazed, diamond-set clay mosaic with a small carved rosette."""
    out = field()
    px = out.load()
    # Doubled distances put the design on the center of an even-size sprite.
    for y in range(SIZE):
        for x in range(SIZE):
            a, b = abs(2 * x - 31), abs(2 * y - 31)
            dist = (a + b) // 2
            if dist > 13:
                continue
            if dist == 13:
                color = (87, 56, 49)
            elif dist == 12:
                color = (187, 139, 90)
            elif dist == 11:
                color = (124, 81, 59)
            elif dist <= 2:
                color = (181, 133, 87)
            elif dist <= 7 and (a <= 3 or b <= 3):
                color = (162, 113, 75)
            elif 2 < dist < 9 and abs(a - b) <= 2:
                color = (146, 88, 62)
            else:
                color = (94, 101, 91) if a >= b else (98, 103, 89)
            px[x, y] = shade(color, (x * 3 + y * 5) % 5 - 2) + (255,)
    return out


def brick_paving():
    """Herringbone pavers, two cells by one; the bond repeats every 32 pixels."""
    out = Image.new("RGB", (SIZE, SIZE), BRICK_JOINT)
    px = out.load()
    cell = 8
    for j in range(SIZE // cell):
        for i in range(SIZE // cell):
            bond = (i - j) % 4
            if bond not in (0, 3):
                continue  # second half of a paver that starts elsewhere
            wide, tall = (2 * cell, cell) if bond == 0 else (cell, 2 * cell)
            body = BRICK[(i * 3 + j * 5) % 4]
            for dy in range(tall - 1):
                for dx in range(wide - 1):
                    if dy == 0 and dx < wide - 2:
                        color = BRICK_LIGHT
                    elif dy == tall - 2 or dx == wide - 2:
                        color = BRICK_SHADE
                    else:
                        color = body
                    px[(i * cell + dx) % SIZE, (j * cell + dy) % SIZE] = color
    return out.convert("RGBA")


def build_atlas():
    art = dmi.Dmi(SIZE, SIZE)
    art.state(STATES[0]).frame(field())
    for state_name, kind in zip(STATES[1:4], ("edge", "outer", "inner")):
        state = art.state(state_name, dirs=4)
        # Rotate the transparent trim only, preserving the common paver bed.
        overlay = trim(kind)
        for rotation in ANGLES.values():
            cell = field()
            cell.alpha_composite(overlay.rotate(rotation))
            state.frame(cell)
    art.state(STATES[4]).frame(inset())
    art.state(STATES[5]).frame(brick_paving())
    return art


def sample(art, shape, x, y, insets):
    edge_offsets = {"NORTH": (0, -1), "SOUTH": (0, 1), "EAST": (1, 0), "WEST": (-1, 0)}
    corners = {"NORTH": ("NORTH", "WEST"), "SOUTH": ("SOUTH", "EAST"),
               "EAST": ("NORTH", "EAST"), "WEST": ("SOUTH", "WEST")}
    edges = {d for d, (a, b) in edge_offsets.items() if (x + a, y + b) not in shape}
    for direction, (first, second) in corners.items():
        if {first, second} <= edges:
            return art.get_state(STATES[2]).get_frame(dir=direction)
    if edges:
        return art.get_state(STATES[1]).get_frame(dir=next(d for d in ANGLES if d in edges))
    for direction, (first, second) in corners.items():
        dx, dy = edge_offsets[first]
        a, b = edge_offsets[second]
        if (x + dx + a, y + dy + b) not in shape:
            return art.get_state(STATES[3]).get_frame(dir=direction)
    return art.get_state(STATES[4 if (x, y) in insets else 0]).get_frame()


def board_font(size, bold=False):
    try:
        name = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
        return ImageFont.truetype(name, size)
    except OSError:
        return ImageFont.load_default(size=size)


def preview(art, path):
    """Lay the sprites against one another so corner joins can be inspected."""
    board = Image.new("RGB", (1000, 800), (25, 27, 30))
    draw = ImageDraw.Draw(board)
    pale, muted, gold = "#f3e4d0", "#bdb6ad", "#ecad77"
    font, small = board_font(17), board_font(14)
    title, label = board_font(34, bold=True), board_font(17, bold=True)
    draw.text((40, 30), "Kiln-fired terracotta", fill=pale, font=title)
    draw.text((40, 78), "Civ13 floor family  /  32 × 32 pixels per state  /  static sprite assembly", fill=muted, font=font)

    shape = {(x, y) for y in range(7) for x in range(9) if y < 4 or x < 5}
    insets = {(2, 2), (3, 2), (2, 3), (3, 3), (6, 1), (6, 2)}
    room = Image.new("RGB", (9 * SIZE, 7 * SIZE), (34, 36, 38))
    for x, y in sorted(shape):
        room.paste(sample(art, shape, x, y, insets), (x * SIZE, y * SIZE))
    board.paste(room.resize((9 * SIZE * 2, 7 * SIZE * 2), Image.Resampling.NEAREST), (40, 145))
    draw.text((40, 115), "ASSEMBLED FLOOR  ·  2×", fill=gold, font=label)
    draw.text((40, 610), "Mitered outside corners and a returning trim at the recess.", fill=pale, font=font)
    draw.text((40, 640), "Use the muted field for most tiles; place the glaze in small groups.", fill=muted, font=font)
    draw.text((40, 688), "NATIVE SIZE", fill=gold, font=label)
    for index, name in enumerate(STATES):
        board.paste(art.get_state(name).get_frame(), (40 + index * 65, 722))

    draw.text((670, 115), "SPRITE STATES", fill=gold, font=label)
    names = ("Fired pavers", "Band edge", "Outside corner", "Inside return", "Glazed inset")
    notes = ("1 direction", "Band faces S, N, E, W", "Shown: southeast", "Shown: southeast notch",
             "1 direction")
    for index, (name, note, state_name) in enumerate(zip(names, notes, STATES)):
        y = 145 + index * 115
        frame = art.get_state(state_name).get_frame()
        board.paste(frame.resize((64, 64), Image.Resampling.NEAREST), (670, y))
        draw.text((751, y + 8), name, fill=pale, font=label)
        draw.text((751, y + 34), note, fill=muted, font=small)
    draw.text((670, 744), "Static preview, not a client capture.", fill=muted, font=small)
    board.save(path, optimize=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--preview", type=Path)
    args = parser.parse_args()
    art = build_atlas()
    art.to_file(args.output)
    if args.preview:
        preview(art, args.preview)


if __name__ == "__main__":
    main()
