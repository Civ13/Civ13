"""Original hand-placed 32px art for the quarried marble stack states.

Every pixel comes from the fixed palette and the block layouts and vein
coordinates in this file; there is no external, traced or generated artwork.
Released under Civ13's AGPL-3.0 licence. Run with Pillow from the repository
root:

    python3 tests/sprites/create_marble.py [--preview sheet.png [--before old_materials.dmi]]

It replaces the pixels of three states in icons/obj/materials.dmi and leaves
every other state, the state order and the metadata text untouched (it prints
a per-state RGBA hash comparison to prove it):

- sheet-marble: one squared block.
- sheet-marble_2: three blocks, two on the ground and one across them.
- sheet-marble_3: five blocks stacked two, two and one.

To change the look, edit this script and rerun it; do not hand-edit the DMI.
"""
import hashlib
import re
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
DMI = ROOT / 'icons/obj/materials.dmi'
S = 32

PAL = {
    'W': '#ffffff',  # chiselled arris catching the light
    't': '#f7f5ee',  # top face
    'f': '#e2dfd6',  # front face
    's': '#c5c2b9',  # right face, away from the light
    'v': '#c9cbd1',  # faint vein
    'V': '#a4a7b0',  # stronger vein
    'e': '#9f9b92',  # soft lower and right edge
    'E': '#74716b',  # ground-contact and gap shadow
}

# Veins per block variant, as (face, x, y) offsets inside that face.
# front: x from the left edge, y from the top edge of the front face.
# top: x along the block, y = rows back from the front arris (0 nearest).
VEINS = {
    0: (('front', 2, 0, 'v'), ('front', 3, 1, 'V'), ('front', 3, 2, 'V'), ('front', 4, 3, 'v'),
        ('front', 5, 4, 'V'), ('front', 5, 5, 'v'), ('front', 9, 2, 'v'), ('front', 10, 3, 'v'),
        ('front', 8, 1, 'v'),
        ('top', 2, 0, 'v'), ('top', 3, 1, 'v'), ('top', 3, 2, 'V'), ('top', 8, 1, 'v'), ('top', 9, 2, 'v')),
    1: (('front', 8, 0, 'V'), ('front', 7, 1, 'V'), ('front', 7, 2, 'v'), ('front', 6, 3, 'V'),
        ('front', 5, 4, 'v'), ('front', 2, 2, 'v'), ('front', 1, 3, 'v'), ('front', 10, 4, 'v'),
        ('top', 8, 0, 'V'), ('top', 9, 1, 'v'), ('top', 10, 2, 'v'), ('top', 4, 1, 'v')),
    2: (('front', 1, 1, 'v'), ('front', 2, 2, 'V'), ('front', 3, 2, 'V'), ('front', 4, 3, 'v'),
        ('front', 5, 3, 'v'), ('front', 9, 1, 'v'), ('front', 9, 2, 'V'), ('front', 10, 3, 'v'),
        ('top', 5, 0, 'v'), ('top', 6, 1, 'V'), ('top', 6, 2, 'v'), ('top', 1, 2, 'v')),
}

# state: blocks back to front as (left, top of front face, width, height, depth, vein variant).
LAYOUTS = {
    'sheet-marble': ((8, 15, 13, 8, 5, 0),),
    'sheet-marble_2': ((2, 20, 12, 7, 4, 1), (15, 21, 12, 7, 4, 2), (8, 12, 13, 7, 4, 0)),
    'sheet-marble_3': ((1, 23, 12, 7, 4, 2), (14, 23, 13, 7, 4, 0),
                       (3, 15, 12, 7, 4, 0), (15, 15, 12, 7, 4, 1),
                       (9, 7, 12, 7, 4, 2)),
}


def rgba(ch):
    c = PAL[ch]
    return (int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16), 255)


def block(img, left, top, w, h, d, variant):
    """One squared block: front face, top face stepped back to the right, right face."""
    def put(x, y, ch):
        if 0 <= x < S and 0 <= y < S:
            img.putpixel((x, y), rgba(ch))

    for k in range(1, d + 1):  # top and right faces, one pixel back per step
        for x in range(w):
            put(left + k + x, top - k, 't')
        for y in range(h):
            put(left + w - 1 + k, top - k + y, 's')
        put(left + k, top - k, 'f')              # left edge of the top face
        put(left + w - 1 + k, top - k, 'W' if k < d else 't')  # top-right arris
        put(left + w - 1 + k, top - k + h - 1, 'e')            # foot of the right face
    for x in range(w):
        put(left + d + x, top - d, 'f')          # back edge of the top face
    for y in range(h):
        put(left + w - 1 + d, top - d + y, 'e')  # far vertical edge
    put(left + w - 1 + d, top - d + h - 1, 'E')
    for y in range(h):
        for x in range(w):
            put(left + x, top + y, 'f')
    for x in range(w):
        put(left + x, top, 'W')                  # front top arris
        put(left + x, top + h - 1, 'e')          # foot of the front face
    for y in range(1, h - 1):
        put(left + w - 1, top + y, 't')          # lit front-right corner
    put(left, top + h - 1, 'E')
    put(left + w - 1, top + h - 1, 'E')
    for face, x, y, ch in VEINS[variant]:
        if face == 'front' and 0 < x < w - 1 and 0 < y + 1 < h - 1:
            put(left + x, top + 1 + y, ch)
        elif face == 'top' and y + 1 < d and x < w - 1:
            put(left + 1 + y + 1 + x, top - 1 - y, ch)
    # a chipped near corner so the block is only roughly square
    if variant != 1:
        put(left, top, 'f')
    else:
        put(left + w - 1, top, 't')


