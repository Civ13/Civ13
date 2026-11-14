"""Repack and verify the Pocket Stronghold 13 gemstone states used by Civ13.

`verify` needs no upstream files: it checks the committed DMI against the
manifest's per-state RGBA hashes. `rebuild --source <ores_gems.dmi>` checks
the pinned upstream file, extracts the selected states unchanged and rewrites
the DMI. `preview --output <png>` draws the actual pixels at 4x for review.
The DMI helpers are shared with the Pocket Stronghold food port.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

from PIL import Image, ImageDraw, ImageFont, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pocket_stronghold_food import read_state, rgba_hash, state_names  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = Path(__file__).resolve().parent / 'sources/pocket_stronghold_gems/manifest.json'
LICENSE = 'icons/obj/pocket_stronghold_gems.dmi.LICENSE.md'


def load_manifest():
    return json.loads(MANIFEST.read_text(encoding='utf-8'))


def verify(target=None):
    manifest = load_manifest()
    target = Path(target) if target else ROOT / manifest['target']
    expected = [entry['state'] for entry in manifest['states']]
    names = state_names(target)
    if names != expected:
        raise AssertionError(f'{target} states {names} != {expected}')
    for entry in manifest['states']:
        image = read_state(target, entry['state'])
        if image.size != (32, 32):
            raise AssertionError(f"{entry['state']} is {image.size}, expected 32x32")
        if rgba_hash(image) != entry['rgba_sha256']:
            raise AssertionError(f"{entry['state']} pixels differ from the attributed source")
    print(f'Verified {len(expected)} states in {target}')


def rebuild(source, output=None):
    manifest = load_manifest()
    data = Path(source).read_bytes()
    pinned = manifest['source_file']
    if hashlib.sha256(data).hexdigest() != pinned['sha256']:
        raise AssertionError('Upstream ores_gems.dmi does not match the pinned SHA-256')
    if hashlib.sha1(f'blob {len(data)}\0'.encode() + data).hexdigest() != pinned['git_blob']:
        raise AssertionError('Upstream ores_gems.dmi does not match the pinned Git blob')
    states = manifest['states']
    sheet = Image.new('RGBA', (32 * len(states), 32))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for i, entry in enumerate(states):
        image = read_state(source, entry['source_state'])
        if rgba_hash(image) != entry['rgba_sha256']:
            raise AssertionError(f"{entry['source_state']} upstream pixels changed")
        sheet.paste(image, (32 * i, 0))
        text += f'state = "{entry["state"]}"\n\tdirs = 1\n\tframes = 1\n'
    text += '# END DMI\n'
    info = PngImagePlugin.PngInfo()
    info.add_text('Description', text, zip=True)
    output = Path(output) if output else ROOT / manifest['target']
    sheet.save(output, format='PNG', pnginfo=info)
    verify(output)


def preview(output):
    manifest = load_manifest()
    target = ROOT / manifest['target']
    states = manifest['states']
    canvas = Image.new('RGB', (40 + 170 * len(states), 300), '#242830')
    draw = ImageDraw.Draw(canvas)
    title = ImageFont.load_default(size=20)
    label = ImageFont.load_default(size=13)
    draw.text((20, 15), 'Pocket Stronghold gemstones in Civ13', fill='white', font=title)
    draw.text((20, 45), 'Actual DMI pixels, nearest-neighbour 4x. Asset preview, not a gameplay screenshot.', fill='white', font=label)
    for i, entry in enumerate(states):
        x = 20 + i * 170
        image = read_state(target, entry['state']).resize((128, 128), Image.Resampling.NEAREST)
        draw.text((x, 80), entry['state'], fill='white', font=label)
        draw.text((x, 98), entry['civ13_use'], fill='#c8c8c8', font=label)
        canvas.paste(image, (x, 125), image)
    draw.text((20, 260), f'Pocket Stronghold 13 / Dwarf Fortress 13 contributors - CC BY-SA 3.0. See {LICENSE}.', fill='white', font=label)
    Path(output).parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output)
    print(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('verify')
    rebuild_parser = sub.add_parser('rebuild')
    rebuild_parser.add_argument('--source', required=True, help='Pocket Stronghold dwarfs/icons/items/ores_gems.dmi at the pinned revision')
    rebuild_parser.add_argument('--output')
    preview_parser = sub.add_parser('preview')
    preview_parser.add_argument('--output', required=True)
    args = parser.parse_args()
    if args.command == 'verify':
        verify()
    elif args.command == 'rebuild':
        rebuild(args.source, args.output)
    else:
        preview(args.output)


if __name__ == '__main__':
    main()
