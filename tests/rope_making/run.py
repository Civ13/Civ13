"""Isolated rope regression; --compile-only never launches the native runtime."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
import byond_runtime
import byond_toolchain

CORE = 'code/modules/1713/rope_making.dm'
CONTROLS = {
    'payment': ('if (!F.use(1))', 'if (FALSE)', 'FAIL: spindle payment'),
    'replay': ('B.stage = 1', 'B.stage = 0', 'FAIL: twist advances without rope'),
    # Keep the capture referenced so the deliberately false guard compiles cleanly
    # and the control reaches its causal assertion rather than unused-var warnings.
    'admission': ('admission != persistence_admission_identity', 'admission != admission', 'FAIL: completed admission cancels spindle'),
    'persistence': ('return key == "working" || ..()', 'return ..()', 'FAIL: station lock excluded'),
}



def runtime_identity(binary, archive):
    if sys.platform == 'linux':
        if archive is None:
            raise ValueError('--byond-archive is required for Linux fixture identity')
        return byond_runtime.verify_linux(binary, archive)
    # Existing Windows launch path is not archive/member verification evidence.
    return None


def check_compile(build, expected_version):
    output = build.stdout + build.stderr
    if build.returncode:
        raise RuntimeError('Fixture compiler exited nonzero: ' + output[-4000:])
    try:
        byond_toolchain.compiler_log(output, expected_version)
    except ValueError as error:
        raise RuntimeError('Fixture compiler version/result contract rejected: ' + output[-4000:]) from error


def source_for(control):
    source = (ROOT / CORE).read_text(encoding='utf-8')
    if control:
        old, new, _ = CONTROLS[control]
        if source.count(old) != {'admission': 4, 'persistence': 3}.get(control, 1):
            raise RuntimeError('Mutation target missing or ambiguous')
        source = source.replace(old, new)
    return source


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--byond-archive', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--negative-control', choices=CONTROLS)
    parser.add_argument('--source-check', action='store_true')
    parser.add_argument('--compile-only', action='store_true')
    args = parser.parse_args()
    if args.source_check:
        for control in (None, *CONTROLS):
            source_for(control)
        print('PASS: source and unique mutation targets; no compiler/runtime launched')
        return
    if not args.byond_bin or not args.output:
        parser.error('--byond-bin and --output are required for native verification')
    if sys.platform == 'linux' and args.byond_archive is None:
        parser.error('--byond-archive is required for Linux fixture identity')
    requirement = byond_toolchain.load()
    args.output.mkdir(parents=True, exist_ok=True)
    if any(args.output.iterdir()):
        parser.error('Preserve existing evidence; use an empty output directory')
    binary = args.byond_bin.absolute()  # Preserve links/traversal for identity rejection.
    compiler = binary / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = binary / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    prefix = '.rope_probe_' + uuid.uuid4().hex
    generated = [ROOT / (prefix + suffix) for suffix in
                 ('.dme', '_world.dm', '_globals.dm', '_rope.dm', '.dmb', '.rsc')]
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    paths = [CORE, 'code/modules/persistence/saving.dm',
             'code/modules/persistence/loading.dm', 'code/modules/persistence/functions.dm',
             'config/crafting/material_recipes_global.txt', 'code/modules/research_tree/research_node.dm',
             'code/modules/1713/flax_processing.dm',
             'tests/rope_making/probe.dm', 'tests/rope_making/run.py',
             'scripts/byond_runtime.py', 'scripts/byond_toolchain.py', 'tools/byond/version.json']
    metadata = {'head_sha': commit, 'control': args.negative_control,
                'expected_byond_version': requirement['version'],
                'source_sha256': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}}
    (args.output / 'metadata.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
    (args.output / 'tested.patch').write_bytes(subprocess.check_output(['git', 'diff', 'HEAD'], cwd=ROOT))
    try:
        world = (ROOT / 'code/world.dm').read_text(encoding='utf-8')
        start = world.index('/world/New()')
        parent = world.index('\n\t..()', start)
        world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
        world = world.replace('/world/New()', '/world/proc/unused_rope_startup()', 1)
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
        include = '#include "code\\modules\\1713\\rope_making.dm"'
        if include in source:
            source = source.replace(include, '#include "' + generated[3].name + '"')
        else:
            source += '\n#include "' + generated[3].name + '"\n'
        source = re.sub(r'^#include ".*\.dmm".*$', '', source, flags=re.M)
        generated[0].write_text(source + '\n#include "tests/rope_making/probe.dm"\n', encoding='utf-8')
        identity = runtime_identity(binary, args.byond_archive)
        (args.output / 'compiler-runtime.json').write_text(json.dumps(identity, indent=2), encoding='utf-8')
        build = subprocess.run([str(compiler), '-max_errors', '0', str(generated[0])],
                               cwd=ROOT, capture_output=True, text=True, timeout=180, creationflags=flags)
        output = build.stdout + build.stderr
        (args.output / 'compile.log').write_text(output, encoding='utf-8')
        check_compile(build, requirement['version'])
        if args.compile_only:
            print('PASS: isolated rope fixture compiles; runtime not launched')
            return
        with tempfile.TemporaryDirectory(prefix='civ13-rope-runtime-') as temporary:
            work = Path(temporary)
            for path in generated[4:]:
                shutil.copy2(path, work / path.name)
            shutil.copytree(ROOT / 'config/names', work / 'config/names')
            (work / 'config/crafting').mkdir(parents=True)
            shutil.copy2(ROOT / 'config/crafting/material_recipes_global.txt', work / 'config/crafting/material_recipes_global.txt')
            identity = runtime_identity(binary, args.byond_archive)
            (args.output / 'daemon-runtime.json').write_text(json.dumps(identity, indent=2), encoding='utf-8')
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
            expected = CONTROLS[args.negative_control][2] if args.negative_control else 'PASS: rope making and native disk round trips'
            if result.returncode or actual != expected or any(marker in diagnostics.lower() for marker in ('runtime error:', 'bug:', '## error:')):
                raise RuntimeError(f'Expected {expected!r}, got {actual!r}; diagnostics: {diagnostics[-2500:]}')
            print(('PASS expected mutation: ' if args.negative_control else '') + actual)
    finally:
        for path in generated:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
