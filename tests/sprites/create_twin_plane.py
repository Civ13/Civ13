"""Hand-placed pieces for a twin-engine plane, five sections across the wings
and four long, appended to icons/obj/vehicles/lightplane.dmi.

Every pixel is placed by this script (Pillow only) from the colours already in
the light plane sheet; no external or generated artwork. The middle of the
plane reuses the light plane's own tiles (nose_center, cockpit, fuselage_*,
tail_center); the new tiles are cut from the existing nose, wing and tail tiles
and redrawn where the wider wing, the engine nacelles and the wider tailplane
need it. All art is drawn facing NORTH; the other three facings are quarter
turns, exactly as the existing states are.

Run it to append the twin_* states. Existing states are read back afterwards
and must be pixel-identical or the script fails. It is safe to run again: the
twin_* states are dropped and redrawn from the original ones.

    python3 tests/sprites/create_twin_plane.py
        [--check]            verify the sheet on disk matches this script
        [--preview out.png]  assembled plane, outside/inside/engines running
        [--layout out.json]  tile-by-tile layout of the plane facing north

Released under Civ13 AGPL-3.0.
"""
import json
import re
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/vehicles/lightplane.dmi'
SIZE = 32
COLUMNS = 11
PREFIX = 'twin_'

# The light plane palette (every colour below is already in the sheet).
CLEAR = (0, 0, 0, 0)
SKIN = (188, 193, 198, 255)     # hull and wing skin
LINE = (58, 62, 66, 255)        # outline
PANEL = (150, 156, 162, 255)    # panel seams
SPAR = (124, 130, 136, 255)     # leading-edge spar line
SHINE = (224, 228, 231, 255)    # highlight
COWL = (132, 138, 144, 255)     # engine cowling
VENT = (96, 101, 106, 255)      # cowling gills
RED = (156, 48, 42, 255)        # tip paint
DECK = (84, 86, 88, 255)        # deck seen from inside
PLANK = (60, 62, 64, 255)       # deck seams
RIM = (118, 121, 124, 255)      # deck edge
BLADE = (44, 44, 46, 255)       # propeller
BLADE_TIP = (222, 200, 70, 255)
BLUR = (40, 40, 42, 150)        # spinning blade
DISC = (70, 70, 72, 70)         # spinning disc

# BYOND stores four-direction states SOUTH, NORTH, EAST, WEST.
DIRS = ('S', 'N', 'E', 'W')


def turned(north):
    """The four facings of a tile drawn facing north."""
    return [north.rotate(180), north.copy(), north.rotate(-90), north.rotate(90)]


def mirror(im):
    return im.transpose(Image.FLIP_LEFT_RIGHT)


# ------------------------------------------------------------------ sheet io

