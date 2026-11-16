"""Hand-placed 32px window fitting sprites for
icons/obj/doors/window_fittings.dmi: a glazed casement and wooden and iron
shutters, each shut, open and through its opening and closing animations.

They are drawn to lie over the `windownew_frame` sprite of
icons/obj/windows.dmi, whose opening is the square x = 4-27, y = 4-27 inside
the timber surround (the same square the stone, sandstone and marble frames
leave). Each fitting is two leaves of 12 x 24px that fill that square and
meet on x = 15/16, so they cover the frame's own mullion and transom. The
leaves are hinged on the jambs (x = 4 and x = 27) and swing outwards: over
six frames (delay 2, loop 1) each leaf foreshortens from 12px to a 4px strip
against its jamb (x = 4-7 and x = 24-27), leaving x = 8-23 clear.

The casement is only the two sashes: light timber stiles and rails, glazing
bars that cut each leaf into eight small panes, and slightly blue glass that
is partly see-through. The wooden shutters are three upright boards a leaf in
a warm brown with two dark iron strap hinges; the iron shutters are dark grey
plate with a stiffening band and rivets. Both shutters are fully opaque and
carry a 1px dark outline round each leaf. Nothing here is tinted.

Every pixel is placed by this script from a fixed palette (Pillow only); no
external or generated artwork. Run it to reproduce the sheet; `--check`
verifies the committed sheet instead of writing it, `--preview <png>` writes
a 4x review sheet of every state over the `windownew_frame` and
`medieval_windownew_frame` sprites, with a 1x strip. Released under Civ13
AGPL-3.0.
"""
import re
import sys
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/doors/window_fittings.dmi'
WINDOWS = ROOT / 'icons/obj/windows.dmi'

OUT = (28, 22, 16)
# sash timber, lighter than the frame it hangs in: highlight, light, mid, shade
SASH = [(214, 170, 112), (184, 136, 80), (150, 104, 56), (104, 68, 34)]
# glass, slightly blue and partly see-through: glare, pane, deep pane
GLASS = [(226, 242, 250, 170), (150, 198, 226, 110), (112, 164, 202, 125)]
# shutter boards, a warm brown: highlight, light, mid, shade, dark
BOARD = [(190, 132, 72), (164, 108, 56), (138, 88, 44), (108, 66, 32), (78, 46, 22)]
# iron straps and rivets: highlight, light, mid, dark
STRAP = [(158, 162, 170), (98, 102, 112), (62, 64, 74), (38, 40, 48)]
# iron plate: highlight, light, mid, shade, dark
PLATE = [(152, 156, 166), (108, 112, 124), (80, 84, 96), (60, 64, 74), (42, 44, 54)]

X0, X1, Y0, Y1 = 4, 27, 4, 27   # the window opening, inclusive
LEAF_W = 12                     # a shut leaf; the two meet on x = 15/16
LEAF_H = Y1 - Y0 + 1
WIDTHS = (12, 10, 8, 6, 5, 4)   # px each leaf shows at each opening frame


class Frame:
    def __init__(self):
        self.px = {}

    def put(self, x, y, c):
        if 0 <= x < 32 and 0 <= y < 32:
            self.px[(x, y)] = c

    def image(self):
        im = Image.new('RGBA', (32, 32))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c if len(c) == 4 else c + (255,))
        return im


# Each leaf painter fills a dict {(col, row): colour} for a leaf w px wide and
# LEAF_H tall. Column 0 is the hinge edge and column w - 1 the free edge, so
# the right-hand leaf is the same leaf mirrored; `lit` says whether the hinge
# edge is the one facing the light (the left leaf) so shading is not mirrored.

def casement_leaf(w, lit):
    """A sash: stiles, top, middle and bottom rails, glazing bars and panes."""
    px = {}
    last = w - 1
    bar = (w - 1) // 2 if w >= 8 else None      # the upright glazing bar
    for r in range(LEAF_H):
        for c in range(w):
            left = c if lit else last - c       # 0 at the leaf's lit edge
            if r == 0:
                col = SASH[0]
            elif r == LEAF_H - 1:
                col = SASH[3]
            elif c == 0:                        # hinge stile
                col = SASH[1] if lit else SASH[3]
            elif c == last:                     # meeting stile, outer line
                col = OUT if lit else SASH[0]
            elif c == last - 1 and w >= 8:      # meeting stile, face
                col = SASH[2] if lit else SASH[1]
            elif r in (11, 12):                 # middle rail
                col = SASH[1] if r == 11 else SASH[3]
            elif r in (6, 17) or c == bar:      # glazing bars
                col = SASH[2]
            else:
                col = GLASS[1] if (r < 11) == (left * 2 < w) or w < 8 else GLASS[2]
            px[(c, r)] = col
    # a glare in the upper lit corner of each pane, and a deeper lower corner
    cols = [c for c in range(1, last) if px[(c, 1)] in GLASS]
    panes = [[]]
    for c in cols:
        if panes[-1] and c != panes[-1][-1] + 1:
            panes.append([])
        panes[-1].append(c)
    for pane in panes:
        if not pane:
            continue
        near, far = (pane[0], pane[-1]) if lit else (pane[-1], pane[0])
        for top, bottom in ((1, 5), (7, 10), (13, 16), (18, 22)):
            px[(near, top)] = GLASS[0]
            if len(pane) >= 3:
                px[(near, top + 1)] = GLASS[0]
                step = 1 if near < far else -1
                px[(near + step, top)] = GLASS[0]
                px[(far, bottom)] = GLASS[2]
    return px


