"""Hand-placed sprites for the canal pound lock:

  icons/obj/canal_lock.dmi (32x32): a one-tile lock chamber that stands on a
      flooded trench. Stone chamber walls run down both sides, a pair of
      timber mitre gates closes each end and their balance beams reach out
      over the banks. dir is the direction of the upper (higher) pound.

      lock_low       chamber water low, lower gates open, upper gates shut
      lock_high      chamber water high, upper gates open, lower gates shut
      lock_filling   4 frames, plays once: both pairs shut, the water rising,
                     a white rush at the upper gates' paddles
      lock_emptying  4 frames, plays once: both pairs shut, the water
                     falling, the outflow below the lower gates

Every pixel is placed by this script from the fixed palettes below (Pillow
only); no external or generated artwork. The stone greys are the masonry
brazier's and the timber and iron are the catapult's, so the lock stands
beside the existing stonework and machines.

The lock is planned once on a grid that runs along the canal (u, 0 at the
upper end) and across it (v), as a material and a height for every cell, and
that plan is laid onto the tile for each direction. The shading is then done
on the tile from the heights, so the light stays upper left whichever way the
lock faces. Both pairs of gates point up the canal, as mitre gates do, and
swing back into recesses cut in the walls.

The pounds beyond the gates are left clear so the trench's own animated water
shows there. The chamber water is a see-through tint over the trench water:
a dark one with the wet wall face showing when the chamber is low, a faint
light one with a bright brim when it is high.

Run with Pillow to reproduce the sheet. `--check` verifies the committed
sheet matches and `--preview <png>` writes a 4x review sheet with every state,
direction and frame labelled, drawn over the flooded trench. Released under
Civ13 AGPL-3.0.
"""
import re
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
CANAL_LOCK = ROOT / 'icons/obj/canal_lock.dmi'
TRENCH = ROOT / 'icons/turf/trench.dmi'

SIZE = 32
DIRS = ('S', 'N', 'E', 'W')          # BYOND order inside a DMI
FRAMES = 4

OUT = (37, 21, 14)                   # the braziers' outline
# masonry brazier greys, light to dark
STONE = [(176, 176, 176), (157, 157, 157), (138, 138, 138), (117, 117, 117), (95, 95, 95), (76, 76, 76),
         (58, 58, 58), (46, 46, 46)]
# the wet wall face inside the chamber, top to waterline
WET = [(86, 88, 80), (68, 72, 64), (52, 56, 50)]
# catapult timber, light to dark
WOOD = [(152, 78, 26), (135, 66, 20), (120, 58, 18), (105, 52, 16), (87, 43, 13), (70, 34, 11), (55, 28, 9)]
# wrought iron
IRON = [(150, 154, 166), (116, 120, 134), (86, 90, 104), (62, 64, 78), (42, 44, 54)]
# chamber water tints over the trench water: (colour, alpha) low and high
LOW_TINT = ((22, 30, 30), 168)
HIGH_TINT = ((150, 164, 150), 46)
BRIM = (188, 200, 184)               # the bright line where high water meets the wall
FOAM = [(244, 250, 250), (214, 230, 232), (176, 200, 204)]

WALL = 6                             # the walls are v 0..5 and 26..31
RECESS = 4                           # the gate recesses cut the wall back to v 0..3
MID = 16                             # the mitre is at v 15 | 16
UPPER, LOWER = 7, 28                 # u of each pair's heel posts
RISE = 4                             # how far up the canal the mitre stands from the heels
UPPER_RECESS = (0, UPPER)            # u range of each recess
LOWER_RECESS = (19, LOWER)
FACE = 3                             # width of wall face showing when the chamber is low

# heights, for the shading
H_WALL, H_GATE, H_BEAM, H_POST = 4, 6, 8, 9


def noise(x, y, seed=0):
    """A fixed pseudo-random number 0..255, the same on every run."""
    v = (x * 73856093) ^ (y * 19349663) ^ (seed * 2654435761)
    v = (v ^ (v >> 13)) * 1274126177
    return ((v ^ (v >> 16)) >> 4) & 255


def step(ramp, i):
    return ramp[max(0, min(len(ramp) - 1, int(i)))]


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(len(a)))


# -------------------------------------------------------------------- plan --
# A plan is {(u, v): (material, height, detail)}. Cells that are absent are
# clear, so the trench water shows.

def both(plan, u, v, cell):
    """Set a cell and its mirror on the other bank."""
    for vv in (v, SIZE - 1 - v):
        if 0 <= u < SIZE and 0 <= vv < SIZE:
            plan[(u, vv)] = cell


