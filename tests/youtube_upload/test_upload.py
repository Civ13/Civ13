"""Offline behavioral and adversarial contracts. Never uses a live OAuth grant."""
import base64
import copy
import importlib.util
import io
import json
from pathlib import Path
import stat
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("youtube_upload", ROOT / "tools/youtube/upload.py")
u = importlib.util.module_from_spec(spec)
spec.loader.exec_module(u)


def fixtures():
    policy = json.loads((ROOT / "tools/youtube/policy.example.json").read_text())
    policy.update(approvers=["reviewer"], producers=[{
        "workflow_id": 42, "workflow_path": ".github/workflows/gameplay-capture.yml"}])
    clip = b"\x00\x00\x00\x20ftypisom" + b"x" * 1024
    evidence = {"schema_version": 1, "tested_commit": "a" * 40, "run_id": 1, "run_attempt": 1,
                "clip_sha256": u.digest(clip), "result": "success", "classification": "genuine-gameplay"}
    raw = bundle(clip, evidence)
    manifest = {"schema_version": 1, "repository": u.REPO, "channel_handle": u.HANDLE,
        "channel_id": u.CHANNEL, "privacy": "unlisted",
        "source": {"run_id": 1, "run_attempt": 1, "workflow_id": 42,
            "workflow_path": ".github/workflows/gameplay-capture.yml", "event": "pull_request",
            "head_branch": "test-branch", "commit": "a" * 40, "pr": 100, "owner": "capture-owner"},
        "artifact": {"id": 2, "name": "gameplay-video-example", "archive_sha256": u.digest(raw), "bytes": len(raw)},
        "clip": {"path": "gameplay.mp4", "sha256": u.digest(clip), "bytes": len(clip),
                 "duration_seconds": 19.1, "content_type": "video/mp4"},
        "metadata": {"title": "Civ13 movement test", "description": "Reviewed isolated movement example and its limitations.",
                     "made_for_kids": False, "contains_synthetic_media": False},
        "review": {"classification": "genuine-gameplay", "reproduction": "Describe actual movement steps here.",
                   "capture_context": "Actual client captured by source owner.",
                   "known_limits": "No full server or latency acceptance.",
                   "content_review": "Entire real clip reviewed for private content."},
        "approval": {"issue_number": 100, "comment_id": 123}}
    return policy, manifest, clip, raw, evidence


def bundle(clip, evidence, extra=None, video_name="gameplay.mp4", symlink=False):
    raw = io.BytesIO()
    with zipfile.ZipFile(raw, "w") as z:
        entry = zipfile.ZipInfo(video_name)
        if symlink:
            entry.create_system, entry.external_attr = 3, (stat.S_IFLNK | 0o777) << 16
        z.writestr(entry, clip)
        z.writestr("evidence.json", u.canonical(evidence))
        if extra:
            z.writestr(*extra)
    return raw.getvalue()


class FakeTransport:
    def __init__(self, responses):
        self.responses, self.calls = list(responses), []

    def request(self, *args, **kwargs):
        self.calls.append((args, kwargs))
        response = self.responses.pop(0)
        if isinstance(response, Exception):
            raise response
        return response


def response(value, status=200, headers=None):
    return status, headers or {}, u.canonical(value)


