"""Build, start, save-and-stop, restart, update and watch a group of region worlds.

A region group (sharded servers) is several Civ13 worlds on one host. Each
region is its own git worktree of the repository with its own selected map,
build, config and map_saves, so regions never share a save or a lock:

    python shard_group.py --config group.json setup     # worktrees and region config
    python shard_group.py --config group.json update    # check out and compile every region
    python shard_group.py --config group.json start|stop|restart [--region ID]
    python shard_group.py --config group.json status

Each region is driven by the same host logic as scripts/gaia-host/gaia_host.py
(one detached worker per action, progress in operation.json, save-and-stop
through the world's lifecycle topic, a verified backup of every save), except
that DreamDaemon is started directly instead of through a scheduled task.
Actions never take paths or commands from the caller; everything comes from
the group config. setup never touches the source checkout's own files.
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
import struct
import subprocess
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'gaia-host'))
import gaia_host  # noqa: E402
from gaia_host import Host, Platform, Refused  # noqa: E402

GROUP_ACTIONS = ('setup', 'status', 'start', 'stop', 'restart', 'update')
KINDS = ('SURFACE', 'OCEANIC', 'UNDERGROUND', 'RAILYARD', 'RAID', 'OTHER')
ID = re.compile(r'^[a-z0-9_-]{1,32}$')
HOST = re.compile(r'^[A-Za-z0-9.-]{1,64}$')
HEX40 = re.compile(r'^[0-9a-f]{40}$')
MAP_BLOCK = re.compile(r'// BEGIN_SELECTED_MAP\r?\n.*?// END_SELECTED_MAP', re.S)
RESERVED_PORTS = (1714,)  # live Gaia
MAX_REGIONS = 16


def load_group(path):
    group = json.loads(Path(path).read_text(encoding='utf-8-sig'))
    for key in ('group', 'repository', 'root', 'compiler', 'daemon', 'git', 'public_host'):
        if type(group.get(key)) is not str or not group[key]:
            raise ValueError('group config needs %s' % key)
    if not ID.match(group['group']):
        raise ValueError('group id must be 1-32 of a-z, 0-9, - and _')
    if not HOST.match(group['public_host']):
        raise ValueError('public_host must be a plain host name or IPv4 address')
    regions = group.get('regions')
    if type(regions) is not list or not 1 <= len(regions) <= MAX_REGIONS:
        raise ValueError('a group has 1 to %d regions' % MAX_REGIONS)
    ids, ports = set(), set()
    for region in regions:
        if type(region) is not dict or not ID.match(str(region.get('id', ''))) or region['id'] in ids:
            raise ValueError('every region needs a unique id of 1-32 of a-z, 0-9, - and _')
        if type(region.get('name')) is not str or not 1 <= len(region['name']) <= 64:
            raise ValueError('region %s needs a name of 1 to 64 characters' % region['id'])
        if region.get('kind') not in KINDS:
            raise ValueError('region %s kind must be one of %s' % (region['id'], ', '.join(KINDS)))
        port = region.get('port')
        if type(port) is not int or not 1024 <= port <= 65535 or port in ports:
            raise ValueError('region %s needs a unique port from 1024 to 65535' % region['id'])
        if port in RESERVED_PORTS:
            raise ValueError('port %d is reserved for the live server' % port)
        if type(region.get('map')) is not str or not region['map'].endswith('.dmm'):
            raise ValueError('region %s needs a map (.dmm)' % region['id'])
        ids.add(region['id'])
        ports.add(port)
    # Transfers (character travel and trade) need an agent port on every region.
    transfer_ports = [r.get('transfer_port') for r in regions]
    if any(p is not None for p in transfer_ports):
        for region, port in zip(regions, transfer_ports):
            if type(port) is not int or not 1024 <= port <= 65535 or port in ports or port in RESERVED_PORTS:
                raise ValueError('region %s needs a unique transfer_port from 1024 to 65535' % region['id'])
            ports.add(port)
        group['transfers'] = True
    else:
        group['transfers'] = False
    # New characters, and players whose character died, start in the mainland
    # region and reach the others only by travel.
    mainland = group.setdefault('mainland', regions[0]['id'])
    if mainland not in ids:
        raise ValueError('mainland must be one of the region ids')
    # Raid worlds reset and send everyone home; nobody can live in one.
    if any(r['id'] == mainland and r['kind'] == 'RAID' for r in regions):
        raise ValueError('the mainland cannot be a RAID region')
    for key, low, high, default in (('save_minutes', 0, 1440, 15), ('travel_save_seconds', 10, 3600, 60)):
        value = group.setdefault(key, default)
        if type(value) is not int or not low <= value <= high:
            raise ValueError('%s must be a whole number from %d to %d' % (key, low, high))
    if type(group.setdefault('persistent', True)) is not bool:
        raise ValueError('persistent must be true or false')
    if group.get('python') is not None and (type(group['python']) is not str or not group['python']):
        raise ValueError('python must be a path')
    group.setdefault('python', sys.executable)
    if group.get('rust_g') is not None and (type(group['rust_g']) is not str or not group['rust_g']):
        raise ValueError('rust_g must be a path')
    root, repository = Path(group['root']).resolve(), Path(group['repository']).resolve()
    if root == repository or repository in root.parents or root in repository.parents:
        raise ValueError('root must be outside the repository (and not contain it)')
    group.setdefault('revision', 'HEAD')
    group.setdefault('public', False)
    group.setdefault('save_timeout_seconds', 5400)
    group.setdefault('start_timeout_seconds', 300)
    group.setdefault('backups_kept', 3)
    group['_path'] = str(Path(path).resolve())
    return group


def region_dir(group, region_id):
    return Path(group['root']) / region_id


def region_config(group, region):
    """The gaia_host-shaped config one region's host and worker run with."""
    path = region_dir(group, region['id'])
    return {'repository': str(path), 'port': region['port'], 'task': 'region:' + region['id'],
            'compiler': group['compiler'], 'daemon': group['daemon'], 'git': group['git'],
            'state_dir': str(path / 'data' / 'shard-host'), 'public': bool(group['public']),
            'save_timeout_seconds': group['save_timeout_seconds'], 'start_timeout_seconds': group['start_timeout_seconds'],
            'backups_kept': group['backups_kept'], 'group_config': group['_path'], 'region': region['id'],
            'group': group['group'], 'python': group['python'], 'transfer_port': region.get('transfer_port'),
            'peers': [r['id'] for r in group['regions'] if r['id'] != region['id']],
            '_path': str(path / 'data' / 'shard-host' / 'host.json')}


