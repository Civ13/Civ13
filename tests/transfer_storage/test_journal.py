"""Fast (journaled) character transfers: confirmed when recorded, replayed after
a load whose save does not list them. Characters must never be live in two
worlds, and none may be lost, whatever crashes and message faults happen."""
import json
import os
import random
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sim import Node, deliver  # noqa: E402
from tools.transfer_storage.region import (  # noqa: E402
    IN, OUT, RegionStore, TransferError)


def character(owner):
    return json.dumps({'v': 1, 'kind': 'character', 'owner': owner}, sort_keys=True)


class FastNode(Node):
    """A world whose characters travel fast and whose loads replay the journal."""

    def start_transfer(self, peer, items):
        tid, effect = self.store.begin_escrow(peer, sorted(items), fast=True)
        self.live -= set(items)
        self.pending.append(effect)
        return tid

    def run_pending(self):
        for tid in self.store.status()['pending_transfers']:
            row = [a for a in self.store.status()['active'] if a['transfer_id'] == tid][0]
            begin = self.store.begin_import if row['direction'] == IN else self.store.begin_return
            try:
                effect, payloads = begin(tid, fast=True)
            except TransferError:
                continue
            self.live |= set(payloads)
            self.pending.append(effect)

    def crash(self):
        self.store.close()
        self.store = RegionStore(self.path, self.name, self.group)
        s = self.saved
        self.live = set(s['items'])
        self.pending = []
        base = self.store.reconcile_load(s['generation'], s['effects'], s['ledger'])
        self.base = base if base is not None else self.base
        for entry in self.store.replay():
            if entry['kind'] == 'remove':
                self.live -= set(entry['payloads'])
            else:
                self.live |= set(entry['payloads'])
            self.pending.append(entry['effect_id'])


def pair(folder):
    a = FastNode(folder, 'alpha', {character('a%d' % i) for i in range(4)})
    b = FastNode(folder, 'beta', {character('b%d' % i) for i in range(4)})
    for x, y in ((a, b), (b, a)):
        x.store.enroll(y.name, OUT)
        x.store.enroll(y.name, IN)
    return a, b


def run(a, b, rounds=8, save=False):
    for _ in range(rounds):
        for n in (a, b):
            n.run_pending()
            if save:
                n.save()
        deliver([a, b])


