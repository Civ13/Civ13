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

    def test_refused_cover_preserves_grave_contents_and_seated_occupant(self):
        grave = read('code/game/objects/structures/religious.dm')
        cover = grave.split('/proc/cover_grave()', 1)[1].split('/proc/uncover_grave()', 1)[0]
        guard = cover.index('if (L.buckled || L.pinned.len)')
        self.assertLess(guard, cover.index('open = FALSE'))
        self.assertLess(guard, cover.index('forceMove(src)'))
        self.assertIn('return FALSE', cover[guard:cover.index('open = FALSE')])
        self.assertIn('return TRUE', cover)
        self.assertLess(grave.index('if (!cover_grave())'), grave.index('filled in [src]'))

    def test_operating_table_checks_drop_target_before_moving_them(self):
        table = read('code/game/objects/structures/optable.dm')
        drop = table.split('/MouseDrop_T(mob/target, mob/user)', 1)[1].split('/verb/climb_on()', 1)[0]
        self.assertIn('user.stat || user.restrained() || !ishuman(target) || !check_table(target)', drop)
        self.assertNotIn('check_table(user)', drop)
        self.assertLess(drop.index('check_table(target)'), drop.index('take_victim(target,user)'))
        guard = table.split('/proc/check_table(', 1)[1]
        self.assertIn('if (patient.buckled)', guard)

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
