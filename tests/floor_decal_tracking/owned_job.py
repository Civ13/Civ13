"""Bounded owned-Job membership queries and injectable accounting drain."""
import ctypes as c
from ctypes import wintypes as w
import time


class ProcessIds(c.Structure):
    _fields_ = [('assigned', w.DWORD), ('count', w.DWORD), ('pids', c.c_size_t * 32)]


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
    value, length = ProcessIds(), w.DWORD()
    adapter.check(adapter.k.QueryInformationJobObject(adapter.job, 3, c.byref(value),
                                                     c.sizeof(value), c.byref(length)))
    require(value.assigned == value.count and value.count <= 32
            and ProcessIds.pids.offset + value.count * c.sizeof(c.c_size_t)
            <= length.value <= c.sizeof(value), 'Truncated owned Job membership')
    return dict(assigned=value.assigned, count=value.count, pids=list(value.pids[:value.count]))


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
