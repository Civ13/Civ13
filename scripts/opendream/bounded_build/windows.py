"""Windows adapter. Importing is inert; constructing only binds native APIs.

No CLI, process attachment, shell launcher, breakaway flags or build default.
Instantiation/run must occur only after separate human-reviewed build lease.
"""
import ctypes as C
from ctypes import wintypes as W
import os
import subprocess
import time

from guard import GuardFailure


class Memory(C.Structure):
    _fields_ = [('size', W.DWORD), ('load', W.DWORD)] + [(n, C.c_ulonglong) for n in
                ('total', 'available', 'page_total', 'page_available', 'virtual_total', 'virtual_available', 'extended')]


class Counters(C.Structure):
    _fields_ = [('size', W.DWORD), ('faults', W.DWORD)] + [(n, C.c_size_t) for n in
                ('peak_working', 'working', 'peak_paged', 'paged', 'peak_nonpaged', 'nonpaged', 'page', 'peak_page', 'private')]


class BasicLimits(C.Structure):
    _fields_ = [('process_time', C.c_longlong), ('job_time', C.c_longlong), ('flags', W.DWORD),
                ('min_working', C.c_size_t), ('max_working', C.c_size_t), ('active', W.DWORD),
                ('affinity', C.c_size_t), ('priority', W.DWORD), ('scheduling', W.DWORD)]


class Io(C.Structure):
    _fields_ = [(n, C.c_ulonglong) for n in ('read_ops', 'write_ops', 'other_ops', 'read_bytes', 'write_bytes', 'other_bytes')]


class Limits(C.Structure):
    _fields_ = [('basic', BasicLimits), ('io', Io)] + [(n, C.c_size_t) for n in
                ('process_memory', 'job_memory', 'peak_process', 'peak_job')]


class PortInfo(C.Structure):
    _fields_ = [('key', W.LPVOID), ('port', W.HANDLE)]


class Pids(C.Structure):
    _fields_ = [('assigned', W.DWORD), ('count', W.DWORD), ('pids', C.c_size_t * 4096)]


class Accounting(C.Structure):
    _fields_ = [(n, C.c_longlong) for n in ('user', 'kernel', 'period_user', 'period_kernel')] + [
        (n, W.DWORD) for n in ('faults', 'total_processes', 'active_processes', 'terminated_processes')]


class Startup(C.Structure):
    _fields_ = [('cb', W.DWORD), ('reserved', W.LPWSTR), ('desktop', W.LPWSTR), ('title', W.LPWSTR)] + [
        (n, W.DWORD) for n in ('x', 'y', 'width', 'height', 'chars_x', 'chars_y', 'fill', 'flags')] + [
        ('show', W.WORD), ('reserved_bytes', W.WORD), ('reserved_ptr', W.LPBYTE),
        ('stdin', W.HANDLE), ('stdout', W.HANDLE), ('stderr', W.HANDLE)]


class Process(C.Structure):
    _fields_ = [('process', W.HANDLE), ('thread', W.HANDLE), ('pid', W.DWORD), ('tid', W.DWORD)]


