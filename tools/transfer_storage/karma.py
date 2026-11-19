"""Hidden karma: what staff see about how players remember each other.

Karma is a set of record kinds in the shared player records table
(records.py), tied to ckeys:

    karma_rating    about the rated ckey; body {giver, rating: kindly|poorly, note, faction, shared_cid}.
                    A giver's latest rating of a ckey replaces their earlier ones; when
                    staff revoke that latest one the pair has no rating (an older one
                    never comes back).
    karma_standing  about a ckey; body {value: -2..2, reason}. Set by staff; the latest counts.
    karma_bar       about a ckey; body {reason}. The ckey may not give karma until it is revoked.

Removing a rating or a bar is the store's ordinary "revoke" record.

Weights (each factor kept apart so staff can switch it off):
    standing   the giver's admin standing: +2 1.5, +1 1.2, unset or 0 1.0, -1 0.25, -2 0
    playtime   the giver's share of 100 hours played, at least 0.05
    age        1.0 for 90 days, then 0.5
A giver under an active game ban counts for nothing until the ban ends; the
rating is kept and shown as such.

After each coordinator pass this writes one file per ckey that has karma,
<group root>/shared-records/karma/<ckey>.json, read by the game (giver lists)
and by the Discord bot's staff-only karma command. Nothing else in
shared-records/ is touched here. Karma is never shown to players.
"""
import json
import os
import sys
import time

from tools.transfer_storage import records

KARMA_DIR = 'karma'
RATINGS = ('kindly', 'poorly')
STANDING_FACTOR = {2: 1.5, 1: 1.2, 0: 1.0, -1: 0.25, -2: 0.0}
STANDING_NAME = {2: 'trusted', 1: 'good', 0: 'neutral', -1: 'poor', -2: 'bad'}
FULL_WEIGHT_HOURS = 100.0
PLAYTIME_FLOOR = 0.05
AGE_DAYS = 90
AGE_FACTOR = 0.5
LOW_WEIGHT = 0.25
BURST_SECONDS = 3600
BURST_COUNT = 3
DERIVED_MARGIN = 3  # net received ratings that give a ckey with no admin standing a good or poor label
NOTE_LIMIT = 1000
BAN_SCOPES = ('game', 'play')  # a server ban or a playing ban; OOC and job bans do not count


def standing_factor(value):
    return STANDING_FACTOR.get(value, 1.0)


def playtime_factor(hours):
    return max(PLAYTIME_FLOOR, min(1.0, (hours or 0) / FULL_WEIGHT_HOURS))


def age_factor(at, now):
    return 1.0 if now - at <= AGE_DAYS * 86400 else AGE_FACTOR


def _date(at):
    return time.strftime('%Y-%m-%d', time.gmtime(at))


def ledger(db, now):
    """Everything karma needs from the record table, as plain dicts:
    ratings[target][giver] (latest live rating), standing[ckey], barred set,
    notes[ckey] (live admin notes), banned[ckey] (latest end of an active game
    ban, 0 for never)."""
    revoked = records.revocations(db)
    ratings, standing, barred, notes, banned = {}, {}, set(), {}, {}
    for row in records._rows(db, 'WHERE kind IN (?, ?, ?, ?, ?)',
                             ('karma_rating', 'karma_standing', 'karma_bar', 'note', 'ban')):
        body, ckey = row['body'], row['ckey']
        if row['id'] in revoked and row['kind'] != 'karma_rating':
            continue
        if row['kind'] == 'note':
            notes[ckey] = notes.get(ckey, 0) + 1
        elif row['kind'] == 'ban':
            if body.get('scope') in BAN_SCOPES and records.ban_active(row, now):
                until = body.get('until', 0)
                banned[ckey] = 0 if until == 0 or banned.get(ckey) == 0 else max(until, banned.get(ckey, 0))
        elif row['kind'] == 'karma_bar':
            barred.add(ckey)
        elif row['kind'] == 'karma_standing':
            value = body.get('value')
            if isinstance(value, int) and not isinstance(value, bool) and value in STANDING_FACTOR:
                standing[ckey] = {'value': value, 'reason': str(body.get('reason', ''))[:300],
                                  'author': row['author'], 'at': _date(row['at'])}
        else:
            giver = body.get('giver')
            if body.get('rating') not in RATINGS or not records.ckey_valid(giver) or giver == ckey:
                continue
            # Rows come in table order, so a later rating replaces an earlier one.
            ratings.setdefault(ckey, {})[giver] = {
                'giver': giver, 'kind': body['rating'], 'at_unix': row['at'], 'at': _date(row['at']),
                'note': str(body.get('note', ''))[:NOTE_LIMIT], 'faction': str(body.get('faction', ''))[:64],
                'shared_cid': body.get('shared_cid') in (True, 1), 'id': row['id'], 'revoked': row['id'] in revoked,
                'region': row['region']}
    # A revoked latest rating leaves the pair with none: an older one never comes back.
    for target in list(ratings):
        ratings[target] = {g: r for g, r in ratings[target].items() if not r['revoked']}
        if not ratings[target]:
            del ratings[target]
    return ratings, standing, barred, notes, banned


