"""Offline DM control-flow projection with a fake lexical type hierarchy; no BYOND."""
import importlib.util
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).parent
SPEC = importlib.util.spec_from_file_location('adapter', ROOT / 'tests/save_movement/source_adapter.py')
ADAPTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ADAPTER)
WILD = '/obj/structure/wild'
DEAD = [f'{WILD}/jungle/{name}/dead' for name in ('acacia', 'cherry', 'medpine')]
EXCLUDED = [f'{WILD}/{name}' for name in ('berrybush', 'burnedbush', 'burnedtree')] + DEAD
EDIBLE = [f'{WILD}/{name}' for name in (
    'smallbush', 'bush', 'tallgrass', 'junglebush', 'jungle', 'palm', 'tree/cactus', 'flowers')]
OTHER = [None, '/obj/item', WILD, f'{WILD}/tree', f'{WILD}/jungle/medpine',
         f'{WILD}/jungle/cherry', f'{WILD}/jungle/yucca']
CASES = [(item, expected) for item, expected in (
    [(p, False) for p in EXCLUDED] + [(p, True) for p in EDIBLE] +
    [(None, False), ('/obj/item', False), (WILD, False), (f'{WILD}/tree', False),
     (f'{WILD}/jungle/medpine', True), (f'{WILD}/jungle/cherry', True),
     (f'{WILD}/jungle/yucca', True)])]
CASES += [(path + '/test_subtype', expected) for path, expected in CASES if path]


def project(source, trace):
    # Path tokens are literals at the fake type-check boundary.
    source = re.sub(r', (/obj/structure/wild(?:/\w+)*)', r', "\1"', source)
    def istype(value, path=WILD):
        trace.append(path)
        return isinstance(value, str) and (value == path or value.startswith(path + '/'))
    return ADAPTER.project(source, '/proc/wild_browse_plant', 'W', {'istype': istype})


def call(source, value):
    trace = []
    result = project(source, trace)(value)
    return bool(result), len(trace)


class BrowseTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.before = (HERE / 'before.dm.txt').read_text(encoding='utf-8')
        cls.after = (ROOT / 'code/modules/ecology/wild_feeding.dm').read_text(encoding='utf-8')

    def test_expected_behavior_and_frozen_predicate_parity(self):
        for path, expected in CASES:
            with self.subTest(path=path):
                self.assertEqual(call(self.before, path)[0], expected)
                self.assertEqual(call(self.after, path)[0], expected)

    def test_type_check_counts_and_counterexamples(self):
        for path in EDIBLE:
            old, old_count = call(self.before, path)
            new, new_count = call(self.after, path)
            self.assertEqual(old, new)
            self.assertLess(new_count, old_count, path)
        for path in DEAD:
            self.assertEqual(call(self.after, path)[1], call(self.before, path)[1] + 1)
        for path in EXCLUDED[:3] + [None, '/obj/item']:
            self.assertEqual(call(self.before, path)[1], call(self.after, path)[1])

    def test_negative_controls_detect_changed_eligibility(self):
        dead_mutant = self.after.replace(
            '!istype(W, /obj/structure/wild/jungle/acacia/dead)', 'TRUE')
        cactus_mutant = self.after.replace(
            'istype(W, /obj/structure/wild/tree/cactus)', 'FALSE')
        self.assertTrue(call(dead_mutant, DEAD[0])[0])
        self.assertFalse(call(cactus_mutant, f'{WILD}/tree/cactus')[0])


if __name__ == '__main__':
    unittest.main()