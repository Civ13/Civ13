"""Original hand-placed 32px art for small tools carried on the body: boot and
sleeve knife sheaths, a fire-making pouch, a hand drill, a bone needle case,
a neck knife, a pendant hone, a strike-a-light pouch and a chatelaine.

Every pixel comes from the fixed palette, the character stamps and the
coordinate lists in this file; there is no external, traced or generated
artwork. The leather, linen-thread, cord and metal colours are the ones in
create_belt_pouches.py. Released under Civ13's AGPL-3.0 licence. Run with
Pillow from the repository root:

    python3 tests/sprites/create_worn_tools.py [--check] [--preview sheet.png]

It writes two files:

- icons/obj/worn_tools.dmi: boot_sheath, sleeve_sheath, fire_pouch,
  fire_drill, needle_case, neck_sheath, pendant_hone, strike_pouch,
  chatelaine - inventory icons, one direction, one frame.
- icons/mob/worn_tools.dmi: fire_pouch, strike_pouch, fire_pouch_left,
  strike_pouch_left, needle_case, neck_sheath, pendant_hone, chatelaine -
  worn overlays, four directions (SOUTH, NORTH, EAST, WEST), one frame.
  The two pouches use the belt pouch stamp positions of
  icons/mob/belt_pouches.dmi (belt line y 18 from the top, wearer's right
  hip, _left mirrored). The three neck pieces hang on the necklace cord line
  of icons/mob/necklaces.dmi (neck y 9-10, lowest point (15, 13) in front)
  and show only the cord across the nape from the north. The chatelaine
  hangs from the belt line at the front right (x 12-14 facing south); it is
  empty from the north and a single column from the west.

The boot sheath, sleeve sheath and fire drill have no worn overlay: they are
hidden in a boot, up a sleeve or inside a pouch.

--check verifies the committed sheets without writing. To change the look,
edit this script and rerun it; do not hand-edit the DMIs.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_belt_pouches import figure  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OBJ = ROOT / 'icons/obj/worn_tools.dmi'
MOB = ROOT / 'icons/mob/worn_tools.dmi'
S = 32

PAL = {
    # leather, light to dark, and its outline (create_belt_pouches.py)
    '0': '#c08a58', '1': '#a06c3c', '2': '#80522a', '3': '#603a1c', '4': '#432712', 'o': '#2a180b',
    # waxed thread stitches
    's': '#d2b684',
    # rawhide, light to dark
    'A': '#e6cfa2', 'B': '#cdae78', 'C': '#ad8956', 'D': '#88663a', 'E': '#614627',
    # dark smoked leather, light to dark, and its outline
    'j': '#7a5230', 'J': '#5c3a1f', 'l': '#422712', 'L': '#2e1a0b', 'O': '#170c05',
    # bone, light to dark, and the incised rings
    't': '#ece2c8', 'i': '#d3c5a0', 'T': '#b3a384', 'I': '#7d6d50', 'k': '#554b33',
    # hemp cord
    'h': '#a8834a', 'H': '#6f5127',
    # wood, light to dark, and charring
    'w': '#c69a66', 'W': '#a2743f', 'x': '#74502a', 'X': '#523618', 'K': '#2a2220', 'c': '#4a3a32',
    # flint
    'f': '#c4beb2', 'F': '#9a958d', 'g': '#6f6a64', 'G': '#4a4640',
    # tinder fungus
    'v': '#c99556', 'u': '#a06a30', 'U': '#6e431b',
    # schist whetstone
    'p': '#bcc0bd', 'P': '#969a98', 'q': '#70747a', 'Q': '#3d4044',
    # iron and steel
    'm': '#c9cdd1', 'M': '#868b90', 'n': '#45484c',
    # brass
    'z': '#e6bc62', 'Z': '#a87a30', 'y': '#5a3e14',
}

# name: (left, top, rows). '.' is transparent.
ITEMS = {
    # Narrow sheath with a seam down the face and a collar band; the
    # wooden grip and iron bolster of a small knife stand out of the mouth.
    'boot_sheath': (11, 3, (
        '..oooo....',
        '..owWxo...',
        '..owWxo...',
        '..owxXo...',
        '..owWxo...',
        '..owWxo...',
        '.nnmmMnn..',
        'oooooooooo',
        'o00112234o',
        'oooooooooo',
        '.o0112s3o.',
        '.o011243o.',
        '.o0112s3o.',
        '.o011243o.',
        '.o0112s3o.',
        '.o011243o.',
        '.o0112s3o.',
        '.o01124o..',
        '.o011s3o..',
        '.o01124o..',
        '.o01s3o...',
        '.o0124o...',
        '.o1s3o....',
        '.o13o.....',
        '..oo......',
    )),
    # Slim, long sheath with two cord ties, knotted at the side, to bind it
    # to the forearm.
    'sleeve_sheath': (10, 4, (
        '....ooooo.....',
        '....o012o.....',
        '....o0s2o.....',
        '....o012o.....',
        '...hhhHHHh....',
        '....o0s2oHh...',
        '....o012o.h.h.',
        '....o0s2o.H..H',
        '....o012o.....',
        '....o0s2o.....',
        '....o012o.....',
        '....o0s3o.....',
        '....o012o.....',
        '....o1s3o.....',
        '....o123o.....',
        '...hhhHHHh....',
        '....o1s3oHh...',
        '....o123o.h.h.',
        '....o1s3o.H..H',
        '....o123o.....',
        '....o1s3o.....',
        '.....o23o.....',
        '.....o3o......',
        '......o.......',
    )),
    # Small sewn rawhide belt pouch with a flap and bone toggle; a flint edge
    # and a tuft of tinder fungus show at the mouth.
    'fire_pouch': (8, 6, (
        '......oooo......',
        '.....oABBCo.....',
        '.....oBooCo.....',
        '..GG.oBooCo.UU..',
        '.GfFGoBsCso.vuU.',
        '.GffFGoooooUvuuU',
        '.GFfFgGoooUvuuUo',
        '.oooooooooooooo.',
        'oAAABBBBBBBBCCDo',
        'oAABBBBBBBBCCCDo',
        'oABBBBBBBBCCCCDo',
        'osBBBBBBBCCCCDso',
        'oDsBBBBBCCCCDsEo',
        'oCDssBBCCCDssDDo',
        'oBCDDsstTssDDCDo',
        'oBCCCDDtTDDCCDDo',
        'oBCCCCCCCCCCDDEo',
        'oCCCCCCCCCCDDDEo',
        '.oCCCCCCCDDDDEo.',
        '..oooooooooooo..',
    )),
    # Bone tube, incised rings near each end, on a thin cord that runs
    # through it and ends in a knot (the cord loop is CORD_LOOP below).
    'needle_case': (13, 13, (
        '..ooo..',
        '.otiTo.',
        '.oIIIo.',
        '.otiTo.',
        '.oIIIo.',
        '.otiTo.',
        '.otiTo.',
        '.otiTo.',
        '.otiTo.',
        '.otiTo.',
        '.oIIIo.',
        '.otiTo.',
        '.oIIIo.',
        '.oiTTo.',
        '..ooo..',
        '...h...',
        '..hHh..',
        '...H...',
    )),
    # Small rawhide sheath, stitched down one side, with a wooden knife grip;
    # it hangs from a leather thong (THONG_LOOP below).
    'neck_sheath': (11, 10, (
        '....ooo....',
        '...owWxo...',
        '...owWxo...',
        '...owxXo...',
        '...owWxo...',
        '..ooooooo..',
        '..oABBCDo..',
        '..oAsBCDo..',
        '..oABBCDo..',
        '..oAsBCDo..',
        '..oABBCDo..',
        '..oAsBCDo..',
        '..oABCDo...',
        '..oAsCDo...',
        '..oBCDo....',
        '..oBDo.....',
        '...oo......',
    )),
    # Slender bar of grey schist, drilled at the top, worn smooth and
    # slightly waisted in the middle (hangs on CORD_LOOP below).
    'pendant_hone': (13, 13, (
        '..QQQ..',
        '.QpPqQ.',
        '.QpQqQ.',
        '.QpPqQ.',
        '.QppqQ.',
        '.QpPqQ.',
        '.QpPqQ.',
        '.QPPqQ.',
        '.QpPqQ.',
        '.QpPqQ.',
        '.QpPqQ.',
        '.QpPPQ.',
        '.QPPqQ.',
        '.QPqqQ.',
        '..QQQ..',
    )),
    # Chuckmuck: dark leather pouch with a flap, brass studs and a curved
    # steel striker riveted along the bottom edge.
    'strike_pouch': (7, 6, (
        '.......OOOO.......',
        '......OjJJlO......',
        '......OJOOlO......',
        '......OJOOlO......',
        '....OOOOOOOOOO....',
        '...OjjjJJJJJllO...',
        '..OjjJJJJJJJJllO..',
        '..OjJzJJJJJJzJlO..',
        '..OjJJJJJJJJJllO..',
        '..OJJJJJJJJJJlLO..',
        '..OLJJJJJJJJlLLO..',
        '..OJLLJJzZJLLlLO..',
        '..OJJJLLZyLJJlLO..',
        '..OJJJJJLLJJllLO..',
        '.nOJJJJJJJJlllLOn.',
        'nmnnnnnnnnnnnnnnMn',
        'nmmmzmmmmzMMMMzMMn',
        '.nmmmmmmMMMMMMMMn.',
        '..nnMMMMMMMMMMnn..',
        '....nnnnnnnnnn....',
    )),
    # Belt clasp with a hook, three chains and a knife, a pair of spring
    # shears and a key.
    'chatelaine': (7, 3, (
        '.......yyyy.......',
        '......yzyyZy......',
        '......yzy.yZy.....',
        '......yzZy.y......',
        '...yyyyyzZyyyyy...',
        '..yzzzzzzzZZZZZy..',
        '..yzZyzZZyzZZyZy..',
        '..yZZzZZZzZZZzZy..',
        '...yyzyyyzyyyzy...',
        '.....Z...Z...Z....',
        '.....z...z...z....',
        '.....Z...Z...Z....',
        '.....z...z...z....',
        '....oZo..Z...Z....',
        '....owo..z..yzy...',
        '....oWo..Z.yz.Zy..',
        '....oxo.nzn.yZy...',
        '....nmn.m.m..z....',
        '....nmn.m.M..Z....',
        '....nmn.nmn..z....',
        '....nMn.nmn..Zzy..',
        '....nMn.nMn..z....',
        '.....n..nMn..Zzy..',
        '.........n...y....',
    )),
}

# Cord loop over the needle case and the hone: left half from the top centre
# down to the piece, mirrored about x 16; lit on the left.
CORD_LOOP = ((16, 3), (15, 3), (14, 4), (13, 5), (12, 6), (12, 7), (12, 8), (12, 9),
             (13, 10), (14, 11), (15, 12))
# Wider leather thong for the neck knife, meeting the sheath mouth corners.
THONG_LOOP = ((16, 3), (15, 3), (14, 3), (13, 4), (12, 5), (11, 6), (10, 7), (10, 8), (10, 9),
              (10, 10), (10, 11), (11, 12), (11, 13), (12, 14))

# Hearth board of the hand drill; the spindle is laid over it in fire_drill().
HEARTH = (4, 18, (
    '.oooooooooooooooooooooo.',
    'owwwwwwWWWoKoWWWWcKcWWWo',
    'owWWWWWWWWWKWWWWcKKKcWxo',
    'oWWWxxWWWWWWWWWWWcKcxxxo',
    'oxxxxxxxxxxxxxxxxxxxxxXo',
    '.oooooooooooooooooooooo.',
))

# Worn hip pouch as seen from the front; mirrored for the back view.
WORN = {
    'fire_pouch': (
        '.BC..',
        '.BC..',
        'ABBCf',
        'ABtCD',
        'BCCCD',
        '.DDE.',
    ),
    'strike_pouch': (
        '.jJ..',
        '.jJ..',
        'jjJJl',
        'jJzJl',
        'JJJlL',
        'mmMMn',
    ),
}
# Same placement as create_belt_pouches.py: left edge per direction (SOUTH,
# NORTH, EAST), top on the belt line; from the west two front columns show.
WORN_TOP = 18
WORN_LEFT = (10, 16, 13)
WEST_LEFT = 11

# Neck cord, as create_necklaces.py lays its strands.
NECK_SOUTH = ((12, 10), (13, 11), (14, 12), (15, 13), (16, 12), (17, 11), (18, 10))
NECK_NORTH = ((13, 10), (14, 10), (15, 10), (16, 10), (17, 10))
NECK_EAST = ((14, 9), (15, 10), (16, 10), (17, 11), (18, 11), (19, 12))
# name: (cord light, cord dark, pendant from the front, pendant from the east).
# Pendants are (dx, dy, colour) from the lowest cord pixel.
NECK = {
    'needle_case': ('h', 'H',
                    ((0, 1, 't'), (0, 2, 'I'), (0, 3, 't'), (0, 4, 'i'), (0, 5, 'I'), (0, 6, 'T')),
                    ((0, 1, 't'), (0, 2, 'I'), (0, 3, 't'), (0, 4, 'i'), (0, 5, 'I'), (0, 6, 'T'))),
    'neck_sheath': ('2', '4',
                    ((0, 1, 'W'), (0, 2, 'x'),
                     (-1, 3, 'A'), (0, 3, 'B'), (1, 3, 'D'),
                     (-1, 4, 'A'), (0, 4, 'C'), (1, 4, 'D'),
                     (0, 5, 'C'), (1, 5, 'E'), (0, 6, 'D')),
                    ((0, 1, 'W'), (0, 2, 'x'),
                     (0, 3, 'A'), (1, 3, 'C'), (0, 4, 'B'), (1, 4, 'D'), (0, 5, 'C'), (0, 6, 'D'))),
    'pendant_hone': ('h', 'H',
                     ((0, 1, 'p'), (0, 2, 'P'), (0, 3, 'P'), (0, 4, 'q')),
                     ((0, 1, 'p'), (0, 2, 'P'), (0, 3, 'P'), (0, 4, 'q'))),
}

# Worn chatelaine facing south: clasp on the belt line, three chains of
# different lengths, a tool at the end of each.
CHATELAINE_SOUTH = (
    (12, 18, 'z'), (13, 18, 'Z'), (14, 18, 'z'),
    (12, 19, 'Z'), (13, 19, 'z'), (14, 19, 'Z'),
    (12, 20, 'z'), (13, 20, 'Z'), (14, 20, 'm'),
    (12, 21, 'x'), (13, 21, 'z'), (14, 21, 'M'),
    (12, 22, 'm'), (13, 22, 'Z'),
    (12, 23, 'M'), (13, 23, 'z'),
)
CHATELAINE_EAST = (
    (18, 18, 'z'), (19, 18, 'Z'),
    (18, 19, 'Z'), (19, 19, 'z'),
    (18, 20, 'z'), (19, 20, 'm'),
    (18, 21, 'x'), (19, 21, 'M'),
    (18, 22, 'm'), (18, 23, 'M'),
)
CHATELAINE_WEST = ((12, 18, 'Z'), (12, 19, 'z'), (12, 20, 'Z'), (12, 21, 'M'))


def rgba(ch):
    c = PAL[ch]
    return (int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16), 255)


def stamp(rows, left, top, flip=False):
    assert len({len(r) for r in rows}) == 1, 'ragged stamp: %r' % (rows,)
    img = Image.new('RGBA', (S, S))
    for y, row in enumerate(rows):
        row = row[::-1] if flip else row
        for x, ch in enumerate(row):
            if ch != '.':
                img.putpixel((left + x, top + y), rgba(ch))
    return img


def plot(pixels, img=None):
    img = img or Image.new('RGBA', (S, S))
    for x, y, ch in pixels:
        img.putpixel((x, y), rgba(ch))
    return img


def mirrored(img):
    return img.transpose(Image.FLIP_LEFT_RIGHT)


def loop_pixels(left_half, light, dark):
    """A closed cord loop from its left half, mirrored about x 16."""
    px = [(x, y, light) for x, y in left_half]
    px += [(32 - x, y, dark) for x, y in left_half if x != 16]
    return px


def fire_drill():
    """Hearth board with a charred notch and a spare socket; the spindle
    leans across it with its burnt tip in the notch's socket."""
    img = stamp(HEARTH[2], HEARTH[0], HEARTH[1])
    # Spindle from the socket (15, 19) up to the right, two pixels wide.
    core = []
    for i in range(16):
        x, y = 15 + (i * 2 + 1) // 3, 19 - i
        core.append((x, y, i))
    ring = set()
    solid = {(x + d, y) for x, y, _ in core for d in (0, 1)}
    for x, y in solid:
        for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if n not in solid:
                ring.add(n)
    # The outline stops where the tip sits on the board.
    plot([(x, y, 'o') for x, y in ring if y < 20 and not (y == 19 and x > 16)], img)
    for x, y, i in core:
        tip = i < 2
        plot([(x, y, 'c' if tip else 'w'), (x + 1, y, 'K' if tip else 'x' if i % 5 == 3 else 'W')], img)
    return img


