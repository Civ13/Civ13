"""Render existing DMI pixels for review; this is not gameplay evidence."""
import argparse
import importlib.util
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('native_dmi', ROOT / 'tests/animal_harvest/preview.py')
native_dmi = importlib.util.module_from_spec(spec)
spec.loader.exec_module(native_dmi)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    sprites = [
        ('Radio receiver / program desks', 'device.dmi', 'radio_vintage'),
        ('Television receiver', 'modern_structures.dmi', 'TV'),
        ('Broadcast antenna', 'obj32x64.dmi', 'radio_powered'),
        ('Network landline', 'device.dmi', 'telephone'),
        ('Local terminal', 'computers.dmi', 'ibm'),
    ]
    canvas = Image.new('RGB', (800, 350), '#242830')
    draw = ImageDraw.Draw(canvas)
    draw.text((12, 12), 'Existing Civ13 DMI pixels - static review, no gameplay capture', fill='white')
    for i, (label, resource, state) in enumerate(sprites):
        x, y = 12 + (i % 3) * 265, 45 + (i // 3) * 145
        sprite = native_dmi.state(ROOT / 'icons/obj' / resource, state)
        sprite = sprite.resize((sprite.width * 2, sprite.height * 2), Image.Resampling.NEAREST)
        draw.text((x, y), label, fill='white')
        canvas.paste(sprite, (x, y + 20), sprite)
        draw.text((x, y + 112), f'{resource}: {state}', fill='#CCCCCC')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(args.output)
    print(f'Validated {len(sprites)} nonblank native sprite states: {args.output}')

if __name__ == '__main__':
    main()
