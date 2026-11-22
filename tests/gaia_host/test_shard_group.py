"""Offline tests for scripts/shard-group/shard_group.py with a fake machine."""
import importlib.util
import io
import json
import time
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts/gaia-host'))
SPEC = importlib.util.spec_from_file_location('shard_group', ROOT / 'scripts/shard-group/shard_group.py')
shard_group = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(shard_group)
BATTLE_SPEC = importlib.util.spec_from_file_location('battle_mapswap', ROOT / 'scripts/shard-group/battle_mapswap.py')
battle_mapswap = importlib.util.module_from_spec(BATTLE_SPEC)
BATTLE_SPEC.loader.exec_module(battle_mapswap)

REVISION = 'c' * 40
DME = 'line\r\n// BEGIN_SELECTED_MAP\r\n#include "maps\\nomads\\nomads_gaia.dmm"\r\n// END_SELECTED_MAP\r\ntail\r\n'


class SelectedMapTests(unittest.TestCase):
    def test_both_entrypoints_preserve_block_and_line_endings(self):
        for transform in (shard_group.selected_map_dme, battle_mapswap.select_map):
            for newline in ('\n', '\r\n'):
                with self.subTest(transform=transform.__name__, newline=repr(newline)):
                    old = newline.join(('prefix', '// BEGIN_SELECTED_MAP', '#include "old.dmm"',
                                        '// END_SELECTED_MAP', '#include "outside.dmm"',
                                        '// BEGIN_SELECTED_MAP', '#include "second.dmm"',
                                        '// END_SELECTED_MAP', 'tail'))
                    expected = old.replace('#include "old.dmm"', '#include "new.dmm"', 1)
                    self.assertEqual(expected, transform(old, 'new.dmm'))

    def test_missing_block_keeps_each_entrypoint_error(self):
        for transform, message in ((shard_group.selected_map_dme, 'civ13.dme has no selected-map block'),
                                   (battle_mapswap.select_map, 'region.dme has no selected-map block')):
            with self.subTest(transform=transform.__name__):
                with self.assertRaises(RuntimeError) as raised:
                    transform('no block', 'new.dmm')
                self.assertEqual(message, str(raised.exception))

    def test_scripts_import_helper_when_launched_outside_checkout(self):
        with tempfile.TemporaryDirectory() as cwd:
            for name, args, expected in (('shard_group.py', ['--help'], 0),
                                         ('battle_mapswap.py', [], 2)):
                with self.subTest(script=name):
                    result = subprocess.run([sys.executable, str(ROOT / 'scripts/shard-group' / name), *args],
                                            cwd=cwd, capture_output=True, text=True, timeout=30)
                    self.assertEqual(expected, result.returncode, result.stderr)
                    self.assertIn('usage:', result.stdout.lower())


class RegionViewTopicTests(unittest.TestCase):
    def test_fragmented_reply_and_request(self):
        connection = mock.MagicMock()
        connection.recv.side_effect = [b'\x00', b'\x83\x00', b'\x09\x06', b'{"a":', b'1}\x00']
        with mock.patch.object(shard_group.socket, 'create_connection') as connect:
            connect.return_value.__enter__.return_value = connection
            self.assertEqual({'a': 1}, shard_group.region_view(1716, timeout=3))
        connect.assert_called_once_with(('127.0.0.1', 1716), timeout=3)
        query = b'shard_region=1&format=json&peers=1'
        connection.sendall.assert_called_once_with(b'\x00\x83\x00\x28' + b'\0' * 5 + query + b'\0')

    def test_malformed_and_truncated_replies_return_none(self):
        cases = ([b'\x00\x84\x00\x01\x06'], [b'\x00\x83\x00\x01\x05'],
                 [b'\x00\x83\x00\x03\x06', b''], [b'\x00\x83\x00\x03\x06{\x00'])
        for parts in cases:
            with self.subTest(parts=parts):
                connection = mock.MagicMock()
                connection.recv.side_effect = parts
                with mock.patch.object(shard_group.socket, 'create_connection') as connect:
                    connect.return_value.__enter__.return_value = connection
                    self.assertIsNone(shard_group.region_view(1716))


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
    free_disk = None
    pids_by_port = {}

    def free_memory_mb(self):
        return self.free_mb

    def free_disk_mb(self, path):
        return self.free_disk

    def server_pid(self, port):
        return self.pids_by_port.get(port) if port in self.up else None

    def kill_tree(self, pid, expect=None):
        self.calls.append((['kill_tree', pid], None))
        for port, owner in list(self.pids_by_port.items()):
            if owner == pid:
                self.up.discard(port)


class GroupLandsTests(unittest.TestCase):
    """The host tool reads land stages from the coordinator database, read-only."""

    def test_group_lands_reads_the_coordinator_database(self):
        sys.path.insert(0, str(ROOT))
        from tools.transfer_storage.coordinator import Coordinator
        with tempfile.TemporaryDirectory() as root:
            group = {'root': root, 'mainland': 'gaia'}
            self.assertEqual({}, shard_group.group_lands(group))
            c = Coordinator(os.path.join(root, 'coordinator.sqlite'), 'g', 'gaia')
            try:
                for name in ('gaia', 'europe'):
                    c.enroll(name, 'http://127.0.0.1:1', 'x' * 40)
                self.assertTrue(c.set_land('europe', 'FRONTIER', False, 'val'))
            finally:
                c.close()
            lands = shard_group.group_lands(group)
            self.assertEqual(('MAINLAND', 'FRONTIER'), (lands['gaia']['stage'], lands['europe']['stage']))
            self.assertEqual(0, lands['europe']['readiness']['homes'])


