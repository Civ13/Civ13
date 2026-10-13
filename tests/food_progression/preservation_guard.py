"""Own one gated audit in a kill-on-close Windows job, including descendants."""
import argparse
import ctypes as C
from ctypes import wintypes as W
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import uuid
from guard_cleanup import finish_owned_run

class MemoryStatus(C.Structure):
    _fields_ = [('length', W.DWORD), ('load', W.DWORD)] + [(n, C.c_ulonglong) for n in
                ('total', 'available', 'page_total', 'page_available', 'virtual_total', 'virtual_available', 'extended')]

class Counters(C.Structure):
    _fields_ = [('size', W.DWORD), ('faults', W.DWORD)] + [(n, C.c_size_t) for n in
                ('peak_working', 'working', 'peak_paged', 'paged', 'peak_nonpaged', 'nonpaged', 'page', 'peak_page', 'private')]

class BasicLimits(C.Structure):
    _fields_ = [('process_time', C.c_longlong), ('job_time', C.c_longlong), ('flags', W.DWORD),
                ('min_working', C.c_size_t), ('max_working', C.c_size_t), ('active', W.DWORD),
                ('affinity', C.c_size_t), ('priority', W.DWORD), ('scheduling', W.DWORD)]

class IoCounters(C.Structure):
    _fields_ = [(n, C.c_ulonglong) for n in ('read_ops', 'write_ops', 'other_ops', 'read_bytes', 'write_bytes', 'other_bytes')]

class ExtendedLimits(C.Structure):
    _fields_ = [('basic', BasicLimits), ('io', IoCounters)] + [(n, C.c_size_t) for n in
                ('process_memory', 'job_memory', 'peak_process', 'peak_job')]

class JobPids(C.Structure):
    _fields_ = [('assigned', W.DWORD), ('count', W.DWORD), ('pids', C.c_size_t * 512)]

k = C.WinDLL('kernel32', use_last_error=True)
p = C.WinDLL('psapi', use_last_error=True)
for name, args, result in (
    ('CreateJobObjectW', [W.LPVOID, W.LPCWSTR], W.HANDLE),
    ('OpenProcess', [W.DWORD, W.BOOL, W.DWORD], W.HANDLE),
    ('CloseHandle', [W.HANDLE], W.BOOL),
    ('SetInformationJobObject', [W.HANDLE, C.c_int, W.LPVOID, W.DWORD], W.BOOL),
    ('AssignProcessToJobObject', [W.HANDLE, W.HANDLE], W.BOOL),
    ('QueryInformationJobObject', [W.HANDLE, C.c_int, W.LPVOID, W.DWORD, W.LPVOID], W.BOOL),
    ('TerminateJobObject', [W.HANDLE, W.UINT], W.BOOL),
    ('GlobalMemoryStatusEx', [C.POINTER(MemoryStatus)], W.BOOL),
):
    function = getattr(k, name)
    function.argtypes, function.restype = args, result
p.GetProcessMemoryInfo.argtypes = [W.HANDLE, C.POINTER(Counters), W.DWORD]
p.GetProcessMemoryInfo.restype = W.BOOL

def utc():
    return datetime.now(timezone.utc).isoformat()

def free_bytes():
    value = MemoryStatus()
    value.length = C.sizeof(value)
    if not k.GlobalMemoryStatusEx(C.byref(value)):
        raise OSError(C.get_last_error())
    return value.available

def pids(job):
    value = JobPids()
    if not k.QueryInformationJobObject(job, 3, C.byref(value), C.sizeof(value), None):
        raise OSError(C.get_last_error())
    if value.assigned > 512 or value.count > 512:
        raise RuntimeError('Owned process inventory exceeded bound')
    return list(value.pids[:value.count])

def private(pid):
    handle = k.OpenProcess(0x1000, False, pid)
    if not handle:
        return None
    try:
        value = Counters()
        value.size = C.sizeof(value)
        return value.private if p.GetProcessMemoryInfo(handle, C.byref(value), C.sizeof(value)) else None
    finally:
        k.CloseHandle(handle)

parser = argparse.ArgumentParser()
parser.add_argument('--inspect', action='store_true')
parser.add_argument('--preservation-control', choices=('nutrition', 'age', 'conversion'))
parser.add_argument('--probe', choices=('preservation', 'rack-save'), default='preservation')
parser.add_argument('--rack-control', choices=('coverage', 'runtime', 'storage', 'stale-wait', 'duplicate', 'conversion'))
parser.add_argument('--directory', type=Path)
parser.add_argument('--byond-bin', type=Path)
parser.add_argument('--timeout', type=int, default=180)
args = parser.parse_args()
if args.inspect:
    print(json.dumps({'utc': utc(), 'available_physical': free_bytes(), 'watcher_private': private(os.getpid())}))
    sys.exit(0)
if not args.directory or not args.byond_bin or not args.byond_bin.is_absolute() or not args.byond_bin.is_dir() or not 20 <= args.timeout <= 180:
    parser.error('Unique output directory, absolute SDK executable and total deadline 20-180 seconds required')
start, started = time.monotonic(), utc()
overall_deadline = start + args.timeout
execution_deadline = overall_deadline - 12  # Reserve termination, file cleanup and receipt time.
out = args.directory.resolve()
if out.exists():
    raise RuntimeError('Use a new owner-specific output directory')
