"""Lossless, offline conversion and audit for one explicitly selected art batch.

Requires Pillow. Never fetches sources, runs BYOND, or changes gameplay files.
"""
import argparse
import hashlib
from io import BytesIO
import json
from pathlib import Path
import re
import subprocess

from PIL import Image, ImageDraw, ImageFont, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(__file__).resolve().parent / 'sources/humanity_wild_herbs'
STATES = ('yarrow', 'milk_thistle', 'elderflower', 'comfrey')


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def git_blob(data):
    return hashlib.sha1(f'blob {len(data)}\0'.encode() + data).hexdigest()


def git(repo, *args):
    return subprocess.check_output(['git', '-C', str(repo), *args])


def sources(directory=SOURCE, upstream=None):
    """Validate both current and original rights metadata and every source byte."""
    manifest = json.loads((directory / 'manifest.json').read_text(encoding='utf-8'))
    if (manifest['states'] != list(STATES) or manifest['size'] != [32, 32]
            or manifest['directions'] != 1 or manifest['frames'] != 1
            or manifest['license'] != 'CC0-1.0'):
        raise ValueError('Unsupported batch contract')
    expected_files = {f'{name}.png' for name in STATES} | {'meta.json', 'meta.original.json'}
    if set(manifest['files']) != expected_files:
        raise ValueError('Manifest source entries must be exactly the six selected files')
    for filename, entry in manifest['files'].items():
        data = (directory / filename).read_bytes()
        if sha256(data) != entry['sha256'] or git_blob(data) != entry['git_blob']:
            raise ValueError(f'Source hash mismatch: {filename}')
        if upstream:
            revision = entry.get('revision', manifest['source_revision'])
            original = git(upstream, 'show', f"{revision}:{entry['upstream_path']}")
            if data != original:
                raise ValueError(f'Upstream mismatch: {filename}')
            if filename.endswith('.png'):
                at_origin = git(upstream, 'show',
                                f"{manifest['art_origin_revision']}:{entry['upstream_path']}")
                if data != at_origin:
                    raise ValueError(f'Changed since original art commit: {filename}')
    for filename in ('meta.json', 'meta.original.json'):
        meta = json.loads((directory / filename).read_text(encoding='utf-8'))
        if meta['license'] != 'CC0-1.0' or meta['size'] != {'x': 32, 'y': 32}:
            raise ValueError(f'Rights or dimensions changed: {filename}')
        selected_rows = [s for s in meta['states'] if s['name'] in STATES]
        selected = {s['name']: s for s in selected_rows}
        if len(selected_rows) != len(STATES) or len(selected) != len(STATES):
            raise ValueError(f'Missing or repeated selected RSI state: {filename}')
        for name in STATES:
            state = selected[name]
            # A future animated/directional variant must receive a new reviewed converter.
            if set(state) - {'name', 'directions'} or state.get('directions', 1) != 1:
                raise ValueError(f'Unsupported RSI semantics: {filename}:{name}')
    pictures = []
    for name in STATES:
        with Image.open(directory / f'{name}.png') as image:
            picture = image.convert('RGBA')
        if picture.size != (32, 32) or not picture.getchannel('A').getbbox():
            raise ValueError(f'Invalid source pixels: {name}')
        pictures.append(picture)
    if len({p.tobytes() for p in pictures}) != len(pictures):
        raise ValueError('Duplicate source states')
    return manifest, pictures


def description():
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name in STATES:
        text += f'state = "{name}"\n\tdirs = 1\n\tframes = 1\n'
    return text + '# END DMI\n'


def convert(pictures):
    sheet = Image.new('RGBA', (32 * len(STATES), 32))
    for i, picture in enumerate(pictures):
        # No mask: preserve RGBA bytes, including any invisible RGB values.
        sheet.paste(picture, (i * 32, 0))
    info = PngImagePlugin.PngInfo()
    info.add_text('Description', description(), zip=True)
    output = BytesIO()
    sheet.save(output, format='PNG', pnginfo=info)
    return output.getvalue()


def verify(target, pictures):
    with Image.open(target) as image:
        if image.info.get('Description') != description() or image.size != (128, 32):
            raise ValueError('DMI state/direction/frame/size metadata changed')
        sheet = image.convert('RGBA')
    for i, (name, picture) in enumerate(zip(STATES, pictures)):
        if sheet.crop((i * 32, 0, i * 32 + 32, 32)).tobytes() != picture.tobytes():
            raise ValueError(f'DMI pixel mismatch: {name}')
    return {'states': list(STATES), 'dimensions': [32, 32], 'directions': 1,
            'frames': 1, 'exact_rgba': True, 'target_sha256': sha256(target.read_bytes())}


