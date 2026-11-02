"""Execute the complete startup loader block offline with inert engine I/O.

This is source control-flow evidence, not DM compilation or native startup.
The shared audited projector translates every selected executable line. The
local lexical adapter only renders DM message interpolation and protects the
literal // marker from that projector's comment splitter.
"""
import builtins
from collections import defaultdict
import html
import importlib.util
from pathlib import Path
import re
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('craft_loader_source', ROOT / 'tests/save_movement/source_adapter.py')
source_adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(source_adapter)


class DMList(builtins.list):
    @property
    def len(self):
        return len(self)

    def __getitem__(self, key):
        return super().__getitem__(key - 1 if isinstance(key, int) else key)


class Log(builtins.list):
    def __lshift__(self, message):
        self.append(message)
        return self


def message_literal(match):
    token = match.group()
    body = token[1:-1]
    result = []
    position = 0
    interpolated = False
    while position < len(body):
        if body[position] == '\\':
            result.append(body[position:position + 2])
            position += 2
        elif body[position] == '[':
            depth, end = 1, position + 1
            while end < len(body) and depth:
                depth += (body[end] == '[') - (body[end] == ']')
                end += 1
            if depth:
                raise AssertionError('Unclosed DM interpolation')
            result.append('{' + body[position + 1:end - 1] + '}')
            position = end
            interpolated = True
        else:
            result.append(body[position])
            position += 1
    literal = '"' + ''.join(result).replace('//', r'\x2f\x2f') + '"'
    return ('f' if interpolated else '') + literal


def loader_source():
    source = (ROOT / 'code/setup.dm').read_text(encoding='utf-8-sig')
    start = source.index('\tvar/all_craft_lists = flist("config/crafting/")')
    end = source.index('\n\tadmin_notice("<span class=\'danger\'>Initializing dictionary...', start)
    return '/proc/loader_fixture()\n' + source[start:end]


class Loader:
    def __init__(self, filenames, files, source=None):
        self.filenames, self.files = filenames, files
        self.notices, self.log, self.reads, self.opened = [], Log(), [], []
        self.rows = defaultdict(DMList)
        text = loader_source() if source is None else source
        text = re.sub(r'"(?:[^"\\]|\\.)*"', message_literal, text)
        env = {
            'flist': lambda folder: DMList(self.filenames),
            'file': self.file,
            'fexists': lambda path: path in self.files,
            'file2text': self.read,
            'file2list': lambda path, separator: DMList(self.read(path).split(separator)),
            'splittext': lambda text, separator: DMList(text.split(separator)),
            'findtext': lambda text, needle: text.casefold().find(needle.casefold()) + 1,
            'replacetext': lambda text, old, new: re.sub(re.escape(old), lambda m: new, text, flags=re.I),
            'html_encode': lambda text: html.escape(text, quote=True),
            'istext': lambda text: isinstance(text, str),
            'length': len,
            'list': lambda *values: DMList(values),
            'craftlist_lists': self.rows,
            'world': SimpleNamespace(log=self.log),
            'admin_notice': lambda message, level: self.notices.append(message),
            'R_DEBUG': 'debug',
        }
        source_adapter.project(text, '/proc/loader_fixture', '', env)()

    def file(self, path):
        self.opened.append(path)
        return path

    def read(self, path):
        self.reads.append(path)
        return self.files[path]


def recipe(title):
    return 'RECIPE: /material/steel/,' + title + ',/obj/item/stack/material/steel,1,0,0,1,none,0,0,0,8,null'


def run_file(filename, text, source=None):
    return Loader([filename], {'config/crafting/' + filename: text}, source)


