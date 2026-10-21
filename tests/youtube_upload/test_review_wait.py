"""Review admission/execution tests with fake clocks and services; no live calls."""
import importlib.util
import os
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

from test_deferred import d, u
from test_upload import fixtures, FakeGH, FakeYT

spec = importlib.util.spec_from_file_location("review_wait", Path(u.__file__).with_name("review_wait.py"))
r = importlib.util.module_from_spec(spec)
sys.modules["review_wait"] = r
spec.loader.exec_module(r)
CREATED = r.stamp("2026-10-21T12:00:00Z")
DEADLINE = CREATED + r.REVIEW_SECONDS


class Reader:
    def __init__(self):
        self.values = {scope: {"YOUTUBE_UPLOAD_ENABLED": "false", "YOUTUBE_UPLOAD_STOP_USE": "true",
            "YOUTUBE_ZERO_COST_CONFIRMED": "false"} for scope in ("repository", "environment")}
        self.values["repository"].update(YOUTUBE_DEFERRED_ENABLED="false", YOUTUBE_DEFERRED_ARMED_UNTIL="0")
        self.updated = "2026-10-21T19:59:00Z"
        self.reads = []

    def variables(self, scope):
        self.reads.append(scope)
        return self.values[scope].copy()

    def metadata(self, scope, name):
        return {"name": name, "value": self.values[scope][name], "updated_at": self.updated}

    def arm(self, until):
        for scope in self.values:
            self.values[scope].update(YOUTUBE_UPLOAD_ENABLED="true", YOUTUBE_UPLOAD_STOP_USE="false",
                                      YOUTUBE_ZERO_COST_CONFIRMED="true")
        self.values["repository"].update(YOUTUBE_DEFERRED_ENABLED="true", YOUTUBE_DEFERRED_ARMED_UNTIL=str(until))


