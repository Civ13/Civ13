"""Compiler-free launcher failure receipt regression."""
import copy
import json
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import run

class ExecutionReceipts(unittest.TestCase):
    def test_return_preserves_output_and_status(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            child = SimpleNamespace(stdout="out", stderr="err", returncode=7)
            with patch.object(run.subprocess, "run", return_value=child):
                self.assertIs(run.run_logged(["fixture"], root, "compile.log", 120, 0), child)
            self.assertEqual((root/"compile.log").read_text(), "outerr")
            receipt = json.loads((root/"compile-execution.json").read_text())
            self.assertEqual(receipt["returncode"], 7)
            self.assertEqual(receipt["state"], "returned")

    def test_timeout_preserves_partial_bytes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            error = subprocess.TimeoutExpired(["fixture"], 120, output=b"partial output", stderr=b"partial error")
            with patch.object(run.subprocess, "run", side_effect=error):
                with self.assertRaises(subprocess.TimeoutExpired):
                    run.run_logged(["fixture"], root, "daemon-child.log", 120, 0)
            self.assertEqual((root/"daemon-child.log").read_text(), "partial outputpartial error")
            receipt = json.loads((root/"daemon-child-execution.json").read_text())
            self.assertEqual(receipt["state"], "timeout")
            self.assertEqual(receipt["timeout_seconds"], 120)

    def test_missing_binary_retains_failure_before_raise(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with patch.object(run.subprocess, "run", side_effect=FileNotFoundError("fixture missing")):
                with self.assertRaises(FileNotFoundError):
                    run.run_logged(["fixture"], root, "compile.log", 120, 0)
            self.assertTrue((root/"compile.log").exists())
            receipt = json.loads((root/"compile-execution.json").read_text())
            self.assertEqual(receipt["state"], "launch_error")
            self.assertEqual(receipt["exception_type"], "FileNotFoundError")
            self.assertEqual(receipt["command"], ["fixture"])

class OrderingContract(unittest.TestCase):
    def test_inactive_corner_control_removes_only_reconciliation_call(self):
        repo = Path(__file__).resolve().parents[2]
        positive, _ = run.prepare(repo, "candidate")
        control, manifest = run.prepare(repo, "candidate", inactive_corner_control=True)
        anchor = "\t\tactivate_existing_lighting_corners()\n"
        self.assertEqual(positive["production.dm"].count(anchor), 1)
        self.assertEqual(control["production.dm"], positive["production.dm"].replace(anchor, "", 1))
        self.assertTrue(manifest["inactive_corner_control"])

    def pair(self):
        baseline = {"snapshots": {"initial": ["shared:queued:rendered"]},
                    "bulk_overlay_order": ["1,1,1", "2,1,1"],
                    "compatibility_overlay_order": ["2,1,3", "1,1,3"],
                    "expected_compatibility_order": ["1,1,3", "2,1,3"]}
        candidate = copy.deepcopy(baseline)
        candidate["compatibility_overlay_order"].reverse()
        return baseline, candidate

    def test_separate_compatibility_schedule_is_explicit(self):
        run.validate_parity(*self.pair())

    def test_bulk_order_negative_control(self):
        baseline, candidate = self.pair()
        candidate["bulk_overlay_order"].reverse()
        with self.assertRaisesRegex(AssertionError, "Bulk overlay construction order"):
            run.validate_parity(baseline, candidate)

    def test_compatibility_traversal_negative_control(self):
        baseline, candidate = self.pair()
        candidate["compatibility_overlay_order"].reverse()
        with self.assertRaisesRegex(AssertionError, "native world traversal"):
            run.validate_parity(baseline, candidate)

    def test_missing_default_constructor_negative_control(self):
        baseline, candidate = self.pair()
        candidate["compatibility_overlay_order"].pop()
        with self.assertRaisesRegex(AssertionError, "eligibility/multiplicity"):
            run.validate_parity(baseline, candidate)

    def test_native_order_control_contract(self):
        baseline, candidate = self.pair()
        candidate["bulk_overlay_order"].reverse()
        run.validate_bulk_order_control(baseline, candidate)
        with self.assertRaisesRegex(AssertionError, "was not detected"):
            run.validate_bulk_order_control(*self.pair())

    def test_update_registration_negative_control(self):
        baseline, candidate = self.pair()
        candidate["snapshots"]["initial"] = ["shared:unqueued:unrendered"]
        with self.assertRaisesRegex(AssertionError, "update registration"):
            run.validate_parity(baseline, candidate)


if __name__ == "__main__": unittest.main()
