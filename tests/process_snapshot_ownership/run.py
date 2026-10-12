"""Native production ownership checks with an immutable pre-fix control."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile

BASELINE = 'f556e39b93fc97f41020b2d8c5f2abed63fab497'
SUITE = 'process_snapshot_ownership'
SOURCE = 'code/processes/_process.dm'
PATTERNS = [r'/process/proc/finished\([^\n]*\)[\s\S]*?(?=/process/proc/fire\(\))', r'/process/proc/fire_as_member\(\)[\s\S]*?(?=/process/proc/setup\(\))', r'/process/proc/process\(\)[\s\S]*?(?=/process/proc/running\(\))']
EXPECTED_FAILURES = set(['copied snapshot and iterator released', 'aliased snapshot and iterator released'])
parser = argparse.ArgumentParser()
parser.add_argument('--byond-bin', required=True, type=Path)
parser.add_argument('--baseline', action='store_true')
parser.add_argument('--negative-control', action='store_true')
parser.add_argument('--reset-control', action='store_true')
parser.add_argument('--evidence-dir', type=Path)
args = parser.parse_args()
repo = Path(__file__).resolve().parents[2]
source = (repo / SOURCE).read_text()
if args.baseline:
    source = subprocess.run(['git', 'show', BASELINE + ':' + SOURCE], cwd=repo,
                            check=True, capture_output=True, text=True).stdout
raw_source = source
scheduler_path = 'code/processes/__processScheduler.dm'
scheduler = subprocess.check_output(['git','show',BASELINE+':'+scheduler_path], cwd=repo, text=True) if args.baseline else (repo/scheduler_path).read_text()
if sum((args.baseline,args.negative_control,args.reset_control)) > 1:
    raise SystemExit('Do not combine baseline and negative control')
source = '\n'.join(re.search(pattern, source).group() for pattern in PATTERNS)
for pattern in (r'/processScheduler/proc/relayProcess\([^\n]*\)[\s\S]*?(?=/processScheduler/proc/addProcess\()', r'/processScheduler/proc/start\(\)[\s\S]*?(?=/processScheduler/proc/process\()', r'/processScheduler/proc/runQueuedProcesses\(\)[\s\S]*?(?=/processScheduler/proc/relayProcess\()'):
    source += '\n' + re.search(pattern,scheduler).group()
reset_path = 'code/processes/mob.dm'
reset_source = subprocess.check_output(['git','show',BASELINE+':'+reset_path],cwd=repo,text=True) if args.baseline else (repo/reset_path).read_text()
reset = re.search(r'/process/mob/reset_current_list\(\)[\s\S]*?(?=/process/mob/statProcess)',reset_source).group()
source += '\n' + reset.replace('\n\tPROCESS_USE_FASTEST_LIST', '\n\tresets++\n\tPROCESS_USE_FASTEST_LIST')
defines_path = 'code/processes/___defines.dm'
defines = subprocess.check_output(['git','show',BASELINE+':'+defines_path],cwd=repo,text=True) if args.baseline else (repo/defines_path).read_text()

if args.baseline:
    source = '#define BASELINE_CONTROL\n' + source
if args.negative_control:
    source = '#define UNCONDITIONAL_CLEAR_CONTROL\n' + source
if args.negative_control:
    anchor = 'if (fire_result != PROCESS_TICK_CHECK_RETURNED_EARLY)'
    if source.count(anchor) != 1:
        raise SystemExit('Negative control anchor changed')
    source = source.replace(anchor, 'if (TRUE)')
    EXPECTED_FAILURES = {'budgeted snapshot retained for next pass', 'member snapshot retained for next pass'}
if args.reset_control:
    anchor = '\t\tif (p)\n\t\t\tqueue -= p'
    if source.count(anchor) != 1:
        raise SystemExit('Repopulation control anchor changed')
    source = source.replace(anchor, '\t\tif (p)\n\t\t\tp.reset_current_list()\n\t\t\tqueue -= p')
    EXPECTED_FAILURES = {'copied snapshot and iterator released'}
probe = Path(__file__).with_name('probe.dm').read_text()
head = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=repo, check=True,
                      capture_output=True, text=True).stdout.strip()
dirty = subprocess.run(['git', 'status', '--porcelain'], cwd=repo, check=True,
                       capture_output=True, text=True).stdout
with tempfile.TemporaryDirectory(prefix='civ13-' + SUITE + '-') as directory:
    temp = Path(directory)
    (temp / 'production.dm').write_text(source)
    if args.baseline:
        probe = '#define BASELINE_CONTROL\n' + probe
    elif args.negative_control:
        probe = '#define UNCONDITIONAL_CLEAR_CONTROL\n' + probe
    elif args.reset_control:
        probe = '#define RESET_REPOPULATION_CONTROL\n' + probe
    (temp / 'probe.dm').write_text(probe)
    (temp / 'defines.dm').write_text(defines)
    (temp / 'probe.dme').write_text('#include "defines.dm"\n#include "probe.dm"\n#include "production.dm"\n')
    win = (args.byond_bin / 'dm.exe').exists()
    compiler = args.byond_bin / ('dm.exe' if win else 'DreamMaker')
    daemon = args.byond_bin / ('dd.exe' if win else 'DreamDaemon')
    result = subprocess.run([str(compiler), 'probe.dme'], cwd=temp, capture_output=True,
                            text=True, timeout=60)
    print(result.stdout, end='')
    if result.returncode or 'DM compiler version 516.1681' not in result.stdout or '0 errors, 0 warnings' not in result.stdout:
        raise SystemExit('Fixture compilation failed: ' + result.stderr)
    process = subprocess.run([str(daemon), 'probe.dmb', '-invisible', '-safe', '-log', 'runtime.log'],
                             cwd=temp, capture_output=True, timeout=20)
    log = (temp / 'runtime.log').read_text()
    print(log, end='')
    actual_failures = set(re.findall(r'^FAIL (.+)$', log, re.M))
    engine_error = bool(re.search(r'runtime error|bad ref|bad loc|assertion failed', log, re.I))
    pass_marker = 'PASS ' + SUITE.replace('_', ' ')
    success = not process.returncode and not engine_error
    if args.baseline or args.negative_control or args.reset_control:
        success = success and actual_failures == EXPECTED_FAILURES and pass_marker not in log
    else:
        success = success and not actual_failures and pass_marker in log
    if args.evidence_dir:
        destination = args.evidence_dir / (SUITE + ('-baseline' if args.baseline else '-unconditional-clear' if args.negative_control else '-reset-repopulation' if args.reset_control else '-fixed'))
        destination.mkdir(parents=True, exist_ok=True)
        (destination / 'compile.log').write_text(result.stdout + result.stderr)
        (destination / 'runtime.log').write_text(log)
        (destination / 'production.dm').write_text(source)
        (destination / 'source.dm').write_text(raw_source)
        (destination / 'scheduler.dm').write_text(scheduler)
        (destination / 'reset_source.dm').write_text(reset_source)
        (destination / 'defines.dm').write_text(defines)
        (destination / 'probe.dm').write_text(probe)
        (destination / 'result.json').write_text(json.dumps({
            'suite': SUITE, 'baseline': args.baseline, 'negative_control': args.negative_control, 'reset_control':args.reset_control, 'source_commit': BASELINE if args.baseline else head,
            'working_tree_dirty': bool(dirty) if not args.baseline else False, 'checkout_status': dirty,
            'source_sha256': hashlib.sha256(raw_source.encode()).hexdigest(),
            'scheduler_sha256': hashlib.sha256(scheduler.encode()).hexdigest(),
            'reset_source_sha256':hashlib.sha256(reset_source.encode()).hexdigest(),
            'defines_sha256':hashlib.sha256(defines.encode()).hexdigest(),
            'adapted_source_sha256': hashlib.sha256(source.encode()).hexdigest(),
            'fixture_sha256': hashlib.sha256(probe.encode()).hexdigest(),
            'byond_version': '516.1681', 'passed': bool(success),
            'expected_baseline_failures': sorted(EXPECTED_FAILURES) if args.baseline or args.negative_control or args.reset_control else [],
            'observed_failures': sorted(actual_failures), 'runtime_error': engine_error,
        }, indent=2) + '\n')
    if not success:
        raise SystemExit('Ownership regression or baseline control failed')
    if args.baseline:
        print('PASS baseline control: exact historical ownership failures detected')
    elif args.negative_control:
        print('PASS negative control: exact unconditional-clear continuation failures detected')





    if args.reset_control:
        print('PASS reset control: exact post-completion snapshot repopulation failure detected')
