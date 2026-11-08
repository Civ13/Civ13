"""Start, save-and-stop, restart and update a Windows-hosted Civ13 server.

This is the one control path the Discord bot and the launcher share. It does
what an operator does by hand: check the saved world, start the server's
scheduled task, ask the running world to save and shut down, keep a verified
copy of that save, and pull and compile master while the server is stopped.

    python gaia_host.py --config gaia-host.json status
    python gaia_host.py --config gaia-host.json start|stop|restart|update
    python gaia_host.py --config gaia-host.json freeze|thaw|watch
    python gaia_host.py --config gaia-host.json check-update
    python gaia_host.py --config gaia.json [--config other.json ...] [--group group.json ...] serve

status prints one JSON object and never changes anything. The other actions
take a lock, record their progress in <state_dir>/operation.json and run in a
detached worker, so a caller gets an answer within seconds even though a Gaia
save takes minutes. Only one action runs at a time. Actions never take paths,
commands or arguments from the caller; everything comes from the config file.

The world must have config/lifecycle-token.txt (32 hex characters, git-ignored)
for save-and-stop; start writes config/lifecycle-revision.txt from git HEAD.
start and restart first pull and recompile unless the last build (build.json in
the state folder) is already of the fetched revision, so a server never runs a
stale build; a failed fetch or compile leaves it stopped with the error.

freeze suspends the running dd.exe while nobody is online, so it uses no CPU
and its memory can go to the pagefile; thaw resumes the same process, with
every object exactly as it was. watch does both: it freezes the server after
freeze_idle_minutes with no clients and thaws it as soon as a player's TCP
connection reaches the port. The world notices the jump in wall-clock time
itself (code/_helpers/wall_clock.dm).

watch (and serve) is also a watchdog: a world that should be running is started
again from its last completed save when it exits on its own, and ended and
started again when it stops answering its lifecycle status (README, Watchdog).

serve does watch for every instance on this host and runs the doorman. With
--group it also takes every region of a region group (scripts/shard-group), so
one service sleeps, wakes and cold-starts Gaia and all regions alike, and keeps
each group's transfer agents and coordinator running.
"""
from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import socket
import struct
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'nomads-lifecycle'))
from supervisor import byond_text_md5, query  # noqa: E402

# Console programs (git, dm.exe, schtasks, tasklist) run by the windowless host
# service would each flash a console window on Windows.
NO_WINDOW = 0x08000000 if os.name == 'nt' else 0  # CREATE_NO_WINDOW
# Long-lived children (DreamDaemon, workers, agents) get a hidden console of their own rather than
# none (DETACHED_PROCESS): a console program they start, such as the cmd.exe behind DM's shell(),
# then shares that hidden console instead of opening a window that takes focus.
DETACH_FLAGS = NO_WINDOW | 0x00000200 if os.name == 'nt' else 0  # | CREATE_NEW_PROCESS_GROUP

ACTIONS = ('status', 'start', 'stop', 'restart', 'update', 'freeze', 'thaw', 'watch', 'serve', 'check-update',
           'kill', 'force-restart', 'stage', 'unlock', 'force-unlock', 'handover')
# quick or long-running; no detached worker (stage starts its own, beside the action lock)
DIRECT = ('freeze', 'thaw', 'watch', 'serve', 'check-update', 'kill', 'force-restart', 'stage', 'unlock', 'force-unlock')
BELOW_NORMAL_PRIORITY = 0x00004000  # Windows: staged compiles yield to the running worlds
# Status pollers such as the Discord bot connect from this machine, so by
# default only other addresses wake a frozen server.
# Trimming hands a frozen server's memory to the pagefile, but paging ~2 GB back
# in slows the wake past the launcher's patience, so it is opt-in.
FREEZE_DEFAULTS = {'freeze_idle_minutes': 15, 'freeze_trim_memory': False, 'wake_ignore': ['127.0.0.1', '::1'],
                   'wake_poll_seconds': 0.2,
                   # serve: the doorman port the launcher asks before touching a game port
                   'doorman_port': 1713, 'doorman_bind': '0.0.0.0', 'wake_estimate_seconds': 5,
                   # serve: refuse a doorman wake while less physical memory than this is free (0 = never refuse)
                   'wake_min_free_mb': 1024,
                   # A frozen process does not survive a power-down, so it is only frozen once
                   # map_saves holds a save newer than the last player; after a reboot the
                   # doorman starts the world from that save on the next wake request.
                   'freeze_requires_save': True, 'cold_start_estimate_seconds': 300,
                   'cold_start_min_free_mb': 2560,
                   # serve: while less physical memory than this is free, stop the longest-frozen
                   # world (it has saved, so it starts from that save on its next wake). 0 = never.
                   'evict_below_free_mb': 1024,
                   # dd.exe -public needs the host's BYOND account signed in, which on Windows
                   # lives in the BYOND pager (byond.exe) of the same logon session
                   'start_requires_byond_pager': True,
                   # watch/serve watchdog: start a world again that exited on its own (after
                   # crash_grace_seconds), and force-restart one whose lifecycle status has not
                   # answered for hang_minutes (the save timeout while it was busy saving). Both
                   # start from the last completed save. More than watchdog_max_restarts in an
                   # hour leaves it stopped for a person to look at.
                   'watchdog': True, 'crash_grace_seconds': 120, 'hang_minutes': 10, 'watchdog_max_restarts': 3,
                   # region groups: every this many minutes, build the latest revision beside the
                   # running world (stage); it is installed once the world is empty. 0 = only on request.
                   'auto_stage_minutes': 0,
                   # region groups: handover (scripts/shard-group) boots the staged build beside the running
                   # world and waits this long for it to load the save before giving up and leaving the old
                   # world running
                   'load_timeout_seconds': 1800}
MARKER = re.compile(r'^round-v([12]):[0-9a-f]{32}$')
HEX32 = re.compile(r'^[0-9a-f]{32}$')
HEX40 = re.compile(r'^[0-9a-f]{40}$')


class Refused(Exception):
    """An action that was checked and declined; nothing was changed."""


def load_config(path):
    config = json.loads(Path(path).read_text(encoding='utf-8-sig'))
    required = {'repository': str, 'port': int, 'task': str, 'compiler': str, 'git': str, 'state_dir': str}
    for key, kind in required.items():
        if type(config.get(key)) is not kind:
            raise ValueError('config needs %s (%s)' % (key, kind.__name__))
    if not 1 <= config['port'] <= 65535:
        raise ValueError('config port is out of range')
    config.setdefault('save_timeout_seconds', 5400)
    config.setdefault('start_timeout_seconds', 120)
    config.setdefault('backups_kept', 3)
    config.setdefault('branch', 'master')
    for key, value in FREEZE_DEFAULTS.items():
        config.setdefault(key, value)
    return config


def parse_meminfo(text):
    """MemAvailable from Linux /proc/meminfo, in MB, or None."""
    for line in text.splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[0] == 'MemAvailable:' and parts[1].isdigit():
            return int(parts[1]) // 1024
    return None


def parse_netstat(text):
    """Rows of (local_port, remote_address, state, pid) from Windows `netstat -ano -p TCP`."""
    rows = []
    for line in text.splitlines():
        parts = line.split()
        if len(parts) != 5 or parts[0] != 'TCP' or not parts[4].isdigit():
            continue
        local, remote = parts[1].rsplit(':', 1), parts[2].rsplit(':', 1)
        if len(local) != 2 or len(remote) != 2 or not local[1].isdigit():
            continue
        rows.append((int(local[1]), remote[0].strip('[]'), parts[3], int(parts[4])))
    return rows


TCP_STATES = {2: 'LISTENING', 5: 'ESTABLISHED'}
# Save and stop (Host.wait_for_exit): a world that closed its port after saving but is still
# running this long later is ended; without its pid, the port must be closed this many polls
# in a row (5 s apart) before the world counts as gone.
STOP_LINGER_SECONDS = 180
STOP_CLOSED_POLLS = 6


