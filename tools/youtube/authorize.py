"""User-run local setup only. Never invoked by Actions. Google consent is manual.

Credential values stay in memory/stdin; no browser control, token files or logs.
Three GitHub secret writes cannot be a server-side transaction: the environment
must stay disabled, and failed writes receive bounded compensating cleanup.
"""
import argparse
import base64
from contextlib import contextmanager
import hashlib
import hmac
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import secrets
import stat
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

PROJECT = 'calcium-circuit-384407'
CHANNEL = 'UCFRx_n3Mh3FfvL9yOUfG-yw'
HANDLE = '@valzartech8995'
REPOSITORY = 'Civ13/Civ13'
ENVIRONMENT = 'youtube-unlisted'
SCOPES = ['https://www.googleapis.com/auth/youtube.readonly',
          'https://www.googleapis.com/auth/youtube.upload']
SECRET_NAMES = ['YOUTUBE_CLIENT_ID', 'YOUTUBE_CLIENT_SECRET', 'YOUTUBE_REFRESH_TOKEN']
AUTH_URL = 'https://accounts.google.com/o/oauth2/v2/auth'
TOKEN_URL = 'https://oauth2.googleapis.com/token'
STORE_PHRASE = 'STORE ' + REPOSITORY + ' ' + ENVIRONMENT


class Stopped(Exception):
    """Only deliberate non-secret diagnostics may escape the helper."""


def require(condition, message):
    if not condition:
        raise Stopped(message)


def read_json(raw, cap=65536):
    require(len(raw) <= cap, 'Input exceeds cap')
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, 'Duplicate JSON field')
            result[key] = value
        return result
    try:
        return json.loads(raw, object_pairs_hook=pairs,
                          parse_constant=lambda _: (_ for _ in ()).throw(Stopped('Invalid JSON number')))
    except (ValueError, UnicodeError):
        raise Stopped('Invalid JSON; values redacted') from None


def load_client(path, repository_root):
    path = Path(path)
    require(path.is_absolute() and path.is_file() and not path.is_symlink(),
            'Select an absolute path to your private local downloaded client JSON')
    resolved = path.resolve()
    require(repository_root.resolve() not in resolved.parents, 'Keep client JSON outside the repository')
    require(not str(resolved).startswith('\\\\'), 'Use a local private file, not a network share')
    with path.open('rb') as file:
        info = os.fstat(file.fileno())
        require(stat.S_ISREG(info.st_mode) and info.st_size <= 16384 and
                not getattr(info, 'st_file_attributes', 0) & 0x400, 'Unsafe credential file')
        if os.name != 'nt':
            require(info.st_mode & 0o077 == 0, 'Client JSON must be readable only by its owner (chmod 600)')
        document = read_json(file.read(16385), 16384)
    require(isinstance(document, dict) and set(document) == {'installed'},
            'Use the downloaded Desktop client JSON, not a web or service account credential')
    client = document['installed']
    require(isinstance(client, dict) and client.get('project_id') == PROJECT and
            client.get('auth_uri') in {AUTH_URL, 'https://accounts.google.com/o/oauth2/auth'} and
            client.get('token_uri') == TOKEN_URL,
            'Client project/type/endpoints do not match the approved setup')
    for key in ('client_id', 'client_secret'):
        require(isinstance(client.get(key), str) and 1 <= len(client[key]) <= 2048 and
                all(33 <= ord(c) < 127 for c in client[key]), 'Invalid Desktop credential field')
    require(re.fullmatch(r'[A-Za-z0-9._-]+\.apps\.googleusercontent\.com', client['client_id']),
            'Invalid Google OAuth client ID')
    return client


def pkce():
    verifier = secrets.token_urlsafe(64)
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b'=').decode()
    return verifier, challenge


def consent_url(client, redirect_uri, state, challenge):
    return AUTH_URL + '?' + urllib.parse.urlencode({
        'client_id': client['client_id'], 'redirect_uri': redirect_uri, 'response_type': 'code',
        'scope': ' '.join(SCOPES), 'access_type': 'offline', 'prompt': 'consent select_account',
        'include_granted_scopes': 'false', 'state': state,
        'code_challenge': challenge, 'code_challenge_method': 'S256'})


