"""Offline protected-sleep projections and strict negative-control oracles."""
import importlib.util
from pathlib import Path
import re
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('sleep_runner_tests', Path(__file__).with_name('run-sleep-transfer.py'))
RUNNER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUNNER)


class SleepTransferSourceTests(unittest.TestCase):
    def setUp(self):
        self.source = (ROOT / 'code/game/mob/living/carbon/human/human_helpers.dm').read_text()
        self.helpers = '\n'.join(RUNNER.BASE.extract_proc(self.source, path) for path in RUNNER.HELPERS)

    def test_duplicate_diagnostic_injects_capture_without_changing_production(self):
        probe = (ROOT / 'tests/world_save/sleep_transfer_probe.dm').read_text()
        self.assertIn('/map_storage/cross_level/diagnostic_duplicate/BuildVarDirectory', probe)
        self.assertIn('if(A == cross_target && saving_z == 2)', probe)
        self.assertIn('saving_world_movables -= "\\ref[A]"', probe)
        self.assertIn('return ..()', probe)
        self.assertIn('new /map_storage/cross_level/diagnostic_duplicate(', probe)
        self.assertIn('map_storage.saved_content_refs(', probe)

    def test_candidate_extracts_exact_helpers_and_actual_buckling_and_movement(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            receipt = RUNNER.prepare(output)
            self.assertEqual((output / 'sleep_helpers.dm').read_text(), self.helpers + RUNNER.BASE.extract_proc(self.source, '/proc/is_protected_sleep_location'))
            for relative, target, paths in (
                ('code/game/objects/buckling.dm', 'buckling.dm', RUNNER.BUCKLING),
                ('code/game/atoms_movable.dm', 'force_move.dm', RUNNER.MOVEMENT_HELPERS),
            ):
                expected = '\n'.join(RUNNER.BASE.extract_proc((ROOT / relative).read_text(), path) for path in paths)
                self.assertEqual((output / target).read_text(), expected)
            self.assertFalse(receipt['native_verified'])
            self.assertFalse(receipt['actual_client_timing_verified'])
            self.assertFalse(receipt['full_gameplay_verified'])

    def test_force_move_dependencies_match_production_throw_fields_and_cleanup(self):
        production = (ROOT / 'code/game/atoms_movable.dm').read_text(encoding='utf-8')
        fixture = (ROOT / 'tests/world_save/sleep_transfer_probe.dm').read_text(encoding='utf-8')
        fields = ('var/tmp/mob/living/human/throw_launch_source = null',
                  'var/tmp/throw_launch_dx = null', 'var/tmp/throw_launch_dy = null',
                  'var/tmp/throw_launch_x = null', 'var/tmp/throw_launch_y = null',
                  'var/tmp/list/throw_flight_token = null')
        for field in fields:
            with self.subTest(field=field):
                self.assertEqual(production.count(field), 1)
                self.assertEqual(fixture.count(field), 1)
        self.assertIn('/atom/movable/proc/clear_throw_launch', RUNNER.MOVEMENT_HELPERS)
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            receipt = RUNNER.prepare(output)
            generated = (output / 'force_move.dm').read_text(encoding='utf-8')
            cleanup = RUNNER.BASE.extract_proc(production, '/atom/movable/proc/clear_throw_launch')
            self.assertEqual(generated.count(cleanup), 1)
            self.assertIn('/atom/movable/proc/clear_throw_launch',
                          receipt['source_projections']['force_move.dm']['procedures'])

    def test_generated_environment_has_one_startup_and_only_relative_sources(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            RUNNER.prepare(output)
            environment = (output / 'probe.dme').read_text()
            sources = re.findall(r'^#include "([^"]+)"', environment, re.M)
            self.assertEqual(len(sources), len(set(sources)))
            for name in sources:
                self.assertFalse(Path(name).is_absolute())
                self.assertTrue((output / name).is_file())
            startup_count = sum((output / name).read_text().count('/world/New()\n') for name in sources)
            self.assertEqual(startup_count, 1)

    def test_movement_fixture_uses_exact_disabled_production_presentation_default(self):
        source = (ROOT / 'code/modules/visibility/los_context.dm').read_text(encoding='utf-8')
        default = RUNNER.presentation_default(source)
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            receipt = RUNNER.prepare(output)
            environment = (output / 'probe.dme').read_text(encoding='utf-8')
            self.assertTrue(environment.startswith(default))
            self.assertIn('#if CIV13_ROOT_TREE_PRESENTATION', (output / 'force_move.dm').read_text(encoding='utf-8'))
            self.assertEqual(receipt['source_projections']['presentation_default']['source'], 'code/modules/visibility/los_context.dm')
            self.assertEqual(receipt['source_sha256']['code/modules/visibility/los_context.dm'], RUNNER.BASE.sha((ROOT / 'code/modules/visibility/los_context.dm').read_bytes()))
        for altered in (source.replace(default, '', 1), source.replace(default, default.replace(' 0\n', ' 1\n'), 1), source + default):
            with self.subTest(count=altered.count(default)), self.assertRaisesRegex(RuntimeError, 'disabled production presentation default'):
                RUNNER.presentation_default(altered)

    def test_every_control_changes_only_its_generated_source(self):
        for control in RUNNER.CONTROLS:
            with self.subTest(control=control), tempfile.TemporaryDirectory() as directory:
                output = Path(directory)
                RUNNER.prepare(output, control)
                self.assertEqual((output / 'sleep_helpers.dm').read_text(), RUNNER.mutate(self.helpers, control) + RUNNER.BASE.extract_proc(self.source, '/proc/is_protected_sleep_location'))
                if control != 'diagnostic-record':
                    self.assertNotEqual((output / 'sleep_helpers.dm').read_text(), self.helpers)
                for relative in RUNNER.BASE.PRODUCTION:
                    expected = (ROOT / relative).read_text(encoding='utf-8-sig')
                    if control == 'diagnostic-record' and Path(relative).name == 'functions.dm':
                        expected = RUNNER.omit_record(expected)
                    self.assertEqual((output / Path(relative).name).read_text(), expected)

    def test_every_control_rejects_missing_and_ambiguous_anchors(self):
        for control in RUNNER.CONTROLS:
            if control == 'diagnostic-record':
                source = (ROOT / 'code/modules/persistence/functions.dm').read_text()
                for invalid in ('', source + source):
                    with self.assertRaises(RuntimeError):
                        RUNNER.omit_record(invalid)
                continue
            for source in ('', self.helpers + self.helpers):
                with self.subTest(control=control), self.assertRaises(RuntimeError):
                    RUNNER.mutate(source, control)

    def test_old_bed_control_reaches_real_export_with_original_reciprocal_link(self):
        changed = RUNNER.mutate(self.helpers, 'old-bed')
        self.assertIn(RUNNER.HELPERS[0] + '()\n\treturn TRUE', changed)
        self.assertNotIn('inducedSSD || buckled ||', changed)
        case, expected = RUNNER.CONTROLS['old-bed']
        self.assertEqual(case, 'disk')
        self.assertIn('saved_z=1 native_z=2 turf_z=2', expected)
        self.assertTrue(expected.endswith('source_type=/mob/living/human/sleep_fixture source_field=buckled'))

    def test_other_occupant_control_exercises_normal_unbuckle(self):
        changed = RUNNER.mutate(self.helpers, 'other-occupant')
        self.assertNotIn('if (seat.buckled_mob != src)', changed)
        self.assertIn('seat.unbuckle_mob()', changed)
        self.assertIn('return !buckled && (!seat || seat.buckled_mob != src)', changed)

    def test_persistence_control_omits_all_six_gates_only(self):
        self.assertEqual(self.helpers.count('persistence_sleep_transfer_blocked()'), 6)
        changed = RUNNER.mutate(self.helpers, 'persistence-gate')
        self.assertNotIn('persistence_sleep_transfer_blocked()', changed)
        self.assertIn('release_protected_sleep_buckle()', changed)
        self.assertIn('!return_turf || !sleep_turf', changed)
        self.assertIn('inducedSSD || buckled ||', changed)

    def test_rollback_control_keeps_native_locals_used(self):
        changed = RUNNER.mutate(self.helpers, 'move-rollback')
        self.assertIn('if (cross_case == "never-selected")', changed)
        self.assertNotEqual(RUNNER.CONTROLS['move-rollback'][0], 'never-selected')
        for name in ('lastx', 'lasty', 'lastz', 'sleeping'):
            self.assertIn(f'{name} = previous_{name}', changed)

    def test_helpers_use_source_actor_and_preserve_hook_revalidation(self):
        self.assertNotRegex(self.helpers, r'\busr\b')
        entry = RUNNER.BASE.extract_proc(self.source, RUNNER.HELPERS[1])
        self.assertLess(entry.index('drop_item()'), entry.index('var/previous_lastx'))
        self.assertLess(entry.index('inducedSSD || buckled || !return_turf'), entry.index('lastx = return_turf.x'))
        self.assertLess(entry.index('forceMove(sleep_turf)'), entry.index('sleep_update()'))
        self.assertIn('lastx = previous_lastx', entry)
        self.assertIn('lasty = previous_lasty', entry)
        self.assertIn('lastz = previous_lastz', entry)
        wake = RUNNER.BASE.extract_proc(self.source, RUNNER.HELPERS[2])
        self.assertIn('locate(lastx,lasty,lastz) != return_turf', wake)
        self.assertLess(wake.index('get_turf(src) != return_turf'), wake.index('inducedSSD = FALSE'))

    def test_timed_verbs_pin_and_revalidate_the_initiating_client(self):
        for name, client in (('mob_sleep', 'sleeping_client'), ('mob_wakeup', 'waking_client')):
            body = RUNNER.BASE.extract_proc(self.source, '/mob/living/human/verb/' + name)
            self.assertIn('if (usr != src || !client || client.mob != src)', body)
            self.assertIn(f'var/client/{client} = client', body)
            self.assertIn(f'client != {client} || {client}.mob != src', body)
            self.assertNotIn('usr.forceMove', body)
        wake = RUNNER.BASE.extract_proc(self.source, '/mob/living/human/verb/mob_wakeup')
        self.assertLess(wake.index('spawn(300)'), wake.index('client != waking_client'))
        self.assertLess(wake.index('client != waking_client'), wake.index('complete_protected_wakeup()'))

    def test_fixture_covers_adversarial_hooks_and_disk_roundtrip(self):
        source = (ROOT / 'tests/world_save/sleep_transfer_probe.dm').read_text()
        for case in RUNNER.CASES:
            self.assertIn(f'if("{case}")', source)
            self.assertGreaterEqual(RUNNER.MINIMUM_CHECKS[case], 7)
        for marker in ('sleep_bed.buckle_mob(sleep_actor)', 'map_storage.validate_world_save()',
                       'map_storage.Load_World()', 'roots[1] == roots[2]',
                       'source_field=buckled', 'inventory callback refusal committed protected state'):
            self.assertIn(marker, source)

    def test_each_negative_control_requires_its_exact_failure(self):
        for case, expected in RUNNER.CONTROLS.values():
            row = {'case': case, 'done': True, 'runtime_failed': False, 'checks': 50, 'port': 0, 'result': expected}
            RUNNER.BASE.adjudicate(row, '', case, expected)
            for result in ('PASS', expected + ' extra', 'FAIL: unrelated failure'):
                with self.assertRaisesRegex(RuntimeError, 'Wrong assertion'):
                    RUNNER.BASE.adjudicate(dict(row, result=result), '', case, expected)

    def test_diagnostic_omission_preserves_both_production_rejection_guards(self):
        source = (ROOT / 'code/modules/persistence/functions.dm').read_text()
        changed = RUNNER.omit_record(source)
        body = RUNNER.BASE.extract_proc(changed, RUNNER.RECORD_PROC)
        self.assertEqual(body.splitlines()[1:], ['\treturn'])
        self.assertIn('if(kind == "save") last_save_reference_failure = null', changed)
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            RUNNER.prepare(output, 'diagnostic-record')
            for name in ('saving.dm', 'durable_graph.dm'):
                self.assertEqual((output / name).read_text(), (ROOT / 'code/modules/persistence' / name).read_text())
        self.assertEqual(RUNNER.CONTROLS['diagnostic-record'],
                         ('diagnostic-cross-level', 'FAIL: cross-level failure record missing'))

    def test_diagnostic_cases_cover_identity_cleanup_bounds_and_reset_order(self):
        source = (ROOT / 'tests/world_save/sleep_transfer_probe.dm').read_text()
        for marker in ('snapshot["lookup_ref"] == "\\ref[expected]"',
                       'sleep_check_detached_record(record)',
                       'json_encode(record) == snapshot_json',
                       'chain.len == 8 && record["owner_chain_truncated"]',
                       'length(oversized["field"]) == 80',
                       'rejected busy save erased the failure record',
                       'rejected busy load erased the failure record',
                       'accepted save did not clear the previous record before contents',
                       'record["first_entry"] == first_entry',
                       'record["current_entry"] == source["entry"] + 1',
                       'invalid owner frame masked the original cross-level exception'):
            self.assertIn(marker, source)
        self.assertIn('map_storage.saving_export_stack = list(bad_owner)', source)
        self.assertIn('sleep_check_invalid_frame_record(null)', source)
        self.assertIn('sleep_check_invalid_frame_record(not_a_frame)', source)


if __name__ == '__main__':
    unittest.main()