class FakeGH:
    def __init__(self, manifest, failure_at_save=None):
        self.m, self.saves, self.failure_at_save = manifest, [], failure_at_save
        self.ledger = {"schema_version": 1, "channel_id": u.CHANNEL, "imports_complete": True, "records": {}}
        self.objects = {
            "": {"id": u.REPO_ID, "full_name": u.REPO, "visibility": "public", "default_branch": "master"},
            "/actions/runs/1": {"id": 1, "repository": {"id": u.REPO_ID}, "head_repository": {"id": u.REPO_ID},
                "status": "completed", "conclusion": "success", "run_attempt": 1, "workflow_id": 42,
                "path": manifest["source"]["workflow_path"], "head_sha": "a" * 40,
                "head_branch": "test-branch", "event": "pull_request", "pull_requests": [{"number": 100}]},
            "/pulls/100": {"base": {"repo": {"id": u.REPO_ID}}, "head": {"repo": {"id": u.REPO_ID}}},
            "/actions/artifacts/2": {"id": 2, "name": manifest["artifact"]["name"], "expired": False,
                "size_in_bytes": manifest["artifact"]["bytes"],
                "digest": "sha256:" + manifest["artifact"]["archive_sha256"],
                "workflow_run": {"id": 1, "head_sha": "a" * 40,
                    "repository_id": u.REPO_ID, "head_repository_id": u.REPO_ID},
                "created_at": "2026-10-20T12:01:00Z"},
            "/actions/runs/1/attempts/1": {"run_attempt": 1, "conclusion": "success", "status": "completed",
                "head_sha": "a" * 40, "run_started_at": "2026-10-20T12:00:00Z", "updated_at": "2026-10-20T12:02:00Z"},
            "/issues/comments/123": {"user": {"login": "reviewer", "type": "User"},
                "issue_url": "https://api.github.com/repos/Civ13/Civ13/issues/100", "body": u.approval_text(manifest),
                "created_at": "2026-10-20T12:05:00Z", "updated_at": "2026-10-20T12:05:00Z"}}

    def repo(self, path, method="GET", value=None):
        if path.startswith("/contents/"):
            if method == "GET":
                raw = u.canonical(self.ledger)
                return {"sha": "ledger-sha", "encoding": "base64", "size": len(raw),
                        "content": base64.b64encode(raw).decode()}
            if self.failure_at_save == len(self.saves) + 1:
                raise u.Refused("CAS write uncertain")
            self.ledger = u.parse_json(base64.b64decode(value["content"]))
            self.saves.append(copy.deepcopy(self.ledger))
            return {"content": {"sha": "next-sha"}}
        return copy.deepcopy(self.objects[path])


class FakeYT:
    def __init__(self, gh, upload_error=None, verify_error=None, wrong_channel=False):
        self.gh, self.calls = gh, []
        self.upload_error, self.verify_error, self.wrong_channel = upload_error, verify_error, wrong_channel

    def channel(self):
        self.calls.append("channel")
        if self.wrong_channel:
            raise u.Refused("Wrong channel")

    def upload(self, m, clip):
        self.calls.append("upload")
        assert len(self.gh.saves) == 1
        assert next(iter(self.gh.ledger["records"].values()))["state"] == "reserved"
        if self.upload_error:
            raise self.upload_error
        return "abcdefghijk"

    def verify(self, video_id):
        self.calls.append("verify")
        if self.verify_error:
            raise self.verify_error


class ManifestTests(unittest.TestCase):
    def setUp(self):
        self.p, self.m, self.clip, self.raw, self.evidence = fixtures()

    def test_valid_and_default_policy_cannot_enable_upload(self):
        u.validate_policy(self.p)
        u.validate_manifest(self.m, self.p)
        with self.assertRaises(u.Refused):
            u.validate_policy(json.loads((ROOT / "tools/youtube/policy.example.json").read_text()))

    def test_destination_visibility_and_metadata_override_refused(self):
        for field, value in (("channel_id", "other"), ("privacy", "public"), ("privacy", "private")):
            m = copy.deepcopy(self.m)
            m[field] = value
            with self.subTest(field=field, value=value), self.assertRaises(u.Refused):
                u.validate_manifest(m, self.p)
        for field, value in (("title", "::error::\nInjected"), ("description", "<script>"), ("publishAt", "tomorrow")):
            m = copy.deepcopy(self.m)
            m["metadata"][field] = value
            with self.subTest(field=field), self.assertRaises(u.Refused):
                u.validate_manifest(m, self.p)

    def test_metadata_or_media_changes_require_new_human_approval(self):
        before = u.approval_hash(self.m)
        for area, field, value in (("metadata", "title", "Different title"),
                ("clip", "sha256", "b" * 64), ("review", "known_limits", "Changed known limitations.")):
            m = copy.deepcopy(self.m)
            m[area][field] = value
            self.assertNotEqual(before, u.approval_hash(m))

    def test_duplicate_json_and_nonfinite_numbers_refused(self):
        for raw in (b'{"a":1,"a":2}', b'{"duration":NaN}', b'{"duration":Infinity}'):
            with self.assertRaises(u.Refused):
                u.parse_json(raw)

    def test_no_live_dry_run(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "tools/youtube/approved").mkdir(parents=True)
            (root / "tools/youtube/policy.json").write_bytes(u.canonical(self.p))
            (root / "tools/youtube/approved/offline-example.json").write_bytes(u.canonical(self.m))
            with patch.object(sys, "argv", ["upload.py", "dry-run", "--manifest", "offline-example"]), \
                    patch.object(u, "__file__", str(root / "tools/youtube/upload.py")), \
                    patch.object(u, "Transport", side_effect=AssertionError("NO NETWORK")), \
                    patch.object(u, "PhpYouTube", side_effect=AssertionError("NO OAUTH")), \
                    patch.object(u, "publish", side_effect=AssertionError("NO UPLOAD")):
                u.main()

    def test_manifest_path_injection_and_absent_policy_refused(self):
        with tempfile.TemporaryDirectory() as folder:
            for name in ("../test", "$(whoami)", "test\nX=1", "/tmp/x", "safe-id"):
                with self.subTest(name=name), self.assertRaises(u.Refused):
                    u.load_inputs(Path(folder), name)


