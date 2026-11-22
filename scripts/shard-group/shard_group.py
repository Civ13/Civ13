"""Build, start, save-and-stop, restart, update, freeze and thaw a group of region worlds.

A region group (sharded servers) is several Civ13 worlds on one host. Each
region is its own git worktree of the repository with its own selected map,
build, config and map_saves, so regions never share a save or a lock:

    python shard_group.py --config group.json setup     # worktrees and region config
    python shard_group.py --config group.json update    # check out and compile every region
    python shard_group.py --config group.json update-offline [--region ID]  # update every region not running
    python shard_group.py --config group.json start|stop|restart [--region ID]
    python shard_group.py --config group.json status
    python shard_group.py --config group.json freeze|thaw [--region ID]
    python shard_group.py --config group.json adopt --region ID --from PATH
    python shard_group.py --config group.json check-update [--region ID]
    python shard_group.py --config group.json help-status|help-start|help-stop
    python shard_group.py --config group.json translator-status|translator-start|translator-stop  # Edge chat translator
    python shard_group.py --config group.json config-apply [--region ID]  # overlays + config.local.txt, no compile
    python shard_group.py --config group.json config-migrate  # whole overlay config.txt -> config.local.txt
    python shard_group.py --config group.json expedition-land --region ID --template T.json [--key X,Y]
    python shard_group.py --config group.json expedition-archive --region ID
    python shard_group.py --config group.json expedition-status
    python shard_group.py --config group.json activity                      # player activity report (launcher)
    python shard_group.py --config group.json records [--ckey K | --search T | --export F]  # shared player records
    python shard_group.py --config group.json ports                         # every port, who holds it, clashes
    python shard_group.py --config group.json set-gate --region ID [--apply]  # make ID the front door (group_ports.py)
    python shard_group.py --config group.json set-port --region ID --port N [--apply]
    python shard_group.py --config group.json add-gateway [--region ID] [--apply]  # an always-up world for the front door

Sleeping (freeze after idle, wake on a connection or a launcher request, cold
start after a power-down) is done by the host service:
`gaia_host.py [--config gaia.json] --group group.json serve`, which also keeps
the group's transfer agents and coordinator running, and (when the group
config has "player_help") one "Ask for help" bridge per region, and (with
"chat_translator") the Edge chat translator, whose address every region's config gets.

Each region is driven by the same host logic as scripts/gaia-host/gaia_host.py
(one detached worker per action, progress in operation.json, save-and-stop
through the world's lifecycle topic, a verified backup of every save), except
that DreamDaemon is started directly instead of through a scheduled task.
Actions never take paths or commands from the caller; everything comes from
the group config. setup never touches the source checkout's own files.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import contextlib
import filecmp
import hashlib
import io
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import socket
import sqlite3
import struct
import subprocess
import sys
import threading
import time
import traceback
import urllib.request

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'gaia-host'))
import gaia_host  # noqa: E402
from byond_topic import frame_query  # noqa: E402
from gaia_host import Host, Platform, Refused  # noqa: E402
import process_safety  # noqa: E402
from process_safety import Unverified  # noqa: E402
sys.path.insert(0, str(HERE))
import expedition_slots  # noqa: E402
import fresh_world  # noqa: E402
import group_fresh_world  # noqa: E402
import agent_runs  # noqa: E402
import group_ports  # noqa: E402
import underground_migration  # noqa: E402
import daily_maintenance  # noqa: E402
from shard_map_selection import select_map_block  # noqa: E402

GROUP_ACTIONS = ('setup', 'status', 'start', 'stop', 'restart', 'update', 'freeze', 'thaw', 'adopt', 'check-update',
                 'kill', 'force-restart', 'stage', 'enrol', 'help-status', 'help-start', 'help-stop', 'unlock', 'force-unlock',
                 'config-apply', 'config-migrate', 'handover', 'epoch', 'fresh-world', 'group-fresh-world', 'update-offline',
                 'update-unsaved', 'expedition-land', 'expedition-archive', 'expedition-status', 'expedition-open', 'expedition-grow', 'add-gateway',
                 'players', 'send-players', 'magic-whitelist', 'activity', 'agents', 'ports', 'set-gate', 'set-port',
                 'translator-status', 'translator-start', 'translator-stop', 'maintenance', 'maintenance-status',
                 'migrate-underground', 'records', 'accounts', 'add-regions')
# send-players landings (region_admin_send.dm): the nearest dry shore facing the source,
# exact coordinates, or the destination's normal arrival point.
SEND_LANDINGS = ('shore', 'coords', 'arrival')
CKEY_LIST = re.compile(r'^[A-Za-z0-9_ .@-]{1,32}(,[A-Za-z0-9_ .@-]{1,32}){0,19}$')
COORDS = re.compile(r'^\d{1,5},\d{1,5},\d{1,5}$')
# Magic whitelist (code/modules/divine/magic_whitelist.dm): one player key per line in the
# source region's SQL folder, read by every region like admins.txt. Keep the header in step.
MAGIC_WHITELIST_HEADER = '# Magic whitelist: one player key per line. Shared by every region of the group.\n'
# Kinds nobody can start in: worlds that reset, transit/orbit, battles, events,
# expedition slots, practice rooms and the gateway (the mainland's own rules).
START_REGION_REFUSED_KINDS = ('RAID', 'ORBIT', 'BATTLE', 'EVENT', 'EXPEDITION', 'TUTORIAL', 'GATEWAY')
HELP_STOP_SECONDS = 60  # help-stop waits this long for bridges to finish their answers before ending them
HELP_STARTING_SECONDS = 300  # a bridge we started may load its corpus this long before it takes the lock
# Chat translator (tools/edge-translator): the host service runs one for the whole group.
TRANSLATOR_PORT = 55581
TRANSLATOR_SOURCE = 'tools/edge-translator'
TRANSLATOR_FILES = ('edge_translator.js', 'detect.js', 'package.json', 'package-lock.json')
TRANSLATOR_INSTALL_SECONDS = 600  # npm ci of the pinned playwright-core
TRANSLATOR_STARTING_SECONDS = 120  # Edge may take this long to open before /health answers
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
# A world answers a request only at its next yield, and a large land can run longer than the
# 15 s reply time first: Earth Europe's standby_load and the Oceania and Antarctica
# handover_release timed out that way (2026-11-18). How long such a request is checked and resent.
ASK_SECONDS = 180
# A handover that fails after the old world let go used to leave the loaded standby running on
# its standby port. The region was then down with a second world still holding its save, the
# host service's restart met that world, and every later handover was refused because the
# standby port was in use. The old world saved before it let go, so the standby is ended and
# the host service starts the region from that save.
STANDBY_ENDED = 'the loaded standby was ended, and the host service starts the region again from the save'
STAGE_LOCK_HOURS = 3  # a stage lock older than this belongs to a worker that died
DEFAULT_UPDATE_CHECK_MINUTES = 5  # how often an empty or sleeping region fetches to look for an update
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
             'config/tdm-token.txt', 'config/event-token.txt', 'config/shard_build.json', 'config/server-build.json',
             expedition_slots.WORLD_FILE)
# BARRACKS is the always-on TDM world players wait and practise in; BATTLE runs the
# TDM rounds, rotates its map after each vote and sends everyone back to the
# barracks before it reboots (code/modules/tdm_barracks).
# EVENT is an admin-run event world: admins send players there and back while
# their characters wait, saved, in their own land (docs/event-regions.md). It
# never saves and nobody lives there. TUTORIAL only runs the practice rooms, never
# saves, and sends players back when they leave (code/modules/1713/tutorial_region.dm).
# EXPEDITION is a slot that holds one generated land at a time, reached only by
# ship (expedition_slots.py, docs/expedition-slots.md).
# GATEWAY is the always-up world on the front door's port: it hosts no play, never
# saves or sleeps, restarts on its own port to update (never a standby handover) and
# sends every player on to their land through the relay (code/modules/persistence/region_gateway.dm).
KINDS = ('SURFACE', 'OCEANIC', 'UNDERGROUND', 'RAILYARD', 'RAID', 'ORBIT', 'OTHER', 'BARRACKS', 'BATTLE', 'EVENT', 'TUTORIAL',
         'EXPEDITION', 'GATEWAY')
# Kinds whose world never saves: an ordinary round with SKIP_PERSISTENCE_SAVING (region_mode_config).
UNSAVED_KINDS = ('EVENT', 'TUTORIAL', 'GATEWAY')
# Kinds that stay up for players even while the lands are down (Val, 2026-11-21: the
# tutorial stays current and available): never asleep, back at once after a crash, and
# updated by a plain restart on their own port while empty, never a standby handover.
ALWAYS_UP_KINDS = ('GATEWAY', 'TUTORIAL')
GATEWAY_MAP = 'maps/special/gateway.dmm'
# Val (2026-11-21): the gateway never stages a build and always stays on its port. The host
# service never stages, updates or restarts it, and a group-wide restart or update leaves it
# running; a person updates it only by naming it (restart --region ID).
GATEWAY_PINNED = 'the gateway never stages a build and stays on its port; restart it by name (--region) to update it'
# Group-wide actions that would close a running world's port or build beside it.
GATEWAY_SKIPPED_ACTIONS = ('restart', 'force-restart', 'update', 'stage', 'handover', 'update-unsaved', 'update-handover')
ID = re.compile(r'^[a-z0-9_-]{1,32}$')
HOST = re.compile(r'^[A-Za-z0-9.-]{1,64}$')
HEX40 = re.compile(r'^[0-9a-f]{40}$')
RESERVED_PORTS = (1714,)  # live Gaia
AUTO_PORT_BASE = 1724  # where fill_ports starts when the group names no port at all (1714 for a live group)
TRANSFER_PORT_OFFSET = 10  # a transfer agent the group does not place sits this far above its region's port
# <root>/front-door holds what belongs to whichever region is the front door (the relay's gate,
# else the mainland), so moving the front door carries nothing: SQL/admins.txt and the magic
# whitelist every region reads, and config.local.txt, the bot link lines merged into the front
# door's config.txt only (adopt_front_door).
FRONT_FOLDER = 'front-door'
FRONT_FILES = ('admins.txt', 'magic_whitelist.txt')
FRONT_CONFIG_KEYS = ('WEBHOOK_CAN_FIRE', 'WEBHOOK_ADDRESS', 'WEBHOOK_KEY')
# Regions other than expedition slots. Slots come and go with ships' lands and
# factions' islands, and are never capped for the host (Val, 2026-11-22): the
# whole group may grow to MAX_REGIONS, a ceiling only the free ports set.
MAX_CORE_REGIONS = 32
MAX_REGIONS = 512
# The Earth regions a group that hosts Earth may be missing (add-regions): the lands of
# docs/earth-continents.md and the seas of docs/ocean-regions.md, with the ports the
# live host keeps for them (another free port when one is taken).
EARTH_REGIONS = (
    ('europe', 'Europe', 'SURFACE', 'maps/nomads/nomads_earth_europe.dmm', 1740),
    ('africa', 'Africa', 'SURFACE', 'maps/nomads/nomads_earth_africa.dmm', 1741),
    ('oceania', 'Oceania', 'SURFACE', 'maps/nomads/nomads_earth_oceania.dmm', 1742),
    ('asia', 'Asia', 'SURFACE', 'maps/nomads/nomads_earth_asia.dmm', 1743),
    ('northamerica', 'North America', 'SURFACE', 'maps/nomads/nomads_americas_north.dmm', 1744),
    ('southamerica', 'South America', 'SURFACE', 'maps/nomads/nomads_americas_south.dmm', 1746),
    ('greenland', 'Greenland', 'SURFACE', 'maps/nomads/nomads_earth_greenland.dmm', 1747),
    ('antarctica', 'Antarctica', 'SURFACE', 'maps/nomads/nomads_earth_antarctica.dmm', 1748),
    ('mediterranean', 'Mediterranean', 'SURFACE', 'maps/nomads/nomads_earth_mediterranean.dmm', 1749),
    ('atlantic', 'Atlantic Ocean', 'OCEANIC', 'maps/nomads/nomads_ocean_atlantic.dmm', 1750),
    ('pacific', 'Pacific Ocean', 'OCEANIC', 'maps/nomads/nomads_ocean_pacific.dmm', 1751),
    ('indian', 'Indian Ocean', 'OCEANIC', 'maps/nomads/nomads_ocean_indian.dmm', 1752),
    ('arctic', 'Arctic Ocean', 'OCEANIC', 'maps/nomads/nomads_ocean_arctic.dmm', 1753),
    ('southern', 'Southern Ocean', 'OCEANIC', 'maps/nomads/nomads_ocean_southern.dmm', 1754),
)
EARTH_MAINLAND_MAP = 'maps/nomads/nomads_gaia.dmm'
# The slots that hold lands across the sea (docs/expedition-slots.md): ships' voyages
# open them, and a faction's claimed island lives in one. add-regions adds the ones a
# group hosting Earth is missing, by id (they share one placeholder map), with the
# ports the plan gave them. A free slot stays stopped until a ship needs it.
EXPEDITION_SLOT_MAP = 'maps/expedition/slot.dmm'
EXPEDITION_SLOTS = (
    ('far1', 'Far Land 1', 1811, 1831),
    ('far2', 'Far Land 2', 1812, 1832),
    ('far3', 'Far Land 3', 1813, 1833),
    ('far4', 'Far Land 4', 1814, 1834),
)


def unused_backup_path(path):
    """<name>.bak-<time>, with -2, -3... added when a rewrite in the same second already kept one,
    so an earlier backup (the file as the host wrote it) is never overwritten."""
    stem = '%s.bak-%s' % (path.name, time.strftime('%Y%m%d-%H%M%S', time.gmtime()))
    candidate, number = path.with_name(stem), 1
    while candidate.exists():
        number += 1
        candidate = path.with_name('%s-%d' % (stem, number))
    return candidate


WORLD_LINKS_TABLE = HERE.parents[1] / 'tools' / 'world_links' / 'world_links.json'
_NEIGHBOURS = {}


def world_neighbours(table=None):
    """{region id: set of region ids next to it} from the world links table (map edges walked or
    sailed over, and the islands set inside an ocean), both ways round, or {} when it cannot be
    read. Cached until the file changes."""
    path = Path(table or WORLD_LINKS_TABLE)
    try:
        stamp = path.stat().st_mtime_ns
    except OSError:
        return {}
    cached = _NEIGHBOURS.get(str(path))
    if cached and cached[0] == stamp:
        return cached[1]
    try:
        data = json.loads(path.read_text(encoding='utf-8'))
    except (OSError, ValueError):
        return {}
    out = {}
    def join(a, b):
        if isinstance(a, str) and isinstance(b, str) and a != b:
            out.setdefault(a, set()).add(b)
            out.setdefault(b, set()).add(a)
    for rid in list((data.get('lands') or {})) + list((data.get('oceans') or {})):
        out.setdefault(rid, set())
    for link in data.get('links') or []:
        ends = [link.get(side) for side in ('a', 'b')]
        if all(isinstance(end, list) and end for end in ends):
            join(ends[0][0], ends[1][0])
    for oid, ocean in (data.get('oceans') or {}).items():
        for inset in (ocean or {}).get('insets') or []:
            join(oid, (inset or {}).get('land'))
    _NEIGHBOURS[str(path)] = (stamp, out)
    return out


def load_group(path):
    group = json.loads(Path(path).read_text(encoding='utf-8-sig'))
    if isinstance(group, dict) and fill_ports(group):
        # Ports the file left out were chosen: keep them, so every later reader (the launcher,
        # the bot, the host service) sees the same ones and a new region never moves an old one.
        path = Path(path)
        shutil.copy2(path, unused_backup_path(path))
        temporary = path.with_name(path.name + '.tmp')
        temporary.write_text(json.dumps(group, indent=2) + '\n', encoding='utf-8')
        gaia_host.replace_file(temporary, path)
    return check_group(group, path)


def fill_ports(group, listening=None):
    """Choose every port the group file leaves out. Returns what was chosen ([] = nothing).

    A region without "port" gets the next free one, the front door first; a region without
    "transfer_port" gets one when the group travels ("transfers": true, or any region has
    one); "relay_port": "auto" gets two free ports in a row (the relay and its control
    port). Ports already in the file are never moved, and a port another program on this
    machine listens on is skipped. Anything malformed is left for check_group to refuse."""
    regions = group.get('regions')
    if type(regions) is not list or not regions or any(type(r) is not dict for r in regions):
        return []
    number = lambda value: value if type(value) is int else None
    missing = [r for r in regions if r.get('port') is None]
    travels = group.get('transfers') is True or any(number(r.get('transfer_port')) for r in regions)
    agents = [r for r in regions if r.get('transfer_port') is None] if travels else []
    relay = group.get('relay_port') == 'auto'
    if not missing and not agents and not relay:
        return []
    if listening is None:
        listening = Platform().listening
    taken = {number(r.get(key)) for r in regions for key in ('port', 'transfer_port', 'standby_port')}
    taken |= {number(group.get('relay_port')), number(group.get('relay_control_port')),
              number(group.get('doorman_port')) or gaia_host.FREEZE_DEFAULTS['doorman_port']}
    taken.discard(None)
    reserved = () if group.get('live') is True else RESERVED_PORTS

    def free(start, run=1, game=False):
        port = max(1024, start)
        while any(p in taken or p in (reserved if game else RESERVED_PORTS) or listening(p) for p in range(port, port + run)):
            port += 1
            if port + run > 65536:
                raise ValueError('no free port left to choose; set the ports in the group file')
        taken.update(range(port, port + run))
        return port

    placed = [number(r.get('port')) for r in regions if number(r.get('port'))]
    base = number(group.get('port_base')) or (min(placed) if placed else 1714 if group.get('live') is True else AUTO_PORT_BASE)
    front = group.get('gate') if group.get('relay_port') and group.get('gate') else group.get('mainland', regions[0].get('id'))
    chosen = []
    for region in sorted(missing, key=lambda r: r.get('id') != front):
        region['port'] = free(base, game=True)
        chosen.append('%s port %d' % (region.get('id'), region['port']))
    for region in agents:
        if type(region.get('port')) is not int:
            continue
        region['transfer_port'] = free(region['port'] + TRANSFER_PORT_OFFSET)
        chosen.append('%s transfer port %d' % (region.get('id'), region['transfer_port']))
    if relay:
        group['relay_port'] = free(max(p for p in taken) + 1, run=2)
        group.setdefault('relay_control_port', group['relay_port'] + 1)
        chosen.append('relay port %d' % group['relay_port'])
    return chosen


def check_group(group, path):
    """Validate a group config read from path and fill in its defaults (load_group).
    group_ports checks a planned change with it before anything is written."""
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
        raise ValueError('a group has 1 to %d regions besides its expedition slots, and %d in all' % (MAX_CORE_REGIONS, MAX_REGIONS))
    if sum(1 for r in regions if type(r) is dict and r.get('kind') != 'EXPEDITION') > MAX_CORE_REGIONS:
        raise ValueError('a group has 1 to %d regions besides its expedition slots, and %d in all' % (MAX_CORE_REGIONS, MAX_REGIONS))
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
        if region.get('keep_down') is not None and type(region['keep_down']) is not bool:
            raise ValueError('region %s keep_down must be true or false' % region['id'])
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
    if any(r['id'] == mainland and r['kind'] == 'EVENT' for r in regions):
        raise ValueError('the mainland cannot be an EVENT region')
    if any(r['id'] == mainland and r['kind'] == 'EXPEDITION' for r in regions):
        raise ValueError('the mainland cannot be an EXPEDITION slot')
    if FRONT_FOLDER in ids:
        raise ValueError('a region cannot be called %s: the group keeps its front door files there' % FRONT_FOLDER)
    if group.get('port_base') is not None and (type(group['port_base']) is not int or not 1024 <= group['port_base'] <= 65535):
        raise ValueError('port_base must be a port from 1024 to 65535')
    if expedition_slots.SLOTS_FOLDER in ids:
        raise ValueError('a region cannot be called %s: the expedition slots keep their lands there' % expedition_slots.SLOTS_FOLDER)
    tutorials = [r for r in regions if r['kind'] == 'TUTORIAL']
    if len(tutorials) > 1:
        raise ValueError('a group has at most one TUTORIAL region')
    if any(r['id'] == mainland for r in tutorials):
        raise ValueError('the mainland cannot be a TUTORIAL region')
    gateways = [r for r in regions if r['kind'] == 'GATEWAY']
    if len(gateways) > 1:
        raise ValueError('a group has at most one GATEWAY region')
    if any(r['id'] == mainland for r in gateways):
        raise ValueError('the mainland cannot be a GATEWAY region')
    if gateways and not group.get('relay_port'):
        raise ValueError('a GATEWAY region sends players on through the routing relay; set relay_port')
    # Where new characters start (and fallen ones whose bed does not keep their
    # home): the mainland unless the host names another region. The mainland
    # stays the era source, bot link and land-stage reference either way.
    start_region = group.setdefault('start_region', mainland)
    if start_region is None:
        start_region = group['start_region'] = mainland
    if start_region not in ids:
        raise ValueError('start_region must be one of the region ids')
    start_kind = next(r['kind'] for r in regions if r['id'] == start_region)
    if start_kind in START_REGION_REFUSED_KINDS:
        raise ValueError('the start region cannot be a %s region' % start_kind)
    for key, low, high, default in (('save_minutes', 0, 1440, 15), ('travel_save_seconds', 10, 3600, 60)):
        value = group.setdefault(key, default)
        if type(value) is not int or not low <= value <= high:
            raise ValueError('%s must be a whole number from %d to %d' % (key, low, high))
    # Val (2026-11-22): a land next to one with players stays ready to wake in seconds (suspended in
    # memory, started ahead from cold storage); one with nobody next door goes to cold storage after
    # cold_after_minutes. Only regions in the world links table take part (RegionHost.readiness).
    if type(group.setdefault('ready_neighbours', True)) is not bool:
        raise ValueError('ready_neighbours must be true or false')
    cold_after = group.setdefault('cold_after_minutes', 15)
    if type(cold_after) is not int or not 0 <= cold_after <= 1440:
        raise ValueError('cold_after_minutes must be a whole number from 0 (never) to 1440')
    # Ships sail over linked map edges (docs/ocean-regions.md); off until the oceans run.
    if type(group.setdefault('edge_travel_oceans', False)) is not bool:
        raise ValueError('edge_travel_oceans must be true or false')
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
        if gate not in ids or any(r['id'] == gate and r['kind'] in ('RAID', 'EVENT', 'TUTORIAL', 'EXPEDITION') for r in regions):
            raise ValueError('gate must be one of the region ids and not a RAID, EVENT, TUTORIAL or EXPEDITION region')
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
    # The CivilizationBot profile.json that watches the gate; set-gate repoints it (group_ports).
    if group.get('bot_profile') is not None and (type(group['bot_profile']) is not str or not group['bot_profile']):
        raise ValueError('bot_profile must be a path')
    group.setdefault('python', sys.executable)
    if group.get('rust_g') is not None and (type(group['rust_g']) is not str or not group['rust_g']):
        raise ValueError('rust_g must be a path')
    root, repository = Path(group['root']).resolve(), Path(group['repository']).resolve()
    if root == repository or repository in root.parents or root in repository.parents:
        raise ValueError('root must be outside the repository (and not contain it)')
    group.setdefault('revision', 'HEAD')
    # Every region gets a host operator agent (write_operator_agent) unless this is false.
    group.setdefault('operator_agent', True)
    if type(group['operator_agent']) is not bool:
        raise ValueError('operator_agent must be true or false')
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
    # The players' countdown before a save and stop, restart or handover (seconds, 0-3600).
    group.setdefault('shutdown_warning_seconds', gaia_host.DEFAULT_SHUTDOWN_WARNING_SECONDS)
    gaia_host.check_shutdown_warning(group['shutdown_warning_seconds'])
    # A region that is empty and has saved since its last player moves onto the latest revision
    # at once (RegionHost.update_while_empty); the remote is checked at most this often.
    if type(group.setdefault('update_when_empty', True)) is not bool:
        raise ValueError('update_when_empty must be true or false')
    minutes = group.setdefault('update_check_minutes', DEFAULT_UPDATE_CHECK_MINUTES)
    if type(minutes) is not int or not 1 <= minutes <= 1440:
        raise ValueError('update_check_minutes must be a whole number of minutes, 1-1440')
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
    # Chat translator: the host service keeps tools/edge-translator running and every
    # region's config gets CHAT_TRANSLATE_URL (code/modules/chat/chat_translate.dm).
    settings = group.get('chat_translator')
    if settings is not None:
        if type(settings) is not dict:
            raise ValueError('chat_translator must be an object')
        port = settings.setdefault('port', TRANSLATOR_PORT)
        if type(port) is not int or not 1024 <= port <= 65535:
            raise ValueError('chat_translator port must be 1024-65535')
        for key in ('node', 'npm', 'edge', 'profile'):
            if key in settings and (type(settings[key]) is not str or not settings[key]):
                raise ValueError('chat_translator %s must be a non-empty string' % key)
        settings.setdefault('node', 'node')
        settings.setdefault('npm', 'npm.cmd' if os.name == 'nt' else 'npm')
    # Daily maintenance (daily_maintenance.py): every region onto one build at a set time of day.
    daily_maintenance.check_settings(group)
    resolve_standby_ports(group)
    group['_path'] = str(Path(path).resolve())
    # While a maintenance run stands, every reader builds the one commit it pinned.
    daily_maintenance.apply_pin(group)
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


def front_region(group):
    """The region players join first and the bot watches: the relay's gate, else the mainland."""
    return group['gate'] if group.get('relay_port') and group.get('gate') else group['mainland']


