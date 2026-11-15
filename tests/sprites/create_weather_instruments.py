"""Hand-placed 32px weather instruments: the weather vane (a wooden post with
a swinging arrow, one state for each of the four winds) and the barometer (a
brass dial in a wooden case). Every pixel is placed by this script from a
fixed palette (Pillow only); no external or generated artwork.

Run with Pillow to reproduce icons/obj/weather_instruments.dmi. `--preview
<png>` also writes an enlarged review sheet. Released under Civ13 AGPL-3.0.
"""
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
ICON = ROOT / 'icons/obj/weather_instruments.dmi'

OUT = (28, 22, 16)
POST = [(176, 138, 88), (142, 106, 64), (98, 70, 42)]      # light, mid, dark wood
IRON = [(196, 200, 206), (132, 138, 148), (78, 84, 94)]    # light, mid, dark iron
RED = [(214, 82, 60), (158, 48, 38)]
BRASS = [(246, 214, 120), (212, 168, 72), (160, 116, 44), (104, 72, 28)]
DIAL = [(250, 246, 232), (222, 214, 192)]
STONE = [(150, 148, 140), (112, 110, 104)]


def blank():
    return Image.new('RGBA', (32, 32), (0, 0, 0, 0))


def put(image, x, y, colour):
    if 0 <= x < 32 and 0 <= y < 32:
        image.putpixel((x, y), colour + (255,))


def outline(image):
    """A one pixel dark edge round everything drawn so far."""
    src = image.copy()
    for y in range(32):
        for x in range(32):
            if src.getpixel((x, y))[3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < 32 and 0 <= ny < 32 and src.getpixel((nx, ny))[3]:
                    put(image, x, y, OUT)
                    break
    return image


def vane(wind):
    """wind: where the wind blows FROM; the arrow's head points into it."""
    image = blank()
    # Stone footing and the post.
    for x in range(12, 20):
        put(image, x, 29, STONE[1])
        put(image, x, 28, STONE[0])
    for x in range(13, 19):
        put(image, x, 27, STONE[0])
    for y in range(10, 27):
        put(image, 15, y, POST[0])
        put(image, 16, y, POST[1])
        put(image, 17, y, POST[2] if y % 5 else POST[1])
    # The fixed cross of the four quarters, under the arrow.
    for x in range(10, 23):
        put(image, x, 14, IRON[2])
    for x in (9, 23):
        put(image, x, 14, IRON[1])
        put(image, x, 13, IRON[1])
        put(image, x, 15, IRON[1])
    # The spindle.
    for y in range(4, 10):
        put(image, 16, y, IRON[1])
    put(image, 16, 3, IRON[0])
    # The arrow, on the spindle at y 7.
    if wind in ('East', 'West'):
        head = 1 if wind == 'East' else -1
        for x in range(6, 27):
            put(image, x, 7, IRON[0])
        tip = 16 + head * 11
        for i in range(4):
            for dy in range(-i, i + 1):
                put(image, tip - head * i, 7 + dy, RED[0] if dy <= 0 else RED[1])
        tail = 16 - head * 10
        for i in range(4):
            for dy in (-1 - i // 2, 1 + i // 2):
                put(image, tail - head * (i - 2), 7 + dy, IRON[1])
            put(image, tail - head * (i - 2), 7, IRON[0])
    else:
        # End on: north wind shows the red head toward the top, south the tail.
        for x in range(13, 20):
            put(image, x, 7, IRON[0])
        if wind == 'North':
            for i in range(4):
                for dx in range(-i, i + 1):
                    put(image, 16 + dx, 2 + i, RED[0] if dx <= 0 else RED[1])
        else:
            for i in range(4):
                for dx in range(-i, i + 1):
                    put(image, 16 + dx, 11 - i, RED[0] if dx <= 0 else RED[1])
            for dx in (-2, -1, 1, 2):
                put(image, 16 + dx, 4, IRON[1])
    return outline(image)


def barometer():
    image = blank()
    # A round wooden case with a brass rim and a pale dial.
    cx, cy = 16, 17
    for y in range(32):
        for x in range(32):
            d2 = (x - cx) ** 2 + (y - cy) ** 2
            if d2 <= 90:
                put(image, x, y, POST[1] if (x + y) % 7 else POST[2])
            if d2 <= 64:
                put(image, x, y, BRASS[1] if x + y < 33 else BRASS[2])
            if d2 <= 42:
                put(image, x, y, DIAL[0] if x + y < 34 else DIAL[1])
    # Brass highlight on the upper left of the rim.
    for x, y in ((10, 12), (11, 11), (12, 10), (13, 10)):
        put(image, x, y, BRASS[0])
    # Scale marks round the top of the dial.
    for x, y in ((11, 16), (12, 13), (14, 12), (16, 11), (18, 12), (20, 13), (21, 16)):
        put(image, x, y, OUT)
    # The needle, toward "change", and its pin.
    for x, y in ((16, 17), (17, 16), (18, 15), (19, 14)):
        put(image, x, y, RED[1])
    put(image, 16, 17, BRASS[3])
    # A hanging ring at the top.
    for x, y in ((15, 6), (16, 5), (17, 6), (16, 7)):
        put(image, x, y, BRASS[2])
    put(image, 16, 6, (0, 0, 0))
    image.putpixel((16, 6), (0, 0, 0, 0))
    return outline(image)


def states():
    st = {}
    for wind in ('North', 'East', 'South', 'West'):
        st['weather_vane_' + wind.lower()] = [vane(wind)]
    st['barometer'] = [barometer()]
    return st


def dmi_png(st):
    frames = [fr for group in st.values() for fr in group]
    sheet = Image.new('RGBA', (32 * len(frames), 32), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(fr, (i * 32, 0))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, group in st.items():
        text += 'state = "%s"\n\tdirs = %d\n\tframes = 1\n' % (name, len(group))
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    return sheet, meta


def preview(path, st, scale=8):
    grounds = [(94, 132, 62), (120, 96, 66), (60, 60, 64)]
    cell = 32 * scale
    names = list(st)
    sheet = Image.new('RGBA', (cell * len(names), cell * len(grounds)), (40, 40, 44, 255))
    for r, ground in enumerate(grounds):
        for c, name in enumerate(names):
            tile = Image.new('RGBA', (32, 32), ground + (255,))
            tile.alpha_composite(st[name][0])
            sheet.paste(tile.resize((cell, cell), Image.NEAREST), (c * cell, r * cell))
    sheet.save(path)


if __name__ == '__main__':
    st = states()
    sheet, meta = dmi_png(st)
    sheet.save(ICON, format='PNG', pnginfo=meta)
    print('wrote', ICON.relative_to(ROOT))
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1], st)
