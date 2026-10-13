"""SOURCE ONLY, UNRUN: own one gated offline oracle in a bounded Windows Job.

API structures/free_bytes reuse the reviewed savefile_cleanup guard mechanics.
No compiler, native game, library install or foreign guard execution is supported.
"""
import argparse
import ctypes as C
from ctypes import wintypes as W
from datetime import datetime, timezone
from hashlib import sha256
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time


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


FLOOR = 6 * 1024**3
CAP = 256 * 1024**2
DEADLINE = 60
POLL = 0.1


def utc():
    return datetime.now(timezone.utc).isoformat()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', required=True, type=Path)
    parser.add_argument('--source-head', required=True)
    parser.add_argument('--oracle-sha256', required=True)
    args = parser.parse_args()
    if os.name != 'nt' or not args.directory.is_absolute():
        parser.error('Windows and an absolute new owner-specific output directory required')
    if not re.fullmatch(r'[0-9a-f]{40}', args.source_head) or not re.fullmatch(r'[0-9a-f]{64}', args.oracle_sha256):
        parser.error('Exact reviewed commit and raw oracle SHA-256 required')
    script = Path(__file__).resolve()
    oracle = script.with_name('test_generation_contract.py')
    # Capture exactly the verified bytes. The gated child executes this private copy.
    source = oracle.read_bytes()
    if sha256(source).hexdigest() != args.oracle_sha256:
        raise RuntimeError('Oracle source differs from reviewed bytes')
    out = args.directory.resolve()
    if out.exists():
        raise RuntimeError('Output directory must be new')

    k = C.WinDLL('kernel32', use_last_error=True)
    p = C.WinDLL('psapi', use_last_error=True)
    for name, arguments, result in (
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
        function.argtypes, function.restype = arguments, result
    p.GetProcessMemoryInfo.argtypes = [W.HANDLE, C.POINTER(Counters), W.DWORD]
    p.GetProcessMemoryInfo.restype = W.BOOL

    def free_bytes():
        value = MemoryStatus()
        value.length = C.sizeof(value)
        if not k.GlobalMemoryStatusEx(C.byref(value)):
            raise OSError(C.get_last_error(), 'GlobalMemoryStatusEx failed')
        return value.available

    def pids(job):
        value = JobPids()
        if not k.QueryInformationJobObject(job, 3, C.byref(value), C.sizeof(value), None):
            raise OSError(C.get_last_error(), 'Owned PID query failed')
        if value.assigned > 512 or value.count > 512:
            raise RuntimeError('Owned PID inventory exceeds bound')
        return list(value.pids[:value.count])

    def memory(pid):
        handle = k.OpenProcess(0x1000, False, pid)
        if not handle:
            return None
        try:
            value = Counters()
            value.size = C.sizeof(value)
            return (value.private, value.working) if p.GetProcessMemoryInfo(handle, C.byref(value), C.sizeof(value)) else None
        finally:
            if not k.CloseHandle(handle):
                raise OSError(C.get_last_error(), 'Process handle close failed')

    started, start = utc(), time.monotonic()
    child, job, assigned, work = None, None, False, None
    reason, cleanup_errors, command = None, [], None
    peak_private, peak_working, lowest = 0, 0, None
    try:
        available = free_bytes()
        lowest = available
        if available < FLOOR:
            raise RuntimeError('Host free physical memory below 6 GiB; oracle not started')
        # mkdir without exist_ok refuses a concurrent creator. Never remove out.
        out.mkdir()
        candidate_work = out / 'owned-temporary'
        candidate_work.mkdir()
        work = candidate_work  # cleanup owns only a directory created successfully
        frozen = work / 'test_generation_contract.py'
        frozen.write_bytes(source)
        job = k.CreateJobObjectW(None, None)
        if not job:
            raise OSError(C.get_last_error(), 'Job creation failed')
        limits = ExtendedLimits()
        limits.basic.flags = 0x2208  # kill-on-close, hard aggregate commit, one process
        limits.basic.active = 1
        limits.job_memory = CAP
        if not k.SetInformationJobObject(job, 9, C.byref(limits), C.sizeof(limits)):
            raise OSError(C.get_last_error(), 'Job limits failed')
        # No oracle import, parsing or execution before successful Job assignment.
        gate = "import sys,runpy; token=sys.stdin.buffer.readline(16); sys.exit(125) if token!=b'start\\n' else None; path=sys.argv[1]; sys.argv=[path,'-v']; runpy.run_path(path,run_name='__main__')"
        command = [sys.executable, '-I', '-B', '-c', gate, str(frozen)]
        environment = os.environ.copy()
        for name in ('TEMP', 'TMP', 'TMPDIR'):
            environment[name] = str(work)
        with (out / 'oracle.log').open('w', encoding='utf-8') as log, (out / 'resource-trace.jsonl').open('w', encoding='utf-8') as trace:
            if time.monotonic() - start >= DEADLINE:
                raise RuntimeError('Deadline reached before child launch')
            if free_bytes() < FLOOR:
                raise RuntimeError('Host floor lost before child launch')
            child = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=log, stderr=subprocess.STDOUT,
                                     cwd=work, env=environment, creationflags=0x08000000)
            if not k.AssignProcessToJobObject(job, W.HANDLE(child._handle)):
                raise OSError(C.get_last_error(), 'Gated root Job assignment failed')
            assigned = True
            if time.monotonic() - start >= DEADLINE or free_bytes() < FLOOR:
                raise RuntimeError('Deadline or host floor lost before oracle gate release')
            child.stdin.write(b'start\n')
            child.stdin.close()
            while True:
                inventory = pids(job)
                if any(pid != child.pid for pid in inventory):
                    raise RuntimeError('Unexpected owned descendant')
                values = {pid: memory(pid) for pid in inventory}
                unknown = [pid for pid, value in values.items() if value is None]
                if unknown:
                    fresh = pids(job)
                    if any(pid in fresh for pid in unknown):
                        raise RuntimeError('Unmeasured live owned PID')
                private = sum(value[0] for value in values.values() if value is not None)
                working = sum(value[1] for value in values.values() if value is not None)
                available, elapsed = free_bytes(), time.monotonic() - start
                peak_private, peak_working = max(peak_private, private), max(peak_working, working)
                lowest = min(lowest, available)
                trace.write(json.dumps({'utc': utc(), 'seconds': elapsed, 'owned_pids': inventory,
                                        'private': private, 'working': working, 'host_free': available}) + '\n')
                trace.flush()
                if elapsed >= DEADLINE or available < FLOOR or private > CAP:
                    reason = 'deadline' if elapsed >= DEADLINE else 'host-free-floor' if available < FLOOR else 'sampled-private-cap'
                    break
                if child.poll() is not None:
                    if pids(job):
                        reason = 'owned-process-survived-root'
                    break
                time.sleep(POLL)
    except Exception as exc:
        reason = 'guard-error: ' + str(exc)
    finally:
        if child and child.stdin and not child.stdin.closed:
            try:
                child.stdin.close()
            except Exception as exc:
                cleanup_errors.append('Gate close failed: ' + str(exc))
        if job:
            if not k.TerminateJobObject(job, 137):
                cleanup_errors.append('Job termination failed: ' + str(C.get_last_error()))
        if child:
            try:
                if not assigned and child.poll() is None:
                    child.terminate()  # gated root only, never a global process search
                child.wait(timeout=10)
                if assigned:
                    end = time.monotonic() + 10
                    while pids(job) and time.monotonic() < end:
                        time.sleep(POLL)
                    if pids(job):
                        cleanup_errors.append('Owned Job PID inventory not empty')
            except Exception as exc:
                cleanup_errors.append(str(exc))
            try:
                child._handle.Close()
            except Exception as exc:
                cleanup_errors.append('Root process handle close failed: ' + str(exc))
        if job and not k.CloseHandle(job):
            cleanup_errors.append('Job handle close failed: ' + str(C.get_last_error()))
        if work:
            try:
                if cleanup_errors:
                    raise RuntimeError('Temporary storage retained after uncertain process cleanup')
                if work.is_symlink() or work.resolve().parent != out or work.name != 'owned-temporary':
                    raise RuntimeError('Owned temporary path validation failed')
                shutil.rmtree(work)
            except Exception as exc:
                cleanup_errors.append(str(exc))
    receipt = {'source_head_label': args.source_head, 'oracle_sha256': args.oracle_sha256,
               'wrapper_sha256': sha256(script.read_bytes()).hexdigest(), 'interpreter': sys.executable,
               'started_utc': started, 'ended_utc': utc(), 'elapsed_including_cleanup': time.monotonic() - start,
               'root_pid': child.pid if child else None, 'job_assigned': assigned,
               'exit': child.returncode if child else None, 'stop_reason': reason, 'cleanup_errors': cleanup_errors,
               'peak_private': peak_private, 'peak_working': peak_working, 'lowest_host_free': lowest,
               'job_commit_cap': CAP, 'host_free_floor': FLOOR, 'deadline_seconds': DEADLINE,
               'poll_seconds': POLL, 'command': command}
    # Prestart refusal without an owned output directory still returns a receipt.
    if work:
        (out / 'watchdog-receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    print(json.dumps(receipt))
    return 1 if reason or cleanup_errors or child is None else child.returncode


if __name__ == '__main__':
    sys.exit(main())
