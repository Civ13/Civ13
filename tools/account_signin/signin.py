"""Discord sign-in service for Civ13 accounts (docs/accounts/discord-accounts.md).

The launcher signs the player in with Discord (OAuth2 public client + PKCE) and
POSTs the access token here over HTTPS. The service asks Discord who the token
belongs to, revokes the token at once, and hands back a single-use ticket bound
to that Discord ID, the target server and the caller's address. Only the ticket
goes into the byond:// join link; the world redeems it with /redeem.

    POST /signin  {"access_token": "...", "server": "gaia"}  -> {"ticket", "expires_in"}
    POST /redeem  {"ticket": "...", "server": "gaia", "address": "1.2.3.4"}
                  header X-Account-Token  -> {"discord_id"}

It binds 127.0.0.1 only. /signin is meant to be reached through a TLS front
(the hosted bot, or a tunnel); set "forwarded_header" to the header that front
uses for the player's address. /redeem also needs the world's token. Nothing
is written to disk: tickets live in memory for two minutes, and Discord tokens
are never stored or logged. Only the standard library is used.
"""
import argparse
import hmac
import json
import secrets
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DISCORD_API = 'https://discord.com/api/v10'
TICKET_TTL = 120
MAX_TICKETS = 10000
MAX_BODY = 16 * 1024
SIGNIN_LIMIT = 10  # sign-ins per address per minute


class Refused(Exception):
    """A request the service turns down; the message is safe to return."""


def is_discord_id(value):
    return isinstance(value, str) and 17 <= len(value) <= 20 and value.isdigit() and value[0] != '0'


def server_name(value):
    return isinstance(value, str) and 0 < len(value) <= 64 and value.isascii() and value.isalnum() and value.islower()


class Discord:
    """The two Discord calls the service makes. Tests replace it."""

    def __init__(self, client_id, api=DISCORD_API, timeout=10):
        self.client_id = client_id
        self.api = api
        self.timeout = timeout

    def identify(self, access_token):
        request = urllib.request.Request(self.api + '/users/@me', headers={
            'Authorization': 'Bearer ' + access_token, 'User-Agent': 'Civ13AccountSignin (civ13, 1)'})
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                user = json.loads(response.read(64 * 1024))
        except (urllib.error.URLError, ValueError, OSError):
            return None
        return user.get('id') if isinstance(user, dict) else None

    def revoke(self, access_token):
        data = urllib.parse.urlencode({'token': access_token, 'token_type_hint': 'access_token',
                                       'client_id': self.client_id}).encode()
        request = urllib.request.Request(self.api + '/oauth2/token/revoke', data=data, headers={
            'Content-Type': 'application/x-www-form-urlencoded', 'User-Agent': 'Civ13AccountSignin (civ13, 1)'})
        try:
            with urllib.request.urlopen(request, timeout=self.timeout):
                return True
        except (urllib.error.URLError, OSError):
            return False


class SigninService:
    def __init__(self, discord, servers, clock=time.monotonic, ttl=TICKET_TTL, bind_address=True):
        self.discord = discord
        self.servers = frozenset(servers)
        self.clock = clock
        self.ttl = ttl
        self.bind_address = bind_address
        self.tickets = {}
        self.attempts = {}
        self.lock = threading.Lock()

    def _expire(self, now):
        for ticket in [t for t, row in self.tickets.items() if row['expires'] <= now]:
            del self.tickets[ticket]
        for address in [a for a, times in self.attempts.items() if not [t for t in times if t > now - 60]]:
            del self.attempts[address]

    def signin(self, access_token, server, address):
        if not isinstance(access_token, str) or not 1 <= len(access_token) <= 512:
            raise Refused('missing access token')
        if server not in self.servers:
            raise Refused('unknown server')
        now = self.clock()
        with self.lock:
            self._expire(now)
            times = [t for t in self.attempts.get(address, []) if t > now - 60]
            if len(times) >= SIGNIN_LIMIT:
                raise Refused('too many sign-ins; wait a minute')
            times.append(now)
            self.attempts[address] = times
            if len(self.tickets) >= MAX_TICKETS:
                raise Refused('busy; try again shortly')
        discord_id = self.discord.identify(access_token)
        # The token is only ever needed for that one call.
        self.discord.revoke(access_token)
        if not is_discord_id(discord_id):
            raise Refused('Discord did not accept the sign-in')
        ticket = secrets.token_urlsafe(32)
        with self.lock:
            self.tickets[ticket] = {'discord_id': discord_id, 'server': server, 'address': address,
                                    'expires': self.clock() + self.ttl}
        return {'ticket': ticket, 'expires_in': self.ttl}

    def redeem(self, ticket, server, address):
        if not isinstance(ticket, str):
            raise Refused('unknown ticket')
        now = self.clock()
        with self.lock:
            self._expire(now)
            row = self.tickets.pop(ticket, None)  # single use, even when refused below
        if row is None:
            raise Refused('unknown ticket')
        if row['server'] != server:
            raise Refused('ticket is for another server')
        if self.bind_address and row['address'] != address:
            raise Refused('ticket was issued to another address')
        return {'discord_id': row['discord_id']}


