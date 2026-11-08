"""Routing relay: one public port in front of a host's region worlds.

Every region of a shard group listens on its own port, and players used to need
one forwarded router port per world. The relay lets a group publish a single
extra port (relay_port) instead. It does not decide where anyone goes: the gate
world (the group's mainland, which players join directly with their real
address) asks the coordinator for the account's home, writes a route for the
player's IP here, and then links the player to the relay. The relay forwards
each new connection from that IP to the routed region on 127.0.0.1.

Two listeners:

    public  (relay_bind:relay_port)       player logins only; a BYOND Topic frame
                                          is never forwarded, so nothing from the
                                          internet reaches a world as loopback
    control (127.0.0.1:relay_control_port) HTTP GET /?query (what DM's rust_g
                                          sends) or Topic framing, loopback peers
                                          only, and every request carries the token:
        ?route=1&ip=A&ckey=K&port=P&token=T   send A's next connections to P
        ?lookup=1&ckey=K&token=T              the routed address of K
        ?relay_status=1&token=T               route and connection counts

Routes are last-write-wins per address. One that is never used expires after
ROUTE_UNUSED_SECONDS; a used one sticks for ROUTE_STICKY_SECONDS after its last
use, so the automatic reconnect after a world reboot lands in the same world.
A route only ever names one of the group's own game ports.

Before piping, the relay asks the doorman to wake the region and holds the
connection up to HOLD_SECONDS until the doorman reports it awake (a frozen
world still accepts TCP, and the freeze watcher ignores loopback, so the relay
never just probes the port). A cold start takes minutes, so the gate wakes the
region and waits for it before it writes the route.

--capture logs the first bytes of every public connection (hex) so the client
login packet can be measured on the real host. It may contain the player's key,
so the log stays on that machine.
"""
from __future__ import annotations

import argparse
import ipaddress
import json
import re
import socket
import struct
import sys
import threading
import time
import urllib.parse
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from doorman import _read, frame, http_reply, is_http, parse_request, read_http_query, topic  # noqa: E402

ROUTE_UNUSED_SECONDS = 60
ROUTE_STICKY_SECONDS = 6 * 3600
MAX_ROUTES = 8192
MAX_CONNECTIONS = 256
MAX_CONTROL = 16
FIRST_BYTES_SECONDS = 15     # a client that sends nothing is dropped
HOLD_SECONDS = 20            # how long a connection waits for a thawing world
CAPTURE_BYTES = 64
CKEY = re.compile(r'^[a-z0-9]{1,64}$')
HEX = re.compile(r'^[0-9a-f]{32,128}$')


def is_topic(first):
    """True when the first bytes of a connection are a BYOND Topic frame."""
    return first[:2] == b'\x00\x83'


def normal_ip(text):
    """The canonical form of an IP address (IPv4-mapped IPv6 folded to IPv4), or None."""
    try:
        address = ipaddress.ip_address(text)
    except ValueError:
        return None
    if address.version == 6 and address.ipv4_mapped is not None:
        address = address.ipv4_mapped
    return str(address)


def loopback(text):
    address = normal_ip(text)
    return address is not None and ipaddress.ip_address(address).is_loopback


