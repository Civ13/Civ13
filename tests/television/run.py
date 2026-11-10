"""Run the television fixture (tests/television/game.dm) on Linux or Windows.

Production sources are compiled without ordinary
startup or maps, the lesson clock is replaced in a generated copy, the world
runs with no listening port and unique temporary save storage, and the result
JSON names the tested commit and compiler build. The compiler must match the
pin in tools/byond/version.json.

    python3 tests/television/run.py --byond-bin <pinned BYOND bin directory>
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def byond_env(bin_dir):
    env = dict(os.environ)
    if os.name != 'nt':
        env['LD_LIBRARY_PATH'] = os.pathsep.join(p for p in (str(bin_dir), env.get('LD_LIBRARY_PATH')) if p)
    return env


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', required=True, help='directory with DreamMaker and DreamDaemon (pinned build)')
    parser.add_argument('--timeout', type=int, default=120)
    parser.add_argument('--compile-only', action='store_true')
    parser.add_argument('--trusted', action='store_true', help='Requires explicit maintainer authorization')
    args = parser.parse_args(argv)
    if not args.compile_only and not args.trusted:
        parser.error("Native execution requires --trusted and explicit maintainer authorization")
    bin_dir = Path(args.byond_bin)
    compiler = bin_dir / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = bin_dir / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    pin = json.loads((ROOT / 'tools/byond/version.json').read_text(encoding='utf-8'))['version']
    build = pin.split('.')[1]
    prefix = '.television_' + uuid.uuid4().hex
    commit = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=ROOT, capture_output=True, text=True, check=True).stdout.strip()
    temporary = Path(tempfile.mkdtemp(prefix='civ13-television-game-'))
    generated = []
    try:
        world = (ROOT / 'code/world.dm').read_text(encoding='utf-8-sig')
        world = world.replace('/world/New()', '/world/proc/unused_television_startup()')
        offset = world.index('/world/proc/unused_television_startup()')
        world = world[:offset] + re.sub(r'(?m)^\t\.\.\(\)\r?$', '', world[offset:], count=1)
        world = world.replace('/datum/global_init/New()', '/datum/global_init/New()\n\treturn')
        globals_source = (ROOT / 'code/controllers/mc/globals.dm').read_text(encoding='utf-8-sig')
        globals_source = globals_source.replace('/datum/controller/global_vars/New()',
                                                '/datum/controller/global_vars/New()\n\tGLOB = src\n\treturn')
        telecom = (ROOT / 'code/modules/research_tree/node_broadcast.dm').read_text(encoding='utf-8-sig')
        telecom = telecom.replace('return world.time', 'return tv_fixture_time')
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8-sig')
        dme = dme.replace('code\\world.dm', prefix + '_world.dm').replace('code\\controllers\\mc\\globals.dm', prefix + '_globals.dm')
        dme = dme.replace('code\\modules\\research_tree\\node_broadcast.dm', prefix + '_telecom.dm')
        modern = (ROOT / 'code/modules/1713/modern_telecom.dm').read_text(encoding='utf-8-sig').replace('return world.time', 'return tv_fixture_time')
        dme = dme.replace('code\\modules\\1713\\modern_telecom.dm', prefix + '_modern.dm')
        dme = re.sub(r'(?m)^#include ".*\.dmm"\s*$', '', dme)
        for suffix, text in (('_world.dm', world), ('_globals.dm', globals_source), ('_telecom.dm', telecom), ('_modern.dm', modern),
                             ('.dme', dme + '\n#include "tests/television/game.dm"\n')):
            path = ROOT / (prefix + suffix)
            path.write_text(text, encoding='utf-8')
            generated.append(path)
        generated += [ROOT / (prefix + '.dmb'), ROOT / (prefix + '.rsc')]
        compile_run = subprocess.run([str(compiler), '-max_errors', '0', prefix + '.dme'], cwd=ROOT,
                                     capture_output=True, text=True, env=byond_env(bin_dir))
        output = compile_run.stdout + compile_run.stderr
        (temporary / 'compile.log').write_text(output, encoding='utf-8')
        print(output)
        if compile_run.returncode != 0 or '0 errors, 0 warnings' not in output or pin not in output:
            print('FAIL: pinned full-source fixture compile failed')
            return 1
        if args.compile_only:
            print('Compile-only passed; native behavior not run')
            return 0
        for extension in ('.dmb', '.rsc'):
            shutil.copy(ROOT / (prefix + extension), temporary / ('probe' + extension))
        shutil.copytree(ROOT / 'config', temporary / 'config')
        argv_daemon = [str(daemon), 'probe.dmb', '0', '-invisible', '-close', '-params',
                       'tested_commit=' + commit, '-log', 'runtime.log']
        if args.trusted:
            argv_daemon.insert(5, '-trusted')
        try:
            subprocess.run(argv_daemon, cwd=temporary, timeout=args.timeout, env=byond_env(bin_dir))
        except subprocess.TimeoutExpired:
            print('FAIL: television fixture timed out')
            return 1
        log_path = temporary / 'runtime.log'
        log = log_path.read_text(encoding='utf-8', errors='replace') if log_path.exists() else ''
        print(log)
        result_path = temporary / 'result.json'
        if not result_path.exists():
            print('FAIL: no result.json')
            return 1
        result = json.loads(result_path.read_text(encoding='utf-8'))
        print(json.dumps(result))
        checks = log.count('PASS')
        bad = (result.get('failures') != 0 or result.get('commit') != commit or str(result.get('byond_build')) != build
               or re.search(r'runtime error|Bad ref|FAIL:', log) is not None)
        print('%d checks passed, %s failures' % (checks, result.get('failures')))
        return 1 if bad else 0
    finally:
        for path in generated:
            if path.exists():
                path.unlink()
        evidence = ROOT / '.ci' / 'television' / prefix
        evidence.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(temporary, evidence, dirs_exist_ok=True)
        print('Evidence:', evidence)
        shutil.rmtree(temporary, ignore_errors=True)


if __name__ == '__main__':
    sys.exit(main())
