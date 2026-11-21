#!/usr/bin/env python3
"""Build Civ13 gray-cobble sill and floor covers from stock pixels.

Run once per tone after scripts/draw_cobble_floors.py:
    --tone light --output icons/turf/flooring/cobble_trim.dmi
    --tone dark  --output icons/turf/flooring/cobble_trim_dark.dmi
"""
import argparse
import hashlib
import io
import re
import struct
import zlib
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

TILE = 32
ORDER = ("S", "N", "E", "W")
STATES = (
    "sill_center", "sill_cap_left", "sill_cap_right", "trim_straight",
    "trim_corner_inside", "trim_corner_outside", "trim_stop", "trim_stop_reverse",
)
FLOORS = Path("icons/turf/floors.dmi")
ROTATIONS = (None, Image.Transpose.ROTATE_180,
             Image.Transpose.ROTATE_90, Image.Transpose.ROTATE_270)


def dmi_states(im):
    desc = im.info["Description"]
    assert all(int(re.search(rf"(?m)^\s*{field} = (\d+)", desc)[1]) == TILE
               for field in ("width", "height"))
    index = 0
    for block in re.split(r"(?m)(?=^state = )", desc):
        name = re.match(r'state = "([^"]*)"', block)
        if name is None:
            continue
        dirs = int(re.search(r"dirs = (\d+)", block)[1])
        frames = int(re.search(r"frames = (\d+)", block)[1])
        yield name[1], index, dirs, frames
        index += dirs * frames


