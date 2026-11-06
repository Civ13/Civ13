"""Build, start, save-and-stop, restart, update, freeze and thaw a group of region worlds.

A region group (sharded servers) is several Civ13 worlds on one host. Each
region is its own git worktree of the repository with its own selected map,
build, config and map_saves, so regions never share a save or a lock:

    python shard_group.py --config group.json setup     # worktrees and region config
    python shard_group.py --config group.json update    # check out and compile every region
    python shard_group.py --config group.json start|stop|restart [--region ID]
    python shard_group.py --config group.json status
    python shard_group.py --config group.json freeze|thaw [--region ID]
    python shard_group.py --config group.json adopt --region ID --from PATH
    python shard_group.py --config group.json check-update [--region ID]

Sleeping (freeze after idle, wake on a connection or a launcher request, cold
start after a power-down) is done by the host service:
`gaia_host.py [--config gaia.json] --group group.json serve`, which also keeps
the group's transfer agents and coordinator running.

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

GROUP_ACTIONS = ('setup', 'status', 'start', 'stop', 'restart', 'update', 'freeze', 'thaw', 'adopt', 'check-update',
                 'kill', 'force-restart')
# Runtime state a stopped standalone server keeps outside map_saves (bans, admins,
# player notes, faction symbols, ...). adopt copies whichever of these exist.
ADOPT_PATHS = ('SQL', 'data/player_saves', 'data/player_notes.sav', 'data/memo.sav', 'data/memo2.sav',
               'data/faction_symbols', 'data/nomad_reputation.json', 'data/nomad_raids.json', 'data/round_counter.txt',
               'data/paintings', 'data/ToR_ban.bdb', 'data/extraction_accounts', 'data/extraction_world',
               'data/extraction_surface', 'data/extraction_loot', 'data/vehicle_key_service', 'data/safehouse_spool')
# Files setup writes for each region; an overlay must not replace them.
GENERATED = ('config/shard_region.json', 'config/lifecycle-token.txt', 'config/lifecycle-revision.txt',
             'config/transfer-token.txt', 'config/transfer_agent.json')
KINDS = ('SURFACE', 'OCEANIC', 'UNDERGROUND', 'RAILYARD', 'RAID', 'OTHER')
ID = re.compile(r'^[a-z0-9_-]{1,32}$')
HOST = re.compile(r'^[A-Za-z0-9.-]{1,64}$')
HEX40 = re.compile(r'^[0-9a-f]{40}$')
MAP_BLOCK = re.compile(r'// BEGIN_SELECTED_MAP\r?\n.*?// END_SELECTED_MAP', re.S)
RESERVED_PORTS = (1714,)  # live Gaia
MAX_REGIONS = 16


def load_group(path):
    group = json.loads(Path(path).read_text(encoding='utf-8-sig'))
    # A live group hosts the live server itself, so it may use its port.
    if type(group.setdefault('live', False)) is not bool:
        raise ValueError('live must be true or false')
    reserved = () if group['live'] else RESERVED_PORTS
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
        if port in reserved:
            raise ValueError('port %d is reserved for the live server (set "live": true for the live group)' % port)
        if region.get('public') is not None and type(region['public']) is not bool:
            raise ValueError('region %s public must be true or false' % region['id'])
        if region.get('overlay') is not None and (type(region['overlay']) is not str or not region['overlay']):
            raise ValueError('region %s overlay must be a folder path' % region['id'])
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
    # A resetting raid world never saves; it reboots on a new map every
    # reset_minutes and sends everyone still inside home without their gear.
    for r in regions:
        reset = r.setdefault('reset_minutes', 0)
        if type(reset) is not int or not (reset == 0 or 30 <= reset <= 1440):
            raise ValueError('region %s reset_minutes must be 0 or 30 to 1440' % r['id'])
        if reset and r['kind'] != 'RAID':
            raise ValueError('only a RAID region can reset (region %s)' % r['id'])
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
    if type(group['public']) is not bool:
        raise ValueError('public must be true or false')
    if group.get('overlay') is not None and (type(group['overlay']) is not str or not group['overlay']):
        raise ValueError('overlay must be a folder path')
    # update fetches this remote in the repository first, so revision can name origin/master.
    if group.get('fetch') is not None and (type(group['fetch']) is not str or not ID.match(group['fetch'])):
        raise ValueError('fetch must be a remote name such as origin')
    group.setdefault('save_timeout_seconds', 5400)
    group.setdefault('start_timeout_seconds', 300)
    group.setdefault('backups_kept', 3)
    # Linux: run each region's DreamDaemon in its own systemd scope ("user" or "system"),
    # so every world has its own cgroup for memory accounting and can be stopped alone.
    group.setdefault('systemd_scope', '')
    if group['systemd_scope'] not in ('', 'user', 'system'):
        raise ValueError('systemd_scope must be "", "user" or "system"')
    # Sleep settings (gaia_host FREEZE_DEFAULTS) apply to every region of the group.
    for key, default in gaia_host.FREEZE_DEFAULTS.items():
        if key not in group:
            continue
        value = group[key]
        if type(default) is bool or type(value) is bool:
            ok = type(value) is type(default)
        elif isinstance(default, list):
            ok = type(value) is list and all(type(item) is str for item in value)
        elif isinstance(default, str):
            ok = type(value) is str and bool(value)
        elif key == 'doorman_port':
            ok = type(value) is int and 1 <= value <= 65535
        else:
            ok = type(value) in (int, float) and value >= 0
        if not ok:
            raise ValueError('%s has the wrong type' % key)
    group['_path'] = str(Path(path).resolve())
    return group


def region_dir(group, region_id):
    return Path(group['root']) / region_id


def region_config(group, region):
    """The gaia_host-shaped config one region's host and worker run with."""
    path = region_dir(group, region['id'])
    public = region.get('public', group['public'])
    config = {'repository': str(path), 'port': region['port'], 'task': 'region:' + region['id'],
            'compiler': group['compiler'], 'daemon': group['daemon'], 'git': group['git'],
            'state_dir': str(path / 'data' / 'shard-host'), 'public': bool(public),
            'save_timeout_seconds': group['save_timeout_seconds'], 'start_timeout_seconds': group['start_timeout_seconds'],
            'backups_kept': group['backups_kept'], 'group_config': group['_path'], 'region': region['id'],
            'group': group['group'], 'python': group['python'], 'transfer_port': region.get('transfer_port'),
            'peers': [r['id'] for r in group['regions'] if r['id'] != region['id']],
            'systemd_scope': group.get('systemd_scope', ''),
            '_path': str(path / 'data' / 'shard-host' / 'host.json'),
            # Only a hub-listed (-public) world needs the host's BYOND account signed in.
            'start_requires_byond_pager': bool(public)}
    for key in gaia_host.FREEZE_DEFAULTS:
        if key in group:
            config[key] = group[key]
    return config


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
    flags = gaia_host.DETACH_FLAGS  # a hidden console, so its own children open no window
    out = open(log, 'ab') if log else subprocess.DEVNULL
    try:
        return subprocess.Popen(argv, cwd=cwd, stdin=subprocess.DEVNULL, stdout=out, stderr=subprocess.STDOUT if log else subprocess.DEVNULL,
                                creationflags=flags, start_new_session=os.name != 'nt', close_fds=True).pid
    finally:
        if log:
            out.close()


