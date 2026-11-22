"""Offline projections of production particle lifetime guards; no BYOND runtime."""
import importlib.util
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/game/objects/effects/effect_system.dm').read_text(encoding='utf-8-sig')
MACROS = (ROOT / 'code/__defines/qdel.dm').read_text(encoding='utf-8-sig')
SPEC = importlib.util.spec_from_file_location('effect_guard_adapter', ROOT / 'tests/save_movement/source_adapter.py')
ADAPTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ADAPTER)


class Effect:
    def __init__(self, deleted=False, loc=True, lifetime='current'):
        self.gc_destroyed, self.loc, self.effect_lifetime = deleted, loc, lifetime
        self.truth_checks = 0

    def __bool__(self):
        self.truth_checks += 1
        return True


def guards(source):
    expressions = re.findall(r'^\s*if \(([^\n]*(?:QDELETED\((?:steam|sparks|smoke|E)\))[^\n]*)\)$', source, re.M)
    if len(expressions) != 7:
        raise AssertionError(f'Expected seven selected guards, got {len(expressions)}')
    return expressions


def run(expression, name, value, system_lifetime='current'):
    body = '/proc/check()\n\tif (' + expression + ')\n\t\treturn TRUE\n\treturn FALSE\n'
    env = {'QDELETED': lambda x: not x or x.gc_destroyed}
    try:
        result = ADAPTER.project(body, '/proc/check', name + ', effect_activation, activation, system_lifetime, lifetime', env)(
            value, 'current', 'current', system_lifetime, 'current')
        return ('return', bool(result))
    except Exception as error:
        return ('exception', type(error).__name__)


class LifetimeGuardTest(unittest.TestCase):
    def test_macro_and_guards(self):
        self.assertIn('#define QDELING(X) (X.gc_destroyed)', MACROS)
        self.assertIn('#define QDELETED(X) (!X || QDELING(X))', MACROS)
        found = guards(SOURCE)
        for name in ('steam', 'sparks', 'smoke'):
            self.assertIn(f'QDELETED({name}) || !{name}.loc || {name}.effect_lifetime != effect_activation || system_lifetime != activation', found)
            self.assertIn(f'!QDELETED({name}) && {name}.effect_lifetime == effect_activation', found)
        self.assertIn('!QDELETED(E) && E.effect_lifetime == lifetime', found)

    def test_before_after_and_guards(self):
        for expr in guards(SOURCE):
            name = re.search(r'QDELETED\((\w+)\)', expr)[1]
            positive = expr.startswith('!QDELETED')
            old = expr.replace(('!' if positive else '') + f'QDELETED({name})',
                (f'{name} && !QDELETED({name})' if positive else f'!{name} || QDELETED({name})'), 1)
            for value, expected in ((None, False if positive else True),
                                    (0, False if positive else True),
                                    (Effect(deleted=True), False if positive else True),
                                    (Effect(lifetime='old'), False if positive else True),
                                    (Effect(), True if positive else False)):
                other = Effect(value.gc_destroyed, value.loc, value.effect_lifetime) if isinstance(value, Effect) else value
                with self.subTest(expr=expr, value=value):
                    self.assertEqual(run(old, name, other), run(expr, name, value))
                    self.assertEqual(run(expr, name, value), ('return', expected))
            if not positive:
                self.assertEqual(run(expr, name, Effect(loc=False)), ('return', True))
                self.assertEqual(run(expr, name, Effect(), 'old'), ('return', True))
            self.assertEqual(run(old, name, 'invalid'), run(expr, name, 'invalid'))

    def test_mutation_controls_and_modeled_count(self):
        for expr in guards(SOURCE):
            name = re.search(r'QDELETED\((\w+)\)', expr)[1]
            positive = expr.startswith('!QDELETED')
            without_deleted = expr.replace(('!' if positive else '') + f'QDELETED({name})', 'TRUE' if positive else 'FALSE', 1)
            self.assertNotEqual(run(expr, name, Effect(deleted=True)), run(without_deleted, name, Effect(deleted=True)))
            if not positive:
                without_system = expr.replace('system_lifetime != activation', 'FALSE', 1)
                self.assertNotEqual(run(expr, name, Effect(), 'old'), run(without_system, name, Effect(), 'old'))
            token = f'{name}.effect_lifetime ' + ('== lifetime' if name == 'E' else '== effect_activation' if positive else '!= effect_activation')
            without_token = expr.replace(token, 'TRUE' if positive else 'FALSE', 1)
            self.assertNotEqual(run(expr, name, Effect(lifetime='old')), run(without_token, name, Effect(lifetime='old')))
            old = expr.replace(('!' if positive else '') + f'QDELETED({name})',
                (f'{name} && !QDELETED({name})' if positive else f'!{name} || QDELETED({name})'), 1)
            before, after = Effect(), Effect()
            self.assertEqual(run(old, name, before), run(expr, name, after))
            self.assertEqual((before.truth_checks, after.truth_checks), (2, 1))


if __name__ == '__main__':
    unittest.main()
