"""Hand-placed 32px art for the wooden splitting wedge: a short block of
whittled hardwood, square and battered at the struck end and cut down to a
chisel edge at the other. Every pixel is placed by this script from a fixed
palette (Pillow only); no external or generated artwork. The wood tones are
those of the sharpened stick in icons/obj/old_weapons.dmi, which the wedge
borrowed before it had art of its own, lit from the upper left.

Run with Pillow to reproduce
  icons/obj/splitting_wedge.dmi                    item icon
  icons/mob/items/lefthand_splitting_wedge.dmi     held, four directions
  icons/mob/items/righthand_splitting_wedge.dmi
all with the single state `splitting_wedge`.

`--check` verifies the three committed sheets byte for byte, `--preview <png>`
writes a before and after review sheet. Released under Civ13 AGPL-3.0.
"""
import io
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_diving_gear import base_body  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
STATE = 'splitting_wedge'
SHEETS = {
    'item': ROOT / 'icons/obj/splitting_wedge.dmi',
    'left': ROOT / 'icons/mob/items/lefthand_splitting_wedge.dmi',
    'right': ROOT / 'icons/mob/items/righthand_splitting_wedge.dmi',
}

OUT = (48, 32, 20)
# split heartwood, light to dark
W = [(224, 186, 146), (198, 156, 118), (170, 126, 90), (144, 102, 71), (116, 82, 55), (86, 58, 36)]
# the bruised, fibrous rim of the struck end
BRUISE = (104, 76, 54)

# The wedge is seen from its side, so the taper shows: it leans from the
# struck end at the upper right to the edge at the lower left. U runs down its
# length, V across its thickness; DEPTH is its width, going away up and left.
U = (-0.651, 0.759)
V = (0.759, 0.651)
HEAD = (21.0, 11.4)
LENGTH = 19.0
HALF = 4.3                           # half the thickness of the struck end
DEPTH = (-0.4, -4.2)


class Frame:
    def __init__(self):
        self.px = {}

    def put(self, x, y, c):
        if 0 <= x < 32 and 0 <= y < 32:
            self.px[(x, y)] = c

    def pts(self, c, *points):
        for x, y in points:
            self.put(x, y, c)

    def outline(self, c=OUT):
        edge = set()
        for (x, y) in self.px:
            for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if n not in self.px:
                    edge.add(n)
        for x, y in edge:
            self.put(x, y, c)
        return self

    def flip(self):
        """Mirror about the body's centre column (x = 15), as the held sheets do."""
        f = Frame()
        f.px = {(30 - x, y): c for (x, y), c in self.px.items() if 0 <= 30 - x < 32}
        return f

    def image(self):
        im = Image.new('RGBA', (32, 32))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c + (255,))
        return im


def noise(x, y, seed=0):
    """A fixed 0..1 value per pixel, so the sheet is reproducible."""
    n = (x * 374761393 + y * 668265263 + seed * 2147483647) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def at(along, across, back=0.0):
    """A point on the wedge: `along` its length from the struck end, `across`
    its thickness from the centre line, `back` 0 on the near side to 1 on the far."""
    return (HEAD[0] + U[0] * along + V[0] * across + DEPTH[0] * back,
            HEAD[1] + U[1] * along + V[1] * across + DEPTH[1] * back)


def inside(poly, x, y):
    hit = False
    for i in range(len(poly)):
        (x0, y0), (x1, y1) = poly[i], poly[(i + 1) % len(poly)]
        if (y0 > y) != (y1 > y) and x < x0 + (y - y0) * (x1 - x0) / (y1 - y0):
            hit = not hit
    return hit


def fill(f, poly, colour):
    for y in range(32):
        for x in range(32):
            if inside(poly, x + 0.5, y + 0.5):
                c = colour(x, y) if callable(colour) else colour
                if c is not None:
                    f.put(x, y, c)


def local(x, y):
    """Pixel centre to (along, across) on the front face."""
    px, py = x + 0.5 - HEAD[0], y + 0.5 - HEAD[1]
    return px * U[0] + py * U[1], px * V[0] + py * V[1]


