"""Home worlds: one region per account, decided by the coordinator over HTTP."""
import os
import sys
import tempfile
import threading
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, ROOT)
from tools.transfer_storage.agent import make_server  # noqa: E402
from tools.transfer_storage.coordinator import Coordinator, call  # noqa: E402
from tools.transfer_storage.region import RegionStore, TransferError  # noqa: E402

TOKENS = {'alpha': 'a' * 40, 'beta': 'b' * 40, 'gamma': 'c' * 40}


class HomeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.stores, self.servers, self.urls = {}, {}, {}
        for name in ('alpha', 'beta', 'gamma'):
            self.start(name)
        self.coordinator = self.new_coordinator()

    def start(self, name):
        store = RegionStore(os.path.join(self.tmp.name, name + '.sqlite'), name, 'g')
        server = make_server(store, TOKENS[name])
        threading.Thread(target=server.serve_forever, kwargs={'poll_interval': 0.01}, daemon=True).start()
        self.stores[name], self.servers[name] = store, server
        self.urls[name] = 'http://127.0.0.1:%d' % server.server_address[1]

    def stop(self, name):
        self.servers[name].shutdown()
        self.servers[name].server_close()
        self.stores[name].close()

    def new_coordinator(self, file='coordinator.sqlite'):
        c = Coordinator(os.path.join(self.tmp.name, file), 'g', bootstrap_new_group=True)
        for name in self.stores:
            c.enroll(name, self.urls[name], TOKENS[name])
        return c

    def tearDown(self):
        for name in list(self.servers):
            self.stop(name)
        self.coordinator.close()
        self.tmp.cleanup()

    def ask(self, region, ckey, op='claim', dest=None, body_here=False):
        body = {'ckey': ckey, 'op': op}
        if dest:
            body['region'] = dest
        if body_here:
            body['body'] = True
        answer = call(self.urls[region], TOKENS[region], '/account', body)
        self.assertTrue(answer.get('ok'), answer)
        return answer['result']['verdict'] if op == 'claim' else answer['result']

    def test_first_claim_wins_and_other_regions_see_it(self):
        self.assertEqual('PENDING', self.ask('alpha', 'val'))
        self.assertEqual('PENDING', self.ask('beta', 'val'))
        self.assertEqual('PENDING', self.ask('alpha', 'val'), 'a repeated claim does not queue twice')
        self.assertEqual(2, self.coordinator.homes_once())
        self.assertEqual({'val': 'alpha'}, self.coordinator.homes())
        self.assertEqual('HOME', self.ask('alpha', 'val'))
        self.assertEqual('ELSEWHERE', self.ask('beta', 'val'))
        self.assertEqual('ELSEWHERE', self.ask('gamma', 'val'))
        self.assertEqual(0, self.coordinator.homes_once(), 'answered claims need no new request')

    def test_a_trip_moves_the_home_and_blocks_the_source_meanwhile(self):
        self.ask('alpha', 'val')
        self.coordinator.homes_once()
        self.ask('alpha', 'val', 'depart', 'beta')
        # Between the gate and the next pass the source cannot start a new character.
        self.assertEqual('PENDING', self.ask('alpha', 'val'))
        self.coordinator.homes_once()
        self.assertEqual('ELSEWHERE', self.ask('alpha', 'val'))
        self.ask('beta', 'val', 'arrive')
        self.assertEqual('PENDING', self.ask('beta', 'val'), 'the arrival is not decided yet')
        self.coordinator.homes_once()
        self.assertEqual('HOME', self.ask('beta', 'val'))
        self.assertEqual({'val': 'beta'}, self.coordinator.homes())

    def test_no_new_character_while_one_is_travelling_here(self):
        import json
        self.ask('alpha', 'val')
        self.coordinator.homes_once()
        body = json.dumps({'v': 1, 'kind': 'character', 'owner': 'val', 'name': 'Pepijn'})
        # beta cannot take the trip yet (held or down): it waits in alpha's escrow.
        self.stores['alpha'].enroll('beta', 'out')
        self.stores['alpha'].begin_escrow('beta', [body], fast=True)
        self.assertEqual([{'ckey': 'val', 'region': 'beta'}], self.stores['alpha'].account_requests()['travelling'])
        self.ask('alpha', 'val', 'depart', 'beta')
        self.coordinator.homes_once()
        # Home moved at departure, but beta's lobby must not offer a new character.
        self.assertEqual({'val': 'beta'}, self.coordinator.homes())
        answer = call(self.urls['beta'], TOKENS['beta'], '/account', {'ckey': 'val', 'op': 'claim'})['result']
        self.assertEqual(('TRAVELLING', 'alpha'), (answer['verdict'], answer['from']))
        self.assertEqual('HOME', self.ask('beta', 'val', body_here=True), 'a living character already there is still played')
        # alpha goes quiet; beta still knows on the next pass.
        self.stop('alpha')
        del self.servers['alpha']
        self.coordinator.homes_once()
        self.assertEqual('TRAVELLING', self.ask('beta', 'val'))
        # The character is built in beta: the arrival ends the wait even though alpha never reported again.
        self.ask('beta', 'val', 'arrive')
        self.coordinator.homes_once()
        self.assertEqual('HOME', self.ask('beta', 'val'))

    def test_a_refused_trip_comes_home(self):
        self.ask('alpha', 'val')
        self.coordinator.homes_once()
        self.ask('alpha', 'val', 'depart', 'beta')
        self.coordinator.homes_once()
        # beta refused; the character is rebuilt at the source.
        self.ask('alpha', 'val', 'arrive')
        self.coordinator.homes_once()
        self.assertEqual('HOME', self.ask('alpha', 'val'))
        self.assertEqual('ELSEWHERE', self.ask('beta', 'val'))

    def test_a_refused_trip_decided_in_one_pass_stays_home(self):
        self.ask('alpha', 'val')
        self.coordinator.homes_once()
        # The depart and the refused trip's return land in the same pass.
        self.ask('alpha', 'val', 'depart', 'beta')
        self.ask('alpha', 'val', 'arrive')
        self.coordinator.homes_once()
        self.assertEqual({'val': 'alpha'}, self.coordinator.homes())
        self.assertEqual('HOME', self.ask('alpha', 'val'))
        self.assertEqual('ELSEWHERE', self.ask('beta', 'val'))

    def test_a_lost_ledger_keeps_a_living_character_where_it_is(self):
        self.coordinator.close()
        self.coordinator = Coordinator(os.path.join(self.tmp.name, 'm1.sqlite'), 'g', 'alpha', bootstrap_new_group=True)
        for name in self.stores:
            self.coordinator.enroll(name, self.urls[name], TOKENS[name])
        self.ask('alpha', 'val', 'depart', 'beta')
        self.ask('beta', 'val', 'arrive')
        self.coordinator.homes_once()
        self.assertEqual({'val': 'beta'}, self.coordinator.homes())
        # A replacement must not clear surviving agent homes.
        self.coordinator.close()
        self.coordinator = self.new_coordinator('replacement.sqlite')
        self.assertEqual(0, self.coordinator.homes_once())
        self.assertEqual({}, self.coordinator.homes())
        self.assertEqual('HOME', self.ask('beta', 'val'))
        self.assertEqual('ELSEWHERE', self.ask('alpha', 'val'))

    def test_a_body_claim_does_not_override_a_home(self):
        self.ask('alpha', 'val')
        self.coordinator.homes_once()
        self.assertEqual('ELSEWHERE', self.ask('beta', 'val', body_here=True))
        self.coordinator.homes_once()
        self.assertEqual({'val': 'alpha'}, self.coordinator.homes())

    def test_departure_from_a_region_that_is_not_home_changes_nothing(self):
        self.ask('alpha', 'val')
        self.coordinator.homes_once()
        self.ask('beta', 'val', 'depart', 'gamma')
        self.coordinator.homes_once()
        self.assertEqual({'val': 'alpha'}, self.coordinator.homes())

    def test_death_frees_the_home_only_where_it_is(self):
        self.ask('alpha', 'val')
        self.coordinator.homes_once()
        self.ask('beta', 'val', 'release')
        self.coordinator.homes_once()
        self.assertEqual({'val': 'alpha'}, self.coordinator.homes(), 'a release from elsewhere is ignored')
        self.ask('alpha', 'val', 'release')
        self.coordinator.homes_once()
        self.assertEqual({}, self.coordinator.homes())
        self.assertEqual('PENDING', self.ask('gamma', 'val'), 'a freed account may start anywhere')
        self.coordinator.homes_once()
        self.assertEqual('HOME', self.ask('gamma', 'val'))
        self.assertEqual('ELSEWHERE', self.ask('alpha', 'val'))

    def test_arrival_is_decided_before_a_competing_claim(self):
        self.ask('beta', 'val', 'arrive')
        self.ask('alpha', 'val')
        self.coordinator.homes_once()
        self.assertEqual({'val': 'beta'}, self.coordinator.homes())

    def test_an_unreachable_agent_waits_and_catches_up(self):
        self.ask('alpha', 'val')
        self.stop('gamma')
        self.coordinator.homes_once()
        self.start('gamma')
        self.coordinator.enroll('gamma', self.urls['gamma'], TOKENS['gamma'])
        self.ask('beta', 'kim')
        self.coordinator.homes_once()
        self.assertEqual('ELSEWHERE', self.ask('gamma', 'val'), 'missed rows arrive on the next pass')
        self.assertEqual('ELSEWHERE', self.ask('gamma', 'kim'))

    def test_a_lost_coordinator_file_starts_a_new_ledger(self):
        self.ask('alpha', 'val')
        self.coordinator.homes_once()
        self.coordinator.close()
        self.coordinator = self.new_coordinator('fresh.sqlite')
        self.coordinator.homes_once()
        self.assertEqual('quarantined', self.coordinator.recovery_status()['state'])
        self.assertEqual('ELSEWHERE', self.ask('beta', 'val'))
        self.assertEqual(0, self.coordinator.homes_once())
        self.assertEqual('HOME', self.ask('alpha', 'val'))

    def test_a_lost_acknowledgement_never_replays_an_old_request(self):
        self.ask('alpha', 'val')
        self.coordinator.homes_once()
        self.ask('beta', 'val', 'arrive')
        # beta's agent misses the answer, so its arrive stays queued there.
        original = self.stores['beta'].apply_homes
        self.stores['beta'].apply_homes = lambda *a, **k: (_ for _ in ()).throw(TransferError('lost'))
        self.assertEqual(1, self.coordinator.homes_once())
        self.assertEqual({'val': 'beta'}, self.coordinator.homes())
        # An admin moves the account by hand; the stale arrive must not undo it.
        self.coordinator.db.execute('BEGIN IMMEDIATE')
        self.coordinator._set_home('val', 'gamma')
        self.coordinator.db.execute('COMMIT')
        self.stores['beta'].apply_homes = original
        self.assertEqual(0, self.coordinator.homes_once(), 'the queued arrive was already decided')
        self.assertEqual({'val': 'gamma'}, self.coordinator.homes())
        self.assertEqual('ELSEWHERE', self.ask('beta', 'val'))
        self.assertEqual([], self.stores['beta'].account_requests()['requests'], 'the late answer acknowledged it')

    def test_mainland_is_where_everyone_starts_and_returns_after_death(self):
        self.coordinator.close()
        self.coordinator = Coordinator(os.path.join(self.tmp.name, 'main.sqlite'), 'g', 'alpha', bootstrap_new_group=True)
        for name in self.stores:
            self.coordinator.enroll(name, self.urls[name], TOKENS[name])
        self.coordinator.homes_once()  # agents learn the mainland
        self.assertEqual('ELSEWHERE', self.ask('beta', 'val'), 'a new player cannot start off the mainland')
        self.assertEqual('alpha', self.stores['beta'].account('val', 'claim')['home'])
        self.assertEqual('PENDING', self.ask('alpha', 'val'))
        self.coordinator.homes_once()
        self.assertEqual('HOME', self.ask('alpha', 'val'))
        # Travel out, then die abroad: back to the mainland, not free.
        self.ask('alpha', 'val', 'depart', 'beta')
        self.ask('beta', 'val', 'arrive')
        self.coordinator.homes_once()
        self.assertEqual('HOME', self.ask('beta', 'val'))
        self.ask('beta', 'val', 'release')
        self.coordinator.homes_once()
        self.assertEqual({'val': 'alpha'}, self.coordinator.homes())
        self.assertEqual('ELSEWHERE', self.ask('beta', 'val'))
        self.assertEqual('ELSEWHERE', self.ask('gamma', 'val'))
        self.assertEqual('HOME', self.ask('alpha', 'val'))
        # Dying on the mainland keeps the mainland.
        self.ask('alpha', 'val', 'release')
        self.coordinator.homes_once()
        self.assertEqual({'val': 'alpha'}, self.coordinator.homes())

    def test_a_start_region_apart_from_the_mainland_takes_new_and_fallen_characters(self):
        # The host's start_region (Gaia) while the mainland (North America) keeps the era.
        self.coordinator.close()
        self.coordinator = Coordinator(os.path.join(self.tmp.name, 'start.sqlite'), 'g', 'alpha', bootstrap_new_group=True,
                                       start_region='gamma')
        for name in self.stores:
            self.coordinator.enroll(name, self.urls[name], TOKENS[name])
        self.coordinator.homes_once()  # agents learn the mainland and the start region
        self.assertEqual('gamma', self.stores['alpha'].start_region())
        self.assertEqual('alpha', self.stores['alpha'].lands()['mainland'])
        self.assertEqual('gamma', self.stores['beta'].lands()['start_region'])
        # A new player at the mainland (the gate) is sent to the start region.
        self.assertEqual('ELSEWHERE', self.ask('alpha', 'new'))
        self.assertEqual('gamma', self.stores['alpha'].account('new', 'claim')['home'])
        self.ask('alpha', 'new')
        self.coordinator.homes_once()
        self.assertEqual({}, self.coordinator.homes(), 'the mainland cannot claim a new player')
        self.assertEqual('PENDING', self.ask('gamma', 'new'))
        self.coordinator.homes_once()
        self.assertEqual('HOME', self.ask('gamma', 'new'))
        # An existing mainland home stays put, and so does a death there with a bed
        # (DM sends no release then); a death without one goes to the start region.
        self.coordinator._set_home('old', 'alpha')
        self.coordinator.homes_once()
        self.assertEqual('HOME', self.ask('alpha', 'old'), 'an existing character keeps its home')
        self.ask('alpha', 'old', 'release')
        self.coordinator.homes_once()
        self.assertEqual('gamma', self.coordinator.home('old'))
        self.assertEqual('ELSEWHERE', self.ask('alpha', 'old'))
        # Back on the mainland: a coordinator without a start region uses it.
        self.coordinator.close()
        self.coordinator = Coordinator(os.path.join(self.tmp.name, 'start.sqlite'), 'g', 'alpha')
        for name in self.stores:
            self.coordinator.enroll(name, self.urls[name], TOKENS[name])
        self.coordinator.homes_once()
        self.assertEqual('alpha', self.stores['beta'].start_region())

    def test_a_home_with_nothing_left_in_it_goes_back_to_the_start_region(self):
        # region_home_stranded(): a home in beta whose world lost the character
        # (no living body, no bed) sends a release on Join, and the next
        # character is sent to the start region; an arrival later takes it back.
        self.coordinator.close()
        self.coordinator = Coordinator(os.path.join(self.tmp.name, 'stranded.sqlite'), 'g', 'gamma', bootstrap_new_group=True,
                                       start_region='gamma')
        for name in self.stores:
            self.coordinator.enroll(name, self.urls[name], TOKENS[name])
        self.coordinator._set_home('val', 'beta')
        self.coordinator.homes_once()
        self.assertEqual('HOME', self.ask('beta', 'val'))
        self.ask('beta', 'val', 'release')
        self.assertEqual('PENDING', self.ask('beta', 'val'), 'Join keeps waiting while the release is queued')
        self.coordinator.homes_once()
        self.assertEqual('gamma', self.coordinator.home('val'))
        self.assertEqual('ELSEWHERE', self.ask('beta', 'val'))
        self.assertEqual('gamma', self.stores['beta'].account('val', 'claim')['home'])
        self.assertEqual('HOME', self.ask('gamma', 'val'))
        # A character that was still on its way to beta takes the home back once built.
        self.ask('beta', 'val', 'arrive')
        self.coordinator.homes_once()
        self.assertEqual('beta', self.coordinator.home('val'))

    def test_an_older_coordinator_without_a_start_region_means_the_mainland(self):
        store = self.stores['beta']
        store.apply_homes('e1', 0, [], [], reset=True, mainland='alpha')
        self.assertEqual('alpha', store.start_region())
        self.assertEqual('alpha', store.account('val', 'claim')['home'])

    def test_a_raid_death_sends_the_home_back_where_the_raider_came_from(self):
        # region_raid.dm: a raid world notes a death as a depart to the origin.
        self.coordinator.close()
        self.coordinator = Coordinator(os.path.join(self.tmp.name, 'main.sqlite'), 'g', 'alpha', bootstrap_new_group=True)
        for name in self.stores:
            self.coordinator.enroll(name, self.urls[name], TOKENS[name])
        self.coordinator.homes_once()
        self.ask('alpha', 'val')
        self.coordinator.homes_once()
        self.ask('alpha', 'val', 'depart', 'gamma')
        self.ask('gamma', 'val', 'arrive')
        self.coordinator.homes_once()
        self.assertEqual({'val': 'gamma'}, self.coordinator.homes())
        # gamma -> raid world beta, then death there.
        self.ask('gamma', 'val', 'depart', 'beta')
        self.ask('beta', 'val', 'arrive')
        self.coordinator.homes_once()
        self.assertEqual('HOME', self.ask('beta', 'val'))
        self.ask('beta', 'val', 'depart', 'gamma')
        self.coordinator.homes_once()
        self.assertEqual({'val': 'gamma'}, self.coordinator.homes(), 'home, not the mainland')
        self.assertEqual('HOME', self.ask('gamma', 'val'))
        self.assertEqual('ELSEWHERE', self.ask('beta', 'val'))

    def test_bad_requests_are_refused(self):
        store = self.stores['alpha']
        for ckey, op, region in (('Val', 'claim', None), ('', 'claim', None), ('x' * 33, 'claim', None),
                                 ('val', 'steal', None), ('val', 'depart', None), ('val', 'depart', 'alpha')):
            with self.assertRaises(TransferError):
                store.account(ckey, op, region)
        with self.assertRaises(TransferError):
            store.apply_homes('', 1, [], [])


if __name__ == '__main__':
    unittest.main()
