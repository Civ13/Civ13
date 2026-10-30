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
    def test_mcp_changed_files_and_comparison_failure(self):
        for path in ('tools/mcp/server.mjs', 'tools/mcp/test.mjs',
                     'tools/mcp/package-lock.json', '.github/workflows/mcp.yml'):
            with self.subTest(path=path), patch.object(selection.subprocess, 'check_output',
                                                        return_value=(path + '\0').encode()):
                self.assertTrue(selection.select_mcp('a' * 40, 'b' * 40, 'pull_request'))
                self.assertTrue(selection.select_mcp('a' * 40, 'b' * 40, 'push'))
        with patch.object(selection.subprocess, 'check_output', return_value=b'code/world.dm\0'):
            self.assertFalse(selection.select_mcp('a' * 40, 'b' * 40, 'pull_request'))
        with patch.object(selection.subprocess, 'check_output', side_effect=subprocess.CalledProcessError(1, 'git')):
            with self.assertRaises(RuntimeError):
                selection.select_mcp('a' * 40, 'b' * 40, 'pull_request')
        with self.assertRaises(RuntimeError):
            selection.select_mcp('', 'b' * 40, 'pull_request')
        self.assertTrue(selection.select_mcp('', '', 'workflow_dispatch'))
        self.assertTrue(selection.select_mcp('0' * 40, 'b' * 40, 'push'))

    def test_mcp_workflow_keeps_both_platforms_and_requires_selection(self):
        workflow = (Path(__file__).resolve().parents[1] / '.github/workflows/mcp.yml').read_text()
        self.assertIn('os: [ubuntu-latest, windows-latest]', workflow)
        self.assertIn("if: needs.changes.outputs.mcp == 'true'", workflow)
        self.assertIn('--mcp-only', workflow)
        self.assertIn('scripts/ci_checkout_refs.py', workflow)

    def test_mcp_selector_real_diff_and_no_output_on_failure(self):
        script = Path(__file__).resolve().parents[1] / 'scripts/select-ci.py'
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def git(*args):
                return subprocess.check_output(['git', '-c', 'user.name=Fixture',
                    '-c', 'user.email=fixture@example.invalid', '-c', 'commit.gpgsign=false',
                    *args], cwd=root, stderr=subprocess.PIPE, text=True).strip()
            git('init', '-q')
            (root / 'tools/mcp').mkdir(parents=True)
            for name in ('server.mjs', 'test.mjs'):
                (root / 'tools/mcp' / name).write_text('before', encoding='utf-8')
            git('add', '.')
            git('commit', '-qm', 'base')
            base = git('rev-parse', 'HEAD')
            for name in ('server.mjs', 'test.mjs'):
                (root / 'tools/mcp' / name).write_text('after', encoding='utf-8')
                git('add', '.')
                git('commit', '-qm', name)
                head = git('rev-parse', 'HEAD')
                output = root / 'selection-output'
                args = [sys.executable, '-B', str(script), '--mcp-only', '--base', base,
                        '--head', head, '--event', 'pull_request', '--output', str(output)]
                result = subprocess.run(args, cwd=root, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(output.read_text(encoding='utf-8'), 'mcp=true\n')
                output.unlink()
                args[args.index('--base') + 1] = 'f' * 40
                result = subprocess.run(args, cwd=root, capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(output.exists())
                base = head

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
        expression = "${{ github.event_name == 'workflow_dispatch' && inputs.comparison_base || github.event.pull_request.base.sha || github.event.before || '' }}"

        def assert_routes(source):
            changes = source.split('\n  changes:\n', 1)[1].split('\n  baseline:\n', 1)[0]
            baseline = source.split('\n  baseline:\n', 1)[1].split('\n  evidence-checker:\n', 1)[0]
            build = source.split('\n  build:\n', 1)[1].split('\n  ci-required:\n', 1)[0]
            aggregate = source.split('\n  ci-required:\n', 1)[1]
            self.assertIn('      base: ' + expression, changes)
            for job in (baseline, aggregate):
                prepare = job.split('      - name: Prepare exact comparison commit\n', 1)[1].split('\n      - ', 1)[0]
                self.assertIn('          BASE_REF: ' + expression, prepare)
            for job in (baseline, build, aggregate):
                self.assertIn('          CI_BASE: ' + expression, job)

        assert_routes(workflow)
        # Mutate each actual producer/consumer binding, independent of unrelated steps.
        for job, end, field in (('changes', 'baseline', 'base'),
                                ('baseline', 'evidence-checker', 'BASE_REF'),
                                ('baseline', 'evidence-checker', 'CI_BASE'),
                                ('build', 'ci-required', 'CI_BASE'),
                                ('ci-required', None, 'BASE_REF'),
                                ('ci-required', None, 'CI_BASE')):
            start = workflow.index('\n  ' + job + ':\n')
            stop = workflow.index('\n  ' + end + ':\n', start) if end else len(workflow)
            section = workflow[start:stop]
            binding = field + ': ' + expression
            self.assertEqual(section.count(binding), 1)
            altered = workflow[:start] + section.replace(binding, field + ': ${{ github.sha }}', 1) + workflow[stop:]
            with self.subTest(job=job, field=field), self.assertRaises(AssertionError):
                assert_routes(altered)

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
