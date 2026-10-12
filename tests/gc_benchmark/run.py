"""Compare actual collector sources in a closed native runtime, without game startup."""
import argparse
import ctypes
from ctypes import wintypes
import hashlib
import json
import os
import re
from pathlib import Path
import statistics
import subprocess
import time

BASELINE = '7cfa850bd9d2788dcbb9fd35f5c5915ccb528dd2'

class Memory(ctypes.Structure):
    _fields_ = [('cb', wintypes.DWORD), ('PageFaultCount', wintypes.DWORD)] + [(n, ctypes.c_size_t) for n in ('PeakWorkingSetSize', 'WorkingSetSize', 'QuotaPeakPagedPoolUsage', 'QuotaPagedPoolUsage', 'QuotaPeakNonPagedPoolUsage', 'QuotaNonPagedPoolUsage', 'PagefileUsage', 'PeakPagefileUsage', 'PrivateUsage')]

def sample(process):
    memory = Memory()
    memory.cb = ctypes.sizeof(memory)
    handle = wintypes.HANDLE(int(process._handle))
    api = ctypes.WinDLL('psapi', use_last_error=True).GetProcessMemoryInfo
    api.argtypes = [wintypes.HANDLE, ctypes.POINTER(Memory), wintypes.DWORD]
    if not api(handle, ctypes.byref(memory), memory.cb):
        raise ctypes.WinError(ctypes.get_last_error())
    times = [wintypes.FILETIME() for _ in range(4)]
    api = ctypes.WinDLL('kernel32', use_last_error=True).GetProcessTimes
    api.argtypes = [wintypes.HANDLE] + [ctypes.POINTER(wintypes.FILETIME)] * 4
    if not api(handle, *[ctypes.byref(t) for t in times]):
        raise ctypes.WinError(ctypes.get_last_error())
    cpu = sum((t.dwHighDateTime << 32) | t.dwLowDateTime for t in times[2:]) / 10_000_000
    return {'cpu_seconds': cpu, 'rss_bytes': memory.WorkingSetSize, 'private_bytes': memory.PrivateUsage}

