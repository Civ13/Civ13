"""No type check joins two type paths with || inside one call.

In DM `istype(X, /a || /b)` evaluates `/a || /b` first, which is just `/a`,
so the call never tests `/b`. Braziers refused wood planks and broken single
wooden doors dropped nothing because of this. Write one call per path instead:
`istype(X, /a) || istype(X, /b)`. Comments are ignored.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
CALL = re.compile(r'\b(istype|ispath|locate)\(')
JOINED = re.compile(r'/[\w/]+\s*(\|\||&&)\s*/[\w/]')


def call_args(line, start):
    depth = 0
    for i in range(start, len(line)):
        if line[i] == '(':
            depth += 1
        elif line[i] == ')':
            depth -= 1
            if depth == 0:
                return line[start + 1:i]
    return line[start + 1:]


def joined_paths(text):
    found = []
    for number, line in enumerate(text.split('\n'), 1):
        code = line.split('//', 1)[0]
        for match in CALL.finditer(code):
            if JOINED.search(call_args(code, match.end() - 1)):
                found.append(number)
                break
    return found


class JoinedTypePathTest(unittest.TestCase):
    def test_detector(self):
        self.assertEqual(joined_paths('if (istype(W, /obj/a || /obj/b))'), [1])
        self.assertEqual(joined_paths('if (istype(W, /obj/a) || istype(W, /obj/b))'), [])
        self.assertEqual(joined_paths('// istype(O, /a||/b) only tests /a'), [])

    def test_code_has_no_joined_paths(self):
        bad = []
        for path in sorted((ROOT / 'code').rglob('*.dm')):
            text = path.read_text(encoding='utf-8', errors='replace')
            for number in joined_paths(text):
                bad.append(f'{path.relative_to(ROOT).as_posix()}:{number}')
        self.assertEqual(bad, [], 'type check joins paths with ||; use one call per path: ' + ', '.join(bad))


if __name__ == '__main__':
    unittest.main()
