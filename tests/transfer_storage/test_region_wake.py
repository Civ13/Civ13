"""Source contracts for sleeping regions. Never launches BYOND.

A frozen region wakes on any connection to its port, so peers ask the host's
doorman which regions sleep instead of polling them, and a trail wakes its
destination through the doorman before sending a traveller.
"""
import os
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def read(path):
    with open(os.path.join(ROOT, path), encoding='utf-8-sig') as f:
        return f.read().replace('\r\n', '\n')


def proc(source, name):
    start = source.index('\n' + name + '(') + 1
    end = re.search(r'\n(?=[^\s#])', source[start + 1:])
    return source[start:start + 1 + end.start()] if end else source[start:]


GROUP = read('code/modules/persistence/shard_group.dm')
TRAVEL = read('code/modules/persistence/region_travel.dm')
GATE = '/obj/structure/region_gate'


class RegionWakeTests(unittest.TestCase):
    def test_sleeping_peers_are_never_polled_directly(self):
        body = proc(GROUP, '/datum/shard_group/proc/poll_once')
        self.assertLess(body.index('doorman_states()'), body.index('poll_peer(id)'))
        self.assertIn('entry["state"] != "awake"', body)
        self.assertIn('record_sleeping(id, entry, world.time)\n\t\t\tcontinue', body)

    def test_doorman_states_name_cold_worlds(self):
        body = proc(GROUP, '/datum/shard_group/proc/record_sleeping')
        self.assertIn('entry["cold"] ? "COLD" : "ASLEEP"', body)
        self.assertIn('"WAKING"', body)

    def test_the_doorman_address_is_validated(self):
        body = proc(GROUP, '/datum/shard_group/proc/configure')
        self.assertIn('shard_address_valid(settings["doorman"])', body)

    def test_a_trail_to_a_sleeping_region_stays_open(self):
        body = proc(TRAVEL, GATE + '/proc/closed_reason')
        self.assertIn('!shard_group.peer_wakeable(destination)', body)

    def test_travel_wakes_the_destination_then_checks_again(self):
        body = proc(TRAVEL, GATE + '/proc/travel')
        wake = body.index('shard_group.wake_peer(destination, H)')
        self.assertLess(wake, body.index('reason = travel_refusal(H)', wake))
        self.assertLess(wake, body.index('H.record_persistence_owner()'))

    def test_departure_needs_an_awake_destination(self):
        body = proc(TRAVEL, GATE + '/proc/depart')
        self.assertLess(body.index('shard_group.poll_peer(destination)'), body.index('begin_escrow'))

    def test_waking_is_bounded(self):
        body = proc(GROUP, '/datum/shard_group/proc/wake_peer')
        self.assertIn('Clamp(reply["eta"], 0, 900)', body)
        self.assertIn('while(world.time < deadline)', body)


if __name__ == '__main__':
    unittest.main()
