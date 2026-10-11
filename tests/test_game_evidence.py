"""Synthetic helper tests; these never launch BYOND or verify real gameplay."""

from copy import deepcopy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


KIT = Path(__file__).resolve().parents[1]
HELPER = KIT / "skills/civ13-byond-verification/scripts/check_game_evidence.py"
if not HELPER.is_file():
    HELPER = KIT / "scripts/check-game-evidence.py"
spec = importlib.util.spec_from_file_location("game_evidence", HELPER)
evidence = importlib.util.module_from_spec(spec)
spec.loader.exec_module(evidence)


class GameEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.manifest = self.root / "manifest.json"
        (self.root / "run.log").write_text("Synthetic fixture result: PASS\n", encoding="utf-8")
        self.sha = "a" * 40
        self.data = {
            "schema_version": 1, "game": "Civ13", "commit": self.sha,
            "runtime": {"name": "BYOND", "version": "synthetic", "platform": "fixture"},
            "map": {"name": "fixture", "source": "synthetic:test", "dimensions": [2, 2, 1]},
            "scenario": "other",
            "run": {"scope": "synthetic", "dirty": False,
                    "started_utc": "2026-10-11T00:00:00Z", "finished_utc": "2026-10-11T00:01:00Z"},
            "steps": ["Validate synthetic fixture files without launching a game."],
            "limitations": ["Synthetic only; no BYOND or graphical acceptance was exercised."],
            "media": {"screenshot_required": False, "video_required": False,
                      "reason": "Helper unit fixture; no game acceptance claim."},
            "artifacts": [{"id": "log", "kind": "log", "path": "run.log"}],
            "checks": [{"id": "fixture", "description": "Synthetic result exists",
                        "result": "passed", "evidence": ["log"], "notes": "Fixture only."}],
        }

    def run_check(self, data=None, sha=None):
        self.manifest.write_text(json.dumps(self.data if data is None else data), encoding="utf-8")
        return evidence.validate(self.manifest, sha or self.sha)

    def memory_fixture(self):
        self.data["scenario"] = "season-memory"
        for identity in ("memory-samples", "repeated-seasons"):
            self.data["checks"].append({"id": identity, "description": identity,
                                        "result": "passed", "evidence": ["metrics"], "notes": "Synthetic."})
        self.data["artifacts"].append({"id": "metrics", "kind": "metrics", "path": "samples.csv"})
        self.data["memory"] = {"artifact": "metrics", "metric": "private_bytes",
                               "process_identity": "synthetic:PID1:start0",
                               "settling_rule": "Fixture samples after cleanup"}
        csv_text = ("elapsed_seconds,cycle,phase,bytes\n"
                    "0,1,baseline,100\n1,1,peak,150\n2,1,settled,105\n"
                    "3,2,baseline,105\n4,2,peak,155\n5,2,settled,110\n")
        (self.root / "samples.csv").write_text(csv_text, encoding="utf-8")
        return csv_text

    def test_deterministic_report_checksums_and_no_game_acceptance_claim(self):
        first = self.run_check()
        self.assertEqual(first, self.run_check())
        self.assertTrue(first["bundle_valid"])
        self.assertEqual(first["artifacts"][0]["sha256"], evidence.sha256(self.root / "run.log"))
        self.assertIn("not independently verified", first["meaning"])
        self.assertEqual(first["run"]["scope"], "synthetic")

    def test_godot_scene_requires_engine_and_non_grid_reason(self):
        self.data["game"] = "Frontier Systems"
        self.data["runtime"] = {"name": "Godot", "version": "synthetic", "platform": "fixture"}
        self.data["map"].update(source="res://tests/fixture.tscn", dimensions=None)
        with self.assertRaisesRegex(ValueError, "dimensions_reason"):
            self.run_check()
        self.data["map"]["dimensions_reason"] = "This synthetic scene has no tile-grid dimensions."
        self.assertEqual(self.run_check()["runtime"]["name"], "Godot")
        self.data["runtime"].pop("version")
        with self.assertRaisesRegex(ValueError, "Runtime version"):
            self.run_check()

    def test_stale_commit_and_checksum_rejected(self):
        with self.assertRaisesRegex(ValueError, "commit differs"):
            self.run_check(sha="b" * 40)
        self.data["artifacts"][0]["sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "checksum mismatch"):
            self.run_check()

    def test_missing_empty_and_escaping_files_rejected(self):
        for path in ("missing.log", "../outside.log", str(self.root / "run.log")):
            with self.subTest(path=path):
                data = deepcopy(self.data)
                data["artifacts"][0]["path"] = path
                with self.assertRaises(ValueError):
                    self.run_check(data)
        (self.root / "run.log").write_bytes(b"")
        with self.assertRaisesRegex(ValueError, "missing or empty"):
            self.run_check()

    def test_unknown_duplicate_and_unreferenced_evidence_rejected(self):
        for change in (lambda d: d["artifacts"].append(deepcopy(d["artifacts"][0])),
                       lambda d: d["checks"].append(deepcopy(d["checks"][0])),
                       lambda d: d["checks"][0].update(evidence=["unknown"]),
                       lambda d: d["checks"][0].update(evidence=[])):
            data = deepcopy(self.data)
            change(data)
            with self.assertRaises(ValueError):
                self.run_check(data)

    def test_dirty_run_requires_patch(self):
        self.data["run"]["dirty"] = True
        with self.assertRaisesRegex(ValueError, "patch artifact"):
            self.run_check()
        (self.root / "patch.diff").write_text("synthetic patch", encoding="utf-8")
        self.data["artifacts"].append({"id": "patch", "kind": "patch", "path": "patch.diff"})
        self.assertTrue(self.run_check()["bundle_valid"])

    def test_external_url_is_never_reported_verified(self):
        self.data["artifacts"][0].pop("path")
        self.data["artifacts"][0]["url"] = "https://example.invalid/run.log"
        self.assertEqual(self.run_check()["artifacts"][0]["availability"], "external-url-not-verified")
        self.data["artifacts"][0]["url"] = "https://user:password@example.invalid/run.log"
        with self.assertRaisesRegex(ValueError, "without credentials"):
            self.run_check()

    def test_missing_media_requires_its_own_explicit_skip(self):
        self.data["media"]["screenshot_required"] = True
        self.data["checks"].append({"id": "other", "description": "Unrelated skip", "result": "not-run",
                                    "evidence": [], "notes": "Unavailable"})
        with self.assertRaisesRegex(ValueError, "screenshot evidence is missing"):
            self.run_check()
        self.data["checks"][-1]["id"] = "screenshot"
        self.assertEqual(self.run_check()["missing_required_media"], ["screenshot"])

    def test_gameplay_cannot_turn_off_screenshots(self):
        self.data["scenario"] = "gameplay"
        with self.assertRaisesRegex(ValueError, "real screenshot"):
            self.run_check()

    def test_skipped_media_cannot_cite_unrelated_evidence(self):
        self.data["media"]["screenshot_required"] = True
        self.data["checks"].append({"id": "screenshot", "description": "Capture the interaction",
                                    "result": "not-run", "evidence": ["log"], "notes": "Unavailable"})
        with self.assertRaisesRegex(ValueError, "empty evidence list"):
            self.run_check()

    def test_save_scenario_requires_rejection_and_preservation_results(self):
        self.data["scenario"] = "save-roundtrip"
        with self.assertRaisesRegex(ValueError, "Scenario checks are missing"):
            self.run_check()
        for identity in sorted(evidence.SCENARIO_CHECKS["save-roundtrip"]):
            self.data["checks"].append({"id": identity, "description": identity, "result": "not-run",
                                        "evidence": [], "notes": "Real BYOND fixture unavailable"})
        result = self.run_check()
        self.assertEqual(sum(c["result"] == "not-run" for c in result["checks"]), 5)

    def test_memory_summary_separates_peak_and_settled(self):
        self.memory_fixture()
        result = self.run_check()["memory_observations"]
        self.assertEqual(result["cycles"][0]["observed_peak_bytes"], 150)
        self.assertEqual(result["cycles"][1]["settled_delta_bytes"], 5)
        self.assertEqual(result["first_to_last_settled_delta_bytes"], 5)
        self.assertIn("No leak or OOM verdict", result["interpretation"])

    def test_memory_rejects_nonfinite_unsorted_missing_phase_and_one_cycle(self):
        csv_text = self.memory_fixture()
        alternatives = [csv_text.replace("155", "nan"), csv_text.replace("5,2", "2,2"),
                        csv_text.replace("5,2,settled,110\n", ""),
                        "\n".join(csv_text.splitlines()[:4]) + "\n",
                        csv_text.replace("3,2", "3,3").replace("4,2", "4,3").replace("5,2", "5,3")]
        for content in alternatives:
            with self.subTest(content=content):
                (self.root / "samples.csv").write_text(content, encoding="utf-8")
                with self.assertRaises(ValueError):
                    self.run_check()

    def test_memory_pass_without_samples_rejected(self):
        self.memory_fixture()
        self.data.pop("memory")
        with self.assertRaisesRegex(ValueError, "requires parsed memory"):
            self.run_check()

    def test_memory_samples_must_fit_declared_run_duration(self):
        self.memory_fixture()
        self.data["run"]["finished_utc"] = "2026-10-11T00:00:01Z"
        with self.assertRaisesRegex(ValueError, "run duration"):
            self.run_check()
        self.data["run"]["finished_utc"] = "2026-10-11T00:00:05Z"
        self.assertTrue(self.run_check()["bundle_valid"])

    def test_missing_limits_bad_dimensions_and_timestamps_rejected(self):
        for change in (lambda d: d.update(limitations=[]), lambda d: d["map"].update(dimensions=[True, 2, 1]),
                       lambda d: d["run"].update(started_utc="2026-10-11T01:00:00Z"),
                       lambda d: d["run"].update(finished_utc="2026-10-11T00:01:00")):
            data = deepcopy(self.data)
            change(data)
            with self.assertRaises(ValueError):
                self.run_check(data)

    def test_cli_never_overwrites_and_does_not_launch_game(self):
        self.run_check()
        target = self.root / "report.json"
        args = [sys.executable, str(HELPER), str(self.manifest), "--expected-commit", self.sha,
                "--report", str(target)]
        result = subprocess.run(args, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        original = target.read_bytes()
        result = subprocess.run(args, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(target.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
