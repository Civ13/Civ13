"""Run every native BYOND test runner on the pinned compiler and report which fail.

Most tests/**/run*.py fixtures compile and boot a small world with DreamMaker and
DreamDaemon. They are not part of the offline CI suites, so they can break unseen
when production code moves. This sweep runs each one with --byond-bin (plus any
arguments from tests/native_sweep/manifest.json). Runners listed under "skip" need a
mode or input the sweep cannot give (Windows only, a packet, a live bot). Runners under
"known_failing" still run and are reported; the sweep fails when any other runner
fails, so a newly broken runner is caught, and it names known failures that now pass
so they can come off the list.

    python3 scripts/native_runner_sweep.py --byond-bin "$BYOND_HOME/byond/bin" [--jobs 3] [--only name ...]
"""
import argparse
import concurrent.futures
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'tests/native_sweep/manifest.json'
TAIL = 4000


def discover():
    """Runner scripts that take --byond-bin, as repository-relative posix paths."""
    found = []
    for path in sorted((ROOT / 'tests').glob('*/*.py')):
        name = path.name
        if not (name.startswith('run') or 'native' in name) or name.startswith('test_'):
            continue
        text = path.read_text(encoding='utf-8', errors='replace')
        if "'--byond-bin'" in text or '"--byond-bin"' in text:
            found.append(path.relative_to(ROOT).as_posix())
    return found


def load_manifest():
    data = json.loads(MANIFEST.read_text(encoding='utf-8'))
    for key in ('runners', 'skip', 'known_failing'):
        if not isinstance(data.get(key), dict):
            raise SystemExit(f'{MANIFEST}: "{key}" must be an object')
    return data


def standard_args(runner, extra, scratch):
    """Fill the arguments most runners share: a fresh output or evidence folder, the pinned archive."""
    text = (ROOT / runner).read_text(encoding='utf-8', errors='replace')
    args = []
    for flag in ('--output', '--evidence-dir'):
        if flag not in extra and re.search(r"add_argument\(\s*['\"]" + flag + r"['\"]", text):
            # A fresh path that does not exist yet: some runners refuse an existing folder.
            folder = Path(scratch) / f'{Path(runner).parent.name}-{Path(runner).stem}-{uuid.uuid4().hex[:8]}'
            args += [flag, str(folder)]
    archive = os.environ.get('BYOND_ARCHIVE')
    if archive and '--byond-archive' not in extra and "'--byond-archive'" in text:
        args += ['--byond-archive', archive]
    return args


def run_one(runner, byond_bin, settings, scratch):
    extra = settings.get('args', [])
    args = [sys.executable, '-B', runner, '--byond-bin', str(byond_bin), *standard_args(runner, extra, scratch), *extra]
    timeout = settings.get('timeout', 600)
    started = time.monotonic()
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE='1')
    try:
        result = subprocess.run(args, cwd=ROOT, capture_output=True, text=True, errors='replace',
                                timeout=timeout, env=env)
        status = 'pass' if result.returncode == 0 else 'fail'
        output = result.stdout + result.stderr
    except subprocess.TimeoutExpired as error:
        status = 'timeout'
        output = (error.stdout or '') if isinstance(error.stdout, str) else ''
    return {'runner': runner, 'status': status, 'seconds': round(time.monotonic() - started, 1),
            'tail': output[-TAIL:]}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--jobs', type=int, default=1)
    parser.add_argument('--only', nargs='*', help='run only runners whose path contains one of these')
    parser.add_argument('--output', type=Path, help='write the full JSON report here')
    parser.add_argument('--list', action='store_true', help='list runners and their settings, run nothing')
    args = parser.parse_args()
    manifest = load_manifest()
    runners = discover()
    stale = sorted(set(manifest['runners']).union(manifest['skip'], manifest['known_failing']) - set(runners))
    if stale:
        raise SystemExit('Manifest names runners that no longer exist: ' + ', '.join(stale))
    if args.only:
        runners = [r for r in runners if any(part in r for part in args.only)]
    if args.list:
        for runner in runners:
            print(runner, json.dumps(manifest['skip'].get(runner) or manifest['runners'].get(runner, {})))
        return 0
    todo = [r for r in runners if r not in manifest['skip']]
    results = []
    scratch = tempfile.mkdtemp(prefix='civ13-native-sweep-')
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, args.jobs)) as pool:
        futures = {pool.submit(run_one, r, args.byond_bin.resolve(), manifest['runners'].get(r, {}), scratch): r for r in todo}
        for future in concurrent.futures.as_completed(futures):
            result = future.result()
            results.append(result)
            print(f"{result['status']:7} {result['seconds']:7.1f}s {result['runner']}", flush=True)
    results.sort(key=lambda r: r['runner'])
    known = manifest['known_failing']
    failed = [r for r in results if r['status'] != 'pass']
    new = [r for r in failed if r['runner'] not in known]
    still_known = [r for r in failed if r['runner'] in known]
    fixed = [r['runner'] for r in results if r['status'] == 'pass' and r['runner'] in known]
    skipped = [{'runner': r, 'reason': manifest['skip'][r]} for r in runners if r in manifest['skip']]
    report = {'byond_bin': str(args.byond_bin), 'ran': len(results), 'passed': len(results) - len(failed),
              'new_failures': [r['runner'] for r in new], 'known_failures': [r['runner'] for r in still_known],
              'known_now_passing': fixed, 'skipped': skipped, 'results': results}
    if args.output:
        args.output.write_text(json.dumps(report, indent=1), encoding='utf-8')
    lines = [f"Native runner sweep: {report['passed']}/{report['ran']} passed, {len(new)} new failures, "
             f"{len(still_known)} known failures, {len(skipped)} skipped."]
    if fixed:
        lines += ['', 'Known failures that now pass (remove them from known_failing): ' + ', '.join(fixed)]
    for r in new:
        lines += ['', f"NEW FAILURE ({r['status']}, {r['seconds']} s): {r['runner']}", '```',
                  re.sub(r'```', "'''", r['tail'][-1500:]).rstrip(), '```']
    if still_known:
        lines += ['', 'Known failures: ' + ', '.join(f"{r['runner']} ({known[r['runner']]})" for r in still_known)]
    summary = '\n'.join(lines)
    print('\n' + summary)
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as handle:
            handle.write(summary + '\n')
    return 1 if new else 0


if __name__ == '__main__':
    sys.exit(main())
