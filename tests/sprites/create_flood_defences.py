"""Script-drawn flood defences for icons/obj/flood_defences.dmi.

Every pixel is placed by this script from fixed palettes (Pillow only); no
external or generated artwork. It is the same family as create_sewers.py and
takes its timber, stone, iron and water colours and its small drawing helpers
from there, so the two sheets sit together. The pieces are transparent outside
the drawn work and the light comes from the upper left.

States, all 32x32 and 1 dir, 1 frame unless noted:

  stilts                 A timber platform on wooden posts, seen from above
                         like a floor: a plank deck with a post head at each
                         corner, and on the south edge the fascia beam, the
                         posts and the dark space under the deck, about knee
                         high.
  plinth                 A raised dressed-stone foundation slab: a flat paved
                         top and a course of stone showing on the south side.
  sluice_gate            A timber sluice gate seen from the side, standing in
                         a gap of an earth levee: two posts, a cross-beam
                         with a windlass roller, and stacked boards on two
                         ropes closing the gap.
  sluice_gate_open       The same with the boards drawn up under the beam and
                         water running through the open gap.
  shaduf                 An ancient water-lifting sweep seen from the side: a
                         forked post, a long pole lashed in the fork, a stone
                         counterweight on the short end and a rope and bucket
                         on the long end, at rest with the bucket up.
  shaduf_use             4 frames, 3 ds each: the pole comes down, the bucket
                         dips and splashes, comes up full and dripping, and
                         is tipped out at the top.
  archimedes_screw       A wooden Archimedes screw lying up the tile from the
                         lower left to the upper right on two trestles: an
                         open timber trough bound with iron, the helix inside
                         it and a crank at the top end.
  archimedes_screw_use   4 frames, 3 ds each: the helix walks up the trough
                         carrying water, the crank goes round and water falls
                         from the top end.
  river_gauge            A tall narrow gauge post driven into the ground,
                         painted in light and dark bands with tick marks, the
                         paint weathered and the foot stained by the river.
  cistern0 .. cistern3   A Classical plastered rainwater cistern seen from
                         above like the plinth: a square stone tank with a
                         pale lime-plaster rim, a stone gutter coming in over
                         the north wall and a worn stone dipping lip on the
                         south rim. 0 is empty, the stained plaster floor
                         showing; 1 has a shallow puddle; 2 is about half
                         full, the inside wall still showing above the water;
                         3 is full to the brim, with a ripple under the spout.
  lever_pump             An 18th-century cast-iron hand lever pump seen from
                         the side: a fluted iron barrel with three collars on
                         a stone block, a long handle on a bracket at the
                         head, a spout on the west side and a wooden bucket
                         under it. At rest the handle hangs down.
  lever_pump_use         4 frames, 3 ds each: the handle rocks up and down
                         and water gushes from the spout into the bucket on
                         the down-strokes.
  mine_pump              A Newcomen-style atmospheric beam engine pumping a
                         mine, seen from the side: a brick engine house with
                         a tall chimney, the cylinder over its copper boiler
                         showing in an arch, a wooden beam rocking on the bob
                         wall, and a pump rod going down a timbered shaft on
                         the east side with an outlet pipe beside it. Stopped,
                         the pump end of the beam hangs down.
  mine_pump_on           4 frames, 3 ds each: the beam rocks, the fire
                         flickers, smoke puffs from the chimney and water
                         trickles from the outlet pipe.
  windmill_pump          A Dutch polder drainage mill reduced to one tile: a
                         thatched smock on a brick base with a boarded cap,
                         four lattice sails standing in a cross, and a scoop
                         wheel in a stone channel at its foot.
  windmill_pump_on       4 frames, 2 ds each: the sails turn 22.5 degrees a
                         frame, so the four frames close the loop, the scoop
                         wheel turns and water spills from the channel.
  sump_pump              A modern electric sump pump seen from slightly
                         above: a round blue-grey motor standing in a square
                         concrete pit of water, a white discharge riser with
                         a black check valve, a float switch on an arm, a
                         mains cord to a plug on the ground and a green and
                         yellow standby battery beside the pit.
  sump_pump_on           3 frames, 3 ds each: the green indicator lamp
                         blinks, the float bobs and the water in the pit
                         shimmers.

Every state keeps at least 1px clear on the left, right and bottom of the
tile, which `--check` enforces together with the frame counts and delays, and
that no animation repeats a frame.

Run with Pillow to rewrite icons/obj/flood_defences.dmi (safe to rerun).
`--out <dmi>` writes the sheet somewhere else, `--preview <png>` writes a
labelled review sheet with every state and frame on grass and dirt and five
small scenes (`--preview-only <prefix>[,<prefix>...]` keeps just the states
whose names start with one of the prefixes and the scenes made for them),
`--check` only verifies
that the committed sheet is what this script draws. Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_water_animation import SIZE, write_dmi  # noqa: E402
from create_sewers import (  # noqa: E402
    BANK_LIT, BANK_SHADE, BRASS, BRICK, BRICK_MORTAR, CABLE, CLEAR, CLEAR_GLINT, CLEAR_SHADE, CONCRETE, DAMP, DARK,
    EMBER, FLOW, IRON, MORTAR, NAIL, PAINT, RIM, RIVER, ROCK, SHADOW, SLAB, SLAB_SHADE, SLOT, CHIP, VALVE, WALL_SHADE,
    WET, WOOD, brick_drain, check_sheet, fill_box, ground_shadow, ground_tiles, image, loop, noise, option, pixels,
    pump_electric, pump_steam, rod, septic, settling, stone_drain)

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/flood_defences.dmi'

MARGIN = 1                               # clear pixels left, right and below
USE_FRAMES, USE_DELAY = 4, 3             # both working loops

ROPE = [(204, 180, 128), (156, 130, 86)]
FOAM = (226, 236, 232)
STONE_FOOT = (92, 88, 80)                # the bottom of a stone course, damp
WHITE = [(236, 230, 208), (206, 198, 174)]       # gauge paint, lit and worn
BLACK = [(62, 58, 56), (40, 38, 38)]
RED = [(190, 62, 48), (140, 40, 34)]
STAIN = [(96, 104, 66), (74, 78, 52)]            # river slime on the gauge foot
# lime plaster: fresh and lit, plain, worn, in shade, in deep shade
PLASTER = [(242, 236, 218), (226, 218, 198), (206, 197, 176), (168, 160, 142), (126, 119, 105)]

# the shaduf: the pole turns on the fork of the post
PIVOT = (15, 10)
LONG_ARM, SHORT_ARM = 13.0, 9.0
ROPE_LEN = 8
SHADUF_REST = 25                         # degrees the long end is raised
# (pole angle, what the bucket is doing) for each working frame
SHADUF_USE = ((8, 'empty'), (-15, 'dip'), (5, 'full'), (25, 'pour'))

# the screw: its axis from the foot in the water to the head
SCREW_FOOT, SCREW_HEAD = (5.0, 25.0), (25.5, 8.5)
SCREW_HALF = 4.2                         # half the width of the trough
SCREW_PITCH = 6.0                        # one turn of the helix, along the axis


def wood_tone(tone, x, y, seed, chance=0.25):
    """A timber colour with a little grain: now and then one tone darker."""
    if noise(x, y, seed) < chance:
        tone += 1
    return WOOD[max(0, min(tone, len(WOOD) - 1))]


# ------------------------------------------------------------------- stilts

DECK = (1, 1, 30, 24)                    # the plank deck, x0 y0 x1 y1
DECK_PLANK = 4
POST_HEADS = ((2, 2), (26, 2), (2, 20), (26, 20))     # 3px square, top left
STILT_LEGS = ((2, 4), (14, 17), (27, 29))             # columns of the posts seen under the deck


def stilts():
    px = {}
    x0, y0, x1, y1 = DECK
    for y in range(y0, y1 + 1):
        plank, row = divmod(y - y0, DECK_PLANK)
        for x in range(x0, x1 + 1):
            if row == DECK_PLANK - 1:
                c = WOOD[2]                              # the gap to the next plank
            else:
                # long quiet streaks of grain, so it reads as a floor
                c = WOOD[1]
                streak = noise((x + plank * 5) // 6, plank * 3 + row, 501)
                if streak < 0.22:
                    c = WOOD[0]
                elif streak > 0.9:
                    c = WOOD[2]
            px[(x, y)] = c
        # a butt joint in each plank, staggered
        joint = x0 + 6 + (plank * 11) % 19
        if row != DECK_PLANK - 1:
            px[(joint, y)] = WOOD[2]
    for y in range(y0, y1 + 1):
        px[(x0, y)] = WOOD[0]
        px[(x1, y)] = WOOD[2]
    for x in range(x0, x1 + 1):
        px[(x, y0)] = WOOD[0]
    # the post heads come up through the deck at the corners
    for hx, hy in POST_HEADS:
        fill_box(px, hx, hy, hx + 2, hy + 2, WOOD[1])
        for i in range(3):
            px[(hx + i, hy)] = WOOD[0]
            px[(hx, hy + i)] = WOOD[0]
            px[(hx + i, hy + 2)] = WOOD[3]
            px[(hx + 2, hy + i)] = WOOD[3]
        px[(hx + 1, hy + 1)] = WOOD[2]                   # the heart of the end grain
        for i in range(1, 4):                            # its shadow on the deck
            px[(hx + i, hy + 3)] = WOOD[2]
            px[(hx + 3, hy + i)] = WOOD[2]
    # the south side: the fascia beam, then the posts and the dark under the deck
    for x in range(x0, x1 + 1):
        px[(x, y1 + 1)] = WOOD[2] if noise(x // 4, 1, 503) < 0.8 else WOOD[1]
        px[(x, y1 + 2)] = WOOD[3] if noise(x // 5, 2, 503) < 0.75 else WOOD[2]
        px[(x, y1 + 3)] = WOOD[3]
    px[(x0, y1 + 1)] = WOOD[1]
    for y in range(y1 + 4, SIZE - MARGIN):
        for x in range(x0 + 1, x1):
            px[(x, y)] = SHADOW + ((150, 120, 80)[y - y1 - 4],)
        for lo, hi in STILT_LEGS:
            for x in range(lo, hi + 1):
                px[(x, y)] = WOOD[2] if x == lo else WOOD[3]
    for lo, hi in STILT_LEGS:                            # pegs through the beam into each post
        px[(lo + 1, y1 + 2)] = NAIL
    return image(px)


# ------------------------------------------------------------------- plinth

SLABTOP = (1, 2, 30, 23)
FLAG_ROWS = ((2, 8), (9, 15), (16, 23))  # the rows of flagstones, y0 y1
FLAG_WIDE = 10


def plinth():
    px = {}
    x0, y0, x1, y1 = SLABTOP
    for n, (fy0, fy1) in enumerate(FLAG_ROWS):
        shift = (0, 5, 2)[n]
        for y in range(fy0, fy1 + 1):
            for x in range(x0, x1 + 1):
                flag, col = divmod(x - x0 + shift, FLAG_WIDE)
                if (y == fy1 and n < len(FLAG_ROWS) - 1) or (col == FLAG_WIDE - 1 and x != x1):
                    px[(x, y)] = MORTAR
                    continue
                seed = 521 + n * 7 + flag
                c = SLAB[1] if noise(flag, n, 523) < 0.6 else SLAB[2]
                if noise(x // 3, y // 2, seed) < 0.16:
                    c = SLAB[2] if c == SLAB[1] else SLAB[1]
                if noise(x, y, seed + 1) < 0.02:
                    c = CHIP
                px[(x, y)] = c
    for x in range(x0, x1 + 1):
        px[(x, y0)] = SLAB[0]
        px[(x, y1)] = SLAB[0] if noise(x // 3, 0, 525) < 0.8 else SLAB[1]     # the worn nosing
    for y in range(y0, y1 + 1):
        px[(x0, y)] = SLAB[0]
        px[(x1, y)] = SLAB_SHADE
    # the south face: one course of dressed blocks, in shade
    for y in range(y1 + 1, SIZE - MARGIN - 1):
        row = y - y1 - 1
        for x in range(x0, x1 + 1):
            block, col = divmod(x - x0 + 3, 8)
            if col == 7 and x != x1:
                c = MORTAR
            elif row == 0:
                c = SLAB_SHADE                               # under the nosing
            elif y == SIZE - MARGIN - 2:
                c = STONE_FOOT
            else:
                c = SLAB[3] if noise(block, 3, 527) < 0.65 else SLAB_SHADE
                if noise(x, y, 529) < 0.06:
                    c = SLAB_SHADE
            if x == x0 and row:
                c = SLAB[2]
            if x == x1:
                c = STONE_FOOT
            px[(x, y)] = c
    ground_shadow(px, x0 + 1, x1, SIZE - MARGIN - 1)
    return image(px)


# -------------------------------------------------------------- sluice gate

POSTS = ((4, 7), (24, 27))               # columns of the two uprights
POST_TOP, POST_FOOT = 2, 29
BEAM = (4, 7)                            # rows of the cross-beam
GATE_X = (8, 23)                         # the gap between the posts
BOARD = 4
GATE_ROPES = (11, 20)
SHUT_BOARDS, OPEN_BOARDS = 5, 3          # boards showing below the beam
SHUT_TOP, OPEN_TOP = 9, 8                # the row the stack starts on
RACE_TOP = 24                            # the water through the open gap


def sluice_gate(is_open=False):
    px = {}
    # the cut ends of the levee the gate stands in
    for side, cols in ((0, (1, 2, 3)), (1, (28, 29, 30))):
        for i, x in enumerate(cols):
            rise = (3, 5, 6)[i] if side == 0 else (6, 5, 3)[i]
            for y in range(POST_FOOT + 1 - rise, POST_FOOT + 2):
                top = y == POST_FOOT + 1 - rise
                tones = BANK_LIT if side == 0 else BANK_SHADE
                c = RIM[0] if top and side == 0 else tones[noise(x, y, 541) < 0.4]
                if y == POST_FOOT + 1:
                    c = RIM[1]
                px[(x, y)] = c

    gx0, gx1 = GATE_X
    top, boards = (OPEN_TOP, OPEN_BOARDS) if is_open else (SHUT_TOP, SHUT_BOARDS)
    if is_open:
        # the race under the lifted boards
        for y in range(RACE_TOP, POST_FOOT + 2):
            for x in range(gx0, gx1 + 1):
                n = noise((x + 3 * y) // 4, y, 543)
                c = FLOW[1] if n < 0.5 else FLOW[2]
                if y == RACE_TOP:
                    c = FOAM if noise(x // 2, 0, 545) < 0.45 else FLOW[0]
                elif noise(x // 3, y, 547) < 0.18:
                    c = FLOW[0]
                px[(x, y)] = c + (235,)
        for x, y in ((10, RACE_TOP - 1), (14, RACE_TOP - 1), (15, RACE_TOP - 1), (21, RACE_TOP - 1)):
            px[(x, y)] = FOAM + (200,)
        # drips off the wet bottom board
        for x, y in ((9, 20), (13, 20), (13, 21), (18, 20), (22, 20), (22, 22)):
            px[(x, y)] = FLOW[1] + (190,)
    # the boards, each lit along its top and dark where it laps the next
    for y in range(top, top + boards * BOARD):
        board, row = divmod(y - top, BOARD)
        for x in range(gx0, gx1 + 1):
            if row == 0:
                c = wood_tone(0, x // 3, board, 549, 0.3)
            elif row == BOARD - 1:
                c = WOOD[3]
            else:
                c = wood_tone(1, (x + board * 3) // 4, y, 551, 0.3)
            px[(x, y)] = c
    foot = top + boards * BOARD - 1
    for x in range(gx0, gx1 + 1):
        if is_open:
            px[(x, foot)] = WALL_SHADE[1]                   # wet from the river
        else:
            px[(x, foot + 1)] = WET + (200,)                # the sill
    # the lifting ropes down the face of the stack, from the roller
    for rx in GATE_ROPES:
        for y in range(BEAM[1] + 1, top + 2 * BOARD - 1):
            px[(rx, y)] = ROPE[0] if y % 2 else ROPE[1]
        px[(rx, top + 2 * BOARD - 1)] = IRON[2]             # the staple it is tied to
        px[(rx - 1, top + 2 * BOARD - 1)] = IRON[1]
    # the uprights
    for lo, hi in POSTS:
        for y in range(POST_TOP, POST_FOOT + 1):
            for x in range(lo, hi + 1):
                tone = (0, 1, 1, 3)[x - lo]
                c = wood_tone(tone, x, y // 3, 553, 0.3) if tone == 1 else WOOD[tone]
                if y == POST_TOP:
                    c = WOOD[0] if x < hi else WOOD[1]
                if y >= POST_FOOT - 1 and tone < 3:
                    c = WOOD[2]                             # damp at the foot
                px[(x, y)] = c
    # the cross-beam, halved over the posts and pegged
    for y in range(BEAM[0], BEAM[1] + 1):
        for x in range(2, 30):
            tone = (0, 1, 2, 3)[y - BEAM[0]]
            c = wood_tone(tone, x // 4, y, 555, 0.3) if tone in (1, 2) else WOOD[tone]
            if x == 29:
                c = WOOD[3]
            px[(x, y)] = c
    for lo, hi in POSTS:
        px[(lo + 1, BEAM[0] + 1)] = NAIL
        px[(lo + 2, BEAM[0] + 2)] = NAIL
    # the windlass roller on top of the beam, with the ropes wound on it
    for x in range(9, 23):
        for y, tone in zip((1, 2, 3), (0, 1, 3)):
            px[(x, y)] = WOOD[tone]
        if x in (9, 22):
            px[(x, 1)] = px[(x, 3)] = IRON[2]
            px[(x, 2)] = IRON[0]
    for rx in GATE_ROPES:
        for x in (rx - 1, rx, rx + 1) if is_open else (rx,):
            for y, c in zip((1, 2, 3), (ROPE[0], ROPE[0], ROPE[1])):
                px[(x, y)] = c
    # the handspike in the roller: it has been hauled round when the gate is up
    if is_open:
        rod(px, 16, 2, 19, 0, IRON[1])
    else:
        rod(px, 15, 0, 16, 2, IRON[1])
    return image(px)


# ------------------------------------------------------------------- shaduf

def shaduf(frame=None):
    """The shaduf; `frame` is None at rest, else 0..3 working."""
    px = {}
    angle, doing = (SHADUF_REST, 'rest') if frame is None else SHADUF_USE[frame]
    a = math.radians(angle)
    cx, cy = PIVOT
    lx, ly = int(round(cx + LONG_ARM * math.cos(a))), int(round(cy - LONG_ARM * math.sin(a)))
    sx, sy = int(round(cx - SHORT_ARM * math.cos(a))), int(round(cy + SHORT_ARM * math.sin(a)))

    ground_shadow(px, 10, 21, 30)
    # the post, with a prop on the lee side and stones packed round its foot
    rod(px, 20, 29, 17, 21, WOOD[3])
    rod(px, 19, 29, 16, 21, WOOD[2])
    for y in range(cy + 2, 30):
        for x, tone in zip((14, 15, 16), (0, 1, 3)):
            px[(x, y)] = wood_tone(tone, x, y // 3, 561, 0.3) if tone == 1 else WOOD[tone]
    # the fork the pole lies in
    for y in range(cy - 3, cy + 2):
        px[(13, y)] = WOOD[0] if y > cy - 3 else WOOD[1]
        px[(17, y)] = WOOD[3] if y > cy - 3 else WOOD[2]
    px[(14, cy + 1)], px[(15, cy + 1)], px[(16, cy + 1)] = WOOD[1], WOOD[2], WOOD[3]
    for (x, y), c in (((12, 29), ROCK[1]), ((13, 29), ROCK[0]), ((12, 30), ROCK[2]), ((13, 30), ROCK[1]),
                      ((14, 30), ROCK[2]), ((17, 29), ROCK[1]), ((17, 30), ROCK[2]), ((18, 30), ROCK[3]),
                      ((15, 30), WOOD[3]), ((16, 30), WOOD[3])):
        px[(x, y)] = c

    # the rope and the bucket hang from the long end
    top = ly + ROPE_LEN
    for y in range(ly + 1, top + 1):
        px[(lx, y)] = ROPE[0] if y % 2 else ROPE[1]
    bx = lx - 2                                          # the bucket is 4 wide, 5 high
    if doing == 'dip':
        # down in the water: only the rim shows above a ring of ripples
        for x in range(bx - 2, bx + 5):
            edge = x in (bx - 2, bx + 4)
            px[(x, top + 3)] = (FOAM if (x + 1) % 3 == 0 else FLOW[0]) + (160 if edge else 230,)
            if not edge:
                px[(x, top + 4)] = FLOW[1 + (x % 2)] + (220,)
        for x in range(bx, bx + 3):
            px[(x, top + 5)] = FLOW[2] + (170,)
        for x, y in ((bx - 2, top), (bx + 4, top + 1), (bx - 1, top - 1)):
            px[(x, y)] = FOAM + (210,)
    for row in range(5):
        y = top + 1 + row
        if doing == 'dip' and row >= 2:
            break
        for i in range(4):
            if row == 4 and i in (0, 3):
                continue                                 # the bucket narrows to its foot
            tone = (0, 1, 1, 3)[i]
            if row == 0:
                c = WOOD[0] if i < 3 else WOOD[2]
            elif row == 2:
                c = IRON[1] if i < 3 else IRON[3]        # the hoop
            else:
                c = WOOD[tone if tone else 1]
            px[(bx + i, y)] = c
    px[(bx, top)] = px[(bx + 3, top)] = ROPE[1]          # the bail
    if doing in ('full', 'pour'):
        px[(bx + 1, top + 1)] = FLOW[0]
        px[(bx + 2, top + 1)] = FLOW[1]
    if doing == 'full':
        for x, y in ((bx + 1, top + 6), (bx + 2, top + 8), (bx, top + 9), (bx + 3, top + 7), (bx + 1, top + 11)):
            px[(x, y)] = FLOW[1] + (200,)
    if doing == 'pour':
        # tipped out over the side: a fall of water to the ground
        px[(bx - 1, top + 1)] = FLOW[0]
        for y in range(top + 2, 29):
            n = noise(bx, y, 563)
            px[(bx - 1, y)] = (FLOW[0] if n < 0.4 else FLOW[1]) + (230,)
            if n > 0.35 and y > top + 3:
                px[(bx - 2, y)] = FLOW[2] + (190,)
        for x, y in ((bx - 3, 29), (bx - 2, 29), (bx - 1, 29), (bx, 29), (bx + 1, 28), (bx - 4, 28)):
            px[(x, y)] = FOAM + (200,)

    # the pole, thicker at the butt, and the lashing at the fork
    rod(px, sx, sy + 1, lx, ly + 1, WOOD[3])
    rod(px, sx, sy, lx, ly, WOOD[1])
    rod(px, sx, sy, cx - 2, int(round((sy + cy) / 2.0)) if abs(sy - cy) > 3 else sy, WOOD[1])
    rod(px, sx, sy - 1, cx, cy - 1, WOOD[0])
    px[(lx, ly)] = ROPE[1]
    for x, y, c in ((cx - 1, cy - 1, ROPE[0]), (cx, cy - 1, ROPE[0]), (cx + 1, cy, ROPE[0]),
                    (cx - 1, cy, ROPE[1]), (cx, cy, ROPE[0]), (cx, cy + 1, ROPE[1]), (cx + 1, cy + 1, ROPE[1])):
        px[(x, y)] = c
    # the counterweight: a boulder roped under the butt
    wx, wy = sx - 0.5, sy + 3.2
    for y in range(SIZE):
        for x in range(SIZE):
            u, v = (x + 0.5 - wx - 0.5) / 3.3, (y + 0.5 - wy - 0.5) / 2.9
            if u * u + v * v <= 1.0:
                d = math.hypot(u + 0.45, v + 0.5)
                px[(x, y)] = ROCK[0] if d < 0.55 else ROCK[1] if d < 1.0 else ROCK[2] if d < 1.4 else ROCK[3]
    for y in range(sy, sy + 6):
        if (sx, y) in px and px[(sx, y)] in ROCK or y < sy + 2:
            px[(sx, y)] = ROPE[0] if y % 2 else ROPE[1]
    return image(px)


# --------------------------------------------------------- Archimedes screw

def screw_axes():
    (fx, fy), (hx, hy) = SCREW_FOOT, SCREW_HEAD
    length = math.hypot(hx - fx, hy - fy)
    ux, uy = (hx - fx) / length, (hy - fy) / length
    return length, (ux, uy), (-uy, ux)          # along, and across toward the lower right


def archimedes_screw(frame=None):
    """The screw; `frame` is None standing, else 0..3 turning."""
    px = {}
    turning = frame is not None
    phase = (frame if turning else 0) * SCREW_PITCH / USE_FRAMES
    length, (ux, uy), (vx, vy) = screw_axes()
    (fx, fy) = SCREW_FOOT

    def at(u, v):
        return fx + ux * u + vx * v, fy + uy * u + vy * v

    # the two trestles: a pair of crossed legs and a rail under each end
    for u, spread in ((7.5, 3), (20.0, 4)):
        tx, ty = at(u, SCREW_HALF)
        tx, ty = int(round(tx)), int(round(ty))
        ground_shadow(px, tx - spread, tx + spread + 1, 30)
        rod(px, tx + 2, ty - 2, tx - spread, 29, WOOD[2])
        rod(px, tx + 3, ty - 2, tx - spread + 1, 29, WOOD[3])
        rod(px, tx - 3, ty - 1, tx + spread - 1, 29, WOOD[0])
        rod(px, tx - 2, ty - 1, tx + spread, 29, WOOD[1])
        if 29 - ty > 8:
            rail = ty + (29 - ty) * 2 // 3
            for x in range(tx - spread + 1, tx + spread):
                px[(x, rail)] = WOOD[1]
                px[(x, rail + 1)] = WOOD[3]

    if turning:
        # the water it has raised, falling from the lip of the head
        lip_x, lip_y = at(length - 0.5, SCREW_HALF - 0.5)
        lip_x, lip_y = int(round(lip_x)), int(round(lip_y))
        for y in range(lip_y, 29):
            for i, x in enumerate((lip_x, lip_x + 1)):
                n = noise(x, y - 3 * frame, 571)
                c = FLOW[0] if n < 0.35 else FLOW[1] if n < 0.8 else FLOW[2]
                if i == 1 and (y + frame) % 4 == 0:
                    continue
                px[(x, y)] = c + (235,)
        splash = (((-1, 29), (2, 29), (0, 29), (3, 28)), ((0, 29), (1, 29), (-2, 28), (2, 29)),
                  ((-1, 29), (1, 29), (3, 29), (-1, 28)), ((0, 29), (2, 29), (-2, 29), (2, 28)))[frame]
        for dx, dy in splash:
            px[(lip_x + dx, dy)] = FOAM + (200,)

    # the trough: two rims, the dark inside, the blades of the helix
    bands = (1.0, length / 2.0, length - 1.2)
    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = x + 0.5 - fx - 0.5, y + 0.5 - fy - 0.5
            u, v = dx * ux + dy * uy, dx * vx + dy * vy
            if not (-0.5 <= u <= length + 0.3 and abs(v) <= SCREW_HALF):
                continue
            lit = v < 0                                  # the upper left rim faces the light
            if abs(v) > SCREW_HALF - 1.3:
                c = wood_tone(0 if lit else 2, int(u) // 3, lit, 573, 0.25)
                if not lit and v > SCREW_HALF - 0.6:
                    c = WOOD[3]
            else:
                turn = (u - phase + 1.3 * v) % SCREW_PITCH
                if turn < 1.7:
                    c = WOOD[0] if turn < 0.9 and v < 1.0 else WOOD[1]      # a blade
                elif turning and v > 0.4 and turn > SCREW_PITCH - 2.4:
                    c = FLOW[1] if v < 1.5 else FLOW[2]                      # water held behind the blade
                else:
                    c = WALL_SHADE[1] if v < 0.4 else WALL_SHADE[0]
            if any(abs(u - band) < 0.75 for band in bands):
                c = IRON[0] if v < -1.6 else IRON[3] if v > 1.9 else IRON[1] if v < 0.6 else IRON[2]
            px[(x, y)] = c

    # the crank on the end of the shaft: it swings across the axis as it turns
    hx, hy = at(length + 0.6, 0)
    ex, ey = at(length + 2.4, 0)
    hx, hy, ex, ey = int(round(hx)), int(round(hy)), int(round(ex)), int(round(ey))
    rod(px, hx, hy, ex, ey, IRON[1])
    throw = (-3.2, -3.2, 0.0, 3.2, 0.0)[0 if not turning else frame + 1]
    ax, ay = int(round(ex + vx * throw)), int(round(ey + vy * throw))
    rod(px, ex, ey, ax, ay, IRON[2])
    px[(ex, ey)] = IRON[0]
    if throw:
        grip = (1, -1) if throw < 0 else (-1, 1)
        px[(ax, ay)] = WOOD[0]
        px[(ax + grip[0], ay + grip[1])] = WOOD[1]
    else:
        # end on: toward us on one half turn, away on the other
        near = frame == 1
        px[(ex, ey)] = WOOD[0] if near else IRON[3]
        px[(ex + 1, ey + 1)] = WOOD[1] if near else IRON[2]
    if turning:
        # the foot stirs the water it stands in
        for dx, dy in (((-2, 2), (1, 4), (3, 4)), ((-1, 3), (2, 4), (-3, 1)),
                       ((-2, 3), (0, 4), (4, 4)), ((-3, 2), (1, 5), (2, 4)))[frame]:
            sx, sy = int(fx) + dx, min(int(fy) + dy, 29)
            if (sx, sy) not in px or px[(sx, sy)][:3] == SHADOW:
                px[(max(sx, MARGIN), sy)] = FOAM + (200,)
    return image(px)


# -------------------------------------------------------------- river gauge

GAUGE_X = (13, 18)                       # the 6px board
GAUGE_TOP, GAUGE_FOOT = 2, 28
GAUGE_BAND = 4


def river_gauge():
    px = {}
    x0, x1 = GAUGE_X
    for y in range(GAUGE_TOP, GAUGE_FOOT + 1):
        band, row = divmod(y - GAUGE_TOP - 2, GAUGE_BAND)
        for x in range(x0, x1 + 1):
            col = x - x0
            if y < GAUGE_TOP + 2:
                # the bare weathered head, cut to a point
                if y == GAUGE_TOP and col in (0, 5):
                    continue
                c = WOOD[0] if col < 2 else WOOD[1] if col < 5 else WOOD[3]
                px[(x, y)] = c
                continue
            dark = band % 2 == 1
            paint = (RED if band == 1 else BLACK) if dark else WHITE
            c = paint[0] if col < 4 else paint[1]
            if col == 0 and not dark:
                c = WHITE[0]
            if col == 5:
                c = BLACK[1] if dark else WHITE[1]
            # the tick at the top of each band, and a figure suggested beside it
            if row == 0 and col >= 3:
                c = WHITE[0] if dark else BLACK[0]
            if not dark and row == 2 and col == 1:
                c = BLACK[0]
            if not dark and row == 3 and col == 1 + band // 2 % 2:
                c = BLACK[0]
            # paint flaked off down to the wood, worse lower down
            wear = 0.015 + 0.05 * (y - GAUGE_TOP) / float(GAUGE_FOOT - GAUGE_TOP)
            if noise(x, y, 585) < wear:
                c = WOOD[2] if col < 5 else WOOD[3]
            # the river's mark on the foot
            if y >= GAUGE_FOOT - 5 and noise(x, y, 587) < 0.1 + 0.13 * (y - GAUGE_FOOT + 5):
                c = STAIN[0] if col < 4 else STAIN[1]
            px[(x, y)] = c
    px[(x0, GAUGE_TOP + 1)] = WOOD[0]
    # a split from the head, and the earth heaped where it was driven in
    for y in range(GAUGE_TOP + 1, GAUGE_TOP + 5):
        px[(x0 + 3, y)] = WOOD[3]
    for x, top in zip(range(x0 - 2, x1 + 4), (30, 29, 28, 28, 28, 28, 28, 28, 28, 29, 30)):
        for y in range(top, 31):
            if (x, y) in px and y < 29:
                continue
            c = RIM[0] if y == top and x <= x1 else BANK_SHADE[noise(x, y, 589) < 0.5]
            if y == 30:
                c = RIM[1]
            px[(x, y)] = c
    px[(x1 + 4, 30)] = SHADOW + (110,)
    px[(x1 + 5, 30)] = SHADOW + (70,)
    return image(px)


# ------------------------------------------------------------------ cistern

CISTERN = (2, 4, 29, 26)                 # the top of the walls, x0 y0 x1 y1
CISTERN_RIM = 4                          # a stone kerb, two of plaster and the lip
CISTERN_FILLS = 4
# rows of the plastered north wall that show inside, above the floor or the water
CISTERN_WALL = (5, 5, 3, 1)
GUTTER = (13, 18)                        # columns of the stone gutter from the north
DIP = (19, 24)                           # columns of the dipping lip on the south rim
PUDDLE = (16.0, 18.4, 6.4, 2.9)          # centre and radii of the puddle at level 1
# stains on the dry floor: centre, radii and tone
FLOOR_STAINS = ((8.0, 21.5, 1.6, 1.2, STAIN[0]), (9.5, 15.0, 2.2, 1.1, DAMP[0]), (23.5, 21.0, 1.8, 1.4, DAMP[0]),
                (24.0, 21.6, 1.0, 0.8, STAIN[0]))
# the still water in the tank is the settling tank's; nothing else on the piece uses these
CISTERN_WATER = set(CLEAR) | {CLEAR_SHADE, CLEAR_GLINT}


def cistern_inside():
    x0, y0, x1, y1 = CISTERN
    return x0 + CISTERN_RIM, y0 + CISTERN_RIM, x1 - CISTERN_RIM, y1 - CISTERN_RIM


def cistern(fill):
    px = {}
    x0, y0, x1, y1 = CISTERN
    ix0, iy0, ix1, iy1 = cistern_inside()
    # the top of the walls: a dressed stone kerb, the plaster carried over it
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if ix0 <= x <= ix1 and iy0 <= y <= iy1:
                continue
            reach = {'n': y - y0, 's': y1 - y, 'w': x - x0, 'e': x1 - x}
            side = min('nwse', key=lambda k: reach[k])
            ring = reach[side]
            along = x if side in 'ns' else y
            if ring == 0:
                c = SLAB[0] if side in 'nw' else SLAB[2] if side == 's' else SLAB_SHADE
                if (along + 2) % 7 == 0 and x not in (x0, x1) and y not in (y0, y1):
                    c = MORTAR
            elif ring == CISTERN_RIM - 1:
                # the lip: it drops into shade on the north and west and
                # catches the light on the south and east
                c = PLASTER[3] if side in 'nw' else PLASTER[0]
            else:
                c = PLASTER[0] if noise(x // 3, y // 2, 561) < 0.3 else PLASTER[1]
                if ring == 1 and side in 'nw':
                    c = PLASTER[0]
                if noise(x // 2, y // 2, 563) < 0.07:
                    c = PLASTER[2]                          # a worn patch
            px[(x, y)] = c
    for at in ((6, 6), (7, 6), (26, 12), (26, 13), (27, 14), (10, 24), (11, 24), (4, 19), (4, 20)):
        px[at] = PLASTER[3]                                 # hairline cracks

    # the inside: the north wall as far down as it shows, then floor or water
    wall = CISTERN_WALL[fill]
    top = iy0 + wall                                        # first row of the floor or the water
    for y in range(iy0, top):
        for x in range(ix0, ix1 + 1):
            c = PLASTER[4] if y == iy0 or x == ix0 else PLASTER[3]
            # the tide mark the water left along the wall
            if y == iy0 + 2 and x > ix0 and noise(x // 4, 0, 567) < 0.7:
                c = DAMP[0]
            px[(x, y)] = c
    cx, cy, rx, ry = PUDDLE
    for y in range(top, iy1 + 1):
        for x in range(ix0, ix1 + 1):
            grain = noise(x, y, 569)
            if fill >= 2:
                if fill == 2:
                    # deep in the shade of the walls
                    c = CLEAR[1] if grain < 0.6 else CLEAR[0]
                    if y <= top + 1 or x <= ix0 + 1:
                        c = CLEAR_SHADE
                    elif y == top + 2 and grain < 0.5:
                        c = CLEAR_SHADE
                else:
                    # up in the light
                    c = CLEAR[0] if grain < 0.55 else CLEAR[2] if grain < 0.8 else CLEAR[1]
                    if x == ix0:
                        c = CLEAR_SHADE
                    elif y == top or x == ix0 + 1:
                        c = CLEAR[1]
                    elif y == iy1 or x == ix1:
                        c = CLEAR[2]
                px[(x, y)] = c
                continue
            # the plaster floor, a little duller than the rim, and its stains
            c = PLASTER[2] if noise(x // 4, y // 3, 571) < 0.75 else PLASTER[1]
            if x == ix0:
                c = PLASTER[3]                              # shade at the foot of the west wall
            for sx, sy, srx, sry, tone in FLOOR_STAINS:
                if math.hypot((x - sx) / srx, (y - sy) / sry) < 1.0:
                    c = tone
            out = math.hypot((x - cx) / rx, (y - cy) / ry) + 0.25 * (noise(x // 2, y, 577) - 0.5)
            if fill == 0 and out < 1.05:
                # the pale scale and the ring where the last of it dried
                c = PLASTER[1] if out < 0.8 else DAMP[0] if y > cy - 1 else PLASTER[3]
            elif fill == 1 and out < 1.0:
                c = CLEAR[2] if out > 0.72 or grain < 0.3 else CLEAR[0]
            elif fill == 1 and out < 1.3:
                c = DAMP[1] if out < 1.15 else DAMP[0]      # wet plaster round the puddle
            px[(x, y)] = c
    if fill == 0:
        for at in ((20, 14), (21, 14), (22, 15), (22, 16)):
            px[at] = PLASTER[3]                             # a crack in the floor
    elif fill == 1:
        for at in ((14, 18), (15, 18), (18, 19)):
            px[at] = CLEAR_GLINT
    elif fill == 2:
        for at in ((11, 16), (12, 16), (20, 18), (21, 18), (15, 20)):
            px[at] = CLEAR[2]
        px[(16, 14)] = CLEAR_GLINT
    else:
        # ripples spreading from under the spout, and the sky on the water
        for at in ((13, 11), (14, 12), (15, 12), (16, 12), (17, 12), (18, 11),
                   (11, 13), (12, 14), (13, 15), (18, 15), (19, 14), (20, 13)):
            px[at] = CLEAR_GLINT if at[1] < 13 else CLEAR[2]
        for at in ((9, 18), (10, 18), (11, 18), (20, 19), (21, 19), (14, 21), (15, 21)):
            px[at] = CLEAR_GLINT

    # the south face: one course of dressed blocks in shade, as on the plinth
    for y in range(y1 + 1, SIZE - MARGIN - 1):
        row = y - y1 - 1
        for x in range(x0, x1 + 1):
            block, col = divmod(x - x0 + 2, 7)
            if col == 6 and x != x1 and row:
                c = MORTAR
            elif row == 0:
                c = SLAB_SHADE
            elif y == SIZE - MARGIN - 2:
                c = STONE_FOOT
            else:
                c = SLAB[3] if noise(block, 5, 579) < 0.65 else SLAB_SHADE
            if x == x0 and row:
                c = SLAB[2]
            if x == x1:
                c = STONE_FOOT
            px[(x, y)] = c
    ground_shadow(px, x0 + 1, x1, SIZE - MARGIN - 1)

    # the dipping lip: a stone set in the south rim, worn hollow where the
    # buckets go over it and standing a little proud of the wall
    dx0, dx1 = DIP
    for y in range(iy1 + 1, y1 + 2):
        for x in range(dx0, dx1 + 1):
            c = SLAB[1] if noise(x // 2, y, 581) < 0.7 else SLAB[2]
            if y == iy1 + 1:
                c = SLAB[0]
            if x == dx0:
                c = SLAB[0] if y <= y1 else SLAB[1]
            if x == dx1:
                c = SLAB_SHADE
            if y == y1 + 1:
                c = SLAB[2] if x < dx1 else SLAB_SHADE
            px[(x, y)] = c
    for x in range(dx0 + 2, dx1 - 1):
        for y in range(iy1 + 1, y1 + 1):
            # the hollow, wet when there is water
            px[(x, y)] = (STONE_FOOT if fill else SLAB_SHADE) if x == dx0 + 2 or y == iy1 + 1 else CHIP
    px[(dx0 + 1, y1 + 2)] = px[(dx1 - 1, y1 + 2)] = SLAB_SHADE     # its shadow on the face
    for x in range(dx0 + 2, dx1 - 1):
        px[(x, y1 + 2)] = SLAB_SHADE

    # the gutter from the roofs: two lines of kerb stones and a wet channel,
    # carried over the north wall to a spout
    gx0, gx1 = GUTTER
    for y in range(0, iy0 + 1):
        for x in range(gx0, gx1 + 1):
            if x in (gx0 + 2, gx1 - 2):
                c = WET if x == gx0 + 2 else STONE_FOOT
                if y == iy0:
                    c = WET
            else:
                c = {gx0: SLAB[0], gx0 + 1: SLAB[1], gx1 - 1: SLAB[2], gx1: SLAB_SHADE}[x]
                if y % 4 == 2 and y < y0:
                    c = MORTAR
                if y == iy0:
                    c = SLAB[2] if x < gx1 else SLAB_SHADE
            if y == iy0 and x in (gx0, gx1):
                continue                                    # the spout is narrower than the gutter
            px[(x, y)] = c
    # the green streak the spout has left down the wall
    for y in range(iy0 + 1, top):
        px[(gx0 + 2, y)] = STAIN[0]
        px[(gx0 + 3, y)] = STAIN[1] if y % 2 else STAIN[0]
    return image(px)


# ------------------------------------------------------------------- pumps

def brickwork(px, x0, y0, x1, y1, seed):
    """A brick wall seen from the side: two rows to a course and a bed joint,
    the perpends staggered, lit on the left and dark down the right edge."""
    for y in range(y0, y1 + 1):
        course, row = divmod(y1 - y, 3)
        for x in range(x0, x1 + 1):
            along = x - x0 + (3 if course % 2 else 0)
            if row == 2 or along % 6 == 5:
                c = BRICK_MORTAR
            else:
                tone = 1 if row == 1 else 2
                if noise(along // 6, course, seed) < 0.35:
                    tone += 1
                if x == x0:
                    tone = 0
                c = BRICK[tone]
            if x == x1 and x1 > x0:
                c = BRICK[4]
            px[(x, y)] = c


def falling_water(px, cols, y0, y1, frame, seed):
    for y in range(y0, y1 + 1):
        for x in cols:
            n = noise(x, y - 2 * frame, seed)
            px[(x, y)] = (FLOW[0] if n < 0.35 else FLOW[1] if n < 0.8 else FLOW[2]) + (235,)


# the lever pump: the handle turns on a bracket at the head of the barrel
LEVER_PIVOT = (17, 8)
LEVER_LONG, LEVER_SHORT = 10.5, 3.0
LEVER_REST = -40                         # degrees the grip is raised: hanging down
# (handle angle, what the spout is doing) for each working frame
LEVER_USE = ((28, 'drip'), (2, 'gush'), (-28, 'flood'), (10, 'trickle'))
LEVER_BARREL = (11, 16)                  # columns of the barrel
LEVER_BUCKET = (3, 9)


def lever_pump(frame=None):
    """The hand lever pump; `frame` is None standing, else 0..3 worked."""
    px = {}
    angle, doing = (LEVER_REST, 'rest') if frame is None else LEVER_USE[frame]
    a = math.radians(angle)
    cx, cy = LEVER_PIVOT
    lx, ly = int(round(cx + LEVER_LONG * math.cos(a))), int(round(cy - LEVER_LONG * math.sin(a)))
    sx, sy = int(round(cx - LEVER_SHORT * math.cos(a))), int(round(cy + LEVER_SHORT * math.sin(a)))
    bx0, bx1 = LEVER_BARREL

    # the stone it is bolted to, over the well
    ground_shadow(px, 4, 21, 30)
    for y in range(26, 30):
        for x in range(8, 21):
            c = (SLAB[0], SLAB[1], SLAB[3], STONE_FOOT)[y - 26]
            if y == 27 and noise(x // 3, 0, 611) < 0.3:
                c = SLAB[2]
            if x == 20 and y > 26:
                c = STONE_FOOT
            if x == 14 and y in (27, 28):
                c = MORTAR
            px[(x, y)] = c
    # the fluted barrel, with three collars cast on it
    flutes = (1, 0, 2, 0, 2, 3)
    for y in range(11, 26):
        for x, tone in zip(range(bx0, bx1 + 1), flutes):
            px[(x, y)] = IRON[tone]
    for y in (11, 18, 25):
        for x in range(bx0 - 1, bx1 + 2):
            px[(x, y)] = IRON[0] if x < bx1 - 1 else IRON[1] if x <= bx1 else IRON[3]
        if y < 25:
            for x in range(bx0, bx1 + 1):
                px[(x, y + 1)] = IRON[3] if x > bx0 + 1 else IRON[2]
    for x in range(bx0 + 1, bx1):                       # the domed head
        px[(x, 10)] = IRON[0] if x < bx1 - 1 else IRON[2]
    px[(bx0, 10)] = IRON[1]
    px[(bx1, 10)] = IRON[3]
    # the bracket the handle turns in
    for y in range(cy, 11):
        px[(cx, y)] = IRON[1]
        px[(cx + 1, y)] = IRON[3]
    # the spout, turned down over the bucket
    for x in range(7, bx0):
        px[(x, 14)], px[(x, 15)], px[(x, 16)] = IRON[0], IRON[1], IRON[3]
    px[(6, 15)], px[(6, 16)], px[(6, 17)], px[(7, 17)] = IRON[0], IRON[1], IRON[1], IRON[3]
    px[(6, 14)] = IRON[1]

    # the bucket under it: staves and two iron hoops
    kx0, kx1 = LEVER_BUCKET
    working = frame is not None
    for y in range(22, 30):
        for x in range(kx0, kx1 + 1):
            if y >= 28 and x in (kx0, kx1):
                continue                                 # it narrows to its foot
            col = x - kx0
            tone = 0 if col == 0 else 3 if col == kx1 - kx0 else 2 if col % 2 == 0 else 1
            c = WOOD[tone]
            if y in (24, 27):
                c = IRON[1] if col < kx1 - kx0 else IRON[3]
            if y == 22:
                c = WOOD[0] if col in (0, kx1 - kx0) else (FLOW[1 + (x + (frame or 0)) % 2] if working else WALL_SHADE[1])
            px[(x, y)] = c
    px[(kx0 + 1, 22)] = FLOW[0] if working else WALL_SHADE[0]

    # the water
    if doing == 'drip':
        px[(6, 19)] = FLOW[1] + (220,)
    elif doing == 'trickle':
        for y in (18, 19, 21):
            px[(6, y)] = FLOW[1] + (225,)
    elif doing in ('gush', 'flood'):
        falling_water(px, (6, 7) if doing == 'gush' else (5, 6, 7), 18, 21, frame, 613)
        px[(5 if doing == 'gush' else 4, 21)] = FOAM + (210,)
        px[(8, 21)] = FOAM + (210,)
        if doing == 'flood':
            for at in ((2, 22), (10, 21), (3, 20), (8, 19)):
                px[at] = FOAM + (200,)
            px[(kx0, 23)] = px[(kx0, 25)] = FLOW[1] + (220,)      # slopping over

    # the pump rod, from the short end of the handle down into the head
    for y in range(min(sy, 9), 10):
        px[(14, y)] = SLAB[0] if y % 2 else SLAB[1]
    # the handle: a long iron lever with a round grip
    rod(px, sx, sy + 1, lx, ly + 1, IRON[3])
    rod(px, sx, sy, lx, ly, IRON[1])
    px[(lx, ly)] = IRON[0]
    px[(lx, ly + 1)] = IRON[2]
    px[(lx + 1, ly)] = IRON[1]
    px[(lx + 1, ly + 1)] = IRON[3]
    px[(cx, cy)] = BRASS[0]                              # the pivot pin
    px[(sx, sy)] = BRASS[1]
    return image(px)


# the mine pump: a beam rocking on the bob wall of the engine house
MINE_PIVOT = (15, 7)
MINE_OUT, MINE_IN = 10.0, 8.0            # the pump arm and the engine arm of the beam
MINE_REST = -15                          # degrees the pump end is raised: down, out of steam
MINE_USE = (15, 0, -15, 0)
SMOKE = [(176, 174, 168), (132, 130, 126)]
COPPER = [(214, 142, 92), (176, 104, 64), (124, 68, 44)]


def mine_pump(frame=None):
    """The atmospheric beam engine; `frame` is None stopped, else 0..3 running."""
    px = {}
    running = frame is not None
    a = math.radians(MINE_USE[frame] if running else MINE_REST)
    cx, cy = MINE_PIVOT
    ox, oy = int(round(cx + MINE_OUT * math.cos(a))), int(round(cy - MINE_OUT * math.sin(a)))
    ex, ey = int(round(cx - MINE_IN * math.cos(a))), int(round(cy + MINE_IN * math.sin(a)))

    # smoke from the chimney, two puffs half a loop apart, drifting east
    if running:
        for k in range(2):
            age = (frame + 2 * k) % 4
            sx, sy = 3.6 + 2.1 * age, 1.6 - 0.35 * age
            radius = 1.3 + 0.4 * age
            for y in range(SIZE):
                for x in range(MARGIN, SIZE):
                    r = math.hypot(x - sx, (y - sy) * 1.15) + 0.9 * (noise(x, y, 621 + age) - 0.5)
                    if r <= radius:
                        alpha = (235, 200, 150, 105)[age]
                        px[(x, y)] = SMOKE[x - sx + y - sy > 0.6] + (alpha if r < radius - 0.9 else alpha * 2 // 3,)

    ground_shadow(px, 3, 19, 30)
    # the chimney
    brickwork(px, 2, 4, 5, 16, 623)
    for x, c in zip(range(1, 7), (SLAB[0], SLAB[0], SLAB[1], SLAB[1], SLAB[2], SLAB_SHADE)):
        px[(x, 3)] = c
    for x in (2, 3, 4, 5):
        px[(x, 2)] = BLACK[1] if x > 2 else BLACK[0]
    # the engine house, and the taller bob wall the beam rocks on
    brickwork(px, 2, 17, 12, 29, 625)
    brickwork(px, 12, 10, 17, 29, 627)
    for x in range(1, 12):                               # the slate lean-to roof
        px[(x, 15)] = IRON[0] if x % 3 else IRON[1]
        px[(x, 16)] = IRON[2] if x % 3 else IRON[3]
    for x, c in zip(range(11, 19), (SLAB[0], SLAB[0], SLAB[0], SLAB[1], SLAB[1], SLAB[1], SLAB[2], SLAB_SHADE)):
        px[(x, 9)] = c                                   # the stone the bearing sits on
    # the arched opening: the cylinder over its copper boiler and the fire
    for y in range(18, 29):
        for x in range(4, 10):
            if y == 18 and x in (4, 9):
                continue
            px[(x, y)] = SLOT
    for x in range(5, 9):
        px[(x, 17)] = BRICK[0] if x % 2 else BRICK[1]
    px[(4, 18)], px[(9, 18)] = BRICK[0], BRICK[2]
    for y in range(18, 22):
        for x, c in zip((5, 6, 7, 8), (IRON[1], IRON[0], IRON[1], IRON[3])):
            px[(x, y)] = c
    for x, c in zip((5, 6, 7, 8), (BRASS[1], BRASS[0], BRASS[1], BRASS[2])):
        px[(x, 19)] = c
    for y, cols in ((22, (5, 6, 7, 8)), (23, (4, 5, 6, 7, 8, 9)), (24, (4, 5, 6, 7, 8, 9))):
        for x in cols:
            px[(x, y)] = COPPER[0] if x <= 5 and y < 24 else COPPER[2] if x >= 8 or y == 24 and x > 6 else COPPER[1]
    px[(6, 22)] = COPPER[0]
    fill_box(px, 5, 26, 8, 28, IRON[3])
    px[(5, 25)] = px[(6, 25)] = px[(7, 25)] = px[(8, 25)] = IRON[2]
    if running:
        fire = ((EMBER[1], EMBER[0]), (EMBER[0], EMBER[1]), (EMBER[1], EMBER[2]), (EMBER[0], EMBER[0]))[frame]
        px[(6, 27)], px[(7, 27)] = fire
        px[(6, 28)], px[(7, 28)] = fire[1], EMBER[2]
        px[(6, 26)] = EMBER[2] if frame % 2 else EMBER[1]
    else:
        px[(6, 27)] = px[(7, 27)] = SLOT
    # a window in the bob wall
    px[(14, 16)] = px[(15, 16)] = px[(14, 17)] = px[(15, 17)] = SLOT
    px[(14, 15)] = px[(15, 15)] = BRICK[0]

    # the shaft: a timber collar round the dark mouth
    for x in range(22, 31):
        px[(x, 24)] = WOOD[2]
        for y in (25, 26):
            px[(x, y)] = SLOT if 22 < x < 30 else WOOD[1] if x == 22 else WOOD[3]
        px[(x, 27)], px[(x, 28)], px[(x, 29)] = WOOD[0], wood_tone(1, x // 3, 0, 629, 0.3), WOOD[3]
    px[(22, 27)] = px[(30, 27)] = NAIL
    ground_shadow(px, 23, 30, 30)
    # the outlet pipe from the rising main
    for x in range(19, 22):
        px[(x, 26)], px[(x, 27)] = IRON[0], IRON[2]
    px[(18, 26)], px[(18, 27)] = IRON[1], SLOT
    if running:
        strong = frame in (0, 3)                         # the bucket lifts as the pump end rises
        for y in (28, 29):
            px[(18, y)] = FLOW[(y + frame) % 2] + (235,)
        if strong:
            px[(19, 28)] = FLOW[1] + (220,)
            px[(19, 29)] = FLOW[2] + (220,)
        for x in ((17, 19, 20), (18, 20), (19, 20, 21), (17, 18, 20, 21))[frame]:
            px[(x, 30)] = (FOAM if (x + frame) % 2 else FLOW[1]) + (200,)

    # the chain from the engine end down through the roof to the piston
    for y in range(ey + 1, 15):
        px[(ex - 1, y)] = IRON[0] if y % 2 else IRON[2]
    # the pump rod from the other end down the shaft
    for y in range(oy + 1, 27):
        px[(ox + 1, y)] = WOOD[1] if y % 4 else IRON[1]
    # the beam: a heavy baulk, deeper over the pivot, with an arch head at each end
    rod(px, ex, ey + 1, ox, oy + 1, WOOD[3])
    rod(px, ex, ey, ox, oy, WOOD[1])
    rod(px, ex, ey - 1, ox, oy - 1, WOOD[0])
    for x in range(cx - 3, cx + 4):
        dy = int(round(-(x - cx) * math.tan(a)))
        px[(x, cy + dy - 2)] = WOOD[0]
        px[(x, cy + dy + 2)] = WOOD[3]
    for hx, hy, out in ((ox, oy, 1), (ex, ey, -1)):
        for dy in range(-2, 3):
            px[(hx + out, hy + dy)] = WOOD[2] if out > 0 else WOOD[0]
        px[(hx + out, hy - 2)] = IRON[1]
        px[(hx + out, hy + 2)] = IRON[3]
    px[(cx, cy)] = BRASS[0]
    px[(cx, cy + 1)] = BRASS[2]
    px[(cx - 1, cy + 1)] = px[(cx + 1, cy + 1)] = IRON[2]
    return image(px)


# the windmill pump: sails on the cap, a scoop wheel at the foot
MILL_HUB = (16, 9)
MILL_SAIL = 9.0                          # from the hub to the tip of a sail
MILL_REST = 45.0                         # the sails stand in a cross when the mill is idle
MILL_STEP = 22.5                         # a quarter of a quarter turn, so four frames loop
MILL_WHEEL = (26, 25)
MILL_WHEEL_R = 3.5
THATCH = [(176, 148, 88), (146, 120, 70), (116, 94, 56), (88, 70, 44)]
SAILCLOTH = [(238, 232, 212), (200, 192, 170)]


def windmill_pump(frame=None):
    """The polder mill; `frame` is None idle, else 0..3 turning."""
    px = {}
    turning = frame is not None
    ground_shadow(px, 11, 22, 30)
    # the brick base
    brickwork(px, 10, 24, 21, 29, 641)
    # the thatched smock, tapering up to the cap
    for y in range(11, 24):
        hw = 3.0 + 3.0 * (y - 11) / 12.0
        x0, x1 = int(round(16 - hw)), int(round(15 + hw))
        for x in range(x0, x1 + 1):
            t = (x - x0) / float(max(x1 - x0, 1))
            tone = 0 if t < 0.2 else 1 if t < 0.55 else 2 if t < 0.85 else 3
            if tone in (1, 2) and noise(x, y // 3, 643) < 0.25:
                tone += 1 if tone == 1 else -1
            px[(x, y)] = THATCH[tone]
    for x in range(10, 22):
        px[(x, 23)] = WOOD[3] if x > 18 else WOOD[2]     # the sill beam on the brick
    # the door and a window
    for y in range(18, 23):
        for x, c in zip((15, 16, 17), (PAINT[1], PAINT[2], PAINT[3])):
            px[(x, y)] = c
    px[(15, 17)] = px[(16, 17)] = px[(17, 17)] = WOOD[0]
    px[(17, 20)] = BRASS[0]
    px[(15, 14)] = px[(16, 14)] = SLOT
    px[(15, 13)] = px[(16, 13)] = WOOD[0]
    # the boarded cap
    for y, (x0, x1) in zip((6, 7, 8, 9, 10), ((14, 17), (13, 18), (12, 19), (12, 19), (12, 19))):
        for x in range(x0, x1 + 1):
            t = (x - x0) / float(x1 - x0)
            px[(x, y)] = WOOD[0] if t < 0.3 or y == 6 and t < 0.7 else WOOD[1] if t < 0.7 else WOOD[2]
        px[(x1, y)] = WOOD[3]
    for x in range(12, 20):
        px[(x, 10)] = WOOD[3] if x > 13 else WOOD[2]

    # the scoop wheel in its stone channel
    wx, wy = MILL_WHEEL
    spin = math.radians(MILL_STEP * (frame if turning else 0) + 12)
    px[(22, wy)] = IRON[1]                               # the shaft out of the base
    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = x - wx, y - wy
            r = math.hypot(dx, dy)
            if r > MILL_WHEEL_R + 0.3:
                continue
            if r > MILL_WHEEL_R - 0.9:
                c = WOOD[0] if dx + dy < -2 else WOOD[3] if dx + dy > 2 else WOOD[1]
            elif r < 0.8:
                c = IRON[1]
            else:
                off = min(abs(dx * math.sin(spin + q) - dy * math.cos(spin + q)) for q in (0.0, math.pi / 2))
                if off > 0.5:
                    c = WALL_SHADE[1]
                else:
                    c = WOOD[2]
            px[(x, y)] = c
    for y in (28, 29):
        px[(22, y)] = SLAB[1] if y == 28 else SLAB_SHADE
        px[(30, y)] = SLAB[2] if y == 28 else STONE_FOOT
        for x in range(23, 30):
            if turning:
                n = noise(x + frame * 2, y, 645)
                c = FOAM if n < 0.3 and y == 28 else FLOW[1] if n < 0.7 else FLOW[2]
            else:
                c = CLEAR_SHADE if y == 29 or noise(x, y, 647) < 0.4 else CLEAR[1]
            px[(x, y)] = c
    if turning:
        for at in (((30, 26), (29, 27), (23, 27)), ((30, 27), (28, 27), (30, 25)),
                   ((29, 26), (30, 27), (24, 27)), ((30, 26), (30, 24), (29, 27)))[frame]:
            px[at] = FOAM + (215,)
        px[(30, 28)] = FLOW[0]                           # spilling over the sill
        px[(30, 29)] = FLOW[1 + frame % 2]
        for x in ((27, 29), (26, 28, 30), (28, 29), (27, 30))[frame]:
            px[(x, 30)] = FLOW[1] + (200,)

    # the four lattice sails
    hx, hy = MILL_HUB
    base = math.radians(MILL_STEP * frame if turning else MILL_REST)
    for k in range(4):
        th = base + k * math.pi / 2
        ux, uy, vx, vy = math.cos(th), -math.sin(th), math.sin(th), math.cos(th)

        def at(u, v):
            return int(round(hx + ux * u + vx * v)), int(round(hy + uy * u + vy * v))

        # the sail bars and the hem lath, then the stock they hang on
        for u in (3.0, 5.0, 7.0, MILL_SAIL):
            rod(px, *(at(u, 1.0) + at(u, 2.5) + (SAILCLOTH[1],)))
        rod(px, *(at(3.0, 2.5) + at(MILL_SAIL, 2.5) + (SAILCLOTH[0],)))
        rod(px, *(at(1.0, 0.0) + at(MILL_SAIL, 0.0) + (WOOD[3],)))
    px[(hx, hy)] = IRON[0]
    return image(px)


# the sump pump: a pit, the motor standing in it, the riser, and a battery
SUMP_FRAMES, SUMP_DELAY = 3, 3
SUMP_PIT = (2, 14, 19, 26)               # the top of the pit walls, x0 y0 x1 y1
SUMP_WATER = (4, 18, 17, 24)             # the water showing inside it
SUMP_LED = (9, 8)
BLUE = [(158, 180, 204), (118, 142, 172), (84, 106, 136), (54, 70, 96)]
YELLOW = [(244, 214, 76), (204, 166, 44), (146, 112, 30)]
LED_ON = [(206, 255, 184), (88, 232, 96)]
LED_OFF = [(52, 104, 60), (34, 68, 42)]
FLOAT = [(250, 150, 60), (206, 96, 34)]


def sump_pump(frame=None):
    """The electric sump pump; `frame` is None stopped, else 0..2 running."""
    px = {}
    running = frame is not None
    x0, y0, x1, y1 = SUMP_PIT
    wx0, wy0, wx1, wy1 = SUMP_WATER
    ground_shadow(px, x0 + 1, x1 + 1, 30)
    # the concrete pit: the top of its walls, then the south face
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if x in (x0, x1) or y in (y0, y1):
                c = CONCRETE[0] if x == x0 or y == y0 else CONCRETE[2]
            else:
                c = CONCRETE[1] if noise(x // 2, y // 2, 661) < 0.75 else CONCRETE[2]
            px[(x, y)] = c
    for y in range(y1 + 1, 30):
        for x in range(x0, x1 + 1):
            c = CONCRETE[2] if y == y1 + 1 else CONCRETE[3]
            if y == 28 and noise(x // 3, 0, 663) < 0.5:
                c = CONCRETE[2]
            if x == x1:
                c = CONCRETE[3]
            px[(x, y)] = c
    # the inside: the north wall in shade, then the water
    for y in range(y0 + 2, wy1 + 1):
        for x in range(wx0, wx1 + 1):
            if y < wy0:
                c = CONCRETE[3] if y > y0 + 2 else IRON[2]
                if x == wx0:
                    c = IRON[2]
            else:
                n = noise(x, y, 665)
                c = CLEAR_SHADE if x == wx0 or y == wy0 or n < 0.45 else CLEAR[1]
            px[(x, y)] = c
    glints = (((6, 22), (12, 23), (16, 20)) if not running else
              (((5, 21), (6, 21), (11, 23), (16, 19), (15, 23), (9, 22)),
               ((5, 23), (10, 23), (11, 23), (16, 21), (6, 20), (13, 22)),
               ((4, 22), (8, 23), (15, 20), (16, 20), (12, 24), (6, 19)))[frame])
    for at in glints:
        px[at] = CLEAR_GLINT if running else CLEAR[2]
    if running:
        for x in range(6, 16):                           # the ring the motor makes on the water
            if (x + frame) % 3:
                px[(x, 22 if 7 < x < 14 else 21)] = CLEAR[2]

    # the leads from the battery, behind the riser
    rod(px, 23, 18, 19, 13, VALVE[1])
    rod(px, 19, 13, 14, 12, VALVE[1])
    rod(px, 28, 18, 24, 12, CABLE)
    rod(px, 24, 12, 14, 10, CABLE)

    # the battery: green case, yellow caps and a yellow band, two posts
    ground_shadow(px, 23, 30, 30)
    for y in range(19, 30):
        for x in range(22, 31):
            if y < 22:
                c = PAINT[0] if y > 19 or x < 30 else PAINT[1]
                if y == 20 and x in (24, 26, 28):
                    c = YELLOW[0]
                if y == 21 and x in (24, 26, 28):
                    c = YELLOW[2]
            else:
                c = PAINT[1] if x > 22 else PAINT[0]
                if y in (24, 25):
                    c = YELLOW[0] if y == 24 else YELLOW[1]
                if y == 22:
                    c = PAINT[2]
                if y == 29 or x == 30:
                    c = PAINT[3] if y not in (24, 25) else YELLOW[2]
            px[(x, y)] = c
    px[(27, 27)] = px[(28, 27)] = px[(26, 27)] = PAINT[3]         # the maker's mark
    for x, cap in ((23, VALVE[0]), (28, BLACK[0])):
        px[(x, 17)], px[(x + 1, 17)] = IRON[0], IRON[1]
        px[(x, 18)], px[(x + 1, 18)] = cap, cap

    # the motor: a round housing standing in the water
    tones = (1, 0, 0, 1, 1, 2, 2, 3)
    for y in range(9, 22):
        for x, tone in zip(range(7, 15), tones):
            if y == 21 and x in (7, 14):
                continue
            c = BLUE[tone]
            if y in (13, 14):
                c = IRON[min(tone, 3)] if y == 13 else IRON[min(tone + 1, 3)]   # the clamp band
            if y >= 19:
                c = IRON[3] if (x + y) % 2 else IRON[2]                         # the strainer
            px[(x, y)] = c
    for y, (ex0, ex1) in zip((6, 7, 8, 9), ((9, 12), (7, 14), (7, 14), (8, 13))):
        for x in range(ex0, ex1 + 1):
            px[(x, y)] = BLUE[0] if y < 9 else BLUE[1]
    px[(7, 7)] = px[(14, 7)] = BLUE[1]
    px[(14, 8)] = BLUE[2]
    for x in (10, 11, 12):                               # the carrying handle
        px[(x, 5)] = IRON[2]
    px[(9, 6)] = px[(13, 6)] = IRON[2]
    fill_box(px, 9, 16, 12, 17, YELLOW[0])               # the rating plate
    px[(12, 17)] = px[(11, 17)] = YELLOW[1]
    lx, ly = SUMP_LED
    lit = running and frame != 2
    px[(lx, ly)] = LED_ON[0] if lit else LED_OFF[0]
    px[(lx + 1, ly)] = LED_ON[1] if lit else LED_OFF[1]
    if running and frame == 0:
        for dx, dy in ((0, -1), (1, -1), (-1, 0), (2, 0), (0, 1), (1, 1)):
            px[(lx + dx, ly + dy)] = LED_ON[1]
        px[(lx, ly)] = px[(lx + 1, ly)] = LED_ON[0]

    # the float switch: an arm out to a float riding on the water
    rod(px, 7, 16, 5, 19, CABLE)
    fy = 20 if not running else (20, 19, 20)[frame]
    px[(4, fy)], px[(5, fy)] = FLOAT[0], FLOAT[1]
    px[(4, fy + 1)], px[(5, fy + 1)] = FLOAT[1], VALVE[2]

    # the discharge riser: out of the pump, up, and away east, with a check valve
    px[(15, 18)], px[(15, 19)] = WHITE[0], PLASTER[3]
    for y in range(1, 20):
        px[(16, y)], px[(17, y)] = WHITE[0], PLASTER[3]
    for x in range(16, 22):
        px[(x, 1)], px[(x, 2)] = WHITE[0], PLASTER[3]
    px[(21, 1)], px[(21, 2)] = PLASTER[2], PLASTER[4]
    for y in range(7, 12):
        for x, c in zip((15, 16, 17, 18), (BLACK[0], BLACK[0], BLACK[1], BLACK[1])):
            px[(x, y)] = c
    for y in (7, 11):
        for x, c in zip((15, 16, 17, 18), (IRON[0], SLAB[0], IRON[0], IRON[2])):
            px[(x, y)] = c
    px[(16, 9)] = WHITE[0]                               # the arrow moulded on the valve
    px[(16, 8)] = px[(16, 10)] = IRON[1]

    # the mains cord, over the rim to a plug lying on the ground
    rod(px, 8, 8, 5, 6, CABLE)
    rod(px, 5, 6, 3, 8, CABLE)
    rod(px, 3, 8, 3, 10, CABLE)
    fill_box(px, 2, 10, 4, 11, IRON[2])
    px[(2, 10)] = px[(3, 10)] = IRON[1]
    px[(2, 12)] = px[(4, 12)] = BRASS[0]
    return image(px)


# -------------------------------------------------------------------- sheet

CISTERNS = tuple('cistern%d' % fill for fill in range(CISTERN_FILLS))
# the pumps: (state, drawing, working state, frames, delay in ds)
PUMPS = (('lever_pump', lever_pump, 'lever_pump_use', USE_FRAMES, USE_DELAY),
         ('mine_pump', mine_pump, 'mine_pump_on', 4, 3),
         ('windmill_pump', windmill_pump, 'windmill_pump_on', 4, 2),
         ('sump_pump', sump_pump, 'sump_pump_on', SUMP_FRAMES, SUMP_DELAY))
STILLS = ('stilts', 'plinth', 'sluice_gate', 'sluice_gate_open', 'shaduf', 'archimedes_screw',
          'river_gauge') + CISTERNS + tuple(pump[0] for pump in PUMPS)
# every working loop: (standing state, working state, frames, delay in ds)
LOOPS = (('shaduf', 'shaduf_use', USE_FRAMES, USE_DELAY),
         ('archimedes_screw', 'archimedes_screw_use', USE_FRAMES, USE_DELAY)) + tuple(
             (still, name, frames, delay) for still, _, name, frames, delay in PUMPS)


def build():
    """The whole sheet as [(state, keys, images)]."""
    one = {'dirs': '1', 'frames': '1'}
    use = loop(USE_FRAMES, USE_DELAY)
    states = [('stilts', dict(one), [stilts()]),
            ('plinth', dict(one), [plinth()]),
            ('sluice_gate', dict(one), [sluice_gate()]),
            ('sluice_gate_open', dict(one), [sluice_gate(True)]),
            ('shaduf', dict(one), [shaduf()]),
            ('shaduf_use', dict(use), [shaduf(frame) for frame in range(USE_FRAMES)]),
            ('archimedes_screw', dict(one), [archimedes_screw()]),
            ('archimedes_screw_use', dict(use), [archimedes_screw(frame) for frame in range(USE_FRAMES)]),
            ('river_gauge', dict(one), [river_gauge()])] + [
               (name, dict(one), [cistern(fill)]) for fill, name in enumerate(CISTERNS)]
    # the pumps, appended so the earlier states keep their place in the sheet
    for still, draw, name, frames, delay in PUMPS:
        states.append((still, dict(one), [draw()]))
        states.append((name, loop(frames, delay), [draw(frame) for frame in range(frames)]))
    return states


def check_drawing(states):
    """Rules the drawing itself must keep, whatever the palettes become."""
    by = {name: images for name, _, images in states}
    keys_of = {name: keys for name, keys, _ in states}
    problems = []
    want = list(STILLS) + [name for _, name, _, _ in LOOPS]
    if sorted(by) != sorted(want) or len(states) != len(want):
        problems.append('state list is %s' % ', '.join(name for name, _, _ in states))
    for name, keys, images in states:
        if len(images) != int(keys['dirs']) * int(keys['frames']):
            problems.append('%s has %d images for its dirs and frames' % (name, len(images)))
        for im in images:
            if im.size != (SIZE, SIZE):
                problems.append('%s is not %dpx' % (name, SIZE))
                break
            if any(p[3] == 0 and p != (0, 0, 0, 0) for p in pixels(im)):
                problems.append('%s has coloured invisible pixels' % name)
                break
            box = im.getbbox()
            if box is None or box[0] < MARGIN or box[2] > SIZE - MARGIN or box[3] > SIZE - MARGIN:
                problems.append('%s does not keep its margin: %r' % (name, box))
                break
            if sum(1 for p in pixels(im) if p[3]) < 60:
                problems.append('%s is nearly empty' % name)
                break
    for name in STILLS:
        if name in by and keys_of[name] != {'dirs': '1', 'frames': '1'}:
            problems.append('%s is not a single frame' % name)
    for still, name, frames, delay in LOOPS:
        if name not in by or still not in by:
            continue
        if keys_of[name] != loop(frames, delay) or len(by[name]) != frames:
            problems.append('%s is not %d frames of %d ds' % (name, frames, delay))
        shots = [pixels(im) for im in by[name]]
        if any(shots[i] == shots[j] for i in range(len(shots)) for j in range(i)):
            problems.append('%s repeats a frame' % name)
        if pixels(by[still][0]) in shots:
            problems.append('%s looks the same standing and working' % still)
        # the machine stands still: only the moving parts may differ
        moved = sum(1 for spot in zip(pixels(by[still][0]), *shots) if len(set(spot)) > 1)
        if moved > SIZE * SIZE * 2 // 5:
            problems.append('%s moves more than its working parts' % name)
    # the pumps raise water, or show a lamp, only when they are working
    wet = set(FLOW)
    for still, _, name, _, _ in PUMPS:
        if name not in by or still not in by:
            continue
        signs = set(LED_ON) if still == 'sump_pump' else wet
        if signs & {p[:3] for p in pixels(by[still][0]) if p[3]}:
            problems.append('%s looks as if it is working' % still)
        if still == 'sump_pump':
            if sum(1 for im in by[name] if signs & {p[:3] for p in pixels(im) if p[3]}) not in (1, 2):
                problems.append('%s lamp does not blink' % name)
        elif any(not signs & {p[:3] for p in pixels(im) if p[3]} for im in by[name]):
            problems.append('%s has a frame with no water' % name)
    if 'sluice_gate' in by and 'sluice_gate_open' in by:
        shut, opened = by['sluice_gate'][0].load(), by['sluice_gate_open'][0].load()
        gap = [(x, y) for y in range(OPEN_TOP + OPEN_BOARDS * BOARD, RACE_TOP - 1)
               for x in range(GATE_X[0], GATE_X[1] + 1)]
        if sum(1 for at in gap if opened[at][3]) > len(gap) // 6:
            problems.append('sluice_gate_open is not open under the boards')
        if any(not shut[at][3] for at in gap):
            problems.append('sluice_gate has a hole in its boards')
        water = {c + (235,) for c in FLOW}
        if not water & set(pixels(by['sluice_gate_open'][0])) or water & set(pixels(by['sluice_gate'][0])):
            problems.append('water should run through the open sluice only')
    # players stand on the deck and the slab: no holes in either
    for name, (x0, y0, x1, y1) in (('stilts', DECK), ('plinth', SLABTOP)):
        if name in by:
            px = by[name][0].load()
            if any(px[x, y][3] != 255 for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)):
                problems.append('%s has a hole in its floor' % name)
    # the cistern: a sound tank, and more water showing at every level
    x0, y0, x1, y1 = CISTERN
    ix0, iy0, ix1, iy1 = cistern_inside()
    wet = []
    for name in CISTERNS:
        if name not in by:
            continue
        px = by[name][0].load()
        if any(px[x, y][3] != 255 for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)):
            problems.append('%s has a hole in it' % name)
        water = [(x, y) for y in range(SIZE) for x in range(SIZE) if px[x, y][:3] in CISTERN_WATER and px[x, y][3]]
        if any(not (ix0 <= x <= ix1 and iy0 <= y <= iy1) for x, y in water):
            problems.append('%s has water outside the tank' % name)
        wet.append(len(water))
    if len(wet) == CISTERN_FILLS:
        if wet[0] or any(a >= b for a, b in zip(wet, wet[1:])):
            problems.append('cistern water does not grow with the level: %r' % wet)
        if wet[-1] < (ix1 - ix0 + 1) * (iy1 - iy0 + 1) * 4 // 5:
            problems.append('cistern3 is not full to the brim')
    shots = [pixels(by[name][0]) for name in CISTERNS if name in by]
    if any(shots[i] == shots[j] for i in range(len(shots)) for j in range(i)):
        problems.append('two cistern levels look the same')
    return problems


# ------------------------------------------------------------------- review

def levee_tile(gap=False):
    """A stand-in earth bank running east-west, for the review scenes only."""
    px = {}
    for y in range(4, 31):
        for x in range(SIZE):
            if gap and 3 < x < 28:
                continue
            if y < 7:
                c = RIM[0]
            elif y < 15:
                c = BANK_LIT[noise(x, y, 601) < 0.4]
            elif y < 26:
                c = BANK_SHADE[noise(x, y, 603) < 0.4] if y > 19 else BANK_LIT[1]
            else:
                c = RIM[1]
            px[(x, y)] = c
    return image(px)


SCENE = (6, 4)                           # tiles in a review scene


def flood_scene(by, n):
    """A river behind a levee with the sluice in it, stilts, a plinth and a
    gauge on the dry side, and a pond worked by both machines; n = 1 has the
    sluice open and the machines working."""
    grass, dirt = ground_tiles()
    water = Image.new('RGBA', (SIZE, SIZE), RIVER + (255,))
    scene_w, scene_h = SCENE
    label, gate, sweep, screw = (
        ('shut sluice in a levee; stilts, plinth, gauge; shaduf and screw at a pond',
         'sluice_gate', by['shaduf'][0], by['archimedes_screw'][0]),
        ('sluice open, shaduf dipping, screw turning',
         'sluice_gate_open', by['shaduf_use'][1], by['archimedes_screw_use'][1]))[n]
    scene = Image.new('RGBA', (scene_w * SIZE, scene_h * SIZE))
    for ty in range(scene_h):
        for tx in range(scene_w):
            scene.paste(water if ty == 0 or (ty == 3 and tx in (2, 3)) else grass, (tx * SIZE, ty * SIZE))
    for tx in range(scene_w):
        at = (tx * SIZE, SIZE)
        if tx == 2:
            scene.paste(water if n else dirt, at)
            scene.alpha_composite(levee_tile(True), at)
            scene.alpha_composite(by[gate][0], at)
        else:
            scene.alpha_composite(levee_tile(), at)
    for tx, ty, name in ((0, 2, 'stilts'), (1, 2, 'stilts'), (3, 2, 'plinth'), (4, 2, 'plinth'),
                         (5, 2, 'river_gauge'), (0, 3, 'river_gauge')):
        scene.alpha_composite(by[name][0], (tx * SIZE, ty * SIZE))
    scene.alpha_composite(by['river_gauge'][0], (4 * SIZE + 6, 2 * SIZE - 8))
    # the shaduf stands on the bank with its bucket over the pond, and
    # the screw has its foot in the water from the other bank
    scene.alpha_composite(sweep, (1 * SIZE + 4, 3 * SIZE))
    scene.alpha_composite(screw, (4 * SIZE - 6, 3 * SIZE))
    return label, scene


def cistern_scene(by):
    """A yard with the four cisterns in a row, each fed by a stone drain,
    beside a plinth, the sewer sheet's settling and septic tanks and a brick
    sewer, to see the cistern with its neighbours."""
    grass, dirt = ground_tiles()
    scene_w, scene_h = SCENE
    scene = Image.new('RGBA', (scene_w * SIZE, scene_h * SIZE))
    for ty in range(scene_h):
        for tx in range(scene_w):
            scene.paste(dirt if ty in (1, 2) else grass, (tx * SIZE, ty * SIZE))
    for fill, name in enumerate(CISTERNS):
        scene.alpha_composite(stone_drain(3), (fill * SIZE, 0))
        scene.alpha_composite(by[name][0], (fill * SIZE, SIZE))
    for tx, ty, im in ((4, 1, by['plinth'][0]), (5, 1, by['plinth'][0]), (0, 2, settling(0)), (1, 2, settling(2)),
                       (2, 2, septic(0)), (3, 2, by['cistern3'][0]), (4, 2, by['stilts'][0]),
                       (5, 2, by['river_gauge'][0])):
        scene.alpha_composite(im, (tx * SIZE, ty * SIZE))
    for tx in range(scene_w):
        scene.alpha_composite(brick_drain(12), (tx * SIZE, 3 * SIZE))
    return 'cisterns 0-3 under stone drains; plinth; settling, septic, cistern3, stilts, gauge; brick sewer', scene


def pump_scene(by, n):
    """The four pumps in a row by a river with the sewer sheet's two pumps
    beside them, and the older machines below; n = 1 has them all working."""
    grass, dirt = ground_tiles()
    water = Image.new('RGBA', (SIZE, SIZE), RIVER + (255,))
    scene_w, scene_h = SCENE
    scene = Image.new('RGBA', (scene_w * SIZE, scene_h * SIZE))
    for ty in range(scene_h):
        for tx in range(scene_w):
            scene.paste(water if ty == 0 else dirt if ty == 2 else grass, (tx * SIZE, ty * SIZE))
    for ty in (1, 2):
        for tx, (still, _, name, _, _) in enumerate(PUMPS):
            scene.alpha_composite(by[name][1] if n else by[still][0], (tx * SIZE, ty * SIZE))
        scene.alpha_composite(pump_steam(1 if n else None), (4 * SIZE, ty * SIZE))
        scene.alpha_composite(pump_electric(1 if n else None), (5 * SIZE, ty * SIZE))
    for tx, im in enumerate((by['shaduf_use'][1] if n else by['shaduf'][0],
                             by['archimedes_screw_use'][1] if n else by['archimedes_screw'][0],
                             by['cistern2'][0], by['sluice_gate_open' if n else 'sluice_gate'][0],
                             by['river_gauge'][0], by['plinth'][0])):
        scene.alpha_composite(im, (tx * SIZE, 3 * SIZE))
    return ('lever, mine, windmill, sump, sewer steam and electric pumps %s; older pieces'
            % ('working' if n else 'standing')), scene


PREVIEW_WRAP = 12                        # tiles to a row of the review sheet


def write_preview(path, states, scale=4, only=None):
    by = {name: images for name, _, images in states}
    only = tuple(only.split(',')) if only else None
    grass, dirt = ground_tiles()
    label_h, pad = 12, 6
    cell = SIZE * scale
    shots = []                                   # (label, image) in sheet order
    for name, _, images in states:
        if only and not name.startswith(only):
            continue
        for n, im in enumerate(images):
            shots.append((name if len(images) == 1 else '%s %d' % (name.replace('archimedes_', ''), n), im))
    cols = min(len(shots), PREVIEW_WRAP)
    bands = (len(shots) + PREVIEW_WRAP - 1) // PREVIEW_WRAP          # the shots wrap onto more rows
    scene_w, scene_h = SCENE
    # the scenes: (first state it shows, what draws it)
    scenes = [(name, draw_scene) for name, draw_scene in (
        ('sluice_gate', lambda: flood_scene(by, 0)), ('sluice_gate_open', lambda: flood_scene(by, 1)),
        ('cistern0', lambda: cistern_scene(by)), ('lever_pump', lambda: pump_scene(by, 0)),
        ('mine_pump', lambda: pump_scene(by, 1))) if not only or name.startswith(only)]
    scene_cols = max(1, (cols * (cell + pad)) // (scene_w * cell + pad))
    scene_rows = (len(scenes) + scene_cols - 1) // scene_cols
    game_rows = (2 * len(shots) + 1) * (SIZE + 2) // (cols * (cell + pad)) + 1
    wide = pad + max(cols * (cell + pad), min(len(scenes), scene_cols) * (scene_w * cell + pad))
    high = (pad + 2 * bands * (cell + label_h + pad) + label_h + game_rows * (SIZE + 2) + pad
            + scene_rows * (scene_h * cell + label_h + pad))
    sheet = Image.new('RGB', (wide, high), DARK)
    draw = ImageDraw.Draw(sheet)

    def tile(layers):
        im = Image.new('RGBA', (SIZE, SIZE))
        for layer in layers:
            im.alpha_composite(layer)
        return im

    for shot, (label, im) in enumerate(shots):
        band, col = divmod(shot, PREVIEW_WRAP)
        for row, ground in enumerate((grass, dirt)):
            x, y = pad + col * (cell + pad), pad + (2 * band + row) * (cell + label_h + pad)
            big = tile([ground, im]).convert('RGB').resize((cell, cell), Image.NEAREST)
            sheet.paste(big, (x, y + label_h))
            draw.text((x, y), label if row == 0 else 'dirt', fill=(220, 220, 220))
    # the same at game size
    ay = pad + 2 * bands * (cell + label_h + pad)
    draw.text((pad, ay), 'at game size', fill=(220, 220, 220))
    per_row = cols * (cell + pad) // (SIZE + 2)
    small = [tile([grass, im]) for _, im in shots] + [None] + [tile([dirt, im]) for _, im in shots]
    for n, im in enumerate(small):
        if im is not None:
            sheet.paste(im.convert('RGB'), (pad + n % per_row * (SIZE + 2), ay + label_h + n // per_row * (SIZE + 2)))

    top = ay + label_h + game_rows * (SIZE + 2) + pad
    for n, (_, draw_scene) in enumerate(scenes):
        label, scene = draw_scene()
        x = pad + n % scene_cols * (scene_w * cell + pad)
        if n >= scene_cols:
            top_n = top + n // scene_cols * (scene_h * cell + label_h + pad)
        else:
            top_n = top
        top, keep = top_n, top
        big = scene.convert('RGB').resize((scene.width * scale, scene.height * scale), Image.NEAREST)
        sheet.paste(big, (x, top + label_h))
        draw.text((x, top), label, fill=(220, 220, 220))
        top = keep
    sheet.save(path)


def main():
    states = build()
    problems = check_drawing(states)
    if '--check' in sys.argv:
        problems += check_sheet(option('--sheet') or SHEET, states)
        for line in problems:
            print(line)
        print('flood defences: %s' % ('FAILED' if problems else 'ok'))
        return 1 if problems else 0
    if problems:
        print('\n'.join(problems))
        return 1
    write_dmi(option('--out') or SHEET, states)
    if option('--preview'):
        write_preview(option('--preview'), states, only=option('--preview-only'))
    return 0


if __name__ == '__main__':
    sys.exit(main())