def wedge_item():
    f = Frame()
    # the upper driving face, in the light: a long strip running down to the edge
    face = [at(0, -HALF), at(0, -HALF, 1), at(LENGTH, 0, 1), at(LENGTH, 0)]

    def face_tone(x, y):
        along, _ = local(x, y)
        if along > LENGTH - 3.0:
            return W[0]                                   # the freshly cut edge
        if not inside(face, x + 0.5, y - 0.5) or not inside(face, x - 0.5, y + 0.5):
            return W[0] if inside(face, x + 1.5, y + 0.5) else W[1]   # far arris catching the light
        return W[2] if int(along) in (6, 12) else W[1]    # flats left by the knife
    fill(f, face, face_tone)

    # the near side: the triangle that makes it a wedge, its struck corner
    # knocked off by the mallet
    side = [at(0, -HALF), at(0, HALF - 1.4), at(1.6, HALF * (1.0 - 1.6 / LENGTH)), at(LENGTH, 0)]

    def side_tone(x, y):
        along, across = local(x, y)
        half = HALF * (1.0 - along / LENGTH)
        s = across / max(half, 0.01)
        if half < 0.9:
            return W[3]
        if s > 0.42:
            return W[5]                                   # the under face turns from the light
        if s < -0.5:
            return W[3]
        # long grain: two darker threads running down the length
        if int(across + 9.4) in (9, 11) and noise(int(across + 9.4), int(along / 4.0), 7) > 0.3:
            return W[5] if along < 9 else W[4]
        return W[4]
    fill(f, side, side_tone)

    # the struck end: pale end grain, bruised round the rim by the mallet
    end = [at(0, -HALF), at(0, HALF - 1.4), at(0, HALF - 1.4, 1), at(0, -HALF, 1)]

    def end_tone(x, y):
        _, across = local(x, y)
        if not inside(end, x + 1.5, y + 0.5) or not inside(end, x + 0.5, y + 1.5):
            return BRUISE if noise(x, y, 11) > 0.4 else W[2]
        return W[0] if across < 0.6 else W[1]
    fill(f, end, end_tone)
    return f.outline()


def wedge_in_hand(x):
    """Gripped round the middle, struck end up and the edge pointing down."""
    f = Frame()
    rows = {14: (x - 1, x + 2), 15: (x - 1, x + 2), 16: (x - 1, x + 2), 17: (x - 1, x + 2), 18: (x - 1, x + 2),
            19: (x - 1, x + 1), 20: (x - 1, x + 1), 21: (x - 1, x + 1), 22: (x, x + 1), 23: (x, x + 1), 24: (x, x)}
    for y, (x0, x1) in rows.items():
        for xx in range(x0, x1 + 1):
            f.put(xx, y, W[1] if xx == x0 else W[5] if xx == x1 and x1 > x0 else W[3])
    for xx in range(x - 1, x + 3):
        f.put(xx, 14, W[0])                               # end grain of the struck end
    f.put(x + 2, 14, W[2])
    f.put(x, 24, W[0])                                    # the edge
    return f


def four(make, s=21, n=9, e=16, w=13):
    """Left-hand frames S, N, E, W for a maker taking the hand's column."""
    return [make(s), make(n), make(e), make(w)]


def right_of(left):
    return [left[0].flip(), left[1].flip(), left[3].flip(), left[2].flip()]


HELD_L = four(wedge_in_hand)
HELD_R = right_of(HELD_L)
BUILD = {'item': [wedge_item()], 'left': HELD_L, 'right': HELD_R}


def dmi_bytes(frames):
    sheet = Image.new('RGBA', (len(frames) * 32, 32))
    for i, fr in enumerate(frames):
        sheet.paste(fr.image(), (i * 32, 0))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    text += 'state = "%s"\n\tdirs = %d\n\tframes = 1\n# END DMI\n' % (STATE, len(frames))
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    out = io.BytesIO()
    sheet.save(out, format='PNG', pnginfo=meta)
    return out.getvalue()


def check_drawing():
    """Rules the drawing must keep, whatever the palette becomes."""
    problems = []
    item = BUILD['item'][0]
    xs = [x for x, _ in item.px]
    ys = [y for _, y in item.px]
    if min(xs) < 1 or max(xs) > 30 or min(ys) < 1 or max(ys) > 30:
        problems.append('the item icon touches the tile border')
    for key in ('left', 'right'):
        for fr in BUILD[key]:
            if not fr.px:
                problems.append('an in-hand frame is empty')
    return problems


