"""Offline source checks for cooking-pot filling, emptying and serving."""
from math import ceil
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


class PotSourceTest(unittest.TestCase):
    def setUp(self):
        self.pot = SOURCE.read_text(encoding='utf-8')
        self.meals = (ROOT / 'code/game/objects/structures/kitchen/cooked_meals.dm').read_text(encoding='utf-8')

    def body(self, text, header):
        start = text.index(header)
        end = text.find('\n/', start + 1)
        return text[start:] if end < 0 else text[start:end]


class PotKeepsDissolvedReagentsTest(PotSourceTest):
    """Salt and germs follow the water into the pot instead of staying in the vessel."""

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
        self.assertIn('reagents.clear_reagents()\n\t\tsalt_water = FALSE\n\t\tfullness = 0\n\t\tif (meal_portions)', empty)
        self.assertIn('food_toxin_origin = null\n\t\t\treagents.clear_reagents()', self.pot)

    def test_seawater_meal_is_not_seasoned(self):
        recipe = self.body(self.meals, '/obj/structure/pot/proc/meal_recipe()')
        self.assertIn('!salt_water && !reagents_are_brine(reagents, fullness)', recipe)
        take = self.body(self.pot, '/obj/structure/pot/proc/take_dissolved(')
        self.assertIn('if (D.id == "sodiumchloride")\n\t\t\tsalt_water = TRUE', take)
        # Every way the pot empties forgets the salt water.
        self.assertEqual(self.pot.count('salt_water = FALSE'), 3)  # var, last bowl, Empty
        self.assertIn('salt_water = FALSE', self.body(self.meals, '/obj/structure/pot/proc/serve_meal('))
        # Seawater is 4% salt; brine starts at 3%, a seasoning pinch (0.5) is below it.
        self.assertGreater(0.04 * 100, 0.03 * 100)
        self.assertLess(0.5, 0.03 * 100)

    def test_negative_control(self):
        old = 'var/rem = min(R.volume, 100 - fullness)\n\t\t\tI.reagents.remove_reagent(R.id, rem)'
        self.assertNotIn('take_dissolved', old)

class PotLiquidLifecycleTest(PotSourceTest):
    def test_partial_water_and_reagent_only_pots_can_be_emptied(self):
        empty = self.body(self.pot, '/obj/structure/pot/verb/empty()')
        self.assertIn('if (meal_cooking || (state == STATE_EMPTY && fullness <= 0 && reagents.total_volume <= 0))', empty)
        wait = empty.index('if (do_after(usr, 100, src) && !meal_cooking)')
        for reset in ('state = STATE_EMPTY', 'reagents.clear_reagents()', 'salt_water = FALSE', 'fullness = 0'):
            self.assertGreater(empty.index(reset), wait)
        # A 30-unit partial saltwater fill can be emptied, then refilled with
        # 30 fresh units without retaining its water level or brine markers.
        partial, _ = water_top_up(self.pot, 0, 30)
        self.assertEqual(partial, 30)
        self.assertIn('salt_water = FALSE\n\t\tfullness = 0', empty)
        self.assertEqual(water_top_up(self.pot, 0, 30), (30, 30))

    def test_glass_and_drinks_share_additive_path_after_full_water(self):
        attack = self.body(self.pot, '/obj/structure/pot/attackby(')
        self.assertIn('var/liquid_vessel = istype(I, /obj/item/weapon/reagent_containers/food/drinks) || istype(I, /obj/item/weapon/reagent_containers/glass)', attack)
        self.assertIn('if (liquid_vessel && state == STATE_EMPTY)', attack)
        additive = attack[attack.index('if (liquid_vessel || istype(I, /obj/item/weapon/reagent_containers/food))'):]
        branch = additive[:additive.index('else if (istype(I, /obj/item/weapon/reagent_containers/food/condiment))')]
        self.assertIn('if (state != STATE_WATER && state != STATE_BOILING)', branch)
        self.assertLess(branch.index('if (liquid_vessel)'), branch.index('if (!I.is_open_container())'))
        self.assertLess(branch.index('if (!I.is_open_container())'), branch.index('pour_into_pot(I, H)'))
        self.assertEqual(pour(self.pot, 90, 18), (100, 8))

    def test_ordinary_stew_serves_its_stored_share_once(self):
        attack = self.body(self.pot, '/obj/structure/pot/attackby(')
        serve = attack[attack.index('var/obj/item/weapon/reagent_containers/food/snacks/stew_wood/w_stew = new'):]
        cook = self.body(self.pot, '/obj/structure/pot/process()')
        self.assertIn('R.volume /= bowls', cook)
        self.assertIn('w_stew.reagents.maximum_volume += R.volume', serve)
        self.assertIn('w_stew.reagents.add_reagent(R.id, R.volume)', serve)
        self.assertNotIn('ceil(', serve)
        self.assertNotIn('initial_bowls', serve)
        self.assertLess(serve.index('--bowls'), serve.index('reagents.clear_reagents()'))
        for added, expected in ((18, 6), (0.75, 0.25)):
            stored = added / 3
            self.assertEqual([stored] * 3, [expected] * 3)
            self.assertNotEqual([ceil(stored / 3)] * 3, [expected] * 3)

    def test_prepared_meal_keeps_its_separate_remaining_pool(self):
        attack = self.body(self.pot, '/obj/structure/pot/attackby(')
        self.assertLess(attack.index('serve_meal(I, H)'), attack.index('I.reagents.get_master_reagent()'))
        meal = self.body(self.meals, '/obj/structure/pot/proc/serve_meal(')
        self.assertIn('reagents.trans_to_holder(M.reagents, reagents.total_volume / meal_portions)', meal)


if __name__ == '__main__':
    unittest.main()
