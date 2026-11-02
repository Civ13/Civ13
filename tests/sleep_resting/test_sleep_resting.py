"""Source-projected Sleep countdown/capacity, not native timing or storage."""
from copy import copy
import importlib.util
import itertools
from pathlib import Path
import re
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('resting_source_adapter', ROOT/'tests/save_movement/source_adapter.py')
A = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(A)
A.FIELDS += ('client','disease','hygiene','wear_suit','w_uniform','shoes',
             'paralysis','stunned','weakened','resting','status_flags','restrained')
FLAGS = {}
for name, expression in re.findall(r'^#define (INCAPACITATION_\w+) (.+)$', (ROOT/'code/__defines/mobs.dm').read_text(encoding='utf-8-sig'), re.M):
    expression = expression.split('//',1)[0].strip()
    assert re.fullmatch(r'[A-Z0-9_()| &~x+-]+', expression)
    FLAGS[name] = eval(expression, {'__builtins__':{}}, FLAGS)
DEFAULT = FLAGS['INCAPACITATION_DEFAULT']
PERMISSION = FLAGS['INCAPACITATION_DISABLED_NO_REST']
SLEEP_FLAGS = (DEFAULT & ~FLAGS['INCAPACITATION_DISABLED']) | PERMISSION
FAKEDEATH = 1  # Isolated fake status bit; actual status definitions are unchanged.
FIELDS = ('stat','paralysis','stunned','weakened','resting','sleeping','status_flags')


def capacity(source):
    # Bound to the proc before its enclosing file's trailing #undef directives.
    source = source.split('\n#undef UNBUCKLED',1)[0]
    env = dict(FLAGS, FAKEDEATH=FAKEDEATH, PARTIALLY_BUCKLED=1, FULLY_BUCKLED=2)
    return A.project(source,'/mob/proc/incapacitated','src,incapacitation_flags',env,method=True)


CURRENT = capacity((ROOT/'code/game/mob/mob.dm').read_text(encoding='utf-8-sig'))
LEGACY = capacity((Path(__file__).parent/'fixtures/legacy_incapacitated.dm').read_text(encoding='utf-8'))


class Clothing:
    def __init__(self, fleas=False): self.fleas=fleas
class Bed: pass
class Turf:
    def __init__(self): self.beds=[Bed()]
    def __iter__(self): return iter(self.beds)
class Client:
    def __init__(self, actor): self.mob=actor;self.closed=False
    def __bool__(self): return not self.closed
class Bar:
    def __init__(self): self.deleted=False;self.updates=[]
    def update(self, elapsed): self.updates.append(elapsed)
class Actor:
    def __init__(self, resting=False):
        self.loc=Turf();self.step_x=0;self.step_y=0;self.deleted=False
        self.stat=0;self.paralysis=0;self.stunned=0;self.weakened=0
        self.resting=resting;self.sleeping=0;self.status_flags=0
        self.restrained_state=False;self.buckle_level=0;self.lying=False
        self.client=Client(self);self.may_do_after=True;self.hand=object()
        self.started=0;self.finished=0;self.disease=False;self.hygiene=100
        self.wear_suit=Clothing();self.w_uniform=None;self.shoes=None
        self.answer='Yes'
    def __bool__(self): return not self.deleted
    def incapacitated(self, flags=DEFAULT): return CURRENT(self,flags)
    def restrained(self): return self.restrained_state
    def buckled(self): return self.buckle_level
    def get_active_hand(self): return self.hand
    def survival_action_started(self): self.started+=1
    def survival_action_finished(self): self.finished+=1


