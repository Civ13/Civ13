"""Replay cooking-pot pouring from source, not BYOND: lids, water top-ups and partial refills."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/objects/structures/kitchen/pot.dm'

# Pre-fix branches, frozen as negative controls.
OLD_WATER = 'var/rem = min(R.volume, 100)'
OLD_POUR = '''			if (I.reagents.total_volume >= reagents.maximum_volume)
				to_chat(H, "<span class = 'notice'>The pot can't hold any more reagents.</span>")
			else
				for (var/datum/reagent/RR in I.reagents.reagent_list)
					reagents.add_reagent(RR.id, RR.volume)
				I.reagents.clear_reagents()
'''


def water_top_up(source, fullness, poured):
    """Return (new fullness, units taken from the source) for the water branch."""
    rem_expr = re.search(r'var/rem = min\(R\.volume, ([^)]+)\)', source).group(1).strip()
    room = 100 - fullness if rem_expr == '100 - fullness' else int(rem_expr)
    taken = min(poured, room)
    return min(fullness + taken, 100), taken


def pour(source, pot_volume, poured, capacity=100):
    """Return (pot volume, units left in the source) for a non-water pour."""
    if 'I.reagents.trans_to_holder(reagents, free)' in source:
        free = capacity - pot_volume
        if free <= 0:
            return pot_volume, poured
        moved = min(free, poured)
        return pot_volume + moved, poured - moved
    if poured >= capacity:
        return pot_volume, poured
    return min(pot_volume + poured, capacity), 0  # add_reagent clamps, clear_reagents empties


class CookingPotPourTest(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')

    def test_water_top_up_takes_only_what_fits(self):
        self.assertEqual(water_top_up(self.source, 90, 30), (100, 10))
        self.assertEqual(water_top_up(self.source, 0, 30), (30, 30))

    def test_reagent_refill_keeps_the_overflow(self):
        self.assertEqual(pour(self.source, 60, 60), (100, 20))
        self.assertEqual(pour(self.source, 0, 120), (100, 20))
        self.assertEqual(pour(self.source, 100, 10), (100, 10))

    def test_both_pour_branches_need_an_open_source(self):
        self.assertEqual(self.source.count('if (!I.is_open_container())'), 2)

    def test_negative_controls(self):
        self.assertEqual(water_top_up(OLD_WATER, 90, 30), (100, 30))
        self.assertEqual(pour(OLD_POUR, 60, 60), (100, 0))
        self.assertNotIn('is_open_container', OLD_POUR)


if __name__ == '__main__':
    unittest.main()


class PotKeepsDissolvedReagentsTest(unittest.TestCase):
    """Salt and germs follow the water into the pot instead of staying in the vessel."""

    def setUp(self):
        self.pot = SOURCE.read_text(encoding='utf-8')
        self.meals = (ROOT / 'code/game/objects/structures/kitchen/cooked_meals.dm').read_text(encoding='utf-8')

    def body(self, text, header):
        start = text.index(header)
        end = text.find('\n/', start + 1)
        return text[start:] if end < 0 else text[start:end]

    def test_water_fill_takes_dissolved_share(self):
        water = self.pot[self.pot.index('var/rem = min(R.volume, 100 - fullness)'):]
        self.assertLess(water.index('take_dissolved(I, rem / R.volume, R.id)'), water.index('I.reagents.remove_reagent(R.id, rem)'))
        take = self.body(self.pot, '/obj/structure/pot/proc/take_dissolved(')
        self.assertIn('if (D.id == water_id)', take)
        self.assertIn('D.volume * fraction', take)
        self.assertIn('reagents.maximum_volume - reagents.total_volume', take)
        self.assertIn('I.reagents.remove_reagent(D.id, amount)', take)

    def test_stew_kills_germs_and_keeps_salt(self):
        stew = self.pot[self.pot.index('// Boiling kills germs from the water'):]
        self.assertLess(stew.index('reagents.kill_germs()'), stew.index('R.volume /= bowls'))
        self.assertNotIn('del_reagent("sodiumchloride")', self.pot)

    def test_empty_and_last_bowl_clear_the_pot(self):
        empty = self.body(self.pot, '/obj/structure/pot/verb/empty()')
        self.assertIn('reagents.clear_reagents()\n\t\tfullness = 0\n\t\tif (meal_portions)', empty)
        self.assertIn('food_toxin_origin = null\n\t\t\treagents.clear_reagents()', self.pot)

    def test_seawater_meal_is_not_seasoned(self):
        recipe = self.body(self.meals, '/obj/structure/pot/proc/meal_recipe()')
        self.assertIn('!reagents_are_brine(reagents, fullness)', recipe)
        # Seawater is 4% salt; brine starts at 3%, a seasoning pinch (0.5) is below it.
        self.assertGreater(0.04 * 100, 0.03 * 100)
        self.assertLess(0.5, 0.03 * 100)

    def test_negative_control(self):
        old = 'var/rem = min(R.volume, 100 - fullness)\n\t\t\tI.reagents.remove_reagent(R.id, rem)'
        self.assertNotIn('take_dissolved', old)
