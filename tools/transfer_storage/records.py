"""Shared player records: staff records about an account, the same on every region.

Admin notes, warnings, bans, watch flags, memos and later karma and lifetime
points are records about one ckey. A world makes each record with an id of its
own (32 hex characters) and hands it to its region agent (/record); the agent
keeps it in its own SQLite store until the coordinator collects it
(/records/outbox, /records/ack). Only the coordinator writes the group table,
so no two processes ever write one file, and a record sent twice is stored
once (the id is the key).

Records are never edited in place. Removing a note or lifting a ban appends a
"revoke" record naming the target id, so two admins acting at once on two
regions cannot overwrite each other.

After each pass the coordinator writes read-only snapshot files that every
world reads, like the shared admins file:

    <group root>/shared-records/index.json            per-ckey summary, account map, pull times
    <group root>/shared-records/bans.json             every active ban
    <group root>/shared-records/connections.json      every ckey, IP and computer id seen together (alt lookups)
    <group root>/shared-records/players/<k>/<ckey>.json   every record about one ckey

Each file is written to a temporary name in the same folder and renamed, so a
world never reads half a file. Other features may keep their own folders beside
these (karma/ belongs to the karma ledger); this module never touches them.

Playtime comes from the host's player activity database (tools/player_activity):
only minutes when the player was connected and their character alive and awake.
"""
import json
import os
import re
import sqlite3
import time

RECORD_ID = re.compile(r'^[0-9a-f]{32}$')
KIND = re.compile(r'^[a-z][a-z0-9_]{0,31}$')
CKEY = re.compile(r'^[a-z0-9@]{1,32}$')
REGION = re.compile(r'^[a-z0-9_-]{1,64}$')
MAX_BODY = 16 * 1024
MAX_RANK = 64
BAN_SCOPES = ('game', 'play', 'ooc', 'job')  # game: a server ban; play: may watch, not play
OUTBOX_BATCH = 200
SNAPSHOT_SECONDS = 60  # the index is rewritten at least this often (playtime, expired bans)
RECORDS_DIR = 'shared-records'
INDEX_VERSION = 1


class RecordError(ValueError):
    """A record the store refuses. Nothing was changed."""


def unix_int(value):
    """A unix time as DM sends it: a digit string (DM numbers are 32-bit
    floats, too coarse for seconds), or an int. None when it is neither."""
    if isinstance(value, str) and value.isdigit() and len(value) <= 12:
        return int(value)
    if isinstance(value, float) and value.is_integer():
        value = int(value)
    if isinstance(value, int) and not isinstance(value, bool):
        return value
    return None


def unix_text(value):
    """Times in the snapshot files are digit strings, so DM can compare them
    exactly (json_decode would turn a number into a 32-bit float)."""
    return str(int(value or 0))


def ckey_valid(ckey):
    return isinstance(ckey, str) and bool(CKEY.match(ckey))