def walls(plan):
    for u in range(SIZE):
        cut = any(lo <= u <= hi for lo, hi in (UPPER_RECESS, LOWER_RECESS))
        for v in range(RECESS if cut else WALL):
            # coping stones: a joint every sixth pixel, a few worn ones
            joint = (u + 2) % 6 == 0 and v > 0
            worn = noise(u, v, 3) < 46
            both(plan, u, v, ('stone', H_WALL, 3 if joint else 1 + worn))
        if cut:
            for v in range(RECESS, WALL):
                both(plan, u, v, ('recess', 0, 0))


def chamber(plan, face):
    """The water between the two pairs of gates. face is how many pixels of
    wet wall show on each side: FACE when low, 0 when brimming."""
    level = 1.0 - face / FACE
    for u in range(SIZE):
        for v in range(WALL, MID):
            if not inside_chamber(u, v):
                continue
            d = v - WALL
            if d < face:
                both(plan, u, v, ('wet', 2 - d * 0.5, d + (FACE - face)))
            else:
                both(plan, u, v, ('water', 0, level))
    # the recesses fill too, where they open on the chamber
    for u in range(SIZE):
        for v in range(RECESS, WALL):
            if plan.get((u, v), ('', 0, 0))[0] == 'recess' and inside_chamber(u, WALL):
                both(plan, u, v, ('wet', 2, 2) if face else ('water', 0, level))


def leaf_u(heel, v):
    """u of a shut leaf's upstream edge at v (left bank half)."""
    return heel - (max(0, v - RECESS) * RISE + 5) // (MID - 1 - RECESS)


def inside_chamber(u, v):
    """Between the shut upper leaves and the shut lower leaves."""
    return leaf_u(UPPER, v) + 1 < u < leaf_u(LOWER, v)


def gates(plan, heel, shut, recess):
    lo, hi = recess
    if shut:
        for v in range(RECESS, MID):
            u = leaf_u(heel, v)
            for k in (0, 1):
                both(plan, u + k, v, ('wood', H_GATE, 1 + k))
        # the paddle gear, an iron rack standing on each leaf
        u = leaf_u(heel, 10)
        both(plan, u, 10, ('iron', H_POST, 1))
        both(plan, u + 1, 10, ('iron', H_POST, 3))
        # the mitre posts, where the two leaves meet
        u = leaf_u(heel, MID - 1)
        both(plan, u, MID - 1, ('wood', H_POST, 0))
        both(plan, u + 1, MID - 1, ('wood', H_POST, 3))
        # the balance beam runs on from the heel out over the bank
        for v in range(RECESS, -1, -1):
            u = heel + ((RECESS - v) * 2 + 2) // 4
            for k in (0, 1):
                both(plan, u + k, v, ('wood', H_BEAM, 0 if k == 0 else 2))
        both(plan, heel + 2, 0, ('iron', H_BEAM, 2))
    else:
        # swung back into the recess, the beam lying along the wall top
        for u in range(lo, heel + 1):
            for k in (0, 1):
                both(plan, u, RECESS + k, ('wood', H_GATE, 1 + k))
        mid = (lo + heel) // 2
        both(plan, mid, RECESS, ('iron', H_POST, 1))
        both(plan, mid, RECESS + 1, ('iron', H_POST, 3))
        if lo > 0:
            both(plan, lo, RECESS, ('wood', H_POST, 0))
            both(plan, lo, RECESS + 1, ('wood', H_POST, 3))
        for u in range(heel, heel + 8):
            v = RECESS - 1 - (u - heel) // 4
            for k in (0, 1):
                both(plan, u, v + k, ('wood', H_BEAM, 0 if k == 0 else 2))
        both(plan, heel + 7, RECESS - 2, ('iron', H_BEAM, 2))
    # heel posts, iron capped
    for du, dv, c in ((0, 0, 0), (1, 0, 1), (0, 1, 1), (1, 1, 3)):
        both(plan, heel + du, RECESS + dv, ('iron', H_POST, c))


