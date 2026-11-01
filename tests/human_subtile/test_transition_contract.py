"""Synthetic positive/negative tests for the draft observer contract."""
import copy
import hashlib
import importlib.util
from pathlib import Path
import re
import unittest
from unittest.mock import patch

spec=importlib.util.spec_from_file_location('transition_contract', Path(__file__).with_name('transition_contract.py'))
c=importlib.util.module_from_spec(spec)
spec.loader.exec_module(c)


def row(case):
    events=[]
    x, y = 12*32, 32*32
    def add(label, at, **values):
        event={'event':label,'at':at,'x':x//32,'y':y//32,'z':1,'sx':x%32,'sy':y%32,
               'tick_usage':1,'enabled':1,'life_depth':0,'transaction':0,'pulse':0,
               'owner':None,'pending':None,'recovery':None,'tx_intent':None,'active_tx':None,'tx':None,'generation':1,'step_size':32}
        event.update(values); events.append(event)
    def admit(tx, at, direction):
        intent='recover' if tx=='recovery' else ('newwalk' if tx=='north' else 'walk')
        add('tx_admitted',at,tx=tx,active_tx=tx,transaction=1,tx_dir=direction,tx_intent=intent,
            owner='newwalk' if tx=='north' else None)
    def move(tx, at, dx, dy):
        nonlocal x,y
        add('move_enter',at,active_tx=tx,transaction=1)
        x+=dx; y+=dy
        add('move_exit',at,active_tx=tx,transaction=1)
    def finish(tx, at, arrived):
        add('tx_actor_released',at,tx=tx,tx_finished=0,tx_actor_present=1,arrived=arrived)
        add('tx_finished',at,tx=tx,tx_finished=1,tx_actor_present=0,tx_target_present=0,
            tx_combat_present=0,tx_following_present=0,tx_intent_present=0,arrived=arrived)
    add('transition_start',0,detail={'case':case,'wall_dense':int(case=='blocked'),
                                     'bound_x':0,'bound_y':0,'bound_width':32,'bound_height':32})
    add('command_before',0,detail={'mode':'direction','lag':4,'speed_argument':0,'direction':4})
    add('command_after',0,detail=1,owner='walk')
    admit('old',4,4); move('old',4,0 if case=='blocked' else 2,0)
    if case=='blocked':
        finish('old',4,0)
        admit('second',8,4); move('second',8,0,0); finish('second',8,0)
        add('transition_blocked_end',9,detail={'wall_dense':1})
        add('transition_end',9.5,detail={'case':case})
    else:
        add('transition_before',7.5,tx='old',active_tx='old',transaction=1,owner='walk',tx_finished=0,
            detail={'case':case,'old_end':8,'offset_owned':1})
        add('transition_after',7.5,tx='old',active_tx='old',transaction=1,generation=2,detail={'case':case,'old_end':8})
        add('transition_old_completion',8)
        finish('old',8,0)
        add('transition_old_terminal',8,tx='old',tx_finished=1,arrived=0,detail={'case':case,'completions':1})
        add('transition_recovery',8,recovery='recover',detail={'case':case,'recovery':1})
        add('command_before',8,detail={'mode':'direction','lag':4,'speed_argument':0,'direction':1})
        add('command_after',8,detail=1,pending='new')
        add('transition_replacement',8,pending='new',recovery='recover',detail={'case':case,'recovery':1,'pending':1})
        admit('recovery',8.5,8); move('recovery',8.5,-2,0)
        add('final_pulse',9,tx='recovery',active_tx='recovery',transaction=1,remaining_x=0,remaining_y=0)
        finish('recovery',9,1)
        admit('north',13,1); move('north',13,0,2)
        add('transition_wait_end',13,tx='old',tx_finished=1,arrived=0,active_tx='north',transaction=1,owner='newwalk',detail={'case':case})
        finish('north',13.5,0)
        add('transition_end',14,detail={'case':case})
    return {'case':case,'tick':.5,'lag':4,'start':0,'end':events[-1]['at'],'events':events,
            'event_count':len(events),'move_enter_count':sum(e['event']=='move_enter' for e in events),
            'move_exit_count':sum(e['event']=='move_exit' for e in events),
            'tx_count':sum(e['event']=='tx_admitted' for e in events),'life_count':0,'overflow':0}


