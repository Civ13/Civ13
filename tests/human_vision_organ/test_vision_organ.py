"""Offline short-circuit projection; does not execute BYOND."""
import importlib.util
from itertools import product
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).parent
SPEC = importlib.util.spec_from_file_location('vision_organ_adapter', ROOT / 'tests/save_movement/source_adapter.py')
ADAPTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ADAPTER)
TYPE = '/obj/item/clothing/glasses/sunglasses/blindfold'


def production():
    text = (ROOT / 'code/game/mob/living/carbon/human/human_life.dm').read_text(encoding='utf-8')
    return text[text.index('/mob/living/human/handle_disabilities()'):text.index('/mob/living/human/handle_chemical_smoke(')].rstrip() + '\n'


def project(text):
    lines = [line.strip().split('//', 1)[0].strip() for line in text.splitlines()
             if line.strip().startswith('else if (!vision')]
    assert len(lines) == 1
    condition = lines[0][len('else if '):].replace(TYPE, 'BLINDFOLD')
    source = '/check()\n\tif ' + condition + '\n\t\treturn TRUE\n\treturn FALSE\n'
    return ADAPTER.project(source, '/check', 'vision, eyes, istype, BLINDFOLD', {})


def run(proc, present, broken, blindfold):
    events = []
    class Organ:
        def is_broken(self):
            events.append('is_broken')
            return broken
    def istype(eyes, kind):
        events.append('istype')
        return eyes == kind
    result = proc(Organ() if present else None, 'blindfold' if blindfold else 'other', istype, 'blindfold')
    return result, events


class VisionOrganChecks(unittest.TestCase):
    def test_only_redundant_check_changes(self):
        before = (HERE / 'before.dm.txt').read_text(encoding='utf-8')
        old = '!vision || (vision && vision.is_broken())'
        self.assertEqual(before.count(old), 1)
        self.assertEqual(production(), before.replace(old, '!vision || vision.is_broken()'))

    def test_short_circuit_results_and_call_order(self):
        before = (HERE / 'before.dm.txt').read_text(encoding='utf-8')
        current = production()
        original, candidate = project(before), project(current)
        mutant = project(current.replace('!vision || vision.is_broken()', '!vision || !vision.is_broken()'))
        differences = 0
        for present, broken, blindfold in product((False, True), repeat=3):
            expected = run(original, present, broken, blindfold)
            self.assertEqual(run(candidate, present, broken, blindfold), expected)
            differences += run(mutant, present, broken, blindfold) != expected
        self.assertEqual(run(candidate, False, False, False), (True, []))
        self.assertEqual(run(candidate, True, True, False), (True, ['is_broken']))
        self.assertEqual(run(candidate, True, False, True), (True, ['is_broken', 'istype']))
        self.assertEqual(run(candidate, True, False, False), (False, ['is_broken', 'istype']))
        self.assertGreater(differences, 0, 'the inverted-organ negative control must be detected')


if __name__ == '__main__':
    unittest.main()
