"""Rearming close air support restores the maximum without aliasing it (#6886).

BYOND lists are references: assigning the maximum list to the remaining list
made every later strike decrement the maximum too, so each rearm restored
less. The rearm must copy the maximum.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
ZOOM = (ROOT / 'code/modules/1713/weapons/zoom.dm').read_text(encoding='utf-8-sig')
GLOBALS = (ROOT / 'code/_helpers/global_lists.dm').read_text(encoding='utf-8-sig')


class AirstrikeRearm(unittest.TestCase):
    def test_rearm_copies_the_maximum(self):
        for faction in ('faction1', 'faction2'):
            with self.subTest(faction=faction):
                assignments = re.findall(faction + r'_airstrikes_remaining = ([^\n]*)', ZOOM)
                self.assertEqual(len(assignments), 1)
                self.assertTrue(assignments[0].startswith(faction + '_airstrikes_max.Copy()'), assignments[0])

    def test_maximum_and_remaining_start_as_separate_lists(self):
        for faction in ('faction1', 'faction2'):
            with self.subTest(faction=faction):
                self.assertRegex(GLOBALS, r'var/global/list/' + faction + r'_airstrikes_max = list\(')
                self.assertRegex(GLOBALS, r'var/global/list/' + faction + r'_airstrikes_remaining = list\(')


if __name__ == '__main__':
    unittest.main()
