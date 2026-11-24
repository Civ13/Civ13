"""Project the actual refinery batch against a bounded reagent-holder fixture."""
import importlib.util
import json
import re
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
PATH = 'code/modules/1713/modern_items.dm'
SOURCE = (ROOT / PATH).read_text(encoding='utf-8')
DECL = '/obj/structure/refinery/proc/refine_petroleum_batch'

spec = importlib.util.spec_from_file_location('kerosene_projection', ROOT / 'tests/save_movement/source_adapter.py')
vm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vm)
vm.FIELDS += ('volume', 'product', 'powered', 'active', 'barrel', 'powerneeded',
              'refine_scheduled', 'update_icon', 'factory_output_barrel',
              'refine_petroleum_batch', 'powersource')


class Holder:
    def __init__(self, room, limit=None):
        self.room = room
        self.limit = limit
        self.contents = {}

    def get_free_space(self):
        return self.room

    def add_reagent(self, reagent, amount, *, accepted_amount):
        if self.limit == 0:
            return False
        amount = min(self.room, amount, amount if self.limit is None else self.limit)
        self.contents[reagent] = self.contents.get(reagent, 0) + amount
        self.room -= amount
        accepted_amount['amount'] = amount
        return True


def batch(source=SOURCE):
    return vm.project(source, DECL, 'src, output',
                      dict(min=min, max=max, MINIMUM_CHEMICAL_VOLUME=.01, list=dict), method=True)


class KeroseneTests(unittest.TestCase):
    def test_normal_batches_preserve_legacy_yields_and_select_kerosene(self):
        run = batch()
        for setting, output, units in [('kerosene', 'kerosene', 8),
                                        ('gasoline', 'gasoline', 8),
                                        ('diesel', 'diesel', 7),
                                        ('unknown', 'diesel', 7)]:
            with self.subTest(setting=setting):
                refinery = SimpleNamespace(product=setting, volume=20)
                collector = Holder(25)
                self.assertEqual(run(refinery, collector), units)
                self.assertEqual(collector.contents, {output: units})
                self.assertEqual(refinery.volume, 10)

    def test_partial_batch_debits_only_accepted_output(self):
        run = batch()
        for product, rate in [('kerosene', .8), ('gasoline', .8), ('diesel', .7)]:
            with self.subTest(product=product):
                refinery = SimpleNamespace(product=product, volume=10)
                holder = Holder(.5, limit=.25)
                self.assertEqual(run(refinery, holder), .25)
                self.assertAlmostEqual(refinery.volume, 10 - .25 / rate)
                self.assertEqual(holder.contents, {product: .25})

    def test_trace_feed_has_value_once_it_can_make_measurable_output(self):
        run = batch()
        refinery = SimpleNamespace(product='kerosene', volume=.625)
        self.assertEqual(run(refinery, Holder(10)), .5)
        self.assertAlmostEqual(refinery.volume, 0)
        refinery.volume = .005
        holder = Holder(10)
        self.assertEqual(run(refinery, holder), 0)
        self.assertEqual((refinery.volume, holder.contents), (.005, {}))

    def test_full_missing_or_rejecting_barrel_leaves_feed_untouched(self):
        run = batch()
        for holder in [Holder(0), Holder(.005), Holder(10, limit=0), None]:
            with self.subTest(holder=holder):
                refinery = SimpleNamespace(product='kerosene', volume=10)
                self.assertEqual(run(refinery, holder), 0)
                self.assertEqual(refinery.volume, 10)
                if holder:
                    self.assertEqual(holder.contents, {})

    def test_capacity_debit_mutation_is_detected(self):
        mutant = SOURCE.replace('volume - produced / rate', 'volume - 10', 1)
        refinery = SimpleNamespace(product='kerosene', volume=10)
        batch(mutant)(refinery, Holder(.5))
        self.assertNotAlmostEqual(refinery.volume, 10 - .5 / .8)

    def test_live_cycle_reaches_batch_and_respects_admission(self):
        for case in ('normal', 'off', 'no_power', 'empty', 'full', 'missing'):
            with self.subTest(case=case):
                collector = Holder(0 if case == 'full' else 25)
                barrel = SimpleNamespace(reagents=collector)
                timers = []
                refinery = SimpleNamespace(product='kerosene', volume=0 if case == 'empty' else 15,
                    powered=case != 'no_power', active=case != 'off', barrel=[barrel],
                    refine_scheduled=False, powersource=None, update_icon=lambda: None,
                    factory_output_barrel=lambda: None if case == 'missing' else barrel)
                refinery.refine_petroleum_batch = lambda output: batch()(refinery, output)
                cycle = vm.project(SOURCE, '/obj/structure/refinery/proc/refine', 'src',
                    dict(isemptylist=lambda items: not items, MINIMUM_CHEMICAL_VOLUME=.01,
                         visible_message=lambda _text: None, deferred=timers.append), method=True)
                cycle(refinery)
                self.assertEqual(collector.contents, {'kerosene': 8} if case == 'normal' else {})
                self.assertEqual(timers, [600] if case == 'normal' else [])
                if case in ('full', 'missing'):
                    self.assertFalse(refinery.active)

    def test_menu_reagent_and_lantern_contracts(self):
        menu = vm.extract(SOURCE, '/obj/structure/refinery/verb/set_product')
        self.assertIn('list("Gasoline", "Diesel", "Kerosene")', menu)
        self.assertLess(menu.rindex('if (active)'), menu.index('product = lowertext(prod)'))
        self.assertLess(menu.index('!Adjacent(user)'), menu.index('product = lowertext(prod)'))
        reagents = (ROOT / 'code/modules/reagents/Chemistry-Reagents/Chemistry-Reagents-Other.dm').read_text()
        self.assertRegex(reagents, r'/datum/reagent/kerosene\n\tname = "Kerosene"\n\tid = "kerosene"')
        lantern = (ROOT / 'code/modules/1713/lantern.dm').read_text().split('/obj/item/flashlight/lantern/copper', 1)[0]
        rates = dict(re.findall(r'"(\w+)" = (\d+)', lantern))
        self.assertEqual(rates['kerosene'], '360')
        self.assertEqual(rates['petroleum'], '240')
        self.assertFalse({'gasoline', 'diesel'} & rates.keys())
        for furnishing in ('/obj/item/flashlight/lantern/fat_lamp', '/obj/item/flashlight/torch'):
            file = 'fat_lights.dm' if 'fat_lamp' in furnishing else 'lantern.dm'
            text = (ROOT / 'code/modules/1713' / file).read_text()
            own_settings = text.split(furnishing + '\n', 1)[1].split('\n/', 1)[0]
            self.assertNotIn('"kerosene"', own_settings)

    def test_atlas_lists_acquirable_kerosene_with_station_era(self):
        catalog = json.loads((ROOT / 'UI/crafting-atlas.json').read_text(encoding='utf-8'))
        recipe, = [r for r in catalog['recipes'] if r['name'] == 'Refine crude petroleum into kerosene']
        self.assertEqual(recipe['station'], '/obj/structure/refinery')
        self.assertEqual(recipe['unlock_eras'], [5])
        self.assertEqual([(r['id'], r['quantity']) for r in recipe['inputs']], [('petroleum', '10')])
        self.assertEqual([(r['id'], r['quantity']) for r in recipe['outputs']], [('kerosene', '8')])


if __name__ == '__main__':
    unittest.main()
