"""Hand-placed 32px art for the two lathes: the wooden pole lathe (a springy
pole, a cord round the work and a treadle) and the iron engine lathe
(headstock with a stepped pulley, chuck, carriage and tailstock on a cast
bed), each with a four-frame working animation. Every pixel is placed by this
script from a fixed palette (Pillow only); no external or generated artwork.

Drawn side on, lit from the upper left, in the timber and iron colours of
icons/obj/workshop_machines.dmi so the lathes sit beside the potter's wheel
and the bellows.

    python3 tests/sprites/create_lathes.py [--preview sheet.png] [--check]

Run with Pillow to reproduce icons/obj/lathes.dmi. `--preview <png>` also
writes a review sheet (each state at 4x, animations as a row of frames).
`--check` writes nothing and fails when the committed sheet differs from what
this script draws.
Released under Civ13 AGPL-3.0.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
DMI = ROOT / 'icons/obj/lathes.dmi'
COLUMNS = 5

OUT = (30, 22, 16)
# timber: lit, face, shade, deep shade, dark
T = [(186, 140, 90), (156, 110, 66), (124, 84, 48), (92, 60, 34), (62, 40, 24)]
# pale new wood on the work and the pole
W = [(226, 196, 146), (200, 164, 112), (164, 128, 82)]
# cord
CORD = [(214, 200, 170), (160, 146, 118)]
# cast iron: glint, lit, face, shade, dark
I = [(176, 182, 194), (128, 132, 144), (84, 88, 100), (50, 52, 64), (32, 34, 42)]
IOUT = (18, 18, 24)
# bright steel work
S = [(244, 246, 250), (200, 206, 216), (150, 156, 170)]
# leather belt on the pulley
BELT = [(150, 100, 58), (104, 66, 38)]
SWARF = (232, 236, 244)
DARK = (30, 32, 36)
FLOORS = ((120, 124, 112), (112, 92, 70))


class Frame:
    def __init__(self):
        self.px = {}

    def put(self, x, y, c):
        if 0 <= x < 32 and 0 <= y < 32:
            self.px[(x, y)] = (c[0], c[1], c[2], 255)

    def pts(self, c, *points):
        for x, y in points:
            self.put(x, y, c)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def box(self, x0, y0, x1, y1, ramp, out):
        """A block ringed with an outline: lit top and left, shaded right and bottom."""
        self.rect(x0, y0, x1, y1, out)
        self.rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, ramp[1])
        if x1 - x0 >= 2 and y1 - y0 >= 2:
            self.rect(x0 + 1, y0 + 1, x1 - 1, y0 + 1, ramp[0])
            self.rect(x1 - 1, y0 + 2, x1 - 1, y1 - 1, ramp[2])
            if y1 - y0 >= 4:
                self.rect(x0 + 1, y1 - 1, x1 - 1, y1 - 1, ramp[2])

    def image(self):
        im = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c)
        return im


# --------------------------------------------------------------- pole lathe

def pole_lathe(frame=None):
    """frame None is at rest; 0..3 is one push of the treadle and its return."""
    f = Frame()
    drop = 0 if frame is None else (0, 1, 2, 1)[frame]
    # the springy pole: fixed to a back post on the left, arching over the bed
    f.box(1, 6, 3, 28, T[1:], OUT)                      # back post
    f.rect(0, 28, 4, 29, OUT)
    pole = ((3, 5), (5, 4), (7, 3), (9, 3), (11, 2), (13, 2), (15, 2), (17, 3), (19, 3))
    tip_y = 4 + drop
    for i, (x, y) in enumerate(pole):
        y += (drop * i) // (len(pole) - 1)
        f.rect(x - 1, y - 1, x + 2, y + 1, OUT)
    for i, (x, y) in enumerate(pole):
        y += (drop * i) // (len(pole) - 1)
        f.pts(W[0], (x, y), (x + 1, y))
    # bed: two rails on two trestle legs
    f.box(6, 18, 29, 21, T, OUT)
    f.rect(7, 20, 28, 20, T[3])
    for x in (8, 25):
        f.box(x, 21, x + 2, 29, T[1:], OUT)
    f.rect(6, 29, 12, 30, OUT)
    f.rect(23, 29, 29, 30, OUT)
    f.rect(7, 29, 11, 29, T[2])
    f.rect(24, 29, 28, 29, T[2])
    # poppets holding the work between two iron centres
    for x in (10, 24):
        f.box(x, 10, x + 3, 18, T, OUT)
    f.pts(I[1], (14, 14), (23, 14))
    # the work: a billet being turned round, a bead already cut near the middle
    f.rect(15, 12, 22, 16, OUT)
    f.rect(15, 13, 22, 15, W[1])
    f.rect(15, 13, 22, 13, W[0])
    f.rect(15, 15, 22, 15, W[2])
    if frame is not None:
        # the grain mark runs round the billet as it turns back and forth
        mark = (13, 14, 15, 14)[frame]
        f.pts(T[2], (16, mark), (21, mark))
    f.pts(OUT, (20, 12), (20, 16))
    f.pts(W[2], (20, 13), (20, 14), (20, 15))
    # the cord: from the pole tip, a turn round the work, down to the treadle
    for y in range(tip_y + 1, 12):
        f.put(18, y, CORD[0])
    f.pts(CORD[1], (18, 12), (18, 16))
    f.pts(CORD[0], (18, 13), (18, 14), (18, 15))
    treadle_y = 25 + drop
    for y in range(22, treadle_y):
        f.put(18, y, CORD[0])
    # treadle: a board hinged at the right leg
    for x in range(13, 25):
        y = treadle_y + ((x - 13) * (27 - treadle_y)) // 11
        f.put(x, y, OUT)
        f.put(x, y + 1, T[0] if x < 20 else T[1])
        f.put(x, y + 2, OUT)
    # tool rest in front of the work
    f.rect(15, 17, 22, 17, T[0])
    return f


# ------------------------------------------------------------- engine lathe

def engine_lathe(frame=None):
    f = Frame()
    # cast legs and the tray between them
    for x in (3, 24):
        f.box(x, 21, x + 4, 29, I[1:], IOUT)
        f.pts(I[3], (x + 2, 24), (x + 2, 25), (x + 2, 26))
    f.rect(2, 29, 8, 30, IOUT)
    f.rect(23, 29, 29, 30, IOUT)
    f.rect(8, 25, 23, 25, IOUT)
    f.rect(8, 26, 23, 26, I[3])
    f.rect(8, 27, 23, 27, IOUT)
    # bed with its ways and the lead screw under the front edge
    f.box(1, 17, 30, 21, I[1:], IOUT)
    f.rect(2, 18, 29, 18, I[0])
    for x in range(9, 29, 2):
        f.put(x, 20, I[4])                              # lead screw thread
    # headstock: a tall casting on the left, stepped pulley on its spindle
    f.box(1, 7, 9, 17, I[1:], IOUT)
    f.rect(2, 8, 8, 8, I[0])
    f.rect(3, 3, 7, 7, IOUT)                            # stepped cone pulley
    f.rect(4, 4, 6, 6, I[2])
    f.rect(4, 4, 6, 4, I[1])
    f.rect(2, 5, 8, 7, IOUT)
    f.rect(3, 6, 7, 6, I[2])
    # the belt coming down from the line shaft
    for y in range(0, 4):
        f.pts(BELT[0], (4, y))
        f.pts(BELT[1], (6, y))
    if frame is not None:
        # a lacing mark travels down the belt
        f.put(4, frame, BELT[1])
        f.put(6, 3 - frame, BELT[0])
    # chuck on the spindle nose
    f.rect(10, 9, 12, 15, IOUT)
    f.rect(10, 10, 11, 14, I[1])
    f.rect(11, 10, 11, 14, I[2])
    if frame is not None:
        jaw = (10, 11, 13, 14)[frame]
        f.pts(I[0], (10, jaw), (11, jaw))
    else:
        f.pts(I[0], (10, 11), (11, 11))
    # the work: a bright bar held by the chuck and the tailstock centre
    f.rect(13, 11, 23, 13, IOUT)
    f.rect(13, 12, 23, 12, S[1])
    f.rect(13, 11, 18, 11, IOUT)
    f.rect(13, 12, 17, 12, S[0])                        # the turned, brighter length
    if frame is not None:
        f.put(19 + frame, 12, S[0])                     # glint running along the bar
    # carriage and tool post riding the ways
    f.box(15, 14, 21, 17, I, IOUT)
    f.box(17, 12, 19, 14, I[1:], IOUT)
    f.pts(S[0], (17, 13))                               # the tool bit at the work
    f.rect(16, 21, 18, 23, IOUT)                        # apron handwheel
    f.pts(I[0], (17, 22))
    if frame is not None and frame % 2 == 0:
        f.pts(SWARF, (16, 10 - frame // 2), (15, 9 + frame // 2))
    # tailstock
    f.box(24, 9, 29, 17, I[1:], IOUT)
    f.rect(23, 11, 24, 13, IOUT)
    f.pts(I[0], (23, 12))
    f.rect(30, 11, 31, 13, IOUT)                        # its handwheel, edge on
    f.pts(I[1], (30, 12))
    return f


def build():
    """name -> (frames, delays); delays is None for a still state."""
    return {
        'pole_lathe': ([pole_lathe()], None),
        'pole_lathe_on': ([pole_lathe(i) for i in range(4)], (2, 2, 2, 2)),
        'engine_lathe': ([engine_lathe()], None),
        'engine_lathe_on': ([engine_lathe(i) for i in range(4)], (1, 1, 1, 1)),
    }


def render(states):
    frames = [fr for group, _ in states.values() for fr in group]
    rows = -(-len(frames) // COLUMNS)
    sheet = Image.new('RGBA', (32 * COLUMNS, 32 * rows), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(fr.image(), (i % COLUMNS * 32, i // COLUMNS * 32))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, (group, delays) in states.items():
        text += 'state = "%s"\n\tdirs = 1\n\tframes = %d\n' % (name, len(group))
        if delays:
            text += '\tdelay = %s\n' % ','.join(str(d) for d in delays)
    text += '# END DMI\n'
    return sheet, text


def write_dmi(path, states):
    sheet, text = render(states)
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta)


def check(path, states):
    sheet, text = render(states)
    if not Path(path).is_file():
        return ['%s is missing' % path]
    with Image.open(path) as im:
        have_text = im.info.get('Description', '')
        have = im.convert('RGBA')
    problems = []
    if have_text != text:
        problems.append('state metadata differs')
    if have.size != sheet.size or have.tobytes() != sheet.tobytes():
        problems.append('pixels differ')
    return problems


def write_preview(path, states, scale=4):
    cell, pad, label = 32 * scale, 8, 14
    wide = max(len(group) for group, _ in states.values())
    sheet = Image.new('RGBA', ((cell + pad) * wide + pad, (cell + label + pad) * len(states) + pad),
                      DARK + (255,))
    draw = ImageDraw.Draw(sheet)
    for j, (name, (group, _)) in enumerate(states.items()):
        oy = pad + j * (cell + label + pad)
        draw.text((pad, oy), name, fill=(232, 228, 214))
        for i, fr in enumerate(group):
            tile = Image.new('RGBA', (32, 32), FLOORS[i % 2] + (255,))
            tile.alpha_composite(fr.image())
            sheet.alpha_composite(tile.resize((cell, cell), Image.NEAREST), (pad + i * (cell + pad), oy + label))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.convert('RGB').save(path)


def main():
    states = build()
    if '--check' in sys.argv:
        problems = check(DMI, states)
        for p in problems:
            print('lathes.dmi: ' + p)
        if problems:
            sys.exit(1)
        print('lathes.dmi matches (%d states, %d frames)'
              % (len(states), sum(len(g) for g, _ in states.values())))
    else:
        write_dmi(DMI, states)
    if '--preview' in sys.argv[1:-1]:
        write_preview(sys.argv[sys.argv.index('--preview') + 1], states)


if __name__ == '__main__':
    main()