class ProvenanceTests(unittest.TestCase):
    def setUp(self):
        self.p, self.m, *_ = fixtures()
        self.gh = FakeGH(self.m)

    def test_exact_provenance_and_approval(self):
        u.validate_provenance(self.gh, self.m, self.p)

    def test_wrong_run_sha_attempt_workflow_fork_status_refused(self):
        for field, value in (("head_sha", "b" * 40), ("run_attempt", 2), ("workflow_id", 999),
                ("path", ".github/workflows/attacker.yml"), ("conclusion", "failure"),
                ("head_repository", {"id": 999}), ("event", "pull_request_target")):
            gh = FakeGH(self.m)
            gh.objects["/actions/runs/1"][field] = value
            with self.subTest(field=field), self.assertRaises(u.Refused):
                u.validate_provenance(gh, self.m, self.p)

    def test_artifact_old_attempt_expired_wrong_digest_or_run_refused(self):
        for field, value in (("created_at", "2026-10-20T11:59:00Z"), ("expired", True),
                ("digest", "sha256:" + "b" * 64), ("workflow_run", {"id": 1000})):
            gh = FakeGH(self.m)
            gh.objects["/actions/artifacts/2"][field] = value
            with self.subTest(field=field), self.assertRaises(u.Refused):
                u.validate_provenance(gh, self.m, self.p)

    def test_bot_unknown_approver_stale_or_wrong_issue_approval_refused(self):
        for field, value in (("body", "I approve"), ("issue_url", "https://evil.invalid/issues/100"),
                ("user", {"login": "reviewer", "type": "Bot"}),
                ("user", {"login": "stranger", "type": "User"})):
            gh = FakeGH(self.m)
            gh.objects["/issues/comments/123"][field] = value
            with self.subTest(field=field), self.assertRaises(u.Refused):
                u.validate_provenance(gh, self.m, self.p)

    def test_approval_edit_or_missing_timestamp_evidence_refused(self):
        for field, value in (("updated_at", "2026-10-20T12:06:00Z"),
                ("updated_at", None), ("created_at", None), ("created_at", "")):
            gh = FakeGH(self.m)
            gh.objects["/issues/comments/123"][field] = value
            with self.subTest(field=field), self.assertRaises(u.Refused):
                u.validate_approval(gh, self.m, self.p)


class ArtifactTests(unittest.TestCase):
    def setUp(self):
        self.p, self.m, self.clip, self.raw, self.evidence = fixtures()

    def inspect(self, raw):
        self.m["artifact"].update(bytes=len(raw), archive_sha256=u.digest(raw))
        return u.inspect_archive(raw, self.m)

    def test_exact_flat_bundle(self):
        self.assertEqual(self.inspect(self.raw), self.clip)

    def test_path_traversal_absolute_backslash_duplicate_extra_symlink_refused(self):
        for name in ("../gameplay.mp4", "/gameplay.mp4", "C:\\gameplay.mp4", "nested/gameplay.mp4"):
            with self.subTest(name=name), self.assertRaises(u.Refused):
                self.inspect(bundle(self.clip, self.evidence, video_name=name))
        for kwargs in ({"extra": ("payload.sh", "execute me")}, {"extra": ("evidence.json", "{}")}, {"symlink": True}):
            with self.subTest(kwargs=kwargs), self.assertRaises(u.Refused):
                self.inspect(bundle(self.clip, self.evidence, **kwargs))

    def test_tampered_archive_media_evidence_refused(self):
        with self.assertRaises(u.Refused):
            u.inspect_archive(self.raw + b"x", self.m)
        with self.assertRaises(u.Refused):
            self.inspect(bundle(b"bad" * 400, self.evidence))
        evidence = dict(self.evidence, tested_commit="b" * 40)
        with self.assertRaises(u.Refused):
            self.inspect(bundle(self.clip, evidence))

    def test_expanded_cap_before_read(self):
        with patch.object(u, "MAX_CLIP", 1000), self.assertRaises(u.Refused):
            self.inspect(self.raw)

    def test_signed_download_never_forwards_authorization(self):
        transport = FakeTransport([(302, {"Location": "https://example.blob.core.windows.net/signed"}, b""),
            (200, {"Content-Type": "application/zip"}, self.raw)])
        self.assertEqual(u.GitHub(transport, "github-credential").archive(2), self.raw)
        args, kwargs = transport.calls[1]
        self.assertEqual(args[:2], ("GET", "https://example.blob.core.windows.net/signed"))
        self.assertEqual(len(args), 2)

    def test_signed_download_host_and_content_type_refused(self):
        for url in ("http://example.blob.core.windows.net/x", "https://evil.invalid/x",
                    "https://api.github.com/x", "https://a.blob.core.windows.net.evil.invalid/x"):
            transport = FakeTransport([(302, {"Location": url}, b"")])
            with self.subTest(url=url), self.assertRaises(u.Refused):
                u.GitHub(transport, "credential").archive(2)
            self.assertEqual(len(transport.calls), 1)
        transport = FakeTransport([(302, {"Location": "https://a.blob.core.windows.net/x"}, b""),
            (200, {"Content-Type": "text/html"}, b"oops")])
        with self.assertRaises(u.Refused):
            u.GitHub(transport, "credential").archive(2)


