"""Expedition slots: a slot takes one generated land at a time, compiles it as
its map, and archives its saved world before the next land."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts/gaia-host'))
sys.path.insert(0, str(ROOT / 'tests/gaia_host'))
SPEC = importlib.util.spec_from_file_location('shard_group', ROOT / 'scripts/shard-group/shard_group.py')
shard_group = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(shard_group)
slots = shard_group.expedition_slots
from test_shard_group import FakeMachine  # noqa: E402

TEMPLATE = {
    'biome': 'DESERT', 'land_type': 'COASTAL_PLAIN', 'size': 'TINY', 'width': 96, 'height': 96, 'coast': ['S'],
    'seed': 'slot-test:3:4:r0', 'features': {'rivers': 1, 'lakes': 0, 'ridges': 1, 'caves': False},
    'resources': {'ore': 'rich', 'ores': ['iron'], 'rare': [], 'fertility': 'poor', 'game': ['camel']},
}


def fake_build(template, out):
    out.mkdir()
    (out / 'land.dmm').write_text('"a" = (/turf,/area)\n')
    return {'template': template, 'width': template['width'], 'height': template['height'],
            'area': '/area/caribbean/nomads/desert', 'slot_world': {'ores': ['iron'], 'rare': [], 'game': ['camel']},
            'seconds': {'total': 1.0}}


class ExpeditionSlotTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        (self.base / 'repo').mkdir()
        self.group_json = {
            'group': 'earth', 'repository': str(self.base / 'repo'), 'root': str(self.base / 'regions'),
            'compiler': 'DreamMaker', 'daemon': 'DreamDaemon', 'git': 'git', 'public_host': '203.0.113.5',
            'regions': [{'id': 'gaia', 'name': 'Gaia', 'kind': 'SURFACE', 'port': 1720, 'map': 'maps/small/tiny.dmm'},
                        {'id': 'far1', 'name': 'Far Land 1', 'kind': 'EXPEDITION', 'port': 1721,
                         'map': 'maps/small/tiny.dmm'}]}
        self.group = self.load()
        self.machine = FakeMachine()
        shard_group.setup(self.group, self.machine)
        (self.region, self.host), = shard_group.hosts(self.group, 'far1', self.machine)
        self.slot = self.base / 'regions' / 'far1'

    def tearDown(self):
        self.tmp.cleanup()

    def load(self):
        path = self.base / 'group.json'
        path.write_text(json.dumps(self.group_json))
        return shard_group.load_group(path)

    def give(self, key='3,4'):
        return slots.give_land(self.group, self.host, 'far1', TEMPLATE, key=key, build=fake_build)

    def test_a_slot_is_never_the_mainland_or_the_gate(self):
        self.group_json['mainland'] = 'far1'
        with self.assertRaisesRegex(ValueError, 'EXPEDITION'):
            self.load()
        del self.group_json['mainland']
        self.group_json.update(relay_port=1730, gate='far1')
        with self.assertRaisesRegex(ValueError, 'EXPEDITION'):
            self.load()
        del self.group_json['gate']
        self.group_json['regions'][1]['id'] = 'expeditions'
        with self.assertRaisesRegex(ValueError, 'cannot be called expeditions'):
            self.load()

    def test_a_free_slot_compiles_its_placeholder_and_a_land_slot_its_land(self):
        self.assertEqual('FREE', slots.status(self.group)['far1']['state'])
        self.assertEqual('maps\\small\\tiny.dmm', shard_group.place_map(self.group, self.region, self.slot))
        self.assertFalse((self.slot / slots.WORLD_FILE).exists())
        answer = self.give()
        self.assertEqual('LAND', answer['state'])
        include = shard_group.place_map(self.group, self.region, self.slot)
        self.assertEqual('maps\\regions\\far1.dmm', include)
        self.assertEqual('"a" = (/turf,/area)\n', (self.slot / 'maps/regions/far1.dmm').read_text())
        world = json.loads((self.slot / slots.WORLD_FILE).read_text())
        self.assertEqual(('DESERT', 'COASTAL_PLAIN', 'TINY', '3,4'), (world['biome'], world['land_type'], world['size'], world['key']))
        self.assertEqual(['camel'], world['slot_world']['game'])
        state = slots.status(self.group)['far1']
        self.assertEqual(('LAND', '3,4'), (state['state'], state['key']))

    def test_a_slot_takes_a_land_only_when_stopped_free_and_without_a_save(self):
        self.machine.up.add(1721)
        with self.assertRaisesRegex(shard_group.Refused, 'running'):
            self.give()
        self.machine.up.discard(1721)
        (self.slot / 'map_saves' / 'map.txt').write_text('saved')
        with self.assertRaisesRegex(shard_group.Refused, 'saved world'):
            self.give()
        (self.slot / 'map_saves' / 'map.txt').unlink()
        self.give()
        with self.assertRaisesRegex(shard_group.Refused, 'already holds land 3,4'):
            self.give('5,6')
        with self.assertRaisesRegex(shard_group.Refused, 'not an EXPEDITION'):
            slots.give_land(self.group, self.host, 'gaia', TEMPLATE, build=fake_build)

    def test_archive_moves_the_save_aside_and_frees_the_slot(self):
        self.give()
        (self.slot / 'map_saves' / 'map.txt').write_text('saved')
        self.machine.up.add(1721)
        with self.assertRaisesRegex(shard_group.Refused, 'running'):
            slots.archive(self.group, self.host, 'far1')
        self.machine.up.discard(1721)
        answer = slots.archive(self.group, self.host, 'far1')
        self.assertEqual(['map_saves'], answer['archived'])
        archived = Path(answer['archive'])
        self.assertEqual('saved', (archived / 'map_saves' / 'map.txt').read_text())
        self.assertEqual('3,4', json.loads((archived / 'slot.json').read_text())['key'])
        self.assertFalse((self.slot / 'map_saves').exists())
        record = slots.read_slot(self.group, 'far1')
        self.assertEqual('FREE', record['state'])
        self.assertEqual(['land', 'archive'], [h['event'] for h in record['history']])
        self.assertTrue(Path(record['history'][0]['land_dir']).is_dir(), 'the land folder is kept')
        shard_group.place_map(self.group, self.region, self.slot)
        self.assertFalse((self.slot / slots.WORLD_FILE).exists())
        self.give('5,6')  # the next land

    def test_a_missing_land_map_stops_the_build(self):
        self.give()
        Path(slots.read_slot(self.group, 'far1')['map']).unlink()
        with self.assertRaisesRegex(RuntimeError, 'missing'):
            shard_group.place_map(self.group, self.region, self.slot)

    def test_a_new_land_forgets_the_old_build_so_the_same_revision_compiles_again(self):
        for path in (self.host.build_file(), self.host.staged_file):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('{"revision": "%s"}' % ('a' * 40))
        self.give()
        self.assertFalse(self.host.build_file().exists())
        self.assertFalse(self.host.staged_file.exists())
        self.host.build_file().write_text('{}')
        slots.archive(self.group, self.host, 'far1')
        self.assertFalse(self.host.build_file().exists())

    def want(self, key='3,4'):
        slots.write_wish(self.group, slots.WANTED, 'far1', {'region': 'far1', 'key': key, 'template': TEMPLATE, 'voyage': 'gaia-1-2'})

    def serve(self, now=1000):
        launched = []
        done = slots.serve(self.group, [(self.region, self.host)], launched.append, now=now)
        return done, launched

    def test_a_wanted_land_is_opened_once_by_a_worker(self):
        self.assertEqual(({}, []), self.serve())
        self.want()
        done, launched = self.serve()
        self.assertEqual((['far1'], {'far1': {'opening': '3,4'}}), (launched, done))
        self.assertTrue(slots.opening(self.group, 'far1', __import__('time').time()))
        # The worker is still running: no second one.
        self.assertEqual([], self.serve()[1])
        update = mock.Mock(return_value={'accepted': {'far1': {'accepted': True}}, 'skipped': {}})
        answer = slots.open_land(self.group, self.host, 'far1', update, build=fake_build)
        self.assertEqual('building', answer['phase'])
        update.assert_called_once_with(self.group, 'far1')
        record = slots.read_slot(self.group, 'far1')
        self.assertEqual(('LAND', '3,4', 'building', 'gaia-1-2'), (record['state'], record['key'], record['phase'], record['voyage']))
        self.assertIsNone(slots.read_wish(self.group, slots.WANTED, 'far1'))
        self.assertFalse(slots.opening(self.group, 'far1', __import__('time').time()))
        self.assertEqual('building', slots.status(self.group)['far1']['phase'])

    def test_a_free_slot_running_its_placeholder_is_stopped_first(self):
        self.want()
        self.machine.up.add(1721)
        with mock.patch.object(self.host, 'request', return_value={'accepted': True}) as request:
            done, launched = self.serve()
        request.assert_called_once_with('stop')
        self.assertEqual([], launched)

    def test_a_land_that_cannot_be_built_is_given_up_and_the_coordinator_told(self):
        self.want()
        update = mock.Mock(return_value={'accepted': {}, 'skipped': {'far1': 'busy: start'}})
        answer = slots.open_land(self.group, self.host, 'far1', update, build=fake_build)
        self.assertIn('busy: start', answer['failed'])
        self.assertEqual('FREE', slots.read_slot(self.group, 'far1')['state'])
        failed = slots.read_wish(self.group, slots.FAILED, 'far1')
        self.assertEqual('3,4', failed['key'])
        self.assertIsNone(slots.read_wish(self.group, slots.WANTED, 'far1'))
        # Nothing wanted: the worker refuses and says so.
        self.assertIn('no land is wanted', slots.open_land(self.group, self.host, 'far1', update)['failed'])

    def test_a_built_land_is_started_and_a_failed_build_freed(self):
        self.want()
        slots.open_land(self.group, self.host, 'far1', mock.Mock(return_value={'skipped': {}}), build=fake_build)
        # Still building: nothing happens.
        with mock.patch.object(self.host, 'built_revision', return_value=None):
            self.assertEqual({}, self.serve()[0])
        with mock.patch.object(self.host, 'built_revision', return_value='a' * 40), \
                mock.patch.object(self.host, 'request', return_value={'accepted': True}) as request:
            done, _ = self.serve()
        request.assert_called_once_with('start')
        self.assertEqual({'far1': {'started': '3,4'}}, done)
        self.assertEqual('started', slots.read_slot(self.group, 'far1')['phase'])
        # A start refused (BYOND signed out) waits for the next pass.
        slots.archive(self.group, self.host, 'far1')
        self.want('5,6')
        slots.open_land(self.group, self.host, 'far1', mock.Mock(return_value={'skipped': {}}), build=fake_build)
        with mock.patch.object(self.host, 'built_revision', return_value='a' * 40), \
                mock.patch.object(self.host, 'request', side_effect=slots.Refused('BYOND is not signed in yet')):
            self.assertIn('BYOND', self.serve()[0]['far1']['waiting'])
        self.assertEqual('building', slots.read_slot(self.group, 'far1')['phase'])
        # A failed stage gives the land up.
        self.host.write_json(self.host.stage_file, {'phase': 'failed', 'error': 'compile failed: boom'})
        self.assertIn('compile failed', self.serve()[0]['far1']['failed'])
        self.assertEqual('FREE', slots.read_slot(self.group, 'far1')['state'])
        self.assertEqual('5,6', slots.read_wish(self.group, slots.FAILED, 'far1')['key'])

    def test_a_wish_for_a_slot_holding_another_land_is_refused(self):
        self.give('1,1')
        self.want('3,4')
        self.assertEqual({'far1': {'refused': '3,4'}}, self.serve()[0])
        self.assertIn('already holds land 1,1', slots.read_wish(self.group, slots.FAILED, 'far1')['reason'])

    def test_the_coordinator_is_told_the_slots(self):
        started = []
        (Path(self.group['root']) / 'coordinator.pid').unlink(missing_ok=True)
        with mock.patch.object(shard_group, 'coordinator_pid', return_value=None):
            group = dict(self.group, transfers=True, mainland='gaia',
                         regions=[dict(r, transfer_port=1800 + n) for n, r in enumerate(self.group['regions'])])
            shard_group.ensure_coordinator(group,
                                           start=lambda argv, cwd, log: started.append(argv) or 4242)
        argv = started[0]
        self.assertEqual('far1', argv[argv.index('--slots') + 1])
        self.assertEqual(str(Path(self.group['root']) / 'expeditions'), argv[argv.index('--expeditions') + 1])

    def test_command_line(self):
        template = self.base / 'tile.json'
        template.write_text(json.dumps({'x': 3, 'y': 4, 'template': TEMPLATE}))
        config = str(self.base / 'group.json')
        out = io.StringIO()
        with mock.patch.object(slots, 'default_build', fake_build), contextlib.redirect_stdout(out):
            self.assertEqual(0, shard_group.main(['--config', config, 'expedition-land', '--region', 'far1',
                                                  '--template', str(template), '--key', '3,4']))
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(0, shard_group.main(['--config', config, 'expedition-status']))
        self.assertIn('"LAND"', out.getvalue())

    def test_a_real_land_is_built(self):
        answer = slots.give_land(self.group, self.host, 'far1', TEMPLATE, key='3,4')
        self.assertTrue(Path(answer['map']).is_file())
        world = slots.read_slot(self.group, 'far1')['world']
        self.assertEqual('/area/caribbean/nomads/desert', world['area'])
        self.assertIn('/obj/map_metadata/nomads/expedition', Path(answer['map']).read_text())


if __name__ == '__main__':
    unittest.main()
