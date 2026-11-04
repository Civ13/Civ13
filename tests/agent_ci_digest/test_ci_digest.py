"""Offline checks for scripts/ci_digest.py and its workflow. No network."""
import importlib.util
import json
from pathlib import Path
import re
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('ci_digest', ROOT / 'scripts/ci_digest.py')
digest = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(digest)
SHA = 'a' * 40


def log(*lines):
    return [f'2026-11-04T19:19:37.1234567Z {line}' for line in lines]


class ClassifyTests(unittest.TestCase):
    def kind(self, step, *lines, conclusion='failure'):
        return digest.classify(conclusion, step, digest.clean('\n'.join(log(*lines))))[0]

    def test_checkout_failure_is_infra(self):
        self.assertEqual(self.kind('Check out simple compilation source', 'fetching', '##[error]fatal: timeout'), 'infra')

    def test_network_patterns_are_infra(self):
        self.assertEqual(self.kind('Compile selected exact-head game',
                                   "fatal: unable to access 'https://github.com/x/': Could not resolve host",
                                   '##[error]Process completed with exit code 128.'), 'infra')
        self.assertEqual(self.kind('Fetch BYOND', 'curl: (22) The requested URL returned error: 503',
                                   '##[error]Process completed with exit code 22.'), 'infra')

    def test_compile_and_test_failures_are_real(self):
        self.assertEqual(self.kind('Compile', 'code/game/foo.dm:12:error: bar: undefined var',
                                   'civ13.dmb - 1 error, 0 warnings', '##[error]Process completed with exit code 1.'),
                         'real')
        self.assertEqual(self.kind('Run suites', 'FAILED (failures=1)', 'AssertionError: 1 != 2',
                                   '##[error]Process completed with exit code 1.'), 'real')

    def test_real_failure_wins_over_incidental_network_text(self):
        self.assertEqual(self.kind('Run suites', 'Connection reset by peer (expected by test)',
                                   'AssertionError: boom', '##[error]Process completed with exit code 1.'), 'real')

    def test_git_rpc_failure_is_not_mistaken_for_a_test_failure(self):
        self.assertEqual(self.kind('Compile', 'error: RPC failed; curl 92 HTTP/2 stream was not closed',
                                   '##[error]Process completed with exit code 128.'), 'infra')

    def test_follow_on_upload_error_does_not_mask_test_failure(self):
        # Shape of moving-save run 41882783236: unittest failure, then an
        # evidence upload that found no files.
        self.assertEqual(self.kind('Run correctness', 'Ran 236 tests in 1.376s', 'FAILED (failures=1)',
                                   '##[error]Process completed with exit code 1.',
                                   '##[error]No files were found with the provided path. No artifacts will be uploaded.'),
                         'real')

    def test_native_control_failure_is_real_and_step_echo_is_dropped(self):
        # Shape of moving-save run 41892453577.
        lines = digest.clean('\n'.join(log('CONTROL zone-fields: failed at its named assertion',
                                           '##[group]Run set -euo pipefail', '\x1b[36;1mset -euo pipefail\x1b[0m',
                                           'shell: /usr/bin/bash', '##[endgroup]',
                                           '##[error]Process completed with exit code 1.')))
        self.assertEqual(digest.classify('failure', 'Run native', lines)[0], 'real')
        self.assertEqual(digest.failure_window(lines), ['CONTROL zone-fields: failed at its named assertion',
                                                        '##[error]Process completed with exit code 1.'])

    def test_known_capture_budget(self):
        self.assertEqual(self.kind('Run native', 'Moving save chunk exceeded its capture budget',
                                   '##[error]Process completed with exit code 1.'), 'known')

    def test_timeout_cancel_and_unknown(self):
        self.assertEqual(self.kind('Run native', 'working', conclusion='timed_out'), 'timeout')
        self.assertEqual(self.kind('Run native', '##[error]The operation was canceled.', conclusion='cancelled'), 'infra')
        self.assertEqual(self.kind('Run native', 'something odd', '##[error]Process completed with exit code 2.'),
                         'unknown')


class RenderTests(unittest.TestCase):
    def failure(self, kind, attempt=1):
        return {'workflow': 'CI', 'job': 'build', 'run_id': 7, 'job_id': 8, 'attempt': attempt, 'step': 'Compile',
                'class': kind, 'reason': 'r', 'url': 'https://example.invalid/job', 'excerpt': ['a', 'b ``` c']}

    def test_verdicts(self):
        self.assertEqual(digest.verdict([], []), 'green')
        self.assertEqual(digest.verdict([self.failure('infra')], []), 'infra-only')
        self.assertEqual(digest.verdict([self.failure('infra'), self.failure('known')], []), 'known-only')
        self.assertEqual(digest.verdict([self.failure('unknown')], []), 'needs-fix')
        self.assertEqual(digest.verdict([], ['x']), 'pending')

    def test_render_has_marker_json_and_stable_signature(self):
        summary = {'success': 3, 'skipped': 1, 'failed': 1}
        body, state, sig = digest.render(SHA, summary, [self.failure('real')], [], [], '')
        self.assertTrue(body.startswith(f'<!-- agent-ci-digest sha={SHA} sig={sig} -->'))
        self.assertEqual(state, 'needs-fix')
        data = json.loads(re.search(r'<!-- agent-ci-digest-json (.*) -->', body).group(1))
        self.assertEqual(data['verdict'], 'needs-fix')
        self.assertEqual(data['failed'][0]['job_id'], 8)
        self.assertNotIn('b ``` c', body)
        self.assertEqual(digest.render(SHA, summary, [self.failure('real')], [], [], 'other-url')[2], sig)

    def test_failure_window_keeps_context_and_errors(self):
        lines = digest.clean('\n'.join(log('##[group]noise', 'context', '##[endgroup]', '##[error]boom', 'after')))
        self.assertEqual(digest.failure_window(lines), ['context', '##[error]boom'])


