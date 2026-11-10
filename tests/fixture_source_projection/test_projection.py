"""Offline parity and selection tests for source-projected fixtures."""
import importlib.util
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
RUNNERS = ('faction_membership', 'faction_recruitment', 'research_persistence')


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


projection = load('fixture_source_projection', ROOT / 'scripts/fixture_source_projection.py')


def old_proc_text(source, signature):
    start = source.index(signature)
    body = source.index('\n', start) + 1
    end = re.compile(r'^\S', re.M).search(source, body)
    return source[start:end.start() if end else len(source)]


def old_read(runner, path, control):
    text = (runner.ROOT / path).read_text(encoding='utf-8')
    if runner.HERE.name != 'research_persistence':
        text = text.replace('\r\n', '\n')
    if control:
        target, old, new = runner.CONTROLS[control]
        if target == path:
            if text.count(old) != 1:
                raise RuntimeError(f'Control target missing or ambiguous: {control}')
            text = text.replace(old, new, 1)
    return text


class ProjectionTest(unittest.TestCase):
    def test_control_targets_and_missing_or_ambiguous_occurrences(self):
        controls = {'change': ('one.dm', 'needle', 'replacement')}
        self.assertEqual(projection.apply_control('needle', 'other.dm', 'change', controls), 'needle')
        self.assertEqual(projection.apply_control('needle', 'one.dm', None, controls), 'needle')
        self.assertEqual(projection.apply_control('needle', 'one.dm', 'change', controls), 'replacement')
        for text in ('absent', 'needle needle'):
            with self.subTest(text=text), self.assertRaisesRegex(RuntimeError, 'Control target missing or ambiguous: change'):
                projection.apply_control(text, 'one.dm', 'change', controls)

    def test_proc_boundaries_and_missing_signature(self):
        for source, expected in (
            ('/proc/a()\n\treturn 1\n/proc/b()\n\treturn 2\n', '/proc/a()\n\treturn 1\n'),
            ('/proc/a()\n\treturn 1\n', '/proc/a()\n\treturn 1\n'),
            ('/proc/a()\n\treturn 1\n// comment\n', '/proc/a()\n\treturn 1\n'),
        ):
            self.assertEqual(projection.proc_text(source, '/proc/a()'), expected)
        with self.assertRaises(ValueError):
            projection.proc_text('/proc/a()\n', '/proc/missing()')

    def test_reader_newlines_and_all_generated_fixtures_match_old_logic(self):
        for name in RUNNERS:
            runner = load('runner_' + name, ROOT / 'tests' / name / 'run.py')
            with self.subTest(runner=name), tempfile.TemporaryDirectory() as temp:
                temp = Path(temp)
                (temp / 'line.dm').write_bytes(b'a\r\nb\rc\n')
                with patch.object(runner, 'ROOT', temp):
                    self.assertEqual(runner.read('line.dm', None), old_read(runner, 'line.dm', None))
                for control in (None, *runner.CONTROLS):
                    actual, expected = temp / 'actual', temp / 'expected'
                    actual.mkdir(exist_ok=True)
                    expected.mkdir(exist_ok=True)
                    runner.build(actual, control)
                    with patch.object(runner, 'read', side_effect=lambda path, control=None: old_read(runner, path, control)), \
                         patch.object(runner, 'proc_text', old_proc_text):
                        runner.build(expected, control)
                    actual_files = {p.name: p.read_bytes() for p in actual.iterdir()}
                    expected_files = {p.name: p.read_bytes() for p in expected.iterdir()}
                    self.assertEqual(actual_files, expected_files, (name, control))

    def test_direct_cli_imports_from_an_unrelated_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            for name in RUNNERS:
                result = subprocess.run([sys.executable, str(ROOT / 'tests' / name / 'run.py'), '--help'],
                                        cwd=directory, capture_output=True, text=True, timeout=20)
                self.assertEqual(result.returncode, 0, (name, result.stderr))
                self.assertIn('--byond-bin', result.stdout)

    def test_helper_and_inputs_select_suite_and_dependent_faction_tests(self):
        baseline = load('ci_baseline', ROOT / 'scripts/ci_baseline.py')
        suite = baseline.SUITES['fixture_source_projection']
        for path in suite['paths'] + suite['shared_paths']:
            with self.subTest(path=path):
                self.assertTrue(baseline.impact([path])['suites']['fixture_source_projection']['selected'])
        for name in RUNNERS:
            decision = baseline.impact([f'tests/{name}/run.py'])
            self.assertFalse(decision['fallback_reasons'], name)
        selected = baseline.impact(['scripts/fixture_source_projection.py'])['suites']
        for name in ('faction_membership', 'faction_recruitment'):
            self.assertTrue(selected[name]['selected'])


if __name__ == '__main__':
    unittest.main()
