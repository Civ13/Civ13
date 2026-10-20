"""Serialized native BYOND test-server updates using the production lifecycle API."""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import ctypes
import hashlib
import json
import os
from pathlib import Path
import shutil
import socket
import struct
import subprocess
import time
import urllib.parse
import uuid


def write_json(path, value):
    path = Path(path)
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(value, indent=2), encoding='utf-8')
    temporary.replace(path)


def digest(path, algorithm='sha256'):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, algorithm).hexdigest()


def byond_text_md5(path):
    # file2text() normalizes native Windows CRLF. Only the transaction's text
    # identities use this contract; backup receipts retain SHA-256 of raw bytes.
    return hashlib.md5(Path(path).read_bytes().replace(b'\r\n', b'\n')).hexdigest()


def verify_binaries(folder, manifest, revision):
    if manifest.get('revision') != revision or manifest.get('map') != 'NOMADS_EUROPE':
        raise RuntimeError('Staged build identity changed')
    if set(manifest.get('binaries', {})) != {'civ13.dmb', 'civ13.rsc'}:
        raise RuntimeError('Staged build manifest is incomplete')
    for name, expected in manifest['binaries'].items():
        if digest(Path(folder) / name) != expected:
            raise RuntimeError('Staged build binary changed')


@contextmanager
def exclusive_lock(path):
    with Path(path).open('a+b') as stream:
        stream.seek(0)
        if os.name == 'nt':
            import msvcrt
            stream.write(b'0')
            stream.flush()
            stream.seek(0)
            msvcrt.locking(stream.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        yield


def process_identity(pid):
    """Creation FILETIME prevents a recycled Windows PID from becoming our host."""
    if os.name != 'nt':
        raise RuntimeError('Live supervisor currently supports Windows only')
    from ctypes import wintypes
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    kernel.OpenProcess.argtypes = (wintypes.DWORD, wintypes.BOOL, wintypes.DWORD)
    kernel.OpenProcess.restype = wintypes.HANDLE
    kernel.GetProcessTimes.argtypes = (wintypes.HANDLE,) + (ctypes.POINTER(wintypes.FILETIME),) * 4
    kernel.GetExitCodeProcess.argtypes = (wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD))
    kernel.CloseHandle.argtypes = (wintypes.HANDLE,)
    handle = kernel.OpenProcess(0x1000, False, pid)
    if not handle:
        if ctypes.get_last_error() == 87:
            return None
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        created, exited, system, user = (wintypes.FILETIME() for _ in range(4))
        code = wintypes.DWORD()
        if not kernel.GetProcessTimes(handle, ctypes.byref(created), ctypes.byref(exited), ctypes.byref(system), ctypes.byref(user)):
            raise ctypes.WinError(ctypes.get_last_error())
        if not kernel.GetExitCodeProcess(handle, ctypes.byref(code)):
            raise ctypes.WinError(ctypes.get_last_error())
        if code.value != 259:
            return None
        return (created.dwHighDateTime << 32) | created.dwLowDateTime
    finally:
        kernel.CloseHandle(handle)


def startup_session(status):
    session = status.get('session')
    if not isinstance(session, str) or len(session) != 32 or any(c not in '0123456789abcdef' for c in session):
        raise RuntimeError('Startup supplied no valid process session challenge')
    return session


