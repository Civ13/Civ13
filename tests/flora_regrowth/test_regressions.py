"""Offline source contracts; the DM probe covers the queue at runtime."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def proc(source, path):
    match = re.search(rf"(?m)^{re.escape(path)}[^\n]*\n(?:(?:\t[^\n]*|)\n)*", source)
    if not match:
        raise AssertionError(f"missing {path}")
    return match.group()


class FloraRegressions(unittest.TestCase):
    def test_wither_queue_rotates_retained_entries(self):
        source = (ROOT / "code/modules/ecology/flora_regrowth.dm").read_text(encoding="utf-8")
        body = proc(source, "/datum/flora_regrowth/proc/wither_plants")
        self.assertIn("min(wild_plant_list.len, FLORA_WITHER_BUDGET * 4)", body)
        self.assertIn("wild_plant_list.Cut(1, 2)", body)
        self.assertEqual(body.count("wild_plant_list += P"), 2)
        self.assertLess(body.index("wild_plant_list.Cut(1, 2)"), body.index("qdel(P)"))

    def test_palm_revalidates_pot_cooldown_and_persistence(self):
        source = (ROOT / "code/game/objects/structures/wild.dm").read_text(encoding="utf-8")
        action = proc(source, "/obj/structure/wild/palm/attackby")
        commit = proc(source, "/obj/structure/wild/palm/proc/finish_sap_extraction")
        for expected in ("do_after(user, 50, src)", "persistence_admission_identity", "finish_sap_extraction(user, W, pot, pot_in_left_hand, save_identity)"):
            self.assertIn(expected, action)
        for expected in ("QDELETED(pot)", "cooldown_sap", "user.Adjacent(src)", "pot.loc != user", "user.l_hand != pot", "user.r_hand != pot", "save_identity != persistence_admission_identity"):
            self.assertIn(expected, commit)
        self.assertLess(commit.index("cooldown_sap = TRUE"), commit.index("qdel(pot)"))
        self.assertNotIn("qdel(user.l_hand)", action)
        self.assertNotIn("qdel(user.r_hand)", action)


if __name__ == "__main__":
    unittest.main()