def items():
    out = {}
    for name in ('boot_sheath', 'sleeve_sheath', 'fire_pouch'):
        left, top, rows = ITEMS[name]
        out[name] = stamp(rows, left, top)
    out['fire_drill'] = fire_drill()
    for name, loop, light, dark in (('needle_case', CORD_LOOP, 'h', 'H'),
                                    ('neck_sheath', THONG_LOOP, '1', '3'),
                                    ('pendant_hone', CORD_LOOP, 'h', 'H')):
        left, top, rows = ITEMS[name]
        img = plot(loop_pixels(loop, light, dark))
        img.alpha_composite(stamp(rows, left, top))
        out[name] = img
    # The hone's cord passes through the drilled hole.
    plot([(16, 13, 'H'), (16, 14, 'h')], out['pendant_hone'])
    for name in ('strike_pouch', 'chatelaine'):
        left, top, rows = ITEMS[name]
        out[name] = stamp(rows, left, top)
    return out


def worn_pouch(name):
    rows = WORN[name]
    return [
        stamp(rows, WORN_LEFT[0], WORN_TOP),
        stamp(rows, WORN_LEFT[1], WORN_TOP, flip=True),
        stamp(rows, WORN_LEFT[2], WORN_TOP, flip=True),
        stamp(['..' if i < 2 else r[:2] for i, r in enumerate(rows)], WEST_LEFT, WORN_TOP),
    ]


