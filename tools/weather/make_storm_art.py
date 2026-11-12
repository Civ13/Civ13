"""Draw the storm art of the moving weather systems (docs/weather-systems.md).

icons/effects/weather_storm.dmi, 128 px (four tiles):
  shadow_n .. shadow_nw   the mottled shadow of storm cloud, sixteen frames
                          that slide one whole icon in the named direction, so
                          neighbouring pieces join and the loop has no jump
icons/effects/weather_bolt.dmi, 64 x 160 px:
  bolt1 .. bolt4          forked lightning standing on its tile; the game
                          flickers and fades it

Every pixel is placed by the code below from a fixed seed: no image
generation, no borrowed art.

    python3 tools/weather/make_storm_art.py            # rewrite the icons
    python3 tools/weather/make_storm_art.py --check    # exit 1 if stale
    python3 tools/weather/make_storm_art.py --preview out.gif
"""
import random
import struct
import sys
import zlib
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_chunks import same_icon  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
STORM = ROOT / "icons/effects/weather_storm.dmi"
BOLT = ROOT / "icons/effects/weather_bolt.dmi"
SIZE = 128
FRAMES = 16
# name, pixels moved per frame (x right, y up)
DRIFT = (("n", 0, 1), ("ne", 1, 1), ("e", 1, 0), ("se", 1, -1),
         ("s", 0, -1), ("sw", -1, -1), ("w", -1, 0), ("nw", -1, 1))
BOLT_W, BOLT_H = 64, 160


def number(value):
    return str(int(value)) if value == int(value) else str(value)


