"""Default-off fixed native lifecycle spool. No arbitrary command or remote route."""
from __future__ import annotations

from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import re
import time
import uuid
import errno

import supervisor as core

PROTOCOL = 'civilizationbot.native-supervisor.v1'
ORIGIN = 'https://github.com/Civ13/Civ13.git'
FILES = {'supervisor.py', 'master_guard.py', 'bot_consumer.py', 'prepared_backend.py'}


def canonical(value):
    return json.dumps(value, ensure_ascii=True, separators=(',', ':')).encode('ascii')


def read(path):
    path = local(path)
    with path.open('rb') as stream:
        raw = stream.read(16385)
    if len(raw) > 16384:
        raise ValueError('Oversized native record')
    value = json.loads(raw.decode('utf-8-sig'))
    if not isinstance(value, dict):
        raise ValueError('Native record must be an object')
    return value


def local(path):
    path = Path(path)
    if not path.is_absolute() or str(path).startswith('\\\\'):
        raise ValueError('Explicit local absolute path required')
    for parent in (path, *path.parents):
        if parent.is_symlink() or (hasattr(parent, 'is_junction') and parent.is_junction()):
            raise ValueError('Linked native paths are unsupported')
    return path.resolve(strict=True)


def hex_value(value, size):
    if not isinstance(value, str) or not re.fullmatch('[a-f0-9]{%d}' % size, value):
        raise ValueError('Invalid native identity')
    return value


def create(path, value):
    """Exclusive durable record: never overwrites a journal or completed result."""
    with Path(path).open('xb') as stream:
        stream.write(canonical(value))
        stream.flush()
        os.fsync(stream.fileno())


def replace(path, value):
    path = Path(path)
    temporary = path.with_name(path.name + '.' + uuid.uuid4().hex + '.tmp')
    create(temporary, value)
    os.replace(temporary, path)


def publish(path, value):
    """Publish a complete immutable result, never exposing partial final bytes."""
    path = Path(path)
    temporary = path.with_name(path.name + '.' + uuid.uuid4().hex + '.tmp')
    create(temporary, value)
    os.link(temporary, path)  # Exclusive final-name publication; cannot overwrite evidence.
    temporary.unlink()


def binding(config_path, profile_path, *, allow_disabled=False):
    """Metadata/pins only: never loads an environment/token or accesses a process."""
    config, profile = read(config_path), read(profile_path)
    if profile.get('schema') != 'civilizationbot.portable.v1' or len(profile.get('servers', {})) != 1:
        raise ValueError('Exactly one explicit portable native server required')
    server = next(iter(profile['servers'].values()))
    settings = server.get('native_lifecycle', {})
    if not allow_disabled and (settings.get('enabled') is not True or server.get('enabled') is not True):
        raise RuntimeError('Bot consumer and local server are disabled')
    if server.get('ip') != '127.0.0.1' or server.get('port') != 1714:
        raise ValueError('Only loopback TEST1714 is supported')
    root, run, repository = (local(settings['supervisor_root']), local(server['basedir']), local(profile['gitdir']))
    if run.parent != local(root / 'runs') or local(config_path) != root / 'supervisor.json':
        raise ValueError('Supervisor config/run root mismatch')
    local(root / 'bot-control')
    expected = settings['expected']
    if list(expected) != ['revision', 'map', 'generation', 'dmb_sha256', 'rsc_sha256']:
        raise ValueError('Exact expected build/map/save identity required')
    hex_value(expected['revision'], 40)
    for key in ('dmb_sha256', 'rsc_sha256'):
        hex_value(expected[key], 64)
    if expected['map'] not in ('NOMADS_GAIA', 'NOMADS_EUROPE') or not re.fullmatch('round-v2:[a-f0-9]{32}', expected['generation']):
        raise ValueError('Unsupported map or generation')
    daemon = local(settings['daemon'])
    result = {'supervisor_root': str(root), 'runtime_directory': str(run),
        'repository': str(repository), 'branch': 'master', 'origin': ORIGIN, 'bind': '127.0.0.1', 'port': 1714,
        'daemon': str(daemon), 'expected': expected,
        'supervisor_sha256': settings['supervisor_sha256'], 'guard_sha256': settings['guard_sha256'], 'config_sha256': settings['config_sha256']}
    if (local(config['root']) != root or local(config['repository']) != repository or
        config.get('branch') != 'master' or config.get('bind') != '127.0.0.1' or config.get('port') != 1714 or
        config.get('map') != expected['map'] or local(config['daemon']) != daemon or config.get('bot_control_protocol') != PROTOCOL):
        raise ValueError('Supervisor configuration disagrees with the explicit native binding')
    pins = {root/'software/supervisor.py': settings['supervisor_sha256'], root/'software/master_guard.py': settings['guard_sha256'],
            root/'supervisor.json': settings['config_sha256'], daemon: settings['daemon_sha256'],
            run/'civ13.dmb': expected['dmb_sha256'], run/'civ13.rsc': expected['rsc_sha256']}
    package = config.get('bot_control_files', {})
    if set(package) != FILES:
        raise ValueError('Every installed consumer module must be source-pinned in supervisor config')
    for name, digest in package.items():
        pins[root/'software'/name] = digest
    for path, digest in pins.items():
        hex_value(digest, 64)
        if core.digest(local(path)) != digest:
            raise ValueError('Native source/configuration/build pin changed')
    # Shared pins must not be shadowed by the module manifest.
    if package['supervisor.py'] != settings['supervisor_sha256'] or package['master_guard.py'] != settings['guard_sha256']:
        raise ValueError('Conflicting supervisor source pins')
    return result, config


