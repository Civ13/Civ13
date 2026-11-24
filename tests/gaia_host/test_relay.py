"""Offline tests for scripts/gaia-host/relay.py: routes, control requests and the pipe."""
import json
import queue
from pathlib import Path
import socket
import struct
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'scripts' / 'gaia-host'))
import relay  # noqa: E402
from doorman import frame, topic  # noqa: E402

TOKEN = 'ab' * 16


class Clock:
    def __init__(self):
        self.now = 1000.0

    def __call__(self):
        return self.now


class RoutesTest(unittest.TestCase):
    def setUp(self):
        self.clock = Clock()
        self.routes = relay.Routes([1714, 1716], self.clock)

    def test_route_is_taken_and_sticks(self):
        self.assertTrue(self.routes.set('203.0.113.5', 'alice', 1716))
        self.assertEqual(self.routes.take('203.0.113.5'), 1716)
        self.clock.now += relay.ROUTE_STICKY_SECONDS - 1
        self.assertEqual(self.routes.take('203.0.113.5'), 1716)  # reboot reconnect
        self.assertEqual(self.routes.lookup('alice'), {'ip': '203.0.113.5', 'port': 1716})

    def test_unused_route_expires(self):
        self.routes.set('203.0.113.5', 'alice', 1716)
        self.clock.now += relay.ROUTE_UNUSED_SECONDS + 1
        self.assertIsNone(self.routes.take('203.0.113.5'))
        self.assertIsNone(self.routes.lookup('alice'))

    def test_used_route_expires_after_sticky_time(self):
        self.routes.set('203.0.113.5', 'alice', 1716)
        self.routes.take('203.0.113.5')
        self.clock.now += relay.ROUTE_STICKY_SECONDS + 1
        self.assertIsNone(self.routes.take('203.0.113.5'))

    def test_last_write_wins_per_address_and_per_key(self):
        self.routes.set('203.0.113.5', 'alice', 1716)
        self.routes.set('203.0.113.5', 'bob', 1714)  # same household
        self.assertEqual(self.routes.take('203.0.113.5'), 1714)
        self.assertIsNone(self.routes.lookup('alice'))
        self.routes.set('198.51.100.7', 'bob', 1716)  # bob moved address
        self.assertIsNone(self.routes.take('203.0.113.5'))
        self.assertEqual(self.routes.lookup('bob'), {'ip': '198.51.100.7', 'port': 1716})

    def test_only_group_ports_and_valid_input(self):
        self.assertFalse(self.routes.set('203.0.113.5', 'alice', 1720))  # e.g. a transfer agent
        self.assertFalse(self.routes.set('not-an-ip', 'alice', 1716))
        self.assertFalse(self.routes.set('203.0.113.5', 'Alice!', 1716))
        self.assertEqual(self.routes.count(), 0)

    def test_a_routed_region_sending_a_player_on_keeps_their_real_address(self):
        self.routes.set('203.0.113.5', 'alice', 1716)  # the gate sent alice to a routed region
        self.assertEqual(self.routes.take('203.0.113.5'), 1716)
        self.assertTrue(self.routes.set('127.0.0.1', 'alice', 1714))  # that region sees loopback
        self.assertEqual(self.routes.take('203.0.113.5'), 1714)
        self.assertEqual(self.routes.lookup('alice'), {'ip': '203.0.113.5', 'port': 1714})

    def test_a_lan_player_arriving_from_the_public_address_gets_their_route(self):
        # The world saw the host's LAN address; the relay sees the router's public one.
        self.assertTrue(self.routes.set('192.168.0.20', 'val', 1716))
        self.assertEqual(self.routes.take('72.218.249.221'), 1716)
        self.assertEqual(self.routes.lookup('val'), {'ip': '72.218.249.221', 'port': 1716})
        self.assertEqual(self.routes.take('72.218.249.221'), 1716, 'the reconnect sticks to the public address')
        # Never a guess: two LAN routes waiting, a used one, or an expired one.
        self.routes.set('192.168.0.21', 'ann', 1714)
        self.routes.set('10.0.0.5', 'bob', 1716)
        self.assertIsNone(self.routes.take('8.8.8.8'))
        self.routes.take('10.0.0.5')
        self.assertEqual(self.routes.take('8.8.8.8'), 1714)
        self.routes.set('192.168.0.22', 'cy', 1714)
        self.clock.now += relay.ROUTE_UNUSED_SECONDS + 1
        self.assertIsNone(self.routes.take('8.8.4.4'))
        # A public route is never moved.
        self.routes.set('2.2.2.2', 'dee', 1714)
        self.routes.set('1.1.1.1', 'eve', 1714)
        self.assertIsNone(self.routes.take('9.9.9.9'))

    def test_ipv4_mapped_ipv6_is_the_same_address(self):
        self.routes.set('203.0.113.5', 'alice', 1716)
        self.assertEqual(self.routes.take('::ffff:203.0.113.5'), 1716)