class Windows:
    def __init__(self, *, kernel=None, psapi=None):
        if (kernel is None) != (psapi is None):
            raise ValueError('Inject both native libraries or neither')
        if kernel is None and os.name != 'nt':
            raise RuntimeError('Windows only')
        self.k = kernel if kernel is not None else C.WinDLL('kernel32', use_last_error=True)
        self.p = psapi if psapi is not None else C.WinDLL('psapi', use_last_error=True)
        specs = (
            ('CreateJobObjectW', [W.LPVOID, W.LPCWSTR], W.HANDLE),
            ('CreateIoCompletionPort', [W.HANDLE, W.HANDLE, C.c_size_t, W.DWORD], W.HANDLE),
            ('GetQueuedCompletionStatus', [W.HANDLE, C.POINTER(W.DWORD), C.POINTER(C.c_size_t), C.POINTER(W.LPVOID), W.DWORD], W.BOOL),
            ('OpenProcess', [W.DWORD, W.BOOL, W.DWORD], W.HANDLE),
            ('GetCurrentProcess', [], W.HANDLE),
            ('CloseHandle', [W.HANDLE], W.BOOL),
            ('SetInformationJobObject', [W.HANDLE, C.c_int, W.LPVOID, W.DWORD], W.BOOL),
            ('QueryInformationJobObject', [W.HANDLE, C.c_int, W.LPVOID, W.DWORD, W.LPVOID], W.BOOL),
            ('AssignProcessToJobObject', [W.HANDLE, W.HANDLE], W.BOOL),
            ('IsProcessInJob', [W.HANDLE, W.HANDLE, C.POINTER(W.BOOL)], W.BOOL),
            ('TerminateJobObject', [W.HANDLE, W.UINT], W.BOOL),
            ('TerminateProcess', [W.HANDLE, W.UINT], W.BOOL),
            ('GlobalMemoryStatusEx', [C.POINTER(Memory)], W.BOOL),
            ('GetExitCodeProcess', [W.HANDLE, C.POINTER(W.DWORD)], W.BOOL),
            ('WaitForSingleObject', [W.HANDLE, W.DWORD], W.DWORD),
            ('ResumeThread', [W.HANDLE], W.DWORD),
            ('CreateProcessW', [W.LPCWSTR, W.LPWSTR, W.LPVOID, W.LPVOID, W.BOOL, W.DWORD,
                                W.LPVOID, W.LPCWSTR, C.POINTER(Startup), C.POINTER(Process)], W.BOOL),
        )
        for name, args, result in specs:
            function = getattr(self.k, name)
            function.argtypes, function.restype = args, result
        self.p.GetProcessMemoryInfo.argtypes = [W.HANDLE, C.POINTER(Counters), W.DWORD]
        self.p.GetProcessMemoryInfo.restype = W.BOOL
        self.port = None
        self.job = None

    @staticmethod
    def now():
        return time.monotonic()

    @staticmethod
    def pause(seconds):
        time.sleep(seconds)

    @staticmethod
    def check(value):
        if not value:
            raise OSError(C.get_last_error())
        return value

    def new_job(self, cap):
        if self.job is not None:
            raise GuardFailure('Adapter cannot reuse jobs')
        job = self.check(self.k.CreateJobObjectW(None, None))
        port = None
        try:
            limits = Limits()
            limits.basic.flags = 0x2200  # KILL_ON_JOB_CLOSE | JOB_MEMORY, NO breakaway
            limits.job_memory = cap
            self.check(self.k.SetInformationJobObject(job, 9, C.byref(limits), C.sizeof(limits)))
            port = self.check(self.k.CreateIoCompletionPort(W.HANDLE(-1), None, 0, 1))
            association = PortInfo(1, port)
            self.check(self.k.SetInformationJobObject(job, 7, C.byref(association), C.sizeof(association)))
        except BaseException:
            try:
                if port:
                    self.close(port)
            finally:
                self.close(job)
            raise
        self.port, self.job = port, job
        return job

    def new_process(self, argv, cwd, env):
        info, startup = Process(), Startup()
        startup.cb = C.sizeof(startup)
        startup.flags, startup.show = 1, 0
        command = C.create_unicode_buffer(subprocess.list2cmdline(argv))
        if any(not name or '=' in name or '\0' in name or '\0' in value for name, value in env.items()):
            raise GuardFailure('Invalid explicit environment')
        environment = C.create_unicode_buffer('\0'.join(name+'='+value for name, value in
                                                        sorted(env.items(), key=lambda row: row[0].upper()))+'\0\0')
        # CREATE_SUSPENDED | CREATE_UNICODE_ENVIRONMENT | CREATE_NO_WINDOW.
        # No CREATE_BREAKAWAY_FROM_JOB; no inherited handles; explicit executable.
        self.check(self.k.CreateProcessW(argv[0], command, None, None, False, 0x08000404,
                                       environment, str(cwd), C.byref(startup), C.byref(info)))
        return info.process, info.thread, info.pid

    def assign(self, job, handle):
        self.check(self.k.AssignProcessToJobObject(job, handle))

    def in_job(self, job, handle):
        value = W.BOOL()
        self.check(self.k.IsProcessInJob(handle, job, C.byref(value)))
        return bool(value.value)

    def resume(self, thread):
        if self.k.ResumeThread(thread) != 1:
            raise GuardFailure('Unexpected suspended root resume count')

    def events(self, job):
        if job != self.job:
            raise GuardFailure('Foreign Job')
        rows = []
        # Bounded drain: flood cannot keep supervisor from sampling its deadline.
        for _ in range(8192):
            message, key, pid = W.DWORD(), C.c_size_t(), W.LPVOID()
            ok = self.k.GetQueuedCompletionStatus(self.port, C.byref(message), C.byref(key), C.byref(pid), 0)
            if not ok:
                if C.get_last_error() == 258:  # WAIT_TIMEOUT
                    return rows
                raise OSError(C.get_last_error())
            if key.value != 1:
                raise GuardFailure('Unknown completion ownership')
            if message.value == 6:
                rows.append(('new', pid.value))
            elif message.value in (7, 8):
                rows.append(('exit', pid.value))
            elif message.value != 4:  # ACTIVE_PROCESS_ZERO is informational
                raise GuardFailure('Job limit/error notification: '+str(message.value))
        raise GuardFailure('Job event flood exceeded bound')

    def active_pids(self, job):
        value = Pids()
        self.check(self.k.QueryInformationJobObject(job, 3, C.byref(value), C.sizeof(value), None))
        if value.assigned > 4096 or value.count > 4096:
            raise GuardFailure('Owned inventory exceeds bound')
        return list(value.pids[:value.count])

    def open_owned(self, job, pid):
        # Called ONLY for this fresh Job's NEW_PROCESS notifications, never an
        # existing-process attachment. Retain the handle so PID reuse is harmless.
        handle = self.check(self.k.OpenProcess(0x00101000, False, pid))
        try:
            if not self.in_job(job, handle):
                raise GuardFailure('Unverified child')
        except BaseException:
            self.close(handle)
            raise
        return handle

    def assigned_count(self, job):
        value = Accounting()
        self.check(self.k.QueryInformationJobObject(job, 1, C.byref(value), C.sizeof(value), None))
        return value.total_processes

    def private(self, handle):
        value = Counters()
        value.size = C.sizeof(value)
        self.check(self.p.GetProcessMemoryInfo(handle, C.byref(value), C.sizeof(value)))
        return value.private

    def watcher_private(self):
        return self.private(self.k.GetCurrentProcess())

    def free_memory(self):
        value = Memory()
        value.size = C.sizeof(value)
        self.check(self.k.GlobalMemoryStatusEx(C.byref(value)))
        return value.available

    def exit_code(self, handle):
        # Query termination independently: a real exit code may itself be 259.
        if self.k.WaitForSingleObject(handle, 0) != 0:
            raise GuardFailure('Owned handle has not exited or wait failed')
        value = W.DWORD()
        self.check(self.k.GetExitCodeProcess(handle, C.byref(value)))
        return value.value

    def wait(self, handle, seconds):
        value = self.k.WaitForSingleObject(handle, max(0, min(30000, int(seconds*1000))))
        if value == 0xffffffff:
            raise OSError(C.get_last_error())
        return value == 0

    def terminate(self, job):
        self.check(self.k.TerminateJobObject(job, 125))

    def stop_unassigned(self, handle):
        self.check(self.k.TerminateProcess(handle, 125))

    def close(self, handle):
        self.check(self.k.CloseHandle(handle))

    def close_job(self, job):
        try:
            self.close(job)
        finally:
            if self.port:
                self.close(self.port)
                self.port = None
