"""Offline production-path rain barrel regression. Never opens a client or server port."""
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
CORE = 'code/modules/1713/rain_barrel.dm'
CONTROLS = {
    'exposure': ('A.location != AREA_OUTSIDE', 'FALSE', 'FAIL: indoors rejected'),
    'timing': ('var/elapsed = min(2, max(0, configured_seconds), max(0, (world.time - last_collection_tick) / 10))', 'var/elapsed = 600', 'FAIL: delayed tick cannot replay backlog'),
    'persistence': ('list("collection_seconds", "collection_mode", "last_collection_tick")', 'list("collection_mode", "last_collection_tick")', 'FAIL: runtime field excluded: collection_seconds'),
    'lid': ('if (!collects_rain || QDELETED(src) || !is_open_container())\n\t\treset_rain_collection()', 'if (!collects_rain || QDELETED(src))\n\t\treset_rain_collection()', 'FAIL: closed barrel leaves the object loop'),
    'legacy': ('reagents.trans_to_holder(B.reagents, reagents.total_volume)', 'reagents.clear_reagents()', 'FAIL: legacy collector keeps its water'),
}


def source_for(control):
    source = (ROOT / CORE).read_text(encoding='utf-8')
    if control:
        old, new, _ = CONTROLS[control]
        if source.count(old) != 1:
            raise RuntimeError('Mutation target missing or ambiguous')
        source = source.replace(old, new, 1)
    return source


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
    pin = json.loads((ROOT / 'tools/byond/version.json').read_text(encoding='utf-8'))['version']
    binary = args.byond_bin.resolve()
    compiler = binary / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = binary / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    prefix = '.rain_probe_' + uuid.uuid4().hex
    generated = [ROOT / (prefix + suffix) for suffix in
                 ('.dme', '_world.dm', '_globals.dm', '_rain.dm', '.dmb', '.rsc')]
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    paths = [CORE, 'code/modules/reagents/reagent_containers/glass.dm',
             'code/modules/persistence/saving.dm',
             'code/modules/persistence/loading.dm', 'code/modules/persistence/functions.dm',
             'config/crafting/material_recipes_global.txt',
             'tests/rain_barrel/probe.dm', 'tests/rain_barrel/run.py']
    metadata = {'head_sha': commit, 'control': args.negative_control, 'byond_pin': pin,
                'source_sha256': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}}
    (args.output / 'metadata.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
    (args.output / 'tested.patch').write_bytes(subprocess.check_output(['git', 'diff', 'HEAD'], cwd=ROOT))
    try:
        world = (ROOT / 'code/world.dm').read_text(encoding='utf-8')
        start = world.index('/world/New()')
        parent = world.index('\n\t..()', start)
        world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
        world = world.replace('/world/New()', '/world/proc/unused_rain_startup()', 1)
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
        include = '#include "code\\modules\\1713\\rain_barrel.dm"'
        if source.count(include) != 1:
            raise RuntimeError('Rain barrel include marker changed')
        source = source.replace(include, '#include "' + generated[3].name + '"')
        source = re.sub(r'^#include ".*\.dmm".*$', '', source, flags=re.M)
        generated[0].write_text(source + '\n#include "tests/rain_barrel/probe.dm"\n', encoding='utf-8')
        build = subprocess.run([str(compiler), '-max_errors', '0', str(generated[0])],
                               cwd=ROOT, capture_output=True, text=True, timeout=180, creationflags=flags)
        output = build.stdout + build.stderr
        (args.output / 'compile.log').write_text(output, encoding='utf-8')
        if build.returncode or pin not in output or '0 errors, 0 warnings' not in output:
            raise RuntimeError('Pinned compile failed: ' + output[-4000:])
        with tempfile.TemporaryDirectory(prefix='civ13-rain-runtime-') as temporary:
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
            expected = CONTROLS[args.negative_control][2] if args.negative_control else 'PASS: rain barrel and native disk round trips'
            if result.returncode or actual != expected or any(marker in diagnostics.lower() for marker in ('runtime error:', 'bug:', '## error:')):
                raise RuntimeError(f'Expected {expected!r}, got {actual!r}; diagnostics: {diagnostics[-2500:]}')
            print(('PASS expected mutation: ' if args.negative_control else '') + actual)
    finally:
        for path in generated:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
