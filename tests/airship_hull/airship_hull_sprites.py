"""Draw the buildable airship's sprites (original pixel art, no generated images).

icons/obj/vehicles/airship_hull.dmi, 32x32: "helm" (4 directions, the wheel
faces the bow), the inventory items "gas_cell_folded", "airship_planks"
and "helm_kit", the deck fittings "bomb_hatch" and "bomb_hatch_open", the metal
framing bundles "aluminium_frame" and "steel_frame", the metal deck floors
"airship_deck_aluminium" and "airship_deck_steel", and the folded cells of
the other two fabrics, "gas_cell_folded_rubber" and "gas_cell_folded_skin".

icons/obj/vehicles/airship_gas_cell.dmi, 64x64: "gas_cell", "gas_cell_holed",
"gas_cell_burnt" and "gas_cell_empty", then the same full, holed and empty
states for rubberised cloth ("gas_cell_rubber...") and goldbeater's skin
("gas_cell_skin..."); a burnt cell of any fabric is "gas_cell_burnt". The game draws the cell with pixel_x = -16 and
pixel_y = 12, so its deck tile is under the bottom middle of the sheet and
the rigging lines meet there.

The palette and line weight follow tests/pedal_bicycle/airship_sprites.py so
the parts sit beside the pedal airship.

    python3 tests/airship_hull/airship_hull_sprites.py            # rewrite both DMIs
    python3 tests/airship_hull/airship_hull_sprites.py --check    # fail when one is stale
    python3 tests/airship_hull/airship_hull_sprites.py --preview out.png
    python3 tests/airship_hull/airship_hull_sprites.py --hatch-preview out.png

tests/gas_works/gas_works_sprites.py --preview shows the material states.
"""
from pathlib import Path
import sys

from PIL import Image, ImageDraw
from PIL.PngImagePlugin import PngInfo

ROOT = Path(__file__).resolve().parents[2]
HULL = ROOT / 'icons/obj/vehicles/airship_hull.dmi'
CELL = ROOT / 'icons/obj/vehicles/airship_gas_cell.dmi'

# Shared with the pedal airship.
CANVAS = (226, 214, 180, 255)
CANVAS_SHADE = (196, 180, 140, 255)
CANVAS_LINE = (132, 114, 80, 255)
ROPE = (96, 82, 62, 255)
WOOD = (92, 62, 36, 255)
STEEL = (120, 124, 132, 255)
STEEL_DARK = (78, 82, 90, 255)
# Added for the hull parts.
CANVAS_LIGHT = (240, 232, 206, 255)
CANVAS_DARK = (166, 148, 108, 255)
ROPE_LIGHT = (140, 122, 92, 255)
WOOD_DARK = (58, 38, 22, 255)
WOOD_MID = (124, 86, 50, 255)
WOOD_LIGHT = (158, 114, 64, 255)
WOOD_PALE = (190, 146, 90, 255)
PLANK = (202, 166, 112, 255)
PLANK_SHADE = (168, 130, 82, 255)
PLANK_LINE = (112, 80, 46, 255)
BRASS = (204, 166, 72, 255)
BRASS_LIGHT = (238, 212, 124, 255)
BRASS_DARK = (132, 100, 38, 255)
GLASS = (214, 230, 226, 255)
HOLE = (58, 46, 36, 255)
CHAR = (38, 32, 30, 255)
CHAR_MID = (66, 50, 40, 255)
CHAR_BROWN = (98, 72, 50, 255)
SCORCH = (150, 126, 90, 255)
CLEAR = (0, 0, 0, 0)


def blank(size):
    return Image.new('RGBA', (size, size), CLEAR)


def mirrored(im):
    return im.transpose(Image.FLIP_LEFT_RIGHT)


# --- helm -----------------------------------------------------------------

def binnacle(d, x, y):
    """Brass compass dome on a short wooden pedestal; (x, y) is its top left."""
    d.rectangle((x + 1, y + 6, x + 6, y + 15), fill=WOOD_LIGHT, outline=WOOD_DARK)
    d.line((x + 2, y + 8, x + 2, y + 14), fill=WOOD_PALE)
    d.line((x + 5, y + 8, x + 5, y + 14), fill=WOOD_MID)
    d.line((x, y + 15, x + 7, y + 15), fill=WOOD_DARK)
    d.pieslice((x, y, x + 7, y + 11), 180, 360, fill=BRASS, outline=BRASS_DARK)
    d.line((x, y + 6, x + 7, y + 6), fill=BRASS_DARK)
    d.rectangle((x + 3, y + 3, x + 4, y + 4), fill=GLASS)
    d.point((x + 2, y + 2), fill=BRASS_LIGHT)
    d.point((x + 3, y), fill=BRASS_DARK)
    d.point((x + 4, y), fill=BRASS_DARK)


def post(d, left, top):
    d.rectangle((left, top, left + 4, 28), fill=WOOD_LIGHT, outline=WOOD_DARK)
    d.line((left + 1, top + 1, left + 1, 27), fill=WOOD_PALE)
    d.line((left + 3, top + 1, left + 3, 27), fill=WOOD_MID)
    d.rectangle((left - 2, 28, left + 6, 29), fill=WOOD_MID, outline=WOOD_DARK)


def wheel(d, cx, cy):
    """Eight-spoke ship's wheel seen face on."""
    for dx, dy in ((0, -10), (0, 10), (-10, 0), (10, 0), (-7, -7), (7, -7), (-7, 7), (7, 7)):
        d.line((cx, cy, cx + dx, cy + dy), fill=WOOD_LIGHT)
        d.point((cx + dx, cy + dy), fill=WOOD_DARK)
    d.ellipse((cx - 8, cy - 8, cx + 8, cy + 8), outline=WOOD_DARK)
    d.ellipse((cx - 7, cy - 7, cx + 7, cy + 7), outline=WOOD_LIGHT)
    d.arc((cx - 7, cy - 7, cx + 7, cy + 7), 190, 320, fill=WOOD_PALE)
    d.ellipse((cx - 2, cy - 2, cx + 2, cy + 2), fill=BRASS, outline=BRASS_DARK)
    d.point((cx - 1, cy - 1), fill=BRASS_LIGHT)


