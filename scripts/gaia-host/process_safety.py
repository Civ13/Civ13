"""Process checks and kills that never go through tasklist, taskkill or WMI.

On 2026-11-19 a broken WMI provider ("Provider load failure") made tasklist hang, and a
host start crashed on the timeout and kept Gaia down. Everything here asks the kernel
directly: Toolhelp32 snapshots, OpenProcess, GetProcessTimes and QueryFullProcessImageNameW
on Windows, /proc elsewhere. Checks answer None for "unknown" instead of raising.

Criticality rules (docs: scripts/gaia-host/README.md, "Process safety"):
- Looking never kills: a check that fails answers unknown.
- A kill only ends a verified target. end() checks the executable (and, for a pid read
  from a file, that the process is older than the file) on the same handle it then
  terminates, so a reused pid can never redirect it. An unverified target is left
  running and Unverified names it, with the manual step.
"""
from __future__ import annotations

import ctypes
import fnmatch
import os
import signal
import time
from pathlib import Path

# DreamDaemon: dd.exe (Windows console daemon), dreamdaemon.exe (GUI), DreamDaemon (Linux).
WORLD_IMAGES = ('dd.exe', 'dreamdaemon.exe', 'dreamdaemon')
PYTHON_IMAGES = ('python*', 'pythonw*', 'py.exe')
# A process created up to this long after the moment it must predate still counts
# (file timestamps and process times come from different clocks and resolutions).
BORN_SLACK_SECONDS = 2.0
EXIT_WAIT_SECONDS = 5.0


class Unverified(RuntimeError):
    """The process could not be shown to be the one meant, so it was left running."""


class Expect:
    """What a process about to be ended must be.

    images: fnmatch patterns for the executable's file name (case-insensitive).
    born_before: a time (epoch seconds) the process must already have existed at, for a pid
    read from a file or recorded earlier; a younger process holds a reused pid.
    what: the name used in refusals."""

    def __init__(self, images, born_before=None, what='the expected process'):
        self.images = tuple(name.lower() for name in images if name)
        self.born_before = born_before
        self.what = what

    def problem(self, ident):
        """None when ident matches, else why not (also when ident is unknown)."""
        if ident is None:
            return 'it could not be inspected'
        name = Path(str(ident.get('exe') or '').replace('\\', '/')).name.lower()
        if not name or not any(fnmatch.fnmatchcase(name, pattern) for pattern in self.images):
            return 'it is %s' % (ident.get('exe') or 'an unknown program')
        if self.born_before is not None and ident.get('created') is not None \
                and ident['created'] > float(self.born_before) + BORN_SLACK_SECONDS:
            return 'it started after the recorded process (the pid was reused)'
        return None


def world_expect(config=None, born_before=None):
    """DreamDaemon, including the daemon a config names."""
    images = list(WORLD_IMAGES)
    daemon = (config or {}).get('daemon')
    if daemon:
        images.append(Path(str(daemon).replace('\\', '/')).name)
    return Expect(images, born_before, 'DreamDaemon')


def python_expect(born_before=None):
    return Expect(PYTHON_IMAGES, born_before, 'Python')


# -- Windows ------------------------------------------------------------------
PROCESS_TERMINATE = 0x0001
PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
SYNCHRONIZE = 0x00100000
TH32CS_SNAPPROCESS = 0x00000002
STILL_ACTIVE = 259
WAIT_OBJECT_0 = 0
EPOCH_AS_FILETIME = 116444736000000000


def _kernel32():
    from ctypes import wintypes
    k = ctypes.WinDLL('kernel32', use_last_error=True)
    k.OpenProcess.argtypes = (wintypes.DWORD, wintypes.BOOL, wintypes.DWORD)
    k.OpenProcess.restype = wintypes.HANDLE
    k.CloseHandle.argtypes = (wintypes.HANDLE,)
    k.GetProcessTimes.argtypes = (wintypes.HANDLE,) + (ctypes.POINTER(wintypes.FILETIME),) * 4
    k.QueryFullProcessImageNameW.argtypes = (wintypes.HANDLE, wintypes.DWORD, wintypes.LPWSTR, ctypes.POINTER(wintypes.DWORD))
    k.GetExitCodeProcess.argtypes = (wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD))
    k.TerminateProcess.argtypes = (wintypes.HANDLE, wintypes.UINT)
    k.WaitForSingleObject.argtypes = (wintypes.HANDLE, wintypes.DWORD)
    k.WaitForSingleObject.restype = wintypes.DWORD
    k.CreateToolhelp32Snapshot.argtypes = (wintypes.DWORD, wintypes.DWORD)
    k.CreateToolhelp32Snapshot.restype = wintypes.HANDLE
    k.ProcessIdToSessionId.argtypes = (wintypes.DWORD, ctypes.POINTER(wintypes.DWORD))
    k.Process32FirstW.argtypes = (wintypes.HANDLE, ctypes.c_void_p)
    k.Process32NextW.argtypes = (wintypes.HANDLE, ctypes.c_void_p)
    return k


