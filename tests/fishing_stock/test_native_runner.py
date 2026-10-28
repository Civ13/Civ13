"""Offline injected lifecycle/receipt tests: never launch BYOND or contact a network."""
from contextlib import redirect_stdout, redirect_stderr
from copy import deepcopy
import importlib.util
import io
import json
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

HERE = Path(__file__).resolve().parent
# Import itself must be passive, including the shared lifecycle/toolchain imports.
with patch.object(subprocess, "Popen", side_effect=AssertionError("spawn forbidden during import")), patch.object(socket, "socket", side_effect=AssertionError("network forbidden during import")):
    spec = importlib.util.spec_from_file_location("fishing_native_driver", HERE / "run_native.py")
    native = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(native)

HEAD = "a" * 40
PROVENANCE = {"head": HEAD, "tracked_dirty": False, "input_sha256": {"synthetic": "offline"}}
CANONICAL = "World opened on network port 43210 for address 127.0.0.1.\nWorld no longer opened to new users.\nFISHING_DONE\n"


def receipt(work):
    variant = work.name
    failed = native.prepare.expected_failures(variant)
    return dict(schema_version=1, fixture="fishing-completion-v1", source_head=HEAD,
                source_sha256=native.prepare.SOURCE_SHA256,
                hook_sha256=native.digest_file(work / "hooks.dm"), variant=variant,
                byond_version=516, byond_build=1688, initial_port=43210, port_closed=1,
                reopen_refused=1, clients=0, topics=0, cleanup_owned_remaining=0,
                errors=[], cases={label: int(label not in failed) for label in native.prepare.labels()},
                failed_cases=failed)


class RunnerTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.args = SimpleNamespace(output=self.root / "out", expected_byond_version="516.1688",
                                    byond_bin=self.root, byond_archive=self.root / "absent.zip",
                                    acquisition_receipt=self.root / "absent-receipt.json")
        self.events = []
        self.receipt_change = lambda value: value
        self.canonical = CANONICAL
        self.compile_log = "DM compiler version 516.1688\nprobe.dmb - 0 errors, 0 warnings\n"
        self.reaped = True
        # Even failure branches cannot accidentally fall through to a real spawn/network.
        self.spawn = patch.object(subprocess, "Popen", side_effect=AssertionError("real process forbidden")).start()
        self.network = patch.object(socket, "socket", side_effect=AssertionError("network forbidden")).start()
        self.addCleanup(patch.stopall)

    def identity(self, binary, archive, acquisition):
        self.events.append("identity")
        return {"injected_offline_identity": True}

    def runner(self, command, work, role, deadline):
        self.events.append((role, work.name, command))
        self.assertGreater(deadline, time.monotonic())
        (work / (role + "-process.json")).write_text(json.dumps({"reaped": self.reaped, "returncode": 0}))
        if role == "compile":
            return self.compile_log
        (work / "runtime.log").write_text(self.canonical)
        (work / "result.json").write_text(json.dumps(self.receipt_change(receipt(work))))
        return ""

    def execute(self, **overrides):
        arguments = dict(runner=self.runner, provenance=lambda deadline: deepcopy(PROVENANCE), verify_identity=self.identity)
        arguments.update(overrides)
        with redirect_stdout(io.StringIO()):
            return native.execute(self.args, **arguments)

    def test_four_targets_eight_launches_are_explicitly_synthetic(self):
        result = self.execute()
        self.assertEqual(result["status"], "passed")
        self.assertTrue(result["injected_offline_test"])
        self.assertFalse(result["native_attempted"])
        self.assertEqual(list(result["modes"]), list(native.prepare.VARIANTS))
        self.assertEqual(len(self.events), 16)
        for index in range(0, len(self.events), 2):
            self.assertEqual(self.events[index], "identity")
        commands = [event[2] for event in self.events if isinstance(event, tuple)]
        self.assertEqual(len(commands), 8)
        self.assertEqual([Path(c[0]).name for c in commands], ["DreamMaker", "DreamDaemon"] * 4)
        for command in commands[1::2]:
            self.assertEqual(command[1:], ["probe.dmb", "-ip", "127.0.0.1", "-invisible", "-close", "-trusted", "-nowebclient", "-log", "runtime.log"])
        self.spawn.assert_not_called(); self.network.assert_not_called()

    def test_exact_execution_head_is_distinct_from_production_origin(self):
        result = self.execute()
        self.assertEqual(result["manifest"]["source_head"], HEAD)
        self.assertEqual(result["manifest"]["production_origin_head"], native.prepare.SOURCE_HEAD)
        for row in result["modes"].values():
            self.assertEqual(row["result"]["source_head"], HEAD)

    def test_identity_failure_prevents_first_launch_and_retains_failure(self):
        reject = Mock(side_effect=ValueError("archive identity mismatch"))
        with self.assertRaisesRegex(ValueError, "archive identity"):
            self.execute(verify_identity=reject)
        self.assertEqual(self.events, [])
        saved = json.loads((self.args.output / "summary.json").read_text())
        self.assertFalse(saved["native_attempted"])
        self.assertEqual(saved["status"], "incomplete")
        self.assertIn("archive identity mismatch", saved["error"])

    def test_identity_is_reverified_before_daemon_not_only_compiler(self):
        calls = 0
        def identity(*args):
            nonlocal calls
            calls += 1
            if calls == 2:
                raise ValueError("installed member changed")
            return {}
        with self.assertRaisesRegex(ValueError, "member changed"):
            self.execute(verify_identity=identity)
        self.assertEqual([event[0] for event in self.events], ["compile"])

    def test_wrong_or_missing_profile_and_platform_reject_before_output(self):
        for version in (None, "516.1681", "latest"):
            self.args.expected_byond_version = version
            with self.assertRaisesRegex(ValueError, "explicit Linux"):
                self.execute()
            self.assertFalse(self.args.output.exists())
        self.args.expected_byond_version = "516.1688"
        with patch.object(sys, "platform", "win32"), self.assertRaises(ValueError):
            self.execute()
        self.assertFalse(self.args.output.exists())

    def test_cli_requires_explicit_opt_in_and_profile_without_spawning(self):
        for argv in (["run_native.py"], ["run_native.py", "--execute", "--expected-byond-version", "516.1681"]):
            with patch.object(sys, "argv", argv), redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                native.main()
        self.spawn.assert_not_called()

    def test_compiler_failure_stops_before_runtime_and_is_preserved(self):
        self.compile_log = "DM compiler version 516.1688\nprobe.dmb - 1 errors, 0 warnings\n"
        with self.assertRaises(ValueError):
            self.execute()
        self.assertEqual(len([e for e in self.events if isinstance(e, tuple)]), 1)
        self.assertIn("Compiler banner", json.loads((self.args.output / "summary.json").read_text())["error"])

    def test_unreaped_process_is_rejected_before_next_launch(self):
        self.reaped = False
        with self.assertRaisesRegex(ValueError, "reap receipt"):
            self.execute()
        self.assertEqual(len(self.events), 2)

    def test_generated_source_change_stops_before_daemon(self):
        def tamper(command, work, role, deadline):
            result = self.runner(command, work, role, deadline)
            (work / "hooks.dm").write_text("changed")
            return result
        with self.assertRaisesRegex(ValueError, "generated source changed"):
            self.execute(runner=tamper)
        self.assertEqual(len(self.events), 2)

    def test_receipts_require_every_causal_case_and_no_runtime_errors(self):
        for mutation in (lambda r: r.update(errors=["unexpected"]),
                         lambda r: r["cases"].pop("pair/modern/ordinary"),
                         lambda r: r.update(clients=1), lambda r: r.update(byond_build=1681),
                         lambda r: r.update(source_head="b" * 40)):
            work = self.root / "candidate"; work.mkdir(exist_ok=True)
            (work / "hooks.dm").write_text("synthetic")
            result = receipt(work); mutation(result)
            with self.assertRaises(ValueError):
                native.verify_runtime(result, CANONICAL, CANONICAL, "candidate", result["hook_sha256"], HEAD)
        work = self.root / "omit-modern"; work.mkdir()
        (work / "hooks.dm").write_text("synthetic")
        result = receipt(work); result["cases"]["pair/modern/modern"] = 1
        with self.assertRaisesRegex(ValueError, "unexpected case verdict"):
            native.verify_runtime(result, CANONICAL, CANONICAL, "omit-modern", result["hook_sha256"], HEAD)

    def test_network_receipt_requires_one_loopback_open_then_close_then_done(self):
        work = self.root / "candidate"; work.mkdir()
        (work / "hooks.dm").write_text("synthetic")
        result = receipt(work)
        for canonical in (CANONICAL.replace("127.0.0.1", "0.0.0.0"), CANONICAL.replace("43210", "43211"),
                          CANONICAL + "FISHING_DONE\n", CANONICAL.replace("FISHING_DONE\n", ""),
                          "FISHING_DONE\n" + CANONICAL.replace("FISHING_DONE\n", ""),
                          CANONICAL.replace("World no longer opened to new users.\n", "")):
            with self.assertRaises(ValueError):
                native.verify_runtime(result, canonical, canonical, "candidate", result["hook_sha256"], HEAD)
        with self.assertRaises(ValueError):
            native.verify_runtime(result, CANONICAL + "\nruntime error: test", CANONICAL, "candidate", result["hook_sha256"], HEAD)

    def test_deadline_expiry_prevents_launch_and_original_output_not_reused(self):
        with patch.object(native, "WORK_SECONDS", 0), self.assertRaisesRegex(RuntimeError, "deadline"):
            self.execute()
        self.assertEqual(self.events, [])
        first = (self.args.output / "summary.json").read_bytes()
        with self.assertRaises(FileExistsError):
            self.execute()
        self.assertEqual((self.args.output / "summary.json").read_bytes(), first)

    def test_changed_source_after_run_cannot_pass(self):
        rows = [deepcopy(PROVENANCE), dict(PROVENANCE, head="b" * 40)]
        with self.assertRaisesRegex(ValueError, "source changed"):
            self.execute(provenance=lambda deadline: rows.pop(0))
        self.assertNotEqual(json.loads((self.args.output / "summary.json").read_text())["status"], "passed")

    def test_existing_bootstrap_paths_and_scoped_five_minute_ci_gate(self):
        workflow = (native.ROOT / ".github/workflows/test.yml").read_text()
        section = workflow.split("      - name: Verify isolated fishing completion and native omission controls\n", 1)[1].split("      - name: Verify accessory removal", 1)[0]
        self.assertIn("if: needs.changes.outputs.extensive == 'true' || contains(fromJSON(needs.changes.outputs.new_tests || '[]'), 'tests/fishing_stock')", section)
        self.assertIn("timeout-minutes: 5", section)
        self.assertIn("--execute --expected-byond-version 516.1688", section)
        self.assertIn('--byond-archive "$PWD/BYOND/pinned.zip"', section)
        self.assertIn('--acquisition-receipt "$PWD/.ci/compile/byond-download.json"', section)
        self.assertIn("always() && needs.changes.result == 'success' && steps.fishing_stock_native.outputs.started == 'true'", section)
        self.assertIn("if-no-files-found: error", section)
        bootstrap = (native.ROOT / "scripts/travis_pre_byond.sh").read_text()
        self.assertIn("cd BYOND", bootstrap)
        self.assertIn("--platform linux --output pinned.zip", bootstrap)
        self.assertIn('> "$repo_root/.ci/compile/byond-download.json"', bootstrap)

    def test_real_passive_identity_path_rejects_absent_receipt_without_spawn(self):
        with self.assertRaises(OSError):
            self.execute(verify_identity=native.identity)
        self.assertEqual(self.events, [])
        self.spawn.assert_not_called(); self.network.assert_not_called()

    def test_source_provenance_bounds_git_without_scoping_away_dirty_files(self):
        responses = [HEAD.encode(), b"", "\n".join(native.TRACKED_INPUTS).encode()]
        with patch.object(subprocess, "run", side_effect=lambda *args, **kwargs: SimpleNamespace(stdout=responses.pop(0))) as run:
            result = native.source_provenance(time.monotonic() + 5)
        self.assertEqual(result["head"], HEAD)
        commands = [call.args[0] for call in run.call_args_list]
        prefix = ["git", *native.GIT_MEMORY_ARGS]
        self.assertTrue(all(command[:len(prefix)] == prefix for command in commands))
        self.assertEqual(commands[1][len(prefix):], ["diff", "--quiet", "HEAD"])
        self.assertEqual(commands[2][len(prefix):], ["ls-files", "--error-unmatch", "--", *native.TRACKED_INPUTS])
        self.assertTrue(all(call.kwargs["check"] and call.kwargs["timeout"] <= 5 for call in run.call_args_list))
        self.assertEqual(native.MEMORY_BYTES, 512 * 1024**2)

    def test_git_dirty_and_infrastructure_failures_keep_distinct_bounded_stderr(self):
        for code, label, detail in ((1, "tracked source dirty", b""),
                                    (128, "Git provenance failure", b"fatal: packfile cannot be mapped: Cannot allocate memory\n"),
                                    (128, "Git provenance failure", b"x" * 1000 + b"fatal: retained ending\xff")):
            def git(command, **kwargs):
                if "rev-parse" in command:
                    return SimpleNamespace(stdout=HEAD.encode())
                raise subprocess.CalledProcessError(code, command, stderr=detail)
            with patch.object(subprocess, "run", side_effect=git):
                with self.assertRaises(RuntimeError):
                    self.execute(provenance=native.source_provenance)
            saved = json.loads((self.args.output / "summary.json").read_text())
            self.assertIn(label, saved["error"])
            self.assertIn("exit=" + str(code), saved["error"])
            self.assertLessEqual(len(saved["error"]), 514)
            self.assertEqual(saved["modes"], {})
            self.assertFalse(saved["native_attempted"])
            if code == 128:
                self.assertIn("fatal:", saved["error"])
            self.assertEqual(self.events, [])
            self.args.output = self.root / ("out-" + str(len(list(self.root.iterdir()))))

    def test_shared_containment_is_pinned_and_not_reimplemented(self):
        self.assertEqual(native.WORK_SECONDS, 280)
        self.assertEqual(native.MEMORY_BYTES, 512 * 1024**2)
        self.assertEqual(native.shared.LIMIT, 2 * 1024**2)
        for path, expected in native.PINS.items():
            self.assertEqual(native.digest_file(native.ROOT / path), expected)
        original = object(); sys.modules["test_source_contract"] = original
        try:
            native.load_shared()
            self.assertIs(sys.modules["test_source_contract"], original)
        finally:
            sys.modules.pop("test_source_contract", None)
        with patch.object(native, "PINS", {"tools/byond/version.json": "0" * 64}), self.assertRaisesRegex(ValueError, "dependency changed"):
            native.load_shared()
        self.spawn.assert_not_called(); self.network.assert_not_called()


if __name__ == "__main__":
    unittest.main()
