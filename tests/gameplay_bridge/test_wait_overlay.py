"""Source/drift and abstract wait controls; never execute or claim DM parity."""
import difflib
import hashlib
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "gameplay_bridge"))
from wait_overlay import BASE_COMMIT, BASE_RAW_SHA256, guarded_source, unguarded_source


def abstract_wait(source, *, delay=1, entry=True, wake=True, final=True, replace=False,
                  ordinary_cancel=False, enabled=True):
    """Bounded oracle for extracted hook phases, NOT a DM interpreter or runtime."""
    baseline = unguarded_source(source)
    assert guarded_source(baseline) == source
    captured = {"valid": entry}
    service_lease = captured
    cleanup = False
    if enabled and not captured["valid"]:
        return False, cleanup
    if delay:
        captured["valid"] = wake
        if replace:
            service_lease = {"valid": True}
        # Actual source has one capture, so replacement cannot change the guard.
        if ordinary_cancel or (enabled and not captured["valid"]):
            cleanup = True
            return False, cleanup
    captured["valid"] = final
    cleanup = True
    return not enabled or captured["valid"], cleanup


class WaitOverlayTests(unittest.TestCase):
    def setUp(self):
        self.path = ROOT / "code/_helpers/mobs.dm"
        # Historical accepted overlay ONLY; successor's shared helper is untouched.
        self.source = subprocess.check_output(["git", "show", "aeaf00ae77dfca70c24b05ccce46434629469571:code/_helpers/mobs.dm"], cwd=ROOT).decode().replace("\r\n", "\n")
        self.baseline = unguarded_source(self.source)

    def test_disabled_path_matches_immutable_owner_baseline_exactly(self):
        result = subprocess.run(["git", "show", BASE_COMMIT + ":code/_helpers/mobs.dm"],
                                cwd=ROOT, capture_output=True, timeout=10, check=True)
        baseline = result.stdout.decode().replace("\r\n", "\n")
        self.assertEqual(self.baseline, baseline)
        self.assertEqual(hashlib.sha256(result.stdout).hexdigest(), BASE_RAW_SHA256)
        self.assertEqual(guarded_source(baseline), self.source)
        # All disabled text is exactly preserved, including signature/defaults.
        self.assertEqual(abstract_wait(self.source, enabled=False), (True, True))
        self.assertEqual(abstract_wait(self.source, enabled=False, ordinary_cancel=True), (False, True))

    def test_hook_only_adds_conditional_checks_to_existing_wait(self):
        changes = list(difflib.ndiff(self.baseline.splitlines(), self.source.splitlines()))
        self.assertFalse(any(row.startswith("- ") for row in changes))
        self.assertEqual(self.source.count("gameplay_lease.valid()"), 3)
        capture = self.source.index("gameplay_bridge.wait_lease(user)")
        self.assertGreater(capture, self.source.index("if (!user || !user.may_do_after)", self.source.index("/proc/do_after(")))
        self.assertLess(capture, self.source.index("if (check_for_repeats)", capture))
        self.assertGreater(self.source.rindex("gameplay_lease.valid()"), self.source.index("qdel(progbar)", capture))
        self.assertEqual(self.source.count("gameplay_bridge.wait_lease(user)"), 1)

    def test_omission_controls_detect_missing_entry_wake_and_final(self):
        blocks = ["\tif (gameplay_lease && !gameplay_lease.valid())\n\t\treturn FALSE\n",
                  "\t\tif (gameplay_lease && !gameplay_lease.valid())\n\t\t\t. = FALSE\n\t\t\tbreak\n",
                  "\tif (gameplay_lease && !gameplay_lease.valid())\n\t\t. = FALSE\n"]
        for block in blocks:
            with self.subTest(block=block), self.assertRaises(ValueError):
                unguarded_source(self.source.replace(block, "", 1))

    def test_reacquisition_control_detected(self):
        mutation = self.source.replace("\t\tsleep(0.1)\n", "\t\tsleep(0.1)\n\t\tgameplay_lease = gameplay_bridge.wait_lease(user)\n", 1)
        with self.assertRaises(ValueError):
            unguarded_source(mutation)

    def test_old_cancelled_new_lease_abstract_oracle(self):
        self.assertEqual(abstract_wait(self.source, wake=False, replace=True), (False, True))

    def test_entry_wake_final_and_zero_delay_abstract_oracles(self):
        self.assertEqual(abstract_wait(self.source, entry=False), (False, False))
        self.assertEqual(abstract_wait(self.source, wake=False), (False, True))
        self.assertEqual(abstract_wait(self.source, final=False), (False, True))
        self.assertEqual(abstract_wait(self.source, delay=0, final=False), (False, True))
        self.assertEqual(abstract_wait(self.source, delay=0), (True, True))

    def test_production_wait_drift_rejects(self):
        with self.assertRaises(ValueError):
            guarded_source(self.baseline.replace("\t\tsleep(0.1)\n", "\t\tsleep(1)\n"))

    def test_historical_patch_is_exact_and_current_helper_remains_unmodified(self):
        patch = ROOT / "code/modules/gameplay_bridge/do_after.guard.patch"
        relative = "code/_helpers/mobs.dm"
        expected = "".join(difflib.unified_diff(self.baseline.splitlines(True), self.source.splitlines(True), fromfile="a/" + relative, tofile="b/" + relative))
        self.assertEqual(patch.read_text(encoding="utf-8"), expected)
        self.assertNotIn(b"\r\n", patch.read_bytes())
        current = self.path.read_text(encoding="utf-8")
        expected_current = subprocess.check_output(["git", "show", "331117df900476ded8afbc5317c1dedb6b884825:code/_helpers/mobs.dm"], cwd=ROOT).decode().replace("\r\n", "\n")
        self.assertEqual(current, expected_current)
        self.assertNotIn("CIV13_GAMEPLAY_WAIT_GUARDS", current)
        self.assertIn("user.survival_action_finished()", current)
        self.assertNotEqual(current, self.source)


if __name__ == "__main__":
    unittest.main()
