"""Forbidden source patterns stay at or below their recorded baseline; no BYOND runtime.

The repository check is the CI contract: a file may only lower its count of
spawn(), "in world" loops, untyped WWinput results and merge markers. The unit
cases pin the matcher behaviour the baseline relies on.
"""
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'scripts/check_forbidden_patterns.py'
BASELINE = ROOT / 'tools/lint/forbidden_patterns_baseline.json'


def load():
    spec = importlib.util.spec_from_file_location('check_forbidden_patterns', SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class MatcherTests(unittest.TestCase):
    def setUp(self):
        self.module = load()

    def test_comments_do_not_count(self):
        text = ('/proc/a()\n'
                '\tspawn(5) // spawn(1)\n'
                '\t// spawn(2)\n'
                '\t/* spawn(3)\n'
                '\tspawn(4) */ spawn(6)\n'
                '\tvar/s = "spawn(7)"\n')
        found = self.module.regex_matches(text, self.module.PATTERNS['spawn'][2], 'dm')
        self.assertEqual([number for number, _ in found], [2, 5])

    def test_spawn_sync_helper_is_not_a_spawn(self):
        text = '\tspawn_sync(1)\n\tlist.spawn(3)\n\tspawn (2)\n'
        found = self.module.regex_matches(text, self.module.PATTERNS['spawn'][2], 'dm')
        self.assertEqual([number for number, _ in found], [3])

    def test_in_world_loops(self):
        text = '\tfor (var/mob/M in world)\n\tfor (var/obj/O in world_list)\n\tif (x in world)\n'
        found = self.module.regex_matches(text, self.module.PATTERNS['in_world'][2], 'dm')
        self.assertEqual([number for number, _ in found], [1, 3])

    def test_call_arguments_counts_nested_calls_and_strings(self):
        count, complete = self.module.call_arguments('WWinput(H, "a, b", list("x", "y"), f(1, 2))', 7)
        self.assertEqual((count, complete), (4, True))
        count, complete = self.module.call_arguments('WWinput()', 7)
        self.assertEqual((count, complete), (0, True))
        count, complete = self.module.call_arguments('WWinput(H, "a",', 7)
        self.assertFalse(complete)

    def test_wwinput_result_needs_a_type_or_choices(self):
        text = ('\tvar/t = WWinput(H, "Title?", "Prompt", "Default")\n'
                '\tvar/u = WWinput(H, "Title?", "Prompt", "Default", "text")\n'
                '\tWWinput(H, "Notice", "Prompt")\n'
                '\tif (WWinput(H, "Sure?", "Prompt", "No", list("Yes", "No")) == "Yes")\n'
                '\tvar/v = WWinput(H, "Multi",\n'
                '\t\t"Prompt", "Default")\n'
                '\tvar/w = WWinput(H, "Multi",\n'
                '\t\t"Prompt", "Default", "num")\n')
        found = self.module.wwinput_matches(text)
        self.assertEqual([number for number, _ in found], [1, 5])

    def test_merge_markers(self):
        text = '<<<<<<< HEAD\n"aa" = (/turf)\n>>>>>>> branch\n=======\n'
        found = self.module.regex_matches(text, self.module.PATTERNS['merge_marker'][2], 'any')
        self.assertEqual([number for number, _ in found], [1, 3])


class RatchetTests(unittest.TestCase):
    def setUp(self):
        self.module = load()

    def scan_tree(self, files):
        directory = Path(tempfile.mkdtemp())
        for relative, text in files.items():
            path = directory / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding='utf-8')
        return directory, self.module.scan(directory)

    def test_new_occurrence_fails_and_lowered_count_is_reported(self):
        directory, hits = self.scan_tree({'code/a.dm': '\tspawn(1)\n\tspawn(2)\n', 'code/b.dm': '\tspawn(1)\n'})
        baseline = {name: {} for name in self.module.PATTERNS}
        baseline['spawn'] = {'code/a.dm': 3, 'code/c.dm': 1}
        violations, lowered = self.module.compare(hits, baseline)
        self.assertEqual([(name, path, allowed) for name, path, allowed, _ in violations],
                         [('spawn', 'code/b.dm', 0)])
        self.assertEqual(sorted(lowered), [('spawn', 'code/a.dm', 3, 2), ('spawn', 'code/c.dm', 1, 0)])

    def test_write_then_check_round_trip(self):
        directory, hits = self.scan_tree({'code/a.dm': '\tspawn(1)\n', 'maps/m.dmm': '"aa" = (/turf)\n'})
        baseline = directory / 'baseline.json'
        self.assertEqual(self.module.main(['--root', str(directory), '--baseline', str(baseline), '--write']), 0)
        self.assertEqual(json.loads(baseline.read_text())['patterns']['spawn'], {'code/a.dm': 1})
        self.assertEqual(self.module.main(['--root', str(directory), '--baseline', str(baseline)]), 0)
        (directory / 'code/a.dm').write_text('\tspawn(1)\n\tspawn(2)\n', encoding='utf-8')
        self.assertEqual(self.module.main(['--root', str(directory), '--baseline', str(baseline)]), 1)


class RepositoryContract(unittest.TestCase):
    def test_no_file_exceeds_its_baseline(self):
        module = load()
        self.assertTrue(BASELINE.is_file(), 'tools/lint/forbidden_patterns_baseline.json is missing')
        violations, _ = module.compare(module.scan(ROOT), module.load_baseline(BASELINE))
        report = '\n'.join(f'{name}: {path} {len(lines)} > {allowed}: ' + '; '.join(f'{n}: {l}' for n, l in lines[:5])
                           for name, path, allowed, lines in violations)
        self.assertEqual(violations, [], 'New forbidden patterns (see scripts/check_forbidden_patterns.py):\n' + report)

    def test_zero_tolerance_patterns_have_no_baseline_rows(self):
        baseline = json.loads(BASELINE.read_text(encoding='utf-8'))['patterns']
        self.assertEqual(baseline.get('merge_marker', {}), {})


if __name__ == '__main__':
    unittest.main()
