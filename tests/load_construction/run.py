"""Construct every saveable type the way a world load does.

Compiles the production game with normal startup disabled, then builds each
saveable /datum type on a synthetic 40x40x1 world: atoms with new type(loc)
while persistence_saved_atom_construction is set, other datums with no
arguments. A constructor that throws aborts a whole world import, and one that
reschedules itself without yielding stalls the server.

The run fails on a failure that known_failures.txt does not list, on a listed
entry that no longer fails, and on a stall (no completion within --timeout).
Prints the evidence directory.
"""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import uuid

HERE = Path(__file__).resolve().parent
# Each control reverts one fix and must fail the run with its own message.
CONTROLS = {
    'zero-timer': ('code/game/objects/effects/spawner.dm',
                   '\treturn max(10, rand(timer, timer * 1.5))\n',
                   '\treturn rand(timer, timer * 1.5)\n',
                   'stalled'),
    'vehicle-names': ('code/modules/1713/machinery/modular_vehicles/axis.dm',
                      '\tif (persistence_saved_atom_construction || !length(names))\n',
                      '\tif (FALSE)\n',
                      'new failure'),
}


def compiler_matches(text, returncode, version):
    return (returncode == 0 and
            re.search(r'^DM compiler version ' + re.escape(version) + r'\b', text, re.MULTILINE) is not None and
            re.search(r'\b0 errors,\s*0 warnings\b', text) is not None)


def known_failures():
    known = set()
    for line in (HERE / 'known_failures.txt').read_text(encoding='utf-8').splitlines():
        line = line.split('#', 1)[0].strip()
        if line:
            known.add(line)
    return known


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--negative-control', choices=sorted(CONTROLS))
    parser.add_argument('--expected-byond-version', default='516.1688')
    parser.add_argument('--timeout', type=int, default=900, help='seconds before the sweep counts as stalled')
    parser.add_argument('--range', nargs=2, type=int, metavar=('START', 'STOP'),
                        help='only construct saveable types numbered START..STOP-1 (for bisecting a stall)')
    args = parser.parse_args()
    root = HERE.parents[1]
    stem = '.load_construction_' + uuid.uuid4().hex
    generated = {suffix: root / (stem + suffix) for suffix in
                 ('.dme', '_world.dm', '_globals.dm', '_control.dm', '.dmb', '.rsc')}
    output = Path(tempfile.mkdtemp(prefix='civ13-load-construction-'))
    print(f'Evidence: {output}', flush=True)
    env = dict(os.environ)
    env['LD_LIBRARY_PATH'] = str(args.byond_bin) + os.pathsep + env.get('LD_LIBRARY_PATH', '')
    try:
        world = (root / 'code/world.dm').read_text(encoding='utf-8')
        start = world.index('/world/New()')
        parent = world.index('\n\t..()', start)
        world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
        world = world.replace('/world/New()', '/world/proc/unused_load_construction_startup()', 1)
        world = world.replace('/datum/global_init/New()\n', '/datum/global_init/New()\n\treturn\n', 1)
        generated['_world.dm'].write_text(world, encoding='utf-8')
        globals_source = (root / 'code/controllers/mc/globals.dm').read_text(encoding='utf-8')
        marker = '/datum/controller/global_vars/New()\n'
        if globals_source.count(marker) != 1:
            raise RuntimeError('Global isolation marker changed')
        generated['_globals.dm'].write_text(globals_source.replace(marker, marker + '\treturn\n'), encoding='utf-8')
        source = (root / 'civ13.dme').read_text(encoding='utf-8')
        replacements = [('code\\world.dm', '_world.dm'), ('code\\controllers\\mc\\globals.dm', '_globals.dm')]
        if args.negative_control:
            path, old, new, _ = CONTROLS[args.negative_control]
            text = (root / path).read_text(encoding='utf-8')
            if text.count(old) != 1:
                raise RuntimeError('Negative-control target missing or ambiguous')
            generated['_control.dm'].write_text(text.replace(old, new, 1), encoding='utf-8')
            replacements.append((path.replace('/', '\\'), '_control.dm'))
        for original, suffix in replacements:
            if source.count(original) != 1:
                raise RuntimeError(f'Include {original} missing from civ13.dme')
            source = source.replace(original, generated[suffix].name)
        source = re.sub(r'^#include ".*\.dmm"\s*$', '', source, flags=re.M)
        generated['.dme'].write_text(source + '\n#include "tests/load_construction/probe.dm"\n', encoding='utf-8')
        compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
        daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
        build = subprocess.run([str(compiler), '-max_errors', '0', str(generated['.dme'])], cwd=root,
                               capture_output=True, text=True, timeout=600, env=env)
        text = build.stdout + build.stderr
        (output / 'compile.log').write_text(text, encoding='utf-8')
        if not compiler_matches(text, build.returncode, args.expected_byond_version):
            print(text, flush=True)
            raise RuntimeError('Pinned production-source compilation failed')
        for suffix in ('.dmb', '.rsc'):
            shutil.copy2(generated[suffix], output / generated[suffix].name)
        for rel in subprocess.check_output(['git', 'ls-files', 'config/names'], cwd=root, text=True).splitlines():
            destination = output / rel
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(root / rel, destination)
        (output / 'data').mkdir(exist_ok=True)
        if args.range:
            (output / 'construction_range.txt').write_text(f'{args.range[0]} {args.range[1]}', encoding='utf-8')
        command = [str(daemon), str(output / generated['.dmb'].name)]
        if os.name == 'nt':
            command += ['-invisible', '-close']
        process = subprocess.Popen(command + ['-trusted', '-log', 'runtime.log'], cwd=output,
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env)
        try:
            process.wait(timeout=args.timeout)
            stalled = False
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
            stalled = True
        log = (output / 'runtime.log').read_text(encoding='utf-8', errors='replace') if (output / 'runtime.log').exists() else ''
        progress = [line for line in log.splitlines() if line.startswith('swept ')]
        problems = []
        if stalled:
            last = progress[-1] if progress else 'before the first 200 types'
            problems.append(f'stalled: no completion within {args.timeout}s (last progress: {last}); '
                            'bisect with --range START STOP')
        failures = set()
        failure_file = output / 'construction_failures.txt'
        if failure_file.exists():
            for line in failure_file.read_text(encoding='utf-8').splitlines():
                parts = line.split('\t')
                if len(parts) >= 2:
                    failures.add(parts[1])
                    print(line, flush=True)
        if not stalled:
            known = known_failures()
            for path in sorted(failures - known):
                problems.append(f'new failure: {path}')
            if not args.range:
                for path in sorted(known - failures):
                    problems.append(f'listed in known_failures.txt but constructs cleanly now: {path}')
            result = output / 'construction_result.txt'
            print(result.read_text(encoding='utf-8') if result.exists() else 'no construction_result.txt', flush=True)
            if not result.exists() or process.returncode:
                problems.append(f'daemon exited {process.returncode} without a result')
        for problem in problems:
            print('FAIL: ' + problem, flush=True)
        if args.negative_control:
            expected = CONTROLS[args.negative_control][3]
            if not any(p.startswith(expected) for p in problems):
                raise RuntimeError(f'Negative control {args.negative_control} did not fail with "{expected}"')
            print('PASS: negative control failed as expected', flush=True)
        elif problems:
            raise RuntimeError('Load construction sweep failed')
        else:
            print('PASS: every saveable type constructs the way a load does', flush=True)
    finally:
        for path in generated.values():
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
