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

    def status_topic(self, port):
        if self.suspended:
            raise OSError('frozen')
        self.status_calls += 1
        return json.dumps({'players': self.clients, 'map_name': 'Gaia', 'map_gamemode': 'Nomads'})


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

    def test_parse_request(self):
        self.assertEqual(doorman.parse_request(request('?wake=1&port=1714')), 'wake=1&port=1714')
        self.assertIsNone(doorman.parse_request(request('x')[:-1]))
        self.assertIsNone(doorman.parse_request(b'\x00\x84' + request('x')[2:]))


# The inherited GaiaHostTests cases already run in test_gaia_host.
for name in [name for name in dir(base.GaiaHostTests) if name.startswith('test_')]:
    if name not in DoormanTests.__dict__:
        setattr(DoormanTests, name, None)

if __name__ == '__main__':
    unittest.main()
