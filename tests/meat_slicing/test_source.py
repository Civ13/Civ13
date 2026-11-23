"""Direct meat slicing shares the slab's toxins and germs across the real
number of cutlets (issue 6938).

Native check: python3 tests/ecology_spawning/run_linux.py . tests/meat_slicing/probe.dm
"""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
MEAT = (ROOT / 'code/modules/reagents/reagent_containers/food/snacks/meat.dm').read_text(encoding='utf-8')
SNACKS = (ROOT / 'code/modules/reagents/reagent_containers/food/snacks.dm').read_text(encoding='utf-8')


class MeatSlicingTests(unittest.TestCase):
    def test_prepare_divides_by_the_piece_count(self):
        prepare = MEAT.split('/proc/prepare_meat_cutlet(', 1)[1].split('\n/obj/', 1)[0]
        self.assertTrue(prepare.startswith('obj/item/weapon/reagent_containers/food/snacks/rawcutlet/cutlet, pieces = 2)'))
        self.assertIn('cutlet.reagents.add_reagent(germ, amount / pieces)', prepare)
        self.assertIn('for (var/datum/reagent/toxin/T in reagents.reagent_list)', prepare)
        self.assertIn('!(T.id in germ_reagent_disease)', prepare)
        self.assertIn('cutlet.reagents.add_reagent(T.id, T.volume / pieces)', prepare)

    def test_each_route_passes_its_count(self):
        self.assertIn('prepare_meat_cutlet(cutlet, 2)', MEAT)
        self.assertIn('prepare_meat_cutlet(cutlet, 3)', SNACKS)


if __name__ == '__main__':
    unittest.main()