class Routes:
    """address -> the region port its next connections go to."""

    def __init__(self, ports, clock=time.monotonic):
        self.ports = frozenset(ports)
        self.clock = clock
        self.lock = threading.Lock()
        self.by_ip = {}      # ip -> {'ckey', 'port', 'set_at', 'used_at'}
        self.by_ckey = {}    # ckey -> ip

    def _expired(self, route, now):
        if route['used_at'] is None:
            return now - route['set_at'] > ROUTE_UNUSED_SECONDS
        return now - route['used_at'] > ROUTE_STICKY_SECONDS

    def _drop(self, ip):
        route = self.by_ip.pop(ip, None)
        if route is not None and self.by_ckey.get(route['ckey']) == ip:
            del self.by_ckey[route['ckey']]

    def prune(self):
        now = self.clock()
        with self.lock:
            for ip in [ip for ip, route in self.by_ip.items() if self._expired(route, now)]:
                self._drop(ip)

    def set(self, ip, ckey, port):
        """Route ip to port for ckey; False when the request is not valid."""
        ip = normal_ip(ip)
        if ip is None or not CKEY.match(ckey or '') or port not in self.ports:
            return False
        now = self.clock()
        with self.lock:
            old = self.by_ckey.get(ckey)
            # A player already behind the relay reaches their region from 127.0.0.1, so a
            # region that sends them on (the Regions panel's Join) names loopback. Keep their
            # real address: routing loopback dropped the player's own route and left the next
            # connection unrouted (Rail Yard to Gaia, 2026-11-08).
            if loopback(ip) and old is not None and not loopback(old):
                ip = old
            if old is not None and old != ip:
                self._drop(old)
            self._drop(ip)
            if len(self.by_ip) >= MAX_ROUTES:
                for stale in [key for key, route in self.by_ip.items() if self._expired(route, now)]:
                    self._drop(stale)
                if len(self.by_ip) >= MAX_ROUTES:
                    return False
            self.by_ip[ip] = {'ckey': ckey, 'port': port, 'set_at': now, 'used_at': None}
            self.by_ckey[ckey] = ip
        return True

    def take(self, ip):
        """The port for a new connection from ip, marking the route used; None if unrouted."""
        ip = normal_ip(ip)
        now = self.clock()
        with self.lock:
            route = self.by_ip.get(ip)
            if route is None:
                return None
            if self._expired(route, now):
                self._drop(ip)
                return None
            route['used_at'] = now
            return route['port']

    def lookup(self, ckey):
        now = self.clock()
        with self.lock:
            ip = self.by_ckey.get(ckey)
            route = self.by_ip.get(ip) if ip else None
            if route is None or self._expired(route, now):
                return None
            return {'ip': ip, 'port': route['port']}

    def count(self):
        with self.lock:
            return len(self.by_ip)


