"""Small coordinator: a region directory, envelope relay and home-world ledger.

It holds no custody and no transfer phase. Losing its file only pauses
transfers until the directory is enrolled again.

The home ledger says which region each account may play in. With a mainland
region, a new account and a player whose character died start there, and
reach the other regions only by travel; without one, the first claim wins. Regions queue
account requests in their agents; each pass decides them in a fixed order and
sends every agent the ledger rows it has not seen. Losing the file starts a
new ledger epoch: agents drop their copies and homes are claimed again.
"""
import secrets
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


class Coordinator:
    def __init__(self, path, group, mainland=None):
        self.group = group
        self.mainland = mainland
        self.db = sqlite3.connect(path, isolation_level=None)
        self.db.execute('PRAGMA journal_mode=WAL')
        self.db.execute('PRAGMA synchronous=FULL')
        self.db.execute('''CREATE TABLE IF NOT EXISTS region(
            region TEXT PRIMARY KEY, url TEXT NOT NULL, token TEXT NOT NULL)''')
        self.db.execute('''CREATE TABLE IF NOT EXISTS home(
            ckey TEXT PRIMARY KEY, region TEXT, rev INTEGER NOT NULL)''')
        self.db.execute('CREATE TABLE IF NOT EXISTS ledger(key TEXT PRIMARY KEY, value TEXT NOT NULL)')
        # Requests already decided but not yet acknowledged by their agent, so a
        # lost acknowledgement never replays an old request over newer ones.
        self.db.execute('''CREATE TABLE IF NOT EXISTS decided(
            store TEXT NOT NULL, id INTEGER NOT NULL, PRIMARY KEY(store, id))''')
        self.db.execute("INSERT OR IGNORE INTO ledger VALUES ('epoch', ?)", (secrets.token_hex(8),))
        self.db.execute("INSERT OR IGNORE INTO ledger VALUES ('rev', '0')")

    def close(self):
        self.db.close()

    def enroll(self, region, url, token):
        if not url.startswith('http://127.0.0.1:'):
            raise ValueError('the pilot coordinator only reaches loopback agents')
        self.db.execute('INSERT OR REPLACE INTO region VALUES (?, ?, ?)', (region, url, token))

    def regions(self):
        return {r: (u, t) for r, u, t in self.db.execute('SELECT region, url, token FROM region ORDER BY region')}

    def _ledger(self, key):
        return self.db.execute('SELECT value FROM ledger WHERE key = ?', (key,)).fetchone()[0]

    def home(self, ckey):
        row = self.db.execute('SELECT region FROM home WHERE ckey = ?', (ckey,)).fetchone()
        return row[0] if row else None

    def homes(self):
        return {c: r for c, r in self.db.execute('SELECT ckey, region FROM home WHERE region IS NOT NULL ORDER BY ckey')}

    def _set_home(self, ckey, region):
        rev = int(self._ledger('rev')) + 1
        self.db.execute("UPDATE ledger SET value = ? WHERE key = 'rev'", (str(rev),))
        self.db.execute('INSERT OR REPLACE INTO home VALUES (?, ?, ?)', (ckey, region, rev))

    def decide(self, source, request):
        """Apply one account request from region source to the ledger."""
        ckey, op, region = request['ckey'], request['op'], request['region']
        home = self.home(ckey)
        if op == 'arrive' and region == source:
            # A recorded trip delivered the character here; custody already decided.
            if home != source:
                self._set_home(ckey, source)
        elif op == 'depart' and home in (None, source) and region != source:
            self._set_home(ckey, region)
        elif op == 'release' and home == source:
            # A death sends the player back to the mainland, not anywhere.
            if home != self.mainland:
                self._set_home(ckey, self.mainland)
        elif op == 'claim' and home is None and region == source and self.mainland in (None, source):
            self._set_home(ckey, source)
        elif op == 'custody' and home is None and region == source:
            # A living character of an unhomed account is here (a lost ledger
            # forgot it); it stays where it lives.
            self._set_home(ckey, source)

    def homes_once(self):
        """Decide every queued account request and bring each agent's ledger copy
        up to date. Returns the number of requests decided."""
        regions = self.regions()
        epoch = self._ledger('epoch')
        asked = {}
        for name, (url, token) in regions.items():
            try:
                answer = call(url, token, '/accounts')
            except (OSError, ValueError):
                continue  # down: its requests and rows wait for a later pass
            if answer.get('ok'):
                asked[name] = answer['result']
        # Each region's requests in the order it made them (a refused trip's
        # depart then arrive must not swap). Across regions only claims wait
        # for everything else, so an arrival or a living body beats a new start.
        self.db.execute('BEGIN IMMEDIATE')
        try:
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
            self.db.execute('COMMIT')
        except Exception:
            self.db.execute('ROLLBACK')
            raise
        rev = int(self._ledger('rev'))
        for name, answer in asked.items():
            url, token = regions[name]
            since = answer.get('rev', 0) if answer.get('epoch') == epoch else 0
            rows = [{'ckey': c, 'region': r} for c, r in self.db.execute(
                'SELECT ckey, region FROM home WHERE rev > ? ORDER BY rev', (since,))]
            try:
                call(url, token, '/homes', {'epoch': epoch, 'rev': rev, 'rows': rows, 'reset': since == 0,
                                            'mainland': self.mainland,
                                            'done': [r['id'] for r in answer.get('requests', [])]})
            except (OSError, ValueError):
                # Its requests stay queued; deciding them again changes nothing.
                continue
        return len(queue)

    def relay_once(self):
        """Deliver every outbox envelope once. Returns the number delivered."""
        regions = self.regions()
        delivered = 0
        for name, (url, token) in regions.items():
            answer = call(url, token, '/outbox')
            for envelope in (answer.get('result') or {}).get('envelopes', []):
                target = regions.get(envelope.get('recipient'))
                if target is None or envelope.get('group') != self.group:
                    continue
                result = call(target[0], target[1], '/receive', {'envelope': envelope})
                if result.get('ok'):
                    delivered += 1
                    reply = result['result'].get('reply')
                    if reply:
                        call(url, token, '/receive', {'envelope': reply})
        return delivered


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--db', required=True)
    parser.add_argument('--group', required=True)
    parser.add_argument('--region', action='append', default=[], metavar='NAME=URL=TOKEN_FILE',
                        help='enroll a loopback agent; repeatable')
    parser.add_argument('--mainland', help='region where new and dead characters start')
    parser.add_argument('--interval', type=float, default=5.0, help='seconds between relay passes')
    parser.add_argument('--once', action='store_true', help='relay one pass and exit')
    args = parser.parse_args(argv)
    enrollments = []
    for item in args.region:
        parts = item.split('=', 2)
        if len(parts) != 3 or not all(parts):
            parser.error('--region takes NAME=URL=TOKEN_FILE, got %r' % item)
        with open(parts[2], encoding='utf-8') as f:
            enrollments.append((parts[0], parts[1], f.read().strip()))
    coordinator = Coordinator(args.db, args.group, args.mainland)
    try:
        for name, url, token in enrollments:
            coordinator.enroll(name, url, token)
        while True:
            try:
                coordinator.relay_once()
                coordinator.homes_once()
            except (OSError, ValueError) as e:
                # An agent is down or answered garbage: its outbox waits for the next pass.
                print('relay pass failed: %s' % e, file=sys.stderr)
            if args.once:
                return
            time.sleep(args.interval)
    finally:
        coordinator.close()


if __name__ == '__main__':
    main()
