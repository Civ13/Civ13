"""Bounded production weather probe, without normal world startup."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--baseline', action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    (root / 'data').mkdir(exist_ok=True)
    logs = Path(tempfile.mkdtemp(prefix='weather-', dir=root / 'data'))
    prefix = '.weather_probe'
    generated = [root / (prefix + suffix) for suffix in ('.dme', '_world.dm', '.dmb', '.rsc', '_globals.dm')]
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
        globals_source = globals_source.replace('gvars_datum_in_built_vars = exclude_these.vars + list(',
            'var/list/concrete_keys = list()\n\tfor(var/key in exclude_these.vars)\n\t\tconcrete_keys += key\n\tgvars_datum_in_built_vars = concrete_keys + list(')
        generated[4].write_text(globals_source, encoding='utf-8')
        source = source.replace('code\\controllers\\mc\\globals.dm', prefix + '_globals.dm')
        source += '\n#include "tests/weather/probe.dm"\n'
        if args.baseline:
            source = '#define WEATHER_BASELINE\n' + source
        generated[0].write_text(source, encoding='utf-8')
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
        result = subprocess.run([str(daemon), str(logs / generated[2].name),
                                 *(['-invisible', '-close'] if os.name == 'nt' else []),
                                 '-safe', '-log', 'runtime.log'], cwd=logs,
                                capture_output=True, text=True, timeout=60, creationflags=flags)
        runtime = (logs / 'runtime.log').read_text(encoding='utf-8', errors='replace')
        print(runtime, flush=True)
        if (logs / 'weather.csv').exists():
            print((logs / 'weather.csv').read_text(), flush=True)
        if result.returncode or 'FAIL' in runtime or 'runtime error:' in runtime or 'WEATHER PASS' not in runtime:
            raise RuntimeError('Weather probe failed')
    finally:
        for path in generated:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
