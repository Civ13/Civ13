"""Offline projection of the SSD and sleeping-bed branch; not a BYOND runtime test."""
import importlib.util
from itertools import product
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).parent
SPEC = importlib.util.spec_from_file_location('ssd_hunger_adapter', ROOT / 'tests/save_movement/source_adapter.py')
ADAPTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ADAPTER)
TYPE = '/obj/structure/bed'
OLD = 'stat == UNCONSCIOUS && !inducedSSD'
NEW = 'stat == UNCONSCIOUS'


def production():
    source = (ROOT / 'code/game/mob/living/carbon/human/human_life.dm').read_text(encoding='utf-8')
    start = source.index('\t\tif (inducedSSD) //if sleeping in SSD mode')
    end = source.index('\n\t\telse if (map.heat_wave', start)
    return source[start:end].rstrip() + '\n'


def project(fragment):
    first = [line.strip().split('//', 1)[0].rstrip() for line in fragment.splitlines()
             if line.strip().startswith('if (inducedSSD)')]
    second = [line.strip().split('//', 1)[0].rstrip() for line in fragment.splitlines()
              if line.strip().startswith('else if (istype(buckled,')]
    assert len(first) == len(second) == 1
    source = '/check()\n\t' + first[0] + '\n\t\treturn 1\n\t' + second[0].replace(TYPE, 'BED') + '\n\t\treturn 2\n\treturn 3\n'
    return ADAPTER.project(source, '/check', 'inducedSSD, buckled, stat, istype, BED, UNCONSCIOUS', {})


def run(proc, ssd, buckle, stat):
    events = []
    def istype(value, kind):
        events.append(('istype', value, kind))
        return value == kind
    result = proc(ssd, buckle, stat, istype, 'bed', 1)
    return result, events


class SSDHungerChecks(unittest.TestCase):
    def test_only_redundant_check_changes(self):
        before = (HERE / 'before.dm.txt').read_text(encoding='utf-8')
        self.assertEqual(before.count(OLD), 1)
        self.assertEqual(production(), before.replace(OLD, NEW))

    def test_branches_and_type_call_order(self):
        before = (HERE / 'before.dm.txt').read_text(encoding='utf-8')
        current = production()
        original, candidate = project(before), project(current)
        mutant = project(current.replace(NEW, 'stat != UNCONSCIOUS'))
        differences = 0
        for ssd, buckle, stat in product((False, True), (None, 'other', 'bed'), (0, 1, 2)):
            expected = run(original, ssd, buckle, stat)
            self.assertEqual(run(candidate, ssd, buckle, stat), expected)
            differences += run(mutant, ssd, buckle, stat) != expected
        self.assertEqual(run(candidate, True, 'bed', 1), (1, []))
        self.assertEqual(run(candidate, False, 'bed', 1), (2, [('istype', 'bed', 'bed')]))
        self.assertEqual(run(candidate, False, 'bed', 0), (3, [('istype', 'bed', 'bed')]))
        self.assertGreater(differences, 0, 'the inverted-stat negative control must be detected')


if __name__ == '__main__':
    unittest.main()
