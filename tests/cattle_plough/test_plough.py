"""Offline differential projection of cattle plough selection, not a DM runtime."""
import ast
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/mob/living/simple_animal/friendly/farm_animals.dm'
HEADER = '/mob/living/simple_animal/cattle/Life()'

# Frozen from the parent source before caching. Keep independent of Git history.
BASELINE = '''\
\t. = ..()
\tif (stat == CONSCIOUS)
\t\tif ( plough && pulledby)
\t\t\tif ( istype(get_turf(src), /turf/floor/grass/jungle) )
\t\t\telse if ( istype(get_turf(src), /turf/floor/dirt/burned) )
\t\t\telse if ( istype(get_turf(src), /turf/floor/dirt/jungledirt) )
\t\t\telse if (istype(get_turf(src), /turf/floor/grass) && !istype(get_turf(src), /turf/floor/grass/jungle))
\t\t\t\tdo_plough(src)
\t\t\telse if (istype(get_turf(src), /turf/floor/dirt) && !(istype(get_turf(src), /turf/floor/dirt/ploughed)) && !(istype(get_turf(src), /turf/floor/dirt/dust)))
\t\t\t\tdo_plough(src)
'''


def source_block():
    source = SOURCE.read_text(encoding='utf-8')
    rest = source.split(HEADER + '\n', 1)[1]
    return rest.split('\n/mob/', 1)[0]


def expression(text, state):
    """Evaluate only the small, explicitly permitted DM expression subset."""
    text = text.replace('get_turf(src)', 'get_turf()')
    text = re.sub(r'(/turf(?:/[a-z_]+)+)', lambda m: repr(m.group(1)), text)
    text = text.replace('&&', ' and ').replace('||', ' or ')
    text = re.sub(r'!(?!=)', ' not ', text).strip()
    tree = ast.parse(text, mode='eval')
    allowed = (ast.Expression, ast.BoolOp, ast.And, ast.Or, ast.UnaryOp,
               ast.Not, ast.Compare, ast.Eq, ast.Name, ast.Load, ast.Call,
               ast.Constant)
    for node in ast.walk(tree):
        if not isinstance(node, allowed):
            raise ValueError(f'Unsupported expression: {text!r}, {node!r}')
        if isinstance(node, ast.Name) and node.id not in state:
            raise ValueError(f'Unexpected name: {node.id}')
        if isinstance(node, ast.Call) and (not isinstance(node.func, ast.Name)
                                           or node.func.id not in ('istype', 'get_turf')):
            raise ValueError(f'Unexpected call: {text}')
    return eval(compile(tree, '<DM selection>', 'eval'), {'__builtins__': {}}, state)


def project(block, turf, conscious=True, plough=True, pulled=True):
    """Interpret indentation and branching; reject unfamiliar statements."""
    rows = []
    for raw in block.splitlines():
        text = raw.split('//', 1)[0].strip()
        if not text or text == '. = ..()':
            continue
        depth = len(raw) - len(raw.lstrip('\t'))
        rows.append((depth, text))
    calls = []
    state = {'stat': int(conscious), 'CONSCIOUS': 1, 'plough': plough,
             'pulledby': pulled, 'get_turf': lambda: turf,
             'istype': lambda value, typ: bool(value) and
                 (value == typ or value.startswith(typ + '/'))}

    def run(start, depth, enabled):
        index = start
        last_if = False
        while index < len(rows):
            level, text = rows[index]
            if level < depth:
                break
            if level != depth:
                raise ValueError(f'Unexpected indentation: {rows[index]}')
            branch = re.fullmatch(r'(if|else if)\s*\((.*)\)', text)
            if branch:
                kind, condition = branch.groups()
                if kind == 'if':
                    last_if = False
                active = enabled and not last_if and bool(expression(condition, state))
                if active:
                    last_if = True
                index += 1
                if index < len(rows) and rows[index][0] > depth:
                    if rows[index][0] != depth + 1:
                        raise ValueError('Unexpected nesting')
                    index = run(index, depth + 1, active)
                continue
            if text == 'var/turf/plough_turf = get_turf(src)':
                if enabled:
                    state['plough_turf'] = turf
            elif text == 'do_plough(src)':
                if enabled:
                    calls.append('do_plough')
            else:
                raise ValueError(f'Unsupported statement: {text!r}')
            index += 1
        return index

    if rows:
        end = run(0, rows[0][0], True)
        if end != len(rows):
            raise ValueError('Unconsumed source')
    return len(calls)


CASES = {
    None: 0,
    '/turf/space': 0,
    '/turf/floor/grass': 1,
    '/turf/floor/grass/ordinary_subtype': 1,
    '/turf/floor/grass/jungle': 0,
    '/turf/floor/grass/jungle/subtype': 0,
    '/turf/floor/dirt': 1,
    '/turf/floor/dirt/flooded': 1,
    '/turf/floor/dirt/underground': 1,
    '/turf/floor/dirt/burned': 0,
    '/turf/floor/dirt/jungledirt': 0,
    '/turf/floor/dirt/ploughed': 0,
    '/turf/floor/dirt/ploughed/flooded': 0,
    '/turf/floor/dirt/dust': 0,
    '/turf/floor/dirt/dust/subtype': 0,
}


class PloughSelectionTest(unittest.TestCase):
    def test_current_and_parent_agree_with_expected_outcomes(self):
        current = source_block()
        for turf, expected in CASES.items():
            for conscious in (False, True):
                for plough in (False, True):
                    for pulled in (False, True):
                        with self.subTest(turf=turf, conscious=conscious, plough=plough, pulled=pulled):
                            result = expected if conscious and plough and pulled else 0
                            self.assertEqual(project(BASELINE, turf, conscious, plough, pulled), result)
                            self.assertEqual(project(current, turf, conscious, plough, pulled), result)

    def test_negative_controls_detect_exclusion_and_guard_regressions(self):
        current = source_block()
        mutants = [
            (current.replace(' && !(istype(plough_turf, /turf/floor/dirt/dust))', ''),
             '/turf/floor/dirt/dust', True, True, True),
            (current.replace('plough && pulledby', 'plough || pulledby'),
             '/turf/floor/grass', True, True, False),
        ]
        for mutant, turf, conscious, plough, pulled in mutants:
            with self.subTest(turf=turf):
                self.assertNotEqual(mutant, current, 'negative control must alter source')
                self.assertNotEqual(project(mutant, turf, conscious, plough, pulled),
                                    project(BASELINE, turf, conscious, plough, pulled))


if __name__ == '__main__':
    unittest.main()
