"""Draw the gas works sprites (original pixel art, no generated images).

icons/obj/gas_works.dmi, 32x32: the items "gasbag", "gasbag_full",
"cylinder_empty", "cylinder_hydrogen", "cylinder_helium", "cylinder_oxygen"
and "gas_hose", and the machines "hydrogen_generator", "electrolysis_tank"
and "water_gas_retort" (each with an "_on" state), "helium_separator" and
"gas_compressor".

icons/obj/gas_holder.dmi, 64x64: "gas_holder", "gas_holder_low" and
"gas_holder_high", a gasometer whose bell sits at half height, sunk or risen.
Its tank stands on the bottom middle of the sheet.

The palette and line weight follow tests/airship_hull/airship_hull_sprites.py
so the works sit beside the airship parts they fill.

    python3 tests/gas_works/gas_works_sprites.py            # rewrite both DMIs
    python3 tests/gas_works/gas_works_sprites.py --check    # fail when one is stale
    python3 tests/gas_works/gas_works_sprites.py --preview out.png

The preview also shows the material states of the two airship DMIs, read
from the files on disk.
"""
from pathlib import Path
import sys

from PIL import Image, ImageDraw
from PIL.PngImagePlugin import PngInfo

ROOT = Path(__file__).resolve().parents[2]
WORKS = ROOT / 'icons/obj/gas_works.dmi'
HOLDER = ROOT / 'icons/obj/gas_holder.dmi'

# Shared with the airship hull parts.
CANVAS = (226, 214, 180, 255)
CANVAS_LIGHT = (240, 232, 206, 255)
CANVAS_SHADE = (196, 180, 140, 255)
CANVAS_DARK = (166, 148, 108, 255)
CANVAS_LINE = (132, 114, 80, 255)
ROPE = (96, 82, 62, 255)
ROPE_LIGHT = (140, 122, 92, 255)
WOOD = (92, 62, 36, 255)
WOOD_DARK = (58, 38, 22, 255)
WOOD_MID = (124, 86, 50, 255)
WOOD_LIGHT = (158, 114, 64, 255)
WOOD_PALE = (190, 146, 90, 255)
BRASS = (204, 166, 72, 255)
BRASS_LIGHT = (238, 212, 124, 255)
BRASS_DARK = (132, 100, 38, 255)
IRON = (104, 106, 112, 255)
IRON_LIGHT = (150, 152, 158, 255)
IRON_DARK = (52, 54, 60, 255)
STEEL = (120, 124, 132, 255)
STEEL_DARK = (78, 82, 90, 255)
RUBBER = (54, 44, 40, 255)
RUBBER_LIGHT = (96, 84, 78, 255)
RUBBER_LINE = (16, 13, 14, 255)
# Added for the works.
STEEL_LIGHT = (170, 174, 182, 255)
STEEL_LINE = (34, 36, 42, 255)
IRON_MID = (78, 80, 86, 255)
LEAD = (126, 132, 142, 255)
LEAD_LIGHT = (176, 182, 190, 255)
LEAD_DARK = (74, 80, 92, 255)
BAND_HYDROGEN = (188, 44, 38, 255)
BAND_HELIUM = (132, 84, 44, 255)
BAND_OXYGEN = (236, 236, 232, 255)
BRICK = (150, 76, 54, 255)
BRICK_LIGHT = (184, 104, 76, 255)
BRICK_DARK = (112, 54, 40, 255)
MORTAR = (78, 44, 36, 255)
SOOT = (30, 26, 26, 255)
GLOW = (255, 196, 64, 255)
GLOW_HOT = (255, 240, 170, 255)
EMBER = (232, 110, 30, 255)
EMBER_DARK = (170, 62, 22, 255)
SMOKE = (150, 150, 150, 150)
SMOKE_THIN = (170, 170, 170, 90)
WATER = (84, 140, 178, 255)
WATER_DARK = (58, 104, 144, 255)
WATER_LIGHT = (150, 196, 220, 255)
GLASS = (206, 226, 226, 255)
GLASS_AIR = (188, 212, 216, 150)
BUBBLE = (238, 248, 250, 255)
ACID = (198, 214, 116, 255)
ACID_LIGHT = (232, 240, 176, 255)
COPPER = (184, 104, 62, 255)
GRAPHITE = (46, 46, 52, 255)
FROST = (232, 242, 250, 255)
FROST_SHADE = (180, 206, 228, 255)
DIAL = (240, 234, 212, 255)
NEEDLE = (170, 40, 34, 255)
CLEAR = (0, 0, 0, 0)


def blank(size=32):
    return Image.new('RGBA', (size, size), CLEAR)


def points(d, colour, *at):
    for xy in at:
        d.point(xy, fill=colour)


def gauge(d, x, y, needle):
    """Five-pixel brass dial; (x, y) is its top left, needle the tip offset."""
    d.ellipse((x, y, x + 4, y + 4), fill=DIAL, outline=BRASS_DARK)
    points(d, BRASS, (x + 1, y), (x + 2, y), (x, y + 1), (x, y + 2))
    d.point((x + 2, y + 2), fill=IRON_DARK)
    d.point((x + 2 + needle[0], y + 2 + needle[1]), fill=NEEDLE)


# --- gasbag -----------------------------------------------------------------

def stopper(d, x, y):
    """Wooden bung in the bag's neck; (x, y) is its top left."""
    d.rectangle((x, y, x + 3, y + 4), fill=WOOD_LIGHT, outline=WOOD_DARK)
    d.line((x + 1, y + 1, x + 2, y + 1), fill=WOOD_PALE)
    d.point((x + 2, y + 3), fill=WOOD_MID)


