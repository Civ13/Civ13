"""No live account, token or GitHub write. A single fixture uses IPv4 loopback."""
import base64
import contextlib
import hashlib
import http.client
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import threading
import unittest
from unittest.mock import patch
import urllib.parse

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('youtube_authorize', ROOT / 'tools/youtube/authorize.py')
a = importlib.util.module_from_spec(spec)
spec.loader.exec_module(a)


def client():
    return {'project_id': a.PROJECT, 'client_id': '123-offline.apps.googleusercontent.com',
            'client_secret': 'FAKE-CLIENT-SECRET', 'auth_uri': a.AUTH_URL, 'token_uri': a.TOKEN_URL}


def token():
    return {'scope': ' '.join(a.SCOPES), 'token_type': 'Bearer',
            'access_token': 'FAKE-ACCESS-TOKEN', 'refresh_token': 'FAKE-REFRESH-TOKEN', 'expires_in': 3600,
            'expires_at': 3700}


class FakeResponse:
    status = 200
    def __init__(self, value):
        self.raw = json.dumps(value).encode()
    def read(self, maximum):
        return self.raw[:maximum]
    def __enter__(self):
        return self
    def __exit__(self, *args):
        pass


class FakeOpener:
    def __init__(self, value):
        self.value, self.calls = value, []
    def open(self, request, timeout):
        self.calls.append(request)
        if isinstance(self.value, Exception):
            raise self.value
        return FakeResponse(self.value)


class GitHubSimulator:
    def __init__(self, fail_at=None, uncertain=False, cleanup_fails=False):
        self.names, self.calls, self.writes = set(), [], 0
        self.fail_at, self.uncertain, self.cleanup_fails = fail_at, uncertain, cleanup_fails
        self.variables = {'YOUTUBE_UPLOAD_ENABLED': 'false', 'YOUTUBE_UPLOAD_STOP_USE': 'true',
                          'YOUTUBE_ZERO_COST_CONFIRMED': 'false'}
        self.env_variables = {}
        self.environment = {'can_admins_bypass': False,
            'protection_rules': [{'type': 'required_reviewers', 'prevent_self_review': True,
                                  'reviewers': [{'type': 'User', 'reviewer': {'id': 1}}]}],
            'deployment_branch_policy': {'custom_branch_policies': True, 'protected_branches': False}}

    def __call__(self, args, input=None, **kwargs):
        self.calls.append((list(args), input))
        assert kwargs['capture_output'] and kwargs['timeout'] == 30
        if args[1] == 'api':
            path = args[2].removeprefix('repos/' + a.REPOSITORY)
            if not path:
                value = {'id': 141349998, 'full_name': a.REPOSITORY, 'visibility': 'public'}
            elif path == '/environments/' + a.ENVIRONMENT:
                value = self.environment
            elif path.endswith('/deployment-branch-policies'):
                value = {'total_count': 1, 'branch_policies': [{'name': 'master', 'type': 'branch'}]}
            elif '/variables/' in path:
                name = path.rsplit('/', 1)[1]
                source = self.env_variables if path.startswith('/environments/') else self.variables
                if name not in source:
                    return subprocess.CompletedProcess(args, 1, b'', b'HTTP 404')
                value = {'name': name, 'value': source[name]}
            elif path.endswith('/secrets?per_page=100'):
                value = {'total_count': len(self.names), 'secrets': [{'name': n} for n in self.names]}
            else:
                raise AssertionError('Unexpected API endpoint: ' + path)
            return subprocess.CompletedProcess(args, 0, json.dumps(value).encode(), b'')
        action, name = args[2:4]
        assert args[1] == 'secret' and args[4:8] == ['--repo', a.REPOSITORY, '--env', a.ENVIRONMENT]
        if action == 'set':
            self.writes += 1
            assert input and input.decode() not in args
            self.names.add(name)
            if self.writes == self.fail_at:
                if self.uncertain:
                    raise subprocess.TimeoutExpired(args, 30)
                return subprocess.CompletedProcess(args, 1, b'FAKE-REFRESH-TOKEN', b'FAKE-CLIENT-SECRET')
        elif action == 'delete':
            assert args[-1] == '--yes'
            if self.cleanup_fails:
                return subprocess.CompletedProcess(args, 1, b'', b'FAKE-ACCESS-TOKEN')
            self.names.discard(name)
        else:
            raise AssertionError('Unexpected secret operation')
        return subprocess.CompletedProcess(args, 0, b'', b'')