def front_dir(group):
    return Path(group['root']) / FRONT_FOLDER


def front_shared(group):
    """True once the group keeps its shared files in <root>/front-door (adopt_front_door)."""
    return (front_dir(group) / 'SQL' / 'admins.txt').is_file()


def shared_file(group, name):
    """SQL/<name> as every region reads it (admins_file() and magic_whitelist_file() in the
    game): the group's front-door folder once it is adopted, else the front door's own."""
    if front_shared(group):
        return front_dir(group) / 'SQL' / name
    return region_dir(group, front_region(group)) / 'SQL' / name


def front_config_lines(text):
    """The lines of a config.local.txt that link its world to the bot (set or switched off)."""
    return [line for line in text.splitlines() if (config_key(line) or commented_key(line)) in FRONT_CONFIG_KEYS]


def front_sources(group, also=()):
    """Region ids whose folders may hold the front door's files: the front door, then also
    (set-gate names both ends of a move, so a move that is run again still finds them)."""
    known = {r['id'] for r in group['regions']}
    return [region_id for region_id in dict.fromkeys([front_region(group), *also]) if region_id in known]


def front_link_file(group, also=()):
    """The first source overlay's config.local.txt that holds bot link lines, or None."""
    for region_id in front_sources(group, also):
        overlay = next(r for r in group['regions'] if r['id'] == region_id).get('overlay')
        local = Path(overlay) / LOCAL_CONFIG if overlay else None
        try:
            if local and front_config_lines(local.read_text(encoding='utf-8-sig')):
                return local
        except OSError:
            continue
    return None


def plan_front_door(group, also=()):
    """What adopt_front_door would still move: {'files': [names], 'keys': [setting names]}.
    Names only: the values (the webhook key) never leave the files."""
    front = front_dir(group)
    files = [name for name in FRONT_FILES if not (front / 'SQL' / name).exists()]
    local = front_link_file(group, also)
    keys = sorted({config_key(line) or commented_key(line)
                   for line in front_config_lines(local.read_text(encoding='utf-8-sig'))}) if local else []
    return {'files': files, 'keys': keys, 'folder': str(front)}


def adopt_front_door(group, stamp=None, also=()):
    """Move what belongs to the front door, whichever region that is, into <root>/front-door.

    The shared admins file and magic whitelist are copied from the current front door's
    SQL folder (worlds find them by the admins file being there), and the bot link lines
    leave its overlay's config.local.txt for front-door/config.local.txt, which
    apply_overlays merges into the front door's config.txt only. Safe to repeat; a file
    that is rewritten keeps a .bak-<stamp> copy. Returns what moved."""
    stamp = stamp or time.strftime('%Y%m%d-%H%M%S', time.gmtime())
    plan, front = plan_front_door(group, also), front_dir(group)
    folders = [region_dir(group, region_id) / 'SQL' for region_id in front_sources(group, also)]
    (front / 'SQL').mkdir(parents=True, exist_ok=True)
    moved = []
    # The whitelist first: the admins file is what tells a world the folder is in use.
    for name in sorted(plan['files'], key=lambda name: name == 'admins.txt'):
        source = next((folder / name for folder in folders if (folder / name).is_file()), None)
        if source:
            shutil.copy2(source, front / 'SQL' / name)
        else:
            (front / 'SQL' / name).write_text(MAGIC_WHITELIST_HEADER if name == 'magic_whitelist.txt' else '', encoding='utf-8')
        moved.append('SQL/' + name)
    if plan['keys']:
        local, target = front_link_file(group, also), front / 'config.local.txt'
        text = local.read_text(encoding='utf-8-sig')
        lines = front_config_lines(text)
        old = target.read_text(encoding='utf-8-sig') if target.exists() else \
            '# Settings of whichever region is the front door (scripts/shard-group/README.md).\n'
        kept = [line for line in old.splitlines() if line not in front_config_lines(old)]
        if target.exists():
            shutil.copy2(target, target.with_name('%s.bak-%s' % (target.name, stamp)))
        shutil.copy2(local, local.with_name('%s.bak-%s' % (local.name, stamp)))
        # The shared file first, so a failure between the two writes leaves the lines in both.
        target.write_text('\n'.join(kept + lines) + '\n', encoding='utf-8')
        local.write_text('\n'.join(line for line in text.splitlines() if line not in lines) + '\n', encoding='utf-8')
        moved.append('config.local.txt')
    return moved


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
    # An empty land across the sea sleeps on disk, not in memory, unless the group says otherwise.
    if region['kind'] == 'EXPEDITION' and 'freeze_cold' not in group:
        config['freeze_cold'] = True
    return config


def directory(group):
    """config/shard_region.json for one region: the whole group plus which region this is."""
    return [{'id': r['id'], 'name': r['name'], 'kind': r['kind'], 'address': '%s:%d' % (group['public_host'], r['port'])}
            for r in group['regions']]


