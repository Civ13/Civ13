"""Independent offline controls: temporary files and mocks, never native execution.

Run with: python -B -m unittest discover -s tools/snow_native_1688 -p test_review_controls.py -v
The synthetic result records below test the Python oracle, not DM or gameplay.
"""
import contextlib
import copy
import io
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import collect_evidence as collector
import oracle
import owned_process_1688 as owned
import prepare
import run as runner


HERE = Path(__file__).resolve().parent
SOURCE = Path(os.environ.get("SNOW_TEST_SOURCE", str(HERE.parent.parent / "source-inputs")))
CONTROLLER_SHA = "b247b308ff088b832417466218b1b96f11be2f1a622e710749e92c77b451b1ea"
IDENTITY = {"pid": 41001, "state": "S", "ppid": 41000, "pgrp": 41001,
            "session": 41001, "start_ticks": 123456}
EXPECTED = {mode: ["control_ok"] + ([oracle.TARGETS[mode]] if mode in oracle.TARGETS else [])
            for mode in prepare.MODES}


def fake_result(mode="baseline"):
    values = {name: int(name != oracle.TARGETS.get(mode)) for name in EXPECTED[mode]}
    result = {"head": prepare.HEAD, "tree": prepare.TREE, "version": prepare.VERSION,
              "mode": mode, "checks": len(values), "failed": int(mode != "baseline"),
              "assertions": values}
    log = "".join(f"SNOW_ASSERT {name}={value}\n" for name, value in values.items())
    return result, log + f"SNOW_RESULT {mode}\n"


class OfflineCase(unittest.TestCase):
    def setUp(self):
        self.stack = contextlib.ExitStack()
        self.addCleanup(self.stack.close)
        self.temp = Path(self.stack.enter_context(tempfile.TemporaryDirectory(prefix="snow-review-")))
        for target in ("subprocess.Popen", "subprocess.check_output", "subprocess.run",
                       "subprocess.call", "subprocess.check_call", "socket.socket",
                       "os.kill", "os.killpg", "os.waitid"):
            self.stack.enter_context(patch(target, side_effect=AssertionError("Forbidden live operation: " + target)))
        self.stack.enter_context(patch.object(owned, "proc_identity", side_effect=AssertionError("Live proc identity prohibited")))
        self.stack.enter_context(patch.object(runner, "proc_identity", side_effect=AssertionError("Live proc identity prohibited")))
        original_open = Path.open

        def safe_open(path, *args, **kwargs):
            if str(path) == "/proc" or str(path).startswith("/proc/"):
                raise AssertionError("Live /proc reads prohibited")
            return original_open(path, *args, **kwargs)

        self.stack.enter_context(patch.object(Path, "open", safe_open))
        self.stack.enter_context(patch.object(oracle, "expected_assertions", return_value=EXPECTED))

    def tooling(self):
        root = self.temp / "tooling"
        (root / "fixtures").mkdir(parents=True)
        shutil.copyfile(HERE / "source-bindings.json", root / "source-bindings.json")
        (root / "fixtures/stubs.dm").write_text("// Offline fake stub, not compiled.\n")
        (root / "fixtures/probe.dm").write_text("// Offline fake probe, not compiled.\n")
        self.stack.enter_context(patch.object(prepare, "HERE", root))
        return root

    def fixture(self):
        self.tooling()
        output = self.temp / "prepared"
        return output, prepare.build_fixture(SOURCE, output, require_git=False)

    def copy_source(self, output):
        # A hosted SOURCE may be the full game checkout. Copy only eight bound inputs.
        for name in prepare.REQUIRED:
            target = output / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(SOURCE / name, target)