def rush(plan, where, frame):
    """White water: below the upper paddles while filling, below the lower
    gates while emptying. It is strongest in the middle frames."""
    strength = (150, 215, 200, 110)[frame]
    for v in range(WALL + 1, MID):
        if where == 'upper':
            first, reach = leaf_u(UPPER, v) + 2, 5 + (frame > 0)
        else:
            first, reach = leaf_u(LOWER, v) + 2, 4
        # two streams a side, under the paddles, spreading as they go
        near = min(abs(v - 10), abs(v - 13))
        for i in range(reach):
            u = first + i
            n = noise(u, v, 11 + frame * 7)
            keep = strength - i * 30 - max(0, near - 1 - i // 2) * 60
            if n < keep:
                both(plan, u, v, ('foam', 0, 0 if n < keep // 3 and i < 3 else 1 + (i > 2)))


def plan_for(state, frame=0):
    plan = {}
    walls(plan)
    if state == 'lock_low':
        face, upper, lower = FACE, True, False
    elif state == 'lock_high':
        face, upper, lower = 0, False, True
    elif state == 'lock_filling':
        face, upper, lower = FACE - frame, True, True
    else:
        face, upper, lower = frame, True, True
    chamber(plan, face)
    if not upper:
        # open to the upper pound: the same brimming water runs in from the tile edge
        for u in range(UPPER + 2):
            for v in range(WALL, MID):
                both(plan, u, v, ('water', 0, 1.0))
    if not lower:
        # open to the lower pound: the low water runs out to the tile edge
        for u in range(LOWER - RISE, SIZE):
            for v in range(WALL, MID):
                d = v - WALL
                both(plan, u, v, ('wet', 2 - d * 0.5, d) if d < FACE else ('water', 0, 0.0))
            if u > LOWER:
                continue
            for v in range(RECESS, WALL):
                both(plan, u, v, ('wet', 2, 2))
    gates(plan, UPPER, upper, UPPER_RECESS)
    gates(plan, LOWER, lower, LOWER_RECESS)
    if state == 'lock_filling':
        rush(plan, 'upper', frame)
    elif state == 'lock_emptying':
        rush(plan, 'lower', frame)
    return plan


# ------------------------------------------------------------------- tiles --

def to_plan(d, x, y):
    """The plan cell under a tile pixel: dir is where the upper pound is."""
    if d == 'N':
        return y, x
    if d == 'S':
        return SIZE - 1 - y, x
    if d == 'E':
        return SIZE - 1 - x, y
    return x, y


def render(plan, d):
    cells = {}
    for y in range(SIZE):
        for x in range(SIZE):
            cell = plan.get(to_plan(d, x, y))
            if cell:
                cells[(x, y)] = cell

    def height(x, y):
        # past the tile edge the neighbour is taken to be the same height
        return cells.get((x, y), ('', 0, 0))[1] if 0 <= x < SIZE and 0 <= y < SIZE else None

    im = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    for y in range(SIZE):
        for x in range(SIZE):
            cell = cells.get((x, y))
            mat, h, detail = cell if cell else ('', 0, 0)
            lit = [height(x - 1, y), height(x, y - 1)]
            dark = [height(x + 1, y), height(x, y + 1)]
            up = sum(1 for n in lit if n is not None and n < h)
            down = sum(1 for n in dark if n is not None and n < h)
            # the shadow something tall throws down and to the right
            shade = 0
            for k in (1, 2):
                n = height(x - k, y - k)
                if n is not None and n - h >= 2 * k:
                    shade = max(shade, 3 - k)
            if mat == 'stone':
                c = step(STONE, detail - up + down * 2 + shade * 2)
                a = 255
            elif mat == 'wood':
                c = step(WOOD, detail - up + down * 2 + shade)
                if down == 2:
                    c = OUT
                a = 255
            elif mat == 'iron':
                c = step(IRON, detail - up + down + shade)
                a = 255
            elif mat in ('wet', 'recess'):
                c = step(WET, detail if mat == 'wet' else 1)
                if shade:
                    c = mix(c, OUT, 0.3 * shade)
                a = 255
            elif mat == 'water':
                c = mix(LOW_TINT[0], HIGH_TINT[0], detail)
                a = int(round(LOW_TINT[1] + (HIGH_TINT[1] - LOW_TINT[1]) * detail))
                if detail >= 1.0 and any(n is not None and n == H_WALL
                                         for n in lit + dark):
                    c, a = BRIM, 150                   # the brim against the coping
                elif noise(x // 2, y, 5) < 22:
                    c, a = mix(c, BRIM, 0.5), min(255, a + 30)   # a glint
                if shade:
                    c, a = mix(c, (10, 14, 14), 0.5), min(255, a + 45 * shade)
            elif mat == 'foam':
                c, a = FOAM[detail], (240, 205, 150)[detail]
            elif shade:
                c, a = (10, 14, 14), 50 * shade        # shadow on the open pound
            else:
                continue
            im.putpixel((x, y), (c[0], c[1], c[2], a))
    return im


def lock(state, frame=0):
    plan = plan_for(state, frame)
    return [render(plan, d) for d in DIRS]


# ------------------------------------------------------------------ sheets --

def lock_states():
    """[(state, frames, delay, loop)]; frames is a list of per-frame dir lists,
    loop 0 repeats for ever."""
    return [
        ('lock_low', [lock('lock_low')], 0, 0),
        ('lock_high', [lock('lock_high')], 0, 0),
        ('lock_filling', [lock('lock_filling', f) for f in range(FRAMES)], 2, 1),
        ('lock_emptying', [lock('lock_emptying', f) for f in range(FRAMES)], 2, 1),
    ]


def sheets():
    return [(CANAL_LOCK, lock_states())]


def build(states):
    icons = [im for _, frames, _, _ in states for row in frames for im in row]
    cols = int(len(icons) ** 0.5 + 0.999)
    rows = (len(icons) + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * SIZE, rows * SIZE))
    for i, im in enumerate(icons):
        sheet.paste(im, ((i % cols) * SIZE, (i // cols) * SIZE))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = %d\n\theight = %d\n' % (SIZE, SIZE)
    for name, frames, delay, loop in states:
        text += 'state = "%s"\n\tdirs = %d\n\tframes = %d\n' % (name, len(frames[0]), len(frames))
        if len(frames) > 1:
            text += '\tdelay = %s\n' % ','.join(['%g' % delay] * len(frames))
            if loop:
                text += '\tloop = %d\n' % loop
    text += '# END DMI\n'
    return sheet, text


def write_dmi(path, sheet, text):
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta, optimize=True)


def same(path, sheet, text):
    if not path.exists():
        return False
    old = Image.open(path)
    return old.info.get('Description') == text and old.size == sheet.size \
        and old.convert('RGBA').tobytes() == sheet.tobytes()


def existing(sheet, state):
    """The first icon of a state in an existing sheet; None if absent."""
    try:
        im = Image.open(sheet)
        index = 0
        for name, dirs, frames in re.findall(r'state = "(.*?)"\n\tdirs = (\d+)\n\tframes = (\d+)',
                                             im.info.get('Description', '')):
            if name == state:
                cols = im.size[0] // SIZE
                x, y = (index % cols) * SIZE, (index // cols) * SIZE
                return im.convert('RGBA').crop((x, y, x + SIZE, y + SIZE))
            index += int(dirs) * int(frames)
    except OSError:
        pass
    return None


def preview(path, built, scale=4):
    """Every state, direction and frame at 4x, each cell labelled, drawn over
    the flooded trench it stands on."""
    trench = existing(TRENCH, 'trench_flooded') or Image.new('RGBA', (SIZE, SIZE), (82, 85, 68, 255))
    pad, label = 6, 12
    rows = []                                   # (title, [(caption, image)])
    for sheet_path, states in built:
        for name, frames, delay, loop in states:
            if len(frames) == 1:
                rows.append(('%s  %s (%d dirs)' % (sheet_path.name, name, len(frames[0])),
                             [(DIRS[i], im) for i, im in enumerate(frames[0])]))
                continue
            for i, d in enumerate(DIRS):
                rows.append(('%s  %s %s (%d frames, delay %g, %s)' % (
                    sheet_path.name, name, d, len(frames), delay, 'loop %d' % loop if loop else 'looping'),
                    [('%d' % (k + 1), fr[i]) for k, fr in enumerate(frames)]))
    cell = SIZE * scale
    width = pad + max(len(cells) for _, cells in rows) * (cell + pad)
    height = pad + len(rows) * (label + label + cell + pad)
    out = Image.new('RGBA', (width, height), (24, 24, 24, 255))
    draw = ImageDraw.Draw(out)
    y = pad
    for title, cells in rows:
        draw.text((pad, y), title, fill=(240, 240, 240, 255))
        y += label
        for i, (caption, im) in enumerate(cells):
            x = pad + i * (cell + pad)
            draw.text((x, y), caption[:21], fill=(200, 220, 160, 255))
            tile = trench.copy()
            tile.alpha_composite(im)
            out.paste(tile.resize((cell, cell), Image.NEAREST), (x, y + label))
        y += label + cell + pad
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    out.save(path, format='PNG')


def main(argv):
    built = sheets()
    if '--check' in argv:
        for path, states in built:
            if not same(path, *build(states)):
                sys.exit('stale sheet: ' + str(path))
        print('canal lock sheet matches')
    else:
        for path, states in built:
            write_dmi(path, *build(states))
            print('wrote %s (%d states)' % (path.relative_to(ROOT), len(states)))
    if '--preview' in argv:
        preview(argv[argv.index('--preview') + 1], built)


if __name__ == '__main__':
    main(sys.argv[1:])
