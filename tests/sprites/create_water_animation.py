"""Script-drawn water animation for every water tile in icons/turf/beach.dmi.

Every pixel is placed by this script from the fixed palettes below (Pillow
only); no external or generated artwork. The palettes are the colours the
hand-made water tiles already used, so each water type keeps its look.

The ripple is a net of bright lines between drifting cells. The cell centres
circle slowly on a 32px torus, so each frame tiles with itself in every
direction and the last frame leads back into the first. All water types share
one set of frames and one timing, so neighbouring water of different kinds,
the shoreline edges and the flood overlays stay in step.

Shoreline edges keep their existing outline: the script reads the alpha of
each edge direction from the sheet and cuts the new frames with it. The dock
line keeps its planks. Ice, coast surf, the sea layer and the wading masks are
left alone.

Run with Pillow to rewrite icons/turf/beach.dmi in place (safe to rerun).
`--out <dmi>` writes the sheet somewhere else, `--gif <gif>` writes a tiled
review animation, `--check` only verifies the sheet. Released under Civ13
AGPL-3.0.
"""
import math
import random
import struct
import sys
import zlib
from pathlib import Path
from PIL import Image, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/turf/beach.dmi'

SIZE = 32
FRAMES = 12
DELAY = 2          # ticks per frame: a 2.4 second loop
CELLS = 11
ROUND = 1.1      # higher is sharper cell corners

# Per water type: base shades from dark to light, then the ripple line from
# its soft outer halo to its brightest core.
PALETTES = {
    'seashallow': {
        'base': [(123, 148, 148), (132, 156, 148), (132, 156, 156), (140, 165, 165)],
        'line': [(148, 165, 165), (173, 181, 173), (181, 189, 173), (189, 197, 181)],
    },
    'seadeep': {
        'base': [(66, 132, 181), (66, 132, 181), (66, 132, 181), (74, 140, 189)],
        'line': [(99, 156, 197), (140, 181, 214), (165, 197, 222), (173, 197, 222)],
    },
    'seashallow_jungle1': {
        'base': [(103, 98, 69), (109, 102, 68), (109, 102, 73), (116, 111, 78)],
        'line': [(122, 114, 82), (134, 111, 81), (139, 115, 80), (146, 120, 84)],
    },
    'seashallow_jungle2': {
        'base': [(88, 98, 81), (94, 104, 81), (95, 104, 86), (101, 110, 91)],
        'line': [(107, 116, 96), (123, 121, 96), (128, 127, 95), (134, 132, 100)],
    },
    'seashallow_jungle3': {
        'base': [(100, 92, 56), (107, 95, 55), (106, 94, 60), (114, 104, 64)],
        'line': [(119, 107, 68), (130, 103, 66), (136, 106, 65), (143, 111, 68)],
    },
    'seashallow_swamp': {
        'base': [(77, 93, 62), (83, 98, 66), (84, 100, 69), (87, 105, 70)],
        'line': [(92, 105, 70), (106, 120, 69), (110, 125, 72), (114, 126, 77)],
    },
}

# state -> (palette, alpha) for the see-through copies laid over other tiles
OVERLAYS = {
    'seashallow_swamp_overlay': ('seashallow_swamp', 153),
    'flood_overlay1': ('seadeep', 102),
    'flood_overlay2': ('seadeep', 163),
    'flood_overlay3': ('seadeep', 190),
}

# edge state -> (palette, state whose alpha gives the outline)
EDGES = {
    'seashallow_edges': ('seashallow', 'seashallow_edges'),
    'seadeep_edges': ('seadeep', 'seadeep_edges'),
    'seashallow_jungle1_edges': ('seashallow_jungle1', 'seashallow_jungle1_edges'),
    'seashallow_jungle2_edges': ('seashallow_jungle2', 'seashallow_jungle2_edges'),
    'seashallow_jungle3_edges': ('seashallow_jungle3', 'seashallow_jungle1_edges'),
    'seashallow_swamp_edges': ('seashallow_swamp', 'seashallow_swamp_edges'),
}
NEW_STATES_AFTER = {'seashallow_jungle3_edges': 'seashallow_jungle2_edges'}

DOCK = 'ship_line'   # deep water with a strip of planks, four directions

ANIMATED = set(PALETTES) | set(OVERLAYS) | set(EDGES) | {DOCK}


# ------------------------------------------------------------------ pattern

def torus(d):
    d = abs(d) % SIZE
    return min(d, SIZE - d)


def cell_centres(rng):
    """Evenly scattered points on the torus (best of several candidates)."""
    pts = [(rng.uniform(0, SIZE), rng.uniform(0, SIZE))]
    while len(pts) < CELLS:
        best, best_d = None, -1.0
        for _ in range(40):
            c = (rng.uniform(0, SIZE), rng.uniform(0, SIZE))
            d = min(math.hypot(torus(c[0] - p[0]), torus(c[1] - p[1])) for p in pts)
            if d > best_d:
                best, best_d = c, d
        pts.append(best)
    return pts


