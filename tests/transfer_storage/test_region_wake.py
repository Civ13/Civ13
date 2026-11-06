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

    def test_peers_on_this_host_are_polled_over_loopback(self):
        # world/Topic bans a non-loopback caller that asks more than once every
        # two minutes; the once-a-minute poll through the public host got the
        # rail yard banned from Gaia for the round (2026-11-05).
        body = proc(GROUP, '/datum/shard_group/proc/poll_peer')
        self.assertIn('byond://[peer_address(peer)]?shard_region=1', body)
        self.assertNotIn('byond://[peer["address"]]', body)
        helper = proc(GROUP, '/datum/shard_group/proc/peer_address')
        self.assertIn('"127.0.0.1:[shard_address_port(target)]"', helper)
        self.assertIn('copytext(address, 1, findlasttext(address, ":"))', helper)
        world = read('code/world.dm')
        self.assertIn('lasttimeaddr[addr] = world.time + 1200', world)

    def test_regions_follow_the_mainland_epoch_forward_only(self):
        # A fresh region started at the 1943 persistence floor while Gaia was
        # in 2013 (2026-11-05); every region keeps the mainland's epoch.
        self.assertIn('.["ordinal_age"] = map.ordinal_age', proc(GROUP, '/datum/shard_group/proc/describe'))
        record = proc(GROUP, '/datum/shard_group/proc/record')
        self.assertIn('if(id == mainland)\n\t\tfollow_mainland_epoch(reply["ordinal_age"])', record)
        follow = proc(GROUP, '/datum/shard_group/proc/follow_mainland_epoch')
        self.assertIn('region == mainland', follow)
        self.assertIn('ordinal <= map.ordinal_age', follow)
        self.assertIn('map.set_epoch(ordinal)', follow)
        configure = proc(GROUP, '/datum/shard_group/proc/configure')
        self.assertIn('mainland = first["id"]', configure)
        self.assertIn('settings["mainland"] in found', configure)
        epochs = read('code/modules/persistence/functions.dm')
        self.assertIn('var/global/list/epoch_names = list("5000 B.C.", "313 B.C.", "1013", "1713", "1873", "1903", "1943", "1969", "2013", "2026")', epochs)
        self.assertIn('map.set_epoch(epoch_names.Find(customage) - 1)', read('code/modules/admin/admin.dm'))

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

    def test_departure_rechecks_the_trail_after_the_poll(self):
        body = proc(TRAVEL, GATE + '/proc/depart')
        expected = body.index('var/expected = destination')
        poll = body.index('shard_group.poll_peer(destination)')
        recheck = body.index('destination != expected || closed_reason()', poll)
        self.assertLess(expected, poll)
        self.assertLess(recheck, body.index('region_travel_payload('))
        self.assertLess(recheck, body.index('begin_escrow'))

    def test_waking_is_bounded(self):
        body = proc(GROUP, '/datum/shard_group/proc/wake_peer')
        self.assertIn('Clamp(reply["eta"], 0, 900)', body)
        self.assertIn('while(world.time < deadline)', body)


if __name__ == '__main__':
    unittest.main()
