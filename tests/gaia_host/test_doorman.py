"""Offline tests for scripts/gaia-host/doorman.py with the fake machine from test_gaia_host."""
import json
import os
from pathlib import Path
import socket
import struct
import sys
import threading
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import test_gaia_host as base  # noqa: E402

gaia_host = base.gaia_host
import doorman  # noqa: E402  (gaia_host put scripts/gaia-host on sys.path)


class Machine(base.FakeMachine):
    def __init__(self):
        super().__init__()
        self.status_calls = 0
        self.free_mb = 8192
        self.boot = None
        self.pager = None

    def free_memory_mb(self):
        return self.free_mb

    def boot_time(self):
        return self.boot

    def byond_pager_running(self):
        return self.pager

    def terminate(self, pid):
        self.calls.append(['terminate', pid])
        self.up = False
        self.suspended = 0

    def status_topic(self, port):
        if self.suspended:
            raise OSError('frozen')
        self.status_calls += 1
        return json.dumps({'players': self.clients, 'map_name': 'Gaia', 'map_gamemode': 'Nomads'})

    def region_topic(self, port):
        if self.suspended:
            raise OSError('frozen')
        if getattr(self, 'region', None) is None:
            return json.dumps({'group': None})
        return json.dumps(dict(self.region, players=self.clients))


def request(query):
    payload = b'\0' * 5 + query.encode('ascii') + b'\0'
    return b'\x00\x83' + struct.pack('>H', len(payload)) + payload