def parse_tcp_table(buffer, ipv6=False):
    """Rows of (local_port, remote_address, state, pid) from a GetExtendedTcpTable
    TCP_TABLE_OWNER_PID_ALL buffer (MIB_TCPTABLE_OWNER_PID or MIB_TCP6TABLE_OWNER_PID)."""
    count = struct.unpack_from('<I', buffer, 0)[0]
    size = 56 if ipv6 else 24
    if 4 + count * size > len(buffer):
        raise ValueError('truncated TCP table')
    rows = []
    for index in range(count):
        offset = 4 + index * size
        if ipv6:
            local_port, = struct.unpack_from('<I', buffer, offset + 20)
            remote = socket.inet_ntop(socket.AF_INET6, bytes(buffer[offset + 24:offset + 40]))
            remote_port, state, pid = struct.unpack_from('<III', buffer, offset + 44)
            if remote.startswith('::ffff:') and '.' in remote:
                remote = remote[7:]
        else:
            state, _, local_port, remote_raw, remote_port, pid = struct.unpack_from('<IIIIII', buffer, offset)
            remote = socket.inet_ntop(socket.AF_INET, struct.pack('<I', remote_raw))
        port = socket.ntohs(local_port & 0xffff)
        rows.append((port, remote, TCP_STATES.get(state, str(state)), pid))
    return rows


def windows_tcp_rows():
    """Read both TCP tables through iphlpapi; much cheaper than running netstat."""
    iphlpapi = ctypes.windll.iphlpapi
    rows = []
    for family, ipv6 in ((2, False), (23, True)):  # AF_INET, AF_INET6
        size = ctypes.c_ulong(0)
        for _ in range(4):  # the table can grow between the size query and the read
            buffer = ctypes.create_string_buffer(max(size.value, 4))
            result = iphlpapi.GetExtendedTcpTable(buffer, ctypes.byref(size), False, family, 5, 0)  # OWNER_PID_ALL
            if result == 0:
                rows += parse_tcp_table(buffer.raw[:size.value], ipv6)
                break
            if result != 122:  # ERROR_INSUFFICIENT_BUFFER
                raise OSError('GetExtendedTcpTable failed: %d' % result)
        else:
            raise OSError('GetExtendedTcpTable kept growing')
    return rows


def parse_proc_net(text, ipv6=False):
    """Rows of (local_port, remote_address, state, inode) from Linux /proc/net/tcp{,6}."""
    states = {'01': 'ESTABLISHED', '0A': 'LISTENING'}
    rows = []
    for line in text.splitlines()[1:]:
        parts = line.split()
        if len(parts) < 10:
            continue
        port = int(parts[1].rsplit(':', 1)[1], 16)
        address = parts[2].rsplit(':', 1)[0]
        raw = bytes.fromhex(address)
        if ipv6:
            words = b''.join(raw[i:i + 4][::-1] for i in range(0, 16, 4))
            if words[:12] == b'\0' * 10 + b'\xff\xff':
                remote = socket.inet_ntop(socket.AF_INET, words[12:])
            else:
                remote = socket.inet_ntop(socket.AF_INET6, words)
        else:
            remote = socket.inet_ntop(socket.AF_INET, raw[::-1])
        rows.append((port, remote, states.get(parts[3], parts[3]), int(parts[9])))
    return rows