class RelayedRegionSendsOnTest(unittest.TestCase):
    """A region behind the relay sees its players from loopback. Sending one on must
    route the player's own address: routing the host's public address instead left
    them unrouted (TDM Barracks to Battle behind the gateway, 2026-11-21)."""
    SOURCE = Path(__file__).resolve().parents[2] / 'code' / 'modules' / 'persistence' / 'region_relay.dm'

    def proc_body(self, name):
        text = self.SOURCE.read_text(encoding='utf-8')
        start = text.index(name)
        end = text.find('\n/', start + 1)
        return text[start:end]

    def test_routing_the_hosts_public_address_strands_the_player(self):
        routes = relay.Routes([1715, 1716], Clock())
        routes.set('85.220.24.225', 'sveit', 1716)  # the gateway sent them to the Barracks
        self.assertEqual(routes.take('85.220.24.225'), 1716)
        routes.set('93.184.216.34', 'sveit', 1715)  # the old Barracks named the host's own address
        self.assertIsNone(routes.take('85.220.24.225'))
        routes.set('85.220.24.225', 'sveit', 1716)
        routes.take('85.220.24.225')
        routes.set('127.0.0.1', 'sveit', 1715)  # loopback, as the Barracks now sends it
        self.assertEqual(routes.take('85.220.24.225'), 1715)

    def test_send_player_keeps_loopback_and_prefers_the_relayed_address(self):
        route_ip = self.proc_body('/proc/region_relay_route_ip(')
        self.assertIn('!region_relay_ip_loopback(public)', route_ip)
        send = self.proc_body('/datum/shard_group/proc/send_player(')
        self.assertIn('region_relay_route_ip(public, world.internet_address)', send)
        self.assertNotIn('public = world.internet_address', send)
        address = self.proc_body('/client/proc/public_address(')
        self.assertIn('region_relay_ip_loopback(address)', address)
        login = self.proc_body('/client/New(TopicData)')
        self.assertIn('region_relay_ip_loopback(address)', login)


