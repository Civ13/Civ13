"""Land stages: the coordinator keeps each land's stage and sends it to every agent."""
import json
import os
import subprocess
import sys
import tempfile
import threading
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, ROOT)
from tools.transfer_storage.agent import make_server  # noqa: E402
from tools.transfer_storage import coordinator as coordinator_module  # noqa: E402
from tools.transfer_storage.coordinator import Coordinator, call, read_lands  # noqa: E402
from tools.transfer_storage.region import RegionStore  # noqa: E402

TOKENS = {'alpha': 'a' * 40, 'beta': 'b' * 40, 'gamma': 'c' * 40}


class LandStageTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.stores, self.servers, self.urls = {}, {}, {}
        for name in ('alpha', 'beta', 'gamma'):
            store = RegionStore(os.path.join(self.tmp.name, name + '.sqlite'), name, 'g')
            server = make_server(store, TOKENS[name])
            threading.Thread(target=server.serve_forever, kwargs={'poll_interval': 0.01}, daemon=True).start()
            self.stores[name], self.servers[name] = store, server
            self.urls[name] = 'http://127.0.0.1:%d' % server.server_address[1]
        self.db = os.path.join(self.tmp.name, 'coordinator.sqlite')
        self.coordinator = Coordinator(self.db, 'g', 'alpha', bootstrap_new_group=True)
        for name in self.stores:
            self.coordinator.enroll(name, self.urls[name], TOKENS[name])
        self.coordinator.homes_once()

    def tearDown(self):
        for name in list(self.servers):
            self.servers[name].shutdown()
            self.servers[name].server_close()
            self.stores[name].close()
        self.coordinator.close()
        self.tmp.cleanup()

    def lands(self, region):
        answer = call(self.urls[region], TOKENS[region], '/lands')
        self.assertTrue(answer.get('ok'), answer)
        return answer['result']

    def set_land(self, region, land, stage, paused=False, admin='val'):
        return call(self.urls[region], TOKENS[region], '/land/set',
                    {'region': land, 'stage': stage, 'paused': 1 if paused else 0, 'admin': admin})

    def test_every_agent_learns_the_stages_and_unset_lands_are_closed(self):
        seen = self.lands('gamma')
        self.assertEqual('alpha', seen['mainland'])
        self.assertEqual('MAINLAND', seen['lands']['alpha']['stage'])
        self.assertEqual('CLOSED', seen['lands']['beta']['stage'])
        self.assertEqual([], seen['pending'])

    def test_an_admin_change_waits_for_the_pass_then_reaches_every_land(self):
        self.assertTrue(self.set_land('alpha', 'beta', 'FRONTIER').get('ok'))
        pending = self.lands('alpha')
        self.assertEqual('CLOSED', pending['lands']['beta']['stage'])
        self.assertEqual([{'region': 'beta', 'stage': 'FRONTIER', 'paused': False, 'admin': 'val'}], pending['pending'])
        self.coordinator.homes_once()
        for region in ('alpha', 'beta', 'gamma'):
            entry = self.lands(region)['lands']['beta']
            self.assertEqual(('FRONTIER', False, 'val'), (entry['stage'], entry['paused'], entry['by']))
        self.assertEqual([], self.lands('alpha')['pending'])

    def test_a_lands_later_change_wins_and_decided_requests_never_replay(self):
        self.set_land('gamma', 'beta', 'COLONY')
        self.set_land('gamma', 'beta', 'OPEN', paused=True)
        self.coordinator.homes_once()
        self.assertEqual(('OPEN', True), (self.coordinator.lands()['beta']['stage'], self.coordinator.lands()['beta']['paused']))
        # Another admin corrects it from the coordinator; the old requests,
        # already acknowledged, are gone and a later pass changes nothing.
        self.coordinator.set_land('beta', 'FRONTIER', False, 'admin2')
        self.coordinator.homes_once()
        self.assertEqual('FRONTIER', self.lands('gamma')['lands']['beta']['stage'])
        self.assertEqual([], self.stores['gamma'].account_requests()['land_requests'])

    def test_bad_requests_are_refused(self):
        self.assertFalse(self.set_land('alpha', 'beta', 'CAPITAL').get('ok'))
        self.assertFalse(self.set_land('alpha', 'Beta!', 'OPEN').get('ok'))
        self.assertFalse(self.set_land('alpha', 'alpha', 'OPEN').get('ok'), 'the mainland has no stage')
        self.assertFalse(self.set_land('alpha', 'beta', 'OPEN', admin='Not A Key').get('ok'))
        # A land the coordinator does not know is dropped at the pass.
        self.assertTrue(self.set_land('alpha', 'nowhere', 'OPEN').get('ok'))
        self.coordinator.homes_once()
        self.assertNotIn('nowhere', self.lands('alpha')['lands'])
        self.assertEqual([], self.lands('alpha')['pending'])

    def test_a_stage_change_never_moves_a_home(self):
        call(self.urls['alpha'], TOKENS['alpha'], '/account', {'ckey': 'val', 'op': 'claim'})
        self.coordinator.homes_once()
        self.assertEqual({'val': 'alpha'}, self.coordinator.homes())
        self.coordinator.set_land('beta', 'OPEN', False, 'val')
        self.coordinator.homes_once()
        self.assertEqual({'val': 'alpha'}, self.coordinator.homes())

    def test_command_line_sets_and_prints_stages(self):
        self.coordinator.close()
        script = os.path.join(ROOT, 'tools', 'transfer_storage', 'coordinator.py')
        out = subprocess.run([sys.executable, '-I', script, '--db', self.db, '--group', 'g', '--mainland', 'alpha',
                              '--set-land', 'beta=colony,paused'], capture_output=True, text=True, check=True).stdout
        self.assertEqual({'stage': 'COLONY', 'paused': True}, {k: json.loads(out)['beta'][k] for k in ('stage', 'paused')})
        bad = subprocess.run([sys.executable, '-I', script, '--db', self.db, '--group', 'g', '--mainland', 'alpha',
                              '--set-land', 'alpha=open'], capture_output=True, text=True)
        self.assertNotEqual(0, bad.returncode)
        self.coordinator = Coordinator(self.db, 'g', 'alpha')

    def fill(self, region, players, living, hours, now):
        for h in range(hours):
            self.coordinator.record_land_sample(region, {'players': players, 'living': living, 'at': int(now - h * 3600)},
                                                now=now - h * 3600)

    def test_worlds_samples_reach_the_weekly_numbers(self):
        answer = call(self.urls['beta'], TOKENS['beta'], '/land/sample', {'players': 4, 'living': 6})
        self.assertTrue(answer.get('ok'), answer)
        self.assertFalse(call(self.urls['beta'], TOKENS['beta'], '/land/sample', {'players': -1, 'living': 0}).get('ok'))
        self.coordinator.homes_once()
        ready = self.lands('gamma')['lands']['beta']['readiness']
        self.assertEqual((4.0, 4, 6, 1), (ready['players_avg'], ready['players_peak'], ready['living'], ready['hours']))
        self.assertIsNone(ready['suggest'])

    def test_an_old_sample_counts_for_nothing(self):
        now = 1_800_000_000
        self.assertFalse(self.coordinator.record_land_sample('beta', {'players': 9, 'living': 9, 'at': now - 600}, now=now))
        self.assertFalse(self.coordinator.record_land_sample('beta', {'players': 9, 'living': 9}, now=now))
        self.assertTrue(self.coordinator.record_land_sample('beta', {'players': 9, 'living': 9, 'at': now - 30}, now=now))

    def test_suggestions_follow_the_placeholder_gates(self):
        now = 1_800_000_000
        c = self.coordinator
        for i in range(coordinator_module.OPEN_HOMES):
            c._set_home('p%d' % i, 'beta')
        c.set_land('beta', 'COLONY', False, 'val')
        # Under a day of mainland numbers decides nothing.
        self.fill('alpha', 25, 30, coordinator_module.READY_MIN_HOURS - 1, now)
        self.fill('beta', 3, 12, 5, now)
        self.assertIsNone(c.lands(now)['beta']['readiness']['suggest'])
        self.fill('alpha', 25, 30, coordinator_module.READY_MIN_HOURS, now)
        self.assertEqual('OPEN', c.lands(now)['beta']['readiness']['suggest'])
        self.assertIsNone(c.lands(now)['alpha']['readiness']['suggest'], 'the mainland is never suggested')
        c.set_land('beta', 'OPEN', False, 'val')
        self.assertIsNone(c.lands(now)['beta']['readiness']['suggest'])
        # The land outgrows the mainland: pause, then resume once it no longer does.
        self.fill('beta', 3, 40, 1, now)
        self.assertEqual('PAUSE', c.lands(now)['beta']['readiness']['suggest'])
        c.set_land('beta', 'OPEN', True, 'val')
        self.assertIsNone(c.lands(now)['beta']['readiness']['suggest'])
        self.fill('beta', 3, 12, 1, now)
        self.assertEqual('RESUME', c.lands(now)['beta']['readiness']['suggest'])
        # Read-only view for the host tool matches the coordinator's own.
        self.assertEqual(c.lands(now), read_lands(self.db, 'alpha', now))
        self.assertEqual({}, read_lands(os.path.join(self.tmp.name, 'missing.sqlite'), 'alpha', now))

    def test_colonies_reach_the_coordinator_and_a_standing_one_suggests_colony(self):
        colony = {'parent': 'civ:alpha:Wolves', 'name': 'Wolves', 'age_hours': 5, 'members': 3}
        answer = call(self.urls['beta'], TOKENS['beta'], '/land/sample', {'players': 2, 'living': 3, 'colonies': [colony]})
        self.assertTrue(answer.get('ok'), answer)
        for bad in ([dict(colony, parent='Wolves')], [dict(colony, parent='civ:Alpha!:Wolves')],
                    [dict(colony, members=-1)], [dict(colony, name='')], [dict(colony, age_hours=1.5)], 'Wolves'):
            self.assertFalse(call(self.urls['beta'], TOKENS['beta'], '/land/sample',
                                  {'players': 2, 'living': 3, 'colonies': bad}).get('ok'), bad)
        self.coordinator.homes_once()
        seen = self.lands('gamma')['lands']['beta']['colonies']
        self.assertEqual([('civ:alpha:Wolves', 'Wolves', 3)], [(c['parent'], c['name'], c['members']) for c in seen])
        c, now = self.coordinator, 1_800_000_000
        c.set_land('beta', 'FRONTIER', False, 'val')
        days = coordinator_module.COLONY_SECONDS // 3600

        def sample(**kw):
            row = dict(colony, **kw)
            self.assertTrue(c.record_land_sample('beta', {'players': 1, 'living': 3, 'at': now, 'colonies': [row]}, now=now))
            return c.lands(now)['beta']

        self.assertEqual(now - 3600, sample(age_hours=1)['colonies'][0]['founded'])
        self.assertIsNone(sample(age_hours=days - 1)['readiness']['suggest'], 'too young')
        self.assertIsNone(sample(age_hours=days, members=coordinator_module.COLONY_MEMBERS - 1)['readiness']['suggest'],
                          'too few members')
        self.assertEqual('COLONY', sample(age_hours=days)['readiness']['suggest'])
        c.set_land('beta', 'COLONY', False, 'val')
        self.assertIsNone(c.lands(now)['beta']['readiness']['suggest'])
        # A colony the world stops reporting is gone.
        c.record_land_sample('beta', {'players': 1, 'living': 3, 'at': now, 'colonies': []}, now=now)
        self.assertEqual([], c.lands(now)['beta']['colonies'])
    def test_a_member_starts_at_its_colony_only_where_it_stands_and_the_land_allows(self):
        wolves = 'civ:alpha:Wolves'
        call(self.urls['beta'], TOKENS['beta'], '/land/sample', {'players': 1, 'living': 3, 'colonies': [
            {'parent': wolves, 'name': 'Wolves', 'age_hours': 80, 'members': 3}]})

        def ask(land, ckey, op, **kw):
            return call(self.urls[land], TOKENS[land], '/account', dict({'ckey': ckey, 'op': op}, **kw))

        self.assertFalse(ask('alpha', 'val', 'colony', region='beta', faction='Wolves').get('ok'))
        self.assertFalse(ask('alpha', 'val', 'colony', region='alpha', faction=wolves).get('ok'))
        # A frontier land takes no colony starts yet.
        self.coordinator.set_land('beta', 'FRONTIER', False, 'val')
        ask('alpha', 'val', 'colony', region='beta', faction=wolves)
        self.coordinator.homes_once()
        self.assertIsNone(self.coordinator.home('val'))
        self.coordinator.set_land('beta', 'COLONY', True, 'val')
        # Only the faction's own land vouches for its members.
        ask('gamma', 'ann', 'colony', region='beta', faction=wolves)
        ask('alpha', 'val', 'colony', region='beta', faction=wolves)
        self.coordinator.homes_once()
        self.assertIsNone(self.coordinator.home('ann'))
        self.assertEqual('beta', self.coordinator.home('val'))
        self.coordinator.homes_once()
        claim = ask('beta', 'val', 'claim')['result']
        self.assertEqual(('HOME', wolves), (claim['verdict'], claim['colony_grant']))
        self.assertEqual('ELSEWHERE', ask('alpha', 'val', 'claim')['result']['verdict'])
        self.assertTrue(ask('beta', 'val', 'colony_used', faction=wolves).get('ok'))
        self.assertIsNone(ask('beta', 'val', 'claim')['result'].get('colony_grant'))
        self.coordinator.homes_once()
        self.coordinator.homes_once()
        self.assertEqual([], self.stores['beta'].db.execute('SELECT * FROM colony_grant').fetchall())
        self.assertEqual([], self.coordinator.db.execute('SELECT * FROM colony_grant').fetchall())

    def test_a_colony_nobody_lives_in_for_days_pauses_its_start(self):
        c, now = self.coordinator, 1_800_000_000
        wolves = 'civ:alpha:Wolves'
        c.set_land('beta', 'COLONY', False, 'val')
        quiet = coordinator_module.COLONY_QUIET_SECONDS

        def sample(members, at):
            row = {'parent': wolves, 'name': 'Wolves', 'age_hours': 100, 'members': members}
            self.assertTrue(c.record_land_sample('beta', {'players': 1, 'living': members, 'at': at, 'colonies': [row]}, now=at))
            return c.lands(at)['beta']['colonies'][0]['paused']

        self.assertFalse(sample(1, now))
        self.assertFalse(sample(1, now + quiet - 60), 'quiet only since the first low sample')
        self.assertTrue(sample(0, now + quiet))
        self.assertFalse(c.colony_start_allowed('alpha', 'beta', wolves, now + quiet))
        # Members back: the colony takes starts again at once.
        self.assertFalse(sample(2, now + quiet + 60))
        self.assertTrue(c.colony_start_allowed('alpha', 'beta', wolves, now + quiet + 60))
        self.assertFalse(sample(1, now + quiet + 120), 'the clock starts again')

    def test_a_player_starts_in_an_open_lands_wilds_from_their_home_only(self):
        def ask(land, ckey, op, **kw):
            return call(self.urls[land], TOKENS[land], '/account', dict({'ckey': ckey, 'op': op}, **kw))

        ask('alpha', 'val', 'claim')
        self.coordinator.homes_once()
        self.assertEqual('alpha', self.coordinator.home('val'))
        self.assertFalse(ask('alpha', 'val', 'start', region='alpha').get('ok'))
        for stage, paused in (('COLONY', False), ('OPEN', True)):
            self.coordinator.set_land('beta', stage, paused, 'val')
            ask('alpha', 'val', 'start', region='beta')
            self.coordinator.homes_once()
            self.assertEqual('alpha', self.coordinator.home('val'), (stage, paused))
        self.coordinator.set_land('beta', 'OPEN', False, 'val')
        # Only the account's home land may send it elsewhere.
        ask('gamma', 'val', 'start', region='beta')
        self.coordinator.homes_once()
        self.assertEqual('alpha', self.coordinator.home('val'))
        ask('alpha', 'val', 'start', region='beta')
        self.coordinator.homes_once()
        self.assertEqual('beta', self.coordinator.home('val'))


