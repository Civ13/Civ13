"""Fullscreen fog and mist vignettes for icons/effects/weather_fog.dmi. Every
pixel is computed by this script from the fixed numbers and the seeded noise
below (Pillow only); no external or generated artwork.

Two 128px states, one direction and one frame each, in pale grey
(200, 205, 210):

- fog_view: clear out to 14px from the centre, rising on a smoothstep to
  solid (alpha 255) at 29px and solid from there to every edge and corner.
- mist_view: clear out to 26px, rising to alpha 150 at 50px and holding that
  to the edges.

The cell is meant to be drawn on a player's screen centred on the player and
scaled up ten times, so one cell pixel is ten screen pixels and a 32px tile
is 3.2 cell pixels: fog clears about 4.5 tiles and closes at about 9, mist
clears about 8 tiles and levels off at about 15.5. The centre is the middle
of the cell, between pixels 63 and 64.

The edge is not a true circle: slow value noise moves the radius by at most
2px either way, so the bank has soft wisps. The grey is mottled by at most 6
levels, slowly, so the solid part is not flat. Nothing is sharp, because the
game scales the cell bilinearly. Clear pixels keep the fog colour under
alpha 0, so scaling does not pull a dark fringe into the edge.

    python3 tests/sprites/create_weather_fog.py                  # write the sheet
    python3 tests/sprites/create_weather_fog.py --check          # exit 1 if it is stale
    python3 tests/sprites/create_weather_fog.py --preview <png>  # also write a review sheet

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
SHEET = ROOT / "icons/effects/weather_fog.dmi"
SIZE = 128
CENTRE = (SIZE - 1) / 2.0    # 63.5: the middle of the cell, between pixels

FOG = (200, 205, 210)
WOBBLE = 2.0                 # most the edge radius moves, in pixels, either way
MOTTLE = 6                   # most the grey moves, in levels, either way

# (name, clear radius, full radius, top alpha, noise seed)
STATES = (
    ("fog_view", 14.0, 29.0, 255, 1713),
    ("mist_view", 26.0, 50.0, 150, 1714),
)


# ---------------------------------------------------------------- noise
class ValueNoise:
    """Seeded value noise on a square lattice, quintic-eased between the
    lattice points, in -1 .. 1."""

    def __init__(self, seed, cell):
        rng = random.Random(seed)
        self.cell = float(cell)
        self.side = int(SIZE // cell) + 3
        self.lattice = [[rng.uniform(-1.0, 1.0) for _ in range(self.side)] for _ in range(self.side)]

    def at(self, x, y):
        fx, fy = x / self.cell, y / self.cell
        ix, iy = int(fx), int(fy)
        tx, ty = fx - ix, fy - iy
        tx = tx * tx * tx * (tx * (tx * 6 - 15) + 10)
        ty = ty * ty * ty * (ty * (ty * 6 - 15) + 10)
        a, b = self.lattice[iy][ix], self.lattice[iy][ix + 1]
        c, d = self.lattice[iy + 1][ix], self.lattice[iy + 1][ix + 1]
        return (a + (b - a) * tx) * (1 - ty) + (c + (d - c) * tx) * ty


def soft_noise(seed, coarse, fine):
    """Two octaves, the coarse one twice as strong; stays inside -1 .. 1."""
    low, high = ValueNoise(seed, coarse), ValueNoise(seed + 7919, fine)
    return lambda x, y: (2 * low.at(x, y) + high.at(x, y)) / 3.0


def smoothstep(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- states
def vignette(clear, full, top, seed):
    edge = soft_noise(seed, 22, 11)          # where the bank begins
    grey = soft_noise(seed + 104729, 26, 13)  # mottling of the bank
    cell = Image.new("RGBA", (SIZE, SIZE), FOG + (0,))
    px = cell.load()
    for y in range(SIZE):
        for x in range(SIZE):
            radius = math.hypot(x - CENTRE, y - CENTRE) + WOBBLE * edge(x, y)
            alpha = int(round(top * smoothstep((radius - clear) / (full - clear))))
            shift = int(round(MOTTLE * grey(x, y)))
            px[x, y] = (FOG[0] + shift, FOG[1] + shift, FOG[2] + shift, alpha)
    return cell


def new_states():
    """[(name, cell)] in sheet order."""
    return [(name, vignette(clear, full, top, seed)) for name, clear, full, top, seed in STATES]


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
    sheet = Image.new("RGBA", (len(states) * SIZE, SIZE), (0, 0, 0, 0))
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
def preview(data, path, zoom=3):
    """Both states side by side over a mid-green checker of 3.2px tiles,
    enlarged bilinearly as the game does."""
    sheet = Image.open(BytesIO(data)).convert("RGBA")
    count = sheet.width // SIZE
    side, gap = SIZE * zoom, 8
    out = Image.new("RGBA", (count * side + (count + 1) * gap, side + 2 * gap), (24, 24, 28, 255))
    tile = 3.2 * zoom
    ground = Image.new("RGBA", (side, side))
    px = ground.load()
    for y in range(side):
        for x in range(side):
            px[x, y] = (86, 138, 70, 255) if (int(x / tile) + int(y / tile)) % 2 else (70, 118, 58, 255)
    for at in range(count):
        cell = sheet.crop((at * SIZE, 0, (at + 1) * SIZE, SIZE)).resize((side, side), Image.BILINEAR)
        view = ground.copy()
        view.alpha_composite(cell)
        out.paste(view, (gap + at * (side + gap), gap))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    out.save(path)


def main():
    have = SHEET.read_bytes() if SHEET.exists() else None
    data = build()
    current = have is not None and same_sheet(have, data)
    if "--check" in sys.argv:
        if not current:
            print("stale: icons/effects/weather_fog.dmi")
            return 1
        print("weather fog states are current")
        return 0
    if not current:
        SHEET.write_bytes(data)
        print(f"wrote {SHEET.relative_to(ROOT)} ({len(data)} bytes)")
    else:
        print("weather fog states are current")
    if "--preview" in sys.argv:
        path = sys.argv[sys.argv.index("--preview") + 1]
        preview(SHEET.read_bytes(), path)
        print(f"wrote {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
