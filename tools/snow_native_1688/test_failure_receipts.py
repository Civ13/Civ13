"""Mock-only integration of failed helper receipts into runner evidence."""
import copy
import json
from unittest.mock import patch

import owned_process_1688 as owned
import run
from test_review_controls import OfflineCase, IDENTITY


class FailureReceiptTests(OfflineCase):
    def exercise(self, receipt, notify_started=False):
        output = self.temp / "output"
        source = output / "cases/baseline/source"
        source.mkdir(parents=True)
        summary = run.initial_summary()
        prepared = {"source_authentication": "clean-git", "controller_sha256": {}}
        original = ValueError("synthetic inventory failure")
        def fake_bounded(command, work, log, wall, cap, env, profile, sample, started):
            if notify_started:
                started(41001, None)
            raise owned.BoundedProcessError(original, copy.deepcopy(receipt))
        with patch.object(run, "MODES", ("baseline",)), \
                patch.object(run, "binaries", return_value={}), \
                patch.object(run, "controller_hashes", return_value={}), \
                patch.object(run, "verify_fixture"), \
                patch.object(run, "run_bounded", side_effect=fake_bounded) as bounded:
            with self.assertRaises(owned.BoundedProcessError) as raised:
                run.run_native(output, prepared, self.temp, self.temp / "archive", summary)
        self.assertIs(raised.exception.original_error, original)
        self.assertEqual(bounded.call_count, 1)
        self.assertFalse(summary["compiler_completed"])
        self.assertFalse(summary["daemon_attempted"])
        self.assertEqual(summary["compiler_completed_phases"], 0)
        self.assertFalse(summary["phases"][0]["completed"])
        persisted = json.loads((source / "compile-process.json").read_text())
        for key, value in receipt.items():
            self.assertEqual(persisted[key], value)
        self.assertEqual(json.loads((output / "result.json").read_text()), summary)
        return summary, persisted

    def receipt(self, verified=True):
        return {"process_started": True, "pid": 41001,
                "termination_observed": True, "leader_reaped": True, "exit_code": -9,
                "owned_leader_identity": IDENTITY, "cleanup_verified": verified,
                "cleanup_no_observed_live_descendants": verified,
                "cleanup_process_group_absent": verified,
                "owned_final_states": [{"pid": 41001, "state": "absent_or_reused"}],
                "signal_events": [{"signal": 9, "outcome": "sent"}],
                "cleanup_errors": [] if verified else [{"stage": "cleanup_wait", "message": "synthetic timeout"}],
                "controller_error": {"stage": "on_sample", "message": "synthetic inventory failure"}}

    def test_failed_callback_keeps_verified_cleanup_but_cannot_complete(self):
        summary, persisted = self.exercise(self.receipt(), notify_started=True)
        self.assertTrue(persisted["cleanup_verified"])
        self.assertTrue(summary["phases"][0]["terminated"])
        self.assertTrue(summary["compiler_started"])
        self.assertTrue(summary["native_executed"])

    def test_failed_cleanup_keeps_error_and_unknown_result(self):
        receipt = self.receipt(False)
        receipt.update(termination_observed=False, leader_reaped=False, exit_code=None)
        summary, persisted = self.exercise(receipt, notify_started=True)
        self.assertFalse(persisted["cleanup_verified"])
        self.assertFalse(summary["phases"][0]["terminated"])
        self.assertEqual(len(persisted["cleanup_errors"]), 1)

    def test_helper_start_receipt_recovers_failed_start_callback_evidence(self):
        summary, _ = self.exercise(self.receipt(), notify_started=False)
        self.assertTrue(summary["compiler_started"])
        self.assertTrue(summary["native_executed"])
        self.assertEqual(summary["phases"][0]["pid"], 41001)
        self.assertEqual(summary["phases"][0]["owned_identity"], IDENTITY)

    def test_before_spawn_failure_stays_unstarted_and_unverified(self):
        receipt = {"process_started": False, "pid": None, "termination_observed": False,
                   "exit_code": None, "cleanup_verified": False,
                   "owned_leader_identity": None, "signal_events": [], "cleanup_errors": []}
        summary, _ = self.exercise(receipt)
        self.assertFalse(summary["compiler_started"])
        self.assertFalse(summary["native_executed"])
        self.assertFalse(summary["phases"][0]["terminated"])
