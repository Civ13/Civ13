"""Exact winter assertions and diagnostics. Data-only; never dispatches native code."""
import hashlib
import json
from pathlib import Path
import re
from prepare import ADAPTER, VERSION, VARIANTS, CONTROLS, HEAD, TREE

INVENTORY_SHA256 = 'cdac26dfb6c4df9f689d948a288c8c297db3536de344a56d3bc0c3518fd5509e'
COUNTS = {'roundtrip': 239, 'writer': 20, 'reader': 21}
SUCCESS = {phase: 'passed' for phase in COUNTS}
FATAL = re.compile(r'WINTER1688_FATAL|runtime error|runtime in |uncaught exception|\bBUG:|##\s*ERROR|'
                   r'\berror:|\bwarning:|segmentation|out of memory|access violation|cleanup failed|'
                   r'bad ref|bad loc|infinite loop', re.I)
RESULT_KEYS = {'schema', 'adapter', 'candidate_manifest_sha256', 'version', 'variant', 'phase',
               'port', 'status', 'failure', 'assertions', 'head', 'tree'}


def strict_json(raw):
    """Call this at file admission too: dicts alone cannot reveal duplicate keys."""
    def object_pairs(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError('Duplicate JSON key')
            result[key] = value
        return result
    def nonfinite(value):
        raise ValueError('Nonfinite JSON number')
    return json.loads(raw, object_pairs_hook=object_pairs, parse_constant=nonfinite)


def inventory():
    path = Path(__file__).with_name('expected-assertions.json')
    raw = path.read_bytes()
    if hashlib.sha256(raw).hexdigest() != INVENTORY_SHA256:
        raise ValueError('Exact assertion inventory bytes changed')
    value = strict_json(raw)
    if set(value) != {'schema', 'source_sha256', 'phases', 'scope'} or type(value['schema']) is not int or value['schema'] != 1:
        raise ValueError('Malformed assertion inventory schema')
    phases = value['phases']
    if not isinstance(phases, dict) or set(phases) != set(COUNTS) or {
            name: len(rows) for name, rows in phases.items()} != COUNTS:
        raise ValueError('Fixed generated assertion inventory changed')
    if any(not isinstance(rows, list) or any(not isinstance(row, str) or not row for row in rows)
           for rows in phases.values()):
        raise ValueError('Malformed assertion inventory')
    hashes = value['source_sha256']
    if not isinstance(hashes, dict) or set(hashes) != {'probe.dm', 'food-save.dm'}:
        raise ValueError('Wrong assertion source inventory')
    for name, expected_digest in hashes.items():
        if hashlib.sha256(path.with_name(name).read_bytes()).hexdigest() != expected_digest:
            raise ValueError('Assertion source changed: ' + name)
    return phases


def expected(variant, phase):
    if variant not in VARIANTS or phase not in COUNTS or (variant != 'baseline' and phase != 'roundtrip'):
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
    if not isinstance(log, str):
        raise ValueError('Nontext diagnostic log')
    if FATAL.search(log):
        raise ValueError('Fatal native diagnostic')
    listener_diagnostics(log)
    if 'FAIL:' in log:
        raise ValueError('Unexpected unstructured failure diagnostic')


def validate_rows(rows):
    if not isinstance(rows, list) or any(not isinstance(row, dict) or set(row) != {'name', 'ok'} or
            not isinstance(row['name'], str) or not row['name'] or
            type(row['ok']) is not int or row['ok'] not in (0, 1) for row in rows):
        raise ValueError('Malformed native integer assertion rows')


def verify_result(binding, variant, phase, result, log, auxiliary=None):
    if not isinstance(binding, str) or not re.fullmatch(r'[0-9a-f]{64}', binding):
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
    validate_rows(received)
    if received != rows:
        raise ValueError('Exact ordered assertion inventory differs')
    required = ('passed', None) if variant == 'baseline' else ('assertion-rejected', CONTROLS[variant][3])
    if (result['status'], result['failure']) != required:
        raise ValueError('Wrong terminal status or failure')
    diagnostics(log)
    found = []
    for line in log.splitlines():
        if line.startswith('WINTER1688_ASSERT '):
            found.append(strict_json(line[len('WINTER1688_ASSERT '):]))
    validate_rows(found)
    if found != rows or log.count('WINTER1688_ASSERT ') != len(rows):
        raise ValueError('Missing, duplicate, malformed or reordered assertion log')
    marker = 'WINTER1688_RESULT ' + variant + ':' + phase
    if [line for line in log.splitlines() if line.startswith('WINTER1688_RESULT ')] != [marker] or log.count('WINTER1688_RESULT ') != 1:
        raise ValueError('Missing or repeated terminal marker')
    if log.rfind('WINTER1688_ASSERT ') > log.index(marker):
        raise ValueError('Assertion follows completion')
    if auxiliary is not None and not isinstance(auxiliary, dict):
        raise ValueError('Malformed auxiliary logs')
    for name, content in (auxiliary or {}).items():
        diagnostics(content)
        # Complete duplicate transcripts are allowed; partial ones cannot hide failures.
        if 'WINTER1688_ASSERT ' in content or 'WINTER1688_RESULT ' in content:
            verify_result(binding, variant, phase, result, content)
    return {'status': 'passed' if variant == 'baseline' else 'causal-control-detected',
            'assertions': len(rows), 'failed_assertion': None if variant == 'baseline' else CONTROLS[variant][3]}


def verify_compile(log):
    if not isinstance(log, str):
        raise ValueError('Nontext compiler log')
    if re.findall(r'DM compiler version ([0-9.]+)', log) != [VERSION]:
        raise ValueError('Exactly one matching compiler banner required')
    if len(re.findall(r'(?<!\d)0 errors, 0 warnings(?!\d)', log)) != 1:
        raise ValueError('Exactly one clean compiler summary required')
    if FATAL.search(log) or re.search(r'\b(?:[1-9]\d*) (?:errors?|warnings?)\b|invalid file', log, re.I):
        raise ValueError('Compiler diagnostics rejected')
    return {'status': 'passed', 'version': VERSION}
