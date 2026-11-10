"""Bounded physical-train wire envelope; gameplay codec validates item fields.

This validator establishes graph identity, membership and routing invariants.
It never interprets DM type paths or constructs gameplay objects.
"""
import json
import math
import re

MAX_BYTES = 200000
MAX_SEGMENTS = 64
MAX_ENTITIES = 256
_ID = re.compile(r'^[A-Za-z0-9_.:@-]{1,160}$')
TRAIN_TYPES = {'/obj/structure/trains' + suffix for suffix in
               ('', '/storage', '/storage/miningcart', '/storage/tender', '/storage/closed', '/transport',
                '/transport/flatbed', '/transport/cabin', '/locomotive/coal', '/platform')}
TOP = {'kind', 'version', 'id', 'party', 'source', 'destination', 'station',
       'segments', 'entities', 'accounts'}
SEGMENT = {'id', 'type', 'dir', 'health', 'on', 'fuel', 'car_kind', 'car_id',
           'seg_index', 'open_doors'}
ENTITY = {'id', 'kind', 'segment', 'slot', 'payload', 'dir', 'anchored'}


def _require(ok, reason):
    if not ok:
        raise ValueError('train: ' + reason)


def identifier(value):
    return isinstance(value, str) and _ID.fullmatch(value) is not None


def account_key(value):
    return isinstance(value, str) and re.fullmatch(r'[a-z0-9@]{1,32}', value) is not None


def validate(payload):
    _require(isinstance(payload, str) and len(payload.encode('utf-8')) <= MAX_BYTES,
             'payload exceeds byte limit')
    try:
        m = json.loads(payload, parse_constant=lambda value: (_ for _ in ()).throw(ValueError(value)))
    except (ValueError, RecursionError) as exc:
        raise ValueError('train: invalid JSON') from exc
    _require(type(m) is dict and set(m) == TOP, 'unknown or missing envelope fields')
    _require(m['kind'] == 'train' and type(m['version']) is int and m['version'] == 1, 'unsupported version')
    for field in ('id', 'source', 'destination', 'station'):
        _require(identifier(m[field]), 'invalid ' + field)
    _require(m['source'] != m['destination'], 'source equals destination')
    _require(isinstance(m['party'], str) and 0 < len(m['party']) <= 100, 'invalid party')
    segments, entities, accounts = m['segments'], m['entities'], m['accounts']
    _require(type(segments) is list and 1 <= len(segments) <= MAX_SEGMENTS, 'segment limit')
    _require(type(entities) is list and len(entities) <= MAX_ENTITIES, 'entity limit')
    _require(type(accounts) is list and len(accounts) <= MAX_ENTITIES and all(account_key(a) for a in accounts), 'accounts')
    _require(len(set(accounts)) == len(accounts), 'duplicate account')
    ids = set()
    owners = []
    for s in segments:
        _require(type(s) is dict and set(s) == SEGMENT, 'segment fields')
        _require(identifier(s['id']) and s['id'] not in ids, 'duplicate/invalid segment identity')
        ids.add(s['id'])
        _require(s['type'] in TRAIN_TYPES, 'unsupported segment type')
        _require(type(s['dir']) is int and s['dir'] in (1, 2, 4, 8), 'segment direction')
        for k in ('health', 'fuel'):
            _require(type(s[k]) in (int, float) and math.isfinite(s[k]) and 0 <= s[k] <= 1000000, k)
        _require(type(s['on']) is int and s['on'] in (0, 1), 'engine state')
        _require(isinstance(s['car_kind'], str) and len(s['car_kind']) <= 40, 'car kind')
        _require(isinstance(s['car_id'], str) and len(s['car_id']) <= 160, 'car identity')
        _require(type(s['seg_index']) is int and 0 <= s['seg_index'] <= 4, 'segment index')
        _require(type(s['open_doors']) is int and 0 <= s['open_doors'] <= 255, 'door bits')
    for e in entities:
        _require(type(e) is dict and set(e) == ENTITY, 'entity fields')
        _require(identifier(e['id']) and e['id'] not in ids, 'duplicate/invalid entity identity')
        ids.add(e['id'])
        _require(type(e['segment']) is int and 1 <= e['segment'] <= len(segments), 'entity segment')
        _require(type(e['slot']) is int and e['slot'] in (1, 2, 3), 'entity slot')
        _require(type(e['dir']) is int and e['dir'] in (1, 2, 4, 8), 'entity direction')
        _require(type(e['anchored']) is int and e['anchored'] in (0, 1), 'entity anchor')
        _require(e['kind'] in ('character', 'item', 'crate', 'fitting'), 'entity kind')
        if e['kind'] == 'character':
            _require(isinstance(e['payload'], str), 'character encoding')
            try:
                person = json.loads(e['payload'])
            except (ValueError, RecursionError) as exc:
                raise ValueError('train: invalid character JSON') from exc
            _require(type(person) is dict and person.get('kind') == 'character' and account_key(person.get('owner')), 'character owner')
            owners.append(person['owner'])
        else:
            _require(type(e['payload']) in (dict, list), 'cargo encoding')
    _require(len(owners) == len(set(owners)) and set(owners) == set(accounts), 'account manifest mismatch')
    return m
