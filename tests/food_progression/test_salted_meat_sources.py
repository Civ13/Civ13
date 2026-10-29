"""Offline source contracts; these do not execute DM or a savefile."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
MEAT = (ROOT / "code/modules/reagents/reagent_containers/food/snacks/meat.dm").read_text(encoding="utf-8")
CONDIMENT = (ROOT / "code/modules/reagents/reagent_containers/food/condiment.dm").read_text(encoding="utf-8")
RACK = (ROOT / "code/modules/1713/production.dm").read_text(encoding="utf-8")
SNACKS = (ROOT / "code/modules/reagents/reagent_containers/food/snacks.dm").read_text(encoding="utf-8")
PERSISTENCE = (ROOT / "code/modules/persistence/functions.dm").read_text(encoding="utf-8")
SAVING = (ROOT / "code/modules/persistence/saving.dm").read_text(encoding="utf-8")


class SaltedMeatSourceTests(unittest.TestCase):
    def test_interaction_and_payment_precede_generic_condiment_transfer(self):
        self.assertLess(CONDIMENT.index("snack.salt_meat(src, user)"), CONDIMENT.index("reagents.trans_to_obj(target"))
        proc = MEAT.split("/proc/salt_meat(", 1)[1].split("\n/obj/", 1)[0]
        for guard in ("if (salted_meat)", "if (rotten || decay <= 0", 'has_reagent("sodiumchloride", 1)'):
            self.assertLess(proc.index(guard), proc.index('remove_reagent("sodiumchloride", 1)'))
        self.assertEqual(proc.count('remove_reagent("sodiumchloride", 1)'), 1)
        self.assertLess(proc.index('remove_reagent("sodiumchloride", 1)'), proc.index("mark_salted_meat()"))

    def test_lifetimes_retain_fraction_and_drying_carries_salt(self):
        self.assertIn("? 4 : 2", MEAT)
        self.assertIn("decay *= multiplier", MEAT)
        self.assertIn("decaytimer *= multiplier", MEAT)
        self.assertIn("cutlet.decaytimer = decaytimer * cutlet.decay / decay", MEAT)
        self.assertLess(RACK.index("output_meat.mark_salted_meat()"), RACK.index("input_food.decaytimer * output_food.decay / original_decay"))
        self.assertIn("if (input_meat.salted_meat)", RACK)
        for age in (0, 1200, 4499):
            salted_age, salted_limit = age * 2, 9000 * 2
            dried_limit = 150000 * 4
            self.assertAlmostEqual(salted_age / salted_limit, (salted_age * dried_limit / salted_limit) / dried_limit)

    def test_persistence_uses_durable_state_and_holder_graph(self):
        self.assertIn("var/salted_meat = FALSE", SNACKS)
        self.assertIn("src.vars[key] != initial(src.vars[key])", PERSISTENCE)
        self.assertIn('changing_vars += "reagents"', SAVING)
        self.assertNotIn('key == "salted_meat"', PERSISTENCE)
        self.assertNotIn('key == "decaytimer"', PERSISTENCE)


if __name__ == "__main__":
    unittest.main()
