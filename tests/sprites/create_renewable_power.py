"""Original hand-placed 32px wind, solar and waterwheel generator sprites, no external or generated artwork.
Run with Pillow to reproduce icons/obj/renewable_power.dmi; released under Civ13 AGPL-3.0.
"""
import math
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SIZE = 32


def rotor(d, hub, blades, length, angle, fill, edge, width=1):
    for i in range(blades):
        a = math.radians(angle + i * 360 / blades)
        tip = (hub[0] + length * math.cos(a), hub[1] + length * math.sin(a))
        d.line([hub, tip], fill=edge, width=width + 1)
        d.line([hub, tip], fill=fill, width=width)


def wind_charger(angle):
    """Interwar wind charger: steel lattice tower, many-bladed wooden rotor, tail vane."""
    im = Image.new('RGBA', (SIZE, SIZE))
    d = ImageDraw.Draw(im)
    # Lattice tower legs and cross bracing.
    d.line([(9, 31), (15, 12)], fill='#4a4d52')
    d.line([(23, 31), (17, 12)], fill='#4a4d52')
    d.line([(10, 31), (16, 12)], fill='#7d8188')
    for y in (28, 23, 18, 14):
        half = 3 + (y - 12) * 7 // 19
        d.line([(16 - half, y), (16 + half, y)], fill='#6b6f75')
    d.line([(11, 28), (19, 18)], fill='#5d6166')
    d.line([(21, 28), (13, 18)], fill='#5d6166')
    # Generator body and tail vane.
    d.rectangle((14, 9, 19, 12), fill='#3e4a3f', outline='#252b26')
    d.line([(19, 10), (26, 7)], fill='#3a3a3a')
    d.polygon([(24, 4), (29, 6), (29, 9), (25, 8)], fill='#b0412f', outline='#6e271c')
    # Rotor: six wooden blades around a hub.
    rotor(d, (14, 10), 6, 7, angle, '#b98a52', '#6b4a28')
    d.rectangle((13, 9, 15, 11), fill='#2b2b2b')
    return im


def wind_turbine(angle):
    """Modern three-bladed utility turbine on a tapered tubular tower."""
    im = Image.new('RGBA', (SIZE, SIZE))
    d = ImageDraw.Draw(im)
    d.polygon([(14, 31), (18, 31), (17, 10), (15, 10)], fill='#e6e9ec', outline='#9aa1a8')
    d.line([(17, 30), (17, 11)], fill='#c3c8cd')
    d.rectangle((13, 30, 19, 31), fill='#8d9298')
    d.rectangle((14, 7, 20, 10), fill='#f3f5f7', outline='#8f969d')
    rotor(d, (14, 9), 3, 9, angle, '#fbfcfd', '#a3aab1')
    d.ellipse((12, 7, 16, 11), fill='#d9dde1', outline='#8f969d')
    return im


def solar_panel():
    """Framed photovoltaic module tilted toward the sun on a steel stand."""
    im = Image.new('RGBA', (SIZE, SIZE))
    d = ImageDraw.Draw(im)
    d.line([(9, 29), (9, 21)], fill='#5d6166', width=2)
    d.line([(23, 29), (23, 15)], fill='#5d6166', width=2)
    d.line([(9, 29), (23, 29)], fill='#4a4d52')
    panel = [(3, 22), (27, 22), (30, 9), (6, 9)]
    d.polygon(panel, fill='#1f3463', outline='#b9c0c7')
    # Cell grid follows the panel's slant.
    for i in range(1, 4):
        t = i / 4
        d.line([(3 + 24 * t, 22), (6 + 24 * t, 9)], fill='#7f95c4')
    for i in range(1, 3):
        t = i / 3
        y = 22 - 13 * t
        d.line([(3 + 3 * t + 1, y), (27 + 3 * t - 1, y)], fill='#7f95c4')
    d.line([(8, 11), (14, 11)], fill='#c9d6f2')
    return im


