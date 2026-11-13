"""Huey air assault, checked headless.

Checks that American soldiers on the Vietnam maps get the Huey note and that
signal smoke can mark its landing zone, then compiles the production game
with normal startup disabled plus probe.dm, starts the MC timer loop and
checks that the Huey is put on a clear pad near the American start, only
Americans board, it waits for a landing zone, signal smoke calls the lift,
it flies to the smoke over the roofs, sets the squad down, flies home and
keeps a smoke popped during the flight for the next lift.

--negative-control no-unload compiles a copy that sets the squad down back at
the pad instead of the landing zone and must fail.
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
    parser.add_argument('--negative-control', choices=['no-unload'])
    parser.add_argument('--expected-byond-version', default='516.1688')
    parser.add_argument('--timeout', type=int, default=180)
    args = parser.parse_args()
    root = HERE.parents[1]
    controller = (root / 'code/game/jobs/job_controller.dm').read_text(encoding='utf-8')
    if controller.count('\t\tjob.equip(H)\n\t\thuey_give_note(H)\n') != 1:
        raise RuntimeError('Soldiers no longer get the Huey note after equipping')
    smoke = (root / 'code/game/objects/items/weapons/grenades/smokebomb.dm').read_text(encoding='utf-8')
    if smoke.count('huey_mark_lz(get_turf(src), firer)') != 1 or smoke.count('options["Landing zone for the Huey"]') != 1:
        raise RuntimeError('Signal smoke no longer marks the Huey landing zone')
    if not (root / 'icons/obj/vehicles/huey.dmi').exists():
        raise RuntimeError('huey.dmi is missing')
    print('ok: the Huey note, the smoke option and the art are wired', flush=True)
    stem = '.huey_assault_' + uuid.uuid4().hex
    generated = {suffix: root / (stem + suffix) for suffix in ('.dme', '_world.dm', '_globals.dm', '.dmb', '.rsc')}
    output = Path(tempfile.mkdtemp(prefix='civ13-huey-assault-'))
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
        world = world.replace('/world/New()', '/world/proc/unused_huey_assault_startup()', 1)
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
            meta = (root / 'code/modules/1713/huey_assault.dm').read_text(encoding='utf-8')
            needle = '\tunload(get_turf(src))\n\t// A new smoke'
            if meta.count(needle) != 1:
                raise RuntimeError('touch_down changed; update the negative control')
            generated['_meta.dm'] = root / (stem + '_meta.dm')
            generated['_meta.dm'].write_text(meta.replace(needle, '\tunload(home)\n\t// A new smoke'), encoding='utf-8')
            original = 'code\\modules\\1713\\huey_assault.dm'
            if source.count(original) != 1:
                raise RuntimeError('huey_assault.dm include changed')
            source = source.replace(original, generated['_meta.dm'].name)
        generated['.dme'].write_text(source + '\n#include "tests/huey_assault/probe.dm"\n', encoding='utf-8')
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
        log_path = output / 'hp_log.txt'
        lines = [l for l in (log_path.read_text(encoding='utf-8').splitlines() if log_path.exists() else []) if l.strip()]
        print('\n'.join(lines), flush=True)
        failed = 'DONE' not in lines or any(not l.startswith(('ok:', 'DONE')) for l in lines)
        if args.negative_control:
            if not failed:
                raise RuntimeError('Negative control passed; the probe no longer detects a Huey that keeps its passengers')
            print('PASS: negative control failed as expected', flush=True)
        elif failed:
            raise RuntimeError('Huey probe failed')
        else:
            print('PASS: the Huey drops the squad at the LZ', flush=True)
    finally:
        for path in generated.values():
            path.unlink(missing_ok=True)
        for leftover in root.glob(stem + '*'):
            leftover.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
