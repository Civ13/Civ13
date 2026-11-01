"""Build requests change compilation selection, never native suite admission."""
import importlib.util
import ast
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('selection', ROOT / 'scripts/select-ci.py')
selection = importlib.util.module_from_spec(spec)
spec.loader.exec_module(selection)


def push(*messages, ref='refs/heads/feature'):
    return {'ref': ref, 'deleted': False,
            'commits': [{'message': message} for message in messages]}


def pr(title, base='feature-base', action='opened'):
    payload = {'action': action, 'pull_request': {'title': title, 'body': 'new description',
               'head': {'sha': '1' * 40}, 'base': {'ref': base, 'sha': '2' * 40}}}
    if action == 'edited':
        payload['changes'] = {'body': {'from': 'old description'}}
    return payload


def workflow_contexts(selection_result, gating):
    """Evaluate the actual two job-name expressions using a closed vocabulary."""
    workflow = (ROOT / '.github/workflows/test.yml').read_text()
    names = []
    for job in ('build', 'ci-required'):
        expression = workflow.split('\n  ' + job + ':\n', 1)[1].splitlines()[0]
        assert expression.startswith('    name: ${{ ') and expression.endswith(' }}')
        expression = expression[len('    name: ${{ '):-len(' }}')]
        expression = expression.replace('needs.changes.result', 'selection_result').replace(
            'needs.changes.outputs.gating', 'gating').replace('&&', ' and ').replace('||', ' or ')
        tree = ast.parse(expression, mode='eval')
        for node in ast.walk(tree):
            if not isinstance(node, (ast.Expression, ast.BoolOp, ast.And, ast.Or, ast.Compare,
                                     ast.Eq, ast.Name, ast.Load, ast.Constant)):
                raise AssertionError('Unexpected check-name expression syntax')
            if isinstance(node, ast.Name) and node.id not in {'selection_result', 'gating'}:
                raise AssertionError('Check identity must not depend on compiler success or native omission')
        names.append(eval(compile(tree, '<workflow check identity>', 'eval'),
                          {'__builtins__': {}}, dict(selection_result=selection_result, gating=gating)))
    return tuple(names)


