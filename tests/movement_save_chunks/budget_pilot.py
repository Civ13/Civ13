"""Fixed diagnostic pilot. Default prepares source only; never grants acceptance."""
import argparse
from datetime import datetime, timezone
import importlib.util
import json
from pathlib import Path
import shutil
import sys
import time
import uuid

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('budget_pilot_benchmark', HERE / 'benchmark.py')
bench = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = bench
spec.loader.exec_module(bench)

ORDER = (1, 0, 0, 1, 0, 1, 1, 0)
LIMITS = dict(case_seconds=90, job_seconds=900, rss_mib=1024, sample_ms=20)


def plan():
    return [dict(count=64, payload=1024, baseline=b) for b in ORDER]


def _error_record(error):
    chain, seen = [], set()
    current = error
    while current is not None and id(current) not in seen and len(chain) < 8:
        seen.add(id(current))
        chain.append(dict(type=type(current).__name__, message=str(current)))
        current = current.__cause__ or current.__context__
    return dict(type=type(error).__name__, message=str(error), chain=chain)


def _initial_receipt():
    return dict(cases=plan(), benchmark_mode='capture_budget_recurrence_pilot',
                comparative=False, acceptance_status='not_established',
                diagnostic_verdict='not_run', preparation_complete=False,
                interpretation='Eight fixed diagnostic processes, not full-matrix or production acceptance.',
                fixed_order=list(ORDER), replacements=0, limits=LIMITS.copy())


def _atomic_json(path, receipt):
    # Failed temporary files remain evidence. No bounded or infallible I/O claim.
    temporary = path.with_name('.' + path.name + '.' + uuid.uuid4().hex + '.tmp')
    temporary.write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    temporary.replace(path)


def write(output, receipt, name='receipt.json'):
    _atomic_json(output / name, receipt)


def _persist_final(output, receipt, primary_error=None):
    try:
        write(output, receipt)
    except BaseException as final_error:
        receipt['finalization_error'] = _error_record(final_error)
        receipt['diagnostic_verdict'] = ('not_run' if not receipt.get('execution_started')
                                         else 'inconclusive_stopped')
        receipt['stop'] = receipt.get('stop') or dict(reason='finalization_write_failure')
        recovery_error = None
        try:
            # One recovery publication; never more native launches.
            _atomic_json(output / 'receipt.json', receipt)
        except BaseException as error:
            recovery_error = error
            receipt['recovery_write_error'] = _error_record(error)
            try:
                print('PILOT_FINALIZATION_FAILURE ' + json.dumps(receipt), file=sys.stderr)
            except BaseException as stderr_error:
                final_error.add_note('Terminal stderr also failed: ' + str(stderr_error))
        if recovery_error is not None:
            final_error.add_note('Recovery receipt publication failed: ' + str(recovery_error))
        if primary_error is not None:
            primary_error.add_note('Final receipt publication failed: ' + str(final_error))
            for note in getattr(final_error, '__notes__', []):
                primary_error.add_note('Finalization detail: ' + note)
            if recovery_error is not None:
                primary_error.add_note('Recovery receipt publication failed: ' + str(recovery_error))
            return
        raise final_error


def prepare(output):
    # Claim a fresh directory; never overwrite another run after a refusal.
    output.mkdir(parents=True, exist_ok=False)
    receipt = _initial_receipt()
    try:
        receipt = bench.prepare(output)
        receipt.update(_initial_receipt())
        receipt['preparation_complete'] = True
        write(output, receipt)
        return receipt
    except BaseException as error:
        receipt.update(_initial_receipt())
        receipt['orchestration_error'] = _error_record(error)
        _persist_final(output, receipt, error)
        raise


def authorization_deadline(value):
    return datetime.strptime(value, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)


