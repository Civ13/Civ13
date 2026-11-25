"""Offline tests for scripts/shard-group/daily_maintenance.py (every region onto one build daily)."""
import datetime
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import types
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts/gaia-host'))
SPEC = importlib.util.spec_from_file_location('shard_group', ROOT / 'scripts/shard-group/shard_group.py')
shard_group = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(shard_group)
daily_maintenance = shard_group.daily_maintenance

OLD, NEW = 'a' * 40, 'b' * 40


class FakePlatform:
    def __init__(self, host):
        self.host = host
        self.queries = []

    def listening(self, port):
        return self.host.up

    def query(self, port, token, action, operation=None, session=None, extra=None):
        self.queries.append((action, extra))
        if action == 'planned_notice':
            self.host.counting = True
            return {'notice': 'started'}
        return {}

    def run(self, argv, cwd=None, timeout=None):
        return 0, NEW + '\n'


class FakeHost:
    """A region host: up/asleep/down, its build and staged build, its action record."""
    def __init__(self, name, built=OLD, up=True, asleep=False, clients=0, stage_fails=False, gateway=False,
                 busy_passes=0, refuse=None, coasts=None):
        self.name, self.built, self.staged = name, built, None
        self.coasts = coasts
        self.up, self.asleep, self.clients = up, asleep, clients
        self.stage_fails, self.gateway, self.busy_passes, self.refuse = stage_fails, gateway, busy_passes, refuse
        self.repo = ROOT  # set up: it has a .git
        self.config = {'port': 1720, 'region': name}
        self.platform = FakePlatform(self)
        self.stage_file = 'stage'
        self.stage_requests = 0
        self.handovers = 0
        self.state = {}
        self.counting = False
        self.cancel_countdown = False

    def holds_its_port(self):
        return self.gateway

    def built_revision(self):
        return self.built

    def staged_revision(self):
        return self.staged

    def request_stage(self, urgent=False):
        if self.gateway:
            raise shard_group.Refused(shard_group.GATEWAY_PINNED)
        self.stage_requests += 1
        if not self.stage_fails:
            self.staged = NEW
        return {'accepted': True}

    def stage_running(self):
        return False

    def read_json(self, path):
        return {'phase': 'failed', 'error': 'compile failed: 1 error'} if self.stage_fails else {'phase': 'ready'}

    def frozen(self):
        return self.asleep

    def ocean_update_blockers(self, group, revision):
        return [h.name for h in self.coasts if h.built_revision() != revision]

    def world(self):
        if self.cancel_countdown:
            self.counting = False
        return {'clients': self.clients, 'planned_notice': True, 'shutdown_in': 60 if self.counting else None}

    def token(self):
        return 'f' * 32

    def request(self, action):
        assert action == 'handover'
        if self.refuse:
            raise shard_group.Refused(self.refuse)
        if self.busy_passes:
            self.busy_passes -= 1
            raise shard_group.Refused('another action is still running: stop')
        self.handovers += 1
        self.built = self.staged
        self.state = {'operation': 'op-' + self.name, 'phase': 'done'}
        return {'accepted': True, 'operation': 'op-' + self.name}

    def read_state(self):
        return self.state


class Clock:
    def __init__(self):
        self.now = 1_700_000_000.0

    def __call__(self):
        return self.now

    def sleep(self, seconds):
        self.now += seconds


class DailyMaintenanceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = Path(self.tmp.name)
        (base / 'repo').mkdir()
        self.group_data = {'group': 'earth', 'repository': str(base / 'repo'), 'root': str(base / 'regions'),
                           'compiler': 'DreamMaker', 'daemon': 'DreamDaemon', 'git': 'git', 'public_host': '203.0.113.5',
                           'regions': [{'id': 'gaia', 'name': 'Gaia', 'kind': 'SURFACE', 'port': 1720, 'map': 'maps/a.dmm'}]}
        self.path = base / 'group.json'
        self.clock = Clock()

    def tearDown(self):
        self.tmp.cleanup()

    def load(self, **changes):
        self.path.write_text(json.dumps(dict(self.group_data, **changes)))
        return shard_group.load_group(self.path)

    def this(self, hosts, offline=None):
        offline = offline if offline is not None else {}

        def update_offline(group, only=None, platform=None):
            offline[only] = True
            return {'accepted': {only: {'state': 'asleep'}}, 'skipped': {}}
        return types.SimpleNamespace(
            hosts=lambda group, only=None, platform=None: [
                ({'id': h.name, 'kind': 'GATEWAY' if h.gateway else 'OCEANIC' if h.coasts is not None else 'SURFACE'}, h)
                for h in hosts],
            fetch_remote=lambda group, platform=None: True, update_offline=update_offline,
            Platform=lambda: FakePlatform(hosts[0]), HEX40=shard_group.HEX40,
            fresh_world=types.SimpleNamespace(pending=lambda host: Path('/nonexistent/fresh-world')),
            process_alive=lambda pid: False)

    def maintain(self, group, hosts, **kwargs):
        return daily_maintenance.run(self.this(hosts, **kwargs), group, platform=hosts[0].platform,
                                     sleep=self.clock.sleep, clock=self.clock)

    def test_settings_default_on_only_for_the_live_saving_group_that_follows_a_remote(self):
        self.assertFalse(self.load()['maintenance']['enabled'], 'a test group is never restarted by the clock')
        live = self.load(live=True, fetch='origin', revision='origin/master', regions=[dict(self.group_data['regions'][0], port=1714)])
        self.assertEqual({'enabled': True, 'time': '03:00', 'warning_minutes': 10, 'late_minutes': 90}, live['maintenance'])
        tdm = self.load(live=True, fetch='origin', persistent=False, regions=[dict(self.group_data['regions'][0], port=1714)])
        self.assertFalse(tdm['maintenance']['enabled'], 'TDM updates between rounds')
        for bad in ({'time': '3:00'}, {'time': '24:00'}, {'warning_minutes': 61}, {'enabled': 'yes'}, {'late_minutes': -1}):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                self.load(maintenance=bad)

    def test_due_once_a_day_within_the_late_window(self):
        group = self.load(maintenance={'enabled': True, 'time': '03:00', 'late_minutes': 90})
        day = datetime.datetime(2026, 11, 23)
        at = lambda h, m: day.replace(hour=h, minute=m).timestamp()
        self.assertIsNone(daily_maintenance.due(group, at(2, 59)))
        self.assertEqual('2026-11-23', daily_maintenance.due(group, at(3, 0)))
        self.assertIsNone(daily_maintenance.due(group, at(4, 31)), 'too late: wait for tomorrow')
        self.assertEqual('2026-11-23 03:00', daily_maintenance.next_run(group, at(2, 0)))
        self.assertEqual('2026-11-24 03:00', daily_maintenance.next_run(group, at(5, 0)))
        started = []
        this = types.SimpleNamespace(process_alive=lambda pid: False)
        self.assertEqual('2026-11-23', daily_maintenance.ensure(this, group, lambda *a: started.append(a), at(3, 1)))
        self.assertIn('--scheduled', started[0][0])
        self.assertIsNone(daily_maintenance.ensure(this, group, lambda *a: started.append(a), at(3, 2)), 'started once')
        self.assertEqual(1, len(started))
        self.assertEqual('2026-11-24 03:00', daily_maintenance.next_run(group, at(3, 5)))
        off = self.load(maintenance={'enabled': False})
        self.assertIsNone(daily_maintenance.due(off, at(3, 0)))

    def test_pin_makes_every_reader_build_the_same_commit_and_expires(self):
        group = self.load(revision='origin/master')
        daily_maintenance.write_json(daily_maintenance.folder(group) / 'pin.json', {'revision': NEW, 'started': int(__import__('time').time())})
        pinned = shard_group.load_group(self.path)
        self.assertEqual((NEW, 'origin/master'), (pinned['revision'], pinned['unpinned_revision']))
        daily_maintenance.write_json(daily_maintenance.folder(group) / 'pin.json', {'revision': NEW, 'started': 1})
        self.assertEqual('origin/master', shard_group.load_group(self.path)['revision'], 'a stale pin is ignored')

    def test_every_region_moves_to_one_build_and_the_gateway_stays(self):
        group = self.load()
        gaia = FakeHost('gaia', clients=3)
        europe = FakeHost('europe', busy_passes=2)  # busy for a while: never holds the others back
        asia = FakeHost('asia', up=False, asleep=True)
        current = FakeHost('tutorial', built=NEW)
        gateway = FakeHost('gateway', gateway=True)
        offline = {}
        result = daily_maintenance.run(self.this([gaia, europe, asia, current, gateway], offline), group,
                                       platform=gaia.platform, sleep=self.clock.sleep, clock=self.clock)
        self.assertEqual({'revision': NEW, 'problems': {}}, result)
        self.assertEqual((NEW, NEW), (gaia.built, europe.built))
        self.assertEqual(('planned_notice', {'seconds': '600'}), gaia.platform.queries[0], 'occupied lands are warned')
        self.assertEqual([], europe.platform.queries, 'an empty land gets no countdown')
        self.assertEqual({'asia': True}, offline, 'asleep regions install without waking')
        self.assertEqual((0, 0), (current.stage_requests, gateway.stage_requests))
        self.assertEqual(0, gateway.handovers)
        state = json.loads((daily_maintenance.folder(group) / 'state.json').read_text())
        self.assertEqual('done', state['phase'])
        self.assertIn('gateway stays on its port', state['regions']['gateway']['result'])
        self.assertFalse((daily_maintenance.folder(group) / 'pin.json').exists(), 'the pin is removed afterwards')
        self.assertFalse((daily_maintenance.folder(group) / 'run.json').exists())

    def test_oceans_wait_for_live_and_offline_lands_regardless_of_group_order(self):
        group = self.load()
        mainland = FakeHost('gaia', busy_passes=1)
        island = FakeHost('greenland', up=False, asleep=True)
        live = FakeHost('atlantic', coasts=[mainland, island])
        asleep = FakeHost('arctic', up=False, asleep=True, coasts=[mainland, island])
        fake = self.this([asleep, live, mainland, island])
        events = []

        def install(group, name, platform):
            if name == 'arctic':
                self.assertEqual((NEW, NEW), (mainland.built_revision(), island.built_revision()))
                self.assertTrue((daily_maintenance.folder(group) / 'pin.json').exists())
            events.append(name)
            return {'accepted': {name: {'state': 'asleep'}}}

        def finish_workers(seconds):
            self.clock.sleep(seconds)
            if 'greenland' in events:
                island.built = NEW
            if 'arctic' in events:
                self.assertTrue((daily_maintenance.folder(group) / 'pin.json').exists(),
                                'the pin remains after an offline ocean merely queues')
                asleep.built = NEW

        live_request = live.request

        def request(action):
            self.assertEqual((NEW, NEW), (mainland.built_revision(), island.built_revision()))
            events.append('atlantic')
            return live_request(action)

        fake.update_offline = install
        live.request = request
        asleep.stage_running = lambda: 'arctic' in events and asleep.built_revision() != NEW
        result = daily_maintenance.run(fake, group, platform=mainland.platform,
                                       sleep=finish_workers, clock=self.clock)
        self.assertEqual({}, result['problems'])
        self.assertEqual(NEW, asleep.built_revision())
        self.assertEqual('greenland', events[0])
        self.assertEqual({'atlantic', 'arctic'}, set(events[1:]))

    def test_cancelled_coast_defers_its_ocean_but_not_other_lands(self):
        group = self.load()
        mainland = FakeHost('gaia', clients=1)
        mainland.cancel_countdown = True
        ocean = FakeHost('atlantic', coasts=[mainland])
        unrelated = FakeHost('asia')
        result = self.maintain(group, [ocean, mainland, unrelated])
        self.assertEqual((OLD, OLD, NEW), (mainland.built, ocean.built, unrelated.built))
        self.assertIn('waiting for coastal land builds: gaia', result['problems']['atlantic'])

    def test_a_failed_build_anywhere_changes_no_region(self):
        group = self.load()
        gaia, broken = FakeHost('gaia', clients=2), FakeHost('moon', stage_fails=True)
        with self.assertRaisesRegex(RuntimeError, 'moon did not finish, so no region was updated'):
            self.maintain(group, [gaia, broken])
        self.assertEqual((0, 0), (gaia.handovers, broken.handovers))
        self.assertEqual(OLD, gaia.built)
        self.assertEqual([], gaia.platform.queries, 'nobody is warned for an update that will not happen')
        state = json.loads((daily_maintenance.folder(group) / 'state.json').read_text())
        self.assertEqual('failed', state['phase'])
        self.assertFalse((daily_maintenance.folder(group) / 'pin.json').exists())

    def test_an_admin_calling_off_the_countdown_keeps_that_land_on_its_build(self):
        group = self.load()
        gaia, europe = FakeHost('gaia', clients=2), FakeHost('europe', clients=1)
        europe.cancel_countdown = True
        result = self.maintain(group, [gaia, europe])
        self.assertEqual((1, 0), (gaia.handovers, europe.handovers))
        self.assertIn('called off in game', result['problems']['europe'])

    def test_a_lasting_refusal_is_reported_without_waiting(self):
        group = self.load()
        gaia = FakeHost('gaia', refuse='no staged build newer than the running one')
        result = self.maintain(group, [gaia])
        self.assertIn('not updated', result['problems']['gaia'])

    def test_warned_handover_gets_a_short_reminder_only(self):
        group = self.load()
        folder = daily_maintenance.folder(group)
        daily_maintenance.write_json(folder / 'pin.json', {'revision': NEW, 'started': int(__import__('time').time())})
        daily_maintenance.write_json(folder / 'state.json', {'phase': 'handing over', 'regions': {'gaia': {'warned': True}}})
        self.assertEqual(30, daily_maintenance.handover_warning(group, 'gaia'))
        self.assertIsNone(daily_maintenance.handover_warning(group, 'europe'), 'unwarned lands get the full warning')

    def test_tdm_groups_are_refused(self):
        group = self.load(persistent=False)
        with self.assertRaisesRegex(shard_group.Refused, 'between rounds'):
            daily_maintenance.request(types.SimpleNamespace(process_alive=lambda pid: False), group, lambda *a: 1)

    def test_lifecycle_takes_the_planned_notice(self):
        lifecycle = (ROOT / 'code/modules/persistence/nomads_lifecycle.dm').read_text(encoding='utf-8')
        self.assertIn('if(action == "planned_notice") allowed = list("nomads_lifecycle", "token", "action", "seconds")', lifecycle)
        self.assertIn('planned_shutdown_countdown("update", seconds, "daily maintenance")', lifecycle)
        self.assertIn('"planned_notice" = TRUE)', lifecycle)


if __name__ == '__main__':
    unittest.main()
