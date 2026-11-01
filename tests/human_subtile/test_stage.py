"""Offline source-substitution controls, without DreamMaker or execution."""
import unittest
from pathlib import Path
import build_guard
import stage_observer
import source_binding

ROOT = Path(__file__).resolve().parents[2]
GIT = ['git', '-C', str(ROOT)]


def baseline():
    return source_binding.read_inputs(GIT, source_binding.BASE)['code/game/mob/living/living.dm']


class StageControls(unittest.TestCase):
    def test_both_exact_preimages_and_instrumented_leg_counts(self):
        original = baseline()
        candidate = build_guard.build(build_guard.OLD.read_bytes(), build_guard.WALKER.read_bytes(),
                                      build_guard.TACTICAL.read_bytes())
        for raw, variant in ((original, False), (candidate, True)):
            result = stage_observer.stage(raw, variant).decode()
            with self.subTest(candidate=variant):
                self.assertEqual(result.count('fixture_bump_observe("collision"'), 1)
                self.assertEqual(result.count('fixture_bump_observe("deferred"'), 1)
                self.assertEqual(result.count('fixture_bump_observe("legacy_swap_leg_before"'), 4)
                self.assertEqual(result.count('fixture_bump_observe("legacy_swap_leg_after"'), 4)
                self.assertEqual(result.count('fixture_bump_observe("legacy_push_before"'), 1)
                density = result.split('/proc/swap_density_check', 1)[1].split('/mob/living/proc/can_swap_with', 1)[0]
                self.assertEqual(density.count('A.CanPass(swapee, T, TRUE)'), 1)
                self.assertLess(density.index('canpass_before'), density.index('A.CanPass'))
                self.assertLess(density.index('A.CanPass'), density.index('canpass_after'))

    def test_wrong_variant_or_modified_source_is_rejected(self):
        original = baseline()
        for raw, variant in ((original, True), (original + b'\n// unexpected\n', False)):
            with self.assertRaises(ValueError):
                stage_observer.stage(raw, variant)

    def test_probe_adapter_preserves_failure_fields_and_variant(self):
        paths = source_binding.read_inputs(GIT, source_binding.BASE)
        probe = paths['tests/human_subtile/probe.dm'].decode()
        before = '\t\t\thuman_subtile_fixture_headless()'
        self.assertEqual(probe.count(before), 1)
        probe = probe.replace(before, '\t\t\tnpc_subtile_fixture()').encode()
        for variant in (False, True):
            output = stage_observer.stage_prepared_probe(probe, variant).decode()
            self.assertIn('fixture_bump_run()', output)
            self.assertIn('"bump_partial" = fixture_bump_events', output)
            self.assertIn('"bump_variant" = "' + ('candidate' if variant else 'baseline') + '"', output)
        with self.assertRaises(ValueError):
            stage_observer.stage_prepared_probe(probe.replace(b'npc_subtile_fixture()', b'other()'), False)

    def test_npc_finish_adapter_retains_real_hook_and_terminal_order(self):
        raw = build_guard.WALKER.read_bytes()
        staged = stage_observer.stage_npc_finish(raw).decode()
        chunk = staged.split('/datum/npc_subtile_transaction/proc/finish(', 1)[1].split('/mob/living/simple_animal/proc/npc_subtile_take_pulse', 1)[0]
        for earlier, later in (('animal_living_before', 'actor.living_movement_completed()'),
                               ('actor.living_movement_completed()', 'animal_living_after'),
                               ('finished = TRUE', 'animal_tx_finished'),
                               ('animal_tx_finished', 'W.transaction_finished')):
            self.assertLess(chunk.index(earlier), chunk.index(later))
        with self.assertRaises(ValueError):
            stage_observer.stage_npc_finish(raw + b'\n// unexpected')


if __name__ == '__main__':
    unittest.main()