class Harness:
    def __init__(self, actor, bridge=False, legacy_prefix=False):
        self.actor=actor;self.world=SimpleNamespace(time=0);self.hook=None
        self.bars=[];self.messages=[];self.wait_calls=[];self.bridge=bridge
        def sleep(delay):
            self.world.time+=1
            if self.hook:
                hook=self.hook;self.hook=None;hook()
        def bar(*args):
            value=Bar();self.bars.append(value);return value
        def typed_iter(values,path):
            cls={'/obj/structure/bed':Bed,'/obj/item/clothing':Clothing}[path]
            return [v for v in values if isinstance(v,cls)]
        self.env=dict(FLAGS, world=self.world, sleep=sleep, isnull=lambda v:v is None,
            istype=lambda value,kind:isinstance(value,kind), MINING_CONTEXT_TYPE=type('Mining',(),{}),
            LEASE_TYPE=type('Lease',(),{}), new_progressbar=bar, qdel=lambda v:setattr(v,'deleted',True),
            MINUTES=600, list=lambda *v:v, typed_iter=typed_iter, get_turf=lambda mob:mob.loc,
            to_chat=lambda user,message:self.messages.append(message), SPAN_RED=lambda s:s,
            SPAN_NOTICE=lambda s:s, SPAN_WARNING=lambda s:s, WWalert=lambda *a:None,
            WWinput=lambda *a:actor.answer, usr=actor, map=SimpleNamespace(ID='ordinary'),
            MAP_VOYAGE='voyage', persistence_sleep_transfer_blocked=lambda:False,
            persistence_bed_return_enabled=lambda:False)
        source=(ROOT/'code/_helpers/mobs.dm').read_text(encoding='utf-8-sig')
        pattern=r'#ifdef CIV13_GAMEPLAY_BRIDGE\n(/proc/do_after[^\n]+)\n#else\n(/proc/do_after[^\n]+)\n#endif'
        source,count=re.subn(pattern,lambda m:m[1] if bridge else m[2],source)
        assert count==1
        defines=dict(A.DEFAULT_DEFINES,CIV13_GAMEPLAY_BRIDGE=bridge)
        body=A.extract(source,'/proc/do_after',defines=defines)
        lines=[]
        for line in body.splitlines():
            if line.strip().startswith('var/') and '=' not in line: line+=' = null'
            line=line.replace('= new(user, delay, target)','= new_progressbar(user, delay, target)')
            line=line.replace('istype(mining_context, /datum/pickaxe_mining_action)','istype(mining_context, MINING_CONTEXT_TYPE)')
            line=line.replace('istype(gameplay_context, /datum/gameplay_action_lease)','istype(gameplay_context, LEASE_TYPE)')
            if line.strip()=='while (world.time < endtime)': line+=':'
            lines.append(line)
        selected='/proc/do_after()\n'+'\n'.join(lines)+'\n\treturn .\n'
        args='user,delay,target=None,needhand=True,progress=True,incapacitation_flags=DEFAULT,can_move=False,check_for_repeats=True,mining_context=None'
        if bridge: args+=',gameplay_context=None'
        self.env['DEFAULT']=DEFAULT
        self.core=A.project(selected,'/proc/do_after',args,self.env)
        def do_after(*args,**kwargs):
            self.wait_calls.append((args,kwargs));return self.core(*args,**kwargs)
        self.env['do_after']=do_after
        human=(ROOT/'code/game/mob/living/carbon/human/human_helpers.dm').read_text(encoding='utf-8-sig')
        full=A.extract(human,'/mob/living/human/verb/mob_sleep')
        if legacy_prefix:
            prefix=(Path(__file__).parent/'fixtures/legacy_sleep_prefix.dm').read_text(encoding='utf-8')
        else:
            line=next(line for line in full.splitlines() if 'if (do_after(' in line)
            call=line.strip()[4:-1]
            prefix='/mob/living/human/verb/mob_sleep()\n'+full[:full.index(line)]+'\t\treturn '+call+'\n'
        prefix=prefix.replace('2 MINUTES','2 * MINUTES')
        self.prefix=A.project(prefix,'/mob/living/human/verb/mob_sleep','src',self.env,method=True)
        captured=re.search(r'var/client/(\w+) = client',full)[1]
        guard=next(line.strip() for line in full.splitlines() if f'client != {captured}' in line)
        guard_source='/proc/client_completion_guard()\n\t'+guard+'\n\t\treturn FALSE\n\treturn TRUE\n'
        self.guard=A.project(guard_source,'/proc/client_completion_guard','src,'+captured,self.env,method=True)
    def run(self):
        client=self.actor.client
        return self.prefix(self.actor) is True and self.guard(self.actor,client) is True


