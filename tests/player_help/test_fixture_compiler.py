"""Injected checks for the actual fixture runner's compiler-version gate."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('player_help_fixture_runner', ROOT / 'tests/player_help/run.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class FixtureCompilerTests(unittest.TestCase):
    def exercise(self, banner, *, expected=None, code=0, result='0 errors, 0 warnings', stderr='', accepted):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'fixture'
            argv = ['run.py', '--byond-bin', str(Path(directory) / 'byond'), '--output', str(output)]
            if expected is not None:
                argv += ['--expected-byond-version', expected]
            built = SimpleNamespace(returncode=code,
                                    stdout=f'DM compiler version {banner}\nprobe.dmb - {result}\n',
                                    stderr=stderr)
            def invoke(*args, **kwargs):
                if invoke.calls:
                    raise RuntimeError('daemon deliberately suppressed')
                invoke.calls += 1
                return built
            invoke.calls = 0
            with patch.object(sys, 'argv', argv), patch.object(subprocess, 'run', side_effect=invoke) as run:
                if accepted:
                    with self.assertRaisesRegex(RuntimeError, 'daemon deliberately suppressed'):
                        runner.main()
                    self.assertEqual(run.call_count, 2)
                else:
                    with self.assertRaisesRegex(SystemExit, 'Fixture compilation failed'):
                        runner.main()
                    self.assertEqual(run.call_count, 1)

    def test_current_pin_is_default_and_reaches_daemon_boundary(self):
        manifest = json.loads((ROOT / 'tools/byond/version.json').read_text(encoding='utf-8'))
        self.assertEqual(manifest['version'], '516.1688')
        self.exercise('516.1688', accepted=True)

    def test_historical_1681_requires_explicit_selection(self):
        self.exercise('516.1681', accepted=False)
        self.exercise('516.1681', expected='516.1681', accepted=True)
        self.exercise('516.1688', expected='516.1681', accepted=False)

    def test_wrong_banner_and_bad_compiler_results_stop_before_daemon(self):
        for fields in ({'banner': '516.16810'}, {'banner': '516.16881'},
                       {'banner': '516.1688 extra'}, {'banner': '516.1688\nDM compiler version 516.1681'},
                       {'banner': '516.1688', 'code': 1},
                       {'banner': '516.1688', 'result': '0 errors, 1 warning'},
                       {'banner': '516.1688', 'stderr': 'invalid file'}):
            with self.subTest(fields=fields):
                self.exercise(**fields, accepted=False)


if __name__ == '__main__':
    unittest.main()
