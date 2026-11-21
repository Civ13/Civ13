"""Draw the berth and drydock sprites (original pixel art, no generated images).

icons/obj/berths.dmi, 32x32, one direction each:

- "dock_gate_shut" and "dock_gate_open": a pair of timber dock gates across a
  flooded trench, closed leaf to leaf or swung back against the walls. The
  channel shows through the clear pixels above, below and between the leaves.
- "refit_add", "refit_remove", "refit_change" and "refit_turn": chalk marks
  laid over a hull tile. They are drawn in white and pale grey because the
  game tints them with `color` (green, red, amber and a faint amber).
- "yard_office": the shipwright's office, with a rack of rolled draughts by
  the door and timber stacked at its side.
- "keel_blocks": three stacks of the blocks a keel rests on in a drydock.

The wood tones and the dark outline follow icons/obj/boathouse.dmi so the
yard sits beside the boathouse and its slip.

    python3 tests/naval_carrier/berth_sprites.py            # rewrite the DMI
    python3 tests/naval_carrier/berth_sprites.py --check    # fail when it is stale
    python3 tests/naval_carrier/berth_sprites.py --preview out.png

The preview shows the gates over flooded trench, the chalk marks tinted as the
game tints them over a wooden deck, and the rest on grass.
"""
from math import atan2, cos, radians, sin
from pathlib import Path
import sys

from PIL import Image, ImageDraw
from PIL.PngImagePlugin import PngInfo

ROOT = Path(__file__).resolve().parents[2]
BERTHS = ROOT / 'icons/obj/berths.dmi'

# Shared with the boathouse.
LINE = (22, 18, 16, 255)
OAK_DARK = (42, 33, 28, 255)
OAK_SHADE = (62, 52, 42, 255)
OAK = (88, 76, 60, 255)
OAK_LIGHT = (118, 102, 82, 255)
OAK_PALE = (146, 130, 106, 255)
WEATHERED = (176, 160, 134, 255)
WOOD_DARK = (74, 52, 32, 255)
WOOD_SHADE = (90, 62, 36, 255)
WOOD = (124, 90, 52, 255)
WOOD_MID = (156, 116, 70, 255)
WOOD_LIGHT = (180, 150, 96, 255)
WOOD_PALE = (206, 180, 140, 255)
WOOD_CUT = (232, 204, 150, 255)
IRON_DARK = (52, 54, 60, 255)
IRON = (92, 96, 104, 255)
IRON_LIGHT = (150, 152, 158, 255)
WET = (236, 248, 255, 190)
WET_THIN = (236, 248, 255, 110)
PAPER = (236, 228, 204, 255)
PAPER_SHADE = (196, 184, 152, 255)
RIBBON = (150, 52, 44, 255)
GLASS = (150, 196, 220, 255)
GLASS_DARK = (84, 140, 178, 255)
BRASS = (204, 166, 72, 255)
SHADOW = (0, 0, 0, 70)
CHALK = (244, 244, 238)
CHALK_GREY = (206, 208, 204)
CLEAR = (0, 0, 0, 0)


def blank(size=32):
    return Image.new('RGBA', (size, size), CLEAR)


def points(d, colour, *at):
    for xy in at:
        d.point(xy, fill=colour)


# --- dock gates -------------------------------------------------------------

def sluice_wheel(d, x, y):
    """A small iron handwheel on its spindle; (x, y) is the hub."""
    d.line((x, y + 1, x, y + 4), fill=IRON_DARK)
    d.ellipse((x - 3, y - 3, x + 3, y + 3), outline=LINE)
    d.ellipse((x - 2, y - 2, x + 2, y + 2), outline=IRON)
    points(d, IRON_LIGHT, (x - 1, y - 2), (x, y - 2), (x - 2, y - 1))
    d.line((x - 1, y, x + 1, y), fill=IRON_DARK)
    d.line((x, y - 1, x, y + 1), fill=IRON_DARK)
    d.point((x, y), fill=IRON_LIGHT)