def normalise(record, region=None):
    """A validated copy of one record as DM sends it. region, when given, is the
    agent's own region and wins over the record's."""
    if not isinstance(record, dict):
        raise RecordError('a record is an object')
    rid = record.get('id')
    if not isinstance(rid, str) or not RECORD_ID.match(rid):
        raise RecordError('bad record id')
    ckey = record.get('ckey')
    if not ckey_valid(ckey):
        raise RecordError('bad record ckey')
    kind = record.get('kind')
    if not isinstance(kind, str) or not KIND.match(kind):
        raise RecordError('bad record kind')
    author = record.get('author') or ''
    if not isinstance(author, str) or (author and not CKEY.match(author)):
        raise RecordError('bad record author')
    rank = record.get('rank') or ''
    if not isinstance(rank, str) or len(rank) > MAX_RANK:
        raise RecordError('bad record rank')
    at = unix_int(record.get('at'))
    if at is None or at <= 0:
        raise RecordError('bad record time')
    body = record.get('body')
    if body is None or body == []:
        body = {}  # DM encodes an empty list as []
    if not isinstance(body, dict):
        raise RecordError('a record body is an object')
    text = json.dumps(body, sort_keys=True, separators=(',', ':'))
    if len(text.encode('utf-8')) > MAX_BODY:
        raise RecordError('record body too large')
    source = region if region is not None else record.get('region')
    if not isinstance(source, str) or not REGION.match(source):
        raise RecordError('bad record region')
    if kind == 'revoke':
        target = body.get('target')
        if not isinstance(target, str) or not RECORD_ID.match(target) or target == rid:
            raise RecordError('a revoke names another record id')
    if kind == 'ban':
        if body.get('scope') not in BAN_SCOPES:
            raise RecordError('a ban has scope game, play, ooc or job')
        until = unix_int(body.get('until', 0))
        if until is None or until < 0:
            raise RecordError('a ban ends at a unix time, or 0 for never')
        body = dict(body, until=until)
        text = json.dumps(body, sort_keys=True, separators=(',', ':'))
    return {'id': rid, 'ckey': ckey, 'kind': kind, 'author': author, 'rank': rank, 'region': source,
            'at': at, 'body': text}


# -- region agent side --------------------------------------------------------

def init_region(db):
    """The agent's queue of records waiting for the coordinator."""
    db.execute('''CREATE TABLE IF NOT EXISTS record_outbox(
        id TEXT PRIMARY KEY, record TEXT NOT NULL)''')


def region_add(db, region, records):
    """Queue records from DM. Returns the ids now queued (old ones included):
    a world may send the same record again after a lost answer."""
    if not isinstance(records, list) or not records:
        raise RecordError('send a list of records')
    if len(records) > OUTBOX_BATCH:
        raise RecordError('too many records at once')
    rows = [normalise(r, region) for r in records]
    for row in rows:
        queued = dict(row, body=json.loads(row['body']))
        db.execute('INSERT OR IGNORE INTO record_outbox VALUES (?, ?)', (row['id'], json.dumps(queued, sort_keys=True)))
    return [row['id'] for row in rows]


def region_outbox(db):
    return {'records': [json.loads(r) for (r,) in db.execute(
        'SELECT record FROM record_outbox ORDER BY rowid LIMIT ?', (OUTBOX_BATCH,))]}


def region_ack(db, ids):
    if not isinstance(ids, list) or not all(isinstance(i, str) and RECORD_ID.match(i) for i in ids):
        raise RecordError('acknowledge a list of record ids')
    db.executemany('DELETE FROM record_outbox WHERE id = ?', [(i,) for i in ids])
    return len(ids)


# -- coordinator side ---------------------------------------------------------

def init_group(db):
    db.execute('''CREATE TABLE IF NOT EXISTS player_record(
        seq INTEGER PRIMARY KEY AUTOINCREMENT, id TEXT NOT NULL UNIQUE, ckey TEXT NOT NULL,
        kind TEXT NOT NULL, author TEXT NOT NULL, rank TEXT NOT NULL, region TEXT NOT NULL,
        at INTEGER NOT NULL, received INTEGER NOT NULL, body TEXT NOT NULL)''')
    db.execute('CREATE INDEX IF NOT EXISTS player_record_ckey ON player_record(ckey, seq)')
    db.execute('CREATE INDEX IF NOT EXISTS player_record_kind ON player_record(kind, seq)')
    # When each region's queue was last emptied into the table: a world drops a
    # record it sent once its region's pull time passes the send time.
    db.execute('CREATE TABLE IF NOT EXISTS record_pull(region TEXT PRIMARY KEY, at INTEGER NOT NULL)')


