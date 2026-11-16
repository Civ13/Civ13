"""Tests for tools/player_activity/aggregate.py on small sample region folders."""
import datetime as dt
import json
import pathlib
import sqlite3
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools' / 'player_activity'))
import aggregate  # noqa: E402

DAY = 86400


def write(folder, day, lines):
    path = pathlib.Path(folder) / 'data' / 'player_activity' / ('%s.jsonl' % day)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('a', encoding='utf-8') as stream:
        for line in lines:
            stream.write(json.dumps(line) + '\n')
    return path


class Aggregate(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        self.db = aggregate.connect(self.root / 'activity.sqlite')
        self.yesterday = (dt.date.today() - dt.timedelta(days=1)).isoformat()
        self.today = dt.date.today().isoformat()
        self.dirs = {'gaia': self.root / 'gaia', 'europe': self.root / 'europe'}

    def tearDown(self):
        self.db.close()
        self.tmp.cleanup()

    def sample(self):
        write(self.dirs['gaia'], self.yesterday, [
            {'e': 'boot', 's': 36000, 'boot': 'b1', 'tz': 0, 'region': 'gaia', 'v': 1},
            {'e': 'join', 's': 36000, 'a': 'alice', 'via': 'byond'},
            {'e': 'hb', 's': 36300, 'a': 'alice', 'act': 1, 'st': 'alive'},
            {'e': 'death', 's': 36400, 'a': 'alice', 'cause': 'starved', 'smin': 7},
            {'e': 'depart', 's': 36500, 'a': 'alice', 'to': 'europe', 'how': 'edge'},
            {'e': 'leave', 's': 36510, 'a': 'alice', 'min': 8.5, 'why': 'travel', 'to': 'europe'},
            {'e': 'health', 's': 36300, 'p': 3, 'living': 2, 'dil': 4.0, 'cpu': 30},
            {'e': 'death', 's': 36600, 'a': 'agent@ada', 'cause': 'wounded', 'agent': 1},
        ])
        write(self.dirs['europe'], self.yesterday, [
            {'e': 'boot', 's': 36000, 'boot': 'b2', 'tz': 0, 'region': 'europe', 'v': 1},
            {'e': 'join', 's': 36560, 'a': 'alice', 'via': 'byond'},
            {'e': 'hb', 's': 36800, 'a': 'alice', 'act': 0, 'st': 'alive'},
            {'e': 'death', 's': 36900, 'a': 'carol', 'cause': 'player', 'by': 'alice'},
        ])

    def test_reads_once_and_archives_past_days(self):
        self.sample()
        self.assertEqual(aggregate.ingest(self.db, self.dirs), 10)
        self.assertEqual(aggregate.ingest(self.db, self.dirs), 0)
        self.assertFalse((self.dirs['gaia'] / 'data/player_activity' / ('%s.jsonl' % self.yesterday)).exists())
        self.assertTrue((self.dirs['gaia'] / 'data/player_activity/read' / ('%s.jsonl.gz' % self.yesterday)).exists())

    def test_today_file_kept_and_partial_line_waits(self):
        path = write(self.dirs['gaia'], self.today, [{'e': 'boot', 's': 10, 'boot': 'b', 'tz': 0}, {'e': 'join', 's': 100, 'a': 'bob'}])
        with path.open('a') as stream:
            stream.write('{"e": "hb", "s": 400, "a": "bob"')
        self.assertEqual(aggregate.ingest(self.db, self.dirs), 1)
        self.assertTrue(path.exists())
        with path.open('a') as stream:
            stream.write(', "act": 1}\n')
        self.assertEqual(aggregate.ingest(self.db, self.dirs), 1)

    def test_lines_before_midnight_in_new_file(self):
        write(self.dirs['gaia'], self.today, [{'e': 'boot', 's': 10, 'boot': 'b', 'tz': 0}, {'e': 'hb', 's': 86390, 'a': 'bob'}, {'e': 'join', 's': 100, 'a': 'bob'}])
        aggregate.ingest(self.db, self.dirs)
        hb, join = [row[0] for row in self.db.execute("SELECT ts FROM event WHERE account = 'bob' ORDER BY id")]
        self.assertLess(hb, join)

    def test_timezone_moves_to_utc(self):
        write(self.dirs['gaia'], self.yesterday, [{'e': 'boot', 's': 0, 'boot': 'b', 'tz': -5}, {'e': 'join', 's': 3600, 'a': 'bob'}])
        aggregate.ingest(self.db, self.dirs)
        ts = self.db.execute("SELECT ts FROM event WHERE account = 'bob'").fetchone()[0]
        self.assertEqual(ts, aggregate.day_start(self.yesterday) + 3600 + 5 * 3600)

    def test_report(self):
        self.sample()
        aggregate.ingest(self.db, self.dirs)
        data = aggregate.report(self.db, now=aggregate.day_start(self.yesterday) + 40000)
        self.assertEqual(data['active']['day'], 2)  # alice, carol; the agent is left out
        self.assertEqual(data['sessions_this_week'], 1)  # alice's two regions are one play session
        causes = {row['cause']: row['n'] for row in data['deaths_by_cause']}
        self.assertEqual(causes, {'starved': 1, 'player': 1})
        self.assertEqual(data['travel'], [{'origin': 'gaia', 'dest': 'europe', 'how': 'edge', 'n': 1}])
        self.assertEqual(data['lag_by_player_count'][0]['players'], 3)

    def test_daily_rollup(self):
        self.sample()
        aggregate.ingest(self.db, self.dirs)
        rows = {(r['account'], r['region']): dict(r) for r in self.db.execute('SELECT * FROM daily')}
        self.assertEqual(rows[('alice', 'gaia')]['active_minutes'], 5)
        self.assertEqual(rows[('alice', 'europe')]['active_minutes'], 0)
        self.assertEqual(rows[('alice', 'gaia')]['deaths'], 1)

    def test_forget(self):
        self.sample()
        aggregate.ingest(self.db, self.dirs)
        aggregate.forget(self.db, 'alice')
        self.assertEqual(self.db.execute("SELECT COUNT(*) FROM event WHERE account = 'alice' OR data LIKE '%alice%'").fetchone()[0], 0)
        self.assertIsNone(self.db.execute("SELECT 1 FROM account WHERE account = 'alice'").fetchone())
        write(self.dirs['gaia'], self.today, [{'e': 'boot', 's': 10, 'boot': 'b', 'tz': 0}, {'e': 'join', 's': 100, 'a': 'alice'}])
        aggregate.ingest(self.db, self.dirs)
        self.assertEqual(self.db.execute("SELECT COUNT(*) FROM event WHERE account = 'alice'").fetchone()[0], 0)

    def test_prune(self):
        write(self.dirs['gaia'], self.yesterday, [{'e': 'boot', 's': 0, 'boot': 'b', 'tz': 0}, {'e': 'join', 's': 100, 'a': 'bob'}])
        aggregate.ingest(self.db, self.dirs, now=aggregate.day_start(self.yesterday) + 100 * DAY)
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM event').fetchone()[0], 0)

    def test_group_config(self):
        group = self.root / 'group.json'
        group.write_text(json.dumps({'root': str(self.root), 'regions': [{'id': 'gaia'}, {'id': 'europe'}]}))
        self.assertEqual(aggregate.region_dirs_from_group(group), self.dirs)

    def test_never_opens_coordinator(self):
        source = (ROOT / 'tools/player_activity/aggregate.py').read_text(encoding='utf-8')
        code = source.split('"""', 2)[2]
        self.assertNotIn('coordinator.sqlite', code)
        self.assertNotIn('transfers.sqlite', code)


if __name__ == '__main__':
    unittest.main()


class HostSideJob(unittest.TestCase):
    """The host service reads activity every PLAYER_ACTIVITY_MINUTES from supervise()."""

    def test_ingest_when_due(self):
        sys.path.insert(0, str(ROOT / 'scripts' / 'shard-group'))
        import shard_group
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            group = {'root': str(root), 'regions': [{'id': 'gaia'}, {'id': 'europe'}]}
            self.assertIsNone(shard_group.ingest_player_activity(group))  # nothing recorded yet
            yesterday = (dt.date.today() - dt.timedelta(days=1)).isoformat()
            write(root / 'gaia', yesterday, [{'e': 'boot', 's': 0, 'boot': 'b', 'tz': 0}, {'e': 'join', 's': 100, 'a': 'bob'}])
            self.assertEqual(shard_group.ingest_player_activity(group), 1)
            self.assertIsNone(shard_group.ingest_player_activity(group))  # not due again yet
            db = sqlite3.connect(str(root / 'player-activity.sqlite'))
            self.assertEqual(db.execute('SELECT COUNT(*) FROM event').fetchone()[0], 1)
            db.close()

    def test_supervise_calls_it(self):
        source = (ROOT / 'scripts/shard-group/shard_group.py').read_text(encoding='utf-8')
        body = source.split('def supervise(group, start=detach):', 1)[1].split('\ndef ', 1)[0]
        self.assertIn('ingest_player_activity(group)', body)
