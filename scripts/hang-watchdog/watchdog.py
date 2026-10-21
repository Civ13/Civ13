"""Independent Linux Nomads observer. No game requests, subprocesses or recovery.

Only this observer's dedicated output directory is writable. Game heartbeat
contents, command lines, credentials and raw log lines never enter its output.
"""
from __future__ import annotations

import argparse
from collections import Counter
from dataclasses import dataclass
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import stat
import sys
import time


READ_LIMIT = 65536
STATUS_LIMIT = 8192
ENTRY_LIMIT = 256
THREAD_LIMIT = 32
BUNDLE_RE = re.compile(r'incident-[0-9]{20}\.json\Z')
RUNTIME_RE = re.compile(r'20[0-9]{2}-[0-9]{2}-[0-9]{2}-\([0-9]{2}-[0-9]{2}-[0-9]{2}\)-runtime\.txt\Z')
LOG_CLASSES = {
    'network_open': re.compile(r'^World opened on network port [0-9]+'),
    'clean_shutdown_attempt': re.compile(r'^Caught SIGTERM, attempting clean shutdown\.'),
    'engine_sequence_warning': re.compile(r'^BUG: Sequence number [0-9A-Fa-f]+ expected but'),
    'engine_bad_reference': re.compile(r'^BUG: Bad ref '),
    'null_damage_runtime': re.compile(r'^runtime error: Cannot read null\.(burn_dam|brute_dam)$'),
    'save_failed': re.compile(r'^World-save export failed:'),
    'import_failed': re.compile(r'^World-save import failed:'),
    'recovery_hold': re.compile(r'^World restart transaction: RECOVERY HOLD:'),
}


def utc(value):
    return datetime.fromtimestamp(value, timezone.utc).isoformat()


def error_code(error):
    if isinstance(error, PermissionError):
        return 'permission_denied'
    if isinstance(error, FileNotFoundError):
        return 'missing'
    return 'unavailable'


def bounded_read(path, limit=READ_LIMIT, *, tail=False):
    """Refuse symlinks/special files and bound reads, including concurrent growth."""
    path = Path(path)
    if path.is_symlink():
        raise ValueError('symlink refused')
    fd = os.open(path, os.O_RDONLY | getattr(os, 'O_NOFOLLOW', 0) | getattr(os, 'O_NONBLOCK', 0))
    with os.fdopen(fd, 'rb') as stream:
        if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):
            raise ValueError('regular file required')
        if tail:
            stream.seek(max(0, os.fstat(stream.fileno()).st_size - limit))
        raw = stream.read(limit + 1)
        if len(raw) > limit:
            raise ValueError('read bound')
        return raw


def beneath(root, relative):
    """Fixed observer paths must not traverse a game-controlled symlink."""
    relative = Path(relative)
    if relative.is_absolute() or '..' in relative.parts:
        raise ValueError('relative path required')
    path = root
    for part in relative.parts:
        path = path / part
        if path.is_symlink():
            raise ValueError('symlink refused')
    if not path.resolve().is_relative_to(root):
        raise ValueError('path escapes root')
    return path


