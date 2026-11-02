"""Synthetic receipt negatives for the unwired scheduler transition contract."""
import copy
import importlib.util
from pathlib import Path
import unittest

spec=importlib.util.spec_from_file_location('transition_contract',Path(__file__).with_name('scheduler_transition_contract.py'))
contract=importlib.util.module_from_spec(spec);spec.loader.exec_module(contract)

def row(mode,case):
    duration=100 if case=='follow_flee' else 12;flag=int(mode=='mixed');events=[];cid=0;ckind=None;seq=0;commands=0;px=6;ps=0
    def emit(name,t,phase,kind=None,accepted=None,call_id=None):
        events.append(dict(event=name,at=t,phase=phase,kind=kind,accepted=accepted,call_id=call_id,command_id=cid,command_kind=ckind,
            x=px,y=6,z=1,sx=ps,sy=0,generation=0,follow_flag=flag,flee_flag=flag,pet_flag=flag,base_flag=0,transaction=0,pulse=0,
            follow_owner=0,flee_owner=0,pet_owner=0,pursuit_owner=0,wild_owner=0,pending=0,recovery=0))
    def stop(t,phase):
        nonlocal seq,cid,ckind
        seq+=1;ident=seq;emit('stop_before',t,phase,call_id=ident);cid=0;ckind=None;emit('stop_after',t,phase,call_id=ident)
    def run_command(t,phase):
        nonlocal seq,cid,ckind,commands,ps
        seq+=1;life=seq;emit('life_before',t,phase,call_id=life)
        seq+=1;ready=seq;emit('ready_before',t,phase,kind=phase,call_id=ready);emit('ready_after',t,phase,kind=phase,accepted=1,call_id=ready)
        commands+=1;cid=commands;ckind=phase;emit('command_return',t,phase,kind=phase)
        emit('life_after',t,phase,call_id=life);seq+=1;move=seq
        emit('move_before',t,phase,call_id=move);ps+=2;emit('move_after',t,phase,accepted=0,call_id=move)
    for tick in range(duration*2):
        t=tick/2;phase='pet' if case=='pet' else ('follow' if t<30 else 'gap' if t<40 else 'flee')
        if case=='follow_flee' and t==30:
            emit('stimulus_before',t,'follow');stop(t,'gap')
        if case=='follow_flee' and t==40:emit('stimulus_after',t,'flee')
        emit('sample',t,phase)
        if t==1 or (case=='follow_flee' and t==41):run_command(t,phase)
    phase='pet' if case=='pet' else 'flee';emit('observation_end',duration,phase);stop(duration,'quiet')
    for tick in range(8):emit('quiet_sample',duration+tick/2,'quiet')
    emit('quiet_end',duration+4,'quiet');emit('end',duration+4,'quiet')
    return dict(mode=mode,scenario=case,started=0,ended=duration+4,process_ticks=3,
                life_interval_ds=10,start_delay_ds=6,tick_lag_ds=0.5,actual_clients=0,events=events)

def rows(mode):return [row(mode,'follow_flee'),row(mode,'pet')]

