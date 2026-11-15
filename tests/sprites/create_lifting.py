"""Hand-placed sprites for the shear legs hoist in
icons/obj/lifting_machines.dmi: empty, with a load slung, and the hauling
loop, plus the treadwheel crane and its hauling loop. Every pixel is placed by this script from a fixed palette (Pillow
only); no external or generated artwork.

Run with Pillow to reproduce the sheet. `--check` verifies the committed
sheet matches and `--preview <png>` writes an enlarged review sheet.
Released under Civ13 AGPL-3.0.
"""
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_clay_lime_fire import Frame, TIMBER, IRON, grain  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/lifting_machines.dmi'

# peeled pole: light, mid, dark
POLE = [(204, 170, 116), (166, 130, 82), (114, 84, 50)]
# hemp rope: light, mid, dark
ROPE = [(226, 208, 160), (186, 164, 112), (134, 114, 74)]
# crate boards: light, mid, dark
CRATE = [(176, 132, 84), (140, 98, 58), (98, 66, 38)]


def leg(f, x_top, x_foot, y_top, y_foot, shade):
    """One pole of the A-frame, two pixels thick, from the lashing to the ground."""
    span = y_foot - y_top
    for i in range(span + 1):
        x = x_top + round((x_foot - x_top) * i / span)
        y = y_top + i
        f.put(x, y, POLE[shade])
        f.put(x + 1, y, POLE[min(2, shade + 1)])
    f.put(x_foot, y_foot, POLE[2])
    f.put(x_foot + 1, y_foot, POLE[2])


