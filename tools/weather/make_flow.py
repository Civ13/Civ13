"""Draw the flow lines of running water and sea currents (docs/river-flow.md).

icons/turf/water_flow.dmi, 32 px, one state for each of the eight directions
(flow_north .. flow_northwest) in two variants (the second ends in "2"), so
a wide current is not one tile repeated. A few pale streaks slide the way the water
runs, eight frames to cross one tile, so neighbouring tiles join and the loop
has no jump. The streaks are clear enough to read the direction and faint
enough to leave the water under them its own look.

Every pixel is placed by the code below from a fixed seed: no image
generation, no borrowed art.

    python3 tools/weather/make_flow.py            # rewrite the icon
    python3 tools/weather/make_flow.py --check    # exit 1 if stale
    python3 tools/weather/make_flow.py --preview out.gif
"""
import random
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_chunks import same_icon  # noqa: E402
from make_storm_art import dmi_bytes  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
FLOW = ROOT / "icons/turf/water_flow.dmi"
SIZE = 32
FRAMES = 8
DELAY = 2
COLOUR = (226, 240, 255)
# name, unit step (x right, y up)
DIRECTIONS = (("north", 0, 1), ("northeast", 1, 1), ("east", 1, 0), ("southeast", 1, -1),
              ("south", 0, -1), ("southwest", -1, -1), ("west", -1, 0), ("northwest", -1, 1))


def streaks(rng, diagonal):
    """[(across, along, length, strength)]: where each streak starts in the
    tile, measured across and along the flow."""
    found = []
    lanes = [3, 11, 19, 27] if not diagonal else [2, 10, 18, 26]
    for lane in lanes:
        found.append((lane + rng.randint(-1, 1), rng.randrange(SIZE), rng.randint(6, 10), rng.choice((70, 84, 96))))
    return found


def frame(direction, shift, marks):
    _, dx, dy = direction
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    pixels = image.load()
    for across, along, length, strength in marks:
        for i in range(length):
            # The head is brightest and the tail fades out behind it.
            alpha = int(strength * (i + 1) / length)
            travelled = along + shift + i
            if dx and dy:
                # A diagonal streak: along is the step count on both axes.
                x = (across + dx * travelled) % SIZE
                y = (-dy * travelled) % SIZE
            elif dx:
                x = (dx * travelled) % SIZE
                y = across % SIZE
            else:
                x = across % SIZE
                y = (-dy * travelled) % SIZE
            if pixels[x, y][3] < alpha:
                pixels[x, y] = COLOUR + (alpha,)
    return image


def states():
    out = []
    for variant, seed in (("", 1713), ("2", 1805)):
        for direction in DIRECTIONS:
            rng = random.Random(seed)
            marks = streaks(rng, direction[1] and direction[2])
            step = SIZE // FRAMES
            out.append((f"flow_{direction[0]}{variant}", [frame(direction, step * n, marks) for n in range(FRAMES)], [DELAY] * FRAMES))
    return out


def build():
    return dmi_bytes(SIZE, SIZE, states())


def preview(path):
    """A bend of sea-blue water: east along the top, turning south."""
    by_name = dict((name, frames) for name, frames, _ in states())
    layout = [["east", "east", "east", "southeast"],
              [None, None, None, "south"],
              [None, None, None, "south"]]
    frames = []
    for n in range(FRAMES):
        scene = Image.new("RGBA", (SIZE * 4, SIZE * 3), (66, 132, 181, 255))
        for ty, row in enumerate(layout):
            for tx, name in enumerate(row):
                if name:
                    variant = "2" if (tx * 3 + ty * 5) % 2 else ""
                    scene.alpha_composite(by_name[f"flow_{name}{variant}"][n], (tx * SIZE, ty * SIZE))
        frames.append(scene.convert("RGB").resize((scene.width * 3, scene.height * 3), Image.NEAREST))
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=DELAY * 100, loop=0)
    print(f"wrote {path}")


def main():
    if "--preview" in sys.argv:
        preview(sys.argv[sys.argv.index("--preview") + 1])
        return 0
    data = build()
    if "--check" in sys.argv:
        if not same_icon(FLOW, data):
            print("stale: icons/turf/water_flow.dmi")
            return 1
        print("flow lines are current")
        return 0
    FLOW.write_bytes(data)
    print(f"wrote {FLOW.relative_to(ROOT)} ({len(data)} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
