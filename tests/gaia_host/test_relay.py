"""Offline tests for scripts/gaia-host/relay.py: routes, control requests and the pipe."""
import json
from pathlib import Path
import socket
import struct
import sys
import threading
import unittest

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

    def test_ipv4_mapped_ipv6_is_the_same_address(self):
        self.routes.set('203.0.113.5', 'alice', 1716)
        self.assertEqual(self.routes.take('::ffff:203.0.113.5'), 1716)


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

    def test_unrouted_connection_is_closed(self):
        self.assertEqual(self.exchange(b'\x00\x01\x00\x04abcd'), b'')
        self.assertEqual(self.world.received, [])

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


if __name__ == '__main__':
    unittest.main()
