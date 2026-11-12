"""Draw icons/obj/vehicles/pedal_airship.dmi (original pixel art, no generated images).

64x64 states "airship" (4 directions) and "airship_overlay" (the basket side
and propeller drawn in front of the rider, 4 directions). The game draws the
sheet 16 pixels to the left, so the rider's tile is the bottom middle 32x32
and the skids rest on the tile's bottom edge.

    python3 tests/pedal_bicycle/airship_sprites.py            # rewrite the DMI
    python3 tests/pedal_bicycle/airship_sprites.py --check    # fail when it is stale
"""
from pathlib import Path
import sys

from PIL import Image, ImageDraw
from PIL.PngImagePlugin import PngInfo

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / 'icons/obj/vehicles/pedal_airship.dmi'
SIZE = 64
CANVAS = (226, 214, 180, 255)
CANVAS_SHADE = (196, 180, 140, 255)
CANVAS_LINE = (132, 114, 80, 255)
FIN = (156, 44, 38, 255)
FIN_LIGHT = (198, 78, 64, 255)
ROPE = (96, 82, 62, 255)
WICKER = (158, 114, 64, 255)
WICKER_DARK = (108, 74, 40, 255)
WOOD = (92, 62, 36, 255)
STEEL = (120, 124, 132, 255)
STEEL_DARK = (78, 82, 90, 255)


def blank():
    return Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))


def basket(d, left, right):
    d.rectangle((left, 51, right, 62), fill=WICKER, outline=WICKER_DARK)
    d.line((left, 51, right, 51), fill=WOOD)
    for y in (54, 57, 60):
        d.line((left + 1, y, right - 1, y), fill=WICKER_DARK)
    for x in range(left + 3, right, 4):
        d.point((x, 53), fill=WICKER_DARK)
        d.point((x, 56), fill=WICKER_DARK)
        d.point((x, 58), fill=WICKER_DARK)


def skids(d, left, right):
    d.line((left - 1, 63, right + 1, 63), fill=WOOD)


def side(parts='all'):
    """East-facing side view; the nose is on the right, the propeller behind."""
    im = blank()
    d = ImageDraw.Draw(im)
    if parts == 'all':
        d.polygon(((3, 8), (11, 12), (11, 18), (3, 22)), fill=FIN, outline=FIN)
        d.line((4, 10, 10, 13), fill=FIN_LIGHT)
        d.ellipse((5, 3, 61, 27), fill=CANVAS, outline=CANVAS_LINE)
        d.chord((5, 3, 61, 27), 20, 160, fill=CANVAS_SHADE, outline=CANVAS_LINE)
        for x in (19, 33, 47):
            d.line((x, 5, x, 25), fill=CANVAS_LINE)
        d.line((6, 15, 60, 15), fill=CANVAS_LINE)
        d.line((24, 26, 22, 50), fill=ROPE)
        d.line((33, 27, 32, 50), fill=ROPE)
        d.line((42, 26, 43, 50), fill=ROPE)
        d.line((15, 56, 21, 56), fill=STEEL_DARK)
        d.line((44, 47, 44, 50), fill=STEEL)
        d.line((43, 47, 46, 47), fill=WOOD)
    basket(d, 21, 44)
    skids(d, 21, 44)
    # Propeller on its shaft behind the basket, and the pedal crank on its side.
    d.line((14, 49, 14, 62), fill=STEEL)
    d.line((13, 51, 13, 54), fill=STEEL_DARK)
    d.line((15, 58, 15, 61), fill=STEEL_DARK)
    d.point((14, 56), fill=WOOD)
    d.ellipse((30, 54, 34, 58), outline=STEEL_DARK)
    d.line((32, 56, 34, 59), fill=STEEL)
    return im


def front(parts, facing_camera):
    im = blank()
    d = ImageDraw.Draw(im)
    if parts == 'all':
        d.ellipse((16, 1, 47, 29), fill=CANVAS, outline=CANVAS_LINE)
        d.chord((16, 1, 47, 29), 20, 160, fill=CANVAS_SHADE, outline=CANVAS_LINE)
        d.line((31, 2, 31, 28), fill=CANVAS_LINE)
        d.line((32, 2, 32, 28), fill=CANVAS_LINE)
        d.arc((22, 1, 41, 29), 90, 270, fill=CANVAS_LINE)
        d.arc((22, 1, 41, 29), 270, 90, fill=CANVAS_LINE)
        if not facing_camera:
            # The tail fins point at the camera.
            d.rectangle((31, 9, 32, 21), fill=FIN)
            d.line((25, 15, 38, 15), fill=FIN)
            d.line((26, 14, 37, 14), fill=FIN_LIGHT)
        d.line((21, 25, 23, 50), fill=ROPE)
        d.line((42, 25, 40, 50), fill=ROPE)
    basket(d, 22, 41)
    skids(d, 22, 41)
    if facing_camera:
        d.line((29, 48, 34, 48), fill=WOOD)
        d.line((31, 48, 31, 50), fill=STEEL)
        d.line((32, 48, 32, 50), fill=STEEL)
    else:
        # Propeller on the back of the basket.
        d.line((25, 49, 38, 62), fill=STEEL)
        d.line((38, 49, 25, 62), fill=STEEL)
        d.line((26, 49, 28, 51), fill=STEEL_DARK)
        d.line((37, 62, 35, 60), fill=STEEL_DARK)
        d.rectangle((31, 55, 32, 56), fill=WOOD)
    return im


def mirrored(im):
    return im.transpose(Image.FLIP_LEFT_RIGHT)


def frames():
    # BYOND stores four-direction states as south, north, east, west.
    return [front('all', True), front('all', False), side(), mirrored(side()),
            front('overlay', True), front('overlay', False), side('overlay'), mirrored(side('overlay'))]


def build():
    sheet = Image.new('RGBA', (SIZE * 4, SIZE * 2), (0, 0, 0, 0))
    for i, frame in enumerate(frames()):
        sheet.paste(frame, ((i % 4) * SIZE, (i // 4) * SIZE))
    description = ('# BEGIN DMI\nversion = 4.0\n\twidth = 64\n\theight = 64\n'
                   'state = "airship"\n\tdirs = 4\n\tframes = 1\n'
                   'state = "airship_overlay"\n\tdirs = 4\n\tframes = 1\n'
                   '# END DMI\n')
    return sheet, description


def main():
    sheet, description = build()
    if '--check' in sys.argv:
        current = Image.open(TARGET)
        same = current.info.get('Description') == description and current.convert('RGBA').tobytes() == sheet.tobytes()
        raise SystemExit(0 if same else 'icons/obj/vehicles/pedal_airship.dmi is stale; rerun tests/pedal_bicycle/airship_sprites.py')
    info = PngInfo()
    info.add_text('Description', description, zip=True)
    sheet.save(TARGET, format='PNG', pnginfo=info, optimize=True)


if __name__ == '__main__':
    main()
