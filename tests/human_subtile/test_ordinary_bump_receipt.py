"""Offline positive and negative controls for the current-source receipt oracle."""
import copy
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('ordinary_bump_receipt', ROOT / 'ordinary_bump_receipt.py')
oracle = importlib.util.module_from_spec(spec)
spec.loader.exec_module(oracle)


def row(name, mode):
    events = []
    def add(label, human=(10,10,0,0), goat=(11,10,0,0), **overrides):
        actor, other = ('human','goat') if name == 'human_idle' else ('goat','human')
        e = {'ordinal':len(events)+1,'at':len(events)*0.5,'case':name,'label':label,'actor':actor,'other':other,
             'hx':human[0],'hy':human[1],'hsx':human[2],'hsy':human[3],
             'ax':goat[0],'ay':goat[1],'asx':goat[2],'asy':goat[3],
             'human_owned':0,'human_transaction':0,'same_admission':0,'human_pulse':0,
             'human_completions':0,'living_completions':0,'human_pushing':0,'goat_pushing':0}
        e.update(overrides);events.append(e)
    add('initial')
    active = name == 'goat_active_permitted'
    if active:
        add('active_before_goat',human=(10,10,0,2),human_owned=1,human_transaction=1,same_admission=1)
        add('goat_bump_before',human=(10,10,0,2),human_owned=1,human_transaction=1,same_admission=1)
    else:
        add('human_bump_before' if name == 'human_idle' else 'goat_bump_before')
    swapped = mode == 'legacy' and name in ('human_idle','goat_idle_permitted')
    if swapped:
        add('first_leg_before');add('first_leg_after',human=(11,10,0,0))
        add('second_leg_before',human=(11,10,0,0));add('second_leg_after',human=(11,10,0,0),goat=(10,10,0,0))
    elif mode == 'candidate' and name != 'goat_idle_default':
        if active:add('veto',human=(10,10,0,2),human_owned=1,human_transaction=1,same_admission=1)
        else:add('veto')
    if active:
        add('post_deferred',human=(10,10,0,4),human_owned=1,human_transaction=1,same_admission=1)
        add('terminal',human=(10,11,0,0),human_completions=1,living_completions=1)
        pulses=[{'x':10,'y':10+(i//16),'sx':0,'sy':(2*i)%32} for i in range(1,17)]
    elif swapped:
        add('post_deferred',human=(11,10,0,0),goat=(10,10,0,0)); add('terminal',human=(11,10,0,0),goat=(10,10,0,0)); pulses=[]
    else:
        add('post_deferred');add('terminal');pulses=[]
    return {'case':name,'callbacks':1,'events':events,'human_pulses':pulses,'overflow':0}


def receipt(mode):
    return {'head':'a'*40,'scope':oracle.SCOPE,'ordinary_bump_mode':mode,'byond_version':516,
            'byond_build':1688,'port':0,'error':None,'checks':20,'ordinary_bump_overflow':0,
            'ordinary_bump_rows':[row(name,mode) for name in oracle.CASES]}


class ReceiptControls(unittest.TestCase):
    def setUp(self):
        self.old=receipt('legacy');self.new=receipt('candidate')

    def test_complete_pair_is_observation_not_visual_acceptance(self):
        self.assertEqual(oracle.compare(self.old,self.new,'a'*40),{'ordinary_cases_observed':4,'visual_or_broad_parity_established':False})

    def rejects(self, change):
        old,new=copy.deepcopy(self.old),copy.deepcopy(self.new)
        change(old,new)
        with self.assertRaises(ValueError):oracle.compare(old,new,'a'*40)

    def test_missing_veto_or_stray_swap_leg_rejected(self):
        def missing(o,n): n['ordinary_bump_rows'][0]['events'][2]['label']='after_attempt'
        def stray(o,n): n['ordinary_bump_rows'][0]['events'][2]['label']='first_leg_before'
        self.rejects(missing);self.rejects(stray)

    def test_partial_owner_loss_wrong_final_or_missing_pulse_rejected(self):
        def owner(o,n):
            x=n['ordinary_bump_rows'][3]['events'];next(e for e in x if e['label']=='post_deferred')['same_admission']=0
        def final(o,n):n['ordinary_bump_rows'][3]['events'][-1]['hsy']=2
        def pulse(o,n):n['ordinary_bump_rows'][3]['human_pulses'].pop()
        self.rejects(owner);self.rejects(final);self.rejects(pulse)

    def test_wrong_actor_duplicate_checkpoint_or_wrong_mode_rejected(self):
        def actor(o,n):n['ordinary_bump_rows'][0]['events'][1]['actor']='goat'
        def checkpoint(o,n):n['ordinary_bump_rows'][0]['events'][-1]['label']='post_deferred'
        def mode(o,n):n['ordinary_bump_mode']='legacy'
        self.rejects(actor);self.rejects(checkpoint);self.rejects(mode)

    def test_equivalent_world_position_with_nonnormalized_offsets_is_rejected(self):
        def human_terminal(o,n):
            e=n['ordinary_bump_rows'][0]['events'][-1];e['hx']=9;e['hsx']=32
        def goat_terminal(o,n):
            e=n['ordinary_bump_rows'][0]['events'][-1];e['ax']=10;e['asx']=32
        def active_terminal(o,n):
            e=n['ordinary_bump_rows'][3]['events'][-1];e['hy']=10;e['hsy']=32
        def pulse_equivalent(o,n):
            p=n['ordinary_bump_rows'][3]['human_pulses'][0];p['x']=9;p['sx']=32
        for mutation in (human_terminal,goat_terminal,active_terminal,pulse_equivalent):
            with self.subTest(mutation=mutation.__name__):self.rejects(mutation)

    def test_out_of_bounds_tiles_and_offsets_rejected_for_both_actors(self):
        for actor,field,bad in (('human','hx',0),('human','hx',19),('human','hy',0),('human','hy',15),
                                ('goat','ax',0),('goat','ax',19),('goat','ay',0),('goat','ay',15),
                                ('human','hsx',-1),('human','hsy',32),('goat','asx',-1),('goat','asy',32)):
            def mutate(o,n,field=field,bad=bad):n['ordinary_bump_rows'][0]['events'][1][field]=bad
            with self.subTest(actor=actor,field=field,bad=bad):self.rejects(mutate)
    def test_default_reverse_difference_and_truncated_receipt_rejected(self):
        def changed(o,n):n['ordinary_bump_rows'][1]['events'][-1]['ax']=10
        def missing(o,n):n['ordinary_bump_rows'].pop()
        self.rejects(changed);self.rejects(missing)


if __name__=='__main__':unittest.main()