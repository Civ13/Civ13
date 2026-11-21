"""A missing hand does not count as a free hand for two-handed wielding (#6352)."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / "code/game/objects/items/weapons/material/twohanded.dm").read_text(encoding="utf-8-sig")


def block(header):
    start = SOURCE.index(header)
    nxt = re.search(r"\n(?=\S)", SOURCE[start + len(header):])
    return SOURCE[start:start + len(header) + nxt.start()] if nxt else SOURCE[start:]


class TwoHandedOffhandTest(unittest.TestCase):
    def test_wield_uses_offhand_helper(self):
        held = block("/obj/item/weapon/material/twohanded/update_held_icon()")
        self.assertIn("has_free_offhand(M)", held)
        self.assertNotIn("!M.l_hand) || (M.l_hand == src", held)

    def test_offhand_requires_empty_slot_and_present_hand(self):
        helper = block("/obj/item/weapon/material/twohanded/proc/has_free_offhand(mob/living/M)")
        self.assertIn("M.r_hand == src && !M.l_hand", helper)
        self.assertIn("offhand_slot = slot_l_hand", helper)
        self.assertIn("M.l_hand == src && !M.r_hand", helper)
        self.assertIn("offhand_slot = slot_r_hand", helper)
        self.assertIn("return H.has_organ_for_slot(offhand_slot)", helper)
        # Both hands busy (or not holding src) never wields.
        self.assertLess(helper.index("return FALSE"), helper.index("ishuman(M)"))


if __name__ == "__main__":
    unittest.main()