def publish_ready(root, *, revision, expected_map, host, generation, session, status, identity=None):
    """Publish canonical readiness under the caller's supervisor.lock.

    The caller binds session from its initial lifecycle status for this owned
    process. A final status cannot replace that challenge or the owned context.
    This function never queries, starts or stops a process, or records a session.
    """
    root = Path(root).resolve(strict=True)
    state_path = root / 'state.json'
    state = json.loads(state_path.read_text(encoding='utf-8-sig'))
    if (not isinstance(revision, str) or len(revision) != 40 or
            any(c not in '0123456789abcdef' for c in revision) or
            not isinstance(expected_map, str) or not expected_map or
            state.get('revision') != revision or
            state.get('map', 'NOMADS_EUROPE') != expected_map or
            state.get('host') != host or state.get('generation') != generation):
        raise RuntimeError('Startup owned context changed')
    if (not isinstance(host, dict) or type(host.get('pid')) is not int or host['pid'] <= 0 or
            type(host.get('creation_filetime')) is not int or host['creation_filetime'] <= 0 or
            not isinstance(host.get('workdir'), str) or
            Path(host['workdir']).resolve(strict=True).parent != (root / 'runs').resolve(strict=True)):
        raise RuntimeError('Invalid startup host identity or run path')
    if (status.get('ok') != 1 or status.get('ready') != 1 or status.get('busy') != 0 or
            status.get('restart_hold') != 0 or status.get('restart_intent') != 0 or status.get('error')):
        raise RuntimeError('Running host is not ready')
    if status.get('revision') != revision or status.get('map') != expected_map:
        raise RuntimeError('Startup status revision/map differs from owned context')
    if generation is not None and (not generation or status.get('generation') != generation or
                                   status.get('restart_import_complete') != 1):
        raise RuntimeError('Startup did not restore the intended generation')
    if generation is None and (status.get('generation') != '' or status.get('restart_import_complete') != 0):
        raise RuntimeError('Fresh startup unexpectedly imported a generation')
    if startup_session({'session': session}) != startup_session(status):
        raise RuntimeError('Startup process session changed')
    if (identity or process_identity)(host['pid']) != host['creation_filetime']:
        raise RuntimeError('Startup host identity changed')
    # Cooperating writers hold supervisor.lock; detect stale caller state and
    # changes during the final process check before replacing the state file.
    if json.loads(state_path.read_text(encoding='utf-8-sig')) != state:
        raise RuntimeError('Startup owned state changed before publication')
    state['phase'] = 'ready'
    write_json(state_path, state)
    return state


def query(port, token, action='status', operation=None, session=None):
    values = {'nomads_lifecycle': '1', 'token': token, 'action': action}
    if operation:
        values['operation'] = operation
    if session:
        values['session'] = session
    payload = b'\0' * 5 + urllib.parse.urlencode(values).encode('ascii') + b'\0'
    with socket.create_connection(('127.0.0.1', port), timeout=15) as connection:
        connection.sendall(b'\x00\x83' + struct.pack('>H', len(payload)) + payload)

        def read_exact(count):
            result = bytearray()
            while len(result) < count:
                part = connection.recv(count - len(result))
                if not part:
                    raise RuntimeError('Incomplete lifecycle response')
                result.extend(part)
            return bytes(result)

        header = read_exact(4)
        if header[:2] != b'\x00\x83':
            raise RuntimeError('Invalid lifecycle response header')
        body = read_exact(struct.unpack('>H', header[2:])[0])
        if not body or body[0] != 6:
            raise RuntimeError('Lifecycle response is not JSON text')
        result = json.loads(body[1:].rstrip(b'\0').decode('utf-8'))
        if not isinstance(result, dict) or not result.get('ok'):
            raise RuntimeError('Lifecycle request rejected')
        return result


def validate_generation(folder, operation=None, session=None):
    folder = Path(folder)
    intent = json.loads((folder / 'restart_intent.json').read_text(encoding='utf-8-sig'))
    state = json.loads((folder / 'round.json').read_text(encoding='utf-8-sig'))
    marker = (folder / 'save_complete.txt').read_text(encoding='utf-8-sig').strip()
    if state.get('version') != 2 or not marker.startswith('round-v2:'):
        raise RuntimeError('A completed durable round-v2 generation is required')
    if intent.get('version') != 1 or intent.get('generation') != marker or state.get('generation') != marker:
        raise RuntimeError('Save/intent generation mismatch')
    if operation is not None and (intent.get('lifecycle_operation') != operation or intent.get('lifecycle_session') != session):
        raise RuntimeError('Saved intent does not belong to the acknowledged lifecycle operation')
    if intent.get('metadata') != byond_text_md5(folder / 'map.txt') or intent.get('round') != byond_text_md5(folder / 'round.json'):
        raise RuntimeError('Restart intent metadata mismatch')
    if state.get('map') != 'NOMADS_EUROPE':
        raise RuntimeError('Saved generation belongs to another map')
    if any(type(state.get(axis)) is not int or not 1 <= state[axis] <= 32767 for axis in ('maxx', 'maxy')):
        raise RuntimeError('Invalid saved horizontal dimensions')
    levels = state.get('maxz')
    if not isinstance(levels, int) or not 1 <= levels <= 128:
        raise RuntimeError('Invalid saved level count')
    names = ['map.txt', 'round.json', 'save_complete.txt', 'restart_intent.json']
    names += [f'{z}.sav' for z in range(1, levels + 1)]
    if any(not (folder / name).is_file() or (folder / name).stat().st_size == 0 for name in names):
        raise RuntimeError('Incomplete saved generation')
    if list(folder.glob('*.lk')):
        raise RuntimeError('Saved generation still has native locks')
    return state, names