class GroupRecordsTests(unittest.TestCase):
    """shard_group.py records: the launcher's read-only Player records window."""

    def test_records_summary_lookup_search_and_export(self):
        sys.path.insert(0, str(ROOT))
        from tools.transfer_storage import records
        import sqlite3
        with tempfile.TemporaryDirectory() as root:
            group = {'root': root, 'regions': [{'id': 'gaia'}, {'id': 'europe'}]}
            self.assertIn('No coordinator database yet', shard_group.group_records(group)['text'])
            gaia = Path(root) / 'gaia'
            (gaia / 'data').mkdir(parents=True)
            (gaia / 'data' / 'player_notes.migrated').write_text('1 notes copied')
            (gaia / 'data' / 'player_records.json').write_text(json.dumps([{'id': 'a' * 32, 'sent': 0}, {'id': 'b' * 32, 'sent': -1}]))
            db = sqlite3.connect(os.path.join(root, 'coordinator.sqlite'))
            records.init_group(db)
            now = 1_800_000_000
            rows = [{'id': '%032x' % 1, 'ckey': 'bob', 'kind': 'note', 'author': 'val', 'rank': 'Host', 'at': now - 50,
                     'body': {'text': 'griefed the well'}},
                    {'id': '%032x' % 2, 'ckey': 'bob', 'kind': 'ban', 'author': 'val', 'rank': 'Host', 'at': now - 40,
                     'body': {'scope': 'game', 'type': 'Server', 'until': 0, 'reason': 'grief', 'ip': '10.0.0.1'}},
                    {'id': '%032x' % 3, 'ckey': 'amy', 'kind': 'warning', 'author': 'val', 'rank': 'Host', 'at': now - 30,
                     'body': {'text': 'spam'}},
                    {'id': '%032x' % 4, 'ckey': 'amy', 'kind': 'revoke', 'author': 'val', 'rank': 'Host', 'at': now - 20,
                     'body': {'target': '%032x' % 3, 'target_kind': 'warning'}}]
            records.store_records(db, 'gaia', rows, now)
            db.commit()
            db.close()
            summary = shard_group.group_records(group, now=now)
            self.assertEqual((1, 1), (summary['players'], summary['active_bans']))  # amy's only record was removed
            self.assertEqual({'active': 0, 'removed': 1}, summary['kinds']['warning'])
            self.assertEqual({'notes': True, 'bans': False, 'memos': False}, summary['regions']['gaia']['migrated'])
            self.assertEqual((1, 1), (summary['regions']['gaia']['waiting'], summary['regions']['gaia']['refused']))
            self.assertIn('gaia: old notes copied; 1 records waiting for the coordinator, 1 refused', summary['text'])
            bob = shard_group.group_records(group, ckey='Bob', now=now)
            self.assertEqual(2, len(bob['records']))
            self.assertIn('griefed the well', bob['text'])
            found = shard_group.group_records(group, search='WELL', now=now)
            self.assertEqual(['%032x' % 1], [r['id'] for r in found['matches']])
            amy = shard_group.group_records(group, ckey='amy', now=now)
            self.assertIn('[removed]', amy['text'])
            out = os.path.join(root, 'export.json')
            self.assertEqual(4, shard_group.group_records(group, export=out, now=now)['exported'])
            exported = json.loads(Path(out).read_text(encoding='utf-8'))['records']
            self.assertEqual('%032x' % 4, [r for r in exported if r['id'] == '%032x' % 3][0]['revoked'])
            with self.assertRaises(shard_group.Refused):
                shard_group.group_records(group, ckey='!!')
            with self.assertRaises(shard_group.Refused):
                shard_group.group_records(group, search='  ')


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
        self.refuse_config('1 to 32 regions', regions=[])
        self.refuse_config('group id', group='Europe!')
        self.refuse_config('mainland', mainland='atlantis')
        self.refuse_config('mainland cannot be a RAID', mainland='deep', region_kind='RAID')
        group = self.write_group()
        self.assertEqual('gaia', group['mainland'], 'the first region is the mainland by default')
        self.assertEqual('gaia', group['start_region'], 'new characters start on the mainland by default')
        self.refuse_config('start_region must be', start_region='atlantis')
        for kind in ('RAID', 'ORBIT', 'EVENT', 'TUTORIAL'):
            self.refuse_config('start region cannot be a %s' % kind, start_region='deep', region_kind=kind)
        self.group['start_region'] = 'deep'
        self.assertEqual(('gaia', 'deep'), (self.write_group()['mainland'], self.write_group()['start_region']),
                         'the start region is apart from the mainland')
        del self.group['start_region']
        self.assertEqual(('HEAD', False), (group['revision'], group['public']))

    def test_every_region_gets_the_host_operator_agent(self):
        group = self.write_group()
        shard_group.setup(group, self.machine)
        token = (self.base / 'regions' / 'operator-token.txt').read_text().strip()
        self.assertRegex(token, '^[0-9a-f]{48}$')
        deep = self.base / 'regions' / 'deep' / 'config' / 'agent-control.txt'
        self.assertEqual('agent operator %s * Host\n' % token, deep.read_text())
        # Lines from an overlay (or the host) stay; the operator line is replaced, never doubled.
        deep.write_text('agent ada %s observe,characters\nagent operator stale * Host\n' % ('a' * 40))
        self.assertTrue(shard_group.write_operator_agent(group, deep.parent.parent))
        self.assertEqual(['agent ada %s observe,characters' % ('a' * 40), 'agent operator %s * Host' % token],
                         deep.read_text().splitlines())
        self.assertFalse(shard_group.write_operator_agent(group, deep.parent.parent), 'an unchanged file is not rewritten')
        self.group['operator_agent'] = False
        off = self.write_group()
        deep.unlink()
        self.assertFalse(shard_group.write_operator_agent(off, deep.parent.parent))
        self.assertFalse(deep.exists())
        self.refuse_config('operator_agent must be', operator_agent='yes')

    def test_setup_creates_worktrees_and_region_config_once(self):
        group = self.write_group()
        result = shard_group.setup(group, self.machine)
        self.assertEqual((REVISION, ['gaia', 'deep']), (result['revision'], result['created']))
        deep = self.base / 'regions' / 'deep'
        settings = json.loads((deep / 'config' / 'shard_region.json').read_text())
        self.assertEqual(('europe', 'deep', 'gaia'), (settings['group'], settings['region'], settings['mainland']))
        self.assertEqual('gaia', settings['start_region'])
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

    def test_event_region_validation_and_setup(self):
        # An event world (region_event.dm): never the mainland or the gate, never saves,
        # and every region of its group shares one event token.
        self.refuse_config('mainland cannot be an EVENT', mainland='deep', region_kind='EVENT')
        self.refuse_config('gate must be', relay_port=1730, gate='deep', region_kind='EVENT')
        self.group['regions'][1]['kind'] = 'EVENT'
        group = self.write_group()
        shard_group.setup(group, self.machine)
        tokens = set()
        for region in ('gaia', 'deep'):
            tokens.add((self.base / 'regions' / region / 'config' / 'event-token.txt').read_text().strip())
        self.assertEqual({(self.base / 'regions' / 'event-token.txt').read_text().strip()}, tokens)
        self.assertRegex(tokens.pop(), '^[0-9a-f]{48}$')
        event = json.loads((self.base / 'regions' / 'deep' / 'config' / 'shard_region.json').read_text())
        self.assertEqual(0, event['save_minutes'])
        home = json.loads((self.base / 'regions' / 'gaia' / 'config' / 'shard_region.json').read_text())
        self.assertEqual(group['save_minutes'], home['save_minutes'])
        self.assertIn('config/event-token.txt', shard_group.GENERATED)

    def test_ordinary_groups_get_no_event_token(self):
        shard_group.setup(self.write_group(), self.machine)
        self.assertFalse((self.base / 'regions' / 'gaia' / 'config' / 'event-token.txt').exists())

    def test_status_shows_characters_away_at_an_event(self):
        group = self.write_group()
        shard_group.setup(group, self.machine)
        self.machine.up.add(1721)
        answers = {1721: {'group': group['group'], 'region': 'deep', 'players': 0, 'map': 'Caves', 'event_away': 4}}
        status = shard_group.group_status(group, 'deep', view=answers.get, platform=self.machine)
        self.assertEqual(4, status['regions']['deep']['region_view']['event_away'])
        for bad in (-1, '4', 2.5, True):
            answers[1721]['event_away'] = bad
            status = shard_group.group_status(group, 'deep', view=answers.get, platform=self.machine)
            self.assertNotIn('event_away', status['regions']['deep']['region_view'], bad)

    def test_status_shows_the_world_calendar(self):
        group = self.write_group()
        shard_group.setup(group, self.machine)
        self.machine.up.add(1721)
        calendar = {'clock': '06:40 AM', 'phase': 'Early Morning', 'season': 'WINTER', 'zone': -2, 'season_left': 37}
        answers = {1721: {'group': group['group'], 'region': 'deep', 'players': 0, 'map': 'Caves', 'calendar': dict(calendar)}}
        status = shard_group.group_status(group, 'deep', view=answers.get, platform=self.machine)
        self.assertEqual(calendar, status['regions']['deep']['region_view']['calendar'])
        for key, bad in (('clock', '6:40'), ('phase', 'Dusk'), ('season', 'monsoon'), ('zone', 2.5), ('zone', 20), ('zone', True)):
            answers[1721]['calendar'] = dict(calendar, **{key: bad})
            status = shard_group.group_status(group, 'deep', view=answers.get, platform=self.machine)
            self.assertNotIn('calendar', status['regions']['deep']['region_view'], (key, bad))
        answers[1721]['calendar'] = dict(calendar, season_left=-5)
        status = shard_group.group_status(group, 'deep', view=answers.get, platform=self.machine)
        self.assertNotIn('season_left', status['regions']['deep']['region_view']['calendar'])
        answers[1721].pop('calendar')
        status = shard_group.group_status(group, 'deep', view=answers.get, platform=self.machine)
        self.assertNotIn('calendar', status['regions']['deep']['region_view'])

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

    def test_supervise_teaches_a_running_relay_the_group_ports_once(self):
        # A relay started before a region joined refused routes to it (South America, 2026-11-15).
        self.group['relay_port'] = 1730
        group = self.write_group()
        shard_group.setup(group, self.machine)
        (self.base / 'regions' / 'relay.pid').write_text('5151\n')
        sent = []
        def send(port, query):
            sent.append(query)
            return json.dumps({'ok': True})
        real = shard_group.relay_add_ports
        with mock.patch.object(shard_group, 'process_alive', lambda pid: pid == 5151), \
                mock.patch.object(shard_group, 'relay_add_ports', lambda group, _=None: real(group, send)):
            self.assertEqual({'relay_ports': True}, shard_group.supervise(group, lambda *a: 1))
            self.assertEqual(2, len(sent))
            # Nothing changed: no requests on the next pass.
            self.assertEqual({}, shard_group.supervise(group, lambda *a: 1))
            self.assertEqual(2, len(sent))
            # A new relay process hears them all again.
            (self.base / 'regions' / 'relay.pid').write_text('6262\n')
        with mock.patch.object(shard_group, 'process_alive', lambda pid: pid == 6262), \
                mock.patch.object(shard_group, 'relay_add_ports', lambda group, _=None: real(group, send)):
            self.assertEqual({'relay_ports': True}, shard_group.supervise(group, lambda *a: 1))
            self.assertEqual(4, len(sent))
        # A relay that does not answer is asked again next pass.
        def down(port, query):
            raise OSError('refused')
        (self.base / 'regions' / 'relay.pid').write_text('7373\n')
        with mock.patch.object(shard_group, 'process_alive', lambda pid: pid == 7373), \
                mock.patch.object(shard_group, 'relay_add_ports', lambda group, _=None: real(group, down)):
            self.assertEqual({}, shard_group.supervise(group, lambda *a: 1))
            self.assertEqual({}, shard_group.supervise(group, lambda *a: 1))

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

    def test_backups_in_the_same_second_never_overwrite(self):
        self.path = self.base / 'group.json'
        self.path.write_text('first')
        frozen = time.gmtime(1700000000)
        with mock.patch.object(shard_group.time, 'gmtime', return_value=frozen):
            first = shard_group.unused_backup_path(self.path)
            first.write_text('first')
            second = shard_group.unused_backup_path(self.path)
        self.assertNotEqual(first, second)
        self.assertEqual('group.json.bak-20231114-221320', first.name)
        self.assertEqual('group.json.bak-20231114-221320-2', second.name)

    def test_transfer_and_save_options(self):
        group = self.write_group()
        self.assertEqual((False, 15, 60, True), (group['transfers'], group['save_minutes'], group['travel_save_seconds'], group['persistent']))
        self.refuse_config('transfer_port', region_transfer_port=1720)
        self.group['regions'][0]['transfer_port'] = 47201
        # Earlier writes may have kept backups in another second; count only this one.
        for old in self.base.glob('group.json.bak-*'):
            old.unlink()
        # Once any region has one, the others get theirs chosen and kept in the file (fill_ports).
        earlier = set(self.base.glob('group.json.bak-*'))
        written = json.loads(json.dumps(self.group))
        with mock.patch.object(shard_group.Platform, 'listening', return_value=False):
            filled = self.write_group()
        chosen = filled['regions'][1]['transfer_port']
        self.assertEqual((True, filled['regions'][1]['port'] + shard_group.TRANSFER_PORT_OFFSET), (filled['transfers'], chosen))
        self.assertEqual(chosen, json.loads(self.path.read_text())['regions'][1]['transfer_port'])
        # Counted against the backups already there, so a slow runner crossing a second
        # boundary between loads does not change the count.
        kept = set(self.base.glob('group.json.bak-*')) - earlier
        self.assertEqual(1, len(kept), 'the file as the host wrote it is kept')
        self.assertEqual(written, json.loads(next(iter(kept)).read_text()))
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
        self.assertEqual('gaia', started[0][started[0].index('--start-region') + 1])
        # A new start region (launcher Start region) restarts a running coordinator at the next check.
        ended = []
        with mock.patch.object(shard_group, 'coordinator_pid', lambda g: 4242):
            self.assertFalse(shard_group.ensure_coordinator(group, start, refresh=True, terminate=lambda pid, expect=None: ended.append(pid)))
            moved = dict(group, start_region='deep')
            self.assertTrue(shard_group.ensure_coordinator(moved, start, refresh=True, terminate=lambda pid, expect=None: ended.append(pid)))
        self.assertEqual([4242], ended)
        self.assertEqual('deep', started[1][started[1].index('--start-region') + 1])
        started.pop()
        # So does a new mainland.
        with mock.patch.object(shard_group, 'coordinator_pid', lambda g: 4242):
            self.assertTrue(shard_group.ensure_coordinator(dict(moved, mainland='deep'), start, refresh=True, terminate=lambda pid, expect=None: ended.append(pid)))
            self.assertFalse(shard_group.ensure_coordinator(dict(moved, mainland='deep'), start, refresh=True, terminate=lambda pid, expect=None: ended.append(pid)))
        self.assertEqual('deep', started[1][started[1].index('--mainland') + 1])
        started.pop()
        self.assertEqual('4242', (self.base / 'regions' / 'coordinator.pid').read_text().strip())
        # Only a group without a coordinator database asserts a clean bootstrap.
        self.assertIn('--bootstrap-new-group', started[0])
        (self.base / 'regions' / 'coordinator.pid').unlink()
        (self.base / 'regions' / 'coordinator.sqlite').write_bytes(b'')
        self.assertTrue(shard_group.ensure_coordinator(group, start))
        self.assertNotIn('--bootstrap-new-group', started[1])
        (self.base / 'regions' / 'coordinator.sqlite').unlink()
        # A store an unflagged coordinator created on the cleared group decided
        # nothing, so the next start still asserts the bootstrap (else every join
        # waits on a held directory). Any decided state keeps the flag off.
        sys.path.insert(0, str(ROOT))
        from tools.transfer_storage.coordinator import Coordinator
        database = self.base / 'regions' / 'coordinator.sqlite'
        Coordinator(str(database), 'earth', 'gaia').close()
        (self.base / 'regions' / 'coordinator.pid').unlink()
        self.assertTrue(shard_group.ensure_coordinator(group, start))
        self.assertIn('--bootstrap-new-group', started[2])
        coordinator = Coordinator(str(database), 'earth', 'gaia')
        coordinator._set_home('someone', 'gaia')
        coordinator.close()
        (self.base / 'regions' / 'coordinator.pid').unlink()
        self.assertTrue(shard_group.ensure_coordinator(group, start))
        self.assertNotIn('--bootstrap-new-group', started[3])
        for path in database.parent.glob('coordinator.sqlite*'):
            path.unlink()
        platform = shard_group.RegionPlatform(shard_group.region_config(group, group['regions'][1]))
        self.assertEqual(['gaia'], platform.config['peers'])
        self.group['persistent'] = False
        shard_group.setup(self.write_group(), self.machine)
        self.assertEqual(0, json.loads((config / 'shard_region.json').read_text())['save_minutes'])

    def test_a_standby_is_launched_for_its_own_port(self):
        # A standby that took over keeps its launch parameters; naming its own port
        # lets a later reboot on the region's port come back as the region
        # (North America and Jungle, 2026-11-16).
        group = self.write_group()
        platform = shard_group.RegionPlatform(shard_group.region_config(group, group['regions'][0]))
        platform.config['repository'] = str(self.base)
        platform.start_agent = lambda: None
        launched = []
        detach = shard_group.detach
        shard_group.detach = lambda argv, cwd, log: launched.append(argv) or 4242
        try:
            self.assertEqual(4242, platform.start_standby('region.b.dmb', 1755))
        finally:
            shard_group.detach = detach
        self.assertEqual(['-params', 'standby=1755'], launched[0][-2:])
        dm = (Path(__file__).resolve().parents[2] / 'code/modules/persistence/restart_transaction.dm').read_text()
        self.assertIn('persistence_standby_launch(islist(world.params) ? world.params["standby"] : null, world.port)', dm)
        self.assertIn('return isnum(launched) && launched == port', dm)

    def test_a_public_standby_can_join_the_hub_after_its_handover(self):
        # -invisible kept a standby off the BYOND hub even after it took over the
        # region's port, so Gaia vanished from the hub (2026-11-18). A public region's
        # standby launches -public; DM keeps it hidden until the handover opens it.
        group = self.write_group()
        platform = shard_group.RegionPlatform(shard_group.region_config(group, group['regions'][0]))
        platform.config['repository'] = str(self.base)
        platform.start_agent = lambda: None
        launched = []
        detach = shard_group.detach
        shard_group.detach = lambda argv, cwd, log: launched.append(argv) or 4242
        try:
            for public in (True, False):
                platform.config['public'] = public
                platform.start_standby('region.b.dmb', 1755)
        finally:
            shard_group.detach = detach
        self.assertIn('-public', launched[0])
        self.assertNotIn('-invisible', launched[0])
        self.assertIn('-invisible', launched[1])
        self.assertNotIn('-public', launched[1])
        root = Path(__file__).resolve().parents[2]
        self.assertIn('visibility = 0', (root / 'code/hub.dm').read_text())
        config = (root / 'code/datums/configuration.dm').read_text()
        self.assertIn('if (config.hub && !persistence_standby_launch(islist(world.params) ? world.params["standby"] : null, world.port))', config)
        lifecycle = (root / 'code/modules/persistence/nomads_lifecycle.dm').read_text()
        self.assertIn('world.visibility = config && config.hub ? TRUE : FALSE', lifecycle)

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

    def test_tutorial_region(self):
        self.refuse_config('mainland cannot be a TUTORIAL', mainland='deep', region_kind='TUTORIAL')
        self.refuse_config('gate must be', relay_port=1730, gate='deep', region_kind='TUTORIAL')
        self.group['regions'][0]['kind'] = 'TUTORIAL'
        self.refuse_config('at most one TUTORIAL', region_kind='TUTORIAL', mainland='deep')
        self.group['regions'][0]['kind'] = 'SURFACE'
        self.group['regions'][1]['kind'] = 'TUTORIAL'
        group = self.write_group()
        shard_group.setup(group, self.machine)
        settings = json.loads((self.base / 'regions' / 'deep' / 'config' / 'shard_region.json').read_text())
        self.assertEqual(0, settings['save_minutes'], 'a tutorial region never saves')
        gaia = json.loads((self.base / 'regions' / 'gaia' / 'config' / 'shard_region.json').read_text())
        self.assertEqual(15, gaia['save_minutes'])

    def test_tutorial_config_never_saves(self):
        path = self.base / 'config.txt'
        path.write_text('A 1\nALLOWED_GAMEMODES PERSISTENCE\n#SKIP_PERSISTENCE_SAVING\n')
        shard_group.tutorial_config(path)
        self.assertEqual(['A 1', 'SKIP_PERSISTENCE_SAVING', 'ALLOWED_GAMEMODES ALL'], path.read_text().splitlines())
        path.write_text('ALLOWED_GAMEMODES PERSISTENCE\n')
        shard_group.region_mode_config({'persistent': True}, {'kind': 'TUTORIAL'}, path)
        self.assertEqual(['ALLOWED_GAMEMODES ALL', 'SKIP_PERSISTENCE_SAVING'], path.read_text().splitlines())
        shard_group.region_mode_config({'persistent': True}, {'kind': 'SURFACE'}, path)
        self.assertIn('ALLOWED_GAMEMODES PERSISTENCE', path.read_text())

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

    def test_update_retries_a_compiler_that_died_while_loading(self):
        group = self.write_group()
        shard_group.setup(group, self.machine)
        host = self.host(group, 'gaia')
        died = 'DM compiler version 516.1688\nloading region.dme\nloading interface/skin.dmf'
        run = self.machine.run
        outputs = [died]
        def run_once_dead(argv, cwd=None, timeout=1800, low_priority=False):
            if argv[-1] == 'region.dme' and outputs:
                self.machine.calls.append((list(argv), str(cwd)))
                return 1, outputs.pop()
            return run(argv, cwd, timeout, low_priority)
        self.machine.run = run_once_dead
        host.work('update', host.request('update')['operation'])
        self.assertEqual('done', host.read_state()['phase'], host.read_state())
        self.assertEqual(2, sum(1 for call in self.machine.calls if call[0][-1] == 'region.dme'))
        self.assertIn(str(host.repo), self.machine.low_priority, 'an update compiles at low priority')
        self.assertFalse((host.repo.parent / '.staging' / 'compile.lock').exists(), 'the slot is released')
        outputs[:] = [died, died]
        host.work('update', host.request('update')['operation'])
        self.assertEqual('failed', host.read_state()['phase'])
        self.assertIn('loading interface/skin.dmf', host.read_state()['error'])
        self.assertFalse((host.repo.parent / '.staging' / 'compile.lock').exists(), 'released after a failure')

    def test_update_waits_for_the_group_compile_slot(self):
        group = self.write_group()
        shard_group.setup(group, self.machine)
        host = self.host(group, 'gaia')
        lock = host.repo.parent / '.staging' / 'compile.lock'
        lock.parent.mkdir(parents=True, exist_ok=True)
        lock.write_text('777')
        self.machine.pids.add(777)
        seen = []
        def sleep(seconds):
            seen.append(host.read_state().get('phase'))
            self.machine.pids.discard(777)  # the other region's compile finishes
            self.machine.clock += seconds
        self.machine.sleep = sleep
        host.work('update', host.request('update')['operation'])
        self.assertEqual('done', host.read_state()['phase'], host.read_state())
        self.assertIn("waiting for another region's compile", seen)

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

    def test_a_traveller_starts_a_stopped_region_unless_it_is_kept_down(self):
        # Val (2026-11-22): travel to a land that is not up prepares it, unless a person kept it down.
        self.refuse_config('keep_down must be true or false', region_keep_down='yes')
        group = self.write_group()
        host = self.host(group, 'deep')
        self.assertEqual(host.travel_start_refusal(), 'not set up')
        shard_group.setup(group, self.machine)
        host = self.host(group, 'deep')
        self.assertIsNone(host.travel_start_refusal())
        self.assertNotIn('keep_down', host.status())
        accepted = host.start_for_travel('test')
        self.assertEqual((accepted['action'], accepted['travel_start']), ('start', True))
        self.assertTrue(host.starting())
        self.assertEqual(host.start_for_travel('again'), {'already_starting': True, 'reason': 'again'})
        host.lock.unlink()
        self.group['regions'][1]['keep_down'] = True
        self.write_group()
        self.assertEqual(host.travel_start_refusal(), 'kept down')
        self.assertTrue(host.status()['keep_down'])
        with self.assertRaisesRegex(shard_group.Refused, 'kept down'):
            host.start_for_travel('test')
        self.assertFalse(host.lock.exists())

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

    def test_start_waits_once_for_the_byond_pager_before_starting_the_regions(self):
        self.write_group()
        calls = []

        class Machine:
            def listening(self, port):
                return False

        class Region:
            def __init__(self, name, public):
                self.name, self.platform = name, Machine()
                self.config = {'start_requires_byond_pager': public, 'port': 1}

            def wait_for_byond(self):
                calls.append(('wait', self.name))
                return True

            def request(self, action):
                calls.append((action, self.name))
                return {'accepted': True}

        regions = [({'id': 'deep'}, Region('deep', False)), ({'id': 'gaia'}, Region('gaia', True)),
                   ({'id': 'yard'}, Region('yard', True))]
        with mock.patch.object(shard_group, 'hosts', return_value=regions),                 mock.patch.object(shard_group, 'ensure_coordinator', return_value=False), mock.patch('sys.stdout', io.StringIO()):
            self.assertEqual(0, shard_group.main(['--config', str(self.path), 'start']))
        self.assertEqual([('start', 'deep'), ('wait', 'gaia'), ('start', 'gaia'), ('start', 'yard')], calls)

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

    def test_players_and_send_players_ask_the_running_region(self):
        # Send Player to Region from the launcher (region_admin_send.dm): a dry run by default.
        group = self.write_group()
        shard_group.setup(group, self.machine)
        asked = []

        def query(port, token, action='status', operation=None, session=None, extra=None):
            asked.append((port, action, extra))
            if action == 'players':
                return {'ok': True, 'players': [{'ckey': 'ann', 'name': 'Ann'}], 'recent': [], 'running': False, 'destinations': {'The Deep (up)': 'deep'}}
            return {'ok': True, 'send': 'dry_run' if extra['dry_run'] == '1' else 'started', 'rows': [{'ckey': 'ann', 'ok': True}]}
        self.machine.query = query
        with self.assertRaisesRegex(shard_group.Refused, 'not running'):
            shard_group.region_players(group, 'gaia', self.machine)
        self.machine.up.add(1720)
        self.assertEqual('ann', shard_group.region_players(group, 'gaia', self.machine)['players'][0]['ckey'])
        result = shard_group.send_players(group, 'gaia', 'ann,Bob', 'deep', platform=self.machine)
        self.assertEqual('dry_run', result['send'])
        self.assertEqual((1720, 'send_players', {'ckeys': 'ann,Bob', 'to': 'deep', 'landing': 'shore', 'dry_run': '1'}), asked[-1])
        result = shard_group.send_players(group, 'gaia', 'ann', 'deep', 'coords', '10,20,1', dry_run=False, platform=self.machine)
        self.assertEqual('started', result['send'])
        self.assertEqual({'ckeys': 'ann', 'to': 'deep', 'landing': 'coords', 'dry_run': '0', 'at': '10,20,1'}, asked[-1][2])
        shard_group.send_players(group, 'gaia', 'ann', 'deep', 'arrival', ship=True, platform=self.machine)
        self.assertEqual('1', asked[-1][2]['ship'])
        # Bad requests never reach the world.
        count = len(asked)
        for args in (('ann', 'gaia', 'shore', None), ('ann', 'atlantis', 'shore', None), ('ann', 'deep', 'coords', None),
                     ('ann', 'deep', 'shore', '1,2,3'), ('ann', 'deep', 'coords', '1,2'), ('a&b=c', 'deep', 'shore', None),
                     ('ann', 'deep', 'sky', None)):
            with self.assertRaises(shard_group.Refused):
                shard_group.send_players(group, 'gaia', *args, platform=self.machine)
        self.assertEqual(count, len(asked))
        # An older world without the request says so instead of answering nothing.
        self.machine.query = lambda *a, **k: {'ok': False, 'error': 'malformed_request'}
        with self.assertRaisesRegex(shard_group.Refused, 'older build'):
            shard_group.send_players(group, 'gaia', 'ann', 'deep', platform=self.machine)

    def test_magic_whitelist_is_one_shared_file(self):
        # code/modules/divine/magic_whitelist.dm: every region reads the mainland's (or gate's) SQL file.
        group = self.write_group()
        path = shard_group.magic_whitelist_path(group)
        self.assertEqual(shard_group.region_dir(group, group['mainland']) / 'SQL' / 'magic_whitelist.txt', path)
        self.assertEqual([], shard_group.magic_whitelist(group)['keys'])
        result = shard_group.magic_whitelist(group, add='Ann,bob_2, Cid')
        self.assertEqual(['ann', 'bob2', 'cid'], result['keys'])
        self.assertEqual(['ann', 'bob2', 'cid'], result['added'])
        text = path.read_text(encoding='utf-8')
        self.assertTrue(text.startswith(shard_group.MAGIC_WHITELIST_HEADER))
        self.assertEqual(['ann', 'bob2', 'cid'], shard_group.magic_whitelist_keys(text))
        # Hand edits with comments and Windows line endings still read.
        path.write_text('# staff\r\nAnn # first\r\nzed\r\nann\r\n', encoding='utf-8')
        result = shard_group.magic_whitelist(group, add='zed', remove='ANN,nobody')
        self.assertEqual(['zed'], result['keys'])
        self.assertEqual(([], ['ann']), (result['added'], result['removed']))
        for bad in ('a&b', '', 'x' * 40, ','.join(['k%d' % i for i in range(21)])):
            with self.assertRaises(shard_group.Refused):
                shard_group.magic_whitelist(group, add=bad)
        self.assertEqual(['zed'], shard_group.magic_whitelist(group)['keys'])
        # Behind the relay the gate's file is the shared one.
        group['relay_port'], group['gate'] = 1790, 'deep'
        self.assertEqual(shard_group.region_dir(group, 'deep') / 'SQL' / 'magic_whitelist.txt', shard_group.magic_whitelist_path(group))

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

    def test_status_shows_a_held_transfer_agent(self):
        group = self.write_group()
        shard_group.setup(group, self.machine)
        self.machine.up.add(1721)
        answers = {1721: {'group': group['group'], 'region': 'deep', 'players': 0, 'map': 'Berlin', 'transfers_held': 1}}
        status = shard_group.group_status(group, 'deep', view=answers.get, platform=self.machine)
        self.assertIs(True, status['regions']['deep']['region_view']['transfers_held'])
        del answers[1721]['transfers_held']
        status = shard_group.group_status(group, 'deep', view=answers.get, platform=self.machine)
        self.assertNotIn('transfers_held', status['regions']['deep']['region_view'])

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
        # Only a land across the sea sleeps on disk by default; the group can say otherwise.
        self.assertNotIn('freeze_cold', config)
        slot = dict(group['regions'][1], kind='EXPEDITION')
        self.assertTrue(shard_group.region_config(group, slot)['freeze_cold'])
        self.assertFalse(shard_group.region_config(dict(group, freeze_cold=False), slot)['freeze_cold'])
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
        def terminate(platform, pid, expect=None):
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
        hosts, supervisors, watches = gaia_host.group_hosts([str(self.path)])
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
        self.assertEqual([], [p.name for p in (gaia / 'config').iterdir() if p.name not in ('config.txt', 'shard_region.json', 'agent-control.txt')
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

    def test_config_apply_moves_the_mainland_in_shard_region(self):
        # The host moved the mainland while the regions run (Gaia, 2026-11-15): config-apply
        # brings shard_region.json up to the group without a setup, which needs them stopped.
        path = self.base / 'region'
        (path / 'config').mkdir(parents=True)
        target = path / 'config' / 'shard_region.json'
        self.assertIsNone(shard_group.refresh_shard_region({'mainland': 'gaia', 'start_region': 'gaia'}, path))
        target.write_text(json.dumps({'region': 'northamerica', 'mainland': 'northamerica', 'start_region': 'gaia', 'gate': 'northamerica'}))
        self.assertTrue(shard_group.refresh_shard_region({'mainland': 'gaia', 'start_region': 'gaia'}, path))
        self.assertEqual({'region': 'northamerica', 'mainland': 'gaia', 'start_region': 'gaia', 'gate': 'northamerica'},
                         json.loads(target.read_text()), 'the gate and everything else stay')
        self.assertFalse(shard_group.refresh_shard_region({'mainland': 'gaia', 'start_region': 'gaia'}, path))

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
        self.assertEqual(old, answer['current'], 'the furthest-behind region names the current build, not an updated one')
        self.assertNotEqual(answer['current'], answer['available'])
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
        def kill(pid, expect=None):
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
        def kill(pid, expect=None):
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
        # A pid file naming some other process (a reused pid after a reboot) is never ended.
        self.alive.add(103)
        self.lock('deep', 103)
        seen = []

        def refuse(pid, expect=None):
            seen.append(expect)
            raise shard_group.Unverified('process %d is not Python (it is C:\\x.exe); it was left running' % pid)
        result = shard_group.help_stop(group, timeout=0, sleep=lambda s: None, clock=lambda: 0.0, kill=refuse, region_id='deep')
        self.assertEqual([], result['forced'])
        self.assertIn('not Python', result['not_ended']['deep'])
        self.assertIn(103, self.alive)
        self.assertEqual('Python', seen[0].what)
        self.assertIsNotNone(seen[0].born_before, 'the pid file time bounds the process age')

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
        self.assertEqual(self.machine.low_priority[-1:], [str(staging)])
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

    def test_a_background_stage_lets_a_requested_stage_compile_first(self):
        # Val (2026-11-18): Save, update and restart for one region queued behind the host
        # service's background stages of every other region, one compile at a time.
        group, host = self.built()
        deep = self.host(group, 'deep')
        deep.log = lambda values: None
        background = deep.request_stage()  # the host service's own stage of another region
        wanted = host.request_stage(urgent=True)  # a person's Save, update and restart
        self.assertTrue(host.urgent_marker().exists())
        phases = []
        def sleep(seconds):
            phases.append(deep.read_json(deep.stage_file).get('phase'))
            host.work('stage', wanted['operation'])  # the requested stage runs meanwhile
            self.machine.clock += seconds
        self.machine.sleep = sleep
        deep.work('stage', background['operation'])
        self.assertEqual(['waiting for a requested build of another region'], phases)
        self.assertEqual('ready', host.read_json(host.stage_file)['phase'])
        self.assertEqual('ready', deep.read_json(deep.stage_file)['phase'])
        self.assertFalse(host.urgent_marker().exists(), 'the marker ends with its stage')
        self.assertFalse(host.urgent_stage_waiting())

    def test_a_queued_background_stage_is_moved_up_when_a_person_asks(self):
        group, host = self.built()
        queued = host.request_stage()
        self.assertFalse(host.urgent_marker().exists())
        with self.assertRaisesRegex(shard_group.Refused, 'already being staged'):
            host.request_stage(urgent=True)
        self.assertTrue(host.urgent_marker().exists())
        deep = self.host(group, 'deep')
        self.assertTrue(deep.urgent_stage_waiting())
        self.assertFalse(host.urgent_stage_waiting(), 'a region never waits for itself')
        host.work('stage', queued['operation'])
        self.assertFalse(deep.urgent_stage_waiting())

    def test_a_stale_urgent_marker_is_ignored_and_removed(self):
        group, host = self.built()
        host.mark_stage_urgent()  # its stage ended without clearing it (a killed worker)
        deep = self.host(group, 'deep')
        self.assertFalse(deep.urgent_stage_waiting())
        self.assertFalse(host.urgent_marker().exists())

    def test_a_stage_builds_the_revision_current_when_its_compile_slot_comes_round(self):
        # A stage queued before deploy.bat pulled must not build (and hand over onto) the
        # revision of its queueing.
        group, host = self.built()
        lock = host.repo.parent / '.staging' / 'compile.lock'
        lock.parent.mkdir(parents=True, exist_ok=True)
        lock.write_text('777')
        self.machine.pids.add(777)
        newest = 'f' * 40
        def sleep(seconds):
            self.machine.pids.discard(777)  # the other region's compile finishes
            self.machine.revision = newest  # and master moved meanwhile
            self.machine.clock += seconds
        self.machine.sleep = sleep
        host.work('stage', host.request_stage()['operation'])
        stage = host.read_json(host.stage_file)
        self.assertEqual(('ready', newest), (stage['phase'], stage['revision']), stage)
        self.assertEqual(newest, host.staged_revision())

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

    def test_a_failed_stage_stops_showing_once_a_newer_build_runs(self):
        # Desert kept "update build failed: [WinError 32] ... compile.lock" on its status
        # line for a day after the race was fixed, through updates, kills and unlocks.
        group, host = self.built()
        host.write_json(host.stage_file, {'phase': 'failed', 'error': "[WinError 32] ... 'compile.lock'", 'updated': 1})
        old = host.build_file().stat().st_mtime_ns
        os.utime(host.stage_file, ns=(old + 10**9, old + 10**9))
        self.assertEqual('failed', host.status()['stage']['phase'], 'a failure after the build still shows')
        os.utime(host.build_file(), ns=(old + 2 * 10**9, old + 2 * 10**9))
        self.assertNotIn('stage', host.status(), 'a newer build supersedes it')
        host.stage_lock.write_text('busy')
        self.assertIn('stage', host.status(), 'never hidden while a stage runs')
        self.assertFalse(host.clear_failed_stage())
        host.stage_lock.unlink()
        # unlock clears it even without a newer build.
        os.utime(host.stage_file, ns=(old + 3 * 10**9, old + 3 * 10**9))
        self.assertTrue(host.unlock()['stage_cleared'])
        self.assertFalse(host.stage_file.exists())
        self.assertNotIn('stage_cleared', host.unlock())

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
        lock.parent.mkdir(parents=True, exist_ok=True)
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

    def test_an_empty_compile_lock_is_a_claim_in_progress_not_stale(self):
        group, host = self.built()
        lock = self.base / 'regions' / '.staging' / 'compile.lock'
        lock.parent.mkdir(parents=True, exist_ok=True)
        lock.write_text('')  # another region created it and has not written its pid yet
        seen = []
        real_sleep = self.machine.sleep
        def sleep(seconds):
            seen.append(lock.exists())
            real_sleep(seconds)
            if self.machine.clock >= 20:
                lock.write_text('77')  # its pid lands; that compile then finishes
                self.machine.pids = set()
        self.machine.sleep = sleep
        host.work('stage', host.request_stage()['operation'])
        self.assertEqual(host.read_json(host.stage_file)['phase'], 'ready')
        self.assertEqual(seen[:2], [True, True], 'the fresh empty lock was waited on, not deleted')
        self.assertFalse(lock.exists())

    def test_an_empty_compile_lock_left_behind_is_cleared_after_a_minute(self):
        group, host = self.built()
        lock = self.base / 'regions' / '.staging' / 'compile.lock'
        lock.parent.mkdir(parents=True, exist_ok=True)
        lock.write_text('')
        host.work('stage', host.request_stage()['operation'])
        self.assertEqual(host.read_json(host.stage_file)['phase'], 'ready')
        self.assertEqual(self.machine.clock, 60)

    def test_a_compile_lock_windows_will_not_delete_is_waited_on(self):
        group, host = self.built()
        lock = self.base / 'regions' / '.staging' / 'compile.lock'
        lock.parent.mkdir(parents=True, exist_ok=True)
        lock.write_text('77')  # a dead holder, but the file is still open somewhere
        real_unlink, refusals = Path.unlink, []
        def unlink(path, missing_ok=False):
            if path == lock and len(refusals) < 2:
                refusals.append(path)
                raise PermissionError(32, 'The process cannot access the file because it is being used by another process')
            return real_unlink(path, missing_ok=missing_ok)
        with mock.patch.object(Path, 'unlink', unlink):
            host.work('stage', host.request_stage()['operation'])
        self.assertEqual(host.read_json(host.stage_file)['phase'], 'ready', host.read_json(host.stage_file))
        self.assertEqual(len(refusals), 2)

    def test_a_cold_mainland_keeps_its_existing_build_before_wake(self):
        self.group['update_when_empty'] = False
        group, host = self.built()
        host.work('stage', host.request_stage()['operation'])
        host.write_json(host.cold_file, {'frozen_at': 0})
        self.machine.detached.clear()
        host.watch_step(None)
        self.assertFalse([argv for argv in self.machine.detached if argv[-2] == 'update'])
        self.assertEqual(host.built_revision(), REVISION)
        self.assertEqual(host.status()['state'], 'cold', 'it still starts on the next wake')

    def test_an_empty_mainland_hands_over_instead_of_restarting_at_idle(self):
        self.group['update_when_empty'] = False
        group, host = self.built()
        host.work('stage', host.request_stage()['operation'])
        self.machine.up = {1720}
        idle, _ = host.watch_step(None)
        self.machine.clock += 15 * 60
        host.watch_step(idle)
        self.assertEqual(self.machine.detached[-1][-2], 'auto-handover')
        self.assertFalse(host.frozen())

    def test_idle_update_does_not_retry_a_failed_mainland_handover(self):
        self.group['update_when_empty'] = False
        group, host = self.built()
        host.work('stage', host.request_stage()['operation'])
        host.record(action='auto-handover', phase='failed', revision=NEWER, error='standby load failed')
        self.machine.up = {1720}
        self.machine.detached.clear()
        idle, _ = host.watch_step(None)
        for _ in range(3):
            self.machine.clock += 15 * 60
            idle, _ = host.watch_step(idle)
        self.assertFalse([argv for argv in self.machine.detached if argv[-2] in ('restart', 'handover', 'auto-handover')])

    def test_an_empty_saved_region_updates_at_once_when_master_moves_on(self):
        # Val (2026-11-13): once the region is empty and has saved, an update is built beside it
        # and it restarts onto it straight away, without waiting the idle minutes for sleep.
        group, host = self.built()
        self.machine.up = {1720}
        idle, wait = host.watch_step(None)
        self.assertEqual(['--worker', 'stage'], self.machine.detached[-1][-3:-1], 'the update is built beside the world')
        self.assertEqual((idle, wait), (0, 30))
        self.machine.clock += 20 * 60  # the build is slow: the region does not fall asleep meanwhile
        idle, _ = host.watch_step(idle)
        self.assertFalse(host.frozen())
        self.assertEqual('stage', self.machine.detached[-1][-2], 'only one build')
        host.work('stage', self.machine.detached[-1][-1])
        host.watch_step(idle)
        self.assertEqual('auto-handover', self.machine.detached[-1][-2], 'the new build loads the save before it takes over')

    def test_an_unattended_update_never_falls_back_to_a_plain_restart(self):
        # A save the new code cannot read must not leave the region down: only a handover,
        # whose standby loads the save first, may install an unattended update.
        group, host = self.built()
        host.work('stage', host.request_stage()['operation'])
        self.machine.up = {1720}
        self.machine.free_mb = 100  # too little memory for a standby
        self.machine.detached.clear()
        idle, _ = host.watch_step(None)
        for _ in range(3):
            self.machine.clock += 15 * 60
            idle, _ = host.watch_step(idle)
        self.assertFalse([argv for argv in self.machine.detached if argv[-2] in ('restart', 'handover', 'update')])

    def test_a_failed_handover_is_not_retried_for_the_same_build(self):
        group, host = self.built()
        host.work('stage', host.request_stage()['operation'])
        host.record(action='handover', phase='failed', revision=NEWER, error='the standby world did not load the save in time')
        self.machine.up = {1720}
        host.watch_step(None)
        self.assertFalse([argv for argv in self.machine.detached if argv[-2] in ('restart', 'handover', 'auto-handover')])

    def test_an_asleep_region_keeps_its_build_until_it_can_hand_over(self):
        group, host = self.built()
        host.work('stage', host.request_stage()['operation'])
        self.machine.pids = {77}
        self.machine.connections = lambda port: []
        host.write_json(host.freeze_file, {'pid': 77, 'frozen_at': 0})
        self.machine.up = {1720}
        self.machine.detached.clear()
        host.watch_step(None)
        self.assertTrue(host.frozen(), 'not stopped to install an unchecked build')
        self.assertFalse([argv for argv in self.machine.detached if argv[-2] == 'update'])

    def test_a_player_online_or_an_unsaved_world_holds_the_update(self):
        group, host = self.built()
        self.machine.up = {1720}
        host.write_json(host.activity_file, {'last_client': 100})  # someone played since the last save
        self.machine.clock = 200
        host.watch_step(None)
        self.assertEqual([], [argv for argv in self.machine.detached if argv[-2] == 'stage'], 'no save since the last player')
        self.assertEqual(0, sum(1 for argv, _ in self.machine.calls if argv[1:2] == ['fetch']), 'nothing fetched yet')

    def test_update_when_empty_off_leaves_the_old_behaviour(self):
        self.group['update_when_empty'] = False
        group, host = self.built()
        self.machine.up = {1720}
        idle, _ = host.watch_step(None)
        self.machine.clock += 5 * 60
        host.watch_step(idle)
        self.assertFalse([argv for argv in self.machine.detached if argv[-2] in ('stage', 'restart')])
        # The launcher's toggle rewrites the group config; the host reads it at the next check.
        self.group['update_when_empty'] = True
        self.write_group()
        host.watch_step(idle)
        self.assertEqual('stage', self.machine.detached[-1][-2])

    def test_the_remote_is_checked_at_most_every_update_check_minutes(self):
        self.group['update_check_minutes'] = 10
        self.group['fetch'] = 'origin'
        group, host = self.built()
        self.machine.revision = REVISION  # nothing new
        self.machine.up = {1720}
        fetches = lambda: sum(1 for argv, _ in self.machine.calls if argv[1:2] == ['fetch'])
        idle, _ = host.watch_step(None)
        first = fetches()
        self.assertGreater(first, 0)
        self.machine.clock += 9 * 60
        idle, _ = host.watch_step(idle)
        self.assertEqual(first, fetches())
        self.machine.clock += 60
        host.watch_step(idle)
        self.assertGreater(fetches(), first)

    def test_a_failed_update_build_is_not_retried_for_the_same_revision(self):
        group, host = self.built()
        self.machine.up = {1720}
        self.machine.compile_output = 'region.dmb - 1 errors, 0 warnings'
        idle, _ = host.watch_step(None)
        host.work('stage', self.machine.detached[-1][-1])
        self.assertEqual('failed', host.read_json(host.stage_file)['phase'])
        stages = len(self.machine.detached)
        self.machine.clock += 15 * 60
        host.watch_step(idle)
        self.assertEqual(stages, len(self.machine.detached), 'no rebuild of the same broken revision')

    def test_a_world_that_does_not_save_is_left_alone(self):
        group, host = self.built()
        self.machine.up = {1720}
        self.machine.query = lambda *args, **kwargs: {'ok': True, 'ready': True, 'busy': False, 'session': 'b' * 32,
                                                      'persistence_mode': 0}
        host.watch_step(None)
        self.assertFalse([argv for argv in self.machine.detached if argv[-2] in ('stage', 'restart')])

    def tdm_built(self, kind='BARRACKS', mainland=False):
        # A TDM group (Val, 2026-11-18): rounds never save, so an empty world just restarts.
        self.group['persistent'] = False
        self.group['regions'][0]['kind'] = kind
        self.group['regions'][1]['kind'] = 'BATTLE' if kind == 'BARRACKS' else 'BARRACKS'
        self.group['regions'][1]['map'] = 'maps/small/tiny.dmm'
        if kind == 'BATTLE':
            self.group['mainland'] = 'deep'
        elif not mainland:
            self.group['regions'].append({'id': 'main', 'name': 'Main', 'kind': 'SURFACE', 'port': 1722,
                                          'map': 'maps/small/tiny.dmm'})
            self.group['mainland'] = 'main'
        group, host = self.built()
        self.machine.up = {1720}
        self.machine.query = lambda *args, **kwargs: {'ok': True, 'ready': True, 'busy': False, 'session': 'b' * 32,
                                                      'persistence_mode': 0}
        run = self.machine.run

        def newer_is_not_older(argv, cwd=None, timeout=1800, low_priority=False):
            if argv[1:3] == ['merge-base', '--is-ancestor'] and argv[3:5] == [NEWER, REVISION]:
                return 1, ''
            return run(argv, cwd, timeout, low_priority)
        self.machine.run = newer_is_not_older
        return group, host

    def test_nonpersistent_mainland_does_not_automatically_restart_for_updates(self):
        group, host = self.tdm_built(mainland=True)
        host.work('stage', host.request_stage()['operation'])
        self.machine.detached.clear()
        idle, _ = host.watch_step(None)
        self.machine.clock += 15 * 60
        host.watch_step(idle)
        self.assertFalse([argv for argv in self.machine.detached if argv[-2] in ('restart', 'handover', 'auto-handover', 'update')])

    def test_a_tdm_barracks_waits_for_the_battle_to_take_the_update(self):
        # Val (2026-11-18): a restart per merge pinged Discord every few minutes; the barracks
        # updates once per round, after the battle has moved on.
        group, host = self.tdm_built()
        battle_head = [REVISION]
        run = self.machine.run

        def heads(argv, cwd=None, timeout=1800, low_priority=False):
            if argv[1:] == ['rev-parse', 'HEAD'] and cwd == self.base / 'regions' / 'deep':
                return 0, battle_head[0] + '\n'
            return run(argv, cwd, timeout, low_priority)
        self.machine.run = heads
        host.watch_step(None)
        self.machine.clock += 15 * 60
        host.watch_step(None)
        self.assertFalse([argv for argv in self.machine.detached if argv[-2] in ('stage', 'restart')],
                         'master moved, but the battle still runs the barracks build')
        battle_head[0] = NEWER  # the battle's round ended and it took the update
        host.watch_step(None)
        self.assertEqual('stage', self.machine.detached[-1][-2])

    def test_a_tdm_battle_in_pregame_is_never_handed_over(self):
        # Before its round is set up a world reports no persistence_mode, which reads as saving.
        group, host = self.tdm_built(kind='BATTLE')
        self.machine.query = lambda *args, **kwargs: {'ok': True, 'ready': True, 'busy': False, 'session': 'b' * 32,
                                                      'persistence_mode': None}
        host.work('stage', host.request_stage()['operation'])
        self.machine.detached.clear()
        for _ in range(3):
            self.machine.clock += 15 * 60
            host.watch_step(None)
        self.assertFalse([argv for argv in self.machine.detached if argv[-2] in ('stage', 'restart', 'handover')])

    def test_an_empty_tdm_barracks_restarts_onto_the_update(self):
        group, host = self.tdm_built()
        idle, wait = host.watch_step(None)
        self.assertEqual('stage', self.machine.detached[-1][-2], 'built beside the running world first')
        self.assertEqual(30, wait)
        host.work('stage', self.machine.detached[-1][-1])
        host.watch_step(idle)
        self.assertEqual('restart', self.machine.detached[-1][-2])
        self.assertFalse([argv for argv in self.machine.detached if argv[-2] == 'handover'], 'no save to hand over')

    def test_a_tdm_barracks_waits_while_the_battle_sends_players_back(self):
        group, host = self.tdm_built()
        host.work('stage', host.request_stage()['operation'])
        rotation = self.base / 'regions' / 'deep' / 'data' / 'shard-host' / 'rotation.json'
        rotation.parent.mkdir(parents=True, exist_ok=True)
        rotation.write_text(json.dumps({'state': 'building', 'map': 'karak'}))
        self.machine.detached.clear()
        host.watch_step(None)
        self.assertFalse([argv for argv in self.machine.detached if argv[-2] == 'restart'])
        rotation.write_text(json.dumps({'state': 'ready', 'map': 'karak'}))
        host.watch_step(None)
        self.assertEqual('restart', self.machine.detached[-1][-2])

    def test_a_failed_tdm_restart_is_not_retried_for_the_same_build(self):
        group, host = self.tdm_built()
        host.work('stage', host.request_stage()['operation'])
        host.watch_step(None)
        self.assertEqual('restart', self.machine.detached[-1][-2])
        host.lock.unlink(missing_ok=True)
        host.record(action='restart', phase='failed', error='the world did not start')
        self.machine.detached.clear()
        host.watch_step(None)
        self.assertFalse([argv for argv in self.machine.detached if argv[-2] == 'restart'])

    def test_a_tdm_battle_world_updates_only_between_rounds(self):
        group, host = self.tdm_built(kind='BATTLE')
        self.machine.detached.clear()
        host.watch_step(None)
        self.assertFalse([argv for argv in self.machine.detached if argv[-2] in ('stage', 'restart')],
                         'battle_mapswap.py takes the update when its round ends')

    def test_an_asleep_region_builds_the_update_and_wakes_on_it(self):
        group, host = self.built()
        self.machine.pids = {77}
        self.machine.connections = lambda port: []
        host.write_json(host.freeze_file, {'pid': 77, 'frozen_at': 0})
        self.machine.up = {1720}
        host.watch_step(None)
        self.assertEqual('stage', self.machine.detached[-1][-2])
        self.assertTrue(host.frozen(), 'building does not wake it')
        host.work('stage', self.machine.detached[-1][-1])
        self.assertTrue(host.update_pending())

    def test_update_when_empty_must_be_a_boolean(self):
        self.group['update_when_empty'] = 'yes'
        with self.assertRaisesRegex(ValueError, 'update_when_empty'):
            self.write_group()
        self.group['update_when_empty'] = True
        self.group['update_check_minutes'] = 0
        with self.assertRaisesRegex(ValueError, 'update_check_minutes'):
            self.write_group()

    def test_stage_reaches_every_region_from_the_command_line(self):
        group = self.write_group()
        shard_group.setup(group, self.machine)
        with mock.patch.object(shard_group, 'Platform', return_value=self.machine), \
                mock.patch.object(shard_group, 'RegionPlatform', return_value=self.machine), \
                mock.patch('sys.stdout', new_callable=io.StringIO) as out:
            code = shard_group.main(['--config', str(self.path), 'stage'])
        result = json.loads(out.getvalue())
        self.assertEqual((code, sorted(result['accepted'])), (0, ['deep', 'gaia']), result)


    def offline_group(self):
        """gaia runs, deep is stopped; both have a build of REVISION and NEWER is out."""
        group = self.write_group()
        shard_group.setup(group, self.machine)
        hosts = {name: self.host(group, name) for name in ('gaia', 'deep')}
        for host in hosts.values():
            host.log = lambda values: None
            host.work('update', host.request('update')['operation'])
        self.machine.revision = NEWER
        self.machine.up = {1720}
        return group, hosts

    def run_offline(self, *extra):
        with mock.patch.object(shard_group, 'Platform', return_value=self.machine), \
                mock.patch.object(shard_group, 'RegionPlatform', return_value=self.machine), \
                mock.patch('sys.stdout', new_callable=io.StringIO) as out:
            code = shard_group.main(['--config', str(self.path), 'update-offline'] + list(extra))
        return code, json.loads(out.getvalue())

    def test_update_offline_builds_and_installs_stopped_regions_and_leaves_running_ones(self):
        group, hosts = self.offline_group()
        code, result = self.run_offline()
        self.assertEqual((0, ['deep'], {'gaia': 'running'}), (code, sorted(result['accepted']), result['skipped']), result)
        self.assertEqual('stopped', result['accepted']['deep']['state'])
        gaia, deep = hosts['gaia'], hosts['deep']
        self.assertFalse(gaia.stage_lock.exists(), 'nothing is staged for the running region')
        self.assertEqual(1, len(self.machine.detached) - 2, 'one worker: the stopped region\'s stage')
        stage = self.machine.detached[-1]
        self.assertEqual(['--worker', 'stage'], stage[-3:-1])
        deep.work('stage', stage[-1])
        self.assertEqual(['--worker', 'update'], self.machine.detached[-1][-3:-1], 'the ready stage is installed')
        self.assertFalse(deep.install_marker.exists())
        self.assertEqual('installing', deep.read_json(deep.stage_file)['install'])
        deep.work('update', self.machine.detached[-1][-1])
        self.assertEqual((NEWER, True), (deep.built_revision(), deep.read_state().get('staged')), deep.read_state())
        self.assertEqual(1, self.compiles(self.base / 'regions' / 'deep'), 'installed by copying, not compiled again')
        self.assertEqual(REVISION, gaia.built_revision(), 'the running region keeps its build')
        self.assertEqual({1720}, self.machine.up)

    def test_update_offline_never_wakes_an_asleep_region_and_lets_the_host_install_it(self):
        group, hosts = self.offline_group()
        gaia = hosts['gaia']
        self.machine.pids = {77}
        gaia.write_json(gaia.freeze_file, {'pid': 77, 'frozen_at': 0})
        self.machine.up = {1720, 1721}  # deep runs this time
        code, result = self.run_offline()
        self.assertEqual((['gaia'], {'deep': 'running'}), (sorted(result['accepted']), result['skipped']), result)
        self.assertEqual('asleep', result['accepted']['gaia']['state'])
        self.assertTrue(gaia.frozen(), 'still asleep while it builds')
        self.assertTrue(gaia.install_marker.exists(), 'installed as soon as it is built, host service or not')
        self.machine.terminate = lambda pid, expect=None: (self.machine.pids.discard(pid), self.machine.up.discard(1720))
        gaia.work('stage', self.machine.detached[-1][-1])
        stage = gaia.read_json(gaia.stage_file)
        self.assertEqual(('ready', 'installing'), (stage['phase'], stage.get('install')), stage)
        self.assertEqual(['--worker', 'update'], self.machine.detached[-1][-3:-1])
        self.assertFalse(gaia.frozen(), 'stopped from its save, never woken')
        self.assertEqual('cold', gaia.status()['state'], 'it starts on the new build at its next wake')
        gaia.work('update', self.machine.detached[-1][-1])
        self.assertEqual(NEWER, gaia.built_revision())

    def test_update_on_an_asleep_region_builds_and_installs_it_without_waking_it(self):
        # Val (2026-11-13): asleep regions must be able to take the new update.
        group, host = StagedBuildTests.built(self)
        self.machine.pids = {77}
        self.machine.terminate = lambda pid, expect=None: (self.machine.pids.discard(pid), self.machine.up.discard(1720))
        host.write_json(host.freeze_file, {'pid': 77, 'frozen_at': 0})
        self.machine.up = {1720}
        answer = host.request('update')
        self.assertEqual(('stage', 'asleep'), (answer['action'], answer['state']), answer)
        self.assertTrue(host.frozen(), 'it sleeps (and can wake at once) while the update builds')
        host.work('stage', answer['operation'])
        self.assertEqual('update', self.machine.detached[-1][-2])
        host.work('update', self.machine.detached[-1][-1])
        self.assertEqual((NEWER, 'cold'), (host.built_revision(), host.status()['state']))

    def test_update_on_an_asleep_region_with_a_ready_build_installs_it_at_once(self):
        group, host = StagedBuildTests.built(self)
        host.work('stage', host.request_stage()['operation'])
        self.machine.pids = {77}
        self.machine.terminate = lambda pid, expect=None: (self.machine.pids.discard(pid), self.machine.up.discard(1720))
        host.write_json(host.freeze_file, {'pid': 77, 'frozen_at': 0})
        answer = host.request('update')
        self.assertEqual(('update', 'asleep'), (answer['action'], answer['state']), answer)
        self.assertFalse(host.frozen())
        host.work('update', answer['operation'])
        self.assertEqual(NEWER, host.built_revision())

    def test_update_offline_leaves_a_region_that_started_while_building(self):
        group, hosts = self.offline_group()
        deep = hosts['deep']
        code, result = self.run_offline('--region', 'deep')
        self.assertEqual(['deep'], sorted(result['accepted']))
        self.machine.up = {1720, 1721}  # someone started deep meanwhile
        deep.work('stage', self.machine.detached[-1][-1])
        self.assertEqual(['--worker', 'stage'], self.machine.detached[-1][-3:-1])
        self.assertIn('started while', deep.read_json(deep.stage_file)['install'])
        self.assertTrue(deep.update_pending(), 'it installs at its next empty restart instead')

    def test_update_offline_joins_a_stage_already_running_and_skips_busy_regions(self):
        group, hosts = self.offline_group()
        deep = hosts['deep']
        operation = deep.request_stage()['operation']
        self.machine.up = set()
        hosts['gaia'].lock.write_text('busy')
        hosts['gaia'].record(action='stop', operation='x', phase='saving')
        code, result = self.run_offline()
        self.assertEqual({'gaia': 'busy: stop'}, result['skipped'], result)
        self.assertTrue(result['accepted']['deep']['already_staging'])
        deep.work('stage', operation)
        self.assertEqual(['--worker', 'update'], self.machine.detached[-1][-3:-1], 'the running stage installs it')

    def test_update_offline_with_everything_running_changes_nothing(self):
        group, hosts = self.offline_group()
        self.machine.up = {1720, 1721}
        before = len(self.machine.detached)
        code, result = self.run_offline()
        self.assertEqual((0, {}, {'gaia': 'running', 'deep': 'running'}), (code, result['accepted'], result['skipped']))
        self.assertEqual(before, len(self.machine.detached))


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
                        'handover': world['handover'], 'handover_empty_guard': True, 'error': save_error if world['handover'] == 'saving' else None}
            if port == me.STANDBY:
                if action == 'standby_load':
                    standby.update(standby='loading', operation=operation)
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
                        'operation': standby.get('operation'), 'restart_hold': not ready, 'error': None}
            raise OSError('nothing listens on %d' % port)

        machine.query = query
        start_standby = machine.start_standby

        def boot(dmb, port):
            standby.update(standby=None, loading=0, operation=None)  # a fresh process
            machine.up.add(port)
            return start_standby(dmb, port)
        machine.start_standby = boot
        return group, host

    def empty_live_world(self):
        query = self.machine.query
        def empty(port, token, action='status', operation=None, session=None, extra=None):
            answer = query(port, token, action, operation, session, extra)
            return dict(answer, clients=0) if port == self.LIVE and action == 'status' else answer
        self.machine.query = empty

    def recover_current_build(self, host):
        self.machine.up.clear()
        before = host.read_state()
        accepted = host.request('start-current')
        if before.get('revision') == host.staged_revision() and not before.get('retryable'):
            self.assertEqual((host.read_json(host.failed_handover_file) or {}).get('revision'), before.get('revision'), before)
        with mock.patch.object(host, 'do_start'):
            host.work('start-current', accepted['operation'])
        self.assertEqual(host.read_state()['phase'], 'done')
        self.machine.up.add(self.LIVE)

    def test_automatic_handover_loads_the_standby_before_releasing_mainland(self):
        group, host = self.staged()
        self.empty_live_world()
        host.work('auto-handover', host.request('auto-handover')['operation'])
        self.assertEqual(host.read_state()['phase'], 'done', host.read_state())
        names = [action for _, action, _ in self.actions if action != 'status']
        self.assertEqual(names, ['handover_save', 'standby_load', 'handover_release', 'standby_open'])
        self.assertEqual([extra for _, action, extra in self.actions if action == 'handover_save'],
                         [{'only_if_empty': '1'}])

    def test_automatic_handover_late_save_refusal_defers(self):
        self.check_automatic_occupancy_refusal('handover_save')

    def test_automatic_handover_late_release_refusal_defers(self):
        self.check_automatic_occupancy_refusal('handover_release')

    def check_automatic_occupancy_refusal(self, refused_action):
        group, host = self.staged()
        self.empty_live_world()
        query = self.machine.query

        def late_arrival(port, token, action='status', operation=None, session=None, extra=None):
            if action == refused_action:
                if action == 'handover_save':
                    self.assertEqual(extra, {'only_if_empty': '1'})
                self.actions.append((port, action, extra))
                raise shard_group.gaia_host.LifecycleRefused('handover_players_arrived')
            return query(port, token, action, operation, session, extra)

        self.machine.query = late_arrival
        host.work('auto-handover', host.request('auto-handover')['operation'])
        state = host.read_state()
        self.assertEqual(state['phase'], 'failed', state)
        self.assertTrue(state.get('retryable'), state)
        self.assertFalse(host.failed_staged_handover())
        self.assertIn(self.LIVE, self.machine.up)
        self.assertNotIn(self.STANDBY, self.machine.up)
        names = [action for _, action, _ in self.actions if action != 'status']
        expected = ['handover_save', 'handover_cancel'] if refused_action == 'handover_save' else [
            'handover_save', 'standby_load', 'handover_release', 'handover_cancel']
        self.assertEqual(names, expected)

    def test_automatic_handover_failed_load_keeps_old_world(self):
        group, host = self.staged(load_error='invalid save')
        self.empty_live_world()
        host.work('auto-handover', host.request('auto-handover')['operation'])
        self.assertEqual(host.read_state()['phase'], 'failed')
        self.assertEqual(host.read_json(host.failed_handover_file)['revision'], NEWER)
        self.assertIn(self.LIVE, self.machine.up)
        self.assertFalse(any(action == 'handover_release' for _, action, _ in self.actions))
        self.recover_current_build(host)
        host = self.host(group, 'gaia')  # a new host process must see the same rejection
        self.assertTrue(host.failed_staged_handover())
        self.assertIsNone(host.idle_update_action())
        self.machine.detached.clear()
        host.watch_step(None)
        self.assertFalse([argv for argv in self.machine.detached if argv[-2] == 'auto-handover'])

        self.machine.revision = 'f' * 40
        host.work('stage', host.request_stage()['operation'])
        self.assertEqual(host.staged_revision(), 'f' * 40)
        self.assertFalse(host.failed_staged_handover())
        self.assertEqual(host.idle_update_action(), 'auto-handover')

    def test_automatic_handover_defers_if_player_arrives_before_lock(self):
        group, host = self.staged()
        accepted = host.request('auto-handover')
        host.work('auto-handover', accepted['operation'])
        self.assertEqual(host.read_state()['phase'], 'failed')
        self.assertIn('not confirmed empty', host.read_state()['error'])
        self.assertFalse(any(action == 'handover_save' for _, action, _ in self.actions))
        self.assertIn(self.LIVE, self.machine.up)
        self.recover_current_build(host)
        self.assertFalse(self.host(group, 'gaia').failed_staged_handover())

    def test_automatic_handover_failed_save_remains_rejected_after_recovery(self):
        group, host = self.staged(save_error='World save failed; server remains running')
        self.empty_live_world()
        host.work('auto-handover', host.request('auto-handover')['operation'])
        self.assertIn('World save failed', host.read_state()['error'])
        self.recover_current_build(host)
        self.assertTrue(self.host(group, 'gaia').failed_staged_handover())

    def test_manual_update_handover_failure_and_retry_survive_recovery(self):
        group, host = self.staged(load_error='invalid save')
        host.work('update-handover', host.request('update-handover')['operation'])
        self.assertEqual(host.read_state()['phase'], 'failed', host.read_state())
        self.assertIn('invalid save', host.read_state()['error'])
        self.assertTrue(host.failed_staged_handover())
        self.recover_current_build(host)
        host = self.host(group, 'gaia')
        self.assertTrue(host.failed_staged_handover())

        accepted = host.request('update-handover')
        self.assertTrue(host.failed_handover_file.exists())
        with mock.patch.object(host, 'do_handover') as handover:
            host.work('update-handover', accepted['operation'])
        handover.assert_called_once_with(accepted['operation'])
        self.assertEqual(host.read_state()['phase'], 'done')
        self.assertFalse(self.host(group, 'gaia').failed_staged_handover())

    def test_failed_manual_update_handover_retry_rejects_revision_again(self):
        group, host = self.staged(load_error='invalid save')
        self.empty_live_world()
        host.work('auto-handover', host.request('auto-handover')['operation'])
        self.recover_current_build(host)
        accepted = host.request('update-handover')
        self.assertTrue(host.failed_handover_file.exists())
        host.work('update-handover', accepted['operation'])
        self.assertEqual(host.read_state()['phase'], 'failed', host.read_state())
        self.assertTrue(host.failed_staged_handover())
        self.recover_current_build(host)
        self.assertTrue(self.host(group, 'gaia').failed_staged_handover())

    def test_early_manual_retry_failure_keeps_the_prior_rejection(self):
        group, host = self.staged()
        host.record(action='auto-handover', phase='failed', revision=NEWER, error='invalid save')
        self.recover_current_build(host)
        for action, step in (('handover', 'do_handover'), ('update-handover', 'wait_for_build')):
            with self.subTest(action=action):
                accepted = host.request(action)
                with mock.patch.object(host, step, side_effect=RuntimeError('early failure')):
                    host.work(action, accepted['operation'])
                self.assertEqual(host.read_state()['phase'], 'failed')
                self.assertNotIn('revision', host.read_state())
                self.assertTrue(self.host(group, 'gaia').failed_staged_handover())
                self.recover_current_build(host)
                self.assertTrue(self.host(group, 'gaia').failed_staged_handover())

    def test_concurrent_requests_serialize_rejection_preservation(self):
        import threading
        group, host = self.staged()
        host.record(action='auto-handover', phase='failed', revision=NEWER, error='invalid save')
        self.machine.up.clear()
        writing, release, second_finished = threading.Event(), threading.Event(), threading.Event()
        writes, outcomes = [], []
        real_write = host.write_json

        def blocked_write(path, value):
            if path == host.failed_handover_file:
                writes.append(value)
                writing.set()
                if not release.wait(5):
                    raise RuntimeError('test did not release the writer')
            return real_write(path, value)

        def request(finished=None):
            try:
                outcomes.append(host.request('start-current'))
            except Exception as error:
                outcomes.append(error)
            finally:
                if finished:
                    finished.set()

        with mock.patch.object(host, 'write_json', side_effect=blocked_write):
            first = threading.Thread(target=request)
            first.start()
            try:
                self.assertTrue(writing.wait(5), 'first request did not reach preservation')
                second = threading.Thread(target=request, args=(second_finished,))
                second.start()
                self.assertTrue(second_finished.wait(5), 'the competing request waited on the marker write')
            finally:
                release.set()
                first.join(5)
                if 'second' in locals():
                    second.join(5)
        self.assertEqual(len(writes), 1)
        self.assertEqual(sum(isinstance(result, shard_group.Refused) for result in outcomes), 1)
        accepted = next(result for result in outcomes if isinstance(result, dict))
        with mock.patch.object(host, 'do_start'):
            host.work('start-current', accepted['operation'])
        self.assertTrue(self.host(group, 'gaia').failed_staged_handover())

    def test_automatic_handover_defers_if_player_arrives_during_standby_boot(self):
        group, host = self.staged()
        query = self.machine.query
        def joining(port, token, action='status', operation=None, session=None, extra=None):
            answer = query(port, token, action, operation, session, extra)
            if port == self.LIVE and action == 'status' and self.STANDBY not in self.machine.up:
                answer['clients'] = 0
            return answer
        self.machine.query = joining
        host.work('auto-handover', host.request('auto-handover')['operation'])
        self.assertEqual(host.read_state()['phase'], 'failed')
        self.assertTrue(host.read_state()['retryable'])
        self.assertIn(self.LIVE, self.machine.up)
        self.assertNotIn(self.STANDBY, self.machine.up)
        self.assertFalse(any(action == 'handover_save' for _, action, _ in self.actions))
        self.recover_current_build(host)
        self.assertFalse(self.host(group, 'gaia').failed_staged_handover())

    def test_automatic_handover_never_uses_legacy_stop_and_start(self):
        group, host = self.staged()
        query = self.machine.query
        def legacy(port, token, action='status', operation=None, session=None, extra=None):
            result = query(port, token, action, operation, session, extra)
            if port == self.LIVE and action == 'status':
                result.pop('handover_empty_guard', None)
            return result
        self.machine.query = legacy
        with mock.patch.object(host, 'do_stop') as stop, mock.patch.object(host, 'do_update') as update:
            host.work('auto-handover', host.request('auto-handover')['operation'])
        self.assertEqual(host.read_state()['phase'], 'failed')
        self.assertIn('automatic update deferred', host.read_state()['error'])
        stop.assert_not_called()
        update.assert_not_called()
        self.assertEqual([a for _, a, _ in self.actions if a != 'status'], [])
        self.recover_current_build(host)
        host = self.host(group, 'gaia')
        self.assertTrue(host.failed_staged_handover())
        accepted = host.request('handover')  # an explicit manual retry is allowed
        with mock.patch.object(host, 'do_handover'):
            host.work('handover', accepted['operation'])
        self.assertEqual(host.read_state()['phase'], 'done')
        self.assertFalse(self.host(group, 'gaia').failed_staged_handover())

    def test_mainland_cold_wake_uses_recorded_build_without_refresh(self):
        group, host = self.staged()
        self.machine.up.clear()
        host.write_json(host.cold_file, {'frozen_at': 0})
        accepted = host.start_cold('player connection')
        self.assertEqual(accepted['action'], 'start-current')
        revisions = []
        with mock.patch.object(host, 'do_refresh') as refresh, mock.patch.object(host, 'do_start', side_effect=lambda op: revisions.append(host.startup_revision())):
            host.work('start-current', accepted['operation'])
        refresh.assert_not_called()
        self.assertEqual(revisions, [REVISION])
        self.assertEqual(host.read_state()['phase'], 'done')

    def test_mainland_cold_wake_refuses_a_changed_build(self):
        group, host = self.staged()
        self.machine.up.clear()
        host.write_json(host.cold_file, {'frozen_at': 0})
        host.dmb().write_bytes(b'changed')
        with self.assertRaisesRegex(shard_group.Refused, 'missing or changed'):
            host.start_cold('player connection')
        self.assertTrue(host.cold_file.exists())

    def test_mainland_watchdog_starts_the_recorded_build_without_refresh(self):
        group, host = self.staged()
        self.machine.up.clear()
        self.machine.detached.clear()
        host.watchdog_restart('crash', 'lost world')
        action, operation = self.machine.detached[-1][-2:]
        self.assertEqual(action, 'start-current')
        with mock.patch.object(host, 'do_refresh') as refresh, mock.patch.object(host, 'do_start') as start:
            host.work(action, operation)
        refresh.assert_not_called()
        start.assert_called_once_with(operation)
        self.assertEqual(host.read_state()['phase'], 'done')

    def test_non_mainland_automatic_start_keeps_existing_behavior(self):
        group, host = self.staged()
        self.group['mainland'] = 'deep'
        self.write_group()
        self.assertEqual(host.automatic_start_action(), 'start')

    def test_handover_warns_players_for_the_group_configs_current_warning(self):
        group, host = self.staged()
        path = Path(host.config['group_config'])
        data = json.loads(path.read_text())
        data['shutdown_warning_seconds'] = 45  # the launcher's Players' warning, changed after setup
        path.write_text(json.dumps(data))
        query = self.machine.query

        def offering(port, token, action='status', operation=None, session=None, extra=None):
            answer = query(port, token, action, operation, session, extra)
            return dict(answer, shutdown_warning=True) if port == self.LIVE and action == 'status' else answer
        self.machine.query = offering
        host.work('handover', host.request('handover')['operation'])
        self.assertEqual(host.read_state()['phase'], 'done', host.read_state())
        saves = [extra for _, action, extra in self.actions if action == 'handover_save']
        self.assertEqual(saves, [{'warn': '45'}])

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
        self.assertEqual(json.loads((live / 'config' / 'server-build.json').read_text())['revision'], NEWER)
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

    def test_a_standby_that_never_boots_is_stopped_and_the_world_keeps_running(self):
        # North America, 2026-11-16: a standby still preparing a large map timed
        # out and was left running, holding region.rsc against the next build.
        group, host = self.staged()
        query = self.machine.query
        started = []

        def silent(port, token, action='status', operation=None, session=None, extra=None):
            if port == self.STANDBY:
                raise OSError('busy preparing the map')
            return query(port, token, action, operation, session, extra)
        self.machine.query = silent
        host.work('handover', host.request('handover')['operation'])
        state = host.read_state()
        self.assertEqual(state['phase'], 'failed', state)
        self.assertIn('the standby world did not boot', state['error'])
        self.assertIn((['kill_tree', 200], None), self.machine.calls, 'the standby is stopped')
        self.assertIn(self.LIVE, self.machine.up, 'the old world keeps running')
        self.assertNotIn('handover_save', [action for _, action, _ in self.actions])
        self.assertTrue(host.update_pending())
        self.assertFalse(host.lock.exists())

    def test_the_standby_boot_waits_as_long_as_a_load(self):
        group, host = self.staged()
        host.config['start_timeout_seconds'], host.config['load_timeout_seconds'] = 300, 1800
        waits = []
        wait_world = host.wait_world

        def recording(port, token, done, timeout, what, standby=False):
            waits.append((what, timeout))
            return wait_world(port, token, done, timeout, what, standby)
        host.wait_world = recording
        host.work('handover', host.request('handover')['operation'])
        self.assertIn(('the standby world did not boot', 1800), waits)

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

    def test_the_backup_copies_while_the_standby_loads(self):
        # Val, 2026-11-13: copying the save before the load added about 23 s to the pause.
        import threading
        group, host = self.staged()
        query, real_copy = self.machine.query, shard_group.gaia_host.copy_save
        load_sent, seen = threading.Event(), []

        def loading(port, token, action='status', operation=None, session=None, extra=None):
            if action == 'standby_load':
                load_sent.set()
            return query(port, token, action, operation, session, extra)

        def copy_save(source, target):
            seen.append(load_sent.wait(5))  # the load is under way while the copy runs
            return real_copy(source, target)
        self.machine.query = loading
        shard_group.gaia_host.copy_save = copy_save
        try:
            accepted = host.request('handover')
            host.work('handover', accepted['operation'])
        finally:
            shard_group.gaia_host.copy_save = real_copy
        self.assertEqual(seen, [True])
        self.assertEqual(host.read_state()['phase'], 'done', host.read_state())
        self.assertTrue((Path(host.config['state_dir']) / 'backups' / accepted['operation'] / '1.sav').exists())

    def test_a_failed_backup_stops_the_handover_before_the_switch(self):
        group, host = self.staged()
        real_copy = shard_group.gaia_host.copy_save

        def broken(source, target):
            raise OSError('disk full')
        shard_group.gaia_host.copy_save = broken
        try:
            host.work('handover', host.request('handover')['operation'])
        finally:
            shard_group.gaia_host.copy_save = real_copy
        state = host.read_state()
        self.assertEqual(state['phase'], 'failed', state)
        self.assertIn('could not be backed up: disk full', state['error'])
        names = [action for _, action, _ in self.actions if action != 'status']
        self.assertEqual(names, ['handover_save', 'standby_load', 'handover_cancel'])
        self.assertIn(self.LIVE, self.machine.up, 'the old world keeps running')
        self.assertNotIn(self.STANDBY, self.machine.up)

    def force_stop_on(self, host, trigger):
        """Script a person's Force stop that lands when the handover sends trigger; a world
        that is gone refuses connections as on Windows (WinError 10061)."""
        query = self.machine.query
        stopped = []

        def stopping(port, token, action='status', operation=None, session=None, extra=None):
            if port not in self.machine.up:
                raise ConnectionRefusedError(10061, 'No connection could be made because the target machine actively refused it')
            answer = query(port, token, action, operation, session, extra)
            if action == trigger and not stopped:
                stopped.append(host.kill())
            return answer
        self.machine.query = stopping
        return stopped

    def test_a_force_stop_during_the_save_ends_the_handover_and_the_region_stays_down(self):
        # 2026-11-13: Europe and Desert were force-stopped mid-handover and reported only
        # "[WinError 10061] ... actively refused it".
        group, host = self.staged()
        stopped = self.force_stop_on(host, 'handover_save')
        host.work('handover', host.request('handover')['operation'])
        state = host.read_state()
        self.assertEqual(len(stopped), 1)
        self.assertEqual((state['phase'], state.get('reason')), ('killed', 'forced stop'), state)
        self.assertIn('forced stop during handover', state['error'])
        self.assertIn((['kill_tree', 200], None), self.machine.calls, 'the standby is stopped')
        self.assertEqual(self.machine.up, set())
        self.assertFalse(host.running_file.exists(), 'the watchdog leaves it down')
        self.assertEqual(host.built_revision(), REVISION)
        self.assertFalse(host.lock.exists())
        self.assertFalse(host.killed_file.exists())

    def test_a_force_stop_after_the_release_never_lets_the_standby_open_the_region(self):
        group, host = self.staged()
        host.mark_running()
        stopped = self.force_stop_on(host, 'handover_release')
        host.work('handover', host.request('handover')['operation'])
        state = host.read_state()
        self.assertEqual(len(stopped), 1)
        self.assertEqual(state['phase'], 'killed', state)
        names = [action for _, action, _ in self.actions if action != 'status']
        self.assertNotIn('standby_open', names)
        self.assertIn((['kill_tree', 200], None), self.machine.calls)
        self.assertEqual(self.machine.up, set(), 'neither world runs')
        self.assertFalse(host.running_file.exists(), 'the watchdog leaves it down')
        self.assertEqual(host.built_revision(), REVISION)

    def late(self, trigger, times=1, taken=True):
        """trigger gets no reply in time (a big map's world past the 15 s reply), times over;
        taken: the world still did what it asked."""
        query = self.machine.query
        late = []

        def slow(port, token, action='status', operation=None, session=None, extra=None):
            if action == trigger and len(late) < times:
                late.append(action)
                if taken:
                    query(port, token, action, operation, session, extra)
                raise TimeoutError('timed out')
            return query(port, token, action, operation, session, extra)
        self.machine.query = slow
        return late

    def test_a_standby_load_answered_late_is_not_a_failed_handover(self):
        # Earth Europe, 2026-11-18: standby_load timed out at 15 s while the standby opened the save.
        group, host = self.staged()
        late = self.late('standby_load')
        host.work('handover', host.request('handover')['operation'])
        state = host.read_state()
        self.assertEqual((state['phase'], state.get('error')), ('done', None), state)
        self.assertEqual(late, ['standby_load'])
        names = [action for _, action, _ in self.actions if action != 'status']
        self.assertEqual(names, ['handover_save', 'standby_load', 'handover_release', 'standby_open'], 'sent once')
        self.assertIn(self.LIVE, self.machine.up)

    def test_a_standby_load_that_was_not_taken_is_sent_again(self):
        group, host = self.staged()
        self.late('standby_load', taken=False)
        host.work('handover', host.request('handover')['operation'])
        state = host.read_state()
        self.assertEqual((state['phase'], state.get('error')), ('done', None), state)
        names = [action for _, action, _ in self.actions if action != 'status']
        self.assertEqual(names, ['handover_save', 'standby_load', 'handover_release', 'standby_open'])

    def test_a_handover_release_answered_late_still_switches(self):
        # Oceania and Antarctica, 2026-11-18: handover_release timed out and left a loaded standby running.
        group, host = self.staged()
        self.late('handover_release')
        host.work('handover', host.request('handover')['operation'])
        state = host.read_state()
        self.assertEqual((state['phase'], state.get('error')), ('done', None), state)
        self.assertIn(self.LIVE, self.machine.up, 'the new world answers on the region port')

    def test_a_handover_release_not_taken_is_sent_again(self):
        group, host = self.staged()
        self.late('handover_release', taken=False)
        host.work('handover', host.request('handover')['operation'])
        state = host.read_state()
        self.assertEqual((state['phase'], state.get('error')), ('done', None), state)
        names = [action for _, action, _ in self.actions if action != 'status']
        self.assertEqual(names, ['handover_save', 'standby_load', 'handover_release', 'standby_open'])

    def test_a_release_that_never_answers_stops_the_standby(self):
        group, host = self.staged()
        self.late('handover_release', times=10 ** 6, taken=False)
        host.work('handover', host.request('handover')['operation'])
        state = host.read_state()
        self.assertEqual(state['phase'], 'failed', state)
        self.assertIn('handover_release', state['error'])
        self.assertIn((['kill_tree', 200], None), self.machine.calls, 'the loaded standby is stopped')
        names = [action for _, action, _ in self.actions if action != 'status']
        self.assertEqual(names[-1], 'handover_cancel', 'the old world resumes')
        self.assertIn(self.LIVE, self.machine.up, 'the old world stays the region')

    def test_a_forced_handover_is_not_counted_as_a_failed_build(self):
        group, host = self.staged()
        self.force_stop_on(host, 'handover_save')
        host.work('handover', host.request('handover')['operation'])
        self.assertNotEqual(host.read_state().get('phase'), 'failed')
        self.assertTrue(host.update_pending(), 'the staged build is installed by the next start')

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
        # 2026-11-09: a full drive failed Gaia's handover at "copying the staged build".
        self.machine.free_disk = 33
        with self.assertRaisesRegex(shard_group.Refused, 'MB free on the disk'):
            host.request('handover')
        with self.assertRaisesRegex(shard_group.Refused, 'MB free on the disk'):
            host.request_stage()
        host.config['min_free_disk_mb'] = 0  # 0 turns the check off
        self.assertTrue(host.request_stage()['accepted'])
        host.stage_lock.unlink()
        host.config['min_free_disk_mb'] = shard_group.DEFAULT_MIN_FREE_DISK_MB
        self.machine.free_disk = None
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


