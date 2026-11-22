"""Project the large bathtub's wash order with inert engine boundaries."""
from pathlib import Path
from types import SimpleNamespace
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests' / 'save_movement'))
import source_adapter

SOURCE = (ROOT / 'code/game/objects/structures/watercloset.dm').read_text(encoding='utf-8')


TUBS = (ROOT / 'code/modules/1713/bathtubs.dm').read_text(encoding='utf-8')


class LargeBathtubWashing(unittest.TestCase):
    """Bathing itself is checked natively by tests/bathtubs/probe.dm."""

    def test_public_tub_covers_its_four_tiles(self):
        turfs = source_adapter.extract(TUBS, '/obj/structure/shower/bathtub/big/tub_turfs')
        self.assertIn('for (var/dx in 0 to 1)', turfs)
        self.assertIn('for (var/dy in 0 to 1)', turfs)
        self.assertIn('locate(x + dx, y + dy, z)', turfs)

    def test_one_tub_procedure_for_both_sizes(self):
        # The old per-size click and wash loops are gone; both sizes share one.
        self.assertNotIn('/obj/structure/shower/bathtub/big/attack_hand', SOURCE)
        self.assertNotIn('/obj/structure/shower/bathtub/big/process', SOURCE)
        self.assertNotIn('wash_location', SOURCE)
        process = source_adapter.extract(TUBS, '/obj/structure/shower/bathtub/process')
        self.assertIn('for (var/turf/T in tub_turfs())', process)
        self.assertNotIn('wash(', process)
        soak = source_adapter.extract(TUBS, '/obj/structure/shower/bathtub/proc/soak')
        self.assertIn('do_after(user, TUB_SOAK_TIME, M', soak)
        self.assertIn('wash(H)', soak)


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
