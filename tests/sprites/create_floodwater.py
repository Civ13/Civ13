"""Script-drawn river floodwater for icons/effects/floodwater.dmi.

Every pixel is placed by this script from the fixed palettes below (Pillow
only); no external or generated artwork. Floodwater is muddy river water laid
over the ground tile as a see-through image, so the ground shows through the
shallow bands and disappears under the deep ones.

States, all 32x32:

  flood1 .. flood4            1 dir, 12 frames. Ankle, knee, waist and
                              over-the-head water. flood1 is a thin film with
                              a few ripples, flood4 is opaque and carries
                              current streaks that drift east.
  flood_edge1 .. flood_edge4  4 dirs (SOUTH, NORTH, EAST, WEST), 12 frames.
                              The ragged waterline of each band.
  flood_step2 .. flood_step4  4 dirs, 12 frames. Optional: the same band
                              thinning out over 9px with no foam, to lay on a
                              SHALLOWER flooded neighbour so the bands do not
                              meet in a straight line. Same dirs as the edges.
  silt1 .. silt4              1 dir, 1 frame. A light mud film for ground the
                              flood has just left. Each tiles with itself.

The ripple is the same net of drifting cells as the river: the frames, the
frame count and the per-frame delay come from create_water_animation.py, so a
flood tile ripples in step with icons/turf/beach.dmi water and the net runs
unbroken from the river across every band.

Edge direction convention. An edge image goes on the DRY tile next to a
flooded tile, and its dir is the direction from the water to that dry tile:

  dir     the dry tile is ...     water side of the image    fades toward
  SOUTH   south of the water      top (north) rows           the bottom
  NORTH   north of the water      bottom (south) rows        the top
  EAST    east of the water       left (west) columns        the right
  WEST    west of the water       right (east) columns       the left

So for a flooded turf T and a dry neighbour D, put flood_edge<band of T> on D
with dir = get_dir(T, D). The water reaches 4-8px into the dry tile, ends in
a thin broken foam line and a darker wet line, and laps one pixel in and out
over the loop. A dry tile with water on two sides takes one edge per side.
flood_step<band of T> follows the same rule, with D the shallower flooded
neighbour instead of a dry one.

Run with Pillow to rewrite icons/effects/floodwater.dmi (safe to rerun).
`--out <dmi>` writes the sheet somewhere else, `--gif <gif>` writes a tiled
review animation over grass, dirt and sand next to a river, `--check` only
verifies that the committed sheet is what this script draws. Released under
Civ13 AGPL-3.0.
"""
import math
import random
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_water_animation import DELAY, FRAMES, SIZE, pattern, read_dmi, write_dmi  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/effects/floodwater.dmi'
RIVER = ROOT / 'icons/turf/beach.dmi'
GROUND = ROOT / 'icons/turf/floors.dmi'

BANDS = (1, 2, 3, 4)
DIRS = ('SOUTH', 'NORTH', 'EAST', 'WEST')   # BYOND order for dirs = 4

# Per band, RGBA for the eight levels of the shared ripple pattern: four base
# shades from dark to light, then the ripple line from halo to core. The thin
# film hides the halo so only a few ripple cores show.
PALETTES = {
    1: [(126, 104, 66, 70), (134, 112, 72, 78), (140, 118, 78, 84), (148, 126, 84, 92),
        (148, 126, 84, 92), (156, 134, 92, 104), (178, 158, 114, 132), (196, 178, 134, 150)],
    2: [(122, 102, 64, 138), (128, 108, 68, 144), (134, 113, 72, 148), (140, 120, 78, 154),
        (148, 128, 86, 160), (164, 146, 100, 174), (180, 162, 116, 186), (194, 178, 132, 198)],
    3: [(88, 84, 50, 218), (94, 89, 53, 222), (98, 94, 57, 224), (105, 100, 62, 228),
        (113, 107, 68, 232), (128, 120, 78, 238), (142, 133, 89, 242), (156, 146, 101, 246)],
    4: [(66, 70, 46, 255), (71, 74, 48, 255), (75, 78, 52, 255), (81, 84, 56, 255),
        (89, 91, 61, 255), (104, 102, 68, 255), (118, 114, 77, 255), (132, 126, 87, 255)],
}
# Deep water only: a current streak from its faint tail to its bright crest,
# and the dark trough under the crest.
STREAK = [(104, 102, 70, 255), (138, 132, 92, 255), (174, 166, 122, 255)]
STREAK_DARK = (54, 58, 38, 255)
STREAKS = 5

# Waterline, per band: foam line and the wet ground just beyond it.
FOAM = {1: (212, 198, 158, 104), 2: (214, 200, 160, 144),
        3: (216, 202, 162, 176), 4: (218, 204, 164, 196)}
