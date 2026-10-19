"""Offline source staging and evidence-oracle checks; never launches BYOND."""
import importlib.util
import json
from pathlib import Path
import re
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('cross_runner_tests', Path(__file__).with_name('run-cross-level.py'))
RUNNER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUNNER)


class CrossLevelSourceTests(unittest.TestCase):
    def test_staging_preserves_all_production_sources_and_is_relocatable(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            receipt = RUNNER.prepare(output)
            for path in RUNNER.PRODUCTION:
                self.assertEqual((output / Path(path).name).read_text(), (ROOT / path).read_text(encoding='utf-8-sig'))
            for path in re.findall(r'^#include "([^"]+)"', (output / 'probe.dme').read_text(), re.M):
                self.assertFalse(Path(path).is_absolute())
                self.assertTrue((output / path).is_file(), path)
            self.assertFalse(receipt['native_verified'])
            self.assertTrue(receipt['prepared_only'])
            self.assertEqual(json.loads((output / 'receipt.json').read_text()), receipt)

    def test_stub_adapter_removes_only_graph_noops(self):
        source = (ROOT / 'tests/world_save/stubs.dm').read_text()
        changed = RUNNER.adapt_stubs(source)
        self.assertNotIn('/datum/durable_save_graph/proc/', changed)
        self.assertIn('/map_storage/proc/capture_durable_world()\n\treturn null', changed)
        self.assertIn('/map_storage/proc/release_durable_world()', changed)
        with self.assertRaisesRegex(RuntimeError, 'exactly one'):
            RUNNER.adapt_stubs(source + source)

    def test_reachability_projection_is_actual_production_body(self):
        source = (ROOT / 'code/modules/persistence/durable_world.dm').read_text()
        body = RUNNER.extract_proc(source, '/map_storage/proc/validate_durable_reachability')
        self.assertIn('Durable metadata references an unreachable world entry', body)
        self.assertNotIn('/map_storage/proc/require_durable_world_idle()', body)
        with self.assertRaisesRegex(RuntimeError, 'Expected one'):
            RUNNER.extract_proc(source + source, '/map_storage/proc/validate_durable_reachability')

    def test_controls_touch_only_their_named_generated_source(self):
        for control, (name, before, after, case, expected) in RUNNER.CONTROLS.items():
            with self.subTest(control=control), tempfile.TemporaryDirectory() as directory:
                output = Path(directory)
                RUNNER.prepare(output, control)
                for path in RUNNER.PRODUCTION:
                    original = (ROOT / path).read_text(encoding='utf-8-sig')
                    actual = (output / Path(path).name).read_text()
                    self.assertEqual(actual, original.replace(before, after, 1) if Path(path).name == name else original)
                self.assertIn(case, RUNNER.CASES)
                self.assertTrue(expected.startswith('FAIL: '))

    def test_control_anchor_drift_fails_closed(self):
        for _, before, after, _, _ in RUNNER.CONTROLS.values():
            for source in ('', before + before):
                with self.assertRaisesRegex(RuntimeError, 'exactly one'):
                    RUNNER.replace_once(source, before, after, 'control')

    def test_native_probe_declares_closed_port_and_rejects_clients(self):
        probe = (ROOT / 'tests/world_save/cross_level_probe.dm').read_text()
        self.assertIn('/world/OpenPort(port)\n\treturn ..("none")', probe)
        self.assertIn('/client/New()\n\tdel(src)', probe)
        self.assertIn('map_storage.Save_World()', probe)
        self.assertIn('map_storage.Load_World()', probe)
        self.assertIn('storage.fixture_restored[1] == restored && storage.fixture_restored[2] == restored', probe)
        self.assertIn('explicit native deletion did not clear pinned references', probe)

    def test_diagnostic_sources_remain_bounded_and_exclude_native_handles(self):
        saving = (ROOT / 'code/modules/persistence/saving.dm').read_text()
        graph = (ROOT / 'code/modules/persistence/durable_graph.dm').read_text()
        functions = (ROOT / 'code/modules/persistence/functions.dm').read_text()
        self.assertIn('copytext("[owner.current_field]", 1, 81)', saving)
        self.assertIn('frame.current_field = null', functions)
        for source, marker in ((saving, 'Cross-level object reference cannot be represented'),
                               (graph, 'Durable metadata atom was exported more than once')):
            line = next(line for line in source.splitlines() if 'throw EXCEPTION(' in line and marker in line)
            self.assertNotIn('\\ref[', line)
            self.assertNotIn('.name', line)
            self.assertNotIn('.ckey', line)
        self.assertIn('if(node["ref"] && (node["ref"] != ref || node["z"] != z))', graph)

    def test_bounded_characterization_accepts_only_intended_duplicate(self):
        expected = RUNNER.BASELINE_DEFECTS['move-direct']
        message = ('FAIL: movement export rejected: Durable metadata atom was exported more than once: '
                   'type=/obj/item/cross_target first_z=1 first_ref=2 current_z=2 current_ref=2 native_z=2 turf_z=2')
        row = {'case': 'move-direct', 'done': True, 'runtime_failed': False, 'checks': 7, 'port': 0, 'result': message}
        RUNNER.adjudicate(row, '', 'move-direct', expected)
        for changed in (message + ' unexpected', message.replace('first_z=1', 'first_z=3'),
                        message.replace('/obj/item/cross_target', '/obj/other'), 'FAIL: unrelated problem'):
            with self.assertRaisesRegex(RuntimeError, 'Wrong assertion'):
                RUNNER.adjudicate(dict(row, result=changed), '', 'move-direct', expected)

    def test_oracle_rejects_incomplete_contaminated_or_wrong_results(self):
        row = {'case': 'pins', 'done': True, 'runtime_failed': False, 'checks': 8, 'port': 0, 'result': 'PASS'}
        RUNNER.adjudicate(row, '', 'pins', minimum=8)
        for change in ({'case': 'binder'}, {'done': False}, {'runtime_failed': True}, {'port': 1234}, {'checks': 7}):
            with self.assertRaisesRegex(RuntimeError, 'Incomplete'):
                RUNNER.adjudicate(dict(row, **change), '', 'pins', minimum=8)
        with self.assertRaisesRegex(RuntimeError, 'Incomplete'):
            RUNNER.adjudicate(row, 'runtime error: invalid call', 'pins')
        with self.assertRaisesRegex(RuntimeError, 'Wrong assertion'):
            RUNNER.adjudicate(dict(row, result='FAIL: other'), '', 'pins')


if __name__ == '__main__':
    unittest.main()