def make_server(service, token, port=0, forwarded_header=None):
    class Handler(BaseHTTPRequestHandler):
        server_version = 'Civ13AccountSignin'

        def log_message(self, fmt, *args):
            pass  # requests carry tokens and tickets; never log them

        def _answer(self, status, payload):
            data = json.dumps(payload).encode()
            self.send_response(status)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def _address(self):
            if forwarded_header:
                value = self.headers.get(forwarded_header, '').split(',')[0].strip()
                if value:
                    return value
            return self.client_address[0]

        def do_POST(self):
            if self.client_address[0] != '127.0.0.1':
                return self._answer(403, {'ok': False, 'error': 'loopback only'})
            try:
                length = int(self.headers.get('Content-Length', '0'))
            except ValueError:
                length = -1
            if not 0 < length <= MAX_BODY:
                return self._answer(413, {'ok': False, 'error': 'bad body size'})
            try:
                body = json.loads(self.rfile.read(length))
            except ValueError:
                return self._answer(400, {'ok': False, 'error': 'body is not JSON'})
            if not isinstance(body, dict):
                return self._answer(400, {'ok': False, 'error': 'body must be an object'})
            try:
                if self.path == '/signin':
                    result = service.signin(body.get('access_token'), body.get('server'), self._address())
                elif self.path == '/redeem':
                    if not hmac.compare_digest(self.headers.get('X-Account-Token', ''), token):
                        return self._answer(403, {'ok': False, 'error': 'bad token'})
                    result = service.redeem(body.get('ticket'), body.get('server'), body.get('address'))
                else:
                    return self._answer(404, {'ok': False, 'error': 'no such route'})
            except Refused as refusal:
                return self._answer(409, {'ok': False, 'error': str(refusal)})
            return self._answer(200, {'ok': True, 'result': result})

        def do_GET(self):
            self._answer(405, {'ok': False, 'error': 'POST only'})

    return ThreadingHTTPServer(('127.0.0.1', port), Handler)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('--config', required=True, help='JSON: port, token_file, client_id, servers, forwarded_header?')
    args = parser.parse_args(argv)
    with open(args.config, encoding='utf-8') as handle:
        config = json.load(handle)
    with open(config['token_file'], encoding='utf-8') as handle:
        token = handle.read().strip()
    if len(token) < 32:
        sys.exit('the token file must hold at least 32 characters')
    servers = config.get('servers')
    if not isinstance(servers, list) or not servers or not all(server_name(s) for s in servers):
        sys.exit('servers must be a list of lowercase names, such as ["gaia"]')
    if not is_discord_id(str(config.get('client_id', ''))):
        sys.exit('client_id must be the login Discord application ID')
    service = SigninService(Discord(str(config['client_id'])), servers)
    httpd = make_server(service, token, int(config['port']), config.get('forwarded_header'))
    print(json.dumps({'ok': True, 'listening': httpd.server_address[1]}), flush=True)
    httpd.serve_forever()


if __name__ == '__main__':
    main()
