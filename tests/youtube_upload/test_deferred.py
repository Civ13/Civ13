"""Offline durable deferral contracts; no grants, settings, dispatches or uploads."""
import base64
import copy
import importlib.util
import json
from pathlib import Path
import sys
import unittest
from types import SimpleNamespace
from unittest.mock import patch

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


def setup(now=100000, attachment=False):
    p, m, fake = history.HistoricalImportTests().attachment() if attachment else pilot()
    gh = GH(fake, now)
    manifest_id = 'pr3081-attachments-public' if attachment else h.PILOT_ID
    queue = d.Queue(gh)
    ident, entry = queue.enqueue(manifest_id, m, 10, now, now, 'rolling_cap')
    return gh, ident, m


class EligibilityTests(unittest.TestCase):
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
    def test_manual_run_and_other_queue_owner_block_destination(self):
        gh, ident, _ = setup()
        gh.objects['/actions/workflows/youtube-upload.yml/runs?branch=master&status=waiting&per_page=100'] = {
            'total_count': 1, 'workflow_runs': [{'id': 99}]}
        with patch.object(d, 'dispatch') as send:
            d.tick(gh, 100000, 'b' * 40)
        send.assert_not_called()
        self.assertEqual(gh.queue['records'][ident]['hold_reason'], 'destination_busy')
        self.assertEqual(gh.queue['records'][ident]['attempts'], 0)
        gh, ident, _ = setup()
        gh.queue['records'][ident].update(state='blocked', reason='dispatch_outcome_unknown')
        with patch.object(d, 'destination_busy', side_effect=AssertionError('Unknown claim already owns destination')), \
                patch.object(d, 'dispatch') as send:
            d.tick(gh, 100000, 'b' * 40)
        send.assert_not_called()

    def test_read_limit_wait_is_finite_and_attempted_insert_cannot_defer(self):
        gh, ident, _ = setup()
        with patch.object(d, 'core_material', side_effect=u.RateLimited(429, 100120)):
            d.tick(gh, 100000, 'b' * 40)
        entry = gh.queue['records'][ident]
        self.assertEqual((entry['reason'], entry['next_eligible_at'], entry['attempts']), ('provider_limit', 100120, 1))
        with patch.object(d, 'core_material', side_effect=AssertionError('Wait until provider boundary')):
            d.tick(gh, 100119, 'b' * 40)
        with self.assertRaises(u.Refused):
            d.provider_wait(entry, u.RateLimited(429, 100120, True), 100000)
        gh.queue['records'][ident]['attempts'] = d.MAX_ATTEMPTS
        d.tick(gh, 100120, 'b' * 40)
        self.assertEqual(gh.queue['records'][ident]['state'], 'exhausted')

    def test_inventory_retry_after_respected_and_expiry_precedes_outage(self):
        gh, ident, _ = setup()
        with patch.object(d, 'destination_busy', side_effect=u.RateLimited(429, 100900)) as read:
            d.tick(gh, 100000, 'b' * 40)
            d.tick(gh, 100899, 'b' * 40)
        self.assertEqual(read.call_count, 1)
        self.assertEqual(gh.queue['records'][ident]['attempts'], 1)
        gh.queue['records'][ident]['expires_at'] = 100901
        with patch.object(d, 'destination_busy', side_effect=AssertionError('Expired before provider access')):
            d.tick(gh, 100901, 'b' * 40)
        self.assertEqual(gh.queue['records'][ident]['state'], 'expired')
        gh, ident, _ = setup()
        gh.queue['records'][ident]['attempts'] = d.MAX_ATTEMPTS
        with patch.object(d, 'destination_busy', side_effect=AssertionError('Exhausted before provider access')):
            d.tick(gh, 100000, 'b' * 40)
        self.assertEqual(gh.queue['records'][ident]['state'], 'exhausted')

    def test_overdue_protected_review_cancels_without_releasing_receipt(self):
        gh, ident, m = setup()
        with patch.object(d, 'dispatch'):
            d.tick(gh, 100000, 'b' * 40)
        gh.queue['records'][ident]['active_run_id'] = 42
        gh.objects['/actions/runs/42'] = {'id': 42, 'repository': {'id': u.REPO_ID}, 'head_sha': 'b' * 40,
            'event': 'workflow_dispatch', 'head_branch': 'master', 'run_attempt': 1, 'status': 'waiting'}
        record = {'state': 'uncertain', 'channel_id': u.CHANNEL, 'clip_sha256': m['clip']['sha256'],
            'commit': m['source']['commit'], 'reserved_at': 100000}
        gh.ledger['records'][u.receipt_key(m)] = record.copy()
        with patch.object(d, 'cancel_overdue_run', side_effect=u.Refused('Cancellation outcome uncertain')) as cancel:
            with self.assertRaises(u.Refused):
                d.tick(gh, 100900, 'b' * 40)
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
                d.tick(gh, 100000, 'b' * 40)
            proof = d.capability_probe(gh)
        send.assert_not_called()
        self.assertEqual(proof, {scope: {'supported': False, 'status': 'denied_or_unavailable'}
            for scope in ('repository_variables', 'environment_variables')})
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
            d.tick(gh, 100000, 'b' * 40)
        entry = gh.queue['records'][ident]
        self.assertEqual((entry['reason'], entry['hold_reason'], entry['attempts']), ('rolling_cap', 'emergency_stop', 0))
        self.assertEqual(entry['next_eligible_at'], 186400)

    def test_due_dispatch_claim_persists_before_post_and_stale_artifact_reimports(self):
        for stale in (False, True):
            gh, ident, _ = setup()
            with patch.object(d, 'resolve_artifact', return_value=not stale), patch.object(d, 'dispatch') as send:
                d.tick(gh, 100000, 'b' * 40)
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
            d.tick(gh, 100000, 'b' * 40)
        send.assert_not_called()
        gh, ident, _ = setup()
        with patch.object(d, 'dispatch', side_effect=u.Refused('Unknown dispatch')):
            with self.assertRaises(u.Refused):
                d.tick(gh, 100000, 'b' * 40)
        entry = gh.queue['records'][ident]
        self.assertEqual(entry['state'], 'dispatching')
        gh.objects[d.runs_path(entry)] = {
            'total_count': 0, 'workflow_runs': []}
        with patch.object(d, 'dispatch', side_effect=AssertionError('No blind redispatch')):
            d.tick(gh, 100900, 'b' * 40)
        self.assertEqual(gh.queue['records'][ident]['reason'], 'dispatch_outcome_unknown')

    def test_revoked_approval_and_uncertain_receipt_block_dispatch(self):
        gh, ident, m = setup(attachment=True)
        gh.objects['/issues/comments/456']['body'] = 'Revoked or edited'
        with patch.object(d, 'dispatch') as send:
            d.tick(gh, 100000, 'b' * 40)
        send.assert_not_called()
        self.assertEqual(gh.queue['records'][ident]['reason'], 'approval_or_source_invalid')
        gh, ident, m = setup()
        gh.ledger['records'][u.receipt_key(m)] = {'state': 'uncertain', 'channel_id': u.CHANNEL,
            'clip_sha256': m['clip']['sha256'], 'commit': m['source']['commit'], 'reserved_at': 99999}
        with patch.object(d, 'dispatch') as send:
            d.tick(gh, 100000, 'b' * 40)
        send.assert_not_called()
        self.assertEqual(gh.queue['records'][ident]['reason'], 'media_outcome_uncertain')

    def test_known_id_is_verify_only_without_source_artifact(self):
        gh, ident, m = setup()
        record = u.Ledger(gh).reserve(m, 99999)
        record.update(state='uploaded', video_id='abcdefghijk')
        gh.ledger['records'][u.receipt_key(m)] = record
        gh.queue['records'][ident]['import_run_id'] = 999
        with patch.object(d, 'resolve_artifact', side_effect=AssertionError('No artifact for known ID')), patch.object(d, 'dispatch') as send:
            d.tick(gh, 100000, 'b' * 40)
        self.assertEqual(send.call_args.args[2]['verify_only'], 'true')
        self.assertEqual(send.call_args.args[2]['import_run_id'], '10')
        entry = gh.queue['records'][ident]
        _, resolved = h.resolve_pilot_receipt(gh, entry['import_run_id'], entry['manifest_id'], entry['approval_comment_id'])
        self.assertEqual(resolved['import'], record['historical_import'])
        gh, ident, m = setup()
        gh.ledger['records'][u.receipt_key(m)] = record
        gh.ledger['records'][u.receipt_key(m)]['commit'] = 'c' * 40
        with patch.object(d, 'dispatch') as send, self.assertRaises(u.Refused):
            d.tick(gh, 100000, 'b' * 40)
        send.assert_not_called()

    def test_expiry_cancellation_retry_exhaustion_and_feature_off_never_dispatch(self):
        for state in ('cancelled', 'expired', 'blocked', 'exhausted'):
            gh, ident, _ = setup()
            gh.queue['records'][ident]['state'] = state
            with patch.object(d, 'dispatch') as send:
                d.tick(gh, 100000, 'b' * 40)
            send.assert_not_called()
        gh, ident, _ = setup()
        gh.queue['records'][ident]['attempts'] = d.MAX_ATTEMPTS
        d.tick(gh, 100000, 'b' * 40)
        self.assertEqual(gh.queue['records'][ident]['state'], 'exhausted')
        gh, ident, _ = setup()
        gh.set_gates(100000, enabled=False)
        with patch.object(d, 'dispatch') as send:
            d.tick(gh, 100000, 'b' * 40)
        send.assert_not_called()
        self.assertEqual(gh.queue['records'][ident]['hold_reason'], 'feature_disabled')

    def test_worker_claim_is_single_owner_and_rechecks_arm_and_cancellation(self):
        gh, ident, _ = setup()
        with patch.object(d, 'dispatch'):
            d.tick(gh, 100000, 'b' * 40)
        token = gh.queue['records'][ident]['token']
        d.worker_guard(gh, ident, token, 42, 100000, 'b' * 40, upload_step=True)
        with self.assertRaises(u.Refused):
            d.worker_guard(gh, ident, token, 43, 100000, 'b' * 40, upload_step=True)
        with self.assertRaises(u.Refused):
            d.worker_guard(gh, ident, token, 42, 100900, 'b' * 40, upload_step=True)
        gh.queue['records'][ident]['state'] = 'cancelled'
        with self.assertRaises(u.Refused):
            d.worker_guard(gh, ident, token, 42, 100001, 'b' * 40, upload_step=True)


if __name__ == '__main__':
    unittest.main()
