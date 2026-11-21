"""Hand-placed 32px precipitation states for icons/effects/weather.dmi: sleet1,
sleet2, hail and glaze. Every pixel is placed by this script from the fixed
tables below (Pillow only); no external or generated artwork.

The look follows the rain and snow states already on the sheet: rain is a
soft grey-blue streak three pixels wide that slides one pixel down and one
left each frame, snow a pale flake at alpha 175.

- sleet1, sleet2: short steep streaks and pale ice pellets on the same
  lines, sliding one pixel down a frame and one left every other frame, so a
  little slower and steeper than rain. 32 frames, rain1's and rain2's delays.
- hail: heavy rain streaks at rain's own pace, white-grey stones of one or
  two pixels dropping two pixels a frame, and stones that strike, splash and
  hop. 32 frames, rain3's delay.
- glaze: one still frame of faint sheen, glints and sparkles for a turf iced
  by freezing rain.

Every frame wraps at all four edges and frame 32 is frame 0, so the pieces
tile and loop without a seam. Only these four states are written: every
other state keeps its pixels, its place in the list and its description
lines. A sheet that already has one of the four gets it replaced in place.

    python3 tests/sprites/create_weather_precip.py                  # rewrite the sheet
    python3 tests/sprites/create_weather_precip.py --check          # exit 1 if it is stale
    python3 tests/sprites/create_weather_precip.py --preview <png>  # also write a review sheet

Released under Civ13 AGPL-3.0.
"""
import math
import re
import struct
import sys
import zlib
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / "icons/effects/weather.dmi"
FLOORS = ROOT / "icons/turf/floors.dmi"
SIZE = 32
FRAMES = 32
COLUMNS = 28  # the sheet's width in cells; kept so no existing frame moves

# ---------------------------------------------------------------- palette
RAIN = (121, 121, 142)       # the bright rain streak of rain1-3
RAIN_DIM = (118, 118, 135)   # its long faint streak
SLEET = (150, 158, 176)      # a rain streak going to ice
PELLET = (232, 240, 244)     # ice pellet, next to snow's (245, 245, 240)
PELLET_SHADE = (178, 194, 208)
STONE = (250, 252, 255)      # hailstone
STONE_SHADE = (190, 200, 212)
SPRAY = (214, 226, 236)      # splash thrown up by a stone
ICE = (212, 232, 246)        # glaze sheen
GLINT = (246, 251, 255)      # glaze highlight


class Frame:
    """A 32px cell that wraps at its edges; a pixel put twice keeps the
    stronger alpha."""

    def __init__(self):
        self.px = {}

    def put(self, x, y, colour, alpha):
        alpha = int(round(alpha))
        if alpha <= 0:
            return
        key = (int(x) % SIZE, int(y) % SIZE)
        if key not in self.px or self.px[key][3] < alpha:
            self.px[key] = colour + (min(255, alpha),)

    def image(self):
        cell = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        for (x, y), value in self.px.items():
            cell.putpixel((x, y), value)
        return cell


# ---------------------------------------------------------------- rain streaks
def rain_streak(f, x, y, length, colour, alpha):
    """The sheet's rain streak: a core running down-left from (x, y) with a
    faint pixel either side, thinner at both ends."""
    for i in range(length):
        end = i == 0 or i == length - 1
        core = alpha * (0.85 if end else 1)
        f.put(x - i, y + i, colour, core)
        f.put(x - i - 1, y + i, colour, core * (0.13 if i == length - 1 else 0.27))
        f.put(x - i + 1, y + i, colour, core * (0.13 if i == 0 else 0.27))


