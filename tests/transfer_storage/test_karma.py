"""Hidden karma (tools/transfer_storage/karma.py and code/modules/karma/karma_ledger.dm):
weights, banned givers, latest rating wins, revokes, the per-ckey files the
coordinator writes, and DM source contracts. Never launches BYOND."""
import json
import os
import re
import shutil
import sqlite3
import subprocess
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


class KarmaAdmin(unittest.TestCase):
    """code/modules/karma/karma_admin.dm source contracts."""

    @classmethod
    def setUpClass(cls):
        with open(os.path.join(ROOT, 'code', 'modules', 'karma', 'karma_admin.dm'), encoding='utf-8') as f:
            cls.dm = f.read()

    def test_staff_only_and_registered(self):
        self.assertIn('if (!check_rights(R_ADMIN))', self.dm)
        self.assertIn('if (!C || !C.holder || !(C.holder.rights & R_ADMIN))', self.dm)
        self.assertIn('if (!C || !check_rights(R_ADMIN))', self.dm)
        with open(os.path.join(ROOT, 'code', 'modules', 'admin', 'admin_verbs.dm'), encoding='utf-8') as f:
            self.assertIn('/client/proc/cmd_admin_karma,', f.read())
        with open(os.path.join(ROOT, 'code', 'modules', 'admin', 'player_panel_pages.dm'), encoding='utf-8') as f:
            panel = f.read()
        # The Player Panel shows the karma card to admins only.
        self.assertIn('if (karma_key && (rights & R_ADMIN))', panel)
        self.assertIn('player_karma_tiles_html(karma_key)', panel)

    def test_every_change_needs_a_reason_and_is_logged(self):
        for action in ('karma_set_standing(', 'karma_set_bar(', 'shared_records.revoke(target'):
            self.assertIn(action, self.dm)
        self.assertEqual(self.dm.count('karma_staff_log(C,'), 3)
        self.assertEqual(self.dm.count('if (!reason)'), 3)
        self.assertIn('log_admin(', self.dm)

    def test_the_dossier_shows_what_staff_asked_for(self):
        for shown in ('giver_standing', 'giver_hours', 'giver_notes', 'Playtime', 'per10h', 'factors["standing"]',
                      'factors["playtime"]', 'factors["age"]', 'row["note"]'):
            self.assertIn(shown, self.dm)
        self.assertIn('show_browse(C, html', self.dm)

    def test_staff_see_the_badge_where_they_meet_players(self):
        self.assertIn('/proc/karma_staff_badge(ckey)', self.dm)
        self.assertIn('karma/[ckey].json', self.dm)
        self.assertIn('karma_dossier(ckey)', self.dm)  # no coordinator: computed from the journal
        def src(*parts):
            with open(os.path.join(ROOT, *parts), encoding='utf-8') as f:
                return f.read()
        for parts in (('code', 'game', 'mob', 'pray.dm'), ('code', 'modules', 'divine', 'covenant.dm'),
                      ('code', 'modules', 'admin', 'verbs', 'divine_patron.dm'), ('code', 'modules', 'admin', 'topic.dm')):
            self.assertIn('karma_staff_badge(karma', src(*parts), parts)
        self.assertIn('check_rights(R_ADMIN, FALSE) && karma_mob_ckey(M)', src('code', 'modules', 'admin', 'topic.dm'))
        # Adminhelps: admins get the badge, mods and mentors the plain line.
        ahelp = src('code', 'modules', 'admin', 'verbs', 'adminhelp.dm')
        self.assertIn('(R_ADMIN & X.holder.rights) ? karma_msg : msg', ahelp)
        self.assertNotIn('karma_msg', ahelp.split('else if (R_MENTOR & X.holder.rights)')[1])


JS_STUB = '''
var nodes = {};
function node(tag) { return {tag: tag, children: [], style: {}, value: '', checked: false, textContent: '',
  attrs: {}, setAttribute: function (k, v) { this.attrs[k] = v; }, getAttribute: function (k) { return this.attrs[k]; },
  appendChild: function (c) { this.children.push(c); return c; },
  set innerHTML(v) { this.children = []; }, get innerHTML() { return ''; }}; }
var document = {createElement: node, querySelectorAll: function () { return []; },
  getElementById: function (id) { if (!nodes[id]) nodes[id] = node(id); return nodes[id]; }};
'''

JS_IDS = ['k_group', 'k_kind', 'k_standing', 'k_from', 'k_to', 'k_minhours', 'k_notes', 'k_flagged', 'k_disagree',
          'k_target', 'k_giver', 'k_faction', 'k_region', 'k_min', 'k_showrows', 'k_f_standing', 'k_f_playtime',
          'k_f_age', 'k_f_banned', 'k_preset', 'k_table', 'k_rows', 'k_count', 'k_csv']

