"""Original hand-placed 32px art for player paintings: easel, canvases, frames,
ground pigments and the worn locket.

Every pixel comes from the fixed palettes, coordinate lists and character
stamps in this file; there is no external, traced or generated artwork.
Released under Civ13's AGPL-3.0 licence. Run with Pillow from the repository
root:

    python3 tests/sprites/create_paintings.py [--check] [--preview sheet.png]

It writes icons/obj/paintings.dmi (one direction) and icons/mob/paintings.dmi
(four directions: SOUTH, NORTH, EAST, WEST). `--check` writes nothing and
fails if the committed sheets differ from what this script draws.

The game overlays the player's painting (a generated icon) under or inside
these sprites, so the art windows below are a contract with the code. They
are BYOND coordinates: x 1..32 from the left, y 1..32 from the BOTTOM.

    easel_canvas      face x 9..24, y 14..29 (art drawn on top of the face)
    canvas_miniature  face x 9..24, y 9..24, primed #e9dfc8; rim on the ring
                      x 8..25, y 8..25
    frame_miniature   same ring, window x 9..24, y 9..24 transparent
    canvas_table      face x 9..24, y 11..26, primed #e9dfc8
    frame_table       same frame and stand, window transparent
    canvas_wall       face x 2..31, y 2..31, stretcher edge on x 1/32, y 1/32
    frame_wall        frame on the outer two pixels, x 3..30, y 3..30
                      transparent
    locket (SOUTH)    8x8 face x 13..20, y 11..18 transparent, 1px bezel
                      around it; the other directions show cord and edge only

`main` asserts every window before writing. To change the look, edit this
script and rerun it; do not hand-edit the DMIs.
"""
import sys
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_belt_pouches import dmi_frames, figure, tile, write_dmi  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OBJ = ROOT / 'icons/obj/paintings.dmi'
MOB = ROOT / 'icons/mob/paintings.dmi'
S = 32

PRIMED = '#e9dfc8'
# wood, light to dark, and the outline (the leather/wood ramp of the belt pouches)
W0, W1, W2, W3, W4, OUT = '#c08a58', '#a06c3c', '#80522a', '#603a1c', '#432712', '#2a180b'
# hemp lashing
CORD, CORD_D = '#d2b684', '#a8834a'
# linen edge of a stretched canvas
LINEN_L, LINEN_D, LINEN_O = '#f0e7cb', '#c4b58a', '#7c704e'
# bronze bezel and gilding
BZ0, BZ1, BZ2 = '#dcae56', '#94692a', '#5a3e14'
GILT, GILT_D = '#c1af5e', '#996c35'
# hanging frame, as the painting1..13 decals: near-black edge over dark wood
FR_EDGE, FR_WOOD, FR_LIT = '#1b140d', '#402308', '#6a4016'
# worn cord on skin
NECK, NECK_D = '#8c5c30', '#5c3819'

# Art windows, BYOND coordinates (x1, x2, y1, y2), inclusive.
WIN_EASEL = (9, 24, 14, 29)
WIN_MINIATURE = (9, 24, 9, 24)
WIN_TABLE = (9, 24, 11, 26)
WIN_WALL_FACE = (2, 31, 2, 31)
WIN_WALL = (3, 30, 3, 30)
WIN_LOCKET = (13, 20, 11, 18)

PIGMENTS = {
    'pigment_charcoal': '#2a2522',
    'pigment_red_ochre': '#9a3d26',
    'pigment_yellow_ochre': '#c99a3a',
    'pigment_bone_white': '#ece6d6',
}
OBJ_ORDER = ('easel', 'easel_canvas', 'canvas_miniature', 'frame_miniature', 'canvas_table',
             'frame_table', 'canvas_wall', 'frame_wall') + tuple(PIGMENTS)
MOB_ORDER = ('locket',)

# Ground pigment heaped on a scrap of leather. L M D are the pigment's light,
# base and shade; 0-3 the leather; o the outline.
PIGMENT_ROWS = (
    '......oooo......',
    '.....oLLMMo.....',
    '....oLLMMMDo....',
    '..ooLLMLMMDDoo..',
    '.o0oLMMMMDMDo2o.',
    '.o10oMMMMDDo23o.',
    '.o1100oooo2233o.',
    '..o1M12222333o..',
    '...oo2223D3oo...',
    '.....oooooo.....',
)
PIGMENT_AT = (8, 12)  # left, top (from the top-left)


