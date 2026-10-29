"""Export labeled existing DMI frames. This does not run or simulate gameplay."""
import argparse
import importlib.util
from pathlib import Path
import re
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]


def key_states():
    """Check the six concrete catalog defaults against the exported map states."""
    source = (ROOT / 'code/modules/1713/extraction/container_keys.dm').read_text()
    base = '/obj/item/weapon/key/extraction_container'
    blocks = dict(re.findall(r'^(' + re.escape(base) + r'(?:/\w+)?)\n(.*?)(?=^/|\Z)',
                             source, re.M | re.S))
    expected = (
        ('Industrial District', ('industrial_tool_cage', 'industrial_dispatch'), 'modern'),
        ('Modern City', ('city_pharmacy', 'city_evidence'), 'key'),
        ('Interchange Mall', ('mall_security', 'mall_hardware'), 'treasure_key'),
    )
    catalog = source.split('/proc/extraction_container_key_type', 1)[0]
    actual = set(re.findall(re.escape(base) + r'/\w+', catalog))
    if actual != {base + '/' + suffix for _, suffixes, _ in expected for suffix in suffixes}:
        raise ValueError('Concrete key catalog changed; update the labeled preview')
    def field(block, name):
        match = re.search(r'^\t' + name + r' = [\'\"]([^\'\"]+)[\'\"]$', block, re.M)
        return match[1] if match else None
    result = []
    for label, suffixes, state in expected:
        for suffix in suffixes:
            block = blocks[base + '/' + suffix]
            icon = field(block, 'icon') or field(blocks[base], 'icon')
            selected = field(block, 'icon_state') or field(blocks[base], 'icon_state')
            if icon != 'icons/obj/key.dmi' or selected != state:
                raise ValueError(f'Preview differs from concrete defaults: {suffix}: {icon}/{selected}')
        result.append((label, 'key.dmi', state))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'docs/images/extraction-container-keys.png')
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location('sprite_validation', ROOT / 'tests/sprites/validate.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    keys = key_states()
    canvas = Image.new('RGB', (900, 668), '#1c222a')
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.load_default(size=18)
    small = ImageFont.load_default(size=14)
    draw.text((24, 18), 'Extraction keys by map - native Civ13 sprites', font=font, fill='white')
    pixels = set()
    for index, (label, filename, state) in enumerate(keys + [
            ('Locked cache', 'storage.dmi', 'securecrate'),
            ('Unlocked cache', 'storage.dmi', 'securecrateopen')]):
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
        if index < 3:
            signature = frame.tobytes()
            if signature in pixels:
                raise ValueError('Map key frames must be pixel-distinct')
            pixels.add(signature)
        frame = frame.resize((width * 6, height * 6), Image.Resampling.NEAREST)
        left = 24 + (index if index < 3 else index - 3) * 288
        top = 54 if index < 3 else 344
        draw.rounded_rectangle((left, top, left + 264, top + 272), radius=8, fill='#303b47')
        canvas.paste(frame, (left + 36, top + 12), frame)
        draw.text((left + 12, top + 214), label, font=font, fill='white')
        draw.text((left + 12, top + 242), f'{filename}: {state}', font=small, fill='#c6d0da')
    draw.text((24, 642), 'Static sprite export - not a gameplay capture', font=small, fill='#c6d0da')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(args.output)
    print(f'PASS: six catalog keys match three pixel-distinct map sprites; five nonempty DMI states; preview saved to {args.output}')


if __name__ == '__main__':
    main()
