#!/usr/bin/env python3
"""Draw the roof-collapse dust cloud in icons/effects/collapse_dust.dmi.

One single-direction 32x32 state:

  dust  a grey-brown cloud that bursts from the middle of the tile, billows
        outward and thins away over 8 frames of 1 decisecond each. It plays
        once (loop = 1) over a tile where a roof has just fallen.

The cloud is a handful of round puffs that drift apart and swell. Each puff is
lit from the top left. The cloud is half transparent from the start; later
frames grow paler and break up into loose specks until almost nothing is left.
The drawing is plain pixel work with Pillow; nothing is random, so a rerun
writes the same bytes.

  python3 tests/sprites/create_collapse_dust.py                  write the sheet
  python3 tests/sprites/create_collapse_dust.py --check          verify the committed sheet
  python3 tests/sprites/create_collapse_dust.py --preview <png>  also write a 4x review sheet
"""
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_water_animation import SIZE, write_dmi  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/effects/collapse_dust.dmi'
STATE = 'dust'
FRAMES = 8
DELAY = 1  # deciseconds per frame: 0.8 seconds in all
FLOORS = ((121, 88, 58), (126, 126, 122), (138, 104, 68))  # dirt, stone, planks

# shade, body, light, highlight
DUST = [(112, 99, 86), (146, 133, 117), (176, 165, 149), (202, 194, 180)]
# how solid the cloud is in each frame, and how much of it has broken up
ALPHA = (225, 215, 200, 178, 150, 116, 78, 40)
HOLES = (0.0, 0.0, 0.04, 0.10, 0.20, 0.34, 0.50, 0.68)
# puffs: direction it drifts (dx, dy per unit), reach, start radius, growth
PUFFS = (
    (0.0, 0.0, 0.0, 4.5, 4.5),
    (-1.0, -0.35, 8.0, 3.0, 3.5),
    (1.0, -0.2, 8.5, 3.0, 3.5),
    (-0.7, 0.55, 7.5, 2.5, 3.5),
    (0.75, 0.6, 7.5, 2.5, 3.0),
    (-0.3, -1.0, 7.5, 2.5, 3.5),
    (0.4, -0.9, 6.5, 2.0, 3.0),
    (0.05, 0.9, 5.5, 2.5, 2.5),
)
CENTRE = (15.5, 17.0)


def noise(x, y, seed):
    n = (x * 73856093) ^ (y * 19349663) ^ (seed * 83492791)
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def frame(f):
    t = f / float(FRAMES - 1)
    spread = 1.0 - (1.0 - t) ** 2  # fast at first, then slowing
    puffs = [(CENTRE[0] + dx * reach * 1.3 * spread, CENTRE[1] + dy * reach * 1.25 * spread - 1.5 * t,
              r0 * 1.5 + grow * 1.5 * spread)
             for dx, dy, reach, r0, grow in PUFFS]
    im = Image.new('RGBA', (SIZE, SIZE))
    px = im.load()
    for y in range(SIZE):
        for x in range(SIZE):
            best, lit = 0.0, 0.0
            for cx, cy, r in puffs:
                d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
                depth = 1.0 - d / r
                if depth > best:
                    best, lit = depth, -((x - cx) + (y - cy)) / (r * 1.4142)
            if best <= 0.0:
                continue
            # the thin skirt of the cloud breaks up first
            if noise(x, y, 7) < HOLES[f] * (1.6 - best):
                continue
            tone = 3 if lit > 0.45 else 2 if lit > 0.05 else 1 if lit > -0.5 else 0
            grain = noise(x // 2, y // 2, 11 + f // 2)
            if grain < 0.18 and tone > 0:
                tone -= 1
            elif grain > 0.88 and tone < 3:
                tone += 1
            alpha = ALPHA[f]
            if best < 0.22:
                alpha = alpha * 11 // 20  # soft edge
            elif best < 0.4:
                alpha = alpha * 4 // 5
            px[x, y] = DUST[tone] + (alpha,)
    return im


def build():
    keys = {'dirs': '1', 'frames': str(FRAMES), 'delay': ','.join([str(DELAY)] * FRAMES), 'loop': '1'}
    return [(STATE, keys, [frame(f) for f in range(FRAMES)])]


def check_drawing(states):
    problems = []
    (_, keys, images), = states
    if keys.get('loop') != '1' or keys.get('frames') != str(FRAMES):
        problems.append('dust is not an %d-frame one-shot' % FRAMES)
    if sum(int(d) for d in keys['delay'].split(',')) >= 10:
        problems.append('dust lasts a second or more')
    cover, weight = [], []
    for im in images:
        alpha = im.getchannel('A').tobytes()
        cover.append(sum(1 for a in alpha if a))
        weight.append(max(alpha))
    if not cover[0] < cover[2] < cover[4]:
        problems.append('dust does not billow outward: %s' % cover)
    if any(a <= b for a, b in zip(weight, weight[1:])):
        problems.append('dust does not fade steadily: %s' % weight)
    if weight[-1] > 48:
        problems.append('last frame is still alpha %d' % weight[-1])
    return problems


def check_sheet(path, states):
    path = Path(path)
    if not path.exists():
        return ['%s is missing' % path]
    sheet = Image.open(path)
    text = sheet.info.get('Description', '')
    (name, keys, images), = states
    want = 'state = "%s"\n' % name + ''.join('\t%s = %s\n' % item for item in keys.items())
    problems = []
    if want not in text or text.count('state = ') != 1:
        problems.append('%s metadata is not the one-shot dust state' % path.name)
    sheet = sheet.convert('RGBA')
    for n, im in enumerate(images):
        if sheet.crop((n * SIZE, 0, (n + 1) * SIZE, SIZE)).tobytes() != im.tobytes():
            problems.append('frame %d: committed pixels differ from the drawing' % (n + 1))
    return problems


def write_preview(path, states, scale=4):
    """The 8 frames side by side at 4x over three floor tones, with a 1x copy underneath."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    (_, _, images), = states
    block = Image.new('RGBA', (SIZE * len(images), SIZE * len(FLOORS)))
    px = block.load()
    for row, floor in enumerate(FLOORS):
        for y in range(row * SIZE, (row + 1) * SIZE):
            for x in range(block.width):
                v = noise(x, y, 40 + row)
                shift = -9 if v < 0.14 else 7 if v > 0.9 else 0
                px[x, y] = tuple(c + shift for c in floor) + (255,)
        for n, im in enumerate(images):
            block.alpha_composite(im, (n * SIZE, row * SIZE))
    block = block.convert('RGB')
    sheet = Image.new('RGB', (block.width * scale, block.height * scale + block.height), (32, 32, 32))
    sheet.paste(block.resize((block.width * scale, block.height * scale), Image.NEAREST), (0, 0))
    sheet.paste(block, (0, block.height * scale))
    sheet.save(path)


def option(name):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else None


def main():
    states = build()
    problems = check_drawing(states)
    if '--check' in sys.argv:
        problems += check_sheet(option('--sheet') or SHEET, states)
        for line in problems:
            print(line)
        print('collapse dust: %s' % ('FAILED' if problems else 'ok'))
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
