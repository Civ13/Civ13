"""Direct meat slicing shares the slab's toxins and germs across the real
number of cutlets (issue 6938).

Native check: python3 tests/ecology_spawning/run_linux.py . tests/meat_slicing/probe.dm
"""
import importlib.util
import pathlib
from types import SimpleNamespace
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
MEAT = (ROOT / 'code/modules/reagents/reagent_containers/food/snacks/meat.dm').read_text(encoding='utf-8')
SNACKS = (ROOT / 'code/modules/reagents/reagent_containers/food/snacks.dm').read_text(encoding='utf-8')


PRODUCTION = (ROOT / 'code/modules/1713/complex_production.dm').read_text(encoding='utf-8')
SNACK_TYPE = '/obj/item/weapon/reagent_containers/food/snacks'
SPEC = importlib.util.spec_from_file_location('slice_source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(adapter)


class Holder:
    """Model only the engine boundary: capacity and proportional transfer."""

    def __init__(self, contents, capacity=50):
        self.contents = dict(contents)
        self.capacity = capacity

    def clear_reagents(self):
        self.contents.clear()

    def trans_to_obj(self, target, amount):
        target = target.reagents
        total = sum(self.contents.values())
        amount = min(amount, total, target.capacity - sum(target.contents.values()))
        if amount <= 0:
            return
        for reagent, volume in self.contents.items():
            move = volume * (amount / total)
            target.contents[reagent] = target.contents.get(reagent, 0) + move
            self.contents[reagent] -= move


def project_portions(contents, default_contents, intended, remaining=None):
    source = Holder(contents)
    helper = adapter.project(SNACKS, SNACK_TYPE + '/proc/fill_food_slice',
                             'slice, portion_volume', {'reagents': source})
    count = intended if remaining is None else remaining
    amount = sum(contents.values()) / intended
    portions = []
    for _ in range(count):
        piece = SimpleNamespace(reagents=Holder(default_contents))
        helper(piece, amount)
        portions.append(piece.reagents.contents)
    return portions


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

    def test_both_routes_transfer_a_fixed_share_before_retiring_source(self):
        generic = adapter.extract(SNACKS, SNACK_TYPE + '/attackby')
        salami = adapter.extract(PRODUCTION, SNACK_TYPE + '/sausage/salted/salami/attackby')
        self.assertIn('var/reagents_per_slice = reagents.total_volume/slices_num', generic)
        self.assertLess(generic.index('for (var/i=1 to (slices_num - slices_lost))'),
                        generic.index('fill_food_slice(slice, reagents_per_slice)'))
        self.assertLess(generic.index('fill_food_slice(slice, reagents_per_slice)'), generic.index('qdel(src)'))
        self.assertIn('var/portion_count = 4', salami)
        self.assertIn('var/reagents_per_slice = reagents.total_volume / portion_count', salami)
        self.assertLess(salami.index('for (var/i = 1 to portion_count)'),
                        salami.index('fill_food_slice(portion, reagents_per_slice)'))
        self.assertLess(salami.index('fill_food_slice(portion, reagents_per_slice)'), salami.index('qdel(src)'))

    def test_dough_then_spaghetti_preserves_the_input(self):
        dough = {'nutriment': 2, 'protein': 1}
        slices = project_portions(dough, {'nutriment': 1}, intended=3)
        spaghetti = [project_portions(piece, {'nutriment': 1}, intended=1)[0] for piece in slices]
        for piece in spaghetti:
            self.assertAlmostEqual(piece['nutriment'], 2/3)
            self.assertAlmostEqual(piece['protein'], 1/3)
        self.assertAlmostEqual(sum(sum(piece.values()) for piece in spaghetti), 3)

    def test_last_slice_can_take_a_full_holder_without_constructor_defaults(self):
        contents = {'nutriment': 15, 'protein': 20, 'water': 15}
        self.assertEqual(project_portions(contents, {'nutriment': 1}, intended=1), [contents])

    def test_lost_slice_does_not_enlarge_surviving_shares(self):
        self.assertEqual(project_portions({'nutriment': 3, 'water': 3}, {'nutriment': 1}, intended=3, remaining=2),
                         [{'nutriment': 1, 'water': 1}] * 2)

    def test_salami_slices_hold_only_remaining_source_contents(self):
        self.assertEqual(project_portions({'protein': 8}, {'protein': 9}, intended=4),
                         [{'protein': 2}] * 4)
        self.assertEqual(project_portions({'protein': 3, 'water': 1}, {'protein': 9}, intended=4),
                         [{'protein': 0.75, 'water': 0.25}] * 4)


if __name__ == '__main__':
    unittest.main()