class PreparationControls(OfflineCase):
    def test_exact_identity_and_retained_controller(self):
        self.assertEqual(prepare.HEAD, "e87eae1d411e276ce2ae3f0b871829a1911c114c")
        self.assertEqual(prepare.TREE, "cb0db4de48f271ca3a694583b17904c410d7dce1")
        self.assertEqual(prepare.VERSION, "516.1688")
        self.assertEqual(len(prepare.MODES), 7)
        self.assertEqual(prepare.digest((HERE / "owned_process_1688.py").read_bytes()), CONTROLLER_SHA)

    def test_export_authenticates_all_reference_blobs_without_git(self):
        rows = prepare.input_inventory(SOURCE, require_git=False)
        self.assertEqual(set(rows), set(prepare.REQUIRED))
        for name, row in rows.items():
            data = (SOURCE / name).read_bytes()
            self.assertEqual(row["blob"], prepare.blob(data))
            self.assertEqual(row["sha256"], prepare.digest(data))
            self.assertEqual(row["bytes"], len(data))

    def test_git_authentication_requires_exact_head_tree_clean_and_inventory(self):
        expected = prepare.bindings()
        tracked = b"".join(f'{row["mode"]} blob {row["sha"]}\t{name}\0'.encode()
                            for name, row in expected.items())
        responses = [prepare.HEAD.encode(), prepare.TREE.encode(), b"", tracked]
        with patch.object(prepare, "git", side_effect=responses) as git:
            self.assertEqual(len(prepare.input_inventory(SOURCE, True)), len(prepare.REQUIRED))
            self.assertEqual(git.call_count, 4)
        for wrong in ([b"wrong"], [prepare.HEAD.encode(), b"wrong"],
                      [prepare.HEAD.encode(), prepare.TREE.encode(), b"?? untracked"],
                      [prepare.HEAD.encode(), prepare.TREE.encode(), b"", b""]):
            with self.subTest(wrong=wrong), patch.object(prepare, "git", side_effect=wrong):
                with self.assertRaises(ValueError):
                    prepare.input_inventory(SOURCE, True)

    def test_changed_source_bytes_rejected(self):
        copied = self.temp / "source"
        self.copy_source(copied)
        (copied / "code/modules/1713/snowfall_ground.dm").write_text("wrong\n")
        with self.assertRaisesRegex(ValueError, "Source blob mismatch"):
            prepare.input_inventory(copied, False)

    def test_linked_input_and_parent_rejected(self):
        linked = self.temp / "linked"
        linked.symlink_to(SOURCE, target_is_directory=True)
        with self.assertRaises(ValueError):
            prepare.input_inventory(linked, False)
        with self.assertRaises(ValueError):
            prepare.regular(linked / "AGENTS.md")

    def test_unique_causal_mutations_preserve_baseline(self):
        source = (SOURCE / "code/modules/1713/snowfall_ground.dm").read_text()
        self.assertEqual(prepare.mutate(source, "baseline"), source)
        variants = [prepare.mutate(source, mode) for mode in prepare.MODES[1:]]
        self.assertEqual(len(set(variants)), 6)
        for mode, variant in zip(prepare.MODES[1:], variants):
            with self.subTest(mode=mode):
                self.assertNotEqual(variant, source)
                with self.assertRaises(ValueError):
                    prepare.mutate(source + source, mode)
                with self.assertRaises(ValueError):
                    prepare.mutate("", mode)
        with self.assertRaises(ValueError):
            prepare.mutate(source, "unknown")

    def test_procedure_extraction_is_exact_and_unique(self):
        text = "/a()\n\treturn 1\n\n/b()\n\treturn 2\n"
        self.assertEqual(prepare.procedure(text, "/a()"), "/a()\n\treturn 1\n\n")
        for source in ("", text + text):
            with self.assertRaises(ValueError):
                prepare.procedure(source, "/a()")

    def test_export_receipt_and_every_generated_hash(self):
        output, receipt = self.fixture()
        self.assertEqual(receipt["source_authentication"], "git-blob-export")
        self.assertIs(receipt["native_executed"], False)
        self.assertIs(receipt["clients_admitted"], False)
        self.assertIs(receipt["custom_serializer_executed"], False)
        self.assertEqual(receipt["modes"], list(prepare.MODES))
        self.assertEqual(receipt["dimensions"], [18, 18, 3])
        prepare.verify_fixture(output, receipt)
        self.assertEqual((output / "cases/baseline/source/production-snow.dm").read_bytes(),
                         (SOURCE / "code/modules/1713/snowfall_ground.dm").read_bytes())
        self.assertEqual((output / "cases/baseline/source/mutation.diff").read_bytes(), b"")
        for name, expected in receipt["generated"].items():
            self.assertEqual(prepare.digest((output / name).read_bytes()), expected)

    def test_reverification_detects_original_and_generated_changes(self):
        output, receipt = self.fixture()
        for path in (output / "inputs/AGENTS.md", output / "cases/baseline/source/probe.dm"):
            with self.subTest(path=str(path)):
                original = path.read_bytes()
                path.write_bytes(original + b"changed")
                with self.assertRaises(ValueError):
                    prepare.verify_fixture(output, receipt)
                path.write_bytes(original)

    def test_existing_or_in_source_outputs_rejected(self):
        self.tooling()
        copied = self.temp / "source"
        self.copy_source(copied)
        for path in (self.temp, copied / "forbidden-output"):
            with self.assertRaises(ValueError):
                prepare.build_fixture(copied, path, False)

    def test_symlinked_output_ancestor_rejected_before_writes(self):
        self.tooling()
        copied = self.temp / "source"
        self.copy_source(copied)
        linked = self.temp / "outside"
        linked.symlink_to(copied, target_is_directory=True)
        with self.assertRaises(ValueError):
            prepare.build_fixture(copied, linked / "forbidden", False)
        self.assertFalse((copied / "forbidden").exists())

    def test_parent_component_source_alias_cannot_place_output_in_source(self):
        self.tooling()
        copied = self.temp / "source"
        self.copy_source(copied)
        alias = copied / ".." / "source"
        with self.assertRaises(ValueError):
            prepare.build_fixture(alias, copied / "forbidden", False)
        self.assertFalse((copied / "forbidden").exists())


