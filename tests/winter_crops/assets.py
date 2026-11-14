"""Repack attributed upstream pixels and render a labeled asset preview, not gameplay.

The growth states listed in REDRAWN are Civ13 adaptations drawn by
tests/sprites/create_orchard.py; a repack restores the upstream states and then
lets that script draw its states over them.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
from PIL import Image, ImageDraw, ImageFont, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / 'icons/farming/pocket_stronghold_turnip.dmi'
MANIFEST = ROOT / 'icons/farming/pocket_stronghold_turnip.json'
MAPPING = [('turnip-seeds', 'seeds.dmi', 'turnip'),
           *[(f'turnip-grow{i}', 'growing.dmi', f'turnip-{j}')
             for i, j in enumerate((1, 2, 2, 3, 4, 4), 1)],
           ('turnip-harvest', 'growing.dmi', 'turnip-5'),
           ('turnip-dead', 'growing.dmi', 'turnip-dead'),
           ('turnip', 'growable.dmi', 'turnip')]
REDRAWN = {'turnip': ('grow1', 'grow2', 'grow3', 'grow6'),
           'plump_helmet': ('grow1', 'grow2', 'grow3', 'grow6'),
           'cave_wheat': ('grow1', 'grow2', 'grow3', 'grow4', 'grow5', 'grow6', 'harvest', 'dead')}


def state(path, name):
    sheet = Image.open(path)
    text = sheet.info['Description']
    width = int(re.search(r'width = (\d+)', text)[1])
    height = int(re.search(r'height = (\d+)', text)[1])
    offset = 0
    for match in re.finditer(r'state = "([^"]*)"(.*?)(?=\nstate =|\Z)', text, re.S):
        dirs = int(re.search(r'dirs = (\d+)', match[2])[1])
        frames = int(re.search(r'frames = (\d+)', match[2])[1])
        if match[1] == name:
            assert dirs == frames == 1, 'Selected art must be a single-direction still'
            x, y = offset % (sheet.width // width) * width, offset // (sheet.width // width) * height
            im = sheet.convert('RGBA').crop((x, y, x + width, y + height))
            assert im.getchannel('A').getbbox(), name
            return im
        offset += dirs * frames
    raise ValueError(f'Missing {path}:{name}')


def repack(source):
    manifest = json.loads(MANIFEST.read_text())
    for filename, expected in manifest['source_files'].items():
        data = (source / filename).read_bytes()
        assert hashlib.sha256(data).hexdigest() == expected['sha256'], filename
        assert hashlib.sha1(f'blob {len(data)}\0'.encode() + data).hexdigest() == expected['git_blob'], filename
    sheet = Image.new('RGBA', (32 * len(MAPPING), 32))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for i, (name, filename, original) in enumerate(MAPPING):
        sheet.paste(state(source / filename, original), (32 * i, 0))
        text += f'state = "{name}"\n\tdirs = 1\n\tframes = 1\n'
    text += '# END DMI\n'
    info = PngImagePlugin.PngInfo()
    info.add_text('Description', text, zip=True)
    sheet.save(TARGET, format='PNG', pnginfo=info)
    crop = TARGET.stem.replace('pocket_stronghold_', '')
    redrawn = {f'{crop}-{stage}' for stage in REDRAWN[crop]}
    sys.path.insert(0, str(ROOT / 'tests/sprites'))
    import create_orchard
    relative = TARGET.relative_to(ROOT).as_posix()
    create_orchard.write_dmi(TARGET, create_orchard.build()[relative])
    kept = [entry for entry in MAPPING if entry[0] not in redrawn]
    for name, filename, original in kept:
        assert state(TARGET, name).tobytes() == state(source / filename, original).tobytes()
    print(f'Repacked 10 states: {len(kept)} with exact upstream RGBA equality, {len(redrawn)} redrawn for Civ13')


def preview(output):
    canvas = Image.new('RGB', (1140, 510), '#242830')
    draw = ImageDraw.Draw(canvas)
    # Bundled Pillow font sizes keep labels readable without platform font lookup.
    title_font = ImageFont.load_default(size=20)
    label_font = ImageFont.load_default(size=13)
    crop = TARGET.stem.replace('pocket_stronghold_', '').replace('_', ' ').capitalize()
    draw.text((20, 15), f'{"Cave food" if crop == "Cave wheat" else "Winter food"}: {crop}', fill='white', font=title_font)
    draw.text((20, 45), 'Actual DMI pixels, nearest-neighbor 4x. Asset preview - NOT a gameplay screenshot.', fill='white', font=label_font)
    for i, (name, _, original) in enumerate(MAPPING):
        x, y = 20 + (i % 5) * 224, 80 + (i // 5) * 190
        im = state(TARGET, name).resize((128, 128), Image.Resampling.NEAREST)
        draw.text((x, y), name, fill='white', font=label_font)
        canvas.paste(im, (x, y + 28), im)
    draw.text((20, 466), 'Pocket Stronghold 13 / Dwarf Fortress 13 contributors - CC BY-SA 3.0.', fill='white', font=label_font)
    draw.text((20, 487), 'Upstream states extracted and renamed; early and in-between growth stages redrawn for Civ13. See icons/farming/ATTRIBUTION.md.', fill='white', font=label_font)
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output)
    print(output)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--crop', choices=('turnip', 'plump_helmet', 'cave_wheat'), default='turnip')
    parser.add_argument('--source-dir', type=Path)
    parser.add_argument('--preview', type=Path)
    args = parser.parse_args()
    if args.crop != 'turnip':
        TARGET = ROOT / f'icons/farming/pocket_stronghold_{args.crop}.dmi'
        MAPPING = [(name.replace('turnip', args.crop), file, original.replace('turnip', args.crop)) for name, file, original in MAPPING]
    if args.source_dir:
        repack(args.source_dir)
    if args.preview:
        preview(args.preview)
