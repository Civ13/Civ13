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

    def test_candidate_extracts_exact_helpers_and_actual_buckling_and_movement(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            receipt = RUNNER.prepare(output)
            self.assertEqual((output / 'sleep_helpers.dm').read_text(), self.helpers)
            for relative, target, paths in (
                ('code/game/objects/buckling.dm', 'buckling.dm', RUNNER.BUCKLING),
                ('code/game/atoms_movable.dm', 'force_move.dm', ('/atom/movable/proc/forceMove',)),
            ):
                expected = '\n'.join(RUNNER.BASE.extract_proc((ROOT / relative).read_text(), path) for path in paths)
                self.assertEqual((output / target).read_text(), expected)
            self.assertFalse(receipt['native_verified'])
            self.assertFalse(receipt['actual_client_timing_verified'])
            self.assertFalse(receipt['full_gameplay_verified'])

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

    def test_every_control_changes_only_generated_helper_projection(self):
        for control in RUNNER.CONTROLS:
            with self.subTest(control=control), tempfile.TemporaryDirectory() as directory:
                output = Path(directory)
                RUNNER.prepare(output, control)
                self.assertEqual((output / 'sleep_helpers.dm').read_text(), RUNNER.mutate(self.helpers, control))
                self.assertNotEqual((output / 'sleep_helpers.dm').read_text(), self.helpers)
                for relative in RUNNER.BASE.PRODUCTION:
                    self.assertEqual((output / Path(relative).name).read_text(), (ROOT / relative).read_text(encoding='utf-8-sig'))

    def test_every_control_rejects_missing_and_ambiguous_anchors(self):
        for control in RUNNER.CONTROLS:
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

    def test_persistence_control_omits_all_five_gates_only(self):
        self.assertEqual(self.helpers.count('persistence_save_in_progress'), 5)
        changed = RUNNER.mutate(self.helpers, 'persistence-gate')
        self.assertNotIn('persistence_save_in_progress', changed)
        self.assertIn('release_protected_sleep_buckle()', changed)
        self.assertIn('!return_turf || !sleep_turf', changed)
        self.assertIn('inducedSSD || buckled ||', changed)

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


if __name__ == '__main__':
    unittest.main()
