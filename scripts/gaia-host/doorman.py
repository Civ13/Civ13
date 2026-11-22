"""Always-on doorman for one host's frozen-on-idle game servers.

`gaia_host.py serve` runs this. It does the `watch` work for every configured
instance (Gaia and, with --group, every region of a region group: freeze
after idle, thaw on a direct connection) and also listens on
one extra TCP port (doorman_port, 1713 by default) that speaks the same BYOND
Topic framing as a game port. The launcher asks it two things:

    ?host_status=1          every instance's state and cached status (and, for a
                            world in a region group, its shard_region answer)
    ?wake=1&port=1714       thaw that instance now (refused while the machine has
                            less than wake_min_free_mb of physical memory free)
    ?wake=1&port=1714&start=1
                            the same, and a stopped instance is started (prepared)
                            for a traveller: only from this machine (a region of the
                            group), never while it is kept down (keep_down), busy
                            with another action or given up on by the watchdog

so browsing reads the cache and never wakes a frozen world; only joining does.
The same two queries also answer plain HTTP (`GET /?host_status=1`): a DM world
cannot ask with world.Export, which opens a world-to-world BYOND handshake
rather than sending a bare Topic frame, so regions ask over HTTP (rust_g).
Answers are display data and a wake trigger. They carry no addresses and no
join authority: the launcher still verifies the game port itself before
joining. The doorman never proxies game traffic, so players keep their own
address for bans and logs.
"""
from __future__ import annotations

import ipaddress
import json
import socket
import struct
import threading
import time
import urllib.parse

from byond_topic import frame_query

SCHEMA = 1
MAX_REQUEST = 512
REQUEST_TIMEOUT = 3
REFRESH_SECONDS = 30
# Seconds after a wake request during which an instance that has not answered
# its status topic yet still reads as waking rather than asleep or stopped.
WAKING_SECONDS = 60
WAKE_SPACING = 30            # one wake per address and port per this many seconds
REQUESTS_PER_MINUTE = 40     # per address, all requests
MAX_CONNECTIONS = 16
SUPERVISE_SECONDS = 30       # how often helper processes (transfer agents, coordinators) are checked
EVICT_SECONDS = 60           # at most one low-memory eviction per this many seconds, so freed memory shows
READY_SECONDS = 30           # how often lands next to players are checked (keep_ready)
READY_RETRY_SECONDS = 600    # after a refused or failed start ahead, wait this long before trying that land again


def frame(text):
    """A BYOND Topic reply carrying text."""
    body = b'\x06' + text.encode('utf-8') + b'\x00'
    return b'\x00\x83' + struct.pack('>H', len(body)) + body


def parse_request(data):
    """The query string of a BYOND Topic request, or None if it is not one."""
    if len(data) < 4 or data[:2] != b'\x00\x83':
        return None
    length = struct.unpack('>H', data[2:4])[0]
    body = data[4:]
    if length != len(body) or length < 6 or length > MAX_REQUEST or body[:5] != b'\0' * 5 or body[-1:] != b'\0':
        return None
    try:
        text = body[5:-1].decode('ascii')
    except UnicodeDecodeError:
        return None
    return text[1:] if text.startswith('?') else text


MAX_HTTP_HEAD = 2048


def is_http(first):
    """True when the first four bytes of a connection start an HTTP GET."""
    return first[:4] == b'GET '


def read_http_query(connection, first):
    """The query string of `GET /?query HTTP/1.x` whose first bytes were already read, or None."""
    head = bytearray(first)
    while b'\r\n\r\n' not in head:
        if len(head) > MAX_HTTP_HEAD:
            return None
        part = connection.recv(512)
        if not part:
            return None
        head.extend(part)
    try:
        line = bytes(head).split(b'\r\n', 1)[0].decode('ascii')
    except UnicodeDecodeError:
        return None
    parts = line.split(' ')
    if len(parts) != 3 or parts[0] != 'GET' or not parts[2].startswith('HTTP/1.') or not parts[1].startswith('/?'):
        return None
    return parts[1][2:]