def rgba(c):
    return (int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16), 255)


def shade(c, f):
    """Scale a colour towards black (f < 1) or white (f > 1)."""
    r, g, b, _ = rgba(c)
    if f <= 1:
        return '#%02x%02x%02x' % (int(r * f), int(g * f), int(b * f))
    f -= 1
    return '#%02x%02x%02x' % (int(r + (255 - r) * f), int(g + (255 - g) * f), int(b + (255 - b) * f))


def new():
    return Image.new('RGBA', (S, S))


def put(img, x, y, c):
    """Set one pixel given BYOND coordinates (y from the bottom)."""
    img.putpixel((x - 1, S - y), rgba(c))


def box(x1, x2, y1, y2):
    return [(x, y) for y in range(y1, y2 + 1) for x in range(x1, x2 + 1)]


def in_win(x, y, win):
    return win[0] <= x <= win[1] and win[2] <= y <= win[3]


def fill(img, win, c):
    for x, y in box(*win):
        put(img, x, y, c)


def outline(img, c=OUT, keep_clear=None):
    """Dark one-pixel outline around the drawing, never inside keep_clear."""
    src = img.copy()
    for y in range(1, S + 1):
        for x in range(1, S + 1):
            if src.getpixel((x - 1, S - y))[3] or (keep_clear and in_win(x, y, keep_clear)):
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 1 <= nx <= S and 1 <= ny <= S and src.getpixel((nx - 1, S - ny))[3]:
                    put(img, x, y, c)
                    break
    return img


def ring(img, win, lit, mid, dark, cut_corners=False):
    """One-pixel bevelled ring just outside win: lit top and left, dark bottom and right."""
    x1, x2, y1, y2 = win[0] - 1, win[1] + 1, win[2] - 1, win[3] + 1
    for x, y in box(x1, x2, y1, y2):
        if in_win(x, y, win):
            continue
        if cut_corners and x in (x1, x2) and y in (y1, y2):
            continue
        if y == y2 or x == x1:
            c = lit if (x + y) % 5 else mid
        else:
            c = dark if (x + y) % 5 else mid
        put(img, x, y, c)


# ---------------------------------------------------------------- structures

def easel():
    img = new()
    # rear prop, seen between the front legs
    for y in range(4, 29):
        put(img, 16, y, W3)
        put(img, 17, y, W4)
    # two splayed front legs of split timber, lit on the left
    for y in range(1, 31):
        x = 5 + (y - 1) * 9 // 29
        for lx in (x, 33 - x - 1):
            put(img, lx, y, W1 if y % 7 else W0)
            put(img, lx + 1, y, W2 if y % 5 else W3)
    # lower brace
    for x in range(8, 26):
        put(img, x, 6, W2)
        put(img, x, 5, W3)
    # canvas ledge resting on pegs
    for x in range(5, 29):
        put(img, x, 12, W0 if x % 6 else W1)
        put(img, x, 11, W2)
    for x in (10, 23):
        put(img, x, 13, W1)  # peg heads that stop the canvas sliding
        put(img, x, 11, W4)
    # hemp lashings at the apex and where the ledge crosses the legs
    for x, y in ((14, 30), (15, 30), (18, 30), (19, 30), (15, 29), (16, 29), (17, 29), (18, 29)):
        put(img, x, y, CORD if (x + y) % 2 else CORD_D)
    for x in (8, 9, 24, 25):
        put(img, x, 12, CORD)
        put(img, x, 11, CORD_D)
    return outline(img)


def easel_canvas():
    img = new()
    fill(img, WIN_EASEL, PRIMED)
    ring(img, WIN_EASEL, LINEN_L, LINEN_D, LINEN_O)
    return img


# ----------------------------------------------------------------- miniature

def miniature_loop(img):
    for x, y, c in ((16, 26, BZ1), (17, 26, BZ2), (15, 27, BZ0), (18, 27, BZ2), (16, 28, BZ0), (17, 28, BZ1)):
        put(img, x, y, c)


def canvas_miniature():
    img = new()
    fill(img, WIN_MINIATURE, PRIMED)
    ring(img, WIN_MINIATURE, W2, W3, W4, cut_corners=True)
    return img


def frame_miniature():
    img = new()
    ring(img, WIN_MINIATURE, BZ0, BZ1, BZ2, cut_corners=True)
    miniature_loop(img)
    return img


