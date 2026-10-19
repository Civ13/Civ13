"""Prepare hash-bound production fixtures without invoking BYOND."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
HUMAN = 'code/game/mob/living/carbon/human/human.dm'
AXIS = 'code/modules/1713/machinery/modular_vehicles/axis.dm'
WHEELS = 'code/modules/1713/machinery/modular_vehicles/wheels.dm'
CONE = 'code/game/mob/vision_cone.dm'
CONTROLS = {
    'forced-move': ('forced move refreshes exactly once', 'human'),
    'translation': ('translation refreshes once after final geometry', 'translation'),
    'rotation': ('rotation refreshes once after final facing', 'rotation'),
    'early-refresh': ('vehicle callback observes final geometry', 'early'),
    'seat-facing': ('stationary gunner facing refreshes once', 'seat'),
}


def unique_replace(text, old, new):
    if text.count(old) != 1:
        raise AssertionError(f'Production binding changed: {old!r}')
    return text.replace(old, new, 1)


def transform_sources(control=None):
    human = (ROOT / HUMAN).read_text(encoding='utf-8')
    axis = (ROOT / AXIS).read_text(encoding='utf-8')
    wheels = (ROOT / WHEELS).read_text(encoding='utf-8')
    if control == 'forced-move':
        start = human.index('/mob/living/human/forceMove(atom/destination, var/special_event)')
        end = human.index('\n/mob/living/human/ex_act', start)
        human = human[:start] + human[end:]
    elif control in ('translation', 'rotation'):
        boundary = 'move_turfs' if control == 'translation' else 'turn_turfs'
        axis = unique_replace(axis, f'\trelease_transform_tiles({boundary})\n\trefresh_passenger_vision()\n\treturn TRUE',
                              f'\trelease_transform_tiles({boundary})\n\treturn TRUE')
    elif control == 'early-refresh':
        human = unique_replace(human, '\tif (vehicle && !QDELETED(vehicle) && vehicle.transforming_vehicle && (src in vehicle.transporting))', '\tif (FALSE)')
    elif control == 'seat-facing':
        start = wheels.index('/obj/structure/bed/chair/gunner/update_icon()')
        end = wheels.index('/obj/structure/bed/chair/gunner/post_buckle_mob()', start)
        body = unique_replace(wheels[start:end], '\t\tif (old_facing != buckled_mob.dir)\n\t\t\trefresh_seated_vision()', '')
        wheels = wheels[:start] + body + wheels[end:]
    cone = (ROOT / CONE).read_text(encoding='utf-8')
    # Only the client I/O transport is adapted. Native view(), cone(), InCone(),
    # image construction, rest/prone gates and image retirement remain verbatim.
    start = cone.index('/mob/living/human/update_vision_cone()')
    end = cone.index('mob/living/human/proc/rest_cone_act()', start)
    body = cone[start:end]
    assert body.count('if (client &&') == 1 and body.count('client.') == 8
    body = body.replace('if (client &&', 'if (cone_client &&').replace('client.', 'cone_client.')
    cone = cone[:start] + body + cone[end:]
    return {'human.dm': human, 'axis.dm': axis, 'wheels.dm': wheels, 'vision_cone.dm': cone}


def prepare(output, control=None):
    output.mkdir(parents=True, exist_ok=False)
    generated = transform_sources(control)
    world = (ROOT / 'code/world.dm').read_text(encoding='utf-8')
    start = world.index('/world/New()')
    parent = world.index('\n\t..()', start)
    world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
    world = unique_replace(world, '/world/New()', '/world/proc/unused_cone_fixture_startup()')
    world = unique_replace(world, '/datum/global_init/New()\n', '/datum/global_init/New()\n\treturn\n')
    globals_source = (ROOT / 'code/controllers/mc/globals.dm').read_text(encoding='utf-8')
    globals_source = unique_replace(globals_source, '/datum/controller/global_vars/New()\n', '/datum/controller/global_vars/New()\n\treturn\n')
    generated.update({'world.dm': world, 'globals.dm': globals_source})
    for name, value in generated.items():
        (output / name).write_text(value, encoding='utf-8', newline='\n')
    replacements = {HUMAN: output / 'human.dm', AXIS: output / 'axis.dm', WHEELS: output / 'wheels.dm', CONE: output / 'vision_cone.dm',
                    'code/world.dm': output / 'world.dm', 'code/controllers/mc/globals.dm': output / 'globals.dm'}
    dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
    dme = unique_replace(dme, '#include "interface\\skin.dmf"', '')
    dme = re.sub(r'^#include ".*\.dmm".*$', '', dme, flags=re.M)
    dme = unique_replace(dme, '#define FILE_DIR .', f'#define FILE_DIR "{ROOT.as_posix()}"')
    def include(match):
        path = match[1].replace('\\', '/')
        return f'#include "{replacements.get(path, ROOT / path).resolve(strict=True).as_posix()}"'
    dme = re.sub(r'^#include "([^"]+)"', include, dme, flags=re.M)
    dme += f'\n#include "{(ROOT / "tests/cone_refresh/probe.dm").as_posix()}"\n'
    (output / 'probe.dme').write_text(dme, encoding='utf-8', newline='\n')
    paths = ['civ13.dme', HUMAN, AXIS, WHEELS, CONE, 'code/world.dm', 'code/controllers/mc/globals.dm',
             'code/game/atoms_movable.dm', 'code/modules/persistence/functions.dm',
             'code/modules/persistence/saving.dm', 'code/modules/persistence/loading.dm',
             'tests/cone_refresh/probe.dm', 'tests/cone_refresh/prepare.py', 'tests/cone_refresh/run.py', 'tests/cone_refresh/evidence.py']
    receipt = {'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
               'prepared_only': True, 'native_executed': False, 'control': control,
               'expected_failure': CONTROLS[control][0] if control else None,
               'source_root': ROOT.as_posix(), 'adapter': 'client I/O datum only; real view/cone/forceMove/axis/seat/codec bodies',
               'ui_rendering_verified': False, 'interface': 'DMF and maps omitted; no client is connected',
               'source_sha256': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths},
               'generated_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in output.iterdir()}}
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    return receipt


if __name__ == '__main__':
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--control', choices=CONTROLS)
    args = parser.parse_args()
    prepare(args.output.resolve(), args.control)
    print('PASS: prepared only; no compiler/runtime invoked')
