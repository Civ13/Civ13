"""Execute headless gather contracts in disposable Linux CI, never ordinary clients.

Separate from the Windows exact-packet grant runner. Uses frozen source and
bounded sequential processes; does not claim Windows Job resource containment.
"""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess

from compile_check import prepare, verify_log
from prepare_gather import PROFILES, variants, fixture_dme, name_dependencies
from prepare_native import git
from check_gather_packet import verify_result


def run(root, output, commit, binaries, prepare_only=False):
    source = prepare(root, output, commit)
    read = lambda path: git(root, 'show', commit + ':' + path).decode('utf-8-sig').replace('\r\n', '\n')
    helper, grass, dme = (read(p) for p in ('code/_helpers/mobs.dm', 'code/game/turfs/floor_attackby.dm', 'civ13.dme'))
    generated = source / 'gather_generated'
    generated.mkdir()
    results = {}
    for profile in PROFILES:
        h, g = variants(helper, grass, profile)
        (generated / (profile + '_mobs.dm')).write_text(h, encoding='utf-8')
        (generated / (profile + '_grass.dm')).write_text(g, encoding='utf-8')
        (source / ('gather_' + profile + '.dme')).write_text(fixture_dme(dme, profile), encoding='utf-8')
    if prepare_only:
        print('PASS frozen gather preparation; native UNRUN')
        return
    for profile in PROFILES:
        runtime = output / 'runtime' / profile
        runtime.mkdir(parents=True)
        for name in name_dependencies(read('code/names.dm')):
            path = runtime / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(git(root, 'show', commit + ':' + name))
        name = 'gather_' + profile
        build = subprocess.run([str(binaries / 'DreamMaker'), '-max_errors', '0', name + '.dme'],
                               cwd=source, capture_output=True, text=True, timeout=180)
        log = build.stdout + build.stderr
        (runtime / 'compile.log').write_text(log, encoding='utf-8')
        verify_log(log, build.returncode)
        for ext in ('.dmb', '.rsc'):
            shutil.copy2(source / (name + ext), runtime / (name + ext))
        result = subprocess.run([str(binaries / 'DreamDaemon'), name + '.dmb', '-invisible', '-close',
                                 '-trusted', '-params', 'tested_commit=' + commit + '&profile=' + profile,
                                 '-log', 'runtime.log'], cwd=runtime, capture_output=True, text=True, timeout=90)
        log = result.stdout + result.stderr
        (runtime / 'daemon.log').write_text(log, encoding='utf-8')
        log += (runtime / 'runtime.log').read_text(encoding='utf-8', errors='replace')
        if result.returncode or re.search(r'BUG:|runtime error|Bad ref|Bad loc|## ERROR:', log, re.I):
            raise ValueError('Native diagnostics in ' + profile)
        verdict = json.loads((runtime / 'result.json').read_text(encoding='utf-8'))
        verify_result(verdict, profile, commit)
        if verdict['port'] not in (None, 0):
            raise ValueError('CI fixture port not closed')
        results[profile] = verdict
        print('PASS native gather profile ' + profile, flush=True)
    if not results['stock']['ordinary_state'] == results['disabled']['ordinary_state'] == results['enabled_null']['ordinary_state']:
        raise ValueError('Ordinary wait parity mismatch')
    (output / 'ci-result.json').write_text(json.dumps({'commit': commit, 'profiles': list(results),
        'native_headless': 'passed', 'client_acceptance': 'not_run'}, indent=2), encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--expected-commit', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--prepare-only', action='store_true')
    args = parser.parse_args()
    if not args.prepare_only and not args.byond_bin:
        parser.error('--byond-bin required for native execution')
    run(Path(__file__).resolve().parents[2], args.output.resolve(), args.expected_commit,
        args.byond_bin.resolve() if args.byond_bin else None, args.prepare_only)


if __name__ == '__main__':
    main()
