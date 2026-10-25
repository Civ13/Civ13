"""Prepare by default. Native execution requires --native and maintainer approval."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from native_fixture import Session, no_port_args, read_bounded, run_native

CONTROLS = {
    'clock': ('code/game/objects/farming.dm',
              'return key == "last_growth_tick" || ..()', 'return ..()',
              'FAIL: runtime clock is absent on disk'),
    'duration': ('code/game/objects/farming.dm',
                 '/obj/structure/farming/plant/tree/after_load()\n\t..()\n',
                 '/obj/structure/farming/plant/tree/after_load()\n\t..()\n\tgrowth_time_left = 600\n',
                 'FAIL: disk round trip preserves scalar growth state'),
    'payment': ('code/game/turfs/floor_attackby.dm',
                '\t\t\t\tC.amount -= 1', '\t\t\t\tC.amount -= 0',
                'FAIL: planting creates seedling and spends exactly one seed'),
}


def prepare(prefix, control=None):
    generated = {}
    for original, suffix, marker in (
        ('code/world.dm', '_world.dm', '/datum/global_init/New()\n'),
        ('code/controllers/mc/globals.dm', '_globals.dm', '/datum/controller/global_vars/New()\n')):
        source = (ROOT / original).read_text(encoding='utf-8')
        if original == 'code/world.dm':
            start = source.index('/world/New()')
            parent = source.index('\n\t..()', start)
            source = source[:parent] + source[parent:].replace('\n\t..()', '', 1)
            source = source.replace('/world/New()', '/world/proc/unused_tree_startup()', 1)
        if source.count(marker) != 1:
            raise RuntimeError('Startup isolation marker drift: ' + original)
        # Close at the earliest production global initializer, before the large
        # remaining global graph is constructed. world/New closes again before
        # assertions. The unchanged supervisor still rejects any sampled socket.
        early_close = '\tworld.OpenPort("none")\n' if original == 'code/world.dm' else ''
        generated[suffix] = source.replace(marker, marker + early_close + '\treturn\n', 1)
    source = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
    for original, suffix in (('code\\world.dm', '_world.dm'),
                             ('code\\controllers\\mc\\globals.dm', '_globals.dm')):
        if source.count(original) != 1:
            raise RuntimeError('Include marker drift: ' + original)
        source = source.replace(original, prefix + suffix)
    source = re.sub(r'^#include ".*\.dmm".*$', '', source, flags=re.M)
    if control:
        relative, old, new, _ = CONTROLS[control]
        production = (ROOT / relative).read_text(encoding='utf-8')
        if production.count(old) != 1:
            raise RuntimeError('Mutation anchor missing or ambiguous: ' + control)
        generated['_control.dm'] = production.replace(old, new, 1)
        original = relative.replace('/', '\\')
        if source.count(original) != 1:
            raise RuntimeError('Mutation include anchor drift')
        source = source.replace(original, prefix + '_control.dm')
    generated['.dme'] = source + '\n#include "tests/tree_planting/probe.dm"\n'
    return generated


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--native', action='store_true')
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--negative-control', choices=CONTROLS)
    parser.add_argument('--compile-only', action='store_true',
                        help='Use the contained compiler but launch no game runtime')
    args = parser.parse_args()
    if args.native and not args.byond_bin:
        parser.error('--native requires --byond-bin')
    if args.compile_only and (not args.native or args.negative_control):
        parser.error('--compile-only requires --native and no mutation control')
    args.output.mkdir(parents=True, exist_ok=True)
    if any(args.output.iterdir()):
        parser.error('Use an empty evidence directory')
    prefix = '.tree_probe_' + uuid.uuid4().hex
    generated = prepare(prefix, args.negative_control)
    files = ('code/game/objects/farming.dm', 'code/game/turfs/floor_attackby.dm',
             'code/game/objects/structures/wild.dm', 'code/modules/persistence/saving.dm',
             'code/modules/persistence/loading.dm', 'code/processes/obj.dm',
             'tests/tree_planting/probe.dm', 'tests/tree_planting/run.py', 'scripts/native_fixture.py')
    metadata = dict(head_sha=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                    native_requested=args.native, negative_control=args.negative_control,
                    compile_only=args.compile_only,
                    map='synthetic 8x4x1', normal_startup=False,
                    source_sha256={name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in files})
    (args.output / 'metadata.json').write_text(json.dumps(metadata, indent=2))
    (args.output / 'tested.patch').write_bytes(subprocess.check_output(['git', 'diff', 'HEAD'], cwd=ROOT))
    for suffix, text in generated.items():
        (args.output / (prefix + suffix)).write_text(text, encoding='utf-8')
    shutil.copy2(ROOT / 'tests/tree_planting/probe.dm', args.output / 'probe.dm')
    if not args.native:
        print('PASS: production-source fixture prepared; no compiler or runtime executed')
        return
    binary = args.byond_bin.resolve()
    session = Session(args.output / 'supervisor', metadata['head_sha']) if os.name == 'nt' else None
    paths = [ROOT / (prefix + suffix) for suffix in (*generated, '.dmb', '.rsc')]
    try:
        for suffix, text in generated.items():
            (ROOT / (prefix + suffix)).write_text(text, encoding='utf-8')
        build = run_native(session, [str(binary / ('dm.exe' if os.name == 'nt' else 'DreamMaker')),
                                     '-max_errors', '0', str(ROOT / (prefix + '.dme'))], cwd=ROOT,
                           phase='tree-compile', timeout=120, artifacts=paths[-2:])
        output = build.stdout + build.stderr
        (args.output / 'compile.log').write_text(output)
        if build.returncode or 'DM compiler version 516.1681' not in output or '0 errors, 0 warnings' not in output:
            raise RuntimeError('Pinned compile failed: ' + output[-4000:])
        if args.compile_only:
            print('PASS: BYOND 516.1681 production-source fixture compile, 0 errors/warnings; no runtime launched')
            return
        work = args.output.resolve() / 'runtime'
        work.mkdir()
        for suffix in ('.dmb', '.rsc'):
            shutil.copy2(ROOT / (prefix + suffix), work / (prefix + suffix))
        shutil.copytree(ROOT / 'config/names', work / 'config/names')
        phases = [('roundtrip', 'PASS: tree planting production paths and disk round trip'),
                  ('writer', 'PASS: tree restart writer'),
                  ('reader', 'PASS: tree restart reader and production object dispatch')]
        if args.negative_control:
            phases = [('roundtrip', CONTROLS[args.negative_control][3])]
        for phase, expected in phases:
            # Preserve every attempted phase's logs; result files cannot leak a
            # previous pass into a failed or unfinished fresh process.
            (work / 'result.txt').unlink(missing_ok=True)
            (work / 'runtime.log').unlink(missing_ok=True)
            runtime = run_native(session, [str(binary / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')),
                                           str(work / (prefix + '.dmb')),
                                           *(['-invisible', '-close'] if os.name == 'nt' else []),
                                           *no_port_args(), '-trusted', '-params', 'tree_phase=' + phase,
                                           '-log', 'runtime.log'], cwd=work,
                                 phase='tree-' + phase, timeout=45, state_directory=work)
            diagnostics = runtime.stdout + runtime.stderr
            for name in ('runtime.log', 'result.txt', 'errors.txt'):
                if (work / name).exists():
                    shutil.copy2(work / name, args.output / (phase + '-' + name))
                    if name != 'result.txt':
                        diagnostics += read_bounded(work / name)
            (args.output / (phase + '-daemon.log')).write_text(runtime.stdout + runtime.stderr)
            result = read_bounded(work / 'result.txt').strip() if (work / 'result.txt').exists() else ''
            if runtime.returncode or result != expected or any(
                    marker in diagnostics.lower() for marker in ('runtime error:', 'runtime in ', 'uncaught exception:', 'bug:', '## error:')):
                raise RuntimeError('Native fixture failed: ' + result + '\n' + diagnostics[-3000:])
            print(('PASS expected mutation: ' if args.negative_control else '') + result, flush=True)
    finally:
        for path in paths:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
