"""Read every region's player activity lines into one host database, and report.

The game writes data/player_activity/<yyyy-mm-dd>.jsonl in each region's folder
when PLAYER_ACTIVITY 1 is set (docs/player-activity.md). This tool reads new
bytes from those files into one SQLite database, keeps the read position so a
re-run never counts a line twice, deletes a past day's file once it is fully
read (keeping a compressed copy for RECOVERY_DAYS), prunes old rows, and
prints a report. It never touches the transfer agents or coordinator.sqlite.

    python3 tools/player_activity/aggregate.py --group <group.json> --db <db> [--report]
    python3 tools/player_activity/aggregate.py --region-dir gaia=<dir> ... --db <db>
    python3 tools/player_activity/aggregate.py --db <db> --forget <account>
    python3 tools/player_activity/aggregate.py --db <db> --report --json

Plan: https://claude.ai/artifact/Rr7NGiEdMCwRaXtpbfP3PV
"""
import argparse
import datetime as dt
import gzip
import json
import os
from pathlib import Path
import sqlite3
import sys

SCHEMA_VERSION = 1
EVENT_DAYS = 90
ROLLUP_DAYS = 365
RECOVERY_DAYS = 7
SESSION_JOIN_SECONDS = 300  # a leave on one region and a join on another this close are one play session
HEARTBEAT_MINUTES = 5
DAY = 86400
ACTIVITY_DIR = Path('data') / 'player_activity'

SCHEMA = """
CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS source (
    path TEXT PRIMARY KEY, region TEXT NOT NULL, day TEXT NOT NULL,
    offset INTEGER NOT NULL DEFAULT 0, boot TEXT, tz REAL NOT NULL DEFAULT 0,
    daytime INTEGER NOT NULL DEFAULT 0, finished INTEGER NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS event (
    id INTEGER PRIMARY KEY, region TEXT NOT NULL, boot TEXT, ts INTEGER NOT NULL,
    day TEXT NOT NULL, e TEXT NOT NULL, account TEXT, anon TEXT, data TEXT NOT NULL);
CREATE INDEX IF NOT EXISTS event_ts ON event (ts);
CREATE INDEX IF NOT EXISTS event_account ON event (account, ts);
CREATE INDEX IF NOT EXISTS event_kind ON event (e, ts);
CREATE TABLE IF NOT EXISTS account (
    account TEXT PRIMARY KEY, first_ts INTEGER NOT NULL, last_ts INTEGER NOT NULL,
    first_region TEXT, ckey TEXT, agent INTEGER NOT NULL DEFAULT 0, staff INTEGER NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS daily (
    day TEXT NOT NULL, account TEXT NOT NULL, region TEXT NOT NULL,
    joins INTEGER NOT NULL DEFAULT 0, minutes REAL NOT NULL DEFAULT 0,
    active_minutes REAL NOT NULL DEFAULT 0, deaths INTEGER NOT NULL DEFAULT 0,
    departs INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (day, account, region));
CREATE TABLE IF NOT EXISTS forgotten (account TEXT PRIMARY KEY, at INTEGER NOT NULL);
"""


def connect(path):
    db = sqlite3.connect(str(path))
    db.row_factory = sqlite3.Row
    db.execute('PRAGMA journal_mode=WAL')
    db.executescript(SCHEMA)
    db.execute("INSERT OR IGNORE INTO meta VALUES ('schema', ?)", (str(SCHEMA_VERSION),))
    if 'alive_minutes' not in {row[1] for row in db.execute('PRAGMA table_info(daily)')}:
        # Playtime (shared player records): minutes connected with the character
        # alive and awake. Days whose events are still kept are counted again.
        db.execute('ALTER TABLE daily ADD COLUMN alive_minutes REAL NOT NULL DEFAULT 0')
        rebuild_daily(db, [row['day'] for row in db.execute('SELECT DISTINCT day FROM event ORDER BY day')])
    db.commit()
    return db


def region_dirs_from_group(path):
    group = json.loads(Path(path).read_text(encoding='utf-8'))
    root = Path(group['root'])
    return {r['id']: root / r['id'] for r in group['regions']}