def gasbag(full):
    im = blank()
    d = ImageDraw.Draw(im)
    if full:
        d.ellipse((2, 8, 24, 27), fill=CANVAS, outline=CANVAS_LINE)
        d.chord((3, 9, 23, 26), 20, 160, fill=CANVAS_SHADE)
        d.chord((3, 9, 23, 26), 45, 135, fill=CANVAS_DARK)
        d.ellipse((6, 10, 15, 14), fill=CANVAS_LIGHT)
        # Stitched gores.
        for y in range(9, 27):
            t = (y - 17.5) / 9.5
            for x, bend in ((8, -3), (13, 0), (18, 3)):
                if y % 3 != 2:
                    d.point((round(x + bend * (1 - t * t) * 0.6), y), fill=CANVAS_LINE)
        # Neck gathered and tied over the stopper.
        d.polygon(((22, 14), (26, 15), (26, 20), (22, 21)), fill=CANVAS_SHADE, outline=CANVAS_LINE)
        d.line((23, 16, 25, 17), fill=CANVAS_LIGHT)
        stopper(d, 27, 15)
        d.line((25, 14, 25, 21), fill=ROPE)
        d.line((26, 14, 26, 21), fill=ROPE_LIGHT)
        d.line((25, 21, 24, 24), fill=ROPE)
    else:
        # Flat and creased, lying where it was dropped.
        d.polygon(((3, 23), (4, 19), (8, 17), (13, 18), (17, 16), (22, 17), (25, 19), (26, 23),
                   (23, 26), (16, 27), (9, 26), (5, 26)), fill=CANVAS, outline=CANVAS_LINE)
        d.polygon(((5, 24), (12, 24), (18, 25), (24, 23), (23, 25), (16, 26), (9, 25), (6, 25)), fill=CANVAS_SHADE)
        d.line((6, 19, 12, 19), fill=CANVAS_LIGHT)
        d.line((15, 18, 21, 18), fill=CANVAS_LIGHT)
        for x0, y0, x1, y1 in ((8, 18, 10, 23), (13, 19, 12, 24), (17, 17, 19, 23), (22, 18, 21, 22)):
            d.line((x0, y0, x1, y1), fill=CANVAS_LINE)
            d.line((x0 + 1, y0 + 1, x1 + 1, y1 - 1), fill=CANVAS_LIGHT)
        d.line((5, 21, 7, 22), fill=CANVAS_SHADE)
        d.line((14, 21, 16, 22), fill=CANVAS_SHADE)
        d.polygon(((23, 18), (27, 17), (27, 22), (24, 23)), fill=CANVAS_SHADE, outline=CANVAS_LINE)
        stopper(d, 27, 17)
        d.line((26, 16, 26, 23), fill=ROPE)
        d.line((26, 23, 24, 26), fill=ROPE)
        d.point((27, 16), fill=ROPE_LIGHT)
    return im


# --- pressure cylinder ------------------------------------------------------

def cylinder(band):
    im = blank()
    d = ImageDraw.Draw(im)
    # Foot ring, body and the domed shoulder.
    d.rectangle((10, 27, 21, 30), fill=IRON_DARK, outline=STEEL_LINE)
    d.line((11, 28, 20, 28), fill=IRON)
    d.rectangle((11, 8, 20, 27), fill=STEEL, outline=STEEL_LINE)
    for y, x0, x1 in ((5, 14, 17), (6, 13, 18), (7, 12, 19)):
        d.line((x0, y, x1, y), fill=STEEL)
        points(d, STEEL_LINE, (x0 - 1, y), (x1 + 1, y))
    d.line((14, 4, 17, 4), fill=STEEL_LINE)
    d.line((13, 6, 13, 26), fill=STEEL_LIGHT)
    d.point((14, 5), fill=STEEL_LIGHT)
    d.line((12, 8, 12, 26), fill=STEEL)
    d.line((18, 7, 18, 26), fill=STEEL_DARK)
    d.line((19, 8, 19, 26), fill=STEEL_DARK)
    # Riveted seam down the front and two riveted hoops.
    for y in range(9, 26, 3):
        d.point((16, y), fill=STEEL_DARK)
        d.point((16, y + 1), fill=STEEL_LIGHT)
    for y in (16, 25):
        d.line((12, y, 19, y), fill=STEEL_DARK)
        for x in (12, 14, 18):
            d.point((x, y), fill=STEEL_LIGHT)
    if band:
        light = tuple(min(255, c + 36) for c in band[:3]) + (255,)
        dark = tuple(int(c * 0.68) for c in band[:3]) + (255,)
        d.rectangle((12, 10, 19, 13), fill=band)
        d.line((13, 10, 13, 13), fill=light)
        d.line((18, 10, 19, 10), fill=dark)
        d.rectangle((18, 11, 19, 13), fill=dark)
        d.line((12, 14, 19, 14), fill=STEEL_DARK)
    # Neck, brass valve with its side outlet, and the handwheel.
    d.rectangle((14, 2, 17, 4), fill=BRASS, outline=BRASS_DARK)
    d.point((15, 3), fill=BRASS_LIGHT)
    d.rectangle((18, 2, 20, 3), fill=BRASS_DARK)
    d.point((19, 2), fill=BRASS)
    d.line((12, 0, 19, 0), fill=IRON_DARK)
    d.line((13, 0, 18, 0), fill=IRON)
    d.line((15, 1, 16, 1), fill=IRON_DARK)
    points(d, IRON_LIGHT, (13, 0), (16, 0))
    return im


# --- hose -------------------------------------------------------------------