def callback_code(target, expected_state):
    require(len(target) <= 8192, 'Callback exceeds cap')
    parsed = urllib.parse.urlsplit(target)
    require(not parsed.scheme and not parsed.netloc and parsed.path == '/' and
            not parsed.fragment, 'Unexpected callback path')
    try:
        query = urllib.parse.parse_qs(parsed.query, keep_blank_values=True,
                                      strict_parsing=True, max_num_fields=10)
    except ValueError:
        raise Stopped('Malformed OAuth callback') from None
    require(set(query) <= {'state', 'code', 'error', 'error_description', 'error_uri', 'scope', 'authuser', 'prompt'} and
            all(len(values) == 1 for values in query.values()), 'Unexpected/duplicate callback field')
    state = query.get('state', [''])[0]
    require(state.isascii() and hmac.compare_digest(state, expected_state), 'OAuth state mismatch; no token exchange')
    require('error' not in query and 'error_description' not in query and 'error_uri' not in query,
            'Google consent denied or returned an error; no token exchange')
    code = query.get('code', [''])[0]
    require(1 <= len(code) <= 4096 and code.isascii() and all(33 <= ord(c) < 127 for c in code),
            'Missing or invalid authorization code')
    return code


class LocalServer(ThreadingHTTPServer):
    daemon_threads = True
    block_on_close = False

    def __init__(self, *args):
        self.slots = threading.BoundedSemaphore(8)
        super().__init__(*args)

    def get_request(self):
        connection, address = super().get_request()
        connection.settimeout(2)
        return connection, address

    def process_request(self, request, address):
        if not self.slots.acquire(blocking=False):
            self.close_request(request)
            return
        try:
            super().process_request(request, address)
        except BaseException:
            self.slots.release()
            raise

    def process_request_thread(self, request, address):
        try:
            super().process_request_thread(request, address)
        finally:
            self.slots.release()

    def handle_error(self, request, address):
        # Socket/parser diagnostics must never include callback query strings.
        pass


class Callback:
    """One temporary IPv4 loopback listener; query strings are never logged."""
    def __init__(self, state, timeout=300, clock=time.monotonic, factory=LocalServer):
        self.state, self.timeout, self.clock = state, timeout, clock
        self.code, self.error = None, None
        self.authorization_url = None
        owner = self
        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass
            def do_GET(self):
                parsed = urllib.parse.urlsplit(self.path)
                if parsed.path == '/authorize' and not parsed.query and owner.authorization_url:
                    # The user opens this local link directly. Keep Google's
                    # client/state/challenge URL out of terminal transcripts.
                    self.send_response(302)
                    self.send_header('Location', owner.authorization_url)
                    self.send_header('Cache-Control', 'no-store')
                    self.send_header('Content-Length', '0')
                    self.end_headers()
                    return
                if parsed.path != '/':
                    self.send_response(404)
                    self.end_headers()
                    return
                try:
                    owner.code = callback_code(self.path, owner.state)
                    status = 200
                except Stopped as failure:
                    owner.error, status = failure, 400
                body = b'Return to the local terminal. This page contains no credentials.'
                self.send_response(status)
                self.send_header('Content-Type', 'text/plain; charset=utf-8')
                self.send_header('Cache-Control', 'no-store')
                self.send_header('Content-Length', str(len(body)))
                self.end_headers()
                self.wfile.write(body)
        self.server = factory(('127.0.0.1', 0), Handler)
        self.server.timeout = 1
        self.redirect_uri = 'http://127.0.0.1:' + str(self.server.server_address[1]) + '/'

    def wait(self):
        deadline = self.clock() + self.timeout
        while self.code is None and self.error is None and self.clock() < deadline:
            self.server.handle_request()
        if self.error:
            raise self.error
        require(self.code is not None, 'Consent callback expired; no token exchange')
        return self.code

    def close(self):
        self.server.server_close()


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args):
        return None


def exchange_code(client, code, verifier, redirect_uri, opener=None, clock=time.time):
    values = {'client_id': client['client_id'], 'client_secret': client['client_secret'],
              'code': code, 'code_verifier': verifier, 'redirect_uri': redirect_uri,
              'grant_type': 'authorization_code'}
    request = urllib.request.Request(TOKEN_URL, urllib.parse.urlencode(values).encode(),
        {'Content-Type': 'application/x-www-form-urlencoded'}, method='POST')
    opener = opener or urllib.request.build_opener(NoRedirect())
    try:
        with opener.open(request, timeout=30) as response:
            require(response.status == 200, 'Token exchange stopped; response redacted')
            token = read_json(response.read(65537))
    except (OSError, ValueError):
        raise Stopped('Token exchange failed or uncertain; no automatic retry, values redacted') from None
    require(isinstance(token, dict) and isinstance(token.get('scope'), str) and
            sorted(token['scope'].split()) == SCOPES and token.get('token_type', '').lower() == 'bearer',
            'Granted scopes differ from the two approved scopes')
    for key in ('access_token', 'refresh_token'):
        require(isinstance(token.get(key), str) and 1 <= len(token[key]) <= 8192 and
                token[key].isascii() and all(33 <= ord(c) < 127 for c in token[key]),
                'Token response incomplete; values redacted')
    require(type(token.get('expires_in')) is int and 120 <= token['expires_in'] <= 7200,
            'Access token is expired or too near expiry')
    token['expires_at'] = clock() + token['expires_in']
    return token


