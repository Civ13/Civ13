"""Offline contracts for the disabled insect cadence candidate; no BYOND runtime."""
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]
def source(path): return (ROOT/path).read_text(encoding='utf-8')

class InsectCadenceCandidate(unittest.TestCase):
    def test_unmodified_life_damage_and_range_sites(self):
        movement=source('code/game/mob/living/simple_animal/subtile_movement.dm')
        self.assertNotIn('npc_subtile_has_human_contact',movement)
        for animal in ('mosquitoes','vampirebat'):
            text=source('code/game/mob/living/simple_animal/hostile/'+animal+'.dm')
            self.assertIn('for (var/mob/living/human/TG in range(1,src))',text)
            self.assertIn('if (!npc_subtile_contact_settled())',text)
            self.assertEqual(text.count('TG.adjustBruteLoss(1,2)'),1)

    def test_walker_never_waits_for_life_or_queues_a_bite(self):
        movement=source('code/game/mob/living/simple_animal/subtile_movement.dm')
        loop=movement.split('/datum/npc_subtile_wild_walk/proc/perform_loop()',1)[1].split('/datum/npc_subtile_recovery',1)[0]
        self.assertNotIn('await_contact',movement)
        self.assertNotIn('npc_subtile_contact_tick',movement)
        self.assertIn('actor.ai_step_wait(next, interval, src)',loop)
        self.assertNotIn('adjustBruteLoss',loop)
        self.assertNotIn('prob(',loop)

    def test_same_live_request_keeps_owner_and_deadline(self):
        movement=source('code/game/mob/living/simple_animal/subtile_movement.dm')
        start=movement.split('/proc/npc_subtile_start_wild_walk(',1)[1].split('/mob/living/simple_animal/proc/npc_subtile_stop_wild_walk',1)[0]
        early=start.split('if (npc_subtile_can_defer())',1)[0]
        for token in ('!npc_subtile_pending_intent','W.valid()','W.mode == mode','W.target == target',
                      'W.interval == interval','W.direction == direction','W.distance_limit == distance_limit','return TRUE'):
            self.assertIn(token,early)
        self.assertNotIn('move_gen++',early)
        self.assertNotIn('W.due =',early)
        self.assertIn('move_gen++',start)
        self.assertIn('W.due = world.time + interval',start)

    def test_measured_lag3_cycle_preserves_other_modes(self):
        for animal in ('mosquitoes','vampirebat'):
            text=source('code/game/mob/living/simple_animal/hostile/'+animal+'.dm')
            period=text.split('/npc_subtile_wild_period(mode, interval)',1)[1].split('/Life()',1)[0]
            self.assertIn('mode == "towards" && interval == npc_subtile_native_interval(3)',period)
            self.assertIn('return 2 * interval',period)
            self.assertIn('return ..()',period)
        # Full period, not pulse duration, matches the observed lag-3 case.
        tick_lag=.5; interval=3*tick_lag
        self.assertEqual(2*interval,3)
        self.assertEqual(interval,1.5)

if __name__=='__main__': unittest.main()
