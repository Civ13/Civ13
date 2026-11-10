"""Exercise meat collection using the source handler and fake engine effects."""
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests' / 'save_movement'))
import source_adapter


class KitchenSpikeTests(unittest.TestCase):
    def test_only_small_animals_with_meat_are_accepted(self):
        source = (ROOT / 'code/game/objects/structures/kitchen_spike.dm').read_text()
        source = source.replace('istype(victim, /mob/living/simple_animal)', 'istype(victim, ANIMAL)')
        source = source.replace('istype(victim, /mob/living/human)', 'istype(victim, HUMAN)')
        env = {'ANIMAL': 'animal', 'HUMAN': 'human',
               'istype': lambda victim, kind='living': kind == 'living' or victim.kind == kind,
               'issmall': lambda victim: victim.small}
        old_fields = source_adapter.FIELDS
        try:
            source_adapter.FIELDS += ('meat', 'meat_type', 'occupied', 'victim_name')
            load = source_adapter.project(source, '/obj/structure/kitchenspike/proc/spike',
                                          'src, victim', env, method=True)
        finally:
            source_adapter.FIELDS = old_fields
        for small, meat, expected in ((True, 'cat meat', True),
                                      (False, 'cat meat', False), (True, None, False)):
            spike = SimpleNamespace(meat=0, meat_type=None, occupied=False,
                                    victim_name='corpse', icon_state='spike')
            animal = SimpleNamespace(kind='animal', small=small, meat_type=meat, name='cat')
            self.assertEqual(bool(load(spike, animal)), expected)
            self.assertEqual(spike.occupied, expected)
            if expected:
                self.assertEqual((spike.meat, spike.meat_type, spike.icon_state),
                                 (5, 'cat meat', 'spikebloody'))
        spike = SimpleNamespace(meat=0, meat_type=None, occupied=False,
                                victim_name='corpse', icon_state='spike')
        human = SimpleNamespace(kind='human', small=True, name='human',
                                species=SimpleNamespace(meat_type='human meat'))
        self.assertTrue(load(spike, human))
        self.assertEqual(spike.meat_type, 'human meat')

    def test_harvests_all_five_pieces_and_stops(self):
        source = (ROOT / 'code/game/objects/structures/kitchen_spike.dm').read_text()
        source = source.replace('..()', 'parent_attack()')
        source = source.replace('new meat_type(get_turf(src))',
                                'make_meat(meat_type, get_turf(src))')
        produced, messages = [], []
        env = {'parent_attack': lambda: False, 'get_turf': lambda src: src.loc,
               'make_meat': lambda kind, loc: produced.append((kind, loc)),
               'to_chat': lambda *args: messages.append(args[1])}
        old_fields = source_adapter.FIELDS
        try:
            source_adapter.FIELDS += ('meat', 'meat_type', 'occupied', 'victim_name')
            collect = source_adapter.project(source, '/obj/structure/kitchenspike/attack_hand',
                                             'src, user', env, method=True)
        finally:
            source_adapter.FIELDS = old_fields
        spike = SimpleNamespace(meat=5, meat_type='meat', occupied=True,
                                victim_name='victim', icon_state='spikebloody', loc='turf')
        for remaining in range(4, 0, -1):
            collect(spike, object())
            self.assertEqual(spike.meat, remaining)
            self.assertTrue(spike.occupied)
        collect(spike, object())
        self.assertEqual((spike.meat, spike.occupied, spike.icon_state), (0, False, 'spike'))
        self.assertEqual(produced, [('meat', 'turf')] * 5)
        self.assertIn('last piece', messages[-1])
        collect(spike, object())
        self.assertEqual(len(produced), 5)


if __name__ == '__main__':
    unittest.main()
