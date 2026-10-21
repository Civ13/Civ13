"""Build requests change compilation selection, never native suite admission."""
import importlib.util
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
    return {'action': action, 'pull_request': {'title': title, 'base': {'ref': base}}}


class BuildPrefixTests(unittest.TestCase):
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
        # A body edit or removal of build: does not compile even a source diff.
        for base in ('master', 'feature-base'):
            self.assertEqual(self.choose('pull_request', pr('docs: x', base, 'edited'), b'world.dm\0'),
                             (False, False, []))

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
                    f'new_tests=[]\ngame={str(expected).lower()}\nextensive=false\n')
                self.assertFalse((root / 'INJECTED').exists())
            event_path.write_text('{invalid', encoding='utf-8')
            self.assertEqual(selection.load_event(event_path), {})
            self.assertEqual(selection.load_event(root / 'missing'), {})

    def test_workflow_intake_and_single_existing_compiler(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text(encoding='utf-8')
        intake = workflow.split('  workflow_dispatch:', 1)[0]
        self.assertIn("branches: [ '**' ]", intake)
        self.assertIn('types: [ opened, synchronize, reopened, edited ]', intake)
        self.assertNotIn('branches:', intake.split('  pull_request:', 1)[1])
        self.assertNotIn('pull_request_target', workflow)
        self.assertIn('contents: read', workflow)
        self.assertIn('build_prefix: true', workflow)
        self.assertEqual(workflow.count('sudo bash ./scripts/travis_pre_byond.sh'), 1)
        reusable = (ROOT / '.github/workflows/ci-selection.yml').read_text(encoding='utf-8')
        self.assertIn("--build-prefix \"$BUILD_PREFIX\"", reusable)
        self.assertNotIn('github.event.pull_request.title', reusable)
        self.assertNotIn('github.event.head_commit.message', reusable)


if __name__ == '__main__':
    unittest.main()