def waterwheel(angle, frame=0):
    """Undershot paddle wheel standing in the stream on timber trestles.

    The lower paddles dip below the waterline at row 22, so the water tile
    beneath shows through them. Eight paddles repeat every 45 degrees, so
    frames 11.25 degrees apart loop as a steady turn.
    """
    wheel = Image.new('RGBA', (SIZE, SIZE))
    d = ImageDraw.Draw(wheel)
    hub = (16, 13)
    for i in range(8):
        t = math.radians(angle + i * 45)
        # Paddle stubs standing out past the rim.
        d.line([(hub[0] + 9 * math.cos(t), hub[1] + 9 * math.sin(t)),
                (hub[0] + 13 * math.cos(t), hub[1] + 13 * math.sin(t))], fill='#4f3520', width=3)
    d.ellipse((5, 2, 27, 24), outline='#53371f', width=3)
    d.ellipse((7, 4, 25, 22), outline='#b48854', width=1)
    rotor(d, hub, 8, 9, angle, '#c69a60', '#694727')
    submerge(wheel)
    im = Image.new('RGBA', (SIZE, SIZE))
    d = ImageDraw.Draw(im)
    # Timber trestles either side carry the axle.
    for x0, x1 in ((3, 9), (29, 23)):
        d.line([(x0, 24), (x1, 13)], fill='#3f2a17', width=3)
        d.line([(x0, 24), (x1, 13)], fill='#7a5531')
    im.alpha_composite(wheel)
    d = ImageDraw.Draw(im)
    d.line([(8, 13), (24, 13)], fill='#3a3a36', width=2)
    d.ellipse((13, 10, 19, 16), fill='#6c6d68', outline='#313633')
    # Foam where the paddles bite, shifting with each frame.
    for i, x in enumerate(range(4 + frame % 2, 29, 3)):
        y = 22 + ((i + frame) % 3 == 0)
        d.point((x, y), fill='#e8f3f4')
        d.point((x + 1, y), fill='#bcd8dc')
    return im


def submerge(im, top=23):
    """Fade and cool pixels below the waterline so the water reads through."""
    px = im.load()
    for y in range(top, SIZE):
        for x in range(SIZE):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = ((r + 40) // 3, (g + 90) // 3, (b + 120) // 3, a * 2 // 5)


def waterwheel_edge(angle, frame=0):
    """The same wheel seen edge-on in a north-south river.

    The axle crosses the stream from bank to bank; paddles pass as bars and
    the near ones (lit) travel down the screen as angle grows, with the water.
    """
    wheel = Image.new('RGBA', (SIZE, SIZE))
    d = ImageDraw.Draw(wheel)
    for back in (True, False):
        for i in range(8):
            t = math.radians(angle + i * 45)
            if (math.cos(t) < 0) != back:
                continue
            y = round(13 + 11 * math.sin(t))
            fill, edge = ('#7f5a33', '#3f2a17') if back else ('#d0a46a', '#4f3520')
            d.rectangle((11, y - 1, 21, y + 1), fill=fill, outline=edge)
        if back:
            # Side rims seen edge-on, between the far and near paddles.
            for x in (12, 20):
                d.line([(x, 2), (x, 24)], fill='#53371f', width=2)
    submerge(wheel)
    im = Image.new('RGBA', (SIZE, SIZE))
    d = ImageDraw.Draw(im)
    # Trestles stand on each bank; the axle spans the channel.
    for x in (3, 29):
        d.line([(x, 25), (x, 11)], fill='#3f2a17', width=3)
        d.line([(x, 25), (x, 11)], fill='#7a5531')
    d.line([(2, 13), (30, 13)], fill='#3a3a36', width=2)
    im.alpha_composite(wheel)
    d = ImageDraw.Draw(im)
    d.rectangle((14, 11, 18, 15), fill='#6c6d68', outline='#313633')
    for i, x in enumerate(range(9 + frame % 2, 23, 3)):
        y = 22 + ((i + frame) % 3 == 0)
        d.point((x, y), fill='#e8f3f4')
        d.point((x + 1, y), fill='#bcd8dc')
    return im


def waterwheel_dirs(angle, frame=0):
    """DMI dir order south, north, east, west; the icon faces the current.

    Face-on frames turn clockwise, so their bottom paddles run west; east is
    the mirror. North-flowing water runs the edge-on wheel backwards.
    """
    face = waterwheel(angle, frame)
    return [waterwheel_edge(angle, frame), waterwheel_edge(-angle, frame),
            face.transpose(Image.FLIP_LEFT_RIGHT), face]


def main():
    states = [
        ('wind_charger', [wind_charger(0)]),
        ('wind_charger_on', [wind_charger(a) for a in (0, 15, 30, 45)]),
        ('wind_turbine', [wind_turbine(-90)]),
        ('wind_turbine_on', [wind_turbine(-90 + a) for a in (0, 30, 60, 90)]),
        ('solar_panel', [solar_panel()]),
        ('waterwheel', [waterwheel_dirs(0)]),
        ('waterwheel_on', [waterwheel_dirs(i * 11.25, i) for i in range(4)]),
    ]
    # A group entry is one frame, or a list of four dir images for that frame.
    frames = [img for _, group in states for frame in group
              for img in (frame if isinstance(frame, list) else [frame])]
    sheet = Image.new('RGBA', (SIZE * len(frames), SIZE))
    for i, frame in enumerate(frames):
        sheet.paste(frame, (i * SIZE, 0))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, group in states:
        dirs = 4 if isinstance(group[0], list) else 1
        text += f'state = "{name}"\n\tdirs = {dirs}\n\tframes = {len(group)}\n'
        if len(group) > 1:
            text += '\tdelay = ' + ','.join(['1'] * len(group)) + '\n'
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(ROOT / 'icons/obj/renewable_power.dmi', format='PNG', pnginfo=meta)


if __name__ == '__main__':
    main()
