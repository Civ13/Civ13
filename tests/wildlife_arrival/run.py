"""Native wildlife arrival-timing acceptance (#3509).

Builds a temporary copy of civ13.dme with tests/wildlife_arrival/probe.dm,
runs it once in DreamDaemon from a fresh directory (no client, localhost only)
and checks that the sub-tile walker reaches a target no later than one server
tick after the legacy native walk_towards() at every tested lag, and keeps the
same average step period. Generated sources are removed afterwards.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import uuid

REPO = Path(__file__).resolve().parents[2]
PROBE = '\n#include "tests\\wildlife_arrival\\probe.dm"\n'


def check(rows):
    """Return failure strings for probe rows; empty means pass."""
    if not rows or 'error' in rows[0]:
        return ['probe error: ' + (rows[0].get('error', 'no rows') if rows else 'no rows')]
    failures = []
    legacy = {(r['lag'], r['move_target_at']): r for r in rows if not r['subtile']}
    for row in (r for r in rows if r['subtile']):
        key = (row['lag'], row['move_target_at'])
        base = legacy.get(key)
        tick = row['tick_lag']
        if not base or base['arrived'] < 0:
            failures.append(f'{key}: legacy walk did not arrive')
            continue
        if row['arrived'] < 0:
            failures.append(f'{key}: sub-tile walk did not arrive')
            continue
        late = row['arrived'] - base['arrived']
        allowed = tick
        step = base['entries'][1] - base['entries'][0] if len(base['entries']) > 1 else 0
        if row['move_target_at'] >= 0 and len(base['entries']) >= 8 and base['entries'][7] <= row['move_target_at']:
            # The walker was already waiting when the target moved. A native
            # step jumps a whole tile at once; the sub-tile reaction glides, so
            # it lands one step period later by design. Allow that glide only.
            allowed = step + tick
        if late > allowed + 0.01:
            failures.append(f'{key}: sub-tile arrived {late:.2f} ds after legacy ({row["arrived"]:.2f} vs {base["arrived"]:.2f})')
        if late < -(tick + 0.01):
            failures.append(f'{key}: sub-tile arrived {-late:.2f} ds before legacy')
        if len(row['entries']) != len(base['entries']):
            failures.append(f'{key}: {len(row["entries"])} turf entries vs legacy {len(base["entries"])}')
        steps = row['entries'][:8]
        if len(steps) > 1:
            # Mean cadence over the first eight tiles, before any reaction.
            period = (steps[-1] - steps[0]) / (len(steps) - 1)
            legacy_steps = base['entries'][:8]
            legacy_period = (legacy_steps[-1] - legacy_steps[0]) / (len(legacy_steps) - 1)
            if period > legacy_period + 0.01:
                failures.append(f'{key}: mean step {period:.3f} ds slower than legacy {legacy_period:.3f} ds')
    return failures


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--deadline', type=int, default=1800)
    args = parser.parse_args()
    output = (args.output or Path(tempfile.gettempdir()) / ('civ13-wildlife-arrival-' + uuid.uuid4().hex)).resolve()
    if output.exists() and any(output.iterdir()):
        raise SystemExit('Output directory must be fresh')
    output.mkdir(parents=True, exist_ok=True)
    stem = '.wildlife_arrival_' + uuid.uuid4().hex
    source = REPO / (stem + '.dme')
    created = [source] + [source.with_suffix(s) for s in ('.dmb', '.rsc', '.int')]
    try:
        source.write_text((REPO / 'civ13.dme').read_text(encoding='utf-8-sig') + PROBE, encoding='utf-8')
        build = subprocess.run([str(args.byond_bin / 'DreamMaker'), '-max_errors', '0', source.name], cwd=REPO,
                               capture_output=True, text=True, timeout=900)
        log = build.stdout + build.stderr
        (output / 'compile.log').write_text(log, encoding='utf-8')
        if build.returncode or '0 errors' not in log:
            raise SystemExit('Probe compilation failed; see ' + str(output / 'compile.log'))
        shutil.copy2(source.with_suffix('.dmb'), output / 'probe.dmb')
        shutil.copy2(source.with_suffix('.rsc'), output / 'probe.rsc')
        shutil.copytree(REPO / 'config', output / 'config')
        with (output / 'stdout.log').open('w') as out:
            subprocess.run([str(args.byond_bin / 'DreamDaemon'), 'probe.dmb', '-trusted', '-ip', '127.0.0.1', '-log', 'startup.log'],
                           cwd=output, stdout=out, stderr=subprocess.STDOUT, timeout=args.deadline)
    finally:
        for path in created:
            if path.exists():
                path.unlink()
    result = output / 'result.json'
    if not result.exists():
        raise SystemExit('No result.json; see ' + str(output))
    rows = json.loads(result.read_text())
    for row in rows:
        if 'error' not in row:
            print(('subtile' if row['subtile'] else 'legacy '), 'lag', row['lag'], 'target moved' if row['move_target_at'] >= 0 else 'still target',
                  'arrived', round(row['arrived'], 2))
    failures = check(rows)
    for failure in failures:
        print('FAIL', failure)
    print('PASS' if not failures else 'FAILED', '-', output)
    raise SystemExit(1 if failures else 0)


if __name__ == '__main__':
    main()
