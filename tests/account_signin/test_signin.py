"""Offline checks for tools/account_signin/signin.py; Discord is a fake."""
import http.client
import json
import sys
import threading
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools' / 'account_signin'))
import signin  # noqa: E402

PLAYER = '123456789012345678'
WORLD_TOKEN = 'w' * 40


class FakeDiscord:
    def __init__(self, users=None):
        self.users = users if users is not None else {'good-token': PLAYER}
        self.revoked = []

    def identify(self, access_token):
        return self.users.get(access_token)

    def revoke(self, access_token):
        self.revoked.append(access_token)
        return True


class Clock:
    def __init__(self):
        self.now = 1000.0

    def __call__(self):
        return self.now


class ServiceTests(unittest.TestCase):
    def setUp(self):
        self.discord = FakeDiscord()
        self.clock = Clock()
        self.service = signin.SigninService(self.discord, ['gaia'], clock=self.clock)

    def test_ticket_redeems_once_for_its_server_and_address(self):
        issued = self.service.signin('good-token', 'gaia', '1.2.3.4')
        self.assertEqual(issued['expires_in'], 120)
        self.assertGreaterEqual(len(issued['ticket']), 32)
        self.assertEqual(self.service.redeem(issued['ticket'], 'gaia', '1.2.3.4'), {'discord_id': PLAYER})
        with self.assertRaises(signin.Refused):
            self.service.redeem(issued['ticket'], 'gaia', '1.2.3.4')

    def test_token_is_kept_unless_revoke_is_on(self):
        # The launcher's refresh token dies with a revoke, so it is opt-in.
        self.service.signin('good-token', 'gaia', '1.2.3.4')
        self.assertEqual(self.discord.revoked, [])
        strict = signin.SigninService(self.discord, ['gaia'], clock=self.clock, revoke=True)
        strict.signin('good-token', 'gaia', '1.2.3.4')
        with self.assertRaises(signin.Refused):
            strict.signin('stolen-or-expired', 'gaia', '1.2.3.4')
        self.assertEqual(self.discord.revoked, ['good-token', 'stolen-or-expired'])

    def test_launcher_names_the_server_by_game_port(self):
        ports = signin.SigninService(self.discord, {'gaia': 1714, 'railyard': 1716}, clock=self.clock)
        ticket = ports.signin('good-token', None, '1.2.3.4', port=1716)['ticket']
        with self.assertRaises(signin.Refused):
            ports.redeem(ticket, 'gaia', '1.2.3.4')
        ticket = ports.signin('good-token', None, '1.2.3.4', port=1716)['ticket']
        self.assertEqual(ports.redeem(ticket, 'railyard', '1.2.3.4'), {'discord_id': PLAYER})
        for bad in (1799, '1714', True, None):
            with self.subTest(bad=bad), self.assertRaises(signin.Refused):
                ports.signin('good-token', None, '1.2.3.4', port=bad)

    def test_ticket_expires_after_two_minutes(self):
        ticket = self.service.signin('good-token', 'gaia', '1.2.3.4')['ticket']
        self.clock.now += 121
        with self.assertRaises(signin.Refused):
            self.service.redeem(ticket, 'gaia', '1.2.3.4')

    def test_wrong_server_or_address_burns_the_ticket(self):
        ticket = self.service.signin('good-token', 'gaia', '1.2.3.4')['ticket']
        with self.assertRaises(signin.Refused):
            self.service.redeem(ticket, 'gaia', '5.6.7.8')
        with self.assertRaises(signin.Refused):
            self.service.redeem(ticket, 'gaia', '1.2.3.4')
        other = signin.SigninService(self.discord, ['gaia', 'railyard'], clock=self.clock)
        ticket = other.signin('good-token', 'gaia', '1.2.3.4')['ticket']
        with self.assertRaises(signin.Refused):
            other.redeem(ticket, 'railyard', '1.2.3.4')

    def test_unknown_server_is_refused_before_calling_discord(self):
        with self.assertRaises(signin.Refused):
            self.service.signin('good-token', 'elsewhere', '1.2.3.4')
        self.assertEqual(self.discord.revoked, [])

    def test_bad_discord_ids_are_refused(self):
        for bad in (None, '', '0123456789012345678', '12345', 'abcdefghijklmnopqr', 123456789012345678):
            self.discord.users['weird'] = bad
            with self.subTest(bad=bad), self.assertRaises(signin.Refused):
                self.service.signin('weird', 'gaia', '1.2.3.4')

    def test_sign_ins_are_rate_limited_per_address(self):
        for _ in range(signin.SIGNIN_LIMIT):
            self.service.signin('good-token', 'gaia', '1.2.3.4')
        with self.assertRaises(signin.Refused):
            self.service.signin('good-token', 'gaia', '1.2.3.4')
        self.service.signin('good-token', 'gaia', '9.9.9.9')
        self.clock.now += 61
        self.service.signin('good-token', 'gaia', '1.2.3.4')


