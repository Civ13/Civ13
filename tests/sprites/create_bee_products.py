"""Hand-placed sprites for the things that come out of a hive in
icons/farming/bee_products.dmi: a stick of sealing wax (`sealing_wax`), the
same stick used down to about half its length (`sealing_wax_half`) and a slab
of capped honeycomb cut from a hive (`honeycomb`). Every pixel is placed by
this script from a fixed palette (Pillow only); no external or generated
artwork. Shading is soft, lit from the upper left, with no black outline, like
the `beeswax` cake of icons/farming/wild_bees.dmi the sticks are made from.

The two wax states are GREYSCALE: the game multiplies them by the item's `color` var
to make red, black, blue, green, pink or white wax, so the ramp runs from pure
white down to a mid grey and never darker, which leaves the black wax a
visible sheen and the white wax a visible shadow side. The stick lies on the
diagonal with its square-cut foot at the lower left; the upper right end is
the one held to the flame, rounded and slightly swollen on the whole stick,
worn to a slant with a bead of wax run down its side on the half stick.

`honeycomb` is in full colour and is not tinted. It is a hand-sized slab lying
face up, typed out pixel by pixel in HONEYCOMB_MAP: pale-gold capped cells
three pixels wide and two tall, each a little dome (lighter upper left, darker
lower right) between tan walls and laid like bricks, at the cell scale of the
`brood_comb` of wild_bees.dmi and the `honey_frame_filled` of frame_hives.dmi;
the right side is the cut edge, where the cells are open and full of amber
honey with a glint in each; the near edge shows the thickness of the slab,
soaked with honey, and two drips hang from it.

Run with Pillow to write the sheet. `--check` verifies the committed sheet
(all three states), `--preview <png>` writes a 4x review sheet of the wax
states untinted and in each of the six wax colours on grass, dirt, a wooden
table and a dark inventory slot, then the old `honeycomb` of
icons/farming/beekeeping.dmi beside the new one and the new one beside
`brood_comb`, `crushed_comb` and `honey_frame_filled` on the same grounds,
with 2x and 1x rows. Released under Civ13 AGPL-3.0.
"""
import re
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/farming/bee_products.dmi'

SIZE = 32

# untinted wax: gloss, light, mid, shade, dark
WAX = [(255, 255, 255), (232, 232, 232), (202, 202, 202), (164, 164, 164), (124, 124, 124)]
# the six colours of code/modules/1713/sealing_wax.dm
TINTS = [('red', (0xa3, 0x20, 0x1b)), ('black', (0x2a, 0x25, 0x24)), ('blue', (0x2f, 0x4f, 0x9a)),
         ('green', (0x2f, 0x7a, 0x3c)), ('pink', (0xd9, 0x7a, 0xa6)), ('white', (0xec, 0xe6, 0xd6))]

# The stick lies on the 45 degree diagonal. A pixel is addressed by `a`, its
# step along the stick from the square-cut foot at the lower left, and `d`,
# the diagonal it sits on across the stick: -2 is the lit upper left edge,
# 0 the middle and +2 the shadowed lower right edge.
FOOT = (9, 23)
# wax colour by diagonal: light edge, light, mid, shade, dark edge
ACROSS = {-2: 1, -1: 1, 0: 2, 1: 3, 2: 4}


def body(end):
    """Pixels of a stick; end(a, d) is true past the end of the stick."""
    px = {}
    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = x - FOOT[0], y - FOOT[1]
            a, d = dx - dy, dx + dy
            if a < 0 or abs(d) > 2 or end(a, d):
                continue
            px[(x, y)] = WAX[ACROSS[d]]
    return px


def at(a, d):
    """The pixel `a` steps along the stick on diagonal `d` (same parity)."""
    return FOOT[0] + (a + d) // 2, FOOT[1] + (d - a) // 2


def put(px, c, *spots):
    for a, d in spots:
        px[at(a, d)] = WAX[c]


def frame(px):
    im = Image.new('RGBA', (SIZE, SIZE))
    for (x, y), c in px.items():
        im.putpixel((x, y), c + (255,))
    return im


def sealing_wax():
    # 25 steps long (17-18 px); the nose rounds off over the last three
    px = body(lambda a, d: a > 24 or (a > 23 and abs(d) > 0) or (a > 21 and abs(d) > 1))
    # softened by the flame, the wax sags a little on the shadow side
    put(px, 4, (15, 3), (17, 3), (19, 3))
    put(px, 3, (16, 2), (18, 2), (20, 2))
    # glossy streak along the lit side, broken once, and a glint on the nose
    put(px, 0, (3, -1), (5, -1), (7, -1), (9, -1), (13, -1), (15, -1), (21, -1))
    # the foot: square cut, its face a shade darker than the lit side
    put(px, 2, (0, -2), (1, -1))
    put(px, 3, (0, 0))
    return frame(px)


