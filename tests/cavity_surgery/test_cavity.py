"""Exercise projected surgery predicates with deterministic engine boundaries.

This is source control-flow evidence, not native DM execution or gameplay.
"""
from pathlib import Path
from types import SimpleNamespace
import re
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'save_movement'))
from source_adapter import extract, project, read

SOURCE = 'code/modules/surgery/implant.dm'
PARENT = '/datum/surgery_step/cavity'
CLOSE = PARENT + '/close_space'
REMOVAL = '/datum/surgery_step/internal/implant_removal'


def type_body(source, path):
    match = re.search(r'^' + re.escape(path) + r'\n((?:\t[^\n]*\n|\n)*)', source, re.M)
    if not match:
        raise AssertionError('Missing surgery type: ' + path)
    return match.group()


def can_close(source, organ, has_organs=True):
    parent = extract(type_body(source, PARENT), 'can_use')
    child = extract(type_body(source, CLOSE), 'can_use')
    # Python's conditional expression represents the equivalent DM ternary.
    parent = parent.replace('(affected.encased ? 3 : 2)', '(3 if affected.encased else 2)')
    child = child.replace('..()', 'parent_can_use(user, target, target_zone, tool)')
    target = SimpleNamespace(get_organ=lambda _: organ)
    env = {'hasorgans': lambda _: has_organs, 'ORGAN_BLEEDING': 1}
    parent_fn = project('/proc/parent()\n' + parent + '\n', '/proc/parent',
                        'user, target, target_zone, tool', env)
    env['parent_can_use'] = parent_fn
    child_fn = project('/proc/child()\n' + child + '\n', '/proc/child',
                       'user, target, target_zone, tool', env)
    return bool(child_fn(None, target, None, None))


def finds_implant(source, coefficient, roll):
    body = extract(type_body(source, REMOVAL), 'end_step')
    # Project the source's chance initialization and full if condition. Calls
    # to prob and getStatCoeff are controlled boundaries, not reimplemented DM.
    initial = re.search(r'^\s*var/find_prob\s*=\s*[^\n]+$', body, re.M)
    increment = re.search(r'^\s*find_prob\s*\+=\s*[^\n]+$', body, re.M)
    condition = re.search(r'^\s*if\s*\([^\n]*\bprob\([^\n]+$', body, re.M)
    if not initial or not increment or not condition:
        raise AssertionError('Missing implant search chance or condition')
    code = ('/proc/search()\n\t' + initial.group().strip() + '\n\t' +
            increment.group().strip() + '\n\t' + condition.group().strip() +
            '\n\t\treturn TRUE\n\treturn FALSE\n')
    surgeon = SimpleNamespace(getStatCoeff=lambda stat: coefficient if stat == 'medical' else None)
    fn = project(code, '/proc/search', 'H', {'prob': lambda chance: roll <= chance})
    return bool(fn(surgeon))


def organ(*, opening=2, encased=False, cavity=True, bleeding=False):
    return SimpleNamespace(open=opening, encased=encased, cavity=cavity,
                           status=1 if bleeding else 0)


class CavitySurgery(unittest.TestCase):
    def test_closing_requires_a_prepared_cavity_and_parent_surgery_gate(self):
        source = read(SOURCE)
        for case in (organ(), organ(opening=3, encased=True)):
            self.assertTrue(can_close(source, case))
        for case in (None, organ(cavity=False), organ(opening=0),
                     organ(opening=3), organ(opening=2, encased=True),
                     organ(bleeding=True)):
            self.assertFalse(can_close(source, case))
        self.assertFalse(can_close(source, organ(), has_organs=False))

    def test_close_completion_clears_cavity(self):
        body = extract(type_body(read(SOURCE), CLOSE), 'end_step')
        self.assertRegex(body, r'(?m)^\s*affected\.cavity\s*=\s*FALSE\s*$')

    def test_search_roll_scales_with_medical_skill(self):
        source = read(SOURCE)
        self.assertFalse(finds_implant(source, 0.5, 26))
        self.assertTrue(finds_implant(source, 0.5, 25))
        self.assertFalse(finds_implant(source, 1, 51))
        self.assertTrue(finds_implant(source, 1, 50))
        self.assertTrue(finds_implant(source, 1.5, 75))
        self.assertFalse(finds_implant(source, 1.5, 76))

    def test_original_defects_are_detected_as_negative_controls(self):
        source = read(SOURCE)
        close = type_body(source, CLOSE)
        changed_close, count = re.subn(r'(?m)^(\t\t\t)return [^\n]+$',
                               r'\1return affected && !affected.cavity && affected.open == FALSE',
                               close, count=1)
        self.assertEqual(count, 1)
        broken_close = source.replace(close, changed_close, 1)
        self.assertFalse(can_close(broken_close, organ()))

        removal = type_body(source, REMOVAL)
        broken_removal, count = re.subn(r'(?m)^(\t+)(if\s*\([^\n]*\bprob\([^\n]+)$',
                                       r'\1if (prob(find_prob)*H.getStatCoeff("medical"))',
                                       removal, count=1)
        self.assertEqual(count, 1)
        changed = source.replace(removal, broken_removal, 1)
        self.assertTrue(finds_implant(changed, 0.5, 26))
        self.assertFalse(finds_implant(changed, 1.5, 75))


if __name__ == '__main__':
    unittest.main()
