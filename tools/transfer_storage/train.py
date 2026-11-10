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
_ID = re.compile(r'^[A-Za-z0-9_.:@-]{1,100}$')
TRAIN_TYPES = {'/obj/structure/trains' + suffix for suffix in
               ('', '/storage', '/storage/miningcart', '/storage/tender', '/storage/closed', '/transport',
                '/transport/flatbed', '/transport/cabin', '/locomotive', '/locomotive/coal', '/platform')}
TOP = {'kind', 'version', 'id', 'journey', 'party', 'source', 'destination', 'station',
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
    for field in ('id', 'journey', 'source', 'destination', 'station'):
        _require(identifier(m[field]), 'invalid ' + field)
    _require(m['source'] != m['destination'], 'source equals destination')
    party = m['party']
    valid_party = isinstance(party, str) and 0 < len(party) <= 100
    if valid_party:
        parts = party.split(':', 2)
        valid_party = (party.startswith('ckey:') and account_key(party[5:])) or (
            len(parts) == 3 and parts[0] == 'civ' and bool(parts[1]) and bool(parts[2]))
    _require(valid_party, 'invalid party')
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
        _require(isinstance(s['type'], str) and s['type'] in TRAIN_TYPES, 'unsupported segment type')
        _require(type(s['dir']) is int and s['dir'] in (1, 2, 4, 8), 'segment direction')
        for k, low, high in (('health', 1, 1500), ('fuel', 0, 100)):
            _require(type(s[k]) in (int, float) and math.isfinite(s[k]) and s[k] == int(s[k]) and low <= s[k] <= high, k)
        _require(type(s['on']) is int and s['on'] in (0, 1), 'engine state')
        _require(isinstance(s['car_kind'], str) and len(s['car_kind']) <= 40, 'car kind')
        _require(isinstance(s['car_id'], str) and len(s['car_id']) <= 160, 'car identity')
        _require(type(s['seg_index']) is int and 0 <= s['seg_index'] <= 4, 'segment index')
        _require(type(s['open_doors']) is int and 0 <= s['open_doors'] <= 65535, 'door bits')
        if s['type'] == '/obj/structure/trains/platform':
            _require(s['car_kind'] in ('flatbed', 'coach', 'sleeper', 'dining', 'storage', 'railgun', 'armored', 'flak')
                     and 0 < len(s['car_id']) <= 100 and 1 <= s['seg_index'] <= 4, 'platform layout')
        else:
            _require(s['car_kind'] == s['car_id'] == '' and s['seg_index'] == s['open_doors'] == 0,
                     'nonplatform layout fields')
    i = 0
    while i < len(segments):
        first = segments[i]
        if first['type'] != '/obj/structure/trains/platform':
            i += 1
            continue
        _require(i + 4 <= len(segments), 'incomplete platform car')
        for j, part in enumerate(segments[i:i + 4], 1):
            _require(part['type'] == first['type'] and part['seg_index'] == j
                     and part['car_id'] == first['car_id'] and part['car_kind'] == first['car_kind'],
                     'inconsistent platform car')
        i += 4
    for e in entities:
        _require(type(e) is dict and set(e) == ENTITY, 'entity fields')
        _require(identifier(e['id']) and e['id'] not in ids, 'duplicate/invalid entity identity')
        ids.add(e['id'])
        _require(type(e['segment']) is int and 1 <= e['segment'] <= len(segments), 'entity segment')
        _require(type(e['slot']) is int and e['slot'] in (1, 2, 3), 'entity slot')
        _require(segments[e['segment'] - 1]['type'] == '/obj/structure/trains/platform' or e['slot'] == 2,
                 'nonplatform side load')
        _require(type(e['dir']) is int and e['dir'] in (1, 2, 4, 8), 'entity direction')
        _require(type(e['anchored']) is int and e['anchored'] in (0, 1), 'entity anchor')
        _require(e['kind'] in ('character', 'item', 'crate', 'fitting'), 'entity kind')
        if e['kind'] == 'character':
            _require(isinstance(e['payload'], str), 'character encoding')
            try:
                person = json.loads(e['payload'])
            except (ValueError, RecursionError) as exc:
                raise ValueError('train: invalid character JSON') from exc
            _require(type(person) is dict and person.get('kind') == 'character' and account_key(person.get('owner')) and person.get('party') == m['party'], 'character owner/party')
            owners.append(person['owner'])
        else:
            _require(type(e['payload']) is dict, 'cargo encoding')
            cargo = e['payload']
            if e['kind'] == 'crate':
                _require(cargo.get('type') == '/obj/structure/closet/crate'
                         and type(cargo.get('items')) is list and len(cargo['items']) <= 60,
                         'crate schema')
            if e['kind'] == 'fitting':
                _require(cargo.get('type') in ('/obj/structure/bed', '/obj/structure/bed/chair/comfy/blue',
                         '/obj/structure/bed/chair/comfy/diner_booth', '/obj/structure/table/modern/table'),
                         'fitting type')
    _require(len(owners) == len(set(owners)) and set(owners) == set(accounts), 'account manifest mismatch')
    return m