# --------------------------------------------------------------- table panel

def table_frame(face):
    img = new()
    # feet of the stand: two splayed front legs and the rear prop between them
    for i, y in enumerate(range(8, 1, -1)):
        x = 9 - i // 2
        put(img, x, y, W1)
        put(img, x + 1, y, W3)
        put(img, 33 - x - 1, y, W1)
        put(img, 33 - x, y, W3)
    for y in range(4, 9):
        put(img, 16, y, W3)
        put(img, 17, y, W4)
    ring(img, WIN_TABLE, W0, W1, W3)
    for x, y in ((8, 27), (25, 27), (8, 10), (25, 10)):  # pegged corners
        put(img, x, y, W4)
    outline(img, keep_clear=WIN_TABLE)
    if face:
        fill(img, WIN_TABLE, PRIMED)
    return img


# --------------------------------------------------------------------- wall

def canvas_wall():
    img = new()
    fill(img, WIN_WALL_FACE, PRIMED)
    for x, y in box(1, 32, 1, 32):
        if in_win(x, y, WIN_WALL_FACE):
            continue
        c = LINEN_D if (y == 32 or x == 1) else LINEN_O
        if (x in (1, 32) and y % 6 == 3) or (y in (1, 32) and x % 6 == 3):
            c = W3  # tacks holding the linen to the stretcher
        put(img, x, y, c)
    return img


def frame_wall():
    img = new()
    for x, y in box(1, 32, 1, 32):
        if in_win(x, y, WIN_WALL):
            continue
        outer = x in (1, 32) or y in (1, 32)
        lit = (y >= 31 and x <= 30) or (x <= 2 and y >= 3)
        if outer:
            c = FR_WOOD if lit else FR_EDGE
        else:  # inner lip carries the gilding
            c = GILT if lit else GILT_D
            if (x + y) % 4 == 0:
                c = FR_LIT
        put(img, x, y, c)
    for x, y in ((1, 1), (32, 1), (1, 32), (32, 32)):
        put(img, x, y, FR_EDGE)
    for x, y in ((2, 31), (31, 31), (2, 2), (31, 2)):  # gilt corner studs
        put(img, x, y, GILT)
    return img


# ------------------------------------------------------------------ pigments

def pigment(colour):
    pal = {'L': shade(colour, 1.22), 'M': colour, 'D': shade(colour, 0.72),
           '0': W0, '1': W1, '2': W2, '3': W3, 'o': OUT}
    img = new()
    left, top = PIGMENT_AT
    for y, row in enumerate(PIGMENT_ROWS):
        for x, ch in enumerate(row):
            if ch != '.':
                img.putpixel((left + x, top + y), rgba(pal[ch]))
    return img


# -------------------------------------------------------------------- locket

def locket():
    """Cord on the neck line of icons/mob/necklaces.dmi with an oval pendant on the chest."""
    south = new()
    ring(south, WIN_LOCKET, BZ0, BZ1, BZ2, cut_corners=True)
    # cord from both sides of the neck down to the bezel (top-left coords 12,10 .. as the necklaces)
    for x, y, c in ((13, 22, NECK), (14, 21, NECK), (15, 20, NECK_D), (20, 22, NECK_D), (19, 21, NECK_D),
                    (18, 20, NECK_D)):
        put(south, x, y, c)
    north = new()
    for x in range(14, 19):
        put(north, x, 22, NECK if x <= 16 else NECK_D)
    east = new()
    for x, y in ((15, 23), (16, 22), (17, 22), (18, 21), (19, 21), (20, 20)):
        put(east, x, y, NECK if y >= 22 else NECK_D)
    for y in range(11, 19):  # the pendant edge-on against the chest
        put(east, 21, y, BZ0 if y >= 15 else BZ1)
        put(east, 20, y, BZ2)
    put(east, 21, 19, BZ1)
    put(east, 21, 10, BZ2)
    return [south, north, east, east.transpose(Image.FLIP_LEFT_RIGHT)]


# -------------------------------------------------------------------- checks

def assert_window(img, win, name, clear=None, colour=None):
    for x, y in box(*win):
        p = img.getpixel((x - 1, S - y))
        if clear:
            assert p[3] == 0, '%s: (%d,%d) must be transparent' % (name, x, y)
        if colour:
            assert p == rgba(colour), '%s: (%d,%d) must be %s' % (name, x, y, colour)