def dmi_frames(data):
    """Decode stored frames independently of names; BYOND order is S,N,E,W,... ."""
    with Image.open(BytesIO(data)) as image:
        text = image.info.get('Description', '')
        sheet = image.convert('RGBA')
    if not text:
        yield {'state': '(PNG)', 'direction_index': 0, 'frame': 0}, sheet
        return
    width = int(re.search(r'\bwidth\s*=\s*(\d+)', text)[1])
    height = int(re.search(r'\bheight\s*=\s*(\d+)', text)[1])
    if width <= 0 or height <= 0 or sheet.width % width or sheet.height % height:
        raise ValueError('Invalid DMI grid')
    offset = 0
    pattern = r'^state\s*=\s*("(?:[^"\\]|\\.)*")(.*?)(?=^state\s*=|\Z)'
    matches = list(re.finditer(pattern, text, re.M | re.S))
    if len(matches) != len(re.findall(r'^state\s*=', text, re.M)):
        raise ValueError('Unparsed DMI state declaration')
    for match in matches:
        # Two baseline states contain literal control characters in their names.
        name = json.loads(match[1], strict=False)
        dirs = int(re.search(r'\bdirs\s*=\s*(\d+)', match[2])[1])
        frames = int(re.search(r'\bframes\s*=\s*(\d+)', match[2])[1])
        if dirs not in (1, 4, 8) or frames < 1:
            raise ValueError('Unsupported DMI layout')
        for frame in range(frames):
            for direction in range(dirs):
                cell = offset + frame * dirs + direction
                x = cell % (sheet.width // width) * width
                y = cell // (sheet.width // width) * height
                if y + height > sheet.height:
                    raise ValueError('DMI frame outside grid')
                yield {'state': name, 'direction_index': direction, 'frame': frame}, sheet.crop(
                    (x, y, x + width, y + height))
        offset += dirs * frames
    # Baseline vehicles/testing.dmi is a valid state-less sheet with no frames.


def visible_hash(image, crop=False):
    image = image.convert('RGBA')
    box = image.getchannel('A').getbbox()
    if box is None:
        return None
    if crop:
        image = image.crop(box)
    # Ignore hidden RGB when looking for displayed duplicates. Conversion still
    # retains those bytes, and verify() compares the exact original RGBA values.
    image.paste((0, 0, 0, 0), mask=image.getchannel('A').point(
        [255] + [0] * 255))
    return sha256(str(image.size).encode() + image.tobytes())


def audit(repo, revision, pictures):
    """Compare every committed icons PNG/DMI frame, including translated/mirrored art."""
    candidates = []
    for name, picture in zip(STATES, pictures):
        candidates.append({'state': name, 'same_state_name': [], 'pixel_matches': [],
                           'exact': visible_hash(picture), 'crop': visible_hash(picture, True),
                           'mirror': visible_hash(picture.transpose(Image.Transpose.FLIP_LEFT_RIGHT), True)})
    paths = git(repo, 'ls-tree', '-r', '--name-only', revision, 'icons').decode().splitlines()
    sheets = frames = 0
    empty_sheets = []
    for path in paths:
        if not path.lower().endswith(('.png', '.dmi')):
            continue
        data = git(repo, 'show', f'{revision}:{path}')
        sheets += 1
        sheet_frames = 0
        for semantic, image in dmi_frames(data):
            frames += 1
            sheet_frames += 1
            exact = visible_hash(image)
            crop = visible_hash(image, True)
            for candidate in candidates:
                reference = {'path': path, **semantic}
                if semantic['state'] == candidate['state']:
                    candidate['same_state_name'].append(reference)
                if exact and (exact == candidate['exact'] or crop in (candidate['crop'], candidate['mirror'])):
                    candidate['pixel_matches'].append(reference)
        if not sheet_frames:
            empty_sheets.append(path)
    for candidate in candidates:
        for key in ('exact', 'crop', 'mirror'):
            del candidate[key]
    return {'baseline_revision': revision, 'image_sheets': sheets, 'decoded_frames': frames,
            'state_less_sheets': empty_sheets, 'errors': [], 'candidates': candidates,
            'limits': 'Compares full visible RGBA, alpha-bounded translation and horizontal mirror; '
                      'does not prove originality or detect every recoloring, redraw, composited overlay or historical deletion.'}


def preview(pictures, output):
    canvas = Image.new('RGB', (880, 280), '#252932')
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.load_default()
    draw.text((16, 14), 'Humanity wild medicinal plants - original pixels, enlarged 4x for review', fill='white', font=font)
    for i, (name, picture) in enumerate(zip(STATES, pictures)):
        x = 24 + i * 216
        draw.text((x, 50), name, fill='white', font=font)
        enlarged = picture.resize((128, 128), Image.Resampling.NEAREST)
        canvas.paste(enlarged, (x, 78), enlarged)
        canvas.paste(picture, (x + 152, 174), picture)
    draw.text((16, 234), 'escortag / escortage - CC0-1.0. DMI repack only; no redraw or scaling of game assets.', fill='white', font=font)
    draw.text((16, 254), 'Asset preview, not gameplay. No harvesting, crop or medical behavior is implemented by this import.', fill='white', font=font)
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('rebuild', 'verify', 'audit', 'preview'))
    parser.add_argument('--upstream', type=Path, help='Optional local Humanity Git checkout; validates pinned Git objects')
    parser.add_argument('--baseline-repo', type=Path, default=ROOT)
    parser.add_argument('--baseline', help='Defaults to manifest Civ13 baseline; requires its Git objects')
    parser.add_argument('--output', type=Path, help='DMI output for rebuild, JSON for audit, PNG for preview')
    args = parser.parse_args()
    manifest, pictures = sources(upstream=args.upstream)
    target = ROOT / manifest['target']
    if args.command == 'rebuild':
        target = args.output or target
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(convert(pictures))
        result = verify(target, pictures)
    elif args.command == 'verify':
        result = verify(target, pictures)
    elif args.command == 'audit':
        result = audit(args.baseline_repo, args.baseline or manifest['baseline_revision'], pictures)
        if not args.output:
            parser.error('audit requires --output')
        args.output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
        if any(row['pixel_matches'] for row in result['candidates']):
            raise ValueError('Duplicate selected art found; inspect report')
    else:
        if not args.output:
            parser.error('preview requires --output')
        preview(pictures, args.output)
        result = {'preview': str(args.output)}
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
