"""Script-drawn scum film for fouled river water, icons/effects/water_scum.dmi.

Every pixel is placed by this script from the fixed palettes below (Pillow
only); no external or generated artwork. The scum is a thin, see-through film
laid as an image over an open fresh-water tile in a reach fouled by sewage or
carcasses upstream. The animated water underneath keeps showing through it.

States, all 32x32, 1 dir, 3 frames at 9 ticks each (a 2.7 second loop):

  scum1   light: a few faint patches and three foam flecks, barely there
  scum2   medium: the patches join up, an oily sheen starts to show
  scum3   heavy: most of the tile is filmed over, with sheen and more foam

The three states are cut from one field, so a heavier state covers everything
the lighter one does and a tile can step between them without the patches
jumping. Every frame wraps on a 32px torus: a tile joins itself and any other
scum tile on all four sides, whatever the mix of states. Over the loop the
patch outlines breathe by about a pixel and the foam flecks circle a pixel
around their spot, then the last frame leads back into the first.

The loop is deliberately slower than, and not in step with, the 12-frame
water loop from create_water_animation.py: the film sits on the water rather
than rippling with it.

Run with Pillow to rewrite icons/effects/water_scum.dmi (safe to rerun).
`--out <dmi>` writes the sheet somewhere else, `--preview <png>` writes a
labelled review sheet of each state tiled 3x3 over river water, `--check`
only verifies that the committed sheet is what this script draws. Released
under Civ13 AGPL-3.0.
"""
import math
import random
import sys
from pathlib import Path
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_water_animation import SIZE, read_dmi, write_dmi  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/effects/water_scum.dmi'
RIVER = ROOT / 'icons/turf/beach.dmi'

LEVELS = (1, 2, 3)
FRAMES = 3
DELAY = 9          # ticks per frame

# Per level: film from thin to thick, the grey-yellow oily sheen, then foam
# from soft to bright. Alpha does the work: scum1 is close to nothing.
PALETTES = {
    1: {'film': [(96, 98, 54, 20), (90, 92, 48, 34)],
        'sheen': (168, 160, 98, 30),
        'foam': [(206, 200, 160, 64), (226, 222, 190, 96)]},
    2: {'film': [(96, 98, 54, 40), (90, 92, 48, 62), (82, 84, 44, 78)],
        'sheen': (172, 164, 100, 62),
        'foam': [(206, 200, 160, 100), (228, 224, 192, 140)]},
    3: {'film': [(96, 98, 54, 66), (90, 92, 48, 94), (80, 82, 42, 116)],
        'sheen': (176, 168, 102, 96),
        'foam': [(208, 202, 162, 136), (230, 226, 194, 178)]},
}
# Per level: the field value where the film starts, then where it thickens
# (once for scum1, twice for the others). Lower start is more cover.
CUTS = {1: (0.42, 0.80), 2: (0.05, 0.50, 0.95), 3: (-0.38, 0.12, 0.62)}
SHEEN_CUT = {1: 0.80, 2: 0.66, 3: 0.52}   # second field; only on the film
FLECKS = {1: 3, 2: 5, 3: 8}               # foam flecks, heavier keeps lighter's
BREATHE = 0.45                            # how far the patch outlines move
ORBIT = ((0, 0), (1, 0), (0, 1))          # a fleck's place in each frame


# -------------------------------------------------------------------- field

def waves(rng, shapes):
    return [(kx, ky, rng.uniform(0, math.tau), rng.uniform(0, math.tau), amp) for kx, ky, amp in shapes]


def field(parts, grain, turn):
    """A torus-periodic tone map: whole waves only, so every edge wraps."""
    norm = math.sqrt(sum(amp * amp for *_, amp in parts) / 2)
    return [[sum(amp * math.sin(math.tau * (kx * x + ky * y) / SIZE + ph + BREATHE * math.sin(turn + sway))
                 for kx, ky, ph, sway, amp in parts) / norm + grain[y][x]
             for x in range(SIZE)] for y in range(SIZE)]


