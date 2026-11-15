"""Draw the storm art of the moving weather systems (docs/weather-systems.md).

icons/effects/weather_storm.dmi, 128 px (four tiles):
  shadow_<wind>_<qx><qy>  the mottled shadow of storm cloud. The cloud is one
                          field eight tiles on a side, cut in four pieces
                          (qx, qy = 0 or 1, west to east and south to north),
                          so the pattern repeats every eight tiles and not
                          every four. Its thirty-two frames slide the whole
                          field once round in the direction the named wind
                          carries it (n, e, s or w), so neighbouring pieces
                          join and the loop has no jump
icons/effects/weather_edge.dmi, 128 px:
  m<sw><se><nw><ne>       the fade of a piece on the storm's edge: white, with
                          an opacity that runs evenly between the levels (0 to
                          3) at its four corners. The game lays it over the
                          piece as an alpha mask. A corner is shared by the
                          pieces round it, so the fade has no step
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
EDGE = ROOT / "icons/effects/weather_edge.dmi"
EDGE_LEVELS = 3
SIZE = 128
FIELD = SIZE * 2
FRAMES = 32
# name, pixels moved per frame (x right, y up). The wind has four quarters.
DRIFT = (("n", 0, 1), ("e", 1, 0), ("s", 0, -1), ("w", -1, 0))
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
    """A 256 x 256 field of 0..1 that wraps on both edges: soft cloud masses."""
    rng = random.Random(1713)
    total = None
    for cells, weight in ((4, 1.0), (8, 0.6), (16, 0.3), (32, 0.12)):
        grid = Image.new("L", (cells, cells))
        grid.putdata([rng.randrange(256) for _ in range(cells * cells)])
        # Three by three copies, scaled up, middle kept: the edges then wrap.
        wide = Image.new("L", (cells * 3, cells * 3))
        for gx in range(3):
            for gy in range(3):
                wide.paste(grid, (gx * cells, gy * cells))
        wide = wide.resize((FIELD * 3, FIELD * 3), Image.BICUBIC).crop((FIELD, FIELD, FIELD * 2, FIELD * 2))
        values = [v * weight for v in wide.tobytes()]
        total = values if total is None else [t + v for t, v in zip(total, values)]
    low, high = min(total), max(total)
    return [[(total[y * FIELD + x] - low) / (high - low) for x in range(FIELD)] for y in range(FIELD)]


def shadow_field():
    """The whole cloud as an alpha image, in twelve soft steps, 44 to 176 of
    255: never clear, never black."""
    field = cloud_field()
    base = Image.new("L", (FIELD, FIELD))
    pixels = base.load()
    for y in range(FIELD):
        for x in range(FIELD):
            step = min(11, int(field[y][x] * 12))
            pixels[x, y] = 44 + step * 12
    return base


def shifted_field(base, dx, dy, frame):
    """The field moved frame steps the way (dx, dy) points, wrapping."""
    step_px = FIELD // FRAMES
    # Image y runs down, the map's y runs up.
    shift_x = (dx * step_px * frame) % FIELD
    shift_y = (-dy * step_px * frame) % FIELD
    alpha = Image.new("L", (FIELD, FIELD))
    for ox in (shift_x - FIELD, shift_x):
        for oy in (shift_y - FIELD, shift_y):
            alpha.paste(base, (ox, oy))
    return alpha


def shadow_frames():
    base = shadow_field()
    states = []
    for name, dx, dy in DRIFT:
        moved = [shifted_field(base, dx, dy, frame) for frame in range(FRAMES)]
        for qx in (0, 1):
            for qy in (0, 1):
                frames = []
                # qy 0 is the south half: the lower rows of the image.
                box = (qx * SIZE, (1 - qy) * SIZE, qx * SIZE + SIZE, (1 - qy) * SIZE + SIZE)
                for alpha in moved:
                    image = Image.new("RGBA", (SIZE, SIZE), (14, 18, 30, 0))
                    image.putalpha(alpha.crop(box))
                    frames.append(image)
                states.append((f"shadow_{name}_{qx}{qy}", frames, [4] * FRAMES))
    return states


def edge_mask(sw, se, nw, ne):
    """White, its opacity running evenly between the four corner levels."""
    alpha = Image.new("L", (SIZE, SIZE))
    pixels = alpha.load()
    for py in range(SIZE):
        # Image y runs down, the map's y runs up.
        v = 1 - (py + 0.5) / SIZE
        for px in range(SIZE):
            u = (px + 0.5) / SIZE
            level = (sw * (1 - u) + se * u) * (1 - v) + (nw * (1 - u) + ne * u) * v
            pixels[px, py] = round(255 * level / EDGE_LEVELS)
    image = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    image.putalpha(alpha)
    return image


def edge_states():
    """Every mix of corner levels but nothing at all and the whole piece."""
    states = []
    levels = range(EDGE_LEVELS + 1)
    for sw in levels:
        for se in levels:
            for nw in levels:
                for ne in levels:
                    if sw == se == nw == ne and sw in (0, EDGE_LEVELS):
                        continue
                    states.append((f"m{sw}{se}{nw}{ne}", [edge_mask(sw, se, nw, ne)], []))
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


def build_edge():
    return dmi_bytes(SIZE, SIZE, edge_states())


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
                piece = shadows[f"shadow_e_{tx % 2}{(1 - ty) % 2}"][frame % FRAMES]
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
        stale = [str(p.relative_to(ROOT)) for p, data in ((STORM, storm), (BOLT, bolt), (EDGE, build_edge())) if not same_icon(p, data)]
        if stale:
            print("stale:", ", ".join(stale))
            return 1
        print("storm art is current")
        return 0
    STORM.write_bytes(storm)
    BOLT.write_bytes(bolt)
    EDGE.write_bytes(build_edge())
    print(f"wrote {STORM.relative_to(ROOT)} ({len(storm)} bytes), {BOLT.relative_to(ROOT)} ({len(bolt)} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