class ClientAndProtocolTests(unittest.TestCase):
    def test_scope_contract_uses_full_google_uris_only(self):
        self.assertEqual(set(a.SCOPES), {
            'https://www.googleapis.com/auth/youtube.upload',
            'https://www.googleapis.com/auth/youtube.readonly'})

    def test_private_desktop_file_and_exact_project(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / 'client.json'
            path.write_text(json.dumps({'installed': client()}))
            path.chmod(0o600)
            self.assertEqual(a.load_client(path, root / 'repo'), client())
            for document in ({'web': client()}, {'installed': dict(client(), project_id='wrong-project')},
                             {'installed': dict(client(), token_uri='https://evil.invalid/token')}):
                path.write_text(json.dumps(document))
                with self.assertRaises(a.Stopped):
                    a.load_client(path, root / 'repo')
            with self.assertRaises(a.Stopped):
                a.load_client(path, root)

    def test_pkce_and_offline_consent_have_exact_scopes_no_browser_control(self):
        verifier, challenge = a.pkce()
        self.assertTrue(43 <= len(verifier) <= 128)
        self.assertEqual(challenge, base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b'=').decode())
        url = a.consent_url(client(), 'http://127.0.0.1:1234/', 'state-fixture', challenge)
        query = urllib.parse.parse_qs(urllib.parse.urlsplit(url).query)
        self.assertEqual(query['scope'], [' '.join(a.SCOPES)])
        self.assertEqual(query['code_challenge_method'], ['S256'])
        self.assertEqual(query['access_type'], ['offline'])
        self.assertEqual(query['include_granted_scopes'], ['false'])
        self.assertNotIn(client()['client_secret'], url)

    def test_wrong_state_code_error_duplicates_and_paths_rejected(self):
        self.assertEqual(a.callback_code('/?state=expected&code=FAKE-CODE', 'expected'), 'FAKE-CODE')
        for target in ['/?state=wrong&code=DO-NOT-EXCHANGE',
                '/?state=expected&error=access_denied',
                '/?state=expected&code=x&code=y',
                '/?state=expected&code=x&error=other',
                '/?state=expected', '/wrong?state=expected&code=x',
                'https://evil.invalid/?state=expected&code=x']:
            with self.subTest(target=target), self.assertRaises(a.Stopped):
                a.callback_code(target, 'expected')

    def test_loopback_callback_is_local_and_redacts_response_and_logs(self):
        callback = a.Callback('expected', timeout=3)
        response = []
        def request():
            port = urllib.parse.urlsplit(callback.redirect_uri).port
            connection = http.client.HTTPConnection('127.0.0.1', port, timeout=3)
            connection.request('GET', '/?state=expected&code=FAKE-CALLBACK-SECRET')
            result = connection.getresponse()
            response.append((result.status, result.read()))
            connection.close()
        output = io.StringIO()
        with contextlib.redirect_stderr(output):
            worker = threading.Thread(target=request, daemon=True)
            worker.start()
            try:
                self.assertEqual(callback.wait(), 'FAKE-CALLBACK-SECRET')
            finally:
                callback.close()
            worker.join(3)
        self.assertEqual(response[0][0], 200)
        self.assertNotIn(b'FAKE-CALLBACK-SECRET', response[0][1])
        self.assertEqual(output.getvalue(), '')

    def test_expired_callback_never_exchanges_code(self):
        class Server:
            server_address = ('127.0.0.1', 1234)
            def __init__(self, address, handler):
                self.address = address
            def handle_request(self):
                pass
            def server_close(self):
                pass
        ticks = iter([0, 2])
        callback = a.Callback('expected', timeout=1, clock=lambda: next(ticks), factory=Server)
        self.assertEqual(callback.server.address, ('127.0.0.1', 0))
        with self.assertRaises(a.Stopped):
            callback.wait()
        callback.close()

    def test_token_exchange_is_one_post_and_rejects_scope_expiry_missing_refresh(self):
        opener = FakeOpener(token())
        result = a.exchange_code(client(), 'FAKE-CODE', 'FAKE-VERIFIER', 'http://127.0.0.1:1234/', opener, lambda: 100)
        self.assertEqual(result['expires_at'], 3700)
        self.assertEqual(len(opener.calls), 1)
        request = opener.calls[0]
        self.assertEqual(request.full_url, a.TOKEN_URL)
        self.assertEqual(request.get_method(), 'POST')
        self.assertEqual(urllib.parse.parse_qs(request.data.decode())['code_verifier'], ['FAKE-VERIFIER'])
        for change in ({'scope': a.SCOPES[0]}, {'expires_in': 0}, {'refresh_token': ''},
                       {'scope': ' '.join(a.SCOPES) + ' https://www.googleapis.com/auth/youtube'}):
            with self.subTest(change=change), self.assertRaises(a.Stopped):
                a.exchange_code(client(), 'code', 'verifier', 'http://127.0.0.1:1/', FakeOpener(dict(token(), **change)))

    def test_token_errors_are_redacted_and_never_retried(self):
        opener = FakeOpener(OSError('FAKE-CLIENT-SECRET FAKE-REFRESH-TOKEN'))
        with self.assertRaises(a.Stopped) as error:
            a.exchange_code(client(), 'FAKE-CODE', 'VERIFIER', 'http://127.0.0.1:1/', opener)
        self.assertNotIn('FAKE-', str(error.exception))
        self.assertEqual(len(opener.calls), 1)

    def test_wrong_channel_and_expiry_stop_before_secret_placement(self):
        calls = []
        def run(args, **kwargs):
            calls.append((args, kwargs))
            self.assertNotIn(token()['access_token'], args)
            return subprocess.CompletedProcess(args, 0, b'{"channel_id":"wrong-channel"}', b'FAKE-REFRESH-TOKEN')
        with self.assertRaises(a.Stopped):
            a.verify_channel(token(), run=run, clock=lambda: 100)
        self.assertEqual(len(calls), 1)
        with self.assertRaises(a.Stopped):
            a.verify_channel(token(), run=lambda *x, **k: self.fail('No call after expiry'), clock=lambda: 4000)