def directory(group):
    """config/shard_region.json for one region: the whole group plus which region this is."""
    return [{'id': r['id'], 'name': r['name'], 'kind': r['kind'], 'address': '%s:%d' % (group['public_host'], r['port'])}
            for r in group['regions']]


def selected_map_dme(dme_text, include):
    if not MAP_BLOCK.search(dme_text):
        raise RuntimeError('civ13.dme has no selected-map block')
    newline = '\r\n' if '\r\n' in dme_text else '\n'
    block = '// BEGIN_SELECTED_MAP' + newline + '#include "' + include + '"' + newline + '// END_SELECTED_MAP'
    return MAP_BLOCK.sub(lambda _: block, dme_text, count=1)


TRANSFER_TOOLS = Path(__file__).resolve().parents[2] / 'tools' / 'transfer_storage'


def detach(argv, cwd, log):
    """Start a process that outlives this one, with its output in log (or discarded)."""
    flags = 0x00000008 | 0x00000200 if os.name == 'nt' else 0
    out = open(log, 'ab') if log else subprocess.DEVNULL
    try:
        return subprocess.Popen(argv, cwd=cwd, stdin=subprocess.DEVNULL, stdout=out, stderr=subprocess.STDOUT if log else subprocess.DEVNULL,
                                creationflags=flags, start_new_session=os.name != 'nt', close_fds=True).pid
    finally:
        if log:
            out.close()


