"""Offline wiring checks for opening dug-out rock to the sky (no compiler or game).

The native probe (probe.dm) covers the refusals and the area change; these
check that a pickaxe click reaches the module and that the balance stays as
reviewed (docs/open-cave-roof.md).
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


class Wiring(unittest.TestCase):
    def test_included(self):
        self.assertIn('#include "code\\modules\\1713\\open_cave_roof.dm"', read('civ13.dme'))

    def test_pickaxe_click_reaches_module(self):
        floor = read('code/game/turfs/floor_attackby.dm')
        self.assertIn('if (open_cave_roof_attempt(H, C))', floor)
        self.assertLess(floor.index('start_pickaxe_mining(H, C)'), floor.index('open_cave_roof_attempt(H, C)'))

    def test_reviewed_balance(self):
        module = read('code/modules/1713/open_cave_roof.dm')
        self.assertIn('#define OPEN_CAVE_ROOF_TIME 120', module)
        self.assertNotIn('adaptStat', module, 'no strength xp for a tile mining already paid for')
        self.assertNotIn('new /obj/item', module, 'opening drops nothing')
        self.assertIn('ChangeArea(src, sky)', module)
        self.assertIn('open_cave_roof_refusal(user)', module.split('var/done = do_after')[1], 'checks again after the wait')


if __name__ == '__main__':
    unittest.main()