def label(ckey, standing, ratings):
    """An admin standing's name, else one derived from raw received ratings."""
    if ckey in standing:
        return STANDING_NAME[standing[ckey]['value']]
    received = ratings.get(ckey, {}).values()
    if not received:
        return 'unknown'
    net = sum(1 if r['kind'] == 'kindly' else -1 for r in received)
    return 'good' if net >= DERIVED_MARGIN else 'poor' if net <= -DERIVED_MARGIN else 'neutral'


def snapshots(db, now, hours=None):
    """ckey -> the karma file for every ckey that has received, given or been
    set any karma."""
    now = int(now)
    hours = hours or {}
    ratings, standing, barred, notes, banned = ledger(db, now)
    given = {}
    for target, by_giver in ratings.items():
        for giver, r in by_giver.items():
            given.setdefault(giver, []).append({'target': target, 'kind': r['kind'], 'at': r['at'], 'note': r['note']})
    files = {}
    for ckey in set(ratings) | set(given) | set(standing) | barred:
        rows = []
        received = sorted(ratings.get(ckey, {}).values(), key=lambda r: r['at_unix'])
        for r in received:
            giver = r['giver']
            g_standing = standing.get(giver, {}).get('value')
            factors = {'standing': standing_factor(g_standing), 'playtime': round(playtime_factor(hours.get(giver)), 3),
                       'age': age_factor(r['at_unix'], now)}
            flags = []
            weight = factors['standing'] * factors['playtime'] * factors['age']
            if giver in banned:
                flags.append('giver_banned')
                weight = 0.0
            if r['shared_cid']:
                flags.append('shared_connection')
            if r['kind'] == 'poorly' and r['faction']:
                peers = [o for o in received if o['kind'] == 'poorly' and o['faction'] == r['faction']
                         and abs(o['at_unix'] - r['at_unix']) <= BURST_SECONDS]
                if len(peers) >= BURST_COUNT:
                    flags.append('burst')
            if giver not in banned and weight < LOW_WEIGHT:
                flags.append('low_weight')
            rows.append({'giver': giver, 'kind': r['kind'], 'weight': round(weight, 3), 'factors': factors,
                         'giver_standing': label(giver, standing, ratings), 'giver_hours': hours.get(giver, 0),
                         'giver_notes': notes.get(giver, 0) > 0, 'giver_banned_until': banned.get(giver),
                         'flags': flags, 'faction': r['faction'], 'region': r['region'], 'at': r['at'],
                         'at_unix': r['at_unix'], 'note': r['note'], 'id': r['id']})
        counted = [r for r in rows if 'giver_banned' not in r['flags']]
        kindly = [r for r in counted if r['kind'] == 'kindly']
        poorly = [r for r in counted if r['kind'] == 'poorly']
        kw = round(sum(r['weight'] for r in kindly), 3)
        pw = round(sum(r['weight'] for r in poorly), 3)
        files[ckey] = {
            'version': 1, 'ckey': ckey, 'generated': time.strftime('%Y-%m-%d %H:%M UTC', time.gmtime(now)),
            'standing': standing.get(ckey), 'barred': ckey in barred, 'hours': hours.get(ckey, 0),
            'summary': {'kindly': len(kindly), 'poorly': len(poorly), 'kindly_weighted': kw, 'poorly_weighted': pw,
                        'per10h': round((kw - pw) / max(hours.get(ckey, 0), 1.0) * 10, 2)},
            'ratings': rows, 'given': sorted(given.get(ckey, []), key=lambda g: g['target'])}
    return files


