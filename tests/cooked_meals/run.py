"""Offline production-path meal regression. Never opens a client or server port."""
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
CORE = 'code/game/objects/structures/kitchen/cooked_meals.dm'
CONTROLS = {
 'human': ('istype(H) && H.stat == CONSCIOUS', 'H && H.stat == CONSCIOUS', 'FAIL: nonhuman readiness rejected without lock'),
 'payment': ('F.reagents.trans_to_holder(reagents, F.reagents.total_volume)', 'reagents.add_reagent("nutriment", 50)', 'FAIL: paid nutrients conserved'),
 'portions': ('reagents.total_volume / meal_portions', 'reagents.total_volume', 'FAIL: equal paid portions'),
 'reward': ('mood = floor_mood', 'mood += floor_mood', 'FAIL: substantial actual ingestion earns seasoned reward'),
 'persistence': ('key == "meal_cooking" || ..()', '..()', 'FAIL: cooking lock excluded'),
 'heat': ('&& meal_heat() && meal_recipe()', '&& meal_recipe()', 'FAIL: unlit fire cannot cook'),
}



def source_for(control):
    source = (ROOT / CORE).read_text(encoding='utf-8')
    if control:
        old, new, _ = CONTROLS[control]
        if source.count(old) != 1:
            raise RuntimeError('Mutation target missing or ambiguous')
        source = source.replace(old, new, 1)
    return source


DIAGNOSTIC_MARKERS = ('runtime error:', 'runtime in ', 'uncaught exception:',
                      'bug:', '## error:', 'bad ref', 'bad loc')


def verify_result(returncode, actual, expected, diagnostics):
    if returncode or actual != expected or any(marker in diagnostics.lower() for marker in DIAGNOSTIC_MARKERS):
        raise RuntimeError(f'Expected {expected!r}, got {actual!r}; diagnostics: {diagnostics[-2500:]}')


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--negative-control', choices=CONTROLS)
    parser.add_argument('--source-check', action='store_true')
    args = parser.parse_args()
    if args.source_check:
        for control in (None, *CONTROLS):
            source_for(control)
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
    prefix = '.meal_probe_' + uuid.uuid4().hex
    generated = [ROOT / (prefix + suffix) for suffix in
                 ('.dme', '_world.dm', '_globals.dm', '_meal.dm', '.dmb', '.rsc')]
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    paths = [CORE, 'code/modules/persistence/saving.dm',
             'code/modules/persistence/loading.dm', 'code/modules/persistence/functions.dm',
             'code/game/objects/structures/kitchen/pot.dm', 'code/modules/reagents/reagent_containers/food/snacks.dm', 'code/game/mob/living/carbon/human/human_life.dm',
             'tests/cooked_meals/probe.dm', 'tests/cooked_meals/run.py']
    metadata = {'head_sha': commit, 'control': args.negative_control,
                'source_sha256': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}}
    (args.output / 'metadata.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
    (args.output / 'tested.patch').write_bytes(subprocess.check_output(['git', 'diff', 'HEAD'], cwd=ROOT))
    try:
        world = (ROOT / 'code/world.dm').read_text(encoding='utf-8')
        start = world.index('/world/New()')
        parent = world.index('\n\t..()', start)
        world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
        world = world.replace('/world/New()', '/world/proc/unused_meal_startup()', 1)
        marker = '/datum/global_init/New()\n'
        if world.count(marker) != 1:
            raise RuntimeError('World isolation marker changed')
        generated[1].write_text(world.replace(marker, marker + '\treturn\n', 1), encoding='utf-8')
        globals_source = (ROOT / 'code/controllers/mc/globals.dm').read_text(encoding='utf-8')
        marker = '/datum/controller/global_vars/New()\n'
        if globals_source.count(marker) != 1:
            raise RuntimeError('Controller isolation marker changed')
        generated[2].write_text(globals_source.replace(marker, marker + '\treturn\n', 1), encoding='utf-8')
        generated[3].write_text(source_for(args.negative_control), encoding='utf-8')
        source = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        source = source.replace('code\\world.dm', generated[1].name)
        source = source.replace('code\\controllers\\mc\\globals.dm', generated[2].name)
        include = '#include "code\\game\\objects\\structures\\kitchen\\cooked_meals.dm"'
        if include in source:
            source = source.replace(include, '#include "' + generated[3].name + '"')
        else:
            source += '\n#include "' + generated[3].name + '"\n'
        source = re.sub(r'^#include ".*\.dmm".*$', '', source, flags=re.M)
        generated[0].write_text(source + '\n#include "tests/cooked_meals/probe.dm"\n', encoding='utf-8')
        build = subprocess.run([str(compiler), '-max_errors', '0', str(generated[0])],
                               cwd=ROOT, capture_output=True, text=True, timeout=180, creationflags=flags)
        output = build.stdout + build.stderr
        (args.output / 'compile.log').write_text(output, encoding='utf-8')
        if build.returncode or '516.1681' not in output or '0 errors, 0 warnings' not in output:
            raise RuntimeError('Pinned compile failed: ' + output[-4000:])
        with tempfile.TemporaryDirectory(prefix='civ13-meal-runtime-') as temporary:
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
            for filename in ('runtime.log', 'errors.txt', 'result.txt', 'fixture.json'):
                path = work / filename
                if path.exists():
                    shutil.copy2(path, args.output / filename)
                    if filename in ('runtime.log', 'errors.txt'):
                        diagnostics += path.read_text(encoding='utf-8', errors='replace')
            (args.output / 'daemon.log').write_text(result.stdout + result.stderr, encoding='utf-8')
            actual = (work / 'result.txt').read_text(encoding='utf-8').strip() if (work / 'result.txt').exists() else ''
            expected = CONTROLS[args.negative_control][2] if args.negative_control else 'PASS: cooking and native disk round trips'
            verify_result(result.returncode, actual, expected, diagnostics)
            print(('PASS expected mutation: ' if args.negative_control else '') + actual)
    finally:
        for path in generated:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
