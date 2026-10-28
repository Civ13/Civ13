"""Source-derived zone header compatibility; no compiler, daemon or sockets."""
import ast
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
PATH = 'code/modules/persistence/zone_topology.dm'
BASE = '99647037c70786a3c3944fcf5ae51b570b377f08'


class FormatCompatibility(unittest.TestCase):
    def test_only_typed_version_admission_changes_from_pinned_master(self):
        before = subprocess.check_output(['git', 'show', BASE+':'+PATH], cwd=ROOT, text=True)
        anchor = 'F["/format_version"] != 2'
        self.assertEqual(before.count(anchor), 1)
        self.assertEqual((ROOT/PATH).read_text(), before.replace(anchor,
            '!(F["/format_version"] in list(2, 3))', 1))

    def test_actual_guard_accepts_only_typed_versions_with_matching_generation_and_dimensions(self):
        source = (ROOT/PATH).read_text()
        condition, = re.findall(r'if\(([^\n]+)\) throw EXCEPTION\("Zone capture header differs"\)', source)
        expression = condition.replace('||', ' or ').replace('!(', 'not (').replace('list(2, 3)', '(2, 3)')
        for field in ('maxx', 'maxy'):
            expression = expression.replace('world.'+field, 'expected["/'+field+'"]')
        expression = expression.replace('save_validation_maxz()', 'expected["/maxz"]')
        tree = ast.parse(expression, mode='eval')
        allowed = (ast.Expression, ast.BoolOp, ast.Or, ast.UnaryOp, ast.Not,
                   ast.Compare, ast.In, ast.NotEq, ast.Subscript, ast.Name,
                   ast.Load, ast.Constant, ast.Tuple)
        self.assertTrue(all(isinstance(node, allowed) for node in ast.walk(tree)))
        guard = compile(tree, str(ROOT/PATH), 'eval')
        expected = {'/generation': 'round-v2:fixture', '/maxx': 3, '/maxy': 4, '/maxz': 2}
        def rejects(fields):
            return eval(guard, {'__builtins__': {}}, dict(F=fields, generation=expected['/generation'], expected=expected))
        for version in (2, 3):
            fields = dict(expected, **{'/format_version': version})
            self.assertFalse(rejects(fields))
            for key in expected:
                self.assertTrue(rejects(dict(fields, **{key: 'wrong'})), (version, key))
        for version in (None, 0, 1, 4, '2', '3', False):
            self.assertTrue(rejects(dict(expected, **{'/format_version': version})), version)
