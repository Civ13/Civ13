"""Atomic account leases for physical train envelopes relayed by the coordinator.

The persisted decision is part of recovery state. It must not be discarded while
any physical-train transaction is in flight. Worlds enforce the lock snapshots
and their own local active-train locks before granting account control.
"""
import hashlib
import json
import secrets
from tools.transfer_storage.train_lease import lease_text, lease_request, lease_binding, lease_hash
from tools.transfer_storage.train import validate


class TrainCustody:
    def init_train_custody(self):
        self.db.execute("INSERT OR IGNORE INTO ledger VALUES ('group', ?)", (self.group,))
        if self._ledger('group') != self.group:
            raise ValueError('coordinator ledger belongs to another group')
        self.db.execute('''CREATE TABLE IF NOT EXISTS train_prelease(
            journey TEXT PRIMARY KEY, request TEXT NOT NULL, token TEXT NOT NULL,
            state TEXT NOT NULL, reason TEXT NOT NULL, transfer_id TEXT NOT NULL)''')
        self.db.execute('''CREATE TABLE IF NOT EXISTS train_custody(
            tid TEXT PRIMARY KEY, source TEXT NOT NULL, destination TEXT NOT NULL,
            digest TEXT NOT NULL, accounts TEXT NOT NULL, state TEXT NOT NULL)''')
        self.db.execute('''CREATE TABLE IF NOT EXISTS train_account_lock(
            ckey TEXT PRIMARY KEY, tid TEXT NOT NULL)''')
        self.db.execute('''CREATE TABLE IF NOT EXISTS train_account_fence(
            ckey TEXT PRIMARY KEY, rev INTEGER NOT NULL)''')

    def decide_train_lease(self, source, item):
        """Inside homes_once's transaction: reserve or cancel all members together."""
        if self._ledger('recovery') != 'ready':
            raise ValueError('train custody recovery is not reconciled')
        request = lease_request(item['request'])
        text = lease_text(request)
        journey = request['journey']
        if request['source'] != source or item.get('op') not in ('reserve', 'cancel'):
            raise ValueError('train prelease request origin mismatch')
        row = self.db.execute('SELECT request,token,state,reason,transfer_id FROM train_prelease WHERE journey=?', (journey,)).fetchone()
        if row and row[0] != text:
            raise ValueError('train journey lease binding changed')
        if not row:
            reason = ''
            if request['destination'] not in self.regions():
                reason = 'destination is not enrolled'
            for owner in request['accounts']:
                if self.home(owner) != source:
                    reason = 'passenger home is not the source'
                if self.db.execute('SELECT 1 FROM train_account_lock WHERE ckey=?', (owner,)).fetchone():
                    reason = 'passenger is already leased'
            state = 'rejected' if reason else 'granted'
            token = secrets.token_hex(32) if state == 'granted' else ''
            self.db.execute('INSERT INTO train_prelease VALUES (?,?,?,?,?,?)', (journey, text, token, state, reason, ''))
            if state == 'granted':
                for owner in request['accounts']:
                    self.db.execute('INSERT INTO train_account_lock VALUES (?,?)', (owner, 'lease:' + journey))
            row = text, token, state, reason, ''
        if item['op'] == 'cancel' and row[2] in ('granted', 'rejected'):
            for owner in request['accounts']:
                # Do not change any newer home while releasing the old request.
                self._set_home(owner, self.home(owner))
                self.db.execute('INSERT OR REPLACE INTO train_account_fence VALUES (?,?)', (owner, int(self._ledger('rev'))))
            self.db.execute('DELETE FROM train_account_lock WHERE tid=?', ('lease:' + journey,))
            self.db.execute("UPDATE train_prelease SET state='cancelled',reason='' WHERE journey=?", (journey,))
            row = row[0], row[1], 'cancelled', '', row[4]
        return {'journey': journey, 'request_hash': lease_hash(text), 'token': row[1],
                'state': row[2], 'reason': row[3], 'epoch': self._ledger('epoch'), 'transfer_id': row[4]}

    def train_locks(self):
        return [c for (c,) in self.db.execute('SELECT ckey FROM train_account_lock ORDER BY ckey')]

    def train_request_allowed(self, request):
        owner = request['ckey']
        if self.db.execute('SELECT 1 FROM train_account_lock WHERE ckey = ?', (owner,)).fetchone():
            return False
        fence = self.db.execute('SELECT rev FROM train_account_fence WHERE ckey = ?', (owner,)).fetchone()
        if fence and (request.get('homes_epoch') != self._ledger('epoch') or
                      type(request.get('home_rev')) is not int or request['home_rev'] < fence[0]):
            return False
        return True

    def train_envelope(self, sender, envelope):
        """Check/advance a train custody decision before forwarding its envelope.

        Non-train messages are unchanged. The caller authenticates sender via
        its enrolled agent and requires envelope.sender == sender.
        """
        tid, step = envelope.get('transfer_id'), envelope.get('step')
        record = self.db.execute('SELECT source,destination,digest,accounts,state FROM train_custody WHERE tid = ?',
                                 (tid,)).fetchone()
        manifest = envelope.get('manifest', {})
        items = manifest.get('items', []) if isinstance(manifest, dict) else []
        train = None
        if 'train_manifest' in envelope and step == 'ESCROW' and items != [envelope['train_manifest']]:
            raise ValueError('train escrow marker does not match payload')
        if 'train_manifest' in envelope:
            items = [envelope['train_manifest']]
            train = validate(items[0])
        if step == 'ESCROW':
            decoded = []
            for item in items if isinstance(items, list) else []:
                try:
                    decoded.append(json.loads(item))
                except (ValueError, TypeError):
                    pass
            if any(type(p) is dict and p.get('kind') == 'train' for p in decoded):
                if len(items) != 1:
                    raise ValueError('train custody requires one manifest')
                train = validate(items[0])
        if train is None and record is None:
            # COMMIT cannot identify a train on its own. The region will only
            # admit a train if its persistent coordinator custody witness exists.
            return False
        if envelope.get('group') != self.group or not isinstance(tid, str) or len(tid) != 64:
            raise ValueError('train custody envelope identity mismatch')
        if self._ledger('recovery') != 'ready':
            raise ValueError('coordinator custody recovery is not reconciled')
        self.db.execute('BEGIN IMMEDIATE')
        try:
            if train is not None:
                source, destination = train['source'], train['destination']
                if step in ('ESCROW', 'COMMIT', 'ABORT', 'FINALIZE') and (sender != source or envelope.get('recipient') != destination):
                    raise ValueError('train custody route mismatch')
                prelease = self.db.execute('SELECT request,token,state,reason,transfer_id FROM train_prelease WHERE journey=?',
                                           (train['journey'],)).fetchone()
                if not prelease or prelease[0] != lease_text(lease_binding(train)):
                    raise ValueError('train has no matching prelease')
                if step in ('ESCROW', 'ABORT') and (not envelope.get('train_lease') or envelope['train_lease'] != prelease[1]):
                    raise ValueError('train prelease token mismatch')
                if prelease[2] not in ('granted', 'sealed') or (prelease[4] and prelease[4] != tid):
                    raise ValueError('train prelease is cancelled or already used')
                digest = hashlib.sha256(items[0].encode()).hexdigest()
                accounts = json.dumps(sorted(train['accounts']))
                if record:
                    if record[:4] != (source, destination, digest, accounts):
                        raise ValueError('train custody manifest changed')
                else:
                    if step not in ('ESCROW', 'ABORT'):
                        raise ValueError('missing durable train custody decision')
                    if step == 'ABORT':
                        self.db.execute("UPDATE train_prelease SET state='sealed',transfer_id=? WHERE journey=?", (tid, train['journey']))
                        self.db.execute('DELETE FROM train_account_lock WHERE tid=?', ('lease:' + train['journey'],))
                        self.db.execute('INSERT INTO train_custody VALUES (?,?,?,?,?,?)',
                                        (tid, source, destination, digest, accounts, 'aborted'))
                        # Fence stale requests without claiming ownership: a
                        # newer legitimate home may already exist elsewhere.
                        for owner in train['accounts']:
                            self._set_home(owner, self.home(owner))
                            self.db.execute('INSERT OR REPLACE INTO train_account_fence VALUES (?,?)',
                                            (owner, int(self._ledger('rev'))))
                        self.db.execute('COMMIT')
                        return True
                    for owner in train['accounts']:
                        if self.home(owner) != source:
                            raise ValueError('train passenger home is not the source')
                        if self.db.execute('SELECT tid FROM train_account_lock WHERE ckey = ?', (owner,)).fetchone() != ('lease:' + train['journey'],):
                            raise ValueError('train passenger lease is missing or changed')
                    self.db.execute("UPDATE train_prelease SET state='sealed',transfer_id=? WHERE journey=?", (tid, train['journey']))
                    self.db.execute('INSERT INTO train_custody VALUES (?,?,?,?,?,?)',
                                    (tid, source, destination, digest, accounts, 'reserved'))
                    for owner in train['accounts']:
                        self.db.execute('UPDATE train_account_lock SET tid=? WHERE ckey=?', (tid, owner))
                    record = source, destination, digest, accounts, 'reserved'
            source, destination, _, accounts, state = record
            expected = source if step in ('ESCROW', 'COMMIT', 'ABORT', 'FINALIZE') else destination
            if sender != expected or envelope.get('recipient') != (destination if sender == source else source):
                raise ValueError('train custody sender mismatch')
            next_state = state
            if step == 'COMMIT':
                if state not in ('reserved', 'committed', 'imported'):
                    raise ValueError('train commit after abort')
                if state == 'reserved':
                    for owner in json.loads(accounts):
                        if self.home(owner) != source:
                            raise ValueError('train source home changed during lease')
                        self._set_home(owner, destination)
                    next_state = 'committed'
            elif step == 'TOMBSTONE':
                if state not in ('reserved', 'aborted'):
                    raise ValueError('train abort after commit')
                next_state = 'aborted'
            elif step == 'IMPORTED':
                if state not in ('committed', 'imported'):
                    raise ValueError('train import without commit')
                next_state = 'imported'
            if next_state in ('aborted', 'imported'):
                # Advance a fence even on abort, where the home did not change.
                # Old delayed account requests cannot override the decision.
                if next_state != state:
                    for owner in json.loads(accounts):
                        self._set_home(owner, destination if next_state == 'imported' else source)
                        self.db.execute('INSERT OR REPLACE INTO train_account_fence VALUES (?,?)',
                                        (owner, int(self._ledger('rev'))))
                self.db.execute('DELETE FROM train_account_lock WHERE tid = ?', (tid,))
            self.db.execute('UPDATE train_custody SET state = ? WHERE tid = ?', (next_state, tid))
            self.db.execute('COMMIT')
        except Exception:
            self.db.execute('ROLLBACK')
            raise
        return True
