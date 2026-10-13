"""Source-only regression checks; no BYOND processes or game state."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('decay_probe', Path(__file__).with_name('run.py'))
PROBE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PROBE)
METADATA = ROOT / 'code/game/objects/map_metadata'
MAPS = ('_map_metadata', 'nomads/nomads_mountain', 'nomads/nomads_ice_age', 'colonia', 'pepelsibirsk')


class SeasonWiringTests(unittest.TestCase):
    def test_current_production_sources(self):
        PROBE.check_season_wiring(ROOT)

    def test_queued_base_worker_has_four_transitions(self):
        source = (METADATA / '_map_metadata.dm').read_text()
        self.assertEqual(PROBE.check_transition_hooks('_map_metadata', source), 4)

    def test_missing_hook_is_rejected_for_each_production_cycle(self):
        for name in MAPS:
            with self.subTest(map=name):
                source = (METADATA / (name + '.dm')).read_text()
                hook = 'record_abandonment_season_change(advance_decay)'
                self.assertIn(hook, source)
                with self.assertRaises(AssertionError):
                    PROBE.check_transition_hooks(name, source.replace(hook, 'return', 1))

    def test_unrelated_procedure_does_not_supply_transition_coverage(self):
        source = (METADATA / '_map_metadata.dm').read_text()
        source = source.replace('/season_apply(', '/unrelated_helper(')
        with self.assertRaises(AssertionError):
            PROBE.check_transition_hooks('_map_metadata', source)

    def test_direct_seasons_layout_remains_supported(self):
        source = (METADATA / '_map_metadata.dm').read_text()
        # The historical layout kept these same transition bodies in seasons.
        source = source.replace('/season_apply(', '/seasons(')
        self.assertEqual(PROBE.check_transition_hooks('_map_metadata', source), 4)

    def test_missing_worker_dispatch_is_rejected(self):
        source = (METADATA / '_map_metadata.dm').read_text()
        source = source.replace('season_apply(force, advance_decay, epoch)', 'return', 1)
        with self.assertRaises(AssertionError):
            PROBE.check_transition_hooks('_map_metadata', source)

    def test_missing_asia_completion_parent_call_is_rejected(self):
        source = (METADATA / 'nomads/nomads_asia.dm').read_text()
        PROBE.check_asia_forwarding(source)
        with self.assertRaises(AssertionError):
            PROBE.check_asia_forwarding(source.replace('..(epoch)', 'return', 1))


if __name__ == '__main__':
    unittest.main()
