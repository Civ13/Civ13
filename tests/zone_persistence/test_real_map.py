"""Offline checks of the real-map runner's own bookkeeping (no compiler, no daemon)."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('zone_real_map', ROOT / 'tests/zone_persistence/real_map.py')
real_map = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(real_map)

PROBE = (ROOT / real_map.PROBE).read_text(encoding='utf-8')


def zone(identity, kind, cells=4):
    return {'id': identity, 'type': kind, 'name': kind, 'cells': cells, 'levels': {'1': cells}, 'sum_x': 10, 'sum_xy': 20}


def document(zones, roofs=(), groups=None):
    return {'zones': list(zones), 'roofs': list(roofs),
            'spawns': {'latejoin': groups or {}, 'start': [], 'join': [], 'paradrop': [], 'supply': []}}


class RealMapRunner(unittest.TestCase):
    def test_schema_edit_changes_one_number_only(self):
        state = {'schema': 2, 'generation': 'g', 'world_state': {'schema': 2, 'topology': {'schema': 2, 'zones': []}}}
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'round.json'
            text = json.dumps(state, separators=(',', ':'))
            path.write_text(text, encoding='utf-8')
            real_map.rewrite_schema(Path(folder), 3)
            edited = path.read_text(encoding='utf-8')
        self.assertEqual(len(edited), len(text))
        self.assertEqual(sum(a != b for a, b in zip(text, edited)), 1)
        after = json.loads(edited)
        self.assertEqual((after['schema'], after['world_state']['schema'], after['world_state']['topology']['schema']), (2, 3, 2))

    def test_schema_edit_refuses_another_format(self):
        with tempfile.TemporaryDirectory() as folder:
            (Path(folder) / 'round.json').write_text('{"world_state":{"schema":1}}', encoding='utf-8')
            with self.assertRaises(RuntimeError):
                real_map.rewrite_schema(Path(folder), 3)

    def test_inventory_comparison_ignores_order_and_names_what_changed(self):
        roof = {'x': 1, 'y': 2, 'z': 1, 'type': '/obj/roof', 'switch': 1, 'base': '/area/a', 'area': '/area/r', 'zone': 'zone:g:3'}
        before = document([zone('zone:g:1', '/area/a'), zone('zone:g:2', '/area/b')], [roof], {'kept': ['2,2,1', '1,1,1']})
        same = document([zone('zone:g:2', '/area/b'), zone('zone:g:1', '/area/a')], [dict(roof)], {'kept': ['1,1,1', '2,2,1']})
        self.assertEqual(real_map.differences(before, same), [])
        moved = document([zone('zone:g:1', '/area/a', 5), zone('zone:g:2', '/area/b', 3)], [roof], {'kept': ['1,1,1', '2,2,1']})
        self.assertEqual(real_map.differences(before, moved), ['zones'])
        renumbered = document([zone('zone:g:1', '/area/a'), zone('zone:g:9', '/area/b')], [roof], {'kept': ['1,1,1', '2,2,1']})
        self.assertEqual(real_map.differences(before, renumbered), ['zones'])
        emptied = document(before['zones'], [], {'kept': []})
        self.assertEqual(real_map.differences(before, emptied), ['roofs', 'spawns'])

    def test_roof_ambiguity_counts_repeated_and_absent_base_types(self):
        zones = [{'id': 'a', 'type': '/area/a'}, {'id': 'b', 'type': '/area/b'}, {'id': 'c', 'type': '/area/b'}]
        roofs = [{'switch': 1, 'base': '/area/a'}, {'switch': 1, 'base': '/area/b'}, {'switch': 0, 'base': '/area/b'},
                 {'switch': 1, 'base': '/area/gone'}]
        with tempfile.TemporaryDirectory() as folder:
            (Path(folder) / 'round.json').write_text(json.dumps({'world_state': {'schema': 2, 'topology': {'schema': 2, 'zones': zones}}}), encoding='utf-8')
            report = real_map.roof_ambiguity(Path(folder), {'roofs': roofs})
        self.assertEqual(report['zone_types_saved_more_than_once'], {'/area/b': 2})
        self.assertEqual((report['switched_roofs'], report['switched_roofs_on_a_repeated_base_type']), (3, 1))
        self.assertEqual(report['roof_bases_absent_from_saved_zones'], ['/area/gone'])

    def test_probe_drives_production_procs_and_never_a_server_save(self):
        for text in ('ticker.savemap()', 'ticker.loadmap()', 'job_master.relocate(H)', 'new /obj/roof(T)',
                     'persistence_startup_recovery_status', '/map_storage/ClearMap()', 'return ..()'):
            self.assertIn(text, PROBE)
        # Saves and loads go through the ticker; the probe never opens a save file itself.
        for text in ('new /savefile', 'savefile/', 'fcopy(', 'Save_World(', 'Load_World('):
            self.assertNotIn(text, PROBE)
        runner = (ROOT / 'tests/zone_persistence/real_map.py').read_text(encoding='utf-8')
        self.assertIn("'-ip', '127.0.0.1'", runner)
        self.assertIn("need(not output.exists() or not any(output.iterdir())", runner)


if __name__ == '__main__':
    unittest.main()