# ---------------------------------------------------------------- sleet
# Sleet slides along steep lines: the line through column c holds the pixels
# (c - Y // 2, Y). Y runs over 64 rows, twice the cell, before a line comes
# back to its own column, so each entry is drawn twice, 32 rows apart; the
# two stand 16 pixels apart in the cell. Brightness follows the place on the
# 64 rows, which makes the two glint in turn and still closes the loop.
# Entries are (x, y at frame 0, kind, glint phase in 64ths), set out over the
# left half of the cell; the second drawing fills the right half.
SLEET_LIGHT = (
    (5, 2, "streak", 0), (1, 19, "pellet", 23), (13, 7, "short", 46), (9, 25, "pellet", 5),
    (3, 12, "streak", 28), (15, 30, "big", 51), (11, 16, "streak", 10), (7, 0, "pellet", 33),
    (6, 21, "short", 56), (0, 7, "pellet", 15), (14, 24, "streak", 38),
)
SLEET_HEAVY = SLEET_LIGHT + (
    (9, 10, "streak", 9), (4, 28, "pellet", 32), (2, 15, "short", 55), (12, 2, "big", 14),
    (8, 19, "streak", 37), (6, 5, "pellet", 60), (1, 25, "streak", 19), (15, 11, "pellet", 42),
    (10, 29, "short", 1), (4, 16, "pellet", 24), (0, 1, "streak", 47), (13, 20, "big", 6),
)


