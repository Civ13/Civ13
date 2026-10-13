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
    VEHICLE_DIAGNOSTICS = {
        'Diagnose extraction vehicle custody ' + suffix
        for suffix in ('positive', 'roster omission', 'reservation omission',
                       'issuance omission', 'persistence omission')
    }
    VEHICLE_GATES = (
        '!cancelled()', "needs.changes.result == 'success'",
        "steps.byond_setup.outcome == 'success'",
        "needs.changes.outputs.extensive == 'true'",
    )

    def assert_vehicle_diagnostic_guard(self, block):
        self.assertIn('if: ${{ ' + ' && '.join(self.VEHICLE_GATES) + ' }}', block)
        self.assertNotIn('continue-on-error:', block)

    def test_vehicle_diagnostic_policy_accepts_only_complete_gate(self):
        block = 'if: ${{ ' + ' && '.join(self.VEHICLE_GATES) + ' }}'
        self.assert_vehicle_diagnostic_guard(block)
        for omitted in self.VEHICLE_GATES:
            with self.subTest(omitted=omitted), self.assertRaises(AssertionError):
                self.assert_vehicle_diagnostic_guard(
                    'if: ${{ ' + ' && '.join(gate for gate in self.VEHICLE_GATES
                                              if gate != omitted) + ' }}')
        with self.assertRaises(AssertionError):
            self.assert_vehicle_diagnostic_guard(block + '\ncontinue-on-error: true')

    def test_only_added_executable_tests_select_their_suite(self):
        with patch.object(selection.subprocess, 'check_output', return_value=
                          b'tests/weather/new_probe.dm\0tests/weather/README.md\0'
                          b'tests/test_new.py\0tools/mcp/new.test.mjs\0code/new.dm\0'):
            self.assertEqual(selection.introduced_tests('base', 'head', 'pull_request'),
                             ['tests/test_new.py', 'tests/weather', 'tools/mcp'])

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
        diagnostics = []
        for block in re.split(r'(?=      - name:)', workflow):
            name = re.search(r'^      - name: (.+)$', block, re.MULTILINE)
            if name and name.group(1) in self.VEHICLE_DIAGNOSTICS:
                diagnostics.append(name.group(1))
                self.assert_vehicle_diagnostic_guard(block)
                continue
            if 'uses: actions/upload-artifact' in block:
                continue
            if re.search(r'(tests/|unittest discover|scripts/(check-recipes|test-power|test-batteries|check-battery-items))', block):
                self.assertIn("if: needs.changes.outputs.extensive == 'true' || contains(fromJSON(needs.changes.outputs.new_tests)", block)
        self.assertEqual(sorted(diagnostics), sorted(self.VEHICLE_DIAGNOSTICS))
        self.assertIn("id: byond_setup\n        if: needs.changes.outputs.game == 'true'\n        run: sudo bash", workflow)
        self.assertIn("if: needs.changes.outputs.game == 'true'\n        run: sudo bash", workflow)


if __name__ == '__main__':
    unittest.main()