def dmi_bytes(width, height, entries):
    """entries: [(name, [frame images], [delays])], one direction each."""
    total = sum(len(frames) for _, frames, _ in entries)
    columns = max(1, int(total ** 0.5 + 0.9999))
    rows = -(-total // columns)
    sheet = Image.new("RGBA", (columns * width, rows * height), (0, 0, 0, 0))
    lines = ["# BEGIN DMI", "version = 4.0", f"\twidth = {width}", f"\theight = {height}"]
    at = 0
    for name, frames, delays in entries:
        lines += [f'state = "{name}"', "\tdirs = 1", f"\tframes = {len(frames)}"]
        if len(frames) > 1:
            lines.append("\tdelay = " + ",".join(number(d) for d in delays))
        for frame in frames:
            sheet.paste(frame, ((at % columns) * width, (at // columns) * height))
            at += 1
    lines.append("# END DMI\n")
    plain = BytesIO()
    sheet.save(plain, "PNG", optimize=True)
    data = plain.getvalue()
    body = b"Description\0\0" + zlib.compress("\n".join(lines).encode(), 9)
    chunk = struct.pack(">I", len(body)) + b"zTXt" + body + struct.pack(">I", zlib.crc32(b"zTXt" + body) & 0xFFFFFFFF)
    return data[:33] + chunk + data[33:]  # after IHDR


def cloud_field():
    """A 128 x 128 field of 0..1 that wraps on both edges: soft cloud masses."""
    rng = random.Random(1713)
    total = None
    for cells, weight in ((4, 1.0), (8, 0.5), (16, 0.22)):
        grid = Image.new("L", (cells, cells))
        grid.putdata([rng.randrange(256) for _ in range(cells * cells)])
        # Three by three copies, scaled up, middle kept: the edges then wrap.
        wide = Image.new("L", (cells * 3, cells * 3))
        for gx in range(3):
            for gy in range(3):
                wide.paste(grid, (gx * cells, gy * cells))
        wide = wide.resize((SIZE * 3, SIZE * 3), Image.BICUBIC).crop((SIZE, SIZE, SIZE * 2, SIZE * 2))
        values = [v * weight for v in wide.tobytes()]
        total = values if total is None else [t + v for t, v in zip(total, values)]
    low, high = min(total), max(total)
    return [[(total[y * SIZE + x] - low) / (high - low) for x in range(SIZE)] for y in range(SIZE)]


def shadow_frames():
    field = cloud_field()
    # Alpha in twelve soft steps, 44 to 176 of 255: never clear, never black.
    base = Image.new("L", (SIZE, SIZE))
    pixels = base.load()
    for y in range(SIZE):
        for x in range(SIZE):
            step = min(11, int(field[y][x] * 12))
            pixels[x, y] = 44 + step * 12
    step_px = SIZE // FRAMES
    states = []
    for name, dx, dy in DRIFT:
        frames = []
        for frame in range(FRAMES):
            # Image y runs down, the map's y runs up.
            shift_x = (dx * step_px * frame) % SIZE
            shift_y = (-dy * step_px * frame) % SIZE
            alpha = Image.new("L", (SIZE, SIZE))
            for ox in (shift_x - SIZE, shift_x):
                for oy in (shift_y - SIZE, shift_y):
                    alpha.paste(base, (ox, oy))
            image = Image.new("RGBA", (SIZE, SIZE), (14, 18, 30, 0))
            image.putalpha(alpha)
            frames.append(image)
        states.append((f"shadow_{name}", frames, [4] * FRAMES))
    return states


def bolt_image(seed, glow):
    """One forked bolt from the top of the icon to the ground at its foot."""
    rng = random.Random(seed)
    image = Image.new("RGBA", (BOLT_W, BOLT_H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    def strike(x, y, end_y, width, depth):
        points = [(x, y)]
        while y < end_y:
            y = min(end_y, y + rng.randint(7, 15))
            x = max(4, min(BOLT_W - 5, x + rng.randint(-9, 9)))
            points.append((x, y))
            if depth < 2 and rng.random() < 0.28 and y < end_y - 24:
                strike(x, y, min(end_y - 8, y + rng.randint(20, 50)), 1, depth + 1)
        return points, width

    branches = []
    trunk, width = strike(BOLT_W // 2 + rng.randint(-10, 10), 0, BOLT_H - 17, 2, 0)
    # Pull the foot to the middle of the tile it stands on.
    trunk[-1] = (BOLT_W // 2, BOLT_H - 17)
    branches.append((trunk, 2))
    rng2 = random.Random(seed * 7)
    for i in range(1, len(trunk) - 2):
        if rng2.random() < 0.3:
            x, y = trunk[i]
            fork = [(x, y)]
            lean = rng2.choice((-1, 1))
            for _ in range(rng2.randint(2, 4)):
                x = max(3, min(BOLT_W - 4, x + lean * rng2.randint(3, 9)))
                y = min(BOLT_H - 24, y + rng2.randint(6, 13))
                fork.append((x, y))
            branches.append((fork, 1))
    if glow:
        halo = Image.new("RGBA", (BOLT_W, BOLT_H), (0, 0, 0, 0))
        halo_draw = ImageDraw.Draw(halo)
        for points, width in branches:
            halo_draw.line(points, fill=(150, 170, 255, 150), width=width + 4)
        image = halo.filter(ImageFilter.GaussianBlur(2))
        draw = ImageDraw.Draw(image)
    for points, width in branches:
        draw.line(points, fill=(190, 205, 255, 255), width=width + 1)
    for points, width in branches:
        draw.line(points, fill=(255, 255, 255, 255), width=width)
    return image


def faded(image, share):
    out = image.copy()
    out.putalpha(image.getchannel("A").point(lambda a: int(a * share)))
    return out


def bolt_states():
    states = []
    for index, seed in enumerate((11, 29, 47, 83), start=1):
        states.append((f"bolt{index}", [bolt_image(seed, True)], []))
    return states


def build():
    storm = dmi_bytes(SIZE, SIZE, shadow_frames())
    bolt = dmi_bytes(BOLT_W, BOLT_H, bolt_states())
    return storm, bolt


def preview(path):
    """Grass-coloured ground, the shadow sliding east over it, and a bolt."""
    shadows = dict((name, frames) for name, frames, _ in shadow_frames())
    bolts = bolt_states()
    frames = []
    rng = random.Random(5)
    ground = Image.new("RGBA", (SIZE * 3, SIZE * 2), (86, 122, 62, 255))
    for _ in range(2500):
        x, y = rng.randrange(ground.width), rng.randrange(ground.height)
        ground.putpixel((x, y), rng.choice(((74, 108, 54, 255), (98, 136, 70, 255), (110, 100, 70, 255))))
    for frame in range(FRAMES * 2):
        scene = ground.copy()
        for tx in range(3):
            for ty in range(2):
                piece = shadows["shadow_e"][frame % FRAMES]
                # The storm thins toward the right edge of the view.
                piece = faded(piece, (1.0, 0.75, 0.4)[tx])
                scene.alpha_composite(piece, (tx * SIZE, ty * SIZE))
        if 10 <= frame <= 12:
            bolt = faded(bolts[1][1][0], (1.0, 0.6, 0.3)[frame - 10])
            scene.alpha_composite(bolt, (150, 40))
            if frame == 10:
                scene = Image.blend(scene, Image.new("RGBA", scene.size, (255, 255, 255, 255)), 0.3)
        frames.append(scene.convert("RGB").resize((scene.width * 2, scene.height * 2), Image.NEAREST))
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=400, loop=0)
    print(f"wrote {path}")


def main():
    if "--preview" in sys.argv:
        preview(sys.argv[sys.argv.index("--preview") + 1])
        return 0
    storm, bolt = build()
    if "--check" in sys.argv:
        stale = [str(p.relative_to(ROOT)) for p, data in ((STORM, storm), (BOLT, bolt)) if not same_icon(p, data)]
        if stale:
            print("stale:", ", ".join(stale))
            return 1
        print("storm art is current")
        return 0
    STORM.write_bytes(storm)
    BOLT.write_bytes(bolt)
    print(f"wrote {STORM.relative_to(ROOT)} ({len(storm)} bytes), {BOLT.relative_to(ROOT)} ({len(bolt)} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