def selected_map_dme(dme_text, include):
    return select_map_block(dme_text, include, 'civ13.dme')


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
        host to name the save (DM reads -params standby=PORT), hidden from the hub until it is opened.

        The parameter names the standby port: a standby that took over keeps its launch
        parameters, and a reboot on the region's port must come back as the region, not
        as a standby waiting for a move (North America and Jungle, 2026-11-16)."""
        path = Path(self.config['repository'])
        (path / 'logs').mkdir(exist_ok=True)
        self.start_agent()
        # -invisible would keep the world off the BYOND hub for good, even after the handover
        # opens the region's port, so a public region's standby launches -public and stays
        # hidden through world.visibility until then (Gaia, 2026-11-18).
        argv = [self.config['daemon'], dmb, str(port), '-trusted', '-close',
                '-public' if self.config['public'] else '-invisible', '-log', STANDBY_LOG,
                '-params', 'standby=%d' % port]
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
                try:
                    self.terminate(pid, expect=process_safety.python_expect())
                except Unverified:
                    return False  # not an agent: never end it; the port stays taken until a person frees it
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
        self.failed_handover_file = self.state_dir / 'failed-handover.json'
        # update-offline: install the build into the stopped region as soon as its stage is ready.
        self.install_marker = self.state_dir / 'install-after-stage'
        self.next_install_attempt = 0.0  # update_while_empty: when to try a refused handover again
        self.unsaved_install = None  # update_unsaved_while_empty: the staged build last restarted onto

    def shutdown_warning(self):
        """The group config's current shutdown_warning_seconds (the launcher's Players' warning),
        read at each action so a change applies without a setup; the region's own config if
        the group config cannot be read."""
        try:
            group = load_group(self.config['group_config'])
        except (OSError, ValueError, KeyError):
            return super().shutdown_warning()
        # Players the daily maintenance already counted down get a short reminder only.
        reminder = daily_maintenance.handover_warning(group, self.config['region'])
        return group['shutdown_warning_seconds'] if reminder is None else reminder

    def status(self):
        report = super().status()
        stage = self.read_json(self.stage_file)
        if stage and not self.stage_failure_superseded(stage):
            report['stage'] = dict(stage, pending=self.update_pending())
        report['build'] = self.live_dmb_name()
        if self.keep_down():
            report['keep_down'] = True  # travellers never start it (group config keep_down)
        if self.lock.exists() and (self.read_state() or {}).get('action') in ('handover', 'auto-handover'):
            port = self.standby_port()
            report['standby'] = {'port': port, 'listening': self.platform.listening(port)}
        return report

    def work(self, action, operation):
        if action == 'fresh-world':
            return fresh_world.work(self, operation)
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

    def stale_stage_lock(self):
        """(why, operation) when the stage lock is held by nobody, else None (no lock, or its
        worker runs)."""
        try:
            operation = self.stage_lock.read_text().strip()
            held_since = self.stage_lock.stat().st_mtime
        except OSError:
            return None
        if self.booted_since(held_since):
            return 'the machine restarted', operation
        stage = self.read_json(self.stage_file) or {}
        worker = stage.get('worker')
        if operation and stage.get('operation') == operation and isinstance(worker, dict) and type(worker.get('pid')) is int:
            # Before the age check: a stage that waited hours for its compile slot still runs.
            alive = getattr(self.platform, 'worker_alive', None)
            return ('its worker ended', operation) if alive and not alive(worker['pid'], worker.get('started')) else None
        if time.time() - held_since > STAGE_LOCK_HOURS * 3600:
            return 'it ran for more than %d hours' % STAGE_LOCK_HOURS, operation
        if not operation or stage.get('operation') != operation:
            return None  # being taken right now
        if stage.get('phase') == 'accepted' and time.time() - held_since > gaia_host.WORKER_START_SECONDS:
            return 'its worker never started', operation
        return None

    def stage_running(self):
        """Whether a stage holds its lock. A stage whose worker is gone (the machine restarted
        or the worker was ended mid-build) used to keep "a build is already being staged" for
        STAGE_LOCK_HOURS, and Save, update and restart waited on it; the stage is recorded as
        failed and its lock released, so the next one builds. As Host.busy: the record is
        settled while the stale lock still keeps a new stage out, and only then is the lock
        taken away, if it is still that one."""
        if not self.stage_lock.exists():
            return False
        stale = self.stale_stage_lock()
        if not stale:
            return True
        reason, operation = stale
        try:
            stage = self.read_json(self.stage_file) or {}
            if stage.get('operation') == operation and stage.get('phase') not in ('ready', 'current', 'failed'):
                self.stage_record(phase='failed', error='the build was interrupted (%s) and did not finish' % reason)
            gaia_host.remove_file(self.urgent_marker())
        except OSError:
            return True  # not settled: the lock stays, and the next look tries again
        if not gaia_host.release_lock(self.stage_lock, operation):
            return self.stage_lock.exists()
        print('stale stage lock removed for %s (%s)' % (self.config['region'], reason), file=sys.stderr, flush=True)  # as Host.busy
        return False

    def stage_failure_superseded(self, stage):
        """A failed stage is out of date once the region has a newer, intact build.

        stage.json is only written by a stage, so without this a failure (such as the
        compile.lock sharing violation fixed in #4701) stayed on the region's status line
        through every later update, kill and unlock, as if something still held its files.
        """
        if stage.get('phase') != 'failed' or self.stage_running() or not self.built_revision():
            return False
        try:
            return self.build_file().stat().st_mtime_ns > self.stage_file.stat().st_mtime_ns
        except OSError:
            return False

    def clear_failed_stage(self):
        """Forget a failed stage record unless a stage is running; True when one was removed."""
        stage = self.read_json(self.stage_file)
        if not stage or stage.get('phase') != 'failed' or self.stage_running():
            return False
        gaia_host.remove_file(self.stage_file)
        return True

    def unlock(self, force=False):
        answer = super().unlock(force)
        if self.clear_failed_stage():
            answer['stage_cleared'] = True
        return answer

    def request_stage(self, urgent=False):
        """Build the latest revision beside the running world. urgent: a person is waiting on
        it (Save, update and restart, the in-game button, Build update), so it takes the group's
        next compile ahead of the host service's background stages; a stage already queued in
        the background is moved up the same way."""
        if not (self.repo / '.git').exists():
            raise Refused('the region is not set up; run setup first')
        if self.holds_its_port():
            raise Refused(GATEWAY_PINNED)
        self.check_disk('staging checks out and compiles a whole build')
        self.state_dir.mkdir(parents=True, exist_ok=True)
        self.stage_running()  # releases a lock whose worker is gone
        try:
            descriptor = os.open(self.stage_lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        except FileExistsError:
            if urgent:
                self.mark_stage_urgent()
            raise Refused('a build is already being staged')
        operation = secrets.token_hex(16)
        with os.fdopen(descriptor, 'w') as handle:
            handle.write(operation)
        if urgent:
            self.mark_stage_urgent()
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
        """One staged compile per group at a time, so a deploy never compiles every region at once.
        A background stage lets a person's stage of another region go first."""
        def yield_to_urgent():
            return not self.urgent_marker().exists() and self.urgent_stage_waiting()
        with self.group_slot('compile.lock', 'compile', self.stage_record, wait_seconds, yield_to=yield_to_urgent):
            yield

    # Val (2026-11-18): Save, update and restart sat a long time before anything happened. The
    # host service stages every region on each master commit, one compile at a time (about two
    # to three minutes each), so the region a person was updating queued behind up to a dozen
    # background builds. A stage a person waits on now marks itself in .staging/urgent, and
    # background stages wait while one is queued.
    def urgent_dir(self):
        return self.repo.parent / '.staging' / 'urgent'

    def urgent_marker(self):
        return self.urgent_dir() / self.config['region']

    def mark_stage_urgent(self):
        marker = self.urgent_marker()
        try:
            marker.parent.mkdir(parents=True, exist_ok=True)
            marker.write_text(str(self.stage_lock), encoding='utf-8')
        except OSError:
            pass  # only the order of the queue depends on it

    def urgent_stage_waiting(self):
        """Whether another region has a stage a person is waiting on. A marker whose stage has
        ended (its stage.lock is gone) is stale and removed."""
        try:
            entries = list(self.urgent_dir().iterdir())
        except OSError:
            return False
        waiting = False
        for entry in entries:
            if entry.name == self.config['region']:
                continue
            try:
                lock = Path(entry.read_text(encoding='utf-8').strip())
            except OSError:
                continue  # being written or removed right now
            if lock.name == 'stage.lock' and lock.exists():
                waiting = True
                continue
            try:
                entry.unlink()
            except OSError:
                pass
        return waiting

    @contextlib.contextmanager
    def handover_slot(self, wait_seconds=7200):
        """One handover per group at a time: two Gaias loading at once would not fit in memory."""
        with self.group_slot('handover.lock', 'handover', self.record, wait_seconds):
            yield

    @contextlib.contextmanager
    def group_slot(self, name, what, record, wait_seconds, yield_to=None):
        """Hold one of the group's slots (a lock file in .staging). yield_to: while it returns
        True this waiter lets others take the slot first; that wait does not count against
        wait_seconds, since the stages it waits for end on their own."""
        lock = self.repo.parent / '.staging' / name
        lock.parent.mkdir(parents=True, exist_ok=True)
        deadline = self.platform.now() + wait_seconds
        empty_since = None
        while True:
            if yield_to is not None and yield_to():
                record(phase='waiting for a requested build of another region')
                self.platform.sleep(10)
                deadline = max(deadline, self.platform.now() + wait_seconds)
                continue
            try:
                descriptor = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
                break
            except PermissionError:
                # Windows: the lock is being deleted by its holder right now.
                if self.platform.now() > deadline:
                    raise RuntimeError('another region kept the %s slot busy too long' % what)
                self.platform.sleep(1)
                continue
            except FileExistsError:
                holder = self.slot_holder(lock)
                if holder is None:
                    continue  # released while we looked
                if holder:
                    empty_since = None
                    stale = not self.platform.alive(holder) or self.slot_from_before_boot(lock)
                else:
                    # The holder writes its pid just after creating the file (and Windows
                    # refuses reading a file another process has open), so an empty lock
                    # is only stale once it stays empty longer than a claim takes.
                    if empty_since is None:
                        empty_since = self.platform.now()
                    stale = self.platform.now() - empty_since >= self.SLOT_CLAIM_SECONDS
                if stale:
                    try:
                        lock.unlink(missing_ok=True)
                        continue
                    except PermissionError:
                        # Windows: another region has it open (it is creating or
                        # releasing it right now), so it is not stale after all.
                        pass
                if self.platform.now() > deadline:
                    raise RuntimeError('another region kept the %s slot busy too long' % what)
                record(phase='waiting for another region\'s %s' % what)
                self.platform.sleep(10)
        with os.fdopen(descriptor, 'w') as handle:
            handle.write(str(os.getpid()))
        try:
            yield
        finally:
            for _ in range(10):
                try:
                    lock.unlink(missing_ok=True)
                    break
                except PermissionError:  # Windows: another region is reading it
                    self.platform.sleep(1)

    SLOT_CLAIM_SECONDS = 60

    def slot_from_before_boot(self, lock):
        """A slot taken before the machine last started: its holder is gone, whatever process
        has its pid now (waiters sat out the whole wait on a reused pid)."""
        try:
            return self.booted_since(lock.stat().st_mtime)
        except OSError:
            return False

    def slot_holder(self, lock):
        """The pid written in a group slot lock: 0 when it is empty or unreadable,
        None when it is gone."""
        try:
            return int(lock.read_text(encoding='utf-8').strip() or 0)
        except FileNotFoundError:
            return None
        except (OSError, ValueError):
            return 0

    def stage_work(self, operation):
        try:
            if self.stage_lock.read_text().strip() != operation:
                return
        except OSError:
            return
        ready = False
        try:
            self.stage_record(phase='checking for updates', error=None, install=None,
                              worker={'pid': os.getpid(), 'started': int(time.time())})
            latest = self.latest_revision()
            if not HEX40.match(latest):
                raise RuntimeError('could not read the latest revision')
            if self.built_revision() == latest:
                self.stage_record(phase='current', revision=latest)
                return
            if self.staged_revision() == latest:
                self.stage_record(phase='ready', revision=latest)
                ready = True
                return
            group = load_group(self.config['group_config'])
            region = next(r for r in group['regions'] if r['id'] == self.config['region'])
            path = self.stage_dir()
            with self.compile_slot():
                # The slot can take a while to come round, and master often moves meanwhile
                # (deploy.bat pulls before it stages, so a stage the host service queued earlier
                # would otherwise build the revision of its queueing and hand over onto that).
                # Build what the group revision names now; this reads the local refs only.
                try:
                    newest = self.git_text(['rev-parse', group['revision']], group['repository'])
                except RuntimeError:
                    newest = latest
                if HEX40.match(newest or '') and newest != latest:
                    latest = newest
                    if self.built_revision() == latest:
                        self.stage_record(phase='current', revision=latest)
                        return
                    if self.staged_revision() == latest:
                        self.stage_record(phase='ready', revision=latest)
                        ready = True
                        return
                if not (path / '.git').exists():
                    if path.exists() and any(path.iterdir()):
                        raise RuntimeError('%s exists and is not a staging worktree' % path)
                    path.parent.mkdir(parents=True, exist_ok=True)
                    code, out = self.platform.run([self.config['git'], 'worktree', 'add', '--detach', str(path), latest],
                                                  cwd=group['repository'], timeout=600)
                    if code != 0:
                        raise RuntimeError('staging worktree failed: ' + out.strip()[-300:])
                self.stage_record(phase='preparing', revision=latest)
                gaia_host.remove_file(self.staged_file)
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
            ready = True
        except Exception as error:  # stage.json is the only place a detached worker can report
            self.stage_record(phase='failed', error=str(error)[:500])
        finally:
            install = self.install_marker.exists()
            gaia_host.remove_file(self.install_marker)
            self.urgent_marker().unlink(missing_ok=True)
            gaia_host.remove_file(self.stage_lock)
            if install and ready:
                self.install_after_stage()

    # -- updating an empty region -------------------------------------------------
    # Val (2026-11-13): once the last player leaves and the world has saved, a region with an
    # update waiting shuts down, takes the new build and starts again. The update is built
    # beside the running world first (stage), so a failed build never takes it down and a
    # player who joins meanwhile is never kicked: the restart waits until it is empty again.
    def update_settings(self):
        """(update_when_empty, update_check_minutes) from the group config, read at each check
        so the launcher's toggle applies without a setup or a host service restart."""
        try:
            group = load_group(self.config['group_config'])
            return group['update_when_empty'], group['update_check_minutes']
        except (OSError, ValueError, KeyError):
            return False, DEFAULT_UPDATE_CHECK_MINUTES

    def update_when_empty(self):
        return self.update_settings()[0]

    def region_kind(self):
        """This region's kind from the group config (read at each check), or None."""
        try:
            group = load_group(self.config['group_config'])
        except (OSError, ValueError, KeyError):
            return None
        return next((r['kind'] for r in group['regions'] if r['id'] == self.config['region']), None)

    def is_gateway(self):
        return self.region_kind() == 'GATEWAY'

    def always_up(self):
        return self.region_kind() in ALWAYS_UP_KINDS

    def may_sleep(self):
        # The gateway is every player's way in and the group's hub entry: a frozen world
        # stops answering the hub and holds each join until it thaws, so it stays awake.
        # The tutorial stays awake too, so it opens at once even while the lands are down.
        # The mainland never sleeps either (Val, 2026-11-21): it is where new players start
        # and the land everyone else's trails lead back to.
        return not self.always_up() and not self.protects_mainland_uptime()

    def protects_mainland_uptime(self):
        try:
            return load_group(self.config['group_config'])['mainland'] == self.config['region']
        except (OSError, ValueError, KeyError):
            return True  # a missing policy must not turn an automatic update into a restart

    def automatic_start_action(self):
        # The gateway is every player's way in: a watchdog start brings it back on the build it
        # has instead of compiling first; updates reach it by its empty-world restart.
        if self.protects_mainland_uptime() or self.always_up():
            return 'start-current'
        return super().automatic_start_action()

    def keep_down(self):
        """The region's keep_down in the group config (read at each check): a person kept it
        down on purpose, so a traveller bound for it is turned back instead of starting it."""
        try:
            group = load_group(self.config['group_config'])
        except (OSError, ValueError, KeyError):
            return True  # an unreadable policy must not start a world
        return next((bool(r.get('keep_down')) for r in group['regions'] if r['id'] == self.config['region']), True)

    def readiness(self):
        """How this region takes part in keeping lands ready (doorman.Doorman.keep_ready), or None
        when it does not: the group turned it off, or the region is not in the world links table.
        exempt: never put in cold storage and always kept ready (the mainland, the always-up kinds
        and the oceans around the mainland)."""
        try:
            group = load_group(self.config['group_config'])
        except (OSError, ValueError, KeyError):
            return None
        if not group.get('ready_neighbours', True):
            return None
        region_id = self.config['region']
        region = next((r for r in group['regions'] if r['id'] == region_id), None)
        links = world_neighbours()
        if region is None or region_id not in links:
            return None
        ids = {r['id'] for r in group['regions']}
        mainland = group['mainland']
        exempt = (region_id == mainland or region['kind'] in ALWAYS_UP_KINDS
                  or (region['kind'] == 'OCEANIC' and mainland in links.get(region_id, ())))
        return {'group': group['group'], 'region': region_id, 'neighbours': sorted(links[region_id] & ids),
                'exempt': exempt, 'cold_after_minutes': group.get('cold_after_minutes', 15)}

    def travel_start_refusal(self):
        if not (self.repo / '.git').exists():
            return 'not set up'
        if fresh_world.pending(self).exists():
            return 'fresh-world archive needs recovery'
        if self.holds_its_port():
            return 'the gateway is started by the host service only'
        return super().travel_start_refusal()

    def idle_update_action(self):
        if self.holds_its_port():
            return None
        if not self.protects_mainland_uptime():
            return super().idle_update_action()
        try:
            return ('auto-handover' if load_group(self.config['group_config'])['persistent']
                    and not self.failed_staged_handover() else None)
        except (OSError, ValueError, KeyError):
            return None

    def install_staged_while_down(self):
        if self.protects_mainland_uptime():
            return False
        return super().install_staged_while_down()

    def failed_staged_handover(self):
        last = self.read_state()
        staged = self.staged_revision()
        rejected = self.read_json(self.failed_handover_file) or {}
        return bool(staged and (rejected.get('revision') == staged or
                    (last.get('action') in ('handover', 'auto-handover', 'update-handover') and last.get('phase') == 'failed'
                     and not last.get('retryable') and last.get('revision') == staged)))

    def stage_if_behind(self):
        """Stage the latest revision when the region's build is behind it; at most once per
        update_check_minutes (each check fetches). True when a stage was started."""
        if self.holds_its_port():
            return False
        now = self.platform.now()
        if now < self.next_update_check or self.stage_running():
            return False
        self.next_update_check = now + self.update_settings()[1] * 60
        try:
            latest = self.latest_revision()
        except (Refused, RuntimeError, OSError) as error:
            self.log({'update_check_failed': str(error)[:300]})
            return False
        if not HEX40.match(latest or '') or latest == self.built_revision() or latest == self.staged_revision():
            return False
        stage = self.read_json(self.stage_file) or {}
        if stage.get('phase') == 'failed' and stage.get('revision') == latest:
            return False  # that build already failed; a new commit or a Build update tries again
        try:
            self.log(dict(self.request_stage(), reason='update available', revision=latest))
        except Refused as refusal:
            self.log({'update_stage_refused': str(refusal)})
            return False
        return True

    def update_while_empty(self):
        """An awake region that is empty and saved: hand over to a ready update, or build the
        latest revision beside it. The next wait, or None to carry on towards sleep.

        Unattended updates always hand over rather than restart: the save is backed up, then
        the new build loads it beside the running world, and only a load that succeeds takes
        the region's port. A save the new code cannot read (such as a timer it no longer
        knows) fails that load and the old world plays on, so no unattended update can leave
        a region down on a broken load."""
        if self.holds_its_port():
            return None
        try:
            if not load_group(self.config['group_config'])['persistent']:
                # A TDM world in pregame reports no round yet, which reads as saving; it has
                # no save to hand over (update_unsaved_while_empty covers these groups).
                return None
        except (OSError, ValueError, KeyError):
            return None
        if self.update_pending():
            now = self.platform.now()
            if now < self.next_install_attempt:
                return None
            if self.failed_staged_handover():
                return None  # this build already failed to take over (its load or save failed); a person looks
            try:
                self.log(dict(self.request('auto-handover'), reason='installing the update while the world is empty'))
            except Refused as refusal:
                # Low memory, a busy world, ...: try again after the next check interval, never
                # by a plain restart, which would load the save on the new build unchecked.
                self.next_install_attempt = now + self.update_settings()[1] * 60
                self.log({'empty_handover_refused': str(refusal)})
                return None
            return 30
        if self.stage_running():
            return 30  # an update is building: restart onto it once it is ready, rather than sleep
        return 30 if self.stage_if_behind() else None

    # Val (2026-11-18): civ13.com's TDM servers update between rounds whenever they can. The
    # battle world takes the update with its next map at the end of each round
    # (battle_mapswap.py); a world that never saves and is empty (the barracks while everyone
    # is in the battle) has no save to load, so it restarts onto an update built beside it.
    def holds_its_port(self):
        """The gateway never stages a build (Val, 2026-11-21: it must always stay on its port):
        the host service never stages, updates or restarts it, and group-wide actions leave
        it running. It takes new code only when a person names it (restart --region ID)."""
        return self.region_kind() == 'GATEWAY'

    def update_unsaved_while_empty(self):
        """An awake, empty region of a group that does not save (TDM): restart onto a ready
        update, or build the latest revision beside it. The next wait, or None."""
        if self.holds_its_port():
            return None
        try:
            group = load_group(self.config['group_config'])
        except (OSError, ValueError):
            return None
        region = next((r for r in group['regions'] if r['id'] == self.config['region']), None)
        always_up = bool(region) and region['kind'] in ALWAYS_UP_KINDS
        if (group['persistent'] and not always_up) or not region or region['kind'] == 'BATTLE' or self.protects_mainland_uptime():
            return None  # saving groups hand over instead; a battle updates when its round ends
        if not self.battle_moved_on(group):
            # Val (2026-11-18): a restart per merge pinged Discord every few minutes. The
            # barracks follows the battle instead: once per round, after the battle took an update.
            return None
        if self.update_pending():
            now = self.platform.now()
            if now < self.next_install_attempt or self.battle_ending(group):
                return None
            staged = self.staged_revision()
            last = self.read_state()
            if (self.unsaved_install == staged and last.get('action') == 'restart'
                    and last.get('phase') == 'failed'):
                return None  # this build already failed to start; a person looks
            try:
                self.log(dict(self.request('restart'), reason='installing the update while the world is empty'))
            except Refused as refusal:
                self.next_install_attempt = now + self.update_settings()[1] * 60
                self.log({'empty_restart_refused': str(refusal)})
                return None
            self.unsaved_install = staged
            return 30
        if self.stage_running():
            return 30
        return 30 if self.stage_if_behind() else None

    def battle_moved_on(self, group):
        """Whether the group's battle world runs a revision this region's build lacks (it took
        an update at the end of its last round). True for a group without a battle world."""
        battles = [r for r in group['regions'] if r['kind'] == 'BATTLE']
        if not battles:
            return True
        built = self.built_revision()
        try:
            battle = self.git_text(['rev-parse', 'HEAD'], region_dir(group, battles[0]['id']))
        except (RuntimeError, OSError):
            return False
        if not HEX40.match(battle or '') or battle == built:
            return False
        if not built:
            return True
        code, _ = self.platform.run([self.config['git'], 'merge-base', '--is-ancestor', battle, built],
                                    cwd=self.repo, timeout=60)
        return code != 0

    @staticmethod
    def battle_ending(group):
        """Whether a battle world of the group is between rounds (its next map is building),
        when its players are on their way back here: a restart now would drop them."""
        for region in group['regions']:
            if region['kind'] != 'BATTLE':
                continue
            try:
                state = json.loads((region_dir(group, region['id']) / 'data' / 'shard-host' / 'rotation.json')
                                   .read_text(encoding='utf-8'))
            except (OSError, ValueError):
                continue
            if isinstance(state, dict) and state.get('state') == 'building':
                return True
        return False

    def keep_sleeper_current(self):
        """An asleep or cold region: build the latest revision, so it is ready for a handover
        once the region is awake, empty and saved again (an asleep region keeps its old build
        until then), or for a cold region's next start."""
        if self.update_when_empty():
            self.stage_if_behind()

    def update_asleep(self):
        """Update an asleep region without waking it (Val, 2026-11-13: asleep regions must be
        able to take the new update). A ready build is copied in at once: the world saved before
        it froze, so it is stopped and starts from that save on the new build at its next wake.
        Otherwise the update is built beside it while it keeps sleeping (it can still wake at
        once) and installed the same way as soon as the build is ready."""
        if self.update_pending():
            return dict(self.install_into_sleeper(), state='asleep')
        self.state_dir.mkdir(parents=True, exist_ok=True)
        self.install_marker.write_text('update\n', encoding='utf-8')
        try:
            return dict(self.request_stage(urgent=True), state='asleep')
        except Refused as refusal:
            if 'already being staged' in str(refusal):
                # The running stage installs it when it finishes (it reads the marker last).
                return {'accepted': True, 'action': 'stage', 'state': 'asleep', 'already_staging': True}
            gaia_host.remove_file(self.install_marker)
            raise

    def install_into_sleeper(self, close_seconds=60):
        """Stop an asleep region (it saved before it froze), wait for its port to close, then
        run update, which copies the ready build in; it starts on it at its next wake."""
        self.evict('installing the update')
        deadline = self.platform.now() + close_seconds
        while self.platform.listening(self.config['port']):
            if self.platform.now() > deadline:
                raise Refused('the stopped world kept its port open; it gets the update from the host service')
            self.platform.sleep(1)
        return Host.request(self, 'update')

    def install_after_stage(self):
        """update-offline: copy the build just staged into a region that is still not running,
        so its next start loads at once. An asleep region is stopped first (it saved before it
        froze) and wakes on the new build. A region that started meanwhile is left alone; it
        gets the build at its next empty restart, as after any stage."""
        try:
            if self.frozen():
                if self.update_pending():
                    self.install_into_sleeper()
                    self.stage_record(install='installing')
                return
            if self.platform.listening(self.config['port']):
                raise Refused('the region started while its update was building')
            if self.update_pending():
                self.request('update')
                self.stage_record(install='installing')
        except Refused as refusal:
            self.stage_record(install='not installed: %s' % str(refusal)[:200])

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
        if fresh_world.pending(self).exists():
            raise Refused('interrupted fresh-world archive: manual recovery required before any host action')
        # Checked before the lock: taking it would create the folder setup needs empty.
        if action in ('start', 'start-current', 'restart', 'update', 'handover', 'auto-handover', 'update-unsaved', 'update-handover') and not (self.repo / '.git').exists():
            raise Refused('the region is not set up; run setup first')
        if action == 'update' and self.frozen():
            # Host.request would wake it first, only to refuse it as running.
            return self.update_asleep()
        if action == 'update' and self.platform.listening(self.config['port']):
            raise Refused('stop the region before updating')
        return super().request(action)

    def remember_failed_handover(self):
        # Called under the action lock, before replacing or after writing operation state.
        last = self.read_state()
        if (last.get('action') in ('handover', 'auto-handover', 'update-handover') and last.get('phase') == 'failed'
                and not last.get('retryable') and last.get('revision') == self.staged_revision()
                and last.get('revision')):
            self.write_json(self.failed_handover_file, {'revision': last['revision']})

    def before_action_accepted(self, action):
        self.remember_failed_handover()

    def action_failed(self, action):
        self.remember_failed_handover()

    def action_succeeded(self, action):
        if action in ('handover', 'update-handover'):
            # Keep the rejection through an early failure; only a completed retry clears it.
            gaia_host.remove_file(self.failed_handover_file)

    def watch_step(self, idle_since):
        if fresh_world.pending(self).exists() or (self.lock.exists() and self.read_state().get('action') == 'fresh-world'):
            return None, 30
        return super().watch_step(idle_since)

    def thaw(self, *args, **kwargs):
        if fresh_world.pending(self).exists() or (self.lock.exists() and self.read_state().get('action') == 'fresh-world'):
            raise Refused('fresh-world archive blocks wake until it finishes or is recovered')
        return super().thaw(*args, **kwargs)

    def do_start(self, operation):
        if fresh_world.pending(self).exists():
            raise Refused('interrupted fresh-world archive: manual recovery required')
        return super().do_start(operation)

    def precheck(self, action):
        # start compiles a missing or stale build itself (Host.do_refresh), so a
        # region with no build yet is not refused.
        if action in ('handover', 'auto-handover'):
            return self.precheck_handover()
        if action == 'start-current' and not self.built_revision():
            raise Refused('the current region build is missing or changed; manual recovery is required')
        if action == 'update-handover':
            # The build is made by the action itself; the handover checks run once it is ready.
            if self.frozen():
                raise Refused('the region is asleep; use Update, which installs the new build while it sleeps')
            return super().precheck('restart')
        super().precheck(action)

    # -- update and restart (in game, launcher) -------------------------------------
    def extra_steps(self, action):
        # The update is built beside the running world first; only a ready build ends it.
        steps = {'update-unsaved': [self.wait_for_build, self.do_kill_unsaved, self.do_update, self.stop_if_killed, self.do_start],
                 'update-handover': [self.wait_for_build, self.do_handover_if_behind]}
        return steps[action]

    BUILD_WAIT_SECONDS = 7200

    def wait_for_build(self, operation):
        """Build the latest revision beside the running world (stage) and wait until it is
        ready. Nothing is stopped yet: a failed build leaves the world running."""
        self.record(phase='checking for updates')
        latest = self.latest_revision()
        if not HEX40.match(latest or ''):
            raise RuntimeError('could not read the latest revision; the world was left running')
        if self.built_revision() == latest or self.staged_revision() == latest:
            self.record(revision=latest)
            return
        try:
            self.request_stage(urgent=True)
        except Refused as refusal:
            if 'already being staged' not in str(refusal):
                raise RuntimeError('%s; the world was left running' % refusal)
        self.record(phase='building the update beside the running world', revision=latest)
        deadline = self.platform.now() + self.BUILD_WAIT_SECONDS
        while self.stage_running():
            if self.platform.now() > deadline:
                raise RuntimeError('the update took too long to build; the world was left running')
            self.platform.sleep(10)
        if self.built_revision() == latest or self.staged_revision() == latest or self.update_pending():
            return
        stage = self.read_json(self.stage_file) or {}
        raise RuntimeError('the update did not build (%s); the world was left running'
                           % (stage.get('error') or stage.get('phase') or 'no ready build'))

    def do_handover_if_behind(self, operation):
        """Hand the world over to the build wait_for_build made ready (players keep playing
        while the new build loads the save), or nothing when it already runs it."""
        if not self.update_pending():
            self.record(phase='already on the latest build')
            return
        try:
            self.precheck_handover()
        except Refused as refusal:
            raise RuntimeError('%s; the world was left running on its old build' % refusal)
        self.do_handover(operation)

    def set_update_when_empty(self, enabled):
        """The group's update_when_empty switch (the launcher's Update when empty...), written
        into the group config; it applies to every region at its next check."""
        path = Path(self.config['group_config'])
        try:
            raw = json.loads(path.read_text(encoding='utf-8-sig'))
        except (OSError, ValueError) as error:
            raise Refused('could not read the group config: %s' % str(error)[:200])
        if not isinstance(raw, dict):
            raise Refused('the group config is not an object')
        raw['update_when_empty'] = bool(enabled)
        if enabled and not (isinstance(raw.get('fetch'), str) and raw['fetch']):
            # As the launcher's toggle does: without a fetch, new commits would only show up
            # after the host's checkout is pulled by hand.
            raw['fetch'], raw['revision'] = 'origin', 'origin/master'
        write_json_atomic(path, raw)
        load_group(str(path))  # still valid

    def host_status(self):
        report = super().host_status()
        stage = self.read_json(self.stage_file)
        if stage and not self.stage_failure_superseded(stage):
            report['stage'] = {key: stage.get(key) for key in ('phase', 'revision', 'error', 'updated')}
        report['staged'] = self.staged_revision()
        try:
            group = load_group(self.config['group_config'])
            report['group'] = group['group']
            report['shutdown_warning_seconds'] = group['shutdown_warning_seconds']
        except (OSError, ValueError, KeyError):
            pass
        return report

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
        if self.always_up():
            return  # it restarts on its own port (do_handover): no standby, no second world in memory
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

    def do_start_current(self, operation):
        if not self.built_revision():
            raise RuntimeError('the current region build is missing or changed')
        self.do_start(operation)

    def startup_revision(self):
        if self.read_state().get('action') == 'start-current':
            return self.built_revision() or ''
        return super().startup_revision()

    def do_auto_handover(self, operation):
        self.do_handover(operation, automatic=True)

    def do_handover(self, operation, automatic=False):
        group = load_group(self.config['group_config'])
        region = next(r for r in group['regions'] if r['id'] == self.config['region'])
        revision = self.staged_revision()
        if not revision or not self.update_pending():
            raise RuntimeError('no staged build newer than the running one')
        if region['kind'] in ALWAYS_UP_KINDS:
            # The hub lists a world by the port its DreamDaemon was started on; a standby
            # that takes the port over with world.OpenPort is not listed again. The gateway
            # and the tutorial keep nothing, so they restart on their own port onto the
            # staged build instead.
            if automatic and (self.world() or {}).get('clients'):
                raise RuntimeError('players are in the %s; automatic update deferred' % region['kind'].lower())
            self.record(phase='restarting the %s on its own port' % region['kind'].lower(), revision=revision)
            with self.handover_slot():
                self.do_stop(operation)
                self.do_update(operation)
                self.do_start(operation)
            self.record(phase='restarted onto the staged build', revision=revision, staged=True)
            return
        port, spare_port, token = self.config['port'], self.standby_port(), self.token()
        before = self.world()
        if not token or not before:
            raise RuntimeError('the world does not answer lifecycle status')
        session = before.get('session', '')
        if not gaia_host.HEX32.match(session or ''):
            raise RuntimeError('the world gave no valid session')
        if self.platform.listening(spare_port):
            raise RuntimeError('port %d (the standby port) is in use' % spare_port)
        if automatic and not guards_empty_handover(before):
            self.record(revision=revision)
            raise RuntimeError('the running build cannot guard an empty handover; automatic update deferred')
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
            if automatic:
                before = self.world()
                if not before or before.get('busy') or not before.get('ready') or before.get('clients') != 0:
                    raise RuntimeError('the world is not confirmed empty and ready; automatic update deferred')
                if not self.saved_since_last_client():
                    raise RuntimeError('the world has not saved since the last player; automatic update deferred')
                session = before.get('session', '')
                if not gaia_host.HEX32.match(session or '') or not guards_empty_handover(before):
                    raise RuntimeError('the world no longer supports a safe handover')
            self.handover_work(operation, group, region, revision, port, spare_port, token, before, session, automatic)

    def handover_work(self, operation, group, region, revision, port, spare_port, token, before, session, automatic=False):
        if self.platform.listening(spare_port):
            raise RuntimeError('port %d (the standby port) is in use' % spare_port)
        spare = self.spare_dmb_name()
        self.record(phase='copying the staged build', revision=revision, build=spare, standby_port=spare_port)
        source = self.stage_dir()
        for name in STAGED_OUTPUTS:
            target = self.repo / (spare[:-4] + name[-4:])  # region.b.dmb, region.b.rsc
            temporary = self.repo / (target.name + '.staged')
            shutil.copy2(source / name, temporary)
            gaia_host.replace_file(temporary, target)
        self.record(phase='booting the standby')
        standby_pid = self.platform.start_standby(spare, spare_port)
        # A standby prepares the whole map before it waits, so a large land
        # (North America, 2026-11-16) can need longer than an empty boot. A
        # standby that never comes up is stopped here: left running, it holds
        # region.rsc and the next build fails on locked icons.
        boot_timeout = max(self.config['start_timeout_seconds'], self.config.get('load_timeout_seconds', 0))
        try:
            standby = self.wait_world(spare_port, token, lambda s: s.get('standby') == 'waiting',
                                     boot_timeout, 'the standby world did not boot', standby=True)
        except BaseException:
            self.stop_standby(spare_port, standby_pid)
            raise
        standby_session = standby.get('session', '')
        if not gaia_host.HEX32.match(standby_session or ''):
            self.stop_standby(spare_port, standby_pid)
            raise RuntimeError('the standby world gave no valid session')
        generation = None
        backup = None
        try:
            if automatic:
                before = self.world()
                if (not before or before.get('busy') or not before.get('ready') or before.get('clients') != 0
                        or before.get('session') != session or not guards_empty_handover(before)
                        or not self.saved_since_last_client()):
                    self.record(retryable=True)
                    raise RuntimeError('the world is no longer confirmed empty and ready; automatic update deferred')
            warning = self.shutdown_warning()
            if before.get('clients') and warning and before.get('shutdown_warning'):
                self.record(phase='warning players (%d s), then saving' % warning, clients=before.get('clients'))
            else:
                self.record(phase='saving', clients=before.get('clients'))
            fields = gaia_host.warning_fields(before, warning)
            if automatic:
                fields = {**(fields or {}), 'only_if_empty': '1'}
            answer = (self.platform.query(port, token, 'handover_save', operation, session, extra=fields) if fields
                      else self.platform.query(port, token, 'handover_save', operation, session))
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
            # The backup copies while the standby loads (Val, 2026-11-13: the copy before the
            # load added to the pause). Both only read map_saves; the switch waits for it.
            backup = self.start_backup(saves, backups, operation)
            self.record(phase='loading the standby', generation=generation, backup=str(backups / operation))
            answer = self.ask_world(spare_port, token, 'standby_load', operation, standby_session,
                                    taken=lambda s: s.get('operation') == operation,
                                    untaken=lambda s: s.get('standby') == 'waiting')
            if answer.get('operation') != operation:
                raise RuntimeError('the standby world did not accept the load: %s' % (answer.get('error') or 'no operation in its reply'))
            self.wait_world(spare_port, token, lambda s: s.get('ready') and not s.get('restart_hold'),
                            self.config['load_timeout_seconds'], 'the standby world did not load the save in time',
                            standby=True)
            self.finish_backup(backup)
        except Exception as error:
            if automatic and isinstance(error, gaia_host.LifecycleRefused) and error.code == 'handover_players_arrived':
                self.record(retryable=True)
            if backup is not None:
                backup.join()  # never leave a copy running into the next handover
            # The old world is still running: stop the standby and release the freeze.
            self.record(phase='rolling back', error=str(error)[:500])
            self.stop_standby(spare_port, standby_pid)
            try:
                self.platform.query(port, token, 'handover_cancel', operation, session)
            except (OSError, RuntimeError, ValueError):
                pass
            raise
        # The switch: from here the standby is the region, unless a person force-stopped it.
        try:
            self.stop_if_killed(operation)
        except RuntimeError:
            self.stop_standby(spare_port, standby_pid)
            raise
        self.record(phase='switching')
        try:
            self.ask_world(port, token, 'handover_release', operation, session,
                           taken=lambda s: s.get('handover') == 'released', untaken=lambda s: s.get('handover') == 'saved',
                           gone_is_taken=True)
        except Exception as error:
            if automatic and isinstance(error, gaia_host.LifecycleRefused) and error.code == 'handover_players_arrived':
                self.record(retryable=True)
            # Not released: the old world stays the region, so the loaded standby must not keep
            # its port (the next handover would be refused with the standby port in use).
            self.stop_standby(spare_port, standby_pid)
            try:
                self.platform.query(port, token, 'handover_cancel', operation, session)
            except (OSError, RuntimeError, ValueError):
                pass
            raise
        # world.OpenPort on a port another process still holds fails and closes the standby's
        # own port (measured on 516.1688), so the old world's port must be free first.
        deadline = self.platform.now() + SWITCH_SECONDS
        killed = False
        while self.platform.listening(port):
            if self.platform.now() > deadline:
                pid = self.platform.server_pid(port)
                if pid and not killed:
                    self.platform.kill_tree(pid, expect=self.world_expect())
                    killed = True
                    deadline = self.platform.now() + 30
                    continue
                self.stop_standby(spare_port, standby_pid)
                raise RuntimeError('the old world kept port %d; %s' % (port, STANDBY_ENDED))
            self.platform.sleep(2)
        # The region is offline from here until the standby opens its port, so keep trying for
        # a while. Each try uses the session the standby reports now: on 2026-11-08 every
        # standby_open after a live Gaia load was refused for a minute and the region stayed
        # down, then one sent with the session read back from its status succeeded at once.
        deadline = self.platform.now() + OPEN_SECONDS
        while True:
            if self.killed_during(operation):
                self.stop_standby(spare_port, standby_pid)
                self.stop_if_killed(operation)
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
                if self.platform.listening(port):
                    # The old world left this port, so whatever serves it now is the standby: it
                    # switched and only its reply was lost. It is the region, never to be ended.
                    self.record(open_reply_lost=str(error)[:200])
                    break
                if self.platform.now() > deadline:
                    self.stop_standby(spare_port, standby_pid)
                    raise RuntimeError('the new world did not open port %d (%s); %s' % (port, error, STANDBY_ENDED))
                self.platform.sleep(3)
        deadline = self.platform.now() + 60
        while not self.platform.listening(port):
            if self.platform.now() > deadline:
                self.stop_standby(spare_port, standby_pid)
                raise RuntimeError('the new world did not open port %d; %s' % (port, STANDBY_ENDED))
            self.platform.sleep(2)
        self.stop_if_killed(operation)  # a forced stop now must not leave running.json for the watchdog
        self.mark_running()
        gaia_host.remove_file(self.freeze_file)
        gaia_host.remove_file(self.cold_file)
        self.clear_watchdog_holds()
        (self.repo / 'config' / 'lifecycle-revision.txt').write_text(revision + '\n', encoding='utf-8')
        self.record_build(revision, spare)
        self.write_server_build(revision, self.repo / spare)
        self.write_player_changelog(revision)
        self.record(phase='checking out', revision=revision)
        try:  # the sources beside the new build; the world itself needs nothing from them
            prepare_tree(group, region, self.repo, revision, self.platform, self.config['git'])
        except (OSError, RuntimeError) as error:
            self.record(checkout_warning=str(error)[:300])
        self.record(phase='handed over', revision=revision, generation=generation, build=spare, staged=True)

    def ask_world(self, port, token, action, operation, session, taken, untaken, gone_is_taken=False):
        """Send a handover request that a busy world may answer late. A request that gets no
        reply in time (OSError: a timeout or reset, not a refusal) is checked through status:
        taken(status) means the world took it, untaken(status) that it did not, so it is sent
        again. A refusal raises at once. Returns the reply or the status that showed it taken."""
        deadline = self.platform.now() + ASK_SECONDS
        while True:
            try:
                return self.platform.query(port, token, action, operation, session)
            except OSError as error:
                self.record(phase='%s got no reply in time (%s); checking the world' % (action, error))
                last = error
            while True:
                if self.platform.now() > deadline:
                    raise RuntimeError('%s: the world did not answer (%s)' % (action, last))
                self.platform.sleep(5)
                if not self.platform.listening(port):
                    if gone_is_taken:
                        return {'ok': True}
                    continue
                try:
                    status = self.platform.query(port, token)
                except (OSError, RuntimeError, ValueError):
                    continue  # still busy
                if taken(status):
                    return status
                if untaken(status):
                    break  # send it again

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

    def kill(self, reason='forced stop', keep_running=False):
        """A forced stop during a handover also ends its standby, so the update cannot bring
        back a region a person stopped; the handover sees killed.json and gives up."""
        handing_over = self.lock.exists() and self.read_state().get('action') in ('handover', 'auto-handover', 'update-handover')
        if handing_over:
            self.note_kill_during_action(reason)
            standby = self.stop_standby(self.standby_port())
            if not (self.frozen() or self.platform.server_pid(self.config['port'])):
                if not keep_running:
                    gaia_host.remove_file(self.running_file)
                return {'killed': True, 'pid': standby, 'reason': reason, 'released_locks': [], 'standby': standby}
        return super().kill(reason, keep_running)

    def start_backup(self, saves, backups, operation):
        """Copy the save to backups/operation in a thread, then drop the oldest beyond backups_kept."""
        keep = self.config['backups_kept']

        def copy():
            try:
                gaia_host.copy_save(saves, backups / operation)
                kept = sorted((p for p in backups.iterdir() if p.is_dir()), key=lambda p: p.stat().st_mtime)
                for old in kept[:-keep]:
                    shutil.rmtree(old)
            except BaseException as error:  # reported by finish_backup
                worker.error = error
        worker = threading.Thread(target=copy, name='handover-backup', daemon=True)
        worker.error = None
        worker.start()
        return worker

    def finish_backup(self, worker):
        """Wait for the backup; a failed one stops the handover before the switch."""
        if self.read_state().get('phase') == 'loading the standby':
            self.record(phase='finishing the backup')
        worker.join()
        if worker.error is not None:
            raise RuntimeError('the save could not be backed up: %s' % worker.error)

    def stop_if_killed(self, operation):
        reason = self.killed_during(operation)
        if reason:
            raise RuntimeError('%s: the region stays stopped' % reason)

    def stop_standby(self, port, pid=None):
        pid = self.platform.server_pid(port) or pid
        if pid:
            try:
                self.platform.kill_tree(pid, expect=self.world_expect())
            except (OSError, Unverified) as error:  # already gone, or not a world: left running
                self.log({'standby_not_ended': str(error)[:300], 'port': port})
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

    def do_refresh(self, operation):
        """A restart of an always-up region (the gateway, the tutorial) installs the build
        staged beside it, even when the group has moved on since: compiling the newer
        revision with the world stopped kept the TDM front door shut for 35 seconds
        (2026-11-21). The newer revision is staged beside it next and installed by the
        next empty restart. Other regions, or one with nothing staged, refresh as before."""
        staged = self.staged_revision() if self.always_up() else None
        if staged and self.update_pending():
            group = load_group(self.config['group_config'])
            region = next(r for r in group['regions'] if r['id'] == self.config['region'])
            self.record(phase='installing the staged build', revision=staged)
            prepare_tree(group, region, self.repo, staged, self.platform, self.config['git'])
            if self.platform.listening(self.config['port']):
                raise RuntimeError('the region started during the update; not installing')
            if self.install_staged(staged):
                self.record_build(staged, DMB_SLOTS[0])
                self.record(phase='compiled', revision=staged, map=region['map'], staged=True)
                return
        return super().do_refresh(operation)

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
        # Val (2026-11-15): updating every stopped region at once ran twelve DreamMakers side by
        # side and Jungle's died right after "loading interface/skin.dmf", with no error line.
        # The update now takes the group's compile slot like a stage does, and a compiler that
        # died before reporting any result is run once more.
        with self.group_slot('compile.lock', 'compile', self.record, 7200):
            self.record(phase='compiling', revision=revision)
            for attempt in range(2):
                before = dmb_mtime(path / 'region.dmb')
                code, out = self.platform.run([self.config['compiler'], 'region.dme'], cwd=path, timeout=1800,
                                              low_priority=True)
                if compile_succeeded(code, out, path / 'region.dmb', before):
                    break
                if attempt or compile_reported(out):
                    raise RuntimeError('compile failed: ' + out.strip()[-300:])
                self.record(phase='compiling (the compiler stopped without a result; trying again)',
                            revision=revision)
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


def compile_reported(out):
    """Whether DreamMaker got as far as reporting a result ("N errors"); a compiler that was
    killed or crashed while loading leaves only its loading lines."""
    return bool(re.search(r'\d+ errors?\b', out or ''))


# A checkout ended at its timeout leaves its worktree's index.lock behind, and every
# later checkout there then fails with "index.lock: File exists" (ten regions on
# 2026-11-22, after parallel checkouts of 148 commits ran past 600 s). No checkout
# holds the lock this long, so an older one is a leftover.
STALE_INDEX_LOCK_SECONDS = 1800
CHECKOUT_TIMEOUT_SECONDS = 1800


def worktree_index_lock(path):
    """The index.lock git takes for the worktree at path, or None when it cannot tell."""
    dotgit = Path(path) / '.git'
    try:
        if dotgit.is_dir():
            return dotgit / 'index.lock'
        text = dotgit.read_text(encoding='utf-8').strip()
    except OSError:
        return None
    if not text.startswith('gitdir:'):
        return None
    gitdir = Path(text[len('gitdir:'):].strip())
    if not gitdir.is_absolute():
        gitdir = Path(path) / gitdir
    return gitdir / 'index.lock'


def checkout_revision(path, revision, platform, git):
    """git checkout --force --detach revision in path, clearing an index.lock left by a
    checkout that was ended (here at its timeout, or earlier by a killed worker)."""
    lock = worktree_index_lock(path)
    if lock is not None:
        try:
            if time.time() - lock.stat().st_mtime > STALE_INDEX_LOCK_SECONDS:
                lock.unlink()
        except OSError:
            pass
    code, out = platform.run([git, 'checkout', '--force', '--detach', revision], cwd=path,
                             timeout=CHECKOUT_TIMEOUT_SECONDS)
    if code == gaia_host.TIMED_OUT and lock is not None:
        try:
            lock.unlink()  # its git was ended with the timeout, so nothing holds it
        except OSError:
            pass
    return code, out


def prepare_tree(group, region, path, revision, platform, git, live=False):
    """Check a region's worktree (or its staging worktree) out at revision and write
    everything its compile needs: overlays, the persistent config, rust_g and region.dme.

    live: the world is still running from this worktree (a TDM battle taking an update
    between rounds), so rust_g, which it has loaded, is replaced only when it changed."""
    # --force: the region's config/config.txt override below is rewritten every update.
    code, out = checkout_revision(path, revision, platform, git)
    if code != 0:
        raise RuntimeError('checkout failed: ' + out.strip()[-300:])
    apply_overlays(group, region, path)
    (path / 'config').mkdir(exist_ok=True)
    region_mode_config(group, region, path / 'config' / 'config.txt')
    if group.get('rust_g'):
        target = path / Path(group['rust_g']).name
        if not live:
            shutil.copyfile(group['rust_g'], target)
        elif not target.is_file() or target.read_bytes() != Path(group['rust_g']).read_bytes():
            # A new file under the name: the running world keeps the one it mapped.
            shutil.copyfile(group['rust_g'], target.with_name(target.name + '.new'))
            gaia_host.replace_file(target.with_name(target.name + '.new'), target)
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
    # The front door's own lines (the bot link) follow whichever region is the front door.
    front = front_dir(group) / 'config.local.txt'
    if region['id'] == front_region(group) and front.is_file():
        local.append(front)
    translator = translator_config_line(group)
    if local or translator:
        config = path / 'config' / 'config.txt'
        text = config.read_text(encoding='utf-8') if config.exists() else ''
        # The group's translator first, so a host's own CHAT_TRANSLATE_URL line (or #CHAT_TRANSLATE_URL) wins.
        if translator:
            text = merge_config(text, translator)
        for item in local:
            try:
                text = merge_config(text, item.read_text(encoding='utf-8-sig'))
            except ValueError as error:
                raise RuntimeError('%s: %s' % (item, error))
        config.parent.mkdir(parents=True, exist_ok=True)
        config.write_text(text, encoding='utf-8')
        copied.append(LOCAL_CONFIG)
    if write_operator_agent(group, path):
        copied.append(AGENT_CONTROL)
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
    restart; host.txt is read at each login. The mainland and start region in each
    region's config/shard_region.json are brought up to the group config too, so a
    world started later agrees with the coordinator (running worlds take both from
    their transfer agent within a minute)."""
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
            region_mode_config(group, region, path / 'config' / 'config.txt')
        except (RuntimeError, OSError) as error:
            refused[region['id']] = str(error)
            continue
        done[region['id']] = {'copied': copied, 'running': platform.listening(region['port']),
                              'shard_region': refresh_shard_region(group, path)}
    return done, refused


def refresh_shard_region(group, path):
    """Rewrite the mainland and start region of a region's config/shard_region.json
    when the group config moved them. True when the file changed; None without one."""
    target = path / 'config' / 'shard_region.json'
    if not target.exists():
        return None
    settings = json.loads(target.read_text(encoding='utf-8'))
    wanted = {'mainland': group['mainland'], 'start_region': group['start_region']}
    if all(settings.get(key) == value for key, value in wanted.items()):
        return False
    settings.update(wanted)
    write_json_atomic(target, settings)
    return True


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


def region_mode_config(group, region, path):
    """Set a region's round mode after its overlays: a tutorial or gateway region never
    saves, even in a persistent group; the others follow the group."""
    if region['kind'] in ('TUTORIAL', 'GATEWAY'):
        tutorial_config(path)
    elif group['persistent']:
        persistent_config(path, saving=not region.get('reset_minutes'))


def tutorial_config(path):
    """A tutorial region is an ordinary round that never saves: ALLOWED_GAMEMODES ALL
    (whatever an overlay set) and SKIP_PERSISTENCE_SAVING on."""
    lines = path.read_text(encoding='utf-8').splitlines() if path.exists() else []
    out, skip = [], False
    for line in lines:
        key = line.lstrip('#').strip().split(' ', 1)[0]
        if key == 'ALLOWED_GAMEMODES':
            continue
        if key == 'SKIP_PERSISTENCE_SAVING':
            if not skip:
                out.append('SKIP_PERSISTENCE_SAVING')
                skip = True
            continue
        out.append(line)
    out.append('ALLOWED_GAMEMODES ALL')
    if not skip:
        out.append('SKIP_PERSISTENCE_SAVING')
    path.write_text('\n'.join(out) + '\n', encoding='utf-8')


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
    if region['kind'] == 'EXPEDITION':
        # A slot with a land compiles that land; a free slot its placeholder map.
        source = expedition_slots.place_world_file(group, region, path) or source
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
            if path.exists() and any(path.iterdir()) and not set_aside_agent_leftovers(path):
                raise Refused('%s exists and is not a region worktree' % path)
            code, out = platform.run([git, 'worktree', 'add', '--detach', str(path), revision], cwd=repository, timeout=600)
            if code != 0:
                raise Refused('worktree for %s failed: %s' % (region['id'], out.strip()[-300:]))
            made.append(region['id'])
        write_region_files(group, region, path)
    result = {'revision': revision, 'created': made, 'regions': [r['id'] for r in group['regions']]}
    if region_id is not None:
        result['region'] = region_id
        result['running'] = running  # their worlds pick up the new peer list on their next start
        result['enrolled'] = enrol_region(group, region_id) if group['transfers'] else []
        if group['relay_port']:
            result['relay_ports'] = relay_add_ports(group)
    return result


def set_aside_agent_leftovers(path):
    """True when path held only what a transfer agent started before setup leaves behind
    (data/shard-host with its settings, log and records) and it was moved aside to
    <name>.agent-leftovers-<time>, so setup can make the worktree. Nothing is deleted."""
    path = Path(path)
    entries = [p for p in path.rglob('*')]
    files = [p for p in entries if p.is_file()]
    state = path / 'data' / 'shard-host'
    if not files or any(state not in f.parents for f in files):
        return False
    if any(f.suffix not in ('.json', '.log', '.pid', '.tmp') for f in files):
        return False
    stamp = time.strftime('%Y%m%d-%H%M%S', time.gmtime())
    target = path.with_name('%s.agent-leftovers-%s' % (path.name, stamp))
    number = 1
    while target.exists():
        number += 1
        target = path.with_name('%s.agent-leftovers-%s-%d' % (path.name, stamp, number))
    path.rename(target)
    return True


def write_region_files(group, region, path):
    """Write everything setup generates for one region: its shard_region.json, tokens,
    transfer agent settings and host config. Safe to repeat; existing tokens are kept."""
    (path / 'map_saves').mkdir(exist_ok=True)
    config = path / 'config'
    config.mkdir(exist_ok=True)
    settings = {'group': group['group'], 'region': region['id'], 'regions': directory(group), 'mainland': group['mainland'],
                'start_region': group['start_region'],
                'save_minutes': group['save_minutes'] if group['persistent'] and not region['reset_minutes'] and region['kind'] not in UNSAVED_KINDS else 0,
                'travel_save_seconds': group['travel_save_seconds'], 'reset_minutes': region['reset_minutes'],
                'edge_travel_oceans': group['edge_travel_oceans'],
                # The host service's doorman on this machine; regions ask it which peers
                # sleep (a direct poll would wake them) and to wake one for a traveller.
                'doorman': '127.0.0.1:%d' % group.get('doorman_port', gaia_host.FREEZE_DEFAULTS['doorman_port'])}
    if group['relay_port']:
        settings.update(relay_settings(group))
        (config / 'relay-token.txt').write_text(relay_token(group) + '\n', encoding='utf-8')
    write_json_atomic(config / 'shard_region.json', settings)  # a running world may be rereading it (reload_group)
    write_operator_agent(group, path)
    if any(r['kind'] == 'BARRACKS' for r in group['regions']) and region['kind'] in ('BARRACKS', 'BATTLE'):
        (config / 'tdm-token.txt').write_text(group_token(group, 'tdm-token.txt') + '\n', encoding='utf-8')
    if any(r['kind'] == 'EVENT' for r in group['regions']):
        # Every region: home worlds and the event world tell each other who went where.
        (config / 'event-token.txt').write_text(group_token(group, 'event-token.txt') + '\n', encoding='utf-8')
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


def sync_relay_ports(group, send=None):
    """Tell the running relay every game port of the group once per relay process and port
    list. A region added or renumbered while the relay ran (by setup, or by editing the
    group file) was otherwise unroutable until the relay restarted: players sent there got
    "the way is closed" (South America, 2026-11-15). Returns the ports sent, or None when
    nothing needed sending or no relay answered (the next pass tries again)."""
    pid = relay_pid(group)
    if not group.get('relay_port') or not pid:
        return None
    ports = sorted(region['port'] for region in group['regions'])
    state = Path(group['root']) / 'relay-ports.json'
    try:
        if json.loads(state.read_text(encoding='utf-8')) == {'pid': pid, 'ports': ports}:
            return None
    except (OSError, ValueError):
        pass
    taken = relay_add_ports(group, send)
    if taken is None or sorted(taken) != ports:
        return None
    write_json_atomic(state, {'pid': pid, 'ports': ports})
    return taken


def write_json_atomic(path, value):
    """Write value as JSON through a temporary file, so a reader never sees half a file."""
    temporary = path.with_name(path.name + '.tmp')
    temporary.write_text(json.dumps(value, indent=1) + '\n', encoding='utf-8')
    gaia_host.replace_file(temporary, path)


def guards_empty_handover(status):
    """True when a world's lifecycle status advertises the empty-handover guard.

    DM's json_encode writes TRUE as 1, so a live world reports 1 rather than JSON
    true; testing `is True` deferred every automatic handover (2026-11-22)."""
    value = (status or {}).get('handover_empty_guard')
    return value is True or (type(value) is int and value == 1)


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


AGENT_CONTROL = 'config/agent-control.txt'
OPERATOR_AGENT = 'operator'


def write_operator_agent(group, path):
    """Give the region a loopback-only host operator agent (docs/agent-control.md).

    One token for the group (root/operator-token.txt, never in an overlay or the
    repository), every scope and Host rights, so the host's own tools and LLM
    sessions on this machine can observe a region and run any admin verb there
    (tools/agent-control/civ13_agent.py with CIV13_GROUP and CIV13_REGION). The
    world re-reads the file when it changes, so no restart is needed. Other agent
    lines (from an overlay or the host) are kept. Returns True when it wrote."""
    if not group.get('operator_agent', True):
        return False
    target = Path(path) / AGENT_CONTROL
    old = target.read_text(encoding='utf-8-sig') if target.exists() else ''
    lines = [line for line in old.splitlines() if line.split()[:2] != ['agent', OPERATOR_AGENT]]
    while lines and not lines[-1].strip():
        lines.pop()
    lines.append('agent %s %s * Host' % (OPERATOR_AGENT, group_token(group, 'operator-token.txt')))
    text = '\n'.join(lines) + '\n'
    if text == old:
        return False
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding='utf-8')
    return True


def add_gateway(group, region_id=None, apply=False, platform=None):
    """The first half of putting a gateway world on the front door's port.

    Adds a GATEWAY region (maps/special/gateway.dmm, ports chosen like any omitted
    port) to the group file, sets it up and starts it on that port while the current
    front door keeps playing (with the front door stopped it is only set up). The second half is `set-gate --region <id> --apply`, which
    swaps the two worlds' ports: the gateway takes the public port (1714 on the live
    host) and stays on it, and the old front door moves behind the relay on the
    gateway's port. Without apply, only the plan. A group that already has a gateway
    gets only the next step."""
    platform = platform or Platform()
    if not group.get('relay_port'):
        raise Refused('a gateway sends players on through the routing relay, and this group has none (relay_port)')
    gate = group.get('gate')
    existing = next((r for r in group['regions'] if r['kind'] == 'GATEWAY'), None)
    if existing:
        done = gate == existing['id']
        steps = ['%s is already the gateway%s.' % (existing['name'], ' and the front door' if done else
                 '; make it the front door (set-gate --region %s --apply)' % existing['id'])]
        return {'plan': {'region': existing['id'], 'already': True, 'gate': gate, 'steps': steps, 'problems': [], 'warnings': []},
                'accepted': False, 'next': None if done else 'set-gate --region %s --apply' % existing['id']}
    region_id = region_id or 'gateway'
    if not ID.match(region_id) or any(r['id'] == region_id for r in group['regions']):
        raise Refused('%s is not a free region id' % region_id)
    path = Path(group['_path'])
    raw = json.loads(path.read_text(encoding='utf-8-sig'))
    raw['regions'].append({'id': region_id, 'name': 'Gateway', 'kind': 'GATEWAY', 'map': GATEWAY_MAP, 'public': True})
    planned = json.loads(json.dumps(raw))
    fill_ports(planned, platform.listening)
    try:
        check_group(json.loads(json.dumps(planned)), path)
    except ValueError as error:
        raise Refused(str(error))
    entry = planned['regions'][-1]
    front = next((r for r in group['regions'] if r['id'] == gate), None)
    # With the front door stopped (the whole group down for maintenance) nothing has to
    # keep playing, so the gateway is only set up; set-gate then just swaps the ports.
    offline = bool(front) and not platform.listening(front['port'])
    steps = ['Add the region %s (Gateway) on port %d%s; it never saves, never sleeps and hosts no play.'
             % (region_id, entry['port'], ', travel agent %d' % entry['transfer_port'] if entry.get('transfer_port') else ''),
             'Set it up there without starting it: %s is stopped, so the next start brings both up.' % front['name']
             if offline else
             'Set it up and start it there (the first start compiles it); %s keeps playing on port %d meanwhile.'
             % (front['name'], front['port']) if front else 'Set it up and start it there.',
             'Then run set-gate --region %s --apply: the gateway takes port %s for good and %s moves to port %d behind '
             'the relay (it is saved and started again once).' % (region_id, front['port'] if front else '?',
                                                                  front['name'] if front else 'the front door', entry['port'])]
    plan = {'region': region_id, 'port': entry['port'], 'transfer_port': entry.get('transfer_port'), 'gate': gate,
            'offline': offline, 'already': False, 'steps': steps, 'problems': [], 'warnings': []}
    if not apply:
        return {'plan': plan, 'accepted': False}
    shutil.copy2(path, unused_backup_path(path))
    write_json_atomic(path, planned)
    group = load_group(str(path))
    result = {'plan': plan, 'accepted': True, 'setup': setup(group, platform, region_id)}
    if offline:
        result['start'] = None
    else:
        (region, host), = hosts(group, region_id, platform)
        result['start'] = host.request('start')
    result['next'] = 'set-gate --region %s --apply' % region_id
    return result


def add_regions(group, apply=False, platform=None):
    """Add the Earth regions this group is missing (EARTH_REGIONS), and the slots for
    lands across the sea (EXPEDITION_SLOTS), to the group file.

    Only a group that hosts Earth (Gaia, or one of the Earth lands) is offered them; a
    region is missing when neither its id nor its map is in the group. Each is added
    stopped and set up, so the launcher lists it and the host starts it when wanted.
    Without apply, only the plan. Running regions keep playing; they learn the new
    peers on their next start."""
    platform = platform or Platform()
    maps = {r['map'] for r in group['regions']}
    ids = {r['id'] for r in group['regions']}
    if EARTH_MAINLAND_MAP not in maps and not maps & {entry[3] for entry in EARTH_REGIONS}:
        raise Refused('this group does not host Earth (no Gaia or Earth land in it)')
    missing = [entry + (None,) for entry in EARTH_REGIONS if entry[0] not in ids and entry[3] not in maps]
    missing += [(region_id, name, 'EXPEDITION', EXPEDITION_SLOT_MAP, port, transfer)
                for region_id, name, port, transfer in EXPEDITION_SLOTS if region_id not in ids]
    path = Path(group['_path'])
    raw = json.loads(path.read_text(encoding='utf-8-sig'))
    taken = {r.get(key) for r in raw['regions'] for key in ('port', 'transfer_port', 'standby_port')}
    taken |= {raw.get(key) for key in ('relay_port', 'relay_control_port', 'doorman_port')}
    for region_id, name, kind, map_path, port, transfer in missing:
        entry = {'id': region_id, 'name': name, 'kind': kind, 'map': map_path}
        if port not in taken and not platform.listening(port):
            entry['port'] = port
            taken.add(port)
        if transfer and transfer not in taken and not platform.listening(transfer):
            entry['transfer_port'] = transfer
            taken.add(transfer)
        raw['regions'].append(entry)
    planned = json.loads(json.dumps(raw))
    problems = []
    if missing:
        fill_ports(planned, platform.listening)
        try:
            check_group(json.loads(json.dumps(planned)), path)
        except ValueError as error:
            problems.append(str(error))
    added = planned['regions'][len(planned['regions']) - len(missing):] if missing else []
    steps = ['Add %s (%s) on port %d%s.' % (r['name'], r['id'], r['port'],
             ', travel agent %d' % r['transfer_port'] if r.get('transfer_port') else '') for r in added]
    if added:
        steps.append('Set each one up without starting it; start it from its region row when wanted.')
    plan = {'regions': [{'id': r['id'], 'name': r['name'], 'kind': r['kind'], 'port': r['port'],
                         'transfer_port': r.get('transfer_port')} for r in added],
            'already': not missing, 'steps': steps or ['Every Earth region is already in the group.'],
            'problems': problems, 'warnings': []}
    if not apply or not missing:
        return {'plan': plan, 'accepted': False}
    if problems:
        raise Refused(problems[0])
    shutil.copy2(path, unused_backup_path(path))
    write_json_atomic(path, planned)
    group = load_group(str(path))
    done = {}
    for r in added:
        try:
            done[r['id']] = setup(group, platform, r['id'])
        except Refused as error:
            done[r['id']] = {'refused': str(error)}
    return {'plan': plan, 'accepted': True, 'setup': done}


def relay_settings(group):
    """The shard_region.json keys a region needs to send players through the relay."""
    return {'relay': '%s:%d' % (group['public_host'], group['relay_port']),
            'relay_control': '127.0.0.1:%d' % group['relay_control_port'], 'gate': group['gate']}


def recorded_pid(path):
    """The pid a helper's pid file names while that helper can still be running, or None.

    A pid file outlives its process across a restart of the machine, and Windows soon gives
    the pid to something else: the relay, the coordinator and the other helpers then counted
    as running and were never started again. A file written before the machine last booted
    names nothing that runs now."""
    path = Path(path)
    try:
        pid = int(path.read_text(encoding='utf-8').strip())
        written = path.stat().st_mtime
    except (OSError, ValueError):
        return None
    if pid <= 0 or not process_alive(pid):
        return None
    boot = Platform().boot_time()
    return None if boot is not None and boot > written + 60 else pid


def relay_pid(group):
    return recorded_pid(Path(group['root']) / 'relay.pid')


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


def update_offline(group, only=None, platform=None):
    """Bring every region that is not running up to the latest group revision, so it is
    ready when it next starts; a running region is never stopped, woken or rebuilt.

    A stopped (or cold) region builds the update in its staging worktree, then copies it in
    (install_after_stage). An asleep region builds it the same way while it keeps sleeping,
    then is stopped (it saved before it froze) and the build copied in, so it wakes on it. The builds take turns in the
    group compile slot at low priority, so the running regions keep their CPU and memory.
    """
    accepted, skipped = {}, {}
    for region, host in hosts(group, only, platform):
        name = region['id']
        if not (host.repo / '.git').exists():
            skipped[name] = 'not set up'
            continue
        if fresh_world.pending(host).exists():
            skipped[name] = 'interrupted fresh-world archive'
            continue
        asleep = host.frozen()
        if not asleep and host.platform.listening(host.config['port']):
            skipped[name] = 'running'
            continue
        if host.lock.exists():
            skipped[name] = 'busy: %s' % (host.read_state() or {}).get('action')
            continue
        state = 'asleep' if asleep else 'cold' if host.cold() else 'stopped'
        host.state_dir.mkdir(parents=True, exist_ok=True)
        host.install_marker.write_text('update-offline\n', encoding='utf-8')
        try:
            accepted[name] = dict(host.request_stage(), state=state)
        except Refused as refusal:
            if 'already being staged' in str(refusal):
                # The running stage installs it when it finishes (it reads the marker last).
                accepted[name] = {'accepted': True, 'action': 'stage', 'state': state, 'already_staging': True}
                continue
            gaia_host.remove_file(host.install_marker)
            skipped[name] = str(refusal)
    return {'accepted': accepted, 'skipped': skipped}


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
    return recorded_pid(Path(group['root']) / 'coordinator.pid')


def coordinator_never_established(database):
    """True when coordinator.sqlite exists but its coordinator never accepted any
    group: no roster, no decided home, recovery never ready, no bootstrap asked.

    Such a database holds no authority (nothing was ever decided), so asserting a
    clean bootstrap for it is the same as for a missing file. This happens when a
    coordinator without the flag starts first on a group Fresh world just cleared
    and creates the empty store; without this, every later start keeps the group
    held and no account can join. The coordinator still quarantines if any agent
    reports an earlier epoch or train history."""
    try:
        db = sqlite3.connect(Path(database).resolve().as_uri() + '?mode=ro', uri=True)
    except sqlite3.Error:
        return False
    try:
        ledger = dict(db.execute('SELECT key, value FROM ledger'))
        homes = db.execute('SELECT count(*) FROM home').fetchone()[0]
    except sqlite3.Error:
        return False
    finally:
        db.close()
    return (ledger.get('recovery') == 'unreconciled' and ledger.get('roster') == '[]' and ledger.get('rev') == '0'
            and ledger.get('bootstrap') == '0' and homes == 0)


def ensure_coordinator(group, start=detach, refresh=False, terminate=None):
    """Start the group's relay between region agents unless it already runs.

    With refresh, a coordinator started on other code than the source on disk is
    ended and started again (see transfer_code)."""
    if not group['transfers']:
        return False
    root = Path(group['root'])
    code = transfer_code()
    # Ships' courses open lands in these (docs/expedition-slots.md); a slot added
    # to the group restarts the coordinator like new code does.
    slots = [r['id'] for r in group['regions'] if r['kind'] == 'EXPEDITION']
    agents = {r['id']: r['transfer_port'] for r in group['regions']}
    pid = coordinator_pid(group)
    if pid:
        record = read_record(root / 'coordinator.json')
        # A new mainland or start region (the launcher's Start region) restarts it too.
        # A record from before either was kept counts as the current value.
        # So does a region whose agent moved to another port (set-port --transfer-port).
        if not refresh or (record.get('code') == code and record.get('slots', []) == slots
                           and record.get('agents', agents) == agents
                           and record.get('mainland', group['mainland']) == group['mainland']
                           and record.get('start_region', group['mainland']) == group['start_region']):
            return False
        try:
            # coordinator.pid can outlive its coordinator (a reboot) and name a reused pid.
            born = (root / 'coordinator.pid').stat().st_mtime
        except OSError:
            born = None
        try:
            (terminate or Platform().terminate)(pid, expect=process_safety.python_expect(born_before=born))
        except Unverified:
            pass  # not the coordinator: the pid file was stale, so leave that process alone and start one
    database = root / 'coordinator.sqlite'
    argv = [group['python'], str(TRANSFER_TOOLS / 'coordinator.py'), '--db', str(database), '--group', group['group'],
            '--mainland', group['mainland'], '--start-region', group['start_region']]
    if not database.exists() or coordinator_never_established(database):
        # A new group, or one a group Fresh world just cleared. The coordinator
        # still quarantines if any agent reports an earlier epoch or train custody.
        argv.append('--bootstrap-new-group')
    for region in group['regions']:
        token = region_dir(group, region['id']) / 'config' / 'transfer-token.txt'
        argv += ['--region', '%s=http://127.0.0.1:%d=%s' % (region['id'], region['transfer_port'], token)]
    if slots:
        argv += ['--slots', ','.join(slots), '--expeditions', str(expedition_slots.slots_dir(group))]
    pid = start(argv, root, root / 'coordinator.log')
    (root / 'coordinator.pid').write_text('%d\n' % pid, encoding='utf-8')
    write_record(root / 'coordinator.json', pid=pid, code=code, slots=slots, mainland=group['mainland'],
                 start_region=group['start_region'], agents=agents)
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
    # The furthest-behind region is the group's line, so "current" is that region's
    # build: a region already updated must not show as "x -> x" beside its count.
    worst = max(regions.values(), key=lambda answer: answer['behind'])
    behind = worst['behind']
    reasons = sorted({answer['reason'] for answer in regions.values() if answer['reason'] and answer['behind']})
    return {'component': 'server', 'current': worst['current'], 'available': worst['available'], 'behind': behind,
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
    pid = recorded_pid(help_spool(group, region_id) / 'worker.lock' / 'pid')
    if pid:
        return pid
    started = help_dir(group) / ('%s.pid' % region_id)
    try:
        if now() - started.stat().st_mtime < HELP_STARTING_SECONDS:
            return recorded_pid(started)
    except OSError:
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
    refused = {}
    for one, pid in running.items():
        # A pid file can outlive its bridge (a reboot, a crash) and name a reused pid: end only
        # a Python process that is older than the file that names it.
        try:
            kill(pid, expect=process_safety.python_expect(born_before=help_pid_written(group, one, pid)))
        except Unverified as error:
            refused[one] = str(error)
        clear_help_lock(group, one)
    for one in ids:
        (help_dir(group) / ('%s.pid' % one)).unlink(missing_ok=True)
    result = {'stopped': stopped, 'forced': sorted(r for r in running if r not in refused)}
    if refused:
        result['not_ended'] = refused
    return result


def help_pid_written(group, region_id, pid):
    """When the newest pid file naming pid for this region's bridge was written, or None."""
    times = []
    for path in (help_spool(group, region_id) / 'worker.lock' / 'pid', help_dir(group) / ('%s.pid' % region_id)):
        try:
            if int(path.read_text(encoding='utf-8').strip()) == pid:
                times.append(path.stat().st_mtime)
        except (OSError, ValueError):
            pass
    return max(times) if times else None


