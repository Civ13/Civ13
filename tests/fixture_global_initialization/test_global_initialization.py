"""Offline checks for the fixture global-controller startup projection."""
import ast
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
RUNNERS = (
    'ammo_casing_load', 'berry_load', 'construction_weathering_load',
    'custom_clothing_load', 'gun_icon_states', 'load_construction',
    'roof_support_load', 'trench_save', 'vending_load',
)
MARKER = '/datum/controller/global_vars/New()\n'


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class GlobalInitializationTest(unittest.TestCase):
    def test_transform_and_marker_guards_for_each_runner(self):
        for name in RUNNERS:
            with self.subTest(runner=name):
                runner = load('fixture_runner_' + name, ROOT / 'tests' / name / 'run.py')
                project = runner.isolate_global_initialization
                self.assertEqual(project.__module__, 'fixture_global_initialization')
                self.assertEqual(project('before\n' + MARKER + '\tinit()\n'),
                                 'before\n' + MARKER + '\treturn\n\tinit()\n')
                for source in ('no marker', MARKER + MARKER):
                    with self.assertRaisesRegex(RuntimeError, '^Global isolation marker changed$'):
                        project(source)
                tree = ast.parse((ROOT / 'tests' / name / 'run.py').read_text(encoding='utf-8'))
                calls = [node for node in ast.walk(tree) if isinstance(node, ast.Call)
                         and isinstance(node.func, ast.Name) and node.func.id == 'isolate_global_initialization']
                self.assertEqual(len(calls), 1)

    def test_direct_cli_imports_from_an_unrelated_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            for name in RUNNERS:
                with self.subTest(runner=name):
                    result = subprocess.run([sys.executable, str(ROOT / 'tests' / name / 'run.py'), '--help'],
                                            cwd=directory, capture_output=True, text=True, timeout=30)
                    self.assertEqual(result.returncode, 0, result.stderr)

    def test_helper_and_each_runner_select_this_offline_suite(self):
        baseline = load('ci_baseline', ROOT / 'scripts/ci_baseline.py')
        paths = ['scripts/fixture_global_initialization.py']
        paths.extend(f'tests/{name}/run.py' for name in RUNNERS)
        for path in paths:
            with self.subTest(path=path):
                self.assertTrue(baseline.impact([path])['suites']['fixture_global_initialization']['selected'])
        for suite in ('gun_icon_states', 'fixture_compiler_output', 'irrigation_ci_runner'):
            with self.subTest(suite=suite):
                self.assertTrue(baseline.impact([paths[0]])['suites'][suite]['selected'])


if __name__ == '__main__':
    unittest.main()
