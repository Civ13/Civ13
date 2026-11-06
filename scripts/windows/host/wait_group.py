"""Wait until every region of a group (or one) reaches a state, for deploy.bat.

    py -3 wait_group.py --config group.json --until stopped|compiled|awake [--region ID] [--timeout SECONDS]

Polls `shard_group.py status` every 15 seconds and prints each change. Exits 0 when
every selected region is there, 1 when an operation reports an error or fails, and
2 on timeout. It never changes anything itself.
"""
import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

SHARD = Path(__file__).resolve().parents[2] / 'shard-group' / 'shard_group.py'


def reached(entry, until):
    operation = entry.get('operation') or {}
    phase = operation.get('phase')
    if until == 'stopped':
        return not entry.get('listening') and entry.get('state') in ('stopped', 'cold') and not entry.get('busy')
    if until == 'compiled':
        return operation.get('action') == 'update' and phase in ('compiled', 'done') and not entry.get('busy')
    return entry.get('state') == 'awake' and (entry.get('world') or {}).get('ready') == 1 and not entry.get('busy')


def failed(entry):
    operation = entry.get('operation') or {}
    return bool(operation.get('error')) or operation.get('phase') == 'failed'


def status(config, region):
    command = [sys.executable, '-I', '-B', str(SHARD), '--config', config, 'status']
    if region:
        command += ['--region', region]
    no_window = 0x08000000 if os.name == 'nt' else 0  # CREATE_NO_WINDOW
    out = subprocess.run(command, capture_output=True, text=True, timeout=120, creationflags=no_window).stdout
    return json.loads(out)['regions']


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--config', required=True)
    parser.add_argument('--until', required=True, choices=('stopped', 'compiled', 'awake'))
    parser.add_argument('--region')
    parser.add_argument('--timeout', type=int, default=5400)
    args = parser.parse_args(argv)
    deadline = time.monotonic() + args.timeout
    last = None
    while True:
        try:
            regions = status(args.config, args.region)
        except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
            regions, line = None, 'status unavailable: %s' % error
        else:
            line = ', '.join('%s %s/%s' % (name, entry.get('state'), (entry.get('operation') or {}).get('phase'))
                             for name, entry in sorted(regions.items()))
        if line != last:
            print(time.strftime('%H:%M:%S'), line, flush=True)
            last = line
        if regions:
            broken = [name for name, entry in regions.items() if failed(entry)]
            if broken:
                for name in broken:
                    print('%s failed: %s' % (name, regions[name]['operation'].get('error')), flush=True)
                return 1
            if all(reached(entry, args.until) for entry in regions.values()):
                return 0
        if time.monotonic() > deadline:
            print('Timed out waiting for %s.' % args.until, flush=True)
            return 2
        time.sleep(15)


if __name__ == '__main__':
    sys.exit(main())
