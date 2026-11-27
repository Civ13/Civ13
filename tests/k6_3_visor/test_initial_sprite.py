"""The forged K6-3 starts with the raised visor shown by its toggle."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / "code/modules/1713/apparel_modern.dm").read_text(encoding="utf-8")
HELMET = "/obj/item/clothing/head/helmet/modern/sovietfacehelmet/welding/nomads"


def block(header):
    return re.search(rf"^{re.escape(header)}[^\n]*\n((?:\t[^\n]*\n)+)", SOURCE, re.M)[1]


class K63VisorTest(unittest.TestCase):
    def test_fresh_helmet_looks_raised(self):
        fresh = block(HELMET + " ")
        toggle = block(HELMET + "/verb/toggle_visor()")
        raise_visor, lower_visor = toggle.split("else if (!toggled)", 1)
        self.assertIn("var/toggled = FALSE", fresh)
        self.assertIn("\tbody_parts_covered = HEAD\n", fresh)
        for field in ("icon_state", "item_state"):
            with self.subTest(field=field):
                pattern = rf'^\s*{field} = "([^"]+)"'
                initial_state = re.search(pattern, fresh, re.M)[1]
                raised_state = re.search(pattern, raise_visor, re.M)[1]
                lowered_state = re.search(pattern, lower_visor, re.M)[1]
                self.assertEqual(initial_state, raised_state)
                self.assertNotEqual(initial_state, lowered_state)


if __name__ == "__main__":
    unittest.main()
