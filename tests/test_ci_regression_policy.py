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

ROOF_NATIVE_NAME = 'Verify synthetic saved-roof recovery and two defect controls'
ROOF_HEAD_REQUEST = "contains(github.event.pull_request.labels.*.name, format('roof-ci:{0}', github.event.pull_request.head.sha))"
ROOF_SUITE_SELECTION = ("(contains(fromJSON(needs.changes.outputs.new_tests), 'tests/roof_area_recovery') || "
                       + ROOF_HEAD_REQUEST + ')')
ROOF_NATIVE_GUARD = ("github.event_name == 'pull_request' && github.event.action != 'edited' && "
                     "needs.changes.outputs.game == 'true' && " + ROOF_SUITE_SELECTION)


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
        self.assert_explicit_suite_guards(workflow)

    def assert_explicit_suite_guards(self, workflow):
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
        self.assertIn("if: needs.changes.outputs.game == 'true'\n        run: sudo bash", workflow)

    def test_roof_native_guard_rejects_each_missing_or_weakened_clause(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text()
        self.assertEqual(workflow.count('        if: ' + ROOF_NATIVE_GUARD + '\n'), 1)
        clauses = ("github.event_name == 'pull_request'", "github.event.action != 'edited'",
                   "needs.changes.outputs.game == 'true'",
                   ROOF_SUITE_SELECTION)
        for clause in clauses:
            changed = ' && '.join(part for part in ROOF_NATIVE_GUARD.split(' && ') if part != clause)
            with self.subTest(omitted=clause), self.assertRaises(AssertionError):
                self.assert_explicit_suite_guards(workflow.replace(ROOF_NATIVE_GUARD, changed, 1))
        for changed in (ROOF_NATIVE_GUARD.replace(' && ', ' || ', 1), ROOF_NATIVE_GUARD + ' || true',
                        ROOF_NATIVE_GUARD.replace("'pull_request'", "'workflow_dispatch'"),
                        ROOF_NATIVE_GUARD.replace("!= 'edited'", "== 'edited'"),
                        ROOF_NATIVE_GUARD.replace("game == 'true'", "game == 'false'"),
                        ROOF_NATIVE_GUARD.replace('tests/roof_area_recovery', 'tests/other'),
                        ROOF_NATIVE_GUARD.replace("format('roof-ci:{0}', github.event.pull_request.head.sha)", "'roof-ci'"),
                        ROOF_NATIVE_GUARD.replace('github.event.pull_request.head.sha', 'github.sha')):
            with self.subTest(changed=changed), self.assertRaises(AssertionError):
                self.assert_explicit_suite_guards(workflow.replace(ROOF_NATIVE_GUARD, changed, 1))

    def test_roof_explicit_request_is_head_bound_and_keeps_native_event_guards(self):
        import re
        workflow = (ROOT / '.github/workflows/test.yml').read_text()
        block = next(part for part in re.split(r'(?=      - name:)', workflow)
                     if part.startswith('      - name: ' + ROOF_NATIVE_NAME + '\n'))
        expression = re.findall(r'^        if: (.+)$', block, re.M)[0]
        # Evaluate only these five known Boolean operands, not arbitrary Actions expressions.
        translated = expression
        for text, variable in (("github.event_name == 'pull_request'", 'pr_event'),
                               ("github.event.action != 'edited'", 'not_edited'),
                               ("needs.changes.outputs.game == 'true'", 'game'),
                               ("contains(fromJSON(needs.changes.outputs.new_tests), 'tests/roof_area_recovery')", 'introduced'),
                               (ROOF_HEAD_REQUEST, 'requested')):
            self.assertEqual(translated.count(text), 1)
            translated = translated.replace(text, variable)
        translated = translated.replace('&&', 'and').replace('||', 'or')
        self.assertRegex(translated, r'^[a-z_ ()]+$')
        head = 'a' * 40
        requested = 'roof-ci:' + head
        cases = [('pull_request', 'synchronize', True, False, [requested], True),
                 ('pull_request', 'opened', True, False, [requested], True),
                 ('pull_request', 'reopened', True, False, [requested], True),
                 ('pull_request', 'synchronize', True, True, [], True),
                 ('pull_request', 'synchronize', True, False, [], False),
                 ('pull_request', 'synchronize', True, False, ['roof-ci:' + 'b' * 40], False),
                 ('pull_request', 'synchronize', True, False, ['prefix-' + requested], False),
                 ('pull_request', 'synchronize', True, False, [requested + '-suffix'], False),
                 ('pull_request', 'synchronize', True, False, ['roof-ci'], False),
                 ('pull_request', 'edited', True, False, [requested], False),
                 ('pull_request', 'synchronize', False, False, [requested], False),
                 ('push', 'synchronize', True, True, [requested], False),
                 ('workflow_dispatch', 'synchronize', True, True, [requested], False),
                 ('pull_request_target', 'synchronize', True, True, [requested], False)]
        for event, action, game, introduced, labels, expected in cases:
            with self.subTest(event=event, action=action, labels=labels):
                values = dict(pr_event=event == 'pull_request', not_edited=action != 'edited',
                              game=game, introduced=introduced,
                              requested=requested.casefold() in [label.casefold() for label in labels])
                self.assertEqual(eval(translated, {'__builtins__': {}}, values), expected)
        self.assertIn('types: [ opened, synchronize, reopened, edited ]', workflow)
        self.assertNotIn('types: [ opened, synchronize, reopened, edited, labeled ]', workflow)
        offline = next(part for part in re.split(r'(?=      - name:)', workflow)
                       if part.startswith('      - name: Prepare roof-area recovery fixture offline\n'))
        self.assertIn(ROOF_HEAD_REQUEST, offline)
        example = (ROOT / 'tests/roof_area_recovery/ci-steps.yml.example').read_text()
        self.assertIn('  if: ' + ROOF_NATIVE_GUARD + '\n', example)

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
