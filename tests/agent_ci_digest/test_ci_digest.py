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
        self.assertEqual(digest.verdict([self.failure('infra')], [], [7]), 'rerunning')

    def test_render_has_marker_json_and_stable_signature(self):
        summary = {'success': 3, 'skipped': 1, 'failed': 1}
        body, state, sig = digest.render(SHA, summary, [self.failure('real')], [], [], '')
        self.assertTrue(body.startswith(f'<!-- agent-ci-digest sha={SHA} sig={sig} verdict=needs-fix -->'))
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
    """A head whose single Actions job moves through the given states."""

    def __init__(self, conclusion='failure', step='Check out source', head=SHA):
        self.repo, self.calls, self.comments = 'o/r', [], []
        self.status, self.conclusion, self.step, self.head, self.attempt = 'in_progress', None, step, head, 1
        self.final = conclusion

    def finish(self, conclusion=None, attempt=1):
        self.status, self.conclusion, self.attempt = 'completed', conclusion or self.final, attempt

    def check(self):
        return {'name': 'build', 'status': self.status, 'conclusion': self.conclusion,
                'app': {'slug': 'github-actions'}, 'details_url': f'https://github.com/o/r/actions/runs/5/job/1{self.attempt}',
                'html_url': 'https://example.invalid/j'}

    def check_runs(self, sha):
        other_app = dict(self.check(), status='in_progress', app={'slug': 'coderabbitai'})
        return [self.check(), other_app]

    def get(self, path):
        if path.startswith('pulls/'):
            return {'head': {'sha': self.head}}
        if path.startswith('actions/jobs/'):
            return {'run_attempt': self.attempt, 'steps': [{'name': self.step, 'conclusion': 'failure'}]}
        if path.startswith('actions/runs/'):
            return {'name': 'CI'}
        if path.startswith('issues/'):
            return self.comments
        raise AssertionError(path)

    def job_log(self, job_id):
        return '2026-11-04T00:00:00Z ##[error]The operation timed out'

    def request(self, method, path, payload=None, raw=False):
        self.calls.append((method, path))
        if method == 'POST' and path.startswith('issues/'):
            self.comments.append({'id': len(self.comments) + 1, 'body': payload['body']})
        elif method == 'PATCH':
            self.comments[-1]['body'] = payload['body']
        return {}

    def writes(self):
        return [c for c in self.calls if c[0] in ('POST', 'PATCH')]


class MainFlowTests(unittest.TestCase):
    def run_main(self, fake, *extra):
        with mock.patch.object(digest, 'GitHub', return_value=fake), \
                mock.patch.object(digest.time, 'sleep'), \
                mock.patch.dict(digest.os.environ, {'GITHUB_REPOSITORY': 'o/r', 'GITHUB_TOKEN': 't',
                                                    'GITHUB_STEP_SUMMARY': '', 'GITHUB_RUN_ID': '99'}), \
                mock.patch('builtins.print') as printed:
            self.assertEqual(digest.main(['--sha', SHA, '--pr', '3', *extra]), 0)
            return ' '.join(str(c) for c in printed.call_args_list)

    def test_running_checks_exit_at_once_without_writing(self):
        fake = FakeGitHub()
        self.run_main(fake)
        self.assertEqual(fake.writes(), [])

    def test_infra_rerun_once_then_new_comment_for_final_verdict(self):
        fake = FakeGitHub()
        fake.finish()
        self.run_main(fake)
        self.assertEqual(fake.writes(), [('POST', 'actions/runs/5/rerun-failed-jobs'), ('POST', 'issues/3/comments')])
        self.assertIn('verdict=rerunning', fake.comments[0]['body'])
        fake.finish('success', attempt=2)
        self.run_main(fake)
        self.assertEqual(len(fake.comments), 2)
        self.assertIn('**green**', fake.comments[1]['body'])
        self.run_main(fake)
        self.assertEqual(len(fake.writes()), 3)

    def test_second_infra_failure_is_reported_not_rerun(self):
        fake = FakeGitHub()
        fake.finish(attempt=2)
        self.run_main(fake)
        self.assertNotIn(('POST', 'actions/runs/5/rerun-failed-jobs'), fake.calls)
        self.assertIn('**infra-only**', fake.comments[0]['body'])

    def test_real_failure_is_never_rerun(self):
        fake = FakeGitHub(step='Run suites')
        fake.job_log = lambda job_id: 'AssertionError: x\n##[error]Process completed with exit code 1.'
        fake.finish()
        self.run_main(fake)
        self.assertEqual(fake.writes(), [('POST', 'issues/3/comments')])
        self.assertIn('**needs-fix**', fake.comments[0]['body'])

    def test_moved_head_and_api_failure_post_nothing(self):
        fake = FakeGitHub(head='b' * 40)
        fake.finish()
        self.run_main(fake)
        self.assertEqual(fake.writes(), [])
        broken = FakeGitHub()
        broken.check_runs = mock.Mock(side_effect=digest.urllib.error.HTTPError('u', 403, 'rate limit', {}, None))
        self.assertIn('verdict=unavailable', self.run_main(broken))
        self.assertEqual(broken.writes(), [])

    def test_manual_report_pending(self):
        fake = FakeGitHub()
        self.run_main(fake, '--report-pending')
        self.assertIn('**pending**', fake.comments[0]['body'])

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

    def test_triggers_on_every_pull_request_workflow(self):
        listed = set(re.findall(r'^      - (.+)$', self.text.split('types: [completed]')[0], re.M))
        expected = set()
        for path in (ROOT / '.github/workflows').glob('*.yml'):
            source = path.read_text(encoding='utf-8')
            triggers = source.split('\njobs:')[0]
            if re.search(r'^  pull_request:?\s*$', triggers, re.M):
                expected.add(re.search(r'^name:\s*(.+?)\s*$', source, re.M).group(1).strip('\'"'))
        self.assertIn('CI', expected)
        self.assertEqual(listed, expected, 'Add new pull_request workflows to agent-ci-digest.yml workflows:')

    def test_short_job_and_usage_doc(self):
        self.assertIn('timeout-minutes: 10', self.text)
        self.assertTrue((ROOT / 'docs/agent-ci-digest.md').is_file())


if __name__ == '__main__':
    unittest.main()