# -- chat translator ---------------------------------------------------------------
# One Edge translator service (tools/edge-translator) per group, kept running by the host
# service like the Player Help bridges. It runs from its own copy under <root>/chat-translator
# (app/, with node_modules from npm ci), so region updates never pull files from under it,
# and keeps Edge's language packs in <root>/chat-translator/edge-profile.

def translator_dir(group):
    return Path(group['root']) / 'chat-translator'


def translator_stop_file(group):
    """While this exists the host service leaves the translator stopped (translator-stop)."""
    return translator_dir(group) / 'stopped'


def translator_config_line(group):
    """The CHAT_TRANSLATE_URL line every region's config gets, or None without chat_translator."""
    settings = group.get('chat_translator')
    if not settings:
        return None
    return 'CHAT_TRANSLATE_URL http://127.0.0.1:%d' % settings['port']


def translator_pid(group, now=time.time):
    return recorded_pid(translator_dir(group) / 'service.pid')


def translator_health(group, timeout=2):
    """The service's /health answer, or None when it does not answer."""
    settings = group.get('chat_translator')
    if not settings:
        return None
    try:
        with urllib.request.urlopen('http://127.0.0.1:%d/health' % settings['port'], timeout=timeout) as reply:
            answer = json.loads(reply.read(65536).decode('utf-8'))
        return answer if type(answer) is dict and answer.get('ok') is True else None
    except (OSError, ValueError):
        return None