def day_start(day):
    return int(dt.datetime.strptime(day, '%Y-%m-%d').replace(tzinfo=dt.timezone.utc).timestamp())


def utc_day(ts):
    return dt.datetime.fromtimestamp(ts, dt.timezone.utc).strftime('%Y-%m-%d')


def line_time(day, seconds, tz, daytime):
    """UTC seconds for a line written on the host's local day `day`.

    A flush just after local midnight still carries lines from before it in
    the new day's file; they show as a late time before any daytime line."""
    base = day_start(day)
    if not daytime and seconds > DAY - 600:
        base -= DAY
    return base + int(seconds) - int(round(float(tz or 0) * 3600))


def ingest_file(db, region, path, today, forgotten):
    day = path.stem
    try:
        day_start(day)
    except ValueError:
        return 0
    key = str(path.resolve())
    row = db.execute('SELECT * FROM source WHERE path = ?', (key,)).fetchone()
    if row is None:
        db.execute('INSERT INTO source (path, region, day) VALUES (?, ?, ?)', (key, region, day))
        offset, boot, tz, daytime = 0, None, 0, 0
    else:
        offset, boot, tz, daytime = row['offset'], row['boot'], row['tz'], row['daytime']
    size = path.stat().st_size
    added = 0
    if size > offset:
        with path.open('rb') as stream:
            stream.seek(offset)
            chunk = stream.read(size - offset)
        # Only whole lines; a line still being written waits for the next run.
        end = chunk.rfind(b'\n')
        if end >= 0:
            for raw in chunk[:end].splitlines():
                try:
                    line = json.loads(raw.decode('utf-8'))
                except (UnicodeDecodeError, ValueError):
                    continue
                if not isinstance(line, dict) or not isinstance(line.get('e'), str):
                    continue
                seconds = line.get('s') if isinstance(line.get('s'), (int, float)) else 0
                if line['e'] == 'boot':
                    boot, tz = line.get('boot'), line.get('tz') or 0
                    continue
                if 600 <= seconds <= DAY - 600:
                    daytime = 1
                ts = line_time(day, seconds, tz, daytime)
                account = line.get('a') if isinstance(line.get('a'), str) else None
                if account in forgotten or line.get('by') in forgotten:
                    continue
                anon = line.get('anon') if isinstance(line.get('anon'), str) else None
                db.execute('INSERT INTO event (region, boot, ts, day, e, account, anon, data) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
                           (region, boot, ts, utc_day(ts), line['e'], account, anon, json.dumps(line, sort_keys=True)))
                if account:
                    note_account(db, account, ts, region, line)
                added += 1
            offset += end + 1
    finished = 1 if day < today and offset >= size else 0
    db.execute('UPDATE source SET offset = ?, boot = ?, tz = ?, daytime = ?, finished = ? WHERE path = ?',
               (offset, boot, tz, daytime, finished, key))
    return added


def note_account(db, account, ts, region, line):
    agent = 1 if line.get('agent') or account.startswith('agent@') else 0
    staff = 1 if line.get('staff') else 0
    ckey = line.get('ck') if isinstance(line.get('ck'), str) else None
    db.execute("""INSERT INTO account (account, first_ts, last_ts, first_region, ckey, agent, staff)
                  VALUES (?, ?, ?, ?, ?, ?, ?)
                  ON CONFLICT(account) DO UPDATE SET
                    first_ts = MIN(first_ts, excluded.first_ts),
                    first_region = CASE WHEN excluded.first_ts < first_ts THEN excluded.first_region ELSE first_region END,
                    last_ts = MAX(last_ts, excluded.last_ts),
                    ckey = COALESCE(excluded.ckey, ckey),
                    agent = MAX(agent, excluded.agent), staff = MAX(staff, excluded.staff)""",
               (account, ts, ts, region, ckey, agent, staff))