class RegionPlatform(Platform):
    """Starts DreamDaemon for one region directly instead of a scheduled task."""

    def __init__(self, config):
        self.config = config

    def start_task(self, name):
        path = Path(self.config['repository'])
        (path / 'logs').mkdir(exist_ok=True)
        # The world must find its agent when it loads, so the agent starts first.
        self.start_agent()
        argv = [self.config['daemon'], 'region.dmb', str(self.config['port']), '-trusted', '-close',
                '-public' if self.config['public'] else '-invisible', '-log', 'logs/world.log']
        detach(argv, path, None)
        return 0, 'started'

    def task_ready(self, name):
        return (Path(self.config['repository']) / 'region.dmb').exists()

    def start_agent(self):
        """Start this region's transfer agent unless it already listens."""
        port = self.config.get('transfer_port')
        if not port or self.listening(port):
            return False
        path = Path(self.config['repository'])
        argv = [self.config['python'], str(TRANSFER_TOOLS / 'agent.py'), '--db', str(Path(self.config['state_dir']) / 'transfers.sqlite'),
                '--region', self.config['region'], '--group', self.config['group'], '--port', str(port),
                '--token-file', str(path / 'config' / 'transfer-token.txt')]
        for peer in self.config['peers']:
            argv += ['--enroll', peer + ':out', '--enroll', peer + ':in']
        detach(argv, path, Path(self.config['state_dir']) / 'agent.log')
        return True


class RegionHost(Host):
    def __init__(self, config, platform=None):
        super().__init__(config, platform or RegionPlatform(config), script=Path(__file__).resolve())

    def request(self, action):
        if action == 'update' and self.platform.listening(self.config['port']):
            raise Refused('stop the region before updating')
        return super().request(action)

    def precheck(self, action):
        if action == 'start' and not self.platform.task_ready(self.config['task']):
            raise Refused('the region has no build yet; run update first')
        super().precheck(action)

    def do_update(self, operation):
        """Check out the group's revision in this region's worktree and compile region.dme."""
        group = load_group(self.config['group_config'])
        region = next(r for r in group['regions'] if r['id'] == self.config['region'])
        git, path = self.config['git'], self.repo
        self.record(phase='checking out')
        code, out = self.platform.run([git, 'rev-parse', group['revision']], cwd=group['repository'], timeout=60)
        revision = out.strip().splitlines()[-1] if code == 0 and out.strip() else ''
        if not HEX40.match(revision):
            raise RuntimeError('could not resolve the group revision')
        # --force: the region's config/config.txt override below is rewritten every update.
        code, out = self.platform.run([git, 'checkout', '--force', '--detach', revision], cwd=path, timeout=600)
        if code != 0:
            raise RuntimeError('checkout failed: ' + out.strip()[-300:])
        if group['persistent']:
            persistent_config(path / 'config' / 'config.txt')
        if group.get('rust_g'):
            shutil.copyfile(group['rust_g'], path / Path(group['rust_g']).name)
        include = place_map(group, region)
        dme = (path / 'civ13.dme').read_text(encoding='utf-8')
        (path / 'region.dme').write_text(selected_map_dme(dme, include), encoding='utf-8', newline='')
        if self.platform.listening(self.config['port']):
            raise RuntimeError('the region started during the update; not compiling')
        self.record(phase='compiling', revision=revision)
        code, out = self.platform.run([self.config['compiler'], 'region.dme'], cwd=path, timeout=1800)
        if code != 0 or '0 errors' not in out:
            raise RuntimeError('compile failed: ' + out.strip()[-300:])
        self.record(phase='compiled', revision=revision, map=region['map'])


def persistent_config(path):
    """Make a region world a persistent round that saves: ALLOWED_GAMEMODES
    PERSISTENCE, and SKIP_PERSISTENCE_SAVING (on in the repository's development
    config) commented out."""
    lines = path.read_text(encoding='utf-8').splitlines() if path.exists() else []
    out, found = [], False
    for line in lines:
        key = line.split(' ', 1)[0]
        if key == 'ALLOWED_GAMEMODES':
            line, found = 'ALLOWED_GAMEMODES PERSISTENCE', True
        elif key == 'SKIP_PERSISTENCE_SAVING':
            line = '#' + line
        out.append(line)
    if not found:
        out.append('ALLOWED_GAMEMODES PERSISTENCE')
    path.write_text('\n'.join(out) + '\n', encoding='utf-8')