def assert_outside(img, win, name):
    """Every pixel of the one-pixel ring around win is opaque, bar cut corners."""
    x1, x2, y1, y2 = win[0] - 1, win[1] + 1, win[2] - 1, win[3] + 1
    for x, y in box(x1, x2, y1, y2):
        if in_win(x, y, win) or (x in (x1, x2) and y in (y1, y2)):
            continue
        assert img.getpixel((x - 1, S - y))[3] == 255, '%s: rim gap at (%d,%d)' % (name, x, y)


def build():
    items = {
        'easel': easel(), 'easel_canvas': easel_canvas(),
        'canvas_miniature': canvas_miniature(), 'frame_miniature': frame_miniature(),
        'canvas_table': table_frame(True), 'frame_table': table_frame(False),
        'canvas_wall': canvas_wall(), 'frame_wall': frame_wall(),
    }
    items.update({name: pigment(c) for name, c in PIGMENTS.items()})
    items = {name: items[name] for name in OBJ_ORDER}
    mobs = {'locket': locket()}

    assert_window(items['easel_canvas'], WIN_EASEL, 'easel_canvas', colour=PRIMED)
    assert_window(items['canvas_miniature'], WIN_MINIATURE, 'canvas_miniature', colour=PRIMED)
    assert_window(items['frame_miniature'], WIN_MINIATURE, 'frame_miniature', clear=True)
    assert_window(items['canvas_table'], WIN_TABLE, 'canvas_table', colour=PRIMED)
    assert_window(items['frame_table'], WIN_TABLE, 'frame_table', clear=True)
    assert_window(items['canvas_wall'], WIN_WALL_FACE, 'canvas_wall', colour=PRIMED)
    assert_window(items['frame_wall'], WIN_WALL, 'frame_wall', clear=True)
    assert_window(mobs['locket'][0], WIN_LOCKET, 'locket south', clear=True)
    for name, win, img in (('canvas_miniature', WIN_MINIATURE, items['canvas_miniature']),
                           ('frame_miniature', WIN_MINIATURE, items['frame_miniature']),
                           ('canvas_table', WIN_TABLE, items['canvas_table']),
                           ('frame_table', WIN_TABLE, items['frame_table']),
                           ('frame_wall', WIN_WALL, items['frame_wall']),
                           ('locket south', WIN_LOCKET, mobs['locket'][0])):
        assert_outside(img, win, name)
    # the rim of the miniature stays on its ring, bar the cord loop of the frame
    for x, y in box(1, 32, 1, 32):
        if not in_win(x, y, (8, 25, 8, 25)):
            assert items['canvas_miniature'].getpixel((x - 1, S - y))[3] == 0
    # canvas_table and frame_table share every pixel outside the window
    blank = table_frame(True)
    for x, y in box(*WIN_TABLE):
        blank.putpixel((x - 1, S - y), (0, 0, 0, 0))
    assert ImageChops.difference(blank, items['frame_table']).getbbox() is None
    return items, mobs


# ------------------------------------------------------------------- preview