class Consumer:
    """The caller owns bot-consumer.lock. All native work also owns supervisor.lock."""
    def __init__(self, config_path, profile_path, backend, *, now=time.time):
        self.config_path, self.profile_path = Path(config_path), Path(profile_path)
        self.binding, self.config = binding(config_path, profile_path)
        self.hash = hashlib.sha256(canonical(self.binding)).hexdigest()
        self.root = Path(self.binding['supervisor_root'])
        self.directory = self.root / 'bot-control'
        self.backend, self.now = backend, now
        self.epoch, self.sequence = uuid.uuid4().hex, 0
        if (self.root/'HALTED.json').exists():
            raise RuntimeError('Installed supervisor is halted; no consumer action')
        if any((self.directory/name).exists() for name in ('pending.json', 'request.json', 'inflight.json')):
            raise RuntimeError('Unresolved operation survived restart; no automatic replay')
        previous = read(self.directory/'consumer-state.json') if (self.directory/'consumer-state.json').exists() else {}
        if previous.get('blocked') or (previous.get('saved_generation') and previous['saved_generation'] != self.binding['expected']['generation']):
            raise RuntimeError('Consumer state requires explicit save/operation reconciliation')
        self.sequence = previous.get('sequence', 0) + 1
        self.before = None
        self.blocked = False
        self.master_ready = False

    def verify(self):
        current, config = binding(self.config_path, self.profile_path)
        if current != self.binding or config != self.config or (self.root/'HALTED.json').exists():
            raise RuntimeError('Native binding, source, profile or halt status changed')

    def advertise(self):
        self.verify()
        with core.exclusive_lock(self.root/'supervisor.lock'):
            if not self.master_ready:
                self.backend.master()
                self.master_ready = True
            self.before = self.backend.observe()
        value = {'protocol': PROTOCOL, 'binding_sha256': self.hash, 'heartbeat_unix': int(self.now()),
                 'epoch': self.epoch, 'sequence': self.sequence, 'master_verified': True,
                 'busy': self.blocked, 'process': self.before}
        replace(self.directory/'capability.json', value)
        return value

    def validate(self, packet):
        if set(packet) != {'protocol', 'operation', 'action', 'epoch', 'sequence', 'binding_sha256', 'binding', 'before'}:
            raise ValueError('Exact native request packet required')
        hex_value(packet['operation'], 32)
        if (packet['protocol'] != PROTOCOL or packet['epoch'] != self.epoch or type(packet['sequence']) is not int or
            packet['sequence'] != self.sequence or packet['binding_sha256'] != self.hash or canonical(packet['binding']) != canonical(self.binding) or
            canonical(packet['before']) != canonical(self.before) or packet['action'] not in ('start', 'save-stop', 'restart')):
            raise ValueError('Stale, replayed or unbound native request')
        if (packet['action'] == 'start') != (packet['before'] is None):
            raise ValueError('Native request action/ownership mismatch')
        if (self.directory/('accepted-'+packet['operation']+'.json')).exists() or (self.directory/('result-'+packet['operation']+'.json')).exists():
            raise ValueError('Native operation already used')

    def consume_once(self):
        request = self.directory/'request.json'
        if self.blocked or not request.exists():
            return False
        packet = None
        try:
            self.verify()
            # Short cross-language transition lock; never held while saving/loading.
            try:
                with core.exclusive_lock(self.directory/'adapter.lock'):
                    packet = read(request)
                    self.validate(packet)
                    if read(self.directory/'pending.json') != packet:
                        raise ValueError('Request and durable bot pending record differ')
                    create(self.directory/'inflight.json', packet)
                    create(self.directory/('accepted-'+packet['operation']+'.json'), packet)
                    request.unlink()
            except OSError as error:
                if packet is None and error.errno in (errno.EACCES, errno.EAGAIN):
                    return False  # Publisher is still in its short transition; no acceptance or replay.
                raise
            with core.exclusive_lock(self.root/'supervisor.lock'):
                self.verify()
                self.backend.master()
                if self.backend.observe() != packet['before']:
                    raise RuntimeError('Owned process changed before action; no mutation')
                result = self.backend.execute(packet['action'], packet['operation'], packet['before'])
                self.verify()
            receipt = {key: packet[key] for key in ('protocol', 'operation', 'action', 'epoch', 'sequence', 'binding_sha256', 'before')}
            receipt.update(outcome='complete', master_verified=True, **result)
            # Retain generation transition before publishing completion; never fall back to the old save.
            self.sequence += 1
            advanced = result.get('saved_generation', self.binding['expected']['generation'])
            self.blocked = advanced != self.binding['expected']['generation']
            replace(self.directory/'consumer-state.json', {'sequence': self.sequence, 'saved_generation': advanced,
                    'blocked': False, 'binding_sha256': self.hash, 'last_operation': packet['operation']})
            publish(self.directory/('result-'+packet['operation']+'.json'), receipt)
            (self.directory/'inflight.json').unlink()
            return True
        except Exception:
            # No retry and no kill. Preserve request/pending/journal and a private failure latch.
            self.blocked = True
            replace(self.directory/'consumer-state.json', {'sequence': self.sequence, 'blocked': True,
                    'binding_sha256': self.hash, 'last_operation': packet.get('operation') if isinstance(packet, dict) else None})
            raise RuntimeError('Native operation failed or outcome unknown; inspect retained private evidence') from None


def main(config_path, profile_path, *, check=False):
    description, config = binding(config_path, profile_path, allow_disabled=check)
    if check:
        from importlib.util import find_spec
        print(json.dumps({'metadata_verified': True, 'binding': description,
                         'windows_execution_available': os.name == 'nt', 'psutil_available': find_spec('psutil') is not None,
                         'live_execution': False}, indent=2))
        return
    from prepared_backend import PreparedBackend
    root = Path(description['supervisor_root'])
    # Normal updates use supervisor.lock; consumer identity has its separate lifetime lock.
    with core.exclusive_lock(root/'bot-control/bot-consumer.lock'):
        backend = PreparedBackend(config, description)
        consumer = Consumer(config_path, profile_path, backend)
        while True:
            consumer.advertise()
            consumer.consume_once()
            time.sleep(1)
