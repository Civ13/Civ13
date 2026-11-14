"""Hand-placed sprites for the machine shop in icons/obj/machine_shop.dmi:
the steam hammer, drill press and hydraulic press, each standing still and
working. Every pixel is placed by this script from a fixed palette (Pillow
only); no external or generated artwork.

Run with Pillow to reproduce the sheet. `--check` verifies the committed
sheet matches and `--preview <png>` writes an enlarged review sheet.
Released under Civ13 AGPL-3.0.
"""
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_clay_lime_fire import Frame, TIMBER, IRON, FIRE  # noqa: E402
from create_mechanical_power import line  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/machine_shop.dmi'

# bright worked steel: light, mid, shade
STEEL = [(206, 212, 222), (164, 170, 184), (116, 122, 138)]
# brass fittings
BRASS = [(236, 200, 96), (196, 152, 58), (140, 104, 38)]
# steam
STEAM = [(244, 246, 250), (208, 214, 224)]
# leather belt
BELT = [(150, 104, 62), (108, 72, 42)]
SPARK = (255, 232, 150)


def bed(f, x0, x1, y):
    """A cast iron foot: lit top edge, body, shaded underside."""
    f.rect(x0, y, x1, y + 2, IRON[1])
    f.hline(x0, x1, y, IRON[0])
    f.hline(x0, x1, y + 2, IRON[2])


# ---------------------------------------------------------- steam hammer --

def steam_hammer(step=None):
    """An A-frame of two iron legs carrying a steam cylinder, with the ram
    hanging between them over an anvil block and a small firebox behind.
    Working, the ram drops and rises and steam blows from the cylinder."""
    f = Frame()
    k = 0 if step is None else step % 4
    drop = (0, 5, 9, 3)[k] if step is not None else 0
    bed(f, 3, 28, 27)
    # anvil block
    f.rect(12, 23, 19, 26, IRON[1])
    f.hline(12, 19, 23, STEEL[1])
    f.hline(12, 19, 26, IRON[2])
    # the two legs of the frame
    for x0, x1 in ((6, 11), (25, 20)):
        line(f, x0, 26, x1, 9, IRON[1])
        line(f, x0 + (1 if x0 < 16 else -1), 26, x1 + (1 if x0 < 16 else -1), 9, IRON[0 if x0 < 16 else 2])
    # crosshead and cylinder
    f.rect(10, 8, 21, 10, IRON[1])
    f.hline(10, 21, 8, IRON[0])
    f.rect(13, 2, 18, 8, IRON[1])
    f.vline(13, 2, 8, IRON[0])
    f.vline(18, 2, 8, IRON[2])
    f.hline(13, 18, 2, STEEL[1])
    f.hline(13, 18, 5, BRASS[1])
    # piston rod and ram
    f.vline(15, 10, 12 + drop, STEEL[0])
    f.vline(16, 10, 12 + drop, STEEL[2])
    f.rect(13, 12 + drop, 18, 14 + drop, IRON[1])
    f.hline(13, 18, 12 + drop, IRON[0])
    f.hline(13, 18, 14 + drop, STEEL[2])
    # firebox at the right foot
    f.rect(24, 20, 28, 26, IRON[2])
    f.vline(24, 20, 26, IRON[1])
    f.hline(24, 28, 20, IRON[0])
    f.rect(25, 23, 27, 25, FIRE[2] if step is not None else IRON[1])
    if step is not None:
        f.put(26, 24, FIRE[k % 2])
        # exhaust steam from the cylinder head
        puff = ((19, 3), (20, 2), (21, 1), (22, 1))[k]
        f.put(puff[0], puff[1], STEAM[0])
        f.put(puff[0] + 1, puff[1] - (1 if puff[1] > 0 else 0), STEAM[1])
        if k == 2:
            f.pts(SPARK, (11, 22), (20, 22), (10, 24), (21, 24))    # the blow
    f.outline()
    return f


# ----------------------------------------------------------- drill press --

