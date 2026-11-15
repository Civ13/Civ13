"""Four-direction hand carts for icons/obj/carts.dmi (wood, stone, copper,
bronze and steel, closed and open). The direction is the side the pulling
handles point to, in BYOND order SOUTH, NORTH, EAST, WEST.

WEST is the existing one-direction sprite, bit for bit, and EAST is that sprite
mirrored. SOUTH and NORTH are end views built by this script (Pillow only):
the box end is assembled from pixel columns of the existing side view of the
same state, so palette, outline and shading match each material, and the
edge-on wheels and the handle shafts are placed pixel by pixel in colours
sampled from that same sprite. No external or generated artwork is used.

    python3 create_hand_carts.py [original carts.dmi] <output carts.dmi>
                                 [--preview <png>]

The original defaults to carts_one_direction.dmi beside this script, the
one-direction sheet frozen before these directions were added. Released under
Civ13 AGPL-3.0.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

STATES = ('w_cart_c', 'w_cart_o', 's_cart_c', 's_cart_o', 'c_cart_c', 'c_cart_o',
          'b_cart_c', 'b_cart_o', 'st_cart_c', 'st_cart_o')
DIRS = ('SOUTH', 'NORTH', 'EAST', 'WEST')

# Side-view geometry shared by every state: the box spans x 7-31 and ends on
# row 29, the two wheels sit under it on rows 30-31, the shafts leave to the left.
END_COLUMNS = list(range(7, 16)) + list(range(24, 32))   # left panel, post, right panel
END_X = 8                                                # end view spans x 8-24
BOX_BOTTOM = 29
SOUTH_LIFT = 4                                           # room for the shafts below the box
SHAFTS = (9, 22)                                         # left column of each 2px shaft


def read_states(path):
    """{state: 32x32 RGBA frame} from a sheet whose states are 1 dir, 1 frame."""
    sheet = Image.open(path)
    names, counts = [], []
    for line in sheet.info.get('Description', '').split('\n'):
        line = line.strip()
        if line.startswith('state = '):
            names.append(line[9:-1])
            counts.append(1)
        elif line.startswith('dirs = ') or line.startswith('frames = '):
            counts[-1] *= int(line.split('=')[1])
    if any(n != 1 for n in counts):
        raise SystemExit('%s is not the one-direction cart sheet' % path)
    sheet = sheet.convert('RGBA')
    cols = sheet.width // 32
    return {name: sheet.crop(((i % cols) * 32, (i // cols) * 32, (i % cols) * 32 + 32, (i // cols) * 32 + 32))
            for i, name in enumerate(names)}


def end_view(side, toward):
    """End view of the cart in `side`; toward=True is the handle end (SOUTH)."""
    src = side.load()
    out = Image.new('RGBA', (32, 32))
    px = out.load()
    lift = SOUTH_LIFT if toward else 0
    bottom = BOX_BOTTOM - lift
    shaft, rim, tyre = src[0, 14], src[10, 30], src[11, 30]

    def put(x, y, c):
        if 0 <= x < 32 and 0 <= y < 32:
            px[x, y] = c

    # shafts going away behind the box: only the grips show above it
    if not toward:
        top = min(y for y in range(32) if src[10, y][3]) - 2
        for x0 in SHAFTS:
            for y in range(top, top + 3):
                put(x0, y, shaft)
                put(x0 + 1, y, shaft)

    # box end: lid, body and lid knobs, from the side view's own columns
    for i, sx in enumerate(END_COLUMNS):
        for y in range(BOX_BOTTOM + 1):
            c = src[sx, y]
            if c == shaft:                      # the side view's shaft overlaps the box edge:
                c = src[38 - sx, y]             # use the same row of the other end instead
            if c[3]:
                put(END_X + i, y - lift, c)

    # wheels seen edge-on, tucked against each side of the box
    for outer, inner in ((6, 7), (26, 25)):
        for y in range(bottom - 2, bottom + 3):
            ends = y in (bottom - 2, bottom + 2)
            if not ends:
                put(outer, y, rim)
            put(inner, y, rim if ends else tyre)

    # shafts coming toward the viewer, fixed two rows up the end of the box
    if toward:
        for x0 in SHAFTS:
            for y in range(bottom - 2, 32):
                put(x0, y, shaft)
                put(x0 + 1, y, shaft)
        for y in (30, 31):
            put(SHAFTS[0] - 1, y, shaft)
            put(SHAFTS[1] + 2, y, shaft)
    return out


def build(original):
    """{state: [SOUTH, NORTH, EAST, WEST]}."""
    sides = read_states(original)
    return {name: [end_view(sides[name], True), end_view(sides[name], False),
                   sides[name].transpose(Image.FLIP_LEFT_RIGHT), sides[name].copy()]
            for name in STATES}


def write_dmi(path, states):
    frames = [fr for name in states for fr in states[name]]
    sheet = Image.new('RGBA', (4 * 32, len(states) * 32))
    for i, fr in enumerate(frames):
        sheet.paste(fr, ((i % 4) * 32, (i // 4) * 32))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name in states:
        text += 'state = "%s"\n\tdirs = 4\n\tframes = 1\n' % name
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta)


def write_preview(path, states, scale=4):
    """Review sheet: one row per state, four directions at 4x, then a 1x strip."""
    cell, left, top = 32 * scale + 8, 78, 16
    sheet = Image.new('RGBA', (left + cell * 4 + 4 * 34 + 8, top + cell * len(states)), (124, 132, 120, 255))
    draw = ImageDraw.Draw(sheet)
    for d, label in enumerate(DIRS):
        draw.text((left + d * cell + 4, 3), label, fill=(20, 20, 20, 255))
    draw.text((left + 4 * cell + 4, 3), 'game scale', fill=(20, 20, 20, 255))
    for row, name in enumerate(states):
        y = top + row * cell
        draw.text((4, y + cell // 2 - 6), name, fill=(20, 20, 20, 255))
        for d, fr in enumerate(states[name]):
            sheet.alpha_composite(fr.resize((32 * scale, 32 * scale), Image.NEAREST), (left + d * cell + 4, y + 4))
            sheet.alpha_composite(fr, (left + 4 * cell + 4 + d * 34, y + cell // 2 - 16))
    sheet.convert('RGB').save(path)


def main():
    args = sys.argv[1:]
    preview = None
    if '--preview' in args:
        i = args.index('--preview')
        preview = args[i + 1]
        del args[i:i + 2]
    if not args or len(args) > 2:
        raise SystemExit(__doc__)
    original = args[0] if len(args) == 2 else Path(__file__).resolve().parent / 'carts_one_direction.dmi'
    states = build(original)
    write_dmi(args[-1], states)
    if preview:
        write_preview(preview, states)


if __name__ == '__main__':
    main()
