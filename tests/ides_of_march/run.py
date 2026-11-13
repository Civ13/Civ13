"""The Ides of March map and mode, checked headless.

First checks the map source: maps/313bc/ides_of_march.dmm is exactly what
tools/ides_of_march/make_map.py writes, it carries the map metadata, both
sides' spawn landmarks and the doorway invisible walls, and the map is in the
pre-firearms vote list. Then compiles the production game with normal startup
disabled plus probe.dm and checks the mode: both sides' jobs are on the map and
spawn at those landmarks, Caesar's party are Romans and the conspirators a
separate side, the pugio fits in a pocket, and the conspirators win only when
every Caesar who joined is dead.

--negative-control immortal-caesar compiles a copy where a dead Caesar still
counts as alive and must fail.
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


def check_map(root):
    dmm = root / 'maps/313bc/ides_of_march.dmm'
    before = dmm.read_text(encoding='utf-8')
    subprocess.run(['python3' if os.name != 'nt' else 'py', *([] if os.name != 'nt' else ['-3']),
                    str(root / 'tools/ides_of_march/make_map.py')], check=True, capture_output=True)
    after = dmm.read_text(encoding='utf-8')
    if before != after:
        dmm.write_text(before, encoding='utf-8')
        raise RuntimeError('ides_of_march.dmm differs from make_map.py output; rerun the generator')
    keys = {k: v + ')' for k, v in re.findall(r'^"(\w+)" = \((.*)\)$', after, re.M)}
    rows = after[after.index('(1,1,1) = {"') + 12:after.rindex('"}')].split()
    counts = {}
    for row in rows:
        for i in range(0, len(row), 2):
            counts[row[i:i + 2]] = counts.get(row[i:i + 2], 0) + 1
    def tiles(text):
        return sum(n for k, n in counts.items() if text in keys[k])
    for text, least in (('/obj/map_metadata/ides_of_march,', 1), ('"JoinLateIdesSenate"', 40),
                        ('"JoinLateIdesCaesar"', 20), ('/area/caribbean/no_mans_land/invisible_wall)', 5),
                        ('/area/caribbean/ides/curia)', 300)):
        if tiles(text) < least:
            raise RuntimeError(f'map has fewer than {least} tiles with {text}')
    code = '\n'.join(p.read_text(encoding='utf-8', errors='ignore') for p in (root / 'code').rglob('*.dm'))
    for kind in set(re.findall(r'(/(?:obj|turf|area)/[\w/]+)', after)):
        if not re.search('^' + re.escape(kind) + r'\s*$', code, re.M):
            raise RuntimeError(f'map uses {kind}, which is not defined')
    vote = (root / 'code/processes/mapswap.dm').read_text(encoding='utf-8')
    if not re.search(r'^\t+MAP_IDES_OF_MARCH = \d+,', vote, re.M):
        raise RuntimeError('The Ides of March is not in the map vote lists')
    print('ok: the map matches its generator and has spawns, doorways and metadata', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--negative-control', choices=['immortal-caesar'])
    parser.add_argument('--expected-byond-version', default='516.1688')
    parser.add_argument('--timeout', type=int, default=180)
    args = parser.parse_args()
    root = HERE.parents[1]
    check_map(root)
    stem = '.ides_of_march_' + uuid.uuid4().hex
    generated = {suffix: root / (stem + suffix) for suffix in ('.dme', '_world.dm', '_globals.dm', '.dmb', '.rsc')}
    output = Path(tempfile.mkdtemp(prefix='civ13-ides-of-march-'))
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
        world = world.replace('/world/New()', '/world/proc/unused_ides_of_march_startup()', 1)
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
            meta = (root / 'code/game/objects/map_metadata/ides_of_march.dm').read_text(encoding='utf-8')
            needle = 'if (!QDELETED(H) && H.stat != DEAD)'
            if meta.count(needle) != 1:
                raise RuntimeError('caesar_fallen changed; update the negative control')
            generated['_meta.dm'] = root / (stem + '_meta.dm')
            generated['_meta.dm'].write_text(meta.replace(needle, 'if (!QDELETED(H))'), encoding='utf-8')
            original = 'code\\game\\objects\\map_metadata\\ides_of_march.dm'
            source = source.replace(original, generated['_meta.dm'].name)
        generated['.dme'].write_text(source + '\n#include "tests/ides_of_march/probe.dm"\n', encoding='utf-8')
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
        log_path = output / 'im_log.txt'
        lines = [l for l in (log_path.read_text(encoding='utf-8').splitlines() if log_path.exists() else []) if l.strip()]
        print('\n'.join(lines), flush=True)
        failed = 'DONE' not in lines or any(not l.startswith(('ok:', 'DONE')) for l in lines)
        if args.negative_control:
            if not failed:
                raise RuntimeError('Negative control passed; the probe no longer detects a Caesar who cannot die')
            print('PASS: negative control failed as expected', flush=True)
        elif failed:
            raise RuntimeError('Ides of March probe failed')
        else:
            print('PASS: the senate waits for Caesar', flush=True)
    finally:
        for path in generated.values():
            path.unlink(missing_ok=True)
        for leftover in root.glob(stem + '*'):
            leftover.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
