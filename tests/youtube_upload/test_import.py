"""Offline contracts for public pilot approval and honest historical provenance."""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from test_upload import u, fixtures, FakeGH, FakeTransport, FakeYT, bundle

sys.modules.setdefault("upload", u)
spec = importlib.util.spec_from_file_location("prepare_import", Path(u.__file__).with_name("prepare_import.py"))
h = importlib.util.module_from_spec(spec)
sys.modules["prepare_import"] = h
spec.loader.exec_module(h)


def pilot():
    run = {"id": 10, "run_attempt": 1, "workflow_id": 77, "head_sha": "b" * 40}
    m = h.material(h.specification(), run)
    p = h.policy(m)
    m["artifact"] = {"id": 2, "name": h.ARTIFACT_NAME, "archive_sha256": "a" * 64, "bytes": 500}
    base_policy, base_manifest, *_ = fixtures()
    gh = FakeGH(base_manifest)
    source = gh.objects.pop("/actions/runs/1")
    source.update(id=m["source"]["run_id"], head_sha=m["source"]["commit"],
        head_branch=m["source"]["head_branch"], workflow_id=m["source"]["workflow_id"],
        path=m["source"]["workflow_path"], pull_requests=[{"number": 3031}])
    gh.objects[f'/actions/runs/{source["id"]}'] = source
    gh.objects['/pulls/3031'] = gh.objects.pop('/pulls/100')
    body = json.loads((Path(__file__).parent / "fixtures/pr3031-owner-attestation.json").read_text())["body"]
    gh.objects['/issues/comments/6107609332'] = {"body": body,
        "user": {"type": "User", "login": "valzargaming"},
        "issue_url": "https://api.github.com/repos/Civ13/Civ13/issues/3031"}
    imported = dict(source, **run, path=h.WORKFLOW_PATH, head_branch="master", event="workflow_dispatch")
    gh.objects['/actions/runs/10'] = imported
    gh.objects['/actions/workflows/youtube-prepare-import.yml'] = {
        "id": 77, "path": h.WORKFLOW_PATH, "state": "active"}
    artifact = gh.objects['/actions/artifacts/2']
    artifact.update(name=h.ARTIFACT_NAME, size_in_bytes=500, digest="sha256:" + "a" * 64)
    artifact['workflow_run'].update(id=10, head_sha="b" * 40)
    attempt = gh.objects.pop('/actions/runs/1/attempts/1')
    attempt['head_sha'] = "b" * 40
    gh.objects['/actions/runs/10/attempts/1'] = attempt
    gh.objects['/actions/runs/10/artifacts?per_page=10'] = {"total_count": 1, "artifacts": [artifact]}
    return p, m, gh


class HistoricalImportTests(unittest.TestCase):
    def test_exact_owner_approval_and_separate_source_packaging_provenance(self):
        p, m, gh = pilot()
        u.validate_manifest(m, p)
        u.validate_provenance(gh, m, p)
        self.assertEqual(u.approval_hash(m), u.PILOT_APPROVAL_DIGEST)
        evidence = u.expected_evidence(m)
        self.assertEqual(evidence['source_ci_run_id'], 38127733413)
        self.assertEqual(evidence['packaging_run_id'], 10)
        self.assertIn('CI did not record', evidence['capture_provenance'])
        self.assertNotEqual(evidence['tested_commit'], evidence['packaging_commit'])

    def test_prior_approval_cannot_authorize_changed_media_metadata_visibility_or_context(self):
        for section, field, value in [('metadata', 'title', 'A different approved-looking title'),
                ('metadata', 'description', 'Another description is not the approved description.'),
                ('clip', 'sha256', 'c' * 64), ('review', 'known_limits', 'Claims completed multiplayer acceptance.'),
                ('source', 'owner', 'another-user'), ('approval', 'authorization_id', 'made-up-approval')]:
            p, m, gh = pilot()
            m[section][field] = value
            with self.subTest(section=section, field=field), self.assertRaises(u.Refused):
                u.validate_manifest(m, p)
        for privacy in ('unlisted', 'private'):
            p, m, gh = pilot()
            m['privacy'] = privacy
            with self.assertRaises(u.Refused):
                u.validate_manifest(m, p)

    def test_import_run_cannot_be_pr_fork_old_commit_failed_or_other_workflow(self):
        for field, value in [('event', 'pull_request'), ('head_branch', 'some-pr'),
                ('head_repository', {'id': 999}), ('head_sha', 'c' * 40),
                ('conclusion', 'failure'), ('path', '.github/workflows/attacker.yml'), ('workflow_id', 999)]:
            p, m, gh = pilot()
            gh.objects['/actions/runs/10'][field] = value
            with self.subTest(field=field), self.assertRaises(u.Refused):
                u.validate_provenance(gh, m, p)

    def test_wrong_original_ci_or_mutated_owner_attestation_refused(self):
        for target, field, value in [(38127733413, 'head_sha', 'c' * 40),
                (38127733413, 'conclusion', 'failure')]:
            p, m, gh = pilot()
            gh.objects[f'/actions/runs/{target}'][field] = value
            with self.assertRaises(u.Refused):
                u.validate_provenance(gh, m, p)
        for field, value in [('body', 'Forged exact-head claim'),
                ('user', {'type': 'User', 'login': 'other-user'}),
                ('issue_url', 'https://api.github.com/repos/Civ13/Civ13/issues/3228')]:
            p, m, gh = pilot()
            gh.objects['/issues/comments/6107609332'][field] = value
            with self.assertRaises(u.Refused):
                u.validate_provenance(gh, m, p)

    def test_original_run_cannot_be_relabelled_as_artifact_packager(self):
        p, m, gh = pilot()
        gh.objects['/actions/artifacts/2']['workflow_run'].update(
            id=m['source']['run_id'], head_sha=m['source']['commit'])
        with self.assertRaises(u.Refused):
            u.validate_provenance(gh, m, p)

    def test_resolve_only_exact_current_trusted_importer_and_unique_artifact(self):
        p, m, gh = pilot()
        resolved_policy, resolved = h.resolve_pilot(gh, 10, 'b' * 40)
        self.assertEqual(resolved, m)
        with self.assertRaises(u.Refused):
            h.resolve_pilot(gh, 10, 'c' * 40)
        gh.objects['/actions/runs/10/artifacts?per_page=10']['artifacts'].append(
            copy.deepcopy(gh.objects['/actions/artifacts/2']))
        gh.objects['/actions/runs/10/artifacts?per_page=10']['total_count'] = 2
        with self.assertRaises(u.Refused):
            h.resolve_pilot(gh, 10, 'b' * 40)

    def test_known_pilot_receipt_readback_survives_expired_artifact_without_source_calls(self):
        p, m, gh = pilot()
        ledger = u.Ledger(gh)
        record = ledger.reserve(m, 100000)
        record.update(state='uploaded', video_id='abcdefghijk')
        ledger.save()
        gh.objects = {'': gh.objects['']}
        resolved_policy, resolved = h.resolve_pilot_receipt(gh, 10)
        self.assertEqual(resolved, m)
        gh.ledger['records'][u.receipt_key(m)]['state'] = 'uncertain'
        with self.assertRaises(u.Refused):
            h.resolve_pilot_receipt(gh, 10)

    def test_old_unlisted_or_missing_receipt_privacy_never_changes_visibility(self):
        p, m, gh = pilot()
        ledger = u.Ledger(gh)
        record = ledger.reserve(m, 100000)
        record.update(state='uploaded', video_id='abcdefghijk', privacy='unlisted')
        ledger.save()
        yt = FakeYT(gh)
        with self.assertRaises(u.Refused):
            u.publish(m, b'not-sent', u.Ledger(gh), yt, 100001)
        self.assertEqual(yt.calls, ['channel'])


