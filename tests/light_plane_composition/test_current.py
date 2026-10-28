"""Offline current-runner controls. Every compiler/daemon child is mocked."""
import argparse
import ast
import copy
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import re
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('current_plane_fixture', Path(__file__).with_name('run_current.py'))
current = importlib.util.module_from_spec(spec)
spec.loader.exec_module(current)
PREDECESSOR = '5b0c1e981c324a00cc4d504d6bc56cc7aa3468e3'
IDENTITY = {'version': '516.1688', 'archive': {'sha256': 'c' * 64},
            'members': {name: {'sha256': 'd' * 64} for name in current.runtime.MEMBERS}}
SOURCE = {'head': 'a' * 40, 'tree': 'b' * 40, 'tracked_dirty': False,
          'patch_sha256': hashlib.sha256(b'').hexdigest()}
MATRIX = [(False, None), (True, None)] + [
    (disabled, control) for control in ('area-change', 'area-owner', 'area-policy', 'area-policy-dynamic')
    for disabled in (False, True)] + [(False, control) for control in ('coverage', 'bypass', 'ordinary')]


def compiler(version='516.1688', returncode=0, stderr=''):
    return SimpleNamespace(stdout='DM compiler version ' + version + '\nprobe.dmb - 0 errors, 0 warnings (fixture)\n',
                           stderr=stderr, returncode=returncode)


