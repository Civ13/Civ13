"""Build requests change compilation selection, never native suite admission."""
import importlib.util
import ast
import json
import os
import re
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
    return {'action': action, 'pull_request': {'title': title, 'base': {'ref': base}}}


def workflow_contexts(selection_result, gating, *, event='pull_request', action='opened', title='feature', old_base=''):
    """Evaluate the actual two job-name expressions using a closed vocabulary."""
    workflow = (ROOT / '.github/workflows/test.yml').read_text()
    names = []
    for job in ('build', 'ci-required'):
        expression = workflow.split('\n  ' + job + ':\n', 1)[1].splitlines()[0]
        assert expression.startswith('    name: ${{ ') and expression.endswith(' }}')
        expression = expression[len('    name: ${{ '):-len(' }}')]
        for before, after in (("!startsWith(github.event.pull_request.title, 'build:')", 'not requested'),
                              ('github.event.pull_request.title', 'title'),
                              ('github.event.changes.base.ref.from', 'old_base'),
                              ('github.event_name', 'event'), ('github.event.action', 'action'),
                              ('needs.changes.result', 'selection_result'),
                              ('needs.changes.outputs.gating', 'gating'), ('&&', ' and '), ('||', ' or ')):
            expression = expression.replace(before, after)
        tree = ast.parse(expression, mode='eval')
        for node in ast.walk(tree):
            if not isinstance(node, (ast.Expression, ast.BoolOp, ast.And, ast.Or, ast.Compare,
                                     ast.Eq, ast.Name, ast.Load, ast.Constant, ast.UnaryOp, ast.Not)):
                raise AssertionError('Unexpected check-name expression syntax')
            if isinstance(node, ast.Name) and node.id not in {'selection_result', 'gating', 'event', 'action', 'title', 'old_base', 'requested'}:
                raise AssertionError('Check identity must not depend on compiler success or native omission')
        names.append(eval(compile(tree, '<workflow check identity>', 'eval'),
                          {'__builtins__': {}}, dict(selection_result=selection_result, gating=gating,
                          event=event, action=action, title=title, old_base=old_base,
                          requested=title.lower().startswith('build:'))))
    return tuple(names)


