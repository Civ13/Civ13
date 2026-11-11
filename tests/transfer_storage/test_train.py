"""Physical-train grouped protocol tests. Not native movement acceptance."""
import copy
import json
import tempfile
import unittest
from pathlib import Path
from tools.transfer_storage.region import RegionStore, TransferError, OUT, IN
from tools.transfer_storage.train import validate


def manifest(identity='alpha-train1'):
    return {'kind': 'train', 'version': 1, 'id': identity, 'journey': identity + '-journey1', 'party': 'ckey:alice',
            'source': 'alpha', 'destination': 'beta', 'station': 'beta-station1',
            'segments': [{'id': identity + '-segment1', 'type': '/obj/structure/trains/locomotive/coal',
                          'dir': 4, 'health': 100, 'on': 0, 'fuel': 5, 'car_kind': '',
                          'car_id': '', 'seg_index': 0, 'open_doors': 0}],
            'entities': [{'id': identity + '-alice', 'kind': 'character', 'segment': 1, 'slot': 2,
                          'payload': json.dumps({'kind': 'character', 'owner': 'alice', 'party': 'ckey:alice'}), 'dir': 4, 'anchored': 0}],
            'accounts': ['alice']}


class TrainTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.a = RegionStore(str(Path(self.tmp.name) / 'a.db'), 'alpha', 'earth')
        self.b = RegionStore(str(Path(self.tmp.name) / 'b.db'), 'beta', 'earth')
        self.a.enroll('beta', OUT)
        self.b.enroll('alpha', IN)

    def tearDown(self):
        self.a.close()
        self.b.close()
        self.tmp.cleanup()

    def start(self):
        payload = json.dumps(manifest())
        tid, effect = self.a.begin_escrow('beta', [payload], fast=True)
        self.b.receive(self.a.outbox()[0])
        return tid, effect, payload

    def admit(self, tid):
        pending = self.b.pending_train_admissions()[0]
        return self.b.prepare_train(tid, pending['manifest_hash'], 'entry-strip-1')

    def test_waits_for_admission_and_full_payload_replays(self):
        tid, effect, payload = self.start()
        self.assertEqual([], self.b.outbox())
        self.assertEqual([], self.b.status()['pending_transfers'])
        with self.assertRaises(TransferError):
            self.b.begin_import(tid, fast=True)
        self.admit(tid)
        self.a.receive(self.b.outbox()[0])
        self.b.receive(self.a.outbox()[0])
        imported, data = self.b.begin_import(tid, fast=True)
        self.assertEqual([payload], data)
        self.assertEqual([payload], self.b.replay()[0]['payloads'])
        self.a.receive(self.b.outbox()[0])
        reply = self.b.receive(self.a.outbox()[0])
        self.a.receive(reply)
        self.assertEqual([], self.a.status()['active'])
        self.assertEqual([], self.b.status()['active'])
        self.assertEqual(effect, self.a.lookup_train('alpha-train1')['replay'][0]['effect_id'])

    def test_pending_abort_returns_manifest(self):
        tid, _, payload = self.start()
        self.a.abort(tid)
        self.b.receive(self.a.outbox()[0])
        self.a.receive(self.b.outbox()[0])
        _, restored = self.a.begin_return(tid, fast=True)
        self.assertEqual([payload], restored)
        self.assertEqual([], self.b.pending_train_admissions())

    def test_admission_is_hash_bound_idempotent_and_survives_reopen(self):
        tid, _, _ = self.start()
        pending = self.b.pending_train_admissions()[0]
        with self.assertRaises(TransferError):
            self.b.prepare_train(tid, 'wrong', 'entry-strip-1')
        self.admit(tid)
        self.b.close()
        self.b = RegionStore(str(Path(self.tmp.name) / 'b.db'), 'beta', 'earth')
        self.assertEqual({'prepared': True}, self.b.prepare_train(tid, pending['manifest_hash'], 'entry-strip-1'))
        with self.assertRaises(TransferError):
            self.b.prepare_train(tid, pending['manifest_hash'], 'other-strip')
        self.b.receive(self.a.outbox()[0]) # duplicate escrow does not regress admission
        self.assertEqual('PREPARE', self.b.outbox()[0]['step'])

    def test_reject_bad_schema_membership_graph_and_bounds(self):
        mutations = [lambda m: m.update(extra=1), lambda m: m.update(accounts=[]),
                     lambda m: m['accounts'].append('alice'),
                     lambda m: m['segments'].append(copy.deepcopy(m['segments'][0])),
                     lambda m: m['entities'][0].update(segment=0),
                     lambda m: m['segments'][0].update(type='/mob/living/human'),
                     lambda m: m['segments'][0].update(fuel=float('nan')),
                     lambda m: m['entities'][0].update(payload='x' * 200001)]
        for mutate in mutations:
            m = manifest(); mutate(m)
            with self.subTest(mutate=mutate), self.assertRaises(TransferError):
                self.a.begin_escrow('beta', [json.dumps(m)], fast=True)
        self.assertEqual([], self.a.status()['active'])

    def test_no_mixed_or_split_manifests_or_wrong_peer(self):
        payload = json.dumps(manifest())
        for items in ([payload, payload], [payload, json.dumps({'kind': 'character'})]):
            with self.assertRaises(TransferError):
                self.a.begin_escrow('beta', items, fast=True)
        with self.assertRaises(TransferError):
            self.a.begin_escrow('gamma', [payload], fast=True)

    def test_passenger_already_elsewhere_rejected(self):
        self.a.apply_homes('epoch', 1, [{'ckey': 'alice', 'region': 'gamma'}], [])
        with self.assertRaises(TransferError):
            self.a.begin_escrow('beta', [json.dumps(manifest())], fast=True)

    def test_duplicate_passenger_cannot_enter_second_transfer(self):
        self.start()
        self.a.enroll('gamma', OUT)
        second = manifest('alpha-train2'); second['destination'] = 'gamma'
        with self.assertRaises(TransferError):
            self.a.begin_escrow('gamma', [json.dumps(second)], fast=True)

    def test_two_sources_cannot_reserve_same_passenger(self):
        self.start()
        c = RegionStore(str(Path(self.tmp.name) / 'c.db'), 'gamma', 'earth')
        try:
            c.enroll('beta', OUT)
            self.b.enroll('gamma', IN)
            m = manifest('gamma-train'); m['source'] = 'gamma'
            c.begin_escrow('beta', [json.dumps(m)], fast=True)
            with self.assertRaises(TransferError):
                self.b.receive(c.outbox()[0])
        finally:
            c.close()

    def test_route_api_reports_admission_and_lookup(self):
        from tools.transfer_storage.agent import _routes
        tid, _, _ = self.start()
        routes = _routes(self.b, None)
        pending = routes['/train/pending']({})['trains'][0]
        lookup = routes['/train/lookup']({'id': 'alpha-train1'})['active'][0]
        self.assertEqual(tid, lookup['transfer_id'])
        self.assertEqual('alpha-train1-journey1', lookup['journey'])
        self.assertEqual(pending['manifest_hash'], lookup['manifest_hash'])
        result = routes['/train/prepare']({'transfer_id': tid,
                                          'manifest_hash': pending['manifest_hash'],
                                          'reservation': 'strip-2'})
        self.assertEqual({'prepared': True}, result)

    def test_existing_nontrain_json_scalar_goods_still_work(self):
        for payload in ('"wood"', '[]', '{}', '17', 'null'):
            # Separate stores avoid the intentional per-peer flight limit.
            c = RegionStore(':memory:', 'alpha', 'earth')
            try:
                c.enroll('beta', OUT)
                c.begin_escrow('beta', [payload])
            finally:
                c.close()

    def test_codec_parity_platform_and_numeric_bounds(self):
        m = manifest()
        m['segments'][0]['type'] = '/obj/structure/trains/locomotive'
        validate(json.dumps(m))
        example = dict(m['segments'][0], type='/obj/structure/trains/platform',
                       car_kind='coach', car_id='coach1', open_doors=65535)
        m['segments'] = [dict(example, id='s' + str(i), seg_index=i) for i in range(1, 5)]
        validate(json.dumps(m))
        for cut in (1, 2, 3):
            bad = copy.deepcopy(m); bad['segments'] = bad['segments'][:cut]
            with self.assertRaises(ValueError):
                validate(json.dumps(bad))
        bad = copy.deepcopy(m); bad['segments'][2]['car_id'] = 'other'
        with self.assertRaises(ValueError):
            validate(json.dumps(bad))
        for field, value in (('health', 0), ('health', 1501), ('health', 1.5), ('fuel', 101), ('type', [])):
            bad = manifest(); bad['segments'][0][field] = value
            with self.assertRaises(TransferError):
                self.a.begin_escrow('beta', [json.dumps(bad)], fast=True)
        bad = manifest(); bad['entities'][0]['slot'] = 1
        with self.assertRaises(ValueError):
            validate(json.dumps(bad))

    def test_64_segments_accepted_65_refused(self):
        m = manifest(); example = m['segments'][0]
        m['segments'] = [dict(example, id='seg' + str(i)) for i in range(64)]
        validate(json.dumps(m))
        m['segments'].append(dict(example, id='extra'))
        with self.assertRaises(ValueError):
            validate(json.dumps(m))

if __name__ == '__main__':
    unittest.main()