class ReceiptTests(unittest.TestCase):
    def setUp(self):
        self.p, self.m, self.clip, *_ = fixtures()
        self.gh = FakeGH(self.m)

    def test_reservation_precedes_upload_and_success_requires_verification(self):
        yt = FakeYT(self.gh)
        url = u.publish(self.m, self.clip, u.Ledger(self.gh), yt, 100000)
        self.assertEqual(url, "https://youtu.be/abcdefghijk")
        self.assertEqual([next(iter(save["records"].values()))["state"] for save in self.gh.saves],
                         ["reserved", "uploaded", "verified"])
        self.assertEqual(yt.calls, ["channel", "upload", "verify"])

    def test_wrong_channel_never_reserves_or_uploads(self):
        yt = FakeYT(self.gh, wrong_channel=True)
        with self.assertRaises(u.Refused):
            u.publish(self.m, self.clip, u.Ledger(self.gh), yt, 100000)
        self.assertEqual(self.gh.saves, [])

    def test_reservation_write_failure_prevents_external_mutation(self):
        self.gh.failure_at_save = 1
        yt = FakeYT(self.gh)
        with self.assertRaises(u.Refused):
            u.publish(self.m, self.clip, u.Ledger(self.gh), yt, 100000)
        self.assertEqual(yt.calls, ["channel"])

    def test_uncertain_upload_blocks_retry_even_if_commit_or_metadata_changes(self):
        yt = FakeYT(self.gh, upload_error=u.Refused("connection lost"))
        with self.assertRaises(u.Refused):
            u.publish(self.m, self.clip, u.Ledger(self.gh), yt, 100000)
        changed = copy.deepcopy(self.m)
        changed["source"]["commit"] = "b" * 40
        changed["metadata"]["title"] = "Rename attempt"
        retry = FakeYT(self.gh)
        with self.assertRaises(u.Refused):
            u.publish(changed, self.clip, u.Ledger(self.gh), retry, 100001)
        self.assertEqual(retry.calls, ["channel"])

    def test_failed_video_id_persistence_keeps_durable_reservation(self):
        self.gh.failure_at_save = 2
        with self.assertRaises(u.Refused):
            u.publish(self.m, self.clip, u.Ledger(self.gh), FakeYT(self.gh), 100000)
        self.assertNotIn("video_id", next(iter(self.gh.ledger["records"].values())))
        with self.assertRaises(u.Refused):
            u.publish(self.m, self.clip, u.Ledger(self.gh), FakeYT(self.gh), 100001)

    def test_processing_pending_retries_only_readback(self):
        with self.assertRaises(u.Refused):
            u.publish(self.m, self.clip, u.Ledger(self.gh),
                      FakeYT(self.gh, verify_error=u.Refused("pending")), 100000)
        retry = FakeYT(self.gh)
        u.publish(self.m, self.clip, u.Ledger(self.gh), retry, 100001)
        self.assertEqual(retry.calls, ["channel", "verify"])

    def test_unreconciled_imports_and_two_per_day_cap(self):
        self.gh.ledger["imports_complete"] = False
        with self.assertRaises(u.Refused):
            u.Ledger(self.gh)
        self.gh.ledger["imports_complete"] = True
        ledger = u.Ledger(self.gh)
        for i in range(2):
            m = copy.deepcopy(self.m)
            m["clip"]["sha256"] = str(i) * 64
            ledger.reserve(m, 100000)
        with self.assertRaises(u.Refused):
            ledger.reserve(self.m, 100001)

    def test_imported_uncertain_oneoff_remains_blocked_even_with_video_id(self):
        self.gh.ledger = json.loads((ROOT / "tools/youtube/ledger.example.json").read_text())
        self.gh.ledger["imports_complete"] = True
        record = next(iter(self.gh.ledger["records"].values()))
        record["video_id"] = "abcdefghijk"
        self.m["clip"]["sha256"] = record["clip_sha256"]
        yt = FakeYT(self.gh)
        with self.assertRaises(u.Refused):
            u.publish(self.m, self.clip, u.Ledger(self.gh), yt, 100000)
        self.assertEqual(yt.calls, ["channel"])

    def test_ledger_record_cap_never_prunes_history(self):
        ledger = u.Ledger(self.gh)
        record = {"channel_id": u.CHANNEL, "state": "verified", "reserved_at": 1,
                  "clip_sha256": "b" * 64, "commit": "b" * 40}
        ledger.data["records"] = {format(i, "064x"): dict(record) for i in range(1000)}
        with self.assertRaises(u.Refused):
            ledger.reserve(self.m, 100000)
        self.assertEqual(len(ledger.data["records"]), 1000)


