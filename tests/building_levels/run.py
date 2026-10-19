"""Production-path building regressions with fixture startup.

Probes close the native port in world.New(); this is not OS network isolation.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[2]
CORE = 'code/game/objects/building_levels.dm'
CONTROLS = {
    'lighting-gravity': ('\t// Lighting renderers belong to their turf; they are not falling cargo.\n\tif (istype(A, /atom/movable/lighting_overlay) || istype(A, /atom/movable/lighting_fullbright))\n\t\treturn\n', '', 'FAIL: lighting renderer stays on upper level'),
    'removal': ('\t\tqdel(C)', '\t\treturn', 'FAIL: roof removal removes floor'),
    'foundation': ('if (building_floor_height(get_turf(A), depth, max(h + 1, required_height)) >= 0)', 'if (TRUE)', 'FAIL: strong upper pillar cannot bypass weaker foundation'),
    'persistence': ('"building_pair_id", "building_floor_z", "health"', '"building_floor_z", "health"', 'FAIL: disk restored slab links'),
    'pair': ('R.building_pair_id = id', 'R.building_pair_id = null', 'FAIL: pair resolves both faces'),
    'support': ('max(h + 1, required_height) <= tier', 'TRUE', 'FAIL: wood height limit'),
}



def source_for(control, allocation_interleave=False):
    source = (ROOT / CORE).read_text(encoding='utf-8')
    if control:
        old, new, _ = CONTROLS[control]
        if source.count(old) != 1:
            raise RuntimeError('Mutation target missing or ambiguous')
        source = source.replace(old, new, 1)
    if allocation_interleave:
        marker = '\tworld.maxz = target_z\n'
        if source.count(marker) != 1:
            raise RuntimeError('Allocation scheduling marker changed')
        # Diagnostic scheduling adapter only: allow the real deferred dirt
        # lighting constructor to run before real raw sky replacement.
        source = source.replace(marker, marker + '\tsleep(6)\n', 1)
    return source


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--negative-control', choices=CONTROLS)
    parser.add_argument('--source-check', action='store_true')
    parser.add_argument('--lighting-gravity', action='store_true',
                        help='Actual lighting startup and renderer/item/mob sky entry; no client rendering')
    parser.add_argument('--lighting-roof', action='store_true',
                        help='Actual first-roof allocation, distant ground and torch lifecycle')
    parser.add_argument('--allocation-interleave', action='store_true',
                        help='Diagnostic six-tick pause after native expansion; not unadapted timing')
    args = parser.parse_args()
    if args.lighting_gravity and args.lighting_roof:
        parser.error('Choose one focused lighting probe')
    if args.allocation_interleave and not args.lighting_roof:
        parser.error('--allocation-interleave requires --lighting-roof')
    if args.negative_control == 'lighting-gravity' and not (args.lighting_gravity or args.lighting_roof):
        parser.error('lighting-gravity control requires a focused lighting probe')
    if (args.lighting_gravity or args.lighting_roof) and args.negative_control not in (None, 'lighting-gravity'):
        parser.error('Use only lighting-gravity control with this probe')
    if args.lighting_roof and args.negative_control and not args.allocation_interleave:
        parser.error('Roof negative control requires explicit diagnostic --allocation-interleave')
    probe = ('tests/building_levels/lighting_gravity_probe.dm' if args.lighting_gravity else
             'tests/building_levels/lighting_roof_probe.dm' if args.lighting_roof else
             'tests/building_levels/probe.dm')
    if args.source_check:
        for control in (None, *CONTROLS):
            source_for(control)
            if args.lighting_roof:
                source_for(control, True)
        print('PASS: source and unique mutation targets; no compiler/runtime launched')
        return
    if not args.byond_bin or not args.output:
        parser.error('--byond-bin and --output are required for native verification')
    args.output.mkdir(parents=True, exist_ok=True)
    if any(args.output.iterdir()):
        parser.error('Preserve existing evidence; use an empty output directory')
    binary = args.byond_bin.resolve()
    compiler = binary / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = binary / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    prefix = '.building_probe_' + uuid.uuid4().hex
    generated = [ROOT / (prefix + suffix) for suffix in
                 ('.dme', '_world.dm', '_globals.dm', '_building.dm', '.dmb', '.rsc')]
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    paths = [CORE, 'civ13.dme', 'code/game/objects/roof_stuff.dm',
             'code/game/objects/covers.dm', 'code/game/objects/covers_types/cover_walltypes.dm',
             'code/game/objects/items/stacks/stack.dm', 'code/game/turfs/floor_attackby.dm',
             'code/game/turfs/flooring/flooring_premade.dm',
             'code/modules/persistence/saving.dm', 'code/modules/persistence/loading.dm',
             'code/modules/persistence/functions.dm',
             probe, 'tests/building_levels/run.py',
             'code/modules/lighting/lighting_system.dm', 'code/modules/lighting/lighting_turf.dm',
             'code/modules/lighting/lighting_overlay.dm', 'code/modules/lighting/lighting_corner.dm',
             'code/game/turfs/turf.dm', 'code/game/atoms_movable.dm']
    metadata = {'head_sha': commit, 'control': args.negative_control, 'probe': probe,
                'allocation_pause_ticks': 6 if args.allocation_interleave else 0,
                'source_sha256': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}}
    (args.output / 'metadata.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
    (args.output / 'tested.patch').write_bytes(subprocess.check_output(['git', 'diff', 'HEAD'], cwd=ROOT))
    try:
        world = (ROOT / 'code/world.dm').read_text(encoding='utf-8')
        start = world.index('/world/New()')
        parent = world.index('\n\t..()', start)
        world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
        world = world.replace('/world/New()', '/world/proc/unused_building_startup()', 1)
        marker = '/datum/global_init/New()\n'
        if world.count(marker) != 1:
            raise RuntimeError('World isolation marker changed')
        generated[1].write_text(world.replace(marker, marker + '\treturn\n', 1), encoding='utf-8')
        globals_source = (ROOT / 'code/controllers/mc/globals.dm').read_text(encoding='utf-8')
        marker = '/datum/controller/global_vars/New()\n'
        if globals_source.count(marker) != 1:
            raise RuntimeError('Controller isolation marker changed')
        generated[2].write_text(globals_source.replace(marker, marker + '\treturn\n', 1), encoding='utf-8')
        generated[3].write_text(source_for(args.negative_control, args.allocation_interleave), encoding='utf-8')
        source = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        source = source.replace('code\\world.dm', generated[1].name)
        source = source.replace('code\\controllers\\mc\\globals.dm', generated[2].name)
        include = '#include "code\\game\\objects\\building_levels.dm"'
        if include in source:
            source = source.replace(include, '#include "' + generated[3].name + '"')
        else:
            source += '\n#include "' + generated[3].name + '"\n'
        source = re.sub(r'^#include ".*\.dmm".*$', '', source, flags=re.M)
        generated[0].write_text(source + '\n#include "' + probe + '"\n', encoding='utf-8')
        build = subprocess.run([str(compiler), '-max_errors', '0', str(generated[0])],
                               cwd=ROOT, capture_output=True, text=True, timeout=180, creationflags=flags)
        output = build.stdout + build.stderr
        (args.output / 'compile.log').write_text(output, encoding='utf-8')
        if build.returncode or '516.1681' not in output or '0 errors, 0 warnings' not in output:
            raise RuntimeError('Pinned compile failed: ' + output[-4000:])
        with tempfile.TemporaryDirectory(prefix='civ13-building-runtime-') as temporary:
            work = Path(temporary)
            for path in generated[4:]:
                shutil.copy2(path, work / path.name)
            shutil.copytree(ROOT / 'config/names', work / 'config/names')
            (work / 'config/crafting').mkdir(parents=True)
            shutil.copy2(ROOT / 'config/crafting/material_recipes_global.txt', work / 'config/crafting/material_recipes_global.txt')
            result = subprocess.run([str(daemon), str(work / generated[4].name),
                                     *(['-invisible', '-close'] if os.name == 'nt' else []),
                                     '-trusted', '-log', 'runtime.log'], cwd=work,
                                    capture_output=True, text=True, timeout=45, creationflags=flags)
            diagnostics = result.stdout + result.stderr
            for filename in ('runtime.log', 'errors.txt', 'result.txt', 'fixture.json', 'fixture.jsonl'):
                path = work / filename
                if path.exists():
                    shutil.copy2(path, args.output / filename)
                    if filename in ('runtime.log', 'errors.txt'):
                        diagnostics += path.read_text(encoding='utf-8', errors='replace')
            (args.output / 'daemon.log').write_text(result.stdout + result.stderr, encoding='utf-8')
            actual = (work / 'result.txt').read_text(encoding='utf-8').strip() if (work / 'result.txt').exists() else ''
            expected = CONTROLS[args.negative_control][2] if args.negative_control else ('PASS: lighting gravity' if args.lighting_gravity else 'PASS: first roof lighting' if args.lighting_roof else 'PASS: linked building levels')
            if args.lighting_roof and args.negative_control:
                expected = 'FAIL: distant unroofed tile keeps one lighting overlay'
            if result.returncode or actual != expected or any(marker in diagnostics.lower() for marker in ('runtime error:', 'bug:', '## error:')):
                raise RuntimeError(f'Expected {expected!r}, got {actual!r}; diagnostics: {diagnostics[-2500:]}')
            print(('PASS expected mutation: ' if args.negative_control else '') + actual)
    finally:
        for path in generated:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