class OracleControls(OfflineCase):
    def test_baseline_and_all_six_exact_causal_negatives(self):
        for mode in prepare.MODES:
            with self.subTest(mode=mode):
                result, log = fake_result(mode)
                verdict = oracle.verify_result(mode, result, log)
                self.assertEqual(verdict["expected_failures"], [] if mode == "baseline" else [oracle.TARGETS[mode]])

    def test_all_passing_mutant_does_not_count_as_detection(self):
        for mode in prepare.MODES[1:]:
            with self.subTest(mode=mode):
                result, log = fake_result(mode)
                result["assertions"][oracle.TARGETS[mode]] = 1
                result["failed"] = 0
                with self.assertRaisesRegex(ValueError, "Wrong causal failure set"):
                    oracle.verify_result(mode, result, log)

    def test_unrelated_failure_cannot_replace_or_join_causal_failure(self):
        for mode in prepare.MODES[1:]:
            for replace in (False, True):
                with self.subTest(mode=mode, replace=replace):
                    result, log = fake_result(mode)
                    result["assertions"]["control_ok"] = 0
                    if replace:
                        result["assertions"][oracle.TARGETS[mode]] = 1
                    result["failed"] = sum(value == 0 for value in result["assertions"].values())
                    with self.assertRaisesRegex(ValueError, "Wrong causal failure set"):
                        oracle.verify_result(mode, result, log)

    def test_result_identity_schema_counts_and_strict_integer_values(self):
        original, log = fake_result()
        edits = [lambda r: r.update(head="wrong"), lambda r: r.update(tree="wrong"),
                 lambda r: r.update(version="516.1681"), lambda r: r.update(mode="wrong"),
                 lambda r: r.update(extra=1), lambda r: r.pop("tree"),
                 lambda r: r.update(checks=True), lambda r: r.update(checks=2),
                 lambda r: r.update(failed=False), lambda r: r.update(failed=1),
                 lambda r: r["assertions"].update(control_ok=True),
                 lambda r: r["assertions"].update(control_ok=1.0),
                 lambda r: r["assertions"].update(control_ok=2),
                 lambda r: r["assertions"].update(extra=1),
                 lambda r: r.update(assertions={})]
        for index, edit in enumerate(edits):
            with self.subTest(index=index):
                result = copy.deepcopy(original)
                edit(result)
                with self.assertRaises(ValueError):
                    oracle.verify_result("baseline", result, log)

    def test_bad_assertion_and_completion_log_shapes_rejected(self):
        result, valid = fake_result()
        bad = ["", valid + "SNOW_ASSERT control_ok=1\n", valid + "SNOW_RESULT baseline\n",
               valid.replace("control_ok=1", "control_ok=0"),
               valid.replace("control_ok=1", "control_ok=true"),
               valid.replace("SNOW_RESULT baseline", "SNOW_RESULT wrong"),
               valid + "SNOW_ASSERT malformed\n", valid + "SNOW_RESULT malformed marker\n"]
        for log in bad:
            with self.subTest(log=log), self.assertRaises(ValueError):
                oracle.verify_result("baseline", result, log)

    def test_native_error_diagnostics_rejected_in_all_logs(self):
        result, valid = fake_result()
        diagnostics = ["FAIL: bad", "BUG: bad", "RUNTIME: bad", "warning: bad", "error: bad",
                       "runtime error", "Runtime in x", "bad ref", "bad loc", "segmentation fault",
                       "fatal error", "out of memory", "access violation", "infinite loop", "## ERROR", "cleanup failed"]
        for text in diagnostics:
            with self.subTest(text=text):
                with self.assertRaises(ValueError):
                    oracle.verify_result("baseline", result, valid + text)
                with self.assertRaises(ValueError):
                    oracle.verify_auxiliary({"daemon.log": text})

    def test_loopback_open_requires_later_close_and_single_bind(self):
        result, valid = fake_result()
        opened = "World opened on network port 12345 for address 127.0.0.1.\n"
        closed = "World no longer opened to new users.\n"
        oracle.verify_result("baseline", result, opened + closed + valid)
        for prefix in (opened, closed + opened, opened + closed + opened + closed,
                       opened.replace("127.0.0.1", "0.0.0.0") + closed):
            with self.subTest(prefix=prefix), self.assertRaises(ValueError):
                oracle.verify_result("baseline", result, prefix + valid)

    def test_auxiliary_logs_also_reject_external_bind(self):
        with self.assertRaises(ValueError):
            oracle.verify_auxiliary({"daemon.log": "World opened on network port 12345 for address 0.0.0.0.\n"
                                     "World no longer opened to new users.\n"})

    def test_malformed_listener_diagnostics_and_impossible_ports_rejected(self):
        for text in ("World opened on network port mystery",
                     "World opened on network port 0 for address 127.0.0.1.",
                     "World opened on network port 65536 for address 127.0.0.1."):
            with self.subTest(text=text), self.assertRaises(ValueError):
                oracle.verify_auxiliary({"daemon.log": text + "\nWorld no longer opened to new users.\n"})