class DoormanTests(base.GaiaHostTests):
    def setUp(self):
        super().setUp()
        self.machine = Machine()
        self.host = gaia_host.Host(self.config, self.machine, script=Path('gaia_host.py'))
        self.host.log = lambda values: None
        self.clock = [1000.0]
        self.door = doorman.Doorman([self.host], self.machine, clock=lambda: self.clock[0], wall=lambda: self.clock[0])
        self.instance = self.door.instances[1714]

    def ask(self, query, address='203.0.113.9'):
        return self.door.handle(query, address)

    def test_status_shows_the_cache_and_asleep_without_waking(self):
        self.running()
        self.door.step()
        self.assertEqual(self.ask('host_status=1')['instances'][0]['state'], 'awake')
        self.host.freeze()
        self.clock[0] += 120
        entry = self.ask('host_status=1')['instances'][0]
        self.assertEqual((entry['state'], entry['map_name'], entry['players'], entry['cached_age']), ('asleep', 'Gaia', 0, 120))
        self.assertFalse(entry['cold'])  # frozen in memory: thaws at once
        self.assertEqual(self.machine.suspended, 1)

    def test_host_status_carries_the_region_answer_of_a_grouped_world(self):
        # Regions read each other from here instead of a blocking world.Export poll.
        self.running()
        self.door.step()
        self.assertNotIn('region', self.ask('host_status=1')['instances'][0])
        self.machine.region = {'group': 'earth', 'region': 'gaia', 'name': 'Gaia', 'kind': 'MAINLAND', 'map': 'Gaia',
                               'ordinal_age': 8, 'secret': 'never copied'}
        self.clock[0] += doorman.REFRESH_SECONDS
        self.door.step()
        entry = self.ask('host_status=1')['instances'][0]
        self.assertEqual(entry['region'], {'group': 'earth', 'region': 'gaia', 'name': 'Gaia', 'kind': 'MAINLAND',
                                           'map': 'Gaia', 'ordinal_age': 8, 'players': self.machine.clients})
        self.machine.region = 'not json at all'
        self.machine.region_topic = lambda port: 'garbage'
        self.clock[0] += doorman.REFRESH_SECONDS
        self.door.step()
        self.assertNotIn('region', self.ask('host_status=1')['instances'][0])

    def test_wake_thaws_once_and_reads_waking_until_the_world_answers(self):
        self.running()
        self.door.step()
        self.host.freeze()
        reply = self.ask('wake=1&port=1714')
        self.assertEqual((reply['ok'], reply['state'], self.machine.suspended), (True, 'waking', 0))
        self.assertEqual(self.ask('host_status=1')['instances'][0]['state'], 'waking')
        self.door.step()
        self.assertEqual(self.ask('host_status=1')['instances'][0]['state'], 'awake')

    def test_wake_is_refused_without_memory_headroom(self):
        self.running()
        self.host.freeze()
        self.machine.free_mb = 700
        reply = self.ask('wake=1&port=1714')
        self.assertEqual(reply, {'schema': 1, 'ok': False, 'error': 'low memory', 'port': 1714, 'free_mb': 700, 'need_mb': 1024})
        self.assertEqual(self.machine.suspended, 1)
        self.assertEqual(self.ask('host_status=1')['instances'][0]['state'], 'asleep')
        # A refusal does not use up the address's wake spacing.
        self.machine.free_mb = 1024
        self.assertEqual(self.ask('wake=1&port=1714')['state'], 'waking')
        self.assertEqual(self.machine.suspended, 0)

    def test_memory_check_is_configurable_and_unknown_does_not_block(self):
        self.running()
        self.host.freeze()
        self.machine.free_mb = None
        self.assertTrue(self.ask('wake=1&port=1714')['ok'])
        self.door.step()
        self.host.freeze()
        self.machine.free_mb = 10
        self.host.config['wake_min_free_mb'] = 0
        self.assertTrue(self.ask('wake=1&port=1714', address='198.51.100.7')['ok'])
        self.assertEqual(self.machine.suspended, 0)

    # -- low-memory eviction -------------------------------------------------
    def test_low_memory_stops_a_frozen_world_which_then_starts_from_its_save(self):
        self.running()
        self.saved_at(50)
        self.host.freeze()
        self.machine.free_mb = 500
        self.door.step()
        self.assertIn(['terminate', 4242], self.machine.calls)
        self.assertEqual(self.host.cold()['evicted'], 'low memory: 500 MB free')
        entry = self.ask('host_status=1')['instances'][0]
        self.assertEqual((entry['state'], entry['cold']), ('asleep', True))
        self.door.step()  # spaced: nothing left to stop, and no second attempt yet
        self.assertEqual(self.machine.calls.count(['terminate', 4242]), 1)

    def test_eviction_needs_a_save_before_freezing_and_can_be_turned_off(self):
        self.running()
        self.host.config['freeze_requires_save'] = False
        self.host.freeze()
        self.machine.free_mb = 500
        self.door.step()
        self.assertNotIn(['terminate', 4242], self.machine.calls)
        with self.assertRaisesRegex(gaia_host.Refused, 'saved before freezing'):
            self.host.evict()
        self.host.config['freeze_requires_save'] = True
        self.host.config['evict_below_free_mb'] = 0
        self.clock[0] += 120
        self.door.step()
        self.assertNotIn(['terminate', 4242], self.machine.calls)

    def test_a_wake_stops_the_longest_asleep_other_world_to_make_room(self):
        class Sleeper:
            def __init__(self, port, frozen_at, machine):
                self.config = dict(gaia_host.FREEZE_DEFAULTS, port=port)
                self.state = {'pid': port, 'frozen_at': frozen_at}
                self.cold_state = None
                self.machine = machine
                self.log = lambda values: None

            def frozen(self):
                return self.state

            def cold(self):
                return self.cold_state

            def byond_signed_in(self):
                return True

            def evict(self, reason):
                self.cold_state, self.state = {'evicted': reason}, None
                self.machine.free_mb += 1000
                return {'evicted': True}

            def thaw(self, reason):
                self.state = None
                return {'thawed': True}

        machine = Machine()
        machine.free_mb = 300
        old, newer, wanted = Sleeper(1801, 10, machine), Sleeper(1802, 20, machine), Sleeper(1803, 5, machine)
        door = doorman.Doorman([old, newer, wanted], machine, clock=lambda: self.clock[0], wall=lambda: self.clock[0])
        reply = door.handle('wake=1&port=1803', '203.0.113.9')
        self.assertEqual((reply['ok'], reply['state']), (True, 'waking'))
        # 1803 itself froze first but is the one being woken; 1801 is the longest-asleep other world.
        self.assertEqual((old.cold_state, newer.cold_state), ({'evicted': 'memory for waking port 1803'}, None))
        self.assertIsNone(wanted.state)

    def test_routed_instances_are_marked_for_the_launcher(self):
        self.running()
        self.assertNotIn('routed', self.ask('host_status=1')['instances'][0])
        self.host.config['routed'] = True
        self.assertTrue(self.ask('host_status=1')['instances'][0]['routed'])

    def test_one_address_may_wake_two_worlds_in_a_row(self):
        # The routing relay asks from loopback for every region; spacing is per port.
        class Sleeper:
            def __init__(self, port):
                self.config = dict(gaia_host.FREEZE_DEFAULTS, port=port)
                self.state = {'pid': port, 'frozen_at': 1}
                self.log = lambda values: None

            def frozen(self):
                return self.state

            def cold(self):
                return None

            def thaw(self, reason):
                self.state = None
                return {'thawed': True}

        first, second = Sleeper(1801), Sleeper(1802)
        door = doorman.Doorman([first, second], Machine(), clock=lambda: self.clock[0], wall=lambda: self.clock[0])
        door.handle('wake=1&port=1801', '127.0.0.1')
        door.handle('wake=1&port=1802', '127.0.0.1')
        self.assertEqual((first.state, second.state), (None, None))

    # -- surviving a power-down ---------------------------------------------
    def saved_at(self, moment):
        base.write_save(self.repo / 'map_saves')
        os.utime(self.repo / 'map_saves' / 'save_complete.txt', (moment, moment))

    def test_freeze_waits_for_a_save_newer_than_the_last_player(self):
        self.running(clients=1)
        self.saved_at(50)
        self.machine.clock = 100
        self.assertEqual(self.host.watch_step(None), (None, 30))  # remembers the player
        self.machine.clients = 0
        idle, _ = self.host.watch_step(None)
        self.machine.clock = 100 + 15 * 60
        self.assertEqual(self.host.watch_step(idle), (idle, 60))
        with self.assertRaisesRegex(gaia_host.Refused, 'save newer than the last player'):
            self.host.freeze()
        self.assertEqual(self.machine.suspended, 0)
        self.saved_at(200)  # the world saved itself once it was empty
        self.host.watch_step(idle)
        self.assertEqual(self.machine.suspended, 1)

    def test_a_power_down_leaves_a_cold_server_that_starts_from_its_save_on_wake(self):
        self.running()
        self.saved_at(50)
        self.host.freeze()
        self.machine.up = False  # the machine went down; nothing listens after the reboot
        self.machine.suspended = 0
        self.assertIsNone(self.host.frozen())
        self.assertIsNotNone(self.host.cold())
        entry = self.ask('host_status=1')['instances'][0]
        self.assertEqual((entry['state'], entry['wake_estimate'], entry['cold']), ('asleep', 300, True))
        self.machine.free_mb = 2000  # enough to thaw, not enough to load a save
        refused = self.ask('wake=1&port=1714')
        self.assertEqual((refused['ok'], refused['need_mb']), (False, 2560))
        self.machine.free_mb = 8192
        reply = self.ask('wake=1&port=1714')
        self.assertEqual((reply['ok'], reply['state'], reply['eta']), (True, 'waking', 300))
        self.assertEqual(self.machine.detached[-1][-2], 'start')
        self.assertIsNone(self.host.cold())
        self.clock[0] += 200  # a cold start reads waking for much longer than a thaw
        self.assertEqual(self.ask('host_status=1')['instances'][0]['state'], 'waking')
        self.machine.up = True
        self.assertEqual(self.ask('host_status=1')['instances'][0]['state'], 'waking')
        self.door.step()
        self.assertEqual(self.ask('host_status=1')['instances'][0]['state'], 'awake')

    def test_a_reused_pid_after_a_reboot_is_not_thawed(self):
        self.running()
        self.saved_at(50)
        self.host.freeze()
        self.machine.boot = 10_000  # rebooted after the freeze; the old pid now names another process
        self.machine.up = False
        self.machine.alive = lambda pid: True
        self.assertIsNone(self.host.frozen())
        self.assertIsNotNone(self.host.cold())

    def test_a_cold_start_clears_an_action_lock_left_by_the_power_down(self):
        self.running()
        self.saved_at(50)
        self.host.freeze()
        self.host.lock.write_text('x')
        os.utime(self.host.lock, (100, 100))
        self.machine.up = False
        self.machine.boot = 5_000
        self.host.frozen()
        self.assertTrue(self.ask('wake=1&port=1714')['ok'])
        self.assertEqual(self.machine.detached[-1][-2], 'start')

    def test_a_cold_server_without_a_valid_save_stays_down(self):
        self.running()
        self.saved_at(50)
        self.host.freeze()
        self.machine.up = False
        self.host.frozen()
        (self.repo / 'map_saves' / 'save_complete.txt').unlink()
        reply = self.ask('wake=1&port=1714')
        self.assertEqual((reply['ok'], reply['state']), (True, 'asleep'))
        self.assertEqual(self.machine.detached, [])

    def test_a_cold_start_waits_for_the_byond_pager(self):
        self.running()
        self.saved_at(50)
        self.host.freeze()
        self.machine.up = False
        self.host.frozen()
        self.machine.pager = False
        self.assertEqual(self.ask('wake=1&port=1714'), {'schema': 1, 'ok': False, 'error': 'byond signed out', 'port': 1714})
        self.assertEqual(self.machine.detached, [])
        with self.assertRaisesRegex(gaia_host.Refused, 'BYOND is not signed in'):
            self.host.request('start')
        self.assertIsNotNone(self.host.cold())
        self.machine.pager = True
        self.assertFalse(self.ask('wake=1&port=1714')['ok'], 'a pager that has just started may still be signing in')
        self.clock[0] += 45
        self.machine.clock += 45
        self.assertTrue(self.ask('wake=1&port=1714', address='198.51.100.7')['ok'])
        self.assertEqual(self.machine.detached[-1][-2], 'start')

    def test_supervisors_run_every_half_minute_and_never_stop_the_doorman(self):
        calls = []
        def broken():
            calls.append('broken')
            raise OSError('cannot start the agent')
        door = doorman.Doorman([self.host], self.machine, clock=lambda: self.clock[0], wall=lambda: self.clock[0],
                               supervisors=[broken, lambda: calls.append('ok') or {}])
        with mock.patch('builtins.print'):
            door.step()
            self.clock[0] += 10
            door.step()
            self.assertEqual(['broken', 'ok'], calls)
            self.clock[0] += doorman.SUPERVISE_SECONDS
            door.step()
        self.assertEqual(['broken', 'ok', 'broken', 'ok'], calls)

    def test_meminfo(self):
        self.assertEqual(gaia_host.parse_meminfo('MemTotal: 16000000 kB\nMemAvailable:    2097152 kB\n'), 2048)
        self.assertIsNone(gaia_host.parse_meminfo('MemTotal: 16000000 kB\n'))

    def test_wake_requests_are_spaced_per_address(self):
        self.running()
        self.host.freeze()
        self.ask('wake=1&port=1714')
        self.door.step()
        self.host.freeze()
        self.clock[0] += 5
        self.ask('wake=1&port=1714')
        self.assertEqual(self.machine.suspended, 1)  # the same address cannot keep it awake every few seconds
        self.ask('wake=1&port=1714', address='198.51.100.7')
        self.assertEqual(self.machine.suspended, 0)

    def test_stopped_and_unknown(self):
        self.give_token()
        self.assertEqual(self.ask('host_status=1')['instances'][0]['state'], 'stopped')
        self.assertEqual(self.ask('wake=1&port=1715'), {'schema': 1, 'ok': False, 'error': 'unknown port'})
        for bad in ('status=1', 'wake=1', 'host_status=1&extra=2', 'host_status', '%%%'):
            self.assertIsNone(self.ask(bad), bad)

    def test_requests_are_rate_limited_per_address(self):
        self.give_token()
        for _ in range(doorman.REQUESTS_PER_MINUTE):
            self.assertIsNotNone(self.ask('host_status=1'))
        self.assertIsNone(self.ask('host_status=1'))
        self.assertIsNotNone(self.ask('host_status=1', address='198.51.100.7'))
        self.clock[0] += 61
        self.assertIsNotNone(self.ask('host_status=1'))

    def test_loopback_callers_are_not_rate_limited(self):
        self.give_token()
        for address in ('127.0.0.1', '::1', '::ffff:127.0.0.1'):
            for _ in range(doorman.REQUESTS_PER_MINUTE + 5):
                self.assertIsNotNone(self.ask('host_status=1', address=address), address)
        self.assertFalse(doorman.is_loopback('not an address'))
        self.assertFalse(doorman.is_loopback('::ffff:203.0.113.9'))

    def test_a_direct_connection_wake_also_reads_waking(self):
        self.running()
        self.host.freeze()
        self.instance.next_watch = 0
        self.machine.peers = ['203.0.113.9']
        status_topic = self.machine.status_topic
        self.machine.status_topic = lambda port: (_ for _ in ()).throw(OSError('still paging in'))
        self.door.step()
        self.assertEqual(self.ask('host_status=1')['instances'][0]['state'], 'waking')
        self.machine.status_topic = status_topic
        self.instance.next_refresh = 0
        self.door.step()
        self.assertEqual(self.ask('host_status=1')['instances'][0]['state'], 'awake')

    def test_framing_round_trip_over_a_socket(self):
        self.running()
        self.config['doorman_port'] = 0
        self.config['doorman_bind'] = '127.0.0.1'
        self.door = doorman.Doorman([self.host], self.machine)
        server = self.door.listen()
        port = server.getsockname()[1]
        threading.Thread(target=self.door.accept_forever, args=(server,), daemon=True).start()
        with socket.create_connection(('127.0.0.1', port), timeout=5) as connection:
            connection.sendall(request('?host_status=1'))
            header = doorman._read(connection, 4)
            body = doorman._read(connection, struct.unpack('>H', header[2:])[0])
        self.assertEqual((header[:2], body[:1], body[-1:]), (b'\x00\x83', b'\x06', b'\x00'))
        self.assertEqual(json.loads(body[1:-1])['instances'][0]['port'], 1714)
        with socket.create_connection(('127.0.0.1', port), timeout=5) as connection:
            connection.sendall(b'\x00\x83\xff\xff')  # oversized request is dropped unanswered
            self.assertEqual(connection.recv(10), b'')
        server.close()

    def test_http_get_answers_the_same_queries(self):
        # DM worlds cannot reach this port with world.Export (it opens a BYOND
        # world handshake, not a Topic frame), so regions ask over HTTP.
        self.running()
        self.config['doorman_port'] = 0
        self.config['doorman_bind'] = '127.0.0.1'
        self.door = doorman.Doorman([self.host], self.machine)
        server = self.door.listen()
        port = server.getsockname()[1]
        threading.Thread(target=self.door.accept_forever, args=(server,), daemon=True).start()
        def get(path):
            with socket.create_connection(('127.0.0.1', port), timeout=5) as connection:
                connection.sendall(('GET %s HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n' % path).encode())
                data = b''
                while True:
                    part = connection.recv(4096)
                    if not part:
                        return data
                    data += part
        reply = get('/?host_status=1')
        self.assertTrue(reply.startswith(b'HTTP/1.1 200 OK\r\n'))
        self.assertEqual(json.loads(reply.split(b'\r\n\r\n', 1)[1])['instances'][0]['port'], 1714)
        self.assertTrue(get('/?nonsense=1').startswith(b'HTTP/1.1 404'))
        self.assertTrue(get('/status').startswith(b'HTTP/1.1 404'))
        server.close()

    def test_parse_request(self):
        self.assertEqual(doorman.parse_request(request('?wake=1&port=1714')), 'wake=1&port=1714')
        self.assertIsNone(doorman.parse_request(request('x')[:-1]))
        self.assertIsNone(doorman.parse_request(b'\x00\x84' + request('x')[2:]))

    def test_world_export_handshake_is_neither_topic_nor_http(self):
        # What DreamDaemon 516 sends first for world.Export("byond://...") (measured).
        first = bytes.fromhex('0015001804020000db010000')
        self.assertIsNone(doorman.parse_request(first))
        self.assertFalse(doorman.is_http(first))