def http_reply(value):
    """An HTTP/1.1 answer carrying value as JSON, or a 404 when value is None."""
    if value is None:
        return b'HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n'
    body = json.dumps(value, separators=(',', ':')).encode('utf-8')
    return (b'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: ' + str(len(body)).encode()
            + b'\r\nConnection: close\r\n\r\n' + body)


def topic(port, query, timeout=5):
    """Send one Topic to 127.0.0.1:port and return its text reply."""
    query_bytes = query.encode('ascii')
    with socket.create_connection(('127.0.0.1', port), timeout=timeout) as connection:
        connection.sendall(frame_query(query_bytes))
        header = _read(connection, 4)
        if header[:2] != b'\x00\x83':
            raise RuntimeError('invalid Topic reply')
        body = _read(connection, struct.unpack('>H', header[2:])[0])
    if not body or body[0] != 6:
        raise RuntimeError('Topic reply is not text')
    return body[1:].rstrip(b'\0').decode('utf-8')


def _read(connection, count):
    data = bytearray()
    while len(data) < count:
        part = connection.recv(count - len(data))
        if not part:
            raise RuntimeError('connection closed early')
        data.extend(part)
    return bytes(data)


class Instance:
    def __init__(self, host):
        self.host = host
        self.port = host.config['port']
        self.status = None        # last {"players", "map_name", "map_gamemode"} the world reported
        self.region = None        # last shard_region answer of a world in a region group
        self.status_at = None
        self.waking_since = None
        self.waking_limit = WAKING_SECONDS
        self.preparing_since = None   # a traveller's wake started this stopped world then
        self.unwanted_since = None    # keep_ready: since when no land next to it has had players
        self.next_ready_start = 0.0   # keep_ready: no start ahead before this clock time
        self.wanted_by = None         # keep_ready: the occupied land it is kept ready for
        self.start_refusal = None     # why the last such start was refused
        self.idle_since = None
        self.next_watch = 0.0
        self.next_refresh = 0.0



def is_loopback(address):
    """True for a loopback peer (IPv4, IPv6 or IPv4-mapped); False when unparseable."""
    try:
        ip = ipaddress.ip_address(str(address).split('%')[0])
    except ValueError:
        return False
    mapped = getattr(ip, 'ipv4_mapped', None)
    return (mapped or ip).is_loopback