def place_map(group, region):
    """Return the region.dme include for the region's map, copying an outside map into the worktree."""
    path = region_dir(group, region['id'])
    source = Path(region['map'])
    if not source.is_absolute():
        if '..' in source.parts or not (path / source).is_file():
            raise RuntimeError('map %s is not a file in the repository' % region['map'])
        return str(source).replace('/', '\\')
    if not source.is_file():
        raise RuntimeError('map %s does not exist' % region['map'])
    target = path / 'maps' / 'regions' / (region['id'] + '.dmm')
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
    return 'maps\\regions\\%s.dmm' % region['id']


def setup(group, platform=None):
    """Create each region's worktree and write its config. Refuses while any region is running."""
    platform = platform or Platform()
    git, repository = group['git'], group['repository']
    code, out = platform.run([git, 'rev-parse', group['revision']], cwd=repository, timeout=60)
    revision = out.strip().splitlines()[-1] if code == 0 and out.strip() else ''
    if not HEX40.match(revision):
        raise Refused('could not resolve the group revision')
    for region in group['regions']:
        if platform.listening(region['port']):
            raise Refused('region %s is running; stop it before setup' % region['id'])
    Path(group['root']).mkdir(parents=True, exist_ok=True)
    made = []
    for region in group['regions']:
        path = region_dir(group, region['id'])
        if not (path / '.git').exists():
            if path.exists() and any(path.iterdir()):
                raise Refused('%s exists and is not a region worktree' % path)
            code, out = platform.run([git, 'worktree', 'add', '--detach', str(path), revision], cwd=repository, timeout=600)
            if code != 0:
                raise Refused('worktree for %s failed: %s' % (region['id'], out.strip()[-300:]))
            made.append(region['id'])
        (path / 'map_saves').mkdir(exist_ok=True)
        config = path / 'config'
        config.mkdir(exist_ok=True)
        settings = {'group': group['group'], 'region': region['id'], 'regions': directory(group),
                    'save_minutes': group['save_minutes'] if group['persistent'] else 0,
                    'travel_save_seconds': group['travel_save_seconds']}
        (config / 'shard_region.json').write_text(json.dumps(settings, indent=1) + '\n', encoding='utf-8')
        token = config / 'lifecycle-token.txt'
        if not token.exists():
            token.write_text(secrets.token_hex(16) + '\n', encoding='utf-8')
        if group['transfers']:
            secret = config / 'transfer-token.txt'
            if not secret.exists():
                secret.write_text(secrets.token_hex(24) + '\n', encoding='utf-8')
            peers = [r['id'] for r in group['regions'] if r['id'] != region['id']]
            agent = {'port': region['transfer_port'], 'token_file': 'config/transfer-token.txt', 'peers': peers, 'poll_seconds': 5}
            (config / 'transfer_agent.json').write_text(json.dumps(agent, indent=1) + '\n', encoding='utf-8')
        host = region_config(group, region)
        Path(host['state_dir']).mkdir(parents=True, exist_ok=True)
        Path(host['_path']).write_text(json.dumps(host, indent=1) + '\n', encoding='utf-8')
    return {'revision': revision, 'created': made, 'regions': [r['id'] for r in group['regions']]}


def hosts(group, only=None, platform=None):
    chosen = [r for r in group['regions'] if only in (None, r['id'])]
    if not chosen:
        raise Refused('no region %s in the group' % only)
    return [(r, RegionHost(region_config(group, r), platform)) for r in chosen]


def region_view(port, timeout=10):
    """Ask a running region what it is and how it sees its peers (shard_region topic)."""
    payload = b'\0' * 5 + b'shard_region=1&format=json&peers=1' + b'\0'
    try:
        with socket.create_connection(('127.0.0.1', port), timeout=timeout) as connection:
            connection.sendall(b'\x00\x83' + struct.pack('>H', len(payload)) + payload)
            data = b''
            while len(data) < 4 or len(data) < 4 + struct.unpack('>H', data[2:4])[0]:
                part = connection.recv(65536)
                if not part:
                    return None
                data += part
        body = data[4:4 + struct.unpack('>H', data[2:4])[0]]
        if data[:2] != b'\x00\x83' or not body or body[0] != 6:
            return None
        answer = json.loads(body[1:].rstrip(b'\0').decode('utf-8'))
    except (OSError, ValueError):
        return None
    return answer if isinstance(answer, dict) else None


