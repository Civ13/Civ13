"""Offline poultry registry contracts. These never execute BYOND or emulate DM lists."""
import argparse
import json
from pathlib import Path
import tempfile
import unittest

import run_native as native
from test_source_contract import POULTRY_HOOKS, POULTRY_SOURCE, ROOT, violations

LOG = "World opened on network port 43210 for address 127.0.0.1.\nWorld no longer opened to new users.\nDONE registry fixture\n"


def result_for(control=None):
    failures = native.expected_failures(control, POULTRY_HOOKS)
    return dict(version=native.VERSION, initial_port=43210, closed_port=0, reopen=0,
                cases=[{'case': c, 'passed': int(c not in failures)}
                       for c in native.case_names(POULTRY_HOOKS)])


class PoultrySourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = (ROOT / POULTRY_SOURCE).read_text()

    def test_all_six_hooks_remove_only_the_owner_before_parent(self):
        self.assertEqual(len(POULTRY_HOOKS), 6)
        self.assertEqual(set(POULTRY_HOOKS.values()), {'chicken_count'})
        self.assertEqual(violations(self.source, POULTRY_HOOKS), [])

    def test_historical_intersection_is_rejected_for_every_hook(self):
        historical = self.source.replace('chicken_count -= src', 'chicken_count &= src')
        self.assertEqual(set(violations(historical, POULTRY_HOOKS)), set(POULTRY_HOOKS))

    def test_each_single_reversion_is_detected(self):
        for hook in POULTRY_HOOKS:
            with self.subTest(hook=hook):
                start = self.source.index(f'/mob/living/simple_animal/{hook}()')
                mutated = (self.source[:start] +
                           self.source[start:].replace('chicken_count -= src', 'chicken_count &= src', 1))
                self.assertEqual(violations(mutated, POULTRY_HOOKS), [hook])

    def test_registration_and_hatch_cap_remain_on_the_shared_registry(self):
        for kind in ('chick', 'chicken', 'rooster'):
            with self.subTest(kind=kind):
                start = self.source.index(f'/mob/living/simple_animal/{kind}/New()')
                end = self.source.index('\n/', start + 1)
                self.assertIn('chicken_count |= src', self.source[start:end])
        self.assertIn('chicken_count.len < 50', self.source)


class PoultryNativePreparationTests(unittest.TestCase):
    def setUp(self):
        self.source = (ROOT / POULTRY_SOURCE).read_text()

    def test_hooks_extracted_unchanged_with_paired_cases(self):
        generated = native.prepare(self.source, hooks=POULTRY_HOOKS)
        for body in native.extract(self.source, POULTRY_HOOKS).values():
            self.assertIn(body, generated['hooks.dm'])
        self.assertIn('var/list/chicken_count = list()', generated['hooks.dm'])
        self.assertNotIn('civ13.dme', generated['probe.dme'])
        # Three cases per hook plus one death-then-Destroy pair per bird type.
        self.assertEqual(len(native.case_names(POULTRY_HOOKS)), 6 * 3 + 3)

    def test_each_control_changes_only_its_exact_production_hook(self):
        baseline = native.prepare(self.source, hooks=POULTRY_HOOKS)
        for hook in POULTRY_HOOKS:
            with self.subTest(hook=hook):
                changed = native.prepare(self.source, hook, POULTRY_HOOKS)
                old = native.extract(self.source, POULTRY_HOOKS)[hook]
                expected = old.replace('chicken_count -= src', 'chicken_count &= src', 1)
                self.assertEqual(changed['hooks.dm'], baseline['hooks.dm'].replace(old, expected, 1))
                self.assertEqual(changed['fixture.dm'], baseline['fixture.dm'])

    def test_baseline_and_every_exact_control_verdict(self):
        for control in (None, *POULTRY_HOOKS):
            native.verify(result_for(control), LOG, control, POULTRY_HOOKS)
            broken = result_for(control)
            broken['cases'][0]['passed'] = 1 - broken['cases'][0]['passed']
            with self.assertRaises(ValueError):
                native.verify(broken, LOG, control, POULTRY_HOOKS)

    def test_engine_version_is_strict_and_explicit(self):
        default = native.prepare(self.source, hooks=POULTRY_HOOKS)['fixture.dm']
        self.assertIn('byond_build != 1681', default)
        self.assertIn('"version" = "516.1681"', default)
        current = native.prepare(self.source, hooks=POULTRY_HOOKS, version='516.1688')['fixture.dm']
        self.assertIn('byond_build != 1688', current)
        self.assertIn('"version" = "516.1688"', current)
        self.assertNotIn('@', current)
        result = result_for()
        result['version'] = '516.1688'
        native.verify(result, LOG, hooks=POULTRY_HOOKS, version='516.1688')
        with self.assertRaises(ValueError):
            native.verify(result, LOG, hooks=POULTRY_HOOKS)

    def test_farm_controls_are_rejected_for_the_poultry_suite(self):
        with tempfile.TemporaryDirectory() as directory:
            args = argparse.Namespace(output=Path(directory)/'out', byond_bin=None, prepare_only=True,
                                      all_controls=False, negative_control='goat/death', suite='poultry', expected_byond_version=native.VERSION)
            with self.assertRaises(ValueError):
                native.execute(args, runner=None)

    def test_prepare_only_poultry_suite_never_invokes_runner(self):
        with tempfile.TemporaryDirectory() as directory:
            args = argparse.Namespace(output=Path(directory)/'out', byond_bin=None, prepare_only=True,
                                      all_controls=True, negative_control=None, suite='poultry', expected_byond_version=native.VERSION)
            def forbidden(*args):
                self.fail('prepare-only invoked a process')
            result = native.execute(args, runner=forbidden)
            self.assertEqual((result['status'], result['suite'], result['source']),
                             ('prepared-only', 'poultry', POULTRY_SOURCE))
            self.assertEqual(len(result['modes']), 7)
            summary = json.loads((args.output/'summary.json').read_text())
            self.assertFalse(summary['native_execution'])


if __name__ == '__main__':
    unittest.main()
