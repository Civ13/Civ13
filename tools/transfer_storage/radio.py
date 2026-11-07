"""Ephemeral cross-region radio relay for one region's agent.

A world with an operational relay station posts each radio message it hears to
its agent (``send``); the coordinator collects them (``outbox``) and hands them
to every other region's agent (``deliver``); that world polls them (``inbox``)
and rebroadcasts them through its own relays. Nothing here touches the SQLite
ledger: a chat line needs no custody, no save confirmation and no replay, so a
crash or a restart simply loses what was in flight.

Relay heartbeats travel the same way, so a world can tell whether a peer has a
matching, working relay before anyone talks into the void.
"""
import re
import time
import uuid
from collections import deque

RING = 200                 # envelopes kept per direction
TTL = 30.0                 # seconds an envelope stays deliverable
HEARTBEAT_TTL = 150.0      # seconds a peer relay counts as linked after its last heartbeat
MAX_MESSAGE = 256
MAX_NAME = 64
MAX_TEXT = 32              # language, verb, relay name, frequency as text
MAX_BATCH = 50             # envelopes per send_batch call (the world queues at most 50)
KEY = re.compile(r'^[a-z0-9_-]{1,16}$')
ID = re.compile(r'^[a-z0-9_-]{1,32}$')


class RadioError(ValueError):
    pass


def _text(value, limit, name):
    if not isinstance(value, str) or not value or len(value) > limit:
        raise RadioError('%s must be 1 to %d characters' % (name, limit))
    return value


def _frequency(value):
    if isinstance(value, bool):
        raise RadioError('frequency must be a number or a channel name')
    if isinstance(value, (int, float)):
        if value != int(value) or not 150 <= value <= 300:
            raise RadioError('frequency must be a whole number from 150 to 300')
        return int(value)
    return _text(value, MAX_TEXT, 'frequency')