class ControlTest(unittest.TestCase):
    def setUp(self):
        self.logged = []
        self.relay = relay.Relay([1714, 1716], TOKEN, log=self.logged.append)

    def test_route_lookup_and_status(self):
        self.assertEqual(self.relay.handle('route=1&ip=203.0.113.5&ckey=alice&port=1716&token=' + TOKEN), {'ok': True})
        self.assertEqual(self.relay.handle('lookup=1&ckey=alice&token=' + TOKEN),
                         {'ok': True, 'ip': '203.0.113.5', 'port': 1716})
        self.assertEqual(self.relay.handle('relay_status=1&token=' + TOKEN), {'ok': True, 'routes': 1, 'connections': 0})

    def test_add_port_lets_routes_name_a_new_region(self):
        route = 'route=1&ip=203.0.113.5&ckey=alice&port=1740&token=' + TOKEN
        self.assertEqual({'ok': False}, self.relay.handle(route))
        self.assertIsNone(self.relay.handle('add_port=1&port=1740&token=' + 'cd' * 16))
        self.assertEqual({'ok': False}, self.relay.handle('add_port=1&port=99999&token=' + TOKEN))
        self.assertEqual({'ok': True}, self.relay.handle('add_port=1&port=1740&token=' + TOKEN))
        self.assertEqual({'ok': True}, self.relay.handle(route))
        self.assertEqual({'ports': [1714, 1716, 1740]}, self.logged[0])
        # The host service repeats every port on each pass: a known port is fine and quiet.
        logged = len(self.logged)
        self.assertEqual({'ok': True}, self.relay.handle('add_port=1&port=1740&token=' + TOKEN))
        self.assertEqual({'ok': True}, self.relay.handle('add_port=1&port=1714&token=' + TOKEN))
        self.assertEqual(logged, len(self.logged))

    def test_the_gateway_names_only_a_group_port(self):
        self.assertEqual({'ok': False}, self.relay.handle('gate=1&port=1740&token=' + TOKEN))
        self.assertIsNone(self.relay.handle('gate=1&port=1714&token=' + 'cd' * 16))
        self.assertIsNone(self.relay.gate_port)
        self.assertEqual({'ok': True}, self.relay.handle('gate=1&port=1714&token=' + TOKEN))
        self.assertEqual(1714, self.relay.gate_port)
        self.assertEqual({'gate': 1714}, self.logged[-1])
        logged = len(self.logged)
        self.assertEqual({'ok': True}, self.relay.handle('gate=1&port=1714&token=' + TOKEN))
        self.assertEqual(logged, len(self.logged), 'the minutely repeat is quiet')

    def test_is_login_matches_only_a_whole_login_frame(self):
        self.assertTrue(relay.is_login(bytes.fromhex('000100160402000014010000197da25ae8799806000000000000')))
        self.assertFalse(relay.is_login(b'GET / HTTP/1.1\r\n'))
        self.assertFalse(relay.is_login(b'\x00\x83\x00\x02ab'))
        self.assertFalse(relay.is_login(b'\x00\x01'))

    def test_wrong_token_or_shape_is_dropped(self):
        self.assertIsNone(self.relay.handle('route=1&ip=203.0.113.5&ckey=alice&port=1716&token=' + 'cd' * 16))
        self.assertIsNone(self.relay.handle('route=1&ip=203.0.113.5&ckey=alice&port=1716'))
        self.assertIsNone(self.relay.handle('route=1&ip=1.2.3.4&ip=5.6.7.8&ckey=a&port=1716&token=' + TOKEN))
        self.assertIsNone(self.relay.handle('wake=1&port=1716&token=' + TOKEN))
        self.assertEqual(self.relay.handle('route=1&ip=203.0.113.5&ckey=alice&port=99999&token=' + TOKEN), {'ok': False})

    def test_control_must_be_loopback_and_token_valid(self):
        with self.assertRaises(ValueError):
            relay.Relay([1714], TOKEN, control=('0.0.0.0', 0))
        with self.assertRaises(ValueError):
            relay.Relay([1714], 'short')


class Upstream:
    """A stand-in world on a loopback port that echoes with a prefix and records what it got."""

    def __init__(self):
        self.server = socket.socket()
        self.server.bind(('127.0.0.1', 0))
        self.server.listen(4)
        self.port = self.server.getsockname()[1]
        self.received = []
        threading.Thread(target=self.serve, daemon=True).start()

    def serve(self):
        while True:
            try:
                connection, _ = self.server.accept()
            except OSError:
                return
            data = connection.recv(4096)
            self.received.append(data)
            connection.sendall(b'world:' + data)
            connection.close()

    def close(self):
        self.server.close()


