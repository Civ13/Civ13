"""Offline durable deferral contracts; no grants, settings, dispatches or uploads."""
import base64
import contextlib
import copy
import importlib.util
import json
import io
from pathlib import Path
import sys
import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, patch
import re

from test_import import u, h, pilot
import test_import as history

spec = importlib.util.spec_from_file_location("deferred", Path(u.__file__).with_name("deferred.py"))
d = importlib.util.module_from_spec(spec)
sys.modules["deferred"] = d
spec.loader.exec_module(d)


class GH:
    def __init__(self, original, now=100000):
        self.original = original
        self.objects = original.objects
        self.queue = {"schema_version": 1, "channel_id": u.CHANNEL, "records": {}}
        self.version, self.writes, self.fail_save = 1, 0, None
        self.objects['/commits/master'] = {'sha': 'b' * 40}
        self.set_gates(now)
        for status in ("queued", "in_progress", "waiting", "pending", "requested"):
            self.objects[f'/actions/workflows/youtube-upload.yml/runs?branch=master&status={status}&per_page=100'] = {
                'total_count': 0, 'workflow_runs': []}

    @property
    def ledger(self):
        return self.original.ledger

    def set_gates(self, now, stop=False, enabled=True):
        values = {'YOUTUBE_UPLOAD_ENABLED': 'true', 'YOUTUBE_UPLOAD_STOP_USE': 'true' if stop else 'false',
            'YOUTUBE_ZERO_COST_CONFIRMED': 'true', 'YOUTUBE_DEFERRED_ENABLED': 'true' if enabled else 'false',
            'YOUTUBE_DEFERRED_ARMED_UNTIL': str(now + 900)}
        self.objects['/actions/variables?per_page=100'] = {'total_count': len(values),
            'variables': [{'name': k, 'value': v} for k, v in values.items()]}
        env = {k: v for k, v in values.items() if k in
            {'YOUTUBE_UPLOAD_ENABLED', 'YOUTUBE_UPLOAD_STOP_USE', 'YOUTUBE_ZERO_COST_CONFIRMED'}}
        self.objects['/environments/youtube-unlisted/variables?per_page=100'] = {
            'total_count': len(env), 'variables': [{'name': k, 'value': v} for k, v in env.items()]}

    def repo(self, path, method='GET', value=None):
        if path.startswith('/contents/deferred.json'):
            if method == 'GET':
                raw = u.canonical(self.queue)
                return {'sha': str(self.version), 'encoding': 'base64', 'size': len(raw),
                    'content': base64.b64encode(raw).decode()}
            if self.fail_save == self.writes + 1 or value['sha'] != str(self.version):
                raise u.Refused('CAS conflict or uncertain persistence')
            self.queue = u.parse_json(base64.b64decode(value['content']))
            self.version += 1
            self.writes += 1
            return {'content': {'sha': str(self.version)}}
        return self.original.repo(path, method, value)

    def variables(self, scope):
        path = '/actions/variables?per_page=100' if scope == 'repository' else '/environments/youtube-unlisted/variables?per_page=100'
        return {v['name']: v['value'] for v in self.repo(path)['variables']}

    def read(self, scope, name):
        return self.variables(scope)[name]


def run_tick(gh, *args, **kwargs):
    return d.tick(gh, *args, control=gh, **kwargs)


def setup(now=100000, attachment=False):
    p, m, fake = history.HistoricalImportTests().attachment() if attachment else pilot()
    gh = GH(fake, now)
    manifest_id = 'pr3081-attachments-public' if attachment else h.PILOT_ID
    queue = d.Queue(gh)
    ident, entry = queue.enqueue(manifest_id, m, 10, now, now, 'rolling_cap')
    return gh, ident, m