class HttpTests(unittest.TestCase):
    def setUp(self):
        self.service = signin.SigninService(FakeDiscord(), {'gaia': 1714})
        self.httpd = signin.make_server(self.service, WORLD_TOKEN, 0, forwarded_header='CF-Connecting-IP')
        self.port = self.httpd.server_address[1]
        threading.Thread(target=self.httpd.serve_forever, daemon=True).start()

    def tearDown(self):
        self.httpd.shutdown()
        self.httpd.server_close()

    def post(self, path, body, headers=None):
        connection = http.client.HTTPConnection('127.0.0.1', self.port, timeout=5)
        connection.request('POST', path, json.dumps(body), {'Content-Type': 'application/json', **(headers or {})})
        response = connection.getresponse()
        answer = json.loads(response.read())
        connection.close()
        return response.status, answer

    def test_signin_and_redeem_over_http(self):
        status, answer = self.post('/signin', {'access_token': 'good-token', 'port': 1714},
                                   {'CF-Connecting-IP': '203.0.113.7'})
        self.assertEqual((status, answer['ok']), (200, True))
        ticket = answer['result']['ticket']
        body = {'ticket': ticket, 'server': 'gaia', 'address': '203.0.113.7'}
        self.assertEqual(self.post('/redeem', body)[0], 403)  # the world's token is required
        status, answer = self.post('/redeem', body, {'X-Account-Token': WORLD_TOKEN})
        self.assertEqual((status, answer['result']), (200, {'discord_id': PLAYER}))
        self.assertEqual(self.post('/redeem', body, {'X-Account-Token': WORLD_TOKEN})[0], 409)

    def test_refusals_and_bad_bodies(self):
        self.assertEqual(self.post('/signin', {'access_token': 'nope', 'server': 'gaia'})[0], 409)
        self.assertEqual(self.post('/signin', ['not', 'an', 'object'])[0], 400)
        self.assertEqual(self.post('/nowhere', {})[0], 404)


class SourceTests(unittest.TestCase):
    """The world keeps the ticket out of client.Topic and logs."""

    def test_client_new_reads_the_ticket_before_dropping_the_topic(self):
        source = (ROOT / 'code/modules/client/client_procs.dm').read_text(encoding='utf-8-sig')
        keep = source.index('account_ticket = account_ticket_from_topic(TopicData)')
        drop = source.index('TopicData = null')
        self.assertLess(keep, drop)

    def test_redeem_drops_the_ticket_and_never_logs_it(self):
        source = (ROOT / 'code/modules/accounts/discord_accounts.dm').read_text(encoding='utf-8-sig')
        redeem = source[source.index('/datum/account_signin/proc/redeem'):]
        self.assertLess(redeem.index('C.account_ticket = null'), redeem.index('R.prepare('))
        for line in source.splitlines():
            if 'log_game(' in line or 'world.log' in line or 'to_chat(' in line:
                self.assertNotIn('ticket]', line)
                self.assertNotIn('[ticket', line)


if __name__ == '__main__':
    unittest.main()