class KarmaFiles:
    """Writes shared-records/karma/ after each coordinator pass, only the files
    whose content changed (the generated time alone is no change)."""

    def __init__(self, db, root):
        self.db = db
        self.folder = os.path.join(root, KARMA_DIR)
        self.last = {}
        self.seq = None
        self.next = 0.0

    def write(self, now=None, hours=None):
        """Recompute when a record arrived, else once a minute (playtime and
        ban ends change weights). Returns the number of files written."""
        now = time.time() if now is None else now
        seq = self.db.execute('SELECT COALESCE(MAX(seq), 0) FROM player_record').fetchone()[0]
        if seq == self.seq and now < self.next:
            return 0
        self.seq, self.next = seq, now + records.SNAPSHOT_SECONDS
        written = 0
        for ckey, value in snapshots(self.db, now, hours).items():
            same = dict(value, generated=None)
            if self.last.get(ckey) == same:
                continue
            if records.write_json(os.path.join(self.folder, ckey + '.json'), value):
                self.last[ckey] = same
                written += 1
        return written


def main(argv=None):
    """Read-only karma for one ckey from a coordinator database (host tools)."""
    import argparse
    import sqlite3
    parser = argparse.ArgumentParser(description=main.__doc__)
    parser.add_argument('--db', required=True, help='the coordinator database')
    parser.add_argument('--ckey', help='one ckey\'s karma file as JSON')
    parser.add_argument('--csv', action='store_true', help='every live rating as CSV, for offline analysis')
    parser.add_argument('--hours', help='a shared-records index.json to take playtime hours from')
    args = parser.parse_args(argv)
    hours = {}
    if args.hours:
        with open(args.hours, encoding='utf-8') as f:
            hours = {c: p.get('hours', 0) for c, p in json.load(f).get('players', {}).items()}
    db = sqlite3.connect('file:%s?mode=ro' % args.db, uri=True)
    try:
        files = snapshots(db, time.time(), hours)
    finally:
        db.close()
    if args.csv:
        write_csv(files, sys.stdout)
    elif args.ckey:
        print(json.dumps(files.get(args.ckey), indent=1, sort_keys=True))
    else:
        parser.error('give --ckey or --csv')


CSV_COLUMNS = ('target', 'target_hours', 'target_standing', 'giver', 'kind', 'weight', 'standing_factor',
               'playtime_factor', 'age_factor', 'giver_standing', 'giver_hours', 'giver_notes', 'flags', 'faction',
               'region', 'at', 'note')


def write_csv(files, out):
    """Every live rating, one row each, heaviest first within a target."""
    import csv
    writer = csv.writer(out)
    writer.writerow(CSV_COLUMNS)
    for target in sorted(files):
        f = files[target]
        standing = f['standing']['value'] if f['standing'] else ''
        for r in sorted(f['ratings'], key=lambda r: -r['weight']):
            writer.writerow((target, f['hours'], standing, r['giver'], r['kind'], r['weight'],
                             r['factors']['standing'], r['factors']['playtime'], r['factors']['age'],
                             r['giver_standing'], r['giver_hours'], int(r['giver_notes']), ' '.join(r['flags']),
                             r['faction'], r['region'], r['at'], r['note']))


if __name__ == '__main__':
    main()
