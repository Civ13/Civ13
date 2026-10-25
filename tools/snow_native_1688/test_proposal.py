"""Pure offline source/oracle controls. Never launches a process or uses sockets."""
import contextlib
import hashlib
import io
import json
import os
import re
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import prepare
import oracle
import run
import collect_evidence

HERE = Path(__file__).resolve().parent
SOURCE = Path(os.environ.get("SNOW_TEST_SOURCE", HERE.parents[1] / "source-inputs"))


class ProposalTests(unittest.TestCase):
    def test_native_assertion_inventory_and_six_dispatches_are_explicit(self):
        source = (HERE / "fixtures/probe.dm").read_text()
        expected = oracle.expected_assertions()
        names = re.findall(r'snow_fixture_assert\("([a-z0-9_]+)",', source)
        self.assertEqual(names, expected["baseline"])
        self.assertEqual(len(names), len(set(names)))
        cases = {"overlay-omission": "appearance", "melt-omission": "warm_debit",
                 "generation-omission": "stale_reaccumulation",
                 "reload-generation-omission": "reload_generation",
                 "reload-sampling": "reload_sampling", "del-unregister-omission": "replacement"}
        for mode, case in cases.items():
            body = prepare.procedure(source, "/proc/snow_fixture_case_" + case + "()")
            self.assertEqual(re.findall(r'snow_fixture_assert\("([a-z0-9_]+)",', body), expected[mode])
            self.assertIn('else if (SNOW_NATIVE_MODE == "' + mode + '")\n\t\tsnow_fixture_case_' + case + '()', source)
        self.assertIn('OpenPort("none")\n\tif (world.port != 0 || !snow_fixture_admit())', source)
        self.assertNotIn('/turf/Destroy()', source)
        self.assertIn('#define EXCEPTION(message) new /exception(message)', (HERE / 'fixtures/stubs.dm').read_text())

    def record(self, mode):
        names = oracle.expected_assertions()[mode]
        values = {name: 1 for name in names}
        if mode in oracle.TARGETS:
            values[oracle.TARGETS[mode]] = 0
        result = dict(head=prepare.HEAD, tree=prepare.TREE, version=prepare.VERSION, mode=mode,
                      checks=len(values), failed=sum(value == 0 for value in values.values()), assertions=values)
        log = "".join(f"SNOW_ASSERT {name}={value}\n" for name, value in values.items())
        log += "SNOW_RESULT " + mode + "\n"
        return result, log

    def test_all_seven_mode_oracles(self):
        for mode in prepare.MODES:
            with self.subTest(mode=mode):
                result, log = self.record(mode)
                verdict = oracle.verify_result(mode, result, log)
                self.assertEqual(verdict["status"], "passed" if mode == "baseline" else "causal-control-detected")

    def test_wrong_binding_missing_extra_and_boolean_fields_reject(self):
        for key, value in (("head", "wrong"), ("tree", "wrong"), ("version", "516.1681"),
                           ("mode", "wrong"), ("checks", True), ("failed", False)):
            result, log = self.record("baseline")
            result[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                oracle.verify_result("baseline", result, log)
        for operation in (lambda r: r.pop("tree"), lambda r: r.update(extra=1)):
            result, log = self.record("baseline")
            operation(result)
            with self.assertRaises(ValueError):
                oracle.verify_result("baseline", result, log)

    def test_each_control_requires_named_causal_failure_and_no_collateral(self):
        for mode, target in oracle.TARGETS.items():
            for alteration in ("all-pass", "wrong-failure", "collateral"):
                result, log = self.record(mode)
                other = next(name for name in result["assertions"] if name != target)
                if alteration != "collateral":
                    result["assertions"][target] = 1
                if alteration != "all-pass":
                    result["assertions"][other] = 0
                result["failed"] = sum(v == 0 for v in result["assertions"].values())
                with self.subTest(mode=mode, alteration=alteration), self.assertRaises(ValueError):
                    oracle.verify_result(mode, result, log)

    def test_runtime_and_log_ambiguity_are_never_control_success(self):
        result, log = self.record("generation-omission")
        bad = (log + "runtime error: fixture failed\n", log + "Bad ref\n",
               log + "SNOW_RESULT generation-omission\n", log.replace("SNOW_ASSERT ", "SNOW_ASSERT ", 1) +
               "SNOW_ASSERT unexpected=0\n", log.replace("SNOW_RESULT generation-omission", ""),
               "SNOW_RESULT generation-omission\n" + log.replace("SNOW_RESULT generation-omission\n", ""))
        for value in bad:
            with self.assertRaises(ValueError):
                oracle.verify_result("generation-omission", result, value)

    def test_every_mutation_has_one_sealed_change_and_original_survives(self):
        source = (SOURCE / "code/modules/1713/snowfall_ground.dm").read_text()
        original = hashlib.sha256(source.encode()).hexdigest()
        self.assertEqual(prepare.mutate(source, "baseline"), source)
        variants = []
        for mode in prepare.MODES[1:]:
            changed = prepare.mutate(source, mode)
            self.assertNotEqual(changed, source)
            variants.append(changed)
            with self.assertRaises(ValueError):
                prepare.mutate(changed, mode)
        self.assertEqual(len(set(variants)), 6)
        self.assertEqual(hashlib.sha256(source.encode()).hexdigest(), original)

    def test_export_preparation_never_uses_git_or_native(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(prepare, "git", side_effect=AssertionError("Git call")), \
                patch.object(run, "run_bounded", side_effect=AssertionError("Native call")):
            output = Path(directory) / "prepared"
            receipt = prepare.build_fixture(SOURCE, output, require_git=False)
            self.assertEqual(receipt["source_authentication"], "git-blob-export")
            self.assertFalse(receipt["native_executed"])
            self.assertEqual(receipt["dimensions"], [18, 18, 3])
            prepare.verify_fixture(output, receipt)
            raw = (SOURCE / "code/modules/1713/snowfall_ground.dm").read_bytes()
            self.assertEqual((output / "cases/baseline/source/production-snow.dm").read_bytes(), raw)
            for mode in prepare.MODES:
                asset = output / "cases" / mode / "source/icons/turf/snow.dmi"
                self.assertEqual(asset.read_bytes(), (SOURCE / "icons/turf/snow.dmi").read_bytes())
            (output / "cases/baseline/source/probe.dm").write_text("changed")
            with self.assertRaises(ValueError):
                prepare.verify_fixture(output, receipt)

    def test_source_export_never_admitted_to_native_controller(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(run, "run_bounded", side_effect=AssertionError("Native call")):
            root = Path(directory)
            summary = run.initial_summary()
            with self.assertRaisesRegex(ValueError, "clean Git"):
                run.run_native(root, {"source_authentication": "git-blob-export"}, root, root / "archive", summary)
            self.assertFalse(summary["native_executed"])
            self.assertFalse(summary["compiler_started"])
            self.assertFalse(summary["daemon_started"])

    def test_native_export_cli_combination_rejected_before_preparation(self):
        with patch("sys.argv", ["run.py", "--source", str(SOURCE), "--output", "unused",
                                "--source-export", "--reviewed-native"]), \
                patch.object(run, "build_fixture", side_effect=AssertionError("Preparation called")), \
                contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as result:
                run.main()
            self.assertEqual(result.exception.code, 2)

    def test_wrong_git_identity_fails_before_any_source_read(self):
        with patch.object(prepare, "git", return_value=b"wrong"):
            with self.assertRaisesRegex(ValueError, "HEAD/tree"):
                prepare.input_inventory(Path("/nonexistent-offline-fixture"), True)

    def test_exact_retained_controller_and_requested_limits(self):
        self.assertEqual(prepare.digest((HERE / "owned_process_1688.py").read_bytes()), run.OWNED_CONTROLLER)
        self.assertEqual(run.COMPILE, {"cpu": 150, "as": 2 * 1024**3, "file": 128 * 1024**2, "fds": 256})
        self.assertEqual(run.RUNTIME, {"cpu": 20, "as": 1024**3, "file": 16 * 1024**2, "fds": 128})
        self.assertEqual(run.TOTAL_WALL, 600)
        owned = (HERE / "owned_process_1688.py").read_text()
        self.assertIn("os.WNOWAIT", owned)
        # Behavioral ordering is independently mocked in test_owned_cleanup.py.
        self.assertLess(owned.index("on_start(proc.pid, None)"),
                        owned.index('stage = "establish_identity"'))

    def test_inventory_rejects_saves_unknown_directories_and_links(self):
        for kind in ("save", "directory", "link"):
            with tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                if kind == "save":
                    (root / "1.sav").write_bytes(b"synthetic-disallowed-output")
                elif kind == "directory":
                    (root / "unapproved").mkdir()
                else:
                    (root / "runtime.log").symlink_to(root / "target")
                with self.subTest(kind=kind), self.assertRaises(ValueError):
                    run.runtime_inventory(root)

    def test_collector_never_includes_native_or_real_save_inputs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "evidence"
            source.mkdir()
            (source / "result.json").write_text('{}')
            (source / "1.sav").write_text("not retained")
            (source / "DreamDaemon").write_text("not retained")
            report = collect_evidence.collect(source, root / "no-acquisition", HERE, root / "retained")
            self.assertFalse(report["rejected"])
            self.assertFalse(any(row["path"].endswith((".sav", ".dmb", ".rsc", "DreamDaemon")) for row in report["files"]))


if __name__ == "__main__":
    unittest.main()