def dock_gate_shut():
    im = blank()
    d = ImageDraw.Draw(im)
    # The two leaves, face on: wet oak planks under a capping rail.
    d.rectangle((2, 9, 29, 27), fill=OAK, outline=LINE)
    for x in range(3, 29):
        column = (x - 3) % 4
        tone = OAK_SHADE if column == 3 else OAK_LIGHT if column == 0 else OAK
        d.line((x, 10, x, 26), fill=tone)
    # Darker, wetter timber toward the waterline.
    for x in range(3, 29):
        if (x - 3) % 4 != 3:
            d.line((x, 23, x, 26), fill=OAK_SHADE)
        else:
            d.line((x, 23, x, 26), fill=OAK_DARK)
    # The capping rail, seen from above.
    d.rectangle((2, 6, 29, 9), fill=OAK_PALE, outline=LINE)
    d.line((3, 7, 28, 7), fill=WEATHERED)
    d.line((3, 8, 28, 8), fill=OAK_LIGHT)
    # Where the leaves meet.
    d.line((15, 6, 15, 27), fill=LINE)
    d.line((16, 7, 16, 26), fill=OAK_DARK)
    # Iron straps with their bolts.
    for y in (12, 20):
        d.rectangle((3, y, 28, y + 1), fill=IRON)
        d.line((3, y, 28, y), fill=IRON_LIGHT)
        d.line((3, y + 2, 28, y + 2), fill=OAK_DARK)
        for x in (4, 9, 13, 18, 22, 27):
            d.point((x, y + 1), fill=IRON_DARK)
        d.line((15, y, 16, y + 1), fill=LINE)
    # Heel posts against the dock walls.
    for x in (0, 29):
        d.rectangle((x, 4, x + 2, 28), fill=OAK_SHADE, outline=LINE)
        d.line((x + 1, 5, x + 1, 27), fill=OAK_LIGHT)
        d.point((x + 1, 5), fill=WEATHERED)
    sluice_wheel(d, 22, 5)
    # Water lapping the foot of the gates.
    points(d, WET, (4, 28), (5, 28), (11, 28), (19, 28), (20, 28), (26, 28))
    points(d, WET_THIN, (6, 28), (10, 28), (12, 29), (18, 28), (25, 28), (5, 29), (20, 29))
    return im


def dock_gate_open():
    im = blank()
    d = ImageDraw.Draw(im)
    for left in (True, False):
        x = 0 if left else 26
        # The leaf lies back along the wall: its capping rail runs away from us...
        d.rectangle((x, 3, x + 5, 28), fill=OAK, outline=LINE)
        rail = (x + 1, x + 2) if left else (x + 3, x + 4)
        face = (x + 3, x + 4) if left else (x + 1, x + 2)
        d.line((rail[0], 4, rail[0], 22), fill=WEATHERED if left else OAK_PALE)
        d.line((rail[1], 4, rail[1], 22), fill=OAK_PALE if left else WEATHERED)
        # ...with the planked face turned to the channel.
        d.line((face[0], 4, face[0], 22), fill=OAK_LIGHT if left else OAK_SHADE)
        d.line((face[1], 4, face[1], 22), fill=OAK_SHADE if left else OAK_LIGHT)
        for y in (9, 15):
            d.line((face[0], y, face[1], y), fill=OAK_DARK)
        # The straps wrap over the rail.
        for y in (6, 18):
            d.line((x + 1, y, x + 4, y), fill=IRON)
            d.line((x + 1, y + 1, x + 4, y + 1), fill=IRON_DARK)
            d.point((rail[0], y), fill=IRON_LIGHT)
        # The near end of the leaf, face on.
        d.line((x, 22, x + 5, 22), fill=LINE)
        for i in range(1, 5):
            d.line((x + i, 23, x + i, 27), fill=OAK_LIGHT if i in (1, 3) else OAK_SHADE)
        d.line((x + 1, 26, x + 4, 26), fill=OAK_DARK)
        d.line((x + 1, 27, x + 4, 27), fill=OAK_DARK)
        d.line((x + 1, 24, x + 4, 24), fill=IRON)
        # Wash along the inner side and at the foot.
        inner = x + 6 if left else x - 1
        points(d, WET, (inner, 12), (inner, 13), (inner, 24), (x + 2, 29), (x + 3, 29))
        points(d, WET_THIN, (inner, 11), (inner, 23), (inner, 25), (x + 1, 29), (x + 4, 29))
    sluice_wheel(d, 28, 3)
    return im