class ControlReaderTests(unittest.TestCase):
    def response(self, name, value='false', status=200):
        return status, {}, u.canonical({'name': name, 'value': value})

    def test_only_eight_named_gets_receive_app_token_and_writes_keep_workflow_token(self):
        names = [(scope, name) for scope, values in d.CONTROL_NAMES.items() for name in values]
        transport = history.FakeTransport([self.response(name) for _, name in names])
        reader = d.ControlReader(transport, 'CONTROL-READ-ONLY')
        for scope in d.CONTROL_NAMES:
            reader.variables(scope)
        self.assertEqual(len(transport.calls), 8)
        for (scope, name), (args, kwargs) in zip(names, transport.calls):
            prefix = '/actions/variables/' if scope == 'repository' else '/environments/youtube-unlisted/variables/'
            self.assertEqual(args[0:2], ('GET', 'https://api.github.com/repos/Civ13/Civ13' + prefix + name))
            self.assertEqual(args[2]['Authorization'], 'Bearer CONTROL-READ-ONLY')
            self.assertEqual(len(args), 3)  # No request body or mutation method.
            self.assertEqual(kwargs, {})
        writes = history.FakeTransport([(200, {}, b'{}'), (204, {}, b''), (202, {}, b'')])
        gh = u.GitHub(writes, 'WORKFLOW-WRITES')
        gh.repo('/contents/deferred.json', method='PUT', value={'fixture': True})
        d.dispatch(gh, 'youtube-upload.yml', {'fixture': 'true'})
        d.cancel_overdue_run(gh, 42)
        for args, _ in writes.calls:
            self.assertIn(args[0], {'PUT', 'POST'})
            self.assertEqual(args[2]['Authorization'], 'Bearer WORKFLOW-WRITES')
            self.assertNotIn('CONTROL-READ-ONLY', str(args))

    def test_missing_token_or_control_never_falls_back_to_github_token_or_other_path(self):
        with patch.dict(d.os.environ, {'GITHUB_TOKEN': 'WORKFLOW-ONLY'}, clear=True), \
                patch.object(u.Transport, 'request', side_effect=AssertionError('No token fallback')):
            with self.assertRaises(u.Refused):
                d.ControlReader.from_environment()
        transport = history.FakeTransport([])
        reader = d.ControlReader(transport, 'OFFLINE-CONTROL')
        for scope, name in [('other', 'YOUTUBE_UPLOAD_ENABLED'), ('environment', 'YOUTUBE_DEFERRED_ENABLED'),
                ('repository', 'UNRELATED_SECRET'), ('environment', '../other/variables/x')]:
            with self.assertRaises(u.Refused):
                reader.read(scope, name)
        self.assertEqual(transport.calls, [])
        for response in [(403, {}, b'PRIVATE'), (404, {}, b'PRIVATE'), (500, {}, b'PRIVATE'),
                (200, {}, b'{}'), self.response('WRONG-NAME')]:
            reader = d.ControlReader(history.FakeTransport([response]), 'OFFLINE-CONTROL')
            with self.assertRaises(u.Refused) as caught:
                reader.read('repository', 'YOUTUBE_UPLOAD_ENABLED')
            self.assertNotIn('PRIVATE', str(caught.exception))

    def test_fresh_both_scope_reads_and_manual_feature_off_no_app_dependency(self):
        values = {'YOUTUBE_UPLOAD_ENABLED': 'true', 'YOUTUBE_UPLOAD_STOP_USE': 'false',
            'YOUTUBE_ZERO_COST_CONFIRMED': 'true', 'YOUTUBE_DEFERRED_ENABLED': 'true',
            'YOUTUBE_DEFERRED_ARMED_UNTIL': '100900'}
        responses = [self.response(name, values[name]) for scope in d.CONTROL_NAMES for name in d.CONTROL_NAMES[scope]]
        stopped = responses.copy()
        stopped[6] = self.response('YOUTUBE_UPLOAD_STOP_USE', 'true')
        transport = history.FakeTransport(responses + stopped)
        reader = d.ControlReader(transport, 'OFFLINE-CONTROL')
        self.assertEqual(d.controls(100000, reader), '')
        self.assertEqual(d.controls(100001, reader), 'emergency_stop')
        self.assertEqual(len(transport.calls), 16)
        with patch.dict(d.os.environ, {'YOUTUBE_DEFERRED_ENABLED': 'false'}, clear=True), \
                patch.object(d.ControlReader, 'from_environment', side_effect=AssertionError('Manual path must not need App')):
            self.assertFalse(d.defer_upload(None, 'unused', None, None, 100000))

    def test_pinned_action_inherits_only_approved_installation_permissions_and_revokes(self):
        root = Path(__file__).resolve().parents[2]
        metadata = (root / 'tests/youtube_upload/fixtures/create-app-token-v3.3.0-action.yml').read_text()
        inputs = metadata.split('\ninputs:\n')[1].split('\noutputs:\n')[0]
        supported = set(re.findall(r'^  ([a-z][a-z0-9-]*):', inputs, re.M))
        self.assertIn('permission-environments', supported)
        self.assertNotIn('permission-variables', supported)
        self.assertIn('using: "node24"', metadata)
        pin = 'actions/create-github-app-token@64ab729a6294000f5aa4a4bc0b73d1f32bc45510'
        for filename in ('youtube-deferred.yml', 'youtube-upload-worker.yml'):
            workflow = (root / '.github/workflows' / filename).read_text()
            mint = workflow.split('uses: ' + pin)[1].split('\n      - name:')[0]
            self.assertIn('owner: Civ13', mint)
            self.assertIn('repositories: Civ13', mint)
            self.assertIn('skip-token-revoke: false', mint)
            self.assertIn('app-id: ${{ vars.YOUTUBE_CONTROL_APP_ID }}', mint)
            self.assertIn('private-key: ${{ secrets.YOUTUBE_CONTROL_APP_PRIVATE_KEY }}', mint)
            self.assertNotRegex(mint, r'\n\s+permission-[a-z-]+:')
            self.assertIn('YOUTUBE_CONTROL_TOKEN: ${{ steps.control-token.outputs.token }}', workflow)
            self.assertNotIn('GITHUB_TOKEN: ${{ steps.control-token.outputs.token }}', workflow)
        worker = (root / '.github/workflows/youtube-upload-worker.yml').read_text()
        inspect, upload = worker.split('\n  upload:\n')
        self.assertNotIn(pin, inspect)
        self.assertIn('environment: youtube-unlisted', upload)
        self.assertIn("if: inputs.review_hours == '8' || vars.YOUTUBE_DEFERRED_ENABLED == 'true' || inputs.deferred_id != '' || inputs.deferred_token != ''", upload)
        controller = (root / '.github/workflows/youtube-deferred.yml').read_text()
        self.assertIn('environment: youtube-controls', controller)
        self.assertIn("if: contains(fromJSON('[\"tick\",\"control-probe\"]'), inputs.operation || 'tick')", controller)
        manage = controller.split('\n  manage:\n')[1]
        self.assertNotIn('environment:', manage)
        self.assertNotIn('control-token', manage)
        checks = (root / '.github/workflows/youtube-upload-checks.yml').read_text()
        self.assertNotIn('capability-probe', checks)

    def test_app_probe_reports_named_status_without_values_and_never_touches_queue(self):
        pairs = [(scope, name) for scope, values in d.CONTROL_NAMES.items() for name in values]
        responses = [self.response(name, 'PRIVATE-CONTROL-VALUE') for _, name in pairs]
        for index in (3, 4):
            responses[index] = (404, {}, b'PRIVATE-ERROR')
        reader = d.ControlReader(history.FakeTransport(responses), 'OFFLINE-APP')
        proof = d.control_probe(reader)
        self.assertFalse(proof['all_controls_readable'])
        self.assertEqual(proof['controls']['repository:YOUTUBE_DEFERRED_ENABLED']['status'], 404)
        self.assertNotIn('PRIVATE', json.dumps(proof))
        responses = [self.response(name) for _, name in pairs]
        with patch.object(d.ControlReader, 'from_environment', return_value=d.ControlReader(history.FakeTransport(responses), 'OFFLINE-APP')), \
                patch.object(d, 'Queue', side_effect=AssertionError('Probe never initializes or reads queue')), \
                patch.object(u, 'GitHub', side_effect=AssertionError('No workflow-token API proof')), \
                patch.dict(d.os.environ, {'GITHUB_REPOSITORY': u.REPO, 'GITHUB_REF': 'refs/heads/master',
                    'GITHUB_EVENT_NAME': 'workflow_dispatch', 'GITHUB_WORKFLOW_REF': u.REPO + '/' + d.WORKFLOW + '@refs/heads/master'}, clear=True), \
                patch.object(sys, 'argv', ['deferred.py', 'control-probe']), contextlib.redirect_stdout(io.StringIO()) as output:
            d.main()
        self.assertTrue(json.loads(output.getvalue())['all_controls_readable'])
        limited = history.FakeTransport([u.RateLimited(429, 100120)])
        proof = d.control_probe(d.ControlReader(limited, 'OFFLINE-APP'))
        self.assertEqual(len(limited.calls), 1)
        self.assertFalse(proof['all_controls_readable'])
        self.assertEqual(list(proof['controls'].values())[1]['status'], 'not_attempted_after_limit')


