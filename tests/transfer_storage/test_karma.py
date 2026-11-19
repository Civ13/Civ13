"""Hidden karma (tools/transfer_storage/karma.py and code/modules/karma/karma_ledger.dm):
weights, banned givers, latest rating wins, revokes, the per-ckey files the
coordinator writes, and DM source contracts. Never launches BYOND."""
import json
import os
import re
import sqlite3
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, ROOT)
from tools.transfer_storage import karma, records  # noqa: E402

NOW = 1_800_000_000
DAY = 86400
DM = os.path.join(ROOT, 'code', 'modules', 'karma', 'karma_ledger.dm')


class Karma(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:', isolation_level=None)
        records.init_group(self.db)
        self.n = 0

    def add(self, ckey, kind, body, at=NOW - 100, author='val'):
        self.n += 1
        rid = '%032x' % self.n
        records.store_records(self.db, 'gaia', [{'id': rid, 'ckey': ckey, 'kind': kind, 'author': author,
                                                 'rank': 'Host', 'at': at, 'body': body}], NOW)
        return rid

    def rate(self, giver, target, rating, at=NOW - 100, **extra):
        return self.add(target, 'karma_rating', dict({'giver': giver, 'rating': rating}, **extra), at, giver)

    def test_weights_follow_standing_playtime_and_age(self):
        self.add('vet', 'karma_standing', {'value': 2, 'reason': 'helpful'})
        self.rate('vet', 'bob', 'kindly')
        self.rate('newbie', 'bob', 'kindly', at=NOW - 100 * DAY)
        files = karma.snapshots(self.db, NOW, {'vet': 250, 'newbie': 2})
        rows = {r['giver']: r for r in files['bob']['ratings']}
        self.assertEqual(rows['vet']['weight'], 1.5)
        self.assertEqual(rows['vet']['giver_standing'], 'trusted')
        self.assertEqual(rows['newbie']['factors'], {'standing': 1.0, 'playtime': 0.05, 'age': 0.5})
        self.assertEqual(rows['newbie']['weight'], 0.025)
        self.assertIn('low_weight', rows['newbie']['flags'])
        self.assertEqual(files['bob']['summary']['kindly'], 2)
        self.assertEqual(files['bob']['summary']['kindly_weighted'], 1.525)

    def test_the_latest_rating_from_a_giver_wins_and_revokes_remove_it(self):
        self.rate('amy', 'bob', 'kindly', at=NOW - 500)
        later = self.rate('amy', 'bob', 'poorly', at=NOW - 400)
        summary = karma.snapshots(self.db, NOW)['bob']['summary']
        self.assertEqual((summary['kindly'], summary['poorly']), (0, 1))
        self.add('bob', 'revoke', {'target': later, 'target_kind': 'karma_rating'})
        self.assertNotIn('bob', karma.snapshots(self.db, NOW))  # the earlier one was replaced, not restored

    def test_a_banned_giver_counts_only_while_the_ban_lasts(self):
        self.rate('troll', 'bob', 'poorly')
        self.add('troll', 'ban', {'scope': 'game', 'until': NOW + DAY, 'reason': 'x'})
        self.add('troll', 'ban', {'scope': 'ooc', 'until': 0, 'reason': 'x'})
        files = karma.snapshots(self.db, NOW, {'troll': 100})
        row = files['bob']['ratings'][0]
        self.assertIn('giver_banned', row['flags'])
        self.assertEqual(row['weight'], 0)
        self.assertEqual(files['bob']['summary']['poorly'], 0)
        later = karma.snapshots(self.db, NOW + 2 * DAY, {'troll': 100})['bob']
        self.assertEqual(later['summary']['poorly'], 1)
        self.assertNotIn('giver_banned', later['ratings'][0]['flags'])

    def test_bursts_shared_connections_notes_and_self_ratings(self):
        for giver in ('a1', 'a2', 'a3'):
            self.rate(giver, 'bob', 'poorly', faction='reds')
        self.rate('a4', 'bob', 'poorly', faction='blues', shared_cid=1)
        self.rate('bob', 'bob', 'kindly')
        self.add('a1', 'note', {'text': 'warned'})
        rows = {r['giver']: r for r in karma.snapshots(self.db, NOW)['bob']['ratings']}
        self.assertNotIn('bob', rows)
        self.assertIn('burst', rows['a1']['flags'])
        self.assertNotIn('burst', rows['a4']['flags'])
        self.assertIn('shared_connection', rows['a4']['flags'])
        self.assertTrue(rows['a1']['giver_notes'])
        self.assertFalse(rows['a2']['giver_notes'])

    def test_givers_see_their_own_list_and_bars_and_standings_get_files(self):
        self.rate('amy', 'bob', 'kindly', note='Shared food')
        self.add('carl', 'karma_bar', {'reason': 'spam'})
        self.add('dan', 'karma_standing', {'value': -1, 'reason': 'grief'})
        files = karma.snapshots(self.db, NOW)
        self.assertEqual(files['amy']['given'], [{'target': 'bob', 'kind': 'kindly', 'at': '2027-01-15', 'note': 'Shared food'}])
        self.assertTrue(files['carl']['barred'])
        self.assertEqual(files['dan']['standing']['value'], -1)
        self.assertEqual(karma.label('bob', {}, {'bob': {}}), 'unknown')

    def test_files_are_written_beside_the_snapshots_only_when_changed(self):
        with tempfile.TemporaryDirectory() as root:
            writer = karma.KarmaFiles(self.db, root)
            self.rate('amy', 'bob', 'kindly')
            self.assertEqual(writer.write(NOW), 2)  # bob received, amy gave
            self.assertEqual(writer.write(NOW + 5), 0)  # nothing new, under a minute
            self.assertEqual(writer.write(NOW + 120), 0)  # recomputed, unchanged
            with open(os.path.join(root, 'karma', 'bob.json'), encoding='utf-8') as f:
                bob = json.load(f)
            self.assertEqual(bob['ckey'], 'bob')
            # The fields the Discord bot reads (Civilizationbot KarmaSnapshot).
            for key in ('generated', 'standing', 'hours', 'summary', 'ratings'):
                self.assertIn(key, bob)
            for key in ('giver', 'kind', 'weight', 'giver_standing', 'giver_hours', 'giver_notes', 'flags', 'at', 'note'):
                self.assertIn(key, bob['ratings'][0])
            self.assertEqual(sorted(os.listdir(root)), ['karma'])

    def test_weights_match_the_dm_ledger(self):
        with open(DM, encoding='utf-8') as f:
            dm = f.read()
        constants = dict(re.findall(r'#define (KARMA_\w+) ([0-9.]+)', dm))
        self.assertEqual(float(constants['KARMA_FULL_WEIGHT_HOURS']), karma.FULL_WEIGHT_HOURS)
        self.assertEqual(float(constants['KARMA_PLAYTIME_FLOOR']), karma.PLAYTIME_FLOOR)
        self.assertEqual(int(constants['KARMA_AGE_SECONDS']), karma.AGE_DAYS * DAY)
        self.assertEqual(float(constants['KARMA_AGE_FACTOR']), karma.AGE_FACTOR)
        self.assertEqual(float(constants['KARMA_LOW_WEIGHT']), karma.LOW_WEIGHT)
        self.assertEqual(int(constants['KARMA_BURST_SECONDS']), karma.BURST_SECONDS)
        self.assertEqual(int(constants['KARMA_BURST_COUNT']), karma.BURST_COUNT)
        self.assertEqual(int(constants['KARMA_DERIVED_MARGIN']), karma.DERIVED_MARGIN)
        factors = re.search(r'proc/karma_standing_factor\(value\)(.*?)\n\n', dm, re.S).group(1)
        for value, factor in karma.STANDING_FACTOR.items():
            if factor != 1.0:
                self.assertRegex(factors, r'if \(%d\)\n\t\t\treturn %s\b' % (value, ('%g' % factor)))
        for name in constants:
            self.assertIn('#undef ' + name, dm)

    def test_dm_ledger_is_included_and_uses_the_shared_store(self):
        with open(os.path.join(ROOT, 'civ13.dme'), encoding='utf-8') as f:
            self.assertIn('#include "code\\modules\\karma\\karma_ledger.dm"', f.read())
        with open(DM, encoding='utf-8') as f:
            dm = f.read()
        self.assertIn('shared_records.add(target, "karma_rating"', dm)
        self.assertIn('shared_records.active_bans(giver, "game") + shared_records.active_bans(giver, "play")', dm)
        self.assertIn('karma/[ckey].json', dm)


class KarmaGiving(unittest.TestCase):
    """code/modules/karma/karma_give.dm source contracts."""

    @classmethod
    def setUpClass(cls):
        with open(os.path.join(ROOT, 'code', 'modules', 'karma', 'karma_give.dm'), encoding='utf-8') as f:
            cls.dm = f.read()

    def proc(self, name):
        return re.search(r'\n/[\w/]*%s\(.*?(?=\n/|\Z)' % name, self.dm, re.S).group(0)

    def test_only_verified_unbarred_signed_in_accounts_give(self):
        refusal = self.proc('karma_giver_refusal')
        self.assertIn('IsGuestKey(C.key)', refusal)
        self.assertIn('if (!verified_discord_id(C.ckey))', refusal)
        self.assertIn('karma_barred(C.ckey)', refusal)

    def test_no_cap_and_no_minimum_time(self):
        for word in ('playtime_hours', 'world.time <', 'per day', 'daily', 'cooldown'):
            self.assertNotIn(word, self.dm)

    def test_targets_are_other_living_players(self):
        refusal = self.proc('karma_target_refusal')
        self.assertIn('is_agent_account(target)', refusal)
        self.assertIn('target == C.ckey', refusal)
        self.assertIn('H.stat == DEAD', refusal)
        self.assertIn('H.persistence_owner_ckey', self.proc('karma_character_ckey'))

    def test_the_rated_player_is_never_told(self):
        remember = self.proc('karma_remember')
        self.assertIn('set src in view()', remember)
        self.assertNotIn('to_chat(src', remember)
        self.assertNotIn('to_chat(client', remember)
        # Rechecked after the prompts, which can stay open.
        self.assertEqual(remember.count('karma_giver_refusal(C)'), 2)

    def test_givers_can_change_and_forget_their_own_ratings_only(self):
        topic = self.proc('Topic')
        self.assertIn('received[C.ckey]', topic)
        self.assertIn('shared_records.revoke(record, C.ckey', topic)
        self.assertIn('/client/verb/karma_notes()', self.dm)


if __name__ == '__main__':
    unittest.main()
