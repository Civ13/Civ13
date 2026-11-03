import copy
from pathlib import Path
import unittest
import scheduler_hostile_contract as C
HERE=Path(__file__).resolve().parent

def event(kind,at,**kw):
    d=dict(event=kind,at=at,x=6,y=6,z=1,sx=0,sy=0,settled=1,transaction=0,wild_owner=1,wild_due=3,
      wild_idle_end=0,wild_revision=1,wild_generation=1,wild_mode='towards',wild_target_matches=1,generation=1,
      pending=0,recovery=0,choice=None,native_choice=None,chance=None,target_x=6,target_y=6,target_z=1,
      target_sx=0,target_sy=0,target_in_range=1,target_brute=0,target_disease=0)
    d.update(kw);return d

def good():
    events=[event('command_before',0,wild_owner=0,wild_due=None,wild_revision=None,wild_generation=None,wild_mode=None),
            event('mosquito_intent_towards',0,wild_owner=0,wild_due=None,wild_revision=None,wild_generation=None,wild_mode=None),
            event('command_after',0,choice=1),event('idle_before_target',3.5,wild_idle_end=6),
            event('target_step_before',3.5,wild_idle_end=6),event('target_step_after',3.5,wild_idle_end=6,target_x=7)]
    for i in range(16):
        at=4+(i//3)*0.5;events.append(event('mosquito_move_before',at,sx=i*2,target_x=7,transaction=1,settled=0));
        end=dict(x=7,sx=0) if i==15 else dict(sx=(i+1)*2)
        events.append(event('mosquito_move_after',at,target_x=7,transaction=1,settled=0,**end))
    events.extend([event('arrived',7,x=7,target_x=7),
      event('stop',7,x=7,target_x=7,wild_owner=0,wild_due=None,wild_revision=None,wild_generation=None,wild_mode=None),
      event('quiet_end',11,x=7,target_x=7,wild_owner=0,wild_due=None,wild_revision=None,wild_generation=None,wild_mode=None)])
    return dict(started=0,ended=11,tick_lag_ds=.5,actual_clients=0,events=events)

def first(row,label): return next(e for e in row['events'] if e['event']==label)
class ContractTests(unittest.TestCase):
    def setUp(self): self.row=good()
    def bad(self,mutator):
        mutator(self.row)
        with self.assertRaises(ValueError):C.validate(self.row)
    def test_good(self): self.assertTrue(C.validate(self.row)['target_response'])
    def test_idle_deadline_missing(self): self.bad(lambda r:first(r,'idle_before_target').update(wild_idle_end=0))
    def test_idle_owner_changed(self): self.bad(lambda r:first(r,'idle_before_target').update(wild_revision=2))
    def test_first_pulse_late(self):
        def mutate(r):
            for e in r['events']:
                if e['event'] in ('mosquito_move_before','mosquito_move_after','arrived','stop','quiet_end'):e['at']+=1
            r['ended']+=1
        self.bad(mutate)
    def test_pulse_teleport(self): self.bad(lambda r:first(r,'mosquito_move_after').update(sx=4))
    def test_pulse_wrong_generation(self): self.bad(lambda r:first(r,'mosquito_move_after').update(wild_generation=2))
    def test_target_not_moved(self): self.bad(lambda r:first(r,'target_step_after').update(target_x=6))
    def test_stop_not_quiet(self): self.bad(lambda r:first(r,'quiet_end').update(wild_owner=1))
    def test_idle_missing(self): self.bad(lambda r:r['events'].remove(first(r,'idle_before_target')))
    def test_wrong_receipt_scope(self):
        row=good();head='a'*40
        receipt=dict(head=head,error=None,port=0,byond_version=516,byond_build=1688,scope=C.SCOPE,
           transition_checks=1,transition_phase='quiet',transition_rows=[row],transition_partial=copy.deepcopy(row['events']))
        self.assertTrue(C.validate_receipt(receipt,head)['target_response'])
        receipt['scope']='incorrect'
        with self.assertRaises(ValueError):C.validate_receipt(receipt,head)
    def test_fixture_calls_real_adapter_and_preserves_bounds(self):
        src=(HERE/'scheduler_hostile_draft.dm').read_text(encoding='utf-8')
        self.assertIn('A.npc_subtile_species_walk("towards", H, 3)',src)
        self.assertIn('W.idle_window_end == original_due + 3',src)
        self.assertNotIn('A.Life()',src);self.assertNotIn('A.adjustBruteLoss',src)
if __name__=='__main__':unittest.main()