def draw(name):
    img = Image.new('RGBA', (S, S))
    for spec in LAYOUTS[name]:
        block(img, *spec)
    return img


def states_of(sheet):
    """[(name, first frame index, frame count)] in file order."""
    out, index = [], 0
    for m in re.finditer(r'state = "([^"]*)"(.*?)(?=\nstate =|\n# END DMI)', sheet.info['Description'], re.S):
        n = int(re.search(r'dirs = (\d+)', m[2])[1]) * int(re.search(r'frames = (\d+)', m[2])[1])
        out.append((m[1], index, n))
        index += n
    return out


def box(sheet, i):
    cols = sheet.width // S
    return ((i % cols) * S, (i // cols) * S, (i % cols) * S + S, (i // cols) * S + S)


def hashes(sheet):
    rgba_sheet = sheet.convert('RGBA')
    return [(name, hashlib.sha256(b''.join(rgba_sheet.crop(box(sheet, i)).tobytes()
                                           for i in range(start, start + n))).hexdigest())
            for name, start, n in states_of(sheet)]


def rebuild():
    old = Image.open(DMI)
    text = old.info['Description']
    before = hashes(old)
    sheet = old.convert('RGBA')
    seen = set()
    for name, start, n in states_of(old):
        if name in LAYOUTS and name not in seen:
            if n != 1:
                raise SystemExit('%s is not a single still' % name)
            sheet.paste(draw(name), box(old, start)[:2])
            seen.add(name)
    if seen != set(LAYOUTS):
        raise SystemExit('missing states: %s' % sorted(set(LAYOUTS) - seen))
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(DMI, format='PNG', pnginfo=meta, optimize=True)

    new = Image.open(DMI)
    after = hashes(new)
    changed = [a[0] for a, b in zip(before, after) if a != b]
    same_meta = new.info['Description'] == text and new.size == old.size
    print('%d states; metadata and sheet size unchanged: %s' % (len(after), same_meta))
    print('states whose pixels changed:', changed or 'none (already current)')
    untouched = sum(1 for a, b in zip(before, after) if a == b and a[0] not in LAYOUTS)
    print('other states with identical RGBA hash before and after: %d of %d' % (
        untouched, sum(1 for a in before if a[0] not in LAYOUTS)))
    if not same_meta or [a[0] for a in before] != [a[0] for a in after] or set(changed) - set(LAYOUTS):
        raise SystemExit('FAILED: something other than the marble states changed')


def preview(out, before=None, scale=4):
    cell, label = S * scale, 14
    rows = []
    if before:
        old = Image.open(before)
        starts = {name: start for name, start, _ in reversed(states_of(old))}
        rows.append(('before', {n: old.convert('RGBA').crop(box(old, starts[n])) for n in LAYOUTS}))
    rows.append(('after', {n: draw(n) for n in LAYOUTS}))
    img = Image.new('RGBA', (cell * len(LAYOUTS) + 3 * 40, len(rows) * (cell + label)), (34, 34, 40, 255))
    d = ImageDraw.Draw(img)
    for r, (title, tiles) in enumerate(rows):
        y = r * (cell + label)
        for i, (name, tile) in enumerate(tiles.items()):
            d.text((i * cell + 4, y + 1), '%s: %s' % (title, name), fill=(235, 235, 235, 255))
            img.alpha_composite(tile.resize((cell, cell), Image.NEAREST), (i * cell, y + label))
            # 1x on a light and a dark floor tone
            d.rectangle((len(LAYOUTS) * cell + i * 40, y + label + 8, len(LAYOUTS) * cell + i * 40 + 35, y + label + 43),
                        fill=(96, 110, 70, 255))
            img.alpha_composite(tile, (len(LAYOUTS) * cell + i * 40 + 2, y + label + 10))
            img.alpha_composite(tile, (len(LAYOUTS) * cell + i * 40 + 2, y + label + 60))
    img.save(out)


def main(argv):
    rebuild()
    if '--preview' in argv:
        before = argv[argv.index('--before') + 1] if '--before' in argv else None
        preview(argv[argv.index('--preview') + 1], before)


if __name__ == '__main__':
    main(sys.argv[1:])
