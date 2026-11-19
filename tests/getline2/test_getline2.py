"""Offline source-projected getline2 contract; no BYOND process is launched.

The test executes the complete production procedure using the existing audited
DM subset adapter and fake atom, list and locate boundaries. It does not model
BYOND compilation, scheduling, or native turf/list semantics.
"""
import importlib.util
from pathlib import Path
import re
import unittest
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    'getline_source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


class DMList(list):
    def __iadd__(self, value):
        self.append(value)
        return self


def projected_getline(mutate=None):
    source = (ROOT / 'code/_helpers/unsorted.dm').read_text(encoding='utf-8-sig')
    # Capture through the first unindented declaration/directive, including all
    # executable body lines. Unexpected DM syntax fails in the shared adapter.
    match = re.search(r'^/proc/getline2\([^\n]*\)\n(?:(?:\t[^\n]*|[ \t]*)\n)*', source, re.M)
    if not match:
        raise AssertionError('getline2 procedure missing')
    body = match.group() + '/proc/end_projection()\n'
    if mutate:
        body = mutate(body)
    replacements = {
        '\tvar/i\n': '\tvar/i = null\n',
        'for(i = 0; i <= longest; i++)': 'for(i in range(longest + 1))',
    }
    for before, after in replacements.items():
        if body.count(before) != 1:
            raise AssertionError('getline2 projection requires exactly one: ' + before)
        body = body.replace(before, after)
    # Expand DM's inline else-if statements for the shared subset adapter.
    body = re.sub(r'^(\t*)else if\s*(\([^\n]*?\))\s+([^\n]+)$',
                  lambda m: m[1] + 'else if' + m[2] + '\n' + m[1] + '\t' + m[3],
                  body, flags=re.M)
    return adapter.project(body, '/proc/getline2',
                           'from_atom, to_atom, include_from_atom=True',
                           {'list': DMList, 'locate': lambda x, y, z: (x, y, z)})


def expected_line(start, end, include_start):
    if start is None or end is None:
        return 0
    dx, dy = end.x - start.x, end.y - start.y
    ax, ay = abs(dx), abs(dy)
    major = max(ax, ay)
    sx = (dx > 0) - (dx < 0)
    sy = (dy > 0) - (dy < 0)
    if not major:
        return [(start.x, start.y, start.z)] if include_start else []
    minor = min(ax, ay)
    result = []
    for step in range(0 if include_start else 1, major + 1):
        minor_step = (major // 2 + step * minor) // major
        if ax > ay:
            result.append((start.x + sx * step, start.y + sy * minor_step, start.z))
        else:
            result.append((start.x + sx * minor_step, start.y + sy * step, start.z))
    return result


def atom(x, y, z):
    return SimpleNamespace(x=x, y=y, z=z)


def mutate_once(text, before, after):
    if text.count(before) != 1:
        raise AssertionError('negative control source drift: ' + before)
    return text.replace(before, after)


class GetlineContract(unittest.TestCase):
    def test_octants_ties_endpoints_inclusion_and_z(self):
        run = projected_getline()
        baseline = projected_getline(lambda body: mutate_once(
            body,
            '\t\tvar/previous_longest = longest\n\t\tlongest = shortest\n\t\tshortest = previous_longest',
            '\t\tlongest = abs(h)\n\t\tshortest = abs(w)'))
        start = atom(12, 12, 1)
        for dx in range(-8, 9):
            for dy in range(-8, 9):
                for target_z in (1, 2):
                    end = atom(start.x + dx, start.y + dy, target_z)
                    for include in (False, True):
                        with self.subTest(dx=dx, dy=dy, target_z=target_z, include=include):
                            self.assertEqual(run(start, end, include), expected_line(start, end, include))
                            self.assertEqual(run(start, end, include), baseline(start, end, include))
        self.assertEqual(run(start, atom(14, 13, 1)), expected_line(start, atom(14, 13, 1), True))
        for start_arg, end_arg in ((None, start), (start, None), (None, None)):
            self.assertEqual(run(start_arg, end_arg), 0)

    def test_negative_control_detects_tie_change(self):
        run = projected_getline(lambda body: mutate_once(
            body, 'if(!(numerator < longest))', 'if(numerator > longest)'))
        start, end = atom(10, 10, 1), atom(12, 11, 1)
        self.assertNotEqual(run(start, end), expected_line(start, end, True))

    def test_negative_control_detects_wrong_z(self):
        run = projected_getline(lambda body: mutate_once(
            body, 'locate(cur_x,cur_y,from_atom.z)', 'locate(cur_x,cur_y,to_atom.z)'))
        start, end = atom(10, 10, 1), atom(12, 11, 2)
        self.assertNotEqual(run(start, end), expected_line(start, end, True))


if __name__ == '__main__':
    unittest.main()
