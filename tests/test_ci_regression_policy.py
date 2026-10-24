"""Policy acceptance: new PR tests run once; existing regressions stay opt-in."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import os
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('selection', ROOT / 'scripts/select-ci.py')
selection = importlib.util.module_from_spec(spec)
spec.loader.exec_module(selection)


class RegressionPolicyTests(unittest.TestCase):
    def test_only_added_executable_tests_select_their_suite(self):
        with patch.object(selection.subprocess, 'check_output', return_value=
                          b'tests/weather/new_probe.dm\0tests/weather/README.md\0'
                          b'tests/test_new.py\0tools/mcp/new.test.mjs\0code/new.dm\0'):
            self.assertEqual(selection.introduced_tests('base', 'head', 'pull_request'),
                             ['tests/test_new.py', 'tests/weather', 'tools/mcp'])

    def test_bounded_build_only_added_registered_tests_select_suite(self):
        for name in ('test_guard.py', 'test_windows.py'):
            with self.subTest(name=name), patch.object(selection.subprocess, 'check_output',
                    return_value=f'scripts/opendream/bounded_build/{name}\0'.encode()):
                self.assertEqual(selection.introduced_tests('base', 'head', 'pull_request'),
                                 ['scripts/opendream/bounded_build'])
        with patch.object(selection.subprocess, 'check_output', return_value=
                b'scripts/opendream/bounded_build/guard.py\0scripts/opendream/bounded_build/README.md\0'):
            self.assertEqual(selection.introduced_tests('base', 'head', 'pull_request'), [])

    def test_push_manual_missing_or_failed_comparisons_never_auto_select(self):
        for event in ('push', 'workflow_dispatch', 'pull_request_target', ''):
            self.assertEqual(selection.introduced_tests('base', 'head', event), [])
        self.assertEqual(selection.introduced_tests('', 'head', 'pull_request'), [])
        self.assertEqual(selection.introduced_tests('0' * 40, 'head', 'pull_request'), [])
        with patch.object(selection.subprocess, 'check_output',
                          side_effect=subprocess.CalledProcessError(1, 'git')):
            self.assertEqual(selection.introduced_tests('base', 'head', 'pull_request'), [])

    def test_real_git_added_modified_renamed_and_post_merge_tests(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def git(*args):
                return subprocess.check_output(['git', '-C', directory, *args],
                                               stderr=subprocess.PIPE).decode().strip()
            git('init')
            git('config', 'user.name', 'CI policy test')
            git('config', 'user.email', 'ci@example.invalid')
            (root / 'tests/weather').mkdir(parents=True)
            (root / 'tests/weather/probe.dm').write_text('// original')
            git('add', '.')
            git('commit', '-m', 'base')
            base = git('rev-parse', 'HEAD')
            (root / 'tests/weather/probe.dm').rename(root / 'tests/weather/moved.dm')
            (root / 'tests/weather/README.md').write_text('new documentation')
            git('add', '-A')
            git('commit', '-m', 'move existing test')
            moved = git('rev-parse', 'HEAD')
            previous = os.getcwd()
            try:
                os.chdir(root)
                self.assertEqual(selection.introduced_tests(base, moved, 'pull_request'), [])
                (root / 'tests/weather/moved.dm').write_text('// modified')
                git('add', '.')
                git('commit', '-m', 'edit existing test')
                modified = git('rev-parse', 'HEAD')
                self.assertEqual(selection.introduced_tests(moved, modified, 'pull_request'), [])
                (root / 'tests/weather/new_probe.dm').write_text('// new integration')
                git('add', '.')
                git('commit', '-m', 'introduce integration')
                head = git('rev-parse', 'HEAD')
                self.assertEqual(selection.introduced_tests(modified, head, 'pull_request'), ['tests/weather'])
                self.assertEqual(selection.introduced_tests(modified, head, 'push'), [])
                self.assertEqual(selection.introduced_tests(head, head, 'pull_request'), [])
            finally:
                os.chdir(previous)

    def test_offline_and_game_regressions_have_explicit_suite_guards(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text()
        import re
        for block in re.split(r'(?=      - name:)', workflow):
            if 'uses: actions/upload-artifact' in block:
                continue
            if re.search(r'(tests/|unittest discover|scripts/(check-recipes|test-power|test-batteries|check-battery-items))', block):
                # These two cheap source-only checks intentionally run on every PR.
                always_on = {
                    'Verify noninteractive BYOND bootstrap commands offline': 'python3 -B -m unittest discover -s tests -p test_byond_bootstrap.py -v',
                    'Test serializer profiling source contracts': 'python3 -B tests/world_save/test_progress_sources.py -v',
                }
                if any(block.startswith('      - name: ' + name + '\n') for name in always_on):
                    name = block.splitlines()[0].removeprefix('      - name: ')
                    self.assertEqual(block, f'      - name: {name}\n        run: {always_on[name]}\n')
                    continue
                if block.startswith('      - name: Opt-in serializer phase profiling\n'):
                    self.assertIn("        if: github.event_name == 'workflow_dispatch' && inputs.world_save_profile_regressions\n", block)
                    self.assertRegex(workflow, r'world_save_profile_regressions:\n        description: [^\n]+\n        type: boolean\n        default: false\n')
                    continue
                if block.startswith('      - name: Verify paid rack save and six mutation controls\n'):
                    self.assertIn("        if: github.event_name == 'workflow_dispatch' && inputs.rack_save_regressions\n", block)
                    self.assertRegex(workflow, r'rack_save_regressions:\n        description: [^\n]+\n        type: boolean\n        default: false\n')
                    continue
                if block.startswith('      - name: Verify private collector native publication\n'):
                    # This narrower hosted fixture has no manual/extensive
                    # entry. Keep its introduced-PR-only gate explicit.
                    self.assertIn("        if: contains(fromJSON(needs.changes.outputs.new_tests), 'tests/nomads_lifecycle')\n", block)
                    self.assertIn('timeout-minutes: 3\n', block)
                    self.assertIn('tests/nomads_lifecycle/run_variable_probe_linux.py', block)
                    self.assertNotIn('workflow_dispatch', block)
                    self.assertNotIn('secrets.', block)
                    continue
                self.assertRegex(block, r"if: (?:always\(\) && \()?needs\.changes\.outputs\.extensive == 'true' \|\| contains\(fromJSON\(needs\.changes\.outputs\.new_tests\)")
        self.assertIn("if: needs.changes.outputs.game == 'true'\n        run: sudo bash", workflow)


if __name__ == '__main__':
    unittest.main()
