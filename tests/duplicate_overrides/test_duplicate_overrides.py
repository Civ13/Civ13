"""No proc override is defined twice for the same type in one file.

When a file overrides the same proc on the same type twice and the later body
never calls ..(), the earlier body is dead. Every case found so far was a
copy-paste that meant to target a sibling type (PMC Sergeant kit, Arab Town 2
names, crusader gold upgrade, creed hood), so new ones fail here. Bodies under
preprocessor conditionals and proc/verb declarations are not compared.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
HEADER = re.compile(r'^(/[\w/]+?)/((?:proc/|verb/)?)(\w+)\(')


def dead_overrides(path, text):
    found = []
    seen = {}
    lines = text.split('\n')
    depth = 0
    comment = False
    for i, line in enumerate(lines):
        if comment:
            if '*/' in line:
                comment = False
            continue
        if line.startswith('/*') and '*/' not in line:
            comment = True
            continue
        if re.match(r'#\s*if', line):
            depth += 1
            continue
        if re.match(r'#\s*endif', line):
            depth -= 1
            continue
        match = HEADER.match(line)
        if not match or depth:
            continue
        body = []
        for following in lines[i + 1:]:
            if following.startswith('\t') or not following.strip():
                body.append(following)
            else:
                break
        key = (match.group(1), match.group(3))
        if key in seen and match.group(2) == '' and '..(' not in '\n'.join(body):
            found.append(f'{path}:{i + 1} {key[0]}/{key[1]} hides line {seen[key]}')
        if match.group(2) != 'proc/':
            seen[key] = i + 1
    return found


def scan(root=ROOT):
    found = []
    for path in sorted((root / 'code').rglob('*.dm')):
        text = path.read_text(encoding='utf-8', errors='replace')
        found += dead_overrides(path.relative_to(root).as_posix(), text)
    return found


class DuplicateOverrides(unittest.TestCase):
    def test_no_dead_duplicate_overrides(self):
        self.assertEqual(scan(), [])

    def test_detects_hidden_override(self):
        text = '/obj/a/foo()\n\treturn 1\n\n/obj/a/foo()\n\treturn 2\n'
        self.assertEqual(len(dead_overrides('x.dm', text)), 1)

    def test_allows_parent_call_and_conditionals(self):
        text = ('/obj/a/foo()\n\treturn 1\n\n/obj/a/foo()\n\t. = ..()\n'
                '#ifdef X\n/obj/b/bar()\n\treturn 1\n#else\n/obj/b/bar()\n\treturn 2\n#endif\n')
        self.assertEqual(dead_overrides('x.dm', text), [])


if __name__ == '__main__':
    unittest.main()
