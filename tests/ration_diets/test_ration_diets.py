"""Check actual MRE type inheritance against the food diet gate."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/MRE.dm'
BASE = '/obj/item/weapon/reagent_containers/food/snacks/MRE'


def inherited_meat_flag(source, subtype):
    path = BASE + subtype
    while path.startswith(BASE):
        match = re.search(r'^' + re.escape(path) + r'\s*\n((?:\t[^\n]*\n|\n)*)', source, re.M)
        if match:
            setting = re.search(r'^\tnon_vegetarian\s*=\s*(TRUE|FALSE)\s*$', match[1], re.M)
            if setting:
                return setting[1] == 'TRUE'
        path = path.rsplit('/', 1)[0]
    raise AssertionError('MRE diet flag missing')


class RationDietTest(unittest.TestCase):
    def test_plant_rations_are_edible_by_herbivores(self):
        source = SOURCE.read_text(encoding='utf-8-sig')
        for subtype in ('/generic/german', '/generic/pirates', '/generic/russian'):
            with self.subTest(subtype=subtype):
                self.assertFalse(inherited_meat_flag(source, subtype))

    def test_meat_rations_keep_the_restriction(self):
        source = SOURCE.read_text(encoding='utf-8-sig')
        for subtype in ('/generic/american', '/generic/idf', '/generic/russian/modern'):
            with self.subTest(subtype=subtype):
                self.assertTrue(inherited_meat_flag(source, subtype))

    def test_food_gate_uses_the_same_flag(self):
        food = (ROOT / 'code/modules/reagents/reagent_containers/food/snacks.dm').read_text(encoding='utf-8-sig')
        self.assertRegex(food, r'if \(H\.gorillaman \|\| H\.find_trait\("Vegan"\)\)\s+if \(non_vegetarian\)')


if __name__ == '__main__':
    unittest.main()