class SecretPlacementTests(unittest.TestCase):
    def test_preflight_checks_protection_empty_secrets_and_both_variable_scopes(self):
        simulator = GitHubSimulator()
        github = a.GitHubSecrets(simulator)
        github.preflight()
        for mapping in (simulator.variables, simulator.env_variables):
            prior = dict(mapping)
            mapping['YOUTUBE_UPLOAD_ENABLED'] = 'true'
            with self.assertRaises(a.Stopped):
                github.preflight()
            mapping.clear()
            mapping.update(prior)
        simulator.names.add(a.SECRET_NAMES[0])
        with self.assertRaises(a.Stopped):
            github.preflight()
        self.assertEqual(simulator.writes, 0)

    def test_success_uses_stdin_and_never_activates_uploads(self):
        simulator = GitHubSimulator()
        a.GitHubSecrets(simulator).store(client(), token())
        self.assertEqual(simulator.names, set(a.SECRET_NAMES))
        for args, stdin in simulator.calls:
            if args[1:3] == ['secret', 'set']:
                self.assertTrue(stdin)
                self.assertNotIn(stdin.decode(), args)
            self.assertNotIn('--method', args)
        self.assertEqual(simulator.variables['YOUTUBE_UPLOAD_ENABLED'], 'false')
        self.assertEqual(simulator.variables['YOUTUBE_UPLOAD_STOP_USE'], 'true')
        self.assertEqual(simulator.env_variables, {})

    def test_every_failed_or_uncertain_write_compensates_all_attempts(self):
        for position in (1, 2, 3):
            for uncertain in (False, True):
                simulator = GitHubSimulator(fail_at=position, uncertain=uncertain)
                with self.subTest(position=position, uncertain=uncertain), self.assertRaises(a.Stopped) as error:
                    a.GitHubSecrets(simulator).store(client(), token())
                self.assertEqual(simulator.names, set())
                self.assertEqual(simulator.writes, position)
                self.assertNotIn('FAKE-', str(error.exception))

    def test_failed_cleanup_reports_only_nonsecret_names_and_stays_disabled(self):
        simulator = GitHubSimulator(fail_at=2, cleanup_fails=True)
        with self.assertRaises(a.Stopped) as error:
            a.GitHubSecrets(simulator).store(client(), token())
        self.assertIn('YOUTUBE_CLIENT_ID', str(error.exception))
        self.assertNotIn('FAKE-', str(error.exception))
        self.assertEqual(simulator.variables['YOUTUBE_UPLOAD_ENABLED'], 'false')
        self.assertEqual(simulator.writes, 2)

    def test_interrupt_during_uncertain_write_also_compensates(self):
        simulator = GitHubSimulator()
        def interrupted(args, **kwargs):
            result = simulator(args, **kwargs)
            if args[1:4] == ['secret', 'set', a.SECRET_NAMES[1]]:
                raise KeyboardInterrupt()
            return result
        with self.assertRaises(a.Stopped):
            a.GitHubSecrets(interrupted).store(client(), token())
        self.assertEqual(simulator.names, set())

    def test_missing_repository_gate_cannot_inherit_activating_organization_default(self):
        simulator = GitHubSimulator()
        simulator.variables.pop('YOUTUBE_UPLOAD_ENABLED')
        with self.assertRaises(a.Stopped):
            a.GitHubSecrets(simulator).preflight()
        self.assertEqual(simulator.writes, 0)

    def test_delayed_remote_write_remains_uncertain_after_absent_snapshots(self):
        simulator = GitHubSimulator()
        delayed = []
        def run(args, **kwargs):
            if args[1:4] == ['secret', 'set', a.SECRET_NAMES[1]]:
                delayed.append(a.SECRET_NAMES[1])
                raise subprocess.TimeoutExpired(args, 30)
            return simulator(args, **kwargs)
        with self.assertRaises(a.Stopped) as error:
            a.GitHubSecrets(run).store(client(), token())
        self.assertEqual(simulator.names, set())  # All immediate snapshots absent.
        self.assertIn(a.SECRET_NAMES[1], str(error.exception))
        self.assertIn('even if currently absent', str(error.exception))
        simulator.names.update(delayed)  # Models the remote PUT completing later.
        self.assertEqual(simulator.variables['YOUTUBE_UPLOAD_ENABLED'], 'false')
        self.assertNotIn('FAKE-', str(error.exception))


