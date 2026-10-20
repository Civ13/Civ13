"""Source/drift and abstract wait controls; never execute or claim DM parity."""
import difflib
import hashlib
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "gameplay_bridge"))
from wait_overlay import PUBLIC_BASE_SHA256, guarded_source, unguarded_source


class WaitOverlayTests(unittest.TestCase):
    def setUp(self):
        self.path = ROOT / "code/_helpers/mobs.dm"
        # In-memory abstract overlay on PUBLIC source, never applied/accepted.
        self.source = self.path.read_text(encoding="utf-8")
        self.baseline = unguarded_source(self.source)

    def test_abstract_disabled_path_matches_unmodified_public_helper(self):
        baseline = self.baseline
        self.assertEqual(self.baseline, baseline)
        self.assertEqual(hashlib.sha256(baseline.encode()).hexdigest(), PUBLIC_BASE_SHA256)
        self.assertEqual(guarded_source(baseline), self.source)
        # All disabled text is exactly preserved, including signature/defaults.

    def test_exact_explicit_patch_and_no_ambient_capture(self):
        patch = "".join(difflib.unified_diff(self.baseline.splitlines(True), self.source.splitlines(True),
                       fromfile="a/code/_helpers/mobs.dm",tofile="b/code/_helpers/mobs.dm"))
        self.assertEqual((ROOT/"code/modules/gameplay_bridge/do_after.guard.patch").read_text(),patch)
        self.assertEqual(self.source.count("gameplay_lease = gameplay_context"),1)
        self.assertNotIn("wait_lease(",self.source)

    def test_omission_controls_detect_missing_entry_wake_and_final(self):
        blocks = ["\t\tif (!gameplay_lease.claim_gather_wait(user, target))\n\t\t\treturn FALSE\n",
                  "\t\tif (gameplay_lease && !gameplay_lease.valid())\n\t\t\t. = FALSE\n\t\t\tbreak\n",
                  "\tif (gameplay_lease && !gameplay_lease.valid())\n\t\t. = FALSE\n"]
        for block in blocks:
            with self.subTest(block=block), self.assertRaises(ValueError):
                unguarded_source(self.source.replace(block, "", 1))

    def test_reacquisition_control_detected(self):
        mutation = self.source.replace("\t\tsleep(0.1)\n", "\t\tsleep(0.1)\n\t\tgameplay_lease = gameplay_bridge.wait_lease(user)\n", 1)
        with self.assertRaises(ValueError):
            unguarded_source(mutation)

    def test_production_wait_drift_rejects(self):
        with self.assertRaises(ValueError):
            guarded_source(self.baseline.replace("\t\tsleep(0.1)\n", "\t\tsleep(1)\n"))

    def test_type_and_callback_omission_refuses(self):
        for anchor in ("if (!istype(gameplay_context, /datum/gameplay_action_lease))",
                       "user.survival_action_started()", "user.survival_action_finished()"):
            with self.subTest(anchor=anchor), self.assertRaises(ValueError):
                unguarded_source(self.source.replace(anchor,"OMITTED",1))


if __name__ == "__main__":
    unittest.main()