class BuildPrefixTests(unittest.TestCase):
    def test_edited_trigger_and_irrelevant_push_keep_check_identities(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text(encoding='utf-8')
        selector = (ROOT / '.github/workflows/ci-selection.yml').read_text(encoding='utf-8')
        changes = workflow.split('\n  changes:\n', 1)[1].split('\n  baseline:\n', 1)[0]
        self.assertIn("if: github.event_name != 'pull_request' || github.event.action != 'edited' || !github.event.pull_request.title || startsWith(github.event.pull_request.title, 'build:') || github.event.changes.base.ref.from != ''", changes)
        self.assertIn('lint_workflows: true', changes)
        expression = next(line.strip()[4:] for line in changes.splitlines() if line.startswith('    if: '))
        for before, after in (("startsWith(github.event.pull_request.title, 'build:')", 'requested'),
                              ('!github.event.pull_request.title', 'not title'),
                              ('github.event.changes.base.ref.from', 'old_base'),
                              ('github.event_name', 'event'), ('github.event.action', 'action'),
                              ('&&', ' and '), ('||', ' or ')):
            expression = expression.replace(before, after)
        parsed = ast.parse(expression, mode='eval')
        for node in ast.walk(parsed):
            self.assertIsInstance(node, (ast.Expression, ast.BoolOp, ast.And, ast.Or,
                                         ast.Compare, ast.Eq, ast.NotEq, ast.Name,
                                         ast.Load, ast.Constant, ast.UnaryOp, ast.Not))
            if isinstance(node, ast.Name):
                self.assertIn(node.id, ('event', 'action', 'title', 'requested', 'old_base'))
        for event, action, title, old_base, expected in (
                ('pull_request', 'opened', 'feature', '', True),
                ('pull_request', 'synchronize', 'feature', '', True),
                ('pull_request', 'edited', 'feature', '', False),
                ('pull_request', 'edited', 'build: feature', '', True),
                ('pull_request', 'edited', 'Build: feature', '', True),
                ('pull_request', 'edited', '', '', True),
                ('pull_request', 'edited', 'feature', 'master', True),
                ('push', '', '', '', True), ('workflow_dispatch', '', '', '', True)):
            with self.subTest(event=event, action=action, title=title, old_base=old_base):
                actual = eval(compile(parsed, '<selector admission>', 'eval'), {'__builtins__': {}},
                              dict(event=event, action=action, title=title,
                                   requested=title.lower().startswith('build:'), old_base=old_base))
                self.assertEqual(actual, expected)
        self.assertIn("if: inputs.lint_workflows && (steps.select.outputs.gating == '1' || steps.select.outputs.game == 'true' || github.event_name == 'workflow_dispatch')", selector)
        self.assertEqual(workflow_contexts('skipped', '', action='edited'),
                         ('CI informational build', 'CI informational aggregate'))
        self.assertEqual(workflow_contexts('skipped', '', action='edited', title='build: requested'),
                         ('build', 'CI required aggregate'))
        self.assertEqual(workflow_contexts('failure', ''), ('build', 'CI required aggregate'))
        self.assertEqual(workflow_contexts('success', '1'), ('build', 'CI required aggregate'))
        for name in ('baseline', 'evidence-checker'):
            block = re.split(r'\n  [\w-]+:\n', workflow.split('\n  ' + name + ':\n', 1)[1], 1)[0]
            self.assertIn("if: needs.changes.outputs.gating == '1' || needs.changes.outputs.game == 'true' || github.event_name == 'workflow_dispatch'", block)
        # Both jobs must still fail on a failed selector, run on ordinary PRs,
        # explicit build requests and manual dispatch, and skip unforced pushes.
        for name in ('build', 'ci-required'):
            block = workflow.split('\n  ' + name + ':\n', 1)[1]
            self.assertIn("(needs.changes.result != 'success' || needs.changes.outputs.gating == '1' || needs.changes.outputs.game == 'true' || github.event_name == 'workflow_dispatch')", block)
            expression = next(line.strip()[4:] for line in block.splitlines() if line.startswith('    if: '))
            for before, after in (("startsWith(github.event.pull_request.title, 'build:')", 'requested'),
                                  ('!github.event.pull_request.title', 'not title'),
                                  ('github.event.changes.base.ref.from', 'old_base'),
                                  ('github.event.action', 'action'), ('always()', 'True'), ('!cancelled()', 'True'),
                                  ('needs.changes.result', 'result'),
                                  ('needs.changes.outputs.gating', 'gating'),
                                  ('needs.changes.outputs.game', 'game'),
                                  ('github.event_name', 'event'), ('&&', ' and '), ('||', ' or ')):
                expression = expression.replace(before, after)
            parsed = ast.parse(expression, mode='eval')
            for node in ast.walk(parsed):
                self.assertIsInstance(node, (ast.Expression, ast.BoolOp, ast.And, ast.Or,
                                             ast.Compare, ast.Eq, ast.NotEq, ast.Name,
                                             ast.Load, ast.Constant, ast.UnaryOp, ast.Not))
                if isinstance(node, ast.Name):
                    self.assertIn(node.id, ('result', 'gating', 'game', 'event', 'action', 'title', 'requested', 'old_base'))
            for result, gating, game, event, action, title, old_base, expected in (
                    ('skipped', '', '', 'pull_request', 'edited', 'feature', '', False),
                    ('skipped', '', '', 'pull_request', 'opened', 'feature', '', True),
                    ('skipped', '', '', 'pull_request', 'edited', 'build: docs', '', True),
                    ('skipped', '', '', 'pull_request', 'edited', 'feature', 'master', True),
                    ('failure', '', '', 'pull_request', 'opened', 'feature', '', True),
                    ('success', '1', 'false', 'pull_request', 'opened', 'feature', '', True),
                    ('success', '0', 'true', 'push', '', '', '', True),
                    ('success', '0', 'false', 'push', '', '', '', False),
                    ('success', '0', 'false', 'workflow_dispatch', '', '', '', True)):
                with self.subTest(job=name, result=result, gating=gating, game=game, event=event, action=action):
                    actual = eval(compile(parsed, '<job admission>', 'eval'), {'__builtins__': {}},
                                  dict(result=result, gating=gating, game=game, event=event, action=action,
                                       title=title, requested=title.lower().startswith('build:'), old_base=old_base))
                    self.assertEqual(actual, expected)

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
        # Removing build: cannot turn a supported code diff into a compiler skip.
        for base, expected in (('master', True), ('feature-base', False)):
            self.assertEqual(self.choose('pull_request', pr('docs: x', base, 'edited'), b'world.dm\0'),
                             (expected, False, []))

    def test_edited_code_docs_and_forcing_stay_informational_without_native_admission(self):
        for base in ('master', 'help-markdown-byond-html'):
            for title, paths, compile_needed in (
                    ('docs: edited body', b'world.dm\0', True),
                    ('docs: edited body', b'README.md\0', False),
                    ('build: docs', b'README.md\0', True)):
                payload = pr(title, base, 'edited')
                with self.subTest(base=base, title=title, paths=paths), patch.object(
                        selection, 'introduced_tests', side_effect=AssertionError('native expansion')):
                    self.assertEqual(self.choose('pull_request', payload, paths), (compile_needed, False, []))
                policy = selection.eligibility('pull_request', payload, True)
                self.assertTrue(policy['compile']['eligible'])
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
        payload = pr('source', 'master', 'edited')
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
                    f'new_tests=[]\ngame={str(expected).lower()}\nextensive=false\ngating=0\n')
                self.assertFalse((root / 'INJECTED').exists())
            event_path.write_text('{invalid', encoding='utf-8')
            self.assertEqual(selection.load_event(event_path), {})
            self.assertEqual(selection.load_event(root / 'missing'), {})

    def test_cli_missing_scope_metadata_fails_before_outputs(self):
        head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
        for event, payload in (('pull_request', {}),
                ('pull_request', {'action': 'edited', 'pull_request': {'title': 'source'}}),
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
            for paths, compile_needed in ((('world.dm', 'tests/new_suite/probe.dm'), True),
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
                    self.assertTrue(saved['eligibility']['compile']['eligible'])
                    self.assertFalse(saved['eligibility']['native']['eligible'])
                    self.assertFalse(saved['eligibility']['gating']['eligible'])
                    self.assertFalse(saved['extensive'])
                    self.assertEqual(saved['new_tests'], [])
                    self.assertTrue(all(saved['eligibility'][key]['reason'] for key in ('compile', 'native', 'gating')))
                    self.assertEqual(output.read_text(encoding='utf-8'),
                        f'new_tests=[]\ngame={str(compile_needed).lower()}\nextensive=false\ngating=0\n')
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
