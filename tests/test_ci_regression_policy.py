"""Legacy/native admission remains guarded; reviewed offline baseline is separate."""
import importlib.util
from pathlib import Path
import subprocess
import sys
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
ROOF_SUITE_SELECTION = ("(contains(fromJSON(needs.changes.outputs.new_tests || '[]'), 'tests/roof_area_recovery') || "
                       + ROOF_HEAD_REQUEST + ')')
ROOF_NATIVE_GUARD = ("github.event_name == 'pull_request' && github.event.action != 'edited' && "
                     "needs.changes.outputs.game == 'true' && " + ROOF_SUITE_SELECTION)


class RegressionPolicyTests(unittest.TestCase):
    MALL_STEP = 'Verify native mall interactions and omission controls'
    MALL_GATES = (
        '!cancelled()', "needs.changes.result == 'success'",
        "steps.compile.outcome == 'success'",
        "(needs.changes.outputs.extensive == 'true' || contains(fromJSON(needs.changes.outputs.new_tests || '[]'), 'tests/extraction') || inputs.mall_regressions == true)",
    )

    def assert_mall_guard(self, block):
        self.assertIn('        if: ${{ ' + ' && '.join(self.MALL_GATES) + ' }}\n', block)
        self.assertNotIn('continue-on-error:', block)

    def test_mall_guard_rejects_missing_prerequisite_or_scope(self):
        guard = '        if: ${{ ' + ' && '.join(self.MALL_GATES) + ' }}\n'
        self.assert_mall_guard(guard)
        with self.assertRaises(AssertionError):
            self.assert_mall_guard(guard.replace("new_tests || '[]'", 'new_tests'))
        for omitted in self.MALL_GATES:
            with self.subTest(omitted=omitted), self.assertRaises(AssertionError):
                self.assert_mall_guard('        if: ${{ ' + ' && '.join(g for g in self.MALL_GATES if g != omitted) + ' }}\n')
        with self.assertRaises(AssertionError):
            self.assert_mall_guard(guard + '        continue-on-error: true\n')

    ADMISSION_STEP = 'Verify persistence admission adapter and ordinary restore compatibility'
    ADMISSION_GATES = (
        '!cancelled()', "needs.changes.result == 'success'",
        "steps.compile.outcome == 'success'",
        "(needs.changes.outputs.extensive == 'true' || contains(fromJSON(needs.changes.outputs.new_tests || '[]'), 'tests/persistence_admission'))",
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

    def test_changelog_validation_runs_on_pr_description_edits_without_a_second_selector(self):
        workflow = (ROOT / '.github/workflows/changelog-checks.yml').read_text(encoding='utf-8')
        selection = (ROOT / '.github/workflows/ci-selection.yml').read_text(encoding='utf-8')
        self.assertIn('types: [opened, synchronize, reopened, edited]', workflow)
        self.assertIn('      - name: Validate the PR description\n'
                      "        if: github.event_name == 'pull_request'\n"
                      '        run: node tools/changelog/check-pr.mjs\n', workflow)
        self.assertIn('node --test tools/changelog/*.test.mjs', workflow)
        self.assertIn('node tools/changelog/publish.mjs --validate', workflow)
        self.assertNotIn('./.github/workflows/ci-selection.yml', workflow)
        self.assertNotIn('needs: changes', workflow)
        self.assertIn("      - name: Validate changelog workflow syntax for standalone manual runs\n"
                      "        if: github.event_name == 'workflow_dispatch'\n", workflow)
        # The ordinary CI selector continues to lint all workflow files.
        ci = (ROOT / '.github/workflows/test.yml').read_text(encoding='utf-8')
        self.assertIn('      lint_workflows: true\n', ci)
        self.assertIn('actionlint" -shellcheck=', selection)
        self.assertIn('.github/workflows/*.yml', selection)

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

    def test_reviewed_atlas_test_edits_select_only_their_suite_on_ordinary_prs(self):
        # Exercise the actual Git comparison and admission, not a copied selector.
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def git(*args):
                return subprocess.check_output(['git', '-C', directory, *args],
                                               stderr=subprocess.PIPE).decode().strip()
            git('init')
            git('config', 'user.name', 'CI policy test')
            git('config', 'user.email', 'ci@example.invalid')
            atlas_inputs = {'tests/test_crafting_atlas.py': 'tests/test_crafting_atlas.py',
                            'tests/crafting_atlas/probe.dm': 'tests/crafting_atlas',
                            'tests/crafting_atlas/resource-search.test.mjs': 'tests/crafting_atlas'}
            paths = tuple(atlas_inputs) + ('tests/crafting_atlas/unrelated.dm',)
            for name in paths:
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text('original\n')
            git('add', '.')
            git('commit', '-m', 'base')
            base = git('rev-parse', 'HEAD')
            previous = os.getcwd()
            try:
                os.chdir(root)
                for name in paths:
                    with self.subTest(path=name):
                        (root / name).write_text('changed\n')
                        git('add', name)
                        git('commit', '-m', 'edit test')
                        head = git('rev-parse', 'HEAD')
                        expected = [atlas_inputs[name]] if name in atlas_inputs else []
                        payload = {'action': 'opened', 'pull_request': {'title': 'test', 'base': {'ref': 'master'}}}
                        self.assertEqual(selection.selections(base, head, 'pull_request', False, True, payload)[2], expected)
                        for action, branch in (('edited', 'master'), ('opened', 'other')):
                            payload = {'action': action, 'pull_request': {'title': 'test', 'base': {'ref': branch}}}
                            self.assertEqual(selection.selections(base, head, 'pull_request', False, True, payload)[2], [])
                        self.assertEqual(selection.selections(base, head, 'push', False, True,
                            {'ref': 'refs/heads/master', 'commits': [{'message': 'test'}]})[2], [])
                        base = head
            finally:
                os.chdir(previous)
        workflow = (ROOT / '.github/workflows/test.yml').read_text(encoding='utf-8')
        for suite in ('tests/crafting_atlas', 'tests/test_crafting_atlas.py'):
            self.assertIn("contains(fromJSON(needs.changes.outputs.new_tests || '[]'), '" + suite + "')", workflow)

    def test_atlas_comparison_failure_stops_the_actual_selector_before_output(self):
        payload = {'action': 'opened', 'pull_request': {'title': 'test', 'base': {'ref': 'master'}}}
        faults = (
            ('timeout', subprocess.TimeoutExpired('git', 15)),
            ('git failure', subprocess.CalledProcessError(1, 'git')),
            ('invalid UTF-8', b'\xff'),
        )
        for label, fault in faults:
            with self.subTest(fault=label), tempfile.TemporaryDirectory() as directory:
                output = Path(directory) / 'output.txt'
                receipt = Path(directory) / 'receipt.json'
                argv = ['select-ci.py', '--base', 'base', '--head', 'head',
                        '--event', 'pull_request', '--build-prefix', 'true',
                        '--output', str(output), '--receipt', str(receipt)]
                kwargs = {'return_value': fault} if isinstance(fault, bytes) else {'side_effect': fault}
                with patch.object(sys, 'argv', argv), patch.object(selection, 'load_event', return_value=payload), \
                        patch.object(selection, 'select', return_value=(True, 'selected')), \
                        patch.object(selection, 'introduced_tests', return_value=[]), \
                        patch.object(selection.subprocess, 'check_output', **kwargs):
                    with self.assertRaisesRegex(RuntimeError, 'Atlas test selection.*base and head'):
                        selection.main()
                self.assertFalse(output.exists())
                self.assertFalse(receipt.exists())
        with patch.object(selection, 'select', return_value=(True, 'selected')), \
                patch.object(selection, 'introduced_tests', return_value=[]):
            for base, head in (('', 'head'), ('0' * 40, 'head'), ('base', '')):
                with self.subTest(base=base, head=head):
                    with self.assertRaisesRegex(RuntimeError, 'Atlas test selection.*base and head'):
                        selection.selections(base, head, 'pull_request', False, True, payload)

    def test_atlas_comparison_does_not_expand_ineligible_event_admission(self):
        with patch.object(selection, 'select', return_value=(True, 'selected')), \
                patch.object(selection, 'introduced_tests', return_value=[]), \
                patch.object(selection.subprocess, 'check_output', side_effect=AssertionError('unexpected Atlas comparison')):
            for action, base in (('edited', 'master'), ('opened', 'unrelated')):
                payload = {'action': action, 'pull_request': {'title': 'test', 'base': {'ref': base}}}
                self.assertEqual(selection.selections('base', 'head', 'pull_request', False, True, payload)[2], [])
            payload = {'ref': 'refs/heads/master', 'commits': [{'message': 'test'}]}
            self.assertEqual(selection.selections('base', 'head', 'push', False, True, payload)[2], [])

    def test_offline_and_game_regressions_have_explicit_suite_guards(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text()
        self.assert_explicit_suite_guards(workflow)

    def assert_explicit_suite_guards(self, workflow):
        import re
        diagnostics = []
        admission_steps = 0
        mall_steps = 0
        for block in re.split(r'(?=      - name:)', workflow):
            name = re.search(r'^      - name: (.+)$', block, re.MULTILINE)
            if name and name.group(1) == self.MALL_STEP:
                mall_steps += 1
                self.assert_mall_guard(block)
                self.assertEqual(block.count('tests/extraction/run_mall.py'), 8)
                self.assertRegex(workflow, r'mall_regressions:\n        description: [^\n]+\n        type: boolean\n        default: false\n')
                continue
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
                    self.assertIn("        if: contains(fromJSON(needs.changes.outputs.new_tests || '[]'), 'tests/nomads_lifecycle')\n", block)
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
                self.assertRegex(block, r"if: (?:always\(\) && needs\.changes\.result == 'success' && (?:steps\.[a-z_]+\.outcome != 'skipped' && )?\()?needs\.changes\.outputs\.extensive == 'true' \|\| contains\(fromJSON\(needs\.changes\.outputs\.new_tests \|\| '\[\]'\)")
        self.assertEqual(sorted(diagnostics), sorted(self.VEHICLE_DIAGNOSTICS))
        self.assertEqual(admission_steps, 1)
        self.assertEqual(mall_steps, 1)
        self.assertIn("if: needs.changes.outputs.game == 'true'\n        timeout-minutes: 15\n", workflow)
        self.assertIn('bash ./scripts/travis_pre_byond.sh 2>&1 | tee .ci/compile/bootstrap.log', workflow)

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
                               ("contains(fromJSON(needs.changes.outputs.new_tests || '[]'), 'tests/roof_area_recovery')", 'introduced'),
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


class PlayerHelpLinkAdmissionTests(unittest.TestCase):
    def test_only_the_registered_work_animation_projection_is_exempt(self):
        offline = 'tests/test_resource_work_animation.py'
        self.assertEqual(selection.RESOURCE_WORK_OFFLINE_TESTS, frozenset({offline}))
        for added, expected in (([offline], []),
                                ([offline, 'tests/resource_work_animation/run.py'], ['tests/resource_work_animation']),
                                ([offline, 'tests/new_animation_test.py'], ['tests/new_animation_test.py'])):
            with self.subTest(added=added), patch.object(selection.subprocess, 'check_output',
                    return_value=('\0'.join(added) + '\0').encode()):
                self.assertEqual(selection.introduced_tests('base', 'head', 'pull_request'), expected)

    def test_only_the_registered_static_file_is_exempt(self):
        offline = 'tests/player_help/test_help_links.py'
        wiki_offline = 'tests/player_help/test_wiki_guides.py'
        self.assertEqual(selection.PLAYER_HELP_OFFLINE_TESTS, frozenset({offline, wiki_offline}))
        for added, expected in (([offline], []),
                                ([wiki_offline], []),
                                ([wiki_offline, 'tests/player_help/new_test.py'], ['tests/player_help']),
                                ([offline, 'tests/player_help/new_test.py'], ['tests/player_help']),
                                ([offline, 'tests/player_help/run_native.py'], ['tests/player_help']),
                                ([offline, 'tests/player_help/new_probe.dm'], ['tests/player_help']),
                                ([offline, 'tests/other/new_test.py'], ['tests/other'])):
            with self.subTest(added=added), patch.object(selection.subprocess, 'check_output',
                    return_value=('\0'.join(added) + '\0').encode()):
                self.assertEqual(selection.introduced_tests('base', 'head', 'pull_request'), expected)

    def test_actual_pr_selection_compiles_without_adding_native_suite(self):
        offline = 'tests/player_help/test_help_links.py'
        client = 'code/modules/client/client_verbs.dm'
        payload = {'action': 'synchronize', 'pull_request': {'title': 'help links', 'base': {'ref': 'master'}}}
        for changed, added, expected in (
                ([client, offline], [offline], []),
                ([client, offline, 'tests/player_help/new_test.py'],
                 [offline, 'tests/player_help/new_test.py'], ['tests/player_help'])):
            def diff(command, **kwargs):
                paths = added if '--diff-filter=A' in command else changed
                return ('\0'.join(paths) + '\0').encode()
            with self.subTest(changed=changed), patch.object(selection.subprocess, 'check_output', side_effect=diff):
                self.assertEqual(selection.selections('base', 'head', 'pull_request',
                                 False, True, payload)[:3], (True, False, expected))


class SourcePreparationAdmissionTests(unittest.TestCase):
    FILES = (
        'tests/world_save/character_return/fixture.dm',
        'tests/world_save/character_return/prepare.py',
        'tests/world_save/character_return/test_prepare.py',
    )

    def introduced(self, paths):
        with patch.object(selection.subprocess, 'check_output',
                          return_value=('\0'.join(paths) + '\0').encode()):
            return selection.introduced_tests('base', 'head', 'pull_request')

    def baseline(self):
        spec = importlib.util.spec_from_file_location('preparation_baseline', ROOT / 'scripts/ci_baseline.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_only_three_reviewed_preparation_files_are_exempt(self):
        for paths in ((path,) for path in self.FILES):
            with self.subTest(paths=paths):
                self.assertEqual(self.introduced(paths), [])
        self.assertEqual(self.introduced(self.FILES), [])
        self.assertEqual(selection.SOURCE_PREPARATION_ONLY_TESTS, frozenset(self.FILES))
        baseline = self.baseline()
        self.assertEqual(baseline.SUITES['character_return_preparation']['files'],
                         ('tests/world_save/character_return/test_prepare.py',
                          'tests/world_save/test_roundtrip_compat.py',
                          'tests/world_save/test_restart_sources.py'))
        for path in self.FILES:
            self.assertTrue(baseline.impact([path])['suites']['character_return_preparation']['selected'])

    def test_unlisted_files_even_inside_same_directory_retain_native_selection(self):
        for path in ('tests/world_save/new_probe.dm',
                     'tests/world_save/character_return/run_native.py',
                     'tests/world_save/character_return/run.ps1',
                     'tests/world_save/character_return/run.sh',
                     'tests/world_save/character_return/fixture.DM',
                     'tests/world_save/character_return/nested/prepare.py',
                     'tests/world_save/character_return_other/prepare.py'):
            with self.subTest(path=path):
                self.assertEqual(self.introduced([path]), ['tests/world_save'])
                self.assertEqual(self.introduced([*self.FILES, path]), ['tests/world_save'])

    def test_mixed_production_and_unlisted_world_save_additions_keep_native_selection(self):
        payload = {'action': 'synchronize', 'pull_request': {'title': 'save source', 'base': {'ref': 'master'}}}
        for production in ('code/modules/persistence/loading.dm',
                           'code/modules/persistence/saving.dm',
                           'code/modules/persistence/player_reclaim.dm'):
            paths = [*self.FILES, production, 'tests/world_save/new_probe.dm']
            with self.subTest(production=production), patch.object(selection.subprocess,
                    'check_output', return_value=('\0'.join(paths) + '\0').encode()):
                self.assertEqual(selection.selections('base', 'head', 'pull_request',
                                 False, True, payload)[:3], (True, False, ['tests/world_save']))

    def test_production_compile_and_offline_coverage_are_not_exempted(self):
        baseline = self.baseline()
        payload = {'action': 'synchronize', 'pull_request': {'title': 'save source', 'base': {'ref': 'master'}}}
        for production in ('code/modules/persistence/loading.dm',
                           'code/modules/persistence/saving.dm',
                           'code/modules/persistence/bed_return.dm'):
            for added in ([], list(self.FILES)):
                paths = [production, *added]
                with self.subTest(production=production, added=added), patch.object(
                        selection.subprocess, 'check_output',
                        return_value=('\0'.join(paths) + '\0').encode()):
                    # Existing production-only policy compiles, but does not
                    # invent introduced native tests without a new runnable file.
                    self.assertEqual(selection.selections('base', 'head', 'pull_request',
                                     False, True, payload)[:3], (True, False, []))
                self.assertTrue(baseline.impact(paths)['suites']['year']['selected'])
                self.assertTrue(baseline.impact(paths)['suites']['character_return_preparation']['selected'])
        for path in ('scripts/select-ci.py', 'code/predefines.dm',
                     'code/game/mob/living/simple_animal/friendly/static.dm'):
            decision = baseline.impact([path])
            self.assertTrue(decision['fallback_reasons'])
            self.assertTrue(all(row['selected'] for row in decision['suites'].values()))

    def test_explicit_extensive_manual_admission_is_unchanged(self):
        with patch.object(selection.subprocess, 'check_output',
                          return_value=b'code/modules/persistence/loading.dm\0'):
            self.assertEqual(selection.selections('base', 'head', 'workflow_dispatch',
                             True, True, {})[:3], (True, True, []))
            self.assertEqual(selection.selections('base', 'head', 'workflow_dispatch',
                             False, True, {})[:3], (True, False, []))

    def test_real_git_preparation_additions_then_mixed_native_and_production(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def git(*args):
                return subprocess.check_output(['git', '-c', 'user.name=CI preparation test',
                    '-c', 'user.email=ci@example.invalid', '-c', 'commit.gpgsign=false', *args],
                    cwd=root, stderr=subprocess.PIPE, timeout=10).decode().strip()
            git('init', '-q')
            production = root / 'code/modules/persistence/loading.dm'
            production.parent.mkdir(parents=True)
            production.write_text('// original loading fixture\n')
            git('add', '.')
            git('commit', '-qm', 'base')
            base = git('rev-parse', 'HEAD')
            for path in self.FILES:
                file = root / path
                file.parent.mkdir(parents=True, exist_ok=True)
                file.write_text('# source preparation only\n')
            git('add', '.')
            git('commit', '-qm', 'prepare only')
            prepared = git('rev-parse', 'HEAD')
            previous = os.getcwd()
            try:
                os.chdir(root)
                self.assertEqual(selection.introduced_tests(base, prepared, 'pull_request'), [])
                self.assertTrue(selection.select(base, prepared)[0])
                (root / 'tests/world_save/new_probe.dm').write_text('// runnable fixture\n')
                production.write_text('// changed loading fixture\n')
                git('add', '.')
                git('commit', '-qm', 'native fixture and production')
                mixed = git('rev-parse', 'HEAD')
                self.assertEqual(selection.introduced_tests(base, mixed, 'pull_request'), ['tests/world_save'])
                self.assertEqual(selection.introduced_tests(prepared, mixed, 'pull_request'), ['tests/world_save'])
                self.assertTrue(selection.select(prepared, mixed)[0])
            finally:
                os.chdir(previous)


if __name__ == '__main__':
    unittest.main()
