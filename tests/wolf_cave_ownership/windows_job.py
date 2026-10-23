"""Dedicated cave-fixture Win32 backend. Inert on import; injectable DLLs for tests.

No process attachment, shell, security changes, breakaway, or prior-suite grant.
The caller must have separate approval before constructing the native backend.
"""
import ctypes as C
from dataclasses import dataclass
import os
from pathlib import Path
import struct
import subprocess
import sys
import time

U32, BOOL, HANDLE = C.c_uint32, C.c_int32, C.c_void_p
CAP = 256 * 1024**2
FLAGS = 0x2000 | 0x8 | 0x100 | 0x200  # kill-on-close, active=1, process+job memory
CREATE_FLAGS = 0x4 | 0x400 | 0x80000 | 0x08000000


class Basic(C.Structure):
    _fields_ = [('process_time', C.c_int64), ('job_time', C.c_int64), ('flags', U32),
                ('minws', C.c_size_t), ('maxws', C.c_size_t), ('active', U32),
                ('affinity', C.c_size_t), ('priority', U32), ('scheduling', U32)]


class Limits(C.Structure):
    _fields_ = [('basic', Basic), ('io', C.c_uint64 * 6),
                ('process_memory', C.c_size_t), ('job_memory', C.c_size_t),
                ('peak_process', C.c_size_t), ('peak_job', C.c_size_t)]


class Accounting(C.Structure):
    _fields_ = [(n, C.c_int64) for n in ('user', 'kernel', 'period_user', 'period_kernel')] + [
        (n, U32) for n in ('faults', 'total', 'active', 'terminated')]


class Members(C.Structure):
    _fields_ = [('assigned', U32), ('count', U32), ('pids', C.c_size_t * 2)]


class Memory(C.Structure):
    _fields_ = [('size', U32), ('faults', U32)] + [(n, C.c_size_t) for n in
        ('peakws', 'ws', 'ppp', 'pp', 'pnp', 'np', 'page', 'peakpage', 'private')]


class HostMemory(C.Structure):
    _fields_ = [('size', U32), ('load', U32)] + [(n, C.c_uint64) for n in
        ('total', 'available', 'page_total', 'page_available', 'virtual', 'virtual_available', 'extended')]


class Startup(C.Structure):
    _fields_ = [('size', U32), ('reserved', C.c_wchar_p), ('desktop', C.c_wchar_p), ('title', C.c_wchar_p)] + [
        (n, U32) for n in ('x', 'y', 'width', 'height', 'chars_x', 'chars_y', 'fill', 'flags')] + [
        ('show', C.c_uint16), ('reserved_size', C.c_uint16), ('reserved_ptr', HANDLE),
        ('stdin', HANDLE), ('stdout', HANDLE), ('stderr', HANDLE)]


class StartupEx(C.Structure):
    _fields_ = [('startup', Startup), ('attributes', HANDLE)]


class ProcessInfo(C.Structure):
    _fields_ = [('process', HANDLE), ('thread', HANDLE), ('pid', U32), ('tid', U32)]


class Security(C.Structure):
    _fields_ = [('size', U32), ('descriptor', HANDLE), ('inherit', BOOL)]


@dataclass
class Child:
    info: ProcessInfo
    job: object
    identity: dict


