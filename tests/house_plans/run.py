"""House plans judged as drawn and then really built (tests/house_plans/probe.dm).

Compiles the game without its maps around the probe's small world and runs it
once. The probe closes the native port in world.New(); this is not OS network
isolation.
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
PROBE = 'tests/house_plans/probe.dm'
EXPECTED = 'PASS: house plans'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True, help='an empty directory for the logs')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    if any(args.output.iterdir()):
        parser.error('Preserve existing evidence; use an empty output directory')
    binary = args.byond_bin.resolve()
    compiler = binary / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = binary / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    prefix = '.house_probe_' + uuid.uuid4().hex
    generated = [ROOT / (prefix + suffix) for suffix in ('.dme', '_world.dm', '_globals.dm', '.dmb', '.rsc')]
    try:
        # The game's own startup stays out: the probe's world.New() runs alone.
        world = (ROOT / 'code/world.dm').read_text(encoding='utf-8')
        start = world.index('/world/New()')
        parent = world.index('\n\t..()', start)
        world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
        world = world.replace('/world/New()', '/world/proc/unused_house_startup()', 1)
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
        for old, new in (('code\\world.dm', generated[1].name), ('code\\controllers\\mc\\globals.dm', generated[2].name)):
            if source.count('#include "' + old + '"') != 1:
                raise RuntimeError('Include changed: ' + old)
            source = source.replace(old, new)
        source = re.sub(r'^#include ".*\.dmm".*$', '', source, flags=re.M)
        generated[0].write_text(source + '\n#include "' + PROBE + '"\n', encoding='utf-8')
        build = subprocess.run([str(compiler), '-max_errors', '0', str(generated[0])],
                               cwd=ROOT, capture_output=True, text=True, timeout=300, creationflags=flags)
        output = build.stdout + build.stderr
        (args.output / 'compile.log').write_text(output, encoding='utf-8')
        if build.returncode or 'DM compiler version ' + PINNED not in output or '0 errors, 0 warnings' not in output:
            raise RuntimeError('Pinned compile failed: ' + output[-4000:])
        with tempfile.TemporaryDirectory(prefix='civ13-house-runtime-') as temporary:
            work = Path(temporary)
            for path in generated[3:5]:
                shutil.copy2(path, work / path.name)
            shutil.copytree(ROOT / 'config/names', work / 'config/names')
            (work / 'config/crafting').mkdir(parents=True)
            shutil.copy2(ROOT / 'config/crafting/material_recipes_global.txt', work / 'config/crafting/material_recipes_global.txt')
            result = subprocess.run([str(daemon), str(work / generated[3].name),
                                     *(['-invisible', '-close'] if os.name == 'nt' else []),
                                     '-trusted', '-log', 'runtime.log'], cwd=work,
                                    capture_output=True, text=True, timeout=180, creationflags=flags)
            diagnostics = result.stdout + result.stderr
            for filename in ('runtime.log', 'result.txt', 'designer.json'):
                path = work / filename
                if path.exists():
                    shutil.copy2(path, args.output / filename)
                    if filename == 'runtime.log':
                        diagnostics += path.read_text(encoding='utf-8', errors='replace')
            (args.output / 'daemon.log').write_text(result.stdout + result.stderr, encoding='utf-8')
            actual = (work / 'result.txt').read_text(encoding='utf-8').strip() if (work / 'result.txt').exists() else ''
            if result.returncode or actual != EXPECTED or any(mark in diagnostics.lower() for mark in ('runtime error:', 'bug:', '## error:')):
                raise RuntimeError(f'Expected {EXPECTED!r}, got {actual!r}; diagnostics: {diagnostics[-3000:]}')
            checks = re.findall(r'HOUSE CHECKS: (\d+)', diagnostics)
            print(actual + (f' ({checks[-1]} checks)' if checks else ''))
    finally:
        for path in generated:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
