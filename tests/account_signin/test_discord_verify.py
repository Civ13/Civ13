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
    def __init__(self, pattern): self.pattern = pattern
    def Find(self, text): return bool(re.search(self.pattern, text))


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