@dataclass(frozen=True)
class Config:
    game_root: Path
    output_dir: Path
    daemon: str
    pid: int
    start_ticks: int
    port: int
    poll_seconds: float = 5
    stale_seconds: float = 120
    startup_grace_seconds: float = 120
    cooldown_seconds: float = 900
    max_bundles: int = 8
    max_bundle_bytes: int = 65536
    max_total_bytes: int = 1048576
    expected_revision: str | None = None
    expected_byond: str = '516.1681'

    def __post_init__(self):
        for name in ('game_root', 'output_dir'):
            value = Path(getattr(self, name))
            if not value.is_absolute() or any(p.is_symlink() for p in [value, *value.parents]):
                raise ValueError('absolute nonsymlink paths required')
            object.__setattr__(self, name, value.resolve())
        if self.game_root.is_relative_to(self.output_dir) or self.output_dir.is_relative_to(self.game_root):
            raise ValueError('game and output directories must not overlap')
        # A copied installation has no repository layout (and may be shallow).
        # Require Civ13's entry point too: an unrelated ancestor (e.g. a
        # version-controlled home directory) is not this script's source checkout.
        # A normal .git directory and a worktree .git file are both supported.
        checkout = next((parent for parent in Path(__file__).resolve().parents
                         if (parent / '.git').exists() and (parent / 'civ13.dme').is_file()), None)
        if checkout is not None and self.output_dir.is_relative_to(checkout):
            raise ValueError('output must be outside source checkout')
        if not Path(self.daemon).is_absolute():
            raise ValueError('absolute daemon identity required')
        for name, low, high in (('pid', 1, 2**31 - 1), ('start_ticks', 1, 2**63 - 1),
                                ('port', 1, 65535), ('max_bundles', 1, 64),
                                ('max_bundle_bytes', 4096, 262144),
                                ('max_total_bytes', 32768, 16777216)):
            value = getattr(self, name)
            if type(value) is not int or not low <= value <= high:
                raise ValueError('invalid integer bound')
        for name, low, high in (('poll_seconds', 1, 60), ('stale_seconds', 30, 3600),
                                ('startup_grace_seconds', 30, 3600), ('cooldown_seconds', 30, 86400)):
            value = getattr(self, name)
            if type(value) not in (int, float) or not math.isfinite(value) or not low <= value <= high:
                raise ValueError('invalid time bound')
        if self.max_total_bytes < self.max_bundle_bytes + 3 * STATUS_LIMIT:
            raise ValueError('quota must reserve status/state and atomic-write headroom')
        if self.expected_revision is not None and not re.fullmatch(r'[0-9a-f]{40}', self.expected_revision):
            raise ValueError('invalid expected revision')
        if not re.fullmatch(r'[0-9]{3}\.[0-9]{4}', self.expected_byond):
            raise ValueError('invalid expected build')

    @property
    def target(self):
        value = [str(self.game_root), self.daemon, self.pid, self.start_ticks, self.port]
        return hashlib.sha256(json.dumps(value).encode()).hexdigest()


def proc_stat(raw):
    # comm may contain spaces and parentheses. Fields after the last ')' start at 3.
    fields = raw.decode('ascii').rsplit(')', 1)[1].split()
    return dict(state=fields[0] if fields[0] in 'RSDZTWtXIP' else '?',
                cpu_ticks=int(fields[11]) + int(fields[12]), start_ticks=int(fields[19]))


