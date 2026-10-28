"""Bounded owned-Job membership queries and injectable accounting drain."""
import ctypes as c
from ctypes import wintypes as w
import time
from types import SimpleNamespace


class ProcessIds(c.Structure):
    # Win32 DWORD is always 32 bits, including when pure tests run on LP64 Linux.
    _fields_ = [('assigned', c.c_uint32), ('count', c.c_uint32), ('pids', c.c_size_t * 32)]


def require(value, message):
    if not value:
        raise RuntimeError(message)


def validate_members(value, child_pid=None):
    require(type(value) is dict and type(value.get('assigned')) is int
            and type(value.get('count')) is int
            and 0 <= value['assigned'] == value['count'] <= 32
            and type(value.get('pids')) is list and len(value['pids']) == value['count']
            and all(type(pid) is int and pid > 0 for pid in value['pids'])
            and len(set(value['pids'])) == value['count'], 'Invalid owned Job membership')
    require(all(pid == child_pid for pid in value['pids']), 'Unexpected owned Job PID')


def query_members(adapter):
    value, length = ProcessIds(), c.c_uint32()
    adapter.check(adapter.k.QueryInformationJobObject(adapter.job, 3, c.byref(value),
                                                     c.sizeof(value), c.byref(length)))
    require(value.assigned == value.count and value.count <= 32
            and ProcessIds.pids.offset + value.count * c.sizeof(c.c_size_t)
            <= length.value <= c.sizeof(value), 'Truncated owned Job membership')
    return dict(assigned=value.assigned, count=value.count, pids=list(value.pids[:value.count]))


def capture_unexpected(adapter, pid):
    """Read-only query of one observed owned-Job PID; never relax its rejection."""
    record = {'pid': pid, 'status': 'unavailable'}
    handle, retained = None, False
    try:
        adapter.k.OpenProcess.argtypes = [w.DWORD, w.BOOL, w.DWORD]
        adapter.k.OpenProcess.restype = w.HANDLE
        handle = adapter.k.OpenProcess(0x1000 | 0x100000, False, pid)
        require(bool(handle), 'Observed Job member handle unavailable')
        def belongs():
            member = w.BOOL()
            adapter.check(adapter.k.IsProcessInJob(handle, adapter.job, c.byref(member)))
            return bool(member.value)
        require(belongs(), 'Observed PID no longer in exact owned Job')
        process = SimpleNamespace(process=handle, thread=None, pid=pid)
        adapter.retained.append(process)
        retained = True
        identity = adapter.identity(process)
        require(belongs(), 'Owned member identity raced Job membership')
        process.verified_identity = identity
        code = w.DWORD()
        adapter.check(adapter.k.GetExitCodeProcess(handle, c.byref(code)))
        exited = adapter.exited(process)
        require(belongs(), 'Owned member wait raced Job membership')
        record.update(status='verified-owned', identity=identity, exit_code=code.value, exited=exited)
    except Exception as exc:
        record['error'] = str(exc)
    finally:
        record['retained_for_cleanup'] = retained
        if handle and not retained:
            adapter.k.CloseHandle(handle)
    return record


def settle(accounting, members, check, record, now=time.monotonic, pause=time.sleep):
    deadline = now() + 2
    while True:
        require(now() <= deadline, 'Owned Job accounting did not drain')
        value, membership = accounting(), members()
        record({'accounting': value, 'membership': membership})
        validate_members(membership)
        check(value)
        require(now() <= deadline, 'Owned Job accounting did not drain')
        require(type(value.get('active')) is int and value['active'] in (0, 1),
                'Invalid terminal Job accounting')
        if value['active'] == 0:
            return value
        remaining = deadline - now()
        require(remaining > 0, 'Owned Job accounting did not drain')
        pause(min(.05, remaining))
