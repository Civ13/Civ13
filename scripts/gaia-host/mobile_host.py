"""Opt-in HTTPS companion for the launcher's existing host control.

No listener is created on import. Requires operator-provisioned TLS material and
explicitly paired client certificate fingerprints; see MOBILE.md before use.
"""
from __future__ import annotations

import argparse
import hashlib
from http.server import BaseHTTPRequestHandler, HTTPServer
import ipaddress
import json
import os
from pathlib import Path
import re
import secrets
import ssl
import sys
import threading
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gaia_host

ACTIONS = ('start', 'stop', 'restart')
STATES = ('awake', 'asleep', 'cold', 'stopped')
PHASES = ('accepted', 'checking save', 'starting', 'started', 'saving', 'backing up',
          'stopped', 'pulling', 'compiling', 'compiled', 'checking for updates',
          'build is current', 'done', 'failed')
PRIVATE = tuple(ipaddress.ip_network(value) for value in ('10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16'))
HEX64 = re.compile(r'[0-9a-f]{64}')
HEX32 = re.compile(r'[0-9a-f]{32}')
MAX_RECEIPTS = 100


def read_json(path, limit=65536):
    with Path(path).open('rb') as source:
        raw = source.read(limit + 1)
    if len(raw) > limit:
        raise ValueError('configuration or receipt exceeds its limit')
    return json.loads(raw)


def load_config(path):
    cfg = read_json(path)
    if not isinstance(cfg, dict) or cfg.get('enabled') is not True:
        raise ValueError('mobile access is disabled')
    address = ipaddress.IPv4Address(cfg['bind'])
    network = ipaddress.IPv4Network(cfg['lan_cidr'], strict=True)
    if not any(network.subnet_of(private) for private in PRIVATE):
        raise ValueError('lan_cidr must be an explicit RFC1918 subnet')
    if network.prefixlen < 24 or network.prefixlen > 30 or address not in network or address in (network.network_address, network.broadcast_address):
        raise ValueError('bind must be a host address in an explicit /24 through /30 LAN subnet')
    if type(cfg.get('port')) is not int or not 1024 <= cfg['port'] <= 65535:
        raise ValueError('port must be 1024 through 65535')
    fingerprints = cfg.get('devices')
    if not isinstance(fingerprints, list) or not 1 <= len(fingerprints) <= 16 or any(
            not isinstance(value, str) or not HEX64.fullmatch(value) for value in fingerprints):
        raise ValueError('devices must contain 1 through 16 SHA-256 certificate fingerprints')
    for field in ('certificate', 'private_key', 'client_ca', 'host_config', 'state_dir'):
        value = cfg.get(field)
        if not isinstance(value, str) or not Path(value).is_absolute():
            raise ValueError('local paths must be absolute')
        if not (Path(value).is_dir() if field == 'state_dir' else Path(value).is_file()):
            raise ValueError('required local material is missing')
    cfg['network'] = network
    cfg['authority'] = '%s:%d' % (address, cfg['port'])
    cfg['origin'] = 'https://' + cfg['authority']
    return cfg


def tls_context(cfg):
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.options |= ssl.OP_NO_TICKET
    context.verify_mode = ssl.CERT_REQUIRED
    context.load_verify_locations(cafile=cfg['client_ca'])
    # Never generate certificates, install trust or fall back to HTTP.
    context.load_cert_chain(cfg['certificate'], cfg['private_key'], password=lambda: '')
    return context


def operation_view(raw):
    raw = raw if isinstance(raw, dict) else {}
    return {'action': raw.get('action') if raw.get('action') in ACTIONS else 'other',
            'phase': raw.get('phase') if raw.get('phase') in PHASES else 'unknown',
            'failed': bool(raw.get('error')) or raw.get('phase') == 'failed'}


def status_view(raw):
    """Allowlist scalars, never redact arbitrary upstream text heuristically."""
    world = raw.get('world') if isinstance(raw.get('world'), dict) else {}
    players = world.get('clients')
    return {'state': raw.get('state') if raw.get('state') in STATES else 'unknown',
            'players': players if type(players) is int and 0 <= players <= 10000 else None,
            'busy': raw.get('busy') is True, 'operation': operation_view(raw.get('operation'))}