def translator_source(group):
    """Where the service's files come from: the group repository's checkout."""
    return Path(group['repository']) / TRANSLATOR_SOURCE


def install_translator(group, run=None):
    """Copy the service's files into <root>/chat-translator/app and npm ci there when the
    lock file changed or node_modules is missing. Returns the app folder."""
    settings = group['chat_translator']
    source, app = translator_source(group), translator_dir(group) / 'app'
    app.mkdir(parents=True, exist_ok=True)
    changed = False
    for name in TRANSLATOR_FILES:
        item = source / name
        if not item.is_file():
            raise OSError('%s is missing (update the group repository)' % item)
        target = app / name
        if not target.is_file() or not filecmp.cmp(item, target, shallow=False):
            shutil.copyfile(item, target)
            changed = changed or name in ('package.json', 'package-lock.json')
    if changed or not (app / 'node_modules' / 'playwright-core' / 'package.json').is_file():
        run = run or (lambda argv, cwd: subprocess.run(argv, cwd=cwd, stdin=subprocess.DEVNULL, capture_output=True,
                                                       timeout=TRANSLATOR_INSTALL_SECONDS).returncode)
        if run([settings['npm'], 'ci', '--ignore-scripts', '--no-audit', '--no-fund'], app) != 0:
            raise OSError('npm ci failed in %s' % app)
    return app