class BuildPrefixTests(unittest.TestCase):
    def test_ready_for_review_is_held_outside_subscription_and_native_admission(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text()
        subscription = workflow.split('\n  pull_request:\n', 1)[1].split('\n  #', 1)[0]
        self.assertIn('types: [ opened, synchronize, reopened, edited ]', subscription)
        self.assertNotIn('ready_for_review', subscription)
        for title, expected in (('ordinary', False), ('build: compile', True)):
            payload = pr(title, 'master', 'ready_for_review')
            policy = selection.eligibility('pull_request', payload, True)
            self.assertEqual(policy['compile']['eligible'], expected)
            self.assertFalse(policy['native']['eligible'])
            self.assertFalse(policy['gating']['eligible'])
            with patch.object(selection, 'select', return_value=(True, 'offline diff')), \
                    patch.object(selection, 'introduced_tests', side_effect=AssertionError('Native expansion forbidden')), \
                    patch.object(selection, 'changed_atlas_tests', side_effect=AssertionError('Atlas expansion forbidden')):
                self.assertEqual(selection.selections('base', 'head', 'pull_request', True, True, payload)[:3],
                                 (expected, False, []))

    def test_ordinary_ready_for_review_proposal_would_expand_native_selection(self):
        # Demonstrate why changing the event and action set needs separate review.
        payload = pr('source', 'master', 'ready_for_review')
        with patch.object(selection, 'ORDINARY_PR_ACTIONS', selection.ORDINARY_PR_ACTIONS | {'ready_for_review'}), \
                patch.object(selection, 'select', return_value=(True, 'offline diff')), \
                patch.object(selection, 'introduced_tests', return_value=['tests/world_save']) as introduced, \
                patch.object(selection, 'changed_atlas_tests', return_value=[]):
            policy = selection.eligibility('pull_request', payload, True)
            self.assertTrue(policy['native']['eligible'])
            self.assertTrue(policy['gating']['eligible'])
            self.assertEqual(selection.selections('base', 'head', 'pull_request', False, True, payload)[:3],
                             (True, False, ['tests/world_save']))
            introduced.assert_called_once()

    def test_only_valid_text_edits_skip_and_retargets_fail_closed(self):
        for field, old in (('title', 'old title'), ('body', None)):
            payload = pr('ordinary', 'master', 'edited')
            payload['changes'] = {field: {'from': old}}
            policy = selection.eligibility('pull_request', payload, True)
            self.assertTrue(policy['metadata_valid'])
            self.assertTrue(policy['skip_duplicate'])
            self.assertFalse(policy['gating']['eligible'])
        payload = pr('ordinary', 'master', 'edited')
        payload['changes'] = {'base': {'ref': {'from': 'previous-base'}}}
        policy = selection.eligibility('pull_request', payload, True)
        self.assertFalse(policy['metadata_valid'])
        self.assertFalse(policy['skip_duplicate'])
        self.assertFalse(policy['native']['eligible'])
        payload['pull_request']['base']['ref'] = 'unsupported'
        self.assertFalse(selection.eligibility('pull_request', payload, True)['metadata_valid'])

    def test_edited_unknown_metadata_never_skips_or_emits_selector_outputs(self):
        bad = (None, {}, {'unknown': {'from': 'x'}}, {'body': {}},
               {'title': {'from': None}}, {'base': {}}, {'base': {'ref': {'from': ''}}})
        for changes in bad:
            payload = pr('ordinary', 'master', 'edited')
            if changes is None:
                payload.pop('changes')
            else:
                payload['changes'] = changes
            with self.subTest(changes=changes):
                policy = selection.eligibility('pull_request', payload, True)
                self.assertFalse(policy['metadata_valid'])
                self.assertFalse(policy['skip_duplicate'])
        for field in ('body', 'head'):
            payload = pr('ordinary', 'master', 'edited')
            payload['pull_request'].pop(field)
            with self.subTest(missing_field=field):
                self.assertFalse(selection.eligibility('pull_request', payload, True)['metadata_valid'])
        self.assertEqual(workflow_contexts('failure', ''), ('build', 'CI required aggregate'))
        self.assertEqual(workflow_contexts('skipped', ''), ('build', 'CI required aggregate'))

    def test_job_and_lint_admission_uses_only_validated_selector_outputs(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text(encoding='utf-8')
        reusable = (ROOT / '.github/workflows/ci-selection.yml').read_text(encoding='utf-8')
        changes = workflow.split('\n  changes:\n', 1)[1].split('\n  baseline:\n', 1)[0]
        self.assertNotIn('    if:', changes)
        self.assertIn('      lint_workflows: true', changes)
        self.assertIn('skip_duplicate: ${{ steps.select.outputs.skip_duplicate }}', reusable)
        for name in ('build', 'ci-required'):
            block = workflow.split('\n  ' + name + ':\n', 1)[1]
            self.assertIn("needs.changes.result != 'success' || needs.changes.outputs.skip_duplicate != 'true'", block)
            expression = next(line.strip()[4:] for line in block.splitlines() if line.startswith('    if: '))
            for before, after in (('always()', 'True'), ('!cancelled()', 'True'),
                                  ('needs.changes.result', 'result'),
                                  ('needs.changes.outputs.skip_duplicate', 'duplicate'),
                                  ('needs.changes.outputs.gating', 'gating'),
                                  ('needs.changes.outputs.game', 'game'),
                                  ('github.event_name', 'event'), ('&&', ' and '), ('||', ' or ')):
                expression = expression.replace(before, after)
            parsed = ast.parse(expression, mode='eval')
            for node in ast.walk(parsed):
                self.assertIsInstance(node, (ast.Expression, ast.BoolOp, ast.And, ast.Or,
                                             ast.Compare, ast.Eq, ast.NotEq, ast.Name,
                                             ast.Load, ast.Constant))
                if isinstance(node, ast.Name):
                    self.assertIn(node.id, ('result', 'duplicate', 'gating', 'game', 'event'))
            for result, duplicate, gating, game, event, expected in (
                    ('failure', '', '', '', 'pull_request', True),
                    ('skipped', '', '', '', 'pull_request', True),
                    ('success', 'true', '0', 'false', 'pull_request', False),
                    ('success', 'false', '1', 'false', 'pull_request', True),
                    ('success', 'false', '0', 'true', 'push', True),
                    ('success', 'false', '0', 'false', 'push', False),
                    ('success', 'false', '0', 'false', 'workflow_dispatch', True)):
                with self.subTest(job=name, result=result, event=event):
                    actual = eval(compile(parsed, '<job admission>', 'eval'), {'__builtins__': {}},
                                  dict(result=result, duplicate=duplicate, gating=gating, game=game, event=event))
                    self.assertEqual(actual, expected)
        for name in ('baseline', 'evidence-checker'):
            block = workflow.split('\n  ' + name + ':\n', 1)[1]
            self.assertIn("needs.changes.outputs.skip_duplicate != 'true' &&", block)
        self.assertIn("if: inputs.lint_workflows && (steps.select.outputs.gating == '1' || steps.select.outputs.game == 'true' || github.event_name == 'workflow_dispatch')", reusable)

    def choose(self, event, payload, paths=b'README.md\0'):
        with patch.object(selection.subprocess, 'check_output', return_value=paths):
            return selection.selections('base', 'head', event, True, True, payload)[:3]

    def test_every_pushed_commit_first_line_and_branch(self):
        self.assertEqual(self.choose('push', push('build: first', 'docs: last')),
                         (True, False, []))
        self.assertEqual(self.choose('push', push('docs: first', 'build: last')),
                         (True, False, []))
        self.assertEqual(self.choose('push', push('build: docs', ref='refs/heads/master')),
                         (True, False, []))

    def test_literal_prefix_negatives(self):
        for message in ('Build: x', ' build: x', '\nbuild: x',
                        'docs: x\n\nbuild: body', 'rebuild: x', 'build x'):
            with self.subTest(message=message):
                self.assertEqual(self.choose('push', push(message)), (False, False, []))
                self.assertEqual(self.choose('pull_request', pr(message)), (False, False, []))

    def test_title_edit_and_nondefault_base(self):
        for action in ('opened', 'synchronize', 'reopened', 'edited'):
            self.assertEqual(self.choose('pull_request', pr('build: docs', action=action)),
                             (True, False, []))
        # A recognized title/body edit reuses the unchanged head's earlier check.
        for base, expected in (('master', False), ('feature-base', False)):
            self.assertEqual(self.choose('pull_request', pr('docs: x', base, 'edited'), b'world.dm\0'),
                             (expected, False, []))

    def test_edited_code_docs_and_forcing_stay_informational_without_native_admission(self):
        for base in ('master', 'help-markdown-byond-html'):
            for title, paths, compile_needed in (
                    ('docs: edited body', b'world.dm\0', False),
                    ('docs: edited body', b'README.md\0', False),
                    ('build: docs', b'README.md\0', True)):
                payload = pr(title, base, 'edited')
                with self.subTest(base=base, title=title, paths=paths), patch.object(
                        selection, 'introduced_tests', side_effect=AssertionError('native expansion')):
                    self.assertEqual(self.choose('pull_request', payload, paths), (compile_needed, False, []))
                policy = selection.eligibility('pull_request', payload, True)
                self.assertEqual(policy['compile']['eligible'], title.startswith('build:'))
                self.assertFalse(policy['native']['eligible'])
                self.assertFalse(policy['gating']['eligible'])
                self.assertEqual(workflow_contexts('success', '0'),
                                 ('CI informational build', 'CI informational aggregate'))

    def test_full_ordinary_scopes_retain_gating_names_and_admission(self):
        for base in ('master', 'help-markdown-byond-html'):
            for action in ('opened', 'synchronize', 'reopened'):
                policy = selection.eligibility('pull_request', pr('source', base, action), True)
                self.assertTrue(policy['native']['eligible'])
                self.assertTrue(policy['gating']['eligible'])
                self.assertEqual(workflow_contexts('success', '1'), ('build', 'CI required aggregate'))
        self.assertTrue(selection.eligibility('push', push('source', ref='refs/heads/master'), True)['gating']['eligible'])

    def test_incomplete_scopes_cannot_collide_even_when_compilation_is_forced(self):
        for event, payload in (('push', push('source')), ('push', push('build: source')),
                               ('pull_request', pr('build: source')),
                               ('workflow_dispatch', {})):
            with self.subTest(event=event, payload=payload):
                policy = selection.eligibility(event, payload, True)
                self.assertFalse(policy['gating']['eligible'])
                self.assertEqual(workflow_contexts('success', '0'),
                                 ('CI informational build', 'CI informational aggregate'))

    def test_later_edited_success_preserves_both_compiler_and_native_failure_contexts(self):
        for prior_failure in ('compiler acquisition', 'native fixture'):
            with self.subTest(prior_failure=prior_failure):
                history = dict(zip(workflow_contexts('success', '1'), ('failure', 'failure')))
                # An edited run may really compile successfully, but cannot
                # certify an earlier omitted native fixture or replace its name.
                history.update(zip(workflow_contexts('success', '0'), ('success', 'success')))
                self.assertEqual(history['build'], 'failure')
                self.assertEqual(history['CI required aggregate'], 'failure')

    def test_selector_failure_missing_or_invalid_output_retains_failing_gating_names(self):
        for result, gating in (('failure', '0'), ('cancelled', '0'),
                               ('skipped', ''), ('success', ''), ('success', 'invalid'),
                               ('success', 'false'), ('success', 'False'), ('success', '00'),
                               ('success', None), ('success', False), ('success', 0)):
            self.assertEqual(workflow_contexts(result, gating), ('build', 'CI required aggregate'))
        workflow = (ROOT / '.github/workflows/test.yml').read_text()
        self.assertEqual(workflow.count('needs.changes.outputs.gating &&'), 2)
        self.assertIn('case "$GATING_SELECTION" in 0|1) ;; *) exit 1 ;; esac', workflow)

    def test_missing_comparison_compiles_conservatively_without_edited_native_admission(self):
        payload = pr('build: source', 'master', 'edited')
        for base in ('', '0' * 40, 'missing-base'):
            with self.subTest(base=base), patch.object(selection.subprocess, 'check_output',
                    side_effect=subprocess.CalledProcessError(1, 'git')), patch.object(
                    selection, 'introduced_tests', side_effect=AssertionError('native expansion')):
                self.assertEqual(selection.selections(base, 'head', 'pull_request', True, True, payload)[:3],
                                 (True, False, []))

    def test_ordinary_subscription_behavior_is_retained(self):
        self.assertEqual(self.choose('push', push('docs', ref='refs/heads/master')),
                         (False, False, []))
        self.assertEqual(self.choose('push', push('source', ref='refs/heads/master'), b'world.dm\0'),
                         (True, False, []))
        for base in ('master', 'help-markdown-byond-html'):
            self.assertEqual(self.choose('pull_request', pr('source', base), b'world.dm\0'),
                             (True, False, []))
            self.assertEqual(self.choose('pull_request', pr('docs', base)), (False, False, []))
        self.assertEqual(self.choose('workflow_dispatch', {}, b'world.dm\0'), (True, True, []))

    def test_forcing_outside_subscriptions_does_not_select_new_native_tests(self):
        for event, payload in (('push', push('build: x')),
                               ('pull_request', pr('build: x')),
                               ('pull_request', pr('build: x', 'master', 'edited'))):
            with patch.object(selection, 'introduced_tests', side_effect=AssertionError('native escalation')):
                self.assertEqual(self.choose(event, payload, b'tests/world_save/new.dm\0'),
                                 (True, False, []))
        with patch.object(selection, 'introduced_tests', return_value=['tests/new_suite']):
            self.assertEqual(self.choose('pull_request', pr('build: x', 'master')),
                             (True, False, ['tests/new_suite']))

    def test_incomplete_push_metadata_conservatively_compiles_only(self):
        for payload in ({}, {'commits': None}, push(), {'commits': [{}]},
                        dict(push('docs'), size=2),
                        {'commits': [{'message': 'docs'}] * 2048}):
            with self.subTest(payload_keys=list(payload)):
                self.assertEqual(self.choose('push', payload), (True, False, []))
        self.assertEqual(self.choose('pull_request', {}), (True, False, []))
        self.assertEqual(self.choose('push', dict(push('build: x'), deleted=True)),
                         (False, False, []))
        self.assertEqual(self.choose('pull_request_target', pr('build: x')), (False, False, []))

    def test_other_reusable_callers_keep_existing_selection(self):
        with patch.object(selection.subprocess, 'check_output', return_value=b'world.dm\0'):
            result = selection.selections('base', 'head', 'pull_request', False)
        self.assertEqual(result[:3], (True, False, []))

    def test_cli_reads_json_as_data_and_real_git_docs_diff(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def git(*args):
                return subprocess.check_output(['git', '-c', 'user.name=CI test',
                    '-c', 'user.email=ci@example.invalid', *args], cwd=root, stderr=subprocess.PIPE).decode().strip()
            git('init', '-q')
            (root / 'README.md').write_text('first\n', encoding='utf-8')
            git('add', '.')
            git('commit', '-qm', 'first')
            base = git('rev-parse', 'HEAD')
            (root / 'README.md').write_text('second\n', encoding='utf-8')
            git('commit', '-qam', 'docs: update')
            head = git('rev-parse', 'HEAD')
            event_path = root / 'event.json'
            output = root / 'output'
            env = dict(os.environ, GITHUB_EVENT_PATH=str(event_path))
            env.pop('GITHUB_STEP_SUMMARY', None)
            command = [sys.executable, str(ROOT / 'scripts/select-ci.py'), '--base', base,
                       '--head', head, '--output', str(output), '--event', 'push',
                       '--build-prefix', 'true', '--extensive', 'true']
            for messages, expected in ((('docs: only',), False),
                                       (('build: $(touch INJECTED); `echo bad`', 'docs: head'), True)):
                output.write_text('', encoding='utf-8')
                event_path.write_text(json.dumps(push(*messages)), encoding='utf-8')
                subprocess.run(command, cwd=root, env=env, check=True, capture_output=True)
                self.assertEqual(output.read_text(encoding='utf-8'),
                    f'new_tests=[]\ngame={str(expected).lower()}\nextensive=false\ngating=0\nskip_duplicate=false\n')
                self.assertFalse((root / 'INJECTED').exists())
            # A valid docs-only base must not suppress an explicit manual run
            # or its BYOND bootstrap, even for a single native opt-in.
            workflow = (ROOT / '.github/workflows/test.yml').read_text()
            build = workflow.split('\n  build:\n', 1)[1].split('\n  ci-required:\n', 1)[0]
            compile_step = build.split('      - name: Compile selected exact-head game\n', 1)[1].split('      - name:', 1)[0]
            rack_step = build.split('      - name: Verify paid rack', 1)[1].split('      - name:', 1)[0]
            self.assertIn("if: needs.changes.outputs.game == 'true'", compile_step)
            self.assertIn('github.event_name == \'workflow_dispatch\' && inputs.rack_save_regressions', rack_step)
            for extensive, rack in ((True, False), (False, True), (False, False)):
                with self.subTest(extensive=extensive, rack=rack):
                    event_path.write_text(json.dumps({'inputs': {'rack_save_regressions': rack}}), encoding='utf-8')
                    output.write_text('', encoding='utf-8')
                    manual = command.copy()
                    manual[manual.index('--event') + 1] = 'workflow_dispatch'
                    manual[manual.index('--extensive') + 1] = str(extensive).lower()
                    subprocess.run(manual, cwd=root, env=env, check=True, capture_output=True)
                    self.assertEqual(output.read_text(encoding='utf-8'),
                        f'new_tests=[]\ngame=true\nextensive={str(extensive).lower()}\ngating=0\nskip_duplicate=false\n')
            event_path.write_text('{invalid', encoding='utf-8')
            self.assertEqual(selection.load_event(event_path), {})
            self.assertEqual(selection.load_event(root / 'missing'), {})

    def test_cli_missing_scope_metadata_fails_before_outputs(self):
        head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
        for event, payload in (('pull_request', {}),
                ('pull_request', {'action': 'edited', 'pull_request': {'title': 'source'}}),
                ('pull_request', {'action': 'edited', 'pull_request': {'title': 'source', 'base': {'ref': 'master'}}}),
                ('pull_request', pr('source', 'master', 'edited')),
                ('pull_request', dict(pr('source', 'master', 'edited'), changes={'unknown': {'from': 'x'}})),
                ('pull_request', dict(pr('source', 'master', 'edited'), changes={'base': {'ref': {'from': 'feature-base'}}})),
                ('pull_request', dict(pr('source', 'feature-base', 'edited'), changes={'base': {'ref': {'from': 'master'}}})),
                ('pull_request', {'pull_request': {'title': 'source', 'base': {'ref': 'master'}}}),
                ('push', {'commits': [{'message': 'source'}]})):
            with self.subTest(event=event, payload=payload), tempfile.TemporaryDirectory() as directory:
                event_file = Path(directory) / 'event.json'
                output = Path(directory) / 'output'
                receipt = Path(directory) / 'selection.json'
                event_file.write_text(json.dumps(payload))
                env = dict(os.environ, GITHUB_EVENT_PATH=str(event_file))
                env.pop('GITHUB_STEP_SUMMARY', None)
                result = subprocess.run([sys.executable, '-B', str(ROOT / 'scripts/select-ci.py'),
                    '--base', head, '--head', head, '--event', event, '--build-prefix', 'true',
                    '--output', str(output), '--receipt', str(receipt)], cwd=ROOT,
                    env=env, capture_output=True, timeout=10)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(output.exists())
                saved = json.loads(receipt.read_text())
                self.assertEqual(saved['status'], 'failed')
                self.assertFalse(saved['eligibility']['metadata_valid'])

    def test_cli_receipt_records_action_and_independent_eligibility_reasons(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / 'repo'
            (root / 'scripts').mkdir(parents=True)
            # Receipt provenance is rooted at the scripts' location. Use their
            # unchanged bytes in a real test-only repository, never the caller's
            # latest commit, which may legitimately contain only documentation.
            for name in ('select-ci.py', 'ci_baseline.py', 'byond_toolchain.py'):
                (root / 'scripts' / name).write_bytes((ROOT / 'scripts' / name).read_bytes())
            def git(*args):
                return subprocess.check_output(['git', '-c', 'user.name=CI receipt fixture',
                    '-c', 'user.email=ci@example.invalid', '-c', 'commit.gpgsign=false', *args],
                    cwd=root, stderr=subprocess.PIPE, timeout=10, text=True).strip()
            git('init', '-q')
            (root / 'world.dm').write_text('// initial fixture source\n', encoding='utf-8')
            (root / 'README.md').write_text('Initial fixture documentation.\n', encoding='utf-8')
            git('add', '.')
            git('commit', '-qm', 'test fixture base')
            event_file = Path(directory) / 'event.json'
            output = Path(directory) / 'output'
            receipt = Path(directory) / 'selection.json'
            event_file.write_text(json.dumps(pr('ci: metadata edit', 'master', 'edited')), encoding='utf-8')
            env = dict(os.environ, GITHUB_EVENT_PATH=str(event_file))
            env.pop('GITHUB_STEP_SUMMARY', None)
            for paths, compile_needed in ((('world.dm', 'tests/new_suite/probe.dm'), False),
                                          (('README.md',), False)):
                with self.subTest(paths=paths):
                    base = git('rev-parse', 'HEAD')
                    for relative in paths:
                        path = root / relative
                        path.parent.mkdir(parents=True, exist_ok=True)
                        path.write_text('Updated fixture input.\n', encoding='utf-8')
                    git('add', '.')
                    git('commit', '-qm', 'test fixture change')
                    head = git('rev-parse', 'HEAD')
                    event = pr('ci: metadata edit', 'master', 'edited')
                    event['pull_request']['head']['sha'] = head
                    event['pull_request']['base']['sha'] = base
                    event_file.write_text(json.dumps(event), encoding='utf-8')
                    output.write_text('', encoding='utf-8')
                    subprocess.run([sys.executable, '-B', str(root / 'scripts/select-ci.py'),
                        '--base', base, '--head', head, '--event', 'pull_request', '--build-prefix', 'true',
                        '--extensive', 'true', '--output', str(output), '--receipt', str(receipt)], cwd=root,
                        env=env, capture_output=True, timeout=10, check=True)
                    saved = json.loads(receipt.read_text(encoding='utf-8'))
                    self.assertEqual(saved['status'], 'passed')
                    self.assertEqual(saved['head'], head)
                    self.assertEqual(saved['base'], base)
                    self.assertEqual(saved['requested_base'], base)
                    self.assertEqual(saved['comparison']['status'], 'available')
                    self.assertEqual(saved['comparison']['paths'], sorted(paths))
                    self.assertEqual(saved['action'], 'edited')
                    self.assertEqual(saved['eligibility']['base_ref'], 'master')
                    self.assertEqual(saved['compile']['selected'], compile_needed)
                    self.assertFalse(saved['eligibility']['compile']['eligible'])
                    self.assertFalse(saved['eligibility']['native']['eligible'])
                    self.assertFalse(saved['eligibility']['gating']['eligible'])
                    self.assertFalse(saved['extensive'])
                    self.assertEqual(saved['new_tests'], [])
                    self.assertTrue(all(saved['eligibility'][key]['reason'] for key in ('compile', 'native', 'gating')))
                    self.assertEqual(output.read_text(encoding='utf-8'),
                        f'new_tests=[]\ngame={str(compile_needed).lower()}\nextensive=false\ngating=0\nskip_duplicate=true\n')
                    self.assertEqual(workflow_contexts('success', '0'),
                                     ('CI informational build', 'CI informational aggregate'))

    def test_workflow_intake_and_single_existing_compiler(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text(encoding='utf-8')
        intake = workflow.split('  workflow_dispatch:', 1)[0]
        self.assertIn("branches: [ '**' ]", intake)
        self.assertIn('types: [ opened, synchronize, reopened, edited ]', intake)
        self.assertNotIn('branches:', intake.split('  pull_request:', 1)[1])
        self.assertNotIn('pull_request_target', workflow)
        self.assertIn('contents: read', workflow)
        self.assertIn('build_prefix: true', workflow)
        self.assertEqual(workflow.count('bash ./scripts/travis_pre_byond.sh'), 1)
        reusable = (ROOT / '.github/workflows/ci-selection.yml').read_text(encoding='utf-8')
        self.assertIn("--build-prefix \"$BUILD_PREFIX\"", reusable)
        self.assertNotIn('github.event.pull_request.title', reusable)
        self.assertNotIn('github.event.head_commit.message', reusable)


if __name__ == '__main__':
    unittest.main()
