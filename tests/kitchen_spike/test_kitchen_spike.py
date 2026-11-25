"""Exercise meat collection using the source handler and fake engine effects."""
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests' / 'save_movement'))
import source_adapter


class KitchenSpikeTests(unittest.TestCase):
    def load_proc(self):
        source = (ROOT / 'code/game/objects/structures/kitchen_spike.dm').read_text()
        source = source.replace('istype(victim, /mob/living/simple_animal)', 'istype(victim, ANIMAL)')
        source = source.replace('istype(victim, /mob/living/human)', 'istype(victim, HUMAN)')
        env = {'ANIMAL': 'animal', 'HUMAN': 'human',
               'istype': lambda victim, kind='living': kind == 'living' or victim.kind == kind,
               'issmall': lambda victim: victim.small}
        old_fields = source_adapter.FIELDS
        try:
            source_adapter.FIELDS += ('meat', 'meat_type', 'occupied', 'victim_name', 'meat_radiation')
            load = source_adapter.project(source, '/obj/structure/kitchenspike/proc/spike',
                                          'src, victim', env, method=True)
        finally:
            source_adapter.FIELDS = old_fields
        return load

    def test_only_small_animals_with_meat_are_accepted(self):
        load = self.load_proc()
        for small, meat, expected in ((True, 'cat meat', True),
                                      (False, 'cat meat', False), (True, None, False)):
            spike = SimpleNamespace(meat=0, meat_type=None, occupied=False,
                                    victim_name='corpse', icon_state='spike', meat_radiation=0)
            animal = SimpleNamespace(kind='animal', small=small, meat_type=meat, name='cat', radiation=80)
            self.assertEqual(bool(load(spike, animal)), expected)
            self.assertEqual(spike.occupied, expected)
            if expected:
                self.assertEqual((spike.meat, spike.meat_type, spike.icon_state),
                                 (5, 'cat meat', 'spikebloody'))
                self.assertEqual(spike.meat_radiation, 40)
        spike = SimpleNamespace(meat=0, meat_type=None, occupied=False,
                                victim_name='corpse', icon_state='spike', meat_radiation=0)
        human = SimpleNamespace(kind='human', small=True, name='human', radiation=80,
                                species=SimpleNamespace(meat_type='human meat'))
        self.assertTrue(load(spike, human))
        self.assertEqual(spike.meat_type, 'human meat')
        self.assertEqual(spike.meat_radiation, 8)

    def test_harvests_all_five_pieces_and_resets_for_clean_reuse(self):
        source = (ROOT / 'code/game/objects/structures/kitchen_spike.dm').read_text()
        source = source.replace('..()', 'parent_attack()')
        source = source.replace('new meat_type(get_turf(src))',
                                'make_meat(meat_type, get_turf(src))')
        produced, messages = [], []

        def make_meat(kind, location):
            cut = SimpleNamespace(kind=kind, location=location, radiation=0)
            produced.append(cut)
            return cut

        env = {'parent_attack': lambda: False, 'get_turf': lambda src: src.loc,
               'make_meat': make_meat,
               'to_chat': lambda *args: messages.append(args[1])}
        old_fields = source_adapter.FIELDS
        try:
            source_adapter.FIELDS += ('meat', 'meat_type', 'occupied', 'victim_name', 'meat_radiation')
            collect = source_adapter.project(source, '/obj/structure/kitchenspike/attack_hand',
                                             'src, user', env, method=True)
        finally:
            source_adapter.FIELDS = old_fields
        spike = SimpleNamespace(meat=0, meat_type=None, occupied=False,
                                victim_name='corpse', icon_state='spike', loc='turf', meat_radiation=0)
        load = self.load_proc()
        animal = SimpleNamespace(kind='animal', small=True, meat_type='meat', name='cat', radiation=80)
        self.assertTrue(load(spike, animal))
        for remaining in range(4, 0, -1):
            collect(spike, object())
            self.assertEqual(spike.meat, remaining)
            self.assertTrue(spike.occupied)
        collect(spike, object())
        self.assertEqual((spike.meat, spike.occupied, spike.icon_state), (0, False, 'spike'))
        self.assertEqual([(cut.kind, cut.location, cut.radiation) for cut in produced],
                         [('meat', 'turf', 40)] * 5)
        self.assertEqual(spike.meat_radiation, 0)
        self.assertIn('last piece', messages[-1])
        collect(spike, object())
        self.assertEqual(len(produced), 5)
        animal.radiation = 0
        self.assertTrue(load(spike, animal))
        collect(spike, object())
        self.assertEqual(produced[-1].radiation, 0)


if __name__ == '__main__':
    unittest.main()
