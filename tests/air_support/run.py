"""Visible air support jets, checked headless.

Compiles the production game with normal startup disabled plus probe.dm,
starts the MC timer loop the way world/New does, and sends real jets through
air_support_jet_pass(): the jet and its shadow appear, cross the release point
when the payload leaves, fly on past the target and delete themselves, near a
map edge the launch waits so the timing still holds, aircraft without art fly
unseen, and a rocket's smoke trail puffs appear along its path and fade away.
It also checks that turf/try_airstrike and the Syria operators are wired to it.

--negative-control no-timer-loop skips Master.start_timer_loop() and must fail
(no jet ever moves).
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
    parser.add_argument('--negative-control', choices=['no-timer-loop'])
    parser.add_argument('--expected-byond-version', default='516.1688')
    parser.add_argument('--timeout', type=int, default=180)
    args = parser.parse_args()
    root = HERE.parents[1]
    turf_source = (root / 'code/game/turfs/turf.dm').read_text(encoding='utf-8')
    if turf_source.count('air_support_jet_pass(src, direction, aircraft_name') != 3:
        raise RuntimeError('turf/try_airstrike no longer shows the jet on every strike path')
    if 'air_support_smoke_trail(P.loc, P.pixel_x, P.pixel_y, 15)' not in turf_source:
        raise RuntimeError('turf/airstrike no longer trails smoke behind rockets')
    jobs = (root / 'code/modules/1713/jobs/modern.dm').read_text(encoding='utf-8')
    delta = jobs[jobs.index('/datum/job/american/delta_force/equip('):]
    delta = delta[:delta.index('\n/datum/job/', 1)] if '\n/datum/job/' in delta[1:] else delta
    if 'laser_designator(null), H)' not in delta:
        raise RuntimeError('Syria operators no longer carry a laser designator')
    print('ok: try_airstrike, rockets and Syria operators are wired to air support', flush=True)
    stem = '.air_support_' + uuid.uuid4().hex
    generated = {suffix: root / (stem + suffix) for suffix in ('.dme', '_world.dm', '_globals.dm', '.dmb', '.rsc')}
    output = Path(tempfile.mkdtemp(prefix='civ13-air-support-'))
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
        world = world.replace('/world/New()', '/world/proc/unused_air_support_startup()', 1)
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
        generated['.dme'].write_text(source + '\n#include "tests/air_support/probe.dm"\n', encoding='utf-8')
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
        if args.negative_control:
            (output / 'skip_start.txt').write_text('1', encoding='utf-8')
        command = [str(daemon), str(output / generated['.dmb'].name)]
        if os.name == 'nt':
            command += ['-invisible', '-close']
        try:
            subprocess.run(command + ['-trusted', '-log', 'runtime.log'], cwd=output, stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL, env=env, timeout=args.timeout)
        except subprocess.TimeoutExpired:
            pass
        log_path = output / 'as_log.txt'
        lines = [l for l in (log_path.read_text(encoding='utf-8').splitlines() if log_path.exists() else []) if l.strip()]
        print('\n'.join(lines), flush=True)
        failed = 'DONE' not in lines or any(not l.startswith(('ok:', 'DONE')) for l in lines)
        if args.negative_control:
            if not failed:
                raise RuntimeError('Negative control passed; the probe no longer detects a stopped timer loop')
            print('PASS: negative control failed as expected', flush=True)
        elif failed:
            raise RuntimeError('Air support probe failed')
        else:
            print('PASS: air support jets fly and leave no objects behind', flush=True)
    finally:
        for path in generated.values():
            path.unlink(missing_ok=True)
        for leftover in root.glob(stem + '*'):
            leftover.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
