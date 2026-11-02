"""Offline tests of a synthetic receipt; no BYOND runtime is invoked."""
import copy
import unittest
from pathlib import Path
from scheduler_enabled_handoff_contract import validate


def good():
    e=[]; s=dict(x=6,y=6,z=1,sx=0,sy=0,generation=1,base_enabled=1,offset_owned=0,
        transaction=0,transaction_old=0,transaction_owner=None,transaction_generation=None,pulse=0,
        flee_old=0,follow_new=0,follow_any=0,recovery=0,pending=0,pursuit=0,wild=0,pet=0,
        ticket_deadline=55,old_cancelled=0,old_owner_retired=0,old_finished=0,old_arrived=0,old_hooks=0,old_timer_count=0,follow_moves=0,result=None,call_id=None)
    def add(name,t,phase='flee',**changes):
        s.update(changes); e.append(dict(s,event=name,at=t,phase=phase))
    add('life_before',4)
    add('move_before',4,transaction=1,transaction_owner='other',transaction_generation=1,pulse=1,call_id=10)
    add('move_after',4,sx=2,result=1)
    add('life_after',4,offset_owned=1,pulse=0,result=None,call_id=None)
    add('stop_before',5,transaction_old=1,transaction_owner='old_flee',flee_old=1)
    add('stop_after',5,generation=2,flee_old=0,old_cancelled=1)
    add('replacement_requested',5,'replacement')
    add('old_completion_hook',5.5,'replacement',transaction=0,transaction_old=0,transaction_owner=None,
        transaction_generation=None,old_hooks=1)
    add('life_before',14,'replacement',old_finished=1,old_owner_retired=1)
    add('move_before',14,'replacement',generation=3,transaction=1,transaction_owner='recovery',
        transaction_generation=3,pulse=1,recovery=1,call_id=1)
    add('move_after',14,'replacement',sx=0,result=1)
    add('life_after',14,'replacement',transaction=0,transaction_owner=None,transaction_generation=None,
        pulse=0,recovery=0,result=None,call_id=None)
    add('follow_owner_observed',15,'replacement',generation=4,follow_new=1,follow_any=1)
    add('move_before',16,'replacement',transaction=1,transaction_owner='new_follow',
        transaction_generation=4,pulse=1,call_id=2)
    add('move_after',16,'replacement',sx=2,result=1,follow_moves=1)
    add('sample',17,'replacement',transaction=0,transaction_owner=None,transaction_generation=None,
        pulse=0,result=None,call_id=None)
    add('old_timer_before',55,'replacement')
    add('old_timer_after',55,'replacement',old_timer_count=1,result=0)
    add('final_stop_before',55,'replacement',result=None)
    add('final_stop_after',55,'quiet',generation=5,follow_new=0,follow_any=0)
    for i in range(8):add('quiet_sample',55+i*0.5,'quiet')
    add('quiet_end',59,'quiet')
    return dict(started=0,ended=59,process_ticks=6,life_interval_ds=10,start_delay_ds=6,
                tick_lag_ds=0.5,actual_clients=0,events=e)


def check_fixture_declarations(source):
    declaration='var/global/fixture_handoff_move_sequence = 0'
    if source.count(declaration) != 1:
        raise ValueError('fixture move sequence declaration')


