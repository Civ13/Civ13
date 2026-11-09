"""Source contract for injury support from either kind of cane in either hand."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/mob/living/carbon/human/human_organs.dm'
ORDINARY = '/obj/item/weapon/cane'
FANCY = '/obj/item/weapon/material/fancycane'


def assert_cane_support(test, source):
    stance = source.split('/mob/living/human/proc/handle_stance()', 1)[1]
    for hand in ('l_hand', 'r_hand'):
        condition = f'\tif (istype({hand}, {ORDINARY}) || istype({hand}, {FANCY}))'
        test.assertIn(condition + '\n\t\tstance_damage -= 2', stance)


class CaneStanceTest(unittest.TestCase):
    def test_both_types_reduce_stance_damage_in_each_hand(self):
        assert_cane_support(self, SOURCE.read_text(encoding='utf-8'))
        self.assertIn(ORDINARY + '\n', (ROOT / 'code/modules/1713/cane.dm').read_text(encoding='utf-8'))
        self.assertIn(FANCY + '\n', (ROOT / 'code/game/objects/items/weapons/material/misc.dm').read_text(encoding='utf-8'))

    def test_original_type_path_or_is_rejected_for_each_hand(self):
        source = SOURCE.read_text(encoding='utf-8')
        for hand in ('l_hand', 'r_hand'):
            fixed = f'istype({hand}, {ORDINARY}) || istype({hand}, {FANCY})'
            old = f'{hand} && istype({hand}, (({ORDINARY})||({FANCY})))'
            self.assertIn(fixed, source)
            with self.assertRaises(AssertionError):
                assert_cane_support(self, source.replace(fixed, old, 1))


if __name__ == '__main__':
    unittest.main()
