"""Legacy/native admission remains guarded; reviewed offline baseline is separate."""
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

ROOF_NATIVE_NAME = 'Verify synthetic saved-roof recovery and two defect controls'
ROOF_NATIVE_GUARD = ("github.event_name == 'pull_request' && github.event.action != 'edited' && "
                     "needs.changes.outputs.game == 'true' && "
                     "contains(fromJSON(needs.changes.outputs.new_tests), 'tests/roof_area_recovery')")


class RegressionPolicyTests(unittest.TestCase):
    ADMISSION_STEP = 'Verify persistence admission adapter and ordinary restore compatibility'
    ADMISSION_GATES = (
        '!cancelled()', "needs.changes.result == 'success'",
        "steps.compile.outcome == 'success'",
        "(needs.changes.outputs.extensive == 'true' || contains(fromJSON(needs.changes.outputs.new_tests), 'tests/persistence_admission'))",
    )
    VEHICLE_DIAGNOSTICS = {
        'Diagnose extraction vehicle custody ' + suffix
        for suffix in ('positive', 'roster omission', 'reservation omission',
                       'issuance omission', 'persistence omission')
    }
    VEHICLE_GATES = (
        '!cancelled()', "needs.changes.result == 'success'",
        "steps.compile.outcome == 'success'",
        "needs.changes.outputs.extensive == 'true'",
    )

    def assert_vehicle_diagnostic_guard(self, block):
        self.assertIn('if: ${{ ' + ' && '.join(self.VEHICLE_GATES) + ' }}', block)
        self.assertNotIn('continue-on-error:', block)

    def assert_admission_guard(self, block):
        self.assertIn('        if: ${{ ' + ' && '.join(self.ADMISSION_GATES) + ' }}\n', block)
        self.assertNotIn('continue-on-error:', block)

    def test_admission_policy_requires_complete_independent_gate(self):
        block = '        if: ${{ ' + ' && '.join(self.ADMISSION_GATES) + ' }}\n'
        self.assert_admission_guard(block)
        for omitted in self.ADMISSION_GATES:
            with self.subTest(omitted=omitted), self.assertRaises(AssertionError):
                self.assert_admission_guard(
                    '        if: ${{ ' + ' && '.join(gate for gate in self.ADMISSION_GATES
                                                      if gate != omitted) + ' }}\n')
        with self.assertRaises(AssertionError):
            self.assert_admission_guard(block.replace('tests/persistence_admission', 'tests/unrelated'))
        with self.assertRaises(AssertionError):
            self.assert_admission_guard(block + '        continue-on-error: true\n')

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
        self.assert_explicit_suite_guards(workflow)

    def assert_explicit_suite_guards(self, workflow):
        import re
        diagnostics = []
        admission_steps = 0
        for block in re.split(r'(?=      - name:)', workflow):
            name = re.search(r'^      - name: (.+)$', block, re.MULTILINE)
            if name and name.group(1) == self.ADMISSION_STEP:
                admission_steps += 1
                self.assert_admission_guard(block)
                continue
            if name and name.group(1) in self.VEHICLE_DIAGNOSTICS:
                diagnostics.append(name.group(1))
                self.assert_vehicle_diagnostic_guard(block)
                continue
            if 'uses: actions/upload-artifact' in block:
                continue
            if block.startswith('      - name: Require selected jobs and exact-source execution receipts\n'):
                # This reads the selected suite ID as data; it cannot launch it.
                self.assertIn('scripts/ci_baseline.py aggregate ', block)
                self.assertNotIn('unittest', block)
                continue
            if re.search(r'(tests/|unittest discover|scripts/(check-recipes|test-power|test-batteries|check-battery-items))', block):
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
                if block.startswith('      - name: ' + ROOF_NATIVE_NAME + '\n'):
                    # The reviewed roof fixture deliberately has no extensive
                    # or manual entry. Accept only its complete narrower guard.
                    self.assertEqual(re.findall(r'^        id: (.+)$', block, re.M), ['roof_native'])
                    self.assertEqual(re.findall(r'^        if: (.+)$', block, re.M), [ROOF_NATIVE_GUARD])
                    self.assertEqual(re.findall(r'^        timeout-minutes: (.+)$', block, re.M), ['40'])
                    self.assertIn('          ROOF_HEAD: ${{ github.event.pull_request.head.sha }}\n', block)
                    self.assertIn('tests/roof_area_recovery/run_linux.py', block)
                    self.assertNotIn('workflow_dispatch', block)
                    self.assertNotIn('secrets.', block)
                    continue
                self.assertRegex(block, r"if: (?:always\(\) && \()?needs\.changes\.outputs\.extensive == 'true' \|\| contains\(fromJSON\(needs\.changes\.outputs\.new_tests\)")
        self.assertEqual(sorted(diagnostics), sorted(self.VEHICLE_DIAGNOSTICS))
        self.assertEqual(admission_steps, 1)
        self.assertIn("if: needs.changes.outputs.game == 'true'\n        timeout-minutes: 15\n", workflow)
        self.assertIn('bash ./scripts/travis_pre_byond.sh 2>&1 | tee .ci/compile/bootstrap.log', workflow)

    def test_roof_native_guard_rejects_each_missing_or_weakened_clause(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text()
        self.assertEqual(workflow.count('        if: ' + ROOF_NATIVE_GUARD + '\n'), 1)
        clauses = ("github.event_name == 'pull_request'", "github.event.action != 'edited'",
                   "needs.changes.outputs.game == 'true'",
                   "contains(fromJSON(needs.changes.outputs.new_tests), 'tests/roof_area_recovery')")
        for clause in clauses:
            changed = ' && '.join(part for part in ROOF_NATIVE_GUARD.split(' && ') if part != clause)
            with self.subTest(omitted=clause), self.assertRaises(AssertionError):
                self.assert_explicit_suite_guards(workflow.replace(ROOF_NATIVE_GUARD, changed, 1))
        for changed in (ROOF_NATIVE_GUARD.replace(' && ', ' || ', 1), ROOF_NATIVE_GUARD + ' || true',
                        ROOF_NATIVE_GUARD.replace("'pull_request'", "'workflow_dispatch'"),
                        ROOF_NATIVE_GUARD.replace("!= 'edited'", "== 'edited'"),
                        ROOF_NATIVE_GUARD.replace("game == 'true'", "game == 'false'"),
                        ROOF_NATIVE_GUARD.replace('tests/roof_area_recovery', 'tests/other')):
            with self.subTest(changed=changed), self.assertRaises(AssertionError):
                self.assert_explicit_suite_guards(workflow.replace(ROOF_NATIVE_GUARD, changed, 1))

    def test_roof_native_exception_is_bound_to_fixture_and_limits(self):
        import re
        workflow = (ROOT / '.github/workflows/test.yml').read_text()
        block = next(part for part in re.split(r'(?=      - name:)', workflow)
                     if part.startswith('      - name: ' + ROOF_NATIVE_NAME + '\n'))
        for before, after in (('        id: roof_native\n', ''),
                              ('        id: roof_native\n', '        id: other\n'),
                              ('        timeout-minutes: 40\n', ''),
                              ('        timeout-minutes: 40\n', '        timeout-minutes: 41\n'),
                              ('${{ github.event.pull_request.head.sha }}', '${{ github.sha }}'),
                              ('tests/roof_area_recovery/run_linux.py', 'tests/other/run.py'),
                              ('      - name: ' + ROOF_NATIVE_NAME, '      - name: Other native fixture'),
                              ('        if: ' + ROOF_NATIVE_GUARD + '\n', '')):
            with self.subTest(before=before, after=after), self.assertRaises(AssertionError):
                self.assert_explicit_suite_guards(workflow.replace(block, block.replace(before, after), 1))


if __name__ == '__main__':
    unittest.main()