# --- chalk marks ------------------------------------------------------------

def chalk(im, x, y, strength=1.0, grey=False):
    """One chalk grain: its weight varies with the place, as a dragged stick does."""
    if not (0 <= x < 32 and 0 <= y < 32):
        return
    alpha = (232, 190, 214, 150, 224, 176, 204)[(x * 7 + y * 13 + x * y) % 7]
    alpha = int(alpha * strength)
    r, g, b = CHALK_GREY if grey or alpha < 170 * strength else CHALK
    old = im.getpixel((x, y))
    if old[3] < alpha:
        im.putpixel((x, y), (r, g, b, alpha))


def chalk_line(im, x0, y0, x1, y1, strength=1.0, dash=0):
    steps = max(abs(x1 - x0), abs(y1 - y0))
    for i in range(steps + 1):
        if dash and (i % dash) >= dash - 2:
            continue
        x = x0 + round((x1 - x0) * i / steps) if steps else x0
        y = y0 + round((y1 - y0) * i / steps) if steps else y0
        chalk(im, x, y, strength)


def chalk_frame(im, strength=1.0, dash=0):
    """The outline of the tile, with the corners gone over twice."""
    chalk_line(im, 2, 1, 29, 1, strength, dash)
    chalk_line(im, 2, 30, 29, 30, strength, dash)
    chalk_line(im, 1, 2, 1, 29, strength, dash)
    chalk_line(im, 30, 2, 30, 29, strength, dash)
    for cx, sx in ((2, 1), (29, -1)):
        for cy, sy in ((2, 1), (29, -1)):
            chalk_line(im, cx, cy, cx + 3 * sx, cy, strength)
            chalk_line(im, cx, cy, cx, cy + 3 * sy, strength)


def chalk_arc(im, radius, start, end, strength=1.0, head=4, width=2, centre=(15.5, 15.5)):
    """An arc from `start` to `end` degrees (clockwise on screen) with an arrowhead at its end."""
    cx, cy = centre
    count = int(abs(end - start) * 2)
    for step in range(count + 1):
        a = radians(start + (end - start) * step / count)
        for w in range(width):
            chalk(im, round(cx + (radius + w) * cos(a)), round(cy + (radius + w) * sin(a)), strength)
    a = radians(end)
    middle = radius + (width - 1) / 2
    tip = (cx + middle * cos(a), cy + middle * sin(a))
    # Barbs run back along the arc, splayed to either side.
    back = atan2(-cos(a), sin(a)) if end > start else atan2(cos(a), -sin(a))
    for splay in (-1.0, 0.7):
        for reach in range(1, head + 1):
            chalk(im, round(tip[0] + reach * cos(back + splay)),
                  round(tip[1] + reach * sin(back + splay)), strength)


def refit_add():
    im = blank()
    chalk_frame(im, dash=5)
    for o in (0, 1):
        chalk_line(im, 15 + o, 10, 15 + o, 21)
        chalk_line(im, 10, 15 + o, 21, 15 + o)
    return im


def refit_remove():
    im = blank()
    chalk_frame(im, 0.8)
    for o in (0, 1):
        chalk_line(im, 6 + o, 6, 24 + o, 24)
        chalk_line(im, 24 + o, 6, 6 + o, 24)
    # Scribbled hatching in the quarters.
    for x0, y0, x1, y1 in ((13, 4, 18, 9), (4, 13, 9, 18), (22, 13, 27, 18), (13, 22, 18, 27)):
        chalk_line(im, x0, y1, x1, y0, 0.7)
    return im


