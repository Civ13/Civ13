"""Small coordinator: a region directory, envelope relay and home-world ledger.

Ordinary item transfers retain custody in the region ledgers. Physical-train
transfers additionally require this coordinator's durable grouped-account lease
and decision. Losing its file holds in-flight trains for reviewed recovery;
re-enrolling the directory does not recreate train commit authority.

The home ledger says which region each account may play in. With a mainland
region, a new account and a player whose character died (with no bed keeping
their home) start in the start region, the mainland unless the host names
another (start_region), and reach the other regions only by travel; without
a mainland, the first claim wins. The mainland stays the group's era source
and land-stage reference either way. Regions queue
account requests in their agents; each pass decides them in a fixed order and
sends every agent the ledger rows it has not seen. The database is durable authority: after loss, restore it rather than
resetting homes. Explicit bootstrap is only for a genuinely new group.
"""
import secrets
import os
import argparse
import json
import sqlite3
import sys
import time
import urllib.error
import urllib.request


# Agents are on loopback: never route these requests through a proxy.
_OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}))


def call(url, token, path, body=None, timeout=5):
    data = json.dumps(body or {}).encode('utf-8')
    request = urllib.request.Request(url + path, data=data, method='POST',
                                     headers={'Content-Type': 'application/json', 'X-Transfer-Token': token})
    try:
        with _OPENER.open(request, timeout=timeout) as response:
            return json.loads(response.read())
    except urllib.error.HTTPError as e:
        return json.loads(e.read() or b'{}')


if __package__ in (None, ''):
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from tools.transfer_storage.train_custody import TrainCustody
from tools.transfer_storage.region import LAND_STAGES, account_key_valid, colony_valid, faction_id_valid, land_id_valid
from tools.transfer_storage.world_chart import WorldChart, land_home, owner_valid, tile_valid
from tools.transfer_storage.nations import Nations
from tools.transfer_storage import records as player_records
from tools.transfer_storage import karma as player_karma


# Land readiness (docs/land-stages.md). Placeholder thresholds for Val to tune:
# a land is suggested for OPEN once this many accounts call it home and the
# mainland averages this many players; an OPEN land is suggested for a pause
# when the mainland falls under PAUSE_MAINLAND_AVG or the land holds more
# living characters than the mainland. Suggestions need READY_MIN_HOURS of
# mainland samples in the window, so a quiet restart decides nothing.
READY_WINDOW_HOURS = 7 * 24
READY_MIN_HOURS = 24
OPEN_HOMES = 10
OPEN_MAINLAND_AVG = 20
PAUSE_MAINLAND_AVG = 15
SAMPLE_FRESH_SECONDS = 180  # worlds sample about once a minute
# A colony (a faction planted in another land with a colony charter) moves its
# land to COLONY once it has stood this long with this many living members.
COLONY_MEMBERS = 3
COLONY_SECONDS = 3 * 24 * 3600
# A colony with fewer living members than this for COLONY_QUIET_SECONDS
# pauses its colony start (and its faction hall bonus) until they are back.
COLONY_KEEP_MEMBERS = 2
COLONY_QUIET_SECONDS = 3 * 24 * 3600


def land_rows(db, regions, mainland):
    """Every enrolled land's stage: the mainland is MAINLAND, a land no
    admin has set is CLOSED."""
    rows = {r: (st, p, b, a) for r, st, p, b, a in db.execute('SELECT region, stage, paused, by, at FROM land')}
    result = {}
    for region in regions:
        if region == mainland:
            result[region] = {'stage': 'MAINLAND', 'paused': False, 'by': None, 'at': 0}
            continue
        stage, paused, by, at = rows.get(region, ('CLOSED', 0, None, 0))
        result[region] = {'stage': stage, 'paused': bool(paused), 'by': by, 'at': int(at)}
    return result


def colony_paused(quiet_since, now):
    return quiet_since is not None and now - quiet_since >= COLONY_QUIET_SECONDS


