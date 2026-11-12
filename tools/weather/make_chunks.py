"""Build the icons the moving weather systems draw with (docs/weather-systems.md).

icons/effects/weather_chunks.dmi: each precipitation state of
icons/effects/weather.dmi tiled four by four into one 128 px icon, frame for
frame, so a client holds one image for sixteen tiles of rain. No pixel is
drawn here: the art is the existing weather sheet, repeated.

icons/effects/weather_roof.dmi: one solid 32 px state, the mask a roofed area
draws to cut the weather away.

    python3 tools/weather/make_chunks.py            # rewrite both icons
    python3 tools/weather/make_chunks.py --check    # exit 1 if either is stale
"""
import re
import struct
import sys
import zlib
from io import BytesIO
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "icons/effects/weather.dmi"
CHUNKS = ROOT / "icons/effects/weather_chunks.dmi"
ROOF = ROOT / "icons/effects/weather_roof.dmi"
STATES = ("rain1", "rain2", "rain3", "monsoon", "snow1", "snow2", "snow_storm", "sandstorm")
TILES = 4


def description(path):
    data = path.read_bytes()
    at = 8
    while at < len(data):
        length, kind = struct.unpack(">I4s", data[at:at + 8])
        body = data[at + 8:at + 8 + length]
        if kind == b"zTXt" and body.startswith(b"Description\0"):
            return zlib.decompress(body[len(b"Description\0") + 1:]).decode()
        at += 12 + length
    raise SystemExit(f"{path}: no DMI description")


def description_of(data):
    at = 8
    while at < len(data):
        length, kind = struct.unpack(">I4s", data[at:at + 8])
        body = data[at + 8:at + 8 + length]
        if kind == b"zTXt" and body.startswith(b"Description\0"):
            return zlib.decompress(body[len(b"Description\0") + 1:]).decode()
        at += 12 + length
    return None


def same_icon(path, data):
    """TRUE when the file at path holds the same pixels and DMI description
    as these bytes. The packed bytes themselves differ between zlib and
    Pillow versions, so they are not compared."""
    if not Path(path).exists():
        return False
    have = Path(path).read_bytes()
    if description_of(have) != description_of(data):
        return False
    a = Image.open(BytesIO(have)).convert("RGBA")
    b = Image.open(BytesIO(data)).convert("RGBA")
    return a.size == b.size and a.tobytes() == b.tobytes()


def states(path):
    """[(name, dirs, frames, [delays])] in sheet order, and the cell size."""
    text = description(path)
    width = int(re.search(r"width = (\d+)", text).group(1))
    height = int(re.search(r"height = (\d+)", text).group(1))
    found = []
    for block in text.split("state = ")[1:]:
        name = re.match(r'"([^"]*)"', block).group(1)
        dirs = int(re.search(r"dirs = (\d+)", block).group(1))
        frames = int(re.search(r"frames = (\d+)", block).group(1))
        delay = re.search(r"delay = ([\d.,]+)", block)
        delays = [float(d) for d in delay.group(1).split(",")] if delay else []
        found.append((name, dirs, frames, delays))
    return found, width, height


def number(value):
    return str(int(value)) if value == int(value) else str(value)


def dmi_bytes(size, entries):
    """entries: [(name, [frame images], [delays])], one direction each."""
    total = sum(len(frames) for _, frames, _ in entries)
    columns = max(1, int(total ** 0.5 + 0.9999))
    rows = -(-total // columns)
    sheet = Image.new("RGBA", (columns * size, rows * size), (0, 0, 0, 0))
    lines = ["# BEGIN DMI", "version = 4.0", f"\twidth = {size}", f"\theight = {size}"]
    at = 0
    for name, frames, delays in entries:
        lines += [f'state = "{name}"', "\tdirs = 1", f"\tframes = {len(frames)}"]
        if len(frames) > 1:
            lines.append("\tdelay = " + ",".join(number(d) for d in delays))
        for frame in frames:
            sheet.paste(frame, ((at % columns) * size, (at // columns) * size))
            at += 1
    lines.append("# END DMI\n")
    plain = BytesIO()
    sheet.save(plain, "PNG", optimize=True)
    data = plain.getvalue()
    body = b"Description\0\0" + zlib.compress("\n".join(lines).encode(), 9)
    chunk = struct.pack(">I", len(body)) + b"zTXt" + body + struct.pack(">I", zlib.crc32(b"zTXt" + body) & 0xFFFFFFFF)
    return data[:33] + chunk + data[33:]  # after IHDR


def build():
    found, width, height = states(SOURCE)
    sheet = Image.open(SOURCE).convert("RGBA")
    columns = sheet.width // width
    entries = []
    at = 0
    wanted = {}
    for name, dirs, frames, delays in found:
        if name in STATES and name not in wanted:
            if dirs != 1:
                raise SystemExit(f"{name}: expected one direction")
            cells = []
            for frame in range(frames):
                index = at + frame
                cell = sheet.crop(((index % columns) * width, (index // columns) * height,
                                   (index % columns + 1) * width, (index // columns + 1) * height))
                tiled = Image.new("RGBA", (width * TILES, height * TILES), (0, 0, 0, 0))
                for x in range(TILES):
                    for y in range(TILES):
                        tiled.paste(cell, (x * width, y * height))
                cells.append(tiled)
            wanted[name] = (cells, delays or [1])
        at += dirs * frames
    missing = [name for name in STATES if name not in wanted]
    if missing:
        raise SystemExit(f"weather.dmi lacks {missing}")
    for name in STATES:
        entries.append((name, wanted[name][0], wanted[name][1]))
    roof = Image.new("RGBA", (32, 32), (255, 255, 255, 255))
    return dmi_bytes(width * TILES, entries), dmi_bytes(32, [("roof", [roof], [])])


def main():
    chunks, roof = build()
    if "--check" in sys.argv:
        stale = [str(p.relative_to(ROOT)) for p, data in ((CHUNKS, chunks), (ROOF, roof)) if not same_icon(p, data)]
        if stale:
            print("stale:", ", ".join(stale))
            return 1
        print("weather icons are current")
        return 0
    CHUNKS.write_bytes(chunks)
    ROOF.write_bytes(roof)
    print(f"wrote {CHUNKS.relative_to(ROOT)} ({len(chunks)} bytes), {ROOF.relative_to(ROOT)} ({len(roof)} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
