"""Original hand-placed 32px wind and solar generator sprites, no external or generated artwork.
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


def main():
    states = [
        ('wind_charger', [wind_charger(0)]),
        ('wind_charger_on', [wind_charger(a) for a in (0, 15, 30, 45)]),
        ('wind_turbine', [wind_turbine(-90)]),
        ('wind_turbine_on', [wind_turbine(-90 + a) for a in (0, 30, 60, 90)]),
        ('solar_panel', [solar_panel()]),
    ]
    frames = [frame for _, group in states for frame in group]
    sheet = Image.new('RGBA', (SIZE * len(frames), SIZE))
    for i, frame in enumerate(frames):
        sheet.paste(frame, (i * SIZE, 0))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, group in states:
        text += f'state = "{name}"\n\tdirs = 1\n\tframes = {len(group)}\n'
        if len(group) > 1:
            text += '\tdelay = ' + ','.join(['1'] * len(group)) + '\n'
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(ROOT / 'icons/obj/renewable_power.dmi', format='PNG', pnginfo=meta)


if __name__ == '__main__':
    main()
