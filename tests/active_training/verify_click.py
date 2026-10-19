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
# Compiler evidence contract v1: exact DIAGNOSTIC and validate_compile from
# contained-bb89a0b8-v7/oracle/z_budget_evidence.py, also faction client-native-v10
# helpers/z_budget_evidence.py. Both original files have SHA256:
# 133c130845ab28cfb6f0bfb8b2c63b595d3694afc44a3af398cb1fdf3de584db.
DIAGNOSTIC = re.compile(r'runtime error:|bad ref|bad loc|BUG:|##\s*ERROR\s*:|RUNTIME:|assertion failed|infinite loop|segmentation|fatal error|unexpected runtime|\bOOM\b|out of memory|access violation|\bCRASH(?:ED)?\b|invalid file', re.I)


MAX_COMPILE_LOG = 1024 * 1024


def validate_compile(exit_code, log, artifact="probe.dmb"):
    """Accept one exact pinned banner and one uncontaminated probe result."""
    if exit_code != 0 or len(log.encode('utf-8')) > MAX_COMPILE_LOG or DIAGNOSTIC.search(log):
        raise RuntimeError('Compiler exit, output bound or diagnostics invalidated evidence')
    lines = log.splitlines()
    banners = [line for line in lines if re.search(r'DM compiler version', line, re.I)]
    if banners != ['DM compiler version 516.1681']:
        raise RuntimeError('Exactly one full pinned compiler banner required')
    results = [line for line in lines if re.search(r'\berrors?\b|\bwarnings?\b', line, re.I)]
    # Native 516.1681 adds a local date/time to the result; synthetic logs may omit it.
    summary = re.escape(artifact) + r' - 0 errors, 0 warnings(?: \(\d{1,2}/\d{1,2}/\d{2,4} \d{1,2}:\d{2}(?::\d{2})? (?:am|pm)\))?'
    if len(results) != 1 or not re.fullmatch(summary, results[0]):
        raise RuntimeError('Exactly one bounded clean compiler result required')
    if lines.index(banners[0]) >= lines.index(results[0]):
        raise RuntimeError('Compiler result preceded its banner')

# Preserve fixture-specific rejection checks in addition to the accepted helper.
DIAGNOSTICS = re.compile(DIAGNOSTIC.pattern + r'|runtime error|Cannot (?:read|execute) null|'
                         r'exception|fixture deadline|##\s*ERROR', re.I)
MAX_RETAINED_BYTES = 16 * 1024 * 1024
RETAINED_FILES = ('metadata.json', 'result.json', 'compile-status.json', 'runtime-status.json',
                  'compile.log', 'compile-stdout.log', 'compile-stderr.log',
                  'runtime.log', 'runtime-stdout.log', 'runtime-stderr.log')
COMPILED_ARTIFACT = '.active_training_click.dmb'


def require(ok, message):
    if not ok:
        raise ValueError(message)


def verify(folder, expected_commit, original_silence=False):
    folder = Path(folder)
    # Check the aggregate before reading metadata or any output. The bounded
    # reads also reject growth between stat and read without allocating >16 MiB.
    require(sum((folder / name).stat().st_size for name in RETAINED_FILES) <= MAX_RETAINED_BYTES,
            'Retained evidence exceeds 16 MiB aggregate bound')
    texts = {}
    remaining = MAX_RETAINED_BYTES
    for name in RETAINED_FILES:
        with (folder / name).open('rb') as stream:
            data = stream.read(remaining + 1)
        require(len(data) <= remaining, 'Retained evidence grew past 16 MiB aggregate bound')
        remaining -= len(data)
        texts[name] = data.decode('utf-8-sig')
    def read(name):
        return json.loads(texts[name])
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
    compile_log = texts['compile.log']
    try:
        validate_compile(0, compile_log, COMPILED_ARTIFACT)
    except RuntimeError as error:
        raise ValueError('Pinned warning-free compilation invalid: ' + str(error)) from error
    for name in ['compile.log', 'compile-stdout.log', 'compile-stderr.log']:
        require(not DIAGNOSTICS.search(texts[name]), 'Unrelated compile diagnostics invalidate the result')
        require(not re.search(r'\bFAIL\b', texts[name]), 'Unrelated compile FAIL invalidates the result')
    runtime_log = texts['runtime.log']
    for name in ['runtime.log', 'runtime-stdout.log', 'runtime-stderr.log']:
        require(not DIAGNOSTICS.search(texts[name]), 'Unrelated runtime diagnostics invalidate the result')
    checks = result['checks']
    require(isinstance(checks, list) and len(checks) == len(CHECKS), 'Incomplete/extra checks')
    require([row['label'] for row in checks] == CHECKS, 'Check labels/order changed')
    require(all(type(row['passed']) in (int, bool) and row['passed'] in (0, 1) for row in checks), 'Invalid check boolean')
    failed = {row['label'] for row in checks if not row['passed']}
    expected_failed = SILENT_FAILURES if original_silence else set()
    require(failed == expected_failed, 'Unexpected causal failures: ' + repr(sorted(failed)))
    # Console output may repeat world.log; count exact canonical markers once,
    # but reject every unrelated FAIL marker in every runtime stream.
    for name in ['runtime.log', 'runtime-stdout.log', 'runtime-stderr.log']:
        markers = re.findall(r'\bFAIL\b([^\r\n]*)', texts[name])
        require(all(marker.startswith(': ') and marker[2:] in expected_failed for marker in markers),
                'Unrelated runtime FAIL invalidates the result')
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