class PipeTest(unittest.TestCase):
    def setUp(self):
        self.world = Upstream()
        self.logged = []
        self.relay = relay.Relay([self.world.port], TOKEN, public=('127.0.0.1', 0), control=('127.0.0.1', 0),
                                 capture=True, log=self.logged.append)
        self.public, self.control = self.relay.start()
        self.public_port = self.public.getsockname()[1]
        self.control_port = self.control.getsockname()[1]

    def tearDown(self):
        self.public.close()
        self.control.close()
        self.world.close()

    def exchange(self, data):
        with socket.create_connection(('127.0.0.1', self.public_port), timeout=5) as client:
            client.sendall(data)
            client.settimeout(5)
            chunks = []
            while True:
                try:
                    part = client.recv(4096)
                except socket.timeout:
                    break
                if not part:
                    break
                chunks.append(part)
            return b''.join(chunks)

    def test_routed_login_is_piped_with_its_first_bytes(self):
        reply = json.loads(topic(self.control_port, 'route=1&ip=127.0.0.1&ckey=alice&port=%d&token=%s' % (self.world.port, TOKEN)))
        self.assertEqual(reply, {'ok': True})
        login = b'\x00\x01\x00\x10hello-login-data'
        self.assertEqual(self.exchange(login), b'world:' + login)
        self.assertEqual(self.world.received, [login])
        self.assertTrue(any(entry.get('capture') == login.hex() for entry in self.logged))

    def test_piped_connections_send_small_frames_at_once(self):
        # Nagle held BYOND's small frames back behind the relay (TDM Barracks, 2026-11-21).
        seen = []
        original = relay.no_delay

        def record(sock):
            original(sock)
            seen.append(sock.getsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY))
        relay.no_delay = record
        try:
            self.relay.routes.set('127.0.0.1', 'alice', self.world.port)
            self.exchange(b'\x00\x01\x00\x04abcd')
        finally:
            relay.no_delay = original
        self.assertEqual(2, len(seen), 'both the player and the world side')
        self.assertTrue(all(seen))

    def test_unrouted_connection_is_closed(self):
        self.assertEqual(self.exchange(b'\x00\x01\x00\x04abcd'), b'')
        self.assertEqual(self.world.received, [])

    def test_unrouted_login_goes_to_the_gateway_once_it_has_named_its_port(self):
        # 2026-11-23: players who rejoined the relay port from BYOND's reconnect list
        # had no route and got "Connection failed during handshake".
        login = bytes.fromhex('000100160402000014010000235a022efa929706000000000000')
        self.assertEqual(self.exchange(login), b'', 'no gateway named yet: dropped as before')
        reply = json.loads(topic(self.control_port, 'gate=1&port=%d&token=%s' % (self.world.port, TOKEN)))
        self.assertEqual(reply, {'ok': True})
        self.assertEqual(self.exchange(login), b'world:' + login)
        self.assertTrue(any(entry.get('unrouted_to_gate') == '127.0.0.1' for entry in self.logged))
        # Scanners and stray bytes never reach the gateway.
        for junk in (b'GET / HTTP/1.0\r\n\r\n', bytes.fromhex('030000130ee00000000000010008000b000000'), b'\r\n\r\n',
                     b'\x00\x01\x00\x30short'):
            self.assertEqual(self.exchange(junk), b'')
        self.assertEqual(self.world.received, [login])

    def test_topic_frame_is_never_forwarded(self):
        self.relay.routes.set('127.0.0.1', 'alice', self.world.port)
        payload = b'\0' * 5 + b'?status=1\0'
        self.assertEqual(self.exchange(b'\x00\x83' + struct.pack('>H', len(payload)) + payload), b'')
        self.assertEqual(self.world.received, [])

    def test_down_world_is_woken_through_the_doorman_and_refused_if_it_stays_down(self):
        woken = []
        self.relay.wake = lambda port: woken.append(port) or 'waking'
        original = relay.HOLD_SECONDS
        relay.HOLD_SECONDS = 0
        try:
            self.relay.routes.set('127.0.0.1', 'alice', self.world.port)
            self.assertEqual(self.exchange(b'\x00\x01\x00\x04abcd'), b'')
        finally:
            relay.HOLD_SECONDS = original
        self.assertEqual(woken[:1], [self.world.port])
        self.assertEqual(self.world.received, [])

    def test_control_answers_http_get(self):
        with socket.create_connection(('127.0.0.1', self.control_port), timeout=5) as client:
            client.sendall(('GET /?relay_status=1&token=%s HTTP/1.1\r\nHost: x\r\n\r\n' % TOKEN).encode())
            data = b''
            while True:
                part = client.recv(4096)
                if not part:
                    break
                data += part
        self.assertTrue(data.startswith(b'HTTP/1.1 200 OK'))
        self.assertEqual(json.loads(data.split(b'\r\n\r\n', 1)[1]), {'ok': True, 'routes': 0, 'connections': 0})

    def test_control_reply_is_a_topic_frame(self):
        with socket.create_connection(('127.0.0.1', self.control_port), timeout=5) as client:
            query = b'\0' * 5 + ('?relay_status=1&token=' + TOKEN).encode() + b'\0'
            client.sendall(b'\x00\x83' + struct.pack('>H', len(query)) + query)
            data = client.recv(4096)
        self.assertEqual(data, frame(json.dumps({'ok': True, 'routes': 0, 'connections': 0}, separators=(',', ':'))))