class Journal(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.a, self.b = pair(self.tmp.name)

    def tearDown(self):
        for n in (self.a, self.b):
            n.store.close()
        self.tmp.cleanup()

    def test_a_trip_settles_without_any_world_save(self):
        c = character('a0')
        self.a.start_transfer('beta', {c})
        self.assertEqual(['ESCROW'], [e['step'] for e in self.a.store.outbox()])
        run(self.a, self.b)
        self.assertIn(c, self.b.live)
        self.assertNotIn(c, self.a.live)
        for n in (self.a, self.b):
            self.assertEqual([], n.store.status()['active'])
            self.assertEqual(1, n.store.status()['journal'])

    def test_save_listing_the_effect_clears_the_journal(self):
        self.a.start_transfer('beta', {character('a0')})
        run(self.a, self.b)
        for n in (self.a, self.b):
            n.save()
            self.assertEqual(0, n.store.status()['journal'])
            self.assertEqual([], n.store.replay())

    def test_source_crash_before_a_save_replays_the_departure(self):
        c = character('a0')
        self.a.start_transfer('beta', {c})
        run(self.a, self.b)
        self.a.crash()  # the loaded save still holds a0
        self.assertNotIn(c, self.a.live)
        self.assertIn(c, self.b.live)

    def test_destination_crash_before_a_save_replays_the_arrival(self):
        c = character('a0')
        self.a.start_transfer('beta', {c})
        run(self.a, self.b)
        self.b.crash()  # the loaded save never had a0
        self.assertIn(c, self.b.live)
        self.b.save()
        self.b.crash()
        self.assertIn(c, self.b.live)
        self.assertEqual(0, self.b.store.status()['journal'])

    def test_returned_character_is_replayed_at_the_source(self):
        c = character('a0')
        tid = self.a.start_transfer('beta', {c})
        self.a.store.abort(tid)
        run(self.a, self.b)
        self.assertIn(c, self.a.live)
        self.assertNotIn(c, self.b.live)
        self.a.crash()  # the save before the trip: removal and return both replay
        self.assertIn(c, self.a.live)
        self.assertEqual([], self.a.store.status()['active'])

    def test_resetting_raid_world_boots_fresh(self):
        """A raid world that never saves adopts the store's ledger on each new
        map instead of being held for a rollback. A crash replays its journal;
        a reset first confirms the journal, so the next map replays nothing."""
        c = character('a0')
        self.a.start_transfer('beta', {c})
        run(self.a, self.b)
        self.b.store.close()
        self.b.store = RegionStore(self.b.path, self.b.name, self.b.group)
        # An ordinary unsaved load would now be refused as a rollback.
        seq = self.b.store.reconcile_load('raid-1', [], 0, fresh=True)
        self.assertIsNotNone(seq)
        self.assertFalse(self.b.store.status().get('hold_reason'))
        replay = self.b.store.replay()
        self.assertEqual([[c]], [e['payloads'] for e in replay], 'a crash rebuilds the raider on the new map')
        # The reset settles every applied effect before rebooting.
        seq = self.b.store.report_save('raid-reset-1', [e['effect_id'] for e in replay], seq)
        self.b.store.close()
        self.b.store = RegionStore(self.b.path, self.b.name, self.b.group)
        self.assertIsNotNone(self.b.store.reconcile_load('raid-2', ['ignored'], 99, fresh=True))
        self.assertEqual([], self.b.store.replay(), 'nobody comes back after a reset')
        self.assertFalse(self.b.store.status().get('hold_reason'))

    def test_goods_cannot_travel_fast(self):
        for payloads in (['plain'], [json.dumps({'kind': 'goods'})], [character('x'), 'plain']):
            with self.assertRaises(TransferError):
                self.a.store.begin_escrow('beta', payloads, fast=True)
        self.assertEqual([], self.a.store.status()['active'])

    def test_older_backup_still_holds_the_region(self):
        snapshot = dict(self.a.saved)
        self.a.start_transfer('beta', {character('a0')})
        run(self.a, self.b, save=True)
        self.a.restore_backup(snapshot)
        self.assertTrue(self.a.store.status()['hold_reason'].startswith('rollback'))


class RandomFaults(unittest.TestCase):
    def run_seed(self, seed):
        rng = random.Random(seed)
        with tempfile.TemporaryDirectory() as folder:
            a, b = pair(folder)
            nodes = (a, b)
            everyone = set(a.live | b.live)
            try:
                for _ in range(60):
                    n = rng.choice(nodes)
                    peer = b if n is a else a
                    r = rng.random()
                    try:
                        if r < 0.2 and n.live:
                            n.start_transfer(peer.name, {rng.choice(sorted(n.live))})
                        elif r < 0.3:
                            n.run_pending()
                        elif r < 0.45:
                            n.save(report=rng.random() < 0.8)
                        elif r < 0.6:
                            n.crash()
                        elif r < 0.65:
                            active = [x for x in n.store.status()['active'] if x['direction'] == OUT]
                            if active:
                                n.store.abort(active[0]['transfer_id'])
                        else:
                            deliver(nodes, rng, drop=0.3, duplicate=0.3)
                    except TransferError:
                        pass
                    self.assertFalse(a.live & b.live, 'character live in two worlds (seed %d)' % seed)
                run(a, b, rounds=16, save=True)
                self.assertEqual(sorted(everyone), sorted(a.live | b.live), 'characters lost (seed %d)' % seed)
                self.assertFalse(a.live & b.live, 'character live in two worlds (seed %d)' % seed)
                for n in nodes:
                    st = n.store.status()
                    self.assertEqual('', st['hold_reason'])
                    self.assertEqual([], st['active'], 'transfer stuck (seed %d)' % seed)
                    self.assertEqual(0, st['journal'], 'journal not cleared (seed %d)' % seed)
            finally:
                for n in nodes:
                    n.store.close()

    def test_random_interleavings(self):
        for seed in range(150):
            self.run_seed(seed)


if __name__ == '__main__':
    unittest.main()
