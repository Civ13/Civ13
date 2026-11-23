"""Offline projection of the loose manure clock; no native process."""
import importlib.util
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
MANURE = (ROOT / 'code/game/mob/living/carbon/human/shit_piss.dm').read_text(encoding='utf-8-sig')
SPEC = importlib.util.spec_from_file_location('abandonment_adapter', ROOT / 'tests/save_movement/source_adapter.py')
ADAPTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ADAPTER)
ADAPTER.FIELDS += ('restoring', 'manure_ground_age', 'manure_ground_since', 'update_manure_ground_age',
                   'is_abandonment_waste', 'unregister_abandoned_item', 'abandonment_protected')


class LooseManureDecayTest(unittest.TestCase):
    def test_production_ages_only_ground_intervals_and_defers_retirement_during_save(self):
        path = '/obj/item/weapon/reagent_containers/food/snacks/poo/animal'
        lifetime = re.search(r'^#define MANURE_GROUND_LIFETIME ([0-9 ()*]+)$', MANURE, re.M)[1]
        limit = 1
        for factor in re.findall(r'[0-9]+', lifetime):
            limit *= int(factor)
        self.assertEqual(limit, 144000)
        saving = False

        def qdel(pile):
            pile.deleted = True

        env = {'MANURE_GROUND_LIFETIME': limit, 'isnull': lambda x: x is None,
               'isturf': lambda x: x == 'ground', 'QDELETED': lambda x: x.deleted,
               'persistence_save_active': lambda: saving, 'qdel': qdel}
        update = ADAPTER.project(MANURE, path + '/proc/update_manure_ground_age', 'src, now', env, method=True)
        check = ADAPTER.project(MANURE, path + '/check_abandonment', 'src, now', env, method=True)

        class Pile:
            loc, restoring, manure_ground_age, manure_ground_since, deleted = 'ground', False, 0, None, False
            update_manure_ground_age = update
            is_abandonment_waste = lambda self: True
            abandonment_protected = lambda self: False
            unregister_abandoned_item = lambda self: None

        pile = Pile()
        self.assertFalse(check(pile, 0))
        self.assertEqual(pile.manure_ground_since, 0)
        # Same pre/post observation boundary as the production relocation hooks.
        update(pile, 36000)
        pile.loc = 'carried'
        update(pile, 36000)
        self.assertFalse(check(pile, limit * 10))
        self.assertEqual(pile.manure_ground_age, 36000)
        pile.loc = 'ground'
        update(pile, limit * 10)
        self.assertFalse(check(pile, limit * 10 + 107999))
        saving = True
        self.assertFalse(check(pile, limit * 10 + 108000))
        self.assertEqual(pile.manure_ground_age, limit)
        self.assertFalse(pile.deleted)
        saving = False
        self.assertTrue(check(pile, limit * 10 + 108000))
        self.assertTrue(pile.deleted)


if __name__ == '__main__':
    unittest.main()
