"""Project the production carry curves and protect the player's feedback wiring."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / "code/game/mob/mob_movement.dm"
CHECK = ROOT / "code/modules/1713/movement_check.dm"
spec = importlib.util.spec_from_file_location("source_adapter", ROOT / "tests/save_movement/source_adapter.py")
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


class CarryLoad(unittest.TestCase):
    def setUp(self):
        self.source = PATH.read_text(encoding="utf-8")
        self.reference = adapter.project(self.source, "/proc/movement_carry_reference", "strength", {})
        self.slowdown = adapter.project(self.source, "/proc/movement_carry_slowdown", "weight, reference, heavy", {})

    def test_weak_and_average_reference_are_unchanged(self):
        self.assertAlmostEqual(self.reference(0.5), 44.25)
        self.assertEqual(self.reference(1.0), 59)

    def test_training_raises_the_free_load_threshold(self):
        self.assertGreater(self.reference(1.5) * 0.25, 22)
        self.assertEqual(self.slowdown(20, self.reference(1.5), False), 0)
        self.assertEqual(self.slowdown(20, self.reference(1), False), 0.33)

    def test_weight_bands_still_stop_short_of_a_hard_cap(self):
        for weight, expected in ((0, 0), (14.75, 0), (15, 0.33), (30, 0.44), (39, 0.55),
                                 (45, 0.66), (51, 0.77), (54, 0.88), (57, 0.99), (500, 0.99)):
            self.assertEqual(self.slowdown(weight, self.reference(1), False), expected, weight)
        self.assertEqual(self.slowdown(1, self.reference(1), True), 0.33)

    def test_movement_and_player_report_share_the_same_data(self):
        self.assertIn(". *= 1 + carried_movement_slowdown()", self.source)
        self.assertIn('report["comfort"] = reference * 0.25', self.source)
        check = CHECK.read_text(encoding="utf-8")
        for token in ("carried_movement_slowdown(load_info)", "Carried weight:", "Training Strength",
                      'load_info["heavy"]'):
            self.assertIn(token, check)


if __name__ == "__main__":
    unittest.main()