class AuthorizationGateTests(unittest.TestCase):
    def run_flow(self, answers, callback_error=None, channel_error=None, expires=False):
        state = {'exchange': 0, 'channel': 0, 'store': 0, 'closed': False, 'preflight': 0}
        class GitHub:
            def preflight(self):
                state['preflight'] += 1
            def store(self, client, token):
                state['store'] += 1
        class Callback:
            redirect_uri = 'http://127.0.0.1:1234/'
            def __init__(self, expected_state):
                pass
            def wait(self):
                if callback_error:
                    raise callback_error
                return 'FAKE-CODE'
            def close(self):
                state['closed'] = True
        def exchange(*args):
            state['exchange'] += 1
            return token()
        def channel_check(value):
            state['channel'] += 1
            if channel_error:
                raise channel_error
        entries = iter(answers)
        output = io.StringIO()
        try:
            with contextlib.redirect_stdout(output):
                a.authorize(client(), GitHub(), reader=lambda _: next(entries), callback_factory=Callback,
                    exchange=exchange, channel_check=channel_check, clock=lambda: 4000 if expires else 100)
        except a.Stopped as error:
            state['error'] = str(error)
        state['output'] = output.getvalue()
        return state

    def test_separate_storage_gate_and_no_secrets_printed_or_redundant_grant_prompt(self):
        declined_store = self.run_flow(['no'])
        self.assertEqual((declined_store['exchange'], declined_store['store']), (1, 0))
        success = self.run_flow([a.STORE_PHRASE])
        self.assertEqual((success['exchange'], success['channel'], success['store']), (1, 1, 1))
        self.assertTrue(success['closed'])
        for secret in [client()['client_secret'], token()['access_token'], token()['refresh_token'], 'FAKE-CODE']:
            self.assertNotIn(secret, success['output'])

    def test_callback_failure_wrong_channel_and_expiry_cannot_write_secrets(self):
        failed_callback = self.run_flow([], callback_error=a.Stopped('OAuth state mismatch'))
        self.assertEqual((failed_callback['exchange'], failed_callback['store']), (0, 0))
        self.assertTrue(failed_callback['closed'])
        failed_channel = self.run_flow([], channel_error=a.Stopped('Wrong channel'))
        self.assertEqual(failed_channel['store'], 0)
        expired = self.run_flow([a.STORE_PHRASE], expires=True)
        self.assertEqual(expired['store'], 0)

    def test_setup_lock_is_exclusive_and_contains_no_credentials(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(a.tempfile, 'gettempdir', return_value=directory):
            with a.local_setup_lock():
                with self.assertRaises(a.Stopped):
                    with a.local_setup_lock():
                        self.fail('Second setup acquired lock')
                self.assertEqual(len(list(Path(directory).iterdir())), 1)
            self.assertEqual(list(Path(directory).iterdir()), [])


if __name__ == '__main__':
    unittest.main()