ROWS = [
    {'target': 'bob', 'target_hours': 20, 'target_standing': -1, 'giver': 'amy', 'kind': 'kindly',
     'factors': {'standing': 1.2, 'playtime': 0.5, 'age': 1}, 'giver_standing': 'good', 'giver_hours': 50,
     'giver_notes': False, 'flags': [], 'faction': 'reds', 'region': 'gaia', 'at': '2026-11-18', 'note': 'kind, "really"'},
    {'target': 'bob', 'target_hours': 20, 'target_standing': -1, 'giver': 'eve', 'kind': 'poorly',
     'factors': {'standing': 1, 'playtime': 1, 'age': 1}, 'giver_standing': 'neutral', 'giver_hours': 300,
     'giver_notes': True, 'flags': ['giver_banned'], 'faction': 'blues', 'region': 'europe', 'at': '2026-11-10', 'note': ''},
    {'target': 'cat', 'target_hours': 5, 'target_standing': None, 'giver': 'amy', 'kind': 'poorly',
     'factors': {'standing': 1.2, 'playtime': 0.5, 'age': 1}, 'giver_standing': 'good', 'giver_hours': 50,
     'giver_notes': False, 'flags': ['burst'], 'faction': 'reds', 'region': 'gaia', 'at': '2026-11-19', 'note': ''},
]


@unittest.skipUnless(shutil.which('node'), 'node not installed')
class KarmaAnalysisView(unittest.TestCase):
    """code/js/karma_analysis.js: grouping, filters, factor toggles and CSV, under node with a tiny DOM."""

    def run_js(self, setup, probe):
        with open(os.path.join(ROOT, 'code', 'js', 'karma_analysis.js'), encoding='utf-8') as f:
            script = f.read()
        prelude = ''.join('document.getElementById(%s);' % json.dumps(i) for i in JS_IDS)
        prelude += ''.join('nodes.%s.checked = true;' % i for i in ('k_f_standing', 'k_f_playtime', 'k_f_age', 'k_f_banned'))
        prelude += 'nodes.k_group.value = "target";'
        code = JS_STUB + script + prelude + setup + 'karmaInit(%s, "");' % json.dumps(ROWS) + \
            'console.log(JSON.stringify(%s));' % probe
        out = subprocess.run(['node', '-e', code], capture_output=True, text=True, timeout=30)
        self.assertEqual(out.returncode, 0, out.stderr)
        return json.loads(out.stdout)

    TABLE = 'nodes.k_table.children.slice(1).map(function (r) { return r.children.map(function (c) { return c.textContent; }); })'

    def test_groups_by_rated_player_and_drops_banned_givers_by_default(self):
        bob = [r for r in self.run_js('', self.TABLE) if r[0] == 'bob'][0]
        self.assertEqual(bob[1:7], ['2', '1', '1', '0.6', '0', '0.6'])  # eve is banned: weight 0
        self.assertEqual(bob[7], '0.3')  # 0.6 net over 20 hours, per 10 hours

    def test_factor_toggles_change_the_weights(self):
        rows = self.run_js('nodes.k_f_banned.checked = false; nodes.k_f_playtime.checked = false;', self.TABLE)
        bob = [r for r in rows if r[0] == 'bob'][0]
        self.assertEqual(bob[4:7], ['1.2', '1', '0.2'])

    def test_filters(self):
        rows = self.run_js('nodes.k_group.value = "giver"; nodes.k_flagged.checked = true;', self.TABLE)
        self.assertEqual(sorted(r[0] for r in rows), ['amy', 'eve'])
        rows = self.run_js('nodes.k_disagree.checked = true; nodes.k_group.value = "giver";', self.TABLE)
        self.assertEqual([r[0] for r in rows], ['amy'])  # kindly to a player staff rate poor
        self.assertEqual(self.run_js('nodes.k_from.value = "2026-11-15";', 'nodes.k_count.textContent'),
                         '2 ratings in 2 groups')
        weeks = self.run_js('nodes.k_group.value = "week";', self.TABLE)
        self.assertEqual(sorted(r[0] for r in weeks), ['week of 2026-11-09', 'week of 2026-11-16'])

    def test_csv_quotes_fields(self):
        csv = self.run_js('', 'nodes.k_csv.value')
        lines = csv.split('\n')
        self.assertTrue(lines[0].startswith('target,target_hours,target_standing,giver,kind,weight'))
        self.assertIn('"kind, ""really"""', csv)
        self.assertEqual(len(lines), 4)


class KarmaCsvReport(unittest.TestCase):
    def test_host_csv_lists_every_live_rating(self):
        import io
        db = sqlite3.connect(':memory:', isolation_level=None)
        records.init_group(db)
        records.store_records(db, 'gaia', [{'id': '%032x' % 1, 'ckey': 'bob', 'kind': 'karma_rating', 'author': 'amy',
                                            'rank': 'Player', 'at': NOW, 'body': {'giver': 'amy', 'rating': 'kindly',
                                                                                  'note': 'a, b'}}], NOW)
        out = io.StringIO()
        karma.write_csv(karma.snapshots(db, NOW, {'amy': 50}), out)
        lines = out.getvalue().splitlines()
        self.assertEqual(lines[0].split(','), list(karma.CSV_COLUMNS))
        self.assertTrue(lines[1].startswith('bob,0,,amy,kindly,0.5,1.0,0.5,1.0,unknown,50,0,,,gaia,'))
        self.assertTrue(lines[1].endswith('"a, b"'))
        db.close()


if __name__ == '__main__':
    unittest.main()