def _entry_type():
    from ctypes import wintypes

    class PROCESSENTRY32W(ctypes.Structure):
        _fields_ = [('dwSize', wintypes.DWORD), ('cntUsage', wintypes.DWORD), ('th32ProcessID', wintypes.DWORD),
                    ('th32DefaultHeapID', ctypes.c_size_t), ('th32ModuleID', wintypes.DWORD),
                    ('cntThreads', wintypes.DWORD), ('th32ParentProcessID', wintypes.DWORD),
                    ('pcPriClassBase', ctypes.c_long), ('dwFlags', wintypes.DWORD),
                    ('szExeFile', ctypes.c_wchar * 260)]
    return PROCESSENTRY32W


def _win_processes():
    k = _kernel32()
    entry_type = _entry_type()
    snap = k.CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
    if not snap or snap == ctypes.c_void_p(-1).value:
        return None
    rows = []
    try:
        entry = entry_type()
        entry.dwSize = ctypes.sizeof(entry_type)
        ok = k.Process32FirstW(snap, ctypes.byref(entry))
        while ok:
            rows.append((int(entry.th32ProcessID), int(entry.th32ParentProcessID), entry.szExeFile))
            ok = k.Process32NextW(snap, ctypes.byref(entry))
    finally:
        k.CloseHandle(snap)
    return rows


def _win_handle_identity(k, handle, pid):
    from ctypes import wintypes
    times = [wintypes.FILETIME() for _ in range(4)]
    if not k.GetProcessTimes(handle, *[ctypes.byref(t) for t in times]):
        return None
    created = (times[0].dwHighDateTime << 32) | times[0].dwLowDateTime
    size = wintypes.DWORD(32768)
    buffer = ctypes.create_unicode_buffer(size.value)
    exe = buffer.value if k.QueryFullProcessImageNameW(handle, 0, buffer, ctypes.byref(size)) else None
    return {'pid': pid, 'created': (created - EPOCH_AS_FILETIME) / 1e7, 'exe': exe}


def _win_alive(k, handle):
    from ctypes import wintypes
    code = wintypes.DWORD()
    return bool(k.GetExitCodeProcess(handle, ctypes.byref(code))) and code.value == STILL_ACTIVE


# -- POSIX ----------------------------------------------------------------------
def _boot_time():
    try:
        for line in Path('/proc/stat').read_text().splitlines():
            if line.startswith('btime '):
                return float(line.split()[1])
    except (OSError, ValueError):
        pass
    return None


def _proc_stat(pid):
    """(ppid, comm, starttime ticks) from /proc/<pid>/stat, or None."""
    try:
        raw = Path('/proc/%d/stat' % pid).read_text()
    except (OSError, ValueError):
        return None
    left, right = raw.find('('), raw.rfind(')')
    if left < 0 or right < 0:
        return None
    fields = raw[right + 2:].split()
    try:
        return int(fields[1]), raw[left + 1:right], int(fields[19])
    except (IndexError, ValueError):
        return None


def _posix_identity(pid):
    stat = _proc_stat(pid)
    if stat is None:
        return None
    boot = _boot_time()
    created = boot + stat[2] / os.sysconf('SC_CLK_TCK') if boot is not None else None
    try:
        exe = os.readlink('/proc/%d/exe' % pid)
    except OSError:
        exe = stat[1]  # comm: the first 15 characters of the name
    return {'pid': pid, 'created': created, 'exe': exe}


def _posix_processes():
    try:
        names = os.listdir('/proc')
    except OSError:
        return None
    rows = []
    for name in names:
        if name.isdigit():
            stat = _proc_stat(int(name))
            if stat:
                rows.append((int(name), stat[0], stat[1]))
    return rows


# -- public ---------------------------------------------------------------------
def processes():
    """Every process as (pid, parent pid, executable name), or None when unknown."""
    try:
        return _win_processes() if os.name == 'nt' else _posix_processes()
    except (OSError, AttributeError, ValueError):
        return None


def identity(pid):
    """{'pid', 'created' (epoch seconds), 'exe'} for a running process, or None when unknown."""
    try:
        pid = int(pid)
        if pid <= 0:
            return None
        if os.name != 'nt':
            return _posix_identity(pid)
        k = _kernel32()
        handle = k.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
        if not handle:
            return None
        try:
            return _win_handle_identity(k, handle, pid) if _win_alive(k, handle) else None
        finally:
            k.CloseHandle(handle)
    except (OSError, AttributeError, ValueError, TypeError):
        return None


def running_in_session(image, session=None):
    """True/False whether a process named image runs in the logon session (this process's
    session by default), or None when that cannot be told. Windows only; None elsewhere."""
    if os.name != 'nt':
        return None
    try:
        from ctypes import wintypes
        k = _kernel32()
        if session is None:
            own = wintypes.DWORD()
            if not k.ProcessIdToSessionId(os.getpid(), ctypes.byref(own)):
                return None
            session = own.value
        rows = processes()
        if rows is None:
            return None
        for pid, _, name in rows:
            if name.lower() == image.lower():
                found = wintypes.DWORD()
                if k.ProcessIdToSessionId(pid, ctypes.byref(found)) and found.value == session:
                    return True
        return False
    except (OSError, AttributeError, ValueError):
        return None