def gas_hose():
    im = blank()
    d = ImageDraw.Draw(im)
    # The loose end runs out from under the coil to its coupling.
    d.line((19, 25, 26, 27), fill=RUBBER_LINE)
    d.line((19, 24, 26, 26), fill=RUBBER)
    d.line((20, 23, 26, 25), fill=RUBBER_LINE)
    d.rectangle((26, 24, 29, 28), fill=BRASS, outline=BRASS_DARK)
    d.point((27, 25), fill=BRASS_LIGHT)
    d.line((30, 25, 30, 27), fill=BRASS_DARK)
    # Three turns of hose.
    d.ellipse((3, 8, 27, 25), fill=RUBBER, outline=RUBBER_LINE)
    d.ellipse((6, 11, 24, 23), outline=RUBBER_LINE)
    d.ellipse((9, 13, 21, 21), fill=RUBBER, outline=RUBBER_LINE)
    d.ellipse((12, 15, 18, 19), fill=CLEAR, outline=RUBBER_LINE)
    d.arc((4, 9, 26, 24), 190, 300, fill=RUBBER_LIGHT)
    d.arc((7, 12, 23, 22), 195, 290, fill=RUBBER_LIGHT)
    d.arc((10, 14, 20, 20), 200, 280, fill=RUBBER_LIGHT)
    d.arc((4, 9, 26, 24), 30, 110, fill=(36, 29, 27, 255))
    # The inner end turns up through the middle, coupling uppermost.
    d.line((15, 14, 15, 17), fill=RUBBER_LINE)
    d.line((16, 14, 16, 17), fill=RUBBER)
    d.line((17, 14, 17, 17), fill=RUBBER_LINE)
    d.rectangle((14, 10, 18, 13), fill=BRASS, outline=BRASS_DARK)
    d.point((15, 11), fill=BRASS_LIGHT)
    d.line((15, 9, 17, 9), fill=BRASS_DARK)
    return im


# --- hydrogen generator -----------------------------------------------------

def pipe_run(d, path, body=LEAD, light=LEAD_LIGHT, dark=LEAD_DARK):
    """Two-pixel pipe along right-angled segments: lit on its upper or left side."""
    for (x0, y0), (x1, y1) in zip(path, path[1:]):
        if y0 == y1:
            d.line((x0, y0, x1, y0), fill=light)
            d.line((x0, y0 + 1, x1, y0 + 1), fill=dark)
        else:
            d.line((x0, y0, x0, y1), fill=light)
            d.line((x0 + 1, y0, x0 + 1, y1), fill=dark)
    for x, y in path[1:-1]:
        d.point((x, y), fill=body)
        d.point((x + 1, y + 1), fill=dark)


def hydrogen_generator(on):
    """An upright cask of acid on iron scrap; the gas leaves by a lead pipe."""
    im = blank()
    d = ImageDraw.Draw(im)
    # Lead pipe: up from the lid, across, and down to the tap.
    pipe_run(d, ((15, 9), (15, 3), (26, 3), (26, 13)))
    # Staves, bulging at the middle.
    for y in range(10, 30):
        t = abs(y - 19.5) / 9.5
        half = 9 - round(t * t * 2.2)
        d.line((14 - half, y, 14 + half + 1, y), fill=WOOD_LIGHT)
        points(d, WOOD_DARK, (14 - half - 1, y), (14 + half + 2, y))
        points(d, WOOD_PALE, (14 - half + 1, y), (14 - half + 2, y))
        points(d, WOOD_MID, (14 + half - 1, y), (14 + half, y), (14 + half + 1, y))
        for x in (9, 12, 15, 18):
            d.point((x, y), fill=WOOD_MID if x < 18 else WOOD)
    d.line((6, 30, 23, 30), fill=WOOD_DARK)
    # Lid seen from above.
    d.ellipse((5, 6, 24, 13), fill=WOOD_PALE, outline=WOOD_DARK)
    d.line((8, 8, 21, 8), fill=PLANK_LIGHT)
    d.line((7, 10, 22, 10), fill=WOOD_LIGHT)
    d.line((9, 12, 20, 12), fill=WOOD_LIGHT)
    # Iron hoops with a rivet each.
    for y, x0, x1 in ((14, 5, 24), (25, 5, 24)):
        d.rectangle((x0, y, x1, y + 1), fill=IRON)
        d.line((x0, y + 1, x1, y + 1), fill=IRON_DARK)
        points(d, IRON_DARK, (x0 - 1, y), (x1 + 1, y), (x0 - 1, y + 1), (x1 + 1, y + 1))
        points(d, IRON_LIGHT, (x0 + 2, y), (x0 + 3, y), (17, y))
    # The pipe's flange on the lid and the open filling hole beside it.
    d.rectangle((14, 9, 17, 10), fill=LEAD_DARK)
    d.line((14, 9, 17, 9), fill=LEAD)
    d.ellipse((8, 8, 12, 11), fill=SOOT, outline=WOOD_DARK)
    # Brass tap on the end of the pipe.
    d.rectangle((25, 13, 28, 16), fill=BRASS, outline=BRASS_DARK)
    d.point((26, 14), fill=BRASS_LIGHT)
    d.line((29, 12, 29, 15), fill=BRASS_DARK)
    d.line((30, 12, 30, 13), fill=BRASS)
    d.line((26, 17, 27, 17), fill=LEAD_DARK)
    d.line((26, 18, 27, 18), fill=LEAD)
    if on:
        # Acid froth working out of the filling hole and gas at the tap.
        d.ellipse((8, 8, 12, 11), fill=ACID, outline=WOOD_DARK)
        points(d, ACID_LIGHT, (9, 9), (11, 10), (10, 8))
        points(d, BUBBLE, (10, 9), (9, 7), (11, 6))
        points(d, ACID_LIGHT, (8, 6), (12, 7), (10, 5))
        d.ellipse((7, 2, 9, 4), outline=ACID_LIGHT)
        d.point((11, 3), fill=BUBBLE)
        d.point((9, 1), fill=ACID)
        d.point((7, 9), fill=ACID)
        d.point((6, 12), fill=ACID)
        d.line((7, 13, 7, 17), fill=ACID)
        d.point((7, 18), fill=ACID_LIGHT)
        points(d, (214, 226, 232, 200), (26, 20), (27, 22), (25, 23))
        points(d, (214, 226, 232, 120), (27, 20), (26, 22), (27, 24), (25, 25))
    return im


PLANK_LIGHT = (214, 178, 122, 255)


# --- electrolysis tank ------------------------------------------------------

