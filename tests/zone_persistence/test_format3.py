"""Source-derived zone header compatibility; no compiler, daemon or sockets."""
import ast
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
PATH = 'code/modules/persistence/zone_topology.dm'


class FormatCompatibility(unittest.TestCase):
    def test_zone_row_listing_is_detached_before_membership_navigation(self):
        source = (ROOT/PATH).read_text()
        body = source.split('/map_storage/proc/prepare_saved_zones(', 1)[1].split('\n/map_storage/', 1)[0]

        def check_detached_rows(text):
            listing = text.index('F.cd = "/map/[z]"')
            copied = text.index('var/list/rows = F.dir.Copy()', listing)
            checked = text.index('if(!("[y]" in rows)) throw EXCEPTION("Missing captured zone row z=[z] y=[y]")', copied)
            self.assertLess(checked, text.index('F.cd = "/zone_capture/[ref]"', checked))

        check_detached_rows(body)
        with self.assertRaises((AssertionError, ValueError)):
            check_detached_rows(body.replace('var/list/rows = F.dir.Copy()', 'var/list/rows = F.dir', 1))

    def test_turf_validation_reads_by_path_without_per_turf_directory_listing(self):
        # Listing or indexing a whole level's savefile directory is quadratic;
        # each turf reads its own entries by absolute path and the loop still yields.
        source = (ROOT/PATH).read_text()
        self.assertNotIn('savefile_dir_index', source)
        self.assertNotIn('"[ref]" in F.dir', source)
        self.assertNotIn('"[x]" in F.dir', source)
        loop = source.split('for(var/x = 1, x <= world.maxx, x++)', 1)[1].split('var/list/spawns', 1)[0]
        self.assertIn('var/ref = F["/map/[z]/[y]/[x]"]', loop)
        self.assertIn('if(isnull(F["/zone_capture/[ref]/id"])) throw EXCEPTION("Missing captured membership entry")', loop)
        self.assertRegex(loop, r'validated_zone_grid \+= id\n\t+TICK_CHECK\n')

    def test_zone_header_admits_typed_versions_2_and_3_only(self):
        source = (ROOT/PATH).read_text()
        self.assertEqual(source.count('!(F["/format_version"] in list(2, 3))'), 1)
        self.assertNotIn('F["/format_version"] != 2', source)

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
