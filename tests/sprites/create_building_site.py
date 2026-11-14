"""Hand-placed sprites for the building-site kit in
icons/obj/building_site.dmi: the hand-cranked cement mixer with its turning
loop, and cast concrete blocks. Every pixel is placed by this script from a
fixed palette (Pillow only); no external or generated artwork.

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
SHEET = ROOT / 'icons/obj/building_site.dmi'

# painted drum: glint, light, mid, dark, deep
DRUM = [(238, 190, 96), (214, 150, 58), (176, 112, 40), (130, 78, 30), (88, 52, 24)]
# wet mix and set concrete: highlight, light, mid, dark, deep
MIX = [(206, 206, 200), (176, 176, 172), (146, 146, 144), (112, 112, 114), (80, 80, 86)]
# cart wheel rim and spoke
RIM = [(70, 66, 66), (40, 38, 40)]


# ----------------------------------------------------------- cement mixer --

def cement_mixer(step=None):
    """A tilted iron drum on a two-wheeled timber cart, turned by a crank on
    the near side. Working, the drum's bands roll, the crank goes round and
    the wet mix slops in the mouth."""
    f = Frame()
    turn = 0 if step is None else step % 4
    # cart frame: two shafts and a cross beam
    f.rect(4, 22, 27, 23, TIMBER[2])
    f.hline(4, 27, 22, TIMBER[1])
    f.hline(4, 27, 24, TIMBER[4])
    for x in (7, 23):                      # uprights carrying the drum trunnions
        f.vline(x, 14, 22, TIMBER[2])
        f.vline(x + 1, 14, 22, TIMBER[3])
    # prop leg at the mouth end
    f.vline(27, 24, 28, TIMBER[3])
    f.put(27, 28, TIMBER[4])
    # the drum: a fat barrel tilted mouth-up to the right
    def barrel(x, y, nx, ny):
        band = (x - y + turn * 2) % 8
        if ny < -0.55 and nx < 0.4:
            c = DRUM[0] if band else DRUM[1]
        elif ny < -0.1:
            c = DRUM[1]
        elif ny < 0.5:
            c = DRUM[2]
        else:
            c = DRUM[3]
        if band == 0 and -0.8 < nx < 0.7:
            c = DRUM[4] if ny > 0 else DRUM[3]       # rolling hoop
        return c
    f.ellipse(15, 13, 9.5, 7.5, barrel)
    # neck and open mouth, upper right
    f.rect(21, 6, 25, 10, DRUM[2])
    f.hline(21, 25, 6, DRUM[1])
    f.vline(25, 6, 10, DRUM[3])

    def mouth(x, y, nx, ny):
        if nx * nx + ny * ny > 0.55:
            return DRUM[4]
        slop = (x + y + turn) % 3 == 0
        return MIX[1] if slop else MIX[3]
    f.ellipse(24.5, 6.5, 3.4, 2.6, mouth)
    if step is None:
        for x in range(22, 28):
            if (x, 6) in f.px and f.px[(x, 6)] in (MIX[1], MIX[3]):
                f.put(x, 6, DRUM[4])          # empty, dark throat
                f.put(x, 7, DRUM[4])
    else:
        f.put(27 + turn % 2, 9 + turn % 3, MIX[2])   # a drip off the lip
    # trunnion and crank on the near side
    f.rect(6, 12, 9, 15, IRON[1])
    f.hline(6, 9, 12, IRON[0])
    arm = ((0, -4), (4, 0), (0, 4), (-4, 0))[turn]
    cx, cy = 7, 14
    for t in range(1, 5):
        f.put(cx + arm[0] * t // 4, cy + arm[1] * t // 4, IRON[0])
    hx, hy = cx + arm[0], cy + arm[1]
    f.pts(TIMBER[0], (hx, hy), (hx - 1, hy))
    f.put(hx - 2, hy, TIMBER[2])
    # two spoked wheels
    for wx in (9, 21):
        def wheel(x, y, nx, ny):
            d = nx * nx + ny * ny
            if d > 0.5:
                return RIM[0] if ny < 0 else RIM[1]
            if abs(x - wx) == abs(y - 26) or x == wx or y == 26:
                return TIMBER[1]
            return TIMBER[4]
        f.ellipse(wx, 26, 3.5, 3.5, wheel)
        f.put(wx, 26, IRON[0])
    f.outline()
    return f


# -------------------------------------------------------- concrete blocks --

def block(f, x0, y0, w, h, seed):
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            c = MIX[1]
            if y == y0:
                c = MIX[0]
            elif y >= y0 + h - 2:
                c = MIX[3]
            elif x == x0 + w - 1:
                c = MIX[3]
            elif grain(x, y, seed) == 0:
                c = MIX[2]
            elif grain(x, y, seed + 5) == 1:
                c = MIX[0]
            f.put(x, y, c)
    f.pts(MIX[4], (x0 + 2, y0 + h - 1), (x0 + w - 3, y0 + h - 1))


def concrete(pile=1):
    """Cast concrete blocks: one, a short stack, or a full pile."""
    f = Frame()
    block(f, 8, 20, 14, 6, 1)
    if pile >= 2:
        block(f, 4, 21, 9, 5, 2) if pile >= 3 else None
        block(f, 11, 14, 13, 6, 3)
    if pile >= 3:
        block(f, 18, 20, 10, 6, 4)
        block(f, 8, 8, 12, 6, 5)
    f.outline((52, 52, 58))
    return f


def states():
    """[(state, frames, delay)] in sheet order."""
    return [
        ('cement_mixer', [cement_mixer()], 0),
        ('cement_mixer_on', [cement_mixer(i) for i in range(4)], 2),
        ('concrete', [concrete(1)], 0),
        ('concrete_2', [concrete(2)], 0),
        ('concrete_3', [concrete(3)], 0),
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
        print('building site sheet matches')
    else:
        write_dmi()
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