class SaveValidatorTests(unittest.TestCase):
    """The outside save validator (ensure_save_validation) and its record hand-back."""

    GENERATION = 'round-v2:' + 'a' * 32

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        self.group = {'group': 'europe', 'root': str(self.base / 'regions'), 'daemon': 'DreamDaemon',
                      'regions': [{'id': 'gaia', 'port': 1720}, {'id': 'deep', 'port': 1721}],
                      'transfers': False}
        self.region = self.base / 'regions' / 'gaia'
        self.saves = self.region / 'map_saves'
        self.saves.mkdir(parents=True)
        for name, body in (('map.txt', 'meta'), ('round.json', '{}'), ('1.sav', 'level one'), ('1.stream.sav', 'stream')):
            (self.saves / name).write_text(body)
        (self.saves / 'save_complete.txt').write_text(self.GENERATION + '\n')
        (self.region / 'region.dmb').write_bytes(b'dmb')
        (self.region / 'region.rsc').write_bytes(b'rsc')
        (self.region / 'libsavestream.so').write_bytes(b'shim')
        (self.region / 'config').mkdir()
        (self.region / 'config' / 'config.txt').write_text('SERVER_NAME x\n')
        (self.region / 'config' / 'lifecycle-token.txt').write_text('secret\n')
        self.started, self.alive, self.clock = [], set(), [1000.0]

    def tearDown(self):
        self.tmp.cleanup()

    def config(self):
        return {**self.group, '_path': str(self.base / 'group.json')}

    def step(self, free=None):
        def start(argv, cwd, log):
            self.started.append((argv, Path(cwd)))
            self.alive.add(77)
            return 77
        with mock.patch.object(shard_group, 'region_config', lambda group, region: {'state_dir': str(self.base / 'regions' / region['id'] / 'data' / 'shard-host')}):
            return shard_group.ensure_save_validation(self.config(), start, free_mb=lambda: free,
                                                      now=lambda: self.clock[0], alive=lambda pid: pid in self.alive,
                                                      terminate=lambda pid, expect=None: self.alive.discard(pid))

    def finish_validator(self, ok=True, files=None):
        """What the validate-only world leaves behind."""
        folder = self.started[-1][1]
        sums = files or {name: shard_group.file_md5(folder / 'map_saves' / name) for name in ('map.txt', 'round.json', '1.sav', '1.stream.sav')}
        record = {'version': 2, 'kind': 'full', 'generation': self.GENERATION, 'files': sums, 'roofs': []}
        if ok:
            (folder / 'map_saves' / 'validated.json').write_text(json.dumps(record))
        (folder / 'validation_result.json').write_text(json.dumps({'ok': 1 if ok else 0, 'full': 1 if ok else 0, 'error': None if ok else 'Missing saved z-level 2'}))
        self.alive.discard(77)

    def test_validates_a_new_save_in_a_private_copy_and_hands_the_record_back(self):
        self.assertEqual({'save_validation': {'gaia': 'started'}}, self.step())
        argv, folder = self.started[0]
        self.assertIn('validate_save=1', argv)
        self.assertEqual('region.dmb', argv[argv.index('DreamDaemon') + 1])
        self.assertTrue((folder / 'map_saves' / '1.stream.sav').exists())
        self.assertTrue((folder / 'region.rsc').exists() and (folder / 'libsavestream.so').exists())
        self.assertTrue((folder / 'config' / 'config.txt').exists())
        self.assertFalse((folder / 'config' / 'lifecycle-token.txt').exists())
        self.assertEqual({}, self.step())  # still running
        self.finish_validator()
        self.assertEqual({'save_validation': {'gaia': 'validated'}}, self.step())
        self.assertEqual('full', json.loads((self.saves / 'validated.json').read_text())['kind'])
        self.assertFalse(folder.exists())
        self.assertEqual({}, self.step())  # nothing left to check

    def test_a_save_that_changed_meanwhile_gets_no_record(self):
        self.step()
        (self.saves / '1.sav').write_text('a newer level one')
        self.finish_validator()
        self.assertEqual({'save_validation': {'gaia': 'superseded'}}, self.step())
        self.assertFalse((self.saves / 'validated.json').exists())

    def test_a_failed_check_is_not_retried_until_the_next_save(self):
        self.step()
        self.finish_validator(ok=False)
        result = self.step()
        self.assertIn('failed', result['save_validation']['gaia'])
        self.assertFalse((self.saves / 'validated.json').exists())
        self.assertEqual({}, self.step())
        (self.saves / 'save_complete.txt').write_text('round-v2:' + 'b' * 32 + '\n')
        self.assertEqual({'save_validation': {'gaia': 'started'}}, self.step())

    def test_waits_for_memory_a_pending_restart_and_an_existing_record(self):
        self.assertEqual({}, self.step(free=1000))
        (self.saves / 'restart_intent.json').write_text('{}')
        self.assertEqual({}, self.step())
        (self.saves / 'restart_intent.json').unlink()
        (self.saves / 'validated.json').write_text(json.dumps({'kind': 'full', 'generation': self.GENERATION}))
        self.assertEqual({}, self.step())
        self.group['save_validator'] = False
        (self.saves / 'validated.json').unlink()
        self.assertEqual({}, self.step())
        self.assertEqual([], self.started)

    def test_a_hung_validator_is_ended(self):
        self.step()
        self.clock[0] += shard_group.VALIDATOR_TIMEOUT_SECONDS + 1
        self.assertEqual({'save_validation': {'gaia': 'failed: timed out'}}, self.step())
        self.assertNotIn(77, self.alive)


