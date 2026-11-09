"""Offline source contracts for traps (#4248, #4249); these do not execute DM."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "code/game/objects/items/weapons/traps.dm"
DISARM_GUARD = 'if (!deployed || buckled_mob || !anchored)'


def proc_body(source, header):
    return source.split(header, 1)[1].split('\n/obj/', 1)[0]


def disarm_branch(source, trap):
    body = proc_body(source, f'/obj/item/weapon/{trap}/attack_hand(mob/user as mob)')
    return body[body.index('else if (deployed && can_use(user))'):]


def project_disarm(branch):
    """A victim is caught during the disarm wait; returns the trap's final anchored state."""
    wait = branch.index('do_after(')
    guarded = DISARM_GUARD in branch[wait:branch.index('anchored = FALSE', wait)]
    trap = {'deployed': False, 'buckled_mob': 'victim', 'anchored': True}
    if guarded and (not trap['deployed'] or trap['buckled_mob'] or not trap['anchored']):
        return trap['anchored']
    trap['anchored'] = False
    return trap['anchored']


def animal_branch(source):
    body = proc_body(source, '/obj/item/weapon/punji_sticks/Crossed(AM as mob|obj)')
    return body[body.index('istype(L, /mob/living/simple_animal)'):body.index('else\n')]


class TrapsSource(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding="utf-8")

    def test_disarm_rechecks_trap_after_wait(self):
        for trap in ('beartrap', 'punji_sticks'):
            with self.subTest(trap=trap):
                branch = disarm_branch(self.source, trap)
                self.assertTrue(project_disarm(branch))
                self.assertFalse(project_disarm(branch.replace(DISARM_GUARD, 'if (FALSE)', 1)))

    def test_punji_animal_is_buckled_and_releasable(self):
        branch = animal_branch(self.source)
        self.assertNotIn('stop_automated_movement', branch)
        self.assertNotIn('return', branch)
        self.assertIn('buckle_mob(SA)', branch)
        self.assertLess(branch.index('can_buckle = TRUE'), branch.index('buckle_mob(SA)'))
        self.assertIn('can_buckle = initial(can_buckle)', branch)

    def test_punji_settles_armed_state_for_every_victim(self):
        body = proc_body(self.source, '/obj/item/weapon/punji_sticks/Crossed(AM as mob|obj)')
        tail = body[body.index('attack_mob(L)'):]
        # Shared by the animal and human paths: one dedent level above attack_mob(L).
        self.assertIn('\n\t\tif (!buckled_mob)\n\t\t\tanchored = FALSE\n\t\tdeployed = FALSE\n\t\tupdate_icon()', tail)


if __name__ == "__main__":
    unittest.main()