floor, cap = 6 * 1024**3, 2 * 1024**3
if free_bytes() < floor:
    raise RuntimeError('Host free physical memory below 6 GiB; audit not started')
out.mkdir(parents=True)
work = out / 'evidence'  # Retain outputs in place; no unbounded copy or recursive cleanup.
work.mkdir()
stem = '.food_progression_' + uuid.uuid4().hex
command = [sys.executable, str(Path(__file__).with_name('preservation_run.py')), '--byond-bin', str(args.byond_bin),
           '--output', str(work), '--stem', stem, '--start-gated']
if args.preservation_control:
    command += ['--preservation-control', args.preservation_control]
if args.probe != 'preservation':
    command += ['--probe', args.probe]
if args.rack_control:
    command += ['--rack-control', args.rack_control]
child, job, assigned, reason = None, None, False, None
peak, lowest = 0, free_bytes()
try:
    job = k.CreateJobObjectW(None, None)
    if not job:
        raise OSError(C.get_last_error(), 'CreateJobObjectW failed')
    limits = ExtendedLimits()
    limits.basic.flags = 0x2200  # KILL_ON_JOB_CLOSE | JOB_MEMORY: hard aggregate commit cap
    limits.job_memory = cap
    if not k.SetInformationJobObject(job, 9, C.byref(limits), C.sizeof(limits)):
        raise OSError(C.get_last_error(), 'SetInformationJobObject failed')
    if time.monotonic() >= execution_deadline:
        raise TimeoutError('Execution budget exhausted before launch')
    with (out / 'watchdog-process.log').open('w', encoding='utf-8') as log, (out / 'resource-trace.jsonl').open('w', encoding='utf-8') as trace:
        child = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=log, stderr=subprocess.STDOUT, creationflags=0x08000000)
        if not k.AssignProcessToJobObject(job, W.HANDLE(child._handle)):
            raise OSError(C.get_last_error(), 'Unable to assign gated root to owned job')
        assigned = True
        if time.monotonic() >= execution_deadline:
            raise TimeoutError('Execution budget exhausted before gated release')
        child.stdin.write(b'start\n')
        child.stdin.close()
        while True:
            inventory = pids(job)
            values = {pid: private(pid) for pid in inventory}
            unknown = [pid for pid, value in values.items() if value is None]
            if unknown:
                fresh = pids(job)
                unknown = [pid for pid in unknown if pid in fresh]
            total = sum(value for value in values.values() if value is not None)
            available, elapsed = free_bytes(), time.monotonic() - start
            peak, lowest = max(peak, total), min(lowest, available)
            trace.write(json.dumps({'utc': utc(), 'seconds': elapsed, 'owned_private': total,
                                   'host_free': available, 'owned_pids': inventory, 'unmeasured_pids': unknown}) + '\n')
            trace.flush()
            if time.monotonic() >= execution_deadline or total > cap or available < floor or unknown:
                reason = 'execution-deadline' if time.monotonic() >= execution_deadline else 'owned-private-cap' if total > cap else 'host-free-floor' if available < floor else 'unmeasured-owned-process'
                break
            if child.poll() is not None:
                if pids(job):
                    reason = 'descendants-survived-root'
                break
            time.sleep(min(0.5, max(0, execution_deadline - time.monotonic())))
except Exception as exc:
    reason = 'guard-error: ' + str(exc)
finally:
    def terminate_owned():
        if child and not assigned and child.poll() is None:
            child.terminate()  # The gated root has not launched any descendants.
        if job and not k.TerminateJobObject(job, 137):
            raise OSError(C.get_last_error(), 'TerminateJobObject failed')
        return True

    def write_receipt(value):
        value['exit'] = child.returncode if child else None
        value['overall_deadline_reached'] = time.monotonic() >= overall_deadline
        try:
            (out / 'watchdog-receipt.json').write_text(json.dumps(value, indent=2), encoding='utf-8')
        except Exception as exc:
            value['receipt_write_error'] = str(exc)
        finally:
            if time.monotonic() >= overall_deadline:
                value['overall_deadline_reached'] = True
            print(json.dumps(value), flush=True)

    repo = Path(__file__).resolve().parents[2]
    paths = [repo / (stem + suffix) for suffix in ('.dme', '_world.dm', '_globals.dm', '_farming.dm', '_floor.dm', '_persistence.dm', '_food.dm', '_production.dm', '.dmb', '.rsc')]
    receipt = finish_owned_run(
        receipt={'started_utc': started, 'owned_root_pid': child.pid if child else None,
                 'stop_reason': reason, 'peak_owned_private': peak, 'lowest_host_free': lowest,
                 'private_cap': cap, 'host_free_floor': floor, 'command': command,
                 'total_timeout_seconds': args.timeout, 'cleanup_reserve_seconds': 12,
                 'evidence_directory': str(work), 'runtime_installation': 'unchanged'},
        terminate=terminate_owned, inventory=lambda: pids(job) if job else [],
        close_job=lambda: bool(k.CloseHandle(job)) if job else True, child=child,
        paths=paths, unlink=lambda path: path.unlink(missing_ok=True),
        deadline=overall_deadline - 2,
        process_deadline=min(time.monotonic() + 6, overall_deadline - 4),
        started=start, utc=utc, write_receipt=write_receipt)
sys.exit(1 if reason or receipt.get('cleanup_error') or receipt.get('receipt_write_error') or receipt.get('overall_deadline_reached') or not child else child.returncode)
