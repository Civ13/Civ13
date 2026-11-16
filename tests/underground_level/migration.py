"""Migration of an old save to the unformed compiled underground, on a real map.

  seed      the build from before the change (--old-rev, a git worktree) boots
            fresh, leaves a body, a loose item, a crate with an item inside and
            a ladder pair on the old filled cave level (z 1), and saves
  migrate   the current tree's build restores that save with
            -params migrate_underground=1 (underground_migration.dm)
  validate  the same copy with -params validate_save=1 (the outside validator)
  verify    a fresh copy of the migrated save: the old level is unformed rock
            with nothing on it, and the seeded things are on the surface

  source <byond>/bin/byondsetup
  python3 -B tests/underground_level/migration.py --byond-bin <byond>/bin \\
      --old-rev f4ee824 --map maps/nomads/nomads_desert.dmm --output <fresh dir>
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests' / 'zone_persistence'))
import real_map as zone  # noqa: E402


def plain_run(byond, case, params, deadline):
    """DreamDaemon until the world ends; for runs that write no result.json."""
    env = dict(os.environ, HOME=str(case), LD_LIBRARY_PATH=str(byond) + ':' + str(case))
    command = [str(byond / 'DreamDaemon'), 'probe.dmb', '0', '-trusted', '-invisible', '-params', params,
               '-log', params.split('=')[0] + '.log']
    started = time.monotonic()
    with (case / (params.split('=')[0] + '.out')).open('w') as out:
        process = subprocess.run(command, cwd=case, stdin=subprocess.DEVNULL, stdout=out, stderr=subprocess.STDOUT,
                                 env=env, timeout=deadline)
    return {'exit': process.returncode, 'wall_seconds': round(time.monotonic() - started)}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--old-rev', required=True, help='a commit from before the compiled levels became unformed')
    parser.add_argument('--map', default='maps/nomads/nomads_desert.dmm')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--deadline', type=int, default=3600)
    args = parser.parse_args()
    byond = args.byond_bin.resolve(strict=True)
    output = args.output.resolve()
    zone.need(not output.exists() or not any(output.iterdir()), 'The output directory must be fresh')
    (output / 'old').mkdir(parents=True)
    (output / 'new').mkdir()
    summary = {'map': args.map, 'old_rev': args.old_rev, 'failures': []}

    def record():
        (output / 'summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')

    worktree = output / 'old-tree'
    subprocess.run(['git', '-C', str(ROOT), 'worktree', 'add', '--detach', str(worktree), args.old_rev], check=True,
                   capture_output=True)
    try:
        shutil.copy2(ROOT / 'tests/underground_level/migration_seed_probe.dm', worktree / 'migration_seed_probe.dm')
        zone.ROOT, zone.PROBE = worktree, 'migration_seed_probe.dm'
        zone.compile_probe(byond, args.map, output / 'old')
        seed = zone.stage(output / 'old', 'seed', None)
    finally:
        zone.ROOT = ROOT
        subprocess.run(['git', '-C', str(ROOT), 'worktree', 'remove', '--force', str(worktree)], capture_output=True)
    outcome = zone.run(byond, seed, {}, args.deadline)
    summary['seed'] = {'result': outcome['result'], 'wall_seconds': outcome['wall_seconds'],
                       'runtime_errors': outcome['runtime_errors']}
    record()
    zone.need(outcome['result'].get('passed'), 'seed failed: %s' % outcome['result'].get('failure'))
    cells = '_'.join(outcome['result']['cells'])

    zone.PROBE = 'tests/underground_level/migration_verify_probe.dm'
    zone.compile_probe(byond, args.map, output / 'new')
    case = zone.stage(output / 'new', 'migrate', None, seed / 'map_saves')
    summary['migrate'] = plain_run(byond, case, 'migrate_underground=1', args.deadline)
    report = json.loads((case / 'underground_migration.json').read_text(encoding='utf-8')) \
        if (case / 'underground_migration.json').is_file() else {}
    summary['migrate']['report'] = report
    record()
    zone.need(report.get('ok'), 'migration failed: %s' % report.get('error'))
    lifted = report['lifted']
    if lifted['bodies'] < 1 or lifted['items'] < 1 or lifted['crates'] < 1 or report['surface_ladders_removed'] < 1:
        summary['failures'].append('migrate: expected a body, an item, a crate and a surface ladder: %s' % lifted)

    summary['validate'] = plain_run(byond, case, 'validate_save=1', args.deadline)
    validation = json.loads((case / 'validation_result.json').read_text(encoding='utf-8')) \
        if (case / 'validation_result.json').is_file() else {}
    summary['validate']['result'] = validation
    if not validation.get('ok') or not validation.get('full'):
        summary['failures'].append('validate: %s' % (validation.get('error') or 'no full result'))
    record()

    check = zone.stage(output / 'new', 'verify', None, case / 'map_saves')
    outcome = zone.run(byond, check, {'migration_probe': 'verify', 'cells': cells}, args.deadline)
    summary['verify'] = {'result': outcome['result'], 'wall_seconds': outcome['wall_seconds'],
                         'runtime_errors': outcome['runtime_errors']}
    if not outcome['result'].get('passed'):
        summary['failures'].append('verify: %s' % (outcome['result'].get('failure') or outcome['result'].get('failed_checks')))
    record()
    print('FAILURES: ' + '; '.join(summary['failures']) if summary['failures'] else 'PASS: underground migration')
    return 1 if summary['failures'] else 0


if __name__ == '__main__':
    sys.exit(main())