class FakeGitHub:
    """Two polls running, then one infra failure that passes after the rerun."""

    def __init__(self):
        self.repo, self.calls, self.polls, self.comments, self.reran = 'o/r', [], 0, [], False

    def check(self, status, conclusion, job_id=11):
        return {'name': 'build', 'status': status, 'conclusion': conclusion, 'app': {'slug': 'github-actions'},
                'details_url': f'https://github.com/o/r/actions/runs/5/job/{job_id}',
                'html_url': 'https://example.invalid/j'}

    def check_runs(self, sha):
        self.polls += 1
        other_app = dict(self.check('in_progress', None), app={'slug': 'coderabbitai'})
        if self.polls == 1:
            return [self.check('in_progress', None), other_app]
        return [self.check('completed', 'success' if self.reran else 'failure', 12 if self.reran else 11), other_app]

    def get(self, path):
        if path.startswith('pulls/'):
            return {'head': {'sha': SHA}}
        if path.startswith('actions/jobs/'):
            return {'run_attempt': 2 if self.reran else 1, 'steps': [{'name': 'Check out source', 'conclusion': 'failure'}]}
        if path.startswith('actions/runs/'):
            return {'name': 'CI'}
        if path.startswith('issues/'):
            return self.comments
        raise AssertionError(path)

    def job_log(self, job_id):
        return '2026-11-04T00:00:00Z ##[error]The operation timed out'

    def request(self, method, path, payload=None, raw=False):
        self.calls.append((method, path))
        if path.endswith('rerun-failed-jobs'):
            self.reran = True
        elif method == 'POST':
            self.comments.append({'id': 1, 'body': payload['body']})
        elif method == 'PATCH':
            self.comments[0]['body'] = payload['body']
        return {}


class MainFlowTests(unittest.TestCase):
    def run_main(self, fake, *extra):
        with mock.patch.object(digest, 'GitHub', return_value=fake), \
                mock.patch.object(digest.time, 'sleep'), \
                mock.patch.dict(digest.os.environ, {'GITHUB_REPOSITORY': 'o/r', 'GITHUB_TOKEN': 't',
                                                    'GITHUB_STEP_SUMMARY': '', 'GITHUB_RUN_ID': '99'}), \
                mock.patch('builtins.print'):
            return digest.main(['--sha', SHA, '--pr', '3', *extra])

    def test_waits_reruns_infra_once_then_posts_green(self):
        fake = FakeGitHub()
        self.assertEqual(self.run_main(fake), 0)
        self.assertIn(('POST', 'actions/runs/5/rerun-failed-jobs'), fake.calls)
        self.assertEqual(len(fake.comments), 1)
        self.assertIn('**green**', fake.comments[0]['body'])
        self.assertIn('rerun once automatically', fake.comments[0]['body'])

    def test_no_rerun_reports_infra_and_repeat_is_unchanged(self):
        fake = FakeGitHub()
        self.run_main(fake, '--no-rerun')
        self.run_main(fake, '--no-rerun')
        self.assertNotIn(('POST', 'actions/runs/5/rerun-failed-jobs'), fake.calls)
        self.assertEqual([c for c in fake.calls if c[0] in ('POST', 'PATCH')], [('POST', 'issues/3/comments')])
        self.assertIn('**infra-only**', fake.comments[0]['body'])

    def test_rejects_short_sha(self):
        with self.assertRaises(SystemExit), mock.patch('sys.stderr'):
            digest.main(['--sha', 'abc'])


class WorkflowContractTests(unittest.TestCase):
    text = (ROOT / '.github/workflows/agent-ci-digest.yml').read_text(encoding='utf-8')

    def test_never_checks_out_pull_request_code(self):
        self.assertIn('ref: ${{ github.event.repository.default_branch }}', self.text)
        self.assertIn('sparse-checkout: scripts/ci_digest.py', self.text)
        self.assertNotIn('head_sha }}\n          sparse', self.text)
        self.assertNotIn('pull_request_target', self.text)
        self.assertEqual(self.text.count('actions/checkout@'), 1)

    def test_follows_main_ci_and_documents_usage(self):
        self.assertIn('workflows: [CI]', self.text)
        self.assertTrue((ROOT / 'docs/agent-ci-digest.md').is_file())


if __name__ == '__main__':
    unittest.main()
