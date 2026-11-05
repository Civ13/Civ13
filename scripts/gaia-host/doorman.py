"""Always-on doorman for one host's frozen-on-idle game servers.

`gaia_host.py serve` runs this. It does the `watch` work for every configured
instance (Gaia and, with --group, every region of a region group: freeze
after idle, thaw on a direct connection) and also listens on
one extra TCP port (doorman_port, 1713 by default) that speaks the same BYOND
Topic framing as a game port. The launcher asks it two things:

    ?host_status=1          every instance's state and cached status
    ?wake=1&port=1714       thaw that instance now (refused while the machine has
                            less than wake_min_free_mb of physical memory free)

so browsing reads the cache and never wakes a frozen world; only joining does.
Answers are display data and a wake trigger. They carry no addresses and no
join authority: the launcher still verifies the game port itself before
joining. The doorman never proxies game traffic, so players keep their own
address for bans and logs.
"""
from __future__ import annotations

import json
import socket
import struct
import threading
import time
import urllib.parse

SCHEMA = 1
MAX_REQUEST = 512
REQUEST_TIMEOUT = 3
REFRESH_SECONDS = 30
# Seconds after a wake request during which an instance that has not answered
# its status topic yet still reads as waking rather than asleep or stopped.
WAKING_SECONDS = 60
WAKE_SPACING = 30            # one wake per address per this many seconds
REQUESTS_PER_MINUTE = 40     # per address, all requests
MAX_CONNECTIONS = 16
SUPERVISE_SECONDS = 30       # how often helper processes (transfer agents, coordinators) are checked


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


def topic(port, query, timeout=5):
    """Send one Topic to 127.0.0.1:port and return its text reply."""
    payload = b'\0' * 5 + query.encode('ascii') + b'\0'
    with socket.create_connection(('127.0.0.1', port), timeout=timeout) as connection:
        connection.sendall(b'\x00\x83' + struct.pack('>H', len(payload)) + payload)
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
        self.status_at = None
        self.waking_since = None
        self.waking_limit = WAKING_SECONDS
        self.idle_since = None
        self.next_watch = 0.0
        self.next_refresh = 0.0


class Doorman:
    def __init__(self, hosts, platform, clock=time.monotonic, wall=time.time, supervisors=()):
        self.instances = {}
        # Callables that restart a group's helper processes if they died; each
        # returns a dict of what it started (empty when everything was running).
        self.supervisors = list(supervisors)
        self.next_supervise = 0.0
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
        self.wakes = {}          # address -> last wake time
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
        return True

    def state(self, instance):
        now = self.clock()
        if instance.waking_since is not None and now - instance.waking_since > instance.waking_limit:
            instance.waking_since = None
        if instance.host.frozen() or instance.host.cold():
            return 'waking' if instance.waking_since is not None else 'asleep'
        if instance.waking_since is not None:
            return 'waking'
        return 'awake' if self.platform.listening(instance.port) else 'stopped'

    def describe(self, instance):
        with self.lock:
            entry = {'port': instance.port, 'state': self.state(instance), 'wake_estimate': self.estimate(instance)}
            if instance.status is not None:
                entry.update(instance.status)
                entry['cached_age'] = max(0, int(self.wall() - instance.status_at))
            return entry

    def estimate(self, instance):
        config = instance.host.config
        cold = instance.host.cold() is not None or (instance.waking_limit > WAKING_SECONDS and instance.waking_since is not None)
        return config['cold_start_estimate_seconds'] if cold else config['wake_estimate_seconds']

    def wake(self, instance, reason):
        """Thaw a frozen instance, or start a cold one from its last save, and mark
        it waking until its status answers."""
        with self.lock:
            host = instance.host
            if host.frozen():
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

    def low_memory(self, instance):
        """(free_mb, need_mb) when a frozen instance must not be woken for lack of memory.

        An awake instance needs nothing, and an unknown free amount does not block.
        """
        host = instance.host
        if host.frozen():
            need = host.config['wake_min_free_mb']
        elif host.cold():
            need = host.config['cold_start_min_free_mb']  # loading a save peaks far above a thaw
        else:
            return None
        if not need:
            return None
        free = self.platform.free_memory_mb()
        if free is None or free >= need:
            return None
        return free, need

    # -- requests ------------------------------------------------------------
    def allowed(self, address, now):
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
        if values.get('wake') == ['1'] and len(values) == 2 and len(values.get('port', [])) == 1:
            port = values['port'][0]
            instance = self.instances.get(int(port)) if port.isdigit() and len(port) <= 5 else None
            if instance is None:
                return {'schema': SCHEMA, 'ok': False, 'error': 'unknown port'}
            if instance.host.cold() and not instance.host.byond_signed_in():
                instance.host.log({'wake_refused': 'byond signed out', 'port': instance.port})
                return {'schema': SCHEMA, 'ok': False, 'error': 'byond signed out', 'port': instance.port}
            low = self.low_memory(instance)
            if low is not None:
                instance.host.log({'wake_refused': 'low memory', 'port': instance.port, 'free_mb': low[0], 'need_mb': low[1]})
                return {'schema': SCHEMA, 'ok': False, 'error': 'low memory', 'port': instance.port,
                        'free_mb': low[0], 'need_mb': low[1]}
            with self.lock:
                last = self.wakes.get(address)
                spaced = last is None or now - last >= WAKE_SPACING
                if spaced and (instance.host.frozen() or instance.host.cold()):
                    self.wakes[address] = now
            if spaced:
                self.wake(instance, 'doorman wake request')
            entry = self.describe(instance)
            return {'schema': SCHEMA, 'ok': True, 'port': instance.port, 'state': entry['state'],
                    'eta': entry['wake_estimate'] if entry['state'] in ('asleep', 'waking') else 0}
        return None

    def serve_connection(self, connection, address):
        try:
            connection.settimeout(REQUEST_TIMEOUT)
            header = _read(connection, 4)
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

    # -- the watch loop for every instance -----------------------------------
    def step(self):
        """One pass over every instance; returns seconds until the next pass."""
        now = self.clock()
        soonest = 30.0
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
