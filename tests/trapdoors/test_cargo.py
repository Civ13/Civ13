"""Offline guards for the two supported-to-unsupported hatch transitions."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "code/game/objects/structures/trapdoors.dm"


def proc(source, header):
    start = source.index(header)
    end = source.find("\n/", start + 1)
    return source[start:] if end == -1 else source[start:end]


class TrapdoorCargoTest(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding="utf-8")

    def test_opening_replays_unanchored_items_and_structures(self):
        opened = proc(self.source, "/trapdoor/door_opened()")
        self.assertIn("trapdoor_recheck_loose_cargo(loc)", opened)
        helper = proc(self.source, "/proc/trapdoor_recheck_loose_cargo(")
        self.assertIn("T.contents.Copy()", helper)
        gravity = helper.index("T.Entered(O)")
        for guard in ("QDELETED(O)", "O.loc != T", "O.anchored", "isitem(O)", "istype(O, /obj/structure)"):
            self.assertLess(helper.index(guard), gravity)
        self.assertNotIn("forceMove", helper)

    def test_wrench_removal_rechecks_hatch_turf_after_deletion(self):
        removal = proc(self.source, "/trapdoor/take_down_door(")
        site = removal.index("var/turf/unsupported_site = state ? null : loc")
        actor = removal.index("var/turf/T = get_turf(user)")
        recover = removal.index("new kit_type(T)")
        delete = removal.index("qdel(src)")
        recheck = removal.index("trapdoor_recheck_loose_cargo(unsupported_site)")
        self.assertTrue(site < actor < recover < delete < recheck)

    def test_players_still_prevent_opening_underfoot(self):
        opens = proc(self.source, "/trapdoor/canOpen(")
        self.assertIn("!state && (locate(/mob/living) in loc)", opens)


if __name__ == "__main__":
    unittest.main()