def read_sheet(path):
    im = Image.open(path)
    text = im.info['Description']
    im = im.convert('RGBA')
    columns = im.width // SIZE
    states, n = [], 0
    for block in re.split(r'\nstate = ', text.split('# END DMI')[0])[1:]:
        name = re.match(r'"(.*?)"', block).group(1)
        dirs = int(re.search(r'dirs = (\d+)', block).group(1))
        count = int(re.search(r'frames = (\d+)', block).group(1))
        delay = re.search(r'delay = ([\d.,]+)', block)
        frames = []
        for _ in range(count):
            row = []
            for _ in range(dirs):
                x, y = (n % columns) * SIZE, (n // columns) * SIZE
                row.append(im.crop((x, y, x + SIZE, y + SIZE)))
                n += 1
            frames.append(row)
        states.append((name, frames, delay.group(1) if delay else None))
    return states


def write_sheet(path, states):
    cells = [im for _, frames, _ in states for fr in frames for im in fr]
    rows = (len(cells) + COLUMNS - 1) // COLUMNS
    sheet = Image.new('RGBA', (SIZE * COLUMNS, SIZE * rows), CLEAR)
    for n, im in enumerate(cells):
        sheet.paste(im, ((n % COLUMNS) * SIZE, (n // COLUMNS) * SIZE))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = %d\n\theight = %d\n' % (SIZE, SIZE)
    for name, frames, delay in states:
        text += 'state = "%s"\n\tdirs = %d\n\tframes = %d\n' % (name, len(frames[0]), len(frames))
        if delay:
            text += '\tdelay = %s\n' % delay
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta, optimize=True)


def same(a, b):
    return a.size == b.size and a.tobytes() == b.tobytes()


def same_states(a, b):
    if [(n, len(f), len(f[0]), d) for n, f, d in a] != [(n, len(f), len(f[0]), d) for n, f, d in b]:
        return False
    return all(same(x, y) for (_, fa, _), (_, fb, _) in zip(a, b)
               for ra, rb in zip(fa, fb) for x, y in zip(ra, rb))


# ------------------------------------------------------------------- drawing

def h(im, y, x0, x1, c):
    for x in range(x0, x1 + 1):
        im.putpixel((x, y), c)


def v(im, x, y0, y1, c):
    for y in range(y0, y1 + 1):
        im.putpixel((x, y), c)


def wing_column(im, x, seam=False):
    """One column of the straight wing, as the light plane's wing root has it."""
    v(im, x, 0, 1, CLEAR)
    im.putpixel((x, 2), LINE)
    v(im, x, 3, 16, SKIN)
    im.putpixel((x, 5), SPAR)
    im.putpixel((x, 17), SHINE)
    im.putpixel((x, 18), SKIN)
    im.putpixel((x, 19), LINE)
    v(im, x, 20, 31, CLEAR)
    if seam:
        v(im, x, 4, 16, PANEL)


# The nacelle outline, tile by tile: {row: (left edge, right edge)}. It is 12
# wide, starts 16 rows ahead of the wing row and ends 6 rows behind the wing.
NACELLE_FRONT = {16: (8, 17), 17: (8, 17), 18: (8, 17), 19: (8, 17)}
NACELLE_FRONT.update({y: (7, 18) for y in range(20, 32)})
NACELLE_BACK = {y: (7, 18) for y in range(0, 14)}
NACELLE_BACK.update({14: (8, 17), 15: (8, 17), 16: (8, 17), 17: (9, 16), 18: (9, 16), 19: (9, 16),
                     20: (10, 15), 21: (10, 15), 22: (10, 15), 23: (11, 14), 24: (11, 14), 25: (12, 13)})
COWL_END = 4    # row of the wing tile where the cowling meets the nacelle body


def engine_tile(nose, inside):
    """Row 1, beside the nose: the engine cowling ahead of the wing. From the
    light plane's nose corner, without its fixed wheel (the gear folds into
    the nacelle)."""
    im = nose.copy()
    for y in range(18, 25):
        h(im, y, 21, 23, CLEAR)
    h(im, 21, 24, 31, CLEAR)
    edge = RIM if inside else LINE
    for y, (x0, x1) in NACELLE_FRONT.items():
        h(im, y, x0, x1, COWL)
        im.putpixel((x0, y), edge)
        im.putpixel((x1, y), edge)
    h(im, 16, 8, 17, edge)
    h(im, 18, 11, 14, VENT)
    for y in (25, 28):
        h(im, y, 10, 15, VENT)
    return im


def nacelle_tile(wing, inside):
    """Row 2, beside the cockpit: the wing carried straight through, with the
    nacelle over it. Columns 26-31 keep the light plane's fuselage side."""
    im = wing.copy()
    for x in range(0, 26):
        wing_column(im, x, seam=x in (6, 16))
    im.putpixel((25, 5), SKIN)
    edge = RIM if inside else LINE
    for y, (x0, x1) in NACELLE_BACK.items():
        if y < COWL_END:
            fill = COWL
        else:
            fill = DECK if inside else SKIN
        h(im, y, x0, x1, fill)
        im.putpixel((x0, y), edge)
        im.putpixel((x1, y), edge)
    h(im, COWL_END, 7, 18, edge)
    if inside:
        # An open bay in the wing for the fuel tank, planked like the deck.
        for y in (9, 15, 21):
            x0, x1 = NACELLE_BACK[y]
            h(im, y, x0 + 1, x1 - 1, PLANK)
    else:
        h(im, 1, 10, 15, VENT)
        v(im, 12, 6, 21, SHINE)
        v(im, 13, 6, 21, SHINE)
    return im


def wing_tip_tile(wing):
    """Row 2, outermost: the light plane's wing tip with the wing carried on
    where its fuselage side was."""
    im = wing.copy()
    for x in range(25, 32):
        wing_column(im, x, seam=x == 26)
    # The aileron: a seam along the outer trailing edge.
    h(im, 13, 7, 25, PANEL)
    return im


def tail_tile(tail, inside):
    """Row 4, beside the tail: the tailplane carried through to the edge."""
    im = tail.copy()
    edge, fill = (RIM, PLANK) if inside else (LINE, SKIN)
    for x in range(0, 9):
        im.putpixel((x, 16), edge)
        v(im, x, 17, 19, fill)
        im.putpixel((x, 20), edge)
    if not inside:
        v(im, 3, 17, 19, PANEL)
    return im


def tailplane_tile(inside):
    """Row 4, outermost: the tailplane's tip and its end fin."""
    im = Image.new('RGBA', (SIZE, SIZE), CLEAR)
    edge, fill = (RIM, PLANK) if inside else (LINE, SKIN)
    for x in range(20, 32):
        im.putpixel((x, 16), edge)
        v(im, x, 17, 19, fill)
        im.putpixel((x, 20), edge)
    if not inside:
        v(im, 27, 17, 19, PANEL)
    # The fin, seen edge on, with a red rudder tip like the centre fin's light.
    for x in (18, 19):
        v(im, x, 11, 22, edge)
        v(im, x, 23, 25, edge if inside else RED)
    im.putpixel((18, 10), edge)
    im.putpixel((19, 10), edge)
    return im


# The propeller sits four rows behind the cowling's front, like the nose one.
PROP_ROW = 20
PROP_X0, PROP_X1 = 0, 25
HUB = (12, 13)


def prop_tile():
    im = Image.new('RGBA', (SIZE, SIZE), CLEAR)
    for y in (PROP_ROW, PROP_ROW + 1):
        h(im, y, PROP_X0, PROP_X1, BLADE)
        h(im, y, PROP_X0, PROP_X0 + 2, BLADE_TIP)
        h(im, y, PROP_X1 - 2, PROP_X1, BLADE_TIP)
    h(im, PROP_ROW + 2, HUB[0], HUB[1], BLADE)
    return im


def prop_spin_tile(frame):
    im = Image.new('RGBA', (SIZE, SIZE), CLEAR)
    y = PROP_ROW + 1
    for dy, inset in ((-3, 6), (-2, 3), (-1, 1), (0, 0), (1, 1), (2, 3), (3, 6)):
        h(im, y + dy, PROP_X0 + inset, PROP_X1 - inset, DISC)
    h(im, y, PROP_X0, PROP_X0 + 1, BLADE_TIP)
    h(im, y, PROP_X1 - 1, PROP_X1, BLADE_TIP)
    h(im, y, HUB[0] - 5, HUB[0] - 1, BLUR)
    h(im, y, HUB[1] + 1, HUB[1] + 5, BLUR)
    h(im, y, HUB[0], HUB[1], BLADE)
    h(im, y + 1, HUB[0], HUB[1], BLADE)
    lead, trail = (y - 1, y + 1) if frame == 0 else (y + 1, y - 1)
    h(im, lead, PROP_X0 + 1, PROP_X0 + 6, BLUR)
    h(im, trail, PROP_X1 - 6, PROP_X1 - 1, BLUR)
    return im


# -------------------------------------------------------------------- states

def build(original):
    """The twin_* states, from the light plane's own north-facing tiles."""
    north = {name: frames[0][1] for name, frames, _ in original}

    def left(name):
        return north[name]

    def right(name):
        # Work on the right-hand tile as if it were a left-hand one.
        return mirror(north[name])

    tiles = {}
    for side, src, back in (('left', left, lambda im: im), ('right', right, mirror)):
        tiles['twin_engine_' + side] = back(engine_tile(src('nose_' + side), False))
        tiles['twin_engine_%s_floor' % side] = back(engine_tile(src('nose_%s_floor' % side), True))
        tiles['twin_nacelle_' + side] = back(nacelle_tile(src('wing_' + side), False))
        tiles['twin_nacelle_%s_floor' % side] = back(nacelle_tile(src('wing_%s_floor' % side), True))
        tip = back(wing_tip_tile(src('wing_' + side)))
        tiles['twin_wing_tip_' + side] = tip
        tiles['twin_wing_tip_%s_floor' % side] = tip
        tiles['twin_tail_' + side] = back(tail_tile(src('tail_' + side), False))
        tiles['twin_tail_%s_floor' % side] = back(tail_tile(src('tail_%s_floor' % side), True))
        tiles['twin_tailplane_' + side] = back(tailplane_tile(False))
        tiles['twin_tailplane_%s_floor' % side] = back(tailplane_tile(True))
    # The corners ahead of and behind the wing tips: open air.
    tiles['twin_open'] = Image.new('RGBA', (SIZE, SIZE), CLEAR)

    states = [(name, [turned(im)], None) for name, im in tiles.items()]
    for side, back in (('left', lambda im: im), ('right', mirror)):
        states.append(('twin_prop_' + side, [turned(back(prop_tile()))], None))
        states.append(('twin_prop_spin_' + side, [turned(back(prop_spin_tile(f))) for f in (0, 1)], '1,1'))
    return states


def allowed_colours(original):
    return {px for _, frames, _ in original for row in frames for im in row
            for px in set(im.getdata())}


# -------------------------------------------------------------------- layout

# The plane facing north: columns from its own left, rows from the nose.
# (state, roofed, prop overlay, solid outer sides, crew door)
TWIN = [
    [('twin_open', False, None, '', False),
     ('twin_engine_left', True, 'twin_prop_left', 'front (cowling)', False),
     ('nose_center', True, None, 'front', False),
     ('twin_engine_right', True, 'twin_prop_right', 'front (cowling)', False),
     ('twin_open', False, None, '', False)],
    [('twin_wing_tip_left', False, None, '', False),
     ('twin_nacelle_left', True, None, '', False),
     ('cockpit', True, None, '', False),
     ('twin_nacelle_right', True, None, '', False),
     ('twin_wing_tip_right', False, None, '', False)],
    [('twin_open', False, None, '', False),
     ('fuselage_left', True, None, 'left', False),
     ('fuselage_center', True, None, '', False),
     ('fuselage_right', True, None, 'right (the door)', True),
     ('twin_open', False, None, '', False)],
    [('twin_tailplane_left', True, None, '', False),
     ('twin_tail_left', True, None, 'left, back', False),
     ('tail_center', True, None, 'back', False),
     ('twin_tail_right', True, None, 'right, back', False),
     ('twin_tailplane_right', True, None, '', False)],
]

LIGHT = [
    [('nose_left', True, None), ('nose_center', True, 'prop'), ('nose_right', True, None)],
    [('wing_left', False, None), ('cockpit', True, None), ('wing_right', False, None)],
    [('fuselage_left', True, None), ('fuselage_center', True, None), ('fuselage_right', True, None)],
    [('tail_left', True, None), ('tail_center', True, None), ('tail_right', True, None)],
]


def layout_json():
    tiles = {}
    for r, row in enumerate(TWIN):
        for c, (state, roofed, prop, walls, door) in enumerate(row):
            tiles['%d,%d' % (c + 1, r + 1)] = {
                'state': state, 'roofed': roofed, 'prop': prop,
                'prop_spin': prop.replace('prop_', 'prop_spin_') if prop else None,
                'walls': walls or 'none', 'door': door}
    return {
        'icon': 'icons/obj/vehicles/lightplane.dmi',
        'facing': 'NORTH',
        'columns': 5,
        'rows': 4,
        'key': 'col,row - col 1 is the plane\'s own left side, row 1 is the nose',
        'tiles': tiles,
        'engines': ['2,1', '4,1'],
        'fuel_tanks': ['2,2', '4,2'],
        'pilot_seat': '3,2',
        'wheels': {
            'drawn': 'none - the gear folds into the nacelles, so no tile has a wheel painted on it',
            'corners': ['1,1', '5,1', '1,4', '5,4'],
            'suggested': ['2,1', '4,1', '2,4', '4,4'],
            'note': 'The hand-assembly survey wants a wheel on each corner frame, but the front '
                    'corners 1,1 and 5,1 are open air (twin_open). Wheels read best under the '
                    'engine cowlings (2,1 and 4,1) and under the tail (2,4 and 4,4); if they stay '
                    'on the corners they should be fitted inside the frame, not drawn.'},
        'notes': [
            'Roofed tiles show "<state>_floor" as the deck and "<state>" as the roof image.',
            'twin_wing_tip_* and twin_open are not roofed and show only "<state>".',
            'twin_open is a fully transparent tile: 1,1 5,1 1,3 and 5,3 have no airframe over them.',
            'Propeller overlays go on the engine tiles (2,1 and 4,1), above the roof image, '
            'not on nose_center.',
        ],
    }


# ------------------------------------------------------------------- preview

def assemble(cells, plan, d, inside, running):
    """A plane laid out for facing d (index into DIRS)."""
    rows, cols = len(plan), len(plan[0])
    along = d in (0, 1)
    out = Image.new('RGBA', ((cols if along else rows) * SIZE, (rows if along else cols) * SIZE), CLEAR)
    for r, row in enumerate(plan):
        for c, tile in enumerate(row):
            state, roofed, prop = tile[0], tile[1], tile[2]
            x, y = ((cols - 1 - c, rows - 1 - r), (c, r), (rows - 1 - r, c), (r, cols - 1 - c))[d]
            name = state + '_floor' if inside and roofed else state
            out.alpha_composite(cells[name][0][d], (x * SIZE, y * SIZE))
            if prop:
                if running:
                    prop = prop.replace('prop', 'prop_spin', 1)
                out.alpha_composite(cells[prop][0][d], (x * SIZE, y * SIZE))
    return out


def preview(path, states):
    cells = {name: frames for name, frames, _ in states}
    views = (('outside (roof states)', False, False), ('inside (deck states)', True, False),
             ('outside, engines running', False, True))
    scale, pad, label = 3, 12, 14
    block_w = 5 * SIZE + 4 * SIZE + 3 * pad
    block_h = 5 * SIZE + 2 * pad
    sheet = Image.new('RGBA', (4 * block_w, len(views) * block_h), (86, 124, 78, 255))
    for j, (_, inside, running) in enumerate(views):
        for d in range(4):
            twin = assemble(cells, TWIN, d, inside, running)
            light = assemble(cells, LIGHT, d, inside, running)
            x0, y0 = d * block_w + pad, j * block_h + pad
            sheet.alpha_composite(twin, (x0, y0))
            sheet.alpha_composite(light, (x0 + 5 * SIZE + pad, y0))
    sheet = sheet.resize((sheet.width * scale, sheet.height * scale), Image.NEAREST)
    draw = ImageDraw.Draw(sheet)
    names = {'S': 'SOUTH', 'N': 'NORTH', 'E': 'EAST', 'W': 'WEST'}
    for j, (title, _, _) in enumerate(views):
        for d in range(4):
            x0, y0 = d * block_w * scale + 8, (j + 1) * block_h * scale - label - 6
            draw.text((x0, y0), 'facing %s - %s - twin-engine 5x4, light plane 3x4'
                      % (names[DIRS[d]], title), fill=(255, 255, 255, 255))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


# ---------------------------------------------------------------------- main

def main(argv):
    on_disk = read_sheet(SHEET)
    original = [s for s in on_disk if not s[0].startswith(PREFIX)]
    new = build(original)
    palette = allowed_colours(original)
    for name, frames, _ in new:
        if len(frames[0]) != 4:
            sys.exit('FAIL: %s does not have four directions' % name)
        for row in frames:
            for im in row:
                stray = set(im.getdata()) - palette
                if stray:
                    sys.exit('FAIL: %s uses colours outside the sheet: %s' % (name, sorted(stray)))
    states = original + new
    if '--check' in argv:
        if not same_states(on_disk, states):
            sys.exit('FAIL: %s does not match this script; run it without --check' % SHEET)
        print('PASS: %s matches (%d original states, %d twin states)' % (SHEET.name, len(original), len(new)))
    else:
        write_sheet(SHEET, states)
        back = read_sheet(SHEET)
        if not same_states(back[:len(original)], original):
            sys.exit('FAIL: an existing state changed')
        if not same_states(back, states):
            sys.exit('FAIL: the sheet did not read back as written')
        print('PASS: %d existing states pixel-identical, %d twin states written: %s'
              % (len(original), len(new), ', '.join(n for n, _, _ in new)))
    if '--preview' in argv:
        preview(argv[argv.index('--preview') + 1], states)
    if '--layout' in argv:
        out = Path(argv[argv.index('--layout') + 1])
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(layout_json(), indent=2) + '\n')


if __name__ == '__main__':
    main(sys.argv[1:])
