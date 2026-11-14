"""Execute production Python tools against temporary/offline inputs; no network."""
import contextlib
import importlib
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
sys.path.insert(0, str(ROOT / 'tools/agent-control'))
import autopilot
from memory import CharacterMemory
from mapmerge2.dmm import DMM
from mapmerge2 import mapmerge, frontend
from transfer_storage import radio
updates = importlib.import_module('UpdatePaths.__main__')


class Regressions(unittest.TestCase):
    def test_cold_prefers_west_and_same_axis(self):
        for dx, dy in ((-1, 0), (0, -1), (0, 0), (1, 0)):
            obs = {'self': {'bodytemperature': 200}, 'nearby': [
                {'ref': 'far', 'name': 'campfire', 'dx': 5, 'dy': 5},
                {'ref': 'near', 'name': 'campfire', 'dx': dx, 'dy': dy}]}
            self.assertEqual(autopilot.cold_plan(obs)['target'], 'near')
            obs['self']['bodytemperature'] = 1000
            self.assertIsNone(autopilot.cold_plan(obs))

    def test_cold_tree_and_invalid_offset(self):
        obs = {'self': {'bodytemperature': 200, 'left_hand': {'name': 'axe'}}, 'nearby': [
            {'ref': 'bad', 'branches': 2, 'dx': True, 'dy': None},
            {'ref': 'near', 'branches': 2, 'dx': -1, 'dy': 0}]}
        self.assertEqual(autopilot.cold_plan(obs)['target'], 'near')
        for v in (True, None, '1', 1.5):
            self.assertEqual(autopilot._offset(v), 9)

    def test_new_recipe_survives_capacity(self):
        m = CharacterMemory('unused.json')
        m.data['made'] = {f'old{i}': 2 for i in range(300)}
        self.assertEqual(m.made('new thing'), 1)
        self.assertEqual(len(m.data['made']), 300)
        self.assertEqual(m.made('new thing'), 2)
        self.assertTrue(m.dirty)

    @staticmethod
    def map():
        return DMM.from_bytes(b'"a" = (/obj/a{dir = 2},/turf/a,/area/a)\n"b" = (/obj/unused,/turf/a,/area/a)\n\n(1,1,1) = {"\na\n"}\n')

    def test_missing_old_property_is_omitted(self):
        m = self.map()
        updates.update_path(m, '/obj/a : /obj/new{name = @OLD:name; dir = @OLD:dir}')
        text = str(list(m.dictionary.values()))
        self.assertIn('/obj/new', text)
        self.assertIn('dir = 2', text)
        self.assertNotIn('name =', text)

    def test_unused_default_and_explicit_keys(self):
        for keys in (None, [1]):
            m = self.map()
            m.remove_unused_keys(keys)
            self.assertEqual(set(m.dictionary), {0})

    def test_merge_main_uses_its_actual_backup(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / 'tiny.dmm'
            self.map().to_file(str(p))
            before = p.read_bytes()
            with patch.object(sys, 'argv', ['mapmerge', str(p)]), patch('builtins.input', return_value=''), contextlib.redirect_stdout(io.StringIO()):
                mapmerge.main(frontend.Settings(d, None))
            self.assertEqual(Path(str(p) + '.before').read_bytes(), before)
            self.assertTrue(DMM.from_file(str(p)).grid)
            self.assertFalse(Path(str(p) + '.backup').exists())

    def test_nonfinite_frequency_rejected_as_radio_error(self):
        for v in (float('nan'), float('inf'), -float('inf'), True, 149, 301, 150.5):
            with self.assertRaises(radio.RadioError):
                radio._frequency(v)
        self.assertEqual(radio._frequency(150.0), 150)
        self.assertEqual(radio._frequency(300), 300)

    def test_nonfinite_strike_rejected_as_radio_error(self):
        base = {'target': 'europe', 'mode': radio.STRIKE_MODES[0], 'party': 'party',
                'x': 1, 'y': 1, 'z': 0, 'shells': 1}
        self.assertEqual(radio.RadioRelay._strike_fields(base)['z'], 0)
        for field in ('x', 'y', 'z', 'shells'):
            for value in (float('inf'), -float('inf'), float('nan'), True):
                with self.assertRaises(radio.RadioError):
                    radio.RadioRelay._strike_fields(dict(base, **{field: value}))


if __name__ == '__main__':
    unittest.main()
