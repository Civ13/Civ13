"""Offline source projection of river carry eligibility; no BYOND runtime."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/1713/river_flow.dm').read_text(encoding='utf-8-sig')
MACROS = (ROOT / 'code/__defines/qdel.dm').read_text(encoding='utf-8-sig')
SPEC = importlib.util.spec_from_file_location('river_guard_adapter', ROOT / 'tests/save_movement/source_adapter.py')
ADAPTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ADAPTER)
GUARD = 'QDELETED(A) || A.anchored'
OLD_GUARD = '!A || ' + GUARD


class Occupant:
    def __init__(self, types=(), deleted=False, anchored=False, stat=0, **flags):
        self.types, self.gc_destroyed, self.anchored, self.stat = set(types), deleted, anchored, stat
        self.buckled = flags.get('buckled', False)
        self.captured = flags.get('captured', False)
        self.pulling = flags.get('pulling', False)
        self.pulledby = flags.get('pulledby', False)
        self.truth_checks = 0
        self.type_checks = []

    def __bool__(self):
        self.truth_checks += 1
        return True


def project(source):
    for path in ('/obj/item', '/mob/living/simple_animal', '/mob/living'):
        source = source.replace('istype(A, ' + path + ')', 'istype(A, ' + repr(path) + ')')
    def istype(value, path):
        value.type_checks.append(path)
        return path in value.types
    env = {'QDELETED': lambda x: not x or x.gc_destroyed, 'istype': istype, 'DEAD': 2}
    return ADAPTER.project(source, '/proc/river_carryable', 'A', env)


def run(source, value):
    try:
        result = project(source)(value)
        return ('return', result, list(value.type_checks) if isinstance(value, Occupant) else [])
    except Exception as error:
        return ('exception', type(error).__name__)


class RiverCarryableGuardTest(unittest.TestCase):
    def test_macro_and_guard(self):
        self.assertIn('#define QDELING(X) (X.gc_destroyed)', MACROS)
        self.assertIn('#define QDELETED(X) (!X || QDELING(X))', MACROS)
        body = ADAPTER.extract(SOURCE, '/proc/river_carryable')
        self.assertEqual(body.count(GUARD), 1)
        self.assertNotIn(OLD_GUARD, body)

    def test_previous_and_current_behavior(self):
        before = SOURCE.replace(GUARD, OLD_GUARD, 1)
        cases = [
            (None, False), (0, False), ('invalid', 'exception'),
            (Occupant(deleted=True), False), (Occupant(anchored=True), False),
            (Occupant(['/obj/item']), True),
            (Occupant(['/mob/living/simple_animal', '/mob/living'], stat=2), False),
            (Occupant(['/mob/living/simple_animal', '/mob/living']), True),
            (Occupant(['/mob/living']), True),
            (Occupant(['/mob/living'], buckled=True), False),
            (Occupant(['/mob/living'], captured=True), False),
            (Occupant(['/mob/living'], pulling=True), False),
            (Occupant(['/mob/living'], pulledby=True), False),
            (Occupant(), False),
        ]
        for value, expected in cases:
            with self.subTest(value=value, expected=expected):
                if isinstance(value, Occupant):
                    old = Occupant(value.types, value.gc_destroyed, value.anchored, value.stat,
                                   buckled=value.buckled, captured=value.captured,
                                   pulling=value.pulling, pulledby=value.pulledby)
                else:
                    old = value
                previous, current = run(before, old), run(SOURCE, value)
                self.assertEqual(previous, current)
                self.assertEqual(current[0], 'exception' if expected == 'exception' else 'return')
                if expected != 'exception':
                    self.assertEqual(current[1], expected)

    def test_deletion_mutation_control(self):
        mutant = SOURCE.replace('QDELETED(A) || A.anchored', 'A.anchored', 1)
        self.assertNotEqual(run(SOURCE, Occupant(['/obj/item'], deleted=True)),
                            run(mutant, Occupant(['/obj/item'], deleted=True)))

    def test_modeled_truth_checks(self):
        before = SOURCE.replace(GUARD, OLD_GUARD, 1)
        old, new = Occupant(['/obj/item']), Occupant(['/obj/item'])
        self.assertEqual(run(before, old)[1], run(SOURCE, new)[1])
        self.assertEqual((old.truth_checks, new.truth_checks), (2, 1))


if __name__ == '__main__':
    unittest.main()
