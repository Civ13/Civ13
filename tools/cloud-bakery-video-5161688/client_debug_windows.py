"""Win32 debug metadata for the one retained client; no memory/context APIs."""
import ctypes as c
from ctypes import wintypes as w
import hashlib
import ntpath
import os
import struct
import threading
import time
from types import SimpleNamespace

from client_debug import DiagnosticError, require


class ExceptionRecord(c.Structure):
    pass


ExceptionRecord._fields_ = [('code', w.DWORD), ('flags', w.DWORD), ('record', c.c_void_p),
                           ('address', c.c_void_p), ('parameters', w.DWORD),
                           ('information', c.c_size_t*15)]


class ExceptionInfo(c.Structure):
    _fields_ = [('record', ExceptionRecord), ('first', w.DWORD)]


class CreateProcess(c.Structure):
    _fields_ = [('file', w.HANDLE), ('process', w.HANDLE), ('thread', w.HANDLE),
                ('base', c.c_void_p), ('debug_offset', w.DWORD), ('debug_size', w.DWORD),
                ('tls', c.c_void_p), ('start', c.c_void_p), ('name', c.c_void_p), ('unicode', w.WORD)]


class CreateThread(c.Structure):
    _fields_ = [('thread', w.HANDLE), ('tls', c.c_void_p), ('start', c.c_void_p)]


class LoadDll(c.Structure):
    _fields_ = [('file', w.HANDLE), ('base', c.c_void_p), ('debug_offset', w.DWORD),
                ('debug_size', w.DWORD), ('name', c.c_void_p), ('unicode', w.WORD)]


class DebugData(c.Union):
    _fields_ = [('exception', ExceptionInfo), ('create', CreateProcess),
                ('thread', CreateThread), ('load', LoadDll), ('base', c.c_void_p),
                ('exit', w.DWORD), ('reserved', c.c_ubyte*160)]


class DebugEvent(c.Structure):
    _fields_ = [('code', w.DWORD), ('pid', w.DWORD), ('tid', w.DWORD), ('data', DebugData)]


def image_size(raw):
    require(len(raw) >= 64 and raw[:2] == b'MZ', 'diagnostic_pe_header')
    offset = struct.unpack_from('<I', raw, 60)[0]
    require(offset <= 65536-88 and offset+88 <= len(raw) and raw[offset:offset+4] == b'PE\0\0',
            'diagnostic_pe_offset')
    optional = offset+24
    require(struct.unpack_from('<H', raw, optional)[0] in (0x10b, 0x20b), 'diagnostic_pe_magic')
    size = struct.unpack_from('<I', raw, optional+56)[0]
    require(0 < size <= 512*1024**2, 'diagnostic_pe_image_bound')
    return size