class DisconnectTest(unittest.TestCase):
    def admission(self, log, close_side='world'):
        port = 1716
        client, relay_client = socket.socketpair()
        relay_world, world = socket.socketpair()
        for sock in (client, relay_client, relay_world, world):
            self.addCleanup(sock.close)
        for peer in (client, world):
            peer.settimeout(1)
        service = relay.Relay([port], TOKEN, connect=lambda _: relay_world,
                              log=lambda _: None, disconnect_log=log)
        self.assertTrue(service.routes.set('203.0.113.5', 'privatekey', port))
        self.assertTrue(service.slots.acquire(blocking=False))
        connection = threading.Thread(target=service.serve_player,
                                      args=(relay_client, '203.0.113.5'), daemon=True)
        connection.start()
        login = b'\x00\x01\x00\x04abcd'
        client.sendall(login)
        self.assertEqual(relay._read(world, len(login)), login)
        world.sendall(b'world')
        self.assertEqual(relay._read(client, 5), b'world')
        client.sendall(b'client')
        self.assertEqual(relay._read(world, 6), b'client')
        closer, other = (world, client) if close_side == 'world' else (client, world)
        closer.shutdown(socket.SHUT_WR)
        self.assertEqual(other.recv(1), b'')
        connection.join(1)
        self.assertFalse(connection.is_alive())
        self.assertEqual(service.active, 0)

    def test_world_and_client_eof_report_only_the_first_side(self):
        rows = queue.Queue()
        log = relay.DisconnectLog(rows.put)
        for side in ('world', 'client'):
            with self.subTest(side=side):
                self.admission(log, side)
                row = rows.get(timeout=1)
                self.assertEqual(set(row), {'event', 'time', 'route_port', 'side', 'reason', 'duration_ms'})
                self.assertEqual(row['event'], 'relay_disconnect')
                self.assertEqual(row['route_port'], 1716)
                self.assertEqual(row['side'], side)
                self.assertEqual(row['reason'], 'eof')
                self.assertGreaterEqual(row['duration_ms'], 0)
        # FIFO barrier after both handlers finished: no synthetic EOF rows.
        log.offer('done')
        self.assertEqual(rows.get(timeout=1), 'done')

    def test_recv_errors_name_source_and_send_errors_name_target(self):
        class PipeEnd:
            def __init__(self, recv_error=False, send_error=False):
                self.recv_error = recv_error
                self.send_error = send_error

            def recv(self, count):
                if self.recv_error:
                    raise OSError('private read detail')
                return b'private payload'

            def sendall(self, data):
                if self.send_error:
                    raise OSError('private write detail')

            def shutdown(self, how):
                pass

        for source, target, expected in (
            (PipeEnd(recv_error=True), PipeEnd(), ('client', 'recv_error')),
            (PipeEnd(), PipeEnd(send_error=True), ('world', 'send_error')),
        ):
            seen = []
            relay.Relay.pump(source, target, 'client', 'world', lambda *args: seen.append(args))
            self.assertEqual(seen, [expected])

    def test_full_queue_with_blocked_sink_does_not_delay_traffic_or_close(self):
        writing, release = threading.Event(), threading.Event()
        rows = queue.Queue()

        def write(row):
            writing.set()
            release.wait(5)
            rows.put(row)

        log = relay.DisconnectLog(write, capacity=1)
        self.addCleanup(release.set)
        log.offer('writing')
        self.assertTrue(writing.wait(1))
        log.offer('queued')

        # Both directions transmit and the handler releases its slot while the
        # diagnostic writer is blocked and its queue has no remaining space.
        self.admission(log)
        self.assertEqual(log.pending.qsize(), 1)
        release.set()
        self.assertEqual(rows.get(timeout=1), 'writing')
        self.assertEqual(rows.get(timeout=1), 'queued')

    def test_first_forward_error_is_recorded_for_the_admitted_route(self):
        class RefusingWorld:
            def setsockopt(self, *args):
                pass

            def sendall(self, data):
                raise OSError('private wire error')

            def close(self):
                pass

        rows = queue.Queue()
        service = relay.Relay([1716], TOKEN, connect=lambda _: RefusingWorld(),
                              disconnect_log=relay.DisconnectLog(rows.put))
        service.routes.set('203.0.113.5', 'privatekey', 1716)
        self.assertTrue(service.slots.acquire(blocking=False))
        client, relay_client = socket.socketpair()
        with client, relay_client:
            client.sendall(b'\x00\x01\x00\x04abcd')
            service.serve_player(relay_client, '203.0.113.5')
        row = rows.get(timeout=1)
        self.assertEqual((row['route_port'], row['side'], row['reason']), (1716, 'world', 'send_error'))
        self.assertEqual(service.active, 0)

    def test_worker_start_failure_does_not_prevent_traffic(self):
        with patch.object(relay.threading.Thread, 'start', side_effect=RuntimeError):
            log = relay.DisconnectLog(lambda row: self.fail('writer unavailable'))
        self.assertIsNone(log.pending)
        self.admission(log)

    def test_cli_sink_is_lazy_separate_json_and_rotates(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'relay-disconnects.log'
            completed = threading.Event()
            handlers = []
            handler_type = relay.DisconnectFile

            def handler_factory(*args, **kwargs):
                handler = handler_type(*args, **kwargs)
                handlers.append(handler)
                return handler

            with patch.object(relay, 'DISCONNECT_LOG_BYTES', 200), patch.object(
                    relay, 'DisconnectFile', handler_factory):
                log = relay.DisconnectLog.for_file(path)
                self.assertFalse(path.exists())
                actual_write = log.write

                def signal_write(row):
                    if row is None:
                        for handler in handlers:
                            handler.close()
                        completed.set()
                    else:
                        actual_write(row)

                log.write = signal_write
                for sequence in range(12):
                    log.offer({'event': 'relay_disconnect', 'duration_ms': sequence})
                log.offer(None)
                self.assertTrue(completed.wait(1))
            files = sorted(Path(directory).iterdir())
            self.assertEqual([file.name for file in files],
                             [path.name, path.name + '.1', path.name + '.2'])
            self.assertTrue(all(file.stat().st_size <= 200 for file in files))
            rows = [json.loads(line) for line in path.read_text().splitlines()]
            self.assertEqual(rows[-1], {'event': 'relay_disconnect', 'duration_ms': 11})

    def test_io_failure_does_not_stop_later_diagnostics(self):
        rows = queue.Queue()

        def write(row):
            if row == 'fail':
                raise OSError('diagnostic sink failed')
            rows.put(row)

        log = relay.DisconnectLog(write)
        log.offer('fail')
        log.offer('recover')
        self.assertEqual(rows.get(timeout=1), 'recover')


if __name__ == '__main__':
    unittest.main()