def archive_finished(db, now):
    """Deletes past days' files once fully read, keeping a compressed copy."""
    for row in db.execute('SELECT path FROM source WHERE finished = 1').fetchall():
        path = Path(row['path'])
        if not path.exists():
            continue
        copy = path.parent / 'read' / (path.name + '.gz')
        copy.parent.mkdir(exist_ok=True)
        with path.open('rb') as src, gzip.open(copy, 'wb') as dst:
            dst.write(src.read())
        path.unlink()
    for row in db.execute('SELECT path, region FROM source').fetchall():
        folder = Path(row['path']).parent / 'read'
        if folder.is_dir():
            for copy in folder.glob('*.jsonl.gz'):
                if copy.stat().st_mtime < now - RECOVERY_DAYS * DAY:
                    copy.unlink()


def rebuild_daily(db, days):
    for day in days:
        db.execute('DELETE FROM daily WHERE day = ?', (day,))
        rows = db.execute('SELECT region, e, account, data FROM event WHERE day = ? AND account IS NOT NULL', (day,)).fetchall()
        totals = {}
        for row in rows:
            data = json.loads(row['data'])
            entry = totals.setdefault((row['account'], row['region']), [0, 0.0, 0.0, 0, 0, 0.0])
            if row['e'] == 'join':
                entry[0] += 1
            elif row['e'] == 'hb':
                entry[1] += HEARTBEAT_MINUTES
                if data.get('act'):
                    entry[2] += HEARTBEAT_MINUTES
                # Playtime counts only while connected, alive and awake ("asleep"
                # covers sleeping and unconscious characters).
                if data.get('st') == 'alive':
                    entry[5] += HEARTBEAT_MINUTES
            elif row['e'] == 'death':
                entry[3] += 1
            elif row['e'] == 'depart':
                entry[4] += 1
        for (account, region), (joins, minutes, active, deaths, departs, alive) in totals.items():
            db.execute('INSERT INTO daily (day, account, region, joins, minutes, active_minutes, deaths, departs, alive_minutes) '
                       'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', (day, account, region, joins, minutes, active, deaths, departs, alive))


def prune(db, now):
    db.execute('DELETE FROM event WHERE ts < ?', (now - EVENT_DAYS * DAY,))
    db.execute('DELETE FROM daily WHERE day < ?', (utc_day(now - ROLLUP_DAYS * DAY),))
    db.execute('DELETE FROM source WHERE finished = 1 AND day < ?', (utc_day(now - EVENT_DAYS * DAY),))


def ingest(db, region_dirs, now=None):
    now = int(now if now is not None else dt.datetime.now(dt.timezone.utc).timestamp())
    today = dt.datetime.now().strftime('%Y-%m-%d')
    forgotten = {row['account'] for row in db.execute('SELECT account FROM forgotten')}
    last_id = db.execute('SELECT COALESCE(MAX(id), 0) FROM event').fetchone()[0]
    added = 0
    for region, folder in sorted(region_dirs.items()):
        activity = Path(folder) / ACTIVITY_DIR
        if not activity.is_dir():
            continue
        for path in sorted(activity.glob('*.jsonl')):
            added += ingest_file(db, region, path, today, forgotten)
    days = {row['day'] for row in db.execute('SELECT DISTINCT day FROM event WHERE id > ?', (last_id,))}
    rebuild_daily(db, sorted(days))
    prune(db, now)
    db.commit()
    archive_finished(db, now)
    return added


def forget(db, account):
    """Removes one account everywhere and stops recording it from files not yet read."""
    now = int(dt.datetime.now(dt.timezone.utc).timestamp())
    removed = db.execute('DELETE FROM event WHERE account = ?', (account,)).rowcount
    db.execute("UPDATE event SET data = json_remove(data, '$.by') WHERE json_extract(data, '$.by') = ?", (account,))
    db.execute('DELETE FROM daily WHERE account = ?', (account,))
    db.execute('DELETE FROM account WHERE account = ?', (account,))
    db.execute('INSERT OR REPLACE INTO forgotten VALUES (?, ?)', (account, now))
    db.commit()
    return removed


# ---------------------------------------------------------------- report

def players(db):
    """Accounts that count as players: not host agents."""
    return {row['account'] for row in db.execute('SELECT account FROM account WHERE agent = 0')}


