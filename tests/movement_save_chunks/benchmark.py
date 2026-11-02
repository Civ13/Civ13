"""Bounded isolated benchmark. Default is source preparation, never execution.

Native execution requires explicit --run-native and a caller-supplied pinned
BYOND directory. This program never downloads tools, connects to a server, or
uses a production save directory. All spawned processes are its own children.
"""
from __future__ import annotations
import argparse
from dataclasses import dataclass
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
_plan_spec = importlib.util.spec_from_file_location('moving_save_diagnostic_cases', Path(__file__).with_name('diagnostic_cases.py'))
_plan_module = importlib.util.module_from_spec(_plan_spec)
_plan_spec.loader.exec_module(_plan_module)
select_case_plan = _plan_module.select_case_plan
_profile_spec = importlib.util.spec_from_file_location('moving_save_datum_profile', Path(__file__).with_name('datum_profile.py'))
_profile_module = importlib.util.module_from_spec(_profile_spec)
_profile_spec.loader.exec_module(_profile_module)
instrument_datum_references = _profile_module.instrument_datum_references
_preflight_spec = importlib.util.spec_from_file_location('moving_save_preflight_fixture', Path(__file__).with_name('preflight_fixture.py'))
_preflight_module = importlib.util.module_from_spec(_preflight_spec)
_preflight_spec.loader.exec_module(_preflight_module)
restore_preflight_reference_keys = _preflight_module.restore_preflight_reference_keys
FILES = ('code/predefines.dm', 'tests/world_save/stubs.dm', 'tests/movement_save_chunks/debug_lossy_adapter.dm',
         'code/modules/multiz/world_z_budget.dm', 'code/modules/persistence/functions.dm',
         'code/modules/persistence/player_reclaim.dm', 'code/modules/persistence/saving.dm',
         'code/modules/persistence/loading.dm', 'tests/movement_save_chunks/benchmark.dm')
VERSION = '516.1688'
DIAGNOSTIC = re.compile(r'runtime error:|bad ?ref|bad loc|BUG:|##\s*ERROR\s*:|RUNTIME:|assertion failed|infinite loop|segmentation|fatal error|unhandled exception|FAIL:', re.I)

@dataclass(frozen=True)
class Limits:
    case_seconds: float = 90
    job_seconds: float = 1200
    rss_mib: int = 1024
    sample_ms: int = 20

    def validate(self):
        if not 1 <= self.case_seconds <= 90: raise ValueError('case timeout must be 1..90 seconds')
        if not 1 <= self.job_seconds <= 1200: raise ValueError('job timeout must be 1..1200 seconds')
        if not 64 <= self.rss_mib <= 1024: raise ValueError('RSS cap must be 64..1024 MiB')
        if not 10 <= self.sample_ms <= 1000: raise ValueError('sampling interval must be 10..1000 ms')
        return self


def cases():
    # Exactly the user-approved scaling grid. A baseline/candidate pair uses
    # identical construction, seed/order, repeats, compiler and resource limits.
    return [dict(count=count, payload=payload, baseline=baseline)
            for count in (64, 512, 2048)
            for payload in (1024, 16384, 65536)
            for baseline in (1, 0)]