def land_readiness(db, lands, mainland, now):
    """Population numbers for each land over the last week, its colonies, and
    the stage change they suggest (None, 'COLONY', 'OPEN', 'PAUSE' or 'RESUME').
    Adds 'readiness' and 'colonies' entries to each land in lands and returns lands."""
    since = int(now // 3600) - READY_WINDOW_HOURS
    homes = dict(db.execute('SELECT region, COUNT(*) FROM home WHERE region IS NOT NULL GROUP BY region'))
    stats = {}
    for region, hours, avg, peak in db.execute(
            'SELECT region, COUNT(*), AVG(players_sum * 1.0 / samples), MAX(players_peak) FROM land_hour '
            'WHERE hour > ? AND samples > 0 GROUP BY region', (since,)):
        stats[region] = (hours, avg or 0.0, peak or 0)
    living = {r: l for r, l in db.execute(
        'SELECT region, living FROM land_hour h WHERE hour = (SELECT MAX(hour) FROM land_hour WHERE region = h.region)')}
    main_hours, main_avg, _ = stats.get(mainland, (0, 0.0, 0))
    main_living = living.get(mainland, 0)
    colonies = {}
    for region, parent, name, founded, members, quiet in db.execute(
            'SELECT region, parent, name, founded, members, quiet_since FROM colony ORDER BY region, founded, name'):
        colonies.setdefault(region, []).append({'parent': parent, 'name': name, 'founded': founded, 'members': members,
                                                'paused': colony_paused(quiet, now)})
    for region, entry in lands.items():
        hours, avg, peak = stats.get(region, (0, 0.0, 0))
        ready = {'homes': homes.get(region, 0), 'players_avg': round(avg, 1), 'players_peak': peak,
                 'living': living.get(region, 0), 'hours': hours, 'suggest': None}
        entry['colonies'] = colonies.get(region, [])
        settled = any(c['members'] >= COLONY_MEMBERS and now - c['founded'] >= COLONY_SECONDS for c in entry['colonies'])
        if region != mainland and entry['stage'] in ('CLOSED', 'FRONTIER') and settled:
            # A standing colony needs no mainland numbers: people live there.
            ready['suggest'] = 'COLONY'
        elif region != mainland and main_hours >= READY_MIN_HOURS:
            busy = main_avg >= OPEN_MAINLAND_AVG
            outgrown = ready['living'] > main_living
            if entry['stage'] in ('FRONTIER', 'COLONY') and ready['homes'] >= OPEN_HOMES and busy and not outgrown:
                ready['suggest'] = 'OPEN'
            elif entry['stage'] == 'OPEN' and not entry['paused'] and (main_avg < PAUSE_MAINLAND_AVG or outgrown):
                ready['suggest'] = 'PAUSE'
            elif entry['stage'] == 'OPEN' and entry['paused'] and busy and not outgrown:
                ready['suggest'] = 'RESUME'
        entry['readiness'] = ready
    return lands


def read_lands(path, mainland, now=None):
    """The stages and readiness from a coordinator database, read-only (for
    the host tool and launcher while the coordinator runs). {} when the
    database or its land tables do not exist yet."""
    try:
        db = sqlite3.connect('file:%s?mode=ro' % path, uri=True)
    except sqlite3.Error:
        return {}
    try:
        regions = [r for (r,) in db.execute('SELECT region FROM region ORDER BY region')]
        lands = land_rows(db, regions, mainland)
        return land_readiness(db, lands, mainland, time.time() if now is None else now)
    except sqlite3.Error:
        return {}
    finally:
        db.close()


class Coordinator(TrainCustody):
    def __init__(self, path, group, mainland=None, bootstrap_new_group=False, slots=(), expeditions=None, start_region=None,
                 records_dir=None, activity_db=None):
        self.group = group
        self.mainland = mainland
        # Where new characters (and fallen ones with no bed keeping their home)
        # start: the mainland unless the host chose another region.
        self.start_region = start_region or mainland
        self.db = sqlite3.connect(path, isolation_level=None)
        self.db.execute('PRAGMA journal_mode=WAL')
        self.db.execute('PRAGMA synchronous=FULL')
        self.db.execute('''CREATE TABLE IF NOT EXISTS region(
            region TEXT PRIMARY KEY, url TEXT NOT NULL, token TEXT NOT NULL)''')
        self.db.execute('''CREATE TABLE IF NOT EXISTS home(
            ckey TEXT PRIMARY KEY, region TEXT, rev INTEGER NOT NULL)''')
        self.db.execute('CREATE TABLE IF NOT EXISTS ledger(key TEXT PRIMARY KEY, value TEXT NOT NULL)')
        # Land stages (docs/land-stages.md): one row per land an admin has set.
        self.db.execute('''CREATE TABLE IF NOT EXISTS land(
            region TEXT PRIMARY KEY, stage TEXT NOT NULL, paused INTEGER NOT NULL,
            by TEXT, at INTEGER NOT NULL)''')
        # Hourly population per land from the worlds' samples (land readiness).
        self.db.execute('''CREATE TABLE IF NOT EXISTS land_hour(
            region TEXT NOT NULL, hour INTEGER NOT NULL, samples INTEGER NOT NULL,
            players_sum INTEGER NOT NULL, players_peak INTEGER NOT NULL, living INTEGER NOT NULL,
            PRIMARY KEY(region, hour))''')
        # Colonies each land reported in its latest sample (colony charters).
        self.db.execute('''CREATE TABLE IF NOT EXISTS colony(
            region TEXT NOT NULL, parent TEXT NOT NULL, name TEXT NOT NULL, founded INTEGER NOT NULL,
            members INTEGER NOT NULL, PRIMARY KEY(region, name))''')
        if 'quiet_since' not in {r[1] for r in self.db.execute('PRAGMA table_info(colony)')}:
            # Since when the colony has had fewer than COLONY_KEEP_MEMBERS living members.
            self.db.execute('ALTER TABLE colony ADD COLUMN quiet_since INTEGER')
        # Colony starts granted (colony_charter.dm): the account's home moved to
        # region so its next character starts at the colony of faction there.
        self.db.execute('''CREATE TABLE IF NOT EXISTS colony_grant(
            ckey TEXT PRIMARY KEY, region TEXT NOT NULL, faction TEXT NOT NULL)''')
        # Requests already decided but not yet acknowledged by their agent, so a
        # lost acknowledgement never replays an old request over newer ones.
        # Characters a land holds in escrow for another, as each source last
        # reported them: a source that is down keeps its rows.
        self.db.execute('''CREATE TABLE IF NOT EXISTS travelling(
            source TEXT NOT NULL, ckey TEXT NOT NULL, region TEXT NOT NULL, PRIMARY KEY (source, ckey))''')
        self.db.execute('''CREATE TABLE IF NOT EXISTS decided(
            store TEXT NOT NULL, id INTEGER NOT NULL, PRIMARY KEY(store, id))''')
        self.db.execute('''CREATE TABLE IF NOT EXISTS chart_pass_result(
            store TEXT NOT NULL, id INTEGER NOT NULL, applied INTEGER NOT NULL, PRIMARY KEY(store, id))''')
        self.db.execute("INSERT OR IGNORE INTO ledger VALUES ('epoch', ?)", (secrets.token_hex(8),))
        self.db.execute("INSERT OR IGNORE INTO ledger VALUES ('rev', '0')")

        # A database written before recovery tracking existed is the group's
        # original authority, even if it never decided a home (rev 0).
        legacy = self.db.execute("SELECT 1 FROM ledger WHERE key = 'recovery'").fetchone() is None and bool(self.regions())
        self.init_train_custody()
        self.db.execute("INSERT OR IGNORE INTO ledger VALUES ('recovery', 'unreconciled')")
        # Migrate established databases from their persisted directory, never
        # infer the old group from peers enrolled into a replacement database.
        established = legacy or self._ledger('recovery') == 'ready' or int(self._ledger('rev')) > 0
        roster = sorted(self.regions()) if established else []
        self.db.execute("INSERT OR IGNORE INTO ledger VALUES ('roster', ?)", (json.dumps(roster),))
        self.db.execute("INSERT OR IGNORE INTO ledger VALUES ('bootstrap', '0')")
        if bootstrap_new_group:
            self.db.execute("UPDATE ledger SET value = '1' WHERE key = 'bootstrap'")
        # The world chart for boat expeditions (docs/world-chart.md).
        self.chart = WorldChart(self.db, mainland, slots, expeditions)
        # Nations (docs/land-stages.md, "Nations"), and the outcome of each
        # leader's request until its agent acknowledges it.
        self.nations = Nations(self.db)
        self.db.execute('''CREATE TABLE IF NOT EXISTS nation_result(
            store TEXT NOT NULL, id INTEGER NOT NULL, text TEXT, PRIMARY KEY(store, id))''')
        # Shared player records (records.py): staff records about accounts,
        # written here only, published as files beside the regions.
        player_records.init_group(self.db)
        root = os.path.dirname(os.path.abspath(path))
        self.records = player_records.Snapshots(
            self.db, records_dir or os.path.join(root, player_records.RECORDS_DIR),
            activity_db if activity_db is not None else os.path.join(root, 'player-activity.sqlite'))
        # Hidden karma (karma.py): per-ckey files in shared-records/karma/.
        self.karma = player_karma.KarmaFiles(self.db, self.records.root)

    def close(self):
        self.db.close()

    def enroll(self, region, url, token):
        if not url.startswith('http://127.0.0.1:'):
            raise ValueError('the pilot coordinator only reaches loopback agents')
        self.db.execute('BEGIN IMMEDIATE')
        try:
            old = self.regions().get(region)
            roster = json.loads(self._ledger('roster'))
            self.db.execute('INSERT OR REPLACE INTO region VALUES (?, ?, ?)', (region, url, token))
            if roster and old != (url, token):
                roster = sorted(set(roster) | {region})
                self.db.execute("UPDATE ledger SET value = ? WHERE key = 'roster'", (json.dumps(roster),))
                if self._ledger('recovery') != 'quarantined':
                    self.db.execute("UPDATE ledger SET value = 'unreconciled' WHERE key = 'recovery'")
            self.db.execute('COMMIT')
        except Exception:
            self.db.execute('ROLLBACK')
            raise

    def regions(self):
        return {r: (u, t) for r, u, t in self.db.execute('SELECT region, url, token FROM region ORDER BY region')}

    def _ledger(self, key):
        return self.db.execute('SELECT value FROM ledger WHERE key = ?', (key,)).fetchone()[0]

    def recovery_status(self):
        return {'state': self._ledger('recovery'),
                'roster': json.loads(self._ledger('roster')),
                'bootstrap_requested': self._ledger('bootstrap') == '1'}

    def home(self, ckey):
        row = self.db.execute('SELECT region FROM home WHERE ckey = ?', (ckey,)).fetchone()
        return row[0] if row else None

    def _lobby_snapshot(self, ckey):
        """One read transaction, without holding a DB lock across agent I/O."""
        self.db.execute('BEGIN')
        try:
            recovery = self.recovery_status()
            regions = self.regions()
            if recovery['state'] != 'ready' or not regions or set(recovery['roster']) != regions.keys():
                return None
            return (regions, self._ledger('epoch'), int(self._ledger('rev')), self.home(ckey),
                    bool(self.db.execute('SELECT 1 FROM train_account_lock WHERE ckey = ?', (ckey,)).fetchone()),
                    bool(self.db.execute('SELECT 1 FROM travelling WHERE ckey = ?', (ckey,)).fetchone()))
        finally:
            self.db.execute('ROLLBACK')  # read-only, including early returns

    def lobby_home(self, ckey):
        """Resolve an account's route without claiming custody or starting a world.

        Only the reconciled coordinator is authoritative. Its cached travel
        rows do not rule out a new, uncollected request in a region, so every
        enrolled agent must give a fresh, consistent answer before we route.
        No endpoint is exposed for this coordinator method in this slice.
        The destination still checks admission after handoff.
        """
        unavailable = {'state': 'UNAVAILABLE'}
        if not account_key_valid(ckey):
            return unavailable
        try:
            snapshot = self._lobby_snapshot(ckey)
        except (sqlite3.Error, ValueError, TypeError, IndexError):
            return unavailable
        if snapshot is None:
            return unavailable
        regions, epoch, rev, home, train_locked, travelling = snapshot
        if train_locked:
            return {'state': 'PENDING'}
        if travelling:
            return {'state': 'TRAVELLING'}
        barriers = set()
        deadline = time.monotonic() + 2
        for region, (url, token) in regions.items():
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                return unavailable
            try:
                answer = call(url, token, '/lobby/account-status', {'ckey': ckey}, timeout=min(1, remaining))
            except (OSError, ValueError):
                return unavailable
            if type(answer) is not dict or answer.get('ok') is not True:
                return unavailable
            status = answer.get('result')
            if (type(status) is not dict or status.get('region') != region or status.get('group') != self.group
                    or status.get('epoch') != epoch or type(status.get('rev')) is not int or status['rev'] != rev
                    or status.get('state') not in ('CLEAR', 'PENDING', 'TRAVELLING')):
                return unavailable
            barriers.add(status['state'])
        if time.monotonic() >= deadline:
            return unavailable
        try:
            if self._lobby_snapshot(ckey) != snapshot:
                return unavailable
        except (sqlite3.Error, ValueError, TypeError, IndexError):
            return unavailable
        if 'PENDING' in barriers:
            return {'state': 'PENDING'}
        if 'TRAVELLING' in barriers:
            return {'state': 'TRAVELLING'}
        region = home if home is not None else self.start_region
        if region not in regions:
            return unavailable
        return {'state': 'HOME' if home is not None else 'NO_HOME', 'region': region}

    def homes(self):
        return {c: r for c, r in self.db.execute('SELECT ckey, region FROM home WHERE region IS NOT NULL ORDER BY ckey')}

    def _set_home(self, ckey, region):
        rev = int(self._ledger('rev')) + 1
        self.db.execute("UPDATE ledger SET value = ? WHERE key = 'rev'", (str(rev),))
        self.db.execute('INSERT OR REPLACE INTO home VALUES (?, ?, ?)', (ckey, region, rev))
        # A colony start belongs to the land it was granted for.
        self.db.execute('DELETE FROM colony_grant WHERE ckey = ? AND region IS NOT ?', (ckey, region))

    def set_land(self, region, stage, paused, by=None, now=None):
        """Set a land's stage and pause. Admins may correct a stage in either
        direction; no home is ever moved by a stage change. Returns False for a
        request that names the mainland, an unknown land or a bad value."""
        if region == self.mainland or region not in self.regions() or not land_id_valid(region):
            return False
        if stage not in LAND_STAGES or paused not in (True, False) or (by is not None and not account_key_valid(by)):
            return False
        self.db.execute('INSERT OR REPLACE INTO land VALUES (?, ?, ?, ?, ?)',
                        (region, stage, 1 if paused else 0, by, int(now if now is not None else time.time())))
        return True

    def lands(self, now=None):
        """Every enrolled land's stage and readiness (land_rows, land_readiness)."""
        lands = land_rows(self.db, self.regions(), self.mainland)
        return land_readiness(self.db, lands, self.mainland, time.time() if now is None else now)

    def record_land_sample(self, region, sample, now=None):
        """Adds one world's population sample to its hourly bucket and forgets
        buckets older than the readiness window."""
        if type(sample) is not dict or type(sample.get('players')) is not int or type(sample.get('living')) is not int:
            return False
        now = time.time() if now is None else now
        # A world that stopped sampling (asleep, stopped) leaves its last
        # sample in the agent; an old one counts for nothing.
        if type(sample.get('at')) is not int or not now - SAMPLE_FRESH_SECONDS <= sample['at'] <= now + 60:
            return False
        players, living = sample['players'], sample['living']
        if not 0 <= players <= 1000 or not 0 <= living <= 10000:
            return False
        if players:
            self.chart.visit(region, now)
        colonies = sample.get('colonies', [])
        if type(colonies) is not list or not all(colony_valid(c) for c in colonies):
            return False
        # The world's own list is the truth: a colony it no longer reports is gone.
        quiet = dict(self.db.execute('SELECT name, quiet_since FROM colony WHERE region = ?', (region,)))
        self.db.execute('DELETE FROM colony WHERE region = ?', (region,))
        for c in colonies:
            since = None if c['members'] >= COLONY_KEEP_MEMBERS else (quiet.get(c['name']) or int(now))
            self.db.execute('INSERT OR REPLACE INTO colony(region, parent, name, founded, members, quiet_since) '
                            'VALUES (?, ?, ?, ?, ?, ?)',
                            (region, c['parent'], c['name'], int(now) - c['age_hours'] * 3600, c['members'], since))
        hour = int(now // 3600)
        self.db.execute('INSERT INTO land_hour VALUES (?, ?, 1, ?, ?, ?) ON CONFLICT(region, hour) DO UPDATE SET '
                        'samples = samples + 1, players_sum = players_sum + excluded.players_sum, '
                        'players_peak = MAX(players_peak, excluded.players_peak), living = excluded.living',
                        (region, hour, players, players, living))
        self.db.execute('DELETE FROM land_hour WHERE hour <= ?', (hour - READY_WINDOW_HOURS - 24,))
        return True

    def chart_request(self, request, origin=None):
        """One request from a world (origin) for the chart: an admin's 'reroll'
        of a charted tile's template or 'reveal' of the tiles round one, a
        ship's 'scout' (what she saw round a tile) or 'course' (she set course
        for a land: see WorldChart.set_course). admin is the account asking.
        Returns True when it changed the chart."""
        x, y, admin = request.get('x'), request.get('y'), request.get('admin')
        if not tile_valid(x, y) or not account_key_valid(admin):
            return False
        op, owner = request.get('op'), request.get('owner')
        if op == 'reroll':
            return self.chart.reroll(x, y, admin) is not None
        if op in ('reveal', 'scout') and owner_valid(owner):
            return bool(self.chart.reveal(owner, x, y))
        if op == 'course' and owner_valid(owner):
            return self.chart.set_course(request.get('voyage'), owner, x, y, origin, by=admin) is not None
        if op in ('access', 'pass'):
            # A faction's leader or officers, from any land, for the island it claims at x, y.
            data = request.get('data')
            if type(data) is not dict or self.chart.claims().get(owner) != '%d,%d' % (x, y):
                return False
            if op == 'access':
                return self.chart.set_access(owner, data.get('mode'), data.get('people'), admin)
            return self.chart.grant_pass(owner, data.get('account'), data.get('hours'), admin)
        if op == 'summon':
            # Somebody whose character is on a parked land came back: only they can wake it.
            return self.home(admin) == land_home(x, y) and self.chart.summon(x, y)
        # A land's own world, for its crew: x and y name the land it holds, as a check.
        found = self.chart.land_in(origin)
        if op not in ('settle', 'claim', 'unclaim', 'abandon') or not found or found[:2] != (x, y):
            return False
        if op == 'settle' and self.chart.settle(origin, admin):
            self.set_land(origin, 'FRONTIER', False)
            return True
        # A player claims only for themself; a faction's claim comes from its charter.
        personal = isinstance(owner, str) and owner.startswith('crew:')
        if personal and owner != 'crew:' + admin:
            return False
        if op == 'claim' and self.chart.claim(origin, owner, admin):
            # A faction's claim makes a colony; a player's own land is frontier, like a settled one.
            self.set_land(origin, 'FRONTIER' if personal else 'COLONY', False)
            return True
        if op == 'unclaim' and self.chart.unclaim(origin, owner, admin):
            self.set_land(origin, 'FRONTIER', False)
            return True
        if op == 'abandon' and self.chart.abandon(origin, admin):
            self.land_lost(origin)
            return True
        return False

    def chart_moves(self):
        """Lands the chart parked or gave a slot again since the last pass: the
        homes there follow the land, and its stage waits with it. A parked
        land is no region, so its residents' home is 'land:x,y' until then."""
        restored, self.chart.restored_now = self.chart.restored_now, []
        parked, self.chart.parked_now = self.chart.parked_now, []
        for slot, x, y, kept in restored:
            for (ckey,) in self.db.execute('SELECT ckey FROM home WHERE region = ?', (land_home(x, y),)).fetchall():
                self._set_home(ckey, slot)
            try:
                kept = json.loads(kept) if kept else {}
            except ValueError:
                kept = {}
            if kept.get('stage') in LAND_STAGES:
                self.set_land(slot, kept['stage'], bool(kept.get('paused')))
        for slot, x, y in parked:
            row = self.db.execute('SELECT stage, paused FROM land WHERE region = ?', (slot,)).fetchone()
            self.chart.keep(x, y, json.dumps({'stage': row[0], 'paused': bool(row[1])}) if row else None)
            for (ckey,) in self.db.execute('SELECT ckey FROM home WHERE region = ?', (slot,)).fetchall():
                self._set_home(ckey, land_home(x, y))
            # The slot's next land starts unexplored; the world reports its colonies again when it is back.
            for table in ('land', 'colony', 'colony_grant', 'land_hour'):
                self.db.execute('DELETE FROM %s WHERE region = ?' % table, (slot,))
        return bool(restored or parked)

    def land_lost(self, region):
        """An abandoned land: whoever was homed there starts in the start region
        again, and the slot's next land starts unexplored."""
        for (ckey,) in self.db.execute('SELECT ckey FROM home WHERE region = ?', (region,)).fetchall():
            self._set_home(ckey, self.start_region)
        self.db.execute('DELETE FROM land WHERE region = ?', (region,))

    def decide(self, source, request):
        """Apply one account request from region source to the ledger."""
        if self._ledger('recovery') != 'ready':
            return
        ckey, op, region = request['ckey'], request['op'], request['region']
        if not self.train_request_allowed(request):
            return
        home = self.home(ckey)
        if op == 'arrive' and region == source:
            # A recorded trip delivered the character here; custody already decided.
            if home != source:
                self._set_home(ckey, source)
            # It is there now, whatever a source that has since gone quiet last said.
            self.db.execute('DELETE FROM travelling WHERE ckey = ? AND region = ?', (ckey, source))
        elif op == 'depart' and home in (None, source) and region != source:
            self._set_home(ckey, region)
        elif op == 'release' and home == source:
            # A death sends the player back to the start region, not anywhere.
            if home != self.start_region:
                self._set_home(ckey, self.start_region)
        elif op == 'claim' and home is None and region == source and self.start_region in (None, source):
            self._set_home(ckey, source)
        elif op == 'colony' and home in (None, source) and region != source and self.colony_start_allowed(
                source, region, request.get('faction')):
            # The faction's own land vouches for its member; the colony must
            # stand in a land open to colony starts.
            self._set_home(ckey, region)
            self.db.execute('INSERT OR REPLACE INTO colony_grant VALUES (?, ?, ?)', (ckey, region, request['faction']))
        elif op == 'start' and home == source and region != source and self.wild_start_allowed(region):
            # An open land's wilds, chosen in the lobby of the account's home.
            self._set_home(ckey, region)
        elif op == 'colony_used' and region == source:
            self.db.execute('DELETE FROM colony_grant WHERE ckey = ? AND region = ?', (ckey, source))
        elif op == 'custody' and home is None and region == source:
            # A living character of an unhomed account is here (a lost ledger
            # forgot it); it stays where it lives.
            self._set_home(ckey, source)

    def wild_start_allowed(self, region):
        """New characters may start in region's wilds: an OPEN land, not paused."""
        entry = land_rows(self.db, [region], self.mainland).get(region) if region in self.regions() else None
        return bool(entry) and entry['stage'] == 'OPEN' and not entry['paused']

    def colony_start_allowed(self, source, region, faction, now=None):
        """A member of faction (founded in source) may start at its colony in
        region: the colony stands there and the land takes colony starts."""
        if not faction_id_valid(faction) or faction[4:].partition(':')[0] != source:
            return False
        entry = land_rows(self.db, [region], self.mainland).get(region) if region in self.regions() else None
        # A pause stops wild starts only; colony starts keep working.
        if not entry or entry['stage'] not in ('COLONY', 'OPEN'):
            return False
        # A colony nobody lives in pauses its start until members are back.
        row = self.db.execute('SELECT quiet_since FROM colony WHERE region = ? AND parent = ?', (region, faction)).fetchone()
        return row is not None and not colony_paused(row[0], time.time() if now is None else now)

    def _proven_authority(self, roster, regions, asked, epoch):
        """Whether the agents that answer prove this database is still the
        group's home authority, so a hold (unreconciled after an enrolment, or a
        quarantine from an enrolment racing a pass, before that was fixed) lifts
        by itself. This database has decided homes (rev above 0) and every roster
        member is still enrolled. Each answering agent holds this database's
        epoch with no newer revision, or is a new region that never had a ledger
        or train custody, and at least one holds the epoch. A member that is down
        (a stopped region runs no agent) loses nothing: its accounts' homes are
        in this ledger, and it gets the rows it missed when it answers again."""
        rev = int(self._ledger('rev'))
        if rev <= 0 or not roster or not set(roster) <= set(regions) or not asked:
            return False
        proven = False
        for answer in asked.values():
            if answer.get('epoch') == epoch:
                if int(answer.get('rev') or 0) > rev:
                    return False
                proven = True
            elif answer.get('epoch') or answer.get('train_history') or int(answer.get('rev') or 0):
                return False
        return proven

    def homes_once(self):
        """Decide every queued account request and bring each agent's ledger copy
        up to date. Returns the number of requests decided."""
        # Directory and roster from one snapshot: setup enrols a new region
        # (both tables in one transaction) while this coordinator runs, and a
        # roster read after the slow agent calls below would miss that region.
        self.db.execute('BEGIN')
        try:
            regions = self.regions()
            roster = json.loads(self._ledger('roster'))
        finally:
            self.db.execute('COMMIT')
        epoch = self._ledger('epoch')
        asked = {}
        for name, (url, token) in regions.items():
            try:
                answer = call(url, token, '/accounts')
            except (OSError, ValueError):
                continue  # down: its requests and rows wait for a later pass
            if answer.get('ok'):
                asked[name] = answer['result']
        if roster and not set(roster) <= set(regions):
            # A member left the directory: it may still hold bodies or trains.
            self.db.execute("UPDATE ledger SET value = 'quarantined' WHERE key = 'recovery'")
        elif roster and set(roster) != set(regions):
            # An enrolled region the roster lacks only adds a member: wait for it.
            self.db.execute('BEGIN IMMEDIATE')
            try:
                roster = sorted(set(roster) | set(regions))
                self.db.execute("UPDATE ledger SET value = ? WHERE key = 'roster'", (json.dumps(roster),))
                if self._ledger('recovery') != 'quarantined':
                    self.db.execute("UPDATE ledger SET value = 'unreconciled' WHERE key = 'recovery'")
                self.db.execute('COMMIT')
            except Exception:
                self.db.execute('ROLLBACK')
                raise
        if self._ledger('recovery') != 'ready':
            if not self._proven_authority(roster, regions, asked, epoch):
                if self._ledger('recovery') == 'quarantined' or not regions or set(asked) != set(regions):
                    return 0
            # A replacement coordinator must not discard surviving train custody
            # or let a third world create a second body from an empty home map.
            if any(a.get('train_history') and a.get('epoch') != epoch for a in asked.values()):
                self.db.execute("UPDATE ledger SET value = 'quarantined' WHERE key = 'recovery'")
                return 0
            if not roster:
                if self._ledger('bootstrap') != '1':
                    return 0
                # The flag is an operator assertion that no omitted peers exist.
                # Any known previous epoch/history disproves clean bootstrap.
                if any(a.get('epoch') or a.get('train_history') for a in asked.values()):
                    self.db.execute("UPDATE ledger SET value = 'quarantined' WHERE key = 'recovery'")
                    return 0
            self.db.execute('BEGIN IMMEDIATE')
            try:
                if not roster:
                    self.db.execute("UPDATE ledger SET value = ? WHERE key = 'roster'", (json.dumps(sorted(regions)),))
                self.db.execute("UPDATE ledger SET value = 'ready' WHERE key = 'recovery'")
                self.db.execute('COMMIT')
            except Exception:
                self.db.execute('ROLLBACK')
                raise
        # Each region's requests in the order it made them (a refused trip's
        # depart then arrive must not swap). Across regions only claims wait
        # for everything else, so an arrival or a living body beats a new start.
        self.db.execute('BEGIN IMMEDIATE')
        try:
            lease_decisions = {name: [self.decide_train_lease(name, r) for r in a.get('train_requests', [])]
                               for name, a in asked.items()}
            for name, a in asked.items():
                self.db.execute('DELETE FROM travelling WHERE source = ?', (name,))
                for row in a.get('travelling') or []:
                    if type(row) is dict and isinstance(row.get('ckey'), str) and isinstance(row.get('region'), str) \
                            and row['ckey'] and row['region'] and row['region'] != name:
                        self.db.execute('INSERT OR REPLACE INTO travelling VALUES (?, ?, ?)', (name, row['ckey'], row['region']))
            queue = []
            for name, a in asked.items():
                store, ids = str(a.get('store') or ''), [r['id'] for r in a.get('requests', [])]
                # Acknowledged requests are gone from the agent; forget them.
                old = {i for (i,) in self.db.execute('SELECT id FROM decided WHERE store = ?', (store,))}
                for i in old - set(ids):
                    self.db.execute('DELETE FROM decided WHERE store = ? AND id = ?', (store, i))
                queue.extend((r.get('op') == 'claim', name, r['id'], store, r)
                             for r in a.get('requests', []) if r['id'] not in old)
            queue.sort(key=lambda t: t[:3])
            for _, name, request_id, store, request in queue:
                self.decide(name, request)
                self.db.execute('INSERT OR IGNORE INTO decided VALUES (?, ?)', (store, request_id))
            # Admin land stage changes, each region's in its own order. Their
            # ids live in a store of their own so they never meet account ids.
            land_done = {}
            for name, a in asked.items():
                store = 'land:' + str(a.get('store') or '')
                requests = [r for r in a.get('land_requests') or [] if type(r) is dict and isinstance(r.get('id'), int)]
                ids = [r['id'] for r in requests]
                old = {i for (i,) in self.db.execute('SELECT id FROM decided WHERE store = ?', (store,))}
                for i in old - set(ids):
                    self.db.execute('DELETE FROM decided WHERE store = ? AND id = ?', (store, i))
                for r in requests:
                    if r['id'] not in old:
                        self.set_land(r.get('region'), r.get('stage'), r.get('paused'), r.get('admin'))
                        self.db.execute('INSERT OR IGNORE INTO decided VALUES (?, ?)', (store, r['id']))
                land_done[name] = ids
                self.record_land_sample(name, a.get('land_sample'))
            chart_done, chart_pass_results = {}, {}
            for name, a in asked.items():
                store = 'chart:' + str(a.get('store') or '')
                requests = [r for r in a.get('chart_requests') or [] if type(r) is dict and isinstance(r.get('id'), int)]
                ids = [r['id'] for r in requests]
                old = {i for (i,) in self.db.execute('SELECT id FROM decided WHERE store = ?', (store,))}
                for i in old - set(ids):
                    self.db.execute('DELETE FROM decided WHERE store = ? AND id = ?', (store, i))
                    self.db.execute('DELETE FROM chart_pass_result WHERE store = ? AND id = ?', (store, i))
                for r in requests:
                    if r['id'] not in old:
                        applied = self.chart_request(r, name)
                        self.db.execute('INSERT OR IGNORE INTO decided VALUES (?, ?)', (store, r['id']))
                        # Commit the decision alongside its pass mutation. A lost /homes
                        # reply can resend the decision without changing the pass again.
                        if r.get('op') == 'pass':
                            self.db.execute('INSERT INTO chart_pass_result VALUES (?, ?, ?)', (store, r['id'], bool(applied)))
                chart_done[name] = ids
                chart_pass_results[name] = [{'id': i, 'applied': bool(applied)} for i, applied in self.db.execute(
                    'SELECT id, applied FROM chart_pass_result WHERE store = ? ORDER BY id', (store,))]
            # Nation requests, each region's in its own order. An outcome is
            # kept until the agent drops the request, so a lost answer is
            # sent again rather than decided twice.
            nation_results = {}
            for name, a in asked.items():
                store = 'nation:' + str(a.get('store') or '')
                requests = [r for r in a.get('nation_requests') or [] if type(r) is dict and isinstance(r.get('id'), int)]
                ids = {r['id'] for r in requests}
                old = dict(self.db.execute('SELECT id, text FROM nation_result WHERE store = ?', (store,)))
                for i in set(old) - ids:
                    self.db.execute('DELETE FROM nation_result WHERE store = ? AND id = ?', (store, i))
                for r in requests:
                    if r['id'] not in old:
                        old[r['id']] = self.nations.decide(name, r)
                        self.db.execute('INSERT INTO nation_result VALUES (?, ?, ?)', (store, r['id'], old[r['id']]))
                nation_results[name] = [{'id': i, 'text': old[i]} for i in sorted(ids)]
            self.db.execute('COMMIT')
        except Exception:
            self.db.execute('ROLLBACK')
            raise
        rev = int(self._ledger('rev'))
        lands = self.lands()
        # Courses whose land the host has opened (or could not) since the last pass,
        # and lands nobody has been to for 7 days.
        self.chart.refresh_courses()
        for region in self.chart.expire():
            self.land_lost(region)
        self.chart_moves()
        chart_rev = self.chart.key()
        chart = None
        nations = self.nations.snapshot()
        for name, answer in asked.items():
            url, token = regions[name]
            since = answer.get('rev', 0) if answer.get('epoch') == epoch else 0
            rows = [{'ckey': c, 'region': r} for c, r in self.db.execute(
                'SELECT ckey, region FROM home WHERE rev > ? ORDER BY rev', (since,))]
            body = {'epoch': epoch, 'rev': rev, 'rows': rows, 'reset': since == 0,
                    'mainland': self.mainland, 'start_region': self.start_region, 'train_locks': self.train_locks(),
                    'train_decisions': lease_decisions.get(name, []),
                    'lands': lands, 'land_done': land_done.get(name, []),
                    'chart_done': chart_done.get(name, []),
                    'chart_pass_results': chart_pass_results.get(name, []),
                    'nations': nations, 'nation_results': nation_results.get(name, []),
                    'colony_grants': [{'ckey': c, 'faction': f} for c, f in self.db.execute(
                        'SELECT ckey, faction FROM colony_grant WHERE region = ? ORDER BY ckey', (name,))],
                    'travelling': dict(self.db.execute(
                        'SELECT ckey, source FROM travelling WHERE region = ? ORDER BY source', (name,))),
                    'done': [r['id'] for r in answer.get('requests', [])]}
            # The chart only goes to an agent whose copy is older.
            if answer.get('chart_rev') != chart_rev:
                chart = chart or self.chart.snapshot()
                body['chart'] = chart
            try:
                call(url, token, '/homes', body)
            except (OSError, ValueError):
                # Its requests stay queued; deciding them again changes nothing.
                continue
        return len(queue)

    def relay_radio_once(self):
        """Fan every region's radio envelopes, relay heartbeats, OOC and admin chat lines, admin announcements and strikes out to every other region.

        Radio is ephemeral: an agent that is down keeps nothing waiting, and a
        pass that fails for one region still serves the others. Returns the
        number of envelopes and OOC lines handed over.
        """
        regions = self.regions()
        collected = {}
        for name, (url, token) in regions.items():
            try:
                answer = call(url, token, '/radio/outbox', timeout=2)
            except (OSError, ValueError):
                continue
            result = answer.get('result') if answer.get('ok') else None
            if type(result) is dict:
                ooc = result.get('ooc')
                strikes = result.get('strikes')
                asay = result.get('asay')
                announce = result.get('announce')
                collected[name] = (result.get('envelopes') or [], result.get('heartbeats') or {},
                                   ooc if isinstance(ooc, list) else [], strikes if isinstance(strikes, list) else [],
                                   asay if isinstance(asay, list) else [], announce if isinstance(announce, list) else [])
        delivered = 0
        for name, (url, token) in regions.items():
            envelopes = [e for source, (batch, _, _, _, _, _) in collected.items() if source != name for e in batch
                         if type(e) is dict and e.get('group') == self.group]
            heartbeats = {source: beats for source, (_, beats, _, _, _, _) in collected.items() if source != name}
            # OOC lines go to every other region whether or not it has a relay.
            ooc = [e for source, (_, _, lines, _, _, _) in collected.items() if source != name for e in lines
                   if type(e) is dict and e.get('group') == self.group]
            # A strike goes only to the region it names.
            strikes = [e for source, (_, _, _, fired, _, _) in collected.items() if source != name for e in fired
                       if type(e) is dict and e.get('group') == self.group and e.get('target') == name]
            # Admin chat goes to every other region, like OOC, in its own list.
            asay = [e for source, (_, _, _, _, lines, _) in collected.items() if source != name for e in lines
                    if type(e) is dict and e.get('group') == self.group]
            # Admin announcements go to every other region's players, in their own list.
            announce = [e for source, (_, _, _, _, _, lines) in collected.items() if source != name for e in lines
                        if type(e) is dict and e.get('group') == self.group]
            if not envelopes and not heartbeats and not ooc and not strikes and not asay and not announce:
                continue
            try:
                answer = call(url, token, '/radio/deliver',
                              {'envelopes': envelopes, 'heartbeats': heartbeats, 'ooc': ooc, 'strikes': strikes,
                               'asay': asay, 'announce': announce}, timeout=2)
            except (OSError, ValueError):
                continue
            if answer.get('ok'):
                result = answer.get('result') or {}
                delivered += result.get('queued', 0) + result.get('ooc', 0) + result.get('strikes', 0) + result.get('asay', 0)
                delivered += result.get('announce', 0)
        return delivered

    def records_once(self, now=None):
        """Collect queued player records from every agent, store them, then
        acknowledge them and rewrite the shared-records files. Records do not
        depend on the home ledger's recovery state: they hold no custody.
        Returns the number of records stored."""
        stored = 0
        for name, (url, token) in self.regions().items():
            # A world drops a record it sent once its region's pull time is
            # later than the send, so the pull time is taken before the read.
            pulled = int(time.time() if now is None else now)
            try:
                answer = call(url, token, '/records/outbox', timeout=2)
            except (OSError, ValueError):
                continue  # down: its records wait in its own store
            result = answer.get('result') if answer.get('ok') else None
            if type(result) is not dict:
                continue  # an agent too old for /records/outbox
            self.db.execute('BEGIN IMMEDIATE')
            try:
                ids, changed = player_records.store_records(self.db, name, result.get('records'), pulled)
                self.db.execute('COMMIT')
            except Exception:
                self.db.execute('ROLLBACK')
                raise
            stored += len(ids)
            self.records.dirty |= changed
            if any(isinstance(r, dict) and r.get('kind') == 'connection' for r in result.get('records') or []):
                self.records.connections_dirty = True
            if ids:
                try:
                    call(url, token, '/records/ack', {'ids': ids}, timeout=2)
                except (OSError, ValueError):
                    pass  # sent again next pass; storing it twice changes nothing
        self.records.write(now)
        self.karma.write(now, self.records.hours)
        return stored

    def relay_once(self):
        """Deliver every outbox envelope once. Returns the number delivered.
        An agent that is down (restarting, say) only holds up its own envelopes
        and those sent to it: they wait in the durable outboxes for the next pass."""
        regions = self.regions()
        delivered = 0
        for name, (url, token) in regions.items():
            try:
                answer = call(url, token, '/outbox')
            except (OSError, ValueError) as e:
                print('relay pass failed for %s: %s' % (name, e), file=sys.stderr)
                continue
            for envelope in (answer.get('result') or {}).get('envelopes', []):
                target = regions.get(envelope.get('recipient'))
                if target is None or envelope.get('group') != self.group:
                    continue
                if envelope.get('sender') != name:
                    continue
                try:
                    is_train = self.train_envelope(name, envelope)
                except ValueError:
                    continue  # unresolved custody stays in the durable outbox
                forwarded = dict(envelope)
                if is_train:
                    forwarded['train_custody_epoch'] = self._ledger('epoch')
                try:
                    result = call(target[0], target[1], '/receive', {'envelope': forwarded})
                except (OSError, ValueError) as e:
                    print('relay pass failed for %s: %s' % (envelope.get('recipient'), e), file=sys.stderr)
                    continue
                if result.get('ok'):
                    delivered += 1
                    reply = result['result'].get('reply')
                    if reply:
                        try:
                            call(url, token, '/receive', {'envelope': reply})
                        except (OSError, ValueError):
                            pass  # the sender's agent went down meanwhile; this pass carries on
        return delivered


def _xy(parser, text):
    try:
        x, y = (int(v) for v in text.split(','))
    except ValueError:
        parser.error('a tile is X,Y, got %r' % text)
    if not tile_valid(x, y):
        parser.error('tile %r is off the chart' % text)
    return x, y


def chart_cli(parser, chart, args):
    """The --chart options: inspect and adjust the world chart on the host."""
    if args.chart_pin:
        region, _, at = args.chart_pin.partition('=')
        if not chart.pin(region, *_xy(parser, at)):
            parser.error('cannot pin %r: the tile holds a template or another land' % args.chart_pin)
    if args.chart_reveal:
        owner, _, at = args.chart_reveal.partition('=')
        if not owner_valid(owner):
            parser.error('an owner is admin, faction:NAME or crew:CKEY')
        rolled = chart.reveal(owner, *_xy(parser, at))
        print('charted %d new land(s)' % len(rolled))
    if args.chart_reroll:
        if chart.reroll(*_xy(parser, args.chart_reroll), by='host') is None:
            parser.error('only a charted tile with no world can be rerolled')
    if args.chart is not None:
        owner = args.chart or None
        if owner is not None and not owner_valid(owner):
            parser.error('an owner is admin, faction:NAME or crew:CKEY')
        if args.chart_json:
            print(json.dumps(chart.snapshot(owner), sort_keys=True))
        else:
            print('\n'.join(chart.text_rows(owner)))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--db', required=True)
    parser.add_argument('--group', required=True)
    parser.add_argument('--region', action='append', default=[], metavar='NAME=URL=TOKEN_FILE',
                        help='enroll a loopback agent; repeatable')
    parser.add_argument('--mainland', help="the group's main region: era source and land-stage reference")
    parser.add_argument('--start-region', help='region where new characters start, and fallen ones with no bed '
                        'keeping their home (default: the mainland)')
    parser.add_argument('--interval', type=float, default=5.0, help='seconds between relay passes')
    parser.add_argument('--radio-interval', type=float, default=1.0, help='seconds between radio passes')
    parser.add_argument('--bootstrap-new-group', action='store_true',
                        help='explicitly assert a new group with no previous peers, epochs or custody; never use for recovery')
    parser.add_argument('--records-dir', help='where the shared player record files go (default: shared-records beside --db)')
    parser.add_argument('--activity-db', help='the host player activity database (default: player-activity.sqlite beside --db)')
    parser.add_argument('--once', action='store_true', help='relay one pass and exit')
    parser.add_argument('--lands', action='store_true', help='print every land\'s stage as JSON and exit')
    parser.add_argument('--set-land', metavar='REGION=STAGE[,paused]',
                        help='set one land\'s stage (%s), optionally paused, and exit' % ', '.join(LAND_STAGES))
    parser.add_argument('--chart', nargs='?', const='', metavar='OWNER',
                        help='print the world chart (everything, or what OWNER has seen) and exit')
    parser.add_argument('--chart-json', action='store_true', help='with --chart, print JSON instead of text')
    parser.add_argument('--chart-reveal', metavar='OWNER=X,Y', help='chart the tiles round X,Y for OWNER and exit')
    parser.add_argument('--chart-reroll', metavar='X,Y', help='give a charted tile a new template and exit')
    parser.add_argument('--chart-pin', metavar='REGION=X,Y', help='put a mainland region on a fixed tile and exit')
    parser.add_argument('--slots', default='', metavar='A,B,...',
                        help="the group's EXPEDITION regions, which ships' courses may open lands in")
    parser.add_argument('--expeditions', metavar='DIR', help='where the host keeps its expedition slots (<group root>/expeditions)')
    args = parser.parse_args(argv)
    enrollments = []
    for item in args.region:
        parts = item.split('=', 2)
        if len(parts) != 3 or not all(parts):
            parser.error('--region takes NAME=URL=TOKEN_FILE, got %r' % item)
        with open(parts[2], encoding='utf-8') as f:
            enrollments.append((parts[0], parts[1], f.read().strip()))
    coordinator = Coordinator(args.db, args.group, args.mainland, args.bootstrap_new_group,
                              [s for s in args.slots.split(',') if s], args.expeditions, args.start_region,
                              args.records_dir, args.activity_db)
    if args.chart is not None or args.chart_reveal or args.chart_reroll or args.chart_pin:
        try:
            chart_cli(parser, coordinator.chart, args)
            return
        finally:
            coordinator.close()
    if args.lands or args.set_land:
        try:
            if args.set_land:
                region, _, rest = args.set_land.partition('=')
                stage, _, flag = rest.partition(',')
                if flag not in ('', 'paused') or not coordinator.set_land(region, stage.upper(), flag == 'paused'):
                    parser.error('cannot set %r: name an enrolled land other than the mainland and one of %s'
                                 % (args.set_land, ', '.join(LAND_STAGES)))
            print(json.dumps(coordinator.lands(), sort_keys=True))
            return
        finally:
            coordinator.close()
    try:
        for name, url, token in enrollments:
            coordinator.enroll(name, url, token)
        radio_interval = max(0.1, min(args.radio_interval, args.interval))
        next_ledger = 0.0
        while True:
            now = time.monotonic()
            if now >= next_ledger:
                next_ledger = now + args.interval
                try:
                    coordinator.relay_once()
                except (OSError, ValueError) as e:
                    # An agent is down or answered garbage: its outbox waits for the next pass.
                    print('relay pass failed: %s' % e, file=sys.stderr)
                # Homes are decided even when one agent's outbox is unreachable:
                # homes_once skips agents that are down by itself.
                try:
                    coordinator.homes_once()
                    status = coordinator.recovery_status()
                    if status['state'] != 'ready':
                        print('Home authority held (%s, roster %s): no answering agent proves this database\'s epoch. '
                              'It lifts once a running agent holds it; otherwise '
                              'restore the original coordinator database. --bootstrap-new-group is only for '
                              'a genuinely new, clean group.' % (status['state'], ', '.join(status['roster']) or 'empty'),
                              file=sys.stderr)
                except (OSError, ValueError) as e:
                    print('home pass failed: %s' % e, file=sys.stderr)
                try:
                    coordinator.records_once()
                except (OSError, ValueError, sqlite3.Error) as e:
                    print('player records pass failed: %s' % e, file=sys.stderr)
            coordinator.relay_radio_once()
            if args.once:
                return
            time.sleep(radio_interval)
    finally:
        coordinator.close()


if __name__ == '__main__':
    main()
