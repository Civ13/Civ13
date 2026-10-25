"""Offline synthetic conversion and failure controls; never launches native tools."""
import copy
from dataclasses import replace
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/save_to_map"))
import core

FIXTURES = Path(__file__).parent / "fixtures"
CANARY = 'PRIVATE_CANARY_[call("untrusted")]\\"; secret'


def fixture():
    return json.loads((FIXTURES / "canonical.json").read_text())


def object_at(data):
    return next(cell for cell in data["cells"] if cell["objects"] and cell["objects"][0]["type"] == core.CHAIR)


class CoreTests(unittest.TestCase):
    def reject(self, data, **kwargs):
        output, report = core.build(data, **kwargs)
        self.assertEqual(report["status"], "rejected")
        self.assertNotIn("geometry.dmm", output)
        self.assertNotIn(b"PRIVATE_CANARY", b"".join(output.values()))
        return report

    def test_exact_deterministic_golden(self):
        data = fixture()
        output, report = core.build(data)
        self.assertEqual(report["status"], "static_source_only")
        self.assertFalse(report["ready"])
        self.assertEqual(output["geometry.dmm"], (FIXTURES / "geometry.dmm").read_bytes())
        self.assertEqual(report["counters"]["retained_objects"], 4)
        self.assertEqual(report["counters"]["retained_cells"], 12)
        data["cells"].reverse()
        self.assertEqual(core.build(data)[0], output)

    def test_multiz_orientation_edges_and_duplicate_objects(self):
        dmm = core.build(fixture())[0]["geometry.dmm"].decode()
        blocks = re.findall(r'\(1,1,(\d+)\) = \{"\n(.*?)\n"\}', dmm, re.S)
        self.assertEqual(blocks, [("1", "aeadac\naaadad"), ("2", "adaeab\nadadad")])
        definitions = re.findall(r'^"([a-z]+)" = (.*)$', dmm, re.M)
        self.assertEqual({len(key) for key, _ in definitions}, {2})
        self.assertEqual(dict(definitions)["ab"].count(core.CHAIR), 2)
        self.assertTrue(all(model.endswith("," + core.AREA + ")") for _, model in definitions))

    def test_manifest_hashes_and_honest_scope(self):
        output, report = core.build(fixture())
        manifest = json.loads(output["manifest.json"])
        for name, digest in manifest["files"].items():
            self.assertEqual(hashlib.sha256(output[name]).hexdigest(), digest)
        self.assertEqual(report["compile_status"], "not_run")
        self.assertEqual(report["native_round_trip"], "not_run")
        self.assertEqual(report["topology_provenance"], "synthetic_only")
        self.assertIn("not_generated", manifest["companion_metadata"])

    def test_policy_example_matches_implemented_exact_catalog(self):
        policy = json.loads((ROOT / "docs/save-to-map/policy.example.json").read_text())
        self.assertEqual(set(policy["terrain"]), {core.FLOOR, core.WALL})
        self.assertEqual(set(policy["structures"]), {core.CHAIR})
        self.assertEqual(set(policy["areas"]), {core.AREA})
        self.assertEqual(set(policy["spawns"]), {core.LANDMARK})
        self.assertEqual(policy["spawns"][core.LANDMARK]["fields"]["name"]["values"], [core.SPAWN])
        self.assertEqual(policy["structures"][core.CHAIR]["fields"]["dir"]["values"], [1,2,4,8])
        self.assertEqual(policy["status"], "implemented_for_synthetic_inputs_only")

    def test_literal_encoder_interpolation_and_controls(self):
        self.assertEqual(core.dm_literal('quote"\\[call()]\n\t'), '"quote\\"\\\\\\[call()\\]\\n\\t"')
        self.assertEqual(core.dm_literal(None), "null")
        self.assertEqual(core.dm_literal(-32), "-32")
        for value in [True, 1.5, float("inf"), {}, [], "\r", "\x00", "\x7f", "a" * 257]:
            with self.subTest(value=type(value).__name__), self.assertRaises(core.CoreError):
                core.dm_literal(value)

    def test_unsafe_string_in_admitted_numeric_property_rejects(self):
        for name in ("dir", "pixel_x", "pixel_y"):
            data = fixture()
            object_at(data)["objects"][0]["vars"][name] = CANARY
            self.reject(data)

    def test_untrusted_spawn_token_rejects(self):
        data = fixture()
        next(c for c in data["cells"] if c["objects"] and c["objects"][0]["type"] == core.LANDMARK)["objects"][0]["vars"]["name"] = CANARY
        self.reject(data)

    def test_unknown_type_and_subtype_refuse_unless_preview(self):
        for path in [core.CHAIR + "/new_subtype", "/obj/structure/simple_door", "/obj/" + CANARY]:
            data = fixture()
            object_at(data)["objects"].append({"type": path, "credential": CANARY})
            self.reject(data)
            output, report = core.build(data, preview=True)
            self.assertEqual(report["status"], "incomplete_preview")
            self.assertEqual(report["counters"]["unsupported_objects"], 1)
            self.assertNotIn(b"PRIVATE_CANARY", b"".join(output.values()))

    def test_unknown_static_field_omits_entire_object_only_in_preview(self):
        data = fixture()
        object_at(data)["objects"][0]["vars"][CANARY] = CANARY
        self.reject(data)
        output, report = core.build(data, preview=True)
        self.assertEqual(report["status"], "incomplete_preview")
        self.assertEqual(report["counters"]["retained_objects"], 3)
        self.assertNotIn(b"PRIVATE_CANARY", b"".join(output.values()))

    def test_credentials_and_user_text_are_redacted_dispositions(self):
        data = fixture()
        obj = object_at(data)["objects"][0]
        for name in ["name", "desc", "ckey", "client", "custom_code", "keycode", "password", "token", "original_target"]:
            obj["vars"][name] = CANARY
        output, report = core.build(data)
        self.assertEqual(report["status"], "static_source_only")
        self.assertEqual(report["counters"]["excluded_fields"], 9)
        self.assertNotIn(b"PRIVATE_CANARY", b"".join(output.values()))

    def test_excluded_mob_subtree_is_not_spilled_onto_map(self):
        data = fixture()
        object_at(data)["objects"].append({"type": "/mob/living/human", "name": CANARY,
                                           "contents": [{"type": core.CHAIR, "password": CANARY}]})
        output, report = core.build(data)
        self.assertEqual(report["status"], "static_source_only")
        self.assertEqual(report["counters"]["excluded_entity_roots"], 1)
        self.assertEqual(report["counters"]["retained_objects"], 4)
        self.assertIsNone(report["uninspected_descendant_count"])
        self.assertNotIn(b"PRIVATE_CANARY", b"".join(output.values()))

    def test_nested_contents_are_excluded_with_unknown_descendant_count(self):
        data = fixture()
        object_at(data)["objects"][0]["contents"] = [{"type": core.CHAIR, "password": CANARY}]
        output, report = core.build(data)
        self.assertEqual(report["counters"]["excluded_content_roots"], 1)
        self.assertIsNone(report["uninspected_descendant_count"])
        self.assertEqual(report["status"], "static_source_only")
        self.assertNotIn(b"PRIVATE_CANARY", b"".join(output.values()))

    def test_unknown_turf_or_turf_field_never_gets_placeholder(self):
        for change in [lambda c: c["turf"].update(type=core.FLOOR + "/new"),
                       lambda c: c["turf"].update(vars={"damage": 5})]:
            data = fixture()
            change(data["cells"][0])
            self.reject(data, preview=True)

    def test_incomplete_duplicate_out_of_bounds_and_boolean_coordinates(self):
        mutations = [lambda d: d["cells"].pop(),
                     lambda d: d["cells"].__setitem__(0, copy.deepcopy(d["cells"][1])),
                     lambda d: d["cells"][0].update(x=0),
                     lambda d: d["cells"][0].update(x=True)]
        for mutate in mutations:
            data = fixture()
            mutate(data)
            self.reject(data)

    def test_source_provenance_topology_and_default_claim_required(self):
        mutations = [lambda d: d.update(kind="native_save"),
                     lambda d: d["provenance"].update(topology="unknown"),
                     lambda d: d["provenance"].update(source_commit="0" * 40),
                     lambda d: d["cells"][0].update(area="/area/caribbean/roofed/temperate"),
                     lambda d: d["cells"][0]["turf"].update(defaults="guessed"),
                     lambda d: object_at(d)["objects"][0].update(defaults="guessed")]
        for mutate in mutations:
            data = fixture()
            mutate(data)
            self.reject(data)

    def test_missing_or_blocked_spawn_refuses(self):
        for mode in ("missing", "wall", "structure"):
            data = fixture()
            cell = next(c for c in data["cells"] if c["objects"] and c["objects"][0]["type"] == core.LANDMARK)
            if mode == "missing":
                cell["objects"] = []
            elif mode == "wall":
                cell["turf"]["type"] = core.WALL
            else:
                cell["objects"].append(copy.deepcopy(object_at(data)["objects"][0]))
            self.reject(data, preview=True)

    def test_invalid_numeric_values(self):
        for value in [True, 0, 3, 16, float("nan"), float("inf"), 1.5]:
            data = fixture()
            object_at(data)["objects"][0]["vars"]["dir"] = value
            self.reject(data)
        data = fixture()
        object_at(data)["objects"][0]["vars"]["pixel_x"] = 33
        self.reject(data)

    def test_resource_bounds_and_cyclic_inputs(self):
        for limits in [replace(core.Limits(), cells=11), replace(core.Limits(), objects=3),
                       replace(core.Limits(), per_cell=1), replace(core.Limits(), levels=1),
                       replace(core.Limits(), nodes=10), replace(core.Limits(), depth=2),
                       replace(core.Limits(), text_bytes=8), replace(core.Limits(), output_bytes=512)]:
            self.reject(fixture(), limits=limits)
        data = fixture()
        data["cells"][0]["objects"].append(data)
        self.reject(data)

    def test_invalid_limits_do_not_crash_or_expand_bounds(self):
        for limits in [replace(core.Limits(), cells=5000), replace(core.Limits(), report_groups="bad"), replace(core.Limits(), output_bytes=1)]:
            report = self.reject(fixture(), limits=limits)
            self.assertEqual(report["reason"], "invalid_limits")

    def test_report_group_saturation_preserves_aggregate_counts(self):
        data = fixture()
        obj = object_at(data)["objects"][0]
        obj["vars"].update(name=CANARY, keycode=CANARY, ckey=CANARY)
        _, report = core.build(data, limits=replace(core.Limits(), report_groups=1))
        self.assertTrue(report["details_truncated"])
        self.assertEqual(report["overflow_group_count"], 2)
        self.assertEqual(report["overflow_dispositions"], 2)
        self.assertEqual(report["counters"]["excluded_fields"], 3)


class FilesystemTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def test_input_is_read_only_and_has_strict_json_bounds(self):
        path = self.root / "canonical.json"
        raw = json.dumps(fixture()).encode()
        path.write_bytes(raw)
        self.assertEqual(core.read_input(path), fixture())
        self.assertEqual(path.read_bytes(), raw)
        with self.assertRaises(core.CoreError):
            core.read_input(path, replace(core.Limits(), input_bytes=2))
        self.assertEqual(path.read_bytes(), raw)

    def test_duplicate_json_keys_nan_and_broken_json_reject_without_echo(self):
        path = self.root / "input.json"
        for raw in [b'{"x":1,"x":2}', b'{"x":NaN}', b'{"x":1e999}', b'{', CANARY.encode()]:
            path.write_bytes(raw)
            with self.assertRaises(core.CoreError) as error:
                core.read_input(path)
            self.assertNotIn(CANARY, str(error.exception))
            self.assertEqual(path.read_bytes(), raw)

    def test_native_extension_is_refused_before_open(self):
        path = self.root / "never_read.sav"
        with patch.object(core.os, "open", side_effect=AssertionError("must not open")):
            with self.assertRaises(core.CoreError):
                core.read_input(path)

    def test_hardlinked_input_is_refused(self):
        source = self.root / "source.json"
        source.write_text(json.dumps(fixture()))
        linked = self.root / "link.json"
        os.link(source, linked)
        with self.assertRaises(core.CoreError):
            core.read_input(linked)

    def test_symlink_or_reparse_components_are_refused(self):
        fake_info = type("Info", (), {"st_mode": 0o040700, "st_file_attributes": 0x400})()
        with patch.object(Path, "lstat", return_value=fake_info):
            with self.assertRaises(core.CoreError):
                core.checked_path(self.root / "input.json")

    def test_exclusive_package_and_receipt_binding(self):
        output, report = core.build(fixture())
        target = self.root / "package"
        core.write_package(target, output, report)
        for name, value in output.items():
            self.assertEqual((target / name).read_bytes(), value)
        receipt = json.loads((target / "CORE_COMPLETE.json").read_bytes())
        self.assertFalse(receipt["ready"])
        self.assertEqual(receipt["manifest_sha256"], hashlib.sha256(output["manifest.json"]).hexdigest())
        before = {p.name: p.read_bytes() for p in target.iterdir()}
        with self.assertRaises(core.CoreError):
            core.write_package(target, output, report)
        self.assertEqual(before, {p.name: p.read_bytes() for p in target.iterdir()})

    def test_existing_output_file_is_never_replaced(self):
        output, report = core.build(fixture())
        target = self.root / "existing"
        target.write_text(CANARY)
        with self.assertRaises(core.CoreError):
            core.write_package(target, output, report)
        self.assertEqual(target.read_text(), CANARY)

    def test_partial_file_write_failure_leaves_no_receipt_and_does_not_retry(self):
        output, report = core.build(fixture())
        target = self.root / "partial"
        real = core.exclusive_write
        calls = []

        def fail(path, content, **kwargs):
            calls.append(path.name)
            if len(calls) == 2:
                raise OSError(CANARY)
            real(path, content, **kwargs)

        with patch.object(core, "exclusive_write", side_effect=fail):
            with self.assertRaises(core.CoreError) as error:
                core.write_package(target, output, report)
        self.assertEqual(len(calls), 2)
        self.assertNotIn(CANARY, str(error.exception))
        self.assertFalse((target / "CORE_COMPLETE.json").exists())
        self.assertTrue(any(target.iterdir()))

    def test_failed_receipt_is_removed(self):
        output, report = core.build(fixture())
        target = self.root / "failed-receipt"
        real = core.exclusive_write

        def fail(path, content, **kwargs):
            real(path, content, **kwargs)
            if path.name == "CORE_COMPLETE.json":
                raise OSError(CANARY)

        with patch.object(core, "exclusive_write", side_effect=fail), self.assertRaises(core.CoreError):
            core.write_package(target, output, report)
        self.assertFalse((target / "CORE_COMPLETE.json").exists())

    def test_uncertain_receipt_cleanup_is_reported_without_retry(self):
        output, report = core.build(fixture())
        target = self.root / "uncertain-receipt"
        real = core.exclusive_write

        def fail(path, content, **kwargs):
            real(path, content, **kwargs)
            if path.name == "CORE_COMPLETE.json":
                raise OSError(CANARY)

        with patch.object(core, "exclusive_write", side_effect=fail), patch.object(Path, "unlink", side_effect=OSError(CANARY)):
            with self.assertRaises(core.CoreError) as error:
                core.write_package(target, output, report)
        self.assertEqual(str(error.exception), "package_write_uncertain")
        # This is an injected uncertain failure, not a passing completion claim.
        self.assertTrue((target / "CORE_COMPLETE.json").exists())

    def test_receipt_collision_is_not_deleted_or_overwritten(self):
        output, report = core.build(fixture())
        target = self.root / "receipt-collision"
        real = core.exclusive_write

        def collide(path, content, **kwargs):
            if path.name == "CORE_COMPLETE.json":
                path.write_text(CANARY)
            real(path, content, **kwargs)

        with patch.object(core, "exclusive_write", side_effect=collide), self.assertRaises(core.CoreError):
            core.write_package(target, output, report)
        self.assertEqual((target / "CORE_COMPLETE.json").read_text(), CANARY)

    def test_output_readback_failure_has_no_receipt(self):
        output, report = core.build(fixture())
        target = self.root / "bad-readback"
        with patch.object(Path, "read_bytes", return_value=b"wrong"), self.assertRaises(core.CoreError):
            core.write_package(target, output, report)
        self.assertFalse((target / "CORE_COMPLETE.json").exists())

    def test_cli_overlap_refusal_preserves_input_and_redacts_paths(self):
        path = self.root / "PRIVATE_PATH_CANARY.json"
        raw = json.dumps(fixture())
        path.write_text(raw)
        with patch.object(sys, "stderr") as stderr:
            self.assertEqual(core.main(["--input", str(path), "--output", str(path)]), 2)
        self.assertNotIn("PRIVATE_PATH_CANARY", str(stderr.write.call_args_list))
        self.assertEqual(path.read_text(), raw)

    def test_cli_rejects_malformed_json_without_exposing_payload(self):
        path = self.root / "input.json"
        path.write_text(CANARY)
        with patch.object(sys, "stderr") as stderr:
            self.assertEqual(core.main(["--input", str(path), "--output", str(self.root / "rejected")]), 2)
        self.assertNotIn(CANARY, str(stderr.write.call_args_list))
        self.assertFalse((self.root / "rejected").exists())

    def test_preview_and_refusal_never_have_complete_receipt(self):
        data = fixture()
        object_at(data)["objects"].append({"type": "/obj/structure/simple_door"})
        for preview in (False, True):
            output, report = core.build(data, preview=preview)
            target = self.root / str(preview)
            core.write_package(target, output, report)
            self.assertFalse((target / "CORE_COMPLETE.json").exists())
            self.assertEqual((target / "geometry.dmm").exists(), preview)

    def test_cli_converts_synthetic_fixture_only(self):
        target = self.root / "cli-package"
        result = subprocess.run([sys.executable, "-I", "-B", str(ROOT / "tools/save_to_map/core.py"),
                                 "--input", str(FIXTURES / "canonical.json"), "--output", str(target)],
                                capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), {"ready": False, "status": "static_source_only"})
        self.assertEqual((target / "geometry.dmm").read_bytes(), (FIXTURES / "geometry.dmm").read_bytes())


if __name__ == "__main__":
    unittest.main()