class CraftingLoaderTests(unittest.TestCase):
    def test_unrelated_files_are_ignored_without_file_access_or_warning(self):
        result = Loader(['furniture_joinery.json', 'README.txt', 'notes/'], {})
        self.assertEqual((result.opened, result.reads, result.notices, result.log, dict(result.rows)), ([], [], [], [], {}))

    def test_missing_selected_file_reports_safe_filename(self):
        name = 'material_recipes_<b>\nmissing.txt'
        result = Loader([name], {})
        self.assertEqual(len(result.notices), 1)
        self.assertIn('&lt;b&gt;\\nmissing.txt', result.notices[0])
        self.assertIn('file not found', result.notices[0])
        self.assertNotIn('\n', result.notices[0])
        self.assertNotIn('<b>', result.notices[0])
        self.assertEqual(result.reads, [])

    def test_empty_and_unreadable_selected_files_remain_failures(self):
        for content in ('', None):
            with self.subTest(content=content):
                result = run_file('material_recipes_global.txt', content)
                self.assertEqual(len(result.notices), 1)
                self.assertIn('material_recipes_global.txt: empty or unreadable file', result.notices[0])
                self.assertEqual(dict(result.rows), {})

    def test_bad_recipe_reports_filename_row_and_count_without_echoing_row(self):
        result = run_file('material_recipes_<b>.txt', '// comment\nRECIPE: only,<script>\n' + recipe('good'))
        self.assertEqual(result.notices, [])
        self.assertEqual(len(result.log), 1)
        self.assertIn('material_recipes_&lt;b&gt;.txt, row 2: expected 13 fields, got 2', result.log[0])
        self.assertNotIn('<script>', result.log[0])
        # Retain the existing registration behavior for malformed comma rows.
        self.assertEqual([row.len for row in result.rows['<b>']], [2, 13])

    def test_recipe_marker_without_comma_is_reported_but_not_registered(self):
        result = run_file('material_recipes_global.txt', 'RECIPE: broken')
        self.assertEqual(len(result.log), 1)
        self.assertIn('row 1: expected 13 fields, got 1', result.log[0])
        self.assertEqual(dict(result.rows), {})

    def test_comments_and_unmarked_lines_keep_legacy_skip_rules(self):
        result = run_file('material_recipes_global.txt', '// ' + recipe('comment') + '\nother,text\n\n' + recipe('good'))
        self.assertEqual(result.notices + result.log, [])
        self.assertEqual([row[2] for row in result.rows['global']], ['good'])

    def test_listing_and_recipe_order_are_preserved(self):
        names = ['material_recipes_zeta.txt', 'furniture_joinery.json', 'material_recipes_alpha.txt']
        files = {'config/crafting/' + names[0]: recipe('z1') + '\n' + recipe('z2'),
                 'config/crafting/' + names[2]: recipe('a1')}
        result = Loader(names, files)
        self.assertEqual(result.reads, ['config/crafting/' + names[0], 'config/crafting/' + names[2]])
        self.assertEqual(builtins.list(result.rows), ['zeta', 'alpha'])
        self.assertEqual([row[2] for row in result.rows['zeta']], ['z1', 'z2'])

    def test_existing_filename_matching_is_not_tightened(self):
        result = run_file('backup_MATERIAL_RECIPES_misc.data', recipe('legacy name'))
        self.assertEqual(result.notices + result.log, [])
        self.assertEqual([row[2] for row in result.rows['backup_misc.data']], ['legacy name'])

    def test_frozen_old_loop_reproduces_warning_for_joinery_json(self):
        legacy = (Path(__file__).parent / 'fixtures/legacy_setup_loop.dm').read_text()
        result = run_file('furniture_joinery.json', '{}', legacy)
        self.assertEqual(len(result.notices), 1)
        fixed = run_file('furniture_joinery.json', '{}')
        self.assertEqual(fixed.notices, [])

    def test_checked_in_recipe_rows_match_legacy_registration_exactly(self):
        paths = builtins.list((ROOT / 'config/crafting').iterdir())
        names = [path.name for path in paths]
        files = {}
        for path in paths:
            if path.is_file():
                with path.open(encoding='utf-8', newline='') as stream:
                    files['config/crafting/' + path.name] = stream.read()
        legacy = (Path(__file__).parent / 'fixtures/legacy_setup_loop.dm').read_text()
        old, new = Loader(names, files, legacy), Loader(names, files)
        self.assertEqual(dict(new.rows), dict(old.rows))
        self.assertEqual(builtins.list(new.rows), builtins.list(old.rows))
        self.assertEqual(new.notices + new.log, [])
        self.assertEqual(len(old.notices), 1)  # furniture_joinery.json only
        self.assertGreater(sum(len(rows) for rows in new.rows.values()), 9000)

    def test_omission_controls_do_not_suppress_real_errors(self):
        source = loader_source()
        cases = [
            ('if (!findtext(i, "material_recipes"))', 'if (FALSE)', 'nonrecipe'),
            ('if (!fexists(F3))', 'if (FALSE)', 'missing'),
            ('if (current.len != 13)', 'if (FALSE)', 'parse'),
        ]
        for before, after, control in cases:
            with self.subTest(control=control):
                self.assertEqual(source.count(before), 1)
                changed = source.replace(before, after, 1)
                if control == 'nonrecipe':
                    result = run_file('furniture_joinery.json', '{}', changed)
                    self.assertNotEqual(result.opened, [])
                elif control == 'missing':
                    with self.assertRaises(KeyError):
                        Loader(['material_recipes_missing.txt'], {}, changed)
                else:
                    result = run_file('material_recipes_global.txt', 'RECIPE: only,two', changed)
                    self.assertEqual(result.log, [])


if __name__ == '__main__':
    unittest.main()