def worn_pouch_left(name):
    """The same pouch on the wearer's left hip (the torso is centred on x 15)."""
    south, north, east, west = worn_pouch(name)
    return [north, south, mirrored(west), mirrored(east)]


def worn_neck(name):
    light, dark, front, side = NECK[name]
    south = plot([(x, y, light if x <= 15 else dark) for x, y in NECK_SOUTH])
    plot([(15 + dx, 13 + dy, c) for dx, dy, c in front], south)
    north = plot([(x, y, light if x <= 15 else dark) for x, y in NECK_NORTH])
    east = plot([(x, y, light if y <= 10 else dark) for x, y in NECK_EAST])
    plot([(19 + dx, 12 + dy, c) for dx, dy, c in side], east)
    return [south, north, east, mirrored(east)]


def worn_chatelaine():
    return [plot(CHATELAINE_SOUTH), Image.new('RGBA', (S, S)), plot(CHATELAINE_EAST), plot(CHATELAINE_WEST)]


def mobs():
    out = {name: worn_pouch(name) for name in WORN}
    for name in WORN:
        out[name + '_left'] = worn_pouch_left(name)
    for name in NECK:
        out[name] = worn_neck(name)
    out['chatelaine'] = worn_chatelaine()
    return out


def sheet_of(states, dirs):
    frames = [f for name in states for f in (states[name] if dirs > 1 else [states[name]])]
    cols = 4 if dirs > 1 else len(frames)
    sheet = Image.new('RGBA', (cols * S, (len(frames) + cols - 1) // cols * S))
    for i, f in enumerate(frames):
        sheet.paste(f, ((i % cols) * S, (i // cols) * S))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = %d\n\theight = %d\n' % (S, S)
    for name in states:
        text += 'state = "%s"\n\tdirs = %d\n\tframes = 1\n' % (name, dirs)
    text += '# END DMI\n'
    return sheet, text


def write_dmi(path, states, dirs):
    sheet, text = sheet_of(states, dirs)
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta, optimize=True)


def same(path, states, dirs):
    if not path.exists():
        return False
    sheet, text = sheet_of(states, dirs)
    old = Image.open(path)
    return (old.info.get('Description') == text and old.size == sheet.size
            and old.convert('RGBA').tobytes() == sheet.tobytes())


def preview(loose, worn, out, scale=4):
    """Loose items at 4x and 1x, then each overlay on the base body in a
    plain tunic and bare, in all four directions at 4x and 1x."""
    cell, label, text = S * scale, 14, (235, 235, 235, 255)
    cols = 5
    item_rows = (len(loose) + cols - 1) // cols
    width = cell * 8 + 108
    col = width // cols
    top = item_rows * (cell + label)
    img = Image.new('RGBA', (width, top + len(worn) * (cell + label)), (34, 34, 40, 255))
    d = ImageDraw.Draw(img)
    for i, (name, im) in enumerate(loose.items()):
        x, y = (i % cols) * col, (i // cols) * (cell + label)
        d.text((x + 4, y + 1), name, fill=text)
        img.alpha_composite(im.resize((cell, cell), Image.NEAREST), (x, y + label))
        for n, ground in enumerate(((34, 34, 40, 255), (120, 124, 112, 255), (214, 206, 186, 255))):
            tile = Image.new('RGBA', (S, S), ground)
            tile.alpha_composite(im)
            img.alpha_composite(tile, (x + cell + 4, y + label + 8 + n * 36))
    y = top
    for name, frames in worn.items():
        d.text((4, y + 1), '%s worn: south, north, east, west over a plain tunic, the same on the bare body, then 1x'
               % name, fill=text)
        for half, uniform in enumerate(('white_tunic', None)):
            for direction in range(4):
                fig = figure(direction, uniform)
                fig.alpha_composite(frames[direction])
                img.alpha_composite(fig.resize((cell, cell), Image.NEAREST),
                                    ((half * 4 + direction) * cell, y + label))
                img.alpha_composite(fig, (8 * cell + 6 + direction * 24, y + label + 20 + half * 44))
        y += cell + label
    Path(out).parent.mkdir(parents=True, exist_ok=True)
    img.save(out)


def main(argv):
    loose, worn = items(), mobs()
    if '--check' in argv:
        ok = same(OBJ, loose, 1) and same(MOB, worn, 4)
        print('worn tool sprites are current' if ok
              else 'worn tool sprites are stale: rerun tests/sprites/create_worn_tools.py')
        return 0 if ok else 1
    write_dmi(OBJ, loose, 1)
    write_dmi(MOB, worn, 4)
    print('wrote %d loose states to %s and %d worn states to %s'
          % (len(loose), OBJ.relative_to(ROOT), len(worn), MOB.relative_to(ROOT)))
    if '--preview' in argv:
        preview(loose, worn, argv[argv.index('--preview') + 1])
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