def shear_legs(loaded=False, step=None):
    """Two poles lashed at the head and spread at the foot, a back guy rope,
    and a block and hook hanging from the lashing. A slung load hangs low at
    rest and climbs and sways while it is hauled."""
    f = Frame()
    # back guy rope to a peg, drawn first so the poles cross over it
    for i in range(12):
        f.put(17 + i, 3 + i * 2 if 3 + i * 2 < 27 else 27, ROPE[2])
    f.pts(TIMBER[3], (28, 27), (29, 27), (28, 28))
    # the two legs
    leg(f, 14, 3, 2, 29, 0)
    leg(f, 16, 26, 2, 29, 1)
    # lashing at the head
    f.rect(13, 3, 18, 5, ROPE[1])
    f.hline(13, 18, 3, ROPE[0])
    f.hline(13, 18, 5, ROPE[2])
    f.pts(POLE[0], (14, 1), (15, 0), (16, 1), (17, 0))
    # foot spreader so the legs cannot splay
    for x in range(6, 25):
        f.put(x, 27, TIMBER[3] if grain(x, 27, 3) else TIMBER[2])
    # block and fall
    sway = 0 if step is None else (0, 1, 0, -1)[step % 4]
    lift = 0 if step is None else (0, 2, 4, 6)[step % 4]
    hook_y = (19 if loaded else 12) - lift
    f.rect(14, 6, 16, 8, IRON[1])
    f.put(15, 7, IRON[0])
    for y in range(9, hook_y):
        f.put(15 + (sway if y > 12 else 0), y, ROPE[0] if y % 2 else ROPE[1])
    hx = 15 + sway
    f.pts(IRON[1], (hx, hook_y), (hx, hook_y + 1), (hx + 1, hook_y + 2), (hx, hook_y + 3), (hx - 1, hook_y + 2))
    f.put(hx, hook_y, IRON[0])
    # hauling end of the fall, down the near leg to a cleat
    for i in range(18):
        f.put(13 - i // 2, 8 + i, ROPE[1] if (i + (0 if step is None else step)) % 3 else ROPE[2])
    f.pts(IRON[2], (4, 25), (5, 25))
    if loaded:
        top = hook_y + 3
        # rope sling
        f.pts(ROPE[1], (hx - 1, top), (hx + 1, top), (hx - 2, top + 1), (hx + 2, top + 1))
        # a bound crate
        for y in range(top + 2, top + 8):
            for x in range(hx - 4, hx + 5):
                c = CRATE[1]
                if y == top + 2 or x == hx - 4:
                    c = CRATE[0]
                elif y == top + 7 or x == hx + 4:
                    c = CRATE[2]
                elif (x - hx) % 3 == 0:
                    c = CRATE[2]
                f.put(x, y, c)
        f.hline(hx - 4, hx + 4, top + 4, ROPE[1])
    f.outline()
    return f


def treadwheel_crane(step=None):
    """A timber crane: a stout mast on a braced base, a long jib raking up to
    the right with a hook on its fall, and a winding drum at the foot.
    Hauling, a crate climbs under the jib and the drum turns."""
    f = Frame()
    # base sills and mast
    f.rect(3, 27, 22, 28, TIMBER[2])
    f.hline(3, 22, 27, TIMBER[1])
    f.hline(3, 22, 29, TIMBER[4])
    f.rect(9, 5, 11, 26, TIMBER[2])
    f.vline(9, 5, 26, TIMBER[1])
    f.vline(11, 5, 26, TIMBER[3])
    # raking braces either side of the mast
    for i in range(10):
        f.put(4 + i // 2, 26 - i, TIMBER[3])
        f.put(17 - i // 2, 26 - i, TIMBER[3])
    # the jib, from the mast head out and up to the right
    for i in range(19):
        x = 10 + i
        y = 7 - i * 5 // 18
        f.put(x, y, POLE[0])
        f.put(x, y + 1, POLE[1])
    f.pts(IRON[1], (28, 2), (29, 2), (28, 3))        # jib sheave
    # stay from the mast head back to the tail of the base
    for i in range(11):
        f.put(9 - i // 2, 5 + i * 2, ROPE[2])
    # winding drum at the foot, its spokes turning
    turn = 0 if step is None else step % 4
    f.rect(12, 20, 17, 25, TIMBER[3])
    f.hline(12, 17, 20, TIMBER[1])
    spoke = ((14, 21), (16, 22), (15, 24), (13, 23))[turn]
    f.put(spoke[0], spoke[1], ROPE[0])
    f.put(14, 22, IRON[0])
    # the fall from the sheave to the hook
    lift = 0 if step is None else (0, 2, 4, 6)[step % 4]
    hook_y = (11 if step is None else 17) - lift
    for y in range(4, hook_y):
        f.put(28, y, ROPE[0] if y % 2 else ROPE[1])
    f.pts(IRON[1], (28, hook_y), (28, hook_y + 1), (29, hook_y + 2), (28, hook_y + 3), (27, hook_y + 2))
    if step is not None:
        top = hook_y + 4
        for y in range(top, top + 6):
            for x in range(24, 31):
                c = CRATE[1]
                if y == top or x == 24:
                    c = CRATE[0]
                elif y == top + 5 or x == 30:
                    c = CRATE[2]
                f.put(x, y, c)
        f.hline(24, 30, top + 2, ROPE[1])
    f.outline()
    return f


def states():
    """[(state, frames, delay)] in sheet order."""
    return [
        ('shear_legs', [shear_legs()], 0),
        ('shear_legs_haul', [shear_legs(True, i) for i in range(4)], 3),
        ('treadwheel_crane', [treadwheel_crane()], 0),
        ('treadwheel_crane_haul', [treadwheel_crane(i) for i in range(4)], 3),
    ]


def build():
    frames = [fr for _, frs, _ in states() for fr in frs]
    cols = int(len(frames) ** 0.5 + 0.999)
    rows = (len(frames) + cols - 1) // cols
    im = Image.new('RGBA', (cols * 32, rows * 32))
    for i, fr in enumerate(frames):
        im.paste(fr.image(), ((i % cols) * 32, (i // cols) * 32))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, frs, delay in states():
        text += 'state = "%s"\n\tdirs = 1\n\tframes = %d\n' % (name, len(frs))
        if len(frs) > 1:
            text += '\tdelay = %s\n' % ','.join([str(delay)] * len(frs))
    text += '# END DMI\n'
    return im, text


def write_dmi():
    im, text = build()
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    im.save(SHEET, 'PNG', pnginfo=meta, optimize=True)


def check():
    im, text = build()
    old = Image.open(SHEET)
    return old.info.get('Description') == text and old.convert('RGBA').tobytes() == im.tobytes()


def preview(path, scale=6):
    """Every state's frames on grass, stone, snow and night grounds."""
    grounds = ((98, 122, 78, 255), (120, 118, 112, 255), (226, 232, 238, 255), (30, 38, 52, 255))
    rows = [frs[:4] for _, frs, _ in states()]
    pad = 6
    cell = 32 * scale + pad
    out = Image.new('RGBA', (pad + 4 * 4 * cell, pad + len(rows) * cell), (24, 24, 24, 255))
    for j, frs in enumerate(rows):
        for g, bg in enumerate(grounds):
            for i, fr in enumerate(frs):
                tile = Image.new('RGBA', (32 * scale, 32 * scale), bg)
                tile.alpha_composite(fr.image().resize((32 * scale, 32 * scale), Image.NEAREST))
                if g == 3:
                    tile.alpha_composite(Image.new('RGBA', tile.size, (10, 14, 40, 90)))
                out.paste(tile, (pad + (g * 4 + i) * cell, pad + j * cell))
    out.save(path)


if __name__ == '__main__':
    if '--check' in sys.argv:
        if not check():
            sys.exit('stale sheet: ' + str(SHEET))
        print('lifting sheet matches')
    else:
        write_dmi()
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
