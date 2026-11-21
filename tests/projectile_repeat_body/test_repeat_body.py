"""Offline source-order regression for projectile body traversal.

This models the guarded control flow; it does not execute BYOND or benchmark it.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "code/modules/projectiles/projectile.dm"
BASELINE = Path(__file__).with_name("before.dm.txt")


def parse_guards(text):
    lines = [line.strip() for line in text.splitlines()
             if line.strip() and not line.lstrip().startswith("//")]
    expected = {
        "if (L.loc != T && !body_in_line(L, T))": "geometry",
        "if (L in bodies_passed)": "seen",
        "bodies_passed += L": "add",
    }
    result = []
    while lines:
        line = lines.pop(0)
        if line not in expected:
            raise AssertionError(f"Unexpected body guard: {line}")
        op = expected[line]
        if op != "add" and (not lines or lines.pop(0) != "continue"):
            raise AssertionError(f"Missing continue after {line}")
        result.append(op)
    if sorted(result) != ["add", "geometry", "seen"]:
        raise AssertionError(f"Unexpected guard sequence: {result}")
    return result


def source_guards():
    text = SOURCE.read_text(encoding="utf-8")
    marker = "var/mob/living/L = AM"
    assert text.count(marker) == 1
    text = text.split(marker, 1)[1].split(
        "if (L != original && height_passes_over(los_target_top(L)))", 1)[0]
    return parse_guards(text)


def simulate(guards, events, initial=()):
    passed = list(initial)
    hits, clips, membership = [], [], []
    for body, location, tile, intersects in events:
        for op in guards:
            if op == "seen":
                membership.append((body, tile))
                if body in passed:
                    break
            elif op == "geometry":
                if location != tile:
                    clips.append((body, tile))
                    if not intersects:
                        break
            else:
                passed.append(body)
        else:
            hits.append((body, tile))
    return hits, passed, clips, membership


class RepeatBodyTest(unittest.TestCase):
    def setUp(self):
        self.before = parse_guards(BASELINE.read_text(encoding="utf-8"))
        self.after = source_guards()

    def test_later_crossing_and_repeated_body(self):
        events = [
            ("A", "home", "first", False),
            ("A", "home", "second", True),
            ("A", "home", "third", True),
            ("B", "direct", "direct", False),
            ("B", "direct", "direct", False),
        ]
        before, after = (simulate(order, events) for order in (self.before, self.after))
        self.assertEqual(before[:2], after[:2])
        self.assertEqual(after[0], [("A", "second"), ("B", "direct")])
        self.assertEqual(after[1], ["A", "B"])
        self.assertEqual(len(before[2]), 3)
        self.assertEqual(len(after[2]), 2)
        # The fresh miss now incurs a membership lookup: this is not a timing result.
        self.assertIn(("A", "first"), after[3])
        self.assertNotIn(("A", "first"), before[3])

    def test_initially_passed_body_is_not_clipped(self):
        event = [("A", "home", "other", True)]
        before = simulate(self.before, event, initial=("A",))
        after = simulate(self.after, event, initial=("A",))
        self.assertEqual(before[:2], after[:2])
        self.assertEqual(before[2], [("A", "other")])
        self.assertEqual(after[2], [])

    def test_negative_control_recording_before_clipping_loses_later_hit(self):
        events = [("A", "home", "first", False),
                  ("A", "home", "second", True)]
        wrong = simulate(["seen", "add", "geometry"], events)
        self.assertEqual(simulate(self.before, events)[0], [("A", "second")])
        self.assertNotEqual(wrong[0], simulate(self.after, events)[0])


if __name__ == "__main__":
    unittest.main()