def store_records(db, region, records, now=None):
    """Store records collected from one region's agent. Returns (stored ids,
    affected ckeys). Bad rows are skipped, not fatal: one bad record must never
    hold up a region's queue (the agent validated them already). now is when the
    queue was read; it becomes the region's pull time only when the read
    emptied the queue (fewer than a full batch), so a world never drops a
    record still waiting in its agent."""
    now = int(time.time() if now is None else now)
    ids, ckeys = [], set()
    for record in records if isinstance(records, list) else []:
        try:
            row = normalise(record, region)
        except RecordError:
            if isinstance(record, dict) and isinstance(record.get('id'), str) and RECORD_ID.match(record['id']):
                ids.append(record['id'])  # acknowledge it so it leaves the queue
            continue
        cursor = db.execute('INSERT OR IGNORE INTO player_record(id, ckey, kind, author, rank, region, at, received, body) '
                            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
                            (row['id'], row['ckey'], row['kind'], row['author'], row['rank'], row['region'],
                             row['at'], now, row['body']))
        ids.append(row['id'])
        if cursor.rowcount:
            ckeys.add(row['ckey'])
            if row['kind'] == 'revoke':
                target = db.execute('SELECT ckey FROM player_record WHERE id = ?',
                                    (json.loads(row['body'])['target'],)).fetchone()
                if target:
                    ckeys.add(target[0])
    if not isinstance(records, list) or len(records) < OUTBOX_BATCH:
        db.execute('INSERT OR REPLACE INTO record_pull VALUES (?, ?)', (region, now))
    return ids, ckeys


def _rows(db, where='', args=()):
    return [{'seq': s, 'id': i, 'ckey': c, 'kind': k, 'author': a, 'rank': r, 'region': g, 'at': t,
             'received': rc, 'body': json.loads(b)}
            for s, i, c, k, a, r, g, t, rc, b in db.execute(
                'SELECT seq, id, ckey, kind, author, rank, region, at, received, body FROM player_record ' + where +
                ' ORDER BY seq', args)]


def revocations(db):
    """target id -> the revoke record (the first one wins)."""
    found = {}
    for row in _rows(db, 'WHERE kind = ?', ('revoke',)):
        found.setdefault(row['body'].get('target'), row)
    return found


def published(row):
    """A record as the snapshot files show it: times as digit strings."""
    entry = dict(row, at=unix_text(row['at']), received=unix_text(row['received']))
    if 'until' in row['body']:
        entry['body'] = dict(row['body'], until=unix_text(row['body']['until']))
    return entry


def ban_active(row, now):
    until = row['body'].get('until', 0)
    return until == 0 or until > now


def player_file(db, ckey, revoked=None, hours=None):
    revoked = revocations(db) if revoked is None else revoked
    records = []
    for row in _rows(db, 'WHERE ckey = ?', (ckey,)):
        entry = published(row)
        gone = revoked.get(row['id'])
        if gone:
            entry['revoked'] = {'id': gone['id'], 'by': gone['author'], 'at': unix_text(gone['at']),
                                'region': gone['region'], 'reason': gone['body'].get('reason', '')}
        records.append(entry)
    return {'version': INDEX_VERSION, 'ckey': ckey, 'hours': hours or 0, 'records': records}


def playtime(activity_path):
    """(ckey -> hours, discord account -> ckey) from the player activity database:
    minutes when the player was connected and their character alive and awake.
    Empty when the database is missing or busy."""
    hours, accounts = {}, {}
    if not activity_path or not os.path.exists(activity_path):
        return hours, accounts
    try:
        db = sqlite3.connect('file:%s?mode=ro' % activity_path, uri=True, timeout=2)
    except sqlite3.Error:
        return hours, accounts
    try:
        columns = {r[1] for r in db.execute('PRAGMA table_info(daily)')}
        if 'alive_minutes' not in columns:
            return hours, accounts
        for account, ckey in db.execute('SELECT account, ckey FROM account WHERE agent = 0'):
            if account.startswith('d:') and isinstance(ckey, str) and CKEY.match(ckey):
                accounts[account] = ckey
        for account, ckey, minutes in db.execute(
                'SELECT d.account, a.ckey, SUM(d.alive_minutes) FROM daily d JOIN account a ON a.account = d.account '
                'WHERE a.agent = 0 GROUP BY d.account'):
            key = ckey if isinstance(ckey, str) and CKEY.match(ckey) else account
            if not CKEY.match(key):
                continue
            hours[key] = hours.get(key, 0) + (minutes or 0) / 60.0
    except sqlite3.Error:
        return {}, {}
    finally:
        db.close()
    return {k: round(v, 1) for k, v in hours.items()}, accounts