def sample(size):
    """A test painting: sky, sun, hills and corner marks so the window edges show."""
    img = Image.new('RGBA', (size, size))
    for y in range(size):
        for x in range(size):
            t = y / (size - 1)
            c = (int(70 + 120 * t), int(120 + 80 * t), int(210 - 60 * t))
            if y > size * 0.55 + (x % (size // 2 or 1)) * 0.25:
                c = (60, 130 - (x * 40 // size), 60)
            if (x - size * 0.7) ** 2 + (y - size * 0.3) ** 2 <= (size * 0.16) ** 2:
                c = (250, 214, 80)
            img.putpixel((x, y), c + (255,))
    for x, y in ((0, 0), (size - 1, 0), (0, size - 1), (size - 1, size - 1)):
        img.putpixel((x, y), (230, 40, 200, 255))
    return img


def with_art(win, under=None, over=None, behind=None):
    """Art in its window: behind (structure), under (blank canvas), art, over (frame)."""
    out = new()
    for layer in (behind, under):
        if layer:
            out.alpha_composite(layer)
    size = win[1] - win[0] + 1
    out.alpha_composite(sample(size), (win[0] - 1, S - win[3]))
    if over:
        out.alpha_composite(over)
    return out


def preview(items, mobs, out, scale=6):
    cell, label, pad = S * scale, 28, 10
    wall_art = with_art((1, 32, 1, 32), over=items['frame_wall'])
    easel_blank = items['easel'].copy()
    easel_blank.alpha_composite(items['easel_canvas'])
    rows = [
        [('easel', items['easel']), ('easel +\neasel_canvas', easel_blank),
         ('+ art x9-24 y14-29', with_art(WIN_EASEL, items['easel_canvas'], behind=items['easel'])),
         ('easel_canvas', items['easel_canvas'])],
        [('canvas_miniature', items['canvas_miniature']), ('frame_miniature', items['frame_miniature']),
         ('art x9-24 y9-24\n+ frame_miniature', with_art(WIN_MINIATURE, items['canvas_miniature'],
                                                         items['frame_miniature'])),
         ('canvas_table', items['canvas_table']), ('frame_table', items['frame_table']),
         ('art x9-24 y11-26\n+ frame_table', with_art(WIN_TABLE, items['canvas_table'], items['frame_table']))],
        [('canvas_wall', items['canvas_wall']), ('frame_wall', items['frame_wall']),
         ('32x32 art\n+ frame_wall', wall_art)] + [(n.replace('pigment_', 'pigment_\n'), items[n]) for n in PIGMENTS],
    ]
    names = ('SOUTH', 'NORTH', 'EAST', 'WEST')
    for uniform in (None, 'white_tunic'):
        row = []
        for d in range(4):
            fig = figure(d, uniform)
            if d == 0:
                art = Image.new('RGBA', (S, S))
                art.alpha_composite(sample(8), (WIN_LOCKET[0] - 1, S - WIN_LOCKET[3]))
                fig.alpha_composite(art)
            fig.alpha_composite(mobs['locket'][d])
            note = '\nart x13-20 y11-18' if d == 0 else ''
            row.append(('locket %s%s' % (names[d], note) if not uniform else 'on tunic %s' % names[d], fig))
        if not uniform:
            row.append(('locket SOUTH\n(state only)', mobs['locket'][0]))
            row.append(('locket EAST\n(state only)', mobs['locket'][2]))
        rows.append(row)
    cols = max(len(r) for r in rows)
    img = Image.new('RGBA', (cols * (cell + pad) + pad + 80, len(rows) * (cell + label + pad) + pad),
                    (58, 62, 70, 255))
    d = ImageDraw.Draw(img)
    for r, row in enumerate(rows):
        y = pad + r * (cell + label + pad)
        for c, (name, icon) in enumerate(row):
            x = pad + c * (cell + pad)
            d.multiline_text((x + 2, y), name, fill=(240, 240, 240, 255), spacing=1)
            for cy in range(0, cell, scale * 2):  # checker so transparency reads
                for cx in range(0, cell, scale * 2):
                    dark = (cx // (scale * 2) + cy // (scale * 2)) % 2
                    d.rectangle((x + cx, y + label + cy, x + cx + scale * 2 - 1, y + label + cy + scale * 2 - 1),
                                fill=(92, 96, 104, 255) if dark else (108, 112, 120, 255))
            img.alpha_composite(icon.resize((cell, cell), Image.NEAREST), (x, y + label))
        x = pad + len(row) * (cell + pad)
        d.text((x, y), '1x', fill=(240, 240, 240, 255))
        for i, (name, icon) in enumerate(row):  # true-size strip
            img.alpha_composite(icon, (x + (i % 2) * 36, y + label + (i // 2) * 36))
    Path(out).parent.mkdir(parents=True, exist_ok=True)
    img.save(out)


def same(path, states, dirs):
    if not path.exists():
        return False
    starts, sheet = dmi_frames(path)
    if list(starts) != list(states):
        return False
    for name, frames in states.items():
        for i, f in enumerate(frames if dirs > 1 else [frames]):
            if tile(sheet, starts[name] + i).tobytes() != f.tobytes():
                return False
    return True


def main(argv):
    items, mobs = build()
    if '--check' in argv:
        ok = same(OBJ, items, 1) and same(MOB, mobs, 4)
        print('paintings sprites', 'match' if ok else 'DIFFER from create_paintings.py')
        return 0 if ok else 1
    write_dmi(OBJ, items, 1)
    write_dmi(MOB, mobs, 4)
    print('wrote', OBJ.relative_to(ROOT), 'and', MOB.relative_to(ROOT))
    if '--preview' in argv:
        preview(items, mobs, argv[argv.index('--preview') + 1])
        print('wrote', argv[argv.index('--preview') + 1])
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
