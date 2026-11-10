"""Check that every gun's sprite states exist after it is unloaded or opened.

Compiles the production game with normal startup disabled, builds every
/obj/item/weapon/gun type on a small synthetic world and calls update_icon()
as spawned, unloaded and with its bolt, cover or action open. Every state the
gun then asks for must exist: icon_state in its own icon, item_state in the
in-hand icons and icon_state in the back/shoulder icon when the gun can be
worn there. BYOND draws its error icon for a missing state.

The run fails on a gap that known_missing.txt does not list and on a listed
gap that no longer happens. Prints the evidence directory.
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
# Reverts the fallback; the unloaded states it covers must then be reported.
CONTROL = ('code/_helpers/sprite_states.dm',
           '\tif (!icon_file || !state || icon_has_state(icon_file, state))\n',
           '\tif (TRUE)\n')


_compiler_spec = importlib.util.spec_from_file_location(
    'fixture_compiler_output', Path(__file__).resolve().parents[2] / 'scripts/fixture_compiler_output.py')
_compiler_output = importlib.util.module_from_spec(_compiler_spec)
_compiler_spec.loader.exec_module(_compiler_output)
compiler_matches = _compiler_output.compiler_matches


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
                        help='disable the missing-state fallback; the run must then report new gaps')
    parser.add_argument('--expected-byond-version', default='516.1688')
    parser.add_argument('--timeout', type=int, default=600)
    args = parser.parse_args()
    root = HERE.parents[1]
    stem = '.gun_icon_states_' + uuid.uuid4().hex
    generated = {suffix: root / (stem + suffix) for suffix in
                 ('.dme', '_world.dm', '_globals.dm', '_control.dm', '.dmb', '.rsc')}
    output = Path(tempfile.mkdtemp(prefix='civ13-gun-icon-states-'))
    print(f'Evidence: {output}', flush=True)
    env = dict(os.environ)
    env['LD_LIBRARY_PATH'] = str(args.byond_bin) + os.pathsep + env.get('LD_LIBRARY_PATH', '')
    try:
        world = (root / 'code/world.dm').read_text(encoding='utf-8')
        start = world.index('/world/New()')
        parent = world.index('\n\t..()', start)
        world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
        world = world.replace('/world/New()', '/world/proc/unused_gun_icon_states_startup()', 1)
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
        generated['.dme'].write_text(source + '\n#include "tests/gun_icon_states/probe.dm"\n', encoding='utf-8')
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
            raise RuntimeError(f'Gun sweep did not finish within {args.timeout}s')
        problems = []
        gaps = {}
        missing_file = output / 'gun_icon_missing.txt'
        if missing_file.exists():
            for line in missing_file.read_text(encoding='utf-8').splitlines():
                parts = line.split('\t')
                if len(parts) == 6 and parts[0] == 'MISSING':
                    gaps.setdefault(' '.join(' '.join(parts[2:6]).split()), parts[1])
        throws = output / 'gun_icon_throws.txt'
        if throws.exists():
            print(throws.read_text(encoding='utf-8'), flush=True)
        known = known_missing()
        for gap in sorted(set(gaps) - known):
            problems.append(f'new missing state ({gaps[gap]}): {gap}')
        for gap in sorted(known - set(gaps)):
            problems.append(f'listed in known_missing.txt but present now: {gap}')
        result = output / 'gun_icon_result.txt'
        print(result.read_text(encoding='utf-8') if result.exists() else 'no gun_icon_result.txt', flush=True)
        if not result.exists() or process.returncode:
            problems.append(f'daemon exited {process.returncode} without a result')
        for problem in problems:
            print('FAIL: ' + problem, flush=True)
        if args.negative_control:
            if not any(p.startswith('new missing state') for p in problems):
                raise RuntimeError('Negative control did not report a missing state')
            print('PASS: negative control reported missing states as expected', flush=True)
        elif problems:
            raise RuntimeError('Gun sprite state sweep failed')
        else:
            print('PASS: every gun sprite state exists after unloading and opening', flush=True)
    finally:
        for path in generated.values():
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
