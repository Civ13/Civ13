"""SQLite transfer state for one region (one DreamDaemon world).

Implements the design in tools/server-management/TRANSFER-STORAGE-SQLITE.md:
world effects are recorded as tentative before the world applies them, and are
confirmed only by a committed world save that lists them. Envelopes for a step
are written to the outbox only after the effects behind that step are
confirmed. Standard library only.
"""
import hashlib
import json
import sqlite3

SCHEMA_VERSION = 1

# Directions are from this region's point of view.
OUT, IN = 'out', 'in'

# Source phases (direction OUT).
REQUESTED = 'Requested'            # escrow removal tentative, nothing sent yet
ESCROWED = 'Escrowed'              # removal confirmed, ESCROW in outbox
COMMIT_DECIDED = 'CommitDecided'   # irreversible; COMMIT in outbox
ABORT_DECIDED = 'AbortDecided'     # before commit only; ABORT in outbox
RETURNING = 'Returning'            # tombstone received; return applied or due
# Destination phases (direction IN).
PREPARED = 'Prepared'              # PREPARE in outbox
COMMIT_RECEIVED = 'CommitReceived' # import may run
IMPORTED = 'Imported'              # credit confirmed, IMPORTED in outbox
DESTINATION_ABORTED = 'DestinationAborted'  # TOMBSTONE in outbox

REMOVE, CREDIT, RETURN = 'remove', 'credit', 'return'
TENTATIVE, CONFIRMED = 'tentative', 'confirmed'


class TransferError(Exception):
    """A request that the current state refuses. Nothing was changed."""


class RegionHeld(TransferError):
    """The region is on hold (for example after an older backup was loaded)."""


def transfer_id(group, source, destination, epoch, seq):
    """Identifier of a directional transfer; an ID, not an authentication proof."""
    text = json.dumps(['civ13-transfer/1', group, source, destination, epoch, seq], separators=(',', ':'))
    return hashlib.sha256(text.encode('ascii')).hexdigest()


