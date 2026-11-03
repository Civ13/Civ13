import copy
from pathlib import Path
import unittest
import scheduler_hostile_contract as C
HERE=Path(__file__).resolve().parent

def event(kind,at,mode,**kw):
    smooth=mode=='smooth';d=dict(event=kind,at=at,x=6,y=6,z=1,sx=0,sy=0,settled=1,transaction=0,wild_owner=int(smooth),wild_due=3 if smooth else None,
      wild_idle_end=0 if smooth else None,wild_revision=1 if smooth else None,wild_generation=1 if smooth else None,wild_mode='towards' if smooth else None,wild_target_matches=int(smooth) if smooth else None,generation=1,
      pending=0,recovery=0,choice=None,native_choice=None,chance=None,target_x=6,target_y=6,target_z=1,
      target_sx=0,target_sy=0,target_in_range=1,target_brute=0,target_disease=0);d.update(kw);return d

def case(mode):
    smooth=mode=='smooth';at=0;absent=dict(wild_owner=0,wild_due=None,wild_revision=None,wild_generation=None,wild_mode=None,wild_idle_end=None,wild_target_matches=None)
    events=[event('command_before',0,mode,**absent),event('mosquito_intent_towards',0,mode,**absent),event('command_after',0,mode,choice=int(smooth)),event('idle_before_target',5,mode,wild_idle_end=6 if smooth else None),event('target_step_before',5,mode,wild_idle_end=6 if smooth else None),event('target_step_after',5,mode,wild_idle_end=6 if smooth else None,target_x=7)]
    if smooth:
        for i in range(16):
            at=5.5+(i//3)*0.5;events.append(event('mosquito_move_before',at,mode,sx=i*2,target_x=7,transaction=1,settled=0));end=dict(x=7,sx=0) if i==15 else dict(sx=(i+1)*2);events.append(event('mosquito_move_after',at,mode,target_x=7,transaction=1,settled=0,**end))
        at+=.5
    else:
        at=6;events.append(event('mosquito_move_before',at,mode,target_x=7));events.append(event('mosquito_move_after',at,mode,x=7,target_x=7))
    events.append(event('arrived',at,mode,x=7,target_x=7));events.append(event('stop',at,mode,x=7,target_x=7,**absent));events.append(event('quiet_end',at+4,mode,x=7,target_x=7,**absent))
    return dict(mode=mode,started=0,ended=at+4,tick_lag_ds=.5,actual_clients=0,events=events)
def good():return [case('legacy'),case('smooth')]
def receipt():
    rows=good();return dict(head='a'*40,error=None,port=0,byond_version=516,byond_build=1688,scope=C.SCOPE,transition_checks=42,transition_phase='quiet',transition_rows=rows,transition_partial=copy.deepcopy(rows[-1]['events']))
def first(row,label):return next(e for e in row['events'] if e['event']==label)
class ContractTests(unittest.TestCase):
    def setUp(self):self.rows=good()
    def bad(self,which,mutator):
        mutator(self.rows[which]);
        with self.assertRaises(ValueError):C.validate(self.rows[which],self.rows[which]['mode'])
    def test_both_cases(self):
        self.assertEqual(C.validate(self.rows[0],'legacy')['pulses'],1);self.assertEqual(C.validate(self.rows[1],'smooth')['pulses'],16)
    def test_sampled_mismatch_retains_original_threshold(self):
        x=C.validate_receipt(receipt(),'a'*40);self.assertEqual(x['strict_tolerance_ds'],.5);self.assertGreater(x['sampled_difference_ds'],.5);self.assertFalse(x['within_original_tolerance'])
    def test_idle_deadline_missing(self):self.bad(1,lambda r:first(r,'idle_before_target').update(wild_idle_end=0))
    def test_idle_owner_changed(self):self.bad(1,lambda r:first(r,'idle_before_target').update(wild_revision=2))
    def test_first_pulse_late(self):
        def mutate(r):
            for e in r['events']:
                if e['event'] in ('mosquito_move_before','mosquito_move_after','arrived','stop','quiet_end'):e['at']+=1
            r['ended']+=1
        self.bad(1,mutate)
    def test_pulse_teleport(self):self.bad(1,lambda r:first(r,'mosquito_move_after').update(sx=4))
    def test_native_teleport_exceeds_one_tile(self):self.bad(0,lambda r:first(r,'mosquito_move_after').update(x=8))
    def test_target_not_moved(self):self.bad(1,lambda r:first(r,'target_step_after').update(target_x=6))
    def test_stop_not_quiet(self):self.bad(1,lambda r:first(r,'quiet_end').update(wild_owner=1))
    def test_wrong_receipt_scope(self):
        r=receipt();r['scope']='incorrect'
        with self.assertRaises(ValueError):C.validate_receipt(r,'a'*40)
    def test_fixture_calls_real_adapter_and_both_modes(self):
        src=(HERE/'scheduler_hostile_draft.dm').read_text(encoding='utf-8');self.assertIn('A.npc_subtile_species_walk("towards", H, 3)',src);self.assertIn('fixture_insect_chase_case(FALSE)',src);self.assertIn('fixture_insect_chase_case(TRUE)',src);self.assertNotIn('A.Life()',src);self.assertNotIn('A.adjustBruteLoss',src)
if __name__=='__main__':unittest.main()