class Platform:
    """Everything that touches the machine, so tests can replace it."""

    def run(self, argv, cwd=None, timeout=1800, low_priority=False):
        # stdin is DEVNULL so Windows never duplicates an inherited console handle: a host started by the
        # launcher gets the launcher's console input, and duplicating it fails with WinError 50.
        extra = {}
        if low_priority and os.name == 'nt':
            extra['creationflags'] = NO_WINDOW | BELOW_NORMAL_PRIORITY
        elif low_priority:
            extra['preexec_fn'] = lambda: os.nice(10)
        result = subprocess.run(argv, cwd=cwd, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=timeout,
                                **dict({'creationflags': NO_WINDOW}, **extra))
        return result.returncode, (result.stdout + result.stderr)[-4000:]

    def listening(self, port):
        # On Windows a loopback connect to a closed port is retried for about 2 s before it is
        # refused, and the doorman asks this several times per cold region for every status
        # request it serves under one lock. With three cold regions each host_status took ~20 s
        # and the doorman stopped answering at all (2026-11-08). The listening table answers
        # at once; the connect stays as the fallback and for other systems.
        if os.name == 'nt':
            try:
                return any(row[0] == port and row[2] == 'LISTENING' for row in windows_tcp_rows())
            except (OSError, ValueError, AttributeError):
                pass
        try:
            with socket.create_connection(('127.0.0.1', port), timeout=2):
                return True
        except OSError:
            return False

    def query(self, port, token, action='status', operation=None, session=None, extra=None):
        return query(port, token, action, operation, session, extra=extra)

    def start_task(self, name):
        return self.run(['schtasks', '/Run', '/TN', name], timeout=60)

    def start_standby(self, dmb, port):
        """Boot a standby world (a region host feature); the pid, or None when unknown."""
        raise Refused('a standby world needs a region host (scripts/shard-group)')

    def byond_pager_running(self):
        """True/False whether byond.exe runs in this logon session; None off Windows or unknown."""
        if os.name != 'nt':
            return None
        try:
            session = ctypes.c_ulong()
            if not ctypes.windll.kernel32.ProcessIdToSessionId(os.getpid(), ctypes.byref(session)):
                return None
        except (OSError, AttributeError):
            return None
        code, out = self.run(['tasklist', '/FI', 'IMAGENAME eq byond.exe', '/FI', 'SESSION eq %d' % session.value,
                              '/FO', 'CSV', '/NH'], timeout=30)
        if code != 0:
            return None
        return '"byond.exe"' in out.lower()

    def task_ready(self, name):
        code, out = self.run(['schtasks', '/Query', '/TN', name, '/FO', 'LIST'], timeout=60)
        return code == 0 and re.search(r'^Status:\s+Ready\s*$', out, re.M) is not None

    def detach(self, argv):
        flags = DETACH_FLAGS
        subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         creationflags=flags, start_new_session=os.name != 'nt', close_fds=True)

    def sleep(self, seconds):
        time.sleep(seconds)

    # -- freezing ----------------------------------------------------------
    def tcp_rows(self):
        if os.name == 'nt':
            try:
                return windows_tcp_rows()
            except (OSError, ValueError, AttributeError):
                code, out = self.run(['netstat', '-ano', '-p', 'TCP'], timeout=60)
                return parse_netstat(out) if code == 0 else []
        rows = []
        for name, ipv6 in (('tcp', False), ('tcp6', True)):
            try:
                rows += parse_proc_net(Path('/proc/net/' + name).read_text(), ipv6)
            except OSError:
                pass
        return rows

    def server_pid(self, port):
        """The process listening on the port, or None."""
        rows = [row for row in self.tcp_rows() if row[0] == port and row[2] == 'LISTENING']
        if not rows:
            return None
        if os.name == 'nt':
            return rows[0][3]
        inodes = {'socket:[%d]' % row[3] for row in rows}
        for entry in Path('/proc').iterdir():
            if not entry.name.isdigit():
                continue
            try:
                if any(os.readlink(fd) in inodes for fd in (entry / 'fd').iterdir()):
                    return int(entry.name)
            except OSError:
                continue
        return None

    def status_topic(self, port):
        """The world's public status JSON text, asked from this machine."""
        from doorman import topic
        return topic(port, 'status=1&format=json')

    def region_topic(self, port):
        """The world's shard_region JSON text (its region group view)."""
        from doorman import topic
        return topic(port, 'shard_region=1&format=json')

    def boot_time(self):
        """Unix time the machine booted, or None if unknown."""
        try:
            if os.name == 'nt':
                kernel32 = ctypes.windll.kernel32
                kernel32.GetTickCount64.restype = ctypes.c_ulonglong
                return time.time() - kernel32.GetTickCount64() / 1000
            for line in Path('/proc/stat').read_text().splitlines():
                if line.startswith('btime '):
                    return float(line.split()[1])
        except (OSError, AttributeError, ValueError):
            pass
        return None

    def free_memory_mb(self):
        """Physical memory available to a new demand, in MB, or None if unknown."""
        try:
            if os.name == 'nt':
                class MemoryStatus(ctypes.Structure):
                    _fields_ = [('dwLength', ctypes.c_ulong), ('dwMemoryLoad', ctypes.c_ulong),
                                ('ullTotalPhys', ctypes.c_ulonglong), ('ullAvailPhys', ctypes.c_ulonglong),
                                ('ullTotalPageFile', ctypes.c_ulonglong), ('ullAvailPageFile', ctypes.c_ulonglong),
                                ('ullTotalVirtual', ctypes.c_ulonglong), ('ullAvailVirtual', ctypes.c_ulonglong),
                                ('ullAvailExtendedVirtual', ctypes.c_ulonglong)]
                status = MemoryStatus()
                status.dwLength = ctypes.sizeof(MemoryStatus)
                if not ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(status)):
                    return None
                return status.ullAvailPhys // (1024 * 1024)
            return parse_meminfo(Path('/proc/meminfo').read_text())
        except (OSError, AttributeError, ValueError):
            return None

    def connections(self, port):
        """Remote addresses with an established connection to the port."""
        return [row[1] for row in self.tcp_rows() if row[0] == port and row[2] == 'ESTABLISHED']

    def alive(self, pid):
        if os.name == 'nt':
            kernel32 = ctypes.WinDLL('kernel32', use_last_error=True)
            kernel32.OpenProcess.restype = ctypes.c_void_p
            handle = kernel32.OpenProcess(0x1000, False, pid)  # PROCESS_QUERY_LIMITED_INFORMATION
            if not handle:
                # A process we may not query still exists, as on POSIX.
                return ctypes.get_last_error() == 5  # ERROR_ACCESS_DENIED
            code = ctypes.c_ulong()
            ok = ctypes.windll.kernel32.GetExitCodeProcess(handle, ctypes.byref(code))
            ctypes.windll.kernel32.CloseHandle(handle)
            return bool(ok) and code.value == 259  # STILL_ACTIVE
        try:
            os.kill(pid, 0)
            return True
        except ProcessLookupError:
            return False
        except PermissionError:
            return True

    def _open(self, pid, access):
        kernel32 = ctypes.windll.kernel32
        kernel32.OpenProcess.restype = ctypes.c_void_p
        return kernel32.OpenProcess(access, False, pid)

    def suspend(self, pid, trim=True):
        if os.name != 'nt':
            os.kill(pid, 19)  # SIGSTOP
            return
        # PROCESS_SUSPEND_RESUME | PROCESS_SET_QUOTA | PROCESS_QUERY_INFORMATION
        handle = self._open(pid, 0x0800 | 0x0100 | 0x0400)
        if not handle:
            raise RuntimeError('cannot open the server process (WinError %d)' % ctypes.GetLastError())
        try:
            status = ctypes.windll.ntdll.NtSuspendProcess(ctypes.c_void_p(handle))
            if status:
                raise RuntimeError('NtSuspendProcess failed: 0x%08x' % (status & 0xffffffff))
            if trim:  # hand the frozen process's pages to the pagefile
                ctypes.windll.kernel32.K32EmptyWorkingSet(ctypes.c_void_p(handle))
        finally:
            ctypes.windll.kernel32.CloseHandle(ctypes.c_void_p(handle))

    def terminate(self, pid):
        if os.name != 'nt':
            os.kill(pid, 9)  # SIGKILL also ends a stopped process
            return
        handle = self._open(pid, 0x0001)  # PROCESS_TERMINATE
        if not handle:
            raise RuntimeError('cannot open the server process (WinError %d)' % ctypes.GetLastError())
        try:
            if not ctypes.windll.kernel32.TerminateProcess(ctypes.c_void_p(handle), 1):
                raise RuntimeError('TerminateProcess failed (WinError %d)' % ctypes.GetLastError())
        finally:
            ctypes.windll.kernel32.CloseHandle(ctypes.c_void_p(handle))

    def kill_tree(self, pid):
        """End a process and everything it started (a stream save helper, a shell() child)."""
        if os.name != 'nt':
            os.kill(pid, 9)
            return
        code, out = self.run(['taskkill', '/F', '/T', '/PID', str(pid)], timeout=60)
        if code != 0 and self.alive(pid):
            self.terminate(pid)

    def resume(self, pid):
        if os.name != 'nt':
            os.kill(pid, 18)  # SIGCONT
            return
        handle = self._open(pid, 0x0800)
        if not handle:
            raise RuntimeError('cannot open the server process (WinError %d)' % ctypes.GetLastError())
        try:
            status = ctypes.windll.ntdll.NtResumeProcess(ctypes.c_void_p(handle))
            if status:
                raise RuntimeError('NtResumeProcess failed: 0x%08x' % (status & 0xffffffff))
        finally:
            ctypes.windll.kernel32.CloseHandle(ctypes.c_void_p(handle))

    def now(self):
        return time.time()


def sha256(path):
    digest = hashlib.sha256()
    with open(path, 'rb') as handle:
        for block in iter(lambda: handle.read(1 << 20), b''):
            digest.update(block)
    return digest.hexdigest()


def check_save(saves):
    """Return the saved generation, or raise Refused if the save cannot be loaded.

    An empty folder is a fresh world. A restart intent left by save-and-stop
    must belong to the saved generation.
    """
    if saves.is_symlink() or not saves.is_dir():
        raise Refused('map_saves is missing or is a link')
    names = sorted(p.name for p in saves.iterdir())
    if not names:
        return None
    try:
        state = json.loads((saves / 'round.json').read_text(encoding='utf-8-sig'))
        marker = (saves / 'save_complete.txt').read_text(encoding='utf-8-sig').strip()
    except (OSError, ValueError):
        raise Refused('the save has no readable round.json and save_complete.txt')
    match = MARKER.match(marker)
    if not match or state.get('generation') != marker or str(state.get('version')) != match.group(1):
        raise Refused('the save marker does not match round.json')
    levels = state.get('maxz')
    if type(levels) is not int or not 1 <= levels <= 255:
        raise Refused('the save has an invalid level count')
    if not (saves / 'map.txt').is_file() or state.get('metadata') != byond_text_md5(saves / 'map.txt'):
        raise Refused('map.txt does not match round.json')
    for z in range(1, levels + 1):
        level = saves / ('%d.sav' % z)
        if not (level.is_file() and level.stat().st_size):
            raise Refused('level %d of the save is missing' % z)
    if any(name.endswith('.lk') for name in names):
        raise Refused('the save still has BYOND lock files')
    intent_path = saves / 'restart_intent.json'
    if intent_path.exists():
        try:
            intent = json.loads(intent_path.read_text(encoding='utf-8-sig'))
        except ValueError:
            raise Refused('restart_intent.json is unreadable')
        if intent.get('generation') != marker:
            raise Refused('restart_intent.json belongs to another save')
    return marker


