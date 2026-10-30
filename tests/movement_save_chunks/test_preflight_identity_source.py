"""Offline clone and fixture guards; no BYOND execution or timing conclusions."""
import importlib.util
from pathlib import Path
import unittest

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SPEC = importlib.util.spec_from_file_location('preflight_fixture_tested', HERE / 'preflight_fixture.py')
helper = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(helper)


class PreflightIdentitySourceTests(unittest.TestCase):
    def test_reference_is_exact_production_clone_with_only_two_key_changes(self):
        source = (ROOT / 'code/modules/persistence/saving.dm').read_text()
        before, body, after = helper.split_preflight(source)
        expected = body.replace('\t\t\tvar/key = L\n', '\t\t\tvar/key = "\\ref[L]"\n').replace('\t\tvar/key = exporter.save_entry_identity(D)\n', '\t\tvar/key = "\\ref[D]"\n')
        self.assertEqual(helper.reference_preflight_definition(source), '/datum/moving_save_preflight_reference\n' + expected)
        self.assertEqual(helper.restore_preflight_reference_keys(source), before + helper.START + expected + helper.END + after)
        for guard in ('work > 512', 'depth > 32', 'world.tick_usage - start_usage > 5', 'bytes <= 262144', 'seen.len >= 64'):
            self.assertIn(guard, expected)
        self.assertNotIn('sleep(', expected)

    def test_drift_and_double_restoration_fail_closed(self):
        source = (ROOT / 'code/modules/persistence/saving.dm').read_text()
        for changed in (source.replace(helper.START, '', 1), source.replace('var/key = L\n', 'var/key = null\n', 1), helper.restore_preflight_reference_keys(source)):
            with self.assertRaises(ValueError): helper.restore_preflight_reference_keys(changed)

    def test_native_semantics_cases_and_timing_limits_are_explicit(self):
        source = (HERE / 'preflight_identity.dm').read_text()
        for case in ('mixed_alias_cycles', 'mutated_same_graph', 'external_movable', 'depth_limit', 'byte_limit', 'work_limit', 'node_limit', 'length_limit'):
            self.assertIn('"' + case + '"', source)
        for counter in ('work', 'bytes', 'seen.len'):
            self.assertIn(f'candidate.{counter} != reference.{counter}', source)
        self.assertIn('candidate timing cap interfered', source)
        self.assertIn('reference timing cap interfered', source)
        self.assertIn('seen identity partition differs', source)
        self.assertIn('seed_pins += list(node)', source)
        for forbidden in ('/world/New', 'sleep(', 'OpenPort(', 'world.tick_usage =', 'world.log'):
            self.assertNotIn(forbidden, source)


if __name__ == '__main__': unittest.main()
