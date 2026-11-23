"""Offline projection of the bounded leeward slide, not a BYOND flight test."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / "code/modules/naval/hull_roll.dm").read_text()
LIMIT = int(re.search(r"#define HULL_ROLL_SLIDE_TILES (\d+)", SOURCE)[1])


def slide(start, dx, deck, clear_sea, covered=(), blocked_edges=()):
    at = start
    for _ in range(LIMIT):
        nxt = at + dx
        if (at, nxt) in blocked_edges or nxt not in clear_sea:
            break
        if nxt not in deck:
            at = nxt
            break
        if nxt in covered:
            break
        at = nxt
    return at


class HullRoll(unittest.TestCase):
    def test_can_go_over_both_rails_and_stops_at_first_water_tile(self):
        sea = range(-6, 7)
        self.assertEqual(slide(1, 1, range(0, 4), sea), 4)
        self.assertEqual(slide(1, -1, range(0, 4), sea), -1)

    def test_wide_deck_never_scans_more_than_four_tiles(self):
        self.assertEqual(slide(1, 1, range(12), range(20)), 5)

    def test_never_crosses_wall_or_covered_space(self):
        self.assertEqual(slide(1, 1, range(5), range(6), covered={3}), 2)
        self.assertEqual(
            slide(1, 1, range(5), range(6), blocked_edges={(2, 3)}), 2
        )

    def test_no_destination_outside_valid_water(self):
        self.assertEqual(slide(3, 1, range(4), range(4)), 3)
        self.assertEqual(slide(0, -1, range(4), range(4)), 0)

    def test_production_keeps_slide_on_authoritative_cells(self):
        for guard in (
            "contains(T) && is_open_sea(T) && hull_floor_in(T)",
            "locate(/obj/roof) in T",
            "hull_floor_in(T) || craft_at(T)",
            "hull_gun_port(R)",
            "HULL_ROLL_SLIDE_TILES",
            "L.loc == T && !QDELETED(L) && L.stat != DEAD && !L.buckled && !L.travel_held()",
            "L.forceMove(destination)",
            "L.Weaken(3)",
            "C.overlays -= wash",
        ):
            with self.subTest(guard=guard):
                self.assertIn(guard, SOURCE)
        # No logical hull/cover or actor presentation mutation.
        for target in ("B.z =", "B.dir =", "L.transform =", "C.transform ="):
            self.assertNotIn(target, SOURCE)


if __name__ == "__main__":
    unittest.main()