def descendants(pid, created=None, rows=None):
    """Pids started (directly or not) by pid. A child counts only when it is younger than its
    parent, since a parent pid in the table may name a process that has since been reused."""
    rows = processes() if rows is None else rows
    if not rows:
        return []
    children = {}
    for child, parent, _ in rows:
        if child != parent:
            children.setdefault(parent, []).append(child)
    born = {pid: created}
    found, queue = [], [pid]
    while queue:
        parent = queue.pop(0)
        for child in children.get(parent, []):
            if child in born:
                continue
            ident = identity(child)
            if ident is None:
                continue
            if born.get(parent) is not None and ident.get('created') is not None \
                    and ident['created'] + BORN_SLACK_SECONDS < born[parent]:
                continue  # older than its "parent": the parent pid was reused
            born[child] = ident.get('created')
            found.append(child)
            queue.append(child)
    return found


def _end_one_windows(pid, expect, wait):
    """Open, check and terminate one process on a single handle. True when it has ended."""
    k = _kernel32()
    handle = k.OpenProcess(PROCESS_TERMINATE | PROCESS_QUERY_LIMITED_INFORMATION | SYNCHRONIZE, False, pid)
    if not handle:
        if identity(pid) is None and not _exists_windows(pid):
            return True  # already gone
        raise Unverified('process %d could not be opened (WinError %d); it was left running'
                         % (pid, ctypes.get_last_error()))
    try:
        if not _win_alive(k, handle):
            return True
        ident = _win_handle_identity(k, handle, pid)
        problem = expect.problem(ident) if expect else None
        if problem:
            raise Unverified('process %d is not %s (%s); it was left running' % (pid, expect.what, problem))
        if not k.TerminateProcess(handle, 1) and _win_alive(k, handle):
            raise RuntimeError('TerminateProcess failed for %d (WinError %d)' % (pid, ctypes.get_last_error()))
        return k.WaitForSingleObject(handle, int(wait * 1000)) == WAIT_OBJECT_0 or not _win_alive(k, handle)
    finally:
        k.CloseHandle(handle)


def _exists_windows(pid):
    rows = processes()
    return rows is None or any(row[0] == pid for row in rows)


def _end_one_posix(pid, expect, wait):
    pidfd = None
    try:
        if hasattr(os, 'pidfd_open'):
            try:
                pidfd = os.pidfd_open(pid)  # pins the process: a reused pid cannot be signalled
            except ProcessLookupError:
                return True
            except OSError:
                pidfd = None
        ident = _posix_identity(pid)
        if ident is None:
            if not Path('/proc/%d' % pid).exists():
                return True
            if expect:
                raise Unverified('process %d could not be inspected; it was left running' % pid)
        problem = expect.problem(ident) if expect else None
        if problem:
            raise Unverified('process %d is not %s (%s); it was left running' % (pid, expect.what, problem))
        try:
            if pidfd is not None:
                signal.pidfd_send_signal(pidfd, signal.SIGKILL)
            else:
                os.kill(pid, signal.SIGKILL)
        except ProcessLookupError:
            return True
        deadline = time.monotonic() + wait
        while time.monotonic() < deadline:
            stat = _proc_stat(pid)
            if stat is None or _zombie(pid):
                return True
            time.sleep(0.05)
        return False
    finally:
        if pidfd is not None:
            os.close(pidfd)


def _zombie(pid):
    try:
        raw = Path('/proc/%d/stat' % pid).read_text()
        return raw[raw.rfind(')') + 2:].split()[0] in ('Z', 'X')
    except (OSError, IndexError):
        return True


def end(pid, expect=None, tree=False, wait=EXIT_WAIT_SECONDS):
    """End pid (and, with tree, the processes it started) after checking it against expect.

    Raises Unverified, leaving everything running, when pid does not match expect. The
    root is checked and ended on one handle; its children are only ended once the root
    has passed its check, and only children younger than their parent. Returns True when
    the root has ended."""
    pid = int(pid)
    if pid <= 0 or pid == os.getpid():
        raise Unverified('refusing to end process %d' % pid)
    kids = []
    if tree:
        root = identity(pid)
        if root is not None and expect is not None and expect.problem(root):
            raise Unverified('process %d is not %s (%s); it was left running' % (pid, expect.what, expect.problem(root)))
        kids = descendants(pid, root.get('created') if root else None) if root else []
    ended = _end_one_windows(pid, expect, wait) if os.name == 'nt' else _end_one_posix(pid, expect, wait)
    for child in kids:
        try:
            _end_one_windows(child, None, 1.0) if os.name == 'nt' else _end_one_posix(child, None, 1.0)
        except (OSError, RuntimeError):
            pass  # a child that went away or will not end does not undo the root's end
    return ended
