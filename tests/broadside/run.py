"""The Broadside map, checked headless.

Checks that the map matches tools/broadside/make_map.py, is in the vote list,
has a tiller for each side and enough rigged masts for half ahead, that the
Naval Battle jobs serve it and that joining puts a crewman aboard his ship.
Then compiles the production game with normal startup disabled, the real map
and probe.dm, starts the MC timer loop and checks that both ships are
commissioned, crewmen join aboard, a ship sails at the battle pace carrying
her guns, the boatswain's call lays the guns on the enemy hull and fires
them, and the sink and capture checks answer.

--negative-control no-pace compiles a copy where ships sail at the ordinary
sea pace and must fail.
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
    parser.add_argument('--negative-control', choices=['no-pace'])
    parser.add_argument('--expected-byond-version', default='516.1688')
    parser.add_argument('--timeout', type=int, default=180)
    args = parser.parse_args()
    root = HERE.parents[1]
    check = subprocess.run(['python3' if os.name != 'nt' else 'py', *([] if os.name != 'nt' else ['-3']),
                            str(root / 'tools/broadside/make_map.py'), '--check'], capture_output=True, text=True)
    if check.returncode:
        raise RuntimeError(check.stdout + check.stderr)
    dmm = (root / 'maps/1713/broadside.dmm').read_text(encoding='utf-8')
    for side in ('french', 'pirates'):
        if dmm.count('/obj/structure/hull_tiller/broadside/' + side + ',') != 1:
            raise RuntimeError(f'The {side} ship has no tiller, or more than one')
    planks = 0
    masts = 0
    keys = {}
    for line in dmm.splitlines():
        m = re.match(r'^"(\w+)" = \((.*)\)$', line)
        if m:
            keys[m.group(1)] = m.group(2)
    grid = dmm[dmm.index('(1,1,1) = {"') + len('(1,1,1) = {"'):dmm.rindex('"}')]
    for row in grid.split():
        for i in range(0, len(row), 2):
            text = keys[row[i:i + 2]]
            planks += '/obj/covers/repairedfloor/ship' in text
            masts += '/sail/premade' in text
    if masts < 8 or masts * 31 < planks:
        raise RuntimeError(f'{masts} masts cannot drive {planks} planks at half ahead')
    if (root / 'code/processes/mapswap.dm').read_text(encoding='utf-8').count('\t\t\t\t\tMAP_BROADSIDE = 0,') != 1:
        raise RuntimeError('Broadside is not in the 1713 vote list')
    jobs = (root / 'code/modules/1713/jobs/french.dm').read_text(encoding='utf-8') + (root / 'code/modules/1713/jobs/pirates.dm').read_text(encoding='utf-8')
    if jobs.count('MAP_NAVAL, MAP_BROADSIDE') != 16:
        raise RuntimeError('The Naval Battle jobs no longer all serve Broadside')
    if (root / 'code/game/jobs/job_controller.dm').read_text(encoding='utf-8').count('if (broadside_spawn_aboard(H))') != 1:
        raise RuntimeError('Joining no longer puts a crewman aboard his ship')
    print(f'ok: the map matches its generator, {planks} planks and {masts} masts, in the vote list, jobs and spawning wired', flush=True)
    stem = '.broadside_' + uuid.uuid4().hex
    generated = {suffix: root / (stem + suffix) for suffix in ('.dme', '_world.dm', '_globals.dm', '.dmb', '.rsc')}
    output = Path(tempfile.mkdtemp(prefix='civ13-broadside-'))
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
        world = world.replace('/world/New()', '/world/proc/unused_broadside_startup()', 1)
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
            meta = (root / 'code/modules/craft/under_way.dm').read_text(encoding='utf-8')
            needle = ' * max(pace, 1)'
            if meta.count(needle) != 1:
                raise RuntimeError('sail_interval changed; update the negative control')
            generated['_meta.dm'] = root / (stem + '_meta.dm')
            generated['_meta.dm'].write_text(meta.replace(needle, ''), encoding='utf-8')
            original = 'code\\modules\\craft\\under_way.dm'
            if source.count(original) != 1:
                raise RuntimeError('under_way.dm include changed')
            source = source.replace(original, generated['_meta.dm'].name)
        generated['.dme'].write_text(source + '\n#include "maps\\1713\\broadside.dmm"\n#include "tests/broadside/probe.dm"\n', encoding='utf-8')
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
        log_path = output / 'bs_log.txt'
        lines = [l for l in (log_path.read_text(encoding='utf-8').splitlines() if log_path.exists() else []) if l.strip()]
        print('\n'.join(lines), flush=True)
        failed = 'DONE' not in lines or any(not l.startswith(('ok:', 'DONE')) for l in lines)
        if args.negative_control:
            if not failed:
                raise RuntimeError('Negative control passed; the probe no longer detects ships sailing at the sea pace')
            print('PASS: negative control failed as expected', flush=True)
        elif failed:
            raise RuntimeError('Broadside map probe failed')
        else:
            print('PASS: the ships sail into a broadside', flush=True)
    finally:
        for path in generated.values():
            path.unlink(missing_ok=True)
        for leftover in root.glob(stem + '*'):
            leftover.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