class UpdateWithoutSaveTests(unittest.TestCase):
    """update-unsaved (launcher Update and restart without saving, and admins in game): the update
    is built beside the running world, then the world is ended without a save, its last completed
    save is backed up and the new build starts from it. A failed build never stops the world, and
    a region that is not running is never started."""
    setUp = ShardGroupTests.setUp
    tearDown = ShardGroupTests.tearDown
    write_group = ShardGroupTests.write_group
    host = ShardGroupTests.host
    built = StagedBuildTests.built
    write_save = HandoverTests.write_save
    MARKER = HandoverTests.MARKER
    LIVE = 1720

    def running(self):
        group, host = self.built()
        self.machine.up = {self.LIVE}
        self.machine.pids_by_port = {self.LIVE: 100}
        self.write_save(Path(host.config['repository']) / 'map_saves')
        start = self.machine.start_task

        def start_task(name, dmb='region.dmb'):
            self.machine.up.add(self.LIVE)
            return start(name, dmb)
        self.machine.start_task = start_task
        sleep = self.machine.sleep

        def build_while_waiting(seconds):
            # The stage worker the action started runs while the action waits for it.
            if host.stage_lock.exists():
                host.work('stage', host.stage_lock.read_text().strip())
            sleep(seconds)
        self.machine.sleep = build_while_waiting
        return group, host

    def test_builds_first_then_restarts_on_the_update_without_a_save_and_keeps_a_backup(self):
        group, host = self.running()
        accepted = host.request('update-unsaved')
        self.assertEqual(['--worker', 'update-unsaved', accepted['operation']], self.machine.detached[-1][-3:])
        host.work('update-unsaved', accepted['operation'])
        state = host.read_state()
        self.assertEqual(('done', NEWER), (state['phase'], host.built_revision()), state)
        commands = [call[0] for call in self.machine.calls]
        staged_compile = next(i for i, (argv, where) in enumerate(self.machine.calls)
                              if argv[-1] == 'region.dme' and '.staging' in where)
        self.assertLess(staged_compile, commands.index(['kill_tree', 100]), 'built before the world is ended')
        self.assertEqual('start', commands[-1][0])
        backup = Path(state['backup'])
        self.assertEqual(self.MARKER, (backup / 'save_complete.txt').read_text())
        self.assertTrue((backup / 'backup-receipt.json').exists())
        saves = Path(host.config['repository']) / 'map_saves'
        self.assertEqual(self.MARKER, (saves / 'save_complete.txt').read_text(), 'the save is never wiped')
        self.assertIn(self.LIVE, self.machine.up)

    def test_a_failed_build_leaves_the_world_running(self):
        group, host = self.running()
        self.machine.compile_output = 'region.dmb - 1 errors, 0 warnings'
        host.work('update-unsaved', host.request('update-unsaved')['operation'])
        state = host.read_state()
        self.assertEqual('failed', state['phase'])
        self.assertIn('left running', state['error'])
        self.assertNotIn((['kill_tree', 100], None), self.machine.calls)
        self.assertIn(self.LIVE, self.machine.up)

    def test_a_person_force_stopping_it_while_it_builds_keeps_it_down(self):
        group, host = self.running()
        build = self.machine.sleep

        def person_stops_it(seconds):
            if self.LIVE in self.machine.up:
                host.kill()  # Force stop from the launcher while the update builds
            build(seconds)
        self.machine.sleep = person_stops_it
        host.work('update-unsaved', host.request('update-unsaved')['operation'])
        state = host.read_state()
        self.assertEqual('killed', state['phase'], state)
        self.assertNotIn(self.LIVE, self.machine.up)
        self.assertFalse([argv for argv, _ in self.machine.calls if argv[0] == 'start'])

    def test_a_stopped_region_is_refused_and_never_started(self):
        group, host = self.built()
        with self.assertRaisesRegex(shard_group.Refused, 'not running'):
            host.request('update-unsaved')
        self.assertFalse(host.lock.exists())

    def test_an_asleep_region_is_refused(self):
        group, host = self.built()
        self.machine.up = {self.LIVE}
        self.machine.pids = {77}
        host.write_json(host.freeze_file, {'pid': 77, 'frozen_at': 0})
        with self.assertRaisesRegex(shard_group.Refused, 'asleep'):
            host.request('update-unsaved')
        self.assertTrue(host.frozen(), 'not woken')

    def test_every_region_from_the_command_line_skips_the_stopped_ones(self):
        group, host = self.running()
        with mock.patch.object(shard_group, 'Platform', return_value=self.machine), \
                mock.patch.object(shard_group, 'RegionPlatform', return_value=self.machine), \
                mock.patch('sys.stdout', new_callable=io.StringIO) as out:
            code = shard_group.main(['--config', str(self.path), 'update-unsaved'])
        result = json.loads(out.getvalue())
        self.assertEqual((0, ['gaia'], ['deep']), (code, sorted(result['accepted']), sorted(result['refused'])), result)
        self.assertIn('not running', result['refused']['deep'])