def translator_argv(group, app):
    settings = group['chat_translator']
    argv = [settings['node'], str(app / 'edge_translator.js'), '--port', str(settings['port']),
            '--profile', settings.get('profile') or str(translator_dir(group) / 'edge-profile')]
    if settings.get('edge'):
        argv += ['--edge', settings['edge']]
    return argv


def ensure_translator(group, start=detach, install=None, now=time.time):
    """Start the translator when it is configured, not stopped on request and not running.
    Returns True when it was started."""
    if not group.get('chat_translator') or translator_stop_file(group).exists() or translator_pid(group, now):
        return False
    folder = translator_dir(group)
    folder.mkdir(parents=True, exist_ok=True)
    app = (install or install_translator)(group)
    pid = start(translator_argv(group, app), app, folder / 'service.log')
    (folder / 'service.pid').write_text('%d\n' % pid, encoding='utf-8')
    return True


def translator_status(group, now=time.time):
    settings = group.get('chat_translator')
    if not settings:
        return {'configured': False}
    pid = translator_pid(group, now)
    health = translator_health(group) if pid else None
    entry = {'configured': True, 'running': pid is not None, 'pid': pid, 'port': settings['port'],
             'stopped': translator_stop_file(group).exists(), 'answering': health is not None,
             'url': 'http://127.0.0.1:%d' % settings['port'], 'log': str(translator_dir(group) / 'service.log')}
    started = translator_dir(group) / 'service.pid'
    try:
        entry['started_seconds_ago'] = max(0, int(now() - started.stat().st_mtime)) if pid else None
    except OSError:
        entry['started_seconds_ago'] = None
    if health:
        entry['stats'] = {key: health[key] for key in ('translated', 'skipped', 'failed', 'busy', 'waiting') if type(health.get(key)) is int}
    return entry


