"""Shared player records (tools/transfer_storage/records.py and
code/modules/admin/shared_player_records.dm): two agents and a coordinator over
HTTP, the snapshot files, playtime, and DM source contracts. Never launches BYOND."""
import json
import os
import re
import sqlite3
import sys
import tempfile
import threading
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, ROOT)
sys.path.insert(0, os.path.join(ROOT, 'tools', 'player_activity'))
from tools.transfer_storage import records  # noqa: E402
from tools.transfer_storage.agent import make_server  # noqa: E402
from tools.transfer_storage.coordinator import Coordinator, call  # noqa: E402
from tools.transfer_storage.region import RegionStore  # noqa: E402
import aggregate  # noqa: E402

TOKENS = {'alpha': 'a' * 40, 'beta': 'b' * 40}
NOW = 1_800_000_000


def rid(n):
    return '%032x' % n


def record(n, ckey='bob', kind='note', body=None, at=NOW - 100):
    return {'id': rid(n), 'ckey': ckey, 'kind': kind, 'author': 'val', 'rank': 'Host', 'region': 'ignored',
            'at': at, 'body': body if body is not None else {'text': 'note %d' % n}}


def read(path):
    with open(path, encoding='utf-8') as f:
        return json.load(f)


class SharedRecords(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = self.tmp.name
        self.stores, self.servers, self.urls = {}, {}, {}
        for name, token in TOKENS.items():
            store = RegionStore(os.path.join(self.root, name + '.sqlite'), name, 'g')
            server = make_server(store, token)
            threading.Thread(target=server.serve_forever, daemon=True).start()
            self.stores[name], self.servers[name] = store, server
            self.urls[name] = 'http://127.0.0.1:%d' % server.server_address[1]
        self.coordinator = Coordinator(os.path.join(self.root, 'coordinator.sqlite'), 'g')
        for name, token in TOKENS.items():
            self.coordinator.enroll(name, self.urls[name], token)
        self.shared = os.path.join(self.root, 'shared-records')

    def tearDown(self):
        for name in self.servers:
            self.servers[name].shutdown()
            self.servers[name].server_close()
            self.stores[name].close()
        self.coordinator.close()
        self.tmp.cleanup()

    def send(self, region, *recs):
        return call(self.urls[region], TOKENS[region], '/record', {'records': list(recs)})

    def index(self):
        return read(os.path.join(self.shared, 'index.json'))

    def test_a_record_made_on_one_region_is_published_for_all(self):
        answer = self.send('alpha', record(1))
        self.assertTrue(answer['ok'])
        self.assertEqual([rid(1)], answer['result']['ids'])
        self.assertEqual(1, self.coordinator.records_once(NOW))
        index = self.index()
        self.assertEqual(1, index['players']['bob']['notes'])
        self.assertEqual(str(NOW), index['pulled']['alpha'])
        self.assertEqual(str(NOW - 100), read(os.path.join(self.shared, 'players', 'b', 'bob.json'))['records'][0]['at'])
        player = read(os.path.join(self.shared, 'players', 'b', 'bob.json'))
        self.assertEqual('alpha', player['records'][0]['region'])  # the agent's region, not the record's claim
        self.assertEqual({'text': 'note 1'}, player['records'][0]['body'])
        # Acknowledged: the agent's queue is empty and a second pass stores nothing.
        self.assertEqual([], call(self.urls['alpha'], TOKENS['alpha'], '/records/outbox')['result']['records'])
        self.assertEqual(0, self.coordinator.records_once(NOW + 1))

    def test_the_same_record_from_two_regions_is_stored_once(self):
        self.send('alpha', record(7))
        self.send('alpha', record(7))  # resent after a lost answer
        self.send('beta', record(7))  # a migrated copy on another region
        self.coordinator.records_once(NOW)
        self.assertEqual(1, self.coordinator.db.execute('SELECT COUNT(*) FROM player_record').fetchone()[0])
        self.assertEqual(1, self.index()['players']['bob']['notes'])

    def test_dm_sends_times_as_digit_strings(self):
        self.assertTrue(self.send('alpha', dict(record(1, kind='ban', body={'scope': 'game', 'until': str(NOW + 60)}),
                                                at=str(NOW - 5)))['ok'])
        self.coordinator.records_once(NOW)
        ban = read(os.path.join(self.shared, 'bans.json'))['bans'][0]
        self.assertEqual((str(NOW - 5), str(NOW + 60)), (ban['at'], ban['until']))
        self.assertEqual(NOW - 5, self.coordinator.db.execute('SELECT at FROM player_record').fetchone()[0])

    def test_bad_records_are_refused_by_the_agent(self):
        for bad in (dict(record(1), id='xyz'), dict(record(1), ckey='Bob Smith'), dict(record(1), kind='Note!'),
                    dict(record(1), body='text'), dict(record(1), body={'t': 'x' * 20000}),
                    record(1, kind='ban', body={'scope': 'everything'}),
                    record(1, kind='revoke', body={'target': rid(1)})):
            answer = self.send('alpha', bad)
            self.assertFalse(answer['ok'], bad)
        self.assertEqual([], call(self.urls['alpha'], TOKENS['alpha'], '/records/outbox')['result']['records'])

    def test_revoke_hides_a_record_but_keeps_it(self):
        self.send('alpha', record(1), record(2, kind='warning', body={'text': 'spam'}))
        self.coordinator.records_once(NOW)
        self.send('beta', record(3, kind='revoke', body={'target': rid(2), 'target_kind': 'warning', 'reason': 'mistake'}))
        self.coordinator.records_once(NOW + 5)
        entry = self.index()['players']['bob']
        self.assertEqual(0, entry['warnings'])
        self.assertEqual(1, entry['notes'])
        player = read(os.path.join(self.shared, 'players', 'b', 'bob.json'))
        warning = [r for r in player['records'] if r['id'] == rid(2)][0]
        self.assertEqual('val', warning['revoked']['by'])
        self.assertEqual('mistake', warning['revoked']['reason'])

    def test_active_bans_end_on_their_own(self):
        self.send('alpha', record(1, kind='ban', body={'scope': 'game', 'until': NOW + 60, 'reason': 'grief'}),
                  record(2, ckey='eve', kind='ban', body={'scope': 'game', 'until': 0, 'reason': 'perma'}),
                  record(3, ckey='eve', kind='ban', body={'scope': 'ooc', 'until': 0}))
        self.coordinator.records_once(NOW)
        bans = read(os.path.join(self.shared, 'bans.json'))['bans']
        self.assertEqual({rid(1), rid(2), rid(3)}, {b['id'] for b in bans})
        self.assertEqual([{'id': rid(1), 'scope': 'game', 'until': str(NOW + 60)}], self.index()['players']['bob']['bans'])
        self.assertIn('0', {b['until'] for b in bans})
        # An hour later the temporary ban is gone with no unban record.
        self.coordinator.records_once(NOW + 3600)
        self.assertEqual({rid(2), rid(3)}, {b['id'] for b in read(os.path.join(self.shared, 'bans.json'))['bans']})
        self.assertEqual([], self.index()['players']['bob']['bans'])

    def test_play_bans_and_ckeyless_bans_are_published(self):
        self.assertTrue(self.send('alpha', record(1, ckey='@nockey', kind='ban',
                                                  body={'scope': 'play', 'until': 0, 'ip': '10.0.0.1', 'cid': 'nil'}))['ok'])
        self.coordinator.records_once(NOW)
        ban = read(os.path.join(self.shared, 'bans.json'))['bans'][0]
        self.assertEqual(('@nockey', 'play', '10.0.0.1'), (ban['ckey'], ban['scope'], ban['ip']))

    def test_connections_are_published_for_alt_lookups(self):
        self.send('alpha', record(1, kind='connection', body={'ip': '10.0.0.1', 'cid': '123'}))
        self.send('beta', record(2, ckey='amy', kind='connection', body={'ip': '10.0.0.1', 'cid': '456'}))
        self.coordinator.records_once(NOW)
        seen = read(os.path.join(self.shared, 'connections.json'))['connections']
        self.assertEqual({('bob', '10.0.0.1', '123'), ('amy', '10.0.0.1', '456')}, {(c['ckey'], c['ip'], c['cid']) for c in seen})
        self.assertEqual({str(NOW - 100)}, {c['at'] for c in seen})
        # Connections are not notes: they leave the per-player counts alone.
        self.assertEqual(0, self.index()['players']['bob']['notes'])

    def test_a_down_agent_keeps_its_records_for_later(self):
        self.send('beta', record(9, ckey='amy'))
        self.servers['beta'].shutdown()
        self.servers['beta'].server_close()
        self.send('alpha', record(1))
        self.coordinator.records_once(NOW)
        self.assertNotIn('amy', self.index()['players'])
        self.assertNotIn('beta', self.index()['pulled'])
        server = make_server(self.stores['beta'], TOKENS['beta'])
        threading.Thread(target=server.serve_forever, daemon=True).start()
        self.servers['beta'] = server
        self.coordinator.enroll('beta', 'http://127.0.0.1:%d' % server.server_address[1], TOKENS['beta'])
        self.urls['beta'] = 'http://127.0.0.1:%d' % server.server_address[1]
        self.coordinator.records_once(NOW + 10)
        self.assertEqual(1, self.index()['players']['amy']['notes'])

    def test_a_full_batch_does_not_advance_the_pull_time(self):
        db = sqlite3.connect(':memory:')
        records.init_group(db)
        records.store_records(db, 'alpha', [record(n) for n in range(1, records.OUTBOX_BATCH + 1)], NOW)
        self.assertIsNone(db.execute("SELECT at FROM record_pull WHERE region = 'alpha'").fetchone())
        records.store_records(db, 'alpha', [], NOW + 5)
        self.assertEqual(NOW + 5, db.execute("SELECT at FROM record_pull WHERE region = 'alpha'").fetchone()[0])

    def test_other_folders_beside_the_snapshots_are_left_alone(self):
        karma = os.path.join(self.shared, 'karma', 'bob.json')
        os.makedirs(os.path.dirname(karma))
        with open(karma, 'w') as f:
            f.write('{"kept": true}')
        self.send('alpha', record(1))
        self.coordinator.records_once(NOW)
        self.assertEqual({'kept': True}, read(karma))
        self.assertFalse([n for n in os.listdir(self.shared) if n.endswith('.tmp')])

    def test_playtime_counts_only_alive_and_awake_heartbeats(self):
        db = aggregate.connect(os.path.join(self.root, 'player-activity.sqlite'))
        db.execute("INSERT INTO account (account, first_ts, last_ts, ckey) VALUES ('bob', 1, 1, 'bob')")
        db.execute("INSERT INTO account (account, first_ts, last_ts, ckey) VALUES ('d:42', 1, 1, 'amy')")
        db.execute("INSERT INTO account (account, first_ts, last_ts, ckey, agent) VALUES ('agent@x', 1, 1, NULL, 1)")
        events = [('bob', 'alive')] * 12 + [('bob', 'asleep')] * 6 + [('bob', 'dead')] * 3 + [('bob', 'lobby')] * 2 + \
                 [('d:42', 'alive')] * 24 + [('agent@x', 'alive')] * 12
        for n, (account, state) in enumerate(events):
            db.execute("INSERT INTO event (region, ts, day, e, account, data) VALUES ('gaia', ?, '2026-11-18', 'hb', ?, ?)",
                       (n, account, json.dumps({'st': state, 'act': 0})))
        aggregate.rebuild_daily(db, ['2026-11-18'])
        db.commit()
        db.close()
        self.coordinator.records_once(NOW)
        index = self.index()
        self.assertEqual(1.0, index['players']['bob']['hours'])  # 12 x 5 minutes; idle time counts
        self.assertEqual(2.0, index['players']['amy']['hours'])
        self.assertEqual({'d:42': 'amy'}, index['accounts'])
        self.assertNotIn('agent@x', index['players'])

    def test_old_activity_database_gains_alive_minutes(self):
        path = os.path.join(self.root, 'old.sqlite')
        db = sqlite3.connect(path)
        db.executescript(aggregate.SCHEMA)
        db.execute("INSERT INTO event (region, ts, day, e, account, data) VALUES ('gaia', 1, '2026-11-18', 'hb', 'bob', ?)",
                   (json.dumps({'st': 'alive'}),))
        db.commit()
        db.close()
        db = aggregate.connect(path)
        self.assertEqual(5, db.execute('SELECT alive_minutes FROM daily').fetchone()[0])
        db.close()


DM = open(os.path.join(ROOT, 'code/modules/admin/shared_player_records.dm'), encoding='utf-8').read()


class SharedRecordsSource(unittest.TestCase):
    def test_included_and_ticked(self):
        dme = open(os.path.join(ROOT, 'civ13.dme'), encoding='utf-8').read()
        self.assertIn('#include "code\\modules\\admin\\shared_player_records.dm"', dme)
        relay = open(os.path.join(ROOT, 'code/modules/1713/radio_relay.dm'), encoding='utf-8').read()
        self.assertIn('shared_records.tick()', relay)

    def test_reads_the_group_folder_and_keeps_a_local_journal(self):
        self.assertIn('"../shared-records/"', DM)
        self.assertIn('"data/player_records.json"', DM)
        self.assertIn('transfer_bridge.request("/record"', DM)

    def test_a_refused_record_is_never_dropped_as_synced(self):
        self.assertIn('record["sent"] = -1', DM)
        self.assertIn('unix_valid(record["sent"]) && unix_after(pull, record["sent"])', DM)

    def test_file_local_defines_are_undefined(self):
        for name in re.findall(r'^#define (\w+)', DM, re.M):
            self.assertIn('#undef ' + name, DM)

    def test_notes_and_warnings_use_the_shared_records(self):
        notes = open(os.path.join(ROOT, 'code/modules/admin/player_notes.dm'), encoding='utf-8').read()
        self.assertNotIn('info << infos', notes)  # old notes are only read, for the one-time copy
        self.assertIn('shared_records.add(key, "note"', notes)
        self.assertIn('shared_records.revoke(record', notes)
        topic = open(os.path.join(ROOT, 'code/modules/admin/topic.dm'), encoding='utf-8').read()
        self.assertIn('notes_del(key, href_list["remove_id"], usr)', topic)
        warn = open(os.path.join(ROOT, 'code/modules/admin/verbs/warn.dm'), encoding='utf-8').read()
        self.assertLess(warn.index('notes_warn(warned_ckey, reason, usr)'), warn.index('for (var/client/C in clients)'))
        admin = open(os.path.join(ROOT, 'code/modules/admin/admin.dm'), encoding='utf-8').read()
        self.assertIn('shared_records.ckeys_with(list("note", "warning"))', admin)
        self.assertIn('var/list/infos = notes_for(key)', admin)

    def test_bans_use_the_shared_records(self):
        ban = open(os.path.join(ROOT, 'code/modules/admin/verbs/quickBan.dm'), encoding='utf-8').read()
        self.assertIn('shared_records.add(record_ckey, "ban"', ban)
        self.assertNotIn('text2file', ban.split('/proc/quickBan_migrate_legacy()')[0])  # bans.txt is only read, once
        for path, call_text in (('code/modules/client/client_procs.dm', 'quickBan_remove_uid(UID'),
                                ('code/modules/client/client_procs.dm', 'shared_records.note_connection(ckey, sql_ip, computer_id)'),
                                ('code/_helpers/_logging.dm', 'quickBan_lift_ckey(banned, banner)'),
                                ('code/modules/persistence/region_ooc.dm', 'quickBan_find_ban(ckey, null, null, ban_type)'),
                                ('code/modules/admin/admin.dm', 'quickBan_migrate_legacy()'),
                                ('code/modules/admin/admin_verbs.dm', '/client/proc/quickBan_unban')):
            source = open(os.path.join(ROOT, path), encoding='utf-8').read()
            self.assertIn(call_text, source, path)
            self.assertNotIn('fdel(bans_file)', source, path)

    def test_watchlist_and_memos_use_the_shared_records(self):
        client = open(os.path.join(ROOT, 'code/modules/client/client_procs.dm'), encoding='utf-8').read()
        self.assertIn('watchlist_login(src)', client)
        watch = open(os.path.join(ROOT, 'code/modules/admin/player_watchlist.dm'), encoding='utf-8').read()
        self.assertIn('region_asay_outbound("Watchlist"', watch)
        for path in ('code/modules/admin/admin_memo.dm', 'code/modules/admin/admin_2_player_memo.dm'):
            self.assertNotIn('savefile', open(os.path.join(ROOT, path), encoding='utf-8').read(), path)
        verbs = open(os.path.join(ROOT, 'code/modules/admin/admin_verbs.dm'), encoding='utf-8').read()
        for verb in ('admin_memo_write', 'admin_memo_delete', 'player_memo_write', 'player_memo_delete', 'watchlist_show'):
            self.assertIn('/client/proc/' + verb + ',', verbs)
        admin = open(os.path.join(ROOT, 'code/modules/admin/admin.dm'), encoding='utf-8').read()
        self.assertIn('player_records_summary_html(M.ckey, src)', admin)

    def test_heartbeat_reports_asleep(self):
        activity = open(os.path.join(ROOT, 'code/modules/player_activity/player_activity.dm'), encoding='utf-8').read()
        self.assertIn('if(L.stat == UNCONSCIOUS || L.sleeping) return "asleep"', activity)


if __name__ == '__main__':
    unittest.main()
