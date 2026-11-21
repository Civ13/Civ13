"""Frost protection for a planted crop, in icons/obj/frost_covers.dmi. Every
pixel is computed by this script from the fixed numbers and the seeded
jitter below (Pillow only); no external or generated artwork.

Three 32px states, one direction and one frame each. They share a tile with
a crop sprite from icons/farming/ on ploughed soil; those crops are flat
shaded with no dark outline and stand on the soil at about row 24 from the
top, with the stem near column 16:

- mulch: an UNDERLAY. A loose bed of pale golden straw strands around the
  foot of the plant, rows 19 to 30, opaque, with the middle left open so the
  stem and the soil under it still show.
- row_cover: an OVERLAY. An off-white fleece draped over the plant, 26px
  wide and 22px tall (columns 3 to 28, rows 8 to 29), alpha about 135 so the
  crop shows through, with soft fold lines, a lighter rim and a more opaque
  hem pegged down at the two bottom corners.
- cloche: an OVERLAY. A glass bell jar, 24px wide and 26px tall with its
  knob (columns 4 to 27, rows 4 to 29): pale blue-white glass at alpha about
  60, a crisp lighter outline and two bright highlight streaks on the left
  shoulder with a fainter reflection on the right.

    python3 tests/sprites/create_frost_covers.py                  # write the sheet
    python3 tests/sprites/create_frost_covers.py --check          # exit 1 if it is stale
    python3 tests/sprites/create_frost_covers.py --preview <png>  # also write a review sheet

Released under Civ13 AGPL-3.0.
"""
import math
import random
import struct
import sys
import zlib
from io import BytesIO
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / "icons/obj/frost_covers.dmi"
SIZE = 32
CLEAR = (0, 0, 0, 0)

# ---------------------------------------------------------------- mulch
STRAW = ((226, 200, 128), (208, 178, 100), (238, 216, 150), (186, 154, 80), (164, 132, 66))
STRAW_SHADE = (120, 94, 44)
MULCH_CENTRE = (15.5, 24.5)   # the bed's middle, at the foot of the stem
MULCH_REACH = (14.5, 5.0)     # how far the bed spreads, across and down
MULCH_OPEN = (5.0, 2.0)       # the open middle, around the stem
MULCH_ROWS = (19, 30)


def line(x0, y0, x1, y1):
    """Bresenham, both ends included."""
    x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    out = []
    while True:
        out.append((x0, y0))
        if x0 == x1 and y0 == y1:
            return out
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def mulch():
    rng = random.Random(2611)
    cell = Image.new("RGBA", (SIZE, SIZE), CLEAR)
    px = cell.load()
    cx, cy = MULCH_CENTRE
    strands = []
    while len(strands) < 34:
        angle = rng.uniform(0, 2 * math.pi)
        spread = rng.uniform(0.5, 1.0)
        mx = cx + math.cos(angle) * MULCH_REACH[0] * spread
        my = cy + math.sin(angle) * MULCH_REACH[1] * spread
        if ((mx - cx) / MULCH_OPEN[0]) ** 2 + ((my - cy) / MULCH_OPEN[1]) ** 2 < 1.6:
            continue
        # strands lie mostly flat, roughly around the stem, a few thrown across
        lie = angle + math.pi / 2 + rng.uniform(-0.9, 0.9)
        half = rng.uniform(1.5, 3.6)
        ax, ay = math.cos(lie) * half, math.sin(lie) * half * 0.5
        strands.append((my, mx - ax, my - ay, mx + ax, my + ay, rng.choice(STRAW)))
    strands.sort()   # nearer strands over farther ones
    for _, x0, y0, x1, y1, colour in strands:
        dots = [(x, y) for x, y in line(x0, y0, x1, y1)
                if 0 <= x < SIZE and MULCH_ROWS[0] <= y <= MULCH_ROWS[1]
                and ((x - cx) / MULCH_OPEN[0]) ** 2 + ((y - cy) / MULCH_OPEN[1]) ** 2 >= 1.0]
        for x, y in dots:   # a thin shadow under the strand, so each one reads
            if y + 1 <= MULCH_ROWS[1]:
                px[x, y + 1] = STRAW_SHADE + (255,)
        for x, y in dots:
            px[x, y] = colour + (255,)
    return cell


# ---------------------------------------------------------------- row cover
FLEECE = (236, 234, 224)
FLEECE_RIM = (248, 247, 240)
FLEECE_FOLD = (172, 174, 168)
FLEECE_LIGHT = (252, 252, 248)
PEG = (85, 53, 5)
COVER_LEFT, COVER_RIGHT = 3, 28      # 26 wide
COVER_TOP, COVER_BOTTOM = 8, 29      # 22 tall
COVER_MID = (COVER_LEFT + COVER_RIGHT) / 2.0