def electrolysis_tank(on):
    """Glass tank in an iron frame: two plates in water, a gas pipe over each."""
    im = blank()
    d = ImageDraw.Draw(im)
    # The two outlet pipes rise from the lid and turn outward.
    pipe_run(d, ((9, 11), (9, 4), (1, 4)))
    pipe_run(d, ((21, 11), (21, 4), (29, 4)))
    d.line((30, 4, 30, 5), fill=LEAD_DARK)
    d.line((0, 4, 0, 5), fill=LEAD_DARK)
    # Glass and water.
    d.rectangle((4, 13, 27, 27), fill=GLASS_AIR)
    d.rectangle((4, 16, 27, 27), fill=WATER)
    d.line((4, 16, 27, 16), fill=WATER_LIGHT)
    d.rectangle((4, 24, 27, 27), fill=WATER_DARK)
    for x0, y0, x1, y1 in ((6, 22, 9, 18), (7, 24, 8, 23), (23, 20, 25, 18)):
        d.line((x0, y0, x1, y1), fill=WATER_LIGHT)
    d.line((5, 13, 8, 13), fill=GLASS)
    d.line((5, 14, 5, 15), fill=GLASS)
    # A glass divider keeps the two gases apart.
    d.line((15, 14, 15, 26), fill=WATER_LIGHT)
    d.line((16, 14, 16, 26), fill=WATER_DARK)
    # The plates: copper on one side, graphite on the other.
    for x, plate, lit in ((10, COPPER, (226, 150, 100, 255)), (20, GRAPHITE, IRON)):
        d.rectangle((x, 14, x + 2, 25), fill=plate)
        d.line((x, 14, x, 25), fill=lit)
    # Iron frame: lid, corner posts, sill and feet.
    d.rectangle((3, 11, 28, 12), fill=IRON, outline=IRON_DARK)
    d.line((4, 11, 27, 11), fill=IRON_LIGHT)
    d.line((3, 13, 3, 28), fill=IRON_DARK)
    d.line((28, 13, 28, 28), fill=IRON_DARK)
    d.rectangle((3, 28, 28, 29), fill=IRON, outline=IRON_DARK)
    d.line((4, 28, 27, 28), fill=IRON_LIGHT)
    for x in (4, 26):
        d.rectangle((x, 30, x + 1, 30), fill=IRON_DARK)
    for x in (6, 14, 17, 25):
        points(d, IRON_DARK, (x, 11), (x, 28))
    # Brass terminals on the lid, with their leads.
    for x, wire in ((10, (170, 40, 34, 255)), (20, (40, 40, 46, 255))):
        d.rectangle((x, 8, x + 2, 10), fill=BRASS, outline=BRASS_DARK)
        d.point((x + 1, 9), fill=BRASS_LIGHT)
        d.line((x + 1, 7, x + 4, 7), fill=wire)
        d.line((x + 4, 7, x + 4, 10), fill=wire)
    if on:
        points(d, BUBBLE, (9, 23), (13, 21), (9, 19), (13, 17), (12, 24), (8, 21), (14, 19), (13, 23),
               (19, 22), (23, 20), (19, 18), (23, 24), (18, 20), (24, 22))
        points(d, WATER_LIGHT, (9, 17), (13, 19), (12, 22), (8, 24), (19, 24), (23, 17), (18, 23), (24, 19))
        points(d, BUBBLE, (8, 16), (9, 15), (12, 16), (13, 15), (14, 16), (19, 16), (23, 16), (24, 15), (18, 16))
    return im


# --- water gas retort -------------------------------------------------------

def water_gas_retort(on):
    """Brick-set retort: steam over glowing coke behind an iron door, flue on top."""
    im = blank()
    d = ImageDraw.Draw(im)
    # Flue with a rain cap.
    d.rectangle((20, 2, 24, 10), fill=IRON, outline=IRON_DARK)
    d.line((21, 3, 21, 9), fill=IRON_LIGHT)
    d.line((23, 3, 23, 9), fill=IRON_MID)
    d.line((20, 6, 24, 6), fill=IRON_DARK)
    d.rectangle((19, 1, 25, 2), fill=IRON_DARK)
    d.line((20, 1, 24, 1), fill=IRON)
    # Brickwork: top face, then the front in broken courses.
    d.rectangle((2, 9, 29, 30), fill=BRICK, outline=MORTAR)
    d.rectangle((3, 10, 28, 12), fill=BRICK_LIGHT)
    d.line((3, 13, 28, 13), fill=MORTAR)
    for row, y in enumerate(range(14, 30, 4)):
        d.line((3, y + 3, 28, y + 3), fill=MORTAR)
        d.line((3, y, 28, y), fill=BRICK_LIGHT)
        for x in range(6 if row % 2 else 10, 29, 8):
            d.line((x, y, x, y + 2), fill=MORTAR)
        d.line((3, y + 2, 28, y + 2), fill=BRICK_DARK)
        for x in range(6 if row % 2 else 10, 29, 8):
            d.point((x, y + 2), fill=MORTAR)
    for x in (8, 16):
        d.point((x, 11), fill=BRICK)
        d.point((x + 3, 12), fill=BRICK)
    d.rectangle((19, 10, 25, 12), fill=IRON_DARK)
    d.line((20, 10, 24, 10), fill=IRON_MID)
    # Arched iron door with strap hinges, latch and a peep slot.
    d.rectangle((9, 17, 20, 29), fill=IRON, outline=IRON_DARK)
    d.line((10, 16, 19, 16), fill=IRON_DARK)
    d.line((11, 15, 18, 15), fill=IRON_DARK)
    d.line((11, 16, 18, 16), fill=IRON)
    d.line((10, 17, 19, 17), fill=IRON_LIGHT)
    d.line((10, 18, 10, 28), fill=IRON_LIGHT)
    d.line((19, 18, 19, 28), fill=IRON_MID)
    for y in (19, 26):
        d.line((7, y, 13, y), fill=IRON_DARK)
        d.point((8, y), fill=IRON_LIGHT)
        d.point((12, y), fill=IRON_LIGHT)
    d.rectangle((17, 22, 21, 23), fill=IRON_DARK)
    d.point((21, 22), fill=IRON_LIGHT)
    d.rectangle((13, 21, 16, 23), fill=SOOT)
    # Steam inlet on the left and the gas offtake on the right.
    d.rectangle((0, 20, 2, 21), fill=LEAD, outline=None)
    d.line((0, 21, 2, 21), fill=LEAD_DARK)
    d.rectangle((29, 15, 31, 16), fill=LEAD, outline=None)
    d.line((29, 16, 31, 16), fill=LEAD_DARK)
    if on:
        d.rectangle((13, 21, 16, 23), fill=GLOW)
        d.line((14, 22, 15, 22), fill=GLOW_HOT)
        d.line((13, 23, 16, 23), fill=EMBER)
        # Light leaking round the door and on the bricks beside it.
        for x in range(10, 20, 2):
            d.point((x, 29), fill=EMBER)
        points(d, EMBER, (9, 21), (9, 24), (20, 19), (20, 26), (12, 15), (17, 15))
        points(d, GLOW, (11, 29), (15, 29), (18, 29))
        points(d, EMBER_DARK, (8, 22), (8, 25), (21, 20), (21, 27), (7, 23), (22, 25), (14, 14), (10, 30), (16, 30))
        d.line((12, 20, 17, 20), fill=EMBER_DARK)
        d.line((12, 24, 17, 24), fill=EMBER_DARK)
        # Smoke off the flue.
        points(d, SMOKE, (22, 0), (23, 0), (24, 0))
        points(d, SMOKE_THIN, (25, 0), (26, 0), (21, 0), (26, 1))
    return im