class TransitionContractTests(unittest.TestCase):
    def test_exact_source_binding_rejects_drift(self):
        paths=b'\0'.join(p.encode() for p in sorted(c.ALLOWED_DELTA))+b'\0'
        def check(args,**kwargs):
            return (c.BASE_TREE+'\n').encode() if args[1]=='rev-parse' else paths
        with patch.object(c.subprocess,'check_output',side_effect=check), \
             patch.object(c.subprocess,'run',return_value=type('Result',(),{'returncode':0})()):
            self.assertTrue(c.validate_source(['git'],{},'a'*40))
            original=paths
            for bad in (original+b'unrelated\0',b'\0'.join(original.split(b'\0')[:-2])+b'\0',
                        original+next(iter(c.ALLOWED_DELTA)).encode()+b'\0',original[:-1]):
                paths=bad
                with self.assertRaises(ValueError): c.validate_source(['git'],{},'a'*40)
        with patch.object(c.subprocess,'check_output',return_value=b'0'*40):
            with self.assertRaises(ValueError): c.validate_source(['git'],{},'a'*40)
        with patch.object(c.subprocess,'check_output',return_value=(c.BASE_TREE+'\n').encode()), \
             patch.object(c.subprocess,'run',return_value=type('Result',(),{'returncode':1})()):
            with self.assertRaises(ValueError): c.validate_source(['git'],{},'a'*40)

    def test_receipt_identity_and_readiness(self):
        rows=[row('blocked'),row('cancel_replace')]
        for r in rows:
            r['start']+=1; r['end']+=1
            for event in r['events']:
                event['at']+=1
                if isinstance(event.get('detail'),dict) and 'old_end' in event['detail']:
                    event['detail']['old_end']+=1
        value={'head':'a'*40,'error':None,'port':0,'byond_version':516,'byond_build':1688,
               'scope':c.SCOPE,'movement_blob':c.MOVEMENT_BLOB,'overflow':0,
               'setup':{'requested_tick':.5,'actual_tick':.5,'startup_time':0,'ready_time':.5,
                        'startup_usage':10000,'ready_usage':1},'transition_rows':rows,
               'transition_case':'cancel_replace','transition_checks':1,'transition_partial':rows[-1]['events']}
        self.assertEqual(len(c.validate_receipt(value,'a'*40)),2)
        for change in (lambda x:x.update(head='b'*40), lambda x:x.update(movement_blob='b'*40),
                       lambda x:x['setup'].update(ready_time=0), lambda x:x['transition_rows'].pop(),
                       lambda x:x.update(transition_partial=[])):
            bad=copy.deepcopy(value);change(bad)
            with self.assertRaises(ValueError): c.validate_receipt(bad,'a'*40)

    def test_fixture_source_uses_real_ownership_and_no_actor_teleport(self):
        source=Path(__file__).with_name('transition_probe.dm').read_text()
        for token in ('A.npc_subtile_stop_wild_walk()', 'A.npc_subtile_request_recovery()',
                      'A.npc_subtile_species_walk("direction", null, 4, NORTH)',
                      'A.npc_subtile_pending_intent', 'A.npc_subtile_offset_owned',
                      'fixture_transition_old_completions == 1', 'wall.density = TRUE',
                      'fixture_random_tx_count >= 2 && fixture_random_tx_count <= 3'):
            self.assertIn(token, source)
        for forbidden in ('A.forceMove(', 'A.Move(', 'step(A,', 'rand(', 'prob('):
            self.assertNotIn(forbidden, source)
        self.assertIsNone(re.search(r'A\.step_[xy]\s*=(?!=)', source))
        body=source.split('/mob/living/simple_animal/mosquito/scheduler_probe/random_probe/living_movement_completed()',1)[1].split('/proc/fixture_transition_phase',1)[0]
        self.assertIn('. = ..()', body)

    def test_exact_reviewed_production_source_identity(self):
        source=Path(__file__).resolve().parents[2]/'code/game/mob/living/simple_animal/subtile_movement.dm'
        raw=source.read_bytes()
        self.assertEqual(hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest(),
                         'c658aa260cd486f5c8a82dc796e048c321362d54')

    def test_recorder_preimages_are_the_reviewed_versions(self):
        root=Path(__file__).resolve().parent
        expected={'random_cadence_fixture.dm':'540016e42b025c40bc4e02973b73564ec211e795',
                  'scheduler_core_draft.dm':'cb785e691885a46bde101c525ecc35a9cc18bebf',
                  'random_cadence_contract.py':'3a69b891797628aa76104b8936580b6982e9ff3b',
                  'probe.dm':'58afd77c15b3b89a3c924e428068085b04f6614a'}
        for name,digest in expected.items():
            raw=(root/name).read_bytes()
            self.assertEqual(hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest(),digest,name)

    def test_positive_pair(self):
        results=c.validate_pair([row('blocked'),row('cancel_replace')])
        self.assertEqual(results[0]['attempts'],2)
        self.assertEqual(results[1]['north_progress'],2)

    def test_block_penetration_or_retry_storm_fails(self):
        original=row('blocked')
        for mutation in (lambda r:r['events'][5].update(sx=2),
                         lambda r:r.update(tx_count=20),
                         lambda r:next(e for e in r['events'] if e['event']=='tx_admitted' and e['tx']=='second').update(at=4),
                         lambda r:r['events'][0]['detail'].update(wall_dense=0)):
            bad=copy.deepcopy(original); mutation(bad)
            with self.assertRaises(ValueError): c.validate(bad)

    def test_stale_old_pulse_missing_completion_and_lost_pending_fail(self):
        original=row('cancel_replace')
        for mutation in (
            lambda r: next(e for e in r['events'] if e['event']=='transition_old_terminal')['detail'].update(completions=2),
            lambda r: next(e for e in r['events'] if e['event']=='transition_replacement')['detail'].update(pending=0),
            lambda r: next(e for e in r['events'] if e['event']=='transition_before')['detail'].update(offset_owned=0),
            lambda r: next(e for e in r['events'] if e['event']=='transition_after').update(generation=1),
            lambda r: next(e for e in r['events'] if e['event']=='move_enter' and e['active_tx']=='north').update(active_tx='old'),
            lambda r: next(e for e in r['events'] if e['event']=='tx_finished' and e['tx']=='old').update(tx_actor_present=1),
            lambda r: next(e for e in r['events'] if e['event']=='tx_finished' and e['tx']=='recovery').update(arrived=0),
            lambda r: next(e for e in r['events'] if e['event']=='tx_admitted' and e['tx']=='recovery').update(tx_intent='wrong-owner'),
        ):
            bad=copy.deepcopy(original); mutation(bad)
            with self.assertRaises(ValueError): c.validate(bad)

    def test_incomplete_duplicate_and_overflow_fail(self):
        for rows in ([row('blocked'),row('blocked')], [row('cancel_replace')]):
            with self.assertRaises(ValueError): c.validate_pair(rows)
        bad=row('cancel_replace'); bad['overflow']=1
        with self.assertRaises(ValueError): c.validate(bad)


if __name__=='__main__': unittest.main()