class PhpBridgeTests(unittest.TestCase):
    def test_subprocess_failure_redacts_raw_service_errors(self):
        result = u.subprocess.CompletedProcess([], 1, b"secret-token", b"private-auth-url")
        with patch.object(u.subprocess, "run", return_value=result), self.assertRaises(u.Refused) as error:
            u.PhpYouTube().channel()
        self.assertNotIn("secret-token", str(error.exception))
        self.assertNotIn("private-auth", str(error.exception))

    def test_timeout_is_uncertain_and_not_retried(self):
        with patch.object(u.subprocess, "run", side_effect=u.subprocess.TimeoutExpired([], 240)) as run:
            with self.assertRaises(u.Refused):
                u.PhpYouTube().channel()
            self.assertEqual(run.call_count, 1)

    def test_media_bridge_has_no_shell_and_removes_temporary_clip(self):
        _, manifest, clip, *_ = fixtures()
        paths = []
        def run(args, **kwargs):
            self.assertEqual(args[0], "php")
            self.assertNotIn("shell", kwargs)
            payload = json.loads(kwargs["input"])
            path = Path(payload["media_path"])
            self.assertEqual(path.read_bytes(), clip)
            paths.append(path)
            return u.subprocess.CompletedProcess(args, 0, b'{"video_id":"abcdefghijk"}', b"")
        with patch.object(u.subprocess, "run", side_effect=run):
            self.assertEqual(u.PhpYouTube().upload(manifest, clip), "abcdefghijk")
        self.assertFalse(paths[0].exists())


class WorkflowTests(unittest.TestCase):
    def test_verification_only_flag_reaches_both_trusted_jobs(self):
        wrapper = (ROOT / '.github/workflows/youtube-upload.yml').read_text()
        worker = (ROOT / '.github/workflows/youtube-upload-worker.yml').read_text()
        self.assertIn('verify_only: ${{ inputs.verify_only }}', wrapper)
        self.assertEqual(worker.count('VERIFY_ONLY: ${{ inputs.verify_only }}'), 2)

    def test_framework_lock_is_pinned_and_portable(self):
        lock = json.loads((ROOT / 'tools/youtube/composer.lock').read_text())
        framework = next(p for p in lock['packages'] if p['name'] == 'vzgcoders/youtubephp')
        self.assertEqual(framework['source']['reference'], '7ce9b24eb26a32af7ffcd4936d8083c06a428fb0')
        for package in lock['packages']:
            self.assertEqual(package['dist']['type'], 'zip')
            self.assertRegex(package['source']['reference'], r'^[0-9a-f]{40}$')
            self.assertEqual(package['dist']['reference'], package['source']['reference'])
        self.assertNotIn('D:/', json.dumps(lock))

    def test_secret_job_never_executes_pr_scripts_or_media_decoder(self):
        workflow = (ROOT / ".github/workflows/youtube-upload-worker.yml").read_text()
        inspect, upload = workflow.split("\n  upload:\n")
        self.assertNotIn("secrets.", inspect)
        self.assertNotIn("ffprobe", upload)
        self.assertNotIn("pull_request.head", workflow)
        self.assertNotIn("secrets: inherit", workflow)
        self.assertEqual(workflow.count("ref: ${{ github.sha }}"), 2)
        self.assertIn("environment: youtube-unlisted", upload)
        self.assertIn("contents: read", inspect)
        self.assertIn("contents: write", upload)
        self.assertNotIn("workflow_run:", workflow)
        self.assertNotIn("schedule:", workflow)
        for line in workflow.splitlines():
            if "uses: actions/" in line:
                self.assertRegex(line, r"@[0-9a-f]{40}")