class RestingSleep(unittest.TestCase):
    def test_original_resting_failure_and_new_standing_resting_completion(self):
        old=Harness(Actor(True),legacy_prefix=True)
        self.assertFalse(old.run());self.assertLess(old.world.time,1200)
        for bridge,resting in itertools.product((False,True),(False,True)):
            with self.subTest(bridge=bridge,resting=resting):
                actor=Actor(resting);h=Harness(actor,bridge)
                self.assertTrue(h.run());self.assertEqual(h.world.time,1200)
                self.assertEqual((actor.started,actor.finished,actor.may_do_after),(1,1,True))
                self.assertTrue(h.bars[0].deleted)
    def test_all_preexisting_mask_combinations_and_states_are_unchanged(self):
        self.assertEqual(DEFAULT,13);self.assertEqual(PERMISSION,64)
        actor=Actor()
        for bits in itertools.product((False,True),repeat=7):
            for name,value in zip(FIELDS,bits):setattr(actor,name,value)
            for restrained,buckled in itertools.product((False,True),range(3)):
                actor.restrained_state=restrained;actor.buckle_level=buckled
                for flags in range(64):
                    self.assertEqual(CURRENT(actor,flags),LEGACY(actor,flags))
    def test_no_mask_is_globally_relaxed_including_all_bits(self):
        actor=Actor()
        for bits in itertools.product((False,True),repeat=7):
            for name,value in zip(FIELDS,bits):setattr(actor,name,value)
            for restrained,buckled in itertools.product((False,True),range(3)):
                actor.restrained_state=restrained;actor.buckle_level=buckled
                for flags in tuple(range(128))+(-1,255):
                    if LEGACY(actor,flags):
                        self.assertTrue(CURRENT(actor,flags))

    def test_opt_in_ignores_only_resting_across_all_states(self):
        actor=Actor()
        for bits in itertools.product((False,True),repeat=7):
            for name,value in zip(FIELDS,bits):setattr(actor,name,value)
            for restrained,buckled in itertools.product((False,True),range(3)):
                actor.restrained_state=restrained;actor.buckle_level=buckled
                oracle=copy(actor);oracle.resting=False
                self.assertEqual(CURRENT(actor,SLEEP_FLAGS),LEGACY(oracle,13))
    def test_ordinary_waits_still_reject_resting(self):
        actor=Actor(True);h=Harness(actor)
        self.assertFalse(h.core(actor,1200,actor,False))
        self.assertLess(h.world.time,1200)
    def test_real_nonresting_incapacities_still_interrupt_resting_countdown(self):
        changes={'unconscious':('stat',1),'dead':('stat',2),'paralyzed':('paralysis',1),
                 'stunned':('stunned',1),'weakened':('weakened',1),'sleeping':('sleeping',1),
                 'fakedeath':('status_flags',FAKEDEATH),'restrained':('restrained_state',True),
                 'fully_buckled':('buckle_level',2)}
        for bridge,(label,(field,value)) in itertools.product((False,True),changes.items()):
            with self.subTest(mode=bridge,state=label):
                actor=Actor(True);h=Harness(actor,bridge);h.hook=lambda:setattr(actor,field,value)
                self.assertFalse(h.run());self.assertLess(h.world.time,1200)
                self.assertTrue(actor.may_do_after);self.assertTrue(h.bars[0].deleted)
    def test_tile_and_both_step_offsets_still_interrupt(self):
        for bridge,field in itertools.product((False,True),('loc','step_x','step_y')):
            with self.subTest(bridge=bridge,field=field):
                actor=Actor(True);h=Harness(actor,bridge)
                h.hook=lambda:setattr(actor,field,Turf() if field=='loc' else 2)
                self.assertFalse(h.run());self.assertLess(h.world.time,1200)
    def test_actor_deletion_interrupts(self):
        actor=Actor(True);h=Harness(actor);h.hook=lambda:setattr(actor,'deleted',True)
        self.assertFalse(h.run());self.assertTrue(h.bars[0].deleted)
    def test_hand_changes_do_not_cancel_sleep_but_still_cancel_hand_required_waits(self):
        actor=Actor(True);h=Harness(actor);h.hook=lambda:setattr(actor,'hand',object())
        self.assertTrue(h.run())
        actor=Actor();h=Harness(actor);h.hook=lambda:setattr(actor,'hand',object())
        self.assertFalse(h.core(actor,1200,actor,True))
    def test_repeat_attempt_fails_without_releasing_or_cancelling_original_wait(self):
        for bridge in (False,True):
            actor=Actor(True);h=Harness(actor,bridge)
            def repeated():
                self.assertFalse(h.run());self.assertFalse(actor.may_do_after)
                self.assertEqual((actor.started,actor.finished),(1,0))
            h.hook=repeated
            self.assertTrue(h.run())
            self.assertEqual((actor.started,actor.finished),(1,1))
    def test_client_loss_replacement_and_detachment_fail_existing_completion_guard(self):
        for change in ('disconnect','replacement','detachment'):
            with self.subTest(change=change):
                actor=Actor(True);h=Harness(actor)
                def mutate():
                    old=actor.client
                    if change=='disconnect':old.closed=True;actor.client=None
                    elif change=='replacement':actor.client=Client(actor)
                    else:old.mob=object()
                h.hook=mutate
                self.assertFalse(h.run())
                # Existing client ownership is rechecked after the timer, not in do_after.
                self.assertEqual(h.world.time,1200)
    def test_ordinary_unrestrained_bed_buckle_and_lying_are_distinct(self):
        actor=Actor(True);actor.buckle_level=1;self.assertTrue(Harness(actor).run())
        actor=Actor();actor.lying=True
        self.assertFalse(CURRENT(actor,DEFAULT));self.assertTrue(Harness(actor).run())
        actor=Actor(True);actor.lying=False
        self.assertTrue(CURRENT(actor,DEFAULT));self.assertFalse(CURRENT(actor,SLEEP_FLAGS))
    def test_disease_fleas_hygiene_and_missing_bed_refuse_before_wait(self):
        for reason in ('disease','fleas','hygiene','bed','already_sleeping'):
            with self.subTest(reason=reason):
                actor=Actor(True)
                if reason=='disease':actor.disease=True
                elif reason=='fleas':actor.wear_suit.fleas=True
                elif reason=='hygiene':actor.hygiene=80
                elif reason=='bed':actor.loc.beds=[]
                else:actor.sleeping=1
                h=Harness(actor);self.assertFalse(h.run());self.assertEqual(h.wait_calls,[])
    def test_caller_retains_hand_movement_and_repeat_defaults(self):
        h=Harness(Actor(True));self.assertTrue(h.run());args,kwargs=h.wait_calls[0]
        self.assertIs(args[0],h.actor);self.assertEqual(args[1],1200)
        self.assertIs(args[2],h.actor);self.assertIs(args[3],False)
        self.assertEqual(kwargs,{'incapacitation_flags':SLEEP_FLAGS})

if __name__ == '__main__':unittest.main()
