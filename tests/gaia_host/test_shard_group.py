"""Offline tests for scripts/shard-group/shard_group.py with a fake machine."""
import importlib.util
import io
import json
import os
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
        self.revision = REVISION  # what the group revision resolves to
        self.low_priority = []  # cwd of every compile run at low priority
        self.restore = {}  # worktree -> config.txt a checkout of config/config.txt restores

    def alive(self, pid):
        return pid in self.pids

    def run(self, argv, cwd=None, timeout=1800, low_priority=False):
        self.calls.append((list(argv), str(cwd)))
        if low_priority:
            self.low_priority.append(str(cwd))
        if argv[1] == 'rev-parse':
            return 0, self.revision + '\n'
        if argv[1:] == ['checkout', '--force', 'HEAD', '--', 'config/config.txt'] and str(cwd) in self.restore:
            (Path(cwd) / 'config' / 'config.txt').write_text(self.restore[str(cwd)])
            return 0, ''
        if argv[1:3] == ['worktree', 'add']:
            path = Path(argv[4])
            (path / 'maps' / 'small').mkdir(parents=True)
            (path / '.git').write_text('gitdir: elsewhere\n')
            (path / 'civ13.dme').write_text(DME, newline='')
            (path / 'maps' / 'small' / 'tiny.dmm').write_text('"a" = (/turf,/area)\n')
            return 0, ''
        if argv[-1] == 'region.dme':
            if '0 errors' in self.compile_output:
                (Path(cwd) / 'region.dmb').write_bytes(b'dmb of ' + str(cwd).encode())
                (Path(cwd) / 'region.rsc').write_bytes(b'rsc of ' + str(cwd).encode())
                return 0, self.compile_output
            return 1, self.compile_output
        return 0, ''

    def listening(self, port):
        return port in self.up

    def query(self, port, token, action='status', operation=None, session=None):
        return {'ok': True, 'ready': True, 'busy': False, 'session': 'b' * 32}

    def start_task(self, name, dmb='region.dmb'):
        self.calls.append((['start', name, dmb], None))
        return 0, 'started'

    def start_standby(self, dmb, port):
        self.calls.append((['standby', dmb, port], None))
        self.standby_started = (dmb, port)
        return 4242

    def task_ready(self, name):
        return True

    def detach(self, argv):
        self.detached.append(argv)

    def sleep(self, seconds):
        self.clock += seconds

    def now(self):
        return self.clock

    free_mb = None
    pids_by_port = {}

    def free_memory_mb(self):
        return self.free_mb

    def server_pid(self, port):
        return self.pids_by_port.get(port) if port in self.up else None

    def kill_tree(self, pid):
        self.calls.append((['kill_tree', pid], None))
        for port, owner in list(self.pids_by_port.items()):
            if owner == pid:
                self.up.discard(port)


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
        self.assertEqual(('europe', 'deep', 'gaia'), (settings['group'], settings['region'], settings['mainland']))
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

    def test_relay_is_off_by_default_and_validated(self):
        group = self.write_group()
        self.assertEqual(0, group['relay_port'])
        shard_group.setup(group, self.machine)
        settings = json.loads((self.base / 'regions' / 'deep' / 'config' / 'shard_region.json').read_text())
        self.assertNotIn('relay', settings)
        self.assertFalse((self.base / 'regions' / 'deep' / 'config' / 'relay-token.txt').exists())
        self.refuse_config('relay_port must be', relay_port=1721)
        self.refuse_config('relay_port must be', relay_port='1730')
        self.refuse_config('relay_control_port', relay_port=1730, relay_control_port=1720)
        self.refuse_config('gate must be', relay_port=1730, gate='atlantis')
        self.refuse_config('gate must be', relay_port=1730, gate='deep', region_kind='RAID')

    def test_tdm_pair_validation(self):
        self.refuse_config('BATTLE region needs a BARRACKS', region_kind='BATTLE')
        self.group['regions'][0]['kind'] = 'BARRACKS'
        self.refuse_config('mainland cannot be a BATTLE', mainland='deep', region_kind='BATTLE')
        self.refuse_config('at most one BARRACKS', region_kind='BARRACKS')
        self.group['regions'][1]['kind'] = 'BATTLE'
        group = self.write_group()
        self.assertEqual('gaia', group['mainland'])

    def test_setup_writes_the_tdm_token_and_battle_build_settings(self):
        self.group['regions'][0]['kind'] = 'BARRACKS'
        self.group['regions'][1]['kind'] = 'BATTLE'
        group = self.write_group()
        shard_group.setup(group, self.machine)
        tokens = set()
        for region in ('gaia', 'deep'):
            tokens.add((self.base / 'regions' / region / 'config' / 'tdm-token.txt').read_text().strip())
        self.assertEqual({(self.base / 'regions' / 'tdm-token.txt').read_text().strip()}, tokens)
        self.assertRegex(tokens.pop(), '^[0-9a-f]{48}$')
        build = json.loads((self.base / 'regions' / 'deep' / 'config' / 'shard_build.json').read_text())
        self.assertEqual(('deep', 'git', 'DreamMaker'), (build['region'], build['git'], build['compiler']))
        self.assertEqual(str((self.base / 'regions').resolve()), build['root'])
        self.assertFalse((self.base / 'regions' / 'gaia' / 'config' / 'shard_build.json').exists())

    def test_a_battle_rebuild_keeps_the_voted_map(self):
        # A start after master moved (or a watchdog restart) rebuilds the battle region;
        # it must build the map the last vote picked, not the configured one.
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            path = root / 'battle'
            (path / 'maps' / 'small').mkdir(parents=True)
            (path / 'maps' / '1943').mkdir(parents=True)
            (path / 'maps' / 'small' / 'tiny.dmm').write_text('"a" = (/turf,/area)\n')
            (path / 'maps' / '1943' / 'hotel.dmm').write_text('"a" = (/turf,/area)\n')
            group = {'root': str(root)}
            region = {'id': 'battle', 'kind': 'BATTLE', 'map': 'maps/small/tiny.dmm'}
            self.assertEqual('maps\\small\\tiny.dmm', shard_group.place_map(group, region, path))
            state = path / 'data' / 'shard-host'
            state.mkdir(parents=True)
            for kind in ('ready', 'building'):
                (state / 'rotation.json').write_text(json.dumps({'state': kind, 'map': 'HOTEL'}))
                self.assertEqual('maps\\1943\\hotel.dmm', shard_group.place_map(group, region, path), kind)
            for record in ({'state': 'failed', 'map': 'HOTEL'}, {'state': 'ready', 'map': 'NOWHERE'},
                           {'state': 'ready', 'map': '../x'}, 'not json'):
                (state / 'rotation.json').write_text(record if isinstance(record, str) else json.dumps(record))
                self.assertEqual('maps\\small\\tiny.dmm', shard_group.place_map(group, region, path), record)
            (state / 'rotation.json').write_text(json.dumps({'state': 'ready', 'map': 'HOTEL'}))
            surface = dict(region, kind='SURFACE')
            self.assertEqual('maps\\small\\tiny.dmm', shard_group.place_map(group, surface, path))

    def test_compile_succeeded_tolerates_a_crash_after_a_clean_save(self):
        with tempfile.TemporaryDirectory() as folder:
            dmb = Path(folder) / 'region.dmb'
            crash = 'region.dmb - 0 errors, 0 warnings\ndouble free or corruption (out)'
            self.assertFalse(shard_group.compile_succeeded(0, 'region.dmb - 0 errors', dmb, None))  # no file
            dmb.write_bytes(b'new')
            self.assertTrue(shard_group.compile_succeeded(0, 'region.dmb - 0 errors, 0 warnings', dmb, None))
            self.assertTrue(shard_group.compile_succeeded(134, crash, dmb, None))
            self.assertFalse(shard_group.compile_succeeded(134, crash, dmb, shard_group.dmb_mtime(dmb)))  # stale file
            self.assertFalse(shard_group.compile_succeeded(1, 'region.dmb - 3 errors, 0 warnings', dmb, None))
            self.assertFalse(shard_group.compile_succeeded(0, 'region.dmb - 3 errors', dmb, None))

    def test_ordinary_regions_get_no_tdm_files(self):
        shard_group.setup(self.write_group(), self.machine)
        self.assertFalse((self.base / 'regions' / 'gaia' / 'config' / 'tdm-token.txt').exists())
        self.assertFalse((self.base / 'regions' / 'deep' / 'config' / 'shard_build.json').exists())

    def test_setup_writes_relay_settings_and_one_shared_token(self):
        self.group['relay_port'] = 1730
        group = self.write_group()
        self.assertEqual((1731, 'gaia'), (group['relay_control_port'], group['gate']))
        shard_group.setup(group, self.machine)
        tokens = set()
        for region in ('gaia', 'deep'):
            config = self.base / 'regions' / region / 'config'
            settings = json.loads((config / 'shard_region.json').read_text())
            self.assertEqual(('203.0.113.5:1730', '127.0.0.1:1731', 'gaia'),
                             (settings['relay'], settings['relay_control'], settings['gate']))
            # Region addresses stay the internal game ports: peers are polled and woken by them.
            self.assertEqual(['203.0.113.5:1720', '203.0.113.5:1721'], [r['address'] for r in settings['regions']])
            tokens.add((config / 'relay-token.txt').read_text().strip())
        self.assertEqual({(self.base / 'regions' / 'relay-token.txt').read_text().strip()}, tokens)
        # Only the gate is offered by the launcher; the others are joined through it.
        self.assertEqual({'gaia': False, 'deep': True},
                         {r['id']: shard_group.region_config(group, r)['routed'] for r in group['regions']})
        # A routed region stays off the hub even when it asks to be public: its port is closed.
        listed = dict(group, regions=[dict(r, public=True) for r in group['regions']])
        self.assertEqual({'gaia': (True, True), 'deep': (False, False)},
                         {r['id']: (shard_group.region_config(listed, r)['public'],
                                    shard_group.region_config(listed, r)['start_requires_byond_pager'])
                          for r in listed['regions']})
        self.assertRegex(tokens.pop(), '^[0-9a-f]{48}$')

    def test_supervise_starts_the_relay_once(self):
        self.group['relay_port'] = 1730
        self.group['relay_capture'] = True
        group = self.write_group()
        shard_group.setup(group, self.machine)
        started, alive = [], set()
        def start(argv, cwd, log):
            started.append(argv)
            return 5151
        with mock.patch.object(shard_group, 'process_alive', lambda pid: pid in alive):
            self.assertEqual({'relay': True}, shard_group.supervise(group, start))
            alive.add(5151)
            self.assertEqual({}, shard_group.supervise(group, start))
        argv = started[0]
        self.assertTrue(argv[1].endswith('relay.py'))
        self.assertEqual(['--region-port', '1720', '--region-port', '1721', '--capture'], argv[-5:])
        self.assertEqual('1731', argv[argv.index('--control-port') + 1])
        self.assertEqual('1713', argv[argv.index('--doorman-port') + 1])

    def test_setup_of_one_region_tells_the_running_relay_its_port(self):
        self.group['relay_port'] = 1730
        group = self.write_group()
        shard_group.setup(group, self.machine)
        token = (self.base / 'regions' / 'relay-token.txt').read_text().strip()
        sent = []
        def send(port, query):
            sent.append((port, query))
            return json.dumps({'ok': True})
        self.assertEqual([1720, 1721], shard_group.relay_add_ports(group, send))
        self.assertEqual([(1731, 'add_port=1&port=%d&token=%s' % (p, token)) for p in (1720, 1721)], sent)
        def down(port, query):
            raise OSError('refused')
        self.assertIsNone(shard_group.relay_add_ports(group, down))
        # setup --region reports what the relay took (none here: no relay listens).
        with mock.patch.object(shard_group, 'relay_add_ports', lambda group: [1720, 1721]):
            self.assertEqual([1720, 1721], shard_group.setup(group, self.machine, 'deep')['relay_ports'])

    def test_a_relay_that_cannot_start_does_not_stop_supervision(self):
        self.group['relay_port'] = 1730
        group = self.write_group()
        shard_group.setup(group, self.machine)
        def start(argv, cwd, log):
            raise OSError('no python')
        with mock.patch.object(shard_group, 'process_alive', lambda pid: False):
            self.assertEqual({'relay_error': 'no python'}, shard_group.supervise(group, start))

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

    def test_setup_one_region_while_the_others_run(self):
        group = self.write_group()
        shard_group.setup(group, self.machine)
        self.group['regions'].append(dict(self.group['regions'][1], id='moon', port=1722, name='Moon'))
        group = self.write_group()
        self.machine.up = {1720, 1721}
        with self.assertRaisesRegex(shard_group.Refused, 'gaia is running'):
            shard_group.setup(group, self.machine)
        with self.assertRaisesRegex(shard_group.Refused, 'no region atlantis'):
            shard_group.setup(group, self.machine, 'atlantis')
        result = shard_group.setup(group, self.machine, 'moon')
        self.assertEqual((['moon'], 'moon', ['gaia', 'deep']), (result['created'], result['region'], result['running']))
        self.assertTrue((self.base / 'regions' / 'moon' / 'config' / 'shard_region.json').exists())
        # The running regions' config lists the new peer for their next start.
        settings = json.loads((self.base / 'regions' / 'gaia' / 'config' / 'shard_region.json').read_text())
        self.assertIn('moon', [r['id'] for r in settings['regions']])
        self.machine.up = {1722}
        with self.assertRaisesRegex(shard_group.Refused, 'moon is running'):
            shard_group.setup(group, self.machine, 'moon')
        adds = [c for c, _ in self.machine.calls if c[1:3] == ['worktree', 'add']]
        self.assertEqual(3, len(adds))

    def test_setup_one_region_enrols_it_with_running_agents(self):
        sys.path.insert(0, str(ROOT))
        from tools.transfer_storage.coordinator import Coordinator
        from tools.transfer_storage.region import RegionStore
        self.group['regions'][0]['transfer_port'] = 47201
        self.group['regions'][1]['transfer_port'] = 47202
        group = self.write_group()
        shard_group.setup(group, self.machine)
        # Gaia's agent and the coordinator have run, so their stores exist; Deep's has not.
        gaia_store = Path(shard_group.region_config(group, group['regions'][0])['state_dir']) / 'transfers.sqlite'
        RegionStore(str(gaia_store), 'gaia', 'europe').close()
        Coordinator(str(self.base / 'regions' / 'coordinator.sqlite'), 'europe', 'gaia').close()
        self.group['regions'].append(dict(self.group['regions'][1], id='moon', port=1722, transfer_port=47203, name='Moon'))
        group = self.write_group()
        self.machine.up = {1720, 1721}
        result = shard_group.setup(group, self.machine, 'moon')
        self.assertEqual(['gaia', 'coordinator'], result['enrolled'])
        store = RegionStore(str(gaia_store), 'gaia', 'europe')
        try:
            fences = {(d, p) for d, p, _, _ in store.db.execute('SELECT direction, peer, epoch, settled_seq FROM fence')}
        finally:
            store.close()
        self.assertTrue({('out', 'moon'), ('in', 'moon')} <= fences)
        coordinator = Coordinator(str(self.base / 'regions' / 'coordinator.sqlite'), 'europe', 'gaia')
        try:
            url, token = coordinator.regions()['moon']
        finally:
            coordinator.close()
        self.assertEqual('http://127.0.0.1:47203', url)
        self.assertEqual((self.base / 'regions' / 'moon' / 'config' / 'transfer-token.txt').read_text().strip(), token)
        # enrol repeats the same step for a region added before setup did it, and is idempotent.
        self.assertEqual({'region': 'moon', 'enrolled': ['gaia', 'coordinator']}, shard_group.enrol(group, 'moon'))
        with self.assertRaisesRegex(shard_group.Refused, 'no region atlantis'):
            shard_group.enrol(group, 'atlantis')
        # host.json is replaced whole, never left half-written beside a temporary file.
        state = Path(shard_group.region_config(group, group['regions'][2])['state_dir'])
        self.assertTrue((state / 'host.json').exists())
        self.assertFalse((state / 'host.json.tmp').exists())

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

    def opens_port_on_start(self, port):
        start = self.machine.start_task
        def start_task(name, dmb='region.dmb'):
            self.machine.up.add(port)
            return start(name, dmb)
        self.machine.start_task = start_task

    def test_start_builds_a_region_that_has_none(self):
        group = self.write_group()
        region = group['regions'][0]
        config = shard_group.region_config(group, region)
        host = shard_group.RegionHost(config, self.machine)
        with self.assertRaisesRegex(shard_group.Refused, 'not set up'):
            host.request('start')
        self.assertFalse(host.lock.exists())
        shard_group.setup(group, self.machine)
        host = shard_group.RegionHost(shard_group.region_config(group, region), self.machine)
        self.opens_port_on_start(config['port'])
        host.work('start', host.request('start')['operation'])
        self.assertEqual(host.read_state()['phase'], 'done', host.read_state())
        commands = [call[0] for call in self.machine.calls]
        self.assertLess(commands.index(['DreamMaker', 'region.dme']), commands.index(['start', config['task'], 'region.dmb']))
        self.assertEqual(json.loads((Path(config['state_dir']) / 'build.json').read_text())['revision'], REVISION)

    def test_start_skips_the_compile_when_the_build_is_current(self):
        group = self.write_group()
        shard_group.setup(group, self.machine)
        region = group['regions'][0]
        host = shard_group.RegionHost(shard_group.region_config(group, region), self.machine)
        host.work('update', host.request('update')['operation'])
        compiles = sum(1 for call in self.machine.calls if call[0][-1] == 'region.dme')
        self.opens_port_on_start(region['port'])
        host.work('start', host.request('start')['operation'])
        self.assertEqual(host.read_state()['phase'], 'done', host.read_state())
        self.assertEqual(compiles, sum(1 for call in self.machine.calls if call[0][-1] == 'region.dme'))

    def test_process_alive_runs_no_console_program(self):
        # Called every 30 s by the host service; a tasklist child flashed a window.
        from unittest import mock
        with mock.patch.object(shard_group.subprocess, 'run', side_effect=AssertionError('no subprocess')), \
                mock.patch.object(shard_group.subprocess, 'Popen', side_effect=AssertionError('no subprocess')):
            self.assertTrue(shard_group.process_alive(os.getpid()))
            self.assertFalse(shard_group.process_alive(2 ** 22 + 12345))

    def test_windows_access_denied_counts_as_alive(self):
        # A live coordinator we may not query must not look stopped, or a
        # second one would start; a missing process still reads as stopped.
        import types
        gh = shard_group.gaia_host
        for error, expected in ((5, True), (87, False)):
            kernel32 = types.SimpleNamespace(OpenProcess=mock.Mock(return_value=None))
            with mock.patch.object(gh, 'os', types.SimpleNamespace(name='nt')), \
                    mock.patch.object(gh.ctypes, 'WinDLL', return_value=kernel32, create=True), \
                    mock.patch.object(gh.ctypes, 'get_last_error', return_value=error, create=True):
                self.assertIs(shard_group.Platform().alive(4242), expected)

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

    def test_kill_and_force_restart_reach_every_region(self):
        group = self.write_group()
        calls = []

        class Region:
            def __init__(self, name, running):
                self.name, self.running = name, running

            def kill(self):
                calls.append(('kill', self.name))
                if not self.running:
                    raise shard_group.Refused('the server is not running')
                return {'killed': True, 'pid': 1}

            def force_restart(self):
                calls.append(('force-restart', self.name))
                return {'accepted': True, 'action': 'start', 'operation': 'x', 'killed': self.running}

        regions = [({'id': 'gaia'}, Region('gaia', True)), ({'id': 'deep'}, Region('deep', False))]
        out = io.StringIO()
        with mock.patch.object(shard_group, 'hosts', return_value=regions), mock.patch('sys.stdout', out):
            self.assertEqual(0, shard_group.main(['--config', str(self.path), 'kill']))
        answer = json.loads(out.getvalue())
        self.assertEqual({'gaia': {'killed': True, 'pid': 1}}, answer['done'])
        self.assertEqual({'deep': 'the server is not running'}, answer['refused'])
        out = io.StringIO()
        with mock.patch.object(shard_group, 'hosts', return_value=regions), mock.patch.object(shard_group, 'ensure_coordinator', return_value=False), \
                mock.patch('sys.stdout', out):
            self.assertEqual(0, shard_group.main(['--config', str(self.path), 'force-restart']))
        self.assertEqual(['gaia', 'deep'], sorted(json.loads(out.getvalue())['accepted'], reverse=True))
        self.assertEqual([('kill', 'gaia'), ('kill', 'deep'), ('force-restart', 'gaia'), ('force-restart', 'deep')], calls)

    def test_unlock_and_force_unlock_reach_every_region(self):
        self.write_group()
        calls = []

        class Region:
            def __init__(self, name, running):
                self.name, self.running = name, running

            def unlock(self, force=False):
                calls.append((self.name, force))
                if self.running and not force:
                    raise shard_group.Refused('the server is running')
                return {'removed': ['1.sav.lk'], 'forced': force}

        regions = [({'id': 'gaia'}, Region('gaia', True)), ({'id': 'deep'}, Region('deep', False))]
        for action, force in (('unlock', False), ('force-unlock', True)):
            out = io.StringIO()
            with mock.patch.object(shard_group, 'hosts', return_value=regions), mock.patch('sys.stdout', out):
                self.assertEqual(0, shard_group.main(['--config', str(self.path), action]))
            answer = json.loads(out.getvalue())
            self.assertIn('deep', answer['done'])
            self.assertEqual(force, 'gaia' in answer['done'])
        self.assertEqual([('gaia', False), ('deep', False), ('gaia', True), ('deep', True)], calls)

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


    def test_epoch_names_match_the_game(self):
        source = (ROOT / 'code/modules/persistence/functions.dm').read_text(encoding='utf-8')
        line = next(text for text in source.splitlines() if text.startswith('var/global/list/epoch_names = list('))
        self.assertEqual(shard_group.EPOCH_NAMES, tuple(name.strip().strip('"') for name in line.split('list(', 1)[1].rstrip(')').split(',')))
        self.assertEqual((9, 8, 0), (shard_group.parse_epoch('2026'), shard_group.parse_epoch('8'), shard_group.parse_epoch('5000 B.C.')))
        for bad in ('10', '-1', '2027', ''):
            with self.assertRaises(shard_group.Refused):
                shard_group.parse_epoch(bad)

    def test_epoch_advances_the_mainland_first_then_every_awake_region(self):
        group = self.write_group()
        shard_group.setup(group, self.machine)
        asked = []

        def query(port, token, action='status', operation=None, session=None, extra=None):
            asked.append((port, action, extra))
            return {'ok': True, 'epoch': 'set' if port == 1720 else 'current'}
        self.machine.query = query
        # Every region follows the mainland, so nothing changes while it is down.
        self.machine.up.add(1721)
        with self.assertRaises(shard_group.Refused):
            shard_group.group_epoch(group, '2026', self.machine)
        self.assertEqual([], asked)
        self.machine.up.add(1720)
        result = shard_group.group_epoch(group, '2026', self.machine)
        self.assertEqual([(1720, 'set_epoch', {'epoch': '9'}), (1721, 'set_epoch', {'epoch': '9'})], asked)
        self.assertEqual({'epoch': 9, 'name': '2026', 'mainland': 'gaia', 'regions': {'gaia': 'set', 'deep': 'current'}}, result)
        # A stopped region is not started; it follows the mainland when it next runs.
        asked.clear()
        self.machine.up.discard(1721)
        self.assertIn('follows the mainland', shard_group.group_epoch(group, '1969', self.machine)['regions']['deep'])
        self.assertEqual([1720], [port for port, _, _ in asked])
        # A mainland that refuses (busy saving, an older build) changes nothing anywhere.
        self.machine.up.add(1721)
        asked.clear()
        self.machine.query = lambda port, token, action='status', operation=None, session=None, extra=None: asked.append(port) or {'ok': True, 'epoch': 'refused:busy'}
        with self.assertRaises(shard_group.Refused):
            shard_group.group_epoch(group, '2026', self.machine)
        self.assertEqual([1720], asked)

    def test_status_shows_each_running_region_epoch(self):
        group = self.write_group()
        shard_group.setup(group, self.machine)
        self.machine.up.add(1721)
        answers = {1721: {'group': group['group'], 'region': 'deep', 'players': 0, 'map': 'Caves', 'ordinal_age': 8}}
        status = shard_group.group_status(group, 'deep', view=answers.get, platform=self.machine)
        self.assertEqual({'ordinal': 8, 'name': '2013'}, status['regions']['deep']['region_view']['epoch'])

    def test_status_shows_the_tdm_battle_phase(self):
        group = self.write_group()
        shard_group.setup(group, self.machine)
        self.machine.up.add(1721)
        answers = {1721: {'group': group['group'], 'region': 'deep', 'players': 3, 'map': 'Berlin', 'battle_phase': 'playing'}}
        status = shard_group.group_status(group, 'deep', view=answers.get, platform=self.machine)
        self.assertEqual('playing', status['regions']['deep']['region_view']['battle_phase'])
        answers[1721]['battle_phase'] = 7
        status = shard_group.group_status(group, 'deep', view=answers.get, platform=self.machine)
        self.assertNotIn('battle_phase', status['regions']['deep']['region_view'])

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

    def test_region_summary_lists_every_region_without_waking_a_sleeper(self):
        group = self.write_group()
        shard_group.setup(group, self.machine)
        state = self.base / 'regions' / 'deep' / 'data' / 'shard-host'
        (state / 'freeze.json').write_text(json.dumps({'pid': 77, 'frozen_at': 0}))
        self.machine.up.add(1721)
        self.machine.pids.add(77)
        summary = shard_group.region_summary(group, platform=self.machine)
        self.assertEqual([r['id'] for r in group['regions']], [entry['id'] for entry in summary])
        deep = next(entry for entry in summary if entry['id'] == 'deep')
        self.assertEqual(('asleep', None, 1721), (deep['state'], deep['players'], deep['port']))
        self.assertEqual('stopped', summary[0]['state'])

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
        self.assertIn((['start', 'region:deep', 'region.dmb'], None), self.machine.calls)

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
            def flaky(platform, refresh=False):
                if platform.config['region'] == 'gaia':
                    raise OSError('state_dir is not writable')
                return real(platform, refresh)
            with mock.patch.object(shard_group.RegionPlatform, 'start_agent', flaky):
                result = shard_group.supervise(group, start)
            self.assertEqual((['deep'], True), (result['agents'], result['coordinator']))
            self.assertIn('not writable', result['errors']['gaia'])
        self.group['regions'][0].pop('transfer_port')
        self.group['regions'][1].pop('transfer_port')
        self.assertEqual({}, shard_group.supervise(self.write_group()))

    def test_supervise_restarts_helpers_running_old_code_but_not_mid_action(self):
        # Rail Yard, 2026-11-08: agents and a coordinator from before group OOC kept
        # running after every update, and four agents shared port 1725.
        self.group['regions'][0]['transfer_port'] = 47201
        self.group['regions'][1]['transfer_port'] = 47202
        group = self.write_group()
        shard_group.setup(group, self.machine)
        listening, started, alive, ended = set(), [], set(), []
        listeners = {47201: [], 47202: []}
        pids = iter(range(5000, 6000))
        def start(argv, cwd, log):
            started.append(argv)
            pid = next(pids)
            alive.add(pid)
            if '--port' in argv:  # an agent listens on its port once started
                port = int(argv[argv.index('--port') + 1])
                listeners[port].append(pid)
                listening.add(port)
            return pid
        def terminate(platform, pid):
            ended.append(pid)
            alive.discard(pid)
            for port, owners in listeners.items():
                if pid in owners:
                    owners.remove(pid)
                    if not owners:
                        listening.discard(port)
        code = ['one']
        with mock.patch.object(shard_group.RegionPlatform, 'listening', lambda self, port: port in listening), \
                mock.patch.object(shard_group.RegionPlatform, 'listener_pids', lambda self, port: list(listeners[port])), \
                mock.patch.object(shard_group.RegionPlatform, 'terminate', terminate), \
                mock.patch.object(shard_group.Platform, 'terminate', terminate), \
                mock.patch.object(shard_group, 'transfer_code', lambda: code[0]), \
                mock.patch.object(shard_group, 'detach', start), \
                mock.patch.object(shard_group, 'process_alive', lambda pid: pid in alive):
            self.assertEqual({'agents': ['gaia', 'deep'], 'coordinator': True}, shard_group.supervise(group, start))
            deep_agent = listeners[47202][0]
            self.assertEqual({}, shard_group.supervise(group, start), 'same code: nothing restarts')
            # A stale duplicate on deep's port is ended with the agent, which starts again.
            listeners[47202].append(4321)
            self.assertEqual({'agents': ['deep']}, shard_group.supervise(group, start))
            self.assertEqual([deep_agent, 4321], ended)
            # New code on disk: nothing restarts while a region runs an action...
            code[0] = 'two'
            lock = Path(shard_group.region_config(group, group['regions'][0])['state_dir']) / 'action.lock'
            lock.parent.mkdir(parents=True, exist_ok=True)
            lock.write_text('busy')
            self.assertEqual({}, shard_group.supervise(group, start))
            # ...and every helper restarts once it is idle.
            lock.unlink()
            self.assertEqual({'agents': ['gaia', 'deep'], 'coordinator': True}, shard_group.supervise(group, start))
            self.assertEqual({}, shard_group.supervise(group, start))
        # A real fingerprint covers the helpers' source.
        self.assertEqual(16, len(shard_group.transfer_code()))

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

    def test_config_local_merges_over_the_repository_config(self):
        base = ('ALLOWED_GAMEMODES ALL\n'
                '## comment about WEBHOOK_KEY\n'
                '#WEBHOOK_CAN_FIRE\n'
                '#WEBHOOK_KEY\n'
                'DAYNIGHT_SWEEP 1\n'
                'NEW_MASTER_SETTING 7\n')
        local = ('# the webhook\n'
                 'WEBHOOK_CAN_FIRE\n'
                 'webhook_key secret\n'
                 '#DAYNIGHT_SWEEP\n'
                 'EXTRA_ONE 1\n'
                 'EXTRA_ONE 2\n')
        merged = shard_group.merge_config(base, local).splitlines()
        self.assertEqual(['ALLOWED_GAMEMODES ALL', '## comment about WEBHOOK_KEY', 'WEBHOOK_CAN_FIRE', 'webhook_key secret',
                          '#DAYNIGHT_SWEEP 1', 'NEW_MASTER_SETTING 7', '', '## Host settings (config.local.txt)', 'EXTRA_ONE 2'],
                         merged, 'named settings change; everything else keeps master')
        self.assertEqual(shard_group.merge_config(base, local), shard_group.merge_config(shard_group.merge_config(base, local), local))
        self.assertEqual('A 1\n#B\n', shard_group.merge_config('A 1\nB\nB 2\n', '#b\n').replace('#B 2\n', ''))
        with self.assertRaisesRegex(ValueError, 'not a config setting'):
            shard_group.merge_config(base, '=nope\n')

    def test_group_and_region_config_local_layer_and_apply_without_compile(self):
        shared, own = self.base / 'overlay-all', self.base / 'overlay-gaia'
        (shared / 'config').mkdir(parents=True)
        (own / 'config').mkdir(parents=True)
        (shared / 'config' / 'config.local.txt').write_text('DAYNIGHT_CLIENT_TINT\nWEBHOOK_ADDRESS http://shared\n')
        (own / 'config' / 'config.local.txt').write_text('WEBHOOK_ADDRESS http://gaia\n')
        (own / 'native.dll').write_bytes(b'dll')
        for kept in ('config.txt.migrated', 'config.local.txt.previous', 'config.txt.bak-20261106-stream'):
            (own / 'config' / kept).write_text('old')
        self.group['overlay'] = str(shared)
        self.group['regions'][0]['overlay'] = str(own)
        self.group['persistent'] = True
        group = self.write_group()
        shard_group.setup(group, self.machine)
        repository_config = 'ALLOWED_GAMEMODES ALL\nSKIP_PERSISTENCE_SAVING\n#WEBHOOK_ADDRESS\n'
        gaia, deep = self.base / 'regions' / 'gaia', self.base / 'regions' / 'deep'
        for path in (gaia, deep):
            (path / 'config').mkdir(exist_ok=True)
            (path / 'config' / 'config.txt').write_text(repository_config)
        self.machine.restore = {str(gaia): repository_config, str(deep): repository_config}
        host = self.host(group, 'gaia')
        host.work('update', host.request('update')['operation'])
        self.assertEqual('done', host.read_state()['phase'], host.read_state())
        self.assertEqual(['ALLOWED_GAMEMODES PERSISTENCE', '#SKIP_PERSISTENCE_SAVING', 'WEBHOOK_ADDRESS http://gaia', '',
                          '## Host settings (config.local.txt)', 'DAYNIGHT_CLIENT_TINT'],
                         (gaia / 'config' / 'config.txt').read_text().splitlines(), 'the region overrides the group')
        self.assertFalse((gaia / 'config' / 'config.local.txt').exists(), 'only the merged config.txt is written')
        self.assertEqual([], [p.name for p in (gaia / 'config').iterdir() if p.name not in ('config.txt', 'shard_region.json')
                              and not p.name.endswith('token.txt') and not p.name.startswith(('lifecycle', 'transfer', 'relay'))],
                         'kept copies stay in the overlay')
        compiles = sum(1 for argv, _ in self.machine.calls if argv[-1] == 'region.dme')
        # An edit made in the launcher reaches every region with config-apply, without a checkout or compile.
        (shared / 'config' / 'config.local.txt').write_text('WEBHOOK_ADDRESS http://edited\n')
        self.machine.up.add(1720)
        dll = gaia / 'native.dll'
        before = dll.stat().st_mtime_ns
        with mock.patch.object(shard_group, 'Platform', return_value=self.machine), \
                mock.patch('sys.stdout', new_callable=io.StringIO) as out:
            self.assertEqual(0, shard_group.main(['--config', str(self.path), 'config-apply']))
        answer = json.loads(out.getvalue())
        self.assertEqual((True, True, False), (answer['ok'], answer['done']['gaia']['running'], answer['done']['deep']['running']))
        self.assertNotIn('native.dll', answer['done']['gaia']['copied'], 'an unchanged DLL a world loaded is not rewritten')
        self.assertEqual(before, dll.stat().st_mtime_ns)
        self.assertIn('WEBHOOK_ADDRESS http://gaia', (gaia / 'config' / 'config.txt').read_text())
        self.assertIn('WEBHOOK_ADDRESS http://edited', (deep / 'config' / 'config.txt').read_text())
        self.assertNotIn('DAYNIGHT_CLIENT_TINT', (deep / 'config' / 'config.txt').read_text(), 'removed lines go back to master')
        self.assertEqual(compiles, sum(1 for argv, _ in self.machine.calls if argv[-1] == 'region.dme'))
        (own / 'config' / 'config.local.txt').write_bytes(b'\xef\xbb\xbfWEBHOOK_ADDRESS http://bom\n')
        done, refused = shard_group.apply_config(group, 'gaia', self.machine)
        self.assertIn('WEBHOOK_ADDRESS http://bom', (gaia / 'config' / 'config.txt').read_text(), 'a BOM from Notepad is not a setting')
        (own / 'config' / 'config.local.txt').write_text('=bad\n')
        done, refused = shard_group.apply_config(group, 'gaia', self.machine)
        self.assertEqual({}, done)
        self.assertIn('not a config setting', refused['gaia'])

    def test_config_migrate_turns_a_whole_overlay_config_into_overrides(self):
        import subprocess
        repo = self.base / 'repo'
        (repo / 'config').mkdir()
        base = 'ALLOWED_GAMEMODES ALL\nSKIP_PERSISTENCE_SAVING\n#WEBHOOK_KEY\n#NEW_OPTION\nTIPS 1\n'
        (repo / 'config' / 'config.txt').write_text(base)
        for argv in (['init', '-q'], ['add', '.'], ['-c', 'user.name=t', '-c', 'user.email=t@t', 'commit', '-qm', 'base']):
            subprocess.run(['git'] + argv, cwd=repo, check=True)
        revision = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=repo, capture_output=True, text=True).stdout.strip()
        own, done = self.base / 'overlay-gaia', self.base / 'overlay-done'
        (own / 'config').mkdir(parents=True)
        (done / 'config').mkdir(parents=True)
        whole = '# old copy\nALLOWED_GAMEMODES PERSISTENCE\n#SKIP_PERSISTENCE_SAVING\nWEBHOOK_KEY secret\nTIPS 1\nDAYNIGHT_CLIENT_TINT\n'
        (own / 'config' / 'config.txt').write_text(whole)
        (done / 'config' / 'config.txt').write_text(whole)
        (done / 'config' / 'config.local.txt').write_text('TIPS 0\n')
        odd = self.base / 'overlay-odd'
        (odd / 'config').mkdir(parents=True)
        (odd / 'config' / 'config.txt').write_text('BAD-KEY 1\n')
        self.group['overlay'] = str(odd)
        self.group['regions'][0]['overlay'] = str(own)
        self.group['regions'][1]['overlay'] = str(done)
        group = self.write_group()
        self.machine.revision = revision
        result = shard_group.migrate_config(group, self.machine)
        self.assertEqual(['ALLOWED_GAMEMODES PERSISTENCE', 'WEBHOOK_KEY secret', 'DAYNIGHT_CLIENT_TINT', '#SKIP_PERSISTENCE_SAVING'],
                         result['done'][str(own)])
        self.assertIn('already exists', result['refused'][str(done)])
        self.assertIn('would not reproduce', result['refused'][str(odd)], 'an odd line refuses that overlay only')
        self.assertFalse((own / 'config' / 'config.txt').exists())
        self.assertEqual(whole, (own / 'config' / 'config.txt.migrated').read_text())
        merged = shard_group.merge_config(base, (own / 'config' / 'config.local.txt').read_text())
        self.assertEqual(shard_group.active_settings(whole), shard_group.active_settings(merged))
        self.assertIn('#NEW_OPTION', merged, 'settings the host never named keep the repository line')

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
        (source / 'SQL' / 'player-help' / 'worker.lock').mkdir(parents=True)
        (source / 'SQL' / 'player-help' / 'worker.lock' / 'pid').write_text('7528')
        (source / 'SQL' / 'player-help' / 'health.json').write_text('{"enabled": true}')
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
        self.assertFalse((path / 'SQL' / 'player-help').exists(), 'the help bridge spool belongs to the source worker')
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


    def test_linux_regions_can_run_in_their_own_systemd_scope(self):
        self.refuse_config('systemd_scope', systemd_scope='yes')
        group = self.write_group()
        argv = ['DreamDaemon', 'region.dmb', '1715']
        config = shard_group.region_config(group, group['regions'][1])
        self.assertEqual('', config['systemd_scope'])
        self.assertEqual(argv, shard_group.scoped(argv, config))
        config['systemd_scope'] = 'user'
        with mock.patch.object(shard_group.os, 'name', 'posix'):
            wrapped = shard_group.scoped(argv, config)
        unit = 'civ13-%s-%s' % (group['group'], group['regions'][1]['id'])
        self.assertEqual(['systemd-run', '--user', '--scope', '--quiet', '--collect', '--unit', unit, '--'] + argv, wrapped)
        with mock.patch.object(shard_group.os, 'name', 'nt'):
            self.assertEqual(argv, shard_group.scoped(argv, config))  # Windows has no scopes