def helm_front(from_behind):
    """Bow to the south: wheel face on, binnacle on the ship's port side."""
    im = blank(32)
    d = ImageDraw.Draw(im)
    binnacle(d, 23, 13)
    if from_behind:
        wheel(d, 13, 11)
        post(d, 11, 9)
        d.rectangle((12, 10, 14, 12), fill=STEEL_DARK)
        d.point((13, 11), fill=STEEL)
    else:
        post(d, 11, 14)
        wheel(d, 13, 11)
    return im


def helm_side(binnacle_near):
    """Bow to the east: wheel edge on, on the bow side of its post."""
    im = blank(32)
    d = ImageDraw.Draw(im)
    if not binnacle_near:
        binnacle(d, 20, 8)
    post(d, 10, 9)
    d.rectangle((15, 10, 16, 12), fill=STEEL_DARK)
    # Handles above and below, then the rim seen edge on.
    d.rectangle((17, 0, 18, 22), fill=WOOD_LIGHT, outline=WOOD_DARK)
    d.rounded_rectangle((16, 2, 19, 20), radius=1, fill=WOOD_LIGHT, outline=WOOD_DARK)
    d.line((17, 3, 17, 19), fill=WOOD_PALE)
    d.line((18, 3, 18, 19), fill=WOOD_MID)
    d.rectangle((19, 10, 20, 12), fill=BRASS, outline=BRASS_DARK)
    d.point((20, 11), fill=BRASS_LIGHT)
    if binnacle_near:
        binnacle(d, 20, 15)
    return im


# --- inventory items --------------------------------------------------------

def rope_band(d, x, top, bottom):
    d.line((x, top, x, bottom), fill=ROPE)
    d.line((x + 1, top, x + 1, bottom), fill=ROPE_LIGHT)
    for y in range(top + 1, bottom, 2):
        d.point((x + 1, y), fill=ROPE)


def gas_cell_folded():
    im = blank(32)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((3, 10, 27, 23), radius=4, fill=CANVAS, outline=CANVAS_LINE)
    d.line((6, 11, 23, 11), fill=CANVAS_LIGHT)
    d.line((5, 12, 22, 12), fill=CANVAS_LIGHT)
    d.rectangle((5, 19, 24, 22), fill=CANVAS_SHADE)
    d.line((7, 23, 23, 23), fill=CANVAS_LINE)
    d.line((5, 16, 21, 16), fill=CANVAS_SHADE)
    # Rolled end with its spiral.
    d.ellipse((20, 10, 28, 23), fill=CANVAS_SHADE, outline=CANVAS_LINE)
    d.arc((22, 12, 26, 21), 0, 300, fill=CANVAS_LINE)
    d.point((24, 16), fill=CANVAS_LINE)
    d.point((24, 17), fill=CANVAS_DARK)
    # Loose corner of the cloth.
    d.polygon(((3, 21), (1, 25), (6, 24)), fill=CANVAS_SHADE, outline=CANVAS_LINE)
    rope_band(d, 8, 10, 23)
    rope_band(d, 16, 10, 23)
    d.rectangle((11, 8, 13, 10), fill=ROPE_LIGHT, outline=ROPE)
    d.line((9, 10, 16, 10), fill=ROPE)
    d.line((14, 8, 15, 6), fill=ROPE)
    return im


def airship_planks():
    im = blank(32)
    d = ImageDraw.Draw(im)
    # Three planks across the top, two layers showing on the near side.
    d.rectangle((3, 10, 28, 17), fill=PLANK, outline=PLANK_LINE)
    d.line((4, 13, 27, 13), fill=PLANK_SHADE)
    d.line((4, 15, 27, 15), fill=PLANK_SHADE)
    d.line((4, 11, 27, 11), fill=CANVAS_LIGHT)
    d.rectangle((3, 17, 28, 23), fill=PLANK_SHADE, outline=PLANK_LINE)
    d.line((4, 20, 27, 20), fill=PLANK_LINE)
    # Uneven ends.
    d.rectangle((28, 12, 30, 14), fill=PLANK, outline=PLANK_LINE)
    d.rectangle((1, 17, 3, 20), fill=PLANK_SHADE, outline=PLANK_LINE)
    for x, y in ((12, 18), (20, 22), (15, 21), (24, 19), (7, 22)):
        d.line((x, y, x + 2, y), fill=WOOD_LIGHT)
    for x, y in ((9, 12), (18, 14), (23, 12)):
        d.line((x, y, x + 2, y), fill=PLANK_SHADE)
    rope_band(d, 8, 10, 23)
    rope_band(d, 22, 10, 23)
    d.line((9, 9, 22, 9), fill=ROPE)
    d.rectangle((14, 8, 16, 10), fill=ROPE_LIGHT, outline=ROPE)
    d.line((17, 8, 19, 6), fill=ROPE)
    return im


def helm_kit():
    im = blank(32)
    d = ImageDraw.Draw(im)
    # The post lying on its side, with its foot at the left.
    d.polygon(((3, 22), (27, 18), (28, 22), (4, 26)), fill=WOOD_LIGHT, outline=WOOD_DARK)
    d.line((5, 23, 26, 19), fill=WOOD_PALE)
    d.polygon(((1, 20), (4, 20), (5, 28), (2, 28)), fill=WOOD_MID, outline=WOOD_DARK)
    # The wheel laid flat on top of it.
    for x0, y0, x1, y1 in ((4, 13, 26, 13), (15, 5, 15, 21), (7, 8, 23, 18), (23, 8, 7, 18)):
        d.line((x0, y0, x1, y1), fill=WOOD_LIGHT)
        d.point((x0, y0), fill=WOOD_DARK)
        d.point((x1, y1), fill=WOOD_DARK)
    d.ellipse((6, 7, 24, 19), outline=WOOD_DARK)
    d.ellipse((7, 8, 23, 18), outline=WOOD_LIGHT)
    d.arc((7, 8, 23, 18), 190, 330, fill=WOOD_PALE)
    d.ellipse((13, 11, 17, 15), fill=BRASS, outline=BRASS_DARK)
    d.point((14, 12), fill=BRASS_LIGHT)
    # Rope tying the two together.
    for x in (10, 20):
        d.line((x, 18, x + 1, 25), fill=ROPE)
        d.line((x + 1, 18, x + 2, 25), fill=ROPE_LIGHT)
    d.line((10, 18, 20, 17), fill=ROPE)
    d.rectangle((14, 20, 16, 22), fill=ROPE_LIGHT, outline=ROPE)
    d.line((17, 22, 19, 25), fill=ROPE)
    return im


