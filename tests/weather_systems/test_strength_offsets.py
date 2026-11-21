"""Offline source-projection comparison; this does not run the BYOND engine."""
import math
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "save_movement"))
import source_adapter

DECLARATION = "/datum/weather_system/proc/strength_at"
BEFORE = (ROOT / "tests/weather_systems/strength_before.dm.txt").read_text(encoding="utf-8")
AFTER = (ROOT / "code/modules/1713/weather_systems.dm").read_text(encoding="utf-8")


def sample(source, x, y, cx=0, cy=0, rx=40, ry=25, wobble=0, power=0.7):
    calls = {"x": 0, "y": 0, "power": 0}

    def centre_x():
        calls["x"] += 1
        return cx

    def centre_y():
        calls["y"] += 1
        return cy

    def system_power():
        calls["power"] += 1
        return power

    env = {"centre_x": centre_x, "centre_y": centre_y, "power": system_power,
           "radius_x": rx, "radius_y": ry, "wobble": wobble,
           "sqrt": math.sqrt, "sin": lambda angle: math.sin(math.radians(angle))}
    fn = source_adapter.project(source, DECLARATION, "x, y", env)
    return fn(x, y), calls


class StrengthOffsetsTests(unittest.TestCase):
    def test_before_and_after_match_across_edges_and_translations(self):
        # Fixed centres model different positions of a moving system. The Python
        # projection is not a model of BYOND numeric precision or scheduling.
        for cx, cy, rx, ry, wobble, power in ((0, 0, 40, 25, 0, .7),
                                               (130.25, -27.5, 13, 71, 93, 1),
                                               (-6, 8, 2, 3, -21, 0)):
            for dx in (-1.101, -1.1, -1.0, -.73, 0, .61, 1.0, 1.1, 1.101):
                for dy in (-1.101, -1.0, -.5, 0, .42, 1.0, 1.101):
                    with self.subTest(cx=cx, cy=cy, dx=dx, dy=dy):
                        args = (cx + dx * rx, cy + dy * ry, cx, cy, rx, ry, wobble, power)
                        before, old_calls = sample(BEFORE, *args)
                        after, new_calls = sample(AFTER, *args)
                        self.assertEqual(before, after)
                        self.assertEqual(old_calls["power"], new_calls["power"])
                        self.assertEqual(old_calls["y"] > 0, new_calls["y"] > 0)
                        self.assertLessEqual(new_calls["x"], old_calls["x"])
                        self.assertLessEqual(new_calls["y"], old_calls["y"])

    def test_guard_order_and_reused_centres(self):
        _, old = sample(BEFORE, 45, 0)
        _, new = sample(AFTER, 45, 0)
        self.assertEqual(old, {"x": 1, "y": 0, "power": 0})
        self.assertEqual(old, new)
        _, old = sample(BEFORE, 0, 0)
        _, new = sample(AFTER, 0, 0)
        self.assertEqual(old, {"x": 2, "y": 2, "power": 1})
        self.assertEqual(new, {"x": 1, "y": 1, "power": 1})

    def test_negative_control_detects_wrong_edge_term(self):
        original = "offset_x * 9 + offset_y * 5 + wobble"
        self.assertIn(original, AFTER)
        broken = AFTER.replace(original, "offset_x * 9 + offset_y * 9 + wobble", 1)
        before, _ = sample(BEFORE, 25, 9, wobble=10)
        wrong, _ = sample(broken, 25, 9, wobble=10)
        self.assertNotEqual(before, wrong)


if __name__ == "__main__":
    unittest.main()