def scoped(argv, config):
    """argv wrapped in its own systemd scope when the group asks for one (Linux only)."""
    kind = config.get('systemd_scope') or ''
    if not kind or os.name == 'nt':
        return argv
    unit = 'civ13-%s-%s' % (config['group'], config['region'])
    wrapper = ['systemd-run', '--scope', '--quiet', '--collect', '--unit', unit]
    if kind == 'user':
        wrapper.insert(1, '--user')
    return wrapper + ['--'] + argv


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
        detach(scoped(argv, self.config), path, None)
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
        # Checked before the lock: taking it would create the folder setup needs empty.
        if action in ('start', 'restart', 'update') and not (self.repo / '.git').exists():
            raise Refused('the region is not set up; run setup first')
        if action == 'update' and self.platform.listening(self.config['port']):
            raise Refused('stop the region before updating')
        return super().request(action)

    def precheck(self, action):
        # start compiles a missing or stale build itself (Host.do_refresh), so a
        # region with no build yet is not refused.
        super().precheck(action)

    def task_ready_for_start(self):
        return True

    def dmb(self):
        return self.repo / 'region.dmb'

    def latest_revision(self):
        """Fetch the group's remote, then the group revision this region should run."""
        group = load_group(self.config['group_config'])
        # Regions starting together share the repository; a fetch that meets
        # another region's ref lock is retried.
        for attempt in range(3):
            try:
                fetch_remote(group, self.platform)
                break
            except Refused:
                if attempt == 2:
                    raise
                self.platform.sleep(5)
        return self.git_text(['rev-parse', group['revision']], group['repository'])

    def check_update(self):
        """Like Host.check_update, for this region: its worktree's HEAD against the
        group's revision, after fetching the group's remote."""
        group = self.config.get('_group') or load_group(self.config['group_config'])
        fetch_remote(group, self.platform)
        available = self.git_text(['rev-parse', group['revision']], group['repository'])
        answer = self.update_answer(self.git_text(['rev-parse', 'HEAD'], self.repo), available, group['repository'])
        return dict(answer, region=self.config['region'])

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
        apply_overlays(group, region, path)
        if group['persistent']:
            persistent_config(path / 'config' / 'config.txt', saving=not region.get('reset_minutes'))
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
        self.record_build(revision)
        self.record(phase='compiled', revision=revision, map=region['map'])