class ReviewTests(unittest.TestCase):
    def setUp(self):
        self.env = {"REVIEW_HOURS": "8", "GITHUB_REPOSITORY": u.REPO, "GITHUB_REF": "refs/heads/master",
            "GITHUB_EVENT_NAME": "workflow_dispatch", "GITHUB_RUN_ATTEMPT": "1", "GITHUB_RUN_ID": "42",
            "GITHUB_WORKFLOW_REF": u.REPO + "/.github/workflows/youtube-upload.yml@refs/heads/master",
            "GITHUB_SHA": "b" * 40}
        _, m, *_ = fixtures()
        self.gh = FakeGH(m)
        self.run = {"id": 42, "repository": {"id": u.REPO_ID}, "event": "workflow_dispatch",
            "head_branch": "master", "path": ".github/workflows/youtube-upload.yml", "run_attempt": 1,
            "display_title": r.TITLE, "head_sha": "b" * 40, "created_at": "2026-10-21T12:00:00Z"}
        self.run.update(status="in_progress", conclusion=None)
        self.gh.objects.update({"/actions/runs/42": self.run, "/commits/master": {"sha": "b" * 40}})
        self.context = patch.dict(os.environ, self.env, clear=True)
        self.context.start()
        self.addCleanup(self.context.stop)

    def test_eight_hour_admission_boundary_and_late_runner_fail_closed(self):
        self.assertEqual(r.request(self.gh, DEADLINE - 1), DEADLINE)
        for now in (CREATED - 1, DEADLINE, DEADLINE + 1):
            with self.assertRaises(u.Refused):
                r.request(self.gh, now)
        self.assertEqual(r.request(self.gh, DEADLINE + 100, admission=False), DEADLINE)

    def test_rerun_other_workflow_source_move_queue_claim_and_verify_rejected(self):
        for field, value in (("run_attempt", 2), ("head_sha", "a" * 40), ("display_title", "Other"),
                             ("path", ".github/workflows/other.yml"), ("status", "completed"),
                             ("conclusion", "cancelled")):
            with patch.dict(self.run, {field: value}), self.assertRaises(u.Refused):
                r.request(self.gh, CREATED)
        self.gh.objects["/commits/master"] = {"sha": "a" * 40}
        with self.assertRaises(u.Refused):
            r.request(self.gh, CREATED)
        self.gh.objects["/commits/master"] = {"sha": "b" * 40}
        for field, value in (("DEFERRED_ID", "a" * 64), ("DEFERRED_TOKEN", "b" * 64),
                             ("GITHUB_RUN_ATTEMPT", "2"), ("VERIFY_ONLY", "true")):
            with patch.dict(os.environ, {field: value}), self.assertRaises(u.Refused):
                r.request(self.gh, CREATED)

    def test_artifact_coverage_requires_exact_pinned_bytes_for_full_review(self):
        _, manifest, *_ = fixtures()
        minimum = DEADLINE + r.HANDOFF_SECONDS + r.EXECUTION_SECONDS + r.ARTIFACT_MARGIN
        item = {"id": 2, "name": manifest["artifact"]["name"], "digest": "sha256:" + manifest["artifact"]["archive_sha256"],
            "expired": False, "expires_at": "2026-10-21T20:22:00Z"}
        self.assertEqual(r.stamp(item["expires_at"]), minimum)
        self.gh.objects["/actions/artifacts/2"] = item
        r.artifact_coverage(self.gh, manifest, DEADLINE)
        for field, value in (("expires_at", "2026-10-21T20:21:59Z"), ("expired", True),
                             ("id", 3), ("digest", "sha256:" + "f" * 64)):
            with patch.dict(item, {field: value}), self.assertRaises(u.Refused):
                r.artifact_coverage(self.gh, manifest, DEADLINE)

    def test_closed_baseline_then_new_short_arm_in_same_job(self):
        reader, clock = Reader(), [DEADLINE - 60]
        reader.updated = "2026-10-21T19:59:05Z"
        def sleep(seconds):
            clock[0] += seconds
            reader.arm(clock[0] + 600)
        with patch("builtins.print"):
            result = r.await_arm(self.gh, reader, clock=lambda: clock[0], sleep=sleep)
        self.assertEqual(result, {"review_started_at": DEADLINE - 60, "review_deadline": DEADLINE,
                                  "execution_until": DEADLINE + 545})
        self.assertGreaterEqual(reader.reads.count("environment"), 3)

    def test_prearmed_request_and_stale_arm_and_missing_arm_refused(self):
        reader = Reader()
        reader.arm(DEADLINE + 500)
        with self.assertRaises(u.Refused):
            r.await_arm(self.gh, reader, clock=lambda: DEADLINE - 60)
        reader = Reader()
        clock = [DEADLINE - 60]
        def sleep(seconds):
            clock[0] += seconds
        with patch("builtins.print"), self.assertRaises(u.Refused):
            r.await_arm(self.gh, reader, clock=lambda: clock[0], sleep=sleep)
        self.assertEqual(clock[0], DEADLINE + 60)
        reader = Reader()
        clock[0] = DEADLINE - 60
        def stale(seconds):
            clock[0] += seconds
            reader.arm(DEADLINE + 500)
            reader.updated = "2026-10-21T19:58:59Z"
        with patch("builtins.print"), self.assertRaises(u.Refused):
            r.await_arm(self.gh, reader, clock=lambda: clock[0], sleep=stale)

    def execution(self):
        reader = Reader()
        reader.arm(DEADLINE + 500)
        os.environ.update(REVIEW_STARTED_AT=str(DEADLINE - 60), REVIEW_DEADLINE=str(DEADLINE),
                          REVIEW_EXECUTION_UNTIL=str(DEADLINE + 500), YOUTUBE_UPLOAD_ENABLED="false",
                          YOUTUBE_UPLOAD_STOP_USE="true", YOUTUBE_ZERO_COST_CONFIRMED="false")
        return reader

    def test_execution_uses_fresh_both_scope_values_despite_off_process_snapshots(self):
        reader = self.execution()
        r.execution_gate(self.gh, reader, clock=lambda: DEADLINE + 50)
        reader.values["environment"]["YOUTUBE_UPLOAD_STOP_USE"] = "true"
        with self.assertRaises(u.Refused):
            r.execution_gate(self.gh, reader, clock=lambda: DEADLINE + 51)

    def test_execution_expiry_rearm_changed_source_or_missing_handoff_refused(self):
        reader = self.execution()
        with self.assertRaises(u.Refused):
            r.execution_gate(self.gh, reader, clock=lambda: DEADLINE + 500)
        reader.arm(DEADLINE + 501)
        with self.assertRaises(u.Refused):
            r.execution_gate(self.gh, reader, clock=lambda: DEADLINE)
        reader = self.execution()
        del os.environ["REVIEW_STARTED_AT"]
        with self.assertRaises(u.Refused):
            r.execution_gate(self.gh, reader, clock=lambda: DEADLINE)

    def test_slow_control_reads_cannot_cross_handoff_or_execution_deadline(self):
        reader, clock = Reader(), [DEADLINE - 60]
        original = reader.variables
        calls = [0]
        def slow(scope):
            calls[0] += 1
            if calls[0] == 3:  # First poll after baseline.
                clock[0] += 121
                reader.updated = "2026-10-21T20:01:01Z"
                reader.arm(clock[0] + 500)
            return original(scope)
        reader.variables = slow
        with patch("builtins.print"), self.assertRaises(u.Refused):
            r.await_arm(self.gh, reader, clock=lambda: clock[0], sleep=lambda _: None)
        reader = self.execution()
        clock[0] = DEADLINE + 490
        original = reader.metadata
        def slow_metadata(scope, name):
            clock[0] += 11
            return original(scope, name)
        reader.metadata = slow_metadata
        with self.assertRaises(u.Refused):
            r.execution_gate(self.gh, reader, clock=lambda: clock[0])
    def test_expiry_cleanup_cancels_only_matching_expired_review_not_legacy(self):
        for status in ("queued", "in_progress", "waiting", "pending", "requested"):
            self.gh.objects[f"/actions/workflows/youtube-upload.yml/runs?branch=master&status={status}&per_page=100"] = {
                "total_count": 0, "workflow_runs": []}
        legacy = dict(self.run, id=43, display_title="Reviewed YouTube upload")
        self.gh.objects["/actions/workflows/youtube-upload.yml/runs?branch=master&status=waiting&per_page=100"] = {
            "total_count": 2, "workflow_runs": [self.run, legacy]}
        self.gh.objects["/actions/runs/42/jobs?per_page=100"] = {"total_count": 1, "jobs": [
            {"name": "approved-upload / upload", "steps": []}]}
        with patch.object(r, "cancel_overdue_run") as cancel, patch("builtins.print"):
            r.expire(self.gh, DEADLINE - 1)
            cancel.assert_not_called()
            r.expire(self.gh, DEADLINE)
            cancel.assert_called_once_with(self.gh, 42)

    def test_fresh_gate_failure_happens_before_reservation_or_media(self):
        _, manifest, clip, *_ = fixtures()
        gh = FakeGH(manifest)
        youtube = FakeYT(gh)
        def revoked():
            raise u.Refused("Owner approval revoked or stop closed")
        with self.assertRaises(u.Refused):
            u.publish(manifest, clip, u.Ledger(gh), youtube, CREATED, before_insert=revoked)
        self.assertEqual(gh.saves, [])
        self.assertNotIn("upload", youtube.calls)

    def test_arm_expiry_during_reservation_persistence_cannot_send_media(self):
        _, manifest, clip, *_ = fixtures()
        gh = FakeGH(manifest)
        youtube = FakeYT(gh)
        calls = [0]
        def gate():
            calls[0] += 1
            if calls[0] == 2:
                raise u.Refused("Arm expired during durable reservation")
            return CREATED
        with self.assertRaises(u.Refused):
            u.publish(manifest, clip, u.Ledger(gh), youtube, CREATED, before_insert=gate)
        self.assertEqual(len(gh.saves), 1)
        self.assertEqual(next(iter(gh.ledger["records"].values()))["state"], "reserved")
        self.assertNotIn("upload", youtube.calls)

    def test_workflow_wait_has_no_youtube_credentials_and_cleanup_has_no_secrets(self):
        root = Path(__file__).resolve().parents[2]
        worker = (root / ".github/workflows/youtube-upload-worker.yml").read_text()
        wait = worker.split("- name: Admit reviewed request")[1].split("- name: Reserve,")[0]
        for name in ("YOUTUBE_CLIENT_ID", "YOUTUBE_CLIENT_SECRET", "YOUTUBE_REFRESH_TOKEN", "secrets."):
            self.assertNotIn(name, wait)
        cleanup = (root / ".github/workflows/youtube-deferred.yml").read_text().split("  expire-review:")[1].split("  deferred:")[0]
        self.assertNotIn("secrets.", cleanup)
        self.assertNotIn("environment:", cleanup)
        self.assertNotIn("YOUTUBE_DEFERRED_ENABLED", cleanup)


if __name__ == "__main__":
    unittest.main()