class Observer:
    def __init__(self, config, proc_root=Path('/proc')):
        self.config, self.proc = config, Path(proc_root)

    def identity(self):
        c = self.config
        try:
            data = proc_stat(bounded_read(self.proc / str(c.pid) / 'stat', 2048))
            argv = bounded_read(self.proc / str(c.pid) / 'cmdline', 2048).split(b'\0')
            expected = [os.fsencode(c.daemon), os.fsencode(c.game_root), b'civ13.dmb', str(c.port).encode()]
            if data['start_ticks'] != c.start_ticks or argv[:4] != expected:
                return dict(status='identity_mismatch')
            return dict(status='verified', pid=c.pid, **data)
        except (OSError, ValueError, IndexError, UnicodeError) as error:
            return dict(status=error_code(error))

    def heartbeat(self):
        try:
            path = beneath(self.config.game_root, 'serverdata.txt')
            info = path.stat()
            if not stat.S_ISREG(info.st_mode):
                raise ValueError('regular heartbeat required')
            return dict(status='present', signature=[info.st_dev, info.st_ino, info.st_mtime_ns, info.st_size],
                        mtime_utc=utc(info.st_mtime), bytes=info.st_size)
        except (OSError, ValueError, OverflowError) as error:
            return dict(status=error_code(error))

    def listener(self, verified):
        """Local kernel tables only: no connection attempts and no peer IP output."""
        sockets, errors = [], []
        for family in ('tcp', 'tcp6'):
            try:
                rows = bounded_read(self.proc / 'net' / family).decode('ascii').splitlines()[1:]
                for row in rows:
                    fields = row.split()
                    if int(fields[1].rsplit(':', 1)[1], 16) != self.config.port or fields[3] != '0A':
                        continue
                    sockets.append((fields[9], int(fields[4].split(':')[1], 16)))
                    if len(sockets) >= 16:
                        raise ValueError('listener bound')
            except (OSError, ValueError, IndexError, UnicodeError) as error:
                errors.append(error_code(error))
        owner = None
        if verified and sockets:
            try:
                inodes = {inode for inode, _ in sockets}
                entries = list_bounded(self.proc / str(self.config.pid) / 'fd')
                owner = any(os.readlink(entry).removeprefix('socket:[').removesuffix(']') in inodes
                            for entry in entries)
            except (OSError, ValueError):
                owner = None
        return dict(status='partial' if errors else 'observed', listening=bool(sockets) if sockets or not errors else None,
                    verified_process_owns_listener=owner,
                    queued_unaccepted=sum(queue for _, queue in sockets),
                    maximum_backlog=None, errors=sorted(set(errors)),
                    scope='local kernel listener; no TCP/game/protocol/remote-connectivity test')

    def sample(self):
        identity = self.identity()
        return dict(process=identity, heartbeat=self.heartbeat(),
                    listener=self.listener(identity['status'] == 'verified'))

    def diagnostics(self, observation):
        c = self.config
        result = dict(threads=[], logs=[], artifacts={}, resources={})
        if observation['process']['status'] == 'verified':
            try:
                fields = {}
                for line in bounded_read(self.proc / str(c.pid) / 'status', 8192).decode('ascii').splitlines():
                    parts = line.split()
                    if parts[0] in ('VmRSS:', 'VmPeak:', 'VmSwap:', 'Threads:',
                                    'voluntary_ctxt_switches:', 'nonvoluntary_ctxt_switches:'):
                        fields[parts[0].rstrip(':')] = int(parts[1])
                result['process_counters'] = fields
            except (OSError, ValueError, IndexError, UnicodeError) as error:
                result['process_counters'] = dict(error=error_code(error))
            try:
                for thread in sorted(list_bounded(self.proc / str(c.pid) / 'task'), key=lambda p: p.name)[:THREAD_LIMIT]:
                    if not thread.name.isdigit():
                        continue
                    try:
                        row = proc_stat(bounded_read(thread / 'stat', 2048))
                        wait = bounded_read(thread / 'wchan', 128).decode('ascii').strip()
                        row['wchan'] = wait if re.fullmatch(r'[A-Za-z0-9_+.]{1,100}', wait) else 'withheld'
                        row['tid'] = int(thread.name)
                        result['threads'].append(row)
                    except (OSError, ValueError, IndexError, UnicodeError) as error:
                        result['threads'].append(dict(tid=int(thread.name), error=error_code(error)))
                result['thread_limit'] = THREAD_LIMIT
            except (OSError, ValueError) as error:
                result['thread_error'] = error_code(error)
        for name in ('civ13.dmb', 'civ13.rsc'):
            try:
                path = beneath(c.game_root, name)
                # No execution or hashing of unbounded binaries. The digest is of
                # the on-disk file, not proof of the currently loaded image.
                info = path.stat()
                if info.st_size > 128 * 1024 * 1024:
                    raise ValueError('artifact size')
                digest = hashlib.sha256()
                fd = os.open(path, os.O_RDONLY | getattr(os, 'O_NOFOLLOW', 0) | getattr(os, 'O_NONBLOCK', 0))
                with os.fdopen(fd, 'rb') as stream:
                    before = os.fstat(stream.fileno())
                    if not stat.S_ISREG(before.st_mode):
                        raise ValueError('artifact type')
                    remaining = 128 * 1024 * 1024
                    while remaining:
                        chunk = stream.read(min(1048576, remaining))
                        if not chunk:
                            break
                        digest.update(chunk)
                        remaining -= len(chunk)
                    after = os.fstat(stream.fileno())
                    if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns) or after.st_size > 128 * 1024 * 1024:
                        raise ValueError('artifact changed')
                result['artifacts'][name] = dict(sha256=digest.hexdigest(), bytes=after.st_size,
                                               identity='on-disk only; loaded-image identity unverified')
            except (OSError, ValueError) as error:
                result['artifacts'][name] = dict(error=error_code(error))
        try:
            revision = bounded_read(beneath(c.game_root, 'config/lifecycle-revision.txt'), 128).decode('ascii').strip()
            result['claimed_revision'] = revision if re.fullmatch(r'[0-9a-f]{40}', revision) else None
        except (OSError, ValueError, UnicodeError):
            result['claimed_revision'] = None
        result['operator_expected_revision'] = c.expected_revision
        result['operator_expected_byond'] = c.expected_byond
        result['revision_binding_verified'] = False
        try:
            result['watchdog_source_sha256'] = hashlib.sha256(bounded_read(__file__, 131072)).hexdigest()
        except (OSError, ValueError) as error:
            result['watchdog_source_error'] = error_code(error)
        # Metadata only. Never open, copy, repair, import or invalidate saves.
        result['save_artifacts'] = {}
        for folder in ('map_saves', 'map_backups'):
            records = {}
            for name in ('save_complete.txt', 'restart_intent.json', 'round.json', 'map.txt',
                         *(f'{i}.sav' for i in range(1, 33))):
                try:
                    info = beneath(c.game_root, folder + '/' + name).stat()
                    if not stat.S_ISREG(info.st_mode):
                        raise ValueError('save type')
                    records[name] = dict(bytes=info.st_size, mtime_utc=utc(info.st_mtime))
                except FileNotFoundError:
                    continue
                except (OSError, ValueError, OverflowError) as error:
                    records[name] = dict(error=error_code(error))
            result['save_artifacts'][folder] = records
        try:
            values = {}
            for line in bounded_read(self.proc / 'meminfo', 16384).decode('ascii').splitlines():
                parts = line.split()
                if parts[0] in ('MemTotal:', 'MemAvailable:', 'SwapTotal:', 'SwapFree:'):
                    values[parts[0].rstrip(':') + '_kib'] = int(parts[1])
            result['resources']['memory'] = values
        except (OSError, ValueError, IndexError, UnicodeError) as error:
            result['resources']['memory'] = dict(error=error_code(error))
        try:
            usage = shutil.disk_usage(c.game_root)
            result['resources']['game_filesystem'] = dict(total_bytes=usage.total, free_bytes=usage.free)
        except OSError as error:
            result['resources']['game_filesystem'] = dict(error=error_code(error))
        paths = [('engine', 'civ13.log')]
        try:
            folder = beneath(c.game_root, 'data/logs/runtime')
            candidates = [p for p in list_bounded(folder) if RUNTIME_RE.fullmatch(p.name) and not p.is_symlink()]
            candidates.sort(key=lambda p: p.stat().st_mtime_ns, reverse=True)
            paths += [('runtime', str(p.relative_to(c.game_root))) for p in candidates[:2]]
        except (OSError, ValueError) as error:
            result['logs'].append(dict(kind='runtime_inventory', error=error_code(error)))
        for kind, relative in paths:
            try:
                path = beneath(c.game_root, relative)
                info = path.stat()
                text = bounded_read(path, 16384, tail=True).decode('utf-8', 'replace')
                counts = Counter()
                for line in text.splitlines():
                    for label, pattern in LOG_CLASSES.items():
                        if pattern.search(line):
                            counts[label] += 1
                result['logs'].append(dict(kind=kind, mtime_utc=utc(info.st_mtime), bytes=info.st_size,
                                           tail_bytes=16384, classifications=dict(counts),
                                           raw_lines_withheld=True))
            except (OSError, ValueError, OverflowError) as error:
                result['logs'].append(dict(kind=kind, error=error_code(error)))
        # Recheck after collection: never present a recycled process as this game.
        result['process_identity_still_verified'] = self.identity()['status'] == 'verified'
        return result


