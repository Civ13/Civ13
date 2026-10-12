"""Native production ownership checks with an immutable pre-fix control."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile

BASELINE = 'f556e39b93fc97f41020b2d8c5f2abed63fab497'
SUITE = 'weakref_ownership'
SOURCE = 'code/datums/weakref.dm'
PATTERNS = []
EXPECTED_FAILURES = set(['nonforced disposal preserves target'])
parser = argparse.ArgumentParser()
parser.add_argument('--byond-bin', required=True, type=Path)
parser.add_argument('--baseline', action='store_true')
parser.add_argument('--evidence-dir', type=Path)
args = parser.parse_args()
repo = Path(__file__).resolve().parents[2]
source = (repo / SOURCE).read_text()
if args.baseline:
    source = subprocess.run(['git', 'show', BASELINE + ':' + SOURCE], cwd=repo,
                            check=True, capture_output=True, text=True).stdout
if PATTERNS:
    source = '\n'.join(re.search(pattern, source).group() for pattern in PATTERNS)
probe = Path(__file__).with_name('probe.dm').read_text()
head = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=repo, check=True,
                      capture_output=True, text=True).stdout.strip()
dirty = subprocess.run(['git', 'status', '--porcelain'], cwd=repo, check=True,
                       capture_output=True, text=True).stdout
with tempfile.TemporaryDirectory(prefix='civ13-' + SUITE + '-') as directory:
    temp = Path(directory)
    (temp / 'production.dm').write_text(source)
    (temp / 'probe.dm').write_text(probe)
    (temp / 'probe.dme').write_text('#include "probe.dm"\n#include "production.dm"\n')
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
    if args.baseline:
        success = success and actual_failures == EXPECTED_FAILURES and pass_marker not in log
    else:
        success = success and not actual_failures and pass_marker in log
    if args.evidence_dir:
        destination = args.evidence_dir / (SUITE + ('-baseline' if args.baseline else '-fixed'))
        destination.mkdir(parents=True, exist_ok=True)
        (destination / 'compile.log').write_text(result.stdout + result.stderr)
        (destination / 'runtime.log').write_text(log)
        (destination / 'production.dm').write_text(source)
        (destination / 'probe.dm').write_text(probe)
        (destination / 'result.json').write_text(json.dumps({
            'suite': SUITE, 'baseline': args.baseline, 'source_commit': BASELINE if args.baseline else head,
            'working_tree_dirty': bool(dirty) if not args.baseline else False,
            'source_sha256': hashlib.sha256(source.encode()).hexdigest(),
            'fixture_sha256': hashlib.sha256(probe.encode()).hexdigest(),
            'byond_version': '516.1681', 'passed': bool(success),
            'expected_baseline_failures': sorted(EXPECTED_FAILURES) if args.baseline else [],
            'observed_failures': sorted(actual_failures), 'runtime_error': engine_error,
        }, indent=2) + '\n')
    if not success:
        raise SystemExit('Ownership regression or baseline control failed')
    if args.baseline:
        print('PASS baseline control: expected ownership failures detected; production baseline remains defective')