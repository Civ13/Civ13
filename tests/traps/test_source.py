"""Offline source contracts for traps (#4248, #4249); these do not execute DM."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "code/game/objects/items/weapons/traps.dm"
DISARM_GUARD = 'if (!deployed || buckled_mob || !anchored)'


def proc_body(source, header):
    return source.split(header, 1)[1].split('\n/obj/', 1)[0]


def disarm_branch(source):
    body = proc_body(source, '/obj/item/weapon/trap_lifecycle/attack_hand(mob/user as mob)')
    return body[body.index('else if (deployed && can_use(user))'):]


def project_disarm(branch, trap):
    """Project the post-wait guard against a trap state; return its anchored state."""
    wait = branch.index('do_after(')
    guarded = DISARM_GUARD in branch[wait:branch.index('anchored = FALSE', wait)]
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
        branch = disarm_branch(self.source)
        victim = {'deployed': False, 'buckled_mob': 'victim', 'anchored': True}
        self.assertTrue(project_disarm(branch, victim))
        self.assertFalse(project_disarm(branch.replace(DISARM_GUARD, 'if (FALSE)', 1), victim))
        self.assertTrue(project_disarm(branch, {'deployed': False, 'buckled_mob': None, 'anchored': True}))
        self.assertTrue(project_disarm(branch, {'deployed': True, 'buckled_mob': 'victim', 'anchored': True}))
        self.assertFalse(project_disarm(branch, {'deployed': True, 'buckled_mob': None, 'anchored': True}))
        self.assertFalse(project_disarm(branch, {'deployed': True, 'buckled_mob': None, 'anchored': False}))

    def test_both_traps_inherit_shared_lifecycle_and_keep_timing(self):
        defaults = proc_body(self.source, '/obj/item/weapon/trap_lifecycle\n')
        for setting in ('deploy_time', 'free_time', 'disarm_time'):
            self.assertIn(f'var/{setting} = 60', defaults)
        for trap in ('beartrap', 'punji_sticks'):
            definition = proc_body(self.source, f'/obj/item/weapon/{trap}\n')
            self.assertIn('parent_type = /obj/item/weapon/trap_lifecycle', definition)
        punji = proc_body(self.source, '/obj/item/weapon/punji_sticks\n')
        for setting, value in (('deploy_time', 120), ('free_time', 120), ('disarm_time', 90)):
            self.assertIn(f'{setting} = {value}', punji)
        self.assertIn('update_on_unhandled_hand = TRUE', punji)
        bear = proc_body(self.source, '/obj/item/weapon/beartrap\n')
        for sound in ('deploy_start_sound', 'deploy_finish_sound', 'disarm_start_sound'):
            self.assertIn(sound + ' = ', bear)
            self.assertNotIn(sound + ' = ', punji)

    def test_cancelled_wait_does_not_mutate_deployed_state(self):
        deploy = proc_body(self.source, '/obj/item/weapon/trap_lifecycle/attack_self(mob/user as mob)')
        hand = proc_body(self.source, '/obj/item/weapon/trap_lifecycle/attack_hand(mob/user as mob)')
        self.assertIn('if (do_after(user, deploy_time, src))', deploy)
        self.assertIn('\n\t\t\tdeployed = TRUE', deploy)
        self.assertIn('if (do_after(user, free_time, src))', hand)
        self.assertIn('\n\t\t\tunbuckle_mob()', hand)
        self.assertIn('if (do_after(user, disarm_time, src))', hand)
        self.assertIn('\n\t\t\tdeployed = FALSE', hand)

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
        self.assertIn('\n\t\tfinish_trigger()', tail)
        bear = proc_body(self.source, '/obj/item/weapon/beartrap/Crossed(AM as mob|obj)')
        self.assertIn('\n\t\tfinish_trigger()', bear)
        finish = proc_body(self.source, '/obj/item/weapon/trap_lifecycle/proc/finish_trigger()')
        self.assertIn('\n\tif (!buckled_mob)\n\t\tanchored = FALSE\n\tdeployed = FALSE\n\tupdate_icon()', finish)


if __name__ == "__main__":
    unittest.main()
