"""Sheep lambs neither conceive nor sire (issue #6847).

Behaviour is covered natively (adults conceive; a ewe lamb or a ram lamb
does not):

    python3 tests/ecology_spawning/run_linux.py . tests/sheep_lambs/probe.dm
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/game/mob/living/simple_animal/friendly/farm_animals.dm').read_text(encoding='utf-8')


class SheepLambs(unittest.TestCase):
    def test_conception_requires_mature_parents(self):
        body = SOURCE.split('/mob/living/simple_animal/sheep/female/Life()', 1)[1].split('\n/', 1)[0]
        gate = body.index('if (!pregnant && !lamb && ')
        ram = body.index('M.stat == CONSCIOUS && !M.lamb && ')
        self.assertLess(gate, ram)
        self.assertLess(ram, body.index('pregnant = TRUE'))

    def test_sheared_restore_rearms_one_regrowth_without_changing_corpses(self):
        restore = SOURCE.split('/mob/living/simple_animal/sheep/after_load()', 1)[1].split('\n/', 1)[0]
        schedule = SOURCE.split('/mob/living/simple_animal/sheep/proc/regrowth()', 1)[1].split('\n/', 1)[0]
        finish = SOURCE.split('/mob/living/simple_animal/sheep/proc/finish_wool_regrowth()', 1)[1].split('\n/', 1)[0]
        self.assertLess(restore.index('. = ..()'), restore.index('regrowth()'))
        self.assertIn('var/tmp/wool_regrowth_pending = FALSE', SOURCE)
        self.assertIn('if (stat == DEAD || !sheared || wool_regrowth_pending)', schedule)
        self.assertLess(schedule.index('wool_regrowth_pending = TRUE'), schedule.index('addtimer('))
        self.assertIn('PROC_REF(finish_wool_regrowth)), 4800)', schedule)
        self.assertLess(finish.index('wool_regrowth_pending = FALSE'), finish.index('if (stat == DEAD || !sheared)'))
        self.assertLess(finish.index('if (stat == DEAD || !sheared)'), finish.index('sheared = FALSE'))
        self.assertIn('update_icons()', finish)


if __name__ == '__main__':
    unittest.main()
