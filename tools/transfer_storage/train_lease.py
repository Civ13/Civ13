"""Durable source-side train prelease queue over the existing homes channel."""
import hashlib
import json
from tools.transfer_storage.train import identifier, account_key

LEASE_FIELDS = {'id', 'journey', 'source', 'destination', 'party', 'station', 'accounts'}
ACTIVE_LEASES = ('pending', 'granted', 'cancel_pending', 'sealed')


def lease_request(value):
    if type(value) is not dict or set(value) != LEASE_FIELDS:
        raise ValueError('invalid train lease fields')
    for key in ('id', 'journey', 'source', 'destination', 'station'):
        if not identifier(value[key]):
            raise ValueError('invalid train lease ' + key)
    if value['source'] == value['destination'] or not isinstance(value['party'], str) or not 0 < len(value['party']) <= 100:
        raise ValueError('invalid train lease route/party')
    owners = value['accounts']
    if type(owners) is not list or len(owners) > 256 or not all(account_key(k) for k in owners) or len(set(owners)) != len(owners):
        raise ValueError('invalid train lease accounts')
    return dict(value, accounts=sorted(owners))


def lease_text(value):
    return json.dumps(lease_request(value), sort_keys=True, separators=(',', ':'))


def lease_binding(manifest):
    return {k: manifest[k] for k in LEASE_FIELDS}


def lease_hash(text):
    return hashlib.sha256(text.encode('utf-8')).hexdigest()


class TrainLeaseQueue:
    def init_train_leases(self):
        self.db.execute('''CREATE TABLE IF NOT EXISTS train_lease(
            journey TEXT PRIMARY KEY, request TEXT NOT NULL, state TEXT NOT NULL,
            token TEXT NOT NULL, epoch TEXT NOT NULL, reason TEXT NOT NULL, transfer_id TEXT NOT NULL)''')

    def _lease(self, journey):
        row = self.db.execute('SELECT request,state,token,epoch,reason,transfer_id FROM train_lease WHERE journey=?', (journey,)).fetchone()
        if row is None:
            raise ValueError('unknown train lease journey')
        return row

    def train_lease_status(self, journey):
        request, state, token, epoch, reason, tid = self._lease(journey)
        return {'journey': journey, 'state': state, 'token': token, 'epoch': epoch,
                'reason': reason, 'request_hash': lease_hash(request), 'transfer_id': tid}

    def reserve_train(self, request):
        request = lease_request(request)
        if request['source'] != self.region:
            raise ValueError('train lease source mismatch')
        text = lease_text(request)
        with self._tx():
            self._require_open()
            self._fence('out', request['destination'])
            prior = self.db.execute('SELECT request FROM train_lease WHERE journey=?', (request['journey'],)).fetchone()
            if prior:
                if prior[0] != text:
                    raise ValueError('train journey already has different lease identity')
            else:
                for (other,) in self.db.execute("SELECT request FROM train_lease WHERE state IN ('pending','granted','cancel_pending','sealed')"):
                    bound = json.loads(other)
                    if bound['id'] == request['id'] or set(bound['accounts']) & set(request['accounts']):
                        raise ValueError('train or account already has a lease request')
                self.db.execute('INSERT INTO train_lease VALUES (?,?,?,?,?,?,?)',
                                (request['journey'], text, 'pending', '', '', '', ''))
                self._set_meta('train_history', '1')
        return self.train_lease_status(request['journey'])

    def cancel_train_lease(self, journey):
        with self._tx():
            self._require_open()
            row = self._lease(journey)
            if row[1] in ('sealed', 'settled'):
                raise ValueError('sealed train lease requires transfer abort/recovery')
            if row[1] in ('pending', 'granted', 'cancel_pending'):
                self.db.execute("UPDATE train_lease SET state='cancel_pending' WHERE journey=?", (journey,))
        return self.train_lease_status(journey)

    def train_lease_requests(self):
        return [{'request': json.loads(request), 'op': 'cancel' if state == 'cancel_pending' else 'reserve'}
                for request, state in self.db.execute("SELECT request,state FROM train_lease WHERE state IN ('pending','granted','cancel_pending','sealed')")]

    def apply_train_lease_decisions(self, epoch, decisions):
        # Called inside the enclosing atomic homes snapshot transaction.
        if not isinstance(decisions, list):
            raise ValueError('invalid train lease decisions')
        for decision in decisions:
            journey = decision['journey']
            request, state, token, old_epoch, _, tid = self._lease(journey)
            if decision.get('request_hash') != lease_hash(request) or decision.get('epoch') != epoch:
                raise ValueError('train lease decision binding mismatch')
            new_state = decision.get('state')
            if new_state not in ('granted', 'sealed', 'cancelled', 'rejected'):
                raise ValueError('unknown train lease decision')
            new_token = decision.get('token', '')
            if new_state in ('granted', 'sealed') and (not isinstance(new_token, str) or len(new_token) != 64):
                raise ValueError('invalid train lease token')
            if old_epoch and old_epoch != epoch:
                raise ValueError('train lease coordinator epoch changed')
            if token and token != new_token:
                raise ValueError('train lease token changed')
            if state in ('sealed', 'settled'):
                if new_state not in ('sealed',):
                    raise ValueError('sealed train lease cannot be cancelled')
                continue
            # A late grant cannot discard a locally requested cancellation.
            if state == 'cancel_pending' and new_state == 'granted':
                new_state = 'cancel_pending'
            self.db.execute('UPDATE train_lease SET state=?,token=?,epoch=?,reason=? WHERE journey=?',
                            (new_state, new_token, epoch, str(decision.get('reason', ''))[:300], journey))

    def require_train_lease(self, train, token):
        row = self._lease(train['journey'])
        if row[0] != lease_text(lease_binding(train)) or row[1] != 'granted' or not token or token != row[2]:
            raise ValueError('train escrow requires matching granted prelease')
        if row[3] != self._meta('homes_epoch'):
            raise ValueError('train lease epoch is not synchronized')
        return row