def sessions(db, since):
    """Play sessions: join to leave per account, stitched across regions."""
    rows = db.execute("SELECT region, ts, e, account, data FROM event WHERE e IN ('join', 'leave', 'hb') AND account IS NOT NULL AND ts >= ? ORDER BY account, ts", (since,)).fetchall()
    out = []
    current = None
    for row in rows:
        account, ts = row['account'], row['ts']
        if current and (current['account'] != account or ts - current['last'] > SESSION_JOIN_SECONDS + HEARTBEAT_MINUTES * 60):
            out.append(current)
            current = None
        if current is None:
            current = {'account': account, 'start': ts, 'last': ts, 'regions': {row['region']}}
        current['last'] = ts
        current['regions'].add(row['region'])
    if current:
        out.append(current)
    return out


def report(db, now=None):
    now = int(now if now is not None else dt.datetime.now(dt.timezone.utc).timestamp())
    real = players(db)

    def active_since(seconds):
        return {row['account'] for row in db.execute('SELECT DISTINCT account FROM event WHERE ts >= ? AND account IS NOT NULL', (now - seconds,))} & real

    new_week = {row['account'] for row in db.execute('SELECT account FROM account WHERE agent = 0 AND first_ts >= ?', (now - 7 * DAY,))}
    week = sessions(db, now - 7 * DAY)
    lengths = sorted((s['last'] - s['start']) / 60 for s in week if s['account'] in real)

    def counts(sql, *args):
        return [dict(row) for row in db.execute(sql, args)]

    deaths = counts("SELECT json_extract(data, '$.cause') AS cause, COUNT(*) AS n FROM event WHERE e = 'death' AND ts >= ? AND json_extract(data, '$.agent') IS NULL GROUP BY cause ORDER BY n DESC", now - 7 * DAY)
    early = counts("SELECT json_extract(data, '$.cause') AS cause, COUNT(*) AS n FROM event WHERE e = 'death' AND ts >= ? AND json_extract(data, '$.smin') < 60 AND json_extract(data, '$.agent') IS NULL GROUP BY cause ORDER BY n DESC", now - 7 * DAY)
    travel = counts("SELECT region AS origin, json_extract(data, '$.to') AS dest, json_extract(data, '$.how') AS how, COUNT(*) AS n FROM event WHERE e = 'depart' AND ts >= ? AND json_extract(data, '$.agent') IS NULL GROUP BY origin, dest, how ORDER BY n DESC", now - 7 * DAY)
    refused = counts("SELECT json_extract(data, '$.why') AS why, COUNT(*) AS n FROM event WHERE e = 'refused' AND ts >= ? GROUP BY why ORDER BY n DESC", now - 7 * DAY)
    playtime = counts('SELECT region, ROUND(SUM(minutes) / 60.0, 1) AS hours, ROUND(SUM(active_minutes) / 60.0, 1) AS active_hours FROM daily WHERE day >= ? GROUP BY region ORDER BY hours DESC', utc_day(now - 7 * DAY))
    by_hour = {}
    for row in db.execute("SELECT ts, json_extract(data, '$.p') AS p FROM event WHERE e = 'health' AND ts >= ?", (now - 7 * DAY,)):
        hour = dt.datetime.fromtimestamp(row['ts'], dt.timezone.utc).hour
        by_hour[hour] = max(by_hour.get(hour, 0), row['p'] or 0)
    lag = counts("SELECT json_extract(data, '$.p') AS players, ROUND(AVG(json_extract(data, '$.dil')), 1) AS dilation, COUNT(*) AS samples FROM event WHERE e = 'health' AND ts >= ? GROUP BY players ORDER BY players", now - 7 * DAY)

    # Retention: of the accounts first seen 8-37 days ago, how many came back.
    retention = {}
    cohort = [dict(row) for row in db.execute('SELECT account, first_ts FROM account WHERE agent = 0 AND first_ts BETWEEN ? AND ?', (now - 37 * DAY, now - 8 * DAY))]
    for label, lo, hi in (('day1', DAY, 2 * DAY), ('day7', 2 * DAY, 8 * DAY)):
        back = 0
        for entry in cohort:
            hit = db.execute('SELECT 1 FROM event WHERE account = ? AND e = ? AND ts BETWEEN ? AND ? LIMIT 1',
                             (entry['account'], 'join', entry['first_ts'] + lo, entry['first_ts'] + hi)).fetchone()
            back += 1 if hit else 0
        retention[label] = {'cohort': len(cohort), 'returned': back}

    # Churn: active in the week before last, silent for the last 7 days, with their last event.
    churn = []
    for row in db.execute('SELECT account, last_ts FROM account WHERE agent = 0 AND last_ts BETWEEN ? AND ? ORDER BY last_ts DESC', (now - 14 * DAY, now - 7 * DAY)):
        last = db.execute("SELECT e, region, data FROM event WHERE account = ? AND e NOT IN ('hb', 'leave', 'counts') ORDER BY ts DESC LIMIT 1", (row['account'],)).fetchone()
        churn.append({'account': row['account'], 'last_seen': utc_day(row['last_ts']), 'last_event': last['e'] if last else None, 'region': last['region'] if last else None})

    # New-player funnel: of the accounts first seen in the last 30 days, how many reached each step.
    fresh = [row['account'] for row in db.execute('SELECT account FROM account WHERE agent = 0 AND first_ts >= ?', (now - 30 * DAY,))]
    funnel_steps = (
        ('joined', "e = 'join'"),
        ('tutorial_finished', "e = 'tutorial' AND json_extract(data, '$.step') = 'finished'"),
        ('crafted', "e = 'counts' AND data LIKE '%\"craft:%'"),
        ('learned_research', "e = 'learn'"),
        ('joined_faction', "e IN ('faction_join', 'faction_found')"),
        ('travelled', "e = 'depart'"),
        ('died', "e = 'death'"),
    )
    funnel = {}
    for name, where in funnel_steps:
        funnel[name] = sum(1 for account in fresh if db.execute('SELECT 1 FROM event WHERE account = ? AND ' + where + ' LIMIT 1', (account,)).fetchone())
    funnel['came_back_another_day'] = sum(1 for account in fresh if db.execute('SELECT COUNT(DISTINCT day) FROM event WHERE account = ? AND e = ?', (account, 'join')).fetchone()[0] > 1)
    tutorial = counts("SELECT json_extract(data, '$.step') AS step, COUNT(DISTINCT COALESCE(account, anon)) AS players FROM event WHERE e = 'tutorial' AND ts >= ? GROUP BY step ORDER BY players DESC", now - 30 * DAY)

    # Research walls: hand actions refused for missing research (counter "locked:<node>").
    walls = {}
    crafts = {}
    for row in db.execute("SELECT account, data FROM event WHERE e = 'counts' AND ts >= ?", (now - 7 * DAY,)):
        for name, amount in (json.loads(row['data']).get('c') or {}).items():
            if name.startswith('locked:'):
                entry = walls.setdefault(name[7:], [0, set()])
            elif name.startswith('craft:'):
                entry = crafts.setdefault(name[6:], [0, set()])
            else:
                continue
            entry[0] += amount if isinstance(amount, (int, float)) else 0
            entry[1].add(row['account'])
    features = {}
    help_outcomes = {}
    for row in db.execute("SELECT account, data FROM event WHERE e = 'counts' AND ts >= ?", (now - 7 * DAY,)):
        for name, amount in (json.loads(row['data']).get('c') or {}).items():
            amount = amount if isinstance(amount, (int, float)) else 0
            if name.startswith('use:'):
                entry = features.setdefault(name[4:], [0, set()])
                entry[0] += amount
                entry[1].add(row['account'])
            elif name.startswith('help:'):
                help_outcomes[name[5:]] = help_outcomes.get(name[5:], 0) + amount
    feature_use = sorted(({'feature': k, 'uses': v[0], 'players': len(v[1])} for k, v in features.items()), key=lambda r: (-r['players'], -r['uses']))
    voyages = counts("SELECT region, json_extract(data, '$.kind') AS kind, COUNT(*) AS n FROM event WHERE e = 'voyage' AND ts >= ? GROUP BY region, kind ORDER BY n DESC", now - 7 * DAY)
    reach = []
    for row in db.execute("SELECT region, data FROM event WHERE e = 'reach' AND id IN (SELECT MAX(id) FROM event WHERE e = 'reach' GROUP BY region) ORDER BY region"):
        for level, pair in sorted((json.loads(row['data']).get('levels') or {}).items(), key=lambda kv: int(kv[0]) if kv[0].isdigit() else 0):
            if isinstance(pair, list) and len(pair) == 2 and pair[1]:
                reach.append({'region': row['region'], 'level': level, 'visited': pair[0], 'chunks': pair[1], 'percent': round(100.0 * pair[0] / pair[1], 1)})
    research_walls = sorted(({'node': k, 'refusals': v[0], 'players': len(v[1])} for k, v in walls.items()), key=lambda r: (-r['players'], -r['refusals']))[:20]
    crafting = sorted(({'family': k, 'crafts': v[0], 'players': len(v[1])} for k, v in crafts.items()), key=lambda r: -r['crafts'])[:20]
    learned = counts("SELECT json_extract(data, '$.node') AS node, COUNT(DISTINCT account) AS players FROM event WHERE e = 'learn' AND json_extract(data, '$.agent') IS NULL GROUP BY node ORDER BY players DESC")
    first_crafts = db.execute("SELECT COUNT(DISTINCT json_extract(data, '$.type')) FROM event WHERE e = 'first_craft'").fetchone()[0]
    factions = counts("SELECT e AS event, COUNT(*) AS n FROM event WHERE e IN ('faction_found', 'faction_join', 'faction_leave') AND ts >= ? GROUP BY e", now - 7 * DAY)
    eras = counts("SELECT region, MAX(json_extract(data, '$.era')) AS era FROM event WHERE e = 'health' GROUP BY region ORDER BY region")

    return {
        'generated': dt.datetime.fromtimestamp(now, dt.timezone.utc).strftime('%Y-%m-%d %H:%M UTC'),
        'active': {'day': len(active_since(DAY)), 'week': len(active_since(7 * DAY)), 'month': len(active_since(30 * DAY))},
        'new_this_week': len(new_week),
        'sessions_this_week': len(lengths),
        'session_minutes_median': round(lengths[len(lengths) // 2], 1) if lengths else 0,
        'playtime_by_region': playtime,
        'peak_players_by_utc_hour': {str(h): by_hour[h] for h in sorted(by_hour)},
        'lag_by_player_count': lag,
        'deaths_by_cause': deaths,
        'first_hour_deaths_by_cause': early,
        'travel': travel,
        'refused_travel': refused,
        'retention': retention,
        'churn': churn,
        'new_player_funnel': dict(funnel, accounts=len(fresh)),
        'tutorial_steps': tutorial,
        'research_walls': research_walls,
        'crafting_by_family': crafting,
        'research_reach': learned,
        'recipes_made_this_world': first_crafts,
        'factions': factions,
        'era_by_region': eras,
        'feature_use': feature_use,
        'help_outcomes': help_outcomes,
        'voyages': voyages,
        'map_reach': reach,
    }


WEEKLY_FILE = 'player-activity-weekly.json'


def weekly_totals(data):
    """The totals the Discord bot may show (decision 7): numbers and region ids only,
    never account keys, research nodes or recipe types."""
    return {
        'v': 1,
        'generated': data['generated'],
        'active': dict(data['active']),
        'new_this_week': data['new_this_week'],
        'sessions_this_week': data['sessions_this_week'],
        'session_minutes_median': data['session_minutes_median'],
        'deaths_this_week': sum(row['n'] for row in data['deaths_by_cause']),
        'trips_this_week': sum(row['n'] for row in data['travel']),
        'hours_by_region': [{'region': row['region'], 'hours': row['hours']} for row in data['playtime_by_region']],
    }


def write_weekly(data, path):
    """Write weekly_totals() atomically for the bot to read."""
    path = Path(path)
    temp = path.with_name(path.name + '.tmp')
    temp.write_text(json.dumps(weekly_totals(data), indent=1), encoding='utf-8')
    os.replace(temp, path)


def print_report(data, out=sys.stdout):
    w = out.write
    w('Player activity, %s\n\n' % data['generated'])
    a = data['active']
    w('Active players: %d today, %d this week, %d this month. New this week: %d.\n' % (a['day'], a['week'], a['month'], data['new_this_week']))
    w('Sessions this week: %d, median %.1f minutes.\n' % (data['sessions_this_week'], data['session_minutes_median']))
    for name, r in data['retention'].items():
        w('Retention %s: %d of %d came back.\n' % (name, r['returned'], r['cohort']))

    def table(title, rows, keys):
        w('\n%s\n' % title)
        if not rows:
            w('  (none)\n')
        for row in rows:
            w('  ' + '  '.join('%s=%s' % (k, row.get(k)) for k in keys) + '\n')

    table('Playtime by region (7 days)', data['playtime_by_region'], ('region', 'hours', 'active_hours'))
    table('Deaths by cause (7 days)', data['deaths_by_cause'], ('cause', 'n'))
    table('Deaths in the first session hour', data['first_hour_deaths_by_cause'], ('cause', 'n'))
    table('Travel (7 days)', data['travel'], ('origin', 'dest', 'how', 'n'))
    table('Refused travel (7 days)', data['refused_travel'], ('why', 'n'))
    table('Lag by player count (7 days)', data['lag_by_player_count'], ('players', 'dilation', 'samples'))
    table('Went quiet (active 8-14 days ago, not since)', data['churn'], ('account', 'last_seen', 'last_event', 'region'))
    f = data['new_player_funnel']
    w('\nNew players (first seen in 30 days): %d\n' % f['accounts'])
    for name in ('joined', 'tutorial_finished', 'crafted', 'learned_research', 'joined_faction', 'travelled', 'died', 'came_back_another_day'):
        w('  %s: %d\n' % (name, f[name]))
    table('Tutorial steps reached (30 days)', data['tutorial_steps'], ('step', 'players'))
    table('Research walls (7 days)', data['research_walls'], ('node', 'players', 'refusals'))
    table('Crafting by family (7 days)', data['crafting_by_family'], ('family', 'players', 'crafts'))
    table('Research known by players (90 days)', data['research_reach'], ('node', 'players'))
    table('Faction events (7 days)', data['factions'], ('event', 'n'))
    table('Era by region', data['era_by_region'], ('region', 'era'))
    w('Recipes made at least once (90 days): %d\n' % data['recipes_made_this_world'])
    table('Features used (7 days)', data['feature_use'], ('feature', 'players', 'uses'))
    w('AI help outcomes (7 days): %s\n' % (', '.join('%s=%s' % kv for kv in sorted(data['help_outcomes'].items())) or '(none)'))
    table('Voyages (7 days)', data['voyages'], ('region', 'kind', 'n'))
    table('Map reach (latest)', data['map_reach'], ('region', 'level', 'visited', 'chunks', 'percent'))
    w('\nPeak players by UTC hour: %s\n' % (', '.join('%s:%s' % kv for kv in data['peak_players_by_utc_hour'].items()) or '(none)'))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--db', type=Path, required=True)
    parser.add_argument('--group', type=Path, help='shard group config; reads <root>/<region id>/data/player_activity')
    parser.add_argument('--region-dir', action='append', default=[], metavar='ID=DIR')
    parser.add_argument('--forget', metavar='ACCOUNT')
    parser.add_argument('--report', action='store_true')
    parser.add_argument('--json', action='store_true', help='print the report as JSON (for the launcher and bot)')
    args = parser.parse_args(argv)
    db = connect(args.db)
    if args.forget:
        print('Forgot %s: %d events removed.' % (args.forget, forget(db, args.forget)))
        return 0
    dirs = region_dirs_from_group(args.group) if args.group else {}
    for item in args.region_dir:
        region, _, folder = item.partition('=')
        if not region or not folder:
            parser.error('--region-dir takes ID=DIR')
        dirs[region] = Path(folder)
    if dirs:
        added = ingest(db, dirs)
        if not args.report:
            print('Read %d new lines from %d regions.' % (added, len(dirs)))
    if args.report:
        data = report(db)
        if args.json:
            print(json.dumps(data, indent=2))
        else:
            print_report(data)
    return 0


if __name__ == '__main__':
    sys.exit(main())
