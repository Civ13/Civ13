"""Offline tests for scripts/shard-group/shard_group.py with a fake machine."""
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest

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


if __name__ == '__main__':
    unittest.main()