def refit_change():
    im = blank()
    chalk_frame(im, 0.8, dash=5)
    chalk_arc(im, 8, 195, 320, head=3, width=1)
    chalk_arc(im, 8, 15, 140, head=3, width=1)
    return im


def refit_turn():
    im = blank()
    # Corner ticks only, and a single sweeping arrow: this mark stays faint.
    for cx, sx in ((2, 1), (29, -1)):
        for cy, sy in ((2, 1), (29, -1)):
            chalk_line(im, cx, cy, cx + 3 * sx, cy, 0.6)
            chalk_line(im, cx, cy, cx, cy + 3 * sy, 0.6)
    chalk_arc(im, 8, 110, 370, 0.75, head=4, width=1)
    return im


# --- the yard ---------------------------------------------------------------

def yard_office():
    im = blank()
    d = ImageDraw.Draw(im)
    # Plank wall.
    d.rectangle((8, 13, 30, 30), fill=WOOD, outline=LINE)
    for x in range(9, 30):
        column = (x - 9) % 4
        d.line((x, 14, x, 29), fill=WOOD_SHADE if column == 3 else WOOD_MID if column == 0 else WOOD)
    d.line((9, 14, 29, 14), fill=WOOD_DARK)
    d.line((9, 15, 29, 15), fill=WOOD_SHADE)
    d.line((9, 29, 29, 29), fill=WOOD_DARK)
    # Shingle roof, weathered grey, overhanging the wall.
    d.rectangle((6, 1, 31, 13), fill=OAK, outline=LINE)
    for row, y in enumerate((2, 5, 8, 11)):
        bottom = min(y + 2, 12)
        d.rectangle((7, y, 30, bottom), fill=OAK_LIGHT if row % 2 else OAK_PALE)
        d.line((7, y, 30, y), fill=WEATHERED if row < 3 else OAK_PALE)
        if bottom < 12:
            d.line((7, bottom, 30, bottom), fill=OAK_SHADE)
        for x in range(9 + (row % 2) * 3, 30, 6):
            d.line((x, y, x, bottom), fill=OAK_SHADE)
    d.line((7, 12, 30, 12), fill=OAK_DARK)
    # Door.
    d.rectangle((11, 17, 17, 30), fill=WOOD_SHADE, outline=LINE)
    d.line((13, 18, 13, 29), fill=WOOD_DARK)
    d.line((15, 18, 15, 29), fill=WOOD_DARK)
    d.line((12, 18, 12, 29), fill=WOOD)
    d.line((12, 20, 16, 20), fill=WOOD_DARK)
    d.line((12, 27, 16, 27), fill=WOOD_DARK)
    d.point((16, 24), fill=BRASS)
    # Window with a pale frame.
    d.rectangle((20, 16, 27, 22), fill=WOOD_PALE, outline=LINE)
    d.rectangle((21, 17, 26, 21), fill=GLASS_DARK)
    d.rectangle((21, 17, 23, 18), fill=GLASS)
    d.point((25, 20), fill=GLASS)
    d.line((24, 17, 24, 21), fill=WOOD_PALE)
    d.line((21, 19, 26, 19), fill=WOOD_PALE)
    d.line((20, 23, 27, 23), fill=WOOD_CUT)
    # A rack of rolled draughts by the door.
    for x, top in ((20, 25), (23, 24), (26, 25)):
        d.rectangle((x - 1, top - 1, x + 2, 28), fill=LINE)
        d.rectangle((x, top, x + 1, 28), fill=PAPER)
        d.line((x + 1, top + 1, x + 1, 28), fill=PAPER_SHADE)
    points(d, RIBBON, (23, 26), (24, 26))
    d.rectangle((19, 27, 28, 30), fill=WOOD_DARK, outline=LINE)
    d.line((20, 28, 27, 28), fill=WOOD_MID)
    d.line((20, 29, 27, 29), fill=WOOD_SHADE)
    # Timber stacked at the side, cut ends toward us.
    for row, (y, first, count) in enumerate(((27, 0, 3), (23, 0, 3), (19, 2, 2))):
        for i in range(count):
            x = first + i * 3
            d.rectangle((x, y, x + 3, y + 4), fill=WOOD_LIGHT, outline=LINE)
            d.rectangle((x + 1, y + 1, x + 2, y + 3), fill=WOOD_PALE)
            d.point((x + 1, y + 1), fill=WOOD_CUT)
            d.point((x + 2, y + 3), fill=WOOD_MID)
    d.line((0, 31, 9, 31), fill=SHADOW)
    return im