# --- helium separator -------------------------------------------------------

def helium_separator():
    """Tall riveted cold column: frost on the lower courses, a gauge each side."""
    im = blank()
    d = ImageDraw.Draw(im)
    # Offtake pipe from the cap, down the right side.
    pipe_run(d, ((16, 1), (24, 1), (24, 9)))
    # Plinth, shell and the domed cap.
    d.rectangle((8, 28, 23, 30), fill=IRON_DARK, outline=STEEL_LINE)
    d.line((9, 28, 22, 28), fill=IRON)
    d.rectangle((10, 5, 21, 28), fill=STEEL, outline=STEEL_LINE)
    for y, x0, x1 in ((2, 13, 18), (3, 12, 19), (4, 11, 20)):
        d.line((x0, y, x1, y), fill=STEEL)
        points(d, STEEL_LINE, (x0 - 1, y), (x1 + 1, y))
    d.line((13, 1, 15, 1), fill=STEEL_LINE)
    d.line((12, 4, 12, 27), fill=STEEL_LIGHT)
    d.point((13, 2), fill=STEEL_LIGHT)
    d.line((13, 5, 13, 27), fill=(146, 150, 158, 255))
    d.line((19, 5, 19, 27), fill=STEEL_DARK)
    d.line((20, 5, 20, 27), fill=STEEL_DARK)
    # Flanged joints with their bolts.
    for y in (9, 18):
        d.rectangle((9, y, 22, y + 1), fill=IRON, outline=None)
        d.line((9, y + 1, 22, y + 1), fill=IRON_DARK)
        points(d, STEEL_LINE, (8, y), (23, y), (8, y + 1), (23, y + 1))
        for x in range(10, 22, 3):
            d.point((x, y), fill=IRON_LIGHT)
    for y in (6, 13, 15, 22, 25):
        for x in (11, 15, 18):
            d.point((x, y), fill=STEEL_DARK if x > 11 else IRON)
    d.line((16, 11, 16, 16), fill=STEEL_DARK)
    # Gauges: one high on the left, one low on the right, on short stubs.
    d.line((7, 13, 9, 13), fill=BRASS_DARK)
    gauge(d, 3, 11, (-1, -1))
    d.line((22, 7, 23, 7), fill=BRASS_DARK)
    d.rectangle((24, 9, 25, 10), fill=BRASS, outline=None)
    d.point((25, 10), fill=BRASS_DARK)
    gauge(d, 24, 12, (1, 0))
    d.line((23, 14, 22, 14), fill=BRASS_DARK)
    # Frost creeping up the cold end, icicles under the lower flange.
    for x, y in ((11, 21), (14, 21), (17, 21), (12, 22), (13, 22), (16, 22), (18, 22), (11, 23), (12, 23), (14, 23),
                 (15, 23), (17, 23), (19, 23), (11, 24), (12, 24), (13, 24), (15, 24), (16, 24), (18, 24), (20, 24),
                 (11, 25), (12, 25), (13, 25), (14, 25), (16, 25), (17, 25), (18, 25), (19, 25),
                 (11, 26), (12, 26), (13, 26), (14, 26), (15, 26), (17, 26), (18, 26), (19, 26), (20, 26),
                 (11, 27), (12, 27), (13, 27), (14, 27), (15, 27), (16, 27), (17, 27), (18, 27), (19, 27), (20, 27)):
        d.point((x, y), fill=FROST if x < 17 else FROST_SHADE)
    points(d, FROST_SHADE, (13, 23), (15, 25), (12, 26), (16, 27), (14, 24))
    points(d, FROST, (10, 20), (13, 20), (17, 20), (21, 20), (10, 21), (9, 28), (13, 28), (14, 28), (19, 28), (22, 28),
           (11, 17), (15, 17))
    points(d, FROST_SHADE, (21, 21), (18, 20), (16, 28), (21, 28))
    return im


# --- compressor -------------------------------------------------------------

