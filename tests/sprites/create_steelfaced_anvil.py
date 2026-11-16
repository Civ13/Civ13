"""The steel-faced anvil: a wrought iron anvil with a steel plate welded on top.

Around 1000 AD an anvil was a wrought iron body with a hardened steel face
forge-welded across the working surface; the horn stayed plain iron. The three
states "steelfaced_anvil", "steelfaced_anvil_use" and "steelfaced_anvil_use2"
in icons/obj/metallurgy.dmi are the matching "iron_anvil*" frames from the
same sheet with that plate drawn over the top face: a bright polished edge, a
cool grey plate under it, and a dark weld seam where it meets the iron. The
hot metal and sparks of the iron "_use" frames are kept as they are. Every
pixel is placed by this script from the fixed palette below (Pillow only); no
external or generated artwork.

Run with Pillow to insert (or redraw) the three states right after
"iron_anvil_use2"; frame counts, delays and dirs are copied from the iron
states and every other state in the sheet is left untouched. `--check`
verifies the committed sheet, `--preview <png>` writes a 4x review sheet of
the stone, iron, steel-faced and steel anvils. Released under Civ13 AGPL-3.0.
"""
import struct
import sys
import zlib
from pathlib import Path
from PIL import Image, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons' / 'obj' / 'metallurgy.dmi'

SIZE = 32
# new state -> the iron state it is drawn over
STATES = {
    'steelfaced_anvil': 'iron_anvil',
    'steelfaced_anvil_use': 'iron_anvil_use',
    'steelfaced_anvil_use2': 'iron_anvil_use2',
}
AFTER = 'iron_anvil_use2'

# The working face of the iron anvil: the heel and table, right of the horn.
FACE_FIRST, FACE_LAST = 10, 28
EDGE_ROW, PLATE_ROW, SEAM_ROW = 17, 18, 19
SEAM_LAST = 27                      # the iron under the plate is one pixel shorter

# polished steel, cool grey
SHINE = (214, 224, 236)             # glints on the top edge
EDGE = (182, 194, 208)              # top edge
PLATE = (138, 150, 166)             # side of the plate
PLATE_DARK = (104, 115, 132)        # the plate's ends, turning away from the light
SEAM = (24, 24, 28)                 # forge weld line between steel and iron
GLINTS = (12, 13, 22, 25)           # columns of the edge that catch the light


def is_hot(pixel):
    """The glowing workpiece and sparks of the _use frames (never grey)."""
    r, g, b, a = pixel
    return a and r > 150 and r - b > 80


def face_frame(iron):
    out = iron.copy()
    px, src = out.load(), iron.load()
    for x in range(FACE_FIRST, FACE_LAST + 1):
        end = x in (FACE_FIRST, FACE_LAST)
        for y, colour in ((EDGE_ROW, EDGE), (PLATE_ROW, PLATE)):
            if not src[x, y][3] or is_hot(src[x, y]):
                continue
            if end:
                colour = PLATE if y == EDGE_ROW else PLATE_DARK
            elif y == EDGE_ROW and x in GLINTS:
                colour = SHINE
            elif y == PLATE_ROW and x % 6 == 3:
                colour = PLATE_DARK      # faint hammer wear along the plate
            px[x, y] = colour + (255,)
        if x <= SEAM_LAST and src[x, SEAM_ROW][3]:
            px[x, SEAM_ROW] = SEAM + (255,)
    return out


# -------------------------------------------------------------------- sheet