def fleck_spots(rng):
    """Foam flecks as (x, y, shape, orbit step); 1-3px each, kept apart."""
    shapes = (((0, 0),), ((0, 0), (1, 0)), ((0, 0), (1, 0), (0, 1)), ((0, 0), (1, 0), (2, 0)), ((0, 0), (0, 1)))
    spots = []
    while len(spots) < max(FLECKS.values()):
        x, y = rng.randrange(SIZE), rng.randrange(SIZE)
        if all(max(min(abs(x - a), SIZE - abs(x - a)), min(abs(y - b), SIZE - abs(y - b))) >= 6
               for a, b, _, _ in spots):
            spots.append((x, y, rng.choice(shapes), rng.randrange(FRAMES)))
    return spots


def build_frames():
    """{level: [FRAMES images]}."""
    rng = random.Random(6607)
    film = waves(rng, ((1, 0, 1.0), (0, 1, 0.9), (1, 1, 0.9), (1, -1, 0.8), (2, 1, 0.7),
                       (1, -2, 0.7), (2, -1, 0.5), (3, 1, 0.4), (2, 3, 0.35), (3, -2, 0.3)))
    oil = waves(rng, ((1, 2, 1.0), (2, -1, 1.0), (3, 1, 0.8), (1, -3, 0.8), (4, 1, 0.5), (2, 3, 0.5)))
    grain = [[rng.uniform(-0.22, 0.22) for _ in range(SIZE)] for _ in range(SIZE)]
    oil_grain = [[rng.uniform(-0.25, 0.25) for _ in range(SIZE)] for _ in range(SIZE)]
    spots = fleck_spots(rng)
    out = {level: [] for level in LEVELS}
    for f in range(FRAMES):
        turn = math.tau * f / FRAMES
        tone, shine = field(film, grain, turn), field(oil, oil_grain, turn)
        for level in LEVELS:
            colours, cuts = PALETTES[level], CUTS[level]
            im = Image.new('RGBA', (SIZE, SIZE))
            px = im.load()
            for y in range(SIZE):
                for x in range(SIZE):
                    depth = sum(tone[y][x] >= cut for cut in cuts)
                    if not depth:
                        continue
                    px[x, y] = colours['sheen'] if shine[y][x] >= SHEEN_CUT[level] else colours['film'][depth - 1]
            for x, y, shape, step in spots[:FLECKS[level]]:
                dx, dy = ORBIT[(f + step) % FRAMES]
                for i, (sx, sy) in enumerate(shape):
                    px[(x + dx + sx) % SIZE, (y + dy + sy) % SIZE] = colours['foam'][0 if i else 1]
            out[level].append(im)
    return out


# -------------------------------------------------------------------- sheet

def build():
    """The whole sheet as [(state, keys, images)]."""
    keys = {'dirs': '1', 'frames': str(FRAMES), 'delay': ','.join([str(DELAY)] * FRAMES)}
    frames = build_frames()
    return [('scum%d' % level, dict(keys), frames[level]) for level in LEVELS]


def pixels(im):
    raw = im.convert('RGBA').tobytes()
    return [tuple(raw[i:i + 4]) for i in range(0, len(raw), 4)]


def seam_ratio(im):
    """Alpha change across the wrap, over the largest change between any two
    neighbouring rows or columns inside the tile. At or below 1 the tile's own
    edge is no more visible than lines already running through it."""
    alpha = [[p[3] for p in pixels(im)[y * SIZE:(y + 1) * SIZE]] for y in range(SIZE)]
    worst = 0.0
    for grid in (alpha, [list(col) for col in zip(*alpha)]):
        steps = [sum(abs(row[i] - row[(i + 1) % SIZE]) for row in grid) for i in range(SIZE)]
        inside = max(steps[:-1])
        worst = max(worst, steps[-1] / inside if inside else 0.0)
    return worst