def gas_compressor():
    """Single-cylinder piston compressor: flywheel, crosshead and a delivery gauge."""
    im = blank()
    d = ImageDraw.Draw(im)
    # Bedplate and the cylinder's cradle.
    d.rectangle((1, 27, 30, 30), fill=IRON_DARK, outline=STEEL_LINE)
    d.line((2, 28, 29, 28), fill=IRON)
    for x in (3, 10, 21, 28):
        d.point((x, 29), fill=IRON_LIGHT)
    d.polygon(((19, 26), (20, 22), (28, 22), (29, 26)), fill=IRON_MID, outline=STEEL_LINE)
    # Delivery pipe and gauge on top of the cylinder.
    d.rectangle((23, 8, 24, 13), fill=LEAD)
    d.line((24, 8, 24, 13), fill=LEAD_DARK)
    gauge(d, 21, 3, (1, -1))
    d.line((25, 10, 30, 10), fill=LEAD_LIGHT)
    d.line((25, 11, 30, 11), fill=LEAD_DARK)
    # Cylinder with end flanges and a row of bolts.
    d.rectangle((18, 13, 29, 22), fill=IRON, outline=STEEL_LINE)
    d.line((19, 14, 28, 14), fill=IRON_LIGHT)
    d.line((19, 15, 28, 15), fill=(126, 128, 134, 255))
    d.line((19, 20, 28, 20), fill=IRON_MID)
    d.line((19, 21, 28, 21), fill=IRON_DARK)
    for x in (18, 29):
        d.line((x, 12, x, 23), fill=STEEL_LINE)
    d.line((17, 13, 17, 22), fill=IRON_MID)
    d.line((30, 13, 30, 22), fill=IRON_MID)
    for x in (21, 24, 27):
        d.point((x, 17), fill=IRON_LIGHT)
        d.point((x, 18), fill=IRON_DARK)
    d.rectangle((22, 12, 25, 13), fill=IRON_DARK)
    # Flywheel: rim, six spokes, brass hub.
    d.ellipse((1, 9, 17, 25), fill=None, outline=STEEL_LINE)
    d.ellipse((2, 10, 16, 24), outline=IRON)
    d.ellipse((3, 11, 15, 23), outline=IRON_DARK)
    d.arc((2, 10, 16, 24), 180, 290, fill=IRON_LIGHT)
    for dx, dy in ((0, -6), (0, 6), (-5, -3), (5, -3), (-5, 3), (5, 3)):
        d.line((9, 17, 9 + dx, 17 + dy), fill=IRON_MID)
    d.ellipse((7, 15, 11, 19), fill=BRASS, outline=BRASS_DARK)
    d.point((8, 16), fill=BRASS_LIGHT)
    # Crank pin, connecting rod and crosshead into the cylinder.
    d.line((11, 20, 16, 18), fill=STEEL_LIGHT)
    d.line((11, 21, 16, 19), fill=STEEL_DARK)
    d.rectangle((10, 20, 11, 21), fill=BRASS_DARK)
    d.rectangle((15, 17, 17, 19), fill=STEEL, outline=STEEL_LINE)
    d.point((16, 18), fill=STEEL_LIGHT)
    return im


# --- gas holder -------------------------------------------------------------

HOLDER_CX = 31.5
TANK_RIM = (5, 42, 58, 58)
TANK_FOOT = (5, 47, 58, 63)
RING_TOP = (5, 1, 58, 17)
BELL_X = (13, 50)
BELL_RISE = {'gas_holder_low': 39, 'gas_holder': 29, 'gas_holder_high': 18}
BELL = (112, 116, 124, 255)
BELL_LIGHT = (156, 160, 168, 255)
BELL_PALE = (184, 188, 194, 255)
BELL_SHADE = (84, 88, 96, 255)
BELL_DARK = (62, 65, 72, 255)
STONE = (136, 130, 120, 255)
STONE_LIGHT = (172, 166, 154, 255)
STONE_DARK = (98, 92, 86, 255)
STONE_LINE = (56, 52, 50, 255)


def ellipse_y(box, x, lower):
    """Y of an ellipse's lower or upper arc at column x (None outside it)."""
    x0, y0, x1, y1 = box
    cx, cy, rx, ry = (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) / 2, (y1 - y0) / 2
    t = (x - cx) / rx
    if abs(t) > 1:
        return None
    off = ry * (1 - t * t) ** 0.5
    return round(cy + off if lower else cy - off)


def column(d, x, top, foot):
    d.line((x, top, x, foot), fill=IRON_DARK)
    d.line((x + 1, top, x + 1, foot), fill=IRON_LIGHT)
    d.line((x + 2, top, x + 2, foot), fill=STEEL_LINE)
    d.rectangle((x - 1, top - 1, x + 3, top), fill=IRON_DARK)
    d.line((x, top - 1, x + 2, top - 1), fill=IRON_LIGHT)


def brace(d, x0, top0, foot0, x1, top1, foot1, colour):
    """Two tiers of X bracing between a pair of columns."""
    mid0, mid1 = (top0 + foot0) // 2, (top1 + foot1) // 2
    for a0, b0, a1, b1 in ((top0, mid0, top1, mid1), (mid0, foot0, mid1, foot1)):
        d.line((x0, a0, x1, b1), fill=colour)
        d.line((x0, b0, x1, a1), fill=colour)
    d.line((x0, mid0, x1, mid1), fill=colour)