class Doorman:
    def __init__(self, hosts, platform, clock=time.monotonic, wall=time.time, supervisors=(), groups=()):
        self.instances = {}
        # Group configs that may change while we serve (gaia_host.GroupWatch): see reload_groups.
        self.groups = list(groups)
        # Callables that restart a group's helper processes if they died; each
        # returns a dict of what it started (empty when everything was running).
        self.supervisors = list(supervisors)
        self.next_supervise = 0.0
        self.next_evict = 0.0
        self.next_ready = 0.0
        for host in hosts:
            if host.config['port'] in self.instances:
                raise ValueError('two configs use port %d' % host.config['port'])
            self.instances[host.config['port']] = Instance(host)
        first = hosts[0].config
        self.port = first['doorman_port']
        self.bind = first['doorman_bind']
        self.platform = platform
        self.clock = clock
        self.wall = wall
        self.lock = threading.RLock()
        self.requests = {}       # address -> recent request times
        self.wakes = {}          # (address, port) -> last wake time
        self.slots = threading.BoundedSemaphore(MAX_CONNECTIONS)

    # -- state ---------------------------------------------------------------
    def refresh(self, instance):
        """Ask an awake world for its public status; True when it answered."""
        try:
            reply = json.loads(self.platform.status_topic(instance.port))
        except (OSError, RuntimeError, ValueError):
            return False
        if not isinstance(reply, dict):
            return False
        with self.lock:
            instance.status = {'players': reply.get('players') if type(reply.get('players')) is int else 0,
                               'map_name': str(reply.get('map_name') or '')[:128],
                               'map_gamemode': str(reply.get('map_gamemode') or '')[:80]}
            instance.status_at = self.wall()
            instance.waking_since = None
            instance.preparing_since = None
        # Regions of a group used to poll each other with world.Export, which
        # blocks the asking world for the round trip. The doorman asks once and
        # every region reads its peers from host_status instead (2026-11-07).
        region = None
        try:
            answer = json.loads(self.platform.region_topic(instance.port))
            if isinstance(answer, dict) and isinstance(answer.get('group'), str):
                region = {key: answer[key] for key in ('group', 'region', 'name', 'kind', 'players', 'map',
                                                         'ordinal_age', 'free_berths') if key in answer}
        except (OSError, RuntimeError, ValueError, AttributeError):
            region = None
        with self.lock:
            instance.region = region
        return True

    def state(self, instance):
        now = self.clock()
        if instance.waking_since is not None and now - instance.waking_since > instance.waking_limit:
            instance.waking_since = None
            instance.preparing_since = None
        if (instance.preparing_since is not None and not self.preparing(instance)
                and not self.platform.listening(instance.port)):
            # The start a traveller asked for ended without the world (a failed compile, a
            # broken save): stopped again, so waiting travellers are told at once.
            failed = instance.host.read_state() or {}
            instance.start_refusal = str(failed.get('error') or 'the start failed')[:200]
            instance.waking_since = None
            instance.preparing_since = None
        if instance.host.frozen() or instance.host.cold():
            return 'waking' if instance.waking_since is not None else 'asleep'
        if instance.waking_since is not None or self.preparing(instance):
            return 'waking'
        return 'awake' if self.platform.listening(instance.port) else 'stopped'

    def describe(self, instance):
        with self.lock:
            entry = {'port': instance.port, 'state': self.state(instance), 'wake_estimate': self.estimate(instance),
                     # asleep after a power-down: a wake starts it from its save, which takes minutes
                     'cold': instance.host.cold() is not None}
            if self.preparing(instance):
                entry['preparing'] = True  # a start is running: pulled, compiled if behind, then loaded
                # What the start is doing now (checking for updates, compiling, starting...), so a
                # waiting player hears whether the land is being built or loading.
                entry['phase'] = str((instance.host.read_state() or {}).get('phase') or '')[:40]
            elif entry['state'] == 'stopped':
                # Whether a traveller's wake may start it (Val, 2026-11-22); the regions show it.
                entry['startable'] = self.travel_refusal(instance) is None
            if instance.host.config.get('routed'):
                # Behind the routing relay: players join through the gate world, never this port.
                entry['routed'] = True
            if instance.status is not None:
                entry.update(instance.status)
                entry['cached_age'] = max(0, int(self.wall() - instance.status_at))
                if instance.region is not None:
                    entry['region'] = dict(instance.region)
            return entry

    def preparing(self, instance):
        """True while a start action runs for a world that is not up yet."""
        starting = getattr(instance.host, 'starting', None)
        return bool(starting and starting()) and not self.platform.listening(instance.port)

    def travel_refusal(self, instance):
        """Why a traveller may not start this stopped world, or None."""
        refusal = getattr(instance.host, 'travel_start_refusal', None)
        return refusal() if refusal else 'this host cannot start it'

    def stopped(self, instance):
        host = instance.host
        return not host.frozen() and not host.cold() and not self.platform.listening(instance.port)

    def estimate(self, instance):
        config = instance.host.config
        if instance.preparing_since is not None:  # a traveller's start: it may compile first
            return config.get('travel_start_estimate_seconds', 600)
        cold = instance.host.cold() is not None or (instance.waking_limit > WAKING_SECONDS and instance.waking_since is not None)
        return config['cold_start_estimate_seconds'] if cold else config['wake_estimate_seconds']

    def wake(self, instance, reason, start=False):
        """Thaw a frozen instance, or start a cold one from its last save, and mark
        it waking until its status answers. start: a stopped one is started too (for a
        traveller); one already starting is only marked waking, so it is prepared once."""
        with self.lock:
            host = instance.host
            if start and self.stopped(instance):
                try:
                    host.log(host.start_for_travel(reason))
                except Exception as refusal:  # gaia_host.Refused; that module may be __main__
                    if 'Refused' not in [kind.__name__ for kind in type(refusal).__mro__]:
                        raise
                    instance.start_refusal = str(refusal)[:200]
                    host.log({'travel_start_refused': instance.start_refusal, 'port': instance.port})
                    return False
                instance.start_refusal = None
                instance.preparing_since = self.clock()
                limit = host.config.get('travel_start_estimate_seconds', 600) + host.config['cold_start_estimate_seconds']
            elif host.frozen():
                host.log(host.thaw(reason))
                limit = WAKING_SECONDS
            elif host.cold():
                try:
                    host.log(host.start_cold(reason))
                except Exception as refusal:  # gaia_host.Refused; that module may be __main__
                    if type(refusal).__name__ != 'Refused':
                        raise
                    host.log({'cold_start_refused': str(refusal)})
                    return False
                limit = host.config['cold_start_estimate_seconds'] + WAKING_SECONDS
            else:
                return False
            instance.waking_since = self.clock()
            instance.waking_limit = limit
            instance.idle_since = None
            instance.next_refresh = 0.0
            return True

    def low_memory(self, instance, start=False):
        """(free_mb, need_mb) when a frozen instance must not be woken for lack of memory.

        An awake instance needs nothing, and an unknown free amount does not block.
        start: a stopped instance about to be started for a traveller needs what a cold start does.
        """
        host = instance.host
        if host.frozen():
            need = host.config['wake_min_free_mb']
        elif host.cold() or start:
            need = host.config['cold_start_min_free_mb']  # loading a save peaks far above a thaw
        else:
            return None
        if not need:
            return None
        free = self.platform.free_memory_mb()
        if free is None or free >= need:
            return None
        return free, need

    def evict_one(self, reason, keep=None):
        """Stop the longest-frozen world except keep, so its memory is freed. It saved
        before freezing, so it reads as cold and starts from that save on its next
        wake. Returns the evicted instance or None."""
        with self.lock:
            frozen = []
            for instance in self.instances.values():
                if instance is keep or not instance.host.config.get('freeze_requires_save', True):
                    continue
                state = instance.host.frozen()
                if state:
                    # A land kept ready for players next door goes last (keep_ready).
                    frozen.append((instance.wanted_by is not None, state.get('frozen_at') or 0, instance.port, instance))
            for *_, instance in sorted(frozen, key=lambda item: item[:3]):
                try:
                    instance.host.log(instance.host.evict(reason))
                except Exception as refusal:  # Refused, or the process could not be stopped
                    instance.host.log({'evict_refused': str(refusal)[:300]})
                    continue
                instance.waking_since = None
                return instance
            return None

    def free_memory_for(self, instance, need):
        """Evict other frozen worlds until need MB is free; True when it is (or unknown)."""
        while True:
            free = self.platform.free_memory_mb()
            if free is None or free >= need:
                return True
            if self.evict_one('memory for waking port %d' % instance.port, keep=instance) is None:
                return False

    # -- requests ------------------------------------------------------------
    def allowed(self, address, now):
        # Regions and the routing relay on this machine ask often; only remote callers are limited.
        if is_loopback(address):
            return True
        with self.lock:
            recent = [moment for moment in self.requests.get(address, []) if now - moment < 60]
            recent.append(now)
            self.requests[address] = recent
            if len(self.requests) > 4096:  # forget idle addresses
                for key in [key for key, times in self.requests.items() if now - times[-1] >= 60]:
                    del self.requests[key]
            return len(recent) <= REQUESTS_PER_MINUTE

    def handle(self, query, address):
        """The reply object for one request, or None to drop the connection."""
        now = self.clock()
        if not self.allowed(address, now):
            return None
        try:
            values = urllib.parse.parse_qs(query, strict_parsing=True, max_num_fields=4)
        except ValueError:
            return None
        if values.get('host_status') == ['1'] and len(values) == 1:
            return {'schema': SCHEMA, 'instances': [self.describe(self.instances[port]) for port in sorted(self.instances)]}
        wake_keys = set(values) in ({'wake', 'port'}, {'wake', 'port', 'start'})
        if values.get('wake') == ['1'] and wake_keys and len(values.get('port', [])) == 1 \
                and values.get('start', ['1']) == ['1']:
            port = values['port'][0]
            instance = self.instances.get(int(port)) if port.isdigit() and len(port) <= 5 else None
            if instance is None:
                return {'schema': SCHEMA, 'ok': False, 'error': 'unknown port'}
            # Only a region on this machine may start a stopped world (for a traveller); a
            # remote caller (the launcher's Join) only wakes a sleeping one, as before.
            start = 'start' in values and is_loopback(address) and self.stopped(instance)
            if start and not self.preparing(instance):
                refusal = self.travel_refusal(instance)
                if refusal is not None:
                    return {'schema': SCHEMA, 'ok': False, 'error': 'kept down' if refusal == 'kept down' else 'not startable',
                            'reason': refusal, 'port': instance.port}
            if (instance.host.cold() or (start and not self.preparing(instance))) and not instance.host.byond_signed_in():
                instance.host.log({'wake_refused': 'byond signed out', 'port': instance.port})
                return {'schema': SCHEMA, 'ok': False, 'error': 'byond signed out', 'port': instance.port}
            low = self.low_memory(instance, start=start and not self.preparing(instance))
            # Make room by stopping the longest-asleep other world before refusing.
            if low is not None and self.free_memory_for(instance, low[1]):
                low = self.low_memory(instance, start=start and not self.preparing(instance))
            if low is not None:
                instance.host.log({'wake_refused': 'low memory', 'port': instance.port, 'free_mb': low[0], 'need_mb': low[1]})
                return {'schema': SCHEMA, 'ok': False, 'error': 'low memory', 'port': instance.port,
                        'free_mb': low[0], 'need_mb': low[1]}
            with self.lock:
                last = self.wakes.get((address, instance.port))
                spaced = last is None or now - last >= WAKE_SPACING
                if spaced and (instance.host.frozen() or instance.host.cold() or start):
                    self.wakes[(address, instance.port)] = now
            # A world already being prepared is never asked again: one start, one compile.
            if start and self.preparing(instance):
                with self.lock:
                    if instance.waking_since is None:
                        instance.waking_since = self.clock()
                        instance.waking_limit = (instance.host.config.get('travel_start_estimate_seconds', 600)
                                                 + instance.host.config['cold_start_estimate_seconds'])
                    instance.preparing_since = instance.preparing_since or self.clock()
            elif spaced:
                self.wake(instance, 'doorman wake request' + (' (travel start)' if start else ''), start=start)
            entry = self.describe(instance)
            if start and entry['state'] == 'stopped':
                return {'schema': SCHEMA, 'ok': False, 'error': 'not startable',
                        'reason': instance.start_refusal or 'the start was refused', 'port': instance.port}
            reply = {'schema': SCHEMA, 'ok': True, 'port': instance.port, 'state': entry['state'],
                     'eta': entry['wake_estimate'] if entry['state'] in ('asleep', 'waking') else 0}
            if instance.preparing_since is not None and entry['state'] == 'waking':
                reply['preparing'] = True
            return reply
        return None

    def serve_connection(self, connection, address):
        try:
            connection.settimeout(REQUEST_TIMEOUT)
            header = _read(connection, 4)
            if is_http(header):
                query = read_http_query(connection, header)
                connection.sendall(http_reply(self.handle(query, address) if query is not None else None))
                return
            length = struct.unpack('>H', header[2:])[0]
            if header[:2] != b'\x00\x83' or length > MAX_REQUEST:
                return
            query = parse_request(header + _read(connection, length))
            reply = self.handle(query, address) if query is not None else None
            if reply is not None:
                connection.sendall(frame(json.dumps(reply, separators=(',', ':'))))
        except (OSError, RuntimeError, ValueError):
            pass
        finally:
            connection.close()
            self.slots.release()

    def listen(self):
        family = socket.AF_INET6 if ':' in self.bind else socket.AF_INET
        server = socket.socket(family, socket.SOCK_STREAM)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind((self.bind, self.port))
        server.listen(32)
        return server

    def accept_forever(self, server):
        while True:
            connection, peer = server.accept()
            if not self.slots.acquire(blocking=False):
                connection.close()
                continue
            threading.Thread(target=self.serve_connection, args=(connection, peer[0]), daemon=True).start()

    def reload_groups(self):
        """Take the new region hosts of a group whose config file changed (a region moved to
        another port, or the front door moved: scripts/shard-group/group_ports.py). What we
        know of a region (its last status, how long it has been idle) follows it to its new
        port. A change that would put two worlds on one port is refused and reported."""
        for watch in self.groups:
            changed = watch.poll()
            if changed is None:
                continue
            old, new = changed
            with self.lock:
                kept = {port: instance for port, instance in self.instances.items()
                        if not any(instance.host is host for host in old)}
                known = {instance.host.config.get('region'): instance for instance in self.instances.values()
                         if any(instance.host is host for host in old)}
                fresh = {}
                for host in new:
                    port = host.config['port']
                    if port in kept or port in fresh:
                        fresh = None
                        break
                    instance = Instance(host)
                    before = known.get(host.config.get('region'))
                    if before is not None:
                        for name in ('status', 'region', 'status_at', 'idle_since'):
                            setattr(instance, name, getattr(before, name))
                    fresh[port] = instance
                if fresh is None:
                    print(json.dumps({'group_reload_refused': 'two worlds would share a port', 'time': int(self.wall())}), flush=True)
                    continue
                kept.update(fresh)
                self.instances = kept
            print(json.dumps({'group_reloaded': sorted(fresh), 'instances': sorted(self.instances), 'time': int(self.wall())}), flush=True)

    # -- lands kept ready for players next door ---------------------------------
    # Val (2026-11-22): travel between lands took too long. A land next to one with players stays
    # suspended in memory, so a traveller wakes it in seconds, and one in cold storage is started
    # ahead, one at a time, then freezes in memory once idle. A stopped land is left alone: a person
    # stopped it, and a traveller still starts it on demand (wake&start=1). A land with
    # nobody next door for cold_after_minutes goes to cold storage (it saved before it froze), so
    # its memory is free. The mainland, the always-up kinds and the oceans around the mainland are
    # always kept ready and never put in cold storage.
    def readiness(self, instance):
        policy = getattr(instance.host, 'readiness', None)
        if policy is None:
            return None
        try:
            return policy()
        except Exception as error:  # one region's broken config must not stop the others
            instance.host.log({'readiness_error': str(error)[:200]})
            return None

    def occupied(self, instance):
        return (self.platform.listening(instance.port) and not instance.host.frozen()
                and isinstance(instance.status, dict) and (instance.status.get('players') or 0) > 0)

    def keep_ready(self, now):
        """One pass: returns what it did ({port: action}), for the log and tests."""
        done = {}
        policies = {instance.port: self.readiness(instance) for instance in list(self.instances.values())}
        occupied = {}
        for instance in self.instances.values():
            policy = policies[instance.port]
            if policy and self.occupied(instance):
                occupied.setdefault(policy['group'], set()).add(policy['region'])
        starting = any(self.preparing(i) or (i.waking_since is not None and i.host.lock.exists())
                       for i in self.instances.values())
        for instance in sorted(self.instances.values(), key=lambda i: i.port):
            policy = policies[instance.port]
            if not policy:
                instance.wanted_by = instance.unwanted_since = None
                continue
            here = occupied.get(policy['group'], set())
            near = sorted(set(policy['neighbours']) & here)
            if policy['exempt'] or policy['region'] in here or near:
                instance.unwanted_since = None
                instance.wanted_by = near[0] if near else policy['region']
                host = instance.host
                if host.cold() is None or starting or now < instance.next_ready_start:
                    continue
                if host.keep_down() if hasattr(host, 'keep_down') else False:
                    continue
                if not host.byond_signed_in() or self.low_memory(instance) is not None:
                    instance.next_ready_start = now + READY_SECONDS * 4
                    continue
                reason = 'ready: next to players in %s' % instance.wanted_by if near else 'ready: always kept ready'
                if self.wake(instance, reason):
                    starting = True
                    done[instance.port] = 'started ahead'
                instance.next_ready_start = now + READY_RETRY_SECONDS
                continue
            instance.wanted_by = None
            if instance.unwanted_since is None:
                instance.unwanted_since = now
            minutes = policy['cold_after_minutes']
            if not minutes or now - instance.unwanted_since < minutes * 60 or not instance.host.frozen():
                continue
            try:
                instance.host.log(instance.host.evict('cold storage: no players next door for %d minutes' % minutes))
            except Exception as refusal:  # Refused (busy, never saved): try again on a later pass
                if 'Refused' not in [kind.__name__ for kind in type(refusal).__mro__]:
                    raise
                continue
            instance.waking_since = None
            done[instance.port] = 'cold storage'
        return done

    # -- the watch loop for every instance -----------------------------------
    def step(self):
        """One pass over every instance; returns seconds until the next pass."""
        now = self.clock()
        soonest = 30.0
        if self.groups:
            self.reload_groups()
            soonest = 5.0  # a port change waits for us to load the new ports
        if self.supervisors and now >= self.next_supervise:
            self.next_supervise = now + SUPERVISE_SECONDS
            for supervise in self.supervisors:
                try:
                    started = supervise()
                except Exception as error:  # keep serving the worlds even if a helper cannot start
                    print(json.dumps({'supervise_error': str(error)[:300], 'time': int(self.wall())}), flush=True)
                    continue
                if started:
                    print(json.dumps({'supervise_started': started, 'time': int(self.wall())}), flush=True)
        limit = max(i.host.config.get('evict_below_free_mb', 0) for i in self.instances.values())
        if limit and now >= self.next_evict:
            self.next_evict = now + EVICT_SECONDS
            free = self.platform.free_memory_mb()
            if free is not None and free < limit and self.evict_one('low memory: %d MB free' % free) is not None:
                print(json.dumps({'evicted_for_memory': free, 'time': int(self.wall())}), flush=True)
        if now >= self.next_ready:
            self.next_ready = now + READY_SECONDS
            try:
                done = self.keep_ready(now)
            except Exception as error:  # keep serving the worlds whatever goes wrong here
                done = None
                print(json.dumps({'keep_ready_error': str(error)[:300], 'time': int(self.wall())}), flush=True)
            if done:
                print(json.dumps({'keep_ready': done, 'time': int(self.wall())}), flush=True)
        for instance in self.instances.values():
            host = instance.host
            frozen = host.frozen() is not None
            if now >= instance.next_watch:
                try:
                    instance.idle_since, wait = host.watch_step(instance.idle_since)
                except Exception as error:  # keep serving; a stuck freeze is worse than a missed one
                    host.log({'watch_error': str(error)[:300]})
                    instance.idle_since, wait = None, 5
                instance.next_watch = now + wait
                if frozen and host.frozen() is None and host.cold() is None:  # a direct connection thawed it
                    with self.lock:
                        instance.waking_since = self.clock()
                        instance.waking_limit = WAKING_SECONDS
                        instance.next_refresh = 0.0
            if host.frozen() is None and now >= instance.next_refresh:
                answered = self.platform.listening(instance.port) and self.refresh(instance)
                instance.next_refresh = now + (REFRESH_SECONDS if answered else 2)
            soonest = min(soonest, instance.next_watch - now, instance.next_refresh - now if host.frozen() is None else 30)
        return max(0.05, soonest)

    def run(self):
        server = self.listen()
        threading.Thread(target=self.accept_forever, args=(server,), daemon=True).start()
        print(json.dumps({'doorman': '%s:%d' % (self.bind, self.port), 'instances': sorted(self.instances)}), flush=True)
        while True:
            self.platform.sleep(self.step())
