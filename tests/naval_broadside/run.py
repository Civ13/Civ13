"""Naval broadsides, checked headless.

Checks that Naval Battle captains get the boatswain's call and that firing a
cannon by hand goes through discharge(), then compiles the production game
with normal startup disabled plus probe.dm, starts the MC timer loop and
checks the broadside order: guns are found by ship (hull guns by the deck
behind them) and grouped by the side they face, unloaded, broken and modern
guns are left out, the other ship's guns never answer, and the chosen side
fires in a ripple until every gun on it is empty.

--negative-control no-discharge compiles a copy where an ordered gun does not
fire and must fail.
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--negative-control', choices=['no-discharge'])
    parser.add_argument('--expected-byond-version', default='516.1688')
    parser.add_argument('--timeout', type=int, default=180)
    args = parser.parse_args()
    root = HERE.parents[1]
    jobs = (root / 'code/modules/1713/jobs/french.dm').read_text(encoding='utf-8') + (root / 'code/modules/1713/jobs/pirates.dm').read_text(encoding='utf-8')
    if jobs.count('broadside_give_call(H)') != 2:
        raise RuntimeError('Naval Battle captains no longer get the boatswain\'s call')
    piece = (root / 'code/modules/1713/siege/piece.dm').read_text(encoding='utf-8')
    if piece.count('\t\t\t\t\tdischarge(user)') != 1:
        raise RuntimeError('Firing a cannon by hand no longer goes through discharge()')
    print('ok: captains get the call and hand firing uses discharge()', flush=True)
    stem = '.naval_broadside_' + uuid.uuid4().hex
    generated = {suffix: root / (stem + suffix) for suffix in ('.dme', '_world.dm', '_globals.dm', '.dmb', '.rsc')}
    output = Path(tempfile.mkdtemp(prefix='civ13-naval-broadside-'))
    print(f'Evidence: {output}', flush=True)
    env = dict(os.environ)
    env['LD_LIBRARY_PATH'] = str(args.byond_bin) + os.pathsep + env.get('LD_LIBRARY_PATH', '')
    try:
        world = (root / 'code/world.dm').read_text(encoding='utf-8')
        if world.count('\tMaster.start_timer_loop()\n') != 1:
            raise RuntimeError('world/New no longer starts the MC timer loop')
        start = world.index('/world/New()')
        parent = world.index('\n\t..()', start)
        world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
        world = world.replace('/world/New()', '/world/proc/unused_naval_broadside_startup()', 1)
        world = world.replace('/datum/global_init/New()\n', '/datum/global_init/New()\n\treturn\n', 1)
        generated['_world.dm'].write_text(world, encoding='utf-8')
        globals_source = (root / 'code/controllers/mc/globals.dm').read_text(encoding='utf-8')
        marker = '/datum/controller/global_vars/New()\n'
        if globals_source.count(marker) != 1:
            raise RuntimeError('Global isolation marker changed')
        generated['_globals.dm'].write_text(globals_source.replace(marker, marker + '\treturn\n'), encoding='utf-8')
        source = (root / 'civ13.dme').read_text(encoding='utf-8')
        for original, suffix in [('code\\world.dm', '_world.dm'), ('code\\controllers\\mc\\globals.dm', '_globals.dm')]:
            if source.count(original) != 1:
                raise RuntimeError(f'Include {original} missing from civ13.dme')
            source = source.replace(original, generated[suffix].name)
        source = re.sub(r'^#include ".*\.dmm"\s*$', '', source, flags=re.M)
        if args.negative_control:
            meta = (root / 'code/modules/1713/siege/naval_broadside.dm').read_text(encoding='utf-8')
            needle = '\tC.discharge(null)\n'
            if meta.count(needle) != 1:
                raise RuntimeError('broadside_fire_gun changed; update the negative control')
            generated['_meta.dm'] = root / (stem + '_meta.dm')
            generated['_meta.dm'].write_text(meta.replace(needle, ''), encoding='utf-8')
            original = 'code\\modules\\1713\\siege\\naval_broadside.dm'
            source = source.replace(original, generated['_meta.dm'].name)
        generated['.dme'].write_text(source + '\n#include "tests/naval_broadside/probe.dm"\n', encoding='utf-8')
        compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
        daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
        build = subprocess.run([str(compiler), '-max_errors', '0', str(generated['.dme'])], cwd=root,
                               capture_output=True, text=True, timeout=600, env=env)
        text = build.stdout + build.stderr
        (output / 'compile.log').write_text(text, encoding='utf-8')
        if (build.returncode or not re.search(r'^DM compiler version ' + re.escape(args.expected_byond_version) + r'\b', text, re.M)
                or not re.search(r'\b0 errors,\s*0 warnings\b', text)):
            print(text, flush=True)
            raise RuntimeError('Pinned production-source compilation failed')
        for suffix in ('.dmb', '.rsc'):
            shutil.copy2(generated[suffix], output / generated[suffix].name)
        (output / 'data').mkdir(exist_ok=True)
        command = [str(daemon), str(output / generated['.dmb'].name)]
        if os.name == 'nt':
            command += ['-invisible', '-close']
        try:
            subprocess.run(command + ['-trusted', '-log', 'runtime.log'], cwd=output, stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL, env=env, timeout=args.timeout)
        except subprocess.TimeoutExpired:
            pass
        log_path = output / 'nb_log.txt'
        lines = [l for l in (log_path.read_text(encoding='utf-8').splitlines() if log_path.exists() else []) if l.strip()]
        print('\n'.join(lines), flush=True)
        failed = 'DONE' not in lines or any(not l.startswith(('ok:', 'DONE')) for l in lines)
        if args.negative_control:
            if not failed:
                raise RuntimeError('Negative control passed; the probe no longer detects guns that do not fire')
            print('PASS: negative control failed as expected', flush=True)
        elif failed:
            raise RuntimeError('Broadside probe failed')
        else:
            print('PASS: the broadside fires', flush=True)
    finally:
        for path in generated.values():
            path.unlink(missing_ok=True)
        for leftover in root.glob(stem + '*'):
            leftover.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
