"""Account-key helpers from code/modules/accounts/discord_accounts.dm, run through
the audited DM source projector with fake engine boundaries (regex, ckey,
params2list, IsGuestKey). This is source evidence, not BYOND compilation."""
import importlib.util
import re
import unittest
from pathlib import Path
from types import SimpleNamespace
from urllib.parse import parse_qs

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('accounts_source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
SOURCE = (ROOT / 'code/modules/accounts/discord_accounts.dm').read_text(encoding='utf-8-sig')
PROJECTED = SOURCE.replace('regex(@"', 'regex(r"').replace('var/static/regex/', 'var/regex/')
RECLAIM = (ROOT / 'code/modules/persistence/player_reclaim.dm').read_text(encoding='utf-8-sig')
RECLAIM_PROJECTED = RECLAIM.replace('regex(@"', 'regex(r"').replace('var/static/regex/', 'var/regex/')

DISCORD = '123456789012345678'


class Regex:
    def __init__(self, pattern): self.pattern = pattern
    def Find(self, text): return bool(isinstance(text, str) and re.fullmatch(self.pattern, text))


class DMParams(dict):
    def __missing__(self, key): return None  # a DM list lookup of a missing key is null


def params2list(text):
    return DMParams({key: values[0] for key, values in parse_qs(text, keep_blank_values=True).items()})


class AccountKeys(unittest.TestCase):
    def setUp(self):
        self.verified = {}
        env = dict(istext=lambda s: isinstance(s, str), length=len, regex=Regex,
                   copytext=lambda s, start, end=0: s[start - 1:(end - 1 if end else None)],
                   ckey=lambda s: re.sub('[^a-z0-9]', '', s.lower()), params2list=params2list,
                   IsGuestKey=lambda key: key.lower().startswith('guest-'),
                   verified_discord_id=lambda key: self.verified.get(key))
        env['ACCOUNT_TICKET_MIN_LENGTH'], env['ACCOUNT_TICKET_MAX_LENGTH'] = 32, 128
        # Fake boundary for the existing player_reclaim.dm helper: guest ckeys.
        env['persistence_guest_account'] = lambda account: bool(isinstance(account, str) and re.fullmatch(r'guestw?\d+', account))
        for name, args in (('is_discord_id', 'id'), ('is_account_key', 'account'), ('persistence_owner_valid', 'account')):
            env[name] = adapter.project(RECLAIM_PROJECTED, '/proc/' + name, args, env)
        for name, args in (('account_discord_id', 'C'), ('account_key', 'C'), ('account_ticket_from_topic', 'topic')):
            env[name] = adapter.project(PROJECTED, '/proc/' + name, args, env)
        self.env = env

    def client(self, key, discord_id=None):
        return SimpleNamespace(key=key, ckey=re.sub('[^a-z0-9]', '', key.lower()), discord_id=discord_id)

    def test_account_keys_never_look_like_ckeys(self):
        valid = self.env['is_account_key']
        self.assertTrue(valid('d:' + DISCORD))
        for bad in ('d' + DISCORD, 'd:', 'd:0' + DISCORD[1:], 'd:1234', 'D:' + DISCORD, 'd:' + DISCORD + 'x', None):
            with self.subTest(bad=bad):
                self.assertFalse(valid(bad))

    def test_save_owner_accepts_ckeys_and_account_keys_only(self):
        owner = self.env['persistence_owner_valid']
        for good in ('alice', 'd:' + DISCORD):
            self.assertTrue(owner(good), good)
        for bad in ('', None, 'Alice', 'guest123', 'guestw42', 'd:12', 'd:' + DISCORD + ' '):
            with self.subTest(bad=bad):
                self.assertFalse(owner(bad))

    def test_account_key_prefers_ticket_then_verified_list(self):
        key = self.env['account_key']
        self.assertEqual(key(self.client('Alice')), 'alice')
        self.verified['alice'] = DISCORD
        self.assertEqual(key(self.client('Alice')), 'd:' + DISCORD)
        self.assertEqual(key(self.client('Alice', '223456789012345678')), 'd:223456789012345678')
        self.assertIsNone(key(self.client('Guest-123')))
        self.verified['guest123'] = DISCORD  # guests never borrow a verified row
        self.assertIsNone(key(self.client('Guest-123')))
        self.assertEqual(key(self.client('Guest-123', DISCORD)), 'd:' + DISCORD)
        self.assertIsNone(key(None))

    def test_ticket_is_read_from_the_join_topic(self):
        read = self.env['account_ticket_from_topic']
        ticket = 'A' * 20 + '-_' + 'z' * 21
        self.assertEqual(read('civ13_ticket=' + ticket), ticket)
        self.assertEqual(read('other=1&civ13_ticket=' + ticket), ticket)
        for bad in (None, '', 'civ13_ticket=short', 'civ13_ticket=' + 'a' * 129, 'civ13_ticket=' + 'a' * 40 + '%3B',
                    'x=' + ticket, 'civ13_ticket=' + 'a' * 2100):
            with self.subTest(bad=bad and bad[:40]):
                self.assertIsNone(read(bad))

    def test_every_owner_check_uses_the_shared_validator(self):
        travel = (ROOT / 'code/modules/persistence/region_travel.dm').read_text(encoding='utf-8-sig')
        for source in (RECLAIM, travel):
            self.assertNotIn('ckey(account) != account', source)
            self.assertNotIn('ckey(value) != value', source)
            self.assertNotIn('ckey(owner) != owner', source)
        self.assertEqual(RECLAIM.count('persistence_owner_valid('), 5)  # definition + four checks
        self.assertIn('persistence_owner_valid(owner)', travel)


if __name__ == '__main__':
    unittest.main()