class EligibilityTests(unittest.TestCase):
    def test_only_transient_get_failures_are_retryable_and_diagnostics_are_sanitized(self):
        url = 'https://api.github.com/repos/Civ13/Civ13'
        for method in ('GET', 'POST', 'PUT'):
            errors = [u.urllib.error.HTTPError(url, code, 'PRIVATE-BODY', {}, None)
                      for code in (400, 401, 403, 404, 500, 503, 599)]
            errors += [OSError('PRIVATE-NETWORK'), ValueError('PRIVATE-REQUEST')]
            for error in errors:
                transient = method == 'GET' and (type(error) is OSError or
                    isinstance(error, u.urllib.error.HTTPError) and error.code >= 500)
                transport = u.Transport()
                with patch.object(transport.opener, 'open', side_effect=error), self.assertRaises(u.Refused) as caught:
                    transport.request(method, url)
                self.assertEqual(isinstance(caught.exception, u.Unavailable), transient)
                self.assertNotIn('PRIVATE', str(caught.exception))
            response = MagicMock()
            response.read.side_effect = OSError('PRIVATE-READ')
            transport = u.Transport()
            with patch.object(transport.opener, 'open', return_value=response), \
                    self.assertRaises(u.Refused) as caught:
                transport.request(method, url)
            self.assertEqual(isinstance(caught.exception, u.Unavailable), method == 'GET')
            self.assertNotIn('PRIVATE', str(caught.exception))

    def test_secondary_get_limit_differs_from_permission_failure_and_post(self):
        url = 'https://api.github.com/repos/Civ13/Civ13'
        for method, headers, limited in (
                ('GET', {'Retry-After': '120', 'X-RateLimit-Remaining': '4999'}, True),
                ('GET', {'X-RateLimit-Remaining': '0'}, True),
                ('GET', {'Retry-After': 'PRIVATE-URL'}, False),
                ('GET', {}, False),
                ('POST', {'Retry-After': '120', 'X-RateLimit-Remaining': '0'}, False)):
            transport = u.Transport()
            error = u.urllib.error.HTTPError(url, 403, 'PRIVATE-BODY', headers, None)
            with patch.object(transport.opener, 'open', side_effect=error), patch.object(u.time, 'time', return_value=100000):
                with self.assertRaises(u.Refused) as caught:
                    transport.request(method, url)
            self.assertEqual(isinstance(caught.exception, u.RateLimited), limited)
            self.assertNotIn('PRIVATE', str(caught.exception))
            if limited:
                self.assertFalse(caught.exception.media_attempted)
                self.assertGreaterEqual(caught.exception.retry_at, 100120 if headers.get('Retry-After') else 100060)

    def test_inclusive_boundary_and_current_two_reservations(self):
        records = [{'reserved_at': 1792497964}, {'reserved_at': 1792509762}]
        self.assertEqual(d.rolling_eligible_at(records, 1792518000), 1792584365)
        self.assertEqual(d.rolling_eligible_at(records, 1792584364), 1792584365)
        self.assertEqual(d.rolling_eligible_at(records, 1792584365), 1792584365)
        self.assertEqual(d.utc(1792584365), '2026-10-21 12:06:05 UTC')
        self.assertEqual(d.rolling_eligible_at([{'reserved_at': 10}, {'reserved_at': 20}, {'reserved_at': 30}], 100), 86421)
        with self.assertRaises(u.Refused):
            d.rolling_eligible_at([{'reserved_at': 100301}], 100000)

    def test_provider_headers_are_bounded_utc_and_unknown_backoff_is_finite(self):
        self.assertEqual(d.retry_at({'Retry-After': '120'}, 100000), 100120)
        self.assertEqual(d.retry_at({'Retry-After': 'Thu, 01 Jan 1970 04:00:00 GMT'}, 10000), 14400)
        self.assertEqual(d.retry_at({'Retry-After': 'Thu, 01 Jan 1970 05:00:00 +0100'}, 10000), 14400)
        self.assertEqual(d.retry_at({'X-RateLimit-Reset': '100900'}, 100000), 100900)
        self.assertEqual(d.retry_at({'Retry-After': 'secret-or-untrusted-url'}, 100000), 103600)
        self.assertEqual(d.retry_at({'Retry-After': '-5'}, 100000, 6), 186400)
        self.assertEqual(d.retry_at({'Retry-After': '9999999'}, 100000), 103600)


