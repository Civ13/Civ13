"""Loopback HTTP agent for one region's RegionStore.

DM reaches it with rustg_http_request_async; the coordinator reaches it to move
envelopes. It listens on 127.0.0.1 only, refuses other client addresses, and
requires the shared token from the region's token file on every request.
Requests are served one at a time, so the store sees no concurrency.
"""
import argparse
import hmac
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

if __package__ in (None, ''):
    import os
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from tools.transfer_storage.radio import RadioError, RadioRelay  # noqa: E402
from tools.transfer_storage.region import RegionHeld, RegionStore, TransferError  # noqa: E402

MAX_BODY = 1 << 20  # 1 MiB per request


def _load(store, body):
    seq = store.reconcile_load(body['generation'], body['effects'], body['ledger_seq'], body.get('fresh') in (True, 1))
    if seq is None:
        # reconcile_load just put the region on hold; say so like other refusals.
        raise RegionHeld(store.status().get('hold_reason') or 'rollback')
    # Journaled effects the loaded save lacks; the world applies them again.
    return {'ledger_seq': seq, 'replay': store.replay()}


def _fast(body):
    """DM's json_encode writes TRUE as 1."""
    return body.get('fast') in (True, 1)


def _routes(store, radio):
    return {
        # Cross-region radio: ephemeral, never in the ledger (radio.py).
        '/radio/send': lambda body: {'id': radio.send(body.get('envelope'))},
        '/radio/send_batch': lambda body: radio.send_batch(body.get('envelopes')),
        '/radio/heartbeat': lambda body: {'relays': radio.heartbeat(body.get('relays', []))},
        '/radio/inbox': lambda body: {'envelopes': radio.inbox()},
        '/radio/status': lambda body: radio.status(),
        '/radio/outbox': lambda body: radio.outbox(),
        '/radio/deliver': lambda body: {'queued': radio.deliver(body.get('envelopes', []), body.get('heartbeats'))},
        '/status': lambda body: store.status(),
        '/outbox': lambda body: {'envelopes': store.outbox()},
        '/receive': lambda body: {'reply': store.receive(body['envelope'])},
        '/escrow': lambda body: dict(zip(('transfer_id', 'effect_id'), store.begin_escrow(
            body['peer'], body['payloads'], _fast(body)))),
        '/import': lambda body: dict(zip(('effect_id', 'payloads'), store.begin_import(body['transfer_id'], _fast(body)))),
        '/return': lambda body: dict(zip(('effect_id', 'payloads'), store.begin_return(body['transfer_id'], _fast(body)))),
        '/abort': lambda body: store.abort(body['transfer_id']) or {},
        '/save': lambda body: {'ledger_seq': store.report_save(body['generation'], body['effects'], body['ledger_seq'])},
        '/load': lambda body: _load(store, body),
        # Home worlds: DM asks /account; the coordinator reads /accounts and answers /homes.
        '/account': lambda body: store.account(body['ckey'], body['op'], body.get('region'),
                                                 body.get('body') in (True, 1)),
        '/accounts': lambda body: store.account_requests(),
        '/homes': lambda body: store.apply_homes(body['epoch'], body['rev'], body['rows'], body['done'],
                                                 body.get('reset') in (True, 1), body.get('mainland')),
    }


def make_server(store, token, port=0, radio=None):
    if not isinstance(token, str) or len(token) < 32:
        raise ValueError('the agent token must be at least 32 characters')
    routes = _routes(store, radio or RadioRelay(store.region, store.group))

    class Handler(BaseHTTPRequestHandler):
        server_version = 'civ13-transfer-agent/1'

        def log_message(self, fmt, *args):
            pass  # no request bodies or items in logs

        def _answer(self, status, payload):
            data = json.dumps(payload, sort_keys=True).encode('utf-8')
            self.send_response(status)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def do_POST(self):
            if self.client_address[0] != '127.0.0.1':
                return self._answer(403, {'error': 'loopback only'})
            if not hmac.compare_digest(self.headers.get('X-Transfer-Token', ''), token):
                return self._answer(403, {'error': 'bad token'})
            route = routes.get(self.path)
            if route is None:
                return self._answer(404, {'error': 'unknown path'})
            try:
                length = int(self.headers.get('Content-Length', '0'))
            except ValueError:
                return self._answer(400, {'error': 'bad length'})
            if not 0 <= length <= MAX_BODY:
                return self._answer(413, {'error': 'body too large'})
            try:
                body = json.loads(self.rfile.read(length) or b'{}')
                if type(body) is not dict:
                    raise ValueError('body must be an object')
                return self._answer(200, {'ok': True, 'result': route(body)})
            except RegionHeld as e:
                return self._answer(409, {'ok': False, 'held': True, 'error': str(e)})
            except (TransferError, RadioError, KeyError, TypeError, ValueError) as e:
                return self._answer(409, {'ok': False, 'error': str(e)})

        def do_GET(self):
            self._answer(405, {'error': 'use POST'})

    return HTTPServer(('127.0.0.1', port), Handler)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--db', required=True)
    parser.add_argument('--region', required=True)
    parser.add_argument('--group', required=True)
    parser.add_argument('--port', type=int, required=True)
    parser.add_argument('--token-file', required=True)
    parser.add_argument('--enroll', action='append', default=[], metavar='PEER:DIRECTION',
                        help='permit one direction (out or in) with a peer; repeatable, kept in the store')
    args = parser.parse_args(argv)
    enrollments = []
    for item in args.enroll:
        peer, _, direction = item.partition(':')
        if not peer or direction not in ('out', 'in'):
            parser.error('--enroll takes PEER:out or PEER:in, got %r' % item)
        enrollments.append((peer, direction))
    with open(args.token_file, encoding='utf-8') as f:
        token = f.read().strip()
    store = RegionStore(args.db, args.region, args.group)
    for peer, direction in enrollments:
        store.enroll(peer, direction)
    server = make_server(store, token, args.port)
    try:
        server.serve_forever()
    finally:
        server.server_close()
        store.close()


if __name__ == '__main__':
    main()
