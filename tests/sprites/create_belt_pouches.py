"""Original hand-placed 32px art for two small belt pouches.

Every pixel comes from the fixed palettes and the character stamps in this
file; there is no external, traced or generated artwork. Released under
Civ13's AGPL-3.0 licence. Run with Pillow from the repository root:

    python3 tests/sprites/create_belt_pouches.py [--preview sheet.png] [--belt-preview sheet.png]

It writes two files with matching state names:

- icons/obj/belt_pouches.dmi: leather_pouch, cloth_pouch, pouch_belt, baldric -
  inventory icons, one direction, one frame.
- icons/mob/belt_pouches.dmi: leather_pouch, cloth_pouch, pouch_belt, baldric,
  leather_pouch_left, cloth_pouch_left - worn overlays, four directions
  (SOUTH, NORTH, EAST, WEST), one frame. A pouch hangs from the belt line
  (y 18-20 from the top, as in icons/mob/belt.dmi) on the wearer's right hip;
  seen from the west only its front edge shows past the body. The _left
  states are the same pouches mirrored to the left hip. pouch_belt is a waist
  belt on that line with the buckle in front; baldric is a strap from the
  left shoulder to the right hip.

To change the look, edit this script and rerun it; do not hand-edit the DMIs.
"""
import re
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
OBJ = ROOT / 'icons/obj/belt_pouches.dmi'
MOB = ROOT / 'icons/mob/belt_pouches.dmi'
S = 32

PAL = {
    # leather, light to dark, and its outline
    '0': '#c08a58', '1': '#a06c3c', '2': '#80522a', '3': '#603a1c', '4': '#432712', 'o': '#2a180b',
    # waxed thread stitches and a bone toggle
    's': '#d2b684', 't': '#ece2c8', 'T': '#b3a384',
    # undyed linen, light to dark, and its outline
    'a': '#f0e7cb', 'b': '#ddd1ab', 'c': '#c4b58a', 'd': '#a3946a', 'e': '#7c704e', 'k': '#554b33',
    # hemp cord
    'h': '#a8834a', 'H': '#6f5127',
    # iron buckle
    'm': '#b9bdc1', 'M': '#73787d', 'n': '#45484c',
    # bronze buckle
    'z': '#dcae56', 'Z': '#94692a', 'y': '#5a3e14',
}

# name: (left, top, rows). '.' is transparent.
ITEMS = {
    'leather_pouch': (8, 6, (
        '......oooo......',
        '.....o0112o.....',
        '.....o1s2so.....',
        '.....o1223o.....',
        '...ooo1s2sooo...',
        '..o0001111112o..',
        '.o001111111122o.',
        '.o011111111222o.',
        '.o011111112222o.',
        '.o111111122223o.',
        '.os1111122222so.',
        '.o3s11122222s3o.',
        '.o23ss1tT2ss32o.',
        '.o1244stTs4423o.',
        '.o122244442233o.',
        '.o122222222333o.',
        '.o222222223333o.',
        '.o322222233334o.',
        '..o3333333344o..',
        '...oooooooooo...',
    )),
    'cloth_pouch': (8, 7, (
        '....k.kk.kk.....',
        '...kakabkbckk...',
        '...kabbbcccdk...',
        '....kbbccddk....',
        '....hhHhhHhH....',
        '....kbccdek.H...',
        '...kabbcddekhH..',
        '..kaabbccddekh..',
        '.kaabbbcdcddekH.',
        '.kabbbcbccdddkh.',
        '.kabbbbcccddekH.',
        '.kabbbccdcddek..',
        '.kbbbcbccdddek..',
        '.kbbcccddcdeek..',
        '..kcccdddddek...',
        '...kdddddeek....',
        '....kkkkkkk.....',
    )),
    # Waist belt fastened into a loop, buckle and spare holes at the front.
    'pouch_belt': (6, 11, (
        '.....oooooooooo.....',
        '...oo0011111111oo...',
        '..o00111222222211o..',
        '.o0112ooooooooo221o.',
        '.o012o.........o22o.',
        'o012o...........o22o',
        'o112o...........o23o',
        '.o122oooooooooo223o.',
        '.o1122nmmn22o2o233o.',
        '..o222nmoM22222333o.',
        '...oo3nMMn33334oo...',
        '.....oooooooooo.....',
    )),
    # Longer, narrower shoulder strap hung up as a loop, with a stitched tab.
    'baldric': (9, 5, (
        '....oooooo....',
        '..oo011112oo..',
        '.o0112oo2223o.',
        '.o01o....o23o.',
        'o01o......o23o',
        'o01o......o23o',
        'o01o......o23o',
        'o01o......o23o',
        'o11o......yzzy',
        'o12o......zo2Z',
        'o12o......yZZy',
        'o12o......o23o',
        'o12o......o23o',
        '.o12o....o23o.',
        '.o12o....o23o.',
        '..o12o..o23o..',
        '..o122oo233o..',
        '...o122233o...',
        '....o2233o....',
        '....o2s3so....',
        '....o2334o....',
        '.....oooo.....',
    )),
}