class QueueTests(unittest.TestCase):
    def test_transient_source_get_keeps_bounded_wait_instead_of_revoking_approval(self):
        url = 'https://api.github.com/repos/Civ13/Civ13/actions/runs/123'
        for error in (u.urllib.error.HTTPError(url, 503, 'PRIVATE-BODY', {}, None),
                      OSError('PRIVATE-NETWORK-DETAIL')):
            gh, ident, _ = setup()
            transport = u.Transport()
            def read_source(*args):
                return transport.request('GET', url)
            with patch.object(transport.opener, 'open', side_effect=error), \
                    patch.object(d, 'core_material', side_effect=read_source), patch.object(d, 'dispatch') as send:
                run_tick(gh, 100000, 'b' * 40)
            send.assert_not_called()
            entry = gh.queue['records'][ident]
            self.assertEqual((entry['state'], entry['reason'], entry['attempts']),
                             ('waiting', 'provider_unavailable', 1))
            self.assertGreater(entry['next_eligible_at'], 100000)

    def test_unavailable_wait_honors_deadline_budget_and_fresh_revoked_approval(self):
        gh, ident, _ = setup(attachment=True)
        with patch.object(d, 'core_material', side_effect=u.Unavailable('Safe GET failure')):
            run_tick(gh, 100000, 'b' * 40)
        due = gh.queue['records'][ident]['next_eligible_at']
        with patch.object(d, 'core_material', side_effect=AssertionError('No early revalidation')), \
                patch.object(d, 'dispatch') as send:
            run_tick(gh, due - 1, 'b' * 40)
        send.assert_not_called()
        gh.objects['/issues/comments/456']['body'] = 'Revoked'
        with patch.object(d, 'dispatch') as send:
            run_tick(gh, due, 'b' * 40)
        send.assert_not_called()
        self.assertEqual(gh.queue['records'][ident]['reason'], 'approval_or_source_invalid')
        gh, ident, _ = setup()
        now = 100000
        with patch.object(d, 'core_material', side_effect=u.Unavailable('Safe GET failure')), \
                patch.object(d, 'dispatch') as send:
            for attempt in range(d.MAX_ATTEMPTS):
                run_tick(gh, now, 'b' * 40)
                entry = gh.queue['records'][ident]
                self.assertEqual(entry['attempts'], attempt + 1)
                self.assertGreater(entry['next_eligible_at'], now)
                now = entry['next_eligible_at']
            run_tick(gh, now, 'b' * 40)
        send.assert_not_called()
        self.assertEqual(gh.queue['records'][ident]['state'], 'exhausted')

    def test_skipped_upload_requires_one_successful_inspect_before_gate_wait(self):
        for inspections, waiting in ((['success'], True), (['failure'], False),
                                     (['cancelled'], False), (['timed_out'], False), (['skipped'], False),
                                     ([], False), (['success', 'success'], False)):
            gh, ident, _ = setup()
            with patch.object(d, 'dispatch'):
                run_tick(gh, 100000, 'b' * 40)
            queue = d.Queue(gh)
            entry = queue.data['records'][ident]
            entry['active_run_id'] = 42
            gh.objects['/actions/runs/42'] = {'id': 42, 'repository': {'id': u.REPO_ID},
                'head_sha': 'b' * 40, 'event': 'workflow_dispatch', 'head_branch': 'master',
                'run_attempt': 1, 'status': 'completed', 'conclusion': 'failure'}
            jobs = [{'name': 'approved-upload / upload', 'conclusion': 'skipped'}] + [
                {'name': 'approved-upload / inspect', 'conclusion': value} for value in inspections]
            gh.objects['/actions/runs/42/jobs?per_page=100'] = {'total_count': len(jobs), 'jobs': jobs}
            d.reconcile(gh, entry, u.Ledger(gh), 100001)
            self.assertEqual((entry['state'], entry['reason']),
                ('waiting', 'gates_closed') if waiting else ('blocked', 'failed_run_requires_reconciliation'))
            if waiting:
                # A success from an unrelated reusable-job prefix is insufficient.
                entry.update(state='dispatching', reason='dispatch_pending', active_run_id=42)
                jobs[1]['name'] = 'other-worker / inspect'
                d.reconcile(gh, entry, u.Ledger(gh), 100001)
                self.assertEqual(entry['state'], 'blocked')
                jobs[1]['name'] = 'approved-upload / inspect'
                # Missing/paginated jobs must not be treated as a gate-only skip.
                entry.update(state='dispatching', reason='dispatch_pending', active_run_id=42)
                gh.objects['/actions/runs/42/jobs?per_page=100']['total_count'] += 1
                with self.assertRaises(u.Refused):
                    d.reconcile(gh, entry, u.Ledger(gh), 100001)

    def test_manual_run_and_other_queue_owner_block_destination(self):
        gh, ident, _ = setup()
        gh.objects['/actions/workflows/youtube-upload.yml/runs?branch=master&status=waiting&per_page=100'] = {
            'total_count': 1, 'workflow_runs': [{'id': 99}]}
        with patch.object(d, 'dispatch') as send:
            run_tick(gh, 100000, 'b' * 40)
        send.assert_not_called()
        self.assertEqual(gh.queue['records'][ident]['hold_reason'], 'destination_busy')
        self.assertEqual(gh.queue['records'][ident]['attempts'], 0)
        gh, ident, _ = setup()
        gh.queue['records'][ident].update(state='blocked', reason='dispatch_outcome_unknown')
        with patch.object(d, 'destination_busy', side_effect=AssertionError('Unknown claim already owns destination')), \
                patch.object(d, 'dispatch') as send:
            run_tick(gh, 100000, 'b' * 40)
        send.assert_not_called()

    def test_read_limit_wait_is_finite_and_attempted_insert_cannot_defer(self):
        gh, ident, _ = setup()
        with patch.object(d, 'core_material', side_effect=u.RateLimited(429, 100120)):
            run_tick(gh, 100000, 'b' * 40)
        entry = gh.queue['records'][ident]
        self.assertEqual((entry['reason'], entry['next_eligible_at'], entry['attempts']), ('provider_limit', 100120, 1))
        with patch.object(d, 'core_material', side_effect=AssertionError('Wait until provider boundary')):
            run_tick(gh, 100119, 'b' * 40)
        with self.assertRaises(u.Refused):
            d.provider_wait(entry, u.RateLimited(429, 100120, True), 100000)
        gh.queue['records'][ident]['attempts'] = d.MAX_ATTEMPTS
        run_tick(gh, 100120, 'b' * 40)
        self.assertEqual(gh.queue['records'][ident]['state'], 'exhausted')

    def test_inventory_retry_after_respected_and_expiry_precedes_outage(self):
        gh, ident, _ = setup()
        with patch.object(d, 'destination_busy', side_effect=u.RateLimited(429, 100900)) as read:
            run_tick(gh, 100000, 'b' * 40)
            run_tick(gh, 100899, 'b' * 40)
        self.assertEqual(read.call_count, 1)
        self.assertEqual(gh.queue['records'][ident]['attempts'], 1)
        gh.queue['records'][ident]['expires_at'] = 100901
        with patch.object(d, 'destination_busy', side_effect=AssertionError('Expired before provider access')):
            run_tick(gh, 100901, 'b' * 40)
        self.assertEqual(gh.queue['records'][ident]['state'], 'expired')
        gh, ident, _ = setup()
        gh.queue['records'][ident]['attempts'] = d.MAX_ATTEMPTS
        with patch.object(d, 'destination_busy', side_effect=AssertionError('Exhausted before provider access')):
            run_tick(gh, 100000, 'b' * 40)
        self.assertEqual(gh.queue['records'][ident]['state'], 'exhausted')

    def test_overdue_protected_review_cancels_without_releasing_receipt(self):
        gh, ident, m = setup()
        with patch.object(d, 'dispatch'):
            run_tick(gh, 100000, 'b' * 40)
        gh.queue['records'][ident]['active_run_id'] = 42
        gh.objects['/actions/runs/42'] = {'id': 42, 'repository': {'id': u.REPO_ID}, 'head_sha': 'b' * 40,
            'event': 'workflow_dispatch', 'head_branch': 'master', 'run_attempt': 1, 'status': 'waiting'}
        record = {'state': 'uncertain', 'channel_id': u.CHANNEL, 'clip_sha256': m['clip']['sha256'],
            'commit': m['source']['commit'], 'reserved_at': 100000}
        gh.ledger['records'][u.receipt_key(m)] = record.copy()
        with patch.object(d, 'cancel_overdue_run', side_effect=u.Refused('Cancellation outcome uncertain')) as cancel:
            with self.assertRaises(u.Refused):
                run_tick(gh, 100900, 'b' * 40)
        cancel.assert_called_once_with(gh, 42)
        self.assertEqual(gh.queue['records'][ident]['reason'], 'run_deadline_requires_reconciliation')
        self.assertEqual(gh.ledger['records'][u.receipt_key(m)], record)

    def test_variable_permission_failure_is_fail_closed_and_probe_has_no_values(self):
        gh, ident, _ = setup()
        original = gh.repo
        def denied(path, *args, **kwargs):
            if '/variables?' in path:
                raise u.Refused('GitHub GET failed (403)')
            return original(path, *args, **kwargs)
        with patch.object(gh, 'repo', side_effect=denied), patch.object(d, 'dispatch') as send:
            with self.assertRaises(u.Refused):
                run_tick(gh, 100000, 'b' * 40)
            proof = d.control_probe(gh)
        send.assert_not_called()
        self.assertFalse(proof['all_controls_readable'])
        self.assertTrue(all(item == {'supported': False, 'status': 'invalid_or_unavailable'}
            for item in proof['controls'].values()))
        self.assertNotIn('value', json.dumps(proof))

    def test_reviewed_derivative_never_uses_private_original_and_locks_are_separate(self):
        _, _, m = setup()
        self.assertNotEqual(d.reviewed_transport(m), m['import']['original_url'])
        self.assertEqual(d.reviewed_transport(m), d.REVIEWED_TRANSPORTS[m['clip']['sha256']])
        altered = copy.deepcopy(m)
        altered['metadata']['title'] = 'Changed reviewed material'
        with self.assertRaises(u.Refused):
            d.reviewed_transport(altered)
        root = Path(__file__).resolve().parents[2]
        self.assertIn('group: youtube-deferred-controller', (root / '.github/workflows/youtube-deferred.yml').read_text())
        self.assertIn('group: youtube-unlisted-valzartech8995', (root / '.github/workflows/youtube-upload-worker.yml').read_text())
        controller = (root / '.github/workflows/youtube-deferred.yml').read_text()
        self.assertIn('github.event_name == \'workflow_dispatch\' && contains(fromJSON(\'["status","cancel"]\'), inputs.operation)', controller)

    def test_adapter_metadata_preserves_preinsert_vs_uncertain_insert_without_logging_body(self):
        credentials = {name: 'OFFLINE-FAKE' for name in ('YOUTUBE_CLIENT_ID', 'YOUTUBE_CLIENT_SECRET', 'YOUTUBE_REFRESH_TOKEN')}
        for attempted in (False, True):
            safe = {'kind': 'rate_limit', 'status': 429, 'retry_at': 100120, 'media_attempted': attempted}
            result = SimpleNamespace(returncode=1, stdout=u.canonical(safe), stderr=b'PRIVATE-ERROR')
            with patch.dict(u.os.environ, credentials), patch.object(u.subprocess, 'run', return_value=result):
                with self.assertRaises(u.RateLimited) as caught:
                    u.PhpYouTube().call('channel')
            self.assertEqual(caught.exception.metadata(), safe)
            self.assertNotIn('PRIVATE', str(caught.exception))
        result.stdout = b'{"kind":"rate_limit","status":429,"retry_at":100120,"media_attempted":false,"url":"PRIVATE"}'
        with patch.dict(u.os.environ, credentials), patch.object(u.subprocess, 'run', return_value=result):
            with self.assertRaises(u.Refused) as caught:
                u.PhpYouTube().call('channel')
        self.assertNotIsInstance(caught.exception, u.RateLimited)

    def test_enqueue_is_idempotent_and_cannot_revive_cancelled_or_changed_material(self):
        gh, ident, m = setup()
        queue = d.Queue(gh)
        queue.data['records'][ident]['state'] = 'cancelled'
        queue.save()
        writes = gh.writes
        _, entry = d.Queue(gh).enqueue(h.PILOT_ID, m, 10, 100001, 100001, 'rolling_cap')
        self.assertEqual(entry['state'], 'cancelled')
        self.assertEqual(gh.writes, writes)
        changed = copy.deepcopy(m)
        changed['metadata']['title'] = 'Changed source material'
        with self.assertRaises(u.Refused):
            d.Queue(gh).enqueue(h.PILOT_ID, changed, 10, 100001, 100001, 'rolling_cap')

    def test_two_queue_readers_cannot_both_win_claim(self):
        gh, ident, _ = setup()
        first, stale = d.Queue(gh), d.Queue(gh)
        first.data['records'][ident]['state'] = 'dispatching'
        first.save()
        stale.data['records'][ident]['state'] = 'cancelled'
        with self.assertRaises(u.Refused):
            stale.save()
        self.assertEqual(gh.queue['records'][ident]['state'], 'dispatching')

    def test_cap_wait_and_emergency_hold_are_separate_and_do_not_consume_attempts(self):
        gh, ident, _ = setup()
        gh.ledger['records'] = {'a' * 64: {'channel_id': u.CHANNEL, 'clip_sha256': 'a' * 64,
            'commit': 'a' * 40, 'state': 'uncertain', 'reserved_at': 99999},
            'b' * 64: {'channel_id': u.CHANNEL, 'clip_sha256': 'b' * 64,
            'commit': 'b' * 40, 'state': 'verified', 'reserved_at': 100000, 'video_id': 'abcdefghijk'}}
        gh.set_gates(100000, stop=True)
        with patch.object(d, 'dispatch', side_effect=AssertionError('No dispatch under stop')):
            run_tick(gh, 100000, 'b' * 40)
        entry = gh.queue['records'][ident]
        self.assertEqual((entry['reason'], entry['hold_reason'], entry['attempts']), ('rolling_cap', 'emergency_stop', 0))
        self.assertEqual(entry['next_eligible_at'], 186400)

    def test_due_dispatch_claim_persists_before_post_and_stale_artifact_reimports(self):
        for stale in (False, True):
            gh, ident, _ = setup()
            with patch.object(d, 'resolve_artifact', return_value=not stale), patch.object(d, 'dispatch') as send:
                run_tick(gh, 100000, 'b' * 40)
            entry = gh.queue['records'][ident]
            self.assertEqual(entry['state'], 'dispatching')
            self.assertEqual(entry['attempts'], 1)
            self.assertEqual(send.call_count, 1)
            self.assertEqual(send.call_args.args[1], 'youtube-prepare-import.yml' if stale else 'youtube-upload.yml')
            self.assertEqual(send.call_args.args[2].get('deferred_token'), entry['token'])

    def test_failed_claim_never_dispatches_and_uncertain_post_never_blindly_retries(self):
        gh, ident, _ = setup()
        gh.fail_save = gh.writes + 1
        with patch.object(d, 'dispatch') as send, self.assertRaises(u.Refused):
            run_tick(gh, 100000, 'b' * 40)
        send.assert_not_called()
        gh, ident, _ = setup()
        with patch.object(d, 'dispatch', side_effect=u.Refused('Unknown dispatch')):
            with self.assertRaises(u.Refused):
                run_tick(gh, 100000, 'b' * 40)
        entry = gh.queue['records'][ident]
        self.assertEqual(entry['state'], 'dispatching')
        gh.objects[d.runs_path(entry)] = {
            'total_count': 0, 'workflow_runs': []}
        with patch.object(d, 'dispatch', side_effect=AssertionError('No blind redispatch')):
            run_tick(gh, 100900, 'b' * 40)
        self.assertEqual(gh.queue['records'][ident]['reason'], 'dispatch_outcome_unknown')

    def test_revoked_approval_and_uncertain_receipt_block_dispatch(self):
        gh, ident, m = setup(attachment=True)
        gh.objects['/issues/comments/456']['body'] = 'Revoked or edited'
        with patch.object(d, 'dispatch') as send:
            run_tick(gh, 100000, 'b' * 40)
        send.assert_not_called()
        self.assertEqual(gh.queue['records'][ident]['reason'], 'approval_or_source_invalid')
        gh, ident, m = setup()
        gh.ledger['records'][u.receipt_key(m)] = {'state': 'uncertain', 'channel_id': u.CHANNEL,
            'clip_sha256': m['clip']['sha256'], 'commit': m['source']['commit'], 'reserved_at': 99999}
        with patch.object(d, 'dispatch') as send:
            run_tick(gh, 100000, 'b' * 40)
        send.assert_not_called()
        self.assertEqual(gh.queue['records'][ident]['reason'], 'media_outcome_uncertain')

    def test_known_id_is_verify_only_without_source_artifact(self):
        gh, ident, m = setup()
        record = u.Ledger(gh).reserve(m, 99999)
        record.update(state='uploaded', video_id='abcdefghijk')
        gh.ledger['records'][u.receipt_key(m)] = record
        gh.queue['records'][ident]['import_run_id'] = 999
        with patch.object(d, 'resolve_artifact', side_effect=AssertionError('No artifact for known ID')), patch.object(d, 'dispatch') as send:
            run_tick(gh, 100000, 'b' * 40)
        self.assertEqual(send.call_args.args[2]['verify_only'], 'true')
        self.assertEqual(send.call_args.args[2]['import_run_id'], '10')
        entry = gh.queue['records'][ident]
        _, resolved = h.resolve_pilot_receipt(gh, entry['import_run_id'], entry['manifest_id'], entry['approval_comment_id'])
        self.assertEqual(resolved['import'], record['historical_import'])
        gh, ident, m = setup()
        gh.ledger['records'][u.receipt_key(m)] = record
        gh.ledger['records'][u.receipt_key(m)]['commit'] = 'c' * 40
        with patch.object(d, 'dispatch') as send, self.assertRaises(u.Refused):
            run_tick(gh, 100000, 'b' * 40)
        send.assert_not_called()

    def test_expiry_cancellation_retry_exhaustion_and_feature_off_never_dispatch(self):
        for state in ('cancelled', 'expired', 'blocked', 'exhausted'):
            gh, ident, _ = setup()
            gh.queue['records'][ident]['state'] = state
            with patch.object(d, 'dispatch') as send:
                run_tick(gh, 100000, 'b' * 40)
            send.assert_not_called()
        gh, ident, _ = setup()
        gh.queue['records'][ident]['attempts'] = d.MAX_ATTEMPTS
        run_tick(gh, 100000, 'b' * 40)
        self.assertEqual(gh.queue['records'][ident]['state'], 'exhausted')
        gh, ident, _ = setup()
        gh.set_gates(100000, enabled=False)
        with patch.object(d, 'dispatch') as send:
            run_tick(gh, 100000, 'b' * 40)
        send.assert_not_called()
        self.assertEqual(gh.queue['records'][ident]['hold_reason'], 'feature_disabled')

    def test_worker_claim_is_single_owner_and_rechecks_arm_and_cancellation(self):
        gh, ident, _ = setup()
        with patch.object(d, 'dispatch'):
            run_tick(gh, 100000, 'b' * 40)
        token = gh.queue['records'][ident]['token']
        d.worker_guard(gh, ident, token, 42, 100000, 'b' * 40, upload_step=True, control=gh)
        with self.assertRaises(u.Refused):
            d.worker_guard(gh, ident, token, 43, 100000, 'b' * 40, upload_step=True, control=gh)
        with self.assertRaises(u.Refused):
            d.worker_guard(gh, ident, token, 42, 100900, 'b' * 40, upload_step=True, control=gh)
        gh.queue['records'][ident]['state'] = 'cancelled'
        with self.assertRaises(u.Refused):
            d.worker_guard(gh, ident, token, 42, 100001, 'b' * 40, upload_step=True, control=gh)


if __name__ == '__main__':
    unittest.main()
