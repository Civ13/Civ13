"""Offline CI/CLI boundary checks. Every native subprocess is mocked."""
from contextlib import redirect_stdout
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('irrigation_trench_runner', ROOT / 'tests/trench_save/run.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
PIN = '067478b82c7ad9f1b83759a221e6f22080ba865a'


class CIRunner(unittest.TestCase):
    def test_ci_fetches_only_the_exact_baseline_before_tests(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text()
        start = workflow.index('      - name: Verify immutable irrigation baseline and offline contracts')
        stop = workflow.index('\n      - name:', start + 1)
        step = workflow[start:stop]
        self.assertIn("contains(fromJSON(needs.changes.outputs.new_tests), 'tests/irrigation_persistence')", step)
        self.assertIn('git cat-file -e ' + PIN + '^{commit}', step)
        self.assertIn('git fetch --no-tags --depth=1 origin ' + PIN, step)
        self.assertLess(step.index('git fetch'), step.index('python3 -B -m unittest'))
        self.assertNotIn('|| true', step)
        contract = (ROOT / 'tests/irrigation_persistence/test_contract.py').read_text()
        self.assertNotIn("['git', 'fetch'", contract)
        self.assertNotIn('skipTest', contract)
        manifest = json.loads((ROOT / 'tests/irrigation_persistence/baseline.json').read_text())
        self.assertEqual(manifest['upstream_commit'], PIN)

    def test_hosted_profile_is_explicit_and_keeps_both_controls(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text()
        start = workflow.index('      - name: Verify trench and ordinary irrigation restoration with current toolchain')
        stop = workflow.index('\n      - name:', start + 1)
        step = workflow[start:stop]
        self.assertIn('timeout-minutes: 10', step)
        self.assertEqual(step.count('--expected-byond-version 516.1688'), 3)
        self.assertIn('--negative-control filling', step)
        self.assertIn('--negative-control digging', step)
        self.assertNotIn('--compile-only', step)

    def test_historical_defaults_and_new_mode_are_not_interchangeable(self):
        parser = runner.argument_parser()
        old = parser.parse_args(['--byond-bin', '/placeholder'])
        self.assertEqual(old.expected_byond_version, '516.1681')
        self.assertFalse(old.compile_only)
        new = parser.parse_args(['--byond-bin', '/placeholder', '--expected-byond-version', '516.1688', '--compile-only'])
        self.assertEqual(new.expected_byond_version, '516.1688')
        self.assertTrue(new.compile_only)
        for version in ('516.1681', '516.1688'):
            text = f'DM compiler version {version}\nfixture.dmb - 0 errors, 0 warnings\n'
            self.assertTrue(runner.compiler_matches(text, 0, version))
            other = '516.1688' if version == '516.1681' else '516.1681'
            self.assertFalse(runner.compiler_matches(text, 0, other))
            self.assertFalse(runner.compiler_matches(text, 1, version))
        self.assertFalse(runner.compiler_matches('DM compiler version 516.16880\n0 errors, 0 warnings', 0, '516.1688'))

    def test_compile_errors_and_warnings_still_fail(self):
        for suffix in ('1 error, 0 warnings', '0 errors, 1 warning', 'incomplete log'):
            self.assertFalse(runner.compiler_matches('DM compiler version 516.1688\n' + suffix, 0, '516.1688'))

    def exercise_compile_only(self, expected, observed, should_pass):
        with tempfile.TemporaryDirectory(prefix='irrigation-cli-offline-') as directory:
            output = Path(directory) / 'evidence'
            output.mkdir()
            calls = []
            def fake_git(command, **kwargs):
                self.assertEqual(command[0], 'git')
                if command[1:3] == ['rev-parse', 'HEAD']:
                    return 'f' * 40 + '\n'
                if command[1:3] == ['diff', 'HEAD']:
                    return ''
                raise AssertionError('Unexpected external command in offline boundary test')
            def fake_compile(command, **kwargs):
                self.assertIn(Path(command[0]).name, ('dm.exe', 'DreamMaker'))
                self.assertEqual(kwargs['timeout'], 120)
                self.assertEqual(command[1:3], ['-max_errors', '0'])
                dme = Path(command[-1])
                calls.append(dme)
                for suffix in ('.dmb', '.rsc'):
                    dme.with_suffix(suffix).write_bytes(b'offline-mock-only')
                return subprocess.CompletedProcess(command, 0, f'DM compiler version {observed}\n0 errors, 0 warnings\n', '')
            args = ['run.py', '--byond-bin', directory, '--expected-byond-version', expected, '--compile-only']
            with patch.object(sys, 'argv', args), \
                    patch.object(runner.tempfile, 'mkdtemp', return_value=str(output)), \
                    patch.object(runner.subprocess, 'check_output', side_effect=fake_git), \
                    patch.object(runner.subprocess, 'run', side_effect=fake_compile), redirect_stdout(io.StringIO()):
                if should_pass:
                    runner.main()
                else:
                    with self.assertRaisesRegex(RuntimeError, 'Pinned production-source compilation failed'):
                        runner.main()
            self.assertEqual(len(calls), 1)
            metadata = json.loads((output / 'metadata.json').read_text())
            self.assertFalse(metadata['runtime_started'])
            self.assertTrue(metadata['compile_only'])
            self.assertFalse(calls[0].exists())
            self.assertFalse(calls[0].with_suffix('.dmb').exists())
            if should_pass:
                self.assertEqual(metadata['compiler_verified'], expected)
                self.assertTrue((output / 'compile.log').is_file())

    def test_compile_only_stops_before_daemon_and_config_copy(self):
        self.exercise_compile_only('516.1688', '516.1688', True)

    def test_default_legacy_rejects_current_target_without_runtime(self):
        self.exercise_compile_only('516.1681', '516.1688', False)

    def test_original_resource_limits_and_control_markers_remain(self):
        source = (ROOT / 'tests/trench_save/run.py').read_text()
        self.assertIn("choices=('filling', 'digging')", source)
        self.assertIn('timeout=120', source)
        self.assertIn('timeout=60', source)
        self.assertIn("'FAIL: trench fill progress survives'", source)
        self.assertIn("'FAIL: dirt and sand partial digging survives'", source)
        self.assertLess(source.index('if args.compile_only:'), source.index("for rel in subprocess.check_output"))
        self.assertLess(source.index('if args.compile_only:'), source.index('runtime = subprocess.run'))


if __name__ == '__main__':
    unittest.main()
