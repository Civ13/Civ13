"""Raising a lowered sterile mask restores its face coverage (#6713)."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / "code/game/objects/items/clothing/masks/medical.dm").read_text(encoding="utf-8-sig")


def block(header):
    start = SOURCE.index(header)
    nxt = re.search(r"\n(?=\S)", SOURCE[start + len(header):])
    return SOURCE[start:start + len(header) + nxt.start()] if nxt else SOURCE[start:]


class SterileMaskToggleTest(unittest.TestCase):
    def test_raise_restores_and_lower_clears_coverage(self):
        toggle = block("/obj/item/clothing/mask/sterile/verb/toggle()")
        raise_branch = toggle[toggle.index("if (toggled)"):toggle.index("else if (!toggled)")]
        lower_branch = toggle[toggle.index("else if (!toggled)"):]
        self.assertIn("body_parts_covered = initial(body_parts_covered)", raise_branch)
        self.assertIn("toggled = FALSE", raise_branch)
        self.assertIn("body_parts_covered = null", lower_branch)
        self.assertIn("toggled = TRUE", lower_branch)

    def test_initial_coverage_is_the_face(self):
        mask = block("/obj/item/clothing/mask/sterile\n")
        self.assertIn("body_parts_covered = FACE", mask)


if __name__ == "__main__":
    unittest.main()
