"""Draw icons/obj/vehicles/bicycle.dmi (original pixel art, no generated images).

States: "bicycle" (4 directions), "bicycle_overlay" (the parts drawn in front
of a mounted rider, 4 directions) and "bicycle_handlebars" (the held controls).

    python3 tests/pedal_bicycle/sprites.py            # rewrite the DMI
    python3 tests/pedal_bicycle/sprites.py --check    # fail when it is stale
"""
from pathlib import Path
import sys

from PIL import Image, ImageDraw
from PIL.PngImagePlugin import PngInfo

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / 'icons/obj/vehicles/bicycle.dmi'
TYRE = (34, 34, 38, 255)
SPOKE = (150, 152, 158, 255)
HUB = (96, 98, 104, 255)
FRAME = (156, 44, 38, 255)
FRAME_LIGHT = (198, 78, 64, 255)
STEEL = (120, 124, 132, 255)
SADDLE = (104, 66, 38, 255)
SADDLE_DARK = (74, 46, 26, 255)
GRIP = (44, 40, 38, 255)


def blank():
    return Image.new('RGBA', (32, 32), (0, 0, 0, 0))


def wheel(d, cx, cy):
    d.ellipse((cx - 6, cy - 6, cx + 6, cy + 6), outline=TYRE)
    d.ellipse((cx - 5, cy - 5, cx + 5, cy + 5), outline=TYRE)
    for dx, dy in ((0, -4), (0, 4), (-4, 0), (4, 0), (-3, -3), (3, 3), (-3, 3), (3, -3)):
        d.line((cx, cy, cx + dx, cy + dy), fill=SPOKE)
    d.point((cx, cy), fill=HUB)


def side_bars(d):
    d.line((21, 9, 21, 13), fill=STEEL)
    d.line((19, 9, 23, 9), fill=GRIP)
    d.point((19, 10), fill=GRIP)


def side(parts='all'):
    """East-facing side view; the front wheel is on the right."""
    im = blank()
    d = ImageDraw.Draw(im)
    if parts == 'all':
        wheel(d, 8, 22)
        wheel(d, 23, 22)
        d.line((12, 13, 15, 22), fill=FRAME)        # seat tube
        d.line((12, 14, 21, 14), fill=FRAME_LIGHT)  # top tube
        d.line((21, 15, 15, 22), fill=FRAME)        # down tube
        d.line((15, 22, 8, 22), fill=FRAME)         # chain stay
        d.line((12, 14, 8, 22), fill=FRAME)         # seat stay
        d.line((21, 13, 23, 22), fill=STEEL)        # fork
        d.rectangle((9, 11, 14, 12), fill=SADDLE)
        d.line((9, 12, 14, 12), fill=SADDLE_DARK)
        d.point((15, 22), fill=HUB)
        side_bars(d)
    # Crank and near pedal sit in front of the rider's leg.
    d.line((15, 22, 16, 25), fill=STEEL)
    d.line((15, 26, 18, 26), fill=GRIP)
    if parts == 'overlay':
        side_bars(d)
    return im


def south(parts='all'):
    """Facing the camera: handlebars and front wheel in front of the rider."""
    im = blank()
    d = ImageDraw.Draw(im)
    if parts == 'all':
        d.rectangle((13, 7, 18, 9), fill=SADDLE)
        d.line((13, 9, 18, 9), fill=SADDLE_DARK)
        d.line((14, 10, 14, 16), fill=FRAME)
        d.line((17, 10, 17, 16), fill=FRAME)
    d.rectangle((15, 16, 16, 29), fill=TYRE)
    d.line((14, 18, 14, 27), fill=STEEL)
    d.line((17, 18, 17, 27), fill=STEEL)
    d.rectangle((15, 10, 16, 16), fill=FRAME_LIGHT)
    d.line((9, 12, 22, 12), fill=STEEL)
    d.line((7, 12, 9, 12), fill=GRIP)
    d.line((22, 12, 24, 12), fill=GRIP)
    d.point((7, 13), fill=GRIP)
    d.point((24, 13), fill=GRIP)
    return im


def north(parts='all'):
    """Back to the camera: the rear wheel is nearest."""
    im = blank()
    d = ImageDraw.Draw(im)
    if parts == 'all':
        d.line((10, 8, 21, 8), fill=STEEL)
        d.line((8, 8, 10, 8), fill=GRIP)
        d.line((21, 8, 23, 8), fill=GRIP)
        d.rectangle((15, 8, 16, 12), fill=FRAME)
        d.rectangle((13, 12, 18, 14), fill=SADDLE)
        d.line((13, 14, 18, 14), fill=SADDLE_DARK)
        d.line((14, 15, 14, 19), fill=FRAME)
        d.line((17, 15, 17, 19), fill=FRAME)
    d.rectangle((15, 17, 16, 29), fill=TYRE)
    d.line((14, 19, 14, 27), fill=FRAME)
    d.line((17, 19, 17, 27), fill=FRAME)
    return im


def handlebars():
    im = blank()
    d = ImageDraw.Draw(im)
    d.line((9, 14, 22, 14), fill=STEEL)
    d.line((6, 14, 9, 14), fill=GRIP)
    d.line((22, 14, 25, 14), fill=GRIP)
    d.line((6, 15, 6, 17), fill=GRIP)
    d.line((25, 15, 25, 17), fill=GRIP)
    d.rectangle((15, 14, 16, 20), fill=FRAME_LIGHT)
    return im


def mirrored(im):
    return im.transpose(Image.FLIP_LEFT_RIGHT)


def build():
    # BYOND stores four-direction states as south, north, east, west.
    frames = [south(), north(), side(), mirrored(side()),
              south('overlay'), north('overlay'), side('overlay'), mirrored(side('overlay')),
              handlebars()]
    sheet = Image.new('RGBA', (32 * 3, 32 * 3), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        sheet.paste(frame, ((i % 3) * 32, (i // 3) * 32))
    description = ('# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
                   'state = "bicycle"\n\tdirs = 4\n\tframes = 1\n'
                   'state = "bicycle_overlay"\n\tdirs = 4\n\tframes = 1\n'
                   'state = "bicycle_handlebars"\n\tdirs = 1\n\tframes = 1\n'
                   '# END DMI\n')
    return sheet, description


def main():
    sheet, description = build()
    if '--check' in sys.argv:
        current = Image.open(TARGET)
        same = current.info.get('Description') == description and current.convert('RGBA').tobytes() == sheet.tobytes()
        raise SystemExit(0 if same else 'icons/obj/vehicles/bicycle.dmi is stale; rerun tests/pedal_bicycle/sprites.py')
    info = PngInfo()
    info.add_text('Description', description, zip=True)
    sheet.save(TARGET, format='PNG', pnginfo=info, optimize=True)


if __name__ == '__main__':
    main()