FOAM_SOFT = {1: (186, 168, 126, 70), 2: (184, 166, 122, 104),
             3: (172, 158, 114, 134), 4: (160, 150, 106, 156)}
WET = {1: (70, 56, 36, 46), 2: (66, 54, 34, 62), 3: (62, 52, 32, 76), 4: (58, 50, 32, 88)}
REACH = 6.0                              # mean distance the edge runs inland
FADE = (1.0, 1.0, 0.86, 0.7, 0.54, 0.4, 0.3, 0.3)   # alpha by distance inland
MAX_REACH = 9                            # nothing is drawn further inland
STEP_REACH = 8.0                         # the same for a step between bands
STEP_FADE = (1.0, 0.92, 0.82, 0.7, 0.58, 0.46, 0.34, 0.24, 0.14, 0.08, 0.08)
STEP_MAX_REACH = 11

# Silt film from thin to thick, then the darker damp fleck.
SILT = [(172, 152, 112, 44), (160, 140, 100, 72), (148, 128, 90, 100)]
SILT_FLECK = (108, 90, 62, 120)
SILT_SEEDS = (4101, 4102, 4103, 4104)


# ------------------------------------------------------------------- bodies

def streak_frames():
    """Per frame, {(x, y): colour} for the deep-water current streaks."""
    rng = random.Random(2917)
    rows = rng.sample(range(1, SIZE, 3), STREAKS)
    streaks = [(row, rng.uniform(0, SIZE), rng.randint(9, 14), rng.uniform(0, math.tau), rng.uniform(0, math.tau))
               for row in rows]
    frames = []
    for f in range(FRAMES):
        turn = math.tau * f / FRAMES
        marks = {}
        for row, start, length, phase, bend in streaks:
            # each streak drifts one tile east per loop and swells and fades
            swell = 0.62 + 0.38 * math.sin(turn + phase)
            span = int(round(length * swell))
            if span < 4:
                continue
            head = int(round(start + SIZE * f / FRAMES))
            for i in range(span):
                x = (head - i) % SIZE
                y = (row + int(round(0.7 * math.sin(i * 0.4 + bend)))) % SIZE
                near_end = min(i, span - 1 - i)
                marks[(x, y)] = STREAK[min(2, near_end // 2)]
                if near_end >= 3:
                    marks.setdefault((x, (y + 1) % SIZE), STREAK_DARK)
        frames.append(marks)
    return frames


def bodies():
    """{band: [FRAMES images]} of full-tile floodwater."""
    index = pattern()
    streaks = streak_frames()
    out = {}
    for band in BANDS:
        colours = PALETTES[band]
        frames = []
        for f, rows in enumerate(index):
            im = Image.new('RGBA', (SIZE, SIZE))
            px = im.load()
            for y in range(SIZE):
                for x in range(SIZE):
                    level = rows[y][x]
                    colour = colours[level]
                    if band == 4 and (x, y) in streaks[f]:
                        colour = streaks[f][(x, y)]
                    px[x, y] = colour
            frames.append(im)
        out[band] = frames
    return out


# -------------------------------------------------------------------- edges

def waterlines(seed, mean, limit):
    """{dir: [FRAMES lists of SIZE reaches]}: how far the water runs inland."""
    rng = random.Random(seed)
    out = {}
    for name in DIRS:
        waves = [(k, rng.uniform(0, math.tau), amp) for k, amp in ((1, 0.9), (2, 0.7), (3, 0.5), (5, 0.35))]
        jag = [rng.choice((-1, 0, 0, 0, 1)) for _ in range(SIZE)]
        lap_phase = rng.uniform(0, math.tau)
        frames = []
        for f in range(FRAMES):
            turn = math.tau * f / FRAMES
            line = []
            for a in range(SIZE):
                reach = mean + sum(amp * math.sin(math.tau * k * a / SIZE + ph) for k, ph, amp in waves)
                reach += jag[a] + 0.9 * math.sin(turn + lap_phase + math.tau * 2 * a / SIZE)
                line.append(max(3, min(limit - 1, int(round(reach)))))
            frames.append(line)
        out[name] = frames
    return out


def foam_runs():
    """{dir: SIZE values}: 0 no foam, 1 soft foam, 2 bright foam, in runs."""
    rng = random.Random(7349)
    out = {}
    for name in DIRS:
        run = []
        while len(run) < SIZE:
            run += [rng.choice((2, 2, 1, 1, 0))] * rng.randint(2, 5)
        out[name] = run[:SIZE]
    return out


def inland(name, x, y):
    """(distance from the water side, position along the waterline)."""
    if name == 'SOUTH':
        return y, x
    if name == 'NORTH':
        return SIZE - 1 - y, x
    if name == 'EAST':
        return x, y
    return SIZE - 1 - x, y


def edge(body, band, name, line, foam):
    """One waterline image; foam is None for a foamless step between bands."""
    fade = FADE if foam else STEP_FADE
    im = Image.new('RGBA', (SIZE, SIZE))
    px, src = im.load(), body.load()
    for y in range(SIZE):
        for x in range(SIZE):
            t, a = inland(name, x, y)
            reach = line[a]
            if foam and t == reach - 1 and foam[a]:
                px[x, y] = FOAM[band] if foam[a] == 2 else FOAM_SOFT[band]
            elif foam and t == reach:
                px[x, y] = WET[band]
            elif t < reach:
                r, g, b, alpha = src[x, y]
                px[x, y] = (r, g, b, int(round(alpha * fade[t])))
    return im


def edges(body_frames):
    """{band: [FRAMES x 4 images]} in sheet order: each frame, dirs in turn."""
    lines, foam = waterlines(5521, REACH, MAX_REACH), foam_runs()
    return {band: [edge(body_frames[band][f], band, name, lines[name][f], foam[name])
                   for f in range(FRAMES) for name in DIRS]
            for band in BANDS}


def steps(body_frames):
    """The same for the foamless steps of bands 2-4 onto shallower water."""
    lines = waterlines(6143, STEP_REACH, STEP_MAX_REACH)
    return {band: [edge(body_frames[band][f], band, name, lines[name][f], None)
                   for f in range(FRAMES) for name in DIRS]
            for band in BANDS[1:]}


# --------------------------------------------------------------------- silt

def silt(seed):
    rng = random.Random(seed)
    waves = [(kx, ky, rng.uniform(0, math.tau), amp)
             for kx, ky, amp in ((1, 0, 1.0), (0, 1, 1.0), (1, 1, 0.8), (1, -1, 0.8),
                                 (2, 1, 0.5), (1, -2, 0.5), (3, 2, 0.3), (2, -3, 0.3))]
    grain = [[rng.uniform(-0.3, 0.3) for _ in range(SIZE)] for _ in range(SIZE)]
    flecks = set((rng.randrange(SIZE), rng.randrange(SIZE)) for _ in range(10))
    im = Image.new('RGBA', (SIZE, SIZE))
    px = im.load()
    for y in range(SIZE):
        for x in range(SIZE):
            tone = sum(amp * math.sin(math.tau * (kx * x + ky * y) / SIZE + ph) for kx, ky, ph, amp in waves) / 2.2
            tone += grain[y][x]
            if tone < -0.3:
                continue
            level = 0 if tone < 0.1 else 1 if tone < 0.6 else 2
            px[x, y] = SILT_FLECK if (x, y) in flecks and level else SILT[level]
    return im


# -------------------------------------------------------------------- sheet

def loop_keys(dirs):
    return {'dirs': str(dirs), 'frames': str(FRAMES), 'delay': ','.join([str(DELAY)] * FRAMES)}


def build():
    """The whole sheet as [(state, keys, images)]."""
    body_frames = bodies()
    edge_frames, step_frames = edges(body_frames), steps(body_frames)
    states = [('flood%d' % band, loop_keys(1), body_frames[band]) for band in BANDS]
    states += [('flood_edge%d' % band, loop_keys(len(DIRS)), edge_frames[band]) for band in BANDS]
    states += [('flood_step%d' % band, loop_keys(len(DIRS)), step_frames[band]) for band in BANDS[1:]]
    states += [('silt%d' % (i + 1), {'dirs': '1', 'frames': '1'}, [silt(seed)])
               for i, seed in enumerate(SILT_SEEDS)]
    return states


def pixels(im):
    raw = im.convert('RGBA').tobytes()
    return [tuple(raw[i:i + 4]) for i in range(0, len(raw), 4)]


def check_drawing(states):
    """Rules the drawing itself must keep, whatever the palettes become."""
    by = {name: images for name, _, images in states}
    problems = []
    for band in BANDS:
        allowed = set(PALETTES[band]) | (set(STREAK) | {STREAK_DARK} if band == 4 else set())
        body = by['flood%d' % band]
        if any(not set(pixels(im)) <= allowed for im in body):
            problems.append('flood%d uses a colour outside its palette' % band)
        for state, limit in (('flood_edge%d' % band, MAX_REACH), ('flood_step%d' % band, STEP_MAX_REACH)):
            for i, im in enumerate(by.get(state, ())):
                name, src = DIRS[i % len(DIRS)], body[i // len(DIRS)].load()
                px = im.load()
                spots = [(x, y) + inland(name, x, y)[:1] for y in range(SIZE) for x in range(SIZE)]
                if any(t == 0 and px[x, y] != src[x, y] for x, y, t in spots):
                    problems.append('%s %s does not meet its water' % (state, name))
                    break
                if any(t >= limit and px[x, y][3] for x, y, t in spots):
                    problems.append('%s %s runs too far inland' % (state, name))
                    break
    for name, _, images in states:
        if any(p[3] == 0 and p != (0, 0, 0, 0) for im in images for p in pixels(im)):
            problems.append('%s has coloured invisible pixels' % name)
    return problems


def check_sheet(path, states):
    """The committed sheet is exactly what build() draws."""
    if not Path(path).exists():
        return ['%s is missing' % path]
    have = read_dmi(path)
    problems = []
    if [name for name, _, _ in have] != [name for name, _, _ in states]:
        return ['state list differs: %s' % ', '.join(name for name, _, _ in have)]
    for (name, keys, images), (_, want_keys, want_images) in zip(have, states):
        if keys != want_keys:
            problems.append('%s has dirs/frames/delay %r, expected %r' % (name, keys, want_keys))
        elif any(pixels(a) != pixels(b) for a, b in zip(images, want_images)):
            problems.append('%s is not what this script draws' % name)
    return problems


# ------------------------------------------------------------------- review

def ground_tiles():
    """Grass, dirt and sand from the game sheets, or flat stand-ins."""
    flat = {'grass0': (82, 110, 52), 'dirt': (112, 88, 60), 'sand': (206, 190, 140)}
    found = {}
    try:
        found = {name: images[0] for name, _, images in read_dmi(GROUND) if name in flat and images}
    except Exception:
        pass
    return [found.get(name) or Image.new('RGBA', (SIZE, SIZE), colour + (255,)) for name, colour in flat.items()]


def write_gif(path, states, scale=3):
    """A river, the four bands running inland from it, an islet and silt."""
    by = {name: images for name, _, images in states}
    river = {name: images for name, _, images in read_dmi(RIVER)}['seashallow']
    grass, dirt, sand = ground_tiles()
    wide, high = 10, 7
    ground_rows = [grass, grass, grass, dirt, dirt, sand, sand]
    band_at = {2: 4, 3: 3, 4: 2, 5: 1}      # column -> band, deepest by the river
    islet = (4, 3)
    towards = {'SOUTH': (0, 1), 'NORTH': (0, -1), 'EAST': (1, 0), 'WEST': (-1, 0)}

    def flooded(tx, ty):
        return tx in band_at and 1 <= ty <= 5 and (tx, ty) != islet

    out = []
    for f in range(FRAMES):
        im = Image.new('RGBA', (wide * SIZE, high * SIZE))
        for ty in range(high):
            for tx in range(wide):
                at = (tx * SIZE, ty * SIZE)
                if tx < 2:
                    im.paste(river[f], at)
                    continue
                im.paste(ground_rows[ty], at)
                if flooded(tx, ty):
                    im.alpha_composite(by['flood%d' % band_at[tx]][f], at)
                for d, (name, (dx, dy)) in enumerate(towards.items()):
                    # the water tile lies opposite the edge's dir
                    wx, wy = tx - dx, ty - dy
                    if not flooded(wx, wy):
                        continue
                    if flooded(tx, ty):
                        if band_at[wx] > band_at[tx]:
                            im.alpha_composite(by['flood_step%d' % band_at[wx]][f * len(DIRS) + d], at)
                    else:
                            im.alpha_composite(by['flood_edge%d' % band_at[wx]][f * len(DIRS) + d], at)
                if tx >= 8 and 1 <= ty <= 5:
                    im.alpha_composite(by['silt%d' % ((tx + ty) % len(SILT_SEEDS) + 1)][0], at)
        im = im.convert('RGB')
        out.append(im.resize((im.width * scale, im.height * scale), Image.NEAREST))
    out[0].save(path, save_all=True, append_images=out[1:], duration=DELAY * 100, loop=0)


def option(name):
    args = sys.argv[1:]
    return args[args.index(name) + 1] if name in args[:-1] else None


def main():
    states = build()
    problems = check_drawing(states)
    if '--check' in sys.argv:
        problems += check_sheet(option('--sheet') or SHEET, states)
        for line in problems:
            print(line)
        print('floodwater: %s' % ('FAILED' if problems else 'ok'))
        return 1 if problems else 0
    if problems:
        print('\n'.join(problems))
        return 1
    write_dmi(option('--out') or SHEET, states)
    if option('--gif'):
        write_gif(option('--gif'), states)
    return 0


if __name__ == '__main__':
    sys.exit(main())
