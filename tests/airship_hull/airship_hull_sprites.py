"""Draw the buildable airship's sprites (original pixel art, no generated images).

icons/obj/vehicles/airship_hull.dmi, 32x32: "helm" (4 directions, the wheel
faces the bow), and the inventory items "gas_cell_folded", "airship_planks"
and "helm_kit".

icons/obj/vehicles/airship_gas_cell.dmi, 64x64: "gas_cell", "gas_cell_holed"
and "gas_cell_burnt". The game draws the cell with pixel_x = -16 and
pixel_y = 12, so its deck tile is under the bottom middle of the sheet and
the rigging lines meet there.

The palette and line weight follow tests/pedal_bicycle/airship_sprites.py so
the parts sit beside the pedal airship.

    python3 tests/airship_hull/airship_hull_sprites.py            # rewrite both DMIs
    python3 tests/airship_hull/airship_hull_sprites.py --check    # fail when one is stale
    python3 tests/airship_hull/airship_hull_sprites.py --preview out.png
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


# --- sheets -----------------------------------------------------------------

def sheets():
    # BYOND stores four-direction states as south, north, east, west.
    hull = [helm_front(False), mirrored(helm_front(True)), helm_side(False), mirrored(helm_side(True)),
            gas_cell_folded(), airship_planks(), helm_kit()]
    hull_sheet = Image.new('RGBA', (32 * 4, 32 * 2), CLEAR)
    for i, frame in enumerate(hull):
        hull_sheet.paste(frame, ((i % 4) * 32, (i // 4) * 32))
    hull_description = ('# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
                        'state = "helm"\n\tdirs = 4\n\tframes = 1\n'
                        'state = "gas_cell_folded"\n\tdirs = 1\n\tframes = 1\n'
                        'state = "airship_planks"\n\tdirs = 1\n\tframes = 1\n'
                        'state = "helm_kit"\n\tdirs = 1\n\tframes = 1\n'
                        '# END DMI\n')
    cell_sheet = Image.new('RGBA', (64 * 3, 64), CLEAR)
    for i, frame in enumerate((gas_cell(), gas_cell(holed=True), gas_cell_burnt())):
        cell_sheet.paste(frame, (i * 64, 0))
    cell_description = ('# BEGIN DMI\nversion = 4.0\n\twidth = 64\n\theight = 64\n'
                        'state = "gas_cell"\n\tdirs = 1\n\tframes = 1\n'
                        'state = "gas_cell_holed"\n\tdirs = 1\n\tframes = 1\n'
                        'state = "gas_cell_burnt"\n\tdirs = 1\n\tframes = 1\n'
                        '# END DMI\n')
    return ((HULL, hull_sheet, hull_description), (CELL, cell_sheet, cell_description))


def turf(state):
    """One 32x32 tile from icons/turf/floors.dmi, for the preview only."""
    im = Image.open(ROOT / 'icons/turf/floors.dmi')
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


def main():
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