def wood_leaf(w, lit):
    """Three upright boards in a dark outline, hung on two iron straps."""
    px = {}
    last = w - 1
    inner = w - 2
    for r in range(LEAF_H):
        for c in range(w):
            if r in (0, LEAF_H - 1) or c in (0, last):
                px[(c, r)] = OUT
                continue
            left = (c if lit else last - c) - 1         # 0 .. inner - 1 from the lit side
            if inner >= 6:
                # three boards; each lit on its left edge, shaded on its right
                edges = [0, inner // 3, inner - inner // 3, inner]
                b = max(i for i in range(3) if left >= edges[i])
                col = (BOARD[1] if left == edges[b] else
                       BOARD[3] if left == edges[b + 1] - 1 else BOARD[2])
            else:
                col = (BOARD[1] if left == 0 else
                       BOARD[3] if left == inner - 1 and inner > 1 else BOARD[2])
            if r == 1:
                col = BOARD[0] if col != BOARD[3] else BOARD[2]
            elif r == LEAF_H - 2:
                col = BOARD[4] if col == BOARD[3] else BOARD[3]
            px[(c, r)] = col
    if inner >= 6:
        # grain: a few short dark and light flecks, kept off the straps
        for c, r, shade in ((2, 9, 3), (2, 10, 3), (5, 13, 3), (5, 14, 3), (8, 8, 3),
                            (8, 9, 3), (3, 15, 1), (6, 3, 1), (9, 21, 3), (2, 21, 1)):
            if 1 <= c < last and px[(c, r)] == BOARD[2]:
                px[(c, r)] = BOARD[shade]
    # strap hinges from the hinge edge: lit top line, body, rivets, pointed end
    reach = max(1, min(inner - 1, (inner * 4 + 2) // 5))
    for top in (4, 18):
        for i in range(reach):
            c = 1 + i
            px[(c, top)] = STRAP[1]
            px[(c, top + 1)] = STRAP[3]
            if i == reach - 1 and reach >= 4:   # the taper at the strap's end
                px[(c, top)] = STRAP[2]
                px[(c, top + 1)] = px[(c, top + 2)]
        for i in ((0, 3, 6) if reach >= 7 else (0, 3) if reach >= 4 else (0,)):
            px[(1 + i, top)] = STRAP[0]
        # the knuckle on the hinge edge
        px[(1, top - 1)] = STRAP[2]
        px[(1, top + 2)] = STRAP[3]
    return px


def iron_leaf(w, lit):
    """A dark grey plate in a dark outline, with a stiffening band across the
    middle and rivets round its edge."""
    px = {}
    last = w - 1
    inner = w - 2
    for r in range(LEAF_H):
        for c in range(w):
            if r in (0, LEAF_H - 1) or c in (0, last):
                px[(c, r)] = OUT
                continue
            left = (c if lit else last - c) - 1
            col = PLATE[2]
            if left == 0 or r == 1:
                col = PLATE[1]
            if (left == inner - 1 and inner > 1) or r == LEAF_H - 2:
                col = PLATE[3]
            if r == 11:                         # the band: lit top, dark foot
                col = PLATE[1]
            elif r == 12:
                col = PLATE[2] if inner > 2 else PLATE[3]
            elif r == 13:
                col = PLATE[4]
            px[(c, r)] = col
    # rivets, each a bright head with its shadow below
    if inner >= 6:
        rivet_cols = (2, last - 2)
    elif inner >= 3:
        rivet_cols = (2,) if lit else (last - 2,)
    else:
        rivet_cols = (1,) if lit else (last - 1,)
    for c in rivet_cols:
        for r in (3, 7, 16, 20):
            px[(c, r)] = PLATE[0]
            px[(c, r + 1)] = PLATE[4]
    if inner >= 8:
        for c in (4, last - 4):
            px[(c, 12)] = PLATE[0]
        # a scuff on each panel so the plate is not dead flat
        for c, r in ((5, 5), (6, 5), (4, 18), (5, 19)):
            cc = c if lit else last - c
            px[(cc, r)] = PLATE[1] if r < 11 else PLATE[3]
    return px


def fitting(leaf, w):
    """Both leaves at width w, each hard against its own jamb."""
    f = Frame()
    for (c, r), col in leaf(w, True).items():
        f.put(X0 + c, Y0 + r, col)
    for (c, r), col in leaf(w, False).items():
        f.put(X1 - c, Y0 + r, col)
    return f


def fitting_states(name, leaf):
    opening = [fitting(leaf, w) for w in WIDTHS]
    return {
        name: [opening[0]],
        name + 'open': [opening[-1]],
        name + 'opening': opening,
        name + 'closing': opening[::-1],
    }


def states():
    st = {}
    st.update(fitting_states('casement', casement_leaf))
    st.update(fitting_states('shutters_wood', wood_leaf))
    st.update(fitting_states('shutters_iron', iron_leaf))
    return st


def build_sheet(st):
    frames = [fr for group in st.values() for fr in group]
    sheet = Image.new('RGBA', (32 * len(frames), 32), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(fr.image(), (i * 32, 0))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, group in st.items():
        text += 'state = "%s"\n\tdirs = 1\n\tframes = %d\n' % (name, len(group))
        if len(group) > 1:      # the timing of the material door animations
            text += '\tdelay = %s\n\tloop = 1\n' % ','.join(['2'] * len(group))
    text += '# END DMI\n'
    return sheet, text


def write_dmi(path, st):
    sheet, text = build_sheet(st)
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta)


def check(path, st):
    sheet, text = build_sheet(st)
    old = Image.open(path)
    if old.info.get('Description') != text:
        sys.exit('%s: state list differs from the generator' % path)
    if old.size != sheet.size or ImageChops.difference(old.convert('RGBA'), sheet).getbbox():
        sys.exit('%s: pixels differ from the generator' % path)
    print('%s matches the generator' % path)


def window_state(name):
    """The first frame of one state of icons/obj/windows.dmi."""
    im = Image.open(WINDOWS)
    at = 0
    for m in re.finditer(r'state = "(.*)"\n\tdirs = (\d+)\n\tframes = (\d+)', im.info['Description']):
        if m.group(1) == name:
            x, y = (at % (im.width // 32)) * 32, (at // (im.width // 32)) * 32
            return im.convert('RGBA').crop((x, y, x + 32, y + 32))
        at += int(m.group(2)) * int(m.group(3))
    sys.exit('%s: no state "%s"' % (WINDOWS, name))


def preview(path, st, scale=4):
    text, dim = (230, 230, 230), (170, 170, 170)
    # what shows through the opening: grass outside by day, a dark room
    grounds = [(94, 132, 62), (44, 40, 46)]
    frames = ('windownew_frame', 'medieval_windownew_frame')
    under = {n: window_state(n) for n in frames}
    fittings = ('casement', 'shutters_wood', 'shutters_iron')
    columns = [('frame only', None, 0), ('shut', '', 0)]
    columns += [('opening %d' % (n + 1), 'opening', n) for n in range(len(WIDTHS))]
    columns += [('open', 'open', 0)]
    cell, pad, label, left = 32 * scale, 8, 14, 190
    step = cell + pad
    rows = [(fit, fr) for fit in fittings for fr in frames]
    width = left + len(columns) * step + pad
    height = label + len(rows) * step + pad + label + len(rows) * 34 + pad
    sheet = Image.new('RGBA', (width, height), (40, 40, 44, 255))
    draw = ImageDraw.Draw(sheet)

    def tile(fit, fr, suffix, frame, ground):
        t = Image.new('RGBA', (32, 32), ground + (255,))
        t.alpha_composite(under[fr])
        if suffix is not None:
            t.alpha_composite(st[fit + suffix][frame].image())
        return t

    for c, col in enumerate(columns):
        draw.text((left + c * step, 2), col[0], fill=text)
    y = label
    for r, (fit, fr) in enumerate(rows):
        draw.text((4, y + r * step + cell // 2 - 12), fit, fill=text)
        draw.text((4, y + r * step + cell // 2), 'on ' + fr, fill=dim)
        for c, col in enumerate(columns):
            t = tile(fit, fr, col[1], col[2], grounds[0])
            sheet.paste(t.resize((cell, cell), Image.NEAREST), (left + c * step, y + r * step))
    y += len(rows) * step + pad
    draw.text((4, y), '1x: the same over grass, then over a dark room, then closing over grass', fill=text)
    y += label
    for r, (fit, fr) in enumerate(rows):
        x = left
        for ground in grounds:
            for col in columns:
                sheet.paste(tile(fit, fr, col[1], col[2], ground), (x, y + r * 34))
                x += 34
            x += pad
        # the closing frames run the opening ones backwards; show them at 1x only
        for n in range(len(WIDTHS)):
            sheet.paste(tile(fit, fr, 'closing', n, grounds[0]), (x, y + r * 34))
            x += 34
    sheet.save(path)


if __name__ == '__main__':
    st = states()
    if '--check' in sys.argv:
        check(SHEET, st)
    else:
        write_dmi(SHEET, st)
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1], st)
