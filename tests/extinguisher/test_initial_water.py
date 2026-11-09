"""Source contract for the crafted empty and standard extinguisher constructors."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/objects/items/weapons/tools.dm'
EMPTY = '/obj/item/weapon/reagent_containers/glass/fire_extinguisher/empty'


def assert_initial_charge(test, source):
    parent = source.split('/obj/item/weapon/reagent_containers/glass/fire_extinguisher\n', 1)[1].split(EMPTY + '/New()', 1)[0]
    constructor = parent.split('\n\tNew()\n', 1)[1]
    test.assertIn('\t\t..()\n\t\tif (!istype(src, ' + EMPTY + '))\n\t\t\treagents.add_reagent("water",30)', constructor)
    child = source.split(EMPTY + '/New()', 1)[1].split('\n/obj/', 1)[0]
    test.assertIn('\n\t..()', child)
    test.assertNotIn('add_reagent', child)


class InitialWaterTest(unittest.TestCase):
    def test_empty_subtype_is_not_charged_by_parent(self):
        assert_initial_charge(self, SOURCE.read_text(encoding='utf-8'))

    def test_regression_rejects_unconditional_parent_charge(self):
        source = SOURCE.read_text(encoding='utf-8')
        fixed = '\t\tif (!istype(src, ' + EMPTY + '))\n\t\t\treagents.add_reagent("water",30)'
        self.assertIn(fixed, source)
        with self.assertRaises(AssertionError):
            assert_initial_charge(self, source.replace(fixed, '\t\treagents.add_reagent("water",30)', 1))

    def test_global_recipe_constructs_empty_subtype(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        self.assertIn(',fire extinguisher,' + EMPTY + ',', recipes)


if __name__ == '__main__':
    unittest.main()
