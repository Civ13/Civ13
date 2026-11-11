"""Atomic grouped-home reservations; protocol tests, not native train travel."""
import copy
import json
import tempfile
import unittest
from pathlib import Path
from tools.transfer_storage.coordinator import Coordinator
from tools.transfer_storage.region import RegionStore, OUT, IN, TransferError
from test_train import manifest


class TrainCustodyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = str(Path(self.tmp.name) / 'coordinator.db')
        self.c = Coordinator(self.path, 'earth')
        self.c.db.execute("UPDATE ledger SET value = 'ready' WHERE key = 'recovery'")
        self.a = RegionStore(':memory:', 'alpha', 'earth')
        self.b = RegionStore(':memory:', 'beta', 'earth')
        self.a.enroll('beta', OUT); self.b.enroll('alpha', IN)
        for who in ('alice', 'bob'):
            self.c._set_home(who, 'alpha')
        m = manifest()
        entity = copy.deepcopy(m['entities'][0]); entity['id'] = 'bob'
        entity['payload'] = json.dumps({'kind': 'character', 'owner': 'bob', 'party': m['party']})
        m['entities'].append(entity); m['accounts'].append('bob')
        self.payload = json.dumps(m)
        self.c.enroll('alpha', 'http://127.0.0.1:1', 'a' * 40)
        self.c.enroll('beta', 'http://127.0.0.1:2', 'b' * 40)
        original = self.a.begin_escrow
        def leased_begin(peer, payloads, fast=False, train_lease=None):
            from tools.transfer_storage.train_lease import lease_binding
            if train_lease is None:
                request = lease_binding(json.loads(payloads[0]))
                self.a.reserve_train(request)
                decision = self.c.decide_train_lease('alpha', {'op': 'reserve', 'request': request})
                self.a.apply_homes(self.c._ledger('epoch'), int(self.c._ledger('rev')), [], [], train_decisions=[decision])
                train_lease = decision['token']
            return original(peer, payloads, fast, train_lease)
        self.a.begin_escrow = leased_begin


    def tearDown(self):
        self.a.close(); self.b.close(); self.c.close(); self.tmp.cleanup()

    def begin(self):
        tid, _ = self.a.begin_escrow('beta', [self.payload], fast=True)
        self.deliver(self.a, self.b)
        return tid

    def deliver(self, source, dest):
        e = source.outbox()[0]
        train = self.c.train_envelope(source.region, e)
        if train:
            e = dict(e, train_custody_epoch=self.c._ledger('epoch'))
        return dest.receive(e)

    def prepare(self, tid):
        p = self.b.pending_train_admissions()[0]
        self.b.prepare_train(tid, p['manifest_hash'], 'strip1')
        self.deliver(self.b, self.a)

    def test_all_homes_commit_together_and_duplicate_commit_is_idempotent(self):
        tid = self.begin()
        self.assertEqual(['alice', 'bob'], self.c.train_locks())
        self.prepare(tid)
        self.deliver(self.a, self.b)
        self.assertEqual({'alice': 'beta', 'bob': 'beta'}, self.c.homes())
        rev = self.c._ledger('rev')
        self.deliver(self.a, self.b)
        self.assertEqual(rev, self.c._ledger('rev'))
        self.b.begin_import(tid, fast=True)
        self.deliver(self.b, self.a)
        self.assertEqual([], self.c.train_locks())
        self.assertEqual({'alice': 'beta', 'bob': 'beta'}, self.c.homes())

    def test_conflicting_or_unknown_member_prevents_every_reservation(self):
        self.c.db.execute("DELETE FROM home WHERE ckey = 'bob'")
        with self.assertRaises(TransferError):
            self.a.begin_escrow('beta', [self.payload], fast=True)
        self.assertEqual([], self.c.train_locks())
        self.assertEqual(0, self.c.db.execute('SELECT COUNT(*) FROM train_custody').fetchone()[0])

    def test_abort_before_commit_releases_all_members(self):
        tid = self.begin()
        self.a.abort(tid)
        self.deliver(self.a, self.b)
        self.deliver(self.b, self.a)
        self.assertEqual([], self.c.train_locks())
        self.assertEqual({'alice': 'alpha', 'bob': 'alpha'}, self.c.homes())
        self.a.begin_return(tid, fast=True)

    def test_abort_before_escrow_delivery_still_returns(self):
        tid, _ = self.a.begin_escrow('beta', [self.payload], fast=True)
        self.a.abort(tid)
        self.deliver(self.a, self.b)
        self.deliver(self.b, self.a)
        self.a.begin_return(tid, fast=True)
        self.assertEqual([], self.c.train_locks())

    def test_restart_preserves_lease_and_blocks_ordinary_requests(self):
        tid = self.begin()
        self.c.close(); self.c = Coordinator(self.path, 'earth')
        for op in ('claim', 'custody', 'arrive', 'depart', 'release'):
            self.c.decide('gamma', {'ckey': 'alice', 'op': op, 'region': 'gamma'})
        self.assertEqual('alpha', self.c.home('alice'))
        self.prepare(tid); self.deliver(self.a, self.b)
        self.assertEqual('beta', self.c.home('alice'))

    def test_lost_database_cannot_recreate_commit_authority(self):
        tid = self.begin(); self.prepare(tid)
        self.c.close(); self.c = Coordinator(str(Path(self.tmp.name) / 'lost.db'), 'earth')
        with self.assertRaises(ValueError):
            self.deliver(self.a, self.b)
        self.assertEqual([], self.b.status()['pending_transfers'])

    def test_failure_mid_commit_rolls_back_every_home(self):
        tid = self.begin(); self.prepare(tid)
        original = self.c._set_home
        def fail(who, region):
            original(who, region)
            if who == 'bob':
                raise RuntimeError('simulated disk failure')
        self.c._set_home = fail
        with self.assertRaises(RuntimeError):
            self.deliver(self.a, self.b)
        self.assertEqual({'alice': 'alpha', 'bob': 'alpha'}, self.c.homes())
        self.c._set_home = original
        self.deliver(self.a, self.b)
        self.assertEqual({'alice': 'beta', 'bob': 'beta'}, self.c.homes())

    def test_stale_arrival_cannot_steal_post_trip_home(self):
        epoch, old = self.c._ledger('epoch'), int(self.c._ledger('rev'))
        tid = self.begin(); self.prepare(tid); self.deliver(self.a, self.b)
        self.b.begin_import(tid, fast=True); self.deliver(self.b, self.a)
        for request in ({'ckey': 'alice', 'op': 'arrive', 'region': 'alpha'},
                        {'ckey': 'alice', 'op': 'arrive', 'region': 'alpha', 'homes_epoch': epoch, 'home_rev': old}):
            self.c.decide('alpha', request)
            self.assertEqual('beta', self.c.home('alice'))
        self.c.decide('beta', {'ckey': 'alice', 'op': 'depart', 'region': 'gamma',
                              'homes_epoch': epoch, 'home_rev': int(self.c._ledger('rev'))})
        self.assertEqual('gamma', self.c.home('alice'))

    def test_relay_and_homes_routes_release_only_after_confirmed_home_snapshot(self):
        from unittest.mock import patch
        from tools.transfer_storage.agent import _routes
        routes = {'http://127.0.0.1:1': _routes(self.a, None),
                  'http://127.0.0.1:2': _routes(self.b, None)}
        def call(url, token, path, body=None, **kwargs):
            try:
                return {'ok': True, 'result': routes[url][path](body or {})}
            except TransferError as exc:
                return {'ok': False, 'error': str(exc)}
        self.c.enroll('alpha', 'http://127.0.0.1:1', 'a' * 40)
        self.c.enroll('beta', 'http://127.0.0.1:2', 'b' * 40)
        with patch('tools.transfer_storage.coordinator.call', call):
            self.c.homes_once()
            tid, _ = self.a.begin_escrow('beta', [self.payload], fast=True)
            self.c.relay_once()
            p = self.b.pending_train_admissions()[0]
            self.b.prepare_train(tid, p['manifest_hash'], 'strip')
            self.c.relay_once(); self.c.relay_once()
            self.b.begin_import(tid, fast=True)
            self.c.relay_once(); self.c.relay_once()
            self.assertEqual('PENDING', self.a.account('alice', 'claim')['verdict'])
            self.assertEqual('PENDING', self.b.account('alice', 'claim')['verdict'])
            self.c.homes_once()
            self.assertEqual('ELSEWHERE', self.a.account('alice', 'claim')['verdict'])
            self.assertEqual('HOME', self.b.account('alice', 'claim')['verdict'])

    def test_mismatched_train_marker_cannot_reserve_accounts(self):
        self.a.begin_escrow('beta', [self.payload], fast=True)
        e = self.a.outbox()[0]
        e['manifest']['items'] = ['"wood"']
        with self.assertRaises(ValueError):
            self.c.train_envelope('alpha', e)
        self.assertEqual(['alice', 'bob'], self.c.train_locks())
        self.assertEqual(0, self.c.db.execute('SELECT COUNT(*) FROM train_custody').fetchone()[0])
        with self.assertRaises(TransferError):
            self.b.receive(dict(e, train_custody_epoch='test'))

    def test_replacement_coordinator_quarantines_all_claims_with_train_history(self):
        from unittest.mock import patch
        epoch = self.c._ledger('epoch')
        self.a.apply_homes(epoch, 2, [{'ckey': 'alice', 'region': 'alpha'}, {'ckey': 'bob', 'region': 'alpha'}], [])
        self.b.apply_homes(epoch, 2, [], [])
        tid = self.begin(); self.prepare(tid); self.deliver(self.a, self.b)
        self.c.close(); self.c = Coordinator(str(Path(self.tmp.name) / 'new.db'), 'earth')
        self.c.decide('gamma', {'ckey': 'alice', 'op': 'claim', 'region': 'gamma'})
        self.assertIsNone(self.c.home('alice'))
        self.c.enroll('alpha', 'http://127.0.0.1:1', 'a' * 40)
        self.c.enroll('beta', 'http://127.0.0.1:2', 'b' * 40)
        answers = {'http://127.0.0.1:1': self.a.account_requests(), 'http://127.0.0.1:2': self.b.account_requests()}
        with patch('tools.transfer_storage.coordinator.call', lambda url, token, path, *args, **kw:
                   {'ok': True, 'result': answers[url]}):
            self.assertEqual(0, self.c.homes_once())
        self.assertEqual('quarantined', self.c._ledger('recovery'))
        self.c.decide('gamma', {'ckey': 'alice', 'op': 'claim', 'region': 'gamma'})
        self.assertIsNone(self.c.home('alice'))
        self.assertEqual(epoch, self.a.account_requests()['epoch'])

    def test_new_coordinator_waits_for_every_region_before_claiming(self):
        from unittest.mock import patch
        self.c.close(); self.c = Coordinator(str(Path(self.tmp.name) / 'fresh.db'), 'earth')
        self.c.enroll('alpha', 'http://127.0.0.1:1', 'a' * 40)
        self.c.enroll('beta', 'http://127.0.0.1:2', 'b' * 40)
        def call(url, *args, **kw):
            if url.endswith(':2'):
                raise OSError('offline')
            return {'ok': True, 'result': self.a.account_requests()}
        with patch('tools.transfer_storage.coordinator.call', call):
            self.assertEqual(0, self.c.homes_once())
        self.assertEqual('unreconciled', self.c._ledger('recovery'))

    def test_early_abort_fences_stale_arrive_without_stealing_newer_home(self):
        epoch, rev = self.c._ledger('epoch'), int(self.c._ledger('rev'))
        tid, _ = self.a.begin_escrow('beta', [self.payload], fast=True)
        self.c._set_home('alice', 'gamma') # a newer legitimate owner won before admission
        self.a.abort(tid); self.deliver(self.a, self.b); self.deliver(self.b, self.a)
        self.a.begin_return(tid, fast=True)
        self.c.decide('beta', {'ckey': 'alice', 'op': 'arrive', 'region': 'beta',
                              'homes_epoch': epoch, 'home_rev': rev})
        self.assertEqual('gamma', self.c.home('alice'))
        self.assertEqual(2, self.c.db.execute('SELECT COUNT(*) FROM train_account_fence').fetchone()[0])

    def test_region_locally_blocks_account_while_train_active_or_leased(self):
        self.begin()
        self.assertEqual('PENDING', self.a.account('alice', 'claim')['verdict'])
        with self.assertRaises(TransferError):
            self.a.account('alice', 'depart', 'gamma')
        self.b.apply_homes('epoch', 1, [], [], train_locks=['alice', 'bob'])
        self.assertEqual('PENDING', self.b.account('alice', 'claim')['verdict'])
        with self.assertRaises(TransferError):
            self.b.account('bob', 'arrive')

if __name__ == '__main__':
    unittest.main()