def list_bounded(folder):
    result = []
    with os.scandir(folder) as entries:
        for entry in entries:
            if len(result) >= ENTRY_LIMIT:
                raise ValueError('directory entry bound')
            result.append(Path(entry.path))
    return result


class Heartbeat:
    def __init__(self, config):
        self.config = config
        self.started = self.progress = self.previous_now = None
        self.signature = None
        self.confirmed = False

    def evaluate(self, observation, now):
        if not math.isfinite(now) or now < 0:
            raise ValueError('invalid monotonic clock')
        if self.previous_now is None or now < self.previous_now:
            self.started = self.progress = now
            self.signature, self.confirmed = None, False
        self.previous_now = now
        process = observation['process']['status']
        if process != 'verified':
            return dict(state='process_' + process, progress_age_seconds=None)
        heartbeat = observation['heartbeat']
        if heartbeat['status'] == 'present':
            signature = heartbeat['signature']
            if self.signature is None:
                self.signature = signature
                self.progress = now
            elif self.signature != signature:
                self.signature, self.progress, self.confirmed = signature, now, True
        age = max(0, now - self.progress)
        if now - self.started < self.config.startup_grace_seconds and not self.confirmed:
            state = 'starting'
        elif heartbeat['status'] != 'present':
            state = 'heartbeat_' + heartbeat['status']
        elif age >= self.config.stale_seconds:
            state = 'heartbeat_stale'
        else:
            state = 'healthy' if self.confirmed else 'starting'
        return dict(state=state, progress_age_seconds=round(age, 3))


