"""Project fancy-box count expressions, with fake item-type and DM boundaries.

This verifies source-level counting; it does not execute BYOND or render icons.
"""
import ast
import hashlib
import importlib.util
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/objects/items/weapons/storage/fancy.dm'
ORIGINAL = Path(__file__).with_name('original_fancy.dm')
ORIGINAL_BLOB = '5cbb5012da270d9374244b53eb32c668f8ddd74d'
EGG = '/obj/item/weapon/reagent_containers/food/snacks/egg'
BOILED = '/obj/item/weapon/reagent_containers/food/snacks/boiledegg'
NON_EGG = '/obj/item/weapon/reagent_containers/food/snacks/donut'
spec = importlib.util.spec_from_file_location('source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


def safe_expression(expression, env):
    """Evaluate only the count operations we deliberately model; reject drift."""
    expression = expression.replace('..()', 'parent_count()')
    expression = expression.replace(BOILED, 'BOILED')
    tree = ast.parse(expression, mode='eval')
    permitted = (ast.Expression, ast.Call, ast.Name, ast.Load, ast.BinOp, ast.Add)
    for node in ast.walk(tree):
        if not isinstance(node, permitted):
            raise AssertionError('Unexpected count expression: ' + expression)
        if isinstance(node, ast.Name) and node.id not in env:
            raise AssertionError('Unexpected count symbol: ' + node.id)
        if isinstance(node, ast.Call) and (not isinstance(node.func, ast.Name) or node.keywords):
            raise AssertionError('Unsupported count call: ' + expression)
    return eval(compile(tree, '<count expression>', 'eval'), {'__builtins__': {}}, env)


def projected_counts(source, contents, current):
    def count_by_type(items, kind):
        return sum(item == kind or item.startswith(kind + '/') for item in items)

    env = {'contents': contents, 'key_type': EGG, 'BOILED': BOILED,
           'count_by_type': count_by_type}
    if current:
        base = adapter.extract(source, '/obj/item/weapon/storage/fancy/proc/count_key_items')
        egg = adapter.extract(source, '/obj/item/weapon/storage/fancy/egg_box/count_key_items')

        def expression(body):
            statements = [line.strip() for line in body.splitlines() if line.strip()]
            if len(statements) != 1 or not statements[0].startswith('return '):
                raise AssertionError('Count helper has unexpected behavior')
            return statements[0][len('return '):]

        base_expression, egg_expression = expression(base), expression(egg)
        env['parent_count'] = lambda: safe_expression(base_expression, env)
        env['count_key_items'] = lambda: safe_expression(egg_expression, env)

    results = []
    for declaration in ('/obj/item/weapon/storage/fancy/update_icon',
                        '/obj/item/weapon/storage/fancy/examine'):
        body = adapter.extract(source, declaration)
        assignments = re.findall(r'^\s*var/key_count\s*=\s*(.+)$', body, re.M)
        if len(assignments) != 1:
            raise AssertionError('Expected one count assignment in ' + declaration)
        results.append(safe_expression(assignments[0], env))
    return tuple(results)


class EggBoxCountTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = SOURCE.read_text(encoding='utf-8-sig')
        data = ORIGINAL.read_bytes().replace(b'\r\n', b'\n')
        digest = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
        if digest != ORIGINAL_BLOB:
            raise AssertionError('Original source fixture does not match the master blob')
        cls.original = data.decode('utf-8-sig')

    def test_egg_box_accepts_raw_and_boiled_eggs(self):
        block = self.source.split('/obj/item/weapon/storage/fancy/egg_box\n', 1)[1]
        block = block.split('/obj/item/weapon/storage/fancy/egg_box/empty', 1)[0]
        hold = re.search(r'\bcan_hold\s*=\s*list\((.*?)\)', block, re.S)
        self.assertIsNotNone(hold)
        self.assertEqual({part.strip() for part in hold.group(1).split(',') if part.strip()}, {EGG, BOILED})

    def test_frozen_original_misses_boiled_eggs(self):
        self.assertEqual(projected_counts(self.original, [EGG, BOILED], False), (1, 1))
        self.assertEqual(projected_counts(self.original, [BOILED], False), (0, 0))

    def test_opened_box_icon_and_examine_count_every_egg(self):
        for contents, expected in (([], 0), ([EGG], 1), ([BOILED], 1),
                                   ([EGG, BOILED, BOILED], 3),
                                   ([EGG + '/fertile', BOILED, NON_EGG], 2),
                                   ([NON_EGG], 0)):
            with self.subTest(contents=contents):
                self.assertEqual(projected_counts(self.source, contents, True), (expected, expected))


if __name__ == '__main__':
    unittest.main()
