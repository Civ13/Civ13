"""Offline platform, process-boundary and passive identity checks. Never launch BYOND."""
from contextlib import redirect_stdout
import importlib.util
import io
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import stat
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch
import zipfile

SPEC = importlib.util.spec_from_file_location('round_metadata_current', Path(__file__).with_name('run-round-metadata.py'))
RUNNER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUNNER)
CLEAN = 'DM compiler version 516.1688\nroundtrip.dmb - 0 errors, 0 warnings\n'
EXPECTED = {
    None: 'PASS',
    'restore': 'FAIL: round-mode flag lost: persistence',
    'preflight': 'FAIL: invalid round extension passed preflight: partial',
    'integrity': 'FAIL: modern metadata tamper passed preflight',
}


class CurrentRoundMetadata(unittest.TestCase):
    def exercise(self, *, control=None, compiler_log=None, identity_error_at=None,
                 actual=None, expected_error=None, launches=2, current_mode=True, archive_mode=False):
        if compiler_log is None:
            compiler_log = CLEAN if current_mode else CLEAN.replace('516.1688', '516.1681')
        with tempfile.TemporaryDirectory(prefix='round-metadata-injected-') as directory:
            root = Path(directory)
            binary, output = root / 'bin', root / 'evidence'
            binary.mkdir()
            output.mkdir()
            compiler = binary / ('DreamMaker' if current_mode else 'dm.exe')
            daemon = binary / ('DreamDaemon' if current_mode else 'dd.exe')
            for executable in (compiler, daemon):
                executable.write_text('Nonexecutable test placeholder', encoding='utf-8')
            events, children = [], []

            def verify(command):
                self.assertTrue(current_mode, 'Historical Windows mode must not require a Linux archive')
                role = 'compile' if Path(command) == compiler else 'daemon'
                events.append('verify:' + role)
                if role == identity_error_at:
                    raise ValueError('archive member mismatch')
                return {'version': '516.1688'}

            def before_launch(role, evidence):
                self.assertEqual(evidence, output)
                events.append('verify:' + role)
                if role == identity_error_at:
                    raise ValueError('archive member mismatch')

            def validate_archive_compile(code, log, name):
                self.assertEqual(name, 'roundtrip.dmb')
                RUNNER.current.validate_compiler(RUNNER.subprocess.CompletedProcess([], code, log, ''))

            runtime = SimpleNamespace(before_launch=before_launch, validate_compile=validate_archive_compile)

            def launch(command, **kwargs):
                role = 'compile' if Path(command[0]) == compiler else 'daemon'
                if current_mode:
                    self.assertEqual(events[-1], 'verify:' + role)
                events.append('launch:' + role)
                self.assertEqual(kwargs['cwd'], output)
                self.assertEqual(kwargs['stderr'], RUNNER.subprocess.STDOUT)
                self.assertEqual(kwargs['creationflags'], 0 if current_mode else 0x08000000)
                if role == 'compile':
                    kwargs['stdout'].write(compiler_log)
                    kwargs['stdout'].flush()
                else:
                    self.assertIn('-trusted', command)
                    self.assertIn('-ip', command)
                    self.assertIn('127.0.0.1', command)
                    self.assertIn('-close', command)
                    (output / 'runtime.log').write_text('Injected closed fixture log\n')
                    (output / 'result.txt').write_text(EXPECTED[control] if actual is None else actual)
                child = SimpleNamespace(pid=1234 + len(children), poll=Mock(return_value=0),
                                        wait=Mock(return_value=0))
                children.append(child)
                return child

            argv = ['run-round-metadata.py', '--byond-bin', str(binary)]
            if current_mode:
                argv += ['--byond-archive', 'inert.zip'] if archive_mode else ['--current-linux-toolchain']
            if control:
                argv += ['--negative-control', control]
            with patch.object(sys, 'argv', argv), \
                 patch.object(RUNNER.sys, 'platform', 'linux' if current_mode else 'win32'), \
                 patch.object(RUNNER, 'os', SimpleNamespace(name='posix' if current_mode else 'nt')), \
                 patch.object(RUNNER.subprocess, 'CREATE_NO_WINDOW', 0x08000000, create=True), \
                 patch.object(RUNNER.tempfile, 'mkdtemp', return_value=str(output)), \
                 patch.object(RUNNER.current, 'verify', side_effect=verify), \
                 patch.object(RUNNER, 'selected_runtime', return_value=runtime if archive_mode else None), \
                 patch.object(RUNNER.subprocess, 'Popen', side_effect=launch) as execute, \
                 redirect_stdout(io.StringIO()):
                if expected_error:
                    with self.assertRaisesRegex((RuntimeError, ValueError), expected_error):
                        RUNNER.main()
                else:
                    RUNNER.main()
            self.assertEqual(execute.call_count, launches)
            for child in children:
                child.wait.assert_called_once_with(timeout=120)
            cleanup = json.loads((output / 'cleanup.json').read_text())
            self.assertTrue(all(not row['cancelled'] for row in cleanup))
            if expected_error:
                self.assertFalse((output / 'summary.json').exists())
            else:
                self.assertEqual(events, ['verify:compile', 'launch:compile', 'verify:daemon', 'launch:daemon']
                                 if current_mode else ['launch:compile', 'launch:daemon'])
                summary = json.loads((output / 'summary.json').read_text())
                self.assertEqual(summary['negative_control'], control)
                self.assertEqual(summary['result'], EXPECTED[control])
                self.assertTrue(all(row['exit'] == 0 for row in summary['processes']))
                self.assertFalse(summary['opendream_verified'])
                self.assertFalse(summary['rpo_verified'])
                self.assertEqual(summary['toolchain_mode'], 'current-archive' if archive_mode else ('current-linux' if current_mode else 'historical-516.1681'))
                self.assertEqual(summary['archive_identity_verified'], current_mode)
                for row in summary['processes']:
                    self.assertEqual('runtime_identity' in row, current_mode and not archive_mode)

    def test_positive_and_all_named_controls_keep_their_exact_oracles(self):
        for control in EXPECTED:
            with self.subTest(control=control):
                self.exercise(control=control)

    def test_explicit_archive_mode_keeps_oracles_and_identity_checks(self):
        for control in EXPECTED:
            with self.subTest(control=control):
                self.exercise(control=control, archive_mode=True)
        self.exercise(archive_mode=True, identity_error_at='compile', expected_error='archive member mismatch', launches=0)
        self.exercise(archive_mode=True, identity_error_at='daemon', expected_error='archive member mismatch', launches=1)
        self.exercise(archive_mode=True, compiler_log=CLEAN.replace('516.1688', '516.1681'),
                      expected_error='exact current compiler', launches=1)

    def test_current_toolchain_modes_cannot_be_combined(self):
        with patch.object(sys, 'argv', ['runner', '--byond-bin', '.', '--byond-archive', 'inert.zip', '--current-linux-toolchain']), \
             patch.object(RUNNER.tempfile, 'mkdtemp') as create, patch.object(RUNNER, 'selected_runtime') as select, \
             patch.object(RUNNER.subprocess, 'Popen') as launch, patch.object(sys, 'stderr', io.StringIO()):
            with self.assertRaises(SystemExit): RUNNER.main()
        create.assert_not_called(); select.assert_not_called(); launch.assert_not_called()

    def test_default_windows_mode_retains_exact_historical_runner_without_archive(self):
        for control in EXPECTED:
            with self.subTest(control=control):
                self.exercise(control=control, current_mode=False)
        self.exercise(current_mode=False, compiler_log=CLEAN,
                      expected_error='full pinned compiler banner', launches=1)

    def test_current_linux_mode_refuses_windows_before_any_effect(self):
        with patch.object(sys, 'argv', ['run-round-metadata.py', '--byond-bin', '.', '--current-linux-toolchain']), \
             patch.object(RUNNER.sys, 'platform', 'win32'), \
             patch.object(RUNNER.tempfile, 'mkdtemp') as create, \
             patch.object(RUNNER.current, 'verify') as verify, \
             patch.object(RUNNER.subprocess, 'Popen') as launch, \
             redirect_stdout(io.StringIO()), patch.object(sys, 'stderr', io.StringIO()):
            with self.assertRaises(SystemExit) as rejected:
                RUNNER.main()
            self.assertEqual(rejected.exception.code, 2)
        create.assert_not_called()
        verify.assert_not_called()
        launch.assert_not_called()

    def test_historical_extended_duplicate_and_warning_output_stop_before_daemon(self):
        for log in (CLEAN.replace('516.1688', '516.1681'),
                    CLEAN.replace('516.1688', '516.16880'),
                    CLEAN + 'DM compiler version 516.1688\n',
                    CLEAN + 'prefix DM compiler version 516.1688\n',
                    CLEAN + 'warning: unexpected compiler output\n'):
            with self.subTest(log=log):
                self.exercise(compiler_log=log, expected_error='exact current compiler', launches=1)

    def test_identity_rejection_precedes_each_owned_launch(self):
        self.exercise(identity_error_at='compile', expected_error='archive member mismatch', launches=0)
        self.exercise(identity_error_at='daemon', expected_error='archive member mismatch', launches=1)

    def test_negative_control_cannot_accept_a_positive_or_unrelated_result(self):
        for actual in ('PASS', 'FAIL: unrelated assertion'):
            with self.subTest(actual=actual):
                self.exercise(control='preflight', actual=actual, expected_error='Unexpected round metadata result')

    def test_ci_layout_passive_identity_reads_archive_and_members_without_launch(self):
        # Use the actual CI path relationship and real regular files/ZIP reads.
        # Only the manifest is synthetic; neither verifier nor file IO is mocked.
        with tempfile.TemporaryDirectory(prefix='round-metadata-ci-layout-') as directory:
            root = Path(directory) / 'repository' / 'BYOND'
            binary = root / 'byond' / 'bin'
            binary.mkdir(parents=True)
            archive = root / 'pinned.zip'
            bodies = {name: ('passive CI member ' + name).encode() for name in RUNNER.current.runtime.MEMBERS}
            with zipfile.ZipFile(archive, 'w') as package:
                for name, body in bodies.items():
                    entry = zipfile.ZipInfo('byond/bin/' + name)
                    entry.create_system = 3
                    entry.external_attr = (stat.S_IFREG | 0o755) << 16
                    package.writestr(entry, body)
                    (binary / name).write_bytes(body)
            manifest = {'version': '516.1688', 'linux': {
                'bytes': archive.stat().st_size,
                'sha256': hashlib.sha256(archive.read_bytes()).hexdigest()}}
            with patch.object(RUNNER.current.runtime.pin, 'load', return_value=manifest), \
                 patch.object(RUNNER.subprocess, 'Popen', side_effect=AssertionError('Native launch attempted')):
                for executable in ('DreamMaker', 'DreamDaemon'):
                    identity = RUNNER.current.verify(binary / executable)
                    self.assertEqual(identity['archive'], manifest['linux'])
                    self.assertEqual(identity['members'], {
                        name: {'bytes': len(body), 'sha256': hashlib.sha256(body).hexdigest()}
                        for name, body in bodies.items()})
                library = binary / 'libbyond.so'
                library.write_bytes(b'X' * len(bodies['libbyond.so']))
                with self.assertRaisesRegex(ValueError, 'Installed runtime differs'):
                    RUNNER.current.verify(binary / 'DreamMaker')


if __name__ == '__main__':
    unittest.main()