def cover_top(x):
    """Top row of the cloth in column x: a slack rounded hump, a little
    peaked, with one shoulder hanging lower than the other."""
    t = min(1.0, abs(x - COVER_MID) / (COVER_RIGHT - COVER_MID + 0.5))
    rise = (COVER_BOTTOM - COVER_TOP) * (1 - t ** 1.9) ** (1 / 1.9)
    sag = 1 if 4 < COVER_MID - x < 9 else 0
    return min(COVER_BOTTOM - 1, int(round(COVER_BOTTOM - rise)) + sag)


def row_cover():
    rng = random.Random(2612)
    cell = Image.new("RGBA", (SIZE, SIZE), CLEAR)
    px = cell.load()
    tops = {x: cover_top(x) for x in range(COVER_LEFT, COVER_RIGHT + 1)}
    for x, top in tops.items():
        for y in range(top, COVER_BOTTOM + 1):
            depth = (y - COVER_TOP) / float(COVER_BOTTOM - COVER_TOP)
            alpha = 124 + int(round(14 * depth)) + rng.randint(-4, 4)
            shade = rng.randint(-3, 3)
            px[x, y] = (FLEECE[0] + shade, FLEECE[1] + shade, FLEECE[2] + shade, alpha)
    # folds fall from the crown towards the hem, bowing outwards as the hump
    # does; each has a lit side
    for start, bow, first, last in ((10, -4.0, 12, 27), (15, 0.6, 9, 24), (20, 3.6, 11, 27), (24, 2.2, 17, 27)):
        for y in range(first, last + 1):
            t = (y - first) / float(last - first)
            x = int(round(start + bow * t ** 1.6))
            if x in tops and tops[x] + 1 < y < COVER_BOTTOM - 1:
                px[x, y] = FLEECE_FOLD + (158,)
                lit = x + (1 if bow < 0 else -1)
                if lit in tops and tops[lit] + 1 < y:
                    px[lit, y] = FLEECE_LIGHT + (158,)
    # the rim, where the cloth turns away and looks thicker
    for x, top in tops.items():
        beside = min(tops.get(x - 1, COVER_BOTTOM), tops.get(x + 1, COVER_BOTTOM))
        outer = COVER_BOTTOM if x in (COVER_LEFT, COVER_RIGHT) else max(top + 1, beside)
        for y in range(top, min(outer, COVER_BOTTOM)):
            px[x, y] = FLEECE_RIM + (180,)
    # the hem lies on the soil: denser, and bunched and pegged at the corners
    for x in range(COVER_LEFT, COVER_RIGHT + 1):
        px[x, COVER_BOTTOM] = FLEECE + (200,)
        if rng.random() < 0.35:
            px[x, COVER_BOTTOM - 1] = FLEECE + (176,)
    for corner, inward in ((COVER_LEFT, 1), (COVER_RIGHT, -1)):
        for step in range(4):
            for y in range(COVER_BOTTOM - (2 if step < 2 else 1), COVER_BOTTOM + 1):
                px[corner + inward * step, y] = FLEECE_RIM + (232,)
        for y in (COVER_BOTTOM - 1, COVER_BOTTOM, COVER_BOTTOM + 1):
            px[corner + inward, y] = PEG + (255,)
        px[corner + inward * 2, COVER_BOTTOM - 1] = PEG + (255,)   # the peg's head
    return cell


# ---------------------------------------------------------------- cloche
GLASS = (214, 232, 242)
GLASS_EDGE = (236, 246, 252)
GLASS_RIM = (176, 204, 220)
GLINT = (255, 255, 255)
JAR_LEFT, JAR_RIGHT = 4, 27          # 24 wide
JAR_TOP, JAR_BOTTOM = 7, 29          # the bell; the knob stands on it, rows 4 to 6
JAR_MID = (JAR_LEFT + JAR_RIGHT) / 2.0
JAR_SHOULDER = 17                    # the dome ends here and the wall drops straight


def jar_span(y):
    """Leftmost and rightmost column of the bell in row y."""
    half = (JAR_RIGHT - JAR_LEFT + 1) / 2.0
    if y < JAR_SHOULDER:
        t = (JAR_SHOULDER - y) / float(JAR_SHOULDER - JAR_TOP + 0.5)
        half *= (1 - t ** 2.4) ** (1 / 2.4)      # a full, slightly square dome
    half = max(2.0, half)
    return int(math.ceil(JAR_MID - half)), int(math.floor(JAR_MID + half))


