"""Offline source staging and evidence-oracle checks; never launches BYOND."""
import importlib.util
import json
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('cross_runner_tests', Path(__file__).with_name('run-cross-level.py'))
RUNNER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUNNER)


class CrossLevelSourceTests(unittest.TestCase):
    def test_cli_characterization_expectations_require_explicit_flag(self):
        for flags, expected, characterization in (
            ([], {}, False),
            (['--expect-current-defects'], RUNNER.BASELINE_DEFECTS, True),
        ):
            with self.subTest(flags=flags), tempfile.TemporaryDirectory() as directory:
                argv = ['run-cross-level.py', '--run-native', '--byond-bin', '/synthetic/bin', '--case', 'move-direct', *flags]
                with patch.object(RUNNER.sys, 'argv', argv), \
                        patch.object(RUNNER.tempfile, 'mkdtemp', return_value=directory), \
                        patch.object(RUNNER, 'native') as native, patch('builtins.print'):
                    RUNNER.main()
                self.assertEqual(native.call_args.args[4], expected)
                receipt = json.loads((Path(directory) / 'receipt.json').read_text())
                self.assertEqual(receipt['expected_results'], expected)
                self.assertIs(receipt['characterization_only'], characterization)

    def test_cli_mutation_control_retains_its_own_exact_expectation(self):
        with tempfile.TemporaryDirectory() as directory:
            argv = ['run-cross-level.py', '--run-native', '--byond-bin', '/synthetic/bin', '--negative-control', 'field-level']
            with patch.object(RUNNER.sys, 'argv', argv), \
                    patch.object(RUNNER.tempfile, 'mkdtemp', return_value=directory), \
                    patch.object(RUNNER, 'native') as native, patch('builtins.print'):
                RUNNER.main()
            expected = {'field-direct': RUNNER.CONTROLS['field-level'][4]}
            self.assertEqual(native.call_args.args[4], expected)
            self.assertFalse(native.call_args.args[3]['characterization_only'])

    def test_direct_field_case_checks_owning_field_context(self):
        source = (ROOT / 'tests/world_save/cross_level_probe.dm').read_text()
        self.assertIn('if(!nested && !backward)', source)
        self.assertIn('saved_z=1 native_z=2 turf_z=2 source_type=/obj/cross_holder source_field=payload', source)

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

    def test_structured_record_is_bounded_private_runtime_context(self):
        source = (ROOT / 'code/modules/persistence/functions.dm').read_text()
        snapshot = RUNNER.extract_proc(source, '/map_storage/proc/reference_failure_snapshot')
        record = RUNNER.extract_proc(source, '/map_storage/proc/record_save_reference_failure')
        self.assertIn('"type" = value ? "[value.type]" : "none"', snapshot)
        self.assertIn('"lookup_ref" = value ? "\\ref[value]" : null', snapshot)
        self.assertNotIn('"value" = value', snapshot)
        for key in ('native_x', 'native_y', 'native_z', 'turf_x', 'turf_y', 'turf_z'):
            self.assertIn(f'"{key}"', snapshot)
        self.assertIn('saving_export_stack.len - 7', record)
        self.assertIn('saving_export_stack.len > 8', record)
        self.assertIn('copytext(frame.current_field, 1, 81)', record)
        self.assertIn('istext(frame.current_field)', record)
        self.assertIn('istype(frame, /datum/save_export_frame)', record)
        self.assertIn(': "unavailable"', record)
        self.assertIn('frame_snapshot["entry"] = valid_frame ? frame.entry : 0', record)
        for forbidden in ('.name', '.ckey', '.key', '.client', '.vars'):
            self.assertNotIn(forbidden, snapshot + record)
        self.assertIn('if(key == "last_save_reference_failure") return TRUE', source)

    def test_record_reset_follows_save_admission_and_precedes_contents(self):
        source = (ROOT / 'code/modules/persistence/functions.dm').read_text()
        operation = RUNNER.extract_proc(source, '/map_storage/proc/run_world_operation')
        reset = 'if(kind == "save") last_save_reference_failure = null'
        self.assertEqual(source.count(reset), 1)
        self.assertLess(operation.index('!operation.enter_backend(src, kind)'), operation.index(reset))
        self.assertLess(operation.index(reset), operation.index('success = save_world_contents(operation)'))
        for proc in ('clear_bookkeeping', 'cleanup_world_operation'):
            self.assertNotIn('last_save_reference_failure', RUNNER.extract_proc(source, '/map_storage/proc/' + proc))
        saving = (ROOT / 'code/modules/persistence/saving.dm').read_text()
        graph = (ROOT / 'code/modules/persistence/durable_graph.dm').read_text()
        self.assertIn('record_save_reference_failure("cross_level_object", A)', saving)
        self.assertIn('durable_export.bind_entry(A, saving_z, ref, src)', saving)
        self.assertIn('exporter.record_save_reference_failure("duplicate_durable_entry", A, ref, node["z"], node["ref"])', graph)

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

    def test_native_numeric_json_flags_are_strictly_validated(self):
        row = {'case': 'normal', 'done': 1, 'runtime_failed': 0, 'checks': 14, 'port': 0, 'result': 'PASS'}
        RUNNER.adjudicate(row, '', 'normal')
        for field in ('done', 'runtime_failed'):
            for invalid in (None, '0', '1', 2, -1, 0.0, 1.0):
                with self.subTest(field=field, invalid=invalid), self.assertRaisesRegex(RuntimeError, 'Incomplete'):
                    RUNNER.adjudicate(dict(row, **{field: invalid}), '', 'normal')


if __name__ == '__main__':
    unittest.main()
