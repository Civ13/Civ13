"""Pale grey holding tank for tanks of any metal.

    python3 tests/sprites/create_fluid_tanks.py [--preview sheet.png] [--check]

Run with Pillow to reproduce icons/obj/fluid_tanks.dmi. The one state, `tank`,
is the existing red holding tank (`air` in icons/obj/barrel.dmi) with its
colour taken out: each pixel keeps its brightness on a pale grey ramp, because
the game tints the tank with its material's colour
(code/modules/materials/vessel_materials.dm). No pixel is drawn by hand.
`--preview <png>` writes a 4x sheet: untinted, then copper, bronze, lead and
iron. `--check` writes nothing and fails when the committed sheet differs.
"""
import re
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'icons/obj/barrel.dmi'
DMI = ROOT / 'icons/obj/fluid_tanks.dmi'
STATE = 'tank'
TEXT = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\nstate = "%s"\n\tdirs = 1\n\tframes = 1\n# END DMI\n' % STATE
# material colours from code/modules/materials/materials.dm, for the preview only
PREVIEW = (('copper', '#b87333'), ('bronze', '#7c4611'), ('lead', '#444f53'), ('iron', '#5C5454'))


def source_tile(name):
    with Image.open(SOURCE) as im:
        text = im.info['Description']
        sheet = im.convert('RGBA')
    index = 0
    for state, dirs, frames in re.findall(r'state = "([^"]*)"\s+dirs = (\d+)\s+frames = (\d+)', text):
        if state == name:
            break
        index += int(dirs) * int(frames)
    else:
        raise SystemExit('%s has no state %s' % (SOURCE, name))
    columns = sheet.size[0] // 32
    left, top = index % columns * 32, index // columns * 32
    return sheet.crop((left, top, left + 32, top + 32))


def build():
    tile = source_tile('air')
    out = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
    solid = sorted(sum(tile.getpixel((x, y))[:3]) for y in range(32) for x in range(32) if tile.getpixel((x, y))[3])
    # the tank is red, so its highlights and shadows show in the sum of the three channels;
    # the outline is the darkest tenth and all goes to the bottom of the ramp
    low = solid[len(solid) // 10]
    high = solid[-1]
    for y in range(32):
        for x in range(32):
            r, g, b, a = tile.getpixel((x, y))
            if not a:
                continue
            # stretch that shading over a pale ramp, darkest 80 and brightest 255
            v = 80 + max(0, r + g + b - low) * 175 // max(1, high - low)
            out.putpixel((x, y), (v, v, v, a))
    return out


def tinted(im, colour):
    r, g, b = (int(colour[i:i + 2], 16) for i in (1, 3, 5))
    out = im.copy()
    for y in range(32):
        for x in range(32):
            pr, pg, pb, pa = im.getpixel((x, y))
            out.putpixel((x, y), (pr * r // 255, pg * g // 255, pb * b // 255, pa))
    return out


def main():
    tile = build()
    if '--check' in sys.argv:
        with Image.open(DMI) as im:
            same = im.info.get('Description', '') == TEXT and im.convert('RGBA').tobytes() == tile.tobytes()
        if not same:
            print('fluid_tanks.dmi differs')
            sys.exit(1)
        print('fluid_tanks.dmi matches (1 state)')
    else:
        meta = PngImagePlugin.PngInfo()
        meta.add_text('Description', TEXT, zip=True)
        tile.save(DMI, format='PNG', pnginfo=meta)
    if '--preview' in sys.argv[1:-1]:
        tiles = [tile] + [tinted(tile, colour) for _, colour in PREVIEW]
        sheet = Image.new('RGBA', (len(tiles) * 136 + 8, 144), (86, 110, 84, 255))
        for i, t in enumerate(tiles):
            big = t.resize((128, 128), Image.NEAREST)
            sheet.paste(big, (8 + i * 136, 8), big)
        sheet.save(sys.argv[sys.argv.index('--preview') + 1])


if __name__ == '__main__':
    main()
