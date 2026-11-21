"""Private lobby decisions use current custody evidence and never claim a home."""
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.transfer_storage.agent import _routes
from tools.transfer_storage.coordinator import Coordinator
from tools.transfer_storage.region import RegionHeld, RegionStore, TransferError


class LobbyHomeTests(unittest.TestCase):
    def setUp(self):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.coordinator = Coordinator(':memory:', 'earth', mainland='gaia', start_region='beta',
                                       bootstrap_new_group=True, records_dir=folder.name,
                                       activity_db=str(Path(folder.name) / 'activity.sqlite'))
        self.addCleanup(self.coordinator.close)
        self.stores = {}
        self.urls = {}
        for region, port in [('gaia', 19010), ('beta', 19011)]:
            self.stores[region] = RegionStore(':memory:', region, 'earth')
            self.addCleanup(self.stores[region].close)
            self.urls[f'http://127.0.0.1:{port}'] = region
            self.coordinator.enroll(region, f'http://127.0.0.1:{port}', 'test-token-' + region)
        self.guards, self.calls = {}, []
        agent_calls = patch('tools.transfer_storage.coordinator.call', side_effect=self.agent_call)
        agent_calls.start()
        self.addCleanup(agent_calls.stop)
        self.coordinator.homes_once()  # real authority bootstrap and copy installation

    def agent_call(self, url, token, path, body=None, timeout=5):
        name = self.urls[url]
        self.assertEqual('test-token-' + name, token)
        self.calls.append((name, path))
        if name in self.guards:
            return self.guards[name](url, path, body)
        return {'ok': True, 'result': _routes(self.stores[name], None)[path](body or {})}

    def assert_no_mutation(self, ckey, expected):
        databases = [self.coordinator.db] + [s.db for s in self.stores.values()]
        before = ['\n'.join(db.iterdump()) for db in databases]
        for db in databases:
            db.execute('PRAGMA query_only=ON')
        self.calls.clear()
        try:
            self.assertEqual(expected, self.coordinator.lobby_home(ckey))
            self.assertEqual(before, ['\n'.join(db.iterdump()) for db in databases])
        finally:
            for db in databases:
                db.execute('PRAGMA query_only=OFF')
        self.assertTrue(all(path == '/lobby/account-status' for _, path in self.calls))

    def test_known_home_and_confirmed_new_account(self):
        self.coordinator._set_home('alice', 'gaia')
        self.coordinator.homes_once()
        self.assert_no_mutation('alice', {'state': 'HOME', 'region': 'gaia'})
        self.assertEqual({'gaia', 'beta'}, {region for region, _ in self.calls})
        self.assert_no_mutation('bob', {'state': 'NO_HOME', 'region': 'beta'})
        self.assertIsNone(self.coordinator.home('bob'))

    def test_queued_home_operation_cannot_look_new(self):
        self.assertEqual('PENDING', self.stores['beta'].account('alice', 'claim')['verdict'])
        self.assert_no_mutation('alice', {'state': 'PENDING'})
        self.assertEqual('claim', self.stores['beta'].account_requests()['requests'][0]['op'])

    def test_uncollected_character_transfer_blocks(self):
        manifest = json.dumps({'items': [json.dumps({'kind': 'character', 'owner': 'alice'})]})
        db = self.stores['beta'].db
        db.execute("INSERT INTO active VALUES ('out', 'gaia', 1, 'trip', ?, 'Returning')", (manifest,))
        self.assert_no_mutation('alice', {'state': 'TRAVELLING'})
        self.assert_no_mutation('bob', {'state': 'NO_HOME', 'region': 'beta'})

    def test_local_and_coordinator_train_locks_block(self):
        self.stores['beta'].db.execute("INSERT INTO train_lease VALUES ('journey', ?, 'pending', '', '', '', '')",
                                       (json.dumps({'accounts': ['alice']}),))
        self.assert_no_mutation('alice', {'state': 'PENDING'})
        self.coordinator.db.execute("INSERT INTO train_account_lock VALUES ('bob', 'id')")
        self.assert_no_mutation('bob', {'state': 'PENDING'})
        self.assertEqual([], self.calls)

    def test_coordinator_travelling_blocks_without_probe(self):
        self.coordinator.db.execute("INSERT INTO travelling VALUES ('beta', 'alice', 'gaia')")
        self.assert_no_mutation('alice', {'state': 'TRAVELLING'})
        self.assertEqual([], self.calls)

    def test_recovery_or_incomplete_roster_cannot_look_new(self):
        for state in ('unreconciled', 'quarantined'):
            with self.subTest(state=state):
                self.coordinator.db.execute("UPDATE ledger SET value=? WHERE key='recovery'", (state,))
                self.assert_no_mutation('alice', {'state': 'UNAVAILABLE'})
                self.assertEqual([], self.calls)
        self.coordinator.db.execute("UPDATE ledger SET value='ready' WHERE key='recovery'")
        self.coordinator.db.execute("DELETE FROM region WHERE region='beta'")
        self.assert_no_mutation('alice', {'state': 'UNAVAILABLE'})
        self.assertEqual([], self.calls)

    def test_offline_refusal_or_malformed_agent_cannot_look_new(self):
        def offline(*_):
            raise OSError('offline')
        for response in (offline, lambda *_: {'ok': False, 'held': True}, lambda *_: [],
                         lambda *_: {'ok': True, 'result': {}},
                         lambda *_: {'ok': True, 'result': self.stores['gaia'].lobby_account_status('alice')}):
            with self.subTest(response=response):
                self.guards['beta'] = response
                self.assert_no_mutation('alice', {'state': 'UNAVAILABLE'})

    def test_stale_epoch_or_revision_cannot_look_new(self):
        agent = self.stores['beta']
        old_epoch = agent._meta('homes_epoch')
        agent._set_meta('homes_epoch', 'stale-epoch')
        self.assert_no_mutation('alice', {'state': 'UNAVAILABLE'})
        agent._set_meta('homes_epoch', old_epoch)
        self.coordinator._set_home('someoneelse', 'gaia')
        self.assert_no_mutation('alice', {'state': 'UNAVAILABLE'})

    def test_agent_refuses_held_or_bad_account(self):
        route = _routes(self.stores['beta'], None)['/lobby/account-status']
        with self.assertRaises(TransferError):
            route({'ckey': 'not a ckey'})
        self.stores['beta']._set_meta('hold_reason', 'test fixture hold')
        with self.assertRaises(RegionHeld):
            route({'ckey': 'alice'})

    def test_missing_configured_destination_never_falls_back(self):
        self.coordinator.start_region = 'not-enrolled'
        self.assert_no_mutation('alice', {'state': 'UNAVAILABLE'})
        self.coordinator._set_home('alice', 'vanished')
        self.coordinator.homes_once()
        self.assert_no_mutation('alice', {'state': 'UNAVAILABLE'})

    def test_snapshot_change_during_probe_fails_closed(self):
        def changed_after_reply(*_):
            result = self.stores['gaia'].lobby_account_status('alice')
            self.coordinator._set_home('alice', 'gaia')
            return {'ok': True, 'result': result}

        self.guards['gaia'] = changed_after_reply
        self.assertEqual({'state': 'UNAVAILABLE'}, self.coordinator.lobby_home('alice'))
        self.assertEqual('gaia', self.coordinator.home('alice'))
        self.assertEqual([], self.stores['gaia'].account_requests()['requests'])

    def test_deadline_refuses_without_probing(self):
        with patch('tools.transfer_storage.coordinator.time.monotonic', side_effect=[0, 2]):
            self.assert_no_mutation('alice', {'state': 'UNAVAILABLE'})
        self.assertEqual([], self.calls)
