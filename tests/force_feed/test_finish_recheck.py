"""Force-feeding rechecks reach and mouth coverage after its wait (#6249)."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8-sig")


def block(text, header):
    start = text.index(header)
    nxt = re.search(r"\n(?=\S)", text[start + len(header):])
    return text[start:start + len(header) + nxt.start()] if nxt else text[start:]


HELPERS = read("code/game/mob/mob_helpers.dm")
PILL = read("code/modules/reagents/reagent_containers/pill.dm")
SNACKS = read("code/modules/reagents/reagent_containers/food/snacks.dm")
KITCHEN = read("code/game/objects/items/weapons/material/kitchen.dm")


class ForceFeedRecheckTest(unittest.TestCase):
    def test_helper_requires_reach_and_feedable_mouth(self):
        helper = block(HELPERS, "/mob/proc/can_finish_force_feed(mob/feeder, food)")
        self.assertIn("QDELETED(src) || QDELETED(feeder)", helper)
        self.assertIn("feeder != src && !feeder.Adjacent(src)", helper)
        self.assertIn("return can_force_feed(feeder, food)", helper)

    def assert_recheck_before(self, text, wait, effect):
        recheck = text.index("can_finish_force_feed(user,", text.index(wait))
        self.assertLess(recheck, text.index(effect, text.index(wait)))

    def test_pill_rechecks_before_swallowing(self):
        self.assertIn("!do_mob(user, M) || loc != user || !M.can_finish_force_feed(user, src)", PILL)
        self.assert_recheck_before(PILL, "!do_mob(user, M)", "user.drop_from_inventory(src)")

    def test_food_rechecks_before_feeding(self):
        self.assert_recheck_before(SNACKS, "do_after(user, 30, M, check_for_repeats = FALSE)",
                                   "user.visible_message(\"<span class='danger'>[user] feeds [M] [src].</span>\")")

    def test_utensil_rechecks_before_feeding(self):
        wait = "do_mob(user, M, 5 SECONDS)"
        self.assert_recheck_before(KITCHEN, wait, "reagents.trans_to_mob(M, reagents.total_volume, CHEM_INGEST)")
        self.assertIn("!reagents.total_volume || !M.can_finish_force_feed(user, loaded)", KITCHEN)


if __name__ == "__main__":
    unittest.main()