def snapshot(folder, destination, operation=None, session=None):
    state, names = validate_generation(folder, operation, session)
    destination = Path(destination)
    destination.mkdir(parents=True, exist_ok=False)
    hashes = {}
    for name in names:
        source = Path(folder) / name
        target = destination / name
        shutil.copy2(source, target)
        hashes[name] = digest(source)
        if digest(target) != hashes[name]:
            raise RuntimeError('Backup copy hash mismatch')
    write_json(destination / 'receipt.json', {'generation': state['generation'], 'files': hashes})
    return state['generation']


class Supervisor:
    def __init__(self, config, *, clock=time.monotonic, sleep=time.sleep):
        self.config = config
        self.root = Path(config['root']).resolve()
        self.root.mkdir(parents=True, exist_ok=True)
        self.clock, self.sleep = clock, sleep
        self.state_path = self.root / 'state.json'
        self.state = json.loads(self.state_path.read_text()) if self.state_path.exists() else {}
        self.token = (Path(config['config_directory']) / 'lifecycle-token.txt').read_text().strip()
        if len(self.token) != 32 or any(c not in '0123456789abcdef' for c in self.token):
            raise ValueError('Expected a 32-character lowercase hex lifecycle token')
        if config['port'] != 1714:
            raise ValueError('This installation is restricted to authorized Nomads TEST1714')
        if not 60 <= config.get('poll_seconds', 300) <= 86400:
            raise ValueError('Poll interval must be 60..86400 seconds')

    def record(self, event, **details):
        with (self.root / 'events.jsonl').open('a', encoding='utf-8') as stream:
            stream.write(json.dumps({'time_utc': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()), 'event': event, **details}) + '\n')

    def command(self, arguments, cwd=None, log=None, timeout=1800):
        result = subprocess.run(arguments, cwd=cwd, capture_output=True, timeout=timeout)
        if log:
            Path(log).write_bytes(result.stdout + result.stderr)
        if result.returncode:
            raise RuntimeError(f'Command failed: {arguments[0]} (exit {result.returncode}); inspect retained log')
        return result.stdout.decode('utf-8', errors='replace').strip()

    def candidate(self):
        c = self.config
        self.command([c['git'], 'fetch', 'origin', c.get('branch', 'master')], c['repository'], self.root / 'fetch.log', timeout=180)
        revision = self.command([c['git'], 'rev-parse', 'FETCH_HEAD^{commit}'], c['repository'])
        if len(revision) != 40 or any(x not in '0123456789abcdef' for x in revision):
            raise RuntimeError('Invalid fetched commit')
        return revision

    def build(self, revision):
        c = self.config
        folder = self.root / 'builds' / revision
        if folder.exists():
            manifest = json.loads((folder / 'build.json').read_text())
            verify_binaries(folder / 'game', manifest, revision)
            return folder
        folder.mkdir(parents=True)
        game = folder / 'game'
        # The catalog generator reads HEAD and tracked paths. A bare archive
        # cannot run it. Shared objects keep this exact detached checkout cheap;
        # no command checks out or edits the operator's repository.
        self.command([c['git'], 'clone', '--shared', '--no-checkout', c['repository'], str(game)], log=folder / 'clone.log', timeout=300)
        self.command([c['git'], 'checkout', '--detach', revision], game, folder / 'checkout.log', timeout=300)
        self.command([c['python'], 'scripts/build-crafting-atlas.py', '--catalog-only', '--game-catalog', 'UI/crafting-atlas.json'], game, folder / 'atlas.log')
        dme = (game / 'civ13.dme').read_text(encoding='utf-8')
        import re
        includes = re.findall(r'(?m)^#include "[^"\r\n]*\.dmm"\s*$', dme)
        if len(includes) != 1:
            raise RuntimeError('Expected exactly one map include')
        dme = dme.replace(includes[0], '#include "maps\\nomads\\nomads_europe.dmm"')
        (game / 'civ13.dme').write_text(dme, encoding='utf-8')
        output = self.command([c['compiler'], '-max_errors', '0', 'civ13.dme'], game, folder / 'compile.log')
        if '0 errors, 0 warnings' not in output:
            raise RuntimeError('Compilation did not confirm zero errors and warnings')
        if not (game / 'code/modules/persistence/nomads_lifecycle.dm').exists():
            raise RuntimeError('Candidate lacks the reviewed production lifecycle API')
        write_json(folder / 'build.json', {'revision': revision, 'map': 'NOMADS_EUROPE', 'binaries': {name: digest(game / name) for name in ('civ13.dmb', 'civ13.rsc')}})
        return folder

    def alive(self):
        host = self.state.get('host')
        if not host:
            return False
        identity = process_identity(host['pid'])
        if identity is not None and identity != host['creation_filetime']:
            raise RuntimeError('Host PID was reused; refusing ownership')
        return identity is not None

    def status(self):
        value = query(self.config['port'], self.token)
        if value.get('revision') != self.state['revision'] or value.get('map') != 'NOMADS_EUROPE':
            raise RuntimeError('Running host revision/map differs from owned state')
        return value

    def accept_ready(self, status, generation):
        if not status.get('ready') or status.get('busy') or status.get('error') or status.get('restart_hold'):
            raise RuntimeError('Running host is not ready')
        if generation and (status.get('generation') != generation or status.get('restart_intent') or not status.get('restart_import_complete')):
            raise RuntimeError('Startup did not restore the intended generation')

    def publish_ready(self, status, generation, session):
        self.state = publish_ready(self.root, revision=self.state['revision'],
            expected_map=self.state.get('map', 'NOMADS_EUROPE'), host=self.state['host'].copy(),
            generation=generation, session=session, status=status)

    def stop_saved(self, operation):
        before = self.status()
        if not before.get('ready') or before.get('busy') or before.get('error') or before.get('clients') or before.get('restart_hold') or before.get('restart_intent'):
            raise RuntimeError('Current world is not ready for a safe update')
        session = before.get('session', '')
        if len(session) != 32 or any(c not in '0123456789abcdef' for c in session):
            raise RuntimeError('Current world supplied no valid process session challenge')
        self.record('save_requested', operation=operation, revision=self.state['revision'])
        answer = query(self.config['port'], self.token, 'save_shutdown', operation, session)
        if answer.get('operation') != operation:
            raise RuntimeError('Save operation identity not acknowledged')
        deadline = self.clock() + self.config.get('save_timeout_seconds', 1800)
        while self.alive():
            if self.clock() > deadline:
                raise RuntimeError('Save shutdown timed out; leaving owned world untouched')
            self.sleep(5)
            try:
                status = self.status()
                if status.get('error'):
                    raise RuntimeError('Production save reported an error; current host preserved')
            except (OSError, TimeoutError):
                pass
        backup = self.root / 'backups' / operation
        generation = snapshot(Path(self.state['host']['workdir']) / 'map_saves', backup, operation, session)
        self.record('validated_shutdown_backup', operation=operation, generation=generation, backup=str(backup))
        return backup, generation

    def start(self, build, backup, generation, operation):
        c = self.config
        with socket.socket() as probe:
            if os.name == 'nt':
                probe.setsockopt(socket.SOL_SOCKET, socket.SO_EXCLUSIVEADDRUSE, 1)
            probe.bind(('0.0.0.0', c['port']))
        run = self.root / 'runs' / operation
        shutil.copytree(build / 'game', run, ignore=shutil.ignore_patterns('.git'))
        manifest = json.loads((build / 'build.json').read_text())
        verify_binaries(run, manifest, build.name)
        shutil.copytree(c['config_directory'], run / 'config', dirs_exist_ok=True)
        (run / 'config/lifecycle-revision.txt').write_text(build.name, encoding='ascii')
        if backup:
            shutil.copytree(backup, run / 'map_saves')
        flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
        child = subprocess.Popen([c['daemon'], 'civ13.dmb', str(c['port']), '-trusted', '-invisible', '-log', 'supervisor-runtime.log'], cwd=run, creationflags=flags)
        previous = {key: self.state.get(key) for key in ('revision', 'host', 'generation', 'backup', 'operation')} if self.state else None
        self.state = {'revision': build.name, 'map': manifest['map'], 'binaries': manifest['binaries'], 'phase': 'starting', 'generation': generation, 'backup': str(backup) if backup else None, 'previous': previous, 'host': {'pid': child.pid, 'creation_filetime': process_identity(child.pid), 'workdir': str(run)}, 'operation': operation}
        write_json(self.state_path, self.state)
        self.record('started', revision=build.name, pid=child.pid, workdir=str(run), operation=operation)
        deadline = self.clock() + c.get('startup_timeout_seconds', 1800)
        session = None
        while self.alive():
            try:
                status = self.status()
            except (OSError, TimeoutError):
                status = None
            if status:
                if status.get('error'):
                    raise RuntimeError('Startup recovery failed; preserve this host and matched backup')
                observed_session = startup_session(status)
                if session is None:
                    session = observed_session
                elif observed_session != session:
                    raise RuntimeError('Startup process session changed')
                if status.get('ready'):
                    self.accept_ready(status, generation)
                    self.publish_ready(status, generation, session)
                    public_status = {key: value for key, value in status.items() if key not in ('session', 'token')}
                    self.record('cycle_complete', revision=build.name, generation=generation, operation=operation, status=public_status)
                    return
            if self.clock() > deadline:
                raise RuntimeError('Startup readiness timeout; no automatic fresh round or retry')
            self.sleep(5)
        raise RuntimeError('Owned host exited before readiness')

    def cycle(self, force=False):
        if (self.root / 'HALTED.json').exists():
            raise RuntimeError('Supervisor is latched halted; inspect evidence before operator recovery')
        revision = self.candidate()
        if self.state and not self.alive():
            raise RuntimeError('Previously owned host exited unexpectedly; refusing automatic restart')
        if self.state and self.state.get('phase') != 'ready':
            initial = self.status()
            self.accept_ready(initial, self.state.get('generation'))
            session = startup_session(initial)
            self.publish_ready(self.status(), self.state.get('generation'), session)
            self.record('reconciled_ready', revision=self.state['revision'], generation=self.state.get('generation'))
        if self.state:
            status = self.status()
            # An ordinary admin save temporarily clears ready and replaces the
            # completion generation. Startup binding is checked above; it must
            # not be reapplied to later saves of the same running world.
            if status.get('busy') and not status.get('error') and not status.get('restart_hold'):
                return
            self.accept_ready(status, None)
            if status.get('restart_intent'):
                raise RuntimeError('Running host has an unconsumed restart intent')
            if status.get('clients'):
                return
            if self.state.get('revision') == revision and not force:
                return
        build = self.build(revision)  # Compile before requesting any save/shutdown.
        operation = uuid.uuid4().hex
        if self.state:
            backup, generation = self.stop_saved(operation)
        elif self.config.get('initial_save'):
            backup = self.root / 'backups' / operation
            generation = snapshot(self.config['initial_save'], backup)
        else:
            backup, generation = None, None
        self.start(build, backup, generation, operation)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, required=True)
    parser.add_argument('--once', action='store_true')
    parser.add_argument('--force-cycle', action='store_true')
    args = parser.parse_args()
    config = json.loads(args.config.read_text(encoding='utf-8-sig'))
    supervisor = Supervisor(config)
    with exclusive_lock(supervisor.root / 'supervisor.lock'):
        try:
            while True:
                supervisor.cycle(force=args.force_cycle)
                if args.once:
                    break
                supervisor.sleep(config.get('poll_seconds', 300))
        except Exception as error:
            # Persistent latch also prevents task-logon or manual invocation restart storms.
            write_json(supervisor.root / 'HALTED.json', {'error': str(error), 'state': supervisor.state})
            supervisor.record('halted', error=str(error))
            raise


if __name__ == '__main__':
    main()