def process_alive(pid):
    if os.name == 'nt':
        out = subprocess.run(['tasklist', '/FI', 'PID eq %d' % pid, '/NH'], capture_output=True, text=True).stdout
        return str(pid) in out
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def coordinator_pid(group):
    """The running coordinator's pid, or None."""
    try:
        pid = int((Path(group['root']) / 'coordinator.pid').read_text(encoding='utf-8').strip())
    except (OSError, ValueError):
        return None
    return pid if process_alive(pid) else None


def ensure_coordinator(group, start=detach):
    """Start the group's relay between region agents unless it already runs."""
    if not group['transfers'] or coordinator_pid(group):
        return False
    root = Path(group['root'])
    argv = [group['python'], str(TRANSFER_TOOLS / 'coordinator.py'), '--db', str(root / 'coordinator.sqlite'), '--group', group['group'],
            '--mainland', group['mainland']]
    for region in group['regions']:
        token = region_dir(group, region['id']) / 'config' / 'transfer-token.txt'
        argv += ['--region', '%s=http://127.0.0.1:%d=%s' % (region['id'], region['transfer_port'], token)]
    pid = start(argv, root, root / 'coordinator.log')
    (root / 'coordinator.pid').write_text('%d\n' % pid, encoding='utf-8')
    return True


def group_status(group, only=None, view=region_view, platform=None):
    report = {}
    for region, host in hosts(group, only, platform):
        entry = host.status()
        entry.update(kind=region['kind'], name=region['name'], built=(region_dir(group, region['id']) / 'region.dmb').exists())
        if entry.get('listening'):
            seen = view(region['port'])
            # A world that answers for another group or id is not this region.
            if not seen or seen.get('group') != group['group'] or seen.get('region') != region['id']:
                entry['region_view'] = {'error': 'no matching shard_region answer'}
            else:
                entry['region_view'] = {'players': seen.get('players'), 'map': seen.get('map'), 'peers': seen.get('peers') or {}}
        if group['transfers']:
            entry['transfer_agent'] = (platform or RegionPlatform(region_config(group, region))).listening(region['transfer_port'])
        report[region['id']] = entry
    result = {'group': group['group'], 'regions': report}
    if group['transfers']:
        result['coordinator'] = coordinator_pid(group) is not None
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--config', required=True)
    parser.add_argument('action', nargs='?', choices=GROUP_ACTIONS)
    parser.add_argument('--region')
    parser.add_argument('--worker', nargs=2, metavar=('ACTION', 'OPERATION'), help=argparse.SUPPRESS)
    args = parser.parse_args(argv)
    if args.worker:
        # A detached worker is started with one region's own host.json.
        config = json.loads(Path(args.config).read_text(encoding='utf-8'))
        RegionHost(config).work(*args.worker)
        return 0
    try:
        group = load_group(args.config)
    except (OSError, ValueError) as error:
        print(json.dumps({'ok': False, 'error': 'config: %s' % error}))
        return 2
    if not args.action:
        parser.error('an action is required')
    try:
        if args.action == 'setup':
            result = setup(group)
        elif args.action == 'status':
            result = group_status(group, args.region)
        else:
            accepted, refused = {}, {}
            for region, host in hosts(group, args.region):
                try:
                    accepted[region['id']] = host.request(args.action)
                except Refused as refusal:
                    refused[region['id']] = str(refusal)
            result = {'accepted': accepted, 'refused': refused}
            if args.action in ('start', 'restart') and accepted:
                result['coordinator_started'] = ensure_coordinator(group)
            if refused and not accepted:
                print(json.dumps({'ok': False, 'refused': refused}))
                return 1
    except Refused as refusal:
        print(json.dumps({'ok': False, 'refused': str(refusal)}))
        return 1
    print(json.dumps(dict(result, ok=True)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