# --- fabrics ----------------------------------------------------------------

# Rubberised cloth: brown-black with a dull sheen. Goldbeater's skin: a thin
# pale yellow-cream membrane. Both are the cloth drawing with its colours
# swapped, so the three fabrics share one silhouette.
RUBBER = (54, 44, 40, 255)
RUBBER_LIGHT = (96, 84, 78, 255)
RUBBER_SHADE = (40, 33, 31, 255)
RUBBER_DARK = (28, 23, 23, 255)
RUBBER_LINE = (16, 13, 14, 255)
RUBBER_GLINT = (156, 146, 138, 255)
RUBBER_HOLE = (6, 5, 8, 255)
SKIN = (246, 230, 156, 255)
SKIN_LIGHT = (255, 246, 204, 255)
SKIN_SHADE = (232, 206, 124, 255)
SKIN_DARK = (210, 178, 96, 255)
SKIN_LINE = (168, 138, 80, 255)
SKIN_VEIN = (218, 190, 110, 255)
FABRIC = {
    'rubber': {CANVAS: RUBBER, CANVAS_LIGHT: RUBBER_LIGHT, CANVAS_SHADE: RUBBER_SHADE,
               CANVAS_DARK: RUBBER_DARK, CANVAS_LINE: RUBBER_LINE, HOLE: RUBBER_HOLE},
    'skin': {CANVAS: SKIN, CANVAS_LIGHT: SKIN_LIGHT, CANVAS_SHADE: SKIN_SHADE,
             CANVAS_DARK: SKIN_DARK, CANVAS_LINE: SKIN_LINE},
}
# How much of the deck shows through the membrane of a rigged skin cell.
SKIN_ALPHA = 196


def recolour(im, mapping, alpha=None):
    """Swap exact colours; with alpha, also thin every swapped pixel but the outline."""
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            to = mapping.get(px[x, y])
            if to:
                if alpha and to != mapping[CANVAS_LINE]:
                    to = to[:3] + (alpha,)
                px[x, y] = to
    return im


def glints(im, body, marks):
    """Specular streaks, only where the fabric's plain body colour is."""
    px = im.load()
    for x0, y, n in marks:
        for x in range(x0, x0 + n):
            if px[x, y] == body:
                px[x, y] = RUBBER_GLINT
    return im


def veins(im, body, marks):
    """Faint overlapping-patch edges of goldbeater's skin."""
    px = im.load()
    for x, y, dx, dy, n in marks:
        for i in range(n):
            at = (x + dx * i, y + dy * i)
            if px[at][:3] == body[:3]:
                px[at] = SKIN_VEIN[:3] + (px[at][3],)
    return im


def gas_cell_folded_fabric(fabric):
    im = recolour(gas_cell_folded(), FABRIC[fabric])
    if fabric == 'rubber':
        glints(im, RUBBER, ((6, 13, 2), (10, 13, 5), (18, 13, 2), (10, 14, 3)))
        glints(im, RUBBER_SHADE, ((22, 11, 2), (21, 12, 1)))
    else:
        veins(im, SKIN, ((6, 14, 1, 0, 2), (11, 15, 1, 0, 4), (18, 14, 1, 0, 2), (10, 18, 1, 0, 5), (18, 18, 1, 0, 3)))
    return im


# --- metal framing ----------------------------------------------------------

ALU = (196, 202, 208, 255)
ALU_LIGHT = (232, 236, 240, 255)
ALU_SHADE = (158, 166, 174, 255)
ALU_DARK = (124, 132, 142, 255)
ALU_LINE = (86, 94, 106, 255)
GIRDER = (104, 108, 116, 255)
GIRDER_LIGHT = (146, 150, 158, 255)
GIRDER_SHADE = (78, 82, 90, 255)
GIRDER_DARK = (58, 61, 68, 255)
GIRDER_LINE = (34, 36, 42, 255)
METAL = {
    'aluminium': (ALU, ALU_LIGHT, ALU_SHADE, ALU_DARK, ALU_LINE),
    'steel': (GIRDER, GIRDER_LIGHT, GIRDER_SHADE, GIRDER_DARK, GIRDER_LINE),
}


def frame_bundle(metal):
    """A roped bundle of riveted I-girders, laid like the plank bundle."""
    face, light, shade, dark, line = METAL[metal]
    im = blank(32)
    d = ImageDraw.Draw(im)
    # Top flanges of two girders side by side.
    d.rectangle((3, 10, 28, 17), fill=face, outline=line)
    d.line((4, 11, 27, 11), fill=light)
    d.line((4, 13, 27, 13), fill=shade)
    d.line((4, 14, 27, 14), fill=line)
    d.line((4, 15, 27, 15), fill=light)
    # The near girder's web between its two flanges, with lightening holes.
    d.rectangle((3, 17, 28, 23), fill=shade, outline=line)
    d.line((4, 18, 27, 18), fill=face)
    d.line((4, 22, 27, 22), fill=dark)
    for x in (5, 11, 17, 23):
        d.rectangle((x, 19, x + 2, 21), fill=line)
        d.point((x, 19), fill=dark)
        d.point((x + 2, 21), fill=dark)
        d.point((x + 3, 20), fill=face)
    # Rivet heads along the flanges.
    for x in range(5, 28, 3):
        d.point((x, 12), fill=shade)
        d.point((x + 1, 16), fill=shade)
        d.point((x, 18), fill=light)
    # Uneven ends, showing the I section.
    d.rectangle((28, 11, 30, 13), fill=face, outline=line)
    d.point((29, 12), fill=light)
    d.rectangle((1, 17, 3, 23), fill=shade, outline=line)
    d.line((2, 19, 2, 21), fill=line)
    d.point((2, 18), fill=light)
    rope_band(d, 8, 10, 23)
    rope_band(d, 22, 10, 23)
    d.line((9, 9, 22, 9), fill=ROPE)
    d.rectangle((14, 8, 16, 10), fill=ROPE_LIGHT, outline=ROPE)
    d.line((17, 8, 19, 6), fill=ROPE)
    return im