def gas_holder(state):
    """A gasometer: riveted iron bell floating in a stone tank, guided by a
    six-column lattice frame."""
    rise = BELL_RISE[state]
    im = blank(64)
    d = ImageDraw.Draw(im)
    lattice = (70, 73, 80, 255)
    # Column positions round the tank: back pair, side pair, front pair.
    back, side, front = (17, 44), (4, 57), (17, 44)
    # Back of the frame, then the tank's far wall and the water in it.
    d.arc(RING_TOP, 180, 360, fill=IRON_DARK)
    brace(d, side[0] + 1, 9, 50, back[0] + 1, 3, 44, lattice)
    brace(d, back[0] + 1, 3, 44, back[1] + 1, 3, 44, lattice)
    brace(d, back[1] + 1, 3, 44, side[1] + 1, 9, 50, lattice)
    for x in back:
        column(d, x, 3, 44)
    d.ellipse(TANK_RIM, fill=WATER_DARK, outline=STONE_LINE)
    d.arc((6, 43, 57, 57), 180, 360, fill=STONE_DARK)
    d.arc((7, 44, 56, 56), 200, 340, fill=WATER)
    # The bell: lit from the upper left, plate courses broken like brickwork.
    x0, x1 = BELL_X
    lip = (x0, 44, x1, 56)
    crown = (x0, rise - 6, x1, rise + 6)
    for x in range(x0, x1 + 1):
        t = (x - x0) / (x1 - x0)
        tone = BELL_DARK if t < 0.06 else BELL_SHADE if t < 0.16 else BELL_LIGHT if t < 0.4 else BELL if t < 0.7 \
            else BELL_SHADE if t < 0.9 else BELL_DARK
        top, foot = ellipse_y(crown, x, True), ellipse_y(lip, x, True)
        d.line((x, top, x, foot), fill=tone)
        for course, y in enumerate(range(top + 5, foot, 6)):
            d.point((x, y), fill=BELL_DARK if t > 0.16 else STEEL_LINE)
            if (x + course * 4) % 8 == 0 and y + 5 < foot:
                d.line((x, y + 1, x, y + 5), fill=BELL_SHADE if t < 0.7 else BELL_DARK)
            if x % 3 == 0 and 0.16 < t < 0.9:
                d.point((x, y + 1), fill=BELL_PALE if t < 0.7 else BELL)
        d.point((x, foot), fill=STEEL_LINE)
    d.line((x0, rise, x0, 50), fill=STEEL_LINE)
    d.line((x1, rise, x1, 50), fill=STEEL_LINE)
    # Crown: a shallow dome of gores with a manhole at its centre.
    d.ellipse(crown, fill=BELL_LIGHT, outline=STEEL_LINE)
    d.chord((x0 + 1, rise - 5, x1 - 1, rise + 5), 0, 110, fill=BELL)
    d.ellipse((20, rise - 5, 40, rise + 1), fill=BELL_PALE)
    for dx, dy in ((-17, -2), (-12, 4), (0, 6), (12, 4), (17, -2), (9, -5), (-9, -5)):
        d.line((31, rise - 1, 31 + dx, rise + dy), fill=BELL_SHADE)
    d.ellipse((28, rise - 3, 35, rise), fill=IRON, outline=IRON_DARK)
    d.line((30, rise - 2, 33, rise - 2), fill=IRON_LIGHT)
    for x in range(x0 + 3, x1 - 1, 4):
        d.point((x, ellipse_y(crown, x, True) + 2), fill=BELL_PALE)
    # Guide rollers on the crown's rim, running on the side columns.
    for x in (x0 - 3, x1 + 1):
        d.rectangle((x, rise - 1, x + 2, rise + 1), fill=BRASS_DARK, outline=STEEL_LINE)
        d.point((x + 1, rise), fill=BRASS)
    d.line((side[0] + 3, rise, x0 - 4, rise), fill=IRON_DARK)
    d.line((x1 + 4, rise, side[1] - 1, rise), fill=IRON_DARK)
    # The tank's near wall: coursed stone under a lit coping.
    for x in range(TANK_RIM[0], TANK_RIM[2] + 1):
        top, foot = ellipse_y(TANK_RIM, x, True), ellipse_y(TANK_FOOT, x, True)
        t = (x - TANK_RIM[0]) / (TANK_RIM[2] - TANK_RIM[0])
        tone = STONE_DARK if t < 0.08 or t > 0.84 else STONE_LIGHT if t < 0.36 else STONE
        d.line((x, top, x, foot), fill=tone)
        d.point((x, top), fill=STONE_LINE)
        d.point((x, top + 1), fill=STONE_LIGHT if t < 0.84 else STONE)
        d.point((x, min(63, top + 3)), fill=STONE_DARK)
        if (x + 2) % 6 == 0:
            d.point((x, min(63, top + 2)), fill=STONE_DARK)
        if x % 6 == 0 and top + 5 <= foot:
            d.line((x, top + 4, x, foot), fill=STONE_DARK)
        d.point((x, foot), fill=STONE_LINE)
    d.point((5, 50), fill=STONE_LINE)
    d.point((58, 50), fill=STONE_LINE)
    # Front of the frame: side and front columns, tie ring and the top ring.
    for x in side:
        column(d, x, 9, 51)
    for x in front:
        column(d, x, 16, 57)
    d.arc(RING_TOP, 0, 180, fill=STEEL_LINE)
    d.arc((5, 0, 58, 16), 0, 180, fill=IRON_LIGHT)
    for x in (side[0] + 1, side[1] + 1, front[0] + 1, front[1] + 1):
        top = 9 if x in (side[0] + 1, side[1] + 1) else 16
        d.rectangle((x - 2, top - 2, x + 2, top), fill=IRON_DARK)
        d.line((x - 1, top - 2, x + 1, top - 2), fill=IRON_LIGHT)
    # Light front bracing, kept to the open frame above the bell.
    clear = rise - 9
    for (xa, ta), (xb, tb) in (((side[0] + 3, 10), (front[0] - 1, 17)), ((front[0] + 3, 17), (front[1] - 1, 17)),
                               ((front[1] + 3, 17), (side[1] - 1, 10))):
        if clear - max(ta, tb) >= 6:
            fa, fb = clear - (tb - ta if ta < tb else 0), clear - (ta - tb if tb < ta else 0)
            fa, fb = max(fa, ta + 4), max(fb, tb + 4)
            d.line((xa, ta, xb, fb), fill=IRON_MID)
            d.line((xa, fa, xb, tb), fill=IRON_MID)
            d.line((xa, fa, xb, fb), fill=IRON_DARK)
    return im


# --- sheets -----------------------------------------------------------------

WORKS_STATES = ('gasbag', 'gasbag_full', 'cylinder_empty', 'cylinder_hydrogen', 'cylinder_helium',
                'cylinder_oxygen', 'gas_hose', 'hydrogen_generator', 'hydrogen_generator_on',
                'electrolysis_tank', 'electrolysis_tank_on', 'water_gas_retort', 'water_gas_retort_on',
                'helium_separator', 'gas_compressor')
