"""Source-only fixture generation and synthetic receipt validation; no DM run."""

import ast
from contextlib import redirect_stdout
from copy import deepcopy
import hashlib
import io
import json
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import importlib.util

_spec = importlib.util.spec_from_file_location("fishing_prepare", Path(__file__).with_name("prepare_only.py"))
prepare = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(prepare)


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT.parents[1] / prepare.SOURCE_PATH


def synthetic_receipt(variant="candidate"):
    hook = prepare.mutate(prepare.extract_attackby(SOURCE.read_bytes()), variant)
    failed = prepare.expected_failures(variant)
    return dict(schema_version=1, fixture="fishing-completion-v1",
                source_head=prepare.SOURCE_HEAD, source_sha256=prepare.SOURCE_SHA256,
                hook_sha256=prepare.sha256(hook), variant=variant,
                byond_version=516, byond_build=1688, initial_port=43210, port_closed=1,
                reopen_refused=1, clients=0, topics=0, cleanup_owned_remaining=0,
                errors=[], cases={label: 0 if label in failed else 1 for label in prepare.labels()},
                failed_cases=failed)


class PreparationTests(unittest.TestCase):
    def test_exact_source_extraction_and_full_file_identity(self):
        data = SOURCE.read_bytes()
        self.assertEqual(hashlib.sha256(data).hexdigest(), prepare.SOURCE_SHA256)
        body = prepare.extract_attackby(data)
        self.assertTrue(data.count(body) == 1)
        self.assertTrue(body.startswith((prepare.SIGNATURE + "\n").encode()))
        self.assertNotIn(prepare.NEXT_SIGNATURE.encode(), body)
        self.assertEqual(body.count(b"if (do_after("), 3)

    def test_unknown_oversized_or_changed_source_rejected_before_output(self):
        for data in (b"", SOURCE.read_bytes() + b"\n", b"x" * (prepare.SOURCE_LIMIT + 1)):
            with self.subTest(size=len(data)), tempfile.TemporaryDirectory() as directory:
                root = Path(directory); source = root / "bad.dm"; output = root / "out"
                source.write_bytes(data)
                with self.assertRaises(ValueError):
                    prepare.prepare(source, output, "516.1688")
                self.assertFalse(output.exists())

    def test_explicit_current_profile_required_without_relabeling_legacy(self):
        for version in (None, "516.1681", "516.1689", "latest"):
            with tempfile.TemporaryDirectory() as directory:
                output = Path(directory) / "out"
                with self.assertRaises(ValueError):
                    prepare.prepare(SOURCE, output, version)
                self.assertFalse(output.exists())

    def test_existing_output_is_not_reused_or_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "out"; output.mkdir()
            marker = output / "keep"; marker.write_text("spent evidence")
            with self.assertRaises(ValueError):
                prepare.prepare(SOURCE, output, "516.1688")
            self.assertEqual(marker.read_text(), "spent evidence")

    def test_each_control_only_removes_its_exact_two_line_guard(self):
        body = prepare.extract_attackby(SOURCE.read_bytes())
        self.assertEqual(prepare.mutate(body, "candidate"), body)
        for variant in prepare.VARIANTS[1:]:
            mutated = prepare.mutate(body, variant)
            self.assertEqual(body.count(b"\n\t\t\t\tif (counter <= 0)\n"), 3)
            self.assertEqual(mutated.count(b"\n\t\t\t\tif (counter <= 0)\n"), 2)
            route = variant.removeprefix("omit-")
            _, delay, chance = next(row for row in prepare.ROUTES if row[0] == route)
            after = f"\t\t\tif (do_after(H, {delay}, src))\n\t\t\t\tif (prob({chance}))".encode()
            restored = mutated.replace(after, (f"\t\t\tif (do_after(H, {delay}, src))\n"
                "\t\t\t\tif (counter <= 0)\n\t\t\t\t\treturn\n"
                f"\t\t\t\tif (prob({chance}))").encode(), 1)
            self.assertEqual(restored, body)
            self.assertEqual(prepare.expected_failures(variant), [f"pair/{route}/{inner}" for inner, _, _ in prepare.ROUTES])

    def test_four_complete_dme_targets_and_manifest_readback(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "out"
            manifest = prepare.prepare(SOURCE, output, "516.1688")
            self.assertEqual(json.loads((output / "manifest.json").read_text()), manifest)
            self.assertEqual(set(manifest["variants"]), set(prepare.VARIANTS))
            self.assertFalse(manifest["compile_executed"])
            self.assertFalse(manifest["runtime_executed"])
            for variant, row in manifest["variants"].items():
                self.assertEqual(set(row["files"]), {"probe.dme", "hooks.dm", "adapters.dm", "fixture.dm"})
                for name, record in row["files"].items():
                    data = (output / variant / name).read_bytes()
                    self.assertEqual((len(data), prepare.sha256(data)), (record["bytes"], record["sha256"]))
                dme = (output / variant / "probe.dme").read_text()
                self.assertLess(dme.index('#define prob('), dme.index('#include "hooks.dm"'))
                self.assertLess(dme.index('#undef prob'), dme.index('#include "fixture.dm"'))
                self.assertEqual((output / variant / "hooks.dm").read_bytes(),
                                 prepare.mutate(prepare.extract_attackby(SOURCE.read_bytes()), variant))

    def test_deterministic_preparation(self):
        with tempfile.TemporaryDirectory() as directory:
            a, b = Path(directory) / "a", Path(directory) / "b"
            self.assertEqual(prepare.prepare(SOURCE, a, "516.1688"), prepare.prepare(SOURCE, b, "516.1688"))
            for file in a.rglob("*"):
                if file.is_file():
                    self.assertEqual(file.read_bytes(), (b / file.relative_to(a)).read_bytes())

    def test_template_drift_and_aggregate_output_bound_fail_before_write(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "out"
            with patch.object(prepare, "TEMPLATE_HASHES", {"adapters.dm": "0" * 64, "fixture.dm": "0" * 64}):
                with self.assertRaisesRegex(ValueError, "template identity"):
                    prepare.prepare(SOURCE, output, "516.1688")
            self.assertFalse(output.exists())
            with patch.object(prepare, "OUTPUT_LIMIT", 1):
                with self.assertRaisesRegex(ValueError, "aggregate size"):
                    prepare.prepare(SOURCE, output, "516.1688")
            self.assertFalse(output.exists())

    def test_cli_has_no_process_or_network_effects(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(subprocess, "Popen", side_effect=AssertionError("spawn forbidden")), patch.object(socket, "socket", side_effect=AssertionError("network forbidden")):
            argv = ["prepare_only.py", "--prepare-only", "--source", str(SOURCE), "--output", str(Path(directory) / "out"), "--expected-byond-version", "516.1688"]
            with patch.object(sys, "argv", argv), redirect_stdout(io.StringIO()) as output:
                prepare.main()
            self.assertFalse(json.loads(output.getvalue())["runtime_executed"])
        tree = ast.parse((ROOT / "prepare_only.py").read_text())
        modules = {node.module if isinstance(node, ast.ImportFrom) else alias.name
                   for node in ast.walk(tree) if isinstance(node, (ast.Import, ast.ImportFrom)) for alias in node.names}
        self.assertEqual(modules, {"argparse", "hashlib", "json", "pathlib"})

    def test_only_twenty_four_cases_with_expected_control_partition(self):
        labels = prepare.labels()
        self.assertEqual(len(labels), 24)
        self.assertEqual(len(set(labels)), 24)
        self.assertEqual([sum(label.startswith(prefix) for label in labels) for prefix in ("pair/", "cancel/", "miss/", "species/")], [9, 3, 3, 9])
        controls = [set(prepare.expected_failures(variant)) for variant in prepare.VARIANTS[1:]]
        self.assertEqual(set.union(*controls), {label for label in labels if label.startswith("pair/")})
        self.assertFalse(controls[0] & controls[1] | controls[0] & controls[2] | controls[1] & controls[2])

    def test_barrier_and_adapters_are_explicit_not_real_waits_or_food(self):
        source = (ROOT / "adapters.dm").read_text()
        self.assertIn('fish_probe_mode == "compete" && !fish_probe_nested', source)
        self.assertLess(source.index('fish_probe_nested = 1'), source.index('fish_probe_school.attackby(fish_probe_inner_tool, fish_probe_inner)'))
        self.assertIn('fish_probe_wait_stocks += fish_probe_school.counter', source)
        self.assertNotIn('sleep(', source)
        self.assertNotIn('spawn(', source)
        self.assertIn('/obj/proc/attackby', source)
        self.assertIn('"stock" = fish_probe_school.counter', source)

    def test_world_admission_cleanup_and_return_contract(self):
        source = (ROOT / "fixture.dm").read_text()
        startup = source.split('/world/New()\n', 1)[1]
        self.assertLess(startup.index('OpenPort("none")'), startup.index('fish_probe_cases()'))
        self.assertIn('world.byond_version != 516 || world.byond_build != 1688', startup)
        self.assertIn('fish_probe_finish()\n\t\treturn', startup)
        self.assertIn('del(world)\n\treturn', source)
        self.assertIn('fish_probe_owned.Copy()', source)
        self.assertIn('/client/New()', source)
        self.assertIn('/world/Topic(', source)

    def test_cleanup_counts_survivors_before_forgetting_owned_references(self):
        source = (ROOT / "fixture.dm").read_text()
        expected = ["for (var/atom/A in fish_probe_owned.Copy())", "if (A)", "del(A)",
                    "for (var/atom/B in fish_probe_owned)", "if (B)", "fish_probe_cleanup_survivors++",
                    "fish_probe_owned.Cut()", "fish_probe_school = null", "fish_probe_outer = null",
                    "fish_probe_inner = null", "fish_probe_inner_tool = null", "return"]
        def valid(candidate):
            cleanup = candidate.split("/proc/fish_probe_cleanup()\n", 1)[1].split("\n/proc/", 1)[0]
            return ([line.strip() for line in cleanup.splitlines() if line.strip()] == expected
                    and candidate.count("var/global/fish_probe_cleanup_survivors = 0") == 1
                    and candidate.count("fish_probe_cleanup_survivors = 0") == 1
                    and '"cleanup_owned_remaining" = fish_probe_cleanup_survivors)' in candidate)
        self.assertTrue(valid(source))
        for changed in (source.replace("del(A)", "// omitted deletion"),
                        source.replace("fish_probe_cleanup_survivors++", "// omitted census"),
                        source.replace("\tfor (var/atom/B in fish_probe_owned)", "\tfish_probe_owned.Cut()\n\tfor (var/atom/B in fish_probe_owned)"),
                        source.replace('"cleanup_owned_remaining" = fish_probe_cleanup_survivors)', '"cleanup_owned_remaining" = fish_probe_owned.len)'),
                        source.replace("\tfish_probe_owned.Cut()", "\tfish_probe_cleanup_survivors = 0\n\tfish_probe_owned.Cut()")):
            self.assertFalse(valid(changed))
        receipt = synthetic_receipt(); receipt["cleanup_owned_remaining"] = 1
        self.assertIn("invalid cleanup_owned_remaining", prepare.verify_receipt(receipt, "candidate", receipt["hook_sha256"]))

    def test_source_projected_deletion_omission_cannot_be_hidden_by_cut(self):
        # Source-bound observation-order model only; this does not emulate DM
        # deletion or prove native survivor behavior. Runtime receipts are separate.
        source = (ROOT / "fixture.dm").read_text()
        def observe(candidate, survivors=0):
            owned = [object(), object(), object()]
            cleanup = candidate.split("/proc/fish_probe_cleanup()\n", 1)[1].split("\n/proc/", 1)[0]
            for line in cleanup.splitlines():
                if line.strip() == "del(A)":
                    owned = [None for _ in owned]
                elif line.strip() == "fish_probe_cleanup_survivors++":
                    survivors += sum(value is not None for value in owned)
                elif line.strip() == "fish_probe_owned.Cut()":
                    owned.clear()
            if '"cleanup_owned_remaining" = fish_probe_cleanup_survivors)' in candidate:
                return survivors
            return len(owned)
        self.assertEqual(observe(source), 0)
        omitted = source.replace("del(A)", "// omitted deletion")
        self.assertEqual(observe(omitted), 3)
        # A later successful cleanup must not erase earlier surviving owners.
        self.assertEqual(observe(source, survivors=observe(omitted)), 3)
        old_receipt = omitted.replace('"cleanup_owned_remaining" = fish_probe_cleanup_survivors)',
                                      '"cleanup_owned_remaining" = fish_probe_owned.len)')
        self.assertEqual(observe(old_receipt), 0)

    def test_synthetic_receipt_verifier_requires_each_control_cause(self):
        for variant in prepare.VARIANTS:
            receipt = synthetic_receipt(variant)
            self.assertEqual(prepare.verify_receipt(receipt, variant, receipt["hook_sha256"]), [])
            altered = deepcopy(receipt); altered["cases"]["cancel/modern"] = 0
            self.assertTrue(prepare.verify_receipt(altered, variant, receipt["hook_sha256"]))

    def test_synthetic_receipt_rejects_errors_wrong_profile_missing_cases_and_effects(self):
        receipt = synthetic_receipt()
        for change in (lambda r: r.update(errors=["runtime"]), lambda r: r.update(byond_build=1681),
                       lambda r: r.update(clients=1), lambda r: r.update(topics=1),
                       lambda r: r.update(port_closed=0), lambda r: r.update(cleanup_owned_remaining=1),
                       lambda r: r.update(source_head="wrong"), lambda r: r["cases"].pop("pair/modern/modern"),
                       lambda r: r["cases"].update(extra=1), lambda r: r.update(failed_cases=["extra"])):
            altered = deepcopy(receipt); change(altered)
            self.assertTrue(prepare.verify_receipt(altered, "candidate", receipt["hook_sha256"]))


if __name__ == "__main__":
    unittest.main()
