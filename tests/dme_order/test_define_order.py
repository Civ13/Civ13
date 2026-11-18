"""civ13.dme must compile in its own include order and in the alphabetical
order the Dream Maker IDE writes when it saves the environment.

DM's preprocessor runs in include order, so a macro used in a file that comes
before the file defining it is an undefined macro (or "unexpected token" in an
#if). Shared defines belong in code/__defines/, which sorts first either way.
Stdlib only; no compiler needed.
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFINE = re.compile(r'^\s*#\s*define\s+([A-Za-z_][A-Za-z0-9_]*)', re.M)
UNDEF = re.compile(r'^\s*#\s*undef\s+([A-Za-z_][A-Za-z0-9_]*)', re.M)
TOKEN = re.compile(r'\b[A-Z][A-Z0-9_]{2,}\b')
STRING = re.compile(r'"(?:[^"\\\n]|\\.)*"')


def includes(text):
    block = text.split('// BEGIN_INCLUDE', 1)[1].split('// END_INCLUDE', 1)[0]
    return [line.split('"')[1].replace('\\', '/') for line in block.splitlines()
            if line.startswith('#include "') and line.split('"')[1].endswith('.dm')]


def ide_sorted(paths):
    """Dream Maker's order: case-insensitive, a folder's files before its subfolders."""
    def key(path):
        parts = path.lower().split('/')
        return [(1, part) for part in parts[:-1]] + [(0, parts[-1])]
    return sorted(paths, key=key)


def code_text(text):
    # A macro body expands where it is used, so names inside it may come later.
    text = re.sub(r'^\s*#\s*define\b(?:[^\n]*\\\n)*[^\n]*', ' ', text, flags=re.M)
    text = re.sub(r'/\*.*?\*/', ' ', text, flags=re.S)
    text = re.sub(r'//[^\n]*', ' ', text)
    return STRING.sub('""', text)


def order_violations(order, sources):
    """(user, macro, definer) for each macro used before every file defining it."""
    position = {path: index for index, path in enumerate(order)}
    definers = {}
    local = {}
    for path in order:
        text = sources[path]
        undefined = set(UNDEF.findall(text))
        local[path] = set(DEFINE.findall(text))
        for name in local[path] - undefined:
            definers.setdefault(name, []).append(path)
    found = []
    for path in order:
        for name in sorted(set(TOKEN.findall(code_text(sources[path]))) - local[path]):
            files = definers.get(name)
            if files and min(position[f] for f in files) > position[path]:
                found.append((path, name, min(files, key=position.get)))
    return found


class DefineOrderTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.order = includes((ROOT / 'civ13.dme').read_text(encoding='utf-8'))
        cls.sources = {path: (ROOT / path).read_text(encoding='utf-8', errors='replace') for path in cls.order}

    def check(self, order):
        found = order_violations(order, self.sources)
        self.assertEqual([], found[:20], '%d macro(s) used before their define; move them to code/__defines/' % len(found))

    def test_listed_order(self):
        self.check(self.order)

    def test_dream_maker_sorted_order(self):
        self.check(ide_sorted(self.order))

    def test_checker_catches_a_late_define(self):
        sources = {'code/a.dm': '#if LATE_FLAG\n#endif\nvar/x = LATE_VALUE // LATE_COMMENT\n',
                   'code/b.dm': '#define LATE_FLAG 1\n#define LATE_VALUE 2\n#define LATE_COMMENT 3\n'}
        found = order_violations(['code/a.dm', 'code/b.dm'], sources)
        self.assertEqual([('code/a.dm', 'LATE_FLAG', 'code/b.dm'), ('code/a.dm', 'LATE_VALUE', 'code/b.dm')], found)
        self.assertEqual([], order_violations(['code/b.dm', 'code/a.dm'], sources))

    def test_macro_bodies_expand_where_used(self):
        sources = {'code/a.dm': '#define EARLY (LATE_VALUE + 1)\n', 'code/b.dm': '#define LATE_VALUE 2\nvar/x = EARLY\n'}
        self.assertEqual([], order_violations(['code/a.dm', 'code/b.dm'], sources))

    def test_file_local_defines_are_ignored(self):
        sources = {'code/a.dm': 'var/x = LOCAL_ONLY\n', 'code/b.dm': '#define LOCAL_ONLY 1\n#undef LOCAL_ONLY\n'}
        self.assertEqual([], order_violations(['code/a.dm', 'code/b.dm'], sources))

    def test_ide_sort_puts_folder_files_first(self):
        self.assertEqual(['code/__defines/a.dm', 'code/game/z.dm', 'code/modules/A/b.dm'],
                         ide_sorted(['code/modules/A/b.dm', 'code/game/z.dm', 'code/__defines/a.dm']))
        self.assertEqual(['code/z.dm', 'code/a/b.dm'], ide_sorted(['code/a/b.dm', 'code/z.dm']))


if __name__ == '__main__':
    unittest.main()
