"""Hand-placed 32px weather station instruments: the ancient bronze rain gauge
(empty and holding rain), the hair hygrometer (a hand item), the cup
anemometer (turning, and standing still) and the louvred instrument screen on
its four legs. Every pixel is placed by this script from a fixed palette
(Pillow only); no external or generated artwork. Art by Fable 5.2.

Run with Pillow to reproduce icons/obj/weather_station.dmi. `--preview <png>`
also writes an enlarged review sheet. Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
ICON = ROOT / 'icons/obj/weather_station.dmi'

# Shared with create_weather_instruments.py so the set reads as one family.
OUT = (28, 22, 16)
POST = [(176, 138, 88), (142, 106, 64), (98, 70, 42)]      # light, mid, dark wood
IRON = [(196, 200, 206), (132, 138, 148), (78, 84, 94)]    # light, mid, dark iron
RED = [(214, 82, 60), (158, 48, 38)]
BRASS = [(246, 214, 120), (212, 168, 72), (160, 116, 44), (104, 72, 28)]
DIAL = [(250, 246, 232), (222, 214, 192)]
STONE = [(150, 148, 140), (112, 110, 104)]
# New for this sheet.
BRONZE = [(214, 160, 96), (174, 118, 62), (128, 82, 44), (84, 52, 30)]
VERDIGRIS = (104, 150, 128)
WATER = [(214, 230, 240), (128, 160, 188), (84, 112, 146)]  # glint, mid, deep
WHITE = [(252, 252, 246), (224, 226, 224), (176, 182, 188), (132, 138, 148)]
HAIR = (236, 222, 176)
HOLLOW = (52, 38, 26)

ANEMOMETER_FRAMES = 4


def blank():
    return Image.new('RGBA', (32, 32), (0, 0, 0, 0))


def put(image, x, y, colour):
    if 0 <= x < 32 and 0 <= y < 32:
        image.putpixel((x, y), colour + (255,))


def row(image, x1, x2, y, colour):
    for x in range(x1, x2 + 1):
        put(image, x, y, colour)


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


def bronze_at(x, left, right):
    """Round shading across a bronze vessel, lit from the upper left."""
    span = right - left
    t = (x - left) / float(span) if span else 0
    if t < 0.12:
        return BRONZE[1]
    if t < 0.36:
        return BRONZE[0]
    if t < 0.68:
        return BRONZE[1]
    if t < 0.9:
        return BRONZE[2]
    return BRONZE[3]


def rain_gauge(full):
    image = blank()
    # Stone plinth.
    row(image, 9, 22, 29, STONE[1])
    row(image, 9, 22, 28, STONE[0])
    row(image, 10, 21, 27, STONE[0])
    row(image, 18, 21, 27, STONE[1])
    put(image, 22, 28, STONE[1])
    # A squat jar: foot ring, swelling belly, drawn-in neck.
    body = {26: (12, 19), 25: (11, 20), 24: (10, 21), 23: (10, 21), 22: (10, 21),
            21: (10, 21), 20: (10, 21), 19: (10, 21), 18: (11, 20), 17: (12, 19),
            16: (12, 19)}
    for y, (left, right) in body.items():
        for x in range(left, right + 1):
            put(image, x, y, bronze_at(x, left, right))
    # Foot ring and two raised bands.
    row(image, 12, 19, 26, BRONZE[3])
    put(image, 13, 26, BRONZE[2])
    for y in (19, 23):
        row(image, 10, 21, y, BRONZE[2])
        row(image, 12, 14, y, BRONZE[1])
        row(image, 19, 21, y, BRONZE[3])
    # A touch of verdigris in the lee of the bands.
    for x, y in ((17, 24), (18, 24), (18, 25), (11, 20), (16, 20)):
        put(image, x, y, VERDIGRIS)
    # The funnel mouth, flaring up from the neck to a wide rim.
    funnel = {15: (11, 20), 14: (10, 21), 13: (9, 22), 12: (8, 23)}
    for y, (left, right) in funnel.items():
        for x in range(left, right + 1):
            put(image, x, y, bronze_at(x, left, right))
    # The open mouth seen from a little above: rim, then the hollow.
    row(image, 9, 22, 10, BRONZE[1])
    row(image, 8, 23, 11, BRONZE[0])
    row(image, 9, 13, 10, BRONZE[0])
    row(image, 20, 23, 11, BRONZE[2])
    row(image, 8, 23, 12, BRONZE[1])
    row(image, 8, 11, 12, BRONZE[0])
    row(image, 20, 23, 12, BRONZE[3])
    if full:
        row(image, 10, 21, 11, WATER[1])
        row(image, 11, 20, 10, WATER[2])
        row(image, 11, 14, 11, WATER[0])
        put(image, 18, 11, WATER[0])
        put(image, 13, 10, WATER[1])
    else:
        row(image, 10, 21, 11, HOLLOW)
        row(image, 11, 20, 10, HOLLOW)
        row(image, 16, 21, 11, BRONZE[3])
    return outline(image)


def hygrometer():
    image = blank()
    # A small upright wooden frame: a backboard with raised side rails.
    for y in range(7, 26):
        for x in range(10, 22):
            put(image, x, y, POST[1])
    for y in range(7, 26):
        put(image, 10, y, POST[0])
        put(image, 21, y, POST[2])
    row(image, 10, 21, 7, POST[0])
    row(image, 11, 21, 25, POST[2])
    # The sunk panel behind the hair, dark so the strand shows.
    for y in range(19, 24):
        row(image, 12, 19, y, POST[2])
    row(image, 12, 19, 19, HOLLOW)
    # The round paper dial with its brass rim.
    cx, cy = 15.5, 13.0
    for y in range(7, 19):
        for x in range(10, 22):
            d2 = (x - cx) ** 2 + (y - cy) ** 2
            if d2 <= 27:
                put(image, x, y, BRASS[2] if x + y < 29 else BRASS[3])
            if d2 <= 16.5:
                put(image, x, y, DIAL[0] if x + y < 30 else DIAL[1])
    put(image, 11, 11, BRASS[1])
    put(image, 12, 10, BRASS[1])
    put(image, 13, 9, BRASS[1])
    # Scale marks and the needle with its pin.
    for x, y in ((12, 13), (13, 11), (15, 10), (16, 10), (18, 11), (19, 13)):
        put(image, x, y, OUT)
    for x, y in ((16, 13), (17, 12), (18, 12)):
        put(image, x, y, RED[1])
    put(image, 15, 13, BRASS[3])
    # The hair: one pale strand from the dial's pulley down to a brass peg.
    for y in range(17, 23):
        put(image, 15, y, HAIR)
    put(image, 15, 23, BRASS[1])
    put(image, 16, 23, BRASS[2])
    # Hanging ring.
    for x, y in ((15, 4), (16, 4), (14, 5), (17, 5), (15, 6), (16, 6)):
        put(image, x, y, BRASS[2])
    put(image, 15, 4, BRASS[1])
    return outline(image)


def cup(image, x, y, tx, back):
    """One hemispherical cup, 3 wide; tx is the side its open mouth faces."""
    lit, mid, dark = (BRASS[1], BRASS[2], BRASS[3]) if back else (BRASS[0], BRASS[1], BRASS[2])
    for dx in (-1, 0, 1):
        put(image, x + dx, y - 1, lit if dx < 1 else mid)
        put(image, x + dx, y, mid if dx < 1 else dark)
        put(image, x + dx, y + 1, mid if dx < 0 else dark)
    if tx:
        # The hollow shows on the side the cup's mouth is turned to.
        for dy in (-1, 0, 1):
            put(image, x + tx, y + dy, HOLLOW)
    elif not back:
        put(image, x, y, HOLLOW)


def anemometer(frame):
    image = blank()
    # Stone footing, as under the weather vane.
    row(image, 12, 19, 29, STONE[1])
    row(image, 12, 19, 28, STONE[0])
    row(image, 13, 18, 27, STONE[0])
    put(image, 18, 27, STONE[1])
    # The iron pole with a collar.
    for y in range(11, 27):
        put(image, 15, y, IRON[0])
        put(image, 16, y, IRON[1])
        put(image, 17, y, IRON[2])
    row(image, 14, 18, 22, IRON[2])
    row(image, 14, 16, 22, IRON[1])
    # The spindle.
    for y in range(8, 11):
        put(image, 16, y, IRON[1])
    hx, hy = 16, 7
    turn = math.radians(12 + frame * 90.0 / ANEMOMETER_FRAMES)
    arms = []
    for k in range(4):
        a = turn + k * math.pi / 2
        cx = int(round(hx + 11 * math.cos(a)))
        cy = int(round(hy + 3.2 * math.sin(a)))
        s = -math.sin(a)
        arms.append((math.sin(a), cx, cy, 1 if s > 0.35 else (-1 if s < -0.35 else 0)))
    arms.sort()
    for depth, cx, cy, tx in arms:      # far cups first, near cups over them
        back = depth < 0
        steps = max(abs(cx - hx), abs(cy - hy))
        for i in range(steps + 1):
            x = int(round(hx + (cx - hx) * i / float(steps)))
            y = int(round(hy + (cy - hy) * i / float(steps)))
            put(image, x, y, IRON[2] if back else IRON[1])
        cup(image, cx, cy, tx, back)
    # The hub cap over the crossing.
    put(image, hx, hy, IRON[0])
    put(image, hx, hy - 1, IRON[0])
    put(image, hx + 1, hy, IRON[2])
    put(image, hx - 1, hy, IRON[1])
    return outline(image)


def weather_station():
    image = blank()
    # Four wooden legs: the far pair first, shorter and darker.
    for y in range(19, 28):
        put(image, 11, y, POST[2])
        put(image, 19, y, POST[2])
    for y in range(19, 30):
        put(image, 7, y, POST[0])
        put(image, 8, y, POST[1])
        put(image, 22, y, POST[1])
        put(image, 23, y, POST[2])
    # A stretcher between the front legs.
    row(image, 9, 21, 24, POST[1])
    row(image, 9, 21, 25, POST[2])
    # The louvred box: white corner posts, slats between them.
    for y in range(8, 19):
        for x in range(7, 24):
            put(image, x, y, WHITE[0])
        put(image, 22, y, WHITE[1])
        put(image, 23, y, WHITE[2])
    for y in range(9, 18):
        slat = WHITE[0] if y % 2 else WHITE[3]
        row(image, 9, 21, y, slat)
        if y % 2:
            row(image, 18, 21, y, WHITE[1])
    # The door's centre stile and its brass latch.
    for y in range(9, 18):
        put(image, 15, y, WHITE[1])
    put(image, 16, 13, BRASS[2])
    # Base board and the shadow under the eaves.
    row(image, 7, 23, 18, WHITE[1])
    row(image, 20, 23, 18, WHITE[2])
    row(image, 7, 23, 8, WHITE[2])
    # The slanted roof, high at the left, overhanging all round.
    for x in range(5, 26):
        top = 4 + (x - 5) // 7
        put(image, x, top, WHITE[0])
        put(image, x, top + 1, WHITE[0] if x < 19 else WHITE[1])
        for y in range(top + 2, 8):
            put(image, x, y, WHITE[2])
    # The little rain gauge on the ground beside it.
    row(image, 26, 30, 29, STONE[1])
    row(image, 26, 30, 28, STONE[0])
    for y in range(24, 28):
        put(image, 27, y, BRONZE[0])
        put(image, 28, y, BRONZE[1])
        put(image, 29, y, BRONZE[2])
    row(image, 26, 30, 23, BRONZE[1])
    put(image, 26, 23, BRONZE[0])
    put(image, 30, 23, BRONZE[2])
    row(image, 27, 29, 22, HOLLOW)
    return outline(image)


def states():
    st = {}
    st['rain_gauge'] = [rain_gauge(False)]
    st['rain_gauge_full'] = [rain_gauge(True)]
    st['hygrometer'] = [hygrometer()]
    st['anemometer'] = [anemometer(f) for f in range(ANEMOMETER_FRAMES)]
    st['anemometer_still'] = [anemometer(0)]
    st['weather_station'] = [weather_station()]
    return st


def dmi_png(st):
    frames = [fr for group in st.values() for fr in group]
    sheet = Image.new('RGBA', (32 * len(frames), 32), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(fr, (i * 32, 0))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, group in st.items():
        text += 'state = "%s"\n\tdirs = 1\n\tframes = %d\n' % (name, len(group))
        if len(group) > 1:
            # One tick a frame; no loop line, so it turns for ever (loop 0).
            text += '\tdelay = %s\n' % ','.join(['1'] * len(group))
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    return sheet, meta


def preview(path, st, scale=8):
    grounds = [(94, 132, 62), (120, 96, 66), (60, 60, 64)]
    cell = 32 * scale
    tiles = [fr for group in st.values() for fr in group]
    sheet = Image.new('RGBA', (cell * len(tiles), cell * len(grounds) + 40), (40, 40, 44, 255))
    for r, ground in enumerate(grounds):
        for c, fr in enumerate(tiles):
            tile = Image.new('RGBA', (32, 32), ground + (255,))
            tile.alpha_composite(fr)
            sheet.paste(tile.resize((cell, cell), Image.NEAREST), (c * cell, r * cell))
    # A 1x strip along the bottom, to judge how each reads at game size.
    for c, fr in enumerate(tiles):
        tile = Image.new('RGBA', (32, 32), grounds[0] + (255,))
        tile.alpha_composite(fr)
        sheet.paste(tile, (c * cell + 4, cell * len(grounds) + 4))
    sheet.save(path)


if __name__ == '__main__':
    st = states()
    sheet, meta = dmi_png(st)
    sheet.save(ICON, format='PNG', pnginfo=meta)
    print('wrote', ICON.relative_to(ROOT))
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1], st)
