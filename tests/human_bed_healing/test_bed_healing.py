"""Compare the source-projected bed-healing branch; no BYOND process runs."""
import importlib.util
from itertools import product
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).parent
SPEC = importlib.util.spec_from_file_location('bed_healing_adapter', ROOT / 'tests/save_movement/source_adapter.py')
ADAPTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ADAPTER)
START = '\tif (istype(buckled, /obj/structure/bed) || istype(buckled, /obj/structure/optable))'
END = '\tif (map && istype(map, /obj/map_metadata/football)'
OLD = 'if (healing_stage >= 30 && (istype(buckled, /obj/structure/bed) || istype(buckled, /obj/structure/optable) || istype(buckled, /obj/structure/medicalbed)))'
NEW = 'if (healing_stage >= 30) // Other buckle types reset the counter immediately above.'
TYPES = ('/obj/structure/bed', '/obj/structure/optable', '/obj/structure/medicalbed')


def production():
    source = (ROOT / 'code/game/mob/living/carbon/human/human_life.dm').read_text(encoding='utf-8')
    return source[source.index(START):source.index(END)].rstrip() + '\n'


def project(fragment):
    for name in TYPES:
        fragment = fragment.replace(name, repr(name))
    body = '/check()\n' + fragment + '\treturn healing_stage\n'
    args = ('buckled, healing_stage, halloss, istype, rejuvenate, to_chat, src, '
            'getBruteLoss, adjustBruteLoss, adjustHalLoss')
    return ADAPTER.project(body, '/check', args, {})


def run(proc, buckle_types, stage, brute, hallucination):
    events = []
    health = {'brute': brute}

    def rejuvenate():
        events.append('rejuvenate')
        health['brute'] = 0

    def chat(_src, message):
        events.append(('chat', message))

    def adjust_brute(amount):
        events.append(('brute', amount))
        health['brute'] += amount

    def adjust_halloss(amount):
        events.append(('halloss', amount))

    value = proc(buckle_types, stage, hallucination, lambda value, kind: kind in value,
                 rejuvenate, chat, None, lambda: health['brute'], adjust_brute, adjust_halloss)
    return value, health['brute'], events


class BedHealingChecks(unittest.TestCase):
    def test_only_redundant_check_changes(self):
        before = (HERE / 'before.dm.txt').read_text(encoding='utf-8')
        self.assertEqual(before.count(OLD), 1)
        self.assertEqual(production(), before.replace(OLD, NEW))

    def test_threshold_subtypes_effect_order_and_negative_controls(self):
        before = (HERE / 'before.dm.txt').read_text(encoding='utf-8')
        after = production()
        original, current = project(before), project(after)
        mutants = [project(after.replace('\t\thealing_stage = 0\n\tif', '\t\thealing_stage = 30\n\tif', 1)),
                   project(after.replace('healing_stage >= 30', 'healing_stage > 30')),
                   project(after.replace('halloss > 40', 'halloss >= 40'))]
        differences = [0] * len(mutants)
        # A chair inherits bed; the overlap case exercises the actual order if
        # a specialized type ever satisfies more than one of the checks.
        kinds = ((), (TYPES[0],), (TYPES[1],), (TYPES[2],), (TYPES[0], TYPES[2]))
        for buckle, stage, brute, hallucination in product(kinds, (-1, 0, 27.5, 28, 29, 29.5, 30, 31, 100), (0, 14, 15, 50), (0, 40, 41)):
            expected = run(original, buckle, stage, brute, hallucination)
            self.assertEqual(run(current, buckle, stage, brute, hallucination), expected)
            for index, mutant in enumerate(mutants):
                differences[index] += run(mutant, buckle, stage, brute, hallucination) != expected
        self.assertTrue(all(differences), differences)


if __name__ == '__main__':
    unittest.main()
