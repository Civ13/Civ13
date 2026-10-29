"""Offline sprite admission and workflow contracts. Never run BYOND or installers."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import types
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('sprite_runner', ROOT / 'tests/sprites/run.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


def posix_runner_os():
    # Replace only the runner's dependency. Mutating shared os.name also changes
    # pathlib's concrete Path class throughout the interpreter on Windows.
    return types.SimpleNamespace(**dict(vars(os), name='posix'))


class SpriteToolchainTests(unittest.TestCase):
    def test_posix_dependency_preserves_host_os_and_pathlib(self):
        host_name, host_path = os.name, type(Path())
        with patch.object(runner, 'os', posix_runner_os()):
            self.assertEqual(runner.os.name, 'posix')
            self.assertEqual(os.name, host_name)
            self.assertIs(type(Path().absolute()), host_path)
        self.assertEqual(os.name, host_name)

    def result(self, text='DM compiler version 516.1688\nfixture.dmb - 0 errors, 0 warnings\n', stderr='', code=0):
        return subprocess.CompletedProcess([], code, text, stderr)

    def test_exact_compiler_and_clean_result(self):
        self.assertEqual(runner.validate_compiler(self.result(), '516.1688'), '516.1688')

    def test_missing_wrong_malformed_ambiguous_or_failed_compiler_refused(self):
        good = self.result().stdout
        for text in ('', good.replace('1688', '1681'), good.replace('1688', '1689'),
                     good.replace('1688', '1688 extra'), good.replace('1688', '01688'),
                     good + 'DM compiler version 516.1688\n', good.replace('0 errors', '1 errors'),
                     good.replace('0 warnings', '1 warnings'), good.replace('DM compiler', 'prefix DM compiler')):
            with self.subTest(text=text), self.assertRaises(RuntimeError):
                runner.validate_compiler(self.result(text), '516.1688')
        for result in (self.result(stderr='DM compiler version 516.1688\n'), self.result(code=1)):
            with self.assertRaises(RuntimeError):
                runner.validate_compiler(result, '516.1688')
        with self.assertRaises(RuntimeError):
            runner.validate_compiler(self.result(good.rstrip(), 'DM compiler version 516.1688\n'), '516.1688')

    def test_timeout_and_missing_runtime_log_retain_diagnostics(self):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / 'compiler.log'
            error = subprocess.TimeoutExpired(['never-run'], 1, output=b'partial stdout', stderr=b'partial stderr')
            with patch.object(runner.subprocess, 'run', side_effect=error), self.assertRaises(subprocess.TimeoutExpired):
                runner.run_logged(['never-run'], log)
            self.assertIn('partial stdout\npartial stderr', log.read_text())
            with patch.object(runner.subprocess, 'run', return_value=self.result('daemon stdout', 'daemon stderr')):
                runner.run_logged(['never-run'], log, runtime_log=Path(directory)/'missing.log')
            self.assertEqual(log.read_text(), 'daemon stdout\ndaemon stderr')

    def test_previous_evidence_is_not_reused_or_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            receipt = root/'out.evidence.json'
            receipt.write_text('preserve historical receipt')
            with patch.object(sys, 'argv', ['sprite', '--byond-bin', directory, '--output', str(root/'out.json')]), \
                 patch.object(runner, 'selected_runtime') as selected, self.assertRaises(RuntimeError):
                runner.main()
            selected.assert_not_called()
            self.assertEqual(receipt.read_text(), 'preserve historical receipt')

    def test_current_default_requires_archive_and_verified_members(self):
        args = argparse.Namespace(legacy_fixture_5161681=False, byond_archive=None, byond_bin=Path('/unused'))
        with self.assertRaises(ValueError):
            runner.selected_runtime(args)
        args.byond_archive = Path('/unused.zip')
        verifier = Mock()
        verifier.verify_linux.side_effect = ValueError('wrong archive or daemon')
        with patch.object(runner, 'os', posix_runner_os()), patch.object(runner, 'toolchain', return_value=verifier), self.assertRaises(ValueError):
            runner.selected_runtime(args)
        verifier.verify_linux.assert_called_once_with(args.byond_bin, args.byond_archive)

    def test_legacy_is_explicit_and_cannot_claim_current_archive(self):
        args = argparse.Namespace(legacy_fixture_5161681=True, byond_archive=None)
        self.assertEqual(runner.selected_runtime(args)['identity_basis'], 'explicit-historical-fixture-unverified-members')
        args.byond_archive = Path('/unused.zip')
        with self.assertRaises(ValueError):
            runner.selected_runtime(args)

    def test_initial_identity_failure_precedes_all_execution_and_source_changes(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(runner, 'ROOT', Path(directory)), \
             patch.object(sys, 'argv', ['sprite', '--byond-bin', directory, '--output', directory + '/out.json']), \
             patch.object(runner, 'selected_runtime', side_effect=ValueError('mismatch')), \
             patch.object(runner.subprocess, 'run') as run:
            with self.assertRaises(ValueError):
                runner.main()
            run.assert_not_called()
            self.assertEqual(list(Path(directory).iterdir()), [])

    def fixture(self, directory):
        root = Path(directory)
        sources = {'code/world.dm': '/world/New()\n\t..()\n/datum/global_init/New()\n\treturn\n',
                   'code/controllers/mc/globals.dm': '/datum/controller/global_vars/New()\n\treturn\n',
                   'civ13.dme': '#include "code\\world.dm"\n#include "code\\controllers\\mc\\globals.dm"\n',
                   'tests/sprites/fixture.dm': '// injected offline fixture\n', 'config/names/example.txt': 'fixture'}
        for name, text in sources.items():
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        return root

    def exercise(self, root, identities, compiler=None, max_calls=2):
        output = root / 'output/inventory.json'
        calls = []
        def run(command, **kwargs):
            calls.append(command)
            if command[0].endswith('DreamMaker'):
                for suffix in ('.dmb', '.rsc'):
                    (root / ('.sprite_audit' + suffix)).write_bytes(b'offline fake output')
                return compiler or self.result()
            self.assertTrue(command[0].endswith('DreamDaemon'))
            cwd = Path(kwargs['cwd'])
            (cwd / 'runtime.log').write_text('offline injected daemon output\n')
            (cwd / 'sprites.json').write_text('[{"valid": true}]')
            return self.result('', '')
        def git(command, **kwargs):
            if 'status' in command:
                return ''
            if 'diff' in command:
                return b''
            return ('b' if 'HEAD^{tree}' in command else 'a') * 40 + '\n'
        with patch.object(runner, 'ROOT', root), patch.object(runner, 'os', posix_runner_os()), \
             patch.object(sys, 'argv', ['sprite', '--byond-bin', str(root/'bin'), '--byond-archive', str(root/'pin.zip'), '--output', str(output)]), \
             patch.object(runner, 'selected_runtime', side_effect=identities), \
             patch.object(runner.subprocess, 'run', side_effect=run), \
             patch.object(runner.subprocess, 'check_output', side_effect=git), \
             patch.dict(sys.modules, {'validate': types.SimpleNamespace(validate=lambda *_: None)}), \
             patch.dict(runner.os.environ, {'LD_PRELOAD': '', 'LD_AUDIT': ''}):
            try:
                runner.main()
            finally:
                self.assertFalse(list(root.glob('.sprite_audit*')), 'Generated source/compiled files were not cleaned')
                self.assertLessEqual(len(calls), max_calls, 'Refusal occurred after an unadmitted native command')
        return calls, json.loads(output.with_suffix('.evidence.json').read_text())

    def test_injected_success_binds_actual_banner_source_and_runtime(self):
        identity = {'version': '516.1688', 'members': {'DreamDaemon': {'sha256': 'c'*64}}}
        with tempfile.TemporaryDirectory() as directory:
            calls, evidence = self.exercise(self.fixture(directory), [identity]*3)
        self.assertEqual(len(calls), 2)
        self.assertEqual(evidence['byond'], '516.1688')
        self.assertEqual(evidence['head_sha'], 'a'*40)
        self.assertEqual(evidence['source_tree'], 'b'*40)
        self.assertEqual(evidence['runtime_identity'], identity)
        self.assertEqual(len(evidence['compiler_log_sha256']), 64)
        self.assertEqual(len(evidence['runtime_log_sha256']), 64)
        self.assertEqual(len(evidence['inventory_sha256']), 64)

    def test_changed_source_refuses_success_receipt(self):
        identity = {'version': '516.1688'}
        with tempfile.TemporaryDirectory() as directory:
            root = self.fixture(directory)
            with patch.object(runner, 'source_identity', side_effect=[{'head_sha': 'a'*40}, {'head_sha': 'b'*40}]), self.assertRaises(RuntimeError):
                self.exercise(root, [identity]*3)
            receipt = json.loads((root/'output/inventory.evidence.json').read_text())
            self.assertEqual(receipt['status'], 'failed')
            self.assertEqual(receipt['head_sha'], 'a'*40)

    @unittest.skipIf(sys.platform == 'win32', 'Symlink creation requires extra Windows privilege')
    def test_dangling_generated_link_is_preserved_before_execution(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            existing = root/'.sprite_audit.dme'
            existing.symlink_to(root/'missing-target')
            with patch.object(runner, 'ROOT', root), \
                 patch.object(sys, 'argv', ['sprite', '--byond-bin', directory, '--output', directory+'/out.json']), \
                 patch.object(runner, 'selected_runtime', return_value={'version': '516.1688'}), \
                 patch.object(runner, 'source_identity', return_value={}), \
                 patch.object(runner.subprocess, 'run') as run, self.assertRaises(RuntimeError):
                runner.main()
            run.assert_not_called()
            self.assertTrue(existing.is_symlink())
            self.assertFalse((root/'missing-target').exists())

    def test_changed_identity_and_wrong_compiler_cleanup_without_acceptance(self):
        identity = {'version': '516.1688'}
        for identities, compiler, max_calls in (([identity, {'version': '516.1681'}], None, 1),
                                               ([identity], self.result(self.result().stdout.replace('1688', '1681')), 1),
                                               ([identity, identity, {'version': '516.1681'}], None, 2)):
            with tempfile.TemporaryDirectory() as directory, self.assertRaises(RuntimeError):
                self.exercise(self.fixture(directory), identities, compiler, max_calls)
                self.fail('Unverified extraction passed')

    def test_acceptance_lane_has_no_publication_or_automatic_trigger(self):
        text = (ROOT/'.github/workflows/api-pages.yml').read_text()
        self.assertNotIn('  pull_request:', text)
        self.assertIn('  workflow_dispatch:', text)
        self.assertIn('test "$EXPECTED_HEAD" = "$ACTUAL_HEAD"', text)
        self.assertIn('--negative-control', text)
        self.assertIn('contents: read', text)
        for action in ('configure-pages@', 'upload-pages-artifact@'):
            block = text[text.index('uses: actions/' + action):].split('      - ', 1)[0]
            self.assertIn("if: github.ref == 'refs/heads/master' && (github.event_name != 'workflow_dispatch' || !inputs.artifact_only)", block)
        deploy = text.split('  deploy:\n', 1)[1]
        self.assertIn("if: github.ref == 'refs/heads/master' && (github.event_name != 'workflow_dispatch' || !inputs.artifact_only)", deploy)
        self.assertIn('default: false', text)

    @unittest.skipIf(sys.platform == 'win32', 'Bash admission fixture runs on Linux')
    def test_actual_dispatch_admission_refuses_bad_mode_head_and_nonmaster_publication(self):
        text = (ROOT/'.github/workflows/api-pages.yml').read_text()
        block = text.split('          case "$ARTIFACT_ONLY" in\n', 1)[1].split('          esac', 1)[0]
        script = 'set -e\ncase "$ARTIFACT_ONLY" in\n' + block + 'esac\n'
        # git is a shell function, not an executable; no checkout or network work.
        script = 'git() { if [ "$1" = rev-parse ]; then printf "%s\\n" "$ACTUAL_HEAD"; fi; }\n' + script
        sha = 'a'*40
        for mode, ref, expected, passed in (
                ('true', 'refs/heads/review', sha, True), ('true', 'refs/heads/master', sha, True),
                ('false', 'refs/heads/master', '', True), ('', 'refs/heads/master', '', True),
                ('', 'refs/heads/review', '', False), ('false', 'refs/heads/review', '', False),
                ('garbage', 'refs/heads/master', '', False), ('true', 'refs/heads/review', '', False),
                ('true', 'refs/heads/review', 'b'*40, False), ('true', 'refs/tags/review', sha, False),
                ('false', 'refs/heads/master', sha, False)):
            with self.subTest(mode=mode, ref=ref, expected=expected):
                result = subprocess.run(['/bin/bash', '--noprofile', '--norc', '-c', script],
                                        env={'PATH': '', 'ARTIFACT_ONLY': mode, 'SOURCE_BRANCH': ref,
                                             'EXPECTED_HEAD': expected, 'ACTUAL_HEAD': sha},
                                        capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode == 0, passed, result.stderr)

    def test_active_pages_and_shared_callers_use_checked_archive(self):
        pages = (ROOT/'.github/workflows/api-pages.yml').read_text()
        self.assertNotIn('516.1681', pages)
        self.assertNotIn('civ13.com/downloads', pages)
        self.assertIn('byond_toolchain.py download --platform linux --source repository-release', pages)
        self.assertIn('byond_runtime.py --byond-bin', pages)
        self.assertIn('branches: [master]', pages)
        self.assertIn('uses: actions/deploy-pages@', pages)
        for line in (ROOT/'.github/workflows/test.yml').read_text().splitlines():
            if 'tests/sprites/run.py ' in line or 'build-crafting-atlas.py --output' in line:
                self.assertIn('--byond-archive "$GITHUB_WORKSPACE/BYOND/pinned.zip"', line)


if __name__ == '__main__':
    unittest.main()