def classify(folder, case, result):
    logs = {n: (folder / n).read_text() for n in ('daemon.log', 'runtime.log', 'errors.txt') if (folder / n).exists()}
    text = ''.join(logs.values())
    marker = (folder / 'result.txt').read_text().strip() if (folder / 'result.txt').exists() else None
    diagnostics = bool(bench.DIAGNOSTIC.search(text)) or bool(logs.get('errors.txt', '').strip())
    phases = bench.native_phases(text)
    contract_ok = bench.phase_contract(phases, case['baseline'])
    observations = bench.capture_budget_observations(logs, case, folder.name)
    result.update(case=dict(case), marker=marker, native_diagnostics=diagnostics,
                  phases=phases, phase_contract=contract_ok,
                  capture_budget_observations=observations,
                  passed=result['status'] == 'exited' and result.get('returncode') == 0 and marker == 'PASS' and not diagnostics and contract_ok and 'rss_bytes' in result.get('peaks', {}))
    unexpected = [line for line in text.splitlines()
                  if bench.DIAGNOSTIC.search(line) and bench.CAPTURE_BUDGET_MESSAGE not in line]
    budget_outcome = (result['status'] == 'exited' and result.get('returncode') == 0
                      and marker == 'FAIL' and not unexpected and not logs.get('errors.txt', '').strip()
                      and 'rss_bytes' in result.get('peaks', {}) and bool(observations)
                      and all(o['metric_status'] == 'complete' and o['attempt'] is not None
                              and o['exception_metrics']['usage_delta'] > 10
                              and o['exception_metrics']['tick_delta'] == 0
                              and o['exception_metrics']['work'] <= 8192
                              and o['exception_metrics']['total_usage'] < 90
                              and o['exception_metrics']['elapsed_ds'] <= 1
                              for o in observations))
    return result, budget_outcome