def keel_blocks():
    im = blank()
    d = ImageDraw.Draw(im)
    for x in (1, 11, 21):
        d.line((x + 1, 29, x + 9, 29), fill=SHADOW)
        # Bottom baulk, lying along the dock: side grain.
        d.rectangle((x, 22, x + 9, 28), fill=WOOD, outline=LINE)
        d.line((x + 1, 23, x + 8, 23), fill=WOOD_LIGHT)
        d.line((x + 1, 25, x + 8, 25), fill=WOOD_SHADE)
        d.line((x + 1, 27, x + 8, 27), fill=WOOD_DARK)
        points(d, WOOD_MID, (x + 3, 24), (x + 4, 24), (x + 6, 26))
        # Middle baulk, laid across: cut end toward us.
        d.rectangle((x + 1, 16, x + 8, 22), fill=WOOD_LIGHT, outline=LINE)
        d.rectangle((x + 3, 18, x + 6, 20), outline=WOOD_MID)
        d.point((x + 4, 19), fill=WOOD_CUT)
        d.point((x + 5, 19), fill=WOOD_MID)
        d.line((x + 2, 17, x + 7, 17), fill=WOOD_PALE)
        d.line((x + 2, 21, x + 7, 21), fill=WOOD)
        # Capping block the keel bears on, its worn top in view.
        d.rectangle((x + 2, 10, x + 7, 16), fill=WOOD_SHADE, outline=LINE)
        d.rectangle((x + 3, 11, x + 6, 12), fill=WOOD_PALE)
        d.line((x + 3, 11, x + 6, 11), fill=WOOD_CUT)
        d.line((x + 3, 13, x + 6, 13), fill=WOOD_DARK)
        d.line((x + 3, 14, x + 6, 14), fill=WOOD)
        d.point((x + 3, 15), fill=WOOD_MID)
        # An iron dog holding the stack together.
        d.line((x + 8, 19, x + 8, 24), fill=IRON)
        d.point((x + 8, 19), fill=IRON_LIGHT)
    return im


BERTH_STATES = ('dock_gate_shut', 'dock_gate_open', 'refit_add', 'refit_remove', 'refit_change',
                'refit_turn', 'yard_office', 'keel_blocks')
BERTH_COLUMNS = 4


def description(size, states):
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = %d\n\theight = %d\n' % (size, size)
    for name in states:
        text += 'state = "%s"\n\tdirs = 1\n\tframes = 1\n' % name
    return text + '# END DMI\n'


