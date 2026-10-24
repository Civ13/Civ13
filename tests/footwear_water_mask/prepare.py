"""Stage a tiny production-proc fixture. Does not launch a compiler or runtime."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SOURCE = 'code/game/mob/living/carbon/human/update_icons.dm'
PROCS = ('update_icons', 'update_inv_shoes', 'update_fire', 'proc/get_water_mask_icon',
         'proc/apply_footwear_water_mask', 'proc/clear_overlay_filters')
ASSETS = ('icons/mob/feet.dmi', 'icons/mob/human.dmi', 'icons/mob/OnFire.dmi',
          'icons/mob/human_races/masks/blood_human.dmi', 'icons/turf/beach.dmi')


def procedure(text, name):
    pattern = r'^/mob/living/human/' + re.escape(name) + r'\([^\n]*\n(?:\t[^\n]*\n|\n)*'
    matches = re.findall(pattern, text, re.M)
    if len(matches) != 1:
        raise AssertionError('Expected one production proc: ' + name)
    return matches[0]


def stage(output, control=0):
    if type(control) is not int or control not in (0, 1, 2):
        raise ValueError('Unknown footwear color control')
    output = Path(output)
    output.mkdir(parents=True, exist_ok=False)
    text = (ROOT / SOURCE).read_text(encoding='utf-8')
    constants = text[text.index('#define MUTATIONS_LAYER'):text.index('//////////////////////////////////', text.index('#define MUTATIONS_LAYER'))]
    production = constants + '\n' + '\n'.join(procedure(text, p) for p in PROCS)
    (output / 'production.dm').write_text(production, encoding='utf-8')
    shutil.copyfile(Path(__file__).with_name('probe.dm'), output / 'probe.dm')
    shutil.copyfile(Path(__file__).with_name('rgb_cases.json'), output / 'rgb_cases.json')
    for asset in ASSETS:
        target = output / asset
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / asset, target)
    # Values are extracted, not redefined by the fixture.
    defines = (ROOT / 'code/predefines.dm').read_text(encoding='utf-8')
    planes = (ROOT / 'code/__defines/_planes+layers.dm').read_text(encoding='utf-8')
    selected = '\n'.join(re.search(r'^#define ' + name + r'\s+[^\n]+', content, re.M)[0]
                         for name, content in (('HIDESHOES', defines), ('slot_shoes', defines),
                                               ('FLOOR_PLANE', planes), ('GAME_PLANE', planes)))
    (output / 'probe.dme').write_text(f'#define FOOTWEAR_COLOR_CONTROL {control}\n' + selected + '\n#include "production.dm"\n#include "probe.dm"\n', encoding='utf-8')
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    (output / 'dirty.patch').write_bytes(subprocess.check_output(['git', 'diff', 'HEAD'], cwd=ROOT))
    manifest = {'head': head, 'source': SOURCE, 'control': control, 'scope': 'extracted production procs; adapted 3x3x1 world; no client rendering',
                'sha256': {str(p.relative_to(output)).replace('\\', '/'): hashlib.sha256(p.read_bytes()).hexdigest()
                           for p in output.rglob('*') if p.is_file()}}
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--control', choices=('fixed', 'wrong-rgb', 'missing-stain'), default='fixed')
    args = parser.parse_args()
    print(json.dumps(stage(args.output, {'fixed': 0, 'wrong-rgb': 1, 'missing-stain': 2}[args.control]), indent=2))