class VerificationOnlyMainTests(unittest.TestCase):
    def setUp(self):
        self.p, self.m, *_ = fixtures()
        self.gh = FakeGH(self.m)
        self.record = {"channel_id": u.CHANNEL, "clip_sha256": self.m["clip"]["sha256"],
            "commit": self.m["source"]["commit"], "reserved_at": 100000,
            "state": "uploaded", "video_id": "abcdefghijk"}
        self.gh.ledger["records"][u.receipt_key(self.m)] = self.record
        # These formerly made both main/workflow stages fail before readback.
        self.gh.objects['/actions/artifacts/2']['expired'] = True
        self.gh.objects['/actions/runs/1']['run_attempt'] = 2

    def run_main(self, mode, youtube):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'tools/youtube/approved').mkdir(parents=True)
            (root / 'tools/youtube/policy.json').write_bytes(u.canonical(self.p))
            (root / 'tools/youtube/approved/offline-example.json').write_bytes(u.canonical(self.m))
            env = {'GITHUB_REPOSITORY': u.REPO, 'GITHUB_REF': 'refs/heads/master',
                'GITHUB_EVENT_NAME': 'workflow_dispatch', 'GITHUB_TOKEN': 'OFFLINE-FAKE',
                'GITHUB_WORKFLOW_REF': u.REPO + '/.github/workflows/youtube-upload.yml@refs/heads/master',
                'VERIFY_ONLY': 'true', 'YOUTUBE_UPLOAD_ENABLED': 'true',
                'YOUTUBE_UPLOAD_STOP_USE': 'false', 'YOUTUBE_ZERO_COST_CONFIRMED': 'true'}
            with patch.object(sys, 'argv', ['upload.py', mode, '--manifest', 'offline-example']), \
                    patch.object(u, '__file__', str(root / 'tools/youtube/upload.py')), \
                    patch.dict(u.os.environ, env, clear=True), \
                    patch.object(u, 'GitHub', return_value=self.gh), \
                    patch.object(u, 'Transport', side_effect=lambda: object()), \
                    patch.object(u, 'PhpYouTube', side_effect=youtube), \
                    patch.object(u, 'validate_provenance', side_effect=AssertionError('NO SOURCE DEPENDENCY')), \
                    patch.object(u, 'inspect_archive', side_effect=AssertionError('NO MEDIA')), \
                    patch.object(u, 'probe_media', side_effect=AssertionError('NO DECODER')), \
                    patch.object(u, 'publish', side_effect=AssertionError('NO INSERT PATH')):
                u.main()

    def test_inspect_receipt_survives_expired_artifact_and_producer_rerun_without_oauth(self):
        def no_oauth():
            raise AssertionError('Inspection must not touch OAuth')
        self.run_main('inspect', no_oauth)
        self.assertEqual(self.gh.saves, [])

    def test_execute_only_verifies_known_id_without_upload_or_media(self):
        youtube = FakeYT(self.gh)
        self.run_main('upload', lambda: youtube)
        self.assertEqual(youtube.calls, ['channel', 'verify'])
        self.assertEqual(len(self.gh.saves), 1)
        self.assertEqual(next(iter(self.gh.saves[0]['records'].values()))['state'], 'verified')

    def test_unknown_or_uncertain_receipt_stops_before_oauth(self):
        for state, video_id in [('reserved', None), ('uncertain', 'abcdefghijk'), ('uploaded', None)]:
            with self.subTest(state=state, video_id=video_id):
                self.record['state'] = state
                self.record.pop('video_id', None)
                if video_id:
                    self.record['video_id'] = video_id
                with self.assertRaises(u.Refused):
                    self.run_main('upload', lambda: self.fail('No OAuth for uncertain receipt'))


if __name__ == "__main__":
    unittest.main()
