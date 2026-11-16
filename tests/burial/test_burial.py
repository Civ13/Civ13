"""Offline wiring checks for being buried alive (no compiler or game).

The native probe (probe.dm) covers air, suffocation, clawing out, coffins,
mounds and the dead; these check the hooks that call into burial.dm.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


class Wiring(unittest.TestCase):
    def test_life_tick_runs_burial(self):
        life = read('code/game/mob/living/carbon/human/human_life.dm')
        self.assertIn('burial_life_tick()', life)
        self.assertNotIn('buried_proc', life)

    def test_grave_routes_through_burial(self):
        grave = read('code/game/objects/structures/religious.dm')
        self.assertIn('H.burial_start(src)', grave)
        self.assertIn('HM.burial_start(src)', grave)
        self.assertIn('H.burial_release()', grave)
        self.assertNotIn('buried_proc', grave)

    def test_resist_claws_out_before_closet_breakout(self):
        dme = read('civ13.dme').splitlines()
        burial = dme.index('#include "code\\modules\\1713\\burial.dm"')
        self.assertGreater(burial, dme.index('#include "code\\game\\mob\\living\\carbon\\resist.dm"'))
        self.assertGreater(burial, dme.index('#include "code\\game\\objects\\structures\\religious.dm"'))
        module = read('code/modules/1713/burial.dm')
        self.assertIn('if (buriedalive && burial_resist())', module)
        self.assertNotIn('spawn(', module)


if __name__ == '__main__':
    unittest.main()
