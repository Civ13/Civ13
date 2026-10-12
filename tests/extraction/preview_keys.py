"""Export labeled existing DMI frames. This does not run or simulate gameplay."""
import argparse
import importlib.util
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'docs/images/extraction-container-keys.png')
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location('sprite_validation', ROOT / 'tests/sprites/validate.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    canvas = Image.new('RGB', (720, 300), '#1c222a')
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.load_default(size=18)
    small = ImageFont.load_default(size=14)
    draw.text((24, 18), 'Existing Civ13 DMI frames', font=font, fill='white')
    for index, (label, filename, state) in enumerate((
            ('Container key', 'key.dmi', 'modern'),
            ('Locked cache', 'storage.dmi', 'securecrate'),
            ('Unlocked cache', 'storage.dmi', 'securecrateopen'))):
        path = ROOT / 'icons/obj' / filename
        width, height, states = module.dmi(path)
        first, dirs, frames = states[state]
        sheet = Image.open(path).convert('RGBA')
        columns = sheet.width // width
        for n in range(first, first + dirs * frames):
            frame = sheet.crop(((n % columns) * width, (n // columns) * height,
                                (n % columns + 1) * width, (n // columns + 1) * height))
            if frame.getbbox() is None:
                raise ValueError(f'Transparent DMI frame: {filename}/{state}')
        frame = sheet.crop(((first % columns) * width, (first // columns) * height,
                            (first % columns + 1) * width, (first // columns + 1) * height))
        frame = frame.resize((width * 4, height * 4), Image.Resampling.NEAREST)
        left = 24 + index * 232
        draw.rounded_rectangle((left, 54, left + 208, 248), radius=8, fill='#303b47')
        canvas.paste(frame, (left + 40, 68), frame)
        draw.text((left + 12, 202), label, font=font, fill='white')
        draw.text((left + 12, 227), f'{filename}: {state}', font=small, fill='#c6d0da')
    draw.text((24, 270), 'Static sprite export - not a gameplay capture', font=small, fill='#c6d0da')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(args.output)
    print(f'PASS: three real DMI states have nonempty frames; preview saved to {args.output}')


if __name__ == '__main__':
    main()
