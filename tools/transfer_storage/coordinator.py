"""Small coordinator: a region directory plus envelope relay.

It holds no custody and no transfer phase. Losing its file only pauses
transfers until the directory is enrolled again.
"""
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
    def __init__(self, path, group):
        self.group = group
        self.db = sqlite3.connect(path, isolation_level=None)
        self.db.execute('PRAGMA journal_mode=WAL')
        self.db.execute('PRAGMA synchronous=FULL')
        self.db.execute('''CREATE TABLE IF NOT EXISTS region(
            region TEXT PRIMARY KEY, url TEXT NOT NULL, token TEXT NOT NULL)''')

    def close(self):
        self.db.close()

    def enroll(self, region, url, token):
        if not url.startswith('http://127.0.0.1:'):
            raise ValueError('the pilot coordinator only reaches loopback agents')
        self.db.execute('INSERT OR REPLACE INTO region VALUES (?, ?, ?)', (region, url, token))

    def regions(self):
        return {r: (u, t) for r, u, t in self.db.execute('SELECT region, url, token FROM region ORDER BY region')}

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
    coordinator = Coordinator(args.db, args.group)
    try:
        for name, url, token in enrollments:
            coordinator.enroll(name, url, token)
        while True:
            try:
                coordinator.relay_once()
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
