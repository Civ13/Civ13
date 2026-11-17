"""Hand-placed 32px fittings for multi-storey houses, icons/obj/storey_fittings.dmi.

  chimney        (1 dir): a rough fieldstone flue, 16px wide, standing on the
                 floor and running off the top of the tile: a solid column
                 that passes up through the room into the storey above.
  chimney_top    (1 dir): the same column ending in a stone slab cap with the
                 sooty flue mouth in it, for the storey with nothing built
                 above. The cap sits at row 9 so the smoke has room over it.
  chimney_smoke  (1 dir, 4 frames of 3 ticks, looping): only thin grey wisps
                 rising from the flue mouth of chimney_top, transparent
                 everywhere else. Laid over chimney_top while a fire burns
                 below.
  hoist          (4 dirs): a timber hoist on an upper floor - a short post on
                 a sill with knee braces, a jib arm reaching out over the
                 edge, an iron pulley wheel at the arm's end and a rope with a
                 hook hanging from it. The arm points in the facing direction
                 (SOUTH reaches toward the bottom of the tile, and so on).
  hoist_load     (4 dirs): the same hoist with a rope-slung crate on the rope,
                 shown while it is hauling.

Every pixel is placed by this script from the fixed palettes below (Pillow
only); no external or generated artwork. The stone, timber and iron ramps are
those of create_castle_defences.py and the rope and crate boards those of
create_lifting.py, so the pieces sit beside the parapets, hoardings and shear
legs. Things are seen three-quarters from above with the light from the upper
left: EAST and WEST hoists are seen from the side, the SOUTH arm comes toward
the viewer over its own post, and the NORTH arm runs away up the tile with
the pulley bracketed on its right side so the rope shows.

Run with Pillow to reproduce the sheet. `--check` verifies the committed sheet
matches and `--preview <png>` writes a 4x labelled review sheet. Released
under Civ13 AGPL-3.0.
"""
import math
import re
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/storey_fittings.dmi'
FLOORS = ROOT / 'icons/turf/floors.dmi'

SIZE = 32
DIRS = ('SOUTH', 'NORTH', 'EAST', 'WEST')      # BYOND order inside a DMI

OUT = (24, 20, 18)                  # outline
# castle_defences.dmi's dressed stone with the steps between, light to dark
STONE = [(226, 220, 204), (208, 202, 186), (192, 186, 170), (170, 164, 150), (148, 143, 131),
         (126, 121, 111), (104, 99, 92), (76, 72, 68)]
MORTAR = (92, 86, 80)
SOOT = [(60, 54, 52), (36, 31, 31), (18, 15, 16)]
WOOD = [(198, 162, 114), (162, 124, 80), (126, 92, 56), (88, 62, 38)]
IRON = [(150, 152, 158), (104, 106, 112), (66, 68, 74), (40, 41, 46)]
ROPE = [(226, 208, 160), (186, 164, 112), (134, 114, 74)]
CRATE = [(176, 132, 84), (140, 98, 58), (98, 66, 38)]
SMOKE = [(222, 222, 220), (190, 190, 190), (156, 156, 158)]

SMOKE_FRAMES = 4
SMOKE_DELAY = 3


def noise(x, y, seed=0):
    """A fixed pseudo-random number 0..255, the same on every run."""
    v = (x * 73856093) ^ (y * 19349663) ^ (seed * 2654435761)
    v = (v ^ (v >> 13)) * 1274126177
    return ((v ^ (v >> 16)) >> 4) & 255


# ----------------------------------------------------------------- drawing --

def new():
    return Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))


def put(im, x, y, c, a=255):
    if 0 <= x < SIZE and 0 <= y < SIZE and c is not None:
        im.putpixel((x, y), (c[0], c[1], c[2], a))


def step(ramp, i):
    return ramp[max(0, min(len(ramp) - 1, int(i)))]


def outline(im, c=OUT):
    """A one pixel dark line around the drawn work."""
    src = im.copy()
    for y in range(SIZE):
        for x in range(SIZE):
            if src.getpixel((x, y))[3]:
                continue
            for ax, ay in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= ax < SIZE and 0 <= ay < SIZE and src.getpixel((ax, ay))[3]:
                    put(im, x, y, c)
                    break
    return im