class Native:
    def __init__(self, adapter, process, binary_dir, *, api=None, clock=None, pins=None):
        require(c.sizeof(c.c_void_p) == 8, 'diagnostic_controller_x64')
        require(c.sizeof(DebugEvent) == 176, 'diagnostic_event_abi')
        self.adapter, self.process = adapter, None
        self.identity = self.started = None
        self.creator_thread = threading.get_ident()
        self.now = clock or time.perf_counter
        self.binary = ntpath.normcase(ntpath.abspath(str(binary_dir)))
        self.system = ntpath.normcase(os.environ.get('SystemRoot', ''))
        require(ntpath.isabs(self.binary) and ntpath.isabs(self.system), 'diagnostic_local_roots')
        if pins is None:
            from guard_config import BINARIES
            from nuget_pins import FILES
            pins = dict(BINARIES)
            pins.update({name: row['sha256'] for name, row in FILES.items()})
        self.pins = dict(pins)
        self.pending = self.raw = None
        self.file_closed = False
        self.handle_errors = []
        self.exit_acknowledged = False
        self.adopted = False
        if api is None:
            from client_debug import require_admission
            require_admission(True)
            require(os.name == 'nt', 'diagnostic_windows_only')
            self.k = adapter.k
            signatures = {
                'WaitForDebugEvent': ([c.POINTER(DebugEvent), w.DWORD], w.BOOL),
                'ContinueDebugEvent': ([w.DWORD, w.DWORD, w.DWORD], w.BOOL),
                'GetFinalPathNameByHandleW': ([w.HANDLE, w.LPWSTR, w.DWORD, w.DWORD], w.DWORD),
                'GetFileSizeEx': ([w.HANDLE, c.POINTER(c.c_longlong)], w.BOOL),
                'SetFilePointerEx': ([w.HANDLE, c.c_longlong, c.POINTER(c.c_longlong), w.DWORD], w.BOOL),
                'ReadFile': ([w.HANDLE, c.c_void_p, w.DWORD, c.POINTER(w.DWORD), c.c_void_p], w.BOOL),
                'DuplicateHandle': ([w.HANDLE, w.HANDLE, w.HANDLE, c.POINTER(w.HANDLE), w.DWORD, w.BOOL, w.DWORD], w.BOOL),
                'GetProcessId': ([w.HANDLE], w.DWORD),
                'GetThreadId': ([w.HANDLE], w.DWORD),
            }
            for name, (args, result) in signatures.items():
                getattr(self.k, name).argtypes = args
                getattr(self.k, name).restype = result
        else:
            self.k = api
        if process is not None:
            self.bind(process)

    def bind(self, process):
        require(self.process is None and getattr(process, '_debug_only_this_process', False) is True and
                getattr(process, '_debug_creator_thread', None) == self.creator_thread == threading.get_ident(),
                'diagnostic_creator_binding')
        self.process = process
        self.identity = self.adapter.identity(process)  # Captured suspended by existing Adapter.
        self.started = process._debug_started

    def check(self, timed=False):
        require(self.process._debug_creator_thread == threading.get_ident(), 'diagnostic_creator_thread')
        require(self.adapter.identity(self.process) == self.identity, 'diagnostic_retained_identity')
        if timed:
            require(self.now() < self.started+5, 'diagnostic_five_second_overrun')

    @staticmethod
    def checked(value):
        if not value:
            raise c.WinError(c.get_last_error())
        return value

    def next(self, milliseconds):
        self.check()
        require(self.pending is None and type(milliseconds) is int and 0 <= milliseconds <= 50,
                'diagnostic_pending_or_wait_bound')
        raw = DebugEvent()
        if not self.k.WaitForDebugEvent(c.byref(raw), milliseconds):
            code = c.get_last_error()
            if code == 121:  # ERROR_SEM_TIMEOUT from WaitForDebugEvent.
                return None
            raise c.WinError(code)
        event = {'code': int(raw.code), 'pid': int(raw.pid), 'tid': int(raw.tid)}
        self.raw, self.pending, self.file_closed = raw, event, False
        if raw.code in (3, 6):
            data = raw.data.create if raw.code == 3 else raw.data.load
            event.update(base=int(data.base or 0), file=data.file)
        elif raw.code == 7:
            event['base'] = int(raw.data.base or 0)
        elif raw.code == 1:
            event.update(exception=int(raw.data.exception.record.code),
                         address=int(raw.data.exception.record.address or 0),
                         first=bool(raw.data.exception.first))
        elif raw.code == 5:
            event['exit'] = int(raw.data.exit)
        return event

    def adopt(self, event, *, cleanup=False):
        self.check(timed=not cleanup)
        require(event is self.pending and event['code'] == 3 and event['pid'] == self.process.pid and
                event['tid'] == self.process.tid, 'diagnostic_created_identity')
        info = self.raw.data.create
        require(self.k.GetProcessId(info.process) == self.process.pid and
                self.k.GetThreadId(info.thread) == self.process.tid and
                self.adapter.times(SimpleNamespace(process=info.process))[0] == self.identity['creation_filetime'],
                'diagnostic_event_process_handle')
        # Event process/thread handles are closed by Windows on acknowledged exit.
        # If a provider aliases a CreateProcess return handle, retain an owned
        # duplicate so existing cleanup never double-closes an event handle.
        current = self.k.GetCurrentProcess()
        for field, event_handle in [('process', info.process), ('thread', info.thread)]:
            if getattr(self.process, field) == event_handle:
                duplicate = w.HANDLE()
                self.checked(self.k.DuplicateHandle(current, event_handle, current,
                             c.byref(duplicate), 0, False, 2))
                binding = self.process._identity
                require(binding[:3] == (self.process.process, self.process.thread, self.process.pid),
                        'diagnostic_retained_handle_rebind')
                setattr(self.process, field, duplicate.value)
                self.process._identity = (self.process.process, self.process.thread, *binding[2:])
        self.adopted = True

    def size(self, handle):
        value = c.c_longlong()
        self.checked(self.k.GetFileSizeEx(handle, c.byref(value)))
        require(value.value > 0, 'diagnostic_image_file_size')
        return value.value

    def seek(self, handle):
        self.checked(self.k.SetFilePointerEx(handle, 0, None, 0))

    def read(self, handle, count):
        require(0 < count <= 65536, 'diagnostic_file_read_bound')
        self.check(timed=True)
        buffer, used = c.create_string_buffer(count), w.DWORD()
        self.checked(self.k.ReadFile(handle, buffer, count, c.byref(used), None))
        self.check(timed=True)
        require(0 < used.value <= count, 'diagnostic_short_image_read')
        return buffer.raw[:used.value]

    def image(self, event):
        self.check(timed=True)
        require(event is self.pending and event['pid'] == self.identity['pid'] and event['code'] in (3, 6),
                'diagnostic_image_event')
        handle = event['file']
        if not handle:
            return {'base': event['base'], 'name': None, 'size': None}
        require(handle != c.c_void_p(-1).value, 'diagnostic_invalid_file_handle')
        path_buffer = c.create_unicode_buffer(1024)
        length = self.k.GetFinalPathNameByHandleW(handle, path_buffer, len(path_buffer), 8)
        self.check(timed=True)
        self.checked(length)
        require(length < len(path_buffer), 'diagnostic_image_path_bound')
        path = path_buffer.value
        if path.startswith('\\\\?\\'):
            path = path[4:]
        require(re_local(path), 'diagnostic_nonlocal_image')
        name = ntpath.basename(path)
        size = self.size(handle)
        self.seek(handle)
        header = self.read(handle, min(65536, size))
        result = {'base': event['base'], 'name': name, 'size': image_size(header)}
        normalized = ntpath.normcase(ntpath.abspath(path))
        result['origin'] = ('package' if normalized == ntpath.join(self.binary, ntpath.normcase(name))
                            else 'system' if normalized.startswith(self.system.rstrip('\\')+'\\') else 'other')
        if name.lower() in self.pins:
            require(size <= 8*1024**2, 'diagnostic_selected_file_cap')
            self.seek(handle)
            digest, remaining = hashlib.sha256(), size
            while remaining:
                part = self.read(handle, min(65536, remaining))
                digest.update(part)
                remaining -= len(part)
            require(self.size(handle) == size, 'diagnostic_selected_file_changed')
            result.update(selected=True, sha256=digest.hexdigest(),
                          matches_pin=(result['origin'] == 'package' and digest.hexdigest() == self.pins[name.lower()]))
        return result

    def ack(self, disposition):
        self.check()
        require(self.pending is not None and self.pending['pid'] == self.identity['pid'] and
                disposition in (0x10002, 0x80010001), 'diagnostic_ack_binding')
        event = self.pending
        if event['code'] in (3, 6) and event.get('file') and not self.file_closed:
            self.file_closed = True
            if not self.k.CloseHandle(event['file']):
                self.handle_errors.append('image_file_handle_close_failed')
        self.checked(self.k.ContinueDebugEvent(event['pid'], event['tid'], disposition))
        if event['code'] == 5:
            self.exit_acknowledged = True
        self.pending = self.raw = None


def re_local(path):
    # Reject UNC/device/relative paths without resolving elsewhere or reading strings
    # from the target. Only the event-provided local file handle is consulted.
    return (len(path) <= 1023 and len(path) >= 3 and path[0].isalpha() and
            path[1:3] == ':\\' and not any(ch in path for ch in '\r\n\0'))
