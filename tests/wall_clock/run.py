"""Wall-clock jump handling for a frozen and resumed server.

Builds a small fixture from code/_helpers/wall_clock.dm and the midnight
rollover block of code/_helpers/time.dm, then runs it in DreamDaemon.

    python3 tests/wall_clock/run.py --source-check
    python3 tests/wall_clock/run.py --byond-bin "$HOME/byond-516.1688/byond/bin"
    python3 tests/wall_clock/run.py --byond-bin ... --negative-control rollover
    python3 tests/wall_clock/run.py --byond-bin ... --live-freeze 70   # Linux: SIGSTOP the fixture

The live mode suspends the fixture's DreamDaemon with SIGSTOP for the given
seconds, the same way scripts/gaia-host freezes dd.exe, and checks that the
world logs the jump once. DreamDaemon binds only an ephemeral port nobody connects to.
"""
import argparse
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
TIME = 'code/_helpers/time.dm'
CLOCK = 'code/_helpers/wall_clock.dm'
ROLLOVER_START = 'var/midnight_rollovers = 0'
ROLLOVER_END = '\treturn midnight_rollovers\n'
OLD_ROLLOVER = '''var/midnight_rollovers = 0
var/rollovercheck_last_timeofday = 0
var/rollovercheck_last_realtime = 0
#define REALTIMEOFDAY (world.timeofday + (864000 * MIDNIGHT_ROLLOVER_CHECK))
#define MIDNIGHT_ROLLOVER_CHECK ( rollovercheck_last_timeofday != world.timeofday ? update_midnight_rollover() : midnight_rollovers )
/proc/update_midnight_rollover(now_timeofday = world.timeofday, now_realtime = world.realtime)
	if(now_timeofday < rollovercheck_last_timeofday)
		midnight_rollovers++
	rollovercheck_last_timeofday = now_timeofday
	return midnight_rollovers
'''
CONTROLS = {
    'rollover': 'midnight rollover counts only one day per check',
    'shift': 'the autosave deadline is not moved by the freeze',
}


def fixture_source(control=None):
    time_source = (ROOT / TIME).read_text(encoding='utf-8')
    start = time_source.index(ROLLOVER_START)
    end = time_source.index(ROLLOVER_END, start) + len(ROLLOVER_END)
    rollover = time_source[start:end]
    clock = (ROOT / CLOCK).read_text(encoding='utf-8')
    if control == 'rollover':
        rollover = OLD_ROLLOVER
    elif control == 'shift':
        target = '\tif (nextsave)\n\t\tnextsave += gap\n'
        if clock.count(target) != 1:
            raise RuntimeError('mutation target missing: shift')
        clock = clock.replace(target, '', 1)
    probe = (ROOT / 'tests/wall_clock/probe.dm').read_text(encoding='utf-8')
    return rollover + '\n' + clock + '\n' + probe


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--negative-control', choices=CONTROLS)
    parser.add_argument('--live-freeze', type=int, metavar='SECONDS')
    parser.add_argument('--source-check', action='store_true')
    args = parser.parse_args()
    if args.source_check:
        for control in (None, *CONTROLS):
            fixture_source(control)
        print('PASS: fixture sources and mutation targets; no compiler launched')
        return 0
    if not args.byond_bin:
        parser.error('--byond-bin is required for native verification')
    compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    with tempfile.TemporaryDirectory(prefix='wall_clock_') as work:
        work = Path(work)
        (work / 'probe_fixture.dm').write_text(fixture_source(args.negative_control), encoding='utf-8')
        (work / 'probe.dme').write_text('#include "probe_fixture.dm"\n', encoding='utf-8')
        built = subprocess.run([str(compiler), 'probe.dme'], cwd=work, capture_output=True, text=True)
        if '0 errors' not in built.stdout + built.stderr:
            print(built.stdout + built.stderr)
            return 1
        log = work / 'probe.log'
        if args.live_freeze:
            if os.name == 'nt':
                parser.error('--live-freeze uses SIGSTOP and runs on Linux only')
            process = subprocess.Popen([str(daemon), 'probe.dmb', '-trusted', '-invisible', '-params', 'live=1',
                                        '-logself'], cwd=work, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            try:
                time.sleep(5)
                os.kill(process.pid, signal.SIGSTOP)
                time.sleep(args.live_freeze)
                os.kill(process.pid, signal.SIGCONT)
                time.sleep(5)
            finally:
                process.kill()
                process.wait()
            output = log.read_text(encoding='utf-8', errors='replace')
            print(output)
            jumps = output.count('Wall clock ran')
            expected = 1 if args.live_freeze * 10 >= 600 else 0
            print('RESULT: %s (%d jump(s) logged, expected %d)' % ('PASS' if jumps == expected else 'FAIL', jumps, expected))
            return 0 if jumps == expected else 1
        result = subprocess.run([str(daemon), 'probe.dmb', '-trusted', '-invisible', '-logself'], cwd=work,
                                capture_output=True, text=True, timeout=120)
        output = log.read_text(encoding='utf-8', errors='replace') if log.exists() else result.stdout + result.stderr
        print(output)
        passed = 'RESULT: PASS' in output and 'runtime error' not in output.lower()
        if args.negative_control:
            print('NEGATIVE CONTROL %s: %s' % (args.negative_control, 'caught' if not passed else 'NOT caught'))
            return 0 if not passed else 1
        return 0 if passed else 1


if __name__ == '__main__':
    sys.exit(main())