def prepare(output: Path, diagnostic_subset=False, profile_datums=False):
    output.mkdir(parents=True, exist_ok=True)
    if any(output.iterdir()): raise ValueError('output must be a new or empty isolated directory')
    hashes = {}
    production_hashes = {}
    baseline_hashes = {}
    for name in FILES:
        data = (ROOT / name).read_bytes()
        production_hashes[name] = hashlib.sha256(data).hexdigest()
        baseline_data = restore_preflight_reference_keys(data.decode()).encode() if name == 'code/modules/persistence/saving.dm' else data
        if profile_datums:
            data = instrument_datum_references(name, data.decode()).encode()
            baseline_data = instrument_datum_references(name, baseline_data.decode()).encode()
        target = output / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        hashes[name] = hashlib.sha256(data).hexdigest()
        baseline_target = output / 'baseline-source' / name
        baseline_target.parent.mkdir(parents=True, exist_ok=True)
        baseline_target.write_bytes(baseline_data)
        baseline_hashes[name] = hashlib.sha256(baseline_data).hexdigest()
    header = ('#define TRUE 1\n#define FALSE 0\n#define TICK_CHECK fixture_tick_check()\n'
              '#define TICK_LIMIT_TO_RUN 100\n#define EXCEPTION(message) new /exception(message)\n')
    dme = header + ''.join(f'#include "{name}"\n' for name in FILES)
    (output / 'benchmark.dme').write_text(dme)
    hashes['benchmark.dme'] = hashlib.sha256(dme.encode()).hexdigest()
    (output / 'baseline-source/benchmark.dme').write_text(dme)
    baseline_hashes['benchmark.dme'] = hashes['benchmark.dme']
    receipt = dict(schema=1, execution='not_run', byond_version=VERSION, profile_datums=profile_datums,
                   datum_profile_sites={"saver": _profile_module.EXPECTED_SAVER_REF_SITES, "identity_helper": 1} if profile_datums else {},
                   datum_profiler_sha256=hashlib.sha256(Path(__file__).with_name('datum_profile.py').read_bytes()).hexdigest(),
                   case_selector_sha256=hashlib.sha256(Path(__file__).with_name('diagnostic_cases.py').read_bytes()).hexdigest(),
                   comparison='preflight_only', baseline='same staged saver and optimized main codec, only preflight seen keys use reference strings', preflight_baseline_helper_sha256=hashlib.sha256(Path(__file__).with_name('preflight_fixture.py').read_bytes()).hexdigest(), sources=hashes, production_sources=production_hashes, baseline_sources=baseline_hashes, **select_case_plan(cases(), diagnostic_subset),
                   instrumentation={'scope': 'copied-packet native datum reference timing' if profile_datums else 'logical fixture counters only; candidate serializer bytes unchanged', 'timing': 'Instrumentation adds overhead; opt-in reference profiling is diagnostic only, not acceptance timing.'},
                   boundaries={'live_server': False, 'listener_control': 'fixture OpenPort(none), loopback-only daemon, no webclient; socket absence not measured', 'max_concurrency': 1},
                   missing_evidence=['native compilation', 'RSS/private memory', 'fresh-process restore'])
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2))
    return receipt


def proc_memory(pid: int, proc_root: Path = Path('/proc')):
    """Return optional kernel samples; RSS/HWM and private/PSS stay distinct."""
    result = {}
    for filename, fields in (
        ('status', {'VmRSS': 'rss_bytes', 'VmHWM': 'hwm_bytes', 'VmSize': 'virtual_bytes'}),
        ('smaps_rollup', {'Pss': 'pss_bytes', 'Private_Clean': 'private_clean_bytes',
                          'Private_Dirty': 'private_dirty_bytes'})):
        try: source = (proc_root / str(pid) / filename).read_text()
        except (FileNotFoundError, ProcessLookupError, PermissionError): continue
        for line in source.splitlines():
            key, _, value = line.partition(':')
            if key in fields:
                match = re.fullmatch(r'\s*(\d+)\s+kB\s*', value)
                if match: result[fields[key]] = int(match.group(1)) * 1024
    if 'private_clean_bytes' in result and 'private_dirty_bytes' in result:
        result['private_bytes'] = result['private_clean_bytes'] + result['private_dirty_bytes']
    return result


def limit_reason(now, started, job_deadline, rss_bytes, limits):
    if now >= job_deadline: return 'job_timeout'
    if now - started >= limits.case_seconds: return 'case_timeout'
    if rss_bytes is not None and rss_bytes > limits.rss_mib * 1024 * 1024: return 'rss_limit'
    return None


def bound_address_space(limit_bytes):
    """Executed only in the new test child before exec; not the calling process."""
    import resource
    resource.setrlimit(resource.RLIMIT_AS, (limit_bytes, limit_bytes))


