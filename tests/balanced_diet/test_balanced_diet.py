"""Offline contracts for the balanced diet (issue #3313). No compiler or world is started.

Native behaviour is covered by run.py and probe.dm; these checks keep the taste
taxonomy tied to reachable foods and keep existing hunger/digestion untouched.
"""
from pathlib import Path
import importlib.util
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
DIET = ROOT / 'code/modules/diet/diet.dm'
FOODS = ROOT / 'code/modules/reagents/Chemistry-Reagents/Chemistry-Reagents-Food-Drinks.dm'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def dm_list_block(source, name):
    start = source.index('var/global/list/' + name + ' = list(')
    depth = 0
    for index in range(source.index('(', start), len(source)):
        if source[index] == '(':
            depth += 1
        elif source[index] == ')':
            depth -= 1
            if not depth:
                return source[start:index + 1]
    raise AssertionError(name + ' is not closed')


def taste_categories():
    block = dm_list_block(DIET.read_text(encoding='utf-8'), 'diet_taste_categories')
    return {name: re.findall(r'"([^"]+)"', items)
            for name, items in re.findall(r'"([^"]+)" = list\(([^)]*)\)', block)}


# Where each taste flavour enters ordinary play, as a food constructor's flavour
# descriptor or a nutritional reagent with a fixed taste identity.
SOURCES = {
    'code/modules/reagents/reagent_containers/food/grown.dm': (
        'fruit', 'rice', 'wheat', 'oats', 'barley', 'tomato', 'potato', 'beans',
        'cabbage', 'carrot', 'corn', 'turnip', 'mushroom'),
    'code/game/objects/structures/berries.dm': ('sweetness',),
    'code/modules/reagents/reagent_containers/food/snacks.dm': ('egg',),
}
REAGENT_SOURCES = {
    'meat': ('protein', 'code/modules/reagents/reagent_containers/food/snacks/meat.dm'),
    'honey': ('honey', 'code/modules/reagents/reagent_containers/food/grown.dm'),
}


class TasteTaxonomy(unittest.TestCase):
    def test_every_category_has_two_distinct_unshared_flavours(self):
        categories = taste_categories()
        self.assertGreaterEqual(len(categories), 4)
        seen = set()
        for name, flavours in categories.items():
            self.assertEqual(len(flavours), len(set(flavours)), name)
            self.assertGreaterEqual(len(flavours), 2, name)
            self.assertFalse(seen & set(flavours), name)
            seen |= set(flavours)

    def test_every_flavour_is_carried_by_a_reachable_food(self):
        reachable = {}
        for path, flavours in SOURCES.items():
            source = read(path)
            for flavour in flavours:
                if re.search(r'nutriment_desc = list\("' + re.escape(flavour) + r'" = ', source):
                    reachable[flavour] = path
        for flavour, (reagent, path) in REAGENT_SOURCES.items():
            if 'add_reagent("' + reagent + '"' in read(path) and '"' + reagent + '" = "' + flavour + '"' in DIET.read_text(encoding='utf-8'):
                reachable[flavour] = path
        for name, flavours in taste_categories().items():
            for flavour in flavours:
                self.assertIn(flavour, reachable, f'{name}: {flavour} has no reachable food source')

    def test_egg_and_honey_have_production_routes(self):
        self.assertIn('snacks/egg/E = new', read('code/game/mob/living/simple_animal/friendly/birds.dm'))
        self.assertIn('snacks/honeycomb(loc)', read('code/modules/1713/beekeeping.dm'))


class ExistingSystemsUnchanged(unittest.TestCase):
    def test_nutriment_keeps_hunger_digestion_then_records_diet(self):
        source = FOODS.read_text(encoding='utf-8')
        body = source[source.index('/datum/reagent/nutriment/affect_ingest('):source.index('/datum/reagent/nutriment/glucose')]
        self.assertIn('M.nutrition += nutriment_factor * removed', body)
        self.assertIn('M.bowels += (nutriment_factor * removed)/6', body)
        self.assertLess(body.index('M.nutrition +='), body.index('M.diet_intake(src, removed)'))

    def test_drinks_only_record_real_nutrition(self):
        source = FOODS.read_text(encoding='utf-8')
        body = source[source.index('/datum/reagent/drink/affect_ingest('):]
        body = body[:body.index('\n/datum/')]
        self.assertIn('M.nutrition += nutrition * removed', body)
        self.assertIn('if (nutrition > 0)\n\t\tM.diet_intake(src, removed)', body)

    def test_life_uses_diet_recovery_and_keeps_hunger_rates(self):
        life = read('code/game/mob/living/carbon/human/human_life.dm')
        self.assertEqual(life.count('handle_diet()'), 1)
        self.assertEqual(life.count('diet_recover_stamina()'), 1)
        self.assertNotIn('round(stats["stamina"][2] * 0.02), stats["stamina"][2])', life)
        self.assertIn('#define HUNGER_THIRST_MULTIPLIER 0.32', life)
        diet = DIET.read_text(encoding='utf-8')
        self.assertIn('round(stats["stamina"][2] * 0.02 * diet_recovery_factor()), diet_stamina_cap())', diet)

    def test_penalties_default_off_and_bonus_bounded(self):
        diet = DIET.read_text(encoding='utf-8')
        self.assertIn('var/global/diet_penalties_enabled = FALSE', diet)
        self.assertIn('#define DIET_BONUS_CAP 0.25', diet)
        self.assertIn('return min(DIET_BONUS_CAP,', diet)

    def test_hidden_tastes_never_rendered(self):
        diet = DIET.read_text(encoding='utf-8')
        for proc in ('diet_status_text', 'diet_food_summary'):
            body = diet[diet.index('/mob/living/human/proc/' + proc + '('):]
            end = body.find('\n/', 1)
            body = body if end < 0 else body[:end]
            self.assertNotIn('diet_tastes[', body, proc)
        self.assertNotIn('diet_tastes', read('code/datums/mind.dm'))

    def test_prepared_dish_reads_lineage_before_the_bite(self):
        meals = read('code/game/objects/structures/kitchen/cooked_meals.dm')
        body = meals[meals.index('/proc/take_food_bite('):]
        self.assertLess(body.index('diet_lineage_shares(reagents)'), body.index('reagents.trans_to_mob('))
        self.assertIn('H.diet_credit_dish(M.meal_quality, paid_credit, diet_flavours)', body)

    def test_included_in_build(self):
        self.assertIn('#include "code\\modules\\diet\\diet.dm"', read('civ13.dme'))

    def test_native_mutation_targets_are_unique(self):
        # Each native negative control must change exactly one production line.
        spec = importlib.util.spec_from_file_location('balanced_diet_run', ROOT / 'tests/balanced_diet/run.py')
        runner = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(runner)
        original = runner.source_for(None)
        self.assertEqual(original, DIET.read_text(encoding='utf-8'))
        for control in runner.CONTROLS:
            self.assertNotEqual(runner.source_for(control), original, control)


if __name__ == '__main__':
    unittest.main()
