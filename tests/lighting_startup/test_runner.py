"""Compiler-free launcher failure receipt regression."""
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

if __name__ == "__main__": unittest.main()
