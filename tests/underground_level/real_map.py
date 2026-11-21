"""Unformed underground level on a real dig-down map.

Compiles a temporary copy of civ13.dme with one production map selected and
tests/underground_level/real_map_probe.dm appended (the zone runner's build and
staging helpers), then runs two fresh DreamDaemon processes:

  write   a fresh world: the cave level is added at boot as unformed rock (or
          is the map's compiled one), a shaft and a 24-cell tunnel are dug,
          --deep levels are dug under it, --storeys open-air levels are
          grown, and the world is saved
  read    a copy of that save: the startup restore, the formed cells and
          lighting are checked, and the world is saved again

  source <byond>/bin/byondsetup
  python3 -B tests/underground_level/real_map.py --byond-bin <byond>/bin \\
      --map maps/nomads/nomads_europe.dmm --output <fresh dir>
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests' / 'zone_persistence'))
import real_map as zone  # noqa: E402

zone.PROBE = 'tests/underground_level/real_map_probe.dm'


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--map', default='maps/nomads/nomads_europe.dmm')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--deadline', type=int, default=3600)
    parser.add_argument('--storeys', type=int, default=0, help='grow this many open-air levels before saving')
    parser.add_argument('--deep', type=int, default=0, help='dig shafts down to this underground depth before saving')
    args = parser.parse_args()
    byond = args.byond_bin.resolve(strict=True)
    output = args.output.resolve()
    zone.need(not output.exists() or not any(output.iterdir()), 'The output directory must be fresh')
    output.mkdir(parents=True, exist_ok=True)
    summary = {'map': args.map, 'head': subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip(),
               'working_tree_changes': subprocess.check_output(['git', '-C', str(ROOT), 'status', '--porcelain'], text=True).splitlines(),
               'failures': []}
    summary['compiler'] = zone.compile_probe(byond, args.map, output)

    def finish(name, outcome):
        result = outcome['result']
        summary[name] = {key: outcome[key] for key in ('phases', 'peak_mib', 'wall_seconds', 'runtime_errors', 'phase_lines', 'loop_warnings')}
        summary[name]['result'] = {key: value for key, value in result.items() if key != 'checks'}
        if not result.get('passed'):
            summary['failures'].append(f"{name}: {result.get('failure') or result.get('failed_checks')}")
        if outcome['runtime_errors']:
            summary['failures'].append(f"{name}: {sum(outcome['runtime_errors'].values())} runtime errors")
        (output / 'summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
        print(f"{'PASS' if result.get('passed') else 'FAIL'} {name}: {len(result.get('checks', []))} checks, "
              f"{outcome['wall_seconds']} s, peak {outcome['peak_mib']} MiB", flush=True)
        return result

    write = zone.stage(output, 'write', None)
    result = finish('write', zone.run(byond, write, {'real_mode': 'write', 'storeys': args.storeys, 'deep': args.deep}, args.deadline))
    saves = write / 'map_saves'
    if result.get('passed') and (saves / 'save_complete.txt').is_file():
        summary['save_files'] = {p.name: p.stat().st_size for p in sorted(saves.iterdir()) if p.is_file()}
        read = zone.stage(output, 'read', None, saves)
        finish('read', zone.run(byond, read, {'real_mode': 'read', 'formed': result['dug']['formed'], 'maxz': result['maxz'],
                                                      'deep': args.deep, 'deep_formed': '-'.join(f'{k}.{v}' for k, v in result.get('deep', {}).items())}, args.deadline))
    (output / 'summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    print('FAILURES: ' + '; '.join(summary['failures']) if summary['failures'] else 'PASS: underground real-map write and read')
    return 1 if summary['failures'] else 0


if __name__ == '__main__':
    sys.exit(main())