# Worn pouch as seen from the front; mirrored for the back view.
WORN = {
    'leather_pouch': (
        '.12..',
        '.12..',
        '31112',
        '31t23',
        '32223',
        '.344.',
    ),
    'cloth_pouch': (
        '..h..',
        '..H..',
        '.bHd.',
        'abcde',
        'bbcde',
        '.dek.',
    ),
}
# Left edge of the stamp per direction (SOUTH, NORTH, EAST); all start at the belt top.
WORN_TOP = 18
WORN_LEFT = (10, 16, 13)
# From the west the pouch is behind the body: the two front columns peek out.
WEST_LEFT = 11


def rgba(ch):
    c = PAL[ch]
    return (int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16), 255)


def stamp(rows, left, top, flip=False):
    img = Image.new('RGBA', (S, S))
    for y, row in enumerate(rows):
        row = row[::-1] if flip else row
        for x, ch in enumerate(row):
            if ch != '.':
                img.putpixel((left + x, top + y), rgba(ch))
    return img


def worn(name):
    rows = WORN[name]
    return [
        stamp(rows, WORN_LEFT[0], WORN_TOP),
        stamp(rows, WORN_LEFT[1], WORN_TOP, flip=True),
        stamp(rows, WORN_LEFT[2], WORN_TOP, flip=True),
        stamp(['..' if i < 2 else r[:2] for i, r in enumerate(rows)], WEST_LEFT, WORN_TOP),
    ]


def mirrored(img):
    return img.transpose(Image.FLIP_LEFT_RIGHT)


def worn_left(name):
    """The same pouch on the wearer's left hip (the torso is centred on x 15)."""
    south, north, east, west = worn(name)
    return [north, south, mirrored(west), mirrored(east)]


def plot(pixels):
    img = Image.new('RGBA', (S, S))
    for x, y, ch in pixels:
        img.putpixel((x, y), rgba(ch))
    return img


def worn_belt():
    """Two-pixel belt across the torso (x 11-19) at y 18-19; the arms hide the sides."""
    band = [(x, 18, '1') for x in range(11, 20)] + [(x, 19, '3') for x in range(11, 20)]
    ends = [(11, 18, '2'), (19, 18, '2'), (11, 19, '4'), (19, 19, '4')]
    buckle = [(15, 18, 'm'), (15, 19, 'M')]
    # Facing east the arm covers x 13-15; the buckle sits on the front edge.
    east = [(12, 18, '2'), (12, 19, '4')]
    east += [(x, 18, '1') for x in range(16, 20)] + [(x, 19, '3') for x in range(16, 20)]
    east += [(20, 18, 'm'), (20, 19, 'M')]
    return [plot(band + ends + buckle), plot(band + ends), plot(east), mirrored(plot(east))]


