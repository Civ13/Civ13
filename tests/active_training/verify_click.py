"""Validate retained ClickFeedback receipts offline; never launch a process."""
import argparse
import json
from pathlib import Path
import re

ORIGINAL = 'cc03b199128f8afed58713912c551ad7556e6bc4'
ORIGINAL_SHA256 = '0b114887b3a2f94ceea21287181c3c832a2ce137ff204a55cebebe14b1c3c3d5'
CHECKS = ['held item uses item route without training', 'held item receives empty-hand instruction']
for i in range(1, 4):
    CHECKS += [f'real wait {i} reaches150 ticks and releases action lock',
               f'repetition {i} acknowledges start before real wait']
    if i < 3:
        CHECKS += [f'repetition {i} has no partial gain']
CHECKS += ['original finite set reward remains intact', 'no autonomous fourth repetition',
           'real hand switch interrupts without partial gain', 'interruption reports lost unfinished set',
           'current cap explains rejection', 'trained cap explains rejection', 'fatigue explains rejection',
           'other actor ownership explains rejection', 'own other equipment explains rejection',
           'busy repetition explains rejection', 'internal eligibility checks stay quiet']
SILENT_FAILURES = {'held item receives empty-hand instruction',
                   *(f'repetition {i} acknowledges start before real wait' for i in range(1, 4)),
                   'interruption reports lost unfinished set', 'current cap explains rejection',
                   'trained cap explains rejection', 'fatigue explains rejection',
                   'other actor ownership explains rejection', 'own other equipment explains rejection',
                   'busy repetition explains rejection'}
CASES = ['held active item', *(f'real repetition {i}' for i in range(1, 4)),
         'real hand-switch interruption', 'current cap', 'trained cap', 'fatigue',
         'other actor', 'other equipment', 'busy']
DIAGNOSTICS = re.compile(r'runtime error|\bBad ref\b|\bBad loc\b|Cannot (?:read|execute) null|'
                         r'exception|fixture deadline|Infinite loop|##\s*ERROR|fatal error|assertion failed', re.I)


def require(ok, message):
    if not ok:
        raise ValueError(message)


def verify(folder, expected_commit, original_silence=False):
    folder = Path(folder)
    def read(name):
        return json.loads((folder / name).read_text(encoding='utf-8-sig'))
    metadata, result = read('metadata.json'), read('result.json')
    require(re.fullmatch('[0-9a-f]{40}', expected_commit), 'Full expected commit required')
    require(metadata['checkout_head'] == result['commit'] == expected_commit, 'Source/result commit mismatch')
    require(result['byond_build'] == 1681, 'Runtime build mismatch')
    require(metadata['control'] == ('original-silence' if original_silence else 'candidate'), 'Control mode mismatch')
    require(metadata['original_control_commit'] == (ORIGINAL if original_silence else None), 'Original source identity mismatch')
    require(metadata['original_control_sha256'] == (ORIGINAL_SHA256 if original_silence else None), 'Original source digest mismatch')
    for phase, deadline in [('compile', 180), ('runtime', 100)]:
        status = read(phase + '-status.json')
        require(type(status['returncode']) is int and status['returncode'] == 0 and status['timed_out'] is False,
                phase + ' failed or timed out')
        wall = status['wall_seconds']
        require(type(wall) in (int, float) and 0 <= wall < deadline and status['deadline_seconds'] == deadline,
                phase + ' exceeded its exact phase deadline')
    compile_log = (folder / 'compile.log').read_text(encoding='utf-8-sig')
    require(re.search(r'\bDM compiler version 516\.1681\b', compile_log) and
            re.search(r'(?<!\d)0 errors, 0 warnings\b', compile_log), 'Pinned warning-free compilation missing')
    runtime_log = (folder / 'runtime.log').read_text(encoding='utf-8-sig')
    log = runtime_log
    for name in ['runtime-stdout.log', 'runtime-stderr.log']:
        log += '\n' + (folder / name).read_text(encoding='utf-8-sig')
    require(not DIAGNOSTICS.search(log), 'Unrelated runtime diagnostics invalidate the result')
    checks = result['checks']
    require(isinstance(checks, list) and len(checks) == len(CHECKS), 'Incomplete/extra checks')
    require([row['label'] for row in checks] == CHECKS, 'Check labels/order changed')
    require(all(type(row['passed']) in (int, bool) and row['passed'] in (0, 1) for row in checks), 'Invalid check boolean')
    failed = {row['label'] for row in checks if not row['passed']}
    expected_failed = SILENT_FAILURES if original_silence else set()
    require(failed == expected_failed, 'Unexpected causal failures: ' + repr(sorted(failed)))
    # Console output may repeat world.log; require exact failures in its one
    # canonical runtime log and scan all streams for unrelated diagnostics.
    log_failures = re.findall(r'FAIL:\s*([^\r\n]+)', runtime_log)
    require(len(log_failures) == len(expected_failed) and set(log_failures) == expected_failed,
            'Log failures do not match the intended causal oracle')
    log_passes = re.findall(r'\bPASS\s+([^\r\n]+)', runtime_log)
    expected_passed = set(CHECKS) - expected_failed
    require(len(log_passes) == len(expected_passed) and set(log_passes) == expected_passed,
            'Log passes do not match the complete result receipt')
    cases = result['cases']
    require([row['case'] for row in cases] == CASES, 'Missing/extra input case')
    require(all(isinstance(row['messages'], list) and all(isinstance(m, str) for m in row['messages']) and
                type(row['time']) in (int, float) for row in cases), 'Malformed input case receipt')
    return {'commit': expected_commit, 'control': metadata['control'], 'checks': len(checks),
            'expected_feedback_failures': len(failed), 'result': 'verified',
            'scope': 'Headless fixture only; no connected-client or gameplay acceptance'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence', type=Path, required=True)
    parser.add_argument('--expected-commit', required=True)
    parser.add_argument('--original-silence', action='store_true')
    args = parser.parse_args()
    receipt = verify(args.evidence, args.expected_commit, args.original_silence)
    (args.evidence / 'verification.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    print(json.dumps(receipt))


if __name__ == '__main__':
    main()