def run_monitored(command, cwd: Path, prefix: str, limits: Limits, job_deadline):
    """Sequential subprocess custody. Only this call's child can be terminated."""
    started = time.monotonic()
    if started >= job_deadline:
        summary = dict(command=command, status='not_started_job_timeout', samples=0, returncode=None, peaks={}, elapsed=0)
        (cwd / f'{prefix}.log').write_text('')
        (cwd / f'{prefix}-memory.jsonl').write_text('')
        (cwd / f'{prefix}-summary.json').write_text(json.dumps(summary, indent=2))
        return summary
    summary = dict(command=command, status='running', samples=0, peaks={},
                   address_space_limit_bytes=limits.rss_mib * 1024 * 1024)
    with (cwd / f'{prefix}.log').open('w') as log, (cwd / f'{prefix}-memory.jsonl').open('w') as samples:
        child = subprocess.Popen(command, cwd=cwd, stdout=log, stderr=subprocess.STDOUT,
                                 stdin=subprocess.DEVNULL, start_new_session=True,
                                 preexec_fn=lambda: bound_address_space(limits.rss_mib * 1024 * 1024))
        summary['pid'] = child.pid
        reason = None
        try:
            while True:
                now = time.monotonic()
                memory = proc_memory(child.pid)
                sample = dict(monotonic=now, elapsed=now-started, pid=child.pid, **memory)
                samples.write(json.dumps(sample) + '\n'); samples.flush()
                summary['samples'] += 1
                for key, value in memory.items():
                    summary['peaks'][key] = max(value, summary['peaks'].get(key, 0))
                returncode = child.poll()
                if returncode is not None:
                    summary['returncode'] = returncode
                    break
                reason = limit_reason(now, started, job_deadline, memory.get('rss_bytes'), limits)
                if not reason and 'rss_bytes' not in memory and now - started >= 1:
                    reason = 'memory_sampling_unavailable'
                if reason:
                    child.kill(); child.wait(timeout=2)
                    summary['returncode'] = child.returncode
                    # /proc can disappear between sampling and poll while the
                    # child is exiting. Do not add a grace period: kill/wait
                    # still happens immediately. A reaped zero exit proves the
                    # kill did not terminate a live child; require earlier RSS
                    # and never forgive a time or resource limit.
                    if reason == 'memory_sampling_unavailable' and child.returncode == 0 and 'rss_bytes' in summary['peaks']:
                        summary['sampling_exit_race'] = True
                        summary['sampling_observed_reason'] = reason
                        reason = None
                    break
                time.sleep(limits.sample_ms / 1000)
        finally:
            if child.poll() is None:
                child.kill(); child.wait(timeout=2)
        summary['elapsed'] = time.monotonic() - started
        summary['status'] = reason or ('exited' if summary.get('returncode') == 0 else 'process_failed')
    (cwd / f'{prefix}-summary.json').write_text(json.dumps(summary, indent=2))
    return summary