def over(*layers):
    im = new()
    for layer in layers:
        im.alpha_composite(layer)
    return im


# ----------------------------------------------------------------- chimney --

COL_X0, COL_X1 = 8, 23              # the flue column, 16px wide
COL_FOOT = 28                       # its last row on the floor
COURSE = 4                          # three rows of stone and a mortar bed
CAP_Y = 9                           # top row of the cap slab on chimney_top
FLUE = (12, 19)                     # columns of the flue mouth in the cap
SMOKE_AT = (15.5, CAP_Y + 1)        # where the wisps leave the flue


def masonry(im, y_top):
    """Rough fieldstone courses from y_top down to the footing. Courses are
    counted from the floor so both chimney states share the same stones."""
    for y in range(y_top, COL_FOOT + 1):
        course = (COL_FOOT - y) // COURSE
        in_course = (COL_FOOT - y) % COURSE         # 0 is the mortar bed under the stones
        # the head joints of this course: uneven stones, broken bond
        joints, x = [], COL_X0 + 2 + (noise(course, 7, 1) % 4)
        while x < COL_X1:
            joints.append(x)
            x += 4 + noise(course, x, 2) % 4
        for x in range(COL_X0, COL_X1 + 1):
            if in_course == 0 or x in joints:
                c = MORTAR
            else:
                left = max([COL_X0 - 1] + [j for j in joints if j < x])
                right = min([COL_X1 + 1] + [j for j in joints if j > x])
                tone = 1 + noise(course, left, 3) % 4           # each stone its own grey
                if in_course == 3:
                    tone -= 1                                   # lit upper edge
                if x == left + 1:
                    tone -= 1                                   # lit left edge
                if in_course == 1 and x == right - 1:
                    tone += 2                                   # rounded lower right corner
                elif in_course == 1 or x == right - 1:
                    tone += 1
                if in_course == 3 and x == left + 1 and right - left > 3:
                    c = MORTAR                                  # rounded upper left corner
                else:
                    if noise(x, y, 4) < 26:
                        tone += 1                               # pitting
                    if x >= COL_X1 - 2:
                        tone += 2                               # the shaded right side
                    elif x >= COL_X1 - 4:
                        tone += 1
                    if x == COL_X0:
                        tone -= 1
                    c = step(STONE, tone)
            if c is MORTAR and x >= COL_X1 - 2:
                c = STONE[7]
            put(im, x, y, c)


def footing(im):
    """A course of bigger stones a pixel proud of the column, on the floor."""
    for y in range(COL_FOOT - 2, COL_FOOT + 1):
        for x in range(COL_X0 - 1, COL_X1 + 2):
            tone = (2, 4, 5)[y - (COL_FOOT - 2)]
            if x in (COL_X0 + 4, COL_X0 + 10) and y > COL_FOOT - 2:
                tone = 6                                        # joints
            if x >= COL_X1 - 1:
                tone += 1
            if x == COL_X0 - 1:
                tone -= 1
            put(im, x, y, step(STONE, tone))


def chimney():
    im = new()
    masonry(im, 0)
    footing(im)
    return outline(im)


def chimney_top():
    im = new()
    masonry(im, CAP_Y + 5)
    footing(im)
    for y in (CAP_Y + 5, CAP_Y + 6):                            # the cap's shadow and soot under it
        for x in range(COL_X0, COL_X1 + 1):
            if y == CAP_Y + 5 or noise(x, y, 5) < 90:
                put(im, x, y, STONE[6] if x < COL_X1 - 2 else STONE[7])
    for y in range(CAP_Y, CAP_Y + 5):                           # the slab, two pixels proud each side
        for x in range(COL_X0 - 2, COL_X1 + 3):
            row = y - CAP_Y
            if row < 3:                                         # its top face
                tone = 0 if row == 0 else 1
                if noise(x, y, 6) < 40:
                    tone += 1
            else:                                               # its front edge
                tone = 3 if row == 3 else 5
            if x >= COL_X1 + 1:
                tone += 1
            if x == COL_X0 - 2 and row >= 3:
                tone -= 1
            put(im, x, y, step(STONE, tone))
    for y in (CAP_Y, CAP_Y + 1):                                # the flue mouth, sooted
        for x in range(FLUE[0], FLUE[1] + 1):
            edge = x in FLUE
            put(im, x, y, SOOT[0] if edge and y == CAP_Y + 1 else (SOOT[1] if edge or y == CAP_Y + 1 else SOOT[2]))
    for x in range(FLUE[0] - 1, FLUE[1] + 2):                   # soot spilled round it
        if noise(x, 2, 7) < 150:
            put(im, x, CAP_Y + 2, STONE[4])
    put(im, FLUE[0] - 1, CAP_Y + 1, STONE[3])
    put(im, FLUE[1] + 1, CAP_Y + 1, STONE[3])
    return outline(im)