class WorldRequestTests(unittest.TestCase):
    """Admins in game ask the host service for its actions through data/host_request.json."""
    setUp = ShardGroupTests.setUp
    tearDown = ShardGroupTests.tearDown
    write_group = ShardGroupTests.write_group
    host = ShardGroupTests.host
    built = StagedBuildTests.built
    running = UpdateWithoutSaveTests.running
    write_save = HandoverTests.write_save
    MARKER = HandoverTests.MARKER
    LIVE = 1720

    def ask(self, host, action):
        data = Path(host.config['repository']) / 'data'
        data.mkdir(exist_ok=True)
        (data / 'host_request.json').write_text(json.dumps({'id': 'abc123', 'action': action, 'by': 'someadmin'}))
        host.serve_world()
        self.assertFalse((data / 'host_request.json').exists(), 'a request is taken once')
        return json.loads((data / 'host_reply.json').read_text())

    def test_update_without_saving_from_the_world_starts_the_worker(self):
        group, host = self.running()
        host.log = lambda values: None
        reply = self.ask(host, 'update-unsaved')
        self.assertEqual(('abc123', True), (reply['id'], reply['ok']), reply)
        self.assertEqual('update-unsaved', self.machine.detached[-1][-2])
        status = json.loads((Path(host.config['repository']) / 'data' / 'host_status.json').read_text())
        self.assertTrue(status['busy'])
        self.assertEqual('gaia', status['region'])

    def test_save_update_and_restart_from_the_world_hands_over(self):
        group, host = self.running()
        host.log = lambda values: None
        reply = self.ask(host, 'update-handover')
        self.assertTrue(reply['ok'], reply)
        self.assertEqual('update-handover', self.machine.detached[-1][-2])

    def test_only_listed_actions_are_taken(self):
        group, host = self.running()
        host.log = lambda values: None
        workers = len(self.machine.detached)
        for action in ('kill', 'stop', 'fresh-world', None):
            reply = self.ask(host, action)
            self.assertFalse(reply['ok'], reply)
        self.assertFalse(host.lock.exists())
        self.assertEqual(workers, len(self.machine.detached), 'no worker started')

    def test_update_when_empty_toggle_writes_the_group_config(self):
        group, host = self.running()
        host.log = lambda values: None
        self.assertTrue(self.ask(host, 'update-when-empty-off')['ok'])
        self.assertFalse(json.loads(self.path.read_text())['update_when_empty'])
        self.assertFalse(host.update_when_empty())
        self.assertTrue(self.ask(host, 'update-when-empty-on')['ok'])
        saved = json.loads(self.path.read_text())
        self.assertTrue(saved['update_when_empty'])
        self.assertEqual('origin', saved['fetch'])

    def test_a_busy_host_answers_refused(self):
        group, host = self.running()
        host.log = lambda values: None
        host.request('update-unsaved')
        reply = self.ask(host, 'update-handover')
        self.assertFalse(reply['ok'])
        self.assertIn('still running', reply['result'])

    def test_a_stopped_world_is_not_served(self):
        group, host = self.built()
        data = Path(host.config['repository']) / 'data'
        data.mkdir(exist_ok=True)
        (data / 'host_request.json').write_text(json.dumps({'id': 'x', 'action': 'update-unsaved'}))
        host.serve_world()
        self.assertTrue((data / 'host_request.json').exists())