class Controller:
    def __init__(self, host, directory, clock=time.monotonic):
        self.host, self.directory, self.clock = host, Path(directory), clock
        self.guard = threading.Lock()
        self.confirmations = {}
        self.limits = {}

    def allow(self, device):
        now = self.clock()
        start, count = self.limits.get(device, (now, 0))
        if now - start >= 60:
            start, count = now, 0
        self.limits[device] = (start, count + 1)
        return count < 30

    def prepare(self, device, action):
        if action not in ACTIONS:
            raise ValueError('unsupported action')
        with self.guard:
            # One confirmation per device. New views replace old confirmations.
            token = secrets.token_hex(32)
            self.confirmations[device] = (token, action, self.clock() + 60)
            return {'confirmation': token, 'action': action}

    def write_receipt(self, path, receipt):
        temporary = path.with_suffix('.tmp')
        with temporary.open('w', encoding='utf-8') as target:
            json.dump(receipt, target)
            target.flush()
            os.fsync(target.fileno())
        os.replace(temporary, path)

    def submit(self, device, action, token):
        if action not in ACTIONS or not isinstance(token, str) or not HEX64.fullmatch(token):
            raise ValueError('invalid confirmation')
        with self.guard:
            path = self.directory / (hashlib.sha256(token.encode()).hexdigest() + '.json')
            if path.exists():
                previous = read_json(path, 2048)
                if previous.get('device') != device or previous.get('action') != action:
                    raise ValueError('confirmation does not match')
                return self.receipt_view(previous)  # retry never dispatches again
            expected = self.confirmations.get(device)
            if not expected or expected[0] != token or expected[1] != action or self.clock() >= expected[2]:
                raise ValueError('confirmation expired; review status again')
            del self.confirmations[device]
            for existing in self.directory.glob('*.json'):
                if read_json(existing, 2048).get('result') == 'uncertain':
                    raise ValueError('an uncertain request needs desktop reconciliation')
            # Bound storage without discarding replay evidence. Rotation is an offline
            # operator action with the companion stopped; old tokens are then invalid.
            if len(list(self.directory.glob('*.json'))) >= MAX_RECEIPTS:
                raise ValueError('mobile history is full; use the desktop')
            receipt = {'device': device, 'action': action, 'result': 'uncertain', 'at': int(time.time())}
            self.write_receipt(path, receipt)  # reserve before any lifecycle effect
            try:
                answer = self.host.request(action)
                if answer.get('accepted') is True and HEX32.fullmatch(str(answer.get('operation', ''))):
                    receipt.update(result='accepted', operation=answer['operation'])
            except gaia_host.Refused:
                receipt['result'] = 'refused'
            except Exception:
                # A detach/write failure may follow acceptance. Never retry it.
                pass
            self.write_receipt(path, receipt)
            return self.receipt_view(receipt)

    def receipt_view(self, receipt, current=None):
        result = receipt.get('result')
        view = {'action': receipt.get('action') if receipt.get('action') in ACTIONS else 'other',
                'result': result if result in ('accepted', 'refused', 'uncertain') else 'uncertain',
                'at': receipt.get('at') if type(receipt.get('at')) is int else 0}
        if isinstance(current, dict) and receipt.get('operation') == current.get('operation'):
            view['progress'] = operation_view(current)
        elif isinstance(receipt.get('progress'), dict):
            view['progress'] = operation_view(receipt['progress'])
        return view

    def status(self):
        with self.guard:
            raw = self.host.status()
            view = status_view(raw)
            current = raw.get('operation')
            receipts = []
            for path in sorted(self.directory.glob('*.json'))[:MAX_RECEIPTS]:
                row = read_json(path, 2048)
                if isinstance(current, dict) and row.get('operation') == current.get('operation'):
                    row['progress'] = operation_view(current)
                    self.write_receipt(path, row)
                receipts.append(row)
            view['logs'] = sorted((self.receipt_view(row, current) for row in receipts),
                                  key=lambda row: row['at'], reverse=True)[:20]
            return view