def run(root, output, byond, variant, repetitions, batches, negative=None):
    output.mkdir()
    header = (root/'tests/memory_ownership/probe.dm').read_text().split('/world/New()')[0]
    header = header.replace('#define PROCESS_PRIORITY_HIGH 1\n#define PROCESS_PRIORITY_VERY_HIGH 2\n#define PROCESS_TICK_CHECK', '#include "../../code/processes/___defines.dm"')
    header = header.replace('/process\n', '/process\n\tvar/run_time_tick_usage = 0\n\tvar/run_time_tick_usage_allowance = 100\n', 1)
    source = header.replace('../../code/', root.as_posix()+'/code/')
    body = (root/'code/processes/garbage.dm').read_bytes()
    if variant == 'baseline':
        body = subprocess.check_output(['git', 'show', BASELINE+':code/processes/garbage.dm'], cwd=root)
    # Copied collector sources still resolve sibling helpers in the checkout.
    body = re.sub(rb'(#include\s+")([^"/\\]+\.dm)(")',
                  lambda match: match[1] + (root/'code/processes'/match[2].decode()).as_posix().encode() + match[3], body)
    expected = None
    if negative == 'budget-return':
        source = source.replace('#include \"' + root.as_posix() + '/code/processes/___defines.dm\"', '#include \"' + root.as_posix() + '/code/processes/___defines.dm\"\n#undef PROCESS_TICK_CHECK\n#define PROCESS_TICK_CHECK')
        expected = 'actual production macro returns early on budget'
    elif negative == 'hard-cap':
        body = body.replace(b'#define GC_FORCE_DEL_PER_RUN 30', b'#define GC_FORCE_DEL_PER_RUN 31', 1)
        expected = 'hard budget remains thirty'
    elif negative == 'candidate-cap':
        body = body.replace(b'#define GC_COLLECTIONS_PER_RUN 300', b'#define GC_COLLECTIONS_PER_RUN 301', 1)
        expected = 'mixed first pass preserves forced and candidate budgets'
    collector = output/'garbage.dm'
    collector.write_bytes(body)
    source = source.replace(root.as_posix()+'/code/processes/garbage.dm', collector.as_posix())
    source += (root/'tests/gc_benchmark/probe.dm').read_text()
    (output/'probe.dme').write_text(source)
    pending = [output/'probe.dme']
    source_hashes = {}
    while pending:
        included = pending.pop().resolve()
        if str(included) in source_hashes:
            continue
        data = included.read_bytes()
        source_hashes[str(included)] = hashlib.sha256(data).hexdigest()
        clean = re.sub(r'/\*.*?\*/', '', data.decode('utf-8-sig'), flags=re.S)
        for child in re.findall(r'^\s*#include\s+"([^"]+)"', clean, re.M):
            pending.append(included.parent/child)
    (output/'source-hashes.json').write_text(json.dumps(source_hashes, indent=2))
    build = subprocess.run([str(byond/'dm.exe'), '-max_errors', '0', str(output/'probe.dme')], cwd=output, capture_output=True, text=True, timeout=60, creationflags=subprocess.CREATE_NO_WINDOW)
    log = build.stdout + build.stderr
    (output/'compile.log').write_text(log)
    if build.returncode or '516.1681' not in log or '0 errors, 0 warnings' not in log:
        raise RuntimeError(log)
    params = f'repetitions={repetitions}&batches={batches}' + ('&baseline=1' if variant == 'baseline' else '')
    command = [str(byond/'dd.exe'), str(output/'probe.dmb'), '-invisible', '-close', '-safe', '-log', 'runtime.log', '-params', params]
    rows = []
    with (output/'daemon.log').open('w') as daemon:
        process = subprocess.Popen(command, cwd=output, stdout=daemon, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
        deadline = time.monotonic() + 180
        index, before, began = 1, None, None
        peak_rss = peak_private = 0
        try:
            while process.poll() is None:
                if time.monotonic() > deadline:
                    raise TimeoutError('collector runtime exceeded 180 seconds')
                observed = sample(process)
                peak_rss = max(peak_rss, observed['rss_bytes'])
                peak_private = max(peak_private, observed['private_bytes'])
                if before is None and (output/f'begin-{index}.txt').exists():
                    before, began = observed, time.perf_counter()
                    (output/f'ack-{index}.txt').write_text('ready')
                end = output/f'end-{index}.json'
                if before is not None and end.exists():
                    after = sample(process)
                    row = json.loads(end.read_text())
                    row.update({'cpu_seconds': after['cpu_seconds'] - before['cpu_seconds'], 'handshake_wall_seconds': time.perf_counter() - began, 'rss_before_bytes': before['rss_bytes'], 'rss_after_bytes': after['rss_bytes'], 'private_before_bytes': before['private_bytes'], 'private_after_bytes': after['private_bytes']})
                    rows.append(row)
                    (output/f'end-ack-{index}.txt').write_text('read')
                    index, before = index+1, None
                time.sleep(0.005)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
    result = (output/'result.txt').read_text()
    runtime = (output/'runtime.log').read_text(errors='replace') + (output/'daemon.log').read_text(errors='replace')
    if process.returncode or (not expected and not result.startswith('PASS:')) or any(x in runtime.lower() for x in ('runtime error', 'bad ref', 'badref', 'bad loc', '## bug', 'cannot read null', 'cannot execute null', 'fatal error')):
        raise RuntimeError(result+'\n'+runtime)
    if expected:
        if result.strip() != 'FAIL: ' + expected:
            raise RuntimeError('Negative control missed expected assertion: ' + result)
        record = {'negative_control': negative, 'assertion_result': result.strip(), 'detected': True}
        (output/'measurements.json').write_text(json.dumps(record, indent=2))
        return record
    if len(rows) != repetitions*3:
        raise RuntimeError('Missing measured repetitions')
    record = {'variant': variant, 'collector_sha256': hashlib.sha256(body).hexdigest(), 'assertion_result': result.strip(), 'peak_sampled_rss_bytes': peak_rss, 'peak_sampled_private_bytes': peak_private, 'rows': rows}
    (output/'measurements.json').write_text(json.dumps(record, indent=2))
    return record

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--byond-bin', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--repetitions', type=int, default=5)
    p.add_argument('--batches', type=int, default=50)
    p.add_argument('--negative-control', choices=('budget-return', 'hard-cap', 'candidate-cap'))
    a = p.parse_args()
    if os.name != 'nt':
        raise RuntimeError('This comparative sampler requires Windows native process counters')
    if a.repetitions < 5 or a.batches < 1:
        raise RuntimeError('At least five repetitions and one batch required')
    root = Path(__file__).resolve().parents[2]
    a.output = a.output.resolve()
    a.output.mkdir(parents=True, exist_ok=True)
    if any(a.output.iterdir()):
        raise RuntimeError('Fresh evidence directory required')
    metadata = {'head_sha': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(), 'baseline_sha': BASELINE, 'byond': '516.1681', 'repetitions': a.repetitions, 'batches': a.batches, 'scope': 'isolated native production collector, same current pool support; no world startup', 'timing': 'CPU delta brackets collector with file acknowledgement overhead; wall includes polling and at most one native tick acknowledgement wait; Reported modulo elapsed_deciseconds is truncated to whole 100ms units; native timeofday can contain fractional deciseconds. RSS/private are sampled process storage, not retained object counts.', 'checkout_status': subprocess.check_output(['git', 'status', '--porcelain'], cwd=root, text=True), 'budget_macro': 'exact production ___defines.dm PROCESS_TICK_CHECK; throughput priority VERY_HIGH bypasses budget return; separate assertion exercises genuine early return and resumption'}
    (a.output/'metadata.json').write_text(json.dumps(metadata, indent=2))
    (a.output/'tested.patch').write_bytes(subprocess.check_output(['git','diff','HEAD'],cwd=root))
    for name in ('run.py','probe.dm'):
        (a.output/name).write_bytes((root/'tests/gc_benchmark'/name).read_bytes())
    if a.negative_control:
        print(json.dumps(run(root, a.output/'current', a.byond_bin, 'current', a.repetitions, a.batches, a.negative_control)))
        return
    records = [run(root, a.output/v, a.byond_bin, v, a.repetitions, a.batches) for v in ('baseline', 'current')]
    summary = []
    for record in records:
        for mode in ('soft', 'hard', 'mixed'):
            rows = [r for r in record['rows'] if r['mode'] == mode]
            summary.append({'variant': record['variant'], 'mode': mode, 'records': rows[0]['records'], 'passes': [r['passes'] for r in rows], 'first_drained': [r['first_drained'] for r in rows], 'median_cpu_seconds': statistics.median(r['cpu_seconds'] for r in rows), 'median_handshake_wall_seconds': statistics.median(r['handshake_wall_seconds'] for r in rows), 'elapsed_deciseconds': [r['elapsed_deciseconds'] for r in rows], 'rss_after_bytes': [r['rss_after_bytes'] for r in rows]})
    (a.output/'summary.json').write_text(json.dumps(summary, indent=2))
    print(json.dumps(summary, indent=2))
    print('Evidence:', a.output)

if __name__ == '__main__':
    main()
