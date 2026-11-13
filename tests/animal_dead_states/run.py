"""Check that every simple animal shows its dead sprite after it dies.

Compiles the production game with normal startup disabled, builds every
/mob/living/simple_animal type (and its young and sheared variants) on a small
synthetic world, kills it and refreshes its sprite with update_canmove() and
update_icons(), as the game does afterwards. The animal must then show
icon_dead, and icon_dead must exist in its icon file. An animal whose
update_icons() puts the standing sprite back appears alive after death.

The run fails on a gap that known_missing.txt does not list and on a listed
gap that no longer happens. --negative-control makes the base update_icons()
put the standing sprite back on every dead animal and must fail. Prints the
evidence directory.
"""
import argparse
import importlib.util
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import uuid

HERE = Path(__file__).resolve().parent
# Makes the base update_icons() leave a dead animal's sprite alone, so every
# override that puts the standing sprite back must be reported.
CONTROL = ('code/game/mob/living/simple_animal/riding.dm',
           '\tif (stat == DEAD)\n\t\ticon_state = icon_dead\n',
           '\tif (stat == DEAD)\n\t\ticon_state = icon_living\n')


_compiler_spec = importlib.util.spec_from_file_location(
    'fixture_compiler_output', Path(__file__).resolve().parents[2] / 'scripts/fixture_compiler_output.py')
_compiler_output = importlib.util.module_from_spec(_compiler_spec)
_compiler_spec.loader.exec_module(_compiler_output)
compiler_matches = _compiler_output.compiler_matches

_global_spec = importlib.util.spec_from_file_location(
    'fixture_global_initialization', Path(__file__).resolve().parents[2] / 'scripts/fixture_global_initialization.py')
_global_initialization = importlib.util.module_from_spec(_global_spec)
_global_spec.loader.exec_module(_global_initialization)
isolate_global_initialization = _global_initialization.isolate_global_initialization


def known_missing():
    known = set()
    for line in (HERE / 'known_missing.txt').read_text(encoding='utf-8').splitlines():
        line = line.split('#', 1)[0].strip()
        if line:
            known.add(' '.join(line.split()))
    return known


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--negative-control', action='store_true',
                        help='restore the standing sprite on death; the run must then report new gaps')
    parser.add_argument('--expected-byond-version', default='516.1688')
    parser.add_argument('--timeout', type=int, default=600)
    args = parser.parse_args()
    root = HERE.parents[1]
    stem = '.animal_dead_states_' + uuid.uuid4().hex
    generated = {suffix: root / (stem + suffix) for suffix in
                 ('.dme', '_world.dm', '_globals.dm', '_control.dm', '.dmb', '.rsc')}
    output = Path(tempfile.mkdtemp(prefix='civ13-animal-dead-states-'))
    print(f'Evidence: {output}', flush=True)
    env = dict(os.environ)
    env['LD_LIBRARY_PATH'] = str(args.byond_bin) + os.pathsep + env.get('LD_LIBRARY_PATH', '')
    try:
        world = (root / 'code/world.dm').read_text(encoding='utf-8')
        start = world.index('/world/New()')
        parent = world.index('\n\t..()', start)
        world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
        world = world.replace('/world/New()', '/world/proc/unused_animal_dead_states_startup()', 1)
        world = world.replace('/datum/global_init/New()\n', '/datum/global_init/New()\n\treturn\n', 1)
        generated['_world.dm'].write_text(world, encoding='utf-8')
        globals_source = (root / 'code/controllers/mc/globals.dm').read_text(encoding='utf-8')
        generated['_globals.dm'].write_text(isolate_global_initialization(globals_source), encoding='utf-8')
        source = (root / 'civ13.dme').read_text(encoding='utf-8')
        replacements = [('code\\world.dm', '_world.dm'), ('code\\controllers\\mc\\globals.dm', '_globals.dm')]
        if args.negative_control:
            path, old, new = CONTROL
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
        generated['.dme'].write_text(source + '\n#include "tests/animal_dead_states/probe.dm"\n', encoding='utf-8')
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
        command = [str(daemon), str(output / generated['.dmb'].name)]
        if os.name == 'nt':
            command += ['-invisible', '-close']
        process = subprocess.Popen(command + ['-trusted', '-log', 'runtime.log'], cwd=output,
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env)
        try:
            process.wait(timeout=args.timeout)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
            raise RuntimeError(f'Animal sweep did not finish within {args.timeout}s')
        problems = []
        gaps = {}
        missing_file = output / 'animal_dead_missing.txt'
        if missing_file.exists():
            for line in missing_file.read_text(encoding='utf-8').splitlines():
                parts = line.split('\t')
                if len(parts) == 5 and parts[0] in ('MISSING', 'STANDING'):
                    gaps.setdefault(' '.join(' '.join(parts[:5]).split()), parts[0])
        throws = output / 'animal_dead_throws.txt'
        if throws.exists():
            print(throws.read_text(encoding='utf-8'), flush=True)
        known = known_missing()
        for gap in sorted(set(gaps) - known):
            problems.append(f'new missing state ({gaps[gap]}): {gap}')
        for gap in sorted(known - set(gaps)):
            problems.append(f'listed in known_missing.txt but present now: {gap}')
        result = output / 'animal_dead_result.txt'
        print(result.read_text(encoding='utf-8') if result.exists() else 'no animal_dead_result.txt', flush=True)
        if not result.exists() or process.returncode:
            problems.append(f'daemon exited {process.returncode} without a result')
        for problem in problems:
            print('FAIL: ' + problem, flush=True)
        if args.negative_control:
            if not any(p.startswith('new missing state') for p in problems):
                raise RuntimeError('Negative control did not report a missing state')
            print('PASS: negative control reported missing states as expected', flush=True)
        elif problems:
            raise RuntimeError('Animal dead sprite sweep failed')
        else:
            print('PASS: every animal shows an existing dead sprite after death', flush=True)
    finally:
        for path in generated.values():
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
