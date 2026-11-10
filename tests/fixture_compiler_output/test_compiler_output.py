"""Keep fixture compiler checks consistent across direct and imported runners."""
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


class FixtureCompilerOutputTest(unittest.TestCase):
    def test_helper_change_selects_both_dependent_offline_suites(self):
        spec = importlib.util.spec_from_file_location('ci_baseline', ROOT / 'scripts/ci_baseline.py')
        baseline = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(baseline)
        selected = baseline.impact(['scripts/fixture_compiler_output.py'])['suites']
        self.assertTrue(selected['fixture_compiler_output']['selected'])
        self.assertTrue(selected['gun_icon_states']['selected'])

    def test_each_runner_keeps_the_existing_predicate(self):
        cases = (
            ('DM compiler version 516.1688\nfixture.dmb - 0 errors, 0 warnings\n', 0, '516.1688', True),
            ('DM compiler version 516.1688\r\n0 errors,\t0 warnings\r\n', 0, '516.1688', True),
            ('DM compiler version 516.1688-extra\n0 errors, 0 warnings', 0, '516.1688', True),
            ('DM compiler version 516.1688\n0 errors, 0 warnings', 1, '516.1688', False),
            ('DM compiler version 516.16880\n0 errors, 0 warnings', 0, '516.1688', False),
            ('DM compiler version 516.1688\n1 error, 0 warnings', 0, '516.1688', False),
            ('DM compiler version 516.1688\n0 errors, 1 warning', 0, '516.1688', False),
            ('DM compiler version 516x1688\n0 errors, 0 warnings', 0, '516.1688', False),
        )
        for name in RUNNERS:
            with self.subTest(runner=name):
                spec = importlib.util.spec_from_file_location('fixture_runner_' + name, ROOT / 'tests' / name / 'run.py')
                runner = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(runner)
                self.assertEqual(runner.compiler_matches.__module__, 'fixture_compiler_output')
                for output, code, version, expected in cases:
                    with self.subTest(output=output, code=code):
                        self.assertEqual(runner.compiler_matches(output, code, version), expected)

    def test_direct_cli_can_import_from_an_unrelated_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            for name in RUNNERS:
                with self.subTest(runner=name):
                    result = subprocess.run([sys.executable, str(ROOT / 'tests' / name / 'run.py'), '--help'],
                                            cwd=directory, capture_output=True, text=True, timeout=20)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIn('--byond-bin', result.stdout)


if __name__ == '__main__':
    unittest.main()