def execute(output, byond_bin, archive, authorized_until):
    """At most two compiler children and eight daemon children; never retry."""
    if not sys.platform.startswith('linux'):
        raise ValueError('Actual Linux required for native execution')
    receipt = json.loads((output / 'receipt.json').read_text())
    if (receipt.get('benchmark_mode') != 'capture_budget_recurrence_pilot'
            or receipt.get('cases') != plan() or receipt.get('fixed_order') != list(ORDER)
            or receipt.get('limits') != LIMITS or receipt.get('profile_datums') is not False
            or receipt.get('preparation_complete') is not True
            or receipt.get('diagnostic_verdict') != 'not_run'
            or receipt.get('orchestration_error') or (output / 'progress.json').exists()):
        raise ValueError('Pilot plan, limits or one-shot state differ from the reviewed plan')
    limits = bench.Limits(**LIMITS).validate()
    remaining = (authorization_deadline(authorized_until) - datetime.now(timezone.utc)).total_seconds() - 5
    deadline = time.monotonic() + min(remaining, limits.job_seconds)
    receipt.update(diagnostic_verdict='running', execution='diagnostic_only',
                   execution_started=True, authorized_until=authorized_until,
                   cleanup_reserve_seconds=5, acceptance_status='not_established',
                   results=[], compiles=[])
    results = receipt['results']
    stop, active, primary_error = None, None, None

    def admitted_identity():
        if time.monotonic() >= deadline:
            raise TimeoutError('deadline reached before launch')
        identity = bench.verify_runtime(byond_bin, archive)
        if time.monotonic() >= deadline:
            raise TimeoutError('deadline reached during identity verification')
        return identity

    try:
        # Only progress snapshots are running; canonical receipt stays not_run.
        write(output, receipt, 'progress.json')
        for name, folder in (('candidate', output), ('baseline', output / 'baseline-source')):
            active = dict(stage='compile_identity', variant=name, launch_attempted=False)
            try:
                identity = admitted_identity()
            except Exception as error:
                stop = dict(reason='deadline_or_identity_refusal', error=_error_record(error), stage=name)
                break
            active.update(stage='compile_run', launch_attempted=True)
            build = bench.run_monitored([str(byond_bin / 'DreamMaker'), '-max_errors', '0', 'benchmark.dme'],
                                        folder, 'compile', limits, deadline)
            receipt['compiles'].append(dict(variant=name, identity=identity, result=build))
            active['stage'] = 'compile_log_and_progress'
            log = (folder / 'compile.log').read_text() if (folder / 'compile.log').exists() else ''
            write(output, receipt, 'progress.json')
            if not bench.compile_ok(build, log, folder / 'benchmark.dmb'):
                stop = dict(reason='compile_refused', stage=name, status=build['status'])
                break
            active = None
        if stop is None:
            for index, case in enumerate(plan()):
                active = dict(stage='case_identity', pilot_index=index, case=dict(case), launch_attempted=False)
                try:
                    identity = admitted_identity()
                except Exception as error:
                    stop = dict(reason='deadline_or_identity_refusal', error=_error_record(error), index=index)
                    break
                active['stage'] = 'case_inputs'
                folder = output / f'pilot-{index:02d}-64-1024-{case["baseline"]}'
                folder.mkdir()
                source = output / 'baseline-source' if case['baseline'] else output
                for name in ('benchmark.dmb', 'benchmark.rsc'):
                    if (source / name).exists():
                        shutil.copy2(source / name, folder / name)
                (folder / 'runtime-identity.json').write_text(json.dumps(identity, indent=2))
                params = '&'.join(f'{key}={value}' for key, value in case.items())
                active.update(stage='case_run', launch_attempted=True)
                result = bench.run_monitored([str(byond_bin / 'DreamDaemon'), 'benchmark.dmb', '-trusted',
                                              '-ip', '127.0.0.1', '-nowebclient', '-log', 'runtime.log',
                                              '-params', params], folder, 'daemon', limits, deadline)
                active.update(stage='case_classification', returned_summary=dict(result))
                result, budget_outcome = classify(folder, case, result)
                result['pilot_index'] = index
                results.append(result)
                active['stage'] = 'case_progress'
                write(output, receipt, 'progress.json')
                if not result['passed'] and not budget_outcome:
                    stop = dict(reason='resource_process_or_unexpected_case_failure', index=index, status=result['status'])
                    break
                active = None
    except BaseException as error:
        primary_error = error
        receipt['orchestration_error'] = _error_record(error)
        stop = dict(reason='orchestration_exception')
        if active and active['launch_attempted']:
            if active['stage'].startswith('compile'):
                if not any(c['variant'] == active['variant'] for c in receipt['compiles']):
                    receipt['compiles'].append(dict(variant=active['variant'], status='orchestration_exception',
                                                    child_cleanup='unconfirmed', error=_error_record(error)))
            elif not any(r['pilot_index'] == active['pilot_index'] for r in results):
                results.append(dict(pilot_index=active['pilot_index'], case=active['case'],
                                    status='orchestration_exception', passed=False,
                                    returned_summary=active.get('returned_summary'),
                                    child_cleanup='unconfirmed', error=_error_record(error)))
        raise
    finally:
        attempted = {r['pilot_index'] for r in results}
        receipt['not_run'] = [dict(pilot_index=i, case=dict(c), status='not_run_after_stop')
                              for i, c in enumerate(plan()) if i not in attempted]
        receipt['stop'] = stop
        receipt['active_step'] = active
        receipt['diagnostic_verdict'] = ('inconclusive_stopped' if stop or len(results) != 8 else
                                         'completed_no_breach_observed' if all(r['passed'] for r in results) else
                                         'completed_with_breaches')
        if primary_error is not None:
            receipt['cleanup_qualification'] = (
                'Inherited monitor attempts owned direct-child kill/wait; an escaping monitor exception can leave cleanup '
                'unconfirmed. No descendant containment, socket census or hard I/O bound is established.')
        _persist_final(output, receipt, primary_error)
    return receipt


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--run-native', action='store_true')
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--byond-archive', type=Path)
    parser.add_argument('--authorized-until', help='Explicit reviewed UTC deadline YYYY-MM-DDTHH:MM:SSZ')
    args = parser.parse_args(argv)
    if args.run_native and (not args.byond_bin or not args.byond_archive or not args.authorized_until):
        parser.error('Native requires explicit pinned bin/archive and a newly approved absolute UTC deadline')
    if args.authorized_until:
        try:
            authorization_deadline(args.authorized_until)
        except ValueError:
            parser.error('Invalid absolute UTC deadline')
    prepare(args.output)
    if not args.run_native:
        return 0
    receipt = execute(args.output, args.byond_bin, args.byond_archive, args.authorized_until)
    return 0 if receipt['diagnostic_verdict'] == 'completed_no_breach_observed' else 1


if __name__ == '__main__':
    raise SystemExit(main())