def unexpired(token, clock=time.time):
    require(token['expires_at'] > clock() + 30, 'Authorization expired; no secret placement')


def verify_channel(token, run=subprocess.run, clock=time.time):
    unexpired(token, clock)
    payload = {'access_token': token['access_token'], 'token_type': token['token_type'], 'scope': SCOPES}
    try:
        result = run(['php', '-d', 'display_errors=0', str(Path(__file__).with_name('authorize-channel.php'))],
            input=json.dumps(payload).encode(), capture_output=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired):
        raise Stopped('Channel check failed; no secret placement, values redacted') from None
    require(result.returncode == 0 and read_json(result.stdout) == {'channel_id': CHANNEL},
            'OAuth channel does not match the approved destination; no secret placement')
    unexpired(token, clock)


class GitHubSecrets:
    def __init__(self, run=subprocess.run):
        self.run = run

    def command(self, arguments, value=None, allow_missing=False):
        try:
            result = self.run(['gh', *arguments], input=value, capture_output=True, timeout=30)
        except (OSError, subprocess.TimeoutExpired):
            raise Stopped('GitHub operation failed or uncertain; values redacted') from None
        if allow_missing and result.returncode and b'HTTP 404' in result.stderr:
            return None
        require(result.returncode == 0, 'GitHub operation stopped; values and service output redacted')
        return result.stdout

    def api(self, suffix, allow_missing=False):
        raw = self.command(['api', 'repos/' + REPOSITORY + suffix], allow_missing=allow_missing)
        return read_json(raw) if raw is not None else None

    def names(self):
        data = self.api('/environments/' + ENVIRONMENT + '/secrets?per_page=100')
        require(data['total_count'] <= 100 and len(data['secrets']) == data['total_count'],
                'Unexpected environment secret inventory; stop for review')
        return {item['name'] for item in data['secrets']}

    def disabled(self):
        expected = {'YOUTUBE_UPLOAD_ENABLED': 'false', 'YOUTUBE_UPLOAD_STOP_USE': 'true',
                    'YOUTUBE_ZERO_COST_CONFIRMED': 'false'}
        for name, value in expected.items():
            # Explicit repository values shadow any activating organization
            # defaults. Missing values cannot prove the effective gate is closed.
            item = self.api('/actions/variables/' + name, allow_missing=True)
            require(item is not None and item['value'] == value,
                    'Set all three repository activation variables explicitly disabled before setup')
            item = self.api('/environments/' + ENVIRONMENT + '/variables/' + name, allow_missing=True)
            require(item is None or item['value'] == value, 'Environment activation must remain disabled during setup')

    def preflight(self):
        repo = self.api('')
        require(repo['id'] == 141349998 and repo['full_name'] == REPOSITORY and repo['visibility'] == 'public',
                'Wrong repository or $0/public-repository assumptions changed')
        environment = self.api('/environments/' + ENVIRONMENT)
        require(environment.get('can_admins_bypass', False) is False, 'Disable environment admin bypass where supported')
        reviewers = [r for r in environment.get('protection_rules', []) if r['type'] == 'required_reviewers']
        require(len(reviewers) == 1 and reviewers[0].get('prevent_self_review') is True and
                reviewers[0].get('reviewers'), 'Environment needs required reviewers and prevention of self-review')
        policy = environment.get('deployment_branch_policy') or {}
        require(policy.get('custom_branch_policies') is True and policy.get('protected_branches') is False,
                'Environment must use an explicit master-only deployment policy')
        branches = self.api('/environments/' + ENVIRONMENT + '/deployment-branch-policies')
        require(branches['total_count'] == 1 and
                [(b['name'], b.get('type', 'branch')) for b in branches['branch_policies']] == [('master', 'branch')],
                'Environment must allow only the master branch')
        self.disabled()
        require(not self.names().intersection(SECRET_NAMES),
                'Target secrets already exist; this helper never overwrites or rotates them')

    def store(self, client, token):
        # No server-side multi-secret transaction exists. Keep execution disabled,
        # refuse pre-existing credentials, never retry a write, and compensate.
        self.preflight()
        values = [client['client_id'], client['client_secret'], token['refresh_token']]
        attempted = []
        uncertain = set()
        try:
            for name, value in zip(SECRET_NAMES, values):
                self.disabled()
                require(name not in self.names(), 'Concurrent secret change detected; stop setup')
                attempted.append(name)  # Include writes with an uncertain outcome.
                try:
                    self.command(['secret', 'set', name, '--repo', REPOSITORY, '--env', ENVIRONMENT], value.encode())
                except BaseException:
                    # A remote PUT can finish after a timeout and after an absent
                    # metadata snapshot. Cleanup cannot prove this write absent.
                    uncertain.add(name)
                    raise
            self.disabled()
            require(set(SECRET_NAMES) <= self.names(), 'Secret placement not confirmed')
        except BaseException:
            remaining = set(uncertain)
            for name in reversed(attempted):
                try:
                    if name in self.names():
                        self.command(['secret', 'delete', name, '--repo', REPOSITORY, '--env', ENVIRONMENT, '--yes'])
                    require(name not in self.names(), 'Secret cleanup uncertain')
                except BaseException:
                    remaining.add(name)
            if remaining:
                raise Stopped('Setup incomplete or uncertain; keep uploads disabled. Owner must remove/reconcile '
                              'these attempted names even if currently absent: ' + ', '.join(sorted(remaining))) from None
            raise Stopped('Setup stopped; newly attempted secrets removed, uploads remain disabled. Revoke the new Google grant if abandoning setup') from None


