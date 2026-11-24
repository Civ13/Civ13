"""Bounded, ephemeral mailbox for read-only gateway directory queries."""
import re
import secrets
import time

from tools.transfer_storage.region import TransferError

OWNER_KEY = re.compile(r'(?:@[234])?[a-z0-9]{1,32}')
PARKED_HOME = re.compile(r'land:(0|[1-9][0-9]{0,2}),(0|[1-9][0-9]{0,2})')
REQUEST_LIFETIME = 15
RESULT_LIFETIME = 5
MAX_PENDING = 32


class LobbyMailbox:
    def __init__(self, store, clock=time.monotonic):
        self.store = store
        self.clock = clock
        self.entries = {}

    def prune(self):
        now = self.clock()
        for key, entry in list(self.entries.items()):
            if now >= entry['expires']:
                del self.entries[key]

    def ask(self, key):
        if not isinstance(key, str) or not OWNER_KEY.fullmatch(key):
            raise TransferError('bad owner key')
        self.store._require_open()
        self.prune()
        entry = self.entries.get(key)
        if entry is not None and 'answer' in entry:
            del self.entries[key]  # no cached replay across a later handoff
            return self._current(key, entry['answer'])
        if entry is None:
            if len(self.entries) >= MAX_PENDING:
                return {'state': 'UNAVAILABLE'}
            self.entries[key] = {'id': secrets.token_hex(16), 'expires': self.clock() + REQUEST_LIFETIME}
        return {'state': 'PENDING'}

    def pending(self):
        self.prune()
        return {'requests': [{'owner': key, 'id': row['id']} for key, row in self.entries.items()
                             if 'answer' not in row][:1]}

    def publish(self, key, request_id, answer):
        self.prune()
        entry = self.entries.get(key)
        if entry is None or entry['id'] != request_id or 'answer' in entry:
            return {'accepted': False}
        entry.update(answer=self._current(key, answer), expires=min(entry['expires'], self.clock() + RESULT_LIFETIME))
        return {'accepted': True}

    def _current(self, key, answer):
        if type(answer) is not dict:
            return {'state': 'UNAVAILABLE'}
        state = answer.get('state')
        if state in ('PENDING', 'TRAVELLING', 'UNAVAILABLE'):
            return {'state': state}  # refuse without leaking a destination
        epoch, rev = answer.get('epoch'), answer.get('rev')
        region = answer.get('region')
        home = answer.get('home')
        if state == 'PARKED':
            if not isinstance(home, str) or not PARKED_HOME.fullmatch(home) or region is not None:
                return {'state': 'UNAVAILABLE'}
        elif state not in ('HOME', 'NO_HOME') or not isinstance(region, str) or not region or region == self.store.region:
            return {'state': 'UNAVAILABLE'}
        local = self.store.lobby_account_status(key)
        if not epoch or epoch != local['epoch'] or type(rev) is not int or rev != local['rev']:
            return {'state': 'UNAVAILABLE'}
        if local['state'] != 'CLEAR':
            return {'state': local['state']}
        route = {'home': home} if state == 'PARKED' else {'region': region}
        return dict(route, state=state, epoch=epoch, rev=rev)
