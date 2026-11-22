"""Hand-placed 32px hopper-fed machines for icons/obj/hopper_machines.dmi:
the mill stones (`millstones`, `millstones_on`), the water-powered sash
saw (`sash_saw`, `sash_saw_on`), the fulling stocks (`fulling_stocks`,
`fulling_stocks_on`), the bark stamps (`bark_stamps`, `bark_stamps_on`) and
the shaft-driven power loom (`power_loom`, `power_loom_on`).
Each has one direction; the `_on` states are four-frame loops.

The mill stones sit on a heavy timber hurst frame in 3/4 view: the grey
runner stone on the bed stone, a staved wooden tun round the back and left
(cut away at the right so both stones show), the grain hopper on its horse
over the eye and the meal spout at the front. Running, the dressing furrows
go round the stone face and flour dusts the spout.

The sash saw is an upright wooden sash holding one iron blade between two
fixed fender posts, over a long low carriage bed with a squared log fed into
the blade from the left and a rack of logs at the back. Running, the sash and
blade go up and down and sawdust falls below the cut.

The fulling stocks are two heavy wooden hammers with notched, iron-bound
heads hung from the head beam of a timber frame, over a plank trough (the
stock) of wet wool cloth, with the cam shaft and its tappets along the back.
Running, the hammers rise and fall into the trough in turn and water
splashes where one lands.

The bark stamps are three upright timber stamps with iron shoes standing in
front of two guide rails, over a stone trough of tan bark; the cam shaft
behind lifts each stamp by its tappet. Running, the stamps lift and drop in
turn and bits of crushed bark jump where one lands.

The power loom is an early cast-iron loom of the 1800s, seen from the cloth
end: two iron side frames tied by a breast rail, the warp beam wound with
white cotton at the back, the warp running forward under the heald shaft and
through the reed of the wooden batten (sley) to the fell, and the woven cream
cloth rolling onto the cloth beam at the front. The belt pulley sits on the
crank shaft at the right. Running, the batten swings back and beats up, the
dark wooden shuttle flies along its race, the shed changes, the cloth beam
creeps round and the pulley's spokes turn.

Palette, outline and light (from the upper left) are those of
create_transmission.py and the prime movers in create_mechanical_power.py:
the same seasoned timber, wrought iron and field stone. The loom's iron is
that wrought-iron ramp, its cotton and cloth the flour white, stone highlight
and wool creams already on the sheet.

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
# wet wool cloth in the fulling trough: light, mid, fold
WOOL = [(232, 220, 190, 255), (198, 184, 152, 255), (144, 132, 110, 255)]
# the water it is fulled in, and the spray a falling hammer throws up
WATER = (120, 164, 196, 255)
SPRAY = (214, 232, 242, 255)
# tan bark, the browns of icons/obj/bark.dmi: light, mid, dark, shade
BARK = [(177, 156, 140, 255), (167, 133, 118, 255), (152, 103, 93, 255), (104, 66, 56, 255)]

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


def back_shaft(f, y, x0=1, x1=30):
    """The squared cam shaft along the back of a frame, iron-banded ends.
    It lies in the shade of the frame, a tone darker than what is in front."""
    for x in range(x0, x1 + 1):
        f.put(x, y, TIMBER[2])
        f.put(x, y + 1, TIMBER[3])
        f.put(x, y + 2, TIMBER[4] if grain(x // 4, 2, 7) == 0 else TIMBER[3])
        f.put(x, y + 3, TIMBER[4])
    for x in (x0, x1):
        f.vline(x, y, y + 3, IRON[1])
        f.put(x, y, IRON[0])


def frame_posts(f, xs, top, bottom=27):
    """Two upright posts with a sill foot each, lit on the left."""
    for x0 in xs:
        f.vline(x0, top, bottom, TIMBER[1])
        f.vline(x0 + 1, top, bottom, TIMBER[2])
        f.vline(x0 + 2, top, bottom, TIMBER[4])
        f.rect(x0 - 1, 28, x0 + 3, 29, TIMBER[3])
        f.hline(x0 - 1, x0 + 3, 28, TIMBER[2])
        f.put(x0 + 3, 29, TIMBER[4])


# ---------------------------------------------------------- fulling stocks

# how far each hammer head is lifted in the four working frames
FULL_LIFT = ((0, -3, -5, -2), (-5, -2, 0, -3))


def fulling_stocks(step=None):
    """`step` None is the stocks standing with both hammers down in the
    trough; 0-3 are the working frames."""
    f = Frame()
    back_shaft(f, 8)
    frame_posts(f, (3, 26), 3)
    # head beam the hammers hang from
    f.rect(2, 1, 29, 3, TIMBER[1])
    f.hline(2, 29, 1, TIMBER[0])
    f.hline(3, 29, 3, TIMBER[3])
    f.pts(TIMBER[4], (4, 2), (27, 2))
    # the stock: back rim, the dark inside, wet cloth heaped along it
    f.hline(5, 26, 18, TIMBER[2])
    f.rect(5, 19, 26, 22, PIT)
    for x in range(5, 27):
        top = 20 + (grain(x // 2, 4, 3) % 2)
        for y in range(top, 23):
            f.put(x, y, WOOL[0] if y == top else WOOL[1])
        if grain(x, 6, 2) < 3:
            f.put(x, 22, WOOL[2])                 # a fold in the cloth
    f.pts(WATER, (5, 22), (15, 22), (16, 22), (26, 22))
    for k, sx in enumerate((10, 20)):
        lift = 0 if step is None else FULL_LIFT[k][step]
        # the tappet for this hammer going round on the cam shaft
        turn = (2 * k) if step is None else (step + 2 * k) % 4
        if turn == 0:
            f.pts(TIMBER[3], (sx + 3, 12), (sx + 4, 12))
        elif turn == 1:
            f.rect(sx + 3, 9, sx + 4, 10, TIMBER[0])
            f.pts(TIMBER[3], (sx + 4, 10))
        elif turn == 2:
            f.pts(TIMBER[1], (sx + 3, 7), (sx + 4, 7))
        # the hammer: its shaft from the head beam, and the heavy head
        hb = 22 + lift
        f.vline(sx, 4, hb - 5, TIMBER[0])
        f.vline(sx + 1, 4, hb - 5, TIMBER[2])
        f.rect(sx - 3, hb - 5, sx + 4, hb - 1, TIMBER[1])
        f.hline(sx - 3, sx + 4, hb - 5, TIMBER[0])
        f.vline(sx + 4, hb - 4, hb - 1, TIMBER[3])
        f.hline(sx - 2, sx + 4, hb - 1, TIMBER[2])
        f.hline(sx - 3, sx + 4, hb - 3, IRON[1])           # the iron band
        f.put(sx - 3, hb - 3, IRON[0])
        for x in range(sx - 3, sx + 5):                    # the notched face
            if (x - sx) % 3 != 2:
                f.put(x, hb, TIMBER[4])
    # the front of the stock: rim, planks, two iron straps
    f.rect(4, 23, 27, 27, TIMBER[2])
    f.hline(4, 27, 23, TIMBER[0])
    f.hline(4, 27, 25, TIMBER[3])
    f.hline(4, 27, 27, TIMBER[4])
    f.vline(4, 23, 26, TIMBER[1])
    for x in range(5, 27):
        if grain(x // 3, 5, 8) == 0:
            f.put(x, 26, TIMBER[3])
    for x in (9, 22):
        f.vline(x, 23, 27, IRON[1])
        f.put(x, 23, IRON[0])
    f.rect(15, 23, 16, 24, WOOL[0])               # cloth hanging over the rim
    f.pts(WOOL[2], (16, 24))
    f.outline()
    f.shadow(1, 31, 30, 31)
    # water thrown up where a hammer has just come down
    if step == 0:
        f.pts(SPRAY, (6, 17), (15, 16), (5, 19))
        f.pts(WATER, (15, 18), (6, 15))
    elif step == 2:
        f.pts(SPRAY, (16, 16), (25, 17), (26, 19))
        f.pts(WATER, (16, 18), (25, 15))
    return f


# ------------------------------------------------------------ bark stamps

# a stamp's lift through one turn of its cam: resting, lifting, up, dropped
STAMP_LIFT = (0, -2, -3, 0)


def bark_stamps(step=None):
    """`step` None is the stamps standing, all three down; 0-3 are the
    working frames."""
    f = Frame()
    back_shaft(f, 11)
    frame_posts(f, (2, 27), 3)
    # the two guide rails the stamps stand against
    for y in (5, 16):
        f.hline(2, 29, y, TIMBER[3])
        f.hline(2, 29, y + 1, TIMBER[4])
    # the stone trough: back rim, the dark inside, the bark lying in it
    f.hline(5, 26, 19, STONE[1])
    f.rect(5, 20, 26, 22, PIT)
    for x in range(5, 27):
        top = 20 + (grain(x // 2, 2, 9) % 2)
        for y in range(top, 23):
            f.put(x, y, BARK[grain(x, y, 4) % 3 + (y > top)])
    landed = []
    for k, x0 in enumerate((7, 14, 21)):
        turn = 0 if step is None else (step - k) % 4
        lift = STAMP_LIFT[turn]
        if turn == 3:
            landed.append(x0)
        # the cam coming round under the tappet
        if turn == 0:
            f.rect(x0 + 4, 12, x0 + 5, 13, IRON[1])
            f.put(x0 + 4, 12, IRON[0])
        elif turn in (1, 2):
            f.rect(x0 + 4, 11 + lift, x0 + 5, 12, IRON[1])
            f.vline(x0 + 4, 11 + lift, 12, IRON[0])
        # the stamp: a squared beam, its tappet, an iron shoe
        f.vline(x0, 3 + lift, 19 + lift, TIMBER[0])
        f.rect(x0 + 1, 3 + lift, x0 + 2, 19 + lift, TIMBER[1])
        f.vline(x0 + 3, 3 + lift, 19 + lift, TIMBER[3])
        for y in range(5 + lift, 19 + lift):
            if grain(x0, y // 3, 6) == 0:
                f.put(x0 + 1, y, TIMBER[2])
        f.pts(TIMBER[1], (x0 + 4, 10 + lift), (x0 + 5, 10 + lift))
        f.put(x0 + 5, 10 + lift, TIMBER[3])
        f.rect(x0, 20 + lift, x0 + 3, 22 + lift, IRON[1])
        f.vline(x0, 20 + lift, 21 + lift, IRON[0])
        f.hline(x0, x0 + 3, 22 + lift, IRON[2])
    # the front of the trough: rim, coursed stone
    f.rect(4, 23, 27, 27, STONE[2])
    f.hline(4, 27, 23, STONE[0])
    f.hline(4, 27, 27, STONE[4])
    f.vline(4, 24, 26, STONE[1])
    for x in range(5, 27):
        if (x + 2) % 6 == 0:
            f.vline(x, 24, 26, STONE[4])
        elif grain(x, 3, 2) < 2:
            f.put(x, 25, STONE[3])
        elif grain(x, 7, 5) < 2:
            f.put(x, 24, STONE[1])
    f.outline()
    f.shadow(1, 31, 30, 31)
    # crushed bark thrown out where a stamp has just dropped
    for x0 in landed:
        f.pts(BARK[0], (x0 - 1, 18), (x0 + 5, 20))
        f.pts(BARK[2], (x0 + 4, 17), (x0 - 2, 20), (x0 + 6, 18))
    return f


# ------------------------------------------------------------- power loom

# how far the batten stands from mid swing: back, mid, beating up, mid
BATTEN_SWING = (-2, 0, 2, 0)
# where the shuttle's left end is on the race; standing it rests in the left box
SHUTTLE_X = (8, 14, 19, 4)
# cotton warp: a thread in the light, and the one beside it
COTTON = [FLOUR, STONE[0]]


def power_loom(step=None):
    """`step` None is the loom standing with the batten at mid swing and the
    shuttle in its box; 0-3 are the working frames."""
    f = Frame()
    turn = step or 0
    x0, x1 = 4, 21                        # the width of the warp and cloth
    # the warp sheet from the beam forward to the fell, the shed changing
    for x in range(x0, x1 + 1):
        f.vline(x, 7, 18, COTTON[(x + turn) % 2])
    # the warp beam at the back: a roll of white thread between iron flanges
    for x in range(x0, x1 + 1):
        f.vline(x, 2, 4, FLOUR)
        f.put(x, 5, STONE[0])
        f.put(x, 6, STONE[1])
        if x % 3 == 1:
            f.vline(x, 3, 5, STONE[0] if x % 2 else STONE[1])
    f.hline(x0, x1, 2, STONE[0])
    f.pts(FLOUR, *[(x, 2) for x in range(x0, x1 + 1, 2)])
    # the heald shaft across the warp, its cords knotted along it
    f.hline(x0, x1, 8, TIMBER[2])
    f.hline(x0, x1, 9, TIMBER[4])
    for x in range(x0 + 1, x1, 3):
        f.put(x, 8, TIMBER[0])
    # the woven cloth from the fell to the cloth beam
    for x in range(x0, x1 + 1):
        f.put(x, 19, WOOL[1] if x % 2 else WOOL[0])       # the fell
        f.put(x, 20, WOOL[0])
        f.put(x, 21, WOOL[1] if grain(x // 2, 3, 1) < 3 else WOOL[0])
    # the cloth beam: the roll of cloth, creeping round as it takes up
    for x in range(x0, x1 + 1):
        f.put(x, 22, WOOL[0])
        f.put(x, 23, WOOL[0])
        f.put(x, 24, WOOL[1])
        f.put(x, 25, WOOL[1])
        f.put(x, 26, WOOL[2])
    for k, x in enumerate(range(x0 + 2, x1, 5)):
        y = 22 + (k + turn) % 4
        f.put(x, y, WOOL[2] if y > 23 else WOOL[1])
        f.put(x + 1, y, WOOL[2] if y > 23 else WOOL[1])
    # the batten: reed cap, the iron reed, the race and the heavy sley
    by = 12 + (0 if step is None else BATTEN_SWING[step])
    f.hline(x0, x1, by, TIMBER[2])
    for x in range(x0, x1 + 1):
        f.put(x, by + 1, IRON[0] if x % 2 else IRON[2])
    f.hline(x0, x1, by + 2, TIMBER[0])
    f.hline(x0, x1, by + 3, TIMBER[1])
    f.hline(x0, x1, by + 4, TIMBER[3])
    for x in range(x0, x1 + 1):
        if grain(x // 3, 6, 3) == 0:
            f.put(x, by + 3, TIMBER[2])
    # the shuttle boxes at the ends of the race
    for bx in (x0, x1 - 2):
        f.hline(bx, bx + 2, by, TIMBER[1])
        f.put(bx if bx == x0 else bx + 2, by + 1, TIMBER[3])
    # the shuttle, a dark block of boxwood on the race
    sx = 4 if step is None else SHUTTLE_X[step]
    f.hline(sx, sx + 2, by + 1, TIMBER[3])
    f.hline(sx, sx + 2, by + 2, TIMBER[4])
    if step in (0, 1):
        f.put(sx - 1, by + 2, FLOUR)                      # the weft it trails
    # the cast-iron side frames, their feet, and the flanges of both beams
    for fx in (1, 22):
        f.vline(fx, 4, 28, IRON[0])
        f.vline(fx + 1, 3, 28, IRON[1])
        f.vline(fx + 2, 4, 28, IRON[2])
        f.put(fx + 1, 3, IRON[0])
        f.vline(fx + 1, 9, 11, IRON[2])                   # the cast openings
        f.vline(fx + 1, 17, 20, IRON[2])
        f.hline(fx - 1, fx + 3, 29, IRON[1])
        f.put(fx - 1, 29, IRON[0])
        f.put(fx + 3, 29, IRON[2])
    for fx in (3, 22):
        f.vline(fx, 1, 7, IRON[1])                        # warp beam flange
        f.put(fx, 1, IRON[0])
        f.put(fx, 4, GREASE)                              # its gudgeon
        f.vline(fx, 21, 27, IRON[1])                      # cloth beam flange
        f.put(fx, 21, IRON[0])
        f.put(fx, 24, GREASE)
    # the breast rail tying the frames under the cloth beam
    f.hline(2, 23, 27, IRON[0])
    f.hline(2, 23, 28, IRON[2])
    f.pts(IRON[1], (3, 27), (22, 27))
    f.pts(GREASE, (6, 27), (19, 27))                      # bolt heads
    # the belt pulley on the crank shaft at the right, seen nearly edge on
    cx, cy = 28, 15
    f.hline(25, 27, cy, IRON[1])
    for y in range(cy - 7, cy + 8):
        h = arc(cy, 7.4, 2.4, y)
        for x in range(round(cx - h), round(cx + h) + 1):
            f.put(x, y, IRON[2])
        f.put(round(cx - h), y, IRON[0] if y < cy + 3 else IRON[1])     # lit rim
        f.put(round(cx + h), y, IRON[1])
    f.pts(IRON[0], (cx, cy - 7), (cx - 1, cy - 7))
    f.pts(IRON[1], (cx, cy + 7), (cx + 1, cy + 7))
    for k in range(4):
        a = math.radians(turn * 22.5 + k * 90 + 10)
        f.line(cx, cy, round(cx + 1.2 * math.cos(a)), round(cy + 5.6 * math.sin(a)),
               GREASE if k == 0 else IRON[0])
    f.put(cx, cy, GREASE)                                 # the hub
    f.outline()
    f.shadow(1, 31, 30, 31)
    return f


def states():
    """[(state, frames)] in sheet order; every state has one direction."""
    on = range(FRAMES_ON)
    return [
        ('millstones', [millstones()]),
        ('millstones_on', [millstones(i) for i in on]),
        ('sash_saw', [sash_saw()]),
        ('sash_saw_on', [sash_saw(i) for i in on]),
        ('fulling_stocks', [fulling_stocks()]),
        ('fulling_stocks_on', [fulling_stocks(i) for i in on]),
        ('bark_stamps', [bark_stamps()]),
        ('bark_stamps_on', [bark_stamps(i) for i in on]),
        ('power_loom', [power_loom()]),
        ('power_loom_on', [power_loom(i) for i in on]),
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
