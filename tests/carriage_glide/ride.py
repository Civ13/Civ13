"""Headless full-game carriage ride regression for #3627 (native, not run by CI).

Appends tests/carriage_glide/ride_probe.dm to a temporary copy of civ13.dme,
compiles it with the pinned DreamMaker and runs it once in DreamDaemon from a
fresh output directory (local address only, no client). Passes when every
driven leg at each reins gear gives the driver, both horses and the carriage
the same glide_size, and dismounting restores the driver's own glide.

    python3 tests/carriage_glide/ride.py --byond-bin ~/byond-516.1688/byond/bin
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import uuid


def git(repo, *args):
    return subprocess.check_output(['git', '-C', str(repo), *args], text=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--deadline', type=int, default=1200)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[2]
    output = (args.output or Path(tempfile.gettempdir()) / ('civ13-carriage-ride-' + uuid.uuid4().hex)).resolve()
    if output.exists() and any(output.iterdir()):
        raise SystemExit('Output directory must be fresh')
    output.mkdir(parents=True, exist_ok=True)
    prefix = '.carriage_ride_' + uuid.uuid4().hex
    source = repo / (prefix + '.dme')
    created = [source] + [source.with_suffix(ext) for ext in ('.dmb', '.rsc', '.int')]
    try:
        dme = (repo / 'civ13.dme').read_text(encoding='utf-8-sig')
        source.write_text(dme + '\n#include "tests\\carriage_glide\\ride_probe.dm"\n', encoding='utf-8')
        build = subprocess.run([str(args.byond_bin / 'DreamMaker'), '-max_errors', '0', source.name],
                               cwd=repo, capture_output=True, text=True, timeout=600)
        log = build.stdout + build.stderr
        (output / 'compile.log').write_text(log, encoding='utf-8')
        if build.returncode or '0 errors, 0 warnings' not in log:
            raise SystemExit('Compilation failed; see ' + str(output / 'compile.log'))
        shutil.copy2(source.with_suffix('.dmb'), output / 'probe.dmb')
        shutil.copy2(source.with_suffix('.rsc'), output / 'probe.rsc')
        for path in git(repo, 'ls-files', '--', 'config').splitlines():
            dest = output / path
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(repo / path, dest)
        command = [str(args.byond_bin / 'DreamDaemon'), 'probe.dmb', '-trusted', '-ip', '127.0.0.1', '-log', 'daemon.log']
        with (output / 'stdout.log').open('w') as out:
            subprocess.run(command, cwd=output, stdout=out, stderr=subprocess.STDOUT, timeout=args.deadline)
    finally:
        for path in created:
            if path.exists():
                path.unlink()
    result_path = output / 'result.json'
    if not result_path.exists():
        raise SystemExit('No result.json; see ' + str(output))
    result = json.loads(result_path.read_text())
    summary = {'passed': bool(result.get('passed')), 'failure': result.get('failure'),
               'legs': result.get('notes', {}).get('legs'), 'tested_commit': git(repo, 'rev-parse', 'HEAD').strip(),
               'output': str(output)}
    print(json.dumps(summary, indent=2))
    if not summary['passed']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