class RunnerControls(OfflineCase):
    def test_initial_summary_never_claims_native_start(self):
        summary = runner.initial_summary()
        for name in ("native_executed", "compiler_attempted", "compiler_started", "compiler_completed",
                     "daemon_attempted", "daemon_started", "daemon_completed"):
            self.assertIs(summary[name], False)
        self.assertEqual(summary["phases"], [])

    def test_export_native_combination_rejected_before_preparation(self):
        with patch("sys.argv", ["run.py", "--source", "ignored", "--output", "ignored",
                                "--source-export", "--reviewed-native"]), \
                patch.object(runner, "build_fixture", side_effect=AssertionError("Must reject before prepare")), \
                contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as raised:
            runner.main()
        self.assertEqual(raised.exception.code, 2)

    def test_direct_native_runner_rejects_export_receipt_before_runtime_inspection(self):
        with patch.object(runner, "binaries", side_effect=AssertionError("Runtime must not be inspected")):
            with self.assertRaisesRegex(ValueError, "clean Git source"):
                runner.run_native(self.temp, {"source_authentication": "git-blob-export"},
                                  self.temp, self.temp / "archive", runner.initial_summary())

    def test_read_rejects_symlink_and_oversize_evidence(self):
        path = self.temp / "evidence.json"
        path.write_text("12345")
        with self.assertRaises(ValueError):
            runner.read(path, limit=4)
        link = self.temp / "link"
        link.symlink_to(path)
        with self.assertRaises(ValueError):
            runner.read(link)

    def test_runtime_inventory_refuses_unexpected_files_directories_and_links(self):
        for kind in ("file", "directory", "symlink"):
            with self.subTest(kind=kind):
                work = self.temp / kind
                work.mkdir()
                (work / "home").mkdir()
                (work / "tmp").mkdir()
                (work / "daemon.log").write_text("")
                runner.runtime_inventory(work)
                bad = work / "unexpected"
                if kind == "directory":
                    bad.mkdir()
                elif kind == "symlink":
                    bad.symlink_to(work / "daemon.log")
                else:
                    bad.write_text("bad")
                with self.assertRaises(ValueError):
                    runner.runtime_inventory(work)

    def test_runtime_inventory_enforces_individual_and_aggregate_caps(self):
        work = self.temp / "work"
        work.mkdir()
        with (work / "daemon.log").open("wb") as handle:
            handle.truncate(runner.LOG_LIMIT + 1)
        with self.assertRaises(ValueError):
            runner.runtime_inventory(work)
        (work / "daemon.log").unlink()
        with (work / "snow-native.dmb").open("wb") as handle:
            handle.truncate(64 * 1024**2 + 1)
        with self.assertRaises(ValueError):
            runner.runtime_inventory(work)

    def test_compiler_inventory_refuses_unexpected_outputs_and_individual_caps(self):
        work = self.temp / "compile"
        (work / "icons/turf").mkdir(parents=True)
        (work / "home").mkdir()
        (work / "tmp").mkdir()
        (work / "icons/turf/snow.dmi").write_bytes(b"fake icon")
        (work / "snow-native.dme").write_text("// not compiled")
        runner.compile_inventory(work)
        for name in ("unexpected", "tmp/unexpected"):
            path = work / name
            path.write_text("unexpected")
            with self.assertRaises(ValueError):
                runner.compile_inventory(work)
            path.unlink()
        for name, size in (("compile.log", runner.LOG_LIMIT + 1),
                           ("snow-native.dmb", 32 * 1024**2 + 1)):
            path = work / name
            with path.open("wb") as handle:
                handle.truncate(size)
            with self.assertRaises(ValueError):
                runner.compile_inventory(work)
            path.unlink()

    def test_compiler_inventory_enforces_aggregate_cap(self):
        work = self.temp / "compile"
        work.mkdir()
        sizes = {"snow-native.dmb": 32 * 1024**2, "snow-native.rsc": 32 * 1024**2,
                 "compile-start.json": runner.LOG_LIMIT, "compile-started.json": runner.LOG_LIMIT,
                 "compile-process.json": runner.LOG_LIMIT, "compile.log": runner.LOG_LIMIT}
        for name, size in sizes.items():
            with (work / name).open("wb") as handle:
                handle.truncate(size)
        runner.compile_inventory(work)
        (work / "probe.dm").write_bytes(b"x")
        with self.assertRaisesRegex(ValueError, "Aggregate compiler"):
            runner.compile_inventory(work)

    def test_runtime_binary_members_are_checked_against_pinned_archive(self):
        binary = self.temp / "bin"
        binary.mkdir()
        archive = self.temp / "fake.zip"
        with zipfile.ZipFile(archive, "w") as bundle:
            for name in runner.MEMBERS:
                data = ("fake, never executed: " + name).encode()
                bundle.writestr("byond/bin/" + name, data)
                (binary / name).write_bytes(data)
        with patch.object(runner, "ARCHIVE", prepare.digest(archive.read_bytes())):
            self.assertEqual(set(runner.binaries(binary, archive)), set(runner.MEMBERS))
            original_size = (binary / "DreamDaemon").stat().st_size
            (binary / "DreamDaemon").write_bytes(b"x" * original_size)
            with self.assertRaisesRegex(ValueError, "Runtime member bytes differ"):
                runner.binaries(binary, archive)
        with self.assertRaisesRegex(ValueError, "Unreviewed BYOND archive"):
            runner.binaries(binary, archive)

    def test_runtime_member_wrong_size_is_rejected_before_unbounded_read(self):
        binary = self.temp / "bin"
        binary.mkdir()
        archive = self.temp / "fake.zip"
        with zipfile.ZipFile(archive, "w") as bundle:
            for name in runner.MEMBERS:
                bundle.writestr("byond/bin/" + name, b"fake")
                (binary / name).write_bytes(b"fake")
        altered = binary / "DreamMaker"
        altered.write_bytes(b"wrong-sized")
        original_read = Path.read_bytes
        original_open = Path.open

        def bounded_read(path):
            if path == altered:
                raise AssertionError("Do not read a runtime member with an incorrect size")
            return original_read(path)

        def bounded_open(path, *args, **kwargs):
            if path == altered:
                raise AssertionError("Do not open a runtime member with an incorrect size")
            return original_open(path, *args, **kwargs)

        with patch.object(runner, "ARCHIVE", prepare.digest(archive.read_bytes())), \
                patch.object(Path, "read_bytes", bounded_read), \
                patch.object(Path, "open", bounded_open), self.assertRaises(ValueError):
            runner.binaries(binary, archive)

    def test_readiness_requires_binding_and_integer_closed_port(self):
        for change in ({"head": "wrong"}, {"mode": "wrong"}, {"port": 1}, {"port": False}, {"extra": 1}):
            with self.subTest(change=change):
                work = self.temp / str(len(list(self.temp.iterdir())))
                work.mkdir()
                data = dict(runner.readiness("baseline"), **change)
                (work / "snow-native-ready.json").write_text(json.dumps(data))
                sample, state = runner.listener_ack(work, "baseline")
                with self.assertRaises(ValueError):
                    sample(41001, IDENTITY, {41001: IDENTITY})
                self.assertFalse(state["acknowledged"])
                self.assertFalse((work / "snow-native-go.json").exists())

    def test_listener_absence_and_presence_using_only_fake_proc_tables(self):
        for has_listener in (False, True):
            with self.subTest(has_listener=has_listener):
                work = self.temp / str(has_listener)
                work.mkdir()
                (work / "snow-native-ready.json").write_text(json.dumps(runner.readiness("baseline")))
                table = "header\n" + ("0: 0100007F:1234 00000000:0000 0A 0:0 0:0 0 0 0 8123\n" if has_listener else "")

                class FakeProc:
                    def __init__(self, path):
                        self.path = str(path)

                    def iterdir(self):
                        self_outer.assertEqual(self.path, "/proc/41001/fd")
                        return ["fake_fd_3"]

                    def read_text(self):
                        self_outer.assertIn(self.path, ("/proc/41001/net/tcp", "/proc/41001/net/tcp6"))
                        return table if self.path.endswith("/tcp") else "header\n"

                self_outer = self
                sample, state = runner.listener_ack(work, "baseline")
                with patch.object(runner, "Path", FakeProc), \
                        patch.object(runner, "proc_identity", return_value=IDENTITY.copy()), \
                        patch.object(runner.os, "readlink", return_value="socket:[8123]"):
                    if has_listener:
                        with self.assertRaisesRegex(ValueError, "Owned listening socket"):
                            sample(41001, IDENTITY, {41001: IDENTITY})
                        self.assertFalse(state["acknowledged"])
                        self.assertFalse((work / "snow-native-go.json").exists())
                    else:
                        sample(41001, IDENTITY, {41001: IDENTITY})
                        self.assertTrue(state["acknowledged"])
                        census = json.loads((work / "listener-census.json").read_text())
                        self.assertEqual(census["listeners"], [])
                        self.assertEqual(census["owned"], [IDENTITY])
                        self.assertEqual(json.loads((work / "snow-native-go.json").read_text())["ack"],
                                         "owned-listener-census-v1")

    def test_listener_refuses_dead_reused_or_disappeared_owned_identity(self):
        cases = [None, dict(IDENTITY, state="Z"), dict(IDENTITY, start_ticks=999)]
        for index, current in enumerate(cases):
            with self.subTest(current=current):
                work = self.temp / str(index)
                work.mkdir()
                (work / "snow-native-ready.json").write_text(json.dumps(runner.readiness("baseline")))
                sample, state = runner.listener_ack(work, "baseline")
                with patch.object(runner, "proc_identity", return_value=current), self.assertRaises(ValueError):
                    sample(41001, IDENTITY, {41001: IDENTITY})
                self.assertFalse(state["acknowledged"])

    def test_receipt_truth_before_and_after_fake_spawn_and_cleanup_failure(self):
        for scenario in ("before-spawn", "after-spawn", "cleanup-failure"):
            with self.subTest(scenario=scenario):
                output = self.temp / scenario
                source = output / "cases/baseline/source"
                source.mkdir(parents=True)
                summary = runner.initial_summary()
                receipt = {"source_authentication": "clean-git", "controller_sha256": {}}

                def fake_bounded(command, work, log, wall, cap, env, profile, sample, started):
                    if scenario == "before-spawn":
                        raise OSError("synthetic spawn failure")
                    started(41001, None)  # Exact retained controller on_start contract.
                    if scenario == "after-spawn":
                        raise RuntimeError("synthetic post-spawn failure")
                    return {"exit_code": 0, "stop_reason": None, "log_truncated": False, "cleanup_verified": True,
                            "cleanup_no_observed_live_descendants": False,
                            "cleanup_process_group_absent": True, "owned_child_listing_available": True}

                with patch.object(runner, "MODES", ("baseline",)), \
                        patch.object(runner, "binaries", return_value={}), \
                        patch.object(runner, "controller_hashes", return_value={}), \
                        patch.object(runner, "verify_fixture"), \
                        patch.object(runner, "run_bounded", side_effect=fake_bounded):
                    with self.assertRaises((OSError, RuntimeError, ValueError)):
                        runner.run_native(output, receipt, self.temp, self.temp / "archive", summary)
                self.assertTrue(summary["compiler_attempted"])
                self.assertEqual(summary["compiler_started"], scenario != "before-spawn")
                self.assertEqual(summary["native_executed"], scenario != "before-spawn")
                self.assertFalse(summary["compiler_completed"])
                self.assertFalse(summary["daemon_started"])
                phase = summary["phases"][0]
                self.assertEqual(phase["terminated"], scenario == "cleanup-failure")
                self.assertFalse(phase["completed"])
                self.assertEqual((source / "compile-started.json").exists(), scenario != "before-spawn")

    def test_full_fake_lane_records_every_started_and_completed_phase(self):
        output, receipt = self.fixture()
        receipt.update(source_authentication="clean-git", controller_sha256={})
        summary = runner.initial_summary()
        commands = []

        def fake_bounded(command, work, log, wall, cap, env, profile, sample, started):
            commands.append(command)
            self.assertLessEqual(wall, 180)
            self.assertEqual(cap, runner.LOG_LIMIT)
            self.assertEqual(set(env), {"HOME", "TMPDIR", "LANG", "LC_ALL", "TZ", "BYOND_SYSTEM", "LD_LIBRARY_PATH"})
            started(41001, None)
            mode = work.parent.name
            if command[0].endswith("DreamMaker"):
                log.write_text("DM compiler version 516.1688\n0 errors, 0 warnings\n")
                (work / "snow-native.dmb").write_bytes(b"fake dmb, not executable")
                (work / "snow-native.rsc").write_bytes(b"fake rsc")
            else:
                result, runtime = fake_result(mode)
                log.write_text("")
                (work / "runtime.log").write_text(runtime)
                (work / "snow-native-result.json").write_text(json.dumps(result))
            if sample:
                sample(41001, IDENTITY, {41001: IDENTITY})
            return {"exit_code": 0, "stop_reason": None, "log_truncated": False, "cleanup_verified": True,
                    "cleanup_no_observed_live_descendants": True,
                    "cleanup_process_group_absent": True, "owned_child_listing_available": True}

        with patch.object(runner, "binaries", return_value={}), \
                patch.object(runner, "controller_hashes", return_value={}), \
                patch.object(runner, "listener_ack", return_value=(None, {"acknowledged": True})), \
                patch.object(runner, "run_bounded", side_effect=fake_bounded):
            results = runner.run_native(output, receipt, self.temp, self.temp / "archive", summary)
        self.assertEqual(set(results), set(prepare.MODES))
        self.assertEqual(len(commands), 14)
        self.assertTrue(summary["native_executed"])
        self.assertTrue(summary["compiler_completed"])
        self.assertTrue(summary["daemon_completed"])
        self.assertEqual(summary["compiler_completed_phases"], 7)
        self.assertEqual(summary["daemon_completed_phases"], 7)
        self.assertTrue(all(phase["started"] and phase["terminated"] and phase["completed"]
                            for phase in summary["phases"]))
        for command in commands[1::2]:
            self.assertIn("127.0.0.1", command)
            self.assertIn("-close", command)
            self.assertIn("-nowebclient", command)

    def test_deadline_exhausted_during_preflight_never_spawns(self):
        output = self.temp / "deadline"
        (output / "cases/baseline/source").mkdir(parents=True)
        summary = runner.initial_summary()
        receipt = {"source_authentication": "clean-git", "controller_sha256": {}}
        now = [0]

        def slow_verify(*args):
            now[0] = runner.TOTAL_WALL + 1

        with patch.object(runner, "MODES", ("baseline",)), \
                patch.object(runner.time, "monotonic", side_effect=lambda: now[0]), \
                patch.object(runner, "binaries", return_value={}), \
                patch.object(runner, "controller_hashes", return_value={}), \
                patch.object(runner, "verify_fixture", side_effect=slow_verify), \
                patch.object(runner, "run_bounded", side_effect=AssertionError("Must not spawn beyond deadline")):
            with self.assertRaisesRegex(ValueError, "deadline"):
                runner.run_native(output, receipt, self.temp, self.temp / "archive", summary)
        self.assertFalse(summary["native_executed"])
        self.assertFalse(summary["compiler_started"])

    def test_compiler_ten_errors_cannot_match_zero_error_success(self):
        output = self.temp / "compiler-errors"
        (output / "cases/baseline/source").mkdir(parents=True)
        summary = runner.initial_summary()
        receipt = {"source_authentication": "clean-git", "controller_sha256": {}}

        def fake_bounded(command, work, log, wall, cap, env, profile, sample, started):
            self.assertTrue(command[0].endswith("DreamMaker"))
            started(41001, None)
            log.write_text("DM compiler version 516.1688\n10 errors, 0 warnings\n")
            return {"exit_code": 0, "stop_reason": None, "log_truncated": False, "cleanup_verified": True,
                    "cleanup_no_observed_live_descendants": True,
                    "cleanup_process_group_absent": True, "owned_child_listing_available": True}

        with patch.object(runner, "MODES", ("baseline",)), \
                patch.object(runner, "binaries", return_value={}), \
                patch.object(runner, "controller_hashes", return_value={}), \
                patch.object(runner, "verify_fixture"), \
                patch.object(runner, "run_bounded", side_effect=fake_bounded):
            with self.assertRaisesRegex(ValueError, "clean native compile"):
                runner.run_native(output, receipt, self.temp, self.temp / "archive", summary)
        self.assertFalse(summary["daemon_started"])


