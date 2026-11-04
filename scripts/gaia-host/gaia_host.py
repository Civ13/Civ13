"""Start, save-and-stop, restart and update a Windows-hosted Civ13 server.

This is the one control path the Discord bot and the launcher share. It does
what an operator does by hand: check the saved world, start the server's
scheduled task, ask the running world to save and shut down, keep a verified
copy of that save, and pull and compile master while the server is stopped.

    python gaia_host.py --config gaia-host.json status
    python gaia_host.py --config gaia-host.json start|stop|restart|update

status prints one JSON object and never changes anything. The other actions
take a lock, record their progress in <state_dir>/operation.json and run in a
detached worker, so a caller gets an answer within seconds even though a Gaia
save takes minutes. Only one action runs at a time. Actions never take paths,
commands or arguments from the caller; everything comes from the config file.

The world must have config/lifecycle-token.txt (32 hex characters, git-ignored)
for save-and-stop; start writes config/lifecycle-revision.txt from git HEAD.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import socket
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'nomads-lifecycle'))
from supervisor import byond_text_md5, query  # noqa: E402

ACTIONS = ('status', 'start', 'stop', 'restart', 'update')
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
    return config


class Platform:
    """Everything that touches the machine, so tests can replace it."""

    def run(self, argv, cwd=None, timeout=1800):
        result = subprocess.run(argv, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return result.returncode, (result.stdout + result.stderr)[-4000:]

    def listening(self, port):
        try:
            with socket.create_connection(('127.0.0.1', port), timeout=2):
                return True
        except OSError:
            return False

    def query(self, port, token, action='status', operation=None, session=None):
        return query(port, token, action, operation, session)

    def start_task(self, name):
        return self.run(['schtasks', '/Run', '/TN', name], timeout=60)

    def task_ready(self, name):
        code, out = self.run(['schtasks', '/Query', '/TN', name, '/FO', 'LIST'], timeout=60)
        return code == 0 and re.search(r'^Status:\s+Ready\s*$', out, re.M) is not None

    def detach(self, argv):
        flags = 0x00000008 | 0x00000200 if os.name == 'nt' else 0  # DETACHED_PROCESS | NEW_PROCESS_GROUP
        subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         creationflags=flags, start_new_session=os.name != 'nt', close_fds=True)

    def sleep(self, seconds):
        time.sleep(seconds)

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
        self.platform = platform or Platform()
        self.script = script or Path(__file__).resolve()
        self.repo = Path(config['repository'])
        self.state_dir = Path(config['state_dir'])
        self.state_file = self.state_dir / 'operation.json'
        self.lock = self.state_dir / 'action.lock'

    # -- state -------------------------------------------------------------
    def record(self, **values):
        self.state_dir.mkdir(parents=True, exist_ok=True)
        state = self.read_state()
        state.update(values, updated=int(self.platform.now()))
        temporary = self.state_file.with_suffix('.tmp')
        temporary.write_text(json.dumps(state, indent=1, sort_keys=True), encoding='utf-8')
        os.replace(temporary, self.state_file)
        return state

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
        listening = self.platform.listening(self.config['port'])
        world = self.world() if listening else None
        report = {'port': self.config['port'], 'listening': listening, 'operation': self.read_state() or None,
                  'busy': self.lock.exists(), 'lifecycle_token': self.token() is not None}
        if world:
            report['world'] = {key: world.get(key) for key in
                               ('ready', 'busy', 'clients', 'map', 'generation', 'revision', 'error')}
        return report

    # -- requests from callers ---------------------------------------------
    def request(self, action):
        """Check and accept an action, then hand it to a detached worker."""
        if action not in ACTIONS or action == 'status':
            raise Refused('unknown action')
        self.state_dir.mkdir(parents=True, exist_ok=True)
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
            check_save(self.repo / 'map_saves')
            if not self.platform.task_ready(self.config['task']):
                raise Refused('the scheduled task is not Ready')
        elif action in ('stop', 'restart'):
            if not listening:
                raise Refused('the server is not running')
            if not self.token():
                raise Refused('config/lifecycle-token.txt is missing, so the world cannot be asked to save')
            world = self.world()
            if not world:
                raise Refused('the world does not answer lifecycle status')
            if world.get('busy') or not world.get('ready'):
                raise Refused('the world is busy or not ready, so it cannot save now')
        elif action == 'update':
            if listening:
                raise Refused('stop the server before updating')

    # -- worker ------------------------------------------------------------
    def work(self, action, operation):
        try:
            if self.lock.read_text().strip() != operation:
                return  # another request owns the lock; leave it alone
        except OSError:
            return
        try:
            steps = {'start': [self.do_start], 'stop': [self.do_stop], 'update': [self.do_update],
                     'restart': [self.do_stop, self.do_start]}[action]
            for step in steps:
                step(operation)
            self.record(phase='done', error=None)
        except Exception as error:  # the state file is the only place a detached worker can report
            self.record(phase='failed', error=str(error)[:500])
        finally:
            self.lock.unlink(missing_ok=True)

    def do_start(self, operation):
        self.record(phase='checking save')
        generation = check_save(self.repo / 'map_saves')
        code, out = self.platform.run([self.config['git'], 'rev-parse', 'HEAD'], cwd=self.repo, timeout=60)
        revision = out.strip().splitlines()[-1] if code == 0 and out.strip() else ''
        if not HEX40.match(revision):
            raise RuntimeError('could not read the git revision')
        (self.repo / 'config' / 'lifecycle-revision.txt').write_text(revision + '\n', encoding='utf-8')
        if self.platform.listening(self.config['port']):
            raise RuntimeError('something is already listening on the port')
        self.record(phase='starting', generation=generation, revision=revision)
        code, out = self.platform.start_task(self.config['task'])
        if code != 0:
            raise RuntimeError('the scheduled task did not start: ' + out.strip()[-300:])
        deadline = self.platform.now() + self.config['start_timeout_seconds']
        while not self.platform.listening(self.config['port']):
            if self.platform.now() > deadline:
                raise RuntimeError('the server did not open its port in time')
            self.platform.sleep(2)
        self.record(phase='started')

    def do_stop(self, operation):
        token = self.token()
        before = self.world()
        if not token or not before:
            raise RuntimeError('the world does not answer lifecycle status')
        session = before.get('session', '')
        if not HEX32.match(session or ''):
            raise RuntimeError('the world gave no valid session')
        self.record(phase='saving', clients=before.get('clients'))
        answer = self.platform.query(self.config['port'], token, 'save_shutdown', operation, session)
        if answer.get('operation') != operation:
            raise RuntimeError('the world did not accept the save')
        deadline = self.platform.now() + self.config['save_timeout_seconds']
        while self.platform.listening(self.config['port']):
            if self.platform.now() > deadline:
                raise RuntimeError('the save did not finish in time; the server was left running')
            status = self.world()
            if status and status.get('error'):
                raise RuntimeError('the world reported a save error: %s' % status['error'])
            self.platform.sleep(5)
        self.record(phase='backing up')
        saves = self.repo / 'map_saves'
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
        self.record(phase='compiled', revision=out.strip()[-40:])


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--config', required=True)
    parser.add_argument('action', nargs='?', choices=ACTIONS)
    parser.add_argument('--worker', nargs=2, metavar=('ACTION', 'OPERATION'), help=argparse.SUPPRESS)
    args = parser.parse_args(argv)
    try:
        config = load_config(args.config)
    except (OSError, ValueError) as error:
        print(json.dumps({'ok': False, 'error': 'config: %s' % error}))
        return 2
    config['_path'] = str(Path(args.config).resolve())
    host = Host(config)
    if args.worker:
        host.work(*args.worker)
        return 0
    if not args.action:
        parser.error('an action is required')
    try:
        result = host.status() if args.action == 'status' else host.request(args.action)
    except Refused as refusal:
        print(json.dumps({'ok': False, 'refused': str(refusal)}))
        return 1
    print(json.dumps(dict(result, ok=True)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
