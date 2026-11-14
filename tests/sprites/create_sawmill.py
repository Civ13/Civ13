"""Hand-placed saw mill sprites: the primitive spring-pole mill (32x32) in
icons/obj/plankage.dmi and the hand-cranked large mill and the electric
powered mill (64x32) in icons/obj/plankage_64.dmi, each with its idle frame
and its looping cutting animation. Every pixel is placed by this script from
a fixed palette (Pillow only); no external or generated artwork.

Run with Pillow to reproduce both sheets. `--check` verifies the committed
sheets match, `--preview <png>` writes an enlarged review sheet and
`--gif <gif>` a looping review animation. Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SMALL = ROOT / 'icons/obj/plankage.dmi'
WIDE = ROOT / 'icons/obj/plankage_64.dmi'

OUT = (30, 22, 16)
UNDER = (44, 30, 22)
# seasoned bench timber: highlight, light, mid, dark, deep
TIMBER = [(186, 140, 90), (156, 110, 66), (124, 84, 48), (92, 60, 34), (62, 40, 24)]
# peeled pole: light, mid, dark
POLE = [(204, 170, 116), (166, 130, 82), (114, 84, 50)]
# log bark: highlight, light, mid, dark
BARK = [(142, 104, 68), (114, 80, 50), (88, 60, 38), (62, 42, 28)]
# fresh sawn wood: highlight, light, mid, shade
SAWN = [(244, 216, 160), (224, 190, 130), (196, 158, 100), (158, 120, 72)]
# knapped flint: highlight, light, mid, dark
FLINT = [(196, 200, 204), (128, 132, 142), (82, 84, 96), (46, 46, 58)]
# saw steel: glint, light, mid, dark, outline
STEEL = [(240, 244, 248), (194, 202, 212), (144, 154, 168), (96, 104, 120), (42, 46, 58)]
# wrought iron: highlight, mid, dark
IRON = [(128, 132, 144), (84, 88, 100), (50, 52, 64)]
# leather drive belt: light, dark
BELT = [(170, 120, 72), (108, 72, 42)]
# rawhide cord: light, dark
CORD = [(228, 212, 168), (156, 138, 98)]
# sawdust: light, dark
DUST = [(240, 218, 164), (206, 178, 122)]
# painted motor housing: highlight, light, mid, dark
PAINT = [(110, 150, 132), (74, 116, 102), (50, 86, 78), (32, 58, 56)]
COPPER = [(232, 150, 84), (176, 100, 52)]
LAMP_ON = [(255, 240, 150), (240, 180, 50)]
LAMP_OFF = [(96, 70, 40), (62, 44, 28)]


class Frame:
    def __init__(self, w=32, h=32):
        self.w, self.h, self.px = w, h, {}

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[(x, y)] = c

    def pts(self, c, *points):
        for x, y in points:
            self.put(x, y, c)

    def hline(self, x0, x1, y, c):
        for x in range(x0, x1 + 1):
            self.put(x, y, c)

    def vline(self, x, y0, y1, c):
        for y in range(y0, y1 + 1):
            self.put(x, y, c)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            self.hline(x0, x1, y, c)

    def rows(self, top, left, art, key):
        """Stamp ASCII art: each character is looked up in key, '.' is clear."""
        for dy, row in enumerate(art):
            for dx, ch in enumerate(row):
                if ch != '.':
                    self.put(left + dx, top + dy, key[ch])

    def outline(self, c=OUT):
        """Trace every still-clear pixel that touches a drawn one."""
        edge = set()
        for (x, y) in self.px:
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if (nx, ny) not in self.px:
                    edge.add((nx, ny))
        for x, y in edge:
            self.put(x, y, c)

    def image(self):
        im = Image.new('RGBA', (self.w, self.h))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c + (255,))
        return im


def streak(x, y, seed=0):
    """Grain that runs along the board in short streaks rather than specks."""
    return grain((x + y * 5) // 3, y, seed)


def grain(x, y, seed=0):
    """A fixed pseudo-random speckle, so wood grain is the same every run."""
    v = (x * 73856093) ^ (y * 19349663) ^ (seed * 83492791)
    return (v >> 3) % 11


# ---------------------------------------------------------------- logs --

def log_piece(f, left, right, top, rows, clip_lo, clip_hi, seed=1):
    """An uncut log lying on the bench between x=left..right, drawn only
    where clip_lo <= x <= clip_hi. Bark on the side, pale end grain caps."""
    for x in range(max(left, clip_lo), min(right, clip_hi) + 1):
        cap = x in (left, right)
        for i in range(rows):
            y = top + i
            if cap:
                if i in (0, rows - 1):
                    continue
                c = SAWN[2] if i in (1, rows - 2) else SAWN[1]
                if i == rows // 2 and rows > 4:
                    c = SAWN[3]
            else:
                # round shading: lit shoulder near the top, dark belly
                t = i / (rows - 1)
                c = BARK[1] if t < 0.2 else BARK[0] if t < 0.4 else BARK[1] if t < 0.65 else BARK[2] if t < 0.9 else BARK[3]
                g = grain(x - left, i, seed)
                if g == 0 and 0 < i < rows - 1:
                    c = BARK[3]
                elif g == 1 and i < rows - 2:
                    c = BARK[0]
            f.put(x, y, c)


def plank_piece(f, left, right, top, rows, clip_lo, clip_hi, bark_top=False, lift=0, origin=0):
    """A sawn board: pale face with a lit top edge and a shaded underside.
    bark_top keeps the bark on its upper edge (the outer slab of the log).
    lift raises the board a pixel once it is clear of the blade."""
    for x in range(max(left, clip_lo), min(right, clip_hi) + 1):
        up = lift if x - origin > 3 else 0
        for i in range(rows):
            y = top + i - up
            if i == 0:
                c = BARK[1] if bark_top else SAWN[0]
            elif i == rows - 1:
                c = SAWN[3]
            else:
                c = SAWN[1] if grain(x - left, i, 5) else SAWN[2]
            if x == right and 0 < i < rows - 1:
                c = SAWN[0]
            f.put(x, y, c)


def dust_spray(f, x, y, step, reach=4):
    """A few chips thrown back from the cut; the pattern cycles every 4 frames."""
    spots = (((-1, -1), (-3, 0), (-2, 2)), ((-2, -2), (-4, 1), (-1, 1)),
             ((-1, 0), (-3, -1), (-4, 2)), ((-2, 0), (-1, 2), (-3, 3)))[step % 4]
    for i, (dx, dy) in enumerate(spots):
        if -dx <= reach:
            f.put(x + dx, y + dy, DUST[i % 2])


# ------------------------------------------------------ primitive mill --

def primitive(step=None):
    """The primitive mill: a split-log bench on peg legs, a flint-toothed
    blade standing in a slot, and a springy sapling that lifts the blade
    after each stroke. step is the animation frame, or None when idle."""
    f = Frame(32, 32)
    stroke = 0 if step is None else (0, 1, 2, 1)[step % 4]
    bend = 1 if stroke == 2 else 0

    # spring pole: an upright stake behind the bench and a bent sapling
    f.vline(5, 7, 18, POLE[1])
    f.vline(6, 7, 18, POLE[2])
    f.pts(POLE[0], (5, 8), (5, 11), (5, 14))
    arc = ((6, 6), (7, 5), (8, 4), (9, 4), (10, 3), (11, 3), (12, 3), (13, 3), (14, 4), (15, 4), (16, 5))
    for i, (x, y) in enumerate(arc):
        y += bend if i >= 6 else 0
        f.put(x, y, POLE[0] if i % 3 else POLE[1])
        f.put(x, y + 1, POLE[2])
    # lashing that ties sapling to stake
    f.pts(CORD[0], (5, 7), (6, 6), (5, 9))
    f.pts(CORD[1], (6, 7), (6, 9))

    # peg legs, splayed, and the stretcher between them
    for i, y in enumerate(range(25, 31)):
        lx = 6 - (i + 1) // 3
        rx = 24 + (i + 1) // 3
        f.pts(TIMBER[2], (lx, y), (rx, y))
        f.pts(TIMBER[3], (lx + 1, y), (rx + 1, y))
        f.pts(TIMBER[4], (lx + 2, y), (rx + 2, y))
    f.hline(8, 23, 27, TIMBER[3])
    f.hline(8, 23, 28, TIMBER[4])
    f.pts(CORD[0], (8, 27), (23, 27))
    f.pts(CORD[1], (8, 28), (23, 28))

    # bench: a log split in half, flat face up
    f.hline(4, 27, 18, TIMBER[0])
    for y in (19, 20):
        for x in range(3, 29):
            f.put(x, y, TIMBER[2] if streak(x, y, 2) < 2 else TIMBER[1])
    f.hline(3, 28, 21, TIMBER[2])
    for y, ramp in ((22, 2), (23, 3), (24, 3)):
        for x in range(3 + (y == 24), 29 - (y == 24)):
            c = TIMBER[ramp]
            if streak(x, y, 4) == 0:
                c = TIMBER[4]
            f.put(x, y, c)
    # growth rings on the split ends
    f.pts(SAWN[2], (3, 22), (28, 22))
    f.pts(SAWN[3], (3, 23), (28, 23))
    # blade slot
    f.hline(14, 18, 20, TIMBER[4])
    f.hline(15, 17, 19, TIMBER[3])

    # the log, the board and the bark slab
    if step is not None:
        left = -16 + (step * 47) // 32
        right = left + 15
        log_piece(f, left, right, 13, 5, 0, 15, seed=3)
        plank_piece(f, left, right, 15, 3, 18, 31, origin=18)
        plank_piece(f, left, right, 12, 2, 18, 31, bark_top=True, lift=1, origin=18)
        cutting = left <= 16 <= right
    else:
        cutting = False

    # sawdust under the bench, a little more while cutting
    f.rows(29, 12, ['..ab..', '.abab.'], {'a': DUST[0], 'b': DUST[1]})
    if cutting:
        f.pts(DUST[0], (13, 28), (16, 28))
        dust_spray(f, 15, 14, step)

    # blade: flint flakes set in a wooden slat, teeth toward the log
    top = 8 + stroke
    f.rect(15, top, 18, top + 1, POLE[1])
    f.hline(15, 18, top, POLE[0])
    f.put(18, top + 1, POLE[2])
    for y in range(top + 2, 20):
        f.put(17, y, FLINT[2])
        f.put(18, y, FLINT[3])
        tooth = (y - top) % 2 == 0
        f.put(16, y, FLINT[0] if tooth else FLINT[1])
        if tooth:
            f.put(15, y, FLINT[1])
    # cord from the sapling tip to the blade
    for y in range(6 + bend, top):
        f.put(16, y, CORD[0] if y % 2 else CORD[1])

    f.outline()
    return f


# ---------------------------------------------------------- wide mills --

def table(f, iron_frame=False):
    """The shared 64x32 saw bench: plank top, back fence, apron and legs."""
    # rip fence along the back edge
    f.hline(12, 51, 12, TIMBER[0])
    f.hline(12, 51, 13, TIMBER[2])
    f.pts(IRON[1], (12, 12), (12, 13), (51, 12), (51, 13))
    # top: three boards laid lengthwise, lit along the front lip
    f.hline(10, 53, 14, TIMBER[1])
    for y in range(15, 19):
        for x in range(10, 54):
            f.put(x, y, TIMBER[2] if streak(x, y, 7) < 2 else TIMBER[1])
    for x in range(10, 54):
        if grain(x // 5, 16, 9) > 1:
            f.put(x, 16, TIMBER[2])
    f.hline(10, 53, 19, TIMBER[0])
    # apron, a shade darker than the top, with butt joints near the ends
    for y in range(20, 24):
        for x in range(10, 54):
            f.put(x, y, TIMBER[4] if streak(x, y, 11) == 0 else TIMBER[3])
    f.hline(10, 53, 23, TIMBER[4])
    f.vline(16, 20, 23, TIMBER[4])
    f.vline(47, 20, 23, TIMBER[4])
    # shadow under the bench
    f.rect(15, 24, 48, 26, UNDER)
    # legs and stretcher
    leg = IRON if iron_frame else None
    for x0 in (11, 49):
        for y in range(24, 31):
            if leg:
                f.pts(leg[0], (x0, y))
                f.pts(leg[1], (x0 + 1, y), (x0 + 2, y))
                f.pts(leg[2], (x0 + 3, y))
            else:
                f.pts(TIMBER[1], (x0, y))
                f.pts(TIMBER[2], (x0 + 1, y), (x0 + 2, y))
                f.pts(TIMBER[4], (x0 + 3, y))
    f.hline(15, 48, 27, IRON[1] if iron_frame else TIMBER[3])
    f.hline(15, 48, 28, IRON[2] if iron_frame else TIMBER[4])
    # iron corner straps with a rivet each
    for x0 in (10, 52):
        f.rect(x0, 20, x0 + 1, 23, IRON[1])
        f.vline(x0 + (0 if x0 == 10 else 1), 20, 23, IRON[2])
    f.pts(IRON[0], (11, 21), (52, 21))


def blade(f, cx, cy, r, spin=None):
    """The upper half of a circular saw blade standing out of the table.
    spin steps the teeth and the glints round; None is a blade at rest."""
    phase = 0 if spin is None else spin
    teeth = r * 3 // 2
    for dy in range(-r, 1):
        for dx in range(-r, r + 1):
            d = (dx * dx + dy * dy) ** 0.5
            if d > r + 0.4:
                continue
            x, y = cx + dx, cy + dy
            turn = math.atan2(-dy, dx) / math.pi          # 0 at the right, 1 at the left
            if d > r - 1.2:
                # saw teeth: every other notch of the rim is cut away
                notch = int(turn * teeth * 2 + phase) % 2
                if notch and d > r - 0.6:
                    continue
                c = STEEL[1] if not notch else STEEL[3]
            elif d <= 2.3:
                c = IRON[2] if d > 1.2 else IRON[0]       # arbor washer
            elif spin is None:
                # at rest: plain plate with one soft highlight toward the light
                c = STEEL[1] if 0.55 < turn < 0.8 and d < r - 2 else STEEL[2]
                if abs(d - (r - 2.2)) < 0.5 and turn < 0.35:
                    c = STEEL[3]
            else:
                # running: the plate blurs into rings with glints going round
                ring = int(d + 0.5)
                c = STEEL[2] if ring % 3 == 0 else STEEL[1]
                if ring % 3 == 1 and int(turn * 8 + phase * 0.5) % 4 == 0:
                    c = STEEL[0]
            f.put(x, y, c)
    # the slot the blade runs in
    f.hline(cx - r - 1, cx + r + 1, cy + 1, TIMBER[4])


WHEEL = ['...ooooo...',
         '..o.....o..',
         '.o.......o.',
         'o.........o',
         'o.........o',
         'o.........o',
         'o.........o',
         'o.........o',
         '.o.......o.',
         '..o.....o..',
         '...ooooo...']
RIM = [(1, 0), (4, -3), (5, 0), (4, 3), (1, 4), (-3, 4), (-5, 0), (-3, -3)]


def crank_wheel(f, cx, cy, turn):
    """The hand-cranked flywheel on the large mill, in 8 handle positions."""
    f.rows(cy - 5, cx - 5, WHEEL, {'o': IRON[0]})
    # lit upper left of the rim, shaded lower right
    f.pts(STEEL[1], (cx - 2, cy - 5), (cx - 1, cy - 5), (cx - 3, cy - 4), (cx - 4, cy - 3), (cx - 5, cy - 2), (cx - 5, cy - 1))
    f.pts(IRON[1], (cx + 2, cy + 5), (cx + 1, cy + 5), (cx + 3, cy + 4), (cx + 4, cy + 3), (cx + 5, cy + 2), (cx + 5, cy + 1))
    if turn % 2 == 0:
        spokes = [(0, d) for d in range(-4, 5)] + [(d, 0) for d in range(-4, 5)]
    else:
        spokes = [(d, d) for d in range(-3, 4)] + [(d, -d) for d in range(-3, 4)]
    for dx, dy in spokes:
        f.put(cx + dx, cy + dy, TIMBER[0] if dx <= 0 and dy <= 0 else TIMBER[2])
    f.pts(IRON[0], (cx, cy))
    f.pts(IRON[2], (cx + 1, cy), (cx, cy + 1))
    # turned wooden handle standing off the rim
    hx, hy = RIM[turn % 8]
    f.pts(POLE[0], (cx + hx, cy + hy - 1), (cx + hx - 1, cy + hy - 1))
    f.pts(POLE[2], (cx + hx, cy + hy), (cx + hx - 1, cy + hy))


def drive_belt(f, x0, x1, y_top, y_bot, shift):
    """A leather belt run; the stitch marks travel when shift changes."""
    for x in range(x0, x1 + 1):
        f.put(x, y_top, BELT[1] if (x + shift) % 4 == 0 else BELT[0])
        f.put(x, y_bot, BELT[0] if (x - shift) % 4 == 0 else BELT[1])


def large(step=None):
    """The large mill: a heavy bench with one circular blade turned by a
    hand-cranked flywheel and belt."""
    f = Frame(64, 32)
    table(f)
    turn = 0 if step is None else step // 2
    # belt to the arbor pulley under the top, then the flywheel over it
    drive_belt(f, 20, 32, 24, 26, 0 if step is None else step)
    f.rect(32, 24, 34, 26, IRON[1])
    f.pts(IRON[0], (32, 24), (33, 25))
    f.pts(IRON[2], (34, 26), (34, 25))
    crank_wheel(f, 19, 25, turn)

    if step is not None:
        left = -28 + (step * 92) // 64
        right = left + 27
        log_piece(f, left, right, 9, 8, 0, 31, seed=6)
        plank_piece(f, left, right, 9, 4, 33, 63, bark_top=True, lift=1, origin=33)
        plank_piece(f, left, right, 13, 4, 33, 63, origin=33)
        if left <= 24 <= right:
            dust_spray(f, 24, 11, step)
    blade(f, 32, 16, 8, step)
    f.rows(29, 30, ['.ab.a.', 'abab..'] if step is None else ['.abab.', 'ababab'], {'a': DUST[0], 'b': DUST[1]})
    f.outline()
    return f


def powered(step=None):
    """The powered mill: an iron-framed bench with two blades in line and
    an electric motor in a painted housing, wired at the foot."""
    f = Frame(64, 32)
    table(f, iron_frame=True)
    run = step is not None
    # motor housing hung on the left of the apron
    f.rect(12, 20, 21, 29, PAINT[2])
    f.hline(12, 21, 20, PAINT[0])
    f.vline(12, 21, 29, PAINT[1])
    f.vline(21, 21, 29, PAINT[3])
    f.hline(13, 21, 29, PAINT[3])
    # cooling slots
    for y in (23, 25, 27):
        f.hline(14, 17, y, PAINT[3])
        f.hline(14, 17, y - 1, PAINT[1])
    # status lamp and copper terminal
    lamp = LAMP_ON if run and step % 8 < 6 else LAMP_ON[::-1] if run else LAMP_OFF
    f.pts(lamp[0], (19, 22))
    f.pts(lamp[1], (19, 23))
    f.pts(COPPER[0], (19, 26))
    f.pts(COPPER[1], (20, 26), (19, 27), (20, 27))
    # cable trailing off along the ground
    f.pts(OUT, (20, 28), (20, 29), (21, 30), (22, 30), (23, 30), (24, 30), (25, 30))
    # belt from the motor shaft to both arbor pulleys
    drive_belt(f, 22, 44, 24, 26, 0 if not run else step * 2)
    for px in (27, 43):
        f.rect(px - 1, 24, px + 1, 26, IRON[1])
        f.pts(IRON[0], (px - 1, 24), (px, 25))
        f.pts(IRON[2], (px + 1, 26), (px + 1, 25))

    if run:
        left = -28 + (step * 92) // 64
        right = left + 27
        log_piece(f, left, right, 9, 8, 0, 26, seed=6)
        # first blade halves the log, the second halves each half again
        plank_piece(f, left, right, 9, 4, 28, 42, bark_top=True, origin=28)
        plank_piece(f, left, right, 13, 4, 28, 42, origin=28)
        plank_piece(f, left, right, 8, 2, 44, 63, bark_top=True, lift=1, origin=44)
        plank_piece(f, left, right, 11, 2, 44, 63, origin=44)
        plank_piece(f, left, right, 13, 2, 44, 63, origin=60)
        plank_piece(f, left, right, 15, 2, 44, 63, origin=60)
        if left <= 20 <= right:
            dust_spray(f, 20, 11, step)
        if left <= 36 <= right:
            dust_spray(f, 36, 10, step + 2, reach=2)
    blade(f, 27, 16, 7, None if not run else step)
    blade(f, 43, 16, 7, None if not run else step + 1)
    f.rows(29, 30, ['.ab.a...', 'abab.ab.'] if not run else ['.ababa..', 'abababab'], {'a': DUST[0], 'b': DUST[1]})
    f.outline()
    return f


# -------------------------------------------------------------- sheets --

def sheets():
    """(path, width, [(state, frames)]) for both icon files."""
    return [
        (SMALL, 32, [('primitive_sawmill', [primitive()]),
                     ('primitive_sawmill1', [primitive(i) for i in range(32)])]),
        (WIDE, 64, [('sawmill1', [large(i) for i in range(64)]),
                    ('sawmill', [large()]),
                    ('sawmill_power1', [powered(i) for i in range(64)]),
                    ('sawmill_power', [powered()])]),
    ]


def build(width, states):
    frames = [fr for _, frs in states for fr in frs]
    cols = int(len(frames) ** 0.5 + 0.999)
    rows = (len(frames) + cols - 1) // cols
    im = Image.new('RGBA', (cols * width, rows * 32))
    for i, fr in enumerate(frames):
        im.paste(fr.image(), ((i % cols) * width, (i // cols) * 32))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = %d\n\theight = 32\n' % width
    for name, frs in states:
        text += 'state = "%s"\n\tdirs = 1\n\tframes = %d\n' % (name, len(frs))
        if len(frs) > 1:
            text += '\tdelay = %s\n' % ','.join(['0.5'] * len(frs))
    text += '# END DMI\n'
    return im, text


def write_dmi(path, width, states):
    im, text = build(width, states)
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    im.save(path, 'PNG', pnginfo=meta, optimize=True)


def check(path, width, states):
    im, text = build(width, states)
    old = Image.open(path)
    return old.info.get('Description') == text and old.convert('RGBA').tobytes() == im.tobytes()


def preview(path, scale=6):
    """Idle frame and six evenly spaced cutting frames of each mill."""
    bg = (98, 122, 78, 255)
    rows = []
    for fn, n, w in ((primitive, 32, 32), (large, 64, 64), (powered, 64, 64)):
        rows.append((w, [fn()] + [fn(i) for i in range(n // 12, n, n // 6)][:6]))
    pad = 6
    wmax = max(len(r) * (w * scale + pad) for w, r in rows) + pad
    out = Image.new('RGBA', (wmax, len(rows) * (32 * scale + pad) + pad), bg)
    for j, (w, r) in enumerate(rows):
        for i, fr in enumerate(r):
            im = fr.image().resize((w * scale, 32 * scale), Image.NEAREST)
            out.alpha_composite(im, (pad + i * (w * scale + pad), pad + j * (32 * scale + pad)))
    out.save(path)


def gif(path, scale=5):
    bg = (98, 122, 78, 255)
    frames = []
    for i in range(64):
        im = Image.new('RGBA', (64 * scale, 3 * 34 * scale), bg)
        for j, fr in enumerate((primitive(i % 32), large(i), powered(i))):
            tile = fr.image().resize((fr.w * scale, 32 * scale), Image.NEAREST)
            im.alpha_composite(tile, ((64 - fr.w) * scale // 2, (j * 34 + 1) * scale))
        frames.append(im.convert('P', palette=Image.ADAPTIVE))
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=50, loop=0)


if __name__ == '__main__':
    if '--check' in sys.argv:
        bad = [str(p) for p, w, st in sheets() if not check(p, w, st)]
        if bad:
            sys.exit('stale saw mill sheets: ' + ', '.join(bad))
        print('saw mill sheets match')
    else:
        for p, w, st in sheets():
            write_dmi(p, w, st)
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
    if '--gif' in sys.argv:
        gif(sys.argv[sys.argv.index('--gif') + 1])