class RegionStore:
    def __init__(self, path, region_id, group_id):
        self.region = region_id
        self.group = group_id
        self.db = sqlite3.connect(path, isolation_level=None)
        self.db.execute('PRAGMA journal_mode=WAL')
        self.db.execute('PRAGMA synchronous=FULL')
        self.db.execute('PRAGMA foreign_keys=ON')
        with self._tx():
            self._migrate()

    def close(self):
        self.db.close()

    # -- plumbing -------------------------------------------------------

    def _tx(self):
        store = self

        class Tx:
            def __enter__(self):
                store.db.execute('BEGIN IMMEDIATE')

            def __exit__(self, kind, value, tb):
                store.db.execute('COMMIT' if kind is None else 'ROLLBACK')
                return False
        return Tx()

    def _migrate(self):
        db = self.db
        db.execute('CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)')
        found = dict(db.execute('SELECT key, value FROM meta'))
        if not found:
            for key, value in [('schema', str(SCHEMA_VERSION)), ('region', self.region), ('group', self.group),
                               ('ledger_seq', '0'), ('confirmed_generation', ''), ('hold_reason', '')]:
                db.execute('INSERT INTO meta VALUES (?, ?)', (key, value))
        elif found['schema'] != str(SCHEMA_VERSION) or found['region'] != self.region or found['group'] != self.group:
            raise TransferError('transfer store belongs to another region, group or schema')
        db.execute('''CREATE TABLE IF NOT EXISTS fence(
            direction TEXT NOT NULL, peer TEXT NOT NULL, epoch INTEGER NOT NULL, settled_seq INTEGER NOT NULL,
            PRIMARY KEY(direction, peer))''')
        db.execute('''CREATE TABLE IF NOT EXISTS active(
            direction TEXT NOT NULL, peer TEXT NOT NULL, seq INTEGER NOT NULL, transfer_id TEXT NOT NULL UNIQUE,
            manifest TEXT NOT NULL, phase TEXT NOT NULL, PRIMARY KEY(direction, peer))''')
        db.execute('''CREATE TABLE IF NOT EXISTS escrow(
            transfer_id TEXT NOT NULL, idx INTEGER NOT NULL, payload TEXT NOT NULL,
            PRIMARY KEY(transfer_id, idx))''')
        db.execute('''CREATE TABLE IF NOT EXISTS effect(
            effect_id TEXT PRIMARY KEY, transfer_id TEXT NOT NULL, kind TEXT NOT NULL, state TEXT NOT NULL)''')
        db.execute('''CREATE TABLE IF NOT EXISTS outbox(
            direction TEXT NOT NULL, peer TEXT NOT NULL, step TEXT NOT NULL, body TEXT NOT NULL,
            PRIMARY KEY(direction, peer))''')

    def _meta(self, key):
        return self.db.execute('SELECT value FROM meta WHERE key = ?', (key,)).fetchone()[0]

    def _set_meta(self, key, value):
        self.db.execute('UPDATE meta SET value = ? WHERE key = ?', (str(value), key))

    def _require_open(self):
        reason = self._meta('hold_reason')
        if reason:
            raise RegionHeld(reason)

    def _fence(self, direction, peer):
        row = self.db.execute('SELECT epoch, settled_seq FROM fence WHERE direction = ? AND peer = ?',
                              (direction, peer)).fetchone()
        if row is None:
            raise TransferError('peer %r is not enrolled for %s transfers' % (peer, direction))
        return row

    def _active(self, direction, peer):
        return self.db.execute('SELECT seq, transfer_id, manifest, phase FROM active WHERE direction = ? AND peer = ?',
                               (direction, peer)).fetchone()

    def _active_by_id(self, tid):
        return self.db.execute('SELECT direction, peer, seq, manifest, phase FROM active WHERE transfer_id = ?',
                               (tid,)).fetchone()

    def _set_phase(self, tid, phase):
        self.db.execute('UPDATE active SET phase = ? WHERE transfer_id = ?', (phase, tid))

    def _send(self, direction, peer, step, body):
        body = dict(body, step=step, group=self.group, sender=self.region, recipient=peer)
        self.db.execute('INSERT OR REPLACE INTO outbox VALUES (?, ?, ?, ?)',
                        (direction, peer, step, json.dumps(body, sort_keys=True)))

    def _settle(self, direction, peer, seq, tid):
        self.db.execute('UPDATE fence SET settled_seq = ? WHERE direction = ? AND peer = ?', (seq, direction, peer))
        self.db.execute('DELETE FROM outbox WHERE direction = ? AND peer = ?', (direction, peer))
        for table in ('active', 'escrow', 'effect'):
            self.db.execute('DELETE FROM %s WHERE transfer_id = ?' % table, (tid,))

    # -- enrollment -----------------------------------------------------

    def enroll(self, peer, direction, epoch=1):
        """Operator step: permit transfers with peer in one direction."""
        if direction not in (OUT, IN):
            raise TransferError('direction must be out or in')
        with self._tx():
            self.db.execute('INSERT OR IGNORE INTO fence VALUES (?, ?, ?, 0)', (direction, peer, epoch))

    # -- world effects (called by DM before it changes the world) --------

    def begin_escrow(self, peer, payloads):
        """Source: record the tentative removal of items, before DM removes them.

        Returns (transfer_id, effect_id). DM removes the items only after this
        returns, and lists effect_id in the next world save.
        """
        if not payloads or any(type(p) is not str for p in payloads):
            raise TransferError('escrow needs a non-empty list of serialized items')
        with self._tx():
            self._require_open()
            epoch, settled = self._fence(OUT, peer)
            if self._active(OUT, peer):
                raise TransferError('a transfer to %s is already in flight' % peer)
            if self.db.execute('SELECT 1 FROM outbox WHERE direction = ? AND peer = ?', (OUT, peer)).fetchone():
                raise TransferError('the previous transfer to %s is not acknowledged yet' % peer)
            seq = settled + 1
            tid = transfer_id(self.group, self.region, peer, epoch, seq)
            manifest = json.dumps({'epoch': epoch, 'seq': seq, 'items': payloads}, sort_keys=True)
            self.db.execute('INSERT INTO active VALUES (?, ?, ?, ?, ?, ?)', (OUT, peer, seq, tid, manifest, REQUESTED))
            for idx, payload in enumerate(payloads):
                self.db.execute('INSERT INTO escrow VALUES (?, ?, ?)', (tid, idx, payload))
            effect_id = tid + ':' + REMOVE
            self.db.execute('INSERT INTO effect VALUES (?, ?, ?, ?)', (effect_id, tid, REMOVE, TENTATIVE))
            return tid, effect_id

    def begin_import(self, tid):
        """Destination: record the tentative credit, before DM creates the items.

        Returns (effect_id, payloads).
        """
        with self._tx():
            self._require_open()
            row = self._active_by_id(tid)
            if row is None or row[0] != IN or row[4] != COMMIT_RECEIVED:
                raise TransferError('transfer is not ready to import')
            effect_id = tid + ':' + CREDIT
            if self.db.execute('SELECT 1 FROM effect WHERE effect_id = ?', (effect_id,)).fetchone():
                raise TransferError('import is already applied and waiting for a world save')
            self.db.execute('INSERT INTO effect VALUES (?, ?, ?, ?)', (effect_id, tid, CREDIT, TENTATIVE))
            return effect_id, json.loads(row[3])['items']

    def begin_return(self, tid):
        """Source, after a destination tombstone: record the tentative return."""
        with self._tx():
            self._require_open()
            row = self._active_by_id(tid)
            if row is None or row[0] != OUT or row[4] != RETURNING:
                raise TransferError('transfer is not ready to return')
            effect_id = tid + ':' + RETURN
            if self.db.execute('SELECT 1 FROM effect WHERE effect_id = ?', (effect_id,)).fetchone():
                raise TransferError('return is already applied and waiting for a world save')
            self.db.execute('INSERT INTO effect VALUES (?, ?, ?, ?)', (effect_id, tid, RETURN, TENTATIVE))
            payloads = [p for (p,) in self.db.execute('SELECT payload FROM escrow WHERE transfer_id = ? ORDER BY idx',
                                                      (tid,))]
            return effect_id, payloads

    def abort(self, tid):
        """Source: give up before the commit decision."""
        with self._tx():
            self._require_open()
            row = self._active_by_id(tid)
            if row is None or row[0] != OUT or row[4] not in (REQUESTED, ESCROWED):
                raise TransferError('only an uncommitted outgoing transfer can be aborted')
            if row[4] == REQUESTED:
                raise TransferError('wait for the world save that confirms the escrow before aborting')
            self._set_phase(tid, ABORT_DECIDED)
            self._send(OUT, row[1], 'ABORT', {'transfer_id': tid, 'seq': row[2]})

    # -- world save and load ----------------------------------------------

    def ledger_seq(self):
        return int(self._meta('ledger_seq'))

    def report_save(self, generation, effect_ids, ledger_seq):
        """After save_complete.txt: confirm the effects that save contains.

        Returns the new ledger sequence for DM to cache.
        """
        with self._tx():
            current = self.ledger_seq()
            if self._meta('hold_reason'):
                raise RegionHeld(self._meta('hold_reason'))
            if generation == self._meta('confirmed_generation'):
                return current
            if ledger_seq > current:
                raise TransferError('save report is ahead of the store (save ledger %s, store ledger %s)'
                                    % (ledger_seq, current))
            # A running world may report with an older base when an earlier
            # report's reply was lost; its effect list then repeats confirmed
            # effects, which _confirm skips.
            self._confirm(effect_ids)
            self._set_meta('ledger_seq', current + 1)
            self._set_meta('confirmed_generation', generation)
            return current + 1

    def reconcile_load(self, generation, effect_ids, ledger_seq):
        """At world load: confirm what the loaded save lists, void the rest.

        Returns the ledger sequence DM must cache. Puts the region on hold when
        the loaded save is older than what the store already confirmed.
        """
        with self._tx():
            current = self.ledger_seq()
            if self._meta('hold_reason'):
                raise RegionHeld(self._meta('hold_reason'))
            if generation == self._meta('confirmed_generation'):
                pass
            elif ledger_seq == current:
                self._confirm(effect_ids)
                current += 1
                self._set_meta('ledger_seq', current)
                self._set_meta('confirmed_generation', generation)
            else:
                self._set_meta('hold_reason', 'rollback: loaded save ledger %s, store ledger %s' % (ledger_seq, current))
                return None
            listed = set(effect_ids)
            for effect_id, tid, kind in list(self.db.execute(
                    'SELECT effect_id, transfer_id, kind FROM effect WHERE state = ?', (TENTATIVE,))):
                if effect_id in listed:
                    continue
                self._void(effect_id, tid, kind)
            return current

    def _confirm(self, effect_ids):
        for effect_id in effect_ids:
            row = self.db.execute('SELECT transfer_id, kind, state FROM effect WHERE effect_id = ?',
                                  (effect_id,)).fetchone()
            if row is None or row[2] == CONFIRMED:
                # Already settled, or confirmed by an earlier report of the same save.
                continue
            tid, kind = row[0], row[1]
            self.db.execute('UPDATE effect SET state = ? WHERE effect_id = ?', (CONFIRMED, effect_id))
            direction, peer, seq, manifest, phase = self._active_by_id(tid)
            if kind == REMOVE:
                self._set_phase(tid, ESCROWED)
                self._send(OUT, peer, 'ESCROW', {'transfer_id': tid, 'seq': seq, 'manifest': json.loads(manifest)})
            elif kind == CREDIT:
                self._set_phase(tid, IMPORTED)
                self._send(IN, peer, 'IMPORTED', {'transfer_id': tid, 'seq': seq})
            elif kind == RETURN:
                self._settle(OUT, peer, seq, tid)
                self._send(OUT, peer, 'FINALIZE', {'transfer_id': tid, 'seq': seq, 'outcome': 'returned'})

    def _void(self, effect_id, tid, kind):
        self.db.execute('DELETE FROM effect WHERE effect_id = ?', (effect_id,))
        if kind == REMOVE:
            # The reloaded world still holds the items and no envelope left the
            # region, so the transfer never happened; its sequence is reused.
            self.db.execute('DELETE FROM escrow WHERE transfer_id = ?', (tid,))
            self.db.execute('DELETE FROM active WHERE transfer_id = ?', (tid,))
        # A voided credit or return leaves the phase as it was, so DM redoes it.

    # -- messages ---------------------------------------------------------

    def outbox(self):
        """Envelopes waiting for delivery (resent until superseded or acknowledged)."""
        return [json.loads(body) for (body,) in self.db.execute('SELECT body FROM outbox ORDER BY direction, peer')]

    def receive(self, envelope):
        """Apply one envelope from a peer. Duplicates and stale steps are harmless.

        Returns a direct ACK envelope or None. ACKs are never stored: a lost ACK
        is regenerated when the peer resends.
        """
        step, peer, tid, seq = envelope['step'], envelope['sender'], envelope['transfer_id'], envelope['seq']
        if envelope.get('group') != self.group or envelope.get('recipient') != self.region:
            raise TransferError('envelope is for another group or region')
        with self._tx():
            self._require_open()
            if step in ('ESCROW', 'COMMIT', 'ABORT', 'FINALIZE'):
                return self._receive_as_destination(step, peer, tid, seq, envelope)
            elif step in ('PREPARE', 'IMPORTED', 'TOMBSTONE', 'ACK'):
                return self._receive_as_source(step, peer, tid, seq)
            else:
                raise TransferError('unknown step %r' % step)

    def _receive_as_destination(self, step, peer, tid, seq, envelope):
        epoch, settled = self._fence(IN, peer)
        if seq <= settled:
            # Settled already: answer without looking anything up.
            return self._ack(peer, tid, seq)
        active = self._active(IN, peer)
        if active is None:
            if step not in ('ESCROW', 'ABORT') or seq != settled + 1:
                raise TransferError('unexpected %s for sequence %s' % (step, seq))
            if tid != transfer_id(self.group, peer, self.region, epoch, seq):
                raise TransferError('transfer id does not match the channel')
            if step == 'ABORT':
                # The escrow never arrived: refuse it for good before the source
                # may return its items.
                self.db.execute('INSERT INTO active VALUES (?, ?, ?, ?, ?, ?)',
                                (IN, peer, seq, tid, '{}', DESTINATION_ABORTED))
                self._send(IN, peer, 'TOMBSTONE', {'transfer_id': tid, 'seq': seq})
                return None
            manifest = envelope['manifest']
            if manifest.get('epoch') != epoch or manifest.get('seq') != seq:
                raise TransferError('manifest does not match the channel')
            self.db.execute('INSERT INTO active VALUES (?, ?, ?, ?, ?, ?)',
                            (IN, peer, seq, tid, json.dumps(manifest, sort_keys=True), PREPARED))
            self._send(IN, peer, 'PREPARE', {'transfer_id': tid, 'seq': seq})
            return
        a_seq, a_tid, _, phase = active
        if a_tid != tid:
            raise TransferError('another transfer is active on this channel')
        if step == 'COMMIT' and phase == PREPARED:
            self._set_phase(tid, COMMIT_RECEIVED)
            self.db.execute('DELETE FROM outbox WHERE direction = ? AND peer = ?', (IN, peer))
        elif step == 'ABORT' and phase == PREPARED:
            self._set_phase(tid, DESTINATION_ABORTED)
            self._send(IN, peer, 'TOMBSTONE', {'transfer_id': tid, 'seq': seq})
        elif step == 'FINALIZE' and phase in (IMPORTED, DESTINATION_ABORTED):
            expected = 'imported' if phase == IMPORTED else 'returned'
            if envelope.get('outcome') != expected:
                raise TransferError('finalize outcome does not match the destination phase')
            self._settle(IN, peer, seq, tid)
            return self._ack(peer, tid, seq)
        elif step == 'ABORT' and phase in (COMMIT_RECEIVED, IMPORTED):
            raise TransferError('abort after commit is refused')
        # Anything else is a retransmission of a step already applied.

    def _ack(self, peer, tid, seq):
        return {'step': 'ACK', 'group': self.group, 'sender': self.region, 'recipient': peer,
                'transfer_id': tid, 'seq': seq}

    def _receive_as_source(self, step, peer, tid, seq):
        epoch, settled = self._fence(OUT, peer)
        if step == 'ACK':
            row = self.db.execute('SELECT body FROM outbox WHERE direction = ? AND peer = ?', (OUT, peer)).fetchone()
            if row and json.loads(row[0])['step'] == 'FINALIZE' and json.loads(row[0])['seq'] == seq and seq <= settled:
                self.db.execute('DELETE FROM outbox WHERE direction = ? AND peer = ?', (OUT, peer))
            return
        if seq <= settled:
            return
        active = self._active(OUT, peer)
        if active is None or active[1] != tid:
            raise TransferError('no matching outgoing transfer')
        phase = active[3]
        if step == 'PREPARE' and phase == ESCROWED:
            self._set_phase(tid, COMMIT_DECIDED)
            self._send(OUT, peer, 'COMMIT', {'transfer_id': tid, 'seq': seq})
        elif step == 'IMPORTED' and phase == COMMIT_DECIDED:
            # Retire the escrow for good and settle the channel.
            self._settle(OUT, peer, seq, tid)
            self._send(OUT, peer, 'FINALIZE', {'transfer_id': tid, 'seq': seq, 'outcome': 'imported'})
        elif step == 'TOMBSTONE' and phase == ABORT_DECIDED:
            self._set_phase(tid, RETURNING)
            self.db.execute('DELETE FROM outbox WHERE direction = ? AND peer = ?', (OUT, peer))
        elif step == 'PREPARE' and phase == ABORT_DECIDED:
            pass  # crossed with our ABORT; the ABORT in the outbox answers it
        elif step == 'IMPORTED' and phase != COMMIT_DECIDED:
            raise TransferError('import evidence without a commit decision')

    # -- inspection ---------------------------------------------------------

    def status(self):
        return {
            'region': self.region,
            'ledger_seq': self.ledger_seq(),
            'confirmed_generation': self._meta('confirmed_generation'),
            'hold_reason': self._meta('hold_reason'),
            'active': [dict(zip(('direction', 'peer', 'seq', 'transfer_id', 'phase'), r)) for r in
                       self.db.execute('SELECT direction, peer, seq, transfer_id, phase FROM active ORDER BY direction, peer')],
            'fences': [dict(zip(('direction', 'peer', 'epoch', 'settled_seq'), r)) for r in
                       self.db.execute('SELECT direction, peer, epoch, settled_seq FROM fence ORDER BY direction, peer')],
            'pending_transfers': [tid for (tid,) in self.db.execute(
                "SELECT transfer_id FROM active WHERE (direction = 'in' AND phase = ?) OR (direction = 'out' AND phase = ?)",
                (COMMIT_RECEIVED, RETURNING))],
        }

    def clear_hold(self, reason):
        """Operator step after a reviewed recovery. Never touches fences."""
        with self._tx():
            if self._meta('hold_reason') != reason:
                raise TransferError('hold reason changed; re-read status first')
            self._set_meta('hold_reason', '')