def sealing_wax_half():
    # used down to 13 steps (9-10 px) with a blunt, slumped end
    px = body(lambda a, d: a > 13 or (a > 12 and abs(d) > 1))
    # the worn end: a pale molten rim across it
    put(px, 1, (12, 0), (13, 1))
    put(px, 2, (12, 2))
    # a bead of wax that ran down the shadow side and set there
    put(px, 3, (11, 3), (7, 3))
    put(px, 1, (9, 3))
    put(px, 4, (10, 4), (8, 4))
    put(px, 3, (10, 2), (8, 2))
    put(px, 0, (3, -1), (5, -1), (9, -1), (11, -1))
    put(px, 2, (0, -2), (1, -1))
    put(px, 3, (0, 0))
    return frame(px)


# The honeycomb, one character per pixel; the first column is x = 6 and the
# first row y = 9. Capped cells are two cap pixels and a wall pixel wide and
# two rows tall, every second pair of rows shifted like brickwork.
HONEYCOMB = {
    'H': (252, 244, 208),   # cap, the lit top of the dome
    'L': (243, 224, 160),   # cap, light
    'M': (228, 200, 124),   # cap, mid
    'S': (208, 174, 98),    # cap, shade
    'w': (178, 134, 64),    # cell wall
    'W': (142, 98, 42),     # wall in shadow, the near face of the slab
    'g': (255, 236, 160),   # glint on honey
    'a': (250, 204, 86),    # honey, bright
    'b': (232, 164, 40),    # honey
    'c': (200, 126, 26),    # honey, deep
    'd': (156, 92, 20),     # honey in shadow
    'e': (116, 66, 18),     # the darkest honey, under the slab
}
HONEYCOMB_AT = (6, 9)
HONEYCOMB_MAP = (
    '.LwHLwHLwHLwLMLdcL..',
    'LMwLMwLMwLMwMSMbaLb.',
    'wHLwHLwHLwLMwLdcLdcL',
    'wLMwLMwLMwMSwMbaLbaM',
    'HLwHLwLMwLMwLMLdcLdc',
    'LMwLMwMSwMSwMSMbaMba',
    'wHLwLMwLMwLMwLdcLdcL',
    'wLMwMSwMSwMSwMbaMbaM',
    'LMwLMwLMwMSwMSLdcLdW',
    '.SwMSwMSwSSwSSMbaMbW',
    '.WwWWwWWwWWwWWcWWcd.',
    '..WcWwbWWwWcWbWcWbd.',
    '....edWdeWddWcde....',
    '......b.....c.......',
    '......a.............',
)


def honeycomb():
    px = {}
    for j, row in enumerate(HONEYCOMB_MAP):
        for i, ch in enumerate(row):
            if ch != '.':
                px[(HONEYCOMB_AT[0] + i, HONEYCOMB_AT[1] + j)] = HONEYCOMB[ch]
    return frame(px)


def states():
    return [('sealing_wax', [sealing_wax()], 0), ('sealing_wax_half', [sealing_wax_half()], 0),
            ('honeycomb', [honeycomb()], 0)]


