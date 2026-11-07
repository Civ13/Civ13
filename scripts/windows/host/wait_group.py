"""Wait until every region of a group (or one) reaches a state, for deploy.bat.

    py -3 wait_group.py --config group.json --until staged|stopped|compiled|awake|handed-over [--region ID ...] [--timeout SECONDS]

Polls `shard_group.py status` every 15 seconds and prints each change. Exits 0 when
every selected region is there, 1 when a region that is not there yet reports an error
or fails (for stopped: a region still running with no save under way, such as one whose
world refused or failed the save), and 2 on timeout. It never changes anything itself.
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
    if until == 'staged':  # the update is built beside the running world (or it already runs it)
        return (entry.get('stage') or {}).get('phase') in ('ready', 'current')
    if until == 'stopped':
        return not entry.get('listening') and entry.get('state') in ('stopped', 'cold') and not entry.get('busy')
    if until == 'compiled':
        return operation.get('action') == 'update' and phase in ('compiled', 'done') and not entry.get('busy')
    if until == 'handed-over':
        # A region that is not awake has nothing to hand over: the host service installs the
        # staged build when it wakes or starts.
        if entry.get('state') != 'awake':
            return not entry.get('busy')
        return operation.get('action') == 'handover' and phase == 'done' and not entry.get('busy')
    return entry.get('state') == 'awake' and (entry.get('world') or {}).get('ready') == 1 and not entry.get('busy')


def failed(entry, until=None):
    """Why a region that has not reached `until` never will, or None while it still might."""
    if until == 'staged':  # only the stage counts; the world's own last action does not matter here
        stage = entry.get('stage')
        if not stage:
            return 'no build is being staged (see the answer above)'
        if stage.get('phase') == 'failed':
            return stage.get('error') or 'the staged build failed'
        return None
    operation = entry.get('operation') or {}
    if operation.get('error') or operation.get('phase') == 'failed':
        return operation.get('error') or '%s failed' % (operation.get('action') or 'the last action')
    # A stop that was refused (the world was busy or not ready) leaves the region running
    # with no action under way; waiting would only run into the timeout.
    if until == 'stopped' and entry.get('listening') and not entry.get('busy'):
        return 'it is still running and not saving (its stop was refused; see the answer above)'
    if until == 'handed-over' and entry.get('state') == 'awake' and not entry.get('busy') and operation.get('action') != 'handover':
        return 'its handover was refused (see the answer above); it keeps running on the old build'
    return None


def status(config):
    """Every region's status, by region id."""
    command = [sys.executable, '-I', '-B', str(SHARD), '--config', config, 'status']
    no_window = 0x08000000 if os.name == 'nt' else 0  # CREATE_NO_WINDOW
    out = subprocess.run(command, capture_output=True, text=True, timeout=120, creationflags=no_window).stdout
    return json.loads(out)['regions']


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--config', required=True)
    parser.add_argument('--until', required=True, choices=('staged', 'stopped', 'compiled', 'awake', 'handed-over'))
    parser.add_argument('--region', action='append', help='only this region; repeat for several (default: every region)')
    parser.add_argument('--timeout', type=int, default=5400)
    args = parser.parse_args(argv)
    deadline = time.monotonic() + args.timeout
    last = None
    while True:
        try:
            regions = status(args.config)
        except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
            regions, line = None, 'status unavailable: %s' % error
        else:
            if args.region:
                missing = sorted(set(args.region) - set(regions))
                if missing:
                    print('No region %s in the group.' % ', '.join(missing), flush=True)
                    return 1
                regions = {name: regions[name] for name in args.region}
            line = ', '.join('%s %s/%s' % (name, entry.get('state'), (entry.get('operation') or {}).get('phase'))
                             for name, entry in sorted(regions.items()))
        if line != last:
            print(time.strftime('%H:%M:%S'), line, flush=True)
            last = line
        if regions:
            # A region already there counts even after a failed action: a stop whose
            # world was force-stopped mid-save fails its backup but is down, and the
            # start step checks (and restores) the save before anything runs.
            waiting = {name: entry for name, entry in regions.items() if not reached(entry, args.until)}
            if not waiting:
                return 0
            broken = {name: failed(entry, args.until) for name, entry in waiting.items()}
            broken = {name: reason for name, reason in broken.items() if reason}
            if broken:
                for name, reason in sorted(broken.items()):
                    print('%s failed: %s' % (name, reason), flush=True)
                return 1
        if time.monotonic() > deadline:
            print('Timed out waiting for %s.' % args.until, flush=True)
            return 2
        time.sleep(15)


if __name__ == '__main__':
    sys.exit(main())
