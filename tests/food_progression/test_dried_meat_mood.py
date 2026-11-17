"""Offline source contract: dried meat feeds without lifting mood."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SNACKS = (ROOT / "code/modules/reagents/reagent_containers/food/snacks.dm").read_text(encoding="utf-8")
COMPLEX = (ROOT / "code/modules/1713/complex_production.dm").read_text(encoding="utf-8")
LEISURE = (ROOT / "code/modules/reagents/reagent_containers/food/snacks/mood_leisure.dm").read_text(encoding="utf-8")


def type_body(source, path):
    body = re.split(r"\n" + re.escape(path) + r"[ \t]*(?://[^\n]*)?\n", source, 1)[1]
    return re.split(r"\n(?=/)", body, 1)[0]


class DriedMeatMoodTests(unittest.TestCase):
    def test_dried_meat_has_no_mood_bonus(self):
        body = type_body(SNACKS, "/obj/item/weapon/reagent_containers/food/snacks/driedmeat")
        self.assertRegex(body, r"\n\tsatisfaction = 0\b")
        # Nutrition is unchanged.
        self.assertIn("nutriment_amt = 3", body)
        self.assertIn("biteamount = 3", body)

    def test_minced_dried_meat_inherits_without_override(self):
        body = type_body(COMPLEX, "/obj/item/weapon/reagent_containers/food/snacks/driedmeat/minced_driedmeat")
        self.assertNotIn("satisfaction", body)

    def test_table_meal_lift_needs_positive_satisfaction(self):
        self.assertIn("satisfaction > 0 && (locate(/obj/structure/table)", LEISURE)


if __name__ == "__main__":
    unittest.main()
