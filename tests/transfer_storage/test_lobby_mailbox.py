"""Real coordinator and SQLite custody stores over an in-process test transport."""
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.transfer_storage.agent import _routes
from tools.transfer_storage.coordinator import Coordinator
from tools.transfer_storage.lobby import LobbyMailbox, MAX_PENDING, REQUEST_LIFETIME, RESULT_LIFETIME
from tools.transfer_storage.region import RegionStore, TransferError


class LobbyMailboxTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.coordinator = Coordinator(':memory:', 'earth', mainland='gaia', start_region='beta',
                                       bootstrap_new_group=True, records_dir=directory.name,
                                       activity_db=str(Path(directory.name) / 'activity.sqlite'))
        self.addCleanup(self.coordinator.close)
        self.stores = {}
        self.routes = {}
        self.urls = {}
        self.now = 0
        for region in ('gaia', 'beta', 'gateway'):
            store = RegionStore(':memory:', region, 'earth')
            self.addCleanup(store.close)
            self.stores[region] = store
            mailbox = None
            if region == 'gateway':
                self.mailbox = mailbox = LobbyMailbox(store, lambda: self.now)
            self.routes[region] = _routes(store, None, mailbox)
            url = f'http://127.0.0.1:{19000 + len(self.urls)}'
            self.urls[url] = region
            self.coordinator.enroll(region, url, 'test-token-' + region)
        self.offline = set()

        def call(url, token, path, body=None, **opts):
            url = self.urls[url]
            self.assertEqual(token, 'test-token-' + url)
            if url in self.offline:
                raise TimeoutError()
            return {'ok': True, 'result': self.routes[url][path](body or {})}

        mock = patch('tools.transfer_storage.coordinator.call', side_effect=call)
        mock.start()
        self.addCleanup(mock.stop)
        self.coordinator.homes_once()

    def ask(self, key):
        return self.routes['gateway']['/lobby/home']({'ckey': key})

    def test_exact_owner_slots_route_independently_without_claim(self):
        self.coordinator._set_home('alice', 'gaia')
        self.coordinator._set_home('@2alice', 'beta')
        self.coordinator.homes_once()
        all_dbs = [self.coordinator.db] + [s.db for s in self.stores.values()]
        before = [list(db.iterdump()) for db in all_dbs]
        for key, state, region in [('alice', 'HOME', 'gaia'), ('@2alice', 'HOME', 'beta'), ('@3alice', 'NO_HOME', 'beta')]:
            self.assertEqual({'state': 'PENDING'}, self.ask(key))
            self.assertTrue(self.coordinator.lobby_once('gateway'))
            answer = self.ask(key)
            self.assertEqual((state, region), (answer['state'], answer['region']))
            self.assertEqual({'state': 'PENDING'}, self.ask(key))  # result was consumed
            self.mailbox.entries.clear()  # simulate a new client with no pending lookup
        self.assertEqual(before, [list(db.iterdump()) for db in all_dbs])

    def test_offline_roster_and_expired_results_do_not_route(self):
        self.offline.add('beta')
        self.assertEqual({'state': 'PENDING'}, self.ask('alice'))
        self.assertTrue(self.coordinator.lobby_once('gateway'))
        self.assertEqual({'state': 'UNAVAILABLE'}, self.ask('alice'))
        self.offline.clear()
        self.assertEqual({'state': 'PENDING'}, self.ask('alice'))
        self.assertTrue(self.coordinator.lobby_once('gateway'))
        self.now += RESULT_LIFETIME
        self.assertEqual({'state': 'PENDING'}, self.ask('alice'))

    def test_changed_epoch_snapshot_and_local_barrier_do_not_route(self):
        self.ask('alice')
        self.assertTrue(self.coordinator.lobby_once('gateway'))
        self.coordinator._set_home('alice', 'gaia')
        self.coordinator.homes_once()
        self.assertEqual({'state': 'UNAVAILABLE'}, self.ask('alice'))
        self.ask('alice')
        self.assertTrue(self.coordinator.lobby_once('gateway'))
        self.stores['gateway'].account('alice', 'depart', 'beta')
        self.assertEqual({'state': 'PENDING'}, self.ask('alice'))

    def test_parked_home_returns_summon_target_without_playable_region(self):
        self.coordinator._set_home('@2alice', 'land:2,3')
        self.coordinator.homes_once()
        self.ask('@2alice')
        self.assertTrue(self.coordinator.lobby_once('gateway'))
        self.assertEqual({'state': 'UNAVAILABLE'}, self.ask('@2alice'))
        chart = self.coordinator.chart
        chart.db.execute("INSERT INTO chart_tile VALUES (2, 3, '{}', 0, 'SETTLED', NULL, 'admin', 1)")
        chart.db.execute("INSERT INTO chart_parked VALUES (2, 3, 1, 1, NULL)")
        self.ask('@2alice')
        self.assertTrue(self.coordinator.lobby_once('gateway'))
        result = self.ask('@2alice')
        self.assertEqual(('PARKED', 'land:2,3'), (result['state'], result['home']))
        self.assertNotIn('region', result)
        self.assertEqual('land:2,3', self.coordinator.home('@2alice'))

    def test_bounded_gateway_only_and_reject_stale_response(self):
        self.assertNotIn('/lobby/home', self.routes['gaia'])
        with self.assertRaises(TransferError):
            self.ask('@5alice')
        for i in range(MAX_PENDING):
            self.assertEqual({'state': 'PENDING'}, self.ask(f'alice{i}'))
        self.assertEqual({'state': 'UNAVAILABLE'}, self.ask('overflow'))
        old = self.mailbox.pending()['requests'][0]
        self.now += REQUEST_LIFETIME
        self.ask(old['owner'])
        self.assertNotEqual(old, self.mailbox.pending()['requests'][0])
        self.assertEqual({'accepted': False},
                         self.mailbox.publish(old['owner'], old['id'], {'state': 'UNAVAILABLE'}))


if __name__ == '__main__':
    unittest.main()
