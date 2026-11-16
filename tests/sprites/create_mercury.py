"""Hand-placed sprites for quicksilver in icons/obj/mercury.dmi: the wrought
iron mercury flask (open and empty, stoppered and full), the cinnabar retort
(an iron retort on a brick firebox with its condenser arm and receiver: cold,
a four-frame firing loop and the cracked, leaking retort) and the mercury
vapour effect (a four-frame loop of rising wisps). Every pixel is placed by
this script from a fixed palette (Pillow only); no external or generated
artwork. The iron is the blue-grey of the anvils in icons/obj/metallurgy.dmi,
the brick is the bloomery clay used by create_tatara.py and the fire colours
are those of create_clay_lime_fire.py.

Run with Pillow to write the sheet. `--check` verifies the committed sheet,
`--preview <png>` writes a labelled 4x review sheet on grass and on dirt,
`--gif <path>` writes the firing loop.
Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_clay_lime_fire import FIRE, grain  # noqa: E402
from create_tatara import Sprite, CLAY, HOLE, CHAR, EMBER, GRASS, DIRT, ground  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/mercury.dmi'

SIZE = 32
FIRE_DELAY = 1         # deciseconds per frame, as bloomery_on
FIRE_FRAMES = 4
VAPOUR_DELAY = 2
VAPOUR_FRAMES = 4

# wrought iron: sheen, light, mid, dark, deep
IRON = [(150, 156, 168), (108, 114, 126), (80, 86, 96), (58, 62, 72), (40, 43, 52)]
IRON_EDGE = (18, 19, 24)
# quicksilver: glint, bright, shade
QUICK = [(250, 252, 255), (202, 210, 222), (138, 148, 166)]
# paper tag: lit, shade, ink; and its string
TAG = [(226, 212, 172), (190, 172, 132), (84, 66, 48)]
STRING = (150, 124, 84)
ASH = [(150, 146, 140), (112, 108, 104)]
# iron heated from below: dull red, darker
HOT = [(164, 74, 44), (118, 52, 44)]
GLOW = (232, 150, 86)                    # brick lit from within
# mercury fume and heat haze, drawn with their own alpha
FUME = [(222, 228, 236), (188, 196, 208)]


def tone(c, step, ramp=IRON):
    """The colour step places down (or up) the ramp from c."""
    return ramp[max(0, min(len(ramp) - 1, ramp.index(c) + step))]


# ---------------------------------------------------------------- flask --

FLASK_ROWS = [(12, 13, 18), (13, 11, 20)] + [(y, 10, 21) for y in range(14, 26)] + [(26, 11, 20)]


def flask_body(f):
    """The squat wrought iron bottle, lit from the upper left, with its
    short neck and thick lip; the mouth is left to the caller."""
    for y, x0, x1 in FLASK_ROWS:
        for x in range(x0, x1 + 1):
            c = IRON[(2, 1, 0, 1, 2, 2, 2, 2, 3, 3, 4, 4)[x - 10]]
            if x == 12 and (y < 15 or y > 21):
                c = IRON[1]                   # the sheen is a short streak
            if y == 12:
                c = IRON[1] if x < 17 else IRON[2]
            if grain(x, y, 141) == 0:
                c = tone(c, 1)                # hammer marks
            if y == 23:
                c = tone(c, 1)                # the welded foot seam
            if y == 26:
                c = tone(c, 1)
            f.put(x, y, c)
    f.hline(14, 17, 11, IRON[2])              # neck
    f.put(14, 11, IRON[1])
    f.put(17, 11, IRON[3])
    f.hline(13, 18, 10, IRON[1])              # lip
    f.put(13, 10, IRON[0])
    f.pts(IRON[3], (17, 10), (18, 10))


def flask():
    """Empty: the mouth open and the threaded stopper lying at the foot."""
    f = Sprite()
    flask_body(f)
    f.hline(14, 17, 9, IRON[1])               # far side of the open mouth
    f.hline(14, 17, 10, HOLE)
    f.pts(IRON_EDGE, (15, 10), (16, 10))
    # the stopper: a square head and a threaded shank
    f.rect(23, 24, 25, 26, IRON[2])
    f.hline(23, 25, 24, IRON[1])
    f.put(23, 24, IRON[0])
    f.hline(23, 25, 26, IRON[3])
    f.pts(IRON[1], (26, 25), (28, 25))
    f.pts(IRON[3], (27, 25), (26, 26), (28, 26))
    f.put(27, 26, IRON[4])
    f.outline(IRON_EDGE)
    return f


def flask_full():
    """Full: stoppered, a bead of quicksilver on the lip and a paper tag."""
    f = Sprite()
    flask_body(f)
    f.hline(14, 17, 9, IRON[2])               # the stopper's flange
    f.put(14, 9, IRON[1])
    f.rect(14, 7, 17, 8, IRON[2])             # and its square head
    f.hline(14, 16, 7, IRON[1])
    f.put(14, 7, IRON[0])
    f.pts(IRON[3], (17, 7), (17, 8), (17, 9))
    # the tag, tied round the neck
    f.pts(STRING, (18, 11), (19, 12), (20, 13))
    f.rect(19, 14, 22, 18, TAG[0])
    f.vline(22, 14, 18, TAG[1])
    f.hline(19, 22, 18, TAG[1])
    f.pts(TAG[2], (20, 15), (21, 15), (20, 17))
    f.outline(IRON_EDGE)
    # the bead, bright against the iron
    f.put(13, 10, QUICK[1])
    f.put(12, 10, QUICK[0])
    f.put(12, 11, QUICK[1])
    f.put(13, 11, QUICK[2])
    return f


# --------------------------------------------------------------- retort --

BANDS = (8, 14)                      # hoops round the retort body
MOUTH = (8, 12)                      # the firebox opening, first and last column
CRACK = ((11, 8), (11, 9), (12, 10), (11, 11), (11, 12), (12, 13), (12, 14), (13, 15))


def firebox(f, lit=None):
    """A low brick box with an arched stoke hole in its front."""
    for y in range(17, 29):
        for x in range(4, 18):
            c = CLAY[1] if x < 15 else CLAY[2]
            course = (y - 17) // 3
            if y == 17:
                c = CLAY[0]                   # the lit top course
            elif (y - 17) % 3 == 0 or (x + course * 3) % 6 == 0:
                c = CLAY[3]                   # mortar joints
            elif grain(x, y, 143) == 0:
                c = CLAY[2]
            if x == 17:
                c = CLAY[3]
            if y == 28:
                c = tone(c, 1, CLAY)
            f.put(x, y, c)
    x0, x1 = MOUTH
    f.hline(x0, x1, 21, CLAY[0] if lit is None else GLOW)      # arch
    f.pts(CLAY[0] if lit is None else GLOW, (x0 - 1, 22), (x1 + 1, 22))
    f.vline(x0 - 2, 23, 28, CLAY[1] if lit is None else CLAY[0])
    f.vline(x1 + 2, 23, 28, CLAY[3])
    f.hline(x0, x1, 22, HOLE)
    f.rect(x0 - 1, 23, x1 + 1, 28, HOLE)
    if lit is None:                           # cold: charcoal and ash
        f.pts(CHAR[1], (8, 27), (9, 27), (11, 27), (12, 28), (8, 28))
        f.pts(CHAR[0], (9, 26), (11, 28))
        f.pts(ASH[1], (10, 28), (13, 28), (7, 28))
        f.pts(ASH[0], (9, 28),)
        return
    k = lit % FIRE_FRAMES
    for x in range(x0 - 1, x1 + 2):
        h = 2.6 + 1.6 * math.sin(x * 1.3 + k * math.pi / 2.0) + 1.0 * math.sin(x * 2.1 - k * math.pi)
        h = max(1.0, min(5.0, h + (1.0 if x0 <= x <= x1 else 0.0)))
        for y in range(28, 28 - int(round(h)) - 1, -1):
            t = (28 - y) / (h + 0.01)
            f.put(x, y, FIRE[0] if t < 0.3 else (FIRE[1] if t < 0.6 else (FIRE[2] if t < 0.85 else FIRE[3])))
    f.pts(FIRE[3], (x0 + (k * 2) % 5, 22))    # a tongue licking the arch


def retort_body(f, lit=None):
    """The iron retort lying along the top of the firebox: a hooped
    cylinder with a wedged lid at the left and the condenser arm leaving
    the right end, sloping down into the receiver."""
    shade = (1, 0, 1, 1, 2, 2, 2, 3, 3, 4)        # rows 8..17
    for y in range(8, 18):
        for x in range(3, 21):
            inset = (2, 1, 0, 0, 0, 0, 0, 0, 1, 2)[y - 8]
            if x < 3 + inset or x > 19 - inset + (1 if 10 <= y <= 14 else 0):
                continue                          # rounded ends, the far one domed
            c = IRON[shade[y - 8]]
            if y == 9 and (x < 5 or grain(x, 0, 145) < 3):
                c = IRON[1]                       # the sheen breaks up
            if x in BANDS:
                c = tone(c, 1)
            elif x - 1 in BANDS:
                c = tone(c, -1) if y < 13 else c
            elif grain(x, y, 147) == 0:
                c = tone(c, 1)
            if x >= 19:
                c = tone(c, 1)
            f.put(x, y, c)
    # the lid: a flange and a lugged plate, wedged shut
    for y in range(10, 16):
        f.put(3, y, tone(IRON[shade[y - 8]], -1))
    f.vline(2, 10, 15, IRON[2])
    f.put(2, 10, IRON[1])
    f.vline(1, 12, 13, IRON[3])
    if lit is not None:                           # the belly heated from below
        k = lit % FIRE_FRAMES
        for x in range(6, 17):
            f.put(x, 17, HOT[0] if (x + k) % 4 else GLOW)
            f.put(x, 16, HOT[1] if grain(x, k, 149) > 2 else HOT[0])
    # condenser arm
    for i in range(8):
        x, y = 20 + i, 10 + (i * 5 + 2) // 4
        f.put(x, y, IRON[1] if i % 3 else IRON[0])
        f.put(x, y + 1, IRON[3])
    f.pts(IRON[2], (20, 10), (27, 20))
    f.vline(26, 20, 22, IRON[1])                  # the spout, into the receiver
    f.vline(27, 20, 22, IRON[3])


def receiver(f, lit=None):
    """A small iron pot of water that the arm drips into."""
    for y in range(23, 29):
        for x in range(22, 31):
            if y == 28 and x in (22, 30):
                continue
            c = IRON[(1, 0, 1, 2, 2, 2, 3, 3, 4)[x - 22]]
            if y == 23:
                c = IRON[1] if x < 28 else IRON[2]    # rim
            elif y == 24:
                c = tone(c, 1)                        # shade under the rim
            elif grain(x, y, 151) == 0:
                c = tone(c, 1)
            if y == 28:
                c = tone(c, 1)
            f.put(x, y, c)
    f.hline(23, 29, 22, IRON[2])                      # far rim
    f.hline(23, 29, 23, HOLE)                         # the dark water
    f.pts(IRON[1], (22, 23), (30, 23))
    f.pts(IRON[1], (26, 22),)
    f.pts(IRON[3], (27, 22), (27, 23))
    f.put(26, 23, IRON[2])
    if lit is not None:                               # quicksilver gathering
        k = lit % FIRE_FRAMES
        f.pts(QUICK[2], (24, 23), (29, 23))
        f.put(25 if k < 2 else 28, 23, QUICK[1])
        if k % 2:
            f.put(28 if k == 1 else 24, 23, QUICK[0])


def retort_base(lit=None):
    f = Sprite()
    firebox(f, lit)
    retort_body(f, lit)
    receiver(f, lit)
    f.outline(IRON_EDGE)
    return f


def retort():
    return retort_base()


def retort_fired(step):
    """Fire in the stoke hole, the belly glowing and heat haze above."""
    k = step % FIRE_FRAMES
    f = retort_base(lit=k)
    # firelight on the ground before the hole
    for x in range(6, 15):
        if (x + k) % 3:
            f.put(x, 30, FIRE[2] + (120,))
    f.put(8 + k, 29, FIRE[1] + (255,))
    f.put(12 - k, 29, FIRE[2] + (255,))
    # haze: short pale strokes that climb a pixel a frame and fade
    for i, (sx, sy) in enumerate(((5, 6), (9, 5), (13, 6), (17, 5), (7, 3), (15, 3), (11, 2))):
        phase = (k + i) % FIRE_FRAMES
        x = sx + (0, 1, 0, -1)[(phase + i) % 4]
        y = sy - phase
        a = (110, 85, 60, 35)[phase]
        f.put(x, y, FUME[0] + (a,))
        f.put(x, y + 1, FUME[1] + (a * 2 // 3,))
    return f


def retort_cracked():
    """Cold, the body split across a hoop and a thin fume leaking out."""
    f = retort_base()
    for i, (x, y) in enumerate(CRACK):
        f.put(x, y, IRON_EDGE)
        if i % 3 == 1:
            f.put(x - 1, y, IRON[0])              # the raw lip of the split
    f.pts(IRON_EDGE, (10, 10), (13, 12), (13, 13), (10, 12))
    f.pts(HOT[1], (12, 11), (13, 14))             # rust at the break
    wisp = ((11, 7, 235), (11, 6, 225), (12, 5, 210), (12, 4, 195), (11, 3, 175),
            (10, 2, 150), (10, 1, 120), (11, 0, 90), (12, 6, 150), (13, 4, 120),
            (10, 3, 110), (9, 1, 70))
    for x, y, a in wisp:
        f.put(x, y, (FUME[0] if a > 160 else FUME[1]) + (a,))
    return f


# --------------------------------------------------------------- vapour --

STRANDS = ((11.5, 0.0, 28, 17), (15.5, 2.1, 29, 19), (19.5, 4.2, 27, 16))   # x, phase, foot, height


def vapour(step):
    """Three thin strands that sway and climb, fading as they rise; the
    breaks in each strand travel up two pixels a frame."""
    f = Sprite()
    k = step % VAPOUR_FRAMES
    for n, (cx, ph, foot, height) in enumerate(STRANDS):
        for d in range(height):
            y = foot - d
            if (d - 2 * k + n * 3) % 8 >= 6:
                continue                          # a break in the strand
            sway = math.sin(d * 0.55 + ph + k * math.pi / 2.0)
            x = int(round(cx + sway * (0.6 + d * 0.11)))
            fade = 1.0 - d / float(height)
            a = int(40 + 120 * fade)
            f.put(x, y, FUME[0] + (a,))
            side = x + (1 if sway > 0 else -1)
            if (d + k + n) % 3 == 0 and (side, y) not in f.px:
                f.put(side, y, FUME[1] + (a // 2,))
    return f


def states():
    """[(state, frames, delay)] in sheet order."""
    return [
        ('flask', [flask()], 0),
        ('flask_full', [flask_full()], 0),
        ('retort', [retort()], 0),
        ('retort_fired', [retort_fired(i) for i in range(FIRE_FRAMES)], FIRE_DELAY),
        ('retort_cracked', [retort_cracked()], 0),
        ('vapour', [vapour(i) for i in range(VAPOUR_FRAMES)], VAPOUR_DELAY),
    ]


# --------------------------------------------------------- sheet in/out --

def build():
    blocks, frames = [], []
    for name, frs, delay in states():
        block = 'state = "%s"\n\tdirs = 1\n\tframes = %d\n' % (name, len(frs))
        if len(frs) > 1:
            block += '\tdelay = %s\n' % ','.join([str(delay)] * len(frs))
        blocks.append(block)
        frames += [fr.image() for fr in frs]
    cols = int(len(frames) ** 0.5 + 0.999)
    rows = (len(frames) + cols - 1) // cols
    im = Image.new('RGBA', (cols * SIZE, rows * SIZE))
    for i, fr in enumerate(frames):
        im.paste(fr, ((i % cols) * SIZE, (i // cols) * SIZE))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    text += ''.join(blocks) + '# END DMI\n'
    return im, text


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


# -------------------------------------------------------------- review --

def preview(path, scale=4):
    """Every frame, labelled, on grass (upper block) and dirt (lower)."""
    cells = []
    for name, frs, _ in states():
        for i, fr in enumerate(frs):
            cells.append((name if len(frs) == 1 else '%s [%d]' % (name, i + 1), fr.image()))
    cols, pad, label = 6, 8, 14
    rows = (len(cells) + cols - 1) // cols
    cw, ch = SIZE * scale + pad, SIZE * scale + label + pad
    out = Image.new('RGBA', (pad + cols * cw, pad + 2 * rows * ch), (24, 24, 24, 255))
    pen = ImageDraw.Draw(out)
    for j, tones in enumerate((GRASS, DIRT)):
        back = ground(tones, scale)
        for i, (name, im) in enumerate(cells):
            x, y = pad + (i % cols) * cw, pad + (j * rows + i // cols) * ch
            tile = back.copy()
            tile.alpha_composite(im.resize((SIZE * scale, SIZE * scale), Image.NEAREST))
            out.paste(tile, (x, y))
            pen.text((x + 1, y + SIZE * scale + 1), name, fill=(230, 230, 230, 255))
    out.save(path)


def gif(path, scale=6):
    """The firing loop on grass at game speed."""
    back = ground(GRASS, scale)
    shots = []
    for fr in dict((n, f) for n, f, _ in states())['retort_fired']:
        tile = back.copy()
        tile.alpha_composite(fr.image().resize((SIZE * scale, SIZE * scale), Image.NEAREST))
        shots.append(tile.convert('RGB'))
    shots[0].save(path, save_all=True, append_images=shots[1:], duration=FIRE_DELAY * 100, loop=0)


if __name__ == '__main__':
    if '--check' in sys.argv:
        if not check():
            sys.exit('stale sheet: ' + str(SHEET))
        print('mercury states match')
    else:
        write_dmi()
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
    if '--gif' in sys.argv:
        gif(sys.argv[sys.argv.index('--gif') + 1])
