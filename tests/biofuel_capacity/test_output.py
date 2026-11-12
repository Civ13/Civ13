"""Execute biofuel refine control flow with fake reagents/timers, not BYOND."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest
ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('biofuel_projection', ROOT / 'tests/save_movement/source_adapter.py')
vm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vm)
vm.FIELDS += ('powered', 'active', 'volume_et', 'volume_di', 'barrel', 'product', 'refine_scheduled', 'update_icon')
SOURCE = (ROOT / 'code/modules/1713/modern_items.dm').read_text()
DECL = '/obj/structure/refinery/biofuel/refine'

class Reagents:
    def __init__(self, room):
        self.maximum_volume = 300
        self.total_volume = 300 - room
        self.added = {}
    def get_free_space(self):
        return self.maximum_volume - self.total_volume
    def add_reagent(self, reagent, amount):
        accepted = min(amount, self.get_free_space())
        if self.added.get(reagent, 0) + accepted < .01:
            return
        self.added[reagent] = self.added.get(reagent, 0) + accepted
        self.total_volume += accepted

def cycle(product='ethanol', feed=10, room=1, source=SOURCE, powered=True, active=True, barrel=True):
    holder = Reagents(room)
    events = []
    actor = SimpleNamespace(powered=powered, active=active, volume_et=feed,
        volume_di=feed, product=product, barrel={1: SimpleNamespace(reagents=holder)} if barrel else {},
        refine_scheduled=False, update_icon=lambda: events.append('icon'))
    def deferred(delay):
        events.append(('timer', delay))
        return False
    env = dict(min=min, max=max, MINIMUM_CHEMICAL_VOLUME=.01, isemptylist=lambda items: not items,
        visible_message=lambda text: events.append('full'), deferred=deferred)
    proc = vm.project(source, DECL, 'src', env, method=True)
    proc(actor)
    return actor, holder, events

class BiofuelOutputTests(unittest.TestCase):
    def test_near_full_ethanol_conserves_feed(self):
        actor, holder, _ = cycle()
        self.assertEqual(actor.volume_et, 9)
        self.assertEqual(holder.added, {'pethanol': 1})
        self.assertEqual(actor.volume_di, 10)
    def test_biodiesel_and_default_conserve_conversion(self):
        for product in ('biodiesel', 'legacy-unknown'):
            actor, holder, _ = cycle(product=product)
            self.assertAlmostEqual(actor.volume_di, 10 - 1 / .7)
            self.assertAlmostEqual(holder.added['biodiesel'], 1)
            self.assertEqual(actor.volume_et, 10)
    def test_fractional_capacity_and_small_feed(self):
        for product, reagent, ratio in (('ethanol', 'pethanol', 1), ('biodiesel', 'biodiesel', .7)):
            for feed in (.1, 3, 10, 20):
                for room in (.05, 1, 7, 10, 300):
                    with self.subTest(product=product, feed=feed, room=room):
                        actor, holder, _ = cycle(product, feed, room)
                        remaining = actor.volume_et if product == 'ethanol' else actor.volume_di
                        self.assertAlmostEqual(holder.added[reagent], min(10, feed, room / ratio) * ratio)
                        self.assertAlmostEqual((feed - remaining) * ratio, holder.added[reagent])
                        self.assertLessEqual(holder.total_volume, 300.000001)
    def test_full_barrel_stops_without_debit(self):
        actor, holder, events = cycle(room=0)
        self.assertFalse(actor.active)
        self.assertEqual(actor.volume_et, 10)
        self.assertEqual(holder.added, {})
        self.assertNotIn(('timer', 600), events)
    def test_empty_or_wrong_feed_does_not_create_product(self):
        actor, holder, _ = cycle(feed=0)
        self.assertEqual(holder.added, {})
        self.assertEqual(actor.volume_et, 0)
    def test_power_active_and_barrel_guards(self):
        for kwargs in ({'powered': False}, {'active': False}, {'barrel': False}):
            actor, holder, events = cycle(**kwargs)
            self.assertEqual(actor.volume_et, 10)
            self.assertEqual(holder.added, {})
            self.assertFalse(actor.refine_scheduled)
    def test_normal_batch_and_timer_unchanged(self):
        actor, holder, events = cycle(feed=25, room=50)
        self.assertEqual(actor.volume_et, 15)
        self.assertEqual(holder.added['pethanol'], 10)
        self.assertEqual(events.count(('timer', 600)), 1)
        self.assertTrue(actor.refine_scheduled)
    def test_trace_capacity_does_not_drain_feed(self):
        for product in ('ethanol', 'biodiesel', 'legacy-unknown'):
            actor, holder, _ = cycle(product=product, room=.005)
            self.assertEqual(actor.volume_et, 10)
            self.assertEqual(actor.volume_di, 10)
            self.assertEqual(holder.added, {})
    def test_trace_feed_is_retained(self):
        for product in ('ethanol', 'biodiesel', 'legacy-unknown'):
            actor, holder, _ = cycle(product=product, feed=.005, room=50)
            self.assertEqual(actor.volume_et, .005)
            self.assertEqual(actor.volume_di, .005)
            self.assertEqual(holder.added, {})
    def test_trace_guard_mutation_detects_loss(self):
        mutant = SOURCE.replace('if (amt >= MINIMUM_CHEMICAL_VOLUME)', 'if (TRUE)').replace('if (0.7*amt >= MINIMUM_CHEMICAL_VOLUME)', 'if (TRUE)')
        for product in ('ethanol', 'biodiesel', 'legacy-unknown'):
            actor, holder, _ = cycle(product=product, room=.005, source=mutant)
            self.assertEqual(holder.added, {})
            self.assertLess(actor.volume_et if product == 'ethanol' else actor.volume_di, 10)
    def test_old_ethanol_loss_is_detected(self):
        mutant = SOURCE.replace('amt = min(amt, output_room)', 'amt = amt')
        actor, holder, _ = cycle(source=mutant)
        self.assertEqual(actor.volume_et, 0)
        self.assertNotEqual(10 - actor.volume_et, holder.added['pethanol'])
    def test_old_diesel_loss_is_detected(self):
        mutant = SOURCE.replace('amt = min(amt, output_room / 0.7)', 'amt = amt')
        for product in ('biodiesel', 'legacy-unknown'):
            actor, holder, _ = cycle(product=product, source=mutant)
            self.assertNotAlmostEqual((10 - actor.volume_di) * .7, holder.added['biodiesel'])

if __name__ == '__main__':
    unittest.main()