def build():
    sheet = states()
    frames = [fr for _, frs, _ in sheet for fr in frs]
    cols = int(len(frames) ** 0.5 + 0.999)
    rows = (len(frames) + cols - 1) // cols
    im = Image.new('RGBA', (cols * SIZE, rows * SIZE))
    for i, fr in enumerate(frames):
        im.paste(fr, ((i % cols) * SIZE, (i // cols) * SIZE))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, frs, delay in sheet:
        text += 'state = "%s"\n\tdirs = 1\n\tframes = %d\n' % (name, len(frs))
        if len(frs) > 1:
            text += '\tdelay = %s\n' % ','.join([str(delay)] * len(frs))
    return im, text + '# END DMI\n'


def write_dmi():
    im, text = build()
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    im.save(SHEET, 'PNG', pnginfo=meta, optimize=True)


def check():
    if not SHEET.exists():
        return False
    im, text = build()
    old = Image.open(SHEET)
    return old.info.get('Description') == text and old.convert('RGBA').tobytes() == im.tobytes()


# ---------------------------------------------------------------- review --

BACK = (24, 24, 24, 255)
GROUNDS = [('grass', (98, 122, 78, 255)), ('dirt', (122, 96, 68, 255)),
           ('table', (150, 110, 70, 255)), ('slot', (58, 58, 62, 255))]


def tinted(fr, tint):
    """The frame as the game draws it with `color` set: a per-channel multiply."""
    out = fr.copy()
    for y in range(SIZE):
        for x in range(SIZE):
            r, g, b, a = fr.getpixel((x, y))
            if a:
                out.putpixel((x, y), (r * tint[0] // 255, g * tint[1] // 255,
                                      b * tint[2] // 255, a))
    return out


def dmi_state(path, name):
    """The first frame of a state of another sheet, for the review only."""
    im = Image.open(path)
    text = im.info['Description']
    size = int(re.search(r'width = (\d+)', text).group(1))
    at = 0
    for m in re.finditer(r'state = "(.*?)"\n\tdirs = (\d+)\n\tframes = (\d+)', text):
        if m.group(1) == name:
            break
        at += int(m.group(2)) * int(m.group(3))
    else:
        raise KeyError(name)
    im = im.convert('RGBA')
    cols = im.width // size
    x, y = (at % cols) * size, (at // cols) * size
    return im.crop((x, y, x + size, y + size))


def preview(path, scale=4):
    sheet = states()
    wax, comb = sheet[:2], sheet[2][1][0]
    looks = [('untinted', (255, 255, 255))] + TINTS
    tiles = []         # per ground: [(label, tile at 1x)]
    for ground, colour in GROUNDS:
        row = []
        for name, frs, _ in wax:
            for look, tint in looks:
                tile = Image.new('RGBA', (SIZE, SIZE), colour)
                tile.alpha_composite(tinted(frs[0], tint))
                row.append((look, tile))
        tiles.append((ground, row))
    farming = ROOT / 'icons/farming'
    beside = [('old honeycomb', dmi_state(farming / 'beekeeping.dmi', 'honeycomb')),
              ('new honeycomb', comb), None,
              ('new honeycomb', comb),
              ('brood_comb', dmi_state(farming / 'wild_bees.dmi', 'brood_comb')),
              ('crushed_comb', dmi_state(farming / 'wild_bees.dmi', 'crushed_comb')),
              ('honey_frame_filled', dmi_state(farming / 'frame_hives.dmi', 'honey_frame_filled'))]
    combs = []         # per ground: [(label, tile at 1x) or None for a gap]
    for ground, colour in GROUNDS:
        row = []
        for entry in beside:
            if entry is None:
                row.append(None)
                continue
            tile = Image.new('RGBA', (SIZE, SIZE), colour)
            tile.alpha_composite(entry[1])
            row.append((entry[0], tile))
        combs.append((ground, row))
    pad, label = 6, 12
    cell = SIZE * scale + pad
    per = len(looks) * len(wax)
    width = pad + per * cell
    small = 2 * label + len(GROUNDS) * (66 + 34)
    height = pad + len(GROUNDS) * (cell + 2 * label) * 2 + 2 * small + pad
    out = Image.new('RGBA', (width, height), BACK)
    draw = ImageDraw.Draw(out)
    y = pad
    for title, block in (('%s  |  %s' % (wax[0][0], wax[1][0]), tiles),
                         ('honeycomb: old beside new, then new beside the other comb', combs)):
        for ground, row in block:
            draw.text((pad, y), 'on %s:  %s' % (ground, title), fill=(230, 230, 230, 255))
            for i, entry in enumerate(row):
                if entry is None:
                    continue
                x = pad + i * cell
                draw.text((x, y + label), entry[0], fill=(170, 170, 170, 255))
                out.paste(entry[1].resize((SIZE * scale,) * 2, Image.NEAREST), (x, y + 2 * label))
            y += cell + 2 * label
        draw.text((pad, y), '2x and 1x', fill=(230, 230, 230, 255))
        y += label
        for ground, row in block:
            for i, entry in enumerate(row):
                if entry is None:
                    continue
                out.paste(entry[1].resize((64, 64), Image.NEAREST), (pad + i * 66, y))
                out.paste(entry[1], (pad + i * 34, y + 66))
            y += 66 + 34
        y += label
    out.save(path)


if __name__ == '__main__':
    if '--check' in sys.argv:
        if not check():
            sys.exit('stale sheet: ' + str(SHEET))
        print('bee product states match')
    else:
        write_dmi()
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