def sleet_frames(entries):
    frames = []
    for t in range(FRAMES):
        f = Frame()
        for x, start, kind, phase in entries:
            column = x + start // 2
            for twin in (0, 32):
                top = (start + twin + t) % 64
                glint = 0.78 + 0.22 * math.cos(2 * math.pi * (top + phase) / 64)

                def at(row, colour, alpha, side=0):
                    y = top + row
                    f.put(column - (y % 64) // 2 + side, y, colour, alpha * glint)

                if kind == "streak" or kind == "short":
                    alphas = (34, 74, 104, 112, 96, 52) if kind == "streak" else (40, 96, 108, 56)
                    for row, alpha in enumerate(alphas):
                        at(row, SLEET, alpha)
                        # soft sides like the rain streak, on the side it leans to
                        at(row, SLEET, alpha * 0.26, 1 if (top + row) % 2 else -1)
                elif kind == "pellet":
                    at(0, SLEET, 48)
                    at(1, PELLET, 180)
                else:  # a bigger pellet: two pixels and the streak it leaves
                    at(-1, SLEET, 34)
                    at(0, SLEET, 70)
                    at(1, PELLET_SHADE, 150)
                    at(2, PELLET, 190)
        frames.append(f.image())
    return frames


# ---------------------------------------------------------------- hail
# (x, y of the head at frame 0, rows, bright)
HAIL_RAIN = (
    (4, 0, 3, 1), (13, 1, 3, 1), (22, 0, 4, 1), (30, 2, 3, 1), (8, 5, 7, 0), (18, 6, 3, 1),
    (26, 7, 7, 0), (1, 9, 3, 1), (11, 11, 4, 1), (21, 12, 3, 1), (29, 13, 3, 1), (5, 15, 7, 0),
    (15, 16, 3, 1), (24, 18, 4, 1), (0, 19, 7, 0), (9, 21, 3, 1), (19, 22, 3, 1), (28, 23, 3, 1),
    (3, 25, 4, 1), (13, 26, 7, 0), (22, 27, 3, 1), (31, 28, 3, 1), (7, 30, 3, 1), (17, 31, 4, 1),
    (10, 3, 3, 1), (25, 2, 3, 1), (16, 9, 3, 1), (2, 13, 3, 1), (27, 17, 3, 1), (12, 20, 3, 1),
    (20, 25, 3, 1), (6, 28, 3, 1),
)
# Falling stones: (x, y at frame 0, two pixels wide). Each drops two pixels
# and drifts one left a frame.
HAIL_STONES = (
    (6, 3, 0), (19, 10, 1), (28, 20, 0), (12, 26, 1), (1, 15, 0), (24, 30, 0), (15, 18, 1),
)
# Stones that land: (x, y of the strike, frame of the strike, two pixels wide).
HAIL_STRIKES = ((9, 12, 3, 1), (25, 6, 11, 0), (17, 27, 19, 1), (3, 22, 27, 0))
# The hop after a strike, a frame each: (dx, dy, alpha).
HOP = ((-1, -2, 235), (-2, -3, 225), (-2, -4, 210), (-3, -3, 190), (-3, -2, 160), (-4, 0, 110), (-4, 0, 50))
# The splash, a frame each from the strike: [(dx, dy, alpha)].
SPLASH = (
    ((-1, 0, 150), (1, 0, 150), (0, 1, 70)),
    ((-2, -1, 130), (2, -1, 130), (-1, 0, 80), (1, 0, 80)),
    ((-3, -1, 90), (3, -1, 90), (-2, 0, 50), (2, 0, 50)),
    ((-3, 0, 45), (3, 0, 45)),
)


def stone(f, x, y, wide, alpha, trail=True):
    f.put(x, y, STONE, alpha)
    if wide:
        f.put(x + 1, y, STONE_SHADE, alpha * 0.9)
    if trail:  # the blur of a fast fall, up along its path
        f.put(x, y - 1, STONE_SHADE, alpha * 0.45)
        f.put(x + 1, y - 2, STONE_SHADE, alpha * 0.24)
        f.put(x + 1, y - 3, STONE_SHADE, alpha * 0.1)


def hail_frames():
    frames = []
    for t in range(FRAMES):
        f = Frame()
        for x, y, rows, bright in HAIL_RAIN:
            rain_streak(f, x - t, y + t, rows, RAIN if bright else RAIN_DIM, 118 if bright else 66)
        for x, y, wide in HAIL_STONES:
            stone(f, x - t, y + 2 * t, wide, 235)
        for x, y, hit, wide in HAIL_STRIKES:
            since = (t - hit) % FRAMES
            if since >= FRAMES - 5:  # coming down, out of the rain
                before = FRAMES - since
                stone(f, x + before, y - 2 * before, wide, (235, 235, 200, 140, 70)[before - 1])
            elif since == 0:
                stone(f, x, y, wide, 245)
            elif since <= len(HOP):
                dx, dy, alpha = HOP[since - 1]
                stone(f, x + dx, y + dy, wide and since < 5, alpha, trail=False)
            if since < len(SPLASH):
                for dx, dy, alpha in SPLASH[since]:
                    f.put(x + dx, y + dy, SPRAY, alpha)
        frames.append(f.image())
    return frames


# ---------------------------------------------------------------- glaze
# Glints run down-left like the rain that froze: (x, y, alphas along it).
GLAZE_GLINTS = (
    (7, 2, (20, 38, 50, 32, 18)), (25, 4, (18, 32, 42, 22)), (15, 10, (22, 42, 58, 48, 30, 15)),
    (30, 13, (18, 35, 25)), (5, 16, (20, 38, 48, 28)), (21, 19, (18, 35, 50, 40, 22)),
    (11, 24, (20, 38, 25)), (28, 26, (22, 42, 55, 38, 20)), (2, 29, (18, 30, 20)),
    (18, 30, (20, 35, 45, 25)),
)
# Sparkles: (x, y, alpha).
GLAZE_SPARKS = ((12, 4, 78), (27, 10, 64), (3, 9, 58), (19, 15, 84), (8, 21, 62), (24, 23, 72), (14, 28, 56), (31, 31, 60))


def glaze_frame():
    f = Frame()
    turn = 2 * math.pi / SIZE
    for y in range(SIZE):
        for x in range(SIZE):
            # Slow bands across the tile, whole turns each way so it wraps.
            wave = math.sin(turn * (x + y) + 1.6 * math.sin(turn * (2 * y - x) + 0.9)) \
                + 0.5 * math.sin(turn * (2 * x - y) + 2.2)
            if wave > 1.05:
                f.put(x, y, ICE, 15)
            elif wave > 0.6:
                f.put(x, y, ICE, 10 if (x + y) % 2 else 8)
            elif wave > 0.25 and (x + 2 * y) % 3 == 0:
                f.put(x, y, ICE, 6)
    for x, y, alphas in GLAZE_GLINTS:
        for i, alpha in enumerate(alphas):
            f.put(x - i, y + i, GLINT, alpha)
            f.put(x - i + 1, y + i, ICE, alpha * 0.45)
    for x, y, alpha in GLAZE_SPARKS:
        f.put(x, y, GLINT, alpha)
        f.put(x - 1, y, ICE, alpha * 0.3)
        f.put(x, y - 1, ICE, alpha * 0.3)
    return f.image()


def new_states():
    """[(name, [frames], delay)] - the four states this script owns."""
    return [
        ("sleet1", sleet_frames(SLEET_LIGHT), "0.25"),
        ("sleet2", sleet_frames(SLEET_HEAVY), "0.2"),
        ("hail", hail_frames(), "0.15"),
        ("glaze", [glaze_frame()], None),
    ]


# ---------------------------------------------------------------- the sheet
def description(data):
    at = 8
    while at < len(data):
        length, kind = struct.unpack(">I4s", data[at:at + 8])
        body = data[at + 8:at + 8 + length]
        if kind == b"zTXt" and body.startswith(b"Description\0"):
            return zlib.decompress(body[len(b"Description\0") + 1:]).decode()
        at += 12 + length
    raise SystemExit("no DMI description")


def read_sheet(data):
    """[(name, [description lines], [frames])] in sheet order."""
    text = description(data)
    width = int(re.search(r"width = (\d+)", text).group(1))
    height = int(re.search(r"height = (\d+)", text).group(1))
    if (width, height) != (SIZE, SIZE):
        raise SystemExit("expected 32px cells")
    sheet = Image.open(BytesIO(data)).convert("RGBA")
    columns = sheet.width // SIZE
    found = []
    at = 0
    for block in text.split("state = ")[1:]:
        lines = block.split("# END DMI")[0].rstrip("\n").split("\n")
        name = re.match(r'"([^"]*)"', lines[0]).group(1)
        dirs = int(re.search(r"dirs = (\d+)", block).group(1))
        count = dirs * int(re.search(r"frames = (\d+)", block).group(1))
        cells = [sheet.crop(((i % columns) * SIZE, (i // columns) * SIZE,
                             (i % columns + 1) * SIZE, (i // columns + 1) * SIZE)) for i in range(at, at + count)]
        found.append((name, ["state = " + lines[0]] + lines[1:], cells))
        at += count
    return found


def state_lines(name, frames, delay):
    lines = [f'state = "{name}"', "\tdirs = 1", f"\tframes = {len(frames)}"]
    if delay:
        lines.append("\tdelay = " + ",".join([delay] * len(frames)))
    return lines


def build(data):
    """The sheet's bytes with the four states replaced in place or appended."""
    states = read_sheet(data)
    for name, frames, delay in new_states():
        entry = (name, state_lines(name, frames, delay), frames)
        for i, (have, _, _) in enumerate(states):
            if have == name:
                states[i] = entry
                break
        else:
            states.append(entry)
    total = sum(len(cells) for _, _, cells in states)
    sheet = Image.new("RGBA", (COLUMNS * SIZE, -(-total // COLUMNS) * SIZE), (0, 0, 0, 0))
    lines = ["# BEGIN DMI", "version = 4.0", f"\twidth = {SIZE}", f"\theight = {SIZE}"]
    at = 0
    for _, block, cells in states:
        lines += block
        for cell in cells:
            sheet.paste(cell, ((at % COLUMNS) * SIZE, (at // COLUMNS) * SIZE))
            at += 1
    lines.append("# END DMI\n")
    plain = BytesIO()
    sheet.save(plain, "PNG", optimize=True)
    png = plain.getvalue()
    body = b"Description\0\0" + zlib.compress("\n".join(lines).encode(), 9)
    chunk = struct.pack(">I", len(body)) + b"zTXt" + body + struct.pack(">I", zlib.crc32(b"zTXt" + body) & 0xFFFFFFFF)
    return png[:33] + chunk + png[33:]  # after IHDR


def same_sheet(a, b):
    """Same description and pixels; the packed bytes differ between zlib and
    Pillow versions, so they are not compared."""
    if description(a) != description(b):
        return False
    x = Image.open(BytesIO(a)).convert("RGBA")
    y = Image.open(BytesIO(b)).convert("RGBA")
    return x.size == y.size and x.tobytes() == y.tobytes()


# ---------------------------------------------------------------- review sheet
def ground(state, shade=1.0):
    """A turf from floors.dmi, for the review sheet only."""
    data = FLOORS.read_bytes()
    text = description(data)
    sheet = Image.open(BytesIO(data)).convert("RGBA")
    columns = sheet.width // SIZE
    at = 0
    for block in text.split("state = ")[1:]:
        name = re.match(r'"([^"]*)"', block).group(1)
        if name == state:
            cell = sheet.crop(((at % columns) * SIZE, (at // columns) * SIZE,
                               (at % columns + 1) * SIZE, (at // columns + 1) * SIZE))
            return Image.eval(cell.convert("RGB"), lambda v: int(v * shade)).convert("RGBA")
        at += int(re.search(r"dirs = (\d+)", block).group(1)) * int(re.search(r"frames = (\d+)", block).group(1))
    raise SystemExit(f"floors.dmi lacks {state}")


def preview(data, path, zoom=2):
    """First frames tiled three by three on grass and on dark ground, at 1x
    and enlarged."""
    cells = {name: frames[0] for name, _, frames in read_sheet(data)}
    names = ("rain2", "snow2", "sleet1", "sleet2", "hail", "glaze")
    grounds = (("grass", ground("grass0")), ("dark ground", ground("dirt", 0.42)))
    tile = 3 * SIZE
    gap, left, top = 6, 76, 16

    def block(scale):
        width = left + len(names) * (tile * scale + gap)
        out = Image.new("RGBA", (width, top + len(grounds) * (tile * scale + gap)), (24, 24, 28, 255))
        draw = ImageDraw.Draw(out)
        for column, name in enumerate(names):
            draw.text((left + column * (tile * scale + gap), 2), name, fill=(230, 230, 230, 255))
        for row, (label, turf) in enumerate(grounds):
            draw.text((4, top + row * (tile * scale + gap) + 4), f"{label} {scale}x", fill=(230, 230, 230, 255))
            for column, name in enumerate(names):
                sample = Image.new("RGBA", (tile, tile))
                for x in range(3):
                    for y in range(3):
                        sample.paste(turf, (x * SIZE, y * SIZE))
                        sample.alpha_composite(cells[name], (x * SIZE, y * SIZE))
                out.paste(sample.resize((tile * scale, tile * scale), Image.NEAREST),
                          (left + column * (tile * scale + gap), top + row * (tile * scale + gap)))
        return out

    parts = [block(1), block(zoom)]
    out = Image.new("RGBA", (max(p.width for p in parts), sum(p.height for p in parts)), (24, 24, 28, 255))
    y = 0
    for part in parts:
        out.paste(part, (0, y))
        y += part.height
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    out.save(path)


def main():
    have = SHEET.read_bytes()
    data = build(have)
    if "--check" in sys.argv:
        if not same_sheet(have, data):
            print("stale: icons/effects/weather.dmi")
            return 1
        print("weather precipitation states are current")
        return 0
    if not same_sheet(have, data):
        SHEET.write_bytes(data)
        print(f"wrote {SHEET.relative_to(ROOT)} ({len(data)} bytes)")
    else:
        print("weather precipitation states are current")
    if "--preview" in sys.argv:
        path = sys.argv[sys.argv.index("--preview") + 1]
        preview(SHEET.read_bytes(), path)
        print(f"wrote {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
