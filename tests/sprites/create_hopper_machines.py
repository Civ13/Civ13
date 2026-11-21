"""Hand-placed 32px hopper-fed machines for icons/obj/hopper_machines.dmi:
the mill stones (`millstones`, `millstones_on`) and the water-powered sash
saw (`sash_saw`, `sash_saw_on`). Each has one direction; the `_on` states
are four-frame loops.

The mill stones sit on a heavy timber hurst frame in 3/4 view: the grey
runner stone on the bed stone, a staved wooden tun round the back and left
(cut away at the right so both stones show), the grain hopper on its horse
over the eye and the meal spout at the front. Running, the dressing furrows
go round the stone face and flour dusts the spout.

The sash saw is an upright wooden sash holding one iron blade between two
fixed fender posts, over a long low carriage bed with a squared log fed into
the blade from the left and a rack of logs at the back. Running, the sash and
blade go up and down and sawdust falls below the cut.

Palette, outline and light (from the upper left) are those of
create_transmission.py and the prime movers in create_mechanical_power.py:
the same seasoned timber, wrought iron and field stone.

The art is drawn procedurally by this script: every pixel is placed from a
fixed palette (Pillow only); no external or generated artwork. Run it to
reproduce the sheet; `--check` verifies the committed sheet instead of
writing it, `--preview <png>` writes a 4x review sheet on grass. Released
under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageChops, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_transmission import Frame, TIMBER, STONE, IRON, GREASE, grain  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/hopper_machines.dmi'

# the dark inside of a box or trough
PIT = (40, 28, 20, 255)
# grain heaped in the hopper: light, shade
WHEAT = [(226, 190, 104, 255), (184, 146, 70, 255)]
# flour: in the spout, and drifting off it
FLOUR = (244, 238, 222, 255)
FLOUR_DUST = (244, 238, 222, 150)
# fresh-sawn wood and the dust that falls from it
SAWN = [(232, 200, 140, 255), (206, 170, 110, 255)]
SAWDUST = (240, 214, 156, 255)

FRAMES_ON = 4
DELAY_ON = 1


def arc(cx, rx, ry, x):
    """Half height of an ellipse at column x (0 outside it)."""
    d = 1 - ((x - cx) / rx) ** 2
    return ry * math.sqrt(d) if d > 0 else 0.0


# ------------------------------------------------------------ mill stones

def millstones(step=None):
    """`step` None is the mill standing; 0-3 are the turning frames."""
    f = Frame()
    cx, cy = 15, 14
    # hurst frame: top face, front beam, legs
    f.rect(1, 19, 30, 25, TIMBER[2])
    f.hline(1, 30, 19, TIMBER[1])
    f.vline(1, 19, 25, TIMBER[1])
    for x in range(2, 30):
        if grain(x // 3, 8, 4) == 0:
            f.put(x, 23, TIMBER[3])
    f.rect(1, 26, 30, 28, TIMBER[3])
    f.hline(1, 30, 26, TIMBER[1])
    f.hline(1, 30, 28, TIMBER[4])
    f.pts(TIMBER[4], (3, 27), (28, 27))                       # trenails
    for x0 in (2, 26):
        f.rect(x0, 29, x0 + 3, 30, TIMBER[3])
        f.vline(x0, 29, 30, TIMBER[2])
        f.vline(x0 + 3, 29, 30, TIMBER[4])
    # the stones and the tun, column by column
    cut = 19                                  # the tun is cut away from here
    for x in range(cx - 13, cx + 14):
        h_tun = arc(cx, 12.5, 6.5, x)
        h_gap = arc(cx, 11.4, 5.7, x)
        h_st = arc(cx, 10.4, 5.0, x)
        if h_tun <= 0:
            continue
        top, bot = round(cy - h_tun), round(cy + h_tun)
        # the rim of the tun round the back, and the dark gap inside it
        f.put(x, top, TIMBER[1] if x < cut else TIMBER[2])
        for y in range(top + 1, cy + 1):
            f.put(x, y, TIMBER[4] if y == top + 1 else PIT)
        if x < cut:
            for y in range(cy, round(cy + h_gap) + 1):
                f.put(x, y, PIT)
            # the staved wall under the front of the rim, with an iron hoop
            base = TIMBER[1] if x < 8 else TIMBER[2]
            for y in range(bot, bot + 6):
                f.put(x, y, TIMBER[3 if x >= 8 else 2] if x % 3 == 1 else base)
            f.put(x, bot, TIMBER[0])
            f.put(x, bot + 3, IRON[1])
            f.put(x, bot + 5, TIMBER[4])
        if h_st > 0:
            s_top, s_bot = round(cy - h_st), round(cy + h_st)
            if x >= cut:
                # the stones' own edge: runner, the joint, the bed stone
                dark = x >= 23
                for k in range(1, 7):
                    c = STONE[4] if k == 4 else STONE[3 if dark or k > 4 else 2]
                    f.put(x, s_bot + k, c)
                if grain(x, 3, 6) < 3:
                    f.put(x, s_bot + 2, STONE[3])
            for y in range(s_top, s_bot + 1):
                f.put(x, y, STONE[1])
            if x < cx + 4:
                f.put(x, s_top, STONE[0])        # the lit back edge
            if x >= cut:
                f.put(x, s_bot, STONE[0])        # the arris over the cut-away
        if x == cut:
            for y in range(bot, bot + 6):
                f.put(x - 1, y, TIMBER[4])       # the sawn end of the staves
    # dressing furrows on the runner face, turning with the stone
    phase = 10 + (step or 0) * 15
    for k in range(6):
        a = math.radians(phase + k * 60)
        ca, sa = math.cos(a), math.sin(a)
        f.line(round(cx + 3 * ca), round(cy + 1.5 * sa),
               round(cx + 9 * ca), round(cy + 4.3 * sa), STONE[3])
    # the bright land that shows the stone going round
    a = math.radians(phase + 40 + (step or 0) * 75)
    f.line(round(cx + 5 * math.cos(a)), round(cy + 2.4 * math.sin(a)),
           round(cx + 8 * math.cos(a)), round(cy + 3.8 * math.sin(a)), STONE[0])
    # the eye, with its iron rynd
    f.rect(cx - 1, cy - 1, cx + 1, cy, PIT)
    f.put(cx - 2, cy, IRON[1])
    f.put(cx + 2, cy, IRON[1])
    # the horse: two legs standing on the tun and a rail behind the hopper
    for x0 in (6, 23):
        f.vline(x0, 4, 9, TIMBER[1])
        f.vline(x0 + 1, 4, 9, TIMBER[3])
    f.hline(6, 24, 4, TIMBER[1])
    f.hline(7, 24, 5, TIMBER[3])
    # the hopper: an inverted pyramid, grain showing in its mouth
    for y in range(2, 9):
        half = 6 - (y - 2) * 5 // 6
        for x in range(cx - half, cx + half + 1):
            c = TIMBER[1] if x < cx else TIMBER[2]
            if x == cx - half:
                c = TIMBER[0]
            if x == cx + half:
                c = TIMBER[4]
            f.put(x, y, c)
    f.hline(cx - 6, cx + 6, 0, TIMBER[0])
    f.hline(cx - 5, cx + 5, 1, WHEAT[0])
    f.pts(WHEAT[1], (cx - 3, 1), (cx, 1), (cx + 2, 1), (cx + 5, 1))
    f.pts(TIMBER[1], (cx - 6, 1), (cx + 6, 1))
    f.hline(cx - 6, cx + 6, 2, TIMBER[0])
    f.put(cx + 6, 2, TIMBER[2])
    # the shoe under the hopper, shaking grain into the eye
    f.rect(cx - 1, 9, cx + 1, 10, TIMBER[3])
    f.put(cx - 1, 9, TIMBER[1])
    f.put(cx, 11, WHEAT[0])
    if step is not None and step % 2:
        f.put(cx, 12, WHEAT[0])
    # the meal spout at the front
    f.rect(13, 24, 17, 28, PIT)
    f.vline(12, 23, 29, TIMBER[0])
    f.vline(18, 23, 29, TIMBER[3])
    f.hline(12, 18, 23, TIMBER[1])
    f.hline(13, 17, 29, TIMBER[2])
    f.pts(FLOUR, (14, 27), (15, 27), (16, 27), (13, 28), (14, 28), (15, 28), (16, 28), (17, 28))
    if step is not None:
        f.pts(FLOUR, (15, 26), (14 + step % 3, 25), (15, 24 + step % 2))
    f.outline()
    f.shadow(2, 31, 30, 31)
    dust = {1: ((14, 30), (17, 31), (11, 30)),
            2: ((13, 31), (16, 30), (19, 30), (10, 29)),
            3: ((15, 31), (20, 29), (12, 30))}.get(step, ())
    for x, y in dust:
        f.put(x, y, FLOUR_DUST)
    return f


# --------------------------------------------------------------- sash saw

SASH_OFFSETS = (0, -2, 0, 2)


def end_log(f, x, y):
    """A 4px round log seen end-on."""
    f.rect(x, y, x + 3, y + 3, TIMBER[3])
    f.rect(x + 1, y + 1, x + 2, y + 2, SAWN[1])
    f.put(x + 1, y + 1, SAWN[0])
    f.pts(TIMBER[2], (x + 1, y), (x, y + 1))
    f.pts(TIMBER[4], (x + 3, y + 2), (x + 2, y + 3))
    for p in ((x, y), (x + 3, y), (x, y + 3), (x + 3, y + 3)):
        f.px.pop(p, None)


def sash_saw(step=None):
    """`step` None is the saw standing with the blade at mid height; 0-3 are
    the working frames."""
    f = Frame()
    off = 0 if step is None else SASH_OFFSETS[step]
    # the rack of logs at the back
    f.vline(24, 7, 13, TIMBER[2])
    f.vline(31, 7, 13, TIMBER[3])
    end_log(f, 24, 10)
    end_log(f, 28, 10)
    end_log(f, 26, 6)
    # the squared log on the bed: sawn top face, front face, shade beneath
    for x in range(2, 28):
        f.put(x, 14, SAWN[0])
        f.put(x, 15, SAWN[0] if grain(x // 3, 1, 8) else SAWN[1])
        f.put(x, 16, SAWN[1])
        for y in range(17, 20):
            f.put(x, y, TIMBER[1] if grain(x // 5, y, 5) else TIMBER[2])
        f.put(x, 20, TIMBER[4])
    f.vline(2, 14, 19, SAWN[0])
    f.vline(27, 17, 19, TIMBER[3])
    f.hline(16, 27, 15, TIMBER[4])               # the kerf behind the blade
    # the sash: head rail, two stiles and the blade strained in it
    top = 5 + off
    for x0 in (10, 18):
        f.vline(x0, top, 20, TIMBER[1])
        f.vline(x0 + 1, top, 20, TIMBER[3])
    f.rect(10, top, 19, top + 1, TIMBER[1])
    f.hline(10, 19, top, TIMBER[0])
    f.hline(11, 19, top + 1, TIMBER[3])
    f.pts(IRON[2], (14, top + 1), (15, top + 1))             # the buckle
    for y in range(top + 2, 16):
        f.put(14, y, GREASE if (y - top) % 4 == 3 else IRON[0])
        f.put(15, y, IRON[1])
        if (y - top) % 2 == 0:
            f.put(13, y, IRON[0])                # teeth, toward the log
    # the fixed frame the sash slides in: fender posts and a head beam
    for x0 in (6, 22):
        f.vline(x0, 2, 20, TIMBER[1] if x0 == 6 else TIMBER[2])
        f.vline(x0 + 1, 2, 20, TIMBER[4])
    f.rect(5, 0, 24, 1, TIMBER[2])
    f.hline(5, 24, 0, TIMBER[0])
    f.hline(6, 24, 1, TIMBER[3])
    f.pts(TIMBER[4], (7, 1), (22, 1))
    # the carriage bed: top of the near rail, its face, the sleepers
    f.rect(0, 21, 31, 22, TIMBER[1])
    f.hline(0, 31, 21, TIMBER[0])
    f.rect(0, 23, 31, 25, TIMBER[3])
    f.hline(0, 31, 25, TIMBER[4])
    for x in range(1, 31):
        if grain(x // 4, 9, 1) == 0:
            f.put(x, 24, TIMBER[2])
    for x in (4, 12, 20, 28):
        f.put(x, 22, IRON[1])                    # the feed rack's pins
    for x0 in (2, 14, 26):
        f.rect(x0, 26, x0 + 3, 28, TIMBER[3])
        f.vline(x0, 26, 28, TIMBER[2])
        f.hline(x0, x0 + 3, 28, TIMBER[4])
    if step == 1:
        f.pts(SAWDUST, (14, 17), (16, 19), (13, 20), (17, 22), (15, 24))
    elif step == 3:
        f.pts(SAWDUST, (15, 17), (13, 18), (16, 20), (12, 22), (15, 23), (17, 24))
    f.outline()
    f.shadow(1, 30, 31, 30)
    return f


def states():
    """[(state, frames)] in sheet order; every state has one direction."""
    on = range(FRAMES_ON)
    return [
        ('millstones', [millstones()]),
        ('millstones_on', [millstones(i) for i in on]),
        ('sash_saw', [sash_saw()]),
        ('sash_saw_on', [sash_saw(i) for i in on]),
    ]


def build_sheet(st):
    frames = [fr for _, group in st for fr in group]
    sheet = Image.new('RGBA', (32 * len(frames), 32), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(fr.image(), (i * 32, 0))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, group in st:
        text += 'state = "%s"\n\tdirs = 1\n\tframes = %d\n' % (name, len(group))
        if len(group) > 1:
            text += '\tdelay = %s\n' % ','.join([str(DELAY_ON)] * len(group))
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


def preview(path, st, scale=4):
    """A row per state at 4x on grass, a frame per column, with the same
    frames at true size beside them."""
    grass = (94, 132, 62, 255)
    pad = 6
    cell = 32 * scale
    cols = max(len(group) for _, group in st)
    sheet = Image.new('RGBA', (pad + cols * (cell + pad) + cols * (32 + pad),
                               pad + len(st) * (cell + pad)), grass)
    for j, (_, group) in enumerate(st):
        y = pad + j * (cell + pad)
        for i, fr in enumerate(group):
            tile = Image.new('RGBA', (32, 32), grass)
            tile.alpha_composite(fr.image())
            sheet.paste(tile.resize((cell, cell), Image.NEAREST), (pad + i * (cell + pad), y))
            sheet.paste(tile, (pad + cols * (cell + pad) + i * (32 + pad), y + (cell - 32) // 2))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


if __name__ == '__main__':
    st = states()
    if '--check' in sys.argv:
        check(SHEET, st)
    else:
        write_dmi(SHEET, st)
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1], st)
