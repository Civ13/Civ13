"""Audit actual native flower-constructor outcomes against decoded DMI states.

Offline only; no compiler, daemon, random sampling or game startup.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


def outcomes(source):
    block = re.search(r'^/obj/structure/wild/flowers\n(.*?)(?=^/|\Z)', source, re.M | re.S)[1]
    body = block.split('\tNew()\n', 1)[1]
    lines = [line.strip() for line in body.splitlines() if line.strip() and not line.strip().startswith('//')]
    if lines[0] != '..()':
        raise ValueError('Unrecognized flower constructor parent call')
    # The combined review keeps the original generic draw behind the exact
    # fixed-scenery guard; audit only its ordinary-flower else branch.
    if lines[1:4] == ['if (fixed_flower_appearance)', 'restore_fixed_flower_appearance()', 'else']:
        lines = [lines[0], *lines[4:]]
    match = re.fullmatch(r'icon_state = "flower\[rand\((\d+),(\d+)\)\]"', lines[1])
    if not match:
        raise ValueError('Unrecognized flower constructor draw')
    low, high = map(int, match.groups())
    if not 1 <= low <= high <= 64:
        raise ValueError('Unbounded flower pool')
    mapping = {}
    if len(lines) == 4:
        condition = re.fullmatch(r'if \(icon_state == "(flower\d+)"\)', lines[2])
        replacement = re.fullmatch(r'icon_state = "(flower\d+)"', lines[3])
        if not condition or not replacement:
            raise ValueError('Unrecognized flower alias')
        mapping[condition[1]] = replacement[1]
    elif len(lines) != 2:
        raise ValueError('Unrecognized flower constructor tail')
    return [mapping.get(f'flower{i}', f'flower{i}') for i in range(low, high + 1)]


def states(icon):
    with Image.open(icon) as image:
        text = image.info['Description']
        width = int(re.search(r'\bwidth = (\d+)', text)[1])
        height = int(re.search(r'\bheight = (\d+)', text)[1])
        sheet = image.convert('RGBA')
    offset = 0
    result = {}
    for match in re.finditer(r'^state = ("(?:[^"\\]|\\.)*")(.*?)(?=^state =|\Z)', text, re.M | re.S):
        name = json.loads(match[1], strict=False)
        directions = int(re.search(r'\bdirs = (\d+)', match[2])[1])
        frames = int(re.search(r'\bframes = (\d+)', match[2])[1])
        x = offset % (sheet.width // width) * width
        y = offset // (sheet.width // width) * height
        pixels = sheet.crop((x, y, x + width, y + height))
        result[name] = {'size': [width, height], 'directions': directions, 'frames': frames,
                        'nonempty': bool(pixels.getchannel('A').getbbox()),
                        'rgba_sha256': hashlib.sha256(pixels.tobytes()).hexdigest()}
        offset += directions * frames
    return result


def audit(source, icon):
    selected = outcomes(source.read_text(encoding='utf-8'))
    decoded = states(icon)
    missing = sorted(set(selected) - decoded.keys())
    invalid = sorted({name for name in selected if name in decoded and
                      (decoded[name]['size'] != [32, 32] or decoded[name]['directions'] != 1
                       or decoded[name]['frames'] != 1 or not decoded[name]['nonempty'])})
    return {'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
            'icon_sha256': hashlib.sha256(icon.read_bytes()).hexdigest(),
            'outcomes_by_original_roll': selected, 'missing_states': missing,
            'invalid_states': invalid, 'status': 'failed' if missing or invalid else 'passed',
            'scope': 'Exhaustive offline constructor-outcome / actual DMI pixel audit; not native gameplay'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=ROOT / 'code/game/objects/structures/wild.dm')
    parser.add_argument('--icon', type=Path, default=ROOT / 'icons/obj/flora/ausflora.dmi')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    result = audit(args.source, args.icon)
    text = json.dumps(result, indent=2) + '\n'
    if args.output:
        args.output.write_text(text, encoding='utf-8')
    print(text, end='')
    return result['status'] != 'passed'


if __name__ == '__main__':
    raise SystemExit(main())
