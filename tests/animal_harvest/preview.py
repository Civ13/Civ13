"""Validate effective DMI states and render real game sprites for PR review."""
import argparse
from pathlib import Path
import re
from PIL import Image, ImageDraw, ImageChops


def state(path, name):
    sheet = Image.open(path)
    description = sheet.info['Description']
    width = int(re.search(r'width = (\d+)', description)[1])
    height = int(re.search(r'height = (\d+)', description)[1])
    offset = 0
    for match in re.finditer(r'state = "([^"]+)"(.*?)(?=\nstate =|\Z)', description, re.S):
        body = match[2]
        if match[1] == name:
            x = offset % (sheet.width // width) * width
            y = offset // (sheet.width // width) * height
            sprite = sheet.convert('RGBA').crop((x, y, x + width, y + height))
            assert sprite.getbbox(), f'Blank state: {path}:{name}'
            return sprite
        dirs = re.search(r'dirs = (\d+)', body)
        frames = re.search(r'frames = (\d+)', body)
        offset += int(dirs[1]) if dirs else 1
        if frames:
            offset -= int(dirs[1]) if dirs else 1
            offset += (int(dirs[1]) if dirs else 1) * int(frames[1])
    raise ValueError(f'Missing state: {path}:{name}')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    states = [('giblets / intestines', 'innards', 'innards'), ('heart', 'heart-off', 'heart-x'),
              ('liver', 'liver', 'liver-x'), ('kidneys', 'kidneys', 'kidneys-x'),
              ('lungs', 'lungs', 'lungs-x'), ('brain', 'brain', 'brain-x'),
              ('stomach', 'stomach', 'stomach-x')]
    canvas = Image.new('RGB', (760, 640), '#242830')
    draw = ImageDraw.Draw(canvas)
    draw.text((20, 10), 'Civ13 animal harvest - existing DMI sprites, nearest-neighbor 2x offal / 4x sinew', fill='white')
    for i, (label, fresh, rotten) in enumerate(states):
        x, y = 20 + (i % 4) * 185, 45 + (i // 4) * 195
        draw.text((x, y), label, fill='white')
        for j, name in enumerate([fresh, rotten]):
            sprite = state(root / 'icons/obj/surgery.dmi', name).resize((64, 64), Image.Resampling.NEAREST)
            canvas.paste(sprite, (x + j * 80, y + 25), sprite)
            draw.text((x + j * 80, y + 100), 'fresh' if j == 0 else 'rotten', fill='white')
            draw.text((x + j * 80, y + 120), name, fill='#CCCCCC')
    sprite = state(root / 'icons/obj/materials.dmi', 'rope')
    tint = Image.new('RGBA', sprite.size, (223, 196, 172, 255))
    sprite = ImageChops.multiply(sprite, tint).resize((128, 128), Image.Resampling.NEAREST)
    draw.text((20, 445), 'sinew: materials.dmi / rope, color #DFC4AC', fill='white')
    canvas.paste(sprite, (20, 475), sprite)
    draw.text((180, 490), 'No upstream assets or AI-generated imagery.\nFood sprites inherit existing cooking/decay presentation.\nBinding cord uses the existing rope sprite.', fill='white')
    canvas.save(args.output)
    print(f'Validated 14 offal states and tinted sinew: {args.output}')


if __name__ == '__main__':
    main()