class ReceiptContracts(unittest.TestCase):
    def setUp(self):self.rows=rows('mixed')
    def test_real_receipt_envelope_and_partial_trace_are_required(self):
        def receipt(mode):
            value=rows(mode)
            return dict(head='a'*40,error=None,port=0,byond_version=516,byond_build=1688,
                        scope='headless mob scheduler; native fallback only; no smooth/client parity',
                        transition_checks=1,transition_phase='quiet',transition_rows=value,
                        transition_partial=copy.deepcopy(value[-1]['events']))
        left,right=receipt('legacy'),receipt('mixed')
        self.assertEqual(set(contract.compare_receipts(left,right,'a'*40)),{'legacy','mixed'})
        for field,value in (('head','b'*40),('error','bad'),('port',1),('byond_build',1687),
                            ('transition_checks',0),('transition_phase','flee'),('transition_partial',[])):
            bad=copy.deepcopy(right);bad[field]=value
            with self.subTest(field=field),self.assertRaises(ValueError):contract.validate_receipt(bad,'a'*40,'mixed')
    def test_positive_pair_and_false_native_return_with_displacement(self):
        got=contract.compare_pair(rows('legacy'),self.rows)
        self.assertEqual(got['mixed']['follow_flee']['moves'],{'follow':1,'flee':1});self.assertEqual(got['mixed']['pet']['moves'],{'pet':1})
    def test_unclosed_ready_or_reused_call_id_is_rejected(self):
        for name in ('ready_after','move_before','stop_after'):
            bad=copy.deepcopy(self.rows);events=bad[0]['events'];index=next(i for i,e in enumerate(events) if e['event']==name);del events[index]
            with self.subTest(name=name),self.assertRaises(ValueError):contract.validate_rows(bad,'mixed')
        bad=copy.deepcopy(self.rows);e=[x for x in bad[0]['events'] if x['event']=='life_before'];e[1]['call_id']=e[0]['call_id']
        with self.assertRaises(ValueError):contract.validate_rows(bad,'mixed')
    def test_ready_alone_or_old_follow_epoch_cannot_prove_flee(self):
        bad=copy.deepcopy(self.rows);events=bad[0]['events'];ready=next(e for e in events if e['event']=='ready_after' and e['kind']=='flee');ready['accepted']=0
        with self.assertRaises(ValueError):contract.validate_rows(bad,'mixed')
        bad=copy.deepcopy(self.rows);e=next(e for e in bad[0]['events'] if e['event']=='command_return' and e['kind']=='flee');e['command_id']=1;e['command_kind']='follow'
        with self.assertRaises(ValueError):contract.validate_rows(bad,'mixed')
    def test_move_before_dispatch_cannot_prove_command(self):
        bad=copy.deepcopy(self.rows);events=bad[1]['events'];i=next(i for i,e in enumerate(events) if e['event']=='command_return');dispatch=events.pop(i);j=next(i for i,e in enumerate(events) if e['event']=='move_after');events.insert(j+1,dispatch)
        with self.assertRaises(ValueError):contract.validate_rows(bad,'mixed')
    def test_owner_leak_and_bad_flags_fail(self):
        for field,value in (('pending',1),('recovery',1),('pulse',1),('pursuit_owner',1),('wild_owner',1),('follow_flag',0),('generation',None)):
            bad=copy.deepcopy(self.rows);bad[0]['events'][0][field]=value
            with self.subTest(field=field),self.assertRaises(ValueError):contract.validate_rows(bad,'mixed')
    def test_truncated_samples_and_missing_end_fail(self):
        bad=copy.deepcopy(self.rows);bad[1]['events']=[e for e in bad[1]['events'] if not(e['event']=='sample' and e['at']>8)]
        with self.assertRaises(ValueError):contract.validate_rows(bad,'mixed')
        bad=copy.deepcopy(self.rows);bad[0]['events'].pop()
        with self.assertRaises(ValueError):contract.validate_rows(bad,'mixed')
    def test_quiet_gap_requires_samples_and_no_move(self):
        for phase in ('gap','quiet'):
            bad=copy.deepcopy(self.rows);events=bad[0]['events'];i=next(i for i,e in enumerate(events) if e['phase']==phase and e['event'] in ('sample','quiet_sample'));events[i]['event']='move_before';events[i]['call_id']=999
            with self.subTest(phase=phase),self.assertRaises(ValueError):contract.validate_rows(bad,'mixed')
        bad=copy.deepcopy(self.rows);bad[0]['events']=[e for e in bad[0]['events'] if not(e['event']=='quiet_sample' and e['at']>101)]
        with self.assertRaises(ValueError):contract.validate_rows(bad,'mixed')
    def test_missing_stimulus_or_wrong_phase_fails(self):
        bad=copy.deepcopy(self.rows);bad[0]['events']=[e for e in bad[0]['events'] if e['event']!='stimulus_after']
        with self.assertRaises(ValueError):contract.validate_rows(bad,'mixed')
        bad=copy.deepcopy(self.rows)
        for e in bad[0]['events']:
            if e['event'] in ('ready_before','ready_after') and e['kind']=='flee':e['phase']='follow'
        with self.assertRaises(ValueError):contract.validate_rows(bad,'mixed')
    def test_gap_and_terminal_quiet_require_fixed_position_and_generation(self):
        for case,marker in ((0,'sample'),(0,'stimulus_after'),(0,'quiet_sample'),(0,'quiet_end'),(0,'end'),(1,'quiet_sample')):
            for field in ('x','generation'):
                bad=copy.deepcopy(self.rows)
                event=next(e for e in bad[case]['events'] if e['event']==marker and (marker!='sample' or e['phase']=='gap'))
                event[field]+=1
                with self.subTest(case=case,marker=marker,field=field),self.assertRaises(ValueError):contract.validate_rows(bad,'mixed')
    def test_canonical_map_and_offset_bounds_are_required(self):
        for field,value in (('x',0),('x',19),('y',0),('y',15),('z',2),('sx',-1),('sx',32),('sy',-1),('sy',32)):
            bad=copy.deepcopy(self.rows);bad[0]['events'][0][field]=value
            with self.subTest(field=field,value=value),self.assertRaises(ValueError):contract.validate_rows(bad,'mixed')
        # Equal physical coordinates do not make an unnormalized alias valid.
        bad=copy.deepcopy(self.rows);event=bad[0]['events'][0];event['x']-=1;event['sx']=32
        with self.assertRaises(ValueError):contract.validate_rows(bad,'mixed')
    def test_scheduler_and_case_envelope_fail_closed(self):
        for field,value in (('process_ticks',0),('actual_clients',1),('start_delay_ds',4),('tick_lag_ds',1)):
            bad=copy.deepcopy(self.rows);bad[0][field]=value
            with self.subTest(field=field),self.assertRaises(ValueError):contract.validate_rows(bad,'mixed')

if __name__=='__main__':unittest.main()