class Store:
    """Private bounded directory. Only exact observer-owned history is pruned."""
    def __init__(self, config):
        self.config, self.root = config, config.output_dir
        # Reject symlink parents, including a redirected dedicated directory.
        if any(p.is_symlink() for p in [self.root, *self.root.parents]):
            raise ValueError('output symlink refused')
        existed = self.root.exists()
        self.root.mkdir(mode=0o700, parents=True, exist_ok=True)
        if os.name != 'nt' and self.root.stat().st_mode & 0o077:
            raise ValueError('private output directory required')
        marker = self.root / '.nomads-watchdog'
        if existed and not marker.exists() and list_bounded(self.root):
            raise ValueError('dedicated empty output directory required')
        if not marker.exists():
            fd = os.open(marker, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(fd, 'wb') as stream:
                stream.write(b'nomads-watchdog-schema-1\n')
        if bounded_read(marker, 128) != b'nomads-watchdog-schema-1\n':
            raise ValueError('output marker mismatch')
        self.lock_fd = None

    def __enter__(self):
        import fcntl  # Linux CLI only; portable fixtures bypass acquisition on Windows.
        if self.lock_fd is not None:
            raise FileExistsError('observer already holds the lock')
        path = self.root / 'watchdog.lock'
        fd = os.open(path, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW | os.O_NONBLOCK, 0o600)
        try:
            own = os.fstat(fd)
            if not stat.S_ISREG(own.st_mode) or own.st_nlink != 1 or own.st_mode & 0o077:
                raise ValueError('private regular singleton lock required')
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                raise FileExistsError('another observer holds the lock') from None
            current = path.lstat()
            if (current.st_dev, current.st_ino) != (own.st_dev, own.st_ino):
                raise ValueError('singleton lock identity changed')
        except BaseException:
            os.close(fd)
            raise
        self.lock_fd = fd
        return self

    def __exit__(self, *_):
        if self.lock_fd is not None:
            os.close(self.lock_fd)
            self.lock_fd = None
        # Never unlink: another entrant must lock this same persistent inode.
        # Kernel ownership ends on descriptor close, SIGKILL, OOM or process exit.

    def inventory(self):
        entries = list_bounded(self.root)
        total, history = 0, []
        for path in entries:
            info = path.lstat()
            if stat.S_ISLNK(info.st_mode) or not stat.S_ISREG(info.st_mode):
                raise ValueError('output contains symlink or nonregular entry')
            total += info.st_size
            if BUNDLE_RE.fullmatch(path.name):
                history.append(path)
        return total, sorted(history)

    def load_state(self):
        try:
            value = json.loads(bounded_read(self.root / 'watchdog-state.json', STATUS_LIMIT))
        except FileNotFoundError:
            return dict(schema=1, target=self.config.target, active=False, captured=False,
                        last_emit=None, boot=None, sequence=0)
        if (set(value) != {'schema', 'target', 'active', 'captured', 'last_emit', 'boot', 'sequence'}
                or value['schema'] != 1 or value['target'] != self.config.target
                or type(value['active']) is not bool or type(value['captured']) is not bool
                or type(value['sequence']) is not int or not 0 <= value['sequence'] < 10**20
                or (value['last_emit'] is not None and (type(value['last_emit']) not in (int, float)
                    or not math.isfinite(value['last_emit']) or value['last_emit'] < 0))
                or (value['boot'] is not None and not re.fullmatch(r'[0-9a-f-]{36}', value['boot']))):
            raise ValueError('state invalid or belongs to another target')
        return value

    def write(self, name, value, limit=STATUS_LIMIT):
        if name not in ('watchdog-state.json', 'watchdog-status.json') and not BUNDLE_RE.fullmatch(name):
            raise ValueError('output name refused')
        raw = (json.dumps(value, sort_keys=True, allow_nan=False) + '\n').encode('utf-8')
        if len(raw) > limit:
            raise ValueError('output byte bound')
        path = self.root / name
        if path.exists() and BUNDLE_RE.fullmatch(name):
            raise ValueError('refuse incident overwrite')
        if path.is_symlink():
            raise ValueError('output symlink refused')
        total, history = self.inventory()
        if total - sum(p.stat().st_size for p in history) + len(raw) > self.config.max_total_bytes:
            raise ValueError('output quota exhausted; existing evidence preserved')
        while history and (total + len(raw) > self.config.max_total_bytes or
                           (BUNDLE_RE.fullmatch(name) and len(history) >= self.config.max_bundles)):
            old = history.pop(0)
            total -= old.stat().st_size
            old.unlink()
        if total + len(raw) > self.config.max_total_bytes:
            raise ValueError('output quota exhausted; unknown files preserved')
        temporary = self.root / '.watchdog.tmp'
        fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        try:
            with os.fdopen(fd, 'wb') as stream:
                stream.write(raw)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(temporary, path)
        finally:
            if temporary.exists() and not temporary.is_symlink():
                temporary.unlink()


class Monitor:
    def __init__(self, config, observer, store):
        self.config, self.observer, self.store = config, observer, store
        self.tracker, self.state = Heartbeat(config), store.load_state()
        try:
            self.boot = bounded_read(observer.proc / 'sys/kernel/random/boot_id', 64).decode('ascii').strip()
            if not re.fullmatch(r'[0-9a-f-]{36}', self.boot):
                raise ValueError('boot identity')
        except (OSError, ValueError, UnicodeError):
            # No durable monotonic continuity: retain dedup but start a cooldown.
            self.boot = None
        self.first = True
        self.previous_state = None

    def step(self, monotonic_now, wall_now):
        observation = self.observer.sample()
        health = self.tracker.evaluate(observation, monotonic_now)
        heartbeat_state = health['state']
        if heartbeat_state == 'healthy' and observation['listener']['listening'] is not True:
            health['state'] = 'listener_missing' if observation['listener']['listening'] is False else 'listener_unknown'
        s = self.state
        if self.first:
            if self.boot is None or self.boot != s['boot']:
                s['last_emit'] = monotonic_now if s['last_emit'] is not None else None
            s['boot'] = self.boot
            self.first = False
        if s['last_emit'] is not None and s['last_emit'] > monotonic_now:
            s['last_emit'] = monotonic_now
        status = dict(schema=1, utc=utc(wall_now), monotonic_seconds=monotonic_now,
                      target=self.config.target, heartbeat_state=heartbeat_state, **health, **observation,
                      automatic_recovery=False, automatic_attachment=False)
        state = health['state']
        if state == 'healthy':
            s['active'], s['captured'] = False, False
        elif state != 'starting':
            s['active'] = True
        emitted = None
        if (s['active'] and state != 'starting' and not s['captured'] and
                (s['last_emit'] is None or monotonic_now - s['last_emit'] >= self.config.cooldown_seconds)):
            # Reserve the dedup before collection: a crash cannot cause an
            # unbounded collection loop after observer restarts. Failure is visible
            # in status/stderr and requires operator reconciliation, never retries.
            s['captured'], s['last_emit'] = True, monotonic_now
            _, history = self.store.inventory()
            maximum = max([int(p.name[9:29]) for p in history] + [s['sequence']])
            s['sequence'] = maximum + 1
            self.store.write('watchdog-state.json', s)
            emitted = f'incident-{s["sequence"]:020d}.json'
            bundle = dict(schema=1, observation=status, diagnostics=self.observer.diagnostics(observation),
                          limits=dict(raw_logs=False, environment=False, memory_dump=False,
                                      ptrace=False, game_requests=False, threads=THREAD_LIMIT),
                          warning='A listener is not game readiness. Preserve saves and unsaved-state risk; no recovery performed.')
            self.store.write(emitted, bundle, self.config.max_bundle_bytes)
        self.store.write('watchdog-state.json', s)
        status['incident_captured_for_episode'] = s['captured']
        status['bundle'] = emitted
        self.store.write('watchdog-status.json', status)
        changed = state != self.previous_state
        self.previous_state = state
        return dict(state=state, bundle=emitted, changed=changed)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', required=True)
    parser.add_argument('--once', action='store_true', help='One sample; cannot establish heartbeat progress/staleness alone')
    args = parser.parse_args(argv)
    if sys.platform != 'linux':
        parser.error('The observer runs on Linux; offline tests are portable')
    if os.geteuid() == 0:
        parser.error('Run the observer unprivileged, never through sudo')
    try:
        config = Config(**json.loads(bounded_read(args.config, 16384)))
        observer = Observer(config)
        with Store(config) as store:
            monitor = Monitor(config, observer, store)
            while True:
                result = monitor.step(time.monotonic(), time.time())
                if result['changed'] or result['bundle']:
                    print(json.dumps(result), flush=True)
                if args.once:
                    return 0
                time.sleep(config.poll_seconds)
    except KeyboardInterrupt:
        return 0
    except (OSError, ValueError, TypeError, KeyError, OverflowError):
        # Never print exception text, which can contain paths or private input.
        print('watchdog stopped: configuration, permissions, state or output bound failure; inspect locally', file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
