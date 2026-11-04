"""A two-region simulation of DM worlds around RegionStore, for crash tests.

Each Node stands in for one DreamDaemon world: `live` is the in-memory item set,
`saved` is the last committed world save. A crash throws the in-memory world
away and reloads the saved one; the SQLite file survives.
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, ROOT)
from tools.transfer_storage.region import RegionStore, TransferError  # noqa: E402


class Node:
    def __init__(self, folder, name, items, group='test-group'):
        self.name = name
        self.path = os.path.join(folder, name + '.sqlite')
        self.group = group
        self.store = RegionStore(self.path, name, group)
        self.live = set(items)
        self.pending = []          # effect ids applied since the cached ledger base
        self.base = self.store.ledger_seq()
        self.generation = 0
        self.saved = {'generation': name + '-g0', 'items': set(items), 'effects': [], 'ledger': self.base}
        self.base = self.store.reconcile_load(name + '-g0', [], self.base)

    # world effects ---------------------------------------------------------
    def start_transfer(self, peer, items):
        tid, effect = self.store.begin_escrow(peer, sorted(items))
        self.live -= set(items)
        self.pending.append(effect)
        return tid

    def run_pending(self):
        """Apply imports and returns that are due (DM's arrival point)."""
        for tid in self.store.status()['pending_transfers']:
            row = [a for a in self.store.status()['active'] if a['transfer_id'] == tid][0]
            begin = self.store.begin_import if row['direction'] == 'in' else self.store.begin_return
            try:
                effect, payloads = begin(tid)
            except TransferError:
                continue  # already applied, waiting for a save
            self.live |= set(payloads)
            self.pending.append(effect)

    # saves and crashes -------------------------------------------------------
    def save(self, report=True):
        self.generation += 1
        generation = '%s-g%d' % (self.name, self.generation)
        self.saved = {'generation': generation, 'items': set(self.live), 'effects': list(self.pending),
                      'ledger': self.base}
        if report:
            self.report()

    def report(self):
        s = self.saved
        self.base = self.store.report_save(s['generation'], s['effects'], s['ledger'])
        self.pending = [e for e in self.pending if e not in s['effects']]

    def crash(self):
        self.store.close()
        self.store = RegionStore(self.path, self.name, self.group)
        s = self.saved
        self.live = set(s['items'])
        self.pending = []
        base = self.store.reconcile_load(s['generation'], s['effects'], s['ledger'])
        self.base = base if base is not None else self.base

    def restore_backup(self, snapshot):
        self.saved = {'generation': snapshot['generation'], 'items': set(snapshot['items']),
                      'effects': list(snapshot['effects']), 'ledger': snapshot['ledger']}
        self.crash()


def deliver(nodes, rng=None, drop=0.0, duplicate=0.0):
    """Send every outbox envelope once (with optional loss/duplication)."""
    by_name = {n.name: n for n in nodes}
    moved = False
    queue = []
    for node in nodes:
        queue.extend(node.store.outbox())
    if rng:
        rng.shuffle(queue)
    while queue:
        env = queue.pop(0)
        if rng and rng.random() < drop:
            continue
        copies = 2 if rng and rng.random() < duplicate else 1
        for _ in range(copies):
            try:
                reply = by_name[env['recipient']].store.receive(json.loads(json.dumps(env)))
            except TransferError:
                continue
            moved = True
            if reply and not (rng and rng.random() < drop):
                try:
                    by_name[reply['recipient']].store.receive(reply)
                except TransferError:
                    pass
    return moved