def sheet_of(frames, size, columns):
    sheet = Image.new('RGBA', (size * columns, size * -(-len(frames) // columns)), CLEAR)
    for i, frame in enumerate(frames):
        sheet.paste(frame, ((i % columns) * size, (i // columns) * size))
    return sheet


def sheets():
    berths = [dock_gate_shut(), dock_gate_open(), refit_add(), refit_remove(), refit_change(),
              refit_turn(), yard_office(), keel_blocks()]
    return ((BERTHS, sheet_of(berths, 32, BERTH_COLUMNS), description(32, BERTH_STATES)),)


# --- preview ----------------------------------------------------------------

def dmi_states(path):
    """Every state of a DMI on disk as {name: first frame}."""
    im = Image.open(path)
    size = None
    order = []
    for line in im.info['Description'].splitlines():
        line = line.strip()
        if line.startswith('width = '):
            size = int(line[8:])
        elif line.startswith('state = '):
            order.append([line[9:-1], 1, 1])
        elif line.startswith('dirs = '):
            order[-1][1] = int(line[7:])
        elif line.startswith('frames = '):
            order[-1][2] = int(line[9:])
    rgba = im.convert('RGBA')
    cols = im.width // size
    out, index = {}, 0
    for name, dirs, frames in order:
        x, y = (index % cols) * size, (index // cols) * size
        out[name] = rgba.crop((x, y, x + size, y + size))
        index += dirs * frames
    return out


# How the game colours each chalk mark: (red, green, blue, alpha) multipliers.
TINTS = {'refit_add': (0.45, 1.0, 0.45, 1.0), 'refit_remove': (1.0, 0.35, 0.3, 1.0),
         'refit_change': (1.0, 0.75, 0.2, 1.0), 'refit_turn': (1.0, 0.75, 0.2, 0.6)}


def tinted(frame, tint):
    bands = [band.point(lambda v, m=m: int(v * m)) for band, m in zip(frame.split(), tint)]
    return Image.merge('RGBA', bands)


def preview(path):
    """Every state at 8x: gates over flooded trench, chalk tinted over a deck, the rest on grass."""
    scale = 8
    berths = dmi_states(BERTHS)
    grass = dmi_states(ROOT / 'icons/turf/floors.dmi')['grass0']
    wood = dmi_states(ROOT / 'icons/turf/flooring/wood.dmi')['wood']
    water = dmi_states(ROOT / 'icons/turf/trench.dmi')['trench_flooded']
    cols, box_w, box_h = 4, 60, 72
    rows = -(-len(BERTH_STATES) // cols)
    scene = Image.new('RGBA', (cols * box_w, rows * box_h), (24, 24, 28, 255))
    labels = []
    for i, name in enumerate(BERTH_STATES):
        ox, oy = (i % cols) * box_w + 6, (i // cols) * box_h + 4
        frame = berths[name]
        ground = Image.new('RGBA', (48, 56), CLEAR)
        if name.startswith('dock_gate'):
            floor = (grass, water, grass)
        elif name in TINTS:
            floor = (wood, wood, wood)
            frame = tinted(frame, TINTS[name])
        else:
            floor = (grass, grass, grass)
        for ty in range(3):
            ground.alpha_composite(floor[0], (-24, ty * 32 - 20))
            ground.alpha_composite(floor[1], (8, ty * 32 - 20))
            ground.alpha_composite(floor[2], (40, ty * 32 - 20))
        ground.alpha_composite(frame, (8, 12))
        scene.alpha_composite(ground, (ox, oy))
        labels.append((ox, oy + 58, name))
    big = scene.resize((scene.width * scale, scene.height * scale), Image.NEAREST)
    d = ImageDraw.Draw(big)
    for x, y, text in labels:
        d.text((x * scale, y * scale + 6), text, fill=(240, 240, 240, 255))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    big.convert('RGB').save(path)


def main():
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
        return
    stale = []
    for target, sheet, text in sheets():
        if '--check' in sys.argv:
            same = False
            if target.exists():
                current = Image.open(target)
                same = (current.info.get('Description') == text
                        and current.convert('RGBA').tobytes() == sheet.tobytes())
            if not same:
                stale.append(str(target.relative_to(ROOT)))
            continue
        info = PngInfo()
        info.add_text('Description', text, zip=True)
        sheet.save(target, format='PNG', pnginfo=info, optimize=True)
    if stale:
        raise SystemExit(', '.join(stale) + ' stale; rerun tests/naval_carrier/berth_sprites.py')


if __name__ == '__main__':
    main()