def cloche():
    rng = random.Random(2613)
    cell = Image.new("RGBA", (SIZE, SIZE), CLEAR)
    px = cell.load()
    inside = set()
    for y in range(JAR_TOP, JAR_BOTTOM + 1):
        left, right = jar_span(y)
        inside.update((x, y) for x in range(left, right + 1))
    for x, y in ((14, 4), (15, 4), (16, 4), (17, 4), (14, 5), (15, 5), (16, 5), (17, 5), (15, 6), (16, 6)):
        inside.add((x, y))                       # the knob and its neck
    for x, y in sorted(inside):
        edge = any((x + dx, y + dy) not in inside for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if edge:
            px[x, y] = GLASS_EDGE + (205,)
        else:
            # the glass looks a little thicker towards its walls
            wall = abs(x - JAR_MID) / ((JAR_RIGHT - JAR_LEFT) / 2.0)
            px[x, y] = GLASS + (52 + int(round(16 * wall ** 2)) + rng.randint(-2, 2),)
    left, right = jar_span(JAR_BOTTOM)
    for x in range(left, right + 1):             # the foot of the jar, bedded in the soil
        px[x, JAR_BOTTOM] = GLASS_RIM + (215,)
        if left < x < right:
            px[x, JAR_BOTTOM - 1] = GLASS_EDGE + (120,)
    px[15, 4] = GLINT + (240,)                   # a spark on the knob
    # highlights: a long streak following the left shoulder, a short one beside
    # it, and a faint reflection low on the right wall
    for y in range(11, 23):
        x = 7 if y > 13 else 8 if y > 11 else 9
        px[x, y] = GLINT + (225 if 13 <= y <= 19 else 170,)
    for y in range(10, 14):
        px[10 if y > 10 else 11, y] = GLINT + (190,)
    for y in range(19, 26):
        px[24, y] = GLINT + (112,)
    return cell


def new_states():
    """[(name, cell)] in sheet order."""
    return [("mulch", mulch()), ("row_cover", row_cover()), ("cloche", cloche())]


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


def build():
    """The sheet's bytes: the states side by side, one row."""
    states = new_states()
    sheet = Image.new("RGBA", (len(states) * SIZE, SIZE), CLEAR)
    lines = ["# BEGIN DMI", "version = 4.0", f"\twidth = {SIZE}", f"\theight = {SIZE}"]
    for at, (name, cell) in enumerate(states):
        sheet.paste(cell, (at * SIZE, 0))
        lines += [f'state = "{name}"', "\tdirs = 1", "\tframes = 1"]
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
def first_frames(path):
    """{state: first frame} of a 32px sheet, for the review sheet only."""
    data = path.read_bytes()
    sheet = Image.open(BytesIO(data)).convert("RGBA")
    columns = sheet.width // SIZE
    out, at, name, dirs = {}, 0, None, 1
    for row in description(data).splitlines():
        key, _, value = (part.strip() for part in row.partition("="))
        if key == "state":
            name = value.strip('"')
        elif key == "dirs":
            dirs = int(value)
        elif key == "frames":
            left, top = (at % columns) * SIZE, (at // columns) * SIZE
            out.setdefault(name, sheet.crop((left, top, left + SIZE, top + SIZE)))
            at += dirs * int(value)
    return out


PREVIEW_CROPS = (
    (None, None),
    ("icons/farming/vegetables.dmi", "tomato-grow3"),
    ("icons/farming/vegetables.dmi", "tomato-grow6"),
    ("icons/farming/plants.dmi", "wheat-grow4"),
    ("icons/farming/plants.dmi", "tobacco-grow6"),
)


def preview(data, path, zoom=4):
    """A column for each state and a row for each crop (the first row has no
    crop), on the ploughed soil tile: mulch under the crop, the covers over
    it. The last column is the bare crop."""
    covers = first_frames_of(data)
    soil = first_frames(ROOT / "icons/turf/floors.dmi")["dirt_ploughed"]
    sheets = {}
    gap = 2
    names = [name for name, _ in new_states()] + [None]
    out = Image.new("RGBA", (len(names) * (SIZE + gap) + gap, len(PREVIEW_CROPS) * (SIZE + gap) + gap), (24, 24, 28, 255))
    for row, (sheet, state) in enumerate(PREVIEW_CROPS):
        crop = None
        if sheet:
            if sheet not in sheets:
                sheets[sheet] = first_frames(ROOT / sheet)
            crop = sheets[sheet][state]
        for column, name in enumerate(names):
            view = soil.copy()
            if name == "mulch":
                view.alpha_composite(covers[name])
            if crop:
                view.alpha_composite(crop)
            if name and name != "mulch":
                view.alpha_composite(covers[name])
            out.paste(view, (gap + column * (SIZE + gap), gap + row * (SIZE + gap)))
    out = out.resize((out.width * zoom, out.height * zoom), Image.NEAREST)
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    out.save(path)


def first_frames_of(data):
    sheet = Image.open(BytesIO(data)).convert("RGBA")
    return {name: sheet.crop((at * SIZE, 0, (at + 1) * SIZE, SIZE)) for at, (name, _) in enumerate(new_states())}


def main():
    have = SHEET.read_bytes() if SHEET.exists() else None
    data = build()
    current = have is not None and same_sheet(have, data)
    if "--check" in sys.argv:
        if not current:
            print("stale: icons/obj/frost_covers.dmi")
            return 1
        print("frost cover states are current")
        return 0
    if not current:
        SHEET.write_bytes(data)
        print(f"wrote {SHEET.relative_to(ROOT)} ({len(data)} bytes)")
    else:
        print("frost cover states are current")
    if "--preview" in sys.argv:
        path = sys.argv[sys.argv.index("--preview") + 1]
        preview(SHEET.read_bytes(), path)
        print(f"wrote {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
