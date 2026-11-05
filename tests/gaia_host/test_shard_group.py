"""Offline tests for scripts/shard-group/shard_group.py with a fake machine."""
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts/gaia-host'))
SPEC = importlib.util.spec_from_file_location('shard_group', ROOT / 'scripts/shard-group/shard_group.py')
shard_group = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(shard_group)

REVISION = 'c' * 40
DME = 'line\r\n// BEGIN_SELECTED_MAP\r\n#include "maps\\nomads\\nomads_gaia.dmm"\r\n// END_SELECTED_MAP\r\ntail\r\n'


class FakeMachine:
    def __init__(self):
        self.calls = []
        self.up = set()
        self.detached = []
        self.compile_output = 'region.dmb - 0 errors, 0 warnings'
        self.clock = 0.0
        self.pids = set()

    def alive(self, pid):
        return pid in self.pids

    def run(self, argv, cwd=None, timeout=1800):
        self.calls.append((list(argv), str(cwd)))
        if argv[1] == 'rev-parse':
            return 0, REVISION + '\n'
        if argv[1:3] == ['worktree', 'add']:
            path = Path(argv[4])
            (path / 'maps' / 'small').mkdir(parents=True)
            (path / '.git').write_text('gitdir: elsewhere\n')
            (path / 'civ13.dme').write_text(DME, newline='')
            (path / 'maps' / 'small' / 'tiny.dmm').write_text('"a" = (/turf,/area)\n')
            return 0, ''
        if argv[-1] == 'region.dme':
            if '0 errors' in self.compile_output:
                (Path(cwd) / 'region.dmb').write_bytes(b'dmb')
                return 0, self.compile_output
            return 1, self.compile_output
        return 0, ''

    def listening(self, port):
        return port in self.up

    def query(self, port, token, action='status', operation=None, session=None):
        return {'ok': True, 'ready': True, 'busy': False, 'session': 'b' * 32}

    def start_task(self, name):
        self.calls.append((['start', name], None))
        return 0, 'started'

    def task_ready(self, name):
        return True

    def detach(self, argv):
        self.detached.append(argv)

    def sleep(self, seconds):
        self.clock += seconds

    def now(self):
        return self.clock


class ShardGroupTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        (self.base / 'repo').mkdir()
        self.outside = self.base / 'cave.dmm'
        self.outside.write_text('"a" = (/turf,/area)\n')
        self.group = {'group': 'europe', 'repository': str(self.base / 'repo'), 'root': str(self.base / 'regions'),
                      'compiler': 'DreamMaker', 'daemon': 'DreamDaemon', 'git': 'git', 'public_host': '203.0.113.5',
                      'regions': [{'id': 'gaia', 'name': 'Gaia', 'kind': 'SURFACE', 'port': 1720, 'map': 'maps/small/tiny.dmm'},
                                  {'id': 'deep', 'name': 'The Deep', 'kind': 'UNDERGROUND', 'port': 1721, 'map': str(self.outside)}]}
        self.write_group()
        self.machine = FakeMachine()

    def tearDown(self):
        self.tmp.cleanup()

    def write_group(self):
        self.path = self.base / 'group.json'
        self.path.write_text(json.dumps(self.group))
        return shard_group.load_group(self.path)

    def refuse_config(self, pattern, **changes):
        original = json.loads(json.dumps(self.group))
        for key, value in changes.items():
            if key.startswith('region_'):
                self.group['regions'][1][key[7:]] = value
            else:
                self.group[key] = value
        with self.assertRaisesRegex(ValueError, pattern):
            self.write_group()
        self.group = original

    def test_config_validation(self):
        self.refuse_config('reserved for the live server', region_port=1714)
        self.refuse_config('unique port', region_port=1720)
        self.refuse_config('unique id', region_id='gaia')
        self.refuse_config('kind must be', region_kind='SKY')
        self.refuse_config('needs a map', region_map='cave.sav')
        self.refuse_config('outside the repository', root=str(self.base / 'repo' / 'regions'))
        self.refuse_config('public_host', public_host='http://x')
        self.refuse_config('1 to 16 regions', regions=[])
        self.refuse_config('group id', group='Europe!')
        self.refuse_config('mainland', mainland='atlantis')
        self.refuse_config('mainland cannot be a RAID', mainland='deep', region_kind='RAID')
        group = self.write_group()
        self.assertEqual('gaia', group['mainland'], 'the first region is the mainland by default')
        self.assertEqual(('HEAD', False), (group['revision'], group['public']))

    def test_setup_creates_worktrees_and_region_config_once(self):
        group = self.write_group()
        result = shard_group.setup(group, self.machine)
        self.assertEqual((REVISION, ['gaia', 'deep']), (result['revision'], result['created']))
        deep = self.base / 'regions' / 'deep'
        settings = json.loads((deep / 'config' / 'shard_region.json').read_text())
        self.assertEqual(('europe', 'deep'), (settings['group'], settings['region']))
        self.assertEqual(['203.0.113.5:1720', '203.0.113.5:1721'], [r['address'] for r in settings['regions']])
        self.assertTrue((deep / 'map_saves').is_dir())
        token = (deep / 'config' / 'lifecycle-token.txt').read_text().strip()
        self.assertRegex(token, '^[0-9a-f]{32}$')
        host = json.loads((deep / 'data' / 'shard-host' / 'host.json').read_text())
        self.assertEqual((str(deep), 1721, 'deep'), (host['repository'], host['port'], host['region']))
        again = shard_group.setup(group, self.machine)
        self.assertEqual([], again['created'])
        self.assertEqual(token, (deep / 'config' / 'lifecycle-token.txt').read_text().strip())
        adds = [c for c, _ in self.machine.calls if c[1:3] == ['worktree', 'add']]
        self.assertEqual(2, len(adds))
        self.assertTrue(all(cwd == str(self.base / 'repo') for c, cwd in self.machine.calls if c[1:3] == ['worktree', 'add']))

    def test_setup_refusals(self):
        group = self.write_group()
        self.machine.up = {1721}
        with self.assertRaisesRegex(shard_group.Refused, 'deep is running'):
            shard_group.setup(group, self.machine)
        self.machine.up = set()
        stray = self.base / 'regions' / 'gaia'
        stray.mkdir(parents=True)
        (stray / 'notes.txt').write_text('mine')
        with self.assertRaisesRegex(shard_group.Refused, 'not a region worktree'):
            shard_group.setup(group, self.machine)

    def test_selected_map_dme(self):
        text = shard_group.selected_map_dme(DME, 'maps\\regions\\deep.dmm')
        self.assertIn('// BEGIN_SELECTED_MAP\r\n#include "maps\\regions\\deep.dmm"\r\n// END_SELECTED_MAP\r\ntail', text)
        self.assertNotIn('nomads_gaia', text)
        with self.assertRaises(RuntimeError):
            shard_group.selected_map_dme('no block', 'x.dmm')

    def test_transfer_and_save_options(self):
        group = self.write_group()
        self.assertEqual((False, 15, 60, True), (group['transfers'], group['save_minutes'], group['travel_save_seconds'], group['persistent']))
        self.refuse_config('transfer_port', region_transfer_port=1720)
        self.group['regions'][0]['transfer_port'] = 47201
        self.refuse_config('transfer_port')  # every region needs one once any has one
        self.group['regions'][1]['transfer_port'] = 47201
        self.refuse_config('transfer_port')
        self.group['regions'][1]['transfer_port'] = 47202
        self.refuse_config('save_minutes', save_minutes=-1)
        self.refuse_config('travel_save_seconds', travel_save_seconds=5)
        self.refuse_config('persistent', persistent='yes')
        group = self.write_group()
        self.assertTrue(group['transfers'])
        shard_group.setup(group, self.machine)
        config = self.base / 'regions' / 'deep' / 'config'
        agent = json.loads((config / 'transfer_agent.json').read_text())
        self.assertEqual({'port': 47202, 'token_file': 'config/transfer-token.txt', 'peers': ['gaia'], 'poll_seconds': 5}, agent)
        self.assertGreaterEqual(len((config / 'transfer-token.txt').read_text().strip()), 32)
        settings = json.loads((config / 'shard_region.json').read_text())
        self.assertEqual((15, 60), (settings['save_minutes'], settings['travel_save_seconds']))
        # Regions ask the local doorman which peers sleep instead of polling (and waking) them.
        self.assertEqual('127.0.0.1:1713', settings['doorman'])
        started = []
        def start(argv, cwd, log):
            started.append(argv)
            return 4242
        self.assertTrue(shard_group.ensure_coordinator(group, start))
        self.assertIn('deep=http://127.0.0.1:47202=%s' % (config / 'transfer-token.txt'), started[0])
        self.assertEqual('gaia', started[0][started[0].index('--mainland') + 1])
        self.assertEqual('4242', (self.base / 'regions' / 'coordinator.pid').read_text().strip())
        platform = shard_group.RegionPlatform(shard_group.region_config(group, group['regions'][1]))
        self.assertEqual(['gaia'], platform.config['peers'])
        self.group['persistent'] = False
        shard_group.setup(self.write_group(), self.machine)
        self.assertEqual(0, json.loads((config / 'shard_region.json').read_text())['save_minutes'])

    def host(self, group, region_id):
        region = next(r for r in group['regions'] if r['id'] == region_id)
        return shard_group.RegionHost(shard_group.region_config(group, region), self.machine)

    def test_update_checks_out_and_compiles_each_region_map(self):
        group = self.write_group()
        shard_group.setup(group, self.machine)
        for region_id, include in [('gaia', 'maps\\small\\tiny.dmm'), ('deep', 'maps\\regions\\deep.dmm')]:
            host = self.host(group, region_id)
            operation = host.request('update')['operation']
            self.assertEqual(['--worker', 'update', operation], self.machine.detached[-1][-3:])
            host.work('update', operation)
            state = host.read_state()
            self.assertEqual(('done', REVISION), (state['phase'], state['revision']), state)
            path = self.base / 'regions' / region_id
            self.assertIn('#include "%s"' % include, (path / 'region.dme').read_text())
            self.assertTrue((path / 'region.dmb').exists())
            self.assertIn((['git', 'checkout', '--force', '--detach', REVISION], str(path)), self.machine.calls)
            # Regions are persistent rounds unless the group says otherwise.
            self.assertIn('ALLOWED_GAMEMODES PERSISTENCE', (path / 'config' / 'config.txt').read_text())
        self.assertEqual(self.outside.read_text(), (self.base / 'regions/deep/maps/regions/deep.dmm').read_text())

    def test_persistent_config_saves(self):
        path = self.base / 'config.txt'
        path.write_text('A 1\nALLOWED_GAMEMODES ALL\nSKIP_PERSISTENCE_SAVING\n#SKIP_PERSISTENCE_SAVING\n')
        shard_group.persistent_config(path)
        self.assertEqual(['A 1', 'ALLOWED_GAMEMODES PERSISTENCE', '#SKIP_PERSISTENCE_SAVING', '#SKIP_PERSISTENCE_SAVING'], path.read_text().splitlines())

    def test_resetting_raid_region(self):
        self.refuse_config('only a RAID region can reset', region_reset_minutes=60)
        self.refuse_config('reset_minutes', region_kind='RAID', region_reset_minutes=10)
        self.refuse_config('reset_minutes', region_kind='RAID', region_reset_minutes=True)
        self.group['regions'][1].update(kind='RAID', reset_minutes=180)
        group = self.write_group()
        shard_group.setup(group, self.machine)
        settings = json.loads((self.base / 'regions' / 'deep' / 'config' / 'shard_region.json').read_text())
        self.assertEqual((0, 180), (settings['save_minutes'], settings['reset_minutes']), 'a resetting raid world never saves')
        gaia = json.loads((self.base / 'regions' / 'gaia' / 'config' / 'shard_region.json').read_text())
        self.assertEqual((15, 0), (gaia['save_minutes'], gaia['reset_minutes']))

    def test_persistent_config_without_saving(self):
        path = self.base / 'config.txt'
        path.write_text('ALLOWED_GAMEMODES ALL\nSKIP_PERSISTENCE_SAVING\n')
        shard_group.persistent_config(path, saving=False)
        self.assertEqual(['ALLOWED_GAMEMODES PERSISTENCE', 'SKIP_PERSISTENCE_SAVING'], path.read_text().splitlines())

    def test_update_failures_are_reported(self):
        group = self.write_group()
        shard_group.setup(group, self.machine)
        self.machine.compile_output = 'region.dmb - 2 errors, 0 warnings'
        host = self.host(group, 'gaia')
        host.work('update', host.request('update')['operation'])
        self.assertEqual('failed', host.read_state()['phase'])
        self.assertIn('compile failed', host.read_state()['error'])
        self.machine.up = {1720}
        with self.assertRaisesRegex(shard_group.Refused, 'stop the region'):
            host.request('update')
        self.machine.up = set()
        self.group['regions'][0]['map'] = '../escape.dmm'
        group = self.write_group()
        host = self.host(group, 'gaia')
        self.machine.compile_output = 'region.dmb - 0 errors, 0 warnings'
        host.work('update', host.request('update')['operation'])
        self.assertIn('not a file in the repository', host.read_state()['error'])

    def test_start_needs_a_build(self):
        group = self.write_group()
        shard_group.setup(group, self.machine)
        region = group['regions'][0]
        host = shard_group.RegionHost(shard_group.region_config(group, region), shard_group.RegionPlatform(shard_group.region_config(group, region)))
        with self.assertRaisesRegex(shard_group.Refused, 'no build yet'):
            host.request('start')
        self.assertFalse(host.lock.exists())

    def test_region_platform_command_line(self):
        group = self.write_group()
        config = shard_group.region_config(group, group['regions'][1])
        self.assertEqual(('DreamDaemon', 1721, False), (config['daemon'], config['port'], config['public']))
        self.assertTrue(config['_path'].endswith('host.json'))
        self.assertEqual(str(self.path.resolve()), config['group_config'])

    def test_group_actions_fan_out_and_report_refusals(self):
        group = self.write_group()
        shard_group.setup(group, self.machine)
        hosts = shard_group.hosts(group)
        self.assertEqual(['gaia', 'deep'], [r['id'] for r, _ in hosts])
        with self.assertRaisesRegex(shard_group.Refused, 'no region moon'):
            shard_group.hosts(group, 'moon')
        status = shard_group.group_status(group, 'deep')
        self.assertEqual(['deep'], list(status['regions']))
        self.assertEqual(('UNDERGROUND', False, False), (status['regions']['deep']['kind'], status['regions']['deep']['built'], status['regions']['deep']['listening']))
        self.assertNotIn('region_view', status['regions']['deep'])

    def test_status_checks_the_answering_world_is_the_region(self):
        group = self.write_group()
        shard_group.setup(group, self.machine)
        self.machine.up.add(1721)
        answers = {1721: {'group': group['group'], 'region': 'deep', 'players': 2, 'map': 'Caves', 'peers': {'gaia': 'UP'}}}
        status = shard_group.group_status(group, 'deep', view=answers.get, platform=self.machine)
        self.assertEqual({'players': 2, 'map': 'Caves', 'peers': {'gaia': 'UP'}}, status['regions']['deep']['region_view'])
        answers[1721] = dict(answers[1721], region='gaia')
        status = shard_group.group_status(group, 'deep', view=answers.get, platform=self.machine)
        self.assertIn('error', status['regions']['deep']['region_view'])


    def test_sleep_settings_reach_every_region(self):
        self.refuse_config('freeze_idle_minutes', freeze_idle_minutes='soon')
        self.refuse_config('wake_ignore', wake_ignore=[1])
        self.refuse_config('freeze_requires_save', freeze_requires_save=1)
        self.refuse_config('doorman_port', doorman_port=1713.0)
        self.refuse_config('doorman_port', doorman_port=70000)
        self.group.update(freeze_idle_minutes=5, cold_start_estimate_seconds=90)
        group = self.write_group()
        config = shard_group.region_config(group, group['regions'][1])
        self.assertEqual((5, 90, False), (config['freeze_idle_minutes'], config['cold_start_estimate_seconds'],
                                          config['start_requires_byond_pager']))
        self.assertNotIn('wake_min_free_mb', config, 'unset keys keep the host defaults')
        self.group['public'] = True
        group = self.write_group()
        self.assertTrue(shard_group.region_config(group, group['regions'][1])['start_requires_byond_pager'],
                        'a hub-listed region needs the BYOND pager like Gaia')

    def test_status_reports_asleep_and_cold_without_asking_a_frozen_world(self):
        group = self.write_group()
        shard_group.setup(group, self.machine)
        state = self.base / 'regions' / 'deep' / 'data' / 'shard-host'
        (state / 'freeze.json').write_text(json.dumps({'pid': 77, 'frozen_at': 0}))
        self.machine.up.add(1721)
        self.machine.pids.add(77)
        asked = []
        status = shard_group.group_status(group, 'deep', view=lambda port: asked.append(port), platform=self.machine)
        self.assertEqual(('asleep', []), (status['regions']['deep']['state'], asked))
        self.assertNotIn('region_view', status['regions']['deep'])
        # The machine went down: the frozen process is gone and nothing listens.
        self.machine.up.clear()
        self.machine.pids.clear()
        with mock.patch('builtins.print'):
            status = shard_group.group_status(group, 'deep', view=lambda port: asked.append(port), platform=self.machine)
        self.assertEqual('cold', status['regions']['deep']['state'])
        self.assertTrue((state / 'cold.json').exists())
        (state / 'cold.json').unlink()
        status = shard_group.group_status(group, 'deep', platform=self.machine)
        self.assertEqual('stopped', status['regions']['deep']['state'])

    def test_a_cold_region_starts_through_its_own_worker(self):
        group = self.write_group()
        shard_group.setup(group, self.machine)
        path = self.base / 'regions' / 'deep'
        (path / 'region.dmb').write_bytes(b'dmb')
        (path / 'data' / 'shard-host' / 'cold.json').write_text(json.dumps({'frozen_at': 0}))
        host = self.host(group, 'deep')
        self.assertEqual('cold', host.status()['state'])
        accepted = host.start_cold('doorman wake request')
        self.assertTrue(accepted['cold_start'])
        argv = self.machine.detached[-1]
        self.assertTrue(argv[3].endswith('shard_group.py'), argv)
        self.assertEqual([str(path / 'data' / 'shard-host' / 'host.json'), '--worker', 'start'], argv[-4:-1])
        host.work('start', accepted['operation'])
        self.assertIn((['start', 'region:deep'], None), self.machine.calls)

    def test_supervise_restarts_missing_agents_and_the_coordinator(self):
        self.group['regions'][0]['transfer_port'] = 47201
        self.group['regions'][1]['transfer_port'] = 47202
        group = self.write_group()
        shard_group.setup(group, self.machine)
        listening, started, alive = set(), [], set()
        def start(argv, cwd, log):
            started.append(argv)
            return 4242
        with mock.patch.object(shard_group.RegionPlatform, 'listening', lambda self, port: port in listening), \
                mock.patch.object(shard_group, 'detach', start), \
                mock.patch.object(shard_group, 'process_alive', lambda pid: pid in alive):
            self.assertEqual({'agents': ['gaia', 'deep'], 'coordinator': True}, shard_group.supervise(group, start))
            self.assertEqual(3, len(started))
            listening.update({47201, 47202})
            alive.add(4242)
            self.assertEqual({}, shard_group.supervise(group, start))
            listening.discard(47202)
            self.assertEqual({'agents': ['deep']}, shard_group.supervise(group, start))
            # One region failing to start its agent does not keep the others or the coordinator down.
            listening.clear()
            alive.clear()
            real = shard_group.RegionPlatform.start_agent
            def flaky(platform):
                if platform.config['region'] == 'gaia':
                    raise OSError('state_dir is not writable')
                return real(platform)
            with mock.patch.object(shard_group.RegionPlatform, 'start_agent', flaky):
                result = shard_group.supervise(group, start)
            self.assertEqual((['deep'], True), (result['agents'], result['coordinator']))
            self.assertIn('not writable', result['errors']['gaia'])
        self.group['regions'][0].pop('transfer_port')
        self.group['regions'][1].pop('transfer_port')
        self.assertEqual({}, shard_group.supervise(self.write_group()))

    def test_the_host_service_serves_every_region_of_a_group(self):
        group = self.write_group()
        shard_group.setup(group, self.machine)
        gaia_host = shard_group.gaia_host
        hosts, supervisors = gaia_host.group_hosts([str(self.path)])
        self.assertEqual([1720, 1721], [host.config['port'] for host in hosts])
        self.assertEqual(['region:gaia', 'region:deep'], [host.config['task'] for host in hosts])
        self.assertEqual(1, len(supervisors))
        self.assertEqual({}, supervisors[0](), 'a group without travel has no helpers')
        for argv in (['--group', str(self.path), 'status'], ['serve']):
            with self.assertRaises(SystemExit), mock.patch('sys.stderr'):
                gaia_host.main(argv)


    def test_the_live_group_may_use_the_live_port_and_list_one_region(self):
        self.refuse_config('reserved for the live server', region_port=1714)
        self.refuse_config('live must be', live='yes')
        self.refuse_config('public must be', region_public='yes')
        self.group['live'] = True
        self.group['regions'][0]['port'] = 1714
        self.group['regions'][0]['public'] = True
        group = self.write_group()
        gaia = shard_group.region_config(group, group['regions'][0])
        deep = shard_group.region_config(group, group['regions'][1])
        self.assertEqual((1714, True, True), (gaia['port'], gaia['public'], gaia['start_requires_byond_pager']))
        self.assertEqual((False, False), (deep['public'], deep['start_requires_byond_pager']))

    def test_overlays_are_copied_after_every_checkout(self):
        shared, own = self.base / 'overlay-all', self.base / 'overlay-gaia'
        (shared / 'config').mkdir(parents=True)
        (own / 'config').mkdir(parents=True)
        (shared / 'config' / 'host.txt').write_text('Everyone')
        (own / 'config' / 'host.txt').write_text('Valzargaming')
        (own / 'config' / 'config.txt').write_text('ALLOWED_GAMEMODES ALL\nWEBHOOK_CAN_FIRE\nSKIP_PERSISTENCE_SAVING\n')
        (own / 'native.dll').write_bytes(b'dll')
        self.group['overlay'] = str(shared)
        self.group['regions'][0]['overlay'] = str(own)
        group = self.write_group()
        shard_group.setup(group, self.machine)
        host = self.host(group, 'gaia')
        host.work('update', host.request('update')['operation'])
        self.assertEqual('done', host.read_state()['phase'], host.read_state())
        path = self.base / 'regions' / 'gaia'
        self.assertEqual('Valzargaming', (path / 'config' / 'host.txt').read_text(), 'the region overlay wins')
        self.assertEqual(b'dll', (path / 'native.dll').read_bytes())
        self.assertEqual(['ALLOWED_GAMEMODES PERSISTENCE', 'WEBHOOK_CAN_FIRE', '#SKIP_PERSISTENCE_SAVING'],
                         (path / 'config' / 'config.txt').read_text().splitlines())
        deep = self.host(group, 'deep')
        deep.work('update', deep.request('update')['operation'])
        self.assertEqual('Everyone', (self.base / 'regions' / 'deep' / 'config' / 'host.txt').read_text())
        (own / 'config' / 'lifecycle-token.txt').write_text('a' * 32)
        host.work('update', host.request('update')['operation'])
        self.assertIn('must not contain config/lifecycle-token.txt', host.read_state()['error'])
        self.refuse_config('overlay must be', overlay=5)

    def test_fetch_runs_once_before_setup_and_update(self):
        self.refuse_config('fetch must be', fetch='origin; rm')
        group = self.write_group()
        self.assertFalse(shard_group.fetch_remote(group, self.machine))
        self.group['fetch'] = 'origin'
        group = self.write_group()
        self.assertTrue(shard_group.fetch_remote(group, self.machine))
        self.assertIn((['git', 'fetch', 'origin'], str(self.base / 'repo')), self.machine.calls)

    def make_standalone(self):
        source = self.base / 'gaia-standalone'
        saves = source / 'map_saves'
        saves.mkdir(parents=True)
        (saves / 'map.txt').write_text('nomads_gaia\n')
        (saves / '1.sav').write_bytes(b'level')
        marker = 'round-v2:' + 'a' * 32
        (saves / 'save_complete.txt').write_text(marker)
        state = {'generation': marker, 'version': 2, 'maxz': 1,
                 'metadata': shard_group.gaia_host.byond_text_md5(saves / 'map.txt')}
        (saves / 'round.json').write_text(json.dumps(state))
        (source / 'SQL').mkdir()
        (source / 'SQL' / 'bans.txt').write_text('griefer')
        (source / 'data' / 'faction_symbols').mkdir(parents=True)
        (source / 'data' / 'faction_symbols' / 'wolves.png').write_bytes(b'png')
        (source / 'data' / 'scratch.log').write_text('not runtime state')
        return source, marker

    def test_adopt_moves_a_stopped_standalone_save_into_a_region(self):
        group = self.write_group()
        source, marker = self.make_standalone()
        with self.assertRaisesRegex(shard_group.Refused, 'not set up'):
            shard_group.adopt(group, 'gaia', source, self.machine)
        shard_group.setup(group, self.machine)
        with self.assertRaisesRegex(shard_group.Refused, 'no region moon'):
            shard_group.adopt(group, 'moon', source, self.machine)
        self.machine.up = {1720}
        with self.assertRaisesRegex(shard_group.Refused, 'stop it first'):
            shard_group.adopt(group, 'gaia', source, self.machine)
        self.machine.up = set()
        (source / 'map_saves' / '1.sav.lk').write_text('')
        with self.assertRaisesRegex(shard_group.Refused, 'locked'):
            shard_group.adopt(group, 'gaia', source, self.machine)
        (source / 'map_saves' / '1.sav.lk').unlink()
        result = shard_group.adopt(group, 'gaia', source, self.machine)
        path = self.base / 'regions' / 'gaia'
        self.assertEqual((marker, ['SQL', 'data/faction_symbols']), (result['generation'], result['copied']))
        self.assertEqual(b'level', (path / 'map_saves' / '1.sav').read_bytes())
        self.assertFalse((path / 'map_saves' / 'backup-receipt.json').exists())
        self.assertEqual('griefer', (path / 'SQL' / 'bans.txt').read_text())
        self.assertFalse((path / 'data' / 'scratch.log').exists())
        self.assertTrue((source / 'map_saves' / '1.sav').exists(), 'the source stays as a rollback')
        with self.assertRaisesRegex(shard_group.Refused, 'already has a save'):
            shard_group.adopt(group, 'gaia', source, self.machine)

    def test_gaia_host_drives_a_region_host_json(self):
        group = self.write_group()
        shard_group.setup(group, self.machine)
        config = shard_group.gaia_host.load_config(self.base / 'regions' / 'deep' / 'data' / 'shard-host' / 'host.json')
        host = shard_group.gaia_host.region_host(config)
        self.assertEqual('RegionHost', type(host).__name__)
        self.assertTrue(str(host.script).endswith('shard_group.py'))


    def test_check_update_reports_each_region_against_the_group_revision(self):
        self.group['fetch'] = 'origin'
        group = self.write_group()
        shard_group.setup(group, self.machine)
        old = 'e' * 40
        real = self.machine.run
        def run(argv, cwd=None, timeout=1800):
            if argv[1:] == ['rev-parse', 'HEAD'] and str(cwd).endswith('deep'):
                self.machine.calls.append((list(argv), str(cwd)))
                return 0, old + '\n'
            if argv[1:3] == ['rev-list', '--count']:
                self.machine.calls.append((list(argv), str(cwd)))
                return 0, ('2\n' if argv[3].startswith(old) else '0\n')
            return real(argv, cwd, timeout)
        self.machine.run = run
        answer = shard_group.group_check_update(group, platform=self.machine)
        self.assertEqual((2, True, None), (answer['behind'], answer['can_update'], answer['reason']))
        self.assertEqual(('up to date', 2), (answer['regions']['gaia']['reason'], answer['regions']['deep']['behind']))
        self.assertEqual(1, sum(1 for call, _ in self.machine.calls if call[1:2] == ['fetch']), 'one fetch for the group')
        self.machine.up = {1721}
        answer = shard_group.group_check_update(group, platform=self.machine)
        self.assertEqual((False, 'stop the server before updating'), (answer['can_update'], answer['reason']))


if __name__ == '__main__':
    unittest.main()
