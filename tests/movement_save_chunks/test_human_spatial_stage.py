"""Offline checks for fixture staging only; no BYOND process is started."""
import importlib.util
from pathlib import Path
import unittest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('human_spatial_stage', HERE / 'human_spatial_stage.py')
stage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stage)


class StageChecks(unittest.TestCase):
    def test_anchor_replacement_fails_closed(self):
        self.assertEqual(stage.replace_once('a b c', 'b', 'B', 'x'), 'a B c')
        for text in ('none', 'b b'):
            with self.assertRaises(ValueError):
                stage.replace_once(text, 'b', 'B', 'x')

    def test_stage_has_fixed_candidate_paths_and_no_native_launch(self):
        source = (HERE / 'human_spatial_stage.py').read_text()
        self.assertEqual(len(stage.OVERLAY), 8)
        self.assertEqual(len(set(stage.OVERLAY)), 8)
        self.assertIn('code/modules/persistence/loading.dm', stage.OVERLAY)
        self.assertTrue(all(not p.startswith('/') and '..' not in p.split('/') for p in stage.OVERLAY))
        self.assertIn("native_runner='requires separate approval'", source)
        self.assertNotIn('subprocess.', source)
        self.assertIn('CIV13_HUMAN_SPATIAL_EXPERIMENTAL 1', source)
        self.assertIn("'candidate_sha256': sha(source)", source)

    def test_fixture_requires_writer_handoff_and_fresh_reader_assertions(self):
        probe = (HERE / 'human_spatial_probe.dm').read_text()
        for evidence in ('map_storage.Save_World()', 'human_spatial_fixture_handoffs == 1',
                         'human_spatial_fixture_pulses_after > 0', 'map_storage.Load_World()',
                         'persistence_restored_bodies["syntheticfixture"]',
                         'H.type == /mob/living/human', 'fixture_nested_item_or_slot',
                         'fixture_exact_frozen_capsule', 'fixture_restart_owner',
                         'fixture_audited_floor_and_tool', 'fixture_second_body_position',
                         'fixture_restore_callbacks', 'fixture_legacy_parent_and_link',
                         'fixture_late_exact_capsule', 'fixture_late_walk_did_not_continue',
                         'fixture_seated_did_not_move', 'fixture_seated_reference_first'):
            self.assertIn(evidence, probe)

    def test_drag_authority_seam_is_scoped_to_fixture_actor(self):
        living = (stage.ROOT / 'code/game/mob/living/living.dm').read_text()
        proc = living.split('/mob/living/Move(a, b, flag)\n', 1)[1].split('\n/mob/living/', 1)[0]
        self.assertEqual(proc.count('(client && client.moving)'), 1)
        staged = (HERE / 'human_spatial_stage.py').read_text()
        self.assertIn('(src == human_spatial_fixture_drag_actor && human_spatial_fixture_authorized)', staged)
        self.assertIn("'headless drag predicate'", staged)
        probe = (HERE / 'human_spatial_probe.dm').read_text()
        self.assertIn('fixture_unadapted_headless_control', probe)
        self.assertIn('human_spatial_fixture_drag_actor = H', probe)

    def test_late_fixture_witness_runs_inside_owned_save_and_counts_both_actors(self):
        staged = (HERE / 'human_spatial_stage.py').read_text()
        probe = (HERE / 'human_spatial_probe.dm').read_text()
        self.assertIn('actor == human_spatial_fixture_late_actor && human_spatial_fixture_late_capsule && persistence_save_in_progress', staged)
        self.assertIn('actor.persistence_owner_ckey == "syntheticfixture"', staged)
        self.assertIn('human_spatial_fixture_wait_late_pulse()', staged)
        self.assertIn('human_spatial_fixture_restore_living == 2', probe)
        self.assertIn('human_spatial_fixture_restore_human == 2', probe)
        self.assertIn('geometry_metrics', probe)
        self.assertIn('human_spatial_fixture_move_saved_seated(A)', staged)

    def test_legacy_parent_diagnostic_preserves_refusal_and_has_bounded_identity(self):
        saver = (stage.ROOT / 'code/modules/persistence/saving.dm').read_text()
        adapted = stage.instrument_legacy_parent_refusal(saver)
        condition = 'if(!istype(legacy_parent) || human_save_containment_turf(legacy_parent) != current_turf)'
        error = 'throw EXCEPTION("Human legacy save has no valid parent")'
        self.assertEqual(saver.count(condition), 1)
        self.assertEqual(adapted.count(condition), 1)
        self.assertEqual(adapted.count(error), 1)
        self.assertLess(adapted.index('human_spatial_fixture_record_legacy_refusal(H, legacy_parent'), adapted.index(error))
        self.assertIn('\t\t\tcatch\n', adapted)
        with self.assertRaises(ValueError):
            stage.instrument_legacy_parent_refusal(adapted)
        probe = (HERE / 'human_spatial_probe.dm').read_text()
        for role in ('moving', 'second', 'seated', 'contained', 'late', 'unregistered'):
            self.assertIn('"' + role + '"', probe)
        for field in ('actor_identity', 'actor_type', 'saveable', 'deleted', 'dead',
                      'actor_z', 'parent_valid', 'parent_identity', 'parent_type',
                      'parent_z', 'resolved_turf_z', 'capture_mode', 'chain'):
            self.assertIn('"' + field + '"', probe)
        self.assertIn('i <= 16 && cursor', probe)
        self.assertIn('observed["legacy_parent_diagnostic"]', probe)


if __name__ == '__main__':
    unittest.main()