class HandoffReceipt(unittest.TestCase):
    def test_good(self):
        self.assertTrue(validate(good())['follow_move'])

    def test_causal_negative_controls(self):
        def locate(row,name):
            return next(e for e in row['events'] if e['event']==name)
        def stale(row):
            e=next(e for e in row['events'] if e['event']=='move_before' and e['phase']=='replacement')
            e['transaction_old']=1; e['transaction_owner']='old_flee'
        def no_recovery(row):
            for e in row['events']:
                if e['transaction_owner']=='recovery':e['transaction_owner']='other'
        def stale_owner(row):
            locate(row,'old_timer_before')['old_owner_retired']=0
        def old_timer_stops_follow(row):
            locate(row,'old_timer_after')['follow_new']=0
        def offset_erased(row):
            locate(row,'stop_after')['sx']=0
        def offset_unowned(row):
            locate(row,'stop_after')['offset_owned']=0
        def unowned_after_callback(row):
            locate(row,'life_after')['offset_owned']=0
        def no_completion(row):
            locate(row,'old_completion_hook')['old_hooks']=0
        def early_timer(row):
            locate(row,'old_timer_before')['at']=10
        def false_deadline(row):
            locate(row,'old_timer_before')['ticket_deadline']=54
        def unpaired(row):
            next(e for e in row['events'] if e['event']=='move_after')['call_id']=99
        def false_sample(row):
            next(e for e in row['events'] if e['event']=='quiet_sample')['sx']=4
        def reacquired(row):
            next(e for e in row['events'] if e['event']=='quiet_sample')['transaction']=1
        def no_pulse(row):
            next(e for e in row['events'] if e['event']=='move_before')['pulse']=0
        def false_arrival(row):
            locate(row,'old_timer_before')['old_arrived']=1
        def bad_generation(row):
            locate(row,'follow_owner_observed')['generation']=None
        def alias(row):
            locate(row,'stop_after')['x']=5;locate(row,'stop_after')['sx']=34
        def timer_result(row):
            locate(row,'old_timer_after')['result']=1
        def no_life(row):
            row['events']=[e for e in row['events'] if e['event']!='life_before']
        def quiet_short(row):
            locate(row,'quiet_end')['at']=56
        def changed_frame(row):
            next(e for e in row['events'] if e['event']=='move_after')['generation']+=1
        def competitor(row):
            locate(row,'replacement_requested')['wild']=1
        for mutation in (stale,no_recovery,stale_owner,old_timer_stops_follow,offset_erased,offset_unowned,unowned_after_callback,
                         no_completion,early_timer,false_deadline,unpaired,false_sample,reacquired,no_pulse,
                         false_arrival,bad_generation,alias,timer_result,no_life,quiet_short,
                         changed_frame,competitor):
            with self.subTest(mutation=mutation.__name__):
                row=good();mutation(row)
                with self.assertRaises(ValueError):validate(row)

    def test_missing_move_sequence_declaration_is_rejected(self):
        source=Path(__file__).with_name('scheduler_enabled_handoff_draft.dm').read_text(encoding='utf-8')
        declaration='var/global/fixture_handoff_move_sequence = 0'
        check_fixture_declarations(source)
        with self.assertRaises(ValueError):
            check_fixture_declarations(source.replace(declaration,'',1))

    def test_draft_retains_real_scheduler_and_parent_life(self):
        source=Path(__file__).with_name('scheduler_enabled_handoff_draft.dm').read_text(encoding='utf-8')
        for token in ('var/global/fixture_handoff_move_sequence = 0',
                      'P.schedule_interval == 1 SECONDS && P.start_delay == 0.6 SECONDS',
                      'S.start()', 'S.stop()', 'A.npc_subtile_enabled = TRUE',
                      'A.npc_subtile_flee_enabled = TRUE', 'A.npc_subtile_follow_enabled = TRUE',
                      'A.npc_subtile_recovery_enabled = TRUE', 'A.npc_subtile_stop_flee()',
                      'A.npc_set_following(H)', 'fixture_handoff_old_tx.finished',
                      'fixture_handoff_old_hook_count == 1', 'fixture_handoff_old_timer_count == 1'):
            self.assertIn(token,source)
        observe=source.split('/proc/fixture_scheduler_enabled_handoff_observe()',1)[1]
        for forbidden in ('.Life(','.do_behaviour(','.npc_subtile_start_flee(',
                          '.npc_subtile_start_follow(','.ai_step('):
            self.assertNotIn(forbidden,observe)
        for proc in ('/Life()', '/Move()','/npc_subtile_stop_flee_ticket(list/ticket)'):
            body=source.split('/mob/living/simple_animal/pet/cat/scheduler_enabled_handoff'+proc,1)[1].split('\n/',1)[0]
            self.assertEqual(body.count('. = ..()'),1,proc)


if __name__=='__main__':unittest.main()