HOLDER_STATES = ('gas_holder', 'gas_holder_low', 'gas_holder_high')
WORKS_COLUMNS = 5


def description(size, states):
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = %d\n\theight = %d\n' % (size, size)
    for name in states:
        text += 'state = "%s"\n\tdirs = 1\n\tframes = 1\n' % name
    return text + '# END DMI\n'


def sheet_of(frames, size, columns):
    sheet = Image.new('RGBA', (size * columns, size * -(-len(frames) // columns)), CLEAR)
    for i, frame in enumerate(frames):
        sheet.paste(frame, ((i % columns) * size, (i // columns) * size))
    return sheet


def sheets():
    works = [gasbag(False), gasbag(True), cylinder(None), cylinder(BAND_HYDROGEN), cylinder(BAND_HELIUM),
             cylinder(BAND_OXYGEN), gas_hose(), hydrogen_generator(False), hydrogen_generator(True),
             electrolysis_tank(False), electrolysis_tank(True), water_gas_retort(False), water_gas_retort(True),
             helium_separator(), gas_compressor()]
    holders = [gas_holder(state) for state in HOLDER_STATES]
    return ((WORKS, sheet_of(works, 32, WORKS_COLUMNS), description(32, WORKS_STATES)),
            (HOLDER, sheet_of(holders, 64, len(holders)), description(64, HOLDER_STATES)))


# --- preview ----------------------------------------------------------------

def dmi_states(path):
    """Every state of a DMI on disk as {name: first frame}."""
    im = Image.open(path)
    size = None
    order = []
    for line in im.info['Description'].splitlines():
        line = line.strip()
        if line.startswith('width = '):
            size = int(line[8:])
        elif line.startswith('state = '):
            order.append([line[9:-1], 1, 1])
        elif line.startswith('dirs = '):
            order[-1][1] = int(line[7:])
        elif line.startswith('frames = '):
            order[-1][2] = int(line[9:])
    rgba = im.convert('RGBA')
    cols = im.width // size
    out, index = {}, 0
    for name, dirs, frames in order:
        x, y = (index % cols) * size, (index // cols) * size
        out[name] = rgba.crop((x, y, x + size, y + size))
        index += dirs * frames
    return out


AIRSHIP_HULL_NEW = ('aluminium_frame', 'steel_frame', 'airship_deck_aluminium', 'airship_deck_steel',
                    'gas_cell_folded_rubber', 'gas_cell_folded_skin')
AIRSHIP_CELL_NEW = ('gas_cell_empty', 'gas_cell_rubber', 'gas_cell_rubber_holed', 'gas_cell_rubber_empty',
                    'gas_cell_skin', 'gas_cell_skin_holed', 'gas_cell_skin_empty')


def preview(path):
    """Every material and gas works state at 4x: items on grass, cells over a deck tile."""
    scale = 4
    hull = dmi_states(ROOT / 'icons/obj/vehicles/airship_hull.dmi')
    cell = dmi_states(ROOT / 'icons/obj/vehicles/airship_gas_cell.dmi')
    works = dmi_states(WORKS)
    holder = dmi_states(HOLDER)
    grass = dmi_states(ROOT / 'icons/turf/floors.dmi')['grass0']
    wood = dmi_states(ROOT / 'icons/turf/flooring/wood.dmi')['wood']
    cells = []
    for name in AIRSHIP_HULL_NEW:
        cells.append((name, hull[name], 'tile' if 'deck' in name else 'item'))
    for name in ('gas_cell',) + AIRSHIP_CELL_NEW:
        cells.append((name + (' (existing)' if name == 'gas_cell' else ''), cell[name], 'cell'))
    for name in WORKS_STATES:
        cells.append((name, works[name], 'item'))
    for name in HOLDER_STATES:
        cells.append((name, holder[name], 'big'))
    cols, box_w, box_h = 8, 80, 96
    rows = -(-len(cells) // cols)
    scene = Image.new('RGBA', (cols * box_w, rows * box_h), (24, 24, 28, 255))
    labels = []
    for i, (name, frame, kind) in enumerate(cells):
        ox, oy = (i % cols) * box_w + 8, (i // cols) * box_h + 4
        ground = Image.new('RGBA', (64, 76), CLEAR)
        for tx in range(2):
            for ty in range(3):
                ground.alpha_composite(grass, (tx * 32, ty * 32))
        if kind == 'tile':
            # Two by two, to show the floor tiles without a seam.
            for tx in range(2):
                for ty in range(2):
                    ground.alpha_composite(frame, (tx * 32, 6 + ty * 32))
        elif kind == 'cell':
            # pixel_x = -16, pixel_y = 12: the deck tile is under the bottom middle.
            ground.alpha_composite(wood, (16, 44))
            ground.alpha_composite(frame, (0, 0))
        elif kind == 'big':
            ground.alpha_composite(frame, (0, 8))
        else:
            ground.alpha_composite(frame, (16, 22))
        scene.alpha_composite(ground, (ox, oy))
        labels.append((ox, oy + 78, name))
    big = scene.resize((scene.width * scale, scene.height * scale), Image.NEAREST)
    d = ImageDraw.Draw(big)
    for x, y, text in labels:
        d.text((x * scale, y * scale + 6), text.replace('airship_deck_', 'airship_deck_\n'), fill=(240, 240, 240, 255))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    big.convert('RGB').save(path)


def main():
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
        return
    stale = []
    for target, sheet, text in sheets():
        if '--check' in sys.argv:
            same = False
            if target.exists():
                current = Image.open(target)
                same = (current.info.get('Description') == text
                        and current.convert('RGBA').tobytes() == sheet.tobytes())
            if not same:
                stale.append(str(target.relative_to(ROOT)))
            continue
        info = PngInfo()
        info.add_text('Description', text, zip=True)
        sheet.save(target, format='PNG', pnginfo=info, optimize=True)
    if stale:
        raise SystemExit(', '.join(stale) + ' stale; rerun tests/gas_works/gas_works_sprites.py')


if __name__ == '__main__':
    main()
