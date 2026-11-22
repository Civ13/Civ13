"""Station recipes (mortar grinding, flint and obsidian knapping) are rows in
code/modules/1713/processing_recipes.dm instead of if-chains in each station.

FROZEN is what the old chains in herbalism.dm, flint_mining.dm,
stone_age_arms.dm and obsidian.dm gave: menu order, product, amount, work time,
failure chance and whether the product needed its research. The test parses
the registry and checks the stations read it, and that the Crafting Atlas
extractor reads the same rows.
"""
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / 'code/modules/1713/processing_recipes.dm'
GROWN = '/obj/item/weapon/reagent_containers/food/snacks/grown/'

FROZEN = {
    'mortar': [
        (None, GROWN + 'wheat', 'flour', 5, 0, 0, False),
        (None, GROWN + 'oat', 'oatflour', 5, 0, 0, False),
        (None, GROWN + 'barley', 'barleyflour', 5, 0, 0, False),
        (None, GROWN + 'sunflower_seeds', 'sunflower_oil', 5, 0, 0, False),
        (None, '/obj/item/stack/farming/seeds/flax', 'linseed_oil', 2, 0, 0, False),
        (None, GROWN + 'olives', 'olive_oil', 6, 0, 0, False),
        (None, '/obj/item/weapon/reagent_containers/food/snacks/roasted_coffee', 'coffee_grounds', 3, 0, 0, False),
        (None, '/obj/item/stack/material/poppy', 'poppy_straw', 3, 0, 0, False),
        (None, '/obj/item/stack/material/coca', 'coca_leaf', 3, 0, 0, False),
        (None, '/obj/item/stack/material/cannabis', 'thc', 3, 0, 0, False),
    ],
    'flint knapping': [
        ('Sharp flake', '/obj/item/weapon/flint', None, 1, 40, 10, False),
        ('Three arrowheads', '/obj/item/weapon/flint', '/obj/item/stack/arrowhead/flint', 3, 60, 25, False),
        ('Flint knife', '/obj/item/weapon/flint', '/obj/item/weapon/material/kitchen/utensil/knife/flint', 1, 80, 35, False),
        ('Spearhead', '/obj/item/weapon/flint', '/obj/item/weapon/flint_spearhead', 1, 80, 30, False),
        ('Sickle teeth', '/obj/item/weapon/flint', '/obj/item/weapon/flint_sickle_teeth', 1, 70, 25, False),
        ('Hand axe', '/obj/item/weapon/flint', '/obj/item/weapon/material/hatchet/tribal/hand_axe', 1, 100, 30, True),
        ('Hide scraper', '/obj/item/weapon/flint', '/obj/item/weapon/material/hide_scraper', 1, 50, 15, True),
    ],
    'obsidian knapping': [
        ('Sharp flake', '/obj/item/weapon/obsidian_nodule', '/obj/item/weapon/obsidian_flake', 1, 40, 5, False),
        ('Five arrowheads', '/obj/item/weapon/obsidian_nodule', '/obj/item/stack/arrowhead/obsidian', 5, 60, 20, False),
        ('Knife', '/obj/item/weapon/obsidian_nodule', '/obj/item/weapon/material/kitchen/utensil/knife/obsidian', 1, 80, 30, False),
        ('Spearhead', '/obj/item/weapon/obsidian_nodule', '/obj/item/weapon/obsidian_spearhead', 1, 80, 25, False),
        ('Scraper', '/obj/item/weapon/obsidian_nodule', '/obj/item/weapon/material/hide_scraper/obsidian', 1, 50, 10, True),
        ('Blade core', '/obj/item/weapon/obsidian_nodule', '/obj/item/weapon/obsidian_core', 1, 100, 25, True),
    ],
}

sys.path.insert(0, str(ROOT / 'scripts'))
from atlas.interactions import registry_rows  # noqa: E402


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


class ProcessingRecipeTest(unittest.TestCase):
    def test_rows_match_the_old_chains(self):
        source = REGISTRY.read_text(encoding='utf-8')
        for station, rows in FROZEN.items():
            found = [(r['choice'], r['input'], r['output'], r['amount'], r['delay'], r['fail'], r['gated'])
                     for r in registry_rows(source, station)]
            self.assertEqual(found, rows, station)

    def test_stations_read_the_registry(self):
        herbs = read('code/modules/1713/herbalism.dm')
        grind = herbs[herbs.index('/proc/mortar_grind_result('):herbs.index('/obj/item/weapon/reagent_containers/glass/mortar/attackby')]
        self.assertIn('processing_recipe_for_input("mortar", I)', grind)
        self.assertNotIn('istype(', grind)
        for path, station in (('code/modules/1713/flint_mining.dm', 'flint knapping'),
                              ('code/modules/1713/obsidian.dm', 'obsidian knapping')):
            text = read(path)
            self.assertIn(f'processing_recipe_choices("{station}", H)', text)
            self.assertIn(f'processing_recipe_choice("{station}", choice)', text)
            self.assertIn('var/obj/item/result = processing_recipe_make(R, T, H)', text)
            self.assertNotIn('switch (choice)', text[text.index('/proc/knap('):].split('\n/', 1)[0])
        self.assertNotIn('stone_age_knap', read('code/modules/1713/stone_age_arms.dm'))

    def test_refused_and_special_rows(self):
        source = REGISTRY.read_text(encoding='utf-8')
        make = source[source.index('/proc/processing_recipe_make('):]
        self.assertIn('if (!R || !ispath(R.output) || !processing_recipe_allowed(R, H))', make)
        flint = read('code/modules/1713/flint_mining.dm')
        knap = flint[flint.index('/obj/item/weapon/flint/proc/knap('):].split('\n/', 1)[0]
        self.assertIn('if (sharpened)\n\t\toptions -= "Sharp flake"', knap)
        self.assertLess(knap.index('if (!R.output)\n\t\tsharpen()'), knap.index('processing_recipe_make(R, T, H)'))


if __name__ == '__main__':
    unittest.main()
