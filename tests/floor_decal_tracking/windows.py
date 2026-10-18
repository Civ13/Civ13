"""Windows-only retained-handle Job adapter. No native calls at import time."""
import ctypes as c
from ctypes import wintypes as w
import os
from pathlib import Path
import socket
import struct
import subprocess
import time


class Memory(c.Structure):
    _fields_ = [('cb', w.DWORD), ('faults', w.DWORD)] + [(n, c.c_size_t) for n in
        ('peakws', 'ws', 'ppp', 'pp', 'pnp', 'np', 'page', 'peakpage', 'private')]


class BasicLimits(c.Structure):
    _fields_ = [('process_time', c.c_longlong), ('job_time', c.c_longlong), ('flags', w.DWORD),
                ('minws', c.c_size_t), ('maxws', c.c_size_t), ('active', w.DWORD),
                ('affinity', c.c_size_t), ('priority', w.DWORD), ('scheduling', w.DWORD)]


class JobLimits(c.Structure):
    _fields_ = [('basic', BasicLimits), ('io', c.c_ulonglong * 6),
                ('process_memory', c.c_size_t), ('job_memory', c.c_size_t),
                ('peak_process', c.c_size_t), ('peak_job', c.c_size_t)]


class Accounting(c.Structure):
    _fields_ = [(n, c.c_longlong) for n in ('user', 'kernel', 'perioduser', 'periodkernel')] + [
        (n, w.DWORD) for n in ('faults', 'total', 'active', 'terminated')]


class Startup(c.Structure):
    _fields_ = [('cb', w.DWORD), ('reserved', w.LPWSTR), ('desktop', w.LPWSTR), ('title', w.LPWSTR)] + [
        (n, w.DWORD) for n in ('x', 'y', 'xsize', 'ysize', 'xchars', 'ychars', 'fill', 'flags')] + [
        ('show', w.WORD), ('reserved2size', w.WORD), ('reserved2', c.c_void_p),
        ('stdin', w.HANDLE), ('stdout', w.HANDLE), ('stderr', w.HANDLE)]


class ProcessInfo(c.Structure):
    _fields_ = [('process', w.HANDLE), ('thread', w.HANDLE), ('pid', w.DWORD), ('tid', w.DWORD)]


class StartupEx(c.Structure):
    _fields_ = [('startup', Startup), ('attributes', c.c_void_p)]


class Security(c.Structure):
    _fields_ = [('length', w.DWORD), ('descriptor', c.c_void_p), ('inherit', w.BOOL)]