class CollectorControls(OfflineCase):
    def test_collector_fixed_inventory_never_copies_binaries_or_extra_files(self):
        evidence = self.temp / "evidence"
        tooling = self.temp / "tooling"
        acquisition = self.temp / "acquisition"
        for path in (evidence, tooling, acquisition):
            path.mkdir()
        (evidence / "result.json").write_text('{"native_executed":false}')
        case = evidence / "cases/baseline/run"
        case.mkdir(parents=True)
        (case / "snow-native.dmb").write_text("do not retain")
        (case / "secret.txt").write_text("do not retain")
        (tooling / "DreamDaemon").write_text("do not retain")
        output = self.temp / "retained"
        report = collector.collect(evidence, acquisition, tooling, output)
        self.assertFalse(report["native_execution_performed_by_collector"])
        self.assertEqual([row["path"] for row in report["files"]], ["receipts/result.json"])
        self.assertTrue(report["missing"])
        self.assertEqual(report["rejected"], [])
        self.assertFalse(list(output.rglob("*.dmb")))

    def test_collector_rejects_symlinked_inputs_and_oversize_files(self):
        evidence = self.temp / "evidence"
        evidence.mkdir()
        target = self.temp / "target"
        target.write_text("x")
        (evidence / "result.json").symlink_to(target)
        with (evidence / "preparation.json").open("wb") as handle:
            handle.truncate(collector.MAX_FILE + 1)
        report = collector.collect(evidence, self.temp / "absent", self.temp / "absent",
                                   self.temp / "output")
        self.assertEqual(report["status"], "partial-evidence-rejected")
        self.assertEqual(len(report["rejected"]), 2)
        self.assertEqual(report["files"], [])

    def test_collector_rejects_symlinked_output_ancestor(self):
        target = self.temp / "target"
        target.mkdir()
        linked = self.temp / "linked"
        linked.symlink_to(target, target_is_directory=True)
        with self.assertRaises(ValueError):
            collector.collect(self.temp / "absent", self.temp / "absent", self.temp / "absent",
                              linked / "forbidden")
        self.assertFalse((target / "forbidden").exists())


if __name__ == "__main__":
    unittest.main()
