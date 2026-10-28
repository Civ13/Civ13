import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch
import subprocess
import tempfile
import os
import json
import sys

spec = importlib.util.spec_from_file_location('selection', Path(__file__).resolve().parents[1] / 'scripts/select-ci.py')
selection = importlib.util.module_from_spec(spec)
spec.loader.exec_module(selection)

class SelectionTests(unittest.TestCase):
    def test_manual_comparison_base_requires_distinct_local_full_commits(self):
        with tempfile.TemporaryDirectory() as directory:
            def git(*args):
                return subprocess.check_output(['git', '-C', directory, *args], stderr=subprocess.PIPE).decode().strip()
            git('init')
            git('config', 'user.name', 'Selection test')
            git('config', 'user.email', 'selection@example.invalid')
            file = Path(directory) / 'file.txt'
            file.write_text('base', encoding='utf-8')
            git('add', 'file.txt')
            git('commit', '-m', 'base')
            base = git('rev-parse', 'HEAD')
            file.write_text('head', encoding='utf-8')
            git('add', 'file.txt')
            git('commit', '-m', 'head')
            head = git('rev-parse', 'HEAD')
            selection.validate_manual_base(base, head, cwd=directory)
            for invalid in ('', 'HEAD', '0' * 40, 'f' * 40, head):
                with self.subTest(base=invalid), self.assertRaises(ValueError):
                    selection.validate_manual_base(invalid, head, cwd=directory)

    def test_manual_workflow_routes_one_base_through_all_receipts(self):
        workflow = (Path(__file__).resolve().parents[1] / '.github/workflows/test.yml').read_text()
        self.assertIn('      comparison_base:\n', workflow)
        self.assertIn('        required: true\n', workflow.split('      comparison_base:\n', 1)[1].split('      extensive_regressions:', 1)[0])
        expression = "github.event_name == 'workflow_dispatch' && inputs.comparison_base || github.event.pull_request.base.sha || github.event.before"
        self.assertEqual(workflow.count(expression), 4)

    def test_manual_selector_publishes_only_validated_base_receipt(self):
        source = Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / 'repo'
            (root / 'scripts').mkdir(parents=True)
            for name in ('select-ci.py', 'ci_baseline.py', 'byond_toolchain.py'):
                (root / 'scripts' / name).write_bytes((source / 'scripts' / name).read_bytes())
            def git(*args):
                return subprocess.check_output(['git', '-c', 'user.name=CI fixture',
                    '-c', 'user.email=ci@example.invalid', '-c', 'commit.gpgsign=false', *args],
                    cwd=root, stderr=subprocess.PIPE, text=True, timeout=15).strip()
            git('init', '-q')
            (root / 'README.md').write_text('base\n', encoding='utf-8')
            git('add', '.')
            git('commit', '-qm', 'base')
            base = git('rev-parse', 'HEAD')
            (root / 'README.md').write_text('head\n', encoding='utf-8')
            git('commit', '-qam', 'head')
            head = git('rev-parse', 'HEAD')
            output, receipt = Path(directory) / 'output', Path(directory) / 'receipt.json'
            script = root / 'scripts/select-ci.py'
            args = [sys.executable, '-B', str(script), '--base', base, '--head', head,
                    '--event', 'workflow_dispatch', '--build-prefix', 'true',
                    '--output', str(output), '--receipt', str(receipt)]
            env = dict(os.environ)
            env.pop('GITHUB_EVENT_PATH', None)
            env.pop('GITHUB_STEP_SUMMARY', None)
            result = subprocess.run(args, cwd=root, env=env, capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr)
            plan = json.loads(receipt.read_text(encoding='utf-8'))
            self.assertEqual((plan['base'], plan['requested_base'], plan['head']), (base, base, head))
            self.assertEqual(plan['comparison']['status'], 'available')
            self.assertEqual(plan['new_tests'], [])
            output.unlink(); receipt.unlink()
            args[args.index('--base') + 1] = head
            result = subprocess.run(args, cwd=root, env=env, capture_output=True, text=True, timeout=30)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('must differ', result.stderr)
            self.assertFalse(output.exists())
            self.assertFalse(receipt.exists())

    def test_extensive_is_explicit_manual_opt_in(self):
        self.assertTrue(selection.needs_extensive('workflow_dispatch', True))
        self.assertFalse(selection.needs_extensive('workflow_dispatch', False))
        for event in ('push', 'pull_request', 'pull_request_target', ''):
            with self.subTest(event=event):
                self.assertFalse(selection.needs_extensive(event, True))
                self.assertFalse(selection.needs_extensive(event, False))

    def test_documentation_only(self):
        self.assertFalse(selection.needs_game(['AGENTS.md', 'docs/api/search.js',
            'docs/api/search.css', 'scripts/build-api-docs.py',
            '.github/workflows/api-pages.yml']))
    def test_shared_and_runtime_paths(self):
        for path in ('civ13.dme', 'code/__defines/maps.dm', 'code/world.dm',
                     'maps/nomads/map.dmm', 'icons/obj/test.dmi', 'sound/a.ogg',
                     'config/config.txt', '_compile_options.dm', 'docs/new_include.dm',
                     '.github/workflows/test.yml', '.github/workflows/ci-selection.yml',
                     'scripts/select-ci.py', 'tests/chemistry/run.py',
                     'scripts/test-power.ps1', 'tools/new-tool/file'):
            with self.subTest(path=path):
                self.assertTrue(selection.needs_game(['docs/api/README.md', path]))
    def test_renamed_or_deleted_game_file(self):
        # git diff --name-only without rename detection returns both old/new paths.
        self.assertTrue(selection.needs_game(['code/old.dm', 'docs/moved.md']))
    def test_missing_base_or_manual_runs_all(self):
        self.assertTrue(selection.select('', 'abc')[0])
        self.assertTrue(selection.select('0' * 40, 'abc')[0])
    def test_failed_diff_runs_all(self):
        with patch.object(selection.subprocess, 'check_output',
                          side_effect=subprocess.CalledProcessError(1, 'git')):
            self.assertTrue(selection.select('abc', 'def')[0])
    def test_nul_delimited_paths(self):
        with patch.object(selection.subprocess, 'check_output',
                          return_value=b'docs/api/a file.md\0'):
            self.assertFalse(selection.select('abc', 'def')[0])


    def test_real_git_diff_docs_shared_and_deleted(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def git(*args):
                return subprocess.check_output(['git', '-C', directory, *args], stderr=subprocess.PIPE).decode().strip()
            git('init')
            git('config', 'user.name', 'Selection test')
            git('config', 'user.email', 'selection@example.invalid')
            (root / 'docs').mkdir()
            (root / 'docs/note.md').write_text('before')
            (root / 'shared.dm').write_text('// before')
            git('add', '.')
            git('commit', '-m', 'base')
            base = git('rev-parse', 'HEAD')
            (root / 'docs/note.md').write_text('after')
            git('add', '.')
            git('commit', '-m', 'docs')
            docs = git('rev-parse', 'HEAD')
            previous = os.getcwd()
            try:
                os.chdir(root)
                self.assertFalse(selection.select(base, docs)[0])
                (root / 'shared.dm').unlink()
                git('add', '-A')
                git('commit', '-m', 'delete shared include')
                self.assertTrue(selection.select(docs, git('rev-parse', 'HEAD'))[0])
            finally:
                os.chdir(previous)

if __name__ == '__main__':
    unittest.main()