def translator_settings(group):
    if not group.get('chat_translator'):
        raise Refused('chat_translator is not configured for this group')
    return group['chat_translator']


def translator_start(group, start=detach, install=None):
    translator_settings(group)
    translator_dir(group).mkdir(parents=True, exist_ok=True)
    translator_stop_file(group).unlink(missing_ok=True)
    return {'started': ensure_translator(group, start, install)}


def translator_stop(group, kill=None):
    """Stop the service and keep it stopped until translator-start. Worlds answer chat
    lines untranslated meanwhile (their calls fail and pause)."""
    translator_settings(group)
    folder = translator_dir(group)
    folder.mkdir(parents=True, exist_ok=True)
    translator_stop_file(group).write_text('stopped on request\n', encoding='utf-8')
    pid = translator_pid(group)
    result = {'stopped': pid is not None}
    if pid:
        pid_file = folder / 'service.pid'
        try:
            born = pid_file.stat().st_mtime
        except OSError:
            born = None
        # Node and the Edge it started; only a Node process older than its pid file.
        try:
            (kill or Platform().kill_tree)(pid, expect=process_safety.node_expect(born_before=born))
        except Unverified as error:
            result['not_ended'] = str(error)
        pid_file.unlink(missing_ok=True)
    return result


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
        gaia_host.replace_file(temporary, saves / 'validated.json')
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


def next_expedition_slot(group):
    """The next slot to add: far<N>, one past the highest far number in the group."""
    numbers = [int(r['id'][3:]) for r in group['regions'] if re.match(r'^far[0-9]{1,4}$', r['id'])]
    number = max(numbers, default=0) + 1
    return 'far%d' % number, 'Far Land %d' % number


def add_expedition_slot(group, platform=None):
    """Add one expedition slot to the group file, with ports nobody uses, and set it up
    stopped (setup --region). The coordinator is restarted with it on the next host pass
    (ensure_coordinator compares its slot list). Returns what was done."""
    platform = platform or Platform()
    path = Path(group['_path'])
    raw = json.loads(path.read_text(encoding='utf-8-sig'))
    region_id, name = next_expedition_slot(raw)
    raw['regions'].append({'id': region_id, 'name': name, 'kind': 'EXPEDITION', 'map': EXPEDITION_SLOT_MAP})
    fill_ports(raw, platform.listening)
    check_group(json.loads(json.dumps(raw)), path)
    shutil.copy2(path, unused_backup_path(path))
    write_json_atomic(path, raw)
    group = load_group(str(path))
    done = setup(group, platform, region_id)
    added = next(r for r in raw['regions'] if r['id'] == region_id)
    return {'region': region_id, 'port': added['port'], 'transfer_port': added.get('transfer_port'), 'setup': done}


def grow_expeditions(group, platform=None):
    """The coordinator asked for one more slot (<expeditions>/grow/request.json): every
    slot held a land and none was idle enough to lay up. Adds it and drops the wish.
    Never touches a running world. Returns what was done, or None with no wish."""
    wish = expedition_slots.slots_dir(group) / 'grow' / 'request.json'
    if not wish.exists():
        return None
    lock = wish.with_name('growing.lock')
    try:
        lock.touch(exist_ok=False)
    except FileExistsError:
        return {'busy': True}
    try:
        result = add_expedition_slot(group, platform)
        wish.unlink(missing_ok=True)
        return result
    finally:
        lock.unlink(missing_ok=True)


def serve_expeditions(group, start=detach, platform=None):
    """Open the lands ships' courses asked for in the group's EXPEDITION slots
    and start each once built (expedition_slots.serve). Asked for one more slot,
    the host adds it in a worker (expedition-grow)."""
    if not any(r['kind'] == 'EXPEDITION' for r in group['regions']):
        return {}
    folder = expedition_slots.slots_dir(group)
    grow = folder / 'grow'
    lock = grow / 'growing.lock'
    if (grow / 'request.json').exists() and not group_busy(group):
        if lock.exists() and time.time() - lock.stat().st_mtime > 3600:
            lock.unlink(missing_ok=True)  # a worker that died long ago
        if not lock.exists():
            start([sys.executable, '-I', '-B', str(Path(__file__).resolve()), '--config', group['_path'], 'expedition-grow'],
                  folder, folder / 'grow.log')

    def launch(region_id):
        folder.mkdir(parents=True, exist_ok=True)
        start([sys.executable, '-I', '-B', str(Path(__file__).resolve()), '--config', group['_path'], 'expedition-open',
               '--region', region_id], folder, folder / ('open-%s.log' % region_id))

    return expedition_slots.serve(group, hosts(group, platform=platform), launch)


PLAYER_ACTIVITY_MINUTES = 15


def player_activity_db(group):
    """The host's player activity database, beside coordinator.sqlite."""
    return Path(group['root']) / 'player-activity.sqlite'


def ingest_player_activity(group, now=None):
    """Reads new player activity lines from every region when the last read is
    PLAYER_ACTIVITY_MINUTES old. Returns the lines read, or None when not due."""
    now = time.time() if now is None else now
    stamp = Path(group['root']) / 'player-activity.stamp'
    if stamp.exists() and now - stamp.stat().st_mtime < PLAYER_ACTIVITY_MINUTES * 60:
        return None
    dirs = {r['id']: region_dir(group, r['id']) for r in group['regions']}
    if not any((folder / 'data' / 'player_activity').is_dir() for folder in dirs.values()):
        return None
    aggregate = player_activity_module()
    db = aggregate.connect(player_activity_db(group))
    try:
        read = aggregate.ingest(db, dirs)
        # Totals only, for the Discord bot's activity command (no account keys).
        aggregate.write_weekly(aggregate.report(db, now=now), Path(group['root']) / aggregate.WEEKLY_FILE)
    finally:
        db.close()
    stamp.write_text(str(int(now)), encoding='utf-8')
    return read


def player_activity_module():
    if str(TRANSFER_TOOLS.parents[1]) not in sys.path:
        sys.path.insert(0, str(TRANSFER_TOOLS.parents[1]))
    from tools.player_activity import aggregate
    return aggregate


def player_activity_recording(group):
    """The regions whose config/config.txt switches the recorder on (PLAYER_ACTIVITY 1)."""
    on = []
    for r in group['regions']:
        path = region_dir(group, r['id']) / 'config' / 'config.txt'
        try:
            line = active_settings(path.read_text(encoding='utf-8', errors='replace')).get('PLAYER_ACTIVITY', '')
        except OSError:
            continue
        if line.split(' ', 1)[1:] and line.split(' ', 1)[1].strip() == '1':
            on.append(r['id'])
    return on


def player_activity_report(group, now=None):
    """The launcher's Player activity window: read new lines from every region now, then
    the host report (totals by account key only; no IPs, chat or positions are recorded)."""
    now = time.time() if now is None else now
    aggregate = player_activity_module()
    dirs = {r['id']: region_dir(group, r['id']) for r in group['regions']}
    db = aggregate.connect(player_activity_db(group))
    try:
        read = aggregate.ingest(db, dirs)
        data = aggregate.report(db, now=now)
        aggregate.write_weekly(data, Path(group['root']) / aggregate.WEEKLY_FILE)
    finally:
        db.close()
    (Path(group['root']) / 'player-activity.stamp').write_text(str(int(now)), encoding='utf-8')
    text = io.StringIO()
    aggregate.print_report(data, text)
    recording = player_activity_recording(group)
    return {'db': str(player_activity_db(group)), 'read': read, 'recording': recording,
            'off': [r['id'] for r in group['regions'] if r['id'] not in recording],
            'active': data['active'], 'text': text.getvalue()}


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
        elif sync_relay_ports(group):
            started['relay_ports'] = True
    except OSError as error:
        started['relay_error'] = str(error)[:300]
    helped, help_errors = ensure_help(group, start)
    if helped:
        started['player_help'] = helped
    if help_errors:
        started['player_help_errors'] = help_errors
    # The chat translator: a side job too, so one that cannot start keeps nothing else down.
    try:
        if ensure_translator(group, start):
            started['chat_translator'] = True
    except (OSError, subprocess.SubprocessError) as error:
        started['chat_translator_error'] = str(error)[:300]
    # Lands that ships' courses asked for (expedition_slots.serve): a side job too.
    try:
        opened = serve_expeditions(group, start)
        if opened:
            started['expeditions'] = opened
    except (OSError, RuntimeError, ValueError, KeyError) as error:
        started['expeditions_error'] = str(error)[:300]
    # Player activity (docs/player-activity.md) is read into the host database
    # every PLAYER_ACTIVITY_MINUTES; a side job that never touches the helpers.
    try:
        read = ingest_player_activity(group)
        if read is not None:
            started['player_activity'] = read
    except (OSError, ValueError, KeyError, sqlite3.Error) as error:
        started['player_activity_error'] = str(error)[:300]
    # Daily maintenance (daily_maintenance.py): today's run starts at its time; a side job too.
    try:
        day = daily_maintenance.ensure(_THIS, group, start)
        if day:
            started['maintenance'] = day
    except (OSError, ValueError, KeyError) as error:
        started['maintenance_error'] = str(error)[:300]
    # The validator is a side job: its failure must not keep the helpers down.
    try:
        started.update(ensure_save_validation(group, start))
    except (OSError, RuntimeError, ValueError, KeyError) as error:
        started['save_validation_error'] = str(error)[:300]
    if not group['transfers']:
        return started
    # A group fresh world stops the helpers and moves their stores; they stay down
    # until it has finished (or been recovered by hand).
    if group_fresh_world.paused(group):
        started['paused'] = 'group fresh world'
        return started
    # Helpers that run old code are restarted, but never in the middle of an action.
    refresh = not group_busy(group)
    for region in group['regions']:
        # A region added to the group file but not set up yet has no worktree or token
        # to run an agent from: starting one crashed and left a state folder behind that
        # made its setup refuse (far2-far4, 2026-11-22). Its setup starts it later.
        if not (region_dir(group, region['id']) / '.git').exists():
            continue
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


CALENDAR_PHASES = ('Early Morning', 'Morning', 'Midday', 'Afternoon', 'Evening', 'Night')
CALENDAR_SEASONS = ('SPRING', 'SUMMER', 'FALL', 'WINTER', 'Wet Season', 'Dry Season')


def calendar_view(calendar):
    """A region's world calendar answer (world_calendar.dm), checked, or None."""
    if not isinstance(calendar, dict):
        return None
    clock, phase, season, zone = (calendar.get(key) for key in ('clock', 'phase', 'season', 'zone'))
    if not (isinstance(clock, str) and re.fullmatch(r'\d\d:\d\d [AP]M', clock) and phase in CALENDAR_PHASES
            and season in CALENDAR_SEASONS and type(zone) is int and -12 <= zone <= 14):
        return None
    view = {'clock': clock, 'phase': phase, 'season': season, 'zone': zone}
    left = calendar.get('season_left')
    if type(left) is int and 0 <= left <= 1440:
        view['season_left'] = left
    return view


def region_status(group, region, host, view=region_view, platform=None):
    """One region's entry of the group status."""
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
            # The land's transfer agent is on hold: nobody can arrive until it is cleared.
            if seen.get('transfers_held'):
                entry['region_view']['transfers_held'] = True
            # Characters kept here while their players are at an event region.
            if type(seen.get('event_away')) is int and seen['event_away'] >= 0:
                entry['region_view']['event_away'] = seen['event_away']
            # The world calendar: local clock, phase, season and time zone.
            calendar = calendar_view(seen.get('calendar'))
            if calendar:
                entry['region_view']['calendar'] = calendar
            age = seen.get('ordinal_age')
            if type(age) is int and 0 <= age < len(EPOCH_NAMES):
                entry['region_view']['epoch'] = {'ordinal': age, 'name': EPOCH_NAMES[age]}
    if group['transfers']:
        entry['transfer_agent'] = (platform or RegionPlatform(region_config(group, region))).listening(region['transfer_port'])
    return entry


def group_status(group, only=None, view=region_view, platform=None):
    """Every region's status.

    The regions are asked side by side: each world gets up to 15 seconds to answer its
    status and 10 for its region view, so two worlds that did not answer (saving, loading,
    hung) made the whole status take longer than the launcher waits for it, and the board
    showed "did not answer" for every region. One region whose status cannot be read is
    reported with its error and the rest are still shown."""
    def one(pair):
        region, host = pair
        try:
            return region_status(group, region, host, view, platform)
        except (OSError, RuntimeError, ValueError) as error:
            return {'port': region['port'], 'state': 'unknown', 'busy': False, 'kind': region['kind'], 'name': region['name'],
                    'error': 'its status could not be read: %s' % str(error)[:300]}
    pairs = hosts(group, only, platform)
    if platform is None and len(pairs) > 1:
        with concurrent.futures.ThreadPoolExecutor(max_workers=min(16, len(pairs))) as pool:
            entries = list(pool.map(one, pairs))
    else:
        entries = [one(pair) for pair in pairs]
    report = {region['id']: entry for (region, _host), entry in zip(pairs, entries)}
    result = {'group': group['group'], 'regions': report, 'mainland': group['mainland'], 'start_region': group['start_region']}
    try:
        result['maintenance'] = daily_maintenance.status(_THIS, group)
    except (OSError, ValueError, KeyError) as error:
        result['maintenance'] = {'error': str(error)[:300]}
    if group['transfers']:
        result['coordinator'] = coordinator_pid(group) is not None
        # Land stages and readiness (docs/land-stages.md), read-only from the
        # coordinator's database, for the launcher's region board.
        for region_id, land in group_lands(group).items():
            if region_id in report:
                report[region_id]['land'] = land
    return result


def group_account(group, ckey):
    """One account's lifetime points and character slots (docs/character-slots.md),
    read from the coordinator's shared player records. Read-only: staff grant,
    remove and lock in game (Admin > Player Accolades)."""
    if str(TRANSFER_TOOLS.parents[1]) not in sys.path:
        sys.path.insert(0, str(TRANSFER_TOOLS.parents[1]))
    from tools.transfer_storage import records
    ckey = records.canonical_ckey(ckey or '')
    if not ckey:
        raise Refused('give a player key with --ckey')
    path = Path(group['root']) / 'coordinator.sqlite'
    if not path.exists():
        return {'db': str(path), 'ckey': ckey, 'text': 'No coordinator database yet: accounts are kept once the group runs.'}
    db = sqlite3.connect('file:%s?mode=ro' % path.as_posix(), uri=True)
    try:
        if not db.execute("SELECT name FROM sqlite_master WHERE name = 'player_record'").fetchone():
            return {'db': str(path), 'ckey': ckey, 'text': 'The coordinator has no player records yet.'}
        account = records.account_summary(db, ckey)
    finally:
        db.close()
    return dict(account, db=str(path), ckey=ckey, text='%s\n%s' % (ckey, account['text']))


