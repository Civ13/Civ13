"""Source-bound hidden-atom regression checks. No native process or network.

The native fixture separately exercises BYOND view()/see_invisible with the
complete unmodified production observe proc. Offline tests never model LOS.
"""
import contextlib
import copy
import io
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent / "visibility"


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


fixture = load_module("agent_visibility_prepare", HERE / "prepare.py")
native = load_module("agent_visibility_native", HERE / "run.py")
senses = load_module("agent_visibility_senses", ROOT / "tools/agent-control/senses.py")


class ProductionVisibilityContracts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = (ROOT / fixture.SOURCE).read_text(encoding="utf-8")

    def test_visibility_guards_run_before_rows_and_signatures(self):
        observe = fixture.check_contract(self.source)
        self.assertNotIn("range(radius, M)", observe)
        self.assertEqual(observe.count("for (var/atom/movable/AM in view(radius, M))"), 1)

    def test_contract_rejects_visibility_and_stale_cache_regressions(self):
        mutations = [
            ("in view(radius, M)", "in range(radius, M)"),
            ("AM.invisibility > M.see_invisible", "FALSE"),
            ("AM.invisibility > M.see_invisible", "AM.invisibility >= M.see_invisible"),
            ("!isturf(AM.loc)", "FALSE"),
            ("AM == M", "FALSE"),
            ("!AM.name", "FALSE"),
            ("if (!(ref in signatures))", "if (FALSE)"),
            ('out["nearby_removed"] = gone', 'out["nearby_removed"] = list()'),
            ("C.seen = signatures", "C.seen |= signatures"),
            ("since_rev == C.seen_rev", "TRUE"),
        ]
        for before, after in mutations:
            with self.subTest(mutation=before):
                self.assertIn(before, fixture.extract_observe(self.source))
                mutant = self.source.replace(before, after, 1)
                with self.assertRaises(ValueError):
                    fixture.check_contract(mutant)

    def test_complete_proc_is_extracted_without_rewriting(self):
        observe = fixture.extract_observe(self.source)
        start = self.source.index(fixture.DECLARATION)
        end = self.source.index("\n// Actions a character can take", start)
        self.assertEqual(observe, self.source[start:end].rstrip() + "\n")
        # A real source body change reaches the projection, rather than a frozen
        # copy or a Python reimplementation remaining green.
        modified = self.source.replace('\tvar/list/nearby = list()',
                                       '\tvar/list/nearby = list()\n\t// projection sentinel', 1)
        self.assertIn("projection sentinel", fixture.extract_observe(modified))

    def test_extraction_fails_closed_on_missing_duplicate_or_truncated_proc(self):
        for source in ("", self.source + "\n" + fixture.extract_observe(self.source),
                       fixture.DECLARATION + "\n\treturn list()\n"):
            with self.subTest(source=source[:80]):
                with self.assertRaises(ValueError):
                    fixture.extract_observe(source)

    def test_projection_binds_current_source_and_records_all_input_hashes(self):
        files, manifest = fixture.generated_sources()
        self.assertEqual(files["production_observe.dm"], fixture.extract_observe(self.source))
        self.assertEqual(manifest["production_sha256"], hashlib.sha256(self.source.encode()).hexdigest())
        self.assertEqual(manifest["inputs_sha256"], {
            name: hashlib.sha256(text.encode()).hexdigest() for name, text in files.items()
        })
        self.assertFalse(manifest["runtime_verified"])
        self.assertNotIn("civ13.dme", files["visibility.dme"])
        self.assertEqual(len(re.findall(r'^#include ', files["visibility.dme"], re.M)), 4)
        self.assertRegex(files["constants.dm"], r"#define\s+DEAD\s+2")
        self.assertRegex(files["constants.dm"], r"#define\s+AREA_INSIDE\s+0")

    def test_prepare_is_inert_and_refuses_existing_directory(self):
        with tempfile.TemporaryDirectory() as temp, mock.patch.object(fixture.subprocess, "run") as launch:
            output = Path(temp) / "prepared"
            manifest = fixture.prepare(output)
            self.assertEqual(json.loads((output / "manifest.json").read_text()), manifest)
            self.assertEqual((output / "production_observe.dm").read_text(), fixture.extract_observe(self.source))
            with self.assertRaises(FileExistsError):
                fixture.prepare(output)
            launch.assert_not_called()

    def test_default_cli_only_prepares_inputs(self):
        with tempfile.TemporaryDirectory() as temp, mock.patch.object(fixture, "compile_fixture") as compile_call:
            fixture.main(["--output", str(Path(temp) / "fixture")])
            compile_call.assert_not_called()

    def test_native_fixture_preserves_engine_and_delta_behavior(self):
        adapters = (HERE / "adapters.dm").read_text()
        self.assertNotIn("/proc/view(", adapters)
        self.assertNotIn("/proc/act_character_observe", adapters)
        self.assertNotRegex(adapters, r"\b(?:invisibility|see_invisible|opacity)\s*=")
        self.assertNotIn('nearby_removed', adapters)
        self.assertNotIn('C.seen =', adapters)
        probe = (HERE / "probe.dm").read_text()
        self.assertIn("control.act_character_observe(identity,", probe)
        for label in ("higher invisibility excluded", "opaque wall excluded", "outside radius excluded",
                      "other z-level excluded", "container contents excluded", "see_invisible equality included",
                      "visible atoms included", "stale baseline does not leak hidden atoms",
                      "hidden rows do not reappear or remove twice", "visible again appears in delta"):
            self.assertIn(label, probe)
        for mode in ("invisibility", "observer threshold", "occlusion", "distance", "z-level", "container"):
            self.assertIn(f'if ("{mode}")', probe)
        self.assertIn("new /mob/living/human", probe)
        self.assertIn("var/obj/item/object", probe)
        self.assertIn('agent_ref(AM) in lost["nearby_removed"]', probe)

    def test_native_fixture_is_not_a_production_startup_or_daemon_launcher(self):
        probe = (HERE / "probe.dm").read_text()
        self.assertIn("\tvisibility = 0", probe)
        self.assertIn('OpenPort("none")', probe)
        self.assertIn('!OpenPort(0) && port == 0', probe)
        self.assertIn('/world/Export()\n\treturn null', probe)
        self.assertIn('/world/Topic()\n\treturn null', probe)
        self.assertIn('/client/New()\n\tdel(src)\n\treturn', probe)
        self.assertTrue(probe.rstrip().endswith("del(world)\n\treturn"))
        self.assertNotIn("sleep(", probe)
        self.assertNotIn("spawn(", probe)
        self.assertNotIn("world.Shell", probe)
        prepare = (HERE / "prepare.py").read_text()
        self.assertNotIn('"dd.exe"', prepare)
        self.assertNotIn('"DreamDaemon"', prepare)
        self.assertNotIn('git show', prepare)