def confirmed(prompt, phrase, reader=input):
    print(prompt)
    return hmac.compare_digest(reader('Type exactly "' + phrase + '" to continue: '), phrase)


@contextmanager
def local_setup_lock():
    path = Path(tempfile.gettempdir()) / ('civ13-youtube-setup-' + PROJECT + '.lock')
    try:
        path.mkdir(mode=0o700)
    except FileExistsError:
        raise Stopped('Another setup may be active. Owner must reconcile a stale local setup lock before retry') from None
    try:
        yield
    finally:
        path.rmdir()


def authorize(client, github, reader=input, callback_factory=Callback,
              exchange=exchange_code, channel_check=verify_channel, clock=time.time):
    # Check all remote prerequisites read-only before asking for a new grant.
    github.preflight()
    print('Project: ' + PROJECT + '; destination: ' + HANDLE + ' (' + CHANNEL + ')')
    print('Scopes: ' + ' '.join(SCOPES))
    print('Google consent is manual. Testing grants expire after 7 days. No app publication or upload is performed.')
    print('Run only this setup session; do not rotate these environment secrets concurrently.')
    verifier, challenge = pkce()
    state = secrets.token_urlsafe(32)
    callback = callback_factory(state)
    try:
        callback.authorization_url = consent_url(client, callback.redirect_uri, state, challenge)
        print('Open this local consent link yourself; it redirects to Google. Do not paste callback or tokens into chat:')
        print(callback.redirect_uri + 'authorize')
        code = callback.wait()
        token = exchange(client, code, verifier, callback.redirect_uri)
    finally:
        callback.close()
    channel_check(token)
    print('Verified approved channel. No credential values are displayed or saved locally.')
    print('Placement: ' + REPOSITORY + ' environment ' + ENVIRONMENT + '. See the reviewed setup document for the three credential fields.')
    require(confirmed('Approve persistent GitHub secret placement separately. The grant allows video management/upload and channel reads. '
                      'Revoke it in your Google account and delete environment secrets to terminate access.',
                      STORE_PHRASE, reader),
            'Storage declined; tokens discarded from this process. Revoke the new Google grant if abandoning setup')
    unexpired(token, clock)
    github.store(client, token)
    print('Three environment secrets confirmed. Upload activation remains disabled; no video was uploaded.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['check', 'authorize'])
    parser.add_argument('--client-json', required=True, type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    client = load_client(args.client_json, root)
    github = GitHubSecrets()
    if args.mode == 'check':
        github.preflight()
        print('Client project/type and disabled protected GitHub destination checked. No grant or secret writes.')
        return
    require(sys.stdin.isatty(), 'Authorization requires an interactive user terminal for separate secret placement approval')
    with local_setup_lock():
        authorize(client, github)


if __name__ == '__main__':
    try:
        main()
    except Stopped as error:
        print('Setup stopped: ' + str(error), file=sys.stderr)
        sys.exit(1)
    except (Exception, KeyboardInterrupt):
        print('Setup stopped; values redacted. Keep uploads disabled and reconcile any attempted secret placement', file=sys.stderr)
        sys.exit(1)