class TopicClientTests(unittest.TestCase):
    def test_framing_boundaries(self):
        from byond_topic import frame_query
        self.assertEqual(request('?status=1'), frame_query(b'?status=1'))
        self.assertEqual(b'\x00\x83\xff\xff', frame_query(b'x' * 65529)[:4])
        with self.assertRaises(struct.error):
            frame_query(b'x' * 65530)

    def test_fragmented_reply_preserves_request_and_timeout(self):
        connection = mock.MagicMock()
        connection.recv.side_effect = [b'\x00', b'\x83\x00', b'\x04', b'\x06', b'o', b'k\x00']
        with mock.patch.object(doorman.socket, 'create_connection') as connect:
            connect.return_value.__enter__.return_value = connection
            self.assertEqual('ok', doorman.topic(1714, '?status=1', timeout=2))
        connect.assert_called_once_with(('127.0.0.1', 1714), timeout=2)
        connection.sendall.assert_called_once_with(request('?status=1'))

    def test_malformed_and_truncated_replies_keep_errors(self):
        for parts, message in (([b'\x00\x84\x00\x00'], 'invalid Topic reply'),
                               ([b'\x00\x83\x00\x01', b'\x05'], 'Topic reply is not text'),
                               ([b'\x00\x83', b''], 'connection closed early')):
            with self.subTest(message=message):
                connection = mock.MagicMock()
                connection.recv.side_effect = parts
                with mock.patch.object(doorman.socket, 'create_connection') as connect:
                    connect.return_value.__enter__.return_value = connection
                    with self.assertRaisesRegex(RuntimeError, message):
                        doorman.topic(1714, 'status=1')


# The inherited GaiaHostTests cases already run in test_gaia_host.
for name in [name for name in dir(base.GaiaHostTests) if name.startswith('test_')]:
    if name not in DoormanTests.__dict__:
        setattr(DoormanTests, name, None)

if __name__ == '__main__':
    unittest.main()