class WindowsJob:
    def __init__(self, kernel=None, psapi=None, iphelper=None, error=None):
        injected = (kernel is not None, psapi is not None, iphelper is not None)
        if any(injected) and not all(injected):
            raise ValueError('Inject all libraries or none')
        if not any(injected) and os.name != 'nt':
            raise RuntimeError('Windows only; no fallback')
        self.k = kernel if all(injected) else C.WinDLL('kernel32', use_last_error=True)
        self.ps = psapi if all(injected) else C.WinDLL('psapi', use_last_error=True)
        self.ip = iphelper if all(injected) else C.WinDLL('iphlpapi', use_last_error=True)
        self.error = error if error else lambda: C.WinError(C.get_last_error())
        signatures = {
            'CreateJobObjectW': ([HANDLE, C.c_wchar_p], HANDLE),
            'SetInformationJobObject': ([HANDLE, C.c_int, HANDLE, U32], BOOL),
            'QueryInformationJobObject': ([HANDLE, C.c_int, HANDLE, U32, HANDLE], BOOL),
            'AssignProcessToJobObject': ([HANDLE, HANDLE], BOOL),
            'IsProcessInJob': ([HANDLE, HANDLE, C.POINTER(BOOL)], BOOL),
            'TerminateJobObject': ([HANDLE, U32], BOOL),
            'TerminateProcess': ([HANDLE, U32], BOOL),
            'CloseHandle': ([HANDLE], BOOL), 'ResumeThread': ([HANDLE], U32),
            'WaitForSingleObject': ([HANDLE, U32], U32),
            'GetExitCodeProcess': ([HANDLE, C.POINTER(U32)], BOOL),
            'GetProcessTimes': ([HANDLE] + [C.POINTER(C.c_uint64)] * 4, BOOL),
            'QueryFullProcessImageNameW': ([HANDLE, U32, C.c_wchar_p, C.POINTER(U32)], BOOL),
            'GlobalMemoryStatusEx': ([C.POINTER(HostMemory)], BOOL),
            'GetCurrentProcess': ([], HANDLE),
            'DuplicateHandle': ([HANDLE, HANDLE, HANDLE, C.POINTER(HANDLE), U32, BOOL, U32], BOOL),
            'GetProcessAffinityMask': ([HANDLE, C.POINTER(C.c_size_t), C.POINTER(C.c_size_t)], BOOL),
            'GetSystemTimes': ([C.POINTER(C.c_uint64)] * 3, BOOL),
            'CreateFileW': ([C.c_wchar_p, U32, U32, HANDLE, U32, U32, HANDLE], HANDLE),
            'InitializeProcThreadAttributeList': ([HANDLE, U32, U32, C.POINTER(C.c_size_t)], BOOL),
            'UpdateProcThreadAttribute': ([HANDLE, U32, C.c_size_t, HANDLE, C.c_size_t, HANDLE, HANDLE], BOOL),
            'DeleteProcThreadAttributeList': ([HANDLE], None),
            'CreateProcessW': ([C.c_wchar_p, C.c_wchar_p, HANDLE, HANDLE, BOOL, U32,
                                HANDLE, C.c_wchar_p, C.POINTER(Startup), C.POINTER(ProcessInfo)], BOOL),
        }
        for name, (args, result) in signatures.items():
            function = getattr(self.k, name)
            function.argtypes, function.restype = args, result
        self.ps.GetProcessMemoryInfo.argtypes = [HANDLE, C.POINTER(Memory), U32]
        self.ps.GetProcessMemoryInfo.restype = BOOL

    def check(self, value):
        if not value:
            raise self.error()
        return value

    def resources(self):
        memory = HostMemory(); memory.size = C.sizeof(memory)
        self.check(self.k.GlobalMemoryStatusEx(C.byref(memory)))
        allowed, system = C.c_size_t(), C.c_size_t()
        self.check(self.k.GetProcessAffinityMask(self.k.GetCurrentProcess(), C.byref(allowed), C.byref(system)))
        clocks = [C.c_uint64() for _ in range(3)]
        self.check(self.k.GetSystemTimes(*(C.byref(v) for v in clocks)))
        return dict(available_bytes=memory.available, commit_available_bytes=memory.page_available,
                    allowed_cpus=allowed.value.bit_count(), system_cpu_times=[v.value for v in clocks])

    def verify_limits(self, job):
        value = Limits()
        self.check(self.k.QueryInformationJobObject(job, 9, C.byref(value), C.sizeof(value), None))
        if (value.basic.flags, value.basic.active, value.process_memory, value.job_memory) != (FLAGS, 1, CAP, CAP):
            raise RuntimeError('Owned Job limits differ from exact 256 MiB policy')

    def identity(self, process):
        image, length = C.create_unicode_buffer(32768), U32(32768)
        self.check(self.k.QueryFullProcessImageNameW(process, 0, image, C.byref(length)))
        clocks = [C.c_uint64() for _ in range(4)]
        self.check(self.k.GetProcessTimes(process, *(C.byref(v) for v in clocks)))
        if not clocks[0].value:
            raise RuntimeError('Missing owned process creation identity')
        return dict(image=str(Path(image.value).resolve()), creation_filetime=clocks[0].value)

    def start_suspended(self, argv, cwd, logs):
        """Create isolated child, own it before resume. Failure cleans all retained handles."""
        job, info, handles, attributes = None, ProcessInfo(), [], None
        child, assigned, initialized, completed = None, False, False, False
        try:
            job = self.check(self.k.CreateJobObjectW(None, None))
            limits = Limits(); limits.basic.flags = FLAGS; limits.basic.active = 1
            limits.process_memory = limits.job_memory = CAP
            self.check(self.k.SetInformationJobObject(job, 9, C.byref(limits), C.sizeof(limits)))
            self.verify_limits(job)
            security = Security(C.sizeof(Security), None, True)
            for path, access, disposition in ((logs / 'stdout.log', 0x40000000, 1),
                                               (logs / 'stderr.log', 0x40000000, 1), ('NUL', 0x80000000, 3)):
                handle = self.k.CreateFileW(str(path), access, 1 | 2, C.byref(security), disposition, 0x80, None)
                if handle in (None, C.c_void_p(-1).value):
                    raise self.error()
                handles.append(handle)
            startup = StartupEx(); startup.startup.size = C.sizeof(startup)
            startup.startup.flags = 0x101; startup.startup.show = 0
            startup.startup.stdin, startup.startup.stdout, startup.startup.stderr = handles[2], handles[0], handles[1]
            length = C.c_size_t()
            self.k.InitializeProcThreadAttributeList(None, 1, 0, C.byref(length))
            if not 0 < length.value <= 65536:
                raise RuntimeError('Invalid handle-list size')
            attributes = C.create_string_buffer(length.value)
            self.check(self.k.InitializeProcThreadAttributeList(attributes, 1, 0, C.byref(length)))
            initialized = True; startup.attributes = C.cast(attributes, HANDLE)
            inherited = (HANDLE * 3)(*handles)
            self.check(self.k.UpdateProcThreadAttribute(attributes, 0, 0x20002, inherited, C.sizeof(inherited), None, None))
            envdir = cwd / 'environment'; envdir.mkdir(exist_ok=False)
            system = os.environ.get('SystemRoot')
            if not system:
                raise RuntimeError('SystemRoot unavailable')
            environment = {'SystemRoot': system, 'WINDIR': system, 'PATH': str(Path(argv[0]).parent),
                           **{name: str(envdir) for name in ('TEMP', 'TMP', 'APPDATA', 'LOCALAPPDATA', 'USERPROFILE')}}
            env = C.create_unicode_buffer('\0'.join(k + '=' + v for k, v in sorted(environment.items())) + '\0\0')
            command = C.create_unicode_buffer(subprocess.list2cmdline(argv))
            self.check(self.k.CreateProcessW(argv[0], command, None, None, True, CREATE_FLAGS,
                       env, str(cwd), C.cast(C.byref(startup), C.POINTER(Startup)), C.byref(info)))
            child = Child(info, job, {'pid': info.pid})
            self.check(self.k.AssignProcessToJobObject(job, info.process)); assigned = True
            member = BOOL()
            self.check(self.k.IsProcessInJob(info.process, job, C.byref(member)))
            if not member.value:
                raise RuntimeError('Suspended child ownership unverified')
            self.verify_limits(job)
            child.identity.update(self.identity(info.process))
            if Path(child.identity['image']).resolve() != Path(argv[0]).resolve():
                raise RuntimeError('Created image differs from pinned executable')
            completed = True
            return child
        except BaseException as failure:
            errors = []
            if info.process:
                # Only the exact newly created retained handle; never PID attachment.
                for operation in ((lambda: self.check(self.k.TerminateJobObject(job, 1))) if assigned else
                                  (lambda: self.check(self.k.TerminateProcess(info.process, 1))),
                                  lambda: self.require_exit(info.process, 5000)):
                    try: operation()
                    except BaseException as error: errors.append(str(error))
            for handle in (info.thread, info.process, job):
                if handle:
                    try: self.check(self.k.CloseHandle(handle))
                    except BaseException as error: errors.append(str(error))
            if errors:
                raise RuntimeError(f'{failure}; owned PID {info.pid}; creation cleanup unconfirmed: {errors}') from failure
            raise
        finally:
            if initialized:
                self.k.DeleteProcThreadAttributeList(attributes)
            close_errors = []
            for handle in handles:
                try: self.check(self.k.CloseHandle(handle))
                except BaseException as error: close_errors.append(str(error))
            if close_errors:
                # A log-handle failure on the successful return path still owns
                # a suspended child: do not leak it by throwing from finally.
                if completed:
                    close_errors.append(str(self.cleanup(child)))
                prior = sys.exc_info()[1]
                raise RuntimeError(f'{prior or "Creation return"}; log-handle cleanup failed: {close_errors}')

    def resume(self, child):
        self.verify_limits(child.job)
        if self.k.ResumeThread(child.info.thread) == 0xffffffff:
            raise self.error()

    def exited(self, child):
        status = self.k.WaitForSingleObject(child.info.process, 0)
        if status not in (0, 258):
            raise self.error()
        return status == 0

    def require_exit(self, handle, milliseconds):
        if self.k.WaitForSingleObject(handle, milliseconds) != 0:
            raise RuntimeError('Retained owned process final exit unconfirmed')

    def exit_code(self, child):
        self.require_exit(child.info.process, 0)
        code = U32(); self.check(self.k.GetExitCodeProcess(child.info.process, C.byref(code)))
        return code.value

    def sample(self, child):
        diagnostic = dict(stage='limits', identity=child.identity,
                          layout=dict(buffer_bytes=C.sizeof(Members), alignment=C.alignment(Members),
                                      pid_offset=Members.pids.offset, pointer_bytes=C.sizeof(C.c_size_t),
                                      offsets={name: getattr(Members, name).offset for name, _ in Members._fields_}))

        def error_info(error):
            return dict(type=type(error).__name__, message=str(error), winerror=getattr(error, 'winerror', None))

        def wait_state():
            status = self.k.WaitForSingleObject(child.info.process, 0)
            return dict(result=int(status), error=error_info(self.error()) if status not in (0, 258) else None)

        try:
            return self._sample(child, diagnostic, error_info, wait_state)
        except BaseException as error:
            error.sample_diagnostic = diagnostic
            raise

    def _sample(self, child, diagnostic, error_info, wait_state):
        self.verify_limits(child.job)
        diagnostic['stage'] = 'accounting'
        accounting = Accounting()
        self.check(self.k.QueryInformationJobObject(child.job, 1, C.byref(accounting), C.sizeof(accounting), None))
        diagnostic['accounting'] = {name: getattr(accounting, name) for name, _ in accounting._fields_}
        diagnostic['stage'] = 'pid_list'
        diagnostic['wait_before'] = wait_state()
        members, length = Members(), U32()
        result = self.k.QueryInformationJobObject(child.job, 3, C.byref(members), C.sizeof(members), C.byref(length))
        query_error = self.error() if not result else None  # Capture before another API changes LastError.
        diagnostic['pid_list'] = dict(query_result=int(result), error=error_info(query_error) if query_error else None,
                                      assigned=members.assigned, count=members.count, return_length=length.value,
                                      buffer_prefix=list(members.pids[:min(members.count, 2)]))
        diagnostic['wait_after'] = wait_state()
        if diagnostic['wait_after']['result'] == 0:
            code = U32(); code_result = self.k.GetExitCodeProcess(child.info.process, C.byref(code))
            diagnostic['exit_after'] = dict(query_result=int(code_result), exit_code=code.value if code_result else None,
                                            error=error_info(self.error()) if not code_result else None)
        if query_error:
            raise query_error
        # Diagnostic waits/exit state never bypass the existing rejection rules.
        if not (members.assigned == members.count <= 1 and
                Members.pids.offset + members.count * C.sizeof(C.c_size_t) <= length.value <= C.sizeof(members)):
            raise RuntimeError('Owned Job membership unavailable or unexpected descendant')
        pids = list(members.pids[:members.count])
        if any(pid != child.info.pid for pid in pids) or accounting.total != 1 or accounting.terminated:
            raise RuntimeError('Unexpected owned Job process or resource termination')
        diagnostic['stage'] = 'memory'
        memory = Memory(); memory.size = C.sizeof(memory)
        if not self.exited(child):
            self.check(self.ps.GetProcessMemoryInfo(child.info.process, C.byref(memory), memory.size))
        diagnostic['stage'] = 'complete'
        return dict(private_bytes=memory.private, pids=pids, active=accounting.active,
                    cpu_seconds=(accounting.user + accounting.kernel) / 1e7, diagnostic=diagnostic)

    def sockets(self, child):
        """Spot-check owned PID with retained-handle liveness checks; never continuous proof."""
        if self.exited(child): return []
        rows = []
        for family in (2, 23):
            for protocol in ('tcp', 'udp'):
                function = getattr(self.ip, 'GetExtendedTcpTable' if protocol == 'tcp' else 'GetExtendedUdpTable')
                function.argtypes = [HANDLE, C.POINTER(U32), BOOL, U32, C.c_int, U32]
                function.restype = U32
                length = U32(); tableclass = 5 if protocol == 'tcp' else 1
                code = function(None, C.byref(length), False, family, tableclass, 0)
                if code not in (0, 122) or not 4 <= length.value <= 4 * 1024**2:
                    raise RuntimeError('Socket census unavailable or exceeds bound')
                buffer = C.create_string_buffer(length.value)
                if function(buffer, C.byref(length), False, family, tableclass, 0):
                    raise RuntimeError('Socket census failed; no retry')
                raw = buffer.raw; count = struct.unpack_from('<I', raw)[0]
                width = (24 if family == 2 else 56) if protocol == 'tcp' else (12 if family == 2 else 28)
                if 4 + count * width > len(raw): raise RuntimeError('Truncated socket census')
                for i in range(count):
                    row = raw[4+i*width:4+(i+1)*width]
                    if struct.unpack_from('<I', row, width-4)[0] != child.info.pid: continue
                    state = struct.unpack_from('<I', row, 0 if family == 2 else 48)[0] if protocol == 'tcp' else None
                    rows.append(dict(family=family, protocol=protocol, state=state, listener=state == 2))
        return [] if self.exited(child) else rows

    def terminate(self, child):
        self.check(self.k.TerminateJobObject(child.job, 1))

    def watchdog_handle(self, child):
        handle = HANDLE(); current = self.k.GetCurrentProcess()
        self.check(self.k.DuplicateHandle(current, child.job, current, C.byref(handle), 0, False, 2))
        return handle.value

    def watchdog_terminate(self, handle):
        self.check(self.k.TerminateJobObject(handle, 1))

    def watchdog_close(self, handle):
        self.check(self.k.CloseHandle(handle))

    def cleanup(self, child):
        """Always close Job (kill-on-close), wait retained child, close all handles."""
        errors = []
        deadline = time.monotonic() + 5
        # Terminate only this fresh owned Job, including any unexpected member.
        try: self.terminate(child)
        except BaseException as error: errors.append(str(error))
        active = None
        try:
            while True:
                accounting = Accounting()
                self.check(self.k.QueryInformationJobObject(child.job, 1, C.byref(accounting), C.sizeof(accounting), None))
                active = accounting.active
                if active == 0: break
                if time.monotonic() >= deadline: raise RuntimeError('Owned Job did not drain')
                time.sleep(.01)
        except BaseException as error: errors.append(str(error))
        try: self.check(self.k.CloseHandle(child.job))
        except BaseException as error: errors.append(str(error))
        try: self.require_exit(child.info.process, max(0, int((deadline-time.monotonic())*1000)))
        except BaseException as error: errors.append(str(error))
        for handle in (child.info.thread, child.info.process):
            try: self.check(self.k.CloseHandle(handle))
            except BaseException as error: errors.append(str(error))
        return dict(all_exited=not errors, errors=errors, active_processes=active, identity=child.identity)