def apply_overlays(group, region, path):
    """Copy the group's overlay folder, then the region's, over the region's worktree.

    An overlay holds what git does not: the live config/config.txt (webhook key),
    config/host.txt, native DLLs and their settings. It is copied after every
    checkout, so a forced checkout never loses it. Returns the copied paths.
    """
    copied = []
    for source in (group.get('overlay'), region.get('overlay')):
        if not source:
            continue
        source = Path(source)
        if not source.is_absolute() or not source.is_dir():
            raise RuntimeError('overlay %s is not an absolute folder' % source)
        files = sorted(p for p in source.rglob('*') if p.is_file())
        for item in files:
            relative = item.relative_to(source).as_posix()
            if relative in GENERATED or relative.split('/')[0] in ('map_saves', '.git', 'data'):
                raise RuntimeError('overlay %s must not contain %s' % (source, relative))
        for item in files:
            relative = item.relative_to(source)
            target = path / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(item, target)
            copied.append(relative.as_posix())
    return copied


def adopt(group, region_id, source, platform=None):
    """Move a stopped standalone server (such as live Gaia's own checkout) into a region.

    Copies its map_saves, checking every file's SHA-256, and the runtime state in
    ADOPT_PATHS into the region's worktree. The source is left as it was, so it
    stays a rollback. Refuses unless the source is stopped with a complete save,
    the region is set up, not running and has no save of its own.
    """
    platform = platform or Platform()
    region = next((r for r in group['regions'] if r['id'] == region_id), None)
    if region is None:
        raise Refused('no region %s in the group' % region_id)
    source = Path(source)
    target = region_dir(group, region_id)
    if not (target / '.git').exists():
        raise Refused('region %s is not set up; run setup first' % region_id)
    if source.resolve() == target.resolve():
        raise Refused('the source is the region itself')
    if platform.listening(region['port']):
        raise Refused('region %s is running; stop it first' % region_id)
    saves = source / 'map_saves'
    if not saves.is_dir() or any(p.name.endswith('.lk') for p in saves.iterdir()):
        raise Refused('%s has no map_saves, or the save is still locked (is that server stopped?)' % source)
    if gaia_host.check_save(saves) is None:
        raise Refused('%s has an empty save; there is nothing to adopt' % source)
    destination = target / 'map_saves'
    if destination.exists() and any(destination.iterdir()):
        raise Refused('region %s already has a save; it was not replaced' % region_id)
    if destination.exists():
        destination.rmdir()
    receipt = gaia_host.copy_save(saves, destination)
    (destination / 'backup-receipt.json').unlink()
    copied = []
    for name in ADOPT_PATHS:
        item = source / name
        if item.is_dir():
            shutil.copytree(item, target / name, dirs_exist_ok=True)
        elif item.is_file():
            (target / name).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(item, target / name)
        else:
            continue
        copied.append(name)
    return {'region': region_id, 'save': sorted(receipt), 'generation': gaia_host.check_save(destination), 'copied': copied}


def fetch_remote(group, platform=None):
    """git fetch the group's `fetch` remote in the repository, once, before setup or update."""
    if not group.get('fetch'):
        return False
    platform = platform or Platform()
    code, out = platform.run([group['git'], 'fetch', group['fetch']], cwd=group['repository'], timeout=600)
    if code != 0:
        raise Refused('git fetch %s failed: %s' % (group['fetch'], out.strip()[-300:]))
    return True


def persistent_config(path, saving=True):
    """Make a region world a persistent round that saves: ALLOWED_GAMEMODES
    PERSISTENCE, and SKIP_PERSISTENCE_SAVING (on in the repository's development
    config) commented out. A resetting raid world keeps it on (saving=False)."""
    lines = path.read_text(encoding='utf-8').splitlines() if path.exists() else []
    out, found = [], False
    for line in lines:
        key = line.split(' ', 1)[0]
        if key == 'ALLOWED_GAMEMODES':
            line, found = 'ALLOWED_GAMEMODES PERSISTENCE', True
        elif key == 'SKIP_PERSISTENCE_SAVING' and saving:
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
        settings = {'group': group['group'], 'region': region['id'], 'regions': directory(group), 'mainland': group['mainland'],
                    'save_minutes': group['save_minutes'] if group['persistent'] and not region['reset_minutes'] else 0,
                    'travel_save_seconds': group['travel_save_seconds'], 'reset_minutes': region['reset_minutes'],
                    # The host service's doorman on this machine; regions ask it which peers
                    # sleep (a direct poll would wake them) and to wake one for a traveller.
                    'doorman': '127.0.0.1:%d' % group.get('doorman_port', gaia_host.FREEZE_DEFAULTS['doorman_port'])}
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
    """Whether pid runs. Asks the OS directly: the host service calls this every
    half minute, and a tasklist child flashed a console window on Windows."""
    return Platform().alive(pid)


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


