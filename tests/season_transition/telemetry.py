"""Own-child OS telemetry only; observations are synthetic fixture metrics."""
import os
from pathlib import Path
import subprocess
import threading
import time

def run_native(command, cwd, flags, timeout):
    process = subprocess.Popen(command, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, creationflags=flags)
    samples = []
    stop = threading.Event()
    started = time.monotonic()
    if os.name == 'nt':
        import ctypes
        from ctypes import wintypes
        class Counters(ctypes.Structure):
            _fields_ = [('cb', wintypes.DWORD), ('faults', wintypes.DWORD)] + [(name, ctypes.c_size_t) for name in ('peak_working_set', 'working_set', 'peak_paged', 'paged', 'peak_nonpaged', 'nonpaged', 'pagefile', 'peak_pagefile')]
        def sample():
            counters = Counters()
            counters.cb = ctypes.sizeof(counters)
            if ctypes.windll.psapi.GetProcessMemoryInfo(ctypes.c_void_p(int(process._handle)), ctypes.byref(counters), counters.cb):
                return max(counters.working_set, counters.peak_working_set)
            return None
        metric = 'Windows child peak working set bytes'
    else:
        import resource
        before_cpu = resource.getrusage(resource.RUSAGE_CHILDREN)
        def sample():
            try:
                rows = (Path('/proc') / str(process.pid) / 'status').read_text().splitlines()
                return max(int(row.split()[1]) * 1024 for row in rows if row.startswith(('VmRSS:', 'VmHWM:')))
            except (OSError, ValueError):
                return None
        metric = 'Linux sampled child RSS or high water bytes'
    def collect():
        while not stop.is_set():
            value = sample()
            if value is not None:
                samples.append(value)
            stop.wait(0.02)
    thread = threading.Thread(target=collect, daemon=True)
    thread.start()
    try:
        stdout, stderr = process.communicate(timeout=timeout)
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()
        stop.set()
        thread.join(timeout=2)
    cpu = None
    if os.name == 'nt':
        times = (ctypes.c_ulonglong * 4)()
        if ctypes.windll.kernel32.GetProcessTimes(ctypes.c_void_p(int(process._handle)), ctypes.byref(times, 0), ctypes.byref(times, 8), ctypes.byref(times, 16), ctypes.byref(times, 24)):
            cpu = (times[2] + times[3]) / 10000000
    else:
        after_cpu = resource.getrusage(resource.RUSAGE_CHILDREN)
        cpu = after_cpu.ru_utime + after_cpu.ru_stime - before_cpu.ru_utime - before_cpu.ru_stime
    return process.returncode, stdout, stderr, {'process_cpu_seconds': cpu, 'process_peak_memory_bytes': max(samples) if samples else None, 'process_memory_metric': metric, 'memory_samples': len(samples), 'daemon_wall_seconds': time.monotonic() - started, 'measurement_scope': 'isolated synthetic fixture, not server or player performance'}
