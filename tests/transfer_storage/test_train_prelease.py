"""Durable preleases before source capture; no physical world/native simulation."""
import copy
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from tools.transfer_storage.agent import _routes
from tools.transfer_storage.coordinator import Coordinator
from tools.transfer_storage.region import RegionStore, OUT, IN, TransferError
from tools.transfer_storage.train_lease import lease_binding
from test_train import manifest


class TrainPreleaseTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.a = RegionStore(str(Path(self.tmp.name) / 'a.db'), 'alpha', 'earth')
        self.b = RegionStore(str(Path(self.tmp.name) / 'b.db'), 'beta', 'earth')
        self.a.enroll('beta', OUT); self.b.enroll('alpha', IN)
        self.c = Coordinator(str(Path(self.tmp.name) / 'c.db'), 'earth', bootstrap_new_group=True)
        self.c._set_home('alice', 'alpha')
        self.c.enroll('alpha', 'http://127.0.0.1:1', 'a' * 40)
        self.c.enroll('beta', 'http://127.0.0.1:2', 'b' * 40)
        self.routes = {'http://127.0.0.1:1': _routes(self.a, None), 'http://127.0.0.1:2': _routes(self.b, None)}
        def call(url, token, path, body=None, **kw):
            try:
                return {'ok': True, 'result': self.routes[url][path](body or {})}
            except (ValueError, TransferError) as exc:
                return {'ok': False, 'error': str(exc)}
        self.mock = patch('tools.transfer_storage.coordinator.call', call)
        self.mock.start()
        self.c.homes_once()
        self.m = manifest(); self.request = lease_binding(self.m)

    def tearDown(self):
        self.mock.stop(); self.a.close(); self.b.close(); self.c.close(); self.tmp.cleanup()

    def grant(self):
        self.a.reserve_train(self.request)
        self.c.homes_once()
        return self.a.train_lease_status(self.m['journey'])

    def test_reserve_pending_then_grant_and_exact_retry(self):
        pending = self.a.reserve_train(self.request)
        self.assertEqual('pending', pending['state'])
        self.assertEqual('', pending['token'])
        self.assertEqual(pending, self.a.reserve_train(self.request))
        self.assertEqual('PENDING', self.a.account('alice', 'claim')['verdict'])
        self.c.homes_once()
        grant = self.a.train_lease_status(self.m['journey'])
        self.assertEqual('granted', grant['state'])
        self.assertEqual(64, len(grant['token']))
        self.assertEqual(['alice'], self.c.train_locks())
        self.assertEqual(grant, self.a.reserve_train(self.request))
        self.assertEqual(self.m['journey'], self.a.lookup_train(self.m['id'])['leases'][0]['journey'])

    def test_different_identity_on_same_journey_refused(self):
        self.grant()
        for key, value in (('id', 'other'), ('accounts', []), ('station', 'other')):
            request = dict(self.request, **{key: value})
            with self.assertRaises(ValueError):
                self.a.reserve_train(request)
        self.assertEqual('granted', self.a.train_lease_status(self.m['journey'])['state'])

    def test_unleased_and_wrong_token_escrow_fail(self):
        with self.assertRaises(TransferError):
            self.a.begin_escrow('beta', [json.dumps(self.m)], fast=True)
        token = self.grant()['token']
        for wrong in (None, '', 'x' * 64):
            with self.assertRaises(TransferError):
                self.a.begin_escrow('beta', [json.dumps(self.m)], fast=True, train_lease=wrong)
        changed = dict(self.m, station='other')
        with self.assertRaises(TransferError):
            self.a.begin_escrow('beta', [json.dumps(changed)], fast=True, train_lease=token)
        self.assertEqual([], self.a.status()['active'])

    def test_final_mutable_state_seals_token_and_cannot_cancel(self):
        token = self.grant()['token']
        self.m['segments'][0]['fuel'] = 9
        tid, _ = self.a.begin_escrow('beta', [json.dumps(self.m)], fast=True, train_lease=token)
        self.c.relay_once()
        self.assertEqual(tid, self.a.train_lease_status(self.m['journey'])['transfer_id'])
        with self.assertRaises(ValueError):
            self.a.cancel_train_lease(self.m['journey'])
        self.assertEqual('sealed', self.c.db.execute('SELECT state FROM train_prelease').fetchone()[0])
        self.assertEqual(1, len(self.b.pending_train_admissions()))

    def test_cancel_before_grant_releases_without_expiry(self):
        self.a.reserve_train(self.request)
        self.assertEqual('cancel_pending', self.a.cancel_train_lease(self.m['journey'])['state'])
        self.c.homes_once()
        self.assertEqual('cancelled', self.a.train_lease_status(self.m['journey'])['state'])
        self.assertEqual([], self.c.train_locks())
        self.assertEqual('HOME', self.a.account('alice', 'claim')['verdict'])
        self.assertEqual('cancelled', self.a.reserve_train(self.request)['state'])

    def test_cancel_after_grant_survives_restart(self):
        grant = self.grant()
        self.a.cancel_train_lease(self.m['journey'])
        self.a.close(); self.a = RegionStore(str(Path(self.tmp.name) / 'a.db'), 'alpha', 'earth')
        self.routes['http://127.0.0.1:1'] = _routes(self.a, None)
        self.assertEqual('cancel_pending', self.a.train_lease_status(self.m['journey'])['state'])
        self.c.homes_once()
        result = self.a.train_lease_status(self.m['journey'])
        self.assertEqual('cancelled', result['state'])
        self.assertEqual(grant['token'], result['token'])
        self.assertEqual([], self.c.train_locks())

    def test_stale_grant_cannot_erase_pending_cancel(self):
        grant = self.grant()
        self.a.cancel_train_lease(self.m['journey'])
        self.a.apply_homes(grant['epoch'], int(self.a._meta('homes_rev')), [], [], train_decisions=[grant])
        self.assertEqual('cancel_pending', self.a.train_lease_status(self.m['journey'])['state'])

    def test_coordinator_rejects_wrong_token_without_sealing(self):
        token = self.grant()['token']
        self.a.begin_escrow('beta', [json.dumps(self.m)], fast=True, train_lease=token)
        e = self.a.outbox()[0]; e['train_lease'] = 'z' * 64
        with self.assertRaises(ValueError):
            self.c.train_envelope('alpha', e)
        self.assertEqual('granted', self.c.db.execute('SELECT state FROM train_prelease').fetchone()[0])
        self.assertEqual(0, self.c.db.execute('SELECT COUNT(*) FROM train_custody').fetchone()[0])

    def test_unknown_home_rejects_all_and_retains_handle(self):
        self.c.db.execute("DELETE FROM home WHERE ckey='alice'")
        self.a.reserve_train(self.request); self.c.homes_once()
        status = self.a.train_lease_status(self.m['journey'])
        self.assertEqual('rejected', status['state'])
        self.assertIn('home', status['reason'])
        self.assertEqual([], self.c.train_locks())

if __name__ == '__main__':
    unittest.main()