class ImportTransportAndProbeTests(unittest.TestCase):
    def test_exact_attachment_only_with_no_credentials_on_redirect(self):
        raw = b'no-network-fixture' * 100
        url = 'https://github.com/user-attachments/assets/00000000-0000-0000-0000-000000000001'
        transport = FakeTransport([(302, {'Location': 'https://github-production-user-asset-ab123.s3.amazonaws.com/data'}, b''),
            (200, {'Content-Type': 'video/mp4'}, raw)])
        self.assertEqual(h.public_media(transport, url, len(raw), u.digest(raw)), raw)
        for args, kwargs in transport.calls:
            self.assertEqual(len(args), 2)
            self.assertNotIn('headers', kwargs)
        for bad in ('https://evil.invalid/clip.mp4', url + '?token=x', 'file:///etc/passwd'):
            with self.assertRaises(u.Refused):
                h.public_media(FakeTransport([]), bad, len(raw), u.digest(raw))

    def test_redirect_mime_size_and_hash_rejections_stop_without_retry(self):
        url = 'https://github.com/user-attachments/assets/00000000-0000-0000-0000-000000000001'
        for response in [(302, {'Location': 'https://evil.invalid/media'}, b''),
                (503, {}, b''), (200, {'Content-Type': 'text/html'}, b'x' * 1024),
                (200, {'Content-Type': 'video/mp4'}, b'x' * 1025),
                (200, {'Content-Type': 'video/mp4'}, b'y' * 1024)]:
            transport = FakeTransport([response])
            with self.assertRaises(u.Refused):
                h.public_media(transport, url, 1024, u.digest(b'x' * 1024))
            self.assertEqual(len(transport.calls), 1)

    def test_pinned_runner_parser_rejects_version_duration_resolution_and_non_avc(self):
        info = {'media': {'track': [{'@type': 'General', 'Format': 'MPEG-4', 'Duration': '41.000'},
            {'@type': 'Video', 'Format': 'AVC', 'Width': '1920', 'Height': '1032'}]}}
        def responses(value, version=b'MediaInfoLib - v24.01'):
            return [subprocess.CompletedProcess([], 0, version, b''),
                subprocess.CompletedProcess([], 0, u.canonical(value), b'')]
        with patch.object(u.subprocess, 'run', side_effect=responses(info)):
            u.probe_media(b'mocked-media', 41)
        for index, field, value in [(0, 'Duration', '41000'), (0, 'Format', 'Matroska'),
                (1, 'Width', '3840'), (1, 'Format', 'HEVC')]:
            bad = copy.deepcopy(info)
            bad['media']['track'][index][field] = value
            with patch.object(u.subprocess, 'run', side_effect=responses(bad)), self.assertRaises(u.Refused):
                u.probe_media(b'mocked-media', 41)
        with patch.object(u.subprocess, 'run', side_effect=responses(info, b'MediaInfoLib - v99.00')), self.assertRaises(u.Refused):
            u.probe_media(b'mocked-media', 41)


if __name__ == '__main__':
    unittest.main()