def stock(repo, dmi_path, state):
    with Image.open(repo / dmi_path) as source:
        for name, index, _, _ in dmi_states(source):
            if name == state:
                grid_width = source.width // TILE
                x, y = (index % grid_width) * TILE, (index // grid_width) * TILE
                assert y + TILE <= source.height
                tile = source.crop((x, y, x + TILE, y + TILE)).convert("RGBA")
                assert tile.getchannel("A").getbbox()
                return tile
    raise ValueError(f"missing {dmi_path}:{state}")


def shade(pixel, offset, desaturate=3):
    r, g, b = pixel[:3]
    avg = (3 * r + 6 * g + b) // 10
    return tuple(max(0, min(255, (x + desaturate * avg) // (desaturate + 1) + offset))
                 for x in (r, g, b)) + (255,)


def sill_tile(cobble, state):
    """A flush dressed ribbon; capped ends use a soft chipped/mortared outline."""
    out = Image.new("RGBA", (TILE, TILE))
    grain = cobble.load()
    px = out.load()
    border = {
        "sill_center": (0, 31),
        "sill_cap_left": (5, 31),
        "sill_cap_right": (0, 26),
    }
    a, b = border[state]
    for x in range(a, b + 1):
        recessed_end = (x == a and a > 0) or (x == b and b < 31)
        bevel_end = (x == a + 1 and a > 0) or (x == b - 1 and b < 31)
        for y in range(11, 21):
            if recessed_end and y in (11, 20):
                continue
            base = grain[x, y]
            if recessed_end or y in (11, 20):
                px[x, y] = shade(base, -32)
            elif bevel_end or y == 12:
                px[x, y] = shade(base, 15)
            elif y == 19:
                px[x, y] = shade(base, -15)
            elif x in (11, 23) and not bevel_end:
                px[x, y] = shade(base, -17)
            else:
                px[x, y] = shade(base, 15)
    return out


def trim_tile(cobble, state):
    """An edge band on the south edge; the two corner pieces meet at southwest."""
    out = Image.new("RGBA", (TILE, TILE))
    grain = cobble.load()
    px = out.load()
    for y in range(TILE):
        for x in range(TILE):
            south, west = 31 - y, x
            if state == "trim_straight":
                distance = south
            elif state == "trim_corner_inside":
                # Concave overlap cap: each facing band continues at full width.
                if south >= 4 or west >= 4:
                    continue
                distance = max(south, west)
            elif state == "trim_corner_outside":
                # Convex L: miter the bevel where the two bands meet.
                distance = min(south, west)
            elif state == "trim_stop":
                if x > 25 or (x == 25 and south == 3):
                    continue
                distance = max(south, 27 - x) if x >= 24 else south
            else:
                raise ValueError(state)
            if distance < 4:
                # A dressed kerb: joints every eight pixels along the run.
                run = y if state == "trim_corner_outside" and west < south else x
                joint = distance in (1, 2) and run % 8 == 7 and state != "trim_corner_inside"
                px[x, y] = shade(grain[x, y], -17 if joint else (-23, 4, 15, -17)[distance])
    return out


FIELDS = {"light": "cobble_horizontal", "dark": "cobble_horizontal_dark"}


def dressed(field):
    """A flat tile in the field's lightest stone grey, so the sill and kerb read
    as cut stone in the same rock as the cobbles around them."""
    colours = sorted({colour[:3] for _, colour in field.getcolors(TILE * TILE)}, key=sum)
    return Image.new("RGBA", (TILE, TILE), colours[-2] + (255,))


def sprites(root, tone="light"):
    gray_sill = gray_trim = dressed(stock(root, FLOORS, FIELDS[tone]))
    art = {state: (sill_tile if state.startswith("sill_") else trim_tile)(
                gray_sill if state.startswith("sill_") else gray_trim, state)
           for state in STATES if state != "trim_stop_reverse"}
    art["trim_stop_reverse"] = art["trim_stop"].transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    return art


def rotations(tile):
    return tuple(tile if direction is None else tile.transpose(direction) for direction in ROTATIONS)


def chunk(kind, content):
    return (struct.pack(">I", len(content)) + kind + content +
            struct.pack(">I", zlib.crc32(kind + content)))


def opaque_frames(root, art, tone="light"):
    field = stock(root, FLOORS, FIELDS[tone])
    assert field.getchannel("A").getextrema() == (255, 255)
    return {state: tuple(Image.alpha_composite(field, frame) for frame in rotations(tile))
            for state, tile in art.items()}


def build_kit(root, tone="light"):
    art = sprites(root, tone)
    complete = opaque_frames(root, art, tone)
    sheet = Image.new("RGBA", (TILE * len(ORDER), TILE * len(STATES)))
    metadata = ["# BEGIN DMI", "version = 4.0", "\twidth = 32", "\theight = 32"]
    for row, (state, frames) in enumerate(complete.items()):
        metadata += [f'state = "{state}"', "\tdirs = 4", "\tframes = 1"]
        for col, frame in enumerate(frames):
            sheet.paste(frame, (col * TILE, row * TILE))
    desc = ("\n".join([*metadata, "# END DMI"]) + "\n").encode("ascii")
    # PNG scanlines with explicit "none" filter; the DMI description is
    # PNG zTXt, separate from the sprite bytes. No Pillow compression defaults.
    raw = sheet.tobytes()
    width_bytes = sheet.width * 4
    scanlines = b"".join(b"\x00" + raw[i:i + width_bytes] for i in range(0, len(raw), width_bytes))
    binary = (b"\x89PNG\r\n\x1a\n" +
              chunk(b"IHDR", struct.pack(">IIBBBBB", *sheet.size, 8, 6, 0, 0, 0)) +
              chunk(b"zTXt", b"Description\x00\x00" + zlib.compress(desc, 9)) +
              chunk(b"IDAT", zlib.compress(scanlines, 9)) + chunk(b"IEND", b""))
    return binary, art, complete


def validate(binary, art, complete):
    """Round-trip PNG pixels, rotations, continuity, and full metadata."""
    with Image.open(io.BytesIO(binary)) as image:
        assert image.size == (TILE * len(ORDER), TILE * len(STATES)) and image.mode == "RGBA"
        row_metadata = list(dmi_states(image))
        assert row_metadata == [(state, i * 4, 4, 1) for i, state in enumerate(STATES)]
        for row, frames in enumerate(complete.values()):
            for col, frame in enumerate(frames):
                box = (col*TILE, row*TILE, (col+1)*TILE, (row+1)*TILE)
                assert image.crop(box).tobytes() == frame.tobytes()
                assert frame.getchannel("A").getextrema() == (255, 255)
        for tile in art.values():
            assert set(tile.getchannel("A").tobytes()) == {0, 255}
    center = art["sill_center"].getchannel("A")
    left = art["sill_cap_left"].getchannel("A")
    right = art["sill_cap_right"].getchannel("A")
    column = lambda image, x: image.crop((x, 0, x+1, TILE)).tobytes()
    assert column(left, 31) == column(center, 0) != bytes(TILE)
    assert column(center, 31) == column(right, 0) != bytes(TILE)
    assert column(left, 0) == column(right, 31) == bytes(TILE)
    trim = art["trim_straight"].getchannel("A")
    stop = art["trim_stop"].getchannel("A")
    assert column(trim, 31) == column(stop, 0) != bytes(TILE)
    assert column(stop, 31) == bytes(TILE)
    stop_reverse = art["trim_stop_reverse"].getchannel("A")
    assert column(stop_reverse, 31) == column(trim, 0) != bytes(TILE)
    assert column(stop_reverse, 0) == bytes(TILE)
    outer = art["trim_corner_outside"].getchannel("A")
    assert column(outer, 31) == column(trim, 0)
    assert art["trim_corner_inside"].getchannel("A").getbbox() == (0, 28, 4, 32)


def preview(root, frames, output):
    bg = "#15191e"
    field = stock(root, FLOORS, "cobble_horizontal")
    cross = stock(root, FLOORS, "cobble_vertical")
    dark = stock(root, FLOORS, "cobble_horizontal_dark")
    wall = stock(root, Path("icons/turf/walls.dmi"), "old_stone_wall")
    doors = Path("icons/obj/doors/material_doors.dmi")
    def wood_tint(tile):
        tinted = tile.copy()
        pixels = tinted.load()
        for y in range(TILE):
            for x in range(TILE):
                r, g, b, a = pixels[x, y]
                pixels[x, y] = (r * 167 // 255, g * 120 // 255, b * 78 // 255, a)
        return tinted
    closed = wood_tint(stock(root, doors, "wood"))
    opened = wood_tint(stock(root, doors, "woodopen"))

    def scene(opening, door=None):
        scene = Image.new("RGBA", (TILE*7, TILE*5))
        for y in range(5):
            for x in range(7):
                slab = field if y < 3 else cross
                if y == 2 and abs(x - 3) > opening // 2:
                    slab = wall
                elif x in (0, 6):
                    slab = dark
                scene.alpha_composite(slab, (x*TILE, y*TILE))
        def overlay(tile, x, y):
            scene.alpha_composite(tile, (x*TILE, y*TILE))
        if opening == 3:
            for x, state in zip(range(2, 5), ("sill_cap_left", "sill_center", "sill_cap_right")):
                overlay(frames[state][0], x, 2)
            for x in range(2, 5):
                overlay(frames["trim_straight"][0], x, 0)
            overlay(frames["trim_stop_reverse"][0], 1, 0)
            overlay(frames["trim_stop"][0], 5, 0)
            for y in (3, 4):
                overlay(frames["trim_straight"][2], 1, y)
                overlay(frames["trim_straight"][3], 5, y)
        else:
            overlay(frames["sill_center"][0], 3, 2)
            overlay(door, 3, 2)
        return scene.resize((TILE*14, TILE*10), Image.Resampling.NEAREST)

    board = Image.new("RGB", (988, 1010), bg)
    dr = ImageDraw.Draw(board)
    family = "/usr/share/fonts/truetype/dejavu/DejaVuSans"
    font = lambda n, bold=False: ImageFont.truetype(family + ("-Bold" if bold else "") + ".ttf", n)
    def text(x, y, label, size=16, heavy=False, fill="#d6d9da"):
        dr.text((x, y), label, font=font(size, heavy), fill=fill)
    text(28, 20, "Gray cobble: sills and corridor trim", 30, True, "#f0eee7")
    text(28, 60, "Traditional edits from stock Cobble DMI pixels  •  Offline sprite mockup, not gameplay", 16)
    for x, title, explanation, pic in [
        (28, "01  /  Three-tile opening", "Caps close the line against the stone jambs.", scene(3)),
        (514, "02  /  One-tile opening, open door", "One sill under the existing open wood door.", scene(1, opened)),
        (28, "03  /  Same door, closed", "The stock door overlays the same sill.", scene(1, closed)),
    ]:
        y = 103 if not title.startswith("03") else 500
        text(x, y, title, 18, True, "#f0eee7")
        board.paste(pic, (x, y+31), pic)
        text(x, y+359, explanation, 15)
    text(514, 500, "04  /  Trim states", 18, True, "#f0eee7")
    text(514, 530, "Exact SOUTH frames; each covers one turf.", 15)
    for i, state in enumerate(STATES):
        x, y = 513 + (i % 3)*151, 568 + (i//3)*104
        tile = frames[state][0].resize((64, 64), Image.Resampling.NEAREST)
        board.paste(tile, (x, y), tile)
        text(x, y+70, state, 12)
    text(28, 934, "Flat floor covers only: no change to doors, collision, or route width.", 17, True, "#e3cb92")
    text(28, 971, "Gray cobble kit: use the same sill across open and doored openings.", 15)
    board.save(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--preview", type=Path)
    parser.add_argument("--tone", choices=sorted(FIELDS), default="light",
                        help="light writes cobble_trim.dmi, dark writes cobble_trim_dark.dmi")
    parser.add_argument("--check", action="store_true", help="Refuse if existing DMI differs")
    args = parser.parse_args()
    binary, art, complete = build_kit(args.repo_root, args.tone)
    validate(binary, art, complete)
    if args.check:
        assert args.output.read_bytes() == binary, "committed DMI is stale"
    else:
        args.output.write_bytes(binary)
    if args.preview:
        preview(args.repo_root, complete, args.preview)
    print(f"{len(STATES)} states × {len(ORDER)} directions × 1 frame; sha256={hashlib.sha256(binary).hexdigest()}")


if __name__ == "__main__":
    main()