def group_records(group, ckey=None, search=None, export=None, now=None):
    """The launcher's Player records window (records.py): read-only look at the shared
    player records (notes, warnings, bans, watchlist, memos) in the coordinator
    database, each region's copy of its old files, and an export to one JSON file."""
    now = time.time() if now is None else now
    if str(TRANSFER_TOOLS.parents[1]) not in sys.path:
        sys.path.insert(0, str(TRANSFER_TOOLS.parents[1]))
    from tools.transfer_storage import records
    if ckey is not None:
        ckey = records.canonical_ckey(ckey)
        if not ckey:
            raise Refused('give a player key')
    if search is not None and not 1 <= len(search.strip()) <= 64:
        raise Refused('search for 1 to 64 characters')
    regions = records.region_status({region['id']: str(region_dir(group, region['id'])) for region in group['regions']})
    path = Path(group['root']) / 'coordinator.sqlite'
    if not path.exists():
        text = 'No coordinator database yet: records stay in each region until the group runs.'
        return {'db': str(path), 'regions': regions, 'text': text}
    db = sqlite3.connect('file:%s?mode=ro' % path.as_posix(), uri=True)
    try:
        if not db.execute("SELECT name FROM sqlite_master WHERE name = 'player_record'").fetchone():
            return {'db': str(path), 'regions': regions,
                    'text': 'The coordinator has no player records yet: restart it on the current tools to start collecting.'}
        if export:
            count = records.export(db, export, now)
            return {'db': str(path), 'regions': regions, 'exported': count, 'file': str(export),
                    'text': 'Exported %d records to %s.' % (count, export)}
        result = records.report(db, now, ckey=ckey, search=search.strip() if search else None)
    finally:
        db.close()
    lines = [result['text'], '']
    for region in sorted(regions):
        entry = regions[region]
        copied = [name for name, done in entry['migrated'].items() if done]
        lines.append('%s: old %s copied; %d records waiting for the coordinator%s' % (
            region, ', '.join(copied) if copied else 'files not yet', entry['waiting'],
            ', %d refused' % entry['refused'] if entry['refused'] else ''))
    result['text'] = '\n'.join(lines)
    return dict(result, db=str(path), regions=regions)


def group_lands(group):
    """Each land's stage and readiness from the coordinator database, or {}."""
    path = Path(group['root']) / 'coordinator.sqlite'
    if not path.exists():
        return {}
    if str(TRANSFER_TOOLS.parents[1]) not in sys.path:
        sys.path.insert(0, str(TRANSFER_TOOLS.parents[1]))
    from tools.transfer_storage.coordinator import read_lands
    return read_lands(str(path), group['mainland'])


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


def awake_host(group, region_id, platform=None):
    """The (region, host) of an awake, running region with a lifecycle token, or Refused."""
    if not region_id:
        raise Refused('choose the region with --region')
    region, host = hosts(group, region_id, platform)[0]
    if host.frozen():
        raise Refused('%s is asleep; nobody is playing there' % region_id)
    if not host.platform.listening(region['port']):
        raise Refused('%s is not running' % region_id)
    if not host.token():
        raise Refused('%s has no config/lifecycle-token.txt' % region_id)
    return region, host


def region_players(group, region_id, platform=None):
    """Who is online in one region, the regions they can be sent to and the latest transfers."""
    region, host = awake_host(group, region_id, platform)
    try:
        answer = host.platform.query(region['port'], host.token(), 'players')
    except (OSError, RuntimeError, ValueError) as error:
        raise Refused('%s did not answer: %s' % (region_id, str(error)[:200]))
    if not isinstance(answer, dict) or not isinstance(answer.get('players'), list):
        raise Refused('%s did not list its players (an older build without the Players request?)' % region_id)
    return {'region': region_id, 'players': answer['players'], 'recent': answer.get('recent') or [],
            'running': bool(answer.get('running')), 'destinations': answer.get('destinations') or {}}


def send_players(group, region_id, ckeys, destination, landing='shore', at=None, ship=False, dry_run=True, platform=None):
    """Send players from one region to another (Send Player to Region, region_admin_send.dm).

    Always answers with the world's dry run, one row per player (ok, reason, warnings). With
    dry_run False the world starts the send after answering; the outcome shows in group admin
    chat and in the next `players` answer. The world checks everything again as it sends.
    """
    if not isinstance(ckeys, str) or not CKEY_LIST.match(ckeys):
        raise Refused('give up to 20 player keys separated by commas')
    ids = [r['id'] for r in group['regions']]
    if destination not in ids or destination == region_id:
        raise Refused('choose another region of the group to send them to')
    if landing not in SEND_LANDINGS:
        raise Refused('landing must be one of %s' % ', '.join(SEND_LANDINGS))
    if (landing == 'coords') != bool(at):
        raise Refused('coords landing needs --at X,Y,Z (and only it takes one)')
    if at and not COORDS.match(at):
        raise Refused('--at must be X,Y,Z')
    region, host = awake_host(group, region_id, platform)
    extra = {'ckeys': ckeys, 'to': destination, 'landing': landing, 'dry_run': '1' if dry_run else '0'}
    if at:
        extra['at'] = at
    if ship:
        extra['ship'] = '1'
    try:
        answer = host.platform.query(region['port'], host.token(), 'send_players', extra=extra)
    except (OSError, RuntimeError, ValueError) as error:
        raise Refused('%s did not answer: %s' % (region_id, str(error)[:200]))
    send = answer.get('send') if isinstance(answer, dict) else None
    if not isinstance(send, str):
        raise Refused('%s did not answer the send (an older build without Send Player to Region?)' % region_id)
    return {'region': region_id, 'to': destination, 'landing': landing, 'send': send, 'rows': answer.get('rows') or []}


def ckey(text):
    """BYOND's ckey(): lower case, letters, digits and @ only."""
    return re.sub(r'[^a-z0-9@]', '', str(text).lower())


def magic_whitelist_path(group):
    """The one file every region reads (magic_whitelist_file() in the game)."""
    return shared_file(group, 'magic_whitelist.txt')


def magic_whitelist_keys(text):
    keys = []
    for line in text.replace('\r', '').split('\n'):
        key = ckey(line.split('#', 1)[0])
        if key and len(key) <= 32 and key not in keys:
            keys.append(key)
    return keys


def magic_whitelist(group, add=None, remove=None):
    """List the magic whitelist, or add/remove comma-separated player keys. Worlds reread it within 30 seconds."""
    path = magic_whitelist_path(group)
    try:
        keys = magic_whitelist_keys(path.read_text(encoding='utf-8'))
    except FileNotFoundError:
        keys = []
    changed = {'added': [], 'removed': []}
    for value, adding in ((add, True), (remove, False)):
        if value is None:
            continue
        if not isinstance(value, str) or not CKEY_LIST.match(value):
            raise Refused('give up to 20 player keys separated by commas')
        for raw in value.split(','):
            key = ckey(raw)
            if not key:
                raise Refused('%r is not a player key' % raw)
            if adding and key not in keys:
                keys.append(key)
                changed['added'].append(key)
            elif not adding and key in keys:
                keys.remove(key)
                changed['removed'].append(key)
    if changed['added'] or changed['removed']:
        path.parent.mkdir(parents=True, exist_ok=True)
        temp = path.with_name(path.name + '.tmp')
        temp.write_text(MAGIC_WHITELIST_HEADER + ''.join(k + '\n' for k in sorted(keys)), encoding='utf-8')
        gaia_host.replace_file(temp, path)
    return {'file': str(path), 'keys': sorted(keys), 'added': changed['added'], 'removed': changed['removed']}


class _ThisModule:
    """This module as group_ports sees it (it cannot import us back: we may be __main__)."""
    def __getattr__(self, name):
        try:
            return globals()[name]
        except KeyError:
            raise AttributeError(name)


_THIS = _ThisModule()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--config', required=True)
    parser.add_argument('action', nargs='?', choices=GROUP_ACTIONS)
    parser.add_argument('--region')
    parser.add_argument('--confirm-region', help='fresh-world: type the exact selected region id')
    parser.add_argument('--confirm-group', help='group-fresh-world: type the exact group id')
    parser.add_argument('--from', dest='source', help='adopt: the stopped standalone server folder')
    parser.add_argument('--epoch', help='epoch: the epoch to advance to, by name (2026) or index (0-9)')
    parser.add_argument('--template', help='expedition-land: a world-chart template (JSON file)')
    parser.add_argument('--key', help='expedition-land: the chart tile the land belongs to, X,Y')
    parser.add_argument('--players', help='send-players: player keys, comma separated')
    parser.add_argument('--to', help='send-players: the region to send them to')
    parser.add_argument('--landing', default='shore', choices=SEND_LANDINGS, help='send-players: where they land')
    parser.add_argument('--at', help='send-players: X,Y,Z for --landing coords')
    parser.add_argument('--ship', action='store_true', help='send-players: send the ship the first player is aboard, with everyone aboard')
    parser.add_argument('--send', action='store_true', help='send-players: really send (without it, only the dry run)')
    parser.add_argument('--add', help='magic-whitelist: player keys to add, comma separated')
    parser.add_argument('--stop-run', type=int, help='agents: stop this AI character run (its watcher plays the character again)')
    parser.add_argument('--restart-watcher', type=int, help='agents: restart this AI character watcher as it was started')
    parser.add_argument('--remove', help='magic-whitelist: player keys to remove, comma separated')
    parser.add_argument('--port', type=int, help='set-port: the game port')
    parser.add_argument('--transfer-port', type=int, help='set-port: the transfer agent port')
    parser.add_argument('--standby-port', type=int, help='set-port: the handover standby port')
    parser.add_argument('--apply', action='store_true', help='set-gate, set-port, add-gateway, add-regions: carry the plan out (without it, only the plan)')
    parser.add_argument('--bot-profile', help='set-gate: the bot profile.json to repoint (default: the group\'s bot_profile)')
    parser.add_argument('--ckey', help='records: every record about one player key; accounts: the player key to look up')
    parser.add_argument('--search', help='records: records whose key or text holds this')
    parser.add_argument('--export', help='records: write every record to this JSON file')
    parser.add_argument('--scheduled', action='store_true', help=argparse.SUPPRESS)  # maintenance: the host service's daily run
    parser.add_argument('--run', action='store_true', help=argparse.SUPPRESS)  # maintenance: the detached run of Run maintenance now
    parser.add_argument('--worker', nargs=2, metavar=('ACTION', 'OPERATION'), help=argparse.SUPPRESS)
    parser.add_argument('--ports-worker', metavar='OPERATION', help=argparse.SUPPRESS)
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
    this = _THIS
    if args.ports_worker:
        # The detached worker of set-gate / set-port --apply (group_ports.apply).
        return 0 if group_ports.work(this, group, args.ports_worker) else 1
    if not args.action:
        parser.error('an action is required')
    try:
        if args.action in ('setup', 'update'):
            fetch_remote(group)
        if args.action == 'fresh-world':
            if not args.region or args.confirm_region != args.region:
                raise Refused('fresh-world requires one --region and matching --confirm-region')
            # The launcher reads the same {"accepted": ..., "ok": true} answer as start (LocalHosting.ParseGroup).
            result = {'accepted': {region['id']: fresh_world.request(host, args.confirm_region)
                                   for region, host in hosts(group, args.region)}, 'refused': {}}
        elif args.action == 'group-fresh-world':
            if args.region:
                raise Refused('the group fresh world acts on every region; leave out --region')
            result = group_fresh_world.request(group, hosts(group), args.confirm_group, coordinator_pid,
                                               Platform().terminate)
        elif args.action == 'migrate-underground':
            if not args.region:
                raise Refused('migrate-underground acts on one --region')
            [(_region, host)] = hosts(group, args.region)
            result = underground_migration.migrate(this, group, host, args.region)
        elif args.action == 'setup':
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
        elif args.action in ('translator-status', 'translator-start', 'translator-stop'):
            if args.region:
                raise Refused('the chat translator serves the whole group; leave out --region')
            result = {'translator-status': translator_status, 'translator-start': translator_start,
                      'translator-stop': translator_stop}[args.action](group)
        elif args.action == 'adopt':
            if not args.region or not args.source:
                parser.error('adopt needs --region and --from')
            result = adopt(group, args.region, args.source)
        elif args.action == 'epoch':
            if args.epoch is None or args.region:
                parser.error('epoch needs --epoch and acts on the whole group')
            result = group_epoch(group, args.epoch)
        elif args.action == 'update-offline':
            result = update_offline(group, args.region)
        elif args.action in ('maintenance', 'maintenance-status'):
            # Daily maintenance (daily_maintenance.py): the whole group or nothing.
            if args.region:
                raise Refused('daily maintenance moves the whole group onto one build; leave out --region')
            if args.action == 'maintenance-status':
                result = daily_maintenance.status(this, group)
            elif args.scheduled or args.run:
                # The detached run itself (the host service's daily start, or Run maintenance now).
                result = daily_maintenance.run(this, group, scheduled=args.scheduled)
            else:
                result = daily_maintenance.request(this, group, lambda argv, cwd, log: detach(argv + ['--run'], cwd, log))
        elif args.action == 'players':
            result = region_players(group, args.region)
        elif args.action == 'send-players':
            if not args.region or not args.players or not args.to:
                parser.error('send-players needs --region, --players and --to')
            result = send_players(group, args.region, args.players, args.to, args.landing, args.at, args.ship, not args.send)
        elif args.action == 'magic-whitelist':
            if args.region:
                raise Refused('the magic whitelist is shared by the whole group; leave out --region')
            result = magic_whitelist(group, args.add, args.remove)
        elif args.action == 'agents':
            # AI characters on this host (agent_runs.py): autopilot watchers, their runs and logs.
            if args.region:
                raise Refused('AI characters cover the whole host; leave out --region')
            if args.stop_run:
                result = agent_runs.stop_run(args.stop_run)
            elif args.restart_watcher:
                result = agent_runs.restart_watcher(args.restart_watcher)
            else:
                result = agent_runs.status()
            if result.get('ok') is False:
                raise Refused(result['refused'])
        elif args.action == 'activity':
            if args.region:
                raise Refused('player activity covers the whole group; leave out --region')
            result = player_activity_report(group)
        elif args.action == 'accounts':
            if args.region:
                raise Refused('accounts are shared by the whole group; leave out --region')
            result = group_account(group, args.ckey)
        elif args.action == 'records':
            if args.region:
                raise Refused('player records are shared by the whole group; leave out --region')
            result = group_records(group, args.ckey, args.search, args.export)
        elif args.action == 'ports':
            result = group_ports.report(this, group)
        elif args.action in ('set-gate', 'set-port'):
            if not args.region:
                parser.error('%s needs --region' % args.action)
            if args.action == 'set-gate':
                plan = group_ports.plan_gate(this, group, args.region, bot_profile=args.bot_profile)
            else:
                plan = group_ports.plan_port(this, group, args.region, args.port, args.transfer_port, args.standby_port,
                                             bot_profile=args.bot_profile)
            result = group_ports.apply(this, group, plan) if args.apply else {'plan': plan, 'applied': False}
        elif args.action == 'add-gateway':
            result = add_gateway(group, args.region, args.apply)
        elif args.action == 'add-regions':
            if args.region:
                raise Refused('add-regions adds every missing Earth region; leave out --region')
            result = add_regions(group, args.apply)
        elif args.action == 'config-migrate':
            result = migrate_config(group)
        elif args.action == 'expedition-land':
            if not args.region or not args.template:
                parser.error('expedition-land needs --region and --template')
            (region, host), = hosts(group, args.region)
            result = expedition_slots.give_land(group, host, args.region, expedition_slots.load_template(args.template),
                                                key=args.key)
        elif args.action == 'expedition-archive':
            if not args.region:
                parser.error('expedition-archive needs --region')
            (region, host), = hosts(group, args.region)
            result = expedition_slots.archive(group, host, args.region)
        elif args.action == 'expedition-open':
            # The host service's worker for a land a ship's course asked for (expedition_slots.serve).
            if not args.region:
                parser.error('expedition-open needs --region')
            (region, host), = hosts(group, args.region)
            expedition_slots.expedition_region(group, args.region)
            result = expedition_slots.open_land(group, host, args.region, update_offline)
        elif args.action == 'expedition-grow':
            result = grow_expeditions(group) or {'grown': False}
        elif args.action == 'expedition-status':
            result = {'slots': expedition_slots.status(group), 'parked': expedition_slots.parked(group)}
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
                except (OSError, RuntimeError, ValueError) as error:
                    # One region that cannot be ended must not leave the rest running.
                    refused[region['id']] = '%s failed: %s' % (args.action, str(error)[:300])
            if refused and not done:
                print(json.dumps({'ok': False, 'refused': refused}))
                return 1
            result = {'done': done, 'refused': refused}
        else:
            accepted, refused = {}, {}
            waited = False
            for region, host in hosts(group, args.region):
                if args.region is None and region.get('kind') == 'GATEWAY' and args.action in GATEWAY_SKIPPED_ACTIONS:
                    refused[region['id']] = GATEWAY_PINNED  # it stays on its port (Val, 2026-11-21)
                    continue
                try:
                    if args.action == 'start' and not waited and host.config['start_requires_byond_pager']                             and not host.platform.listening(host.config['port']):
                        # start.bat after a reboot: the pager starts and signs in once for every region
                        waited = True
                        host.wait_for_byond()
                    if args.action == 'force-restart':
                        accepted[region['id']] = host.force_restart()
                    elif args.action == 'stage':  # deploy.bat and the launcher's Build update: a person waits
                        accepted[region['id']] = host.request_stage(urgent=True)
                    else:
                        accepted[region['id']] = host.request(args.action)
                except Refused as refusal:
                    refused[region['id']] = str(refusal)
                except (OSError, RuntimeError, ValueError) as error:
                    # One region that cannot take the action must not hide what the others
                    # answered (the launcher showed "the group script gave no answer").
                    refused[region['id']] = '%s failed: %s' % (args.action, str(error)[:300])
            result = {'accepted': accepted, 'refused': refused}
            if args.action in ('start', 'restart', 'force-restart') and accepted:
                result['coordinator_started'] = ensure_coordinator(group)
            if refused and not accepted:
                print(json.dumps({'ok': False, 'refused': refused}))
                return 1
    except Refused as refusal:
        print(json.dumps({'ok': False, 'refused': str(refusal)}))
        return 1
    except (OSError, RuntimeError, ValueError) as error:
        # Callers read one JSON line; a bare traceback reached them as "no answer".
        traceback.print_exc()
        print(json.dumps({'ok': False, 'refused': '%s failed: %s: %s' % (args.action, type(error).__name__, str(error)[:300])}))
        return 1
    print(json.dumps(dict(result, ok=True)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
