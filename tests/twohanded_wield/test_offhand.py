"""A missing hand does not count as a free hand for two-handed wielding (#6352)."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8-sig")


SOURCE = read("code/game/objects/items/weapons/material/twohanded.dm")
INVENTORY = read("code/game/mob/living/carbon/human/inventory.dm")
ORGANS = read("code/modules/organs/organ_external.dm")


def block(header, text=None):
    text = SOURCE if text is None else text
    start = text.index(header)
    nxt = re.search(r"\n(?=\S)", text[start + len(header):])
    return text[start:start + len(header) + nxt.start()] if nxt else text[start:]


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

    def test_each_holding_hand_checks_the_opposite_hand(self):
        helper = block("/obj/item/weapon/material/twohanded/proc/has_free_offhand(mob/living/M)")
        lines = [line.strip() for line in helper.splitlines()]
        right = lines.index("if(M.r_hand == src && !M.l_hand)")
        self.assertEqual(lines[right + 1], "offhand_slot = slot_l_hand")
        left = lines.index("else if(M.l_hand == src && !M.r_hand)")
        self.assertEqual(lines[left + 1], "offhand_slot = slot_r_hand")

    def test_limb_changes_refresh_held_items(self):
        refresh = block("/mob/living/human/proc/refresh_held_items()", INVENTORY)
        self.assertIn("l_hand.update_held_icon()", refresh)
        self.assertIn("r_hand.update_held_icon()", refresh)
        drop = block("/obj/item/organ/external/proc/droplimb(", ORGANS)
        self.assertLess(drop.index("removed(null, ignore_children)"), drop.index("victim.refresh_held_items()"))
        replaced = block("/obj/item/organ/external/replaced(var/mob/living/human/target)", ORGANS)
        self.assertLess(replaced.index("owner.organs_by_name[limb_name] = src"), replaced.index("owner.refresh_held_items()"))


if __name__ == "__main__":
    unittest.main()