def pattern():
    """FRAMES index maps: 0-3 are base shades, 4-7 the ripple line."""
    rng = random.Random(1713)
    centres = cell_centres(rng)
    orbits = [(rng.uniform(1.6, 2.8), rng.uniform(1.6, 2.8), rng.uniform(0, math.tau), rng.choice((-1, 1)))
              for _ in centres]
    weights = [rng.uniform(-0.9, 0.9) for _ in centres]
    waves = [(rng.choice((1, 2, 3)), rng.choice((-2, -1, 1, 2)), rng.uniform(0, math.tau), rng.choice((-1, 1)))
             for _ in range(4)]
    grain = [[rng.uniform(-0.28, 0.28) for _ in range(SIZE)] for _ in range(SIZE)]
    frames = []
    for f in range(FRAMES):
        turn = math.tau * f / FRAMES
        pts = [(cx + rx * math.cos(turn * way + ph), cy + ry * math.sin(turn * way + ph))
               for (cx, cy), (rx, ry, ph, way) in zip(centres, orbits)]
        rows = []
        for y in range(SIZE):
            row = []
            for x in range(SIZE):
                # a gentle sideways sway keeps the cell walls from looking ruled
                sx = x + 1.1 * math.sin(math.tau * (y / SIZE) * 3 + turn)
                sy = y + 1.1 * math.sin(math.tau * (x / SIZE) * 3 - turn + 1.7)
                near = sorted((math.hypot(torus(sx - px), torus(sy - py)) + w * 0.6)
                              for (px, py), w in zip(pts, weights))
                # soft minimum of the gaps to the next cells: rounds the cell
                # corners, so the cells read as blobs and the joints thicken
                gap = -math.log(sum(math.exp(-ROUND * (d - near[0])) for d in near[1:4])) / ROUND
                if gap < 1.25:
                    level = 7 if gap < -0.5 else 6 if gap < 0.25 else 5 if gap < 0.8 else 4
                else:
                    tone = sum(math.sin(math.tau * (kx * x + ky * y) / SIZE + ph + turn * way)
                               for kx, ky, ph, way in waves) / len(waves)
                    tone += grain[(y + x) % SIZE][(x * 7 + y * 3) % SIZE]
                    level = 0 if tone < -0.42 else 1 if tone < -0.05 else 2 if tone < 0.4 else 3
                row.append(level)
            rows.append(row)
        frames.append(rows)
    return frames


def paint(index, palette, alpha=255):
    colours = [c + (alpha,) for c in PALETTES[palette]['base'] + PALETTES[palette]['line']]
    im = Image.new('RGBA', (SIZE, SIZE))
    im.putdata([colours[v] for row in index for v in row])
    return im


# -------------------------------------------------------------------- sheet

