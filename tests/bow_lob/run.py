"""Compile production projectile code into a 16x6 offline hill world and check lobbed arrows."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PREFIX = '.bow_lob_ci'
CONTROLS = {
    # Each control removes one part of the lob rules in a generated copy and must fail.
    'arc': ('code/modules/projectiles/projectile.dm',
            '\tif (lobbed)\n\t\treturn lob_enter(T)', '\tif (FALSE)\n\t\treturn lob_enter(T)', 'Lob did not clear the wall'),
    'ridge': ('code/modules/projectiles/projectile_lob.dm',
              'if (lob_heights && lob_ground(T) >', 'if (FALSE && lob_ground(T) >', 'Ridge did not stop the lob'),
    'roof': ('code/modules/projectiles/projectile_lob.dm',
             '\tif (los_turf_roofed(T))\n', '\tif (FALSE)\n', 'Lob hit someone under a roof'),
    'scatter': ('code/modules/projectiles/projectile_lob.dm',
                'return 0.25 + distance * 0.08', 'return 0.25 + distance * 0', 'Scatter did not grow'),
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--negative-control', choices=sorted(CONTROLS))
    args = parser.parse_args()
    pin = json.loads((ROOT / 'tools/byond/version.json').read_text(encoding='utf-8'))['version']
    binary = args.byond_bin.resolve()
    compiler = binary / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = binary / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    generated = [ROOT / (PREFIX + suffix) for suffix in ('.dme', '_world.dm', '.dmb', '.rsc', '_mutated.dm', '.int', '.lk')]
    if any(path.exists() for path in generated):
        raise RuntimeError('Preserve existing probe files')
    logs = Path(tempfile.mkdtemp(prefix='bow-lob-'))
    print(f'Evidence: {logs}', flush=True)
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    try:
        world = (ROOT / 'code/world.dm').read_text(encoding='utf-8')
        start = world.index('/world/New()')
        parent = world.index('\n\t..()', start)
        world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
        world = world.replace('/world/New()', '/world/proc/unused_bow_lob_startup()', 1)
        generated[1].write_text(world, encoding='utf-8')
        source = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        source = source.replace('code\\world.dm', PREFIX + '_world.dm')
        expected = None
        if args.negative_control:
            path, old, new, expected = CONTROLS[args.negative_control]
            original = (ROOT / path).read_text(encoding='utf-8')
            if old not in original:
                raise RuntimeError('Negative control anchor missing')
            generated[4].write_text(original.replace(old, new, 1), encoding='utf-8')
            source = source.replace(path.replace('/', '\\'), generated[4].name)
        source = re.sub(r'^#include ".*\.dmm".*$', '', source, flags=re.M)
        generated[0].write_text(source + '\n#include "tests\\bow_lob\\probe.dm"\n', encoding='utf-8')
        build = subprocess.run([str(compiler), '-max_errors', '0', str(generated[0])], cwd=ROOT,
                               capture_output=True, text=True, timeout=300, creationflags=flags)
        output = build.stdout + build.stderr
        (logs / 'compile.log').write_text(output, encoding='utf-8')
        if build.returncode or '0 errors, 0 warnings' not in output or pin not in output:
            print(output, flush=True)
            raise RuntimeError('Pinned compilation failed')
        shutil.copy2(generated[2], logs / generated[2].name)
        shutil.copy2(generated[3], logs / generated[3].name)
        shutil.copytree(ROOT / 'config/names', logs / 'config/names')
        (logs / 'config/config.txt').write_text('# Offline fixture\n', encoding='utf-8')
        runtime = subprocess.run([str(daemon), str(logs / generated[2].name),
                                  *(['-invisible', '-close'] if os.name == 'nt' else []),
                                  '-trusted', '-log', 'runtime.log'],
                                 cwd=logs, capture_output=True, text=True, timeout=120, creationflags=flags)
        result = (logs / 'result.txt').read_text(encoding='utf-8').strip()
        print(result, flush=True)
        log = (logs / 'runtime.log').read_text(encoding='utf-8', errors='replace')
        if expected:
            if not result.startswith('FAIL:') or expected not in result:
                print(log, flush=True)
                raise RuntimeError(f'Negative control {args.negative_control} was not detected')
            print(f'PASS: {args.negative_control} negative control detected', flush=True)
        elif runtime.returncode or not result.startswith('PASS:') or 'runtime error:' in log.lower():
            print(log, flush=True)
            raise RuntimeError('Bow lob fixture failed')
    finally:
        for path in generated:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
