"""Owned subprocess limits with sampled and final resource receipts."""
import ctypes
from ctypes import wintypes as w
import json
import hashlib
import os
from pathlib import Path
import re
import subprocess
import socket
import struct
import time

DIAGNOSTIC = re.compile(r'\bBUG\b|runtime error|Bad ref|Bad loc|Cannot read null|Cannot execute null', re.I)

def binary_info(path):
    if os.name != 'nt':
        raise RuntimeError('Frozen native binaries currently support Windows only')
    api = ctypes.windll.version
    size = api.GetFileVersionInfoSizeW(str(path), None)
    if not size:
        raise OSError('Missing native version resource')
    data = ctypes.create_string_buffer(size)
    pointer = ctypes.c_void_p()
    length = w.UINT()
    if not api.GetFileVersionInfoW(str(path), 0, size, data) or not api.VerQueryValueW(data, '\\', ctypes.byref(pointer), ctypes.byref(length)):
        raise OSError('Native version query failed')
    fixed = ctypes.cast(pointer, ctypes.POINTER(w.DWORD))
    assert fixed[0] == 0xFEEF04BD and length.value >= 52
    version = '.'.join(str(n) for n in [fixed[2] >> 16, fixed[2] & 65535, fixed[3] >> 16, fixed[3] & 65535])
    assert version == '5.0.516.1681', version
    return dict(path=str(path), sha256=hashlib.sha256(path.read_bytes()).hexdigest(), file_version=version)

def listeners(pid):
    """Query only listener rows belonging to the exact owned PID."""
    found = []
    for family, row_size, pid_offset in [(2, 24, 20), (23, 56, 52)]:
        size = w.ULONG(0)
        api = ctypes.windll.iphlpapi.GetExtendedTcpTable
        status = api(None, ctypes.byref(size), False, family, 3, 0)
        if status not in (0, 122):
            raise OSError('TCP listener size query failed')
        table = ctypes.create_string_buffer(size.value)
        if api(table, ctypes.byref(size), False, family, 3, 0):
            raise OSError('TCP listener query failed')
        data = table.raw
        count = struct.unpack_from('=I', data)[0]
        for i in range(count):
            offset = 4 + i * row_size
            if struct.unpack_from('=I', data, offset + pid_offset)[0] != pid:
                continue
            if family == 2:
                address = socket.inet_ntoa(data[offset + 4:offset + 8])
                port = struct.unpack_from('!H', data, offset + 8)[0]
            else:
                address = socket.inet_ntop(socket.AF_INET6, data[offset:offset + 16])
                port = struct.unpack_from('!H', data, offset + 20)[0]
            found.append(dict(family=family, address=address, port=port))
    return found

class Memory(ctypes.Structure):
    _fields_ = [('cb', w.DWORD), ('faults', w.DWORD)] + [(key, ctypes.c_size_t) for key in ['peak_ws', 'ws', 'peak_pool', 'pool', 'peak_nonpool', 'nonpool', 'page', 'peak_page']]

def snapshot(process):
    if os.name == 'nt':
        times = [ctypes.c_ulonglong() for _ in range(4)]
        handle = w.HANDLE(process._handle)
        if not ctypes.windll.kernel32.GetProcessTimes(handle, *(ctypes.byref(t) for t in times)):
            raise OSError('GetProcessTimes failed')
        memory = Memory()
        memory.cb = ctypes.sizeof(memory)
        if not ctypes.windll.psapi.GetProcessMemoryInfo(handle, ctypes.byref(memory), memory.cb):
            raise OSError('GetProcessMemoryInfo failed')
        return dict(identity=times[0].value, cpu_seconds=(times[2].value + times[3].value) / 1e7,
                    peak_working_set=memory.peak_ws, working_set=memory.ws)
    # Linux CI source checks do not launch native processes. No unsupported OS
    # fallback silently weakens the reviewed Windows resource contract.
    raise RuntimeError('Native resource monitoring currently supports Windows only')

class Budget:
    def __init__(self, issued_monotonic, deadline_monotonic):
        self.started = issued_monotonic
        self.deadline = deadline_monotonic
        assert 0 < self.deadline - self.started <= 90
        assert self.started <= time.monotonic() < self.deadline

    def run(self, command, cwd, receipt, wall_limit=30, diagnostic_file=None):
        if os.name != 'nt':
            raise RuntimeError('No reviewed native monitor for this platform')
        if time.monotonic() >= self.deadline:
            raise RuntimeError('Shared lease expired before process creation')
        began = time.monotonic()
        child = subprocess.Popen(command, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                 creationflags=subprocess.CREATE_NO_WINDOW)
        state = dict(pid=child.pid, command=command, samples=0, stop_reason=None, reaped=False, observed_listeners=[])
        stdout = stderr = b''
        def check(final=False):
            resources = snapshot(child)
            if 'identity' in state and state['identity'] != resources['identity']:
                raise RuntimeError('Owned process identity changed')
            state.update(resources)
            for listener in listeners(child.pid):
                if listener not in state['observed_listeners']:
                    state['observed_listeners'].append(listener)
                if listener['family'] != 2 or listener['address'] != '127.0.0.1':
                    raise RuntimeError('Owned listener outside authorized IPv4 loopback')
            state['samples'] += 1
            state['wall_seconds'] = time.monotonic() - began
            state['aggregate_wall_seconds'] = time.monotonic() - self.started
            if resources['cpu_seconds'] > 40 or resources['peak_working_set'] > 512 * 1024**2:
                raise RuntimeError('CPU or memory limit')
            if state['wall_seconds'] > wall_limit or time.monotonic() > self.deadline:
                raise RuntimeError('Wall limit')
            if diagnostic_file and diagnostic_file.exists() and DIAGNOSTIC.search(diagnostic_file.read_text(errors='replace')):
                raise RuntimeError('Engine diagnostic')
            if final:
                state['final_resource_checked'] = True
        try:
            while True:
                check()
                try:
                    stdout, stderr = child.communicate(timeout=.025)
                    break
                except subprocess.TimeoutExpired:
                    pass
            # Keep the Windows process handle open through final accounting.
            check(final=True)
            state['returncode'] = child.returncode
            if DIAGNOSTIC.search((stdout + stderr).decode(errors='replace')):
                raise RuntimeError('Final engine diagnostic')
            if child.returncode:
                raise RuntimeError('Nonzero child exit')
            return subprocess.CompletedProcess(command, child.returncode, stdout, stderr)
        except BaseException as error:
            state['stop_reason'] = str(error)
            raise
        finally:
            if child.poll() is None:
                child.kill()
            tail_out, tail_err = child.communicate()
            state.update(returncode=child.returncode, reaped=child.poll() is not None)
            state['final_accounting_monotonic'] = time.monotonic()
            expired = state['final_accounting_monotonic'] > self.deadline
            if expired and not state['stop_reason']:
                state['stop_reason'] = 'Shared lease expired during final accounting'
            Path(receipt).write_text(json.dumps(state, indent=2) + '\n')
            if diagnostic_file and diagnostic_file.exists():
                Path(str(receipt) + '.engine.log').write_bytes(diagnostic_file.read_bytes())
            Path(str(receipt) + '.stdout').write_bytes(stdout or tail_out)
            Path(str(receipt) + '.stderr').write_bytes(stderr or tail_err)
            if expired:
                raise RuntimeError('Shared lease expired during final accounting')
