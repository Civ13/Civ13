"""Script-drawn fishing gear for icons/obj/fishing_gear.dmi.

Every pixel is placed by this script from the fixed colours below (Pillow
only); no external or generated artwork.

States, all 32x32, 1 dir, 1 frame:

  ice_hole   A hole cut through river or sea ice for a line
             (code/modules/1713/ice_fishing.dm): dark water in an oval about
             18 by 12, the cut wall of the ice showing along its far side, a
             rim of chipped ice and a few loose shards and cracks around it.
             It sits on the "seashallow_frozen" tile of icons/turf/beach.dmi.

Run with Pillow to rewrite the sheet (safe to rerun). `--out <dmi>` writes it
somewhere else, `--png <png>` writes an enlarged review picture over ice,
`--check` only verifies that the committed sheet is what this script draws.
Released under Civ13 AGPL-3.0.
"""
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_water_animation import SIZE, read_dmi, write_dmi  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/fishing_gear.dmi'
TURFS = ROOT / 'icons/turf/beach.dmi'

WATER_DEEP = (22, 44, 64, 255)
WATER = (32, 62, 88, 255)
WATER_LIGHT = (58, 96, 124, 255)
GLINT = (128, 170, 194, 255)
WALL_DARK = (104, 146, 170, 255)     # the cut face of the ice, in shadow
WALL = (142, 182, 202, 255)
RIM = (240, 247, 249, 255)           # chipped ice piled round the hole
RIM_SHADE = (168, 192, 204, 255)
CRACK = (158, 184, 196, 255)

CX, CY, RX, RY = 16, 17, 9, 6


def inside(x, y, grow=0.0):
    dx = (x - CX) / (RX + grow)
    dy = (y - CY) / (RY + grow)
    return dx * dx + dy * dy <= 1.0


def ice_hole():
    im = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    put = im.putpixel
    # Cracks first, so the rim and the hole cover their inner ends.
    for points in (((6, 11), (5, 10), (4, 10), (3, 9), (2, 9)),
                   ((26, 11), (27, 10), (28, 10), (29, 9)),
                   ((23, 24), (24, 25), (25, 25), (26, 26), (26, 27)),
                   ((8, 24), (7, 25), (7, 26), (6, 27))):
        for x, y in points:
            put((x, y), CRACK)
    for y in range(SIZE):
        for x in range(SIZE):
            if inside(x, y):
                continue
            if inside(x, y, 1.6):
                # A broken ring of chips: gaps by a fixed pattern, shaded below.
                if (x * 5 + y * 11) % 7 == 0:
                    continue
                put((x, y), RIM_SHADE if y > CY + 2 and (x + y) % 3 else RIM)
    for y in range(SIZE):
        for x in range(SIZE):
            if not inside(x, y):
                continue
            # The far (upper) wall of the cut shows two pixels of ice thickness.
            if not inside(x, y - 1):
                put((x, y), WALL)
            elif not inside(x, y - 2):
                put((x, y), WALL_DARK)
            elif not inside(x, y + 1) or not inside(x - 1, y) or not inside(x + 1, y):
                put((x, y), WATER_DEEP)
            else:
                put((x, y), WATER)
    for x, y in ((11, 18), (12, 18), (13, 19), (18, 17), (19, 17), (20, 18), (14, 21), (15, 21), (16, 21), (21, 20), (22, 20)):
        put((x, y), WATER_LIGHT)
    for x, y in ((12, 17), (19, 16), (15, 20)):
        put((x, y), GLINT)
    # Loose shards thrown out by the cutting.
    for x, y, c in ((3, 18, RIM), (4, 18, RIM_SHADE), (28, 20, RIM), (28, 21, RIM_SHADE), (11, 7, RIM), (12, 7, RIM),
                    (12, 8, RIM_SHADE), (23, 8, RIM), (19, 27, RIM), (20, 27, RIM_SHADE), (5, 22, RIM)):
        put((x, y), c)
    return im


def build():
    return [('ice_hole', {'dirs': 1, 'frames': 1}, [ice_hole()])]


def check_sheet(path, states):
    try:
        committed = read_dmi(path)
    except Exception as error:  # noqa: BLE001
        return ['cannot read %s: %s' % (path, error)]
    if [name for name, _, _ in committed] != [name for name, _, _ in states]:
        return ['states differ: sheet has %s' % [name for name, _, _ in committed]]
    problems = []
    for (name, _, ims), (_, _, other) in zip(states, committed):
        if len(ims) != len(other) or any(a.tobytes() != b.convert('RGBA').tobytes() for a, b in zip(ims, other)):
            problems.append('%s differs from the script' % name)
    return problems


def write_png(path, states, scale=6):
    ground = {name: ims[0].convert('RGBA') for name, _, ims in read_dmi(TURFS)}.get('seashallow_frozen')
    if ground is None:
        ground = Image.new('RGBA', (SIZE, SIZE), (192, 209, 216, 255))
    canvas = Image.new('RGBA', (SIZE * 3 * len(states), SIZE * 3))
    for i, (_, _, ims) in enumerate(states):
        for ty in range(3):
            for tx in range(3):
                canvas.paste(ground, ((i * 3 + tx) * SIZE, ty * SIZE))
        canvas.alpha_composite(ims[0], ((i * 3 + 1) * SIZE, SIZE))
    canvas.resize((canvas.width * scale, canvas.height * scale), Image.NEAREST).save(path)


def option(name):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else None


def main():
    states = build()
    if '--check' in sys.argv:
        problems = check_sheet(option('--sheet') or SHEET, states)
        for problem in problems:
            print('FAIL: ' + problem)
        print('fishing_gear.dmi: %s' % ('%d problem(s)' % len(problems) if problems else 'matches the script'))
        return 1 if problems else 0
    out = option('--out') or SHEET
    write_dmi(out, states)
    print('wrote %s: %d states' % (out, len(states)))
    if option('--png'):
        write_png(option('--png'), states)
    return 0


if __name__ == '__main__':
    sys.exit(main())