def read_dmi(path):
    """[(name, {key: text}, [image, ...] in sheet order)] for a 32px sheet."""
    text = None
    with open(path, 'rb') as fh:
        fh.read(8)
        while True:
            head = fh.read(8)
            if len(head) < 8:
                break
            length, kind = struct.unpack('>I4s', head)
            data = fh.read(length)
            fh.read(4)
            if kind == b'zTXt' and data.startswith(b'Description\0'):
                text = zlib.decompress(data[data.index(0) + 2:]).decode()
    sheet = Image.open(path).convert('RGBA')
    cols = sheet.width // SIZE
    states, at = [], 0
    for line in text.splitlines():
        line = line.strip()
        if line.startswith('state'):
            states.append((line.split('=', 1)[1].strip().strip('"'), {}, []))
        elif states and '=' in line:
            key, value = (part.strip() for part in line.split('=', 1))
            states[-1][1][key] = value
    for _, keys, images in states:
        for _ in range(int(keys['dirs']) * int(keys['frames'])):
            x, y = (at % cols) * SIZE, (at // cols) * SIZE
            images.append(sheet.crop((x, y, x + SIZE, y + SIZE)))
            at += 1
    return states


def write_dmi(path, states):
    images = [im for _, _, ims in states for im in ims]
    cols = 16
    sheet = Image.new('RGBA', (cols * SIZE, ((len(images) + cols - 1) // cols) * SIZE))
    for i, im in enumerate(images):
        sheet.paste(im, ((i % cols) * SIZE, (i // cols) * SIZE))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = %d\n\theight = %d\n' % (SIZE, SIZE)
    for name, keys, _ in states:
        text += 'state = "%s"\n' % name
        for key, value in keys.items():
            text += '\t%s = %s\n' % (key, value)
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta, optimize=True)


def loop_keys(dirs):
    return {'dirs': str(dirs), 'frames': str(FRAMES), 'delay': ','.join([str(DELAY)] * FRAMES)}


def cut(body, outline):
    out = Image.new('RGBA', (SIZE, SIZE))
    out.paste(body, (0, 0), outline.getchannel('A').point(lambda a: 255 if a else 0))
    return out


def pixels(im):
    raw = im.tobytes()
    return [tuple(raw[i:i + 4]) for i in range(0, len(raw), 4)]


def is_water(pixel):
    return pixel[3] and pixel[2] - pixel[0] >= 40


def rebuild(states):
    index = pattern()
    old = {name: (keys, images) for name, keys, images in states}
    bodies = {name: [paint(i, name) for i in index] for name in PALETTES}
    made = {}
    for name in PALETTES:
        made[name] = (loop_keys(1), bodies[name])
    for name, (palette, alpha) in OVERLAYS.items():
        made[name] = (loop_keys(1), [paint(i, palette, alpha) for i in index])
    for name, (palette, source) in EDGES.items():
        dirs = int(old[source][0]['dirs'])
        outlines = old[source][1][:dirs]
        made[name] = (loop_keys(dirs), [cut(body, o) for body in bodies[palette] for o in outlines])
    dirs = int(old[DOCK][0]['dirs'])
    dock = []
    for body in bodies['seadeep']:
        for first in old[DOCK][1][:dirs]:
            im = first.copy()
            px, src = im.load(), body.load()
            for y in range(SIZE):
                for x in range(SIZE):
                    if is_water(px[x, y]):
                        px[x, y] = src[x, y]
            dock.append(im)
    made[DOCK] = (loop_keys(dirs), dock)

    out = []
    for name, keys, images in states:
        if name in made:
            out.append((name,) + made[name])
        else:
            out.append((name, keys, images))
        for extra, after in NEW_STATES_AFTER.items():
            if after == name and extra not in old:
                out.append((extra,) + made[extra])
    return out


def check(states):
    """Every animated water state shares one timing, and edges match bodies."""
    by = {name: (keys, images) for name, keys, images in states}
    problems = []
    want = ','.join([str(DELAY)] * FRAMES)
    for name in sorted(ANIMATED):
        if name not in by:
            problems.append('%s is missing' % name)
            continue
        keys = by[name][0]
        if keys.get('frames') != str(FRAMES) or keys.get('delay') != want or 'rewind' in keys:
            problems.append('%s does not use the shared %d-frame loop' % (name, FRAMES))
    for name, (palette, _) in EDGES.items():
        if name not in by or palette not in by:
            continue
        dirs = int(by[name][0]['dirs'])
        for i, im in enumerate(by[name][1]):
            body = by[palette][1][i // dirs]
            if any(e[3] and e != b for e, b in zip(pixels(im), pixels(body))):
                problems.append('%s frame %d differs from its water' % (name, i // dirs))
                break
            if im.getchannel('A').tobytes() != by[name][1][i % dirs].getchannel('A').tobytes():
                problems.append('%s outline changes between frames' % name)
                break
    for name in PALETTES:
        if name not in by:
            continue
        allowed = set(c + (255,) for c in PALETTES[name]['base'] + PALETTES[name]['line'])
        for im in by[name][1]:
            if not set(pixels(im)) <= allowed:
                problems.append('%s uses a colour outside its palette' % name)
                break
    return problems


def write_gif(path, states, scale=3, tiles=3):
    """Each water type tiled tiles x tiles, side by side, to show the seams."""
    by = {name: images for name, _, images in states}
    names = list(PALETTES)
    block = SIZE * tiles
    out = []
    for f in range(FRAMES):
        im = Image.new('RGB', (block * len(names), block))
        for n, name in enumerate(names):
            for ty in range(tiles):
                for tx in range(tiles):
                    im.paste(by[name][f], (n * block + tx * SIZE, ty * SIZE))
        out.append(im.resize((im.width * scale, im.height * scale), Image.NEAREST))
    out[0].save(path, save_all=True, append_images=out[1:], duration=DELAY * 100, loop=0)


def option(name):
    args = sys.argv[1:]
    return args[args.index(name) + 1] if name in args[:-1] else None


def main():
    if '--check' in sys.argv:
        problems = check(read_dmi(option('--sheet') or SHEET))
        for line in problems:
            print(line)
        print('water animation: %s' % ('FAILED' if problems else 'ok'))
        return 1 if problems else 0
    states = rebuild(read_dmi(SHEET))
    problems = check(states)
    if problems:
        print('\n'.join(problems))
        return 1
    write_dmi(option('--out') or SHEET, states)
    if option('--gif'):
        write_gif(option('--gif'), states)
    return 0


if __name__ == '__main__':
    sys.exit(main())
