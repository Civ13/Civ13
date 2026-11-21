"""Offline source contract for the Veil on a false-bottomed container; does not execute DM."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(rel):
    return (ROOT / rel).read_text(encoding='utf-8')


TEXT = read('code/modules/divine/arcane_veil.dm')
ENCHANT = read('code/modules/divine/arcane_enchant.dm')


class ArcaneVeilSource(unittest.TestCase):
    def test_included(self):
        self.assertIn('#include "code\\modules\\divine\\arcane_veil.dm"', read('civ13.dme'))

    def test_recipe_two_omen_one_ward_vigil(self):
        self.assertIn('"veil" = list("aspect" = "omen", "count" = 2, "also" = list("ward" = 1), "gem" = 0, "charges" = list(3, 6, 10), "vigil" = TRUE)', ENCHANT)
        self.assertIn('var/list/also = recipe["also"]', ENCHANT)
        self.assertIn('needs["vigil"]', ENCHANT)

    def test_only_on_a_false_bottom(self):
        self.assertIn('S.false_bottom()', TEXT)
        self.assertIn('return arcane_veilable(I)', ENCHANT)

    def test_hides_from_wards_and_spends_per_crossing(self):
        self.assertIn('/atom/movable/proc/hidden_from_wards()', read('code/modules/storage_window/false_bottom.dm'))
        self.assertIn('/obj/item/weapon/storage/hidden_from_wards()', TEXT)
        self.assertIn('arcane_enchant_live() == "veil"', TEXT)
        self.assertIn('arcane_enchant_spend(', TEXT.split('/obj/item/weapon/storage/proc/arcane_veil_crossed(', 1)[1])


if __name__ == '__main__':
    unittest.main()
