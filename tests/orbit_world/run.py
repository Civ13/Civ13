"""Orbit world plane registry fixture on the full game source.

Builds civ13.dme without maps or startup, adds tests/orbit_world/probe.dm and
runs it headless. The probe closes the native port in world.New().
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[2]
PINNED = json.loads((ROOT / 'tools/byond/version.json').read_text(encoding='utf-8'))['version']
PROBE = 'tests/orbit_world/probe.dm'


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    if any(args.output.iterdir()):
        parser.error('Use an empty output directory')
    binary = args.byond_bin.resolve()
    compiler = binary / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = binary / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    prefix = '.orbit_probe_' + uuid.uuid4().hex
    generated = [ROOT / (prefix + suffix) for suffix in ('.dme', '_world.dm', '_globals.dm', '.dmb', '.rsc')]
    try:
        world = (ROOT / 'code/world.dm').read_text(encoding='utf-8')
        start = world.index('/world/New()')
        parent = world.index('\n\t..()', start)
        world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
        world = world.replace('/world/New()', '/world/proc/unused_orbit_startup()', 1)
        marker = '/datum/global_init/New()\n'
        if world.count(marker) != 1:
            raise RuntimeError('World isolation marker changed')
        generated[1].write_text(world.replace(marker, marker + '\treturn\n', 1), encoding='utf-8')
        globals_source = (ROOT / 'code/controllers/mc/globals.dm').read_text(encoding='utf-8')
        marker = '/datum/controller/global_vars/New()\n'
        if globals_source.count(marker) != 1:
            raise RuntimeError('Controller isolation marker changed')
        generated[2].write_text(globals_source.replace(marker, marker + '\treturn\n', 1), encoding='utf-8')
        source = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        source = source.replace('code\\world.dm', generated[1].name)
        source = source.replace('code\\controllers\\mc\\globals.dm', generated[2].name)
        source = re.sub(r'^#include ".*\.dmm".*$', '', source, flags=re.M)
        generated[0].write_text(source + '\n#include "' + PROBE + '"\n', encoding='utf-8')
        build = subprocess.run([str(compiler), '-max_errors', '0', str(generated[0])],
                               cwd=ROOT, capture_output=True, text=True, timeout=300, creationflags=flags)
        output = build.stdout + build.stderr
        (args.output / 'compile.log').write_text(output, encoding='utf-8')
        if build.returncode or 'DM compiler version ' + PINNED not in output or '0 errors, 0 warnings' not in output:
            raise RuntimeError('Pinned compile failed: ' + output[-4000:])
        with tempfile.TemporaryDirectory(prefix='civ13-orbit-runtime-') as temporary:
            work = Path(temporary)
            for path in generated[3:]:
                shutil.copy2(path, work / path.name)
            result = subprocess.run([str(daemon), str(work / generated[3].name),
                                     *(['-invisible', '-close'] if os.name == 'nt' else []),
                                     '-trusted', '-log', 'runtime.log'], cwd=work,
                                    capture_output=True, text=True, timeout=60, creationflags=flags)
            diagnostics = result.stdout + result.stderr
            for filename in ('runtime.log', 'result.txt'):
                path = work / filename
                if path.exists():
                    shutil.copy2(path, args.output / filename)
                    if filename == 'runtime.log':
                        diagnostics += path.read_text(encoding='utf-8', errors='replace')
            actual = (work / 'result.txt').read_text(encoding='utf-8').strip() if (work / 'result.txt').exists() else ''
            if result.returncode or not actual.startswith('PASS') or 'runtime error:' in diagnostics.lower():
                raise RuntimeError(f'Expected PASS, got {actual!r}; diagnostics: {diagnostics[-3000:]}')
            print(actual)
    finally:
        for path in generated:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