def _condition(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not 0 <= value <= 100:
        raise RadioError('condition must be 0 to 100')
    return int(value)


class RadioRelay:
    def __init__(self, region, group, clock=time.monotonic):
        if not ID.match(region or '') or not ID.match(group or ''):
            raise RadioError('region and group ids are 1 to 32 of a-z, 0-9, - and _')
        self.region = region
        self.group = group
        self.clock = clock
        self._outbox = deque(maxlen=RING)
        self._inbox = deque(maxlen=RING)
        self._seen = deque(maxlen=RING * 4)
        self.local = {}            # key -> {'condition': n, 'at': clock}
        self.peers = {}            # region -> {key -> {'condition': n, 'at': clock}}
        self.dropped = 0

    # -- what the world reports ---------------------------------------------

    def send(self, envelope):
        """Record a message heard by an operational relay here. Returns its id."""
        if type(envelope) is not dict:
            raise RadioError('envelope must be an object')
        message = _text(envelope.get('message'), MAX_MESSAGE, 'message')
        key = _text(envelope.get('key'), 16, 'key')
        if not KEY.match(key):
            raise RadioError('key must be 1 to 16 of a-z, 0-9, - and _')
        clean = {
            'id': uuid.uuid4().hex,
            'group': self.group,
            'source': self.region,
            'key': key,
            'frequency': _frequency(envelope.get('frequency')),
            'name': _text(envelope.get('name'), MAX_NAME, 'name'),
            'message': message,
            'language': _text(envelope.get('language') or '-', MAX_TEXT, 'language'),
            'verb': _text(envelope.get('verb') or 'says', MAX_TEXT, 'verb'),
            'relay': _text(envelope.get('relay') or 'relay', MAX_TEXT, 'relay'),
            'condition': _condition(envelope.get('condition', 100)),
            # For the far world's log only; never shown to players.
            'ckey': _text(envelope.get('ckey') or '-', MAX_NAME, 'ckey'),
            'at': self.clock(),
        }
        self._outbox.append(clean)
        return clean['id']

    def send_batch(self, envelopes):
        """Record several messages in one call. Each envelope is checked on its own,
        so one bad envelope does not drop the rest. Returns the ids in order, with
        None where an envelope was refused, and the refusals by index."""
        if not isinstance(envelopes, list) or len(envelopes) > MAX_BATCH:
            raise RadioError('envelopes must be a list of at most %d entries' % MAX_BATCH)
        ids, errors = [], []
        for index, envelope in enumerate(envelopes):
            try:
                ids.append(self.send(envelope))
            except RadioError as error:
                ids.append(None)
                errors.append({'index': index, 'error': str(error)})
        return {'ids': ids, 'errors': errors}

    def heartbeat(self, relays):
        """The world's operational relays: a list of {key, condition}."""
        if not isinstance(relays, list) or len(relays) > 128:
            raise RadioError('relays must be a list of at most 128 entries')
        now = self.clock()
        fresh = {}
        for entry in relays:
            if type(entry) is not dict:
                raise RadioError('each relay is an object')
            key = _text(entry.get('key'), 16, 'key')
            if not KEY.match(key):
                raise RadioError('key must be 1 to 16 of a-z, 0-9, - and _')
            condition = _condition(entry.get('condition', 100))
            if key not in fresh or fresh[key]['condition'] < condition:
                fresh[key] = {'condition': condition, 'at': now}
        self.local = fresh
        return len(fresh)

    def inbox(self):
        """Messages from peers, oldest first, each handed out once."""
        self._expire()
        due = list(self._inbox)
        self._inbox.clear()
        return [self._public(e) for e in due]

    def status(self):
        """What the world shows on a relay: every peer's matching relays and their age."""
        now = self.clock()
        peers = {}
        for region, relays in self.peers.items():
            view = {}
            for key, info in relays.items():
                age = now - info['at']
                if age <= HEARTBEAT_TTL:
                    view[key] = {'condition': info['condition'], 'age': int(age)}
            peers[region] = view
        return {'region': self.region, 'local': sorted(self.local), 'peers': peers,
                'queued_out': len(self._outbox), 'queued_in': len(self._inbox), 'dropped': self.dropped}

    # -- what the coordinator moves -----------------------------------------

    def outbox(self):
        """Envelopes to fan out and this region's live heartbeats; the envelopes leave the ring."""
        self._expire()
        due = list(self._outbox)
        self._outbox.clear()
        now = self.clock()
        heartbeats = {key: {'condition': info['condition'], 'age': int(now - info['at'])}
                      for key, info in self.local.items() if now - info['at'] <= HEARTBEAT_TTL}
        return {'envelopes': [dict(e, age=round(now - e['at'], 2)) for e in due], 'heartbeats': heartbeats}

    def deliver(self, envelopes, heartbeats=None):
        """Accept envelopes from other regions and their heartbeat tables. Returns how many were queued."""
        now = self.clock()
        if heartbeats is not None:
            if type(heartbeats) is not dict:
                raise RadioError('heartbeats must be an object keyed by region')
            for region, relays in heartbeats.items():
                if not ID.match(region) or region == self.region or type(relays) is not dict:
                    continue
                table = {}
                for key, info in relays.items():
                    if KEY.match(key) and type(info) is dict:
                        try:
                            age = float(info.get('age', 0))
                            table[key] = {'condition': _condition(info.get('condition', 100)), 'at': now - max(0.0, age)}
                        except (RadioError, TypeError, ValueError):
                            continue
                self.peers[region] = table
        if not isinstance(envelopes, list):
            raise RadioError('envelopes must be a list')
        queued = 0
        for envelope in envelopes:
            if type(envelope) is not dict or envelope.get('group') != self.group:
                self.dropped += 1
                continue
            source = envelope.get('source')
            ident = envelope.get('id')
            if not isinstance(ident, str) or not ID.match(ident) or ident in self._seen:
                self.dropped += 1
                continue
            if not ID.match(source or '') or source == self.region:
                self.dropped += 1
                continue
            try:
                age = float(envelope.get('age', 0))
                clean = {
                    'id': ident, 'group': self.group, 'source': source,
                    'key': _text(envelope.get('key'), 16, 'key'),
                    'frequency': _frequency(envelope.get('frequency')),
                    'name': _text(envelope.get('name'), MAX_NAME, 'name'),
                    'message': _text(envelope.get('message'), MAX_MESSAGE, 'message'),
                    'language': _text(envelope.get('language') or '-', MAX_TEXT, 'language'),
                    'verb': _text(envelope.get('verb') or 'says', MAX_TEXT, 'verb'),
                    'relay': _text(envelope.get('relay') or 'relay', MAX_TEXT, 'relay'),
                    'condition': _condition(envelope.get('condition', 100)),
                    'ckey': _text(envelope.get('ckey') or '-', MAX_NAME, 'ckey'),
                    'at': now - max(0.0, age),
                }
            except (RadioError, TypeError, ValueError):
                self.dropped += 1
                continue
            if not KEY.match(clean['key']) or now - clean['at'] > TTL:
                self.dropped += 1
                continue
            self._seen.append(ident)
            self._inbox.append(clean)
            queued += 1
        return queued

    # -- internals -----------------------------------------------------------

    def _expire(self):
        now = self.clock()
        for ring in (self._outbox, self._inbox):
            while ring and now - ring[0]['at'] > TTL:
                ring.popleft()
                self.dropped += 1

    @staticmethod
    def _public(envelope):
        public = dict(envelope)
        del public['at']
        return public
