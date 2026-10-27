"""Bounded production weather probe, without normal world startup."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import uuid


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--baseline', action='store_true')
    parser.add_argument('--negative-control', action='store_true')
    args = parser.parse_args()
    if args.baseline and args.negative_control:
        parser.error('Baseline and negative control are separate modes')
    root = Path(__file__).resolve().parents[2]
    (root / 'data').mkdir(exist_ok=True)
    logs = Path(tempfile.mkdtemp(prefix='weather-', dir=root / 'data'))
    prefix = '.weather_' + uuid.uuid4().hex
    generated = [root / (prefix + suffix) for suffix in ('.dme', '_world.dm', '.dmb', '.rsc', '_globals.dm', '_life.dm', '_species.dm', '_clothing.dm')]
    if any(path.exists() for path in generated):
        raise RuntimeError('Existing probe files must be preserved')
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    print(f'Logs: {logs}', flush=True)
    try:
        world = (root / 'code/world.dm').read_text(encoding='utf-8')
        start = world.index('/world/New()')
        parent = world.index('\n\t..()', start)
        world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
        generated[1].write_text(world.replace('/world/New()', '/world/proc/unused_weather_startup()', 1), encoding='utf-8')
        source = (root / 'civ13.dme').read_text(encoding='utf-8')
        source = source.replace('code\\world.dm', prefix + '_world.dm')
        globals_source = (root / 'code/controllers/mc/globals.dm').read_text(encoding='utf-8')
        target = 'gvars_datum_in_built_vars = exclude_these.vars + list('
        if globals_source.count(target) not in (0, 1):
            raise RuntimeError('Global initialization adapter target changed')
        if target not in globals_source and 'for(var/variable_name in exclude_these.vars)' not in globals_source:
            raise RuntimeError('Fixed global name snapshot anchor changed')
        globals_source = globals_source.replace(target,
            'gvars_datum_in_built_vars = list()\n\tfor(var/key in exclude_these.vars)\n\t\tgvars_datum_in_built_vars += key\n\tgvars_datum_in_built_vars += list(')
        generated[4].write_text(globals_source, encoding='utf-8')
        source = source.replace('code\\controllers\\mc\\globals.dm', prefix + '_globals.dm')
        if args.baseline:
            for index, relative in ((5, 'code/game/mob/living/carbon/human/human_life.dm'),
                                    (6, 'code/game/mob/living/carbon/human/species/species.dm'),
                                    (7, 'code/game/objects/items/clothing/clothing.dm')):
                baseline = subprocess.check_output(['git', 'show', 'e4967a4e0:' + relative], cwd=root, text=True)
                generated[index].write_text(baseline, encoding='utf-8')
                source = source.replace(relative.replace('/', '\\'), generated[index].name)
        elif args.negative_control:
            life = (root / 'code/game/mob/living/carbon/human/human_life.dm').read_text(encoding='utf-8')
            target = '/ 240) * (1 + cold_wetness)'
            if life.count(target) != 1:
                raise RuntimeError('Cold loss mutation target changed')
            generated[5].write_text(life.replace(target, '/ 3) * (1 + cold_wetness)'), encoding='utf-8')
            source = source.replace('code\\game\\mob\\living\\carbon\\human\\human_life.dm', generated[5].name)
        source += '\n#include "tests/weather/probe.dm"\n'
        if args.baseline:
            source = '#define WEATHER_BASELINE\n' + source
        generated[0].write_text(source, encoding='utf-8')
        commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
        (logs / 'tested.patch').write_text(subprocess.check_output(['git', 'diff'], cwd=root, text=True), encoding='utf-8')
        compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
        daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
        build = subprocess.run([str(compiler), '-max_errors', '0', str(generated[0])], cwd=root,
                               capture_output=True, text=True, timeout=180, creationflags=flags)
        output = build.stdout + build.stderr
        (logs / 'compile.log').write_text(output, encoding='utf-8')
        print(output, flush=True)
        if build.returncode or '0 errors, 0 warnings' not in output or '516.1681' not in output:
            raise RuntimeError('Pinned probe compilation failed')
        for path in generated[2:4]:
            shutil.copy2(path, logs / path.name)
        shutil.copytree(root / 'config', logs / 'config')
        result = subprocess.run([str(daemon), str(logs / generated[2].name),
                                 *(['-invisible', '-close'] if os.name == 'nt' else []),
                                 '-trusted', '-params', f'tested_commit={commit}', '-log', 'runtime.log'], cwd=logs,
                                capture_output=True, text=True, timeout=60, creationflags=flags)
        runtime = (logs / 'runtime.log').read_text(encoding='utf-8', errors='replace')
        print(f'Daemon exit={result.returncode}; stdout={result.stdout}; stderr={result.stderr}', flush=True)
        print(runtime, flush=True)
        if (logs / 'weather.csv').exists():
            print((logs / 'weather.csv').read_text(), flush=True)
        completion = (logs / 'weather-result.txt').read_text()
        expected = 'WEATHER FAIL: Ten-minute cold harm' if args.negative_control else 'WEATHER PASS'
        diagnostics = runtime + result.stdout + result.stderr
        if result.returncode or 'BUG:' in diagnostics or 'runtime:' in diagnostics or 'Runtime error:' in diagnostics or not completion.startswith(expected):
            raise RuntimeError('Weather probe failed')
    finally:
        for path in generated:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