def build_index(db, now, hours=None, accounts=None):
    """The per-ckey summary every world reads, and the active bans. Times are
    digit strings of unix seconds ("0" for a ban that never ends)."""
    now = int(now)
    revoked = revocations(db)
    players = {}

    def entry(ckey):
        return players.setdefault(ckey, {'notes': 0, 'warnings': 0, 'watch': False, 'bans': [], 'hours': 0,
                                         'kinds': {}})
    bans = []
    for row in _rows(db, 'WHERE kind != ?', ('revoke',)):
        if row['id'] in revoked:
            continue
        e = entry(row['ckey'])
        e['kinds'][row['kind']] = e['kinds'].get(row['kind'], 0) + 1
        if row['kind'] == 'note':
            e['notes'] += 1
        elif row['kind'] == 'warning':
            e['warnings'] += 1
        elif row['kind'] == 'watch':
            e['watch'] = True
        elif row['kind'] == 'unwatch':
            e['watch'] = False
        elif row['kind'] == 'ban' and ban_active(row, now):
            body = row['body']
            until = unix_text(body.get('until', 0))
            e['bans'].append({'id': row['id'], 'scope': body['scope'], 'until': until})
            ban = dict(body, id=row['id'], ckey=row['ckey'], author=row['author'], region=row['region'],
                       at=unix_text(row['at']), until=until)
            bans.append(ban)
    for ckey, value in (hours or {}).items():
        entry(ckey)['hours'] = value
    pulls = {r: unix_text(t) for r, t in db.execute('SELECT region, at FROM record_pull')}
    seq = db.execute('SELECT COALESCE(MAX(seq), 0) FROM player_record').fetchone()[0]
    index = {'version': INDEX_VERSION, 'generated': unix_text(now), 'seq': seq, 'pulled': pulls,
             'accounts': accounts or {}, 'players': players}
    return index, {'version': INDEX_VERSION, 'generated': unix_text(now), 'bans': bans}


def build_connections(db):
    """Every ckey seen with an IP and computer id ("connection" records), for
    alt lookups and bans by IP or computer id on every region."""
    revoked = revocations(db)
    seen = []
    for row in _rows(db, 'WHERE kind = ?', ('connection',)):
        if row['id'] in revoked:
            continue
        body = row['body']
        seen.append({'ckey': row['ckey'], 'ip': str(body.get('ip') or ''), 'cid': str(body.get('cid') or ''),
                     'at': unix_text(row['at'])})
    return {'version': INDEX_VERSION, 'connections': seen}