class Adapter:
    def __init__(self):
        if os.name != 'nt':
            raise RuntimeError('Native admission adapter is Windows-only; no permissive fallback')
        self.k = c.WinDLL('kernel32', use_last_error=True)
        self.ps = c.WinDLL('psapi', use_last_error=True)
        self.ip = c.WinDLL('iphlpapi', use_last_error=True)
        signatures = {
            'CreateJobObjectW': ([c.c_void_p, w.LPCWSTR], w.HANDLE),
            'SetInformationJobObject': ([w.HANDLE, c.c_int, c.c_void_p, w.DWORD], w.BOOL),
            'QueryInformationJobObject': ([w.HANDLE, c.c_int, c.c_void_p, w.DWORD, c.c_void_p], w.BOOL),
            'AssignProcessToJobObject': ([w.HANDLE, w.HANDLE], w.BOOL),
            'IsProcessInJob': ([w.HANDLE, w.HANDLE, c.POINTER(w.BOOL)], w.BOOL),
            'TerminateJobObject': ([w.HANDLE, w.UINT], w.BOOL),
            'TerminateProcess': ([w.HANDLE, w.UINT], w.BOOL),
            'CloseHandle': ([w.HANDLE], w.BOOL),
            'ResumeThread': ([w.HANDLE], w.DWORD),
            'GetCurrentProcess': ([], w.HANDLE),
            'GetProcessTimes': ([w.HANDLE] + [c.POINTER(c.c_ulonglong)] * 4, w.BOOL),
            'QueryFullProcessImageNameW': ([w.HANDLE, w.DWORD, w.LPWSTR, c.POINTER(w.DWORD)], w.BOOL),
            'GetExitCodeProcess': ([w.HANDLE, c.POINTER(w.DWORD)], w.BOOL),
            'WaitForSingleObject': ([w.HANDLE, w.DWORD], w.DWORD),
            'InitializeProcThreadAttributeList': ([c.c_void_p, w.DWORD, w.DWORD, c.POINTER(c.c_size_t)], w.BOOL),
            'UpdateProcThreadAttribute': ([c.c_void_p, w.DWORD, c.c_size_t, c.c_void_p, c.c_size_t, c.c_void_p, c.c_void_p], w.BOOL),
            'DeleteProcThreadAttributeList': ([c.c_void_p], None),
            'CreateFileW': ([w.LPCWSTR, w.DWORD, w.DWORD, c.c_void_p, w.DWORD, w.DWORD, w.HANDLE], w.HANDLE),
            'CreateProcessW': ([w.LPCWSTR, w.LPWSTR, c.c_void_p, c.c_void_p, w.BOOL, w.DWORD,
                                c.c_void_p, w.LPCWSTR, c.POINTER(Startup), c.POINTER(ProcessInfo)], w.BOOL)}
        for name, (args, returns) in signatures.items():
            getattr(self.k, name).argtypes = args
            getattr(self.k, name).restype = returns
        self.ps.GetProcessMemoryInfo.argtypes = [w.HANDLE, c.POINTER(Memory), w.DWORD]
        self.ps.GetProcessMemoryInfo.restype = w.BOOL
        self.job = None
        self.retained = []

    @staticmethod
    def now():
        return time.monotonic()

    @staticmethod
    def pause(seconds):
        time.sleep(seconds)

    @staticmethod
    def check(value):
        if not value:
            raise c.WinError(c.get_last_error())
        return value

    def open(self):
        from guard_config import LIMITS
        self.job = self.check(self.k.CreateJobObjectW(None, None))
        limits = JobLimits()
        # Kill-on-close, one active process (no children), hard process memory cap.
        limits.basic.flags = 0x2000 | 0x8 | 0x100
        limits.basic.active = 1
        limits.process_memory = LIMITS['process_private_bytes']
        self.check(self.k.SetInformationJobObject(self.job, 9, c.byref(limits), c.sizeof(limits)))

    def memory(self, handle):
        value = Memory()
        value.cb = c.sizeof(value)
        self.check(self.ps.GetProcessMemoryInfo(handle, c.byref(value), value.cb))
        return value.private

    def free(self):
        # MEMORYSTATUSEX: length/load DWORDs followed by seven ULONGLONGs.
        class Status(c.Structure):
            _fields_ = [('length', w.DWORD), ('load', w.DWORD), ('values', c.c_ulonglong * 7)]
        status = Status()
        status.length = c.sizeof(status)
        self.check(self.k.GlobalMemoryStatusEx(c.byref(status)))
        return status.values[1]

    def preflight(self, limits):
        if self.memory(self.k.GetCurrentProcess()) > limits['watcher_private_bytes']:
            raise RuntimeError('Watcher reserve unavailable')

    def launch(self, argv, cwd, root, phase):
        # No inherited handles except explicit log handles; no inherited user env.
        from guard_config import digest, BINARIES
        if digest(argv[0]) != BINARIES[Path(argv[0]).name]:
            raise RuntimeError('Executable changed immediately before creation')
        security = Security(c.sizeof(Security), None, True)
        logs = []
        process = ProcessInfo()
        assigned = False
        attributes = None
        try:
            for suffix in ('stdout', 'stderr'):
                handle = self.k.CreateFileW(str(root / (phase + '.' + suffix + '.log')), 0x40000000, 1,
                                           c.byref(security), 1, 0x80, None)
                if handle == c.c_void_p(-1).value:
                    raise c.WinError(c.get_last_error())
                logs.append(handle)
            null = self.k.CreateFileW('NUL', 0x80000000, 1 | 2, c.byref(security), 3, 0x80, None)
            if null == c.c_void_p(-1).value:
                raise c.WinError(c.get_last_error())
            logs.append(null)
            startup = StartupEx()
            startup.startup.cb = c.sizeof(startup)
            startup.startup.flags = 0x101  # STDHANDLES | USESHOWWINDOW; hidden GUI too
            startup.startup.show = 0
            startup.startup.stdin, startup.startup.stdout, startup.startup.stderr = null, logs[0], logs[1]
            attribute_size = c.c_size_t()
            self.k.InitializeProcThreadAttributeList(None, 1, 0, c.byref(attribute_size))
            attributes = c.create_string_buffer(attribute_size.value)
            self.check(self.k.InitializeProcThreadAttributeList(attributes, 1, 0, c.byref(attribute_size)))
            startup.attributes = c.cast(attributes, c.c_void_p)
            inherited = (w.HANDLE * len(logs))(*logs)
            self.check(self.k.UpdateProcThreadAttribute(attributes, 0, 0x20002, inherited, c.sizeof(inherited), None, None))
            envroot = root / 'environment'
            envroot.mkdir(exist_ok=True)
            system = os.environ['SystemRoot']
            environment = dict(SystemRoot=system, WINDIR=system, PATH=str(Path(argv[0]).parent),
                               TEMP=str(envroot), TMP=str(envroot), APPDATA=str(envroot),
                               LOCALAPPDATA=str(envroot), USERPROFILE=str(envroot))
            block = c.create_unicode_buffer('\0'.join(k + '=' + v for k, v in sorted(environment.items())) + '\0\0')
            command = c.create_unicode_buffer(subprocess.list2cmdline(argv))
            self.check(self.k.CreateProcessW(argv[0], command, None, None, True,
                       0x4 | 0x400 | 0x08000000 | 0x80000, block, str(cwd),
                       c.cast(c.byref(startup), c.POINTER(Startup)), c.byref(process)))
            self.retained.append(process)
            self.check(self.k.AssignProcessToJobObject(self.job, process.process))
            assigned = True
            member = w.BOOL()
            self.check(self.k.IsProcessInJob(process.process, self.job, c.byref(member)))
            if not member.value:
                raise RuntimeError('Suspended process Job ownership unverified')
            # Query image/creation while suspended. Windows can reject image
            # lookup after termination even though the retained wait is signaled.
            process.verified_identity = self.identity(process)
            if self.k.ResumeThread(process.thread) == 0xffffffff:
                raise c.WinError(c.get_last_error())
            return process
        except Exception:
            if process.process and not assigned:
                self.check(self.k.TerminateProcess(process.process, 1))
            raise
        finally:
            if attributes is not None and startup.attributes:
                self.k.DeleteProcThreadAttributeList(attributes)
            for handle in logs:
                self.k.CloseHandle(handle)

    def times(self, process):
        values = [c.c_ulonglong() for _ in range(4)]
        self.check(self.k.GetProcessTimes(process.process, *(c.byref(v) for v in values)))
        return values[0].value, (values[2].value + values[3].value) / 1e7

    def identity(self, process):
        if hasattr(process, 'verified_identity'):
            return dict(process.verified_identity)
        image, length = c.create_unicode_buffer(32768), w.DWORD(32768)
        self.check(self.k.QueryFullProcessImageNameW(process.process, 0, image, c.byref(length)))
        created, _ = self.times(process)
        return dict(pid=process.pid, creation_filetime=created, image=str(Path(image.value).resolve()))

    def sample(self, process):
        return dict(private_bytes=self.memory(process.process), watcher_private_bytes=self.memory(self.k.GetCurrentProcess()),
                    cpu_seconds=self.times(process)[1])

    def sockets(self, process):
        if self.exited(process):
            return []
        rows = []
        for family in (2, 23):
            for protocol in ('tcp', 'udp'):
                function = getattr(self.ip, 'GetExtendedTcpTable' if protocol == 'tcp' else 'GetExtendedUdpTable')
                function.argtypes = [c.c_void_p, c.POINTER(w.DWORD), w.BOOL, w.ULONG, c.c_int, w.ULONG]
                function.restype = w.DWORD
                size = w.DWORD()
                tableclass = 5 if protocol == 'tcp' else 1  # OWNER_PID_ALL / OWNER_PID
                code = function(None, c.byref(size), False, family, tableclass, 0)
                if code not in (0, 122) or size.value > 16 * 1024**2:
                    raise RuntimeError('Owned socket inventory unavailable/bounded table exceeded')
                buf = c.create_string_buffer(max(4, size.value))
                code = function(buf, c.byref(size), False, family, tableclass, 0)
                if code:
                    raise RuntimeError('Owned socket inventory failed: ' + str(code))
                raw = buf.raw
                count = struct.unpack_from('<I', raw)[0]
                width = (24 if family == 2 else 56) if protocol == 'tcp' else (12 if family == 2 else 28)
                if 4 + count * width > len(raw):
                    raise RuntimeError('Truncated owned socket inventory')
                for i in range(count):
                    row = raw[4 + i * width:4 + (i + 1) * width]
                    if struct.unpack_from('<I', row, width - 4)[0] != process.pid:
                        continue
                    if family == 2:
                        offset = 4 if protocol == 'tcp' else 0
                        address = socket.inet_ntop(socket.AF_INET, row[offset:offset + 4])
                        portoffset = offset + 4
                        state = struct.unpack_from('<I', row)[0] if protocol == 'tcp' else None
                    else:
                        address = socket.inet_ntop(socket.AF_INET6, row[:16])
                        portoffset = 20
                        state = struct.unpack_from('<I', row, 48)[0] if protocol == 'tcp' else None
                    port = struct.unpack_from('!H', row, portoffset)[0]
                    remote_address = remote_port = None
                    if protocol == 'tcp':
                        remote_offset, remote_port_offset = (12, 16) if family == 2 else (24, 44)
                        remote_address = socket.inet_ntop(socket.AF_INET if family == 2 else socket.AF_INET6,
                                                        row[remote_offset:remote_offset + (4 if family == 2 else 16)])
                        remote_port = struct.unpack_from('!H', row, remote_port_offset)[0]
                    rows.append(dict(protocol=protocol, address=address, port=port,
                                     remote_address=remote_address, remote_port=remote_port,
                                     state='listen' if state == 2 else str(state)))
        # A PID may be reused after exit; a signaled retained handle invalidates
        # the complete inventory rather than attributing another process's row.
        return [] if self.exited(process) else rows

    def exited(self, process):
        value = self.k.WaitForSingleObject(process.process, 0)
        if value not in (0, 258):
            raise RuntimeError('Retained process wait failed')
        return value == 0

    def accounting(self):
        value = Accounting()
        self.check(self.k.QueryInformationJobObject(self.job, 1, c.byref(value), c.sizeof(value), None))
        return value

    def finish(self, process):
        code = w.DWORD()
        self.check(self.k.GetExitCodeProcess(process.process, c.byref(code)))
        accounting = self.accounting()
        return dict(exit_code=code.value, identity=self.identity(process), cpu_seconds=self.times(process)[1],
                    active_processes=accounting.active, total_processes=accounting.total)

    def cleanup(self, process, seconds):
        deadline = self.now() + seconds
        exits, errors = [], []
        if self.job:
            if not self.k.TerminateJobObject(self.job, 1):
                errors.append('Job termination failed')
            self.k.CloseHandle(self.job)  # kill-on-close fallback before retained waits
            self.job = None
        for retained in self.retained:
            try:
                wait = self.k.WaitForSingleObject(retained.process, max(0, int((deadline - self.now()) * 1000)))
                if wait != 0:
                    raise RuntimeError('Retained process final exit unconfirmed')
                code = w.DWORD()
                self.check(self.k.GetExitCodeProcess(retained.process, c.byref(code)))
                exits.append(dict(identity=self.identity(retained), exit_code=code.value, cpu_seconds=self.times(retained)[1]))
            except Exception as error:
                errors.append(str(error))
            finally:
                if retained.thread:
                    self.k.CloseHandle(retained.thread)
                self.k.CloseHandle(retained.process)
        return dict(all_exited=not errors, exits=exits, errors=errors)
