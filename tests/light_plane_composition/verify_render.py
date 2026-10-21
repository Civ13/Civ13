"""Pixel acceptance for NEW native captures. Never converts old receipts into passes.

A capture packet supplies baseline/candidate full PNGs for each isolated control,
and a reference PNG for the oversized-occluder target (visible scene unchanged,
uncovered oversized pixels black). The capture procedure must independently
establish the reference and native sight membership; this checker verifies only
source binding, image integrity and pixel equality, not capture authenticity.
"""
import hashlib
import json
from pathlib import Path
from PIL import Image

CASES = ('weather', 'intentional_fullbright', 'dynamic_to_fullbright',
         'fullbright_to_dynamic', 'turf_replacement', 'save_import',
         'sight_bypass', 'sight_restore', 'occluded_oversize')
SOURCES = ('civ13.dme',
           'code/game/mob/living/life.dm',
           'code/game/mob/living/carbon/human/human_life.dm',
           'code/game/mob/observer/ghost/ghost.dm',
           'code/game/area/areas.dm',
           'code/game/area/caribbean.dm',
           'code/__defines/weather.dm',
           'code/modules/1713/weather.dm',
           'code/processes/time_of_day_change.dm',
           'icons/effects/weather.dmi',
           'code/__defines/_planes+layers.dm',
           'code/_onclick/hud/hud.dm',
           'code/game/turfs/turf_changing.dm',
           'code/game/objects/building_levels.dm',
           'code/modules/persistence/functions.dm',
           'icons/effects/icon.png',
           'code/_onclick/hud/plane_master.dm',
           'code/modules/lighting/lighting_overlay.dm',
           'code/modules/lighting/lighting_composition.dm',
           'code/modules/lighting/lighting_turf.dm',
           'code/modules/lighting/lighting_system.dm',
           'code/modules/persistence/loading.dm')


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def compare_pixels(reference, candidate):
    with Image.open(reference) as a, Image.open(candidate) as b:
        a, b = a.convert('RGBA'), b.convert('RGBA')
        if a.size != b.size:
            raise ValueError('Capture dimensions differ')
        # Count all changed channels, including RGB hidden behind alpha=0.
        left, right = a.tobytes(), b.tobytes()
        changed = sum(left[i:i+4] != right[i:i+4] for i in range(0, len(left), 4))
        return changed


def verify(packet, repo):
    root = packet.parent.resolve()
    receipt = json.loads(packet.read_text())
    if receipt.get('renderer') != 'BYOND DreamSeeker 516.1681' or receipt.get('composition_enabled') is not True:
        raise ValueError('New opt-in native capture receipt required')
    if receipt.get('source_sha256') != {name: digest(repo/name) for name in SOURCES}:
        raise ValueError('Captured source differs from reviewed candidate')
    rows = receipt.get('cases', [])
    if [row.get('name') for row in rows] != list(CASES):
        raise ValueError('Complete ordered control matrix required')
    for row in rows:
        paths = []
        for key in ('reference', 'candidate'):
            entry = row[key]
            path = (root/entry['path']).resolve()
            if not path.is_relative_to(root) or digest(path) != entry['sha256']:
                raise ValueError('Capture binding mismatch')
            paths.append(path)
        changed = compare_pixels(*paths)
        if changed:
            raise ValueError(f'{row["name"]}: {changed} changed pixels')
    return {'pixel_cases': len(rows), 'pixel_equal': True,
            'limit': 'Capture authenticity, reference construction and native view membership require independent review.'}


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('packet', type=Path)
    parser.add_argument('--repository', type=Path, default=Path(__file__).resolve().parents[2])
    args = parser.parse_args()
    print(json.dumps(verify(args.packet, args.repository)))
