"""Project the large bathtub's wash order with inert engine boundaries."""
from pathlib import Path
from types import SimpleNamespace
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests' / 'save_movement'))
import source_adapter

SOURCE = (ROOT / 'code/game/objects/structures/watercloset.dm').read_text(encoding='utf-8')


class LargeBathtubWashing(unittest.TestCase):
    def test_processing_preserves_tile_order_and_type_gates(self):
        events = []
        # DM's istype() infers each declared variable's type; Python cannot.
        source = SOURCE.replace('istype(AM) && AM.simulated', 'is_movable(AM) && AM.simulated')
        source = source.replace('istype(L))\n\t\t\t\tprocess_heat(L)',
                                'is_living(L))\n\t\t\t\tprocess_heat(L)')
        helper = source_adapter.project(source, '/obj/structure/shower/bathtub/big/proc/wash_location',
            'location, wash, process_heat', {
                'is_movable': lambda obj: obj.movable,
                'is_living': lambda obj: obj.living,
            })
        tiles = {}
        for coords, name in (((1, 1, 1), 'base'), ((2, 1, 1), 'east'),
                             ((1, 2, 1), 'north'), ((2, 2, 1), 'northeast')):
            tiles[coords] = [SimpleNamespace(name=name + '-living', movable=True, living=True, simulated=True),
                             SimpleNamespace(name=name + '-item', movable=True, living=False, simulated=True),
                             SimpleNamespace(name=name + '-unsimulated', movable=True, living=True, simulated=False),
                             SimpleNamespace(name=name + '-other', movable=False, living=False, simulated=True)]
        def wash(obj):
            events.append(('wash', obj.name))
        def heat(obj):
            events.append(('heat', obj.name))
        def wash_location(location):
            helper(location, wash, heat)
        reagents = SimpleNamespace(get_free_space=lambda: 12,
            add_reagent=lambda kind, amount: events.append(('reagent', kind, amount)))
        run = source_adapter.project(source, '/obj/structure/shower/bathtub/big/process',
            'on, loc, x, y, z, wash_location, wash_floor, reagents',
            {'locate': lambda x, y, z: tiles[(x, y, z)]})
        floor = lambda: events.append(('floor',))
        run(False, tiles[(1, 1, 1)], 1, 1, 1, wash_location, floor, reagents)
        self.assertEqual(events, [])
        run(True, tiles[(1, 1, 1)], 1, 1, 1, wash_location, floor, reagents)
        expected = []
        for name in ('base', 'east', 'north', 'northeast'):
            expected.extend((('wash', name + '-living'), ('heat', name + '-living'),
                             ('wash', name + '-item')))
        expected.extend((('floor',), ('reagent', 'water', 12)))
        self.assertEqual(events, expected)


class BathtubMistLifecycle(unittest.TestCase):
    def run_update(self, *, on, warm, mist, timer_action=None):
        import re

        events = []
        class Overlays:
            def Cut(self):
                events.append(('clear_overlays',))
        tub = SimpleNamespace(on=on, ismist=mist, mymist='old' if mist else None,
                              loc='tile', overlays=Overlays(),
                              temperature_settings={'chosen': 320 if warm else 270},
                              watertemp='chosen')
        def deleted(obj):
            events.append(('delete', obj))
        def pool(kind, loc):
            events.append(('create', kind, loc))
            return 'new'
        def deferred(delay):
            events.append(('delay', delay))
            if timer_action:
                timer_action(tub, delay)
            return True
        body = source_adapter.extract(SOURCE, '/obj/structure/shower/bathtub/update_icon')
        body = body.replace('/obj/effect/mist/bathtub', 'MIST_TYPE')
        for field in ('overlays', 'mymist', 'on', 'temperature_settings', 'watertemp', 'ismist', 'loc'):
            body = re.sub(r'(?<![\w.])' + field + r'\b', 'src.' + field, body)
        projected_source = '/probe()\n' + body + '\n'
        update = source_adapter.project(projected_source, '/probe', 'src', {
            'qdel': deleted, 'PoolOrNew': pool, 'deferred': deferred,
            'T20C': 293, 'MIST_TYPE': 'bathtub mist',
            'add_water_overlays': lambda: events.append(('water_overlays',)),
        })
        update(tub)
        return tub, events

    def test_cold_water_clears_old_mist_without_creating_more(self):
        tub, events = self.run_update(on=True, warm=False, mist=True)
        self.assertEqual(events, [('clear_overlays',), ('delete', 'old'), ('water_overlays',)])
        self.assertIsNone(tub.mymist)

    def test_hot_water_delays_first_mist_and_observes_switch_off(self):
        tub, events = self.run_update(on=True, warm=True, mist=False)
        self.assertEqual(events, [('clear_overlays',), ('water_overlays',), ('delay', 50),
                                  ('create', 'bathtub mist', 'tile')])
        self.assertTrue(tub.ismist)
        tub, events = self.run_update(on=True, warm=True, mist=False,
                                      timer_action=lambda obj, delay: setattr(obj, 'on', False))
        self.assertNotIn(('create', 'bathtub mist', 'tile'), events)
        self.assertFalse(tub.ismist)

    def test_existing_mist_refreshes_and_lingers_after_switch_off(self):
        tub, events = self.run_update(on=True, warm=True, mist=True)
        self.assertEqual(events, [('clear_overlays',), ('delete', 'old'), ('water_overlays',),
                                  ('create', 'bathtub mist', 'tile')])
        tub, events = self.run_update(on=False, warm=True, mist=True)
        self.assertEqual(events, [('clear_overlays',), ('delete', 'old'),
                                  ('create', 'bathtub mist', 'tile'), ('delay', 250), ('delete', 'new')])
        self.assertFalse(tub.ismist)
        self.assertIsNone(tub.mymist)
        tub, events = self.run_update(on=False, warm=True, mist=True,
                                      timer_action=lambda obj, delay: setattr(obj, 'on', True))
        self.assertNotIn(('delete', 'new'), events)
        self.assertTrue(tub.ismist)

    def test_each_size_retains_its_own_water_overlay(self):
        small = source_adapter.extract(SOURCE, '/obj/structure/shower/bathtub/proc/add_water_overlays')
        big = source_adapter.extract(SOURCE, '/obj/structure/shower/bathtub/big/add_water_overlays')
        self.assertIn('full_bathtub_overlay_2_2"', small)
        self.assertIn('full_bathtub_overlay_2"', small)
        self.assertIn('full_bathtub_overlay_2_2_b"', big)
        self.assertNotIn('/obj/structure/shower/bathtub/big/update_icon()', SOURCE)


if __name__ == '__main__':
    unittest.main()