def worn_baldric():
    """Strap from the left shoulder to the right hip, light upper edge over a dark lower one."""
    # Front: wearer's left shoulder is viewer-right. One step down per pixel.
    front = []
    for y in range(10, 19):
        x = 29 - y
        front.append((x, y, '1'))
        if x + 1 <= 19:
            front.append((x + 1, y, '3'))
    # East shows the right hip: the strap rises from the hip to chest and back.
    east = [(15, 18, '1'), (15, 19, '3')]
    for i in range(1, 5):
        east += [(15 + i, 18 - i, '1'), (15 + i, 19 - i, '3'), (15 - i, 18 - i, '1'), (15 - i, 19 - i, '3')]
    # West shows the left shoulder: the strap falls from it to chest and back.
    west = [(15, 10, '1'), (16, 10, '1'), (15, 11, '3'), (16, 11, '3')]
    for i in range(1, 4):
        west += [(15 - i, 10 + i, '1'), (15 - i, 11 + i, '3')]
    for i in range(1, 5):
        west += [(16 + i, 10 + i, '1'), (16 + i, 11 + i, '3')]
    south = plot(front)
    north = Image.new('RGBA', (S, S))
    north.paste(mirrored(south).crop((1, 0, S, S)), (0, 0))  # mirror about x 15
    return [south, north, plot(east), plot(west)]


