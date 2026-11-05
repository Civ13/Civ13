"""Map tooling: mapmerge2 parser/merge, UpdatePaths and scripts/maplint.py.

Offline and standard-library only; no BYOND runtime. The git hook wrappers
need pygit2 and are exercised by hand (tools/hooks/README.md).
"""

import contextlib
import importlib.util
import io
import pathlib
import sys
import tempfile
import types
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
TOOLS = ROOT / 'tools'
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

if str(ROOT / 'scripts') not in sys.path:
    sys.path.insert(0, str(ROOT / 'scripts'))

from mapmerge2 import dmm, mapmerge  # noqa: E402
import maplint  # noqa: E402  (importable by name so lint workers can unpickle it)


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


BASE = '''"a" = (/turf/floor/grass,/area/caribbean)
"b" = (/obj/structure/grille/fence{icon_state = "fence"; dir = 4},/turf/floor/dirt,/area/caribbean)

(1,1,1) = {"
aba
"}
'''


def parse(text):
    with contextlib.redirect_stdout(io.StringIO()):
        return dmm.DMM.from_bytes(text.encode())


def render(parsed):
    with contextlib.redirect_stdout(io.StringIO()):
        return parsed.to_bytes().decode()


def tile(parsed, x):
    return parsed.get_tile(dmm.Coordinate(x, 1, 1))


class ParserTests(unittest.TestCase):
    def test_dmm_round_trip_keeps_format_and_spacing(self):
        self.assertEqual(render(parse(BASE)), BASE)

    def test_tgm_maps_stay_tgm(self):
        tgm = render(parse(BASE))
        converted = parse(BASE)
        converted.is_tgm = True
        out = render(converted)
        self.assertTrue(out.startswith(dmm.TGM_HEADER))
        self.assertTrue(render(parse(out)).startswith(dmm.TGM_HEADER))
        self.assertEqual(tgm, BASE)

    def test_bidict_fallback_rejects_duplicate_values(self):
        from mapmerge2 import _bidict
        table = _bidict.bidict()
        table[1] = 'x'
        with self.assertRaises(_bidict.ValueDuplicationError):
            table[2] = 'x'
        clone = table.copy()
        clone.forceput(2, 'x')
        self.assertEqual(clone.inv['x'], 2)
        self.assertNotIn(1, clone)
        self.assertEqual(table.inv['x'], 1)


class MergeTests(unittest.TestCase):
    def test_merge_map_keeps_existing_keys(self):
        old = parse(BASE)
        new = parse(BASE.replace('aba', 'abb'))
        merged = mapmerge.merge_map(new, old)
        self.assertEqual(merged.grid[1, 1, 1], old.grid[1, 1, 1])
        self.assertFalse(merged.is_tgm)

    def test_three_way_merge_combines_both_sides(self):
        stub = types.ModuleType('hooks.merge_frontend')
        stub.MergeDriver = object
        package = types.ModuleType('hooks')
        package.merge_frontend = stub
        saved = {k: sys.modules.get(k) for k in ('hooks', 'hooks.merge_frontend')}
        sys.modules.update({'hooks': package, 'hooks.merge_frontend': stub})
        try:
            driver = importlib.import_module('mapmerge2.merge_driver')
        finally:
            for key, value in saved.items():
                if value is None:
                    sys.modules.pop(key, None)
                else:
                    sys.modules[key] = value
        rods = '"c" = (/obj/item/stack/rods,/turf/floor/grass,/area/caribbean)\n'
        bed = '"c" = (/obj/structure/bed,/turf/floor/grass,/area/caribbean)\n'
        left = parse(BASE.replace('\n\n(1', '\n' + rods + '\n(1').replace('aba', 'cba'))
        right = parse(BASE.replace('\n\n(1', '\n' + bed + '\n(1').replace('aba', 'abc'))
        with contextlib.redirect_stdout(io.StringIO()):
            trouble, merged = driver.three_way_merge(parse(BASE), left, right)
        self.assertFalse(trouble)
        self.assertIn('/obj/item/stack/rods', tile(merged, 1))
        self.assertIn('/obj/structure/bed', tile(merged, 3))
        self.assertFalse(merged.is_tgm)


class UpdatePathsTests(unittest.TestCase):
    def setUp(self):
        saved = sys.argv
        self.update = load('civ13_update_paths', TOOLS / 'UpdatePaths' / '__main__.py')
        sys.argv = saved

    def test_rewrites_matching_paths_only(self):
        with tempfile.TemporaryDirectory() as folder:
            hit = pathlib.Path(folder, 'hit.dmm')
            miss = pathlib.Path(folder, 'miss.dmm')
            hit.write_text(BASE, encoding='utf-8')
            odd = BASE + '\n'  # a cosmetic difference the writer would normalise
            miss.write_text(odd, encoding='utf-8')
            with contextlib.redirect_stdout(io.StringIO()):
                self.update.update_map(str(hit), ['/turf/floor/dirt : /turf/floor/dirt/mud'])
                self.update.update_map(str(miss), ['/turf/floor/sand : /turf/floor/dirt'])
            self.assertIn('/turf/floor/dirt/mud,/area/caribbean', hit.read_text(encoding='utf-8'))
            self.assertIn('icon_state = "fence"; dir = 4', hit.read_text(encoding='utf-8'))
            self.assertEqual(miss.read_text(encoding='utf-8'), odd)


class MaplintTests(unittest.TestCase):
    def lint_text(self, text):
        with tempfile.TemporaryDirectory() as folder:
            path = pathlib.Path(folder, 'map.dmm')
            path.write_text(text, encoding='utf-8')
            return maplint.lint_file(path)

    def test_entry_rules(self):
        cases = {
            ('/obj/item/x', '/turf/floor/grass', '/area/a'): ([], []),
            ('/obj/item/x', '/area/a'): (['tile has no turf'], []),
            ('/turf/floor/grass', '/area/a', '/area/b'): (['tile has 2 areas'], []),
            ('/turf/floor/grass', '/area/a', '/obj/item/x'): (['area is not the last entry'], ['object listed after a turf']),
            ('/datum/x', '/turf/floor/grass', '/area/a'): (['path outside /obj, /mob, /turf, /area: /datum/x'], []),
            ('/turf/floor/a', '/obj/x', '/turf/floor/b', '/area/a'): ([], ['tile stacks 2 turfs', 'object listed after a turf']),
            ('/obj/item/x', '/turf/wall/stone', '/area/a'): ([], ['item on a wall turf']),
            ('/turf/floor/grass', '/area/a{name = "x"}'): ([], []),
        }
        for entry, expected in cases.items():
            with self.subTest(entry=entry):
                self.assertEqual(maplint.lint_entry(entry), expected)

    def test_syntax_error_is_reported(self):
        broken = BASE.replace('dir = 4}', 'dir ="4}')
        errors, _ = self.lint_text(broken)
        self.assertEqual(len(errors), 1)
        self.assertIn('does not parse', errors[0][1])

    def test_conflict_marker_is_reported(self):
        errors, _ = self.lint_text('<<<<<<< HEAD\n' + BASE)
        self.assertEqual(errors, [(None, 'merge-conflict marker on line 1')])

    def test_unused_keys_are_ignored(self):
        errors, _ = self.lint_text(BASE.replace('\n\n(1', '\n"c" = (/area/a)\n\n(1'))
        self.assertEqual(errors, [])

    def test_every_map_passes(self):
        with contextlib.redirect_stdout(io.StringIO()) as out:
            status = maplint.main([])
        self.assertEqual(status, 0, out.getvalue()[-2000:])


if __name__ == '__main__':
    unittest.main()
