"""Prepare immutable production fixtures only. Never discover/launch BYOND."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

BASELINE = 'cc03b199128f8afed58713912c551ad7556e6bc4'
FILES = (
    'code/modules/lighting/lighting_turf.dm',
    'code/modules/lighting/lighting_system.dm',
    'code/modules/lighting/lighting_corner.dm',
    'code/modules/lighting/lighting_overlay.dm',
    'code/game/turfs/turf_changing.dm',
    'code/modules/persistence/functions.dm',
    'code/modules/persistence/loading.dm',
)
CONTROLS = {
    'compatibility': (FILES[1], '!T.lighting_overlay && !T.omit_reserved_lighting_overlay()', '!T.lighting_overlay'),
    'virtual-master': (FILES[2], 'T.lighting_overlay || T.omit_reserved_lighting_overlay()', 'T.lighting_overlay'),
    'runtime': (FILES[0], '\tif (omit_reserved_lighting_overlay())\n\t\treturn\n', ''),
    'import': (FILES[6], '\t\t\told_turf.activate_reserved_lighting()\n', '\t\t\t;\n'),
    'halo': (FILES[0], '\t\tif (!T.lighting_reserved)\n\t\t\treturn FALSE\n', ''),
}


def prepare(repo, output, control=None):
    output.mkdir(parents=True, exist_ok=False)
    hashes = {}
    for rel in FILES:
        text = (repo / rel).read_text(encoding='utf-8')
        if control and CONTROLS[control][0] == rel:
            _, before, after = CONTROLS[control]
            assert text.count(before) == 1, (control, 'mutation anchor drift')
            text = text.replace(before, after, 1)
        dest = output / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(text, encoding='utf-8')
        hashes[rel] = hashlib.sha256(dest.read_bytes()).hexdigest()
    source = (repo / 'civ13.dme').read_text(encoding='utf-8')
    lines = []
    for line in source.splitlines():
        if line.startswith('#include "maps\\'):
            continue
        if line.startswith('#include "'):
            rel = line.split('"')[1].replace('\\', '/')
            target = output / rel if rel in FILES else repo / rel
            line = '#include "' + target.as_posix() + '"'
        lines.append(line)
    # Disable only normal world startup, as in existing production lighting probe.
    world = (repo / 'code/world.dm').read_text(encoding='utf-8')
    start = world.index('/world/New()')
    parent = world.index('\n\t..()', start)
    world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
    world = world.replace('/world/New()', '/world/proc/unused_reserved_probe_startup()', 1)
    (output / 'world.dm').write_text(world, encoding='utf-8')
    lines = [x.replace((repo / 'code/world.dm').as_posix(), (output / 'world.dm').as_posix()) for x in lines]
    # No maps/assets copied; source references retain existing checkout paths.
    lines.append('#include "' + (repo / 'tests/reserved_lighting/probe.dm').as_posix() + '"')
    (output / 'probe.dme').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    receipt = dict(head=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip(),
                   baseline=BASELINE, control=control, files=hashes,
                   dirty_diff_sha256=hashlib.sha256(subprocess.check_output(['git', 'diff', 'HEAD'], cwd=repo)).hexdigest(),
                   probe_sha256=hashlib.sha256((repo/'tests/reserved_lighting/probe.dm').read_bytes()).hexdigest(),
                   world_adapter_sha256=hashlib.sha256((output/'world.dm').read_bytes()).hexdigest(),
                   verification='SOURCE_PREPARATION_ONLY; compiler/runtime/functional parity UNRUN')
    (output / 'manifest.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    return receipt


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--control', choices=CONTROLS)
    args = parser.parse_args()
    print(json.dumps(prepare(Path(__file__).resolve().parents[2], args.output.resolve(), args.control)))
