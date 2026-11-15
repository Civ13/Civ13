"""In-game Discord verification helpers from code/modules/client/discord_verify.dm,
run through the audited DM source projector with fake engine boundaries. Source
evidence, not BYOND compilation; the bot side is tested in Civilizationbot."""
import importlib.util
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('discord_verify_source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
SOURCE = (ROOT / 'code/modules/client/discord_verify.dm').read_text(encoding='utf-8-sig').replace('regex(@"', 'regex(r"')
# DM associative list literals become Python dicts; nothing else in these procs uses list().
PROJECTED = SOURCE.replace('list("ok" = ', 'dict(ok = ').replace(', "message" = ', ', message = ')


def dm_json_decode(text):
    value = json.loads(text)  # BYOND raises a runtime on bad JSON; the proc catches it
    return value


class Regex:
    def __init__(self, pattern, flags=''): self.pattern = re.compile(pattern, re.I if 'i' in flags else 0)
    def Find(self, text): return bool(self.pattern.search(text))
    def Replace(self, text, new): return self.pattern.sub(new, text, count=1)


class DMList(dict):
    def __missing__(self, key): return None


class DiscordVerify(unittest.TestCase):
    def setUp(self):
        env = dict(istext=lambda s: isinstance(s, str), length=len, uppertext=str.upper,
                   copytext=lambda s, start, end=0: s[start - 1:(end - 1 if end else None)],
                   replacetext=lambda s, old, new: s.replace(old, new), regex=Regex,
                   islist=lambda v: isinstance(v, dict),
                   json_decode=lambda text: DMList(dm_json_decode(text)) if isinstance(dm_json_decode(text), dict) else dm_json_decode(text))
        self.clean = adapter.project(PROJECTED, '/proc/discord_verify_clean_code', 'code', env)
        self.parse = adapter.project(PROJECTED, '/proc/discord_verify_parse_answer', 'body', env)
        self.endpoint = adapter.project(PROJECTED, '/proc/discord_verify_endpoint', 'address', env)

    def test_only_loopback_or_https_addresses_get_the_key_and_code(self):
        for address, url in (('http://127.0.0.1:55555/webhook/nomads', 'http://127.0.0.1:55555/webhook/nomads/discord_verify'),
                             ('http://localhost:8080/webhook/tdm/', 'http://localhost:8080/webhook/tdm/discord_verify'),
                             ('http://[::1]:55555/webhook/x', 'http://[::1]:55555/webhook/x/discord_verify'),
                             ('HTTPS://civ13.com/webhook/nomads', 'HTTPS://civ13.com/webhook/nomads/discord_verify')):
            with self.subTest(address=address):
                self.assertEqual(self.endpoint(address), url)
        for bad in ('http://civ13.com:55555/webhook/nomads', 'http://127.0.0.1.evil.example/webhook', 'http://localhost@evil.example/x',
                    'https://user@evil.example/x', 'http://192.168.0.5:55555/webhook/x', 'ftp://127.0.0.1/x',
                    'http://127.0.0.1:55555/webhook?key=x', '', None, 'https://' + 'a' * 3000):
            with self.subTest(bad=bad):
                self.assertIsNone(self.endpoint(bad))

    def test_key_and_code_travel_in_header_and_body_not_url(self):
        send = SOURCE[SOURCE.index('/proc/discord_verify_send'):SOURCE.index('/client/verb/verify_discord')]
        self.assertNotIn('?key=', send)
        self.assertNotIn('world.Export', send)
        self.assertIn('RUSTG_HTTP_METHOD_POST', send)
        self.assertIn('"X-Webhook-Key" = config.webhook_key', send)
        self.assertIn('discord_verify_endpoint(config.webhook_address)', send)

    def test_codes_are_cleaned_like_the_bot_does(self):
        self.assertEqual(self.clean('ABCD-EFGH'), 'ABCDEFGH')
        self.assertEqual(self.clean(' abcd efgh '), 'ABCDEFGH')
        for bad in ('ABCD-EFG0', 'ABCD-EFGI', 'ABC', 'ABCDEFGHJ', '', None, 'A' * 33, 'ABCD_EFGH'):
            with self.subTest(bad=bad):
                self.assertIsNone(self.clean(bad))

    def test_bot_answers_are_passed_through_and_failures_explained(self):
        ok = self.parse(json.dumps({'ok': True, 'message': 'Verified!'}))
        self.assertEqual((ok['ok'], ok['message']), (True, 'Verified!'))
        refused = self.parse(json.dumps({'ok': False, 'message': 'That code is wrong or has expired.'}))
        self.assertEqual(refused['ok'], False)
        self.assertEqual(len(self.parse(json.dumps({'ok': False, 'message': 'x' * 900}))['message']), 400)
        for bad in (None, '', '[]', '{"ok":true}', '{"ok":true,"message":""}', 'x' * 5000):
            with self.subTest(bad=bad):
                answer = self.parse(bad)
                self.assertEqual(answer['ok'], False)
                self.assertIn('/approveme', answer['message'])


if __name__ == '__main__':
    unittest.main()