def read(path):
    with open(os.path.join(ROOT, path), encoding='utf-8') as f:
        return f.read()


class LandStageSourceTests(unittest.TestCase):
    """The game side: included, polled, shown and set only by admins."""

    def setUp(self):
        self.land = read('code/modules/persistence/land_stage.dm')
        self.group = read('code/modules/persistence/shard_group.dm')

    def test_included_after_trails_and_registered_as_an_admin_verb(self):
        dme = read('civ13.dme')
        self.assertLess(dme.index('region_trails.dm"'), dme.index('land_stage.dm"'))
        self.assertIn('/datum/admins/proc/land_status,', read('code/modules/admin/admin_verbs.dm'))

    def test_the_poll_loop_refreshes_and_the_panel_shows_the_stage(self):
        loop = self.group[self.group.index('/datum/shard_group/proc/start_polling()'):]
        loop = loop[:loop.index('/datum/shard_group/proc/start_saving()')]
        self.assertIn('land_stages_refresh_due()', loop)
        panel = self.group[self.group.index('/datum/shard_group/proc/panel_html()'):]
        panel = panel[:panel.index('/datum/shard_group/proc/panel_admin_html()')]
        self.assertEqual(2, panel.count('land_stage_column('))
        self.assertIn('<th>Settled</th>', panel)

    def test_setting_needs_admin_rights_after_every_prompt(self):
        verb = self.land[self.land.index('/datum/admins/proc/land_status()'):]
        self.assertGreaterEqual(verb.count('check_rights(R_ADMIN)'), 4)
        self.assertIn('transfer_bridge.request("/land/set"', verb)
        self.assertIn('"admin" = M.ckey', verb)

    def test_the_poll_loop_samples_population_and_suggestions_only_inform(self):
        loop = self.group[self.group.index('/datum/shard_group/proc/start_polling()'):]
        self.assertIn('land_sample_post()', loop[:loop.index('/datum/shard_group/proc/start_saving()')])
        tell = self.land[self.land.index('/proc/land_suggestions_tell()'):]
        tell = tell[:tell.index('/proc/land_sample_post()')]
        self.assertIn('message_admins(', tell)
        self.assertNotIn('/land/set', tell)

    def test_only_lived_in_kinds_take_a_stage_and_the_mainland_is_fixed(self):
        self.assertIn('return kind in list("SURFACE", "OCEANIC", "UNDERGROUND", "OTHER", "EXPEDITION")', self.land)
        stage = self.land[self.land.index('/proc/land_stage(id)'):]
        self.assertLess(stage.index('return "MAINLAND"'), stage.index('return entry ? entry["stage"] : "CLOSED"'))
        choices = self.land[self.land.index('/proc/land_stage_choices()'):]
        self.assertIn('if(id == shard_group.mainland)', choices[:choices.index('/proc/land_stage_admin_html()')])

    def test_the_world_keeps_each_lands_colonies_and_colony_suggestions(self):
        refresh = self.land[self.land.index('/proc/land_stages_refresh()'):]
        refresh = refresh[:refresh.index('/proc/land_readiness_clean(')]
        self.assertIn('"colonies" = land_colonies_clean(entry["colonies"])', refresh)
        clean = self.land[self.land.index('/proc/land_readiness_clean('):]
        self.assertIn('list("COLONY", "OPEN", "PAUSE", "RESUME")', clean[:clean.index('/proc/land_colonies_clean(')])
        colonies = self.land[self.land.index('/proc/land_colonies_clean('):]
        self.assertIn('colony_parent_valid(colony["parent"])', colonies[:colonies.index('/proc/land_suggestion_text(')])


if __name__ == '__main__':
    unittest.main()
