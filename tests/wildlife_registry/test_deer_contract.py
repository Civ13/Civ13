"""Offline deer registry and engine-selection contracts. These never execute BYOND."""
from pathlib import Path
import unittest

import run_native as native
from test_source_contract import HOOKS, ROOT, load_source, violations

DEER = 'code/game/mob/living/simple_animal/friendly/deer.dm'
DEER_HOOKS = {'deer/death': 'deer_count', 'deer/Destroy': 'deer_count'}
LOG = "World opened on network port 43210 for address 127.0.0.1.\nWorld no longer opened to new users.\nDONE registry fixture\n"


class DeerRegistryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.deer = (ROOT / DEER).read_text()
        cls.source = load_source()

    def test_deer_hooks_are_part_of_the_suite(self):
        for hook, registry in DEER_HOOKS.items():
            self.assertEqual(HOOKS[hook], registry)
        self.assertEqual(violations(self.source), [])

    def test_historical_deer_intersection_is_rejected(self):
        historical = self.source.replace('deer_count -= src', 'deer_count &= src')
        self.assertEqual(set(violations(historical)), set(DEER_HOOKS))

    def test_registration_and_conception_caps_remain_on_the_shared_registry(self):
        # Base deer and dik-dik constructors register; both Life gates read the same cap.
        self.assertEqual(self.deer.count('deer_count |= src'), 2)
        self.assertEqual(self.deer.count('deer_count.len < 30'), 2)
        self.assertNotIn('deer_count &= src', self.deer)

    def test_native_cases_include_the_deer_pair(self):
        names = native.case_names()
        self.assertIn('deer:death-then-Destroy', names)
        self.assertEqual(len(names), 10 * 3 + 5)


class EngineSelectionTests(unittest.TestCase):
    def setUp(self):
        self.source = load_source()

    def result_for(self, version):
        return dict(version=version, initial_port=43210, closed_port=0, reopen=0,
                    cases=[{'case': c, 'passed': 1} for c in native.case_names()])

    def test_default_remains_strict_1681(self):
        fixture = native.prepare(self.source)['fixture.dm']
        self.assertIn('byond_build != 1681', fixture)
        self.assertIn('"version" = "516.1681"', fixture)
        native.verify(self.result_for('516.1681'), LOG)

    def test_1688_is_selected_explicitly_and_bound_together(self):
        fixture = native.prepare(self.source, version='516.1688')['fixture.dm']
        self.assertIn('byond_build != 1688', fixture)
        self.assertIn('"version" = "516.1688"', fixture)
        self.assertNotIn('@', fixture)
        native.verify(self.result_for('516.1688'), LOG, version='516.1688')
        with self.assertRaises(ValueError):
            native.verify(self.result_for('516.1688'), LOG)
        with self.assertRaises(ValueError):
            native.verify(self.result_for('516.1681'), LOG, version='516.1688')


if __name__ == '__main__':
    unittest.main()
