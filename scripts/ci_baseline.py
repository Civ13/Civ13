"""Bounded offline CI registry and exact-source execution/aggregate receipts.

Only reviewed, explicitly named unittest files run here. This is neither a native
test launcher nor a claim that source projections establish gameplay acceptance.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import subprocess
import sys
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
POLICY_FILES = tuple('tests/' + name for name in (
    'test_ci_selection.py', 'test_ci_regression_policy.py',
    'test_ci_build_prefix.py', 'test_ci_baseline.py'))
# Review the complete imports/call graph before adding files. No wildcard test
# discovery: test_native.py and newly added runners must never enter implicitly.
SUITES = {
    'policy': {'files': POLICY_FILES, 'always': True, 'paths': ()},
    'bootstrap': {'files': ('tests/test_byond_bootstrap.py',), 'always': True, 'paths': ()},
    'progress': {'files': ('tests/world_save/test_progress_sources.py',), 'always': True, 'paths': ()},
    'research': {'files': ('tests/research_scheduler/test_resume.py',), 'paths': (
        'tests/research_scheduler/', 'code/processes/research_tree.dm',
        'code/processes/_process.dm', 'code/processes/___defines.dm',
        'code/processes/__processScheduler.dm')},
    'ping': {'files': ('tests/ping_scheduler/test_resume.py',), 'paths': (
        'tests/ping_scheduler/', 'code/processes/ping_track.dm', 'code/processes/_process.dm')},
    'year': {'files': ('tests/persistence_year/test_floor.py',), 'paths': (
        'tests/persistence_year/', 'tests/world_save/', 'code/modules/persistence/', 'code/setup.dm')},
    'evidence': {'files': ('tests/test_game_evidence.py',), 'paths': (
        'tests/test_game_evidence.py', 'scripts/check-game-evidence.py')},
}
CI_PATHS = ('scripts/select-ci.py', 'scripts/ci_baseline.py',
            '.github/workflows/ci-selection.yml', '.github/workflows/test.yml')
TIMEOUT = 30  # per reviewed suite; enclosing job also has a wall-clock limit


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, stderr=subprocess.PIPE,
                                   timeout=15).decode('utf-8').strip()


def revision(value):
    return git('rev-parse', '--verify', value + '^{commit}')


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n', encoding='utf-8')


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def provenance(head, base):
    actual = revision('HEAD')
    if revision(head) != actual:
        raise ValueError('Requested head differs from checked-out HEAD')
    resolved_base = None
    if base and set(base) != {'0'}:
        try:
            resolved_base = revision(base)
        except (subprocess.SubprocessError, UnicodeError):
            pass
    return dict(head=actual, base=resolved_base, requested_base=base,
                run_id=os.environ.get('GITHUB_RUN_ID'),
                run_attempt=os.environ.get('GITHUB_RUN_ATTEMPT'))


def documentation(path):
    return PurePosixPath(path).suffix.lower() not in {'.dm', '.dme', '.dmm', '.dmi', '.rsc'} and (
        path.startswith('docs/') or
        (len(PurePosixPath(path).parts) == 1 and path.endswith('.md')) or
        path == 'scripts/build-api-docs.py' or
        path in {'.github/workflows/api-docs.yml', '.github/workflows/api-pages.yml'})


def matches(path, pattern):
    return path.startswith(pattern) if pattern.endswith('/') else path == pattern


def impact(paths, comparison='available'):
    """Unknown executable/shared impact runs this small registry, never native work."""
    reasons = {name: ['Always-required offline baseline'] if spec.get('always') else []
               for name, spec in SUITES.items()}
    unknown = []
    if comparison != 'available':
        unknown = ['Comparison unavailable; all reviewed offline suites required']
    for path in paths:
        covered = False
        for name, spec in SUITES.items():
            if any(matches(path, pattern) for pattern in (*spec['paths'], *spec['files'])):
                reasons[name].append('Affected input: ' + path)
                covered = True
        if path in CI_PATHS or path in POLICY_FILES:
            unknown.append('CI policy/dependency changed: ' + path)
        elif not covered and not documentation(path):
            unknown.append('Unmapped impact: ' + path)
    if unknown:
        for name in reasons:
            reasons[name].append('Conservative fallback: all reviewed offline suites')
    return {'suites': {name: {'selected': bool(why), 'reason': why or [
                'No mapped input changed; native/costly tests remain separately admitted']}
                       for name, why in reasons.items()}, 'fallback_reasons': unknown}


def selection_receipt(base, head, game, extensive, new_tests, reason, event):
    receipt = dict(schema_version=1, kind='selection', status='passed',
                   **provenance(head, base), event=event)
    paths = []
    comparison = 'unavailable'
    if receipt['base']:
        try:
            raw = subprocess.check_output(['git', 'diff', '--name-only', '--no-renames', '-z',
                                           receipt['base'], receipt['head']], cwd=ROOT,
                                          stderr=subprocess.PIPE, timeout=15)
            paths = sorted(p for p in raw.decode('utf-8').split('\0') if p)
            comparison = 'available'
        except (subprocess.SubprocessError, UnicodeError):
            pass
    receipt.update(comparison={'status': comparison, 'paths': paths,
                              'reason': 'Exact base/head comparison' if comparison == 'available'
                              else 'No reliable diff; compile policy and bounded offline fallback apply'},
                   compile={'selected': game, 'reason': reason}, extensive=extensive,
                   new_tests=new_tests, baseline=impact(paths, comparison))
    return receipt


def load_selection(path, head, base):
    plan = json.loads(Path(path).read_text(encoding='utf-8'))
    expected = provenance(head, base)
    for key in ('head', 'base', 'requested_base', 'run_id', 'run_attempt'):
        if plan.get(key) != expected[key]:
            raise ValueError('Selection provenance mismatch: ' + key)
    if plan.get('schema_version') != 1 or plan.get('kind') != 'selection' or plan.get('status') != 'passed':
        raise ValueError('Missing or failed selection receipt')
    suites = plan['baseline']['suites']
    if set(suites) != set(SUITES) or any(type(row['selected']) is not bool for row in suites.values()):
        raise ValueError('Invalid baseline selection')
    if any(not suites[name]['selected'] for name, spec in SUITES.items() if spec.get('always')):
        raise ValueError('Always-required suite omitted')
    if type(plan['compile']['selected']) is not bool:
        raise ValueError('Invalid compilation selection')
    return plan


def run_unit(name, output):
    """Child interpreter emits counts so zero tests or unittest skips cannot pass."""
    suite = unittest.TestSuite()
    for index, relative in enumerate(SUITES[name]['files']):
        path = ROOT / relative
        spec = importlib.util.spec_from_file_location(f'baseline_{name}_{index}', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        suite.addTests(unittest.defaultTestLoader.loadTestsFromModule(module))
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    passed = result.wasSuccessful() and result.testsRun > 0 and not result.skipped
    write_json(output, dict(tests=result.testsRun, failures=len(result.failures),
                            errors=len(result.errors), skipped=len(result.skipped),
                            status='passed' if passed else 'failed'))
    return 0 if passed else 1


def execute(plan, output):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    receipt = dict(schema_version=1, kind='baseline', status='running',
                   **{key: plan[key] for key in ('head', 'base', 'requested_base', 'run_id', 'run_attempt')},
                   selection_sha256=digest(plan), suites={})
    (output / 'source-tree.txt').write_text(git('ls-tree', '-r', 'HEAD') + '\n', encoding='utf-8')
    tracked_patch = subprocess.check_output(['git', 'diff', '--binary', 'HEAD'], cwd=ROOT, timeout=15)
    (output / 'tested.patch').write_bytes(tracked_patch)
    receipt['tracked_dirty'] = bool(tracked_patch)
    write_json(output / 'baseline.json', receipt)
    for name, selected in plan['baseline']['suites'].items():
        row = dict(selected, status='skipped')
        receipt['suites'][name] = row
        if selected['selected']:
            counts = output / (name + '.json')
            counts.unlink(missing_ok=True)
            command = [sys.executable, '-B', str(Path(__file__).resolve()), 'unit',
                       '--suite', name, '--output', str(counts.resolve())]
            row.update(command=command, timeout_seconds=TIMEOUT, files=list(SUITES[name]['files']))
            started = time.monotonic()
            with (output / (name + '.log')).open('wb') as log:
                try:
                    result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                                            timeout=TIMEOUT)
                    row['exit_code'] = result.returncode
                    row['status'] = 'failed'
                    if counts.is_file():
                        row['counts'] = json.loads(counts.read_text(encoding='utf-8'))
                        if result.returncode == 0 and row['counts']['status'] == 'passed':
                            row['status'] = 'passed'
                except subprocess.TimeoutExpired:
                    row.update(status='failed', reason=['Offline suite deadline exceeded'])
            row['duration_seconds'] = round(time.monotonic() - started, 3)
        write_json(output / 'baseline.json', receipt)
    receipt['status'] = 'passed' if all(row['status'] == ('passed' if row['selected'] else 'skipped')
                                        for row in receipt['suites'].values()) else 'failed'
    write_json(output / 'baseline.json', receipt)
    print(json.dumps(receipt, indent=2))
    return 0 if receipt['status'] == 'passed' else 1


def compile_receipt(plan, outcome, output):
    directory = Path(output).parent
    directory.mkdir(parents=True, exist_ok=True)
    (directory / 'source-tree.txt').write_text(git('ls-tree', '-r', 'HEAD') + '\n', encoding='utf-8')
    (directory / 'source-final.patch').write_bytes(subprocess.check_output(
        ['git', 'diff', '--binary', 'HEAD'], cwd=ROOT, timeout=15))
    selected = plan['compile']['selected']
    status = 'passed' if outcome == 'success' and selected else 'failed' if selected else 'skipped'
    if not selected and outcome != 'skipped':
        status = 'failed'
    receipt = dict(schema_version=1, kind='compile', status=status, selected=selected,
                   **{key: plan[key] for key in ('head', 'base', 'requested_base', 'run_id', 'run_attempt')},
                   selection_sha256=digest(plan), step_outcome=outcome,
                   reason=plan['compile']['reason'], toolchain='BYOND 516.1681',
                   archive_authenticity='Unverified: observed digest is diagnostic provenance only')
    write_json(output, receipt)
    return 1 if status == 'failed' else 0


def aggregate(plan, baseline, compile_run, jobs, extraction_selected):
    errors = []
    required = {'changes', 'baseline', 'evidence-checker', 'build'}
    if extraction_selected:
        required.add('extraction-instances')
    for name in required:
        if jobs.get(name, {}).get('result') != 'success':
            errors.append('Required job did not succeed: ' + name)
    if not extraction_selected and jobs.get('extraction-instances', {}).get('result') not in {'success', 'skipped'}:
        errors.append('Unexpected extraction job failure or missing outcome')
    for receipt, kind in ((baseline, 'baseline'), (compile_run, 'compile')):
        if receipt.get('schema_version') != 1 or receipt.get('kind') != kind:
            errors.append('Missing/invalid ' + kind + ' receipt')
        for key in ('head', 'base', 'requested_base', 'run_id', 'run_attempt'):
            if receipt.get(key) != plan.get(key):
                errors.append(kind + ' provenance mismatch: ' + key)
        if receipt.get('selection_sha256') != digest(plan):
            errors.append(kind + ' selection digest mismatch')
    if baseline.get('status') != 'passed':
        errors.append('Baseline did not pass')
    if baseline.get('tracked_dirty') is not False:
        errors.append('Baseline is not evidence from a clean committed head')
    actual = baseline.get('suites', {})
    if set(actual) != set(SUITES):
        errors.append('Baseline suite set differs from selection')
    for name, selection in plan['baseline']['suites'].items():
        row = actual.get(name, {})
        if row.get('selected') != selection['selected'] or row.get('status') != (
                'passed' if selection['selected'] else 'skipped'):
            errors.append('Missing, failed or unexpectedly skipped suite: ' + name)
        if selection['selected']:
            counts = row.get('counts', {})
            if row.get('exit_code') != 0 or counts.get('status') != 'passed' or not counts.get('tests') or any(
                    counts.get(key) != 0 for key in ('errors', 'failures', 'skipped')):
                errors.append('Incomplete test execution: ' + name)
        elif not row.get('reason'):
            errors.append('Unexplained suite skip: ' + name)
    selected = plan['compile']['selected']
    if compile_run.get('selected') != selected or compile_run.get('status') != ('passed' if selected else 'skipped'):
        errors.append('Required compilation missing/failed/skipped, or invalid skip')
    if compile_run.get('step_outcome') != ('success' if selected else 'skipped') or not compile_run.get('reason'):
        errors.append('Incomplete compilation outcome/reason')
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('unit', 'run', 'compile', 'aggregate'))
    parser.add_argument('--suite', choices=SUITES)
    parser.add_argument('--selection')
    parser.add_argument('--head')
    parser.add_argument('--base', default='')
    parser.add_argument('--output', required=True)
    parser.add_argument('--outcome')
    parser.add_argument('--baseline')
    parser.add_argument('--compile-receipt')
    args = parser.parse_args()
    if args.mode == 'unit':
        return run_unit(args.suite, args.output)
    plan = load_selection(args.selection, args.head, args.base)
    if args.mode == 'run':
        return execute(plan, args.output)
    if args.mode == 'compile':
        return compile_receipt(plan, args.outcome, args.output)
    jobs = json.loads(os.environ['CI_NEEDS'])
    extraction = os.environ['EXTRACTION_SELECTED']
    if extraction not in {'true', 'false'}:
        raise ValueError('Missing extraction selection')
    errors = aggregate(plan, json.loads(Path(args.baseline).read_text(encoding='utf-8')),
                       json.loads(Path(args.compile_receipt).read_text(encoding='utf-8')),
                       jobs, extraction == 'true')
    receipt = dict(schema_version=1, kind='aggregate', status='failed' if errors else 'passed',
                   **{key: plan[key] for key in ('head', 'base', 'requested_base', 'run_id', 'run_attempt')},
                   selection_sha256=digest(plan), jobs=jobs, errors=errors)
    write_json(args.output, receipt)
    print(json.dumps(receipt, indent=2))
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