def verify_runtime(byond_bin: Path, byond_archive: Path):
    """Passive exact-byte check; call immediately before every native launch."""
    spec = importlib.util.spec_from_file_location('moving_save_byond_runtime', ROOT / 'scripts/byond_runtime.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    identity = module.verify_linux(byond_bin, byond_archive)
    if identity['version'] != VERSION: raise ValueError('Benchmark runtime version differs from reviewed pin')
    return identity


def compile_ok(summary, log, dmb: Path):
    if summary['status'] != 'exited' or summary.get('returncode') != 0 or not dmb.is_file() or len(log.encode()) > 8 * 1024 * 1024 or DIAGNOSTIC.search(log):
        return False
    lines = log.splitlines()
    banners = [line for line in lines if re.search('DM compiler version', line, re.I)]
    results = [line for line in lines if re.search(r'\berrors?\b|\bwarnings?\b', line, re.I)]
    expected = re.escape(dmb.name) + r' - 0 errors, 0 warnings(?: \(\d{1,2}/\d{1,2}/\d{2,4} \d{1,2}:\d{2}(?::\d{2})? (?:am|pm)\))?'
    return (banners == ['DM compiler version ' + VERSION] and len(results) == 1
            and re.fullmatch(expected, results[0]) is not None
            and lines.index(banners[0]) < lines.index(results[0]))


def native_phases(log):
    found = {}
    for line in log.splitlines():
        if 'BENCHMARK_PHASE ' not in line: continue
        try: row = json.loads(line.split('BENCHMARK_PHASE ', 1)[1])
        except (ValueError, TypeError): continue
        found[json.dumps(row, sort_keys=True)] = row
    return list(found.values())


def phase_contract(phases, baseline):
    observed = {(row.get('attempt'), row.get('phase')) for row in phases}
    expected = {(attempt, 'after_success_cleanup') for attempt in (1, 2, 3, 7)}
    expected |= {(attempt, 'after_refusal_cleanup') for attempt in (4, 5, 6)}
    expected |= {(attempt, phase) for attempt in range(1, 8) for phase in ('roster_start', 'roster_end')}
    return (expected <= observed and any(row.get('phase') == 'complete' for row in phases)
            and all(bool(row.get('baseline')) == bool(baseline) for row in phases))


def run_native(output: Path, byond_bin: Path, byond_archive: Path, limits: Limits):
    limits.validate()
    if not sys.platform.startswith('linux'): raise ValueError('This sampler supports Linux only')
    compiler, daemon = byond_bin / 'DreamMaker', byond_bin / 'DreamDaemon'
    if not compiler.is_file() or not daemon.is_file(): raise ValueError('Explicit BYOND binary directory is incomplete')
    started = time.monotonic(); deadline = started + limits.job_seconds
    receipt = json.loads((output / 'receipt.json').read_text())
    selected_cases = receipt['cases']
    receipt.update(execution='running', limits=vars(limits), compiler=str(compiler), daemon=str(daemon),
                   memory_limit_note='RLIMIT_AS is a stricter virtual-address ceiling in addition to sampled RSS; limit refusal is failure/inconclusive, not a memory pass',
                   timing_note='Logical-counter instrumentation consumes capture budget; phase logging occurs after detach; timings are instrumented, not uninstrumented production timing')
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2))
    receipt['compile_runtime_identity'] = verify_runtime(byond_bin, byond_archive)
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2))
    build = run_monitored([str(compiler), '-max_errors', '0', 'benchmark.dme'], output, 'compile', limits, deadline)
    log = (output / 'compile.log').read_text() if (output / 'compile.log').exists() else ''
    if not compile_ok(build, log, output / 'benchmark.dmb'):
        receipt.update(execution='compile_failed', compile=build)
        (output / 'receipt.json').write_text(json.dumps(receipt, indent=2))
        return receipt
    baseline_folder = output / 'baseline-source'
    receipt['baseline_compile_runtime_identity'] = verify_runtime(byond_bin, byond_archive)
    baseline_build = run_monitored([str(compiler), '-max_errors', '0', 'benchmark.dme'], baseline_folder, 'compile', limits, deadline)
    baseline_log = (baseline_folder / 'compile.log').read_text() if (baseline_folder / 'compile.log').exists() else ''
    if not compile_ok(baseline_build, baseline_log, baseline_folder / 'benchmark.dmb'):
        receipt.update(execution='baseline_compile_failed', compile=build, baseline_compile=baseline_build)
        (output / 'receipt.json').write_text(json.dumps(receipt, indent=2))
        return receipt
    results = []
    for index, case in enumerate(selected_cases):
        if time.monotonic() >= deadline:
            results.append(dict(case=case, status='not_started_job_timeout')); continue
        folder = output / f'case-{index:02d}-{case["count"]}-{case["payload"]}-{case["baseline"]}'
        folder.mkdir()
        artifact_source = baseline_folder if case['baseline'] else output
        for name in ('benchmark.dmb', 'benchmark.rsc'):
            if (artifact_source / name).exists(): shutil.copy2(artifact_source / name, folder / name)
        params = '&'.join(f'{key}={value}' for key, value in case.items())
        identity = verify_runtime(byond_bin, byond_archive)
        (folder / 'runtime-identity.json').write_text(json.dumps(identity, indent=2))
        result = run_monitored([str(daemon), 'benchmark.dmb', '-trusted', '-ip', '127.0.0.1', '-nowebclient', '-log', 'runtime.log', '-params', params], folder, 'daemon', limits, deadline)
        native_log = ''.join((folder / name).read_text() for name in ('daemon.log', 'runtime.log', 'errors.txt') if (folder / name).exists())
        marker = (folder / 'result.txt').read_text().strip() if (folder / 'result.txt').exists() else None
        diagnostics = bool(DIAGNOSTIC.search(native_log)) or ((folder / 'errors.txt').exists() and bool((folder / 'errors.txt').read_text().strip()))
        phases = native_phases(native_log)
        contract_ok = phase_contract(phases, case['baseline'])
        admitted = max((row.get('roster', 0) for row in phases), default=0)
        result.update(case=case, marker=marker, native_diagnostics=diagnostics, phases=phases, phase_contract=contract_ok,
                      admitted_roots=admitted, fallback_roots=case['count']-admitted,
                      passed=result['status'] == 'exited' and result.get('returncode') == 0 and marker == 'PASS' and not diagnostics and contract_ok and 'rss_bytes' in result.get('peaks', {}))
        results.append(result)
        (output / 'results.json').write_text(json.dumps(results, indent=2))
    receipt.update(execution='passed' if len(results) == len(selected_cases) and all(r.get('passed') for r in results) else 'failed_or_incomplete',
                   compile=build, baseline_compile=baseline_build, results=results, elapsed=time.monotonic()-started,
                   memory_acceptance='not_established',
                   missing_evidence=['fresh-process restore', 'representative full-game workload', 'agreed latency and memory acceptance threshold'])
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2))
    return receipt


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--profile-datums', action='store_true', help='Opt-in copied-packet native reference timing; not acceptance evidence')
    parser.add_argument('--diagnostic-subset', action='store_true', help='Four candidate-only diagnostic cases; not comparative evidence')
    parser.add_argument('--run-native', action='store_true', help='Explicitly compile and run isolated native fixture; requires separate authorization')
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--byond-archive', type=Path)
    parser.add_argument('--case-timeout', type=float, default=90)
    parser.add_argument('--job-timeout', '--job-seconds', dest='job_timeout', type=float, default=1200)
    parser.add_argument('--rss-limit-mib', type=int, default=1024)
    parser.add_argument('--sample-ms', type=int, default=20)
    args = parser.parse_args(argv)
    limits = Limits(args.case_timeout, args.job_timeout, args.rss_limit_mib, args.sample_ms)
    try: limits.validate()
    except ValueError as error: parser.error(str(error))
    if args.run_native and (not args.byond_bin or not args.byond_archive or not args.output): parser.error('--run-native requires --byond-bin, --byond-archive and --output')
    output = args.output.resolve() if args.output else Path(tempfile.mkdtemp(prefix='civ13-moving-save-benchmark-'))
    receipt = prepare(output, args.diagnostic_subset, args.profile_datums)
    if args.run_native:
        try:
            receipt = run_native(output, args.byond_bin.absolute(), args.byond_archive.absolute(), limits)
        except Exception as error:
            receipt = json.loads((output / 'receipt.json').read_text())
            receipt.update(execution='harness_error', error=f'{type(error).__name__}: {error}')
            (output / 'receipt.json').write_text(json.dumps(receipt, indent=2))
    print(json.dumps({'output': str(output), 'execution': receipt['execution']}))
    return 0 if receipt['execution'] in ('not_run', 'passed') else 1

if __name__ == '__main__':
    raise SystemExit(main())