def write_dmi(path, states, dirs):
    frames = [f for name in states for f in (states[name] if dirs > 1 else [states[name]])]
    cols = 4 if dirs > 1 else len(frames)
    sheet = Image.new('RGBA', (cols * S, (len(frames) + cols - 1) // cols * S))
    for i, f in enumerate(frames):
        sheet.paste(f, ((i % cols) * S, (i // cols) * S))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = %d\n\theight = %d\n' % (S, S)
    for name in states:
        text += 'state = "%s"\n\tdirs = %d\n\tframes = 1\n' % (name, dirs)
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta, optimize=True)


def dmi_frames(path):
    """{state: first-frame index} and the RGBA sheet of an existing DMI."""
    sheet = Image.open(path)
    index, starts = 0, {}
    for name, dirs, frames in re.findall(r'state = "(.*?)"\n\tdirs = (\d+)\n\tframes = (\d+)',
                                         sheet.info.get('Description', '')):
        starts.setdefault(name, index)
        index += int(dirs) * int(frames)
    return starts, sheet.convert('RGBA')


def tile(sheet, i):
    cols = sheet.width // S
    return sheet.crop(((i % cols) * S, (i // cols) * S, (i % cols) * S + S, (i // cols) * S + S))


def figure(direction, uniform):
    """Male base body, optionally in a plain tunic, for the review sheet only."""
    starts, sheet = dmi_frames(ROOT / 'icons/mob/human_races/r_human.dmi')
    body = Image.new('RGBA', (S, S))
    for part in ('torso', 'groin', 'head', 'r_arm', 'l_arm', 'r_hand', 'l_hand',
                 'r_leg', 'l_leg', 'r_foot', 'l_foot'):
        body.alpha_composite(tile(sheet, starts[part + '_m'] + direction))
    if uniform:
        starts, sheet = dmi_frames(ROOT / 'icons/mob/uniform.dmi')
        body.alpha_composite(tile(sheet, starts[uniform] + direction))
    return body


def preview(items, mobs, out, scale=4):
    cell, label = S * scale, 14
    img = Image.new('RGBA', (cell * 5, (cell + label) * (1 + 2 * len(mobs))), (34, 34, 40, 255))
    d = ImageDraw.Draw(img)
    for i, (name, im) in enumerate(items.items()):
        img.alpha_composite(im.resize((cell, cell), Image.NEAREST), (i * cell, label))
        img.alpha_composite(im, (2 * cell + i * 40 + 8, label + cell // 2 - 16))
        d.text((i * cell + 4, 1), name + ' (inventory)', fill=(235, 235, 235, 255))
    d.text((2 * cell + 8, 1), '1x', fill=(235, 235, 235, 255))
    y = cell + label
    for name, frames in mobs.items():
        for uniform in ('white_tunic', None):
            d.text((4, y + 1), '%s worn, %s: south, north, east, west, then 1x' % (
                name, 'plain tunic' if uniform else 'bare body'), fill=(235, 235, 235, 255))
            for direction in range(4):
                fig = figure(direction, uniform)
                fig.alpha_composite(frames[direction])
                img.alpha_composite(fig.resize((cell, cell), Image.NEAREST), (direction * cell, y + label))
                img.alpha_composite(fig, (4 * cell + (direction % 2) * 40 + 8, y + label + 8 + (direction // 2) * 40))
            y += cell + label
    img.save(out)


def preview_belt(items, mobs, out, scale=4):
    cell, label = S * scale, 14
    rows = (
        ('pouch_belt alone', None, ('pouch_belt',)),
        ('pouch_belt alone over a plain tunic', 'white_tunic', ('pouch_belt',)),
        ('pouch_belt, leather_pouch (right), cloth_pouch_left', None,
         ('pouch_belt', 'leather_pouch', 'cloth_pouch_left')),
        ('pouch_belt, leather_pouch (right), cloth_pouch_left over a plain tunic', 'white_tunic',
         ('pouch_belt', 'leather_pouch', 'cloth_pouch_left')),
        ('baldric and pouch_belt over a plain tunic', 'white_tunic', ('baldric', 'pouch_belt')),
        ('baldric, pouch_belt, cloth_pouch (right), leather_pouch_left', 'white_tunic',
         ('baldric', 'pouch_belt', 'cloth_pouch', 'leather_pouch_left')),
    )
    img = Image.new('RGBA', (cell * 5, (cell + label) * (1 + len(rows))), (34, 34, 40, 255))
    d = ImageDraw.Draw(img)
    for i, name in enumerate(('pouch_belt', 'baldric')):
        img.alpha_composite(items[name].resize((cell, cell), Image.NEAREST), (i * cell, label))
        img.alpha_composite(items[name], (2 * cell + i * 40 + 8, label + cell // 2 - 16))
        d.text((i * cell + 4, 1), name + ' (inventory)', fill=(235, 235, 235, 255))
    d.text((2 * cell + 8, 1), '1x', fill=(235, 235, 235, 255))
    y = cell + label
    for title, uniform, layers in rows:
        d.text((4, y + 1), title + ': south, north, east, west, then 1x', fill=(235, 235, 235, 255))
        for direction in range(4):
            fig = figure(direction, uniform)
            for name in layers:
                fig.alpha_composite(mobs[name][direction])
            img.alpha_composite(fig.resize((cell, cell), Image.NEAREST), (direction * cell, y + label))
            img.alpha_composite(fig, (4 * cell + (direction % 2) * 40 + 8, y + label + 8 + (direction // 2) * 40))
        y += cell + label
    img.save(out)


def main(argv):
    items = {name: stamp(rows, left, top) for name, (left, top, rows) in ITEMS.items()}
    mobs = {name: worn(name) for name in WORN}
    mobs['pouch_belt'] = worn_belt()
    mobs['baldric'] = worn_baldric()
    for name in WORN:
        mobs[name + '_left'] = worn_left(name)
    write_dmi(OBJ, items, 1)
    write_dmi(MOB, mobs, 4)
    print('wrote', OBJ.relative_to(ROOT), 'and', MOB.relative_to(ROOT))
    if '--preview' in argv:
        preview({n: items[n] for n in WORN}, {n: mobs[n] for n in WORN}, argv[argv.index('--preview') + 1])
    if '--belt-preview' in argv:
        preview_belt(items, mobs, argv[argv.index('--belt-preview') + 1])


if __name__ == '__main__':
    main(sys.argv[1:])