def old_state(path, name, index=0):
    """One frame of an existing sheet, for the before column."""
    sheet = Image.open(ROOT / path)
    order = []
    for line in sheet.info.get('Description', '').split('\n'):
        line = line.strip()
        if line.startswith('state = '):
            order.append([line[9:-1], 1, 1])
        elif line.startswith('dirs = '):
            order[-1][1] = int(line[7:])
        elif line.startswith('frames = '):
            order[-1][2] = int(line[9:])
    at_frame = 0
    for state, dirs, frames in order:
        if state == name:
            break
        at_frame += dirs * frames
    sheet = sheet.convert('RGBA')
    cols = sheet.width // 32
    i = at_frame + index
    return sheet.crop(((i % cols) * 32, (i // cols) * 32, (i % cols) * 32 + 32, (i // cols) * 32 + 32))


def write_preview(path, scale=8):
    """Top: the old borrowed icon and the new one at 8x on grass, dirt and an
    inventory-slot grey, then both at 2x and 1x. Bottom: held in each hand
    facing south, north, east and west, old above new."""
    grounds = [(86, 128, 62, 255), (134, 102, 70, 255), (64, 66, 72, 255)]
    cell = 32 * scale
    old = old_state('icons/obj/old_weapons.dmi', 'sharpened_stick')
    new = BUILD['item'][0].image()
    held = 32 * 4
    sheet = Image.new('RGBA', (cell * 3 + 8 + 2 * 66, cell * 2 + 8 + held * 2 + 4), (30, 32, 36, 255))
    for r, im in enumerate((old, new)):
        for c, ground in enumerate(grounds):
            tile = Image.new('RGBA', (32, 32), ground)
            tile.alpha_composite(im)
            sheet.alpha_composite(tile.resize((cell, cell), Image.NEAREST), (c * cell, r * (cell + 4)))
        for c, ground in enumerate(grounds[:2]):
            tile = Image.new('RGBA', (32, 32), ground)
            tile.alpha_composite(im)
            sheet.alpha_composite(tile.resize((64, 64), Image.NEAREST), (cell * 3 + 8 + c * 66, r * (cell + 4)))
            sheet.alpha_composite(tile, (cell * 3 + 8 + c * 66, r * (cell + 4) + 68))
    y0 = cell * 2 + 8
    for r in range(2):
        for hand, (new_frames, old_path) in enumerate(((HELD_L, 'icons/mob/items/lefthand_weapons.dmi'),
                                                        (HELD_R, 'icons/mob/items/righthand_weapons.dmi'))):
            for d in range(4):
                tile = Image.new('RGBA', (32, 32), grounds[0])
                tile.alpha_composite(base_body(d))
                tile.alpha_composite(old_state(old_path, 'sharpened_stick', d) if r == 0 else new_frames[d].image())
                sheet.alpha_composite(tile.resize((held, held), Image.NEAREST), ((hand * 4 + d) * held // 1, y0 + r * (held + 4)))
    sheet = sheet.crop((0, 0, max(sheet.width, held * 8), sheet.height)) if sheet.width >= held * 8 else _widen(sheet, held * 8)
    sheet.convert('RGB').save(path)


def _widen(sheet, width):
    wide = Image.new('RGBA', (width, sheet.height), (30, 32, 36, 255))
    wide.alpha_composite(sheet)
    return wide


def main():
    args = sys.argv[1:]
    problems = check_drawing()
    if '--check' in args:
        for key, frames in BUILD.items():
            path = SHEETS[key]
            if not path.exists():
                problems.append('missing sheet: %s' % path)
            elif path.read_bytes() != dmi_bytes(frames):
                problems.append('stale sheet: %s' % path)
        for line in problems:
            print(line)
        print('splitting wedge: %s' % ('FAILED' if problems else 'ok'))
        return 1 if problems else 0
    if problems:
        print('\n'.join(problems))
        return 1
    for key, frames in BUILD.items():
        SHEETS[key].write_bytes(dmi_bytes(frames))
    if '--preview' in args[:-1]:
        write_preview(args[args.index('--preview') + 1])
    return 0


if __name__ == '__main__':
    sys.exit(main())
