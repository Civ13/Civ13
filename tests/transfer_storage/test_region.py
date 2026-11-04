"""Crash and retry tests for the SQLite transfer store (phase 1 of
tools/server-management/TRANSFER-STORAGE-SQLITE.md)."""
import os
import random
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sim import Node, deliver  # noqa: E402
from tools.transfer_storage.region import (  # noqa: E402
    IN, OUT, RegionHeld, RegionStore, TransferError)


def pair(folder):
    a = Node(folder, 'alpha', {'a%d' % i for i in range(6)})
    b = Node(folder, 'beta', {'b%d' % i for i in range(6)})
    for x, y in ((a, b), (b, a)):
        x.store.enroll(y.name, OUT)
        x.store.enroll(y.name, IN)
    return a, b


def settle(a, b, rounds=12):
    """Run to completion with no faults: saves, deliveries and due imports."""
    for _ in range(rounds):
        for n in (a, b):
            n.run_pending()
            n.save()
        deliver([a, b])


def all_items(*nodes):
    found = []
    for n in nodes:
        found.extend(n.live)
    return found


class Basics(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.a, self.b = pair(self.tmp.name)

    def tearDown(self):
        for n in (self.a, self.b):
            n.store.close()
        self.tmp.cleanup()

    def test_happy_path_moves_items_once(self):
        self.a.start_transfer('beta', {'a0', 'a1'})
        self.assertEqual([], self.a.store.outbox())  # nothing leaves before a save
        settle(self.a, self.b)
        self.assertEqual({'a2', 'a3', 'a4', 'a5'}, self.a.live)
        self.assertEqual({'a0', 'a1'} | {'b%d' % i for i in range(6)}, self.b.live)
        for n in (self.a, self.b):
            st = n.store.status()
            self.assertEqual([], st['active'])
            self.assertEqual([], n.store.outbox())
        self.assertEqual(1, [f for f in self.a.store.status()['fences'] if f['direction'] == OUT][0]['settled_seq'])
        self.assertEqual(1, [f for f in self.b.store.status()['fences'] if f['direction'] == IN][0]['settled_seq'])

    def test_crash_before_save_voids_escrow(self):
        self.a.start_transfer('beta', {'a0'})
        self.a.crash()
        self.assertIn('a0', self.a.live)
        self.assertEqual([], self.a.store.status()['active'])
        # The sequence was never sent, so the next transfer reuses it.
        self.a.start_transfer('beta', {'a1'})
        settle(self.a, self.b)
        self.assertEqual(sorted(all_items(self.a, self.b)), sorted(set(all_items(self.a, self.b))))
        self.assertIn('a1', self.b.live)
        self.assertIn('a0', self.a.live)

    def test_crash_after_save_before_report_confirms_on_load(self):
        self.a.start_transfer('beta', {'a0'})
        self.a.save(report=False)
        self.a.crash()
        self.assertNotIn('a0', self.a.live)
        self.assertEqual('ESCROW', self.a.store.outbox()[0]['step'])
        settle(self.a, self.b)
        self.assertIn('a0', self.b.live)

    def test_crash_after_import_before_save_redoes_import(self):
        self.a.start_transfer('beta', {'a0'})
        self.a.save()
        deliver([self.a, self.b])  # ESCROW -> PREPARE
        deliver([self.a, self.b])  # PREPARE -> COMMIT
        deliver([self.a, self.b])  # COMMIT received
        self.b.run_pending()
        self.assertIn('a0', self.b.live)
        self.b.crash()
        self.assertNotIn('a0', self.b.live)
        settle(self.a, self.b)
        self.assertIn('a0', self.b.live)
        self.assertEqual(1, all_items(self.a, self.b).count('a0'))

    def test_abort_before_commit_returns_items(self):
        tid = self.a.start_transfer('beta', {'a0'})
        self.a.save()
        deliver([self.a, self.b])          # ESCROW reaches beta, PREPARE queued
        self.a.store.abort(tid)
        for _ in range(8):
            for n in (self.a, self.b):
                n.run_pending()
                n.save()
            deliver([self.a, self.b])
        self.assertIn('a0', self.a.live)
        self.assertNotIn('a0', self.b.live)
        self.assertEqual([], self.a.store.status()['active'])
        self.assertEqual([], self.b.store.status()['active'])

    def test_abort_refused_after_commit(self):
        tid = self.a.start_transfer('beta', {'a0'})
        self.a.save()
        deliver([self.a, self.b])
        deliver([self.a, self.b])
        with self.assertRaises(TransferError):
            self.a.store.abort(tid)

    def test_restoring_an_older_backup_holds_the_region(self):
        old = dict(self.a.saved)
        self.a.start_transfer('beta', {'a0'})
        settle(self.a, self.b)
        self.assertIn('a0', self.b.live)
        self.a.restore_backup(old)
        self.assertIn('a0', self.a.live)  # the backup still has it...
        self.assertTrue(self.a.store.status()['hold_reason'].startswith('rollback'))
        with self.assertRaises(RegionHeld):  # ...but nothing can move until an operator acts
            self.a.start_transfer('beta', {'a0'})
        fence = [f for f in self.a.store.status()['fences'] if f['direction'] == OUT][0]
        self.assertEqual(1, fence['settled_seq'])  # the fence is never rewound

    def test_replayed_and_foreign_envelopes_change_nothing(self):
        self.a.start_transfer('beta', {'a0'})
        self.a.save()
        escrow = self.a.store.outbox()[0]
        settle(self.a, self.b)
        before = self.b.store.status()
        reply = self.b.store.receive(dict(escrow))
        self.assertEqual('ACK', reply['step'])
        self.assertEqual(before, self.b.store.status())
        with self.assertRaises(TransferError):
            self.b.store.receive(dict(escrow, group='other'))
        forged = dict(escrow, seq=2)
        with self.assertRaises(TransferError):
            self.b.store.receive(forged)  # transfer id does not match the channel

    def test_unenrolled_peer_is_refused(self):
        with self.assertRaises(TransferError):
            self.a.store.begin_escrow('gamma', ['a0'])

    def test_store_refuses_another_region_file(self):
        import sqlite3
        from tools.transfer_storage import region
        opened = []
        real = region.sqlite3.connect

        def tracking(*args, **kwargs):
            opened.append(real(*args, **kwargs))
            return opened[-1]
        region.sqlite3.connect = tracking
        try:
            with self.assertRaises(TransferError):
                RegionStore(self.a.path, 'beta', 'test-group')
        finally:
            region.sqlite3.connect = real
        # The refused open must close its connection (Windows cannot delete open files).
        with self.assertRaises(sqlite3.ProgrammingError):
            opened[0].execute('SELECT 1')


class RandomFaults(unittest.TestCase):
    """Random interleavings of transfers, saves, crashes, lost and duplicated
    messages. Items must never be live in two worlds and must all survive."""

    def run_seed(self, seed):
        rng = random.Random(seed)
        with tempfile.TemporaryDirectory() as folder:
            a, b = pair(folder)
            nodes = (a, b)
            everything = set(all_items(a, b))
            try:
                for _ in range(60):
                    n = rng.choice(nodes)
                    peer = b if n is a else a
                    r = rng.random()
                    try:
                        if r < 0.15 and n.live:
                            k = rng.randint(1, min(3, len(n.live)))
                            n.start_transfer(peer.name, set(rng.sample(sorted(n.live), k)))
                        elif r < 0.25:
                            n.run_pending()
                        elif r < 0.45:
                            n.save(report=rng.random() < 0.8)
                        elif r < 0.55:
                            n.crash()
                        elif r < 0.60:
                            active = [x for x in n.store.status()['active'] if x['direction'] == OUT]
                            if active:
                                n.store.abort(active[0]['transfer_id'])
                        else:
                            deliver(nodes, rng, drop=0.3, duplicate=0.3)
                    except TransferError:
                        pass
                    live = all_items(a, b)
                    self.assertEqual(len(live), len(set(live)), 'item live in two worlds (seed %d)' % seed)
                settle(a, b, rounds=16)
                live = all_items(a, b)
                self.assertEqual(sorted(everything), sorted(live), 'items lost or duplicated (seed %d)' % seed)
                for n in nodes:
                    self.assertEqual('', n.store.status()['hold_reason'])
                    self.assertEqual([], n.store.status()['active'], 'transfer stuck (seed %d)' % seed)
            finally:
                for n in nodes:
                    n.store.close()

    def test_random_interleavings(self):
        for seed in range(150):
            self.run_seed(seed)


if __name__ == '__main__':
    unittest.main()