class PlayerHelpTests(unittest.TestCase):
    """The host service keeps one Player Help bridge per region; the launcher stops and starts them."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        (self.base / 'repo').mkdir()
        self.group = {'group': 'europe', 'repository': str(self.base / 'repo'), 'root': str(self.base / 'regions'),
                      'compiler': 'DreamMaker', 'daemon': 'DreamDaemon', 'git': 'git', 'public_host': '203.0.113.5',
                      'python': 'python.exe', 'player_help': {'config': str(self.base / 'help.json')},
                      'regions': [{'id': 'gaia', 'name': 'Gaia', 'kind': 'SURFACE', 'port': 1720, 'map': 'maps/a.dmm'},
                                  {'id': 'deep', 'name': 'The Deep', 'kind': 'UNDERGROUND', 'port': 1721, 'map': 'maps/b.dmm'}]}
        for region in ('gaia', 'deep'):
            scripts = self.base / 'regions' / region / 'scripts'
            scripts.mkdir(parents=True)
            (scripts / 'player_help_bridge.py').write_text('# bridge\n')
        self.alive = set()
        patcher = mock.patch.object(shard_group, 'process_alive', lambda pid: pid in self.alive)
        patcher.start()
        self.addCleanup(patcher.stop)

    def tearDown(self):
        self.tmp.cleanup()

    def load(self):
        path = self.base / 'group.json'
        path.write_text(json.dumps(self.group))
        return shard_group.load_group(path)

    def lock(self, region, pid):
        lock = self.base / 'regions' / region / 'SQL' / 'player-help' / 'worker.lock'
        lock.mkdir(parents=True, exist_ok=True)
        (lock / 'pid').write_text(str(pid))
        return lock

    def test_config_validation(self):
        self.assertEqual(['gaia', 'deep'], self.load()['player_help']['regions'])
        for bad in ({'regions': ['gaia']}, {'config': ''}, {'config': 'x', 'regions': ['moon']},
                    {'config': 'x', 'regions': ['gaia', 'gaia']}, {'config': 'x', 'regions': []}, 'help.json'):
            self.group['player_help'] = bad
            with self.assertRaisesRegex(ValueError, 'player_help'):
                self.load()

    def test_supervise_starts_missing_bridges_with_the_stop_file(self):
        group = self.load()
        started = []
        def start(argv, cwd, log):
            started.append((argv, Path(cwd), Path(log)))
            return 7000 + len(started)
        stale = self.lock('gaia', 99)  # a bridge that died: its lock would refuse a new one
        self.assertEqual({'player_help': ['gaia', 'deep']}, shard_group.supervise(group, start))
        self.assertFalse(stale.exists())
        argv, cwd, log = started[0]
        self.assertEqual(['python.exe', '-I', str(cwd / 'scripts' / 'player_help_bridge.py'), '--game-root', str(cwd),
                          '--config', str(self.base / 'help.json'), '--stop-file', str(self.base / 'regions' / 'player-help' / 'gaia.off')], argv)
        self.assertEqual(self.base / 'regions' / 'player-help' / 'gaia.log', log)
        # Starting (pid file, before the lock) and running (lock) bridges are both left alone.
        self.alive.update({7001, 7002})
        self.lock('gaia', 7001)
        self.assertEqual({}, shard_group.supervise(group, start))
        self.assertEqual(2, len(started))
        # A bridge that exits is started again.
        self.alive.discard(7002)
        self.assertEqual({'player_help': ['deep']}, shard_group.supervise(group, start))

    def test_a_region_without_the_bridge_does_not_keep_the_others_down(self):
        (self.base / 'regions' / 'gaia' / 'scripts' / 'player_help_bridge.py').unlink()
        started = shard_group.supervise(self.load(), lambda argv, cwd, log: 1)
        self.assertEqual(['deep'], started['player_help'])
        self.assertIn('missing', started['player_help_errors']['gaia'])

    def test_stop_keeps_them_stopped_until_start(self):
        group = self.load()
        self.alive.update({11, 12})
        self.lock('gaia', 11)
        self.lock('deep', 12)
        clock = [0.0]
        def sleep(seconds):
            clock[0] += seconds
            self.alive.discard(11)  # gaia sees the stop file; deep (an older bridge without it) does not
        killed = []
        def kill(pid):
            killed.append(pid)
            self.alive.discard(pid)
        result = shard_group.help_stop(group, timeout=5, sleep=sleep, clock=lambda: clock[0], kill=kill)
        self.assertEqual({'stopped': ['deep', 'gaia'], 'forced': ['deep']}, result)
        self.assertEqual([12], killed)
        self.assertFalse((self.base / 'regions' / 'deep' / 'SQL' / 'player-help' / 'worker.lock').exists())
        status = shard_group.help_status(group)
        self.assertTrue(status['stopped'])
        self.assertFalse(status['regions']['gaia']['running'])
        started = []
        self.assertEqual({}, shard_group.supervise(group, lambda argv, cwd, log: started.append(argv) or 1))
        self.assertEqual([], started)
        self.assertEqual({'started': ['gaia', 'deep'], 'errors': {}}, shard_group.help_start(group, lambda argv, cwd, log: 5))
        self.assertFalse(shard_group.help_status(group)['stopped'])

    def test_status_reports_the_heartbeat(self):
        group = self.load()
        self.alive.add(21)
        lock = self.lock('gaia', 21)
        (lock.parent / 'health.json').write_text(json.dumps({'enabled': True, 'sequence': 'a' * 32}))
        mtime = (lock.parent / 'health.json').stat().st_mtime
        status = shard_group.help_status(group, now=lambda: mtime + 4)
        self.assertEqual({'running': True, 'pid': 21, 'wanted': True, 'listed': True, 'enabled': True, 'heartbeat_age_seconds': 4,
                          'log': str(self.base / 'regions' / 'player-help' / 'gaia.log')}, status['regions']['gaia'])
        self.assertEqual({'running': False, 'pid': None, 'wanted': True, 'listed': True, 'enabled': False,
                          'log': str(self.base / 'regions' / 'player-help' / 'deep.log')}, status['regions']['deep'])

    def test_every_region_is_listed_and_starts_or_stops_on_its_own(self):
        # Only gaia is listed for help, as on the live earth group (gaia and railyard of four).
        self.group['player_help']['regions'] = ['gaia']
        group = self.load()
        status = shard_group.help_status(group)
        self.assertEqual(['gaia', 'deep'], list(status['regions']), 'every region of the group is shown')
        self.assertEqual((True, False), (status['regions']['gaia']['wanted'], status['regions']['deep']['wanted']))
        started = []
        def start(argv, cwd, log):
            started.append(Path(cwd).name)
            return 100 + len(started)
        self.assertEqual({'player_help': ['gaia']}, shard_group.supervise(group, start))
        self.alive.add(101)
        self.lock('gaia', 101)
        # Starting an unlisted region keeps it running from then on.
        self.assertEqual({'started': ['deep'], 'errors': {}}, shard_group.help_start(group, start, region_id='deep'))
        self.assertTrue(shard_group.help_status(group)['regions']['deep']['wanted'])
        self.alive.add(102)
        self.lock('deep', 102)
        # Stopping one region leaves the other running and is not undone by the host service.
        def kill(pid):
            self.alive.discard(pid)
        result = shard_group.help_stop(group, timeout=0, sleep=lambda s: None, clock=lambda: 0.0, kill=kill, region_id='gaia')
        self.assertEqual({'stopped': ['gaia'], 'forced': ['gaia']}, result)
        self.assertTrue((self.base / 'regions' / 'player-help' / 'gaia.off').exists())
        self.assertIn(102, self.alive)
        self.assertEqual({}, shard_group.supervise(group, start))
        status = shard_group.help_status(group)
        self.assertEqual((False, True, False), (status['regions']['gaia']['wanted'], status['regions']['deep']['wanted'], status['stopped']))
        # A stop of the whole group, then one region started: the others stay stopped.
        shard_group.help_stop(group, timeout=0, sleep=lambda s: None, clock=lambda: 0.0, kill=kill)
        self.assertTrue(shard_group.help_status(group)['stopped'])
        self.assertEqual(['deep'], shard_group.help_start(group, start, region_id='deep')['started'])
        self.assertEqual((False, True), tuple(shard_group.help_status(group)['regions'][r]['wanted'] for r in ('gaia', 'deep')))
        with self.assertRaises(shard_group.Refused):
            shard_group.help_start(group, start, region_id='moon')

    def test_actions_without_player_help(self):
        del self.group['player_help']
        group = self.load()
        self.assertEqual({'configured': False}, shard_group.help_status(group))
        self.assertEqual({}, shard_group.supervise(group, lambda argv, cwd, log: 1))
        path = self.base / 'group.json'
        out = io.StringIO()
        with mock.patch('sys.stdout', out):
            self.assertEqual(1, shard_group.main(['--config', str(path), 'help-stop']))
        self.assertEqual({'ok': False, 'refused': 'player_help is not configured for this group'}, json.loads(out.getvalue()))


if __name__ == '__main__':
    unittest.main()


NEWER = 'e' * 40


class StagedBuildTests(unittest.TestCase):
    """stage compiles the next build beside a running region; the region installs it by
    copying once it is empty or asleep, instead of compiling during its downtime."""

    setUp = ShardGroupTests.setUp
    tearDown = ShardGroupTests.tearDown
    write_group = ShardGroupTests.write_group
    host = ShardGroupTests.host

    def built(self):
        group = self.write_group()
        shard_group.setup(group, self.machine)
        host = self.host(group, 'gaia')
        host.log = lambda values: None
        host.work('update', host.request('update')['operation'])
        self.machine.revision = NEWER
        return group, host

    def compiles(self, cwd):
        return sum(1 for argv, where in self.machine.calls if argv[-1] == 'region.dme' and where == str(cwd))

    def test_stage_compiles_beside_the_running_region_and_update_installs_it(self):
        group, host = self.built()
        live, staging = self.base / 'regions' / 'gaia', self.base / 'regions' / '.staging' / 'gaia'
        self.machine.up = {1720}
        accepted = host.request_stage()
        self.assertEqual(['--worker', 'stage', accepted['operation']], self.machine.detached[-1][-3:])
        self.assertTrue(self.machine.detached[-1][3].endswith('shard_group.py'))
        with self.assertRaisesRegex(shard_group.Refused, 'already being staged'):
            host.request_stage()
        host.work('stage', accepted['operation'])
        self.assertEqual(host.read_json(host.stage_file)['phase'], 'ready', host.read_json(host.stage_file))
        self.assertFalse(host.stage_lock.exists())
        self.assertIn((['git', 'worktree', 'add', '--detach', str(staging), NEWER], str(self.base / 'repo')), self.machine.calls)
        self.assertEqual(self.machine.low_priority, [str(staging)])
        self.assertIn('#include "maps\\small\\tiny.dmm"', (staging / 'region.dme').read_text())
        self.assertEqual((1, 1), (self.compiles(live), self.compiles(staging)), 'the running region is not touched')
        self.assertEqual(host.staged_revision(), NEWER)
        self.assertTrue(host.update_pending())
        self.assertTrue(host.status()['stage']['pending'])
        # The install is a copy, not a second compile.
        self.machine.up = set()
        host.work('update', host.request('update')['operation'])
        state = host.read_state()
        self.assertEqual((state['phase'], state['revision'], state.get('staged')), ('done', NEWER, True), state)
        self.assertEqual(self.compiles(live), 1)
        self.assertEqual((live / 'region.dmb').read_bytes(), (staging / 'region.dmb').read_bytes())
        self.assertEqual((live / 'region.rsc').read_bytes(), (staging / 'region.rsc').read_bytes())
        self.assertEqual(host.built_revision(), NEWER)
        self.assertFalse(host.update_pending())

    def test_stage_does_nothing_for_a_current_build(self):
        group, host = self.built()
        self.machine.revision = REVISION
        host.work('stage', host.request_stage()['operation'])
        self.assertEqual(host.read_json(host.stage_file)['phase'], 'current')
        self.assertFalse((self.base / 'regions' / '.staging' / 'gaia').exists())

    def test_a_failed_staged_compile_leaves_nothing_to_install(self):
        group, host = self.built()
        self.machine.compile_output = 'region.dmb - 1 errors, 0 warnings'
        host.work('stage', host.request_stage()['operation'])
        stage = host.read_json(host.stage_file)
        self.assertEqual(stage['phase'], 'failed')
        self.assertIn('compile failed', stage['error'])
        self.assertFalse(host.update_pending())

    def test_an_older_staged_build_is_never_installed(self):
        group, host = self.built()
        host.work('stage', host.request_stage()['operation'])
        real = self.machine.run
        def run(argv, cwd=None, timeout=1800, low_priority=False):
            if argv[1] == 'merge-base':
                return 1, ''  # the running build is newer (updated by hand)
            return real(argv, cwd, timeout, low_priority)
        self.machine.run = run
        (self.base / 'regions' / 'gaia' / 'region.dmb').write_bytes(b'hand compile')
        host.record_build('f' * 40)
        self.assertFalse(host.update_pending())

    def test_regions_take_turns_at_the_staging_compiler(self):
        group, host = self.built()
        lock = self.base / 'regions' / '.staging' / 'compile.lock'
        lock.parent.mkdir(parents=True)
        lock.write_text('77')
        self.machine.pids = {77}
        real_sleep = self.machine.sleep
        def sleep(seconds):
            real_sleep(seconds)
            self.machine.pids = set()  # the other region's compile finished
        self.machine.sleep = sleep
        host.work('stage', host.request_stage()['operation'])
        self.assertEqual(host.read_json(host.stage_file)['phase'], 'ready')
        self.assertEqual(self.machine.clock, 10)
        self.assertFalse(lock.exists())

    def test_a_cold_region_gets_the_staged_build_before_its_next_wake(self):
        group, host = self.built()
        host.work('stage', host.request_stage()['operation'])
        host.write_json(host.cold_file, {'frozen_at': 0})
        host.watch_step(None)
        self.assertEqual(self.machine.detached[-1][-2], 'update')
        host.work('update', self.machine.detached[-1][-1])
        self.assertEqual(host.built_revision(), NEWER)
        self.assertEqual(host.status()['state'], 'cold', 'it still starts on the next wake')

    def test_an_empty_region_restarts_onto_the_staged_build_instead_of_sleeping(self):
        group, host = self.built()
        host.work('stage', host.request_stage()['operation'])
        self.machine.up = {1720}
        idle, _ = host.watch_step(None)
        self.machine.clock += 15 * 60
        host.watch_step(idle)
        self.assertEqual(self.machine.detached[-1][-2], 'restart')
        self.assertFalse(host.frozen())

    def test_stage_reaches_every_region_from_the_command_line(self):
        group = self.write_group()
        shard_group.setup(group, self.machine)
        with mock.patch.object(shard_group, 'Platform', return_value=self.machine), \
                mock.patch.object(shard_group, 'RegionPlatform', return_value=self.machine), \
                mock.patch('sys.stdout', new_callable=io.StringIO) as out:
            code = shard_group.main(['--config', str(self.path), 'stage'])
        result = json.loads(out.getvalue())
        self.assertEqual((code, sorted(result['accepted'])), (0, ['deep', 'gaia']), result)


class HandoverTests(unittest.TestCase):
    """handover: the staged build boots beside the running region, loads its save and takes over."""
    setUp = ShardGroupTests.setUp
    tearDown = ShardGroupTests.tearDown
    write_group = ShardGroupTests.write_group
    host = ShardGroupTests.host
    built = StagedBuildTests.built
    LIVE, STANDBY = 1720, 1730
    SESSION, STANDBY_SESSION = 'b' * 32, 'c' * 32
    MARKER = 'round-v2:' + 'd' * 32

    def write_save(self, saves, intent=None):
        import hashlib
        saves.mkdir(parents=True, exist_ok=True)
        (saves / 'map.txt').write_text('NOMADS_GAIA\n', encoding='utf-8')
        (saves / 'round.json').write_text(json.dumps({'version': 2, 'generation': self.MARKER, 'maxz': 1,
                                                      'metadata': hashlib.md5(b'NOMADS_GAIA\n').hexdigest()}), encoding='utf-8')
        (saves / 'save_complete.txt').write_text(self.MARKER, encoding='utf-8')
        (saves / '1.sav').write_bytes(b'level 1')
        if intent:
            (saves / 'restart_intent.json').write_text(json.dumps({'version': 1, 'generation': self.MARKER, 'metadata': 'x',
                                                                    'round': 'y'}), encoding='utf-8')

    def staged(self, load_error=None, save_error=None):
        """A built, running region with a staged build ready and two scripted worlds behind query()."""
        group, host = self.built()
        self.machine.up = {self.LIVE}
        self.machine.pids_by_port = {self.LIVE: 100, self.STANDBY: 200}
        host.work('stage', host.request_stage()['operation'])
        self.assertTrue(host.update_pending())
        self.write_save(Path(host.config['repository']) / 'map_saves')
        machine, me = self.machine, self
        world = {'handover': None, 'polls': 0}
        standby = {'standby': None, 'loading': 0}
        self.actions = []

        def query(port, token, action='status', operation=None, session=None, extra=None):
            me.actions.append((port, action, extra))
            if port == me.LIVE:
                if action == 'handover_save':
                    world['handover'] = 'saving'
                    return {'ok': True, 'operation': operation}
                if action == 'handover_cancel':
                    world['handover'] = 'cancelled'
                    return {'ok': True}
                if action == 'handover_release':
                    world['handover'] = 'released'
                    machine.up.discard(me.LIVE)  # the old world reboots out (-close)
                    return {'ok': True}
                if world['handover'] == 'saving':
                    world['polls'] += 1
                    if world['polls'] >= 2:
                        world['handover'] = 'saved'
                        me.write_save(Path(host.config['repository']) / 'map_saves', intent=True)
                busy = world['handover'] in ('saving', 'saved')
                return {'ok': True, 'ready': not busy, 'busy': busy, 'session': me.SESSION, 'clients': 3,
                        'handover': world['handover'], 'error': save_error if world['handover'] == 'saving' else None}
            if port == me.STANDBY:
                if action == 'standby_load':
                    standby['standby'] = 'loading'
                    return {'ok': True, 'operation': operation}
                if action == 'standby_open':
                    standby['standby'] = None
                    machine.up.add(int(extra['port']))
                    return {'ok': True}
                if standby['standby'] is None and standby['loading'] == 0:
                    standby['standby'] = 'waiting'
                if standby['standby'] == 'loading':
                    standby['loading'] += 1
                    if load_error:
                        return {'ok': True, 'ready': False, 'session': me.STANDBY_SESSION, 'standby': 'loading', 'error': load_error}
                    if standby['loading'] >= 3:
                        standby['standby'] = 'loaded'
                ready = standby['standby'] == 'loaded'
                return {'ok': True, 'ready': ready, 'busy': False, 'session': me.STANDBY_SESSION, 'standby': standby['standby'],
                        'restart_hold': not ready, 'error': None}
            raise OSError('nothing listens on %d' % port)

        machine.query = query
        start_standby = machine.start_standby

        def boot(dmb, port):
            standby.update(standby=None, loading=0)  # a fresh process
            machine.up.add(port)
            return start_standby(dmb, port)
        machine.start_standby = boot
        return group, host

    def test_old_world_that_keeps_its_port_is_killed_before_the_standby_opens_it(self):
        group, host = self.staged()
        query = self.machine.query

        def stubborn(port, token, action='status', operation=None, session=None, extra=None):
            answer = query(port, token, action, operation, session, extra)
            if action == 'handover_release':
                self.machine.up.add(self.LIVE)  # it rebooted in place instead of exiting
            return answer
        self.machine.query = stubborn
        host.work('handover', host.request('handover')['operation'])
        state = host.read_state()
        self.assertEqual((state['phase'], state.get('error')), ('done', None), state)
        names = [action for _, action, _ in self.actions if action != 'status']
        self.assertEqual(names, ['handover_save', 'standby_load', 'handover_release', 'standby_open'])
        kill = self.machine.calls.index((['kill_tree', 100], None))
        self.assertGreater(kill, 0, 'the old world was killed after the switch deadline')
        open_at = self.actions.index((self.STANDBY, 'standby_open', {'port': '1720'}))
        self.assertTrue(open_at >= 0)
        self.assertIn(self.LIVE, self.machine.up)

    def test_standby_open_refused_while_the_port_is_held_is_retried(self):
        group, host = self.staged()
        query = self.machine.query
        refused = []

        def flaky(port, token, action='status', operation=None, session=None, extra=None):
            if action == 'standby_open' and not refused:
                refused.append(self.machine.now())
                raise RuntimeError('Lifecycle request rejected')  # port_not_opened: the standby reopened its own port
            return query(port, token, action, operation, session, extra)
        self.machine.query = flaky
        host.work('handover', host.request('handover')['operation'])
        state = host.read_state()
        self.assertEqual((state['phase'], state.get('error')), ('done', None), state)
        self.assertEqual(len([1 for _, action, _ in self.actions if action == 'standby_open']), 1, 'the retry reached the world')
        self.assertEqual(len(refused), 1)
        self.assertIn(self.LIVE, self.machine.up)

    def test_standby_open_uses_the_session_the_loaded_standby_reports(self):
        # Live Gaia, 2026-11-08: standby_open with the session read before the load was
        # refused for a minute and the region stayed down; the session read back worked.
        group, host = self.staged()
        query = self.machine.query
        fresh = 'f' * 32
        loaded = []

        def reloaded(port, token, action='status', operation=None, session=None, extra=None):
            if port == self.STANDBY and action == 'standby_load':
                loaded.append(True)
            if port == self.STANDBY and action == 'standby_open' and session != fresh:
                raise RuntimeError('Lifecycle request rejected: invalid_session_or_operation')
            answer = query(port, token, action, operation, session, extra)
            if port == self.STANDBY and loaded and isinstance(answer, dict) and 'session' in answer:
                answer = dict(answer, session=fresh)
            return answer
        self.machine.query = reloaded
        host.work('handover', host.request('handover')['operation'])
        state = host.read_state()
        self.assertEqual((state['phase'], state.get('error')), ('done', None), state)
        self.assertIn(self.LIVE, self.machine.up)

    def test_handover_moves_the_region_onto_the_staged_build_without_stopping_it(self):
        group, host = self.staged()
        live, staging = self.base / 'regions' / 'gaia', self.base / 'regions' / '.staging' / 'gaia'
        accepted = host.request('handover')
        self.assertEqual(['--worker', 'handover', accepted['operation']], self.machine.detached[-1][-3:])
        host.work('handover', accepted['operation'])
        state = host.read_state()
        self.assertEqual((state['phase'], state.get('error'), state.get('staged')), ('done', None, True), state)
        self.assertEqual(self.machine.standby_started, ('region.b.dmb', self.STANDBY))
        self.assertEqual((live / 'region.b.dmb').read_bytes(), (staging / 'region.dmb').read_bytes())
        self.assertEqual((live / 'region.b.rsc').read_bytes(), (staging / 'region.rsc').read_bytes())
        self.assertEqual((live / 'region.dmb').read_bytes(), b'dmb of ' + str(live).encode(), 'the running build is untouched')
        names = [action for _, action, _ in self.actions if action != 'status']
        self.assertEqual(names, ['handover_save', 'standby_load', 'handover_release', 'standby_open'])
        self.assertEqual([extra for _, action, extra in self.actions if action == 'standby_open'], [{'port': '1720'}])
        self.assertIn(self.LIVE, self.machine.up, 'the new world answers on the region port')
        self.assertTrue((Path(host.config['state_dir']) / 'backups' / accepted['operation'] / '1.sav').exists())
        self.assertEqual(state['generation'], self.MARKER)
        record = json.loads((Path(host.config['state_dir']) / 'build.json').read_text())
        self.assertEqual((record['revision'], record['file']), (NEWER, 'region.b.dmb'))
        self.assertEqual(host.built_revision(), NEWER)
        self.assertFalse(host.update_pending())
        self.assertEqual((live / 'config' / 'lifecycle-revision.txt').read_text().strip(), NEWER)
        self.assertEqual(host.status()['build'], 'region.b.dmb')
        self.assertIn((['git', 'checkout', '--force', '--detach', NEWER], str(live)), self.machine.calls, 'the sources follow the build')
        self.assertTrue(host.running_file.exists())
        # The next plain start runs the slot the region was handed over to.
        self.machine.up = set()
        self.machine.query = lambda *a, **k: {'ok': True, 'ready': True, 'busy': False, 'session': self.SESSION}
        start = self.machine.start_task

        def start_task(name, dmb='region.dmb'):
            self.machine.up.add(self.LIVE)
            return start(name, dmb)
        self.machine.start_task = start_task
        host.work('start', host.request('start')['operation'])
        self.assertEqual(host.read_state()['phase'], 'done', host.read_state())
        self.assertIn((['start', 'region:gaia', 'region.b.dmb'], None), self.machine.calls)

    def test_a_second_handover_uses_the_first_slot_again(self):
        group, host = self.staged()
        host.work('handover', host.request('handover')['operation'])
        self.assertEqual(host.read_state()['phase'], 'done', host.read_state())
        self.machine.revision = 'f' * 40
        self.machine.up = {self.LIVE}
        host.work('stage', host.request_stage()['operation'])
        self.actions.clear()
        host.work('handover', host.request('handover')['operation'])
        self.assertEqual(host.read_state()['phase'], 'done', host.read_state())
        self.assertEqual(self.machine.standby_started, ('region.dmb', self.STANDBY))
        self.assertEqual(host.live_dmb_name(), 'region.dmb')
        self.assertEqual(host.built_revision(), 'f' * 40)

    def test_a_standby_that_cannot_load_the_save_is_stopped_and_the_world_resumes(self):
        group, host = self.staged(load_error='World-save preflight rejected')
        live = self.base / 'regions' / 'gaia'
        host.work('handover', host.request('handover')['operation'])
        state = host.read_state()
        self.assertEqual(state['phase'], 'failed', state)
        self.assertIn('World-save preflight rejected', state['error'])
        names = [action for _, action, _ in self.actions if action != 'status']
        self.assertEqual(names, ['handover_save', 'standby_load', 'handover_cancel'])
        self.assertIn((['kill_tree', 200], None), self.machine.calls, 'the standby is stopped')
        self.assertIn(self.LIVE, self.machine.up, 'the old world keeps running')
        self.assertNotIn(self.STANDBY, self.machine.up)
        self.assertEqual(host.live_dmb_name(), 'region.dmb')
        self.assertEqual(host.built_revision(), REVISION)
        self.assertTrue(host.update_pending(), 'the staged build stays ready for another try')
        revision_file = live / 'config' / 'lifecycle-revision.txt'
        self.assertFalse(revision_file.exists() and revision_file.read_text().strip() == NEWER)
        self.assertFalse(host.lock.exists())

    def test_a_failed_save_leaves_the_world_running_and_stops_the_standby(self):
        group, host = self.staged(save_error='World save failed; server remains running')
        host.work('handover', host.request('handover')['operation'])
        state = host.read_state()
        self.assertEqual(state['phase'], 'failed', state)
        self.assertIn('World save failed', state['error'])
        names = [action for _, action, _ in self.actions if action != 'status']
        self.assertEqual(names, ['handover_save', 'handover_cancel'])
        self.assertIn((['kill_tree', 200], None), self.machine.calls)
        self.assertIn(self.LIVE, self.machine.up)

    def test_handover_refusals(self):
        group, host = self.staged()
        self.machine.up = set()
        with self.assertRaisesRegex(shard_group.Refused, 'not running'):
            host.request('handover')
        self.machine.up = {self.LIVE, self.STANDBY}
        with self.assertRaisesRegex(shard_group.Refused, 'standby port'):
            host.request('handover')
        self.machine.up = {self.LIVE}
        self.machine.free_mb = 512
        with self.assertRaisesRegex(shard_group.Refused, 'MB free'):
            host.request('handover')
        self.machine.free_mb = None
        self.machine.pids = {100}
        host.write_json(host.freeze_file, {'pid': 100, 'frozen_at': 0})
        with self.assertRaisesRegex(shard_group.Refused, 'asleep'):
            host.request('handover')
        host.freeze_file.unlink()
        host.record_build(NEWER, 'region.dmb')  # already on the staged revision
        with self.assertRaisesRegex(shard_group.Refused, 'already runs'):
            host.request('handover')
        self.assertFalse(host.lock.exists())
        plain = shard_group.gaia_host.Host(dict(host.config, _path='x'), self.machine)
        with self.assertRaisesRegex(shard_group.Refused, 'region host'):
            plain.request('handover')

    def test_regions_take_turns_at_the_handover(self):
        group, host = self.staged()
        lock = self.base / 'regions' / '.staging' / 'handover.lock'
        lock.parent.mkdir(parents=True, exist_ok=True)
        lock.write_text('77')
        self.machine.pids = {77}
        phases = []
        real_sleep = self.machine.sleep

        def sleep(seconds):
            real_sleep(seconds)
            if self.machine.pids:
                phases.append(host.read_state().get('phase'))
                self.machine.pids = set()  # the other region's handover finished
        self.machine.sleep = sleep
        host.work('handover', host.request('handover')['operation'])
        self.assertEqual(host.read_state()['phase'], 'done', host.read_state())
        self.assertEqual(phases, ["waiting for another region's handover"])
        self.assertFalse(lock.exists())

    def test_a_world_that_predates_handovers_is_stopped_installed_and_started(self):
        group, host = self.staged()
        live = self.base / 'regions' / 'gaia'
        machine = self.machine

        def query(port, token, action='status', operation=None, session=None, extra=None):
            self.actions.append((port, action, extra))
            if action == 'save_shutdown':
                machine.up.discard(self.LIVE)
                return {'ok': True, 'operation': operation}
            return {'ok': True, 'ready': True, 'busy': False, 'session': self.SESSION, 'clients': 2}  # no handover field
        machine.query = query
        start = machine.start_task

        def start_task(name, dmb='region.dmb'):
            machine.up.add(self.LIVE)
            return start(name, dmb)
        machine.start_task = start_task
        host.work('handover', host.request('handover')['operation'])
        state = host.read_state()
        self.assertEqual((state['phase'], state.get('legacy'), state.get('staged')), ('done', True, True), state)
        names = [action for _, action, _ in self.actions if action != 'status']
        self.assertEqual(names, ['save_shutdown'])
        self.assertIsNone(getattr(machine, 'standby_started', None))
        self.assertEqual((live / 'region.dmb').read_bytes(), (self.base / 'regions' / '.staging' / 'gaia' / 'region.dmb').read_bytes())
        self.assertEqual(host.built_revision(), NEWER)
        self.assertIn((['start', 'region:gaia', 'region.dmb'], None), machine.calls)

    def test_handover_without_a_staged_build_is_refused(self):
        group, host = self.built()
        self.machine.up = {self.LIVE}
        with self.assertRaisesRegex(shard_group.Refused, 'no staged build'):
            host.request('handover')

    def test_standby_port_is_configurable_and_validated(self):
        self.group['regions'][0]['standby_port'] = 1799
        group = self.write_group()
        self.assertEqual(shard_group.RegionHost(shard_group.region_config(group, group['regions'][0]), self.machine).standby_port(), 1799)
        self.assertEqual(shard_group.RegionHost(shard_group.region_config(group, group['regions'][1]), self.machine).standby_port(), 1731)
        self.group['regions'][0]['standby_port'] = 1720
        with self.assertRaisesRegex(ValueError, 'standby_port'):
            self.write_group()
        self.group['regions'][0]['standby_port'] = 1799

    def test_default_standby_port_skips_the_transfer_relay_and_doorman_ports(self):
        # The live earth group: transfer ports are port + 10, so the plain default standby
        # port was the region's own transfer agent and every handover was refused.
        self.group['regions'][0].update(transfer_port=1730)
        self.group['regions'][1].update(transfer_port=1731)
        self.group.update(relay_port=1732, doorman_port=1733)
        group = self.write_group()
        ports = {r['id']: r['standby_port'] for r in group['regions']}
        self.assertEqual(ports, {'gaia': 1734, 'deep': 1735})
        used = {1720, 1721, 1730, 1731, 1732, group['relay_control_port'], 1733}
        self.assertFalse(used & set(ports.values()))
        # A host.json written before standby ports were resolved asks the group.
        config = shard_group.region_config(group, group['regions'][0])
        config.pop('standby_port')
        self.assertEqual(shard_group.RegionHost(config, self.machine).standby_port(), 1734)
        config['group_config'] = str(self.base / 'missing.json')
        self.assertEqual(shard_group.RegionHost(config, self.machine).standby_port(), 1730)
        # An explicit standby port may not take another port of the group.
        for clash in (1730, 1732, 1733):
            self.group['regions'][1]['standby_port'] = clash
            with self.assertRaisesRegex(ValueError, 'standby_port'):
                self.write_group()
        self.group['regions'][1]['standby_port'] = 1799
        self.assertEqual(self.write_group()['regions'][1]['standby_port'], 1799)

    def test_handover_reaches_every_region_from_the_command_line(self):
        group, host = self.staged()
        with mock.patch.object(shard_group, 'RegionPlatform', return_value=self.machine), \
                mock.patch('sys.stdout', new_callable=io.StringIO) as out:
            code = shard_group.main(['--config', str(self.path), 'handover'])
        result = json.loads(out.getvalue())
        self.assertEqual((code, sorted(result['accepted'])), (0, ['gaia']), result)
        self.assertIn('deep', result['refused'])