def chimney_smoke(frame):
    """Two thin wisps climbing from the flue mouth. The curl repeats every 8
    rows and climbs 2 rows a frame, so the 4 frames loop without a jump."""
    im = new()
    cx, y0 = SMOKE_AT
    for strand, (side, phase, start) in enumerate(((-1.6, 0.0, 0), (1.6, 3.0, 2))):
        for y in range(y0 - start, -1, -1):
            rise = y0 - y                                       # rows above the flue
            t = 2 * math.pi * (y + 2 * frame + phase) / 8.0
            x = int(round(cx + side * min(1.0, rise / 3.0) + (0.5 + rise * 0.07) * math.sin(t) + rise * 0.15))
            puff = 0.5 + 0.5 * math.cos(2 * math.pi * (y + 2 * frame + phase * 2 + strand * 3) / 8.0)
            alpha = (190 - rise * 13) * (0.45 + 0.55 * puff)
            if alpha < 24:
                continue
            put(im, x, y, SMOKE[0 if puff > 0.6 else 1], int(alpha))
            if puff > 0.8 and rise > 2:                         # a thicker curl
                put(im, x + 1, y, SMOKE[2], int(alpha * 0.55))
    return im


# ------------------------------------------------------------------- hoist --

def beam_h(im, x0, x1, y, mx):
    """A three pixel timber lying across the tile, seen from the side."""
    for x in range(x0, x1 + 1):
        grain = noise(x // 3, y, 11) < 60
        put(im, mx(x), y, WOOD[0])
        put(im, mx(x), y + 1, WOOD[2 if grain else 1])
        put(im, mx(x), y + 2, WOOD[3])


def beam_v(im, x0, y0, y1, tones=(0, 1, 1, 3)):
    """A four pixel timber standing or running up the tile; x0 is its left column."""
    for y in range(y0, y1 + 1):
        for i, tone in enumerate(tones):
            if 0 < i < 3 and noise(x0 + i, y // 3, 12) < 50:
                tone = min(3, tone + 1)
            put(im, x0 + i, y, WOOD[tone])


def strut(im, xa, ya, xb, yb, tone=1):
    """A two pixel knee brace from (xa, ya) to (xb, yb)."""
    n = max(abs(xb - xa), abs(yb - ya))
    for i in range(n + 1):
        x = xa + round((xb - xa) * i / n)
        y = ya + round((yb - ya) * i / n)
        put(im, x, y, WOOD[tone])
        put(im, x, y + 1, WOOD[min(3, tone + 2)])


def wheel(im, cx, cy):
    """The iron pulley sheave, five pixels across, hub at (cx, cy)."""
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            if abs(dx) == 2 and abs(dy) == 2:
                continue
            rim = max(abs(dx), abs(dy)) == 2
            if rim:
                c = IRON[1] if dx + dy < 0 else IRON[2]
            else:
                c = IRON[0] if dx + dy <= 0 else IRON[1]
            put(im, cx + dx, cy + dy, c)
    put(im, cx - 1, cy - 2, IRON[0])                            # glint on the rim
    put(im, cx, cy, IRON[3])                                    # the pin


def rope(im, x, y0, y1):
    for y in range(y0, y1 + 1):
        put(im, x, y, ROPE[0] if (y - y0) % 3 != 2 else ROPE[2])


def hook(im, x, y, back=-1):
    """An iron hook under the rope end at (x, y); it curls toward `back`."""
    put(im, x, y, IRON[1])
    put(im, x, y + 1, IRON[0])
    put(im, x + back, y + 2, IRON[1])
    put(im, x + 2 * back, y + 1, IRON[2])


def load(im, x, y):
    """A rope-slung crate, eight pixels wide; the rope ends at (x, y) over
    its middle (x is the left of the two middle columns)."""
    for i, (a, b) in enumerate(((x, x + 1), (x - 1, x + 2), (x - 2, x + 3))):   # the sling spreading
        put(im, a, y + 1 + i, ROPE[0])
        put(im, b, y + 1 + i, ROPE[1])
    x0, top = x - 3, y + 4
    for yy in range(top, top + 7):
        for xx in range(x0, x0 + 8):
            row = yy - top
            if row < 2:                                         # the lid
                tone = 0
                if row == 1 and xx in (x0 + 2, x0 + 5):
                    tone = 1
            else:                                               # the boarded front
                tone = 2 if row in (2, 6) or xx in (x0, x0 + 7) else 1
                if row == 4 and x0 < xx < x0 + 7:
                    tone = 2                                    # the board joint
            if xx == x0 + 7 and tone < 2:
                tone += 1
            put(im, xx, yy, CRATE[tone])
    for yy in range(top, top + 7):                              # the sling ropes round it
        put(im, x - 2, yy, ROPE[0] if yy % 2 else ROPE[1])
        put(im, x + 3, yy, ROPE[1] if yy % 2 else ROPE[2])


def hoist_side(flip, loaded):
    """EAST (and WEST when flipped): the hoist seen from the side."""
    mx = (lambda x: SIZE - 1 - x) if flip else (lambda x: x)
    frame = new()
    for x in range(2, 13):                                      # the sill on the floor
        for i, tone in enumerate((0, 1, 3)):
            put(frame, mx(x), 26 + i, WOOD[tone])
    beam_v(frame, min(mx(5), mx(8)), 5, 25)                     # the post
    if flip:
        strut(frame, mx(9), 19, mx(18), 9)
    else:
        strut(frame, 9, 19, 18, 9)
    beam_h(frame, 3, 26, 5, mx)                                 # the jib arm
    for i in range(3):                                          # its iron end band and the post strap
        put(frame, mx(25), 5 + i, IRON[i])
        put(frame, mx(4), 5 + i, IRON[i])
        put(frame, mx(9), 5 + i, IRON[i])
    put(frame, mx(26), 6, WOOD[2])                              # end grain
    put(frame, mx(26), 7, WOOD[3])
    tackle = new()
    put(tackle, mx(24), 8, IRON[2])                             # the strap the sheave hangs in
    wheel(tackle, mx(24), 10)
    rx = mx(26)
    if loaded:
        rope(tackle, rx, 10, 14)
        load(tackle, rx - 1 if flip else rx, 14)                # keeps a pixel clear at the tile edge
    else:
        rope(tackle, rx, 10, 21)
        hook(tackle, rx, 22, 1 if flip else -1)
    return over(outline(frame), outline(tackle))


def hoist_south(loaded):
    """The arm comes toward the viewer, over its own post, and ends above
    the bottom of the tile."""
    frame = new()
    for x in range(8, 24):                                      # the sill
        for i, tone in enumerate((0, 1, 3)):
            put(frame, x, 11 + i, WOOD[tone])
    strut(frame, 9, 10, 13, 4)                                  # knee braces up to the arm
    strut(frame, 22, 10, 18, 4, tone=2)
    beam_v(frame, 14, 1, 15, tones=(0, 0, 1, 2))                # the arm's lit top
    for i, c in enumerate((IRON[0], IRON[1], IRON[1], IRON[2])):
        put(frame, 14 + i, 3, c)                                # strap over the post head
        put(frame, 14 + i, 14, c)                               # the end band
    for i in range(4):
        put(frame, 14 + i, 16, WOOD[3 if i else 2])             # the cut end facing us
    tackle = new()
    wheel(tackle, 16, 18)
    if loaded:
        rope(tackle, 16, 21, 21)
        load(tackle, 15, 20)
    else:
        rope(tackle, 16, 21, 27)
        hook(tackle, 16, 28)
    return over(outline(frame), outline(tackle))


def hoist_north(loaded):
    """The arm runs away up the tile from a post at the bottom; the sheave is
    bracketed on the right of the arm's end so the rope shows beside it."""
    frame = new()
    for x in range(8, 24):                                      # the sill
        for i, tone in enumerate((0, 1, 3)):
            put(frame, x, 26 + i, WOOD[tone])
    strut(frame, 9, 24, 13, 18)                                 # knee braces up to the post
    strut(frame, 22, 24, 18, 18, tone=2)
    beam_v(frame, 14, 14, 25, tones=(1, 2, 2, 3))               # the post's shaded front
    beam_v(frame, 14, 1, 13, tones=(0, 0, 1, 2))                # the arm's lit top
    for i, c in enumerate((IRON[0], IRON[1], IRON[1], IRON[2])):
        put(frame, 14 + i, 12, c)                               # strap over the post head
        put(frame, 14 + i, 2, c)                                # the end band
    for x in (18, 19):                                          # the iron bracket to the sheave
        put(frame, x, 2, IRON[1])
        put(frame, x, 3, IRON[3])
    tackle = new()
    wheel(tackle, 21, 3)
    if loaded:
        rope(tackle, 21, 6, 7)
        load(tackle, 21, 7)
    else:
        rope(tackle, 21, 6, 14)
        hook(tackle, 21, 15)
    return over(outline(frame), outline(tackle))


def hoist(loaded=False):
    """The four facings in BYOND order."""
    return [hoist_south(loaded), hoist_north(loaded), hoist_side(False, loaded), hoist_side(True, loaded)]


# ------------------------------------------------------------------ sheets --

def all_states():
    """[(state, dirs, frames, delay or None, [images, frame by frame and dir by dir])]"""
    return [
        ('chimney', 1, 1, None, [chimney()]),
        ('chimney_top', 1, 1, None, [chimney_top()]),
        ('chimney_smoke', 1, SMOKE_FRAMES, SMOKE_DELAY, [chimney_smoke(f) for f in range(SMOKE_FRAMES)]),
        ('hoist', 4, 1, None, hoist()),
        ('hoist_load', 4, 1, None, hoist(loaded=True)),
    ]


def build(states):
    images = [im for st in states for im in st[4]]
    cols = int(len(images) ** 0.5 + 0.999)
    rows = (len(images) + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * SIZE, rows * SIZE))
    for i, im in enumerate(images):
        sheet.paste(im, ((i % cols) * SIZE, (i // cols) * SIZE))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = %d\n\theight = %d\n' % (SIZE, SIZE)
    for name, dirs, frames, delay, _ in states:
        text += 'state = "%s"\n\tdirs = %d\n\tframes = %d\n' % (name, dirs, frames)
        if delay:
            text += '\tdelay = %s\n' % ','.join([str(delay)] * frames)
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


def check_drawing(states):
    """The promises the game code relies on."""
    by = {st[0]: st for st in states}
    col = by['chimney'][4][0]
    assert all(col.getpixel((x, 0))[3] == 255 for x in range(COL_X0, COL_X1 + 1)), 'chimney must run off the top'
    top = by['chimney_top'][4][0]
    assert not any(top.getpixel((x, y))[3] for y in range(CAP_Y - 1) for x in range(SIZE)), 'no room for smoke'
    for im in by['chimney_smoke'][4]:
        for y in range(SIZE):
            for x in range(SIZE):
                if im.getpixel((x, y))[3]:
                    assert y <= SMOKE_AT[1] and COL_X0 - 2 <= x <= COL_X1 + 2, 'smoke strays from the flue'
    for name in ('hoist', 'hoist_load'):
        for d, im in zip(DIRS, by[name][4]):
            box = im.getbbox()
            reach = {'SOUTH': box[3] >= 28, 'NORTH': box[1] <= 1, 'EAST': box[2] >= 28, 'WEST': box[0] <= 4}[d]
            assert reach, '%s %s does not reach its edge' % (name, d)
    for a, b in zip(by['hoist'][4], by['hoist_load'][4]):
        assert a.tobytes() != b.tobytes()


def floor_tile(state):
    """A floor from floors.dmi to stand the pieces on; None if absent."""
    try:
        im = Image.open(FLOORS)
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


def preview(path, states, scale=4):
    """Every icon at 4x on a wooden floor, on cobbles and on a dark roof, each
    labelled, with the smoke laid over chimney_top, a two-storey stack and a
    1x strip."""
    by = {st[0]: st for st in states}
    backs = [('wooden floor', floor_tile('wood') or Image.new('RGBA', (SIZE, SIZE), (124, 88, 56, 255))),
             ('cobbles', floor_tile('cobble_horizontal') or Image.new('RGBA', (SIZE, SIZE), (120, 120, 116, 255))),
             ('dark roof', Image.new('RGBA', (SIZE, SIZE), (58, 44, 40, 255)))]
    cells = []                                  # (caption, image)
    for name, dirs, frames, _, images in states:
        for i, im in enumerate(images):
            if dirs > 1:
                cap = '%s %s' % (name, DIRS[i])
            elif frames > 1:
                cap = '%s f%d' % (name, i + 1)
            else:
                cap = name
            cells.append((cap, im))
    top = by['chimney_top'][4][0]
    for f, smoke in enumerate(by['chimney_smoke'][4]):
        cells.append(('top + smoke f%d' % (f + 1), over(top, smoke)))
    cell, pad, label = SIZE * scale, 6, 12
    per_row = 7
    grid_rows = [cells[i:i + per_row] for i in range(0, len(cells), per_row)]
    width = pad + per_row * (cell + pad) + 2 * SIZE + 3 * pad
    height = pad + len(backs) * (label + len(grid_rows) * (label + cell + pad)) + label + SIZE + 3 * pad
    out = Image.new('RGBA', (width, height), (24, 24, 24, 255))
    draw = ImageDraw.Draw(out)
    y = pad
    for title, back in backs:
        draw.text((pad, y), '%s  on %s' % (SHEET.name, title), fill=(240, 240, 240, 255))
        y += label
        if title == 'wooden floor':             # the column through two storeys, at 2x
            sx = pad + per_row * (cell + pad) + pad
            draw.text((sx, y), 'stacked 2x', fill=(200, 220, 160, 255))
            stack = Image.new('RGBA', (SIZE, SIZE * 2))
            for i, im in enumerate((over(top, by['chimney_smoke'][4][0]), by['chimney'][4][0])):
                tile = back.copy()
                tile.alpha_composite(im)
                stack.paste(tile, (0, i * SIZE))
            out.paste(stack.resize((SIZE * 2, SIZE * 4), Image.NEAREST), (sx, y + label))
        for row in grid_rows:
            for i, (caption, im) in enumerate(row):
                x = pad + i * (cell + pad)
                draw.text((x, y), caption[:21], fill=(200, 220, 160, 255))
                tile = back.copy()
                tile.alpha_composite(im)
                out.paste(tile.resize((cell, cell), Image.NEAREST), (x, y + label))
            y += label + cell + pad
    draw.text((pad, y), '1x (game scale), same order, on the wooden floor', fill=(240, 240, 240, 255))
    y += label
    for i, (_, im) in enumerate(cells):
        tile = backs[0][1].copy()
        tile.alpha_composite(im)
        out.paste(tile, (pad + i * (SIZE + 2), y))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    out.save(path, format='PNG')


def main(argv):
    states = all_states()
    check_drawing(states)
    if '--check' in argv:
        if not same(SHEET, *build(states)):
            sys.exit('stale sheet: ' + str(SHEET))
        print('storey fittings sheet matches')
    else:
        write_dmi(SHEET, *build(states))
        print('wrote %s (%d states)' % (SHEET.relative_to(ROOT), len(states)))
    if '--preview' in argv:
        preview(argv[argv.index('--preview') + 1], states)


if __name__ == '__main__':
    main(sys.argv[1:])