def group_check_update(group, only=None, platform=None):
    """One update line for the group (the launcher's server row), with each region's
    own answer under "regions". Fetches once; never merges or touches a world."""
    fetch_remote(group, platform)
    group = dict(group, fetch=None)  # already fetched
    regions = {}
    for region, host in hosts(group, only, platform):
        host.config['_group'] = group
        regions[region['id']] = host.check_update()
    first = next(iter(regions.values()))
    behind = max(answer['behind'] for answer in regions.values())
    reasons = sorted({answer['reason'] for answer in regions.values() if answer['reason'] and answer['behind']})
    return {'component': 'server', 'current': first['current'], 'available': first['available'], 'behind': behind,
            'can_update': bool(behind) and not reasons, 'reason': None if behind and not reasons else ('; '.join(reasons) or 'up to date'),
            'regions': regions}


def region_summary(group, platform=None):
    """Every region's state and player count, for the bot's status line. Never asks a
    sleeping world anything (that would queue a connection and wake it)."""
    summary = []
    for region, host in hosts(group, None, platform):
        try:
            entry = host.status()
        except (OSError, RuntimeError, ValueError) as error:
            entry = {'state': 'unknown', 'error': str(error)[:120]}
        world = entry.get('world') or {}
        summary.append({'id': region['id'], 'name': region['name'], 'kind': region['kind'], 'port': region['port'],
                        'state': entry.get('state', 'unknown'),
                        'players': world.get('clients') if type(world.get('clients')) is int else None})
    return summary


def supervise(group, start=detach):
    """Start any of the group's transfer agents or its coordinator that is not running.

    The host service calls this every half minute. Agents run even while their world
    sleeps or is cold, so travellers to it are journaled and handed over on wake.
    Returns what was started (empty when everything was already running).
    """
    if not group['transfers']:
        return {}
    started = {}
    for region in group['regions']:
        # One region that cannot start its agent must not keep the others down.
        try:
            if RegionPlatform(region_config(group, region)).start_agent():
                started.setdefault('agents', []).append(region['id'])
        except OSError as error:
            started.setdefault('errors', {})[region['id']] = str(error)[:300]
    if ensure_coordinator(group, start):
        started['coordinator'] = True
    return started


def group_status(group, only=None, view=region_view, platform=None):
    report = {}
    for region, host in hosts(group, only, platform):
        entry = host.status()
        entry.update(kind=region['kind'], name=region['name'], built=(region_dir(group, region['id']) / 'region.dmb').exists())
        # A frozen world cannot answer; asking it would only queue a connection.
        if entry.get('listening') and entry.get('state') == 'awake':
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
    parser.add_argument('--from', dest='source', help='adopt: the stopped standalone server folder')
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
        if args.action in ('setup', 'update'):
            fetch_remote(group)
        if args.action == 'setup':
            result = setup(group)
        elif args.action == 'status':
            result = group_status(group, args.region)
        elif args.action == 'check-update':
            try:
                result = group_check_update(group, args.region)
            except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
                print(json.dumps({'ok': False, 'component': 'server', 'error': str(error)[:300]}))
                return 1
        elif args.action == 'adopt':
            if not args.region or not args.source:
                parser.error('adopt needs --region and --from')
            result = adopt(group, args.region, args.source)
        elif args.action in ('freeze', 'thaw', 'kill'):
            # kill: forced stop without saving; the next start restores the last completed save.
            done, refused = {}, {}
            for region, host in hosts(group, args.region):
                try:
                    done[region['id']] = getattr(host, args.action)()  # freeze, thaw or kill
                except Refused as refusal:
                    refused[region['id']] = str(refusal)
            if refused and not done:
                print(json.dumps({'ok': False, 'refused': refused}))
                return 1
            result = {'done': done, 'refused': refused}
        else:
            accepted, refused = {}, {}
            for region, host in hosts(group, args.region):
                try:
                    accepted[region['id']] = host.force_restart() if args.action == 'force-restart' else host.request(args.action)
                except Refused as refusal:
                    refused[region['id']] = str(refusal)
            result = {'accepted': accepted, 'refused': refused}
            if args.action in ('start', 'restart', 'force-restart') and accepted:
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
