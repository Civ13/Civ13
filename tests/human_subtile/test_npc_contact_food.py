"""Offline source projections for settled contact and selective food stops."""
from pathlib import Path
from types import SimpleNamespace
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import project

SUBTILE = ROOT / 'code/game/mob/living/simple_animal/subtile_movement.dm'
AI = ROOT / 'code/game/mob/living/simple_animal/simple_ai.dm'


class ContactAndFood(unittest.TestCase):
    def test_owned_motion_blocks_contact_until_settled(self):
        source = SUBTILE.read_text(encoding='utf-8')
        world = SimpleNamespace(time=10)
        settled = project(source, '/mob/living/simple_animal/proc/npc_subtile_settled',
                          'src', {'world': world})
        actor = SimpleNamespace(npc_subtile_transaction=None, npc_subtile_pulse=None,
            npc_subtile_until=10, npc_subtile_offset_owned=False, step_x=0, step_y=0)
        self.assertTrue(settled(actor))
        for field, value in (('npc_subtile_transaction', object()), ('npc_subtile_pulse', object()),
                             ('npc_subtile_until', 11)):
            changed = SimpleNamespace(**vars(actor))
            setattr(changed, field, value)
            self.assertFalse(settled(changed), field)
        for sx, sy in ((30, 0), (0, 30), (2, 2)):
            changed = SimpleNamespace(**vars(actor))
            changed.npc_subtile_offset_owned, changed.step_x, changed.step_y = True, sx, sy
            self.assertFalse(settled(changed))
        # Legacy, unowned pixel offsets retain the original contact behavior.
        actor.step_x = 30
        self.assertTrue(settled(actor))

        contact = project(source, '/mob/living/simple_animal/proc/npc_subtile_contact_settled',
                          'src, other', {})
        attacker = SimpleNamespace(npc_subtile_settled=lambda: True)
        self.assertTrue(contact(attacker, None))
        self.assertTrue(contact(attacker, SimpleNamespace(npc_subtile_settled=lambda: True)))
        self.assertFalse(contact(attacker, SimpleNamespace(npc_subtile_settled=lambda: False)))
        self.assertFalse(contact(SimpleNamespace(npc_subtile_settled=lambda: False), None))

    def test_contact_guards_leave_life_decisions_and_rng_in_place(self):
        for name in ('cat', 'dogs'):
            source = (ROOT / f'code/game/mob/living/simple_animal/friendly/{name}.dm').read_text(encoding='utf-8')
            self.assertLess(source.index('if (!M.stat && npc_subtile_contact_settled(M))'), source.index('M.splat()'))
        lizard = (ROOT / 'code/game/mob/living/simple_animal/friendly/lizard.dm').read_text(encoding='utf-8')
        self.assertEqual(lizard.count('if (!npc_subtile_contact_settled('), 5)
        for name, chance in (('mosquitoes', 'prob(10)'), ('vampirebat', 'prob(5)')):
            source = (ROOT / f'code/game/mob/living/simple_animal/hostile/{name}.dm').read_text(encoding='utf-8')
            self.assertLess(source.index(chance), source.index('if (!npc_subtile_contact_settled())'))
            self.assertLess(source.index('if (!npc_subtile_contact_settled())'), source.index('TG.adjustBruteLoss(1,2)'))

    def test_food_stop_cancels_only_continuous_owners(self):
        source = SUBTILE.read_text(encoding='utf-8')
        events = []
        def stop(kind):
            events.append(kind)
            if animal.pending == kind:
                animal.pending = None
        animal = SimpleNamespace(pending='follow', following_mob=object(), pursuit=object())
        animal.npc_subtile_stop_follow = lambda: stop('follow')
        animal.npc_subtile_stop_flee = lambda: stop('flee')
        animal.npc_subtile_stop_pet_walk = lambda: stop('pet')
        animal.npc_subtile_stop_wild_walk = lambda: stop('wild')
        native_walk = lambda actor, direction: events.append(('walk', actor, direction))
        stop_walk = project(source, '/mob/living/simple_animal/proc/npc_subtile_stop_continuous_walk',
                            'src', {'walk': native_walk})
        leash, pursuit = animal.following_mob, animal.pursuit
        stop_walk(animal)
        self.assertEqual(events[:4], ['follow', 'flee', 'pet', 'wild'])
        self.assertEqual(events[4], ('walk', animal, 0))
        self.assertIsNone(animal.pending)
        self.assertIs(animal.following_mob, leash)
        self.assertIs(animal.pursuit, pursuit)
        for pending in ('flee', 'pet', 'wild', 'pursuit'):
            animal.pending = pending
            stop_walk(animal)
            self.assertEqual(animal.pending, 'pursuit' if pending == 'pursuit' else None)

        food = AI.read_text(encoding='utf-8').split('/mob/living/simple_animal/proc/check_food()', 1)[1]
        self.assertEqual(food.count('npc_subtile_stop_continuous_walk()'), 8)
        self.assertNotIn('walk(src, 0)', food)
        self.assertIn('if (prob(33))', food)
        self.assertIn('npc_set_combat_target(ML)', food)


if __name__ == '__main__':
    unittest.main()