def metal_deck(metal):
    """Full-tile floor: four riveted plates lapped over the girders that run
    under every seam, so the rivet rows trace the frame beneath."""
    face, light, shade, dark, line = METAL[metal]
    seam = dark if metal == 'aluminium' else line
    im = Image.new('RGBA', (32, 32), face)
    px = im.load()
    # A few brushed streaks, the same on every tile so the floor tiles cleanly.
    seed = 11
    for _ in range(14):
        seed = (seed * 73 + 41) % 1021
        x, y, n = seed % 32, (seed // 32) % 32, 3 + seed % 4
        if y % 16 in (5, 6, 7, 8, 9, 10):
            for i in range(n):
                if 4 <= (x + i) % 16 <= 11:
                    px[(x + i) % 32, y] = light if seed % 2 else shade
    for top in (0, 16):
        for x in range(32):
            px[x, top] = light
            px[x, top + 14] = shade
            px[x, top + 15] = seam
        for left in (0, 16):
            for y in range(top, top + 15):
                px[left, y] = light
                px[left + 14, y] = shade
                px[left + 15, y] = seam
            px[left + 15, top + 15] = seam
            # Rivets along all four edges of the plate.
            for i in (2, 5, 8, 11):
                for x, y in ((left + i, top + 2), (left + i + 1, top + 12), (left + 2, top + i + 1), (left + 12, top + i)):
                    px[x, y] = light
                    px[x, y + 1] = dark
    return im

# --- bomb hatch -------------------------------------------------------------

# The dark plank colours of icons/turf/flooring/wood.dmi "wood": a four-pixel
# course is a lit edge, the face, the shaded edge and the gap to the next.
DECK_LIT = (81, 43, 15, 255)
DECK_FACE = (71, 33, 6, 255)
DECK_SHADE = (60, 26, 4, 255)
DECK_GAP = (49, 17, 2, 255)
DECK_COURSE = (DECK_LIT, DECK_FACE, DECK_SHADE, DECK_GAP)
HATCH_EDGE = (30, 10, 2, 255)
IRON = (104, 106, 112, 255)
IRON_LIGHT = (150, 152, 158, 255)
IRON_DARK = (52, 54, 60, 255)
STENCIL = (206, 194, 160, 255)
STENCIL_WORN = (150, 128, 96, 255)
DROP = (14, 13, 18, 255)
DROP_WALL = (36, 16, 6, 255)
HAZE = (96, 124, 142, 255)
HAZE_DARK = (62, 84, 100, 255)
FIELD = (70, 98, 58, 255)
FIELD_DARK = (50, 74, 46, 255)
FIELD_TAN = (128, 112, 74, 255)
RIVER = (120, 152, 168, 255)
CLOUD = (176, 190, 196, 255)

# The stencilled bomb, nose down: fins, neck, body.
BOMB_MARK = ('XX..XX',
             '.XXXX.',
             '..XX..',
             '.XXXX.',
             'XXXXXX',
             'XXXXXX',
             'XXXXXX',
             'XXXXXX',
             '.XXXX.',
             '..XX..')


def hatch_frame(d):
    """Coaming around the 26x26 opening; the deck tile shows outside it."""
    d.rectangle((3, 3, 28, 28), outline=HATCH_EDGE)
    d.rectangle((4, 4, 27, 27), outline=DECK_SHADE)
    d.line((4, 4, 27, 4), fill=DECK_LIT)
    d.line((4, 5, 4, 27), fill=DECK_FACE)


def hinge(d, x, strap_to):
    """Iron strap hinge on the north edge; (x) is the strap's left pixel."""
    d.rectangle((x, 4, x + 2, strap_to), fill=IRON, outline=IRON_DARK)
    d.line((x + 1, 5, x + 1, strap_to - 1), fill=IRON)
    d.rectangle((x - 1, 2, x + 3, 4), fill=IRON_DARK)
    d.line((x, 3, x + 2, 3), fill=IRON_LIGHT)
    d.point((x + 1, 6), fill=IRON_LIGHT)
    if strap_to > 8:
        d.point((x + 1, strap_to - 2), fill=IRON_LIGHT)


def bomb_hatch():
    im = blank(32)
    d = ImageDraw.Draw(im)
    hatch_frame(d)
    # The lid: unbroken courses in step with the deck planks around it.
    for y in range(5, 27):
        d.line((5, y, 26, y), fill=DECK_COURSE[y % 4])
    d.line((5, 26, 26, 26), fill=DECK_GAP)
    d.line((26, 5, 26, 26), fill=DECK_GAP)
    # Two battens holding the lid's planks together.
    for x in (6, 24):
        d.line((x, 6, x, 25), fill=DECK_SHADE)
        d.line((x + 1, 6, x + 1, 25), fill=DECK_LIT)
        for y in (7, 15, 23):
            d.point((x, y), fill=IRON_DARK)
    hinge(d, 9, 11)
    hinge(d, 20, 11)
    # Stencilled bomb, worn where the paint crosses a seam.
    for row, line in enumerate(BOMB_MARK):
        for col, mark in enumerate(line):
            if mark == 'X':
                y = 9 + row
                d.point((13 + col, y), fill=STENCIL_WORN if y % 4 == 3 else STENCIL)
    # Pull ring lying flat on its staple, with its shadow.
    d.ellipse((13, 21, 18, 25), outline=IRON_DARK)
    d.arc((13, 21, 18, 25), 180, 360, fill=IRON_LIGHT)
    d.line((14, 25, 17, 25), fill=IRON)
    d.rectangle((15, 20, 16, 21), fill=IRON, outline=None)
    d.point((15, 20), fill=IRON_LIGHT)
    d.line((14, 26, 18, 26), fill=HATCH_EDGE)
    return im


def bomb_hatch_open():
    im = blank(32)
    d = ImageDraw.Draw(im)
    hatch_frame(d)
    # The drop: plank thickness under the north and west coaming, then dark.
    d.rectangle((5, 5, 26, 26), fill=DROP)
    d.line((5, 5, 26, 5), fill=DROP_WALL)
    d.line((5, 6, 26, 6), fill=DROP_WALL)
    d.line((5, 7, 5, 26), fill=DROP_WALL)
    d.line((6, 7, 26, 7), fill=HATCH_EDGE)
    # Far below: haze, a patchwork of fields, a river and a wisp of cloud.
    d.rectangle((8, 10, 24, 24), fill=HAZE_DARK)
    d.rectangle((9, 11, 23, 23), fill=HAZE)
    d.polygon(((9, 15), (14, 13), (17, 17), (12, 21), (9, 20)), fill=FIELD)
    d.polygon(((16, 12), (23, 11), (23, 16), (19, 17)), fill=FIELD_TAN)
    d.polygon(((14, 21), (19, 18), (23, 19), (23, 23), (15, 23)), fill=FIELD_DARK)
    d.line((18, 11, 16, 15), fill=RIVER)
    d.line((16, 15, 18, 19), fill=RIVER)
    d.line((18, 19, 17, 23), fill=RIVER)
    d.line((10, 17, 13, 16), fill=FIELD_DARK)
    d.line((20, 13, 22, 14), fill=FIELD)
    d.line((10, 12, 13, 12), fill=CLOUD)
    d.line((11, 11, 12, 11), fill=CLOUD)
    d.line((20, 21, 22, 21), fill=CLOUD)
    # The lid folded back flat on the deck to the north, underside up.
    d.rectangle((4, 0, 27, 3), fill=DECK_SHADE, outline=HATCH_EDGE)
    d.line((5, 1, 26, 1), fill=DECK_FACE)
    for x in (10, 16, 22):
        d.point((x, 1), fill=DECK_GAP)
        d.point((x, 2), fill=DECK_GAP)
    for x in (9, 20):
        d.rectangle((x - 1, 2, x + 3, 4), fill=IRON_DARK)
        d.line((x, 3, x + 2, 3), fill=IRON_LIGHT)
    # Bomb cradle: two short rails hung from the hinge side, a tie and hooks.
    for x in (12, 19):
        d.line((x, 5, x, 16), fill=IRON)
        d.line((x + 1, 5, x + 1, 16), fill=IRON_DARK)
        d.point((x, 5), fill=IRON_LIGHT)
        d.point((x, 17), fill=IRON_DARK)
    d.line((12, 9, 20, 9), fill=IRON_DARK)
    d.line((13, 8, 19, 8), fill=IRON)
    d.line((13, 15, 14, 17), fill=IRON_LIGHT)
    d.line((18, 15, 17, 17), fill=IRON_LIGHT)
    # The ring hangs under the open lid's far edge.
    d.point((15, 0), fill=IRON)
    d.point((16, 0), fill=IRON)
    return im


# --- gas cell ---------------------------------------------------------------

def rigging(d, anchors):
    for i, (x, y) in enumerate(anchors):
        foot = 30 + i if len(anchors) > 2 else 31 + i
        d.line((x, y, foot, 63), fill=ROPE)


def envelope(box, slack):
    """A fat cigar seen from slightly above, lit from the top."""
    x0, y0, x1, y1 = box
    mask = Image.new('L', (64, 64), 0)
    m = ImageDraw.Draw(mask)
    m.ellipse(box, fill=255)
    if slack:
        # The belly hangs unevenly once the gas is leaking.
        m.polygon(((14, y1 - 6), (22, y1 + 1), (30, y1 - 1), (38, y1 + 2), (47, y1 - 5)), fill=255)
    skin = Image.new('RGBA', (64, 64), CANVAS)
    d = ImageDraw.Draw(skin)
    mid = (y0 + y1) // 2
    d.ellipse((x0 + 6, y0 + 1, x1 - 6, y0 + 9), fill=CANVAS_LIGHT)
    d.chord((x0, y0, x1, y1 + (3 if slack else 0)), 18, 162, fill=CANVAS_SHADE)
    d.chord((x0, y0, x1, y1 + (3 if slack else 0)), 42, 138, fill=CANVAS_DARK)
    # Stitched panel seams: hoops around the cell and one along its side.
    for x in (13, 25, 38, 50):
        bend = (x - 31.5) / 6
        for y in range(y0, y1 + 4):
            t = (y - mid) / ((y1 - y0) / 2)
            px = round(x + bend * (1 - t * t) * 0.9)
            if y % 3 != 2:
                d.point((px, y), fill=CANVAS_LINE)
    for x in range(x0, x1 + 1):
        if x % 3 != 2:
            d.point((x, mid), fill=CANVAS_LINE)
    if slack:
        for x0w, y0w, x1w, y1w in ((17, 27, 20, 31), (28, 29, 30, 34), (42, 28, 45, 32), (8, 23, 10, 26), (53, 22, 55, 25)):
            d.line((x0w, y0w, x1w, y1w), fill=CANVAS_LINE)
            d.line((x0w + 1, y0w, x1w + 1, y1w), fill=CANVAS_LIGHT)
    out = Image.new('RGBA', (64, 64), CLEAR)
    out.paste(skin, (0, 0), mask)
    # One-pixel outline in the seam colour, like the pedal airship's envelope.
    px = mask.load()
    edge = out.load()
    for y in range(64):
        for x in range(64):
            if px[x, y] and any(not (0 <= x + dx < 64 and 0 <= y + dy < 64) or not px[x + dx, y + dy]
                                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                edge[x, y] = CANVAS_LINE
    return out


def hole(d, x, y, shape):
    for dx, dy in shape:
        d.point((x + dx, y + dy), fill=HOLE)
    cells = set(shape)
    for dx, dy in shape:
        for ex, ey in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            near = (dx + ex, dy + ey)
            if near not in cells:
                # Frayed edge: alternate torn thread and curled-back cloth.
                d.point((x + near[0], y + near[1]), fill=CANVAS_LINE if (near[0] + near[1]) % 2 else CANVAS_LIGHT)


def gas_cell(holed=False):
    im = blank(64)
    d = ImageDraw.Draw(im)
    box = (2, 6, 61, 38) if holed else (2, 4, 61, 37)
    rigging(d, ((14, 32), (32, 36), (49, 32)))
    im.alpha_composite(envelope(box, holed))
    d = ImageDraw.Draw(im)
    # Rope patches where the rigging is sewn on.
    for x, y in ((14, 32), (32, 36), (49, 32)):
        d.line((x - 1, y, x + 1, y), fill=ROPE)
        d.point((x, y - 1), fill=ROPE_LIGHT)
    if holed:
        hole(d, 19, 14, ((0, 0), (1, 0), (2, 0), (1, 1), (2, 1), (3, 1), (2, 2)))
        hole(d, 43, 12, ((0, 0), (1, 0), (0, 1), (1, 1), (2, 1), (1, 2)))
        hole(d, 31, 24, ((0, 0), (1, 0), (2, 0), (3, 0), (1, 1), (2, 1), (0, -1), (1, -1)))
        hole(d, 53, 24, ((0, 0), (1, 0), (0, 1)))
        d.line((22, 17, 24, 20), fill=CANVAS_LINE)
        d.line((45, 15, 46, 18), fill=CANVAS_LINE)
    return im


def gas_cell_burnt():
    im = blank(64)
    d = ImageDraw.Draw(im)
    # Slack rigging, one line burnt through.
    d.line((14, 30, 20, 48), fill=ROPE)
    d.line((20, 48, 30, 63), fill=ROPE)
    d.line((32, 34, 32, 63), fill=ROPE)
    d.line((49, 30, 47, 40), fill=CHAR_MID)
    d.line((36, 56, 33, 63), fill=ROPE)
    d.point((37, 55), fill=CHAR)
    # The collapsed skin, draped over what is left of the lines.
    rag = ((9, 27), (13, 22), (20, 24), (27, 20), (34, 23), (41, 19), (48, 23), (54, 26),
           (55, 31), (52, 37), (49, 34), (46, 42), (43, 37), (39, 45), (36, 39), (32, 48),
           (28, 40), (24, 46), (21, 38), (17, 43), (14, 35), (10, 34))
    d.polygon(rag, fill=CHAR_MID, outline=CHAR)
    d.polygon(((13, 25), (20, 26), (27, 23), (34, 26), (41, 22), (48, 25), (52, 28), (44, 30), (30, 31), (16, 30)),
              fill=CHAR_BROWN)
    # A scorched patch of surviving cloth and its seam.
    d.polygon(((22, 26), (29, 24), (33, 27), (30, 30), (24, 30)), fill=SCORCH, outline=CHAR_BROWN)
    d.line((27, 25, 27, 29), fill=CANVAS_LINE)
    for x0, y0, x1, y1 in ((16, 31, 18, 40), (25, 32, 24, 43), (33, 31, 32, 45), (40, 31, 39, 42), (47, 29, 46, 39)):
        d.line((x0, y0, x1, y1), fill=CHAR)
    for x, y in ((12, 28), (19, 33), (29, 36), (36, 34), (43, 33), (50, 30), (22, 41), (38, 40)):
        d.point((x, y), fill=CHAR_BROWN)
    for x, y in ((15, 27), (37, 25), (45, 27), (31, 33), (20, 29), (51, 33)):
        d.point((x, y), fill=CHAR)
    # Hanging tatters.
    for x, y, n in ((18, 44, 3), (30, 49, 2), (40, 46, 3), (46, 43, 2)):
        for i in range(n):
            d.point((x + (i % 2), y + i * 2), fill=CHAR if i % 2 else CHAR_MID)
    return im


def cloth_mask_outline(skin, mask):
    """Cut a painted cloth layer to a mask and give it the seam-colour outline."""
    out = Image.new('RGBA', skin.size, CLEAR)
    out.paste(skin, (0, 0), mask)
    px = mask.load()
    edge = out.load()
    w, h = skin.size
    for y in range(h):
        for x in range(w):
            if px[x, y] and any(not (0 <= x + dx < w and 0 <= y + dy < h) or not px[x + dx, y + dy]
                                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                edge[x, y] = CANVAS_LINE
    return out


def gas_cell_empty():
    """No gas left: the cell slumps in a heap of folds over its own rigging."""
    im = blank(64)
    d = ImageDraw.Draw(im)
    # The three lines lie slack on the deck.
    d.line((11, 55, 17, 62), fill=ROPE)
    d.line((17, 62, 30, 63), fill=ROPE)
    d.line((52, 56, 46, 62), fill=ROPE)
    d.line((46, 62, 32, 63), fill=ROPE)
    heap = ((8, 55), (7, 50), (10, 46), (15, 45), (19, 40), (25, 42), (30, 37), (34, 37), (38, 41),
            (43, 39), (47, 43), (52, 45), (56, 50), (55, 55), (51, 59), (44, 57), (38, 61),
            (31, 58), (24, 61), (17, 58), (12, 59))
    mask = Image.new('L', (64, 64), 0)
    ImageDraw.Draw(mask).polygon(heap, fill=255)
    skin = Image.new('RGBA', (64, 64), CANVAS)
    s = ImageDraw.Draw(skin)
    # Lit crowns of the three humps, shade pooling toward the hem.
    s.polygon(((17, 46), (20, 42), (25, 44), (23, 48)), fill=CANVAS_LIGHT)
    s.polygon(((27, 43), (31, 39), (34, 39), (36, 43), (31, 46)), fill=CANVAS_LIGHT)
    s.polygon(((40, 44), (43, 41), (46, 44), (44, 47)), fill=CANVAS_LIGHT)
    s.polygon(((7, 53), (16, 54), (24, 57), (31, 54), (38, 57), (45, 53), (56, 52), (56, 63), (7, 63)),
              fill=CANVAS_SHADE)
    s.polygon(((14, 58), (24, 60), (31, 57), (38, 60), (50, 57), (50, 63), (14, 63)), fill=CANVAS_DARK)
    # Folds running down from each hump, each with a lit lip.
    for x0, y0, x1, y1, x2, y2 in ((19, 42, 16, 50, 18, 57), (25, 43, 26, 51, 24, 59), (31, 39, 31, 48, 32, 57),
                                   (37, 42, 39, 50, 38, 59), (43, 41, 46, 49, 45, 56), (12, 47, 11, 53, 13, 57),
                                   (51, 46, 52, 52, 50, 57)):
        s.line((x0, y0, x1, y1), fill=CANVAS_LINE)
        s.line((x1, y1, x2, y2), fill=CANVAS_LINE)
        s.line((x0 + 1, y0 + 1, x1 + 1, y1), fill=CANVAS_LIGHT)
    # What shows of the stitched seams, broken by the folds.
    for x in range(9, 55):
        if x % 3 != 2 and x % 9 < 6:
            s.point((x, 51 + (x % 4 == 0)), fill=CANVAS_LINE)
    for x0w, y0w, x1w, y1w in ((21, 46, 23, 49), (28, 47, 29, 52), (34, 45, 35, 50), (41, 46, 42, 51), (48, 48, 49, 52)):
        s.line((x0w, y0w, x1w, y1w), fill=CANVAS_SHADE)
    im.alpha_composite(cloth_mask_outline(skin, mask))
    d = ImageDraw.Draw(im)
    # Rope patches, and the middle line lying across the heap.
    for x, y in ((12, 54), (51, 55)):
        d.line((x - 1, y, x + 1, y), fill=ROPE)
        d.point((x, y - 1), fill=ROPE_LIGHT)
    d.line((31, 50, 33, 55), fill=ROPE)
    d.line((33, 55, 31, 60), fill=ROPE)
    d.line((30, 49, 32, 49), fill=ROPE)
    d.point((31, 48), fill=ROPE_LIGHT)
    d.line((31, 60, 31, 63), fill=ROPE)
    return im


def gas_cell_fabric(fabric, state):
    """state is 'full', 'holed' or 'empty'."""
    im = gas_cell_empty() if state == 'empty' else gas_cell(holed=state == 'holed')
    recolour(im, FABRIC[fabric], SKIN_ALPHA if fabric == 'skin' else None)
    if fabric == 'rubber':
        if state == 'empty':
            glints(im, RUBBER, ((20, 45, 3), (29, 42, 4), (41, 45, 3), (14, 49, 2), (47, 48, 2)))
        else:
            top = 9 if state == 'holed' else 7
            glints(im, RUBBER_LIGHT, ((14, top + 1, 9), (27, top, 9), (40, top + 1, 8), (16, top + 2, 5)))
            glints(im, RUBBER, ((6, 18, 3), (27, 20 + (state == 'holed'), 8), (52, 18, 3)))
    elif state != 'empty':
        body = SKIN[:3] + (SKIN_ALPHA,)
        veins(im, body, ((6, 17, 1, 0, 5), (16, 15, 1, 1, 4), (20, 26, 1, 0, 4), (28, 15, 1, 0, 6),
                         (30, 27, 1, -1, 4), (41, 17, 1, 1, 4), (44, 26, 1, 0, 4), (53, 17, 1, 0, 4),
                         (8, 25, 1, 0, 3), (34, 18, 0, 1, 3), (19, 18, 0, 1, 3), (47, 16, 0, 1, 3)))
    return im


# --- sheets -----------------------------------------------------------------

HULL_STATES = (('helm', 4), ('gas_cell_folded', 1), ('airship_planks', 1), ('helm_kit', 1),
               ('bomb_hatch', 1), ('bomb_hatch_open', 1), ('aluminium_frame', 1), ('steel_frame', 1),
               ('airship_deck_aluminium', 1), ('airship_deck_steel', 1),
               ('gas_cell_folded_rubber', 1), ('gas_cell_folded_skin', 1))
CELL_STATES = ('gas_cell', 'gas_cell_holed', 'gas_cell_burnt', 'gas_cell_empty',
               'gas_cell_rubber', 'gas_cell_rubber_holed', 'gas_cell_rubber_empty',
               'gas_cell_skin', 'gas_cell_skin_holed', 'gas_cell_skin_empty')
HULL_COLUMNS = 4
CELL_COLUMNS = 5


def description(size, states):
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = %d\n\theight = %d\n' % (size, size)
    for name, dirs in states:
        text += 'state = "%s"\n\tdirs = %d\n\tframes = 1\n' % (name, dirs)
    return text + '# END DMI\n'


def sheet_of(frames, size, columns):
    sheet = Image.new('RGBA', (size * columns, size * -(-len(frames) // columns)), CLEAR)
    for i, frame in enumerate(frames):
        sheet.paste(frame, ((i % columns) * size, (i // columns) * size))
    return sheet


def sheets():
    # BYOND stores four-direction states as south, north, east, west.
    hull = [helm_front(False), mirrored(helm_front(True)), helm_side(False), mirrored(helm_side(True)),
            gas_cell_folded(), airship_planks(), helm_kit(), bomb_hatch(), bomb_hatch_open(),
            frame_bundle('aluminium'), frame_bundle('steel'), metal_deck('aluminium'), metal_deck('steel'),
            gas_cell_folded_fabric('rubber'), gas_cell_folded_fabric('skin')]
    cells = [gas_cell(), gas_cell(holed=True), gas_cell_burnt(), gas_cell_empty()]
    for fabric in ('rubber', 'skin'):
        cells += [gas_cell_fabric(fabric, state) for state in ('full', 'holed', 'empty')]
    return ((HULL, sheet_of(hull, 32, HULL_COLUMNS), description(32, HULL_STATES)),
            (CELL, sheet_of(cells, 64, CELL_COLUMNS), description(64, [(name, 1) for name in CELL_STATES])))


def turf(state, sheet='icons/turf/floors.dmi'):
    """One 32x32 tile from a turf sheet, for the preview only."""
    im = Image.open(ROOT / sheet)
    index = 0
    name = None
    for line in im.info['Description'].splitlines():
        line = line.strip()
        if line.startswith('state = '):
            name = line[9:-1]
            if name == state:
                break
        elif line.startswith('dirs = '):
            dirs = int(line[7:])
        elif line.startswith('frames = '):
            index += dirs * int(line[9:])
    else:
        raise SystemExit('no turf state ' + state)
    cols = im.width // 32
    x, y = (index % cols) * 32, (index // cols) * 32
    return im.convert('RGBA').crop((x, y, x + 32, y + 32))


def preview(path):
    """Every state on grass and deck at 4x, and a small deck mock-up."""
    scale = 4
    (_, hull, _), (_, cell, _) = sheets()
    grass, wood = turf('grass0'), turf('wood')
    pedal = Image.open(ROOT / 'icons/obj/vehicles/pedal_airship.dmi').convert('RGBA')
    tiles_w, tiles_h = 15, 12
    scene = Image.new('RGBA', (tiles_w * 32, tiles_h * 32))
    for tx in range(tiles_w):
        for ty in range(tiles_h):
            scene.alpha_composite(grass, (tx * 32, ty * 32))
    labels = []

    def deck(tx, ty):
        scene.alpha_composite(wood, (tx * 32, ty * 32))

    def hull_frame(i):
        return hull.crop(((i % 4) * 32, (i // 4) * 32, (i % 4) * 32 + 32, (i // 4) * 32 + 32))

    def cell_at(i, tx, ty):
        # pixel_x = -16, pixel_y = 12 from the deck tile.
        scene.alpha_composite(cell.crop((i * 64, 0, i * 64 + 64, 64)), (tx * 32 - 16, ty * 32 + 32 - 12 - 64))

    # Row 1: the helm in each direction on deck, then the three items.
    for i, name in enumerate(('helm S', 'helm N', 'helm E', 'helm W')):
        deck(1 + i * 2, 1)
        scene.alpha_composite(hull_frame(i), ((1 + i * 2) * 32, 32))
        labels.append((1 + i * 2, 2, name))
    for i, name in enumerate(('gas_cell_folded', 'airship_planks', 'helm_kit')):
        scene.alpha_composite(hull_frame(4 + i), ((9 + i * 2) * 32, 32))
        labels.append((8.5 + i * 2, 2 + (i % 2) * 0.35, name))
    # Row 2: the three gas cell states over one deck tile each.
    for i, name in enumerate(('gas_cell', 'gas_cell_holed', 'gas_cell_burnt')):
        tx = 2 + i * 5
        for dx in (-1, 0, 1):
            deck(tx + dx, 5)
        cell_at(i, tx, 5)
        labels.append((tx - 1, 6, name))
    # Mock-up: 5x3 deck, bow to the east, helm aft, two cells, and a pedal airship.
    for dx in range(5):
        for dy in range(3):
            deck(2 + dx, 8 + dy)
    scene.alpha_composite(hull_frame(2), (2 * 32, 9 * 32))
    cell_at(0, 4, 9)
    cell_at(0, 6, 9)
    scene.alpha_composite(pedal.crop((128, 0, 192, 64)), (11 * 32 - 16, 10 * 32 + 32 - 64))
    labels.append((2, 11, 'mock-up: 5x3 deck, helm, 2 gas cells'))
    labels.append((10, 11, 'pedal airship'))

    big = scene.resize((scene.width * scale, scene.height * scale), Image.NEAREST)
    d = ImageDraw.Draw(big)
    for tx, ty, text in labels:
        x, y = int(tx * 32 * scale) + 4, int(ty * 32 * scale) + 4
        box = d.textbbox((x, y), text)
        d.rectangle((box[0] - 3, box[1] - 3, box[2] + 3, box[3] + 3), fill=(24, 24, 28, 255))
        d.text((x, y), text, fill=(240, 240, 240, 255))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    big.convert('RGB').save(path)


def hatch_preview(path):
    """Both hatch states at 4x on the dark wood deck, beside the helm and a gas cell."""
    scale = 4
    (_, hull, _), (_, cell, _) = sheets()
    wood = turf('wood', 'icons/turf/flooring/wood.dmi')
    scene = Image.new('RGBA', (8 * 32, 4 * 32))
    for tx in range(8):
        for ty in range(4):
            scene.alpha_composite(wood, (tx * 32, ty * 32))

    def hull_frame(i):
        return hull.crop(((i % 4) * 32, (i // 4) * 32, (i % 4) * 32 + 32, (i // 4) * 32 + 32))

    scene.alpha_composite(hull_frame(2), (0, 2 * 32))
    scene.alpha_composite(hull_frame(7), (2 * 32, 2 * 32))
    scene.alpha_composite(hull_frame(8), (4 * 32, 2 * 32))
    scene.alpha_composite(cell.crop((0, 0, 64, 64)), (6 * 32 - 16, 2 * 32 + 32 - 12 - 64))
    big = scene.resize((scene.width * scale, scene.height * scale), Image.NEAREST)
    d = ImageDraw.Draw(big)
    for tx, text in ((0, 'helm E'), (2, 'bomb_hatch'), (4, 'bomb_hatch_open'), (6, 'gas_cell')):
        x, y = int(tx * 32 * scale) + 4, 3 * 32 * scale + 8
        box = d.textbbox((x, y), text)
        d.rectangle((box[0] - 3, box[1] - 3, box[2] + 3, box[3] + 3), fill=(24, 24, 28, 255))
        d.text((x, y), text, fill=(240, 240, 240, 255))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    big.convert('RGB').save(path)


def main():
    if '--hatch-preview' in sys.argv:
        hatch_preview(sys.argv[sys.argv.index('--hatch-preview') + 1])
        return
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
        return
    stale = []
    for target, sheet, description in sheets():
        if '--check' in sys.argv:
            same = False
            if target.exists():
                current = Image.open(target)
                same = (current.info.get('Description') == description
                        and current.convert('RGBA').tobytes() == sheet.tobytes())
            if not same:
                stale.append(str(target.relative_to(ROOT)))
            continue
        info = PngInfo()
        info.add_text('Description', description, zip=True)
        sheet.save(target, format='PNG', pnginfo=info, optimize=True)
    if stale:
        raise SystemExit(', '.join(stale) + ' stale; rerun tests/airship_hull/airship_hull_sprites.py')


if __name__ == '__main__':
    main()
