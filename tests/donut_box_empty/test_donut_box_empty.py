"""Project donut-box constructor dispatch with fake BYOND object creation.

Direct subtype instantiation is the tested trigger. This is source control-flow
coverage and does not prove that a map or recipe creates the empty subtype.
"""
import hashlib
import importlib.util
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/objects/items/weapons/storage/fancy.dm'
ORIGINAL = ROOT / 'tests/egg_box_count/original_fancy.dm'
ORIGINAL_BLOB = '5cbb5012da270d9374244b53eb32c668f8ddd74d'
BASE = '/obj/item/weapon/storage/fancy/donut_box'
EMPTY = BASE + '/empty'
spec = importlib.util.spec_from_file_location('source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


def type_block(source, typename):
    pattern = r'^' + re.escape(typename) + r'/?[ \t]*\n((?:\t[^\n]*\n|\n)*)'
    matches = list(re.finditer(pattern, source, re.M))
    if len(matches) != 1:
        raise AssertionError('Expected one declaration block for ' + typename)
    return matches[0].group(1)


def project_constructor(source, empty, current):
    """Execute both constructor bodies, substituting only engine boundaries."""
    contents = []
    base_block = type_block(source, BASE)
    empty_block = type_block(source, EMPTY)
    if 'var/list/donut_types = list(' not in base_block:
        raise AssertionError('Donut selection metadata changed')
    if current:
        if not re.search(r'^\tvar/fill_on_spawn\s*=\s*TRUE\s*$', base_block, re.M):
            raise AssertionError('Default spawn mode changed')
        if not re.search(r'^\tfill_on_spawn\s*=\s*FALSE\s*$', empty_block, re.M):
            raise AssertionError('Empty subtype spawn mode changed')
        if re.search(r'^' + re.escape(EMPTY) + r'/New\(', source, re.M):
            raise AssertionError('Unexpected empty subtype constructor')

    body = adapter.extract(source, BASE + '/New')
    if body.count('..()') != 1:
        raise AssertionError('Unexpected parent constructor dispatch')
    body = body.replace('..()', 'super_init()')
    old_loop = 'for (var/i=1; i <= 2; i++)'
    if body.count(old_loop) != 1:
        raise AssertionError('Unexpected donut creation loop')
    body = body.replace(old_loop, 'for (i in range(1, 3))')
    body, count = re.subn(r'\bnew (random_donut\d*)\(src\)', r'spawn_donut(\1)', body)
    if count != 3:
        raise AssertionError('Unexpected donut creation expressions')
    parent_env = {'super_init': lambda: None, 'spawn_donut': contents.append,
                  'donut_types': ['plain', 'chocolate', 'berry'],
                  'pick': lambda choices: choices[0], 'range': range,
                  'fill_on_spawn': not (current and empty)}
    parent = adapter.project('/fixture/donut_new()\n' + body + '\n',
                             '/fixture/donut_new', '', parent_env)
    if not current and empty:
        child = adapter.extract(source, EMPTY + '/New')
        if child.count('..()') != 1:
            raise AssertionError('Unexpected empty parent dispatch')
        child = child.replace('..()', 'super_init()')
        child_env = {'super_init': parent}
        run = adapter.project('/fixture/empty_new()\n' + child + '\n',
                              '/fixture/empty_new', '', child_env)
        run()
    else:
        parent()
    return contents


class DonutBoxEmptyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = SOURCE.read_text(encoding='utf-8-sig')
        data = ORIGINAL.read_bytes().replace(b'\r\n', b'\n')
        digest = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
        if digest != ORIGINAL_BLOB:
            raise AssertionError('Original source fixture does not match the master blob')
        cls.original = data.decode('utf-8-sig')

    def test_original_empty_subtype_inherits_six_donuts(self):
        self.assertEqual(len(project_constructor(self.original, True, False)), 6)
        self.assertEqual(len(project_constructor(self.original, False, False)), 6)

    def test_empty_subtype_creates_none_but_normal_box_creates_six(self):
        self.assertEqual(project_constructor(self.source, True, True), [])
        self.assertEqual(len(project_constructor(self.source, False, True)), 6)


if __name__ == '__main__':
    unittest.main()