def drill_press(step=None):
    """A pillar drill: a round column on a foot, a work table, a head with
    a spindle and chuck, and a flat belt up to a pulley on a wall bracket.
    Working, the pulleys and the bit turn and swarf flies."""
    f = Frame()
    k = 0 if step is None else step % 4
    bed(f, 6, 25, 27)
    # column
    f.rect(19, 5, 21, 26, IRON[1])
    f.vline(19, 5, 26, IRON[0])
    f.vline(21, 5, 26, IRON[2])
    # table on its bracket
    f.rect(8, 20, 20, 21, IRON[1])
    f.hline(8, 20, 20, STEEL[1])
    line(f, 14, 22, 19, 25, IRON[2])
    # the head
    f.rect(9, 6, 21, 10, IRON[1])
    f.hline(9, 21, 6, IRON[0])
    f.hline(9, 21, 10, IRON[2])
    # spindle, chuck and bit
    f.rect(12, 11, 14, 13, STEEL[1])
    f.vline(12, 11, 13, STEEL[0])
    f.rect(12, 14, 14, 15, BRASS[1])
    for y in range(16, 20):
        lit = (y + k) % 2 == 0 if step is not None else y % 2 == 0
        f.put(13, y, STEEL[0] if lit else STEEL[2])
    # feed lever
    line(f, 9, 8, 5, 12, TIMBER[2])
    f.put(5, 12, TIMBER[0])
    # cone pulley on the head and the pulley above, with the belt
    f.rect(22, 6, 25, 9, TIMBER[2])
    f.vline(22, 6, 9, TIMBER[1])
    f.rect(23, 1, 26, 3, TIMBER[2])
    f.hline(23, 26, 1, TIMBER[1])
    for y in range(3, 7):
        dark = (y + k) % 2 == 0 if step is not None else y % 2 == 0
        f.put(26, y, BELT[1] if dark else BELT[0])
        f.put(23, y, BELT[0] if dark else BELT[1])
    f.put(24 + (k % 2 if step is not None else 0), 7, IRON[0])
    if step is not None:
        chips = (((11, 19), (15, 18)), ((10, 18), (16, 19)), ((11, 17), (15, 19)), ((10, 19), (16, 18)))[k]
        f.pts(STEEL[0], *chips)
    f.outline()
    return f


# ------------------------------------------------------- hydraulic press --

def hydraulic_press(step=None):
    """Two polished columns between a heavy bed and a top crosshead, with a
    platen driven down by the cylinder below the head, and a hand pump with
    a long lever on the left. Working, the lever rocks and the platen closes."""
    f = Frame()
    k = 0 if step is None else step % 4
    close = (0, 2, 4, 5)[k] if step is not None else 0
    # bed
    f.rect(8, 23, 27, 28, IRON[1])
    f.hline(8, 27, 23, IRON[0])
    f.hline(8, 27, 28, IRON[2])
    f.hline(11, 24, 22, STEEL[1])    # the work on the bed
    # columns
    for x in (10, 25):
        f.vline(x, 5, 22, STEEL[0])
        f.vline(x + 1, 5, 22, STEEL[2])
    # top crosshead and cylinder
    f.rect(8, 2, 27, 5, IRON[1])
    f.hline(8, 27, 2, IRON[0])
    f.hline(8, 27, 5, IRON[2])
    f.rect(15, 6, 20, 9, IRON[1])
    f.vline(15, 6, 9, IRON[0])
    f.hline(15, 20, 9, BRASS[1])
    # ram and platen
    f.rect(17, 10, 18, 11 + close, STEEL[1])
    f.vline(17, 10, 11 + close, STEEL[0])
    f.rect(12, 12 + close, 23, 14 + close, IRON[1])
    f.hline(12, 23, 12 + close, IRON[0])
    f.hline(12, 23, 14 + close, STEEL[2])
    # hand pump: a small cylinder, a pipe to the press, a lever
    f.rect(3, 20, 6, 27, IRON[1])
    f.vline(3, 20, 27, IRON[0])
    f.hline(3, 6, 20, BRASS[1])
    f.hline(6, 8, 25, BRASS[2])
    tip = (12, 15, 18, 14)[k] if step is not None else 12
    line(f, 4, 19, 1, tip, TIMBER[2])
    f.put(1, tip, TIMBER[0])
    f.put(4, 19, IRON[0])
    # pressure gauge
    f.put(22, 7, BRASS[0])
    f.put(23, 7, STEEL[0] if (step is None or k < 2) else FIRE[2])
    f.outline()
    return f


def states():
    """[(state, frames, delay)] in sheet order."""
    return [
        ('steam_hammer', [steam_hammer()], 0),
        ('steam_hammer_on', [steam_hammer(i) for i in range(4)], 2),
        ('drill_press', [drill_press()], 0),
        ('drill_press_on', [drill_press(i) for i in range(4)], 2),
        ('hydraulic_press', [hydraulic_press()], 0),
        ('hydraulic_press_on', [hydraulic_press(i) for i in range(4)], 4),
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
        print('machine shop sheet matches')
    else:
        write_dmi()
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