def write_json(path, value, attempts=5):
    """Write a file whole: temp name in the same folder, then rename. On Windows
    the rename fails while a world has the file open; retry briefly, then give
    up for this pass (the next pass writes it again). Returns True when written."""
    folder = os.path.dirname(path)
    os.makedirs(folder, exist_ok=True)
    temp = '%s.%d.tmp' % (path, os.getpid())
    with open(temp, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(value, f, sort_keys=True, separators=(',', ':'))
    for attempt in range(attempts):
        try:
            os.replace(temp, path)
            return True
        except PermissionError:
            time.sleep(0.05 * (attempt + 1))
    try:
        os.remove(temp)
    except OSError:
        pass
    return False


class Snapshots:
    """Writes the shared-records files after each coordinator pass."""

    def __init__(self, db, root, activity_path=None):
        self.db = db
        self.root = root
        self.activity_path = activity_path
        self.dirty = set()
        self.full = True  # the first pass writes every player's file
        self.unwritten = set()
        self.next_index = 0.0
        self.hours = {}
        self.connections_dirty = True  # rewritten on the first pass and when one is stored

    def player_path(self, ckey):
        return os.path.join(self.root, 'players', ckey[0], ckey + '.json')

    def write(self, now=None, force=False):
        """Write what changed. Returns the number of files written."""
        now = time.time() if now is None else now
        written = 0
        if self.full:
            self.dirty |= {c for (c,) in self.db.execute('SELECT DISTINCT ckey FROM player_record')}
            self.full = False
        self.dirty |= self.unwritten
        self.unwritten = set()
        if not self.dirty and not force and now < self.next_index:
            return 0
        hours, accounts = playtime(self.activity_path)
        if hours:
            self.hours = hours
        revoked = revocations(self.db)
        for ckey in sorted(self.dirty):
            if write_json(self.player_path(ckey), player_file(self.db, ckey, revoked, self.hours.get(ckey))):
                written += 1
            else:
                self.unwritten.add(ckey)
        self.dirty = set()
        index, bans = build_index(self.db, now, self.hours, accounts)
        written += write_json(os.path.join(self.root, 'index.json'), index)
        written += write_json(os.path.join(self.root, 'bans.json'), bans)
        if self.connections_dirty:
            if write_json(os.path.join(self.root, 'connections.json'), build_connections(self.db)):
                written += 1
                self.connections_dirty = False
        self.next_index = now + SNAPSHOT_SECONDS
        return written


# -- host tools (shard_group.py records, the launcher's Player records window) --

# What each region writes once it has copied its old files in (player_notes.dm,
# quickBan.dm, shared_memos.dm), and its journal of records not yet collected.
MIGRATION_MARKERS = {'notes': ('data', 'player_notes.migrated'), 'bans': ('SQL', 'bans.migrated'),
                     'memos': ('data', 'memos.migrated')}
JOURNAL = ('data', 'player_records.json')


def canonical_ckey(text):
    """A BYOND key as ckey() makes it: lower case letters, digits and @."""
    return re.sub(r'[^a-z0-9@]', '', str(text or '').lower())[:32]


def _when(at):
    at = unix_int(at) or 0
    return time.strftime('%Y-%m-%d %H:%M', time.localtime(at)) if at > 0 else 'unknown'


def _describe(row):
    """One record as a short line of text (no IPs: those stay in the ckey view and the export)."""
    body = row['body']
    if row['kind'] == 'ban':
        until = unix_int(body.get('until', 0)) or 0
        what = '%s ban (%s)%s: %s, %s' % (body.get('type') or body.get('scope'), body.get('scope'),
                                         ' ' + body['info'] if body.get('info') not in (None, '', 'nil') else '',
                                         body.get('reason', ''), 'never ends' if not until else 'ends ' + _when(until))
    elif row['kind'] == 'connection':
        what = 'connected from %s (computer id %s)' % (body.get('ip', ''), body.get('cid', ''))
    elif row['kind'] == 'revoke':
        what = 'removed %s %s%s' % (body.get('target_kind', ''), body.get('target', ''),
                                    ': ' + body['reason'] if body.get('reason') else '')
    else:
        what = str(body.get('text') or body.get('html') or json.dumps(body, sort_keys=True))
    return '%s  %-10s %s  (by %s on %s)' % (_when(row['at']), row['kind'], what[:300], row['author'] or 'server',
                                            row['region'])


def region_status(region_dirs):
    """Per region: which old files it has copied in, and its journal (records not yet
    collected by the coordinator, and records the agent refused)."""
    status = {}
    for region, folder in region_dirs.items():
        entry = {'migrated': {name: os.path.exists(os.path.join(folder, *path)) for name, path in MIGRATION_MARKERS.items()},
                 'waiting': 0, 'refused': 0}
        try:
            with open(os.path.join(folder, *JOURNAL), encoding='utf-8') as f:
                journal = json.load(f)
        except (OSError, ValueError):
            journal = []
        for record in journal if isinstance(journal, list) else []:
            if isinstance(record, dict):
                if record.get('sent') in (-1, '-1'):
                    entry['refused'] += 1
                else:
                    entry['waiting'] += 1
        status[region] = entry
    return status


def report(db, now, ckey=None, search=None, limit=200):
    """The Player records window: a summary of the whole store, every record about one
    ckey, or the records whose ckey or text holds search. Answers data and text."""
    now = int(now)
    revoked = revocations(db)
    lines = []
    if ckey:
        records = player_file(db, ckey, revoked)['records']
        lines.append('%s: %d records' % (ckey, len(records)))
        for row in records:
            lines.append(('[removed] ' if row.get('revoked') else '') + _describe(row))
        return {'ckey': ckey, 'records': records[-limit:], 'text': '\n'.join(lines)}
    if search:
        needle = search.lower()
        found = []
        for row in reversed(_rows(db)):
            if needle in row['ckey'] or needle in json.dumps(row['body']).lower():
                found.append(row)
                if len(found) >= limit:
                    break
        lines.append('%d records match "%s"%s' % (len(found), search, ' (the newest %d)' % limit if len(found) >= limit else ''))
        for row in found:
            lines.append('%-20s %s%s' % (row['ckey'], '[removed] ' if row['id'] in revoked else '', _describe(row)))
        return {'search': search, 'matches': [published(r) for r in found], 'text': '\n'.join(lines)}
    kinds = {}
    ckeys = set()
    bans = 0
    for row in _rows(db, 'WHERE kind != ?', ('revoke',)):
        counts = kinds.setdefault(row['kind'], {'active': 0, 'removed': 0})
        if row['id'] in revoked:
            counts['removed'] += 1
            continue
        counts['active'] += 1
        ckeys.add(row['ckey'])
        if row['kind'] == 'ban' and ban_active(row, now):
            bans += 1
    pulls = {r: unix_text(t) for r, t in db.execute('SELECT region, at FROM record_pull')}
    lines.append('%d players have records; %d bans are active.' % (len(ckeys), bans))
    for kind in sorted(kinds):
        lines.append('  %-14s %6d active, %d removed' % (kind, kinds[kind]['active'], kinds[kind]['removed']))
    for region in sorted(pulls):
        lines.append('Last collected from %s: %s' % (region, _when(pulls[region])))
    return {'players': len(ckeys), 'active_bans': bans, 'kinds': kinds, 'pulled': pulls, 'text': '\n'.join(lines)}


def export(db, path, now):
    """Every record (removed ones marked) to one JSON file, for a backup or an audit."""
    revoked = revocations(db)
    records = []
    for row in _rows(db):
        entry = published(row)
        if row['id'] in revoked:
            entry['revoked'] = revoked[row['id']]['id']
        records.append(entry)
    if not write_json(path, {'version': INDEX_VERSION, 'exported': unix_text(now), 'records': records}):
        raise OSError('could not write %s' % path)
    return len(records)


def main(argv=None):
    """Read-only look at a coordinator's player records (host tools, launcher)."""
    import argparse
    parser = argparse.ArgumentParser(description=main.__doc__)
    parser.add_argument('--db', required=True, help='the coordinator database')
    parser.add_argument('--ckey', help='every record about one ckey')
    parser.add_argument('--kind', help='only records of this kind')
    parser.add_argument('--limit', type=int, default=50)
    args = parser.parse_args(argv)
    db = sqlite3.connect('file:%s?mode=ro' % args.db, uri=True)
    try:
        where, params = [], []
        if args.ckey:
            where.append('ckey = ?')
            params.append(args.ckey)
        if args.kind:
            where.append('kind = ?')
            params.append(args.kind)
        rows = _rows(db, ('WHERE ' + ' AND '.join(where)) if where else '', tuple(params))
        print(json.dumps(rows[-args.limit:], indent=1, sort_keys=True))
    finally:
        db.close()


if __name__ == '__main__':
    main()
