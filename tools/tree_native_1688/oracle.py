"""Exact phase assertions and diagnostics; consumes data only, never runs native code."""
import json
from pathlib import Path
import re
from prepare import ADAPTER, VERSION, VARIANTS, CONTROLS, HEAD, TREE

FATAL = re.compile(r'TREE1688_FATAL|runtime error|runtime in |uncaught exception|\bBUG:|##\s*ERROR|'
                   r'\berror:|\bwarning:|segmentation|out of memory|access violation|cleanup failed|'
                   r'bad ref|bad loc|infinite loop', re.I)
SUCCESS = {'roundtrip': 'PASS: tree planting production paths and disk round trip',
           'writer': 'PASS: tree restart writer',
           'reader': 'PASS: tree restart reader and production object dispatch'}
RESULT_KEYS = {'schema', 'adapter', 'candidate_manifest_sha256', 'version', 'variant', 'phase',
               'port', 'status', 'failure', 'legacy_result', 'assertions', 'head', 'tree'}


def inventory():
    value = json.loads(Path(__file__).with_name('expected-assertions.json').read_text())
    phases = value['phases']
    if set(phases) != set(SUCCESS) or {name: len(rows) for name, rows in phases.items()} != {
            'roundtrip': 20, 'writer': 3, 'reader': 25}:
        raise ValueError('Fixed generated assertion inventory changed')
    if any(not isinstance(row, str) or not row for rows in phases.values() for row in rows):
        raise ValueError('Malformed assertion inventory')
    return phases


def expected(variant, phase):
    if variant not in VARIANTS or phase not in SUCCESS or (variant != 'baseline' and phase != 'roundtrip'):
        raise ValueError('Unknown variant/phase')
    rows = inventory()[phase]
    failure = None if variant == 'baseline' else CONTROLS[variant][3]
    if failure is not None:
        if rows.count(failure) != 1:
            raise ValueError('Ambiguous causal target')
        rows = rows[:rows.index(failure) + 1]
    return [{'name': name, 'ok': 0 if name == failure else 1} for name in rows]


def listener_diagnostics(log):
    pattern = r'World opened on network port (\d+) for address ([^\s]+)\.'
    binds = list(re.finditer(pattern, log))
    if len(binds) > 1 or log.count('World opened on network port') != len(binds):
        raise ValueError('Repeated or malformed native bind')
    for match in binds:
        if match[2] != '127.0.0.1' or not 1 <= int(match[1]) <= 65535:
            raise ValueError('Nonloopback or invalid native bind')
        if log.find('World no longer opened to new users.', match.end()) < 0:
            raise ValueError('Startup listener lacks closure diagnostic')
    # This log oracle is not a socket census or continuous no-listener proof.


def diagnostics(log):
    if FATAL.search(log):
        raise ValueError('Fatal native diagnostic')
    listener_diagnostics(log)
    if 'FAIL:' in log:
        raise ValueError('Unexpected unstructured failure diagnostic')


def verify_result(binding, variant, phase, result, log, auxiliary=None):
    if not re.fullmatch(r'[0-9a-f]{64}', binding):
        raise ValueError('Invalid candidate identity')
    rows = expected(variant, phase)
    if not isinstance(result, dict) or set(result) != RESULT_KEYS:
        raise ValueError('Unexpected native result schema')
    binding_fields = {'adapter': ADAPTER, 'candidate_manifest_sha256': binding, 'version': VERSION,
                      'variant': variant, 'phase': phase, 'head': HEAD, 'tree': TREE}
    if any(result[k] != v for k, v in binding_fields.items()):
        raise ValueError('Wrong source/adapter/version/variant/phase binding')
    if type(result['schema']) is not int or result['schema'] != 1 or type(result['port']) is not int or result['port'] != 0:
        raise ValueError('Wrong schema or native port')
    received = result['assertions']
    if not isinstance(received, list) or any(not isinstance(row, dict) or set(row) != {'name', 'ok'} or
            type(row['ok']) is not int or row['ok'] not in (0, 1) for row in received):
        raise ValueError('Malformed native integer assertion rows')
    if received != rows:
        raise ValueError('Exact ordered assertion inventory differs')
    if variant == 'baseline':
        required = ('passed', None, SUCCESS[phase])
    else:
        failure = CONTROLS[variant][3]
        required = ('assertion-rejected', failure, 'FAIL: ' + failure)
    if (result['status'], result['failure'], result['legacy_result']) != required:
        raise ValueError('Wrong terminal status or failure')
    diagnostics(log)
    found = []
    for line in log.splitlines():
        if line.startswith('TREE1688_ASSERT '):
            found.append(json.loads(line[len('TREE1688_ASSERT '):]))
    if found != rows or log.count('TREE1688_ASSERT ') != len(rows):
        raise ValueError('Missing, duplicate, malformed or reordered assertion log')
    marker = 'TREE1688_RESULT ' + variant + ':' + phase
    if [line for line in log.splitlines() if line.startswith('TREE1688_RESULT ')] != [marker] or log.count('TREE1688_RESULT ') != 1:
        raise ValueError('Missing or repeated terminal marker')
    if log.rfind('TREE1688_ASSERT ') > log.index(marker):
        raise ValueError('Assertion follows completion')
    for name, content in (auxiliary or {}).items():
        diagnostics(content)
        # Auxiliary logs may duplicate the complete transcript, but cannot
        # provide a partial/mismatched assertion inventory that masks a failure.
        if 'TREE1688_ASSERT ' in content or 'TREE1688_RESULT ' in content:
            verify_result(binding, variant, phase, result, content)
    return {'status': 'passed' if variant == 'baseline' else 'causal-control-detected',
            'assertions': len(rows), 'failed_assertion': None if variant == 'baseline' else CONTROLS[variant][3]}


def verify_compile(log):
    if re.findall(r'DM compiler version ([0-9.]+)', log) != [VERSION]:
        raise ValueError('Exactly one matching compiler banner required')
    if len(re.findall(r'(?<!\d)0 errors, 0 warnings(?!\d)', log)) != 1:
        raise ValueError('Exactly one clean compiler summary required')
    if FATAL.search(log) or re.search(r'\b(?:[1-9]\d*) (?:errors?|warnings?)\b|invalid file', log, re.I):
        raise ValueError('Compiler diagnostics rejected')
    return {'status': 'passed', 'version': VERSION}
