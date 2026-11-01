"""Offline ownership model and source contracts; no BYOND scheduling claims."""
from pathlib import Path
import unittest

SOURCE = Path(__file__).resolve().parents[2]/'code/game/mob/living/simple_animal/subtile_movement.dm'


class WalkerModel:
    def __init__(self):
        self.active=True; self.scheduled=False; self.current=True; self.valid=True
        self.generation=1; self.revision=1; self.due=4
        self.waiting=None; self.bound_revision=None; self.started=None; self.period=None
        self.ready=False; self.error=False; self.admissions=0; self.detached=[]

    def bind(self, tx, start, period):
        if not self.active or self.waiting is not None or not self.current or not self.valid:
            return False
        self.waiting=tx; self.bound_revision=self.revision; self.started=start; self.period=period
        self.admissions+=1
        return True

    def terminal(self, tx, revision, finished, error, now):
        if not finished or tx != self.waiting or revision != self.bound_revision or self.ready:
            return False
        self.ready=True; self.error=error
        if not self.active:
            self.resume(now)
        return True

    def exit_worker(self, now):
        self.active=False
        if self.ready:
            self.resume(now)

    def resume(self, now):
        if self.active or not self.ready or self.waiting is None:
            return
        old_revision=self.bound_revision; failed=self.error
        self.waiting=None; self.bound_revision=None; self.ready=False; self.error=False
        if failed or not self.current or not self.valid:
            return
        if self.revision == old_revision:
            self.due=max(self.started+self.period,now)
        if not self.scheduled:
            self.scheduled=True

    def stop(self):
        if self.waiting is not None:
            self.detached.append(self.waiting)
        self.current=False; self.waiting=None; self.bound_revision=None; self.ready=False


class WildHandoffTests(unittest.TestCase):
    def test_terminal_continues_at_paid_deadline_without_poll_tick(self):
        for start,period,end in ((9,4,13),(6.5,2,8.5)):
            w=WalkerModel(); self.assertTrue(w.bind('a',start,period)); w.exit_worker(start)
            self.assertTrue(w.terminal('a',1,True,False,end))
            self.assertTrue(w.scheduled); self.assertEqual(w.due,end)
            self.assertEqual(w.admissions,1)

    def test_late_completion_skips_elapsed_slots(self):
        w=WalkerModel();w.bind('a',9,4);w.exit_worker(9);w.terminal('a',1,True,False,20)
        self.assertEqual(w.due,20);self.assertEqual(w.admissions,1)

    def test_synchronous_finish_waits_for_executing_worker_to_return(self):
        w=WalkerModel();w.bind('a',0,2);w.terminal('a',1,True,False,0)
        self.assertFalse(w.scheduled);self.assertEqual(w.waiting,'a')
        w.exit_worker(0);self.assertTrue(w.scheduled);self.assertEqual(w.due,2)

    def test_duplicate_wrong_token_unfinished_and_overlap_are_rejected(self):
        w=WalkerModel();w.bind('a',0,2)
        self.assertFalse(w.bind('b',0,2))
        self.assertFalse(w.terminal('b',1,True,False,1))
        self.assertFalse(w.terminal('a',2,True,False,1))
        self.assertFalse(w.terminal('a',1,False,False,1))
        self.assertTrue(w.terminal('a',1,True,False,1))
        self.assertFalse(w.terminal('a',1,True,False,1))
        w.exit_worker(1);self.assertFalse(w.terminal('a',1,True,False,1))

    def test_replacement_preserves_new_deadline_and_never_replays_old_command(self):
        w=WalkerModel();w.bind('a',0,4);w.exit_worker(0)
        w.revision=2;w.generation=2;w.due=17
        w.terminal('a',1,True,False,4)
        self.assertEqual(w.due,17);self.assertTrue(w.scheduled)
        self.assertEqual(w.admissions,1)

    def test_stop_invalid_owner_and_error_never_continue(self):
        for change in ('stop','owner','eligibility','error'):
            w=WalkerModel();w.bind('a',0,4);w.exit_worker(0)
            if change=='stop': w.stop()
            elif change=='owner': w.current=False
            elif change=='eligibility': w.valid=False
            w.terminal('a',1,True,change=='error',4)
            self.assertFalse(w.scheduled,change)

    def test_only_matching_old_transaction_is_detached(self):
        w=WalkerModel();w.bind('old',0,4);w.stop()
        self.assertEqual(w.detached,['old'])
        self.assertFalse(w.terminal('old',1,True,False,4))
        self.assertIsNone(w.waiting)

    def test_source_binds_before_move_and_notifies_after_terminal_cleanup(self):
        source=SOURCE.read_text()
        admission=source.split('/mob/living/simple_animal/proc/ai_step(',1)[1].split('/mob/living/simple_animal/proc/ai_step_wait',1)[0]
        self.assertLess(admission.index('W.bind_transaction(T)'),admission.index('T.advance()'))
        finish=source.split('/datum/npc_subtile_transaction/proc/finish(',1)[1].split('/mob/living/simple_animal/proc/npc_subtile_take_pulse',1)[0]
        for token in ('actor = null','target = null','combat_target = null','following = null',
                      'finished = TRUE','wild_continuation = null','intent_owner = null'):
            self.assertLess(finish.index(token),finish.index('W.transaction_finished('))
        loop=source.split('/datum/npc_subtile_wild_walk/proc/perform_loop()',1)[1].split('/datum/npc_subtile_recovery',1)[0]
        self.assertIn('actor.ai_step(next, interval, TRUE, receipt, src)',loop)
        self.assertNotIn('actor.ai_step_wait(next, interval, src)',loop)
        self.assertIn('sleep(world.tick_lag)',source.split('/datum/npc_subtile_transaction/proc/wait_for_completion()',1)[1].split('/datum/npc_subtile_transaction/proc/valid()',1)[0])
        self.assertIn('T.finish(npc_initial_error)',admission)
        self.assertIn('finish(npc_worker_error)',source)
        self.assertIn('if (!finish_error)\n\t\t\tfinish_error = npc_finish_error',finish)

    def test_continuation_references_are_process_local(self):
        source=SOURCE.read_text()
        wild=source.split('/datum/npc_subtile_wild_walk\n',1)[1].split('/datum/npc_subtile_wild_walk/proc/',1)[0]
        txn=source.split('/datum/npc_subtile_transaction\n',1)[1].split('/datum/npc_subtile_transaction/proc/',1)[0]
        self.assertIn('should_save = FALSE',wild)
        self.assertIn('var/datum/npc_subtile_transaction/waiting_transaction',wild)
        self.assertIn('should_save = FALSE',txn)
        self.assertIn('var/datum/npc_subtile_wild_walk/wild_continuation',txn)
        runtime=source.split('/mob/living/simple_animal/persistence_runtime_var(key)',1)[1]
        self.assertIn('"npc_subtile_transaction"',runtime)
        self.assertIn('"npc_subtile_wild_walk"',runtime)


if __name__ == '__main__': unittest.main()
