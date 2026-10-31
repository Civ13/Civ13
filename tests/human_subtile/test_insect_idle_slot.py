"""Offline timing model and source contracts; not BYOND scheduling evidence."""
import math
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]
MOVEMENT=ROOT/'code/game/mob/living/simple_animal/subtile_movement.dm'

class IdleSlot:
    def __init__(self,due=59.5,interval=1.5,period=3,tick=.5):
        self.due=due;self.interval=interval;self.period=period;self.tick=tick
        self.end=0;self.revision=1;self.generation=1;self.actions=[]
    def refresh(self,same=True):
        if not same:
            self.end=0;self.due=70+self.interval;self.revision+=1;self.generation+=1
    def run(self,now,same_turf,valid=True,blocked=False):
        if not valid or now<self.due:return None
        if not self.end and same_turf:self.end=self.due+self.interval
        if self.end:
            if now>=self.end:
                self.end=0;self.due+=max(1,math.floor((now-self.due)/self.period)+1)*self.period
                return 'expired'
            if same_turf:return 'wait'
            self.end=0
        self.actions.append((now,blocked))
        self.due=now+self.period
        return 'blocked' if blocked else ('start',now,now+self.interval)

class IdleSlotContracts(unittest.TestCase):
    def test_target_moves_during_existing_slot_without_shortening_transit(self):
        owner=IdleSlot()
        self.assertEqual(owner.run(59.5,True),'wait')
        self.assertEqual((owner.due,owner.end),(59.5,61))
        self.assertEqual(owner.run(60,False),('start',60,61.5))
        self.assertEqual(owner.actions,[(60,False)])
        self.assertEqual(owner.due,63)

    def test_window_cannot_start_before_due_or_replay_after_expiry(self):
        owner=IdleSlot()
        self.assertIsNone(owner.run(59,False));self.assertEqual(owner.run(59.5,True),'wait')
        self.assertEqual(owner.run(61,False),'expired')
        self.assertEqual(owner.due,62.5);self.assertIsNone(owner.run(62,False))
        self.assertEqual(owner.run(62.5,False),('start',62.5,64))
        self.assertEqual(len(owner.actions),1)

    def test_late_worker_skips_elapsed_slots_without_burst(self):
        owner=IdleSlot();owner.run(59.5,True)
        self.assertEqual(owner.run(70,False),'expired')
        self.assertGreater(owner.due,70);self.assertEqual(owner.actions,[])

    def test_identical_refresh_keeps_slot_and_replacement_invalidates_it(self):
        owner=IdleSlot();owner.run(59.5,True);owner.refresh()
        self.assertEqual((owner.due,owner.end,owner.revision,owner.generation),(59.5,61,1,1))
        owner.refresh(same=False)
        self.assertEqual((owner.end,owner.due,owner.revision,owner.generation),(0,71.5,2,2))

    def test_invalid_or_blocked_owner_does_not_duplicate_moves(self):
        owner=IdleSlot();owner.run(59.5,True)
        self.assertIsNone(owner.run(60,False,valid=False));self.assertEqual(owner.actions,[])
        self.assertEqual(owner.run(60,False,blocked=True),'blocked')
        self.assertIsNone(owner.run(60.5,False));self.assertEqual(owner.actions,[(60,True)])

    def test_source_limits_idle_window_to_calibrated_towards_and_full_step(self):
        source=MOVEMENT.read_text(encoding='utf-8')
        start=source.split('/proc/npc_subtile_start_wild_walk(',1)[1].split('/mob/living/simple_animal/proc/npc_subtile_stop_wild_walk',1)[0]
        self.assertLess(start.index('W.valid() && W.mode == mode'),start.index('W.idle_window_end = 0'))
        loop=source.split('/datum/npc_subtile_wild_walk/proc/perform_loop()',1)[1].split('/datum/npc_subtile_recovery',1)[0]
        self.assertIn('mode == "towards" && period > interval && get_turf(actor) == get_turf(target)',loop)
        self.assertIn('idle_window_end = due + interval',loop)
        self.assertLess(loop.index('world.time >= idle_window_end'),loop.index('if (get_turf(actor) == get_turf(target))'))
        self.assertIn('due += max(1, floor((world.time - due) / period) + 1) * period',loop)
        self.assertIn('actor.ai_step_wait(next, interval, src)',loop)
        self.assertNotIn('prob(',loop);self.assertNotIn('adjustBruteLoss',loop)
        fixture=(ROOT/'tests/human_subtile/scheduler_core_draft.dm').read_text(encoding='utf-8')
        for field in ('"wild_due"','"wild_idle_end"','"wild_revision"','"pending"','"recovery"'):
            self.assertIn(field,fixture)

if __name__=='__main__':unittest.main()