def read_dmi(path):
    """(columns, [(name, {key: text}, [image, ...] in sheet order)])."""
    text = None
    with open(path, 'rb') as fh:
        fh.read(8)
        while True:
            head = fh.read(8)
            if len(head) < 8:
                break
            length, kind = struct.unpack('>I4s', head)
            data = fh.read(length)
            fh.read(4)
            if kind == b'zTXt' and data.startswith(b'Description\0'):
                text = zlib.decompress(data[data.index(0) + 2:]).decode()
    sheet = Image.open(path).convert('RGBA')
    cols = sheet.width // SIZE
    states, at = [], 0
    for line in text.splitlines():
        line = line.strip()
        if line.startswith('state'):
            states.append((line.split('=', 1)[1].strip().strip('"'), {}, []))
        elif states and '=' in line:
            key, value = (part.strip() for part in line.split('=', 1))
            states[-1][1][key] = value
    for _, keys, images in states:
        for _ in range(int(keys['dirs']) * int(keys['frames'])):
            x, y = (at % cols) * SIZE, (at // cols) * SIZE
            images.append(sheet.crop((x, y, x + SIZE, y + SIZE)))
            at += 1
    return cols, states


def write_dmi(path, cols, states):
    images = [im for _, _, ims in states for im in ims]
    sheet = Image.new('RGBA', (cols * SIZE, ((len(images) + cols - 1) // cols) * SIZE))
    for i, im in enumerate(images):
        sheet.paste(im, ((i % cols) * SIZE, (i // cols) * SIZE))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = %d\n\theight = %d\n' % (SIZE, SIZE)
    for name, keys, _ in states:
        text += 'state = "%s"\n' % name
        for key, value in keys.items():
            text += '\t%s = %s\n' % (key, value)
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta, optimize=True)


def rebuild(states):
    """The sheet with the three steel-faced states placed after the iron ones."""
    by = {name: (keys, images) for name, keys, images in states}
    out = []
    for name, keys, images in states:
        if name in STATES:
            continue
        out.append((name, keys, images))
        if name == AFTER:
            for new, iron in STATES.items():
                iron_keys, iron_images = by[iron]
                out.append((new, dict(iron_keys), [face_frame(im) for im in iron_images]))
    return out


def same(a, b):
    return ([(n, k) for n, k, _ in a] == [(n, k) for n, k, _ in b]
            and all([i.tobytes() for i in x[2]] == [i.tobytes() for i in y[2]] for x, y in zip(a, b)))


def check(states):
    """The committed states are exactly what this script draws, in place."""
    problems = []
    names = [name for name, _, _ in states]
    for name in STATES:
        if name not in names:
            problems.append('%s is missing' % name)
    if not problems:
        at = names.index(AFTER)
        if names[at + 1:at + 1 + len(STATES)] != list(STATES):
            problems.append('the steel-faced states do not follow %s' % AFTER)
        by = {name: (keys, images) for name, keys, images in states}
        for name, keys, images in rebuild(states):
            if name not in STATES:
                continue
            if by[name][0] != keys:
                problems.append('%s does not match the frames, delays and dirs of %s' % (name, STATES[name]))
            elif [im.tobytes() for im in by[name][1]] != [im.tobytes() for im in images]:
                problems.append('%s differs from the drawn plate' % name)
    return problems


GROUNDS = [(128, 128, 128), (104, 78, 52)]     # neutral grey, dirt
KINDS = ['stone_anvil', 'iron_anvil', 'steelfaced_anvil', 'steel_anvil']


def write_preview(path, states, scale=4):
    """One row per anvil and ground: idle, each _use frame, _use2."""
    by = {name: images for name, _, images in states}
    rows = [[im for suffix in ('', '_use', '_use2') for im in by[kind + suffix]] for kind in KINDS]
    width = max(len(row) for row in rows)
    im = Image.new('RGBA', (SIZE * width, SIZE * len(rows) * len(GROUNDS)))
    for g, ground in enumerate(GROUNDS):
        top = g * len(rows) * SIZE
        im.paste(ground + (255,), (0, top, im.width, top + len(rows) * SIZE))
        for r, row in enumerate(rows):
            for f, frame in enumerate(row):
                im.alpha_composite(frame, (f * SIZE, top + r * SIZE))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    im.convert('RGB').resize((im.width * scale, im.height * scale), Image.NEAREST).save(path)


def option(name):
    args = sys.argv[1:]
    return args[args.index(name) + 1] if name in args[:-1] else None


def main():
    cols, states = read_dmi(option('--sheet') or SHEET)
    if '--check' in sys.argv:
        problems = check(states)
        for line in problems:
            print(line)
        print('steel-faced anvil: %s' % ('FAILED' if problems else 'ok'))
        return 1 if problems else 0
    built = rebuild(states)
    if option('--out') or not same(built, states):
        write_dmi(option('--out') or SHEET, cols, built)
    if option('--preview'):
        write_preview(option('--preview'), built)
    return 0


if __name__ == '__main__':
    sys.exit(main())
