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
    # Nobody here is held for a trip (travel_hold.dm).
    env = dict(FLAGS, FAKEDEATH=FAKEDEATH, PARTIALLY_BUCKLED=1, FULLY_BUCKLED=2, travel_held=lambda: False)
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
        self.answer='Yes';self.inducedSSD=False
    def __bool__(self): return not self.deleted
    def incapacitated(self, flags=DEFAULT): return CURRENT(self,flags)
    def restrained(self): return self.restrained_state
    def buckled(self): return self.buckle_level
    def get_active_hand(self): return self.hand
    def survival_action_started(self, target=None, mining_context=None): self.started+=1; return 2
    def survival_action_finished(self, workload): self.finished+=1


class Harness:
    def __init__(self, actor, bridge=False, legacy_prefix=False, *, registered=False, map_id='ordinary', holder=None, island=None, faction='our-faction', nation='our-nation', assigned=False, refusal=None):
        self.actor=actor;self.world=SimpleNamespace(time=0);self.hook=None
        self.bars=[];self.messages=[];self.wait_calls=[];self.bridge=bridge
        self.prompts=[];self.confirm_hook=None;self.holder=holder;self.island=island
        self.assigned=assigned;self.refusal=refusal
        def answer(user, prompt, *args):
            self.prompts.append(prompt)
            if self.confirm_hook:
                hook=self.confirm_hook;self.confirm_hook=None;hook()
            return actor.answer
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
            MINUTES=600, SECONDS=10, HYGIENE_LEVEL_DIRTY=75, list=lambda *v:v, typed_iter=typed_iter, get_turf=lambda mob:mob.loc,
            to_chat=lambda user,message:self.messages.append(message), SPAN_RED=lambda s:s,
            SPAN_NOTICE=lambda s:s, SPAN_WARNING=lambda s:s, WWalert=lambda *a:None,
            WWinput=answer, usr=actor, map=SimpleNamespace(ID=map_id),
            MAP_VOYAGE='voyage', MAP_NOMADS_GAIA='gaia', persistence_sleep_transfer_blocked=lambda:False,
            persistence_bed_return_enabled=lambda:registered, saved_bed_taken_here=lambda:self.assigned,
            saved_bed_sleep_refusal=lambda:self.refusal, log_game=lambda message:None)
        policy=(ROOT/'code/modules/persistence/offline_sleep_protection.dm').read_text(encoding='utf-8-sig')
        self.env['offline_sleep_protection_map_allowed']=A.project(policy,'/proc/offline_sleep_protection_map_allowed','',self.env)
        # Project the production ownership predicate, with fake map/faction lookups.
        ownership_env=dict(self.env, civilization=faction, x=1, y=1,
            island_claim_parent=lambda:self.island, colony_faction_id=lambda body:faction,
            province_holder_of=lambda cell:self.holder, province_group_of=lambda value:nation)
        ownership_env['map']=SimpleNamespace(province_map=lambda:SimpleNamespace(char_at=lambda x,y:'province'))
        ownership=policy.replace('c ? province_holder_of(c) : null', '(province_holder_of(c) if c else null)')
        owns_province=A.project(ownership,'/mob/living/human/proc/offline_sleep_province_owned','src',ownership_env,method=True)
        self.env['offline_sleep_province_owned']=lambda:owns_province(actor)
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
        args+=',ship_craft=None'
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
        prefix=prefix.replace('2 MINUTES','2 * MINUTES').replace('10 SECONDS','10 * SECONDS')
        self.prefix=A.project(prefix,'/mob/living/human/verb/mob_sleep','src',self.env,method=True)
        captured=re.search(r'var/client/(\w+) = client',full)[1]
        completion=full[full.index('if (do_after('):]
        guard=next(line.strip() for line in completion.splitlines() if f'client != {captured}' in line)
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
    def test_registered_bed_uses_the_actual_protection_policy_for_wait_and_messages(self):
        cases=(
            ('Gaia, even if held',dict(map_id='gaia',holder='our-nation'),100,'10 seconds',False),
            ('unheld province',dict(),100,'10 seconds',False),
            ('foreign province',dict(holder='foreign-nation'),100,'10 seconds',False),
            ('no faction',dict(holder='our-nation',faction='none'),100,'10 seconds',False),
            ('faction-held',dict(holder='our-faction',nation='our-faction'),1200,'two minutes',True),
            ('nation-held',dict(holder='our-nation'),1200,'two minutes',True),
            ('own island',dict(island='our-faction'),1200,'two minutes',True),
            ('foreign island',dict(island='foreign-faction'),100,'10 seconds',False),
        )
        for bridge,(label,kw,delay,timing,protected) in itertools.product((False,True),cases):
            with self.subTest(bridge=bridge,region=label):
                actor=Actor(True);h=Harness(actor,bridge,registered=True,**kw)
                self.assertTrue(h.run())
                self.assertEqual(h.wait_calls[0][0][1],delay)
                self.assertEqual(h.world.time,delay)
                self.assertIn('This takes '+timing+'.',h.prompts[0])
                self.assertIn('You will start sleeping in '+timing+'.',h.messages)
                self.assertEqual('still qualifies when you log off' in h.prompts[0],protected)

    def test_registered_wait_stays_fixed_when_ownership_flips(self):
        for holder,flip,delay in ((None,'our-nation',100),('our-nation',None,1200)):
            for moment in ('confirm_hook','hook'):
                with self.subTest(holder=holder,flip=flip,moment=moment):
                    actor=Actor(True);h=Harness(actor,registered=True,holder=holder)
                    setattr(h,moment,lambda:setattr(h,'holder',flip))
                    self.assertTrue(h.run())
                    self.assertEqual(h.world.time,delay)

    def test_registered_sleep_cannot_use_a_prompt_after_moving_to_another_bed(self):
        actor=Actor(True);h=Harness(actor,registered=True)
        def move_to_protected_bed():
            actor.loc=Turf()
            h.holder='our-nation'
        h.confirm_hook=move_to_protected_bed
        self.assertFalse(h.run())
        self.assertEqual(h.wait_calls,[])
        self.assertEqual(h.world.time,0)

    def test_existing_registered_bed_admission_precedes_timer_and_prompt(self):
        for result in (dict(assigned=True),dict(refusal='The bed is not available.')):
            h=Harness(Actor(True),registered=True,**result)
            self.assertFalse(h.run())
            self.assertEqual((h.prompts,h.wait_calls),([],[]))

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
    def test_the_sick_may_sleep(self):
        actor=Actor(True);actor.disease=True
        h=Harness(actor);self.assertTrue(h.run());self.assertEqual(len(h.wait_calls),1)
        legacy=Harness(actor,legacy_prefix=True);self.assertFalse(legacy.run())
        rest=(ROOT/'code/game/mob/living/carbon/human/severe_disease.dm').read_text(encoding='utf-8')
        self.assertIn('return (inducedSSD && isturf(loc) && (locate(/obj/structure/bed) in loc)) ? TRUE : FALSE',rest)
    def test_fleas_hygiene_and_missing_bed_refuse_before_wait(self):
        for reason in ('fleas','hygiene','bed','already_sleeping'):
            with self.subTest(reason=reason):
                actor=Actor(True)
                if reason=='fleas':actor.wear_suit.fleas=True
                elif reason=='hygiene':actor.hygiene=74
                elif reason=='bed':actor.loc.beds=[]
                else:actor.sleeping=1
                h=Harness(actor);self.assertFalse(h.run());self.assertEqual(h.wait_calls,[])
    def test_caller_retains_hand_movement_and_repeat_defaults(self):
        h=Harness(Actor(True));self.assertTrue(h.run());args,kwargs=h.wait_calls[0]
        self.assertIs(args[0],h.actor);self.assertEqual(args[1],1200)
        self.assertIs(args[2],h.actor);self.assertIs(args[3],False)
        self.assertEqual(kwargs,{'incapacitation_flags':SLEEP_FLAGS})

if __name__ == '__main__':unittest.main()