def recover_interrupted_save(repo, now=time.time):
    """Put the last completed generation back after an interrupted save.

    A save removes map_saves/save_complete.txt first and writes it last, so a
    crash or power-down during the save leaves files without a marker, which
    check_save refuses. The world copied the whole previous generation to
    map_backups/ before replacing any level, so when that copy is complete and
    marked it is swapped in (two renames, no copying) and the interrupted files
    are kept beside it as map_saves.interrupted-<time> for inspection, the
    newest one only. Returns (generation, interrupted path) or None when
    nothing was done. A restart intent means the restart transaction owns the
    recovery, so nothing is touched then.
    """
    saves = repo / 'map_saves'
    backups = repo / 'map_backups'
    if saves.is_symlink() or not saves.is_dir() or backups.is_symlink() or not backups.is_dir():
        return None
    names = {p.name for p in saves.iterdir()}
    if 'save_complete.txt' in names or 'restart_intent.json' in names:
        return None
    if not any(name in ('map.txt', 'round.json') or name.endswith('.sav') for name in names):
        return None
    try:
        generation = check_save(backups)
    except Refused:
        return None
    if generation is None:
        return None
    interrupted = repo / ('map_saves.interrupted-' + time.strftime('%Y%m%d-%H%M%S', time.gmtime(now())))
    for old in sorted(repo.glob('map_saves.interrupted-*')):
        if old.is_dir() and not old.is_symlink():
            shutil.rmtree(old)
    os.replace(saves, interrupted)
    os.replace(backups, saves)
    return generation, interrupted


def copy_save(saves, destination):
    """Copy map_saves and check every file's SHA-256 against the original."""
    destination.mkdir(parents=True)
    receipt = {}
    for item in sorted(saves.iterdir()):
        if item.is_file():
            shutil.copy2(item, destination / item.name)
            receipt[item.name] = sha256(item)
            if sha256(destination / item.name) != receipt[item.name]:
                raise RuntimeError('backup copy of %s does not match' % item.name)
    (destination / 'backup-receipt.json').write_text(json.dumps(receipt, indent=1, sort_keys=True), encoding='utf-8')
    return receipt