class Handler(BaseHTTPRequestHandler):
    # HTTP/1.0 closes every connection, including rejected/partially read bodies.
    server_version = 'Civ13Mobile'
    sys_version = ''

    def log_message(self, *_):
        pass  # request URLs, certificates and upstream exceptions stay private

    def send_error(self, code, message=None, explain=None):
        self.reply(code, {'error': 'Request refused.'})

    def reply(self, code, data, kind='application/json'):
        payload = json.dumps(data).encode() if kind == 'application/json' else data
        self.send_response(code)
        self.send_header('Content-Type', kind)
        self.send_header('Content-Length', str(len(payload)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Referrer-Policy', 'no-referrer')
        self.send_header('Content-Security-Policy', "default-src 'self'; frame-ancestors 'none'; object-src 'none'; base-uri 'none'; form-action 'none'")
        self.end_headers()
        self.wfile.write(payload)

    def device(self):
        cfg = self.server.cfg
        cert = self.connection.getpeercert(binary_form=True)
        fingerprint = hashlib.sha256(cert).hexdigest() if cert else ''
        if fingerprint not in cfg['devices'] or self.headers.get_all('Host') != [cfg['authority']]:
            return None
        if self.headers.get('Sec-Fetch-Site') not in (None, 'none', 'same-origin'):
            return None
        if not self.server.controller.allow(fingerprint):
            return None
        return fingerprint

    def do_GET(self):
        if not self.device():
            self.reply(403, {'error': 'Access refused.'})
            return
        try:
            if self.path == '/api/status':
                self.reply(200, self.server.controller.status())
            elif self.path in ('/', '/mobile.js', '/mobile.css'):
                name, kind = {'/': ('mobile.html', 'text/html; charset=utf-8'),
                              '/mobile.js': ('mobile.js', 'text/javascript; charset=utf-8'),
                              '/mobile.css': ('mobile.css', 'text/css; charset=utf-8')}[self.path]
                self.reply(200, (Path(__file__).parent / name).read_bytes(), kind)
            else:
                self.reply(404, {'error': 'Not found.'})
        except Exception:
            self.reply(503, {'error': 'Status unavailable. Check the desktop host.'})

    def do_POST(self):
        device = self.device()
        if not device or self.headers.get_all('Origin') != [self.server.cfg['origin']]:
            self.reply(403, {'error': 'Access refused.'})
            return
        if (self.headers.get('Content-Type') != 'application/json' or self.headers.get('Transfer-Encoding')
                or len(self.headers.get_all('Content-Length', [])) != 1):
            self.reply(400, {'error': 'Invalid request.'})
            return
        try:
            length = int(self.headers['Content-Length'])
            if not 1 <= length <= 512:
                raise ValueError('body size')
            body = json.loads(self.rfile.read(length))
            fields = {'action'} if self.path == '/api/prepare' else {'action', 'confirmation'}
            if not isinstance(body, dict) or set(body) != fields:
                raise ValueError('body fields')
            if self.path == '/api/prepare':
                response = self.server.controller.prepare(device, body['action'])
            elif self.path == '/api/action':
                response = self.server.controller.submit(device, body['action'], body['confirmation'])
            else:
                raise ValueError('route')
            self.reply(200, response)
        except (ValueError, TypeError):
            self.reply(400, {'error': 'Request refused. Refresh and review the desktop if needed.'})
        except Exception:
            self.reply(503, {'error': 'Result uncertain. Refresh status; do not repeat the action.'})


class Server(HTTPServer):
    allow_reuse_address = False
    request_queue_size = 4

    def __init__(self, cfg, context, controller):
        self.cfg, self.context, self.controller = cfg, context, controller
        super().__init__((cfg['bind'], cfg['port']), Handler)

    def get_request(self):
        connection, address = super().get_request()
        connection.settimeout(5)
        try:
            if ipaddress.ip_address(address[0]) not in self.cfg['network']:
                raise OSError('outside configured LAN')
            return self.context.wrap_socket(connection, server_side=True), address
        except Exception:
            connection.close()
            raise

    def handle_error(self, *_):
        pass


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', required=True)
    args = parser.parse_args(argv)
    lock = None
    try:
        cfg = load_config(args.config)
        context = tls_context(cfg)  # fail before opening a port or touching host state
        host_cfg = gaia_host.load_config(cfg['host_config'])
        host_cfg['_path'] = cfg['host_config']
        host = gaia_host.region_host(host_cfg) if host_cfg.get('group_config') else gaia_host.Host(host_cfg)
        lock = Path(cfg['state_dir']) / 'mobile.lock'
        # One companion per receipt directory. Never clear an uncertain old lock.
        with lock.open('x', encoding='ascii') as target:
            target.write(str(os.getpid()))
        try:
            with Server(cfg, context, Controller(host, cfg['state_dir'])) as server:
                print('Mobile host: ' + cfg['origin'], flush=True)
                server.serve_forever()
        finally:
            lock.unlink()
    except (OSError, ValueError, KeyError, TypeError):
        print('Mobile host refused startup. Check disabled/configuration, TLS material and companion lock locally.', file=sys.stderr)
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
