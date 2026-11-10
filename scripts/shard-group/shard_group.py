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
    python shard_group.py --config group.json help-status|help-start|help-stop
    python shard_group.py --config group.json config-apply [--region ID]  # overlays + config.local.txt, no compile
    python shard_group.py --config group.json config-migrate  # whole overlay config.txt -> config.local.txt

Sleeping (freeze after idle, wake on a connection or a launcher request, cold
start after a power-down) is done by the host service:
`gaia_host.py [--config gaia.json] --group group.json serve`, which also keeps
the group's transfer agents and coordinator running, and (when the group
config has "player_help") one "Ask for help" bridge per region.

Each region is driven by the same host logic as scripts/gaia-host/gaia_host.py
(one detached worker per action, progress in operation.json, save-and-stop
through the world's lifecycle topic, a verified backup of every save), except
that DreamDaemon is started directly instead of through a scheduled task.
Actions never take paths or commands from the caller; everything comes from
the group config. setup never touches the source checkout's own files.
"""
from __future__ import annotations

import argparse
import contextlib
import filecmp
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

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'gaia-host'))
import gaia_host  # noqa: E402
from byond_topic import frame_query  # noqa: E402
from gaia_host import Host, Platform, Refused  # noqa: E402

GROUP_ACTIONS = ('setup', 'status', 'start', 'stop', 'restart', 'update', 'freeze', 'thaw', 'adopt', 'check-update',
                 'kill', 'force-restart', 'stage', 'enrol', 'help-status', 'help-start', 'help-stop', 'unlock', 'force-unlock',
                 'config-apply', 'config-migrate', 'handover', 'epoch')
HELP_STOP_SECONDS = 60  # help-stop waits this long for bridges to finish their answers before ending them
HELP_STARTING_SECONDS = 300  # a bridge we started may load its corpus this long before it takes the lock
# code/modules/persistence/functions.dm epoch_names, in order: a map's ordinal_age indexes it from 0.
EPOCH_NAMES = ('5000 B.C.', '313 B.C.', '1013', '1713', '1873', '1903', '1943', '1969', '2013', '2026')
STAGED_OUTPUTS = ('region.dmb', 'region.rsc')  # what a staged compile hands to the running worktree
# A handover boots the staged build beside the running world, so the region keeps two build
# slots and build.json names the live one ('file'); the other is free for the next standby.
DMB_SLOTS = ('region.dmb', 'region.b.dmb')
STANDBY_PORT_OFFSET = 10  # the standby's loopback control port unless the region sets standby_port
STANDBY_LOG = 'logs/world.standby.log'
SWITCH_SECONDS = 120  # how long the old world may take to close its port after it is released
OPEN_SECONDS = 180  # how long the loaded standby is asked to take the region port
STAGE_LOCK_HOURS = 3  # a stage lock older than this belongs to a worker that died
DEFAULT_MIN_FREE_DISK_MB = 2048  # stage and handover refuse below this much free disk (min_free_disk_mb)
# Runtime state a stopped standalone server keeps outside map_saves (bans, admins,
# player notes, faction symbols, ...). adopt copies whichever of these exist.
ADOPT_PATHS = ('SQL', 'data/player_saves', 'data/player_notes.sav', 'data/memo.sav', 'data/memo2.sav',
               'data/faction_symbols', 'data/nomad_reputation.json', 'data/nomad_raids.json', 'data/round_counter.txt',
               'data/paintings', 'data/ToR_ban.bdb', 'data/extraction_accounts', 'data/extraction_world',
               'data/extraction_surface', 'data/extraction_loot', 'data/vehicle_key_service', 'data/safehouse_spool')
# Live process state inside ADOPT_PATHS that adopt must not copy: the Player Help
# bridge's spool belongs to the worker serving the source folder. A copied
# worker.lock and health.json make the region's own bridge refuse to start (or
# its game read a frozen heartbeat and report help unavailable).
ADOPT_SKIP = {'SQL': ('player-help',)}
# Files setup writes for each region; an overlay must not replace them.
LOCAL_CONFIG = 'config/config.local.txt'  # an overlay's own lines for config/config.txt (merge_config)
KEPT_COPY = re.compile(r'\.(previous|migrated)$|\.bak(-|$)')  # earlier versions an overlay keeps, never copied
CONFIG_NAME = re.compile(r'^[A-Za-z][A-Za-z0-9_]*$')
GENERATED = ('config/shard_region.json', 'config/lifecycle-token.txt', 'config/lifecycle-revision.txt',
             'config/transfer-token.txt', 'config/transfer_agent.json', 'config/relay-token.txt',
             'config/tdm-token.txt', 'config/shard_build.json')
# BARRACKS is the always-on TDM world players wait and practise in; BATTLE runs the
# TDM rounds, rotates its map after each vote and sends everyone back to the
# barracks before it reboots (code/modules/tdm_barracks).
KINDS = ('SURFACE', 'OCEANIC', 'UNDERGROUND', 'RAILYARD', 'RAID', 'ORBIT', 'OTHER', 'BARRACKS', 'BATTLE')
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
    if any(r['id'] == mainland and r['kind'] == 'ORBIT' for r in regions):
        raise ValueError('the mainland cannot be an ORBIT region')
    # A TDM pair: at most one barracks and one battle world, and a battle world
    # needs a barracks to send its players back to.
    barracks = [r for r in regions if r['kind'] == 'BARRACKS']
    battles = [r for r in regions if r['kind'] == 'BATTLE']
    if len(barracks) > 1 or len(battles) > 1:
        raise ValueError('a group has at most one BARRACKS and one BATTLE region')
    if battles and not barracks:
        raise ValueError('a BATTLE region needs a BARRACKS region in its group')
    if any(r['id'] == mainland for r in battles):
        raise ValueError('the mainland cannot be a BATTLE region')
    for key, low, high, default in (('save_minutes', 0, 1440, 15), ('travel_save_seconds', 10, 3600, 60)):
        value = group.setdefault(key, default)
        if type(value) is not int or not low <= value <= high:
            raise ValueError('%s must be a whole number from %d to %d' % (key, low, high))
    # Routing relay (scripts/gaia-host/relay.py): one public port for every region.
    # Players join the gate region directly; it (or any region sending a traveller)
    # writes a route for the player's address and links them to relay_port.
    relay = group.setdefault('relay_port', 0)
    if relay:
        if type(relay) is not int or not 1024 <= relay <= 65535 or relay in ports or relay in RESERVED_PORTS:
            raise ValueError('relay_port must be a free port from 1024 to 65535 (0 = off)')
        control = group.setdefault('relay_control_port', relay + 1)
        if type(control) is not int or not 1024 <= control <= 65535 or control in ports or control == relay:
            raise ValueError('relay_control_port must be a free port from 1024 to 65535')
        gate = group.setdefault('gate', mainland)
        if gate not in ids or any(r['id'] == gate and r['kind'] == 'RAID' for r in regions):
            raise ValueError('gate must be one of the region ids and not a RAID region')
        if type(group.setdefault('relay_bind', '0.0.0.0')) is not str or not group['relay_bind']:
            raise ValueError('relay_bind must be an address')
        if type(group.setdefault('relay_capture', False)) is not bool:
            raise ValueError('relay_capture must be true or false')
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
    # stage and handover refuse while the region's drive has less than this free: a handover
    # copies the build, writes a whole save and backs it up, and a full drive fails it midway.
    group.setdefault('min_free_disk_mb', DEFAULT_MIN_FREE_DISK_MB)
    if type(group['min_free_disk_mb']) is not int or group['min_free_disk_mb'] < 0:
        raise ValueError('min_free_disk_mb must be a whole number of MB, 0 or more')
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
    # Player Help ("Ask for help"): the host service keeps one bridge per listed region
    # running (scripts/player_help_bridge.py against that region's SQL/player-help spool).
    settings = group.get('player_help')
    if settings is not None:
        if type(settings) is not dict or type(settings.get('config')) is not str or not settings['config']:
            raise ValueError('player_help needs a config path')
        chosen = settings.setdefault('regions', [r['id'] for r in regions])
        if type(chosen) is not list or not chosen or len(set(map(str, chosen))) != len(chosen) or any(c not in ids for c in chosen):
            raise ValueError('player_help regions must be distinct region ids of the group')
    resolve_standby_ports(group)
    group['_path'] = str(Path(path).resolve())
    return group


def resolve_standby_ports(group):
    """Give every region a standby port no other port of the group uses.

    A handover boots the staged build on this port beside the running world. The default
    is port + 10, the next free port when that one is taken: on a group whose transfer
    ports are port + 10 (the live earth group) the plain default was the region's own
    transfer agent, so every handover was refused as "standby port in use"."""
    regions = group['regions']
    taken = {r['port'] for r in regions} | {r['transfer_port'] for r in regions if r.get('transfer_port')}
    if group.get('relay_port'):
        taken |= {group['relay_port'], group['relay_control_port']}
    taken.add(group.get('doorman_port', gaia_host.FREEZE_DEFAULTS['doorman_port']))
    for region in regions:
        standby = region.get('standby_port')
        if standby is None:
            continue
        if type(standby) is not int or not 1024 <= standby <= 65535 or standby in taken:
            raise ValueError('region %s standby_port must be a free port from 1024 to 65535 '
                             '(not a region, transfer, relay or doorman port of the group)' % region['id'])
        taken.add(standby)
    for region in regions:
        if region.get('standby_port') is not None:
            continue
        standby = region['port'] + STANDBY_PORT_OFFSET
        while standby in taken or standby in RESERVED_PORTS:
            standby += 1
        if standby > 65535:
            raise ValueError('region %s has no free standby port; set standby_port' % region['id'])
        region['standby_port'] = standby
        taken.add(standby)


def region_dir(group, region_id):
    return Path(group['root']) / region_id


def region_config(group, region):
    """The gaia_host-shaped config one region's host and worker run with."""
    path = region_dir(group, region['id'])
    # Behind the routing relay: the launcher offers only the gate region.
    routed = bool(group.get('relay_port')) and region['id'] != group.get('gate')
    # A routed region is reached only through the relay, and its own port stays closed on
    # the router, so a hub entry for it would point at a port nobody can join.
    public = region.get('public', group['public']) and not routed
    config = {'repository': str(path), 'port': region['port'], 'task': 'region:' + region['id'],
            'compiler': group['compiler'], 'daemon': group['daemon'], 'git': group['git'],
            'state_dir': str(path / 'data' / 'shard-host'), 'public': bool(public),
            'save_timeout_seconds': group['save_timeout_seconds'], 'start_timeout_seconds': group['start_timeout_seconds'],
            'backups_kept': group['backups_kept'], 'min_free_disk_mb': group['min_free_disk_mb'],
            'group_config': group['_path'], 'region': region['id'],
            'group': group['group'], 'python': group['python'], 'transfer_port': region.get('transfer_port'),
            'peers': [r['id'] for r in group['regions'] if r['id'] != region['id']],
            'systemd_scope': group.get('systemd_scope', ''),
            'routed': routed,
            'standby_port': region.get('standby_port'),
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


def transfer_code():
    """A fingerprint of the transfer helpers' source (agent, coordinator, radio, region).

    A helper keeps the code it started with, so one started before an update never
    learns new routes: the agents and coordinator of Nov 6 had no group OOC and
    dropped every line (Rail Yard, 2026-11-08). supervise() restarts a helper whose
    fingerprint differs from the source on disk."""
    digest = hashlib.sha256()
    for path in sorted(TRANSFER_TOOLS.glob('*.py')):
        digest.update(path.name.encode('utf-8') + b'\0' + path.read_bytes())
    return digest.hexdigest()[:16]


def read_record(path):
    try:
        record = json.loads(Path(path).read_text(encoding='utf-8'))
    except (OSError, ValueError):
        return {}
    return record if type(record) is dict else {}


def write_record(path, **values):
    Path(path).write_text(json.dumps(values, sort_keys=True) + '\n', encoding='utf-8')


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

    def start_task(self, name, dmb=DMB_SLOTS[0]):
        path = Path(self.config['repository'])
        (path / 'logs').mkdir(exist_ok=True)
        # The world must find its agent when it loads, so the agent starts first.
        self.start_agent()
        argv = [self.config['daemon'], dmb, str(self.config['port']), '-trusted', '-close',
                '-public' if self.config['public'] else '-invisible', '-log', 'logs/world.log']
        detach(scoped(argv, self.config), path, None)
        return 0, 'started'

    def start_standby(self, dmb, port):
        """Boot dmb as a standby world on a loopback control port: it loads the map and waits for the
        host to name the save (DM reads -params standby=1), hidden from the hub until it is opened."""
        path = Path(self.config['repository'])
        (path / 'logs').mkdir(exist_ok=True)
        self.start_agent()
        argv = [self.config['daemon'], dmb, str(port), '-trusted', '-close', '-invisible', '-log', STANDBY_LOG,
                '-params', 'standby=1']
        return detach(scoped(argv, self.config), path, None)

    def task_ready(self, name):
        return (Path(self.config['repository']) / 'region.dmb').exists()

    def agent_record(self):
        return Path(self.config['state_dir']) / 'agent.json'

    def listener_pids(self, port):
        """Every process listening on the port. Windows let several agents share one
        port (SO_REUSEADDR); Rail Yard had four on 1725, and any of them answered."""
        if os.name == 'nt':
            return sorted({row[3] for row in self.tcp_rows() if row[0] == port and row[2] == 'LISTENING'})
        pid = self.server_pid(port)
        return [pid] if pid else []

    def start_agent(self, refresh=False):
        """Start this region's transfer agent unless it already listens.

        With refresh, an agent that runs other code than the source on disk (or one this
        host did not start and record) is ended, with any duplicate on its port, and
        started again. Callers pass refresh only while no action or handover runs."""
        port = self.config.get('transfer_port')
        if not port:
            return False
        code = transfer_code()
        if self.listening(port):
            record = self.agent_record_now()
            if not refresh or (record.get('code') == code and self.listener_pids(port) in ([], [record.get('pid')])):
                return False
            for pid in self.listener_pids(port):
                self.terminate(pid)
            if self.listening(port):
                return False  # the next pass tries again
        path = Path(self.config['repository'])
        argv = [self.config['python'], str(TRANSFER_TOOLS / 'agent.py'), '--db', str(Path(self.config['state_dir']) / 'transfers.sqlite'),
                '--region', self.config['region'], '--group', self.config['group'], '--port', str(port),
                '--token-file', str(path / 'config' / 'transfer-token.txt')]
        for peer in self.config['peers']:
            argv += ['--enroll', peer + ':out', '--enroll', peer + ':in']
        Path(self.config['state_dir']).mkdir(parents=True, exist_ok=True)
        pid = detach(argv, path, Path(self.config['state_dir']) / 'agent.log')
        write_record(self.agent_record(), pid=pid, code=code)
        return True

    def agent_record_now(self):
        return read_record(self.agent_record())


class RegionHost(Host):
    def __init__(self, config, platform=None):
        super().__init__(config, platform or RegionPlatform(config), script=Path(__file__).resolve())
        self.stage_lock = self.state_dir / 'stage.lock'
        self.stage_file = self.state_dir / 'stage.json'
        self.staged_file = self.state_dir / 'staged.json'

    def status(self):
        report = super().status()
        stage = self.read_json(self.stage_file)
        if stage:
            report['stage'] = dict(stage, pending=self.update_pending())
        report['build'] = self.live_dmb_name()
        if self.lock.exists() and (self.read_state() or {}).get('action') == 'handover':
            port = self.standby_port()
            report['standby'] = {'port': port, 'listening': self.platform.listening(port)}
        return report

    def work(self, action, operation):
        if action == 'stage':
            return self.stage_work(operation)
        return super().work(action, operation)

    # -- staged builds -----------------------------------------------------------
    # stage builds the group revision in <root>/.staging/<id>, a second worktree, at
    # low priority while the region keeps running. The build is installed (two file
    # copies instead of a compile) by the next update of that revision: the host
    # service runs it as a restart once the world is empty and saved, or into a
    # sleeping world, which wakes on the new build.
    def stage_dir(self):
        return self.repo.parent / '.staging' / self.config['region']

    def stage_record(self, **values):
        state = self.read_json(self.stage_file) or {}
        state.update(values, updated=int(self.platform.now()))
        self.write_json(self.stage_file, state)

    def request_stage(self):
        if not (self.repo / '.git').exists():
            raise Refused('the region is not set up; run setup first')
        self.check_disk('staging checks out and compiles a whole build')
        self.state_dir.mkdir(parents=True, exist_ok=True)
        try:
            if self.platform.now() - self.stage_lock.stat().st_mtime > STAGE_LOCK_HOURS * 3600:
                self.stage_lock.unlink()
        except OSError:
            pass
        try:
            descriptor = os.open(self.stage_lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        except FileExistsError:
            raise Refused('a build is already being staged')
        operation = secrets.token_hex(16)
        with os.fdopen(descriptor, 'w') as handle:
            handle.write(operation)
        self.write_json(self.stage_file, {'operation': operation, 'phase': 'accepted', 'error': None,
                                          'updated': int(self.platform.now())})
        self.platform.detach([sys.executable, '-I', '-B', str(self.script), '--config', self.config['_path'],
                              '--worker', 'stage', operation])
        return {'accepted': True, 'action': 'stage', 'operation': operation}

    def staged_revision(self):
        """The revision of the ready staged build, or None (none, or its files changed since)."""
        record = self.read_json(self.staged_file)
        if not record or not HEX40.match(str(record.get('revision'))):
            return None
        try:
            stat = (self.stage_dir() / 'region.dmb').stat()
        except OSError:
            return None
        return record['revision'] if record.get('dmb') == [stat.st_size, stat.st_mtime_ns] else None

    def update_pending(self):
        staged = self.staged_revision()
        if not staged:
            return False
        built = self.built_revision()
        if staged == built:
            return False
        if built is None:
            return True
        # Never go back: a build updated by hand past the staged one leaves it unused.
        code, _ = self.platform.run([self.config['git'], 'merge-base', '--is-ancestor', built, staged],
                                    cwd=self.repo, timeout=60)
        return code == 0

    @contextlib.contextmanager
    def compile_slot(self, wait_seconds=7200):
        """One staged compile per group at a time, so a deploy never compiles every region at once."""
        with self.group_slot('compile.lock', 'compile', self.stage_record, wait_seconds):
            yield

    @contextlib.contextmanager
    def handover_slot(self, wait_seconds=7200):
        """One handover per group at a time: two Gaias loading at once would not fit in memory."""
        with self.group_slot('handover.lock', 'handover', self.record, wait_seconds):
            yield

    @contextlib.contextmanager
    def group_slot(self, name, what, record, wait_seconds):
        lock = self.repo.parent / '.staging' / name
        lock.parent.mkdir(parents=True, exist_ok=True)
        deadline = self.platform.now() + wait_seconds
        while True:
            try:
                descriptor = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
                break
            except FileExistsError:
                try:
                    holder = int(lock.read_text(encoding='utf-8').strip() or 0)
                except (OSError, ValueError):
                    holder = 0
                if not holder or not self.platform.alive(holder):
                    lock.unlink(missing_ok=True)
                    continue
                if self.platform.now() > deadline:
                    raise RuntimeError('another region kept the %s slot busy too long' % what)
                record(phase='waiting for another region\'s %s' % what)
                self.platform.sleep(10)
        with os.fdopen(descriptor, 'w') as handle:
            handle.write(str(os.getpid()))
        try:
            yield
        finally:
            lock.unlink(missing_ok=True)

    def stage_work(self, operation):
        try:
            if self.stage_lock.read_text().strip() != operation:
                return
        except OSError:
            return
        try:
            self.stage_record(phase='checking for updates', error=None)
            latest = self.latest_revision()
            if not HEX40.match(latest):
                raise RuntimeError('could not read the latest revision')
            if self.built_revision() == latest:
                self.stage_record(phase='current', revision=latest)
                return
            if self.staged_revision() == latest:
                self.stage_record(phase='ready', revision=latest)
                return
            group = load_group(self.config['group_config'])
            region = next(r for r in group['regions'] if r['id'] == self.config['region'])
            path = self.stage_dir()
            with self.compile_slot():
                if not (path / '.git').exists():
                    if path.exists() and any(path.iterdir()):
                        raise RuntimeError('%s exists and is not a staging worktree' % path)
                    path.parent.mkdir(parents=True, exist_ok=True)
                    code, out = self.platform.run([self.config['git'], 'worktree', 'add', '--detach', str(path), latest],
                                                  cwd=group['repository'], timeout=600)
                    if code != 0:
                        raise RuntimeError('staging worktree failed: ' + out.strip()[-300:])
                self.stage_record(phase='preparing', revision=latest)
                self.staged_file.unlink(missing_ok=True)
                prepare_tree(group, region, path, latest, self.platform, self.config['git'])
                self.stage_record(phase='compiling')
                before = dmb_mtime(path / 'region.dmb')
                code, out = self.platform.run([self.config['compiler'], 'region.dme'], cwd=path, timeout=1800,
                                              low_priority=True)
                if not compile_succeeded(code, out, path / 'region.dmb', before):
                    raise RuntimeError('compile failed: ' + out.strip()[-300:])
                stat = (path / 'region.dmb').stat()
                self.write_json(self.staged_file, {'revision': latest, 'dmb': [stat.st_size, stat.st_mtime_ns],
                                                   'staged_at': int(self.platform.now())})
            self.stage_record(phase='ready', revision=latest)
        except Exception as error:  # stage.json is the only place a detached worker can report
            self.stage_record(phase='failed', error=str(error)[:500])
        finally:
            self.stage_lock.unlink(missing_ok=True)

    def install_staged(self, revision):
        """Copy the staged build of revision into the region; False when there is none."""
        if self.staged_revision() != revision:
            return False
        source = self.stage_dir()
        for name in STAGED_OUTPUTS:
            if (source / name).is_file():
                temporary = self.repo / (name + '.staged')
                shutil.copy2(source / name, temporary)
                os.replace(temporary, self.repo / name)
        return True

    def request(self, action):
        # Checked before the lock: taking it would create the folder setup needs empty.
        if action in ('start', 'restart', 'update', 'handover') and not (self.repo / '.git').exists():
            raise Refused('the region is not set up; run setup first')
        if action == 'update' and self.platform.listening(self.config['port']):
            raise Refused('stop the region before updating')
        return super().request(action)

    def precheck(self, action):
        # start compiles a missing or stale build itself (Host.do_refresh), so a
        # region with no build yet is not refused.
        if action == 'handover':
            return self.precheck_handover()
        super().precheck(action)

    def task_ready_for_start(self):
        return True

    def start_task(self):
        return self.platform.start_task(self.config['task'], dmb=self.live_dmb_name())

    # -- build slots -------------------------------------------------------------
    def live_dmb_name(self):
        """The .dmb the region runs (or starts) from: build.json's 'file', else region.dmb."""
        record = self.read_json(self.build_file()) or {}
        name = record.get('file')
        return name if name in DMB_SLOTS else DMB_SLOTS[0]

    def spare_dmb_name(self):
        return DMB_SLOTS[1] if self.live_dmb_name() == DMB_SLOTS[0] else DMB_SLOTS[0]

    def dmb(self):
        return self.repo / self.live_dmb_name()

    def standby_port(self):
        port = self.config.get('standby_port')
        if port:
            return int(port)
        # A host.json written before standby ports were resolved has none: ask the group,
        # which knows every other port the region's standby must not take.
        try:
            group = load_group(self.config['group_config'])
            return int(next(r['standby_port'] for r in group['regions'] if r['id'] == self.config['region']))
        except (OSError, ValueError, KeyError, StopIteration, TypeError):
            return self.config['port'] + STANDBY_PORT_OFFSET

    # -- handover: a staged build takes over the running world without downtime -------
    # The staged build boots beside the running world on a loopback port and waits. The
    # old world freezes play, saves and publishes its restart intent; the standby loads that
    # save (its load is the validation); then the old world reboots out (-close) and the
    # standby opens the region's port as well, so players reconnect to the same address. A
    # failure anywhere before the switch stops the standby and the old world carries on.
    def precheck_handover(self):
        if self.frozen():
            raise Refused('the region is asleep; it gets the staged build on its next wake')
        if not self.platform.listening(self.config['port']):
            raise Refused('the region is not running; start installs the staged build')
        if not self.token():
            raise Refused('config/lifecycle-token.txt is missing, so the world cannot be asked to save')
        staged = self.staged_revision()
        if not staged:
            raise Refused('no staged build is ready; run stage first')
        if not self.update_pending():
            raise Refused('the region already runs the staged build')
        world = self.world()
        if not world:
            raise Refused('the world does not answer lifecycle status')
        if world.get('busy') or not world.get('ready'):
            raise Refused('the world is busy or not ready, so it cannot save now')
        if self.platform.listening(self.standby_port()):
            raise Refused('port %d (the standby port) is in use' % self.standby_port())
        free = self.platform.free_memory_mb()
        if free is not None and free < self.config['cold_start_min_free_mb']:
            raise Refused('only %d MB free; a standby world needs %d MB to load beside the running one'
                          % (free, self.config['cold_start_min_free_mb']))
        self.check_disk('a handover copies the build and writes and backs up a whole save')

    def check_disk(self, why):
        """Refuse while the region's drive is nearly full (min_free_disk_mb, 0 turns it off)."""
        need = self.config.get('min_free_disk_mb', DEFAULT_MIN_FREE_DISK_MB)
        measure = getattr(self.platform, 'free_disk_mb', None)
        free = measure(str(self.repo.parent)) if need and measure else None
        if free is not None and free < need:
            raise Refused('only %d MB free on the disk; %s, so it needs %d MB (min_free_disk_mb)'
                          % (free, why, need))

    def do_handover(self, operation):
        group = load_group(self.config['group_config'])
        region = next(r for r in group['regions'] if r['id'] == self.config['region'])
        revision = self.staged_revision()
        if not revision or not self.update_pending():
            raise RuntimeError('no staged build newer than the running one')
        port, spare_port, token = self.config['port'], self.standby_port(), self.token()
        before = self.world()
        if not token or not before:
            raise RuntimeError('the world does not answer lifecycle status')
        session = before.get('session', '')
        if not gaia_host.HEX32.match(session or ''):
            raise RuntimeError('the world gave no valid session')
        if self.platform.listening(spare_port):
            raise RuntimeError('port %d (the standby port) is in use' % spare_port)
        if 'handover' not in before:
            # The running build predates handovers (its status has no handover field), so it
            # cannot freeze and save for a standby: the first update onto a build that can is
            # the old save, stop, install and start, under this same action.
            self.record(phase='the running build predates handovers; saving, stopping and starting instead')
            with self.handover_slot():
                self.do_stop(operation)
                self.do_update(operation)
                self.do_start(operation)
            self.record(phase='restarted onto the staged build', revision=revision, staged=True, legacy=True)
            return
        with self.handover_slot():
            self.handover_work(operation, group, region, revision, port, spare_port, token, before, session)

    def handover_work(self, operation, group, region, revision, port, spare_port, token, before, session):
        if self.platform.listening(spare_port):
            raise RuntimeError('port %d (the standby port) is in use' % spare_port)
        spare = self.spare_dmb_name()
        self.record(phase='copying the staged build', revision=revision, build=spare, standby_port=spare_port)
        source = self.stage_dir()
        for name in STAGED_OUTPUTS:
            target = self.repo / (spare[:-4] + name[-4:])  # region.b.dmb, region.b.rsc
            temporary = self.repo / (target.name + '.staged')
            shutil.copy2(source / name, temporary)
            os.replace(temporary, target)
        self.record(phase='booting the standby')
        standby_pid = self.platform.start_standby(spare, spare_port)
        standby = self.wait_world(spare_port, token, lambda s: s.get('standby') == 'waiting',
                                 self.config['start_timeout_seconds'], 'the standby world did not boot', standby=True)
        standby_session = standby.get('session', '')
        if not gaia_host.HEX32.match(standby_session or ''):
            self.stop_standby(spare_port, standby_pid)
            raise RuntimeError('the standby world gave no valid session')
        generation = None
        try:
            self.record(phase='saving', clients=before.get('clients'))
            answer = self.platform.query(port, token, 'handover_save', operation, session)
            if answer.get('operation') != operation:
                raise RuntimeError('the world did not accept the save: %s' % (answer.get('error') or 'no operation in its reply'))
            self.wait_world(port, token, lambda s: s.get('handover') == 'saved', self.config['save_timeout_seconds'],
                            'the save did not finish in time; the world was left running')
            self.record(phase='backing up')
            saves = self.repo / 'map_saves'
            for _ in range(30):
                if not any(p.name.endswith('.lk') for p in saves.iterdir()):
                    break
                self.platform.sleep(2)
            generation = gaia_host.check_save(saves)
            backups = self.state_dir / 'backups'
            gaia_host.copy_save(saves, backups / operation)
            kept = sorted((p for p in backups.iterdir() if p.is_dir()), key=lambda p: p.stat().st_mtime)
            for old in kept[:-self.config['backups_kept']]:
                shutil.rmtree(old)
            self.record(phase='loading the standby', generation=generation, backup=str(backups / operation))
            answer = self.platform.query(spare_port, token, 'standby_load', operation, standby_session)
            if answer.get('operation') != operation:
                raise RuntimeError('the standby world did not accept the load: %s' % (answer.get('error') or 'no operation in its reply'))
            self.wait_world(spare_port, token, lambda s: s.get('ready') and not s.get('restart_hold'),
                            self.config['load_timeout_seconds'], 'the standby world did not load the save in time',
                            standby=True)
        except Exception as error:
            # The old world is still running: stop the standby and release the freeze.
            self.record(phase='rolling back', error=str(error)[:500])
            self.stop_standby(spare_port, standby_pid)
            try:
                self.platform.query(port, token, 'handover_cancel', operation, session)
            except (OSError, RuntimeError, ValueError):
                pass
            raise
        # The switch: from here the standby is the region.
        self.record(phase='switching')
        self.platform.query(port, token, 'handover_release', operation, session)
        # world.OpenPort on a port another process still holds fails and closes the standby's
        # own port (measured on 516.1688), so the old world's port must be free first.
        deadline = self.platform.now() + SWITCH_SECONDS
        killed = False
        while self.platform.listening(port):
            if self.platform.now() > deadline:
                pid = self.platform.server_pid(port)
                if pid and not killed:
                    self.platform.kill_tree(pid)
                    killed = True
                    deadline = self.platform.now() + 30
                    continue
                raise RuntimeError('the old world kept port %d; the loaded standby still answers on port %d' % (port, spare_port))
            self.platform.sleep(2)
        # The region is offline from here until the standby opens its port, so keep trying for
        # a while. Each try uses the session the standby reports now: on 2026-11-08 every
        # standby_open after a live Gaia load was refused for a minute and the region stayed
        # down, then one sent with the session read back from its status succeeded at once.
        deadline = self.platform.now() + OPEN_SECONDS
        while True:
            try:
                current = self.platform.query(spare_port, token).get('session', '')
                if gaia_host.HEX32.match(current or ''):
                    standby_session = current
            except (OSError, RuntimeError, ValueError):
                pass
            try:
                self.platform.query(spare_port, token, 'standby_open', operation, standby_session, extra={'port': str(port)})
                break
            except (OSError, RuntimeError, ValueError) as error:
                if self.platform.now() > deadline:
                    raise RuntimeError('the new world did not open port %d (%s); it still answers on port %d' % (port, error, spare_port))
                self.platform.sleep(3)
        deadline = self.platform.now() + 60
        while not self.platform.listening(port):
            if self.platform.now() > deadline:
                raise RuntimeError('the new world did not open port %d; it still answers on port %d' % (port, spare_port))
            self.platform.sleep(2)
        self.mark_running()
        self.freeze_file.unlink(missing_ok=True)
        self.cold_file.unlink(missing_ok=True)
        watchdog = self.read_json(self.watchdog_file)
        if watchdog and watchdog.pop('gave_up', None):
            self.write_json(self.watchdog_file, watchdog)
        (self.repo / 'config' / 'lifecycle-revision.txt').write_text(revision + '\n', encoding='utf-8')
        self.record_build(revision, spare)
        self.record(phase='checking out', revision=revision)
        try:  # the sources beside the new build; the world itself needs nothing from them
            prepare_tree(group, region, self.repo, revision, self.platform, self.config['git'])
        except (OSError, RuntimeError) as error:
            self.record(checkout_warning=str(error)[:300])
        self.record(phase='handed over', revision=revision, generation=generation, build=spare, staged=True)

    def wait_world(self, port, token, done, timeout, what, standby=False):
        """Poll a world's lifecycle status until done(status) is true; its status.

        A status error fails at once, as does a world whose port closed. A status that
        does not answer (a busy load) only counts against the timeout."""
        now = self.platform.now()
        deadline = now + timeout
        grace = now + 30 if standby else now  # a standby's port opens a moment after its process starts
        while True:
            status = None
            if self.platform.listening(port):
                try:
                    status = self.platform.query(port, token)
                except (OSError, RuntimeError, ValueError):
                    status = None
            elif self.platform.now() > grace:
                raise RuntimeError('%s: the %s is not listening' % (what, 'standby world' if standby else 'world'))
            if status:
                if status.get('error'):
                    raise RuntimeError('%s: %s' % (what, status['error']))
                if done(status):
                    return status
            if self.platform.now() > deadline:
                raise RuntimeError(what)
            self.platform.sleep(5)

    def stop_standby(self, port, pid=None):
        pid = self.platform.server_pid(port) or pid
        if pid:
            try:
                self.platform.kill_tree(pid)
            except OSError:  # already gone
                pass
        return pid

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
        prepare_tree(group, region, path, revision, self.platform, git)
        if self.platform.listening(self.config['port']):
            raise RuntimeError('the region started during the update; not compiling')
        if self.install_staged(revision):
            self.record_build(revision, DMB_SLOTS[0])
            self.record(phase='compiled', revision=revision, map=region['map'], staged=True)
            return
        self.record(phase='compiling', revision=revision)
        before = dmb_mtime(path / 'region.dmb')
        code, out = self.platform.run([self.config['compiler'], 'region.dme'], cwd=path, timeout=1800)
        if not compile_succeeded(code, out, path / 'region.dmb', before):
            raise RuntimeError('compile failed: ' + out.strip()[-300:])
        self.record_build(revision, DMB_SLOTS[0])
        self.record(phase='compiled', revision=revision, map=region['map'])


def dmb_mtime(path):
    try:
        return path.stat().st_mtime_ns
    except OSError:
        return None


def compile_succeeded(code, out, dmb, before):
    """A clean compile: '0 errors' and a .dmb written by it. DreamMaker 516.1688 can crash on
    exit ("double free or corruption") after saving a clean build; that non-zero exit counts
    as success when the output reports the saved .dmb with 0 errors."""
    if '0 errors' not in (out or '') or dmb_mtime(dmb) is None:
        return False
    if code == 0:
        return True
    return dmb_mtime(dmb) != before and bool(re.search(r'\.dmb - 0 errors', out))


def prepare_tree(group, region, path, revision, platform, git):
    """Check a region's worktree (or its staging worktree) out at revision and write
    everything its compile needs: overlays, the persistent config, rust_g and region.dme."""
    # --force: the region's config/config.txt override below is rewritten every update.
    code, out = platform.run([git, 'checkout', '--force', '--detach', revision], cwd=path, timeout=600)
    if code != 0:
        raise RuntimeError('checkout failed: ' + out.strip()[-300:])
    apply_overlays(group, region, path)
    (path / 'config').mkdir(exist_ok=True)
    if group['persistent']:
        persistent_config(path / 'config' / 'config.txt', saving=not region.get('reset_minutes'))
    if group.get('rust_g'):
        shutil.copyfile(group['rust_g'], path / Path(group['rust_g']).name)
    include = place_map(group, region, path)
    dme = (path / 'civ13.dme').read_text(encoding='utf-8')
    (path / 'region.dme').write_text(selected_map_dme(dme, include), encoding='utf-8', newline='')


def apply_overlays(group, region, path):
    """Copy the group's overlay folder, then the region's, over the region's worktree.

    An overlay holds what git does not: config/host.txt, native DLLs and their
    settings, and config/config.local.txt, the host's own lines for config/config.txt
    (see merge_config). It is copied after every checkout, so a forced checkout
    never loses it. A file whose copy already matches is left alone, so a DLL a
    running world has loaded is not rewritten. Returns the copied paths.
    """
    copied, local = [], []
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
            if relative.as_posix() == LOCAL_CONFIG:
                local.append(item)
                continue
            if KEPT_COPY.search(item.name):
                continue  # the launcher's and config-migrate's kept copies stay in the overlay
            target = path / relative
            if target.is_file() and filecmp.cmp(item, target, shallow=False):
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            try:
                shutil.copy2(item, target)
            except PermissionError:
                raise RuntimeError('%s is in use (is the region running?); stop it and try again' % relative.as_posix())
            copied.append(relative.as_posix())
    if local:
        config = path / 'config' / 'config.txt'
        text = config.read_text(encoding='utf-8') if config.exists() else ''
        for item in local:
            try:
                text = merge_config(text, item.read_text(encoding='utf-8-sig'))
            except ValueError as error:
                raise RuntimeError('%s: %s' % (item, error))
        config.parent.mkdir(parents=True, exist_ok=True)
        config.write_text(text, encoding='utf-8')
        copied.append(LOCAL_CONFIG)
    return copied


def config_key(line):
    """The setting a config.txt line sets, as config.load reads it (upper case), or None."""
    line = line.strip()
    if not line or line.startswith('#'):
        return None
    return line.split(' ', 1)[0].upper()


def commented_key(line):
    """The setting a commented-out config.txt line would set ("#WEBHOOK_KEY"), or None.
    Prose comments ("# text", "## text") have a space or a second # after the first."""
    line = line.strip()
    if not line.startswith('#') or not CONFIG_NAME.match(line[1:].split(' ', 1)[0]):
        return None
    return line[1:].split(' ', 1)[0].upper()


def merge_config(base, overrides):
    """Apply a host's config.local.txt to the repository's config.txt.

    Each line of overrides is one of:
      KEY value / KEY  set the setting: replaces its active line, else uncomments its
                       commented line, else is added at the end;
      #KEY             turn the setting off: comments out its active lines;
      blank, "# text"  ignored (comments).
    Everything the host does not name keeps the repository's value, so new settings
    and changed defaults on master still arrive.
    """
    lines = base.splitlines()
    added = []
    for raw in overrides.splitlines():
        text = raw.strip()
        if not text:
            continue
        if text.startswith('#'):
            key = commented_key(text)
            if key is None or ' ' in text:
                continue  # a comment
            lines = ['#' + line.strip() if config_key(line) == key else line for line in lines]
            added = [line for line in added if config_key(line) != key]
            continue
        key = text.split(' ', 1)[0]
        if not CONFIG_NAME.match(key):
            raise ValueError('%r is not a config setting line' % raw)
        key = key.upper()
        active = [i for i, line in enumerate(lines) if config_key(line) == key]
        if active:
            lines[active[0]] = text
            for i in active[1:]:
                lines[i] = '#' + lines[i].strip()
            continue
        if any(config_key(line) == key for line in added):
            added = [text if config_key(line) == key else line for line in added]
            continue
        commented = next((i for i, line in enumerate(lines) if commented_key(line) == key), None)
        if commented is not None:
            lines[commented] = text
        else:
            added.append(text)
    if added:
        lines += ['', '## Host settings (config.local.txt)'] + added
    return '\n'.join(lines) + '\n'


def active_settings(text):
    """config.txt's active lines by setting (the first one config.load acts on last wins, as merge keeps one)."""
    settings = {}
    for line in text.splitlines():
        key = config_key(line)
        if key:
            settings[key] = line.strip()
    return settings


def overrides_for(base, full):
    """The config.local.txt lines that turn base (the repository's config.txt) into full
    (a whole config.txt an overlay used to carry). Comments are not compared."""
    want, have = active_settings(full), active_settings(base)
    lines = [want[key] for key in want if have.get(key) != want[key]]
    lines += ['#' + key for key in have if key not in want]
    return lines


def migrate_config(group, platform=None):
    """Turn each overlay's whole config/config.txt into a config/config.local.txt that
    holds only its differences from the repository's config.txt at the group revision.
    The old file is kept beside it as config.txt.migrated. Refuses an overlay that
    already has a config.local.txt, or whose result would not reproduce its settings."""
    platform = platform or Platform()
    code, out = platform.run([group['git'], 'rev-parse', group['revision']], cwd=group['repository'], timeout=60)
    revision = out.strip().splitlines()[-1] if code == 0 and out.strip() else ''
    if not HEX40.match(revision):
        raise Refused('could not resolve the group revision')
    shown = subprocess.run([group['git'], 'show', revision + ':config/config.txt'], cwd=group['repository'],
                           stdin=subprocess.DEVNULL, capture_output=True, timeout=60)
    if shown.returncode != 0:
        raise Refused('could not read config/config.txt at %s' % revision)
    base = shown.stdout.decode('utf-8')
    done, refused = {}, {}
    sources = [group.get('overlay')] + [r.get('overlay') for r in group['regions']]
    for source in dict.fromkeys(s for s in sources if s):
        full, local = Path(source) / 'config' / 'config.txt', Path(source) / LOCAL_CONFIG
        if not full.is_file():
            continue
        if local.exists():
            refused[source] = '%s already exists' % LOCAL_CONFIG
            continue
        text = full.read_text(encoding='utf-8-sig')
        lines = overrides_for(base, text)
        try:
            reproduced = active_settings(merge_config(base, '\n'.join(lines))) == active_settings(text)
        except ValueError:
            reproduced = False
        if not reproduced:
            refused[source] = 'the overrides would not reproduce config.txt; move it by hand'
            continue
        header = ['# Host settings merged over the repository config/config.txt on every update',
                  '# (scripts/shard-group/README.md). "KEY value" sets, "#KEY" turns a setting off.']
        local.write_text('\n'.join(header + lines) + '\n', encoding='utf-8')
        os.replace(full, full.with_name('config.txt.migrated'))  # KEPT_COPY: not copied into regions
        done[source] = lines
    return {'revision': revision, 'done': done, 'refused': refused}


def apply_config(group, region_id=None, platform=None):
    """Write the overlays and config.local.txt into set-up regions without a checkout
    or compile. The region's config/config.txt is first restored from its checkout.
    A world reads config.txt when it starts, so the change takes effect at its next
    restart; host.txt is read at each login."""
    platform = platform or Platform()
    chosen = [r for r in group['regions'] if region_id in (None, r['id'])]
    if not chosen:
        raise Refused('no region %s in the group' % region_id)
    done, refused = {}, {}
    for region in chosen:
        path = region_dir(group, region['id'])
        if not (path / '.git').exists():
            refused[region['id']] = 'the region is not set up; run setup first'
            continue
        code, out = platform.run([group['git'], 'checkout', '--force', 'HEAD', '--', 'config/config.txt'], cwd=path, timeout=120)
        if code != 0:
            refused[region['id']] = 'could not restore config/config.txt: ' + out.strip()[-300:]
            continue
        try:
            copied = apply_overlays(group, region, path)
            if group['persistent']:
                persistent_config(path / 'config' / 'config.txt', saving=not region.get('reset_minutes'))
        except (RuntimeError, OSError) as error:
            refused[region['id']] = str(error)
            continue
        done[region['id']] = {'copied': copied, 'running': platform.listening(region['port'])}
    return done, refused


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
            skip = ADOPT_SKIP.get(name, ())
            shutil.copytree(item, target / name, dirs_exist_ok=True,
                            ignore=lambda folder, names: [n for n in names if Path(folder) == item and n in skip])
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


def voted_battle_map(group, region, path):
    """The include for a BATTLE region's last voted map, or None.

    The map vote's winner is built by battle_mapswap.py, which records it in the
    region's data/shard-host/rotation.json. Any later update (a start after master
    moved, a watchdog restart, a staged build) builds that map again instead of the
    configured one, so a voted or admin-picked map is not lost to a rebuild."""
    if region.get('kind') != 'BATTLE':
        return None
    try:
        state = json.loads((region_dir(group, region['id']) / 'data' / 'shard-host' / 'rotation.json').read_text(encoding='utf-8'))
    except (OSError, ValueError):
        return None
    if not isinstance(state, dict) or state.get('state') not in ('ready', 'building'):
        return None
    map_id = state.get('map')
    if type(map_id) is not str or not re.match(r'^[A-Za-z0-9_]{1,64}$', map_id):
        return None
    wanted = map_id.lower() + '.dmm'
    files = sorted(p for p in (path / 'maps').rglob('*.dmm') if p.is_file())
    # As battle_mapswap.find_map: the exact name first, then a partial match.
    found = next((p for p in files if p.name.lower() == wanted), None) or next((p for p in files if wanted in p.name.lower()), None)
    return str(found.relative_to(path)).replace('/', '\\') if found else None


def place_map(group, region, path=None):
    """Return the region.dme include for the region's map, copying an outside map into the worktree."""
    path = path or region_dir(group, region['id'])
    voted = voted_battle_map(group, region, path)
    if voted:
        return voted
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


def setup(group, platform=None, region_id=None):
    """Create each region's worktree and write its config. Refuses while any region is running.

    With region_id, adds or refreshes that one region while the others keep
    running: only it must be stopped and only it gets a new worktree. Every set-up
    region's config is rewritten so it lists the new peer, and existing transfer
    agents and the coordinator enrol it in their stores (see enrol_region). A running
    world reads its config only at startup, so it learns the new region on its next start.
    """
    platform = platform or Platform()
    if region_id is not None and not any(r['id'] == region_id for r in group['regions']):
        raise Refused('no region %s in the group' % region_id)
    git, repository = group['git'], group['repository']
    code, out = platform.run([git, 'rev-parse', group['revision']], cwd=repository, timeout=60)
    revision = out.strip().splitlines()[-1] if code == 0 and out.strip() else ''
    if not HEX40.match(revision):
        raise Refused('could not resolve the group revision')
    running = []
    for region in group['regions']:
        if platform.listening(region['port']):
            if region_id is None or region['id'] == region_id:
                raise Refused('region %s is running; stop it before setup' % region['id'])
            running.append(region['id'])
    Path(group['root']).mkdir(parents=True, exist_ok=True)
    made = []
    for region in group['regions']:
        path = region_dir(group, region['id'])
        if region_id is not None and region['id'] != region_id and not (path / '.git').exists():
            continue  # another region not set up yet: left for a full setup
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
        if group['relay_port']:
            settings.update(relay_settings(group))
            (config / 'relay-token.txt').write_text(relay_token(group) + '\n', encoding='utf-8')
        (config / 'shard_region.json').write_text(json.dumps(settings, indent=1) + '\n', encoding='utf-8')
        if any(r['kind'] == 'BARRACKS' for r in group['regions']) and region['kind'] in ('BARRACKS', 'BATTLE'):
            (config / 'tdm-token.txt').write_text(group_token(group, 'tdm-token.txt') + '\n', encoding='utf-8')
        if region['kind'] == 'BATTLE':
            # What scripts/shard-group/battle_mapswap.py needs to build the next voted map.
            build = {'root': str(Path(group['root']).resolve()), 'region': region['id'], 'git': group['git'],
                     'compiler': group['compiler']}
            (config / 'shard_build.json').write_text(json.dumps(build, indent=1) + '\n', encoding='utf-8')
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
        write_json_atomic(Path(host['_path']), host)
    result = {'revision': revision, 'created': made, 'regions': [r['id'] for r in group['regions']]}
    if region_id is not None:
        result['region'] = region_id
        result['running'] = running  # their worlds pick up the new peer list on their next start
        result['enrolled'] = enrol_region(group, region_id) if group['transfers'] else []
        if group['relay_port']:
            result['relay_ports'] = relay_add_ports(group)
    return result


def relay_add_ports(group, send=None):
    """Tell a running relay every game port of the group, so it routes to a region added
    while it runs (it reads --region-port only when it starts). Returns the ports it took,
    or None when no relay answers (the next relay the host service starts gets them all)."""
    if send is None:
        import doorman
        send = doorman.topic
    token, taken = relay_token(group), []
    for region in group['regions']:
        try:
            reply = json.loads(send(group['relay_control_port'], 'add_port=1&port=%d&token=%s' % (region['port'], token)))
        except (OSError, RuntimeError, ValueError):
            return None
        if isinstance(reply, dict) and reply.get('ok'):
            taken.append(region['port'])
    return taken


def write_json_atomic(path, value):
    """Write value as JSON through a temporary file, so a reader never sees half a file."""
    temporary = path.with_name(path.name + '.tmp')
    temporary.write_text(json.dumps(value, indent=1) + '\n', encoding='utf-8')
    os.replace(temporary, path)


def enrol(group, region_id):
    """Enrol an already set-up region with the existing agents and coordinator.

    For a region added while the agents and coordinator kept running, before setup
    enrolled new regions itself. Safe while everything runs, and safe to repeat.
    """
    if not any(r['id'] == region_id for r in group['regions']):
        raise Refused('no region %s in the group' % region_id)
    if not group['transfers']:
        raise Refused('this group has no transfers')
    if not (region_dir(group, region_id) / 'config' / 'transfer-token.txt').exists():
        raise Refused('region %s is not set up; run setup first' % region_id)
    return {'region': region_id, 'enrolled': enrol_region(group, region_id)}


def enrol_region(group, region_id):
    """Enrol region_id in the stores of agents and the coordinator that already exist.

    Running agents and the coordinator read their enrolments from SQLite on every
    transfer and relay pass, so writing to their stores lets them carry the new
    region's transfers without a restart. Stores not made yet enrol it when their
    process first starts. Returns the stores written, as region ids and "coordinator".
    """
    if str(TRANSFER_TOOLS.parents[1]) not in sys.path:
        sys.path.insert(0, str(TRANSFER_TOOLS.parents[1]))
    from tools.transfer_storage.coordinator import Coordinator
    from tools.transfer_storage.region import RegionStore
    enrolled = []
    for region in group['regions']:
        if region['id'] == region_id:
            continue
        store_path = Path(region_config(group, region)['state_dir']) / 'transfers.sqlite'
        if not store_path.exists():
            continue
        store = RegionStore(str(store_path), region['id'], group['group'])
        try:
            store.enroll(region_id, 'out')
            store.enroll(region_id, 'in')
        finally:
            store.close()
        enrolled.append(region['id'])
    coordinator_path = Path(group['root']) / 'coordinator.sqlite'
    if coordinator_path.exists():
        region = next(r for r in group['regions'] if r['id'] == region_id)
        token = (region_dir(group, region_id) / 'config' / 'transfer-token.txt').read_text(encoding='utf-8').strip()
        coordinator = Coordinator(str(coordinator_path), group['group'], group['mainland'])
        try:
            coordinator.enroll(region_id, 'http://127.0.0.1:%d' % region['transfer_port'], token)
        finally:
            coordinator.close()
        enrolled.append('coordinator')
    return enrolled


def relay_token(group):
    """The group's relay control token (root/relay-token.txt), made on first use."""
    return group_token(group, 'relay-token.txt')


def group_token(group, name):
    """A token every region of the group shares (root/<name>), made on first use."""
    path = Path(group['root']) / name
    if not path.exists():
        Path(group['root']).mkdir(parents=True, exist_ok=True)
        path.write_text(secrets.token_hex(24) + '\n', encoding='utf-8')
    return path.read_text(encoding='utf-8').strip()


def relay_settings(group):
    """The shard_region.json keys a region needs to send players through the relay."""
    return {'relay': '%s:%d' % (group['public_host'], group['relay_port']),
            'relay_control': '127.0.0.1:%d' % group['relay_control_port'], 'gate': group['gate']}


def relay_pid(group):
    try:
        pid = int((Path(group['root']) / 'relay.pid').read_text(encoding='utf-8').strip())
    except (OSError, ValueError):
        return None
    return pid if process_alive(pid) else None


def ensure_relay(group, start=detach):
    """Start the group's routing relay unless it is off or already runs."""
    if not group.get('relay_port') or relay_pid(group):
        return False
    root = Path(group['root'])
    relay_token(group)
    argv = [group['python'], str(HERE.parent / 'gaia-host' / 'relay.py'), '--port', str(group['relay_port']),
            '--bind', group['relay_bind'], '--control-port', str(group['relay_control_port']),
            '--token-file', str(root / 'relay-token.txt'),
            '--doorman-port', str(group.get('doorman_port', gaia_host.FREEZE_DEFAULTS['doorman_port']))]
    for region in group['regions']:
        argv += ['--region-port', str(region['port'])]
    if group['relay_capture']:
        argv.append('--capture')
    pid = start(argv, root, root / 'relay.log')
    (root / 'relay.pid').write_text('%d\n' % pid, encoding='utf-8')
    return True


def hosts(group, only=None, platform=None):
    chosen = [r for r in group['regions'] if only in (None, r['id'])]
    if not chosen:
        raise Refused('no region %s in the group' % only)
    return [(r, RegionHost(region_config(group, r), platform)) for r in chosen]


def region_view(port, timeout=10):
    """Ask a running region what it is and how it sees its peers (shard_region topic)."""
    try:
        with socket.create_connection(('127.0.0.1', port), timeout=timeout) as connection:
            connection.sendall(frame_query(b'shard_region=1&format=json&peers=1'))
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


def ensure_coordinator(group, start=detach, refresh=False, terminate=None):
    """Start the group's relay between region agents unless it already runs.

    With refresh, a coordinator started on other code than the source on disk is
    ended and started again (see transfer_code)."""
    if not group['transfers']:
        return False
    root = Path(group['root'])
    code = transfer_code()
    pid = coordinator_pid(group)
    if pid:
        if not refresh or read_record(root / 'coordinator.json').get('code') == code:
            return False
        (terminate or Platform().terminate)(pid)
    argv = [group['python'], str(TRANSFER_TOOLS / 'coordinator.py'), '--db', str(root / 'coordinator.sqlite'), '--group', group['group'],
            '--mainland', group['mainland']]
    for region in group['regions']:
        token = region_dir(group, region['id']) / 'config' / 'transfer-token.txt'
        argv += ['--region', '%s=http://127.0.0.1:%d=%s' % (region['id'], region['transfer_port'], token)]
    pid = start(argv, root, root / 'coordinator.log')
    (root / 'coordinator.pid').write_text('%d\n' % pid, encoding='utf-8')
    write_record(root / 'coordinator.json', pid=pid, code=code)
    return True


def group_busy(group):
    """Whether a region runs an action or a handover: helpers are not restarted then,
    because the world saving or handing over talks to its agent."""
    root = Path(group['root'])
    if (root / '.staging' / 'handover.lock').exists():
        return True
    return any((Path(region_config(group, region)['state_dir']) / 'action.lock').exists() for region in group['regions'])


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


def help_dir(group):
    """Where the group keeps its Player Help bridge logs, pids and stop marker."""
    return Path(group['root']) / 'player-help'


def help_stop_file(group):
    """While this exists every bridge stays stopped (help-stop for the whole group)."""
    return help_dir(group) / 'stopped'


def help_region_file(group, region_id, kind):
    """<id>.off: that region's bridge is stopped on request (and is its --stop-file);
    <id>.on: a region outside player_help's "regions" was started on request."""
    return help_dir(group) / ('%s.%s' % (region_id, kind))


def help_spool(group, region_id):
    return region_dir(group, region_id) / 'SQL' / 'player-help'


def help_pid(group, region_id, now=time.time):
    """The region's running bridge, or None. The bridge's worker.lock names its pid; a
    bridge we started recently may still be loading its corpus before it takes the lock."""
    try:
        pid = int((help_spool(group, region_id) / 'worker.lock' / 'pid').read_text(encoding='ascii').strip())
        if pid > 0 and process_alive(pid):
            return pid
    except (OSError, ValueError):
        pass
    started = help_dir(group) / ('%s.pid' % region_id)
    try:
        pid = int(started.read_text(encoding='utf-8').strip())
        if pid > 0 and now() - started.stat().st_mtime < HELP_STARTING_SECONDS and process_alive(pid):
            return pid
    except (OSError, ValueError):
        pass
    return None


def clear_help_lock(group, region_id):
    """Remove a worker.lock left by a bridge that is gone (a reboot, a crash, a forced stop);
    a new bridge refuses to start while it exists."""
    lock = help_spool(group, region_id) / 'worker.lock'
    if lock.exists():
        (lock / 'pid').unlink(missing_ok=True)
        lock.rmdir()


def help_settings(group):
    settings = group.get('player_help')
    if not settings:
        raise Refused('player_help is not configured for this group')
    return settings


def help_wanted(group, region_id):
    """Whether the host service keeps this region's bridge running: a region of player_help's
    "regions" (every region by default) or one started on request, unless stopped on request."""
    settings = group.get('player_help')
    if not settings or help_stop_file(group).exists() or help_region_file(group, region_id, 'off').exists():
        return False
    return region_id in settings['regions'] or help_region_file(group, region_id, 'on').exists()


def ensure_help(group, start=detach):
    """Start a Player Help bridge for every wanted region (help_wanted) that has none.
    Returns the started region ids and per-region errors."""
    settings = group.get('player_help')
    started, errors = [], {}
    if not settings or help_stop_file(group).exists():
        return started, errors
    folder = help_dir(group)
    folder.mkdir(parents=True, exist_ok=True)
    for region in group['regions']:
        region_id = region['id']
        # One region that cannot start its bridge must not keep the others down.
        try:
            if not help_wanted(group, region_id) or help_pid(group, region_id):
                continue
            game = region_dir(group, region_id)
            bridge = game / 'scripts' / 'player_help_bridge.py'
            if not bridge.exists():
                raise OSError('%s is missing (run setup)' % bridge)
            clear_help_lock(group, region_id)
            # Each bridge watches its own region's stop file, so one region stops without the others.
            argv = [group['python'], '-I', str(bridge), '--game-root', str(game), '--config', settings['config'],
                    '--stop-file', str(help_region_file(group, region_id, 'off'))]
            pid = start(argv, game, folder / ('%s.log' % region_id))
            (folder / ('%s.pid' % region_id)).write_text('%d\n' % pid, encoding='utf-8')
            started.append(region_id)
        except OSError as error:
            errors[region_id] = str(error)[:300]
    return started, errors


def help_status(group, now=time.time):
    """Every region's bridge: whether it runs, is kept running (wanted), and how fresh its heartbeat (health.json) is."""
    settings = group.get('player_help')
    if not settings:
        return {'configured': False}
    regions = {}
    for region in group['regions']:
        region_id = region['id']
        pid = help_pid(group, region_id, now)
        entry = {'running': pid is not None, 'pid': pid, 'wanted': help_wanted(group, region_id),
                 'listed': region_id in settings['regions'], 'log': str(help_dir(group) / ('%s.log' % region_id))}
        health = help_spool(group, region_id) / 'health.json'
        try:
            answer = json.loads(health.read_text(encoding='utf-8'))
            entry['enabled'] = type(answer) is dict and answer.get('enabled') is True
            entry['heartbeat_age_seconds'] = max(0, int(now() - health.stat().st_mtime))
        except (OSError, ValueError):
            entry['enabled'] = False
        regions[region_id] = entry
    stopped = not any(entry['wanted'] for entry in regions.values())
    return {'configured': True, 'stopped': stopped, 'config': settings['config'], 'regions': regions}


def help_region_ids(group, region_id):
    ids = [r['id'] for r in group['regions']]
    if region_id is not None and region_id not in ids:
        raise Refused('no region %s in the group' % region_id)
    return ids if region_id is None else [region_id]


def help_start(group, start=detach, region_id=None):
    """Clear the stop requests (of every region, or one) and start the missing bridges now.
    One region outside player_help's "regions" is kept running from then on."""
    settings = help_settings(group)
    folder = help_dir(group)
    folder.mkdir(parents=True, exist_ok=True)
    ids = help_region_ids(group, region_id)
    stop_all = help_stop_file(group)
    if region_id is not None and stop_all.exists():
        # The whole group was stopped: keep the other regions stopped while this one starts.
        for other in help_region_ids(group, None):
            if other != region_id:
                help_region_file(group, other, 'off').write_text('stopped on request\n', encoding='utf-8')
    stop_all.unlink(missing_ok=True)
    for one in ids:
        help_region_file(group, one, 'off').unlink(missing_ok=True)
        if region_id is not None and one not in settings['regions']:
            help_region_file(group, one, 'on').write_text('started on request\n', encoding='utf-8')
    started, errors = ensure_help(group, start)
    return {'started': started, 'errors': errors}


def help_stop(group, timeout=HELP_STOP_SECONDS, sleep=time.sleep, clock=time.monotonic, kill=None, region_id=None):
    """Stop the bridges (of every region, or one) and keep them stopped until help-start.
    Bridges see their stop file and finish the answers they are writing; one that has not
    exited by the timeout (or was started with another stop file) is ended."""
    help_settings(group)
    help_dir(group).mkdir(parents=True, exist_ok=True)
    ids = help_region_ids(group, region_id)
    if region_id is None:
        help_stop_file(group).write_text('stopped on request\n', encoding='utf-8')
    for one in ids:
        help_region_file(group, one, 'off').write_text('stopped on request\n', encoding='utf-8')
        help_region_file(group, one, 'on').unlink(missing_ok=True)
    running = {r: help_pid(group, r) for r in ids}
    running = {r: pid for r, pid in running.items() if pid}
    stopped = sorted(running)
    deadline = clock() + timeout
    while running and clock() < deadline:
        sleep(1)
        running = {r: pid for r, pid in running.items() if process_alive(pid)}
    kill = kill or Platform().kill_tree
    for one, pid in running.items():
        kill(pid)
        clear_help_lock(group, one)
    for one in ids:
        (help_dir(group) / ('%s.pid' % one)).unlink(missing_ok=True)
    return {'stopped': stopped, 'forced': sorted(running)}


# -- outside save validator ---------------------------------------------------------
# A region's start skips the per-entry walk of its save when map_saves/validated.json
# vouches for the files on the running build. A handover or an ordinary save leaves
# only a structural record (or none), so the next start after a crash, a power loss or
# a restart without new code walked every entry in the world (Gaia: about 2.5 min).
# Between saves the supervisor copies the save and the region's build into a private
# folder and boots it there with -params validate_save=1 (code/modules/persistence/
# save_validator.dm): that world runs the full check, writes the record and ends. The
# record comes back only while the region's own files still match its checksums.
VALIDATOR_DIR = '.validator'
VALIDATOR_BUILD_FILES = ('civ13.dmb', 'region.dmb', 'region.b.dmb')  # persistence_build_identity() hashes these
VALIDATOR_HELPERS = ('savestream.dll', 'savestream_helper.exe', 'libsavestream.so', 'savestream_helper')
VALIDATOR_SKIPPED_SAVES = ('validated.json', 'restart_intent.json')
VALIDATOR_TIMEOUT_SECONDS = 3600
VALIDATOR_MIN_FREE_MB = 2560


def file_md5(path):
    digest = hashlib.md5()
    with open(path, 'rb') as handle:
        for block in iter(lambda: handle.read(1 << 20), b''):
            digest.update(block)
    return digest.hexdigest()


def save_generation(saves):
    """The generation of a completed save in saves, or None while there is none or a
    restart intent is pending (the world is saving, handing over or restoring)."""
    marker = saves / 'save_complete.txt'
    if (saves / 'restart_intent.json').exists() or not marker.exists():
        return None
    try:
        return marker.read_text(encoding='utf-8').strip() or None
    except OSError:
        return None


def full_record_for(saves, generation):
    record = read_record(saves / 'validated.json')
    return bool(record) and record.get('kind') == 'full' and record.get('generation') == generation


def save_snapshot(saves):
    """(name, size, mtime) of every save file the validator copies."""
    rows = []
    for path in sorted(saves.iterdir()):
        if path.is_file() and path.name not in VALIDATOR_SKIPPED_SAVES:
            stat = path.stat()
            rows.append((path.name, stat.st_size, stat.st_mtime_ns))
    return rows


def record_matches_saves(record, saves, generation):
    """Whether a validator record vouches for exactly the files now in saves."""
    files = record.get('files') if isinstance(record, dict) else None
    if record.get('kind') != 'full' or record.get('generation') != generation or not isinstance(files, dict) or not files:
        return False
    try:
        return all(file_md5(saves / name) == digest for name, digest in files.items())
    except OSError:
        return False


def validator_state_path(group):
    return Path(group['root']) / VALIDATOR_DIR / 'state.json'


def validator_argv(group, dmb):
    argv = [group['daemon'], dmb, '0', '-trusted', '-invisible', '-params', 'validate_save=1', '-log', 'validator.log']
    if os.name == 'nt':
        argv.insert(4, '-close')  # dd.exe would stay open after the world ends
    elif shutil.which('nice'):
        argv = ['nice', '-n', '10'] + argv  # the live worlds keep priority
    return argv


def prepare_validator(group, region_id, folder):
    """Copy region_id's completed save and build into folder. Returns the generation,
    or None when there is nothing to check or the save changed while it was copied."""
    path = region_dir(group, region_id)
    saves = path / 'map_saves'
    generation = save_generation(saves)
    if not generation or full_record_for(saves, generation):
        return None
    config = region_config(group, next(r for r in group['regions'] if r['id'] == region_id))
    live = read_record(Path(config['state_dir']) / 'build.json').get('file')  # RegionHost.live_dmb_name()
    live = live if live in DMB_SLOTS else DMB_SLOTS[0]
    if not (path / live).exists():
        return None
    if folder.exists():
        shutil.rmtree(folder)
    (folder / 'map_saves').mkdir(parents=True)
    before = save_snapshot(saves)
    for name, _size, _mtime in before:
        shutil.copy2(saves / name, folder / 'map_saves' / name)
    if save_snapshot(saves) != before or save_generation(saves) != generation:
        shutil.rmtree(folder)
        return None  # a save ran meanwhile; the next pass copies the new one
    for name in VALIDATOR_BUILD_FILES + VALIDATOR_HELPERS:
        if (path / name).exists():
            shutil.copy2(path / name, folder / name)
    rsc = live[:-4] + '.rsc'
    if (path / rsc).exists():
        shutil.copy2(path / rsc, folder / rsc)
    # The world reads its settings at boot; it never answers Topics, so no token is copied.
    if (path / 'config').is_dir():
        shutil.copytree(path / 'config', folder / 'config', ignore=shutil.ignore_patterns('*token*'))
    write_record(folder / 'validator.json', region=region_id, generation=generation, dmb=live)
    return generation


def finish_validator(group, state):
    """Read a finished validator's result; copy its record into the region if the region's
    files still match it. Returns the outcome."""
    folder = Path(state['dir'])
    saves = region_dir(group, state['region']) / 'map_saves'
    result = read_record(folder / 'validation_result.json')
    record = read_record(folder / 'map_saves' / 'validated.json')
    generation = state['generation']
    if not result.get('ok') or not result.get('full') or not record:
        outcome = 'failed: %s' % (result.get('error') or 'no result')[:300]
    elif save_generation(saves) != generation or not record_matches_saves(record, saves, generation):
        outcome = 'superseded'  # a newer save; the next pass checks that one
    elif full_record_for(saves, generation):
        outcome = 'already validated'
    else:
        temporary = saves / 'validated.json.validator'
        temporary.write_text(json.dumps(record), encoding='utf-8')
        os.replace(temporary, saves / 'validated.json')
        outcome = 'validated'
    shutil.rmtree(folder, ignore_errors=True)
    return outcome


def ensure_save_validation(group, start=None, free_mb=None, now=time.time, alive=None, terminate=None):
    """One step of the outside save validator. Returns what it did, or {} when idle."""
    if group.get('save_validator') is False:
        return {}
    alive = alive or process_alive
    state_path = validator_state_path(group)
    state = read_record(state_path)
    done = state.get('done') if isinstance(state.get('done'), dict) else {}
    if state.get('pid'):
        if alive(state['pid']):
            if now() - state.get('started', 0) < VALIDATOR_TIMEOUT_SECONDS:
                return {}
            (terminate or Platform().terminate)(state['pid'])
            outcome = 'failed: timed out'
            shutil.rmtree(state['dir'], ignore_errors=True)
        else:
            outcome = finish_validator(group, state)
        if outcome != 'superseded':
            done[state['region']] = {'generation': state['generation'], 'outcome': outcome, 'at': int(now())}
        write_record(state_path, done=done)
        return {'save_validation': {state['region']: outcome}}
    state_path.parent.mkdir(parents=True, exist_ok=True)
    if group_busy(group):
        return {}
    for region in group['regions']:
        saves = region_dir(group, region['id']) / 'map_saves'
        generation = save_generation(saves)
        if not generation or full_record_for(saves, generation):
            continue
        if (done.get(region['id']) or {}).get('generation') == generation:
            continue  # checked once already; a failure waits for the next save
        free = free_mb() if free_mb else Platform().free_memory_mb()
        if free is not None and free < int(group.get('save_validator_min_free_mb', VALIDATOR_MIN_FREE_MB)):
            return {}
        folder = Path(group['root']) / VALIDATOR_DIR / region['id']
        try:
            generation = prepare_validator(group, region['id'], folder)
        except (OSError, StopIteration) as error:
            shutil.rmtree(folder, ignore_errors=True)
            return {'save_validation_error': {region['id']: str(error)[:300]}}
        if not generation:
            continue
        dmb = read_record(folder / 'validator.json')['dmb']
        pid = (start or detach)(validator_argv(group, dmb), folder, folder / 'validator.out')
        write_record(state_path, done=done, pid=pid, region=region['id'], generation=generation, dir=str(folder), started=int(now()))
        return {'save_validation': {region['id']: 'started'}}
    return {}


def supervise(group, start=detach):
    """Start the group's routing relay, transfer agents, coordinator or Player Help bridges if any is not running.

    The host service calls this every half minute. Agents run even while their world
    sleeps or is cold, so travellers to it are journaled and handed over on wake.
    Returns what was started (empty when everything was already running).
    """
    started = {}
    # A relay that cannot start must not keep the agents and the coordinator down.
    try:
        if ensure_relay(group, start):
            started['relay'] = True
    except OSError as error:
        started['relay_error'] = str(error)[:300]
    helped, help_errors = ensure_help(group, start)
    if helped:
        started['player_help'] = helped
    if help_errors:
        started['player_help_errors'] = help_errors
    # The validator is a side job: its failure must not keep the helpers down.
    try:
        started.update(ensure_save_validation(group, start))
    except (OSError, RuntimeError, ValueError, KeyError) as error:
        started['save_validation_error'] = str(error)[:300]
    if not group['transfers']:
        return started
    # Helpers that run old code are restarted, but never in the middle of an action.
    refresh = not group_busy(group)
    for region in group['regions']:
        # One region that cannot start its agent must not keep the others down.
        try:
            if RegionPlatform(region_config(group, region)).start_agent(refresh):
                started.setdefault('agents', []).append(region['id'])
        except (OSError, RuntimeError) as error:
            started.setdefault('errors', {})[region['id']] = str(error)[:300]
    try:
        if ensure_coordinator(group, start, refresh):
            started['coordinator'] = True
    except (OSError, RuntimeError) as error:
        started['coordinator_error'] = str(error)[:300]
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
                # A TDM pair: what the battle is doing (pregame, playing, finished, rotating, ...).
                if type(seen.get('battle_phase')) is str:
                    entry['region_view']['battle_phase'] = seen['battle_phase'][:16]
                age = seen.get('ordinal_age')
                if type(age) is int and 0 <= age < len(EPOCH_NAMES):
                    entry['region_view']['epoch'] = {'ordinal': age, 'name': EPOCH_NAMES[age]}
        if group['transfers']:
            entry['transfer_agent'] = (platform or RegionPlatform(region_config(group, region))).listening(region['transfer_port'])
        report[region['id']] = entry
    result = {'group': group['group'], 'regions': report}
    if group['transfers']:
        result['coordinator'] = coordinator_pid(group) is not None
    return result


def parse_epoch(value):
    """An epoch ordinal from its index (0-9) or its name ('2026', '313 B.C.')."""
    text = str(value).strip()
    if text in EPOCH_NAMES:
        return EPOCH_NAMES.index(text)
    if text.isdigit() and int(text) < len(EPOCH_NAMES):
        return int(text)
    raise Refused('unknown epoch %r; choose one of %s' % (text, ', '.join(EPOCH_NAMES)))


def group_epoch(group, epoch, platform=None):
    """Advance the mainland to an epoch, then every awake region with it, without a restart.

    Every region keeps the mainland's epoch (follow_mainland_epoch in shard_group.dm), so the
    mainland must be awake to take it first; the others are told at once so they need not wait
    for their next poll of the mainland. A region asleep, cold or stopped follows the mainland by
    itself when it next runs. The epoch only moves forward: a region already there answers "current".
    """
    ordinal = parse_epoch(epoch)
    chosen = hosts(group, None, platform)
    chosen.sort(key=lambda item: item[0]['id'] != group['mainland'])  # the mainland first
    results = {}
    for region, host in chosen:
        mainland = region['id'] == group['mainland']
        if mainland and (host.frozen() or not host.platform.listening(region['port'])):
            raise Refused('the mainland %s is not awake; start or wake it first (every region follows its epoch)' % region['id'])
        if host.frozen():
            state = 'asleep: follows the mainland when it wakes'
        elif not host.platform.listening(region['port']):
            state = 'not running: follows the mainland when it starts'
        elif not host.token():
            state = 'refused: config/lifecycle-token.txt is missing'
        else:
            try:
                answer = host.platform.query(region['port'], host.token(), 'set_epoch', extra={'epoch': str(ordinal)})
            except (OSError, RuntimeError, ValueError) as error:
                answer = {'epoch': 'refused:%s' % str(error)[:100]}
            result = answer.get('epoch') if isinstance(answer, dict) else None
            state = result if isinstance(result, str) else 'refused:no answer (an older build without set_epoch)'
            state = state.replace('refused:', 'refused: ', 1)
        if mainland and state not in ('set', 'current'):
            raise Refused('the mainland %s did not take the epoch (%s); no region was changed' % (region['id'], state))
        results[region['id']] = state
    return {'epoch': ordinal, 'name': EPOCH_NAMES[ordinal], 'mainland': group['mainland'], 'regions': results}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--config', required=True)
    parser.add_argument('action', nargs='?', choices=GROUP_ACTIONS)
    parser.add_argument('--region')
    parser.add_argument('--from', dest='source', help='adopt: the stopped standalone server folder')
    parser.add_argument('--epoch', help='epoch: the epoch to advance to, by name (2026) or index (0-9)')
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
            result = setup(group, region_id=args.region)
        elif args.action == 'enrol':
            if not args.region:
                parser.error('enrol needs --region')
            result = enrol(group, args.region)
        elif args.action == 'status':
            result = group_status(group, args.region)
        elif args.action == 'check-update':
            try:
                result = group_check_update(group, args.region)
            except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
                print(json.dumps({'ok': False, 'component': 'server', 'error': str(error)[:300]}))
                return 1
        elif args.action == 'help-status':
            result = help_status(group)
        elif args.action == 'help-start':
            result = help_start(group, region_id=args.region)
        elif args.action == 'help-stop':
            result = help_stop(group, region_id=args.region)
        elif args.action == 'adopt':
            if not args.region or not args.source:
                parser.error('adopt needs --region and --from')
            result = adopt(group, args.region, args.source)
        elif args.action == 'epoch':
            if args.epoch is None or args.region:
                parser.error('epoch needs --epoch and acts on the whole group')
            result = group_epoch(group, args.epoch)
        elif args.action == 'config-migrate':
            result = migrate_config(group)
        elif args.action == 'config-apply':
            done, refused = apply_config(group, args.region)
            if refused and not done:
                print(json.dumps({'ok': False, 'refused': refused}))
                return 1
            result = {'done': done, 'refused': refused}
        elif args.action in ('freeze', 'thaw', 'kill', 'unlock', 'force-unlock'):
            # kill: forced stop without saving; the next start restores the last completed save.
            # unlock: remove stale BYOND lock files from stopped regions; force-unlock from any.
            done, refused = {}, {}
            for region, host in hosts(group, args.region):
                try:
                    if args.action in ('unlock', 'force-unlock'):
                        done[region['id']] = host.unlock(force=args.action == 'force-unlock')
                    else:
                        done[region['id']] = getattr(host, args.action)()  # freeze, thaw or kill
                except Refused as refusal:
                    refused[region['id']] = str(refusal)
            if refused and not done:
                print(json.dumps({'ok': False, 'refused': refused}))
                return 1
            result = {'done': done, 'refused': refused}
        else:
            accepted, refused = {}, {}
            waited = False
            for region, host in hosts(group, args.region):
                try:
                    if args.action == 'start' and not waited and host.config['start_requires_byond_pager']                             and not host.platform.listening(host.config['port']):
                        # start.bat after a reboot: the pager starts and signs in once for every region
                        waited = True
                        host.wait_for_byond()
                    if args.action == 'force-restart':
                        accepted[region['id']] = host.force_restart()
                    elif args.action == 'stage':
                        accepted[region['id']] = host.request_stage()
                    else:
                        accepted[region['id']] = host.request(args.action)
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
