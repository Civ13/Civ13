"""Offline model of the thrown-object mode guards; does not execute BYOND."""

from itertools import product
from pathlib import Path
from types import SimpleNamespace
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/processes/throwing.dm').read_text(encoding='utf-8-sig')
MACROS = (ROOT / 'code/_macros.dm').read_text(encoding='utf-8-sig')


def expressions(source):
    matches = re.findall(r'^\s*if \((AM(?: && AM)?\.original_target .*)\)\s*$', source, re.M)
    if len(matches) != 2:
        raise AssertionError('Expected both throw-mode conditions')
    return matches


def evaluate(expression, actor):
    expr = expression.replace('&&', ' and ').replace('||', ' or ')
    expr = expr.replace('istype(AM.loc, /turf)', 'is_turf(AM.loc)')
    return bool(eval(expr, {'__builtins__': {}}, {
        'AM': actor, 'EAST': 4, 'WEST': 8, 'NORTH': 1, 'SOUTH': 2,
        'FALSE': False, 'is_turf': lambda value: value == 'turf',
    }))


class ThrowModeGuardTests(unittest.TestCase):
    def test_outer_guard_precedes_both_mode_guards(self):
        self.assertIn('#define isDeleted(D) (!D || D:gcDestroyed)', MACROS)
        start = SOURCE.index('\t\tif (!isDeleted(AM))')
        prefix = SOURCE[start:SOURCE.index('\n\t\t\t\t\t\tif (0)', start)]
        self.assertEqual(prefix.strip().splitlines(), [
            'if (!isDeleted(AM))',
            '\t\t\tvar/list/flight_token = AM.throw_flight_token',
            '\t\t\tif (AM.loc)',
            '\t\t\t\ttry',
            '\t\t\t\t\tswitch (AM.throwmode)',
        ])
        self.assertEqual(SOURCE.count('if (!AM || AM.throw_flight_token != flight_token)'), 8)

    def test_mode_conditions_match_guarded_reference(self):
        checks = expressions(SOURCE)
        count = 0
        for mode, target, direction, position, travelled, gravity, throwing, location in product(
            (0, 1), (None, SimpleNamespace(x=1, y=1)), (1, 2, 4, 8),
            (0, 1, 2), (0, 2), (None, False, True), (False, True), ('turf', 'container')
        ):
            actor = SimpleNamespace(original_target=target, x=position, y=position,
                dx=direction, dy=direction, dist_travelled=travelled, range=1,
                a=None if gravity is None else SimpleNamespace(has_gravity=gravity),
                throwing=throwing, loc=location)
            current = checks[mode]
            guarded = current.replace('AM.original_target', 'AM && AM.original_target', 1)
            self.assertEqual(evaluate(current, actor), evaluate(guarded, actor))
            count += 1
        self.assertEqual(count, 1152)

    def test_outer_guard_is_required_for_null(self):
        current = expressions(SOURCE)[0]
        guarded = current.replace('AM.original_target', 'AM && AM.original_target', 1)
        self.assertFalse(evaluate(guarded, None))
        with self.assertRaises(AttributeError):
            evaluate(current, None)


class ThrowBlockerScanTests(unittest.TestCase):
    def test_each_scan_stops_only_after_a_blocker(self):
        indent = '\t' * 10
        structure = (
            'for (var/obj/structure/S in step)\n'
            + indent + 'if (istype(S, /obj/structure/window/barrier) || S.throwpass)\n'
            + indent + '\tcontinue\n'
            + indent + 'if (!S.density && !istype(S, /obj/structure/window/classic))\n'
            + indent + '\tcontinue\n'
            + indent + 'canMove = FALSE\n'
            + indent + 'break\n'
        )
        cover = (
            'for (var/obj/covers/C in step)\n'
            + indent + 'if (C.passable == TRUE)\n'
            + indent + '\tcontinue\n'
            + indent + 'canMove = FALSE\n'
            + indent + 'break\n'
        )
        def valid(source):
            return source.count(structure) == 4 and source.count(cover) == 4

        self.assertTrue(valid(SOURCE))
        self.assertFalse(valid(SOURCE.replace(indent + 'break\n', '')))
        self.assertFalse(valid(SOURCE.replace(
            'for (var/obj/covers/C in step)\n',
            'for (var/obj/covers/C in step)\n' + indent + 'break\n',
        )))

    def test_blocker_decisions_match_full_scans_in_a_model(self):
        # This models decisions, not BYOND iteration or runtime.
        structure_types = tuple(product((False, True), repeat=4))
        structures = [()] + [(x,) for x in structure_types] + list(product(structure_types, repeat=2))
        covers = [()] + [(x,) for x in (False, True)] + list(product((False, True), repeat=2))

        def blocked(item):
            barrier, throwpass, dense, classic = item
            return not (barrier or throwpass or (not dense and not classic))

        for nearby_structures, nearby_covers in product(structures, covers):
            original = not any(blocked(x) for x in nearby_structures)
            original = original and not any(not x for x in nearby_covers)
            can_move = True
            for item in nearby_structures:
                if blocked(item):
                    can_move = False
                    break
            for passable in nearby_covers:
                if not passable:
                    can_move = False
                    break
            self.assertEqual(can_move, original)

        # Stopping after the first passable cover misses a later blocker.
        self.assertNotEqual(not any(not x for x in (True, False)), True)


if __name__ == '__main__':
    unittest.main()
