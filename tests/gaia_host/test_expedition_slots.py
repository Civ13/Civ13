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