class AgentRunsTests(unittest.TestCase):
    """shard_group.py agents (agent_runs.py): the launcher's AI characters window."""

    def setUp(self):
        self.agent_runs = shard_group.agent_runs
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.logs = Path(self.tmp.name)
        script = r'D:\GitHub\Civ13-ada-tools\tools\agent-control\autopilot.py'
        self.watcher = {'pid': 100, 'ppid': 1, 'started': '', 'cmd': 'python.exe -u %s --watch --log-dir %s' % (script, self.logs)}
        self.run = {'pid': 200, 'ppid': 100, 'started': '', 'cmd': 'python.exe -u %s --character [0x3000135] --goal Survive' % script}
        self.other = {'pid': 300, 'ppid': 1, 'started': '', 'cmd': 'python.exe relay.py'}
        (self.logs / 'Ada-0x3000135.log').write_text(
            'step 33: routine work: make axe (score 0.25, NEEDS: safety 100, thirst 98 | priorities: x)\nstep 34: bind_axe\n')

    def test_status_lists_watchers_runs_logs_and_stalls(self):
        processes = [self.watcher, self.run, self.other]
        result = self.agent_runs.status(processes, now=time.time() + 900)
        watcher = result['watchers'][0]
        self.assertEqual(watcher['pid'], 100)
        self.assertFalse(watcher['restartable'])  # no watcher.json from this pid
        run = watcher['runs'][0]
        self.assertEqual((run['pid'], run['character']), (200, '[0x3000135]'))
        self.assertTrue(run['stalled'])
        self.assertEqual(run['needs'], 'safety 100, thirst 98')
        self.assertIn('STALLED', result['text'])
        self.assertEqual(self.agent_runs.status([], now=0)['text'].strip(), 'No AI character watcher is running on this host.')

    def test_stop_run_kills_only_autopilot_runs(self):
        killed = []
        processes = [self.watcher, self.run, self.other]
        self.assertFalse(self.agent_runs.stop_run(300, processes, killed.append)['ok'])
        self.assertFalse(self.agent_runs.stop_run(100, processes, killed.append)['ok'])  # a watcher is not a run
        self.assertTrue(self.agent_runs.stop_run(200, processes, killed.append)['ok'])
        self.assertEqual(killed, [200])

    def test_restart_needs_the_watchers_own_record_and_no_raw_token(self):
        processes = [self.watcher, self.run]
        self.assertFalse(self.agent_runs.restart_watcher(100, processes, launch=lambda r, d: 1)['ok'])
        record = {'pid': 100, 'python': 'python.exe', 'argv': ['autopilot.py', '--watch'], 'cwd': '', 'env': {}, 'pause_file': '',
                  'token_in_env': True}
        (self.logs / 'watcher.json').write_text(json.dumps(record))
        self.assertFalse(self.agent_runs.restart_watcher(100, processes, launch=lambda r, d: 1)['ok'])
        record['token_in_env'] = False
        (self.logs / 'watcher.json').write_text(json.dumps(record))
        killed, launched = [], []
        with mock.patch.object(self.agent_runs, 'alive', lambda pid, procs: pid in (100, 200) and pid not in killed):
            result = self.agent_runs.restart_watcher(100, processes, killer=killed.append,
                                                     launch=lambda r, d: launched.append((r['argv'], d)) or 555)
        self.assertTrue(result['ok'])
        self.assertEqual(killed, [200, 100])
        self.assertEqual(result['pid'], 555)
        self.assertEqual(launched[0][0], ['autopilot.py', '--watch'])