class CurrentRunner(unittest.TestCase):
    def arguments(self, root, disabled=False, control=None):
        return argparse.Namespace(byond_bin=root / 'bin', byond_archive=root / 'pin.zip',
                                  output=root / 'output', disabled=disabled, negative_control=control)

    def invoke(self, args, calls, *, identities=None, built=None, compiler_error=None,
               daemon_error=None, source_after=None, runtime_log=None):
        expected = current.legacy.prepare(args.negative_control, not args.disabled)
        def child(command, **kwargs):
            out = Path(kwargs['cwd'])
            calls.append(dict(command=command, **kwargs))
            self.assertEqual(kwargs['creationflags'], 0)
            self.assertEqual(kwargs['env']['LD_LIBRARY_PATH'], str(args.byond_bin))
            self.assertEqual(kwargs['env']['BYOND_SYSTEM'], str(args.byond_bin.parent))
            if len(calls) == 1:
                self.assertEqual(command, [str(args.byond_bin / 'DreamMaker'), 'probe.dme'])
                self.assertEqual(kwargs['timeout'], 60)
                self.assertEqual({name: (out / name).read_text() for name in expected}, expected)
                (out / 'probe.dmb').write_bytes(b'offline fake compiled output')
                if compiler_error:
                    raise compiler_error
                return built or compiler()
            self.assertEqual(command, [str(args.byond_bin / 'DreamDaemon'), 'probe.dmb', '-trusted', '-close', '-log', 'runtime.log'])
            self.assertEqual(kwargs['timeout'], 20)
            log = runtime_log
            if log is None:
                log = ('FAIL checks=1 ' + current.CONTROLS[args.negative_control] if args.negative_control else
                       'PASS checks=' + str(8 if args.disabled else 287) + ' area_change_checks=64')
            (out / 'runtime.log').write_text(log + '\n')
            if daemon_error:
                raise daemon_error
            return SimpleNamespace(returncode=0, stdout='', stderr='')
        with patch.object(current.sys, 'platform', 'linux'), \
             patch.dict(current.os.environ, {'LD_PRELOAD': '', 'LD_AUDIT': ''}), \
             patch.object(current.runtime, 'verify_linux', side_effect=identities or [IDENTITY] * 4) as verify, \
             patch.object(current, 'source_identity', side_effect=[SOURCE, source_after or SOURCE]), \
             patch.object(current.subprocess, 'run', side_effect=child), patch('sys.stdout', io.StringIO()):
            current.execute(args)
        return verify

    def receipt(self, args):
        return json.loads((args.output / 'receipt.json').read_text())

    def test_control_labels_and_diagnostic_pattern_match_the_frozen_caller(self):
        tree = ast.parse(Path(current.legacy.__file__).read_text())
        expected = next(ast.literal_eval(node) for node in ast.walk(tree)
                        if isinstance(node, ast.Dict) and any(isinstance(key, ast.Constant)
                                                             and key.value == 'area-owner' for key in node.keys))
        diagnostic = next(node.args[0].value for node in ast.walk(tree)
                          if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
                          and node.func.attr == 'search' and node.args and isinstance(node.args[0], ast.Constant)
                          and isinstance(node.args[0].value, str) and node.args[0].value.startswith('runtime error|'))
        self.assertEqual(current.CONTROLS, expected)
        self.assertEqual(current.DIAGNOSTICS, diagnostic)

    def test_all_thirteen_existing_cases_use_exact_source_and_identity_at_each_phase(self):
        for disabled, control in MATRIX:
            with self.subTest(disabled=disabled, control=control), tempfile.TemporaryDirectory() as temporary:
                args = self.arguments(Path(temporary), disabled, control)
                calls = []
                verify = self.invoke(args, calls)
                receipt = self.receipt(args)
                self.assertEqual(len(calls), 2)
                self.assertEqual(verify.call_count, 4)
                for call in verify.call_args_list:
                    self.assertEqual(call.args, (args.byond_bin, args.byond_archive))
                self.assertEqual(receipt['runtime_identity'], IDENTITY)
                self.assertEqual(receipt['runtime_checks'], ['admission', 'before-compiler', 'before-daemon', 'after-daemon'])
                self.assertEqual(receipt['status'], 'passed')
                self.assertEqual(receipt['compiler_version'], '516.1688')
                self.assertEqual(receipt['source'], SOURCE)
                self.assertEqual(set(receipt['generated_sha256']), set(current.legacy.prepare(control, not disabled)))
                self.assertEqual(receipt['asset_sha256'], hashlib.sha256((current.ROOT / 'icons/effects/icon.png').read_bytes()).hexdigest())
                self.assertTrue((args.output / 'compile-execution.json').is_file())
                self.assertTrue((args.output / 'daemon-execution.json').is_file())
                self.assertFalse(Path(calls[0]['cwd']).exists(), 'Temporary compiled world must be cleaned')

    def test_archive_or_binary_refusal_precedes_generated_output_and_all_execution(self):
        with tempfile.TemporaryDirectory() as temporary:
            args = self.arguments(Path(temporary))
            with patch.object(current.sys, 'platform', 'linux'), \
                 patch.object(current.runtime, 'verify_linux', side_effect=ValueError('archive or member mismatch')) as verify, \
                 patch.object(current.subprocess, 'run') as child, self.assertRaises(ValueError):
                current.execute(args)
            verify.assert_called_once_with(args.byond_bin, args.byond_archive)
            child.assert_not_called()
            self.assertFalse(args.output.exists())

    def test_wrong_platform_or_central_version_cannot_select_historical_runtime(self):
        args = self.arguments(Path('unused'))
        with patch.object(current.sys, 'platform', 'win32'), patch.object(current.runtime, 'verify_linux') as verify:
            with self.assertRaises(ValueError): current.selected_runtime(args)
            verify.assert_not_called()
        for version in ('516.1681', '516.1689'):
            with patch.object(current.sys, 'platform', 'linux'), \
                 patch.object(current.runtime, 'verify_linux', return_value={'version': version}), self.assertRaises(ValueError):
                current.selected_runtime(args)

    def test_cli_requires_archive_and_fresh_output_arguments_before_execution(self):
        for missing in ('--byond-archive', '--output'):
            args = ['current', '--byond-bin', 'bin']
            args += ['--output', 'fresh'] if missing == '--byond-archive' else ['--byond-archive', 'pin.zip']
            with self.subTest(missing=missing), patch.object(current.sys, 'argv', args), \
                 patch.object(current, 'execute') as execute, patch('sys.stderr', io.StringIO()):
                with self.assertRaises(SystemExit) as error: current.main()
                self.assertEqual(error.exception.code, 2)
                execute.assert_not_called()

    def test_existing_output_is_immutable_and_refused_before_identity(self):
        with tempfile.TemporaryDirectory() as temporary:
            args = self.arguments(Path(temporary)); args.output.mkdir()
            old = args.output / 'receipt.json'; old.write_text('preserve spent attempt')
            with patch.object(current, 'selected_runtime') as verify, self.assertRaises(ValueError):
                current.execute(args)
            verify.assert_not_called()
            self.assertEqual(old.read_text(), 'preserve spent attempt')

    def test_loader_injection_refused_before_identity_or_launch(self):
        for key in ('LD_PRELOAD', 'LD_AUDIT'):
            with tempfile.TemporaryDirectory() as temporary, patch.dict(current.os.environ, {key: 'unreviewed.so'}), \
                 patch.object(current, 'selected_runtime') as verify, self.assertRaises(ValueError):
                current.execute(self.arguments(Path(temporary)))
            verify.assert_not_called()

    def test_dirty_source_refused_before_launch(self):
        with tempfile.TemporaryDirectory() as temporary, patch.object(current, 'selected_runtime', return_value=IDENTITY), \
             patch.object(current, 'source_identity', return_value={**SOURCE, 'tracked_dirty': True}), \
             patch.object(current.subprocess, 'run') as child, self.assertRaises(ValueError):
            current.execute(self.arguments(Path(temporary)))
        child.assert_not_called()

    def test_archive_or_member_drift_at_each_execution_boundary_fails_closed(self):
        changed = copy.deepcopy(IDENTITY); changed['members']['DreamDaemon']['sha256'] = 'e' * 64
        for phase, spawned in ((1, 0), (2, 1), (3, 2)):
            with self.subTest(phase=phase), tempfile.TemporaryDirectory() as temporary:
                args = self.arguments(Path(temporary)); calls = []
                with self.assertRaisesRegex(RuntimeError, 'Runtime identity changed'):
                    self.invoke(args, calls, identities=[IDENTITY] * phase + [changed])
                self.assertEqual(len(calls), spawned)
                self.assertEqual(self.receipt(args)['status'], 'failed')
                if calls: self.assertFalse(Path(calls[0]['cwd']).exists())

    def test_exact_combined_compiler_banner_clean_result_and_original_diagnostics_required(self):
        current.validate_compiler(compiler())
        wrong = [compiler('516.1681'), compiler('516.1689'), compiler(returncode=1),
                 compiler(stderr='DM compiler version 516.1688\n'), compiler(stderr='Cannot open file'),
                 SimpleNamespace(returncode=0, stdout=compiler().stdout.replace('0 warnings', '1 warnings'), stderr='')]
        for result in wrong:
            with self.subTest(result=result), self.assertRaisesRegex(RuntimeError, 'Plane fixture compilation failed'):
                current.validate_compiler(result)

    def test_wrong_banner_stops_before_daemon_and_retains_compiler_diagnostic(self):
        with tempfile.TemporaryDirectory() as temporary:
            args = self.arguments(Path(temporary)); calls = []
            with self.assertRaises(RuntimeError): self.invoke(args, calls, built=compiler('516.1681'))
            self.assertEqual(len(calls), 1)
            self.assertEqual(self.receipt(args)['status'], 'failed')
            self.assertIn('516.1681', (args.output / 'compile.log').read_text())
            self.assertFalse(Path(calls[0]['cwd']).exists())

    def test_all_original_runtime_diagnostics_and_nonzero_exit_are_rejected(self):
        result = SimpleNamespace(returncode=0)
        for diagnostic in ('runtime error', 'Runtime in', 'BUG:', 'CRASH', 'Infinite loop', 'Cannot read null'):
            with self.subTest(diagnostic=diagnostic), self.assertRaisesRegex(RuntimeError, 'Unexpected native diagnostic'):
                current.validate_runtime(result, diagnostic + '\nPASS checks=287 area_change_checks=64\n', None, False)
        with self.assertRaises(RuntimeError):
            current.validate_runtime(SimpleNamespace(returncode=1), 'PASS checks=287 area_change_checks=64\n', None, False)

    def test_wrong_control_or_mixed_positive_outcomes_cannot_pass(self):
        result = SimpleNamespace(returncode=0)
        for control in current.CONTROLS:
            for logs in ('FAIL checks=1 wrong reason', 'PASS checks=287 area_change_checks=64',
                         'FAIL checks=1 ' + current.CONTROLS[control] + '\nPASS checks=287 area_change_checks=64'):
                with self.subTest(control=control, logs=logs), self.assertRaises(RuntimeError):
                    current.validate_runtime(result, logs, control, False)
        with self.assertRaises(RuntimeError):
            current.validate_runtime(result, 'PASS checks=287 area_change_checks=64\nFAIL checks=1', None, False)

    def test_compile_timeout_and_launch_failure_keep_partial_receipts_and_cleanup(self):
        for error, state in ((subprocess.TimeoutExpired('compiler', 60, output=b'partial out', stderr=b'partial err'), 'timeout'),
                             (FileNotFoundError('compiler absent'), 'launch_error')):
            with self.subTest(state=state), tempfile.TemporaryDirectory() as temporary:
                args = self.arguments(Path(temporary)); calls = []
                with self.assertRaises(type(error)): self.invoke(args, calls, compiler_error=error)
                receipt = json.loads((args.output / 'compile-execution.json').read_text())
                self.assertEqual(receipt['state'], state)
                self.assertEqual(receipt['timeout_seconds'], 60)
                self.assertEqual(self.receipt(args)['status'], 'failed')
                self.assertEqual(len(calls), 1)
                self.assertFalse(Path(calls[0]['cwd']).exists())
                if state == 'timeout': self.assertIn('partial outpartial err', (args.output / 'compile.log').read_text())

    def test_daemon_timeout_retains_partial_output_runtime_log_and_cleanup(self):
        with tempfile.TemporaryDirectory() as temporary:
            args = self.arguments(Path(temporary)); calls = []
            error = subprocess.TimeoutExpired('daemon', 20, output=b'partial daemon')
            with self.assertRaises(subprocess.TimeoutExpired): self.invoke(args, calls, daemon_error=error, runtime_log='partial native log')
            self.assertEqual(json.loads((args.output / 'daemon-execution.json').read_text())['state'], 'timeout')
            self.assertIn('partial daemon', (args.output / 'daemon.log').read_text())
            self.assertIn('partial native log', (args.output / 'runtime.log').read_text())
            self.assertFalse(Path(calls[0]['cwd']).exists())

    def test_source_drift_prevents_success_receipt_after_execution(self):
        with tempfile.TemporaryDirectory() as temporary:
            args = self.arguments(Path(temporary)); calls = []
            with self.assertRaisesRegex(RuntimeError, 'Tracked source changed'):
                self.invoke(args, calls, source_after={**SOURCE, 'tree': 'f' * 40})
            self.assertEqual(self.receipt(args)['status'], 'failed')
            self.assertFalse(Path(calls[0]['cwd']).exists())

    def test_historical_callers_packets_and_shared_identity_helpers_are_unchanged(self):
        paths = ('tests/light_plane_composition/run.py', 'tests/lighting_startup/run.py',
                 'tests/light_plane_composition/verify_render.py', 'tests/light_plane_composition/render-results.json',
                 'tests/light_plane_composition/counterexamples.json', 'tests/light_plane_composition/rejected',
                 'tests/light_plane_composition/probe.dm', 'tests/light_plane_composition/area_probe.dm', 'scripts/byond_runtime.py',
                 'scripts/byond_toolchain.py', 'tools/byond/version.json')
        # Compare canonical tracked content, not Windows checkout CRLF against
        # Linux Git-blob LF. No source/evidence changes are allowed by this check.
        changed = subprocess.check_output(['git', 'diff', '--exit-code', PREDECESSOR, '--', *paths],
                                          cwd=current.ROOT, timeout=15)
        self.assertEqual(changed, b'')

    def test_workflow_keeps_exact_original_case_selection_with_unique_current_outputs(self):
        path = '.github/workflows/test.yml'
        old = subprocess.check_output(['git', 'show', PREDECESSOR + ':' + path], cwd=current.ROOT, text=True, timeout=15)
        text = (current.ROOT / path).read_text()
        old_calls = [line for line in old.splitlines() if 'python3 tests/light_plane_composition/run.py --byond-bin' in line]
        new_calls = [line for line in text.splitlines() if 'python3 -B tests/light_plane_composition/run_current.py --byond-bin' in line]
        self.assertEqual(len(old_calls), 13)
        self.assertEqual(len(new_calls), 13)
        for old_call, new_call in zip(old_calls, new_calls):
            self.assertEqual(re.findall(r'--disabled|--negative-control [\w-]+', old_call),
                             re.findall(r'--disabled|--negative-control [\w-]+', new_call))
            self.assertIn('--byond-archive "$PWD/BYOND/pinned.zip"', new_call)
        self.assertEqual(len(set(re.findall(r'--output "([^"]+)"', '\n'.join(new_calls)))), 13)
        condition = "if: needs.changes.outputs.extensive == 'true' || contains(fromJSON(needs.changes.outputs.new_tests), 'tests/light_plane_composition')"
        self.assertIn(condition, text)
        self.assertIn('LIGHTING_COMPOSITION_V2 0', (current.ROOT / 'code/__defines/_planes+layers.dm').read_text())


if __name__ == '__main__':
    unittest.main()
