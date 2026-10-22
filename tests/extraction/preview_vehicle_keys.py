"""Render the actual vehicle key DMI state for source review, not gameplay."""
import argparse
import importlib.util
from pathlib import Path

from PIL import Image, ImageDraw


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    spec = importlib.util.spec_from_file_location('actual_dmi', root / 'tests/animal_harvest/preview.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    sprite = module.state(root / 'icons/obj/key.dmi', 'modern')
    canvas = Image.new('RGBA', (440, 140), '#20252b')
    canvas.alpha_composite(sprite.resize((96, 96), Image.Resampling.NEAREST), (12, 20))
    draw = ImageDraw.Draw(canvas)
    draw.text((125, 30), 'Constructed vehicle ignition key', fill='white')
    draw.text((125, 55), 'Actual key.dmi / modern state', fill='white')
    draw.text((125, 80), 'Bound vehicle ID + lock generation', fill='white')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert('RGB').save(args.output)
    print('PASS actual nonempty vehicle key sprite preview')


if __name__ == '__main__':
    main()