class ChatTranslatorTests(unittest.TestCase):
    """The host service keeps the Edge chat translator (tools/edge-translator) running and
    gives every region its address; the launcher's Translator tab stops and starts it."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        source = self.base / 'repo' / 'tools' / 'edge-translator'
        source.mkdir(parents=True)
        for name in shard_group.TRANSLATOR_FILES:
            (source / name).write_text('// ' + name + '\n')
        self.group = {'group': 'europe', 'repository': str(self.base / 'repo'), 'root': str(self.base / 'regions'),
                      'compiler': 'DreamMaker', 'daemon': 'DreamDaemon', 'git': 'git', 'public_host': '203.0.113.5',
                      'python': 'python.exe', 'chat_translator': {},
                      'regions': [{'id': 'gaia', 'name': 'Gaia', 'kind': 'SURFACE', 'port': 1720, 'map': 'maps/a.dmm'}]}
        self.alive = set()
        patcher = mock.patch.object(shard_group, 'process_alive', lambda pid: pid in self.alive)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.installs = []

    def tearDown(self):
        self.tmp.cleanup()

    def load(self):
        path = self.base / 'group.json'
        path.write_text(json.dumps(self.group))
        return shard_group.load_group(path)

    def npm(self, argv, cwd):
        self.installs.append((argv, Path(cwd)))
        (Path(cwd) / 'node_modules' / 'playwright-core').mkdir(parents=True, exist_ok=True)
        (Path(cwd) / 'node_modules' / 'playwright-core' / 'package.json').write_text('{}')
        return 0

    def test_config_validation_and_defaults(self):
        settings = self.load()['chat_translator']
        self.assertEqual(55581, settings['port'])
        self.assertEqual('node', settings['node'])
        for bad in ({'port': 80}, {'port': '55581'}, {'node': ''}, {'profile': 5}, 'yes'):
            self.group['chat_translator'] = bad
            with self.assertRaisesRegex(ValueError, 'chat_translator'):
                self.load()

    def test_install_copies_files_and_runs_npm_ci_only_when_needed(self):
        group = self.load()
        app = shard_group.install_translator(group, run=self.npm)
        self.assertEqual(self.base / 'regions' / 'chat-translator' / 'app', app)
        self.assertEqual(['ci', '--ignore-scripts', '--no-audit', '--no-fund'], self.installs[0][0][1:])
        shard_group.install_translator(group, run=self.npm)
        self.assertEqual(1, len(self.installs), 'nothing changed: no second npm ci')
        (self.base / 'repo' / 'tools' / 'edge-translator' / 'edge_translator.js').write_text('// new\n')
        shard_group.install_translator(group, run=self.npm)
        self.assertEqual('// new\n', (app / 'edge_translator.js').read_text())
        self.assertEqual(1, len(self.installs), 'a script change needs no npm ci')
        (self.base / 'repo' / 'tools' / 'edge-translator' / 'package-lock.json').write_text('// bumped\n')
        shard_group.install_translator(group, run=self.npm)
        self.assertEqual(2, len(self.installs), 'a lock change does')
        with self.assertRaisesRegex(OSError, 'npm ci failed'):
            (self.base / 'repo' / 'tools' / 'edge-translator' / 'package-lock.json').write_text('// again\n')
            shard_group.install_translator(group, run=lambda argv, cwd: 1)

    def test_supervise_keeps_it_running_until_stopped(self):
        group = self.load()
        started = []
        def start(argv, cwd, log):
            started.append((argv, Path(cwd), Path(log)))
            return 900 + len(started)
        real = shard_group.install_translator
        install = lambda g, run=None: real(g, run=self.npm)
        with mock.patch.object(shard_group, 'install_translator', install):
            self.assertTrue(shard_group.supervise(group, start)['chat_translator'])
            argv, cwd, log = started[0]
            folder = self.base / 'regions' / 'chat-translator'
            self.assertEqual(['node', str(folder / 'app' / 'edge_translator.js'), '--port', '55581', '--profile', str(folder / 'edge-profile')], argv)
            self.assertEqual(folder / 'service.log', log)
            self.alive.add(901)
            self.assertNotIn('chat_translator', shard_group.supervise(group, start))
            self.alive.discard(901)  # it exited: started again
            self.assertTrue(shard_group.supervise(group, start)['chat_translator'])
            self.alive.add(902)
            killed = []
            def kill(pid, expect=None):
                killed.append((pid, expect.images))
                self.alive.discard(pid)
            self.assertEqual({'stopped': True}, shard_group.translator_stop(group, kill=kill))
            self.assertEqual([(902, ('node.exe', 'node'))], killed, 'only a Node process is ended')
            self.assertNotIn('chat_translator', shard_group.supervise(group, start), 'stopped on request stays stopped')
            self.assertEqual(3 - 1, len(started))
            self.assertEqual({'started': True}, shard_group.translator_start(group, start))

    def test_install_failure_keeps_the_other_helpers_going(self):
        group = self.load()
        with mock.patch.object(shard_group, 'install_translator', side_effect=OSError('npm ci failed in x')):
            started = shard_group.supervise(group, lambda argv, cwd, log: 1)
        self.assertIn('npm ci failed', started['chat_translator_error'])

    def test_status(self):
        group = self.load()
        self.assertEqual({'configured': False}, shard_group.translator_status(dict(group, chat_translator=None)))
        status = shard_group.translator_status(group)
        self.assertEqual((True, False, False, 55581), (status['configured'], status['running'], status['answering'], status['port']))
        folder = self.base / 'regions' / 'chat-translator'
        folder.mkdir(parents=True)
        (folder / 'service.pid').write_text('77\n')
        self.alive.add(77)
        with mock.patch.object(shard_group, 'translator_health', return_value={'ok': True, 'translated': 4, 'failed': 0, 'waiting': 1}):
            status = shard_group.translator_status(group)
        self.assertEqual((True, True, 77), (status['running'], status['answering'], status['pid']))
        self.assertEqual({'translated': 4, 'failed': 0, 'waiting': 1}, status['stats'])

    def test_every_region_gets_the_address_unless_its_host_lines_say_otherwise(self):
        group = self.load()
        region = group['regions'][0]
        path = self.base / 'worktree'
        (path / 'config').mkdir(parents=True)
        (path / 'config' / 'config.txt').write_text('A 1\n#CHAT_TRANSLATE_URL http://127.0.0.1:55581\n')
        shard_group.apply_overlays(group, region, path)
        self.assertIn('CHAT_TRANSLATE_URL http://127.0.0.1:55581', (path / 'config' / 'config.txt').read_text().splitlines())
        overlay = self.base / 'overlay'
        (overlay / 'config').mkdir(parents=True)
        (overlay / 'config' / 'config.local.txt').write_text('#CHAT_TRANSLATE_URL\n')
        region['overlay'] = str(overlay)
        (path / 'config' / 'config.txt').write_text('A 1\n#CHAT_TRANSLATE_URL http://127.0.0.1:55581\n')
        shard_group.apply_overlays(group, region, path)
        self.assertNotIn('CHAT_TRANSLATE_URL http://127.0.0.1:55581', (path / 'config' / 'config.txt').read_text().splitlines(), 'the host turned it off')
        group['chat_translator'] = None
        region.pop('overlay')
        (path / 'config' / 'config.txt').write_text('A 1\n')
        shard_group.apply_overlays(group, region, path)
        self.assertEqual('A 1\n', (path / 'config' / 'config.txt').read_text(), 'no translator: config untouched')

    def test_actions_need_the_translator_and_the_whole_group(self):
        self.group.pop('chat_translator')
        group = self.load()
        with self.assertRaises(shard_group.Refused):
            shard_group.translator_start(group)
        with self.assertRaises(shard_group.Refused):
            shard_group.translator_stop(group)
        self.assertIn('translator-status', shard_group.GROUP_ACTIONS)