def check_drawing(states):
    """Rules the drawing itself must keep, whatever the palettes become."""
    problems = []
    cover = {}
    for level, (name, _, images) in zip(LEVELS, states):
        colours = PALETTES[level]
        allowed = set(colours['film']) | set(colours['foam']) | {colours['sheen'], (0, 0, 0, 0)}
        for im in images:
            got = pixels(im)
            if not set(got) <= allowed:
                problems.append('%s uses a colour outside its palette' % name)
                break
            if seam_ratio(im) > 1.2:
                problems.append('%s shows a seam where it wraps (%.2f)' % (name, seam_ratio(im)))
                break
        cover[level] = [set(i for i, p in enumerate(pixels(im)) if p[3]) for im in images]
        mean = sum(p[3] for im in images for p in pixels(im)) / (FRAMES * SIZE * SIZE)
        if mean > 110:
            problems.append('%s hides the water (mean alpha %.0f)' % (name, mean))
    for light, heavy in zip(LEVELS, LEVELS[1:]):
        if any(not a <= b for a, b in zip(cover[light], cover[heavy])):
            problems.append('scum%d does not cover what scum%d covers' % (heavy, light))
        if sum(map(len, cover[light])) >= sum(map(len, cover[heavy])):
            problems.append('scum%d is not heavier than scum%d' % (heavy, light))
    return problems


def check_sheet(path, states):
    """The committed sheet is exactly what build() draws."""
    if not Path(path).exists():
        return ['%s is missing' % path]
    have = read_dmi(path)
    if [name for name, _, _ in have] != [name for name, _, _ in states]:
        return ['state list differs: %s' % ', '.join(name for name, _, _ in have)]
    problems = []
    for (name, keys, images), (_, want_keys, want_images) in zip(have, states):
        if keys != want_keys:
            problems.append('%s has dirs/frames/delay %r, expected %r' % (name, keys, want_keys))
        elif any(pixels(a) != pixels(b) for a, b in zip(images, want_images)):
            problems.append('%s is not what this script draws' % name)
    return problems


# ------------------------------------------------------------------- review

def write_preview(path, states, scale=4, tiles=3):
    """Each state tiled 3x3 over river water; first column is clean water."""
    river = {name: images for name, _, images in read_dmi(RIVER)}
    waters = ('seashallow', 'seashallow_jungle1')
    columns = [('clean', None)] + [(name, images[0]) for name, _, images in states]
    block, gap, top, left = tiles * SIZE * scale, 12, 18, 12
    sheet = Image.new('RGB', (left + len(columns) * (block + gap), len(waters) * (block + top + gap) + gap),
                      (32, 32, 36))
    draw = ImageDraw.Draw(sheet)
    for row, water in enumerate(waters):
        for col, (label, scum) in enumerate(columns):
            im = Image.new('RGBA', (tiles * SIZE, tiles * SIZE))
            for ty in range(tiles):
                for tx in range(tiles):
                    im.paste(river[water][0], (tx * SIZE, ty * SIZE))
                    if scum:
                        im.alpha_composite(scum, (tx * SIZE, ty * SIZE))
            at = (left + col * (block + gap), gap + row * (block + top + gap))
            draw.text(at, '%s on %s' % (label, water) if scum else '%s %s' % (label, water), fill=(230, 230, 230))
            sheet.paste(im.convert('RGB').resize((block, block), Image.NEAREST), (at[0], at[1] + top))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


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
        print('water scum: %s' % ('FAILED' if problems else 'ok'))
        return 1 if problems else 0
    if problems:
        print('\n'.join(problems))
        return 1
    write_dmi(option('--out') or SHEET, states)
    if option('--preview'):
        write_preview(option('--preview'), states)
    return 0


if __name__ == '__main__':
    sys.exit(main())