class Relay:
    def __init__(self, ports, token, public=('0.0.0.0', 0), control=('127.0.0.1', 0), doorman_port=None,
                 capture=False, clock=time.monotonic, log=None, wake=None, connect=None):
        if not HEX.match(token or ''):
            raise ValueError('relay token must be 32 to 128 lowercase hex characters')
        if not loopback(control[0]):
            raise ValueError('the relay control port must bind a loopback address')
        self.routes = Routes(ports, clock)
        self.token = token
        self.public = public
        self.control = control
        self.doorman_port = doorman_port
        self.capture = capture
        self.clock = clock
        self.log = log or (lambda values: print(json.dumps(dict(values, time=int(time.time()))), flush=True))
        self.wake = wake or self._wake
        self.connect = connect or self._connect
        self.slots = threading.BoundedSemaphore(MAX_CONNECTIONS)
        self.control_slots = threading.BoundedSemaphore(MAX_CONTROL)
        self.active = 0
        self.lock = threading.Lock()

    # -- control -------------------------------------------------------------
    def handle(self, query):
        """The reply object for one control request, or None to drop it."""
        try:
            values = urllib.parse.parse_qs(query, strict_parsing=True, max_num_fields=6)
        except ValueError:
            return None
        if any(len(items) != 1 for items in values.values()):
            return None
        values = {key: items[0] for key, items in values.items()}
        if values.get('token') != self.token:
            return None
        if values.get('route') == '1' and set(values) == {'route', 'ip', 'ckey', 'port', 'token'}:
            port = int(values['port']) if values['port'].isdigit() and len(values['port']) <= 5 else 0
            ok = self.routes.set(values['ip'], values['ckey'], port)
            if ok:
                self.log({'route': values['ckey'], 'port': port})
            return {'ok': ok}
        if values.get('lookup') == '1' and set(values) == {'lookup', 'ckey', 'token'}:
            found = self.routes.lookup(values['ckey'])
            return dict(found, ok=True) if found else {'ok': False}
        if values.get('relay_status') == '1' and set(values) == {'relay_status', 'token'}:
            self.routes.prune()
            with self.lock:
                active = self.active
            return {'ok': True, 'routes': self.routes.count(), 'connections': active}
        return None

    def serve_control(self, connection, address):
        try:
            if not loopback(address):
                return
            connection.settimeout(3)
            header = _read(connection, 4)
            if is_http(header):
                query = read_http_query(connection, header)
                connection.sendall(http_reply(self.handle(query) if query is not None else None))
                return
            length = struct.unpack('>H', header[2:])[0]
            if not is_topic(header) or length > 512:
                return
            query = parse_request(header + _read(connection, length))
            reply = self.handle(query) if query is not None else None
            if reply is not None:
                connection.sendall(frame(json.dumps(reply, separators=(',', ':'))))
        except (OSError, RuntimeError, ValueError):
            pass
        finally:
            connection.close()
            self.control_slots.release()

    # -- player connections --------------------------------------------------
    def _connect(self, port):
        return socket.create_connection(('127.0.0.1', port), timeout=5)

    def _wake(self, port):
        """The doorman's state for port after asking it to wake ('awake', 'waking', ...).

        Without a doorman every world counts as awake. A frozen world still accepts
        TCP connections, so the relay must ask rather than probe the port.
        """
        if not self.doorman_port:
            return 'awake'
        try:
            reply = json.loads(topic(self.doorman_port, 'wake=1&port=%d' % port, timeout=5))
        except (OSError, RuntimeError, ValueError):
            return None
        return reply.get('state') if isinstance(reply, dict) and reply.get('ok') else None

    def open_world(self, port):
        """A connection to port once its world is awake, or None after HOLD_SECONDS."""
        deadline = self.clock() + HOLD_SECONDS
        while True:
            if self.wake(port) == 'awake':
                try:
                    return self.connect(port)
                except OSError:
                    pass
            if self.clock() >= deadline:
                return None
            time.sleep(0.5)

    def serve_player(self, connection, address):
        upstream = None
        try:
            connection.settimeout(FIRST_BYTES_SECONDS)
            first = connection.recv(4096)
            if len(first) < 4:
                first += _read(connection, 4 - len(first)) if first else b''
            if self.capture:
                self.log({'capture': first[:CAPTURE_BYTES].hex(), 'length': len(first), 'from': normal_ip(address)})
            if len(first) < 4 or is_topic(first):
                return
            port = self.routes.take(address)
            if port is None:
                self.log({'unrouted': normal_ip(address)})
                return
            upstream = self.open_world(port)
            if upstream is None:
                self.log({'not_ready': port})
                return
            upstream.sendall(first)
            connection.settimeout(None)
            upstream.settimeout(None)
            with self.lock:
                self.active += 1
            try:
                pump = threading.Thread(target=self.pump, args=(upstream, connection), daemon=True)
                pump.start()
                self.pump(connection, upstream)
                pump.join()
            finally:
                with self.lock:
                    self.active -= 1
        except (OSError, RuntimeError):
            pass
        finally:
            if upstream is not None:
                upstream.close()
            connection.close()
            self.slots.release()

    @staticmethod
    def pump(source, target):
        """Copy source to target until either side closes, then close both directions."""
        try:
            while True:
                data = source.recv(65536)
                if not data:
                    break
                target.sendall(data)
        except OSError:
            pass
        for side in (source, target):
            try:
                side.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass

    # -- listeners -----------------------------------------------------------
    @staticmethod
    def bind(address):
        family = socket.AF_INET6 if ':' in address[0] else socket.AF_INET
        server = socket.socket(family, socket.SOCK_STREAM)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind(address)
        server.listen(64)
        return server

    def accept_forever(self, server, serve, slots):
        while True:
            connection, peer = server.accept()
            if not slots.acquire(blocking=False):
                connection.close()
                continue
            threading.Thread(target=serve, args=(connection, peer[0]), daemon=True).start()

    def start(self):
        """Bind both listeners and serve them on daemon threads; returns (public, control) sockets."""
        public = self.bind(self.public)
        control = self.bind(self.control)
        threading.Thread(target=self.accept_forever, args=(public, self.serve_player, self.slots), daemon=True).start()
        threading.Thread(target=self.accept_forever, args=(control, self.serve_control, self.control_slots), daemon=True).start()
        return public, control

    def run(self):
        public, control = self.start()
        self.log({'relay': '%s:%d' % public.getsockname()[:2], 'control': '%s:%d' % control.getsockname()[:2],
                  'ports': sorted(self.routes.ports), 'capture': self.capture})
        while True:
            time.sleep(60)
            self.routes.prune()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--port', type=int, required=True, help='public port players are linked to')
    parser.add_argument('--bind', default='0.0.0.0')
    parser.add_argument('--control-port', type=int, required=True, help='loopback control port')
    parser.add_argument('--token-file', required=True)
    parser.add_argument('--region-port', type=int, action='append', required=True,
                        help='a game port routes may name; repeat for every region')
    parser.add_argument('--doorman-port', type=int, default=None)
    parser.add_argument('--capture', action='store_true', help='log the first bytes of every public connection')
    args = parser.parse_args(argv)
    try:
        token = Path(args.token_file).read_text(encoding='utf-8').strip()
        relay = Relay(args.region_port, token, (args.bind, args.port), ('127.0.0.1', args.control_port),
                      args.doorman_port, args.capture)
        relay.run()
    except (OSError, ValueError) as error:
        print(json.dumps({'ok': False, 'error': 'relay: %s' % error}), flush=True)
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
