"""Script-drawn signs of fish for icons/effects/fish_signs.dmi.

Every pixel is placed by this script from the fixed colours below (Pillow
only); no external or generated artwork. The signs are see-through images laid
on water tiles for the players who can see them (code/modules/1713/
fish_signs.dm): well-stocked water shows them often, thin water rarely and
fished-out water never, so a fisher can read a stretch from the bank.

States, all 32x32, 1 dir:

  rise_a, rise_b, rise_c   A fish rising: a ring that opens on the surface and
                           fades. One ring every 4 seconds; the three states
                           are the same ring at different moments of the loop,
                           so neighbouring tiles do not pulse together.
  jump_a, jump_b           A fish leaping clear in a low arc and falling back
                           with a splash, once every 8 seconds. jump_b is the
                           mirror image, half a loop later.
  gulls                    Two gulls wheeling over a shoal on the coast, a
                           continuous 8-frame circle.

Run with Pillow to rewrite the sheet (safe to rerun). `--out <dmi>` writes it
somewhere else, `--gif <gif>` writes a review animation over river water,
`--check` only verifies that the committed sheet is what this script draws.
Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_water_animation import SIZE, read_dmi, write_dmi  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/effects/fish_signs.dmi'
RIVER = ROOT / 'icons/turf/beach.dmi'

FOAM = (226, 242, 248)
SHADE = (34, 70, 98)
BACK = (70, 88, 102, 255)
SIDE = (150, 172, 184, 255)
BELLY = (212, 222, 226, 255)
TAIL = (88, 106, 120, 255)
EYE = (24, 30, 36, 255)
WING = (242, 242, 238, 255)
WINGTIP = (146, 152, 158, 255)
GULL_SHADOW = (20, 40, 60, 90)

# Ring radii (x) and opacity for the five frames of a rise.
RINGS = ((2, 255), (4, 240), (6, 210), (8, 160), (10, 100))
RISE_LOOP = 40   # ticks
JUMP_LOOP = 80

LEVEL = ('t...BBBB..',
         'tt.BSSSSB.',
         '.ttSSSSSSe',
         'tt.ssssss.',
         't...sss...')
RISING = ('.......Be',
          '.....BBSS',
          '....BSSSs',
          '...BSSSs.',
          '..BSSSs..',
          't.BSSs...',
          'tttSs....',
          '.tt......',
          '.ttt.....')
# The same fish coming down: upside down, with the dark back kept uppermost.
FALLING = tuple(row.translate(str.maketrans('Bs', 'sB')) for row in reversed(RISING))
INK = {'B': BACK, 'S': SIDE, 's': BELLY, 't': TAIL, 'e': EYE}


def blank():
    return Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))


def ring(im, cx, cy, rx, alpha):
    """An ellipse outline half as tall as it is wide, with a darker lower lip."""
    ry = max(1, rx // 2)
    seen = set()
    for step in range(0, 360, 3):
        a = math.radians(step)
        x = int(round(cx + rx * math.cos(a)))
        y = int(round(cy + ry * math.sin(a)))
        if (x, y) in seen or not (0 <= x < SIZE and 0 <= y < SIZE):
            continue
        seen.add((x, y))
        # Broken line: skip one pixel in five so it reads as water, not a hoop.
        if (x * 7 + y * 3 + rx) % 5 == 0:
            continue
        im.putpixel((x, y), FOAM + (alpha,))
        if math.sin(a) > 0.3 and y + 1 < SIZE and (x, y + 1) not in seen:
            im.putpixel((x, y + 1), SHADE + (alpha // 2,))
    return im


def rise_frames():
    return [ring(blank(), 16, 17, rx, alpha) for rx, alpha in RINGS]


def stamp(im, rows, x, y, mirror=False):
    for dy, row in enumerate(rows):
        cells = row[::-1] if mirror else row
        for dx, c in enumerate(cells):
            if c != '.' and 0 <= x + dx < SIZE and 0 <= y + dy < SIZE:
                im.putpixel((x + dx, y + dy), INK[c])


def splash(im, cx, cy, big):
    drops = ((-2, -2), (0, -3), (2, -2)) if big else ((-1, -1), (1, -1))
    for dx, dy in drops:
        im.putpixel((cx + dx, cy + dy), FOAM + (230,))
    ring(im, cx, cy, 3 if big else 2, 200)


def jump_frames(mirror=False):
    def at(x):
        return SIZE - 1 - x if mirror else x

    frames = []
    f = blank()
    splash(f, at(8), 20, False)
    frames.append(f)
    for rows, x, y in ((RISING, 6, 11), (RISING, 9, 5), (LEVEL, 12, 4), (FALLING, 17, 7)):
        f = blank()
        left = SIZE - x - len(rows[0]) if mirror else x
        stamp(f, rows, left, y, mirror)
        if rows is RISING and y == 11:
            ring(f, at(8), 20, 4, 150)
        frames.append(f)
    f = blank()
    splash(f, at(24), 19, True)
    frames.append(f)
    frames.append(ring(blank(), at(24), 19, 6, 130))
    frames.append(ring(blank(), at(24), 19, 9, 60))
    return frames


GLIDE = ('tWW...WWt',
         '...WbW...',
         '....g....')
BEAT = ('...WbW...',
        'tWW.g.WWt')
GULL_INK = {'W': WING, 't': WINGTIP, 'b': (255, 255, 255, 255), 'g': WINGTIP}


def gull(im, x, y, up):
    """A gull seen from above, wings spread or on the down beat, with its shadow on the water."""
    rows = GLIDE if up else BEAT
    for dy, row in enumerate(rows):
        for dx, c in enumerate(row):
            if c == '.':
                continue
            px, py = x + dx - 4, y + dy - 1
            if 0 <= px < SIZE and 0 <= py < SIZE:
                im.putpixel((px, py), GULL_INK[c])
    for dy, row in enumerate(rows):
        for dx, c in enumerate(row):
            sx, sy = x + dx - 2, y + dy + 8
            if c != '.' and 0 <= sx < SIZE and 0 <= sy < SIZE and im.getpixel((sx, sy))[3] == 0:
                im.putpixel((sx, sy), GULL_SHADOW)


def gull_frames():
    frames = []
    for i in range(8):
        f = blank()
        a = 2 * math.pi * i / 8
        gull(f, int(round(15 + 9 * math.cos(a))), int(round(9 + 5 * math.sin(a))), i % 2 == 0)
        gull(f, int(round(17 - 9 * math.cos(a + 0.6))), int(round(12 - 5 * math.sin(a + 0.6))), i % 2 == 1)
        frames.append(f)
    return frames


def phased(frames, tick, loop, lead):
    """The frames with a blank before (lead ticks) and after, as (images, delays)."""
    images, delays = [], []
    if lead:
        images.append(blank())
        delays.append(lead)
    images += frames
    delays += [tick] * len(frames)
    rest = loop - lead - tick * len(frames)
    if rest > 0:
        images.append(blank())
        delays.append(rest)
    return images, delays


def keys(images, delays):
    return {'dirs': 1, 'frames': len(images), 'delay': ','.join(str(d) for d in delays)}


def build():
    states = []
    for name, lead in (('rise_a', 0), ('rise_b', 13), ('rise_c', 27)):
        images, delays = phased(rise_frames(), 2, RISE_LOOP, lead)
        states.append((name, keys(images, delays), images))
    for name, lead, mirror in (('jump_a', 0, False), ('jump_b', 40, True)):
        images, delays = phased(jump_frames(mirror), 2, JUMP_LOOP, lead)
        states.append((name, keys(images, delays), images))
    images = gull_frames()
    states.append(('gulls', keys(images, [3] * len(images)), images))
    return states


def check_sheet(path, states):
    problems = []
    try:
        committed = read_dmi(path)
    except Exception as error:  # noqa: BLE001
        return ['cannot read %s: %s' % (path, error)]
    drawn = {name: (meta, ims) for name, meta, ims in states}
    have = {name: (meta, ims) for name, meta, ims in committed}
    if list(drawn) != list(have):
        problems.append('states differ: sheet has %s' % list(have))
        return problems
    for name, (meta, ims) in drawn.items():
        other_meta, other = have[name]
        if str(other_meta.get('delay')) != str(meta['delay']) or len(other) != len(ims):
            problems.append('%s: frames or delays differ' % name)
            continue
        for i, (a, b) in enumerate(zip(ims, other)):
            if a.tobytes() != b.convert('RGBA').tobytes():
                problems.append('%s frame %d differs from the script' % (name, i))
                break
    return problems


def timeline(images, delays):
    out = []
    for im, d in zip(images, delays):
        out += [im] * int(d)
    return out


def write_gif(path, states, scale=4):
    from create_water_animation import read_dmi as read
    water = None
    for name, _, ims in read(RIVER):
        if name == 'seashallow':
            water = ims[0].convert('RGBA')
            break
    if water is None:
        water = Image.new('RGBA', (SIZE, SIZE), (52, 110, 150, 255))
    lines = {name: timeline(ims, [int(x) for x in str(meta['delay']).split(',')]) for name, meta, ims in states}
    frames = []
    for t in range(0, JUMP_LOOP, 2):
        canvas = Image.new('RGBA', (SIZE * len(lines), SIZE))
        for i, (name, line) in enumerate(lines.items()):
            canvas.paste(water, (i * SIZE, 0))
            canvas.alpha_composite(line[t % len(line)], (i * SIZE, 0))
        frames.append(canvas.resize((canvas.width * scale, canvas.height * scale), Image.NEAREST).convert('P', palette=Image.ADAPTIVE))
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=200, loop=0)


def option(name):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else None


def main():
    states = build()
    if '--check' in sys.argv:
        problems = check_sheet(option('--sheet') or SHEET, states)
        for problem in problems:
            print('FAIL: ' + problem)
        print('fish_signs.dmi: %s' % ('%d problem(s)' % len(problems) if problems else 'matches the script'))
        return 1 if problems else 0
    out = option('--out') or SHEET
    write_dmi(out, states)
    print('wrote %s: %d states' % (out, len(states)))
    if option('--gif'):
        write_gif(option('--gif'), states)
    return 0


if __name__ == '__main__':
    sys.exit(main())