class Host:
    def __init__(self, config, platform=None, script=None):
        self.config = config
        for key, value in FREEZE_DEFAULTS.items():
            config.setdefault(key, value)
        self.platform = platform or Platform()
        self.script = script or Path(__file__).resolve()
        self.repo = Path(config['repository'])
        self.state_dir = Path(config['state_dir'])
        self.state_file = self.state_dir / 'operation.json'
        self.lock = self.state_dir / 'action.lock'
        self.freeze_file = self.state_dir / 'freeze.json'
        self.cold_file = self.state_dir / 'cold.json'
        self.activity_file = self.state_dir / 'activity.json'
        # running.json: the world should be up (a start finished, or it was seen answering);
        # a stop or a forced stop removes it. The watchdog only restarts such a world.
        self.running_file = self.state_dir / 'running.json'
        self.watchdog_file = self.state_dir / 'watchdog.json'
        # Written by the world when an admin uses Save and Shut Down in game: the exit that
        # follows is a stop, not a crash (restart_transaction.dm write_stop_marker).
        self.stop_marker = self.repo / 'data' / 'stopped_in_game.json'
        self.down_since = None       # when the port was first seen closed while the world should run
        self.listening_since = None  # when the port was first seen open in this watch
        self.last_answer = None      # when the world last answered lifecycle status in this watch
        self.last_busy = False       # whether that answer said it was saving
        self.next_stage = 0.0
        self.next_install_check = 0.0

    # -- state -------------------------------------------------------------
    def record(self, **values):
        self.state_dir.mkdir(parents=True, exist_ok=True)
        state = self.read_state()
        state.update(values, updated=int(self.platform.now()))
        temporary = self.state_file.with_suffix('.tmp')
        temporary.write_text(json.dumps(state, indent=1, sort_keys=True), encoding='utf-8')
        os.replace(temporary, self.state_file)
        return state

    def read_json(self, path):
        try:
            value = json.loads(path.read_text(encoding='utf-8'))
        except (OSError, ValueError):
            return None
        return value if isinstance(value, dict) else None

    def read_state(self):
        try:
            return json.loads(self.state_file.read_text(encoding='utf-8'))
        except (OSError, ValueError):
            return {}

    def token(self):
        path = self.repo / 'config' / 'lifecycle-token.txt'
        try:
            value = path.read_text(encoding='utf-8-sig').strip()
        except OSError:
            return None
        return value if HEX32.match(value) else None

    def world(self):
        """The running world's own status, or None when it does not answer."""
        token = self.token()
        if not token or not self.platform.listening(self.config['port']):
            return None
        try:
            return self.platform.query(self.config['port'], token)
        except (OSError, RuntimeError, ValueError):
            return None

    def status(self):
        frozen = self.frozen()
        if frozen:  # a frozen world cannot answer, and probing it only queues a connection
            return {'port': self.config['port'], 'listening': True, 'state': 'asleep', 'frozen': frozen,
                    'operation': self.read_state() or None, 'busy': self.lock.exists(),
                    'lifecycle_token': self.token() is not None}
        listening = self.platform.listening(self.config['port'])
        world = self.world() if listening else None
        cold = None if listening else self.cold()
        # awake: running; asleep: frozen in memory; cold: down, starts from its save
        # when woken; stopped: down on purpose, wakes are refused.
        report = {'port': self.config['port'], 'listening': listening,
                  'state': 'awake' if listening else ('cold' if cold else 'stopped'),
                  'operation': self.read_state() or None, 'busy': self.lock.exists(),
                  'lifecycle_token': self.token() is not None}
        if cold:
            report['cold'] = cold
        watchdog = self.read_json(self.watchdog_file)
        if watchdog:
            report['watchdog'] = watchdog
        if world:
            report['world'] = {key: world.get(key) for key in
                               ('ready', 'busy', 'clients', 'map', 'generation', 'revision', 'error')}
        return report

    # -- requests from callers ---------------------------------------------
    def request(self, action):
        """Check and accept an action, then hand it to a detached worker."""
        if action not in ACTIONS or action == 'status' or action in DIRECT:
            raise Refused('unknown action')
        self.state_dir.mkdir(parents=True, exist_ok=True)
        if action in ('stop', 'restart', 'update') and self.frozen():
            self.thaw('before ' + action)
        try:
            descriptor = os.open(self.lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        except FileExistsError:
            raise Refused('another action is still running: %s' % self.read_state().get('action'))
        operation = secrets.token_hex(16)
        with os.fdopen(descriptor, 'w') as handle:
            handle.write(operation)
        try:
            self.precheck(action)
        except BaseException:
            self.lock.unlink()
            raise
        self.state_file.unlink(missing_ok=True)
        self.record(action=action, operation=operation, phase='accepted', error=None)
        self.platform.detach([sys.executable, '-I', '-B', str(self.script), '--config', self.config['_path'],
                              '--worker', action, operation])
        return {'accepted': True, 'action': action, 'operation': operation}

    def precheck(self, action):
        listening = self.platform.listening(self.config['port'])
        if action == 'start':
            if listening:
                raise Refused('the server is already running')
            self.recover_interrupted_save()
            check_save(self.repo / 'map_saves')
            if not self.byond_signed_in():
                raise Refused('BYOND is not signed in: start the BYOND pager and sign in first')
            if not self.task_ready_for_start():
                raise Refused('the scheduled task is not Ready')
        elif action in ('stop', 'restart'):
            if not listening:
                raise Refused('the server is not running')
            if not self.token():
                raise Refused('config/lifecycle-token.txt is missing, so the world cannot be asked to save')
            world = self.world()
            if not world:
                raise Refused('the world does not answer lifecycle status')
            # A world that does not save is ended, not asked to save, so readiness to save
            # does not matter (the TDM worlds report not ready in pregame).
            if world.get('persistence_mode') is not False and (world.get('busy') or not world.get('ready')):
                raise Refused('the world is busy or not ready, so it cannot save now')
        elif action == 'update':
            if listening:
                raise Refused('stop the server before updating')
        elif action == 'handover':
            raise Refused('a handover needs a region host (scripts/shard-group)')

    # -- update check --------------------------------------------------------
    def git_text(self, argv, cwd):
        code, out = self.platform.run([self.config['git']] + argv, cwd=cwd, timeout=600)
        if code != 0:
            raise RuntimeError('git %s failed: %s' % (argv[0], out.strip()[-200:]))
        return out.strip().splitlines()[-1] if out.strip() else ''

    def check_update(self):
        """Whether a newer build is available: fetches, never merges or touches the world.

        One JSON line for the launcher's Updates panel: component, current and
        available commits, how many commits behind, and whether update can run now.
        """
        remote = 'origin/' + self.config['branch']
        self.git_text(['fetch', 'origin', self.config['branch']], self.repo)
        return self.update_answer(self.git_text(['rev-parse', 'HEAD'], self.repo),
                                  self.git_text(['rev-parse', remote], self.repo), self.repo)

    def update_answer(self, current, available, repo):
        if not HEX40.match(current) or not HEX40.match(available):
            raise RuntimeError('could not read the commits')
        behind = int(self.git_text(['rev-list', '--count', current + '..' + available], repo) or 0)
        reason = None
        if not behind:
            reason = 'up to date'
        elif self.platform.listening(self.config['port']):
            reason = 'stop the server before updating'
        elif self.lock.exists():
            reason = 'another action is still running'
        return {'component': 'server', 'current': current, 'available': available, 'behind': behind,
                'can_update': reason is None, 'reason': reason}

    # -- freezing ----------------------------------------------------------
    def booted_since(self, moment):
        """True when the machine has restarted since the unix time `moment`."""
        boot = getattr(self.platform, 'boot_time', lambda: None)()
        return boot is not None and moment is not None and boot > moment + 60

    def frozen(self):
        """The freeze record while the frozen process still exists, else None.

        A frozen process that is gone (the machine was powered down or it was killed)
        while nothing else serves the port leaves a cold record: the world is resumed
        from its last save the next time someone asks the doorman to wake it.
        """
        try:
            state = json.loads(self.freeze_file.read_text(encoding='utf-8'))
        except (OSError, ValueError):
            return None
        if (isinstance(state, dict) and type(state.get('pid')) is int and self.platform.alive(state['pid'])
                and not self.booted_since(state.get('frozen_at'))):
            return state
        if isinstance(state, dict) and not self.platform.listening(self.config['port']):
            self.write_json(self.cold_file, {'frozen_at': state.get('frozen_at'), 'pid': state.get('pid'),
                                             'detected_at': int(self.platform.now())})
            self.log({'cold': 'the frozen server is gone; it will start from its last save when woken'})
        self.freeze_file.unlink(missing_ok=True)
        return None

    def cold(self):
        """The cold record while nothing serves the port, else None."""
        try:
            state = json.loads(self.cold_file.read_text(encoding='utf-8'))
        except (OSError, ValueError):
            return None
        if not isinstance(state, dict):
            return None
        if self.platform.listening(self.config['port']):
            self.cold_file.unlink(missing_ok=True)
            return None
        return state

    def task_ready_for_start(self):
        return self.platform.task_ready(self.config['task'])

    def byond_signed_in(self):
        """False only when the pager is known not to be running in this session."""
        if not self.config['start_requires_byond_pager']:
            return True
        return getattr(self.platform, 'byond_pager_running', lambda: None)() is not False

    def start_cold(self, reason):
        """Start a cold server from its last save through the ordinary start action."""
        if not self.cold():
            raise Refused('the server is not waiting for a cold start')
        try:  # an action that was running when the machine went down never finished
            if self.lock.exists() and self.booted_since(self.lock.stat().st_mtime):
                self.lock.unlink()
                self.log({'stale_lock_removed': self.read_state().get('action')})
        except OSError:
            pass
        accepted = self.request('start')
        self.cold_file.unlink(missing_ok=True)
        return dict(accepted, cold_start=True, reason=reason)

    def write_json(self, path, value):
        self.state_dir.mkdir(parents=True, exist_ok=True)
        temporary = path.with_suffix('.tmp')
        temporary.write_text(json.dumps(value), encoding='utf-8')
        os.replace(temporary, path)

    def recover_interrupted_save(self):
        """Swap the completed generation back in after an interrupted save (see the module function)."""
        recovered = recover_interrupted_save(self.repo, self.platform.now)
        if recovered:
            generation, interrupted = recovered
            self.log({'interrupted_save_recovered': generation, 'interrupted_files': str(interrupted)})
        return recovered

    def last_client(self):
        """Unix time a client was last seen on the world, or None."""
        try:
            value = json.loads(self.activity_file.read_text(encoding='utf-8')).get('last_client')
        except (OSError, ValueError, AttributeError):
            return None
        return value if type(value) in (int, float) else None

    def last_save(self):
        """Unix time map_saves last completed a save, or None."""
        try:
            return (self.repo / 'map_saves' / 'save_complete.txt').stat().st_mtime
        except OSError:
            return None

    def saved_since_last_client(self):
        seen = self.last_client()
        saved = self.last_save()
        return seen is None or (saved is not None and saved >= seen)

    def evict(self, reason='low memory'):
        """Stop a frozen server to free its memory. It saved before it froze, so the
        next wake starts it from that save, like after a power-down."""
        state = self.frozen()
        if not state:
            raise Refused('the server is not frozen')
        if not self.config['freeze_requires_save']:
            raise Refused('only a server that saved before freezing can be stopped while asleep')
        if self.lock.exists():
            raise Refused('another action is still running: %s' % self.read_state().get('action'))
        self.platform.terminate(state['pid'])
        self.write_json(self.cold_file, {'frozen_at': state.get('frozen_at'), 'pid': state['pid'],
                                         'detected_at': int(self.platform.now()), 'evicted': reason})
        self.freeze_file.unlink(missing_ok=True)
        return {'evicted': True, 'pid': state['pid'], 'reason': reason}

    def kill(self, reason='forced stop', keep_running=False):
        """Forced stop: end the server process without saving, for a world that hangs.

        Nothing is written to map_saves. The next start restores the last completed
        save: a save that was cut off leaves no marker, and recover_interrupted_save
        swaps the generation in map_backups back in. A worker still waiting on this
        server (a stuck save-and-stop) sees the port close, fails and frees the lock.
        """
        state = self.frozen()
        pid = state['pid'] if state else self.platform.server_pid(self.config['port'])
        if not pid:
            raise Refused('the server is not running')
        self.platform.kill_tree(pid)
        released = self.release_save_locks(pid)
        self.freeze_file.unlink(missing_ok=True)
        self.cold_file.unlink(missing_ok=True)
        if not keep_running:  # stopped on purpose: the watchdog leaves it down
            self.running_file.unlink(missing_ok=True)
        if not self.lock.exists():
            self.record(action='kill', operation=None, phase='killed', error=None, reason=reason)
        return {'killed': True, 'pid': pid, 'reason': reason, 'released_locks': released}

    def release_save_locks(self, pid, wait_seconds=30):
        """Remove the BYOND lock files a killed server left in map_saves.

        A forced stop leaves each open savefile's .lk behind, and check_save then
        refuses every start. They belong to the dead process only, so they are
        removed once it has ended; while it still runs they are left alone.
        Returns the names removed.
        """
        deadline = self.platform.now() + wait_seconds
        while self.platform.alive(pid):
            if self.platform.now() > deadline:
                return []
            self.platform.sleep(1)
        return self.remove_save_locks(self.save_locks())

    def save_locks(self):
        """The BYOND lock files (*.lk) in map_saves, as paths."""
        saves = self.repo / 'map_saves'
        if saves.is_symlink() or not saves.is_dir():
            return []
        return [item for item in sorted(saves.iterdir()) if item.name.endswith('.lk') and item.is_file() and not item.is_symlink()]

    @staticmethod
    def remove_save_locks(locks):
        for item in locks:
            item.unlink(missing_ok=True)
        return [item.name for item in locks]

    def unlock(self, force=False):
        """Check map_saves for BYOND lock files and remove them.

        Safe (the default): refused while the server runs, is frozen or an action
        (a start, save or update) is in progress, because the files may then be in
        use. Force skips those checks, for a lock left by a server whose process is
        gone but still looks alive; removing a lock a live server holds can corrupt
        its save. Afterwards the save is checked and the answer says if it loads.
        """
        locks = self.save_locks()
        running = bool(self.frozen() or self.platform.listening(self.config['port']) or self.platform.server_pid(self.config['port']))
        busy = self.read_state().get('action') if self.lock.exists() else None
        if locks and not force:
            if running:
                raise Refused('the server is running; its lock files may be in use (force-unlock removes them anyway)')
            if busy:
                raise Refused('an action is still running: %s' % busy)
        removed = self.remove_save_locks(locks)
        answer = {'removed': removed, 'forced': bool(force), 'server_running': running}
        try:
            answer['save'] = check_save(self.repo / 'map_saves') or 'empty'
        except Refused as refusal:
            answer['save_refused'] = str(refusal)
        return answer

    def force_restart(self, lock_wait_seconds=180):
        """Forced stop if it is running, then a normal start from the last completed save."""
        killed = None
        if self.frozen() or self.platform.listening(self.config['port']):
            killed = self.kill('forced restart')
        deadline = self.platform.now() + lock_wait_seconds
        while self.lock.exists():
            if self.platform.now() > deadline:
                raise Refused('the stopped server still has an action running: %s' % self.read_state().get('action'))
            self.platform.sleep(2)
        return dict(self.request('start'), killed=bool(killed))

    def freeze(self):
        if self.lock.exists():
            raise Refused('another action is still running: %s' % self.read_state().get('action'))
        if self.frozen():
            raise Refused('the server is already frozen')
        if not self.platform.listening(self.config['port']):
            raise Refused('the server is not running')
        world = self.world()
        if not world:
            raise Refused('the world does not answer lifecycle status')
        if world.get('busy') or not world.get('ready'):
            raise Refused('the world is busy or not ready')
        if world.get('clients'):
            raise Refused('%s client(s) are connected' % world['clients'])
        if self.config['freeze_requires_save'] and not self.saved_since_last_client():
            raise Refused('waiting for a save newer than the last player (a frozen world must survive a power-down)')
        pid = self.platform.server_pid(self.config['port'])
        if not pid:
            raise Refused('could not find the process listening on the port')
        self.state_dir.mkdir(parents=True, exist_ok=True)
        self.platform.suspend(pid, self.config['freeze_trim_memory'])
        state = {'pid': pid, 'frozen_at': int(self.platform.now())}
        self.write_json(self.freeze_file, state)
        self.cold_file.unlink(missing_ok=True)
        return dict(state, frozen=True)

    def thaw(self, reason='requested'):
        state = self.frozen()
        if not state:
            # A cold server (shut down to disk while asleep) wakes by starting from its save,
            # as the doorman does for a player; the launcher's Wake was refused for it (2026-11-08).
            if self.cold():
                return self.start_cold(reason)
            raise Refused('the server is not frozen or cold')
        self.platform.resume(state['pid'])
        self.freeze_file.unlink(missing_ok=True)
        return {'thawed': True, 'pid': state['pid'], 'reason': reason,
                'frozen_seconds': int(self.platform.now()) - state.get('frozen_at', 0)}

    def watch_step(self, idle_since):
        """One pass of the watch loop; returns (idle_since, seconds until the next pass)."""
        self.maybe_stage()
        if self.frozen():
            self.forget_answers()  # a thawed world gets a fresh hang allowance
            if self.install_check_due() and self.install_staged_while_down():
                return None, 30
            ignore = set(self.config['wake_ignore'])
            if any(address not in ignore for address in self.platform.connections(self.config['port'])):
                self.log(self.thaw('player connection'))
            return None, self.config['wake_poll_seconds']
        if self.lock.exists():
            self.forget_answers()
            self.down_since = None
            return None, 30
        if not self.platform.listening(self.config['port']):
            self.forget_answers()
            if self.cold() and self.install_check_due() and self.install_staged_while_down():
                return None, 30
            return None, self.check_crash()
        self.down_since = None
        world = self.world()
        hung = self.check_hang(world)
        if hung is not None:
            return None, hung
        if world and world.get('clients'):
            self.write_json(self.activity_file, {'last_client': int(self.platform.now())})
        if not world or world.get('busy') or not world.get('ready') or world.get('clients'):
            return None, 30
        now = self.platform.now()
        if idle_since is None:
            return now, 30
        if now - idle_since < self.config['freeze_idle_minutes'] * 60:
            return idle_since, 30
        if self.config['freeze_requires_save'] and not self.saved_since_last_client():
            return idle_since, 60  # the world saves itself once it is empty; freeze after that
        if self.update_pending():
            # Empty and saved: the moment to swap in a staged build without kicking anyone.
            try:
                self.log(dict(self.request('restart'), reason='installing the staged build while the world is empty'))
            except Refused as refusal:
                self.log({'staged_install_refused': str(refusal)})
            return None, 30
        try:
            self.log(self.freeze())
        except Refused as refusal:
            self.log({'freeze_refused': str(refusal)})
        return None, 1

    # -- watchdog --------------------------------------------------------------
    def forget_answers(self):
        self.listening_since = None
        self.last_answer = None
        self.last_busy = False

    def mark_running(self):
        self.stop_marker.unlink(missing_ok=True)  # left from an earlier in-game stop
        self.write_json(self.running_file, {'since': int(self.platform.now())})

    def check_crash(self):
        """The world is down: start it again if it should be running. Returns the next wait."""
        if not self.config['watchdog'] or not self.running_file.exists() or self.cold():
            self.down_since = None
            return 30
        if self.stop_marker.exists():
            # An admin saved and shut the world down in game: a stop, so leave it down.
            marker = self.read_json(self.stop_marker) or {}
            self.running_file.unlink(missing_ok=True)
            self.stop_marker.unlink(missing_ok=True)
            self.down_since = None
            self.log({'stopped_in_game': True, 'by': marker.get('by'), 'generation': marker.get('generation')})
            return 30
        now = self.platform.now()
        if self.down_since is None:
            self.down_since = now
        if now - self.down_since < self.config['crash_grace_seconds']:
            return 10  # a reboot or a slow exit closes the port for a moment
        self.down_since = None
        return self.watchdog_restart('crash', 'the server exited without being stopped')

    def check_hang(self, world):
        """Force-restart a running world that stopped answering. None, or the next wait."""
        now = self.platform.now()
        if self.listening_since is None:
            self.listening_since = now
        if world:
            self.last_answer, self.last_busy = now, bool(world.get('busy'))
            if not self.running_file.exists():  # a world started before the watchdog existed
                self.mark_running()
            return None
        # Only a world that answered in this watch can hang: one that never answers (still
        # loading, or lifecycle status switched off) is left alone.
        if (not self.config['watchdog'] or not self.token() or not self.running_file.exists()
                or self.last_answer is None):
            return None
        limit = self.config['hang_minutes'] * 60
        if self.last_busy:
            limit = max(limit, self.config['save_timeout_seconds'])
        silent = now - self.last_answer
        if silent < limit:
            return None
        self.forget_answers()
        return self.watchdog_restart('hang', 'no answer to lifecycle status for %d minutes' % (silent // 60))

    def watchdog_restart(self, kind, detail):
        """Start a crashed or hung world from its last completed save. Returns the next wait."""
        now = int(self.platform.now())
        record = self.read_json(self.watchdog_file) or {}
        recent = [moment for moment in record.get('restarts', []) if type(moment) is int and now - moment < 3600]
        record.update(last_event=kind, last_detail=detail, last_at=now, restarts=recent)
        if len(recent) >= self.config['watchdog_max_restarts']:
            record['gave_up'] = now
            self.write_json(self.watchdog_file, record)
            self.running_file.unlink(missing_ok=True)
            # A hung world is left as it is, for a person to look at (force-restart.bat).
            self.log({'watchdog_gave_up': kind, 'detail': detail, 'restarts_last_hour': len(recent)})
            return 30
        record.pop('gave_up', None)
        if kind == 'hang':
            try:
                self.kill('watchdog: ' + detail, keep_running=True)
            except Refused as refusal:
                self.log({'watchdog_kill_refused': str(refusal)})
                return 30
        need = self.config['cold_start_min_free_mb']
        free = getattr(self.platform, 'free_memory_mb', lambda: None)()
        if need and free is not None and free < need:
            # Not enough memory to load the save now: it starts on the next wake instead.
            self.write_json(self.cold_file, {'detected_at': now, 'watchdog': kind})
            record['cold'] = True
            self.write_json(self.watchdog_file, record)
            self.log({'watchdog': kind, 'detail': detail, 'cold': 'low memory: %d MB free' % free})
            return 30
        try:
            accepted = self.request('start')
        except Refused as refusal:  # BYOND signed out, a broken save, ...: try again later
            record['last_refusal'] = str(refusal)
            self.write_json(self.watchdog_file, record)
            self.log({'watchdog': kind, 'detail': detail, 'start_refused': str(refusal)})
            return 300
        record.pop('last_refusal', None)
        record.pop('cold', None)
        record['restarts'] = recent + [now]
        self.write_json(self.watchdog_file, record)
        self.log(dict(accepted, watchdog=kind, detail=detail))
        return 30

    # -- staged builds (region groups only; see shard_group.RegionHost) ----------
    def request_stage(self):
        raise Refused('staged builds need a region host (scripts/shard-group)')

    def update_pending(self):
        """True when a staged build newer than the running one is ready to install."""
        return False

    def maybe_stage(self):
        minutes = self.config['auto_stage_minutes']
        now = self.platform.now()
        if not minutes or now < self.next_stage:
            return
        self.next_stage = now + minutes * 60
        try:
            self.log(dict(self.request_stage(), reason='auto_stage_minutes'))
        except Refused:
            pass

    def install_check_due(self):
        now = self.platform.now()
        if now < self.next_install_check:
            return False
        self.next_install_check = now + 60
        return True

    def install_staged_while_down(self):
        """Install a ready staged build into an asleep or cold world, which then starts from
        its save with the new build on its next wake. True when an install was started."""
        if self.lock.exists() or not self.config['freeze_requires_save'] or not self.update_pending():
            return False
        try:
            if self.frozen():
                self.log(self.evict('installing the staged build'))
            self.log(dict(self.request('update'), reason='installing the staged build while the world sleeps'))
        except Refused as refusal:
            self.log({'staged_install_refused': str(refusal)})
            return False
        return True

    def watch(self):
        idle_since = None
        while True:
            try:
                idle_since, wait = self.watch_step(idle_since)
            except Exception as error:  # keep watching; a stuck freeze is worse than a missed one
                self.log({'watch_error': str(error)[:300]})
                idle_since, wait = None, 5
            self.platform.sleep(wait)

    def log(self, values):
        print(json.dumps(dict(values, time=int(self.platform.now()))), flush=True)

    # -- worker ------------------------------------------------------------
    def work(self, action, operation):
        try:
            if self.lock.read_text().strip() != operation:
                return  # another request owns the lock; leave it alone
        except OSError:
            return
        try:
            # A server only ever runs a build of the latest pull (Val, 2026-11-05):
            # start and restart pull and recompile first unless the last build is
            # already of the fetched revision.
            steps = {'start': [self.do_refresh, self.do_start], 'stop': [self.do_stop], 'update': [self.do_update],
                     'restart': [self.do_stop, self.do_refresh, self.do_start], 'handover': [self.do_handover]}[action]
            for step in steps:
                step(operation)
            self.record(phase='done', error=None)
        except Exception as error:  # the state file is the only place a detached worker can report
            self.record(phase='failed', error=str(error)[:500])
        finally:
            self.lock.unlink(missing_ok=True)

    def do_start(self, operation):
        self.record(phase='checking save')
        self.recover_interrupted_save()
        generation = check_save(self.repo / 'map_saves')
        code, out = self.platform.run([self.config['git'], 'rev-parse', 'HEAD'], cwd=self.repo, timeout=60)
        revision = out.strip().splitlines()[-1] if code == 0 and out.strip() else ''
        if not HEX40.match(revision):
            raise RuntimeError('could not read the git revision')
        (self.repo / 'config' / 'lifecycle-revision.txt').write_text(revision + '\n', encoding='utf-8')
        if self.platform.listening(self.config['port']):
            raise RuntimeError('something is already listening on the port')
        self.record(phase='starting', generation=generation, revision=revision)
        code, out = self.start_task()
        if code != 0:
            raise RuntimeError('the scheduled task did not start: ' + out.strip()[-300:])
        deadline = self.platform.now() + self.config['start_timeout_seconds']
        while not self.platform.listening(self.config['port']):
            if self.platform.now() > deadline:
                raise RuntimeError('the server did not open its port in time')
            self.platform.sleep(2)
        self.mark_running()
        watchdog = self.read_json(self.watchdog_file)
        if watchdog and watchdog.pop('gave_up', None):  # running again: watch it again
            self.write_json(self.watchdog_file, watchdog)
        self.record(phase='started')

    def start_task(self):
        return self.platform.start_task(self.config['task'])

    def do_handover(self, operation):
        raise RuntimeError('a handover needs a region host (scripts/shard-group)')

    def do_stop(self, operation):
        token = self.token()
        before = self.world()
        if not token or not before:
            raise RuntimeError('the world does not answer lifecycle status')
        session = before.get('session', '')
        if not HEX32.match(session or ''):
            raise RuntimeError('the world gave no valid session')
        port = self.config['port']
        pid = self.platform.server_pid(port)
        if before.get('persistence_mode') is False:
            # A world whose round does not save (the TDM Barracks and battle world) has
            # nothing to save and refuses save_shutdown: end it, as stopping it means.
            if not pid:
                raise RuntimeError('the world answers but its process was not found')
            self.running_file.unlink(missing_ok=True)  # it is going down on purpose
            self.platform.kill_tree(pid)
            self.release_save_locks(pid)
            self.record(phase='stopped', saved=False)
            return
        self.record(phase='saving', clients=before.get('clients'))
        answer = self.platform.query(port, token, 'save_shutdown', operation, session)
        if answer.get('operation') != operation:
            raise RuntimeError('the world did not accept the save')
        self.running_file.unlink(missing_ok=True)  # it is going down on purpose
        exited = self.wait_for_exit(pid)
        self.record(phase='backing up')
        saves = self.repo / 'map_saves'
        if exited:
            # The process is gone, so any lock file left in map_saves was its own.
            self.remove_save_locks(self.save_locks())
        for _ in range(30):
            if not any(p.name.endswith('.lk') for p in saves.iterdir()):
                break
            self.platform.sleep(2)
        generation = check_save(saves)
        backups = self.state_dir / 'backups'
        copy_save(saves, backups / operation)
        kept = sorted((p for p in backups.iterdir() if p.is_dir()), key=lambda p: p.stat().st_mtime)
        for old in kept[:-self.config['backups_kept']]:
            shutil.rmtree(old)
        self.record(phase='stopped', generation=generation, backup=str(backups / operation))

    def wait_for_exit(self, pid):
        """Wait until the world that accepted save_shutdown has saved and exited.

        A world busy saving can stop accepting connections for minutes (every poll's
        connection waits in its listen backlog until it fills), so a refused connection
        is not an exit: Gaia's Save and stop gave up after its port "closed" in the middle
        of the save, while the world was still saving (2026-11-07). The world is gone when
        no process listens on its port and its process has ended. A world that closed its
        port (it does that only when it shuts down after a validated save) but whose
        process lingers past STOP_LINGER_SECONDS is ended. pid: the process that listened
        before the save, or None when it could not be found (then the port alone decides,
        closed on several polls in a row). True when the process is known to have ended."""
        port = self.config['port']
        deadline = self.platform.now() + self.config['save_timeout_seconds']
        closed_since = None
        misses = 0
        while True:
            if pid:
                held = self.platform.server_pid(port) is not None
                if not held and not self.platform.alive(pid):
                    return True
            else:
                held = self.platform.listening(port)
                misses = 0 if held else misses + 1
                if misses >= STOP_CLOSED_POLLS:
                    return False
            now = self.platform.now()
            if pid and not held:
                closed_since = now if closed_since is None else closed_since
                self.record(phase='waiting for the server to exit')
                if now - closed_since >= STOP_LINGER_SECONDS:
                    self.platform.kill_tree(pid)
                    self.log({'stop': 'the world closed its port after saving but did not exit; ended it', 'pid': pid})
                    self.release_save_locks(pid)
                    return not self.platform.alive(pid)
            elif now > deadline:
                raise RuntimeError('the save did not finish in time; the server was left running')
            elif held:
                status = self.world()
                if status and status.get('error'):
                    raise RuntimeError('the world reported a save error: %s' % status['error'])
            self.platform.sleep(5)

    def do_update(self, operation):
        git, repo = self.config['git'], self.repo
        self.record(phase='pulling')
        for argv in ([git, 'fetch', 'origin', self.config['branch']],
                     [git, 'merge', '--ff-only', 'origin/' + self.config['branch']]):
            code, out = self.platform.run(argv, cwd=repo, timeout=600)
            if code != 0:
                raise RuntimeError('%s failed: %s' % (argv[1], out.strip()[-300:]))
        if self.platform.listening(self.config['port']):
            raise RuntimeError('the server started during the update; not compiling')
        self.record(phase='compiling')
        code, out = self.platform.run([self.config['compiler'], 'civ13.dme'], cwd=repo, timeout=1800)
        if code != 0 or '0 errors' not in out:
            raise RuntimeError('compile failed: ' + out.strip()[-300:])
        code, out = self.platform.run([git, 'rev-parse', 'HEAD'], cwd=repo, timeout=60)
        revision = out.strip()[-40:]
        self.record_build(revision)
        self.record(phase='compiled', revision=revision)

    # -- build record ----------------------------------------------------------
    # build.json names the revision the current .dmb was compiled from, so start
    # can tell whether the build is of the latest pull. A .dmb changed since
    # (a hand compile) no longer matches and is rebuilt.
    def dmb(self):
        return self.repo / 'civ13.dmb'

    def build_file(self):
        return self.state_dir / 'build.json'

    def dmb_stamp(self):
        try:
            stat = self.dmb().stat()
        except OSError:
            return None
        return [stat.st_size, stat.st_mtime_ns]

    def record_build(self, revision, file=None):
        """file: the .dmb the record is about when a host keeps more than one (region hosts)."""
        if file:
            record = self.read_json(self.build_file()) or {}
            record['file'] = file
            self.write_json(self.build_file(), record)  # dmb() reads the slot before it is stamped
        stamp = self.dmb_stamp()
        if HEX40.match(revision or '') and stamp:
            record = {'revision': revision, 'dmb': stamp}
            if file:
                record['file'] = file
            self.write_json(self.build_file(), record)
        else:
            self.build_file().unlink(missing_ok=True)

    def built_revision(self):
        """The revision the current .dmb was compiled from, or None when unknown."""
        try:
            record = json.loads(self.build_file().read_text(encoding='utf-8'))
        except (OSError, ValueError):
            return None
        if not isinstance(record, dict) or record.get('dmb') != self.dmb_stamp():
            return None
        return record.get('revision') if HEX40.match(str(record.get('revision'))) else None

    def latest_revision(self):
        """Fetch, then the revision the server should run."""
        branch = self.config['branch']
        self.git_text(['fetch', 'origin', branch], self.repo)
        return self.git_text(['rev-parse', 'origin/' + branch], self.repo)

    def do_refresh(self, operation):
        """Pull and recompile unless the current build is already of the latest revision."""
        self.record(phase='checking for updates')
        latest = self.latest_revision()
        if not HEX40.match(latest):
            raise RuntimeError('could not read the latest revision')
        if self.built_revision() == latest:
            self.record(phase='build is current', revision=latest)
            return
        self.do_update(operation)
        if self.built_revision() != latest:
            raise RuntimeError('the build is still not of %s; not starting' % latest[:12])


def shard_group_module():
    sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'shard-group'))
    import shard_group
    return shard_group


def region_host(config):
    """A region's own host.json (written by shard_group.py setup) is driven as that
    region: DreamDaemon starts directly, its agent first, with no scheduled task. So
    the bot and the launcher can point their gaia_host config at a region."""
    return shard_group_module().RegionHost(config)


def group_hosts(paths):
    """The region hosts of every group config, and one supervisor per group that keeps
    its transfer agents and coordinator running (they never sleep with their world)."""
    shard_group = shard_group_module()
    hosts, supervisors = [], []
    for path in paths:
        group = shard_group.load_group(path)
        hosts += [host for _, host in shard_group.hosts(group)]
        supervisors.append(lambda group=group: shard_group.supervise(group))
    return hosts, supervisors


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--config', action='append', default=[],
                        help='config file; serve accepts one per instance on this host')
    parser.add_argument('action', nargs='?', choices=ACTIONS)
    parser.add_argument('--group', action='append', default=[],
                        help='serve only: a region group config (scripts/shard-group); every region is served too')
    parser.add_argument('--worker', nargs=2, metavar=('ACTION', 'OPERATION'), help=argparse.SUPPRESS)
    args = parser.parse_args(argv)
    if not args.config and not (args.group and args.action == 'serve'):
        parser.error('--config is required (serve may take only --group)')
    if len(args.config) > 1 and args.action != 'serve':
        parser.error('only serve takes more than one --config')
    if args.group and args.action != 'serve':
        parser.error('only serve takes --group')
    try:
        configs = [load_config(path) for path in args.config]
    except (OSError, ValueError) as error:
        print(json.dumps({'ok': False, 'error': 'config: %s' % error}))
        return 2
    for config, path in zip(configs, args.config):
        config['_path'] = str(Path(path).resolve())
    hosts = [region_host(config) if config.get('group_config') else Host(config) for config in configs]
    supervisors = []
    if args.group:
        try:
            region_hosts, supervisors = group_hosts(args.group)
        except (OSError, ValueError) as error:
            print(json.dumps({'ok': False, 'error': 'group config: %s' % error}))
            return 2
        hosts += region_hosts
    host = hosts[0]
    if args.worker:
        host.work(*args.worker)
        return 0
    if not args.action:
        parser.error('an action is required')
    if args.action == 'watch':
        host.watch()
        return 0
    if args.action == 'serve':
        from doorman import Doorman
        try:
            Doorman(hosts, host.platform, supervisors=supervisors).run()
        except (OSError, ValueError) as error:
            print(json.dumps({'ok': False, 'error': 'doorman: %s' % error}))
            return 2
        return 0
    try:
        if args.action == 'status':
            result = host.status()
            if host.config.get('group_config'):  # a region: the bot also shows its peers
                try:
                    shard_group = shard_group_module()
                    result['regions'] = shard_group.region_summary(shard_group.load_group(host.config['group_config']))
                except (OSError, ValueError) as error:
                    result['regions_error'] = str(error)[:200]
        elif args.action == 'freeze':
            result = host.freeze()
        elif args.action == 'thaw':
            result = host.thaw()
        elif args.action == 'kill':
            result = host.kill()
        elif args.action == 'force-restart':
            result = host.force_restart()
        elif args.action in ('unlock', 'force-unlock'):
            result = host.unlock(force=args.action == 'force-unlock')
        elif args.action == 'stage':
            result = host.request_stage()
        elif args.action == 'check-update':
            try:
                result = host.check_update()
            except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
                print(json.dumps({'ok': False, 'component': 'server', 'error': str(error)[:300]}))
                return 1
        else:
            result = host.request(args.action)
    except Refused as refusal:
        print(json.dumps({'ok': False, 'refused': str(refusal)}))
        return 1
    print(json.dumps(dict(result, ok=True)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