class NativeReceiptTests(unittest.TestCase):
    def receipt(self):
        return {"source_sha256": "a" * 64, "byond_version": 516, "byond_build": 1688,
                "failures": 0, "runtime_error": 0,
                "checks": [{"label": label, "ok": 1} for label in native.expected_labels()]}

    def test_complete_receipt_binds_every_assertion_source_and_engine(self):
        receipt = self.receipt()
        self.assertEqual(len(receipt["checks"]), 185)
        self.assertEqual(len(set(row["label"] for row in receipt["checks"])), 185)
        native.validate_result(receipt, "a" * 64, "516.1688")
        for key, value in (("source_sha256", "b" * 64), ("byond_build", 1687),
                           ("failures", 1), ("runtime_error", 1)):
            with self.subTest(key=key), self.assertRaises(ValueError):
                native.validate_result(dict(receipt, **{key: value}), "a" * 64, "516.1688")

    def test_missing_duplicate_or_failed_assertion_is_not_native_acceptance(self):
        for mutation in ("missing", "duplicate", "failed", "empty"):
            receipt = self.receipt()
            if mutation == "missing":
                receipt["checks"].pop()
            elif mutation == "duplicate":
                receipt["checks"][-1] = receipt["checks"][0]
            elif mutation == "failed":
                receipt["checks"][0]["ok"] = 0
            else:
                receipt["checks"] = []
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                native.validate_result(receipt, "a" * 64, "516.1688")

    def test_native_execution_requires_explicit_opt_in(self):
        with mock.patch.object(native, "run_native") as launch, contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit):
                native.main(["--output", "unused", "--byond-bin", "unused"])
            launch.assert_not_called()

    def test_supervisor_failure_does_not_write_accepted_receipt(self):
        compiled = mock.Mock(stdout="compiled", stderr="", returncode=0)
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / "rejected"
            with mock.patch.object(native, "run_native", side_effect=[compiled, RuntimeError("socket rejected")]), \
                    mock.patch.object(native.fixture_toolchain, "verify"), \
                    mock.patch.object(native.fixture_toolchain, "validate_compiler"):
                with self.assertRaisesRegex(RuntimeError, "socket rejected"):
                    native.main(["--run-native", "--output", str(output), "--byond-bin", str(Path(temp))])
            self.assertFalse((output / "accepted.json").exists())
            self.assertTrue((output / "runtime.log").exists())


class VisibleRowsCacheTests(unittest.TestCase):
    """Exercise the production client on deterministic server-protocol replies.

    This covers cache invalidation only. Source contracts and the native
    fixture cover whether server visibility produces those removals.
    """
    class Replies:
        def __init__(self, replies):
            self.replies = copy.deepcopy(replies)
            self.requests = []

        def request(self, action, args=None):
            self.requests.append((action, dict(args or {})))
            return {"ok": True, "result": self.replies.pop(0)}

    def rows(self):
        return [
            {"ref": "player", "name": "Synthetic visible player", "mob": True, "dx": 1, "dy": 0},
            {"ref": "object", "name": "Synthetic visible object", "item": True, "dx": 2, "dy": 0},
        ]

    def response(self, rev, rows=(), **extra):
        return dict(self={"x": 5, "y": 5, "z": 1}, rev=rev, nearby=list(rows), **extra)

    def test_lost_visibility_evicts_both_rows_until_they_reappear(self):
        replies = self.Replies([
            self.response(1, self.rows()),
            self.response(2, changes_since=1, nearby_removed=["player", "object"], nearby_unchanged=0),
            self.response(3, changes_since=2, nearby_removed=[], nearby_unchanged=0),
            self.response(4, self.rows(), changes_since=3, nearby_removed=[], nearby_unchanged=0),
        ])
        client = senses.SensesClient(replies)
        for expected in ({"player", "object"}, set(), set(), {"player", "object"}):
            reply = client.request("character_observe", {"character": "fixture"})
            self.assertEqual({row["ref"] for row in reply["result"]["nearby"]}, expected)
            self.assertEqual(set(client.seen["fixture"].rows), expected)
        self.assertEqual([args.get("since_rev") for _, args in replies.requests], [None, 1, 2, 3])

    def test_full_baseline_after_stale_revision_drops_hidden_cached_rows(self):
        replies = self.Replies([self.response(1, self.rows()), self.response(8)])
        client = senses.SensesClient(replies)
        client.request("character_observe", {"character": "fixture"})
        result = client.request("character_observe", {"character": "fixture"})["result"]
        self.assertEqual(result["nearby"], [])
        self.assertEqual(client.seen["fixture"].rows, {})


if __name__ == "__main__":
    unittest.main()
