"""Clip upholstery slots from Civ13's stock furniture art (no new painted art)."""
from pathlib import Path
import re
import sys
from PIL import Image, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'icons/obj/bed_chair.dmi'
TARGET = ROOT / 'icons/obj/furniture_upholstery.dmi'


def build(output):
    with Image.open(SOURCE) as sheet:
        states = {}
        index = 0
        tiles_per_row = sheet.width // 32
        for name, dirs, frames in re.findall(r'state = "([^"]*)"\s+dirs = (\d+)\s+frames = (\d+)', sheet.info['Description']):
            states[name] = []
            for frame in range(int(dirs)):
                x, y = (index + frame) % tiles_per_row * 32, (index + frame) // tiles_per_row * 32
                states[name].append(sheet.crop((x, y, x + 32, y + 32)).convert('RGBA'))
            index += int(dirs) * int(frames)
    cutouts = {
        'chair_seat': [],
        'chair_back': [],
        'bed_mattress': states['bed_padding'],
        'bed_cover': [],
    }
    for facing, img in enumerate(states['chair_padding']):
        split = 16 if facing < 2 else 14
        for key, box in (('chair_seat', (0, split, 32, 32)), ('chair_back', (0, 0, 32, split))):
            mask = Image.new('RGBA', (32, 32))
            mask.paste(img.crop(box), box[:2])
            cutouts[key].append(mask)
    for img in states['bed_padding']:
        box = (4, 16, 21, 23)
        mask = Image.new('RGBA', (32, 32))
        mask.paste(img.crop(box), box[:2])
        cutouts['bed_cover'].append(mask)
    sheet = Image.new('RGBA', (32 * sum(map(len, cutouts.values())), 32))
    metadata = ['# BEGIN DMI', 'version = 4.0', '\twidth = 32', '\theight = 32']
    pos = 0
    for name, images in cutouts.items():
        metadata.extend((f'state = "{name}"', f'\tdirs = {len(images)}', '\tframes = 1'))
        for img in images:
            assert img.getbbox(), name
            sheet.paste(img, (pos, 0))
            pos += 32
    metadata.append('# END DMI')
    pnginfo = PngImagePlugin.PngInfo()
    pnginfo.add_text('Description', '\n'.join(metadata) + '\n', zip=True)
    sheet.save(output, format='PNG', pnginfo=pnginfo)


if __name__ == '__main__':
    build(Path(sys.argv[1]) if len(sys.argv) > 1 else TARGET)
